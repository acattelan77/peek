# ADR 0001: Use a layered monolith

- Status: Accepted
- Date: 2026-07-15

## Context

Peek is a small single-process menu-bar app, but lifecycle, EventKit, notifications, preferences, and UI logic were concentrated in a few files. Feature growth would make those files harder to test and change safely.

## Decision

Keep one application target and organize source into App, Application, Domain, Infrastructure, and Presentation layers. Use protocols at macOS service boundaries and pure value builders for display decisions.

## Consequences

- Navigation and build setup remain simple.
- Domain and formatting behavior gain focused test seams.
- Some existing coordinators remain large and will be split incrementally.
- A multi-module Swift package is deferred until compile time or team boundaries justify it.
