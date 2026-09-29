import AppKit
import ApplicationServices
import Combine
import Darwin
import Foundation
import ServiceManagement
import AVFoundation
import Speech

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var cancellables: Set<AnyCancellable> = []
    private var diagnosticTimer: Timer?
    private var layoutChecks: [Bool] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != getpid() && !$0.isTerminated }) {
            NSApp.terminate(nil)
            return
        }
        let cyclesLayout = CommandLine.arguments.contains("--layout-cycle-preview")
        if CommandLine.arguments.contains("--expanded-preview") || cyclesLayout {
            model.isExpanded = true
        }
        panelController = NotchPanelController(model: model)
        configureStatusItem()
        enableLaunchAtLoginIfNeeded()
        model.start()
        if CommandLine.arguments.contains("--diagnostics") {
            diagnosticTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.writeDiagnostics() }
            }
        }
        if CommandLine.arguments.contains("--gui-layout-check") {
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(1))
                let compact = self.panelController?.frame.height ?? 0
                for _ in 0..<4 {
                    self.model.isExpanded = true
                    try? await Task.sleep(for: .milliseconds(200))
                    self.layoutChecks.append((self.panelController?.frame.height ?? 0) > compact + 50)
                    self.model.isExpanded = false
                    try? await Task.sleep(for: .milliseconds(200))
                    self.layoutChecks.append(abs((self.panelController?.frame.height ?? 0) - compact) < 1)
                }
                self.writeDiagnostics()
            }
        }
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
        statusItem = item
        model.$uiLanguage
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildStatusMenu() }
            .store(in: &cancellables)
        model.$accessibilityReady
            .removeDuplicates()
            .sink { [weak self] ready in self?.updateAccessibilityItem(ready: ready) }
            .store(in: &cancellables)
    }

    /// Rebuilt whenever the interface language changes.
    private func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: tr("Show / hide notch"), action: #selector(togglePanel), keyEquivalent: "n")
        menu.addItem(withTitle: tr("Refresh limits"), action: #selector(refreshUsage), keyEquivalent: "r")
        menu.addItem(withTitle: tr("Connect Claude Code"), action: #selector(connectClaude), keyEquivalent: "")
        menu.addItem(withTitle: tr("Copy diagnostics"), action: #selector(copyDiagnostics), keyEquivalent: "")
        accessibilityItem = menu.addItem(withTitle: "", action: #selector(requestAccessibility), keyEquivalent: "")
        launchAtLoginItem = menu.addItem(withTitle: tr("Open at login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

        let languageMenu = NSMenu()
        for language in UILanguage.allCases {
            let entry = languageMenu.addItem(withTitle: language.nativeName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.representedObject = language.rawValue
            entry.state = model.uiLanguage == language ? .on : .off
            entry.target = self
        }
        let languageItem = menu.addItem(withTitle: tr("Interface language"), action: nil, keyEquivalent: "")
        menu.setSubmenu(languageMenu, for: languageItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: tr("Quit"), action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { if $0.action != nil { $0.target = self } }
        statusItem?.menu = menu
        updateAccessibilityItem(ready: model.accessibilityReady)
        updateLaunchAtLoginMenu()
    }

    private func updateAccessibilityItem(ready: Bool) {
        accessibilityItem?.title = ready ? tr("Space to Speak active") : tr("Enable Space to Speak")
        accessibilityItem?.state = ready ? .on : .off
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = UILanguage(rawValue: raw) else { return }
        model.uiLanguage = language
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
            model.notice = tr("Launch at login: %@", error.localizedDescription)
        }
        updateLaunchAtLoginMenu()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private var diagnostics: [String: Any] {
        var values = model.keyboardDiagnostics
        values["pid"] = getpid()
        values["version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        values["accessibilityTrusted"] = AXIsProcessTrusted()
        values["microphoneAuthorized"] = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        values["speechAuthorized"] = SFSpeechRecognizer.authorizationStatus() == .authorized
        values["expanded"] = model.isExpanded
        values["panelHeight"] = panelController?.frame.height ?? 0
        values["panelWidth"] = panelController?.frame.width ?? 0
        values["windowNumber"] = panelController?.windowNumber ?? 0
        values["layoutChecks"] = layoutChecks
        // Never include keystrokes, transcripts, clipboard content or account data.
        return values
    }

    @objc private func copyDiagnostics() {
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func writeDiagnostics() {
        do {
            let directory = AppPaths.supportDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("diagnostics.json")
            let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { /* Optional diagnostics must never interrupt dictation. */ }
    }

    private func enableLaunchAtLoginIfNeeded() {
        guard LaunchAtLoginController.shouldEnableOnLaunch else { updateLaunchAtLoginMenu(); return }
        guard !LaunchAtLoginController.isEnabled else {
            updateLaunchAtLoginMenu()
            return
        }
        do {
            try LaunchAtLoginController.enable()
        } catch {
            model.notice = tr("Enable Agent Notch in Login Items.")
        }
        updateLaunchAtLoginMenu()
    }

    private func updateLaunchAtLoginMenu() {
        launchAtLoginItem?.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem?.toolTip = LaunchAtLoginController.requiresApproval
            ? tr("macOS needs approval in System Settings.")
            : nil
    }
}

if CommandLine.arguments.contains("--claude-bridge") {
    exit(ClaudeBridgeRunner.run())
}
if CommandLine.arguments.contains("--regression-test") {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        Task { @MainActor in exit(await RegressionTests.run()) }
        app.run()
    }
    exit(1)
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
