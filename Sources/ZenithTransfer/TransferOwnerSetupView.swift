#if os(macOS)
import SwiftUI
import ZenithKit

@MainActor final class OwnerSetupModel: ObservableObject {
  let resource: LocalResource
  @Published var inspection: OwnerSetupInspection?
  @Published var nodes: [String: [OwnerScopeNode]] = [:]
  @Published var cursors: [String: String] = [:]
  @Published var expanded: Set<String> = []
  @Published var selected: [OwnerScopeNode] = []
  @Published var loading: Set<String> = []
  @Published var error: String?
  @Published var endpoint = "https://127.0.0.1:18443"
  @Published var preset: OwnerPermissionPreset = .reader
  @Published var operations: Set<String> = []
  @Published var reads = Set(CredentialPresetRevision.allReads)
  @Published var recipe: CredentialPresetRevision?
  func apply(_ value: CredentialPresetRevision) {
    recipe = value; preset = .custom; reads = Set(value.readOperations); operations = Set(value.writeOperations)
    review = nil; saved = nil
  }
  func changedPermissions() {
    preset = .custom; review = nil; saved = nil
    if let recipe, Set(recipe.readOperations) != reads || Set(recipe.writeOperations) != operations { self.recipe = nil }
  }
  @Published var scope = "unselected"
  @Published var untilRevoked = true
  @Published var expiry = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
  @Published var publishHierarchy = false
  @Published var review: OwnerSetupPlan?
  @Published var saved: OwnerSetupPlan?
  private let inspector = OwnerSetupInspector()
  private let store: OwnerSetupStore?
  private var expected: OwnerSetupPlan?
  init(resource: LocalResource) {
    self.resource = resource
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    store = try? OwnerSetupStore(directory: base.appendingPathComponent("ZenithTransfer/OwnerSetups"))
  }
  func refresh() async {
    review = nil; saved = nil; inspection = nil; selected = []; nodes = [:]; cursors = [:]; expanded = []
    do {
      inspection = try await inspector.inspect(resource)
      expected = try store?.load(resourceID: resource.id)
      if let old = expected {
        endpoint = old.walletEndpoint; preset = old.preset; operations = Set(old.writeOperations)
        reads = Set(old.effectiveReads); recipe = old.presetSnapshot
        scope = old.scopeMode; untilRevoked = old.notAfter == nil
        expiry = old.notAfter.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? expiry
        publishHierarchy = old.publishHierarchy
        // Restore the user's draft, not a claim of current granted authority.
        selected = old.paths
      }
      await load(nil)
    } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "The configured local DevGraph could not be read." }
  }
  func load(_ parent: OwnerScopeNode?, more: Bool = false) async {
    let key = parent?.id ?? "root"
    guard !loading.contains(key) else { return }; loading.insert(key); defer { loading.remove(key) }
    do {
      let page = try await inspector.page(parent: parent, after: more ? cursors[key] : nil)
      let items = (more ? nodes[key] ?? [] : []) + page.nodes
      guard items.count <= 2000 else { throw OwnerSetupError.unavailable }
      nodes[key] = items; cursors[key] = page.after
    } catch { self.error = "Could not load this hierarchy page. Retry before selecting its children." }
  }
  func toggleExpanded(_ node: OwnerScopeNode) {
    if expanded.contains(node.id) { expanded.remove(node.id) }
    else { expanded.insert(node.id); if nodes[node.id] == nil { Task { await load(node) } } }
  }
  func inherited(_ node: OwnerScopeNode) -> Bool { selected.contains { $0.id != node.id && node.path.starts(with: $0.path) } }
  func choose(_ node: OwnerScopeNode, _ value: Bool) {
    review = nil; saved = nil
    if value { selected = OwnerSetupPlan.normalized(selected.filter { $0.id != node.id } + [node]) }
    else { selected.removeAll { $0.id == node.id } }
  }
  func prepare(wallet: WalletState?) {
    do {
      guard wallet?.unlocked == true, let publicKey = wallet?.publicKey else { throw OwnerSetupError.walletLocked }
      guard let inspection else { throw OwnerSetupError.unavailable }
      let writes = OwnerPermissionPreset.allOperations.filter { operations.contains($0) }
      review = try OwnerSetupPlan(resource: resource, registrationSHA256: inspection.registrationSHA256,
        configurationSHA256: inspection.configurationSHA256, ownerPublicKey: publicKey,
        walletEndpoint: endpoint, preset: preset, writeOperations: writes, global: scope == "global",
        paths: scope == "global" ? [] : selected, notBefore: UInt64(Date().timeIntervalSince1970),
        notAfter: untilRevoked ? nil : UInt64(max(0, expiry.timeIntervalSince1970)), publishHierarchy: publishHierarchy,
        readOperations: CredentialPresetRevision.allReads.filter { reads.contains($0) }, presetSnapshot: recipe)
    } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Review the owner setup settings." }
  }
  func save(repository: WalletRepository?) async {
    do {
      guard let plan = review, let repository else { throw OwnerSetupError.walletLocked }
      let wallet = try await repository.state()
      guard wallet.unlocked, wallet.publicKey == plan.ownerPublicKey else { throw OwnerSetupError.walletLocked }
      let current = try await inspector.inspect(resource)
      guard current.registrationSHA256 == plan.registrationSHA256,
        current.configurationSHA256 == plan.configurationSHA256, let store else { throw OwnerSetupError.changed }
      let currentWallet = try await repository.state()
      guard currentWallet.unlocked, currentWallet.publicKey == plan.ownerPublicKey, review == plan else { throw OwnerSetupError.walletLocked }
      try store.save(plan, replacing: expected); expected = plan; saved = plan; review = nil
    } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "The setup could not be saved. Existing files are preserved." }
  }
}

struct TransferOwnerSetupView: View {
  @StateObject private var setup: OwnerSetupModel
  @ObservedObject var walletModel: TransferModel
  @ObservedObject private var library: TransferPresetLibrary
  @State private var creatingPreset = false
  @State private var unlocking = false
  @Environment(\.dismiss) private var dismiss
  init(resource: LocalResource, walletModel: TransferModel) {
    self.walletModel = walletModel; self.library = walletModel.presetLibrary; _setup = StateObject(wrappedValue: OwnerSetupModel(resource: resource))
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Set up DevGraph in Transfer").font(.title2.bold())
          Text(setup.resource.name + " · " + setup.resource.endpoint).foregroundStyle(.secondary)
        }
        Spacer()
        Button(walletModel.wallet?.unlocked == true ? "Wallet" : "Unlock Wallet") { unlocking = true }
        Button("Close setup") { dismiss() }
      }.padding(20)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if let saved = setup.saved {
            Label("Owner setup plan saved", systemImage: "checkmark.circle.fill").font(.title2.bold())
            Text("Your choices are saved for this DevGraph. They have not been installed: no owner authority, member grant or HTTPS listener is active from this plan.")
            summary(saved)
            Text("Next: prepare the exact server installation from this plan, review its certificate and authority changes, then activate it. The production graph stays unchanged until that approval.").foregroundStyle(.secondary)
            Button("Continue editing") { setup.saved = nil }
          } else if let plan = setup.review {
            Text("Review owner setup").font(.title2.bold())
            summary(plan)
            Text("This saves a setup plan on this Mac. It does not activate credentials, start a listener or change your production graph.").foregroundStyle(.secondary)
            HStack {
              Button("Edit settings") { setup.review = nil }
              Spacer()
              Button("Save setup plan") { Task { await setup.save(repository: walletModel.repository) } }
                .buttonStyle(.borderedProminent).disabled(walletModel.wallet?.unlocked != true)
            }
          } else {
            section("1. Your graph and owner Wallet") {
              Label(setup.inspection?.healthy == true ? "Configured DevGraph verified" : "Checking local DevGraph…", systemImage: setup.inspection == nil ? "clock" : "checkmark.shield")
              Text("This setup targets your configured graph. Saved test connections stay separate.").foregroundStyle(.secondary)
              if let key = walletModel.wallet?.publicKey {
                Text("Owner Wallet").font(.headline)
                Text(key).font(.caption.monospaced()).textSelection(.enabled)
              }
              Text(walletModel.wallet?.unlocked == true ? "Use this Wallet to administer access after the setup is approved." : "Unlock your Transfer Wallet here to bind the reviewed setup to its identity.").foregroundStyle(.secondary)
              Text("Owner administration manages member grants. It does not automatically give this Wallet permission to edit Work.").font(.callout)
            }
            section("2. Permissions the owner may grant") {
              HStack {
                Picker("Permission recipe", selection: Binding(get: { setup.recipe?.id ?? "custom" }, set: { id in
                  if let value = library.available.first(where: { $0.id == id }) { setup.apply(value) }
                  else { setup.recipe = nil; setup.preset = .custom }
                })) {
                  Text("Custom permissions").tag("custom")
                  ForEach(library.available) { Text($0.name + " · r\($0.revision)").tag($0.id) }
                  if let recipe = setup.recipe, !library.available.contains(where: { $0.id == recipe.id }) {
                    Text(recipe.name + " · pinned r\(recipe.revision)").tag(recipe.id)
                  }
                }
                Button("Create preset") { creatingPreset = true }
              }
              if let recipe = setup.recipe {
                Text("Using \(recipe.name), revision \(recipe.revision). Later preset edits will not change this selection.").font(.caption).foregroundStyle(.secondary)
                if let seat = recipe.seat { Text("Seat type: " + seat.label + " · descriptive association").font(.caption) }
              }
              TransferPermissionEditor(reads: $setup.reads, writes: $setup.operations)
                .onChange(of: setup.reads) { _ in setup.changedPermissions() }
                .onChange(of: setup.operations) { _ in setup.changedPermissions() }
              Text("This is the ceiling for grants you issue. Individual member grants can be narrower. Access administration, proposal acceptance and separate evidence permissions are not part of these Work presets.").font(.callout).foregroundStyle(.secondary)
            }
            section("3. Where those permissions apply") {
              Picker("Resource scope", selection: $setup.scope) {
                Text("Choose a scope…").tag("unselected")
                Text("Entire graph").tag("global")
                Text("Selected Arenas, Initiatives or Projects").tag("paths")
              }
              if setup.scope == "global" {
                Label("All supported Work in this graph, including future resources", systemImage: "globe")
              } else if setup.scope == "paths" {
                Text("Select one or more branches. Everything below the last selected container is included when access is checked.").foregroundStyle(.secondary)
                scopeRows(parent: nil, depth: 0)
                Text("\(setup.selected.count) selected branches · current and future descendants · moved-out work loses access").font(.caption).foregroundStyle(.secondary)
              }
            }
            section("4. Duration and connection") {
              Toggle("Allow grants that remain valid until revoked", isOn: $setup.untilRevoked)
              if !setup.untilRevoked { DatePicker("Maximum grant expiry", selection: $setup.expiry, in: Date()...) }
              TextField("Local HTTPS Wallet address", text: $setup.endpoint)
              Text("Use HTTPS on this Mac or its private LAN address with a separate port, for example https://127.0.0.1:18443. This does not expose the private API or database.").font(.caption).foregroundStyle(.secondary)
              Toggle("Publish scope names for access requests", isOn: $setup.publishHierarchy)
              Text("When enabled, clients may discover Arena, Initiative and Project names to request a scope. Work details still require an approved grant.").font(.caption).foregroundStyle(.secondary)
              Text("Read credentials and approval challenges may expire sooner than a standing grant. A new operator approval is not required merely to redeem another read credential.").font(.callout).foregroundStyle(.secondary)
            }
          }
        }.padding(24).frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
      }
      if setup.saved == nil && setup.review == nil {
        Divider()
        HStack {
          Button("Reload local graph") { Task { await setup.refresh() } }
          Spacer()
          Text("No authority changes until activation").font(.caption).foregroundStyle(.secondary)
          Button("Review owner setup") { setup.prepare(wallet: walletModel.wallet) }
            .buttonStyle(.borderedProminent).disabled(setup.inspection == nil || setup.scope == "unselected")
        }.padding(16)
      }
    }.frame(minWidth: 900, minHeight: 700)
      .task { await setup.refresh() }
      .onChange(of: walletModel.wallet?.unlocked) { _ in setup.review = nil }
      .sheet(isPresented: $creatingPreset) { TransferPresetEditor(library: library, source: nil, duplicate: false) }
      .sheet(isPresented: $unlocking) {
        VStack(spacing: 0) {
          HStack { Text("Castalia Wallet").font(.headline); Spacer(); Button("Return to owner setup") { unlocking = false } }.padding()
          Divider(); TransferWalletView(model: walletModel)
        }.frame(width: 720, height: 660)
      }
      .alert("Owner setup needs attention", isPresented: Binding(get: { setup.error != nil }, set: { if !$0 { setup.error = nil } })) { Button("OK") { setup.error = nil } } message: { Text(setup.error ?? "") }
  }
  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content() }
      .padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.primary.opacity(0.035)).cornerRadius(12)
  }
  private func scopeRows(parent: OwnerScopeNode?, depth: Int) -> AnyView {
    let key = parent?.id ?? "root"
    return AnyView(VStack(alignment: .leading, spacing: 10) {
      ForEach(setup.nodes[key] ?? []) { node in
        HStack(spacing: 8) {
          if node.expandable {
            Button { setup.toggleExpanded(node) } label: { Image(systemName: setup.expanded.contains(node.id) ? "chevron.down" : "chevron.right").frame(width: 14) }
              .buttonStyle(.plain).accessibilityLabel("Show children of \(node.title)")
          } else { Color.clear.frame(width: 14, height: 14) }
          Toggle(isOn: Binding(get: { setup.selected.contains { $0.id == node.id } || setup.inherited(node) }, set: { setup.choose(node, $0) })) {
            VStack(alignment: .leading, spacing: 3) {
              Text(node.title)
              Text(node.kind + (setup.inherited(node) ? " · Included by selected parent" : " · Includes descendants")).font(.caption).foregroundStyle(.secondary)
            }
          }.disabled(setup.inherited(node))
        }.padding(.leading, CGFloat(depth * 22))
        if setup.expanded.contains(node.id) { scopeRows(parent: node, depth: depth + 1) }
      }
      if setup.loading.contains(key) { ProgressView().controlSize(.small) }
      else if setup.cursors[key] != nil { Button("Load more \(parent?.title ?? "Arenas")") { Task { await setup.load(parent, more: true) } } }
      else if setup.nodes[key]?.isEmpty == true { Text("No selectable containers here").font(.caption).foregroundStyle(.secondary).padding(.leading, CGFloat(depth * 22)) }
    })
  }
  private func summary(_ plan: OwnerSetupPlan) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(plan.resourceName).font(.headline)
      Text("Local graph: \(plan.localEndpoint)\nWallet endpoint: \(plan.walletEndpoint)").textSelection(.enabled)
      Text("Owner Wallet: \(plan.ownerPublicKey)").font(.caption.monospaced()).textSelection(.enabled)
      Text("May grant: \(plan.presetSnapshot?.name ?? plan.preset.title)")
      if let recipe = plan.presetSnapshot { Text("Pinned preset revision: \(recipe.revision) · \(recipe.digest)").font(.caption.monospaced()) }
      Text("Read: " + (plan.effectiveReads.isEmpty ? "None" : plan.effectiveReads.joined(separator: ", ")))
      ForEach(plan.writeOperations, id: \.self) { Text(OwnerPermissionPreset.title($0)) }
      if plan.scopeMode == "global" { Text("Scope: entire graph") }
      else { ForEach(plan.paths) { node in VStack(alignment: .leading) { Text(node.title).bold(); Text(node.path.joined(separator: " → ")).font(.caption).textSelection(.enabled) } } }
      Text(plan.notAfter.map { "Maximum expiry: " + Date(timeIntervalSince1970: TimeInterval($0)).formatted() } ?? "Grant ceiling: until revoked")
      Text(plan.publishHierarchy ? "Scope names may be published for requests" : "Scope names stay unpublished")
      DisclosureGroup("Verification details") { Text("Resource: \(plan.resourceID)\nSetup digest: \(plan.digest)").font(.caption.monospaced()).textSelection(.enabled) }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035)).cornerRadius(12)
  }
}
#endif
