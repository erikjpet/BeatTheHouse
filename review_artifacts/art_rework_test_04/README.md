# Art Rework Test 04 — Complete Environment Pass

This review set contains a unique candidate background for every one of the game's 18 environment archetypes. The direction combines a restrained city-pop landscape grammar with a brighter Miami-night/vaporwave palette while keeping the current gameplay coordinates and animated overlay system intact.

## Production contract

- 18 unique RGB PNG backgrounds
- Exact size: 900 × 430
- Controlled 40-color palette
- Built from 450 × 215 working shapes and scaled 2× without interpolation
- Background architecture only: runtime games, items, services, events, characters, labels, arrows, highlights, particles, and animated effects remain separate
- No production assets or manifests were overwritten

## Environment set

| Environment | Setting | Built-in object staging | Water use |
|---|---|---|---|
| `corner_store` | Inland neon convenience store | Five shelf bays, checkout, service counter, street exit | None |
| `back_alley` | Rainy downtown service alley | Three-pad vendor table, clerk awning, side niches | Reflections only |
| `motel` | Inland boulevard motel lobby | Reception, five item pads, vending/service alcove | None |
| `bar` | Inland neighborhood dive | Long bar, cabinet niche, table bay, pool-room recess | None |
| `gas_station_casino` | Highway-edge converted gas station | Three machine recesses, lower bay, service counter | Wet pavement only |
| `small_underground_casino` | Downtown basement casino | Two broad game stages, right machine alcove, drink cart | None |
| `jazz_club` | High-rise downtown jazz room | Three musician stations, bar/merchant, pull-tab alcove | Distant horizon only |
| `kitty_cat_lounge` | Ornate city cabaret | Stage, booths, three game zones, champagne bar | None |
| `delta_queen` | Art-Deco riverboat casino | Three game salons, deck threshold, service console | Primary |
| `beach` | Coastal boardwalk | Arcade pavilion, recovery chaise, sand zone, exit | Primary |
| `pawn_shop` | Inland downtown pawn shop | Six display pads, central counter, machine alcove | None |
| `grand_casino` | Coastal casino atrium | Six separate game bays, host station, three portals | Primary view |
| `grand_casino_high_limit` | Jade penthouse salon | Three private game stages and two doors | Distant accent |
| `grand_casino_back_room` | Internal executive surveillance room | One focal game/event zone and return door | None |
| `grand_casino_cage` | Internal secure cashier room | Teller window, gift case, ATM recess, return door | None |
| `motel_room` | Inland roadside room | Bed, storage, luggage, upgrade and exit surfaces | None |
| `apartment` | Inland mid-rise apartment | Sleep alcove, cubbies, storage, workbench, exit | Distant horizon only |
| `house` | Inland modernist home | Sleep suite, shelving, containers, trade-up and exit zones | None |

## Review materials

- `environments/` — the 18 candidate backgrounds
- `in_game_previews/` — each candidate rendered in the current game with live overlays
- `reference_capture/` — the previous runtime layouts used for the placement audit
- `art_direction_deep_dive.md` — research findings and the translated visual rules
- `prompts.md` — the shared generation brief and environment prompt set
