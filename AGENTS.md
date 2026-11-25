# Peek agent guide

This is the entry point for every coding agent and contributor. `CLAUDE.md`
loads it for Claude Code. Read it in full before changing anything.

## What Peek is

Peek is a native macOS menu-bar app (Swift, SwiftUI and AppKit, macOS 13+) that
augments macOS Calendar: contextual alerts so no meeting is missed, and a meeting
page with people, cleaned notes, an optional brief and an optional context file
so the user arrives prepared. It reads calendars through EventKit and never
becomes the calendar of record. `README.md` describes the features;
`docs/ROADMAP.md` says what is done and what is missing.

## Where the truth lives

Each fact has one home. Do not copy it elsewhere; link to it.

| Question | Source of truth |
| --- | --- |
| Current version and build | `Configuration/Version.xcconfig` |
| What shipped in each version | `CHANGELOG.md` |
| Current state, priorities, what is missing | `docs/ROADMAP.md` |
| Checks only the owner can do on a Mac | `docs/MAC_CHECKS.md` |
| Who is working on what right now | `docs/workstreams/*.md` (top level only) |
| Why something is built the way it is | `docs/decisions/` (ADRs) |
| Layers, boundaries, contracts | `docs/ARCHITECTURE.md` |
| Build, test, scripts, CI | `docs/DEVELOPMENT.md` |
| Tokens, components, visual rules | `docs/DESIGN_SYSTEM.md` and `Peek/Sources/Presentation/DesignSystem/` |
| Version bump rules | `docs/VERSIONING.md` |
| Developer ID release | `docs/RELEASE.md` |
| Mac App Store and owner-side Apple steps | `docs/APP_STORE.md` |

`docs/workstreams/archive/` holds frozen records of finished work. Read one only
when you need the reasoning behind a past change.

## Start of every session

1. Run `git status --short --branch` and `git log --oneline -5`. Never assume the
   tree is clean or that `main` is where the docs say it is.
2. Read `docs/ROADMAP.md` (current state first) and `docs/ARCHITECTURE.md`.
3. List `docs/workstreams/` and read every top-level workstream file. Do not
   touch files an `Active` workstream claims.
4. Read the ADRs that cover the area you are about to change.
5. Copy `docs/workstreams/TEMPLATE.md` to `docs/workstreams/<slug>.md`, set it to
   `Active`, and name the roadmap ID, branch and claimed files.

## Working rules

* One branch per workstream: `claude/<slug>` for Claude Code, `codex/<slug>` for
  Codex, unless the owner names another. Preserve other people's changes; never
  reset, clean or overwrite work you did not make.
* Keep a change set to one logical change. Do not bundle unrelated workstreams.
* Put decisions in Domain or Application types, macOS side effects behind a
  protocol in Infrastructure, and live wiring only in `AppEnvironment`
  (`docs/ARCHITECTURE.md`).
* Every behavior change gets a focused test. Tests use the fakes in
  `PeekTests/Fakes` and inject `now`.
* Every user-visible string goes through `NSLocalizedString` and into all five
  tables (en, it, de, fr, es). `scripts/check-localization.py` fails otherwise.
* Every color, font, spacing, radius and size comes from the design system.
  `scripts/check-design-tokens.sh` fails otherwise.
* Add an ADR in `docs/decisions/` for a cross-layer, persistence, privacy or
  external-contract change. Never rewrite an accepted ADR's decision: add a new
  one and mark the old one `Superseded by ADR NNNN`.

## Invariants that must not break

* **Privacy.** No telemetry, no backend, no account. The only network call is the
  opt-in Claude brief (ADR 0005); adding any other needs an ADR and an update to
  `PrivacyInfo.xcprivacy`, `SECURITY.md` and `docs/APP_STORE.md`. Logs and
  diagnostics never contain titles, notes, attendees, locations, links or paths
  (ADR 0006).
* **Calendar export contract.** `Peek --export --from N --to N --json` and its
  JSON schema v1 are consumed by tools outside this repository. Do not change
  arguments, window semantics, calendar selection, authorization behavior, link
  classification, fields, or stdout/stderr behavior without a new schema
  version, a migration note and an ADR update (ADR 0003, `docs/ARCHITECTURE.md`).
* **Context file contract.** Peek only reads `peek-context.json` from the folder
  the user chose; it never writes there. Changes to the format follow ADR 0004
  and stay backward compatible.
* **No external-system specifics.** Peek knows nothing about any particular
  writer of the context file or consumer of the export (paths, schedules, vault
  layouts). Keep such knowledge out of code, tests and living docs.
* **Sandbox.** Peek is sandboxed for the App Store. New entitlements need a
  reason in `docs/APP_STORE.md` and a change to `scripts/check-app-bundle.sh`.
* **No real personal data** in fixtures, docs, screenshots or examples. The
  repository is public; use fictional names and `example.com`.

## Build and test

```bash
bash scripts/check-version.sh
bash scripts/check-design-tokens.sh
python3 scripts/check-localization.py
xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
git diff --check
```

Also run `bash -n` on touched shell scripts and parse touched plists and JSON.
CI (`.github/workflows/ci.yml`, job `build-and-test` on `macos-latest`) runs the
same checks plus `scripts/check-version-bump.sh` and `scripts/check-app-bundle.sh`.

## Cloud sessions (Linux, no Xcode)

Cloud sessions have no `xcodebuild`, macOS SDK, EventKit or running app.

1. Run what works on Linux: the three check scripts above, `git diff --check`,
   `bash -n`, and Python `plistlib`/`json` on touched files.
2. CI is the build and test gate. Push the branch and open a draft pull request
   with the REST API (GraphQL is not available):
   `gh api repos/acattelan77/peek/pulls -f title=... -f head=... -f base=main -f body=... -F draft=true`.
   Read results with `gh api repos/acattelan77/peek/commits/<sha>/check-runs`
   and failed logs with `gh api repos/acattelan77/peek/actions/jobs/<job_id>/logs`.
   Fix and push until `build-and-test` passes.
3. Record validation honestly: name the CI run URL and say the build and tests
   ran in CI, not locally.
4. Physical checks (menu bar, popover, alerts, permissions, visual QA, the export
   with a real consumer) are the owner's. Add them to `docs/MAC_CHECKS.md` and
   set the roadmap item to `Shipped`, never `Done`.

## Versioning

Follow `docs/VERSIONING.md`. Any user-visible change, compatibility change,
packaging change or release-relevant fix bumps the version once per change set
with `bash scripts/bump-version.sh <major|minor|patch|build>` and adds a
`CHANGELOG.md` entry. CI fails a pull request that changes `Peek/`,
`Peek.xcodeproj/`, `Configuration/` or the local packaging scripts without
raising the build number.

Parallel pull requests bump from the same base. After another one merges, rebase
on `main`, take `main`'s values in `Configuration/Version.xcconfig`, rerun the
bump with the same level, and move your `CHANGELOG.md` entry under the new
version.

## Releases and secrets

Do not push tags, run `scripts/release.sh`, dispatch `release.yml` or
`app-store.yml`, or touch signing secrets without the owner's explicit
authorization. A `v*` tag triggers a signed, notarized public release.
Submitting to App Review is always the owner's step.

## Finishing or pausing

Before you hand off or open a pull request for review:

1. Update your workstream file: status, what changed, files, validation (with the
   CI URL), open questions, and the exact next action.
2. Update `docs/ROADMAP.md` for every item whose state changed, and add the
   owner's physical checks to `docs/MAC_CHECKS.md`.
3. When the pull request merges, move the workstream file to
   `docs/workstreams/archive/`. Its pending checks stay in `docs/MAC_CHECKS.md`.
4. Fill in the pull-request template.

Never leave the next agent to infer progress from a diff.
