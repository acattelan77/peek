@preconcurrency import EventKit
import Foundation

protocol CalendarEventStoring: AnyObject {
    var notificationObject: AnyObject { get }

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus

    func calendars(for entityType: EKEntityType) -> [EKCalendar]

    @available(macOS 14.0, *)
    func requestFullAccessToEvents(completion: @escaping (Bool, Error?) -> Void)

    func requestAccess(
        to entityType: EKEntityType,
        completion: @escaping (Bool, Error?) -> Void
    )

    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate

    func events(matching predicate: NSPredicate) -> [EKEvent]
}

final class EventKitCalendarEventStore: CalendarEventStoring {
    private final class CompletionBox: @unchecked Sendable {
        let completion: (Bool, Error?) -> Void

        init(_ completion: @escaping (Bool, Error?) -> Void) {
            self.completion = completion
        }
    }

    private let store: EKEventStore

    var notificationObject: AnyObject { store }

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        store.calendars(for: entityType)
    }

    @available(macOS 14.0, *)
    func requestFullAccessToEvents(completion: @escaping (Bool, Error?) -> Void) {
        let completionBox = CompletionBox(completion)
        store.requestFullAccessToEvents { granted, error in
            completionBox.completion(granted, error)
        }
    }

    func requestAccess(
        to entityType: EKEntityType,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let completionBox = CompletionBox(completion)
        store.requestAccess(to: entityType) { granted, error in
            completionBox.completion(granted, error)
        }
    }

    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        store.events(matching: predicate)
    }
}
