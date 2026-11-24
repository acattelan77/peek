import Foundation
import UserNotifications
import EventKit
import AppKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var hasNotificationPermission = false
    private let eventNotificationIdentifierPrefix = "event:"
    private let eventIDKey = "eventID"
    private let snoozeFlagKey = "isSnooze"
    private let eventCategoryIdentifier = "EVENT_NOTIFICATION"

    override private init() {
        super.init()
        notificationCenter.delegate = self
        registerNotificationCategories()
    }

    /// Registers the event notification category once, up front. The Join/Snooze
    /// actions are static; the per-event meeting URL travels in `userInfo`, so there
    /// is no need to re-register categories while scheduling individual notifications.
    private func registerNotificationCategories() {
        let joinAction = UNNotificationAction(
            identifier: "JOIN_MEETING",
            title: NSLocalizedString("Join Meeting", comment: "Notification action to join meeting"),
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: String(
                format: NSLocalizedString("Snooze (%d min)", comment: "Notification action to snooze"),
                5
            ),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: eventCategoryIdentifier,
            actions: [joinAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Permission Management

    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.hasNotificationPermission = granted
                if let error = error {
                    // Only log if it's not a simple "not allowed" error
                    // This is expected during development or if user hasn't granted permission
                    print("Notification permission: \(granted ? "granted" : "denied") - \(error.localizedDescription)")
                } else if !granted {
                    print("Notification permission denied by user")
                }
                completion(granted)
            }
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized
                self.hasNotificationPermission = granted
                completion(granted)
            }
        }
    }

    // MARK: - Notification Scheduling

    func clearAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func scheduleNotifications(
        for events: [EKEvent],
        timing: NotificationTiming,
        completion: @escaping (NotificationSchedulingResult) -> Void
    ) {
        guard timing != .none else {
            removePendingEventNotifications(excludingSnoozed: true) { [weak self] in
                self?.complete(.disabled, completion: completion)
            }
            return
        }
        guard hasNotificationPermission else {
            complete(.authorizationRequired, completion: completion)
            return
        }

        removePendingEventNotifications(excludingSnoozed: true) { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let minutesBefore = TimeInterval(timing.rawValue * 60)
            let requests = events.compactMap {
                self.makeNotificationRequest(for: $0, minutesBefore: minutesBefore, now: now)
            }

            guard !requests.isEmpty else {
                self.complete(.scheduled, completion: completion)
                return
            }

            let expectedIdentifiers = Set(requests.map(\.identifier))
            let resultLock = NSLock()
            var schedulingFailed = false
            let schedulingGroup = DispatchGroup()

            for request in requests {
                schedulingGroup.enter()
                self.notificationCenter.add(request) { error in
                    if error != nil {
                        resultLock.lock()
                        schedulingFailed = true
                        resultLock.unlock()
                    }
                    schedulingGroup.leave()
                }
            }

            schedulingGroup.notify(queue: .main) {
                resultLock.lock()
                let failed = schedulingFailed
                resultLock.unlock()
                guard !failed else {
                    self.complete(.failed, completion: completion)
                    return
                }

                self.notificationCenter.getPendingNotificationRequests { pendingRequests in
                    let pendingIdentifiers = Set(pendingRequests.map(\.identifier))
                    let result: NotificationSchedulingResult = expectedIdentifiers.isSubset(of: pendingIdentifiers)
                        ? .scheduled
                        : .failed
                    self.complete(result, completion: completion)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatEventDetails(_ event: EKEvent, minutesBefore: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: event.startDate)

        let baseFormat = NSLocalizedString("Starts at %@", comment: "Notification body: start time")
        var details = String(format: baseFormat, timeString)

        if let location = event.location, !location.isEmpty {
            let withLocationFormat = NSLocalizedString("Starts at %@ • %@", comment: "Notification body: start time with location")
            details = String(format: withLocationFormat, timeString, location)
        }

        return details
    }

    /// "Starts at 10:00 • Room" and, when the context file has open points,
    /// "2 to prepare: Confirm the renewal position" on a second line (PEEK-263).
    static func body(details: String, prepText: String?) -> String {
        guard let prepText else { return details }
        return details + "\n" + prepText
    }

    private func makeNotificationRequest(
        for event: EKEvent,
        minutesBefore: TimeInterval,
        now: Date
    ) -> UNNotificationRequest? {
        guard let eventID = event.eventIdentifier else { return nil }
        guard event.startDate > now else { return nil }

        let notificationTime = event.startDate.addingTimeInterval(-minutesBefore)
        guard notificationTime > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = event.title ?? NSLocalizedString("Upcoming Event", comment: "Notification title fallback")
        content.body = Self.body(
            details: formatEventDetails(event, minutesBefore: Int(minutesBefore / 60)),
            prepText: PrepSummary.text(for: event)
        )
        content.sound = .default
        content.userInfo = [eventIDKey: eventID]

        // The category is static. Only the safe, per-event meeting URL is carried
        // in userInfo for the Join action.
        if let meetingURL = MeetingURLDetector.extract(from: event) {
            content.userInfo["meetingURL"] = meetingURL.absoluteString
            content.categoryIdentifier = eventCategoryIdentifier
        }

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notificationTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        return UNNotificationRequest(
            identifier: "\(eventNotificationIdentifierPrefix)\(eventID)",
            content: content,
            trigger: trigger
        )
    }

    private func complete(
        _ result: NotificationSchedulingResult,
        completion: @escaping (NotificationSchedulingResult) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func removePendingEventNotifications(excludingSnoozed: Bool, completion: (() -> Void)? = nil) {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }

            let identifiersToRemove = requests.compactMap { request -> String? in
                if excludingSnoozed {
                    if (request.content.userInfo[self.snoozeFlagKey] as? Bool) == true {
                        return nil
                    }
                }

                if request.identifier.hasPrefix(self.eventNotificationIdentifierPrefix) {
                    return request.identifier
                }

                if request.content.userInfo[self.eventIDKey] != nil {
                    return request.identifier
                }

                return nil
            }

            if !identifiersToRemove.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            }

            completion?()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "JOIN_MEETING":
            if let urlString = userInfo["meetingURL"] as? String,
               let url = URL(string: urlString) {
                MeetingLinkOpener.open(url)
            }

        case "SNOOZE":
            // Reschedule notification for 5 minutes later
            guard let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent else {
                completionHandler()
                return
            }
            var userInfo = content.userInfo
            userInfo[self.snoozeFlagKey] = true
            content.userInfo = userInfo
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request)

        default:
            break
        }

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
