# Workstream: Phase 1, never miss a meeting

- Roadmap ID: PEEK-201, PEEK-202, PEEK-203, PEEK-204
- Status: In review
- Owner: Claude Code (cloud session, project thread "Pianificare Peek 2.0 per l'App Store")
- Branch/worktree: `claude/project-thread-t3424o`
- Last updated: 2026-11-23

## Objective

Bring Peek's core to parity with the leading menu-bar meeting apps before the 2.0
App Store release: a compact month view (PEEK-201), robust meeting-link detection with
native-app join (PEEK-202), an interrupting start-of-meeting alert with levels
(PEEK-203), and localization (PEEK-204). Plan and mockups: the "Peek: piano di sviluppo
verso l'App Store" doc and the "Peek 2.0 mockup" canvas (phase 0, approved 2026-11-23).

## Scope

- PEEK-202: `MeetingURLDetector`, `MeetingProvider`, `MeetingLinkOpener`, the Join call
  sites, and a Preferences switch for native apps.
- PEEK-201: a read-only month grid in the popover header area.
- PEEK-203: alert levels and a full-screen alert panel.
- PEEK-204: String Catalog migration or added `.lproj` tables for it, de, fr, es.

## Out of scope

- Event creation or editing, week/day views, phase 2 context and phase 3 AI brief.
- Any change to the PEEK-111 CLI or JSON v1 contract.

## Claimed files and subsystems

- `Peek/Sources/Domain/Meetings/`
- `Peek/Sources/Application/AppBehaviorSupport.swift` (`MeetingLinkOpener`)
- `Peek/Sources/Presentation/MenuBar/`, `Peek/Sources/App/StartingNowHUDController.swift`
- New alert and month-view files, `Peek/Resources/*.lproj`
- `PeekTests/MeetingURLDetectorTests.swift` and new phase-1 tests

## Dependencies

- Design system v2 (PR #9, merged as 537bd99).

## Progress

- [x] PEEK-202 link detection, native-app join, export v1 classification frozen
- [x] PEEK-201 compact month view (`MonthGrid`, `MonthCalendarView`, day agenda in `MenuBarView`)
- [x] PEEK-203 alert levels and full-screen alert
- [x] PEEK-204 localization (it, de, fr, es `.lproj` tables, `scripts/check-localization.py` in CI)

## Validation

- Linux cloud session: `bash scripts/check-version.sh`, `bash scripts/check-design-tokens.sh`,
  `python3 scripts/check-localization.py` (162 keys, 5 tables) and `git diff --check` pass.
- Build and tests ran in CI only (`build-and-test` on `macos-latest`, PR #10), not locally.

### Owner checks on a Mac

1. Month view: dots on days with events, previous/next/Today, choosing a day shows its
   agenda, "Back to upcoming"; light, dark and Increased Contrast; hide it in Preferences.
2. Join: a Zoom `/j/` link and a Teams link open the native app when installed, the
   browser when the Preferences switch is off or the app is missing.
3. Start alert set to Full screen: appears over a full-screen app and on the current
   Space; Return joins, Esc dismisses, "In 1 minute" brings it back once; a focus block
   without link or attendees gets the card instead; Off shows nothing.
4. Language: set Peek to Italian in System Settings > General > Language & Region >
   Applications, check the popover, Preferences, onboarding and the permission prompts
   for truncation. A native read of de, fr and es before App Store submission.
5. PEEK-111: `Peek --export --from 0 --to 7 --json` still classifies Zoom, Meet and Teams
   links as `join` and the Northwind Notes renderer reads it unchanged.

## Decisions and open questions

- Export JSON v1 keeps the original eight join domains through
  `MeetingURLDetector.exportV1JoinDomains`, so Northwind Notes sees no classification change.
- The month view is read-only. A double click that opens Calendar on that date was
  dropped: Calendar.app has no documented date deep link; the footer's Open Calendar
  remains.
- Detection order changed to URL field, location, notes (calendar providers put the
  conference link in the URL field; notes often hold secondary links).
- PEEK-203 defaults to the heads-up card, so existing users see no change until they
  choose Full screen. The full-screen alert does not read Focus status yet: that needs
  the Communication Notifications capability and `INFocusStatusCenter` authorization.
  Open question for the owner: should full screen respect Focus before App Store?
- PEEK-204 keeps `.strings` tables instead of migrating to a String Catalog: the
  project file is hand-maintained and a catalog's JSON is harder to review in diffs.
  The English table was regenerated from source (27 unused keys removed, 31 added).
  Translations are mine and need a native read for de, fr and es before release.
  The test action is pinned to en-US so string assertions pass on non-English Macs.

## Exact next action

Owner runs the checks above on a Mac, then merges PR #10. Phase 2 (meeting context) follows.
