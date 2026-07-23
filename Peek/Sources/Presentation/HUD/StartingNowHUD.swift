import SwiftUI
import AppKit

/// High-signal "Starting now" heads-up card shown top-right when a meeting is imminent.
/// Pure presentation: the hosting window and timing live in the composition root.
struct StartingNowHUD: View {
    /// Fixed card width, shared with the composition root for panel placement.
    static let cardWidth: CGFloat = 380
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
    var appearanceMode: AppearanceMode = .auto

    let onJoin: () -> Void
    let onSnooze: () -> Void
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
            .frame(height: 4)

            VStack(alignment: .leading, spacing: 12) {
                header
                Text(title)
                    .font(PeekFont.onboardingTitle)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(2)
                metaRow
                actionRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
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
            HStack(spacing: 5) {
                PulsingDot(color: PeekColor.critical, size: 6)
                Text(NSLocalizedString("STARTING NOW", comment: "HUD status pill"))
                    .font(PeekFont.captionStrong)
                    .tracking(0.6)
                    .foregroundColor(PeekColor.critical)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PeekColor.criticalWash)
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 6) {
                Text("Peek")
                    .font(PeekFont.captionStrong)
                    .foregroundColor(PeekColor.secondaryText)
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(PeekColor.secondaryText)
                Text(timeRange)
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            }
            if let calendarName {
                HStack(spacing: 6) {
                    Circle()
                        .fill(calendarColor ?? PeekColor.secondaryText)
                        .frame(width: 8, height: 8)
                    Text(calendarName)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.secondaryText)
                }
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            if let joinProviderLabel {
                Button(action: onJoin) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
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

            Button(action: onSnooze) {
                Text(NSLocalizedString("Snooze 5 min", comment: "HUD snooze button"))
            }
            .buttonStyle(SecondaryFillButtonStyle())

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PeekColor.secondaryText)
                    .frame(width: 38, height: 38)
                    .background(PeekColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Dismiss", comment: "HUD dismiss help"))
            .accessibilityLabel(Text(NSLocalizedString("Dismiss", comment: "HUD dismiss help")))
        }
    }
}
