# Peek

Peek is a macOS menu bar app that shows your upcoming calendar events from the macOS Calendar app.

## Features

- Quick event overview from the menu bar
- Visual meeting status with color and pulsing alerts
  - Orange: 2 to 10 minutes away
  - Red + pulsing: less than 2 minutes away
  - Click the menu bar icon to toggle colors on or off
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

- Build unsigned app:
  - `./scripts/build-unsigned.sh`
- Build and create DMG:
  - `./scripts/create-dmg.sh`
  - `./scripts/create-simple-dmg.sh`

Note: some scripts may require sudo and create DMGs in the repo root.

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

- `Peek/Sources`: Swift source code
- `Peek/Resources`: assets, Info.plist, entitlements
- `docs`: design and planning docs
- `scripts`: build and DMG helpers
- `artifacts`: generated DMGs and build outputs

## Docs

- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/IMPLEMENTATION.md`
- `docs/CODE_ANALYSIS.md`
- `docs/FIXES_APPLIED.md`

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

See `docs/SECURITY.md` for reporting guidance.
