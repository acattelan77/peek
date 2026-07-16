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
                .padding(.top, 18)
                .padding(.bottom, 20)
        }
        .frame(width: 420, height: 460)
        .background(PeekColor.surface)
        .preferredColorScheme(preferredColorScheme)
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            Text(NSLocalizedString("Welcome to Peek", comment: "Onboarding welcome title"))
                .font(PeekFont.display)
                .foregroundColor(PeekColor.ink)
            Text(NSLocalizedString(
                "Your next meeting, always one glance away in the menu bar — with a one-click join the moment it starts.",
                comment: "Onboarding welcome body"
            ))
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            Spacer()
            Button(NSLocalizedString("Get started", comment: "Onboarding welcome primary")) {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private var accessStep: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PeekColor.blueTint)
                    .frame(width: 72, height: 72)
                Image(systemName: "calendar")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(PeekColor.accent)
            }
            Text(NSLocalizedString("Connect your calendar", comment: "Onboarding access title"))
                .font(PeekFont.onboardingTitle)
                .foregroundColor(PeekColor.ink)
            Text(NSLocalizedString(
                "Peek reads your events to show what's next. That's all — nothing leaves your Mac.",
                comment: "Onboarding access body"
            ))
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text(NSLocalizedString("Read-only · stays local", comment: "Onboarding trust line"))
                    .font(PeekFont.caption)
            }
            .foregroundColor(PeekColor.calm)

            Spacer()

            Button {
                requestAccess()
            } label: {
                Text(isRequestingAccess
                     ? NSLocalizedString("Requesting…", comment: "Onboarding requesting access")
                     : NSLocalizedString("Grant calendar access", comment: "Onboarding access primary"))
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .disabled(isRequestingAccess)
            .padding(.horizontal, 40)

            Button(NSLocalizedString("Maybe later", comment: "Onboarding skip access")) {
                advance()
            }
            .buttonStyle(.plain)
            .font(PeekFont.bodyMeta)
            .foregroundColor(PeekColor.secondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private var calendarsStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("What should Peek watch?", comment: "Onboarding calendars title"))
                .font(PeekFont.onboardingTitle)
                .foregroundColor(PeekColor.ink)
            Text(NSLocalizedString("You can change this anytime in Settings.", comment: "Onboarding calendars subtitle"))
                .font(PeekFont.bodyMeta)
                .foregroundColor(PeekColor.secondaryText)

            InsetCard {
                if !calendarManager.hasCalendarAccess {
                    Text(NSLocalizedString("Calendar access not granted", comment: "Onboarding no access"))
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(24)
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
                    .frame(maxHeight: 200)
                }
            }

            Spacer(minLength: 8)

            Button(NSLocalizedString("Start using Peek", comment: "Onboarding finish primary")) {
                onFinish()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    // MARK: Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == step ? PeekColor.accent : PeekColor.controlBorder)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel(Text(String(
            format: NSLocalizedString("Step %d of 3", comment: "Onboarding progress"),
            step + 1
        )))
    }

    // MARK: Actions

    private func advance() {
        withAnimation(PeekMotion.reduceMotion ? nil : .easeOut(duration: 0.2)) {
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
