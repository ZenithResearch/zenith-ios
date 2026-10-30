import Foundation

/// A read-only projection of the user's permitted, loaded Work. No parallel tracker.
public struct WorkDashboard: Sendable {
  public enum Scope: Hashable, Sendable { case all, arena(String), initiative(String) }
  public let records: [WorkRecord]
  public let arenas: [ArenaRecord]
  public let members: [String: Set<String>]
  public let complete: Bool
  public let arenaMembershipComplete: Bool
  /// Parent/child reads witness these edges independently of list summaries.
  public let parents: [String: String]
  private let index: [String: WorkRecord]
  private let dates: [String: Date]
  private let latestDates: [String: Date]

  public init(records: [WorkRecord], arenas: [ArenaRecord] = [],
              members: [String: Set<String>] = [:], complete: Bool = false,
              arenaMembershipComplete: Bool = false, parents: [String: String] = [:]) {
    self.records = records; self.arenas = arenas; self.members = members
    self.complete = complete; self.arenaMembershipComplete = arenaMembershipComplete
    self.parents = parents
    let lookup = Dictionary(records.map { ($0.rowID, $0) }, uniquingKeysWith: { first, _ in first })
    index = lookup
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    var own: [String: Date] = [:], latest: [String: Date] = [:]
    for row in lookup.values {
      guard let text = row.updated_at, let date = formatter.date(from: text) ?? plain.date(from: text) else { continue }
      own[row.rowID] = date
      var current: WorkRecord? = row, seen = Set<String>()
      while let next = current, seen.insert(next.rowID).inserted {
        latest[next.rowID] = max(latest[next.rowID] ?? .distantPast, date)
        current = (parents[next.rowID] ?? next.parent).flatMap { lookup[$0] }
      }
    }
    dates = own; latestDates = latest
  }

  public func record(_ key: String) -> WorkRecord? { index[key] }
  public func parent(of row: WorkRecord) -> String? { parents[row.rowID] ?? row.parent }
  public func contains(_ row: WorkRecord, within key: String) -> Bool {
    var current: WorkRecord? = row, seen = Set<String>()
    while let next = current, seen.insert(next.rowID).inserted {
      if next.rowID == key { return true }
      current = parent(of: next).flatMap { index[$0] }
    }
    return false
  }
  public func ancestor(of row: WorkRecord, kind: String) -> WorkRecord? {
    var current: WorkRecord? = row, seen = Set<String>()
    while let next = current, seen.insert(next.rowID).inserted {
      if next.kind == kind { return next }
      current = parent(of: next).flatMap { index[$0] }
    }
    return nil
  }
  public func arenas(for row: WorkRecord) -> [ArenaRecord] {
    arenas.filter { arena in
      (members[arena.id] ?? []).contains { contains(row, within: $0) }
    }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }
  public func context(for row: WorkRecord) -> String {
    let area = arenas(for: row).map(\.title).joined(separator: ", ")
    let project = ancestor(of: row, kind: "Project")
    return [area.isEmpty ? nil : area, project?.rowID != row.rowID ? project?.title : nil]
      .compactMap { $0 }.joined(separator: " · ")
  }
  public func date(for row: WorkRecord) -> Date? { dates[row.rowID] }
  public func latestDate(for row: WorkRecord) -> Date? { latestDates[row.rowID] }
  public func recent(_ rows: [WorkRecord]) -> [WorkRecord] {
    let dates = Dictionary(rows.map { ($0.rowID, latestDate(for: $0) ?? .distantPast) },
                           uniquingKeysWith: { first, _ in first })
    return rows.sorted {
      if dates[$0.rowID] != dates[$1.rowID] { return dates[$0.rowID]! > dates[$1.rowID]! }
      let title = $0.title.localizedStandardCompare($1.title)
      return title == .orderedSame ? $0.rowID < $1.rowID : title == .orderedAscending
    }
  }
  public func projects(in scope: Scope = .all) -> [WorkRecord] {
    recent(records.filter { row in
      guard row.kind == "Project" else { return false }
      switch scope {
      case .all: return true
      case .arena(let id): return arenas(for: row).contains { $0.id == id }
      case .initiative(let key): return contains(row, within: key)
      }
    })
  }
  public var initiatives: [WorkRecord] { recent(records.filter { $0.kind == "Initiative" }) }
  public var orderedArenas: [ArenaRecord] {
    let dates = Dictionary(uniqueKeysWithValues: arenas.map { arena in
      (arena.id, records.filter { row in (members[arena.id] ?? []).contains { contains(row, within: $0) } }
        .compactMap { date(for: $0) }.max() ?? .distantPast)
    })
    return arenas.sorted {
      if dates[$0.id] != dates[$1.id] { return dates[$0.id]! > dates[$1.id]! }
      return $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
  }
  public func tasks(in row: WorkRecord) -> [WorkRecord] {
    recent(records.filter { $0.kind == "Task" && contains($0, within: row.rowID) })
  }
  public func issues(in project: String? = nil) -> [WorkRecord] {
    recent(records.filter { $0.kind == "Issue" && (project == nil || contains($0, within: project!)) })
  }
  public var todos: [WorkRecord] {
    records.filter { $0.kind == "Task" && $0.progress == "not_started" }.sorted {
      if $0.priority != $1.priority { return $0.priority > $1.priority }
      return $0.rowID < $1.rowID
    }
  }
}
