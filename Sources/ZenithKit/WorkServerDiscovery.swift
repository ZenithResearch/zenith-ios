import Foundation

/// Fetch only public verification settings. Discovery sends no Wallet identity
/// and cannot save settings, install trust, or grant access.
public enum WorkServerDiscovery {
  public static func discover(_ address: String, transport: PrivateTransport = PrivateTransport()) async throws -> WorkAccessConfiguration {
    let origin = try WorkServerSettings.address(address)
    let url = origin.appendingPathComponent(".well-known/devgraph-connection.json")
    let data = try await transport.request(URLRequest(url: url), maximum: WorkServerSettings.maximumFileBytes)
    let configuration = try WorkServerSettings.decode(data)
    guard configuration.origin == origin.absoluteString, configuration.network == nil else {
      throw WorkServerSetupError.profile
    }
    return configuration
  }
}
