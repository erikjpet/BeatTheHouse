# Art Rework Test 07 — Corrected Neon Midnight Pass

This revision keeps the approved Test 06 noon artwork and replaces every midnight endpoint with a darker, more concentrated neon treatment.

## Correction

- Blue is now primarily a near-black shadow structure rather than a visible overall wash.
- Large surfaces fall into ink navy, aubergine, burgundy, dark natural wood, or deep local color.
- Hot pink, magenta, electric cyan, coral, and amber are concentrated around practical lights, signs, windows, fixtures, and selected architectural edges.
- Skies, water, windows, and floors no longer read as bright cyan daytime surfaces.
- Neon is limited enough to preserve calm negative space and simplified city-pop architecture.
- Noon and midnight geometry remains pixel-identical for animation.

## Asset contract

- 18 noon endpoints and 18 corrected midnight endpoints
- 900 × 430 RGB PNG
- 450 × 215 logical grid, exact 2× nearest-neighbor presentation
- Maximum 48 colors per image
- No dithering or antialiasing
- Runtime objects and animated elements remain separate
- No production files overwritten

## Review files

- `noon/` — unchanged aligned noon endpoints
- `midnight/` — corrected dark-neon endpoints
- `day_night_contact_sheet.png` — complete paired comparison
- `midnight_contact_sheet.png` — corrected night overview
- `calibration_refs/` — built-in ImageGen lighting studies used to calibrate the night balance
- `day_night_manifest.json` — endpoint mapping and schedule
- `transition_plan.md` — pixel-preserving animation plan
- `prompts.md` — corrected midnight art brief
