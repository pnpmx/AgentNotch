import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private let agentNotchEventMarker: Int64 = 0x414E4F544348

private func holdSpaceEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HoldSpaceMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}

final class HoldSpaceMonitor {
    var onLongPressBegan: (() -> Void)?
    var onLongPressEnded: (() -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pendingWork: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var permissionAttempts = 0
    private var keyIsDown = false
    private var longPressActive = false

    deinit { uninstall() }

    @discardableResult
    func install() -> Bool {
        removeEventTap()
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: holdSpaceEventCallback,
            userInfo: pointer
        ) else {
            onAvailabilityChanged?(false)
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        permissionTimer?.invalidate()
        permissionTimer = nil
        onAvailabilityChanged?(true)
        return true
    }

    func uninstall() {
        removeEventTap()
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func removeEventTap() {
        pendingWork?.cancel()
        pendingWork = nil
        keyIsDown = false
        longPressActive = false
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        runLoopSource = nil
        tap = nil
    }

    func requestAccessibilityPermission() {
        if AXIsProcessTrusted() {
            if !install() { monitorAccessibilityPermission() }
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        monitorAccessibilityPermission()
    }

    func monitorAccessibilityPermission() {
        permissionTimer?.invalidate()
        permissionAttempts = 0
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.permissionAttempts += 1
            if AXIsProcessTrusted() {
                if self.install() {
                    timer.invalidate()
                    self.permissionTimer = nil
                } else if self.permissionAttempts >= 120 {
                    timer.invalidate()
                    self.permissionTimer = nil
                    self.onAvailabilityChanged?(false)
                }
            } else if self.permissionAttempts >= 120 {
                timer.invalidate()
                self.permissionTimer = nil
                self.onAvailabilityChanged?(false)
            }
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == agentNotchEventMarker {
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.keyboardEventKeycode) == 49, Self.isSupportedFrontmostApp else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                DispatchQueue.main.async { [weak self] in self?.beginPendingPress() }
            }
            return nil
        }
        if type == .keyUp {
            DispatchQueue.main.async { [weak self] in self?.finishPress() }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func beginPendingPress() {
        guard !keyIsDown else { return }
        keyIsDown = true
        longPressActive = false
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.keyIsDown else { return }
            self.longPressActive = true
            self.onLongPressBegan?()
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
    }

    private func finishPress() {
        guard keyIsDown else { return }
        keyIsDown = false
        pendingWork?.cancel()
        pendingWork = nil
        if longPressActive {
            longPressActive = false
            onLongPressEnded?()
        } else {
            Self.injectSpace()
        }
    }

    private static var isSupportedFrontmostApp: Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let name = (app.localizedName ?? "").lowercased()
        let bundle = (app.bundleIdentifier ?? "").lowercased()
        let allowedNames = ["codex", "terminal", "iterm", "warp", "ghostty", "cursor", "visual studio code", "zed"]
        let allowedBundles = ["com.openai.codex", "com.apple.terminal", "com.googlecode.iterm2", "dev.warp.warp-stable", "com.mitchellh.ghostty"]
        return allowedNames.contains(where: name.contains) || allowedBundles.contains(where: bundle.contains)
    }

    private static func injectSpace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false)
        down?.setIntegerValueField(.eventSourceUserData, value: agentNotchEventMarker)
        up?.setIntegerValueField(.eventSourceUserData, value: agentNotchEventMarker)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
