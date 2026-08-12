# Drift-Free Day/Night Transition Plan

## Core rule

Use one fixed index map for each environment and animate only its 40 palette colors. Do not cross-fade two independently drawn images and do not move, regenerate, or resample any scene pixels.

Because the noon and midnight endpoints share the exact same indexed regions, every table location, doorway, window, prop, reflection, animated-element anchor, and empty gameplay area remains stationary throughout the cycle.

## Runtime approach

1. Load the geometry-locked environment image as a 40-index texture.
2. Load that environment's noon and midnight palettes from `palette_maps.json`.
3. Calculate the current daylight amount from the existing game clock.
4. Interpolate the 40 palette entries in a perceptual color space.
5. Apply the resulting palette to the unchanged index texture.

Nearest-neighbor sampling should remain enabled at every stage. The palette should be interpolated in OKLab or linear RGB rather than ordinary sRGB to avoid muddy middle colors.

## Suggested daily curve

| Game time | Palette state |
| --- | --- |
| 00:00–04:30 | Full midnight |
| 04:30–07:00 | Midnight to sunrise |
| 07:00–11:30 | Sunrise to noon |
| 11:30–14:30 | Full noon |
| 14:30–18:30 | Noon to sunset |
| 18:30–21:00 | Sunset to midnight |
| 21:00–24:00 | Full midnight |

Sunrise and sunset do not need new drawings. They should be generated later as intermediate 40-color palettes derived from these same endpoints, with warm coral/gold emphasis at sunrise and violet/magenta emphasis at sunset.

## Animated elements

Animated overlays must use the same fixed anchors in both phases. Their day/night variants should follow the same principle: identical frame geometry and alpha coverage, with palette changes only. This applies to water shimmer, signs, window lights, rain/reflections, fans, smoke, curtains, and any environmental props animated by the game.

## Verification gate for future frames

Every generated sunrise, afternoon, sunset, or dusk palette must pass these checks before integration:

- image dimensions remain 900 × 430;
- the logical 2× pixel grid remains intact;
- the index assigned to every pixel is unchanged;
- all 40 colors remain uniquely mapped;
- reversing the palette reconstructs the source index image exactly;
- gameplay overlay and animation anchors remain unchanged.
