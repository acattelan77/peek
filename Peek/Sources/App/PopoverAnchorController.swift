import AppKit

/// Owns the invisible anchor window the popover is presented from. The anchor
/// is captured once, when the popover opens, and stays fixed while it is shown
/// (PEEK-282): following the live status item made the popover jump when its
/// countdown or the menu bar changed.
///
/// The popover is attached to a fresh transparent anchor window on each
/// presentation so it never reuses a stale AppKit positioning-view association.
/// Geometry comes from the click event when available and from AppKit's live
/// button frame otherwise. A WindowServer (`CGWindowList`) lookup was tried and
/// removed: on macOS 26 the private status-item window reports a 64-bit window
/// number (observed: exactly 2^32) that the window-list API cannot resolve,
/// while AppKit's frame demonstrably tracks menu-bar rearrangements live.
final class PopoverAnchorController {
    private var anchorWindow: NSPanel?
    private var anchorView: NSView?
    private var lastAnchorScreenFrame: NSRect?

    private weak var popover: NSPopover?
    private weak var button: NSStatusBarButton?

    /// Presents `popover` from a fresh anchor window at the status button's
    /// current screen position. Returns `false` when no usable frame exists
    /// and the popover was not shown.
    @discardableResult
    func show(
        popover: NSPopover,
        relativeTo button: NSStatusBarButton,
        clickDerivedButtonFrame: NSRect?
    ) -> Bool {
        button.layoutSubtreeIfNeeded()
        let appKitFrame = Self.appKitStatusButtonScreenFrame(button: button)
        // The click geometry identifies the display the user actually clicked.
        // During activation, AppKit may briefly report a status item on another display.
        let clickScreen: NSScreen? = clickDerivedButtonFrame.flatMap { _ in
            NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        }
        let liveOnClickScreen = appKitFrame.flatMap { frame -> NSRect? in
            guard let clickScreen,
                  clickScreen.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) else {
                return nil
            }
            return frame
        }
        let screenFrame = liveOnClickScreen ?? clickDerivedButtonFrame ?? appKitFrame
        guard let screenFrame else { return false }

        let anchorView = prepareAnchorWindow(buttonScreenFrame: screenFrame)
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        self.popover = popover
        self.button = button
        return true
    }

    /// Applies `PopoverPresentationPolicy.anchorFrame`: a visible popover keeps
    /// the anchor it opened with. Safe to call anytime.
    func refreshIfNeeded() {
        guard
            let popover, popover.isShown,
            let button,
            let anchorWindow
        else {
            return
        }

        button.layoutSubtreeIfNeeded()
        guard let screenFrame = Self.appKitStatusButtonScreenFrame(button: button),
              let initialFrame = lastAnchorScreenFrame else {
            return
        }

        // While visible the original anchor is authoritative, even when the
        // status item moves within the *same* display. Anchoring again here
        // caused the remaining ~75pt popover jump during countdown updates.
        let selectedFrame = PopoverPresentationPolicy.anchorFrame(
            initial: initialFrame,
            candidate: screenFrame,
            popoverIsShown: popover.isShown
        )
        guard selectedFrame != initialFrame else { return }
        lastAnchorScreenFrame = selectedFrame
        anchorWindow.setFrame(
            PopoverAnchorGeometry.anchorWindowFrame(for: selectedFrame),
            display: false
        )
    }

    /// Tears down the anchor window.
    func detach() {
        tearDownAnchorWindow()
        popover = nil
        button = nil
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
