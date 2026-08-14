# Peek Project Status

Last updated: 2026-08-14

## Overview

Peek is a lightweight macOS menu bar calendar companion. It surfaces upcoming events from the macOS Calendar app, adds urgency cues as meetings approach, and provides one-click join links for common meeting platforms.

This document replaces the previous ROADMAP, IMPLEMENTATION, and SECURITY docs. It reflects the current state of the project, what is done, what has been removed or descoped, and what remains to do.

## Current State

- App runs as a menu bar status item with a popover UI for event details.
- Calendar access is via EventKit, with user-selectable calendars and persisted preferences.
- Build and packaging scripts live in `scripts/`; local outputs go to `build/` and `artifacts/` and are ignored.
- Source follows a layered monolith with explicit App, Application, Domain, Infrastructure, and Presentation boundaries.
- Branding uses a reproducible app-icon and menu-bar asset pipeline documented in `DESIGN_SYSTEM.md`.
- The protected `Peek --export --from <signed-days> --to <signed-days> --json`
  interface exports schema v1 local-calendar JSON to stdout only. Its external
  Northwind Notes consumer is compatibility-sensitive and outside this repository.

## Done

- Menu bar status item with icon, tooltip, and selectable display modes.
- Status bar display modes: time until, actual time, or icon only.
- Basic icon-only fallback when Peek's allocated status-item width is constrained.
- Urgency cues: orange for 2 to under 10 minutes, red for under 2 minutes, and
  a critical pulse unless macOS Reduce Motion is enabled.
- Event list popover with keyboard navigation, selection, and context menu actions.
- Meeting link detection and one-click join for common providers.
- Calendar selection with persistence, plus first-launch defaults.
- Filtering: hide all-day events, hide declined events, filter by keywords.
- Lookahead range and max events configuration.
- Notifications with configurable lead time and join link action.
- Preferences for appearance, hotkey, status bar mode, and notification behavior.
- Basic unit tests under `PeekTests/`.
- GitHub Actions CI for unsigned macOS build and unit tests on `macos-latest`.
- Protocol boundaries for EventKit, notification scheduling, preferences, and launch-at-login behavior.
- Pure, tested status-bar content formatting.
- Architecture decisions, development workflow, design system, roadmap, security policy, and release checklist.
- Release script checks for strict nested signatures, expected entitlements,
  notarization staples, Gatekeeper assessment, and mounted-DMG integrity.

## Removed or Descoped

- Claude integration: previously documented, not implemented and not in scope.
- Preferences settings import/export: removed in 1.3.6.

## Priority backlog

- Physical validation on macOS 13, representative notched/external displays,
  and a clean account for permissions, notification delivery, VoiceOver,
  Increased Contrast, and Reduce Motion.
- A real signed/notarized artifact run with release credentials, followed by a
  clean-install Gatekeeper smoke test.
- Broader deterministic coverage for `UNUserNotificationCenter` rejection and
  pending-request failure paths, which system APIs do not expose directly here.

## Product backlog

- Quick event creation (natural language input, templates, calendar selection).
- Event details expansion refinements (attachments remain unavailable through macOS EventKit).
- Multiple time zone display.
- Additional context actions (email attendees, mark as declined, etc.).
- Custom color themes and per-event color rules.
- Platform-specific icons for meeting providers.
- Travel time integration and "leave now" alerts.
- Conflict detection and overlap warnings.
- Focus mode integration.
- Analytics and reporting.
- External integrations (email, contacts, Slack/Teams, task managers).
- Expanded test coverage.

## Security Posture

- HTTPS-only meeting URL validation with allowlist checks.
- Input sanitization and length limits for meeting URL extraction.
- No network requests or telemetry; all processing is local.
- Minimal permissions: Calendar Full Access for events and optional system
  notifications for reminders.

## Release assessment

The core feature set is suitable for internal and local use. Public distribution
is not release-ready until a real Developer ID/notarization run, clean-account
permission and Gatekeeper testing, physical accessibility/UI checks, and macOS
13 compatibility validation complete. See `RELEASE.md`.

## Notes

If any backlog items should be removed or re-prioritized, update this document to reflect the new scope.
