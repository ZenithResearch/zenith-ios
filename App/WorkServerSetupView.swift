import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

/// User-owned installation settings; nothing is fetched or trusted implicitly.
struct WorkServerSetupView: View {
  let busy: Bool
  let saveError: String?
  let save: (WorkAccessConfiguration) -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var address = ""
  @State private var name = "Devgraph"
  @State private var issuer = ""
  @State private var keyID = ""
  @State private var publicKey = ""
  @State private var tailscale = false
  @State private var importing = false
  @State private var error: String?
  @State private var preview: WorkAccessConfiguration?
  @State private var verificationOrigin: String?

  var body: some View {
    Form {
      if let preview {
        Section("Review server") {
          LabeledContent("Name", value: preview.name)
          Text(preview.origin).textSelection(.enabled)
          LabeledContent("Network", value: preview.network == .tailscale ? "Tailscale" : "HTTPS")
          LabeledContent("Issuer", value: preview.issuer)
          LabeledContent("Key ID", value: preview.authority.key_id)
          Text("Issuer public key").font(.caption).foregroundStyle(.secondary)
          Text(preview.authority.public_key).font(.caption.monospaced()).textSelection(.enabled)
        }
        Section {
          Text("Confirm these details with your server administrator. Saving this server does not grant access or send your Wallet ID.")
          Button("Use this server") { save(preview) }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white).disabled(busy)
          Button("Edit settings") { self.preview = nil }.disabled(busy)
        }
      } else {
        Section {
          TextField("https://devgraph.example", text: $address)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityLabel("Server address")
          Toggle("Uses Tailscale", isOn: $tailscale)
          if tailscale { TailscaleSetupRows() }
          if let url = try? WorkServerSettings.address(address) {
            WorkConnectionCheck(receiver: url, network: tailscale ? .tailscale : nil, busy: busy)
          }
        } header: { Text("Server address") } footer: {
          Text("Use the HTTPS address supplied by your server administrator.")
        }
        Section {
          Button("Import connection file", systemImage: "doc.badge.plus") { importing = true }
          if !issuer.isEmpty && !publicKey.isEmpty {
            Label("Verification settings added", systemImage: "checkmark.circle")
          }
          DisclosureGroup("Enter settings manually") {
            TextField("Server name", text: $name)
            TextField("Issuer", text: $issuer)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Key ID", text: $keyID)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Issuer public key", text: $publicKey, axis: .vertical)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
          }
        } header: { Text("Server verification") } footer: {
          Text("Get a connection file or public verification settings from your server administrator. Never enter a password, private key or read credential here.")
        }
        Section {
          Button("Review server") { review() }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .disabled(busy || address.isEmpty || issuer.isEmpty || keyID.isEmpty || publicKey.isEmpty)
        }
      }
      if let error = error ?? saveError { Section { Text(error).foregroundStyle(.red) } }
    }
    .navigationTitle(preview == nil ? "Add work server" : "Verify server")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: address) { old, new in
      let origin = try? WorkServerSettings.address(new).absoluteString
      if !old.isEmpty, origin != (try? WorkServerSettings.address(old).absoluteString),
        verificationOrigin == nil || origin != verificationOrigin {
        issuer = ""
        keyID = ""
        publicKey = ""
        verificationOrigin = nil
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
      do {
        guard let url = try result.get().first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let settings = try WorkServerSettings.readFile(url)
        // A typed destination must agree with the independently supplied pin.
        if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          try WorkServerSettings.address(address).absoluteString != settings.origin {
          error = "This connection file is for a different server. Check the address before importing."
          return
        }
        verificationOrigin = settings.origin
        address = settings.origin
        name = settings.name
        issuer = settings.issuer
        keyID = settings.authority.key_id
        publicKey = settings.authority.public_key
        tailscale = settings.network == .tailscale
        error = nil
      } catch { self.error = WorkServerSetupError.profile.localizedDescription }
    }
  }
  private func review() {
    do {
      preview = try WorkAccessConfiguration(name: name, receiver: WorkServerSettings.address(address),
        issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
        keyID: keyID.trimmingCharacters(in: .whitespacesAndNewlines),
        publicKey: publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
        network: tailscale ? .tailscale : nil)
      error = nil
    } catch {
      self.error = "Check the HTTPS address and verification settings. The issuer public key must contain 64 lowercase hexadecimal characters."
    }
  }
}
