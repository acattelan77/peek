## Summary

<!-- What changes for the user or the codebase, and why. Name the roadmap IDs. -->

## Version

<!-- New version and build from Configuration/Version.xcconfig, or "No bump: docs/tests only". -->

## Validation

<!-- Commands run and where (locally on a Mac, or Linux plus CI). Link the CI run. -->

- [ ] `bash scripts/check-version.sh`
- [ ] `bash scripts/check-design-tokens.sh`
- [ ] `python3 scripts/check-localization.py`
- [ ] `git diff --check`
- [ ] Build and tests (`build-and-test` in CI, or locally)

## Checks on a Mac

<!-- The physical checks this change needs, also added to docs/MAC_CHECKS.md. "None" if none. -->

## Docs

- [ ] `CHANGELOG.md` entry, when the version is bumped
- [ ] `docs/ROADMAP.md` item states
- [ ] Workstream file updated (archived on merge)
- [ ] ADR added or amended, when a contract, persistence, privacy or cross-layer rule changes
- [ ] No real personal data, secrets, build outputs or artifacts committed
