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
4. Test event refresh, filters, join links, snooze, launch at login, hotkey, and quit.
5. Verify app and status icons in light and dark menu bars.
6. Test VoiceOver navigation and keyboard-only operation.

## Distribution

The `release.yml` GitHub Actions workflow produces a Developer ID-signed, notarized, stapled DMG whenever a `v*` tag is pushed.

Required repository secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE` — base64-encoded Developer ID Application `.p12`.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` — password for the `.p12`.
- `APPLE_DEVELOPER_IDENTITY` — exact identity string, e.g. `Developer ID Application: Your Name (TEAM_ID)`.
- `APPLE_ID` — Apple ID for `notarytool`.
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password for `notarytool`.
- `APPLE_TEAM_ID` — Apple Developer Team ID.
- `KEYCHAIN_PASSWORD` — temporary keychain password used during the runner job.

The workflow performs the following steps:

1. Validates version metadata with `scripts/check-version.sh`.
2. Imports the Developer ID certificate into a temporary keychain.
3. Runs `scripts/release.sh` to build a signed Release app, package a DMG, submit it for notarization, and staple the ticket.
4. Uploads the DMG as a workflow artifact.
5. Creates a GitHub Release and attaches the DMG.

To create a release locally, ensure the secrets above are exported as environment variables and run:

```bash
./scripts/release.sh
```

The output is written to `artifacts/Peek-<version>.<build>.dmg`.

### Update policy

Peek does not include an automatic updater. New versions are published as GitHub Releases, and users are notified through release notes. A Sparkle-based automatic updater may be added in a future release if it is justified by the project scope and privacy design.

Do not describe an ad-hoc-signed DMG as a public production release.

## Rollback

Keep the previous notarized artifact and release notes until the new build has completed a clean-install smoke test. If permission, launch, or data-loss regressions appear, remove the new artifact and publish the known-good version.
