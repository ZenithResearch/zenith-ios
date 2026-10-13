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
}
