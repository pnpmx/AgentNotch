import Foundation

enum UsageSource: String, Codable, Sendable {
    case codex
    case claude
}

struct UsageWindow: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let usedPercent: Double
    let resetsAt: Date?
    let durationMinutes: Int?

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
}

struct UsageSnapshot: Codable, Equatable, Sendable {
    let source: UsageSource
    let windows: [UsageWindow]
    let fetchedAt: Date
    let plan: String?
    var origin: String? = nil

    var primary: UsageWindow? { windows.first }
    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 300 || windows.contains { ($0.resetsAt ?? .distantFuture) < Date() } }
    var ageLabel: String {
        let minutes = max(0, Int(Date().timeIntervalSince(fetchedAt) / 60))
        return "\(origin ?? source.rawValue) · \(tr("%d min ago", minutes))\(isStale ? " · " + tr("outdated") : "")"
    }
}

enum UsageParseError: LocalizedError {
    case malformedPayload
    case missingRateLimits

    var errorDescription: String? {
        switch self {
        case .malformedPayload:
            return tr("The response contains no valid JSON.")
        case .missingRateLimits:
            return tr("The response includes no usage limits.")
        }
    }
}

enum SpeechState: Equatable {
    case idle
    case preparing
    case listening
    case transcribing
    case failed(String)

    var shortLabel: String {
        switch self {
        case .idle: return tr("Hold Space")
        case .preparing: return tr("Preparing…")
        case .listening: return tr("Listening…")
        case .transcribing: return tr("Transcribing…")
        case .failed: return tr("Voice error")
        }
    }
}

enum AppPaths {
    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AgentNotch", isDirectory: true)
    }

    static var claudeSnapshot: URL {
        supportDirectory.appendingPathComponent("claude-usage.json")
    }
}
