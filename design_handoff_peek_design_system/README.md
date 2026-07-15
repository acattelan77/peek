# Handoff: Peek Design System

## Overview
Peek is a lightweight macOS **menu-bar calendar companion**. It surfaces the next upcoming
event, escalates visual urgency as a meeting approaches, and offers one-click join for common
meeting providers. This package is a full visual + interaction refresh of the app: a fresh,
sleek, native-macOS design system plus redesigned screens for every surface.

The design direction is **"calm glance"** — native macOS materials and SF typography, driven
by a single confident accent (Peek Blue), with urgency borrowing amber/red only when time
demands it. Guiding principles:
- **Glanceable first** — title, time, and join action outrank all metadata.
- **One accent per row** — a single accent drives focus; urgency is the only exception.
- **Native, not neutral** — system materials, focus rings, SF type, with just enough
  personality to feel like Peek.

## About the Design Files
The file in this bundle (`Peek Design System.dc.html`) is a **design reference created in
HTML** — a prototype showing the intended look and behavior. It is **not production code to
copy**. The task is to **recreate these designs in the existing Peek codebase**, which is a
native macOS app: **SwiftUI + AppKit**, EventKit for calendar access, `NSStatusItem` for the
menu bar, `NSPopover` for the popup, Carbon for the global hotkey. Use the codebase's existing
patterns (the views live in `Peek/Sources/Presentation/`).

Open the HTML file in a browser to see all screens and states. Every pixel value, hex color,
and copy string below is authoritative; when in doubt, inspect the corresponding element in
the HTML.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, radii, and interaction states. Recreate
pixel-accurately in SwiftUI. Where the design uses a value that maps to a SwiftUI semantic
(e.g. `.secondary`, system materials, `.borderedProminent`), prefer the semantic — see notes.

---

## Design Tokens

### Color — brand
| Token | Hex | Use |
| --- | --- | --- |
| Peek Blue | `#3B60E4` | Primary actions, selection, NEXT badge, accent |
| Blue Pressed | `#2E50CF` | Hover / active on Peek Blue |
| Blue Tint | `#E9EEFD` | Selected-row wash, soft button bg (light) |
| Blue Wash (row) | `#F1F4FE` | NEXT-event row background (light) |
| Midnight | `#0B1B44` | App-icon depth, dark brand field |
| Indigo (icon) | `#1B2E7A` | App-icon gradient top |

### Color — semantic / urgency
| Token | Hex | Use |
| --- | --- | --- |
| Calm (green) | `#2FA968` | > 10 min away; success; "read-only" note |
| Urgent (amber) | `#E8912B` | 2–10 min away; all-day badge |
| Urgent tint | `#FDF2E3` / `#FBEBD6` | Urgent row wash / badge bg |
| Critical (red) | `#E5484D` | < 2 min; pulsing |
| Critical tint | `#FCEBEC` / `#FBE4E5` | Critical row wash / badge bg |
| Menu-bar amber | `#FFB558` | Urgent title tint on dark menu bar |
| Menu-bar red | `#FF8A8E` | Critical title tint on dark menu bar / dark HUD |
| Icon coral slot | `#FF6E5B` | App-icon "next" slot only |

### Color — neutral ramp (light)
| Token | Hex | Use |
| --- | --- | --- |
| Surface | `#FFFFFF` | Cards, popover, windows |
| Canvas | `#F4F5F8` | Window background behind cards |
| Row hover wash | `#F3F4F8` | Event-row hover |
| Fill / chip | `#F0F1F5` / `#EDEEF2` | Secondary buttons, segmented track, count badge |
| Hairline | `#E7E8EE` (borders), `#EEF0F3` (inner dividers) | Separators |
| Control border | `#DADCE3` / `#C4C7CE` | Bordered buttons, radios/checkboxes |
| Tertiary text | `#9A9FA8` | Timestamps, captions, placeholder |
| Secondary text | `#626770` | Metadata, subtitles |
| Body text | `#40454E` | Times, body copy |
| Ink (primary) | `#17181C` | Titles, primary text |

### Color — dark mode
| Token | Hex | Use |
| --- | --- | --- |
| Surface | `#232428` | Popover / HUD background |
| Elevated fill | `rgba(255,255,255,0.08–0.10)` | Chips, secondary buttons |
| Hairline | `rgba(255,255,255,0.07–0.08)` | Dividers |
| NEXT wash | `rgba(59,96,228,0.16)` | NEXT row bg |
| Accent rail (dark) | `#5B7DF0` | NEXT rail / dot on dark |
| Accent icon (dark) | `#7E9BF5` | Clock/countdown on dark NEXT row |
| Ink | `#F2F3F5` | Titles |
| Body | `#C4C8CF` | Times |
| Secondary | `#9DA2AB` | Metadata |
| Tertiary | `#8B9099` / `#6C7079` | Captions / muted |

> **SwiftUI note:** map body/secondary/tertiary text to `.primary` / `.secondary` and let the
> system handle dark mode where possible; use the explicit dark hexes above only where a
> custom tint is required (accent rail, urgency). System materials (`.regularMaterial` /
> `.thickMaterial`) back the notification banner and context menu.

### Typography — SF Pro (system font, `-apple-system`)
| Role | Size | Weight | Use |
| --- | --- | --- | --- |
| Display | 24–30 | 700 (bold) | Onboarding / masthead titles |
| Title | 17 | 600 (semibold) | Popover header "Peek" |
| Headline | 14–15 | 600 (semibold) / 650 | Event titles, section headings |
| Body | 13 | 400 (regular) | Times, settings labels |
| Body-metadata | 12.5 | 400–500 | Location, calendar, metadata |
| Caption | 11 | 400–600 | Countdown, secondary captions |
| Label | 9 | 700 (bold), +0.06em tracking, UPPERCASE | NEXT / SOON / NOW / ALL-DAY badges |
| Mono | — | — | Hotkey display, spec values (`ui-monospace`/SF Mono) |

Negative letter-spacing `-0.01em` to `-0.02em` on titles/display.

### Spacing (4pt grid)
`4` · `8` (row padding) · `12` (edge inset) · `16` (header) · `24` (section)

### Radius
`6` buttons/chips · `7` join buttons · `8–9` event rows · `10` setting-group cards ·
`12` popover/cards/windows · `14–16` HUD/onboarding cards · `999` badges & count · squircle for app icon

### Elevation (shadows)
| Level | Value | Use |
| --- | --- | --- |
| 0 | none / 1px hairline | Flat rows, cards on canvas |
| 1 | `0 2px 6px rgba(20,22,40,0.10)` | Resting card |
| 2 (popover) | `0 14px 40px rgba(20,22,40,0.20)` | Popover |
| 2 (HUD) | `0 20px 50px rgba(20,22,40,0.28)` | "Starting now" alert |
| 2 (window) | `0 18px 46px rgba(20,22,40,0.24)` | Preferences window |
| dark popover | `0 14px 40px rgba(0,0,0,0.45)` | Dark surfaces |

---

## Screens / Views

### 1. Popover (menu-bar popup) — `MenuBarView.swift`
**Purpose:** primary surface; the list of upcoming events opened from the menu bar.
**Layout:** fixed **350pt** wide, `NSPopover`, vertical stack, radius 12.
- **Header** — 13px vertical / 16px horizontal padding, flex row, gap 10:
  - App icon 26×26, radius 7.
  - Column: "Peek" (15 / 600) over the date, e.g. "Tuesday, July 15" (11, `#8A8F98`).
  - Right: event-count pill — "4" (11 / 600, `#626770` on `#F0F1F5`, radius 999, padding 3×9).
- **Hairline** `#EEF0F3`.
- **List** — 8px padding, `ScrollView`, max height ~400.
  - **NEXT row:** background wash `#F1F4FE`, radius 9, **3pt accent left rail** (`#3B60E4`),
    padding 11/12/12/14. Content:
    - Title (14 / 650) + `NEXT` badge (label style, white on `#3B60E4`, radius 4).
    - Meta row: clock icon (accent) + "10:30 – 11:00 AM" (12.5, `#40454E`) + right-aligned
      countdown "in 12 min" (11 / 600, accent).
    - Detail row: provider icon + "Zoom" (12, `#626770`); calendar dot + "Work".
    - **Join button:** accent solid, white, `<video icon> Join Zoom`, 12.5 / 600, radius 7,
      padding 7×13.
  - **Normal rows:** no rail/wash. Title (14 / 500); clock icon `#B0B4BC` + time + muted
    countdown (`#9A9FA8`); calendar dot + name. Hairline divider `#EEF0F3` inset 12px between.
- **Hairline.**
- **Footer** — 9px/16px padding, flex row, icons 15px `#9096A0`, hover → accent:
  gear (Preferences), calendar (Open Calendar), refresh (Refresh) on the left; power (Quit)
  pushed to the right. Every icon has a help + accessibility label (see §Accessibility).

**Urgency variants (same row, escalated):**
- **Urgent (2–10 min):** rail + wash + badge + countdown + clock + join button all **amber
  `#E8912B`**; wash `#FDF2E3`; badge reads `SOON`; join button "Join now".
- **Critical (< 2 min):** all **red `#E5484D`**; wash `#FCEBEC`; badge `● NOW` with pulsing
  white dot; countdown "starting now"; **row has a pulsing outer ring** (see Motion). Join
  button "Join now".

**Empty state:** centered, 40px padding — 52×52 rounded-14 tile `#E9EEFD` with a calendar
glyph (accent), title "You're all clear" (15 / 600), body "No upcoming events. Peek will light
up the moment something lands on your calendar." (12.5, `#626770`, max-width 230).

**No-access state:** same layout, amber tile `#FDF2E3` + calendar-alert glyph, title "Calendar
access needed", body explaining permission, and a primary accent button **"Open System
Settings"**.

### 2. "Starting now" alert (in-app HUD) — new surface
**Purpose:** focused, high-signal prompt when a meeting is imminent; slides in top-right.
**Layout:** 380pt wide card, radius 16, elevation 2 (HUD). Top 4px gradient bar
`linear-gradient(90deg,#E5484D,#E8912B)`. Padding 18/20/20.
- Header row: `● STARTING NOW` pill (11 / 700 tracking, red, `#FCEBEC` bg, pulsing dot) +
  right "Peek" with 16px icon.
- Title (20 / 700).
- Meta: clock + "10:30 – 11:00 AM"; calendar dot + "Work".
- Actions: **Join Zoom** (accent, 13.5 / 600, radius 9, padding 10×18) · **Snooze 5 min**
  (`#F0F1F5` fill) · 38×38 close button (X icon) pushed right.
- Dark variant: surface `#232428`, red pill `#FF8A8E` on `rgba(229,72,77,0.18)`, elevated fills.

### 3. Preferences window — `PreferencesView.swift`
**Purpose:** settings; **500pt** wide window (`.sheet`), height ~700.
- **Title bar:** 44px, `#ECEDF1`, traffic lights, centered title "Peek Settings".
- **Tab bar:** white, three tabs — **Calendars / Filters / General** (13 / 500; active is
  17→13 / 600 ink with a **2pt accent underline**). Horizontal padding 16, per-tab padding
  12/4, gap 22.
- **Footer bar:** `#ECEDF1`, top hairline `#DEDFE5` — "Export…" and "Import…" (bordered
  buttons, `#fff`/`#DADCE3`), right-aligned version "v1.1.0 (5)" (11.5, `#9A9FA8`) + **Done**
  (accent, `.borderedProminent` equivalent).

**Pattern for all tabs:** settings are grouped into **inset cards** — white, border `#E7E8EE`,
radius 10 — with rows separated by inner hairlines `#EEF0F3`, each row 12/14 padding. Group
labels above cards: 11 / 650, +0.06em tracking, UPPERCASE, `#9A9FA8`, margin 0 4px 8px.

- **General tab (top→bottom):**
  - *(ungrouped card)* "Launch at login" + toggle (on).
  - **SCHEDULE:** "Look ahead" → popup "Next 7 days"; "Max events to show" → popup "10".
    (Popups: `#F0F1F5` fill, radius 7, chevron-down.)
  - **STATUS BAR DISPLAY:** "Display format" segmented `[Icon only | Title | Title + time]`;
    "Show event count badge" toggle (on); "Use urgency colors" toggle (on) with subtitle
    "Tint the title amber, then red, as time runs out".
  - **APPEARANCE:** "Theme" segmented `[Auto | Light | Dark]`.
  - **SHORTCUT & ALERTS:** "Global hotkey" → mono chip `⌘⇧C`; "Meeting notifications" toggle
    (on) with subtitle "Alert with a join link 2 min before".
- **Calendars tab:** heading "Calendars to monitor" (15 / 650) + subtitle. Inset card list of
  calendars — each row: checkbox (18×18, radius 5, accent-filled with white check when on, else
  `#C4C7CE` border), calendar color dot (10px), name, right-aligned account type
  (11, `#9A9FA8`: Exchange / iCloud / Subscription). Below: "Select all" (soft accent button
  `#E9EEFD`) + "Deselect all" (`#F0F1F5`).
- **Filters tab:** heading "Event filters" + subtitle. Inset card: "Hide all-day events"
  (off), "Hide declined events" (on). Then **KEYWORD FILTER** card: description + a token/chip
  input — existing keywords as removable chips (`#EDEEF2`, X icon) with "Add keyword…"
  placeholder.

> **Toggles:** 38×22 track, radius 999, 18px white knob (shadow `0 1px 3px rgba(0,0,0,.25)`);
> on = `#3B60E4` knob-right, off = `#DADCE3` knob-left.
> **Segmented control:** `#EDEEF2` track, 2px padding, radius 8; selected segment white,
> radius 6, shadow `0 1px 2px rgba(0,0,0,.10)`, ink text; unselected `#626770`.
> **Radio (selection rows in code today):** 15px circle, selected = 4.5px accent ring.

### 4. First-run onboarding — new surface (3 steps)
**Purpose:** welcome → earn calendar access → pick calendars, before the menu bar appears.
**Layout:** 420pt window, radius 14, traffic-light title bar (38px). Each step ends with a
**3-dot progress indicator** (active `#3B60E4`, inactive `#D6D8DF`, 7px dots).
- **Step 1 — Welcome:** centered; 84×84 app icon (radius 19), "Welcome to Peek" (24 / 700),
  body "Your next meeting, always one glance away in the menu bar — with a one-click join the
  moment it starts.", primary **"Get started"**.
- **Step 2 — Calendar access:** 72×72 `#E9EEFD` tile + calendar glyph; "Connect your calendar"
  (20 / 700); body "Peek reads your events to show what's next. That's all — nothing leaves
  your Mac."; green trust line "🔒 Read-only · stays local" (`#2FA968`); primary **"Grant
  calendar access"**; text button **"Maybe later"** (`#626770`).
- **Step 3 — Pick calendars:** "What should Peek watch?" (20 / 700) + "You can change this
  anytime in Settings."; inset checkbox list (`#F7F8FA` card) of calendars; full-width primary
  **"Start using Peek"**.

### 5. Menu-bar presence (status item) — `StatusBarContentBuilder.swift`
**Purpose:** the `NSStatusItem` itself; scales to available space; glyph is a **monochrome
template image** (macOS tints it) — never colored. Only the **title text** is tinted for urgency.
- **Icon only** — template glyph (tight space / notch).
- **Icon + title** — glyph + "Standup" (12.5 / 500).
- **Urgent** — glyph + "Standup · 6m", title tinted amber `#FFB558`.
- **Critical** — glyph + "Now" + pulsing red dot `#FF8A8E`.

### 6. App icon — refresh target
Flatter than the current rendered icon. Squircle tile, indigo→midnight gradient
(`150deg, #1B2E7A → #0B1B44`), white calendar page (radius scales with size) with a `#3B60E4`
top band, two binding stubs (large sizes only), a **peeled bottom-right corner** (triangle,
`#EDEEF2`), and one **coral `#FF6E5B` "next" slot** pill bottom-left. **Rules:** keep the fold,
the single coral slot, and the indigo→midnight field; never add text, numbers, a dense month
grid, or window traffic lights; verify at 16/32/128/1024px. The HTML shows CSS approximations
at 16/32/64/128 — render the production master in a vector tool and regenerate the
`AppIcon.appiconset` (see `docs/DESIGN_SYSTEM.md`).

### 7. Event context menu — `EventContextMenu` (in `MenuBarView.swift`)
Native vibrancy `NSMenu`. 232pt, radius 10, material bg. Rows: icon + label, 6/10 padding,
radius 6, highlighted row = accent bg white text. Order: **Copy meeting link** (top, only when
a URL is detected) → divider → Open in Calendar → Copy location (only if present) → Copy event
title.

---

## Interactions & Behavior
- **Open popover:** 160ms ease-out (fade/subtle scale). Reduce Motion → instant, no scale.
- **Button press:** background darkens to `#2E50CF` (hover) / `#2A49BC` (pressed), scale
  0.96×, 80ms ease-out. Reduce Motion → color only, no scale.
- **Keyboard nav (existing):** ↑/↓ move selection through events; selected row gets
  `#EEF1FD` bg + 2pt accent focus ring, title turns `#2E50CF`. **Esc** closes the popover.
  Text fields intercept these keys (don't steal arrows while editing keywords).
- **Focus ring:** all focusable controls show a 3pt accent ring
  `box-shadow: 0 0 0 3px rgba(59,96,228,0.40)` (4pt under Increased Contrast).
- **Urgency escalation:** normal → urgent → critical cross-fades the row tint/rail/countdown
  over 300ms ease-in-out. Auto-refresh cadence: every minute normally, every 5s when a meeting
  is close (existing behavior).
- **Critical pulse:** row outer ring pulses `box-shadow 0 → 0 0 0 4px rgba(229,72,77,0.16)` on
  a 1.6s ease-in-out loop; badge dot pulses opacity/scale on a 1.2s loop. **Reduce Motion →
  replace with a static red ring, no animation.**
- **Refresh control:** rest (arrow.clockwise, `#626770`) → **Refreshing** (spinner, min 0.4s)
  → **Refreshed** (green check `#2FA968` on `#E7F6EE`, ~0.9s) → back to rest. Disabled when no
  calendar access.
- **Loading skeleton:** only shown past ~400ms fetch; gray bars (`#ECEDF1` / `#F1F2F5`), radii
  5–6, mimicking title + two meta lines per row.
- **Join button:** opens the detected meeting URL (validate safety first, as in
  `MeetingURLDetector`); provider label reflects the detected service (Zoom, Meet, Teams, …).
- **Notification / HUD actions:** Join opens the URL; Snooze re-alerts in 5 min; close/X
  dismisses.

## State Management
Existing `CalendarManager` (`@ObservedObject`) already holds most of this — reuse it:
- `upcomingEvents`, `hasCalendarAccess`, `appearanceMode` (.auto/.light/.dark).
- Selection index (popover arrow-key nav), `isRefreshing` / refresh-confirmation flags.
- Preferences: enabled calendars, `hideAllDayEvents`, `hideDeclinedEvents`, `filterKeywords`,
  `lookaheadDays`, `maxEventsToShow`, `statusBarMode`, `menuBarSpacePolicy`, `showEventCount`,
  `urgencyColorsEnabled`, `notificationsEnabled`, `notificationTiming`, `globalHotkey`,
  `launchAtLogin`.
- Urgency derives from minutes-until-start: `< 2` critical, `2–10` urgent, else normal
  (`MeetingUrgency`).
- New: onboarding-completed flag (persist in `UserDefaults`) to gate first-run flow; snooze
  timers for the HUD/notification.

## Accessibility
- **Never color-only:** urgency always pairs hue with a word (SOON / NOW) or icon.
- **Contrast (all AA+ on white):** Ink 15.8:1 · Secondary `#626770` 5.4:1 · Peek Blue 4.8:1 ·
  white-on-Peek-Blue 4.8:1.
- **VoiceOver labels** for every icon-only control, e.g. "Refresh events", "Join Design
  Standup on Zoom", "Starting now". Footer buttons keep both `.help(…)` and
  `.accessibilityLabel(…)`.
- **Increased Contrast:** hairlines darken to `#C4C7CE`, tint fills gain a 1pt border, focus
  ring widens to 4pt.
- **Reduce Motion:** disables the critical pulse (static ring), popover scale, and press scale.

## Content & Voice
Plain, calm, present tense; state the fact + next action. Do: "Starting in 2 min", "You're all
clear", "Calendar access needed", "in 12 min"/"in 3 hr"/"10:30 AM". Don't: alarmist ("Hurry!
You're about to be late!"), jokey/emoji empty states, cutesy errors, or raw units ("720
seconds"). Rules: titles truncate at 2 lines (time/join never clip); relative time under 1 hr,
clock time beyond; sentence case everywhere except the 9pt ALL-CAPS status labels.

## Assets
- `assets/peek-icon.png` — current app icon (512px master export), used in headers/onboarding/
  notification here. **To be replaced** by the refreshed icon (see Screen 6); regenerate the
  full `Peek/Resources/Assets.xcassets/AppIcon.appiconset` from the new master.
- All other glyphs in the HTML are simple line icons standing in for **SF Symbols** — use the
  real SF Symbols in the app: `gearshape`, `calendar`, `arrow.clockwise`, `power`, `clock`,
  `location`, `video.fill`, `checkmark`, `xmark`, `chevron.down`, `bell`.

## Files
- `screenshots/` — PNG captures of every section of the reference, in order (`NN-section.png`
  then `NN-tail.png`), for quick visual scanning without opening the HTML.
- `Peek Design System.dc.html` — the complete visual reference (17 sections: direction, color,
  type, spacing/radius/elevation, components, popover states, "starting now" alert, menu-bar
  presence, preferences, onboarding, app icon, motion, accessibility, notification, content &
  voice, loading, context menu). Open in a browser.
- Target source to modify: `Peek/Sources/Presentation/MenuBar/MenuBarView.swift`,
  `Peek/Sources/Presentation/Preferences/PreferencesView.swift`,
  `Peek/Sources/Presentation/StatusBar/StatusBarContentBuilder.swift`; new views for the
  onboarding flow and the "starting now" HUD. Update `docs/DESIGN_SYSTEM.md` to match this system.
