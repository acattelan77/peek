# Workstream: Cloud agent setup

- Roadmap ID: N/A
- Status: In review
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
- [ ] Owner review and merge.

## Validation

- `bash scripts/check-version.sh`: passed on Linux.
- `git diff --check`: passed.
- No app files changed, so no version bump is required.
- The macOS CI run on this pull request is the first check that the cloud
  validation loop works end to end.

## Decisions and open questions

- Documentation only; no marketing-version or build bump.
- Open: whether the owner wants cloud sessions to work only from GitHub `main`,
  or also needs unpushed work from the local repository pushed first.

## Exact next action

Owner reviews and merges the pull request; then pull `main` in the local
repository.
