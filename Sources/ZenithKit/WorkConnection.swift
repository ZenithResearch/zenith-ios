import Foundation

/// Distributor-supplied connection guidance. It never installs a VPN or grants access.
public enum WorkNetwork: String, Codable, Sendable, Hashable {
  case tailscale
}

public struct WorkConnectionFailure: LocalizedError, Sendable {
  let code: URLError.Code
  let network: WorkNetwork?
  public init(code: URLError.Code, network: WorkNetwork?) {
    self.code = code
    self.network = network
  }
  public var errorDescription: String? {
    if code == .secureConnectionFailed || code == .serverCertificateUntrusted
      || code == .serverCertificateHasBadDate || code == .serverCertificateHasUnknownRoot
      || code == .serverCertificateNotYetValid {
      return "The server’s secure connection could not be verified. Contact the server owner."
    }
    if code == .cancelled { return "Connection cancelled." }
    if network == .tailscale {
      return "Can’t reach your work server. Open Tailscale, connect to the same network as your server, then try again."
    }
    return "Can’t reach your work server. Check your internet connection and try again."
  }
}
