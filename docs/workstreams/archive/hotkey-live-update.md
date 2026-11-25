# Workstream: Live global hotkey update and conflict feedback

- Roadmap ID: PEEK-104
- Status: Complete
- Owner: Claude (lead macOS engineer pass)
- Branch/worktree: Current main worktree (the layered refactor it depends on is still uncommitted on main; not branched to avoid separating this change from its dependencies)
- Last updated: 2026-07-15

## Objective

Make the global hotkey take effect immediately when changed in Preferences (no app
restart) and surface registration failures/conflicts to the user instead of only
printing to the console.

## Scope

- Extract a testable hotkey-registration decision policy (`GlobalHotkeyCoordinator`)
  and a `HotkeyRegistering` seam so the Carbon calls sit behind a protocol.
- Move live Carbon registration into a focused `CarbonHotkeyRegistrar` in the
  composition root, installing the Carbon event handler exactly once.
- Re-register the hotkey when `CalendarManager.globalHotkey` changes.
- Publish a transient hotkey status message on `CalendarManager` and show it in the
  General preferences tab; remove the stale "Restart app…" caption.
- Add deterministic tests for the coordinator with a fake registrar.
- Localize new strings; bump version (patch); update changelog/handoff/roadmap.

## Out of scope

- Detecting cross-application hotkey conflicts that Carbon does not report (documented
  limitation — only failures the public API reports are surfaced).
- Custom user-defined key combos beyond the existing `HotkeyOption` set.
- PEEK-105 import/export feedback and PEEK-107 signing.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/Application/AppBehaviorSupport.swift`
- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Resources/en.lproj/Localizable.strings`
- `PeekTests/GlobalHotkeyCoordinatorTests.swift` (new)
- `Peek.xcodeproj/project.pbxproj`
- `CHANGELOG.md`, `docs/HANDOFF.md`, `docs/ROADMAP.md`, `Configuration/Version.xcconfig`

## Dependencies

- None. PEEK-101/102/103 are integrated.

## Progress

- [x] Create workstream file
- [x] Add coordinator + registering seam
- [x] Wire live re-registration in composition root
- [x] Surface status in Preferences
- [x] Add tests and register in project
- [x] Localize, bump version, update changelog/handoff/roadmap
- [x] Validate build and tests

## Validation

- `bash scripts/check-version.sh` → 1.2.1 (9) valid.
- Debug build succeeded (unsigned).
- `xcodebuild ... test` → 62 tests passed, 0 failures (58 baseline + 4 new
  `GlobalHotkeyCoordinatorTests`).
- `git diff --check` → clean.

## Implementation notes

- `HotkeyRegistering` seam + `GlobalHotkeyCoordinator` + `HotkeyRegistrationResult` in
  `AppBehaviorSupport.swift` (testable, no Carbon dependency).
- `CarbonHotkeyRegistrar` in `PeekApp.swift` is the sole Carbon touchpoint; installs the
  event handler once and unregisters the prior binding before each register.
- `AppDelegate` observes `$globalHotkey` and calls `applyGlobalHotkey`, publishing any
  failure to `CalendarManager.hotkeyStatusMessage` (transient, not persisted).
- Hotkey activation now calls `NSApp.activate(ignoringOtherApps:)` before toggling so the
  popover appears above the frontmost app.

## Decisions and open questions

- Carbon `RegisterEventHotKey` cannot reliably detect hotkeys owned by other apps, so
  only API-reported failures are surfaced. This is documented as a limitation.

## Exact next action

Add `HotkeyRegistering`, `HotkeyRegistrationResult`, and `GlobalHotkeyCoordinator` to
`AppBehaviorSupport.swift`.
