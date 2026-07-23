# Workstream: HUD external border

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: codex/hud-external-border
- Last updated: 2026-07-23

## Objective

Hide the rectangular external AppKit container visible around the rounded "Starting now" HUD.

## Scope

- Make the HUD hosting/panel backing transparent without changing HUD content or behavior.
- Give the card's drop shadow room inside the panel so the window bounds do not clip it into a visible squared edge.
- Update versioning/changelog because this is a user-visible visual fix.

## Out of scope

- Redesigning the HUD.
- Changing notification timing, snooze behavior, or event selection.
- Broad manual QA of every design-system surface.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/Presentation/HUD/StartingNowHUD.swift`
- `CHANGELOG.md`
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`
- `docs/workstreams/hud-external-border.md`

## Dependencies

- Builds on the completed design-system consistency workstream, which removed the native panel shadow but left a visible hosting/container backing in the reported screenshot.

## Progress

- [x] Inspect HUD panel/hosting setup.
- [x] Make the external HUD container invisible.
- [x] Give the drop shadow room inside the panel (shadow padding + card-anchored placement).
- [x] Run focused validation.
- [x] Record results.

## Validation

- `bash scripts/bump-version.sh patch` → bumped Peek from 1.3.4 (18) to 1.3.5 (19); second cycle bumped 1.3.7 (21) to 1.3.8 (22).
- `bash scripts/check-version.sh` → 1.3.8 (22) valid.
- `git diff --check` → clean.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded (first cycle, 1.3.5).
- `xcodebuild -scheme Peek -destination platform=macOS -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= test` → 69 tests, 0 failures (first cycle, 1.3.5).
- Second cycle (1.3.8, 2026-07-23): Debug build succeeded; `xcodebuild ... test` → 67 tests, 0 failures; `scripts/check-version.sh` → 1.3.8 (22) valid; `git diff --check` → clean.

## Decisions and open questions

- The screenshot points to the "Starting now" HUD container, not the menu-bar popover or macOS notification banner.
- The first fix created the HUD panel as borderless from initialization rather than creating a default panel and mutating its style mask afterward. The hosting/content layers are also transparent so AppKit cannot paint a rectangular backing behind the rounded SwiftUI card.
- The 1.3.5 fix left one visible artifact: the panel was sized to the card's exact bounds, so the SwiftUI drop shadow (blur 25, y-offset 20) was clipped by the window edges into a squared gray edge. The 1.3.8 follow-up adds a transparent `StartingNowHUD.shadowPadding` margin around the card (sized from the `.hud` elevation values) and anchors the panel by the card's top-right corner so on-screen placement is unchanged.

## Exact next action

None. Optional manual follow-up: trigger a live "Starting now" HUD and visually confirm only the rounded card (with a soft rounded shadow) is visible in light and dark mode.
