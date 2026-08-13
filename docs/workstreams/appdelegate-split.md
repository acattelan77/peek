# Workstream: Split AppDelegate into focused types

- Roadmap ID: N/A (tech debt noted in HANDOFF known constraints)
- Status: Complete
- Owner: Kimi
- Branch/worktree: `codex/appdelegate-split`
- Last updated: 2026-08-13

## Objective

Shrink `Peek/Sources/App/PeekApp.swift` (~1120 lines, flagged in HANDOFF's
known constraints) by extracting self-contained subsystems into their own
files/types, and repair the discovered stale popover-arrow path.

## Scope

- Move `CarbonHotkeyRegistrar` and the `fourCharCodeValue` helper into
  `Peek/Sources/App/CarbonHotkeyRegistrar.swift` (no coupling; move only).
- Move `PopoverAnchorGeometry` into `Peek/Sources/App/PopoverAnchorGeometry.swift`
  (used by `PeekTests`; no changes).
- Extract popover anchor machinery (anchor window, tracking timer, and geometry
  fallbacks) into
  `PopoverAnchorController`; AppDelegate keeps toggle/monitor orchestration.
- Extract the "Starting now" HUD window lifecycle into
  `StartingNowHUDController` (window, snooze work item, shown-event IDs).
- Apply the 1.4.1 patch/build version update and record the handoff.

## Out of scope

- Unrelated behavior, UI, or timing changes. The popover-anchor repair is
  limited to replacing the unusable WindowServer lookup with AppKit geometry.
- Splitting `CalendarManager` (separate, larger effort).
- Rearchitecting the remaining AppDelegate responsibilities (timers,
  notification scheduling, status-bar space policy).

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/App/CarbonHotkeyRegistrar.swift` (new)
- `Peek/Sources/App/PopoverAnchorGeometry.swift` (new)
- `Peek/Sources/App/PopoverAnchorController.swift` (new)
- `Peek/Sources/App/StartingNowHUDController.swift` (new)
- `Peek.xcodeproj/project.pbxproj` (file references)
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`, `docs/workstreams/appdelegate-split.md`

## Dependencies

- Builds on the 1.3.10/1.3.11 popover-anchor behavior. The unavailable
  WindowServer lookup is removed after physical diagnosis on macOS 26.

## Progress

- [x] Map AppDelegate responsibilities and pick extraction seams.
- [x] Create workstream file and branch.
- [x] Move registrar and geometry (no coupling).
- [x] Extract `PopoverAnchorController`.
- [x] Extract `StartingNowHUDController`.
- [x] Apply 1.4.1 (28) patch/build update, validation, and handoff docs.
- [x] Physical QA (popover open/close/anchor tracking, HUD, hotkey).

## Validation

- `bash scripts/check-version.sh` passed for 1.4.1 (28).
- Required unsigned Debug build succeeded on 2026-08-13.
- Required macOS test run passed on 2026-08-13: 80 tests, zero failures.
- `git diff --check` passed.
- `PeekApp.swift` went from 1120 to 753 lines.
- User-performed physical QA passed on 2026-08-13: popover alignment across
  menu-bar rearrangements, the global hotkey, and the Starting now HUD.

## Decisions and open questions

- Extraction targets are the subsystems with clean seams and recent subtle
  fixes (popover anchoring, HUD); everything else stays put to keep the diff
  reviewable and behavior identical.
- New files live in `Sources/App` (the composition-root layer) because both
  controllers orchestrate AppKit objects owned by AppDelegate.
- `PopoverAnchorController.stopTracking()` is internal (not private) because
  the toggle-close path must stop tracking before `performClose`, while
  `popoverDidClose` performs the full `detach()`.
- 2026-08-13 physical QA found the popover arrow pointing at a stale menu-bar
  position. Instrumented Debug runs showed the WindowServer
  (`CGWindowList`) lookup is unusable on macOS 26: the private status-item
  window reports window number 2^32 (which also caused the 1.3.10 crash via
  the `CGWindowID` truncation) and the window list returns an empty result for
  it. AppKit's `button.window` frame, by contrast, tracked menu-bar
  rearrangements live (observed x 1182 → 1214 mid-session). The WindowServer
  path was removed (1.4.1); anchoring uses click-derived geometry first and
  AppKit's live frame otherwise, keeping the fresh per-presentation anchor
  window. Pre-Tahoe macOS behavior of this strategy is unverified (macOS 13
  hardware validation remains outstanding).

## Exact next action

None. The workstream is complete, committed locally on
`codex/appdelegate-split`, and ready for integration.
