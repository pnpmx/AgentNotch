import Foundation

enum ClaudeBridgeError: LocalizedError {
    case executableUnavailable
    case existingStatusLine
    case malformedSettings

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            return tr("Can't find the installed Agent Notch executable.")
        case .existingStatusLine:
            return tr("Claude already has a status line. I didn't overwrite it.")
        case .malformedSettings:
            return tr("Claude's settings file doesn't contain valid JSON.")
        }
    }
}

enum ClaudeUsageProvider {
    static func load() throws -> UsageSnapshot {
        let snapshots = [try? loadBridgeSnapshot(), try? loadClaudeDesktopSnapshot()].compactMap { $0 }
        guard let newest = snapshots.max(by: { $0.fetchedAt < $1.fetchedAt }) else {
            throw UsageParseError.missingRateLimits
        }
        return newest
    }

    private static func loadBridgeSnapshot() throws -> UsageSnapshot {
        let data = try Data(contentsOf: AppPaths.claudeSnapshot)
        var snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        guard !snapshot.windows.isEmpty,
              snapshot.fetchedAt <= Date().addingTimeInterval(60),
              snapshot.windows.allSatisfy({ $0.usedPercent.isFinite && (0...100).contains($0.usedPercent) })
        else { throw UsageParseError.malformedPayload }
        snapshot.origin = "Claude Code"
        return snapshot
    }

    /// Claude Desktop keeps recent plan percentages locally. This is only a
    /// fallback: the Claude Code status line remains the authoritative source
    /// for exact reset timestamps.
    static func loadClaudeDesktopSnapshot(now: Date = Date()) throws -> UsageSnapshot {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/plan-usage-history.json")
        let data = try Data(contentsOf: url)
        return try parseClaudeDesktopHistory(data, now: now)
    }

    static func parseClaudeDesktopHistory(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        guard data.count <= 4 * 1_024 * 1_024,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = (root["version"] as? NSNumber)?.intValue,
              [1, 2].contains(version),
              let entries = root["samples"] as? [[String: Any]]
        else { throw UsageParseError.malformedPayload }

        let latest = entries.compactMap { entry -> (Date, [String: Any])? in
            guard let milliseconds = (entry["t"] as? NSNumber)?.doubleValue,
                  milliseconds.isFinite, milliseconds > 0 else { return nil }
            let values = version == 1 ? entry : (entry["u"] as? [String: Any] ?? [:])
            return (Date(timeIntervalSince1970: milliseconds / 1_000), values)
        }.max(by: { $0.0 < $1.0 })

        guard let latest, now.timeIntervalSince(latest.0) >= -60, now.timeIntervalSince(latest.0) < 30 * 60 else {
            throw UsageParseError.missingRateLimits
        }
        let definitions: [(key: String, label: String, minutes: Int)] = [
            ("fh", "5 horas", 300),
            ("sd", "7 días", 10_080),
            ("so", "Opus · 7 días", 10_080),
            ("sn", "Sonnet · 7 días", 10_080)
        ]
        let windows = definitions.compactMap { definition -> UsageWindow? in
            guard let number = latest.1[definition.key] as? NSNumber,
                  number.doubleValue.isFinite else { return nil }
            return UsageWindow(
                id: "claude-desktop-\(definition.key)",
                label: definition.label,
                usedPercent: min(100, max(0, number.doubleValue)),
                resetsAt: nil,
                durationMinutes: definition.minutes
            )
        }
        guard !windows.isEmpty else { throw UsageParseError.missingRateLimits }
        return UsageSnapshot(source: .claude, windows: windows, fetchedAt: latest.0, plan: nil, origin: "Claude Desktop")
    }

    static func isBridgeConfigured() -> Bool {
        guard let settings = try? readSettings() else { return false }
        guard let line = settings["statusLine"] as? [String: Any], let command = line["command"] as? String else {
            return false
        }
        return command == "\"\(Bundle.main.executableURL?.path ?? "")\" --claude-bridge"
    }

    static func installBridge() throws {
        guard let executable = Bundle.main.executableURL?.path else {
            throw ClaudeBridgeError.executableUnavailable
        }
        let settingsURL = claudeSettingsURL
        var settings = try readSettings()
        if let existing = settings["statusLine"] as? [String: Any], existing["command"] != nil {
            if (existing["command"] as? String)?.contains("--claude-bridge") != true {
                throw ClaudeBridgeError.existingStatusLine
            }
        }

        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backup = settingsURL.deletingLastPathComponent().appendingPathComponent("settings.agentnotch-backup-\(stamp).json")
            try FileManager.default.copyItem(at: settingsURL, to: backup)
        } else {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        settings["statusLine"] = [
            "type": "command",
            "command": "\"\(executable)\" --claude-bridge",
            "refreshInterval": 30
        ]
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    private static func readSettings() throws -> [String: Any] {
        let url = claudeSettingsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeBridgeError.malformedSettings
        }
        return object
    }
}

enum ClaudeBridgeRunner {
    static func run() -> Int32 {
        do {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let object = try JSONSerialization.jsonObject(with: input)
            let snapshot = try UsageParser.parseClaudeStatusLine(object)
            try FileManager.default.createDirectory(at: AppPaths.supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: AppPaths.claudeSnapshot, options: .atomic)

            let summary = snapshot.windows.prefix(2).map {
                "\($0.displayLabel): \(UsageFormatting.percent($0.usedPercent))"
            }.joined(separator: " · ")
            FileHandle.standardOutput.write(Data("Claude \(summary)\n".utf8))
            return 0
        } catch UsageParseError.missingRateLimits {
            FileHandle.standardOutput.write(Data((tr("Claude: limits available after the first reply") + "\n").utf8))
            return 0
        } catch {
            FileHandle.standardError.write(Data("Agent Notch bridge: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
