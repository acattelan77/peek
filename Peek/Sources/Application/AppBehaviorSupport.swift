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

/// Abstraction over the platform hotkey registration API so the re-registration
/// policy can be exercised without Carbon in unit tests. Implementations perform the
/// unregister of any previous binding before registering the new one.
protocol HotkeyRegistering: AnyObject {
    /// Registers the given key combination, returning the platform status code.
    /// `noErr` (0) indicates success.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus
    func unregister()
}

/// Outcome of applying a hotkey selection, in a form the UI can present directly.
struct HotkeyRegistrationResult: Equatable {
    let isActive: Bool
    /// Non-nil when registration failed and the user should be told.
    let errorMessage: String?

    static let active = HotkeyRegistrationResult(isActive: true, errorMessage: nil)
}

/// Applies a `HotkeyOption` through a `HotkeyRegistering` seam and maps the platform
/// status into a user-presentable result.
///
/// Note: Carbon's `RegisterEventHotKey` cannot reliably report combinations already
/// claimed by other applications, so only failures the API itself returns are
/// surfaced here. That limitation is documented in the workstream and handoff.
enum GlobalHotkeyCoordinator {
    static func apply(
        _ hotkey: HotkeyOption,
        using registrar: any HotkeyRegistering
    ) -> HotkeyRegistrationResult {
        let status = registrar.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
        guard status == noErr else {
            let message = String(
                format: NSLocalizedString(
                    "Couldn't register %@. Another app may be using this shortcut. Try a different one.",
                    comment: "Error shown when a global hotkey cannot be registered"
                ),
                hotkey.rawValue
            )
            return HotkeyRegistrationResult(isActive: false, errorMessage: message)
        }
        return .active
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
