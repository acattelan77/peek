# Workstream: Design system consistency

- Roadmap ID: N/A
- Status: Complete
- Owner: Codex
- Branch/worktree: codex/design-system-consistency
- Last updated: 2026-07-16

## Objective

Bring the implemented UI closer to the Claude Design system by removing remaining token drift,
sharing repeated components, and aligning the app/menu-bar icon family around the same model.

## Scope

- Replace the app-icon master with the refined "peek behind the calendar" artwork.
- Align the status-bar template icon geometry with the design-system app icon.
- Replace remaining hardcoded design colors with design-system tokens.
- Move duplicated checkbox/calendar row styling into shared design-system components.
- Improve Preferences keyword filtering UI to use design-system chips.
- Remove AppKit's rectangular panel outline from the rounded Starting Now HUD.
- Add padding between onboarding actions and progress dots.
- Keep meeting notification preference state stable when macOS notification permission is not
  currently granted.
- Update relevant design documentation, version, and changelog for the user-visible polish.

## Out of scope

- New calendar features.
- Release workflow files.
- Full manual visual QA on every macOS accessibility/display mode.

## Claimed files and subsystems

- `Peek/Sources/Presentation/DesignSystem/**`
- `Peek/Sources/Presentation/MenuBar/**`
- `Peek/Sources/Presentation/Preferences/**`
- `Peek/Sources/Presentation/Onboarding/**`
- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/Presentation/HUD/**`
- `Peek/Resources/en.lproj/Localizable.strings`
- `scripts/generate-assets.swift`
- `design/brand/peek-app-icon-master.png`
- `Peek/Resources/Assets.xcassets/AppIcon.appiconset/**`
- `Peek/Resources/Assets.xcassets/StatusBarIcon.imageset/**`
- `Configuration/Version.xcconfig`
- `CHANGELOG.md`
- `docs/DESIGN_SYSTEM.md`
- `design/brand/README.md`
- `docs/HANDOFF.md`
- `docs/workstreams/design-system-consistency.md`
- `docs/workstreams/peek-107-release-workflow.md`

## Dependencies

- Previous design refresh and app-icon refresh are integrated.
- PEEK-107 workstream metadata was stale compared with `docs/HANDOFF.md` and `docs/ROADMAP.md`;
  reconciled it to `Complete` before touching version/changelog files.

## Progress

- [x] Inspect current icon asset generation and SwiftUI design-system drift.
- [x] Implement shared components and icon alignment.
- [x] Replace app-icon master and regenerate derived app/status icon sets.
- [x] Remove rectangular AppKit panel outline behind the rounded HUD.
- [x] Fix onboarding progress-dot spacing and sticky notification toggle behavior.
- [x] Run build/tests and version checks.
- [x] Record validation and remaining visual QA.

## Validation

- `xcrun swift scripts/generate-assets.swift design/brand/peek-app-icon-master.png` →
  generated AppIcon and StatusBarIcon asset sets from the refreshed master icon.
- White-background preview of `statusbar_icon@3x.png` checked manually in `/tmp`.
- `sips -g pixelWidth -g pixelHeight` on generated icon assets → app icon 16 px and
  1024 px outputs valid; status icon outputs valid at 22/44/66 px.
- `bash scripts/check-version.sh` → 1.3.3 (17) valid.
- `git diff --check` → clean.
- `plutil -lint Peek/Resources/en.lproj/Localizable.strings` → OK.
- `python3 -m json.tool` on AppIcon and StatusBarIcon `Contents.json` → OK.
- `xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` → succeeded.
- `xcodebuild -scheme Peek -destination platform=macOS -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= test` → 63 tests, 0 failures.
- Compiled Debug bundle metadata: `CFBundleShortVersionString=1.3.3`, `CFBundleVersion=17`.
- Follow-up HUD outline fix: disabled the `NSPanel` shadow and kept the SwiftUI rounded shadow;
  reran `bash scripts/check-version.sh`, `git diff --check`, `plutil -lint
  Peek/Resources/en.lproj/Localizable.strings`, Debug build, and tests. Build succeeded;
  tests passed with 63 tests and 0 failures.
- Follow-up icon refresh: replaced `design/brand/peek-app-icon-master.png` with the generated
  "peek behind the calendar" variation, refined the menu-bar template glyph, regenerated all
  app/status icon assets, reran version/whitespace/localization/catalog/dimension checks,
  Debug build, and tests. Build succeeded; tests passed with 63 tests and 0 failures.
- Follow-up onboarding/notification fixes: added top padding to the onboarding progress dots,
  stopped macOS notification permission denial from reverting `notificationsEnabled`, and
  re-check notification permission when the app becomes active so scheduling can resume after
  Settings changes. Reran `bash scripts/check-version.sh`, `git diff --check`, `plutil -lint
  Peek/Resources/en.lproj/Localizable.strings`, Debug build, and tests. Build succeeded;
  tests passed with 63 tests and 0 failures.

## Decisions and open questions

- User specifically called out app/status-bar icon model mismatch; prioritize that before
  smaller Preferences polish.
- Remaining visual QA: run the app and inspect light/dark, Reduce Motion, Increased Contrast,
  cramped menu-bar width, and a live Starting Now HUD. Not completed in this pass.

## Exact next action

None. Suggested next step is manual visual QA on the running app.
