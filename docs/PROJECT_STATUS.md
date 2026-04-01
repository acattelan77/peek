# Peek Project Status

Last updated: 2026-04-01

## Overview

Peek is a lightweight macOS menu bar calendar companion. It surfaces upcoming events from the macOS Calendar app, adds urgency cues as meetings approach, and provides one-click join links for common meeting platforms.

This document replaces the previous ROADMAP, IMPLEMENTATION, and SECURITY docs. It reflects the current state of the project, what is done, what has been removed or descoped, and what remains to do.

## Current State

- App runs as a menu bar status item with a popover UI for event details.
- Calendar access is via EventKit, with user-selectable calendars and persisted preferences.
- Build and packaging scripts live in `scripts/`; local outputs go to `build/` and `artifacts/` and are ignored.

## Done

- Menu bar status item with icon, tooltip, and selectable display modes.
- Status bar display modes: time until, actual time, or icon only.
- Automatic icon-only fallback when the menu bar is cramped.
- Urgency cues: orange for 2 to under 10 minutes, red with pulsing for under 2 minutes.
- Event list popover with keyboard navigation, selection, and context menu actions.
- Meeting link detection and one-click join for common providers.
- Calendar selection with persistence, plus first-launch defaults.
- Filtering: hide all-day events, hide declined events, filter by keywords.
- Lookahead range and max events configuration.
- Notifications with configurable lead time and join link action.
- Preferences for appearance, hotkey, status bar mode, and notification behavior.
- Export and import of settings (JSON) with version validation.
- Basic unit tests under `PeekTests/`.
- GitHub Actions CI for unsigned macOS build and unit tests.

## Removed or Descoped

- Claude integration: previously documented, not implemented and not in scope.

## Backlog (Not Yet Implemented)

- Quick event creation (natural language input, templates, calendar selection).
- Event details expansion (notes, attendees, attachments).
- Multiple time zone display.
- Additional context actions (email attendees, mark as declined, etc.).
- Custom color themes and per-event color rules.
- Platform-specific icons for meeting providers.
- Travel time integration and "leave now" alerts.
- Conflict detection and overlap warnings.
- Focus mode integration.
- Analytics and reporting.
- External integrations (email, contacts, Slack/Teams, task managers).
- Accessibility improvements (VoiceOver, keyboard-only navigation, adjustable font sizes).
- Expanded test coverage.

## Security Posture

- HTTPS-only meeting URL validation with allowlist checks.
- Input sanitization and length limits for meeting URL extraction.
- No network requests or telemetry; all processing is local.
- Minimal permissions: calendar access only.

## Notes

If any backlog items should be removed or re-prioritized, update this document to reflect the new scope.
