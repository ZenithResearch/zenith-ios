import SwiftUI
import ZenithKit

/// Application-only Tailscale settings and preserved read-only legacy records.
struct WalletIdentitiesView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var editing: IdentityAccount?
  @State private var adding = false
  @State private var removing: IdentityAccount?
  var body: some View {
    List {
      Section {
        NavigationLink("Open Wallet identities") {
          PortableWalletIdentitiesView(repository: model.repository, unlocked: model.state?.unlocked == true,
            legacy: model.identityAccounts, changed: { Task { await model.load() } })
        }
        Text("Matrix, Nostr, GitHub and X identities are managed in Wallet and included in new Castaway backups.").font(.footnote).foregroundStyle(.secondary)
        if model.state?.unlocked != true {
          NavigationLink("Unlock Wallet") { UnlockView() }
        }
      }
      Section("Tailscale · Application settings") {
        let accounts = model.identityAccounts.filter { $0.provider == .tailscale }
        if accounts.isEmpty { Text("No Tailscale account saved").foregroundStyle(.secondary) }
        ForEach(accounts) { account in
          VStack(alignment: .leading, spacing: 8) {
            Text(account.label).font(.headline)
            Text(account.identifier).textSelection(.enabled)
            Text(account.server).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
              Button("Edit account") { editing = account }
              Spacer()
              Button("Remove…", role: .destructive) { removing = account }
            }.buttonStyle(.borderless).disabled(model.state?.unlocked != true)
          }.padding(.vertical, 8)
        }
        Button("Add Tailscale account") { adding = true }.disabled(model.state?.unlocked != true)
        Text("Public details only. These application settings are not included in Wallet backups. Saving does not connect Tailscale or store authentication secrets.").font(.footnote).foregroundStyle(.secondary)
      }
      Section { LegacyWalletIdentityRecordsView(records: model.identityAccounts) }
      Section { Feedback() }
    }.navigationTitle("Application accounts").navigationBarTitleDisplayMode(.inline)
      .onAppear { model.reloadIdentityAccounts() }
      .sheet(isPresented: $adding) { WalletIdentityEditor(original: nil) }
      .sheet(item: $editing) { WalletIdentityEditor(original: $0) }
      .confirmationDialog("Remove this Tailscale record?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
        Button("Remove account", role: .destructive) {
          do { try model.saveIdentityAccount(nil, replacing: removing); removing = nil }
          catch { model.error = (error as? IdentityAccountError)?.errorDescription ?? "Unlock the same Wallet before changing accounts." }
        }
      } message: { Text("This removes only the local record. It does not sign out or revoke access.") }
  }
}

private struct WalletIdentityEditor: View {
  @EnvironmentObject private var model: WalletModel
  @Environment(\.dismiss) private var dismiss
  private let provider = IdentityProvider.tailscale
  let original: IdentityAccount?
  @State private var label = ""
  @State private var identifier = ""
  @State private var server = ""
  @State private var owner: String?
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Display name", text: $label)
          TextField(provider == .matrix ? "Matrix ID (@name:server)" : provider == .nostr ? "Public key (64 lowercase hex characters)" : "Account name", text: $identifier)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
          TextField(provider == .matrix ? "Homeserver (https://…)" : provider == .nostr ? "Optional relay (wss://…)" : "Tailnet DNS name (name.ts.net)", text: $server)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
        } footer: { Text("Public details only. Saving does not authenticate this account or grant access.") }
        if let error { Section { Text(error).foregroundStyle(.red) } }
      }.navigationTitle(original == nil ? "Add \(provider.title) account" : "Edit \(provider.title) account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              do {
                guard let owner, owner == model.state?.publicKey else { throw WalletFailure.locked }
                let value = try IdentityAccount(id: original?.id ?? UUID(), walletPublicKey: owner, provider: provider, label: label, identifier: identifier, server: server)
                try model.saveIdentityAccount(value, replacing: original); dismiss()
              } catch { self.error = (error as? IdentityAccountError)?.errorDescription ?? "Unlock the same Wallet before saving." }
            }.disabled(model.state?.unlocked != true || label.isEmpty || identifier.isEmpty)
          }
        }
        .onAppear { owner = model.state?.publicKey; label = original?.label ?? ""; identifier = original?.identifier ?? ""; server = original?.server ?? "" }
    }
  }
}
