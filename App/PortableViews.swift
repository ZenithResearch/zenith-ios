import SwiftUI
import ZenithKit

struct PreviewRows: View {
  let review: WalletImportReview
  var body: some View { WalletImportReviewContent(review: review) }
}
struct DataFileView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var selecting = false
  @State private var password = ""
  @State private var preview: WalletImportReview?
  @State private var exporting = false
  @State private var document: EncryptedFile?
  @State private var exportPassword = ""
  var body: some View {
    Form {
      Section {
        Text(
          "A Castaway data file contains your profile, membership proofs, saved account identities and public account descriptors. It cannot restore your signing identity or connect work."
        )
        NavigationLink("Review membership provider") { MembershipView() }
      }
      if let preview {
        Section("Review import") {
          PreviewRows(review: preview)
          Text("Your active membership stays unchanged. Nothing will be published.")
        }
        Section {
          Button("Import data") {
            model.perform({ try await $0.commit(preview.preview) }) { _ in
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
          Button(model.dataSelection == nil ? "Choose Castaway data file" : "Choose another file") {
            selecting = true
          }.frame(minHeight: 44)
          TransferImportButtons { model.dataSelection = $0; password = "" }
          if let selected = model.dataSelection {
            SecureField("Data file password", text: $password).textContentType(.password)
            Button("Review data") {
              let secret = password
              password = ""
              model.perform({ repository in
                let context = try WalletImportReview.Context.dataFile(selected, recovering: false)
                return WalletImportReview(preview: try await repository.prepareData(file: selected, password: secret), context: context)
              }) { preview = $0 }
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
          }.disabled(!WalletPasswordRules.permitsLocal(exportPassword) || model.busy)
        } header: {
          Text("Export")
        } footer: {
          Text(
            "At least 12 characters. Disclosure settings are preserved. Saving never publishes your data."
          )
        }
      }
      Section { Feedback() }
    }.navigationTitle("Castaway data")
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
      .onChange(of: model.dataSelection) { _, _ in
        if preview != nil { preview = nil; model.cancel() }
      }
      .onDisappear {
        preview = nil
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
  @State private var preview: WalletImportReview?
  var body: some View {
    Form {
      Section {
        Text(
          "Use an older Castalia recovery key only if that is the backup you have. You’ll save and check an encrypted recovery file next."
        )
      }
      if let preview {
        Section {
          PreviewRows(review: preview)
          Button("Import wallet") {
            model.perform({ try await $0.commit(preview.preview) }) { _ in
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
              preview = WalletImportReview(preview: $0, context: .olderRecoveryKey)
            }
          }.buttonStyle(.borderedProminent).disabled(
            key.isEmpty || !WalletPasswordRules.permitsLocal(password) || model.busy)
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
        preview = nil
        key = ""
        password = ""
        model.cancel()
      }
  }
}
