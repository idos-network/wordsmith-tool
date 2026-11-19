import AppKit
import Carbon.HIToolbox

/// Reads and replaces the selection in the active app via the clipboard and simulated ⌘C / ⌘V.
enum TextBridge {
    static func save() -> [NSPasteboardItem] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    static func restore(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }

    /// Simulates ⌘C once the shortcut's keys are released; `nil` when nothing got copied.
    static func copySelection(_ done: @escaping (String?) -> Void) {
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        // ⌥ still held from the double tap would turn our ⌘C into ⌥⌘C
        poll(tries: 20, { NSEvent.modifierFlags.isDisjoint(with: modifiers) }) { _ in
            let pasteboard = NSPasteboard.general
            let before = pasteboard.changeCount
            press(kVK_ANSI_C)
            // generous wait: a copy landing after we restore the clipboard would overwrite it
            poll(tries: 60, { pasteboard.changeCount != before }) { copied in
                done(copied ? pasteboard.string(forType: .string) : nil)
            }
        }
    }

    static func put(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func paste(_ text: String) {
        put(text)
        press(kVK_ANSI_V)
    }

    private static func press(_ key: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Checks `condition` every 25 ms, up to `tries` times.
    private static func poll(tries: Int, _ condition: @escaping () -> Bool, then: @escaping (Bool) -> Void) {
        if condition() { return then(true) }
        if tries == 0 { return then(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { poll(tries: tries - 1, condition, then: then) }
    }
}
