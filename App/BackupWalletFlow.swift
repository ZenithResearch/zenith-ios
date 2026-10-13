import SwiftUI
import ZenithKit

/// The create branch resumes here after its identity has been durably created.
/// Verification still commits through the same Rust/SQLite boundary.
struct BackupFlowView: View {
  let isOnboarding: Bool
  @EnvironmentObject private var model: WalletModel
  @State private var checking = false
  @State private var password = ""
  @State private var confirmation = ""
  @State private var filePassword = ""
  @State private var fileName = "Saved recovery file"
  @State private var document: EncryptedFile?
  @State private var exporting = false
  init(isOnboarding: Bool, startsChecking: Bool = false) {
    self.isOnboarding = isOnboarding
    _checking = State(initialValue: startsChecking)
  }
  var body: some View {
    VStack(spacing: 0) {
      if checking { checkPage } else { savePage }
    }.navigationTitle(isOnboarding ? "Create a wallet" : "Recovery")
      .toolbar {
        if isOnboarding {
          ToolbarItem(placement: .topBarTrailing) { Button("Lock") { model.suspend() } }
        }
      }
      .fileExporter(isPresented: $exporting, document: document, contentType: .castaliaRecovery,
        defaultFilename: "Castalia.castalia-recovery") { result in
          document = nil
          switch result {
          case .success:
            model.recoverySelection = nil
            model.error = nil
            checking = true
          case .failure:
            model.error = "The backup was not saved. Try again when you’re ready."
          }
        }
      .onChange(of: model.generation) { _, _ in clear(); document = nil }
      .onDisappear { clear() }
  }
  private var savePage: some View {
    WalletFlowPage(step: isOnboarding ? "Create · 2 of 3" : "Recovery backup",
      title: "Save your recovery backup",
      detail: "This file lets you restore your wallet on another device. Give it a password you can keep safe.",
      buttonTitle: "Save recovery file", enabled: password.count >= 12 && password == confirmation,
      busy: model.busy, action: export) {
        WalletPasswordField(title: "Backup password", prompt: "At least 12 characters", text: $password, isNew: true)
        WalletPasswordField(title: "Repeat backup password", text: $confirmation, isNew: true)
        Text(!confirmation.isEmpty && confirmation != password ? "The passwords don’t match yet."
          : "This can be different from your wallet password. Keep the file and password safe; Zenith cannot recover them for you.")
          .font(.footnote).foregroundStyle(.secondary)
        Button("I already have a saved backup") { clear(); checking = true; model.error = nil }
          .frame(minHeight: 44)
        Feedback()
      }
  }
  private var checkPage: some View {
    WalletFlowPage(step: isOnboarding ? "Create · 3 of 3" : "Check your backup",
      title: "Check the file you saved",
      detail: "Select that file and enter its backup password. We’ll check that it can restore this wallet.",
      buttonTitle: model.recoverySelection == nil ? nil : "Check recovery file",
      enabled: !filePassword.isEmpty, busy: model.busy, action: verify) {
        if model.recoverySelection == nil {
          WalletFilePicker { file, name in
            do {
              guard try RecoveryFileFormat.inspect(file, filename: name).kind == .recovery else {
                model.error = "Choose a recovery backup. A Castaway data file cannot restore your wallet."; return
              }
              model.recoverySelection = file
              fileName = name
              filePassword = ""
              model.error = nil
            } catch { model.error = "That recovery file could not be read." }
          }
        } else {
          WalletSelectedFile(title: fileName) { model.recoverySelection = nil; filePassword = "" }
          WalletPasswordField(title: "Backup password", text: $filePassword)
        }
        Button("Save a new backup instead") { clear(); model.error = nil; checking = false }
          .frame(minHeight: 44)
        Feedback()
      }
  }
  private func export() {
    let secret = password
    clear()
    model.perform({ try await $0.exportRecovery(password: secret) }) {
      document = EncryptedFile(data: $0)
      exporting = true
    }
  }
  private func verify() {
    guard let file = model.recoverySelection else { return }
    let secret = filePassword
    filePassword = ""
    model.perform({ try await $0.verifyBackup(file: file, password: secret) }) { _ in
      model.recoverySelection = nil
      if isOnboarding { model.onboardingCompletion = .created }
      else { model.notice = "Recovery checked. This backup restores your wallet." }
    }
  }
  private func clear() { password = ""; confirmation = ""; filePassword = "" }
}
