# Workstreams

Workstream files let multiple agents coordinate without repeatedly editing one shared handoff document.

## Workflow

1. Copy `TEMPLATE.md` to a short unique slug such as `notch-safe-compact-mode.md`.
2. Fill in owner, branch/worktree, status, scope, claimed files, dependencies, and next action.
3. Set `Status: Active` before implementation.
4. Update the file whenever scope or file ownership changes.
5. On completion, record validation and set `Status: Complete`. Keep completed files as durable context until the related release ships.

Allowed statuses: `Ready`, `Active`, `Blocked`, `In review`, `Complete`, `Abandoned`.

Two active workstreams must not claim the same files. If overlap becomes unavoidable, one agent pauses and leaves an explicit handoff before the other continues.
