# Design system

> **Authoritative reference:** the Claude Design "calm glance" handoff in
> `design_handoff_peek_design_system/` (see its `README.md`). That package defines the
> final colors, type, spacing, and every screen state. This document summarizes the brand
> and records how the system is implemented in code.

## Implementation (code tokens)

The design system is expressed as a single shared token layer under
`Peek/Sources/Presentation/DesignSystem/`; every view consumes it rather than hardcoding
values:

- `PeekTheme.swift` — `PeekColor` / `PeekNSColor` (light/dark-aware brand, urgency,
  neutral, menu-bar, and text tokens), `PeekFont` (SF Pro roles), `PeekSpacing` /
  `PeekRadius` (4pt grid), and `PeekElevation` (`.peekShadow(_:)`).
- `PeekComponents.swift` — reusable pieces: `PeekBadge` (NEXT/SOON/NOW/ALL DAY),
  `CountPill`, `InsetCard` + `GroupLabel` + `SettingRow`, `PeekCheckboxRow`,
  `PeekKeywordChip`, the button styles (`PrimaryButtonStyle`, `SoftAccentButtonStyle`,
  `SecondaryFillButtonStyle`), the `PulsingDot`, and the `.peekFocusRing(_:)` modifier.
  `PeekMotion.reduceMotion` gates animation.

Surfaces built on the tokens: the popover (`MenuBar/MenuBarView.swift`), Preferences
(`Preferences/PreferencesView.swift`), first-run onboarding (`Onboarding/OnboardingView.swift`),
and the "Starting now" HUD (`HUD/StartingNowHUD.swift`). The menu-bar status item keeps a
monochrome template glyph and only tints the title text for urgency.

Primary accent is **Peek Blue `#3B60E4`**; urgency uses amber `#E8912B` then red `#E5484D`,
each always paired with a word (SOON / NOW) or icon — never color alone.

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
- Preserve the page fold, single coral slot peeking from behind the calendar, and
  indigo/blue palette.
- Never add text, numbers, a dense month grid, or traffic-light window controls.
- Verify at 16, 32, 128, and 1024 px after every change.

## Menu-bar icon

The status icon is a monochrome template image generated in code. It is a simplified glyph
of the app icon: a calendar page outline, header mark, two binding stubs, a lower-right fold,
and a bolder next-event slot peeking behind it. Never embed color because macOS controls
template tinting for light, dark, selected, and accessibility appearances.

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
