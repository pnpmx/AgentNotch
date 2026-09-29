import Foundation

enum SelfTests {
    static func run() -> Int32 {
        do {
            try codexParser()
            try claudeStatusLineParser()
            try claudeDesktopHistoryParser()
            L10n.current = .es
            guard UsageFormatting.resetDescription(
                Date(timeIntervalSince1970: 4_900),
                now: Date(timeIntervalSince1970: 1_000)
            ) == "reset 1 h 5 min" else { throw Failure("formato de reset") }
            FileHandle.standardOutput.write(Data("Agent Notch self-test: 4/4 OK\n".utf8))
            return 0
        } catch {
            FileHandle.standardError.write(Data("Agent Notch self-test: \(error)\n".utf8))
            return 1
        }
    }

    private static func codexParser() throws {
        let payload: [String: Any] = [
            "id": 2,
            "result": ["rateLimits": [
                "limitId": "codex",
                "planType": "plus",
                "primary": ["usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1_800_000_000],
                "secondary": ["usedPercent": 40, "windowDurationMins": 10_080, "resetsAt": 1_800_100_000]
            ]]
        ]
        let snapshot = try UsageParser.parseCodexResponse(payload)
        guard snapshot.source == .codex, snapshot.windows.map(\.usedPercent) == [25, 40] else {
            throw Failure("parser Codex")
        }
    }

    private static func claudeStatusLineParser() throws {
        let payload: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 23.5, "resets_at": 1_800_000_000],
            "seven_day": ["used_percentage": 41.2, "resets_at": 1_800_100_000]
        ]]
        let snapshot = try UsageParser.parseClaudeStatusLine(payload)
        guard snapshot.source == .claude, snapshot.windows.map(\.usedPercent) == [23.5, 41.2] else {
            throw Failure("parser status line Claude")
        }
    }

    private static func claudeDesktopHistoryParser() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let payload: [String: Any] = [
            "version": 2,
            "samples": [["t": (now.timeIntervalSince1970 - 60) * 1_000, "u": ["fh": 18.5, "sd": 36]]]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let snapshot = try ClaudeUsageProvider.parseClaudeDesktopHistory(data, now: now)
        guard snapshot.windows.map(\.usedPercent) == [18.5, 36] else {
            throw Failure("parser historial Claude Desktop")
        }
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
