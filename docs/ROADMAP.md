# Peek - Feature Roadmap

This document outlines potential future enhancements and features that could be added to Peek.

---

## High Priority Features

### 1. Notifications
**Effort**: Medium (1-2 hours)
**Impact**: High

- Pre-event notifications (5 min, 15 min, 30 min before events)
- Customizable notification timing per calendar
- Notification actions (Join Meeting, Snooze, Dismiss)
- macOS Notification Center integration

**Technical Notes**: Use `UNUserNotificationCenter` with custom actions

---

### 2. Custom Time Ranges
**Effort**: Low (30 min)
**Impact**: Medium

- User-configurable lookhead period (currently fixed at 7 days)
- Options: Today only, Next 24 hours, Next 3 days, Next 7 days, Next 30 days
- Configurable max events to display (currently fixed at 5)

**Files to Modify**: `CalendarManager.swift`, `PreferencesView.swift`

---

### 3. Event Filtering
**Effort**: Medium (1 hour)
**Impact**: Medium

- Filter out accepted/declined/tentative events
- Hide all-day events option
- Hide recurring events option
- Filter by event keywords

**Files to Modify**: `CalendarManager.swift`, `PreferencesView.swift`

---

### 4. Quick Event Creation
**Effort**: Medium (1-2 hours)
**Impact**: High

- "+" button to create quick events
- Natural language parsing ("Meeting with John tomorrow at 3pm")
- Quick templates for common meeting types
- Add to specific calendar

**Technical Notes**: Consider using `NSLinguisticTagger` for NLP

---

## User Experience Enhancements

### 5. Status Bar Customization
**Effort**: Medium (1 hour)
**Impact**: Medium

- Toggle between "time until" vs "actual time" display
- Show/hide event count badge
- Compact mode (icon only)
- Custom status bar icon options

**Files to Modify**: `PeekApp.swift`, `PreferencesView.swift`

---

### 6. Event Details View
**Effort**: Low (30 min)
**Impact**: Low

- Click event to see full details in expanded view
- Show full event notes
- Show all attendees
- Show event attachments

**Files to Modify**: `MenuBarView.swift`

---

### 7. Multiple Time Zone Support
**Effort**: Medium (1 hour)
**Impact**: Medium

- Show event times in multiple time zones
- Useful for distributed teams
- Configurable time zone list

**Technical Notes**: Use `TimeZone` and add formatter variants

---

### 8. Event Actions
**Effort**: Low (30 min)
**Impact**: Medium

- Right-click context menu on events
- Quick actions: Open in Calendar.app, Copy meeting link, Email attendees
- Mark as "Will not attend"

**Files to Modify**: `MenuBarView.swift`

---

## Visual Improvements

### 9. Color Themes
**Effort**: Low (30 min)
**Impact**: Low

- Light/Dark/Auto theme toggle
- Custom accent colors
- High contrast mode

**Files to Modify**: Throughout UI files

---

### 10. Custom Event Colors
**Effort**: Low (30 min)
**Impact**: Low

- Color-code events by type or keywords
- Visual priority indicators
- Custom color rules

**Files to Modify**: `MenuBarView.swift`, `PreferencesView.swift`

---

### 11. Icons and Glyphs
**Effort**: Low (15 min)
**Impact**: Low

- More SF Symbols for different event types
- Custom icons for specific meeting platforms (Zoom logo, Meet logo, etc.)
- Event type indicators (1-on-1, group, interview, etc.)

**Files to Modify**: `MenuBarView.swift`

---

### 12. Animations
**Effort**: Low (30 min)
**Impact**: Low

- Smooth transitions when events update
- Fade in/out for popover
- Subtle animation for "time until" countdown

**Technical Notes**: Use SwiftUI `.animation()` and `.transition()`

---

## Smart Features

### 13. Travel Time Integration
**Effort**: High (3-4 hours)
**Impact**: High

- Parse location addresses
- Estimate travel time using MapKit
- Adjust "time until" to include travel time
- "Leave now" notifications

**Technical Notes**: Use `MKDirections` API for travel time estimates

---

### 14. Conflict Detection
**Effort**: Medium (1 hour)
**Impact**: Medium

- Highlight overlapping events
- Visual indicator for double-booked times
- Suggest reschedule options

**Files to Modify**: `CalendarManager.swift`, `MenuBarView.swift`

---

### 15. Focus Mode Integration
**Effort**: Low (30 min)
**Impact**: Medium

- Detect ongoing events and auto-enable Do Not Disturb
- Integration with macOS Focus modes
- Custom focus rules per calendar

**Technical Notes**: May require private APIs or workarounds

---

### 16. Smart Suggestions
**Effort**: High (4+ hours)
**Impact**: Medium

- Suggest prep time before meetings
- Recommend break times between back-to-back meetings
- Identify patterns in calendar usage
- ML-based scheduling suggestions

**Technical Notes**: Requires Core ML or Create ML

---

### 17. Calendar Analytics
**Effort**: Medium (2 hours)
**Impact**: Low

- Meeting time statistics
- Most common meeting times
- Calendar utilization graphs
- Export reports

**Files to Modify**: New analytics module

---

## Integration Features

### 18. Email Integration
**Effort**: High (3+ hours)
**Impact**: Medium

- Link to related emails for meetings
- Show recent email threads with attendees
- Quick email compose to attendees

**Technical Notes**: Requires Mail.app integration or IMAP access

---

### 19. Contacts Integration
**Effort**: Medium (1-2 hours)
**Impact**: Low

- Show attendee photos from Contacts
- Quick view of contact details
- Click to call/message attendees

**Technical Notes**: Use `Contacts` framework

---

### 20. Slack/Teams Integration
**Effort**: High (4+ hours)
**Impact**: Medium

- Set status based on calendar
- Post meeting reminders to channels
- Quick Slack/Teams message to attendees

**Technical Notes**: Requires OAuth and API integrations

---

### 21. Task Manager Integration
**Effort**: High (3+ hours)
**Impact**: Medium

- Link tasks to calendar events
- Show related tasks for meetings
- Integration with Reminders.app, Things, OmniFocus, etc.

**Technical Notes**: Requires multiple integrations or URL schemes

---

### 22. Extended Claude Integration
**Effort**: Medium (2 hours)
**Impact**: Medium

- Auto-generate meeting agendas
- Post-meeting summaries
- Action items extraction
- Meeting notes templates

**Technical Notes**: Requires Claude API access

---

## Settings & Customization

### 23. Hotkey Customization
**Effort**: Low (30 min)
**Impact**: Low

- Let users choose custom global hotkey
- Support multiple hotkeys for different actions

**Files to Modify**: `PeekApp.swift`, `PreferencesView.swift`

---

### 24. Menu Bar Position
**Effort**: Low (15 min)
**Impact**: Low

- Pin to left/right side of menu bar
- Manual position saving

**Technical Notes**: macOS controls this largely, but can influence with item ordering

---

### 25. Export/Import Settings
**Effort**: Low (30 min)
**Impact**: Low

- Export preferences to file
- Import settings on new machine
- Sync settings via iCloud

**Files to Modify**: New settings manager

---

### 26. Advanced Preferences
**Effort**: Low (30 min)
**Impact**: Low

- Show/hide specific event fields
- Custom date/time formats
- Language localization options

**Files to Modify**: `PreferencesView.swift`

---

## Performance & Polish

### 27. Improved Caching
**Effort**: Medium (1 hour)
**Impact**: Medium

- Cache event queries to reduce EventKit calls
- Intelligent cache invalidation
- Background refresh

**Files to Modify**: `CalendarManager.swift`

---

### 28. Reduced Memory Footprint
**Effort**: Medium (1-2 hours)
**Impact**: Low

- Lazy loading of event details
- Image/icon caching
- Memory profiling and optimization

**Files to Modify**: Throughout

---

### 29. Accessibility
**Effort**: Medium (1-2 hours)
**Impact**: High

- VoiceOver support
- High contrast mode
- Keyboard-only navigation improvements
- Adjustable font sizes

**Files to Modify**: Throughout UI files

---

### 30. Unit Tests
**Effort**: High (4+ hours)
**Impact**: High (for maintainability)

- Test calendar fetching logic
- Test URL extraction and validation
- Test date formatting
- Test preferences persistence

**Technical Notes**: Create new test target

---

### 31. Error Messages
**Effort**: Low (30 min)
**Impact**: Medium

- User-friendly error messages
- Recovery suggestions
- Error reporting option

**Files to Modify**: Throughout

---

## Advanced Features

### 32. Menulet Widget Mode
**Effort**: High (3+ hours)
**Impact**: Medium

- Inline event display in menu bar (not just popover)
- Expandable menu bar view
- Alternative to popover interface

**Technical Notes**: Complex NSStatusItem customization required

---

### 33. Calendar Subscriptions
**Effort**: Medium (2 hours)
**Impact**: Low

- Subscribe to external calendars (webcal://)
- Public calendar management
- Holiday calendars

**Technical Notes**: Use `EKEventStore` subscription methods

---

### 34. Recurring Event Smart Display
**Effort**: Medium (1 hour)
**Impact**: Low

- Show next X occurrences of recurring events
- "Repeats weekly" indicator
- Skip/reschedule recurring instance

**Files to Modify**: `CalendarManager.swift`, `MenuBarView.swift`

---

### 35. Meeting Room Availability
**Effort**: High (4+ hours)
**Impact**: Medium

- Check room availability for meetings
- Suggest alternative rooms
- Integration with Exchange/O365

**Technical Notes**: Requires Exchange or O365 API integration

---

### 36. Agenda View
**Effort**: Medium (2 hours)
**Impact**: Medium

- Timeline view of day's events
- Visual event blocks showing duration
- Drag to reschedule

**Files to Modify**: New view component

---

### 37. Week/Month View
**Effort**: High (4+ hours)
**Impact**: Low

- Calendar grid view
- Navigate through weeks/months
- Mini Calendar.app alternative

**Files to Modify**: New view component

---

### 38. Event Templates
**Effort**: Medium (2 hours)
**Impact**: Medium

- Save common meeting types as templates
- Quick create from template
- Template includes: duration, location, attendees, notes

**Files to Modify**: New template manager, `PreferencesView.swift`

---

### 39. Sharing
**Effort**: Medium (2 hours)
**Impact**: Low

- Share calendar availability with others
- Generate public availability links
- "Send my availability" feature

**Technical Notes**: Requires backend service or iCloud integration

---

### 40. Automation & Shortcuts
**Effort**: High (4+ hours)
**Impact**: Medium

- macOS Shortcuts integration
- Scriptable actions
- AppleScript support
- URL scheme for external apps

**Technical Notes**: Implement `NSUserActivity`, `INIntent`, URL schemes

---

## Implementation Priority

### Quick Wins (< 1 hour each)
1. Custom time ranges
2. Event filtering
3. Status bar customization
4. Event actions
5. Color themes
6. Custom event colors
7. Hotkey customization
8. Export/import settings

### High Impact (Start here)
1. Notifications
2. Quick event creation
3. Travel time integration
4. Conflict detection
5. Accessibility improvements

### Nice to Have
1. Multiple time zone support
2. Event details view
3. Animations
4. Analytics
5. Extended Claude integration

### Long-term Projects
1. Email integration
2. Slack/Teams integration
3. Task manager integration
4. Week/month view
5. Automation & Shortcuts

---

## Technical Debt

### Code Quality Improvements
- [ ] Add comprehensive unit tests
- [ ] Add UI tests for critical flows
- [ ] Improve error handling coverage
- [ ] Add logging framework
- [ ] Performance profiling
- [ ] Memory leak detection
- [ ] Thread safety audit

### Documentation
- [ ] Add code documentation comments
- [ ] API documentation
- [ ] Architecture decision records
- [ ] User guide / help documentation
- [ ] Developer setup guide

### Build & Distribution
- [ ] CI/CD pipeline
- [ ] Automated releases
- [ ] Code signing
- [ ] Notarization for distribution
- [ ] App Store submission (if desired)
- [ ] Update mechanism (Sparkle or similar)

---

## Community Features

### Open Source Preparation
- [ ] License selection
- [ ] Contribution guidelines
- [ ] Code of conduct
- [ ] Issue templates
- [ ] PR templates
- [ ] Security policy

### User Engagement
- [ ] In-app feedback mechanism
- [ ] Beta testing program
- [ ] Feature voting
- [ ] Usage analytics (opt-in)
- [ ] Crash reporting

---

## Notes

- Features are ordered by category, not strict priority
- Effort estimates are approximate and may vary
- Many features can be implemented incrementally
- User feedback should drive priority
- Some features may require macOS API changes or permissions

---

*Last Updated: 2026-01-22*
