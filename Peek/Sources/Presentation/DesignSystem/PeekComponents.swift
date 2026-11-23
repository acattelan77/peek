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
            .font(PeekFont.captionStrong)
            .tracking(PeekFont.groupLabelTracking)
            .foregroundColor(PeekColor.tertiaryText)
            .padding(.horizontal, PeekSpacing.xs)
            .padding(.bottom, PeekSpacing.sm)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PeekFont.bodyMetaStrong)
            .foregroundColor(tone.onFill)
            .padding(PeekMetrics.joinButtonInsets)
            .background(tone.fill.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.join, style: .continuous))
            .contentShape(Rectangle())
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
