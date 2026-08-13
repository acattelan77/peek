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
