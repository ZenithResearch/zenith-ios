import SwiftUI
import ZenithKit

struct WorkAccessRequestSection: View {
  let client: DevgraphReadClient
  let store: WorkAccessRequestStore
  @EnvironmentObject private var model: WalletModel
  @State private var consent: WorkAccessRequestConsent?
  @State private var result: WorkAccessRequestResult?
  var body: some View {
    Section {
      if let consent {
        Text(consent.checkingStatus ? "Check your existing request" : "Ask this server’s operator for access").font(.headline)
        Text(consent.receiver).font(.footnote).textSelection(.enabled)
        Text("Your Wallet sends proof of identity and this request. The operator chooses the permissions; this step grants no access.")
        LabeledContent("Approval expires",value:consent.approvalExpires.formatted())
        Button(consent.checkingStatus ? "Check request status" : "Send access request") {
          self.consent = nil
          model.perform({ _ in try await client.submitAccessRequest(consent) }) {
            result = $0; self.consent = nil
          }
        }.disabled(model.busy || Date() >= consent.approvalExpires)
        Button("Refresh this approval") { prepare(resubmit:!consent.checkingStatus) }.disabled(model.busy)
      } else {
        if let result {
          Text(status(result.status)).accessibilityAddTraits(.updatesFrequently)
          if result.status == "unknown" {
            Button("Resend the original access request") { prepare(resubmit:true) }.disabled(model.busy)
            Text("Uses the same request ID; it cannot create a second request.").font(.footnote)
          }
        } else {
          Text("If access hasn’t been assigned yet, send a request to this server’s operator. You won’t need to paste a credential.")
        }
        Button(result == nil ? "Request or check access" : "Check request") { prepare() }.disabled(model.busy)
      }
    } header: { Text("Request access") } footer: { Text("An approved grant can be reused while valid. Next, choose Continue below to review the exact read permissions in Wallet.") }
    .onChange(of:model.generation) { _,_ in consent=nil }
  }
  private func prepare(resubmit:Bool=false) {
    model.perform({ _ in try await client.prepareAccessRequest(store:store,resubmitOriginal:resubmit) }) { consent=$0 }
  }
  private func status(_ value:String) -> String {
    switch value {
    case "pending": return "Request sent · Waiting for the server operator"
    case "active": return "Access approved · Continue below to review your read permissions"
    case "approved": return "Request reviewed · The operator still needs to activate access"
    case "denied", "declined": return "Request declined · Contact the server operator"
    case "revoked": return "Access revoked · Contact the server operator"
    case "expired": return "Request expired · Contact the server operator"
    default: return "Request outcome unknown · Check again before resending"
    }
  }
}
