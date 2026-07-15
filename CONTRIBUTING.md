# Contributing

Small, focused changes are preferred. For architectural or product-scope changes, open an issue or discussion before implementation.

1. Read `AGENTS.md`, `docs/HANDOFF.md`, `docs/ROADMAP.md`, and `docs/ARCHITECTURE.md`.
2. Check `docs/workstreams/` for active ownership, then create a branch or worktree from `main`.
3. Copy `docs/workstreams/TEMPLATE.md`, mark it `Active`, and name the roadmap ID, owner, branch, and claimed files.
4. Add tests for behavior changes.
5. Run the version check, unsigned build, and complete test suite.
6. Update the workstream, handoff, roadmap, changelog, and decision records affected by the change.

## Parallel work

Use one branch and preferably one Git worktree per agent. Split work by subsystem and avoid editing another active workstream's claimed files. Do not overwrite or discard unrelated changes in a shared worktree. Integration should be sequential, with validation rerun after each merge.

## Versioning

`Configuration/Version.xcconfig` is the only version source of truth. Follow `docs/VERSIONING.md`: bump the build for every distributable change and bump the semantic version for user-visible behavior, compatibility, or breaking changes. Run `./scripts/check-version.sh` before handoff.

Do not commit calendar data, screenshots containing private events, signing credentials, `build/`, or `artifacts/`.
