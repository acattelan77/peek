# Workstream: Cloud agent setup

- Roadmap ID: N/A
- Status: Complete
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/cloud-agent-setup`
- Last updated: 2026-11-23

## Objective

Let Claude Code cloud sessions, including parallel threads in a Claude Code
project, follow the existing agent contract and validate their work without
Xcode.

## Scope

- `CLAUDE.md` that loads `AGENTS.md`, so Claude Code reads the contract
  automatically.
- `AGENTS.md`: `claude/<workstream>` branch names and a section for cloud
  sessions (Linux checks, CI as the build and test gate, physical validation
  left to the owner, version bumps across parallel pull requests, no release
  tags without authorization).

## Out of scope

- App code, versioning policy, CI and release workflows.

## Claimed files and subsystems

- `CLAUDE.md`
- `AGENTS.md`
- `docs/workstreams/cloud-agent-setup.md`

## Dependencies

- None.

## Progress

- [x] `CLAUDE.md` added.
- [x] `AGENTS.md` updated.
- [x] Owner review and merge: pull request #7, squash-merged to `main` as
  `12c2428` on 2026-11-23.

## Validation

- `bash scripts/check-version.sh`: passed on Linux.
- `git diff --check`: passed.
- No app files changed, so no version bump is required.
- macOS CI on pull request #7 (head `6cd9591`): `build-and-test` passed, build
  succeeded and 95 tests passed with zero failures, run in CI, not locally:
  https://github.com/acattelan77/peek/actions/runs/45148301926
- The REST commands documented in `AGENTS.md` for opening pull requests and
  reading check runs and job logs were used in this workstream and worked.

## Decisions and open questions

- Documentation only; no marketing-version or build bump.
- Resolved: the local repository had no unpushed work; `main` matched
  `origin/main` at `f208d14`, and the two local `codex/` branches were already
  contained in `main` and were deleted by the owner.
- Cloud sessions cannot delete remote branches; the owner deletes merged
  `claude/` branches.

## Exact next action

None. Workstream complete.
