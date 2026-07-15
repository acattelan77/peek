# Project handoff

Last updated: 2026-07-15

## Read this first

Peek is currently at **1.2.1 (build 9)**. The repository has been reorganized into a layered monolith and the app has a refreshed icon and popover presentation. Inspect `git status` before working: the architecture, documentation, and visual upgrade may still be uncommitted in the current worktree.

## Integrated state

- Source layers: App, Application, Domain, Infrastructure, and Presentation.
- Service boundaries: EventKit, notification scheduling, preferences, and launch at login.
- Documentation: architecture, roadmap, development, design system, release, security, versioning, and ADRs.
- Brand assets: generated app-icon family and deterministic template menu-bar icon.
- Reliability fixes: notification disabling, conditional notification permission, Zoom password preservation, and next-event ordering.
- PEEK-101 integrated: notch-safe adaptive compact mode with `Automatic`, `Always show icon`, and `Always show text` space policies, hysteresis, and notched-display margin.
- PEEK-102 integrated: fake `CalendarEventStoring` and `NotificationScheduling` test doubles plus `CalendarManager` integration tests covering authorization, refresh, calendar filtering, and notification scheduling.
- PEEK-103 integrated: menu-bar and preferences integration tests covering first-launch calendar defaults, denied access, empty state, event-list behavior, persistence, import/export, and view instantiation, plus a fake launch-at-login controller.
- PEEK-104 integrated: the global hotkey now re-registers live when changed in Preferences (no restart), triggering it activates the app so the popover surfaces above other windows, and API-reported registration failures are shown in the General tab. Carbon registration lives in `CarbonHotkeyRegistrar` (composition root) behind a `HotkeyRegistering` seam, with the decision policy in the testable `GlobalHotkeyCoordinator`.
- Last full validation: Debug build succeeded; 62 tests passed with zero failures on 2026-07-15. Compiled bundle metadata reports 1.2.1 (9).

## Where to start next

PEEK-101 through PEEK-104 are complete. The next highest-priority ready items are in `docs/ROADMAP.md`:

- **PEEK-105:** Add visible success/error feedback for settings import and export.
- **PEEK-108:** Complete VoiceOver labels, focus order, keyboard activation, and Dynamic Type-style scaling.

Pick one, create a workstream from `docs/workstreams/TEMPLATE.md`, and follow the validation steps in `AGENTS.md`.

## Known limitations from PEEK-104

- Carbon's `RegisterEventHotKey` cannot report a combination already claimed by another application; it may succeed and simply never fire. Only failures the API itself returns are surfaced. A future improvement could verify the key event is received after registration.

## Known constraints

- Public distribution is not ready: Developer ID signing and notarization are still outstanding.
- `CalendarManager` and `AppDelegate` remain larger than the target architecture recommends.
- The new space policy uses a conservative notch margin; real-world validation on multiple notched and external display setups is welcome.

## Active workstreams

See `docs/workstreams/`. A workstream is active only when its file says `Status: Active`.
