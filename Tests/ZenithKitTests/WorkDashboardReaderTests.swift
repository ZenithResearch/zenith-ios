import XCTest
@testable import ZenithKit

private func dashboardRow(_ key: String, updated: String? = nil) throws -> WorkRecord {
  let parts = key.split(separator: "/")
  var row: [String: Any] = ["kind": String(parts[0]), "id": String(parts[1]), "title": String(parts[1]),
    "version": "1", "priority": "0", "progress": "not_started"]
  if let updated { row["updated_at"] = updated }
  // Faithful scoped list/relationship summaries: no parent field.
  return try JSONDecoder().decode(WorkRecord.self, from: JSONSerialization.data(withJSONObject: row))
}
private actor DashboardSourceFixture: WorkDashboardSource {
  let access: NativeReadManifest
  let rows: [WorkRecord]
  let area: ArenaRecord
  let relation: String?
  let fail: Bool
  let unparented: Bool
  var calls: [String] = []
  init(relation: String? = "children", arenaList: Bool = true, fail: Bool = false, unparented: Bool = false) throws {
    self.relation = relation; self.fail = fail; self.unparented = unparented
    let kinds = ["Todo", "Proposal", "Initiative", "Project", "Issue", "Task"]
    var grants: [[String: Any]] = [["scope": "devgraph.work.read", "operations": ["list", "get"],
      "work_kinds": kinds, "relationship_types": ["parent", "children"], "include_archived": false]]
    if let relation {
      // Separate per-operation grants reproduce the native holder profile that
      // cannot carry relationship edges inside a list projection.
      grants.append(["scope": "devgraph.work.read", "operations": ["relationships"],
        "work_kinds": kinds, "relationship_types": [relation], "include_archived": false])
    }
    grants.append(["scope": "devgraph.arena.read", "operations": arenaList ? ["list", "get"] : ["get"], "arena_ids": ["research"]])
    let manifest: [String: Any] = ["readProtocol": WorkReadProtocol.arenaV5.rawValue, "schema": "fixture", "credential_id": "fixture",
      "subject_public_key": "fixture", "installation_id": "fixture", "issuer": "fixture", "receiver": "fixture",
      "policy_digest": "fixture", "audience": "devgraph", "resource": "fixture", "issued_at": 1, "expires_at": 2, "read_grants": grants]
    access = try JSONDecoder().decode(NativeReadManifest.self, from: JSONSerialization.data(withJSONObject: manifest))
    rows = try (0..<21).map { try dashboardRow("Project/p\($0)") } + [
      dashboardRow("Initiative/root"), dashboardRow("Issue/issue"),
      dashboardRow("Task/task", updated: "2026-10-29T12:00:00Z"), dashboardRow("Todo/todo"), dashboardRow("Proposal/proposal")]
    area = try JSONDecoder().decode(ArenaRecord.self, from: Data(#"{"kind":"Arena","id":"research","title":"Research","description":"","version":1,"archived":false}"#.utf8))
  }
  func manifest() async throws -> NativeReadManifest { access }
  func page(kind: String, after: WorkPageCursor?) async throws -> WorkPage {
    calls.append("list/" + kind)
    if fail { throw WalletFailure.core("access_denied") }
    let matching = rows.filter { $0.kind == kind }.sorted { $0.rowID < $1.rowID }
    let start = after.flatMap { cursor in matching.firstIndex { $0.rowID == cursor.after }.map { $0 + 1 } } ?? 0
    let page = Array(matching.dropFirst(start).prefix(20))
    return WorkPage(items: page, next: start + page.count < matching.count
      ? WorkPageCursor(after: page.last!.rowID, revision: String(repeating: "a", count: 64)) : nil)
  }
  func arenas(after: String?) async throws -> ArenaPage {
    calls.append("arena.list"); return ArenaPage(items: [area], next: nil)
  }
  func arena(id: String) async throws -> ArenaRecord { calls.append("arena.get/" + id); return area }
  func arenaMembers(id: String, after: WorkPageCursor?) async throws -> WorkPage {
    calls.append("arena.members/" + id)
    return WorkPage(items: rows.filter { $0.kind == "Initiative" }, next: nil)
  }
  func related(kind: String, id: String, relationship: String, after: WorkPageCursor?) async throws -> WorkPage {
    calls.append(relationship + "/" + kind + "/" + id)
    guard relationship == relation else { throw WalletFailure.core("unsupported_read_scope") }
    let parents: [String: String] = unparented ? [:] : Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (String, String)? in
      switch row.kind {
      case "Project": return (row.rowID, "Initiative/root")
      case "Issue": return (row.rowID, "Project/p0")
      case "Task": return (row.rowID, "Issue/issue")
      default: return nil
      }
    })
    let anchor = kind + "/" + id
    let matching = rows.filter { relationship == "children" ? parents[$0.rowID] == anchor : $0.rowID == parents[anchor] }
      .sorted { $0.rowID < $1.rowID }
    let start = after.flatMap { cursor in matching.firstIndex { $0.rowID == cursor.after }.map { $0 + 1 } } ?? 0
    let page = Array(matching.dropFirst(start).prefix(20))
    return WorkPage(items: page, next: start + page.count < matching.count
      ? WorkPageCursor(after: page.last!.rowID, revision: nil) : nil)
  }
}

final class WorkDashboardReaderTests: XCTestCase {
  func testAllKindsAndPagesLoadAndSeparateRelationshipReadsRestoreScope() async throws {
    let source = try DashboardSourceFixture()
    let result = try await WorkDashboardReader().load(from: source)
    XCTAssertTrue(result.complete); XCTAssertFalse(result.canContinue)
    XCTAssertEqual(Set(result.records.map(\.kind)), ["Todo", "Proposal", "Initiative", "Project", "Issue", "Task"])
    XCTAssertEqual(result.records.count, 26)
    XCTAssertEqual(result.dashboard.projects(in: .arena("research")).count, 21)
    XCTAssertEqual(result.dashboard.projects(in: .initiative("Initiative/root")).count, 21)
    let task = try XCTUnwrap(result.records.first { $0.kind == "Task" })
    XCTAssertEqual(result.dashboard.context(for: task), "Research · p0")
    XCTAssertEqual(result.dashboard.projects().first?.rowID, "Project/p0")
    let calls = await source.calls
    XCTAssertEqual(calls.filter { $0 == "list/Project" }.count, 2)
    XCTAssertEqual(calls.filter { $0 == "children/Initiative/root" }.count, 2)
    XCTAssertFalse(calls.contains { $0.hasPrefix("parent/") })
  }
  func testExplicitArenaGetWorksWithoutBorrowingListPermission() async throws {
    let source = try DashboardSourceFixture(arenaList: false)
    let result = try await WorkDashboardReader().load(from: source)
    XCTAssertEqual(result.dashboard.projects(in: .arena("research")).count, 21)
    let calls = await source.calls
    XCTAssertFalse(calls.contains("arena.list")); XCTAssertTrue(calls.contains("arena.get/research"))
  }
  func testListOnlyDoesNotInventHierarchyOrRequestMoreAuthority() async throws {
    let source = try DashboardSourceFixture(relation: nil)
    let result = try await WorkDashboardReader().load(from: source)
    XCTAssertEqual(result.records.count, 26); XCTAssertTrue(result.parents.isEmpty)
    XCTAssertTrue(result.dashboard.projects(in: .arena("research")).isEmpty)
    XCTAssertTrue(result.notes.contains { $0.contains("parent/child") })
    let calls = await source.calls
    XCTAssertFalse(calls.contains { $0.hasPrefix("parent/") || $0.hasPrefix("children/") })
  }
  func testParentOnlyGrantWorksWithoutChildrenCalls() async throws {
    let source = try DashboardSourceFixture(relation: "parent")
    let result = try await WorkDashboardReader().load(from: source)
    XCTAssertEqual(result.dashboard.projects(in: .arena("research")).count, 21)
    XCTAssertEqual(result.parents["Task/task"], "Issue/issue")
    let calls = await source.calls
    XCTAssertFalse(calls.contains { $0.hasPrefix("children/") })
  }
  func testUnparentedWorkDoesNotInventMembershipOrReportMissingPermission() async throws {
    let source = try DashboardSourceFixture(unparented: true)
    let result = try await WorkDashboardReader().load(from: source)
    XCTAssertTrue(result.complete); XCTAssertTrue(result.parents.isEmpty)
    XCTAssertTrue(result.dashboard.projects(in: .arena("research")).isEmpty)
    XCTAssertFalse(result.notes.contains { $0.contains("parent/child") })
  }
  func testBudgetKeepsPartialDataAndAllowsExplicitContinuation() async throws {
    let source = try DashboardSourceFixture()
    let partial = try await WorkDashboardReader().load(from: source, requestLimit: 1)
    XCTAssertFalse(partial.complete); XCTAssertTrue(partial.canContinue)
    XCTAssertFalse(partial.records.isEmpty)
    let full = try await WorkDashboardReader().load(from: source, requestLimit: 100)
    XCTAssertTrue(full.complete); XCTAssertFalse(full.canContinue)
    XCTAssertEqual(full.records.count, 26)
  }
  func testDeniedReadStopsRatherThanFallingBackToAnotherScope() async throws {
    let source = try DashboardSourceFixture(fail: true)
    do {
      _ = try await WorkDashboardReader().load(from: source)
      XCTFail("Denied reads must propagate")
    } catch { XCTAssertTrue(error is WalletFailure) }
    let calls = await source.calls
    XCTAssertEqual(calls.count, 1)
  }
}
