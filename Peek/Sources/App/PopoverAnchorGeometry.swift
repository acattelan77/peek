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
    static func shouldRenderStatusItem(
        popoverIsShown: Bool,
        presentationPending: Bool
    ) -> Bool {
        !popoverIsShown && !presentationPending
    }

    static func shouldAcceptAnchorRefresh(
        candidate: NSRect,
        presentationScreenFrame: NSRect?
    ) -> Bool {
        guard let screen = presentationScreenFrame else { return true }
        return screen.contains(NSPoint(x: candidate.midX, y: candidate.midY))
    }
}
