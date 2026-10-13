import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

/// User-owned installation settings; nothing is fetched or trusted implicitly.
struct WorkServerSetupView: View {
  let busy: Bool
  let saveError: String?
  let save: (WorkAccessConfiguration) -> Void
  @Environment(\.scenePhase) private var scene
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var draft: WorkServerDraft
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var importing = false
  @State private var error: String?

  var body: some View {
    Form {
      if let preview = draft.preview {
        Section("Review server") {
          LabeledContent("Name", value: preview.name)
          Text(preview.origin).textSelection(.enabled)
          LabeledContent("Connection", value: preview.network == .tailscale ? "Private via Tailscale" : "Direct")
          LabeledContent("Issuer", value: preview.issuer)
          LabeledContent("Key ID", value: preview.authority.key_id)
          Text("Issuer public key").font(.caption).foregroundStyle(.secondary)
          Text(preview.authority.public_key).font(.caption.monospaced()).textSelection(.enabled)
        }
        Section {
          Text("Confirm these details with your server administrator. Saving this server does not grant access or send your Wallet ID.")
          Button("Save server") { save(preview) }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white).disabled(busy)
            .accessibilityIdentifier("work.server.save")
          Button("Edit settings") { draft.preview = nil }.disabled(busy)
        }
      } else {
        Section {
          TextField("https://devgraph.example", text: $draft.address)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityLabel("Server address")
            .accessibilityIdentifier("work.server.address")
          Picker("Connection", selection: connectionSelection) {
            Text("Direct").tag(false)
            Text("Private via Tailscale").tag(true)
          }
          .pickerStyle(.menu)
          .disabled(busy)
          .accessibilityHint("Choose how Zenith reaches this server.")
          .accessibilityIdentifier("work.connection.route")
          if draft.tailscale { PrivateNetworkRow().disabled(busy) }
          if let url = try? WorkServerSettings.address(draft.address) {
            WorkConnectionCheck(receiver: url, network: draft.tailscale ? .tailscale : nil, busy: busy)
          }
        } header: { Text("Server address") } footer: {
          Text("Use the HTTPS address supplied by your server administrator.")
        }
        Section {
          Button("Import connection file", systemImage: "doc.badge.plus") { importing = true }
            .accessibilityIdentifier("work.server.import")
          if !draft.issuer.isEmpty && !draft.publicKey.isEmpty {
            Label("Verification settings added", systemImage: "checkmark.circle")
          }
          DisclosureGroup("Enter settings manually") {
            TextField("Server name", text: $draft.name)
              .accessibilityLabel("Server name")
            TextField("Issuer", text: $draft.issuer)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
              .accessibilityLabel("Issuer")
            TextField("Key ID", text: $draft.keyID)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
              .accessibilityLabel("Key ID")
            TextField("Issuer public key", text: $draft.publicKey, axis: .vertical)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
              .accessibilityLabel("Issuer public key")
          }
        } header: { Text("Server verification") } footer: {
          Text("Get a connection file or public verification settings from your server administrator. Never enter a password, private key or read credential here.")
        }
        Section {
          Button("Review server") { review() }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .disabled(busy || draft.address.isEmpty || draft.issuer.isEmpty || draft.keyID.isEmpty || draft.publicKey.isEmpty)
            .accessibilityIdentifier("work.server.review")
        }
      }
      if let error = error ?? saveError { Section { Text(error).foregroundStyle(.red) } }
    }
    .navigationTitle(draft.preview == nil ? "Add work server" : "Verify server")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { draft.active = true }
    .onDisappear { if scene == .active { draft.active = false } }
    .onChange(of: draft.address) { old, new in
      let origin = try? WorkServerSettings.address(new).absoluteString
      if !old.isEmpty, origin != (try? WorkServerSettings.address(old).absoluteString),
        draft.verificationOrigin == nil || origin != draft.verificationOrigin {
        draft.issuer = ""
        draft.keyID = ""
        draft.publicKey = ""
        draft.verificationOrigin = nil
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
      do {
        guard let url = try result.get().first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let settings = try WorkServerSettings.readFile(url)
        // A typed destination must agree with the independently supplied pin.
        if !draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          try WorkServerSettings.address(draft.address).absoluteString != settings.origin {
          error = "This connection file is for a different server. Check the address before importing."
          return
        }
        draft.verificationOrigin = settings.origin
        draft.address = settings.origin
        draft.name = settings.name
        draft.issuer = settings.issuer
        draft.keyID = settings.authority.key_id
        draft.publicKey = settings.authority.public_key
        selectConnection(settings.network == .tailscale)
        error = nil
      } catch { self.error = WorkServerSetupError.profile.localizedDescription }
    }
  }
  private var connectionSelection: Binding<Bool> {
    Binding(get: { draft.tailscale }, set: selectConnection)
  }
  private func selectConnection(_ tailscale: Bool) {
    if draft.tailscale && !tailscale { privateNetwork.disconnect() }
    draft.tailscale = tailscale
    draft.preview = nil
  }
  private func review() {
    do {
      draft.preview = try WorkAccessConfiguration(name: draft.name, receiver: WorkServerSettings.address(draft.address),
        issuer: draft.issuer.trimmingCharacters(in: .whitespacesAndNewlines),
        keyID: draft.keyID.trimmingCharacters(in: .whitespacesAndNewlines),
        publicKey: draft.publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
        network: draft.tailscale ? .tailscale : nil)
      error = nil
    } catch {
      self.error = "Check the HTTPS address and verification settings. The issuer public key must contain 64 lowercase hexadecimal characters."
    }
  }
}
