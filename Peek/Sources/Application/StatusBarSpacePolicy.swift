import Foundation

/// Decides whether Peek should show its full menu-bar text or fall back to its icon,
/// based on the user's space policy, available menu-bar width, and whether the display
/// has a notch.
struct StatusBarSpacePolicy: Equatable {
    enum Mode: Equatable {
        case automatic
        case alwaysShowIcon
        case alwaysShowText

        init(_ policy: MenuBarSpacePolicy) {
            switch policy {
            case .automatic:
                self = .automatic
            case .alwaysShowIcon:
                self = .alwaysShowIcon
            case .alwaysShowText:
                self = .alwaysShowText
            }
        }
    }

    enum Presentation: Equatable {
        case iconOnly
        case text
    }

    let mode: Mode
    private(set) var presentation: Presentation
    private let hysteresis: CGFloat

    init(mode: Mode, hysteresis: CGFloat = 8) {
        self.mode = mode
        self.hysteresis = hysteresis
        self.presentation = mode == .alwaysShowIcon ? .iconOnly : .text
    }

    init(policy: MenuBarSpacePolicy, hysteresis: CGFloat = 8) {
        self.init(mode: Mode(policy), hysteresis: hysteresis)
    }

    /// Updates the presentation decision based on the current space constraints.
    ///
    /// - Parameters:
    ///   - availableWidth: Horizontal space Peek can use before running into the screen edge or notch.
    ///   - requiredWidth: Width Peek needs to display its full icon + text content.
    ///   - notchMargin: Extra margin to reserve on notched displays so Peek falls back earlier.
    /// - Returns: The presentation to apply to the status item.
    mutating func update(
        availableWidth: CGFloat,
        requiredWidth: CGFloat,
        notchMargin: CGFloat = 0
    ) -> Presentation {
        switch mode {
        case .alwaysShowIcon:
            presentation = .iconOnly
        case .alwaysShowText:
            presentation = .text
        case .automatic:
            let crampedThreshold = requiredWidth + notchMargin
            let relaxedThreshold = crampedThreshold + hysteresis

            if presentation == .text && availableWidth < crampedThreshold {
                presentation = .iconOnly
            } else if presentation == .iconOnly && availableWidth >= relaxedThreshold {
                presentation = .text
            }
        }

        return presentation
    }
}
