# Development

Process rules (claiming work, invariants, versioning, hand-off) are in
`AGENTS.md`. This page covers the tools.

## Requirements

* macOS with Xcode 26 or later. The project uses the macOS 26 SDK; the app's
  deployment target is macOS 13, and newer frameworks (FoundationModels) are
  weak-linked behind `#if canImport` and availability checks.
* Calendar access on the Mac for manual testing. Contacts and notifications are
  optional.
* Python 3 for the localization check.

There are no third-party dependencies and no package manager.

## Build and test

```bash
bash scripts/check-version.sh
bash scripts/check-design-tokens.sh
python3 scripts/check-localization.py

xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
```

The test action is pinned to en-US, so string assertions pass on a Mac set to
another language.

## Scripts

| Script | Purpose | Where it runs |
| --- | --- | --- |
| `check-version.sh` | Version metadata is valid and lives only in `Configuration/Version.xcconfig` | CI, locally, Linux |
| `check-version-bump.sh <base>` | Release-relevant changes raise the build number | CI |
| `bump-version.sh <level>` | Raise the version (`major`, `minor`, `patch`, `build`, or `X.Y.Z`) | Locally |
| `check-design-tokens.sh` | No hardcoded colors, fonts, spacing, radii or sizes outside the design system | CI, Linux |
| `check-localization.py` | Every string is in all five tables with matching format specifiers, and no table has unused keys | CI, Linux |
| `check-app-bundle.sh <app> [--distribution]` | A built app carries the privacy manifest, usage descriptions, export-compliance key and entitlements | CI, release scripts |
| `build-unsigned.sh [--install]` | Ad-hoc signed Release app with working entitlements; `--install` copies it to `/Applications` | Mac |
| `create-dmg.sh` | Ad-hoc signed Release app in `artifacts/Peek-Installer.dmg` | Mac |
| `release.sh` | Developer ID signed, notarized, stapled DMG (needs secrets; owner only) | `release.yml`, Mac |
| `app-store.sh` | Mac App Store archive, export and optional TestFlight upload (needs secrets; owner only) | `app-store.yml` |
| `generate-assets.swift <master>` | App-icon sizes and the menu-bar template glyph from the master PNG | Mac |

Local outputs go to `build/` and `artifacts/`, which are ignored.

## Continuous integration

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` (`build-and-test`) | Every pull request and push to `main` | Version, version-bump, token and localization checks; unsigned build; bundle check; tests. The required gate. |
| `test-installer.yml` | Push to `main`, or manual for any branch | Ad-hoc signed DMG as the `Peek-test-installer` artifact for 30 days. Not notarized; not a release. |
| `release.yml` | `v*` tag, or manual | Developer ID signed, notarized DMG and a GitHub Release. Secrets are not configured yet. |
| `app-store.yml` | Manual only | App Store package and optional TestFlight upload. Secrets are not configured yet. |

All jobs run on `macos-latest`. GitHub's hosted `macos-13` runner was retired,
so macOS 13 compatibility needs real hardware (PEEK-AUD-07).

## Adding code

* Domain policies go in `Domain` and receive time and configuration as
  parameters.
* macOS APIs go in `Infrastructure` behind a protocol, unless they are lifecycle
  or rendering APIs.
* Observable state and use-case coordination go in `Application`.
* Views and user-facing formatting go in `Presentation`, using only design-system
  tokens and components.
* Live dependencies are wired only in `AppEnvironment`.

`Peek.xcodeproj` is maintained by hand: add every new file to
`project.pbxproj` (file reference, group and the target's build phase). The
tests run with the app as test host and use `@testable import Peek`, so a new
source file belongs to the app target only; a new test file belongs to
`PeekTests`.

## Tests

Each behavior change includes a focused test. Use the fakes in
`PeekTests/Fakes` (event store, notification scheduler, launch at login) and
inject `now`. Priorities:

* boundary values for urgency, dates, filters and persisted preferences;
* malicious or malformed meeting URLs and context-file links;
* ordering and dedupe of ongoing, recurring and duplicated events;
* notification scheduling and rescheduling after time changes;
* export payload compatibility (schema v1);
* contrast of design tokens in every appearance.

Fixtures use fictional people, companies and `example.com` addresses.

## Localization

Strings live in `Peek/Resources/<lang>.lproj/Localizable.strings` for en, it, de,
fr and es; permission prompts are in `InfoPlist.strings`. Add every new key to
all five tables in the same change. The project keeps `.strings` tables rather
than a String Catalog so diffs stay reviewable.

## Brand assets

The app-icon master is `design/brand/peek-app-icon-master.png`. After changing it,
regenerate the asset catalog:

```bash
xcrun swift scripts/generate-assets.swift design/brand/peek-app-icon-master.png
```

This writes every app-icon size and the 1x, 2x and 3x template status icon. Do
not resize these assets by hand. Check the result at 16, 32, 128 and 1024 px.

## Pull-request checklist

The pull-request template lists it. In short: checks, build and tests pass;
the version is bumped when required, with a changelog entry; no secrets,
personal data, derived data or artifacts are committed; strings are localized;
new side effects have a protocol boundary; roadmap, Mac checks and ADRs are
updated when scope changes.
