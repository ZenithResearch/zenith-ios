import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

extension UTType {
  static let castaliaRecovery = UTType(exportedAs: "ca.castalia.recovery", conformingTo: .data)
}
struct EncryptedFile: FileDocument {
  static var readableContentTypes: [UTType] { [.data] }
  static var writableContentTypes: [UTType] { [.castaliaRecovery] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents, data.count <= 1_048_576 else {
      throw WalletFailure.invalidFile
    }
    self.data = data
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
/// Bound both before and during reading; a provider's advertised size is untrusted.
func readSelectedFile(_ url: URL) throws -> Data {
  try EncryptedImportFile.read(url)
}
struct RecoveryView: View {
  @EnvironmentObject private var model: WalletModel
  var body: some View {
    List {
      Section {
        StatusRow(title: "Recovery", status: model.state?.backupVerified == true ? "Backup checked" : "Backup needs checking", icon: "checkmark.shield")
      }
      Section {
        NavigationLink("Save a recovery backup") { BackupFlowView(isOnboarding: false) }
        NavigationLink("Check a saved backup") { BackupFlowView(isOnboarding: false, startsChecking: true) }
      }
      Section {
        NavigationLink("Import or save Castaway data") { DataFileView() }
      }
    }.navigationTitle("Recovery")
  }
}
