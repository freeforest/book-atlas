#!/usr/bin/env swift
// Source artwork for the app icon. Uses only AppKit; no downloaded artwork.
// Run: swift Scripts/generate_app_icon.swift <new-output-directory>
import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: generate_app_icon.swift <new-output-directory>")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let manager = FileManager.default
guard !manager.fileExists(atPath: output.path) else {
    fatalError("Output already exists; choose a new directory")
}
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func drawIcon(pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
        pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                            xRadius: 196, yRadius: 196)
    NSGradient(starting: color(0x28555C), ending: color(0x112F38))!.draw(in: tile, angle: -70)
    color(0x52727A).withAlphaComponent(0.5).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // An open book: two deliberately simple, readable page silhouettes.
    let left = NSBezierPath()
    left.move(to: NSPoint(x: 502, y: 298))
    left.curve(to: NSPoint(x: 242, y: 350), controlPoint1: NSPoint(x: 415, y: 346),
               controlPoint2: NSPoint(x: 325, y: 371))
    left.line(to: NSPoint(x: 242, y: 699))
    left.curve(to: NSPoint(x: 502, y: 647), controlPoint1: NSPoint(x: 341, y: 719),
               controlPoint2: NSPoint(x: 431, y: 690))
    left.close()
    color(0xF2E4C6).setFill()
    left.fill()
    let right = NSBezierPath()
    right.move(to: NSPoint(x: 522, y: 298))
    right.curve(to: NSPoint(x: 782, y: 350), controlPoint1: NSPoint(x: 609, y: 346),
                controlPoint2: NSPoint(x: 699, y: 371))
    right.line(to: NSPoint(x: 782, y: 699))
    right.curve(to: NSPoint(x: 522, y: 647), controlPoint1: NSPoint(x: 683, y: 719),
                controlPoint2: NSPoint(x: 593, y: 690))
    right.close()
    color(0xD6C49C).setFill()
    right.fill()

    // Three connected points make the bibliography / atlas relationship visible.
    let nodes = [NSPoint(x: 606, y: 468), NSPoint(x: 713, y: 536), NSPoint(x: 609, y: 605)]
    let links = NSBezierPath()
    links.move(to: nodes[0]); links.line(to: nodes[1]); links.line(to: nodes[2])
    links.lineWidth = 13
    links.lineJoinStyle = .round
    color(0x315B60).setStroke(); links.stroke()
    for point in nodes {
        color(0x315B60).setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x - 20, y: point.y - 20,
                                    width: 40, height: 40)).fill()
    }
    for (startY, endY) in [(592.0, 565.0), (519.0, 492.0), (446.0, 419.0)] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 310, y: startY))
        line.curve(to: NSPoint(x: 438, y: endY), controlPoint1: NSPoint(x: 355, y: startY),
                   controlPoint2: NSPoint(x: 401, y: endY + 19))
        line.lineWidth = 12; line.lineCapStyle = .round
        color(0xAC9569).setStroke(); line.stroke()
    }
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(size)x\(size)\(suffix).png"
        try drawIcon(pixels: size * scale).write(to: iconset.appendingPathComponent(name))
    }
}
print(iconset.path)
