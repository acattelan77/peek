# Mac App Store readiness

Last updated: 2026-11-25. Workstream: `docs/workstreams/app-store-readiness.md`.

Peek ships two ways (owner decision, 2026-11-23): the Mac App Store and a
Developer ID-signed, notarized DMG. Both come from the same source and the same
sandboxed target. This page lists what the repository already does, what only
the owner can do on Apple's and GitHub's side, and the drafts for App Store
Connect. Submitting for App Review stays last and is the owner's step.

## What the repository does

* `Peek/Resources/PrivacyInfo.xcprivacy` is bundled in the app. It declares no
  tracking, no tracking domains, the two required-reason APIs Peek uses
  (UserDefaults `CA92.1`, file timestamps `3B52.1` for the user-picked context
  folder) and the data the optional Claude brief sends off the Mac.
* `Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO`, so App Store
  Connect does not ask the export-compliance question for each build.
* `scripts/check-app-bundle.sh <Peek.app> [--distribution]` checks a built app
  for the manifest, the encryption key, every usage description and the
  sandbox entitlements. CI runs it on every pull request against the unsigned
  Debug build; `scripts/release.sh` and `scripts/app-store.sh` run it with
  `--distribution` on the signed build.
* `scripts/app-store.sh` archives Peek, exports a signed `.pkg` for the Mac
  App Store with cloud-managed signing, verifies the installer and app
  signatures, the embedded provisioning profile and the bundle, and with
  `UPLOAD=1` uploads the build to App Store Connect for TestFlight.
* `.github/workflows/app-store.yml` runs that script on demand only (Actions >
  App Store > Run workflow, with an "Upload" switch). It never runs on tags or
  pushes and never submits for review.
* `.github/workflows/release.yml` and `scripts/release.sh` keep producing the
  Developer ID DMG on a `v*` tag. `release.sh` now forces manual signing for
  the Developer ID identity (the target uses automatic signing, which
  `xcodebuild` refuses to combine with an explicit identity) and runs the
  bundle check.

## Decisions that stay with the owner

* **App name.** App Store names are unique across the store and "Peek" alone
  is very likely taken. Drafts below use "Peek: Calendar in Menu Bar"; App
  Store Connect tells you at once whether a name is free when you create the
  app record.
* **Bundle ID.** The project uses `com.peek.app`. If the Developer portal
  refuses it, register one under a domain you control and either change
  `PRODUCT_BUNDLE_IDENTIFIER` in the project (preferred, one value for both
  channels) or set the repository variable `PEEK_BUNDLE_ID` for the App Store
  workflow only. Changing it moves Peek to a new sandbox container, so
  preferences, the context-folder choice and the keychain API key start fresh.
  External tools that run `Peek --export` call the app by path, so they are
  not affected.
* **Price and availability.** Free, paid, or free with a later paid tier.
  This also decides whether you need the Paid Apps agreement and tax and
  banking forms in App Store Connect.
* **Category.** `Info.plist` says Utilities. Productivity fits the meeting
  brief better and has more relevant neighbours; App Store Connect lets you
  pick primary and secondary independently of the plist.
* **Privacy label stance.** See "App Privacy answers" below. I recommend the
  conservative answer.
* **Copyright line, support URL and privacy policy URL.** The privacy policy
  URL is mandatory. A draft text is at the end of this page.

## Apple-side steps (one time)

All of these happen in the browser or Xcode on your Mac. None of the values go
in chat or in the repository.

1. Confirm the Apple Developer Program membership is active for team
   `RY7ZAZ3QN9` (the team set in the project). Agreements, Tax, and Banking in
   App Store Connect must show the Free Apps agreement as active; add the Paid
   Apps agreement if Peek will be paid.
2. developer.apple.com > Certificates, IDs & Profiles > Identifiers > + > App
   IDs > App. Platform macOS, explicit bundle ID (`com.peek.app` or your
   replacement). No extra capabilities are needed: App Sandbox, Calendars,
   Contacts, user-selected files and outgoing network are entitlements, not
   portal capabilities.
3. appstoreconnect.apple.com > Apps > + > New App. Platform macOS, the name,
   primary language English (U.S.), the bundle ID from step 2, any SKU (for
   example `peek-mac`), full access.
4. App Store Connect > Users and Access > Integrations > App Store Connect API
   > Team Keys > +. Name it "Peek CI", role **Admin** (cloud-managed signing
   needs it to create the Apple Distribution and Mac Installer Distribution
   certificates and the Mac App Store profile). Download the `.p8` (only
   possible once) and note the Key ID and the Issuer ID shown above the list.
5. GitHub > acattelan77/peek > Settings > Secrets and variables > Actions >
   New repository secret, or `gh secret set` from Terminal:

   ```bash
   gh secret set APPLE_TEAM_ID --body "RY7ZAZ3QN9"
   gh secret set APP_STORE_CONNECT_KEY_ID          # paste the Key ID
   gh secret set APP_STORE_CONNECT_ISSUER_ID       # paste the Issuer ID
   base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | gh secret set APP_STORE_CONNECT_API_KEY_P8
   ```

   Then delete the `.p8` from Downloads and keep it in your password manager.

### Developer ID DMG secrets (still missing)

Run 45256846181 failed at "Install Apple signing certificate" because these
are not set. Developer ID certificates can only be created by the Account
Holder.

1. Xcode > Settings > Accounts > your team > Manage Certificates > + >
   Developer ID Application.
2. Keychain Access > login > My Certificates > "Developer ID Application: …"
   > right-click > Export > `.p12` with a strong password.
3. `security find-identity -v -p codesigning` prints the exact identity
   string, for example `Developer ID Application: Name (RY7ZAZ3QN9)`.
4. account.apple.com > Sign-In and Security > App-Specific Passwords >
   create one named "Peek notarization".
5. Set the secrets:

   ```bash
   base64 -i ~/Desktop/DeveloperID.p12 | gh secret set APPLE_DEVELOPER_ID_CERTIFICATE
   gh secret set APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD   # the .p12 password
   gh secret set APPLE_DEVELOPER_IDENTITY                  # string from step 3
   gh secret set APPLE_ID                                  # your Apple ID email
   gh secret set APPLE_APP_SPECIFIC_PASSWORD               # from step 4
   openssl rand -base64 24 | gh secret set KEYCHAIN_PASSWORD
   ```

   `APPLE_TEAM_ID` is shared with the App Store workflow.
6. Test it with Actions > Release > Run workflow (a dispatch builds and
   uploads the DMG artifact but creates no GitHub Release). A public release
   still needs a `v*` tag, which only you push.

## Running the pipelines

* **App Store / TestFlight:** Actions > App Store > Run workflow. Leave
  "Upload" off for the first run to check signing and the package; turn it on
  to send the build to TestFlight. Locally: `APPLE_TEAM_ID=… ASC_KEY_ID=…
  ASC_ISSUER_ID=… ASC_KEY_PATH=~/keys/AuthKey_….p8 UPLOAD=1
  ./scripts/app-store.sh`.
* **Developer ID DMG:** push a `v<version>` tag on `main` after CI is green,
  or run `./scripts/release.sh` on your Mac with the same values exported.
* Every upload needs a build number App Store Connect has not seen. Use
  `scripts/bump-version.sh` as for any release; `manageAppVersionAndBuildNumber`
  is off so the store build always matches `Configuration/Version.xcconfig`.

## Sandbox entitlements review

The target is already sandboxed with the Hardened Runtime. Each entitlement
maps to one feature, and nothing Peek does needs more:

* `app-sandbox`: required for the Mac App Store.
* `personal-information.calendars`: EventKit read access for the menu bar,
  alerts and the `--export` CLI. Full Access is requested because Peek reads
  events from every selected calendar.
* `personal-information.addressbook`: opt-in Contacts matching for attendee
  roles (PEEK-211). Off until the user turns it on.
* `files.user-selected.read-only` plus `files.bookmarks.app-scope`: the 42
  context folder picked in Preferences, kept across launches with a
  security-scoped bookmark (`ContextFolderStore`). Peek only reads
  `peek-context.json`, so read-only is enough.
* `network.client`: only the optional Claude brief to `api.anthropic.com`
  with the user's own key.

Checked and needing no entitlement: user notifications, `SMAppService` launch
at login (only from the Preferences switch, never by default), Carbon global
hotkeys, the keychain item for the API key, the brief cache in the app's
container, Foundation Models, and opening join links or the Zoom and Teams
apps through `NSWorkspace`. `get-task-allow` is rejected by the scripts in
distribution builds.

Pending, for PEEK-272: reminders for meetings with a link or attendees set
`interruptionLevel = .timeSensitive`, but they only break through Focus once the
target carries `com.apple.developer.usernotifications.time-sensitive`. That is a
`com.apple.developer` entitlement: it needs the Time Sensitive Notifications
capability on the App ID and a provisioning profile, and an ad-hoc build that
claims it without a profile may not launch. Add it to `Peek.entitlements` in
the same change that sets up App Store and Developer ID provisioning, then
check on TestFlight that a reminder arrives during a Focus with Peek allowed
to send time-sensitive notifications.

One thing to verify on TestFlight: external tools (for example a LaunchAgent)
run `/Applications/Peek.app/Contents/MacOS/Peek --export …`. A sandboxed App Store
binary run that way keeps its sandbox and calendar grant, so this should work
unchanged, but it has only been tested with the DMG build.

## Export compliance

Peek's only encryption is HTTPS through `URLSession` (to `api.anthropic.com`)
and the operating system's keychain; the SHA-256 cache fingerprint is hashing,
not encryption. That is exempt, so `ITSAppUsesNonExemptEncryption` is `NO`. If
App Store Connect asks anyway, answer that the app uses encryption only through
Apple's operating system (exempt), with no proprietary or non-standard
algorithms. No French encryption declaration is needed for exempt use.

## App Privacy answers (App Store Connect > App Privacy)

Peek has no server, analytics, ads or third-party SDKs, and sends nothing to
its developer. Calendar, Contacts and the context file are processed on the
Mac, which Apple does not count as collection. The one exception is the
optional Claude brief: after a consent screen, the meeting title, cleaned
invitation text, context notes and up to eight attendee names with role and
company go to Anthropic under the user's own API key (ADR 0005).

**Recommended (conservative), matching the privacy manifest:** "Yes, we
collect data", with

* User Content > Other User Content: App Functionality; not linked to the
  user's identity; not used for tracking.
* Contacts: App Functionality; not linked; not used for tracking.

Apple counts data sent to third parties that keep it beyond the request, and
Anthropic's API retention puts this case inside the definition. The optional
disclosure exception does not fit because briefs can run for every meeting.

**Alternative:** "Data Not Collected", arguing that the user contracts
directly with Anthropic and Peek never receives the data. It reads better on
the product page but is easier to challenge in review. If you pick it, remove
`NSPrivacyCollectedDataTypes` entries from the manifest so the two agree.

## App Store metadata drafts (English)

* **Name (30):** Peek: Calendar in Menu Bar
* **Subtitle (30):** Never miss a meeting again
* **Promotional text (170):** See your next meeting at a glance, join it in
  one click, and walk in knowing who you're about to meet. Briefs are written
  on your Mac unless you choose Claude.
* **Keywords (100):** meeting,zoom,teams,google meet,join,reminder,agenda,schedule,countdown,world clock,time zone,brief
* **Description:**

  > Peek lives in your menu bar and keeps your day in view, using the calendars
  > you already have in the macOS Calendar app.
  >
  > Your next meeting, always in sight. A countdown in the menu bar turns
  > orange and then red as a meeting gets close. Open Peek to see today's
  > agenda, a month view and the details of every event: notes without the
  > invitation boilerplate, attendees and their replies, and the meeting link.
  >
  > Join in one click. Peek recognises Zoom, Google Meet, Microsoft Teams,
  > Webex, GoTo, Slack, Chime, Jitsi, FaceTime, RingCentral and more, and opens
  > Zoom or Teams in their own app when it is installed. Press ⌃⌥J anywhere to
  > join the meeting that is starting now.
  >
  > Alerts you can't miss. Choose a gentle heads-up card or a full-screen alert
  > that appears over every Space and full-screen app, by default only for
  > meetings with a link or with people in them.
  >
  > Know who you're meeting. With your permission, Peek matches attendees with
  > your Contacts to show their role and company: "You're about to meet Ada,
  > CEO of Northwind." It can also read meeting notes that another app of
  > yours writes into a folder you choose.
  >
  > A brief before you walk in. Turn on meeting briefs and Peek prepares three
  > to five points on what to prepare, fifteen minutes before the meeting.
  > Briefs are written on your Mac with Apple Intelligence, or by Claude with
  > your own Anthropic API key after you see exactly what is sent. Briefs are
  > off until you turn them on.
  >
  > Across time zones. Keep up to six world clocks under the header and see
  > each meeting's time in those cities.
  >
  > Private by design. Peek has no account, no server, no analytics and no
  > ads. Your calendar stays on your Mac.
  >
  > Available in English, Italian, German, French and Spanish.

* **What's new (first release):** First release on the Mac App Store.
* **Review notes:**

  > Peek is a menu-bar app (no Dock icon): click the calendar icon in the menu
  > bar. It needs Calendar access to show events; add any event with a Zoom or
  > Meet link starting in a few minutes to see the countdown, the join button
  > and the start alert. Contacts access is optional (a switch in Preferences).
  > Network access is used only for the optional "Written by Claude" brief,
  > which requires the user's own Anthropic API key and a consent screen; it is
  > off by default and the rest of the app works without it. On-device briefs
  > need macOS 26 with Apple Intelligence. No account or login exists.

* **Age rating:** none of the content questions apply; expect 4+.
* Localized metadata for Italian, German, French and Spanish can follow the
  English copy once it is approved, matching the app's localizations.

## Screenshots plan

Mac screenshots must be 16:10 at 1280×800, 1440×900, 2560×1600 or 2880×1800;
one to ten per localization. Plan five at 2880×1800, captured on a demo
account with fictional calendars and people (never real meetings or contacts),
light appearance first, with a short caption bar above each:

1. Menu bar with the "8m - Ada" countdown and the open popover: "Your next
   meeting, always in sight."
2. Expanded meeting page with attendees, roles and the Join button: "Know who
   you're meeting."
3. Full-screen start alert over a full-screen app: "Alerts you can't miss."
4. The brief in the meeting page with "Written on this Mac": "A brief before
   you walk in."
5. World clocks and the meeting's time in other cities, in dark appearance:
   "Across time zones."

The UI must be final first, so capture after the mockup alignment (PEEK-241, 1.11.0)
passes its checks in `docs/MAC_CHECKS.md`.

## TestFlight plan

1. After the Apple-side steps, run the App Store workflow with Upload off;
   fix anything the package checks report.
2. Run it with Upload on. Processing in App Store Connect usually takes
   minutes to an hour; the export-compliance answer is preset by the plist.
3. Internal testing (no Beta App Review): add yourself to an internal group
   and install TestFlight from the Mac App Store on both Macs. The TestFlight
   build replaces the DMG install, because both use the same bundle ID.
4. Checks on each Mac, ideally first on a fresh macOS user account:
   * first launch, calendar Full Access prompt, denied access and recovery;
   * Contacts opt-in and attendee roles;
   * pick the context folder, quit, relaunch: the folder is still read
     (security-scoped bookmark), a brief from the file appears;
   * any external tool that runs `--export` still gets its JSON from the
     TestFlight build;
   * on-device brief on macOS 26, Claude brief with your key and the consent
     screen;
   * the API key saved under the DMG build is still found, or can be entered
     again (the keychain item belongs to a differently signed app);
   * launch at login, ⌃⌥J join, start alert over a full-screen app, world
     clocks, menu-bar countdown;
   * VoiceOver pass on the popover and Preferences.
5. Optional external group (needs a short Beta App Review) for a few trusted
   colleagues before the public release.
6. Submission (owner): fill metadata, screenshots, privacy answers, price,
   then "Add for Review".

## Privacy policy draft

> Peek does not collect, store or share your personal data on any server. It
> has no account, analytics, advertising or tracking.
>
> Peek reads your calendars, and, if you allow it, your Contacts and a folder
> you choose, only on your Mac to show your meetings. Briefs and settings are
> stored in Peek's own container on your Mac.
>
> If you turn on briefs written by Claude and enter your own Anthropic API
> key, Peek sends Anthropic the meeting title, the invitation text without
> links or addresses, notes from your context folder, and the names, roles and
> companies of up to eight attendees, to write the brief. This happens only
> after you accept a screen listing these fields. Anthropic processes that
> request under your agreement with Anthropic. Your API key stays in your
> Mac's keychain.
>
> Contact: <owner's support email or page>.
