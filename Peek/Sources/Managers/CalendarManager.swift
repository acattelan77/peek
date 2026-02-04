import Foundation
import EventKit
import Carbon
import UserNotifications

enum StatusBarDisplayMode: String, CaseIterable {
    case timeUntil = "Time Until"
    case actualTime = "Actual Time"
    case iconOnly = "Icon Only"

    var displayName: String {
        switch self {
        case .timeUntil:
            return NSLocalizedString("Time Until", comment: "Status bar display mode: time remaining")
        case .actualTime:
            return NSLocalizedString("Actual Time", comment: "Status bar display mode: event start time")
        case .iconOnly:
            return NSLocalizedString("Icon Only", comment: "Status bar display mode: icon only")
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        switch self {
        case .auto:
            return NSLocalizedString("Auto", comment: "Appearance mode: automatic")
        case .light:
            return NSLocalizedString("Light", comment: "Appearance mode: light")
        case .dark:
            return NSLocalizedString("Dark", comment: "Appearance mode: dark")
        }
    }
}

enum HotkeyOption: String, CaseIterable {
    case cmdShiftC = "⌘⇧C"
    case cmdShiftP = "⌘⇧P"
    case cmdShiftE = "⌘⇧E"
    case cmdOptionC = "⌘⌥C"
    case cmdOptionP = "⌘⌥P"

    var keyCode: UInt32 {
        switch self {
        case .cmdShiftC, .cmdOptionC:
            return 8 // C
        case .cmdShiftP, .cmdOptionP:
            return 35 // P
        case .cmdShiftE:
            return 14 // E
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .cmdShiftC, .cmdShiftP, .cmdShiftE:
            return UInt32(cmdKey | shiftKey)
        case .cmdOptionC, .cmdOptionP:
            return UInt32(cmdKey | optionKey)
        }
    }
}

enum NotificationTiming: Int, CaseIterable {
    case none = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    var displayName: String {
        switch self {
        case .none:
            return NSLocalizedString("Disabled", comment: "Notification timing: disabled")
        case .fiveMinutes:
            return NSLocalizedString("5 minutes before", comment: "Notification timing: 5 minutes before")
        case .tenMinutes:
            return NSLocalizedString("10 minutes before", comment: "Notification timing: 10 minutes before")
        case .fifteenMinutes:
            return NSLocalizedString("15 minutes before", comment: "Notification timing: 15 minutes before")
        case .thirtyMinutes:
            return NSLocalizedString("30 minutes before", comment: "Notification timing: 30 minutes before")
        }
    }
}

class CalendarManager: ObservableObject {
    private static let kLateGraceMinutes = 5

    private let eventStore = EKEventStore()
    private let fetchQueue = DispatchQueue(label: "Peek.CalendarManager.fetch")
    private var eventStoreChangedObserver: NSObjectProtocol?
    @Published var nextEvent: EKEvent?
    @Published var upcomingEvents: [EKEvent] = []
    private(set) var allUpcomingEvents: [EKEvent] = []
    private var hasCustomCalendarSelection: Bool = false
    @Published var hasCalendarAccess = false
    @Published var enabledCalendarIDs: Set<String> = []
    @Published var lookaheadDays: Int = 7
    @Published var maxEventsToShow: Int = 5
    @Published var hideAllDayEvents: Bool = false
    @Published var hideDeclinedEvents: Bool = true
    @Published var filterKeywords: String = ""
    @Published var statusBarMode: StatusBarDisplayMode = .timeUntil
    @Published var showEventCount: Bool = true
    @Published var appearanceMode: AppearanceMode = .auto
    @Published var globalHotkey: HotkeyOption = .cmdShiftC
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTiming: NotificationTiming = .fifteenMinutes
    @Published var urgencyColorsEnabled: Bool = true

    private let defaults = UserDefaults.standard
    private let enabledCalendarsKey = "enabledCalendarIDs"
    private let hasCustomCalendarsKey = "hasCustomCalendarSelection"
    private let lookaheadDaysKey = "lookaheadDays"
    private let maxEventsKey = "maxEventsToShow"
    private let hideAllDayKey = "hideAllDayEvents"
    private let hideDeclinedKey = "hideDeclinedEvents"
    private let filterKeywordsKey = "filterKeywords"
    private let statusBarModeKey = "statusBarMode"
    private let showEventCountKey = "showEventCount"
    private let appearanceModeKey = "appearanceMode"
    private let globalHotkeyKey = "globalHotkey"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationTimingKey = "notificationTiming"
    private let urgencyColorsEnabledKey = "urgencyColorsEnabled"

    init() {
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
        lookaheadDays = defaults.integer(forKey: lookaheadDaysKey)
        if lookaheadDays == 0 {
            lookaheadDays = 7 // Default
        }

        maxEventsToShow = defaults.integer(forKey: maxEventsKey)
        if maxEventsToShow == 0 {
            maxEventsToShow = 5 // Default
        }

        hideAllDayEvents = defaults.bool(forKey: hideAllDayKey)
        hideDeclinedEvents = defaults.bool(forKey: hideDeclinedKey)
        filterKeywords = defaults.string(forKey: filterKeywordsKey) ?? ""

        if let modeString = defaults.string(forKey: statusBarModeKey),
           let mode = StatusBarDisplayMode(rawValue: modeString) {
            statusBarMode = mode
        }

        showEventCount = defaults.object(forKey: showEventCountKey) as? Bool ?? true

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
    }

    func savePreferences() {
        defaults.set(lookaheadDays, forKey: lookaheadDaysKey)
        defaults.set(maxEventsToShow, forKey: maxEventsKey)
        defaults.set(hideAllDayEvents, forKey: hideAllDayKey)
        defaults.set(hideDeclinedEvents, forKey: hideDeclinedKey)
        defaults.set(filterKeywords, forKey: filterKeywordsKey)
        defaults.set(statusBarMode.rawValue, forKey: statusBarModeKey)
        defaults.set(showEventCount, forKey: showEventCountKey)
        defaults.set(appearanceMode.rawValue, forKey: appearanceModeKey)
        defaults.set(globalHotkey.rawValue, forKey: globalHotkeyKey)
        defaults.set(notificationsEnabled, forKey: notificationsEnabledKey)
        defaults.set(notificationTiming.rawValue, forKey: notificationTimingKey)
        defaults.set(urgencyColorsEnabled, forKey: urgencyColorsEnabledKey)
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

    func isCalendarEnabled(_ calendarID: String) -> Bool {
        return enabledCalendarIDs.contains(calendarID)
    }

    func exportSettings() -> [String: Any] {
        return [
            "enabledCalendarIDs": Array(enabledCalendarIDs),
            "hasCustomCalendarSelection": hasCustomCalendarSelection,
            "lookaheadDays": lookaheadDays,
            "maxEventsToShow": maxEventsToShow,
            "hideAllDayEvents": hideAllDayEvents,
            "hideDeclinedEvents": hideDeclinedEvents,
            "filterKeywords": filterKeywords,
            "statusBarMode": statusBarMode.rawValue,
            "showEventCount": showEventCount,
            "appearanceMode": appearanceMode.rawValue,
            "globalHotkey": globalHotkey.rawValue,
            "notificationsEnabled": notificationsEnabled,
            "notificationTiming": notificationTiming.rawValue,
            "urgencyColorsEnabled": urgencyColorsEnabled,
            "exportVersion": 1
        ]
    }

    func importSettings(_ settings: [String: Any]) {
        // Validate settings version
        guard let version = settings["exportVersion"] as? Int, version == 1 else {
            print("Warning: Incompatible settings version, skipping import")
            return
        }

        if let calendars = settings["enabledCalendarIDs"] as? [String] {
            enabledCalendarIDs = Set(calendars)
            hasCustomCalendarSelection = true
        }
        if let hasCustomSelection = settings["hasCustomCalendarSelection"] as? Bool {
            hasCustomCalendarSelection = hasCustomSelection
        }
        if let lookahead = settings["lookaheadDays"] as? Int {
            lookaheadDays = lookahead
        }
        if let maxEvents = settings["maxEventsToShow"] as? Int {
            maxEventsToShow = maxEvents
        }
        if let hideAllDay = settings["hideAllDayEvents"] as? Bool {
            hideAllDayEvents = hideAllDay
        }
        if let hideDeclined = settings["hideDeclinedEvents"] as? Bool {
            hideDeclinedEvents = hideDeclined
        }
        if let keywords = settings["filterKeywords"] as? String {
            filterKeywords = keywords
        }
        if let modeString = settings["statusBarMode"] as? String,
           let mode = StatusBarDisplayMode(rawValue: modeString) {
            statusBarMode = mode
        }
        if let showCount = settings["showEventCount"] as? Bool {
            showEventCount = showCount
        }
        if let appearanceString = settings["appearanceMode"] as? String,
           let appearance = AppearanceMode(rawValue: appearanceString) {
            appearanceMode = appearance
        }
        if let hotkeyString = settings["globalHotkey"] as? String,
           let hotkey = HotkeyOption(rawValue: hotkeyString) {
            globalHotkey = hotkey
        }
        if let notifEnabled = settings["notificationsEnabled"] as? Bool {
            notificationsEnabled = notifEnabled
        }
        if let timingValue = settings["notificationTiming"] as? Int,
           let timing = NotificationTiming(rawValue: timingValue) {
            notificationTiming = timing
        }
        if let colorsEnabled = settings["urgencyColorsEnabled"] as? Bool {
            urgencyColorsEnabled = colorsEnabled
        }

        // Save all imported settings
        savePreferences()
        saveEnabledCalendars()
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
        let status = EKEventStore.authorizationStatus(for: .event)
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = status == .fullAccess || status == .authorized
        } else {
            granted = status == .authorized
        }

        DispatchQueue.main.async {
            self.hasCalendarAccess = granted
            if !granted {
                self.nextEvent = nil
                self.upcomingEvents = []
                self.allUpcomingEvents = []
            }
        }

        return granted
    }

    func startObservingChanges(_ handler: @escaping () -> Void) {
        stopObservingChanges()
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
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

        fetchQueue.async { [weak self] in
            guard let self = self else { return }

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
                    completion(nil)
                }
                return
            }

            // Get current time
            let now = Date()

            // Create start and end dates - look ahead based on user preference
            let calendar = Calendar.current
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
            let events = self.eventStore.events(matching: predicate)

            // Find upcoming events (events that haven't ended yet)
            let upcoming = events.filter { event in
                // Filter out events that have ended
                guard event.endDate > now else { return false }

                // Filter all-day events if enabled
                if hideAllDayEvents && event.isAllDay {
                    return false
                }

                // Filter declined events if enabled
                if hideDeclinedEvents {
                    // Check if current user has declined this event
                    if let attendees = event.attendees {
                        for attendee in attendees where attendee.isCurrentUser {
                            if attendee.participantStatus == .declined {
                                return false
                            }
                        }
                    }
                }

                // Filter by keywords if specified
                if !filterKeywords.isEmpty {
                    let keywords = filterKeywords.lowercased().components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let titleLower = (event.title ?? "").lowercased()
                    let notesLower = (event.notes ?? "").lowercased()

                    // Event must NOT contain any of the keywords to be shown
                    for keyword in keywords where !keyword.isEmpty {
                        if titleLower.contains(keyword) || notesLower.contains(keyword) {
                            return false
                        }
                    }
                }

                return true
            }.sorted { $0.startDate < $1.startDate }

            let lateGraceInterval = TimeInterval(Self.kLateGraceMinutes * 60)
            let ongoingEvents = upcoming.filter { $0.startDate <= now && $0.endDate > now }
            let lateEvent = ongoingEvents
                .sorted { $0.startDate > $1.startDate }
                .first { now.timeIntervalSince($0.startDate) <= lateGraceInterval }
            let futureEvents = upcoming.filter { $0.startDate > now }
            let nextEvent = lateEvent ?? futureEvents.first
            let limitedEvents = Array(upcoming.prefix(maxEventsToShow))

            DispatchQueue.main.async {
                self.nextEvent = nextEvent
                self.upcomingEvents = limitedEvents
                self.allUpcomingEvents = upcoming
                completion(nextEvent)
            }
        }
    }

    func getAllCalendars() -> [EKCalendar] {
        return fetchQueue.sync {
            eventStore.calendars(for: .event)
        }
    }
}
