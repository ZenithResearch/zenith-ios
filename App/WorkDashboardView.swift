import SwiftUI
import ZenithKit

/// Native presentation shared by the authenticated Work page and isolated UI review.
struct WorkDashboardView: View {
  enum Panel: String, Hashable { case pulse = "Project Pulse", activity = "Activity", todo = "Todo", all = "All shared work" }
  let snapshot: WorkDashboard
  let loading: Bool
  let message: String?
  let loadMore: (() -> Void)?
  let destination: (WorkRecord) -> AnyView
  let arenaDestination: (ArenaRecord) -> AnyView
  @Binding var captureText: String
  @Binding var captures: [String]
  @Binding var captureRequested: Bool
  @FocusState private var noteFocused: Bool
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.horizontalSizeClass) private var sizeClass
  private var previewCount: Int { sizeClass == .regular && !typeSize.isAccessibilitySize ? 2 : 1 }
  @State private var context = 0
  @State private var scope = WorkDashboard.Scope.all
  @State private var activityProject: String?
  @State private var sessions = false

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { scroll in
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text(snapshot.complete ? "Shared work" : "Loaded work")
                .font(.subheadline).foregroundStyle(.secondary)
              Spacer()
              if loading { ProgressView().accessibilityLabel("Loading work") }
              else { Text("\(snapshot.records.count) items").font(.caption).foregroundStyle(.secondary) }
            }
            if geometry.size.width < 760 || typeSize.isAccessibilitySize {
              HStack(spacing: 0) {
                ForEach([Panel.pulse, .activity, .todo], id: \.self) { panel in
                  Button(panel.rawValue) { withAnimation { scroll.scrollTo(panel, anchor: .top) } }
                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                }
              }.background(.background, in: RoundedRectangle(cornerRadius: 12))
            }

            if let message {
              Text(message).font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if geometry.size.width >= 760 && !typeSize.isAccessibilitySize {
              WorkDashboardPair { pulse; activity }
              WorkDashboardPair { notepad; todo }
            } else {
              pulse
              activity
              todo
              notepad
            }
            NavigationLink(value: Panel.all) { Text("Browse all shared work").font(.subheadline) }
              .frame(maxWidth: .infinity, minHeight: 44)
            if let loadMore {
              Button("Load more shared work", action: loadMore)
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                .disabled(loading)
            }
          }.padding(16).frame(maxWidth: 1280).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground))
          .scrollDismissesKeyboard(.interactively)
          .onChange(of: captureRequested) { _, requested in
            guard requested else { return }
            withAnimation { scroll.scrollTo("work-notepad", anchor: .bottom) }
            noteFocused = true
            captureRequested = false
          }
          .navigationDestination(for: Panel.self) { panel in
            WorkDashboardExpanded(panel: panel, snapshot: snapshot, scope: scope,
              project: activityProject, destination: destination)
          }
      }
    }
  }

  private func heading(_ panel: Panel, count: Int?, showsAll: Bool = true) -> some View {
    HStack {
      Text(panel.rawValue).font(.headline).accessibilityAddTraits(.isHeader)
      if let count {
        Text(count, format: .number).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          .accessibilityLabel(workDashboardCount(count, "loaded item"))
      }
      Spacer()
      if showsAll {
        NavigationLink(value: panel) { Text("See all").font(.subheadline) }
          .accessibilityLabel("See all \(panel.rawValue)")
          .frame(minHeight: 44)
      }
    }
  }
  private var pulse: some View {
    WorkDashboardCard {
      heading(.pulse, count: snapshot.projects(in: scope).count)
      Picker("Context", selection: $context) {
        Text("Arenas").tag(0); Text("Initiatives").tag(1)
      }.pickerStyle(.segmented).onChange(of: context) { _, _ in scope = .all }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          contextChip("All work", subtitle: workDashboardCount(snapshot.projects().count, "project"), selected: scope == .all) { scope = .all }
          if context == 0 {
            ForEach(snapshot.orderedArenas) { arena in
              let projects = snapshot.projects(in: .arena(arena.id))
              contextChip(arena.title, subtitle: workDashboardCount(projects.count, "project"), selected: scope == .arena(arena.id)) {
                scope = scope == .arena(arena.id) ? .all : .arena(arena.id)
              }.contextMenu { NavigationLink("Arena details") { arenaDestination(arena) } }
            }
          } else {
            ForEach(snapshot.initiatives, id: \.rowID) { initiative in
              contextChip(initiative.title, subtitle: workDashboardCount(snapshot.projects(in: .initiative(initiative.rowID)).count, "project"),
                          selected: scope == .initiative(initiative.rowID)) {
                scope = scope == .initiative(initiative.rowID) ? .all : .initiative(initiative.rowID)
              }
            }
          }
        }.padding(.vertical, 4)
      }
      if context == 0 && snapshot.arenas.isEmpty {
        Text("Arena context is not shared by this connection.").font(.caption).foregroundStyle(.secondary)
      } else if context == 0 && !snapshot.arenaMembershipComplete {
        Text("Arena membership is partially loaded.").font(.caption).foregroundStyle(.secondary)
      }
      let projects = snapshot.projects(in: scope)
      ForEach(Array(projects.prefix(previewCount)), id: \.rowID) { row in
        Divider()
        NavigationLink { destination(row) } label: {
          WorkDashboardProjectRow(row: row, snapshot: snapshot)
        }.buttonStyle(.plain)
      }
      if projects.isEmpty { empty("No projects in this loaded context.") }
      Spacer(minLength: 0)
      Text("Recent record changes · \(projects.count) loaded projects")
        .font(.caption2).foregroundStyle(.secondary)
    }.id(Panel.pulse)
  }
  private var activity: some View {
    WorkDashboardCard {
      heading(.activity, count: sessions ? nil : snapshot.issues(in: activityProject).count, showsAll: !sessions)
      Picker("Activity view", selection: $sessions) {
        Text("Issues").tag(false); Text("Sessions").tag(true)
      }.pickerStyle(.segmented)
      if sessions {
        VStack(alignment: .leading, spacing: 6) {
          Text("Sessions need native read access").font(.subheadline.weight(.medium))
          Text("This connection shares Work, but has no session-ref read route. Your source sessions are unchanged.")
            .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            filterChip("All projects", subtitle: workDashboardCount(snapshot.issues().count, "issue"), selected: activityProject == nil) { activityProject = nil }
            ForEach(snapshot.projects().filter { !snapshot.issues(in: $0.rowID).isEmpty }, id: \.rowID) { project in
              filterChip(project.title, subtitle: workDashboardCount(snapshot.issues(in: project.rowID).count, "issue"), selected: activityProject == project.rowID) {
                activityProject = activityProject == project.rowID ? nil : project.rowID
              }
            }
          }.padding(.vertical, 4)
        }
        let issues = snapshot.issues(in: activityProject)
        ForEach(Array(issues.prefix(previewCount)), id: \.rowID) { row in
          Divider()
          NavigationLink { destination(row) } label: {
            WorkDashboardIssueRow(row: row, snapshot: snapshot)
          }.buttonStyle(.plain)
        }
        if issues.isEmpty { empty("No issues in this loaded context.") }
        Spacer(minLength: 0)
        Text("Record activity · session activity unavailable")
          .font(.caption2).foregroundStyle(.secondary)
      }
    }.id(Panel.activity)
  }
  private var todo: some View {
    WorkDashboardCard {
      heading(.todo, count: snapshot.todos.count)
      ForEach(Array(snapshot.todos.prefix(previewCount)), id: \.rowID) { row in
        Divider()
        NavigationLink { destination(row) } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(row.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
            Text(snapshot.context(for: row)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.buttonStyle(.plain)
      }
      if snapshot.todos.isEmpty { empty("No not-started tasks loaded.") }
      Spacer(minLength: 0)
      Text("\(snapshot.todos.count) not started · priority order")
        .font(.caption2).foregroundStyle(.secondary)
    }.id(Panel.todo)
  }
  private func contextChip(_ title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }.frame(width: 140, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
        .background(selected ? Color.accentColor.opacity(0.12) : Color(uiColor: .tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : .clear))
    }.buttonStyle(.plain).accessibilityLabel(title + ", " + subtitle)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func filterChip(_ title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
    contextChip(title, subtitle: subtitle, selected: selected, action: action)
  }
  private var notepad: some View {
    WorkDashboardCard {
      HStack {
        Text("Notepad").font(.headline).accessibilityAddTraits(.isHeader)
        Spacer()
        Button("Save note") {
          let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !text.isEmpty else { return }
          captures.insert(text, at: 0)
          captureText = ""
          noteFocused = false
        }.font(.subheadline).frame(minHeight: 44)
          .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      TextField("Capture a thought…", text: $captureText, axis: .vertical)
        .font(.body).lineLimit(4...8).focused($noteFocused)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Capture a note")
        .accessibilityIdentifier("work.notepad.input")
      if !captures.isEmpty {
        DisclosureGroup("Saved notes (\(captures.count))") {
          ForEach(Array(captures.enumerated()), id: \.offset) { _, text in
            Text(text).font(.subheadline).textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
          }
        }.font(.subheadline)
      }
      Spacer(minLength: 0)
      Text("Page memory only · no task created").font(.caption2).foregroundStyle(.secondary)
    }.id("work-notepad")
  }
  private func empty(_ text: String) -> some View {
    Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
  }
}

/// Two columns share a row height. A 0.618 primary track yields to a readable sidebar.
private struct WorkDashboardPair: Layout {
  private let gap: CGFloat = 16
  private func tracks(_ width: CGFloat) -> (CGFloat, CGFloat) {
    let available = max(0, width - gap)
    let secondary = min(available / 2, max(300, available * 0.382))
    return (available - secondary, secondary)
  }
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 1000
    let (primary, secondary) = tracks(width)
    let height = zip(subviews, [primary, secondary]).map {
      $0.0.sizeThatFits(ProposedViewSize(width: $0.1, height: nil)).height
    }.max() ?? 0
    return CGSize(width: width, height: height)
  }
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let (primary, secondary) = tracks(bounds.width)
    for (index, view) in subviews.enumerated() {
      view.place(at: CGPoint(x: bounds.minX + (index == 0 ? 0 : primary + gap), y: bounds.minY),
                 anchor: .topLeading,
                 proposal: ProposedViewSize(width: index == 0 ? primary : secondary, height: bounds.height))
    }
  }
}

private struct WorkDashboardCard<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 12, content: content).padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(uiColor: .separator).opacity(0.18)))
  }
}

private struct WorkDashboardProjectRow: View {
  let row: WorkRecord
  let snapshot: WorkDashboard
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    let tasks = snapshot.tasks(in: row)
    VStack(alignment: .leading, spacing: 7) {
      let titleLayout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
      titleLayout {
        Text(row.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
        if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
        if let date = snapshot.latestDate(for: row) {
          Text(date, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.secondary)
        }
      }
      let statusLayout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        : AnyLayout(HStackLayout(spacing: 8))
      statusLayout {
        WorkDashboardStatus(row: row)
        Text("Unestimated").foregroundStyle(.secondary)
      }.font(.caption)
      let context = snapshot.context(for: row)
      if !context.isEmpty {
        Text(context).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      let active = tasks.filter { $0.progress == "in_progress" }
      let done = tasks.filter { $0.progress == "done" }
      if let task = active.first {
        WorkDashboardTaskPreview(label: "Doing", task: task)
      }
      if let task = done.first {
        WorkDashboardTaskPreview(label: "Done", task: task)
      }
      Text(workDashboardCount(snapshot.issues(in: row.rowID).count, "issue") + (snapshot.complete ? "" : " loaded"))
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity, minHeight: 70, alignment: .leading).padding(.vertical, 4)
      .accessibilityElement(children: .combine)
  }
}

private struct WorkDashboardIssueRow: View {
  let row: WorkRecord
  let snapshot: WorkDashboard
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(row.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
      Text(snapshot.context(for: row)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      HStack {
        WorkDashboardStatus(row: row)
        Spacer()
        if let date = snapshot.latestDate(for: row) { Text(date, format: .dateTime.month(.abbreviated).day()) }
      }.font(.caption).foregroundStyle(.secondary)
      if let task = snapshot.tasks(in: row).first {
        WorkDashboardTaskPreview(label: task.progressLabel, task: task)
      }
    }.frame(maxWidth: .infinity, minHeight: 66, alignment: .leading).padding(.vertical, 4)
      .accessibilityElement(children: .combine)
  }
}

private func workDashboardCount(_ count: Int, _ noun: String) -> String {
  "\(count) \(noun)\(count == 1 ? "" : "s")"
}

/// Status always has a text label; the dot is a supplementary scanning cue.
private struct WorkDashboardStatus: View {
  let row: WorkRecord
  private var color: Color {
    switch row.progress {
    case "in_progress": return .accentColor
    case "done": return .secondary
    default: return Color(uiColor: .tertiaryLabel)
    }
  }
  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 5, height: 5).accessibilityHidden(true)
      Text(row.progressLabel).foregroundStyle(.secondary)
    }.fixedSize(horizontal: false, vertical: true)
  }
}

private struct WorkDashboardTaskPreview: View {
  let label: String
  let task: WorkRecord
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
          .padding(.horizontal, 6).padding(.vertical, 3)
          .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
          .fixedSize()
        Text(task.title).font(.caption).lineLimit(1)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Text(task.title).font(.caption).lineLimit(2)
      }
    }.foregroundStyle(.primary).accessibilityElement(children: .combine)
  }
}

private struct WorkDashboardExpanded: View {
  let panel: WorkDashboardView.Panel
  let snapshot: WorkDashboard
  let destination: (WorkRecord) -> AnyView
  let scope: WorkDashboard.Scope
  @State private var search = ""
  @State private var project: String?
  init(panel: WorkDashboardView.Panel, snapshot: WorkDashboard, scope: WorkDashboard.Scope,
       project: String?, destination: @escaping (WorkRecord) -> AnyView) {
    self.panel = panel; self.snapshot = snapshot; self.scope = scope; self.destination = destination
    _project = State(initialValue: project)
  }
  private var rows: [WorkRecord] {
    let rows: [WorkRecord]
    switch panel {
    case .pulse: rows = snapshot.projects(in: scope)
    case .activity: rows = snapshot.issues(in: project)
    case .todo: rows = snapshot.todos
    case .all: rows = snapshot.recent(snapshot.records)
    }
    return rows.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
  }
  var body: some View {
    List {
      Section {
        Text(snapshot.complete ? "Within your shared Work" : "Loaded items only · return to Work to load more")
          .font(.footnote).foregroundStyle(.secondary)
        if panel == .activity {
          Picker("Project", selection: $project) {
            Text("All projects").tag(String?.none)
            ForEach(snapshot.projects(), id: \.rowID) { Text($0.title).tag(Optional($0.rowID)) }
          }
        }
      }
      ForEach(rows, id: \.rowID) { row in
        NavigationLink { destination(row) } label: {
          if panel == .pulse { WorkDashboardProjectRow(row: row, snapshot: snapshot) }
          else if panel == .activity { WorkDashboardIssueRow(row: row, snapshot: snapshot) }
          else {
            VStack(alignment: .leading, spacing: 5) {
              Text(row.title).font(.subheadline)
              Text(panel == .all ? row.kind + " · " + row.progressLabel : snapshot.context(for: row))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
      if rows.isEmpty { Text("No matching loaded items.").foregroundStyle(.secondary) }
    }.navigationTitle(panel.rawValue).navigationBarTitleDisplayMode(.inline)
      .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search loaded " + (panel == .pulse ? "projects" : panel == .activity ? "issues" : panel == .todo ? "tasks" : "work"))
  }
}
