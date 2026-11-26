# Workstream: reminder scheduling without false failures

- Roadmap ID: PEEK-286
- Status: Complete
- Owner: Claude Code
- Branch/worktree: `claude/project-thread-4mi65g`
- Last updated: 2026-11-26

## Objective

No false "Some reminders could not be scheduled" after launch, and a real
failure says why in the log.

## Scope

- `CoalescingSerialQueue` (Application) runs one scheduling pass at a time and
  coalesces a burst into one follow-up; `AppDelegate.rescheduleNotifications`
  submits to it and ignores the result of a pass that a newer one supersedes.
- `NotificationManager` records `notificationsFailed` with reason (`add` or
  `missing`), count, and the first error's domain and code.

## Out of scope

- The direct `clearAllPendingNotifications` calls when notifications are off.

## Claimed files and subsystems

- `Peek/Sources/Application/CoalescingSerialQueue.swift`,
  `PeekTests/CoalescingSerialQueueTests.swift`
- `Peek/Sources/Infrastructure/Notifications/NotificationManager.swift`
- `Peek/Sources/Domain/Diagnostics/DiagnosticEvent.swift`, `PeekTests/DiagnosticsTests.swift`
- `Peek/Sources/App/PeekApp.swift` (`rescheduleNotifications` only)

## Validation

- Linux checks; build and tests in CI (see the pull request).

## Decisions and open questions

- Cause inferred from code: several forced reschedules start at launch, and
  each pass first removes all pending event reminders. Not reproduced on a Mac.

## Exact next action

Owner checks in `docs/MAC_CHECKS.md` under PEEK-286.
