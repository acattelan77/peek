# Workstream: Test preference cleanup and persistent launch log

- Roadmap ID: PEEK-284
- Status: Active (pull request open, waiting for the owner's review)
- Owner: Claude Code
- Branch/worktree: `claude/test-defaults-and-logging`
- Last updated: 2026-11-26

## Objective

Test runs leave no `com.peek.app.tests.*` plists, and `log show` after the fact
finds at least Peek's launch line.

## Scope

- `PeekTests/Fakes/TestDefaults.swift` and every test that creates a suite.
- Launch event level in `DiagnosticEvent`, comment in `DiagnosticsLog`.

## Out of scope

- Changing other event levels or the journal.

## Claimed files and subsystems

- `PeekTests/` suite setup and teardown, `PeekTests/Fakes/TestDefaults.swift`
- `Peek/Sources/Domain/Diagnostics/DiagnosticEvent.swift`
- `Peek/Sources/Infrastructure/Diagnostics/DiagnosticsLog.swift`

## Dependencies

- Independent of PEEK-283 (PR 4); both bump from 1.16.2, so whichever merges
  second rebases and bumps again.

## Progress

- [x] Tests: `UserDefaults().removeSuite(named:)` never deletes a suite's plist;
      `TestDefaults.remove` empties the domain and deletes the file.
- [x] Logging: on the owner's Mac, `log show --info --last 3h` held no
      `com.peek.app` lines, nor did 25 s of `log stream --level info` while
      idle. Every routine event, including the launch, is info level, which
      macOS keeps only in memory, so nothing persists. The subsystem string is
      right (bundle id `com.peek.app`). The launch line is now notice. This is
      inferred; the journal in the sandbox container could not be read to
      confirm events were recorded.
- [ ] CI green; owner runs the PEEK-284 checks.

## Validation

- Linux: the four check scripts, `git diff --check`. Build and tests: CI.

## Decisions and open questions

- Raising every routine event to notice would make `log show` complete but
  persist far more lines; not done.

## Exact next action

After PR 4 merges: rebase on `main`, take its Version.xcconfig, rerun
`bash scripts/bump-version.sh patch`, move the changelog entry.
