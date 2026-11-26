# Workstream: settings as the popover's only page

- Roadmap ID: PEEK-285
- Status: Complete
- Owner: Claude Code
- Branch/worktree: `claude/project-thread-4mi65g`
- Last updated: 2026-11-26

## Objective

The gear button shows Settings alone in the popover, anchored to the menu-bar
item, instead of a sheet over the still-open calendar.

## Scope

- `PopoverPage` and `PopoverPagePolicy` (Application) decide which page shows.
- `MenuBarView` swaps the calendar for `PreferencesView`; Done saves and closes
  the popover; any other close saves too and the popover reopens on the calendar.
- The popover's hosting controller uses `.preferredContentSize` so the popover
  follows the page's width. The status item is not resized (PEEK-283).

## Out of scope

- The "Some reminders could not be scheduled" message (see open questions).

## Claimed files and subsystems

- `Peek/Sources/Application/PopoverPage.swift`, `PeekTests/PopoverPageTests.swift`
- `Peek/Sources/Presentation/MenuBar/MenuBarView.swift` (body, key handling)
- `Peek/Sources/Presentation/Preferences/PreferencesView.swift` (Done)
- `Peek/Sources/App/PeekApp.swift` (popover hosting controller only)

## Dependencies

- None.

## Progress

- [x] Settings replace the calendar in the popover.
- [x] Policy tests.

## Validation

- Linux checks: version, design tokens, localization, personal data,
  `git diff --check`. Build and 299 tests passed in CI only:
  https://github.com/acattelan77/peek/actions/runs/45899643763 (PR 6).

## Decisions and open questions

- Done closes the popover rather than returning to the calendar, so Settings
  never share the popover with the calendar.
- Not fixed here: `NotificationManager.scheduleNotifications` has no guard
  against overlapping runs. At launch several forced reschedules start; one
  run's "remove pending" can delete another run's new requests, whose
  pending-set check then reports `.failed`. Likely cause of the "Some reminders
  could not be scheduled" message with permission granted; the `add` error is
  not logged, so this is inferred from code.

## Exact next action

Owner checks in `docs/MAC_CHECKS.md` under PEEK-285.
