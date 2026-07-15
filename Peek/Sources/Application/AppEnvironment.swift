import EventKit
import Foundation

protocol NotificationScheduling: AnyObject {
    func requestPermission(completion: @escaping (Bool) -> Void)
    func checkPermission(completion: @escaping (Bool) -> Void)
    func clearAllPendingNotifications()
    func scheduleNotifications(for events: [EKEvent], timing: NotificationTiming)
}

extension NotificationManager: NotificationScheduling {}

struct AppEnvironment {
    let calendarManager: CalendarManager
    let notificationScheduler: any NotificationScheduling

    static func live() -> AppEnvironment {
        AppEnvironment(
            calendarManager: CalendarManager(
                eventStore: EventKitCalendarEventStore(),
                preferencesStore: UserDefaults.standard
            ),
            notificationScheduler: NotificationManager.shared
        )
    }
}
