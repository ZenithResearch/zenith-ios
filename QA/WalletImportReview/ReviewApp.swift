// Isolated synthetic review app. It never opens a Wallet repository or network.
import SwiftUI
import ZenithKit

@main
struct WalletReviewQAApp: App {
  var body: some Scene {
    WindowGroup {
      ReviewScreen()
        .tint(.green)
        .dynamicTypeSize(ProcessInfo.processInfo.environment["WALLET_REVIEW_LARGE_TEXT"] == "1" ? .accessibility3 : .large)
    }
  }
}

private struct ReviewScreen: View {
  let review: WalletImportReview
  @State private var cancelled = false
  init() {
    let scenario = ProcessInfo.processInfo.environment["WALLET_REVIEW_SCENARIO"] ?? "recovery"
    let file = Bundle.main.url(forResource: "preview", withExtension: "json")!
    var value = try! JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    if scenario == "empty" {
      var identities = value["wallet_identities"] as! [String: Any]
      identities["accounts"] = []; value["wallet_identities"] = identities
      value["imported_wallet_identities"] = 0
    }
    let preview = try! JSONDecoder().decode(RestorePreview.self, from: JSONSerialization.data(withJSONObject: value))
    let context: WalletImportReview.Context
    switch scenario {
    case "combined": context = .recoveryAndCastaway(.v2)
    case "data", "empty": context = .castaway(.v2)
    case "legacy": context = .castaway(.v1)
    default: context = .recovery
    }
    review = WalletImportReview(preview: preview, context: context)
  }
  var body: some View {
    VStack(spacing: 0) {
      if cancelled { Text("Review cancelled · synthetic data only").padding(40) }
      else {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Text(review.recoversWallet ? "Import · 4 of 4" : "Import Castaway data").foregroundStyle(.secondary)
            Text(review.recoversWallet ? "Review your wallet" : "Review your data").font(.largeTitle.bold())
            Text("Your backup has been checked. Confirm to save it on this device.").foregroundStyle(.secondary)
            WalletImportReviewContent(review: review).padding(20).background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
            Text("Importing does not activate memberships or connect service access.").font(.footnote).foregroundStyle(.secondary)
          }.frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity).padding(24)
        }
        Divider()
        HStack {
          Button("Cancel") { cancelled = true }
          Spacer()
          Button(review.recoversWallet ? "Import wallet" : "Import data") {}.buttonStyle(.borderedProminent)
        }.padding(20)
      }
    }
    #if os(macOS)
    .frame(minWidth: 600, idealWidth: 640, minHeight: 620, idealHeight: 780)
    #endif
  }
}
