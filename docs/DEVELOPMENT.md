# Development

## Requirements

- macOS 13 or newer
- Xcode 15 or newer
- Calendar access for manual testing

## Build and test

```bash
./scripts/check-version.sh

xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
```

Use `./scripts/build-unsigned.sh` for a local ad-hoc-signed Release app with calendar entitlements.

## Continuous integration

CI runs the build and test suite on both `macos-latest` and `macos-13` runners (see `.github/workflows/ci.yml`). The `macos-13` job acts as the project's automated proxy for validating behavior on macOS 13 until dedicated hardware is available.

## Starting or handing off work

Read `AGENTS.md` and `docs/HANDOFF.md`, then claim a ready roadmap item with a file copied from `docs/workstreams/TEMPLATE.md`. Use a dedicated branch/worktree for parallel work and declare the files or subsystem you own. Before pausing or finishing, record what changed, validation performed, remaining risks, and the exact next action in both the workstream and integrated handoff.

## Version changes

The canonical values live in `Configuration/Version.xcconfig`; never duplicate them in the Xcode project. Use `./scripts/bump-version.sh build|patch|minor|major`, then update `CHANGELOG.md` and `docs/HANDOFF.md`. See `docs/VERSIONING.md` for the decision table.

## Regenerate brand assets

The source master is `design/brand/peek-app-icon-master.png`.

```bash
xcrun swift scripts/generate-assets.swift design/brand/peek-app-icon-master.png
```

The script writes every macOS app-icon size and the 1x/2x/3x template status icon. Do not resize these assets manually.

## Adding code

- Domain policies belong in `Domain` and should receive time or configuration as parameters.
- macOS APIs belong in `Infrastructure` unless they are lifecycle or rendering APIs.
- Observable state and use-case coordination belong in `Application`.
- Views and user-facing formatting belong in `Presentation`.
- Wire live dependencies only in `AppEnvironment`.

Add source files to both the app and test target only when tests compile the source directly. Existing tests currently use this pattern rather than `@testable import Peek`.

## Tests

Each behavior change should include a focused test. Priority coverage:

- boundary values for urgency, dates, filters, and imported preferences;
- malicious or malformed meeting URLs;
- event ordering when meetings are ongoing;
- notification disable/reschedule behavior through a fake scheduler;
- formatter behavior with an injected `now`.

## Pull-request checklist

- Build and tests pass without signing.
- `./scripts/check-version.sh` passes and the version was bumped when required.
- No secrets, personal calendar data, derived data, or artifacts are committed.
- User-visible strings are localized.
- New side effects have a protocol boundary or a documented reason not to.
- README, status, roadmap, and decision records are updated when scope changes.
