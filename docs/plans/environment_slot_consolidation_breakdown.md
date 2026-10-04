# Environment slot consolidation: complete placement breakdown

Status: **HISTORICAL PRE-PRERELEASE-3 MIGRATION SNAPSHOT — DO NOT USE FOR THE
MANUAL PLACEMENT PASS.**

> **Supersession note (scenario placement):** This document remains the raw
> four-family migration and source-template audit, but its description of one
> reusable map-wide `scenario.*` bank is no longer the effective catalog
> runtime model. Catalog scenarios now use exact per-scenario banks from
> `data/environments/scenario_slot_layouts.json`; ordinary raw scenario slots
> in `placement_surfaces.json` are filtered out, while explicit runtime
> reserves remain shared. The eight maps without catalog layouts keep their
> scenario-family slots in the sole room-shared base context. Use
> `environment_scenario_layout_breakdown.md` for the current 20-base/55-scenario
> manual-placement guide and Save Current Layout coverage.

The counts and tables below intentionally preserve the earlier consolidation
snapshot. They are not current authority. The generated scenario-layout guide
contains the live 565-row raw census and all 75 reachable save contexts.

This document answers three practical questions for every authored placement
map: what was permanent, what reusable capacity existed, and what appeared in
the manual placement tool at that checkpoint. It covers all 21 effective maps
and all 55 catalog scenarios. This document is retained as historical evidence,
not as current placement authority.

## How to read the breakdown

- `fixed.*` is permanent environment capacity. Required fixed declarations
  appear every time that environment is created; variable shop/game capacity
  remains fixed-family capacity because the position belongs to the room even
  when its selected occupant varies.
- `event.*` is reusable capacity for optional ambient events and contacts that
  are independent of the selected scenario.
- `scenario.*` is reusable capacity for physical actors, props, items, and
  controls belonging to the active scenario chain. A scenario identity claims
  a compatible position; it does not create a new placement position.
- `exit.*` is reserved for real travel between environments, rooms, or layers.
- A **runtime reserve** is retained only for a proven producer outside the
  ordinary scenario-phase snapshot. It is hidden in the normal placement view
  and has an explicit reason below.
- A slot's stable ID is authoring identity. Its marker is occupant-first at
  runtime: an occupied position shows the object's friendly label; an empty
  position shows its physical role. Known claimant IDs appear in details and
  hover text, not as extra room labels.

## What the owner sees in manual placement mode

The tool opens on the `fixed` tab only. The `fixed`, `event`, `scenario`, and
`exit` tabs are mutually exclusive, so changing family replaces the visible
markers instead of stacking another complete bank over the room. The default
view shows occupied positions plus any required position missing an occupant.
Optional empty positions remain hidden until **Empty capacity** is enabled;
runtime reserves remain hidden until **Runtime reserves** is enabled.

The current scenario and phase are shown as context. They control which
scenario positions are occupied but do not change the stable slot IDs. Overlap
warnings compare the selected position only with required, occupied, and
otherwise coexistent positions in that context. Export still includes every
locked local change, including families and empty/reserve positions hidden by
the current view.

## Complete 55-scenario index

The map column is the exact placement map selected by the scenario catalog's
environment and optional `layer_id`. Maps marked **no catalog scenarios** in
the per-map breakdown still have fixed/event/exit capacity and may carry
non-catalog runtime chains; no scenario is invented for them here.

| Placement map | Scenario ID | Player-facing label |
| --- | --- | --- |
| `corner_store` | `corner_store_delivery_day` | Delivery Day |
| `corner_store` | `corner_store_lotto_fever` | Lotto Fever |
| `corner_store` | `corner_store_aftermath` | The Aftermath |
| `corner_store` | `corner_store_dead_shift` | Dead Shift |
| `corner_store` | `corner_store_inventory_night` | Inventory Night |
| `back_alley` | `back_alley_street_craps` | Street Craps |
| `back_alley` | `back_alley_cruiser_parked` | Cruiser Parked |
| `back_alley` | `back_alley_fence_night` | Fence Night |
| `back_alley` | `back_alley_nothing_moving` | Nothing Moving |
| `motel` | `motel_conventioneers` | Conventioneers |
| `motel` | `motel_stakeout` | The Stakeout |
| `motel` | `motel_weekly_rates` | Weekly Rates |
| `motel` | `motel_wedding_overflow` | Wedding Overflow |
| `bar` | `bar_wake` | The Wake |
| `bar` | `bar_fight_night` | Fight Night |
| `bar` | `bar_payday_rush` | Payday Rush |
| `bar` | `bar_lock_in` | Lock-In |
| `bar` | `bar_darts_league_night` | Darts League Night |
| `bar` | `bar_live_band` | Live Band |
| `bar` | `bar_dead_tuesday` | Dead Tuesday |
| `gas_station_casino` | `gas_station_trucker_convoy` | Trucker Convoy |
| `gas_station_casino` | `gas_station_tour_bus_stop` | Tour Bus Stop |
| `gas_station_casino` | `gas_station_graveyard_shift` | Graveyard Shift |
| `gas_station_casino` | `gas_station_road_crew_payday` | Road Crew Payday |
| `gas_station_casino` | `gas_station_storm_shelter` | Storm Shelter |
| `small_underground_casino:club` | `punchline_open_mic_night` | Open Mic Night |
| `small_underground_casino:club` | `punchline_headliner_night` | Headliner Night |
| `small_underground_casino:club` | `punchline_bringer_show` | Bringer Show |
| `small_underground_casino:casino` | `punchline_high_stakes_night` | High-Stakes Night |
| `small_underground_casino:casino` | `punchline_greased_week` | Greased Week |
| `small_underground_casino:club` | `punchline_debt_court` | Debt Court |
| `small_underground_casino:casino` | `punchline_new_muscle` | New Muscle |
| `small_underground_casino:club` | `punchline_raid_jitters` | Raid Jitters |
| `jazz_club` | `jazz_club_guest_legend` | Guest Legend |
| `jazz_club` | `jazz_club_rent_party` | Rent Party |
| `jazz_club` | `jazz_club_recording_night` | Recording Night |
| `jazz_club` | `jazz_club_union_trouble` | Union Trouble |
| `kitty_cat_lounge` | `kitty_cat_lounge_amateur_night` | Amateur Night |
| `kitty_cat_lounge` | `kitty_cat_lounge_buyout` | The Buyout |
| `kitty_cat_lounge` | `kitty_cat_lounge_slow_night` | Slow Night |
| `kitty_cat_lounge` | `kitty_cat_lounge_bachelorette_storm` | Bachelorette Storm |
| `delta_queen` | `delta_queen_wedding_charter` | Wedding Charter |
| `delta_queen` | `delta_queen_whale_aboard` | Whale Aboard |
| `delta_queen` | `delta_queen_fog_delay` | Fog Delay |
| `delta_queen` | `delta_queen_engine_trouble` | Engine Trouble |
| `delta_queen` | `delta_queen_captains_invitational` | Captain's Invitational |
| `beach` | `beach_bonfire_night` | Bonfire Night |
| `beach` | `beach_storm_coming` | Storm Coming |
| `beach` | `beach_festival_weekend` | Festival Weekend |
| `pawn_shop` | `pawn_shop_estate_lot_day` | Estate Lot Day |
| `pawn_shop` | `pawn_shop_serial_check_day` | Serial-Check Day |
| `pawn_shop` | `pawn_shop_sals_mood` | Sal's Mood |
| `grand_casino` | `grand_casino_gala_night` | Gala Night |
| `grand_casino` | `grand_casino_convention_crowd` | Convention Crowd |
| `grand_casino` | `grand_casino_audit_night` | Audit Night |

## Historical authored census

At that checkpoint, the canonical file contained **659 positions**: **214 fixed**, **147 event**, **222 scenario**, and **76 exit** positions. Counts below include empty optional capacity and hidden runtime reserves; the normal placement view deliberately showed less.

| Placement map | Fixed | Event | Scenario | Exit | Total | Catalog scenarios |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `corner_store` | 17 | 6 | 12 | 4 | 39 | 5 |
| `back_alley` | 15 | 9 | 12 | 4 | 40 | 4 |
| `motel` | 18 | 10 | 15 | 4 | 47 | 4 |
| `bar` | 7 | 9 | 18 | 4 | 38 | 7 |
| `gas_station_casino` | 5 | 11 | 19 | 3 | 38 | 5 |
| `small_underground_casino` | 8 | 15 | 5 | 4 | 32 | 0 |
| `small_underground_casino:club` | 6 | 9 | 14 | 4 | 33 | 5 |
| `small_underground_casino:casino` | 11 | 11 | 15 | 4 | 41 | 3 |
| `small_underground_casino:back_room` | 8 | 12 | 4 | 3 | 27 | 0 |
| `jazz_club` | 9 | 4 | 12 | 1 | 26 | 4 |
| `kitty_cat_lounge` | 13 | 9 | 14 | 4 | 40 | 4 |
| `delta_queen` | 19 | 13 | 16 | 4 | 52 | 5 |
| `beach` | 3 | 0 | 17 | 3 | 23 | 3 |
| `pawn_shop` | 12 | 6 | 11 | 4 | 33 | 3 |
| `grand_casino` | 14 | 11 | 13 | 6 | 44 | 3 |
| `grand_casino_high_limit` | 4 | 7 | 4 | 4 | 19 | 0 |
| `grand_casino_back_room` | 2 | 5 | 4 | 3 | 14 | 0 |
| `grand_casino_cage` | 7 | 0 | 5 | 4 | 16 | 0 |
| `motel_room` | 12 | 0 | 4 | 3 | 19 | 0 |
| `apartment` | 12 | 0 | 4 | 3 | 19 | 0 |
| `house` | 12 | 0 | 4 | 3 | 19 | 0 |
| **Total** | **214** | **147** | **222** | **76** | **659** | **55** |

## Pull Tabs and lottery-counter placement

Pull Tabs no longer has a clerk, redeemer, machine, or other standalone room position. When that merchandise is stocked, its buy, information, and redemption actions attach to the existing counter host below. Therefore manual placement shows only that host; it never shows a second Pull Tabs marker. Scratch-ticket service shares Nell's counter where configured.

- `bar`: **Rafi**, host `staff:bar_bartender` at `fixed.staff_bartender`; sells `pull_tabs`; services `pull_tabs`.
- `gas_station_casino`: **Nell**, host `character:nell` at `fixed.staff_nell`; sells `pull_tabs`; services `pull_tabs`, `scratch_tickets`.
- `jazz_club`: **Bartender**, host `shopkeeper:merchant` at `fixed.staff_bartender`; sells `pull_tabs`; services `pull_tabs`.
- `grand_casino`: **Host Desk Attendant**, host `casino_fixture:host_desk` at `fixed.fixture_host_desk`; sells `pull_tabs`; services `pull_tabs`.

The Grand main floor still has six non-Pull-Tabs game positions: `fixed.game_machine_1` through `fixed.game_machine_4`, plus `fixed.game_table_left` and `fixed.game_table_right`.

## Per-map placement breakdown

### Corner Store (`corner_store`)

- **Map authority:** archetype `corner_store`; layer `primary`.
- **Census:** fixed 17 (2 required), event 6, scenario 12, exit 4.
- **Fixed placements:**
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3`, `fixed.item_shop_4`, `fixed.item_shop_5`, `fixed.item_shop_6`, `fixed.item_shop_7`, `fixed.item_shop_8` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.staff_shopkeeper` - **Mara**; footprint `behind_counter_person`; required; known occupants `corner_store:shopkeeper`, `shopkeeper:merchant`.
  - `fixed.phone` - **Store Phone**; footprint `surface_item`; required; known occupants `corner_store:phone`, `event:call_brother_in_law`, `service:cashier_tip`.
  - `fixed.drink` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:coin_pusher`.
  - `fixed.event_group_1` - **Group**; footprint `group`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.lender_floor_1` - **Standing person**; footprint `standing_person`; optional/variable.
  - `fixed.travel_right` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
- **Event pool:** **behind_counter_person x2** (`event.behind_counter_person_1`, `event.behind_counter_person_2`); **floor_fixture x1** (`event.floor_fixture_1`); **ground_marker x1** (`event.ground_marker_1`); **group x1** (`event.group_1`); **standing_person x1** (`event.standing_person_1`).
- **Scenario pool:** **behind_counter_person x1** (`scenario.behind_counter_person_1`); **doorway x1** (`scenario.doorway_1`); **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **standing_person x4** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x3** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.standing_person_4` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.wall_item_3` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.floor_fixture_2` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
- **Exits:**
  - `exit.travel_left` - **Travel exit**; footprint `ground_marker`; no statically named claimant.
  - `exit.travel_right` - **Travel exit**; footprint `wall_mounted`; `travel:gas_station_casino`, `travel:jazz_club`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_right` - **Travel exit**; footprint `doorway`; `travel:bar`, `travel:leave`, `travel:pawn_shop`.
- **Catalog scenarios:** **Delivery Day** (`corner_store_delivery_day`); **Lotto Fever** (`corner_store_lotto_fever`); **The Aftermath** (`corner_store_aftermath`); **Dead Shift** (`corner_store_dead_shift`); **Inventory Night** (`corner_store_inventory_night`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 3 hidden reserve positions.

### Back Alley (`back_alley`)

- **Map authority:** archetype `back_alley`; layer `primary`.
- **Census:** fixed 15 (3 required), event 9, scenario 12, exit 4.
- **Fixed placements:**
  - `fixed.staff_merchant` - **Alley Merchant**; footprint `behind_counter_person`; required; known occupants `back_alley:merchant`, `shopkeeper:merchant`.
  - `fixed.lender_street_lender` - **Standing person**; footprint `standing_person`; optional/variable; known occupants `lender:street_lender`.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable.
  - `fixed.home_container_1`, `fixed.home_container_2`, `fixed.home_container_3` - **Floor prop**; footprint `floor_fixture`; optional/variable.
  - `fixed.patron_crew` - **Group**; footprint `group`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3`, `fixed.item_shop_4` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.event_wall_notice` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.patron_vince` - **Vince**; footprint `standing_person`; required; known occupants `back_alley:vince`, `character:vince`.
  - `fixed.patron_lena` - **Lena**; footprint `standing_person`; required; known occupants `back_alley:lena`, `character:lena`.
- **Event pool:** **behind_counter_person x1** (`event.behind_counter_person_1`); **floor_fixture x1** (`event.floor_fixture_1`); **ground_marker x1** (`event.ground_marker_1`); **standing_person x6** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`).
- **Scenario pool:** **doorway x1** (`scenario.doorway_1`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **standing_person x4** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
- **Exits:**
  - `exit.door_left_upper` - **Travel exit**; footprint `standing_person`; no statically named claimant.
  - `exit.door_left_lower` - **Travel exit**; footprint `ground_marker`; no statically named claimant.
  - `exit.right_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_upper` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **Street Craps** (`back_alley_street_craps`); **Cruiser Parked** (`back_alley_cruiser_parked`); **Fence Night** (`back_alley_fence_night`); **Nothing Moving** (`back_alley_nothing_moving`).
- **Manual view:** the default fixed tab exposes 3 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 9 hidden reserve positions.

### Motel (`motel`)

- **Map authority:** archetype `motel`; layer `primary`.
- **Census:** fixed 18 (3 required), event 10, scenario 15, exit 4.
- **Fixed placements:**
  - `fixed.staff_front_desk` - **Front Desk Clerk**; footprint `behind_counter_person`; required; known occupants `motel:front_desk_clerk`, `shopkeeper:merchant`.
  - `fixed.event_hallway_fixture`, `fixed.item_front_desk`, `fixed.item_bed_left`, `fixed.item_key_ledge` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.patron_floor_right` - **Standing person**; footprint `standing_person`; optional/variable.
  - `fixed.item_counter_phone` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:call_brother_in_law`.
  - `fixed.event_wall_calendar` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3`, `fixed.item_shop_4`, `fixed.item_shop_5` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.lender_motel_friend` - **Standing person**; footprint `standing_person`; optional/variable; known occupants `lender:motel_friend`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
  - `fixed.staff_june` - **June**; footprint `behind_counter_person`; required; known occupants `character:june`, `motel:june`.
  - `fixed.patron_marco` - **Marco**; footprint `standing_person`; required; known occupants `character:marco`, `motel:marco`.
- **Event pool:** **behind_counter_person x1** (`event.behind_counter_person_1`); **doorway x1** (`event.doorway_1`); **ground_marker x1** (`event.ground_marker_1`); **standing_person x4** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`); **surface_item x3** (`event.surface_item_1`, `event.surface_item_2`, `event.surface_item_3`).
- **Scenario pool:** **behind_counter_person x1** (`scenario.behind_counter_person_1`); **doorway x3** (`scenario.doorway_1`, `scenario.doorway_2`, `scenario.doorway_3`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **hanging_item x1** (`scenario.hanging_item_1`; footprint `hanging`); **standing_person x4** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x2** (`scenario.wall_item_1`, `scenario.wall_item_2`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.standing_person_4` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.wall_item_2` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
- **Exits:**
  - `exit.door_curtain` - **Travel exit**; footprint `surface_item`; `travel:leave`.
  - `exit.door_left_middle` - **Travel exit**; footprint `standing_person`; no statically named claimant.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.room_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** **Conventioneers** (`motel_conventioneers`); **The Stakeout** (`motel_stakeout`); **Weekly Rates** (`motel_weekly_rates`); **Wedding Overflow** (`motel_wedding_overflow`).
- **Manual view:** the default fixed tab exposes 3 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 6 hidden reserve positions.

### Bar (`bar`)

- **Map authority:** archetype `bar`; layer `primary`.
- **Census:** fixed 7 (2 required), event 9, scenario 18, exit 4.
- **Fixed placements:**
  - `fixed.random_game_1`, `fixed.random_game_2` - **Game fixture**; footprint `surface_item`; optional/variable.
  - `fixed.drink` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.staff_bartender` - **Rafi**; footprint `behind_counter_person`; required; known occupants `bar:bartender`, `staff:bar_bartender`.
  - `fixed.patron_dot` - **Dot**; footprint `standing_person`; required; known occupants `bar:dot`, `character:dot`.
- **Event pool:** **behind_counter_person x1** (`event.behind_counter_person_1`); **doorway x1** (`event.doorway_1`); **floor_fixture x2** (`event.floor_fixture_1`, `event.floor_fixture_2`); **standing_person x5** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`).
- **Scenario pool:** **behind_counter_person x2** (`scenario.behind_counter_person_1`, `scenario.behind_counter_person_2`); **doorway x1** (`scenario.doorway_1`); **floor_fixture x4** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`, `scenario.floor_fixture_4`); **ground_marker x1** (`scenario.ground_marker_1`); **seated_person x2** (`scenario.seated_person_1`, `scenario.seated_person_2`); **standing_person x4** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x2** (`scenario.wall_item_1`, `scenario.wall_item_2`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_4` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_2` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_4` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.seated_person_2` - Knuckles recruitment can coexist with the Fight Night seated actor.
- **Exits:**
  - `exit.travel_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.travel_right` - **Travel exit**; footprint `standing_person`; `travel:leave`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_right` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** **The Wake** (`bar_wake`); **Fight Night** (`bar_fight_night`); **Payday Rush** (`bar_payday_rush`); **Lock-In** (`bar_lock_in`); **Darts League Night** (`bar_darts_league_night`); **Live Band** (`bar_live_band`); **Dead Tuesday** (`bar_dead_tuesday`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 7 hidden reserve positions.

### Gas Station Casino (`gas_station_casino`)

- **Map authority:** archetype `gas_station_casino`; layer `primary`.
- **Census:** fixed 5 (1 required), event 11, scenario 19, exit 3.
- **Fixed placements:**
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:coin_pusher`, `game:slot`, `game:video_poker`.
  - `fixed.game_scratch_tickets` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:scratch_tickets`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.staff_nell` - **Nell**; footprint `behind_counter_person`; required; known occupants `character:nell`, `gas_station_casino:nell`.
- **Event pool:** **doorway x2** (`event.doorway_1`, `event.doorway_2`); **floor_fixture x2** (`event.floor_fixture_1`, `event.floor_fixture_2`); **ground_marker x1** (`event.ground_marker_1`); **standing_person x5** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`); **surface_item x1** (`event.surface_item_1`).
- **Scenario pool:** **behind_counter_person x2** (`scenario.behind_counter_person_1`, `scenario.behind_counter_person_2`); **doorway x3** (`scenario.doorway_1`, `scenario.doorway_2`, `scenario.doorway_3`); **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **ground_marker x1** (`scenario.ground_marker_1`); **group x2** (`scenario.group_1`, `scenario.group_2`); **standing_person x5** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`, `scenario.standing_person_5`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x3** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.surface_item_1`, `event.doorway_2`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_2` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_3` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_5` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.door_left_middle` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; `travel:back_alley`, `travel:corner_store`, `travel:delta_queen`, `travel:grand_casino`, `travel:kitty_cat_lounge`, `travel:leave`.
- **Catalog scenarios:** **Trucker Convoy** (`gas_station_trucker_convoy`); **Tour Bus Stop** (`gas_station_tour_bus_stop`); **Graveyard Shift** (`gas_station_graveyard_shift`); **Road Crew Payday** (`gas_station_road_crew_payday`); **Storm Shelter** (`gas_station_storm_shelter`).
- **Manual view:** the default fixed tab exposes 1 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 8 hidden reserve positions.

### The Punchline (`small_underground_casino`)

- **Map authority:** archetype `small_underground_casino`; layer `primary`.
- **Census:** fixed 8 (0 required), event 15, scenario 5, exit 4.
- **Fixed placements:**
  - `fixed.door_right_lower` - **Doorway / exit**; footprint `doorway`; optional/variable; known occupants `event:side_door`.
  - `fixed.staff_floor_left` - **Standing person**; footprint `standing_person`; optional/variable.
  - `fixed.service_stage_left` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.crew_group` - **Group**; footprint `group`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.game_video_poker` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:video_poker`.
  - `fixed.service_two_drink_minimum` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:punchline_two_drink_minimum`.
  - `fixed.game_slot` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:slot`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
- **Event pool:** **doorway x1** (`event.doorway_1`); **floor_fixture x2** (`event.floor_fixture_1`, `event.floor_fixture_2`); **standing_person x8** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7`, `event.standing_person_8`); **surface_item x3** (`event.surface_item_1`, `event.surface_item_2`, `event.surface_item_3`); **wall_item x1** (`event.wall_item_1`; footprint `wall_mounted`).
- **Scenario pool:** **doorway x1** (`scenario.doorway_1`); **floor_fixture x1** (`scenario.floor_fixture_1`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.door_right_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.door_right_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; `environment_layer:casino`.
  - `exit.left_lower` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 9 hidden reserve positions.

### The Punchline - Club layer (`small_underground_casino:club`)

- **Map authority:** archetype `small_underground_casino`; layer `club`.
- **Census:** fixed 6 (1 required), event 9, scenario 14, exit 4.
- **Fixed placements:**
  - `fixed.door_right_lower` - **Doorway / exit**; footprint `doorway`; optional/variable; known occupants `event:side_door`.
  - `fixed.staff_floor_right` - **Ox**; footprint `standing_person`; required; known occupants `punchline:club_bouncer`, `staff:punchline_bouncer`.
  - `fixed.service_stage` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:punchline_two_drink_minimum`.
  - `fixed.service_left_table` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.ambient_stage` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `environment_layer:ambient`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
- **Event pool:** **floor_fixture x1** (`event.floor_fixture_1`); **standing_person x8** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7`, `event.standing_person_8`).
- **Scenario pool:** **doorway x2** (`scenario.doorway_1`, `scenario.doorway_2`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **group x1** (`scenario.group_1`); **standing_person x4** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7`, `event.standing_person_8` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_4` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.door_right_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.door_side` - **Travel exit**; footprint `doorway`; `environment_layer:casino`.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_lower` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **Open Mic Night** (`punchline_open_mic_night`); **Headliner Night** (`punchline_headliner_night`); **Bringer Show** (`punchline_bringer_show`); **Debt Court** (`punchline_debt_court`); **Raid Jitters** (`punchline_raid_jitters`).
- **Manual view:** the default fixed tab exposes 1 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 10 hidden reserve positions.

### The Punchline - Casino layer (`small_underground_casino:casino`)

- **Map authority:** archetype `small_underground_casino`; layer `casino`.
- **Census:** fixed 11 (2 required), event 11, scenario 15, exit 4.
- **Fixed placements:**
  - `fixed.staff_dealer` - **Sable**; footprint `standing_person`; required; known occupants `punchline:casino_dealer`, `staff:underground_dealer`.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:slot`.
  - `fixed.random_game_2` - **Game fixture**; footprint `surface_item`; optional/variable.
  - `fixed.service_left_table` - **Group**; footprint `group`; optional/variable.
  - `fixed.staff_street_lender` - **Counter staff**; footprint `behind_counter_person`; optional/variable; known occupants `lender:street_lender`.
  - `fixed.crew_group` - **Group**; footprint `group`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.random_game_3` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:video_poker`.
  - `fixed.door_side_event` - **Doorway / exit**; footprint `doorway`; optional/variable; known occupants `event:side_door`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.numbers_book` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `numbers:book`.
  - `fixed.staff_floor_right` - **Ox**; footprint `standing_person`; required; known occupants `character:ox`, `punchline:casino_bouncer`.
- **Event pool:** **behind_counter_person x1** (`event.behind_counter_person_1`); **floor_fixture x1** (`event.floor_fixture_1`); **seated_person x1** (`event.seated_person_1`); **standing_person x8** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7`, `event.standing_person_8`).
- **Scenario pool:** **doorway x2** (`scenario.doorway_1`, `scenario.doorway_2`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **group x1** (`scenario.group_1`); **seated_person x1** (`scenario.seated_person_1`); **standing_person x3** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x3** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.wall_item_3` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
- **Exits:**
  - `exit.door_guarded_lower` - **Travel exit**; footprint `doorway`; `environment_layer:back_room`.
  - `exit.door_left_lower` - **Travel exit**; footprint `doorway`; `environment_layer:club`.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.guarded_upper` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **High-Stakes Night** (`punchline_high_stakes_night`); **Greased Week** (`punchline_greased_week`); **New Muscle** (`punchline_new_muscle`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 10 hidden reserve positions.

### The Punchline - Back Room layer (`small_underground_casino:back_room`)

- **Map authority:** archetype `small_underground_casino`; layer `back_room`.
- **Census:** fixed 8 (0 required), event 12, scenario 4, exit 3.
- **Fixed placements:**
  - `fixed.random_game_1` - **Game fixture**; footprint `surface_item`; optional/variable; known occupants `game:crew_draw_poker`.
  - `fixed.event_planning_table` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:crew_planning_table`.
  - `fixed.event_numbers_desk` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:numbers_desk`.
  - `fixed.event_job_board` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:crew_job_board`.
  - `fixed.event_mags_bench` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:crew_mags_bench`.
  - `fixed.event_practice_rig` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `event:crew_practice_rig`.
  - `fixed.event_rook_ride` - **Doorway / exit**; footprint `doorway`; optional/variable; known occupants `event:crew_rook_ride`.
  - `fixed.ambient_rook` - **Standing person**; footprint `standing_person`; optional/variable; known occupants `environment_layer:ambient`.
- **Event pool:** **doorway x1** (`event.doorway_1`); **floor_fixture x1** (`event.floor_fixture_1`); **standing_person x6** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`); **surface_item x4** (`event.surface_item_1`, `event.surface_item_2`, `event.surface_item_3`, `event.surface_item_4`).
- **Scenario pool:** **floor_fixture x1** (`scenario.floor_fixture_1`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.layer_door` - **Travel exit**; footprint `doorway`; `environment_layer:casino`.
  - `exit.left_1` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_2` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 8 hidden reserve positions.

### Jazz Club (`jazz_club`)

- **Map authority:** archetype `jazz_club`; layer `primary`.
- **Census:** fixed 9 (7 required), event 4, scenario 12, exit 1.
- **Fixed placements:**
  - `fixed.staff_bartender` - **Bartender**; footprint `behind_counter_person`; required; known occupants `jazz_club:bartender`, `shopkeeper:merchant`.
  - `fixed.band_stage` - **Jazz Band**; footprint `ground_marker`; required; known occupants `fixture:jazz_band_stage`, `jazz_club:band_stage`.
  - `fixed.musician_sax` - **Sax Player**; footprint `standing_person`; required; known occupants `jazz_club:musician_sax`, `musician:jazz_sax`.
  - `fixed.musician_drummer` - **Drummer**; footprint `standing_person`; required; known occupants `jazz_club:musician_drummer`, `musician:jazz_drummer`.
  - `fixed.item_shop_1`, `fixed.item_shop_2` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.musician_cello` - **Cello Player**; footprint `standing_person`; required; known occupants `jazz_club:musician_cello`, `musician:jazz_cello`.
  - `fixed.tip_jar_band` - **Band Tip Jar**; footprint `surface_item`; required; known occupants `jazz_club:band_tip_jar`, `service:jazz_band_tip_jar`.
  - `fixed.patron_dot` - **Dot**; footprint `standing_person`; required; known occupants `character:dot`, `jazz_club:dot`.
- **Event pool:** **floor_fixture x1** (`event.floor_fixture_1`); **standing_person x3** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`).
- **Scenario pool:** **doorway x1** (`scenario.doorway_1`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **seated_person x1** (`scenario.seated_person_1`); **standing_person x3** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x2** (`scenario.wall_item_1`, `scenario.wall_item_2`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_2` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.door_right_upper` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **Guest Legend** (`jazz_club_guest_legend`); **Rent Party** (`jazz_club_rent_party`); **Recording Night** (`jazz_club_recording_night`); **Union Trouble** (`jazz_club_union_trouble`).
- **Manual view:** the default fixed tab exposes 7 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 5 hidden reserve positions.

### Kitty Cat Lounge (`kitty_cat_lounge`)

- **Map authority:** archetype `kitty_cat_lounge`; layer `primary`.
- **Census:** fixed 13 (2 required), event 9, scenario 14, exit 4.
- **Fixed placements:**
  - `fixed.staff_bar` - **Iris**; footprint `behind_counter_person`; required; known occupants `kitty_cat_lounge:bar_host`, `staff:kitty_bar_host`.
  - `fixed.staff_merchant` - **Counter staff**; footprint `behind_counter_person`; optional/variable; known occupants `shopkeeper:merchant`.
  - `fixed.random_game_3` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:slot`.
  - `fixed.patron_group_center` - **Group**; footprint `group`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.random_game_2` - **Game fixture**; footprint `surface_item`; optional/variable; known occupants `game:bar_dice`.
  - `fixed.event_grand_casino_invite` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `event:grand_casino_invite`.
  - `fixed.game_table_left` - **Game fixture**; footprint `surface_item`; optional/variable; known occupants `game:roulette`.
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.service_kitty_champagne` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:kitty_champagne`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.patron_dot` - **Dot**; footprint `seated_person`; required; known occupants `character:dot`, `kitty_cat_lounge:dot`.
- **Event pool:** **doorway x1** (`event.doorway_1`); **floor_fixture x1** (`event.floor_fixture_1`); **seated_person x1** (`event.seated_person_1`); **standing_person x6** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`).
- **Scenario pool:** **doorway x2** (`scenario.doorway_1`, `scenario.doorway_2`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **seated_person x1** (`scenario.seated_person_1`); **standing_person x3** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x3** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.wall_item_3` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
- **Exits:**
  - `exit.door_right_middle` - **Travel exit**; footprint `standing_person`; no statically named claimant.
  - `exit.door_right_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_lower` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **Amateur Night** (`kitty_cat_lounge_amateur_night`); **The Buyout** (`kitty_cat_lounge_buyout`); **Slow Night** (`kitty_cat_lounge_slow_night`); **Bachelorette Storm** (`kitty_cat_lounge_bachelorette_storm`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 8 hidden reserve positions.

### Delta Queen (`delta_queen`)

- **Map authority:** archetype `delta_queen`; layer `primary`.
- **Census:** fixed 19 (2 required), event 13, scenario 16, exit 4.
- **Fixed placements:**
  - `fixed.patron_front_left` - **Seated person**; footprint `seated_person`; optional/variable; known occupants `lender:the_crew`.
  - `fixed.staff_right_table` - **Sable**; footprint `behind_counter_person`; required; known occupants `delta_queen:right_table_dealer`, `staff:delta_right_table_dealer`.
  - `fixed.staff_merchant` - **Counter staff**; footprint `behind_counter_person`; optional/variable; known occupants `shopkeeper:merchant`.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:blackjack`.
  - `fixed.random_game_2` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:video_poker`.
  - `fixed.staff_floor` - **Ox**; footprint `standing_person`; required; known occupants `delta_queen:deck_boss`, `staff:delta_deck_boss`.
  - `fixed.event_deck_walk` - **Floor marker**; footprint `ground_marker`; optional/variable; known occupants `service:riverboat_deck_walk`.
  - `fixed.event_table_1`, `fixed.event_table_2` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.random_game_3` - **Game fixture**; footprint `surface_item`; optional/variable; known occupants `game:roulette`.
  - `fixed.event_grand_casino_invite` - **Wall item**; footprint `wall_mounted`; optional/variable; known occupants `event:grand_casino_invite`.
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3`, `fixed.item_shop_4`, `fixed.item_shop_5`, `fixed.item_shop_6`, `fixed.item_shop_7` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
- **Event pool:** **behind_counter_person x1** (`event.behind_counter_person_1`); **doorway x1** (`event.doorway_1`); **floor_fixture x2** (`event.floor_fixture_1`, `event.floor_fixture_2`); **seated_person x1** (`event.seated_person_1`); **standing_person x6** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`); **surface_item x1** (`event.surface_item_1`); **wall_item x1** (`event.wall_item_1`; footprint `wall_mounted`).
- **Scenario pool:** **behind_counter_person x1** (`scenario.behind_counter_person_1`); **doorway x1** (`scenario.doorway_1`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **group x1** (`scenario.group_1`); **standing_person x3** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x4** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`, `scenario.wall_item_4`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.seated_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_3` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_4` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.door_left_middle` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.door_right_middle` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.left_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** **Wedding Charter** (`delta_queen_wedding_charter`); **Whale Aboard** (`delta_queen_whale_aboard`); **Fog Delay** (`delta_queen_fog_delay`); **Engine Trouble** (`delta_queen_engine_trouble`); **Captain's Invitational** (`delta_queen_captains_invitational`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 9 hidden reserve positions.

### The Beach (`beach`)

- **Map authority:** archetype `beach`; layer `primary`.
- **Census:** fixed 3 (0 required), event 0, scenario 17, exit 3.
- **Fixed placements:**
  - `fixed.door_left_lower` - **Doorway / exit**; footprint `doorway`; optional/variable.
  - `fixed.service_beach_sand_pile` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `service:beach_sand_pile`.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable.
- **Event pool:** none.
- **Scenario pool:** **behind_counter_person x2** (`scenario.behind_counter_person_1`, `scenario.behind_counter_person_2`); **doorway x1** (`scenario.doorway_1`); **floor_fixture x4** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`, `scenario.floor_fixture_4`); **ground_marker x1** (`scenario.ground_marker_1`); **standing_person x5** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`, `scenario.standing_person_4`, `scenario.standing_person_5`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x2** (`scenario.wall_item_1`, `scenario.wall_item_2`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.floor_fixture_4` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_2` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_4` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.standing_person_5` - Lucky recruitment can coexist with the Festival scenario cast.
- **Exits:**
  - `exit.door_right_lower` - **Travel exit**; footprint `floor_fixture`; no statically named claimant.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_upper` - **Travel exit**; footprint `doorway`; `travel:leave`.
- **Catalog scenarios:** **Bonfire Night** (`beach_bonfire_night`); **Storm Coming** (`beach_storm_coming`); **Festival Weekend** (`beach_festival_weekend`).
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 4 hidden reserve positions.

### Sal's Pawn Shop (`pawn_shop`)

- **Map authority:** archetype `pawn_shop`; layer `primary`.
- **Census:** fixed 12 (1 required), event 6, scenario 11, exit 4.
- **Fixed placements:**
  - `fixed.staff_pawn_counter` - **Sal**; footprint `behind_counter_person`; required; known occupants `meta_pawn_counter:sell`, `pawn_shop:sal`, `staff:pawn_counter_sal`.
  - `fixed.staff_merchant` - **Counter staff**; footprint `behind_counter_person`; optional/variable; known occupants `shopkeeper:merchant`.
  - `fixed.lender_sals_pawn_counter` - **Standing person**; footprint `standing_person`; optional/variable; known occupants `lender:sals_pawn_counter`.
  - `fixed.random_game_1` - **Game fixture**; footprint `floor_fixture`; optional/variable; known occupants `game:slot`.
  - `fixed.item_shop_1` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:0`.
  - `fixed.item_shop_2` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:1`.
  - `fixed.item_shop_3` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:2`.
  - `fixed.item_shop_4` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:3`.
  - `fixed.item_shop_5` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:4`.
  - `fixed.item_shop_6` - **Shop item**; footprint `shop_item`; optional/variable; known occupants `meta_sal_shelf:5`.
  - `fixed.item_shop_7`, `fixed.item_shop_8` - **Shop item**; footprint `shop_item`; optional/variable.
- **Event pool:** **floor_fixture x1** (`event.floor_fixture_1`); **shop_item x1** (`event.shop_item_1`); **standing_person x3** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`); **surface_item x1** (`event.surface_item_1`).
- **Scenario pool:** **doorway x1** (`scenario.doorway_1`); **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **shop_item x2** (`scenario.shop_item_1`, `scenario.shop_item_2`); **standing_person x2** (`scenario.standing_person_1`, `scenario.standing_person_2`); **surface_item x2** (`scenario.surface_item_1`, `scenario.surface_item_2`); **wall_item x2** (`scenario.wall_item_1`, `scenario.wall_item_2`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.shop_item_1`, `event.standing_person_2`, `event.standing_person_3` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.standing_person_2` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.wall_item_2` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.floor_fixture_2` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
- **Exits:**
  - `exit.door_right_lower` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.door_left_lower` - **Travel exit**; footprint `standing_person`; no statically named claimant.
  - `exit.left_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_upper` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** **Estate Lot Day** (`pawn_shop_estate_lot_day`); **Serial-Check Day** (`pawn_shop_serial_check_day`); **Sal's Mood** (`pawn_shop_sals_mood`).
- **Manual view:** the default fixed tab exposes 1 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 6 hidden reserve positions.

### Grand Casino Main Floor (`grand_casino`)

- **Map authority:** archetype `grand_casino`; layer `primary`.
- **Census:** fixed 14 (2 required), event 11, scenario 13, exit 6.
- **Fixed placements:**
  - `fixed.game_machine_1`, `fixed.game_machine_2`, `fixed.game_machine_3`, `fixed.game_machine_4` - **Game fixture**; footprint `wall_mounted`; optional/variable.
  - `fixed.game_table_left`, `fixed.game_table_right` - **Game fixture**; footprint `surface_item`; optional/variable.
  - `fixed.drink` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.event_wall_1` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.fixture_host_desk` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `casino_fixture:host_desk`.
  - `fixed.event_floor_1` - **Floor prop**; footprint `floor_fixture`; optional/variable.
  - `fixed.patron_bishop` - **Standing person**; footprint `standing_person`; optional/variable; known occupants `event:recruitment_bishop`.
  - `fixed.service_house_drink` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `service:house_drink`.
  - `fixed.staff_host` - **Iris**; footprint `behind_counter_person`; required; known occupants `grand_casino:floor_host`, `staff:grand_casino_host`.
  - `fixed.event_audit_roster` - **Audit Roster**; footprint `wall_mounted`; required; known occupants `event:scenario_audit_roster`, `grand_casino:audit_roster`.
- **Event pool:** **behind_counter_person x2** (`event.behind_counter_person_1`, `event.behind_counter_person_2`); **floor_fixture x1** (`event.floor_fixture_1`); **standing_person x7** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7`); **wall_item x1** (`event.wall_item_1`; footprint `wall_mounted`).
- **Scenario pool:** **doorway x1** (`scenario.doorway_1`); **floor_fixture x3** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`, `scenario.floor_fixture_3`); **ground_marker x1** (`scenario.ground_marker_1`); **group x1** (`scenario.group_1`); **standing_person x3** (`scenario.standing_person_1`, `scenario.standing_person_2`, `scenario.standing_person_3`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x3** (`scenario.wall_item_1`, `scenario.wall_item_2`, `scenario.wall_item_3`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.behind_counter_person_2`, `event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`, `event.standing_person_7` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_2` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.floor_fixture_3` - The Crew's live table can follow the player into this room beside authored scenario objects.
  - `scenario.wall_item_3` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_3` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.travel_back_room` - **Travel exit**; footprint `doorway`; `travel:grand_casino_back_room`, `travel:motel`.
  - `exit.travel_high_limit` - **Travel exit**; footprint `doorway`; `travel:grand_casino_high_limit`.
  - `exit.travel_cage` - **Travel exit**; footprint `doorway`; `travel:grand_casino_cage`, `travel:small_underground_casino`.
  - `exit.travel_leave` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_right` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** **Gala Night** (`grand_casino_gala_night`); **Convention Crowd** (`grand_casino_convention_crowd`); **Audit Night** (`grand_casino_audit_night`).
- **Manual view:** the default fixed tab exposes 2 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 12 hidden reserve positions.

### Grand Casino High-Limit Room (`grand_casino_high_limit`)

- **Map authority:** archetype `grand_casino_high_limit`; layer `primary`.
- **Census:** fixed 4 (0 required), event 7, scenario 4, exit 4.
- **Fixed placements:**
  - `fixed.game_table_1`, `fixed.game_table_2`, `fixed.game_table_3`, `fixed.game_table_4` - **Game fixture**; footprint `surface_item`; optional/variable.
- **Event pool:** **floor_fixture x1** (`event.floor_fixture_1`); **standing_person x6** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6`).
- **Scenario pool:** **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **standing_person x1** (`scenario.standing_person_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`, `event.standing_person_6` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.floor_fixture_2` - The Crew's live table can follow the player into this room beside authored scenario objects.
- **Exits:**
  - `exit.travel_left` - **Travel exit**; footprint `doorway`; `travel:grand_casino`.
  - `exit.travel_right` - **Travel exit**; footprint `doorway`; `travel:grand_casino_cage`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_right` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 9 hidden reserve positions.

### Grand Casino Back Room (`grand_casino_back_room`)

- **Map authority:** archetype `grand_casino_back_room`; layer `primary`.
- **Census:** fixed 2 (0 required), event 5, scenario 4, exit 3.
- **Fixed placements:**
  - `fixed.game_table_left`, `fixed.game_table_right` - **Game fixture**; footprint `surface_item`; optional/variable.
- **Event pool:** **standing_person x5** (`event.standing_person_1`, `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5`).
- **Scenario pool:** **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **standing_person x1** (`scenario.standing_person_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `event.standing_person_2`, `event.standing_person_3`, `event.standing_person_4`, `event.standing_person_5` - Independent ambient traveler, Crew, or Numbers presence may coexist with mapped room events.
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.floor_fixture_2` - The Crew's live table can follow the player into this room beside authored scenario objects.
- **Exits:**
  - `exit.travel_left` - **Travel exit**; footprint `doorway`; `travel:grand_casino`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_right` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 8 hidden reserve positions.

### Grand Casino Cage (`grand_casino_cage`)

- **Map authority:** archetype `grand_casino_cage`; layer `primary`.
- **Census:** fixed 7 (1 required), event 0, scenario 5, exit 4.
- **Fixed placements:**
  - `fixed.item_shop_1`, `fixed.item_shop_2`, `fixed.item_shop_3`, `fixed.item_shop_4` - **Shop item**; footprint `shop_item`; optional/variable.
  - `fixed.fixture_cage_1` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `casino_fixture:cage_counter`.
  - `fixed.fixture_cage_2` - **Wall item**; footprint `wall_mounted`; optional/variable; known occupants `casino_fixture:cage_atm`.
  - `fixed.staff_linda` - **Linda**; footprint `behind_counter_person`; required; known occupants `grand_casino_cage:linda`, `staff:grand_casino_linda`.
- **Event pool:** none.
- **Scenario pool:** **floor_fixture x2** (`scenario.floor_fixture_1`, `scenario.floor_fixture_2`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
  - `scenario.floor_fixture_2` - The Crew's live table can follow the player into this room beside authored scenario objects.
- **Exits:**
  - `exit.travel_floor_door` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.casino_floor_door` - **Travel exit**; footprint `doorway`; `travel:grand_casino`.
  - `exit.safe_left` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.safe_left_lower` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 1 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 4 hidden reserve positions.

### Motel Room (`motel_room`)

- **Map authority:** archetype `motel_room`; layer `primary`.
- **Census:** fixed 12 (0 required), event 0, scenario 4, exit 3.
- **Fixed placements:**
  - `fixed.home_container_1` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_bag_01`.
  - `fixed.home_container_2` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_trunk_02`.
  - `fixed.home_container_3` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:trunk_01`.
  - `fixed.home_trade_up` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `meta_trade_up:station`.
  - `fixed.home_tenure` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_tenure:status`.
  - `fixed.home_sleep` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_sleep:bed`.
  - `fixed.home_item_1`, `fixed.home_item_2`, `fixed.home_item_3` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.home_upgrade` - **Wall item**; footprint `wall_mounted`; optional/variable; known occupants `meta_upgrade:home`.
  - `fixed.home_notice` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.home_storage` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_storage:place`.
- **Event pool:** none.
- **Scenario pool:** **floor_fixture x1** (`scenario.floor_fixture_1`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.travel_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_door` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.right_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 3 hidden reserve positions.

### Apartment (`apartment`)

- **Map authority:** archetype `apartment`; layer `primary`.
- **Census:** fixed 12 (0 required), event 0, scenario 4, exit 3.
- **Fixed placements:**
  - `fixed.home_trade_up` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `meta_trade_up:station`.
  - `fixed.home_tenure` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_tenure:status`.
  - `fixed.home_sleep` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_sleep:bed`.
  - `fixed.home_item_1`, `fixed.home_item_2`, `fixed.home_item_3` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.home_container_1` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_bag_01`.
  - `fixed.home_container_2` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_trunk_02`.
  - `fixed.home_container_3` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:trunk_01`.
  - `fixed.home_upgrade` - **Wall item**; footprint `wall_mounted`; optional/variable; known occupants `meta_upgrade:home`.
  - `fixed.home_notice` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.home_storage` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_storage:place`.
- **Event pool:** none.
- **Scenario pool:** **floor_fixture x1** (`scenario.floor_fixture_1`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.travel_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.left_door` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.right_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 3 hidden reserve positions.

### House (`house`)

- **Map authority:** archetype `house`; layer `primary`.
- **Census:** fixed 12 (0 required), event 0, scenario 4, exit 3.
- **Fixed placements:**
  - `fixed.home_container_1` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_bag_01`.
  - `fixed.home_container_2` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:meta_trunk_02`.
  - `fixed.home_container_3` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_container:trunk_01`.
  - `fixed.home_sleep` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_sleep:bed`.
  - `fixed.home_tenure` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `home_tenure:status`.
  - `fixed.home_trade_up` - **Counter or table item**; footprint `surface_item`; optional/variable; known occupants `meta_trade_up:station`.
  - `fixed.home_item_1`, `fixed.home_item_2`, `fixed.home_item_3` - **Counter or table item**; footprint `surface_item`; optional/variable.
  - `fixed.home_upgrade` - **Wall item**; footprint `wall_mounted`; optional/variable; known occupants `meta_upgrade:home`.
  - `fixed.home_notice` - **Wall item**; footprint `wall_mounted`; optional/variable.
  - `fixed.home_storage` - **Floor prop**; footprint `floor_fixture`; optional/variable; known occupants `home_storage:place`.
- **Event pool:** none.
- **Scenario pool:** **floor_fixture x1** (`scenario.floor_fixture_1`); **standing_person x1** (`scenario.standing_person_1`); **surface_item x1** (`scenario.surface_item_1`); **wall_item x1** (`scenario.wall_item_1`; footprint `wall_mounted`).
- **Runtime reserves:**
  - `scenario.floor_fixture_1` - Runtime delivery state can add a package or floor prop beside the authored scenario inventory.
  - `scenario.wall_item_1` - Runtime delivery or chain state can add a held wall object beside the authored scenario inventory.
  - `scenario.standing_person_1` - Injected chain, traveler, or delivery contact can coexist with the authored scenario cast.
- **Exits:**
  - `exit.travel_door` - **Travel exit**; footprint `doorway`; `travel:leave`.
  - `exit.left_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
  - `exit.right_door` - **Travel exit**; footprint `doorway`; no statically named claimant.
- **Catalog scenarios:** none.
- **Manual view:** the default fixed tab exposes 0 required positions plus any occupied optional fixed positions. Event and scenario tabs show occupants for the current snapshot. Enable **Empty capacity** to place the full reusable banks and **Runtime reserves** to place the 3 hidden reserve positions.

## Validation

- Derived from canonical placement SHA-256
  `E18795A6665699AA1C8C6A1B451E66C10357F496C1FA059848EA7B3598FCC5D0`.
- The engine-free authority replay passes all 21 maps, 18 archetypes, 55
  scenarios, 767 active snapshots, and 1,504 complete/aftermath snapshots with
  zero missing-capacity overflow.
- The historical documentation census cross-check found all 21 map sections,
  all 55 scenario-index rows, and every one of the 659 then-authored slot IDs in
  its corresponding map section.
- No source/document mismatch was found in that census, family ownership,
  runtime-reserve reasons, layer assignment, or scenario assignment.
