# ADR 0003: Headless local-calendar export contract

- Status: Accepted
- Date: 2026-08-13

## Context

Northwind Notes needs a local, queryable agenda when its agents cannot use Google
Calendar directly. Google Calendar remains authoritative, and Peek already has
the user-approved local EventKit access and calendar-selection preference.

## Decision

Peek exposes `Peek --export --from <signed-days> --to <signed-days> --json`.
It exits before constructing its menu bar, windows, onboarding, notifications,
or HUD. The command checks existing Full Access without requesting permission;
on a missing grant or EventKit failure it writes a readable stderr error,
emits no JSON, and exits non-zero.

The schema is versioned at `schemaVersion: 1`, uses local ISO 8601 timestamps
with explicit UTC offsets, and sorts events by `startAt`, `endAt`, `title`, and
opaque occurrence identifier. It respects the existing selected-calendar
preference; no saved selection means every available calendar, while an
explicitly empty selection produces an empty export.

Links are metadata only. Peek scans notes, then location, then `event.url`,
deduplicates by first absolute URL, and marks only trusted HTTPS meeting URLs
as `join`. Other HTTP(S) URLs from notes or `event.url` are `document`; those
from location are `other`. The CLI has no knowledge of Northwind Notes paths or
renderer behavior.

## Consequences

- An external renderer owns atomic cache replacement, scheduling, and all
  Northwind Notes vault writes.
- Export output can contain personal calendar data and must not be committed,
  logged, or shared casually.
- EventKit remains behind `CalendarEventStoring`; the export path is a separate
  synchronous service rather than a dependency of observable `CalendarManager`.
- This is a maintained public-local contract. Preserve v1 compatibility unless
  a new schema version and external-renderer migration are explicitly planned;
  any contract change also updates export tests, README, architecture, and the
  project handoff.
