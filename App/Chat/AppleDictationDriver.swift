import AVFoundation
import Foundation
import Speech
import UIKit
import ZenithKit

/// On-device speech only. No audio files, uploads, background recording or logs.
actor AppleDictationDriver: DictationDriver {
  private var engine: AVAudioEngine?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var recognizer: SFSpeechRecognizer?
  private var recognition: SFSpeechRecognitionTask?
  private var observers: [NSObjectProtocol] = []
  private var hasTap = false
  private var audioActive = false

  func authorize() async throws {
    let recognizer = try localRecognizer()
    guard recognizer.isAvailable else { throw DictationError.unavailable }
    let status = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
    }
    try Task.checkCancellation()
    guard status == .authorized else { throw DictationError.speechPermission }
    guard await AVAudioApplication.requestRecordPermission() else {
      throw DictationError.microphonePermission
    }
    try Task.checkCancellation()
  }

  func start(receive: @escaping @Sendable (DictationEvent) -> Void) async throws {
    guard engine == nil else { throw DictationError.unavailable }
    guard await MainActor.run(body: { UIApplication.shared.applicationState == .active }) else {
      throw DictationError.interrupted
    }
    try Task.checkCancellation()
    let recognizer = try localRecognizer()
    guard recognizer.isAvailable else { throw DictationError.unavailable }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .measurement)
      try session.setActive(true)
      audioActive = true
      let engine = AVAudioEngine()
      self.engine = engine
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else { throw DictationError.unavailable }
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.requiresOnDeviceRecognition = true
      request.shouldReportPartialResults = true
      request.taskHint = .dictation
      request.addsPunctuation = true
      self.request = request
      self.recognizer = recognizer
      recognition = recognizer.recognitionTask(with: request) { result, error in
        if let result {
          receive(.transcription(result.bestTranscription.formattedString, isFinal: result.isFinal))
          if result.isFinal { return }
        }
        if error != nil { receive(.failed(.unavailable)) }
      }
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      hasTap = true
      engine.prepare()
      try engine.start()
      let center = NotificationCenter.default
      observers = [
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: nil) { _ in
          receive(.failed(.interrupted))
        },
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: nil) { _ in
          receive(.failed(.interrupted))
        },
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { _ in
          receive(.failed(.interrupted))
        },
      ]
    } catch {
      await cancel()
      throw DictationError.unavailable
    }
  }

  func finishAudio() async {
    removeObservers()
    stopMicrophone()
    request?.endAudio()
  }

  func cancel() async {
    removeObservers()
    stopMicrophone()
    request?.endAudio()
    recognition?.cancel()
    recognition = nil
    request = nil
    recognizer = nil
    engine = nil
  }

  private func removeObservers() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
  }

  private func stopMicrophone() {
    engine?.stop()
    if hasTap { engine?.inputNode.removeTap(onBus: 0); hasTap = false }
    if audioActive {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      audioActive = false
    }
  }

  private func localRecognizer() throws -> SFSpeechRecognizer {
    guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
      recognizer.supportsOnDeviceRecognition else { throw DictationError.unsupportedLanguage }
    return recognizer
  }
}
