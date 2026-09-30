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

    // Agent activity, limits and session
    @Published var agentEvents: [AgentEvent] = []
    @Published var limitAlerts: [LimitAlert] = []
    @Published var session: SessionInfo?
    @Published var projections: [String: Date] = [:]
    @Published var claudeConfig = AgentConfiguration()
    @Published var codexConfig = AgentConfiguration()
    @Published var history: [String] = []
    enum PanelTab { case sessions, limits, voice }
    @Published var panelTab: PanelTab = .limits
    @Published var sessions: [AgentSession] = []
    @Published var openSessionID: String?
    @Published var dropTargeted = false
    @Published var wrapped: WeekSummary?
    @Published var wrappedSavedURL: URL?
    @Published var settingsOpen = false

    @Published var limitAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(limitAlertsEnabled, forKey: "limitAlerts") }
    }
    @Published var agentAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(agentAlertsEnabled, forKey: "agentAlerts"); reloadAgentEvents() }
    }
    @Published var vocabulary: String {
        didSet { UserDefaults.standard.set(vocabulary, forKey: "vocabulary") }
    }
    @Published var autoEnter: Bool {
        didSet { UserDefaults.standard.set(autoEnter, forKey: "autoEnter") }
    }
    @Published var removeFillers: Bool {
        didSet { UserDefaults.standard.set(removeFillers, forKey: "removeFillers") }
    }

    private var limitTracker = LimitTracker()
    private var eventsSeen = Int64(Date().timeIntervalSince1970 * 1000)
    private var eventsModified: Date?
    private var eventTimer: Timer?
    private var sessionsModified: Date?
    private var remindedWaits: Set<String> = []
    private var knownDone: Set<String> = []
    private var lastEventKind: [Int64: AgentEvent.Kind] = [:]

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
        let defaults = UserDefaults.standard
        limitAlertsEnabled = defaults.object(forKey: "limitAlerts") as? Bool ?? true
        agentAlertsEnabled = defaults.object(forKey: "agentAlerts") as? Bool ?? true
        vocabulary = defaults.string(forKey: "vocabulary") ?? ""
        autoEnter = defaults.bool(forKey: "autoEnter")
        removeFillers = defaults.object(forKey: "removeFillers") as? Bool ?? true
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
        refreshAgentConfigs()
        eventsModified = Self.eventsFileDate()
        eventTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollAgentEvents() }
        }

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
        eventTimer?.invalidate()
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
            let snapshot = try await codexProvider.fetch()
            codexUsage = snapshot
            trackLimits(snapshot)
            codexError = nil
        } catch {
            codexError = error.localizedDescription
        }
    }

    func refreshCachedClaude() async {
        do {
            let snapshot = try ClaudeUsageProvider.load()
            if snapshot != claudeUsage { trackLimits(snapshot) }
            claudeUsage = snapshot
            claudeError = nil
        } catch {
            claudeError = claudeBridgeReady
                ? tr("Open Claude Code and send a message to get its limits.")
                : tr("Connect Claude's status line.")
        }
    }

    // MARK: Limits

    private func trackLimits(_ snapshot: UsageSnapshot) {
        let alerts = limitTracker.update(snapshot)
        for window in snapshot.windows { projections[window.id] = limitTracker.projection(for: window.id) }
        guard limitAlertsEnabled else { return }
        alerts.forEach(showLimitAlert)
    }

    private func showLimitAlert(_ alert: LimitAlert) {
        limitAlerts.removeAll { $0.id == alert.id }
        limitAlerts.append(alert)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            self?.limitAlerts.removeAll { $0 == alert }
        }
    }

    // MARK: Sessions, drop, Wrapped

    func copyToClipboard(_ text: String, notice message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = message
    }

    /// Brings the session's terminal tab (or at least its app) to the front.
    func jumpToTerminal(_ session: AgentSession) {
        markRead(session)
        guard let terminal = session.terminal else {
            notice = tr("This session's terminal is unknown. It is recorded from the next prompt.")
            return
        }
        switch TerminalLocator.jump(to: terminal) {
        case .tab: notice = nil
        case .app: notice = tr("Opened the terminal app; this terminal can't select the exact tab.")
        case .unavailable: notice = tr("That terminal is no longer open.")
        }
    }

    func handoff(_ session: AgentSession) {
        let other = session.source == "codex" ? "Claude" : "Codex"
        copyToClipboard(session.handoffPrompt, notice: tr("Handoff prompt copied. Paste it in %@.", other))
    }

    /// Files dropped on the notch are pasted, as paths, into the frontmost app
    /// (the panel never activates, so that is where you were typing).
    func pasteDroppedPaths(_ urls: [URL]) {
        let text = urls.map { $0.path.contains(" ") ? "\"\($0.path)\"" : $0.path }.joined(separator: " ")
        guard !text.isEmpty else { return }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let front, front != getpid(), TextInjector.paste(text, into: front) == .attempted {
            notice = tr("Path pasted where you were typing.")
        } else {
            copyToClipboard(text, notice: tr("Path copied. Paste it with Cmd+V."))
        }
    }

    func showWrapped() {
        wrappedSavedURL = nil
        wrapped = AgentStats.weekSummary(AgentStats.load(), today: Date())
    }

    // MARK: Agent activity

    private static func eventsFileDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: AppPaths.agentEvents.path))?[.modificationDate] as? Date
    }

    private static func sessionsFileDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: AppPaths.agentSessions.path))?[.modificationDate] as? Date
    }

    /// Overall state for the notch: waiting beats working beats a recent finish.
    var overallState: AgentSession.State {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if sessions.contains(where: { $0.state == .waiting }) { return .waiting }
        if sessions.contains(where: { $0.state == .working && now - $0.updatedAt < 30 * 60 * 1000 }) { return .working }
        if sessions.contains(where: { $0.state == .done && now - $0.updatedAt < 8000 }) { return .done }
        return .idle
    }

    func hasUnreadEvent(_ session: AgentSession) -> Bool {
        agentEvents.contains { $0.sessionID == session.id }
    }

    func markRead(_ session: AgentSession) {
        for event in agentEvents where event.sessionID == session.id { dismissAgentEvent(event) }
    }

    /// Unread and waiting sessions first, then working, then most recent.
    var orderedSessions: [AgentSession] {
        func rank(_ s: AgentSession) -> Int {
            if s.state == .waiting { return 0 }
            if hasUnreadEvent(s) { return 1 }
            if s.state == .working { return 2 }
            return 3
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return sessions
            .filter { $0.state == .working || $0.state == .waiting || hasUnreadEvent($0) || now - $0.updatedAt < 60 * 60 * 1000 }
            .sorted { (rank($0), -$0.updatedAt) < (rank($1), -$1.updatedAt) }
    }

    var visibleSessions: [AgentSession] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return Array(sessions.filter { $0.state != .idle || now - $0.updatedAt < 60 * 60 * 1000 }.prefix(6))
    }

    private func pollSessions() {
        let modified = Self.sessionsFileDate()
        if modified != sessionsModified {
            sessionsModified = modified
            let loaded = AgentSessions.load().values.sorted { $0.updatedAt > $1.updatedAt }
            // A light trackpad tap when a session finishes (Force Touch trackpads).
            let finished = loaded.filter { $0.state == .done }.map { "\($0.id)-\($0.updatedAt)" }
            if agentAlertsEnabled, !knownDone.isEmpty, finished.contains(where: { !knownDone.contains($0) }) {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
            knownDone = Set(finished)
            if loaded != sessions { sessions = loaded }
        }
        // One reminder per waiting period.
        guard agentAlertsEnabled else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for session in sessions where session.state == .waiting && now - session.updatedAt >= 3 * 60 * 1000 {
            if remindedWaits.insert("\(session.id)-\(session.updatedAt)").inserted {
                notice = tr("%@ has been waiting for you in %@", session.agentName, session.project.isEmpty ? "?" : session.project)
            }
        }
    }

    private func pollAgentEvents() {
        pollSessions()
        for alert in limitTracker.dueAvailable() where limitAlertsEnabled { showLimitAlert(alert) }
        let modified = Self.eventsFileDate()
        let sessionInfo = ClaudeUsageProvider.loadSession()
        if sessionInfo != session { session = sessionInfo }
        guard modified != eventsModified else { return }
        eventsModified = modified
        reloadAgentEvents()
    }

    private func reloadAgentEvents() {
        let events = agentAlertsEnabled ? AgentEvents.load().filter { $0.at > eventsSeen } : []
        if events != agentEvents { agentEvents = events }
    }

    func dismissAgentEvent(_ event: AgentEvent) {
        eventsSeen = max(eventsSeen, event.at)
        reloadAgentEvents()
    }

    var needsAttention: Bool { !agentEvents.isEmpty || !limitAlerts.isEmpty }

    // MARK: Agent configuration

    func refreshAgentConfigs() {
        claudeConfig = AgentConfig.claudeConfiguration()
        codexConfig = AgentConfig.codexConfiguration()
    }

    func setClaudeDefaults(model: String? = nil, effort: String? = nil) {
        do { try AgentConfig.setClaudeDefaults(model: model, effort: effort) }
        catch { notice = error.localizedDescription }
        refreshAgentConfigs()
    }

    func setCodexDefaults(model: String? = nil, effort: String? = nil) {
        do { try AgentConfig.setCodexDefaults(model: model, effort: effort) }
        catch { notice = error.localizedDescription }
        refreshAgentConfigs()
    }

    func connectAgentAlerts() {
        var errors: [String] = []
        do { try AgentConfig.installClaudeHooks() } catch { errors.append(error.localizedDescription) }
        do { try AgentConfig.installCodexNotify() } catch { errors.append(error.localizedDescription) }
        notice = errors.first ?? tr("Agent alerts are on. New Claude Code and Codex sessions will report here.")
        refreshAgentConfigs()
    }

    func copyHistoryItem(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = tr("Text copied.")
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
        // Open where there is something to see.
        if isExpanded { panelTab = orderedSessions.isEmpty ? .limits : .sessions }
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
                speechService.contextualStrings = vocabulary
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
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
            let raw = try await speechService.stop()
            let result = removeFillers ? TranscriptCleanup.removeFillers(raw) : raw
            liveTranscript = result
            if !result.isEmpty {
                history.insert(result, at: 0)
                if history.count > 8 { history.removeLast(history.count - 8) }
            }
            if !result.isEmpty, let targetPID {
                switch TextInjector.paste(result, into: targetPID, pressEnter: autoEnter) {
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
