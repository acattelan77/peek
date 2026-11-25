# ADR 0004: Meeting-context file contract

- Status: Proposed (PEEK-213)
- Date: 2026-11-23

## Context

Peek's meeting-context card ("You're about to meet Marco, CEO at Northwind")
needs context that only another local system has, such as Northwind Notes's notes
about people and projects. PEEK-111 already exports Peek's agenda to such a
system. The reverse direction must work in the sandboxed App Store build, keep
Peek free of Northwind Notes knowledge, and stay read-only.

## Decision

The user chooses a folder in Preferences. Peek stores an app-scoped,
read-only security bookmark and reads one file in it:
`peek-context.json`. Peek never writes, moves or deletes anything there.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-11-23T08:00:00+01:00",
  "events": [
    {
      "id": "<the PEEK-111 export id>",
      "startAt": "2026-11-24T10:00:00+01:00",
      "headline": "Renewal call with Northwind",
      "summary": "Short paragraph shown under Context.",
      "bullets": ["Up to six points to prepare"],
      "people": [
        {"email": "marco@northwind.example", "name": "Ada Lovelace",
         "role": "CEO", "company": "Northwind", "note": "Prefers short calls"}
      ],
      "links": [{"title": "Account notes", "url": "https://example.com/notes"}]
    }
  ],
  "day": {
    "date": "2026-11-24",
    "headline": "Renewal call moved to today",
    "priorities": [{"text": "Talking points for the renewal call", "done": false}],
    "links": [{"title": "Day log", "url": "obsidian://open?vault=Notes&file=today"}]
  }
}
```

* `schemaVersion` is required and must be `1`; any other value disables the
  file and Preferences says why. `events[].id` is required; every other field
  is optional. Unknown fields are ignored, so writers may add fields.
* `id` is the opaque `id` of the PEEK-111 export JSON v1 for the same event.
  Recurring events share an `id`: an entry with `startAt` (ISO 8601 with
  offset) matches only the occurrence that starts within a minute of it and
  wins over an entry without `startAt`, which matches every occurrence.
* `headline` replaces Peek's own headline. People are matched by email;
  their `name`, `role` and `company` win over Contacts, which win over the
  email domain.
* Limits: 1 MiB per file, 1000 events, 6 bullets, 25 people, 6 links; long
  strings are clipped. Links must be `https` or `obsidian` (see "Amendment").
* Peek checks the file's modification date at most every 30 seconds.

## Consequences

* The writer owns atomic replacement (write to a temporary file in the same
  folder, then rename) and what the file contains. Like the export, the file
  holds personal data and must not be committed or logged.
* Removing or retyping a v1 field needs `schemaVersion: 2` and a migration
  planned with the writer. The PEEK-111 export contract is unchanged.
* A phase 3 AI brief from Northwind Notes can travel in `summary` and `bullets`
  without Peek calling any model.

## Amendment 2026-11-24: `day` object, `obsidian://` links, stale files (PEEK-261..264)

The change is additive, so `schemaVersion` stays `1`.

* **`day`** (optional, top level). `date` (`YYYY-MM-DD`, a local calendar
  date) is required; `headline`, `priorities` (`[{text, done}]`) and `links`
  are optional. Limits: 5 priorities decoded, 3 shown, 200 characters each;
  headline 200 characters; 3 links. A missing, malformed or undated `day` is
  ignored without an error and the rest of the file keeps working. The popover
  shows it only when `date` is today in the user's time zone. Peek never writes
  back: `done` is display only. The `day` object never reaches a brief engine:
  `BriefInput` (ADR 0005) is unchanged, and a test asserts it. Its text is held
  in memory with the rest of the file and is never logged or written anywhere.
* **Bullets** are the points still open; a writer leaves done points out. The
  lead-time notification and the 2-minute card count them ("2 to prepare: …").
* **Links.** The allowlist is fixed in code: `https` and `obsidian`, for
  `events[].links` and `day.links`. Every other scheme (`http`, `file`,
  `javascript`, `x-apple…`, app schemes) is dropped when the file is read, and
  the opener checks the scheme again. `obsidian` is accepted because the file
  comes from a folder the user chose, and the link opens a local app only when
  the user clicks it, through `NSWorkspace`; Launch Services opening a URL for
  another app needs no extra sandbox entitlement. Peek never opens a link on
  its own.
* **Stale files.** A file whose `generatedAt` is more than 36 hours old hides
  the day block; meetings keep their context with a quiet "Context from <date>"
  line, and Preferences shows when the file was last generated. A file without
  `generatedAt` counts as fresh.

## Amendment 2026-11-25: how Peek shows writer text (PEEK-276)

No contract change. Peek now shows an `events[].headline` from the file at the
top of the meeting page's Context section, not as the page title, which stays
the event title. The full-screen start alert also keeps the event title as its
headline; the 2-minute card still shows the file headline as its context line. Peek
upper-cases the first letter of `headline`, `summary`, `bullets`,
`people[].note`, `day.headline` and `day.priorities[].text` when it is a
lower-case letter and the first word has no other capital ("iPhone" stays).
Names, roles, companies and link titles are left as written. The Context
section leaves out bullets already listed under "What to prepare".
