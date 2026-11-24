import Carbon
import Combine
import CoreGraphics
import Foundation

// PEEK-274: discreet mode. While it is on, Peek shows only times, titles and
// the join button: briefs, day priorities, notes, attendees, context and
// Obsidian links are hidden, and the full-screen start alert becomes the
// heads-up card. It turns on by hand (popover footer, global shortcut) or by
// itself while a display is mirrored.
//
// macOS has no public API that says "this screen is being shared in a call",
// so Zoom, Meet, Teams and Slack sharing is not detected: see
// docs/workstreams/screen-share-discretion.md for the feasibility notes.

/// Why discreet mode is on.
enum DiscreetReason: Equatable {
    case manual
    case mirroring
}

/// The rules of discreet mode, free of AppKit so they can be tested.
enum DiscreetModePolicy {
    /// Manual wins; otherwise a mirrored display turns it on unless the user
    /// switched it off for the current mirroring session.
    static func reason(
        manual: Bool,
        detectsMirroring: Bool,
        displayMirrored: Bool,
        mirroringDismissed: Bool
    ) -> DiscreetReason? {
        if manual { return .manual }
        if detectsMirroring, displayMirrored, !mirroringDismissed { return .mirroring }
        return nil
    }

    /// The full-screen start alert is too visible to share: it becomes the card.
    static func startAlert(_ presentation: StartAlertPresentation, discreet: Bool) -> StartAlertPresentation {
        discreet && presentation == .fullScreen ? .hud : presentation
    }

    /// "Who you're meeting" can name a contact; the event title is shown instead.
    static func labelStyle(_ style: StatusBarLabelStyle, discreet: Bool) -> StatusBarLabelStyle {
        discreet ? .eventTitle : style
    }

    /// The one line under a title in discreet mode: the meeting provider, or
    /// the duration. Never the location, attendees or context.
    static func meta(providerLabel: String?, duration: String?) -> String {
        [providerLabel, duration].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Global shortcut that toggles discreet mode. D for "discreet".
enum DiscreetHotkeyOption: String, CaseIterable {
    case off = "Off"
    case ctrlOptionD = "⌃⌥D"
    case ctrlOptionH = "⌃⌥H"
    case ctrlOptionCmdD = "⌃⌥⌘D"

    var displayName: String {
        self == .off ? NSLocalizedString("Off", comment: "Start alert style: off") : rawValue
    }

    var keyCode: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptionD, .ctrlOptionCmdD: return 2
        case .ctrlOptionH: return 4
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptionD, .ctrlOptionH: return UInt32(controlKey | optionKey)
        case .ctrlOptionCmdD: return UInt32(controlKey | optionKey | cmdKey)
        }
    }
}

extension GlobalHotkeyCoordinator {
    /// The discreet-mode shortcut; `.off` unregisters it.
    static func apply(
        _ hotkey: DiscreetHotkeyOption,
        using registrar: any HotkeyRegistering
    ) -> HotkeyRegistrationResult {
        guard hotkey != .off else {
            registrar.unregister()
            return .active
        }
        return apply(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, label: hotkey.rawValue, using: registrar)
    }
}

/// Reads the screen-sharing signals macOS exposes publicly.
protocol ScreenShareSignalReading {
    /// True when any online display is part of a mirror set (a projector, a
    /// TV or AirPlay set to mirror).
    func isDisplayMirrored() -> Bool
}

struct LiveScreenShareSignals: ScreenShareSignalReading {
    func isDisplayMirrored() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsInMirrorSet($0) != 0 }
    }
}

/// Shared state of discreet mode. Views observe `shared`; tests build their own.
final class DiscreetModeController: ObservableObject {
    static let shared = DiscreetModeController()

    static let manualKey = "discreetModeOn"
    static let detectsMirroringKey = "discreetModeDetectsMirroring"
    static let hotkeyKey = "discreetModeHotkey"

    private let defaults: any PreferencesStoring
    private let signals: any ScreenShareSignalReading

    /// Turned on by hand. Persisted, so a restart in the middle of a
    /// presentation does not reveal anything.
    @Published var isManuallyOn: Bool {
        didSet { defaults.set(isManuallyOn, forKey: Self.manualKey) }
    }

    /// Turn on by itself while a display is mirrored. On by default.
    @Published var detectsMirroring: Bool {
        didSet { defaults.set(detectsMirroring, forKey: Self.detectsMirroringKey) }
    }

    @Published var hotkey: DiscreetHotkeyOption {
        didSet { defaults.set(hotkey.rawValue, forKey: Self.hotkeyKey) }
    }

    /// Transient result of registering the shortcut; `nil` means it is active.
    @Published var hotkeyStatusMessage: String?

    @Published private(set) var isDisplayMirrored: Bool
    /// The user switched discreet mode off while mirroring; cleared when the
    /// mirroring ends, so the next presentation is covered again.
    @Published private(set) var mirroringDismissed = false

    init(
        defaults: any PreferencesStoring = UserDefaults.standard,
        signals: any ScreenShareSignalReading = LiveScreenShareSignals()
    ) {
        self.defaults = defaults
        self.signals = signals
        isManuallyOn = defaults.bool(forKey: Self.manualKey)
        detectsMirroring = defaults.object(forKey: Self.detectsMirroringKey) as? Bool ?? true
        hotkey = defaults.string(forKey: Self.hotkeyKey).flatMap(DiscreetHotkeyOption.init(rawValue:)) ?? .ctrlOptionD
        isDisplayMirrored = signals.isDisplayMirrored()
    }

    var reason: DiscreetReason? {
        DiscreetModePolicy.reason(
            manual: isManuallyOn,
            detectsMirroring: detectsMirroring,
            displayMirrored: isDisplayMirrored,
            mirroringDismissed: mirroringDismissed
        )
    }

    var isActive: Bool { reason != nil }

    /// Footer button and shortcut: off when on (for whatever reason), on when off.
    func toggle() {
        if isActive {
            if reason == .mirroring { mirroringDismissed = true }
            isManuallyOn = false
        } else {
            isManuallyOn = true
        }
    }

    /// Re-reads the display state. Called on display changes and on the
    /// menu-bar tick, both cheap.
    func refreshSignals() {
        let mirrored = signals.isDisplayMirrored()
        if mirrored != isDisplayMirrored { isDisplayMirrored = mirrored }
        if !mirrored, mirroringDismissed { mirroringDismissed = false }
    }
}
