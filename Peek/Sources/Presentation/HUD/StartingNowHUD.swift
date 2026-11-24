import SwiftUI
import AppKit

/// High-signal "Starting now" heads-up card shown top-right when a meeting is imminent.
/// Pure presentation: the hosting window and timing live in the composition root.
struct StartingNowHUD: View {
    /// Fixed card width, shared with the composition root for panel placement.
    static let cardWidth: CGFloat = PeekMetrics.hudWidth
    /// Transparent margin around the card so the drop shadow has room inside the
    /// hosting window. Without it the window bounds clip the shadow into a
    /// visible squared edge around the rounded card.
    static var shadowPadding: CGFloat {
        PeekElevation.hud.radius / 2 + PeekElevation.hud.y
    }

    let title: String
    let timeRange: String
    let calendarName: String?
    let calendarColor: Color?
    /// Provider label such as "Zoom"; when non-nil a Join button is shown.
    let joinProviderLabel: String?
    /// "You're about to meet Marco, CEO at Northwind" when known.
    var contextLine: String? = nil
    var appearanceMode: AppearanceMode = .auto
    /// Pill text; "STARTING NOW" unless the card warns ahead ("IN 2 MIN").
    var statusText: String? = nil

    let onJoin: () -> Void
    /// Nil hides the snooze button (the 2-minute card: the start alert follows).
    var onSnooze: (() -> Void)? = nil
    let onClose: () -> Void

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient accent bar (critical → urgent).
            LinearGradient(
                colors: [PeekColor.critical, PeekColor.urgent],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: PeekMetrics.hudAccentBar)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PeekSpacing.md) {
                header
                Text(title)
                    .font(PeekFont.onboardingTitle)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                metaRow
                if let contextLine {
                    Text(contextLine)
                        .font(PeekFont.bodyMetaMedium)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actionRow
            }
            .padding(PeekMetrics.hudInsets)
        }
        .frame(width: Self.cardWidth)
        .background(PeekColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.hud, style: .continuous))
        .peekShadow(.hud)
        .padding(Self.shadowPadding)
        .preferredColorScheme(preferredColorScheme)
    }

    private var header: some View {
        HStack {
            PeekStatusPill(text: statusText ?? NSLocalizedString("STARTING NOW", comment: "HUD status pill"))

            Spacer()

            HStack(spacing: PeekSpacing.iconGap) {
                Text("Peek")
                    .font(PeekFont.captionStrong)
                    .foregroundColor(PeekColor.secondaryText)
                PeekAppIcon(size: PeekMetrics.hudIcon, cornerRadius: PeekRadius.badge)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: PeekMetrics.hudMetaGap) {
            HStack(spacing: PeekSpacing.iconGap) {
                Image(systemName: "clock")
                    .font(PeekIcon.meta)
                    .foregroundColor(PeekColor.secondaryText)
                    .accessibilityHidden(true)
                Text(timeRange)
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            }
            if let calendarName {
                HStack(spacing: PeekSpacing.iconGap) {
                    Circle()
                        .fill(calendarColor ?? PeekColor.secondaryText)
                        .frame(width: PeekMetrics.calendarDot, height: PeekMetrics.calendarDot)
                        .accessibilityHidden(true)
                    Text(calendarName)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.secondaryText)
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var actionRow: some View {
        HStack(spacing: PeekMetrics.headerGap) {
            if let joinProviderLabel {
                Button(action: onJoin) {
                    HStack(spacing: PeekSpacing.iconGap) {
                        Image(systemName: "video.fill")
                            .font(PeekIcon.meta)
                            .accessibilityHidden(true)
                        Text(String(
                            format: NSLocalizedString("Join %@", comment: "HUD join button with provider"),
                            joinProviderLabel
                        ))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(Text(String(
                    format: NSLocalizedString("Join %@", comment: "HUD join button with provider"),
                    joinProviderLabel
                )))
            }

            if let onSnooze {
                Button(action: onSnooze) {
                    Text(NSLocalizedString("Snooze 5 min", comment: "HUD snooze button"))
                }
                .buttonStyle(SecondaryFillButtonStyle())
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(PeekIcon.dismiss)
                    .foregroundColor(PeekColor.secondaryText)
                    .frame(width: PeekMetrics.hudDismissButton, height: PeekMetrics.hudDismissButton)
                    .background(PeekColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Dismiss", comment: "HUD dismiss help"))
            .accessibilityLabel(Text(NSLocalizedString("Dismiss", comment: "HUD dismiss help")))
        }
    }
}
