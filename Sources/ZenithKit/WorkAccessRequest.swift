import CryptoKit
import Foundation

public struct WorkAccessRequestRecord: Codable, Sendable, Equatable {
  public let receiver: String
  public let subject: String
  public let installation: String
  public let requestID: String
}
/// Only public identifiers persist, so a lost response can be checked after
/// relaunch without submitting another request. No proof or credential is saved.
public final class WorkAccessRequestStore: @unchecked Sendable {
  private let directory: URL
  private let lock = NSLock()
  public init(directory: URL) throws {
    self.directory = directory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    var path = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true
    try path.setResourceValues(values)
  }
  private func file(_ receiver: String, _ subject: String, _ installation: String) -> URL {
    let key = SHA256.hash(data: Data((receiver + "\n" + subject + "\n" + installation).utf8)).map { String(format:"%02x",$0) }.joined()
    return directory.appendingPathComponent(key + ".json")
  }
  public func existing(receiver: String, subject: String, installation: String) throws -> WorkAccessRequestRecord? {
    lock.lock(); defer { lock.unlock() }
    return try load(receiver,subject,installation)
  }
  private func load(_ receiver: String, _ subject: String, _ installation: String) throws -> WorkAccessRequestRecord? {
    let path = file(receiver,subject,installation)
    guard FileManager.default.fileExists(atPath: path.path) else { return nil }
    let data = try Data(contentsOf: path)
    guard data.count <= 4096 else { throw WalletFailure.invalidFile }
    let value = try JSONDecoder().decode(WorkAccessRequestRecord.self, from: data)
    guard value.receiver == receiver, value.subject == subject, value.installation == installation,
      value.requestID.range(of:"^[0-9a-f]{32}$", options:.regularExpression) != nil else { throw WalletFailure.invalidFile }
    return value
  }
  public func begin(receiver: String, subject: String, installation: String) throws -> WorkAccessRequestRecord {
    lock.lock(); defer { lock.unlock() }
    if let old = try load(receiver,subject,installation) { return old }
    let value = WorkAccessRequestRecord(receiver:receiver,subject:subject,installation:installation,requestID:UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased())
    let path = file(receiver,subject,installation)
    #if os(iOS)
    try JSONEncoder().encode(value).write(to:path,options:[.atomic,.completeFileProtection])
    #else
    try JSONEncoder().encode(value).write(to:path,options:.atomic)
    #endif
    try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
    return value
  }
}
public struct NativeAccessRequestPreview: Decodable, Sendable {
  let token: String
  let summary: Summary
  struct Summary: Decodable, Sendable {
    let issuer: String
    let receiver: String
    let operation: String
    let expires_at: UInt64
  }
}
public struct WorkAccessRequestConsent: Sendable {
  public let requestID: String
  public let receiver: String
  public let issuer: String
  public let checkingStatus: Bool
  public let approvalExpires: Date
  let native: NativeAccessRequestPreview
  let lifecycle: UInt64
}
public struct WorkAccessRequestResult: Decodable, Sendable {
  public let schema: String
  public let request_id: String
  public let status: String
  public let authority_issued: Bool
}

public extension DevgraphReadClient {
  func prepareAccessRequest(store: WorkAccessRequestStore, resubmitOriginal: Bool = false) async throws -> WorkAccessRequestConsent {
    let ticket = repository.lifecycleTicket()
    let identity = try JSONSerialization.jsonObject(with: await repository.readAccessIdentity()) as? [String:String]
    guard let owner = identity?["subject_public_key"], let device = identity?["installation_id"] else { throw WalletFailure.core("invalid_response") }
    let old = try store.existing(receiver:configuration.origin,subject:owner,installation:device)
    let record = try old ?? store.begin(receiver:configuration.origin,subject:owner,installation:device)
    let action:[String:Any] = ["schema":"devgraph.access-request-action.v1","action":old == nil || resubmitOriginal ? "submit":"status","request_id":record.requestID,"subject_public_key":owner,"installation_id":device,"intent":NSNull()]
    var request = URLRequest(url:URL(string:configuration.origin + "/devgraph/access-requests/v2/challenges")!)
    request.httpMethod="POST";request.httpBody=try JSONSerialization.data(withJSONObject:["request":action]);request.setValue("application/json",forHTTPHeaderField:"Content-Type")
    let challenge = try await transport.request(request,maximum:16_384)
    guard let value = try JSONSerialization.jsonObject(with:challenge) as? [String:Any],
      let details = value["details"] as? [String:Any], NSDictionary(dictionary:details).isEqual(to:action) else { throw WalletFailure.core("invalid_response") }
    try repository.checkLifecycle(ticket)
    let prepared = try await repository.prepareAccessRequest(challenge,pin:configuration.authority,now:UInt64(Date().timeIntervalSince1970))
    return WorkAccessRequestConsent(requestID:record.requestID,receiver:prepared.summary.receiver,issuer:prepared.summary.issuer,checkingStatus:old != nil && !resubmitOriginal,approvalExpires:Date(timeIntervalSince1970:Double(prepared.summary.expires_at)),native:prepared,lifecycle:ticket)
  }
  func submitAccessRequest(_ consent: WorkAccessRequestConsent) async throws -> WorkAccessRequestResult {
    try repository.checkLifecycle(consent.lifecycle)
    guard consent.receiver == configuration.origin, consent.issuer == configuration.issuer else { throw WalletFailure.core("invalid_response") }
    let approved = try await repository.approveAccessRequest(consent.native, now:UInt64(Date().timeIntervalSince1970),ticket:consent.lifecycle)
    var request=URLRequest(url:URL(string:configuration.origin + "/devgraph/access-requests/v2/actions")!)
    request.httpMethod="POST";request.httpBody=approved;request.setValue("application/json",forHTTPHeaderField:"Content-Type")
    // Never automatically repeat a submit after an uncertain response. The
    // persistent ID makes the next explicit preparation a status check.
    let data=try await transport.request(request,maximum:16_384)
    try repository.checkLifecycle(consent.lifecycle)
    let result=try JSONDecoder().decode(WorkAccessRequestResult.self,from:data)
    guard ["devgraph.access-request-result.v1","devgraph.access-request-result.v2","devgraph.access-request-result.v3"].contains(result.schema), result.request_id == consent.requestID, !result.authority_issued,
      ["pending","active","approved","denied","declined","expired","revoked","unknown"].contains(result.status) else { throw WalletFailure.core("invalid_response") }
    return result
  }
}
