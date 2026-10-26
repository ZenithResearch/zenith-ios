import XCTest
@testable import ZenithKit

final class TailnetServerDiscoveryTests: XCTestCase {
  func testOnlyVisiblePeerDNSNamesProduceBoundedHTTPSCandidates() throws {
    let data = Data(#"{"BackendState":"Running","Peer":{"one":{"DNSName":"graph.tail123.ts.net.","Online":true},"two":{"DNSName":"offline.tail123.ts.net.","Online":false},"three":{"DNSName":"evil.example","Online":true},"four":{"DNSName":"graph.tail123.ts.net.","Online":true}}}"#.utf8)
    XCTAssertEqual(try TailnetServerDiscovery.candidates(status:data).map(\.absoluteString), ["https://graph.tail123.ts.net","https://graph.tail123.ts.net:9443"])
    XCTAssertThrowsError(try TailnetServerDiscovery.candidates(status:Data(#"{"BackendState":"Stopped"}"#.utf8)))
  }
  func testDirectoryCannotRedirectDiscoveryToAnotherHostOrCleartext() throws {
    let base = URL(string:"https://graph.tail123.ts.net:9443")!
    XCTAssertEqual(try TailnetServerDiscovery.advertisedOrigins(Data(#"{"schema":"zenith.service-directory.v1","origins":["https://graph.tail123.ts.net:10000"]}"#.utf8),at:base).first?.port,10000)
    for origin in ["https://other.tail123.ts.net", "http://graph.tail123.ts.net", "https://graph.tail123.ts.net/private"] {
      let data = try JSONSerialization.data(withJSONObject:["schema":"zenith.service-directory.v1","origins":[origin]])
      XCTAssertThrowsError(try TailnetServerDiscovery.advertisedOrigins(data, at:base))
    }
  }
  func testScanFiltersFailuresAndDeduplicatesProfiles() async throws {
    let config = try WorkAccessConfiguration(name:"Graph",receiver:URL(string:"https://graph.tail123.ts.net:9443")!,issuer:"fixture",keyID:"key",publicKey:String(repeating:"ab",count:32),network:.tailscale)
    let found = try await TailnetServerDiscovery.scan([URL(string:"https://graph.tail123.ts.net")!, config.receiver]) { origin in origin.port == 9443 ? [config, config] : [] }
    XCTAssertEqual(found,[config])
  }
}
