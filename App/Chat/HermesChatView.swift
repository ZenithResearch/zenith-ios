import SwiftUI
import UniformTypeIdentifiers
import ZenithKit

struct HermesChatView: View {
  @EnvironmentObject private var wallet: WalletModel
  @EnvironmentObject private var network: PrivateNetworkModel
  @StateObject private var chat = HermesChatModel()
  @State private var text = ""
  @State private var settings = false
  @State private var confirmNew = false
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if chat.connection == nil {
          ContentUnavailableView {
            Label("Chat with Hermes", systemImage: "bubble.left.and.bubble.right")
          } description: {
            Text("Connect your personal Hermes gateway to start a conversation.")
          } actions: {
            Button("Connect gateway") { settings = true }.buttonStyle(.borderedProminent)
          }
        } else if network.phase != .connected {
          Form {
            Section {
              PrivateNetworkRow(
                explanation:
                  "Connect to the same Tailscale network as your Hermes gateway. Work and Chat share this private connection."
              )
            }
          }
        } else {
          ScrollViewReader { scroll in
            ScrollView {
              LazyVStack(alignment: .leading, spacing: 18) {
                if chat.messages.isEmpty {
                  Text(chat.busy ? "Connecting to Hermes…" : "Start a conversation")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                }
                ForEach(chat.messages) { message in
                  VStack(alignment: .leading, spacing: 6) {
                    Text(message.role == "user" ? "You" : "Hermes").font(.caption.weight(.semibold))
                      .foregroundStyle(.secondary)
                    Text(message.text).textSelection(.enabled)
                  }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                      message.role == "user"
                        ? Color.accentColor.opacity(0.12)
                        : Color(uiColor: .secondarySystemBackground),
                      in: RoundedRectangle(cornerRadius: 14)
                    )
                    .id(message.id)
                }
                if chat.busy {
                  ProgressView(chat.waitingForReply ? "Hermes is working…" : "Connecting…").padding(
                    .vertical)
                }
                if chat.waitingForReply && !chat.busy {
                  Text(
                    "A reply may still be running on your Mac. Refresh to check it; your message won’t be sent again."
                  ).font(.footnote).foregroundStyle(.secondary)
                  Button("Refresh conversation") { chat.load(network: network) }
                }
                if let error = chat.error {
                  Text(error).foregroundStyle(.red).font(.footnote)
                  if !chat.busy && !chat.waitingForReply {
                    Button("Reconnect") { chat.load(network: network) }
                  }
                }
              }.padding()
            }.refreshable { chat.load(network: network) }
              .onChange(of: chat.messages.last?.id) { _, id in
                if let id { withAnimation { scroll.scrollTo(id, anchor: .bottom) } }
              }
          }
          HStack(alignment: .bottom, spacing: 12) {
            TextField("Message Hermes", text: $text, axis: .vertical).lineLimit(1...6)
              .textFieldStyle(.roundedBorder).accessibilityIdentifier("chat.message")
            Button {
              let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
              text = ""
              chat.send(value, network: network)
            } label: {
              Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .accessibilityLabel("Send message")
            .disabled(
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.busy
                || chat.waitingForReply || !chat.ready)
          }.padding().background(.bar)
        }
      }.navigationTitle("Chat")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Connection", systemImage: "network") { settings = true }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("New chat", systemImage: "square.and.pencil") {
              if chat.waitingForReply { confirmNew = true } else { chat.newChat() }
            }.disabled(chat.busy || chat.connection == nil)
          }
        }
        .sheet(isPresented: $settings) {
          NavigationStack {
            HermesChatSetupView(chat: chat) { settings = false }
              .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { settings = false } }
              }
          }
        }
        .confirmationDialog(
          "Start a new conversation?", isPresented: $confirmNew, titleVisibility: .visible
        ) {
          Button("Start new chat") { chat.newChat() }
        } message: {
          Text(
            "This does not stop a message Hermes is already processing. The previous conversation remains on your gateway."
          )
        }
        .task(id: wallet.generation) {
          chat.suspend(); text = ""
          if network.phase == .connected { chat.load(network: network) }
        }
        .onChange(of: network.phase) { _, phase in
          if phase == .connected { chat.load(network: network) }
        }
        .onChange(of: network.generation) { _, _ in
          chat.suspend()
          text = ""
        }
        .onDisappear {
          chat.suspend()
          text = ""
        }
    }
  }
}

private struct HermesChatSetupView: View {
  @ObservedObject var chat: HermesChatModel
  let connected: () -> Void
  @EnvironmentObject private var network: PrivateNetworkModel
  @State private var name = "Hermes"
  @State private var address = ""
  @State private var key = ""
  @State private var importing = false
  @State private var error: String?
  var body: some View {
    Form {
      Section {
        Text("Your personal Hermes gateway").font(.headline)
        Text("Use the private HTTPS address and connection key from the Mac running Hermes.")
        Button("Choose connection file", systemImage: "doc.badge.plus") { importing = true }
        TextField("Name", text: $name)
        TextField("HTTPS gateway address", text: $address).keyboardType(.URL)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
        SecureField("Gateway connection key", text: $key).textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        if chat.connection != nil {
          Text("Leave the key empty to keep it for the same gateway address.").font(.footnote)
            .foregroundStyle(.secondary)
        }
      } footer: {
        Text(
          "The gateway key stays in this iPhone’s Keychain. Chat history lives on your Hermes gateway. Your Wallet recovery file does not include this connection."
        )
      }
      Section {
        PrivateNetworkRow(
          explanation:
            "Connect to the same Tailscale network as your Mac. The gateway key authenticates Chat separately from Work access."
        )
      }
      Section {
        Button("Connect to Hermes") {
          let value = key
          key = ""
          chat.connect(
            name: name, address: address, key: value, network: network, completion: connected)
        }.buttonStyle(.borderedProminent).disabled(chat.busy || network.phase != .connected)
        if chat.busy { ProgressView("Checking gateway…") }
        if let error = error ?? chat.error { Text(error).foregroundStyle(.red) }
      }
      if chat.connection != nil {
        Section {
          Button("Remove chat connection", role: .destructive) {
            chat.remove()
            connected()
          }
        } footer: {
          Text(
            "Removes the saved key and conversation reference from this iPhone. Server conversations remain on your Mac."
          )
        }
      }
    }.navigationTitle("Chat connection").navigationBarTitleDisplayMode(.inline)
      .onAppear {
        if let connection = chat.connection {
          name = connection.name
          address = connection.receiver.absoluteString
        }
      }
      .onDisappear { key = "" }
      .fileImporter(
        isPresented: $importing, allowedContentTypes: [.json, .data], allowsMultipleSelection: false
      ) { result in
        do {
          guard let url = try result.get().first else { return }
          let scoped = url.startAccessingSecurityScopedResource()
          defer { if scoped { url.stopAccessingSecurityScopedResource() } }
          let file = try FileHandle(forReadingFrom: url)
          defer { try? file.close() }
          let value = try HermesChatSettings.importFile(file.read(upToCount: 8193) ?? Data())
          name = value.connection.name
          address = value.connection.receiver.absoluteString
          key = value.key
          error = nil
        } catch { self.error = "Choose the private Hermes connection file supplied by your Mac." }
      }
  }
}
