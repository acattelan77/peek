# Workstream: HUD external border

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: codex/hud-external-border
- Last updated: 2026-07-17

## Objective

Hide the rectangular external AppKit container visible around the rounded "Starting now" HUD.

## Scope

- Make the HUD hosting/panel backing transparent without changing HUD content or behavior.
- Update versioning/changelog because this is a user-visible visual fix.

## Out of scope

- Redesigning the HUD.
- Changing notification timing, snooze behavior, or event selection.
- Broad manual QA of every design-system surface.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `CHANGELOG.md`
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`
- `docs/workstreams/hud-external-border.md`

## Dependencies

- Builds on the completed design-system consistency workstream, which removed the native panel shadow but left a visible hosting/container backing in the reported screenshot.

## Progress

- [x] Inspect HUD panel/hosting setup.
- [x] Make the external HUD container invisible.
- [x] Run focused validation.
- [x] Record results.

## Validation

- `bash scripts/bump-version.sh patch` → bumped Peek from 1.3.4 (18) to 1.3.5 (19).
- `bash scripts/check-version.sh` → 1.3.5 (19) valid.
- `git diff --check` → clean.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded.
- `xcodebuild -scheme Peek -destination platform=macOS -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= test` → 69 tests, 0 failures.
- Compiled Debug bundle metadata: `CFBundleShortVersionString=1.3.5`, `CFBundleVersion=19`.

## Decisions and open questions

- The screenshot points to the "Starting now" HUD container, not the menu-bar popover or macOS notification banner.
- The fix creates the HUD panel as borderless from initialization rather than creating a default panel and mutating its style mask afterward. The hosting/content layers are also transparent so AppKit cannot paint a rectangular backing behind the rounded SwiftUI card.

## Exact next action

None. Optional manual follow-up: trigger a live "Starting now" HUD and visually confirm the external rectangle is gone in light and dark mode.
