# Checks on a Mac

These checks need a real Mac with the app running, so only the owner can do
them. Each section belongs to a `Shipped` item in `docs/ROADMAP.md`. Tick a box
in a pull request once the check passes; when every box of an item is ticked,
set the item to `Done` in the roadmap. A failed check becomes a bug fix with its
own roadmap ID.

Use the test installer from the latest `main` (the `Peek-test-installer`
artifact of the "Test installer" workflow) unless a section says otherwise.
Use fictional or test events where you can, and never paste real meeting
content into an issue or pull request.

Pending since: 1.6.0 to 1.16.1 (2026-11-23 to 2026-11-25). No check below has
been recorded as passed yet.

## Design system v2 (1.6.0)

- [ ] Light, dark and Increased Contrast look right in the popover, Preferences,
      onboarding and the Starting now card (see "Visual QA" in
      `docs/DESIGN_SYSTEM.md`).
- [ ] The amber badge uses dark text; the critical red reads clearly.
- [ ] Reduce Motion toggled while the app runs stops and restarts the pulse.
- [ ] A row turning critical with the popover open gets its ring and dots.
- [ ] SOON and NOW tints are readable on a light menu bar.

## PEEK-201 to PEEK-204: never miss a meeting (1.7.0)

- [ ] Month view: dots on days with events; previous, next and Today; choosing a
      day shows its agenda; hiding it in Preferences works.
- [ ] A Zoom `/j/` link and a Teams link open the native app when installed, and
      the browser when the Preferences switch is off or the app is missing.
- [ ] Full-screen start alert appears over a full-screen app and on the current
      Space; Return joins, Esc dismisses, "In 1 minute" brings it back once; a
      focus block without link or attendees gets the card; Off shows nothing.
- [ ] With Peek set to Italian (System Settings > General > Language & Region >
      Applications), the popover, Preferences, onboarding and permission prompts
      show no truncation.
- [ ] `Peek --export --from 0 --to 7 --json` still classifies Zoom, Meet and Teams
      links as `join`, and any external consumer of the export still reads it.

## PEEK-211 to PEEK-213: meeting context (1.8.0)

- [ ] "Show who you're meeting": the Contacts prompt appears once, in the app
      language; a known contact shows "You're about to meet <name>, <role> at
      <company>" on the next-meeting card, the heads-up card and the full-screen
      alert; denying access leaves the switch off with a footnote.
- [ ] Zoom, Meet and Teams invitations keep only the agenda in Notes.
- [ ] A folder with a `peek-context.json` (example in ADR 0004) whose `id` comes
      from the export shows the headline, Context and people notes; Remove clears
      it; after quitting and relaunching the folder is still readable.
- [ ] Without Contacts and without a folder, a meeting shows no empty fields.

## PEEK-221 to PEEK-224: meeting brief (1.9.0)

- [ ] On a Mac without macOS 26 or Apple Intelligence, the Briefs footnote says why
      the on-device engine is unavailable.
- [ ] On macOS 26 with Apple Intelligence, a meeting with people or notes within
      15 minutes gets points labelled "Written on this Mac"; the full-screen alert
      shows up to three.
- [ ] Choosing Claude shows the consent screen with the fields; Cancel keeps "On
      this Mac"; after accepting and saving a key the field reads "Saved in your
      keychain"; "Prepare brief" gives "Written by Claude"; a wrong key shows the
      rejected-key message.
- [ ] A context file with `bullets` for an event shows them labelled "From your
      context folder", with briefs off too.
- [ ] An excluded keyword in a title gives no brief and no button.
- [ ] Editing the notes drops the old brief; turning briefs off and on clears
      generated briefs.
- [ ] The app launches on macOS 13 to 15.

## PEEK-231 to PEEK-233: join, countdown and time zones (1.10.0)

- [ ] ⌃⌥J with a Zoom or Teams meeting in the next 30 minutes opens it in the app;
      with none, the popover opens; ⌘⇧C opens the popover and does not join; with
      the join shortcut Off, ⌃⌥J does nothing.
- [ ] "Count down to meetings only" skips a lunch block before a call; the start
      alert still follows the lunch if its style allows; with nothing ahead the
      menu bar reads "No upcoming meetings".
- [ ] "Name in the menu bar: Who you're meeting" shows "8m - <name>"; the tooltip
      shows the title.
- [ ] Five world clocks appear under the header and update each minute; a city a
      day ahead shows +1; a meeting's page shows its time in each city; removing a
      city works.
- [ ] VoiceOver reads each clock as one element ("Dublin, 14:05").

## PEEK-241: Peek 2.0 mockup alignment (1.11.0)

- [ ] Compared with the approved mockup canvas in light and dark: header and month
      grid, the next-meeting card (normal, SOON, NOW), rows under Today and
      Tomorrow, a finished meeting, the meeting page (open, Escape back), the
      full-screen alert, and the four Preferences tabs.

## PEEK-242: menu-bar states and alert ladder (1.12.0)

- [ ] 20 minutes before: "Title · HH:MM" in normal text.
- [ ] From 10 minutes an amber pill "· N min"; from 2 minutes a red pulsing pill
      "Join now · Zoom" (static with Reduce Motion).
- [ ] 2 minutes before, the heads-up card shows "IN 2 MIN"; at the start the chosen
      start alert shows.
- [ ] During a meeting with nothing close: "N min left".
- [ ] With a crowded menu bar or Show = Icon only, the glyph sits inside the pill.
- [ ] A badge-only calendar gets no notification, card or start alert.
- [ ] Light and dark menu bars; Preferences > Alerts matches the canvas.

## PEEK-261 to PEEK-264: day priorities and links (1.13.0)

- [ ] A context file whose `day.date` is today shows three priorities and a link
      button that opens its `obsidian://` or `https://` target from the sandboxed
      build.
- [ ] Yesterday's `day.date` hides the block; meetings keep their context.
- [ ] A meeting with two bullets: the notification and the 2-minute card say "2 to
      prepare".
- [ ] `file://` and `http://` links are not shown.
- [ ] A file generated two days ago shows "Context from <date>" and no day block;
      Preferences > Briefs shows when it was generated.

## PEEK-275: local diagnostics (1.13.1)

- [ ] `log stream --level info --predicate 'subsystem == "com.peek.app"'` shows
      `calendar`, `notifications` and `alerts` lines with no titles or names.
- [ ] Preferences > General > Diagnostics > Export… reveals
      `Peek-diagnostics-<date>-<time>.json` in the Finder, with no meeting titles,
      people or paths inside.
- [ ] After a meeting start, the exported journal has `shown kind=…` or
      `skipped … reason=…` for it.

## PEEK-271 and PEEK-272: time and notification robustness (1.14.0)

- [ ] With an event in 10 minutes, changing the time zone in System Settings keeps
      the notification at the right instant.
- [ ] Closing the lid for 5 minutes across a meeting start shows "Started N min
      ago" on opening.
- [ ] The same event on two calendars gives one notification.
- [ ] A daily recurring meeting notifies every day.

## PEEK-273: per-event control (1.15.0)

- [ ] Mute Alerts > This Event Only on a weekly meeting: bell-slash, no
      notification, card or start alert; next week's occurrence alerts.
- [ ] Hide Event on a one-off event removes it from the popover, the month's day
      list and the menu bar; Preferences > Alerts lists it; Restore brings it back.
- [ ] Hiding a whole series, then Show Event from Preferences, works.
- [ ] Ignore on the 2-minute card skips the start alert; Dismiss or Esc on the
      full-screen alert does not bring it back.
- [ ] The join shortcut skips a hidden meeting and joins a muted one.

## PEEK-274: discreet mode (1.16.0)

- [ ] ⌃⌥D hides priorities, brief, people and notes; the menu-bar glyph becomes an
      eye; pressing again restores them.
- [ ] Mirroring the display (TV, AirPlay, projector) turns discreet mode on; the
      footer eye turns it off for that session.
- [ ] With the full-screen start alert style and discreet mode on, the start shows
      the card.
- [ ] While sharing the screen in Zoom and Meet, macOS holds back Peek's
      notifications; discreet mode still needs the shortcut.

## PEEK-276: meeting page with a context-file headline (1.16.1)

- [ ] A meeting with a context-file headline keeps the event title as page title;
      Context starts with the headline in bold, capitalized.
- [ ] The Context paragraph starts with a capital letter and does not repeat the
      "What to prepare" bullets.
- [ ] A meeting without a file headline still titles itself "You're about to
      meet…".
- [ ] The full-screen start alert shows the event title as its headline.
- [ ] On the 2-minute and Starting now cards, "Join Google Meet" stays on one line.

## PEEK-AUD-07: release validation (needs hardware and a clean account)

Run on a signed candidate (TestFlight or notarized DMG), ideally on a fresh macOS
user account, following `docs/RELEASE.md` and "TestFlight plan" in
`docs/APP_STORE.md`.

- [ ] Calendar Full Access grant, deny, revoke and recovery.
- [ ] Notification allow, deny and delivery.
- [ ] Menu-bar visibility, compact transitions and popover anchoring on crowded,
      notched and external displays.
- [ ] Global shortcuts.
- [ ] VoiceOver focus and order; keyboard-only use; Increased Contrast; Reduce
      Motion.
- [ ] Gatekeeper launch of the notarized DMG on a clean account.
- [ ] macOS 13 hardware: launch, alerts and popover.
