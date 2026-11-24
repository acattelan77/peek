# Workstream: App Store readiness

- Roadmap ID: PEEK-251, PEEK-252, PEEK-253, PEEK-254
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-yp9eyy`
- Last updated: 2026-11-24

## Objective

Everything the repository can do for a Mac App Store release is in place and
checked by CI, and the owner has an exact list of the Apple and GitHub steps
only they can do. Submission for App Review stays last and is the owner's.

## Scope

- PEEK-251: privacy manifest (`PrivacyInfo.xcprivacy`) and export compliance
  (`ITSAppUsesNonExemptEncryption = NO`), with a bundle check in CI.
- PEEK-252: sandbox entitlements review (no change needed) and a reusable
  `scripts/check-app-bundle.sh`.
- PEEK-253: App Store archive/export/upload pipeline (`scripts/app-store.sh`,
  `.github/workflows/app-store.yml`, manual dispatch, cloud-managed signing
  with an App Store Connect API key), next to the Developer ID DMG. Fix
  `scripts/release.sh` to sign manually with the Developer ID identity.
- PEEK-254: `docs/APP_STORE.md` with secrets and Apple-side steps, metadata
  drafts, privacy answers, screenshots plan, TestFlight plan, privacy policy
  draft.

## Out of scope

- Setting secrets, creating certificates, keys, identifiers or the App Store
  Connect record (owner).
- Price, final app name, bundle ID change, privacy-label stance (owner).
- `release.yml` changes, tags, releases (owner authorization required).
- Screenshots themselves (after the UI alignment in PR 15 is accepted).

## Claimed files and subsystems

- `Peek/Resources/PrivacyInfo.xcprivacy`, `Peek/Resources/Info.plist`
  (`ITSAppUsesNonExemptEncryption` only), the PrivacyInfo entries in
  `Peek.xcodeproj/project.pbxproj`
- `scripts/app-store.sh`, `scripts/check-app-bundle.sh`, `scripts/release.sh`
- `.github/workflows/app-store.yml`, the bundle-check step in `.github/workflows/ci.yml`
- `docs/APP_STORE.md`, `docs/RELEASE.md` (pointer only)

## Dependencies

- Owner: Apple Developer Program, App Store Connect API key (Admin), app
  record, GitHub secrets, Developer ID certificate. See `docs/APP_STORE.md`.
- PR 15 (UI alignment, 1.11.0) for final screenshots.

## Progress

- [x] Privacy manifest and encryption key, bundled and checked in CI
- [x] Entitlements reviewed: each maps to one feature; none missing or excess
- [x] App Store script and manual workflow
- [x] Developer ID `release.sh` manual-signing fix and bundle check
- [x] Owner guide, metadata drafts, privacy answers, screenshots and TestFlight plans
- [ ] First real App Store export (needs the owner's API key secrets)
- [ ] TestFlight install on both Macs, checks listed in `docs/APP_STORE.md`

## Validation

- Linux: `bash scripts/check-version.sh`, `git diff --check`, `bash -n` on
  the three touched scripts, plistlib parse of `PrivacyInfo.xcprivacy` and
  `Info.plist`, YAML parse of the new workflow.
- CI, not local: `build-and-test` on macos-latest passed on 3e88ae3 (1.11.1,
  rebased on PR 15; now 1.12.5 (47) on top of PR 20, rerun on the PR): unsigned build, 187 tests, and "App bundle checks
  passed" on the Debug app.
  https://github.com/acattelan77/peek/actions/runs/45369944374
- Not run: `scripts/app-store.sh` and `scripts/release.sh` signed paths. They
  need the owner's secrets; the first App Store workflow run with Upload off
  is the test.

## Decisions and open questions

- Signing for the store is cloud-managed with an App Store Connect API key, so
  no `.p12` or profile is stored for it. The DMG path keeps its `.p12` because
  `release.yml` is unchanged.
- Privacy labels: manifest declares Other User Content and Contacts for the
  optional Claude brief (conservative). Owner may choose "Data Not Collected";
  then remove `NSPrivacyCollectedDataTypes` entries.
- Open for the owner: app name, bundle ID, price, category, privacy policy URL.

## Exact next action

Owner: follow "Apple-side steps" in `docs/APP_STORE.md`, then Actions > App
Store > Run workflow with Upload off. Agent: fix whatever that first run
reports, then rerun with Upload on.
