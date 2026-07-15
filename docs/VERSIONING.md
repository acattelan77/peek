# Versioning

Peek uses Semantic Versioning for `MARKETING_VERSION` and a monotonically increasing integer for `CURRENT_PROJECT_VERSION`.

The single source of truth is `Configuration/Version.xcconfig`.

## When to bump

| Change | Bump | Examples |
| --- | --- | --- |
| Major | `major` | Incompatible settings format, removed core workflow, minimum-OS jump with meaningful user impact |
| Minor | `minor` | New user-visible feature, redesigned experience, substantial release milestone |
| Patch | `patch` | User-visible bug fix, small behavior or compatibility improvement |
| Build only | `build` | Repackaging or rebuilding the same marketing version |
| No bump | None | Documentation, comments, tests, or internal refactoring with no release impact |

Every marketing-version bump also increments the build number. Run one bump for the whole logical change set, not once per commit.

## Commands

```bash
bash scripts/bump-version.sh minor
bash scripts/bump-version.sh patch
bash scripts/bump-version.sh build
bash scripts/bump-version.sh 2.0.0
bash scripts/check-version.sh
```

The explicit version form sets the marketing version and increments the build number.

## Required accompanying changes

- Update `CHANGELOG.md`.
- Update `docs/HANDOFF.md` if the integrated version changes.
- Include the version in release notes and artifacts.
- Run `scripts/check-version.sh`, build, and tests before handoff.

CI runs `scripts/check-version-bump.sh` against the base commit. If app code, resources, packaging, or Xcode configuration changed, the build number must be higher than the base. The first commit that introduces centralized versioning is accepted as the baseline.

The app displays `Version <marketing> (<build>)` from its compiled bundle metadata in Preferences.
