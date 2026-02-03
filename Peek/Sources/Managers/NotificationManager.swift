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
                content.title = event.title ?? "Upcoming Event"
                content.body = formatEventDetails(event, minutesBefore: timing.rawValue)
                content.sound = .default
                content.userInfo = [self.eventIDKey: eventID]

                // Add actions if meeting URL is detected
                if let meetingURL = extractMeetingURL(from: event) {
                    content.userInfo["meetingURL"] = meetingURL.absoluteString

                    let joinAction = UNNotificationAction(
                        identifier: "JOIN_MEETING",
                        title: "Join Meeting",
                        options: .foreground
                    )
                    let snoozeAction = UNNotificationAction(
                        identifier: "SNOOZE",
                        title: "Snooze (5 min)",
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

        var details = "Starts at \(timeString)"

        if let location = event.location, !location.isEmpty {
            details += " • \(location)"
        }

        return details
    }

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        let patterns = [
            "https://[a-zA-Z0-9.-]+\\.zoom\\.us/j/[0-9]+",
            "https://meet\\.google\\.com/[a-z-]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.webex\\.com/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.gotomeeting\\.com/[^\\s]+",
            "https://whereby\\.com/[a-z0-9-]+",
            "https://discord\\.gg/[a-zA-Z0-9]+",
            "https://discord\\.com/[^\\s]+"
        ]

        if let notes = event.notes?.prefix(2000) {
            if let url = findURLInText(String(notes), patterns: patterns) {
                return url
            }
        }

        if let location = event.location?.prefix(500) {
            if let url = findURLInText(String(location), patterns: patterns) {
                return url
            }
        }

        if let url = event.url {
            if isURLSafe(url) {
                return url
            }
        }

        return nil
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

    private func findURLInText(_ text: String, patterns: [String]) -> URL? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString), isURLSafe(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func isURLSafe(_ url: URL) -> Bool {
        // Only allow https URLs from known meeting providers
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        // Allowlist of trusted meeting domains
        let trustedDomains = [
            "zoom.us",
            "meet.google.com",
            "teams.microsoft.com",
            "webex.com",
            "gotomeeting.com",
            "whereby.com",
            "discord.gg",
            "discord.com"
        ]

        // Check if host matches or is subdomain of trusted domains
        for domain in trustedDomains {
            if host == domain || host.hasSuffix(".\(domain)") {
                return true
            }
        }

        return false
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "JOIN_MEETING":
            if let urlString = userInfo["meetingURL"] as? String,
               let url = URL(string: urlString),
               isURLSafe(url) {
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
