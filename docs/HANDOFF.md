# Project handoff

Last updated: 2026-07-23

## Read this first

Peek is currently at **1.3.8 (build 22)**. The repository has been reorganized into a layered monolith and the app has a refreshed icon and popover presentation. Inspect `git status` before working: the architecture, documentation, and visual upgrade may still be uncommitted in the current worktree.

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
- PEEK-108 integrated: VoiceOver labels and values added to the menu-bar popover and Preferences; Preferences radio rows and the selected event's meeting link are keyboard-activatable; user-facing text uses Dynamic Type-style text styles.
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
- Last full validation: Debug and Release builds succeeded; 67 tests passed with zero failures on 2026-07-17; `codex/hud-external-border` worktree. Installed bundle metadata reports 1.3.7 (21).

## Where to start next

PEEK-101 through PEEK-108, the full design-system refresh, and the app-icon re-render are complete. There are no remaining `Ready` items in `docs/ROADMAP.md`; the next candidates are in the **Next** bucket:

- Event detail expansion: notes, attendees, attachments, and conference provider identity.
- Conflict and overlap warnings.
- Multiple time-zone display.
- Quick event creation with explicit confirmation and calendar selection.

Outstanding follow-ups from this cycle:

- Visual QA of the redesign on a running build (light/dark, Reduce Motion, Increased Contrast, and a live "Starting now" HUD trigger).
- Real macOS 13 hardware validation (CI-hosted macOS 13 is no longer available).

Create a workstream from `docs/workstreams/TEMPLATE.md` and follow the validation steps in `AGENTS.md`.

## Known limitations from PEEK-104

- Carbon's `RegisterEventHotKey` cannot report a combination already claimed by another application; it may succeed and simply never fire. Only failures the API itself returns are surfaced. A future improvement could verify the key event is received after registration.

## Known constraints

- Public distribution is not ready: Developer ID signing and notarization are still outstanding.
- `CalendarManager` and `AppDelegate` remain larger than the target architecture recommends.
- The automatic space policy now uses the notch frontier on notched displays and a sticky hidden-item latch on non-notched displays; real-world crowded-menu-bar validation on multiple notched and external display setups is welcome.

## Active workstreams

See `docs/workstreams/`. A workstream is active only when its file says `Status: Active`.
