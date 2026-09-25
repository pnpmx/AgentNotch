import Foundation
import ServiceManagement

enum LaunchAtLoginController {
    private static var fallbackURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/dev.agentnotch.mac.autostart.plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
            || FileManager.default.fileExists(atPath: fallbackURL.path)
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func enable() throws {
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
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try service.unregister()
        }
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
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
    }
}
