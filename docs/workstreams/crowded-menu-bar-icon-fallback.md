# Workstream: Reliable icon fallback for crowded menu bars

- Roadmap ID: PEEK-109
- Status: Complete
- Owner: Codex
- Branch/worktree: Current main worktree
- Last updated: 2026-07-17

## Objective

Make the `Automatic` menu-bar space policy actually fall back to Peek's icon when the menu bar is crowded (including when macOS has hidden Peek's item entirely), so the icon remains clickable to open the popover.

## Scope

- Introduce a testable `StatusBarSpaceMetrics` computation that reports real room before macOS hides the status item.
- Use `NSScreen.auxiliaryTopRightArea.minX` as the hiding frontier on notched displays.
- Detect when macOS has hidden Peek's item (`button.window` nil after first layout) and report zero room so the policy collapses to icon.
- Add a sticky latch for non-notched displays where the frontier is unknowable; clear the latch on display-configuration changes or when the user changes the space policy.
- Keep `StatusBarSpacePolicy` and `StatusBarContentBuilder` unchanged.
- Add unit tests for the new metric.
- Update workstream, ROADMAP, CHANGELOG, HANDOFF, and version.

## Out of scope

- Changes to Preferences UI or localized strings.
- Private API usage (e.g. SkyLight) to detect other apps' items.
- Global menu-bar layout observers.

## Claimed files and subsystems

- `Peek/Sources/Application/StatusBarSpaceMetrics.swift` (new)
- `Peek/Sources/App/PeekApp.swift`
- `PeekTests/StatusBarSpaceMetricsTests.swift` (new)
- `Peek.xcodeproj/project.pbxproj`
- `CHANGELOG.md`
- `docs/ROADMAP.md`
- `docs/HANDOFF.md`
- `Configuration/Version.xcconfig`

## Dependencies

- None.

## Progress

- [x] Create workstream file
- [x] Add `StatusBarSpaceMetrics` and wire into `AppDelegate`
- [x] Add unit tests
- [x] Register files in Xcode project
- [x] Bump version and update changelog/handoff
- [x] Validate build and tests

## Validation

- `bash scripts/check-version.sh` passed.
- Debug build succeeded.
- 69 tests passed with zero failures (6 new `StatusBarSpaceMetricsTests`).
- `git diff --check` passed.
- Real crowded-menu-bar behavior needs manual verification on a physical notched Mac.

## Decisions and open questions

- The `availableWidth` calculation is changing from "distance to right screen edge" to "distance from item's left edge to the notch's right edge on notched displays".
- Non-notched displays fall back to hidden-item detection plus a sticky latch because the front-app menu boundary is not measurable via public API.
- Real-world crowded-menu-bar behavior needs manual verification on a physical notched display; unit tests cover the pure metric only.

## Exact next action

None — workstream complete. Integrator should review the diff, validate on a physical
notched Mac with a crowded menu bar, and commit when authorized.
