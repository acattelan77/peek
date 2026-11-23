import SwiftUI

/// The full-screen start-of-meeting alert (PEEK-203): a dimmed backdrop with one
/// centered card. Return joins, Escape dismisses. Pure presentation: the panel,
/// timing and snooze live in `StartingNowHUDController`.
struct MeetingStartAlert: View {
    let title: String
    let startTime: String
    let detail: String
    /// "You're about to meet Marco, CEO at Northwind" when known.
    var contextLine: String? = nil
    /// Up to three "what to prepare" points from the meeting brief.
    var briefPoints: [String] = []
    /// Provider label such as "Zoom"; when non-nil the Join button is shown.
    let joinProviderLabel: String?
    var appearanceMode: AppearanceMode = .auto

    let onJoin: () -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        ZStack {
            PeekColor.scrim
                .ignoresSafeArea()
                .accessibilityHidden(true)

            card
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: PeekMetrics.alertSectionGap) {
            HStack {
                PeekStatusPill(text: String(
                    format: NSLocalizedString("STARTING NOW · %@", comment: "Full-screen alert pill with start time"),
                    startTime
                ))
                Spacer()
                HStack(spacing: PeekSpacing.iconGap) {
                    Text("Peek")
                        .font(PeekFont.captionStrong)
                        .foregroundColor(PeekColor.secondaryText)
                    PeekAppIcon(size: PeekMetrics.hudIcon, cornerRadius: PeekRadius.badge)
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: PeekSpacing.iconGap) {
                Text(title)
                    .font(PeekFont.display)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(PeekFont.body)
                    .foregroundColor(PeekColor.bodyText)
                    .lineLimit(2)

                if let contextLine {
                    Text(contextLine)
                        .font(PeekFont.bodyEmphasis)
                        .foregroundColor(PeekColor.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !briefPoints.isEmpty {
                    VStack(alignment: .leading, spacing: PeekSpacing.xs) {
                        ForEach(Array(briefPoints.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
                                Image(systemName: "checkmark.circle")
                                    .font(PeekIcon.detail)
                                    .foregroundColor(PeekColor.tertiaryText)
                                    .accessibilityHidden(true)
                                Text(point)
                                    .font(PeekFont.body)
                                    .foregroundColor(PeekColor.bodyText)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, PeekSpacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }

            HStack(spacing: PeekSpacing.sm) {
                if let joinProviderLabel {
                    Button(action: onJoin) {
                        HStack(spacing: PeekSpacing.iconGap) {
                            Image(systemName: "video.fill")
                                .font(PeekIcon.meta)
                                .accessibilityHidden(true)
                            Text(String(
                                format: NSLocalizedString("Join %@", comment: "Full-screen alert join button with provider"),
                                joinProviderLabel
                            ))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }

                Button(NSLocalizedString("In 1 minute", comment: "Full-screen alert snooze button"), action: onSnooze)
                    .buttonStyle(SecondaryFillButtonStyle())

                Button(NSLocalizedString("Dismiss", comment: "Full-screen alert dismiss button"), action: onDismiss)
                    .buttonStyle(SecondaryFillButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }

            Text(joinProviderLabel == nil
                 ? NSLocalizedString("Esc to dismiss", comment: "Full-screen alert keyboard hint without join")
                 : NSLocalizedString("Return to join · Esc to dismiss", comment: "Full-screen alert keyboard hint"))
                .font(PeekFont.caption)
                .foregroundColor(PeekColor.tertiaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(PeekMetrics.alertInsets)
        .frame(width: PeekMetrics.alertWidth)
        .background(PeekColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.hud, style: .continuous))
        .peekShadow(.hud)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
