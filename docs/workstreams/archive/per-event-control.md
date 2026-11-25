# Workstream: per-event control

- Roadmap ID: PEEK-273
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-nslw0l`
- Last updated: 2026-11-24

## Objective

Let the user mute alerts for, hide, or ignore a single event or a whole
recurring series, as Dato and MeetingBar allow (PR 3 of the pre-release
robustness plan, https://claude.ai/artifact/SY8a1EeMdayjQe1FPkghVc).

## Scope

- Domain model `EventOverrides` (`Domain/Events/EventOverrides.swift`): mute or
  hide, scope `.event` (one-off, matched by `calendarItemIdentifier`),
  `.occurrence` (identifier plus the occurrence's original start, whole
  seconds) or `.series` (identifier). Hide wins over mute. One-off and
  occurrence entries expire at the event end and are pruned on load and on
  every change; series entries stay until restored.
- `EventCandidate.candidateIdentity` (default `nil`); `EKEvent` supplies it
  from `calendarItemIdentifier`, `occurrenceDate` and `hasRecurrenceRules`.
- `EventPipeline` drops hidden events in `filterAndSelect` and `visibleEvents`
  (popover list, month view, menu bar, join shortcut).
- `CalendarManager.eventOverrides`, persisted as JSON under `eventOverrides`;
  `alerts(for:)` combines badge-only calendars with mute/hide; `setOverride`,
  `restoreEvent`, `removeOverride(id:)`.
- `AppDelegate`: notifications and the heads-up/full-screen alerts use
  `alerts(for:)`; a change forces a refresh and a notification reschedule.
- UI: `EventOverrideMenuItems` in the row context menu and in a menu on the
  meeting page back bar; recurring events get a submenu "This Event Only" /
  "All Events in the Series"; `MutedEventIcon` (bell.slash) on muted rows and
  the next card; Preferences > Alerts "Muted and hidden events" group with
  Restore. Design-system v2 tokens only.
- Ignore: "Ignore" on the 2-minute card; the full-screen Dismiss now ignores.
  Both suppress the rest of that occurrence's ladder in memory
  (`StartingNowHUDPresentationHistory.suppress`).
- Localization in en, it, de, fr, es.
- Rebased on PEEK-275 and PEEK-271/272 (1.14.0 build 50); ships as 1.15.0 (51).

## Out of scope

- The PEEK-111 export and the context file (hidden events are still exported).
- Persisting "Ignore" across a relaunch (it lives only in the alert history).
- An "Ignore" button on the start heads-up card: its close button already
  ends that occurrence's alerts, and a fourth button does not fit the card.

## Claimed files and subsystems

- `Peek/Sources/Domain/Events/EventOverrides.swift` (new)
- `PeekTests/EventOverridesTests.swift` (new)
- Shared with the parallel PEEK-271/272/274/275 work, edited narrowly:
  `EventPipeline.swift`, `CalendarManager.swift`, `PeekApp.swift`,
  `StartingNowHUDController.swift`, `StartingNowHUD.swift`, `MenuBarView.swift`,
  `PreferencesView.swift`, `AppBehaviorSupport.swift`, Localizable.strings.

## Dependencies

- Merges after PEEK-275 (diagnostics) and PEEK-271/272 (time and
  notifications): rebase, take `main`'s version, re-bump minor, move the
  CHANGELOG entry.

## Progress

- [x] Domain model, pipeline and persistence
- [x] Alert gating (notifications, 2-minute card, start alert)
- [x] Context menu, meeting page menu, muted indicator, Preferences list
- [x] Ignore on the 2-minute card and the full-screen alert
- [x] Tests (`EventOverridesTests`, `EventOverridesCalendarManagerTests`)
- [x] Localization (5 languages), CHANGELOG, version 1.14.0 (49)

## Validation

- Linux: `bash scripts/check-version.sh`, `git diff --check`,
  `python3 scripts/check-localization.py` (288 keys in 5 tables).
- Build and tests: CI `build-and-test` on `macos-latest` (see the pull request).
  Not run locally: cloud session without Xcode.

## Owner checks on a Mac

1. Right-click a weekly meeting > Mute Alerts > This Event Only: bell-slash on
   the row, no notification, no 2-minute card, no start alert; next week's
   occurrence alerts normally.
2. Hide Event on a one-off event: it leaves the popover, month day list and
   menu bar countdown; Preferences > Alerts lists it; Restore brings it back.
3. Hide a whole series, then Show Event from Preferences.
4. On the 2-minute card press Ignore: no start alert follows. On the
   full-screen alert press Dismiss or Esc: it does not come back.
5. The join shortcut skips a hidden meeting but joins a muted one.

## Decisions and open questions

- Known limit: cross-calendar dedupe (PEEK-272) keeps one copy of a duplicated
  meeting; a choice made on the copy that was dropped does not match the kept
  one, since identities are per calendar item.
- Plan defaults applied: recurring events ask each time, "This Event Only"
  first; export untouched.
- `calendarItemIdentifier` can change after a full calendar re-sync on some
  accounts; a series choice would then need to be made again.

## Exact next action

Merge PR 23 once CI is green (owner authorized), then the owner's Mac checks
above.
