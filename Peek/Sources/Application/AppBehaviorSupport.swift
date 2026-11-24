import Foundation
import AppKit
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
        meetingURLString: String?,
        prepText: String? = nil
    ) -> String {
        [
            eventID,
            String(startDate.timeIntervalSince1970),
            title ?? "",
            location ?? "",
            meetingURLString ?? "",
            prepText ?? ""
        ].joined(separator: separator)
    }

    /// The whole schedule's signature. The time zone is part of it, so a
    /// time zone change reschedules even when no event changed (PEEK-271).
    static func schedule(eventSignatures: [String], timeZone: TimeZone) -> [String] {
        ["tz:" + timeZone.identifier] + eventSignatures
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
            meetingURLString: MeetingURLDetector.extract(from: event)?.absoluteString,
            // A changed prep list reschedules the notification (PEEK-263).
            prepText: PrepSummary.text(for: event)
        )
    }
}

enum StatusItemPulsePolicy {
    static func shouldPulse(
        urgency: MeetingUrgency,
        urgencyColorsEnabled: Bool,
        reduceMotion: Bool
    ) -> Bool {
        urgency == .critical && urgencyColorsEnabled && !reduceMotion
    }
}

enum NotificationSchedulingFeedback {
    static func message(for result: NotificationSchedulingResult) -> String? {
        switch result {
        case .authorizationRequired:
            return NSLocalizedString(
                "Notifications are unavailable. Allow Peek notifications in System Settings to receive reminders.",
                comment: "Notification scheduling failure caused by denied macOS permission"
            )
        case .failed:
            return NSLocalizedString(
                "Some reminders could not be scheduled. Peek will retry shortly.",
                comment: "Notification scheduling failure that will be retried"
            )
        case .scheduled, .disabled:
            return nil
        }
    }

    static func shouldRetry(_ result: NotificationSchedulingResult) -> Bool {
        result == .failed
    }
}

struct StartingNowHUDPresentationHistory {
    private static let minimumRetention: TimeInterval = 60
    private static let maximumEntries = 256

    private var shownEventExpiryDates: [String: Date] = [:]

    var count: Int {
        shownEventExpiryDates.count
    }

    mutating func shouldPresent(eventID: String, eventEndDate: Date, now: Date) -> Bool {
        prune(now: now)
        guard shownEventExpiryDates[eventID] == nil else { return false }

        if shownEventExpiryDates.count >= Self.maximumEntries,
           let oldestEventID = shownEventExpiryDates.min(by: { $0.value < $1.value })?.key {
            shownEventExpiryDates.removeValue(forKey: oldestEventID)
        }

        let minimumExpiry = now.addingTimeInterval(Self.minimumRetention)
        shownEventExpiryDates[eventID] = max(eventEndDate, minimumExpiry)
        return true
    }

    mutating func prune(now: Date) {
        shownEventExpiryDates = shownEventExpiryDates.filter { $0.value > now }
    }

    /// Records the event as already presented without showing it, so an
    /// ignored meeting gets no further alert of this kind (PEEK-273).
    mutating func suppress(eventID: String, eventEndDate: Date, now: Date) {
        _ = shouldPresent(eventID: eventID, eventEndDate: eventEndDate, now: now)
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
        apply(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, label: hotkey.rawValue, using: registrar)
    }

    /// The join shortcut (PEEK-231); `.off` unregisters it.
    static func apply(
        _ hotkey: JoinHotkeyOption,
        using registrar: any HotkeyRegistering
    ) -> HotkeyRegistrationResult {
        guard hotkey != .off else {
            registrar.unregister()
            return .active
        }
        return apply(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, label: hotkey.rawValue, using: registrar)
    }

    static func apply(
        keyCode: UInt32,
        modifiers: UInt32,
        label: String,
        using registrar: any HotkeyRegistering
    ) -> HotkeyRegistrationResult {
        let status = registrar.register(keyCode: keyCode, modifiers: modifiers)
        guard status == noErr else {
            let message = String(
                format: NSLocalizedString(
                    "Couldn't register %@. Another app may be using this shortcut. Try a different one.",
                    comment: "Error shown when a global hotkey cannot be registered"
                ),
                label
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

/// Opens a meeting link, preferring the provider's Mac app (Zoom, Teams) when the
/// user allows it and an app is registered for the scheme; otherwise the browser.
enum MeetingLinkOpener {
    static let preferNativeAppKey = "openMeetingsInNativeApp"

    static func prefersNativeApp(_ defaults: any PreferencesStoring = UserDefaults.standard) -> Bool {
        defaults.object(forKey: preferNativeAppKey) as? Bool ?? true
    }

    /// The URL to open for `url`, or `nil` when the link is not a trusted
    /// meeting link. `canOpen` reports whether an installed app handles a URL.
    static func destination(for url: URL, preferNativeApp: Bool, canOpen: (URL) -> Bool) -> URL? {
        guard MeetingURLDetector.isURLSafe(url) else { return nil }
        if preferNativeApp, let native = MeetingProvider.nativeAppURL(for: url), canOpen(native) {
            return native
        }
        return url
    }

    static func open(_ url: URL) {
        let target = destination(
            for: url,
            preferNativeApp: prefersNativeApp(),
            canOpen: { NSWorkspace.shared.urlForApplication(toOpen: $0) != nil }
        )
        if let target {
            NSWorkspace.shared.open(target)
        }
    }
}

/// Opens a link from the context file (PEEK-262): only on an explicit click,
/// only for a scheme in `ContextLinkPolicy`. `obsidian://` hands the link to
/// the Obsidian app through Launch Services, which the sandbox allows.
enum ContextLinkOpener {
    @discardableResult
    static func open(_ url: URL, workspace: NSWorkspace = .shared) -> Bool {
        guard ContextLinkPolicy.isAllowed(url) else { return false }
        return workspace.open(url)
    }
}

/// How the app presents a meeting at its start time (PEEK-203).
enum StartAlertPresentation: Equatable {
    case none
    case hud
    case fullScreen
}

/// The alert ladder (Peek 2.0): a notification ahead of time, a heads-up card
/// 2 minutes before, then the start alert. Each step has its own level.
enum AlertLadder {
    /// The heads-up card shows when the meeting is this close.
    static let soonCardLeadTime: TimeInterval = 120

    static func isSoonCardDue(secondsUntilStart: TimeInterval) -> Bool {
        secondsUntilStart > 0 && secondsUntilStart <= soonCardLeadTime
    }

    /// With "interrupt only for meetings" on, events without a join link or
    /// attendees (a focus block, a reminder) never get the 2-minute card.
    static func interrupts(interruptOnlyForMeetings: Bool, hasJoinLink: Bool, hasAttendees: Bool) -> Bool {
        !interruptOnlyForMeetings || hasJoinLink || hasAttendees
    }

    /// Events on a badge-only calendar show in the menu bar but never notify
    /// or interrupt.
    static func alerts(calendarID: String?, badgeOnlyCalendarIDs: Set<String>) -> Bool {
        guard let calendarID else { return true }
        return !badgeOnlyCalendarIDs.contains(calendarID)
    }
}

enum StartAlertPolicy {
    /// Full screen interrupts only when the user allows it for this kind of event:
    /// with "only meetings" on, an event without a join link or attendees (a focus
    /// block, a reminder) gets the heads-up card instead.
    static func presentation(
        style: StartAlertStyle,
        interruptOnlyForMeetings: Bool,
        hasJoinLink: Bool,
        hasAttendees: Bool
    ) -> StartAlertPresentation {
        switch style {
        case .off:
            return .none
        case .hud:
            return .hud
        case .fullScreen:
            if interruptOnlyForMeetings && !hasJoinLink && !hasAttendees {
                return .hud
            }
            return .fullScreen
        }
    }

    /// Snooze delay per presentation: a full-screen alert comes back sooner.
    static func snoozeDelay(for presentation: StartAlertPresentation) -> TimeInterval {
        presentation == .fullScreen ? 60 : 300
    }
}
