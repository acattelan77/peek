# Changelog

This project follows Keep a Changelog conventions. Versions are released from `main`.

## Unreleased

## 1.12.0 - 2026-11-24

### Changed

- PEEK-242: the menu bar follows the Peek 2.0 mockup's five states. More than 10 minutes
  away it reads "Quarterly review · 15:00"; from 10 minutes it is an amber pill
  "Quarterly review · 6 min"; under 2 minutes a red, pulsing pill "Join now · Zoom"
  (or "Title · now" without a link); during a meeting, with nothing close, "18 min left".
  When space is short, or Show is Icon only, the icon stays inside the pill. The "(+N)"
  event count and its setting are gone.
- Preferences > Alerts follows the mockup: an alert ladder with one level per moment
  (the notification lead time, 2 minutes before, at the start), Which meetings, Joining a
  meeting, and Menu bar > Show (Countdown, Start time, Icon only). The global hotkey and
  the other menu-bar settings moved to General.

### Added

- A heads-up card 2 minutes before a meeting ("IN 2 MIN"), on by default and set in the
  alert ladder. "Interrupt only for meetings with a link or attendees" also applies to it.
- Badge-only calendars: click a calendar in Which meetings and its events stay in the menu
  bar but never notify or interrupt.

## 1.11.1 - 2026-11-24

### Fixed

- Preferences tab labels fit on one line in every language: "Alerts" and "Briefs"
  replace "Never miss a meeting" and "Arrive prepared", and tab titles no longer wrap.

## 1.11.0 - 2026-11-24

### Changed

- PEEK-241: the popover follows the Peek 2.0 mockups. The header shows the month with
  "Monday 23 · 4 meetings today" and ‹ Today › buttons; the month grid uses short
  uppercase weekdays and quieter past and out-of-month days; the next meeting is a
  compact card with a "NEXT · IN 24 MIN" eyebrow, the time range, who you are meeting,
  Join on the right and "Brief ready: N points to prepare"; other events are compact
  rows grouped under Today, Tomorrow and later days, and today's finished meetings stay
  in the list, dimmed. The footer keeps its icon buttons.
- Choosing a meeting opens its page in the popover (who you are meeting, what to
  prepare, invitation notes, time zones, sources) instead of expanding the row.
  Escape goes back to the agenda.
- The full-screen alert leads with who you are meeting, shows the first thing to
  prepare and uses large Join, "In 1 minute" and Dismiss buttons.
- Preferences are grouped by purpose: Never miss a meeting, Arrive prepared, Calendars
  (with filters) and General.
- Italian copy matches the mockups ("Entra in Zoom", "e altre 2 persone").

### Fixed

- Attendees whose calendar entry carries only an email address are shown by name
  ("grace.hopper@…" becomes "Grace Hopper") in the popover, the alert, the
  menu-bar name and the brief input. Addresses that do not look like a name
  ("info@…", "j2@…") are still shown as they are.

## 1.10.0 - 2026-11-23

### Added

- PEEK-231: a global "Join next meeting" shortcut, ⌃⌥J by default, with ⌘⇧J, ⌘⌥J or
  off in Preferences. It opens the meeting starting within two minutes, then one that
  started in the last fifteen, then the next within thirty; with none, the popover opens.
- PEEK-232: "Count down to meetings only" skips events without a join link in the menu
  bar, and "Name in the menu bar" can show the first person you're meeting instead of
  the title, which stays in the tooltip. The start alert still follows the next event.
- PEEK-233: world clocks for up to six cities under the popover header, and the
  meeting's time in those cities when a row is expanded, with +1 or −1 on another day.

### Fixed

- Each global shortcut now reacts only to its own key combination.
- The brief's "Never brief" keywords editor has its card padding.

## 1.9.0 - 2026-11-23

### Added

- PEEK-221 to PEEK-224: a meeting brief, three to five points on what to prepare,
  shown in the next-event row, the expanded row and the full-screen alert. Off by
  default. It is prepared 15 minutes before a meeting that has people or notes, or
  on request with "Prepare brief". The source is always shown: "From your context
  folder" (no model), "Written on this Mac" (Apple Intelligence, macOS 26) or
  "Written by Claude" (the user's Anthropic API key, after a consent screen that
  lists the fields sent). Keywords exclude meetings from briefs. Briefs are cached
  for three days in Peek's container and dropped when the event changes or briefs
  are turned off (ADR 0005).

### Changed

- New sandbox entitlement: outgoing network connections, used only for Claude
  briefs. FoundationModels is weak-linked so macOS 13 to 15 still launch.

## 1.8.0 - 2026-11-23

### Added

- PEEK-211: "You're about to meet Marco, CEO at Northwind" in the next-event row,
  the heads-up card and the full-screen alert. Attendees are matched with Contacts
  for role and company when the user turns it on in Preferences (the permission is
  asked only then); otherwise the company email domain is shown.
- PEEK-212: event notes drop Zoom, Meet and Teams join instructions, dial-in numbers
  and HTML, so the expanded row shows the agenda.
- PEEK-213: Peek can read meeting context that another app, such as Northwind Notes,
  writes to `peek-context.json` in a folder the user chooses (ADR 0004). Read-only,
  kept with a security-scoped bookmark.

### Changed

- New sandbox entitlements: Contacts, read-only access to a user-selected folder,
  and app-scoped bookmarks.

## 1.7.0 - 2026-11-23

### Added

- PEEK-202: meeting-link detection covers Zoom personal rooms, webinars, the web client
  and Zoom for Government, Teams `/meet/` and teams.live.com links, Google Meet lookup
  links, GoTo, Slack huddles, Amazon Chime, Jitsi, FaceTime and RingCentral, and fixes
  Zoom links without a company subdomain. The event's URL field is checked before the
  location and notes, and the earliest link in a text wins.
- PEEK-202: Join opens Zoom and Teams meetings in their Mac apps when installed, with a
  Preferences switch to always use the browser.
- PEEK-201: a compact, read-only month calendar above the event list. Days with events
  carry a dot; choosing another day shows its agenda, and Today returns to the upcoming
  list. It follows the user's first weekday and can be hidden in Preferences.
- PEEK-203: a choice of start alert in Preferences: off, the heads-up card, or a
  full-screen alert that appears over every Space and full-screen app. Return joins,
  Esc dismisses, and "In 1 minute" brings it back. By default the full-screen alert is
  only used for events with a join link or attendees; focus blocks get the card.
- PEEK-204: Peek is available in Italian, German, French and Spanish, including the
  calendar and notification permission prompts. CI checks that every table covers
  every string with matching format specifiers.

### Compatibility

- The PEEK-111 export JSON v1 keeps its original `join` link classification; new
  providers only affect in-app detection.

## 1.6.0 - 2026-11-23

### Changed

- Design system v2: one semantic color layer (`PeekNSColor` → `PeekColor`) with light,
  dark and Increased Contrast variants, plus `PeekTone` for urgency-aware components.
  Typography, SF Symbol sizes, spacing, radii and component metrics are now tokens, and
  the popover, Preferences, onboarding and Starting now HUD use only tokens.
- Shared components promoted into the design system: toolbar button, Join button style,
  critical pulse, tabs, switch, status pill, icon tile, section header, setting footnote.
- Preferences "Done" uses the Peek primary button instead of the system accent.

### Fixed

- Contrast (WCAG AA) across light and dark: tertiary and secondary text, white text on
  amber and red fills, amber, red and green text on washes, accent text on dark surfaces,
  and checkbox borders.
- The dark-mode secondary button, input, and count-pill fill was nearly invisible.
- Menu-bar SOON/NOW title tints were unreadable on a light menu bar.
- The critical row ring and pulsing dots now start when an event turns critical while the
  popover is open, and react live to Reduce Motion.
- Primary and secondary buttons now show a disabled state. Preferences tabs, calendar rows
  and section headings expose selected and header traits to VoiceOver, switches carry
  their row's label, and decorative icons are hidden from VoiceOver.

### Added

- `scripts/check-design-tokens.sh` (run in CI) rejects hardcoded design values outside the
  design system, and `DesignSystemTests` checks token contrast in every appearance.

## 1.5.5 - 2026-08-14

### Fixed

- PEEK-AUD-06: bounded the in-process Starting now HUD deduplication history
  and prune completed events so long-running sessions do not retain every
  shown event identifier.

## 1.5.4 - 2026-08-14

### Fixed

- PEEK-AUD-04: release packaging now fails closed unless strict signature,
  entitlement, notarization-staple, Gatekeeper, DMG integrity, and mounted-DMG
  contents checks pass.

## 1.5.3 - 2026-08-14

### Fixed

- PEEK-AUD-03: notification scheduling now verifies that expected requests are
  pending, shows a generic recoverable failure in Preferences, and retries a
  failed pass after a bounded delay without logging calendar content.

## 1.5.2 - 2026-08-14

### Fixed

- PEEK-AUD-02: the critical-event status-item pulse now honors macOS Reduce
  Motion while preserving urgency colors.

## 1.5.1 - 2026-08-14

### Fixed

- PEEK-AUD-01: EventKit store-change notifications now enter Peek's refresh
  path on the main operation queue, preventing a background notification from
  racing AppKit and observable-state lifecycle coordination.

## 1.5.0 - 2026-08-13

### Added

- PEEK-111: `Peek --export --from <signed-days> --to <signed-days> --json`
  emits a versioned, local-calendar JSON snapshot to stdout without starting
  the menu bar app. It honors Peek's saved calendar selection, includes
  all-day and declined events that intersect the requested local-day window,
  and refuses to emit partial output without existing EventKit Full Access.

## 1.4.1 - 2026-08-13

### Fixed

- Popover arrow could point at a stale menu-bar position. The WindowServer
  frame lookup used for anchoring is unusable on macOS 26 — the private
  status-item window reports a 64-bit window number the window-list API cannot
  resolve — so anchoring now uses click-derived geometry and AppKit's live
  button frame, which demonstrably tracks menu-bar rearrangements. The fresh
  per-presentation anchor window is unchanged.

### Changed

- Internal: split `AppDelegate` (~1120 lines) — the Carbon hotkey registrar,
  popover anchor machinery, and the "Starting now" HUD lifecycle now live in
  focused types (`CarbonHotkeyRegistrar`, `PopoverAnchorController`,
  `StartingNowHUDController`, `PopoverAnchorGeometry`). No behavior change.

## 1.4.0 - 2026-08-12

### Added

- Event detail expansion: clicking an event in the popover (or pressing Return
  on the keyboard-selected row) expands it in place to show its notes,
  attendees with response status and the organizer, and a Join button for
  non-hero rows. Conference provider identity (Zoom, Google Meet, Teams, …) is
  now derived in the Domain layer and shared between the row, the expanded
  details, and the "Starting now" HUD. Attachments are not shown: macOS
  EventKit does not expose them.

## 1.3.11 - 2026-08-12

### Fixed

- Fixed a crash when opening Peek with the global hotkey: the private
  status-item window can report a window number outside the `CGWindowID` range,
  and converting it trapped. Peek now falls back to AppKit-derived popover
  geometry in that case.

## 1.3.10 - 2026-07-31

### Fixed

- Detached the popover from AppKit's cached private status-item positioning
  window. Each opening now uses a fresh invisible anchor at Peek's live
  WindowServer position, with click-derived geometry as a fallback, so reopening
  after another menu-bar item no longer reuses the previous arrow location.

## 1.3.9 - 2026-07-30

### Fixed

- Kept the popover arrow attached to Peek's current menu-bar icon when app
  activation, event-title updates, or the automatic icon/text fallback cause
  macOS to rearrange status items, including cases where macOS replaces the
  text item's menu-bar window with a compact icon window after the popover opens.

## 1.3.8 - 2026-07-23

### Fixed

- Gave the "Starting now" HUD's drop shadow room inside its transparent panel so
  the window bounds no longer clip it into a visible squared edge; only the
  rounded card is visible now.

## 1.3.7 - 2026-07-17

### Fixed

- Added the macOS full-calendar-access usage description and regression coverage so
  Peek recognizes Full Access calendar permission on modern macOS.

## 1.3.6 - 2026-07-17

### Removed

- Removed the Preferences import and export controls and the JSON settings
  backup/restore implementation.

## 1.3.5 - 2026-07-17

### Fixed

- Hid the rectangular external AppKit container that could show around the rounded
  "Starting now" HUD.

## 1.3.4 - 2026-07-17

### Fixed

- The `Automatic` menu-bar space policy now reliably falls back to Peek's icon when the
  menu bar is crowded, including when macOS has hidden Peek's status item entirely.
  On notched displays the policy measures the actual room to the notch frontier; on
  non-notched displays it detects the hidden state and stays icon-only until the display
  configuration changes. (PEEK-109)

## 1.3.3 - 2026-07-16

### Changed

- Aligned the menu-bar template icon with the app icon model: calendar page, header band,
  binding stubs, single next-event slot, and lower-right fold now come from the same asset
  generator.
- Replaced the app-icon master with the refined "peek behind the calendar" artwork and
  regenerated the complete macOS app-icon catalog from that source.
- Tightened design-system adoption in Preferences and onboarding by moving checkbox calendar
  rows into a shared component and replacing the keyword filter text field with removable
  design-system chips.
- Menu-bar urgency title colors now use named design-system AppKit tokens.
- Removed the square AppKit panel outline behind the rounded "Starting now" HUD.
- Added breathing room between onboarding actions and the step progress dots.
- Meeting notifications now keep the user's toggle preference on even when macOS notification
  permission is unavailable, and scheduling resumes after permission is granted.

## 1.3.2 - 2026-07-16

### Changed

- Re-rendered the app icon to the Claude Design system (handoff §6): a squircle with an indigo→midnight field, a white calendar page with a Peek-Blue header and binding stubs, a single coral "next" slot, and a peeled corner. The master is generated reproducibly by `scripts/generate-icon-master.swift`; regenerate the icon set with `scripts/generate-assets.swift`.

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
