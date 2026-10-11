import AppKit

// Crop only the helper title bar; preserve every pixel of the app content.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: crop-screenshot.swift <window-capture> <content-png>")
}
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
guard let bitmap = NSBitmapImageRep(data: try Data(contentsOf: source)),
      let image = bitmap.cgImage,
      let content = image.cropping(to: CGRect(x: 0, y: 64, width: image.width, height: image.height - 64)) else {
    fatalError("Could not crop screenshot")
}
try NSBitmapImageRep(cgImage: content).representation(using: .png, properties: [:])!.write(to: destination)
