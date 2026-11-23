import XCTest
import AppKit
@testable import Peek

/// Guards the design-system color tokens against contrast regressions (WCAG 2.x AA):
/// 4.5:1 for text, 3:1 for control boundaries and meaningful icons.
final class DesignSystemTests: XCTestCase {
    private struct RGBA {
        var r: Double
        var g: Double
        var b: Double
        var a: Double
    }

    private let appearanceNames: [NSAppearance.Name] = [
        .aqua,
        .darkAqua,
        .accessibilityHighContrastAqua,
        .accessibilityHighContrastDarkAqua
    ]

    // MARK: Pairs

    private var textPairs: [(String, NSColor, String, NSColor)] {
        let surfaces: [(String, NSColor)] = [
            ("surface", PeekNSColor.surface),
            ("canvas", PeekNSColor.canvas),
            ("rowHoverWash", PeekNSColor.rowHoverWash),
            ("nextWash", PeekNSColor.nextWash),
            ("urgentWash", PeekNSColor.urgentWash),
            ("criticalWash", PeekNSColor.criticalWash)
        ]
        let neutralText: [(String, NSColor)] = [
            ("ink", PeekNSColor.ink),
            ("bodyText", PeekNSColor.bodyText),
            ("secondaryText", PeekNSColor.secondaryText),
            ("tertiaryText", PeekNSColor.tertiaryText)
        ]

        var pairs: [(String, NSColor, String, NSColor)] = []
        for (fgName, fg) in neutralText {
            for (bgName, bg) in surfaces {
                pairs.append((fgName, fg, bgName, bg))
            }
        }
        pairs += [
            ("accentText", PeekNSColor.accentText, "surface", PeekNSColor.surface),
            ("accentText", PeekNSColor.accentText, "canvas", PeekNSColor.canvas),
            ("accentText", PeekNSColor.accentText, "rowHoverWash", PeekNSColor.rowHoverWash),
            ("accentText", PeekNSColor.accentText, "nextWash", PeekNSColor.nextWash),
            ("accentText", PeekNSColor.accentText, "blueTint", PeekNSColor.blueTint),
            ("urgentText", PeekNSColor.urgentText, "surface", PeekNSColor.surface),
            ("urgentText", PeekNSColor.urgentText, "urgentWash", PeekNSColor.urgentWash),
            ("criticalText", PeekNSColor.criticalText, "surface", PeekNSColor.surface),
            ("criticalText", PeekNSColor.criticalText, "canvas", PeekNSColor.canvas),
            ("criticalText", PeekNSColor.criticalText, "criticalWash", PeekNSColor.criticalWash),
            ("calmText", PeekNSColor.calmText, "surface", PeekNSColor.surface),
            ("onAccent", PeekNSColor.onAccent, "accent", PeekNSColor.accent),
            ("onAccent", PeekNSColor.onAccent, "accentPressed", PeekNSColor.accentPressed),
            ("onUrgent", PeekNSColor.onUrgent, "urgent", PeekNSColor.urgent),
            ("onCritical", PeekNSColor.onCritical, "critical", PeekNSColor.critical),
            ("ink", PeekNSColor.ink, "fill", PeekNSColor.fill),
            ("ink", PeekNSColor.ink, "chip", PeekNSColor.chip),
            ("statusUrgent", PeekNSColor.statusUrgent, "canvas", PeekNSColor.canvas),
            ("statusCritical", PeekNSColor.statusCritical, "canvas", PeekNSColor.canvas)
        ]
        return pairs
    }

    private var nonTextPairs: [(String, NSColor, String, NSColor)] {
        [
            ("controlStroke", PeekNSColor.controlStroke, "surface", PeekNSColor.surface),
            ("accentRail", PeekNSColor.accentRail, "surface", PeekNSColor.surface),
            ("calm", PeekNSColor.calm, "surface", PeekNSColor.surface),
            ("accent", PeekNSColor.accent, "surface-light", NSColor(hex: "#FFFFFF"))
        ]
    }

    // MARK: Tests

    func testTextTokensMeetAAContrastInEveryAppearance() {
        assertPairs(textPairs, minimum: 4.5)
    }

    func testControlAndIconTokensMeetNonTextContrast() {
        assertPairs(nonTextPairs, minimum: 3.0)
    }

    func testDarkFillIsVisibleAgainstSurface() throws {
        // Regression: the dark `fill` was #3234391A (10% of a dark grey), invisible on #232428.
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let surface = resolve(PeekNSColor.surface, in: appearance)
        let fill = composite(resolve(PeekNSColor.fill, in: appearance), over: surface)
        XCTAssertGreaterThan(contrast(fill, surface), 1.2)
    }

    func testStatusTintsAdaptToMenuBarAppearance() throws {
        let light = resolve(PeekNSColor.statusUrgent, in: try XCTUnwrap(NSAppearance(named: .aqua)))
        let dark = resolve(PeekNSColor.statusUrgent, in: try XCTUnwrap(NSAppearance(named: .darkAqua)))
        XCTAssertLessThan(luminance(light), luminance(dark))
    }

    func testToneMapsUrgency() {
        XCTAssertEqual(PeekTone(.normal), .accent)
        XCTAssertEqual(PeekTone(.urgent), .urgent)
        XCTAssertEqual(PeekTone(.critical), .critical)
        XCTAssertEqual(PeekBadge.Kind.allDay.tone, .urgent)
        XCTAssertEqual(PeekBadge.Kind.now.tone, .critical)
    }

    // MARK: Helpers

    private func assertPairs(_ pairs: [(String, NSColor, String, NSColor)], minimum: Double) {
        for name in appearanceNames {
            guard let appearance = NSAppearance(named: name) else { continue }
            let surface = resolve(PeekNSColor.surface, in: appearance)
            for (fgName, fg, bgName, bg) in pairs {
                let background = composite(resolve(bg, in: appearance), over: surface)
                let foreground = composite(resolve(fg, in: appearance), over: background)
                let ratio = contrast(foreground, background)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    minimum,
                    "\(fgName) on \(bgName) in \(name.rawValue): \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    private func resolve(_ color: NSColor, in appearance: NSAppearance) -> RGBA {
        var result = RGBA(r: 0, g: 0, b: 0, a: 1)
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = color.usingColorSpace(.sRGB) else { return }
            result = RGBA(
                r: Double(srgb.redComponent),
                g: Double(srgb.greenComponent),
                b: Double(srgb.blueComponent),
                a: Double(srgb.alphaComponent)
            )
        }
        return result
    }

    private func composite(_ top: RGBA, over bottom: RGBA) -> RGBA {
        let a = top.a
        return RGBA(
            r: top.r * a + bottom.r * (1 - a),
            g: top.g * a + bottom.g * (1 - a),
            b: top.b * a + bottom.b * (1 - a),
            a: 1
        )
    }

    private func luminance(_ c: RGBA) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    private func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
