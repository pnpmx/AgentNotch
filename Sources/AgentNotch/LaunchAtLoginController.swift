import Foundation
import ServiceManagement
import Darwin

enum LaunchAtLoginController {
    private static var fallbackURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/dev.agentnotch.mac.autostart.plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
            || (FileManager.default.fileExists(atPath: fallbackURL.path) && launchctl(["print", "gui/\(getuid())/dev.agentnotch.mac.autostart"]) == 0)
    }

    static var shouldEnableOnLaunch: Bool {
        UserDefaults.standard.object(forKey: "launchAtLoginWanted") == nil
            || UserDefaults.standard.bool(forKey: "launchAtLoginWanted")
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func enable() throws {
        UserDefaults.standard.set(true, forKey: "launchAtLoginWanted")
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
        case .notRegistered:
            try service.register()
        case .notFound:
            try installFallbackLaunchAgent()
        @unknown default:
            try installFallbackLaunchAgent()
        }
    }

    static func disable() throws {
        UserDefaults.standard.set(false, forKey: "launchAtLoginWanted")
        let service = SMAppService.mainApp
        if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            _ = launchctl(["bootout", "gui/\(getuid())/dev.agentnotch.mac.autostart"])
            try FileManager.default.removeItem(at: fallbackURL)
        }
    }

    private static func installFallbackLaunchAgent() throws {
        let directory = fallbackURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let propertyList: [String: Any] = [
            "Label": "dev.agentnotch.mac.autostart",
            "ProgramArguments": ["/usr/bin/open", "-g", Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: fallbackURL, options: .atomic)
        guard launchctl(["bootstrap", "gui/\(getuid())", fallbackURL.path]) == 0 || isEnabled else {
            throw NSError(domain: "AgentNotch.Login", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo registrar el inicio automático."])
        }
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit(); return process.terminationStatus }
        catch { return -1 }
    }
}
