# Roadmap

Roadmap items are ordered by product risk and architectural leverage. Dates are intentionally omitted until a release owner assigns them.

## Delivery protocol

Every actionable item has a stable ID and a state. `Ready` means an agent may claim it by creating an active file in `docs/workstreams/`; `Active` means the workstream file names its owner and branch; `Blocked` must include the blocking condition; `Done` means the change is integrated and validated. `docs/HANDOFF.md` is the concise integrated-state record and takes precedence over stale workstream notes.

Before starting an item, follow `AGENTS.md`, confirm that no active workstream claims the same files or subsystem, and copy `docs/workstreams/TEMPLATE.md`. When pausing or finishing, update the workstream and handoff in the same change.

## Now — reliability and release readiness

- **PEEK-101 — Done:** Add notch-safe adaptive compact mode for crowded menu bars. Peek should proactively fall back to its icon before macOS hides the status item, restore text when space returns, and avoid rapid mode switching. Provide `Automatic`, `Always show icon`, and `Always show text` preferences, with `Automatic` as the default.
- **PEEK-102 — Done:** Add fake EventKit and notification schedulers for authorization, refresh, and reminder integration tests.
- **PEEK-103 — Done:** Add UI coverage for first launch, denied calendar access, empty state, event list, and preferences.
- **PEEK-104 — Ready:** Make the global hotkey update without restarting and surface registration conflicts.
- **PEEK-105 — Ready:** Add visible success/error feedback for settings import and export.
- **PEEK-106 — Ready:** Validate macOS 13 behavior on real or CI-hosted macOS 13 hardware.
- **PEEK-107 — Ready:** Establish Developer ID signing, notarization, Sparkle or another update policy, and a release workflow.
- **PEEK-108 — Ready:** Complete VoiceOver labels, focus order, keyboard activation, and Dynamic Type-style scaling.

## Next — calendar usefulness

- Event detail expansion: notes, attendees, attachments, and conference provider identity.
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
