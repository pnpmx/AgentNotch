import SwiftUI

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
        .foregroundStyle(.white)
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
        VStack(spacing: 11) {
            Divider().overlay(.white.opacity(0.12))
            HStack(spacing: 7) {
                SpeechActivityIndicator(state: model.speechState)
                Text(model.speechState.shortLabel)
                Spacer()
                Text("Space · 280 ms")
                    .foregroundStyle(.white.opacity(0.46))
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

            alertsList

            HStack(alignment: .top, spacing: 16) {
                usageColumn(
                    title: "Codex",
                    color: .mint,
                    snapshot: model.codexUsage,
                    error: model.codexError
                )
                usageColumn(
                    title: "Claude Code",
                    color: .orange,
                    snapshot: model.claudeUsage,
                    error: model.claudeError
                )
            }

            if model.history.count > 1 {
                DisclosureGroup(tr("Recent dictations")) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(model.history.dropFirst().enumerated()), id: \.offset) { _, text in
                            Button { model.copyHistoryItem(text) } label: {
                                Text(text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .help(tr("Copy"))
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.75))
            }

            if !model.liveTranscript.isEmpty {
                Text(model.liveTranscript)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 9) {
                Menu {
                    ForEach(model.localeOptions, id: \.id) { locale in
                        Button(locale.name) { model.selectedLocale = locale.id }
                    }
                } label: {
                    Label(localeName, systemImage: "mic")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(tr("Dictation language"))

                Menu {
                    ForEach(UILanguage.allCases) { language in
                        Button(language.nativeName) { model.uiLanguage = language }
                    }
                } label: {
                    Label(model.uiLanguage.resolved.nativeName, systemImage: "globe")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(tr("Interface language"))

                Spacer()

                if !model.accessibilityReady {
                    Button(tr("Enable Space")) { model.requestAccessibility() }
                        .buttonStyle(.borderedProminent)
                }
                if case .failed = model.speechState {
                    Button(tr("Retry")) { model.resetSpeechError() }
                }
                if !model.liveTranscript.isEmpty {
                    Button(tr("Copy")) { model.copyTranscript() }
                }
                if !model.claudeBridgeReady {
                    Button(tr("Connect Claude")) { model.connectClaude() }
                        .buttonStyle(.bordered)
                }
                if !(model.claudeConfig.hooksInstalled && model.codexConfig.hooksInstalled) {
                    Button(tr("Enable agent alerts")) { model.connectAgentAlerts() }
                        .buttonStyle(.bordered)
                }
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if !model.voicePermissionsReady {
                Button(tr("Grant voice permissions")) { model.requestVoicePermissions() }
                    .buttonStyle(.bordered)
            }
            if !model.accessibilityReady {
                Text(model.keyboardStatus)
                    .font(.system(size: 10)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.settingsOpen {
                SettingsSection(model: model)
            }

            if let notice = model.notice {
                Text(notice)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(3)
            }
        }
        .padding(.top, belowCameraClearance)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
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

    @ViewBuilder
    private var alertsList: some View {
        if !model.limitAlerts.isEmpty || !model.agentEvents.isEmpty {
            VStack(spacing: 5) {
                ForEach(model.limitAlerts) { alert in
                    AlertRow(color: .yellow, title: alert.text, detail: nil, onDismiss: nil)
                }
                ForEach(model.agentEvents.suffix(3).reversed()) { event in
                    AlertRow(
                        color: event.kind == .permission ? .red : (event.source == "codex" ? .mint : .orange),
                        title: event.project.isEmpty ? event.title : "\(event.title) · \(event.project)",
                        detail: event.message.isEmpty ? nil : event.message,
                        onDismiss: { model.dismissAgentEvent(event) })
                }
            }
        }
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
