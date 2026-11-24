# Workstream: Align the app with the Peek 2.0 mockups

- Roadmap ID: PEEK-241
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: claude/project-thread-7wacdl
- Last updated: 2026-11-24

## Objective

The installed app matches the approved "Peek 2.0 mockup" canvas (claude.ai artifact
`B8Un31gdcqtookHfZvbPb2`) in light and dark: popover, month grid, next-meeting card,
event rows, meeting page, full-screen alert and Preferences.

## Scope

- Popover header (month title, "weekday · N meetings today", ‹ Today ›), month grid styling,
  next-meeting card, compact rows grouped by day with finished meetings dimmed.
- Meeting page in the popover, replacing in-place row expansion.
- Full-screen alert layout.
- Preferences tabs by purpose, reusing the existing settings.
- Attendee display names derived from email addresses; headline "Marco, CEO at
  Northwind, and 2 others".
- New copy in en, it, de, fr, es.

## Out of scope

- Popover footer: keeps the 1.x icon buttons (owner decision 2026-11-24, recorded in
  `docs/DESIGN_SYSTEM.md` and in the mockup canvas).
- The Preferences alert ladder (one level per moment) and the menu-bar filled pills: both
  change behaviour and need an owner decision.
- Onboarding "Arrive prepared" step, HUD, app icon.

## Claimed files and subsystems

- `Peek/Sources/Presentation/**` (MenuBar, HUD/MeetingStartAlert, Preferences, DesignSystem)
- `Peek/Sources/App/StartingNowHUDController.swift` (alert detail line only)
- `Peek/Sources/Domain/Context/MeetingContext.swift`, `Peek/Sources/Domain/Events/MonthGrid.swift`
- `Peek/Resources/*.lproj/Localizable.strings`
- `PeekTests/MeetingContextTests.swift`, `PeekTests/MonthGridTests.swift`
- `docs/DESIGN_SYSTEM.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `Configuration/Version.xcconfig`

## Dependencies

- Phases 1 to 4 and design system v2 are merged to `main` (In review only for owner
  checks on a Mac); this branch starts from `main` at 1.10.0 (39).

## Progress

- [x] Compare the owner's screenshot and the code with the canvas
- [x] Tokens and components (PeekTheme, PeekComponents)
- [x] Popover, meeting page, alert, Preferences
- [x] Names from email addresses, headline with role and count
- [x] Localization (256 keys, 5 tables), tests, docs, 1.11.0 (40)
- [x] CI green on the draft PR (#15)
- [ ] Owner visual check on a Mac

## Validation

- Cloud session (Linux, no Xcode). Build and tests run in CI, not locally.
- Linux: `bash scripts/check-version.sh` (1.11.0 (40) valid), `bash scripts/check-design-tokens.sh`
  (OK), `python3 scripts/check-localization.py` (256 keys, 5 tables), `git diff --check` (clean).
- CI `build-and-test` on macos-latest passed on 0e037d4: build succeeded, 187 tests, 0 failures.
  https://github.com/acattelan77/peek/actions/runs/45353675645
- Test installer (ad-hoc DMG) from this branch: https://github.com/acattelan77/peek/actions/runs/45353688029

## Decisions and open questions

- The UI language follows macOS (System Settings > General > Language & Region > Applications
  can set Peek to Italian). The owner's Mac runs in English, so the app shows English copy
  even though the mockups are written in Italian. An in-app language picker was not added.
- Today's finished meetings now appear dimmed in the popover list, as in the mockup. They do
  not affect the menu bar, alerts or the brief.

## Exact next action

Owner: install the test build from this branch and compare with the canvas in light and dark:
header and month grid, next-meeting card (normal, SOON, NOW), rows under Today and Tomorrow,
a finished meeting, the meeting page (click the card, Escape back), the full-screen alert,
and the four Preferences tabs. Then mark the PR ready and merge.
