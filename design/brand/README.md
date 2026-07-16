# Peek brand assets

`peek-app-icon-master.png` is the source raster for the macOS app icon. The generated asset-catalog sizes and the deterministic template menu-bar icon are produced with:

```bash
xcrun swift scripts/generate-assets.swift design/brand/peek-app-icon-master.png
```

## App-icon generation brief

- Use case: logo-brand
- Asset type: macOS application icon master
- Product: Peek, a lightweight menu-bar calendar companion for glancing at the next event
- Motif: bold calendar tile with a lower-right page/aperture fold revealing one luminous upcoming time slot; subtle eye-like negative space without a literal eye
- Style: premium modern macOS icon, restrained dimension, geometric, crisp, strong at 16 px
- Palette: deep indigo, electric blue, white, and a small warm coral next-event accent
- Constraints: no text, letters, numbers, trademarks, watermark, traffic-light controls, dense calendar grid, photorealism, thin lines, or Apple Calendar imitation

The master was generated with Codex's built-in image-generation mode from the "peek behind
the calendar" concept. Keep the checked-in master so all derived assets remain reproducible.

## Status icon

The menu-bar mark is drawn by `scripts/generate-assets.swift`, not generated independently.
It is a simplified monochrome template glyph from the same model as the app icon: page,
header mark, binding stubs, one exposed next-event slot, and lower-right fold. This
guarantees a consistent alpha template at 1x, 2x, and 3x while letting macOS provide the
final menu-bar tint.
