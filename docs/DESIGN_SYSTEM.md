# Design system

## Brand idea

Peek reveals the next useful slice of a calendar. The identity combines a calendar page, an opening/fold, and one highlighted upcoming slot. It should feel calm, immediate, and native to macOS.

## Palette

| Token | Value | Use |
| --- | --- | --- |
| Midnight | `#07102D` | Icon depth and dark surfaces |
| Indigo | `#172C82` | Primary brand field |
| Electric blue | `#245BFF` | Active controls and calendar header |
| Coral | `#FF6E5B` | Next-event accent only |
| Cloud | `#F7F8FC` | Light surfaces |

SwiftUI controls should continue to use semantic system colors for accessibility. Brand colors are accents, not replacements for `.primary`, `.secondary`, system red, or system orange.

## App icon

- Master: `design/brand/peek-app-icon-master.png`
- Generated set: `Peek/Resources/Assets.xcassets/AppIcon.appiconset`
- Preserve the page fold, single coral slot, and indigo/blue palette.
- Never add text, numbers, a dense month grid, or traffic-light window controls.
- Verify at 16, 32, 128, and 1024 px after every change.

## Menu-bar icon

The status icon is a monochrome template image generated in code. It uses a calendar outline, two bindings, and a single next-event slot. Never embed color because macOS controls template tinting for light, dark, selected, and accessibility appearances.

## UI principles

- Glanceable first: event title, time, and join action outrank metadata.
- One accent per row: calendar color or join action, not both competing at full intensity.
- Use native materials, controls, typography, focus rings, and semantic colors.
- Avoid gradients on small buttons; reserve dimensional treatment for the app icon.
- Empty and permission-denied states must explain the next action.
- Every icon-only button requires a help label and accessibility label.

## Visual QA

- Light mode and dark mode.
- Reduced motion with urgency pulsing disabled or replaced.
- Increased contrast.
- Menu bar with limited horizontal space.
- Long event, calendar, and location names.
- 16 px app icon and 22 pt template icon.
