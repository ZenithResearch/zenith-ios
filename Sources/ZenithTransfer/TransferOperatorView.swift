#if os(macOS)
import CryptoKit
import SwiftUI
import WebKit
import ZenithKit

struct TransferOperatorView: View {
  @StateObject private var bridge: TransferOperatorBridge
  @ObservedObject private var walletModel: TransferModel
  @State private var unlocking = false
  @Environment(\.dismiss) private var dismiss
  init(resource: RegisteredResource, repository: WalletRepository, walletModel: TransferModel) {
    self.walletModel = walletModel
    _bridge = StateObject(wrappedValue: TransferOperatorBridge(resource: resource, repository: repository))
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(bridge.resource.configuration.name).font(.headline)
        Text(bridge.resource.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        Spacer()
        Button(walletModel.wallet?.unlocked == true ? "Wallet" : "Unlock Wallet") { unlocking = true }
        Button("Close inbox") { bridge.cancel(); dismiss() }
      }.padding(12)
      Divider()
      if let error = bridge.failure { Text(error).padding(24) }
      else { OperatorWebView(bridge: bridge) }
    }.frame(minWidth: 900, minHeight: 650)
      .sheet(isPresented: $unlocking) {
        VStack(spacing: 0) {
          HStack { Text("Castalia Wallet").font(.headline); Spacer(); Button("Return to inbox") { unlocking = false } }.padding()
          Divider(); TransferWalletView(model: walletModel)
        }.frame(width: 720, height: 660)
      }
      .sheet(item: $bridge.consent, onDismiss: { bridge.resolve(false) }) { consent in
        VStack(alignment: .leading, spacing: 16) {
          Text(bridge.confirmationTitle).font(.title2.bold())
          Text("\(consent.receiver)\nIssuer: \(consent.issuer)").textSelection(.enabled)
          Text("Review the exact signed action below. This approval expires at \(consent.expiresAt.formatted()).")
          ScrollView {
            Text(bridge.disclosure).font(.system(.body, design: .monospaced))
              .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
          }
          HStack {
            Button("Cancel") { bridge.resolve(false) }
            Spacer()
            Button("Approve in Castalia Wallet") { bridge.resolve(true) }.buttonStyle(.borderedProminent)
          }
        }.padding(24).frame(width: 700, height: 580)
      }
      .onDisappear { bridge.cancel() }
  }
}

private struct OperatorWebView: NSViewRepresentable {
  @ObservedObject var bridge: TransferOperatorBridge
  func makeNSView(context: Context) -> WKWebView {
    bridge.makeWebView()
  }
  func updateNSView(_ nsView: WKWebView, context: Context) { }
  static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
    nsView.stopLoading(); nsView.configuration.userContentController.removeScriptMessageHandler(forName: "operator", contentWorld: .page)
  }
}

extension TransferOperatorBridge {
  func makeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(self, forURLScheme: "zenith-operator")
    config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "operator")
    let bootstrap = self.bootstrap
    config.userContentController.addUserScript(WKUserScript(source: bootstrap,
      injectionTime: .atDocumentStart, forMainFrameOnly: true))
    let view = WKWebView(frame: .zero, configuration: config)
    webView = view; view.navigationDelegate = self
    view.load(URLRequest(url: URL(string: "zenith-operator://console/index.html")!))
    return view
  }
}

/// Only signed application-bundled UI can call this bridge. Service responses
/// remain data: no remote page, script, iframe or general signing API is loaded.
@MainActor final class TransferOperatorBridge: NSObject, ObservableObject, WKURLSchemeHandler,
  WKNavigationDelegate, WKScriptMessageHandlerWithReply {
  let resource: RegisteredResource
  let repository: WalletRepository
  weak var webView: WKWebView?
  @Published var consent: OperatorConsent?
  @Published var failure: String?
  private var transport: PrivateTransport?
  private var journal: OperatorJournal?
  private var rawChallenge: Data?
  private var signed: Data?
  private var continuation: CheckedContinuation<Bool, Never>?
  private var clearAllowed = false
  private var closed = false
  private let assets: URL = {
    // Packaged apps use the normal Contents/Resources location. SwiftPM's
    // generated command-line accessor otherwise expects a bundle at app root.
    if let root = Bundle.main.resourceURL,
      let bundle = Bundle(url: root.appendingPathComponent("ZenithKit_ZenithTransfer.bundle")),
      let resources = bundle.resourceURL { return resources.appendingPathComponent("Operator") }
    return Bundle.module.resourceURL!.appendingPathComponent("Operator")
  }()

  init(resource: RegisteredResource, repository: WalletRepository,
    transport suppliedTransport: PrivateTransport? = nil, journalDirectory: URL? = nil) {
    self.resource = resource; self.repository = repository
    super.init()
    do {
      transport = try suppliedTransport ?? PrivateTransport(workServer: resource.configuration)
      let root = try FileManager.default.url(for: .applicationSupportDirectory,
        in: .userDomainMask, appropriateFor: nil, create: true)
      journal = try OperatorJournal(directory: journalDirectory ?? root.appendingPathComponent("ZenithTransfer/OperatorActions"), origin: resource.id)
      _ = try journal?.load()
    } catch { failure = "Could not open this resource securely. Check its saved connection and recovery settings." }
  }
  var bootstrap: String {
    do {
      let config: [String: Any] = ["origin": resource.id,
        "pending": try journal?.load().flatMap { String(data: $0, encoding: .utf8) } as Any? ?? NSNull()]
      let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
      return "globalThis.ZenithOperatorConfiguration=" + String(decoding: data, as: UTF8.self) + ";\n" +
        (try String(contentsOf: assets.appendingPathComponent("native-bridge.js"), encoding: .utf8))
    } catch { failure = "The original action could not be recovered. Its record is preserved."; return "" }
  }
  var disclosure: String {
    guard let data = consent?.details,
      let value = try? JSONSerialization.jsonObject(with: data),
      let formatted = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
    else { return "" }
    return String(decoding: formatted, as: UTF8.self)
  }
  var confirmationTitle: String {
    switch consent?.operation {
    case "access.inbox": return "Review this resource's requests?"
    case "access.review": return "Review this exact grant selection?"
    case "access.status": return "Check the original decision?"
    default:
      let value = consent.flatMap { try? object($0.details) }
      let action = (value?["action"] as? [String: Any])?["action"] as? String
      return ["approve":"Activate this exact access grant?", "deny":"Decline this access request?",
        "revoke":"Revoke this access grant?"][action ?? ""] ?? "Confirm this access decision?"
    }
  }
  func resolve(_ approved: Bool) {
    let next = continuation; continuation = nil; consent = nil; next?.resume(returning: approved)
  }
  func cancel() { closed = true; resolve(false); transport?.cancel(); signed = nil }
  private func canonical(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys,.withoutEscapingSlashes,.fragmentsAllowed])
  }
  private func object(_ data: Data) throws -> [String: Any] {
    guard data.count <= 1_048_576, let value = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw WalletFailure.invalidFile }; return value
  }
  private func pending() throws -> [String: Any] {
    guard let data = try journal?.load() else { throw WalletFailure.core("operator_recovery_required") }
    return try object(data)
  }
  private func checkAction(_ action: [String: Any], against original: [String: Any]) throws {
    guard let originalAction = original["action"] as? [String: Any] else { throw WalletFailure.invalidFile }
    if original["dispatched"] as? Bool == true {
      guard action["action"] as? String == "status",
        action["original_action_id"] as? String == originalAction["action_id"] as? String
      else { throw WalletFailure.core("recover_original_action_first") }
    } else {
      guard try canonical(action) == canonical(originalAction) else { throw WalletFailure.conflict }
    }
  }
  func userContentController(_ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
    guard message.frameInfo.isMainFrame, message.webView === webView,
      message.frameInfo.securityOrigin.protocol == "zenith-operator",
      message.frameInfo.securityOrigin.host == "console",
      let args = message.body as? [String: Any], let method = args["method"] as? String
    else { replyHandler(nil,"invalid_native_caller"); return }
    Task {
      do {
        guard !closed else { throw CancellationError() }
        let result = try await handle(method, args)
        guard !closed else { throw CancellationError() }
        replyHandler(result,nil)
      } catch {
        let permitted = ["wallet_locked","approval_denied","backup_verification_required","recover_original_action_first"]
        if case WalletFailure.core(let code) = error, permitted.contains(code) { replyHandler(nil, code) }
        else if case WalletFailure.core("access_approval_expired") = error { replyHandler(nil, "operator_approval_expired") }
        else { replyHandler(nil, "native_operator_step_failed") }
      }
    }
  }
  private func handle(_ method: String, _ args: [String: Any]) async throws -> Any {
    switch method {
    case "hash":
      guard let text = args["text"] as? String, text.utf8.count <= 131_072 else { throw WalletFailure.invalidFile }
      return SHA256.hash(data: Data(text.utf8)).map { String(format:"%02x",$0) }.joined()
    case "identity":
      let data = try await repository.graphAccessIdentityV2()
      if let old = try journal?.load() {
        guard try canonical(object(old)["identity"]!) == canonical(object(data)) else { throw WalletFailure.conflict }
      }
      return String(decoding: data, as: UTF8.self)
    case "save":
      guard let text = args["record"] as? String, text.utf8.count <= 131_072, let journal else { throw WalletFailure.invalidFile }
      let data = Data(text.utf8)
      guard let identity = try object(data)["identity"],
        try canonical(identity) == canonical(object(await repository.graphAccessIdentityV2())) else { throw WalletFailure.conflict }
      try journal.save(data); return true
    case "clear":
      if let journal, let old = try journal.load() {
        let unsigned = try object(old)["dispatched"] as? Bool == false
        guard clearAllowed || unsigned else { throw WalletFailure.core("recover_original_action_first") }
        try journal.clear(matching: old)
      }
      clearAllowed = false; return true
    case "approve":
      guard continuation == nil, let text = args["challenge"] as? String, let rawChallenge,
        try canonical(object(Data(text.utf8))) == canonical(object(rawChallenge)),
        let details = try object(rawChallenge)["details"] as? [String: Any],
        let action = details["action"] as? [String: Any] else { throw WalletFailure.invalidFile }
      try checkAction(action, against: pending())
      let prepared = try await repository.prepareOperatorAccess(rawChallenge, pin: resource.configuration.authority, now: UInt64(Date().timeIntervalSince1970))
      consent = prepared
      let accepted = await withCheckedContinuation { continuation = $0 }
      guard accepted, !closed else { throw WalletFailure.core("approval_denied") }
      let result = try await repository.approveOperatorAccess(prepared, now: UInt64(Date().timeIntervalSince1970))
      signed = result; return String(decoding: result, as: UTF8.self)
    case "post":
      guard let path = args["path"] as? String,
        ["/devgraph/access-operator/v1/challenges","/devgraph/access-operator/v1/actions"].contains(path),
        let text = args["body"] as? String, text.utf8.count <= 65_536, let transport else { throw WalletFailure.invalidFile }
      let body = Data(text.utf8), input = try object(body)
      let actionCall = path.hasSuffix("/actions")
      if actionCall {
        guard let signed, try canonical(input) == canonical(object(signed)) else { throw WalletFailure.conflict }
        self.signed = nil
        var record = try pending(); record["dispatched"] = true
        try journal?.save(canonical(record)) // durable BEFORE possible dispatch
        clearAllowed = false
      } else {
        guard continuation == nil else { throw WalletFailure.conflict }
        rawChallenge = nil; signed = nil
        let identity = try object(await repository.graphAccessIdentityV2())
        guard input["subject_public_key"] as? String == identity["subject_public_key"] as? String,
          input["installation_id"] as? String == identity["installation_id"] as? String,
          let action = input["action"] as? [String: Any] else { throw WalletFailure.conflict }
        if let prior = try journal?.load(), try object(prior)["dispatched"] as? Bool == true {
          try checkAction(action, against: object(prior))
        }
      }
      var request = URLRequest(url: URL(string: resource.id + path)!)
      request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let response = try await transport.exchange(request)
      if !actionCall && response.status == 200 {
        // Native validation sees the ORIGINAL raw JSON, rejecting duplicates
        // before the web renderer parses it. The human signs only later.
        _ = try await repository.prepareOperatorAccess(response.data, pin: resource.configuration.authority, now: UInt64(Date().timeIntervalSince1970))
        let challenge = try object(response.data)
        guard let details = challenge["details"] as? [String: Any],
          Set(details.keys) == ["action","policy_revision","policy_digest_sha256"],
          let revision = details["policy_revision"] as? Int, revision > 0,
          (details["policy_digest_sha256"] as? String)?.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,
          let returnedAction = details["action"] as? [String: Any], let requestedAction = input["action"],
          let actionName = returnedAction["action"] as? String,
          challenge["operation"] as? String == ["inbox":"access.inbox","review":"access.review",
            "approve":"access.decide","deny":"access.decide","revoke":"access.decide","status":"access.status"][actionName],
          try canonical(returnedAction) == canonical(requestedAction) else { throw WalletFailure.conflict }
        rawChallenge = response.data
      }
      if actionCall {
        let error = (try? object(response.data)["error"]) as? String ?? ""
        clearAllowed = (200..<300).contains(response.status) ||
          ([400,401,409].contains(response.status) && ["invalid_operator_selection","operator_access_denied","operator_request_changed","operator_assignment_changed","write_activation_unavailable","write_activation_upgrade_required","native_admission_required","mixed_activation_unavailable","activation_unavailable","activation_upgrade_required"].contains(error))
      }
      return ["status":response.status,"body":String(decoding: response.data, as: UTF8.self)]
    default: throw WalletFailure.invalidFile
    }
  }
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let url = navigationAction.request.url
    decisionHandler(url?.scheme == "zenith-operator" && url?.host == "console" ? .allow : .cancel)
  }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    failure = "The bundled inbox could not load (\((error as NSError).domain):\((error as NSError).code))."
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    failure = "The bundled inbox stopped loading (\((error as NSError).domain):\((error as NSError).code))."
  }
  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    guard let url = urlSchemeTask.request.url, url.host == "console", url.query == nil,
      url.fragment == nil, urlSchemeTask.request.httpMethod == "GET" else {
      urlSchemeTask.didFailWithError(WalletFailure.invalidFile); return
    }
    let path = String(url.path.dropFirst())
    let allowed = ["index.html","theme.js","zenith-tokens.css","scope-picker.mjs","access/app.mjs","access/client.mjs","access/core.mjs","access/policy.mjs","access/style.css"]
    guard allowed.contains(path), let bytes = try? Data(contentsOf: assets.appendingPathComponent(path)) else {
      urlSchemeTask.didFailWithError(WalletFailure.invalidFile); return
    }
    let mime = path.hasSuffix(".html") ? "text/html" : path.hasSuffix(".css") ? "text/css" : "application/javascript"
    urlSchemeTask.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: bytes.count, textEncodingName: "utf-8"))
    urlSchemeTask.didReceive(bytes); urlSchemeTask.didFinish()
  }
  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { }
}
#endif
