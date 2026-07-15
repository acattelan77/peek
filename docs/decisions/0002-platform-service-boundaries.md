# ADR 0002: Abstract stateful macOS services

- Status: Accepted
- Date: 2026-07-15

## Context

EventKit, UserNotifications, UserDefaults, and ServiceManagement are stateful global or framework-owned APIs. Direct use throughout the UI makes authorization and failure behavior difficult to test.

## Decision

Use `CalendarEventStoring`, `NotificationScheduling`, `PreferencesStoring`, and `LaunchAtLoginControlling` as narrow boundaries. Select live implementations in `AppEnvironment` or at the view composition boundary.

## Consequences

- Tests can provide deterministic fakes without calendar or notification permissions.
- Framework-specific data remains near infrastructure adapters.
- Protocols must remain capability-focused; they should not mirror entire Apple frameworks.
