import SwiftUI
import ZenithKit
import CastaliaCustody

@main
struct ZenithApp: App {
  @StateObject private var model = WalletModel()
  @Environment(\.scenePhase) private var scene
  private let idleClock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
  var body: some Scene {
    WindowGroup {
      RootView().walletUserActivity { model.userActivity() }
        .onReceive(idleClock) { _ in if scene == .active { model.expire() } }
        .environmentObject(model)
        .environmentObject(model.workDraft)
        .environmentObject(model.privateNetwork)
        .tint(Color(uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.47, green: 0.91, blue: 0.78, alpha: 1)
            : UIColor(red: 0.09, green: 0.34, blue: 0.28, alpha: 1)
        }))
        .task {
          if UIApplication.shared.isProtectedDataAvailable { await model.privateNetwork.restoreSavedConnection() }
          await model.load()
        }
        .onChange(of: scene) { _, phase in
          switch phase {
          case .background: model.pauseInBackground()
          case .active: model.resumeFromBackground()
          default: model.obscured = true
          }
        }
        .onReceive(
          NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification)
        ) { _ in model.pauseInBackground() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
          if scene == .active { model.resumeFromBackground() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in model.privateNetwork.suspend(); model.suspend() }
    }
  }
}

@MainActor
final class WalletModel: ObservableObject {
  let workDraft = WorkServerDraft()
  let biometricUnlock = BiometricUnlock(store: BiometricKeychain())
  var automaticBiometricUnlock = AutomaticBiometricUnlock()
  @Published var biometricEnabled = false
  let privateNetwork = PrivateNetworkModel(driver: TailscaleDriver(), preferences: .standard)
  enum OnboardingCompletion { case created, imported }
  @Published var onboardingCompletion: OnboardingCompletion?
  static let unlockSettingKey = "wallet.unlockDurationSeconds.v1"
  @Published var unlockDuration = WalletUnlockDuration.load(.standard, key: unlockSettingKey) {
    didSet { UserDefaults.standard.set(unlockDuration.rawValue, forKey: Self.unlockSettingKey); expire() }
  }
  private var unlockTimer = WalletUnlockTimer()
  @Published var state: WalletState? {
    didSet { unlockTimer.observe(unlocked: state?.unlocked == true, now: Date(), uptime: ProcessInfo.processInfo.systemUptime) }
  }
  @Published private(set) var identityAccounts: [IdentityAccount] = []
  private var identityRegistry: IdentityAccountRegistry?
  // Selected recovery/data files remain encrypted even in this process.
  @Published var recoverySelection: Data?
  @Published var dataSelection: Data?
  @Published var busy = false
  @Published var error: String?
  @Published var notice: String?
  @Published var obscured = false
  @Published private(set) var paused = false
  @Published var generation = 0
  @Published private(set) var workServer: WorkAccessConfiguration?
  private var workServerStore: WorkServerStore?
  private(set) var accessRequestStore: WorkAccessRequestStore?
  private(set) var repository: (any WalletSession)?
  private var operation: Task<Void, Never>?
  private var backgrounded = false
  private var backgroundEpoch = 0
  private var backgroundPause: Task<Void, Never>?
  init() {
    do {
      let base = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      identityRegistry = try IdentityAccountRegistry(directory: base.appendingPathComponent("WalletIdentities", isDirectory: true))
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
    let version = generation
    do {
      let current = try await repository.state()
      guard version == generation else { return }
      state = current; biometricEnabled = biometricUnlock.isEnabled
      reloadIdentityAccounts()
    } catch { if version == generation { self.error = error.localizedDescription } }
  }
  func reloadIdentityAccounts() {
    identityAccounts = (try? state?.publicKey.map { try identityRegistry?.load(wallet: $0) ?? [] }) ?? []
  }
  func saveIdentityAccount(_ value: IdentityAccount?, replacing expected: IdentityAccount?) throws {
    expire()
    guard !paused, !obscured, state?.unlocked == true, let owner = state?.publicKey,
      (value?.walletPublicKey ?? expected?.walletPublicKey) == owner, let identityRegistry else { throw WalletFailure.locked }
    try identityRegistry.saveApplicationRecord(value, replacing: expected); reloadIdentityAccounts()
  }
  func userActivity() {
    guard !paused, !obscured, !expire(), state?.unlocked == true else { return }
    unlockTimer.activity(unlockDuration, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
  }
  @discardableResult func expire() -> Bool {
    guard unlockTimer.expired(unlockDuration, now: Date(), uptime: ProcessInfo.processInfo.systemUptime) else { return false }
    suspend(); return true
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
    _ action: @escaping (any WalletSession) async throws -> T, success: @escaping (T) -> Void
  ) {
    guard !expire(), !busy, !paused, !obscured, let repository else { return }
    busy = true
    error = nil
    notice = nil
    let version = generation
    operation = Task {
      do {
        try Task.checkCancellation()
        let result = try await action(repository)
        guard version == generation else { return }
        let current = try await repository.state()
        guard version == generation else { return }
        state = current
        guard !expire(), version == generation else { return }
        reloadIdentityAccounts()
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
    automaticBiometricUnlock.suppress()
    backgroundEpoch += 1
    backgrounded = false
    paused = false
    biometricUnlock.cancel()
    // Wallet custody and network enrollment have independent lifecycles.
    // Background/device lock still closes the embedded node below.
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
  func pauseInBackground() {
    obscured = true
    guard !backgrounded else { return }
    backgrounded = true
    paused = true
    backgroundEpoch += 1
    biometricUnlock.cancel()
    privateNetwork.suspend()
    operation?.cancel(); operation = nil
    generation += 1
    busy = false; error = nil; notice = nil
    // Keep visible state and in-memory custody, but invalidate pending signing.
    // Do not write files while protected data is unavailable.
    backgroundPause = repository?.pauseForBackground()
  }
  func resumeFromBackground() {
    guard UIApplication.shared.isProtectedDataAvailable else { return }
    if expire() { obscured = false; privateNetwork.resume(); return }
    obscured = false
    guard backgrounded else { privateNetwork.resume(); return }
    let epoch = backgroundEpoch
    Task {
      await backgroundPause?.value
      guard epoch == backgroundEpoch, !obscured, backgrounded else { return }
      backgrounded = false
      backgroundPause = nil
      await load()
      guard epoch == backgroundEpoch, !obscured else { return }
      paused = false
      generation += 1
      privateNetwork.resume()
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
