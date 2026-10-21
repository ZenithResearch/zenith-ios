#if os(macOS)
import AppKit
import SwiftUI
import ZenithKit

@MainActor final class TransferModel: ObservableObject {
  @Published var wallet: WalletState?
  @Published var resources: [RegisteredResource] = []
  @Published var error: String?
  @Published var busy = false
  let repository: WalletRepository?
  private let registry: ResourceRegistry?
  private var unlockedAt: Date?
  private var generation = 0

  init() {
    var loadedRepository: WalletRepository?
    var loadedRegistry: ResourceRegistry?
    do {
      let base = try FileManager.default.url(for: .applicationSupportDirectory,
        in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("ZenithTransfer", isDirectory: true)
      loadedRepository = try WalletRepository(directory: base.appendingPathComponent("Wallet"))
      loadedRegistry = try ResourceRegistry(directory: base.appendingPathComponent("Resources"))
    } catch { self.error = "Transfer storage is unavailable." }
    repository = loadedRegistry == nil ? nil : loadedRepository
    registry = loadedRegistry
  }
  func refresh() async {
    do {
      resources = try registry?.load() ?? []
      wallet = try await repository?.state()
    } catch { self.error = "Could not read saved settings. Existing files have been preserved." }
  }
  func register(_ value: RegisteredResource, replacing expected: RegisteredResource?) {
    do {
      guard let registry else { throw WorkServerSetupError.storage }
      try registry.save(value, replacing: expected)
      resources = try registry.load()
    } catch { self.error = "The resource changed or could not be saved. Reload it before trying again." }
  }
  func remove(_ value: RegisteredResource) {
    do {
      guard let registry else { throw WorkServerSetupError.storage }
      try registry.save(nil, replacing: value); resources = try registry.load()
    } catch { self.error = "The resource could not be removed. Its server grants are unchanged." }
  }
  func perform<T>(_ action: @escaping (WalletRepository) async throws -> T,
    success: @escaping (T) -> Void = { _ in }) {
    guard !busy, let repository else { return }
    busy = true; error = nil
    let expected = generation
    Task {
      do {
        let value = try await action(repository)
        wallet = try await repository.state()
        guard generation == expected else { busy = false; return }
        if wallet?.unlocked == true { unlockedAt = Date() }
        busy = false; success(value)
      } catch {
        wallet = try? await repository.state(); busy = false
        guard generation == expected else { return }
        self.error = "Wallet could not complete this step. Check the selected file and passwords, or unlock again."
      }
    }
  }
  func lock() {
    generation += 1
    repository?.invalidatePendingWork()
    unlockedAt = nil
    Task { await repository?.lock(); wallet = try? await repository?.state() }
  }
  func expire() {
    if let unlockedAt, Date().timeIntervalSince(unlockedAt) >= 300 { lock() }
  }
}

struct TransferConsole: View {
  @StateObject private var model = TransferModel()
  @State private var section = "resources"
  private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 16) {
        Text("Zenith Transfer").font(.title2.bold()).padding(.bottom, 12)
        nav("Resources & requests", "square.stack.3d.up", "resources")
        nav("Wallet", "wallet.pass", "wallet")
        nav("Transfer files", "qrcode", "files")
        Spacer()
        Text(model.wallet?.unlocked == true ? "Transfer Wallet unlocked" : "Transfer Wallet locked")
          .font(.caption).foregroundStyle(.secondary)
        if model.wallet?.unlocked == true { Button("Lock Wallet") { model.lock() } }
      }.padding(20).frame(width: 210).frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
      Divider()
      Group {
        switch section {
        case "wallet": TransferWalletView(model: model)
        case "files": TransferWindow()
        default: TransferResourcesView(model: model)
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }.task { await model.refresh() }
      .onReceive(clock) { _ in model.expire() }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.lock() }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.lock() }
      .alert("Needs attention", isPresented: Binding(get: { model.error != nil },
        set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } }
        message: { Text(model.error ?? "") }
  }
  private func nav(_ title: String, _ image: String, _ value: String) -> some View {
    Button { section = value } label: {
      Label(title, systemImage: image).frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(section == value ? Color.accentColor.opacity(0.12) : .clear)
        .cornerRadius(8)
    }.buttonStyle(.plain)
  }
}

private struct TransferResourcesView: View {
  @ObservedObject var model: TransferModel
  @State private var selected: String?
  @State private var proposed: RegisteredResource?
  @State private var replacing: RegisteredResource?
  @State private var removing: RegisteredResource?
  @State private var address = ""
  private var current: RegisteredResource? { model.resources.first { $0.id == selected } }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text("Resources & requests").font(.largeTitle.bold())
          Text("Choose a service to review its access requests and grants.").foregroundStyle(.secondary)
        }
        Spacer()
        Button("Import connection file") { importProfile() }
      }
      HStack {
        TextField("https://your-devgraph-server", text: $address)
        Button("Look up server") { discover() }.disabled(model.busy || address.isEmpty)
      }
      Text("Lookup reads public DevGraph settings. Review the issuer and address before registration.")
        .font(.caption).foregroundStyle(.secondary)
      Divider()
      HStack(alignment: .top, spacing: 24) {
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            if model.resources.isEmpty { Text("No resources registered").foregroundStyle(.secondary) }
            ForEach(model.resources) { resource in
              Button { selected = resource.id } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Label(resource.configuration.name, systemImage: "server.rack").font(.headline)
                  Text(resource.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                  .background(selected == resource.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                  .cornerRadius(10)
              }.buttonStyle(.plain)
            }
          }
        }.frame(width: 260)
        Divider()
        ScrollView {
          if let current {
            VStack(alignment: .leading, spacing: 16) {
              Text(current.configuration.name).font(.title.bold())
              Label("DevGraph · operator inbox", systemImage: "tray.full")
              Text("Review incoming requests, select a permission preset and one or more resource paths, then approve the exact grant in your browser Wallet.")
              Text("A selected container includes the resources beneath it at the time of access. Global access remains limited by the server's operator policy.")
                .foregroundStyle(.secondary)
              Button("Open requests & grants in browser") {
                if !NSWorkspace.shared.open(current.inboxURL) { model.error = "Could not open your browser." }
              }.buttonStyle(.borderedProminent)
              Text("Uses the Wallet in your browser. This Transfer Wallet is separate. The server must already authorize that Wallet as an operator.")
                .font(.callout).foregroundStyle(.secondary)
              Button("Copy inbox address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(current.inboxURL.absoluteString, forType: .string)
              }
              DisclosureGroup("Connection and issuer") { connection(current.configuration) }
              Text("Existing grants can be inspected and revoked in the inbox. Changing an existing grant without a new member request is still planned.")
                .font(.callout).foregroundStyle(.secondary)
              Divider()
              Button("Remove from this Mac", role: .destructive) { removing = current }
              Text("Removing a registration does not stop the service or revoke anyone's access.")
                .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
          } else {
            VStack(alignment: .leading, spacing: 16) {
              Text("Your resource console").font(.title.bold())
              Text("Import a public connection file supplied by your server, or look up an HTTPS DevGraph address. Registration saves public settings on this Mac.")
              Text("DevGraph is the first supported resource. A port or a running Hub service alone does not establish ownership or provide a credential-management interface.")
                .foregroundStyle(.secondary)
              Text("Approve access in your browser's Wallet. Native grant approvals and other service types are not available in Transfer yet.")
                .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }.frame(maxHeight: .infinity)
    }.padding(24)
      .sheet(item: $proposed) { value in
        VStack(alignment: .leading, spacing: 16) {
          Text("Register this resource?").font(.title2.bold())
          Text("Confirm these public settings against your server administrator's information. This does not grant authority or add certificate trust to your browser.")
          ScrollView {
            if let replacing {
              Text("Replace saved connection settings").font(.headline)
              connection(replacing.configuration)
              Divider()
              Text("New settings").font(.headline)
            }
            connection(value.configuration)
          }
          HStack {
            Button("Cancel") { proposed = nil }
            Spacer()
            Button("Register resource") {
              model.register(value, replacing: replacing)
              selected = value.id; proposed = nil
            }.buttonStyle(.borderedProminent)
          }
        }.padding(24).frame(width: 600, height: 500)
      }
      .confirmationDialog("Remove this resource registration?", isPresented: Binding(
        get: { removing != nil }, set: { if !$0 { removing = nil } })) {
        Button("Remove registration", role: .destructive) {
          if let removing { model.remove(removing) }; removing = nil
        }
      } message: { Text("Server grants and Wallet credentials remain unchanged.") }
  }
  private func connection(_ config: WorkAccessConfiguration) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(config.name).font(.headline)
      Text("Server: \(config.origin)")
      Text("Issuer: \(config.issuer)")
      Text("Key ID: \(config.authority.key_id)")
      Text("Public key: \(config.authority.public_key)").font(.caption.monospaced())
      Text("Network: \(config.network?.rawValue ?? "HTTPS")")
      if let fingerprint = config.tls_certificate_sha256 {
        Text("Certificate SHA-256: \(fingerprint)").font(.caption.monospaced())
        Text("This pin is for the native connection. Your browser separately validates HTTPS; registration does not install this certificate.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
  }
  private func importProfile() {
    let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do { propose(try RegisteredResource(configuration: WorkServerSettings.readFile(url))) }
    catch { model.error = "Choose a public DevGraph connection file. Wallet files and credentials cannot be registered as resources." }
  }
  private func discover() {
    guard !model.busy else { return }; model.busy = true
    Task {
      defer { model.busy = false }
      do {
        let result = try await WorkServerDiscovery.discover(address)
        propose(try RegisteredResource(configuration: result))
      } catch { model.error = "Could not look up this HTTPS server. For a private LAN certificate, import its administrator-supplied connection file instead." }
    }
  }
  private func propose(_ value: RegisteredResource) {
    replacing = model.resources.first { $0.id == value.id }; proposed = value
  }
}
#endif
