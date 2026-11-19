import AppKit
import Carbon.HIToolbox

// Renders the app's real ChoicePanel in every state the video shows, dark and at 2x, from texts.json.
// Usage: panels <texts.json> <output dir>

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let texts = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
let outDir = CommandLine.arguments[2]

func render(_ panel: ChoicePanel, _ name: String) {
    guard let view = panel.contentView else { return }
    view.layoutSubtreeIfNeeded()
    let size = view.bounds.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print(name, Int(size.width), Int(size.height))
}

func down(_ panel: ChoicePanel) {
    panel.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                         keyCode: UInt16(kVK_DownArrow))!)
}

let panel = ChoicePanel()
panel.appearance = NSAppearance(named: .darkAqua)
panel.showLoading("Polishing your message…")
render(panel, "loading-polish")
panel.showChoices(texts["variants"] as! [String], original: texts["message"] as! String)
for index in 0..<3 {
    render(panel, "choices-\(index)")
    down(panel)
}
panel.showLoading("Summarizing…")
render(panel, "loading-summary")
let summaries = texts["summaries"] as! [String]
panel.showSummary(zip(["English", texts["nativeLanguage"] as! String], summaries).map { (title: $0.0, text: $0.1) })
render(panel, "summary-0")
panel.orderOut(nil)
