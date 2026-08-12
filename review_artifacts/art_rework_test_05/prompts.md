# Test 05 Prompt Direction

## Shared refinement brief

Use case: style-transfer

Asset type: production 2D game environment background

Preserve the supplied layout, camera, architecture, openings, platform edges, interaction bays, object staging zones, and gameplay-safe negative space. Redraw the scene as an original, deliberately simplified city-pop architectural illustration.

Use broad opaque painted shapes, nearly flat fills, at most two tonal values per material, crisp geometric edges, one or two large clean shadow masses, sparse highlights, and calm negative space. The result should feel closer to a hand-painted album-cover background or screen-printed gouache illustration than rendered concept art.

Deep blue, pink, and magenta are anchors only, never a global tint. Every material keeps its believable local color. Useful scene colors include ivory, mint, jade, teal, coral, tomato red, mustard yellow, brass gold, warm natural wood, terracotta, leafy green, lavender, sky blue, and concrete gray.

Remove pixel speckling, surface grain, texture maps, glossy reflections, bloom, complex gradients, tiny trim, excessive props, photoreal materials, 3D-render shading, and volumetric light. Keep dark areas readable.

Preserve every empty gameplay slot and spatial landmark. Do not add characters, machines, tables, game icons, labels, cards, chips, text, watermarks, or borders.

## Location palette briefs

- `apartment`: ivory, pale peach, honey wood, coral bedding, leafy green, brass yellow, cobalt night, mint, and lavender.
- `back_alley`: terracotta brick, teal doors, mustard awning, green dumpsters, cream work light, cobalt night, and restrained coral.
- `bar`: walnut, cream, bottle green, amber glass, oxblood seating, jade felt, brass, turquoise, and restrained magenta.
- `beach`: azure water, aqua sky, coral horizon, cream architecture, lemon yellow, terracotta, green palms, white sand, and lavender.
- `corner_store`: cream, pale mint, natural wood, tomato red, mustard, jade, cobalt, lavender, and coral product blocks.
- `delta_queen`: ivory, navy, teal water, oxblood carpet, bottle green, mahogany, brass, coral sunset, and pale yellow.
- `gas_station_casino`: cream, turquoise, red-orange, mustard, mint, jade, cobalt night, and restrained magenta.
- `grand_casino`: ivory, turquoise, cobalt, coral, lemon, brass, jade, terracotta, lavender, and selective magenta.
- `grand_casino_back_room`: deep teal, cream, walnut, muted red, ochre, brass, cobalt, and limited magenta.
- `grand_casino_cage`: cream stone, teal panels, brass bars, coral door, jade display bays, black-blue, lavender, and restrained terrazzo accents.
- `grand_casino_high_limit`: jade lacquer, ivory, dark walnut, aubergine, coral, brass, cobalt, and turquoise.
- `house`: cream plaster, pale aqua, honey and walnut furniture, coral, mustard, jade, lavender, terracotta, and cobalt.
- `jazz_club`: cobalt skyline, cream spotlights, walnut, bottle green, amber, burnt orange, brass, jade, burgundy, and selective magenta.
- `kitty_cat_lounge`: coral curtains, cream, blush, teal, emerald, mustard gold, lavender, walnut, terracotta, and selective magenta.
- `motel`: pale turquoise, cream, coral, mustard, mint, natural wood, lavender, tomato red, and cobalt.
- `motel_room`: pale peach, coral, cream, oak, mustard, jade, lavender, turquoise, and cobalt.
- `pawn_shop`: cream, pale mint, walnut, jade, mustard, coral, turquoise, brass, cobalt, and lavender.
- `small_underground_casino`: concrete gray, cream, jade, tomato red, mustard, teal, cobalt, coral, magenta, and lavender.

## Output treatment

The built-in ImageGen sources are center-cropped to the 900:430 game ratio and downsampled with high-quality antialiasing to exactly 900 × 430 RGB PNG. No final global color quantization or blue-magenta grading is applied.
