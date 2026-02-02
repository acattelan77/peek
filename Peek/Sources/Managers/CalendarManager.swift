import Foundation
import EventKit
import Carbon
import UserNotifications

enum StatusBarDisplayMode: String, CaseIterable {
    case timeUntil = "Time Until"
    case actualTime = "Actual Time"
    case iconOnly = "Icon Only"
}

enum AppearanceMode: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"
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
            return "Disabled"
        case .fiveMinutes:
            return "5 minutes before"
        case .tenMinutes:
            return "10 minutes before"
        case .fifteenMinutes:
            return "15 minutes before"
        case .thirtyMinutes:
            return "30 minutes before"
        }
    }
}

class CalendarManager: ObservableObject {
    private static let kLateGraceMinutes = 5

    private let eventStore = EKEventStore()
    @Published var nextEvent: EKEvent?
    @Published var upcomingEvents: [EKEvent] = []
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
        } else {
            // First launch: enable all calendars by default
            let allCalendars = getAllCalendars()
            enabledCalendarIDs = Set(allCalendars.map { $0.calendarIdentifier })
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
    }

    func toggleCalendar(_ calendarID: String) {
        if enabledCalendarIDs.contains(calendarID) {
            enabledCalendarIDs.remove(calendarID)
        } else {
            enabledCalendarIDs.insert(calendarID)
        }
        saveEnabledCalendars()
    }

    func isCalendarEnabled(_ calendarID: String) -> Bool {
        return enabledCalendarIDs.contains(calendarID)
    }

    func exportSettings() -> [String: Any] {
        return [
            "enabledCalendarIDs": Array(enabledCalendarIDs),
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

    func fetchNextEvent(completion: @escaping (EKEvent?) -> Void) {
        guard hasCalendarAccess else {
            completion(nil)
            return
        }

        // Get calendars based on user's enabled selections
        let allCalendars = eventStore.calendars(for: .event)
        let calendars: [EKCalendar]

        if enabledCalendarIDs.isEmpty {
            // If no calendars are selected yet, use all calendars
            calendars = allCalendars
        } else {
            // Filter to only enabled calendars
            calendars = allCalendars.filter { calendar in
                enabledCalendarIDs.contains(calendar.calendarIdentifier)
            }
        }

        guard !calendars.isEmpty else {
            completion(nil)
            return
        }

        // Get current time
        let now = Date()

        // Create start and end dates - look ahead based on user preference
        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .day, value: lookaheadDays, to: now) else {
            completion(nil)
            return
        }

        // Create predicate for events in the next 7 days
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: calendars
        )

        // Fetch events
        let events = eventStore.events(matching: predicate)

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
            completion(nextEvent)
        }
    }

    func getAllCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }
}
