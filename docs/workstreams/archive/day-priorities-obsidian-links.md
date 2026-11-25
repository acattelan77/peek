# Workstream: day priorities, Obsidian links and prep count

- Roadmap ID: PEEK-261, PEEK-262, PEEK-263, PEEK-264
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-4q8lj8`
- Last updated: 2026-11-24

## Objective

Peek reads three new things from `peek-context.json` without learning anything
about the writer: the day's priorities and links, `obsidian://` links, and how
many meeting points are still to prepare. It stays read-only and parses no
Markdown.

## Scope

- PEEK-261: optional top-level `day` object (date, headline, priorities, links),
  lenient decoding, today-only display in the popover above the next-meeting
  card, Preferences > Briefs "Show day priorities" switch (on by default, shown
  when a context folder is set).
- PEEK-262: fixed allowlist `https` + `obsidian` for `events[].links` and
  `day.links` (`ContextLinkPolicy`), checked again on click (`ContextLinkOpener`).
- PEEK-263: "N to prepare: <first point>" in the lead-time notification body
  and on the 2-minute heads-up card. The popover ("Brief ready: N points to
  prepare") and the full-screen alert ("First thing to prepare") already had
  it and are unchanged. A changed prep list reschedules the notification.
- PEEK-264: `generatedAt` older than 36 hours hides the day block, adds
  "Context from <d MMM>" under the meeting page context, and Preferences shows
  when the file was last generated. Missing `generatedAt` counts as fresh.
- ADR 0004 amendment; localization in en, it, de, fr, es.

## Out of scope

- Writing to the context folder, Markdown parsing, any Northwind Notes path or name.
- The calendar export and its schedule.
- Any AI call for the day block. `BriefInput` is unchanged (tested).

## Claimed files and subsystems

- `Peek/Sources/Domain/Context/MeetingContextFile.swift`, `MeetingContext.swift`
- `Peek/Sources/Infrastructure/Context/ContextFolderStore.swift`
- `Peek/Sources/Application/MeetingContextProvider.swift`, `AppBehaviorSupport.swift`
  (`ContextLinkOpener`, notification signature), `Calendar/CalendarManager.swift`
  (preference, Preferences message)
- `Peek/Sources/Infrastructure/Notifications/NotificationManager.swift` (body)
- `Peek/Sources/App/StartingNowHUDController.swift`, `Presentation/HUD/StartingNowHUD.swift`
- `Peek/Sources/Presentation/MenuBar/MenuBarView.swift` (`DayPrioritiesBlock`,
  meeting page stale line), `Preferences/PreferencesView.swift`,
  `DesignSystem/PeekTheme.swift` (`dayBlockInsets`)
- `Peek/Resources/*.lproj/Localizable.strings`, `PeekTests/MeetingContextTests.swift`

## Dependencies

- ADR 0004 (context file), ADR 0005 (brief data and consent).
- The Northwind Notes writer (outside this repo) adds `day` and `obsidian://` links.

## Progress

- [x] Decoding, limits, date matching, staleness, link allowlist
- [x] Popover day block, meeting page stale line, Preferences switch and footnote
- [x] Notification body and 2-minute card prep line
- [x] Localization, tests, ADR, CHANGELOG, version 1.13.0 (48)
- [ ] CI green on the pull request
- [ ] Owner checks on a Mac

## Validation

- Linux (cloud session): `bash scripts/check-version.sh`,
  `bash scripts/check-design-tokens.sh`, `python3 scripts/check-localization.py`,
  `git diff --check`. Build and tests run in CI only (see the pull request).

## Owner checks on a Mac

1. With a context file whose `day.date` is today, the popover shows the three
   priorities and a "Day log" button that opens Obsidian (sandboxed build too).
2. With yesterday's date in `day.date`, the block is hidden and meetings still
   show their context.
3. A meeting with two bullets: the lead-time notification and the 2-minute card
   say "2 to prepare".
4. A link with `file://` or `http://` is not shown.
5. A context file generated two days ago shows the "Context from" line and no
   day block; Preferences > Briefs shows when it was generated.

## Decisions and open questions

- Placement: the block sits at the top of the agenda area, under the header,
  world clocks and month grid, directly above the next-meeting card; hidden when
  another day is chosen in the month grid.
- The 2-minute card shows the same line as the notification (count and first
  point). The "Starting now" card is unchanged; the full-screen alert already
  shows the first point.
- Done priorities are dimmed with a filled check; no strikethrough.

## Exact next action

Wait for the `build-and-test` CI job, then for the owner's Mac checks and merge.
