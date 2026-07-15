import EventKit
@testable import Peek

/// A test double for `NotificationScheduling` that records every call so tests
/// can verify permission and scheduling behavior without using
/// `UNUserNotificationCenter`.
final class FakeNotificationScheduler: NotificationScheduling {
    var permissionGranted = false

    private(set) var requestedPermission = false
    private(set) var checkedPermission = false
    private(set) var cleared = false
    private(set) var scheduledEvents: [EKEvent] = []
    private(set) var lastTiming: NotificationTiming?

    func requestPermission(completion: @escaping (Bool) -> Void) {
        requestedPermission = true
        DispatchQueue.main.async {
            completion(self.permissionGranted)
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        checkedPermission = true
        DispatchQueue.main.async {
            completion(self.permissionGranted)
        }
    }

    func clearAllPendingNotifications() {
        cleared = true
    }

    func scheduleNotifications(for events: [EKEvent], timing: NotificationTiming) {
        scheduledEvents = events
        lastTiming = timing
    }
}
