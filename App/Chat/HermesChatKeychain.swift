import Foundation
import Security
import ZenithKit

/// Separate, device-only chat authorization. Never touches Wallet custody.
enum HermesChatKeychain {
  static var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "ca.zenith.hermes-chat.v1",
      kSecAttrAccount as String: "gateway",
      kSecAttrSynchronizable as String: false,
    ]
  }
  static func load() throws -> HermesChatSettings? {
    var item = query
    item[kSecReturnData as String] = true
    item[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(item as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, var data = result as? Data, data.count <= 16_384 else {
      throw HermesChatError.storage
    }
    defer { data.resetBytes(in: 0..<data.count) }
    let settings = try JSONDecoder().decode(HermesChatSettings.self, from: data)
    try settings.connection.validate()
    try HermesChatConnection.validateKey(settings.key)
    return settings
  }
  static func save(_ value: HermesChatSettings) throws {
    var data = try JSONEncoder().encode(value)
    defer { data.resetBytes(in: 0..<data.count) }
    guard data.count <= 16_384 else { throw HermesChatError.storage }
    let status = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
        throw HermesChatError.storage
      }
    } else if status != errSecSuccess {
      throw HermesChatError.storage
    }
  }
  static func remove() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw HermesChatError.storage
    }
  }
}
