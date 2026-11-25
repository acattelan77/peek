# Security policy

## Supported version

Security fixes target the latest version on `main`.

## Reporting

Report vulnerabilities privately to the repository owner, not in a public
issue. Do not include real calendar content, meeting credentials, API keys
or signing material.

## Security and privacy model

* **Calendar data stays local.** Events are read through EventKit with the
  user's Full Access grant. Peek has no account, backend, analytics or
  telemetry.
* **One optional network connection.** When the user picks "Claude" as the
  brief engine and accepts the consent screen, Peek sends the fields listed
  there for one meeting to `https://api.anthropic.com` with the user's own API
  key. The key is kept in the keychain. Briefs are off by default; the on-device
  engine (Apple Foundation Models) sends nothing. See ADR 0005.
* **Optional Contacts.** Contacts access is requested only when the user turns
  on "Show who you're meeting", and lookups stay on the Mac.
* **Read-only context folder.** Peek reads `peek-context.json` from a folder the
  user picks, through a read-only, app-scoped security bookmark, and never
  writes there. Context links are limited to an allowlist (`https`, `obsidian`)
  and opened only on click (ADR 0004).
* **Meeting links.** Join links must use HTTPS and match the trusted provider
  patterns, with length limits on the input text.
* **Diagnostics.** Logs, the local journal and the diagnostics export carry
  counts, outcomes and opaque references, never titles, notes, attendees,
  locations, links or paths. Nothing is uploaded (ADR 0006).
* **Calendar export.** The headless `--export` command writes calendar content
  only to stdout. Treat its JSON as personal data.
* **Sandbox.** The app is sandboxed. Entitlements: calendars, address book,
  outgoing network (Claude brief only), user-selected read-only files and
  app-scoped bookmarks. The privacy manifest is
  `Peek/Resources/PrivacyInfo.xcprivacy`.

## Distribution

Public builds are Developer ID signed and notarized (DMG) or distributed through
the Mac App Store. `scripts/release.sh` fails closed unless strict signing,
entitlements, stapling, Gatekeeper and DMG checks pass. Ad-hoc builds, including
the test installer, are not production artifacts.
