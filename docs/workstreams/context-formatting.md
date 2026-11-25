# Workstream: context formatting on the meeting page

- Roadmap ID: PEEK-276
- Status: In review
- Owner: Claude Code (cloud session)
- Branch/worktree: `claude/project-thread-286nmm`
- Last updated: 2026-11-25

## Objective

The meeting page reads cleanly with the context file Northwind Notes writes: no
lower-case fragment as the title, no Context paragraph that looks cut off, no
bullets shown twice.

## Diagnosis (2026-11-25, Jane Doe 10:45)

The file is valid and nothing is truncated. `the writer script` (notes vault,
read only) maps the day log's labelled fields as follows:

- `Proposed goal:` → `headline` ("uscire con il dato per Marco…"). Peek
  used any file headline as the page title.
- `Ultima volta:` (absent here) + `Aperto con loro:` → `summary` ("report di una
  pagina sull’EPT…"). The value after the label starts in lower case, so with
  the label gone it read as the tail of a sentence.
- Unticked `To prepare` boxes → `bullets`. Peek showed them in the "What to
  prepare" card (a context-folder brief is built from them) and again under
  Context.

## Scope

- Page title stays the event title when the headline came from the file; the
  file headline opens the Context section.
- Prose fields from the file start with a capital letter (decoder).
- Context omits bullets already in the brief card.
- Owner feedback 2026-11-25: on the "Starting now" card the Join button label
  wrapped to two lines. Card buttons now never wrap; if they do not fit on one
  row, Join keeps the first row and Snooze/Ignore move below
  (`Peek/Sources/Presentation/HUD/StartingNowHUD.swift`).

## Out of scope

- The 42 script. Never written from this repo.
- The 2-minute card still shows the file headline as its context line.

## Claimed files and subsystems

- `Peek/Sources/Domain/Context/MeetingContextFile.swift`
- `Peek/Sources/Domain/Context/MeetingContext.swift`
- `MeetingPage` summary and Context section in `Peek/Sources/Presentation/MenuBar/MenuBarView.swift`
- `PeekTests/MeetingContextTests.swift` (`ContextFileFormattingTests`)

## Progress

- [x] Diagnosis against the live day log on the main Mac
- [x] Fix and tests
- [x] CI green after the card button fix (d6f841b, https://github.com/acattelan77/peek/actions/runs/45588658477)
- [ ] Owner checks on the Mac

## Validation

- Linux: `bash scripts/check-version.sh`, `git diff --check`.
- Build and tests ran in CI (`build-and-test`, macos-latest), not locally:
  green on 96a643a, https://github.com/acattelan77/peek/actions/runs/45587195215.

## Owner checks on the Mac

1. Open the Jane-style meeting with a context-file headline: the title is the
   event title, Context starts with the goal sentence in bold, capitalized.
2. The Context paragraph starts with a capital letter.
3. Bullets under "What to prepare" do not appear again under Context.
4. A meeting without a file headline still shows "You're about to meet…" as
   the title.
5. The full-screen start alert for the Jane-style meeting shows the event
   title as its headline.
6. On the 2-minute and "Starting now" cards, "Join Google Meet" stays on one
   line.

## Decisions and open questions

- 2026-11-25, owner: the full-screen start alert also shows the event title
  instead of the goal sentence (done in this PR).

## Exact next action

Wait for CI on the PR, then the owner's Mac checks and merge word.
