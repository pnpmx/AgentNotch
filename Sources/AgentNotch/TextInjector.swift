import AppKit
import ApplicationServices

struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
    }
    func restore(to pasteboard: NSPasteboard, ifUnchanged changeCount: Int) {
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        let restored = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

@MainActor
enum TextInjector {
    enum Result { case attempted, destinationChanged, unavailable }
    private static var restoring: Task<Void, Never>?

    static func paste(_ text: String, into target: pid_t) -> Result {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target else { return .destinationChanged }
        guard !text.isEmpty, AXIsProcessTrusted(), restoring == nil,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return .unavailable }
        let pasteboard = NSPasteboard.general
        let previous = ClipboardSnapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let count = pasteboard.changeCount
        down.flags = .maskCommand; up.flags = .maskCommand
        // Address the original process; never send the paste to a new frontmost app.
        down.postToPid(target); up.postToPid(target)
        restoring = Task {
            try? await Task.sleep(for: .seconds(1))
            previous.restore(to: pasteboard, ifUnchanged: count)
            restoring = nil
        }
        return .attempted
    }
}
