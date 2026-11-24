# Workstream: local diagnostics and logs

- Roadmap ID: PEEK-275
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-xsgcc3`
- Last updated: 2026-11-24

## Objective

A missed or late alert leaves a local, content-free trace that the owner can
read with `log stream` or export from Preferences. PR 1 of the pre-release
robustness plan (PEEK-271..275); it ships first so PRs 2 to 4 can be checked
with its logs.

## Scope

- Typed `DiagnosticEvent` with category, level and message; opaque event
  references; retention and throttle policies (`Domain/Diagnostics`).
- `DiagnosticsLog`: one `os.Logger` per category plus the on-disk journal
  (`Infrastructure/Diagnostics`).
- `MetricKitCollector` and `MetricPayloadStore`, 30-day pruning.
- `DiagnosticsReport` (Application) and `DiagnosticsExporter` (Infrastructure).
- Log points: launch, calendar access, EventKit refresh and failures,
  notification permission, reschedule reason and counts, requests submitted,
  scheduling result, clear, snooze, start alert and 2-minute card shown or
  skipped (badge only, filtered, already shown), hotkey registration failures,
  context file state, brief outcome, MetricKit payload saved, export.
- Preferences > General > Diagnostics > "Export…", five languages.
- ADR 0006.

## Out of scope

- Time and notification robustness (PEEK-271, PEEK-272), per-event control
  (PEEK-273), screen-share discretion (PEEK-274).
- Any network upload or crash-reporting service.

## Claimed files and subsystems

- `Peek/Sources/Domain/Diagnostics/`, `Peek/Sources/Infrastructure/Diagnostics/`,
  `Peek/Sources/Application/Diagnostics/`, `PeekTests/DiagnosticsTests.swift`,
  `docs/decisions/0006-local-diagnostics.md`.
- Small log-point edits in `PeekApp.swift`, `StartingNowHUDController.swift`,
  `NotificationManager.swift`, `CalendarManager.swift`,
  `MeetingBriefService.swift`, `PreferencesView.swift` and the five
  `Localizable.strings`. Released on merge; PRs 2 to 4 rebase on top.

## Dependencies

- None. Bumps 1.13.0 (48) to 1.13.1 (49).

## Progress

- [x] Domain events, formatter, retention and throttle
- [x] Logger and journal
- [x] MetricKit collection and pruning
- [x] Export and Preferences row, localized in en, it, de, fr, es
- [x] Tests (`DiagnosticsTests`)
- [x] Docs: ADR 0006, roadmap, changelog, architecture

## Validation

- Linux: `bash scripts/check-version.sh`, `python3 scripts/check-localization.py`,
  `bash scripts/check-design-tokens.sh`, `git diff --check`.
- Build and tests ran in CI, not locally: `build-and-test` on `macos-latest`
  passed on de57fb0, https://github.com/acattelan77/peek/actions/runs/45500541806

## Checks for the owner on the Mac

1. `log stream --level info --predicate 'subsystem == "com.peek.app"'` while
   Peek runs: lines for `calendar`, `notifications` and `alerts` appear, with
   no titles or names.
2. Preferences > General > Diagnostics > Export…: the Finder opens on
   `Peek-diagnostics-<date>-<time>.json`; open it and check it holds no meeting
   titles, people or paths.
3. After a meeting start, the journal in the export shows `shown kind=...` or
   `skipped ... reason=...` for that event.

## Decisions and open questions

- Export goes to Peek's container and is revealed in the Finder instead of a
  save panel, to keep the read-only user-selected entitlement (ADR 0006).
- `alreadyShown` skips are throttled to one line per event per hour.

## Exact next action

Owner runs the three checks above on the main Mac. PR 2 (PEEK-271, PEEK-272)
adds its own `DiagnosticEvent` cases for wake, time-zone and clock changes.
