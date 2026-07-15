import SwiftUI
import AppKit

// MARK: - Hex + dynamic color helpers

extension NSColor {
    /// Creates an NSColor from a hex string like "#3B60E4" or "3B60E4" (optionally with alpha "#RRGGBBAA").
    convenience init(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: string).scanHexInt64(&value)

        let r, g, b, a: CGFloat
        switch string.count {
        case 8: // RRGGBBAA
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255
            a = CGFloat(value & 0xFF) / 255
        default: // RRGGBB
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// A color that resolves to `light` in light appearance and `dark` in dark appearance.
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? dark : light
        }
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    static func peekDynamic(light: String, dark: String) -> Color {
        Color(nsColor: .dynamic(light: NSColor(hex: light), dark: NSColor(hex: dark)))
    }
}

// MARK: - Color tokens

/// The Peek "calm glance" palette. Values come from the Claude Design handoff
/// (`design_handoff_peek_design_system/README.md`). Neutral/text tokens adapt to
/// light and dark; brand and urgency accents are fixed hues with dark-tuned variants
/// where the reference specifies one.
enum PeekColor {
    // Brand
    static let accent = Color(hex: "#3B60E4")          // Peek Blue
    static let accentPressed = Color(hex: "#2E50CF")   // Blue Pressed
    static let accentRailDark = Color(hex: "#5B7DF0")  // rail/dot on dark
    static let accentIconDark = Color(hex: "#7E9BF5")  // clock/countdown on dark NEXT row

    // Selection / washes (light + dark)
    static let blueTint = Color.peekDynamic(light: "#E9EEFD", dark: "#2A3352")     // soft accent button bg
    static let nextWash = Color.peekDynamic(light: "#F1F4FE", dark: "#233056")     // NEXT row bg (dark ~ rgba(59,96,228,0.16))

    // Urgency
    static let urgent = Color(hex: "#E8912B")          // amber
    static let urgentWash = Color.peekDynamic(light: "#FDF2E3", dark: "#3A2E1C")
    static let urgentBadgeBg = Color.peekDynamic(light: "#FBEBD6", dark: "#43331D")
    static let critical = Color(hex: "#E5484D")        // red
    static let criticalWash = Color.peekDynamic(light: "#FCEBEC", dark: "#3A2427")
    static let criticalBadgeBg = Color.peekDynamic(light: "#FBE4E5", dark: "#452A2C")
    static let calm = Color(hex: "#2FA968")            // green success

    // Menu-bar title tints (title text only; glyph stays template)
    static let menuBarAmber = Color(hex: "#FFB558")
    static let menuBarRed = Color(hex: "#FF8A8E")

    // Neutral surfaces
    static let surface = Color.peekDynamic(light: "#FFFFFF", dark: "#232428")
    static let canvas = Color.peekDynamic(light: "#F4F5F8", dark: "#1B1C1F")
    static let rowHoverWash = Color.peekDynamic(light: "#F3F4F8", dark: "#2C2D31")
    static let fill = Color.peekDynamic(light: "#F0F1F5", dark: "#3234391A")       // secondary button / chip
    static let chip = Color.peekDynamic(light: "#EDEEF2", dark: "#33343A")
    static let hairline = Color.peekDynamic(light: "#E7E8EE", dark: "#FFFFFF14")
    static let innerDivider = Color.peekDynamic(light: "#EEF0F3", dark: "#FFFFFF12")
    static let controlBorder = Color.peekDynamic(light: "#DADCE3", dark: "#4A4C53")

    // Text ramp
    static let ink = Color.peekDynamic(light: "#17181C", dark: "#F2F3F5")          // primary
    static let bodyText = Color.peekDynamic(light: "#40454E", dark: "#C4C8CF")     // times, body
    static let secondaryText = Color.peekDynamic(light: "#626770", dark: "#9DA2AB")
    static let tertiaryText = Color.peekDynamic(light: "#9A9FA8", dark: "#8B9099") // captions, timestamps

    /// Success confirmation background (refresh "Refreshed" chip).
    static let successWash = Color.peekDynamic(light: "#E7F6EE", dark: "#223A2C")
}

// MARK: - Typography tokens

/// SF Pro type roles from the design handoff.
enum PeekFont {
    static let display = Font.system(size: 24, weight: .bold)
    static let title = Font.system(size: 15, weight: .semibold)      // popover header "Peek"
    static let headline = Font.system(size: 14, weight: .semibold)   // event titles / section headings
    static let nextTitle = Font.system(size: 14, weight: .semibold)  // NEXT row title (650)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMeta = Font.system(size: 12.5, weight: .regular)
    static let bodyMetaMedium = Font.system(size: 12.5, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionStrong = Font.system(size: 11, weight: .semibold)
    static let label = Font.system(size: 9, weight: .bold)           // NEXT / SOON / NOW / ALL-DAY
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let onboardingTitle = Font.system(size: 20, weight: .bold)
}

// MARK: - Spacing / radius (4pt grid)

enum PeekSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8    // row padding
    static let md: CGFloat = 12   // edge inset
    static let lg: CGFloat = 16   // header
    static let xl: CGFloat = 24   // section
}

enum PeekRadius {
    static let button: CGFloat = 6
    static let join: CGFloat = 7
    static let row: CGFloat = 9
    static let card: CGFloat = 10
    static let window: CGFloat = 12
    static let hud: CGFloat = 16
    static let pill: CGFloat = 999
}

// MARK: - Elevation

enum PeekElevation {
    case card
    case popover
    case hud
    case window

    var color: Color {
        Color(nsColor: .dynamic(light: NSColor(hex: "#141628").withAlphaComponent(0.20),
                                dark: NSColor(hex: "#000000").withAlphaComponent(0.45)))
    }

    var radius: CGFloat {
        switch self {
        case .card: return 6
        case .popover: return 40
        case .hud: return 50
        case .window: return 46
        }
    }

    var y: CGFloat {
        switch self {
        case .card: return 2
        case .popover: return 14
        case .hud: return 20
        case .window: return 18
        }
    }
}

extension View {
    func peekShadow(_ level: PeekElevation) -> some View {
        shadow(color: level.color, radius: level.radius / 2, x: 0, y: level.y)
    }
}
