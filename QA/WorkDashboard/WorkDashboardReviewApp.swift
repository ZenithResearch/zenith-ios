import SwiftUI
import ZenithKit

@main
struct WorkDashboardReviewApp: App {
  @State private var captureText = ""
  @State private var captures: [String] = []
  @State private var captureRequested = false
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        WorkDashboardView(snapshot: ReviewData.snapshot, loading: false,
          message: "Design review · synthetic Work · no live Wallet or server", loadMore: nil,
          destination: { row in AnyView(ReviewDetail(row: row)) },
          arenaDestination: { row in AnyView(Text(row.title)) },
          captureText: $captureText, captures: $captures, captureRequested: $captureRequested)
          .navigationTitle("Work").navigationBarTitleDisplayMode(.inline)
          .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Capture") { captureRequested = true } } }
      }.tint(Color(red: 0.09, green: 0.34, blue: 0.28))
        .dynamicTypeSize(ProcessInfo.processInfo.environment["WORK_REVIEW_LARGE_TEXT"] == "1" ? .accessibility2 : .large)
    }
  }
}
private struct ReviewDetail: View {
  let row: WorkRecord
  var body: some View {
    List {
      Section { Text(row.title).font(.headline); Text(row.progressLabel); Text("Synthetic review item · no session or work mutation") }
      let children = ReviewData.snapshot.records.filter { $0.parent == row.rowID }
      if !children.isEmpty {
        Section("Related work") { ForEach(children, id: \.rowID) { child in NavigationLink(child.title) { ReviewDetail(row: child) } } }
      }
    }.navigationTitle(row.kind).navigationBarTitleDisplayMode(.inline)
  }
}
private enum ReviewData {
  static let snapshot: WorkDashboard = {
    func row(_ kind: String, _ id: String, _ title: String, _ progress: String?, _ parent: String?, _ date: String, priority: Int = 0) -> WorkRecord {
      let value: [String: Any] = ["kind":kind,"id":id,"title":title,"description":"Synthetic design review", "priority":priority,"version":1,"progress":progress as Any? ?? NSNull(),"parent":parent as Any? ?? NSNull(),"updated_at":date]
      return try! JSONDecoder().decode(WorkRecord.self, from: JSONSerialization.data(withJSONObject: value))
    }
    let arena = try! JSONDecoder().decode(ArenaRecord.self, from: Data("{\"kind\":\"Arena\",\"id\":\"product\",\"title\":\"Product\",\"description\":\"Synthetic\",\"version\":1,\"archived\":false}".utf8))
    return WorkDashboard(records: [
      row("Initiative","operator","A clear operator workspace",nil,nil,"2026-10-28T12:00:00Z"),
      row("Project","work-page","Native Work page","in_progress","Initiative/operator","2026-10-28T19:00:00Z"),
      row("Project","session-links","Session-to-work provenance","in_progress","Initiative/operator","2026-10-28T18:00:00Z"),
      row("Issue","mobile-overview","Make the overview readable on iPhone","in_progress","Project/work-page","2026-10-28T19:00:00Z"),
      row("Issue","preserve-links","Keep source activity and Done separate","in_progress","Project/session-links","2026-10-28T18:00:00Z"),
      row("Task","layout","Check Pulse, Activity and Todo together","in_progress","Issue/mobile-overview","2026-10-28T20:00:00Z"),
      row("Task","components","Use native input and navigation","done","Issue/mobile-overview","2026-10-28T17:00:00Z"),
      row("Task","review","Review the compact iPad layout","not_started","Issue/mobile-overview","2026-10-28T16:00:00Z",priority:80),
      row("Task","coverage","Check session source coverage","not_started","Issue/preserve-links","2026-10-28T15:00:00Z",priority:60)
    ], arenas:[arena], members:["product":["Initiative/operator"]], complete:true, arenaMembershipComplete:true)
  }()
}
