# Workstream: Personal-data check

- Roadmap ID: N/A (maintenance)
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-sk0n5e`
- Last updated: 2026-11-25

## Objective

No future change brings personal data back into the public repository after
the history cleanup of 2026-11-25.

## Scope

- `scripts/check-personal-data.py` and `scripts/personal-data-denylist.sha256`.
- A CI step in `.github/workflows/ci.yml` that runs it on every push and pull
  request, over tracked files and the new commits' authors and messages.
- The rule in `AGENTS.md`, the script in `docs/DEVELOPMENT.md`, two checkboxes
  in the pull-request template, a `CHANGELOG.md` entry.
- Line markers on two fictional fixtures in `PeekTests/MeetingContextTests.swift`.

## Out of scope

- App behavior. Images are not scanned (no OCR); the template checkbox covers
  screenshots.

## Validation

- Linux: the four check scripts, `git diff --check`, YAML parse of `ci.yml`.
- The check passes on the current tree and on every commit since the new root,
  fails on a planted file with a denylisted term, a home path and a consumer
  email, and fails on the pre-cleanup tree (paths, terms, the committed app).
- Build and tests ran in CI, not locally (run URL in the pull request).

## Decisions and open questions

- Denylisted terms are stored as SHA-256 hashes so the list does not itself
  publish them. Hashes of short names can be guessed from a name list, so the
  owner can keep the most sensitive terms in the `PERSONAL_DATA_DENYLIST`
  repository secret instead (plain terms, one per line); CI reads it when set.
  The secret is not available to pull requests from forks.
- The Apple team ID in `Peek.xcodeproj/project.pbxproj` stays: it is printed in
  every signed build and is needed for local signing.

## Exact next action

Owner reviews and merges the pull request; then move this file to
`docs/workstreams/archive/`.
