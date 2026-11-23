# Roadmap

Roadmap items are ordered by product risk and architectural leverage. Dates are intentionally omitted until a release owner assigns them.

## Delivery protocol

Every actionable item has a stable ID and a state. `Ready` means an agent may claim it by creating an active file in `docs/workstreams/`; `Active` means the workstream file names its owner and branch; `Blocked` must include the blocking condition; `Done` means the change is integrated and validated. `docs/HANDOFF.md` is the concise integrated-state record and takes precedence over stale workstream notes.

Before starting an item, follow `AGENTS.md`, confirm that no active workstream claims the same files or subsystem, and copy `docs/workstreams/TEMPLATE.md`. When pausing or finishing, update the workstream and handoff in the same change.

## Now — audit remediation plan

- **PEEK-AUD-01 — Done:** EventKit store-change refresh delivery is confined to the main thread, with regression coverage that posts the change notification from a background queue. The existing calendar UI and PEEK-111 export contract remain unchanged. Physical Calendar-change UI validation remains part of PEEK-AUD-07.
- **PEEK-AUD-02 — Done:** The critical-event status-item pulse honors the system Reduce Motion preference, with focused policy coverage. Physical accessibility validation remains part of PEEK-AUD-07.
- **PEEK-AUD-03 — Done:** Notification scheduling reports authorization and scheduling results through a testable seam, verifies expected pending requests, surfaces generic recoverable feedback in Preferences, and retries failed passes after 60 seconds without logging calendar content.
- **PEEK-AUD-04 — Done:** The release script fails closed unless strict app signature, expected entitlements, notarization stapling, Gatekeeper assessment, DMG integrity, and mounted-DMG contents checks pass. A real signed/notarized run still requires release credentials and tag authority.
- **PEEK-AUD-05 — Done:** README, development, project-status, and security documentation now reflect the current version, single `macos-latest` CI runner, removed settings import/export, protected PEEK-111 export boundary, and release evidence limitations.
- **PEEK-AUD-06 — Done:** The Starting now HUD deduplication history prunes expired events and has a deterministic 256-entry bound, with focused duplicate, expiry, and long-session coverage.
- **PEEK-AUD-07 — Blocked:** Complete physical release validation on real macOS 13 hardware and representative notched/external displays, including Full Access transitions, notification delivery, VoiceOver, Increased Contrast, and Reduce Motion. Computer Use timed out again on 2026-08-14 before interaction (error `-10005`); suitable hardware and user-authorized permission/UI checks remain required.

## Now — reliability and release readiness

- **PEEK-101 — Done:** Add notch-safe adaptive compact mode for crowded menu bars. Peek should proactively fall back to its icon before macOS hides the status item, restore text when space returns, and avoid rapid mode switching. Provide `Automatic`, `Always show icon`, and `Always show text` preferences, with `Automatic` as the default.
- **PEEK-102 — Done:** Add fake EventKit and notification schedulers for authorization, refresh, and reminder integration tests.
- **PEEK-103 — Done:** Add UI coverage for first launch, denied calendar access, empty state, event list, and preferences.
- **PEEK-104 — Done:** Make the global hotkey update without restarting and surface registration conflicts. Live re-registration through a testable `GlobalHotkeyCoordinator`; API-reported registration failures shown in Preferences. Cross-app conflicts that Carbon does not report remain undetectable (documented limitation).
- **PEEK-105 — Done (superseded):** Added visible success/error feedback for settings import and export. The import/export feature was later removed in 1.3.6 to simplify Preferences.
- **PEEK-106 — Done (partial):** Validate macOS 13 behavior. The CI-hosted `macos-13` runner was removed because GitHub is retiring it and jobs hung queued indefinitely; validation on real macOS 13 hardware is still outstanding.
- **PEEK-107 — Done:** Establish Developer ID signing, notarization, Sparkle or another update policy, and a release workflow.
- **PEEK-108 — Done:** Complete VoiceOver labels, focus order, and keyboard activation. Type uses fixed, centralized roles (macOS has no Dynamic Type for third-party apps; corrected 2026-11-23).
- **PEEK-109 — Done:** Fix automatic menu-bar space policy so a crowded menu bar (including macOS having hidden Peek's item entirely) collapses Peek to its clickable icon; restore text when space returns.
- **PEEK-110 — Done:** Event detail expansion: events in the popover are now bordered cards (the next event keeps its urgency color coding) that expand in place to show notes, attendees with response status and the organizer, and conference provider identity. Attachments are omitted because macOS EventKit does not expose `EKAttachment` (iOS-only).
- **Design refresh — Done:** Adopt the Claude Design "calm glance" system via a shared token layer applied across the popover, Preferences, new onboarding flow, and "Starting now" HUD; re-render the app icon (handoff §6). Follow-up: visual QA on a running build. Fixed alongside: accessory-app popover activation so the popover stays open and controls render active.
- **Design system v2 — In review:** Semantic color roles with Increased Contrast variants, WCAG AA contrast fixes, full token adoption on every surface, promoted shared components, CI token lint and contrast tests (1.6.0, `docs/workstreams/design-system-v2.md`). Awaits owner visual QA on a Mac.

## Now — Peek 2.0 phase 1: never miss a meeting

Plan: "Peek: piano di sviluppo verso l'App Store" (phase 0 mockups approved 2026-11-23). Workstream: `docs/workstreams/phase-1-never-miss-a-meeting.md`. All four items ship in 1.7.0 and await owner checks on a Mac.

- **PEEK-201 — In review:** Compact read-only month calendar above the event list, with a day agenda; can be hidden in Preferences.
- **PEEK-202 — In review:** Broader meeting-link detection (Zoom variants, Teams personal, Meet lookup, GoTo, Slack, Chime, Jitsi, FaceTime, RingCentral) and Join in the Zoom or Teams app when installed. Export JSON v1 join classification frozen.
- **PEEK-203 — In review:** Start alert choice (off, heads-up card, full screen over all Spaces and full-screen apps), with full screen limited by default to events with a join link or attendees. Focus status is not read yet.
- **PEEK-204 — In review:** Italian, German, French and Spanish localization with a CI table check.

## Now — Peek 2.0 phase 2: meeting context

Workstream: `docs/workstreams/phase-2-meeting-context.md`. Ships in 1.8.0, stacked on phase 1.

- **PEEK-211 — In review:** Attendees matched with Contacts (opt-in) for the "You're about to meet" headline and attendee roles; email-domain fallback.
- **PEEK-212 — In review:** Invitation boilerplate removed from notes.
- **PEEK-213 — In review:** Read-only meeting-context file in a user-chosen folder (ADR 0004, proposed); the Northwind Notes writer is not built yet.
- **PEEK-214 — Deferred:** Google Calendar direct access, after 2.0.

## Next — calendar usefulness

- **PEEK-111 — Done:** Headless local EventKit calendar export CLI for external local-cache renderers. `Peek --export --from <signed-days> --to <signed-days> --json` emits only versioned JSON on stdout, honors Peek's persisted calendar selection, never writes Northwind Notes files, and exits non-zero without existing Full Access or on an EventKit error.
- Conflict and overlap warnings.
- Multiple time-zone display.
- Quick event creation with explicit confirmation and calendar selection.
- Better Calendar deep linking when the OS exposes a stable event destination.
- Travel-time and leave-now reminders.

## Later — focused integrations

- Focus mode integration.
- Email-attendee and decline actions with explicit permission boundaries.
- Optional Slack, Teams, and task-manager integrations behind independent adapters.
- User-defined event color rules and themes.
- Local-only analytics summaries; no telemetry without a separate privacy decision.

## Explicitly out of scope

- Cloud accounts or a Peek backend.
- Advertising or behavioral telemetry.
- Replacing macOS Calendar as the source of truth.
- Broad AI features without a concrete local-first use case and privacy design.

## Definition of release-ready

A release candidate must pass the test suite, a signed Release build, the manual checklist in `RELEASE.md`, accessibility smoke testing, and notarization validation on a clean macOS account.
