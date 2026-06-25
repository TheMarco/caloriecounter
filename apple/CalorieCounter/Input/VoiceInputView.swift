//
//  VoiceInputView.swift
//  Speak a food description → on-device speech recognition → on-device Foundation
//  Models parse → ParsedFood. Uses SFSpeechRecognizer with on-device recognition
//  (private, offline). Microphone/recognition are validated on device (Phase 11).
//

import SwiftUI
import Speech
import AVFoundation
import AppCore
import NutritionCore

struct VoiceInputView: View {
    @Environment(AppContainer.self) private var container
    let onParsed: (ParsedFood) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dictation = SpeechDictation()
    @State private var parsing = false
    @State private var errorInfo: CaptureErrorInfo?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Button {
                Task { await toggle() }
            } label: {
                Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.accentColor)
                    .symbolEffect(.variableColor, isActive: dictation.isRecording && !reduceMotion)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(parsing)
            .accessibilityLabel(dictation.isRecording ? "Stop recording" : "Start recording")

            Text(dictation.transcript.isEmpty ? "Tap the mic and say what you ate" : dictation.transcript)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(dictation.transcript.isEmpty ? .secondary : .primary)
                .padding(.horizontal)
                .frame(minHeight: 80)

            Spacer()

            if parsing {
                ProgressView("Analyzing…")
            } else {
                Button {
                    Task { await toggle() }
                } label: {
                    Label(dictation.isRecording ? "Stop & Analyze" : "Start Speaking",
                          systemImage: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 32)
        .navigationTitle("Speak Food")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let errorInfo {
                CaptureErrorCard(info: errorInfo,
                                 onRetry: { Task { await toggle() } },
                                 onDismiss: { self.errorInfo = nil })
            }
        }
        .onDisappear { dictation.stop() }
    }

    private func toggle() async {
        if dictation.isRecording {
            dictation.stop()
            await analyze()
        } else {
            do {
                try await dictation.start()
            } catch {
                // Distinguish "access is off" (fixable in Settings) from "not
                // available right now".
                if case SpeechDictation.DictationError.unauthorized = error {
                    errorInfo = .from(.microphonePermission)
                } else {
                    errorInfo = .from(.speechUnavailable)
                }
            }
        }
    }

    private func analyze() async {
        let text = dictation.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        parsing = true
        defer { parsing = false }
        do {
            onParsed(try await container.foodParser.parse(text: text, units: container.settings.units))
        } catch {
            errorInfo = .from(.classify(error, fallback: .unreadable))
        }
    }
}

/// SwiftUI-facing dictation state (`@MainActor` so `transcript`/`isRecording` are
/// observed safely). The audio + recognition machinery lives in a NON-isolated
/// `SpeechEngine` worker — critically so, because AVAudioEngine's tap and the
/// SFSpeechRecognitionTask handler fire on background/real-time threads. If those
/// callbacks were main-actor-isolated (which they would be if declared inside a
/// `@MainActor` type), the runtime asserts main-thread and crashes
/// (`_dispatch_assert_queue_fail`) the instant audio starts flowing. Transcript
/// updates cross back to the main actor through an `AsyncStream`.
@MainActor
@Observable
final class SpeechDictation {
    var transcript = ""
    var isRecording = false

    @ObservationIgnored private var engine: SpeechEngine?

    enum DictationError: Error { case unauthorized, unavailable }

    func start() async throws {
        guard await SpeechEngine.requestAuthorization() else { throw DictationError.unauthorized }

        let engine = SpeechEngine()
        self.engine = engine
        transcript = ""

        let stream: AsyncStream<String>
        do {
            stream = try engine.start()
        } catch {
            self.engine = nil
            throw DictationError.unavailable
        }

        isRecording = true
        // Consume partial transcripts on the main actor (this Task inherits it).
        Task { [weak self] in
            for await text in stream { self?.transcript = text }
            self?.isRecording = false
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        isRecording = false
    }
}

/// Non-isolated audio + recognition worker. Owns AVAudioEngine + the speech task;
/// emits partial transcripts via an `AsyncStream`. Nothing here touches main-actor
/// state, so the background tap/recognition callbacks are safe.
private final class SpeechEngine: @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    enum EngineError: Error { case unavailable }

    func start() throws -> AsyncStream<String> {
        guard let recognizer, recognizer.isAvailable else { throw EngineError.unavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)   // SFSpeechAudioBufferRecognitionRequest.append is thread-safe
        }

        let (stream, continuation) = AsyncStream<String>.makeStream()
        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                continuation.finish()
            }
        }
        continuation.onTermination = { [weak self] _ in self?.teardown() }

        audioEngine.prepare()
        try audioEngine.start()
        return stream
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        teardown()
    }

    private func teardown() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
