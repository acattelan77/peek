# Workstream: Phase 3, meeting brief

- Roadmap ID: PEEK-221, PEEK-222, PEEK-223, PEEK-224
- Status: In review
- Owner: Claude Code (cloud session, project thread "Pianificare Peek 2.0 per l'App Store")
- Branch/worktree: `claude/phase-3-ai-brief`, stacked on `claude/phase-2-meeting-context` (PR #11)
- Last updated: 2026-11-23

## Objective

Three to five points on what to prepare before a meeting, written on the Mac
or by Claude with the user's key, or taken from the context file, with the
source always visible and nothing sent without consent.

## Scope

- Domain: `BriefInput`, `BriefPrompt`, `BriefParser`, `BriefPolicy`, `MeetingBrief`.
- Engines: `OnDeviceBriefEngine` (Foundation Models), `ClaudeBriefEngine`
  (Messages API, raw HTTP) and `AnthropicKeyStore` (keychain).
- `MeetingBriefService`: settings, consent version, automatic preparation from
  the status-bar tick, cache (`BriefCacheStore`), retry back-off.
- UI: up to three points in the hero row, a Brief section with source label,
  "Prepare brief" and errors in the expanded row, points in the full-screen
  alert, and a "Meeting brief" group in Preferences (switch, engine, consent
  alert, API key, excluded keywords).

## Out of scope

- Streaming, attachments, Google Calendar, a Peek-hosted proxy, the heads-up
  card (kept compact on purpose).

## Claimed files and subsystems

- `Peek/Sources/{Domain,Application,Infrastructure}/Brief/`
- Brief parts of `MenuBarView.swift`, `PreferencesView.swift`,
  `MeetingStartAlert.swift`, `StartingNowHUDController.swift`, `PeekApp.swift`
- `Peek/Resources/Peek.entitlements`, `*.lproj`, app target `OTHER_LDFLAGS`
- `PeekTests/MeetingBriefTests.swift`, `docs/decisions/0005-meeting-brief-data-and-consent.md`

## Dependencies

- Phase 2 (PR #11) is the base, itself on phase 1 (PR #10). Merge in order,
  retargeting each PR to `main` after its base merges.

## Progress

- [x] Prompt, parser, policy, fingerprint and cache
- [x] On-device engine and Claude engine with keychain key
- [x] Consent screen, versioned consent, keyword exclusions
- [x] UI and localization (it, de, fr, es)
- [x] Unit tests with fictional fixtures

## Validation

- Linux cloud session: `check-version.sh`, `check-design-tokens.sh`,
  `check-localization.py`, `git diff --check`; entitlements parsed with `plistlib`.
- Build and tests run in CI only (`build-and-test` on `macos-latest`).
- No live model call was made: neither engine was exercised end to end.

### Owner checks on a Mac

1. Preferences, Meeting brief: turn it on. On a Mac without macOS 26 or Apple
   Intelligence the footnote says why the on-device engine is unavailable.
2. On macOS 26 with Apple Intelligence: a meeting with attendees or notes
   starting within 15 minutes gets points in the hero row, labelled "Written
   on this Mac"; the full-screen alert shows up to three of them.
3. Choose "Claude (your API key)": the consent alert lists the fields; Cancel
   keeps "On this Mac". Accept, paste a key, Save: the field becomes "Saved in
   your keychain". Expand a meeting and use "Prepare brief": the brief says
   "Written by Claude". A wrong key shows the rejected-key message.
4. A context file with `bullets` for an event shows them as the brief, labelled
   "From your context folder", with briefs off too.
5. Add an excluded keyword matching a meeting title: no brief and no button.
6. Edit the meeting notes: the old brief disappears and a new one can be prepared.
   Turn briefs off and on: generated briefs are gone.
7. On macOS 13 to 15, the app launches (weak-linked FoundationModels).

## Decisions and open questions

- See ADR 0005. The consent text lists the `BriefInput` fields; change both together.
- Open: who builds the Northwind Notes writer for `peek-context.json`.
