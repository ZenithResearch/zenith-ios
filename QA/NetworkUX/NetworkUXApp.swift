// Simulator-only, isolated UI review. No Wallet, real network driver or credentials.
#if targetEnvironment(simulator)
import SwiftUI
import ZenithKit

private actor ReviewDriver: PrivateNetworkDriver {
  var state = "Running"
  var saved: Bool
  var unreadable = false
  let scenario: String
  init(_ scenario: String) { self.scenario = scenario; saved = scenario != "new" && scenario != "approval"; unreadable = scenario == "storage" }
  func hasStoredState() async throws -> Bool {
    if unreadable { throw PrivateNetworkError.interrupted }
    return saved
  }
  func start(interactive: Bool) async throws {
    state = scenario == "reauth" ? "NeedsLogin" : "Running"
  }
  func enroll(authKey: String) async throws {
    saved = true
    state = scenario == "approval" ? "NeedsMachineAuth" : "Running"
  }
  func status() async throws -> PrivateNetworkStatus {
    try PrivateNetworkStatus(data: JSONSerialization.data(withJSONObject: [
      "BackendState": state, "CurrentTailnet": ["Name": "Example review network"]]))
  }
  func configuration() async throws -> URLSessionConfiguration { throw PrivateNetworkError.disconnected }
  func stop() async {}
  func transition(_ state: String) { self.state = state }
  func unlockStorage() { unreadable = false }
}

@main
struct NetworkUXApp: App {
  var body: some Scene {
    WindowGroup {
      ReviewFlow().dynamicTypeSize(ProcessInfo.processInfo.environment["NETWORK_UX_LARGE_TEXT"] == "1" ? .accessibility5 : .large)
    }
  }
}

private struct ReviewFlow: View {
  @State private var scenario: String? = ProcessInfo.processInfo.environment["NETWORK_UX_SCENARIO"]
  var body: some View {
    NavigationStack {
      Group {
      if let scenario { ReviewNetwork(scenario: scenario).id(scenario) }
      else {
        List {
          Section("Synthetic scenarios · no live network or Wallet") {
            ForEach(["new", "saved", "approval", "reauth", "storage"], id: \.self) { value in
              Button(value) { scenario = value }
            }
          }
        }.navigationTitle("Network UX review")
      }
      }.toolbar { ToolbarItem(placement: .topBarLeading) { if scenario != nil { Button("Scenarios") { scenario = nil } } } }
    }
  }
}

private struct ReviewNetwork: View {
  let scenario: String
  private let driver: ReviewDriver
  @StateObject private var network: PrivateNetworkSession
  init(scenario: String) {
    self.scenario = scenario
    let driver = ReviewDriver(scenario)
    self.driver = driver
    _network = StateObject(wrappedValue: PrivateNetworkSession(driver: driver))
  }
  var body: some View {
    Form {
      Section("Private network") { PrivateNetworkRow() }
      Section("Simulator controls · synthetic only") {
        Button("Simulate temporary interruption") { Task { await driver.transition("Starting") } }
        Button("Simulate device approval needed") { Task { await driver.transition("NeedsMachineAuth") } }
        Button("Simulate approved / restored") { Task { await driver.transition("Running") } }
        Button("Unlock synthetic storage") { Task { await driver.unlockStorage() } }
        Button("Pause and return") { network.suspend(); network.resume() }
      }
      Section {
        Text("Network connection is separate from server reachability and Work authorization. This review cannot contact a server, enroll a device or access a Wallet.")
      }
    }
    .navigationTitle("Network · " + scenario)
    .environmentObject(network)
    .task { await network.restoreSavedConnection() }
  }
}
#endif
