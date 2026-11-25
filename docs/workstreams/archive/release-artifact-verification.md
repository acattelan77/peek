# Release artifact verification

- **Status:** Complete
- **Roadmap ID:** PEEK-AUD-04
- **Owner:** Codex
- **Scope:** Make the release script reject a release artifact that fails signature, entitlement, notarization-staple, Gatekeeper, or DMG integrity checks; document the exact evidence retained by CI.
- **Owned files:** `scripts/release.sh`, `docs/RELEASE.md`, `.github/workflows/release.yml` if required for evidence upload, `docs/workstreams/release-artifact-verification.md`, `CHANGELOG.md`, `Configuration/Version.xcconfig`, `docs/{HANDOFF,ROADMAP}.md`.
- **Compatibility:** Does not change app runtime behavior, the protected PEEK-111 CLI/JSON v1 contract, signing identity selection, or publishing authority.
- **Plan:** Inspect the existing release path, add fail-closed verification around the built app and final DMG, then syntax-check it. A real signed/notarized release remains out of scope and needs release credentials and tag authority.
- **Completed:** Added strict nested-signature, Developer ID/team, Hardened Runtime, calendar entitlement, and `get-task-allow` checks before packaging. The final DMG must pass `hdiutil verify`, `stapler validate`, Gatekeeper assessment, and mounted-content/signature checks. Verification metadata is intentionally kept outside the DMG staging folder.
- **Files changed:** `scripts/release.sh`, `docs/RELEASE.md`, version/changelog, roadmap, and handoff.
- **Validation:** `bash -n scripts/release.sh`, `bash scripts/check-version.sh`, and `git diff --check` passed on 2026-08-14.
- **Remaining risk:** No Developer ID certificate, Apple notarization credentials, or release-tag authority was used, so the signed/notarized path and a clean-account Gatekeeper assessment remain unverified.
- **Exact next action:** Run the signed/notarized script with release credentials, then complete PEEK-AUD-07 clean-account Gatekeeper validation.
