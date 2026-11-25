# Workstream: Event detail expansion

- Roadmap ID: PEEK-110
- Status: Complete
- Owner: Kimi
- Branch/worktree: `codex/event-detail-expansion`
- Last updated: 2026-08-12

## Objective

Tapping an event in the popover expands it in place to show its notes,
attendees (with response status and organizer), and conference provider
identity. Attachments were dropped: macOS EventKit does not expose
`EKAttachment` (it is iOS-only).

## Scope

- Accordion expansion state in `MenuBarView` (one event expanded at a time),
  including keyboard (Return on the selected row) and VoiceOver support.
- Expanded detail section rendered with existing design-system components.
- A testable `EventDetail` model in the Domain layer; `EKEvent` mapping stays
  thin because EventKit attendees are read-only and cannot be populated by
  the fake store.
- Move `MeetingProvider` from `MenuBarView.swift` into `Domain/Meetings` so
  the row label and the detail section share provider identity.
- Regression tests for the pure detail-model logic, version bump (minor),
  CHANGELOG/ROADMAP/HANDOFF updates.

## Out of scope

- Editing or creating events; attendee actions (email, decline).
- Rendering notes as rich text or stripping conference bridges from notes.
- Changes to popover width, anchoring, or the status-item space policy.
- Snapshot/view-inspection testing infrastructure.

## Claimed files and subsystems

- `Peek/Sources/Presentation/MenuBar/MenuBarView.swift`
- `Peek/Sources/Domain/Events/EventDetail.swift` (new)
- `Peek/Sources/Domain/Meetings/MeetingProvider.swift` (new, moved)
- `Peek/Sources/App/PeekApp.swift` (provider-label call site only)
- `Peek/Resources/en.lproj/Localizable.strings`
- `PeekTests/EventDetailTests.swift` (new)
- `Peek.xcodeproj/project.pbxproj` (file references for new sources)
- `CHANGELOG.md`, `Configuration/Version.xcconfig`, `docs/HANDOFF.md`,
  `docs/ROADMAP.md`, `docs/workstreams/event-detail-expansion.md`

## Dependencies

- Builds on `MeetingURLDetector` (trusted-domain extraction) and the
  design-system token/component layer.

## Progress

- [x] Explore popover UI, event flow, and test seams.
- [x] Create workstream file and branch.
- [x] Implement `EventDetail` model + move `MeetingProvider`.
- [x] Implement expansion UI and keyboard/accessibility behavior.
- [x] Add tests, bump version (1.4.0), update release docs.
- [x] Run required validation.
- [x] Restyle rows as bordered cards after physical QA found expanded and
  collapsed events visually blurred together; hero keeps urgency color coding.
- [x] Physical QA of expansion interactions on a running build.
- [x] Merge to `main` and update HANDOFF/ROADMAP to Done.

## Validation

- `bash scripts/check-version.sh` passed for 1.4.0 (26).
- Required unsigned Debug build succeeded on 2026-08-12, re-run after the card
  restyle.
- Required macOS test run passed on 2026-08-12: 80 tests, zero failures,
  re-run after the card restyle.
- `plutil -lint` passed on `en.lproj/Localizable.strings`.
- Physical QA passed on 2026-08-12 (expansion interactions and card styling).

## Decisions and open questions

- EventKit exposes attendees as read-only, so `EventDetail` is a plain struct
  built by pure, testable functions; the `EKEvent` mapping is a thin
  composition-root-style shim.
- Attachments are not implementable: the macOS EventKit SDK has no
  `EKAttachment`/`EKCalendarItem.attachments` (verified against the macOS
  swiftinterface; it is iOS-only). Documented in ROADMAP and CHANGELOG.
- One event expanded at a time keeps popover height changes bounded.
- Expansion state clears automatically when the expanded event disappears
  from a refresh.

## Exact next action

None — merged to `main` and marked Done in ROADMAP and HANDOFF.
