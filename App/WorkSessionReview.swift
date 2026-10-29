import SwiftUI
import ZenithKit
import CastaliaCustody

/// The same typed native session review used by Transfer. App-scoped custody
/// remains alive when navigating or locking the root Wallet; app exit drops it.
struct WorkSessionReview: View {
  @EnvironmentObject private var wallet: WalletModel
  let client: DevgraphReadClient
  @State private var review: HolderSessionReviewModel?
  @State private var error: String?
  @State private var unlocking = false
  @State private var clientID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  @State private var provider: HolderIssuerPin?
  var body: some View {
    Group {
      if let review {
        HolderSessionReviewView(model: review, unlocked: wallet.state?.unlocked == true) { unlocking = true }
          .onChange(of: review.phase) { _, phase in
            Task {
              if phase == .issued, let provider {
                do {
                  try await HolderSessionRegistry.shared.retain(review, client: clientID, pin: provider)
                  if let owner = review.challenge?.intent.parent.holderPublicKey { wallet.activateWorkSession(owner: owner) }; wallet.generation += 1
                  wallet.notice = "Session ready. Open Work to read within its approved scope."
                } catch { self.error = "Could not retain this session. No additional approval was sent." }
              } else if [.closed, .revoked, .expired].contains(phase) {
                wallet.hasWorkSession = false; wallet.generation += 1
              }
            }
          }
      } else if let error {
        ContentUnavailableView("Session access unavailable", systemImage: "key", description: Text(error))
      } else { ProgressView("Checking service session support") }
    }.navigationTitle("Work session")
      .sheet(isPresented: $unlocking) { UnlockView() }
      .task {
        guard review == nil else { return }
        do {
          if let existing = await HolderSessionRegistry.shared.review(configuration: client.connection) { review = existing; return }
          guard let repository = wallet.repository,
            let capabilities = try await HTTPSHolderSessionIssuer.discover(transport: client.holderSessionTransport, configuration: client.connection)
          else { throw HolderSessionError.unsupported }
          let transport = client.holderSessionTransport, configuration = client.connection, id = clientID
          let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("WorkSessions", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
          provider = capabilities.provider
          let model = try HolderSessionReviewModel(service: capabilities.provider.service, label: "Zenith Work on this device",
            purpose: "Read the Work resources you select until the fixed expiry.", maximumLifetime: capabilities.maximumLifetime) {
              let custody = try NativeHolderSessionCustody(profileData: capabilities.custodyProfile)
              return try HolderSessionFlow(clientID: id,
                requestID: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(), service: capabilities.provider.service,
                context: capabilities.context, wallet: NativeHolderSessionWalletPort(wallet: repository), custody: custody,
                issuer: HTTPSHolderSessionIssuer(transport: transport, configuration: configuration, capabilities: capabilities),
                journal: HolderSessionJournal(directory: base))
            }
          review = model
        } catch {
          self.error = "This service needs session support and a saved version 2 reusable grant. Review or save its reusable grant in Work access, then try again. Your existing access is preserved."
        }
      }
  }
}
