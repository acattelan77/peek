import Foundation

/// Describes whether Peek's status item is currently visible in the menu bar.
///
/// macOS hides status items when the menu bar is too crowded, especially on notched
/// displays. The window state lets the space policy react without depending on AppKit
/// details in the composition root.
enum StatusBarItemWindowState: Equatable {
    /// The item has not been laid out yet (brief launch transient).
    case notYetLaidOut
    /// macOS has hidden the item after it was previously visible.
    case hidden
    /// The item is visible with its leading (left) edge at `minX` in screen coordinates.
    case visible(minX: CGFloat)
}

/// Computes how much room Peek's status item has before macOS hides it.
enum StatusBarSpaceMetrics {
    /// Returns the available horizontal room between the item's leading edge and the
    /// menu-bar extras frontier (the notch's right edge on notched displays).
    ///
    /// - Parameters:
    ///   - windowState: Whether the item is visible, hidden, or not yet laid out.
    ///   - frontierMinX: The left boundary of the menu-bar extras area, obtained from
    ///     `NSScreen.auxiliaryTopRightArea.minX` on notched displays. `nil` when the
    ///     frontier is unknown (non-notched displays, where the front app's menus bound
    ///     the area and no public API exposes that boundary).
    ///   - generousWidth: Value to report when the item is visible but the frontier is
    ///     unknown, preserving the legacy "show text" behavior for non-notched displays.
    static func availableWidth(
        windowState: StatusBarItemWindowState,
        frontierMinX: CGFloat?,
        generousWidth: CGFloat
    ) -> CGFloat {
        switch windowState {
        case .notYetLaidOut:
            // At launch the item may not have a window yet; avoid a false collapse.
            return generousWidth
        case .hidden:
            // macOS has already hidden the item; collapse to icon so it can reappear.
            return 0
        case .visible(let minX):
            guard let frontierMinX else {
                // Non-notched display: crowding is not measurable here.
                return generousWidth
            }
            return max(0, minX - frontierMinX)
        }
    }
}
