# Workstream: Fake EventKit and notification schedulers

- Roadmap ID: PEEK-102
- Status: Complete
- Owner: Codex
- Branch/worktree: Current main worktree
- Last updated: 2026-07-15

## Objective

Make `CalendarManager` and notification scheduling testable end-to-end by introducing fake implementations of `CalendarEventStoring` and `NotificationScheduling`, closing the last EventKit boundary so authorization, refresh, and reminder flows can be exercised without real calendar or notification permissions.

## Scope

- Add `authorizationStatus(for:)` to `CalendarEventStoring` and implement it in `EventKitCalendarEventStore`.
- Update `CalendarManager.refreshAuthorizationStatus()` to use the injected event store.
- Create `FakeCalendarEventStore` in the test target with in-memory `EKCalendar`/`EKEvent` support and controllable authorization results.
- Create `FakeNotificationScheduler` in the test target that records permission and scheduling calls.
- Add integration tests covering authorization, refresh, calendar filtering, EventStore-changed refresh, and notification scheduling.
- Update Xcode project, changelog, version, and handoff.

## Out of scope

- Extracting AppDelegate's notification scheduling into a separate coordinator.
- Real `UNUserNotificationCenter` testing.
- UI tests (PEEK-103) or global hotkey live update (PEEK-104).

## Claimed files and subsystems

- `Peek/Sources/Infrastructure/Calendar/CalendarEventStore.swift`
- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `PeekTests/Fakes/FakeCalendarEventStore.swift` (new)
- `PeekTests/Fakes/FakeNotificationScheduler.swift` (new)
- `PeekTests/CalendarManagerIntegrationTests.swift` (new)
- `Peek.xcodeproj/project.pbxproj`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `Configuration/Version.xcconfig`

## Dependencies

- PEEK-101 complete (integrated state is up to date).

## Progress

- [x] Create workstream file
- [x] Extend calendar boundary and update CalendarManager
- [x] Create fakes
- [x] Add integration tests
- [x] Update Xcode project
- [x] Bump version and update changelog/handoff
- [x] Validate build and tests

## Validation

- `bash scripts/check-version.sh` → version 1.2.0 (7) valid.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build` → succeeded.
- `xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test` → 44 tests passed, 0 failures.
- `git diff --check` → clean.

## Decisions and open questions

- Fakes live in the test target to avoid shipping test code in the app.
- `EKCalendar`/`EKEvent` objects are created in memory using a private `EKEventStore`; they are not persisted, so identifiers may be nil. Tests assert on title/startDate where identifiers are needed.
- Peek source files were removed from the `PeekTests` target and tests now rely on `@testable import Peek`; `TEST_HOST`/`BUNDLE_LOADER` were configured so the test bundle links against the built app.
- Integration tests use isolated `UserDefaults` suites to avoid pollution from the host app or other tests.

## Exact next action

None — workstream complete. The next ready roadmap item is PEEK-103 (UI coverage for first launch, denied calendar access, empty state, event list, and preferences).
