import SwiftUI
import ZenithKit

struct UnlockView: View {
  @EnvironmentObject private var model: WalletModel
  @Environment(\.scenePhase) private var scene
  @State private var password = ""
  @State private var saveWithBiometrics = false
  @State private var usePassword = false
  private var showPassword: Bool { usePassword || !model.biometricEnabled }
  private var automaticUnlockReady: Bool {
    scene == .active && !showPassword && !model.busy && !model.paused && !model.obscured
      && model.repository != nil && model.state?.configured == true && model.state?.unlocked == false
  }
  var body: some View {
    NavigationStack {
      WalletFlowPage(step: "Welcome back", title: "Unlock your wallet",
        detail: "Your wallet stays on this device.",
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
        }.onChange(of: automaticUnlockReady, initial: true) { _, ready in
            if model.automaticBiometricUnlock.claim(isPad: UIDevice.current.userInterfaceIdiom == .pad,
              touchID: BiometricKeychain.label == "Touch ID", enabled: model.biometricEnabled, ready: ready) {
              unlock()
            }
          }
          .onChange(of: model.generation) { _, _ in password = ""; saveWithBiometrics = false }
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
  static let text = "Saves your wallet password in this device’s protected Keychain. Only Face ID or Touch ID can release it; it isn’t synced or included in backups. Keep your password and recovery file."
}

struct WalletSecurityView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var password = ""
  var body: some View {
    Form {
      Section("Wallet lifetime") {
        Picker("Lock after inactivity", selection: $model.unlockDuration) {
          ForEach(WalletUnlockDuration.selectableCases.contains(model.unlockDuration) ? WalletUnlockDuration.selectableCases : [model.unlockDuration] + WalletUnlockDuration.selectableCases) { value in
            Text(value.label).tag(value)
          }
        }
        Text("The default is one hour without activity. Interacting with Zenith resets the timer; background reads and refreshes do not.")
        Text("You can lock it at any time. Quitting or iOS ending the app requires another unlock. Pending approvals are cancelled when Zenith enters the background; returning after the inactivity limit locks Wallet before continuing.").font(.footnote).foregroundStyle(.secondary)
      }
      Section {
        Label(model.biometricEnabled ? "Biometric unlock is on" : "Unlock with \(BiometricKeychain.label)",
          systemImage: BiometricKeychain.label == "Touch ID" ? "touchid" : "faceid")
        Text(BiometricSetupExplanation.text).font(.subheadline).foregroundStyle(.secondary)
        if model.biometricEnabled {
          Button("Turn off biometric unlock") {
            do { try model.biometricUnlock.disable(); model.biometricEnabled = false; model.notice = "Saved unlock password removed from this device." }
            catch { model.error = error.localizedDescription }
          }.disabled(model.busy)
        } else if BiometricKeychain.available {
          WalletPasswordField(title: "Current wallet password", text: $password)
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
          Text("Set up Face ID or Touch ID in Settings, then return here.")
        }
      } footer: {
        Text("On an iPad with Touch ID, Zenith asks automatically once when opening a locked Wallet. On iPhone, use the unlock button. After cancellation or Lock wallet, use the button to try again. Access approvals still need your confirmation. Changing enrolled biometrics requires setup again with your wallet password.")
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
