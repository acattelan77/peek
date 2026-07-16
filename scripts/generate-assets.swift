#!/usr/bin/env swift

import AppKit
import Foundation

enum AssetGenerationError: Error, CustomStringConvertible {
    case missingInput(String)
    case unreadableImage(String)
    case pngEncodingFailed(String)

    var description: String {
        switch self {
        case .missingInput(let path): return "Missing icon master: \(path)"
        case .unreadableImage(let path): return "Unable to read image: \(path)"
        case .pngEncodingFailed(let path): return "Unable to encode PNG: \(path)"
        }
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourcePath = CommandLine.arguments.dropFirst().first ?? "design/brand/peek-app-icon-master.png"
let sourceURL = root.appendingPathComponent(sourcePath)
let appIconDirectory = root.appendingPathComponent("Peek/Resources/Assets.xcassets/AppIcon.appiconset")
let statusIconDirectory = root.appendingPathComponent("Peek/Resources/Assets.xcassets/StatusBarIcon.imageset")

func pngData(from image: NSImage, width: Int, height: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw AssetGenerationError.pngEncodingFailed("\(width)x\(height)")
    }

    representation.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
        NSGraphicsContext.restoreGraphicsState()
        throw AssetGenerationError.pngEncodingFailed("\(width)x\(height)")
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: width, height: height),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw AssetGenerationError.pngEncodingFailed("\(width)x\(height)")
    }
    return data
}

func statusIconPNG(scale: Int) throws -> Data {
    let points = 22
    let pixels = points * scale
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw AssetGenerationError.pngEncodingFailed("status icon @\(scale)x")
    }

    representation.size = NSSize(width: points, height: points)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.shouldAntialias = true

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: points, height: points).fill()
    NSColor.black.setStroke()
    NSColor.black.setFill()

    let pageRect = NSRect(x: 3.8, y: 3.1, width: 14.4, height: 15.8)
    let page = NSBezierPath(roundedRect: pageRect, xRadius: 2.8, yRadius: 2.8)

    // Template glyph for the generated app icon: a calendar sheet with a folded
    // corner revealing the next event. macOS supplies the final menu-bar tint.
    page.lineWidth = 1.75
    page.stroke()

    let headerSeparator = NSBezierPath()
    headerSeparator.move(to: NSPoint(x: pageRect.minX + 1.1, y: pageRect.maxY - 4.8))
    headerSeparator.line(to: NSPoint(x: pageRect.maxX - 1.1, y: pageRect.maxY - 4.8))
    headerSeparator.lineWidth = 1.45
    headerSeparator.lineCapStyle = .round
    headerSeparator.stroke()

    for x in [pageRect.minX + pageRect.width * 0.34, pageRect.minX + pageRect.width * 0.66] {
        let binding = NSBezierPath(roundedRect: NSRect(x: x - 0.75, y: pageRect.maxY - 1.2, width: 1.5, height: 3.4), xRadius: 0.75, yRadius: 0.75)
        binding.fill()
    }

    let revealedSlot = NSBezierPath(
        roundedRect: NSRect(x: pageRect.maxX - 8.1, y: pageRect.minY + 2.0, width: 6.9, height: 2.35),
        xRadius: 1.15,
        yRadius: 1.15
    )
    revealedSlot.fill()

    let foldStart = NSPoint(x: pageRect.maxX - 5.3, y: pageRect.minY + 0.9)
    let foldTip = NSPoint(x: pageRect.maxX - 0.85, y: pageRect.minY + 5.35)
    let fold = NSBezierPath()
    fold.move(to: foldStart)
    fold.curve(
        to: foldTip,
        controlPoint1: NSPoint(x: pageRect.maxX - 3.4, y: pageRect.minY + 1.1),
        controlPoint2: NSPoint(x: pageRect.maxX - 1.2, y: pageRect.minY + 2.9)
    )
    fold.lineWidth = 1.45
    fold.lineCapStyle = .round
    fold.stroke()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw AssetGenerationError.pngEncodingFailed("status icon @\(scale)x")
    }
    return data
}

do {
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
        throw AssetGenerationError.missingInput(sourceURL.path)
    }
    guard let master = NSImage(contentsOf: sourceURL) else {
        throw AssetGenerationError.unreadableImage(sourceURL.path)
    }

    let appIcons: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for (filename, size) in appIcons {
        try pngData(from: master, width: size, height: size)
            .write(to: appIconDirectory.appendingPathComponent(filename), options: .atomic)
    }

    for (filename, scale) in [("statusbar_icon.png", 1), ("statusbar_icon@2x.png", 2), ("statusbar_icon@3x.png", 3)] {
        try statusIconPNG(scale: scale)
            .write(to: statusIconDirectory.appendingPathComponent(filename), options: .atomic)
    }

    print("Generated AppIcon and StatusBarIcon asset sets.")
} catch {
    fputs("Asset generation failed: \(error)\n", stderr)
    exit(1)
}
