# Roadmap

This is the single place for Peek's current state, priorities and what is
missing. Versions are in `CHANGELOG.md`; the physical checks are in
`docs/MAC_CHECKS.md`; who is working on what is in `docs/workstreams/`.

## States

| State | Meaning |
| --- | --- |
| `Ready` | Scoped; an agent may claim it with a workstream file |
| `Active` | A top-level workstream file names its owner and branch |
| `Blocked` | Cannot proceed; the line says on what and on whom |
| `Shipped` | Merged to `main` with CI green; the owner's checks on a Mac are pending in `docs/MAC_CHECKS.md` |
| `Done` | Shipped and validated, including any physical check |
| `Deferred` | Agreed, but not before the first public release |
| `Dropped` | Removed or superseded; kept for traceability |

IDs are stable and never reused. New items take the next free number in their
range.

## Current state

Last reviewed 2026-11-25, with `main` at 1.16.1.

The app is feature-complete for its first public release: phases 1 to 4 of the
Peek 2.0 plan, the Peek 2.0 mockup alignment, App Store packaging and the
pre-release robustness work are all on `main`. Nothing has been published: there
is no App Store build and no notarized DMG yet, because the Apple-side setup and
signing secrets are still missing. The owner uses the ad-hoc test installer
built from `main`.

What stands between `main` and a public release is, in order: the owner's checks
on a Mac, the owner's product decisions, Apple-side setup and signing, and the
first TestFlight round. See "Release path" below.

## Release path

The first public release ships on the Mac App Store and as a Developer ID
signed, notarized DMG (owner decision, 2026-11-23). App Store submission is the
last step and is the owner's.

1. **Checks on a Mac — Blocked on the owner.** Every `Shipped` item below has its
   checks in `docs/MAC_CHECKS.md`. PEEK-AUD-07 (clean account, macOS 13 hardware,
   notched and external displays, VoiceOver, Increased Contrast, Reduce Motion)
   also needs hardware that is not available yet.
2. **Owner decisions — Blocked on the owner.** App name, bundle ID (`com.peek.app`
   may be taken; the `PEEK_BUNDLE_ID` repository variable overrides it for the
   store build), price, category, privacy-label stance, privacy policy URL,
   and whether the full-screen alert should respect Focus. The license is
   decided: MIT, open source (owner, 2026-11-25).
3. **Apple-side setup — Blocked on the owner.** App Store Connect API key, App ID
   and app record, then the App Store and Developer ID secrets listed in
   `docs/APP_STORE.md` and `docs/RELEASE.md`.
4. **Signing-dependent work — Blocked on step 3.**
   * **PEEK-255 — Blocked:** add the time-sensitive notification entitlement
     with App Store and Developer ID provisioning, so PEEK-272's time-sensitive
     reminders break through Focus. Check on TestFlight.
   * **PEEK-253 — Shipped:** first "App Store" workflow run with Upload off; an
     agent fixes what it reports; then a run with Upload on for TestFlight.
   * Verify on TestFlight that the sandboxed App Store binary still serves
     `--export` to an external consumer, and that the Claude API key saved by
     the DMG build is found or can be entered again.
5. **PEEK-256 — Blocked on a native reader:** native review of the German,
   French and Spanish translations (the Italian copy follows the mockups).
6. **TestFlight round and submission — owner.** Follow "TestFlight plan" in
   `docs/APP_STORE.md`, then submit for review.

## In progress — pending review

* **PEEK-282 — Active (target 1.16.2):** stabilize the popover's opening
  anchor on multi-display setups while keeping the menu-bar countdown live;
  align countdown minute rounding with the popover. Local XCTest suite and
  Release build passed; contributor's physical checks passed on the reported
  external-display setup. Further display-arrangement checks, maintainer
  review and PR CI verification remain open.
  Workstream: `docs/workstreams/multimonitor-popover.md`.

## Shipped, awaiting checks on a Mac

All merged to `main` between 1.6.0 and 1.16.1. Checks in `docs/MAC_CHECKS.md`.

**Design**

* **Design system v2 — Shipped (1.6.0):** semantic color roles with Increased
  Contrast variants, WCAG AA fixes, tokens on every surface, CI token lint and
  contrast tests.
* **PEEK-241 — Shipped (1.11.0):** popover, meeting page, full-screen alert and
  Preferences follow the approved Peek 2.0 mockup, light and dark; the footer
  keeps its icon buttons (owner decision, 2026-11-24).
* **PEEK-242 — Shipped (1.12.0):** five menu-bar states, the alert ladder, the
  2-minute heads-up card, badge-only calendars.

**Never miss a meeting (phase 1, 1.7.0)**

* **PEEK-201 — Shipped:** compact read-only month calendar with a day agenda.
* **PEEK-202 — Shipped:** broader join-link detection; Join opens the Zoom or
  Teams app. Export v1 classification frozen.
* **PEEK-203 — Shipped:** start alert choice: off, card, or full screen over all
  Spaces (by default only for meetings with a link or attendees).
* **PEEK-204 — Shipped:** Italian, German, French and Spanish, with a CI table
  check. Native review is PEEK-256.

**Meeting context (phase 2, 1.8.0)**

* **PEEK-211 — Shipped:** attendees matched with Contacts (opt-in), email-domain
  fallback.
* **PEEK-212 — Shipped:** invitation boilerplate removed from notes.
* **PEEK-213 — Shipped:** read-only meeting-context file in a user-chosen folder
  (ADR 0004).

**Meeting brief (phase 3, 1.9.0; ADR 0005)**

* **PEEK-221 — Shipped:** on-device brief with Apple Foundation Models (macOS 26).
* **PEEK-222 — Shipped:** optional Claude brief with the user's API key in the
  keychain.
* **PEEK-223 — Shipped:** versioned consent screen listing the fields sent; off by
  default; keyword exclusions.
* **PEEK-224 — Shipped:** briefs prepared 15 minutes before, cached three days,
  invalidated on change; a brief in the context file wins and calls no model.

**Join, countdown and time zones (phase 4, 1.10.0)**

* **PEEK-231 — Shipped:** global "Join next meeting" shortcut (⌃⌥J).
* **PEEK-232 — Shipped:** countdown to meetings only; name the person in the menu
  bar.
* **PEEK-233 — Shipped:** up to six world clocks and the meeting's time in them.

**Day priorities and links from the context file (1.13.0)**

* **PEEK-261 — Shipped:** optional `day` object; today's priorities above the next
  meeting.
* **PEEK-262 — Shipped:** `obsidian://` joins `https://` on the context-link
  allowlist; opened only on click.
* **PEEK-263 — Shipped:** prep count and first point in the notification and the
  2-minute card.
* **PEEK-264 — Shipped:** context older than 36 hours hides the day block and is
  dated on the meeting page.

**Pre-release robustness (1.13.1 to 1.16.1)**

* **PEEK-275 — Shipped (1.13.1):** local diagnostics without meeting content,
  MetricKit, "Export diagnostics" (ADR 0006).
* **PEEK-271 — Shipped (1.14.0):** wake, time-zone, clock and day changes
  reschedule everything; absolute notification instants; late-start alerts.
* **PEEK-272 — Shipped (1.14.0):** 60-notification cap, one per recurring
  occurrence, cross-calendar dedupe, time-sensitive flag (entitlement is
  PEEK-255).
* **PEEK-273 — Shipped (1.15.0):** mute or hide an event or a series; Ignore on the
  2-minute card; restore list in Preferences.
* **PEEK-274 — Shipped (1.16.0):** discreet mode (manual, ⌃⌥D, automatic on display
  mirroring). Zoom, Meet and Teams screen sharing cannot be detected: no public
  API.
* **PEEK-276 — Shipped (1.16.1):** meeting page formatting with a context-file
  headline; card buttons stay on one line.

**App Store readiness (1.12.5; workstream `app-store-readiness.md`)**

* **PEEK-251 — Shipped:** privacy manifest and export-compliance key, checked in CI.
* **PEEK-252 — Shipped:** sandbox entitlements reviewed; bundle check script.
* **PEEK-253 — Shipped:** App Store archive, export and TestFlight upload workflow;
  never run yet (step 4 of the release path).
* **PEEK-254 — Shipped:** owner guide in `docs/APP_STORE.md`.

## Done

Integrated and validated by tests; their remaining physical checks are folded
into PEEK-AUD-07.

* **PEEK-101** notch-safe compact menu bar · **PEEK-102** fake EventKit and
  notification schedulers · **PEEK-103** UI coverage for first launch, denied
  access, empty state and Preferences · **PEEK-104** live hotkey re-registration
  · **PEEK-106** macOS 13 (partial: CI runner retired, hardware check in
  PEEK-AUD-07) · **PEEK-107** Developer ID release workflow (never run with real
  secrets) · **PEEK-108** VoiceOver labels, focus order, keyboard activation ·
  **PEEK-109** crowded-menu-bar icon fallback · **PEEK-110** event detail
  expansion (later replaced by the meeting page in PEEK-241) · **PEEK-111**
  headless calendar export (ADR 0003) · design refresh 1.3.x and app icon.
* **PEEK-AUD-01..06** audit remediation: EventKit refresh on the main thread,
  Reduce Motion pulse, notification scheduling feedback and retry, fail-closed
  release verification, documentation, bounded HUD history.
* **PEEK-AUD-07 — Blocked:** physical release validation; see step 1 above and
  `docs/workstreams/physical-release-validation.md`.

**Dropped:** PEEK-105 settings import/export feedback (the feature was removed
in 1.3.6).

## After the first release

* **PEEK-214 — Deferred:** Google Calendar direct access.
* **PEEK-277 — Deferred:** keyboard shortcuts inside the popover (join, snooze,
  mute from the list).
* **PEEK-278 — Deferred:** App Intents and Shortcuts actions (next meeting, join,
  discreet mode).
* **PEEK-279 — Deferred:** quick event creation with explicit confirmation and
  calendar choice; scope to be decided by the owner.
* **PEEK-280 — Deferred:** energy audit of timers and refreshes with MetricKit
  data.
* **PEEK-281 — Deferred:** meeting providers as data instead of code, so new
  providers need no code change.
* Conflict and overlap warnings.
* Travel-time and "leave now" reminders.
* Calendar deep links, when macOS exposes a stable event destination.
* Focus status for the full-screen alert, if the owner decides it (release path,
  step 2).
* Email-attendee and decline actions with explicit permission boundaries.
* Optional Slack, Teams and task-manager integrations behind independent
  adapters.
* User-defined event color rules.

## Out of scope

* Cloud accounts or a Peek backend.
* Advertising or behavioral telemetry.
* Replacing macOS Calendar as the source of truth.
* AI features without a concrete use case, a local-first default and an
  explicit consent design like ADR 0005.

## Definition of release-ready

A release candidate passes CI, a signed Release build, every check in
`docs/MAC_CHECKS.md`, the manual checklist in `docs/RELEASE.md`, and
notarization (DMG) or TestFlight (App Store) validation on a clean macOS account.
