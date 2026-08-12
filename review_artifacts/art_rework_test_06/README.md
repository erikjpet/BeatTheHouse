# Art Rework Test 06 — Noon and Midnight Environment Set

This set establishes aligned noon and midnight artwork for all 18 game environments.

## Delivered assets

- `noon/` — 18 restrained daytime backgrounds
- `midnight/` — 18 neon-night counterparts
- `day_night_contact_sheet.png` — side-by-side review sheet
- `noon_contact_sheet.png` — complete noon overview
- `midnight_contact_sheet.png` — complete midnight overview
- `source_noon/` — full-resolution built-in ImageGen noon masters
- `day_night_manifest.json` — pair mapping and transition metadata
- `transition_plan.md` — animation and future intermediate-art plan
- `prompts.md` — generation and pixel-treatment brief

## Art contract

- Display resolution: 900 × 430 RGB PNG
- Logical art grid: 450 × 215
- Scaling: exact 2× nearest-neighbor
- Maximum palette size: 48 colors per endpoint
- Dithering: disabled in the endpoint art
- Noon and midnight share identical geometry and logical pixel coordinates
- Runtime objects, games, characters, labels, particles, and interaction highlights remain separate
- No production assets or manifests were overwritten

## Day and night relationship

The noon master for each location was created with the built-in ImageGen workflow and then normalized to the shared pixel-art contract. The midnight image was derived from that exact master using a location-specific night palette and practical-light rules. It was not independently redrawn.

This alignment is essential: a time-of-day blend can change light and color without making walls, doors, furniture, or gameplay platforms shift position.

Noon uses restrained mid-value local colors rather than the previous high-key white treatment. Midnight preserves those material identities while cooling shadows, deepening skies and windows, and strengthening selected amber, cyan, coral, and magenta light sources.
