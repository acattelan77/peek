# Peek

Peek is a lightweight macOS menu bar calendar companion. It shows your upcoming events from the macOS Calendar app, highlights urgency as meeting time approaches, and provides one-click join links for common meeting providers.

Current development version: **1.1.0 (build 5)**.

## About This Repo

This repository contains the macOS app source, resources, tests, build scripts, and documentation needed to build and distribute Peek. Local build outputs are written to `build/` and `artifacts/` and are ignored.

## Features

- Quick event overview from the menu bar
- Manual icon-only display mode; notch-safe automatic switching is planned
- Visual meeting urgency cues
- Orange when 2 to 10 minutes away
- Red with pulsing when less than 2 minutes away
- Join buttons for common meeting links (Zoom, Google Meet, Teams, Webex, GoToMeeting, Whereby, Discord)
- Event details: title, date, time, location, calendar, time until start
- Calendar selection with saved preferences
- Smart auto refresh (every minute normally, every 5 seconds when a meeting is close)
- Dark mode support

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Calendar access permission

## Install and Run

### Option 1: Xcode

1. Open `Peek.xcodeproj` in Xcode
2. Build and run (Cmd+R)
3. Grant calendar access when prompted

### Option 2: Scripts

These scripts live in `scripts/`:

- Build unsigned app: `./scripts/build-unsigned.sh`
- Build and create DMG: `./scripts/create-dmg.sh`
- Build and create simple DMG: `./scripts/create-simple-dmg.sh`

Optional install: `./scripts/build-unsigned.sh --install` (requires sudo to copy into `/Applications`). DMGs are created in `artifacts/`.

### Option 3: CLI

```bash
# Build
xcodebuild -scheme "Peek" -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

# Test
xcodebuild -scheme "Peek" -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" test
```

## Usage

- Click the menu bar item to open the popup
- Click "Calendars..." to choose which calendars to monitor
- Your selection is saved and restored on restart

### First Launch Behavior

On first launch (before selecting calendars), Peek shows events from all available calendars.

## Keyboard Shortcuts

- Esc: close the popup
- Up/Down: move between events
- Cmd+Shift+C: toggle Peek from anywhere
- Cmd+Drag: reposition the menu bar item

## How It Works

- EventKit for calendar access
- NSStatusItem for the menu bar UI
- SwiftUI for the popup UI
- Carbon for global hotkey registration

## Project Structure

- `Peek/Sources/App`: application lifecycle and composition root
- `Peek/Sources/Application`: observable state and use-case coordination
- `Peek/Sources/Domain`: event, meeting-link, urgency, and preference policies
- `Peek/Sources/Infrastructure`: EventKit, notification, and persistence adapters
- `Peek/Sources/Presentation`: SwiftUI/AppKit views and user-facing formatting
- `Peek/Resources`: asset catalogs, localization, entitlements, and Info.plist
- `Configuration/Version.xcconfig`: canonical marketing version and build number
- `Peek.xcodeproj`: Xcode project
- `PeekTests/`: unit tests
- `docs/`: architecture, product, design, development, and release documentation
- `design/brand`: source brand artwork
- `scripts/`: build and DMG helpers
- `build/`: local Xcode derived data/output (ignored)
- `artifacts/`: local build outputs (ignored)

## Docs

- [Project status](docs/PROJECT_STATUS.md)
- [Current handoff](docs/HANDOFF.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Development](docs/DEVELOPMENT.md)
- [Versioning](docs/VERSIONING.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Release process](docs/RELEASE.md)
- [Security policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)

## Troubleshooting

If the menu bar shows "No Calendar Access":

1. Open System Settings > Privacy and Security > Calendars
2. Make sure Peek is enabled
3. Restart the app

If no events appear:

- Verify you have events in Calendar
- Check calendar selection in the app

If the global hotkey does not work:

- Check if another app uses Cmd+Shift+C
- Restart the app

## Contributing

Issues and pull requests are welcome. If you plan to make larger changes, open an issue first so we can align on scope.

## Security

See the **Security Posture** section in `docs/PROJECT_STATUS.md`.
