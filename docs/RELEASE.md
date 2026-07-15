# Release process

## Prerequisites

- Clean `main` branch and passing CI.
- Updated `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- Developer ID Application certificate and notarization credentials.
- Release notes derived from the changelog.

## Verification

1. Run unit tests and a Release build.
2. Inspect the built entitlements and confirm calendar access remains present.
3. Test first launch on a clean user account: calendar prompt, notification opt-in, denied access, and recovery.
4. Test event refresh, filters, join links, snooze, launch at login, import/export, hotkey, and quit.
5. Verify app and status icons in light and dark menu bars.
6. Test VoiceOver navigation and keyboard-only operation.

## Distribution

The current scripts create local ad-hoc-signed builds. Public distribution additionally requires:

1. Archive with Developer ID signing.
2. Export the signed app.
3. Submit for notarization and staple the ticket.
4. Package the stapled app in a signed DMG.
5. Validate with Gatekeeper on a clean machine.

Do not describe an ad-hoc-signed DMG as a public production release.

## Rollback

Keep the previous notarized artifact and release notes until the new build has completed a clean-install smoke test. If permission, launch, or data-loss regressions appear, remove the new artifact and publish the known-good version.
