# ADR 0006: Local diagnostics without meeting content

- Status: Accepted
- Date: 2026-11-24
- Roadmap: PEEK-275

## Context

Before 1.13.1 Peek had a handful of `print` calls and no structured log, so a
missed or late alert left no trace. The pre-release robustness work
(PEEK-271..274) needs evidence on the owner's Mac. Peek's roadmap promises no
telemetry, and meeting data is personal.

## Decision

1. Every diagnostic line comes from a typed `DiagnosticEvent`
   (`Domain/Diagnostics`). Its cases carry only counts, durations, fixed
   reasons, result names, error codes, versions and an opaque event reference
   (the first 4 bytes of a SHA-256 of the EventKit identifier). No case takes
   free text from an event, a calendar, the context file, a brief or a path.
   Tests assert that no message and no export contains event content.
2. Because messages hold no content, they are logged as `.public` through one
   `os.Logger` per category under the bundle identifier subsystem
   (`com.peek.app`), so `log stream` shows them.
3. The same lines go to `Application Support/Peek/Diagnostics/journal.jsonl`,
   kept for 14 days and at most 2,000 lines. Repeated decisions made on every
   status-bar tick are throttled per key.
4. `MXMetricManager` payloads (metrics, crashes, hangs, energy) are saved as
   JSON in `Diagnostics/MetricKit/` and deleted after 30 days.
5. "Export diagnostics" writes one JSON file (format version 1) into
   `Diagnostics/Exports/` inside Peek's container and reveals it in the Finder.
   Settings appear only as switches, counts and enum names; keywords, calendar
   names, folder paths and keys are left out. The sandbox keeps
   `files.user-selected.read-only`, so there is no save panel and no new
   entitlement. Nothing is sent over the network; the privacy manifest is
   unchanged.
6. The Application layer calls the `Diagnostics` facade directly, as it already
   does `ContextFolderStore`; a protocol seam can come later if tests need to
   observe log calls.

## Consequences

- A missed alert can be explained from the journal: refresh, reschedule,
  shown or skipped with the reason.
- A new log point means a new `DiagnosticEvent` case, which keeps the privacy
  rule reviewable in one file.
- The time zone identifier and locale are in the export, because the time
  robustness work (PEEK-271) needs them.
