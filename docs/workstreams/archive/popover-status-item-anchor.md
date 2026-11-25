# Workstream: Keep popover anchored to the status item

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: `codex/popover-anchor-window-rebind`
- Last updated: 2026-08-12

## Objective

Keep the Peek popover arrow attached to the current menu-bar icon position when
app activation or status-text changes cause macOS to rearrange menu-bar items.

## Scope

- Defer initial popover presentation until the activation layout pass completes.
- Re-anchor a visible popover after Peek changes its status-item width or position.
- Preserve accessory-app activation, transient behavior, and command-drag handling.
- Add regression-oriented validation and update release documentation/versioning.

## Out of scope

- Changes to menu-bar space-policy thresholds or event-title formatting.
- Replacement of `NSPopover` or use of private menu-bar APIs.
- Changes to the popover's visual design.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `PeekTests/EventPipelineTests.swift`
- `CHANGELOG.md`
- `Configuration/Version.xcconfig`
- `docs/HANDOFF.md`
- `docs/workstreams/popover-status-item-anchor.md`

## Dependencies

- Builds on the existing 1.3.1 accessory-app activation fix and PEEK-109
  icon/text fallback behavior.

## Progress

- [x] Reproduce the stale-anchor sequence from screenshots and code.
- [x] Implement deferred presentation and visible-popover re-anchoring.
- [x] Bump the patch version and update release documentation.
- [x] Run required validation.
- [x] Replace bounded stabilization with tracking of the live status-item window.
- [x] Re-run required validation after physical QA exposed the remaining race.
- [x] Decouple `NSPopover` from the private status-item positioning window.
- [x] Add click-geometry regression tests.
- [x] Fix the hotkey-presentation crash from the out-of-range
  `windowNumber` → `CGWindowID` conversion (1.3.11).

## Validation

- `bash scripts/check-version.sh` passed for 1.3.11 (25).
- Required unsigned Debug build succeeded on 2026-08-12.
- Required macOS test run passed on 2026-08-12: 69 tests, zero failures.
- `git diff --check` passed.
- 2026-08-12 physical QA passed on the 1.3.11 build: the global hotkey opens
  the popover without crashing and the arrow follows the current icon.
- Local Release build succeeded for both arm64 and x86_64, passed strict
  on-disk signature verification, and contains the calendar entitlement.
- Computer-control inspection can launch the app but cannot address or capture
  macOS menu-bar extras, so the exact visual close/reopen sequence still
  requires physical QA.
- 2026-07-31 physical QA failed when Peek changed from text to icon after another
  menu-bar item was opened; the popover remained at the prior text-item position.
- 2026-07-31 physical QA failed again on the revised Release build: after another
  menu-bar item was opened, Peek's compact icon appeared at its current position
  while the popover arrow remained centered on an earlier menu-bar position.

## Decisions and open questions

- Keep `NSPopover` anchored to `NSStatusBarButton`; the failure is stale
  positioning after the status-item window moves, not an incorrect anchor view.
- The original bounded retry can declare the old frame stable before macOS
  finishes recreating or moving the compact status-item window.
- The revised implementation compares the live window identity, screen frame,
  and button bounds throughout the popover lifetime. AppKit's documented
  re-show behavior updates the positioning-view association without closing it.
- The second physical failure shows the private positioning-view association
  itself is unreliable across close/reopen. The 1.3.10 candidate attaches each
  presentation to a fresh app-owned transparent anchor window and updates that
  window from the exact WindowServer status-item frame.
- 2026-08-12 physical QA: pressing the global hotkey crashed Peek
  (`EXC_BREAKPOINT` in `liveStatusButtonScreenFrame`). The private status-item
  window's `windowNumber` can fall outside the `CGWindowID` (`UInt32`) range,
  and the unchecked conversion trapped. 1.3.11 range-checks the conversion and
  falls back to click-derived/AppKit-derived geometry.

## Exact next action

None — physical QA passed on 1.3.11 and the workstream is complete.
