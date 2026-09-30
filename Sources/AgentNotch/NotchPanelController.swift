import AppKit
import Combine
import CoreGraphics
import SwiftUI

/// Borderless panels never take keyboard input by default. This one does only
/// while settings are open, so the vocabulary can be typed; as a
/// non-activating panel it still leaves the frontmost app active.
final class NotchPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
}

@MainActor
final class NotchPanelController {
    private let panel: NotchPanel
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []
    private var hosting: NSHostingView<AnyView>?
    var frame: NSRect { panel.frame }
    var windowNumber: Int { panel.windowNumber }

    init(model: AppModel, show: Bool = true) {
        self.model = model
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        // @Published sends in willSet. Deliver on the next main-loop turn so
        // geometry and SwiftUI both read the same, fully committed model state.
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
        model.$settingsOpen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] open in
                guard let self else { return }
                self.panel.acceptsKeyboard = open
                if open { self.panel.makeKey() } else { self.panel.resignKey() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
        layout()
        if show { panel.orderFrontRegardless() }
    }

    func toggleVisibility() {
        if panel.isVisible { panel.orderOut(nil) }
        else { layout(); panel.orderFrontRegardless() }
    }

    private func layout() {
        guard let screen = Self.preferredScreen else { return }
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let gap = left.flatMap { l in right.map { max(0, $0.minX - l.maxX) } } ?? 0
        let center = left.flatMap { l in right.map { (l.maxX + $0.minX) / 2 } } ?? screen.frame.midX
        let headerHeight = max(32, screen.safeAreaInsets.top)
        let width = min(screen.frame.width, max(model.isExpanded ? 440 : 210, gap + 210))
        let root = AnyView(NotchView(model: model, cameraGap: gap, cameraHeight: headerHeight)
            .frame(width: width).fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .dark))
        if let hosting { hosting.rootView = root }
        else {
            let view = NSHostingView(rootView: root)
            view.sizingOptions = [.intrinsicContentSize]
            hosting = view
            panel.contentView = view
        }
        guard let hosting else { return }
        hosting.invalidateIntrinsicContentSize()
        hosting.layoutSubtreeIfNeeded()
        let height = ceil(hosting.fittingSize.height)
        let x = min(max(screen.frame.minX, center - width / 2), screen.frame.maxX - width)
        panel.setFrame(NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height), display: true)
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        hosting.layoutSubtreeIfNeeded()
    }

    private static var preferredScreen: NSScreen? {
        NSScreen.screens.first(where: {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0 && $0.safeAreaInsets.top > 0
        }) ?? NSScreen.main ?? NSScreen.screens.first
    }
}
