import AppKit

struct PopoverAnchorGeometry {
    static func eventDerivedButtonFrame(
        buttonFrameInWindow: NSRect,
        eventLocationInWindow: NSPoint,
        mouseLocation: NSPoint
    ) -> NSRect {
        let actualWindowOrigin = NSPoint(
            x: mouseLocation.x - eventLocationInWindow.x,
            y: mouseLocation.y - eventLocationInWindow.y
        )
        return buttonFrameInWindow.offsetBy(
            dx: actualWindowOrigin.x,
            dy: actualWindowOrigin.y
        )
    }

    static func anchorWindowFrame(for buttonScreenFrame: NSRect) -> NSRect {
        NSRect(
            x: buttonScreenFrame.midX - 0.5,
            y: buttonScreenFrame.minY,
            width: 1,
            height: 1
        )
    }
}

/// Pure decisions for keeping a menu-bar popover stable during presentation.
/// Kept independent of NSScreen/NSPopover so display geometry is unit-testable.
enum PopoverPresentationPolicy {
    /// Never pin a status item to an unusable width (e.g. before layout).
    static func canLockStatusItemWidth(_ width: CGFloat) -> Bool {
        width.isFinite && width > 0
    }

    /// An open popover stays at the anchor captured on presentation,
    /// including when the status button drifts within the same monitor.
    static func anchorFrame(
        initial: NSRect,
        candidate: NSRect,
        popoverIsShown: Bool
    ) -> NSRect {
        popoverIsShown ? initial : candidate
    }
}
