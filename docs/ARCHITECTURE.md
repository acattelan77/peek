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
├── Application/            # AppEnvironment, CalendarManager, app policies
├── Domain/
│   ├── Events/             # Filtering, ordering, urgency
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

## Boundaries and testing

- `CalendarEventStoring` isolates EventKit queries and enables a future fake event store.
- `PreferencesStoring` isolates persistence and enables deterministic preference tests.
- `NotificationScheduling` isolates authorization and scheduling from lifecycle code.
- `LaunchAtLoginControlling` isolates ServiceManagement.
- `EventPipeline`, `MeetingURLDetector`, `MeetingUrgency`, `EventTimeFormatter`, and `StatusBarContentBuilder` are pure or near-pure test seams.

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
