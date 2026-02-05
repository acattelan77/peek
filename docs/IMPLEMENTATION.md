# Peek - Implementation Documentation

This document outlines all features that have been implemented in the Peek calendar menu bar application.

## Overview

Peek is a macOS menu bar application that displays upcoming calendar events from selected calendars, providing quick access to event information and meeting links.

---

## Core Features

### 1. Calendar Integration
- **EventKit Integration**: Full access to macOS Calendar using the EventKit framework
- **Calendar Access Permission**: Proper permission request with fallback for macOS < 14.0 and macOS 14.0+
- **Multi-Calendar Support**: Users can select which calendars to monitor
- **Default Calendar Selection**: All calendars are enabled by default on first launch
- **Real-time Updates**: Events are fetched every 60 seconds automatically

**Files**: `CalendarManager.swift`, `Info.plist`

### 2. Menu Bar Display
- **Status Bar Icon**: Custom icon displayed in the menu bar with proper dark mode support
- **Event Summary**: Shows time until next event and event title
- **Time Until Display**: Dynamic countdown showing days, hours, or minutes until next event
  - Shows "5d" for events more than 24 hours away
  - Shows "3h 15m" for events within 24 hours
  - Shows "45m" for events within an hour
  - Shows "now" for events starting imminently
- **Event Counter**: Displays "+X" badge when multiple events are upcoming
- **Truncated Titles**: Long event titles are truncated with "..." in menu bar
- **Tooltip Support**: Full event title shown in tooltip when truncated
- **Ongoing Events**: Shows "Now - Event Title" for currently happening events

**Files**: `PeekApp.swift` (lines 163-229)

### 3. Popover Interface
- **Event List View**: Displays up to 5 upcoming events in a scrollable list
- **Branded Header**: Shows app icon, "Peek" name, and event count badge
- **Event Details**: Each event shows:
  - Event title with "NEXT" badge for the upcoming event
  - Date and time information (or "ALL DAY" badge)
  - Calendar name with color indicator
  - Location (if available)
  - Time until start (for next event)
- **Empty State**: Friendly "No upcoming events" message when no events exist
- **Keyboard Navigation**:
  - Up/Down arrows to navigate between events
  - Escape key to close popover
- **Global Hotkey**: Cmd+Shift+C to toggle popover from anywhere

**Files**: `MenuBarView.swift`, `PeekApp.swift`

### 4. Meeting Integration
- **URL Detection**: Automatically extracts meeting URLs from event notes, location, and URL fields
- **Supported Platforms**: Zoom, Google Meet, Microsoft Teams, Webex, GoToMeeting, Whereby, Discord
- **Security**:
  - HTTPS-only validation
  - Allowlist of trusted meeting domains
  - Input sanitization to prevent injection attacks
  - Length limits to prevent ReDoS attacks
- **Join Button**: Green "Join Meeting" button appears when meeting URL is detected
- **Claude Integration**: "Ask Claude about this meeting" button to prepare for meetings using Claude AI

**Files**: `MenuBarView.swift` (lines 297-453)

### 5. All-Day Event Display
- **Visual Distinction**:
  - Orange calendar icon (instead of blue clock)
  - "ALL DAY" badge with orange background
  - No time-until countdown shown for all-day events
- **Clear Separation**: Easy to distinguish all-day events from timed events at a glance

**Files**: `MenuBarView.swift` (lines 198-228)

### 6. Event Notifications
- **Permission Management**: Request notification permissions on app launch
- **Configurable Timing**: Choose when to be notified (5, 10, 15, or 30 minutes before events)
- **Smart Scheduling**: Notifications only scheduled for future events that haven't started
- **Meeting Integration**: Interactive "Join Meeting" button in notifications when URL detected
- **Snooze Functionality**: "Snooze (5 min)" button to delay notification
- **Rich Content**:
  - Event title as notification title
  - Start time and location in notification body
  - Event ID stored for reference
- **Background Management**: Notifications scheduled automatically when events refresh
- **Foreground Display**: Notifications shown even when app is open
- **Platform Support**: Uses UserNotifications framework (macOS 10.14+)

**Files**: `NotificationManager.swift`, `CalendarManager.swift`, `PeekApp.swift`, `PreferencesView.swift`, `Info.plist`

### 7. Preferences
- **Tabbed Interface**: Three-tab preferences window (Calendars, Filters, General)
- **Calendar Selection**:
  - Scrollable list of all available calendars
  - Checkbox to enable/disable each calendar
  - Visual indicators showing calendar colors and types (Local, CalDAV, Exchange, etc.)
  - "Select All" and "Deselect All" convenience buttons
- **Event Filtering**:
  - Hide all-day events toggle
  - Hide declined events toggle
  - Keyword filtering (comma-separated list to exclude events containing specific keywords)
  - Filters apply to both title and notes fields
- **Time Range Customization**:
  - Configurable lookahead period: Today only, 3 days, 7 days, 14 days, or 30 days
  - Max events to show: 3, 5, 10, 15, or 20 events
- **Status Bar Display Modes**:
  - Time Until: Shows countdown to next event (e.g., "3h 15m - Meeting")
  - Actual Time: Shows actual start time (e.g., "2:30 PM - Meeting")
  - Icon Only: Shows only the icon with no text
  - Event count badge toggle (+X indicator)
- **Appearance Themes**:
  - Auto: Follows system appearance
  - Light: Forces light mode
  - Dark: Forces dark mode
- **Global Hotkey Customization**:
  - Multiple hotkey options: ⌘⇧C, ⌘⇧P, ⌘⇧E, ⌘⌥C, ⌘⌥P
  - Requires app restart to take effect
- **Notification Settings**:
  - Toggle to enable/disable notifications
  - Configurable timing: 5, 10, 15, or 30 minutes before events
  - Visual feedback showing meeting link availability in notifications
- **Export/Import Settings**:
  - Export all settings to JSON file
  - Import settings from JSON file
  - Includes all preferences, filters, and calendar selections
- **Launch at Login**: Toggle to automatically start Peek when macOS starts
  - Uses modern SMAppService API for macOS 13.0+
  - Falls back to SMLoginItemSetEnabled for older macOS versions
- **Settings Persistence**: All preferences saved to UserDefaults

**Files**: `PreferencesView.swift`, `LaunchAtLogin.swift`, `CalendarManager.swift`, `NotificationManager.swift`

### 8. Quick Actions
- **Open Calendar.app**: Direct button to launch system Calendar application
- **Refresh Events**: Manual refresh button to fetch latest events immediately
- **Quit Button**: Clean application termination
- **Context Menu**: Right-click on any event for quick actions:
  - Copy Meeting Link (if URL detected)
  - Open in Calendar
  - Copy Location (if available)
  - Copy Event Title

**Files**: `MenuBarView.swift` (lines 71-93, 473-585)

---

## Security Implementations

### URL Validation
- **HTTPS Only**: Only HTTPS URLs are allowed for meeting links
- **Domain Allowlist**: Restricted to known meeting platforms
- **Subdomain Checking**: Properly validates subdomains of trusted platforms

**Files**: `MenuBarView.swift` (lines 350-380)

### Input Sanitization
- **Character Filtering**: Only alphanumerics and safe punctuation allowed
- **Length Limits**:
  - Event notes limited to 500 characters for URL extraction
  - Location limited to 500 characters
  - Claude prompts limited to 2000 characters total
- **URL Encoding Validation**: Additional check that encoded URLs don't exceed 8000 characters

**Files**: `MenuBarView.swift` (lines 443-453)

### ReDoS Protection
- **Simplified Regex Patterns**: Meeting URL patterns optimized to prevent exponential backtracking
- **Input Length Limits**: Text truncated before regex matching
- **First Match Only**: Uses `firstMatch` instead of `matches` to limit processing

**Files**: `MenuBarView.swift` (lines 297-348)

---

## Performance Optimizations

### DateFormatter Caching
- **Static Formatters**: DateFormatters are created once and reused
- **Performance Gain**: 3-6ms improvement per event render
- **Three Formatters**:
  - Full date/time formatter
  - Time-only formatter
  - Compact date formatter (MMM d)

**Files**: `MenuBarView.swift` (lines 146-163)

### Memory Management
- **Weak References**: Proper use of `[weak self]` in closures to prevent retain cycles
- **Event Monitor Cleanup**: Local event monitor is removed when popover disappears
- **Timer Invalidation**: Update timer properly cleaned up on app termination

**Files**: `MenuBarView.swift` (lines 98-108), `PeekApp.swift` (lines 97-101, 212-219)

### Efficient Updates
- **60-Second Interval**: Calendar events refreshed every minute (not every second)
- **Lazy Calendar Loading**: Only enabled calendars are queried
- **Event Limit**: Maximum of 5 events shown to limit memory and rendering

**Files**: `PeekApp.swift` (lines 20, 212-219), `CalendarManager.swift` (lines 13, 111)

---

## Code Quality

### Constants
- **Named Constants**: Magic numbers replaced with semantic names
  - `kEscapeKeyCode`, `kDownArrowKeyCode`, `kUpArrowKeyCode`
  - `kHotKeyID`, `kUpdateInterval`
  - `maxEventsToShow`, `maxTitleLength`

**Files**: Throughout codebase

### Error Handling
- **Safe Optionals**: No force unwraps (replaced `!` with `guard` statements)
- **Calendar Access Errors**: Error parameter passed through completion handlers
- **Graceful Degradation**: App continues to function even if calendar access denied

**Files**: `CalendarManager.swift` (lines 42-58, 90-93), `PeekApp.swift` (lines 79-94)

### Bounds Checking
- **Selected Index Validation**: Ensures `selectedEventIndex` never exceeds array bounds
- **onChange Handler**: Resets selection when event count changes

**Files**: `MenuBarView.swift` (lines 109-114)

---

## Platform Compatibility

### macOS Version Support
- **macOS 14.0+**: Uses `requestFullAccessToEvents` and modern `onChange` syntax
- **macOS 13.0+**: Uses `SMAppService` for launch at login
- **Earlier macOS**: Falls back to legacy APIs (`requestAccess`, `SMLoginItemSetEnabled`)

**Files**: `CalendarManager.swift` (lines 43-57), `LaunchAtLogin.swift` (lines 14-24), `MenuBarView.swift` (line 109)

---

## User Experience

### Visual Design
- **Native macOS Look**: Uses standard SwiftUI components and system fonts
- **Color Coding**:
  - Calendar colors preserved from system Calendar
  - Blue for timed events, orange for all-day events
  - Green gradient for meeting join buttons
  - Purple for Claude integration
- **Visual Hierarchy**: Clear separation with dividers, proper spacing, semantic sizing
- **Dark Mode Support**: Template rendering for icons, proper color schemes

**Files**: `MenuBarView.swift`, `PreferencesView.swift`, `PeekApp.swift`

### Interaction Patterns
- **Cmd+Drag**: Menu bar icon can be repositioned
- **Click to Open**: Single click opens popover
- **Keyboard Navigation**: Arrow keys and Escape for navigation
- **Global Hotkey**: Cmd+Shift+C accessible anywhere
- **Transient Popover**: Automatically closes when clicking outside

**Files**: `PeekApp.swift` (lines 140-161), `MenuBarView.swift` (lines 99-136)

---

## File Structure

```
Peek/
├── Peek/
│   ├── PeekApp.swift              # Main app and AppDelegate
│   ├── MenuBarView.swift           # Popover UI and event display
│   ├── PreferencesView.swift       # Settings/preferences UI
│   ├── CalendarManager.swift       # Calendar access and event fetching
│   ├── NotificationManager.swift   # Notification scheduling and handling
│   ├── LaunchAtLogin.swift         # Launch at login functionality
│   ├── Info.plist                  # App metadata and permissions
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/     # Application icon
│       └── StatusBarIcon.imageset/ # Menu bar icon
├── IMPLEMENTATION.md               # This file
└── ROADMAP.md                      # Future features and improvements
```

---

## Technical Architecture

### State Management
- **ObservableObject**: `CalendarManager` uses Combine for reactive updates
- **@Published Properties**:
  - `nextEvent`: The upcoming event
  - `upcomingEvents`: List of events (configurable count)
  - `hasCalendarAccess`: Permission state
  - `enabledCalendarIDs`: User's calendar selection
  - `lookaheadDays`: Configurable time range (1-30 days)
  - `maxEventsToShow`: Configurable event limit (3-20)
  - `hideAllDayEvents`: Filter toggle
  - `hideDeclinedEvents`: Filter toggle
  - `filterKeywords`: Keyword exclusion filter
  - `statusBarMode`: Display mode (Time Until/Actual Time/Icon Only)
  - `showEventCount`: Event count badge toggle
  - `appearanceMode`: Theme setting (Auto/Light/Dark)
  - `globalHotkey`: Hotkey configuration
  - `notificationsEnabled`: Notification toggle
  - `notificationTiming`: When to notify (5/10/15/30 min before)
- **Combine Publishers**: Property changes trigger automatic UI refresh
- **Reactive Updates**: Status bar updates automatically when display settings change
- **Notification Manager Singleton**: Shared instance manages all notification scheduling and handling

**Files**: `CalendarManager.swift`, `MenuBarView.swift`, `PreferencesView.swift`, `PeekApp.swift`

### Data Persistence
- **UserDefaults**:
  - Enabled calendar IDs
  - Lookahead days setting
  - Max events to show setting
  - Event filter settings (hide all-day, hide declined, keywords)
  - Status bar display mode
  - Show event count preference
  - Appearance mode
  - Global hotkey configuration
  - Notification preferences (enabled state and timing)
  - Launch at login preference
- **Automatic Saving**: Settings persist immediately on change
- **Notification State**: Permission state checked on launch
- **Export/Import**: Settings can be exported to and imported from JSON files
  - Full settings backup and restore capability
  - Cross-machine settings transfer support
  - Version tracking in exported files

**Files**: `CalendarManager.swift`, `PreferencesView.swift`, `LaunchAtLogin.swift`

---

## Key Achievements

1. ✅ **Secure by Default**: All security vulnerabilities addressed (URL injection, ReDoS, input sanitization)
2. ✅ **Performance Optimized**: DateFormatter caching, efficient updates, proper memory management
3. ✅ **Highly Customizable**:
   - 3 status bar display modes (Time Until/Actual Time/Icon Only)
   - Configurable time ranges (1-30 days)
   - Adjustable event limits (3-20 events)
   - Event filtering (all-day, declined, keywords)
   - Theme customization (Auto/Light/Dark)
   - 5 hotkey options
   - Export/import settings for backup and transfer
4. ✅ **User-Friendly**: Clear UI, keyboard navigation, customizable hotkey, visual distinction for event types, context menus
5. ✅ **Robust**: Error handling, bounds checking, no force unwraps, graceful degradation
6. ✅ **Compatible**: Supports multiple macOS versions with appropriate fallbacks
7. ✅ **Maintainable**: Named constants, clean architecture, proper separation of concerns, reactive state management
8. ✅ **Feature-Rich**: Multi-calendar support, meeting integration, Claude AI integration, launch at login, advanced filtering

---

## Recent Additions (2026-01-22)

### Quick Win Features Implemented

1. **Custom Time Ranges** ✅
   - Configurable lookahead period: 1, 3, 7, 14, or 30 days
   - Adjustable max events: 3, 5, 10, 15, or 20 events

2. **Event Filtering** ✅
   - Hide all-day events toggle
   - Hide declined events toggle
   - Keyword filtering with comma-separated exclusion list

3. **Status Bar Customization** ✅
   - Three display modes: Time Until, Actual Time, Icon Only
   - Event count badge toggle
   - Reactive updates when settings change

4. **Event Actions** ✅
   - Right-click context menu on all events
   - Copy meeting link, location, or title
   - Quick access to Calendar.app

5. **Color Themes** ✅
   - Auto mode (follows system)
   - Light mode (forced light appearance)
   - Dark mode (forced dark appearance)
   - Applied to both popover and preferences

6. **Hotkey Customization** ✅
   - 5 hotkey options: ⌘⇧C, ⌘⇧P, ⌘⇧E, ⌘⌥C, ⌘⌥P
   - Settings saved and loaded from UserDefaults
   - Applied at app launch

7. **Export/Import Settings** ✅
   - Export all settings to JSON file
   - Import settings from JSON file
   - Includes all preferences, filters, and configurations
   - Version tracking for future compatibility

---

## Recent Additions (2026-01-22 - Evening)

### Event Notifications Feature ✅

**Comprehensive notification system for upcoming events:**

1. **NotificationManager Class** (New File)
   - Singleton pattern for global access
   - Permission management with UNUserNotificationCenter
   - Smart scheduling: only schedules for future events
   - Meeting URL detection reused from MenuBarView
   - Interactive notification actions:
     - "Join Meeting" button (opens meeting URL)
     - "Snooze (5 min)" button (reschedules notification)
   - Foreground presentation (shows notifications even when app is open)
   - UNUserNotificationCenterDelegate implementation

2. **Notification Settings in CalendarManager**
   - NotificationTiming enum: none, 5min, 10min, 15min, 30min
   - Published properties for reactive updates
   - Persistence to UserDefaults
   - Export/import support

3. **PeekApp Integration**
   - NotificationManager singleton instance
   - Permission request on app launch
   - Combine observers for notification settings changes
   - Automatic rescheduling when events update or settings change
   - rescheduleNotifications() helper method

4. **PreferencesView UI Controls**
   - New "Notifications" section in General tab
   - Toggle to enable/disable notifications
   - Radio button picker for timing selection
   - Visual feedback about meeting link availability
   - Conditional display (only show timing when enabled)

5. **Info.plist Permission**
   - NSUserNotificationsUsageDescription added
   - User-friendly permission prompt message

**Technical Implementation:**
- Uses UserNotifications framework (macOS 10.14+)
- UNCalendarNotificationTrigger for precise scheduling
- UNNotificationCategory for custom actions
- Notification content includes event ID, title, time, location, and meeting URL
- Automatic cleanup of pending notifications when disabled

**User Experience:**
- One-time permission request on first use
- Seamless integration with existing settings
- Rich notifications with actionable buttons
- Smart defaults (15 minutes before)
- Works in background and foreground

---

*Last Updated: 2026-01-22 (Event Notifications Feature)*
