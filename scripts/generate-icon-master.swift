#!/usr/bin/env swift

// Renders the Peek app-icon master (1024x1024) per the Claude Design handoff (§6):
// squircle tile with an indigo->midnight gradient, a white calendar page with a
// Peek-Blue header band and two binding stubs, a single coral "next" slot bottom-left,
// and a peeled bottom-right corner. Output overwrites design/brand/peek-app-icon-master.png.
// Regenerate the appiconset afterwards with scripts/generate-assets.swift.

import AppKit
import Foundation

func color(_ hex: String) -> NSColor {
    var s = hex; if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    return NSColor(
        srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
        green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255,
        alpha: 1
    )
}

let indigoTop = color("#1B2E7A")
let midnight = color("#0B1B44")
let headerBlue = color("#3B60E4")
let pageWhite = color("#FFFFFF")
let peelGrey = color("#EDEEF2")
let peelFold = color("#D8DCE6")
let slotGrey = color("#E3E7F0")
let coral = color("#FF6E5B")
let bindingFill = color("#EAEEF9")

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("Failed to create bitmap context\n", stderr); exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
ctx.shouldAntialias = true
ctx.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

// 1. Squircle tile with indigo -> midnight gradient (approximating the 150deg field).
let tile = rounded(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
NSGradient(starting: indigoTop, ending: midnight)?.draw(in: tile, angle: 305)

// Page geometry.
let pageRect = NSRect(x: 272, y: 250, width: 480, height: 520)
let pageRadius: CGFloat = 52
let pagePath = rounded(pageRect, pageRadius)

// Soft drop shadow under the page.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
pageWhite.setFill()
pagePath.fill()
NSGraphicsContext.restoreGraphicsState()

// 2. Clip to the page for header, slots, and the peel.
NSGraphicsContext.saveGraphicsState()
pagePath.setClip()

// Header band (Peek Blue) across the top of the page.
let headerHeight: CGFloat = 122
headerBlue.setFill()
NSRect(x: pageRect.minX, y: pageRect.maxY - headerHeight, width: pageRect.width, height: headerHeight).fill()

// One grey list line + the single coral "next" slot (no dense grid).
let slotLeft = pageRect.minX + 46
slotGrey.setFill()
rounded(NSRect(x: slotLeft, y: 392, width: 250, height: 34), 17).fill()
coral.setFill()
rounded(NSRect(x: slotLeft, y: 300, width: 168, height: 52), 26).fill()

// Peeled bottom-right corner (folded page underside).
let peel = NSBezierPath()
peel.move(to: NSPoint(x: pageRect.maxX - 132, y: pageRect.minY))
peel.line(to: NSPoint(x: pageRect.maxX, y: pageRect.minY))
peel.line(to: NSPoint(x: pageRect.maxX, y: pageRect.minY + 132))
peel.close()
peelGrey.setFill()
peel.fill()
peelFold.setStroke()
let fold = NSBezierPath()
fold.move(to: NSPoint(x: pageRect.maxX - 132, y: pageRect.minY))
fold.line(to: NSPoint(x: pageRect.maxX, y: pageRect.minY + 132))
fold.lineWidth = 3
fold.stroke()

NSGraphicsContext.restoreGraphicsState() // end page clip

// 3. Two binding stubs poking above the header (large-size detail).
bindingFill.setFill()
for cx in [pageRect.minX + pageRect.width * 0.33, pageRect.minX + pageRect.width * 0.67] {
    rounded(NSRect(x: cx - 17, y: pageRect.maxY - 20, width: 34, height: 66), 17).fill()
}

ctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("design/brand/peek-app-icon-master.png")
guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr); exit(1)
}
do {
    try data.write(to: outURL, options: .atomic)
    print("Wrote \(outURL.path)")
} catch {
    fputs("Write failed: \(error)\n", stderr); exit(1)
}
