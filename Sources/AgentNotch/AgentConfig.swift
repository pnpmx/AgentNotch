import Foundation

/// Reads and edits the agents' own configuration: default model and effort,
/// and the hooks that report activity. Only keys AgentNotch owns are touched.
struct AgentModelOption: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let efforts: [String]
}

struct AgentConfiguration: Equatable, Sendable {
    var model = ""
    var effort = ""
    var models: [AgentModelOption] = []
    var hooksInstalled = false

    var selectedModel: AgentModelOption? { models.first { $0.id == model } ?? models.first }
}

enum AgentConfigError: LocalizedError, Equatable {
    case malformed, notifyInUse, invalid

    var errorDescription: String? {
        switch self {
        case .malformed: return tr("Couldn't read the agent's settings file.")
        case .notifyInUse: return tr("Codex already runs another notify program; it was not replaced.")
        case .invalid: return tr("That value isn't supported.")
        }
    }
}

enum AgentConfig {
    static let claudeModels: [(id: String, name: String)] = [
        ("", "Default"), ("opus", "Opus"), ("sonnet", "Sonnet"), ("haiku", "Haiku"), ("fable", "Fable")
    ]
    static let claudeEfforts = ["low", "medium", "high", "xhigh"]

    static func hookCommand(source: String) -> String {
        "\"\(Bundle.main.executableURL?.path ?? "AgentNotch")\" \(AgentEvents.flag) \(source)"
    }

    // MARK: Claude Code

    static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static func readJSON(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw AgentConfigError.malformed
        }
        return object
    }

    static func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func claudeHooksPresent(_ settings: [String: Any]) -> Bool {
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return ["Stop", "Notification"].allSatisfy { event in
            (hooks[event] as? [[String: Any]] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains {
                    ($0["command"] as? String)?.contains(AgentEvents.flag) == true
                }
            }
        }
    }

    static func claudeConfiguration(at url: URL = claudeSettingsURL) -> AgentConfiguration {
        let settings = (try? readJSON(url)) ?? [:]
        return AgentConfiguration(
            model: settings["model"] as? String ?? "",
            effort: settings["effortLevel"] as? String ?? "",
            models: claudeModels.map { AgentModelOption(id: $0.id, name: $0.name, efforts: claudeEfforts) },
            hooksInstalled: claudeHooksPresent(settings))
    }

    /// Empty strings remove the key, restoring Claude Code's default.
    static func setClaudeDefaults(model: String?, effort: String?, at url: URL = claudeSettingsURL) throws {
        var settings = try readJSON(url)
        if let model {
            guard claudeModels.contains(where: { $0.id == model }) else { throw AgentConfigError.invalid }
            settings["model"] = model.isEmpty ? nil : model
        }
        if let effort {
            guard effort.isEmpty || claudeEfforts.contains(effort) else { throw AgentConfigError.invalid }
            settings["effortLevel"] = effort.isEmpty ? nil : effort
        }
        try writeJSON(settings, to: url)
    }

    static func installClaudeHooks(command: String = hookCommand(source: "claude"), at url: URL = claudeSettingsURL) throws {
        var settings = try readJSON(url)
        guard !claudeHooksPresent(settings) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingLastPathComponent().appendingPathComponent("settings.agentnotch-backup-\(stamp).json")
            try? FileManager.default.copyItem(at: url, to: backup)
        }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let hook: [String: Any] = ["type": "command", "command": command, "async": true, "timeout": 10]
        for event in ["Stop", "Notification"] {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.append(["matcher": "*", "hooks": [hook]])
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        try writeJSON(settings, to: url)
    }

    // MARK: Codex

    static var codexDirectory: URL {
        if let home = ProcessInfo.processInfo.environment["CODEX_HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    private static func topLevelEnd(_ lines: [String]) -> Int {
        lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
    }

    private static func keyLine(_ lines: [String], _ key: String) -> Int? {
        lines[..<topLevelEnd(lines)].firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key) else { return false }
            return trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces).hasPrefix("=")
        }
    }

    static func tomlGet(_ text: String, _ key: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let index = keyLine(lines, key), let range = lines[index].range(of: "=") else { return nil }
        var value = lines[index][range.upperBound...].trimmingCharacters(in: .whitespaces)
        if let comment = value.range(of: " #") { value = String(value[..<comment.lowerBound]) }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    /// Sets or removes (nil) a top-level key, keeping comments and tables.
    static func tomlSet(_ text: String, _ key: String, _ value: String?) -> String {
        var lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        switch (keyLine(lines, key), value) {
        case let (index?, value?): lines[index] = "\(key) = \(value)"
        case let (index?, nil): lines.remove(at: index)
        case let (nil, value?):
            var at = topLevelEnd(lines)
            while at > 0 && lines[at - 1].trimmingCharacters(in: .whitespaces).isEmpty { at -= 1 }
            lines.insert("\(key) = \(value)", at: at)
        case (nil, nil): break
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func codexModels(in directory: URL = codexDirectory) -> [AgentModelOption] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("models_cache.json")),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = root["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { model in
            guard model["visibility"] as? String == "list", let slug = model["slug"] as? String else { return nil }
            let efforts = (model["supported_reasoning_levels"] as? [[String: Any]] ?? []).compactMap { $0["effort"] as? String }
            return AgentModelOption(id: slug, name: model["display_name"] as? String ?? slug, efforts: efforts)
        }
    }

    static func codexConfiguration() -> AgentConfiguration {
        let text = (try? String(contentsOf: codexDirectory.appendingPathComponent("config.toml"), encoding: .utf8)) ?? ""
        return AgentConfiguration(
            model: tomlGet(text, "model") ?? "",
            effort: tomlGet(text, "model_reasoning_effort") ?? "",
            models: codexModels(),
            hooksInstalled: tomlGet(text, "notify")?.contains(AgentEvents.flag) == true)
    }

    static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 80
            && value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "-_.:".unicodeScalars.contains($0) }
            && value.allSatisfy(\.isASCII)
    }

    static func setCodexDefaults(model: String?, effort: String?) throws {
        let url = codexDirectory.appendingPathComponent("config.toml")
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        for (key, value) in [("model", model), ("model_reasoning_effort", effort)] {
            guard let value else { continue }
            guard value.isEmpty || isSafeIdentifier(value) else { throw AgentConfigError.invalid }
            text = tomlSet(text, key, value.isEmpty ? nil : "\"\(value)\"")
        }
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func codexNotifyLine(executable: String) -> String {
        func literal(_ s: String) -> String { s.contains("'") ? "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\"" : "'\(s)'" }
        return "[\([executable, AgentEvents.flag, "codex"].map(literal).joined(separator: ", "))]"
    }

    static func installingCodexNotify(in text: String, executable: String) throws -> String {
        switch tomlGet(text, "notify") {
        case let existing? where existing.contains(AgentEvents.flag): return text
        case .some: throw AgentConfigError.notifyInUse // Codex runs one notify program; keep the user's.
        case nil: return tomlSet(text, "notify", codexNotifyLine(executable: executable))
        }
    }

    static func installCodexNotify() throws {
        let url = codexDirectory.appendingPathComponent("config.toml")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let updated = try installingCodexNotify(in: text, executable: Bundle.main.executableURL?.path ?? "AgentNotch")
        guard updated != text else { return }
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }
}
