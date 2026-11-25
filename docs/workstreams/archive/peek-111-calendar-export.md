# Workstream: PEEK-111 calendar export

- Roadmap ID: PEEK-111
- Status: Complete
- Owner: Codex
- Branch/worktree: `codex/peek-111-calendar-export` in `~/Dev/peek`
- Last updated: 2026-08-13

## Objective

Provide a permission-safe, headless `Peek --export --from <days> --to <days> --json` command that emits the versioned local-calendar JSON contract on stdout.

## Scope

- CLI argument parsing, date-window calculation, EventKit export boundary, value payload mapping, and stable JSON serialization.
- Reuse the existing calendar-selection preferences and event-detail/meeting-link decisions.
- Unit tests, ADR, README, changelog, roadmap, handoff, and versioning documentation required for the capability.

## Out of scope

- Northwind Notes vault writes, renderer implementation, `launchd`, export preferences UI, or menu-bar behavior changes.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/Application/CalendarExport/`
- `Peek/Sources/Domain/CalendarExport/`
- `Peek/Sources/Infrastructure/Calendar/CalendarEventStore.swift`
- `PeekTests/CalendarExportTests.swift`
- `docs/decisions/0003-calendar-export-cli.md`
- `docs/{ARCHITECTURE,ROADMAP,HANDOFF}.md`, `README.md`, `CHANGELOG.md`, `Configuration/Version.xcconfig`

## Dependencies

- Existing `CalendarEventStoring`, `PreferencesStoring`, `EventDetailBuilder`, and `MeetingURLDetector` seams.

## Progress

- [x] Claimed the PEEK-111 workstream and recorded roadmap ownership.
- [x] Implemented headless export and unit coverage.
- [x] Completed required validation and handoff updates.
- [x] Recorded the deployed Northwind Notes integration and the ongoing CLI maintenance contract in the required architecture and handoff documents.

## Validation

- `bash scripts/check-version.sh` — passed.
- `git diff --check` — passed.
- Unsigned Debug build — passed.
- Unsigned macOS test suite — passed: 89 tests, zero failures.
- Debug binary `--help` and malformed `--export` arguments — passed with the expected exit codes and stdout/stderr separation.

## Decisions and open questions

- The CLI checks authorization without requesting it, so it never presents a permission prompt or emits partial JSON.
- The signed installed app completed the Northwind Notes LaunchAgent's first real export with existing Full Access; the job exited 0 and the external renderer created both private cache files. Cache content was not inspected or logged during verification.
- `schemaVersion: 1` is a maintained compatibility contract. Breaking changes require a new schema version and a migration coordinated with the external Northwind Notes renderer and LaunchAgent.

## Exact next action

Commit this cohesive PEEK-111 workstream when authorized. Future changes to the headless CLI must first follow the compatibility contract in `docs/ARCHITECTURE.md` and ADR 0003.
