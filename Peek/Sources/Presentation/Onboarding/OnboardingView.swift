import SwiftUI
import EventKit

/// First-run onboarding: welcome → calendar access → pick calendars.
/// Presented in its own window at first launch and dismissed via `onFinish`.
struct OnboardingView: View {
    @ObservedObject var calendarManager: CalendarManager
    let onFinish: () -> Void

    @State private var step = 0
    @State private var isRequestingAccess = false

    private var preferredColorScheme: ColorScheme? {
        switch calendarManager.appearanceMode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcomeStep
                case 1: accessStep
                default: calendarsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            progressDots
                .padding(.top, PeekSpacing.lg)
                .padding(.bottom, PeekSpacing.xl)
        }
        .frame(width: PeekMetrics.onboardingSize.width, height: PeekMetrics.onboardingSize.height)
        .background(PeekColor.surface)
        .preferredColorScheme(preferredColorScheme)
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(spacing: PeekSpacing.lg) {
            Spacer()
            PeekAppIcon(size: PeekMetrics.onboardingIcon, cornerRadius: PeekRadius.appIconLarge)
            Text(NSLocalizedString("Welcome to Peek", comment: "Onboarding welcome title"))
                .font(PeekFont.display)
                .foregroundColor(PeekColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString(
                "Your next meeting, always one glance away in the menu bar — with a one-click join the moment it starts.",
                comment: "Onboarding welcome body"
            ))
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: PeekMetrics.onboardingTextMaxWidth)
            Spacer()
            Button(NSLocalizedString("Get started", comment: "Onboarding welcome primary")) {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, PeekSpacing.huge)
        }
        .padding(.horizontal, PeekSpacing.xxl)
        .padding(.top, PeekSpacing.xxxl)
    }

    private var accessStep: some View {
        VStack(spacing: PeekMetrics.cardContentPadding) {
            Spacer()
            PeekIconTile(
                systemName: "calendar",
                size: PeekMetrics.onboardingTile,
                cornerRadius: PeekRadius.hud,
                iconFont: PeekIcon.hero
            )
            Text(NSLocalizedString("Connect your calendar", comment: "Onboarding access title"))
                .font(PeekFont.onboardingTitle)
                .foregroundColor(PeekColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString(
                "Peek reads your events to show what's next. That's all — nothing leaves your Mac.",
                comment: "Onboarding access body"
            ))
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: PeekMetrics.onboardingTextMaxWidth)

            HStack(spacing: PeekSpacing.iconGap) {
                Image(systemName: "lock.fill")
                    .font(PeekIcon.detail)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("Read-only · stays local", comment: "Onboarding trust line"))
                    .font(PeekFont.caption)
            }
            .foregroundColor(PeekColor.calmText)

            Spacer()

            Button {
                requestAccess()
            } label: {
                Text(isRequestingAccess
                     ? NSLocalizedString("Requesting…", comment: "Onboarding requesting access")
                     : NSLocalizedString("Grant calendar access", comment: "Onboarding access primary"))
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .keyboardShortcut(.defaultAction)
            .disabled(isRequestingAccess)
            .padding(.horizontal, PeekSpacing.huge)

            Button(NSLocalizedString("Maybe later", comment: "Onboarding skip access")) {
                advance()
            }
            .buttonStyle(.plain)
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .disabled(isRequestingAccess)
        }
        .padding(.horizontal, PeekSpacing.xxl)
        .padding(.top, PeekSpacing.xxxl)
    }

    private var calendarsStep: some View {
        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            PeekSectionHeader(
                title: NSLocalizedString("What should Peek watch?", comment: "Onboarding calendars title"),
                subtitle: NSLocalizedString("You can change this anytime in Settings.", comment: "Onboarding calendars subtitle"),
                titleFont: PeekFont.onboardingTitle
            )

            InsetCard {
                if !calendarManager.hasCalendarAccess {
                    InsetCardMessage(text: NSLocalizedString("Calendar access not granted", comment: "Onboarding no access"))
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            let calendars = calendarManager.getAllCalendars().sorted { $0.title < $1.title }
                            ForEach(Array(calendars.enumerated()), id: \.element.calendarIdentifier) { index, calendar in
                                PeekCheckboxRow(
                                    label: calendar.title,
                                    color: Color(calendar.color),
                                    isOn: calendarManager.isCalendarEnabled(calendar.calendarIdentifier),
                                    onToggle: {
                                        calendarManager.toggleCalendar(calendar.calendarIdentifier)
                                    }
                                )
                                if index < calendars.count - 1 { RowDivider() }
                            }
                        }
                    }
                    .frame(maxHeight: PeekMetrics.onboardingListMaxHeight)
                }
            }

            Spacer(minLength: PeekSpacing.sm)

            Button(NSLocalizedString("Start using Peek", comment: "Onboarding finish primary")) {
                onFinish()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, PeekSpacing.xxl)
        .padding(.top, PeekSpacing.xxxl)
    }

    // MARK: Progress

    private var progressDots: some View {
        HStack(spacing: PeekSpacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == step ? PeekColor.accentRail : PeekColor.controlBorder)
                    .frame(width: PeekMetrics.progressDot, height: PeekMetrics.progressDot)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: NSLocalizedString("Step %d of 3", comment: "Onboarding progress"),
            step + 1
        )))
    }

    // MARK: Actions

    private func advance() {
        withAnimation(PeekMotion.reduceMotion ? nil : .easeOut(duration: PeekDuration.step)) {
            step = min(step + 1, 2)
        }
    }

    private func requestAccess() {
        isRequestingAccess = true
        calendarManager.requestAccess { _, _ in
            isRequestingAccess = false
            calendarManager.loadEnabledCalendars()
            advance()
        }
    }
}
