# Workstream: Design system v2 (semantic tokens, accessibility, full adoption)

- Roadmap ID: N/A (design system)
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: claude/project-thread-c9k1h0
- Last updated: 2026-11-23

## Objective

Every Presentation surface consumes one semantic token layer (color, type, icon, spacing,
radius, metrics). No hardcoded design value is left outside `Presentation/DesignSystem/`,
and every text/background token pair meets WCAG AA in light and dark.

## Scope

- Make `PeekNSColor` the single source of truth for colors and derive `PeekColor` from it.
  Remove duplicated menu-bar tints.
- Add semantic roles: `accentText`, `accentRail`, `onAccent`, `urgentText`, `onUrgent`,
  `criticalText`, `onCritical`, `calmText`, and `controlStroke`. Add Increased Contrast
  variants for hairlines, borders, and secondary/tertiary text.
- Fix contrast failures found in the 2026-11-23 audit. These are tertiary text on light
  surfaces, white on amber, white on red, amber/red/green text on washes, accent text on
  dark surfaces, the dark `fill` that was nearly invisible, and menu-bar urgency tints on
  a light menu bar.
- Centralize typography (`PeekFont`), SF Symbol sizes (`PeekIcon`), spacing (`PeekSpacing`),
  radius (`PeekRadius`) and component metrics (`PeekMetrics`).
- Promote `FooterButton`, `JoinButtonStyle`, `CriticalPulse`, and `TabButton` into
  `PeekComponents.swift`. Add disabled states to button styles and a selected trait to tabs.
- Fix `CriticalPulse` and `PulsingDot` so they start when a row becomes critical while
  visible, and stop when Reduce Motion is turned on.
- Migrate the popover, Preferences, onboarding, and HUD to tokens.
- Add `scripts/check-design-tokens.sh` (CI-enforced) and `DesignSystemTests` (contrast
  regression).
- Correct `docs/DESIGN_SYSTEM.md` (single palette) and the PEEK-108 "Dynamic Type"
  claim in `docs/HANDOFF.md` and `docs/ROADMAP.md`.

## Out of scope

- App-icon artwork and the menu-bar template glyph.
- New features or layout redesigns.
- Physical visual QA (owner, on a Mac, PEEK-AUD-07).

## Claimed files and subsystems

- `Peek/Sources/Presentation/**`
- `Peek/Sources/App/PeekApp.swift` (urgency title tint only)
- `PeekTests/DesignSystemTests.swift`, `Peek.xcodeproj/project.pbxproj` (test file entry)
- `scripts/check-design-tokens.sh`, `.github/workflows/ci.yml` (one lint step)
- `docs/DESIGN_SYSTEM.md`, `docs/HANDOFF.md`, `docs/ROADMAP.md`
- `CHANGELOG.md`, `Configuration/Version.xcconfig`

## Dependencies

- None. No other workstream is Active, In review, or Blocked on these files.

## Progress

- [x] Audit (2026-11-23): tokens exist, adoption is partial, contrast failures found.
- [x] Token layer v2
- [x] Component promotion and fixes
- [x] Surface migration
- [x] Lint and tests
- [x] Docs, version, changelog (1.6.0, build 35)
- [x] CI green on draft PR #9

## Validation

- Cloud session (Linux, no Xcode). The build and tests run in CI, not locally.
- `bash scripts/check-version.sh` → 1.6.0 (35) valid.
- `bash scripts/check-design-tokens.sh` → OK. A negative test with a scratch file containing
  each forbidden pattern was rejected as expected.
- `git diff --check` → clean.
- Contrast: every pair in `DesignSystemTests` was checked offline with a Python WCAG script
  that parses `PeekTheme.swift` (light, dark, high-contrast light, high-contrast dark). There
  were 0 failures.
- CI `build-and-test` on macos-latest passed on 6d61231. The token lint passed, the build
  succeeded, and 100 tests ran with 0 failures, including the 5 `DesignSystemTests`:
  https://github.com/acattelan77/peek/actions/runs/45166326873/job/137664101423

## Decisions and open questions

- Peek's design system is its own. It does not follow Northwind's Visual Identity.
- macOS 13 gives third-party apps no Dynamic Type: SwiftUI text styles have fixed sizes
  on macOS. Fixed point sizes stay, centralized in `PeekFont`. The PEEK-108 claim was
  corrected rather than reimplemented.
- Handoff hues are kept where they pass contrast. Where they fail, a text-specific or
  fill-specific role was added, so the brand hue survives on rails and icons.

## Exact next action

Owner visual QA on a Mac, following "Visual QA" in `docs/DESIGN_SYSTEM.md`. Check light,
dark and Increased Contrast; the amber badge with dark text; the critical red `#D13438`;
Reduce Motion toggled live; a row turning critical with the popover open; and SOON/NOW
tints on a light menu bar. Then mark PR #9 ready and merge.
