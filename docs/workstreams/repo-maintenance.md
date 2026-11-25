# Workstream: Repository cleanup and documentation

- Roadmap ID: N/A (maintenance)
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-sk0n5e`
- Last updated: 2026-11-25

## Objective

The repository says clearly what Peek is, what it does, how it is developed and
what is missing, with one home per fact, so agents and contributors can start
work without reconstructing state from stale documents.

## Scope

- Rewrite `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`,
  `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`, `docs/ROADMAP.md`.
- New `docs/MAC_CHECKS.md`, `docs/decisions/README.md`, `design/README.md`,
  `.github/pull_request_template.md`, `docs/workstreams/archive/README.md`.
- Remove `docs/HANDOFF.md`, `docs/PROJECT_STATUS.md`,
  `docs/PEEK-111-calendar-export-prompt.md`, `scripts/create-simple-dmg.sh`,
  `scripts/generate-icon-master.swift`.
- Archive merged workstreams; move the design handoff to `design/handoff-v1/`.
- Mark ADR 0004 Accepted; replace real people in its example and in the
  changelog and archived notes with fictional data.
- Remove external-system specifics from living docs (`docs/APP_STORE.md`,
  architecture, agent guide).
- Trim `.gitignore` to what applies; add secret patterns.
- Build-only bump to 1.16.1 (54), required by CI because a packaging script was
  removed.

## Out of scope

- App code, tests, workflows and release secrets.

## Claimed files and subsystems

- The documentation files above, `scripts/check-version-bump.sh`,
  `scripts/bump-version.sh` (messages only), `.gitignore`,
  `Configuration/Version.xcconfig`, `CHANGELOG.md`.

## Dependencies

- None. No other workstream is active.

## Progress

- [x] Audit of every non-source file.
- [x] Removals, moves and rewrites listed above.
- [x] CI green (see Validation).

## Validation

- Linux: `bash scripts/check-version.sh`, `bash scripts/check-design-tokens.sh`,
  `python3 scripts/check-localization.py`, `git diff --check`, `bash -n` on the
  touched scripts, and a link check of relative Markdown links.
- Build and tests ran in CI, not locally (run URL in the pull request).

## Decisions and open questions

- `docs/HANDOFF.md` was removed instead of refreshed: it had drifted to 1.5.5
  while `main` reached 1.16.1, because every change had to update it as well as
  the roadmap and changelog. Its role is now the "Current state" section of the
  roadmap, which carries no version number of its own.
- Merged workstreams with pending physical checks were archived; their checks
  moved to `docs/MAC_CHECKS.md` so nothing waits inside a frozen file.
- New roadmap IDs: PEEK-255 (time-sensitive entitlement), PEEK-256 (native
  translation review), PEEK-277 to PEEK-281 (post-release proposals from the
  2026-11-24 gap analysis; "providers as data" moved to 281 because PEEK-276
  was used for the context formatting fix).
- Open for the owner: a license for the public repository; real names and
  domains that remain in a source comment and in test fixtures
  (`MeetingContext.swift`, `MeetingContextTests.swift`), left for a code change.

## Exact next action

Owner reviews the pull request and merges it. After merge, move this file to
`docs/workstreams/archive/`.
