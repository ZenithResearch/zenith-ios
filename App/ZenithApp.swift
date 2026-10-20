import SwiftUI
import ZenithKit

@main
struct ZenithApp: App {
  @StateObject private var model = WalletModel()
  @Environment(\.scenePhase) private var scene
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(model)
        .environmentObject(model.workDraft)
        .environmentObject(model.privateNetwork)
        .tint(Color(uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.47, green: 0.91, blue: 0.78, alpha: 1)
            : UIColor(red: 0.09, green: 0.34, blue: 0.28, alpha: 1)
        }))
        .task { await model.load() }
        .onChange(of: scene) { _, phase in
          if phase == .background { model.suspend() }
          if phase == .active { model.privateNetwork.resume() }
          model.obscured = phase != .active
        }
        .onReceive(
          NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification)
        ) { _ in model.suspend() }
    }
  }
}

@MainActor
final class WalletModel: ObservableObject {
  let workDraft = WorkServerDraft()
  let biometricUnlock = BiometricUnlock(store: BiometricKeychain())
  @Published var biometricEnabled = false
  let privateNetwork = PrivateNetworkModel(driver: TailscaleDriver())
  enum OnboardingCompletion { case created, imported }
  @Published var onboardingCompletion: OnboardingCompletion?
  @Published var state: WalletState?
  // Only encrypted selected files survive background locking, in memory.
  @Published var recoverySelection: Data?
  @Published var dataSelection: Data?
  @Published var busy = false
  @Published var error: String?
  @Published var notice: String?
  @Published var obscured = false
  @Published var generation = 0
  @Published private(set) var workServer: WorkAccessConfiguration?
  private var workServerStore: WorkServerStore?
  private(set) var accessRequestStore: WorkAccessRequestStore?
  private(set) var repository: WalletRepository?
  private var operation: Task<Void, Never>?
  init() {
    do {
      let base = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      repository = try WalletRepository(
        directory: base.appendingPathComponent("CastaliaWallet", isDirectory: true))
      workServerStore = try WorkServerStore(
        directory: base.appendingPathComponent("WorkConnection", isDirectory: true))
      workServer = try workServerStore?.load()
      accessRequestStore = try WorkAccessRequestStore(directory:base.appendingPathComponent("WorkRequests",isDirectory:true))
    } catch { self.error = "Wallet storage is unavailable. Reopen Zenith to try again." }
  }
  func load() async {
    guard let repository else { return }
    do { state = try await repository.state(); biometricEnabled = biometricUnlock.isEnabled } catch { self.error = error.localizedDescription }
  }
  func saveWorkServer(_ configuration: WorkAccessConfiguration?, completion: @escaping () -> Void) {
    guard !busy, let store = workServerStore else { return }
    let previous = workServer
    perform({ repository in
      // Never reuse authority from a removed configuration or an older bundled
      // setup. Every newly selected server requires a fresh read approval.
      for origin in Set([previous?.origin, configuration?.origin].compactMap({ $0 })) {
        try await repository.forgetReadAccess(receiver: origin)
      }
    }) { _ in
      do {
        try store.save(configuration, replacing: previous)
        self.workServer = configuration
        self.workDraft.reset()
        self.generation += 1
        self.notice = configuration == nil ? "Server removed from this device." : "Server saved. Review read access to connect."
        completion()
      } catch { self.error = "Could not save server settings. Any previous read access was disconnected; please reconnect after trying again." }
    }
  }
  func perform<T>(
    _ action: @escaping (WalletRepository) async throws -> T, success: @escaping (T) -> Void
  ) {
    guard !busy, let repository else { return }
    busy = true
    error = nil
    notice = nil
    let version = generation
    operation = Task {
      do {
        try Task.checkCancellation()
        let result = try await action(repository)
        guard version == generation else { return }
        state = try await repository.state()
        guard version == generation else { return }
        busy = false
        biometricEnabled = biometricUnlock.isEnabled
        success(result)
      } catch {
        guard version == generation else { return }
        let current = try? await repository.state()
        guard version == generation else { return }
        state = current
        busy = false
        biometricEnabled = biometricUnlock.isEnabled
        self.error = error.localizedDescription
      }
    }
  }
  func suspend() {
    biometricUnlock.cancel()
    privateNetwork.suspend()
    operation?.cancel()
    operation = nil
    generation += 1
    busy = false
    state = nil
    error = nil
    notice = nil
    onboardingCompletion = nil
    repository?.invalidatePendingWork()
    Task {
      await repository?.lock()
      await load()
    }
  }
  func cancel() {
    biometricUnlock.cancel()
    operation?.cancel()
    operation = nil
    generation += 1
    busy = false
    error = nil
    repository?.invalidatePendingWork()
    Task { await repository?.cancel() }
  }
}
