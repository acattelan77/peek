# Workstream: time and notification robustness

- Roadmap ID: PEEK-271, PEEK-272
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-we1l31`
- Last updated: 2026-11-24

## Objective

A Peek alert fires at the right instant, once, across sleep, time zone, DST,
clock and day changes, within the 64 pending notifications macOS keeps, and
once per meeting even when the meeting sits on two calendars.

## Scope

- `SystemTimeObserver` (Infrastructure, behind `SystemTimeObserving`): wake,
  `NSSystemTimeZoneDidChange` (resets the cached zone), `NSSystemClockDidChange`
  and `NSCalendarDayChanged`, debounced one second. `AppDelegate` then refreshes
  events, forces a notification reschedule, updates the menu bar and re-checks
  the card, start alert and snooze.
- Notifications: trigger components carry the time zone (absolute instant); the
  schedule signature includes the time zone; one identifier per occurrence
  (`event:<id>@<start>`), fixing recurring occurrences that replaced each other;
  at most 60 nearest requests with 4 left for snoozes; notification snoozes use an
  absolute calendar trigger; delivered reminders whose meeting started more than
  5 minutes ago are removed at each reschedule.
- Start alert: `LateStartPolicy` shows it up to 5 minutes late ("Started N min
  ago" on the card and full-screen pill). Snoozes store a wall-clock due time
  (`PendingSnooze`), fire via `asyncAfter(wallDeadline:)` and, as a backstop, the
  menu bar tick and the wake handler.
- `EventDeduplicator`: same normalized title, start, end and join link are one
  event; keeps the copy on an alerting calendar, else the first calendar. Applied
  in `CalendarManager` fetches (popover, menu bar, notifications, month view), not
  in the PEEK-111 export.
- Time-sensitive interruption level for meetings with a link or attendees.
- Static date formatters use `TimeZone.autoupdatingCurrent`.

## Out of scope

- Focus detection (`INFocusStatusCenter`) and degrading the full-screen alert to
  the card under Focus: PEEK-274 (screen-share PR) owns it, per the plan.
- The time-sensitive entitlement itself: needs App Store provisioning, documented
  in `docs/APP_STORE.md`.

## Claimed files and subsystems

- `Peek/Sources/Application/AlertTiming.swift` (new)
- `Peek/Sources/Infrastructure/Time/SystemTimeObserver.swift` (new)
- `PeekTests/AlertTimingTests.swift` (new)
- Scheduling paths in `NotificationManager.swift`, `PeekApp.swift`,
  `StartingNowHUDController.swift`, `CalendarManager.swift`; pill text in
  `MeetingStartAlert.swift`; formatter time zones in `EventTimeFormatter.swift`,
  `MenuBarView.swift`, `MonthCalendarView.swift`.

## Dependencies

- Runs in parallel with PEEK-275 (diagnostics), PEEK-273 and PEEK-274. Merge
  order: diagnostics, this, per-event control, screen share. Rebase and re-bump
  after each earlier merge.

## Progress

- [x] System time observer and forced reschedule
- [x] Absolute-instant triggers, time zone in signature, per-occurrence identifiers
- [x] 60-request limit, stale delivered cleanup, time-sensitive level
- [x] Late start alert and wall-clock snooze
- [x] Duplicate events across calendars
- [x] Tests, localization (en, it, de, fr, es), CHANGELOG, version 1.14.0 (50) after rebasing on PEEK-275 (1.13.1, 49)
- [x] Diagnostics: reschedules after a wake or time change log reason `systemTime`; start-alert skips keep the PEEK-275 log points

## Validation

- Linux: `bash scripts/check-version.sh`, `git diff --check`, plist parse of
  the project file. Build and tests ran in CI, not locally: `build-and-test` on
  `macos-latest` passed before the rebase
  (https://github.com/acattelan77/peek/actions/runs/45500523127); the rebased
  head is checked on PR #24.
- New tests in `AlertTimingTests`: Rome to New York keeps the instant; trigger
  fires at the instant; time zone in the signature; 2027-03-28 DST; midnight;
  100 events give the 60 nearest; recurring identifiers; time-sensitive only for
  meetings; late-start timing; snooze due after sleep; stale reminders; duplicate
  rules; `CalendarManager` shows a duplicated meeting once.

## Decisions and open questions

- Late start window is 5 minutes, also after a launch, not only after a wake.
- Stale delivered reminders: start more than 5 minutes ago.
- Focus default decision: time-sensitive only for meetings with a link or
  attendees (here); full screen to card under Focus is PEEK-274.

## Exact next action

Owner checks on a Mac: event in 10 minutes, change the time zone in System
Settings, the notification arrives at the right instant; close the lid for 5
minutes across a meeting start, the "Started N min ago" alert shows on opening;
the same event on two calendars gives one notification; a recurring daily
meeting notifies every day.
