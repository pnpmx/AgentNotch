import AppKit
import Combine
import Foundation

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
    @Published var claudeBridgeReady = false
    @Published var notice: String?
    @Published var selectedLocale: String {
        didSet { UserDefaults.standard.set(selectedLocale, forKey: "speechLocale") }
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
    private let speechService = SpeechService()
    private let holdSpaceMonitor = HoldSpaceMonitor()
    private var refreshTask: Task<Void, Never>?
    private var isStartingSpeech = false
    private var speechPressHeld = false

    init() {
        selectedLocale = UserDefaults.standard.string(forKey: "speechLocale") ?? "es-ES"
    }

    func start() {
        speechService.onPartialText = { [weak self] text in
            self?.liveTranscript = text
        }
        holdSpaceMonitor.onLongPressBegan = { [weak self] in
            Task { @MainActor in
                self?.speechPressHeld = true
                await self?.beginSpeech()
            }
        }
        holdSpaceMonitor.onLongPressEnded = { [weak self] in
            Task { @MainActor in
                self?.speechPressHeld = false
                await self?.finishSpeech()
            }
        }
        holdSpaceMonitor.onAvailabilityChanged = { [weak self] available in
            self?.accessibilityReady = available
            if available { self?.notice = "Space to Speak activado." }
        }
        accessibilityReady = holdSpaceMonitor.install()
        if !accessibilityReady {
            // TCC can report the permission before the session event tap is
            // ready during login. Detect both that race and later permission
            // changes without requiring a second click in the UI.
            holdSpaceMonitor.monitorAccessibilityPermission()
        }
        claudeBridgeReady = ClaudeUsageProvider.isBridgeConfigured()

        Task { await refreshAll() }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await self?.refreshCachedClaude()
                if let self, Int(Date().timeIntervalSince1970) % 120 < 20 {
                    await self.refreshCodex()
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        holdSpaceMonitor.uninstall()
        Task { await speechService.cancel() }
    }

    func refreshAll() async {
        async let codex: Void = refreshCodex()
        async let claude: Void = refreshCachedClaude()
        _ = await (codex, claude)
    }

    func refreshCodex() async {
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
                ? "Abre Claude Code y envía un mensaje para obtener sus límites."
                : "Conecta el status line de Claude."
        }
    }

    func connectClaude() {
        do {
            try ClaudeUsageProvider.installBridge()
            claudeBridgeReady = true
            claudeError = "Envía un mensaje en Claude Code para cargar el primer dato."
            notice = "Claude Code conectado."
        } catch {
            notice = error.localizedDescription
        }
    }

    func requestAccessibility() {
        notice = "Activa Agent Notch en Accesibilidad; lo detectaré automáticamente."
        holdSpaceMonitor.requestAccessibilityPermission()
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    private func beginSpeech() async {
        guard speechState == .idle, !isStartingSpeech else { return }
        isStartingSpeech = true
        liveTranscript = ""
        speechState = .preparing
        do {
            try await speechService.start(localeIdentifier: selectedLocale)
            speechState = .listening
            isExpanded = true
            if !speechPressHeld { await finishSpeech() }
        } catch {
            speechState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
        isStartingSpeech = false
    }

    private func finishSpeech() async {
        guard speechService.isRunning else {
            if case .failed = speechState { return }
            speechState = .idle
            return
        }
        speechState = .transcribing
        do {
            let result = try await speechService.stop()
            liveTranscript = result
            if !result.isEmpty {
                TextInjector.paste(result)
                notice = "Texto insertado."
            }
            speechState = .idle
        } catch {
            speechState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }
}
