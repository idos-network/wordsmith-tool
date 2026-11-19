import AppKit

// Draws the app icon (aquamarine wand on a dark idOS-style tile) into an .iconset folder for `iconutil`.
// Usage: make-icon <output.iconset>

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    // macOS icon grid: the tile is ~80% of the canvas, leaving room for the shadow
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowBlurRadius = s * 0.025
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    // idOS brand: near-black tile, aquamarine (#00FFB9) outline and wand, like the idOS logo
    let aqua = NSColor(srgbRed: 0, green: 1, blue: 0.725, alpha: 1)
    NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1),
               ending: NSColor(srgbRed: 0.02, green: 0.02, blue: 0.02, alpha: 1))!.draw(in: path, angle: -90)
    let inset = s * 0.045
    let ring = NSBezierPath(roundedRect: tile.insetBy(dx: inset, dy: inset), xRadius: s * 0.14, yRadius: s * 0.14)
    ring.lineWidth = max(1, s * 0.022)
    aqua.withAlphaComponent(0.9).setStroke()
    ring.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.4, weight: .medium)
        .applying(.init(paletteColors: [aqua]))
    if let symbol = NSImage(systemSymbolName: "wand.and.sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let box = symbol.size
        symbol.draw(in: NSRect(x: (s - box.width) / 2, y: (s - box.height) / 2, width: box.width, height: box.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(points * scale).write(to: output.appendingPathComponent(name))
    }
}
