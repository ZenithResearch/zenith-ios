import SwiftUI
import ZenithKit

@MainActor
func workClient(_ model: WalletModel) -> DevgraphReadClient? {
  guard let url = Bundle.main.url(forResource: "WorkAccess", withExtension: "json"),
    let data = try? Data(contentsOf: url), data.count <= 65_536,
    let configuration = try? JSONDecoder().decode(WorkAccessConfiguration.self, from: data),
    let repository = model.repository
  else { return nil }
  return try? DevgraphReadClient(repository: repository, configuration: configuration)
}
struct WorkAccessView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var client: DevgraphReadClient?
  @State private var proposal: ReadAccessProposal?
  @State private var current: NativeReadManifest?
  var body: some View {
    Group {
      if let client {
        Form {
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
              Button("Connect read-only access") {
                model.perform({ _ in
                  try await client.connect(proposal)
                  return try await client.manifest()
                }) {
                  current = $0
                  self.proposal = nil
                  model.notice = "Read-only access saved. Open Work to read your items."
                }
              }.buttonStyle(.borderedProminent).disabled(model.busy)
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
              Button("Disconnect this device") {
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
              }.buttonStyle(.borderedProminent).disabled(model.busy)
            }
          }
          Section { Feedback() }
        }.navigationTitle("Work access")
      } else {
        SetupInformation(kind: .work)
      }
    }.task {
      client = workClient(model)
      current = try? await client?.manifest()
    }
    .onChange(of: model.generation) { _, _ in
      client?.cancel()
      proposal = nil
      current = nil
    }
    .onDisappear {
      client?.cancel()
      model.cancel()
    }
  }
}
struct NativeWorkView: View {
  @EnvironmentObject private var model: WalletModel
  @State private var client: DevgraphReadClient?
  @State private var rows: [WorkRecord] = []
  @State private var cursors: [String: String] = [:]
  @State private var finished: Set<String> = []
  @State private var allowed: [String] = []
  @State private var error: String?
  @State private var loading = false
  @State private var filters = false
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
            Text("Connect read-only work access in Wallet to see your items.")
          }
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
        .toolbar { Button("Filters", systemImage: "line.3.horizontal.decrease") { filters = true } }
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
        .task {
          client = workClient(model)
          do {
            if let manifest = try await client?.manifest() {
              allowed = Array(
                Set(
                  manifest.read_grants.filter { $0.operations.contains("list") }.flatMap(
                    \.work_kinds))
              ).sorted()
              if !allowed.contains(kind) { kind = "All types" }
              if rows.isEmpty { await loadMore() }
            }
          } catch {
            self.error = "Work access needs setup or has expired. Open Work access in Wallet."
          }
        }
    }
    .onChange(of: model.generation) { _, _ in
      client?.cancel()
      rows = []
      cursors = [:]
      finished = []
      allowed = []
      error = nil
      loading = false
    }
    .onDisappear { client?.cancel() }
  }
  private func loadMore() async {
    guard !loading, let client else { return }
    loading = true
    error = nil
    let version = model.generation
    defer { if version == model.generation { loading = false } }
    do {
      for type in allowed where !finished.contains(type) {
        let page = try await client.list(kind: type, after: cursors[type])
        guard version == model.generation else { return }
        if page.count < 20 { finished.insert(type) }
        if let last = page.last {
          guard last.id != cursors[type] else { throw WalletFailure.core("invalid_response") }
          cursors[type] = last.id
        }
        let existing = Set(rows.map(\.rowID))
        rows.append(contentsOf: page.filter { !existing.contains($0.rowID) })
      }
    } catch {
      if version == model.generation {
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
