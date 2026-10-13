import SafariServices
import SwiftUI
import ZenithKit

typealias PrivateNetworkModel = PrivateNetworkSession

/// One entry point, reused in setup and the saved server's Connection section.
struct PrivateNetworkRow: View {
  @EnvironmentObject private var network: PrivateNetworkModel
  @State private var managing = false
  @State private var browser: SignInPage?
  @AccessibilityFocusState private var statusFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Label(status, systemImage: network.phase == .connected ? "checkmark.shield" : "network")
          .accessibilityFocused($statusFocused)
        Spacer()
        if network.phase == .connecting { ProgressView().accessibilityLabel("Connecting Tailscale") }
      }
      if network.phase == .connected {
        Button("Manage Tailscale") { managing = true }
      } else if network.phase == .connecting || network.phase == .signInRequired || network.phase == .awaitingApproval {
        if let url = network.authURL {
          Button("Continue sign-in") { browser = SignInPage(url: url) }
        } else if network.phase == .signInRequired {
          Button("Sign in to Tailscale") { network.connect() }
        }
        if network.phase == .awaitingApproval {
          Text("Your network administrator needs to approve this device.").font(.footnote).foregroundStyle(.secondary)
        }
        Button("Cancel") { network.cancelSignIn() }
      } else {
        Button("Connect Tailscale") {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          network.connect()
        }.accessibilityIdentifier("work.tailscale.connect")
      }
      if let message = network.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
    }.padding(.vertical, 4)
    Text("Join the network your server uses. Work access is approved separately.")
      .font(.footnote).foregroundStyle(.secondary)
      .onChange(of: network.authURL) { _, url in
        if let url { browser = SignInPage(url: url) }
        else { browser = nil }
      }
      .onChange(of: network.phase) { _, phase in
        if phase == .connected { browser = nil; statusFocused = true }
      }
      .sheet(item: $browser, onDismiss: {
        statusFocused = true
      }) { page in
        TailscaleSignInBrowser(url: page.url) {
          browser = nil
          if network.phase != .connected && network.phase != .awaitingApproval { network.cancelSignIn() }
        }.interactiveDismissDisabled()
      }
      .sheet(isPresented: $managing) {
        NavigationStack {
          Form {
            Section {
              Label("Private network connected", systemImage: "checkmark.shield")
              if let name = network.networkName { LabeledContent("Network", value: name) }
              Text("Tailscale connects Work inside Zenith. Other apps use their own connections.")
            }
            Section {
              Button("Disconnect Tailscale") { network.disconnect(); managing = false }
            } footer: {
              Text("Pauses this app’s connection. Your server settings and read approval stay saved. Remove this device in the Tailscale admin console to revoke its network membership.")
            }
          }.navigationTitle("Private connection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { managing = false } } }
        }.presentationDetents([.medium, .large])
      }
  }
  private var status: String {
    switch network.phase {
    case .idle: return "Tailscale not connected"
    case .connecting: return "Connecting Tailscale…"
    case .signInRequired: return "Sign in to Tailscale"
    case .awaitingApproval: return "Waiting for device approval"
    case .connected: return "Private network connected"
    case .paused: return "Tailscale paused"
    case .failed: return "Tailscale couldn’t connect"
    }
  }
}
private struct SignInPage: Identifiable {
  let id = UUID()
  let url: URL
}
/// System browser owns authentication. No passwords, cookies, or page content
/// are available to Zenith. Completion is determined by the local node status.
private struct TailscaleSignInBrowser: UIViewControllerRepresentable {
  let url: URL
  let finished: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }
  func makeUIViewController(context: Context) -> SFSafariViewController {
    let view = SFSafariViewController(url: url)
    view.delegate = context.coordinator
    view.dismissButtonStyle = .cancel
    return view
  }
  func updateUIViewController(_ view: SFSafariViewController, context: Context) {}
  final class Coordinator: NSObject, SFSafariViewControllerDelegate {
    let finished: () -> Void
    init(finished: @escaping () -> Void) { self.finished = finished }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { finished() }
  }
}
