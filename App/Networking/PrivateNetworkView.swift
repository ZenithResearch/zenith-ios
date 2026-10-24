import SafariServices
import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

typealias PrivateNetworkModel = PrivateNetworkSession

/// One entry point, reused in setup and the saved server's Connection section.
struct PrivateNetworkRow: View {
  var explanation = "Join the network your server uses. Work access is approved separately."
  @EnvironmentObject private var network: PrivateNetworkModel
  @State private var managing = false
  @State private var enrolling = false
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
      if network.phase != .connected && network.phase != .connecting
        && network.phase != .awaitingApproval {
        Button("Sign in with an auth key", systemImage: "key") { enrolling = true }
          .accessibilityIdentifier("tailscale.enroll")
      }
      if let message = network.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
    }.padding(.vertical, 4)
    Text(explanation)
      .font(.footnote).foregroundStyle(.secondary)
      .onAppear { if let url = network.authURL { browser = SignInPage(url: url) } }
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
      .sheet(isPresented: $enrolling) {
        TailscaleEnrollmentView()
      }
      .sheet(isPresented: $managing) {
        NavigationStack {
          Form {
            Section {
              Label("Private network connected", systemImage: "checkmark.shield")
              if let name = network.networkName { LabeledContent("Network", value: name) }
              Text("Work and Chat share this private connection inside Zenith. Other apps use their own connections.")
            }
            Section {
              Button("Disconnect Tailscale") { network.disconnect(); managing = false }
            } footer: {
              Text("Pauses this app’s connection. Your saved server settings stay on this iPhone. Remove this device in the Tailscale admin console to revoke its network membership.")
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
    case .signInRequired: return "Not signed in"
    case .awaitingApproval: return "Waiting for device approval"
    case .connected: return "Private network connected"
    case .paused: return "Tailscale paused"
    case .failed: return "Tailscale couldn’t connect"
    }
  }
}
private struct TailscaleEnrollmentView: View {
  @EnvironmentObject private var network: PrivateNetworkModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scene
  @State private var key = ""
  @State private var importing = false
  @State private var submitted = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("Sign in to your private network without a browser login.")
          SecureField("Tailscale auth key", text: $key)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .privacySensitive().accessibilityIdentifier("tailscale.authKey")
          Button("Choose auth key file", systemImage: "doc.badge.plus") { importing = true }
        } footer: {
          Text("Use a one-time, non-ephemeral auth key from your Tailscale administrator. Work and Chat will share the saved device sign-in. This key is different from your Hermes gateway key.")
        }
        Section {
          Button("Enroll this iPhone") {
            let value = key
            key = ""
            do {
              try network.enroll(authKey: value)
              submitted = true
              error = nil
            } catch { self.error = error.localizedDescription }
          }.buttonStyle(.borderedProminent)
            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted)
          if submitted {
            if network.phase == .awaitingApproval {
              Text("Waiting for your network administrator to approve this device.")
            } else if network.phase == .connecting {
              ProgressView("Enrolling with Tailscale…")
            }
          }
          if let error { Text(error).foregroundStyle(.red) }
        } footer: {
          Text("Zenith clears the entered key when you submit or leave this screen. Reconnects use the protected device identity saved on this iPhone. A transferred key file stays in Files until you remove it.")
        }
      }.navigationTitle("Tailscale enrollment").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              if submitted { network.cancelSignIn() }
              dismiss()
            }
          }
        }
        .interactiveDismissDisabled(submitted)
        .onChange(of: network.phase) { _, phase in
          guard submitted else { return }
          if phase == .connected { dismiss() }
          else if phase == .failed {
            error = network.message
            submitted = false
          } else if phase == .idle || phase == .paused { submitted = false }
        }
        .onChange(of: scene) { _, phase in
          if phase != .active { key = "" }
        }
        .onDisappear { key = "" }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .data]) { result in
          do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            key = try TailscaleEnrollment.importKey(file.read(upToCount: 1025) ?? Data())
            error = nil
          } catch { self.error = "Choose a text file containing only your Tailscale auth key." }
        }
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
