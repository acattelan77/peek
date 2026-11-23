import Carbon
import Foundation

enum StatusBarDisplayMode: String, CaseIterable {
    case timeUntil = "Time Until"
    case actualTime = "Actual Time"

    var displayName: String {
        switch self {
        case .timeUntil:
            return NSLocalizedString("Time Until", comment: "Status bar display mode: time remaining")
        case .actualTime:
            return NSLocalizedString("Actual Time", comment: "Status bar display mode: event start time")
        }
    }
}

enum MenuBarSpacePolicy: String, CaseIterable {
    case automatic = "Automatic"
    case alwaysShowIcon = "Always show icon"
    case alwaysShowText = "Always show text"

    var displayName: String {
        switch self {
        case .automatic:
            return NSLocalizedString("Automatic", comment: "Menu bar space policy: automatic")
        case .alwaysShowIcon:
            return NSLocalizedString("Always show icon", comment: "Menu bar space policy: always show icon")
        case .alwaysShowText:
            return NSLocalizedString("Always show text", comment: "Menu bar space policy: always show text")
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
            return 8
        case .cmdShiftP, .cmdOptionP:
            return 35
        case .cmdShiftE:
            return 14
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

/// Global shortcut that joins the next meeting (PEEK-231). J for "join".
enum JoinHotkeyOption: String, CaseIterable {
    case off = "Off"
    case ctrlOptionJ = "⌃⌥J"
    case cmdShiftJ = "⌘⇧J"
    case cmdOptionJ = "⌘⌥J"

    var displayName: String {
        self == .off ? NSLocalizedString("Off", comment: "Start alert style: off") : rawValue
    }

    var keyCode: UInt32 { 38 }

    var modifiers: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptionJ: return UInt32(controlKey | optionKey)
        case .cmdShiftJ: return UInt32(cmdKey | shiftKey)
        case .cmdOptionJ: return UInt32(cmdKey | optionKey)
        }
    }
}

/// What the menu-bar countdown names (PEEK-232).
enum StatusBarLabelStyle: String, CaseIterable {
    case eventTitle = "Event title"
    case person = "Who you're meeting"

    var displayName: String {
        switch self {
        case .eventTitle:
            return NSLocalizedString("Event title", comment: "Menu bar label: event title")
        case .person:
            return NSLocalizedString("Who you're meeting", comment: "Menu bar label: first person you're meeting")
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

/// What happens when a meeting starts (PEEK-203).
enum StartAlertStyle: String, CaseIterable {
    case off = "Off"
    case hud = "Heads-up card"
    case fullScreen = "Full screen"

    var displayName: String {
        switch self {
        case .off:
            return NSLocalizedString("Off", comment: "Start alert style: off")
        case .hud:
            return NSLocalizedString("Heads-up card", comment: "Start alert style: heads-up card")
        case .fullScreen:
            return NSLocalizedString("Full screen", comment: "Start alert style: full screen")
        }
    }
}

enum PreferenceConstraints {
    static let lookaheadDays = [1, 3, 7, 14, 30]
    static let eventLimits = [3, 5, 10, 15, 20]

    static func validLookahead(_ value: Int) -> Int? {
        lookaheadDays.contains(value) ? value : nil
    }

    static func validEventLimit(_ value: Int) -> Int? {
        eventLimits.contains(value) ? value : nil
    }
}
