import Darwin
import Foundation

/// Which agents are alive right now: interactive `claude` and `codex`
/// processes attached to a terminal. Background helpers (such as Codex's app
/// server daemon, or the one AgentNotch starts for usage) have no terminal
/// and are not counted.
struct AgentPresence: Equatable, Sendable {
    var claude = 0
    var codex = 0

    var isEmpty: Bool { claude == 0 && codex == 0 }

    static func current() -> AgentPresence {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return AgentPresence() }
        // The process table can grow between the two calls; leave headroom.
        let capacity = size / MemoryLayout<kinfo_proc>.stride + 32
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: capacity)
        size = capacity * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, u_int(mib.count), &processes, &size, nil, 0) == 0 else { return AgentPresence() }
        let count = size / MemoryLayout<kinfo_proc>.stride
        var presence = AgentPresence()
        for process in processes.prefix(count) {
            let device = process.kp_eproc.e_tdev
            guard device != -1 && device != 0 else { continue }
            var command = process.kp_proc.p_comm
            let name = withUnsafeBytes(of: &command) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            switch agent(named: name, pid: process.kp_proc.p_pid) {
            case "claude": presence.claude += 1
            case "codex": presence.codex += 1
            default: break
            }
        }
        return presence
    }

    /// Claude Code's native installer names the binary after its version
    /// (…/claude/versions/2.1.285), so the executable path decides.
    static func agent(named name: String, pid: pid_t) -> String? {
        if name == "claude" || name == "codex" { return name }
        guard name.first?.isNumber == true else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return classify(path: String(cString: buffer))
    }

    static func classify(path: String) -> String? {
        if path.contains("/claude/versions/") { return "claude" }
        if path.contains("/codex/") && path.hasSuffix("/codex") { return "codex" }
        return nil
    }
}
