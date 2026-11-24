# Design system

Peek's design system is its own ("calm glance"). It is not derived from any other brand.

- **Layout reference (Peek 2.0, since 1.11.0):** the "Peek 2.0 mockup" design canvas
  (claude.ai artifact `B8Un31gdcqtookHfZvbPb2`, approved 2026-11-23): popover with compact
  month, meeting page, full-screen alert, Preferences by purpose, light and dark. Where it
  disagrees with the older handoff on layout, the canvas wins, except for the deliberate
  deviations listed in "Deviations from the Peek 2.0 mockup" below.
- **Visual reference (tokens, older screens):** the Claude Design handoff in
  `design_handoff_peek_design_system/` (tokens, onboarding, HUD, icon). Where this document and the handoff disagree on a
  **color value**, this document and the code win: several handoff hues failed WCAG AA
  and were adjusted in 1.6.0 (see "Accessibility deviations from the handoff").
- **Source of truth in code:** `Peek/Sources/Presentation/DesignSystem/`.
- **Enforcement:** `scripts/check-design-tokens.sh` (CI) blocks hardcoded colors, font sizes,
  spacing, radii, frame sizes and line widths outside the design system.
  `PeekTests/DesignSystemTests.swift` blocks contrast regressions.

## Brand idea

Peek reveals the next useful slice of a calendar. It should feel calm, immediate, and
native to macOS. Guiding principles:

- **Glanceable first:** event title, time, and join action outrank metadata.
- **One accent per row:** Peek Blue drives focus. Urgency (amber, then red) is the only
  exception, and it is always paired with a word (SOON / NOW) or an icon, never color alone.
- **Native, not neutral:** SF Pro, native switches/pickers, system focus behavior, with just
  enough personality to feel like Peek.

## Token layers

### Color: `PeekNSColor` → `PeekColor`

`PeekNSColor` (AppKit) is the only place color values are defined. `PeekColor` (SwiftUI)
wraps it one-to-one, so the status item and the SwiftUI views share one definition. Every
token resolves per appearance: light, dark, and the Increased Contrast variants.

Naming rules:

- A bare hue (`accent`, `urgent`, `critical`, `calm`) is a **fill, rail, or icon** color.
- `…Text` (`accentText`, `urgentText`, `criticalText`, `calmText`) is the readable foreground
  for that hue on Peek surfaces and washes.
- `on…` (`onAccent`, `onUrgent`, `onCritical`) is the foreground placed on a solid fill of
  that hue.
- `PeekTone` (`.accent`, `.urgent`, `.critical`, built from `MeetingUrgency`) bundles
  `fill`, `onFill`, `text`, `rail`, and `wash`. Urgency-aware components take a tone,
  never raw hues.

Brand and status:

- Peek Blue `accent` `#3B60E4` (pressed `#2E50CF`). `accentText` `#3B60E4` / dark `#7E9BF5`.
  `accentRail` `#3B60E4` / dark `#5B7DF0`. Washes: `blueTint` `#E9EEFD` / `#2A3352`,
  `nextWash` `#F1F4FE` / `#233056`.
- Urgent (2–10 min) `urgent` `#E8912B` with `onUrgent` `#1F1606` (dark text on amber).
  `urgentText` `#A45A07` / dark `#F0A54A`. `urgentWash` `#FDF2E3` / `#3A2E1C`.
- Critical (< 2 min) `critical` `#D13438` with `onCritical` white. `criticalText` `#B42A30`
  / dark `#FF8A8E`. `criticalWash` `#FCEBEC` / `#3A2427`.
- Calm `calm` `#23955A` / dark `#3CC27E` (icons). `calmText` `#1E7D4B` / dark `#5DD39A`.
- Menu-bar title tints `statusUrgent` `#A45A07` / dark `#FFB558` and `statusCritical`
  `#B42A30` / dark `#FF8A8E`. They resolve against the status button's appearance, so a
  light menu bar gets the dark tints.

Neutrals (light / dark):

- Surfaces: `surface` `#FFFFFF` / `#232428`, `canvas` `#F4F5F8` / `#1B1C1F`, `rowHoverWash`
  `#F3F4F8` / `#2C2D31`, `fill` `#F0F1F5` / white 9%, `chip` `#EDEEF2` / `#33343A`.
- Lines: `hairline` `#E7E8EE` / white 8%, `innerDivider` `#EEF0F3` / white 7%,
  `controlBorder` `#DADCE3` / `#4A4C53` (decorative), `controlStroke` `#8E929A` / `#7A7E87`
  (interactive control boundaries, 3:1). All four get stronger values under Increased
  Contrast.
- Text: `ink` `#17181C` / `#F2F3F5`, `bodyText` `#40454E` / `#C4C8CF`, `secondaryText`
  `#555A63` / `#B0B4BC`, `tertiaryText` `#676C75` / `#999EA7`. Secondary and tertiary
  step up one level under Increased Contrast.

App-icon colors (Midnight `#0B1B44`, Indigo `#1B2E7A`, coral slot `#FF6E5B`) belong to the
icon artwork only and are not UI tokens.

### Typography: `PeekFont`

SF Pro at fixed point sizes: `display` 24 bold, `onboardingTitle` 20 bold, `title` 15
semibold, `headline` 14 semibold, `rowTitle` 14 medium, `body` 13, `bodyEmphasis` and
`button` 13 semibold, `bodyMeta` 12.5, `bodyMetaMedium` 12.5 medium, `bodyMetaStrong` 12.5
semibold, `caption` 11, `captionStrong` 11 semibold, `label` 9 bold uppercase with tracking,
`mono` 12 medium monospaced.

macOS does not offer Dynamic Type to third-party apps: SwiftUI text styles have fixed sizes
on macOS. Peek therefore keeps fixed sizes, defined only in `PeekFont`, and lays text out so
that it wraps instead of clipping (`fixedSize(horizontal: false, vertical: true)` on
multi-line copy, `lineLimit` on titles).

### Icons: `PeekIcon`

SF Symbol sizes by role: `hero` 32, `emptyState` 24, `toolbar` 15, `inlineAction` 14
semibold, `dismiss` 13 medium, `meta` 12, `detail` 11, `checkmark` 11 bold, `chipRemove` 9 bold.
Decorative symbols are hidden from VoiceOver. Every icon-only button has `.help` and an
accessibility label.

### Spacing, radius, metrics

- `PeekSpacing` (4pt grid): `hairline` 1, `xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 20,
  `xxl` 24, `xxxl` 32, `huge` 40, plus `iconGap` 6 and `tightGap` 5 for icon and label pairs.
- `PeekRadius`: `rail` 2, `badge` 4, `checkbox` 5, `button` 6, `join` 7, `row` 9, `card` 10,
  `window` 12, `tile` 14, `hud` 16, `appIconLarge` 19, `pill` 999.
- `PeekMetrics`: component dimensions and insets pixel-matched to the handoff (popover
  360pt, row insets, HUD 380pt, checkbox 18pt, picker widths, focus ring, disabled opacity).
  Off-grid values are deliberate and live only here.
- `PeekElevation` (`.peekShadow(_:)`): card, popover, HUD, window, using the `shadow` token.
- `PeekDuration`: press, step, dot pulse and row pulse. Every animation is gated by Reduce
  Motion.

## Components (`PeekComponents.swift`)

- Status: `PeekBadge` (NEXT / SOON / NOW / ALL DAY), `PeekStatusPill` (HUD "STARTING NOW"),
  `CountPill`, `PulsingDot`, `PeekSectionLabel` (TODAY / TOMORROW), `PeekAvatar`.
- Containers: `InsetCard`, `InsetCardMessage`, `SettingRow`, `SettingFootnote`,
  `RowDivider`, `GroupLabel`, `PeekSectionHeader`, `PeekIconTile`, `PeekAppIcon`.
- Controls: `PrimaryButtonStyle`, `SoftAccentButtonStyle`, `SecondaryFillButtonStyle`
  (all with pressed and disabled states), `JoinButtonStyle(tone:compact:)`,
  `HeaderNavButtonStyle` (‹ Today ›), `AlertButtonStyle` (full-screen alert), `PeekToolbarButton`,
  `PeekTabButton`, `PeekSwitch`, `PeekCheckboxRow`, `PeekKeywordChip`.
- Modifiers: `.peekFocusRing(_:)` (solid and wider under Increased Contrast),
  `.peekCriticalPulse(_:)` (starts when a row turns critical while visible and stays static
  under Reduce Motion, both tracked live).
- `PeekComponents_Previews` renders the gallery in light and dark in Xcode previews.

Surfaces built on the system: the popover (`MenuBar/MenuBarView.swift`), Preferences
(`Preferences/PreferencesView.swift`), onboarding (`Onboarding/OnboardingView.swift`), and
the "Starting now" HUD (`HUD/StartingNowHUD.swift`). The menu-bar status item keeps a
monochrome template glyph and tints only the title text, with `statusUrgent` and
`statusCritical`.

## Popover layout (Peek 2.0)

Built in `MenuBar/MenuBarView.swift` and `MenuBar/MonthCalendarView.swift`, 360pt wide:

- **Header:** month title (15 semibold) over "Monday 23 · 4 meetings today" (11, secondary),
  with ‹ Today › buttons (28pt, `fill`) on the right. Without the month grid the title is
  today's date and the subtitle the meeting count. No app icon or count pill.
- **Month grid:** uppercase short weekdays (10 semibold, tracking 0.4), day numbers 12
  medium in 32pt cells, today on an accent square, past days tertiary, other months
  `mutedText` without dots, past dots muted.
- **Next-meeting card:** `nextWash` with `nextBorder` (per `PeekTone`), 3pt rail inset 10pt,
  radius 10. Eyebrow "NEXT · IN 24 MIN" (9 bold, tone text) with the time range top right;
  title 14 semibold; "You're about to meet **Marco**, CEO at Northwind, and 2 others"
  (12.5, the name in semibold ink); Join on the right; "Brief ready: N points to prepare".
- **Compact rows:** on `canvas`, grouped under TODAY / TOMORROW / weekday date. Time
  column 44pt (12, tabular), 8pt calendar dot, title 13 medium, one meta line 11
  ("Google Meet · 30 min", "Teams · 6 participants", location, or calendar). Finished
  meetings of today stay in the list at 55% opacity with "Finished".
- **Meeting page:** choosing the card or a row opens it in place: "‹ Agenda" bar, eyebrow,
  headline 18 bold that names who you meet, full-width Join, WHO YOU'RE MEETING with
  avatars, "What to prepare" card with its source pill, invitation notes, sources line.
- **Footer:** icon buttons, see below.
- **Preferences tabs:** Alerts, Briefs, Calendars, General. Tab titles are one or two
  short words and never wrap (`PeekTabButton` is single-line); the mockup's longer
  "Never miss a meeting / Arrive prepared" labels wrapped and were shortened (owner, 2026-11-24).

## Deviations from the Peek 2.0 mockup

Deliberate. A future alignment pass must keep them unless the owner changes the decision.

- **Popover footer keeps the icon buttons** (Preferences gear, Refresh, Open Calendar, and
  Quit on the right) from Peek 1.x. The mockup's text footer ("From Calendar · N calendars /
  Preferences / Open Calendar") is not used. Owner decision, 2026-11-24. The mockup canvas
  was updated to show the icon footer.
- **Alert ladder in Preferences** (one level per moment: notification, HUD, full screen) is
  not built: it changes alert behaviour. The current settings are regrouped by purpose
  instead.
- **Menu-bar item** keeps the 1.x title format and tinted text; the mockup's filled
  amber/red pills are not built.

## Rules for contributors

1. Never write a hex color, `Color.red`-style system hue, `.system(size:)`, or a numeric
   padding, spacing, radius, frame size or line width in a view. Add or reuse a token.
   `spacing: 0` is allowed.
2. Text goes on a surface or wash with a `…Text` or neutral text token. Content on a solid
   fill uses the matching `on…` token. Add a new pair to `DesignSystemTests` when you
   introduce one.
3. Urgency-aware UI takes a `PeekTone`.
4. Use the shared component before writing a new one. A pattern used twice belongs in
   `PeekComponents.swift`.
5. Run `bash scripts/check-design-tokens.sh` before pushing (CI runs it too).

## Accessibility deviations from the handoff (1.6.0)

These handoff values failed WCAG AA and were changed:

- Tertiary text `#9A9FA8` (2.4–2.7:1 on light surfaces) became `#676C75`. Secondary
  `#626770` darkened to `#555A63` to keep the hierarchy.
- White on amber (2.5:1): amber fills now carry dark text (`onUrgent`, 7.2:1).
- White on red `#E5484D` (3.9:1): the critical fill is now `#D13438` (4.9:1).
- Amber, red and green used as text on washes (2.2–3.4:1): new `urgentText`,
  `criticalText` and `calmText` roles.
- Peek Blue as text on dark surfaces (2.9:1): `accentText` uses `#7E9BF5` in dark.
- The dark `fill` was `#3234391A`, a dark grey at 10% opacity that was invisible on the dark
  surface. It is now white at 9%, per the handoff.
- Menu-bar urgency tints were light colors even on a light menu bar (about 1.7:1). They now
  adapt to the menu-bar appearance.
- Checkbox borders `#DADCE3` (1.4:1) now use `controlStroke` (3.1:1).

## App icon

- Master: `design/brand/peek-app-icon-master.png`.
- Generated set: `Peek/Resources/Assets.xcassets/AppIcon.appiconset`.
- Preserve the page fold, the single coral slot peeking from behind the calendar, and the
  indigo/blue palette.
- Never add text, numbers, a dense month grid, or traffic-light window controls.
- Verify at 16, 32, 128, and 1024 px after every change.

## Menu-bar icon

The status icon is a monochrome template image generated by `scripts/generate-assets.swift`.
It is a simplified glyph of the app icon: a calendar page outline, header mark, two binding
stubs, a lower-right fold, and a bolder next-event slot peeking behind it. Never embed color:
macOS controls template tinting for light, dark, selected, and accessibility appearances.

## Visual QA (owner, on a Mac)

- Light, dark, and Increased Contrast in both.
- Reduce Motion: the NOW dot, the critical row ring and the status-item pulse are static,
  and they switch live when the setting changes.
- A row that turns critical while the popover is open starts pulsing.
- Light menu bar: SOON/NOW title tints are readable.
- Menu bar with limited horizontal space.
- Long event, calendar, location and keyword names.
- 16 px app icon and 22 pt template icon.
