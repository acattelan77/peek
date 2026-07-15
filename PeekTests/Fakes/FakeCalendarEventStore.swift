import EventKit
import AppKit
@testable import Peek

/// An in-memory `CalendarEventStoring` implementation for integration tests.
///
/// The fake creates real `EKCalendar` and `EKEvent` objects using a private
/// `EKEventStore` but never persists them or talks to the OS, so tests can run
/// without calendar access.
final class FakeCalendarEventStore: CalendarEventStoring {
    private let internalStore = EKEventStore()
    private var storedCalendars: [EKCalendar] = []
    private var storedEvents: [EKEvent] = []

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var requestAccessResult: (granted: Bool, error: Error?) = (false, nil)
    var requestFullAccessResult: (granted: Bool, error: Error?) = (false, nil)

    var notificationObject: AnyObject { self }

    // MARK: - Test setup

    @discardableResult
    func addCalendar(
        title: String,
        color: NSColor = .systemBlue
    ) -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: internalStore)
        calendar.title = title
        calendar.cgColor = color.cgColor
        storedCalendars.append(calendar)
        return calendar
    }

    @discardableResult
    func addEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendar: EKCalendar,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false
    ) -> EKEvent {
        let event = EKEvent(eventStore: internalStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.location = location
        event.notes = notes
        event.isAllDay = isAllDay
        storedEvents.append(event)
        return event
    }

    func removeAllEvents() {
        storedEvents.removeAll()
    }

    // MARK: - CalendarEventStoring

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        authorizationStatus
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        storedCalendars
    }

    @available(macOS 14.0, *)
    func requestFullAccessToEvents(completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            completion(self.requestFullAccessResult.granted, self.requestFullAccessResult.error)
        }
    }

    func requestAccess(
        to entityType: EKEntityType,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        DispatchQueue.main.async {
            completion(self.requestAccessResult.granted, self.requestAccessResult.error)
        }
    }

    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        // The fake ignores the predicate and returns its stored events.
        NSPredicate(value: true)
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        storedEvents
    }
}
