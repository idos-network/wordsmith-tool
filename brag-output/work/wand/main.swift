import AppKit

// Draws the app's menu bar symbol (wand.and.sparkles, white, 2x) to a PNG for the video.
// Usage: wand <output.png>

let config = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular).applying(.init(paletteColors: [.white]))
let symbol = NSImage(systemSymbolName: "wand.and.sparkles", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
let size = symbol.size
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
symbol.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wand", Int(size.width), Int(size.height))
