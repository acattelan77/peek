# Workstream: Menu-bar click opens the popover

- Roadmap ID: PEEK-283
- Status: Done (merged in PR 4; Mac checks pending in `docs/MAC_CHECKS.md`)
- Owner: Claude Code
- Branch/worktree: `claude/project-thread-mqoead`
- Last updated: 2026-11-26

## Objective

In 1.16.2 a click on the menu-bar icon or label does not open the popover; the
keyboard shortcut does. Make the click open it again without bringing back the
PEEK-282 jump.

## Scope

- Remove the status-item width lock PR 2 added on presentation.
- Keep the fixed anchor (`PopoverPresentationPolicy.anchorFrame`).
- Regression test, version bump, changelog, roadmap, Mac checks.

## Out of scope

- Any other popover or anchor change.

## Claimed files and subsystems

- `Peek/Sources/App/PeekApp.swift`
- `Peek/Sources/App/PopoverAnchorGeometry.swift`
- `PeekTests/StatusBarSpacePolicyTests.swift`

## Dependencies

- None.

## Progress

- [x] Root cause: since PR 2, `togglePopover` set `statusItem.length` to the
      button's width inside the click action. It is the only click-specific
      change in 1.16.2; the shortcut runs the same code but no click is in
      flight. The owner's Mac runs macOS 27.0.1, where status items are hosted
      by the system menu bar as scenes (Peek logs ~700 FrontBoard SceneClient
      lines an hour), so a resize during the click reconfigures the hosted item
      and the click is lost. This is inferred from code and logs; nobody has
      reproduced it with a debugger.
- [x] Fix: never change `statusItem.length` on presentation. The anchor window
      already keeps an open popover still, so the lock was redundant.
- [x] CI green: https://github.com/acattelan77/peek/actions/runs/45896047207
- [ ] Owner verifies with the test installer (`docs/MAC_CHECKS.md`).

## Validation

- Linux: the four check scripts, `git diff --check`.
- Build and tests: CI, https://github.com/acattelan77/peek/actions/runs/45896047207 (not run locally).

## Decisions and open questions

- Removing the lock also resolves the PEEK-282 owner decision about a clipped
  label while the popover is open.

## Exact next action

Owner installs the `Peek-test-installer` artifact from this branch's CI run and
clicks the icon and the label on both displays (`docs/MAC_CHECKS.md`, PEEK-283).
