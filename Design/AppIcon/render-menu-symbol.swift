import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
context.imageInterpolation = .high
NSColor(srgbRed: 0.965, green: 0.958, blue: 0.94, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 184, yRadius: 184).fill()
let ink = NSColor(srgbRed: 0.16, green: 0.17, blue: 0.18, alpha: 1)
let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .regular).applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
guard let symbol = NSImage(systemSymbolName: "computermouse", accessibilityDescription: nil)?.withSymbolConfiguration(config) else { fatalError("Missing computermouse symbol") }
let aspect = symbol.size.width / symbol.size.height
let height: CGFloat = 476
let width = height * aspect
symbol.draw(in: NSRect(x: (1024-width)/2, y: (1024-height)/2, width: width, height: height), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("menu-symbol-preview.png"))
print("Rendered native computermouse preview")
