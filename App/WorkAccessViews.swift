import SwiftUI
import ZenithKit

@MainActor
private func workConnectionLoadKey(_ model: WalletModel) -> String {
  let network = model.workServer?.network == .tailscale
    ? "\(model.privateNetwork.generation):\(model.privateNetwork.phase == .connected)" : "direct"
  return "\(model.generation):\(network)"
}

@MainActor
func workClient(_ model: WalletModel) async -> DevgraphReadClient? {
  guard let configuration = model.workServer,
    let repository = model.repository, !model.paused, !model.obscured
  else { return nil }
  let version = model.generation
  do {
    let transport = try configuration.network == .tailscale ? model.privateNetwork.transport() : PrivateTransport(workServer: configuration)
    var resolved = try await configuration.resolveService(transport: transport)
    // An original request issued to a legacy inbox must be recovered there.
    // Its signed identity/receiver is never rewritten to adopt another inbox.
    if resolved.authorityOrigin != configuration.origin, let store = model.accessRequestStore,
       let identity = try JSONSerialization.jsonObject(with: await repository.graphAccessIdentityV2()) as? [String:String],
       let subject = identity["subject_public_key"], let installation = identity["installation_id"],
       try store.existing(receiver: configuration.origin, subject: subject, installation: installation) != nil {
      resolved = try configuration.withServiceAccessPoint(nil)
    }
    guard !Task.isCancelled, version == model.generation else { transport.cancel(); return nil }
    return try DevgraphReadClient(repository: repository, configuration: resolved, transport: transport)
  } catch {
    guard !Task.isCancelled, version == model.generation else { return nil }
    if let networkError = error as? PrivateNetworkError {
      model.error = networkError.localizedDescription
    } else if let urlError = error as? URLError {
      model.error = WorkConnectionFailure(code: urlError.code, network: configuration.network).localizedDescription
    } else {
      model.error = "Could not verify this service connection. Your server and original requests are preserved."
    }
    return nil
  }
}
struct WorkAccessView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var client: DevgraphReadClient?
  @State private var proposal: ReadAccessProposal?
  @State private var holderReview: HolderGrantReview?
  @State private var grantRecovery = false
  @State private var reusableAvailable = false
  @State private var requestResult: WorkAccessRequestResult?
  @State private var editingRequest = false
  @State private var current: NativeReadManifest?
  @State private var continueSetup = false
  @State private var changingServer = false
  @State private var membershipSetup = false
  @Environment(\.dismiss) private var dismiss
  // Reconnection readiness changes after the network generation changes.
  // Include both so an early verification is retried once the route is ready.
  private var connectionLoadKey: String {
    workConnectionLoadKey(model)
  }
  var body: some View {
    Group {
      if let client {
        Form {
          WorkConnectionSection(configuration: client.connection, busy: model.busy).id(
            model.generation)
          if let holderReview {
            Section("Save reusable grant") { HolderGrantSummaryView(summary: holderReview.summary) }
            Section {
              Button("Save grant in Wallet") {
                model.perform({ _ in
                  try await client.saveReusableGrant(holderReview)
                  return try await client.manifest()
                }) {
                  current = $0
                  self.holderReview = nil
                  proposal = nil
                  grantRecovery = false
                  model.notice = "Grant saved in Wallet. Work is ready to read."
                }
              }.buttonStyle(.borderedProminent).disabled(model.busy)
              Button("Cancel") { self.holderReview = nil }
            }
          } else if let proposal {
            Section("Read-only access") {
              LabeledContent("Provider", value: proposal.issuer)
              Text(proposal.receiver).foregroundStyle(.secondary)
              Text("Read permitted work. This cannot create, change or delete anything.")
              Text(proposal.membershipRequirement.disclosure).font(.footnote)
              LabeledContent("Read credential expires", value: proposal.expires.formatted())
              Text(
                "You can obtain a new read credential while your operator-approved grant remains active. No new operator decision is needed."
              ).font(.footnote)
              ForEach(Array(proposal.grants.enumerated()), id: \.offset) { _, grant in
                Text(grant.isArena ? "Arena records · names and details" : grant.work_kinds.joined(separator: ", "))
                Text("Actions: " + grant.operations.joined(separator: ", "))
                if grant.operations.contains("relationships") {
                  Text("Related work: " + grant.relationship_types.joined(separator: ", "))
                }
                if let paths = grant.resource_paths {
                  ForEach(paths, id: \.self) { path in Text("Path: " + path.summary) }
                  Text(
                    "Evaluated at each access. New descendants are included; moved-out resources lose access."
                  ).font(.footnote)
                }
                if let arenas = grant.arena_ids {
                  Text((grant.isArena ? "Only Arena records: " : "Work in Arenas: ") + arenas.joined(separator: ", "))
                } else if grant.isArena && grant.all_arenas == true {
                  Text("All current and future Arena records")
                } else if grant.resource_paths == nil {
                  Text("All matching Work resources")
                }
                if let ids = grant.work_ids {
                  Text("Selected items: " + ids.joined(separator: ", "))
                }
                if grant.isArena {
                  Text("Arena metadata does not grant access to its Work.").font(.footnote)
                } else {
                  Text(grant.include_archived ? "Includes archived work" : "Archived work is excluded")
                }
              }
            }
            Section {
              if reusableAvailable {
                Button("Request reusable grant") {
                  model.perform({ _ in
                    do { return try await client.requestReusableGrant(proposal) } catch {
                      grantRecovery = await client.hasPendingReusableGrant()
                      throw error
                    }
                  }) {
                    holderReview = $0
                    grantRecovery = false
                  }
                }.buttonStyle(.borderedProminent).disabled(model.busy)
                Text(
                  "Review the provider-signed grant before saving it. A saved grant lets this Wallet produce its own credentials within the same or a narrower scope."
                ).font(.footnote)
                if grantRecovery {
                  Button("Recover original grant") {
                    model.perform({ _ in try await client.recoverReusableGrant() }) {
                      holderReview = $0
                      grantRecovery = false
                    }
                  }
                  Text("Recover the original result. This does not send a new grant request.").font(
                    .footnote)
                }
              }
              Button("Use temporary read access") {
                model.perform({ _ in
                  try await client.connect(proposal)
                  return try await client.manifest()
                }) {
                  current = $0
                  self.proposal = nil
                  model.notice = "Connected. Your work is ready to read."
                }
              }.buttonStyle(.borderedProminent)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white).disabled(
                  model.busy)
              Button("Cancel") {
                client.cancel()
                model.cancel()
                self.proposal = nil
              }
            }
          } else if let current {
            if let store = model.accessRequestStore {
              WorkAccessRequestSection(client: client, store: store, result: $requestResult, editingRequest: $editingRequest)
            }
            Section {
              LabeledContent("Access", value: "Read only")
              Text(current.receiver)
              LabeledContent(
                "Read credential expires",
                value: Date(timeIntervalSince1970: Double(current.expires_at)).formatted())
            }
            Section {
              if reusableAvailable {
                Button("Review reusable grant…") {
                  model.perform({ _ in try await client.prepare() }) { proposal = $0 }
                }.disabled(model.busy)
                Text(
                  "Save a provider-signed grant in Wallet without removing this connection or requesting another operator decision."
                )
                .font(.footnote)
              }
              Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
              Button("Remove read access") {
                model.perform({ _ in try await client.disconnect() }) { _ in
                  self.current = nil
                  model.notice = "Work access removed from this device."
                }
              }
            } footer: {
              Text(
                "The server can revoke access. Reusable grants have a separate encrypted grant backup in Wallet; connection settings remain in this app."
              )
            }
          } else if model.state?.canRequestWorkAccess != true {
            Section {
              Text("Prepare your Wallet").font(.headline)
              Text(
                "Unlock your Wallet and verify its recovery backup before requesting access. Community membership is separate from access to this graph."
              )
            }
          } else {
            if let store = model.accessRequestStore {
              WorkAccessRequestSection(client: client, store: store, result: $requestResult, editingRequest: $editingRequest)
            }
            if !editingRequest {
              Section {
                if requestResult?.canReviewReadAccess == true {
                  Text("Read access approved").font(.headline)
                  Text("Review the exact permissions before saving read access on this device.")
                  Button("Review approved read access") { reviewReadAccess(client) }
                    .buttonStyle(.borderedProminent).disabled(readReviewDisabled(client))
                } else {
                  DisclosureGroup("Already have an approved read grant?") {
                    Text("Check existing read access without sending another credential request. You can request credentials above even if no grant exists.").font(.footnote)
                    Button("Check existing read access") { reviewReadAccess(client) }
                      .disabled(readReviewDisabled(client))
                  }
                }
              }
            }
          }
          Section {
            Button(model.state?.membershipActive == true ? "Community membership · Active" : "Community membership") { membershipSetup = true }
              .accessibilityIdentifier("work.membership.open")
            Button("Change connection") { changingServer = true }.disabled(model.busy)
            Button("Remove server", role: .destructive) {
              client.cancel()
              model.saveWorkServer(nil) {}
            }.disabled(model.busy)
          } footer: {
            Text(
              "Removes this device’s server settings and read access. Your wallet and server data stay intact."
            )
          }
        }.navigationTitle("Work access")
          .safeAreaInset(edge: .bottom) {
            if model.error != nil || model.notice != nil || model.busy {
              VStack(alignment: .leading, spacing: 8) { Feedback() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().background(.regularMaterial)
                .accessibilityIdentifier("work.access.feedback")
            }
          }
      } else if let configuration = model.workServer {
        Form {
          WorkConnectionSection(configuration: configuration, busy: model.busy)
          Section("Saved Work connection") {
            if let error = model.error { Text(error).foregroundStyle(.red) }
            else if configuration.network == .tailscale && privateNetwork.phase != .connected {
              Text("Connect Tailscale above. Service verification resumes when the private network is ready.")
            }
            else { ProgressView("Verifying connection") }
            Button("Retry connection") { model.error = nil; model.generation += 1 }
              .disabled(configuration.network == .tailscale && privateNetwork.phase != .connected)
            Button("Change connection") { changingServer = true }
          }
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
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { changingServer = false }
          }
        }
      }
    }.task(id: connectionLoadKey) {
      client?.cancel()
      client = nil
      proposal = nil
      holderReview = nil
      current = nil
      requestResult = nil; editingRequest = false
      reusableAvailable = false
      if model.workServer?.network == .tailscale && privateNetwork.phase != .connected {
        model.error = nil
        return
      }
      let attempt = connectionLoadKey
      model.error = nil
      let loaded = await workClient(model)
      guard !Task.isCancelled, attempt == connectionLoadKey else { loaded?.cancel(); return }
      client = loaded
      let version = model.generation
      let supports = (try? await client?.supportsReusableGrants()) == true
      let manifest = try? await client?.manifest()
      guard !Task.isCancelled, version == model.generation else { return }
      reusableAvailable = supports
      current = manifest
      if continueSetup {
        continueSetup = false
        if manifest == nil {
          model.notice = "Server saved. Request access, or check your existing grant, to continue."
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
  private func readReviewDisabled(_ client: DevgraphReadClient) -> Bool {
    model.busy || (client.connection.network == .tailscale && privateNetwork.phase != .connected)
  }
  private func reviewReadAccess(_ client: DevgraphReadClient) {
    model.perform({ _ -> ReadAccessProposal? in
      do { return try await client.prepare() }
      catch WalletFailure.core("access_denied") { return nil }
    }) { available in
      if let available { proposal = available }
      else {
        model.notice = "No approved read access was found. You can still send or check a credential request above; it does not require existing graph access."
      }
    }
  }

}
struct NativeWorkView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var client: DevgraphReadClient?
  @State private var rows: [WorkRecord] = []
  @State private var hasArenas = false
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
        if hasArenas {
          NavigationLink { NativeArenaListView() } label: {
            Label("Shared Arenas", systemImage: "square.stack.3d.up")
          }
        }
        if rows.isEmpty && !loading && !hasArenas {
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
          rows = []
          cursors = [:]
          finished = []
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
        .task(id: workConnectionLoadKey(model)) {
          if model.workServer?.network == .tailscale && privateNetwork.phase != .connected { return }
          await reload()
        }
    }
    .onChange(of: privateNetwork.generation) { _, _ in
      if model.workServer?.network == .tailscale {
        client?.cancel()
        rows = []
        cursors = [:]
        finished = []
        loading = false
        error = "Private connection changed. Open Connection to reconnect."
      }
    }
    .onDisappear { client?.cancel() }
  }
  private func reload() async {
    client?.cancel()
    rows = []
    cursors = [:]
    finished = []
    allowed = []
    detailKinds = []
    hasArenas = false
    error = nil
    let attempt = workConnectionLoadKey(model)
    let loaded = await workClient(model)
    guard !Task.isCancelled, attempt == workConnectionLoadKey(model) else { loaded?.cancel(); return }
    client = loaded
    loading = false
    let version = model.generation
    do {
      if let manifest = try await client?.manifest() {
        guard !Task.isCancelled, version == model.generation else { return }
        configurePermissions(manifest)
        if !allowed.contains(kind) { kind = "All types" }
        if rows.isEmpty { await loadMore() }
      }
    } catch {
      guard !Task.isCancelled, version == model.generation else { return }
      self.error = "Work access needs setup or has expired. Open Work access in Wallet."
    }

  }
  private func configurePermissions(_ manifest: NativeReadManifest) {
    let grants: [WorkReadGrant] = manifest.read_grants
    hasArenas = grants.contains { grant in grant.isArena && grant.operations.contains("list") }
    let detail: [String] = grants.filter { $0.operations.contains("get") }.flatMap { $0.work_kinds }
    let listed: [String] = grants.filter { $0.operations.contains("list") }.flatMap { $0.work_kinds }
    detailKinds = Set(detail)
    allowed = Array(Set(listed)).sorted()
  }
  private func loadMore() async {
    guard !loading, let client else { return }
    loading = true
    error = nil
    let version = model.generation
    let usesPrivateNetwork = client.connection.network == .tailscale
    let networkVersion = privateNetwork.generation
    func current() -> Bool {
      version == model.generation
        && (!usesPrivateNetwork || networkVersion == privateNetwork.generation)
    }
    defer { if current() { loading = false } }
    do {
      for type in allowed where !finished.contains(type) {
        let page = try await client.page(kind: type, after: cursors[type])
        guard current(), !Task.isCancelled else { return }
        if let next = page.next { cursors[type] = next } else { finished.insert(type) }
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
          if !canRead {
            Text(
              "Your access includes this summary. Full item details need separate read permission."
            ).font(.footnote)
          }
          ForEach(relationships, id: \.self) { relationship in
            NavigationLink(relationshipTitle(relationship)) {
              NativeRelatedWorkView(anchor: record, relationship: relationship)
            }
          }
        } else if let error {
          Text(error)
        } else {
          ProgressView("Loading item")
        }
      }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }.navigationTitle("Work item").navigationBarTitleDisplayMode(.inline)
      .task(id: model.generation) {
        record = nil
        error = nil
        relationships = []
        client?.cancel()
        client = await workClient(model)
        let version = model.generation
        do {
          guard let client else { throw WalletFailure.core("access_setup_required") }
          let manifest = try await client.manifest()
          let permitted = manifest.read_grants.filter {
            $0.operations.contains("relationships") && $0.work_kinds.contains(row.kind)
          }
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
          client?.cancel()
          record = nil
          error = "Private connection changed. Return to Work and reconnect."
        }
      }
      .onDisappear {
        client?.cancel()
        record = nil
      }
  }
}

private func relationshipTitle(_ relationship: String) -> String {
  [
    "children": "Children", "parent": "Parent", "dependencies": "Depends on",
    "dependents": "Used by", "blocked": "Blocks", "blockers": "Blocked by",
  ][relationship] ?? "Related work"
}
private func invalidatesWorkAccess(_ error: Error) -> Bool {
  guard let failure = error as? WalletFailure, case .core(let code) = failure else { return false }
  return [
    "access_denied", "access_expired", "access_setup_required", "membership_required",
    "invalid_read_authority", "read_not_permitted", "issuer_setup_required",
  ].contains(code)
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
      if loading {
        ProgressView("Loading related work")
      } else if let error {
        Text(error)
      } else if rows.isEmpty {
        Text("No related work is visible within your access.")
      }
      if !finished && !loading && error == nil { Button("Load more") { Task { await loadMore() } } }
    }.navigationTitle(relationshipTitle(relationship))
      .task(id: model.generation) {
        client?.cancel()
        rows = []
        cursor = nil
        finished = false
        loading = false
        error = nil
        client = await workClient(model)
        await loadMore()
      }
      .onChange(of: privateNetwork.generation) { _, _ in
        if model.workServer?.network == .tailscale {
          client?.cancel()
          rows = []
          loading = false
          error = "Private connection changed. Return to Work and reconnect."
        }
      }
      .onDisappear { client?.cancel() }
  }
  private func loadMore() async {
    guard !loading, !finished, let client else { return }
    loading = true
    error = nil
    let version = model.generation
    let networkVersion = privateNetwork.generation
    func current() -> Bool {
      version == model.generation
        && (client.connection.network != .tailscale || networkVersion == privateNetwork.generation)
    }
    defer { if current() { loading = false } }
    do {
      let manifest = try await client.manifest()
      let page = try await client.related(
        kind: anchor.kind, id: anchor.id, relationship: relationship, after: cursor)
      guard current(), !Task.isCancelled else { return }
      detailKinds = Set(
        manifest.read_grants.filter { $0.operations.contains("get") }.flatMap(\.work_kinds))
      let existing = Set(rows.map(\.rowID))
      guard page.items.allSatisfy({ !existing.contains($0.rowID) }) else {
        throw WalletFailure.core("invalid_response")
      }
      rows.append(contentsOf: page.items)
      cursor = page.next
      finished = page.next == nil
    } catch {
      guard current(), !Task.isCancelled else { return }
      if invalidatesWorkAccess(error) {
        rows = []
        finished = true
      }
      self.error = error.localizedDescription
    }
  }
}

/// Shared Arena metadata is displayed separately from the Work it may contain.
struct NativeArenaListView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var client: DevgraphReadClient?
  @State private var rows: [ArenaRecord] = []
  @State private var after: String?
  @State private var loading = false
  @State private var finished = false
  @State private var error: String?
  @State private var detailIDs: Set<String> = []
  @State private var allArenaDetails = false
  var body: some View {
    List {
      Section {
        Text("Only explicitly shared Arena records appear here. Work requires its own permission.").font(.footnote)
        ForEach(rows) { row in
          if allArenaDetails || detailIDs.contains(row.id) {
            NavigationLink(row.title) {
              NativeArenaDetailView(id: row.id)
            }
          } else { Text(row.title) }
        }
      }
      if loading { ProgressView("Loading Arenas") }
      if let error { Text(error) }
      if !loading && !finished && error == nil {
        Button("Load more") { Task { await load() } }
      }
    }.navigationTitle("Shared Arenas")
      .task(id: model.generation) {
        client?.cancel(); client = await workClient(model)
        rows = []; after = nil; finished = false; error = nil; loading = false
        detailIDs = []; allArenaDetails = false
        await load()
      }
      .onChange(of: privateNetwork.generation) { _, _ in
        if model.workServer?.network == .tailscale {
          client?.cancel(); rows = []; detailIDs = []; allArenaDetails = false
          error = "Private connection changed. Return to Work and reconnect."
        }
      }
      .onDisappear { client?.cancel() }
  }
  private func load() async {
    guard !loading, !finished, let client else { return }
    loading = true; error = nil
    let generation = model.generation, network = privateNetwork.generation
    func current() -> Bool { generation == model.generation && (client.connection.network != .tailscale || network == privateNetwork.generation) && !Task.isCancelled }
    defer { if current() { loading = false } }
    do {
      let manifest = try await client.manifest()
      let page = try await client.arenas(after: after)
      guard current() else { return }
      let existing = Set(rows.map(\.id))
      guard page.items.allSatisfy({ !existing.contains($0.id) }) else { throw WalletFailure.core("invalid_response") }
      let detailGrants = manifest.read_grants.filter { $0.isArena && $0.operations.contains("get") }
      detailIDs = Set(detailGrants.flatMap { $0.arena_ids ?? [] })
      allArenaDetails = detailGrants.contains { $0.all_arenas == true }
      rows += page.items; after = page.next; finished = page.next == nil
    } catch {
      guard current() else { return }
      if invalidatesWorkAccess(error) {
        rows = []; detailIDs = []; allArenaDetails = false; finished = true
      }
      self.error = error.localizedDescription
    }
  }
}
struct NativeArenaDetailView: View {
  let id: String
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var client: DevgraphReadClient?
  @State private var row: ArenaRecord?
  @State private var error: String?
  var body: some View {
    Form {
      if let row {
        Text(row.title).font(.headline)
        Text(row.description)
        Text("Arena · revision \(row.version)").font(.caption)
      } else if let error { Text(error) } else { ProgressView("Loading Arena") }
    }.navigationTitle("Arena")
      .task(id: model.generation) {
        client?.cancel(); row = nil; error = nil
        guard let connection = await workClient(model) else { error = "Work access needs setup."; return }
        client = connection
        let generation = model.generation, network = privateNetwork.generation
        do {
          let value = try await connection.arena(id: id)
          guard !Task.isCancelled, generation == model.generation,
            connection.connection.network != .tailscale || network == privateNetwork.generation else { return }
          row = value
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
      }
      .onChange(of: privateNetwork.generation) { _, _ in
        if model.workServer?.network == .tailscale { client?.cancel(); row = nil; error = "Private connection changed. Return to Work and reconnect." }
      }
      .onDisappear { client?.cancel() }
  }
}
