import SwiftUI
import ZenithKit

struct PreviewRows: View {
  let preview: RestorePreview
  var body: some View {
    LabeledContent(
      "Recovery", value: preview.backupVerified ? "File checked" : "Check a saved file next")
    if let name = preview.profile?.subject.fields["displayName"]?.value, !name.isEmpty {
      LabeledContent("Profile", value: name)
    }
    if preview.replacesProfile == true { Text("Your saved profile will be replaced.") }
    if let ids = preview.replacedProofs, !ids.isEmpty {
      Text("\(ids.count) membership proof(s) will be replaced. Other saved proofs are kept.")
    }
    DisclosureGroup("Wallet details") {
      Text(preview.publicKey).font(.caption.monospaced()).textSelection(.enabled)
    }
    if let proofs = preview.memberships?.proofs, !proofs.isEmpty {
      DisclosureGroup("Membership proofs (\(proofs.count))") {
        ForEach(proofs) { proof in
          VStack(alignment: .leading) {
            Text(proof.issuerId)
            Text(proof.membershipId).font(.caption.monospaced())
          }
        }
      }
    }
    if let accounts = preview.chainAccounts?.accounts {
      DisclosureGroup("Public accounts (\(accounts.count))") {
        ForEach(accounts) { account in
          VStack(alignment: .leading) {
            Text(account.networkId)
            Text(account.address).font(.caption.monospaced())
          }
        }
      }
    }
  }
}
struct DataFileView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var selecting = false
  @State private var password = ""
  @State private var preview: RestorePreview?
  @State private var exporting = false
  @State private var document: EncryptedFile?
  @State private var exportPassword = ""
  var body: some View {
    Form {
      Section {
        Text(
          "A data file contains your profile, membership proofs and public accounts. It cannot restore your signing identity or connect work."
        )
      }
      if let preview {
        Section("Review import") {
          PreviewRows(preview: preview)
          Text("Your active membership stays unchanged. Nothing will be published.")
        }
        Section {
          Button("Import data") {
            model.perform({ try await $0.commit(preview) }) { _ in
              self.preview = nil
              model.dataSelection = nil
              model.notice = "Data saved to your wallet."
            }
          }.buttonStyle(.borderedProminent).disabled(model.busy)
          Button("Cancel") {
            model.cancel()
            self.preview = nil
            model.dataSelection = nil
          }
        }
      } else {
        Section("Import") {
          Button(model.dataSelection == nil ? "Choose data file" : "Choose another file") {
            selecting = true
          }.frame(minHeight: 44)
          TransferImportButtons { model.dataSelection = $0; password = "" }
          if let selected = model.dataSelection {
            SecureField("Data file password", text: $password).textContentType(.password)
            Button("Review data") {
              let secret = password
              password = ""
              model.perform({ try await $0.prepareData(file: selected, password: secret) }) {
                preview = $0
              }
            }.buttonStyle(.borderedProminent).disabled(password.isEmpty || model.busy)
          }
        }
        Section {
          SecureField("New data file password", text: $exportPassword).textContentType(.newPassword)
          Button("Save data file") {
            let secret = exportPassword
            exportPassword = ""
            model.perform({ try await $0.exportData(password: secret) }) {
              document = EncryptedFile(data: $0)
              exporting = true
            }
          }.disabled(exportPassword.count < 12 || model.busy)
        } header: {
          Text("Export")
        } footer: {
          Text(
            "At least 12 characters. Disclosure settings are preserved. Saving never publishes your data."
          )
        }
      }
      Section { Feedback() }
    }.navigationTitle("Data file")
      .fileImporter(isPresented: $selecting, allowedContentTypes: [.data, .json, .item]) { result in
        do { model.dataSelection = try readSelectedFile(result.get()) } catch {
          if (error as NSError).code != NSUserCancelledError {
            model.error = "The file could not be read."
          }
        }
      }
      .fileExporter(
        isPresented: $exporting, document: document, contentType: .data,
        defaultFilename: "Castalia.castaway"
      ) { result in
        document = nil
        if case .success = result { model.notice = "Data file saved." }
      }
      .onChange(of: model.generation) { _, _ in
        password = ""
        exportPassword = ""
        preview = nil
        document = nil
      }
      .onDisappear {
        password = ""
        exportPassword = ""
        model.cancel()
      }
  }
}
struct LegacyRecoveryView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var key = ""
  @State private var password = ""
  @State private var preview: RestorePreview?
  var body: some View {
    Form {
      Section {
        Text(
          "Use an older Castalia recovery key only if that is the backup you have. You’ll save and check an encrypted recovery file next."
        )
      }
      if let preview {
        Section {
          PreviewRows(preview: preview)
          Button("Import wallet") {
            model.perform({ try await $0.commit(preview) }) { _ in
              model.notice = "Wallet imported. Save and check a recovery file next."
            }
          }.buttonStyle(.borderedProminent).disabled(model.busy)
        }
      } else {
        Section {
          SecureField("Existing recovery key", text: $key).textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          SecureField("New wallet password", text: $password).textContentType(.newPassword)
        } footer: {
          Text("Use at least 12 characters for your new password.")
        }
        Section {
          Button("Review wallet") {
            let old = key
            let secret = password
            key = ""
            password = ""
            model.perform({ try await $0.prepareLegacy(key: old, password: secret) }) {
              preview = $0
            }
          }.buttonStyle(.borderedProminent).disabled(
            key.isEmpty || password.count < 12 || model.busy)
        }
      }
      Section { Feedback() }
    }.navigationTitle("Older recovery key")
      .onChange(of: model.generation) { _, _ in
        key = ""
        password = ""
        preview = nil
      }
      .onDisappear {
        key = ""
        password = ""
        model.cancel()
      }
  }
}
