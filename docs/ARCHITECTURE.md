# Architecture

## Goals

Peek is a small native macOS application. Its architecture should stay understandable to one contributor while keeping EventKit, UserNotifications, UserDefaults, Carbon, and AppKit at replaceable boundaries.

The codebase is a layered monolith: one application target, one unit-test target, and explicit dependency direction.

## Layers

```text
App (composition and lifecycle)
  ├── Application (observable state and use-case coordination)
  ├── Presentation (SwiftUI/AppKit views and formatting)
  ├── Domain (event selection, urgency, links, preference models)
  └── Infrastructure (EventKit, notifications, preferences)
```

Dependencies point inward:

- `Domain` imports Foundation and framework types only where the platform is the domain source, such as `EKEvent` link extraction.
- `Application` coordinates domain policies through protocols.
- `Infrastructure` implements protocols for macOS services.
- `Presentation` reads observable application state and delegates decisions to pure builders.
- `App` is the composition root. It is the only place that chooses live implementations.

## Source map

```text
Peek/Sources/
├── App/                    # NSApplication lifecycle and composition entry
├── Application/
│   ├── Calendar/           # CalendarManager and app-facing calendar state
│   └── CalendarExport/     # Headless CLI orchestration and argument parsing
├── Domain/
│   ├── Events/             # Filtering, ordering, urgency
│   ├── CalendarExport/     # Versioned export payload and serialization policy
│   ├── Meetings/           # Trusted meeting-link extraction
│   └── Models/             # Preferences and constraints
├── Infrastructure/
│   ├── Calendar/           # EventKit adapter and conformances
│   ├── Notifications/      # UserNotifications scheduler
│   └── Preferences/        # UserDefaults boundary
└── Presentation/
    ├── Formatting/         # User-facing date/time formatting
    ├── MenuBar/            # Popover and event rows
    ├── Preferences/        # Settings UI
    └── StatusBar/          # Pure status-bar content builder
```

## Runtime flow

1. `AppDelegate` creates `AppEnvironment.live()`.
2. `CalendarManager` requests authorization and queries `CalendarEventStoring` on its serial queue.
3. `EventPipeline` filters, orders, and limits events.
4. Published state updates the SwiftUI popover.
5. `StatusBarContentBuilder` produces display content; `AppDelegate` applies AppKit styling.
6. `NotificationScheduling` refreshes reminders when the event signature changes.

### Headless calendar-export flow

`Peek --export --from <signed-days> --to <signed-days> --json` is a separate,
non-UI runtime path. `PeekApp` recognizes it before creating the app delegate;
`CalendarExportCommand` validates the request and existing Full Access, reads
through `CalendarEventStoring`, builds the versioned payload, writes JSON only
to stdout, then exits. Failures write a readable diagnostic only to stderr,
exit non-zero, and never emit partial JSON.

The installed app is consumed by an external, user-local Northwind Notes
`launchd` job. That job pipes this command to a renderer that atomically owns
the Northwind Notes cache files. Its scheduling, renderer, and vault writes are not
part of this repository and must not be moved into Peek.

## Boundaries and testing

- `CalendarEventStoring` isolates EventKit queries and enables a future fake event store.
- `PreferencesStoring` isolates persistence and enables deterministic preference tests.
- `NotificationScheduling` isolates authorization and scheduling from lifecycle code.
- `LaunchAtLoginControlling` isolates ServiceManagement.
- `CalendarExportCommand` is a synchronous, headless use-case boundary. It
  deliberately does not depend on observable `CalendarManager`, which owns UI
  state and permission prompting.
- `EventPipeline`, `MeetingURLDetector`, `MeetingUrgency`, `EventTimeFormatter`, and `StatusBarContentBuilder` are pure or near-pure test seams.

## Calendar-export compatibility contract

PEEK-111 is a maintained integration, not a one-off script. Before changing
its CLI arguments, date-window semantics, persisted-calendar selection,
authorization behavior, link classification, JSON field meanings, stdout or
stderr behavior, an agent must assess the external Northwind Notes renderer and
scheduled job that consume the installed app.

- Keep `schemaVersion: 1` backward compatible. A breaking payload change
  requires a new schema version, consumer migration plan, tests, and an ADR
  update rather than silently changing v1.
- Preserve the privacy boundary: no Northwind Notes paths, scheduling, cache writes,
  calendar content logging, or permission prompts in the headless command.
- Cover export behavior with unit tests and update the README, ADR 0003, and
  handoff whenever the public contract changes. A release-affecting change
  follows the normal versioning and signed-build validation process.

## Conventions

- Put decisions in domain or application types, not SwiftUI view bodies.
- Keep macOS side effects behind protocols when they need unit testing.
- Prefer immutable value types for formatted output and configuration.
- Dispatch published state changes to the main queue.
- Add a decision record under `docs/decisions/` for cross-layer or persistence changes.

## Known architectural debt

- `CalendarManager` still combines authorization, fetching, persistence orchestration, and observable state. Split it into a calendar repository plus `CalendarViewModel` when quick event creation or multi-account behavior is introduced.
- `AppDelegate` still owns status-item animation, global hotkey registration, and notification coordination. These should become focused coordinators before adding more lifecycle features.
- EventKit integration has no fake-store integration test yet.
