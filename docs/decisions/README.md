# Architecture decision records

Each record states a decision, its context and its consequences. Records are
history: an accepted decision is not rewritten. A change of direction gets a
new record, and the old one's status becomes `Superseded by ADR NNNN`.
Clarifications that do not change the decision are added as dated amendments.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-layered-monolith.md) | Layered monolith: App, Application, Domain, Infrastructure, Presentation | Accepted |
| [0002](0002-platform-service-boundaries.md) | Stateful macOS services behind protocols | Accepted |
| [0003](0003-calendar-export-cli.md) | Headless calendar export, JSON schema v1 | Accepted |
| [0004](0004-meeting-context-file.md) | Read-only meeting-context file in a user-chosen folder | Accepted, amended 2026-11-24 and 2026-11-25 |
| [0005](0005-meeting-brief-data-and-consent.md) | Meeting brief engines, data sent and consent | Accepted |
| [0006](0006-local-diagnostics.md) | Local diagnostics without meeting content | Accepted |

New records take the next number and start from this outline: title, status,
date, roadmap IDs, Context, Decision, Consequences.
