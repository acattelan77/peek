# Workstream: Keep popover anchored to the status item

- Roadmap ID: N/A
- Status: In review
- Owner: Codex
- Branch/worktree: `codex/popover-status-item-anchor`
- Last updated: 2026-07-31

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

## Validation

- `bash scripts/check-version.sh` passed for 1.3.9 (23).
- Required unsigned Debug build succeeded on 2026-07-31.
- Required macOS test run passed on 2026-07-31: 67 tests, zero failures.
- `git diff --check` passed.
- 2026-07-31 physical QA failed when Peek changed from text to icon after another
  menu-bar item was opened; the popover remained at the prior text-item position.
- The revised build was relaunched from Xcode; repeating the same physical sequence
  remains the final confirmation.

## Decisions and open questions

- Keep `NSPopover` anchored to `NSStatusBarButton`; the failure is stale
  positioning after the status-item window moves, not an incorrect anchor view.
- The original bounded retry can declare the old frame stable before macOS
  finishes recreating or moving the compact status-item window.
- The revised implementation compares the live window identity, screen frame,
  and button bounds throughout the popover lifetime. AppKit's documented
  re-show behavior updates the positioning-view association without closing it.

## Exact next action

Repeat the reported sequence on the currently running Xcode build: open Peek,
open another menu-bar item, then reopen Peek and confirm the arrow follows the
compact icon.
