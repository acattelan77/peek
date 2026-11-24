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
            prepLine: PrepSummary.text(for: event)
        )
    }
    private var snoozeWorkItem: DispatchWorkItem?

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
        // Fire only in the first minute after the start time, and only once per event.
        let started = event.startDate.timeIntervalSince(now)
        let inStartWindow = started <= 0 && started > -60
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
        present(presentation, for: event, appearanceMode: appearanceMode)
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

    func close() {
        snoozeWorkItem?.cancel()
        snoozeWorkItem = nil
        hudWindow?.close()
        hudWindow = nil
        fullScreenWindow?.close()
        fullScreenWindow = nil
    }

    private func present(_ presentation: StartAlertPresentation, for event: EKEvent, appearanceMode: AppearanceMode) {
        switch presentation {
        case .none:
            return
        case .hud:
            show(for: event, appearanceMode: appearanceMode)
        case .fullScreen:
            showFullScreen(for: event, appearanceMode: appearanceMode)
        }
    }

    private func showFullScreen(for event: EKEvent, appearanceMode: AppearanceMode) {
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
            contextLine: MeetingContextProvider.context(for: event).headline,
            briefPoints: Array((MeetingBriefService.shared.brief(for: event)?.points ?? []).prefix(MeetingBrief.heroPointLimit)),
            joinProviderLabel: providerLabel,
            appearanceMode: appearanceMode,
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
                self?.close()
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
        prepLine: String? = nil
    ) {
        close()

        let meetingURL = MeetingURLDetector.extract(from: event)
        let providerLabel = meetingURL.map { MeetingProvider.label(for: $0) }
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
            contextLine: MeetingContextProvider.context(for: event).headline,
            prepLine: prepLine,
            appearanceMode: appearanceMode,
            statusText: statusText,
            onJoin: { [weak self] in
                if let url = meetingURL {
                    MeetingLinkOpener.open(url)
                }
                self?.close()
            },
            onSnooze: snoozeAction,
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
        let work = DispatchWorkItem { [weak self] in
            self?.present(presentation, for: event, appearanceMode: appearanceMode)
        }
        snoozeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + StartAlertPolicy.snoozeDelay(for: presentation), execute: work)
    }
}

/// A borderless panel that can become key, so the full-screen alert receives
/// Return and Escape without the app's other windows.
private final class KeyableAlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
