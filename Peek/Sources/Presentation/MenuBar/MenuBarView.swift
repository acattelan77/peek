import SwiftUI
import AppKit
import EventKit
import Foundation

/// The popover (Peek 2.0 layout): month title header with ‹ Today › controls, the
/// compact month grid, the next-meeting card, compact rows grouped by day, and the
/// icon footer. Choosing a meeting opens its page in place ("You're about to meet").
struct MenuBarView: View {
    // Key codes
    private static let kEscapeKeyCode: UInt16 = 53
    private static let kReturnKeyCode: UInt16 = 36
    private static let kDownArrowKeyCode: UInt16 = 125
    private static let kUpArrowKeyCode: UInt16 = 126

    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var discreetMode: DiscreetModeController = .shared
    @State private var showingPreferences = false
    @State private var selectedEventIndex: Int = 0
    /// The meeting whose page is open, if any.
    @State private var detailEvent: EKEvent?
    @State private var eventMonitor: Any?
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false
    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?
    @State private var eventDays: Set<Date> = []
    @State private var dayEvents: [EKEvent] = []
    /// Everything visible today, so finished meetings can be shown dimmed and counted.
    @State private var todayEvents: [EKEvent] = []
    var closePopover: (() -> Void)?
    var refreshStatusBar: ((EKEvent?) -> Void)? = nil
    private let refreshFeedbackMinDuration: TimeInterval = 0.4
    private let refreshConfirmationDuration: TimeInterval = 0.9

    private static let dayAgendaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter
    }()

    private static let headerDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEE d")
        return formatter
    }()

    private var monthGrid: MonthGrid { MonthGrid.make(containing: displayedMonth) }

    private var showsMonth: Bool {
        calendarManager.showMonthCalendar && calendarManager.hasCalendarAccess
    }

    /// A chosen day other than today replaces the upcoming list with that day's agenda.
    private var chosenOtherDay: Date? {
        guard let selectedDay, !Calendar.current.isDateInToday(selectedDay) else { return nil }
        return selectedDay
    }

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

    /// Meetings today that already ended and are not in the upcoming list.
    private var finishedToday: [EKEvent] {
        let upcomingIDs = Set(calendarManager.upcomingEvents.compactMap(\.eventIdentifier))
        let now = Date()
        return todayEvents
            .filter { !$0.isAllDay && $0.endDate <= now && !upcomingIDs.contains($0.eventIdentifier ?? "") }
            .sorted { $0.startDate < $1.startDate }
    }

    private var page: PopoverPage {
        PopoverPagePolicy.page(showingSettings: showingPreferences, hasMeeting: detailEvent != nil)
    }

    var body: some View {
        Group {
            if page == .settings {
                // PEEK-285: settings replace the calendar as the popover's only page.
                PreferencesView(calendarManager: calendarManager, onDone: finishSettings)
            } else {
                calendarPage
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // The popover always opens on the calendar.
            showingPreferences = false
            reloadEventDays()
            reloadTodayEvents()
            if let existingMonitor = eventMonitor {
                NSEvent.removeMonitor(existingMonitor)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                self.handleKeyPress(event)
            }
        }
        .onDisappear {
            if showingPreferences {
                // Closed with a click outside, Escape or the menu-bar item: keep the changes.
                calendarManager.savePreferences()
                showingPreferences = false
            }
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private var calendarPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let detailEvent {
                MeetingPage(
                    event: detailEvent,
                    worldClockZones: calendarManager.worldClockZones,
                    calendarManager: calendarManager,
                    onBack: closeDetail
                )
            } else {
                header

                if !calendarManager.worldClockZones.isEmpty {
                    WorldClockStrip(zones: calendarManager.worldClockZones)
                }

                if showsMonth {
                    MonthCalendarView(
                        grid: monthGrid,
                        eventDays: eventDays,
                        selectedDay: selectedDay,
                        onSelectDay: selectDay
                    )
                }

                Divider().overlay(PeekColor.hairline)

                if chosenOtherDay == nil, calendarManager.showDayPriorities, !discreetMode.isActive {
                    DayPrioritiesBlock()
                }

                if let day = chosenOtherDay {
                    dayAgenda(for: day)
                } else if calendarManager.upcomingEvents.isEmpty && finishedToday.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }

            Divider().overlay(PeekColor.hairline)
            footer
        }
        .frame(width: PeekMetrics.popoverWidth)
        .background(PeekColor.surface)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: calendarManager.upcomingEvents.count) { newCount in
            if selectedEventIndex >= newCount {
                selectedEventIndex = max(0, newCount - 1)
            }
        }
        .onChange(of: calendarManager.upcomingEvents.map(\.eventIdentifier)) { _ in
            reloadEventDays()
            reloadTodayEvents()
            if let day = chosenOtherDay {
                reloadDayEvents(for: day)
            }
        }
    }

    // MARK: - Header

    private var headerTitle: String {
        if showsMonth {
            return MonthCalendarView.monthTitle(for: displayedMonth)
        }
        return Self.dayAgendaFormatter.string(from: Date()).capitalized
    }

    private var meetingsTodayText: String {
        let count = todayEvents.filter { !$0.isAllDay }.count
        switch count {
        case 0: return NSLocalizedString("No meetings today", comment: "Popover header subtitle: no meetings today")
        case 1: return NSLocalizedString("1 meeting today", comment: "Popover header subtitle: one meeting today")
        default:
            return String(format: NSLocalizedString("%d meetings today", comment: "Popover header subtitle: meetings today"), count)
        }
    }

    private var headerSubtitle: String {
        guard calendarManager.hasCalendarAccess else {
            return Self.headerDayFormatter.string(from: Date()).capitalized
        }
        if showsMonth {
            return String(
                format: NSLocalizedString("%@ · %@", comment: "Two parts joined with a middle dot"),
                Self.headerDayFormatter.string(from: Date()).capitalized,
                meetingsTodayText
            )
        }
        return meetingsTodayText
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PeekMetrics.headerGap) {
            VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
                Text(headerTitle)
                    .font(PeekFont.title)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(headerSubtitle)
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: PeekSpacing.sm)

            if showsMonth {
                HStack(spacing: PeekMetrics.headerNavGap) {
                    navButton(systemName: "chevron.left", help: NSLocalizedString("Previous month", comment: "Month view: previous month")) {
                        shiftMonth(by: -1)
                    }
                    Button(NSLocalizedString("Today", comment: "Month view: jump to today"), action: showToday)
                        .buttonStyle(HeaderNavButtonStyle())
                    navButton(systemName: "chevron.right", help: NSLocalizedString("Next month", comment: "Month view: next month")) {
                        shiftMonth(by: 1)
                    }
                }
            }
        }
        .padding(PeekMetrics.headerInsets)
    }

    private func navButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(PeekIcon.nav)
        }
        .buttonStyle(HeaderNavButtonStyle(square: true))
        .help(help)
        .accessibilityLabel(Text(help))
    }

    // MARK: - Event list

    private struct DayRow: Identifiable {
        let event: EKEvent
        /// Keyboard index in `upcomingEvents`; nil for finished meetings.
        let index: Int?
        var id: String { event.eventIdentifier ?? "\(event.startDate.timeIntervalSince1970)-\(event.title ?? "")" }
    }

    private struct DaySection: Identifiable {
        let day: Date
        let rows: [DayRow]
        var id: Date { day }
    }

    /// Finished meetings of today and the upcoming events after the next one,
    /// grouped by day. `index` is the keyboard index in `upcomingEvents`.
    private var daySections: [DaySection] {
        var rows: [DayRow] = finishedToday.map { DayRow(event: $0, index: nil) }
        for (index, event) in calendarManager.upcomingEvents.enumerated() where index > 0 {
            rows.append(DayRow(event: event, index: index))
        }
        let calendar = Calendar.current
        var order: [Date] = []
        var grouped: [Date: [DayRow]] = [:]
        for row in rows {
            let day = calendar.startOfDay(for: max(row.event.startDate, calendar.startOfDay(for: Date())))
            if grouped[day] == nil { order.append(day) }
            grouped[day, default: []].append(row)
        }
        return order.sorted().map { DaySection(day: $0, rows: grouped[$0] ?? []) }
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return NSLocalizedString("Today", comment: "Popover list section: today")
        }
        if calendar.isDateInTomorrow(day) {
            return NSLocalizedString("Tomorrow", comment: "Popover list section: tomorrow")
        }
        return Self.dayAgendaFormatter.string(from: day)
    }

    private var eventList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PeekMetrics.rowGap) {
                if let next = calendarManager.upcomingEvents.first {
                    NextMeetingCard(
                        event: next,
                        isSelected: selectedEventIndex == 0,
                        isMuted: calendarManager.overrideAction(for: next) == .mute,
                        onOpen: { openDetail(next) }
                    )
                    .contextMenu { EventContextMenu(event: next, calendarManager: calendarManager) }
                }

                ForEach(daySections) { section in
                    PeekSectionLabel(text: sectionTitle(for: section.day))
                    ForEach(section.rows) { row in
                        CompactEventRow(
                            event: row.event,
                            isSelected: row.index != nil && row.index == selectedEventIndex,
                            isMuted: calendarManager.overrideAction(for: row.event) == .mute,
                            onOpen: { openDetail(row.event) }
                        )
                        .contextMenu { EventContextMenu(event: row.event, calendarManager: calendarManager) }
                    }
                }
            }
            .padding(PeekMetrics.listInsets)
        }
        .frame(maxHeight: PeekMetrics.popoverListMaxHeight)
        .background(PeekColor.canvas)
    }

    // MARK: - Month view (PEEK-201)

    private func dayAgenda(for day: Date) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PeekMetrics.rowGap) {
                PeekSectionLabel(text: sectionTitle(for: day))

                if dayEvents.isEmpty {
                    Text(NSLocalizedString("No events on this day.", comment: "Month view: empty day"))
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.secondaryText)
                        .padding(PeekSpacing.sm)
                } else {
                    ForEach(dayEvents, id: \.eventIdentifier) { event in
                        CompactEventRow(
                            event: event,
                            isMuted: calendarManager.overrideAction(for: event) == .mute,
                            onOpen: { openDetail(event) }
                        )
                            .contextMenu { EventContextMenu(event: event, calendarManager: calendarManager) }
                    }
                }
            }
            .padding(PeekMetrics.listInsets)
        }
        .frame(maxHeight: PeekMetrics.popoverListMaxHeight)
        .background(PeekColor.canvas)
    }

    private func selectDay(_ day: Date) {
        if Calendar.current.isDateInToday(day) || selectedDay == day {
            selectedDay = nil
            dayEvents = []
            return
        }
        selectedDay = day
        dayEvents = []
        if !Calendar.current.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = day
            reloadEventDays()
        }
        reloadDayEvents(for: day)
    }

    private func shiftMonth(by months: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: months, to: displayedMonth) ?? displayedMonth
        reloadEventDays()
    }

    private func showToday() {
        displayedMonth = Date()
        selectedDay = nil
        dayEvents = []
        reloadEventDays()
    }

    private func reloadEventDays() {
        guard calendarManager.showMonthCalendar else { return }
        let grid = monthGrid
        calendarManager.fetchEventDays(in: grid) { days in
            if grid.monthStart == monthGrid.monthStart {
                eventDays = days
            }
        }
    }

    private func reloadDayEvents(for day: Date) {
        calendarManager.fetchEvents(on: day) { events in
            if selectedDay == day {
                dayEvents = events
            }
        }
    }

    private func reloadTodayEvents() {
        calendarManager.fetchEvents(on: Date()) { events in
            todayEvents = events
        }
    }

    // MARK: - Empty / no-access states

    private var emptyState: some View {
        let hasAccess = calendarManager.hasCalendarAccess
        return VStack(spacing: PeekSpacing.md) {
            PeekIconTile(
                systemName: hasAccess ? "calendar" : "calendar.badge.exclamationmark",
                tone: hasAccess ? .accent : .urgent
            )

            Text(hasAccess
                 ? NSLocalizedString("You're all clear", comment: "Empty event state title")
                 : NSLocalizedString("Calendar access needed", comment: "Missing calendar permission title"))
                .font(PeekFont.title)
                .foregroundColor(PeekColor.ink)
                .multilineTextAlignment(.center)

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
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: PeekMetrics.emptyTextMaxWidth)

            if !hasAccess {
                Button(NSLocalizedString("Open System Settings", comment: "Open settings button")) {
                    openCalendarPrivacySettings()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, PeekSpacing.xxs)
            }
        }
        .padding(PeekSpacing.huge)
        .frame(maxWidth: .infinity)
        .background(PeekColor.canvas)
    }

    // MARK: - Footer

    /// Icon footer kept from Peek 1.x by owner decision (2026-11-24): the mockup's
    /// text links are not used. See docs/DESIGN_SYSTEM.md, "Popover footer".
    private var footer: some View {
        HStack(spacing: PeekSpacing.lg) {
            PeekToolbarButton(systemName: "gearshape", help: NSLocalizedString("Preferences", comment: "Help text: Preferences")) {
                showingPreferences = true
            }

            PeekToolbarButton(
                systemName: showRefreshConfirmation ? "checkmark" : "arrow.clockwise",
                help: refreshHelpText,
                tint: showRefreshConfirmation ? PeekColor.calmText : nil,
                isBusy: isRefreshing,
                disabled: isRefreshing || !calendarManager.hasCalendarAccess
            ) {
                performRefresh()
            }

            PeekToolbarButton(systemName: "calendar", help: NSLocalizedString("Open Calendar", comment: "Help text: Open Calendar")) {
                openCalendarApp()
            }

            // PEEK-274: discreet mode for screen sharing. Accent while on.
            PeekToolbarButton(
                systemName: discreetMode.isActive ? "eye.slash.fill" : "eye.slash",
                help: discreetMode.isActive
                    ? NSLocalizedString("Discreet mode is on: show details", comment: "Help text: turn discreet mode off")
                    : NSLocalizedString("Discreet mode: hide briefs and details", comment: "Help text: turn discreet mode on"),
                tint: discreetMode.isActive ? PeekColor.accentText : nil
            ) {
                discreetMode.toggle()
            }

            Spacer()

            PeekToolbarButton(systemName: "power", help: NSLocalizedString("Quit Peek", comment: "Help text: Quit Peek")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, PeekSpacing.lg)
        .padding(.vertical, PeekMetrics.footerVerticalPadding)
    }

    // MARK: - Key handling

    private func handleKeyPress(_ event: NSEvent) -> NSEvent? {
        if !PopoverPagePolicy.calendarHandlesKeys(on: page) || NSApp.keyWindow?.attachedSheet != nil {
            return event
        }

        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
           textView.isFieldEditor || textView.isEditable {
            return event
        }

        if event.keyCode == Self.kEscapeKeyCode {
            if detailEvent != nil {
                closeDetail()
            } else {
                closePopover?()
            }
            return nil
        }

        if detailEvent == nil, !calendarManager.upcomingEvents.isEmpty {
            if event.keyCode == Self.kDownArrowKeyCode {
                selectedEventIndex = min(selectedEventIndex + 1, calendarManager.upcomingEvents.count - 1)
                return nil
            } else if event.keyCode == Self.kUpArrowKeyCode {
                selectedEventIndex = max(selectedEventIndex - 1, 0)
                return nil
            } else if event.keyCode == Self.kReturnKeyCode,
                      selectedEventIndex < calendarManager.upcomingEvents.count {
                openDetail(calendarManager.upcomingEvents[selectedEventIndex])
                return nil
            }
        }

        return event
    }

    // MARK: - Actions

    private func openDetail(_ event: EKEvent) {
        detailEvent = event
    }

    private func closeDetail() {
        detailEvent = nil
    }

    /// Done on the settings page: the changes are saved, then the popover closes.
    private func finishSettings() {
        showingPreferences = false
        closePopover?()
    }

    private func performRefresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        showRefreshConfirmation = false
        let startTime = Date()

        calendarManager.fetchNextEvent { event in
            refreshStatusBar?(event)
            reloadTodayEvents()

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

// MARK: - Shared event presentation

/// Text and tone rules shared by the next-meeting card, compact rows and the meeting page.
enum EventPresentation {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter
    }()

    static func title(_ event: EKEvent) -> String {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events") : title
    }

    static func startTime(_ event: EKEvent) -> String {
        timeFormatter.string(from: event.startDate)
    }

    /// "15:00–16:00", or "All day".
    static func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return allDayText }
        return String(
            format: NSLocalizedString("%@–%@", comment: "Compact time range: start–end"),
            timeFormatter.string(from: event.startDate),
            timeFormatter.string(from: event.endDate)
        )
    }

    static var allDayText: String {
        NSLocalizedString("All day", comment: "Time column for an all-day event")
    }

    /// Discreet mode (PEEK-274): the provider or the duration, nothing else.
    static func discreetMeta(_ event: EKEvent) -> String {
        DiscreetModePolicy.meta(
            providerLabel: MeetingURLDetector.extract(from: event).map { MeetingProvider.label(for: $0) },
            duration: duration(event)
        )
    }

    static func duration(_ event: EKEvent) -> String? {
        guard !event.isAllDay else { return nil }
        return durationFormatter.string(from: event.startDate, to: event.endDate)
    }

    static func isFinished(_ event: EKEvent, now: Date = Date()) -> Bool {
        event.endDate <= now
    }

    static func urgency(_ event: EKEvent, now: Date = Date()) -> MeetingUrgency {
        if event.isAllDay || event.endDate <= now { return .normal }
        return MeetingUrgency.from(minutesUntil: Int(event.startDate.timeIntervalSince(now)) / 60)
    }

    /// Number of other people on the invitation (rooms and the user excluded).
    static func otherPeopleCount(_ event: EKEvent) -> Int {
        (event.attendees ?? []).filter {
            !$0.isCurrentUser && ($0.participantType == .person || $0.participantType == .unknown)
        }.count
    }

    /// "Google Meet · 30 min", "Teams · 6 participants", "Finished · Meet", the location,
    /// or the calendar name, in that order of preference.
    static func meta(_ event: EKEvent, now: Date = Date()) -> String {
        var parts: [String] = []
        if isFinished(event, now: now) {
            parts.append(NSLocalizedString("Finished", comment: "Compact row: the meeting has ended"))
        }
        if let url = MeetingURLDetector.extract(from: event) {
            parts.append(MeetingProvider.label(for: url))
        } else if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            parts.append(location)
        }
        if !isFinished(event, now: now) {
            let people = otherPeopleCount(event)
            if people > 1 {
                parts.append(String(format: NSLocalizedString("%d participants", comment: "Compact row: attendee count"), people + 1))
            } else if let duration = duration(event) {
                parts.append(duration)
            }
        }
        if parts.isEmpty, let calendar = event.calendar?.title {
            parts.append(calendar)
        }
        return parts.joined(separator: " · ")
    }

    /// "NEXT · IN 24 MIN", "SOON · IN 6 MIN", "NOW · 18 MIN LEFT", "ALL DAY".
    static func eyebrow(_ event: EKEvent, now: Date = Date()) -> String {
        if event.isAllDay { return PeekBadge.Kind.allDay.text }
        let locale = Locale.current
        if event.startDate <= now {
            let left = max(1, Int(event.endDate.timeIntervalSince(now)) / 60)
            return joined(
                PeekBadge.Kind.now.text,
                String(format: NSLocalizedString("%d min left", comment: "Eyebrow: minutes left in an ongoing meeting"), left)
                    .uppercased(with: locale)
            )
        }
        let kind: PeekBadge.Kind
        switch urgency(event, now: now) {
        case .critical: kind = .now
        case .urgent: kind = .soon
        case .normal: kind = .next
        }
        return joined(kind.text, EventTimeFormatter.countdownText(target: event.startDate, now: now).uppercased(with: locale))
    }

    static func joined(_ first: String, _ second: String) -> String {
        String(format: NSLocalizedString("%@ · %@", comment: "Two parts joined with a middle dot"), first, second)
    }

    static func joinTitle(url: URL, urgency: MeetingUrgency) -> String {
        if urgency == .normal {
            return String(format: NSLocalizedString("Join %@", comment: "Join with provider"), MeetingProvider.label(for: url))
        }
        return NSLocalizedString("Join now", comment: "Join urgent")
    }

    /// The headline with the lead person's short name set in semibold ink.
    static func headlineText(_ headline: String, emphasizing name: String?) -> Text {
        guard let name, !name.isEmpty, let range = headline.range(of: name) else {
            return Text(headline)
        }
        return Text(headline[..<range.lowerBound])
            + Text(headline[range]).fontWeight(.semibold).foregroundColor(PeekColor.ink)
            + Text(headline[range.upperBound...])
    }

    static func sourceLabel(for source: BriefSource) -> String {
        switch source {
        case .contextFolder:
            return NSLocalizedString("From your context folder", comment: "Brief source label: context file")
        case .onDevice:
            return NSLocalizedString("Written on this Mac", comment: "Brief source label: on-device model")
        case .cloud:
            return NSLocalizedString("Written by Claude", comment: "Brief source label: cloud model")
        }
    }
}

// MARK: - Join button

struct EventJoinButton: View {
    let event: EKEvent
    let url: URL
    var fullWidth: Bool = false

    private var urgency: MeetingUrgency { EventPresentation.urgency(event) }

    var body: some View {
        Button {
            MeetingLinkOpener.open(url)
        } label: {
            HStack(spacing: PeekSpacing.tightGap) {
                Image(systemName: "video.fill")
                    .font(PeekIcon.detail)
                    .accessibilityHidden(true)
                Text(EventPresentation.joinTitle(url: url, urgency: urgency))
                    .lineLimit(1)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: fullWidth ? PeekMetrics.meetingJoinButtonHeight : PeekMetrics.joinButtonHeight)
        }
        .buttonStyle(JoinButtonStyle(tone: PeekTone(urgency), compact: true))
        .fixedSize(horizontal: !fullWidth, vertical: true)
        .accessibilityLabel(Text(String(
            format: NSLocalizedString("Join %@ on %@", comment: "Accessibility: join event on provider"),
            EventPresentation.title(event),
            MeetingProvider.label(for: url)
        )))
    }
}

// MARK: - Next meeting card

/// The compact next-meeting card: accent rail, "NEXT · IN 24 MIN" eyebrow with the time
/// range at the top right, title with who you are meeting, Join on the right, and the
/// "Brief ready" line. Tapping it opens the meeting page.
struct NextMeetingCard: View {
    let event: EKEvent
    var isSelected: Bool = false
    /// Alerts muted for this event (PEEK-273): a bell-slash beside the time.
    var isMuted: Bool = false
    let onOpen: () -> Void
    @ObservedObject var briefService: MeetingBriefService = .shared
    @ObservedObject var discreetMode: DiscreetModeController = .shared

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }
    private var urgency: MeetingUrgency { EventPresentation.urgency(event) }
    private var tone: PeekTone { PeekTone(urgency) }
    private var context: MeetingContext {
        event.isAllDay || discreetMode.isActive ? .empty : MeetingContextProvider.context(for: event)
    }

    var body: some View {
        let context = self.context
        VStack(alignment: .leading, spacing: PeekMetrics.nextCardGap) {
            HStack(spacing: PeekSpacing.sm) {
                Text(EventPresentation.eyebrow(event))
                    .font(PeekFont.label)
                    .tracking(PeekFont.labelTracking)
                    .foregroundColor(tone.text)
                    .lineLimit(1)
                Spacer(minLength: PeekSpacing.sm)
                if isMuted {
                    MutedEventIcon()
                }
                Text(EventPresentation.timeRange(event))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: PeekMetrics.headerGap) {
                VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
                    Text(EventPresentation.title(event))
                        .font(PeekFont.headline)
                        .foregroundColor(PeekColor.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    subtitle(context)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let meetingURL {
                    EventJoinButton(event: event, url: meetingURL)
                }
            }

            briefLine
        }
        .padding(PeekMetrics.nextCardInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.wash)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: PeekRadius.rail, style: .continuous)
                .fill(tone.rail)
                .frame(width: PeekMetrics.railWidth)
                .padding(.vertical, PeekMetrics.nextCardRailInset)
                .accessibilityHidden(true)
        }
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous)
                .strokeBorder(tone.border, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
        .peekCriticalPulse(urgency == .critical, cornerRadius: PeekRadius.card)
        .peekFocusRing(isSelected, cornerRadius: PeekRadius.card)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(NSLocalizedString("Show meeting", comment: "Accessibility: open the meeting page")), onOpen)
    }

    @ViewBuilder
    private func subtitle(_ context: MeetingContext) -> some View {
        if discreetMode.isActive {
            Text(EventPresentation.discreetMeta(event))
        } else if let headline = context.headline {
            EventPresentation.headlineText(headline, emphasizing: context.people.first?.shortName)
        } else {
            Text(EventPresentation.meta(event))
        }
    }

    @ViewBuilder
    private var briefLine: some View {
        if !event.isAllDay, !discreetMode.isActive {
            if let brief = briefService.brief(for: event) {
                Button(action: onOpen) {
                    HStack(spacing: PeekSpacing.iconGap) {
                        Image(systemName: "doc.text")
                            .font(PeekIcon.detail)
                            .accessibilityHidden(true)
                        Text(brief.points.count == 1
                             ? NSLocalizedString("Brief ready: 1 point to prepare", comment: "Next card: brief with one point")
                             : String(format: NSLocalizedString("Brief ready: %d points to prepare", comment: "Next card: brief with several points"), brief.points.count))
                            .font(PeekFont.bodyMetaMedium)
                    }
                    .foregroundColor(tone.text)
                }
                .buttonStyle(.plain)
            } else if briefService.isPreparing(event) {
                HStack(spacing: PeekSpacing.iconGap) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(NSLocalizedString("Preparing brief…", comment: "Brief is being generated"))
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                }
            }
        }
    }
}

// MARK: - Compact event row

/// Time on the left, calendar dot, title and one line of metadata. Finished meetings
/// are dimmed.
struct CompactEventRow: View {
    let event: EKEvent
    var isSelected: Bool = false
    /// Alerts muted for this event (PEEK-273): a bell-slash before the badge.
    var isMuted: Bool = false
    let onOpen: () -> Void
    @ObservedObject var discreetMode: DiscreetModeController = .shared

    var body: some View {
        let finished = EventPresentation.isFinished(event)
        HStack(alignment: .center, spacing: PeekMetrics.compactRowGap) {
            Text(event.isAllDay ? EventPresentation.allDayText : EventPresentation.startTime(event))
                .font(event.isAllDay ? PeekFont.caption : PeekFont.rowTime)
                .foregroundColor(PeekColor.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: PeekMetrics.rowTimeWidth, alignment: .leading)

            Circle()
                .fill(event.calendar.map { Color($0.color) } ?? PeekColor.accentRail)
                .frame(width: PeekMetrics.calendarDot, height: PeekMetrics.calendarDot)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PeekSpacing.hairline) {
                Text(EventPresentation.title(event))
                    .font(PeekFont.rowTitle)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(1)
                Text(discreetMode.isActive ? EventPresentation.discreetMeta(event) : EventPresentation.meta(event))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isMuted {
                MutedEventIcon()
            }

            switch EventPresentation.urgency(event) {
            case .critical: PeekBadge(kind: .now)
            case .urgent: PeekBadge(kind: .soon)
            case .normal: EmptyView()
            }
        }
        .padding(PeekMetrics.compactRowInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PeekColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous))
        .opacity(finished ? PeekMetrics.finishedRowOpacity : 1)
        .peekFocusRing(isSelected)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(NSLocalizedString("Show meeting", comment: "Accessibility: open the meeting page")), onOpen)
    }
}

// MARK: - Meeting page ("You're about to meet")

/// The meeting page that replaces the agenda inside the popover. The title says who you
/// are meeting; the brief and every section say where they come from.
struct MeetingPage: View {
    let event: EKEvent
    var worldClockZones: [String] = []
    /// Non-nil adds the mute and hide menu to the back bar (PEEK-273).
    var calendarManager: CalendarManager? = nil
    let onBack: () -> Void
    @ObservedObject var briefService: MeetingBriefService = .shared
    @ObservedObject var discreetMode: DiscreetModeController = .shared

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }
    private var tone: PeekTone { PeekTone(EventPresentation.urgency(event)) }

    var body: some View {
        let discreet = discreetMode.isActive
        let context = discreet ? MeetingContext.empty : MeetingContextProvider.context(for: event)
        let detail = EventDetailBuilder.make(from: event)
        VStack(alignment: .leading, spacing: 0) {
            backBar
            Divider().overlay(PeekColor.hairline)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PeekSpacing.lg) {
                    summary(context)
                    if discreet {
                        // PEEK-274: only the time, title and join button.
                        discreetNotice
                        timeZonesSection
                    } else {
                        peopleSection(context: context, detail: detail)
                        briefCard
                        externalContextSection(context, briefPoints: event.isAllDay ? [] : briefService.brief(for: event)?.points ?? [])
                        timeZonesSection
                        notesSection(context.agenda ?? detail.notes)
                        sourcesRow(context)
                    }
                }
                .padding(PeekMetrics.meetingPageInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: PeekMetrics.meetingPageMaxHeight)
        }
        .accessibilityElement(children: .contain)
    }

    private var backBar: some View {
        HStack(spacing: PeekSpacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(PeekIcon.nav)
            }
            .buttonStyle(HeaderNavButtonStyle(square: true))
            .help(NSLocalizedString("Back to the agenda", comment: "Meeting page: back button"))
            .accessibilityLabel(Text(NSLocalizedString("Back to the agenda", comment: "Meeting page: back button")))
            Text(NSLocalizedString("Agenda", comment: "Meeting page: back bar label"))
                .font(PeekFont.body)
                .foregroundColor(PeekColor.secondaryText)
            Spacer()
            if let calendarManager {
                Menu {
                    EventOverrideMenuItems(
                        event: event,
                        calendarManager: calendarManager,
                        onHide: onBack
                    )
                } label: {
                    Image(systemName: calendarManager.overrideAction(for: event) == .mute ? "bell.slash" : "ellipsis.circle")
                        .font(PeekIcon.nav)
                        .foregroundColor(PeekColor.secondaryText)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(NSLocalizedString("Mute or hide this event", comment: "Meeting page: event options menu"))
                .accessibilityLabel(Text(NSLocalizedString("Mute or hide this event", comment: "Meeting page: event options menu")))
            }
        }
        .padding(PeekMetrics.meetingBackBarInsets)
    }

    private func summary(_ context: MeetingContext) -> some View {
        let title = EventPresentation.title(event)
        // Peek's own "You're about to meet…" is the page title, with the event
        // title below it. A headline from the context file goes to Context.
        let ownHeadline = context.ownHeadline
        var subtitleParts: [String] = []
        if ownHeadline != nil { subtitleParts.append(title) }
        if let meetingURL {
            subtitleParts.append(MeetingProvider.label(for: meetingURL))
        } else if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            subtitleParts.append(location)
        }
        if ownHeadline != nil, context.people.count > 1 {
            subtitleParts.append(context.people.count == 2
                ? NSLocalizedString("1 other person", comment: "Meeting page: one more attendee")
                : String(format: NSLocalizedString("%d other people", comment: "Meeting page: more attendees"), context.people.count - 1))
        }
        if subtitleParts.isEmpty, let calendar = event.calendar?.title {
            subtitleParts.append(calendar)
        }
        let eyebrow = event.isAllDay
            ? EventPresentation.eyebrow(event)
            : (event.startDate > Date()
                ? EventPresentation.joined(
                    EventTimeFormatter.countdownText(target: event.startDate).uppercased(with: .current),
                    EventPresentation.timeRange(event))
                : EventPresentation.joined(EventPresentation.eyebrow(event), EventPresentation.timeRange(event)))

        return VStack(alignment: .leading, spacing: PeekMetrics.headerGap) {
            Text(eyebrow)
                .font(PeekFont.label)
                .tracking(PeekFont.labelTracking)
                .foregroundColor(tone.text)
            Text(ownHeadline ?? title)
                .font(PeekFont.meetingTitle)
                .foregroundColor(PeekColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !subtitleParts.isEmpty {
                Text(subtitleParts.joined(separator: " · "))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let meetingURL {
                EventJoinButton(event: event, url: meetingURL, fullWidth: true)
            }
        }
    }

    private var discreetNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
            Image(systemName: "eye.slash")
                .font(PeekIcon.detail)
                .accessibilityHidden(true)
            Text(NSLocalizedString("Discreet mode is on. Brief, people and notes are hidden.", comment: "Meeting page: discreet mode notice"))
                .font(PeekFont.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(PeekColor.secondaryText)
        .accessibilityElement(children: .combine)
    }

    // MARK: People

    @ViewBuilder
    private func peopleSection(context: MeetingContext, detail: EventDetail) -> some View {
        if !context.people.isEmpty {
            section(NSLocalizedString("Who you're meeting", comment: "Meeting page section: people")) {
                VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                    ForEach(Array(context.people.prefix(EventDetail.maxVisibleAttendees).enumerated()), id: \.offset) { index, person in
                        HStack(spacing: PeekMetrics.headerGap) {
                            PeekAvatar(initials: PeekAvatar.initials(for: person.name), isLead: index == 0)
                            VStack(alignment: .leading, spacing: PeekSpacing.hairline) {
                                Text(person.name)
                                    .font(PeekFont.bodyEmphasis)
                                    .foregroundColor(PeekColor.ink)
                                    .lineLimit(1)
                                if let line = personLine(person) {
                                    Text(line)
                                        .font(PeekFont.caption)
                                        .foregroundColor(PeekColor.secondaryText)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: responseIcon(person.response))
                                .font(PeekIcon.detail)
                                .foregroundColor(responseColor(person.response))
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if context.people.count > EventDetail.maxVisibleAttendees {
                        Text(String(format: NSLocalizedString("+%d more", comment: "Count of attendees not shown in the expanded event row"), context.people.count - EventDetail.maxVisibleAttendees))
                            .font(PeekFont.caption)
                            .foregroundColor(PeekColor.tertiaryText)
                    }
                }
            }
        }
    }

    private func personLine(_ person: MeetingPerson) -> String? {
        var parts: [String] = []
        if let descriptor = person.descriptor { parts.append(descriptor) }
        if person.isOrganizer {
            parts.append(NSLocalizedString("Organizer", comment: "Marks the event organizer in the attendee list").lowercased(with: .current))
        }
        if let note = person.note { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func responseIcon(_ response: AttendeeResponse) -> String {
        switch response {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle"
        case .tentative: return "questionmark.circle"
        case .pending: return "clock"
        case .unknown: return "circle"
        }
    }

    private func responseColor(_ response: AttendeeResponse) -> Color {
        switch response {
        case .accepted: return PeekColor.calm
        case .declined: return PeekColor.criticalText
        case .tentative: return PeekColor.urgentText
        case .pending, .unknown: return PeekColor.tertiaryText
        }
    }

    // MARK: Brief

    @ViewBuilder
    private var briefCard: some View {
        if !event.isAllDay {
            let brief = briefService.brief(for: event)
            let preparing = briefService.isPreparing(event)
            let canPrepare = briefService.canPrepare(event)
            let error = briefService.error(for: event)
            if brief != nil || preparing || canPrepare || error != nil {
                VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                    HStack(spacing: PeekSpacing.sm) {
                        Text(NSLocalizedString("What to prepare", comment: "Meeting page: brief card title"))
                            .font(PeekFont.bodyEmphasis)
                            .foregroundColor(PeekColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: PeekSpacing.sm)
                        if let brief {
                            Text(EventPresentation.sourceLabel(for: brief.source))
                                .font(PeekFont.smallCaptionStrong)
                                .foregroundColor(PeekColor.accentText)
                                .padding(PeekMetrics.sourcePillInsets)
                                .background(Capsule().fill(PeekColor.blueTint))
                        }
                    }

                    if let brief {
                        ForEach(Array(brief.points.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.sm) {
                                Circle()
                                    .fill(PeekColor.accentRail)
                                    .frame(width: PeekMetrics.briefBullet, height: PeekMetrics.briefBullet)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + PeekSpacing.xxs }
                                    .accessibilityHidden(true)
                                Text(point)
                                    .font(PeekFont.bodyMeta)
                                    .foregroundColor(PeekColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else if preparing {
                        HStack(spacing: PeekSpacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text(NSLocalizedString("Preparing brief…", comment: "Brief is being generated"))
                                .font(PeekFont.caption)
                                .foregroundColor(PeekColor.secondaryText)
                        }
                    } else {
                        if let error {
                            Text(error)
                                .font(PeekFont.caption)
                                .foregroundColor(PeekColor.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if canPrepare {
                            Button {
                                briefService.prepare(event)
                            } label: {
                                HStack(spacing: PeekSpacing.xs) {
                                    Image(systemName: "sparkles")
                                        .font(PeekIcon.detail)
                                        .accessibilityHidden(true)
                                    Text(error == nil
                                        ? NSLocalizedString("Prepare brief", comment: "Button: generate a meeting brief now")
                                        : NSLocalizedString("Try again", comment: "Button: retry generating a meeting brief"))
                                        .font(PeekFont.caption)
                                }
                                .foregroundColor(PeekColor.accentText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(PeekMetrics.briefCardInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PeekColor.nextWash)
                .overlay(
                    RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous)
                        .strokeBorder(PeekColor.nextBorder, lineWidth: PeekSpacing.hairline)
                )
                .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Context, time zones, notes

    @ViewBuilder
    private func externalContextSection(_ context: MeetingContext, briefPoints: [String]) -> some View {
        // Bullets already listed under "What to prepare" are not repeated here.
        let bullets = context.contextBullets(excludingBriefPoints: briefPoints)
        if context.contextFileHeadline != nil || context.summary != nil || !bullets.isEmpty || !context.links.isEmpty {
            section(NSLocalizedString("Context", comment: "Expanded event section: context from the context folder")) {
                VStack(alignment: .leading, spacing: PeekSpacing.xs) {
                    if let headline = context.contextFileHeadline {
                        Text(headline)
                            .font(PeekFont.bodyEmphasis)
                            .foregroundColor(PeekColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let summary = context.summary {
                        Text(summary)
                            .font(PeekFont.bodyMeta)
                            .foregroundColor(PeekColor.bodyText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
                            Text(verbatim: "•")
                                .font(PeekFont.bodyMeta)
                                .foregroundColor(PeekColor.tertiaryText)
                                .accessibilityHidden(true)
                            Text(bullet)
                                .font(PeekFont.bodyMeta)
                                .foregroundColor(PeekColor.bodyText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(Array(context.links.enumerated()), id: \.offset) { _, link in
                        Button {
                            ContextLinkOpener.open(link.url)
                        } label: {
                            HStack(spacing: PeekSpacing.xs) {
                                Image(systemName: "link")
                                    .font(PeekIcon.detail)
                                    .accessibilityHidden(true)
                                Text(link.title)
                                    .font(PeekFont.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(PeekColor.accentText)
                        }
                        .buttonStyle(.plain)
                        .help(link.url.absoluteString)
                    }
                    if let staleDate = context.staleContextDate {
                        Text(String(
                            format: NSLocalizedString("Context from %@", comment: "Meeting page: the context file is more than 36 hours old; placeholder is its date"),
                            Self.staleDateFormatter.string(from: staleDate)
                        ))
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.tertiaryText)
                    }
                }
            }
        }
    }

    /// "23 Nov".
    private static let staleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    @ViewBuilder
    private var timeZonesSection: some View {
        if !event.isAllDay, !worldClockZones.isEmpty {
            section(NSLocalizedString("Time zones", comment: "Expanded event section: meeting time in other zones")) {
                VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
                    ForEach(worldClockZones, id: \.self) { identifier in
                        if let range = WorldClock.rangeText(start: event.startDate, end: event.endDate, in: identifier) {
                            HStack(spacing: PeekSpacing.sm) {
                                Text(WorldClock.cityName(for: identifier))
                                    .font(PeekFont.bodyMeta)
                                    .foregroundColor(PeekColor.secondaryText)
                                    .lineLimit(1)
                                Spacer(minLength: PeekSpacing.sm)
                                Text(range)
                                    .font(PeekFont.bodyMeta)
                                    .foregroundColor(PeekColor.bodyText)
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ notes: String?) -> some View {
        if let notes {
            section(NSLocalizedString("From the invitation notes", comment: "Meeting page section: cleaned-up invitation notes")) {
                Text(notes)
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourcesRow(_ context: MeetingContext) -> some View {
        var sources = [NSLocalizedString("Calendar", comment: "Meeting page source: the Calendar app")]
        if MeetingContextProvider.usesContacts(), context.people.contains(where: { $0.role != nil || $0.company != nil }) {
            sources.append(NSLocalizedString("Contacts", comment: "Meeting page source: the Contacts app"))
        }
        if context.hasExternalContext {
            sources.append(NSLocalizedString("context folder", comment: "Meeting page source: the context folder"))
        }
        return HStack(spacing: PeekSpacing.sm) {
            Text(String(format: NSLocalizedString("Sources: %@", comment: "Meeting page: where the details come from"), sources.joined(separator: ", ")))
                .font(PeekFont.caption)
                .foregroundColor(PeekColor.tertiaryText)
                .lineLimit(1)
            Spacer(minLength: PeekSpacing.sm)
            Button(NSLocalizedString("Open in Calendar", comment: "Context menu: open in calendar")) {
                let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
                NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
            }
            .buttonStyle(.plain)
            .font(PeekFont.caption)
            .foregroundColor(PeekColor.accentText)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            Text(title.uppercased(with: .current))
                .font(PeekFont.sectionLabel)
                .tracking(PeekFont.groupLabelTracking)
                .foregroundColor(PeekColor.tertiaryText)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

struct EventContextMenu: View {
    let event: EKEvent
    var calendarManager: CalendarManager? = nil

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }

    var body: some View {
        if let calendarManager {
            EventOverrideMenuItems(event: event, calendarManager: calendarManager)
            Divider()
        }

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

/// Mute, hide and restore for one event (PEEK-273). A recurring event asks
/// each time: this occurrence (listed first) or the whole series.
struct EventOverrideMenuItems: View {
    let event: EKEvent
    @ObservedObject var calendarManager: CalendarManager
    /// Called after hiding, so a meeting page can return to the agenda.
    var onHide: (() -> Void)? = nil

    private var isRecurring: Bool { event.candidateIdentity?.isRecurring ?? false }

    var body: some View {
        if event.candidateIdentity != nil {
            switch calendarManager.overrideAction(for: event) {
            case .some(.mute):
                Button(NSLocalizedString("Unmute Alerts", comment: "Event menu: restore alerts for a muted event")) {
                    calendarManager.restoreEvent(event)
                }
                actionItem(.hide)
            case .some(.hide):
                Button(NSLocalizedString("Show Event", comment: "Event menu: restore a hidden event")) {
                    calendarManager.restoreEvent(event)
                }
            case .none:
                actionItem(.mute)
                actionItem(.hide)
            }
        }
    }

    @ViewBuilder
    private func actionItem(_ action: EventOverrideAction) -> some View {
        let title = Self.title(for: action)
        if isRecurring {
            Menu(title) {
                Button(NSLocalizedString("This Event Only", comment: "Event menu: apply to one occurrence of a recurring event")) {
                    apply(action, wholeSeries: false)
                }
                Button(NSLocalizedString("All Events in the Series", comment: "Event menu: apply to every occurrence of a recurring event")) {
                    apply(action, wholeSeries: true)
                }
            }
        } else {
            Button(title) { apply(action, wholeSeries: false) }
        }
    }

    private func apply(_ action: EventOverrideAction, wholeSeries: Bool) {
        calendarManager.setOverride(action, for: event, wholeSeries: wholeSeries)
        if action == .hide {
            onHide?()
        }
    }

    static func title(for action: EventOverrideAction) -> String {
        switch action {
        case .mute:
            return NSLocalizedString("Mute Alerts", comment: "Event menu: no notification, card or full-screen alert for this event")
        case .hide:
            return NSLocalizedString("Hide Event", comment: "Event menu: remove this event from the popover and menu bar")
        }
    }
}

/// The bell-slash beside a muted event's time (PEEK-273).
struct MutedEventIcon: View {
    var body: some View {
        Image(systemName: "bell.slash")
            .font(PeekIcon.meta)
            .foregroundColor(PeekColor.tertiaryText)
            .help(NSLocalizedString("Alerts muted", comment: "Muted event indicator"))
            .accessibilityLabel(Text(NSLocalizedString("Alerts muted", comment: "Muted event indicator")))
    }
}

// MARK: - Day priorities (PEEK-261)

/// Today's priorities and links from the context file, above the next-meeting
/// card. Shown only when `day.date` is today and the file is fresh. Read-only:
/// done priorities are dimmed, and Peek never writes back.
struct DayPrioritiesBlock: View {
    var folder: ContextFolderStore = .shared

    var body: some View {
        // Re-evaluated every minute, so the block appears and hides at midnight.
        TimelineView(.everyMinute) { timeline in
            if let day = folder.day(now: timeline.date) {
                content(day)
            }
        }
    }

    private func content(_ day: MeetingContextFile.Day) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            Text(NSLocalizedString("Today's priorities", comment: "Popover: eyebrow above the day's priorities from the context file").uppercased(with: .current))
                .font(PeekFont.label)
                .tracking(PeekFont.labelTracking)
                .foregroundColor(PeekColor.accentText)
                .accessibilityAddTraits(.isHeader)

            if let headline = day.headline {
                Text(headline)
                    .font(PeekFont.bodyEmphasis)
                    .foregroundColor(PeekColor.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !day.shownPriorities.isEmpty {
                VStack(alignment: .leading, spacing: PeekSpacing.xs) {
                    ForEach(Array(day.shownPriorities.enumerated()), id: \.offset) { _, priority in
                        priorityRow(priority)
                    }
                }
            }

            if !day.links.isEmpty {
                HStack(spacing: PeekSpacing.sm) {
                    ForEach(Array(day.links.enumerated()), id: \.offset) { _, link in
                        Button {
                            ContextLinkOpener.open(link.url)
                        } label: {
                            HStack(spacing: PeekSpacing.iconGap) {
                                Image(systemName: "arrow.up.forward.square")
                                    .font(PeekIcon.detail)
                                    .accessibilityHidden(true)
                                Text(link.title)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(SoftAccentButtonStyle())
                        .help(link.url.absoluteString)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(PeekMetrics.nextCardInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PeekColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.card, style: .continuous))
        .padding(PeekMetrics.dayBlockInsets)
        .background(PeekColor.canvas)
        .accessibilityElement(children: .contain)
    }

    private func priorityRow(_ priority: MeetingContextFile.Day.Priority) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
            Image(systemName: priority.done ? "checkmark.circle.fill" : "circle")
                .font(PeekIcon.detail)
                .foregroundColor(priority.done ? PeekColor.tertiaryText : PeekColor.accentText)
                .accessibilityHidden(true)
            Text(priority.text)
                .font(PeekFont.bodyMeta)
                .foregroundColor(priority.done ? PeekColor.tertiaryText : PeekColor.bodyText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(priority.done
            ? String(format: NSLocalizedString("Done: %@", comment: "Accessibility: a day priority already done"), priority.text)
            : priority.text))
    }
}

// MARK: - World clocks (PEEK-233)

/// The current time in the cities chosen in Preferences, under the header.
struct WorldClockStrip: View {
    let zones: [String]

    var body: some View {
        TimelineView(.everyMinute) { context in
            PeekFlowLayout {
                ForEach(WorldClock.entries(at: context.date, zones: zones), id: \.identifier) { entry in
                    PeekWorldClockChip(city: entry.city, time: entry.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PeekMetrics.worldClockStripInsets)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("World clocks", comment: "Accessibility: world clock strip")))
    }
}
