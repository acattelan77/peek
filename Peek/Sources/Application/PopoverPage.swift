import Foundation

// PEEK-285: Settings open as the popover's only page, in place of the calendar,
// anchored to the menu-bar item like the calendar. They used to open as a sheet
// over the still-visible calendar. Done saves and closes the popover; the
// popover always reopens on the calendar.

/// What the menu-bar popover shows.
enum PopoverPage: Equatable {
    case calendar
    case meeting
    case settings
}

/// The popover's navigation rules, free of SwiftUI so they can be tested.
enum PopoverPagePolicy {
    /// Settings win over an open meeting page; a meeting page wins over the calendar.
    static func page(showingSettings: Bool, hasMeeting: Bool) -> PopoverPage {
        if showingSettings { return .settings }
        return hasMeeting ? .meeting : .calendar
    }

    /// The calendar's arrow, Return and Escape keys apply only on the calendar
    /// and meeting pages; settings controls keep their own keys.
    static func calendarHandlesKeys(on page: PopoverPage) -> Bool {
        page != .settings
    }
}
