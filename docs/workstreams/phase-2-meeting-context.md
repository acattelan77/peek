# Workstream: Phase 2, meeting context

- Roadmap ID: PEEK-211, PEEK-212, PEEK-213 (PEEK-214 deferred)
- Status: In review
- Owner: Claude Code (cloud session, project thread "Pianificare Peek 2.0 per l'App Store")
- Branch/worktree: `claude/phase-2-meeting-context`, stacked on `claude/project-thread-t3424o` (PR #10)
- Last updated: 2026-11-23

## Objective

Show who the user is about to meet and what to prepare, from data already on
the Mac: attendees matched with Contacts, invitation notes without boilerplate,
and context another app writes into a chosen folder.

## Scope

- PEEK-212: `InvitationTextCleaner` strips Zoom, Meet, Teams, dial-in, SIP and
  H.323 boilerplate and simple HTML from notes.
- PEEK-211: `MeetingContextBuilder` builds people (without the current user,
  rooms and duplicates) and the headline; `SystemContactsDirectory` looks up
  role and company only after the user turns the feature on and grants access.
  Without a card, the company email domain is shown; personal mail domains are not.
- PEEK-213: `MeetingContextFile` (contract in ADR 0004) and `ContextFolderStore`
  (security-scoped, read-only bookmark).
- UI: headline in the hero row, the heads-up card and the full-screen alert;
  Context, Notes and Attendees with role in the expanded row; a "Meeting
  context" group in Preferences.

## Out of scope

- PEEK-214 Google Calendar direct access (deferred after 2.0 per plan).
- Phase 3 AI brief. Any change to the PEEK-111 export.

## Claimed files and subsystems

- `Peek/Sources/Domain/Context/`, `Peek/Sources/Infrastructure/Context/`,
  `Peek/Sources/Application/MeetingContextProvider.swift`
- Meeting-context parts of `MenuBarView.swift`, `PreferencesView.swift`,
  `StartingNowHUD.swift`, `MeetingStartAlert.swift`, `CalendarManager.swift`
- `Peek/Resources/Peek.entitlements`, `Info.plist`, `*.lproj`
- `PeekTests/MeetingContextTests.swift`, `docs/decisions/0004-meeting-context-file.md`

## Dependencies

- Phase 1 (PR #10) is the base branch. Merge it first, then retarget this PR to `main`.

## Progress

- [x] PEEK-212 cleaned notes
- [x] PEEK-211 people and headline, Contacts adapter, Preferences toggle
- [x] PEEK-213 context file contract, reader, Preferences folder picker
- [x] Localization of new strings (it, de, fr, es) and the Contacts prompt

## Validation

- Linux cloud session: `check-version.sh`, `check-design-tokens.sh`,
  `check-localization.py` and `git diff --check`; plists parsed with `plistlib`.
- Build and tests run in CI only (`build-and-test` on `macos-latest`).

### Owner checks on a Mac

1. Turn on "Show who you're meeting": the Contacts prompt appears once, in
   your language. A meeting with a known contact shows "You're about to meet
   <name>, <role> at <company>" in the hero row, the heads-up card and the
   full-screen alert. Denying access leaves the switch off with a footnote.
2. A Zoom, a Meet and a Teams invitation: the expanded row's Notes keep only the
   agenda.
3. Choose a folder with a `peek-context.json` (example in ADR 0004) whose `id`
   comes from `Peek --export --from 0 --to 7 --json`: headline, Context section
   and people notes appear; the footnote counts the events; Remove clears it.
   Quit and relaunch: the folder is still readable (bookmark).
4. Without Contacts and without a folder, a meeting card shows no empty fields.

## Decisions and open questions

- One file per folder instead of one file per event: one atomic write for the
  writer, one read for Peek, and no filename rules for opaque ids.
- The headline comes from the context file first, then from people.
- Open: the Northwind Notes writer is not built. The file format in ADR 0004 is a
  proposal to settle with the Northwind Notes renderer before it is "Accepted".
- Open: Contacts lookups run on the main thread with a per-email cache; fine for
  typical meetings, to recheck with very large invitations.

## Exact next action

Owner runs the checks above after PR #10 merges; then retarget this PR to `main`.
