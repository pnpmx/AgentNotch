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

/// Live Claude Code session details from the status line.
struct SessionInfo: Codable, Equatable, Sendable {
    let model: String
    let effort: String?
    let costUSD: Double?
    let contextPercent: Double?
    let project: String
    let updatedAt: Date

    var line: String {
        var parts = [model]
        if let effort { parts.append(tr(AgentEffort.label(effort))) }
        if let costUSD { parts.append(String(format: "$%.2f", costUSD)) }
        if let contextPercent { parts.append(tr("context %d%%", Int(contextPercent.rounded()))) }
        return parts.joined(separator: " · ")
    }
}

enum AgentEffort {
    /// English label used as the translation key.
    static func label(_ effort: String) -> String {
        switch effort {
        case "none": return "None"
        case "minimal": return "Minimal"
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "Extra high"
        case "max": return "Max"
        default: return effort
        }
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

    static var claudeSession: URL {
        supportDirectory.appendingPathComponent("claude-session.json")
    }

    static var agentEvents: URL {
        supportDirectory.appendingPathComponent("agent-events.json")
    }

    static func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
