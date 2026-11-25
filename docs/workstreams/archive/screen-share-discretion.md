# Workstream: screen-share discretion

- Roadmap ID: PEEK-274
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-cojkkd`
- Last updated: 2026-11-24

## Objective

When Alessandro shares or mirrors his screen, Peek shows nothing more sensitive
than meeting times and titles. Plan: PR 4 of "Peek: piano di robustezza prima
del rilascio (PEEK-271..275)".

## Feasibility (the spike)

Verified in Apple's public API surface, not on a Mac:

- **Display mirroring: reliable.** `CGGetOnlineDisplayList` plus
  `CGDisplayIsInMirrorSet` report a projector, TV or AirPlay display set to
  mirror. Public, no permission, cheap enough to poll on the menu-bar tick and
  on `didChangeScreenParametersNotification`. Shipped as the automatic trigger.
- **Zoom, Meet, Teams, Slack screen sharing: not detectable reliably.** macOS
  exposes no public "the screen is being captured" signal. The candidates are
  heuristics: helper processes (Zoom's `CptHost`), window owners and sizes in
  `CGWindowListCopyWindowInfo` (window names need Screen Recording permission),
  or the purple capture indicator, which apps cannot read. Meet runs in the
  browser and leaves no process to see. None of these can be validated from a
  cloud session, and a heuristic that misses silently is worse than a shortcut
  the user trusts. Not shipped, as the plan's fallback says: manual mode with a
  global shortcut.
- **`NSWindow.sharingType = .none`: not used.** It hides windows from older
  capture APIs, but reports for macOS 15 say ScreenCaptureKit full-display
  capture ignores it, and it would also hide Peek from the owner's own
  screenshots (App Store screenshots). Not a guarantee worth advertising.
- **Focus (`INFocusStatusCenter`): deferred.** As far as I know it needs the Communication
  Notifications capability, a `com.apple.developer.*` entitlement that the
  ad-hoc test installer cannot carry without a provisioning profile (same
  reason PR 2 left out the time-sensitive entitlement). Belongs with the App
  Store signing work.
- **System notifications.** macOS has "Allow notifications when mirroring or
  sharing the display" in System Settings > Notifications, off by default, so
  the lead-time notification is already held back by the system while sharing.
  Peek does not rewrite scheduled notifications on toggle. To verify on the Mac.

## Scope (shipped in 1.16.0, build 52)

- `DiscreetModeController` (shared, persisted): manual on/off, automatic on
  mirroring (default on), global shortcut (default ⌃⌥D; ⌃⌥H, ⌃⌥⌘D or Off).
  Turning it off while mirroring holds until the mirroring ends.
- `DiscreetModePolicy`: reason, full-screen → card, menu-bar label never a
  contact name, row meta limited to provider and duration.
- Popover: day priorities hidden; next-meeting card without headline and brief
  line; rows without location; meeting page shows only summary (title, time,
  provider, join), time zones and a "Discreet mode is on" notice.
- Heads-up card: no context or prep line. Full-screen alert (and its snooze)
  becomes the card.
- Menu bar: the glyph becomes `eye.slash` while discreet.
- Footer: eye button, accent while on. Preferences > Briefs > Screen sharing:
  switch, mirroring switch, shortcut picker.
- Localization in en, it, de, fr, es.

## Out of scope

- Zoom/Meet/Teams detection heuristics, Focus, notification rewriting.

## Claimed files and subsystems

- New: `Peek/Sources/Application/DiscreetMode.swift`,
  `PeekTests/DiscreetModeTests.swift` (pbxproj IDs prefix `7D0274`).
- Small edits: `PeekApp.swift` (registrar id 3, glyph, label style, signal
  refresh), `StartingNowHUDController.swift` (`present`, `show`),
  `MenuBarView.swift`, `PreferencesView.swift` (Briefs tab), the five
  `Localizable.strings`, `CHANGELOG.md`, `docs/ROADMAP.md`.

## Dependencies

- Merges after the PRs for PEEK-275, PEEK-271/272 and PEEK-273: rebase, take
  `main`'s version, rerun `bash scripts/bump-version.sh minor`, move the
  CHANGELOG entry.

## Validation

- Linux: `bash scripts/check-version.sh`, `python3 scripts/check-localization.py`,
  `git diff --check`, pbxproj parsed. Build and tests run in CI only (see the
  pull request); not run locally.

## Physical checks for the owner (Mac)

1. Popover with a brief and day priorities, press ⌃⌥D: priorities, brief line,
   people and notes disappear; the menu-bar glyph becomes an eye; press again to
   restore.
2. Mirror the display to a TV/AirPlay or projector: discreet mode turns on by
   itself; the footer eye turns it off for that session.
3. Full-screen start alert style, discreet on: the meeting start shows the card.
4. Share the screen in Zoom and Meet with notifications on: confirm macOS holds
   back Peek's notifications, and that discreet mode needs the shortcut.

## Exact next action

Rebased on `main` after PEEK-275, 271/272 and 273 merged (1.15.0, 51) and
re-bumped to 1.16.0 (52). Owner performs the physical checks above.
