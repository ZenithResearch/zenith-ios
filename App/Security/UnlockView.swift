import SwiftUI
import ZenithKit

struct UnlockView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var password = ""
  @State private var saveWithBiometrics = false
  @State private var usePassword = false
  private var showPassword: Bool { usePassword || !model.biometricEnabled }
  var body: some View {
    NavigationStack {
      WalletFlowPage(step: "Welcome back", title: "Unlock your wallet",
        detail: "Your wallet stays on this iPhone.",
        buttonTitle: showPassword ? "Unlock" : "Unlock with \(BiometricKeychain.label)",
        enabled: !showPassword || !password.isEmpty, busy: model.busy, action: unlock) {
          if showPassword {
            WalletPasswordField(title: "Wallet password", text: $password)
            if BiometricKeychain.available && !model.biometricEnabled {
              Toggle("Use \(BiometricKeychain.label) next time", isOn: $saveWithBiometrics)
              if saveWithBiometrics { Text(BiometricSetupExplanation.text).font(.footnote).foregroundStyle(.secondary) }
            }
            Text("Use Password AutoFill above the keyboard to choose a password saved in your password manager.")
              .font(.footnote).foregroundStyle(.secondary)
          } else {
            Image(systemName: BiometricKeychain.label == "Touch ID" ? "touchid" : "faceid")
              .font(.system(size: 56)).foregroundStyle(.tint).accessibilityHidden(true)
            Button("Use wallet password") { usePassword = true }
          }
          Feedback()
        }.onChange(of: model.generation) { _, _ in password = ""; saveWithBiometrics = false }
          .onDisappear { password = "" }
    }
  }
  private func unlock() {
    if !showPassword {
      model.perform({ try await model.biometricUnlock.unlock(repository: $0) }) { _ in }
    } else {
      let value = password
      let save = saveWithBiometrics
      password = ""
      model.perform({ repository in
        if save { return try await model.biometricUnlock.enable(password: value, repository: repository) }
        return try await repository.unlock(password: value)
      }) { _ in }
    }
  }
}

enum BiometricSetupExplanation {
  static let text = "Saves your wallet password in this iPhone’s protected Keychain. Only Face ID or Touch ID can release it; it isn’t synced or included in backups. Keep your password and recovery file."
}

struct WalletSecurityView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var password = ""
  var body: some View {
    Form {
      Section {
        Label(model.biometricEnabled ? "Biometric unlock is on" : "Unlock with \(BiometricKeychain.label)",
          systemImage: BiometricKeychain.label == "Touch ID" ? "touchid" : "faceid")
        Text(BiometricSetupExplanation.text).font(.subheadline).foregroundStyle(.secondary)
        if model.biometricEnabled {
          Button("Turn off biometric unlock") {
            do { try model.biometricUnlock.disable(); model.biometricEnabled = false; model.notice = "Saved unlock password removed from this iPhone." }
            catch { model.error = error.localizedDescription }
          }.disabled(model.busy)
        } else if BiometricKeychain.available {
          SecureField("Current wallet password", text: $password).textContentType(.password)
            .accessibilityIdentifier("wallet.biometric.password")
          Button("Enable \(BiometricKeychain.label)") {
            let value = password
            password = ""
            model.perform({ try await model.biometricUnlock.enable(password: value, repository: $0) }) { _ in
              model.notice = "Biometric unlock is ready."
            }
          }.disabled(password.isEmpty || model.busy)
            .accessibilityIdentifier("wallet.biometric.enable")
        } else {
          Text("Set up Face ID or Touch ID in iPhone Settings, then return here.")
        }
      } footer: {
        Text("Changing enrolled biometrics requires setup again with your wallet password. Face ID unlocks the wallet; access approvals still need your confirmation.")
      }
      Section("Password manager") {
        Text("You can also save your wallet password in Apple Passwords or another password manager. Choose it using Password AutoFill when unlocking Zenith.")
        Text("Zenith doesn’t add it to a password manager automatically.").foregroundStyle(.secondary)
      }
      Section { Feedback() }
    }.navigationTitle("Unlock & security").navigationBarTitleDisplayMode(.inline)
      .onChange(of: model.generation) { _, _ in password = "" }
      .onDisappear { password = "" }
  }
}
