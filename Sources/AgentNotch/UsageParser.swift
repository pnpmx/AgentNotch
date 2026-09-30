import Foundation

enum UsageParser {
    static func parseCodexResponse(_ object: Any, now: Date = Date()) throws -> UsageSnapshot {
        guard
            let root = object as? [String: Any],
            let result = root["result"] as? [String: Any]
        else {
            throw UsageParseError.malformedPayload
        }

        let plan = (result["rateLimits"] as? [String: Any])?["planType"] as? String
        var windows: [UsageWindow] = []

        if let buckets = result["rateLimitsByLimitId"] as? [String: Any] {
            let sortedKeys = buckets.keys.sorted { lhs, rhs in
                if lhs == rhs { return false }
                if lhs == "codex" { return true }
                if rhs == "codex" { return false }
                return lhs < rhs
            }
            for key in sortedKeys {
                guard let bucket = buckets[key] as? [String: Any] else { continue }
                windows.append(contentsOf: parseCodexBucket(bucket, fallbackName: key))
            }
        }
        if windows.isEmpty, let bucket = result["rateLimits"] as? [String: Any] {
            windows = parseCodexBucket(bucket, fallbackName: "Codex")
        }

        guard !windows.isEmpty else { throw UsageParseError.missingRateLimits }
        return UsageSnapshot(source: .codex, windows: windows, fetchedAt: now, plan: plan, origin: "Codex CLI")
    }

    static func parseClaudeStatusLine(_ object: Any, now: Date = Date()) throws -> UsageSnapshot {
        guard let root = object as? [String: Any] else {
            throw UsageParseError.malformedPayload
        }
        guard let limits = root["rate_limits"] as? [String: Any] else {
            throw UsageParseError.missingRateLimits
        }

        let definitions: [(String, String)] = [
            ("five_hour", "5 horas"),
            ("seven_day", "7 días"),
            ("spend_limit", "Gasto")
        ]
        let windows = definitions.compactMap { key, label -> UsageWindow? in
            guard let value = limits[key] as? [String: Any], let used = number(value["used_percentage"]) else {
                return nil
            }
            return UsageWindow(
                id: "claude-\(key)",
                label: label,
                usedPercent: min(100, max(0, used)),
                resetsAt: epochDate(value["resets_at"]),
                durationMinutes: nil
            )
        }

        guard !windows.isEmpty else { throw UsageParseError.missingRateLimits }
        return UsageSnapshot(source: .claude, windows: windows, fetchedAt: now, plan: nil, origin: "Claude Code")
    }

    static func parseClaudeSession(_ object: Any, now: Date = Date()) -> SessionInfo? {
        guard let root = object as? [String: Any], let model = root["model"] as? [String: Any],
              let name = (model["display_name"] as? String) ?? (model["id"] as? String) else { return nil }
        let workspace = root["workspace"] as? [String: Any]
        let directory = (workspace?["project_dir"] as? String) ?? (workspace?["current_dir"] as? String) ?? (root["cwd"] as? String)
        return SessionInfo(
            model: name,
            effort: (root["effort"] as? [String: Any])?["level"] as? String,
            costUSD: number((root["cost"] as? [String: Any])?["total_cost_usd"]).flatMap { $0 >= 0 ? $0 : nil },
            contextPercent: number((root["context_window"] as? [String: Any])?["used_percentage"]).map { min(100, max(0, $0)) },
            project: AgentEvents.projectName(directory),
            updatedAt: now)
    }

    private static func parseCodexBucket(_ bucket: [String: Any], fallbackName: String) -> [UsageWindow] {
        let name = (bucket["limitName"] as? String) ?? (bucket["limitId"] as? String) ?? fallbackName
        let entries = ["primary", "secondary"]
        return entries.compactMap { key in
            guard let value = bucket[key] as? [String: Any], let used = number(value["usedPercent"]) else {
                return nil
            }
            let minutes = number(value["windowDurationMins"]).flatMap { $0 > 0 && $0 <= 5_256_000 ? Int($0) : nil }
            let label: String
            switch minutes {
            case 300: label = "5 horas"
            case 10_080: label = "7 días"
            default: label = key == "secondary" ? "\(name) semanal" : name
            }
            return UsageWindow(
                id: "codex-\(name)-\(key)",
                label: label,
                usedPercent: min(100, max(0, used)),
                resetsAt: epochDate(value["resetsAt"]),
                durationMinutes: minutes
            )
        }
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    private static func epochDate(_ value: Any?) -> Date? {
        guard let seconds = number(value), seconds > 0, seconds <= 253_402_300_799 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

enum UsageFormatting {
    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        return "\(Int(min(100, max(0, value)).rounded()))%"
    }

    static func resetDescription(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return tr("reset unknown") }
        if date <= now { return tr("reset overdue · refresh") }
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds < 60 { return tr("reset <1 min") }
        let minutes = seconds / 60
        if minutes < 60 { return tr("reset %d min", minutes) }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours < 24 { return remainder == 0 ? tr("reset %d h", hours) : tr("reset %d h %d min", hours, remainder) }
        return tr("reset %d d %d h", hours / 24, hours % 24)
    }
}
