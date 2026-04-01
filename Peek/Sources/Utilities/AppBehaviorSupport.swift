import Foundation
import EventKit
import ServiceManagement

enum StatusBarRefreshPolicy {
    static let normalInterval: TimeInterval = 60
    static let urgentInterval: TimeInterval = 5

    static func interval(for urgency: MeetingUrgency) -> TimeInterval {
        switch urgency {
        case .critical, .urgent:
            return urgentInterval
        case .normal:
            return normalInterval
        }
    }
}

struct NotificationContentSignature {
    private static let separator = "\u{1F}"

    static func make(
        eventID: String,
        startDate: Date,
        title: String?,
        location: String?,
        meetingURLString: String?
    ) -> String {
        [
            eventID,
            String(startDate.timeIntervalSince1970),
            title ?? "",
            location ?? "",
            meetingURLString ?? ""
        ].joined(separator: separator)
    }

    static func make(for event: EKEvent) -> String? {
        guard let eventID = event.eventIdentifier else {
            return nil
        }

        return make(
            eventID: eventID,
            startDate: event.startDate,
            title: event.title,
            location: event.location,
            meetingURLString: MeetingURLDetector.extract(from: event)?.absoluteString
        )
    }
}

protocol LaunchAtLoginControlling {
    var currentValue: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLaunchAtLoginController: LaunchAtLoginControlling {
    var currentValue: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

struct LaunchAtLoginUpdateResult: Equatable {
    let effectiveValue: Bool
    let errorMessage: String?
}

enum LaunchAtLoginCoordinator {
    static func apply(requestedValue: Bool, controller: any LaunchAtLoginControlling) -> LaunchAtLoginUpdateResult {
        do {
            try controller.setEnabled(requestedValue)
        } catch {
            return LaunchAtLoginUpdateResult(
                effectiveValue: controller.currentValue,
                errorMessage: error.localizedDescription
            )
        }

        let effectiveValue = controller.currentValue
        guard effectiveValue != requestedValue else {
            return LaunchAtLoginUpdateResult(effectiveValue: effectiveValue, errorMessage: nil)
        }

        let errorMessage = requestedValue
            ? NSLocalizedString(
                "macOS did not enable Launch at Login for Peek.",
                comment: "Error shown when enabling launch at login does not take effect"
            )
            : NSLocalizedString(
                "macOS did not disable Launch at Login for Peek.",
                comment: "Error shown when disabling launch at login does not take effect"
            )

        return LaunchAtLoginUpdateResult(effectiveValue: effectiveValue, errorMessage: errorMessage)
    }
}
