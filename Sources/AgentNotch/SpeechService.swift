import AVFoundation
import Foundation
import Speech

enum LocalSpeechError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case unsupportedLocale(String)
    case unavailable
    case noAudioFormat
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "Activa el micrófono para Agent Notch en Privacidad y seguridad."
        case .speechDenied: return "Activa Reconocimiento de voz para Agent Notch."
        case .unsupportedLocale(let locale): return "SpeechAnalyzer no soporta todavía \(locale)."
        case .unavailable: return "SpeechAnalyzer no está disponible en este Mac."
        case .noAudioFormat: return "No se pudo preparar el formato del micrófono."
        case .alreadyRunning: return "Ya hay una transcripción activa."
        }
    }
}

@MainActor
final class SpeechService {
    var onPartialText: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Error>?
    private var resultsTask: Task<Void, Error>?
    private var finalizedSegments: [String] = []
    private var volatileSegment = ""
    private(set) var isRunning = false

    func start(localeIdentifier: String) async throws {
        guard !isRunning else { throw LocalSpeechError.alreadyRunning }
        guard SpeechTranscriber.isAvailable else { throw LocalSpeechError.unavailable }
        guard await requestMicrophonePermission() else { throw LocalSpeechError.microphoneDenied }
        guard await requestSpeechPermission() else { throw LocalSpeechError.speechDenied }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeIdentifier)) else {
            throw LocalSpeechError.unsupportedLocale(localeIdentifier)
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: inputFormat
        ) else {
            throw LocalSpeechError.noAudioFormat
        }

        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.analyzer = analyzer
        self.continuation = continuation
        finalizedSegments = []
        volatileSegment = ""

        resultsTask = Task { [weak self] in
            for try await result in transcriber.results {
                guard let self else { return }
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if result.isFinal {
                    finalizedSegments.append(text)
                    volatileSegment = ""
                } else {
                    volatileSegment = text
                }
                onPartialText?(composedTranscript)
            }
        }

        analysisTask = Task {
            try await analyzer.start(inputSequence: stream)
        }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1_024, format: analyzerFormat) { buffer, _ in
            guard let copy = Self.copyBuffer(buffer) else { return }
            continuation.yield(AnalyzerInput(buffer: copy))
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() async throws -> String {
        guard isRunning else { return composedTranscript }
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()

        if let analyzer {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        _ = try? await analysisTask?.value
        _ = try? await resultsTask?.value

        let transcript = composedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanup()
        return transcript
    }

    func cancel() async {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        continuation?.finish()
        await analyzer?.cancelAndFinishNow()
        analysisTask?.cancel()
        resultsTask?.cancel()
        isRunning = false
        cleanup()
    }

    private var composedTranscript: String {
        (finalizedSegments + (volatileSegment.isEmpty ? [] : [volatileSegment])).joined(separator: " ")
    }

    private func cleanup() {
        analyzer = nil
        continuation = nil
        analysisTask = nil
        resultsTask = nil
        finalizedSegments = []
        volatileSegment = ""
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
        @unknown default: return false
        }
    }

    private func requestSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        @unknown default: return false
        }
    }

    private nonisolated static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameCapacity) else {
            return nil
        }
        copy.frameLength = source.frameLength
        let sourceList = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationList = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (sourceBuffer, destinationBuffer) in zip(sourceList, destinationList) {
            guard let sourceData = sourceBuffer.mData, let destinationData = destinationBuffer.mData else { continue }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
        }
        return copy
    }
}
