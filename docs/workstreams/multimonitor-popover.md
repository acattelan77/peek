# Workstream: Multi-monitor popover stability

- Roadmap ID: PEEK-282 (proposed; confirm with maintainer)
- Status: Active
- Owner: External contributor
- Branch/worktree: `fix/multimonitor-popover`
- Last updated: 2026-11-26

## Objective

Keep Peek's menu-bar popover stable on the display from which it was opened,
including when the status item changes size or its window geometry is refreshed.

## Scope

- Freeze status-item rendering while the popover is opening or visible;
  resume rendering after it closes.
- Keep the anchor associated with the opening display and avoid repeated
  popover presentation during anchor refreshes.
- Add focused unit tests for rendering and screen-selection decisions.
- Document the physical validation needed for the updated build.

## Out of scope

- Redesigning the popover, changing calendar/event behavior or changing the
  public export and context-file contracts.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/App/PopoverAnchorController.swift`
- `Peek/Sources/App/PopoverAnchorGeometry.swift`
- `PeekTests/StatusBarSpacePolicyTests.swift`
- Version, changelog and documentation associated with this workstream.

## Dependencies

- macOS status-item and AppKit popover behavior across external screens.
- Owner/maintainer review of the proposed roadmap identifier and PR.

## Progress

- [x] Reproduced the multi-monitor popover jump before the fix.
- [x] Applied focused changes and added policy regression tests.
- [x] Validated earlier ad-hoc build on built-in and external displays.
- [x] Built and ran complete XCTest suite locally after rebasing on `main`.
- [ ] Validate the final 1.16.2 candidate on the multi-display setup.
- [ ] Push branch and open PR; record the CI run and results.

## Validation

- Local macOS: `xcodebuild -scheme Peek -destination 'platform=macOS'
  -derivedDataPath ./build -jobs 1 CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test` — passed.
- `bash scripts/check-version.sh`, design-token and localization checks — passed
  on the final 1.16.2 candidate — passed.
- `python3 scripts/check-personal-data.py` — passed on tracked files.
- `git diff --check` — passed after documentation changes.
- PR CI run URL: pending.

## Decisions and open questions

- Keep the known-good UI behavior while extracting decisions into testable
  policies. Rendering is temporarily deferred while the popover is open.
- Confirm the proposed PEEK-282 roadmap ID and whether countdown rendering
  should remain deferred while the popover stays open.

## Exact next action

Run all local checks, build and test after the version bump, then create the
commit with a noreply email; push the branch and open a draft PR for review.
