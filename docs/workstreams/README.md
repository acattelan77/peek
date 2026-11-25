# Workstreams

A workstream file says who is working on what, on which branch, and which files
they own, so several agents can work in parallel without colliding. The roadmap
says what matters; a workstream says who holds it right now.

## Layout

* `docs/workstreams/<slug>.md`: open work. Read every one before you start.
* `docs/workstreams/archive/`: frozen records of merged or abandoned work, kept
  for their reasoning. Do not edit them, and do not treat their status lines or
  next actions as current: `docs/ROADMAP.md` and `docs/MAC_CHECKS.md` are.
* `TEMPLATE.md`: copy it to start a workstream.

## Lifecycle

1. Copy `TEMPLATE.md` to a short unique slug, fill in the roadmap ID, owner,
   branch, scope and claimed files, and set `Status: Active`.
2. Keep the file current when scope or file ownership changes.
3. When the pull request is ready, record validation (with the CI run URL) and
   the exact next action, set `Status: In review`, and add the owner's physical
   checks to `docs/MAC_CHECKS.md`.
4. When the pull request merges, set `Status: Complete` and move the file to
   `archive/` in the same or the next change. An abandoned workstream is set to
   `Abandoned` and archived the same way.

Allowed statuses: `Active`, `Blocked`, `In review`, `Complete`, `Abandoned`.
`Blocked` names what and whom it waits on.

Two active workstreams must not claim the same files. If an overlap is
unavoidable, one agent pauses and leaves an explicit handoff in its file before
the other continues.
