import Combine
import ZenithKit

/// Public connection settings retained in memory while setup leaves the foreground.
/// This draft never stores Wallet credentials or persists settings to disk.
@MainActor
final class WorkServerDraft: ObservableObject {
  @Published var active = false
  @Published var address = ""
  @Published var name = "Devgraph"
  @Published var issuer = ""
  @Published var keyID = ""
  @Published var publicKey = ""
  @Published var network: WorkNetwork?
  @Published var tlsCertificateSHA256 = ""
  @Published var preview: WorkAccessConfiguration?
  @Published var verificationOrigin: String?

  func reset() {
    active = false
    address = ""
    name = "Devgraph"
    issuer = ""
    keyID = ""
    publicKey = ""
    network = nil
    tlsCertificateSHA256 = ""
    preview = nil
    verificationOrigin = nil
  }
}
