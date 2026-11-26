# Changelog

This project follows Keep a Changelog conventions. Versions are released from `main`.
The version and build live in `Configuration/Version.xcconfig`; a build-only bump is
noted under the version it belongs to.

Versions 1.0 to 1.12.5 are in `docs/history/CHANGELOG-1.0-1.12.md`. When this
file grows past about 300 lines, move the oldest minor versions there.

## Unreleased

### Repository (no app change)

- CI rejects personal data: `scripts/check-personal-data.py` fails on email
  addresses outside example domains, home-directory paths, signing material,
  build outputs and terms on a hashed denylist, in tracked files and in new
  commits' authors and messages. `AGENTS.md` and the pull-request template say
  how to comply.

## 1.16.5 - 2026-11-26

### Changed

- PEEK-285: the gear button opens Settings as the popover's only page, anchored
  to the menu-bar item, instead of a sheet over the still-open calendar. Done
  saves and closes the popover; closing it any other way also keeps the changes,
  and the next click opens the calendar.

## 1.16.4 - 2026-11-26

### Fixed

- PEEK-284: the launch line in the unified log is notice level, so
  `log show --predicate 'subsystem == "com.peek.app"'` finds it after the fact.
  Other routine events stay info level, which macOS does not keep on disk: watch
  them live with `log stream --level info`, or export diagnostics.

### Repository

- Tests delete the UserDefaults suites they create. They used to call
  `removeSuite(named:)`, which leaves the plist, so every test run left
  `com.peek.app.tests.*` files in Library/Preferences.

## 1.16.3 - 2026-11-26

### Fixed

- PEEK-283: clicking Peek's menu-bar icon or label opens the popover again; only
  the keyboard shortcut worked in 1.16.2. Opening the popover no longer pins the
  status item to its current width: on recent macOS that resize swallowed the
  click. The popover still keeps the position it opened at, and the menu-bar
  label is no longer clipped while the popover is open.

## 1.16.2 - 2026-11-26

### Repository (build 56, no app change)

- Removed code the PEEK-282 fix left unused (the anchor tracking timer, the
  presentation-screen check and its tests); comments describe the fixed anchor.
- Documentation trimmed for agents: older changelog versions and the roadmap's
  Done list moved to `docs/history/`, `AGENTS.md` says what to read and when,
  and the PEEK-282 and personal-data-check workstreams are archived.

### Fixed

- Keep the menu-bar popover anchored to the position and display captured when
  it opens, even while its menu-bar countdown continues to update. Avoid jumps,
  unnecessary repositioning and repeated popover presentation on multi-monitor
  setups; allow fresh anchoring on the next opening.
- Keep the countdown in the menu bar and the popover consistent by sharing
  rounded-up minute calculations; add regression tests for fractional minutes
  and time-boundary behavior.

## 1.16.1 - 2026-11-25

### Repository (build 54, no app change)

- Removed `scripts/create-simple-dmg.sh`, a duplicate of `scripts/create-dmg.sh`
  without its error handling, and `scripts/generate-icon-master.swift`, which
  rendered the 1.3.2 icon and would overwrite the current master artwork.
- Documentation consolidated: `docs/ROADMAP.md` is the single current-state and
  priority record (replacing `docs/HANDOFF.md` and `docs/PROJECT_STATUS.md`),
  `docs/MAC_CHECKS.md` collects every pending check on a Mac, `AGENTS.md` is
  rewritten as the entry point, and finished workstreams moved to
  `docs/workstreams/archive/`. The design handoff moved to `design/handoff-v1/`.
- Peek is open source under the MIT License (`LICENSE`).
- Test fixtures, code comments and docs use fictional people and companies
  instead of real ones.

### Fixed

- PEEK-276: the meeting page no longer looks cut off with a Northwind Notes context
  file. The page title stays the event title when the headline comes from the
  context file; that headline (Northwind Notes sends the proposed goal) now opens the
  Context section. Context text from the file (headline, summary, bullets,
  people notes, day headline and priorities) starts with a capital letter, so a
  value copied from a labelled note no longer reads as a fragment. Context no
  longer repeats the bullets already shown under "What to prepare". The
  full-screen start alert also keeps the event title as its headline when the
  headline comes from the context file.
- PEEK-276: the 2-minute and "Starting now" cards keep "Join Google Meet",
  "Snooze 5 min" and "Ignore" on one line each. When they do not fit side by
  side, Join stays on the first row and the other buttons move below it.

## 1.16.0 - 2026-11-24

### Added

- PEEK-274: discreet mode for screen sharing. While it is on, the popover shows
  only times, titles and the join button: no brief, day priorities, people,
  notes, context or Obsidian links; the heads-up card drops the context and prep
  lines, the full-screen start alert becomes the card, and the menu bar names the
  event instead of a contact. Toggle it from a new eye button in the popover
  footer or with a global shortcut (⌃⌥D by default, Preferences > Briefs >
  Screen sharing); the menu-bar glyph becomes an eye while it is on. It also turns
  on by itself while a display is mirrored (projector, TV, AirPlay mirroring),
  and can be switched off for that session. macOS has no public API for Zoom,
  Meet or Teams screen sharing, so those are not detected automatically.

## 1.15.0 - 2026-11-24

### Added

- PEEK-273: per-event control. Right-click an event in the popover (or use the
  menu on the meeting page) to "Mute Alerts", which keeps it visible but stops
  its notification, 2-minute card and start alert, or "Hide Event", which
  removes it from the popover, the month view and the menu bar. A recurring
  event asks each time: "This Event Only" (listed first) or "All Events in the
  Series". Muted events show a bell-slash. "Unmute Alerts" and "Show Event"
  restore it, and Preferences > Alerts lists every muted or hidden event with
  "Restore". One-off and single-occurrence choices are pruned once the event
  ends. The join shortcut skips hidden events but not muted ones.
- PEEK-273: the 2-minute heads-up card has an "Ignore" button that closes it and
  skips that meeting's start alert. Dismissing the full-screen alert also
  ignores the meeting, so a pending snooze cannot bring it back.

### Notes

- The calendar export (PEEK-111) and the context file are unchanged: hidden
  events are still exported.

## 1.14.0 - 2026-11-24

### Fixed

- PEEK-271: after a wake, a time zone change, a clock change or midnight, Peek
  refreshes its events, reschedules every notification and re-checks the card
  and start alert. Notifications are pinned to an absolute instant, so changing
  time zone no longer moves them to the same clock time in the new zone.
- PEEK-271: a snoozed card or full-screen alert runs on the wall clock, so a
  snooze that runs out while the Mac sleeps shows at the wake.
- PEEK-271: a meeting that started less than 5 minutes before a wake or a launch
  still gets its start alert, worded "Started 3 min ago". Delivered reminders for
  meetings that started more than 5 minutes ago are removed.
- PEEK-272: Peek schedules at most the 60 nearest lead-time notifications,
  leaving room for snoozes within the 64 macOS keeps; the rest are added as
  earlier ones pass. Each occurrence of a recurring event gets its own reminder;
  before, occurrences replaced one another.
- PEEK-272: the same meeting on two calendars (same title, start, end and link)
  shows, notifies and alerts once, keeping the copy on a calendar that alerts.
  The `--export` JSON is unchanged.

### Added

- PEEK-272: reminders for meetings with a link or attendees are marked
  time-sensitive. They break through Focus only once the time-sensitive
  entitlement is added with App Store signing (see `docs/APP_STORE.md`).

## 1.13.1 - 2026-11-24

### Added

- PEEK-275: local diagnostics. Peek writes to the unified log under the
  `com.peek.app` subsystem, one category each for calendar, notifications,
  alerts, context, brief, hotkey, metrics and app: EventKit refreshes (duration,
  counts), notification reschedules (reason, events, requests, result), each
  start alert shown or skipped with its reason (badge only, already shown,
  filtered), hotkey registration failures and the context file state. Lines
  carry counts, outcomes and short opaque event references, never titles,
  notes, attendees, locations, links or paths (ADR 0006).
- PEEK-275: MetricKit crash, hang and energy payloads are kept in Application
  Support for 30 days.
- PEEK-275: Preferences > General > Diagnostics > "Export…" saves a JSON file
  with the recent log journal, MetricKit payloads, versions, permission states
  and settings as counts and switches, then shows it in the Finder. Nothing is
  sent; no network, entitlement or privacy-manifest change.

### Changed

- Replaced the remaining `print` calls with diagnostics events.

## 1.13.0 - 2026-11-24

### Added

- PEEK-261: the context file may carry an optional `day` object (date, headline,
  priorities, links). When its date is today, the popover shows "Today's
  priorities" above the next meeting: the headline, up to three priorities in
  order (done ones dimmed) and up to three link buttons. Read-only. Preferences >
  Briefs has a "Show day priorities" switch, on by default.
- PEEK-263: the lead-time notification and the 2-minute heads-up card say how
  many points from the context file are still to prepare and show the first one
  ("2 to prepare: Confirm the renewal position").
- PEEK-264: a context file generated more than 36 hours ago hides the day block,
  and the meeting page adds "Context from 23 Nov" under the context. Preferences
  shows when the file was last generated.

### Changed

- PEEK-262: context-file links may use `obsidian://` as well as `https://`, for
  meeting links and day links. Every other scheme is still dropped, and a link is
  checked again before a click opens it.
