import SwiftUI
import AppKit
import EventKit
import Foundation

struct MenuBarView: View {
    // Key codes
    private static let kEscapeKeyCode: UInt16 = 53
    private static let kReturnKeyCode: UInt16 = 36
    private static let kDownArrowKeyCode: UInt16 = 125
    private static let kUpArrowKeyCode: UInt16 = 126

    @ObservedObject var calendarManager: CalendarManager
    @State private var showingPreferences = false
    @State private var selectedEventIndex: Int = 0
    @State private var expandedEventID: String?
    @State private var eventMonitor: Any?
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false
    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?
    @State private var eventDays: Set<Date> = []
    @State private var dayEvents: [EKEvent] = []
    var closePopover: (() -> Void)?
    var refreshStatusBar: ((EKEvent?) -> Void)? = nil
    private let refreshFeedbackMinDuration: TimeInterval = 0.4
    private let refreshConfirmationDuration: TimeInterval = 0.9

    private static let dayAgendaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter
    }()

    private var monthGrid: MonthGrid { MonthGrid.make(containing: displayedMonth) }

    /// A chosen day other than today replaces the upcoming list with that day's agenda.
    private var chosenOtherDay: Date? {
        guard let selectedDay, !Calendar.current.isDateInToday(selectedDay) else { return nil }
        return selectedDay
    }

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

            if calendarManager.showMonthCalendar && calendarManager.hasCalendarAccess {
                MonthCalendarView(
                    grid: monthGrid,
                    eventDays: eventDays,
                    selectedDay: selectedDay,
                    onSelectDay: selectDay,
                    onPreviousMonth: { shiftMonth(by: -1) },
                    onNextMonth: { shiftMonth(by: 1) },
                    onToday: showToday
                )
                Divider().overlay(PeekColor.innerDivider)
            }

            if let day = chosenOtherDay {
                dayAgenda(for: day)
            } else if calendarManager.upcomingEvents.isEmpty {
                emptyState
            } else {
                eventList
            }

            Divider().overlay(PeekColor.innerDivider)
            footer
        }
        .frame(width: PeekMetrics.popoverWidth)
        .background(PeekColor.surface)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(calendarManager: calendarManager)
        }
        .onAppear {
            reloadEventDays()
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
        .onChange(of: calendarManager.upcomingEvents.map(\.eventIdentifier)) { identifiers in
            if let expandedEventID, !identifiers.contains(expandedEventID) {
                self.expandedEventID = nil
            }
            reloadEventDays()
            if let day = chosenOtherDay {
                reloadDayEvents(for: day)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PeekMetrics.headerGap) {
            PeekAppIcon(size: PeekMetrics.headerIcon, cornerRadius: PeekRadius.join)

            VStack(alignment: .leading, spacing: PeekSpacing.hairline) {
                Text("Peek")
                    .font(PeekFont.title)
                    .foregroundColor(PeekColor.ink)
                    .accessibilityAddTraits(.isHeader)
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
        .padding(.vertical, PeekMetrics.headerVerticalPadding)
    }

    // MARK: - Event list

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeekMetrics.rowGap) {
                ForEach(Array(calendarManager.upcomingEvents.enumerated()), id: \.element.eventIdentifier) { index, event in
                    EventRow(
                        event: event,
                        isHero: index == 0,
                        isSelected: index == selectedEventIndex,
                        isExpanded: expandedEventID != nil && expandedEventID == event.eventIdentifier,
                        onToggleExpand: { toggleExpansion(for: event) }
                    )
                    .contextMenu {
                        EventContextMenu(event: event)
                    }
                }
            }
            .padding(PeekSpacing.sm)
        }
        .frame(maxHeight: PeekMetrics.popoverListMaxHeight)
        .background(PeekColor.canvas)
    }

    // MARK: - Month view (PEEK-201)

    private func dayAgenda(for day: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeekMetrics.rowGap) {
                HStack(spacing: PeekSpacing.xs) {
                    Text(Self.dayAgendaFormatter.string(from: day).capitalized)
                        .font(PeekFont.bodyEmphasis)
                        .foregroundColor(PeekColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(NSLocalizedString("Back to upcoming", comment: "Month view: return to upcoming events"), action: showToday)
                        .buttonStyle(SecondaryFillButtonStyle())
                        .controlSize(.small)
                }
                .padding(.horizontal, PeekSpacing.xs)
                .padding(.bottom, PeekSpacing.xxs)

                if dayEvents.isEmpty {
                    Text(NSLocalizedString("No events on this day.", comment: "Month view: empty day"))
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.secondaryText)
                        .padding(PeekSpacing.sm)
                } else {
                    ForEach(dayEvents, id: \.eventIdentifier) { event in
                        EventRow(
                            event: event,
                            isExpanded: expandedEventID != nil && expandedEventID == event.eventIdentifier,
                            onToggleExpand: { toggleExpansion(for: event) }
                        )
                        .contextMenu {
                            EventContextMenu(event: event)
                        }
                    }
                }
            }
            .padding(PeekSpacing.sm)
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
    }

    // MARK: - Footer

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
            } else if event.keyCode == Self.kReturnKeyCode,
                      selectedEventIndex < calendarManager.upcomingEvents.count {
                toggleExpansion(for: calendarManager.upcomingEvents[selectedEventIndex])
                return nil
            }
        }

        return event
    }

    // MARK: - Actions

    private func toggleExpansion(for event: EKEvent) {
        guard let identifier = event.eventIdentifier else { return }
        expandedEventID = (expandedEventID == identifier) ? nil : identifier
    }

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

// MARK: - Event row

struct EventRow: View {
    let event: EKEvent
    var isHero: Bool = false
    var isSelected: Bool = false
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    @ObservedObject var briefService: MeetingBriefService = .shared

    private var meetingURL: URL? { MeetingURLDetector.extract(from: event) }

    private var minutesUntil: Int {
        Int(event.startDate.timeIntervalSince(Date())) / 60
    }

    private var urgency: MeetingUrgency {
        // A finished event (shown from a past day in the month view) is never urgent.
        if event.endDate <= Date() { return .normal }
        return MeetingUrgency.from(minutesUntil: minutesUntil)
    }

    private var isUpcoming: Bool { event.startDate > Date() }

    private var tone: PeekTone { PeekTone(urgency) }

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
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpand?()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onToggleExpand?()
        }
        .accessibilityValue(Text(isExpanded
            ? NSLocalizedString("Expanded", comment: "Accessibility: event row is expanded")
            : NSLocalizedString("Collapsed", comment: "Accessibility: event row is collapsed")))
    }

    // MARK: Hero (NEXT) row

    private var heroRow: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: PeekRadius.rail, style: .continuous)
                .fill(tone.rail)
                .frame(width: PeekMetrics.railWidth)
                .padding(.vertical, PeekSpacing.xxs)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PeekMetrics.heroContentGap) {
                HStack(alignment: .top, spacing: PeekSpacing.iconGap) {
                    Text(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))
                        .font(PeekFont.headline)
                        .foregroundColor(PeekColor.ink)
                        .lineLimit(2)
                    PeekBadge(kind: badgeKind)
                    Spacer(minLength: 0)
                }

                metaRow(accented: true)
                detailRow

                if let headline = heroContext.headline {
                    HStack(alignment: .top, spacing: PeekSpacing.sm) {
                        Image(systemName: "person.2")
                            .font(PeekIcon.detail)
                            .foregroundColor(tone.text)
                            .frame(width: PeekMetrics.metaIconWidth)
                            .accessibilityHidden(true)
                        Text(headline)
                            .font(PeekFont.bodyMetaMedium)
                            .foregroundColor(PeekColor.bodyText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !isExpanded, let brief = heroBrief {
                    briefPoints(Array(brief.points.prefix(MeetingBrief.heroPointLimit)), tint: tone.text)
                }

                if let meetingURL {
                    joinButton(url: meetingURL)
                }

                if isExpanded {
                    expandedDetail
                }
            }
            .padding(PeekMetrics.heroRowInsets)
        }
        .background(tone.wash)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous))
        .peekCriticalPulse(urgency == .critical && !event.isAllDay)
    }

    // MARK: Normal row

    private var normalRow: some View {
        VStack(alignment: .leading, spacing: PeekMetrics.rowGap) {
            HStack(alignment: .top, spacing: PeekSpacing.iconGap) {
                Text(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))
                    .font(PeekFont.rowTitle)
                    .foregroundColor(isSelected ? PeekColor.accentText : PeekColor.ink)
                    .lineLimit(2)
                if event.isAllDay { PeekBadge(kind: .allDay) }
                Spacer(minLength: 0)
            }
            metaRow(accented: false)
            detailRow

            if isExpanded {
                expandedDetail
            }
        }
        .padding(PeekMetrics.rowInsets)
        .background(isSelected ? PeekColor.rowHoverWash : PeekColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous)
                .strokeBorder(PeekColor.hairline, lineWidth: PeekSpacing.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: PeekRadius.row, style: .continuous))
    }

    // MARK: Shared pieces

    private func metaRow(accented: Bool) -> some View {
        HStack(spacing: PeekSpacing.sm) {
            Image(systemName: event.isAllDay ? "calendar" : "clock")
                .font(PeekIcon.meta)
                .foregroundColor(accented ? tone.text : PeekColor.tertiaryText)
                .frame(width: PeekMetrics.metaIconWidth)
                .accessibilityHidden(true)

            if event.isAllDay {
                Text(EventTimeFormatter.compactDateText(for: event.startDate))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            } else {
                Text(EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
            }

            Spacer(minLength: PeekSpacing.iconGap)

            if isUpcoming && !event.isAllDay {
                Text(EventTimeFormatter.countdownText(target: event.startDate))
                    .font(PeekFont.captionStrong)
                    .foregroundColor(accented ? tone.text : PeekColor.tertiaryText)
            }
        }
    }

    private var detailRow: some View {
        HStack(spacing: PeekMetrics.headerGap) {
            if let meetingURL {
                HStack(spacing: PeekSpacing.xs) {
                    Image(systemName: "video")
                        .font(PeekIcon.detail)
                        .foregroundColor(PeekColor.secondaryText)
                        .accessibilityHidden(true)
                    Text(MeetingProvider.label(for: meetingURL))
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            if let location = event.location, !location.isEmpty, meetingURL == nil {
                HStack(spacing: PeekSpacing.xs) {
                    Image(systemName: "location")
                        .font(PeekIcon.detail)
                        .foregroundColor(PeekColor.secondaryText)
                        .accessibilityHidden(true)
                    Text(location)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            if let calendar = event.calendar {
                HStack(spacing: PeekSpacing.xs) {
                    Circle()
                        .fill(Color(calendar.color))
                        .frame(width: PeekMetrics.calendarDot, height: PeekMetrics.calendarDot)
                        .accessibilityHidden(true)
                    Text(calendar.title)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Expanded detail

    /// Context for the hero row's headline; built only for the hero row.
    private var heroContext: MeetingContext {
        isHero && !event.isAllDay ? MeetingContextProvider.context(for: event) : .empty
    }

    /// The brief shown on the hero row; built only for the hero row.
    private var heroBrief: MeetingBrief? {
        isHero && !event.isAllDay ? briefService.brief(for: event) : nil
    }

    private var expandedDetail: some View {
        let detail = EventDetailBuilder.make(from: event)
        let context = MeetingContextProvider.context(for: event)
        return VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            RowDivider()

            briefSection

            if detail.isEmpty && context.isEmpty {
                Text(NSLocalizedString("No additional details", comment: "Expanded event row with no notes, attendees, or attachments"))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
            } else {
                // The hero row already shows provider identity and a Join button.
                if !isHero, let meetingURL = detail.meetingURL {
                    joinButton(url: meetingURL)
                }

                if context.hasExternalContext {
                    detailSection(NSLocalizedString("Context", comment: "Expanded event section: context from the context folder")) {
                        externalContextRows(context)
                    }
                }

                if let notes = context.agenda ?? detail.notes {
                    detailSection(NSLocalizedString("Notes", comment: "Expanded event section: notes")) {
                        Text(notes)
                            .font(PeekFont.bodyMeta)
                            .foregroundColor(PeekColor.bodyText)
                            .lineLimit(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !context.people.isEmpty {
                    detailSection(NSLocalizedString("Attendees", comment: "Expanded event section: attendees")) {
                        personRows(context.people)
                    }
                } else if !detail.attendees.isEmpty {
                    detailSection(NSLocalizedString("Attendees", comment: "Expanded event section: attendees")) {
                        attendeeRows(detail: detail)
                    }
                }
            }
        }
        .padding(.top, PeekSpacing.xxs)
    }

    // MARK: Brief

    @ViewBuilder
    private var briefSection: some View {
        if !event.isAllDay {
            let brief = briefService.brief(for: event)
            let preparing = briefService.isPreparing(event)
            let canPrepare = briefService.canPrepare(event)
            let error = briefService.error(for: event)
            if brief != nil || preparing || canPrepare || error != nil {
                detailSection(NSLocalizedString("Brief", comment: "Expanded event section: meeting brief")) {
                    VStack(alignment: .leading, spacing: PeekSpacing.xs) {
                        if let brief {
                            briefPoints(brief.points, tint: PeekColor.tertiaryText)
                            Text(Self.sourceLabel(for: brief.source))
                                .font(PeekFont.caption)
                                .foregroundColor(PeekColor.tertiaryText)
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
                }
            }
        }
    }

    private func briefPoints(_ points: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
                    Image(systemName: "checkmark.circle")
                        .font(PeekIcon.detail)
                        .foregroundColor(tint)
                        .frame(width: PeekMetrics.metaIconWidth)
                        .accessibilityHidden(true)
                    Text(point)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(NSLocalizedString("Brief", comment: "Expanded event section: meeting brief") + ": " + points.joined(separator: ". ")))
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

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xs) {
            Text(title.uppercased())
                .font(PeekFont.label)
                .tracking(PeekFont.labelTracking)
                .foregroundColor(PeekColor.tertiaryText)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func externalContextRows(_ context: MeetingContext) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xs) {
            if let summary = context.summary {
                Text(summary)
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.bodyText)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(context.bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
                    Text(verbatim: "•")
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.tertiaryText)
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(Array(context.links.enumerated()), id: \.offset) { _, link in
                Button {
                    NSWorkspace.shared.open(link.url)
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
        }
    }

    private func personRows(_ people: [MeetingPerson]) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xs) {
            ForEach(Array(people.prefix(EventDetail.maxVisibleAttendees).enumerated()), id: \.offset) { _, person in
                HStack(alignment: .firstTextBaseline, spacing: PeekSpacing.iconGap) {
                    Image(systemName: attendeeResponseIcon(person.response))
                        .font(PeekIcon.detail)
                        .foregroundColor(attendeeResponseColor(person.response))
                        .frame(width: PeekMetrics.metaIconWidth)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: PeekSpacing.iconGap) {
                            Text(person.name)
                                .font(PeekFont.bodyMeta)
                                .foregroundColor(PeekColor.bodyText)
                                .lineLimit(1)
                            if person.isOrganizer {
                                Text(NSLocalizedString("Organizer", comment: "Marks the event organizer in the attendee list"))
                                    .font(PeekFont.caption)
                                    .foregroundColor(PeekColor.tertiaryText)
                            }
                        }
                        if let descriptor = person.descriptor {
                            Text(descriptor)
                                .font(PeekFont.caption)
                                .foregroundColor(PeekColor.secondaryText)
                                .lineLimit(1)
                        }
                        if let note = person.note {
                            Text(note)
                                .font(PeekFont.caption)
                                .foregroundColor(PeekColor.tertiaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if people.count > EventDetail.maxVisibleAttendees {
                Text(String(format: NSLocalizedString("+%d more", comment: "Count of attendees not shown in the expanded event row"), people.count - EventDetail.maxVisibleAttendees))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
            }
        }
    }

    private func attendeeRows(detail: EventDetail) -> some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xs) {
            ForEach(Array(detail.visibleAttendees.enumerated()), id: \.offset) { _, attendee in
                HStack(spacing: PeekSpacing.iconGap) {
                    Image(systemName: attendeeResponseIcon(attendee.response))
                        .font(PeekIcon.detail)
                        .foregroundColor(attendeeResponseColor(attendee.response))
                        .frame(width: PeekMetrics.metaIconWidth)
                        .accessibilityHidden(true)
                    Text(attendee.displayName)
                        .font(PeekFont.bodyMeta)
                        .foregroundColor(PeekColor.bodyText)
                        .lineLimit(1)
                    if attendee.isOrganizer {
                        Text(NSLocalizedString("Organizer", comment: "Marks the event organizer in the attendee list"))
                            .font(PeekFont.caption)
                            .foregroundColor(PeekColor.tertiaryText)
                    }
                }
            }
            if detail.hiddenAttendeeCount > 0 {
                Text(String(format: NSLocalizedString("+%d more", comment: "Count of attendees not shown in the expanded event row"), detail.hiddenAttendeeCount))
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
            }
        }
    }

    private func attendeeResponseIcon(_ response: AttendeeResponse) -> String {
        switch response {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle"
        case .tentative: return "questionmark.circle"
        case .pending: return "clock"
        case .unknown: return "person"
        }
    }

    private func attendeeResponseColor(_ response: AttendeeResponse) -> Color {
        switch response {
        case .accepted: return PeekColor.calm
        case .declined: return PeekColor.criticalText
        case .tentative: return PeekColor.urgentText
        case .pending, .unknown: return PeekColor.tertiaryText
        }
    }

    private func joinButton(url: URL) -> some View {
        Button {
            MeetingLinkOpener.open(url)
        } label: {
            HStack(spacing: PeekSpacing.tightGap) {
                Image(systemName: "video.fill")
                    .font(PeekIcon.detail)
                    .accessibilityHidden(true)
                Text(joinTitle(url: url))
            }
        }
        .buttonStyle(JoinButtonStyle(tone: tone))
        .padding(.top, PeekSpacing.xxs)
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
