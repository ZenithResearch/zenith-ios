import SwiftUI
import ZenithKit

struct WorkAccessRequestSection: View {
  let client: DevgraphReadClient
  let store: WorkAccessRequestStore
  @EnvironmentObject private var model: WalletModel
  @State private var consent: WorkAccessRequestConsent?
  @State private var result: WorkAccessRequestResult?
  @State private var catalog: WorkAccessCatalog?
  @State private var choosing = false
  @State private var presetID = ""
  @State private var paths: [WorkResourcePath] = []
  @State private var globalScope = true
  var body: some View {
    Section {
      if let consent {
        Text(consent.checkingStatus ? "Check your existing request" : "Ask this server’s operator for access").font(.headline)
        Text(consent.receiver).font(.footnote).textSelection(.enabled)
        if let preference = consent.preference {
          LabeledContent("Requested preset", value: preference.id ?? "Operator chooses")
          ForEach(preference.resource_paths ?? [], id: \.self) { Text($0.summary) }
          if preference.resource_paths?.isEmpty != false { Text("No path restriction requested · Operator chooses the exact scope") }
        }
        Text("Your Wallet sends proof of identity and this request. The operator chooses the permissions; this step grants no access.")
        LabeledContent("Approval expires",value:consent.approvalExpires.formatted())
        Button(consent.checkingStatus ? "Check request status" : "Send access request") {
          self.consent = nil
          model.perform({ _ in try await client.submitAccessRequest(consent) }) {
            result = $0; self.consent = nil; choosing = false
          }
        }.disabled(model.busy || Date() >= consent.approvalExpires)
        Button("Refresh this approval") { prepare(resubmit:!consent.checkingStatus) }.disabled(model.busy)
      } else if choosing {
        if let catalog {
          Text("Permissions · What can they do?").font(.headline)
          Text("Presets select operations; resource scope is chosen separately below.").font(.footnote)
          Picker("Access preset", selection: $presetID) {
            Text("No preset · Operator chooses").tag("")
            ForEach(catalog.presets) { Text($0.name).tag($0.id) }
          }
          if let preset = catalog.presets.first(where: { $0.id == presetID }) {
            Text("Requested permissions").font(.subheadline)
            Text((preset.read_operations.map { "Read: \($0)" } + preset.write_operations.map { $0.replacingOccurrences(of:"devgraph.work.",with:"").replacingOccurrences(of:".v2",with:"") }).joined(separator:" · ")).font(.footnote)
          }
          WorkRequestAreaPicker(scopes: catalog.scopes, paths: $paths, globalScope: $globalScope)
          Text("The operator can narrow this request. Paths apply to resources beneath them at each access, including new descendants; moved-out resources lose access.").font(.footnote)
          Button("Review access request") {
            do { let preference = try WorkAccessPreference(catalog:catalog,presetID:presetID.isEmpty ? nil:presetID,paths:globalScope ? [] : paths); prepare(preference:preference) }
            catch { model.error = "Choose an available preset and area, then try again." }
          }.disabled(model.busy || (!globalScope && paths.isEmpty))
        } else {
          Text("This server’s access choices could not be loaded. Retry, or send a general request so its operator can choose your permissions.")
          Button("Load server choices") { beginChoice() }.disabled(model.busy)
          Button("Review general access request") { prepare() }.disabled(model.busy)
        }
        Button("Cancel",role:.cancel) { choosing=false }.disabled(model.busy)
      } else {
        if let result {
          Text(status(result.status)).accessibilityAddTraits(.updatesFrequently)
          if result.status == "unknown" {
            Button("Resend the original access request") { prepare(resubmit:true) }.disabled(model.busy)
            Text("Uses the same request ID; it cannot create a second request.").font(.footnote)
          }
          if ["active","denied","expired","revoked","superseded","partially_active"].contains(result.status) {
            Button("Request different access") {
              model.perform({ _ in try await client.startNewAccessRequest(store:store,after:result) }) { _ in
                self.result=nil;catalog=nil;presetID="";paths=[];globalScope=true;beginChoice()
              }
            }.disabled(model.busy)
          }
        } else {
          Text("Choose a server preset and an area, or let its operator choose. You won’t need to paste a credential.")
        }
        Button(result == nil ? "Request or check access" : "Check request") { beginChoice() }.disabled(model.busy)
      }
    } header: { Text("Request access") } footer: { Text("An approved grant can be reused while valid. Choose Continue below to review exact read permissions in Wallet. Requesting access never grants it automatically.") }
    .onChange(of:model.generation) { _,_ in consent=nil;choosing=false;catalog=nil;result=nil;paths=[];globalScope=true;presetID="" }
  }
  private func beginChoice() {
    model.perform({ _ -> (Bool, WorkAccessCatalog?) in
      if try await client.hasAccessRequest(store:store) { return (true,nil) }
      return (false,try? await client.accessCatalog())
    }) { existing, available in
      if existing { prepare() } else { catalog=available;choosing=true }
    }
  }
  private func prepare(resubmit:Bool=false,preference:WorkAccessPreference?=nil) {
    model.perform({ _ in try await client.prepareAccessRequest(store:store,resubmitOriginal:resubmit,preference:preference) }) { consent=$0 }
  }
  private func status(_ value:String) -> String {
    switch value {
    case "pending": return "Request sent · Waiting for the server operator"
    case "active": return "Access approved · Continue below to review your read permissions"
    case "partially_active": return "Some access remains active · Check the server’s current permissions"
    case "approved", "approved_pending_activation": return "Request reviewed · The operator still needs to activate access"
    case "denied", "declined": return "Request declined · Contact the server operator"
    case "revoked": return "Access revoked · Contact the server operator"
    case "expired": return "Request expired · You can request new access"
    case "superseded": return "Access replaced by a newer grant"
    default: return "Request outcome unknown · Check again before resending"
    }
  }
}

struct WorkRequestAreaPicker: View {
  let scopes: [WorkScopeOption]
  @Binding var paths: [WorkResourcePath]
  @Binding var globalScope: Bool
  @State private var query = ""
  @State private var selectionError: String?
  private func filtered(_ nodes: [WorkScopeTreeNode]) -> [WorkScopeTreeNode] {
    guard !query.isEmpty else { return nodes }
    return nodes.compactMap { node in
      if (node.option.title + " " + node.option.resource).localizedCaseInsensitiveContains(query) { return node }
      let children = filtered(node.children ?? [])
      return children.isEmpty ? nil : WorkScopeTreeNode(option: node.option, children: children)
    }
  }
  var body: some View {
    Group {
      Text("Resources · Where can they do it?").font(.headline)
      Picker("Resource scope", selection: $globalScope) {
        Text("Global request").tag(true)
        Text("Selected areas").tag(false)
      }.pickerStyle(.segmented)
      if globalScope {
        Text("Request no path restriction. The operator still chooses and approves the exact scope within their policy. This grants no access by itself.").font(.footnote)
      } else {
        TextField("Find resources by title, kind or ID", text: $query)
        Text("Choose multiple Arenas, Initiatives or Projects. Selecting a container includes its current and future descendants. Clear a selected parent before narrowing an inherited branch.").font(.footnote)
        if scopes.isEmpty { Text("No resource hierarchy is published for selection.") }
        OutlineGroup(filtered(WorkScopeSelection.tree(scopes)), children: \.children) { node in
          let path = node.option.resource_path
          let inherited = paths.first { $0 != path && WorkScopeSelection.covers($0, path) }
          Toggle(isOn: Binding(get: { paths.contains(path) || inherited != nil }, set: { selected in
            do {
              paths = try WorkScopeSelection.normalized(selected ? paths + [path] : paths.filter { $0 != path })
              selectionError = nil
            } catch { selectionError = "Select up to 16 separate areas, or choose a shared parent." }
          })) {
            VStack(alignment: .leading, spacing: 3) {
              Text(node.option.title)
              Text(node.option.resource).font(.caption).foregroundStyle(.secondary)
              if let inherited { Text("Inherited from " + WorkScopeSelection.label(inherited, scopes: scopes)).font(.caption) }
              else { Text("Includes this \(node.option.kind) and its descendants").font(.caption).foregroundStyle(.secondary) }
            }
          }.toggleStyle(.button).disabled(inherited != nil)
        }
        if let selectionError { Text(selectionError).foregroundStyle(.red) }
        Text("Selected roots (\(paths.count)/16)").font(.subheadline)
        ForEach(paths, id: \.self) { path in
          HStack {
            Text(WorkScopeSelection.label(path, scopes: scopes)).font(.footnote)
            Spacer()
            Button("Remove", role: .destructive) { paths.removeAll { $0 == path } }
          }
        }
        if paths.isEmpty { Text("Choose at least one area to continue.").font(.footnote) }
      }
    }
  }
}
