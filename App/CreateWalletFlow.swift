import SwiftUI

/// Creation never passes through the recovery-import screen.
struct CreateView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var password = ""
  @State private var confirmation = ""
  var body: some View {
    WalletFlowPage(step: "Create · 1 of 3", title: "A password for this phone",
      detail: "This unlocks your wallet here. Next, you’ll save and check a recovery backup.",
      buttonTitle: "Create wallet", enabled: password.count >= 12 && password == confirmation,
      busy: model.busy, action: create) {
        WalletPasswordField(title: "Wallet password", prompt: "At least 12 characters", text: $password, isNew: true)
        WalletPasswordField(title: "Repeat wallet password", text: $confirmation, isNew: true)
        Text(!confirmation.isEmpty && confirmation != password ? "The passwords don’t match yet." : "Use at least 12 characters.")
          .font(.footnote).foregroundStyle(.secondary)
        Feedback()
      }.navigationTitle("Create a wallet")
        .onChange(of: model.generation) { _, _ in clear() }
        .onDisappear { clear() }
  }
  private func create() {
    let secret = password
    clear()
    model.perform({ try await $0.create(password: secret) }) { _ in model.notice = nil }
  }
  private func clear() { password = ""; confirmation = "" }
}
