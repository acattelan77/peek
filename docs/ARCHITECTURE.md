# Architecture

## Goals

Peek is a small native macOS application. Its architecture should stay
understandable to one contributor while keeping EventKit, UserNotifications,
Contacts, UserDefaults, the file system, the network, Carbon and AppKit behind
replaceable boundaries.

The codebase is a layered monolith (ADR 0001): one app target, one test target,
no third-party dependencies, and an explicit dependency direction.

## Layers

```text
App (composition and lifecycle)
  ├── Application (observable state and use-case coordination)
  ├── Presentation (SwiftUI/AppKit views, design system, formatting)
  ├── Domain (pure policies: events, urgency, links, context, briefs, preferences)
  └── Infrastructure (EventKit, notifications, Contacts, files, network, logging)
```

Dependencies point inward:

* `Domain` uses Foundation only, plus EventKit types where the platform is the
  source of the data.
* `Application` coordinates domain policies through protocols.
* `Infrastructure` implements those protocols with macOS services.
* `Presentation` reads observable state and delegates decisions to pure builders.
* `App` is the composition root. `AppEnvironment.live()` is the only place that
  picks live implementations.

## Source map

```text
Peek/Sources/
├── App/                     AppDelegate and SwiftUI entry (PeekApp.swift), hotkey
│                            registrar, popover anchoring, Starting now and
│                            full-screen alert window controllers
├── Application/
│   ├── Calendar/            CalendarManager: authorization, refresh, published state
│   ├── CalendarExport/      Headless --export command (PEEK-111)
│   ├── Brief/               Brief engine protocol and MeetingBriefService (PEEK-221..224)
│   ├── Diagnostics/         Diagnostics export report (PEEK-275)
│   └── *.swift              AppEnvironment, alert timing, discreet mode, meeting
│                            context provider, status-bar space policy, behavior seams
├── Domain/
│   ├── Events/              Pipeline (filter, order, dedupe, limit), urgency,
│   │                        overrides (mute/hide), month grid, event detail
│   ├── Meetings/            Trusted join-link detection, providers, join target
│   ├── Context/             Meeting context, context-file format, link allowlist,
│   │                        invitation-text cleaner
│   ├── Brief/               Brief model and input fields
│   ├── CalendarExport/      Versioned export payload (schema v1)
│   ├── Diagnostics/         Content-free diagnostic events and retention
│   ├── TimeZones/           World clocks
│   └── Models/              AppPreferences and constraints
├── Infrastructure/
│   ├── Calendar/            EventKit store adapter
│   ├── Notifications/       UserNotifications scheduler
│   ├── Context/             Context-folder bookmark and reader, Contacts lookup
│   ├── Brief/               On-device (FoundationModels) and Claude engines, cache
│   ├── Diagnostics/         os.Logger, journal, MetricKit, exporter
│   ├── Time/                Wake, time-zone, clock and day-change observer
│   └── Preferences/         UserDefaults store
└── Presentation/
    ├── DesignSystem/        PeekTheme (tokens) and PeekComponents
    ├── MenuBar/             Popover, month calendar, meeting page
    ├── HUD/                 Starting now card and full-screen start alert
    ├── Preferences/         Settings window (Alerts, Briefs, Calendars, General)
    ├── Onboarding/          First-run flow
    ├── StatusBar/           Pure menu-bar content builder
    └── Formatting/          Date and time formatting
```

## Runtime flow

1. `AppDelegate` creates `AppEnvironment.live()` and the status item.
2. `CalendarManager` requests authorization and queries `CalendarEventStoring`.
   It refreshes on EventKit changes (delivered on the main queue), on a timer
   that speeds up near a meeting, and on `SystemTimeObserving` signals (wake,
   time zone, clock, day change).
3. `EventPipeline` filters, dedupes across calendars, applies per-event
   overrides, orders and limits events.
4. `MeetingContextProvider` builds each meeting's context from attendees,
   Contacts (opt-in) and the context file; `MeetingBriefService` prepares a brief
   15 minutes before when briefs are on.
5. Published state updates the SwiftUI popover; `StatusBarContentBuilder`
   produces the menu-bar content and `AppDelegate` applies AppKit styling.
6. `NotificationScheduling` keeps up to 60 lead-time notifications pinned to
   absolute instants. `AlertTiming` holds the start-alert timing rules (including
   late starts after a wake), and `AppDelegate` decides when the 2-minute card
   and the start alert show; the App-layer controllers present them.
7. `DiscreetMode` hides personal content while sharing or mirroring the screen.

### Headless calendar export

`Peek --export --from <signed-days> --to <signed-days> --json` is a separate,
non-UI path. `PeekApp` recognizes it before creating the app delegate;
`CalendarExportCommand` validates the request and existing Full Access, reads
through `CalendarEventStoring`, builds the payload, writes JSON only to stdout
and exits. Failures write a readable message to stderr, exit non-zero and never
emit partial JSON. It deliberately does not use `CalendarManager`, which owns UI
state and permission prompts.

## Boundaries and seams

| Protocol | Isolates | Fake in tests |
| --- | --- | --- |
| `CalendarEventStoring` | EventKit queries and change notifications | `FakeCalendarEventStore` |
| `NotificationScheduling` | UserNotifications authorization and requests | `FakeNotificationScheduler` |
| `LaunchAtLoginControlling` | ServiceManagement | `FakeLaunchAtLoginController` |
| `PreferencesStoring` | UserDefaults | isolated `UserDefaults` suites |
| `HotkeyRegistering` | Carbon hotkeys | test doubles |
| `SystemTimeObserving` | Wake, time-zone, clock and day notifications | none yet: timing rules are tested through `AlertTiming` |
| `ContactLookup` | Contacts | test doubles |
| `BriefEngine` | On-device and Claude brief generation | fixture engines |
| `ScreenShareSignalReading` | Display mirroring | test doubles |

`EventPipeline`, `MeetingURLDetector`, `MeetingUrgency`, `MeetingContextBuilder`,
`ContextLinkPolicy`, `EventTimeFormatter` and `StatusBarContentBuilder` are pure
or near-pure and tested directly.

## External contracts

Two interfaces are used by tools outside this repository. Peek knows nothing
about those tools: no paths, schedules or formats of theirs belong in this
repository.

### Calendar export (PEEK-111, ADR 0003)

Consumers run the installed app's `--export` command on a schedule. Before
changing its arguments, date-window semantics, calendar selection,
authorization behavior, link classification, field meanings, or stdout and
stderr behavior:

* keep `schemaVersion: 1` backward compatible; a breaking change needs a new
  schema version, a migration note, tests and an ADR update;
* keep the command free of permission prompts, file writes and content logging;
* keep `MeetingURLDetector.exportV1JoinDomains` frozen for v1;
* update the README, ADR 0003 and tests with any contract change.

### Context file (PEEK-213, PEEK-261, ADR 0004)

Peek reads `peek-context.json` from a folder the user picked, through an
app-scoped, read-only security bookmark. It never writes, moves or deletes
anything there. Events are matched by the export's `id`. Links are limited to
the `ContextLinkPolicy` allowlist (`https`, `obsidian`) and re-checked on click.
New fields must be optional; a breaking change needs a new `schemaVersion`.

## Conventions

* Put decisions in Domain or Application types, not in SwiftUI view bodies.
* Keep macOS side effects behind protocols when they need tests.
* Prefer immutable value types for formatted output and configuration.
* Publish state changes on the main queue.
* Add an ADR for cross-layer, persistence, privacy or external-contract changes.

## Known architectural debt

* `AppDelegate` (in `App/PeekApp.swift`, about 1,000 lines) still owns timers,
  status-item styling and animation, alert coordination and notification
  refresh. Split it into focused coordinators before adding more lifecycle
  features.
* `CalendarManager` (about 740 lines) still combines authorization, fetching,
  persistence orchestration and observable state. Split it into a calendar
  repository and a view model when quick event creation (PEEK-279) or a second
  calendar source (PEEK-214) starts.
* `MenuBarView.swift` and `PreferencesView.swift` are large single files; split
  them by screen section when they are next changed substantially.
