import AppKit
import Combine
import Foundation
import AVFoundation
import Speech

@MainActor
final class AppModel: ObservableObject {
    @Published var codexUsage: UsageSnapshot?
    @Published var claudeUsage: UsageSnapshot?
    @Published var codexError: String?
    @Published var claudeError: String?
    @Published var speechState: SpeechState = .idle
    @Published var liveTranscript = ""
    @Published var isExpanded = false
    @Published var accessibilityReady = false
    @Published var keyboardStatus = tr("Checking keyboard…")
    @Published var voicePermissionsReady = false
    @Published var claudeBridgeReady = false
    @Published var notice: String?
    @Published var selectedLocale: String {
        didSet { UserDefaults.standard.set(selectedLocale, forKey: "speechLocale") }
    }

    /// Interface language; independent of the dictation locale below.
    @Published var uiLanguage: UILanguage {
        didSet {
            UserDefaults.standard.set(uiLanguage.rawValue, forKey: UILanguage.defaultsKey)
            L10n.current = uiLanguage.resolved
            // Stored messages were rendered in the previous language.
            notice = nil
            holdSpaceMonitor.republishStatus()
            Task { await refreshAll() }
        }
    }

    let localeOptions: [(id: String, name: String)] = [
        ("es-ES", "Español"),
        ("en-US", "English"),
        ("it-IT", "Italiano"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch"),
        ("pt-BR", "Português")
    ]

    private let codexProvider = CodexUsageProvider()
    private let speechService: any SpeechServing
    private let holdSpaceMonitor = HoldSpaceMonitor()
    private var refreshTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var finishingSpeech = false
    private var targetPID: pid_t?
    private var refreshingCodex = false
    private var speechPressHeld = false

    init(speechService: (any SpeechServing)? = nil) {
        self.speechService = speechService ?? SpeechService()
        selectedLocale = UserDefaults.standard.string(forKey: "speechLocale") ?? "es-ES"
        uiLanguage = UILanguage.stored
        L10n.current = uiLanguage.resolved
        updateVoicePermissions()
    }

    func start() {
        speechService.onPartialText = { [weak self] text in
            self?.liveTranscript = text
        }
        holdSpaceMonitor.onLongPressBegan = { [weak self] in
            self?.beginSpeech()
        }
        holdSpaceMonitor.onLongPressEnded = { [weak self] in
            Task { @MainActor in
                self?.speechPressHeld = false
                await self?.finishSpeech()
            }
        }
        holdSpaceMonitor.onCancelled = { [weak self] in
            Task { @MainActor in await self?.cancelSpeech() }
        }
        holdSpaceMonitor.onStatus = { [weak self] status in
            guard self?.keyboardStatus != status else { return }
            self?.keyboardStatus = status
        }
        speechService.onFailure = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                await self.cancelSpeech()
                self.speechState = .failed(error.localizedDescription)
                self.notice = error.localizedDescription
            }
        }
        holdSpaceMonitor.onAvailabilityChanged = { [weak self] available in
            if self?.accessibilityReady != available { self?.accessibilityReady = available }
        }
        accessibilityReady = holdSpaceMonitor.install()
        holdSpaceMonitor.monitorAccessibilityPermission()
        claudeBridgeReady = ClaudeUsageProvider.isBridgeConfigured()

        refreshTask = Task { [weak self] in
            await self?.refreshAll()
            var tick = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(20)) } catch { break }
                await self?.refreshCachedClaude()
                self?.updateVoicePermissions()
                tick += 1
                if let self, tick % 6 == 0 {
                    await self.refreshCodex()
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        holdSpaceMonitor.uninstall()
        speechTask?.cancel()
        Task { await cancelSpeech() }
    }

    func refreshAll() async {
        async let codex: Void = refreshCodex()
        async let claude: Void = refreshCachedClaude()
        _ = await (codex, claude)
    }

    func refreshCodex() async {
        guard !refreshingCodex else { return }
        refreshingCodex = true
        defer { refreshingCodex = false }
        do {
            codexUsage = try await codexProvider.fetch()
            codexError = nil
        } catch {
            codexError = error.localizedDescription
        }
    }

    func refreshCachedClaude() async {
        do {
            claudeUsage = try ClaudeUsageProvider.load()
            claudeError = nil
        } catch {
            claudeError = claudeBridgeReady
                ? tr("Open Claude Code and send a message to get its limits.")
                : tr("Connect Claude's status line.")
        }
    }

    func connectClaude() {
        do {
            try ClaudeUsageProvider.installBridge()
            claudeBridgeReady = true
            claudeError = tr("Send a message in Claude Code to load the first reading.")
            notice = tr("Claude Code connected.")
        } catch {
            notice = error.localizedDescription
        }
    }

    func requestAccessibility() {
        holdSpaceMonitor.requestAccessibilityPermission()
        notice = keyboardStatus
        if !accessibilityReady {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func requestVoicePermissions() {
        Task {
            let microphone = await AVCaptureDevice.requestAccess(for: .audio)
            guard microphone else {
                notice = tr("Enable Agent Notch under Microphone and try again.")
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                return
            }
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            updateVoicePermissions()
            if speech { resetSpeechError(); notice = tr("Voice permissions granted.") }
            else {
                notice = tr("Enable Agent Notch under Speech Recognition.")
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
            }
        }
    }

    private func updateVoicePermissions() {
        let ready = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            && SFSpeechRecognizer.authorizationStatus() == .authorized
        if voicePermissionsReady != ready { voicePermissionsReady = ready }
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    func beginSpeech() {
        guard speechTask == nil, !finishingSpeech, !speechService.isRunning else { return }
        speechPressHeld = true
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        liveTranscript = ""
        speechState = .preparing
        notice = tr("Preparing voice; the first time may download the language. Release Space to cancel.")
        speechTask = Task {
            defer { speechTask = nil }
            do {
                try await speechService.start(localeIdentifier: selectedLocale)
                try Task.checkCancellation()
                guard speechPressHeld else { await speechService.cancel(); speechState = .idle; return }
                speechState = .listening
                notice = tr("Listening; release Space to finish.")
            } catch is CancellationError {
                await speechService.cancel()
                speechState = .idle
            } catch {
                await speechService.cancel()
                speechState = .failed(error.localizedDescription)
                notice = error.localizedDescription
            }
        }
    }

    func finishSpeech() async {
        speechPressHeld = false
        if speechTask != nil { await cancelSpeech(); return }
        guard speechService.isRunning, !finishingSpeech else { return }
        finishingSpeech = true
        defer { finishingSpeech = false }
        speechState = .transcribing
        do {
            let result = try await speechService.stop()
            liveTranscript = result
            if !result.isEmpty, let targetPID {
                switch TextInjector.paste(result, into: targetPID) {
                case .attempted: notice = tr("Paste requested. If text is missing, use Copy.")
                case .destinationChanged: notice = tr("The app changed. Text kept; use Copy.")
                case .unavailable: notice = tr("Couldn't paste. Text kept; use Copy.")
                }
            } else {
                notice = tr("No text detected. Hold Space to retry.")
            }
            speechState = .idle
        } catch {
            await speechService.cancel()
            speechState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    func cancelSpeech() async {
        speechPressHeld = false
        targetPID = nil
        if let task = speechTask { task.cancel(); await task.value }
        await speechService.cancel()
        speechState = .idle
        notice = tr("Dictation cancelled.")
    }

    func resetSpeechError() {
        if case .failed = speechState { speechState = .idle; notice = tr("Hold Space to retry.") }
    }

    func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(liveTranscript, forType: .string)
        notice = tr("Text copied.")
    }

    var keyboardDiagnostics: [String: Any] {
        ["tapAvailable": holdSpaceMonitor.isAvailable, "acceptedPresses": holdSpaceMonitor.acceptedPresses,
         "completedPresses": holdSpaceMonitor.completedPresses, "speechState": speechState.shortLabel]
    }
}
