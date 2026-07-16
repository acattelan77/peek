# Changelog

This project follows Keep a Changelog conventions. Versions are released from `main`.

## Unreleased

## 1.3.1 - 2026-07-16

### Fixed

- The popover now reliably stays open when clicking the menu-bar item. As an accessory app, Peek was not activating on a status-item click, so the transient popover was dismissed immediately ("opens then closes") and its controls — including Preferences toggles — rendered in the greyed inactive appearance. Peek now activates when the popover opens, so it stays open and active-state controls (e.g. switches) render in the accent color.

## 1.3.0 - 2026-07-15

### Added

- Adopted the Claude Design "calm glance" design system across the app via a shared token
  layer (`PeekColor`, `PeekFont`, `PeekSpacing`, `PeekRadius`, `PeekElevation`) and reusable
  components (badges, count pill, inset cards, button styles, focus ring).
- Redesigned popover: date-stamped header, a hero "NEXT" row with an accent rail, wash,
  countdown, and provider-aware Join button, plus escalating SOON/NOW urgency variants.
- Refreshed empty and no-access states ("You're all clear" / "Calendar access needed" with
  an Open System Settings action).
- New first-run onboarding flow (welcome → calendar access → pick calendars), shown once.
- New "Starting now" heads-up card (top-right) with Join, Snooze 5 min, and dismiss.
- Redesigned Preferences using inset cards, group labels, segmented/menu controls, and
  accent-tinted switches.

### Changed

- Menu-bar urgency title tints now use the design palette (amber `#E8912B`, red `#E5484D`).

## 1.2.5 - 2026-07-15

### Added

- CI matrix now includes a `macos-13` runner for automated macOS 13 build/test validation (PEEK-106).

## 1.2.4 - 2026-07-15

### Added

- GitHub Actions `release.yml` workflow and `scripts/release.sh` for building a Developer ID-signed, notarized, stapled DMG on version tags (PEEK-107).
- Documented required release secrets, release steps, and GitHub Releases update policy in `docs/RELEASE.md` (PEEK-107).

## 1.2.3 - 2026-07-15

### Added

- VoiceOver labels and values for the menu-bar popover event list, status-item button, and Preferences controls (PEEK-108).
- Keyboard activation for Preferences radio rows and for opening the selected event's meeting link with Return or Space in the popover (PEEK-108).
- Dynamic Type-style text styles for user-facing text in the popover and Preferences (PEEK-108).

## 1.2.2 - 2026-07-15

### Added

- Visible success and error feedback after importing or exporting settings in Preferences (PEEK-105).

## 1.2.1 - 2026-07-15

### Changed

- The global hotkey now updates immediately when changed in Preferences; no app restart is required (PEEK-104).
- Triggering Peek with the global hotkey now brings the app forward so the popover reliably appears above the frontmost window (PEEK-104).

### Fixed

- Failed global-hotkey registration (for example, a shortcut another app already owns) is now surfaced in Preferences instead of only printing to the console (PEEK-104).
- The event notification category (Join/Snooze actions) is now registered once at startup instead of repeatedly inside the per-event scheduling loop, so notification actions are reliable regardless of which events have meeting links.
- The event row no longer force-unwraps an event's calendar, preventing a potential crash for events without an associated calendar.

## 1.2.0 - 2026-07-15

### Added

- Fake EventKit event store and notification scheduler for isolated integration tests (PEEK-102).
- CalendarManager integration tests covering authorization, refresh, calendar filtering, and notification scheduling (PEEK-102).
- Menu-bar and preferences integration tests covering first-launch calendar defaults, denied access, empty state, event-list behavior, persistence, import/export, and view instantiation (PEEK-103).
- Fake launch-at-login controller for `PreferencesView` tests (PEEK-103).
- Notch-safe adaptive compact mode for crowded menu bars (PEEK-101).
- New menu-bar space policy with `Automatic`, `Always show icon`, and `Always show text` options.
- Hysteresis in the space policy to prevent rapid text/icon oscillation near the width threshold.
- Notch detection that reserves extra margin on notched displays so Peek falls back to its icon earlier.
- Migration of the previous `Icon Only` display mode to the new `Always show icon` space policy.

### Changed

- `StatusBarDisplayMode` now only controls time format (`Time Until` / `Actual Time`); icon-vs-text behavior is handled by `MenuBarSpacePolicy`.

### Fixed

- `CalendarManager.refreshAuthorizationStatus()` now updates `hasCalendarAccess` synchronously so callers and observers see consistent state immediately.

## 1.1.0 - 2026-07-15

### Added

- Layered source architecture and live dependency composition.
- EventKit, notification, and preferences service boundaries.
- Testable status-bar content builder.
- Architecture, roadmap, development, design, release, security, and decision documentation.
- Reproducible app and menu-bar asset generator.
- Refreshed blue-indigo calendar-fold identity.
- Repository-level multi-agent contract, integrated handoff, and workstream ownership protocol.
- Central version configuration, bump/check tooling, CI validation, and version display in Preferences.

### Changed

- Ongoing events outside the grace window no longer precede the actual next event.
- Zoom links preserve password query parameters.
- Notification permission is requested only after notifications are enabled.

### Fixed

- Selecting disabled notification timing now removes pending event reminders.
