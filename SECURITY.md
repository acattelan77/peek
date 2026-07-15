# Security policy

## Supported version

Security fixes target the latest release on `main`.

## Reporting

Report vulnerabilities privately to the repository owner. Do not include real calendar content, meeting credentials, tokens, or signing material in an issue.

## Security model

- Calendar data is read locally through EventKit.
- Meeting links must use HTTPS and match the explicit trusted-domain allowlist.
- The app makes no network requests and includes no telemetry.
- The sandbox calendar entitlement is the only personal-information entitlement.
- Imported settings are treated as untrusted input and constrained to supported values.

Public distribution must use Developer ID signing and Apple notarization. Local ad-hoc builds are not production artifacts.
