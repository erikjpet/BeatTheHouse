# Test 04 prompt set

Mode: built-in image generation, with current in-game captures used as coordinate and occupancy references.

## Shared production brief

Create an exact 900:430 game environment background using an original city-pop landscape vocabulary and a restrained Miami-night/vaporwave palette. Use deep ultramarine structure, black-violet shadow masses, cyan light, selective magenta/coral planes, amber practical light, broad horizontal composition, calm negative space, and simplified low-resolution painterly shapes. Preserve the supplied runtime coordinates by building empty shelves, counters, risers, alcoves, doorways, rugs, stages, or floor pads beneath them. Do not imitate a specific artwork. Do not include UI, labels, arrows, runtime games, game tables, machines, cards, chips, items, event icons, characters, particles, or animated effects.

## Environment-specific scene briefs

- `corner_store`: inland convenience store; five shelf bays, checkout, two services and right street exit.
- `back_alley`: rainy inland service alley; three-position vendor table, clerk awning, side niches.
- `motel`: boulevard motel office; reception, five item landings, merchant and service stations.
- `bar`: worn inland dive; long counter, distinct game bays, booth and empty right cabinet alcove.
- `gas_station_casino`: highway mini casino; three empty wall bays, lower machine zone, service counter and camera path.
- `small_underground_casino`: low basement; two broad felt stages, empty right machine recess and left drink cart.
- `jazz_club`: downtown high-rise; sax, bass and drums silhouettes, service aprons, bar and empty pull-tab alcove.
- `kitty_cat_lounge`: ornate city cabaret; stage, booths, champagne bar and three distinct game zones.
- `delta_queen`: riverboat salon; three empty game stations, deck threshold and visible river/city.
- `beach`: colorful coastal boardwalk; empty arcade pavilion, recovery chaise, sand zone and exit.
- `pawn_shop`: inland barred shop; six display pads, central glass counter and empty machine alcove.
- `grand_casino`: coastal atrium; six empty upper game bays, host station, lower pads and three portals.
- `grand_casino_high_limit`: private jade/aubergine penthouse; three empty game stages, no reused main-floor theme.
- `grand_casino_back_room`: internal executive noir; one central confrontation zone and return door.
- `grand_casino_cage`: secure mint/magenta cashier room; teller, gift case, ATM and return door zones.
- `motel_room`: roadside bedroom; sleep, storage, containers, bags, upgrade and exit furniture.
- `apartment`: mid-rise city home; sleep alcove, cubbies, storage, workbench, rent and exit zones.
- `house`: inland modernist home; sleep suite, shelves, three container pads, trade-up and exit zones.

## Post-processing brief

Resize each generated source to 450 × 215, slightly reinforce saturation and contrast, quantize to 40 colors without dithering, then scale to 900 × 430 using nearest-neighbor interpolation. This reduces generated micro-texture and restores the game's larger pixel-shape language.
