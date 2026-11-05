import AppKit
// Renders SF Symbols as black-on-white PNGs (bitmap.swift <outDir> <name>...).
let args = Array(CommandLine.arguments.dropFirst())
let out = URL(fileURLWithPath: args[0])
for name in args.dropFirst() {
    let cfg = NSImage.SymbolConfiguration(pointSize: 80, weight: .regular)
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { print("missing \(name)"); continue }
    let size = NSSize(width: 160, height: 160)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 160, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.white.setFill(); NSRect(origin: .zero, size: size).fill()
    let r = NSRect(x: (160 - img.size.width) / 2, y: (160 - img.size.height) / 2, width: img.size.width, height: img.size.height)
    img.draw(in: r)
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name).png"))
}
print("done")
