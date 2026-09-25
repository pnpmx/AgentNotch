import AppKit
import ApplicationServices
import Combine
import Darwin
import Foundation
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let cyclesLayout = CommandLine.arguments.contains("--layout-cycle-preview")
        if CommandLine.arguments.contains("--expanded-preview") || cyclesLayout {
            model.isExpanded = true
        }
        panelController = NotchPanelController(model: model)
        configureStatusItem()
        enableLaunchAtLoginIfNeeded()
        model.start()
        if cyclesLayout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.model.isExpanded = false
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: "Agent Notch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Mostrar / ocultar notch", action: #selector(togglePanel), keyEquivalent: "n")
        menu.addItem(withTitle: "Actualizar límites", action: #selector(refreshUsage), keyEquivalent: "r")
        menu.addItem(withTitle: "Conectar Claude Code", action: #selector(connectClaude), keyEquivalent: "")
        accessibilityItem = menu.addItem(withTitle: "Activar Space to Speak", action: #selector(requestAccessibility), keyEquivalent: "")
        let loginItem = menu.addItem(withTitle: "Abrir al iniciar sesión", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem = loginItem
        updateLaunchAtLoginMenu()
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
        model.$accessibilityReady
            .removeDuplicates()
            .sink { [weak self] ready in
                self?.accessibilityItem?.title = ready ? "Space to Speak activo" : "Activar Space to Speak"
                self?.accessibilityItem?.state = ready ? .on : .off
            }
            .store(in: &cancellables)
    }

    @objc private func togglePanel() { panelController?.toggleVisibility() }
    @objc private func refreshUsage() { Task { await model.refreshAll() } }
    @objc private func connectClaude() { model.connectClaude() }
    @objc private func requestAccessibility() { model.requestAccessibility() }
    @objc private func toggleLaunchAtLogin() {
        do {
            if LaunchAtLoginController.isEnabled {
                try LaunchAtLoginController.disable()
            } else {
                try LaunchAtLoginController.enable()
            }
        } catch {
            model.notice = "Inicio automático: \(error.localizedDescription)"
        }
        updateLaunchAtLoginMenu()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func enableLaunchAtLoginIfNeeded() {
        guard !LaunchAtLoginController.isEnabled else {
            updateLaunchAtLoginMenu()
            return
        }
        do {
            try LaunchAtLoginController.enable()
        } catch {
            model.notice = "Activa Agent Notch en Ítems de inicio."
        }
        updateLaunchAtLoginMenu()
    }

    private func updateLaunchAtLoginMenu() {
        launchAtLoginItem?.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem?.toolTip = LaunchAtLoginController.requiresApproval
            ? "macOS necesita aprobación en Ajustes del Sistema."
            : nil
    }
}

if CommandLine.arguments.contains("--claude-bridge") {
    exit(ClaudeBridgeRunner.run())
}
if CommandLine.arguments.contains("--self-test") {
    exit(SelfTests.run())
}
if CommandLine.arguments.contains("--login-item-status") {
    print(String(describing: SMAppService.mainApp.status))
    exit(0)
}
if CommandLine.arguments.contains("--accessibility-status") {
    print(AXIsProcessTrusted() ? "trusted" : "not-trusted")
    exit(0)
}
if CommandLine.arguments.contains("--event-tap-status") {
    let monitor = HoldSpaceMonitor()
    print(monitor.install() ? "event-tap-ready" : "event-tap-unavailable")
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
    withExtendedLifetime(delegate) {}
}
