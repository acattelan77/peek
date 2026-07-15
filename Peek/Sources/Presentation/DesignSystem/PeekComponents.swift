import SwiftUI
import AppKit

// MARK: - Motion helper

enum PeekMotion {
    /// System-wide Reduce Motion preference (AppKit source of truth).
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

        var background: Color {
            switch self {
            case .next: return PeekColor.accent
            case .soon: return PeekColor.urgent
            case .now: return PeekColor.critical
            case .allDay: return PeekColor.urgent
            }
        }

        var showsPulsingDot: Bool { self == .now }
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 3) {
            if kind.showsPulsingDot {
                PulsingDot(color: .white, size: 5)
            }
            Text(kind.text)
                .font(PeekFont.label)
                .tracking(0.5)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(kind.background)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// White dot that pulses opacity/scale, honoring Reduce Motion (static when reduced).
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 6
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(animate ? 0.35 : 1)
            .scaleEffect(animate ? 0.8 : 1)
            .onAppear {
                guard !PeekMotion.reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
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
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(PeekColor.fill)
            .clipShape(Capsule())
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
            .font(Font.system(size: 11, weight: .semibold))
            .tracking(0.66)
            .foregroundColor(PeekColor.tertiaryText)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// White inset card with a hairline border and rounded corners; used to group
/// settings rows. Rows inside are separated with `PeekColor.innerDivider`.
struct InsetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(PeekColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
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
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Full-width hairline used between rows inside an `InsetCard`.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(PeekColor.innerDivider)
            .frame(height: 1)
    }
}

// MARK: - Button styles

/// Solid accent button (primary actions). Darkens on press; subtle scale unless Reduce Motion.
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(configuration.isPressed ? PeekColor.accentPressed : PeekColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.join, style: .continuous))
            .scaleEffect(configuration.isPressed && !PeekMotion.reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Soft accent button (blue tint background, accent text).
struct SoftAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.system(size: 12.5, weight: .medium))
            .foregroundColor(PeekColor.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PeekColor.blueTint)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Neutral fill button (secondary).
struct SecondaryFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.system(size: 12.5, weight: .medium))
            .foregroundColor(PeekColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PeekColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Focus ring

extension View {
    /// 3pt accent focus ring (widens under Increased Contrast) shown when `active`.
    func peekFocusRing(_ active: Bool, cornerRadius: CGFloat = PeekRadius.row) -> some View {
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(PeekColor.accent.opacity(0.40), lineWidth: active ? (increaseContrast ? 4 : 3) : 0)
        )
    }
}
