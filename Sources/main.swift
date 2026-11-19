import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var optionTap = DoubleTap()
    private var controlTap = DoubleTap()
    private let panel = ChoicePanel()
    private var job: Process?
    private var busy = false
    private var generation = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "wand.and.sparkles", accessibilityDescription: "Wordsmith")
        let menu = NSMenu()
        menu.addItem(withTitle: "Rewrite selection   ⌥ ⌥", action: #selector(polish), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Summarize selection   ⌃ ⌃", action: #selector(summarize), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        askForAccessibility()
        watchDoubleTapsWhenTrusted()
    }

    /// Three English versions; the chosen one replaces the selection.
    @objc func polish() {
        begin("Polishing your message…") { [self] text, saved, current in
            var variants: [String] = []
            panel.onPick = { [self] choice in
                job?.terminate()
                job = nil
                guard let choice, choice < variants.count else {
                    TextBridge.restore(saved)
                    busy = false
                    return
                }
                // give the original app a moment to take keyboard focus back from the panel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    TextBridge.paste(variants[choice])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        TextBridge.restore(saved)
                        self.busy = false
                    }
                }
            }
            job = Rewriter.run(text) { [self] result in
                guard current == generation, panel.isVisible else { return }  // cancelled meanwhile
                job = nil
                switch result {
                case .success(let list): variants = list; panel.showChoices(list, original: text)
                case .failure(let error): panel.showError(error.localizedDescription)
                }
            }
        }
    }

    /// A short summary in English and the user's own language, shown in the panel; the picked one is copied.
    /// The selection is never changed.
    @objc func summarize() {
        begin("Summarizing…") { [self] text, saved, current in
            var summaries: [String] = []
            panel.onPick = { [self] choice in
                job?.terminate()
                job = nil
                TextBridge.restore(saved)
                if let choice, choice < summaries.count { TextBridge.put(summaries[choice]) }
                busy = false
            }
            job = Rewriter.summarize(text) { [self] result in
                guard current == generation, panel.isVisible else { return }  // cancelled meanwhile
                job = nil
                switch result {
                case .success(let list):
                    summaries = list
                    let titles = ["English", Rewriter.nativeLanguage].compactMap { $0 }
                    panel.showSummary(Array(zip(titles, list)).map { (title: $0.0, text: $0.1) })
                case .failure(let error): panel.showError(error.localizedDescription)
                }
            }
        }
    }

    /// Copies the selection, then lets `start` set `panel.onPick` and launch the request, and shows the loading panel.
    /// `start` gets the text, the saved clipboard (to restore on every path) and this run's generation.
    private func begin(_ title: String, _ start: @escaping (String, [NSPasteboardItem], Int) -> Void) {
        guard !busy else { return }
        guard AXIsProcessTrusted() else { return askForAccessibility() }
        busy = true
        generation += 1
        let current = generation
        let saved = TextBridge.save()

        TextBridge.copySelection { [self] text in
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                TextBridge.restore(saved)
                busy = false
                return NSSound.beep()
            }
            start(text, saved, current)
            panel.showLoading(title)
        }
    }

    /// Global key monitors only get events once Accessibility is granted, so wait for it instead of needing a relaunch.
    private func watchDoubleTapsWhenTrusted() {
        guard AXIsProcessTrusted() else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.watchDoubleTapsWhenTrusted() }
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return }
            if event.type == .keyDown {
                optionTap.reset()
                controlTap.reset()
                return
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let none = modifiers.isEmpty
            if optionTap.modifiersChanged(only: modifiers == .option, none: none, at: event.timestamp) { polish() }
            if controlTap.modifiersChanged(only: modifiers == .control, none: none, at: event.timestamp) { summarize() }
        }
    }

    private func askForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

signal(SIGPIPE, SIG_IGN)  // writing to claude's stdin after it exited must not kill the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
