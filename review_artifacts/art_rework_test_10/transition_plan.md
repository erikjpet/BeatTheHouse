# Day/Night Transition Plan

The transition must animate the palette, not the picture.

Each environment uses one unchanged 40-index pixel map. At runtime, its 40 displayed colors interpolate between the daylight palette and the neon midnight palette in `palette_maps.json`. This prevents drifting edges, dissolving objects or mismatched animation anchors.

## Day cycle

| Time | State |
| --- | --- |
| 00:00–04:30 | Midnight neon palette |
| 04:30–07:00 | Neon to warm sunrise palette |
| 07:00–11:30 | Sunrise to calibration-led noon palette |
| 11:30–14:30 | Full noon palette |
| 14:30–18:30 | Noon to warm sunset palette |
| 18:30–21:00 | Sunset to midnight neon palette |
| 21:00–24:00 | Midnight neon palette |

Future sunrise and sunset variants should be intermediate 40-color palettes derived from the same index map. They must not be separately redrawn images.

Use nearest-neighbor sampling. Interpolate colors in OKLab or linear RGB to prevent gray or muddy intermediate colors.

Animated overlays must retain identical frame geometry and alpha coverage at all times. Only their palettes should change between day and night.
