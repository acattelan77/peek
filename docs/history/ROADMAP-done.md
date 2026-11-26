# Roadmap: done and dropped

Moved out of `docs/ROADMAP.md` on 2026-11-26. When an item reaches `Done` there,
move its line here. IDs are never reused.

Integrated and validated by tests; their remaining physical checks are folded
into PEEK-AUD-07.

* **PEEK-101** notch-safe compact menu bar · **PEEK-102** fake EventKit and
  notification schedulers · **PEEK-103** UI coverage for first launch, denied
  access, empty state and Preferences · **PEEK-104** live hotkey re-registration
  · **PEEK-106** macOS 13 (partial: CI runner retired, hardware check in
  PEEK-AUD-07) · **PEEK-107** Developer ID release workflow (never run with real
  secrets) · **PEEK-108** VoiceOver labels, focus order, keyboard activation ·
  **PEEK-109** crowded-menu-bar icon fallback · **PEEK-110** event detail
  expansion (later replaced by the meeting page in PEEK-241) · **PEEK-111**
  headless calendar export (ADR 0003) · design refresh 1.3.x and app icon.
* **PEEK-AUD-01..06** audit remediation: EventKit refresh on the main thread,
  Reduce Motion pulse, notification scheduling feedback and retry, fail-closed
  release verification, documentation, bounded HUD history.

**Dropped:** PEEK-105 settings import/export feedback (the feature was removed
in 1.3.6).
