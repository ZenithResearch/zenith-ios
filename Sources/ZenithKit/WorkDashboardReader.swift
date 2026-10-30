import Foundation

/// All calls retain the existing native credential and receiver-side scope checks.
public protocol WorkDashboardSource: Sendable {
  func manifest() async throws -> NativeReadManifest
  func page(kind: String, after: WorkPageCursor?) async throws -> WorkPage
  func arenas(after: String?) async throws -> ArenaPage
  func arena(id: String) async throws -> ArenaRecord
  func arenaMembers(id: String, after: WorkPageCursor?) async throws -> WorkPage
  func related(kind: String, id: String, relationship: String, after: WorkPageCursor?) async throws -> WorkPage
}
extension DevgraphReadClient: WorkDashboardSource {}

public struct WorkDashboardReadResult: Sendable {
  public var records: [WorkRecord] = []
  public var arenas: [ArenaRecord] = []
  public var members: [String: Set<String>] = [:]
  public var parents: [String: String] = [:]
  public var detailKinds: Set<String> = []
  public var listKinds: Set<String> = []
  public var loadedKinds: Set<String> = []
  public var cursors: [String: WorkPageCursor] = [:]
  public var complete = false
  public var arenaMembershipComplete = false
  public var canContinue = false
  public var notes: [String] = []
  public init() {}
  public var dashboard: WorkDashboard {
    WorkDashboard(records: records, arenas: arenas, members: members,
      complete: complete, arenaMembershipComplete: arenaMembershipComplete, parents: parents, loadedKinds: loadedKinds)
  }
}

/// Overview only: Arena roots, Initiatives and Projects. Deeper lists are paged
/// explicitly when requested; summaries may intentionally omit parent edges.
public struct WorkDashboardReader: Sendable {
  public init() {}
  public func load(
    from source: any WorkDashboardSource, requestLimit: Int = 1000,
    progress: (@MainActor @Sendable (WorkDashboardReadResult) -> Void)? = nil
  ) async throws -> WorkDashboardReadResult {
    try Task.checkCancellation()
    let manifest = try await source.manifest()
    let grants = manifest.read_grants
    var result = WorkDashboardReadResult()
    var work: [String: WorkRecord] = [:]
    var remaining = max(1, min(requestLimit, 10000))
    func snapshot() -> WorkDashboardReadResult {
      var copy = result
      copy.records = work.values.sorted { $0.rowID < $1.rowID }
      return copy
    }
    func publish() async { await progress?(snapshot()) }
    func takeRequest() throws -> Bool {
      try Task.checkCancellation()
      guard remaining > 0 else { return false }
      remaining -= 1
      return true
    }
    func limited() -> WorkDashboardReadResult {
      var copy = snapshot(); copy.canContinue = requestLimit < 10000
      copy.notes.append(copy.canContinue ? "More shared work or context remains. Continue loading to finish."
        : "Shared work exceeds the loading limit. Use a narrower connection to finish loading context.")
      return copy
    }
    func merge(_ rows: [WorkRecord]) {
      // Relationship summaries must not replace richer existing list metadata.
      for row in rows where work[row.rowID] == nil { work[row.rowID] = row }
    }
    func witness(child: String, parent: String) throws {
      guard child != parent, result.parents[child].map({ $0 == parent }) ?? true else {
        throw WalletFailure.core("invalid_response")
      }
      result.parents[child] = parent
    }
    func permits(_ row: WorkRecord, _ relationship: String) -> Bool {
      manifest.readProtocol != .nativeV2 && grants.contains {
        !$0.isArena && $0.work_kinds.contains(row.kind) && $0.operations.contains("relationships")
          && $0.relationship_types.contains(relationship)
      }
    }
    result.detailKinds = Set(grants.filter { !$0.isArena && $0.operations.contains("get") }.flatMap(\.work_kinds))
    let kinds = Set(grants.filter { !$0.isArena && $0.operations.contains("list") }.flatMap(\.work_kinds)).sorted()
    result.listKinds = Set(kinds)
    if kinds.isEmpty { result.notes.append("This connection does not share Work lists. Open Connection to check access.") }
    let arenaGrants = grants.filter(\.isArena)
    var arenaIndex: [String: ArenaRecord] = [:]
    if arenaGrants.contains(where: { $0.operations.contains("list") }) {
      var after: String?
      repeat {
        guard try takeRequest() else { return limited() }
        let page = try await source.arenas(after: after)
        for row in page.items where !row.archived { arenaIndex[row.id] = row }
        after = page.next
      } while after != nil
    }
    // An explicit Arena get grant does not require collection-list authority.
    let knownIDs = Set(arenaGrants.filter { $0.operations.contains("get") }.flatMap { $0.arena_ids ?? [] })
    for id in knownIDs.sorted() where arenaIndex[id] == nil {
      guard try takeRequest() else { return limited() }
      let row = try await source.arena(id: id)
      if !row.archived { arenaIndex[id] = row }
    }
    result.arenas = arenaIndex.values.sorted { $0.id < $1.id }
    await publish()
    for kind in ["Initiative"] where kinds.contains(kind) {
      var after: WorkPageCursor?
      repeat {
        guard try takeRequest() else { return limited() }
        let page = try await source.page(kind: kind, after: after)
        merge(page.items)
        after = page.next
        await publish()
      } while after != nil
      result.loadedKinds.insert(kind)
      await publish()
    }

    var membershipComplete = true
    for arena in result.arenas {
      guard !kinds.isEmpty, arenaGrants.contains(where: {
        $0.operations.contains("get") && ($0.all_arenas == true || ($0.arena_ids ?? []).contains(arena.id))
      }) else { membershipComplete = false; continue }
      var after: WorkPageCursor?
      repeat {
        guard try takeRequest() else { return limited() }
        let page = try await source.arenaMembers(id: arena.id, after: after)
        result.members[arena.id, default: []].formUnion(page.items.map(\.rowID))
        merge(page.items); after = page.next
        await publish()
      } while after != nil
    }
    result.arenaMembershipComplete = membershipComplete
    await publish()

    for kind in ["Project"] where kinds.contains(kind) {
      var after: WorkPageCursor?
      repeat {
        guard try takeRequest() else { return limited() }
        let page = try await source.page(kind: kind, after: after)
        merge(page.items)
        after = page.next
        await publish()
      } while after != nil
      result.loadedKinds.insert(kind)
      await publish()
    }

    // Top-down reads avoid one request per Task. Each edge comes from a granted
    // children response; no ancestor is guessed from names or Arena membership.
    for kind in ["Initiative"] {
      let anchors = work.values.filter { $0.kind == kind && permits($0, "children") }.sorted { $0.rowID < $1.rowID }
      for anchor in anchors {
        var after: WorkPageCursor?
        repeat {
          guard try takeRequest() else { return limited() }
          let page = try await source.related(kind: anchor.kind, id: anchor.id, relationship: "children", after: after)
          for child in page.items { try witness(child: child.rowID, parent: anchor.rowID) }
          merge(page.items); after = page.next
        } while after != nil
        await publish()
      }
      await publish()
    }
    // Parent-only profiles are supported without borrowing children permission.
    let unresolved = work.values.filter {
      $0.kind == "Project" && result.parents[$0.rowID] == nil
        && $0.parent == nil && permits($0, "parent")
    }.sorted { $0.rowID < $1.rowID }
    for row in unresolved {
      guard try takeRequest() else { return limited() }
      let page = try await source.related(kind: row.kind, id: row.id, relationship: "parent", after: nil)
      guard page.next == nil, page.items.count <= 1 else { throw WalletFailure.core("invalid_response") }
      if let parent = page.items.first { try witness(child: row.rowID, parent: parent.rowID) }
      merge(page.items)
    }
    let sharesHierarchy = grants.contains {
      !$0.isArena && $0.operations.contains("relationships") && !$0.work_kinds.isEmpty
        && !$0.relationship_types.filter({ ["parent", "children"].contains($0) }).isEmpty
    }
    if !sharesHierarchy && result.parents.isEmpty && work.values.contains(where: { $0.kind == "Project" && $0.parent == nil }) {
      result.notes.append("Work is loaded. Arena and Initiative grouping needs shared parent/child relationships.")
    }
    result.complete = true
    let value = snapshot()
    await progress?(value)
    return value
  }

  /// Fetch one requested list page. No recursive child crawl or unrelated kinds.
  public func loadPage(kind: String, from source: any WorkDashboardSource,
                       into previous: WorkDashboardReadResult) async throws -> WorkDashboardReadResult {
    try Task.checkCancellation()
    if previous.loadedKinds.contains(kind), previous.cursors[kind] == nil { return previous }
    let manifest = try await source.manifest()
    guard manifest.read_grants.contains(where: {
      !$0.isArena && $0.operations.contains("list") && $0.work_kinds.contains(kind)
    }) else { throw WalletFailure.core("unsupported_read_scope") }
    let page = try await source.page(kind: kind, after: previous.cursors[kind])
    var result = previous
    var work = Dictionary(previous.records.map { ($0.rowID, $0) }, uniquingKeysWith: { first, _ in first })
    for row in page.items {
      work[row.rowID] = row
      // Only this page's immediate parent, to support project filtering. Tasks'
      // deeper ancestry is discovered by opening their existing relationship view.
      if row.parent == nil, result.parents[row.rowID] == nil,
         manifest.readProtocol != .nativeV2,
         manifest.read_grants.contains(where: {
           !$0.isArena && $0.work_kinds.contains(row.kind) && $0.operations.contains("relationships")
             && $0.relationship_types.contains("parent")
         }) {
        let parent = try await source.related(kind: row.kind, id: row.id, relationship: "parent", after: nil)
        guard parent.next == nil, parent.items.count <= 1 else { throw WalletFailure.core("invalid_response") }
        if let anchor = parent.items.first {
          guard anchor.rowID != row.rowID else { throw WalletFailure.core("invalid_response") }
          result.parents[row.rowID] = anchor.rowID
          if work[anchor.rowID] == nil { work[anchor.rowID] = anchor }
        }
      }
    }
    try Task.checkCancellation()
    result.records = work.values.sorted { $0.rowID < $1.rowID }
    result.loadedKinds.insert(kind)
    result.cursors[kind] = page.next
    return result
  }

}
