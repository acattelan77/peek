import Foundation

/// The file "Export diagnostics" writes (PEEK-275). It holds the app and
/// system versions, settings as counts and switches, permission states, the
/// diagnostics journal and the saved MetricKit payloads. It never holds event
/// titles, notes, attendees, locations, links, calendar names, folder paths,
/// keywords or API keys.
struct DiagnosticsReport {
    static let formatVersion = 1

    struct Settings: Equatable {
        var notificationsEnabled: Bool
        var notificationLeadMinutes: Int
        var startAlertStyle: String
        var soonCardEnabled: Bool
        var interruptOnlyForMeetings: Bool
        var selectedCalendarCount: Int
        var badgeOnlyCalendarCount: Int
        var lookaheadDays: Int
        var statusBarMode: String
        var statusBarOnlyMeetings: Bool
        var menuBarSpacePolicy: String
        var globalHotkey: String
        var joinHotkey: String
        var worldClockCount: Int
        var contextFolderChosen: Bool
        var contactsMatching: Bool
        var showDayPriorities: Bool
        var briefsEnabled: Bool
        var briefEngine: String
    }

    struct Payload: Equatable {
        let fileName: String
        let created: Date
        let data: Data
    }

    var generatedAt: Date
    var appVersion: String
    var appBuild: String
    var bundleIdentifier: String
    var systemVersion: String
    var localeIdentifier: String
    var timeZoneIdentifier: String
    var calendarAccess: Bool
    var notificationAuthorization: String
    var pendingNotificationCount: Int?
    var settings: Settings
    var journal: [DiagnosticEntry]
    var payloads: [Payload]

    func jsonData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonObject(), options: [.prettyPrinted, .sortedKeys])
    }

    func jsonObject() -> [String: Any] {
        let iso = ISO8601DateFormatter()
        let settings = self.settings
        var object: [String: Any] = [
            "formatVersion": Self.formatVersion,
            "generatedAt": iso.string(from: generatedAt),
            "app": [
                "version": appVersion,
                "build": appBuild,
                "bundleIdentifier": bundleIdentifier
            ],
            "system": [
                "macOS": systemVersion,
                "locale": localeIdentifier,
                "timeZone": timeZoneIdentifier
            ],
            "permissions": [
                "calendarFullAccess": calendarAccess,
                "notifications": notificationAuthorization
            ],
            "settings": [
                "notificationsEnabled": settings.notificationsEnabled,
                "notificationLeadMinutes": settings.notificationLeadMinutes,
                "startAlertStyle": settings.startAlertStyle,
                "soonCardEnabled": settings.soonCardEnabled,
                "interruptOnlyForMeetings": settings.interruptOnlyForMeetings,
                "selectedCalendarCount": settings.selectedCalendarCount,
                "badgeOnlyCalendarCount": settings.badgeOnlyCalendarCount,
                "lookaheadDays": settings.lookaheadDays,
                "statusBarMode": settings.statusBarMode,
                "statusBarOnlyMeetings": settings.statusBarOnlyMeetings,
                "menuBarSpacePolicy": settings.menuBarSpacePolicy,
                "globalHotkey": settings.globalHotkey,
                "joinHotkey": settings.joinHotkey,
                "worldClockCount": settings.worldClockCount,
                "contextFolderChosen": settings.contextFolderChosen,
                "contactsMatching": settings.contactsMatching,
                "showDayPriorities": settings.showDayPriorities,
                "briefsEnabled": settings.briefsEnabled,
                "briefEngine": settings.briefEngine
            ],
            "journal": journal.map { entry -> [String: Any] in
                [
                    "date": iso.string(from: entry.date),
                    "category": entry.category.rawValue,
                    "level": entry.level.rawValue,
                    "message": entry.message
                ]
            }
        ]
        object["metricKit"] = payloads.map { payload -> [String: Any] in
            var item: [String: Any] = [
                "file": payload.fileName,
                "created": iso.string(from: payload.created)
            ]
            // MetricKit writes JSON; keep it structured when it parses.
            if let parsed = try? JSONSerialization.jsonObject(with: payload.data) {
                item["payload"] = parsed
            } else {
                item["payloadBase64"] = payload.data.base64EncodedString()
            }
            return item
        }
        if let pendingNotificationCount {
            object["pendingNotificationCount"] = pendingNotificationCount
        }
        return object
    }

    /// "Peek-diagnostics-2026-11-24-2215.json", in the Mac's time zone.
    static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Peek-diagnostics-\(formatter.string(from: date)).json"
    }
}

extension DiagnosticsReport.Settings {
    static func from(_ manager: CalendarManager, briefService: MeetingBriefService = .shared) -> Self {
        DiagnosticsReport.Settings(
            notificationsEnabled: manager.notificationsEnabled,
            notificationLeadMinutes: manager.notificationTiming.rawValue,
            startAlertStyle: String(describing: manager.startAlertStyle),
            soonCardEnabled: manager.soonCardEnabled,
            interruptOnlyForMeetings: manager.interruptOnlyForMeetings,
            selectedCalendarCount: manager.enabledCalendarIDs.count,
            badgeOnlyCalendarCount: manager.badgeOnlyCalendarIDs.count,
            lookaheadDays: manager.lookaheadDays,
            statusBarMode: String(describing: manager.statusBarMode),
            statusBarOnlyMeetings: manager.statusBarOnlyMeetings,
            menuBarSpacePolicy: String(describing: manager.menuBarSpacePolicy),
            globalHotkey: String(describing: manager.globalHotkey),
            joinHotkey: String(describing: manager.joinHotkey),
            worldClockCount: manager.worldClockZones.count,
            contextFolderChosen: manager.contextFolderName != nil,
            contactsMatching: manager.meetingContextUsesContacts,
            showDayPriorities: manager.showDayPriorities,
            briefsEnabled: briefService.isEnabled,
            briefEngine: String(describing: briefService.engineChoice)
        )
    }
}
