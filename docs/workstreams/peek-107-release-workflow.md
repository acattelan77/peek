# Workstream: PEEK-107 release workflow

- Roadmap ID: PEEK-107
- Status: Active
- Owner: Agent
- Branch/worktree: codex/peek-107-release-workflow
- Last updated: 2026-07-15

## Objective

Establish a Developer ID-signed, notarized release workflow and document the required secrets and update policy.

## Scope

- Add a GitHub Actions `release.yml` workflow that triggers on version tags.
- Add `scripts/release.sh` to build a Release app with Developer ID signing, package a DMG, notarize it, and staple the ticket.
- Update `docs/RELEASE.md` with the release steps and secret list.
- Keep Sparkle out for now; use GitHub Releases as the update channel and document manual update checks.
- Bump the version for the packaging/release-infrastructure change.

## Out of scope

- Acquiring actual Apple Developer ID certificates or notarization credentials.
- Adding an in-app Sparkle updater.
- Publishing a release to a non-GitHub channel.

## Claimed files and subsystems

- `.github/workflows/release.yml`
- `scripts/release.sh`
- `docs/RELEASE.md`
- `CHANGELOG.md`
- `docs/HANDOFF.md`
- `docs/ROADMAP.md`
- `Configuration/Version.xcconfig`

## Dependencies

- PEEK-105 and PEEK-108 are integrated on this branch.

## Progress

- [x] Create workstream and branch
- [ ] Add release workflow
- [ ] Add release script
- [ ] Update release documentation
- [ ] Bump version and update changelog/handoff
- [ ] Run checks, build, and tests

## Validation

- Not run yet.

## Decisions and open questions

- Use GitHub Releases as the update channel; Sparkle can be added later without changing the workflow.

## Exact next action

Create `.github/workflows/release.yml` and `scripts/release.sh`.
