# Art Rework Test 09 — Geometry-Locked Day/Night Pair

This review set updates every daytime environment to retain the full detail density of the approved Test 04 night artwork.

## Contents

- `noon/` — 18 daytime endpoints.
- `midnight/` — 18 byte-identical copies of the approved Test 04 night masters.
- `day_night_contact_sheet.png` — all day/night pairs side by side.
- `noon_contact_sheet.png` and `midnight_contact_sheet.png` — phase-specific overviews.
- `palette_maps.json` — the exact 40-color midnight-to-noon lookup table for each environment.
- `day_night_manifest.json` — game-facing asset inventory and validation status.
- `transition_plan.md` — the proposed drift-free day/night animation method.
- `calibration_refs/` — visual palette studies only; these are not game-ready assets.

## Alignment guarantee

The noon graphics were not redrawn. Each one was created from its matching Test 04 night master by replacing each of its 40 colors with exactly one daytime color. No pixels were moved, resized, masked, repainted, blurred, or resampled.

This preserves every object silhouette, reflection, texture, empty gameplay area, and architectural feature at the exact same coordinates. The mapping is bijective and reversible: applying the inverse daytime palette reconstructs the night pixels exactly.

## Technical profile

- 18 day/night environment pairs
- 900 × 430 pixels per endpoint
- RGB PNG
- 40 unique colors per endpoint
- 450 × 215 logical art grid displayed at 2× nearest-neighbor scale
- Test 04 night masters preserved byte for byte
- Noon and midnight differ only by color values

These are review artifacts and do not overwrite production game assets.
