# Peek agent operating contract

This file is the required entry point for every coding agent working in this repository.

## Start of every work session

Before editing anything:

1. Read `docs/HANDOFF.md` for the last known state and recommended starting point.
2. Read `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, and `docs/VERSIONING.md`.
3. Run `git status --short --branch` and inspect existing worktrees or branches. Never assume the tree is clean.
4. Read `docs/workstreams/README.md` and every active workstream file.
5. Create or claim one narrowly scoped workstream before making broad changes.

## Parallel-work rules

- Prefer one branch and worktree per agent. Branch names should use `codex/<workstream>` or, for Claude Code sessions, `claude/<workstream>`, unless the owner specifies otherwise.
- Each agent owns a distinct set of files or subsystem. Record that ownership in `docs/workstreams/<workstream>.md`.
- Do not modify files claimed by an active workstream without coordinating through its handoff file.
- Preserve unrelated changes. Never reset, overwrite, or clean another agent's work.
- Commit cohesive changes when authorized; do not bundle unrelated workstreams.
- The roadmap expresses priority. Workstream files express active ownership. `docs/HANDOFF.md` expresses the integrated project state.

## Finishing or pausing

Before handing work to another agent:

1. Update the workstream file with status, completed work, files changed, validation, open questions, and the exact next action.
2. Update `docs/HANDOFF.md` only if you are the integrator or the work changes the integrated starting point.
3. Update `docs/ROADMAP.md` when an item changes state or scope.
4. Run the relevant build/tests and record the command and result.
5. Run `bash scripts/check-version.sh`.

Never leave the next agent to infer progress from a diff alone.

## Cloud sessions (Linux, no Xcode)

Claude Code cloud sessions run in a Linux container. `xcodebuild`, the macOS
SDK, EventKit and the running app are not available there. In those sessions:

1. Run what works on Linux before pushing: `bash scripts/check-version.sh`,
   `git diff --check`, and `bash -n` on touched scripts. Parse touched plists
   and JSON (for example with Python `plistlib` and `json`).
2. Treat CI as the build and test gate. Push the branch, open a draft pull
   request, and wait for the `build-and-test` job on `macos-latest`. GraphQL
   is not available in cloud sessions, so use the REST API: open the pull
   request with `gh api repos/acattelan77/peek/pulls -f title=... -f head=...
   -f base=main -f body=... -F draft=true`, read results with
   `gh api repos/acattelan77/peek/commits/<sha>/check-runs`, and failed logs
   with `gh api repos/acattelan77/peek/actions/jobs/<job_id>/logs`. Fix and
   push until it passes.
3. Record validation honestly in the workstream: name the CI run URL and say
   that the build and tests ran in CI, not locally.
4. Physical validation stays with the owner on a Mac: menu-bar and popover
   behavior, the Starting now HUD, visual QA, permissions, and the PEEK-111
   Northwind Notes consumer. When a change needs it, set the workstream to
   `In review` with the exact checks to perform, never `Complete`.
5. Parallel pull requests bump the version from the same base. After another
   pull request merges, rebase on `main`, take `main`'s values in
   `Configuration/Version.xcconfig`, rerun `bash scripts/bump-version.sh` with
   the same level, and move the `CHANGELOG.md` entry under the new version. CI
   enforces the bump.
6. Do not push tags, run `scripts/release.sh`, or touch release secrets or the
   `release.yml` workflow without explicit owner authorization: a version tag
   triggers a signed, notarized release.

## Versioning requirement

Follow `docs/VERSIONING.md`. Any user-visible feature, behavior change, compatibility change, packaging change, or release-relevant fix must bump the version once per logical change set with `bash scripts/bump-version.sh <major|minor|patch|build>`. Update `CHANGELOG.md` in the same workstream. Pure documentation, tests, comments, and internal refactors do not require a marketing-version bump unless they materially change the release.

## Required quality checks

```bash
bash scripts/check-version.sh
xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
```

Also run `git diff --check` and validate any touched scripts, plists, JSON, localization, or image assets.
