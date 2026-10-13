import XCTest

@testable import ZenithKit

private final class ResponseProtocol: URLProtocol {
  static let guardLock = NSLock()
  static var handler: ((URLRequest) -> (Int, Data))?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.guardLock.lock()
    let handler = Self.handler
    Self.guardLock.unlock()
    guard let handler else { return }
    let (status, data) = handler(request)
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Length": String(data.count)])
    else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
final class TransportTests: XCTestCase {
  func testReadConnectionRequiresSeparateIssuerPin() throws {
    let old = Data(#"{"name":"Work","issuer":"example","receiver":"https://example.test"}"#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(WorkAccessConfiguration.self, from: old))
    var value: [String: Any] = ["name":"Work", "issuer":"example", "receiver":"https://example.test",
      "authority":["issuer":"example", "key_id":"read-key", "public_key":String(repeating:"12", count:32),
      "receiver":"https://example.test", "audience":"devgraph"]]
    let config = try JSONDecoder().decode(WorkAccessConfiguration.self, from: JSONSerialization.data(withJSONObject: value))
    XCTAssertNoThrow(try config.validate())
    XCTAssertNil(config.network)
    value["network"] = "tailscale"
    let privateConfig = try JSONDecoder().decode(WorkAccessConfiguration.self, from: JSONSerialization.data(withJSONObject: value))
    XCTAssertEqual(privateConfig.network, .tailscale)
    XCTAssertNoThrow(try privateConfig.validate())
    value["receiver"] = "https://other.test"
    let wrong = try JSONDecoder().decode(WorkAccessConfiguration.self, from: JSONSerialization.data(withJSONObject: value))
    XCTAssertThrowsError(try wrong.validate())
  }
  private func transport(status: Int, data: Data) -> PrivateTransport {
    ResponseProtocol.guardLock.lock()
    ResponseProtocol.handler = { _ in (status, data) }
    ResponseProtocol.guardLock.unlock()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ResponseProtocol.self]
    return PrivateTransport(configuration: configuration)
  }
  func testRejectsPlainHTTPBeforeDispatch() async throws {
    let client = transport(status: 200, data: Data())
    do {
      _ = try await client.request(URLRequest(url: URL(string: "http://example.test")!))
      XCTFail("HTTP must fail")
    } catch { XCTAssertEqual(error as? WalletFailure, .core("service_setup_required")) }
  }
  func testRejectsOversizedResponseAndRedactsDenial() async throws {
    let url = URL(string: "https://example.test")!
    do {
      _ = try await transport(status: 200, data: Data(repeating: 65, count: 33)).request(
        URLRequest(url: url), maximum: 32)
      XCTFail("Unbounded response")
    } catch { XCTAssertEqual(error as? WalletFailure, .invalidFile) }
    do {
      _ = try await transport(status: 401, data: Data("sensitive server detail".utf8)).request(
        URLRequest(url: url))
      XCTFail("Denied response")
    } catch {
      XCTAssertEqual(error as? WalletFailure, .core("access_denied"))
      XCTAssertFalse(error.localizedDescription.contains("sensitive"))
    }
  }
  func testRedirectIsNeverAcceptedAsCredentialResponse() async throws {
    do {
      _ = try await transport(status: 302, data: Data()).request(
        URLRequest(url: URL(string: "https://example.test")!))
      XCTFail("Redirect accepted")
    } catch { XCTAssertEqual(error as? WalletFailure, .core("service_rejected_request")) }
  }
  func testRejectsMutationScopeBeforeConsent() throws {
    let data = Data(
      #"{"scope":"devgraph.work.read","operations":["transition"],"relationship_types":["parent"],"work_kinds":["Task"],"include_archived":false}"#
        .utf8)
    let grant = try JSONDecoder().decode(WorkReadGrant.self, from: data)
    XCTAssertThrowsError(try grant.validate())
  }
  func testConnectionProbeSendsNoIdentityOrCredential() async throws {
    ResponseProtocol.guardLock.lock()
    ResponseProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://example.test/devgraph/native-read/v2/requests")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
      XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
      var body = request.httpBody ?? Data()
      if let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 64)
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count > 0 { body = Data(buffer.prefix(count)) }
      }
      XCTAssertEqual(body, Data("{}".utf8))
      return (401, Data(#"{"error":"access_denied"}"#.utf8))
    }
    ResponseProtocol.guardLock.unlock()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ResponseProtocol.self]
    try await PrivateTransport(configuration: configuration).checkReadReceiver(at: URL(string: "https://example.test")!)
  }
  func testConnectionProbeRejectsWrongServiceRedirectAndOversizedResponse() async throws {
    for (status, body) in [(200, Data()), (302, Data()), (503, Data()),
      (401, Data(#"{"error":"other_service"}"#.utf8)), (401, Data(repeating: 65, count: 1025))] {
      do {
        try await transport(status: status, data: body).checkReadReceiver(at: URL(string: "https://example.test")!)
        XCTFail("Unexpected probe success for \(status)")
      } catch { XCTAssertTrue(error is WalletFailure) }
    }
  }
  func testNetworkGuidanceDoesNotMisdiagnoseTLSOrCancellation() {
    let timeout = WorkConnectionFailure(code: .timedOut, network: .tailscale)
    XCTAssertTrue(timeout.localizedDescription.contains("Open Tailscale"))
    let publicTimeout = WorkConnectionFailure(code: .timedOut, network: nil)
    XCTAssertFalse(publicTimeout.localizedDescription.contains("Tailscale"))
    let certificate = WorkConnectionFailure(code: .serverCertificateUntrusted, network: .tailscale)
    XCTAssertTrue(certificate.localizedDescription.contains("could not be verified"))
    let cancelled = WorkConnectionFailure(code: .cancelled, network: .tailscale)
    XCTAssertFalse(cancelled.localizedDescription.contains("Can’t reach"))
  }

}
