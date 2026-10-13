import AVFoundation
import SwiftUI
import ZenithKit

struct TransferImportButtons: View {
  let receive: (Data) -> Void
  @State private var scanning = false
  @State private var usb = false
  var body: some View {
    Group {
      Button("Scan laptop QR", systemImage: "qrcode.viewfinder") { scanning = true }
        .frame(minHeight: 44)
        .sheet(isPresented: $scanning) { ScanTransferView(receive: receive) }
      Button("Use USB cable", systemImage: "cable.connector") { usb = true }
        .frame(minHeight: 44)
        .sheet(isPresented: $usb) { USBTransferView(receive: receive) }
    }
  }
}

struct USBTransferView: View {
  let receive: (Data) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var files: [URL] = []
  @State private var error: String?
  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Connect your iPhone to your laptop with a USB cable.")
          Text("On your Mac, open Finder → your iPhone → Files → Zenith. Drag your encrypted file into Zenith.")
          Text("On Windows, use Apple Devices → your iPhone → Files → Zenith.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Transferred files") {
          if files.isEmpty {
            Text("No files yet. Copy a file, then tap Refresh.").foregroundStyle(.secondary)
          }
          ForEach(files, id: \.self) { file in
            Button {
              do {
                let data = try EncryptedImportFile.read(file)
                receive(data)
                dismiss()
              } catch { self.error = error.localizedDescription }
            } label: {
              Label(file.lastPathComponent, systemImage: "doc").lineLimit(3)
                .frame(minHeight: 44, alignment: .leading)
            }
          }
          Button("Refresh", systemImage: "arrow.clockwise") { refresh() }.frame(minHeight: 44)
        }
        if let error { Section { Text(error).foregroundStyle(.red) } }
        Section {
          Text("Choosing a file does not import it yet. Next, enter its password and review your wallet.")
          Text("The transferred copy stays in Files → On My iPhone → Zenith. You can remove that copy after checking your import; keep your original backup safe.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }.navigationTitle("Import by USB")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .task { refresh() }
    }
  }
  private func refresh() {
    do {
      files = try USBImportInbox.files(in: USBImportInbox.directory())
      error = nil
    } catch { self.error = "Could not open the transfer folder. Try again." }
  }
}

struct ScanTransferView: View {
  let receive: (Data) -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scene
  @State private var assembler = RecoveryQRAssembler()
  @State private var received = 0
  @State private var total = 0
  @State private var error: String?
  @State private var scanning = true
  @State private var finished = false
  @State private var attempt = 0
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Open Zenith Transfer on your laptop and choose your encrypted file. Point this camera at its QR.")
          if scanning {
            TransferCamera(scan: accept, failure: { message in
              error = message
              scanning = false
            }).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 16))
              .accessibilityLabel("Camera scanning the laptop QR")
          }
          if total > 1 {
            ProgressView(value: Double(received), total: Double(total)) {
              Text("Read \(received) of \(total) parts")
            }
            Text("Keep the camera still while the laptop cycles through the parts.")
              .font(.subheadline).foregroundStyle(.secondary)
          }
          if let error { Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
          if !scanning {
            Button("Scan again") {
              assembler.reset()
              received = 0
              total = 0
              error = nil
              scanning = true
              attempt += 1
            }.buttonStyle(.borderedProminent)
          }
          Text("The QR carries the encrypted file. No Wi-Fi, Bluetooth or upload is needed. You’ll enter the file’s password after scanning.")
            .font(.footnote).foregroundStyle(.secondary)
        }.padding(24)
      }.navigationTitle("Scan laptop QR")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .task(id: attempt) {
          do {
            try await Task.sleep(nanoseconds: 180_000_000_000)
            assembler.reset()
            scanning = false
            error = "Scanning paused. Tap Scan again when your laptop is ready."
          } catch {}
        }
        .onChange(of: scene) { _, phase in
          if phase == .background { assembler.reset(); scanning = false; dismiss() }
        }
        .onDisappear { assembler.reset(); scanning = false }
    }
  }
  private func accept(_ raw: String) {
    guard !finished, scanning else { return }
    do {
      let progress = try assembler.accept(raw)
      received = progress.received
      total = progress.total
      error = nil
      if let file = progress.file {
        finished = true
        scanning = false
        receive(file)
        dismiss()
      }
    } catch {
      self.error = error.localizedDescription
      scanning = false
      assembler.reset()
    }
  }
}

private struct TransferCamera: UIViewRepresentable {
  let scan: (String) -> Void
  let failure: (String) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(scan: scan, failure: failure) }
  func makeUIView(context: Context) -> CameraSurface {
    let view = CameraSurface()
    view.preview.session = context.coordinator.session
    view.preview.videoGravity = .resizeAspectFill
    context.coordinator.start()
    return view
  }
  func updateUIView(_ uiView: CameraSurface, context: Context) {}
  static func dismantleUIView(_ uiView: CameraSurface, coordinator: Coordinator) { coordinator.stop() }

  final class CameraSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }
  final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ca.zenith.recovery-camera")
    private var stopped = false
    private var lastValue: String?
    private let scan: (String) -> Void
    private let failure: (String) -> Void
    init(scan: @escaping (String) -> Void, failure: @escaping (String) -> Void) {
      self.scan = scan
      self.failure = failure
    }
    func start() {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: configure()
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
          if allowed { self?.configure() } else { self?.fail("Allow camera access to scan a QR, or import with USB or Files.") }
        }
      default: fail("Camera access is off. Enable it in Settings → Zenith, or import with USB or Files.")
      }
    }
    private func configure() {
      queue.async { [self] in
        guard !stopped else { return }
        guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device)
        else { fail("A camera is unavailable. Use this scanner on your iPhone, or import with USB or Files."); return }
        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else {
          session.commitConfiguration()
          fail("The camera could not start. Try again or import with USB or Files.")
          return
        }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        session.startRunning()
      }
    }
    private func fail(_ message: String) { DispatchQueue.main.async { [weak self] in self?.failure(message) } }
    func stop() { queue.async { [self] in stopped = true; session.stopRunning() } }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
      guard let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
        let value = code.stringValue, value != lastValue else { return }
      lastValue = value
      scan(value)
    }
  }
}
