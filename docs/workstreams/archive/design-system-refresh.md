# Workstream: Claude Design system adoption

- Roadmap ID: N/A (design refresh)
- Status: Complete
- Owner: Claude (design-system pass)
- Branch/worktree: codex/design-system-refresh
- Last updated: 2026-07-15

## Objective

Adopt the Claude Design "calm glance" design system (`design_handoff_peek_design_system/`)
across the whole app so every surface consumes one shared token layer and matches the
high-fidelity reference.

## Scope (user chose "Everything")

- Centralized token layer: colors (light/dark), typography, spacing, radius, elevation,
  and reusable component styles (badge, count pill, inset card, button styles, focus ring).
- Popover (`MenuBarView`) full redesign: header + date, NEXT row (rail/wash/badge/countdown/
  Join), normal rows, urgency variants (SOON/NOW), empty + no-access states, footer.
- Preferences (`PreferencesView`) redesign: inset cards, group labels, segmented controls,
  native switches tinted accent, calendars checkbox list, keyword chips.
- Menu-bar urgency title tints (`StatusBarContentBuilder` / status styling).
- New surface: 3-step first-run onboarding (welcome → access → pick calendars), gated by a
  persisted flag.
- New surface: "Starting now" HUD (top-right card, Join / Snooze / dismiss).
- Update `docs/DESIGN_SYSTEM.md`, localize new strings, bump version, changelog.

## Out of scope

- App-icon re-render (needs a vector tool; regenerate `AppIcon.appiconset` from a new master
  per `docs/DEVELOPMENT.md`). Tracked as a follow-up.

## Claimed files and subsystems

- `Peek/Sources/Presentation/**` (new DesignSystem/, Onboarding/, HUD/ + existing views)
- `Peek/Sources/App/PeekApp.swift` (onboarding + HUD window wiring)
- `Peek/Sources/Application/Calendar/CalendarManager.swift` (onboarding flag)
- `Peek/Resources/en.lproj/Localizable.strings`
- `Peek.xcodeproj/project.pbxproj`
- `docs/DESIGN_SYSTEM.md`, `CHANGELOG.md`, `Configuration/Version.xcconfig`

## Progress

- [x] Token layer (PeekTheme + PeekComponents)
- [x] Popover redesign
- [x] Preferences redesign
- [x] Menu-bar urgency tints
- [x] Onboarding flow
- [x] Starting-now HUD
- [x] Docs, localization, version, validation

## Validation

- `bash scripts/check-version.sh` → 1.3.0 (14) valid.
- Debug build succeeded.
- `xcodebuild ... test` → 63 tests passed, 0 failures.
- `git diff --check` → clean; `plutil -lint` on Localizable.strings → OK.

## Follow-ups

- App-icon re-render (needs a vector tool; regenerate `AppIcon.appiconset`).
- Visual QA on a running instance across light/dark, Reduce Motion, Increased Contrast, and
  a live "Starting now" HUD trigger.

## Exact next action

None — workstream complete. Recommend visual QA on a running build and the app-icon refresh.
