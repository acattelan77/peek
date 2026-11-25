import SwiftUI
import AppKit
import EventKit

/// Owns the start-of-meeting alert: the "Starting now" heads-up card (top-right,
/// snoozed for five minutes) or the full-screen alert (snoozed for one minute).
/// Either fires once per event in the first minute after the start time.
/// The alert ladder (Peek 2.0) adds a heads-up card 2 minutes before.
final class StartingNowHUDController {
    private var hudWindow: NSPanel?
    private var fullScreenWindow: NSPanel?
    private var presentationHistory = StartingNowHUDPresentationHistory()
    private var soonHistory = StartingNowHUDPresentationHistory()

    /// The 2-minute step of the alert ladder: a heads-up card, once per event,
    /// when the meeting is 2 minutes or less away and has not started.
    func maybeShowSoon(
        for event: EKEvent,
        enabled: Bool,
        appearanceMode: AppearanceMode,
        interruptOnlyForMeetings: Bool
    ) {
        let now = Date()
        soonHistory.prune(now: now)
        guard enabled, !event.isAllDay, let eventID = event.eventIdentifier,
              fullScreenWindow == nil else { return }
        guard AlertLadder.isSoonCardDue(secondsUntilStart: event.startDate.timeIntervalSince(now)) else { return }
        guard AlertLadder.interrupts(
            interruptOnlyForMeetings: interruptOnlyForMeetings,
            hasJoinLink: MeetingURLDetector.extract(from: event) != nil,
            hasAttendees: !(event.attendees ?? []).isEmpty
        ) else { return }
        guard soonHistory.shouldPresent(eventID: eventID, eventEndDate: event.endDate, now: now) else { return }
        Self.recordShown(.soonCard, eventID: eventID)

        let minutes = max(1, Int((event.startDate.timeIntervalSince(now) / 60).rounded(.up)))
        show(
            for: event,
            appearanceMode: appearanceMode,
            statusText: String(format: NSLocalizedString("IN %d MIN", comment: "Heads-up card pill 2 minutes before a meeting"), minutes),
            allowsSnooze: false,
            allowsIgnore: true,
            prepLine: PrepSummary.text(for: event)
        )
    }
    private var snoozeWorkItem: DispatchWorkItem?
    /// The snoozed alert and its wall-clock due time (PEEK-271).
    private var pendingSnooze: (snooze: PendingSnooze, event: EKEvent, appearanceMode: AppearanceMode)?

    /// Presents the start alert once when an event reaches its start time, as a
    /// heads-up card or a full-screen alert depending on the user's preferences.
    func maybeShow(
        for event: EKEvent,
        urgency: MeetingUrgency,
        appearanceMode: AppearanceMode,
        style: StartAlertStyle = .hud,
        interruptOnlyForMeetings: Bool = true
    ) {
        let now = Date()
        presentationHistory.prune(now: now)
        guard urgency == .critical, !event.isAllDay, let eventID = event.eventIdentifier else { return }

        let presentation = StartAlertPolicy.presentation(
            style: style,
            interruptOnlyForMeetings: interruptOnlyForMeetings,
            hasJoinLink: MeetingURLDetector.extract(from: event) != nil,
            hasAttendees: !(event.attendees ?? []).isEmpty
        )
        // Fire once per event: in the first minute after the start time or,
        // after a wake or a launch, up to five minutes late as "started N min ago".
        let timing = LateStartPolicy.timing(secondsSinceStart: now.timeIntervalSince(event.startDate))
        let inStartWindow: Bool
        switch timing {
        case .startingNow, .startedMinutesAgo:
            inStartWindow = true
        case .notYet, .tooLate:
            inStartWindow = false
        }
        guard presentation != .none else {
            if inStartWindow { Self.recordSkipped(.startCard, reason: .filtered, eventID: eventID) }
            return
        }
        let kind: DiagnosticAlertKind = presentation == .fullScreen ? .startFullScreen : .startCard
        guard inStartWindow else { return }
        guard presentationHistory.shouldPresent(eventID: eventID, eventEndDate: event.endDate, now: now) else {
            Self.recordSkipped(kind, reason: .alreadyShown, eventID: eventID)
            return
        }

        Self.recordShown(kind, eventID: eventID)
        present(presentation, for: event, appearanceMode: appearanceMode, timing: timing)
    }
    /// Shows a snoozed alert whose due time has passed. Called from the menu
    /// bar tick and after a wake, so sleep cannot swallow a snooze.
    func tick(now: Date = Date()) {
        guard let pending = pendingSnooze, pending.snooze.isDue(now: now) else { return }
        pendingSnooze = nil
        snoozeWorkItem?.cancel()
        snoozeWorkItem = nil
        // A snoozed alert says how late it is, even past the late-start window.
        let minutesSinceStart = Int(now.timeIntervalSince(pending.event.startDate) / 60)
        let timing: LateStartPolicy.Timing = minutesSinceStart >= 1 ? .startedMinutesAgo(minutesSinceStart) : .startingNow
        present(pending.snooze.presentation, for: pending.event, appearanceMode: pending.appearanceMode, timing: timing)
    }

    private static func recordShown(_ kind: DiagnosticAlertKind, eventID: String) {
        Diagnostics.record(.alertShown(kind: kind, eventRef: DiagnosticEventRef.make(identifier: eventID)))
    }

    /// Skips repeat on every status-bar tick; one line per event and reason is enough.
    private static func recordSkipped(_ kind: DiagnosticAlertKind, reason: DiagnosticAlertSkipReason, eventID: String) {
        let ref = DiagnosticEventRef.make(identifier: eventID)
        Diagnostics.record(
            .alertSkipped(kind: kind, reason: reason, eventRef: ref),
            throttleKey: "alert.\(kind.rawValue).\(reason.rawValue).\(ref)",
            minInterval: 3600
        )
    }

    /// "Ignore" (PEEK-273): closes the alert, cancels any snooze and skips the
    /// rest of this occurrence's ladder (the start alert after the 2-minute card).
    func ignore(_ event: EKEvent) {
        close()
        guard let eventID = event.eventIdentifier else { return }
        let now = Date()
        soonHistory.suppress(eventID: eventID, eventEndDate: event.endDate, now: now)
        presentationHistory.suppress(eventID: eventID, eventEndDate: event.endDate, now: now)
    }

    func close() {
        snoozeWorkItem?.cancel()
        snoozeWorkItem = nil
        pendingSnooze = nil
        hudWindow?.close()
        hudWindow = nil
        fullScreenWindow?.close()
        fullScreenWindow = nil
    }

    private func present(
        _ presentation: StartAlertPresentation,
        for event: EKEvent,
        appearanceMode: AppearanceMode,
        timing: LateStartPolicy.Timing = .startingNow
    ) {
        var minutesLate: Int?
        if case .startedMinutesAgo(let minutes) = timing {
            minutesLate = minutes
        }
        // Discreet mode (PEEK-274), checked at presentation time so a snoozed
        // full-screen alert also comes back as the card.
        switch DiscreetModePolicy.startAlert(presentation, discreet: DiscreetModeController.shared.isActive) {
        case .none:
            return
        case .hud:
            show(
                for: event,
                appearanceMode: appearanceMode,
                statusText: minutesLate.map {
                    String(format: NSLocalizedString("STARTED %d MIN AGO", comment: "Heads-up card pill when a meeting started a few minutes ago, after sleep"), $0)
                }
            )
        case .fullScreen:
            showFullScreen(for: event, appearanceMode: appearanceMode, minutesLate: minutesLate)
        }
    }

    private func showFullScreen(for event: EKEvent, appearanceMode: AppearanceMode, minutesLate: Int? = nil) {
        close()

        let meetingURL = MeetingURLDetector.extract(from: event)
        let providerLabel = meetingURL.map { MeetingProvider.label(for: $0) }
        // "Zoom · 60 min" at the top right of the alert (Peek 2.0 mockup).
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailParts = [
            providerLabel ?? ((location?.isEmpty ?? true) ? nil : location),
            EventPresentation.duration(event)
        ].compactMap { $0 }

        let alert = MeetingStartAlert(
            title: event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title"),
            startTime: DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short),
            detail: detailParts.joined(separator: " · "),
            // A headline from the context file can be a long goal sentence:
            // the alert then keeps the event title as its headline (PEEK-276).
            contextLine: MeetingContextProvider.context(for: event).ownHeadline,
            briefPoints: Array((MeetingBriefService.shared.brief(for: event)?.points ?? []).prefix(MeetingBrief.heroPointLimit)),
            joinProviderLabel: providerLabel,
            appearanceMode: appearanceMode,
            minutesLate: minutesLate,
            onJoin: { [weak self] in
                if let url = meetingURL {
                    MeetingLinkOpener.open(url)
                }
                self?.close()
            },
            onSnooze: { [weak self] in
                self?.snooze(.fullScreen, for: event, appearanceMode: appearanceMode)
            },
            onDismiss: { [weak self] in
                self?.ignore(event)
            }
        )

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let panel = KeyableAlertPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hostingController = NSHostingController(rootView: alert)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
        panel.setFrame(screen.frame, display: false)
        // Above full-screen apps and on every Space, so the alert is seen wherever
        // the user is working.
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        fullScreenWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func show(
        for event: EKEvent,
        appearanceMode: AppearanceMode,
        statusText: String? = nil,
        allowsSnooze: Bool = true,
        allowsIgnore: Bool = false,
        prepLine: String? = nil
    ) {
        close()

        let discreet = DiscreetModeController.shared.isActive
        let meetingURL = MeetingURLDetector.extract(from: event)
        let providerLabel = meetingURL.map { MeetingProvider.label(for: $0) }
        var ignoreAction: (() -> Void)?
        if allowsIgnore {
            ignoreAction = { [weak self] in
                self?.ignore(event)
            }
        }
        var snoozeAction: (() -> Void)?
        if allowsSnooze {
            snoozeAction = { [weak self] in
                self?.snooze(.hud, for: event, appearanceMode: appearanceMode)
            }
        }

        let hud = StartingNowHUD(
            title: event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title"),
            timeRange: EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate),
            calendarName: event.calendar?.title,
            calendarColor: event.calendar.map { Color($0.color) },
            joinProviderLabel: providerLabel,
            contextLine: discreet ? nil : MeetingContextProvider.context(for: event).headline,
            prepLine: discreet ? nil : prepLine,
            appearanceMode: appearanceMode,
            statusText: statusText,
            onJoin: { [weak self] in
                if let url = meetingURL {
                    MeetingLinkOpener.open(url)
                }
                self?.close()
            },
            onSnooze: snoozeAction,
            onIgnore: ignoreAction,
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: hud)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController.view.layer?.isOpaque = false

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingController.view.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
        panel.setContentSize(hostingController.view.fittingSize)

        // Position top-right of the active screen. The panel is larger than the
        // card by `shadowPadding` on every side to leave room for the shadow, so
        // anchor using the card's top-right corner, not the panel's.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let inset = StartingNowHUD.shadowPadding
            let origin = NSPoint(
                x: visible.maxX - (size.width - inset) - 16,
                y: visible.maxY - (size.height - inset) - 16
            )
            panel.setFrameOrigin(origin)
        }

        hudWindow = panel
        panel.orderFrontRegardless()
    }

    private func snooze(_ presentation: StartAlertPresentation, for event: EKEvent, appearanceMode: AppearanceMode) {
        close()
        let snooze = PendingSnooze(
            eventKey: event.eventIdentifier ?? UUID().uuidString,
            presentation: presentation,
            snoozedAt: Date()
        )
        pendingSnooze = (snooze, event, appearanceMode)
        // Wall-clock deadline: it keeps counting while the Mac sleeps. The
        // menu bar tick and the wake handler call `tick` as a backstop.
        let work = DispatchWorkItem { [weak self] in
            self?.tick()
        }
        snoozeWorkItem = work
        DispatchQueue.main.asyncAfter(
            wallDeadline: .now() + StartAlertPolicy.snoozeDelay(for: presentation),
            execute: work
        )
    }
}

/// A borderless panel that can become key, so the full-screen alert receives
/// Return and Escape without the app's other windows.
private final class KeyableAlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
