import SwiftUI
import EventKit
import Foundation

struct MenuBarView: View {
    // Key codes
    private static let kEscapeKeyCode: UInt16 = 53
    private static let kDownArrowKeyCode: UInt16 = 125
    private static let kUpArrowKeyCode: UInt16 = 126

    @ObservedObject var calendarManager: CalendarManager
    @State private var showingPreferences = false
    @State private var selectedEventIndex: Int = 0
    @State private var eventMonitor: Any?
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false
    var closePopover: (() -> Void)?
    var refreshStatusBar: ((EKEvent?) -> Void)? = nil
    private let refreshFeedbackMinDuration: TimeInterval = 0.4
    private let refreshConfirmationDuration: TimeInterval = 0.9

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMMM d")
        return formatter
    }()

    private var preferredColorScheme: ColorScheme? {
        switch calendarManager.appearanceMode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var refreshHelpText: String {
        if !calendarManager.hasCalendarAccess {
            return NSLocalizedString("No Calendar Access", comment: "Refresh help text when calendar access is missing")
        }
        if isRefreshing {
            return NSLocalizedString("Refreshing…", comment: "Refresh help text while refreshing")
        }
        if showRefreshConfirmation {
            return NSLocalizedString("Refreshed", comment: "Refresh help text after refresh completes")
        }
        return NSLocalizedString("Refresh events", comment: "Help text: Refresh events")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(PeekColor.innerDivider)

            if calendarManager.upcomingEvents.isEmpty {
                emptyState
            } else {
                eventList
            }

            Divider().overlay(PeekColor.innerDivider)
            footer
        }
        .frame(width: 350)
        .background(PeekColor.surface)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(calendarManager: calendarManager)
        }
        .onAppear {
            if let existingMonitor = eventMonitor {
                NSEvent.removeMonitor(existingMonitor)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                self.handleKeyPress(event)
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onChange(of: calendarManager.upcomingEvents.count) { newCount in
            if selectedEventIndex >= newCount {
                selectedEventIndex = max(0, newCount - 1)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Peek")
                    .font(PeekFont.title)
                    .foregroundColor(PeekColor.ink)
                Text(Self.headerDateFormatter.string(from: Date()))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
            }

            Spacer()

            if !calendarManager.upcomingEvents.isEmpty {
                CountPill(count: calendarManager.upcomingEvents.count)
                    .accessibilityLabel(Text(String(
                        format: NSLocalizedString("%d upcoming events", comment: "Accessibility: event count"),
                        calendarManager.upcomingEvents.count
                    )))
            }
        }
        .padding(.horizontal, PeekSpacing.lg)
        .padding(.vertical, 13)
    }

    // MARK: - Event list

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(calendarManager.upcomingEvents.enumerated()), id: \.element.eventIdentifier) { index, event in
                    EventRow(
                        event: event,
                        isHero: index == 0,
                        isSelected: index == selectedEventIndex
                    )
                    .contextMenu {
                        EventContextMenu(event: event)
                    }
                }
            }
            .padding(PeekSpacing.sm)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Empty / no-access states

    private var emptyState: some View {
        let hasAccess = calendarManager.hasCalendarAccess
        return VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hasAccess ? PeekColor.blueTint : PeekColor.urgentWash)
                    .frame(width: 52, height: 52)
                Image(systemName: hasAccess ? "calendar" : "calendar.badge.exclamationmark")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(hasAccess ? PeekColor.accent : PeekColor.urgent)
            }

            Text(hasAccess
                 ? NSLocalizedString("You're all clear", comment: "Empty event state title")
                 : NSLocalizedString("Calendar access needed", comment: "Missing calendar permission title"))
                .font(PeekFont.title)
                .foregroundColor(PeekColor.ink)

            Text(hasAccess
                 ? NSLocalizedString(
                    "No upcoming events. Peek will light up the moment something lands on your calendar.",
                    comment: "Empty event state explanation")
                 : NSLocalizedString(
                    "Peek needs permission to read your events. Grant access in System Settings to get started.",
                    comment: "Calendar permission recovery guidance"))
                .font(PeekFont.bodyMeta)
                .foregroundColor(PeekColor.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)

            if !hasAccess {
                Button(NSLocalizedString("Open System Settings", comment: "Open settings button")) {
                    openCalendarPrivacySettings()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            FooterButton(systemName: "gearshape", help: NSLocalizedString("Preferences", comment: "Help text: Preferences")) {
                showingPreferences = true
            }

            FooterButton(
                systemName: showRefreshConfirmation ? "checkmark" : "arrow.clockwise",
                help: refreshHelpText,
                tint: showRefreshConfirmation ? PeekColor.calm : nil,
                isBusy: isRefreshing,
                disabled: isRefreshing || !calendarManager.hasCalendarAccess
            ) {
                performRefresh()
            }

            FooterButton(systemName: "calendar", help: NSLocalizedString("Open Calendar", comment: "Help text: Open Calendar")) {
                openCalendarApp()
            }

            Spacer()

            FooterButton(systemName: "power", help: NSLocalizedString("Quit Peek", comment: "Help text: Quit Peek")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, PeekSpacing.lg)
        .padding(.vertical, 9)
    }

    // MARK: - Key handling

    private func handleKeyPress(_ event: NSEvent) -> NSEvent? {
        if showingPreferences || NSApp.keyWindow?.attachedSheet != nil {
            return event
        }

        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
           textView.isFieldEditor || textView.isEditable {
            return event
        }

        if event.keyCode == Self.kEscapeKeyCode {
            closePopover?()
            return nil
        }

        if !calendarManager.upcomingEvents.isEmpty {
            if event.keyCode == Self.kDownArrowKeyCode {
                selectedEventIndex = min(selectedEventIndex + 1, calendarManager.upcomingEvents.count - 1)
                return nil
            } else if event.keyCode == Self.kUpArrowKeyCode {
                selectedEventIndex = max(selectedEventIndex - 1, 0)
                return nil
            }
        }

        return event
    }

    // MARK: - Actions

    private func performRefresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        showRefreshConfirmation = false
        let startTime = Date()

        calendarManager.fetchNextEvent { event in
            refreshStatusBar?(event)

            let elapsed = Date().timeIntervalSince(startTime)
            let delay = max(0, refreshFeedbackMinDuration - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isRefreshing = false
                showRefreshConfirmation = true

                DispatchQueue.main.asyncAfter(deadline: .now() + refreshConfirmationDuration) {
                    showRefreshConfirmation = false
                }
            }
        }
    }

    private func openCalendarApp() {
        let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Meeting provider helpers

enum MeetingProvider {
    static func label(for url: URL) -> String {
        guard let host = url.host?.lowercased() else {
            return NSLocalizedString("Meeting", comment: "Generic meeting provider")
        }
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("teams.microsoft") { return "Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("gotomeeting") { return "GoToMeeting" }
        if host.contains("whereby") { return "Whereby" }
        if host.contains("discord") { return "Discord" }
        return NSLocalizedString("Meeting", comment: "Generic meeting provider")
    }
}

// MARK: - Footer button

private struct FooterButton: View {
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
                        .font(.system(size: 15))
                        .foregroundColor(tint ?? (hovering && !disabled ? PeekColor.accent : PeekColor.secondaryText))
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

// MARK: - Event row

struct EventRow: View {
    let event: EKEvent
    var isHero: Bool = false
    var isSelected: Bool = false

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }

    private var minutesUntil: Int {
        Int(event.startDate.timeIntervalSince(Date())) / 60
    }

    private var urgency: MeetingUrgency {
        MeetingUrgency.from(minutesUntil: minutesUntil)
    }

    private var isUpcoming: Bool { event.startDate > Date() }

    private var accentColor: Color {
        switch urgency {
        case .critical: return PeekColor.critical
        case .urgent: return PeekColor.urgent
        case .normal: return PeekColor.accent
        }
    }

    private var washColor: Color {
        switch urgency {
        case .critical: return PeekColor.criticalWash
        case .urgent: return PeekColor.urgentWash
        case .normal: return PeekColor.nextWash
        }
    }

    private var badgeKind: PeekBadge.Kind {
        if event.isAllDay { return .allDay }
        if !isUpcoming { return .now }
        switch urgency {
        case .critical: return .now
        case .urgent: return .soon
        case .normal: return .next
        }
    }

    var body: some View {
        Group {
            if isHero {
                heroRow
            } else {
                normalRow
            }
        }
        .peekFocusRing(isSelected)
    }

    // MARK: Hero (NEXT) row

    private var heroRow: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 6) {
                    Text(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))
                        .font(PeekFont.nextTitle)
                        .foregroundColor(PeekColor.ink)
                        .lineLimit(2)
                    PeekBadge(kind: badgeKind)
                    Spacer(minLength: 0)
                }

                metaRow(accented: true)
                detailRow

                if let meetingURL {
                    joinButton(url: meetingURL)
                }
            }
            .padding(.leading, 11)
            .padding(.trailing, 12)
            .padding(.vertical, 11)
        }
        .background(washColor)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous))
        .modifier(CriticalPulse(active: urgency == .critical && !event.isAllDay))
    }

    // MARK: Normal row

    private var normalRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))
                    .font(Font.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? PeekColor.accent : PeekColor.ink)
                    .lineLimit(2)
                if event.isAllDay { PeekBadge(kind: .allDay) }
                Spacer(minLength: 0)
            }
            metaRow(accented: false)
            detailRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? PeekColor.rowHoverWash : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous))
    }

    // MARK: Shared pieces

    private func metaRow(accented: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: event.isAllDay ? "calendar" : "clock")
                .font(.system(size: 12))
                .foregroundColor(accented ? accentColor : PeekColor.tertiaryText)
                .frame(width: 14)

            if event.isAllDay {
                Text(EventTimeFormatter.compactDateText(for: event.startDate))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            } else {
                Text(EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            }

            Spacer(minLength: 6)

            if isUpcoming && !event.isAllDay {
                Text(EventTimeFormatter.countdownText(target: event.startDate))
                    .font(PeekFont.captionStrong)
                    .foregroundColor(accented ? accentColor : PeekColor.tertiaryText)
            }
        }
    }

    private var detailRow: some View {
        HStack(spacing: 10) {
            if let meetingURL {
                HStack(spacing: 4) {
                    Image(systemName: "video")
                        .font(.system(size: 11))
                        .foregroundColor(PeekColor.secondaryText)
                    Text(MeetingProvider.label(for: meetingURL))
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            if let location = event.location, !location.isEmpty, meetingURL == nil {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 11))
                        .foregroundColor(PeekColor.secondaryText)
                    Text(location)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            if let calendar = event.calendar {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(calendar.color))
                        .frame(width: 8, height: 8)
                    Text(calendar.title)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func joinButton(url: URL) -> some View {
        Button {
            if MeetingURLDetector.isURLSafe(url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "video.fill")
                    .font(.system(size: 11))
                Text(joinTitle(url: url))
            }
        }
        .buttonStyle(JoinButtonStyle(tint: accentColor))
        .padding(.top, 2)
        .accessibilityLabel(Text(String(
            format: NSLocalizedString("Join %@ on %@", comment: "Accessibility: join event on provider"),
            event.title ?? NSLocalizedString("meeting", comment: "generic meeting"),
            MeetingProvider.label(for: url)
        )))
    }

    private func joinTitle(url: URL) -> String {
        if urgency == .normal {
            return String(format: NSLocalizedString("Join %@", comment: "Join with provider"), MeetingProvider.label(for: url))
        }
        return NSLocalizedString("Join now", comment: "Join urgent")
    }
}

/// Join button style that adopts the row's urgency tint.
private struct JoinButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.system(size: 12.5, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(tint.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.join, style: .continuous))
    }
}

/// Static or pulsing outer ring for the critical hero row (honors Reduce Motion).
private struct CriticalPulse: ViewModifier {
    let active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous)
                .strokeBorder(PeekColor.critical.opacity(active ? (pulse ? 0.05 : 0.35) : 0), lineWidth: 3)
                .onAppear {
                    guard active, !PeekMotion.reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        )
    }
}

// MARK: - Event Context Menu

struct EventContextMenu: View {
    let event: EKEvent

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }

    var body: some View {
        if let meetingURL = meetingURL {
            Button(NSLocalizedString("Copy Meeting Link", comment: "Context menu: copy meeting link")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(meetingURL.absoluteString, forType: .string)
            }
            Divider()
        }

        Button(NSLocalizedString("Open in Calendar", comment: "Context menu: open in calendar")) {
            let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
            NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
        }

        if let location = event.location, !location.isEmpty {
            Button(NSLocalizedString("Copy Location", comment: "Context menu: copy location")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(location, forType: .string)
            }
        }

        Button(NSLocalizedString("Copy Event Title", comment: "Context menu: copy title")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(event.title ?? "", forType: .string)
        }
    }
}
