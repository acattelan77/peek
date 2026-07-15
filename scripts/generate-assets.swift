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

    let calendar = NSBezierPath(roundedRect: NSRect(x: 3.25, y: 3.25, width: 15.5, height: 15), xRadius: 3, yRadius: 3)
    calendar.lineWidth = 1.7
    calendar.stroke()

    let header = NSBezierPath()
    header.move(to: NSPoint(x: 3.8, y: 13.6))
    header.line(to: NSPoint(x: 18.2, y: 13.6))
    header.lineWidth = 1.6
    header.stroke()

    for x in [7.25, 14.75] {
        let binding = NSBezierPath()
        binding.move(to: NSPoint(x: x, y: 16.3))
        binding.line(to: NSPoint(x: x, y: 19.4))
        binding.lineWidth = 1.9
        binding.lineCapStyle = .round
        binding.stroke()
    }

    let nextSlot = NSBezierPath(roundedRect: NSRect(x: 8.1, y: 7.1, width: 7.4, height: 2.4), xRadius: 1.2, yRadius: 1.2)
    nextSlot.fill()

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
