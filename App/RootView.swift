import SwiftUI
import ZenithKit

struct RootView: View {
  @EnvironmentObject private var model: WalletModel
  @AppStorage("selectedDestination") private var destination = "work"
  var body: some View {
    ZStack {
      Group {
        if let state = model.state {
          if !state.configured {
            WelcomeView()
          } else if !state.unlocked {
            UnlockView()
          } else if model.onboardingCompletion != nil {
            WalletReadyView()
          } else if !state.backupVerified {
            NavigationStack { BackupFlowView(isOnboarding: true) }
          } else {
            TabView(selection: $destination) {
              NativeWorkView().tabItem { Label("Work", systemImage: "list.bullet") }.tag("work")
              WalletView().tabItem { Label("Wallet", systemImage: "wallet.pass") }.tag("wallet")
            }
          }
        } else if model.repository != nil {
          ProgressView("Opening wallet")
        } else {
          ContentUnavailableView(
            "Wallet unavailable", systemImage: "externaldrive.badge.exclamationmark",
            description: Text(model.error ?? "Reopen Zenith to try again."))
        }
      }
      if model.obscured {
        Color(uiColor: .systemBackground).ignoresSafeArea().overlay(
          Text("Zenith").font(.title2).bold()
        ).accessibilityHidden(true)
      }
    }.onChange(of: model.state?.unlocked) { _, unlocked in
      if unlocked == true && model.state?.backupVerified != true { destination = "wallet" }
    }
  }
}
struct Feedback: View {
  @EnvironmentObject private var model: WalletModel
  var body: some View {
    if let error = model.error {
      Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently)
    }
    if let notice = model.notice {
      Label(notice, systemImage: "checkmark.circle").accessibilityAddTraits(.updatesFrequently)
    }
    if model.busy { ProgressView("Working securely on this device") }
  }
}
struct WelcomeView: View {
  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Welcome to Zenith").font(.largeTitle).bold()
            Text("Start fresh or bring your wallet to this phone.").foregroundStyle(
              .secondary)
            VStack(spacing: 12) {
              NavigationLink {
                CreateView()
              } label: {
                WalletStartChoice(
                  title: "Create a wallet", detail: "Start with a new wallet.", icon: "plus.circle")
              }.accessibilityIdentifier("wallet.create")
              NavigationLink {
                RestoreView(startWithScanner: true)
              } label: {
                WalletStartChoice(
                  title: "Scan to import", detail: "Scan your encrypted backup from a laptop.",
                  icon: "qrcode.viewfinder")
              }.accessibilityIdentifier("wallet.import")
            }.buttonStyle(.plain)
            Spacer()
            Text("Powered by Castalia Wallet").font(.footnote).foregroundStyle(.secondary)
          }.padding(24).frame(minHeight: geometry.size.height)
        }
      }
    }
  }
}
private struct WalletStartChoice: View {
  let title: String
  let detail: String
  let icon: String
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon).font(.title2).foregroundStyle(.tint)
        .frame(width: 28).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.headline).foregroundStyle(.primary)
        Text(detail).font(.subheadline).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary).accessibilityHidden(true)
    }.padding(20).frame(minHeight: 80)
      .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
      .contentShape(RoundedRectangle(cornerRadius: 16))
      .accessibilityElement(children: .combine)
  }
}
struct UnlockView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var password = ""
  var body: some View {
    NavigationStack {
      Form {
        Section { SecureField("Wallet password", text: $password).textContentType(.password) }
        Section {
          Button("Unlock") {
            let value = password
            password = ""
            model.perform({ try await $0.unlock(password: value) }) { _ in }
          }.buttonStyle(.borderedProminent).disabled(password.isEmpty || model.busy)
          Feedback()
        }
      }.navigationTitle("Unlock your wallet")
        .onChange(of: model.generation) { _, _ in password = "" }
    }
  }
}
struct WalletView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var connected = false
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            MembershipView()
          } label: {
            StatusRow(
              title: "Membership",
              status: model.state?.membershipActive == true ? "Active" : "Not connected",
              icon: "person.crop.circle.badge.checkmark")
          }
          NavigationLink {
            RecoveryView()
          } label: {
            StatusRow(
              title: "Recovery",
              status: model.state?.backupVerified == true
                ? "Recovery checked" : "Check your recovery file", icon: "doc.badge.arrow.up")
          }
          NavigationLink {
            WorkAccessView()
          } label: {
            StatusRow(
              title: "Work access", status: connected ? "Read only" : "Not connected", icon: "eye")
          }
        }
        Section {
          DisclosureGroup("Wallet details") {
            Text("Castalia Member Key").font(.caption).foregroundStyle(.secondary)
            Text(model.state?.publicKey ?? "").font(.caption.monospaced()).textSelection(.enabled)
          }
          Button("Lock wallet", systemImage: "lock") { model.suspend() }
        }
        Section { Feedback() }
      }.navigationTitle("Wallet")
        .task { connected = (try? await workClient(model)?.manifest()) != nil }
        .onChange(of: model.generation) { _, _ in connected = false }
    }
  }
}
struct StatusRow: View {
  let title: String, status: String, icon: String
  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
        Text(status).font(.subheadline).foregroundStyle(.secondary)
      }
    } icon: {
      Image(systemName: icon)
    }.padding(.vertical, 4)
  }
}
struct SetupInformation: View {
  enum Kind { case membership, work }
  let kind: Kind
  var body: some View {
    Form {
      Section {
        Text(kind == .membership ? "Membership setup is needed" : "Work access setup is needed")
          .font(.headline)
        Text(
          kind == .membership
            ? "This development build has no approved Zenith membership provider. Ask your administrator for a configured build."
            : "This development build has no approved work-access service. Ask your administrator for a configured build."
        )
      }
      Section {
        Text(
          kind == .membership
            ? "Joining Zenith and connecting work are separate choices. Restoring a wallet does not join a membership."
            : "Work access will be read only. It cannot create, change or delete work."
        ).foregroundStyle(.secondary)
      }
    }.navigationTitle(kind == .membership ? "Membership" : "Work access")
  }
}
