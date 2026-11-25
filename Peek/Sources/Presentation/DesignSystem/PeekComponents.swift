import SwiftUI
import AppKit

// MARK: - Motion helper

enum PeekMotion {
    /// System-wide Reduce Motion preference (AppKit source of truth) for non-view callers.
    /// Views should prefer `@Environment(\.accessibilityReduceMotion)`, which updates live.
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

// MARK: - Uppercase status badge (NEXT / SOON / NOW / ALL DAY)

struct PeekBadge: View {
    enum Kind {
        case next
        case soon
        case now
        case allDay

        var text: String {
            switch self {
            case .next: return NSLocalizedString("NEXT", comment: "Badge: next event")
            case .soon: return NSLocalizedString("SOON", comment: "Badge: event soon")
            case .now: return NSLocalizedString("NOW", comment: "Badge: event now")
            case .allDay: return NSLocalizedString("ALL DAY", comment: "Badge: all-day event")
            }
        }

        var tone: PeekTone {
            switch self {
            case .next: return .accent
            case .soon, .allDay: return .urgent
            case .now: return .critical
            }
        }

        var showsPulsingDot: Bool { self == .now }
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 3) {
            if kind.showsPulsingDot {
                PulsingDot(color: kind.tone.onFill, size: PeekMetrics.pulsingDotSmall)
            }
            Text(kind.text)
                .font(PeekFont.label)
                .tracking(PeekFont.labelTracking)
                .foregroundColor(kind.tone.onFill)
        }
        .padding(PeekMetrics.badgeInsets)
        .background(kind.tone.fill)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.badge, style: .continuous))
    }
}

/// Dot that pulses opacity/scale. Static when Reduce Motion is on, and reacts live when
/// the preference changes.
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = PeekMetrics.pulsingDot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(animate ? 0.35 : 1)
            .scaleEffect(animate ? 0.8 : 1)
            .onAppear(perform: update)
            .onChange(of: reduceMotion) { _ in update() }
            .accessibilityHidden(true)
    }

    private func update() {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { animate = false }
        } else {
            withAnimation(.easeInOut(duration: PeekDuration.dotPulse).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Count pill (header event count)

struct CountPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(PeekFont.captionStrong)
            .foregroundColor(PeekColor.secondaryText)
            .padding(PeekMetrics.countPillInsets)
            .background(PeekColor.fill)
            .clipShape(Capsule())
    }
}

// MARK: - Status pill (HUD "STARTING NOW")

struct PeekStatusPill: View {
    let text: String
    var tone: PeekTone = .critical
    var pulsing: Bool = true

    var body: some View {
        HStack(spacing: PeekSpacing.tightGap) {
            if pulsing {
                PulsingDot(color: tone.rail, size: PeekMetrics.pulsingDot)
            }
            Text(text)
                .font(PeekFont.captionStrong)
                .tracking(0.6)
                .foregroundColor(tone.text)
        }
        .padding(PeekMetrics.statusPillInsets)
        .background(tone.wash)
        .clipShape(Capsule())
    }
}

// MARK: - Icon tile (empty states, onboarding)

struct PeekIconTile: View {
    let systemName: String
    var tone: PeekTone = .accent
    var size: CGFloat = PeekMetrics.emptyTile
    var cornerRadius: CGFloat = PeekRadius.tile
    var iconFont: Font = PeekIcon.emptyState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tone == .accent ? PeekColor.blueTint : tone.wash)
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(iconFont)
                .foregroundColor(tone.text)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - App icon image

struct PeekAppIcon: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Section header (title + subtitle)

struct PeekSectionHeader: View {
    let title: String
    var subtitle: String?
    var titleFont: Font = PeekFont.title

    var body: some View {
        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            Text(title)
                .font(titleFont)
                .foregroundColor(PeekColor.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preferences group label + inset card

struct GroupLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(PeekFont.sectionLabel)
            .tracking(PeekFont.groupLabelTracking)
            .foregroundColor(PeekColor.tertiaryText)
            .padding(.horizontal, PeekSpacing.xs)
            .padding(.bottom, PeekSpacing.iconGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Surface card with a hairline border and rounded corners; used to group
/// settings rows. Rows inside are separated with `RowDivider`.
struct InsetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(PeekColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
    }
}

/// Centered placeholder line inside an `InsetCard` (no access, nothing found).
struct InsetCardMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(PeekSpacing.xxl)
    }
}

/// A single settings row (label + trailing control) with consistent padding.
struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: PeekSpacing.md) {
            VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
                Text(title)
                    .font(PeekFont.body)
                    .foregroundColor(PeekColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: PeekSpacing.md)
            trailing
        }
        .padding(PeekMetrics.settingRowInsets)
    }
}

/// Explanatory or error line under a settings row.
struct SettingFootnote: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(PeekFont.caption)
            .foregroundColor(isError ? PeekColor.criticalText : PeekColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PeekMetrics.footnoteInsets)
    }
}

/// Full-width hairline used between rows inside an `InsetCard`.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(PeekColor.innerDivider)
            .frame(height: PeekSpacing.hairline)
            .accessibilityHidden(true)
    }
}

/// Native switch tinted with the Peek accent.
struct PeekSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String

    var body: some View {
        Toggle(accessibilityLabel, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(PeekColor.accent)
    }
}

// MARK: - Shared selection rows and chips

struct PeekCheckboxRow<Trailing: View>: View {
    let label: String
    var color: Color?
    var isOn: Bool
    var accessibilityValue: String?
    let onToggle: () -> Void
    @ViewBuilder var trailing: Trailing

    init(
        label: String,
        color: Color? = nil,
        isOn: Bool,
        accessibilityValue: String? = nil,
        onToggle: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.color = color
        self.isOn = isOn
        self.accessibilityValue = accessibilityValue
        self.onToggle = onToggle
        self.trailing = trailing()
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: PeekMetrics.headerGap) {
                checkbox

                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: PeekMetrics.colorSwatch, height: PeekMetrics.colorSwatch)
                        .accessibilityHidden(true)
                }

                Text(label)
                    .font(PeekFont.body)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(1)

                Spacer(minLength: PeekSpacing.md)
                trailing
            }
            .contentShape(Rectangle())
            .padding(PeekMetrics.checkboxRowInsets)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityValue(accessibilityValue ?? (isOn
            ? NSLocalizedString("Selected", comment: "Accessibility value for selected checkbox row")
            : ""))
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: PeekRadius.checkbox, style: .continuous)
            .fill(isOn ? PeekColor.accent : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: PeekRadius.checkbox, style: .continuous)
                    .strokeBorder(isOn ? PeekColor.accent : PeekColor.controlStroke, lineWidth: PeekMetrics.checkboxStroke)
            )
            .frame(width: PeekMetrics.checkbox, height: PeekMetrics.checkbox)
            .overlay(
                Image(systemName: "checkmark")
                    .font(PeekIcon.checkmark)
                    .foregroundColor(PeekColor.onAccent)
                    .opacity(isOn ? 1 : 0)
            )
            .accessibilityHidden(true)
    }
}

struct PeekKeywordChip: View {
    let title: String
    var removeHelp: String = NSLocalizedString("Remove keyword", comment: "Keyword chip remove help")
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: PeekSpacing.tightGap) {
            Text(title)
                .font(PeekFont.captionStrong)
                .foregroundColor(PeekColor.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(title)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(PeekIcon.chipRemove)
                    .foregroundColor(PeekColor.secondaryText)
                    .frame(width: PeekMetrics.chipRemoveTarget, height: PeekMetrics.chipRemoveTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(removeHelp)
            .accessibilityLabel(Text(String(
                format: NSLocalizedString("Remove %@", comment: "Accessibility: remove keyword"),
                title
            )))
        }
        .padding(PeekMetrics.chipInsets)
        .background(PeekColor.chip)
        .clipShape(Capsule())
    }
}

/// A calendar in Preferences > Alerts > Which meetings. Clicking it toggles
/// "badge only": its events stay in the menu bar but never notify or interrupt.
struct PeekCalendarAlertChip: View {
    let title: String
    let color: Color
    let badgeOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: PeekSpacing.iconGap) {
                Circle()
                    .fill(color)
                    .frame(width: PeekMetrics.calendarDot, height: PeekMetrics.calendarDot)
                    .accessibilityHidden(true)
                Text(badgeOnly
                    ? String(format: NSLocalizedString("%@ · badge only", comment: "Calendar chip: events only show in the menu bar"), title)
                    : title)
                    .font(PeekFont.footerMeta)
                    .foregroundColor(badgeOnly ? PeekColor.tertiaryText : PeekColor.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(PeekMetrics.chipInsets)
            .background(badgeOnly ? PeekColor.surface : PeekColor.chip)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    badgeOnly ? PeekColor.controlStroke : Color.clear,
                    style: StrokeStyle(lineWidth: PeekSpacing.hairline, dash: PeekMetrics.chipDash)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(badgeOnly
            ? NSLocalizedString("Badge only", comment: "Accessibility value: calendar only shows in the menu bar")
            : NSLocalizedString("Alerts on", comment: "Accessibility value: calendar notifies and interrupts")))
    }
}

/// Lays children out left to right and wraps them onto new lines, each at
/// its natural width (chips, world clocks).
struct PeekFlowLayout: Layout {
    var spacing: CGFloat = PeekSpacing.iconGap
    var lineSpacing: CGFloat = PeekSpacing.iconGap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let proposed = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        return CGSize(width: proposed ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// One world clock: city and time on a single line, on the same fill as
/// the header buttons so the strip reads apart from the month grid.
struct PeekWorldClockChip: View {
    let city: String
    let time: String

    var body: some View {
        HStack(spacing: PeekSpacing.iconGap) {
            Text(city)
                .font(PeekFont.caption)
                .foregroundColor(PeekColor.secondaryText)
                .lineLimit(1)
            Text(time)
                .font(PeekFont.bodyMetaStrong)
                .foregroundColor(PeekColor.ink)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(PeekMetrics.worldClockInsets)
        .background(PeekColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tabs

/// Underlined text tab used by Preferences.
struct PeekTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PeekSpacing.iconGap) {
                Text(title)
                    .font(isSelected ? PeekFont.bodyEmphasis : PeekFont.body)
                    .foregroundColor(isSelected ? PeekColor.ink : PeekColor.secondaryText)
                    .lineLimit(1)
                    .fixedSize()
                Rectangle()
                    .fill(isSelected ? PeekColor.accentRail : Color.clear)
                    .frame(height: PeekMetrics.tabIndicator)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, PeekSpacing.sm)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Popover list section label (TODAY / TOMORROW)

struct PeekSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(PeekFont.sectionLabel)
            .tracking(PeekFont.groupLabelTracking)
            .foregroundColor(PeekColor.tertiaryText)
            .padding(PeekMetrics.sectionLabelInsets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Header navigation buttons (‹ Today ›)

/// Small neutral fill button used in the popover header: square for chevrons,
/// padded for "Today".
struct HeaderNavButtonStyle: ButtonStyle {
    var square: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HeaderNavButtonBody(configuration: configuration, square: square)
    }

    private struct HeaderNavButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let square: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(PeekFont.navButton)
                .foregroundColor(PeekColor.bodyText)
                .padding(.horizontal, square ? 0 : PeekSpacing.md - PeekSpacing.xxs)
                .frame(width: square ? PeekMetrics.headerNavButton : nil, height: PeekMetrics.headerNavButton)
                .background(PeekColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? PeekMetrics.pressedOpacity : 1) : PeekMetrics.disabledOpacity)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Avatar (meeting page)

/// Round initials badge. The lead person uses the accent tint, others stay neutral.
struct PeekAvatar: View {
    let initials: String
    var isLead: Bool = false

    var body: some View {
        Text(initials)
            .font(PeekFont.captionStrong)
            .foregroundColor(isLead ? PeekColor.accentText : PeekColor.bodyText)
            .frame(width: PeekMetrics.avatar, height: PeekMetrics.avatar)
            .background(Circle().fill(isLead ? PeekColor.blueTint : PeekColor.chip))
            .accessibilityHidden(true)
    }

    /// "Ada Lovelace" → "AL", "Ada" → "A", "l.ferri@example.com" → "L".
    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "@" })
        let source = name.contains("@") ? Array(words.prefix(1)) : Array(words.prefix(2))
        return source.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }
}

// MARK: - Toolbar icon button (popover footer)

struct PeekToolbarButton: View {
    let systemName: String
    let help: String
    var tint: Color? = nil
    var isBusy: Bool = false
    var disabled: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                } else {
                    Image(systemName: systemName)
                        .font(PeekIcon.toolbar)
                        .foregroundColor(foreground)
                }
            }
            .frame(width: PeekMetrics.toolbarButton, height: PeekMetrics.toolbarButton)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !isBusy ? PeekMetrics.disabledOpacity : 1)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(Text(help))
    }

    private var foreground: Color {
        if let tint { return tint }
        return hovering && !disabled ? PeekColor.accentText : PeekColor.secondaryText
    }
}

// MARK: - Button styles

/// Solid accent button (primary actions). Darkens on press; subtle scale unless Reduce Motion.
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, fullWidth: fullWidth)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(PeekFont.button)
                .foregroundColor(PeekColor.onAccent)
                .padding(PeekMetrics.primaryButtonInsets)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(configuration.isPressed ? PeekColor.accentPressed : PeekColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: PeekRadius.join, style: .continuous))
                .opacity(isEnabled ? 1 : PeekMetrics.disabledOpacity)
                .scaleEffect(configuration.isPressed && !reduceMotion ? PeekMetrics.pressedScale : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: PeekDuration.press), value: configuration.isPressed)
                .contentShape(Rectangle())
        }
    }
}

/// Soft accent button (blue tint background, accent text).
struct SoftAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SmallButtonBody(
            configuration: configuration,
            foreground: PeekColor.accentText,
            background: PeekColor.blueTint
        )
    }
}

/// Neutral fill button (secondary).
struct SecondaryFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SmallButtonBody(
            configuration: configuration,
            foreground: PeekColor.ink,
            background: PeekColor.fill
        )
    }
}

private struct SmallButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let foreground: Color
    let background: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(PeekFont.bodyMetaMedium)
            .foregroundColor(foreground)
            .padding(PeekMetrics.smallButtonInsets)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? PeekMetrics.pressedOpacity : 1) : PeekMetrics.disabledOpacity)
            .contentShape(Rectangle())
    }
}

/// Join button that adopts the row's urgency tone (accent, amber with dark text, red).
struct JoinButtonStyle: ButtonStyle {
    let tone: PeekTone
    /// Compact buttons set their own height, so only horizontal padding applies.
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PeekFont.bodyMetaStrong)
            .foregroundColor(tone.onFill)
            .padding(compact
                ? EdgeInsets(top: 0, leading: PeekMetrics.joinButtonInsets.leading, bottom: 0, trailing: PeekMetrics.joinButtonInsets.trailing)
                : PeekMetrics.joinButtonInsets)
            .background(tone.fill.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.join, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// Large buttons of the full-screen start alert: solid accent, neutral fill, or plain.
struct AlertButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, plain }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(kind == .primary ? PeekFont.alertButton : PeekFont.alertSecondaryButton)
            .foregroundColor(foreground)
            .padding(PeekMetrics.alertButtonInsets)
            .frame(height: PeekMetrics.alertButtonHeight)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.alertButton, style: .continuous))
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: return PeekColor.onAccent
        case .secondary: return PeekColor.ink
        case .plain: return PeekColor.secondaryText
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: return pressed ? PeekColor.accentPressed : PeekColor.accent
        case .secondary: return pressed ? PeekColor.chip : PeekColor.fill
        case .plain: return pressed ? PeekColor.fill : Color.clear
        }
    }
}

// MARK: - Critical pulse

/// Static or pulsing outer ring for a critical row. Starts when `active` turns true
/// while the row is on screen, and stays static under Reduce Motion (live).
private struct CriticalPulse: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(PeekColor.critical.opacity(ringOpacity), lineWidth: PeekMetrics.focusRing)
                .allowsHitTesting(false)
        )
        .onAppear(perform: update)
        .onChange(of: active) { _ in update() }
        .onChange(of: reduceMotion) { _ in update() }
    }

    private var ringOpacity: Double {
        guard active else { return 0 }
        return pulse ? 0.05 : 0.35
    }

    private func update() {
        if active && !reduceMotion {
            withAnimation(.easeInOut(duration: PeekDuration.rowPulse).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { pulse = false }
        }
    }
}

extension View {
    func peekCriticalPulse(_ active: Bool, cornerRadius: CGFloat = PeekRadius.row) -> some View {
        modifier(CriticalPulse(active: active, cornerRadius: cornerRadius))
    }
}

// MARK: - Focus ring

private struct FocusRing: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let increased = contrast == .increased
        return content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    PeekColor.accentRail.opacity(increased ? 1 : PeekMetrics.focusRingOpacity),
                    lineWidth: active ? (increased ? PeekMetrics.focusRingHighContrast : PeekMetrics.focusRing) : 0
                )
                .allowsHitTesting(false)
        )
    }
}

extension View {
    /// Accent focus ring (solid and wider under Increased Contrast) shown when `active`.
    func peekFocusRing(_ active: Bool, cornerRadius: CGFloat = PeekRadius.row) -> some View {
        modifier(FocusRing(active: active, cornerRadius: cornerRadius))
    }
}

// MARK: - Previews

#if DEBUG
struct PeekComponents_Previews: PreviewProvider {
    static var gallery: some View {
        VStack(alignment: .leading, spacing: PeekSpacing.md) {
            HStack(spacing: PeekSpacing.sm) {
                PeekBadge(kind: .next)
                PeekBadge(kind: .soon)
                PeekBadge(kind: .now)
                PeekBadge(kind: .allDay)
                CountPill(count: 4)
                PeekStatusPill(text: "STARTING NOW")
            }
            HStack(spacing: PeekSpacing.sm) {
                Button("Primary") {}.buttonStyle(PrimaryButtonStyle())
                Button("Disabled") {}.buttonStyle(PrimaryButtonStyle()).disabled(true)
                Button("Soft") {}.buttonStyle(SoftAccentButtonStyle())
                Button("Secondary") {}.buttonStyle(SecondaryFillButtonStyle())
            }
            HStack(spacing: PeekSpacing.sm) {
                Button("Join Zoom") {}.buttonStyle(JoinButtonStyle(tone: .accent))
                Button("Join now") {}.buttonStyle(JoinButtonStyle(tone: .urgent))
                Button("Join now") {}.buttonStyle(JoinButtonStyle(tone: .critical))
            }
            InsetCard {
                SettingRow("Setting", subtitle: "Explanation") { PeekSwitch(isOn: .constant(true), accessibilityLabel: "Setting") }
                RowDivider()
                PeekCheckboxRow(label: "Work", color: .blue, isOn: true, onToggle: {})
                RowDivider()
                PeekCheckboxRow(label: "Personal", color: .green, isOn: false, onToggle: {})
                SettingFootnote(text: "Something went wrong.", isError: true)
            }
            HStack(spacing: PeekSpacing.iconGap) {
                PeekKeywordChip(title: "standup", onRemove: {})
                PeekTabButton(title: "General", isSelected: true, action: {})
                PeekTabButton(title: "Filters", isSelected: false, action: {})
                PeekToolbarButton(systemName: "gearshape", help: "Preferences", action: {})
            }
        }
        .padding(PeekSpacing.xl)
        .background(PeekColor.canvas)
    }

    static var previews: some View {
        gallery.preferredColorScheme(.light).previewDisplayName("Light")
        gallery.preferredColorScheme(.dark).previewDisplayName("Dark")
    }
}
#endif

// MARK: - Menu bar item (Peek 2.0 states)


/// Draws the menu bar item for the Peek 2.0 states.
///
/// Calm and in progress keep the standard template glyph and a plain title,
/// so macOS tints them for a light or dark menu bar. Soon and now are filled
/// pills (amber, then red) drawn as one image, because a status button cannot
/// paint a background behind its title.
enum StatusItemRenderer {
    /// Pill geometry from the mockup: 3 pt by 8 pt padding, 5 pt corners,
    /// a 14 pt glyph and 6 pt between glyph and text.
    static let pillHorizontalPadding: CGFloat = 8
    static let pillVerticalInset: CGFloat = 3
    static let pillCornerRadius: CGFloat = 5
    static let pillGlyphSize: CGFloat = 14
    static let pillGap: CGFloat = 6
    /// Extra width the space policy reserves around a plain title.
    static let plainTitleSlack: CGFloat = 12

    /// Calm and soon titles are medium, now is semibold (mockup weights 500 / 600).
    static func titleFont(for phase: MenuBarPhase, filled: Bool) -> NSFont {
        let size = NSFont.menuBarFont(ofSize: 0).pointSize
        let weight: NSFont.Weight = filled ? .semibold : .medium
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    /// Plain title color: label color while calm, secondary during a meeting.
    static func plainTitleColor(for phase: MenuBarPhase) -> NSColor {
        phase == .inProgress ? .secondaryLabelColor : .labelColor
    }

    static func pillColors(for phase: MenuBarPhase) -> (fill: NSColor, text: NSColor)? {
        switch phase {
        case .soon: return (PeekNSColor.urgent, PeekNSColor.onUrgent)
        case .now: return (PeekNSColor.critical, PeekNSColor.onCritical)
        case .calm, .inProgress: return nil
        }
    }

    static func plainTitle(_ title: String, phase: MenuBarPhase) -> NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: titleFont(for: phase, filled: false),
            .foregroundColor: plainTitleColor(for: phase)
        ])
    }

    /// A filled pill with the glyph and, unless `title` is nil, the text.
    static func pillImage(glyph: NSImage?, title: String?, phase: MenuBarPhase, barThickness: CGFloat) -> NSImage? {
        guard let colors = pillColors(for: phase) else { return nil }
        let font = titleFont(for: phase, filled: true)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colors.text]
        let text = title.map { NSAttributedString(string: $0, attributes: attributes) }
        let textSize = text?.size() ?? .zero

        let height = max(barThickness - 2 * pillVerticalInset, pillGlyphSize + 2 * pillVerticalInset)
        var width = 2 * pillHorizontalPadding + pillGlyphSize
        if text != nil { width += pillGap + ceil(textSize.width) }
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { rect in
            colors.fill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: StatusItemRenderer.pillCornerRadius, yRadius: StatusItemRenderer.pillCornerRadius).fill()

            let glyphRect = NSRect(
                x: StatusItemRenderer.pillHorizontalPadding,
                y: (rect.height - StatusItemRenderer.pillGlyphSize) / 2,
                width: StatusItemRenderer.pillGlyphSize,
                height: StatusItemRenderer.pillGlyphSize
            )
            if let tinted = glyph.map({ StatusItemRenderer.tint($0, with: colors.text, size: glyphRect.size) }) {
                tinted.draw(in: glyphRect)
            }
            if let text {
                let origin = NSPoint(
                    x: glyphRect.maxX + StatusItemRenderer.pillGap,
                    y: (rect.height - textSize.height) / 2
                )
                text.draw(at: origin)
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = title
        return image
    }

    /// Width the item needs for `title`, used by the space policy.
    static func requiredWidth(title: String, phase: MenuBarPhase, filled: Bool, glyphWidth: CGFloat) -> CGFloat {
        let font = titleFont(for: phase, filled: filled)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        if filled {
            return 2 * pillHorizontalPadding + pillGlyphSize + pillGap + ceil(textWidth)
        }
        return glyphWidth + textWidth + plainTitleSlack
    }

    fileprivate static func tint(_ glyph: NSImage, with color: NSColor, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            glyph.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
