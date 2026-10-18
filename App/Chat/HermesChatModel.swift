import SwiftUI
import ZenithKit

@MainActor final class HermesChatModel: ObservableObject {
  @Published private(set) var connection: HermesChatConnection?
  @Published private(set) var messages: [HermesChatMessage] = []
  @Published private(set) var ready = false
  @Published private(set) var busy = false
  @Published private(set) var waitingForReply = false
  @Published var error: String?
  private var settings: HermesChatSettings?
  private var client: HermesChatClient?
  private var task: Task<Void, Never>?
  private var generation = 0

  init() { connection = try? HermesChatKeychain.load()?.connection }
  private func run(_ action: @escaping (Int) async throws -> Void) {
    task?.cancel()
    client?.cancel()
    generation += 1
    let ticket = generation
    busy = true
    error = nil
    task = Task { @MainActor in
      do { try await action(ticket) } catch {
        guard ticket == generation, !Task.isCancelled else { return }
        if error as? HermesChatError == .authentication {
          ready = false
          self.error = HermesChatError.authentication.localizedDescription
        } else if waitingForReply {
          self.error = HermesChatError.uncertainDelivery.localizedDescription
        } else {
          self.error = error.localizedDescription
        }
      }
      if ticket == generation { busy = false }
    }
  }
  private func current(_ ticket: Int) throws {
    try Task.checkCancellation()
    guard generation == ticket else { throw CancellationError() }
  }
  private func makeClient(_ value: HermesChatSettings, network: PrivateNetworkSession) throws
    -> HermesChatClient
  {
    guard network.phase == .connected else { throw PrivateNetworkError.disconnected }
    return try HermesChatClient(
      settings: value, transport: network.transport(requestTimeout: 300, resourceTimeout: 600))
  }
  func load(network: PrivateNetworkSession) {
    guard !busy else { return }
    run { [self] ticket in
      guard let saved = try HermesChatKeychain.load() else {
        ready = false
        return
      }
      ready = false
      settings = saved
      connection = saved.connection
      waitingForReply = saved.awaitingReplyAfter != nil
      let candidate = try makeClient(saved, network: network)
      client = candidate
      try await candidate.check()
      try current(ticket)
      ready = true
      try await refresh(candidate, ticket: ticket)
    }
  }
  func connect(
    name: String, address: String, key: String, network: PrivateNetworkSession,
    completion: @escaping () -> Void
  ) {
    run { [self] ticket in
      let connection = try HermesChatConnection(
        name: name, receiver: WorkServerSettings.address(address))
      let previous = try HermesChatKeychain.load()
      let selectedKey =
        key.isEmpty && previous?.connection.receiver == connection.receiver
        ? previous?.key ?? "" : key
      let value = try HermesChatSettings(connection: connection, key: selectedKey)
      let candidate = try makeClient(value, network: network)
      client = candidate
      try await candidate.check()
      try current(ticket)
      // Keep the conversation only when both the endpoint and credential match.
      let saved =
        previous?.connection.receiver == connection.receiver && previous?.key == selectedKey
        ? previous! : value
      try HermesChatKeychain.save(saved)
      settings = saved
      self.connection = saved.connection
      ready = true
      waitingForReply = saved.awaitingReplyAfter != nil
      messages = []
      completion()
      try await refresh(candidate, ticket: ticket)
    }
  }
  func send(_ text: String, network: PrivateNetworkSession) {
    guard !busy, !waitingForReply, ready, settings != nil else { return }
    run { [self] ticket in
      guard var saved = settings else { throw HermesChatError.setup }
      let candidate = try makeClient(saved, network: network)
      client = candidate
      if saved.sessionID == nil {
        let id = "zenith_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        try await candidate.createSession(id: id)
        try current(ticket)
        saved.sessionID = id
        try HermesChatKeychain.save(saved)
        settings = saved
      }
      guard let id = saved.sessionID else { throw HermesChatError.invalidResponse }
      saved.awaitingReplyAfter = messages.count
      // Persist before dispatch. A lock, timeout or lost reply cannot resend it.
      try HermesChatKeychain.save(saved)
      settings = saved
      waitingForReply = true
      messages.append(HermesChatMessage(id: UUID().uuidString, role: "user", text: text))
      let reply = try await candidate.send(text, sessionID: id)
      try current(ticket)
      messages.append(reply)
      saved.awaitingReplyAfter = nil
      try HermesChatKeychain.save(saved)
      settings = saved
      waitingForReply = false
      try await refresh(candidate, ticket: ticket)
    }
  }
  private func refresh(_ candidate: HermesChatClient, ticket: Int) async throws {
    guard var saved = settings, let id = saved.sessionID else { return }
    let history = try await candidate.history(sessionID: id)
    try current(ticket)
    saved.sessionID = history.sessionID
    if let baseline = saved.awaitingReplyAfter, history.hasReply(after: baseline) {
      saved.awaitingReplyAfter = nil
    }
    try HermesChatKeychain.save(saved)
    settings = saved
    waitingForReply = saved.awaitingReplyAfter != nil
    messages = history.messages
  }
  func newChat() {
    guard !busy else { return }
    do {
      guard var value = try HermesChatKeychain.load() else { return }
      value.sessionID = nil
      value.awaitingReplyAfter = nil
      try HermesChatKeychain.save(value)
      settings = value
      messages = []
      waitingForReply = false
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  func remove() {
    suspend()
    do {
      try HermesChatKeychain.remove()
      connection = nil
    } catch { self.error = error.localizedDescription }
  }
  func suspend() {
    generation += 1
    task?.cancel()
    task = nil
    client?.cancel()
    client = nil
    settings = nil
    messages = []
    ready = false
    busy = false
    error = nil
  }
}
