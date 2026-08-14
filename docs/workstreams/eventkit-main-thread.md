# Workstream: EventKit main-thread refresh delivery

- Roadmap ID: PEEK-AUD-01
- Status: Complete
- Owner: Codex
- Branch/worktree: `codex/eventkit-main-thread` in `~/Dev/peek`
- Last updated: 2026-08-14

## Objective

Ensure an EventKit store-change notification cannot enter Peek's observable/UI refresh path from a background thread.

## Scope

- Deliver `.EKEventStoreChanged` observation on the main operation queue.
- Add a focused regression test that posts the notification from a background queue.
- Record the full audit follow-up plan in the roadmap.
- Bump the patch version, update the changelog and integrated handoff, and run required validation.

## Out of scope

- Any change to the PEEK-111 CLI, JSON v1 schema, selection semantics, stdout/stderr behavior, or external Northwind Notes consumer.
- Notification scheduling, Reduce Motion behavior, release workflow hardening, documentation reconciliation outside this workstream's required handoff, and HUD retention remediation.
- Installation, signing, notarization, commit, push, or release.

## Claimed files and subsystems

- `Peek/Sources/Application/Calendar/CalendarManager.swift`
- `PeekTests/CalendarManagerIntegrationTests.swift`
- `docs/ROADMAP.md`
- `docs/workstreams/eventkit-main-thread.md`
- `Configuration/Version.xcconfig`
- `CHANGELOG.md`
- `docs/HANDOFF.md`

## Dependencies

- EventKit's change notification may be delivered from a background thread.
- PEEK-111 remains a protected compatibility boundary and is not modified.

## Progress

- [x] Record the wider audit remediation plan in the roadmap.
- [x] Claim the EventKit thread-confinement workstream.
- [x] Constrain the EventKit change observer to main-queue delivery.
- [x] Add background-post regression coverage.
- [x] Bump Peek to 1.5.1 (30) and update release-facing handoff documentation.
- [x] Run required automated validation.
- [x] Attempt the relevant physical macOS smoke check and record the limitation.

## Validation

- Focused unsigned test: `xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:PeekTests/CalendarManagerIntegrationTests test` — passed: 13 tests, zero failures.
- `bash scripts/check-version.sh` — passed: 1.5.1 (30).
- `git diff --check` — passed.
- Plist and localization lint — passed.
- Unsigned Debug build — passed.
- Required unsigned macOS test suite — passed: 90 tests, zero failures.
- Physical UI attempt: the Computer Use controller timed out while inspecting both `~/Dev/peek/build/Build/Products/Debug/Peek.app` and the installed accessory app. No permissions, preferences, installed app, or external integration were changed. This does not establish real EventKit-change repaint behavior.

## Decisions and open questions

- `OperationQueue.main` is the narrowest fix: it confines the existing handler before it reaches `AppDelegate.scheduleRefresh`, without changing EventKit queries, preferences, notifications, or export behavior.
- The automated test proves the scheduling boundary, not real EventKit delivery or menu-bar repaint behavior. That physical check remains tracked under PEEK-AUD-07.

## Exact next action

Claim PEEK-AUD-02 (Reduce Motion) or perform PEEK-AUD-07 physical validation when suitable hardware and an inspectable menu-bar UI path are available.
