# Art Rework Test 10 — Calibration-Led Daylight

This pass corrects the daytime direction. The three approved calibration references now define the noon appearance:

- natural cream and plaster instead of neon-tinted walls;
- warm wood, brass and stone materials;
- clear sky blue, turquoise water and glass;
- natural green plants and upholstery;
- restrained coral and lavender accents;
- dark, separated outlines and shadows that keep objects readable.

The neon Miami night palette remains exclusive to the midnight images.

## Geometry and detail

Every noon image is derived from the exact Test 04 midnight master through a reversible 40-color lookup table. No scene pixels were moved, redrawn, masked, resized, blurred or resampled. Objects, reflections, architectural lines, gameplay areas and animation anchors occupy identical pixels in both versions.

The daytime palette additionally preserves strong brightness steps between neighboring colors so object boundaries do not visually merge.

## Files

- `noon/` — 18 calibration-led daylight endpoints.
- `midnight/` — 18 byte-identical Test 04 neon night masters.
- `day_night_contact_sheet.png` — paired review sheet.
- `noon_contact_sheet.png` and `midnight_contact_sheet.png` — phase overviews.
- `calibration_refs/` — the approved daytime appearance targets.
- `palette_maps.json` — reversible environment-specific lookup tables.
- `validation_report.json` — alignment and contrast results.
- `transition_plan.md` — drift-free animation plan.
- `build_geometry_locked_day.py` — reproducible daylight build.

These are review assets. Production game files have not been overwritten.
