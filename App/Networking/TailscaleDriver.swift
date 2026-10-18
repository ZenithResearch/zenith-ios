import Foundation
import Network
import TailscaleKit
import ZenithKit

/// The only adapter that knows TailscaleKit. No Wallet data enters this actor.
/// Node keys live in an installation-local protected, backup-excluded directory.
actor TailscaleDriver: PrivateNetworkDriver {
  private var node: TailscaleNode?
  private var controlSession: URLSession?
  private var interactiveLoginPending = false

  func start(interactive: Bool) async throws {
    guard node == nil else { throw PrivateNetworkError.interrupted }
    let base = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    var directory = base.appendingPathComponent("PrivateNetwork", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
    var resources = URLResourceValues()
    resources.isExcludedFromBackup = true
    try directory.setResourceValues(resources)
    let config = Configuration(hostName: "zenith-ios", path: directory.path,
      authKey: nil, controlURL: kDefaultControlURL, ephemeral: false)
    let created = try TailscaleNode(config: config, logger: QuietTailscaleLogger())
    node = created
    interactiveLoginPending = interactive
    try await command(.run, node: created)
    try Task.checkCancellation()
    _ = try await status()
  }
  func stop() async {
    interactiveLoginPending = false
    controlSession?.invalidateAndCancel()
    controlSession = nil
    let previous = node
    node = nil
    // Do not use upstream down(): the pinned wrapper incorrectly calls up().
    // Closing also discards its cached loopback listener before foreground reuse.
    try? await previous?.close()
  }
  func status() async throws -> PrivateNetworkStatus {
    guard let node else { throw PrivateNetworkError.disconnected }
    let status = try PrivateNetworkStatus(data: await node.statusJSON())
    // Startup may report NoState/Stopped before NeedsLogin. Keep the explicit
    // user intent until the polling loop sees that state; foreground resume
    // never requests interactive login. Consume before awaiting to avoid repeats.
    if interactiveLoginPending && status.phase == .signInRequired {
      interactiveLoginPending = false
      try await command(.signIn, node: node)
      return try PrivateNetworkStatus(data: await node.statusJSON())
    }
    if status.phase == .connected { interactiveLoginPending = false }
    return status
  }
  func configuration() async throws -> URLSessionConfiguration {
    guard let node else { throw PrivateNetworkError.disconnected }
    let config = URLSessionConfiguration.ephemeral
    try await config.proxyVia(node)
    // Explicitly prohibit clear/direct fallback, including when the local SOCKS
    // listener is reclaimed or the private network becomes unavailable.
    var proxies = config.proxyConfigurations
    guard proxies.count == 1 else {
      throw PrivateNetworkError.invalidStatus
    }
    proxies[0].allowFailover = false
    config.proxyConfigurations = proxies
    return config
  }

  private enum Command { case run, signIn }
  private func command(_ command: Command, node: TailscaleNode) async throws {
    let config = URLSessionConfiguration.ephemeral
    let loopback = try await config.proxyVia(node)
    guard loopback.ip == "127.0.0.1", let port = loopback.port, (1...65535).contains(port) else {
      throw PrivateNetworkError.invalidStatus
    }
    config.httpCookieStorage = nil
    config.urlCredentialStorage = nil
    config.urlCache = nil
    config.httpShouldSetCookies = false
    config.timeoutIntervalForRequest = 10
    config.timeoutIntervalForResource = 10
    let session = URLSession(configuration: config, delegate: LocalControlRedirectBlocker(), delegateQueue: nil)
    controlSession = session
    defer { session.invalidateAndCancel(); controlSession = nil }
    let path = command == .run ? "prefs" : "login-interactive"
    let url = URL(string: "http://127.0.0.1:\(port)/localapi/v0/\(path)")!
    var request = URLRequest(url: url)
    request.httpMethod = command == .run ? "PATCH" : "POST"
    request.setValue("Basic " + Data("tsnet:\(loopback.localAPIKey)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
    request.setValue("localapi", forHTTPHeaderField: "Sec-Tailscale")
    if command == .run {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = Data(#"{"WantRunning":true,"WantRunningSet":true,"ShieldsUp":true,"ShieldsUpSet":true,"RouteAll":false,"RouteAllSet":true}"#.utf8)
    }
    let (bytes, response) = try await session.bytes(for: request)
    guard let response = response as? HTTPURLResponse, response.url == url,
      (200..<300).contains(response.statusCode), response.expectedContentLength <= 65_536
    else { throw PrivateNetworkError.invalidStatus }
    var size = 0
    for try await _ in bytes {
      size += 1
      guard size <= 65_536 else { throw PrivateNetworkError.invalidStatus }
    }
  }
}
private struct QuietTailscaleLogger: LogSink {
  var logFileHandle: Int32? { -1 }
  func log(_ message: String) {}
}
private final class LocalControlRedirectBlocker: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
