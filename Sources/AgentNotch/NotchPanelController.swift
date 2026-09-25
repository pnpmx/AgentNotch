import AppKit
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        let initialScreen = Self.preferredScreen
        let cameraGap = initialScreen.map(Self.cameraWidth(on:)) ?? 180
        let cameraHeight = initialScreen.map(Self.cameraHeight(on:)) ?? 38
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.contentView = NSHostingView(
            rootView: NotchView(
                model: model,
                cameraGap: cameraGap,
                cameraHeight: cameraHeight
            )
        )

        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] _ in self?.resizeForCurrentContent(animated: true) }
            .store(in: &cancellables)
        model.$liveTranscript
            .map { !$0.isEmpty }
            .removeDuplicates()
            .sink { [weak self] _ in self?.resizeForCurrentContent(animated: true) }
            .store(in: &cancellables)
        model.$codexUsage
            .sink { [weak self] _ in self?.resizeForCurrentContent(animated: true) }
            .store(in: &cancellables)
        model.$claudeUsage
            .sink { [weak self] _ in self?.resizeForCurrentContent(animated: true) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.screenParametersDidChange() }
            .store(in: &cancellables)

        resizeForCurrentContent(animated: false)
        panel.orderFrontRegardless()
    }

    func toggleVisibility() {
        if panel.isVisible { panel.orderOut(nil) }
        else { panel.orderFrontRegardless() }
    }

    private func screenParametersDidChange() {
        guard let screen = Self.preferredScreen else { return }
        panel.contentView = NSHostingView(
            rootView: NotchView(
                model: model,
                cameraGap: Self.cameraWidth(on: screen),
                cameraHeight: Self.cameraHeight(on: screen)
            )
        )
        resizeForCurrentContent(animated: false)
    }

    private func resizeForCurrentContent(animated _: Bool) {
        guard let screen = Self.preferredScreen else { return }
        let cameraWidth = Self.cameraWidth(on: screen)
        let cameraHeight = Self.cameraHeight(on: screen)
        let compactWidth = max(370, cameraWidth + 190)
        let compactHeight = max(44, cameraHeight + 6)
        let rowCount = max(model.codexUsage?.windows.prefix(2).count ?? 1,
                           model.claudeUsage?.windows.prefix(2).count ?? 1)
        let extraWindowHeight = CGFloat(max(0, rowCount - 1)) * 64
        let transcriptHeight: CGFloat = model.liveTranscript.isEmpty ? 0 : 52
        // Content starts below the physical camera housing plus a separate
        // breathing zone. Account for that zone in the panel height as well.
        let desiredExpandedHeight = 294 + extraWindowHeight + transcriptHeight
        let expandedHeight = min(desiredExpandedHeight, screen.frame.height - 80)
        let size = NSSize(width: model.isExpanded ? max(430, compactWidth) : compactWidth,
                          height: model.isExpanded ? expandedHeight : compactHeight)
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        // AppKit window-frame animation can be superseded by SwiftUI's own
        // transition, leaving the window expanded after its content collapsed.
        // The content still animates; window geometry always lands immediately.
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }

    private static var preferredScreen: NSScreen? {
        let screens = NSScreen.screens
        return screens.first(where: { isBuiltIn($0) && $0.safeAreaInsets.top > 0 })
            ?? screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? screens.first
    }

    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }

    private static func cameraWidth(on screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 180 }
        return max(0, right.minX - left.maxX)
    }

    private static func cameraHeight(on screen: NSScreen) -> CGFloat {
        let auxiliaryHeight = max(
            screen.auxiliaryTopLeftArea?.height ?? 0,
            screen.auxiliaryTopRightArea?.height ?? 0
        )
        return max(38, screen.safeAreaInsets.top, auxiliaryHeight)
    }
}
