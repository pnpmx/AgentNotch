import Foundation

/// Agent activity reported by Claude Code hooks and Codex's `notify` program.
/// Both run `AgentNotch --agent-event <source>`; the payload is normalised and
/// appended to a small file the app watches.
struct AgentEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case done, permission, needsInput
    }

    let source: String
    let kind: Kind
    let message: String
    let project: String
    /// Unix milliseconds; also the identifier.
    let at: Int64
    var sessionID: String?
    /// Cost, duration and lines for a finished task, when known.
    var task: TaskSummary?

    enum CodingKeys: String, CodingKey {
        case source, kind, message, project, at, task
        case sessionID = "sessionId"
    }

    var id: Int64 { at }
    var agentName: String { source == "codex" ? "Codex" : "Claude" }

    var title: String {
        switch kind {
        case .done: return tr("%@ finished", agentName)
        case .permission: return tr("%@ needs your approval", agentName)
        case .needsInput: return tr("%@ is waiting for you", agentName)
        }
    }
}

enum AgentEvents {
    static let flag = "--agent-event"
    private static let keep = 20
    private static let messageLimit = 160

    static func projectName(_ cwd: String?) -> String {
        guard let cwd else { return "" }
        let trimmed = cwd.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
        return trimmed.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? ""
    }

    static func shorten(_ text: String) -> String {
        let single = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard single.count > messageLimit else { return single }
        return String(single.prefix(messageLimit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Returns nil for activity that should not interrupt the user, such as
    /// subagent completions or authentication notices.
    static func fromClaudeHook(_ payload: [String: Any], at: Int64) -> AgentEvent? {
        let text = { (key: String) in payload[key] as? String }
        let kind: AgentEvent.Kind
        let message: String
        switch text("hook_event_name") {
        case "Stop":
            guard payload["agent_id"] == nil else { return nil }
            kind = .done
            message = text("last_assistant_message") ?? ""
        case "Notification":
            switch text("notification_type") {
            case "permission_prompt": kind = .permission
            case "idle_prompt", "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog": kind = .needsInput
            default: return nil
            }
            message = text("message") ?? ""
        default:
            return nil
        }
        return AgentEvent(source: "claude", kind: kind, message: shorten(message),
                          project: projectName(text("cwd")), at: at, sessionID: text("session_id"))
    }

    static func fromCodexNotify(_ raw: String, at: Int64) -> AgentEvent? {
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let kind: AgentEvent.Kind
        switch payload["type"] as? String {
        case "agent-turn-complete": kind = .done
        case "approval-requested": kind = .permission
        default: return nil
        }
        return AgentEvent(source: "codex", kind: kind,
                          message: shorten(payload["last-assistant-message"] as? String ?? ""),
                          project: projectName(payload["cwd"] as? String), at: at,
                          sessionID: (payload["thread-id"] as? String).map { "codex-\($0)" })
    }

    static func load() -> [AgentEvent] {
        guard let data = try? Data(contentsOf: AppPaths.agentEvents) else { return [] }
        return (try? JSONDecoder().decode([AgentEvent].self, from: data)) ?? []
    }

    static func append(_ event: AgentEvent) throws {
        var events = load()
        events.append(event)
        if events.count > keep { events.removeFirst(events.count - keep) }
        try AppPaths.writeAtomically(try JSONEncoder().encode(events), to: AppPaths.agentEvents)
    }

    /// Entry point for `--agent-event claude|codex`. Hooks must never block
    /// or fail an agent, so this always exits 0 and prints nothing.
    static func run(arguments: [String]) -> Int32 {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return 0 }
        let at = Int64(Date().timeIntervalSince1970 * 1000)
        var event: AgentEvent?
        var finished: (TaskSummary, AgentSession)?
        switch arguments[index + 1] {
        case "claude":
            let input = FileHandle.standardInput.readDataToEndOfFile()
            guard let payload = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] else { return 0 }
            finished = try? AgentSessions.update { sessions in
                AgentSessions.prune(&sessions, now: at)
                let task = AgentSessions.applyClaudeHook(&sessions, payload, now: at)
                let session = (payload["session_id"] as? String).flatMap { sessions[$0] }
                return task.flatMap { t in session.map { (t, $0) } }
            } ?? nil
            event = fromClaudeHook(payload, at: at)
        case "codex":
            // Codex appends the JSON payload as the final argument.
            let raw = arguments.last ?? ""
            let payload = (raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any] ?? [:]
            finished = try? AgentSessions.update { sessions in
                AgentSessions.prune(&sessions, now: at)
                let task = AgentSessions.applyCodexNotify(&sessions, payload, now: at)
                let thread = (payload["thread-id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "codex"
                return task.flatMap { t in sessions["codex-\(thread)"].map { (t, $0) } }
            } ?? nil
            event = fromCodexNotify(raw, at: at)
        default:
            break
        }
        if let (task, session) = finished {
            try? AgentStats.recordNow(source: session.source, model: session.model, project: session.project, task: task)
        }
        if var event {
            if event.kind == .done { event.task = finished?.0 }
            try? append(event)
        }
        return 0
    }
}
