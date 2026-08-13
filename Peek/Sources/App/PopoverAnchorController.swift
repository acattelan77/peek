import AppKit

/// Owns the invisible anchor window the popover is presented from and keeps it
/// glued to Peek's live status-item position.
///
/// The popover is attached to a fresh transparent anchor window on each
/// presentation so it never reuses a stale AppKit positioning-view association.
/// Geometry comes from the click event when available and from AppKit's live
/// button frame otherwise. A WindowServer (`CGWindowList`) lookup was tried and
/// removed: on macOS 26 the private status-item window reports a 64-bit window
/// number (observed: exactly 2^32) that the window-list API cannot resolve,
/// while AppKit's frame demonstrably tracks menu-bar rearrangements live.
final class PopoverAnchorController {
    private var anchorTimer: Timer?
    private var anchorWindow: NSPanel?
    private var anchorView: NSView?
    private var lastAnchorScreenFrame: NSRect?

    private weak var popover: NSPopover?
    private weak var button: NSStatusBarButton?

    /// Presents `popover` from a fresh anchor window at the status button's
    /// current screen position and starts tracking so the anchor follows macOS
    /// menu-bar rearrangements. Returns `false` when no usable frame exists
    /// and the popover was not shown.
    @discardableResult
    func show(
        popover: NSPopover,
        relativeTo button: NSStatusBarButton,
        clickDerivedButtonFrame: NSRect?
    ) -> Bool {
        button.layoutSubtreeIfNeeded()
        guard let screenFrame = clickDerivedButtonFrame
            ?? Self.appKitStatusButtonScreenFrame(button: button)
        else {
            return false
        }

        let anchorView = prepareAnchorWindow(buttonScreenFrame: screenFrame)
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        self.popover = popover
        self.button = button
        startTracking()
        return true
    }

    /// Re-anchors a visible popover when the status item has moved; stops
    /// tracking once the popover is gone. Safe to call anytime.
    func refreshIfNeeded() {
        guard
            let popover, popover.isShown,
            let button,
            let anchorWindow,
            let anchorView
        else {
            stopTracking()
            return
        }

        button.layoutSubtreeIfNeeded()
        guard
            let screenFrame = Self.appKitStatusButtonScreenFrame(button: button),
            screenFrame != lastAnchorScreenFrame
        else {
            return
        }

        lastAnchorScreenFrame = screenFrame
        anchorWindow.setFrame(
            PopoverAnchorGeometry.anchorWindowFrame(for: screenFrame),
            display: false
        )
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    /// Stops tracking and tears down the anchor window.
    func detach() {
        stopTracking()
        tearDownAnchorWindow()
        popover = nil
        button = nil
    }

    // MARK: - Tracking

    private func startTracking() {
        stopTracking()

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.refreshIfNeeded()
        }
        anchorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Stops anchor tracking without tearing down the anchor window; used on
    /// the popover-close path where `popoverDidClose` performs the teardown.
    func stopTracking() {
        anchorTimer?.invalidate()
        anchorTimer = nil
    }

    // MARK: - Anchor window

    private func prepareAnchorWindow(buttonScreenFrame: NSRect) -> NSView {
        tearDownAnchorWindow()

        let frame = PopoverAnchorGeometry.anchorWindowFrame(for: buttonScreenFrame)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let anchorView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        anchorView.wantsLayer = true
        anchorView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = anchorView
        panel.orderFrontRegardless()

        anchorWindow = panel
        self.anchorView = anchorView
        lastAnchorScreenFrame = buttonScreenFrame
        return anchorView
    }

    private func tearDownAnchorWindow() {
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
        anchorView = nil
        lastAnchorScreenFrame = nil
    }

    // MARK: - Status button geometry

    /// Derives the button's screen frame from a mouse event. Most precise for
    /// clicks: the event location and the global mouse location pin down the
    /// actual window origin even while AppKit state is mid-rearrangement.
    static func eventDerivedButtonScreenFrame(
        button: NSStatusBarButton,
        event: NSEvent
    ) -> NSRect? {
        guard event.type == .leftMouseUp || event.type == .rightMouseUp else {
            return nil
        }

        return PopoverAnchorGeometry.eventDerivedButtonFrame(
            buttonFrameInWindow: button.convert(button.bounds, to: nil),
            eventLocationInWindow: event.locationInWindow,
            mouseLocation: NSEvent.mouseLocation
        )
    }

    static func appKitStatusButtonScreenFrame(button: NSStatusBarButton) -> NSRect? {
        guard let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
}
