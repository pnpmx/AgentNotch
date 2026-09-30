import Foundation

/// Limit alerts and pace projection: thresholds crossed, resets, and when
/// 100% would be reached at the recent pace.
enum LimitAlert: Equatable, Identifiable {
    case threshold(windowID: String, label: String, source: UsageSource, percent: Int)
    case reset(windowID: String, label: String, source: UsageSource)
    /// A window that had run out (95%+) is available again at its reset time.
    case available(windowID: String, label: String, source: UsageSource)

    var id: String {
        switch self {
        case let .threshold(windowID, _, _, percent): return "\(windowID)-\(percent)"
        case let .reset(windowID, _, _): return "\(windowID)-reset"
        case let .available(windowID, _, _): return "\(windowID)-available"
        }
    }

    var text: String {
        switch self {
        case let .threshold(_, label, source, percent):
            return tr("%@ %@ limit at %d%%", source.agentName, label, percent)
        case let .reset(_, label, source):
            return tr("%@ %@ limit has reset", source.agentName, label)
        case let .available(_, label, source):
            return tr("%@ %@ limit is available again", source.agentName, label)
        }
    }
}

extension UsageSource {
    var agentName: String { self == .codex ? "Codex" : "Claude" }
}

struct LimitTracker {
    static let thresholds = [80, 95]
    private static let windowSeconds: TimeInterval = 45 * 60
    private static let minimumSpan: TimeInterval = 5 * 60

    private struct Track {
        var samples: [(Date, Double)] = []
        var resetsAt: Date?
        var notified = 0
        var exhausted = false
        var label = ""
        var source: UsageSource = .claude
    }

    private var tracks: [String: Track] = [:]

    mutating func update(_ snapshot: UsageSnapshot) -> [LimitAlert] {
        let now = snapshot.fetchedAt
        var alerts: [LimitAlert] = []
        for window in snapshot.windows {
            var track = tracks[window.id] ?? Track()
            let last = track.samples.last?.1
            var newPeriod = false
            if let old = track.resetsAt, let new = window.resetsAt, new > old.addingTimeInterval(60) { newPeriod = true }
            if let last, window.usedPercent + 15 < last { newPeriod = true }
            if newPeriod {
                if track.notified > 0 || (last ?? 0) >= 50 {
                    alerts.append(.reset(windowID: window.id, label: window.displayLabel, source: snapshot.source))
                }
                track = Track()
            }
            track.resetsAt = window.resetsAt
            track.label = window.displayLabel
            track.source = snapshot.source
            if window.usedPercent >= 95 { track.exhausted = true }
            if track.samples.last?.0 != now { track.samples.append((now, window.usedPercent)) }
            track.samples.removeAll { now.timeIntervalSince($0.0) > Self.windowSeconds }
            if let level = Self.thresholds.reversed().first(where: { window.usedPercent >= Double($0) && track.notified < $0 }) {
                track.notified = level
                alerts.append(.threshold(windowID: window.id, label: window.displayLabel, source: snapshot.source, percent: level))
            }
            tracks[window.id] = track
        }
        return alerts
    }

    /// Exhausted windows whose reset time has passed; each fires once.
    mutating func dueAvailable(now: Date = Date()) -> [LimitAlert] {
        var alerts: [LimitAlert] = []
        for (id, track) in tracks where track.exhausted && (track.resetsAt.map { $0 <= now } ?? false) {
            tracks[id]?.exhausted = false
            alerts.append(.available(windowID: id, label: track.label, source: track.source))
        }
        return alerts
    }

    /// When the window reaches 100% at the recent pace, if before its reset.
    func projection(for windowID: String) -> Date? {
        guard let track = tracks[windowID], let eta = Self.project(track.samples) else { return nil }
        if let reset = track.resetsAt, eta >= reset { return nil }
        return eta
    }

    static func project(_ samples: [(Date, Double)]) -> Date? {
        guard let first = samples.first, let last = samples.last, samples.count >= 3,
              last.0.timeIntervalSince(first.0) >= minimumSpan, last.1 < 100 else { return nil }
        let n = Double(samples.count)
        let times = samples.map { $0.0.timeIntervalSince(first.0) }
        let meanT = times.reduce(0, +) / n
        let meanP = samples.map(\.1).reduce(0, +) / n
        var numerator = 0.0, denominator = 0.0
        for (t, sample) in zip(times, samples) {
            numerator += (t - meanT) * (sample.1 - meanP)
            denominator += (t - meanT) * (t - meanT)
        }
        guard denominator > 0 else { return nil }
        let perSecond = numerator / denominator
        guard perSecond > 0 else { return nil }
        return last.0.addingTimeInterval((100 - last.1) / perSecond)
    }
}

enum TranscriptCleanup {
    /// Hesitation sounds in the supported languages; only standalone words go.
    static let fillers: Set<String> = ["um", "uh", "erm", "hmm", "mmm", "eh", "ehm", "em", "este", "ehh",
                                       "euh", "äh", "ähm", "ehmm", "uhm", "umm"]

    static func removeFillers(_ text: String) -> String {
        var result = text.split(whereSeparator: \.isWhitespace).filter { word in
            let bare = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
            return !fillers.contains(bare)
        }.joined(separator: " ")
        while let first = result.first, first == "," || first == ";" {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard let first = result.first else { return "" }
        return first.uppercased() + result.dropFirst()
    }
}
