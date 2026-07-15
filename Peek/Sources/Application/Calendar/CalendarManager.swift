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
    @Published var showEventCount: Bool = true
    @Published var appearanceMode: AppearanceMode = .auto
    @Published var globalHotkey: HotkeyOption = .cmdShiftC
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTiming: NotificationTiming = .fifteenMinutes
    @Published var urgencyColorsEnabled: Bool = true

    /// Transient (not persisted) message describing the outcome of the most recent
    /// global-hotkey registration. `nil` means the current hotkey is active.
    @Published var hotkeyStatusMessage: String?

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
    private let showEventCountKey = "showEventCount"
    private let appearanceModeKey = "appearanceMode"
    private let globalHotkeyKey = "globalHotkey"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationTimingKey = "notificationTiming"
    private let urgencyColorsEnabledKey = "urgencyColorsEnabled"

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
        defaults.set(menuBarSpacePolicy.rawValue, forKey: menuBarSpacePolicyKey)
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
            "menuBarSpacePolicy": menuBarSpacePolicy.rawValue,
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
        if let lookahead = settings["lookaheadDays"] as? Int,
           let lookahead = PreferenceConstraints.validLookahead(lookahead) {
            lookaheadDays = lookahead
        }
        if let maxEvents = settings["maxEventsToShow"] as? Int,
           let maxEvents = PreferenceConstraints.validEventLimit(maxEvents) {
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
        if let modeString = settings["statusBarMode"] as? String {
            if modeString == "Icon Only" {
                statusBarMode = .timeUntil
                menuBarSpacePolicy = .alwaysShowIcon
            } else if let mode = StatusBarDisplayMode(rawValue: modeString) {
                statusBarMode = mode
            }
        }
        if let policyString = settings["menuBarSpacePolicy"] as? String,
           let policy = MenuBarSpacePolicy(rawValue: policyString) {
            menuBarSpacePolicy = policy
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
        }

        return granted
    }

    func startObservingChanges(_ handler: @escaping () -> Void) {
        stopObservingChanges()
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore.notificationObject,
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

            let settings = EventFilterSettings(
                hideAllDayEvents: hideAllDayEvents,
                hideDeclinedEvents: hideDeclinedEvents,
                filterKeywords: filterKeywords
            )
            let result = EventPipeline.filterAndSelect(
                events: events,
                now: now,
                settings: settings,
                maxEvents: maxEventsToShow,
                lateGraceMinutes: Self.kLateGraceMinutes
            )

            DispatchQueue.main.async {
                self.nextEvent = result.nextEvent
                self.upcomingEvents = result.limitedEvents
                self.allUpcomingEvents = result.upcomingEvents
                completion(result.nextEvent)
            }
        }
    }

    func getAllCalendars() -> [EKCalendar] {
        return fetchQueue.sync {
            eventStore.calendars(for: .event)
        }
    }
}
