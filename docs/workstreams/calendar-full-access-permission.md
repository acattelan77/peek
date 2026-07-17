# Workstream: Calendar full access permission

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: codex/hud-external-border
- Last updated: 2026-07-17

## Objective

Fix Peek continuing to show "No Calendar Access" when macOS System Settings grants Full Access.

## Scope

- Add the macOS full-calendar-access usage description.
- Add regression coverage for EventKit `.fullAccess` authorization.
- Bump patch version and update handoff/changelog.
- Rebuild, reinstall, and relaunch the local app.

## Out of scope

- Changing the calendar permission UI design.
- Changing event fetching or calendar filtering.

## Claimed files and subsystems

- `Peek/Resources/Info.plist`
- `PeekTests/CalendarManagerIntegrationTests.swift`
- `CHANGELOG.md`
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`
- `docs/workstreams/calendar-full-access-permission.md`

## Dependencies

- Builds on the current `codex/hud-external-border` branch, which contains the HUD polish and import/export removal changes.

## Progress

- [x] Add full-access usage description.
- [x] Add `.fullAccess` authorization regression test.
- [x] Run validation and reinstall local app.

## Validation

- `bash scripts/bump-version.sh patch` → bumped Peek from 1.3.6 (20) to 1.3.7 (21).
- `bash scripts/check-version.sh` → 1.3.7 (21) valid.
- `git diff --check` → clean.
- `plutil -lint Peek/Resources/Info.plist Peek/Resources/en.lproj/Localizable.strings` → OK.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded.
- `xcodebuild -scheme Peek -destination platform=macOS -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= test` → 67 tests, 0 failures.
- `xcodebuild -scheme Peek -configuration Release -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded.
- `ditto /Users/alessandrocattelan/Dev/peek/build/Build/Products/Release/Peek.app /Applications/Peek.app` → installed locally.
- Installed bundle metadata: `CFBundleShortVersionString=1.3.7`, `CFBundleVersion=21`, `NSCalendarsFullAccessUsageDescription` present.

## Decisions and open questions

- The screenshot shows macOS Full Access, so the fix should target macOS 14+ EventKit full-access semantics and TCC metadata.

## Exact next action

None. Workstream complete.
