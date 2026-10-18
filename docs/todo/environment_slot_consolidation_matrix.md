# Environment slot consolidation matrix

Status: **HISTORICAL PRE-RELEASE-3 CONSOLIDATION SNAPSHOT — SUPERSEDED.**

Use `environment_scenario_slot_instance_rework.md` for the implemented model
and `../plans/environment_scenario_layout_breakdown.md` for the generated
75-context manual-placement authority.

This document records the reviewed slot authority at the pre-release-2
consolidation checkpoint. At that point, placement data had 659 physical rows
across 21 effective maps: 214 `fixed`, 147 `event`, 222 `scenario`, and 76
`exit`.

## Family contract

- `fixed.*` is guaranteed room content. These ids describe the concrete object
  or role, such as `fixed.musician_drummer`, `fixed.item_shop_1`, or
  `fixed.random_game_1` when the guaranteed position intentionally accepts a
  variable game.
- `event.*` is optional ambient content independent of the selected scenario.
- `scenario.*` was then a reusable room-wide bank for selected scenarios and
  runtime content. Current catalog scenarios instead use exact local banks.
- `exit.*` is physical travel authority for another environment or sub-room.

Reusable `event` and `scenario` ids use only these physical roles:
`standing_person`, `behind_counter_person`, `seated_person`, `group`,
`floor_fixture`, `ground_marker`, `surface_item`, `shop_item`, `wall_item`,
`hanging_item`, and `doorway`. Ordinals restart for each family, role, and map.

Every slot also declares:

- `physical_role`: concise placement-facing meaning;
- `occupant_ids`: sorted known claimants;
- `runtime_reserve`: whether non-snapshot runtime state reserves the row; and
- `reserve_reason`: required exactly when `runtime_reserve` is true.

## Before and after

Counts are `fixed/event/scenario/exit (total)`. “Before” is the pinned
`c3d55ffb` slot-schema-v2 authority used by the disposition ledger.

| Map | Before | After |
| --- | ---: | ---: |
| `apartment` | 12/0/5/3 (20) | 12/0/4/3 (19) |
| `back_alley` | 15/9/12/4 (40) | 15/9/12/4 (40) |
| `bar` | 9/9/23/4 (45) | 7/9/18/4 (38) |
| `beach` | 3/0/18/3 (24) | 3/0/17/3 (23) |
| `corner_store` | 17/6/11/4 (38) | 17/6/12/4 (39) |
| `delta_queen` | 19/13/26/4 (62) | 19/13/16/4 (52) |
| `gas_station_casino` | 9/11/26/3 (49) | 5/11/19/3 (38) |
| `grand_casino` | 16/11/18/6 (51) | 14/11/13/6 (44) |
| `grand_casino_back_room` | 2/5/4/3 (14) | 2/5/4/3 (14) |
| `grand_casino_cage` | 7/0/5/4 (16) | 7/0/5/4 (16) |
| `grand_casino_high_limit` | 4/7/4/4 (19) | 4/7/4/4 (19) |
| `house` | 12/0/5/3 (20) | 12/0/4/3 (19) |
| `jazz_club` | 12/6/16/3 (37) | 9/4/12/1 (26) |
| `kitty_cat_lounge` | 13/9/17/4 (43) | 13/9/14/4 (40) |
| `motel` | 18/10/19/4 (51) | 18/10/15/4 (47) |
| `motel_room` | 12/0/5/3 (20) | 12/0/4/3 (19) |
| `pawn_shop` | 12/6/9/4 (31) | 12/6/11/4 (33) |
| `small_underground_casino` | 8/15/9/4 (36) | 8/15/5/4 (32) |
| `small_underground_casino:back_room` | 8/12/5/3 (28) | 8/12/4/3 (27) |
| `small_underground_casino:casino` | 11/11/17/4 (43) | 11/11/15/4 (41) |
| `small_underground_casino:club` | 6/9/16/4 (35) | 6/9/14/4 (33) |

## Pull Tabs and physical game rows

Pull Tabs, its clerk, and ticket redemption no longer own standalone physical
rows in Bar, Gas Station Casino, Jazz Club, or Grand Casino. Runtime conditionally
adds those actions to each venue's configured staffed counter only when Pull
Tabs is selected. Grand uses `casino_fixture:host_desk` at
`fixed.fixture_host_desk`.

The authored physical game-position counts are Bar 2, Gas Station Casino 2
(one shared optional-game row plus Scratch Tickets), Jazz Club 0, and Grand
Casino 6 (four machines plus two tables).

## Audit and authoring handoff

`environment_slot_consolidation_disposition.json` accounts for every one of the
722 pinned source rows as keep, rename, merge, or remove and records all 659
targets. Its collision policy is `prefer_exact_target_then_source_order`, which
is also used by the placement-report translator.

The current coordinates are deterministic carryovers or provisional clones.
They are intentionally ready for manual adjustment with the placement tool;
moving them does not change their lifecycle family or capacity contract. Legacy
saves are not supported and should regenerate their environments under these
rules.
