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

    var primary: UsageWindow? { windows.first }
}

enum UsageParseError: LocalizedError {
    case malformedPayload
    case missingRateLimits

    var errorDescription: String? {
        switch self {
        case .malformedPayload:
            return "La respuesta no contiene JSON válido."
        case .missingRateLimits:
            return "La respuesta no incluye límites de uso."
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
        case .idle: return "Mantén Space"
        case .preparing: return "Preparando…"
        case .listening: return "Escuchando…"
        case .transcribing: return "Transcribiendo…"
        case .failed: return "Error de voz"
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
