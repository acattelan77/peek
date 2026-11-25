import SwiftUI

/// The full-screen start-of-meeting alert (PEEK-203): a dimmed backdrop with one
/// centered card. Return joins, Escape dismisses. Pure presentation: the panel,
/// timing and snooze live in `StartingNowHUDController`.
struct MeetingStartAlert: View {
    let title: String
    let startTime: String
    let detail: String
    /// "You're about to meet Ada, CEO at Northwind" when known.
    var contextLine: String? = nil
    /// Up to three "what to prepare" points from the meeting brief.
    var briefPoints: [String] = []
    /// Provider label such as "Zoom"; when non-nil the Join button is shown.
    let joinProviderLabel: String?
    var appearanceMode: AppearanceMode = .auto
    /// Minutes since the start when the alert shows late, after a wake (PEEK-271).
    var minutesLate: Int? = nil

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

    private var pillText: String {
        if let minutesLate {
            return String(
                format: NSLocalizedString("STARTED %d MIN AGO · %@", comment: "Full-screen alert pill when a meeting started a few minutes ago, after sleep; placeholders are minutes and start time"),
                minutesLate, startTime
            )
        }
        return String(
            format: NSLocalizedString("STARTING NOW · %@", comment: "Full-screen alert pill with start time"),
            startTime
        )
    }

    /// The headline says who you are meeting when known; the event title moves below it.
    private var headline: String { contextLine ?? title }
    private var subtitle: String? { contextLine == nil ? nil : title }

    private var card: some View {
        VStack(alignment: .leading, spacing: PeekMetrics.alertSectionGap) {
            HStack(spacing: PeekSpacing.sm) {
                HStack(spacing: PeekSpacing.iconGap) {
                    PulsingDot(color: PeekColor.onCritical, size: PeekMetrics.pulsingDot)
                    Text(pillText)
                    .font(PeekFont.captionStrong)
                    .tracking(PeekFont.labelTracking)
                    .foregroundColor(PeekColor.onCritical)
                }
                .padding(PeekMetrics.alertPillInsets)
                .background(Capsule().fill(PeekColor.critical))

                Spacer(minLength: PeekSpacing.sm)

                if !detail.isEmpty {
                    Text(detail)
                        .font(PeekFont.footerMeta)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: PeekSpacing.iconGap) {
                Text(headline)
                    .font(PeekFont.alertTitle)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(PeekFont.alertSubtitle)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(2)
                }
            }

            if let first = briefPoints.first {
                VStack(alignment: .leading, spacing: PeekSpacing.xs) {
                    Text(NSLocalizedString("FIRST THING TO PREPARE", comment: "Full-screen alert: label above the first brief point"))
                        .font(PeekFont.captionStrong)
                        .tracking(PeekFont.weekdayTracking)
                        .foregroundColor(PeekColor.accentText)
                    Text(first)
                        .font(PeekFont.alertBrief)
                        .foregroundColor(PeekColor.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(PeekMetrics.alertBriefInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PeekColor.nextWash)
                .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: PeekMetrics.headerGap) {
                if let joinProviderLabel {
                    Button(action: onJoin) {
                        Text(String(
                            format: NSLocalizedString("Join %@", comment: "Full-screen alert join button with provider"),
                            joinProviderLabel
                        ))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AlertButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }

                Button(NSLocalizedString("In 1 minute", comment: "Full-screen alert snooze button"), action: onSnooze)
                    .buttonStyle(AlertButtonStyle(kind: .secondary))

                Button(NSLocalizedString("Dismiss", comment: "Full-screen alert dismiss button"), action: onDismiss)
                    .buttonStyle(AlertButtonStyle(kind: .plain))
                    .keyboardShortcut(.cancelAction)
            }

            Text(joinProviderLabel == nil
                 ? NSLocalizedString("Esc to dismiss", comment: "Full-screen alert keyboard hint without join")
                 : NSLocalizedString("Return to join · Esc to dismiss", comment: "Full-screen alert keyboard hint"))
                .font(PeekFont.footerMeta)
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
