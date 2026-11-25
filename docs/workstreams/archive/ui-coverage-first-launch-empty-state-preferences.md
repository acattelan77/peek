# Workstream: UI coverage for first launch, empty state, and preferences

- Roadmap ID: PEEK-103
- Status: Complete
- Owner: Codex
- Branch/worktree: Current main worktree
- Last updated: 2026-07-15

## Objective

Add test coverage for the menu-bar popover and preferences UI so first-launch, denied calendar access, empty-state, event-list, and preference-interaction flows can be validated without manual launches.

## Scope

- Inspect `MenuBarView`, `PreferencesView`, and any view-state helpers to identify testable seams.
- Add unit/integration tests using fakes where possible for:
  - First launch / no calendar access state.
  - Denied calendar access messaging.
  - Empty upcoming-events state.
  - Event list rendering and selection.
  - Preference toggles and persistence.
- Update the Xcode project for any new test files.
- Bump version and update changelog/handoff.

## Out of scope

- Adding a separate XCTest UI test target (stay in the existing unit-test target).
- Refactoring views beyond what is needed for testability.
- Real user-notification or calendar-permission flows.

## Claimed files and subsystems

- `Peek/Sources/Presentation/MenuBar/MenuBarView.swift`
- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `PeekTests/` (new tests)
- `Peek.xcodeproj/project.pbxproj`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `Configuration/Version.xcconfig`

## Dependencies

- PEEK-101 complete (space policy and status-bar behavior).
- PEEK-102 complete (fake event store and notification scheduler).

## Progress

- [x] Inspect existing views and identify testable seams
- [x] Add first-launch / denied access tests
- [x] Add empty-state and event-list tests
- [x] Add preferences interaction tests
- [x] Update Xcode project for new tests
- [x] Bump version and update changelog/handoff
- [x] Validate build and tests

## Validation

- Debug build succeeded.
- 58 tests passed with zero failures.
- `bash scripts/check-version.sh` passed.
- `git diff --check` passed.

## Decisions and open questions

- Tests use `@testable import Peek` and the existing fakes from PEEK-102 where applicable.
- `CalendarManager.hasCustomCalendarSelection` was changed from `private` to `private(set)` so tests can assert on it.
- Calendar-selection tests that recreate `CalendarManager` after seeding calendars must clear the `enabledCalendarIDs` and `hasCustomCalendarSelection` keys first, because `setUp` eagerly creates a manager that persists an empty first-launch selection.

## Exact next action

None — workstream is complete. Next priority is PEEK-104.
