# Notification scheduling reliability

- **Status:** Complete
- **Roadmap ID:** PEEK-AUD-03
- **Owner:** Codex
- **Scope:** Surface notification authorization/scheduling failures to the user, verify that expected requests become pending, and retry a failed scheduling pass without logging event contents.
- **Owned files:** `Peek/Sources/Infrastructure/Notifications/NotificationManager.swift`, `Peek/Sources/Application/AppEnvironment.swift`, `Peek/Sources/Application/AppBehaviorSupport.swift`, `Peek/Sources/Application/Calendar/CalendarManager.swift`, `Peek/Sources/App/PeekApp.swift`, `Peek/Sources/Presentation/Preferences/PreferencesView.swift`, `Peek/Resources/en.lproj/Localizable.strings`, `PeekTests/Fakes/FakeNotificationScheduler.swift`, `PeekTests/GlobalHotkeyCoordinatorTests.swift`, `CHANGELOG.md`, `Configuration/Version.xcconfig`, `docs/{HANDOFF,ROADMAP}.md`.
- **Compatibility:** Does not alter `Peek --export`, JSON schema v1, EventKit selection semantics, notification content, or external Northwind Notes integration.
- **Plan:** Add a result-bearing scheduling seam, confirm additions through the pending-request API, show generic recoverable status in Preferences, and retry a failed pass with bounded cadence.
- **Files changed:** Notification manager, scheduling protocol/fake, feedback policy, calendar observable status, app retry handling, Preferences strings/view, focused tests, version/changelog, roadmap, and handoff.
- **Validation:** Focused unsigned tests for `CalendarManagerIntegrationTests` and `GlobalHotkeyCoordinatorTests` passed (20 tests, zero failures); final unsigned suite passed (95 tests, zero failures) on 2026-08-14.
- **Completed:** Added a result-bearing notification scheduling seam, pending-request verification, generic Preferences feedback, and a single 60-second retry for a failed scheduling pass. Scheduling errors no longer print error details.
- **Remaining risk:** `UNUserNotificationCenter` cannot be deterministically forced to reject or omit a request in the current test seam, so final delivery and permission transitions require PEEK-AUD-07 physical validation.
- **Exact next action:** Perform PEEK-AUD-07 physical notification permission and delivery validation on authorized hardware.
