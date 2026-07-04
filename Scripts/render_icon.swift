import AppKit
import Foundation

// Rasterize an SVG to a square PNG. NSImage on macOS Ventura+ handles SVG natively.
// Used by Scripts/make_icon.sh to produce the sizes iconutil expects.
guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: render_icon <in.svg> <size> <out.png>\n".utf8))
    exit(64)
}
let src = CommandLine.arguments[1]
let size = Int(CommandLine.arguments[2]) ?? 1024
let dst = CommandLine.arguments[3]

guard let img = NSImage(contentsOfFile: src) else {
    FileHandle.standardError.write(Data("NSImage load failed for \(src)\n".utf8))
    exit(1)
}

let px = CGFloat(size)
let target = NSImage(size: NSSize(width: px, height: px))
target.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
img.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
         from: .zero, operation: .sourceOver, fraction: 1.0)
target.unlockFocus()

guard let tiff = target.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG encoding failed\n".utf8))
    exit(2)
}
try png.write(to: URL(fileURLWithPath: dst))
