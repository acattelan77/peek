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

    /// A color that resolves per appearance. High-contrast variants fall back to the
    /// matching light/dark value when not supplied. macOS switches to the
    /// `accessibilityHighContrast*` appearances when "Increase contrast" is on.
    static func dynamic(
        light: NSColor,
        dark: NSColor,
        highContrastLight: NSColor? = nil,
        highContrastDark: NSColor? = nil
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua,
                .darkAqua,
                .accessibilityHighContrastAqua,
                .accessibilityHighContrastDarkAqua
            ])
            switch match {
            case .darkAqua: return dark
            case .accessibilityHighContrastDarkAqua: return highContrastDark ?? dark
            case .accessibilityHighContrastAqua: return highContrastLight ?? light
            default: return light
            }
        }
    }

    /// Token constructor: one hex for every appearance, or light/dark (+ optional high contrast).
    static func peek(_ light: String, dark: String? = nil, hcLight: String? = nil, hcDark: String? = nil) -> NSColor {
        let lightColor = NSColor(hex: light)
        guard dark != nil || hcLight != nil || hcDark != nil else { return lightColor }
        return .dynamic(
            light: lightColor,
            dark: NSColor(hex: dark ?? light),
            highContrastLight: hcLight.map { NSColor(hex: $0) },
            highContrastDark: hcDark.map { NSColor(hex: $0) }
        )
    }
}

// MARK: - Color tokens (single source of truth)

/// The Peek "calm glance" palette as AppKit colors. Every SwiftUI `PeekColor` token is
/// derived from this table, so AppKit (status item) and SwiftUI share one definition.
///
/// Naming: a bare hue (`accent`, `urgent`, `critical`, `calm`) is a *fill / rail / icon*
/// color. `…Text` is the readable foreground for that hue on Peek surfaces and washes.
/// `on…` is the foreground placed *on top of* a solid fill of that hue. Every text pair is
/// checked against WCAG AA (4.5:1) in `DesignSystemTests`.
enum PeekNSColor {
    // Brand
    static let accent = NSColor.peek("#3B60E4")                              // Peek Blue fill
    static let accentPressed = NSColor.peek("#2E50CF")
    static let accentText = NSColor.peek("#3B60E4", dark: "#7E9BF5")          // links, selected text, countdown
    static let accentRail = NSColor.peek("#3B60E4", dark: "#5B7DF0")          // NEXT rail, dots, focus ring
    static let onAccent = NSColor.peek("#FFFFFF")

    // Washes
    static let blueTint = NSColor.peek("#E9EEFD", dark: "#2A3352")            // soft accent button, icon tile
    static let nextWash = NSColor.peek("#F1F4FE", dark: "#233056")            // NEXT row background
    static let nextBorder = NSColor.peek("#DDE4FB", dark: "#2F3D66", hcLight: "#9A9FA8", hcDark: "#FFFFFF59") // NEXT card outline

    // Urgency (2–10 min). Amber is too light for white text, so fills carry dark text.
    static let urgent = NSColor.peek("#E8912B")
    static let urgentText = NSColor.peek("#A45A07", dark: "#F0A54A")
    static let onUrgent = NSColor.peek("#1F1606")
    static let urgentWash = NSColor.peek("#FDF2E3", dark: "#3A2E1C")
    static let urgentBorder = NSColor.peek("#F6DDB8", dark: "#4E3D24", hcLight: "#9A9FA8", hcDark: "#FFFFFF59")

    // Critical (< 2 min). Fill darkened from the handoff #E5484D so white text passes AA.
    static let critical = NSColor.peek("#D13438")
    static let criticalText = NSColor.peek("#B42A30", dark: "#FF8A8E")
    static let onCritical = NSColor.peek("#FFFFFF")
    static let criticalWash = NSColor.peek("#FCEBEC", dark: "#3A2427")
    static let criticalBorder = NSColor.peek("#F5CDCF", dark: "#55302F", hcLight: "#9A9FA8", hcDark: "#FFFFFF59")

    // Calm / success
    static let calm = NSColor.peek("#23955A", dark: "#3CC27E")                // icons
    static let calmText = NSColor.peek("#1E7D4B", dark: "#5DD39A")

    // Menu-bar title tints (title text only; the glyph stays a template image).
    // Resolved against the status button's appearance, so a light menu bar gets dark tints.
    static let statusUrgent = NSColor.peek("#A45A07", dark: "#FFB558")
    static let statusCritical = NSColor.peek("#B42A30", dark: "#FF8A8E")

    // Neutral surfaces
    static let surface = NSColor.peek("#FFFFFF", dark: "#232428")
    static let canvas = NSColor.peek("#F4F5F8", dark: "#1B1C1F")
    static let rowHoverWash = NSColor.peek("#F3F4F8", dark: "#2C2D31")
    static let fill = NSColor.peek("#F0F1F5", dark: "#FFFFFF17")              // secondary button, input
    static let chip = NSColor.peek("#EDEEF2", dark: "#33343A")

    // Lines and control borders
    static let hairline = NSColor.peek("#E7E8EE", dark: "#FFFFFF14", hcLight: "#9A9FA8", hcDark: "#FFFFFF59")
    static let innerDivider = NSColor.peek("#EEF0F3", dark: "#FFFFFF12", hcLight: "#9A9FA8", hcDark: "#FFFFFF59")
    static let controlBorder = NSColor.peek("#DADCE3", dark: "#4A4C53", hcLight: "#6B7079", hcDark: "#9298A1")
    /// Boundary of an interactive control (checkbox, input). Meets 3:1 against surface.
    static let controlStroke = NSColor.peek("#8E929A", dark: "#7A7E87", hcLight: "#555A63", hcDark: "#B0B4BC")

    // Text ramp
    static let ink = NSColor.peek("#17181C", dark: "#F2F3F5")
    static let bodyText = NSColor.peek("#40454E", dark: "#C4C8CF")
    static let secondaryText = NSColor.peek("#555A63", dark: "#B0B4BC", hcLight: "#40454E", hcDark: "#C4C8CF")
    static let tertiaryText = NSColor.peek("#676C75", dark: "#999EA7", hcLight: "#555A63", hcDark: "#B0B4BC")
    /// Days outside the displayed month. Decorative context, so it sits below AA by design;
    /// Increased Contrast raises it to the tertiary value.
    static let mutedText = NSColor.peek("#A3A7AE", dark: "#6B7079", hcLight: "#676C75", hcDark: "#999EA7")

    // Full-screen alert backdrop (PEEK-203)
    static let scrim = NSColor.peek("#0F101499", dark: "#000000B3")

    // Shadow
    static let shadow = NSColor.dynamic(
        light: NSColor(hex: "#141628").withAlphaComponent(0.20),
        dark: NSColor(hex: "#000000").withAlphaComponent(0.45)
    )
}

/// SwiftUI view of `PeekNSColor`. Views use these; never hex literals.
enum PeekColor {
    static let accent = Color(nsColor: PeekNSColor.accent)
    static let accentPressed = Color(nsColor: PeekNSColor.accentPressed)
    static let accentText = Color(nsColor: PeekNSColor.accentText)
    static let accentRail = Color(nsColor: PeekNSColor.accentRail)
    static let onAccent = Color(nsColor: PeekNSColor.onAccent)

    static let blueTint = Color(nsColor: PeekNSColor.blueTint)
    static let nextWash = Color(nsColor: PeekNSColor.nextWash)
    static let nextBorder = Color(nsColor: PeekNSColor.nextBorder)

    static let urgent = Color(nsColor: PeekNSColor.urgent)
    static let urgentText = Color(nsColor: PeekNSColor.urgentText)
    static let onUrgent = Color(nsColor: PeekNSColor.onUrgent)
    static let urgentWash = Color(nsColor: PeekNSColor.urgentWash)
    static let urgentBorder = Color(nsColor: PeekNSColor.urgentBorder)

    static let critical = Color(nsColor: PeekNSColor.critical)
    static let criticalText = Color(nsColor: PeekNSColor.criticalText)
    static let onCritical = Color(nsColor: PeekNSColor.onCritical)
    static let criticalWash = Color(nsColor: PeekNSColor.criticalWash)
    static let criticalBorder = Color(nsColor: PeekNSColor.criticalBorder)

    static let calm = Color(nsColor: PeekNSColor.calm)
    static let calmText = Color(nsColor: PeekNSColor.calmText)

    static let surface = Color(nsColor: PeekNSColor.surface)
    static let canvas = Color(nsColor: PeekNSColor.canvas)
    static let rowHoverWash = Color(nsColor: PeekNSColor.rowHoverWash)
    static let fill = Color(nsColor: PeekNSColor.fill)
    static let chip = Color(nsColor: PeekNSColor.chip)

    static let hairline = Color(nsColor: PeekNSColor.hairline)
    static let innerDivider = Color(nsColor: PeekNSColor.innerDivider)
    static let controlBorder = Color(nsColor: PeekNSColor.controlBorder)
    static let controlStroke = Color(nsColor: PeekNSColor.controlStroke)

    static let ink = Color(nsColor: PeekNSColor.ink)
    static let bodyText = Color(nsColor: PeekNSColor.bodyText)
    static let secondaryText = Color(nsColor: PeekNSColor.secondaryText)
    static let tertiaryText = Color(nsColor: PeekNSColor.tertiaryText)
    static let mutedText = Color(nsColor: PeekNSColor.mutedText)

    static let shadow = Color(nsColor: PeekNSColor.shadow)
    static let scrim = Color(nsColor: PeekNSColor.scrim)
}

// MARK: - Tone (urgency-aware color set)

/// The color set a component uses for a given urgency, so rows, badges and buttons
/// never pick hues ad hoc.
enum PeekTone {
    case accent
    case urgent
    case critical

    init(_ urgency: MeetingUrgency) {
        switch urgency {
        case .normal: self = .accent
        case .urgent: self = .urgent
        case .critical: self = .critical
        }
    }

    /// Solid fill (badges, Join button).
    var fill: Color {
        switch self {
        case .accent: return PeekColor.accent
        case .urgent: return PeekColor.urgent
        case .critical: return PeekColor.critical
        }
    }

    /// Foreground on `fill`.
    var onFill: Color {
        switch self {
        case .accent: return PeekColor.onAccent
        case .urgent: return PeekColor.onUrgent
        case .critical: return PeekColor.onCritical
        }
    }

    /// Readable text/icon on surfaces and washes.
    var text: Color {
        switch self {
        case .accent: return PeekColor.accentText
        case .urgent: return PeekColor.urgentText
        case .critical: return PeekColor.criticalText
        }
    }

    /// Decorative rail.
    var rail: Color {
        switch self {
        case .accent: return PeekColor.accentRail
        case .urgent: return PeekColor.urgent
        case .critical: return PeekColor.critical
        }
    }

    /// Row background wash.
    var wash: Color {
        switch self {
        case .accent: return PeekColor.nextWash
        case .urgent: return PeekColor.urgentWash
        case .critical: return PeekColor.criticalWash
        }
    }

    /// Outline of a washed card (the next-meeting card).
    var border: Color {
        switch self {
        case .accent: return PeekColor.nextBorder
        case .urgent: return PeekColor.urgentBorder
        case .critical: return PeekColor.criticalBorder
        }
    }
}

// MARK: - Typography tokens

/// SF Pro type roles from the design handoff.
///
/// macOS does not offer Dynamic Type to third-party apps (SwiftUI text styles have fixed
/// sizes on macOS), so roles are fixed point sizes, defined only here.
enum PeekFont {
    static let display = Font.system(size: 24, weight: .bold)          // onboarding welcome
    static let onboardingTitle = Font.system(size: 20, weight: .bold)  // onboarding steps, HUD title
    static let title = Font.system(size: 15, weight: .semibold)        // popover header, section headings
    static let headline = Font.system(size: 14, weight: .semibold)     // NEXT row title
    static let rowTitle = Font.system(size: 13, weight: .medium)       // compact event row title (Peek 2.0)
    static let meetingTitle = Font.system(size: 18, weight: .bold)     // meeting page headline
    static let alertTitle = Font.system(size: 26, weight: .bold)       // full-screen alert headline
    static let alertSubtitle = Font.system(size: 14, weight: .regular)
    static let alertBrief = Font.system(size: 13.5, weight: .regular)
    static let alertButton = Font.system(size: 15, weight: .semibold)
    static let alertSecondaryButton = Font.system(size: 14, weight: .medium)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyEmphasis = Font.system(size: 13, weight: .semibold) // selected tab
    static let button = Font.system(size: 13, weight: .semibold)       // primary button
    static let bodyMeta = Font.system(size: 12.5, weight: .regular)
    static let bodyMetaMedium = Font.system(size: 12.5, weight: .medium) // secondary / soft buttons
    static let bodyMetaStrong = Font.system(size: 12.5, weight: .semibold) // Join button
    static let rowTime = Font.system(size: 12, weight: .regular)       // time column in compact rows
    static let dayNumber = Font.system(size: 12, weight: .medium)      // month grid
    static let dayNumberStrong = Font.system(size: 12, weight: .semibold)
    static let navButton = Font.system(size: 12, weight: .medium)      // header "Today"
    static let footerMeta = Font.system(size: 12, weight: .regular)    // alert detail and hint
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionStrong = Font.system(size: 11, weight: .semibold)
    static let sectionLabel = Font.system(size: 10, weight: .semibold) // TODAY / TOMORROW, weekday row, group labels
    static let smallCaption = Font.system(size: 10.5, weight: .regular) // sources, pill text
    static let smallCaptionStrong = Font.system(size: 10.5, weight: .semibold)
    static let label = Font.system(size: 9, weight: .bold)             // NEXT / SOON / NOW / ALL DAY, eyebrows
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Letter-spacing for uppercase labels.
    static let labelTracking: CGFloat = 0.5
    static let groupLabelTracking: CGFloat = 0.66
    static let weekdayTracking: CGFloat = 0.4
}

/// SF Symbol sizes. Symbols scale with their font, so sizes live next to type.
enum PeekIcon {
    static let hero = Font.system(size: 32, weight: .regular)          // onboarding access tile
    static let emptyState = Font.system(size: 24, weight: .regular)    // popover empty/no-access tile
    static let toolbar = Font.system(size: 15, weight: .regular)       // popover footer
    static let inlineAction = Font.system(size: 14, weight: .semibold) // add-keyword button
    static let dismiss = Font.system(size: 13, weight: .medium)        // HUD close
    static let meta = Font.system(size: 12, weight: .regular)          // clock next to time
    static let nav = Font.system(size: 11, weight: .semibold)          // header chevrons
    static let detail = Font.system(size: 11, weight: .regular)        // provider, location, attendee
    static let checkmark = Font.system(size: 11, weight: .bold)        // checkbox tick
    static let chipRemove = Font.system(size: 9, weight: .bold)        // keyword chip ×
}

// MARK: - Spacing / radius (4pt grid)

enum PeekSpacing {
    static let hairline: CGFloat = 1
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8    // row padding
    static let md: CGFloat = 12   // edge inset
    static let lg: CGFloat = 16   // header
    static let xl: CGFloat = 20   // window content inset
    static let xxl: CGFloat = 24  // section
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 40

    // Inline gaps between an icon and its label, or between chips.
    static let iconGap: CGFloat = 6
    static let tightGap: CGFloat = 5
}

enum PeekRadius {
    static let rail: CGFloat = 2
    static let badge: CGFloat = 4
    static let checkbox: CGFloat = 5
    static let button: CGFloat = 6
    static let join: CGFloat = 7
    static let row: CGFloat = 9
    static let card: CGFloat = 10
    static let window: CGFloat = 12
    static let tile: CGFloat = 14
    static let hud: CGFloat = 16
    static let alertButton: CGFloat = 10
    static let appIconLarge: CGFloat = 19
    static let pill: CGFloat = 999
}

/// Component dimensions and insets from the handoff. Off-grid values are intentional
/// (pixel-matched to the reference) and live only here.
enum PeekMetrics {
    // Popover
    static let popoverWidth: CGFloat = 360
    static let popoverListMaxHeight: CGFloat = 400
    static let headerIcon: CGFloat = 26
    static let headerGap: CGFloat = 10
    static let headerVerticalPadding: CGFloat = 13
    static let headerInsets = EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16)
    static let headerNavButton: CGFloat = 28
    static let headerNavGap: CGFloat = 4
    static let listInsets = EdgeInsets(top: 12, leading: 12, bottom: 6, trailing: 12)
    /// Day priorities block above the list (PEEK-261); the list adds its own top inset.
    static let dayBlockInsets = EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12)
    static let sectionLabelInsets = EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4)
    static let compactRowInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    static let compactRowGap: CGFloat = 10
    static let rowTimeWidth: CGFloat = 44
    static let finishedRowOpacity: Double = 0.55
    static let nextCardInsets = EdgeInsets(top: 11, leading: 14, bottom: 12, trailing: 12)
    static let nextCardRailInset: CGFloat = 10
    static let nextCardGap: CGFloat = 8
    static let joinButtonHeight: CGFloat = 32
    static let meetingJoinButtonHeight: CGFloat = 36
    static let avatar: CGFloat = 32
    static let briefBullet: CGFloat = 5
    static let meetingPageInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    static let meetingBackBarInsets = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    static let meetingPageMaxHeight: CGFloat = 560
    static let briefCardInsets = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    static let sourcePillInsets = EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
    static let footerVerticalPadding: CGFloat = 9
    static let rowGap: CGFloat = 6
    static let heroRowInsets = EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 12)
    static let rowInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    static let heroContentGap: CGFloat = 7
    static let railWidth: CGFloat = 3
    static let metaIconWidth: CGFloat = 14
    static let calendarDot: CGFloat = 8
    static let emptyTile: CGFloat = 52
    static let emptyTextMaxWidth: CGFloat = 230
    static let toolbarButton: CGFloat = 18

    // Month view (PEEK-201)
    static let monthDayCellHeight: CGFloat = 32
    static let monthGridInsets = EdgeInsets(top: 0, leading: 12, bottom: 10, trailing: 12)
    static let monthDayNumber = CGSize(width: 24, height: 20)
    static let monthEventDot: CGFloat = 4
    static let monthDotGap: CGFloat = 2

    // Buttons
    static let primaryButtonInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    static let smallButtonInsets = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    static let joinButtonInsets = EdgeInsets(top: 7, leading: 13, bottom: 7, trailing: 13)
    static let pressedScale: CGFloat = 0.97
    static let pressedOpacity: Double = 0.8
    static let disabledOpacity: Double = 0.45

    // Badges, pills, chips
    static let badgeInsets = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
    static let countPillInsets = EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
    static let chipInsets = EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
    static let statusPillInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let chipRemoveTarget: CGFloat = 14
    static let chipMinWidth: CGFloat = 84
    static let worldClockInsets = EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9)
    static let worldClockStripInsets = EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16)
    static let pulsingDotSmall: CGFloat = 5
    static let pulsingDot: CGFloat = 6

    // Settings
    static let settingRowInsets = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    static let checkboxRowInsets = EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14)
    static let cardContentPadding: CGFloat = 14
    static let checkbox: CGFloat = 18
    static let checkboxStroke: CGFloat = 1.5
    static let colorSwatch: CGFloat = 10
    static let inputInsets = EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
    static let footnoteInsets = EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14)
    static let tabGap: CGFloat = 22
    static let tabIndicator: CGFloat = 2
    static let preferencesSize = CGSize(width: 500, height: 700)
    static let pickerCompact: CGFloat = 90
    static let pickerHotkey: CGFloat = 110
    static let pickerMedium: CGFloat = 150
    static let pickerWide: CGFloat = 180
    static let pickerSegmented: CGFloat = 200
    static let pickerLevel: CGFloat = 140         // alert ladder level (mockup min 130)
    static let pickerShowSegmented: CGFloat = 270 // Countdown / Start time / Icon only
    static let chipDash: [CGFloat] = [3, 2]       // badge-only calendar chip

    // Onboarding
    static let onboardingSize = CGSize(width: 420, height: 460)
    static let onboardingIcon: CGFloat = 84
    static let onboardingTile: CGFloat = 72
    static let onboardingTextMaxWidth: CGFloat = 300
    static let onboardingListMaxHeight: CGFloat = 200
    static let progressDot: CGFloat = 7

    // HUD
    static let hudWidth: CGFloat = 380
    static let hudAccentBar: CGFloat = 4
    static let hudInsets = EdgeInsets(top: 18, leading: 20, bottom: 20, trailing: 20)
    static let hudIcon: CGFloat = 16
    static let hudMetaGap: CGFloat = 14
    static let hudDismissButton: CGFloat = 38

    // Full-screen start alert (PEEK-203)
    static let alertWidth: CGFloat = 520
    static let alertInsets = EdgeInsets(top: 28, leading: 28, bottom: 22, trailing: 28)
    static let alertSectionGap: CGFloat = 18
    static let alertButtonHeight: CGFloat = 48
    static let alertPillInsets = EdgeInsets(top: 5, leading: 11, bottom: 5, trailing: 11)
    static let alertBriefInsets = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    static let alertButtonInsets = EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)

    // Focus ring
    static let focusRing: CGFloat = 3
    static let focusRingHighContrast: CGFloat = 4
    static let focusRingOpacity: Double = 0.55
}

/// Animation durations, always gated by `PeekMotion.reduceMotion`.
enum PeekDuration {
    static let press: Double = 0.08
    static let step: Double = 0.2
    static let dotPulse: Double = 0.6
    static let rowPulse: Double = 1.6
}

// MARK: - Elevation

enum PeekElevation {
    case card
    case popover
    case hud
    case window

    var color: Color { PeekColor.shadow }

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
