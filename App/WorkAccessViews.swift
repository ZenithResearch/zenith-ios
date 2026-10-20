import SwiftUI
import ZenithKit

@MainActor
func workClient(_ model: WalletModel) -> DevgraphReadClient? {
  guard let configuration = model.workServer,
    let repository = model.repository
  else { return nil }
  let transport = configuration.network == .tailscale ? model.privateNetwork.transport() : nil
  return try? DevgraphReadClient(repository: repository, configuration: configuration, transport: transport)
}
struct WorkAccessView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var client: DevgraphReadClient?
  @State private var proposal: ReadAccessProposal?
  @State private var current: NativeReadManifest?
  @State private var continueSetup = false
  @State private var changingServer = false
  @State private var membershipSetup = false
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    Group {
      if let client {
        Form {
          WorkConnectionSection(configuration: client.connection, busy: model.busy).id(model.generation)
          if let proposal {
            Section("Read-only access") {
              LabeledContent("Provider", value: proposal.issuer)
              Text(proposal.receiver).foregroundStyle(.secondary)
              Text("Read permitted work. This cannot create, change or delete anything.")
              LabeledContent("Expires", value: proposal.expires.formatted())
              ForEach(Array(proposal.grants.enumerated()), id: \.offset) { _, grant in
                Text(grant.work_kinds.joined(separator: ", "))
                Text("Actions: " + grant.operations.joined(separator: ", "))
                if grant.operations.contains("relationships") {
                  Text("Related work: " + grant.relationship_types.joined(separator: ", "))
                }
                if let arenas = grant.arena_ids {
                  Text("Arenas: " + arenas.joined(separator: ", "))
                } else {
                  Text("All arenas")
                }
                if let ids = grant.work_ids {
                  Text("Selected items: " + ids.joined(separator: ", "))
                }
                Text(
                  grant.include_archived ? "Includes archived work" : "Archived work is excluded")
              }
            }
            Section {
              Button("Allow read-only access") {
                model.perform({ _ in
                  try await client.connect(proposal)
                  return try await client.manifest()
                }) {
                  current = $0
                  self.proposal = nil
                  model.notice = "Connected. Your work is ready to read."
                }
              }.buttonStyle(.borderedProminent)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white).disabled(model.busy)
              Button("Cancel") {
                client.cancel()
                model.cancel()
                self.proposal = nil
              }
            }
          } else if let current {
            Section {
              LabeledContent("Access", value: "Read only")
              Text(current.receiver)
              LabeledContent(
                "Expires",
                value: Date(timeIntervalSince1970: Double(current.expires_at)).formatted())
            }
            Section {
              Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
              Button("Remove read access") {
                model.perform({ _ in try await client.disconnect() }) { _ in
                  self.current = nil
                  model.notice = "Work access removed from this device."
                }
              }
            } footer: {
              Text(
                "The server can also revoke access. Recovery files do not contain this connection.")
            }
          } else if model.state?.membershipActive != true {
            Section {
              Text("Join Zenith to continue").font(.headline)
              Text("Your server is saved. Join Zenith here, then continue with your request for work access. Membership does not grant access to this server.")
              Button("Open Membership") { membershipSetup = true }
                .accessibilityIdentifier("work.membership.open")
            }
          } else {
            if let store = model.accessRequestStore { WorkAccessRequestSection(client:client,store:store) }
            Section {
              Text("Approve what you can read").font(.headline)
              Text("Next, your server shows the work available to you and when access expires.")
              Button("Continue") {
                model.perform({ _ in try await client.prepare() }) { proposal = $0 }
              }.buttonStyle(.borderedProminent)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .disabled(model.busy || (client.connection.network == .tailscale && privateNetwork.phase != .connected))
            }
          }
          Section {
            Button("Change connection") { changingServer = true }.disabled(model.busy)
            Button("Remove server", role: .destructive) {
              client.cancel()
              model.saveWorkServer(nil) {}
            }.disabled(model.busy)
          } footer: {
            Text("Removes this device’s server settings and read access. Your wallet and server data stay intact.")
          }
          Section { Feedback() }
        }.navigationTitle("Work access")
      } else {
        WorkServerSetupView(busy: model.busy, saveError: model.error) { configuration in
          continueSetup = true
          model.saveWorkServer(configuration) {}
        }
      }
    }.sheet(isPresented: $membershipSetup) {
      NavigationStack {
        MembershipView {
          membershipSetup = false
          model.notice = "Membership active. Request work access from your saved server."
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Back to Work") { membershipSetup = false }
          }
        }
      }
    }.sheet(isPresented: $changingServer) {
      NavigationStack {
        WorkServerSetupView(busy: model.busy, saveError: model.error) { configuration in
          client?.cancel()
          continueSetup = true
          model.saveWorkServer(configuration) { changingServer = false }
        }
        .environmentObject(model.workDraft)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { changingServer = false } } }
      }
    }.task(id: model.generation) {
      client?.cancel()
      proposal = nil
      current = nil
      client = workClient(model)
      let version = model.generation
      let manifest = try? await client?.manifest()
      guard !Task.isCancelled, version == model.generation else { return }
      current = manifest
      if continueSetup {
        continueSetup = false
        if manifest == nil, model.state?.membershipActive == true, let client {
          model.perform({ _ in try await client.prepare() }) { proposal = $0 }
        }
      }
    }
    .onChange(of: privateNetwork.generation) { _, _ in
      if model.workServer?.network == .tailscale {
        client?.cancel()
        proposal = nil
        model.cancel()
      }
    }
    .onDisappear {
      client?.cancel()
      // Opening the membership sheet is part of this saved-server flow. Do not
      // invalidate its Wallet operations because the presenting view is covered.
      if !membershipSetup { model.cancel() }
    }
  }
}
struct NativeWorkView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var client: DevgraphReadClient?
  @State private var rows: [WorkRecord] = []
  @State private var cursors: [String: WorkPageCursor] = [:]
  @State private var finished: Set<String> = []
  @State private var allowed: [String] = []
  @State private var detailKinds: Set<String> = []
  @State private var error: String?
  @State private var loading = false
  @State private var filters = false
  @State private var connection = false
  @EnvironmentObject private var draft: WorkServerDraft
  @State private var search = ""
  @AppStorage("workKindFilter") private var kind = "All types"
  private var visible: [WorkRecord] {
    rows.filter {
      (kind == "All types" || $0.kind == kind)
        && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
    }
  }
  var body: some View {
    NavigationStack {
      List {
        if rows.isEmpty && !loading {
          if let error {
            Text(error)
          } else {
            Text("Connect read-only work access to see your items.")
          }
        }
        if rows.isEmpty && !loading {
          NavigationLink("Set up work connection") { WorkAccessView() }
        }
        ForEach(visible, id: \.rowID) { row in
          NavigationLink {
            NativeWorkDetailView(row: row, canRead: detailKinds.contains(row.kind))
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(row.title)
              Text(row.kind + " · " + row.progressLabel).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
          }
        }
        if loading {
          ProgressView("Loading work")
        } else if !allowed.isEmpty && !Set(allowed).isSubset(of: finished) {
          Button("Load more") { Task { await loadMore() } }
        }
        if !rows.isEmpty, let error { Text(error) }
      }.navigationTitle("Work")
        .searchable(text: $search, prompt: "Search loaded work")
        .refreshable {
          rows = []; cursors = [:]; finished = []
          await loadMore()
        }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Connection", systemImage: "network") { connection = true }
              .accessibilityIdentifier("work.connection.settings")
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Filters", systemImage: "line.3.horizontal.decrease") { filters = true }
          }
        }
        .navigationDestination(isPresented: $connection) { WorkAccessView() }
        .onAppear { if draft.active { connection = true } }
        .sheet(isPresented: $filters) {
          NavigationStack {
            Form {
              Picker("Type", selection: $kind) {
                Text("All types").tag("All types")
                ForEach(allowed, id: \.self) { Text($0).tag($0) }
              }
            }.navigationTitle("Filters").toolbar { Button("Done") { filters = false } }
          }
        }
        .task(id: model.generation) {
          client?.cancel()
          rows = []
          cursors = [:]
          finished = []
          allowed = []
          detailKinds = []
          error = nil
          client = workClient(model)
          loading = false
          let version = model.generation
          do {
            if let manifest = try await client?.manifest() {
              guard !Task.isCancelled, version == model.generation else { return }
              detailKinds = Set(manifest.read_grants.filter { $0.operations.contains("get") }.flatMap(\.work_kinds))
              allowed = Array(
                Set(
                  manifest.read_grants.filter { $0.operations.contains("list") }.flatMap(
                    \.work_kinds))
              ).sorted()
              if !allowed.contains(kind) { kind = "All types" }
              if rows.isEmpty { await loadMore() }
            }
          } catch {
            guard !Task.isCancelled, version == model.generation else { return }
            self.error = "Work access needs setup or has expired. Open Work access in Wallet."
          }
        }
    }
    .onChange(of: privateNetwork.phase) { _, phase in
      if phase == .connected, model.workServer?.network == .tailscale {
        Task { await loadMore() }
      }
    }
    .onChange(of: privateNetwork.generation) { _, _ in
      if model.workServer?.network == .tailscale {
        client?.cancel()
        rows = []; cursors = [:]; finished = []
        loading = false
        error = "Private connection changed. Open Connection to reconnect."
      }
    }
    .onDisappear { client?.cancel() }
  }
  private func loadMore() async {
    guard !loading, let client else { return }
    loading = true
    error = nil
    let version = model.generation
    let usesPrivateNetwork = client.connection.network == .tailscale
    let networkVersion = privateNetwork.generation
    func current() -> Bool {
      version == model.generation && (!usesPrivateNetwork || networkVersion == privateNetwork.generation)
    }
    defer { if current() { loading = false } }
    do {
      for type in allowed where !finished.contains(type) {
        let page = try await client.page(kind: type, after: cursors[type])
        guard current(), !Task.isCancelled else { return }
        if let next = page.next { cursors[type] = next }
        else { finished.insert(type) }
        let existing = Set(rows.map(\.rowID))
        guard page.items.allSatisfy({ !existing.contains($0.rowID) }) else {
          throw WalletFailure.core("invalid_response")
        }
        rows.append(contentsOf: page.items)
      }
    } catch {
      if current() {
        if invalidatesWorkAccess(error) {
          rows = []
          cursors = [:]
          finished = []
          allowed = []
        }
        self.error = error.localizedDescription
      }
    }
  }
}

/// Fetch details through the granted get operation. Modern lists intentionally
/// omit descriptions; a list result must never be presented as a complete item.
struct NativeWorkDetailView: View {
  let row: WorkRecord
  let canRead: Bool
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var record: WorkRecord?
  @State private var client: DevgraphReadClient?
  @State private var error: String?
  @State private var relationships: [String] = []
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let record {
          Text(record.kind).foregroundStyle(.secondary)
          Text(record.title).font(.title2.bold())
          Text(record.progressLabel).font(.subheadline)
          Text(record.description).textSelection(.enabled)
          if !canRead { Text("Your access includes this summary. Full item details need separate read permission.").font(.footnote) }
          ForEach(relationships, id: \.self) { relationship in
            NavigationLink(relationshipTitle(relationship)) {
              NativeRelatedWorkView(anchor: record, relationship: relationship)
            }
          }
        } else if let error {
          Text(error)
        } else { ProgressView("Loading item") }
      }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }.navigationTitle("Work item").navigationBarTitleDisplayMode(.inline)
      .task(id: model.generation) {
        record = nil; error = nil; relationships = []; client?.cancel()
        client = workClient(model)
        let version = model.generation
        do {
          guard let client else { throw WalletFailure.core("access_setup_required") }
          let manifest = try await client.manifest()
          let permitted = manifest.read_grants.filter { $0.operations.contains("relationships") && $0.work_kinds.contains(row.kind) }
          let loaded = canRead ? try await client.get(kind: row.kind, id: row.id) : row
          guard !Task.isCancelled, version == model.generation else { return }
          record = loaded
          relationships = Array(Set(permitted.flatMap(\.relationship_types))).sorted()
        } catch {
          guard !Task.isCancelled, version == model.generation else { return }
          self.error = error.localizedDescription
        }
      }
      .onChange(of: privateNetwork.generation) { _, _ in
        if model.workServer?.network == .tailscale {
          client?.cancel(); record = nil
          error = "Private connection changed. Return to Work and reconnect."
        }
      }
      .onDisappear { client?.cancel(); record = nil }
  }
}

private func relationshipTitle(_ relationship: String) -> String {
  ["children": "Children", "parent": "Parent", "dependencies": "Depends on",
   "dependents": "Used by", "blocked": "Blocks", "blockers": "Blocked by"][relationship] ?? "Related work"
}
private func invalidatesWorkAccess(_ error: Error) -> Bool {
  guard let failure = error as? WalletFailure, case .core(let code) = failure else { return false }
  return ["access_denied", "access_expired", "access_setup_required", "membership_required",
    "invalid_read_authority", "read_not_permitted", "issuer_setup_required"].contains(code)
}
struct NativeRelatedWorkView: View {
  let anchor: WorkRecord
  let relationship: String
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var rows: [WorkRecord] = []
  @State private var client: DevgraphReadClient?
  @State private var cursor: WorkPageCursor?
  @State private var finished = false
  @State private var loading = false
  @State private var detailKinds: Set<String> = []
  @State private var error: String?
  var body: some View {
    List {
      ForEach(rows, id: \.rowID) { row in
        NavigationLink {
          NativeWorkDetailView(row: row, canRead: detailKinds.contains(row.kind))
        } label: {
          VStack(alignment: .leading) {
            Text(row.title)
            Text(row.kind + " · " + row.progressLabel).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      if loading { ProgressView("Loading related work") }
      else if let error { Text(error) }
      else if rows.isEmpty { Text("No related work is visible within your access.") }
      if !finished && !loading && error == nil { Button("Load more") { Task { await loadMore() } } }
    }.navigationTitle(relationshipTitle(relationship))
      .task(id: model.generation) {
        client?.cancel(); rows = []; cursor = nil; finished = false; loading = false; error = nil
        client = workClient(model)
        await loadMore()
      }
      .onChange(of: privateNetwork.generation) { _, _ in
        if model.workServer?.network == .tailscale {
          client?.cancel(); rows = []; loading = false
          error = "Private connection changed. Return to Work and reconnect."
        }
      }
      .onDisappear { client?.cancel() }
  }
  private func loadMore() async {
    guard !loading, !finished, let client else { return }
    loading = true; error = nil
    let version = model.generation
    let networkVersion = privateNetwork.generation
    func current() -> Bool {
      version == model.generation && (client.connection.network != .tailscale || networkVersion == privateNetwork.generation)
    }
    defer { if current() { loading = false } }
    do {
      let manifest = try await client.manifest()
      let page = try await client.related(kind: anchor.kind, id: anchor.id, relationship: relationship, after: cursor)
      guard current(), !Task.isCancelled else { return }
      detailKinds = Set(manifest.read_grants.filter { $0.operations.contains("get") }.flatMap(\.work_kinds))
      let existing = Set(rows.map(\.rowID))
      guard page.items.allSatisfy({ !existing.contains($0.rowID) }) else { throw WalletFailure.core("invalid_response") }
      rows.append(contentsOf: page.items)
      cursor = page.next; finished = page.next == nil
    } catch {
      guard current(), !Task.isCancelled else { return }
      if invalidatesWorkAccess(error) { rows = []; finished = true }
      self.error = error.localizedDescription
    }
  }
}
