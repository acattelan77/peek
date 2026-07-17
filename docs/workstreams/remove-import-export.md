# Workstream: Remove import/export

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: codex/hud-external-border
- Last updated: 2026-07-17

## Objective

Remove the Preferences import and export controls and their JSON settings backup/restore implementation.

## Scope

- Remove the Import and Export buttons from Preferences.
- Remove the underlying JSON import/export methods from `CalendarManager`.
- Remove import/export-specific tests and localization strings.
- Update release/version/handoff documentation for the user-visible simplification.

## Out of scope

- Changing ordinary preference persistence.
- Changing calendar selection, filters, hotkeys, notifications, or appearance settings.
- Reworking Preferences layout beyond closing the gap left by the removed buttons.

## Claimed files and subsystems

- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `Peek/Resources/en.lproj/Localizable.strings`
- `PeekTests/MenuBarAndPreferencesIntegrationTests.swift`
- `CHANGELOG.md`
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`
- `docs/PROJECT_STATUS.md`
- `docs/RELEASE.md`
- `docs/workstreams/remove-import-export.md`

## Dependencies

- Builds on the current `codex/hud-external-border` branch, which also contains the HUD polish change.

## Progress

- [x] Remove Preferences UI and presentation helpers.
- [x] Remove application import/export methods.
- [x] Update tests and docs.
- [x] Run validation.

## Validation

- `bash scripts/bump-version.sh patch` → bumped Peek from 1.3.5 (19) to 1.3.6 (20).
- `bash scripts/check-version.sh` → 1.3.6 (20) valid.
- `git diff --check` → clean.
- `plutil -lint Peek/Resources/en.lproj/Localizable.strings` → OK.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded.
- `xcodebuild -scheme Peek -destination platform=macOS -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= test` → 66 tests, 0 failures.
- Compiled Debug bundle metadata: `CFBundleShortVersionString=1.3.6`, `CFBundleVersion=20`.

## Decisions and open questions

- User requested removing both export and import. Treat this as removing the feature, not merely hiding the footer buttons.
- Historical workstream files still mention PEEK-105 import/export feedback because they describe past completed work; current-state docs now mark the feature as removed/superseded.

## Exact next action

None. Workstream complete.
