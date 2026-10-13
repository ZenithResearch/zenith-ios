import SwiftUI
import ZenithKit

@MainActor
func workClient(_ model: WalletModel) -> DevgraphReadClient? {
  guard let configuration = model.workServer,
    let repository = model.repository
  else { return nil }
  let transport = configuration.network == .tailscale ? model.privateNetwork.transport() : PrivateTransport()
  return try? DevgraphReadClient(repository: repository, configuration: configuration, transport: transport)
}
struct WorkAccessView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var client: DevgraphReadClient?
  @State private var proposal: ReadAccessProposal?
  @State private var current: NativeReadManifest?
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
                  model.notice = "Read-only access saved. Open Work to read your items."
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
              Text("Set up Membership before connecting work.")
              NavigationLink("Open Membership") { MembershipView() }
            }
          } else {
            Section {
              Text("Review the permitted work and expiry before connecting.")
              Button("Review work access") {
                model.perform({ _ in try await client.prepare() }) { proposal = $0 }
              }.buttonStyle(.borderedProminent)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white).disabled(model.busy)
            }
          }
          Section {
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
          model.saveWorkServer(configuration) {}
        }
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
      model.cancel()
    }
  }
}
struct NativeWorkView: View {
  @EnvironmentObject private var model: WalletModel
  @EnvironmentObject private var privateNetwork: PrivateNetworkModel
  @State private var client: DevgraphReadClient?
  @State private var rows: [WorkRecord] = []
  @State private var cursors: [String: String] = [:]
  @State private var finished: Set<String> = []
  @State private var allowed: [String] = []
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
            ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                Text(row.kind).foregroundStyle(.secondary)
                Text(row.title).font(.title2).bold()
                Text(row.progressLabel).font(.subheadline)
                Text(row.description).textSelection(.enabled)
              }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }.navigationTitle("Work item").navigationBarTitleDisplayMode(.inline)
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
          error = nil
          client = workClient(model)
          loading = false
          let version = model.generation
          do {
            if let manifest = try await client?.manifest() {
              guard !Task.isCancelled, version == model.generation else { return }
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
        let page = try await client.list(kind: type, after: cursors[type])
        guard current(), !Task.isCancelled else { return }
        if page.count < 20 { finished.insert(type) }
        if let last = page.last {
          guard last.id != cursors[type] else { throw WalletFailure.core("invalid_response") }
          cursors[type] = last.id
        }
        let existing = Set(rows.map(\.rowID))
        rows.append(contentsOf: page.filter { !existing.contains($0.rowID) })
      }
    } catch {
      if current() {
        if let failure = error as? WalletFailure,
          failure == .core("access_denied") || failure == .core("access_expired")
        {
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
