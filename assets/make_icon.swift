// Génère l'icône (1024 px) : carré arrondi orange chaud, micro blanc et trois points de « casting ».
import Cocoa
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: size - 200, height: size - 200), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0xf0/255, green: 0x8a/255, blue: 0x52/255, alpha: 1), ending: NSColor(srgbRed: 0xc2/255, green: 0x4a/255, blue: 0x1c/255, alpha: 1))!.draw(in: bg, angle: -60)
NSColor.white.setFill()
let c = NSPoint(x: size / 2, y: size / 2 + 40)
NSBezierPath(roundedRect: NSRect(x: c.x - 105, y: c.y - 60, width: 210, height: 330), xRadius: 105, yRadius: 105).fill()
let arc = NSBezierPath(); arc.appendArc(withCenter: NSPoint(x: c.x, y: c.y + 30), radius: 175, startAngle: 180, endAngle: 360, clockwise: false)
arc.lineWidth = 36; arc.lineCapStyle = .round; NSColor.white.setStroke(); arc.stroke()
let stem = NSBezierPath(); stem.move(to: NSPoint(x: c.x, y: c.y - 145)); stem.line(to: NSPoint(x: c.x, y: c.y - 215)); stem.lineWidth = 36; stem.lineCapStyle = .round; stem.stroke()
let base = NSBezierPath(); base.move(to: NSPoint(x: c.x - 90, y: c.y - 215)); base.line(to: NSPoint(x: c.x + 90, y: c.y - 215)); base.lineWidth = 36; base.lineCapStyle = .round; base.stroke()
for (i, dx) in [-70.0, 0.0, 70.0].enumerated() {
    NSColor(white: 1, alpha: 0.55 + 0.2 * CGFloat(i)).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x + dx - 18, y: 235, width: 36, height: 36)).fill()
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
