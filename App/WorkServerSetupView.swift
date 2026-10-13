import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

/// Guided setup keeps transport login and read authorization distinct without
/// asking people to transcribe issuer settings from a connection profile.
struct WorkServerSetupView: View {
  let busy: Bool
  let saveError: String?
  let save: (WorkAccessConfiguration) -> Void
  @Environment(\.scenePhase) private var scene
  @EnvironmentObject private var draft: WorkServerDraft
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var importing = false
  @State private var manual = false
  @State private var error: String?
  @State private var nearby: [WorkServerInboxEntry] = []

  var body: some View {
    Group {
      if let server = draft.preview {
        serverReview(server)
      } else {
        chooseServer
      }
    }
    .navigationTitle("Connect to work")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { draft.active = true }
    .onDisappear { if scene == .active { draft.active = false } }
    .task { refreshFiles() }
    .onChange(of: scene) { _, phase in if phase == .active { refreshFiles() } }
    .sheet(isPresented: $manual) {
      NavigationStack {
        ManualWorkServerView { select($0); manual = false }
          .environmentObject(draft)
          .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { manual = false } } }
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
      do {
        guard let url = try result.get().first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        select(try WorkServerSettings.readFile(url))
      } catch { self.error = WorkServerSetupError.profile.localizedDescription }
    }
  }

  private var chooseServer: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Text("Choose your work server").font(.title2.bold())
          Text("Choose a server below, sign in if asked, then approve what you can read.")
            .foregroundStyle(.secondary)
        }.padding(.vertical, 8)
      }
      if !nearby.isEmpty {
        Section {
          ForEach(nearby) { item in
            Button {
              do { select(try item.selectedConfiguration(), connect: true) }
              catch { self.error = "This connection file changed. Refresh the list and choose it again." }
            } label: {
              Label {
                VStack(alignment: .leading, spacing: 5) {
                  Text("Connect to \(item.configuration.name)").font(.headline)
                  Text(item.configuration.origin).font(.footnote).foregroundStyle(.secondary)
                }
              } icon: { Image(systemName: "network") }
                .frame(minHeight: 54, alignment: .leading)
            }.accessibilityIdentifier("work.server.discovered")
          }
        } header: { Text("Found on this iPhone") } footer: {
          Text("These connection files are already in Zenith’s folder. You’ll review the server before connecting.")
        }
      }
      Section {
        Button("Choose connection file", systemImage: "doc.badge.plus") { importing = true }
          .accessibilityIdentifier("work.server.import")
        DisclosureGroup("Need help finding your server?") {
          Text("Ask your work administrator for a Zenith connection file. Open it from Files, or copy it to Zenith using Finder on your Mac.")
          Text("For USB: connect your iPhone, open Finder → your iPhone → Files → Zenith, then drag in the connection file.")
          Text("You don’t need to type a server address or verification keys when you use a connection file.")
          Button("Refresh files", systemImage: "arrow.clockwise") { refreshFiles() }
        }
        Button("Enter settings manually") { manual = true }
          .font(.footnote)
      }
      feedback
    }
  }

  private func serverReview(_ server: WorkAccessConfiguration) -> some View {
    let needsNetwork = server.network == .tailscale && privateNetwork.phase != .connected
    return Form {
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Text(needsNetwork ? "Join your private network" : "Your work server")
            .font(.title2.bold())
          Text(needsNetwork
            ? "Sign in to the Tailscale network your administrator uses. Then return here to continue."
            : "Check the server below. Next, you’ll review and approve read-only access.")
            .foregroundStyle(.secondary)
        }.padding(.vertical, 8)
      }
      Section {
        Text(server.name).font(.headline)
        Text(server.origin).font(.subheadline).textSelection(.enabled)
        if server.network == .tailscale {
          PrivateNetworkRow().disabled(busy)
        } else {
          Label("Direct connection", systemImage: "network")
        }
      }
      Section {
        if !needsNetwork {
          Button("Continue to read access") { save(server) }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color(uiColor: .systemBackground))
            .disabled(busy)
            .accessibilityIdentifier("work.server.save")
        } else {
          Text("Next: approve read-only access").font(.subheadline).foregroundStyle(.secondary)
        }
        Button("Choose another server") { draft.preview = nil; error = nil }.disabled(busy)
      } footer: {
        Text(needsNetwork ? "You’ll return here after sign-in." : "Continue saves this server on your phone. Work access still needs your approval.")
      }
      Section {
        DisclosureGroup("Server verification details") {
          Text("Use a connection file from your administrator. Compare these details with them if you’re unsure.")
          LabeledContent("Issuer", value: server.issuer)
          LabeledContent("Key ID", value: server.authority.key_id)
          Text(server.authority.public_key).font(.caption.monospaced()).textSelection(.enabled)
        }
      }
      feedback
    }
  }
  @ViewBuilder private var feedback: some View {
    if let message = error ?? saveError { Section { Text(message).foregroundStyle(.red) } }
    if busy { Section { ProgressView("Connecting…") } }
  }
  private func refreshFiles() {
    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    do { nearby = try WorkServerInbox.profiles(in: directory) }
    catch { nearby = []; self.error = "Could not check Zenith’s folder. You can still choose a connection file." }
  }
  private func select(_ server: WorkAccessConfiguration, connect: Bool = false) {
    if server.network != .tailscale { privateNetwork.disconnect() }
    draft.tailscale = server.network == .tailscale
    draft.preview = server
    error = nil
    if connect, server.network == .tailscale, privateNetwork.phase != .connected { privateNetwork.connect() }
  }
}
