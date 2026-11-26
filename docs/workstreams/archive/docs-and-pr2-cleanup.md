# Workstream: Short agent docs and PR 2 cleanup

- Roadmap ID: N/A (maintenance, follows PEEK-282)
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-ydzd3l`
- Last updated: 2026-11-26

## Objective

Agents find where to start and read only what they need; PR 2 leaves no unused
code or stale workstream files.

## Scope

- Remove code the PEEK-282 fix left unused; update the comments.
- Archive the PEEK-282 and personal-data-check workstreams; PEEK-282 to
  `Shipped` in the roadmap; two new owner checks in `docs/MAC_CHECKS.md`.
- Move changelog versions before 1.13 and the roadmap's Done list to
  `docs/history/`; `AGENTS.md` says what to read and when.
- Build bump to 1.16.2 (56).

## Out of scope

- Any app behavior change.

## Claimed files and subsystems

- `Peek/Sources/App/PopoverAnchorController.swift`,
  `Peek/Sources/App/PopoverAnchorGeometry.swift`, `Peek/Sources/App/PeekApp.swift`
  (one line), `PeekTests/StatusBarSpacePolicyTests.swift`
- `AGENTS.md`, `CHANGELOG.md`, `docs/ROADMAP.md`, `docs/MAC_CHECKS.md`,
  `docs/history/`

## Dependencies

- None.

## Progress

- [x] Code cleanup, docs, version bump.
- [ ] CI `build-and-test` green on the pull request.

## Validation

- Linux: version, design-token, localization and personal-data checks, and
  `git diff --check`. Build and tests run in CI only.

## Decisions and open questions

- `docs/ROADMAP.md` stays the project tracker (the to-do list) and `AGENTS.md`
  the handoff; no new files duplicate them.

## Exact next action

Owner reviews and merges; then archive this file.
