# Workstream: Reduce Motion menu-bar pulse

- Roadmap ID: PEEK-AUD-02
- Status: Complete
- Owner: Codex
- Branch/worktree: `codex/eventkit-main-thread` in `~/Dev/peek`
- Last updated: 2026-08-14

## Objective

Ensure the critical-event status-item pulse honors macOS Reduce Motion.

## Scope

- Make the pulse decision testable from urgency, color preference, and Reduce Motion state.
- Suppress and reset the status-item animation when Reduce Motion is enabled.
- Add focused regression coverage and update release handoff/versioning.

## Out of scope

- EventKit refresh behavior, calendar export, notification scheduling, HUD retention, release tooling, and system preference changes.

## Claimed files and subsystems

- `Peek/Sources/Application/AppBehaviorSupport.swift`
- `Peek/Sources/App/PeekApp.swift`
- `PeekTests/GlobalHotkeyCoordinatorTests.swift`
- `docs/workstreams/reduce-motion-pulse.md`
- `Configuration/Version.xcconfig`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `docs/ROADMAP.md`

## Dependencies

- Uses the existing AppKit system Reduce Motion preference as the runtime source of truth.

## Progress

- [x] Claim the workstream.
- [x] Implement and test pulse suppression.
- [x] Bump Peek to 1.5.2 (31), update handoff, and validate.

## Validation

- Focused unsigned test: `xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:PeekTests/GlobalHotkeyCoordinatorTests test` — passed.
- Full validation is recorded with the remaining hardening increments.

## Decisions and open questions

- Preserve urgency color semantics. Reduce Motion disables only the repeated alpha animation.

## Exact next action

Perform PEEK-AUD-07 physical accessibility validation on authorized macOS hardware.
