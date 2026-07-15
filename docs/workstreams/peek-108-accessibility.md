# Workstream: PEEK-108 accessibility

- Roadmap ID: PEEK-108
- Status: Complete
- Owner: Agent
- Branch/worktree: codex/peek-108-accessibility
- Last updated: 2026-07-15

## Objective

Complete VoiceOver labels, focus order, keyboard activation, and Dynamic Type-style scaling across the Peek UI.

## Scope

- Convert custom radio rows in Preferences to buttons so they participate in keyboard focus and activation.
- Add or complete VoiceOver labels and hints for Preferences controls and the menu-bar popover.
- Replace fixed-size fonts in user-facing text with Dynamic Type text styles where it preserves the design.
- Add an accessibility label to the status-item button describing the current/next event.

## Out of scope

- Full UI-test validation with VoiceOver running.
- Redesigning the visual layout.

## Claimed files and subsystems

- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Sources/Presentation/MenuBar/MenuBarView.swift`
- `Peek/Sources/App/PeekApp.swift`
- `PeekTests/MenuBarAndPreferencesIntegrationTests.swift`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `Configuration/Version.xcconfig`

## Dependencies

- PEEK-105 is committed on `codex/peek-105-import-export-feedback`.

## Progress

- [x] Create workstream and branch
- [x] Make Preferences radio rows keyboard-activatable
- [x] Add VoiceOver labels and hints to Preferences
- [x] Add VoiceOver labels and Dynamic Type to MenuBar popover
- [x] Add status-item accessibility label
- [x] Bump version and update docs
- [x] Run build and tests

## Validation

- `bash scripts/check-version.sh` passed.
- `xcodebuild -scheme Peek -configuration Debug ... build` succeeded.
- `xcodebuild -scheme Peek -destination "platform=macOS" ... test` passed: 63 tests, 0 failures.
- `git diff --check` clean.

## Decisions and open questions

- Keep the existing layout; only convert interactive rows to `Button` and add accessibility text.

## Exact next action

Workstream complete. No further action required; PEEK-106 or PEEK-107 are the next ready roadmap items.
