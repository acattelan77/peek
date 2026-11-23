# Project handoff

Last updated: 2026-08-14

## Read this first

Peek is currently at **1.5.5 (build 34)**. The current work has passed full
automated QA. Physical validation of the EventKit-change refresh path remains
required because the available desktop UI controller cannot inspect the
accessory menu-bar app. The repository is organized as a layered monolith with
a refreshed icon and popover presentation. Inspect `git status` before working.

## Integrated state

- Source layers: App, Application, Domain, Infrastructure, and Presentation.
- Service boundaries: EventKit, notification scheduling, preferences, and launch at login.
- Documentation: architecture, roadmap, development, design system, release, security, versioning, and ADRs.
- Brand assets: generated app-icon family and deterministic template menu-bar icon sharing the same calendar-page model.
- Reliability fixes: notification disabling, conditional notification permission, Zoom password preservation, and next-event ordering.
- PEEK-101 integrated: notch-safe adaptive compact mode with `Automatic`, `Always show icon`, and `Always show text` space policies, hysteresis, and notched-display margin.
- PEEK-102 integrated: fake `CalendarEventStoring` and `NotificationScheduling` test doubles plus `CalendarManager` integration tests covering authorization, refresh, calendar filtering, and notification scheduling.
- PEEK-103 integrated: menu-bar and preferences integration tests covering first-launch calendar defaults, denied access, empty state, event-list behavior, persistence, and view instantiation, plus a fake launch-at-login controller.
- PEEK-104 integrated: the global hotkey now re-registers live when changed in Preferences (no restart), triggering it activates the app so the popover surfaces above other windows, and API-reported registration failures are shown in the General tab. Carbon registration lives in `CarbonHotkeyRegistrar` (composition root) behind a `HotkeyRegistering` seam, with the decision policy in the testable `GlobalHotkeyCoordinator`.
- PEEK-105 superseded: Preferences import/export feedback shipped earlier, but the import/export feature was removed in 1.3.6 to simplify the Preferences footer.
- PEEK-108 integrated: VoiceOver labels and values added to the menu-bar popover and Preferences; Preferences radio rows and the selected event's meeting link are keyboard-activatable; user-facing text uses named design-system type roles. (Correction 2026-11-23: macOS gives third-party apps no Dynamic Type; sizes are fixed and centralized in `PeekFont`.)
- PEEK-109 integrated: the `Automatic` menu-bar space policy now measures room to the notch frontier on notched displays, detects when macOS has hidden Peek's item entirely, and falls back to the clickable icon; a sticky latch handles non-notched displays where the front-app menu boundary is not measurable.
- PEEK-107 integrated: GitHub Actions `release.yml` and `scripts/release.sh` produce a Developer ID-signed, notarized, stapled DMG on version tags; release secrets and the GitHub Releases update policy are documented.
- PEEK-106 integrated (partial): the `macos-13` CI leg was **removed** — GitHub is retiring that hosted runner, so those jobs queued indefinitely and hung every run. CI now runs a single `macos-latest` job with a 30-minute timeout. True macOS 13 validation still needs real hardware.
- Design system adopted (1.3.0): the Claude Design "calm glance" system is implemented as a shared token layer (`Presentation/DesignSystem/`: `PeekTheme`, `PeekComponents`) and applied across the popover, Preferences (inset cards, segmented/menu controls, accent switches), a new first-run onboarding flow, and a new "Starting now" HUD. Reference kept in `design_handoff_peek_design_system/`.
- Popover activation fix (1.3.1): as an accessory (`LSUIElement`) app, Peek now activates when the popover opens, so the transient popover no longer dismisses immediately and controls render in the active (accent) appearance instead of greyed.
- App icon (1.3.2): re-rendered to the design system (handoff §6), generated reproducibly from `scripts/generate-icon-master.swift` and resized by `scripts/generate-assets.swift`.
- Design-system consistency (1.3.3): the refined "peek behind the calendar" artwork is now
  the app-icon master, the menu-bar template glyph uses the same page/header/binding/slot/fold
  model in simplified outline form, Preferences keyword filtering uses removable
  design-system chips, onboarding and Preferences calendar rows share `PeekCheckboxRow`, and
  menu-bar urgency colors use named AppKit design tokens.
- HUD polish (1.3.5): the "Starting now" HUD panel is created borderless from the start and
  its AppKit hosting layers are transparent, hiding the rectangular external container behind
  the rounded card.
- Preferences simplification (1.3.6): removed the Import and Export buttons and the JSON
  settings backup/restore implementation.
- Calendar full-access fix (1.3.7): added the macOS full-calendar-access usage description and
  regression coverage so Peek recognizes Full Access calendar permission on modern macOS.
- HUD shadow clipping fix (1.3.8): the "Starting now" HUD card now sits inside a transparent
  `shadowPadding` margin sized from the `.hud` elevation values, so the panel bounds no longer
  clip the drop shadow into a visible squared edge; panel placement anchors on the card's
  top-right corner, keeping the on-screen position unchanged.
- Popover status-item anchoring fix (1.3.10): the direct status-button anchor used
  in 1.3.9 still reused stale AppKit positioning state after close/reopen. Peek
  now creates a fresh invisible anchor window for each presentation, positions
  it from WindowServer's live status-item frame, and retains click-derived
  geometry as a fallback.
- Hotkey crash fix (1.3.11): the private status-item window can report a
  `windowNumber` outside the `CGWindowID` (`UInt32`) range, and the unchecked
  conversion trapped when the popover was presented via the global hotkey
  (`EXC_BREAKPOINT` in `liveStatusButtonScreenFrame`). The conversion is now
  range-checked and falls back to AppKit-derived geometry.
- PEEK-110 integrated (1.4.0): popover events are bordered cards (the next
  event keeps its urgency color coding) that expand in place on click or
  Return to show notes, attendees with response status and the organizer, and
  conference provider identity. `MeetingProvider` moved to `Domain/Meetings`;
  detail logic lives in the testable `EventDetail`/`EventDetailBuilder`.
  Attachments are omitted because macOS EventKit does not expose them.
- 1.4.1: the stale popover-arrow path no longer queries
  `CGWindowList` for a private status-item window. It uses click-derived
  geometry for the initial open and AppKit's live status-button frame for
  tracking, which avoids the macOS 26 `windowNumber == 2^32` failure. The
  AppDelegate refactor also moved the Carbon registrar, popover-anchor
  controller, HUD lifecycle, and geometry into focused App-layer types.
- PEEK-111 integrated (1.5.0): `Peek --export --from <signed-days> --to
  <signed-days> --json` exits before constructing app UI and writes the
  versioned local-calendar JSON v1 contract only to stdout. It uses existing
  Full Access without prompting, honors persisted calendar selection (or all
  calendars on first launch), includes all intersecting all-day and declined
  events, and fails without partial JSON on authorization or EventKit errors.
  The installed app is now consumed by the user-local Northwind Notes LaunchAgent at
  login, 06:45, and 13:00, piping `--from -3 --to 14 --json` to its external
  renderer. The renderer owns atomic writes to Northwind Notes's private
  `_calendar.md` and `_calendar-events.json` caches; those files, its script,
  and `launchd` plist are deliberately outside this repository.
- PEEK-111 maintenance requirement: treat its CLI and JSON v1 schema as a
  live compatibility contract. Do not silently change its arguments, selection
  semantics, authorization behavior, payload fields, link classification, or
  stdout/stderr behavior. Assess the external Northwind Notes consumer first; use a
  new schema version plus a consumer migration for breaking changes, preserve
  the no-vault-write and no-content-logging boundary, and update tests, README,
  ADR 0003, and this handoff with every contract change.
- PEEK-AUD-01 integrated (1.5.1): EventKit store-change observation now
  delivers its refresh handler on the main operation queue. This prevents a
  background EventKit notification from entering `AppDelegate` lifecycle and
  observable refresh coordination off-main. The regression test posts the
  notification from a background queue and asserts main-thread delivery. No
  EventKit query, notification, or PEEK-111 CLI/JSON v1 behavior changed.
- PEEK-AUD-02 integrated (1.5.2): the critical-event status-item pulse now
  honors macOS Reduce Motion. Urgency colors remain available; only repeated
  alpha animation is suppressed. No calendar, notification, or export behavior
  changed.
- PEEK-AUD-03 integrated (1.5.3): notification scheduling now reports generic
  authorization or scheduling results to Preferences, verifies that every
  expected notification request is pending, and retries a failed pass after 60
  seconds. Event titles, locations, and meeting links are not logged. No
  notification content, EventKit selection, or PEEK-111 CLI/JSON v1 behavior
  changed.
- PEEK-AUD-04 integrated (1.5.4): `scripts/release.sh` now fails closed before
  packaging unless the app has a strict valid nested signature, Developer ID
  identity for the configured team, Hardened Runtime, calendar entitlement, and
  no `get-task-allow`. It then verifies DMG integrity, staple validity,
  Gatekeeper assessment, and mounted app/link contents before declaring the
  release ready. A real signed/notarized execution remains required.
- PEEK-AUD-05 integrated: README, development, project-status, and security
  documentation now state the current version and CI topology, acknowledge the
  removed Preferences settings import/export feature, and distinguish scripted
  release checks from unperformed signed/notarized and physical validation.
- PEEK-AUD-06 integrated (1.5.5): the Starting now HUD's shown-event history
  now removes expired events and evicts the oldest expiry at 256 entries. It
  retains a minimum 60-second deduplication window for zero-duration or
  malformed events, preserving the original first-minute single-show behavior.
- Latest automated validation: `bash scripts/check-version.sh`,
  `git diff --check`, plist/localization lint, `bash -n scripts/release.sh`,
  unsigned Debug build, and the macOS test suite all passed on 2026-08-14 (95
  tests, zero failures). The current 1.5.5 unsigned Debug binary also returned
  the protected PEEK-111 `--help` text and rejected an invalid signed-day input
  on stderr with exit status 1, without emitting JSON. The signed, installed app
  previously completed the Northwind Notes LaunchAgent's first end-to-end calendar
  export with existing Full Access; do not inspect or log cache content merely
  to recheck it.
- Last full validation: 80 tests passed with zero failures on 2026-08-12 on
  `codex/event-detail-expansion`, including physical QA of the expansion
  interactions and card styling.

## Where to start next

PEEK-101 through PEEK-110, the full design-system refresh, and the app-icon re-render are complete. PEEK-AUD-01 is integrated. The prioritized audit follow-ups are recorded in `docs/ROADMAP.md`; the next product candidates are in the **Next** bucket:

- Conflict and overlap warnings.
- Multiple time-zone display.
- Quick event creation with explicit confirmation and calendar selection.

Outstanding follow-ups from this cycle:

- Visual QA of the redesign on a running build (light/dark, Reduce Motion, Increased Contrast, and a live "Starting now" HUD trigger).
- Physical Calendar-change refresh validation for PEEK-AUD-01. The desktop UI
  controller timed out again while inspecting the unsigned Debug accessory-app
  instance (Computer Use error `-10005`), so it cannot observe the menu-bar
  result in this environment. No UI setting or permission was changed.
- Real macOS 13 hardware validation (CI-hosted macOS 13 is no longer available).

PEEK-111 is a live local integration and must be maintained. Before modifying
its headless CLI or JSON contract, read the dedicated compatibility section in
`docs/ARCHITECTURE.md`, ADR 0003, and the PEEK-111 workstream. Coordinate any
breaking change with the external Northwind Notes renderer and LaunchAgent rather
than treating that consumer as disposable.

Create a workstream from `docs/workstreams/TEMPLATE.md` and follow the validation steps in `AGENTS.md`.

## Known limitations from PEEK-104

- Carbon's `RegisterEventHotKey` cannot report a combination already claimed by another application; it may succeed and simply never fire. Only failures the API itself returns are surfaced. A future improvement could verify the key event is received after registration.

## Known constraints

- `CalendarManager` remains larger than the target architecture recommends.
- `AppDelegate` is reduced from roughly 1120 to 753 lines, but it still owns
  timers, notification scheduling, and status-bar-space coordination.
- The automatic space policy now uses the notch frontier on notched displays and a sticky hidden-item latch on non-notched displays; real-world crowded-menu-bar validation on multiple notched and external display setups is welcome.

## Active workstreams

See `docs/workstreams/`. A workstream is active only when its file says `Status: Active`.
