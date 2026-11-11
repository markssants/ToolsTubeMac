// Gera o ícone do app (1024×1024 PNG) no estilo macOS.
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

// sombra
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.36, blue: 0.30, alpha: 1),
    NSColor(calibratedRed: 0.86, green: 0.07, blue: 0.24, alpha: 1),
])!
gradient.draw(in: path, angle: -90)

// brilho superior
NSGraphicsContext.saveGraphicsState()
path.addClip()
let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
gloss.draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

func symbol(_ name: String, pt: CGFloat, weight: NSFont.Weight) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: weight)
        .applying(.init(paletteColors: [.white]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
}

let main = symbol("play.rectangle.fill", pt: 420, weight: .semibold)
let ms = main.size
let mainRect = NSRect(x: (size - ms.width) / 2, y: (size - ms.height) / 2 + 60, width: ms.width, height: ms.height)
let s2 = NSShadow()
s2.shadowColor = NSColor.black.withAlphaComponent(0.25)
s2.shadowBlurRadius = 18
s2.shadowOffset = NSSize(width: 0, height: -8)
NSGraphicsContext.saveGraphicsState()
s2.set()
main.draw(in: mainRect)

let arrow = symbol("arrow.down.circle.fill", pt: 210, weight: .bold)
let asz = arrow.size
arrow.draw(in: NSRect(x: (size - asz.width) / 2, y: rect.minY + 70, width: asz.width, height: asz.height))
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("ícone: \(out)")
