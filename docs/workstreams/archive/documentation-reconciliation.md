# Documentation reconciliation

- **Status:** Complete
- **Roadmap ID:** PEEK-AUD-05
- **Owner:** Codex
- **Scope:** Reconcile stale release, CI, version, and removed-feature claims in user-facing and maintainer documentation.
- **Owned files:** `README.md`, `docs/DEVELOPMENT.md`, `docs/PROJECT_STATUS.md`, `SECURITY.md`, `docs/workstreams/documentation-reconciliation.md`, `docs/{HANDOFF,ROADMAP}.md`.
- **Compatibility:** Documentation only. No app runtime, packaging, or PEEK-111 CLI/JSON v1 changes.
- **Plan:** Verify current project metadata and workflows, correct claims that conflict with current source/history, and leave unverified release assertions qualified.
- **Completed:** Replaced the stale 1.4.1 version, corrected the retired `macos-13` CI claim, removed current-tense import/export references, and documented PEEK-111's stdout-only sensitive-data boundary and real-release validation limits.
- **Files changed:** `README.md`, `docs/DEVELOPMENT.md`, `docs/PROJECT_STATUS.md`, `SECURITY.md`, roadmap, and handoff.
- **Validation:** Read-only consistency check against `Configuration/Version.xcconfig`, `.github/workflows/ci.yml`, `Peek/Resources/Info.plist`, `Peek/Resources/Peek.entitlements`, and source search on 2026-08-14.
- **Exact next action:** Keep current-state docs aligned with the next signed/notarized release evidence and PEEK-AUD-07 outcome.
