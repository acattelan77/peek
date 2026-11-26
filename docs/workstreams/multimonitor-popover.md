# Workstream: Multi-monitor popover stability

- Roadmap ID: PEEK-282 (proposed; confirm with maintainer)
- Status: Active — PR #2 in Draft pending branch update and CI
- Owner: External contributor
- Branch/worktree: `fix/multimonitor-popover`
- Last updated: 2026-11-26
- PR: https://github.com/acattelan77/peek/pull/2

## Objective

Keep Peek's menu-bar popover anchored to its initial position and opening
screen on multi-display setups, without stopping the live menu-bar countdown.
Ensure the menu-bar and popup countdowns use consistent minute rounding.

## Scope

- Preserve the popup's initial anchor during its visible lifetime; acquire a
  fresh anchor on reopening, rather than following transient status-item moves.
- Keep status-item content live while constraining status-item geometry during
  presentation.
- Avoid showing the popup repeatedly when refreshing anchor information.
- Share the rounded-up minute calculation between the popup and menu bar.
- Add focused regression tests for anchor decisions and minute boundaries.

## Out of scope

- Popover redesign, calendar/event behavior and public export/context-file
  contracts; release signing and publication.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/App/PopoverAnchorController.swift`
- `Peek/Sources/App/PopoverAnchorGeometry.swift`
- `Peek/Sources/Presentation/Formatting/EventTimeFormatter.swift`
- `Peek/Sources/Presentation/StatusBar/StatusBarContentBuilder.swift`
- `PeekTests/EventTimeFormatterTests.swift`
- `PeekTests/StatusBarContentBuilderTests.swift`
- `PeekTests/StatusBarSpacePolicyTests.swift`
- Version, changelog and documentation associated with this workstream.

## Dependencies

- macOS/AppKit status-item behavior on multiple displays.
- Maintainer confirmation of provisional roadmap ID and final review.

## Progress

- [x] Reproduced the multi-monitor popover jump.
- [x] Applied anchor-stability and live-countdown improvements.
- [x] Unified minute rounding and added regression tests.
- [x] Local XCTest suite passed on the final working tree (2026-11-26).
- [x] Local unsigned/ad-hoc Release build succeeded and was installed.
- [x] Contributor performed physical checks on the problematic external
      display using temporary calendar events; popover was reported stable.
- [x] PR #2 opened; kept in Draft while latest local changes are unpublished.
- [ ] Explicitly verify display rearrangement, urgency/alert transitions,
      notched/crowded menu bars and release-signed candidate where available.
- [ ] Commit and push latest code/docs; verify PR CI before Ready for review.

## Validation

- `xcodebuild -scheme Peek -destination 'platform=macOS' -derivedDataPath
  ./build -jobs 1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY="" test` — passed on the contributor's Mac.
- `./scripts/build-unsigned.sh --install` — Release build and installation
  succeeded on the contributor's Mac.
- `git diff --check` — passed before documentation updates; re-run afterward.
- Additional repository-specific version, privacy and UI checks: verify with
  CI; do not claim them passed for this latest working tree yet.
- PR CI URL/status for latest commit: pending push.

## Decisions and open questions

- Live countdown must remain functional while the popover is open. Do not
  reintroduce the earlier status-item rendering freeze.
- Keep the position captured at initial presentation stable until close;
  re-anchor on a fresh opening.
- Confirm proposed PEEK-282 ID with maintainer.

## Exact next action

Review the final local diff; run repository checks, commit and push to
`fix/multimonitor-popover`, verify PR #2 CI and request maintainer review.
Do not merge or tag a release as part of this workstream.
