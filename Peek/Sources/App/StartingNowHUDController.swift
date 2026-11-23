import SwiftUI
import AppKit
import EventKit

/// Owns the "Starting now" heads-up card: it fires once per event in the first
/// minute after the start time, can be snoozed for five minutes, and floats
/// top-right of the active screen until dismissed.
final class StartingNowHUDController {
    private var hudWindow: NSPanel?
    private var presentationHistory = StartingNowHUDPresentationHistory()
    private var snoozeWorkItem: DispatchWorkItem?

    /// Shows the heads-up card once when an event reaches its start time.
    func maybeShow(for event: EKEvent, urgency: MeetingUrgency, appearanceMode: AppearanceMode) {
        let now = Date()
        presentationHistory.prune(now: now)
        guard urgency == .critical, !event.isAllDay, let eventID = event.eventIdentifier else { return }

        // Fire only in the first minute after the start time, and only once per event.
        let started = event.startDate.timeIntervalSince(now)
        guard started <= 0, started > -60,
              presentationHistory.shouldPresent(eventID: eventID, eventEndDate: event.endDate, now: now) else { return }

        show(for: event, appearanceMode: appearanceMode)
    }

    func close() {
        snoozeWorkItem?.cancel()
        snoozeWorkItem = nil
        hudWindow?.close()
        hudWindow = nil
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
            appearanceMode: appearanceMode,
            onJoin: { [weak self] in
                if let url = meetingURL {
                    MeetingLinkOpener.open(url)
                }
                self?.close()
            },
            onSnooze: { [weak self] in
                self?.snooze(for: event, appearanceMode: appearanceMode)
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

    private func snooze(for event: EKEvent, appearanceMode: AppearanceMode) {
        close()
        let work = DispatchWorkItem { [weak self] in
            self?.show(for: event, appearanceMode: appearanceMode)
        }
        snoozeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: work)
    }
}
