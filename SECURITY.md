# Security policy

## Supported version

Security fixes target the latest release on `main`.

## Reporting

Report vulnerabilities privately to the repository owner. Do not include real calendar content, meeting credentials, tokens, or signing material in an issue.

## Security model

- Calendar data is read locally through EventKit.
- Meeting links must use HTTPS and match the explicit trusted-domain allowlist.
- The app makes no network requests and includes no telemetry.
- The sandbox calendar entitlement is the only personal-information entitlement;
  notification authorization is requested through the system notification API.
- The optional headless calendar export is local-only and writes calendar content
  only to stdout. Treat its JSON as sensitive: do not log it, commit it, or send
  it to third parties without the calendar owner's authorization.
- Settings import/export is not a feature of the current app.

Public distribution must use Developer ID signing and Apple notarization. The
release script verifies strict signing, entitlements, stapling, Gatekeeper, and
DMG integrity, but a real signed/notarized release still needs credentials and
clean-account validation. Local ad-hoc builds are not production artifacts.
