#if os(macOS)
import AppKit
import SwiftUI
import ZenithKit

struct TransferWalletView: View {
  @ObservedObject var model: TransferModel
  @State private var password = ""
  @State private var confirmation = ""
  @State private var filePassword = ""
  @State private var selectedFile: Data?
  @State private var selectedName: String?
  @State private var preview: ImportReview?
  @State private var committing = false
  @State private var mode = "import"
  @State private var backupPassword = ""
  @State private var backupConfirmation = ""
  @State private var notice: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Transfer Wallet").font(.largeTitle.bold())
        Text("Your signing identity in this Mac app. Recovery files are decrypted only by the shared Castalia core.")
          .foregroundStyle(.secondary)
        if let state = model.wallet, state.configured {
          Text(state.unlocked ? "Wallet unlocked" : "Wallet locked").font(.title2.bold())
          Text(state.publicKey ?? "").font(.caption.monospaced()).textSelection(.enabled)
          if state.unlocked {
            Label(state.backupVerified ? "Recovery backup checked" : "Recovery backup needs checking",
              systemImage: state.backupVerified ? "checkmark.shield" : "externaldrive.badge.exclamationmark")
            Button("Lock Wallet") { clear(); model.lock() }
            Divider()
            Text("Recovery backup").font(.headline)
            SecureField("Backup file password", text: $backupPassword)
            SecureField("Confirm backup file password", text: $backupConfirmation)
            Button("Export encrypted recovery file…") { exportBackup() }
              .disabled(model.busy || backupPassword.isEmpty || backupPassword != backupConfirmation)
            Button("Check an existing backup…") { verifyBackup() }
              .disabled(model.busy || backupPassword.isEmpty)
            Text("Export saves an encrypted copy. Checking it confirms that the file can restore this Wallet.")
              .font(.callout).foregroundStyle(.secondary)
          } else {
            SecureField("Wallet unlock password", text: $password).onSubmit { unlock() }
            Button("Unlock Wallet") { unlock() }.buttonStyle(.borderedProminent)
              .disabled(model.busy || password.isEmpty)
          }
        } else if model.wallet != nil {
          Picker("Set up this app's Wallet", selection: $mode) {
            Text("Import recovery file").tag("import")
            Text("Create Wallet").tag("create")
          }.pickerStyle(.segmented).onChange(of: mode) { _ in clear() }
          if mode == "import" {
            Button(selectedName ?? "Choose encrypted recovery file…") { chooseRecovery() }
            SecureField("Recovery file password", text: $filePassword)
          }
          SecureField("New password for this Mac Wallet", text: $password)
          SecureField("Confirm new password", text: $confirmation)
          if mode == "create" {
            Button("Create this app's Wallet") { create() }.buttonStyle(.borderedProminent)
              .disabled(model.busy || password.isEmpty || password != confirmation)
            Text("A new identity will not inherit authority from any existing Wallet. Import your own recovery file to use your existing identity.")
              .font(.callout).foregroundStyle(.secondary)
          } else {
            Button("Review Wallet import") { prepareImport() }.buttonStyle(.borderedProminent)
              .disabled(model.busy || selectedFile == nil || filePassword.isEmpty || password.isEmpty || password != confirmation)
          }
        } else { ProgressView("Loading Wallet…") }
        if model.busy { ProgressView() }
        if let notice { Text(notice).foregroundStyle(.secondary) }
        Divider()
        Text("Grant approvals").font(.headline)
        Text("For now, approve grants using your browser's Wallet from Resources & requests. Native grant approvals are not available in Transfer yet. Unlocking here does not unlock Chrome.")
          .foregroundStyle(.secondary)
        Text("This app stores its encrypted Wallet separately from Zenith and Chrome. It locks when you leave the app and after five minutes. Passwords never enter the resource registry.")
          .font(.footnote).foregroundStyle(.secondary)
      }.frame(maxWidth: 640, alignment: .leading).padding(28)
    }.disabled(model.busy)
      .onDisappear { clear(); model.repository?.invalidatePendingWork(); Task { await model.repository?.cancel() } }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in clear() }
      .sheet(item: $preview, onDismiss: {
        if !committing {
          model.repository?.invalidatePendingWork()
          Task { await model.repository?.cancel() }
        }
      }) { item in
        let value = item.preview
        VStack(alignment: .leading, spacing: 20) {
          Text("Import this Wallet?").font(.title2.bold())
          Text("Castalia decrypted the recovery file. Confirm its public identity before saving this app's encrypted Wallet.")
          Text(value.publicKey).font(.caption.monospaced()).textSelection(.enabled)
          HStack {
            Button("Cancel") { preview = nil; model.repository?.invalidatePendingWork(); Task { await model.repository?.cancel() } }
            Spacer()
            Button("Import Wallet") {
              committing = true
              preview = nil
              model.perform({ try await $0.commit(value) }) { _ in notice = "Wallet imported on this Mac." }
            }.buttonStyle(.borderedProminent)
          }
        }.padding(24).frame(width: 560)
      }
  }
  private func clear() {
    password = ""; confirmation = ""; filePassword = ""
    backupPassword = ""; backupConfirmation = ""; selectedFile = nil; selectedName = nil; preview = nil
  }
  private func unlock() {
    guard !password.isEmpty else { return }; let secret = password; password = ""
    let lifecycle = model.repository?.lifecycleTicket()
    let identity = model.wallet?.publicKey
    model.perform { try await $0.unlock(password: secret, expectedLifecycle: lifecycle, expectedIdentity: identity) }
  }
  private func create() {
    let secret = password; clear()
    model.perform({ try await $0.create(password: secret) }) { _ in
      notice = "Wallet created. Export and check a recovery backup next."
    }
  }
  private func chooseRecovery() {
    guard let result = readEncryptedFile() else { return }
    selectedFile = result.0; selectedName = result.1
  }
  private func prepareImport() {
    guard let selectedFile else { return }
    let old = filePassword, new = password; clear()
    model.perform({ try await $0.prepareRestore(file: selectedFile, filePassword: old, password: new) }) {
      committing = false; preview = ImportReview(preview: $0)
    }
  }
  private func readEncryptedFile() -> (Data, String)? {
    let panel = NSOpenPanel(); panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    do { return (try EncryptedImportFile.read(url), url.lastPathComponent) }
    catch { model.error = "Choose a supported encrypted recovery file, no larger than 1 MiB."; return nil }
  }
  private func exportBackup() {
    let panel = NSSavePanel(); panel.nameFieldStringValue = "transfer-wallet.castalia-recovery"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let secret = backupPassword; backupPassword = ""; backupConfirmation = ""
    model.perform({ try await $0.exportRecovery(password: secret) }) { data in
      do {
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        notice = "Encrypted recovery file exported. Check the saved file before relying on it."
      } catch { model.error = "Could not save the encrypted backup." }
    }
  }
  private func verifyBackup() {
    guard let (data, _) = readEncryptedFile() else { return }
    let secret = backupPassword; backupPassword = ""; backupConfirmation = ""
    model.perform({ try await $0.verifyBackup(file: data, password: secret) }) { _ in
      notice = "Recovery file checked against this Wallet."
    }
  }
}

// A preview token remains opaque to the renderer and is accepted only by the
// core's original lifecycle/revision transaction.
private struct ImportReview: Identifiable {
  let id = UUID()
  let preview: RestorePreview
}
#endif
