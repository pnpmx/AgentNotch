import Darwin
import Foundation

/// Per-session agent activity, so several Claude Code and Codex sessions in
/// different terminal tabs can be followed at once. Hook processes update a
/// shared file under an exclusive lock; the app only reads it.
struct SessionActivity: Codable, Equatable, Sendable {
    /// thinking | edit | run | read | search | web | agent | tool
    var kind: String
    var detail: String

    var text: String {
        switch kind {
        case "thinking": return tr("thinking…")
        case "edit": return tr("editing %@", detail)
        case "run": return tr("running %@", detail)
        case "read": return tr("reading %@", detail)
        case "search": return tr("searching %@", detail)
        case "web": return tr("browsing %@", detail)
        case "agent": return tr("delegating: %@", detail)
        default: return tr("using %@", detail)
        }
    }
}

struct TaskSummary: Codable, Equatable, Sendable {
    var costUsd: Double?
    var durationSecs: Int64
    var linesAdded: Int64?
    var linesRemoved: Int64?

    /// "$0.42 · 4 min · +156/−23", leaving out what is unknown.
    var text: String {
        var parts: [String] = []
        if let costUsd, costUsd > 0 { parts.append(String(format: "$%.2f", costUsd)) }
        if durationSecs > 0 {
            parts.append(durationSecs < 60 ? tr("%d s", Int(durationSecs)) : tr("%d min", Int((Double(durationSecs) / 60).rounded())))
        }
        if (linesAdded ?? 0) > 0 || (linesRemoved ?? 0) > 0 { parts.append("+\(linesAdded ?? 0)/−\(linesRemoved ?? 0)") }
        return parts.joined(separator: " · ")
    }
}

struct AgentSession: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable { case idle, working, waiting, done }

    var id: String
    var source = "claude"
    var project = ""
    var cwd = ""
    var state: State = .idle
    var activity: SessionActivity?
    var model: String?
    var lastPrompt = ""
    var lastMessage = ""
    /// Unix milliseconds.
    var startedAt: Int64 = 0
    var updatedAt: Int64 = 0
    var costUsd: Double?
    var linesAdded: Int64?
    var linesRemoved: Int64?
    var costAtStart: Double?
    var linesAddedAtStart: Int64?
    var linesRemovedAtStart: Int64?
    var lastTask: TaskSummary?
    /// Terminal app and tab the session runs in, to jump back to it.
    var terminal: TerminalLocation?

    var agentName: String { source == "codex" ? "Codex" : "Claude" }

    var stateText: String {
        switch state {
        case .working: return tr("working")
        case .waiting: return tr("waiting for you")
        case .done: return tr("done")
        case .idle: return tr("idle")
        }
    }

    /// Prompt that lets the other agent pick up where this session stopped.
    var handoffPrompt: String {
        tr("Continue this task in the project “%@” (%@).\n\nWhat I asked:\n%@\n\nWhere it got to:\n%@\n\nCheck the current state of the files, then carry on.",
           project.isEmpty ? "?" : project, cwd,
           lastPrompt.isEmpty ? "—" : lastPrompt, lastMessage.isEmpty ? "—" : lastMessage)
    }

    init(id: String, source: String = "claude", now: Int64 = 0) {
        self.id = id
        self.source = source
        startedAt = now
        updatedAt = now
    }

    // Tolerate missing keys, e.g. files written by older versions.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "claude"
        project = try c.decodeIfPresent(String.self, forKey: .project) ?? ""
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        state = try c.decodeIfPresent(State.self, forKey: .state) ?? .idle
        activity = try c.decodeIfPresent(SessionActivity.self, forKey: .activity)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        lastPrompt = try c.decodeIfPresent(String.self, forKey: .lastPrompt) ?? ""
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage) ?? ""
        startedAt = try c.decodeIfPresent(Int64.self, forKey: .startedAt) ?? 0
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        costUsd = try c.decodeIfPresent(Double.self, forKey: .costUsd)
        linesAdded = try c.decodeIfPresent(Int64.self, forKey: .linesAdded)
        linesRemoved = try c.decodeIfPresent(Int64.self, forKey: .linesRemoved)
        costAtStart = try c.decodeIfPresent(Double.self, forKey: .costAtStart)
        linesAddedAtStart = try c.decodeIfPresent(Int64.self, forKey: .linesAddedAtStart)
        linesRemovedAtStart = try c.decodeIfPresent(Int64.self, forKey: .linesRemovedAtStart)
        lastTask = try c.decodeIfPresent(TaskSummary.self, forKey: .lastTask)
        terminal = try c.decodeIfPresent(TerminalLocation.self, forKey: .terminal)
    }
}

enum AgentSessions {
    typealias Sessions = [String: AgentSession]

    static let messageLimit = 4000
    static let promptLimit = 1200
    static let detailLimit = 48
    static let expiryMs: Int64 = 12 * 60 * 60 * 1000

    static func truncate(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func fileName(_ path: String) -> String {
        AgentEvents.projectName(path).isEmpty ? path : AgentEvents.projectName(path)
    }

    /// Short, display-only description of a tool call. File contents and long
    /// commands are never kept.
    static func activity(tool: String, input: [String: Any]) -> SessionActivity {
        let text = { (key: String) in input[key] as? String ?? "" }
        let singleLine = { (s: String) in s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let kind: String
        let detail: String
        switch tool {
        case "Edit", "MultiEdit", "Write", "NotebookEdit":
            kind = "edit"; detail = fileName(text("file_path").isEmpty ? text("notebook_path") : text("file_path"))
        case "Bash", "PowerShell":
            kind = "run"; detail = singleLine(text("command"))
        case "Read":
            kind = "read"; detail = fileName(text("file_path"))
        case "Grep", "Glob":
            kind = "search"; detail = text("pattern")
        case "WebFetch":
            kind = "web"; detail = URL(string: text("url"))?.host ?? text("url")
        case "WebSearch":
            kind = "web"; detail = text("query")
        case "Task", "Agent":
            kind = "agent"; detail = singleLine(text("description"))
        default:
            kind = "tool"
            detail = tool.hasPrefix("mcp__") ? String(tool.components(separatedBy: "__").last ?? tool) : tool
        }
        return SessionActivity(kind: kind, detail: truncate(detail, detailLimit))
    }

    /// Applies a Claude Code hook payload; returns the finished task when the
    /// payload ends a main-agent turn.
    @discardableResult
    static func applyClaudeHook(_ sessions: inout Sessions, _ payload: [String: Any], now: Int64) -> TaskSummary? {
        let text = { (key: String) in payload[key] as? String ?? "" }
        let id = text("session_id")
        guard !id.isEmpty else { return nil }
        var session = sessions[id] ?? AgentSession(id: id, now: now)
        defer { sessions[id] = session }
        if !text("cwd").isEmpty {
            session.cwd = text("cwd")
            session.project = AgentEvents.projectName(session.cwd)
        }
        session.updatedAt = now
        switch text("hook_event_name") {
        case "UserPromptSubmit":
            session.state = .working
            session.lastPrompt = truncate(text("prompt").trimmingCharacters(in: .whitespacesAndNewlines), promptLimit)
            session.startedAt = now
            session.activity = SessionActivity(kind: "thinking", detail: "")
            session.costAtStart = session.costUsd
            session.linesAddedAtStart = session.linesAdded
            session.linesRemovedAtStart = session.linesRemoved
        case "PreToolUse":
            session.state = .working
            session.activity = activity(tool: text("tool_name"), input: payload["tool_input"] as? [String: Any] ?? [:])
        case "Notification":
            if ["permission_prompt", "idle_prompt", "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog"]
                .contains(text("notification_type")) {
                session.state = .waiting
            }
        case "Stop" where payload["agent_id"] == nil:
            session.state = .done
            session.activity = nil
            session.lastMessage = truncate(text("last_assistant_message").trimmingCharacters(in: .whitespacesAndNewlines), messageLimit)
            if session.model == nil, let model = payload["model"] as? String { session.model = model }
            var cost: Double?
            if let now = session.costUsd { cost = session.costAtStart.map { max(0, now - $0) } ?? now }
            let task = TaskSummary(
                costUsd: cost,
                durationSecs: max(0, (now - session.startedAt) / 1000),
                linesAdded: session.linesAdded.map { max(0, $0 - (session.linesAddedAtStart ?? 0)) },
                linesRemoved: session.linesRemoved.map { max(0, $0 - (session.linesRemovedAtStart ?? 0)) })
            session.lastTask = task
            return task
        default:
            break
        }
        return nil
    }

    @discardableResult
    static func applyCodexNotify(_ sessions: inout Sessions, _ payload: [String: Any], now: Int64) -> TaskSummary? {
        guard payload["type"] as? String == "agent-turn-complete" else { return nil }
        let thread = (payload["thread-id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "codex"
        let id = "codex-\(thread)"
        var session = sessions[id] ?? AgentSession(id: id, source: "codex", now: now)
        session.cwd = payload["cwd"] as? String ?? ""
        session.project = AgentEvents.projectName(session.cwd)
        session.state = .done
        session.updatedAt = now
        session.activity = nil
        session.lastMessage = truncate((payload["last-assistant-message"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), messageLimit)
        if let prompt = (payload["input-messages"] as? [String])?.last {
            session.lastPrompt = truncate(prompt.trimmingCharacters(in: .whitespacesAndNewlines), promptLimit)
        }
        let task = TaskSummary(costUsd: nil, durationSecs: 0, linesAdded: nil, linesRemoved: nil)
        session.lastTask = task
        sessions[id] = session
        return task
    }

    static func applyStatusLine(_ sessions: inout Sessions, _ payload: [String: Any], now: Int64) {
        guard let id = payload["session_id"] as? String else { return }
        var session = sessions[id] ?? AgentSession(id: id, now: now)
        session.updatedAt = max(session.updatedAt, now)
        let number = { (value: Any?) -> Double? in (value as? NSNumber).map(\.doubleValue).flatMap { $0.isFinite ? $0 : nil } }
        let cost = payload["cost"] as? [String: Any]
        session.costUsd = number(cost?["total_cost_usd"]) ?? session.costUsd
        session.linesAdded = number(cost?["total_lines_added"]).map { Int64($0) } ?? session.linesAdded
        session.linesRemoved = number(cost?["total_lines_removed"]).map { Int64($0) } ?? session.linesRemoved
        if let model = payload["model"] as? [String: Any], let name = (model["display_name"] ?? model["id"]) as? String {
            session.model = name
        }
        if let cwd = payload["cwd"] as? String {
            session.cwd = cwd
            session.project = AgentEvents.projectName(cwd)
        }
        sessions[id] = session
    }

    static func prune(_ sessions: inout Sessions, now: Int64) {
        sessions = sessions.filter { now - $0.value.updatedAt < expiryMs }
    }

    static func load() -> Sessions {
        guard let data = try? Data(contentsOf: AppPaths.agentSessions) else { return [:] }
        return (try? JSONDecoder().decode(Sessions.self, from: data)) ?? [:]
    }

    /// Read-modify-write under an exclusive lock so hooks from parallel
    /// sessions never lose each other's updates.
    @discardableResult
    static func update<T>(_ change: (inout Sessions) -> T) throws -> T {
        try LockedFile.update(AppPaths.agentSessions, as: Sessions.self, default: [:], change)
    }
}

/// Exclusive-lock read-modify-write of a small JSON file.
enum LockedFile {
    static func update<Value: Codable, T>(_ url: URL, as type: Value.Type, default empty: Value,
                                          _ change: (inout Value) -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.path, O_RDWR | O_CREAT, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        defer { flock(fd, LOCK_UN) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let data = try handle.readToEnd() ?? Data()
        var value = (try? JSONDecoder().decode(Value.self, from: data)) ?? empty
        let result = change(&value)
        let encoded = try JSONEncoder().encode(value)
        guard ftruncate(fd, 0) == 0 else { throw CocoaError(.fileWriteUnknown) }
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: encoded)
        return result
    }
}

// MARK: - Weekly statistics

struct DayStats: Codable, Equatable, Sendable {
    var claudeTasks = 0
    var codexTasks = 0
    var costUsd = 0.0
    var linesAdded: Int64 = 0
    var linesRemoved: Int64 = 0
    var busySeconds: Int64 = 0
    var models: [String: Int] = [:]
    var projects: [String: Int] = [:]
}

struct WeekSummary: Equatable, Sendable {
    var from = ""
    var to = ""
    var claudeTasks = 0
    var codexTasks = 0
    var costUsd = 0.0
    var linesAdded: Int64 = 0
    var linesRemoved: Int64 = 0
    var busyHours = 0.0
    var topModel: String?
    var topProject: String?
    /// Date of the busiest day.
    var busiestDay: Date?
    var dailyTasks: [Int] = []

    var tasks: Int { claudeTasks + codexTasks }
}

enum AgentStats {
    typealias Stats = [String: DayStats]

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func record(_ stats: inout Stats, date: Date, source: String, model: String?, project: String,
                       task: TaskSummary, calendar: Calendar = .current) {
        var day = stats[key(date, calendar: calendar)] ?? DayStats()
        if source == "codex" { day.codexTasks += 1 } else { day.claudeTasks += 1 }
        day.costUsd += task.costUsd ?? 0
        day.linesAdded += task.linesAdded ?? 0
        day.linesRemoved += task.linesRemoved ?? 0
        day.busySeconds += task.durationSecs
        if let model, !model.isEmpty { day.models[model, default: 0] += 1 }
        if !project.isEmpty { day.projects[project, default: 0] += 1 }
        stats[key(date, calendar: calendar)] = day
        if let cutoff = calendar.date(byAdding: .day, value: -92, to: date) {
            let limit = key(cutoff, calendar: calendar)
            stats = stats.filter { $0.key >= limit }
        }
    }

    static func weekSummary(_ stats: Stats, today: Date, calendar: Calendar = .current) -> WeekSummary {
        var summary = WeekSummary()
        var models: [String: Int] = [:], projects: [String: Int] = [:]
        var busiest: (Date, Int)?
        var busySeconds: Int64 = 0
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if offset == 6 { summary.from = key(date, calendar: calendar) }
            if offset == 0 { summary.to = key(date, calendar: calendar) }
            let day = stats[key(date, calendar: calendar)]
            let tasks = (day?.claudeTasks ?? 0) + (day?.codexTasks ?? 0)
            summary.dailyTasks.append(tasks)
            guard let day else { continue }
            summary.claudeTasks += day.claudeTasks
            summary.codexTasks += day.codexTasks
            summary.costUsd += day.costUsd
            summary.linesAdded += day.linesAdded
            summary.linesRemoved += day.linesRemoved
            busySeconds += day.busySeconds
            day.models.forEach { models[$0.key, default: 0] += $0.value }
            day.projects.forEach { projects[$0.key, default: 0] += $0.value }
            if tasks > 0, tasks > (busiest?.1 ?? 0) { busiest = (date, tasks) }
        }
        let top = { (map: [String: Int]) in map.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key }
        summary.topModel = top(models)
        summary.topProject = top(projects)
        summary.busiestDay = busiest?.0
        summary.busyHours = (Double(busySeconds) / 3600 * 10).rounded() / 10
        return summary
    }

    static func load() -> Stats {
        guard let data = try? Data(contentsOf: AppPaths.stats) else { return [:] }
        return (try? JSONDecoder().decode(Stats.self, from: data)) ?? [:]
    }

    static func recordNow(source: String, model: String?, project: String, task: TaskSummary) throws {
        try LockedFile.update(AppPaths.stats, as: Stats.self, default: [:]) { stats in
            record(&stats, date: Date(), source: source, model: model, project: project, task: task)
        }
    }
}

/// Turns agent output into short plain text for the panel: pulls the text out
/// of JSON replies and drops Markdown syntax (tables, emphasis, code marks).
enum AgentText {
    static func plain(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("{"), let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let inner = ["summary", "message", "text", "content", "result"].lazy.compactMap({ object[$0] as? String }).first {
            text = inner
        }
        var lines: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            // Table separator rows such as |---|:---:|
            if !line.isEmpty, line.allSatisfy({ "|-: ".contains($0) }), line.contains("-") { continue }
            if line.hasPrefix("|") || line.hasSuffix("|") {
                line = line.trimmingCharacters(in: CharacterSet(charactersIn: "| "))
                    .components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
            }
            while line.hasPrefix("#") { line.removeFirst() }
            if line.hasPrefix("> ") { line.removeFirst(2) }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { line = "• " + line.dropFirst(2) }
            line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "`", with: "")
            lines.append(line.trimmingCharacters(in: .whitespaces))
        }
        var result = lines.joined(separator: "\n")
        while result.contains("\n\n\n") { result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
