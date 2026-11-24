# Workstream: Menu-bar states and alert ladder from the Peek 2.0 mockups

- Roadmap ID: PEEK-242
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: claude/project-thread-7wacdl
- Last updated: 2026-11-24

## Objective

The menu bar and Preferences > Alerts match the canvas frames "Stati della barra dei menu"
and "Preferenze divise per scopo" in full. The owner asked for the mockups to be applied
completely (2026-11-24) and chose the full alert ladder, including a new heads-up card 2
minutes before meetings.

## Scope

- Five menu-bar states: calm "Title · 15:00", soon amber pill "Title · 6 min", now red pill
  "Join now · Zoom" (pulsing), in progress "18 min left", icon only (pill kept while soon or
  now). The "(+N)" count suffix and its setting are removed.
- Alert ladder: lead time with Notification/Off, 2 minutes before with Heads-up card/Off
  (new), at the start with Full screen/Heads-up card/Off.
- Which meetings: "Interrupt only for meetings with a link or attendees" also gates the
  2-minute card; per-calendar "badge only" chips (no notification, card or start alert).
- Joining a meeting and Menu bar > Show (Countdown / Start time / Icon only). Other menu-bar
  settings and the global hotkey moved to General.

## Claimed files and subsystems

- `Peek/Sources/Presentation/StatusBar/StatusBarContentBuilder.swift`
- `Peek/Sources/Presentation/DesignSystem/PeekComponents.swift` (`StatusItemRenderer`,
  `PeekCalendarAlertChip`), `PeekTheme.swift` (metrics)
- `Peek/Sources/App/PeekApp.swift` (status item), `StartingNowHUDController.swift`
- `Peek/Sources/Presentation/HUD/StartingNowHUD.swift` (status text, optional snooze)
- `Peek/Sources/Presentation/Preferences/PreferencesView.swift`
- `Peek/Sources/Application/AppBehaviorSupport.swift` (`AlertLadder`),
  `Application/Calendar/CalendarManager.swift`, `Domain/Models/AppPreferences.swift`
- `Peek/Resources/*.lproj/Localizable.strings`, tests, `docs/DESIGN_SYSTEM.md`

## Progress

- [x] Detailed comparison with the two canvas frames
- [x] Menu-bar states and pill drawing
- [x] Alert ladder, 2-minute card, badge-only calendars
- [x] Alerts tab layout, General tab regrouping
- [x] Localization (263 keys, 5 tables), tests, docs, 1.12.0 (42)
- [ ] CI green on the pull request
- [ ] Owner visual check on a Mac

## Validation

- Cloud session (Linux, no Xcode): `check-version.sh`, `check-design-tokens.sh`,
  `check-localization.py`, `git diff --check`. Build and tests run in CI, not locally.

## Owner checks on a Mac

1. With a meeting 20 minutes away the menu bar reads "Title · HH:MM" in normal text.
2. From 10 minutes it turns into an amber pill with "· N min"; from 2 minutes a red pulsing
   pill "Join now · Zoom" (static with Reduce Motion).
3. 2 minutes before, the heads-up card shows "IN 2 MIN" without a snooze button; at the start
   the chosen start alert shows.
4. During a meeting, with nothing else close, the menu bar reads "N min left".
5. With a crowded bar or Show = Icon only, the glyph sits inside the pill while soon or now.
6. A calendar set to badge only gets no notification, card or start alert.
7. Light and dark menu bar; Preferences > Alerts matches the canvas.

## Open questions

- None. PR 16 (App Store) also targets build 42: whichever merges second re-bumps.

## Next action

Owner visual check on a Mac after CI passes.
