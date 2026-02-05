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

    override private init() {
        super.init()
        notificationCenter.delegate = self
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

    func scheduleNotifications(for events: [EKEvent], timing: NotificationTiming) {
        guard hasNotificationPermission, timing != .none else { return }
        removePendingEventNotifications(excludingSnoozed: true) { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let minutesBefore = TimeInterval(timing.rawValue * 60)

            for event in events {
                guard let eventID = event.eventIdentifier else { continue }
                let identifier = "\(self.eventNotificationIdentifierPrefix)\(eventID)"

                // Only schedule for future events that haven't started
                guard event.startDate > now else { continue }

                // Calculate notification time
                let notificationTime = event.startDate.addingTimeInterval(-minutesBefore)

                // Only schedule if notification time is in the future
                guard notificationTime > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = event.title ?? NSLocalizedString("Upcoming Event", comment: "Notification title fallback")
                content.body = formatEventDetails(event, minutesBefore: timing.rawValue)
                content.sound = .default
                content.userInfo = [self.eventIDKey: eventID]

                // Add actions if meeting URL is detected
                if let meetingURL = MeetingURLDetector.extract(from: event) {
                    content.userInfo["meetingURL"] = meetingURL.absoluteString

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
                        identifier: "EVENT_NOTIFICATION",
                        actions: [joinAction, snoozeAction],
                        intentIdentifiers: [],
                        options: []
                    )

                    notificationCenter.setNotificationCategories([category])
                    content.categoryIdentifier = "EVENT_NOTIFICATION"
                }

                // Create trigger
                let triggerDate = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: notificationTime
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                // Create request
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                // Schedule notification
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error.localizedDescription)")
                    }
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
               let url = URL(string: urlString),
               MeetingURLDetector.isURLSafe(url) {
                NSWorkspace.shared.open(url)
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
