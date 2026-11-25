# HUD presentation history bound

- **Status:** Complete
- **Roadmap ID:** PEEK-AUD-06
- **Owner:** Codex
- **Scope:** Bound and deterministically prune the `Starting now` HUD deduplication history without changing when a valid event is first shown.
- **Owned files:** `Peek/Sources/App/StartingNowHUDController.swift`, `Peek/Sources/Application/AppBehaviorSupport.swift`, `PeekTests/GlobalHotkeyCoordinatorTests.swift`, `README.md`, `CHANGELOG.md`, `Configuration/Version.xcconfig`, `docs/workstreams/hud-presentation-history.md`, `docs/{HANDOFF,ROADMAP}.md`.
- **Compatibility:** No EventKit selection, notification, UI content, PEEK-111 CLI/JSON v1, or external integration changes.
- **Plan:** Extract the retention decision into a pure testable type, prune history based on event end time, retain a short fallback for malformed/zero-duration entries, and add regression coverage.
- **Completed:** Replaced the unbounded event-ID set with an expiry-based history. Expired events are pruned before HUD decisions and long-running sessions retain at most 256 entries; malformed/zero-duration events remain deduplicated for 60 seconds.
- **Files changed:** HUD controller, pure history policy, focused tests, version/changelog, README version, roadmap, and handoff.
- **Validation:** Focused unsigned `GlobalHotkeyCoordinatorTests` passed (8 tests, zero failures); final unsigned suite passed (95 tests, zero failures) on 2026-08-14.
- **Exact next action:** Perform PEEK-AUD-07 visual HUD smoke testing on authorized macOS hardware.
