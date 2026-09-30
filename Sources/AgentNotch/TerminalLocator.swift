import AppKit
import Darwin
import Foundation

/// Where an agent session runs: the terminal app and its tab's tty.
struct TerminalLocation: Codable, Equatable, Sendable {
    var bundleID: String?
    /// e.g. /dev/ttys004; identifies a tab in Terminal and iTerm2.
    var tty: String?
}

enum TerminalLocator {
    /// Called from a hook process. The terminal app comes from the
    /// environment; the tty from the nearest ancestor that has one (the hook
    /// itself runs without a terminal, its agent does not).
    static func capture(environment: [String: String] = ProcessInfo.processInfo.environment) -> TerminalLocation? {
        let bundleID = environment["__CFBundleIdentifier"].flatMap { $0.isEmpty ? nil : $0 }
        let tty = ancestorTTY()
        guard bundleID != nil || tty != nil else { return nil }
        return TerminalLocation(bundleID: bundleID, tty: tty)
    }

    private static func processInfo(_ pid: pid_t) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }

    static func ancestorTTY(from start: pid_t = getpid(), maxDepth: Int = 8) -> String? {
        var pid = start
        for _ in 0..<maxDepth {
            guard pid > 1, let info = processInfo(pid) else { return nil }
            let device = info.kp_eproc.e_tdev
            if device != -1 && device != 0, let name = devname(device, S_IFCHR) {
                let tty = String(cString: name)
                if tty.hasPrefix("tty") { return "/dev/" + tty }
            }
            pid = info.kp_eproc.e_ppid
        }
        return nil
    }

    static func isValidTTY(_ tty: String) -> Bool {
        tty.range(of: #"^/dev/ttys?[0-9]+$"#, options: .regularExpression) != nil
    }

    /// AppleScript that selects the tab owning `tty`, for terminals that
    /// support it. Nil for other terminals.
    static func selectTabScript(bundleID: String, tty: String) -> String? {
        guard isValidTTY(tty) else { return nil }
        switch bundleID {
        case "com.apple.Terminal":
            return """
            tell application id "com.apple.Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected of t to true
                            set index of w to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        case "com.googlecode.iterm2":
            return """
            tell application id "com.googlecode.iterm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select w
                                select t
                                select s
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            return false
            """
        default:
            return nil
        }
    }

    enum JumpResult { case tab, app, unavailable }

    /// Brings the session's terminal forward: the exact tab where the terminal
    /// allows it, otherwise the terminal app.
    @MainActor
    static func jump(to location: TerminalLocation) -> JumpResult {
        if let bundleID = location.bundleID, let tty = location.tty,
           let source = selectTabScript(bundleID: bundleID, tty: tty) {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            if error == nil, result?.booleanValue == true { return .tab }
        }
        guard let bundleID = location.bundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return .unavailable
        }
        return app.activate() ? .app : .unavailable
    }
}
