import SwiftUI
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var model: AppModel
    let cameraGap: CGFloat
    let cameraHeight: CGFloat

    // The safe-area ends exactly at the camera housing. A little separation is
    // still needed so text and controls are visibly clear of the black glass.
    private let belowCameraClearance: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            compactBar
            if model.isExpanded {
                expandedContent
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, model.isExpanded ? 12 : 6)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
                .fill(.black)
        )
        .overlay(NotchGlow(state: model.overallState))
        .overlay {
            if model.dropTargeted {
                UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
                    .strokeBorder(Color.mint, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .overlay(Text(tr("Drop to paste the path")).font(.system(size: 10, weight: .semibold)).foregroundStyle(.mint))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $model.dropTargeted) { providers in
            loadURLs(providers) { model.pasteDroppedPaths($0) }
            return true
        }
        .foregroundStyle(.white)
    }

    private func loadURLs(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        let group = DispatchGroup()
        let collected = URLCollector()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { collected.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated { completion(collected.urls) }
        }
    }

    private var compactBar: some View {
        HStack(spacing: 0) {
            CompactUsageChip(title: "Codex", color: .mint, snapshot: model.codexUsage, speechState: model.speechState)
                .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(width: cameraGap, height: 1)

            HStack(spacing: 6) {
                if model.needsAttention { AttentionDot(urgent: model.agentEvents.last?.kind == .permission) }
                CompactUsageChip(title: "Claude", color: .orange, snapshot: model.claudeUsage)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: cameraHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    private var expandedContent: some View {
        VStack(spacing: 10) {
            Divider().overlay(.white.opacity(0.12))
            HStack(spacing: 7) {
                SpeechActivityIndicator(state: model.speechState)
                Text(model.speechState.shortLabel)
                Spacer()
                Button {
                    model.settingsOpen.toggle()
                    if model.settingsOpen { model.refreshAgentConfigs() }
                } label: {
                    Image(systemName: model.settingsOpen ? "gearshape.fill" : "gearshape")
                }
                .buttonStyle(.plain)
                .help(tr("Settings"))
                Button {
                    model.settingsOpen = false
                    model.toggleExpanded()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .help(tr("Close"))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))

            ForEach(model.limitAlerts) { alert in
                AlertRow(color: .yellow, title: alert.text, detail: nil, onDismiss: nil)
            }

            // Live words only while dictating; past dictations live in the Voice tab.
            if model.speechState == .listening || model.speechState == .transcribing, !model.liveTranscript.isEmpty {
                Text(model.liveTranscript)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if model.settingsOpen {
                SettingsSection(model: model)
            } else if model.wrapped != nil {
                WrappedSection(model: model)
            } else {
                PanelTabs(model: model)
                switch model.panelTab {
                case .sessions: SessionsList(model: model)
                case .limits: limitsTab
                case .voice: voiceTab
                }
            }

            setupActions

            if let notice = model.notice {
                Text(notice)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, belowCameraClearance)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var limitsTab: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                usageColumn(title: "Codex", color: .mint, snapshot: model.codexUsage, error: model.codexError)
                usageColumn(title: "Claude Code", color: .orange, snapshot: model.claudeUsage, error: model.claudeError)
            }
            HStack {
                Button(tr("Your week")) { model.showWrapped() }
                Spacer()
                Button { Task { await model.refreshAll() } } label: { Image(systemName: "arrow.clockwise") }
                    .help(tr("Refresh"))
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10))
        }
    }

    private var voiceTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.history.isEmpty {
                Text(tr("Hold Space to dictate into any app."))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
            }
            ForEach(Array(model.history.prefix(4).enumerated()), id: \.offset) { index, text in
                Button { model.copyHistoryItem(text) } label: {
                    Text(text)
                        .font(.system(size: index == 0 ? 11 : 10))
                        .foregroundStyle(.white.opacity(index == 0 ? 0.9 : 0.6))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(index == 0 ? 8 : 0)
                        .background(index == 0 ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(tr("Copy"))
            }
            HStack(spacing: 9) {
                Menu {
                    ForEach(model.localeOptions, id: \.id) { locale in
                        Button(locale.name) { model.selectedLocale = locale.id }
                    }
                } label: { Label(localeName, systemImage: "mic") }
                .menuStyle(.borderlessButton).fixedSize()
                .help(tr("Dictation language"))
                Menu {
                    ForEach(UILanguage.allCases) { language in
                        Button(language.nativeName) { model.uiLanguage = language }
                    }
                } label: { Label(model.uiLanguage.resolved.nativeName, systemImage: "globe") }
                .menuStyle(.borderlessButton).fixedSize()
                .help(tr("Interface language"))
                Spacer()
                if case .failed = model.speechState {
                    Button(tr("Retry")) { model.resetSpeechError() }
                }
            }
            .font(.system(size: 10))
        }
    }

    /// Only what still needs doing; nothing when everything is set up.
    @ViewBuilder
    private var setupActions: some View {
        let needsAlerts = !(model.claudeConfig.hooksInstalled && model.codexConfig.hooksInstalled)
        if !model.accessibilityReady || !model.voicePermissionsReady || !model.claudeBridgeReady || needsAlerts {
            HStack(spacing: 6) {
                if !model.accessibilityReady {
                    Button(tr("Enable Space")) { model.requestAccessibility() }.buttonStyle(.borderedProminent)
                }
                if !model.voicePermissionsReady {
                    Button(tr("Grant voice permissions")) { model.requestVoicePermissions() }
                }
                if !model.claudeBridgeReady {
                    Button(tr("Connect Claude")) { model.connectClaude() }
                }
                if needsAlerts {
                    Button(tr("Enable agent alerts")) { model.connectAgentAlerts() }
                }
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 10))
        }
    }

    @ViewBuilder
    private func usageColumn(title: String, color: Color, snapshot: UsageSnapshot?, error: String?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            if title == "Claude Code", let session = model.session {
                Text(session.line)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            if let snapshot {
                Text(snapshot.ageLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(snapshot.isStale ? .orange : .gray)
                ForEach(snapshot.windows.prefix(2)) { window in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(window.displayLabel)
                                .lineLimit(1)
                            Spacer()
                            Text(UsageFormatting.percent(window.usedPercent))
                                .monospacedDigit()
                        }
                        .font(.system(size: 10, weight: .medium))
                        ProgressView(value: window.usedPercent, total: 100)
                            .tint(color)
                            .controlSize(.mini)
                            .frame(height: 6)
                        Text(UsageFormatting.resetDescription(window.resetsAt))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.52))
                        if window.usedPercent >= 90, let reset = window.resetsAt, reset > Date() {
                            Text(tr("back in %@", Self.countdown(to: reset)))
                                .font(.system(size: 9))
                                .foregroundStyle(.mint)
                        }
                        if let eta = model.projections[window.id], eta > Date() {
                            Text(tr("at this pace: 100%% at %@", eta.formatted(date: .omitted, time: .shortened)))
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } else {
                Text(error ?? tr("Loading…"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(3)
            }
            if snapshot != nil, let error {
                Text(error).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "47 min" or "2 h 5 min".
    static func countdown(to date: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSinceNow / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private var localeName: String {
        model.localeOptions.first(where: { $0.id == model.selectedLocale })?.name ?? model.selectedLocale
    }

}

/// Lives in the left wing, outside the physical camera exclusion area.
/// Reuses the usage ring's footprint so starting dictation never resizes the panel.
private struct SpeechActivityIndicator: View {
    let state: SpeechState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state == .listening && !reduceMotion {
                TimelineView(.periodic(from: .distantPast, by: 0.55)) { context in
                    icon.opacity(Int(context.date.timeIntervalSince1970 / 0.55) % 2 == 0 ? 1 : 0.3)
                }
            } else {
                icon
            }
        }
        .frame(width: 18, height: 18)
        .help(state.shortLabel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.shortLabel)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
    }

    private var symbol: String {
        switch state {
        case .idle, .listening: return "mic.fill"
        case .preparing: return "hourglass"
        case .transcribing: return "ellipsis"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .listening: return .red
        case .preparing, .transcribing, .failed: return .orange
        case .idle: return .white
        }
    }
}

private struct CompactUsageChip: View {
    let title: String
    let color: Color
    let snapshot: UsageSnapshot?
    var speechState: SpeechState = .idle

    var body: some View {
        HStack(spacing: 6) {
            if speechState != .idle {
                SpeechActivityIndicator(state: speechState)
            } else {
                Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(.white.opacity(0.16), lineWidth: 3))
                .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var progress: Double {
        guard let snapshot, !snapshot.isStale else { return 0 }
        return min(1, max(0, (snapshot.primary?.usedPercent ?? 0) / 100))
    }

    private var value: String {
        if snapshot?.isStale == true { return tr("stale") }
        return snapshot?.primary.map { UsageFormatting.percent($0.usedPercent) } ?? "--"
    }
}

private struct AttentionDot: View {
    let urgent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 0.8)) { context in
            let on = reduceMotion || Int(context.date.timeIntervalSince1970 / 0.8) % 2 == 0
            Circle()
                .fill(urgent ? Color.red : Color.orange)
                .frame(width: 7, height: 7)
                .opacity(on ? 1 : 0.35)
        }
        .accessibilityLabel(tr("Agents"))
    }
}

private struct AlertRow: View {
    let color: Color
    let title: String
    let detail: String?
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10, weight: .semibold))
                if let detail {
                    Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                    .buttonStyle(.plain)
                    .help(tr("Dismiss"))
            }
        }
        .padding(7)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SettingsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(.white.opacity(0.12))
            Text(tr("Default model for new sessions")).font(.system(size: 10, weight: .semibold))
            agentRow(name: "Claude Code", config: model.claudeConfig,
                     setModel: { model.setClaudeDefaults(model: $0) },
                     setEffort: { model.setClaudeDefaults(effort: $0) })
            agentRow(name: "Codex", config: model.codexConfig,
                     setModel: { model.setCodexDefaults(model: $0) },
                     setEffort: { model.setCodexDefaults(effort: $0) })
            Text(tr("Open sessions keep their model; use /model there."))
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))

            Text(tr("Alerts")).font(.system(size: 10, weight: .semibold)).padding(.top, 2)
            Toggle(tr("Limit alerts (80%, 95%, reset)"), isOn: $model.limitAlertsEnabled)
            Toggle(tr("Agent finished / needs approval"), isOn: $model.agentAlertsEnabled)

            Text(tr("Dictation")).font(.system(size: 10, weight: .semibold)).padding(.top, 2)
            TextField(tr("Names and terms to recognise, separated by commas"), text: $model.vocabulary)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
            Toggle(tr("Press Enter after pasting"), isOn: $model.autoEnter)
            Toggle(tr("Remove filler words (um, eh…)"), isOn: $model.removeFillers)
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 10))
    }

    private func agentRow(name: String, config: AgentConfiguration,
                          setModel: @escaping (String) -> Void,
                          setEffort: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(name).frame(width: 74, alignment: .leading).foregroundStyle(.white.opacity(0.7))
            Menu(modelName(config)) {
                ForEach(config.models) { option in
                    Button(option.id.isEmpty ? tr("Default") : option.name) { setModel(option.id) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Menu(config.effort.isEmpty ? tr("Effort") + ": " + tr("Default") : tr(AgentEffort.label(config.effort))) {
                Button(tr("Default")) { setEffort("") }
                ForEach(config.selectedModel?.efforts ?? [], id: \.self) { effort in
                    Button(tr(AgentEffort.label(effort))) { setEffort(effort) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(config.models.isEmpty)
        }
    }

    private func modelName(_ config: AgentConfiguration) -> String {
        guard !config.model.isEmpty else { return tr("Default") }
        return config.models.first { $0.id == config.model }?.name ?? config.model
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Collects URLs from item-provider callbacks on arbitrary queues.
private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []
    func append(_ url: URL) { lock.lock(); storage.append(url); lock.unlock() }
    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return storage }
}

/// Ambient state of the notch: shimmer while working, breathing while an
/// agent waits, a short flash when one finishes.
private struct NotchGlow: View {
    let state: AgentSession.State
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: state == .idle)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let shape = UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
            switch state {
            case .working where !reduceMotion:
                let phase = (t.truncatingRemainder(dividingBy: 2.4)) / 2.4
                shape.strokeBorder(
                    LinearGradient(colors: [.clear, .mint.opacity(0.7), .clear],
                                   startPoint: UnitPoint(x: phase * 1.6 - 0.3, y: 0),
                                   endPoint: UnitPoint(x: phase * 1.6 + 0.1, y: 0)),
                    lineWidth: 1.5)
            case .waiting:
                let pulse = reduceMotion ? 0.6 : 0.35 + 0.35 * (1 + sin(t * 2.6)) / 2
                shape.strokeBorder(Color.orange.opacity(pulse), lineWidth: 1.5)
            case .done:
                shape.strokeBorder(Color.mint.opacity(0.8), lineWidth: 1.5)
            default:
                Color.clear
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PanelTabs: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            tab(.sessions, tr("Sessions"), badge: model.agentEvents.count)
            tab(.limits, tr("Limits"), badge: 0)
            tab(.voice, tr("Voice"), badge: 0)
        }
        .padding(2)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func tab(_ value: AppModel.PanelTab, _ title: String, badge: Int) -> some View {
        Button { model.panelTab = value } label: {
            HStack(spacing: 4) {
                Text(title)
                if badge > 0 {
                    Text("\(badge)").font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange, in: Capsule()).foregroundStyle(.black)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(model.panelTab == value ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.panelTab == value ? .white : .white.opacity(0.55))
    }
}

private struct SessionsList: View {
    @ObservedObject var model: AppModel
    @State private var showAll = false

    var body: some View {
        let sessions = model.orderedSessions
        VStack(alignment: .leading, spacing: 4) {
            if sessions.isEmpty {
                Text(tr("No active sessions. They appear here when Claude Code or Codex are working."))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
            }
            ForEach(showAll ? sessions : Array(sessions.prefix(4))) { session in
                row(session)
            }
            if sessions.count > 4 {
                Button(showAll ? tr("Show less") : tr("Show all (%d)", sessions.count)) { showAll.toggle() }
                    .buttonStyle(.plain).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func line(_ session: AgentSession) -> String {
        var text = session.stateText
        if session.state == .working {
            text = session.activity?.text ?? text
            let seconds = Int64(Date().timeIntervalSince1970) - session.startedAt / 1000
            if session.startedAt > 0 { text += " · " + TaskSummary(costUsd: nil, durationSecs: seconds).text }
        }
        if session.state == .done, let task = session.lastTask?.text, !task.isEmpty { text += " · " + task }
        return text
    }

    @ViewBuilder
    private func row(_ session: AgentSession) -> some View {
        let open = model.openSessionID == session.id
        let unread = model.hasUnreadEvent(session)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(session.source == "codex" ? Color.mint : Color.orange).frame(width: 6, height: 6)
                Text(session.project.isEmpty ? session.agentName : session.project)
                    .font(.system(size: 10, weight: unread ? .bold : .semibold)).lineLimit(1)
                    .layoutPriority(1)
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    Text(line(session))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(session.state == .waiting ? Color.orange : .white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if unread { Circle().fill(Color.orange).frame(width: 5, height: 5) }
                if session.terminal != nil {
                    Button { model.jumpToTerminal(session) } label: {
                        Image(systemName: "arrow.up.forward.app").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.6))
                    .help(tr("Go to terminal (or double-click)"))
                }
                Image(systemName: open ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.35))
            }
            .contentShape(Rectangle())
            // Double-click jumps to the terminal; a single click shows details.
            .onTapGesture(count: 2) { model.jumpToTerminal(session) }
            .onTapGesture {
                model.openSessionID = open ? nil : session.id
                model.markRead(session)
            }
            if open {
                VStack(alignment: .leading, spacing: 6) {
                    Text([session.agentName, session.model].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                    if !session.lastMessage.isEmpty {
                        ScrollView {
                            Text(AgentText.plain(session.lastMessage))
                                .font(.system(size: 10)).textSelection(.enabled)
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 84)
                    }
                    HStack(spacing: 6) {
                        if !session.lastMessage.isEmpty {
                            Button(tr("Copy response")) { model.copyToClipboard(session.lastMessage, notice: tr("Text copied.")) }
                        }
                        Button(session.source == "codex" ? tr("Continue in Claude") : tr("Continue in Codex")) { model.handoff(session) }
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .background(.white.opacity(open ? 0.09 : 0.05), in: RoundedRectangle(cornerRadius: 7))
    }
}

/// Shareable weekly summary, rendered to a 1080×1350 PNG.
struct WrappedCard: View {
    let week: WeekSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 40) {
                    Circle().stroke(Color.mint, lineWidth: 3.5).frame(width: 14, height: 14)
                    Circle().stroke(Color.orange, lineWidth: 3.5).frame(width: 14, height: 14)
                }
                .padding(.horizontal, 26).frame(height: 34)
                .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 15, bottomTrailingRadius: 15))
                Spacer()
            }
            Text(tr("My week with AI agents")).font(.system(size: 32, weight: .bold)).padding(.top, 50)
            Text("\(week.from) → \(week.to)").font(.system(size: 16)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 40) {
                stat("\(week.tasks)", tr("tasks finished"), .white)
                stat("+\(week.linesAdded.formatted())", tr("lines written"), .mint)
                stat(String(format: "$%.2f", week.costUsd), tr("on Claude"), .orange)
                stat(String(format: "%.1f", week.busyHours), tr("hours of agent work"), .white)
            }
            .padding(.top, 50)
            HStack(alignment: .bottom, spacing: 14) {
                let peak = max(1, week.dailyTasks.max() ?? 1)
                ForEach(Array(week.dailyTasks.enumerated()), id: \.offset) { _, n in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(n == peak && n > 0 ? Color.mint : Color.white.opacity(0.2))
                        .frame(width: 44, height: max(4, CGFloat(n) / CGFloat(peak) * 90))
                }
            }
            .frame(height: 96, alignment: .bottom)
            .padding(.top, 44)
            VStack(alignment: .leading, spacing: 10) {
                if let model = week.topModel { fact(tr("favourite model"), model) }
                if let project = week.topProject { fact(tr("top project"), project) }
                if let day = week.busiestDay { fact(tr("busiest day"), day.formatted(.dateTime.weekday(.wide))) }
            }
            .padding(.top, 30)
            Spacer()
            Text(tr("Made with AgentNotch · open source") + " · agentnotch.vercel.app")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 45).padding(.bottom, 30)
        .frame(width: 540, height: 675)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.11), Color(red: 0.11, green: 0.14, blue: 0.2),
                                            Color(red: 0.23, green: 0.15, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 52, weight: .bold)).foregroundStyle(color).minimumScaleFactor(0.5).lineLimit(1)
            Text(label).font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.6)).frame(width: 160, alignment: .leading)
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 15))
    }
}

private struct WrappedSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let week = model.wrapped {
            VStack(alignment: .leading, spacing: 8) {
                Divider().overlay(.white.opacity(0.12))
                if week.tasks == 0 {
                    Text(tr("No finished tasks yet this week. Enable agent alerts to start counting."))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                } else {
                    WrappedCard(week: week)
                        .scaleEffect(0.5, anchor: .topLeading)
                        .frame(width: 270, height: 337.5, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 8) {
                    if week.tasks > 0 {
                        Button(tr("Save image")) { save(week) }
                    }
                    if let url = model.wrappedSavedURL {
                        Button(tr("Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    Spacer()
                    Button { model.wrapped = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .font(.system(size: 10))
            }
        }
    }

    private func save(_ week: WeekSummary) {
        let renderer = ImageRenderer(content: WrappedCard(week: week).environment(\.colorScheme, .dark))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            model.notice = tr("Couldn't save the image.")
            return
        }
        let directory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = directory.appendingPathComponent("AgentNotch-Wrapped-\(AgentStats.key(Date())).png")
        do {
            try png.write(to: url, options: .atomic)
            model.wrappedSavedURL = url
            model.notice = tr("Image saved.")
        } catch {
            model.notice = tr("Couldn't save the image.")
        }
    }
}
