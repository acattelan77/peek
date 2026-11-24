import Foundation
import EventKit

class CalendarManager: ObservableObject {
    private static let kLateGraceMinutes = 5

    private let eventStore: any CalendarEventStoring
    private let fetchQueue = DispatchQueue(label: "Peek.CalendarManager.fetch")
    private var eventStoreChangedObserver: NSObjectProtocol?
    @Published var nextEvent: EKEvent?
    @Published var upcomingEvents: [EKEvent] = []
    private(set) var allUpcomingEvents: [EKEvent] = []
    /// Visible events not yet ended, including running ones (join shortcut).
    private(set) var activeEvents: [EKEvent] = []
    private(set) var hasCustomCalendarSelection: Bool = false
    @Published var hasCalendarAccess = false
    @Published var enabledCalendarIDs: Set<String> = []
    @Published var lookaheadDays: Int = 7
    @Published var maxEventsToShow: Int = 5
    @Published var hideAllDayEvents: Bool = false
    @Published var hideDeclinedEvents: Bool = true
    @Published var filterKeywords: String = ""
    @Published var statusBarMode: StatusBarDisplayMode = .timeUntil
    @Published var menuBarSpacePolicy: MenuBarSpacePolicy = .automatic
    @Published var appearanceMode: AppearanceMode = .auto
    @Published var globalHotkey: HotkeyOption = .cmdShiftC
    @Published var joinHotkey: JoinHotkeyOption = .ctrlOptionJ
    @Published var joinHotkeyStatusMessage: String?
    @Published var statusBarOnlyMeetings: Bool = false
    @Published var statusBarLabelStyle: StatusBarLabelStyle = .eventTitle
    @Published var worldClockZones: [String] = []
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTiming: NotificationTiming = .fifteenMinutes
    @Published var urgencyColorsEnabled: Bool = true
    @Published var openMeetingsInNativeApp: Bool = true
    @Published var showMonthCalendar: Bool = true
    @Published var startAlertStyle: StartAlertStyle = .hud
    @Published var interruptOnlyForMeetings: Bool = true
    /// Alert ladder, 2 minutes before: show the heads-up card.
    @Published var soonCardEnabled: Bool = true
    /// Calendars that only show in the menu bar: no notification, card or
    /// start alert (Preferences > Alerts > Which meetings).
    @Published var badgeOnlyCalendarIDs: Set<String> = []
    /// Per-event mute and hide choices (PEEK-273).
    @Published private(set) var eventOverrides: EventOverrides = .none
    @Published var meetingContextUsesContacts: Bool = false
    @Published var contactsStatusMessage: String?
    @Published var contextFolderName: String?
    @Published var contextFolderStatusMessage: String?
    /// Popover day block from the context file (PEEK-261). On by default.
    @Published var showDayPriorities: Bool = true

    /// Whether the first-run onboarding flow has been completed. Persisted so it is
    /// only shown once.
    @Published var hasCompletedOnboarding: Bool = false

    /// Transient (not persisted) message describing the outcome of the most recent
    /// global-hotkey registration. `nil` means the current hotkey is active.
    @Published var hotkeyStatusMessage: String?

    /// Transient (not persisted) result of scheduling meeting reminders. The UI
    /// deliberately contains no event details so it cannot expose calendar content.
    @Published var notificationStatusMessage: String?

    private let defaults: any PreferencesStoring
    private let enabledCalendarsKey = "enabledCalendarIDs"
    private let hasCustomCalendarsKey = "hasCustomCalendarSelection"
    private let lookaheadDaysKey = "lookaheadDays"
    private let maxEventsKey = "maxEventsToShow"
    private let hideAllDayKey = "hideAllDayEvents"
    private let hideDeclinedKey = "hideDeclinedEvents"
    private let filterKeywordsKey = "filterKeywords"
    private let statusBarModeKey = "statusBarMode"
    private let menuBarSpacePolicyKey = "menuBarSpacePolicy"
    private let appearanceModeKey = "appearanceMode"
    private let globalHotkeyKey = "globalHotkey"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationTimingKey = "notificationTiming"
    private let urgencyColorsEnabledKey = "urgencyColorsEnabled"
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let openMeetingsInNativeAppKey = MeetingLinkOpener.preferNativeAppKey
    private let showMonthCalendarKey = "showMonthCalendar"
    private let startAlertStyleKey = "startAlertStyle"
    private let interruptOnlyForMeetingsKey = "interruptOnlyForMeetings"
    private let soonCardEnabledKey = "soonCardEnabled"
    private let badgeOnlyCalendarIDsKey = "badgeOnlyCalendarIDs"
    private let joinHotkeyKey = "joinHotkey"
    private let statusBarOnlyMeetingsKey = "statusBarOnlyMeetings"
    private let statusBarLabelStyleKey = "statusBarLabelStyle"
    private let worldClockZonesKey = "worldClockZones"
    private let showDayPrioritiesKey = "showDayPriorities"
    private let eventOverridesKey = "eventOverrides"

    init(
        eventStore: any CalendarEventStoring = EventKitCalendarEventStore(),
        preferencesStore: any PreferencesStoring = UserDefaults.standard
    ) {
        self.eventStore = eventStore
        self.defaults = preferencesStore
        loadEnabledCalendars()
        loadPreferences()
    }

    func loadEnabledCalendars() {
        if let savedIDs = defaults.array(forKey: enabledCalendarsKey) as? [String] {
            enabledCalendarIDs = Set(savedIDs)
            hasCustomCalendarSelection = defaults.object(forKey: hasCustomCalendarsKey) as? Bool ?? true
        } else {
            // First launch: enable all calendars by default
            let allCalendars = getAllCalendars()
            enabledCalendarIDs = Set(allCalendars.map { $0.calendarIdentifier })
            hasCustomCalendarSelection = false
            saveEnabledCalendars()
        }
    }

    func loadPreferences() {
        lookaheadDays = PreferenceConstraints.validLookahead(defaults.integer(forKey: lookaheadDaysKey)) ?? 7
        maxEventsToShow = PreferenceConstraints.validEventLimit(defaults.integer(forKey: maxEventsKey)) ?? 5

        hideAllDayEvents = defaults.bool(forKey: hideAllDayKey)
        hideDeclinedEvents = defaults.bool(forKey: hideDeclinedKey)
        filterKeywords = defaults.string(forKey: filterKeywordsKey) ?? ""

        if let modeString = defaults.string(forKey: statusBarModeKey) {
            if modeString == "Icon Only" {
                // Migrate the old icon-only display mode to the new space policy.
                statusBarMode = .timeUntil
                menuBarSpacePolicy = .alwaysShowIcon
            } else if let mode = StatusBarDisplayMode(rawValue: modeString) {
                statusBarMode = mode
            }
        }

        if let policyString = defaults.string(forKey: menuBarSpacePolicyKey),
           let policy = MenuBarSpacePolicy(rawValue: policyString) {
            menuBarSpacePolicy = policy
        }


        if let appearanceString = defaults.string(forKey: appearanceModeKey),
           let appearance = AppearanceMode(rawValue: appearanceString) {
            appearanceMode = appearance
        }

        if let hotkeyString = defaults.string(forKey: globalHotkeyKey),
           let hotkey = HotkeyOption(rawValue: hotkeyString) {
            globalHotkey = hotkey
        }

        notificationsEnabled = defaults.bool(forKey: notificationsEnabledKey)

        let timingValue = defaults.integer(forKey: notificationTimingKey)
        if let timing = NotificationTiming(rawValue: timingValue) {
            notificationTiming = timing
        }

        urgencyColorsEnabled = defaults.object(forKey: urgencyColorsEnabledKey) as? Bool ?? true
        openMeetingsInNativeApp = MeetingLinkOpener.prefersNativeApp(defaults)
        showMonthCalendar = defaults.object(forKey: showMonthCalendarKey) as? Bool ?? true
        startAlertStyle = defaults.string(forKey: startAlertStyleKey).flatMap(StartAlertStyle.init(rawValue:)) ?? .hud
        interruptOnlyForMeetings = defaults.object(forKey: interruptOnlyForMeetingsKey) as? Bool ?? true
        soonCardEnabled = defaults.object(forKey: soonCardEnabledKey) as? Bool ?? true
        badgeOnlyCalendarIDs = Set(defaults.array(forKey: badgeOnlyCalendarIDsKey) as? [String] ?? [])
        meetingContextUsesContacts = defaults.bool(forKey: MeetingContextProvider.useContactsKey)
        joinHotkey = defaults.string(forKey: joinHotkeyKey).flatMap(JoinHotkeyOption.init(rawValue:)) ?? .ctrlOptionJ
        statusBarOnlyMeetings = defaults.bool(forKey: statusBarOnlyMeetingsKey)
        statusBarLabelStyle = defaults.string(forKey: statusBarLabelStyleKey).flatMap(StatusBarLabelStyle.init(rawValue:)) ?? .eventTitle
        worldClockZones = WorldClock.sanitized(defaults.array(forKey: worldClockZonesKey) as? [String] ?? [])
        showDayPriorities = defaults.object(forKey: showDayPrioritiesKey) as? Bool ?? true
        var overrides = EventOverrides.decoded(from: defaults.object(forKey: eventOverridesKey) as? Data)
        overrides.prune(now: Date())
        eventOverrides = overrides

        hasCompletedOnboarding = defaults.bool(forKey: hasCompletedOnboardingKey)
    }

    /// Persists that onboarding has finished, so it will not be shown again.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }

    func savePreferences() {
        defaults.set(lookaheadDays, forKey: lookaheadDaysKey)
        defaults.set(maxEventsToShow, forKey: maxEventsKey)
        defaults.set(hideAllDayEvents, forKey: hideAllDayKey)
        defaults.set(hideDeclinedEvents, forKey: hideDeclinedKey)
        defaults.set(filterKeywords, forKey: filterKeywordsKey)
        defaults.set(statusBarMode.rawValue, forKey: statusBarModeKey)
        defaults.set(menuBarSpacePolicy.rawValue, forKey: menuBarSpacePolicyKey)
        defaults.set(appearanceMode.rawValue, forKey: appearanceModeKey)
        defaults.set(globalHotkey.rawValue, forKey: globalHotkeyKey)
        defaults.set(notificationsEnabled, forKey: notificationsEnabledKey)
        defaults.set(notificationTiming.rawValue, forKey: notificationTimingKey)
        defaults.set(urgencyColorsEnabled, forKey: urgencyColorsEnabledKey)
        defaults.set(openMeetingsInNativeApp, forKey: openMeetingsInNativeAppKey)
        defaults.set(showMonthCalendar, forKey: showMonthCalendarKey)
        defaults.set(startAlertStyle.rawValue, forKey: startAlertStyleKey)
        defaults.set(interruptOnlyForMeetings, forKey: interruptOnlyForMeetingsKey)
        defaults.set(soonCardEnabled, forKey: soonCardEnabledKey)
        defaults.set(Array(badgeOnlyCalendarIDs), forKey: badgeOnlyCalendarIDsKey)
        defaults.set(meetingContextUsesContacts, forKey: MeetingContextProvider.useContactsKey)
        defaults.set(joinHotkey.rawValue, forKey: joinHotkeyKey)
        defaults.set(statusBarOnlyMeetings, forKey: statusBarOnlyMeetingsKey)
        defaults.set(statusBarLabelStyle.rawValue, forKey: statusBarLabelStyleKey)
        defaults.set(worldClockZones, forKey: worldClockZonesKey)
        defaults.set(showDayPriorities, forKey: showDayPrioritiesKey)
    }

    // MARK: - World clocks (PEEK-233)

    func addWorldClock(_ identifier: String) {
        worldClockZones = WorldClock.sanitized(worldClockZones + [identifier])
        defaults.set(worldClockZones, forKey: worldClockZonesKey)
    }

    func removeWorldClock(_ identifier: String) {
        worldClockZones.removeAll { $0 == identifier }
        defaults.set(worldClockZones, forKey: worldClockZonesKey)
    }

    func saveEnabledCalendars() {
        defaults.set(Array(enabledCalendarIDs), forKey: enabledCalendarsKey)
        defaults.set(hasCustomCalendarSelection, forKey: hasCustomCalendarsKey)
    }

    func toggleCalendar(_ calendarID: String) {
        if enabledCalendarIDs.contains(calendarID) {
            enabledCalendarIDs.remove(calendarID)
        } else {
            enabledCalendarIDs.insert(calendarID)
        }
        hasCustomCalendarSelection = true
        saveEnabledCalendars()
    }

    func toggleBadgeOnly(_ calendarID: String) {
        if badgeOnlyCalendarIDs.contains(calendarID) {
            badgeOnlyCalendarIDs.remove(calendarID)
        } else {
            badgeOnlyCalendarIDs.insert(calendarID)
        }
        defaults.set(Array(badgeOnlyCalendarIDs), forKey: badgeOnlyCalendarIDsKey)
    }

    /// Whether an event on `calendarID` may notify or interrupt.
    func alerts(forCalendarID calendarID: String?) -> Bool {
        AlertLadder.alerts(calendarID: calendarID, badgeOnlyCalendarIDs: badgeOnlyCalendarIDs)
    }

    /// Whether this event may notify or interrupt: its calendar is not
    /// badge-only and the user has not muted or hidden it (PEEK-273).
    func alerts(for event: EKEvent) -> Bool {
        alerts(forCalendarID: event.calendar?.calendarIdentifier)
            && !eventOverrides.isSilenced(event.candidateIdentity)
    }

    // MARK: - Per-event control (PEEK-273)

    func overrideAction(for event: EKEvent) -> EventOverrideAction? {
        eventOverrides.action(for: event.candidateIdentity)
    }

    /// Mutes or hides `event`; for a recurring event, `wholeSeries` picks the
    /// whole series instead of this occurrence.
    func setOverride(_ action: EventOverrideAction, for event: EKEvent, wholeSeries: Bool) {
        guard let identity = event.candidateIdentity else { return }
        var overrides = eventOverrides
        overrides.set(
            action,
            for: identity,
            wholeSeries: wholeSeries,
            title: event.title ?? "",
            endDate: event.endDate ?? identity.occurrenceDate
        )
        applyOverrides(overrides)
    }

    /// Clears every mute or hide that applies to `event`.
    func restoreEvent(_ event: EKEvent) {
        guard let identity = event.candidateIdentity else { return }
        var overrides = eventOverrides
        overrides.restore(identity)
        applyOverrides(overrides)
    }

    /// Restores one entry from the Preferences list.
    func removeOverride(id: String) {
        var overrides = eventOverrides
        overrides.remove(id: id)
        applyOverrides(overrides)
    }

    private func applyOverrides(_ overrides: EventOverrides) {
        var pruned = overrides
        pruned.prune(now: Date())
        eventOverrides = pruned
        defaults.set(pruned.isEmpty ? nil : pruned.encoded(), forKey: eventOverridesKey)
    }

    func isCalendarEnabled(_ calendarID: String) -> Bool {
        return enabledCalendarIDs.contains(calendarID)
    }

    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    completion(granted, error)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    completion(granted, error)
                }
            }
        }
    }

    @discardableResult
    func refreshAuthorizationStatus() -> Bool {
        let status = eventStore.authorizationStatus(for: .event)
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = status == .fullAccess || status == .authorized
        } else {
            granted = status == .authorized
        }

        hasCalendarAccess = granted
        if !granted {
            nextEvent = nil
            upcomingEvents = []
            allUpcomingEvents = []
            activeEvents = []
        }

        return granted
    }

    func startObservingChanges(_ handler: @escaping () -> Void) {
        stopObservingChanges()
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore.notificationObject,
            // EventKit may post this notification from a background thread. The
            // caller refreshes observable state and AppKit lifecycle objects, so
            // keep the whole refresh entry point main-thread confined.
            queue: .main
        ) { _ in
            handler()
        }
    }

    func stopObservingChanges() {
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
            eventStoreChangedObserver = nil
        }
    }

    deinit {
        stopObservingChanges()
    }

    func fetchNextEvent(completion: @escaping (EKEvent?) -> Void) {
        guard hasCalendarAccess else {
            completion(nil)
            return
        }
        let enabledCalendarIDs = self.enabledCalendarIDs
        let hasCustomCalendarSelection = self.hasCustomCalendarSelection
        let lookaheadDays = self.lookaheadDays
        let maxEventsToShow = self.maxEventsToShow
        let hideAllDayEvents = self.hideAllDayEvents
        let hideDeclinedEvents = self.hideDeclinedEvents
        let filterKeywords = self.filterKeywords
        let eventOverrides = self.eventOverrides
        let badgeOnlyCalendarIDs = self.badgeOnlyCalendarIDs

        fetchQueue.async { [weak self] in
            guard let self = self else { return }

            let refreshStarted = Date()
            // Get calendars based on user's enabled selections
            let allCalendars = self.eventStore.calendars(for: .event)
            let calendars: [EKCalendar]

            if enabledCalendarIDs.isEmpty {
                if hasCustomCalendarSelection {
                    calendars = []
                } else {
                    // First launch (no selection yet): use all calendars
                    calendars = allCalendars
                }
            } else {
                // Filter to only enabled calendars
                calendars = allCalendars.filter { calendar in
                    enabledCalendarIDs.contains(calendar.calendarIdentifier)
                }
            }

            guard !calendars.isEmpty else {
                DispatchQueue.main.async {
                    self.nextEvent = nil
                    self.upcomingEvents = []
                    self.allUpcomingEvents = []
                    self.activeEvents = []
                    completion(nil)
                }
                return
            }

            // Get current time
            let now = Date()

            // Create start and end dates - look ahead based on user preference
            let calendar = Calendar.autoupdatingCurrent
            guard let endDate = calendar.date(byAdding: .day, value: lookaheadDays, to: now) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Create predicate for events in the next N days
            let predicate = self.eventStore.predicateForEvents(
                withStart: now,
                end: endDate,
                calendars: calendars
            )

            // Fetch events
            let events: [EKEvent]
            do {
                let fetched = try self.eventStore.events(matching: predicate)
                events = Self.deduplicated(
                    fetched,
                    calendars: calendars,
                    badgeOnlyCalendarIDs: badgeOnlyCalendarIDs
                )
            } catch {
                Diagnostics.record(
                    .calendarRefreshFailed(errorCode: (error as NSError).code),
                    throttleKey: "calendar.refreshFailed",
                    minInterval: 300
                )
                DispatchQueue.main.async {
                    self.nextEvent = nil
                    self.upcomingEvents = []
                    self.allUpcomingEvents = []
                    self.activeEvents = []
                    completion(nil)
                }
                return
            }

            let settings = EventFilterSettings(
                hideAllDayEvents: hideAllDayEvents,
                hideDeclinedEvents: hideDeclinedEvents,
                filterKeywords: filterKeywords,
                overrides: eventOverrides
            )
            let result = EventPipeline.filterAndSelect(
                events: events,
                now: now,
                settings: settings,
                maxEvents: maxEventsToShow,
                lateGraceMinutes: Self.kLateGraceMinutes
            )
            // The status bar refreshes every few seconds near a meeting: log a
            // refresh when the counts change, otherwise every ten minutes.
            Diagnostics.record(
                .calendarRefreshed(
                    durationMs: Int(Date().timeIntervalSince(refreshStarted) * 1000),
                    eventCount: events.count,
                    calendarCount: calendars.count
                ),
                throttleKey: "calendar.refresh.\(events.count).\(calendars.count)",
                minInterval: 600
            )

            DispatchQueue.main.async {
                self.nextEvent = result.nextEvent
                self.upcomingEvents = result.limitedEvents
                self.allUpcomingEvents = result.upcomingEvents
                self.activeEvents = result.activeEvents
                completion(result.nextEvent)
            }
        }
    }

    /// One event per meeting when the same meeting sits on two calendars
    /// (PEEK-272): popover, menu bar and notifications see it once. The
    /// PEEK-111 export reads EventKit on its own path and keeps every copy.
    static func deduplicated(
        _ events: [EKEvent],
        calendars: [EKCalendar],
        badgeOnlyCalendarIDs: Set<String>
    ) -> [EKEvent] {
        var rank: [String: Int] = [:]
        for (index, calendar) in calendars.enumerated() where rank[calendar.calendarIdentifier] == nil {
            rank[calendar.calendarIdentifier] = index
        }
        return EventDeduplicator.deduplicate(
            events,
            key: { event in
                EventDeduplicator.key(
                    title: event.title,
                    start: event.startDate,
                    end: event.endDate,
                    link: MeetingURLDetector.extract(from: event)?.absoluteString
                )
            },
            alerts: { event in
                AlertLadder.alerts(
                    calendarID: event.calendar?.calendarIdentifier,
                    badgeOnlyCalendarIDs: badgeOnlyCalendarIDs
                )
            },
            calendarRank: { event in
                event.calendar.flatMap { rank[$0.calendarIdentifier] } ?? Int.max
            }
        )
    }

    func getAllCalendars() -> [EKCalendar] {
        return fetchQueue.sync {
            eventStore.calendars(for: .event)
        }
    }

    // MARK: - Month view

    /// The calendars Peek reads: the user's selection, or every calendar before
    /// the user has chosen any.
    static func selectedCalendars(
        from allCalendars: [EKCalendar],
        enabledIDs: Set<String>,
        hasCustomSelection: Bool
    ) -> [EKCalendar] {
        if enabledIDs.isEmpty {
            return hasCustomSelection ? [] : allCalendars
        }
        return allCalendars.filter { enabledIDs.contains($0.calendarIdentifier) }
    }

    /// Start-of-day dates in `grid` that hold at least one visible event, for
    /// the month view's day markers.
    func fetchEventDays(in grid: MonthGrid, completion: @escaping (Set<Date>) -> Void) {
        fetchVisibleEvents(in: grid.interval) { events in
            var days = Set<Date>()
            for event in events {
                guard let start = event.startDate, let end = event.endDate else { continue }
                days.formUnion(MonthGrid.daysCovered(start: start, end: end, within: grid.interval))
            }
            completion(days)
        }
    }

    /// The visible events that intersect the day starting at `day`.
    func fetchEvents(on day: Date, completion: @escaping ([EKEvent]) -> Void) {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: day)
        guard let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: start) else {
            completion([])
            return
        }
        fetchVisibleEvents(in: DateInterval(start: start, end: end), completion: completion)
    }

    private func fetchVisibleEvents(in interval: DateInterval, completion: @escaping ([EKEvent]) -> Void) {
        guard hasCalendarAccess else {
            completion([])
            return
        }
        let enabledCalendarIDs = self.enabledCalendarIDs
        let hasCustomCalendarSelection = self.hasCustomCalendarSelection
        let badgeOnlyCalendarIDs = self.badgeOnlyCalendarIDs
        let settings = EventFilterSettings(
            hideAllDayEvents: hideAllDayEvents,
            hideDeclinedEvents: hideDeclinedEvents,
            filterKeywords: filterKeywords,
            overrides: eventOverrides
        )

        fetchQueue.async { [weak self] in
            guard let self = self else { return }
            let calendars = Self.selectedCalendars(
                from: self.eventStore.calendars(for: .event),
                enabledIDs: enabledCalendarIDs,
                hasCustomSelection: hasCustomCalendarSelection
            )
            var visible: [EKEvent] = []
            if !calendars.isEmpty {
                let predicate = self.eventStore.predicateForEvents(
                    withStart: interval.start,
                    end: interval.end,
                    calendars: calendars
                )
                let events = Self.deduplicated(
                    (try? self.eventStore.events(matching: predicate)) ?? [],
                    calendars: calendars,
                    badgeOnlyCalendarIDs: badgeOnlyCalendarIDs
                )
                visible = EventPipeline.visibleEvents(events, settings: settings)
            }
            DispatchQueue.main.async {
                completion(visible)
            }
        }
    }
}

// MARK: - Meeting context (PEEK-211, PEEK-213)

extension CalendarManager {
    /// Turns attendee enrichment from Contacts on or off. Turning it on asks
    /// for Contacts access the first time; a refusal leaves it off.
    func setContactsContext(enabled: Bool, contacts: SystemContactsDirectory = .shared) {
        contactsStatusMessage = nil
        guard enabled else {
            meetingContextUsesContacts = false
            return
        }
        if contacts.isAuthorized {
            meetingContextUsesContacts = true
            contacts.clearCache()
            return
        }
        if contacts.isDenied {
            meetingContextUsesContacts = false
            contactsStatusMessage = Self.contactsDeniedMessage
            return
        }
        contacts.requestAccess { [weak self] granted in
            self?.meetingContextUsesContacts = granted
            self?.contactsStatusMessage = granted ? nil : Self.contactsDeniedMessage
        }
    }

    static var contactsDeniedMessage: String {
        NSLocalizedString(
            "Contacts access is off. Allow Peek in System Settings → Privacy & Security → Contacts.",
            comment: "Contacts permission denied footnote"
        )
    }

    func setContextFolder(_ url: URL, store: ContextFolderStore = .shared) {
        if store.setFolder(url) {
            refreshContextFolderState(store: store)
        } else {
            contextFolderStatusMessage = NSLocalizedString(
                "Peek couldn't keep access to that folder. Try choosing it again.",
                comment: "Context folder bookmark failed"
            )
        }
    }

    func removeContextFolder(store: ContextFolderStore = .shared) {
        store.removeFolder()
        refreshContextFolderState(store: store)
    }

    func refreshContextFolderState(store: ContextFolderStore = .shared) {
        contextFolderName = store.folderName
        let status = store.status()
        contextFolderStatusMessage = Self.message(for: status)
        Diagnostics.record(Self.diagnostic(for: status))
    }

    static func diagnostic(for status: ContextFolderStore.Status, now: Date = Date()) -> DiagnosticEvent {
        switch status {
        case .noFolder: return .contextFile(state: .noFolder, eventCount: 0)
        case .folderUnavailable: return .contextFile(state: .folderUnavailable, eventCount: 0)
        case .fileMissing: return .contextFile(state: .fileMissing, eventCount: 0)
        case .unreadable: return .contextFile(state: .unreadable, eventCount: 0)
        case .unsupportedVersion: return .contextFile(state: .unsupportedVersion, eventCount: 0)
        case .ready(let count, let generatedAt):
            let stale = generatedAt.map { now.timeIntervalSince($0) > MeetingContextFile.staleAfter } ?? false
            return .contextFile(state: stale ? .stale : .ready, eventCount: count)
        }
    }

    /// "Today at 08:52", "23 Nov 2026 at 08:52".
    private static let generatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    static func message(for status: ContextFolderStore.Status, now: Date = Date()) -> String? {
        switch status {
        case .noFolder:
            return nil
        case .folderUnavailable:
            return NSLocalizedString("The folder is no longer available. Choose it again.", comment: "Context folder missing")
        case .fileMissing:
            return String(
                format: NSLocalizedString("No %@ in this folder yet.", comment: "Context file missing; placeholder is the file name"),
                MeetingContextFile.fileName
            )
        case .unreadable:
            return String(
                format: NSLocalizedString("%@ couldn't be read. Check that it is valid JSON.", comment: "Context file invalid; placeholder is the file name"),
                MeetingContextFile.fileName
            )
        case .unsupportedVersion(let version):
            return String(
                format: NSLocalizedString("This file uses format version %d, which this Peek doesn't support.", comment: "Context file schema version unsupported"),
                version
            )
        case .ready(let count, let generatedAt):
            guard let generatedAt else {
                return String(
                    format: NSLocalizedString("Reading context for %d events.", comment: "Context file loaded; placeholder is the number of events"),
                    count
                )
            }
            let when = generatedAtFormatter.string(from: generatedAt)
            if now.timeIntervalSince(generatedAt) > MeetingContextFile.staleAfter {
                return String(
                    format: NSLocalizedString("Reading context for %d events. Last generated %@, more than 36 hours ago, so day priorities are hidden.", comment: "Context file loaded but stale; placeholders are the number of events and when it was generated"),
                    count, when
                )
            }
            return String(
                format: NSLocalizedString("Reading context for %d events. Last generated %@.", comment: "Context file loaded; placeholders are the number of events and when it was generated"),
                count, when
            )
        }
    }
}
