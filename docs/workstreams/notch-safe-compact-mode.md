# Workstream: Notch-safe adaptive compact mode

- Roadmap ID: PEEK-101
- Status: Complete
- Owner: Codex
- Branch/worktree: Current main worktree
- Last updated: 2026-07-15

## Objective

Add a user-facing menu-bar space policy so Peek falls back to its icon before macOS hides the status item, restores text when space returns, and avoids rapid mode switching. Provide `Automatic`, `Always show icon`, and `Always show text` options, with `Automatic` as default.

## Scope

- Introduce `MenuBarSpacePolicy` preference (automatic / alwaysShowIcon / alwaysShowText).
- Remove redundant `StatusBarDisplayMode.iconOnly`; migrate existing saved preferences.
- Extract cramped-width decision logic from `AppDelegate` into a testable `StatusBarSpacePolicy` type.
- Add hysteresis to prevent oscillation near the width threshold.
- Detect notched displays and pass a conservative margin into the policy.
- Update Preferences UI, localization, tests, changelog, version, and handoff.

## Out of scope

- PEEK-104 global hotkey live update.
- PEEK-105 import/export feedback.
- PEEK-107 signing/notarization.

## Claimed files and subsystems

- `Peek/Sources/Domain/Models/AppPreferences.swift`
- `Peek/Sources/Application/StatusBarSpacePolicy.swift` (new)
- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `Peek/Sources/Presentation/StatusBar/StatusBarContentBuilder.swift`
- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Resources/en.lproj/Localizable.strings`
- `PeekTests/StatusBarSpacePolicyTests.swift` (new)
- `PeekTests/StatusBarContentBuilderTests.swift`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `Configuration/Version.xcconfig`

## Dependencies

- None.

## Progress

- [x] Create workstream file
- [x] Model preference and extract policy
- [x] Wire through CalendarManager and AppDelegate
- [x] Update UI and localization
- [x] Add tests
- [x] Bump version and update changelog/handoff
- [x] Validate build and tests

## Validation

- Debug build succeeded.
- `bash scripts/check-version.sh` passed.
- 33 tests passed with zero failures.

## Decisions and open questions

- Decided to keep `StatusBarDisplayMode` for time-until/actual-time content and add a separate `MenuBarSpacePolicy` for icon-vs-text behavior.
- Notch detection uses `NSScreen.safeAreaInsets.top > 0`; margin is a conservative estimate.

## Exact next action

None — workstream complete. Next integrator should review and merge; see `docs/HANDOFF.md` for the next roadmap item.
