import SwiftUI
import ZenithKit

struct MembershipView: View {
  var continueToWork: (() -> Void)? = nil
  @EnvironmentObject private var model: WalletModel
  @State private var trustApproved = false
  @State private var joining = false
  @State private var transport = PrivateTransport()
  @State private var imported: [Data] = []
  private var configuration: MembershipConfiguration? { .bundled() }
  var body: some View {
    Group {
      if let configuration {
        Form {
          Section {
            Text(model.state?.membershipActive == true ? "Membership active" : "Join Zenith").font(
              .headline)
            LabeledContent("Provider", value: configuration.name)
            Text(configuration.endpoint.host ?? "").foregroundStyle(.secondary)
            Text(
              "Your public Wallet ID is shared with this provider. Joining does not connect or change your work."
            )
            DisclosureGroup("Provider details") {
              Text(String(data: (try? configuration.trustData) ?? Data(), encoding: .utf8) ?? "")
                .font(.caption.monospaced()).textSelection(.enabled)
            }
          }
          if model.state?.membershipActive == true {
            Section {
              Text("Your Zenith membership is active. Work access is approved separately by your server’s operator.")
              if let continueToWork {
                Button("Continue to Work", action: continueToWork)
                  .buttonStyle(.borderedProminent)
                  .accessibilityIdentifier("membership.continue.work")
              }
            }
          } else if model.state?.backupVerified != true {
            Section {
              Text("Check your saved recovery file before joining.")
              NavigationLink("Open Recovery") { RecoveryView() }
            }
          } else if !trustApproved {
            Section {
              Button("Trust this membership provider") {
                model.perform({ try await $0.approveTrust(configuration.trustData) }) { _ in
                  trustApproved = true
                }
              }.buttonStyle(.borderedProminent).disabled(model.busy)
            }
          } else if model.state?.membershipActive != true {
            if !imported.isEmpty {
              Section("Saved membership") {
                Text("Use a membership proof restored with your data. This does not connect work.")
                ForEach(Array(imported.enumerated()), id: \.offset) { index, proof in
                  Button(
                    imported.count == 1
                      ? "Use saved membership" : "Use saved membership \(index + 1)"
                  ) {
                    model.perform({
                      try await $0.activateMembership(proof, scoped: configuration.scope != nil)
                    }) { _ in model.notice = "Membership active. Work access is a separate step." }
                  }.disabled(model.busy)
                }
              }
            }
            Section {
              Button("Join Zenith") {
                let version = model.generation
                model.perform({ repository in
                  let body = try await repository.membershipRequest(scope: configuration.scope)
                  var request = URLRequest(url: configuration.endpoint)
                  request.httpMethod = "POST"
                  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                  request.httpBody = body
                  let response = try await transport.request(request, maximum: 65_536)
                  // Navigation and lock are checked before any returned proof is saved.
                  guard await MainActor.run(body: { model.generation == version }) else {
                    throw WalletFailure.locked
                  }
                  return try await repository.activateMembership(
                    response, scoped: configuration.scope != nil)
                }) { _ in model.notice = "Membership active. Work access is a separate step." }
              }.buttonStyle(.borderedProminent).disabled(model.busy)
            }
          }
          Section { Feedback() }
        }.navigationTitle("Membership")
          .task {
            trustApproved =
              (try? await model.repository?.trustMatches(configuration.trustData)) == true
            imported =
              (try? await model.repository?.importedMemberships(scope: configuration.scope)) ?? []
          }
          .onChange(of: model.generation) { _, _ in
            transport.cancel()
            trustApproved = false
          }
          .onDisappear {
            transport.cancel()
            model.cancel()
          }
      } else {
        SetupInformation(kind: .membership)
      }
    }
  }
}
