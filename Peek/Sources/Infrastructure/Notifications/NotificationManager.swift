import Foundation
import UserNotifications
import EventKit
import AppKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var hasNotificationPermission = false
    private let eventNotificationIdentifierPrefix = NotificationPlanner.identifierPrefix
    private let eventIDKey = "eventID"
    /// The occurrence's start, so stale delivered reminders can be removed.
    private let eventStartKey = "eventStart"
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
                Diagnostics.record(.notificationPermission(granted: granted, errorCode: (error as NSError?)?.code))
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

        removeStaleDeliveredNotifications(now: Date())
        removePendingEventNotifications(excludingSnoozed: true) { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let minutesBefore = TimeInterval(timing.rawValue * 60)
            // Nearest first, within the system's 64-request limit (PEEK-272).
            let requests = self.makeNotificationRequests(
                for: events,
                minutesBefore: minutesBefore,
                now: now,
                timeZone: TimeZone.current
            )
            Diagnostics.record(.notificationsRequested(requestCount: requests.count))

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
        formatter.timeZone = .autoupdatingCurrent
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

    private func makeNotificationRequests(
        for events: [EKEvent],
        minutesBefore: TimeInterval,
        now: Date,
        timeZone: TimeZone
    ) -> [UNNotificationRequest] {
        var eventsByIdentifier: [String: EKEvent] = [:]
        let candidates: [NotificationPlanCandidate] = events.compactMap { event in
            guard let eventID = event.eventIdentifier, let startDate = event.startDate else { return nil }
            let identifier = NotificationPlanner.identifier(eventID: eventID, startDate: startDate)
            if eventsByIdentifier[identifier] == nil {
                eventsByIdentifier[identifier] = event
            }
            return NotificationPlanCandidate(
                eventID: eventID,
                startDate: startDate,
                isMeeting: MeetingURLDetector.extract(from: event) != nil || !(event.attendees ?? []).isEmpty
            )
        }
        let plan = NotificationPlanner.plan(candidates, leadTime: minutesBefore, now: now)
        return plan.compactMap { entry in
            eventsByIdentifier[entry.identifier].map {
                makeNotificationRequest(for: $0, entry: entry, minutesBefore: minutesBefore, timeZone: timeZone)
            }
        }
    }

    private func makeNotificationRequest(
        for event: EKEvent,
        entry: NotificationPlanEntry,
        minutesBefore: TimeInterval,
        timeZone: TimeZone
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = event.title ?? NSLocalizedString("Upcoming Event", comment: "Notification title fallback")
        content.body = Self.body(
            details: formatEventDetails(event, minutesBefore: Int(minutesBefore / 60)),
            prepText: PrepSummary.text(for: event)
        )
        content.sound = .default
        content.userInfo = [
            eventIDKey: entry.eventID,
            eventStartKey: entry.startDate.timeIntervalSince1970
        ]
        // Meetings with a link or attendees may break through Focus when the
        // user allows time-sensitive notifications for Peek (PEEK-272).
        content.interruptionLevel = entry.isTimeSensitive ? .timeSensitive : .active

        // The category is static. Only the safe, per-event meeting URL is carried
        // in userInfo for the Join action.
        if let meetingURL = MeetingURLDetector.extract(from: event) {
            content.userInfo["meetingURL"] = meetingURL.absoluteString
            content.categoryIdentifier = eventCategoryIdentifier
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: NotificationPlanner.triggerComponents(for: entry.fireDate, timeZone: timeZone),
            repeats: false
        )
        return UNNotificationRequest(identifier: entry.identifier, content: content, trigger: trigger)
    }

    /// Removes delivered reminders whose meeting started more than five
    /// minutes ago, such as the ones macOS delivers late after a wake.
    private func removeStaleDeliveredNotifications(now: Date) {
        notificationCenter.getDeliveredNotifications { [weak self] notifications in
            guard let self else { return }
            let stale = notifications.compactMap { notification -> String? in
                let userInfo = notification.request.content.userInfo
                guard userInfo[self.eventIDKey] != nil,
                      let start = userInfo[self.eventStartKey] as? TimeInterval,
                      NotificationPlanner.isStale(eventStart: Date(timeIntervalSince1970: start), now: now)
                else { return nil }
                return notification.request.identifier
            }
            if !stale.isEmpty {
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: stale)
            }
        }
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
            // An absolute instant, so a snooze that runs out during sleep or
            // across a time zone change still fires once at the right time.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: NotificationPlanner.triggerComponents(
                    for: Date().addingTimeInterval(300),
                    timeZone: TimeZone.current
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request)
            Diagnostics.record(.notificationSnoozed(minutes: 5))

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
