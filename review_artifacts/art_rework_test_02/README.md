# Art Rework Test 02 — Production-Scale Pass

This pass is built against the real Beat The House art contracts and scene layouts. The current production files remain untouched.

## Production contracts

- Environment backgrounds: `900 × 430`, opaque PNG, first-person venue view.
- Inventory icons: `32 × 32`, transparent hard-edge pixel PNG.
- Character candidate: `64 × 96`, transparent hard-edge pixel PNG.

## Environments

- `environments/beach.png`
- `environments/jazz_club.png`
- `environments/grand_casino.png`

The replacements retain the current camera and functional zones. The Beach preserves the towel, umbrella, sign and upper-right slot kiosk while leaving the recovery, sand-pile and exit zones clear. The Jazz Club preserves the three-player stage, right-side bar/pull-tabs area and open lower interaction field. The Grand Casino preserves its left/right gaming masses, upper machine zones, center aisle and lower service/travel field.

The `in_game_previews` folder shows each candidate rendered inside the real game with current objects, characters, labels, effects and hit-region presentation. The `reference_capture` folder records the unmodified scenes used for comparison.

## Items

- `items/cheap_sunglasses.png`
- `items/thermos_black_coffee.png`
- `items/marked_cards.png`
- `items/lucky_keychain.png`
- `items/neon_players_charm.png`

These use the exact production filenames, dimensions and transparency contract.

## Character

- `characters/pal_tutorial_guide.png`

Pal is supplied at compact production pixel scale and preserves his authored palette and cap silhouette. Unlike environment and item art, the current game renders characters procedurally and has no raster-character asset slot. This sprite is therefore visually production-sized but needs a one-time renderer/manifest hook before character art can become literal drag-and-drop replacements.

## Deployment mapping

- `environments/jazz_club.png` → `assets/art/environments/jazz_club.png`
- `environments/grand_casino.png` → `assets/art/environments/grand_casino.png`
- Each item maps to the same filename under `assets/art/items/`.
- The Beach currently uses procedural fallback art and has no external background entry. Its candidate is ready at the correct contract, but `beach` needs a one-time external-art path before future Beach replacements become file-only swaps.

Exact generation briefs and processing notes are in `prompts.md`.
