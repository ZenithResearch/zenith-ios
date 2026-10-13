import SwiftUI
import ZenithKit

/// Import owns its navigation and transient passwords. It only prepares once
/// all inputs are collected; Rust authenticates before the review can appear.
struct RestoreView: View {
  private enum Step: Int { case choose = 1, backup, localPassword, review }
  @EnvironmentObject private var model: WalletModel
  @Environment(\.dismiss) private var dismiss
  @State private var step = Step.choose
  @State private var scanInitially: Bool
  @State private var fileName = "Recovery backup"
  @State private var filePassword = ""
  @State private var password = ""
  @State private var confirmation = ""
  @State private var dataPassword = ""
  @State private var dataName = "Castaway data"
  @State private var addingData = false
  @State private var trustApproved = false
  @State private var preview: RestorePreview?
  @State private var awaitingOperation = false

  init(startWithScanner: Bool = false) { _scanInitially = State(initialValue: startWithScanner) }
  var body: some View {
    VStack(spacing: 0) {
      switch step {
      case .choose: choosePage
      case .backup: backupPage
      case .localPassword: passwordPage
      case .review: reviewPage
      }
    }.navigationTitle("Import wallet").navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: back) { Label("Back", systemImage: "chevron.left") }
        }
      }
      .sheet(isPresented: $addingData) {
        RestoreDataAttachmentSheet(trustApproved: $trustApproved) { file, name, secret in
          model.dataSelection = file; dataName = name; dataPassword = secret
        }
      }
      .onAppear {
        if model.recoverySelection != nil && step == .choose { scanInitially = false; step = .backup }
      }
      .onChange(of: model.generation) { _, _ in
        clearPasswords(); preview = nil; awaitingOperation = false; trustApproved = false
        step = model.recoverySelection == nil ? .choose : .backup
      }
      .onChange(of: model.error) { _, error in
        if error != nil && awaitingOperation {
          awaitingOperation = false; preview = nil; step = .backup
        }
      }
      .onDisappear { clearPasswords(); model.cancel() }
  }

  private var choosePage: some View {
    WalletFlowPage(step: "Import · 1 of 4", title: "Scan your recovery backup",
      detail: "Open Zenith Transfer on your laptop and select your recovery file. Its QR carries the encrypted backup.") {
        WalletFilePicker(primary: .scan, startWithScanner: scanInitially, receive: receiveRecovery)
          .onDisappear { scanInitially = false }
        Text("Your backup stays encrypted until you enter its password on this phone.")
          .font(.footnote).foregroundStyle(.secondary)
        Feedback()
        NavigationLink("I have an older recovery key") { LegacyRecoveryView() }
          .font(.footnote).frame(minHeight: 44)
      }
  }
  private var backupPage: some View {
    WalletFlowPage(step: "Import · 2 of 4", title: "Enter the backup password",
      detail: "Use the password you chose when you saved this file.", buttonTitle: "Continue",
      enabled: !filePassword.isEmpty && (model.dataSelection == nil || !dataPassword.isEmpty),
      busy: model.busy, action: { model.error = nil; step = .localPassword }) {
        WalletSelectedFile(title: fileName, change: { changeRecovery() })
        WalletPasswordField(title: "Backup password", text: $filePassword)
        if model.dataSelection != nil {
          WalletSelectedFile(title: dataName, detail: "Optional data file", change: {
            model.dataSelection = nil; dataPassword = ""; addingData = true
          })
          if dataPassword.isEmpty {
            WalletPasswordField(title: "Data file password", text: $dataPassword)
          }
          Button("Remove data file") { model.dataSelection = nil; dataPassword = "" }
        } else {
          Button("Add a data file (optional)") { addingData = true }.frame(minHeight: 44)
          Text("You can also add your profile and membership data after importing your wallet.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Feedback()
      }
  }
  private var passwordPage: some View {
    WalletFlowPage(step: "Import · 3 of 4", title: "A password for this phone",
      detail: "Choose how to unlock the imported wallet here. Your original backup stays unchanged.",
      buttonTitle: "Review wallet", enabled: password.count >= 12 && password == confirmation,
      busy: model.busy, action: prepare) {
        WalletPasswordField(title: "New wallet password", prompt: "At least 12 characters", text: $password, isNew: true)
        WalletPasswordField(title: "Repeat wallet password", text: $confirmation, isNew: true)
        Text(!confirmation.isEmpty && confirmation != password ? "The passwords don’t match yet." : "Use at least 12 characters.")
          .font(.footnote).foregroundStyle(.secondary)
        Text("Next, we’ll check your backup and show the wallet before anything is imported.")
          .font(.footnote).foregroundStyle(.secondary)
        Feedback()
      }
  }
  private var reviewPage: some View {
    WalletFlowPage(step: "Import · 4 of 4", title: "Review your wallet",
      detail: "Your backup has been checked. Confirm to save this wallet on your phone.",
      buttonTitle: "Import wallet", enabled: preview != nil, busy: model.busy, action: commit) {
        if let preview {
          VStack(alignment: .leading, spacing: 20) { PreviewRows(preview: preview) }
            .padding(20).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
          Text("Importing does not activate memberships or connect work access.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Feedback()
      }
  }
  private func receiveRecovery(_ file: Data, _ name: String) {
    do {
      guard try RecoveryFileFormat.inspect(file, filename: name).kind == .recovery else {
        model.error = "This is a Castaway data file. Choose a recovery backup first; you can add data in the next step."; return
      }
      model.recoverySelection = file; fileName = name; filePassword = ""
      model.error = nil; scanInitially = false; step = .backup
    } catch { model.error = "That recovery file could not be read. Choose another backup." }
  }
  private func prepare() {
    guard let file = model.recoverySelection else { return }
    let fileSecret = filePassword, localSecret = password
    let data = model.dataSelection, dataSecret = data == nil ? nil : dataPassword
    clearPasswords(); awaitingOperation = true
    model.perform({ try await $0.prepareRestore(file: file, filePassword: fileSecret,
      password: localSecret, dataFile: data, dataPassword: dataSecret) }) {
        preview = $0; awaitingOperation = false; step = .review
      }
  }
  private func commit() {
    guard let preview else { return }
    awaitingOperation = true
    model.perform({ try await $0.commit(preview) }) { _ in
      awaitingOperation = false
      model.recoverySelection = nil; model.dataSelection = nil
      model.onboardingCompletion = .imported
    }
  }
  private func back() {
    if model.busy { model.cancel(); return }
    switch step {
    case .choose: model.recoverySelection = nil; model.dataSelection = nil; dismiss()
    case .backup: changeRecovery()
    case .localPassword: password = ""; confirmation = ""; step = .backup
    case .review: model.cancel(); preview = nil; step = .backup
    }
  }
  private func changeRecovery() {
    model.recoverySelection = nil; model.dataSelection = nil
    clearPasswords(); model.cancel(); scanInitially = false; step = .choose
  }
  private func clearPasswords() { filePassword = ""; password = ""; confirmation = ""; dataPassword = "" }
}
