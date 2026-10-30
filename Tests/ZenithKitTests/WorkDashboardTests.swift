import XCTest
@testable import ZenithKit

final class WorkDashboardTests: XCTestCase {
  private func row(_ key: String, parent: String? = nil, updated: String? = nil,
                   progress: String = "not_started", priority: Int = 0) throws -> WorkRecord {
    let pair = key.split(separator: "/")
    var value: [String: Any] = ["kind":String(pair[0]),"id":String(pair[1]),"title":String(pair[1]),"priority":priority,"version":1,"progress":progress]
    if let parent { value["parent"] = parent }; if let updated { value["updated_at"] = updated }
    return try JSONDecoder().decode(WorkRecord.self, from: JSONSerialization.data(withJSONObject:value))
  }
  func testLegacySummariesStillDecodeWithoutHierarchyOrDates() throws {
    let value = try row("Project/old")
    XCTAssertNil(value.parent); XCTAssertNil(value.updated_at)
    XCTAssertNil(WorkDashboard(records:[value]).latestDate(for:value))
  }
  func testDescendantActivityRanksProjectAndContainingIssue() throws {
    let p = try row("Project/one", updated:"2026-10-27T00:00:00Z")
    let other = try row("Project/two", updated:"2026-10-28T00:00:00Z")
    let issue = try row("Issue/i", parent:p.rowID)
    let task = try row("Task/t", parent:issue.rowID, updated:"2026-10-28T12:00:00.123Z")
    let model = WorkDashboard(records:[p,other,issue,task])
    XCTAssertEqual(model.projects().map(\.rowID),[p.rowID,other.rowID])
    XCTAssertEqual(model.latestDate(for:p),model.date(for:task))
    XCTAssertEqual(model.latestDate(for:issue),model.date(for:task))
  }
  func testArenaScopePropagatesThroughInitiativeAndDoesNotScopeTodo() throws {
    let arena = try JSONDecoder().decode(ArenaRecord.self,from:Data("{\"kind\":\"Arena\",\"id\":\"a\",\"title\":\"A\",\"description\":\"\",\"version\":1,\"archived\":false}".utf8))
    let i = try row("Initiative/i"), p = try row("Project/p",parent:"Initiative/i")
    let outside = try row("Task/outside",priority:90)
    let model=WorkDashboard(records:[i,p,outside],arenas:[arena],members:["a":[i.rowID]])
    XCTAssertEqual(model.projects(in:.arena("a")).map(\.rowID),[p.rowID])
    XCTAssertEqual(model.projects(in:.initiative(i.rowID)).map(\.rowID),[p.rowID])
    XCTAssertEqual(model.todos.map(\.rowID),[outside.rowID])
  }
  func testMissingMembershipDoesNotInventAnArena() throws {
    let p=try row("Project/p")
    XCTAssertTrue(WorkDashboard(records:[p]).arenas(for:p).isEmpty)
  }
  func testIssueTasksDoNotLeakAcrossSiblingIssues() throws {
    let a=try row("Issue/a"),b=try row("Issue/b")
    let t=try row("Task/t",parent:b.rowID)
    let model=WorkDashboard(records:[a,b,t])
    XCTAssertTrue(model.tasks(in:a).isEmpty)
    XCTAssertEqual(model.tasks(in:b).map(\.rowID),[t.rowID])
  }
  func testTodoUsesRecordedProgressAndPriority() throws {
    let done=try row("Task/done",progress:"done",priority:100)
    let low=try row("Task/low",priority:2),high=try row("Task/high",priority:9)
    XCTAssertEqual(WorkDashboard(records:[low,done,high]).todos.map(\.rowID),[high.rowID,low.rowID])
  }
  func testCyclesAndMissingParentsTerminateWithoutInventingContainment() throws {
    let a=try row("Issue/a",parent:"Issue/b"),b=try row("Issue/b",parent:"Issue/a")
    let missing=try row("Task/missing",parent:"Issue/outside")
    let model=WorkDashboard(records:[a,b,missing])
    XCTAssertFalse(model.contains(a,within:"Project/nonexistent"))
    XCTAssertNil(model.ancestor(of:missing,kind:"Project"))
  }
  func testMalformedHierarchyIsRejectedAndInvalidDateIsNotFresh() throws {
    XCTAssertThrowsError(try row("Project/p",parent:"../../secret"))
    let p=try row("Project/p",updated:"not-a-date")
    XCTAssertNil(WorkDashboard(records:[p]).latestDate(for:p))
  }
}
