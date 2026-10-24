import SwiftUI
import ZenithKit

/// A single decision per page, with its next action always in the same place.
struct WalletFlowPage<Content: View>: View {
  let step: String
  let title: String
  let detail: String
  var buttonTitle: String? = nil
  var enabled = true
  var busy = false
  var action: () -> Void = {}
  @ViewBuilder var content: () -> Content
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 10) {
          Text(step).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
          Text(title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
          Text(detail).foregroundStyle(.secondary)
        }
        content()
      }.frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity).padding(24)
    }.scrollDismissesKeyboard(.interactively)
      .background(Color(uiColor: .systemBackground))
      .safeAreaInset(edge: .bottom) {
        if let buttonTitle {
          VStack(spacing: 0) {
            Divider()
            Button(action: action) {
              HStack {
                if busy { ProgressView() }
                Text(busy ? "Please wait…" : buttonTitle).font(.headline)
              }.frame(maxWidth: .infinity, minHeight: 40)
            }.buttonStyle(.borderedProminent)
              .foregroundStyle(Color(uiColor: enabled && !busy ? .systemBackground : .label))
              .disabled(!enabled || busy).padding(.horizontal, 24).padding(.vertical, 12)
          }.background(Color(uiColor: .systemBackground))
        }
      }.navigationBarTitleDisplayMode(.inline)
  }
}

/// Labels remain visible when AutoFill hides a SecureField's placeholder.
struct WalletPasswordField: View {
  let title: String
  var prompt = "Enter password"
  @Binding var text: String
  var isNew = false
  var body: some View {
    WalletPasswordEntry(title: title, text: $text, isNew: isNew).accessibilityHint(prompt)
  }
}

struct WalletSelectedFile: View {
  let title: String
  var detail: String = "Encrypted backup"
  var change: (() -> Void)? = nil
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "doc.badge.lock").font(.title2).foregroundStyle(.tint).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
      if let change { Button("Change", action: change).frame(minHeight: 44) }
    }.padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
  }
}

/// One source selector shared by both flows; it only returns encrypted bytes.
struct WalletFilePicker: View {
  enum Primary { case scan, files }
  var primary: Primary = .files
  var startWithScanner = false
  let receive: (Data, String) -> Void
  @State private var scanning = false
  @State private var usb = false
  @State private var choosing = false
  @State private var started = false
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button {
        if primary == .scan { scanning = true } else { choosing = true }
      } label: {
        Label(primary == .scan ? "Scan laptop QR" : "Select saved file",
          systemImage: primary == .scan ? "qrcode.viewfinder" : "folder")
          .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
      }.buttonStyle(.borderedProminent).foregroundStyle(Color(uiColor: .systemBackground))
      Menu("Other ways to import") {
        if primary == .scan { Button("Choose from Files", systemImage: "folder") { choosing = true } }
        else { Button("Scan laptop QR", systemImage: "qrcode.viewfinder") { scanning = true } }
        Button("Use USB cable", systemImage: "cable.connector") { usb = true }
      }.frame(minHeight: 44)
      if let error { Text(error).foregroundStyle(.red) }
    }
    .sheet(isPresented: $scanning) { ScanTransferView { receive($0, "Scanned backup") } }
    .sheet(isPresented: $usb) { USBTransferView { receive($0, "Backup from USB") } }
    .fileImporter(isPresented: $choosing, allowedContentTypes: [.data, .json, .item]) { result in
      do {
        let url = try result.get()
        receive(try EncryptedImportFile.read(url), url.lastPathComponent)
        error = nil
      } catch {
        if (error as NSError).code != NSUserCancelledError {
          self.error = "That file could not be read. Choose an encrypted recovery or Castaway file."
        }
      }
    }
    .onAppear {
      if startWithScanner && !started { started = true; scanning = true }
    }
  }
}

struct WalletReadyView: View {
  @EnvironmentObject private var model: WalletModel
  @AppStorage("selectedDestination") private var destination = "wallet"
  var body: some View {
    NavigationStack {
      WalletFlowPage(step: "Complete", title: "Your wallet is ready",
        detail: model.onboardingCompletion == .imported
          ? "Your wallet has been imported and its recovery file checked."
          : "Your wallet is created and your saved recovery file has been checked.",
        buttonTitle: "Continue to Zenith", action: {
          destination = "wallet"
          model.onboardingCompletion = nil
          model.notice = nil
        }) {
          Label("Recovery checked", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.tint)
          Text("Membership and work access are separate. You can set them up from Wallet.").foregroundStyle(.secondary)
        }.navigationTitle("Wallet ready")
    }
  }
}
