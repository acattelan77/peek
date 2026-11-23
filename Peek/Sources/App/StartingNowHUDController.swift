import SwiftUI
import AppKit
import EventKit

/// Owns the start-of-meeting alert: the "Starting now" heads-up card (top-right,
/// snoozed for five minutes) or the full-screen alert (snoozed for one minute).
/// Either fires once per event in the first minute after the start time.
final class StartingNowHUDController {
    private var hudWindow: NSPanel?
    private var fullScreenWindow: NSPanel?
    private var presentationHistory = StartingNowHUDPresentationHistory()
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
        guard presentation != .none else { return }

        // Fire only in the first minute after the start time, and only once per event.
        let started = event.startDate.timeIntervalSince(now)
        guard started <= 0, started > -60,
              presentationHistory.shouldPresent(eventID: eventID, eventEndDate: event.endDate, now: now) else { return }

        present(presentation, for: event, appearanceMode: appearanceMode)
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
        let detailParts = [
            EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate),
            providerLabel,
            event.calendar?.title
        ].compactMap { $0 }

        let alert = MeetingStartAlert(
            title: event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title"),
            startTime: DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short),
            detail: detailParts.joined(separator: " · "),
            contextLine: MeetingContextProvider.context(for: event).headline,
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

    private func show(for event: EKEvent, appearanceMode: AppearanceMode) {
        close()

        let meetingURL = MeetingURLDetector.extract(from: event)
        let providerLabel = meetingURL.map { MeetingProvider.label(for: $0) }

        let hud = StartingNowHUD(
            title: event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title"),
            timeRange: EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate),
            calendarName: event.calendar?.title,
            calendarColor: event.calendar.map { Color($0.color) },
            joinProviderLabel: providerLabel,
            contextLine: MeetingContextProvider.context(for: event).headline,
            appearanceMode: appearanceMode,
            onJoin: { [weak self] in
                if let url = meetingURL {
                    MeetingLinkOpener.open(url)
                }
                self?.close()
            },
            onSnooze: { [weak self] in
                self?.snooze(.hud, for: event, appearanceMode: appearanceMode)
            },
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
