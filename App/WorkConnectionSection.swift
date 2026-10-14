import SwiftUI
import ZenithKit

struct WorkConnectionSection: View {
  let configuration: WorkAccessConfiguration
  let busy: Bool
  var body: some View {
    Section("Your work server") {
      Text(configuration.name).font(.headline)
      Text(configuration.origin).font(.footnote).foregroundStyle(.secondary)
        .textSelection(.enabled)
      if configuration.network == .tailscale { PrivateNetworkRow() }
      if configuration.network == .lan {
        Label("Local network", systemImage: "wifi")
        Text("Use the same Wi-Fi as your server. Allow Local Network access when asked.")
          .font(.footnote).foregroundStyle(.secondary)
      }
      WorkConnectionCheck(configuration: configuration, busy: busy)
    }
  }
}

/// Reachability is separate from issuer trust, Wallet approval and saved authority.
struct WorkConnectionCheck: View {
  let configuration: WorkAccessConfiguration
  private var receiver: URL { configuration.receiver }
  private var network: WorkNetwork? { configuration.network }
  var busy = false
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @Environment(\.scenePhase) private var scene
  @State private var checkTask: Task<Void, Never>?
  @State private var checking = false
  @State private var reachable = false
  @State private var failure: String?

  var body: some View {
    Button(action: check) {
      if checking { ProgressView("Checking connection…") }
      else { Label(reachable ? "Check again" : "Check connection", systemImage: "antenna.radiowaves.left.and.right") }
    }.disabled(checking || busy)
      .accessibilityIdentifier("work.connection.check")
    if reachable {
      Label("Server reached", systemImage: "checkmark.circle")
      Text("Reachable only. Server verification and read access still need your approval.")
        .font(.footnote).foregroundStyle(.secondary)
    }
    if let failure { Text(failure).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
    Text("This check sends no Wallet ID or credentials.").font(.footnote).foregroundStyle(.secondary)
      .onChange(of: scene) { _, phase in if phase != .active { reset() } }
      .onChange(of: configuration) { _, _ in reset() }
      .onChange(of: privateNetwork.generation) { _, _ in reset() }
      .onDisappear { reset() }
  }
  private func reset() {
    checkTask?.cancel()
    checkTask = nil
    checking = false
    reachable = false
    failure = nil
  }
  private func check() {
    guard !checking else { return }
    reachable = false
    failure = nil
    checking = true
    checkTask = Task { @MainActor in
      do {
        let transport = try network == .tailscale ? privateNetwork.transport() : PrivateTransport(workServer: configuration)
        try await transport.checkReadReceiver(at: receiver)
        guard !Task.isCancelled else { return }
        reachable = true
      } catch {
        guard !Task.isCancelled else { return }
        if let error = error as? PrivateNetworkError {
          failure = error.localizedDescription
        } else if let error = error as? URLError {
          failure = WorkConnectionFailure(code: error.code, network: network).localizedDescription
        } else {
          failure = "This address did not return a supported Devgraph response. Check the address with your server administrator."
        }
      }
      checking = false
      checkTask = nil
    }
  }
}
