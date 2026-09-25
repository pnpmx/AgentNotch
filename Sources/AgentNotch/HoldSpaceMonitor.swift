import AppKit
import ApplicationServices
import CoreGraphics

private let eventMarker: Int64 = 0x414E4F544348

/// Pure press lifecycle, shared by the event tap and regression tests.
struct SpacePress {
    enum State { case idle, pending, speaking, forwarded }
    private(set) var state: State = .idle
    mutating func begin(allowed: Bool, modified: Bool) -> Bool {
        guard state == .idle, allowed, !modified else { return false }
        state = .pending
        return true
    }
    mutating func threshold() -> Bool {
        guard state == .pending else { return false }
        state = .speaking
        return true
    }
    mutating func interruptTyping() -> Bool {
        guard state == .pending else { return false }
        state = .forwarded
        return true
    }
    mutating func release() -> State { let old = state; state = .idle; return old }
}

private func spaceCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                           userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return .passUnretained(event) }
    return Unmanaged<HoldSpaceMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        .handle(proxy: proxy, type: type, event: event)
}

final class HoldSpaceMonitor {
    var onLongPressBegan: (() -> Void)?
    var onLongPressEnded: (() -> Void)?
    var onCancelled: (() -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?
    var onStatus: ((String) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var press = SpacePress()
    private var owner: pid_t?
    private(set) var isAvailable = false
    private(set) var acceptedPresses = 0
    private(set) var completedPresses = 0

    deinit { uninstall() }

    @discardableResult
    func install() -> Bool {
        if let tap, CGEvent.tapIsEnabled(tap: tap) { return true }
        removeTap()
        guard AXIsProcessTrusted() else { publish(false); return false }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: spaceCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { publish(false); return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        publish(CGEvent.tapIsEnabled(tap: tap))
        return isAvailable
    }

    func monitorAccessibilityPermission() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !AXIsProcessTrusted() { self.cancelPress(); self.removeTap(); self.publish(false) }
            else { _ = self.install() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        if observers.isEmpty {
            for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.willSleepNotification,
                         NSWorkspace.sessionDidResignActiveNotification] {
                observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in self?.cancelPress()
                })
            }
        }
    }

    func requestAccessibilityPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        _ = install()
        monitorAccessibilityPermission()
    }

    func uninstall() {
        timer?.invalidate(); timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        cancelPress(); removeTap()
    }

    private func removeTap() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        tap = nil; source = nil
    }

    private func publish(_ available: Bool) {
        isAvailable = available
        onAvailabilityChanged?(available)
        onStatus?(available ? "Space listo" : AXIsProcessTrusted()
            ? "Accesibilidad concedida; captura de teclado no disponible. Reintentando…"
            : "Activa Agent Notch en Ajustes → Privacidad y seguridad → Accesibilidad.")
    }

    private func cancelPress() {
        pending?.cancel(); pending = nil
        let old = press.release()
        owner = nil
        if old == .speaking { onCancelled?() }
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelPress()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true); publish(CGEvent.tapIsEnabled(tap: tap)) }
            return .passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == eventMarker { return .passUnretained(event) }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        // Complete an accepted press even when the destination has changed.
        if type == .keyUp, key == 49, press.state != .idle {
            pending?.cancel(); pending = nil
            let old = press.release()
            let sameOwner = owner == NSWorkspace.shared.frontmostApplication?.processIdentifier
            owner = nil
            if old == .speaking {
                completedPresses += 1
                if sameOwner { onLongPressEnded?() } else { onCancelled?() }
            } else if old == .pending, sameOwner { Self.injectSpace(proxy: proxy) }
            return nil
        }
        if press.state != .idle, owner != NSWorkspace.shared.frontmostApplication?.processIdentifier { cancelPress() }
        if type == .flagsChanged || (type == .keyDown && key != 49) {
            if press.interruptTyping() {
                pending?.cancel(); pending = nil
                Self.injectSpace(proxy: proxy)
            } else if press.state == .speaking { cancelPress() }
            return .passUnretained(event)
        }
        guard key == 49, type == .keyDown else { return .passUnretained(event) }
        if press.state != .idle { return nil }
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
              press.begin(allowed: Self.isSupportedFrontmostApp, modified: !event.flags.intersection(modifiers).isEmpty)
        else { return .passUnretained(event) }
        owner = NSWorkspace.shared.frontmostApplication?.processIdentifier
        acceptedPresses += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.owner == NSWorkspace.shared.frontmostApplication?.processIdentifier,
                  self.press.threshold() else { return }
            self.onLongPressBegan?()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
        return nil
    }

    private static var isSupportedFrontmostApp: Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let bundles = ["com.openai.codex", "com.apple.Terminal", "com.googlecode.iterm2",
                       "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "com.todesktop.230313mzl4w4u92",
                       "com.microsoft.VSCode", "dev.zed.Zed"]
        return bundles.contains { $0.lowercased() == app.bundleIdentifier?.lowercased() }
    }

    private static func injectSpace(proxy: CGEventTapProxy) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: down)
            event?.setIntegerValueField(.eventSourceUserData, value: eventMarker)
            // Insert before the currently processed character, preserving typing order.
            event?.tapPostEvent(proxy)
        }
    }
}
