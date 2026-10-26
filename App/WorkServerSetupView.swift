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
  @State private var discovering = false
  @State private var discoveryTask: Task<Void,Never>?
  @State private var discoveryID: UUID?
  @State private var tailnetServers: [WorkAccessConfiguration] = []
  @State private var scanningTailnet = false
  @State private var scanTask: Task<Void, Never>?
  @State private var scanMessage: String?
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
    .onDisappear { cancelScan(); cancelDiscovery(); if scene == .active { draft.active = false } }
    .task { refreshFiles(); if privateNetwork.phase == .connected { scanTailnet() } }
    .onChange(of: scene) { _, phase in
      if phase == .active { refreshFiles() } else { cancelScan(); cancelDiscovery() }
    }
    .onChange(of: draft.discoverViaTailscale) { _, _ in cancelDiscovery(); error = nil }
    .onChange(of: privateNetwork.generation) { _, _ in
      if draft.discoverViaTailscale { cancelScan(); tailnetServers = []; cancelDiscovery() }
    }
    .onChange(of: privateNetwork.phase) { _, phase in
      if phase == .connected && draft.preview == nil { scanTailnet() }
      else if phase != .connected { cancelScan(); tailnetServers = [] }
    }
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
      Section {
        Toggle("Use Tailscale", isOn: $draft.discoverViaTailscale)
          .disabled(busy)
          .accessibilityIdentifier("work.server.tailscale")
        if draft.discoverViaTailscale {
          PrivateNetworkRow(explanation: "Sign in to the Tailscale network that contains your DevGraph server, then enter its HTTPS address below.")
            .disabled(busy)
        } else {
          Text("Connect directly using HTTPS.").font(.footnote).foregroundStyle(.secondary)
        }
      } header: { Text("Network") }
      if privateNetwork.phase == .connected {
        Section("Servers on your Tailscale network") {
          Button("Find servers on Tailscale", systemImage: "network") { scanTailnet() }
            .disabled(scanningTailnet || busy)
          if scanningTailnet { ProgressView("Checking visible devices…") }
          ForEach(tailnetServers, id: \.origin) { server in
            Button { select(server) } label: {
              VStack(alignment: .leading) { Text(server.name).font(.headline); Text(server.origin).font(.footnote) }
            }
          }
          if let scanMessage { Text(scanMessage).font(.footnote).foregroundStyle(.secondary) }
          Text("Checks advertised DevGraph servers on visible devices. Discovery sends no Wallet identity and grants no access. Other addresses can be entered below.").font(.footnote).foregroundStyle(.secondary)
        }
      }
      Section {
        TextField("https://your-work-server", text:$draft.address)
          .textContentType(.URL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
          .disabled(discovering || busy)
        Button("Find server") { discover() }
          .disabled(discovering || busy || draft.address.isEmpty
            || (draft.discoverViaTailscale && privateNetwork.phase != .connected))
        if discovering { ProgressView("Finding server…") }
      } header: { Text("Server address") } footer: { Text("Enter the HTTPS address supplied by your administrator. You’ll review its verification details before saving or sharing your Wallet identity.") }
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
                  Text(item.configuration.network == .lan ? "Local network · Same Wi-Fi" :
                    item.configuration.network == .tailscale ? "Private via Tailscale" : "Direct HTTPS")
                    .font(.subheadline)
                  Text(item.configuration.origin).font(.footnote).foregroundStyle(.secondary)
                }
              } icon: { Image(systemName: "network") }
                .frame(minHeight: 54, alignment: .leading)
            }.accessibilityIdentifier("work.server.discovered")
          }
        } header: { Text("Saved connection files") } footer: {
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
        } else if server.network == .lan {
          Label("Local network", systemImage: "wifi")
          Text("Join the same Wi-Fi as your server. When Zenith asks for Local Network access, tap Allow.")
            .font(.subheadline).foregroundStyle(.secondary)
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
          if let certificate = server.tls_certificate_sha256 {
            Text("LAN certificate · SHA-256").font(.caption)
            Text(certificate).font(.caption.monospaced()).textSelection(.enabled)
          }
        }
      }
      feedback
    }
  }
  @ViewBuilder private var feedback: some View {
    if let message = error ?? saveError { Section { Text(message).foregroundStyle(.red) } }
    if busy { Section { ProgressView("Connecting…") } }
  }
  private func cancelScan() {
    scanTask?.cancel(); scanTask = nil; scanningTailnet = false
  }
  private func scanTailnet() {
    guard privateNetwork.phase == .connected, !scanningTailnet, !busy else { return }
    scanningTailnet = true; scanMessage = nil
    let generation = privateNetwork.generation
    scanTask = Task { @MainActor in
      do {
        let found = try await privateNetwork.discoverWorkServers()
        guard !Task.isCancelled, generation == privateNetwork.generation, scene == .active else { return }
        tailnetServers = found
        scanMessage = found.isEmpty ? "No advertised DevGraph servers responded. You can still enter an address or choose a connection file." : "Review a server before saving or connecting your Wallet."
      } catch {
        guard !Task.isCancelled, generation == privateNetwork.generation else { return }
        scanMessage = "Couldn’t finish discovery. Check Tailscale or enter your server address below."
      }
      if !Task.isCancelled { scanningTailnet = false; scanTask = nil }
    }
  }
  private func discover() {
    cancelDiscovery(); discovering = true; error = nil
    let address = draft.address
    let network: WorkNetwork? = draft.discoverViaTailscale ? .tailscale : nil
    let ticket = UUID()
    discoveryID = ticket
    discoveryTask = Task { @MainActor in
      defer {
        if discoveryID == ticket { discovering = false; discoveryID = nil; discoveryTask = nil }
      }
      do {
        let transport = network == .tailscale ? privateNetwork.transport() : nil
        let server = try await WorkServerDiscovery.discover(address, network: network, transport: transport)
        guard !Task.isCancelled, discoveryID == ticket, draft.address == address, scene == .active else { return }
        select(server)
      } catch {
        guard !Task.isCancelled, discoveryID == ticket else { return }
        if let failure = error as? PrivateNetworkError { self.error = failure.localizedDescription }
        else if let failure = error as? URLError {
          self.error = WorkConnectionFailure(code: failure.code, network: network).localizedDescription
        } else {
          self.error = "Could not discover this server. Check its HTTPS address, or import a connection file from your administrator."
        }
      }
    }
  }
  private func cancelDiscovery() {
    discoveryTask?.cancel()
    discoveryTask = nil
    discoveryID = nil
    discovering = false
  }
  private func refreshFiles() {
    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    do { nearby = try WorkServerInbox.profiles(in: directory) }
    catch { nearby = []; self.error = "Could not check Zenith’s folder. You can still choose a connection file." }
  }
  private func select(_ server: WorkAccessConfiguration, connect: Bool = false) {
    // Preparing a public/LAN draft must not stop the shared private session,
    // including Chat, or disrupt the saved connection when setup is cancelled.
    draft.network = server.network
    draft.preview = server
    error = nil
    if connect, server.network == .tailscale, privateNetwork.phase != .connected { privateNetwork.connect() }
  }
}
