# Peek

Peek is a macOS menu-bar companion for the Calendar app. It does not replace
your calendar: it reads the calendars you already have in macOS Calendar and
makes sure you never miss a meeting and arrive prepared for it.

The current version is in [`Configuration/Version.xcconfig`](Configuration/Version.xcconfig);
what changed in each version is in [`CHANGELOG.md`](CHANGELOG.md).

## What it does

**Never miss a meeting**

* The menu bar shows the next meeting and changes as it approaches: the title and
  start time, an amber pill with a countdown from 10 minutes, a red pulsing
  "Join now" pill under 2 minutes, and the time left while a meeting is running.
  It falls back to an icon when the menu bar is crowded or behind the notch.
* An alert ladder you set per moment: a notification at your lead time, a
  heads-up card 2 minutes before, and at the start either a card or a full-screen
  alert over every Space and full-screen app. Snooze, Ignore and Join are on the
  alert itself. Calendars can be set to badge only.
* Join links are detected for Zoom, Google Meet, Microsoft Teams, Webex, GoTo,
  Slack huddles, Amazon Chime, Jitsi, FaceTime, RingCentral and others, and open
  in the Zoom or Teams app when it is installed. A global shortcut (⌃⌥J) joins
  the meeting that is about to start.
* Alerts stay correct after sleep, travel across time zones, clock changes and
  midnight. The same meeting on two calendars alerts once.
* Any event, or a whole recurring series, can be muted or hidden.

**Arrive prepared**

* A popover with a compact month calendar, today's and upcoming meetings, and a
  page per meeting: who you are meeting, what to prepare, cleaned invitation
  notes (join boilerplate and dial-in numbers removed), and the meeting time in
  your world clocks.
* "You're about to meet…": attendees are matched with Contacts, if you allow it,
  for name, role and company.
* An optional meeting brief of three to five points, prepared 15 minutes before.
  It is written on the Mac with Apple Intelligence (macOS 26) or, after an
  explicit consent screen, by Claude with your own Anthropic API key. Off by
  default.
* An optional context folder: another local tool you use can write a
  `peek-context.json` file with notes, points to prepare, people and links per
  meeting, plus the day's priorities. Peek reads it and never writes to it. The
  format is in [ADR 0004](docs/decisions/0004-meeting-context-file.md).
* Discreet mode (⌃⌥D, or automatic while a display is mirrored) hides briefs,
  people, notes and context while you share your screen.

**For other tools**

* A headless command exports your selected calendars as versioned JSON, for
  local scripts that need your agenda (see [Calendar export](#calendar-export)).

Peek is available in English, Italian, German, French and Spanish, and follows
the language set in macOS.

## Privacy

Calendar data stays on the Mac. Peek has no account, no backend and no
telemetry. The only network connection is the optional Claude brief, which sends
the fields listed on its consent screen to the Anthropic API with the user's own
key. Diagnostics are local and never contain meeting content. Details are in
[`SECURITY.md`](SECURITY.md), [ADR 0005](docs/decisions/0005-meeting-brief-data-and-consent.md)
and [ADR 0006](docs/decisions/0006-local-diagnostics.md).

## Status

Peek is open source (MIT), feature-complete for its first public release and in
pre-release validation. Distribution will be through the Mac App Store and a Developer ID
signed, notarized DMG; neither is published yet. What is done, what is waiting
for checks on a Mac and what is missing is in [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Requirements

* macOS 13 or later. The on-device brief needs macOS 26 with Apple Intelligence.
* Calendar Full Access. Contacts and notifications are optional.
* To build: Xcode 26 or later (the project uses the macOS 26 SDK; newer
  frameworks are weak-linked so the app still runs on macOS 13).

## Build and run

```bash
# Build without signing
xcodebuild -scheme Peek -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

# Run the tests
xcodebuild -scheme Peek -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
```

Or open `Peek.xcodeproj` in Xcode and run the `Peek` scheme. For an app you can
keep in `/Applications`, `./scripts/build-unsigned.sh --install` builds an
ad-hoc signed Release app, and `./scripts/create-dmg.sh` wraps it in a DMG.
Every push to `main` also produces an ad-hoc signed test DMG as the
`Peek-test-installer` artifact of the "Test installer" workflow. It is not
notarized: on first launch, allow it in System Settings > Privacy & Security.

More in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## Using Peek

* Click the menu-bar item, or press ⌘⇧C anywhere, to open the popover.
* ↑ and ↓ move between meetings, Return opens a meeting's page, Esc goes back or
  closes.
* Right-click a meeting to mute its alerts or hide it.
* ⌘-drag the menu-bar item to move it.
* Preferences has four tabs: Alerts, Briefs, Calendars and General.

On first launch Peek shows events from every calendar until you choose some.

### Troubleshooting

* "No Calendar Access": enable Peek in System Settings > Privacy & Security >
  Calendars with Full Access, then reopen Peek.
* No events: check the calendar selection and filters in Preferences > Calendars.
* A shortcut does nothing: another app may own it. Choose another one in
  Preferences. macOS does not tell Peek when a shortcut is taken by another app.
* Something misbehaves: Preferences > General > Diagnostics > Export… saves a
  local report without meeting content that you can attach to an issue.

## Calendar export

Peek can export the selected calendars as JSON without opening its UI. It never
asks for Calendar permission in this mode, so grant Full Access first.

```zsh
/Applications/Peek.app/Contents/MacOS/Peek --export --from -3 --to 14 --json
```

`--from` and `--to` are signed day offsets from today, in local time; the window
ends at midnight after `--to`. Stdout carries only JSON (schema version 1);
errors go to stderr with a non-zero exit status, and no partial JSON is written.
The output contains personal data: do not commit it, log it or share it without
the calendar owner's permission. The contract is in
[ADR 0003](docs/decisions/0003-calendar-export-cli.md). Example with fictional data:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-13T06:45:00+02:00",
  "timeZone": "Europe/Rome",
  "window": {
    "from": "2026-08-10T00:00:00+02:00",
    "toExclusive": "2026-08-28T00:00:00+02:00"
  },
  "events": [
    {
      "id": "opaque-example-occurrence-id",
      "title": "Project review",
      "startAt": "2026-08-13T09:30:00+02:00",
      "endAt": "2026-08-13T10:00:00+02:00",
      "allDay": false,
      "calendar": { "id": "example-calendar", "title": "Work" },
      "location": null,
      "organizer": { "name": "Ada Lovelace" },
      "attendees": [],
      "notes": null,
      "links": [{ "kind": "join", "url": "https://meet.google.com/abc-defg-hij" }],
      "currentUserResponse": "accepted"
    }
  ]
}
```

## Repository map

| Path | What it holds |
| --- | --- |
| `Peek/Sources` | The app, in five layers: App, Application, Domain, Infrastructure, Presentation ([architecture](docs/ARCHITECTURE.md)) |
| `Peek/Resources` | Info.plist, entitlements, privacy manifest, assets, localizations |
| `PeekTests` | Unit and integration tests, with fakes for EventKit and notifications |
| `Configuration/Version.xcconfig` | The only place the version lives |
| `scripts` | Build, packaging, release and CI check scripts |
| `.github/workflows` | CI, test installer, Developer ID release, App Store upload |
| `design` | Brand master artwork and the original design handoff |
| `docs` | Roadmap, architecture, development, design system, release, App Store, decisions |

## Documentation

* [Roadmap and current state](docs/ROADMAP.md)
* [Checks on a Mac](docs/MAC_CHECKS.md)
* [Architecture](docs/ARCHITECTURE.md)
* [Development](docs/DEVELOPMENT.md)
* [Design system](docs/DESIGN_SYSTEM.md)
* [Versioning](docs/VERSIONING.md)
* [Release (Developer ID DMG)](docs/RELEASE.md) and [Mac App Store](docs/APP_STORE.md)
* [Decision records](docs/decisions/README.md)
* [Agent and contributor guide](AGENTS.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## License

Peek is open source under the [MIT License](LICENSE). You may use, modify and
redistribute it, including in commercial and App Store builds, as long as the
copyright notice and license text are kept.
