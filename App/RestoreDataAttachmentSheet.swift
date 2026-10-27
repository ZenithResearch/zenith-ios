import SwiftUI
import ZenithKit

/// Optional data stays out of the main import path. It is still included in the
/// same authenticated prepare/review/commit as recovery when explicitly added.
struct RestoreDataAttachmentSheet: View {
  @Binding var trustApproved: Bool
  let receive: (Data, String, String) -> Void
  @EnvironmentObject private var model: WalletModel
  @Environment(\.dismiss) private var dismiss
  @State private var file: Data?
  @State private var name = "Castaway data"
  @State private var password = ""
  var body: some View {
    NavigationStack {
      WalletFlowPage(step: "Optional", title: "Include your data",
        detail: "Add a Castaway file for your profile, membership proofs and public accounts. It will be checked with your recovery backup.",
        buttonTitle: file == nil ? nil : "Include data file", enabled: !password.isEmpty, busy: model.busy,
        action: {
          guard let file else { return }
          receive(file, name, password); password = ""; dismiss()
        }) {
          if file == nil {
            WalletFilePicker { data, filename in
              do {
                guard try RecoveryFileFormat.inspect(data, filename: filename).kind == .castaway else {
                  model.error = "That is a recovery backup. Choose a Castaway data file here."; return
                }
                file = data; name = filename; model.error = nil
              } catch { model.error = "That data file could not be read." }
            }
          } else {
            WalletSelectedFile(title: name, detail: "Castaway data", change: { file = nil; password = "" })
            WalletPasswordField(title: "Data file password", text: $password)
            if let configuration = MembershipConfiguration.proposed() {
              DisclosureGroup("Membership proof provider") {
                VStack(alignment: .leading, spacing: 12) {
                  Text(configuration.name)
                  Text(String(data: (try? configuration.trustData) ?? Data(), encoding: .utf8) ?? "")
                    .font(.caption.monospaced())
                  if trustApproved { Label("Provider approved", systemImage: "checkmark.circle") }
                  else {
                    Button("Approve provider for this import") {
                      model.perform({ try await $0.approveRestoreTrust(configuration.trustData) }) { _ in trustApproved = true }
                    }.disabled(model.busy)
                  }
                  Text("Files cannot add trust or activate membership.").font(.footnote)
                }.padding(.top, 12)
              }
            } else {
              Text("Data with membership proofs needs a configured, approved provider. Profile-only files can be checked now.")
                .font(.footnote).foregroundStyle(.secondary)
            }
          }
          Feedback()
        }.navigationTitle("Add data")
          .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }.onChange(of: model.generation) { _, _ in password = ""; dismiss() }
      .onDisappear { password = "" }
  }
}
