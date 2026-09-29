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
        case .microphoneDenied: return tr("Enable the microphone for Agent Notch in Privacy & Security.")
        case .speechDenied: return tr("Enable Speech Recognition for Agent Notch.")
        case .unsupportedLocale(let locale): return tr("SpeechAnalyzer doesn't support %@ yet.", locale)
        case .unavailable: return tr("SpeechAnalyzer isn't available on this Mac.")
        case .noAudioFormat: return tr("Couldn't prepare the microphone format.")
        case .alreadyRunning: return tr("A transcription is already running.")
        }
    }
}

@MainActor
protocol SpeechServing: AnyObject {
    var onPartialText: ((String) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }
    var isRunning: Bool { get }
    func start(localeIdentifier: String) async throws
    func stop() async throws -> String
    func cancel() async
}

/// One converter per capture session. The audio tap invokes it serially.
final class AudioBufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat
    init(from: AVAudioFormat, to: AVAudioFormat) throws {
        outputFormat = to
        if from == to { converter = nil }
        else {
            guard let converter = AVAudioConverter(from: from, to: to) else { throw LocalSpeechError.noAudioFormat }
            self.converter = converter
        }
    }
    func convert(_ input: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let converter else {
            guard let copy = SpeechService.copyBuffer(input) else { throw LocalSpeechError.noAudioFormat }
            return copy
        }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * outputFormat.sampleRate / input.format.sampleRate)) + 256
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw LocalSpeechError.noAudioFormat }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .noDataNow; return nil }
            supplied = true
            state.pointee = .haveData
            return input
        }
        if let error { throw error }
        guard status != .error else { throw LocalSpeechError.noAudioFormat }
        return output
    }
}

@MainActor
final class SpeechService: SpeechServing {
    var onPartialText: ((String) -> Void)?
    var onFailure: ((Error) -> Void)?

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Error>?
    private var resultsTask: Task<Void, Error>?
    private var finalizedSegments: [String] = []
    private var volatileSegment = ""
    private(set) var isRunning = false
    private var tapInstalled = false
    private var workerError: Error?
    private var sessionID = UUID()

    func start(localeIdentifier: String) async throws {
        guard !isRunning else { throw LocalSpeechError.alreadyRunning }
        do {
        try Task.checkCancellation()
        guard SpeechTranscriber.isAvailable else { throw LocalSpeechError.unavailable }
        guard await requestMicrophonePermission() else { throw LocalSpeechError.microphoneDenied }
        try Task.checkCancellation()
        guard await requestSpeechPermission() else { throw LocalSpeechError.speechDenied }
        try Task.checkCancellation()
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeIdentifier)) else {
            throw LocalSpeechError.unsupportedLocale(localeIdentifier)
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()

        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw LocalSpeechError.noAudioFormat }
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
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try Task.checkCancellation()
        let converter = try AudioBufferConverter(from: inputFormat, to: analyzerFormat)

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self, bufferingPolicy: .bufferingOldest(128))
        self.analyzer = analyzer
        self.continuation = continuation
        finalizedSegments = []
        volatileSegment = ""
        workerError = nil
        sessionID = UUID()
        let session = sessionID

        resultsTask = Task { [weak self] in
            do {
            for try await result in transcriber.results {
                guard let self, self.sessionID == session, !Task.isCancelled else { return }
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
            } catch {
                if !Task.isCancelled { self?.report(error, session: session) }
                throw error
            }
        }

        analysisTask = Task { [weak self] in
            do { try await analyzer.start(inputSequence: stream) }
            catch {
                if !Task.isCancelled { self?.report(error, session: session) }
                throw error
            }
        }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            do {
                let converted = try converter.convert(buffer)
                guard converted.frameLength > 0 else { return }
                if case .dropped = continuation.yield(AnalyzerInput(buffer: converted)) {
                    throw LocalSpeechError.noAudioFormat
                }
            } catch {
                Task { @MainActor in self?.report(error, session: session) }
            }
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
        isRunning = true
        } catch {
            await cancel()
            throw error
        }
    }

    func stop() async throws -> String {
        guard isRunning else { return composedTranscript }
        isRunning = false
        stopCapture()
        continuation?.finish()

        do {
        if let analyzer {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        _ = try await analysisTask?.value
        _ = try await resultsTask?.value
        if let workerError { throw workerError }

        let transcript = composedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanup()
        return transcript
        } catch {
            await cancel()
            throw error
        }
    }

    func cancel() async {
        sessionID = UUID()
        stopCapture()
        continuation?.finish()
        analysisTask?.cancel()
        resultsTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        isRunning = false
        cleanup()
    }

    private func stopCapture() {
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        engine.stop()
    }

    private func report(_ error: Error, session: UUID) {
        guard session == sessionID, workerError == nil else { return }
        workerError = error
        if isRunning { onFailure?(error) }
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
        workerError = nil
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

    nonisolated static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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
