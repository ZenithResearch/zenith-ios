import SwiftUI
import ZenithKit

/// The advanced form is deliberately separate from the normal connection flow.
struct ManualWorkServerView: View {
  let select: (WorkAccessConfiguration) -> Void
  @EnvironmentObject private var draft: WorkServerDraft
  @State private var error: String?
  var body: some View {
    Form {
      Section("Server") {
        TextField("Server name", text: $draft.name)
        TextField("HTTPS server address", text: $draft.address)
          .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("work.server.address")
        Picker("Connection", selection: $draft.tailscale) {
          Text("Direct").tag(false)
          Text("Private via Tailscale").tag(true)
        }.accessibilityIdentifier("work.connection.route")
      }
      Section {
        TextField("Issuer", text: $draft.issuer)
        TextField("Key ID", text: $draft.keyID)
        TextField("Issuer public key", text: $draft.publicKey, axis: .vertical)
      } header: { Text("Public verification settings") } footer: {
        Text("Get these public settings from your administrator. Never enter a password, private key or read credential here.")
      }.textInputAutocapitalization(.never).autocorrectionDisabled()
      Section {
        Button("Continue") {
          do {
            select(try WorkAccessConfiguration(name: draft.name, receiver: WorkServerSettings.address(draft.address),
              issuer: draft.issuer.trimmingCharacters(in: .whitespacesAndNewlines),
              keyID: draft.keyID.trimmingCharacters(in: .whitespacesAndNewlines),
              publicKey: draft.publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
              network: draft.tailscale ? .tailscale : nil))
          } catch { self.error = "Check the HTTPS address and public verification settings supplied by your administrator." }
        }.disabled(draft.address.isEmpty || draft.issuer.isEmpty || draft.keyID.isEmpty || draft.publicKey.isEmpty)
      }
      if let error { Section { Text(error).foregroundStyle(.red) } }
    }.navigationTitle("Manual setup").navigationBarTitleDisplayMode(.inline)
      .onChange(of: draft.address) { old, new in
        if !old.isEmpty, (try? WorkServerSettings.address(old)) != (try? WorkServerSettings.address(new)) {
          draft.issuer = ""; draft.keyID = ""; draft.publicKey = ""
        }
      }
  }
}
