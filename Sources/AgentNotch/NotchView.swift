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

            CompactUsageChip(title: "Claude", color: .orange, snapshot: model.claudeUsage)
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
                    model.toggleExpanded()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .help("Cerrar")
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))

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
                    Label(localeName, systemImage: "globe")
                }
                .menuStyle(.borderlessButton)

                Spacer()

                if !model.accessibilityReady {
                    Button("Activar Space") { model.requestAccessibility() }
                        .buttonStyle(.borderedProminent)
                }
                if case .failed = model.speechState {
                    Button("Reintentar") { model.resetSpeechError() }
                }
                if !model.liveTranscript.isEmpty {
                    Button("Copiar") { model.copyTranscript() }
                }
                if !model.claudeBridgeReady {
                    Button("Conectar Claude") { model.connectClaude() }
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
                Button("Conceder permisos de voz") { model.requestVoicePermissions() }
                    .buttonStyle(.bordered)
            }
            if !model.accessibilityReady {
                Text(model.keyboardStatus)
                    .font(.system(size: 10)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
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
            if let snapshot {
                Text(snapshot.ageLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(snapshot.isStale ? .orange : .gray)
                ForEach(snapshot.windows.prefix(2)) { window in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(window.label)
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
                    }
                }
            } else {
                Text(error ?? "Cargando…")
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
        if snapshot?.isStale == true { return "antiguo" }
        return snapshot?.primary.map { UsageFormatting.percent($0.usedPercent) } ?? "--"
    }
}
