import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

/// Proofs belong to Wallet; provider approval remains an explicit separate step.
struct WalletMembershipScreen: View {
  @EnvironmentObject private var model: WalletModel
  var body: some View {
    WalletMembershipContent(repository: model.repository, unlocked: model.state?.unlocked == true)
      .safeAreaInset(edge: .bottom) {
        VStack(alignment: .leading, spacing: 12) {
          NavigationLink { DataFileView() } label: {
            Label("Import Castaway data", systemImage: "square.and.arrow.down")
          }.accessibilityIdentifier("wallet.membership.import")
          NavigationLink { MembershipView() } label: {
            Label("Join or activate membership", systemImage: "person.crop.circle.badge.checkmark")
          }.accessibilityIdentifier("wallet.membership.join")
          Text("Import into this Wallet without replacing its keys. Membership provider approval and activation are separate; neither grants DevGraph access.")
            .font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.regularMaterial)
      }.navigationTitle("Membership")
  }
}

struct MembershipView: View {
  var continueToWork: (() -> Void)? = nil
  @EnvironmentObject private var model: WalletModel
  @State private var trustApproved = false
  @State private var joining = false
  @State private var transport = PrivateTransport()
  @State private var imported: [Data] = []
  @AppStorage(MembershipConfiguration.settingsKey) private var providerData = Data()
  @State private var selectingProvider = false
  @State private var proposedProvider: MembershipConfiguration?
  @State private var reviewingProvider = false
  private var configuration: MembershipConfiguration? {
    providerData.isEmpty ? .bundled() : try? .decodeFile(providerData)
  }
  var body: some View {
    Group {
      if let configuration {
        Form {
          Section {
            Text(model.state?.membershipActive == true ? "Membership active" : "Join \(configuration.name)").font(
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
              Text("Membership is active. Work access is approved separately by your server’s operator.")
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
              Button("Join \(configuration.name)") {
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
          .task(id: providerData) {
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
        Form {
          Section("Membership provider") {
            Text("No membership provider is configured in this app.")
            Text("Choose the public provider settings supplied by your community. Review its address and issuer keys before approving trust or joining. A DevGraph connection is not a membership provider.")
            Button("Choose provider configuration") { selectingProvider = true }
              .accessibilityIdentifier("membership.provider.import")
          }
          Section {
            NavigationLink("Import Castaway data") { DataFileView() }
            Text("Saved membership proofs need their issuer’s approved configuration before import. A Castaway file cannot approve its own issuer.")
              .font(.footnote).foregroundStyle(.secondary)
          }
          Section { Feedback() }
        }.navigationTitle("Membership")
      }
    }.fileImporter(isPresented: $selectingProvider, allowedContentTypes: [.json]) { result in
      do {
        proposedProvider = try MembershipConfiguration.decodeFile(readSelectedFile(result.get()))
        reviewingProvider = true
      } catch {
        if (error as NSError).code != NSUserCancelledError {
          model.error = "Choose a public membership-provider JSON configuration with an HTTPS endpoint and issuer trust settings."
        }
      }
    }.sheet(isPresented: $reviewingProvider) {
      NavigationStack {
        Form {
          if let proposedProvider {
            Section("Review proposed provider") {
              LabeledContent("Name", value: proposedProvider.name)
              Text(proposedProvider.endpoint.absoluteString).textSelection(.enabled)
              if let scope = proposedProvider.scope { Text("Community scope: " + scope) }
              Text(String(data: (try? proposedProvider.trustData) ?? Data(), encoding: .utf8) ?? "")
                .font(.caption.monospaced()).textSelection(.enabled)
            }
            Section {
              Text("These public settings stay in this application, outside Wallet backups. Saving them does not trust the issuer, send your identity, join a community, or grant graph access.")
              Button("Use provider settings") {
                do {
                  let data = try JSONEncoder().encode(proposedProvider)
                  model.cancel(); trustApproved = false; imported = []
                  providerData = data; reviewingProvider = false
                } catch { model.error = "Provider settings could not be saved." }
              }.disabled(model.busy)
            }
          }
        }.navigationTitle("Membership provider")
          .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reviewingProvider = false } } }
      }
    }
  }
}
