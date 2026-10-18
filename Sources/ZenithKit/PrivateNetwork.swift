import Foundation
import Combine

public enum PrivateNetworkPhase: Equatable, Sendable {
  case idle, connecting, signInRequired, awaitingApproval, connected, paused, failed
}
public enum PrivateNetworkError: Error, LocalizedError, Equatable {
  case disconnected, invalidStatus, interrupted
  public var errorDescription: String? {
    switch self {
    case .disconnected: return "Connect Tailscale in Work connection before trying again."
    case .invalidStatus: return "The private connection could not be verified. Reconnect Tailscale to try again."
    case .interrupted: return "The private connection changed. Please try again."
    }
  }
}

/// Decode only the small subset needed by Zenith. Never retain peers, keys,
/// diagnostic messages, or a complete tailnet status document.
public struct PrivateNetworkStatus: Sendable {
  public let phase: PrivateNetworkPhase
  public let networkName: String?
  public let authURL: URL?
  public init(data: Data) throws {
    struct Status: Decodable {
      struct Tailnet: Decodable { let Name: String }
      let BackendState: String
      let AuthURL: String?
      let CurrentTailnet: Tailnet?
    }
    guard data.count <= 4_194_304 else { throw PrivateNetworkError.invalidStatus }
    let value = try JSONDecoder().decode(Status.self, from: data)
    switch value.BackendState {
    case "Running": phase = .connected
    case "NeedsLogin": phase = .signInRequired
    case "NeedsMachineAuth": phase = .awaitingApproval
    case "Starting", "NoState": phase = .connecting
    case "Stopped": phase = .paused
    default: throw PrivateNetworkError.invalidStatus
    }
    networkName = value.CurrentTailnet?.Name.count ?? 0 <= 256 ? value.CurrentTailnet?.Name : nil
    if phase == .signInRequired, let raw = value.AuthURL, !raw.isEmpty {
      // This release uses the official control plane only. A file cannot select
      // a control plane or redirect the sign-in UI to an arbitrary origin.
      guard raw.count <= 4096, let url = URL(string: raw), url.scheme == "https",
        url.host == "login.tailscale.com", url.port == nil || url.port == 443,
        url.user == nil, url.password == nil, url.fragment == nil
      else { throw PrivateNetworkError.invalidStatus }
      authURL = url
    } else { authURL = nil }
  }
}

public protocol PrivateNetworkDriver: Sendable {
  func start(interactive: Bool) async throws
  func status() async throws -> PrivateNetworkStatus
  func configuration() async throws -> URLSessionConfiguration
  func stop() async
}

/// App-scoped network lifecycle, independent of custody and read authority.
/// Every generation invalidates its HTTP sessions; cancellation never enables
/// a direct-network fallback. Driver calls are serialized across stop/restart.
@MainActor
public final class PrivateNetworkSession: ObservableObject {
  @Published public private(set) var phase: PrivateNetworkPhase = .idle
  @Published public private(set) var networkName: String?
  @Published public private(set) var authURL: URL?
  @Published public private(set) var message: String?
  @Published public private(set) var generation = 0
  private let driver: any PrivateNetworkDriver
  private var operation: Task<Void, Never>?
  private var resumeRequested = false
  private struct WeakTransport { weak var value: PrivateTransport? }
  private var transports: [WeakTransport] = []
  public init(driver: any PrivateNetworkDriver) { self.driver = driver }

  public func connect() { begin(interactive: true) }
  public func disconnect() { stop(phase: .idle, resume: false) }
  public func cancelSignIn() { disconnect() }
  public func suspend() {
    let wanted = phase != .idle && phase != .failed
    stop(phase: wanted ? .paused : .idle, resume: wanted)
  }
  public func resume() {
    guard resumeRequested else { return }
    resumeRequested = false
    begin(interactive: false)
  }
  public func transport(requestTimeout: TimeInterval = 20, resourceTimeout: TimeInterval = 30) -> PrivateTransport {
    let transport = PrivateTransport(configurationProvider: { [weak self] in
      guard let self else { throw PrivateNetworkError.disconnected }
      return try await self.configuration()
    }, requestTimeout: requestTimeout, resourceTimeout: resourceTimeout)
    transports.removeAll { $0.value == nil }
    transports.append(WeakTransport(value: transport))
    return transport
  }
  private func invalidate() {
    generation += 1
    authURL = nil
    networkName = nil
    transports.forEach { $0.value?.cancel() }
    transports.removeAll { $0.value == nil }
  }
  private func stop(phase next: PrivateNetworkPhase, resume: Bool) {
    resumeRequested = resume
    let previous = operation
    previous?.cancel()
    invalidate()
    phase = next
    message = nil
    operation = Task { [driver] in
      await previous?.value
      await driver.stop()
    }
  }
  private func begin(interactive: Bool) {
    let previous = operation
    previous?.cancel()
    invalidate()
    let ticket = generation
    phase = .connecting
    message = nil
    resumeRequested = false
    operation = Task { [weak self, driver] in
      await previous?.value
      await driver.stop()
      do {
        try Task.checkCancellation()
        try await driver.start(interactive: interactive)
        let deadline = Date().addingTimeInterval(300)
        while !Task.isCancelled {
          let status = try await driver.status()
          guard let self, ticket == self.generation, !Task.isCancelled else { break }
          if self.phase == .connected && status.phase != .connected {
            self.transports.forEach { $0.value?.cancel() }
            self.generation += 1
            self.phase = status.phase
            self.authURL = nil
            self.message = "Tailscale disconnected. Reconnect to continue."
            break
          }
          self.phase = status.phase
          self.networkName = status.networkName
          self.authURL = status.authURL
          if status.phase != .connected && Date() > deadline {
            throw PrivateNetworkError.disconnected
          }
          try await Task.sleep(nanoseconds: status.phase == .connected ? 5_000_000_000 : 1_000_000_000)
        }
      } catch {
        if let self, ticket == self.generation, !Task.isCancelled {
          self.invalidate()
          self.phase = .failed
          self.message = "Couldn’t connect Tailscale. Check your internet connection and try again."
        }
      }
      await driver.stop()
    }
  }
  private func configuration() async throws -> URLSessionConfiguration {
    guard phase == .connected else { throw PrivateNetworkError.disconnected }
    let ticket = generation
    let status = try await driver.status()
    guard status.phase == .connected else { throw PrivateNetworkError.disconnected }
    let config = try await driver.configuration()
    guard ticket == generation, phase == .connected else { throw PrivateNetworkError.interrupted }
    return config
  }
}
