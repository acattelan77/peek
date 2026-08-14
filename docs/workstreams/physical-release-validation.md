# Physical release validation

- **Status:** Blocked
- **Roadmap ID:** PEEK-AUD-07
- **Owner:** Codex
- **Scope:** Execute physical macOS checks that cannot be established by unit tests: menu-bar/popover behavior, permissions, notifications, VoiceOver, contrast, motion, displays, and macOS 13 compatibility.
- **Evidence attempted:** On 2026-08-14, Computer Use `get_app_state` timed out (server error `-10005`) while opening the unsigned Debug accessory app. No UI element was clicked; no permission, setting, installed app, or Northwind Notes integration changed.
- **Blocking condition:** This desktop environment cannot inspect the macOS accessory menu-bar app, and no representative macOS 13/notched/external-display hardware or clean release-validation account is currently available.
- **Required authority/dependencies:** A user-authorized test account with Calendar Full Access and notification permission, physical macOS 13 plus representative notched/external display hardware, and a signed/notarized candidate for Gatekeeper checks.
- **Exact next action:** On the authorized hardware, follow `docs/RELEASE.md` and verify Calendar Full Access grant/deny/revoke recovery; notification allow/deny and delivery; menu-bar visibility, compact transitions, and popover anchoring on crowded/notched/external displays; hotkey behavior; VoiceOver focus/order; Increased Contrast; Reduce Motion; and clean-account Gatekeeper launch.
