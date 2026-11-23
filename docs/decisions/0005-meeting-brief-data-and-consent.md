# ADR 0005: Meeting brief data and consent

- Status: Accepted
- Date: 2026-11-23
- Roadmap: PEEK-221, PEEK-222, PEEK-223, PEEK-224

## Context

Peek 2.1 adds a short "what to prepare" brief before a meeting. Meeting data is
personal and often confidential. The owner chose two engines: Apple's on-device
model, and Claude through the user's own Anthropic API key.

## Decision

1. Briefs are off by default. The on-device engine is the default engine.
2. A brief written by another app into `peek-context.json` (ADR 0004, `bullets`)
   always wins and calls no model, even with AI briefs off.
3. Every engine receives only `BriefInput`: title, minutes to start, up to eight
   people with name, role/company descriptor and context note, the cleaned
   invitation text (max 1,500 characters), and the context-file summary and
   points. Email addresses, locations, meeting links, calendar names and RSVP
   states are never included. Tests assert the prompt holds no `@` or `http`.
4. The cloud engine needs a consent screen that lists exactly those fields.
   Consent is stored as a version number (`briefCloudConsentVersion`); changing
   the fields means bumping `MeetingBriefService.currentCloudConsentVersion`
   so the user is asked again. Without current consent the cloud engine is
   never called.
5. The API key lives only in the keychain (`AnthropicKeyStore`), never in
   UserDefaults, logs or the cache. Peek uses the key holder's own account; no
   Peek server sits in between.
6. Generated briefs are cached in `Application Support/Peek/briefs.json` for
   three days, keyed by event id and start, with a SHA-256 fingerprint of the
   input so an edited event gets a new brief. Turning briefs off deletes the cache.
7. Automatic briefs start at most 15 minutes before the meeting and only for
   timed, non-declined meetings with people or notes that match no excluded
   keyword. A failure waits 10 minutes before the next try.

## Consequences

- The app gains `com.apple.security.network.client`. App Review notes must say
  the network is used only for the optional Claude brief.
- FoundationModels is weak-linked; the on-device engine reports why it is
  unavailable on macOS 13 to 15 or without Apple Intelligence.
- The cloud request sets a fallback model for policy declines; a refusal shows
  "The model declined to write a brief" and nothing is cached.
