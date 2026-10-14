import Foundation

public struct ReadAuthorityPin: Codable, Sendable, Hashable {
  public let issuer: String
  public let key_id: String
  public let public_key: String
  public let receiver: String
  public let audience: String
}
public struct WorkAccessConfiguration: Codable, Sendable, Hashable {
  public let name: String
  public let receiver: URL
  public let issuer: String
  public let authority: ReadAuthorityPin
  public let network: WorkNetwork?
  public let tls_certificate_sha256: String?
  public init(name: String, receiver: URL, issuer: String, keyID: String,
    publicKey: String, network: WorkNetwork? = nil, tlsCertificateSHA256: String? = nil) throws {
    self.name = name
    self.receiver = receiver
    self.issuer = issuer
    self.network = network
    self.tls_certificate_sha256 = tlsCertificateSHA256
    let origin = receiver.absoluteString.hasSuffix("/")
      ? String(receiver.absoluteString.dropLast()) : receiver.absoluteString
    self.authority = ReadAuthorityPin(issuer: issuer, key_id: keyID,
      public_key: publicKey, receiver: origin, audience: "devgraph")
    try validate()
  }
  public func validate() throws {
    guard network == .lan
      ? tls_certificate_sha256?.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
      : tls_certificate_sha256 == nil
    else { throw WalletFailure.core("service_setup_required") }
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      name.count <= 80, !issuer.isEmpty, issuer.count <= 256, receiver.scheme == "https",
      receiver.host != nil,
      receiver.path.isEmpty || receiver.path == "/", receiver.query == nil,
      receiver.fragment == nil,
      receiver.user == nil, receiver.password == nil, authority.issuer == issuer,
      authority.receiver == origin, authority.audience == "devgraph", !authority.key_id.isEmpty,
      authority.key_id.count <= 256,
      authority.public_key.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    else { throw WalletFailure.core("service_setup_required") }
  }
  public var origin: String {
    receiver.absoluteString.hasSuffix("/")
      ? String(receiver.absoluteString.dropLast()) : receiver.absoluteString
  }
}
public struct WorkReadGrant: Codable, Sendable, Equatable {
  public let scope: String
  public let operations: [String]
  public let relationship_types: [String]
  public let work_kinds: [String]
  public let work_ids: [String]?
  public let arena_ids: [String]?
  public let include_archived: Bool
  func validate() throws {
    guard scope == "devgraph.work.read", !operations.isEmpty,
      Set(operations).isSubset(of: ["list", "get"]), Set(operations).count == operations.count,
      !work_kinds.isEmpty,
      Set(work_kinds).isSubset(of: ["Proposal", "Initiative", "Project", "Issue", "Task"]),
      Set(work_kinds).count == work_kinds.count,
      !relationship_types.isEmpty,
      Set(relationship_types).isSubset(of: [
        "parent", "children", "dependencies", "dependents", "blockers", "blocked",
      ]), work_ids.map({ !$0.isEmpty && $0.count <= 256 }) ?? true,
      arena_ids.map({ !$0.isEmpty && $0.count <= 256 }) ?? true
    else { throw WalletFailure.core("unsupported_read_scope") }
  }
}
public struct ReadAccessProposal: Sendable {
  public let requestID: String
  public let issuer: String
  public let receiver: String
  public let expires: Date
  public let grants: [WorkReadGrant]
  let challenge: Data
  let owner: String
  let installation: String
  let policy: String
  let challengeExpiry: UInt64
}
public struct NativeReadManifest: Decodable, Sendable {
  public let schema: String
  public let credential_id: String
  public let subject_public_key: String
  public let installation_id: String
  public let issuer: String
  public let receiver: String
  public let policy_digest: String
  public let audience: String
  public let resource: String
  public let issued_at: UInt64
  public let expires_at: UInt64
  public let read_grants: [WorkReadGrant]
}
public struct WorkRecord: Decodable, Identifiable, Sendable {
  public let kind: String
  public let id: String
  public let title: String
  public let description: String
  public let priority: Int
  public let version: Int
  public let progress: String?
  public var rowID: String { kind + "/" + id }
  public var progressLabel: String {
    switch progress {
    case "not_started": return "Not started"
    case "in_progress": return "In progress"
    case "done": return "Done"
    default: return "Progress not recorded"
    }
  }
}

public final class DevgraphReadClient: @unchecked Sendable {
  let repository: WalletRepository
  let configuration: WorkAccessConfiguration
  let transport: PrivateTransport
  public init(
    repository: WalletRepository, configuration: WorkAccessConfiguration,
    transport: PrivateTransport? = nil
  ) throws {
    try configuration.validate()
    self.repository = repository
    self.configuration = configuration
    guard configuration.network != .tailscale || transport != nil else { throw PrivateNetworkError.disconnected }
    if configuration.network == .lan, let transport, !transport.verifiesLAN(configuration) {
      throw WalletFailure.core("service_setup_required")
    }
    self.transport = try transport ?? PrivateTransport(workServer: configuration)
  }
  public var connection: WorkAccessConfiguration { configuration }
  public func cancel() { transport.cancel() }
  /// A credential-free reachability check, not an authority or membership check.
  public func checkConnection() async throws {
    do { try await transport.checkReadReceiver(at: configuration.receiver) }
    catch let error as URLError {
      throw WorkConnectionFailure(code: error.code, network: configuration.network)
    }
  }
  private func response(_ request: URLRequest, maximum: Int = 1_048_576) async throws -> Data {
    do { return try await transport.request(request, maximum: maximum) }
    catch let error as URLError {
      throw WorkConnectionFailure(code: error.code, network: configuration.network)
    }
  }
  private var now: UInt64 { UInt64(Date().timeIntervalSince1970) }
  private func request(path: String, body: Data? = nil) -> URLRequest {
    var request = URLRequest(url: URL(string: configuration.origin + path)!)
    if let body {
      request.httpMethod = "POST"
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return request
  }
  public func prepare() async throws -> ReadAccessProposal {
    let identity = try await repository.readAccessIdentity()
    let response = try await response(
      request(path: "/devgraph/native-read/v2/challenges", body: identity), maximum: 16_384)
    let v = try object(response)
    try exact(
      v,
      [
        "schema", "request_id", "nonce", "subject_public_key", "installation_id", "issuer",
        "receiver", "details", "issued_at", "expires_at", "credential_expires_at",
      ])
    let identityValue = try object(identity)
    guard v["schema"] as? String == "castalia.read-access-challenge.v1",
      v["receiver"] as? String == configuration.origin,
      v["issuer"] as? String == configuration.issuer,
      v["subject_public_key"] as? String == identityValue["subject_public_key"] as? String,
      v["installation_id"] as? String == identityValue["installation_id"] as? String,
      let details = v["details"] as? [String: Any], let id = v["request_id"] as? String,
      let owner = v["subject_public_key"] as? String,
      let installation = v["installation_id"] as? String
    else { throw WalletFailure.core("invalid_read_challenge") }
    try exact(details, ["schema", "policy_digest", "read_grants", "authority_policy"])
    guard details["schema"] as? String == "devgraph.native-read-scope.v2",
      let policy = details["policy_digest"] as? String
    else { throw WalletFailure.core("invalid_read_challenge") }
    let grants = try parseGrants(details["read_grants"])
    guard let authority = details["authority_policy"] as? [String: Any],
      authority["issuer"] as? String == configuration.authority.issuer,
      authority["key_id"] as? String == configuration.authority.key_id,
      authority["public_key"] as? String == configuration.authority.public_key,
      authority["receiver"] as? String == configuration.origin,
      authority["audience"] as? String == "devgraph",
      let permissions = authority["permissions"] as? [[String: Any]]
    else { throw WalletFailure.core("issuer_setup_required") }
    // The disclosure must describe the exact signed permission records. A
    // receiver cannot show a narrow grant while asking the core to approve more.
    let decoded = try permissions.map { permission -> WorkReadGrant in
      try exact(permission, ["operation", "resource", "constraints"])
      guard permission["resource"] as? String == "https://work.zenith-research.ca/devgraph",
        let constraint = permission["constraints"] as? [String: Any]
      else { throw WalletFailure.core("unsupported_read_scope") }
      let grant = try parseGrants([constraint])[0]
      guard let operation = permission["operation"] as? String,
        grant.operations.map({ "devgraph.work." + $0 }).contains(operation)
      else { throw WalletFailure.core("unsupported_read_scope") }
      return grant
    }
    guard permissions.count == grants.reduce(0, { $0 + $1.operations.count }),
      decoded.allSatisfy({ grants.contains($0) }),
      grants.allSatisfy({ grant in
        grant.operations.allSatisfy { operation in
          zip(permissions, decoded).contains { $0.0["operation"] as? String == "devgraph.work." + operation && $0.1 == grant }
        }
      })
    else { throw WalletFailure.core("invalid_read_challenge") }
    let expiry = try integer(v["credential_expires_at"])
    let challengeExpiry = try integer(v["expires_at"])
    let issued = try integer(v["issued_at"])
    guard issued <= now, now < challengeExpiry, challengeExpiry - issued <= 120, expiry > now,
      expiry - issued <= 3_600
    else { throw WalletFailure.core("access_expired") }
    return ReadAccessProposal(
      requestID: id, issuer: configuration.issuer, receiver: configuration.origin,
      expires: Date(timeIntervalSince1970: Double(expiry)), grants: grants, challenge: response,
      owner: owner, installation: installation, policy: policy, challengeExpiry: challengeExpiry)
  }
  public func connect(_ proposal: ReadAccessProposal) async throws {
    guard proposal.receiver == configuration.origin, proposal.issuer == configuration.issuer,
      now < proposal.challengeExpiry
    else { throw WalletFailure.core("access_expired") }
    let ticket = repository.lifecycleTicket()
    let approved = try await repository.approveReadCredential(
      proposal.challenge, pin: configuration.authority, now: now)
    try repository.checkLifecycle(ticket)
    let response = try await response(
      request(path: "/devgraph/native-read/v2/enrollments", body: approved), maximum: 65_536)
    let v = try object(response)
    try exact(v, ["schema", "credential", "manifest"])
    guard v["schema"] as? String == "devgraph.native-read-result.v2",
      let credential = v["credential"] as? [String: Any]
    else { throw WalletFailure.core("invalid_credential") }
    // The shared Rust core verifies issuer signature, holder, device, policy,
    // exact approved permissions and expiry before preparing durable storage.
    try await repository.storeReadCredential(requestID: proposal.requestID,
      credential: JSONSerialization.data(withJSONObject: credential), now: now, ticket: ticket)
  }
  public func manifest() async throws -> NativeReadManifest {
    let access = try object(await repository.readCredential(receiver: configuration.origin, now: now))
    guard let credential = access["credential"] as? [String: Any],
      let claims = credential["claims"] as? [String: Any],
      let permissions = claims["permissions"] as? [[String: Any]]
    else { throw WalletFailure.core("invalid_credential") }
    let parsed = try parseGrants(permissions.map { $0["constraints"] as Any })
    let grants = parsed.reduce(into: [WorkReadGrant]()) { if !$0.contains($1) { $0.append($1) } }
    let value: [String: Any] = ["schema":"devgraph.native-read-manifest.v2",
      "credential_id":claims["credential_id"] as Any, "subject_public_key":claims["holder_public_key"] as Any,
      "installation_id":claims["installation_id"] as Any, "issuer":claims["issuer"] as Any,
      "receiver":claims["receiver"] as Any, "policy_digest":claims["policy_digest"] as Any,
      "audience":claims["audience"] as Any, "resource":"https://work.zenith-research.ca/devgraph",
      "issued_at":claims["issued_at"] as Any, "expires_at":claims["expires_at"] as Any,
      "read_grants":try JSONSerialization.jsonObject(with: JSONEncoder().encode(grants))]
    return try JSONDecoder().decode(NativeReadManifest.self, from: JSONSerialization.data(withJSONObject: value))
  }
  public func list(kind: String, after: String? = nil) async throws -> [WorkRecord] {
    guard ["Proposal", "Initiative", "Project", "Issue", "Task"].contains(kind) else {
      throw WalletFailure.core("unsupported_read_scope")
    }
    let ticket = repository.lifecycleTicket()
    var parameters: [String: Any] = ["kind":kind, "limit":20]
    if let after { parameters["after_id"] = after }
    let read: [String: Any] = ["operation":"devgraph.work.list",
      "resource":"https://work.zenith-research.ca/devgraph", "parameters":parameters]
    let proof = try await repository.signReadCall(receiver: configuration.origin,
      call: JSONSerialization.data(withJSONObject: read), now: now)
    try repository.checkLifecycle(ticket)
    let data = try await response(request(path: "/devgraph/native-read/v2/requests", body: proof))
    try repository.checkLifecycle(ticket)
    struct Page: Decodable { let items: [WorkRecord] }
    let page = try JSONDecoder().decode(Page.self, from: data)
    guard page.items.count <= 20, page.items.allSatisfy({ $0.kind == kind }) else {
      throw WalletFailure.core("invalid_response")
    }
    return page.items
  }
  public func disconnect() async throws {
    try await repository.forgetReadAccess(receiver: configuration.origin)
  }
}
private func object(_ data: Data) throws -> [String: Any] {
  guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw WalletFailure.core("invalid_response")
  }
  return value
}
private func exact(_ value: [String: Any], _ keys: Set<String>) throws {
  guard Set(value.keys) == keys else { throw WalletFailure.core("invalid_response") }
}
private func integer(_ value: Any?) throws -> UInt64 {
  guard let n = value as? NSNumber, String(cString: n.objCType) != "c", n.doubleValue >= 0,
    n.doubleValue.rounded() == n.doubleValue, n.doubleValue <= 9_007_199_254_740_991
  else { throw WalletFailure.core("invalid_response") }
  return n.uint64Value
}
private func parseGrants(_ value: Any?) throws -> [WorkReadGrant] {
  guard let values = value as? [[String: Any]], !values.isEmpty, values.count <= 32 else {
    throw WalletFailure.core("invalid_response")
  }
  for value in values {
    let base: Set<String> = [
      "scope", "operations", "relationship_types", "work_kinds", "include_archived",
    ]
    guard base.isSubset(of: Set(value.keys)),
      Set(value.keys).isSubset(of: base.union(["work_ids", "arena_ids"]))
    else { throw WalletFailure.core("invalid_response") }
  }
  let grants = try JSONDecoder().decode(
    [WorkReadGrant].self, from: JSONSerialization.data(withJSONObject: values))
  for grant in grants { try grant.validate() }
  return grants
}
