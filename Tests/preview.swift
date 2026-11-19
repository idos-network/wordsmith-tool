import AppKit

// Renders the choice panel with sample texts to build/preview-<state>-<theme>.png. Run with `./build.sh preview`.

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// cspell:disable-next-line -- deliberately Czech sample input
let original = "Ahoj, zítra to nestihnu, pošlu to v pátek. Sorry 🙏"
let variants = [
    "Hi, unfortunately I won't be able to finish this by tomorrow. I'll send it over on Friday instead. Apologies for the delay.",
    "Can't make tomorrow — sending it Friday. Sorry!",
    "Hey, won't get it done tomorrow, but you'll have it Friday! Sorry 🙏",
]

func render(_ panel: ChoicePanel, _ name: String) {
    guard let view = panel.contentView else { return }
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    let url = URL(fileURLWithPath: "build/preview-\(name).png")
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
    print("wrote \(url.path) \(Int(view.bounds.width))×\(Int(view.bounds.height))")
}

for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
    let panel = ChoicePanel()
    panel.appearance = NSAppearance(named: appearance)
    panel.showLoading("Polishing your message…")
    render(panel, "loading-\(theme)")
    panel.showChoices(variants, original: original)
    render(panel, "choices-\(theme)")
    panel.showSummary([
        (title: "English", text: """
        The client wants the database migration done by end of month, but the team likely won't make it.

        - Martin is on vacation next week.
        - Peter will ask the client to move the deadline at Thursday's call.
        - About 12k EUR of the Q4 budget is left.
        """),
        // cspell:disable-next-line -- deliberately Czech sample
        (title: "Czech", text: "Klient chce migraci databáze do konce měsíce, tým to nejspíš nestihne.\n\n- Martin má příští týden dovolenou.\n- Petr požádá klienta o posun termínu na čtvrtečním callu.\n- Z rozpočtu na Q4 zbývá asi 12k EUR."),
    ])
    render(panel, "summary-\(theme)")
    panel.showError("Failed to authenticate: OAuth session expired and could not be refreshed")
    render(panel, "error-\(theme)")
    panel.orderOut(nil)
}
