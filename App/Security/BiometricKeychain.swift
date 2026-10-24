import Foundation
import LocalAuthentication
import Security
import ZenithKit

/// Device-only opt-in secret. No iCloud sync, plaintext app storage, passcode
/// fallback, recovery export, or authentication reuse for this Keychain item.
@MainActor final class BiometricKeychain: BiometricCredentialStore {
  private let service = "ca.zenith.wallet.biometric-unlock.v1"
  private let preference = "wallet.biometric-unlock.enabled.v1"
  private var context: LAContext?
  var isEnabled: Bool { UserDefaults.standard.bool(forKey: preference) }

  static var label: String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return context.biometryType == .touchID ? "Touch ID" : "Face ID"
  }
  static var available: Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }
  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: "wallet",
     kSecAttrSynchronizable as String: false]
  }
  private func authenticate() async throws -> LAContext {
    let authentication = LAContext()
    authentication.localizedFallbackTitle = ""
    authentication.touchIDAuthenticationAllowableReuseDuration = 0
    guard authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
      throw BiometricUnlockError.unavailable
    }
    context = authentication
    do {
      guard try await authentication.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Unlock your Zenith wallet on this device.") else { throw BiometricUnlockError.cancelled }
      try Task.checkCancellation()
      guard context === authentication else { throw BiometricUnlockError.cancelled }
      return authentication
    } catch {
      authentication.invalidate()
      if context === authentication { context = nil }
      throw BiometricUnlockError.cancelled
    }
  }
  func save(_ credential: BiometricCredential) async throws {
    let authentication = try await authenticate()
    defer { authentication.invalidate(); context = nil }
    var encoded = try JSONEncoder().encode(credential)
    defer { encoded.resetBytes(in: 0..<encoded.count) }
    guard encoded.count <= 16_384 else { throw BiometricUnlockError.storage }
    var failure: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(nil,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &failure) else {
      throw BiometricUnlockError.storage
    }
    try Task.checkCancellation()
    try remove()
    var item = query
    item[kSecAttrAccessControl as String] = access
    item[kSecUseAuthenticationContext as String] = authentication
    item[kSecValueData as String] = encoded
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw BiometricUnlockError.storage }
    // This preference is only a UI hint. Retrieval always authenticates in Keychain.
    UserDefaults.standard.set(true, forKey: preference)
  }
  func read() async throws -> BiometricCredential {
    let authentication = try await authenticate()
    defer { authentication.invalidate(); context = nil }
    var item = query
    item[kSecUseAuthenticationContext as String] = authentication
    item[kSecReturnData as String] = true
    item[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(item as CFDictionary, &result)
    guard status == errSecSuccess, var data = result as? Data else {
      if status == errSecItemNotFound { UserDefaults.standard.set(false, forKey: preference) }
      throw BiometricUnlockError.missing
    }
    defer { data.resetBytes(in: 0..<data.count) }
    guard data.count <= 16_384, let credential = try? JSONDecoder().decode(BiometricCredential.self, from: data) else {
      throw BiometricUnlockError.missing
    }
    return credential
  }
  func remove() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw BiometricUnlockError.storage }
    UserDefaults.standard.set(false, forKey: preference)
  }
  func cancel() { context?.invalidate(); context = nil }
}
