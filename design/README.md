# Design sources

* `brand/`: the app-icon master (`peek-app-icon-master.png`) and its brief. The
  app-icon sizes and the menu-bar template glyph are generated from it with
  `scripts/generate-assets.swift`; see `brand/README.md`.
* `handoff-v1/`: the original "calm glance" design handoff (July 2026): an HTML
  prototype, its screenshots and a token spec. It is a historical reference for
  tokens, onboarding, the Starting now card and the icon. Layout now follows the
  Peek 2.0 mockup canvas, and colors follow `docs/DESIGN_SYSTEM.md` and the code,
  which corrected several handoff values for contrast in 1.6.0.

The living specification is `docs/DESIGN_SYSTEM.md`; the source of truth for
values is `Peek/Sources/Presentation/DesignSystem/`.
