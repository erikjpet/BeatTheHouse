# Art Rework Test 03 — Environment Direction

This pass contains three game-ready environment candidates built around an original retro coastal-city direction: deep blue architecture, coral sunset light, distant urban detail, reflected color, and quieter foreground shapes.

## Files

- `environments/beach.png` — 900 × 430 RGB PNG
- `environments/jazz_club.png` — 900 × 430 RGB PNG
- `environments/grand_casino.png` — 900 × 430 RGB PNG
- `in_game_previews/` — captures of each candidate inside the current game with live object overlays
- `prompts.md` — the generation and integration brief

## Integration contract

- Every candidate matches the existing 900 × 430 environment canvas exactly.
- The scenes preserve the current interaction layout and leave the runtime object zones readable.
- These files are backgrounds only. Interactive objects, labels, arrows, characters, particles, highlights, and selection effects are not baked into them.
- Grand Casino contains no gaming-table icons, slot-machine icons, card icons, chips, or characters. The game supplies all of those at runtime.
- The controlled 64-color palette retains more atmospheric city detail than Test 02 while still fitting the game's low-resolution output.

## Runtime animation considerations

- Beach leaves room for the moving wave lines and boat, the upper-right sign pulse, sparkles, and floor sheen.
- Jazz Club leaves room for the two sign pulses, smoke bands, cymbal shimmer, pull-tab screen light, sparkles, and floor sheen.
- Grand Casino leaves room for the overhead light pulses, three security-camera beams, the watched badge, marquee pulse, sparkles, and floor sheen.

The current production art has not been overwritten; this remains a separate review set.
