# Workstream: Phase 4, join, countdown and time zones

- Roadmap ID: PEEK-231, PEEK-232, PEEK-233
- Status: In review
- Owner: Claude Code (cloud session, project thread "Pianificare Peek 2.0 per l'App Store")
- Branch/worktree: `claude/phase-4-glance-and-zones`, stacked on `claude/phase-3-ai-brief` (PR #12)
- Last updated: 2026-11-23

## Objective

Three glanceable features asked for before the App Store release: join the next
meeting from anywhere, a countdown that follows real meetings, and time zones for
teams in other countries.

## What already existed (checked before building)

- A global shortcut that opens the popover (`HotkeyOption`); no join shortcut.
- The "Time Until" countdown in the menu bar ("8m - Title") and "Hide declined
  events" in Filters (on by default). No way to skip events without a link or to
  show a person's name.
- No time-zone display (it was listed under "Next" in the roadmap).

## Scope

- PEEK-231: `JoinHotkeyOption`, a second `CarbonHotkeyRegistrar` (id 2; the
  handler now checks the pressed hotkey id), `JoinTargetPolicy`,
  `CalendarManager.activeEvents` (visible events not yet ended, including running
  ones). Registration failures show under the picker.
- PEEK-232: `StatusBarEventChooser`, `StatusBarLabelStyle`, `fullTitle` in
  `StatusBarContentBuilder` for the tooltip. The start alert and the brief keep
  following the next event, and the refresh rate follows the next event so the
  alert stays on time.
- PEEK-233: `WorldClock` (city names, sanitizing, entries, meeting ranges, day
  offsets), `WorldClockStrip` in the popover, a Time zones section in the
  expanded row, and a Time zones group in Preferences (up to six cities from a
  list of 36).

## Out of scope

- Natural-language event creation (after 2.0). Custom key recording for shortcuts.
  Localized city names (the zone identifier's city is shown in English).

## Claimed files and subsystems

- `Peek/Sources/Domain/Meetings/JoinTargetPolicy.swift`, `Peek/Sources/Domain/TimeZones/`
- `CarbonHotkeyRegistrar.swift`, `AppBehaviorSupport.swift` (`GlobalHotkeyCoordinator`),
  `AppPreferences.swift`, `EventPipeline.swift` (`activeEvents`), `CalendarManager.swift`,
  `PeekApp.swift` (status bar and join), `StatusBarContentBuilder.swift`,
  `MenuBarView.swift`, `PreferencesView.swift`, `PeekComponents.swift` (chip help),
  `PeekTheme.swift` (`worldClockMinWidth`), `*.lproj`
- `PeekTests/GlanceAndTimeZonesTests.swift`

## Dependencies

- Phase 3 (PR #12) is the base. Merge order 10, 11, 12, then this PR, each
  retargeted to `main` after its base merges.

## Validation

- Linux cloud session: `check-version.sh`, `check-design-tokens.sh`,
  `check-localization.py`, `git diff --check`.
- Build and tests run in CI only (`build-and-test` on `macos-latest`).

### Owner checks on a Mac

1. Press ⌃⌥J with a Zoom or Teams meeting starting in the next 30 minutes: it
   opens in the app. With none, the popover opens. ⌘⇧C still opens the popover
   and does not join. Set the join shortcut to Off: ⌃⌥J does nothing.
2. Turn on "Count down to meetings only" with a lunch block before a call: the
   menu bar counts down to the call; the start alert still appears for the lunch
   if its style allows. With no meeting ahead it reads "No upcoming meetings".
3. "Name in the menu bar: Who you're meeting" on a meeting with attendees shows
   "8m - Marco"; hovering shows the event title.
4. Add Dublin, New York, Shanghai, Kolkata and Tokyo in Preferences: they appear
   under the popover header and update each minute; Tokyo shows +1 in the
   evening. Expand a meeting: its time appears in each city. Remove a city.
5. VoiceOver reads each clock as one element ("Dublin, 14:05").

## Decisions and open questions

- Default join shortcut ⌃⌥J: ⌘⌥J is Chrome's JavaScript console and ⌘⇧J
  Chrome's downloads, so the default avoids both; they stay available.
- The person label uses the first attendee after removing the user and rooms.
