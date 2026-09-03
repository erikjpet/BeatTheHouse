# teach06_2 dependency-complete lesson classification

Status: **CLASSIFIED — implementation authoring has not begun**  
Exact classification root: `039e3326d7f09ab911f8903adc03b94c2cc12e4f`  
Catalog: `data/tutorial/lessons.json` (63 entries: 56 `tutorial_run`, 7 `normal_run`)

This is the mandatory section 1 classification artifact. It was completed before
any lesson, coach, or teaching test was changed. The required `depth06_1`,
`game06_8`, and `world06_7` surfaces are present on this root. Native cold-run and
visual evidence remain final acceptance work; they were not started while the
Blackjack closeout audit owned the Godot runtime.

## Result

| Classification | Count |
| --- | ---: |
| correct | 59 |
| stale | 4 |
| redundant | 0 |
| broken | 0 |

The guided 56-lesson prefix is unchanged and remains protected by its exact-ID,
trigger, recovery, dialogue-cadence, and pointer-target contracts. Three
contextual tips still match public state and live actions. Four contextual tips
are stale because their trigger is now broader than their promise or their copy
describes the pre-depth interaction. No current lesson is redundant: the
reworked surfaces do not teach the same rule at the same moment with equivalent
once-only guidance.

`tip06_coin_pusher` is stale and must be rewritten. It says to aim a lane and use
nudges, while the current cabinet exposes a draggable carriage, hold-to-charge
drop, skill stop, bonus-token cups, and heavy feature pieces as the primary goals.
The old wording understates the real objective and names an obsolete main verb.

Three other contextual tips are also stale on the dependency-complete root:

- `tip06_tonight_changes_rooms` fires for any active scenario but promises a
  rumor even when no rumor encounter is present, conflating two independent
  public systems.
- `tip06_delivery_route` fires for the shared delivery model, including lookout
  holds, but always describes a carried package and a route. That is false for a
  stationary hold.
- `tip06_craps_pass_line` remains mathematically accurate, but it is the only
  first-encounter Craps lesson and still stops at the pre-depth rule summary. It
  does not teach the current grab/drag/release throw required to act on that rule.

## Evidence key

- **CAT** — exact entry in `data/tutorial/lessons.json`, at the line shown.
- **GUIDED** — one of the frozen 56 guided IDs in
  `scripts/tests/foundation/onboarding_06_contract.gd`; its target/action is also
  traversed by the existing tutorial defect checks.
- **PUBLIC** — normal-run trigger is derived only from the public coach context in
  `scripts/ui/coach_overlay.gd` and is covered by the positive/negative matrix.
- **LIVE** — named anchor/action remains present on the exact classification root.
- **GAP** — current lesson remains correct but does not satisfy all new section 2
  teaching requirements; implementation must extend or add a lesson after this
  classification commit.

## All 63 existing lessons

| # | Lesson | Class | Trace | Disposition |
| ---: | --- | --- | --- | --- |
| 1 | `tutorial_apartment_xray` | correct | CAT:3; GUIDED; LIVE | Keep unchanged. |
| 2 | `tutorial_inventory_xray` | correct | CAT:15; GUIDED; LIVE | Keep unchanged. |
| 3 | `tutorial_open_map_corner` | correct | CAT:27; GUIDED; LIVE | Keep unchanged. |
| 4 | `tutorial_travel_corner` | correct | CAT:39; GUIDED; LIVE | Keep unchanged. |
| 5 | `tutorial_inspect_coffee` | correct | CAT:51; GUIDED; LIVE | Keep unchanged. |
| 6 | `tutorial_inspect_pencil` | correct | CAT:64; GUIDED; LIVE | Keep unchanged. |
| 7 | `tutorial_buy_store_item` | correct | CAT:76; GUIDED; LIVE | Keep unchanged. |
| 8 | `tutorial_buy_remaining_store_item` | correct | CAT:88; GUIDED; LIVE | Keep unchanged. |
| 9 | `tutorial_crew_warning` | correct | CAT:104; GUIDED; LIVE | Keep unchanged; it teaches tutorial debt, not normal-run trust. |
| 10 | `tutorial_family_phone` | correct | CAT:115; GUIDED; LIVE | Keep unchanged. |
| 11 | `tutorial_family_debt` | correct | CAT:127; GUIDED; LIVE | Keep unchanged. |
| 12 | `tutorial_parking_tip` | correct | CAT:138; GUIDED; LIVE | Keep unchanged. |
| 13 | `tutorial_route_map` | correct | CAT:150; GUIDED; LIVE | Keep unchanged. |
| 14 | `tutorial_route_choice` | correct | CAT:162; GUIDED; LIVE | Keep unchanged. |
| 15 | `tutorial_gas_machine` | correct | CAT:174; GUIDED; LIVE | Keep unchanged. |
| 16 | `tutorial_gas_peek` | correct | CAT:186; GUIDED; LIVE | Keep unchanged; detector scan and authored Heat ladder remain live. |
| 17 | `tutorial_gas_peek_heat` | correct | CAT:198; GUIDED; LIVE | Keep unchanged. |
| 18 | `tutorial_gas_xray_buy` | correct | CAT:209; GUIDED; LIVE | Keep unchanged; Buy and Collect Tray remain live. |
| 19 | `tutorial_gas_peel` | correct | CAT:227; GUIDED; LIVE | Keep unchanged; reveal and file actions remain live. |
| 20 | `tutorial_gas_leave_machine` | correct | CAT:249; GUIDED; LIVE | Keep unchanged. |
| 21 | `tutorial_gas_redeem` | correct | CAT:261; GUIDED; LIVE | Keep unchanged. |
| 22 | `tutorial_gas_map_underground` | correct | CAT:273; GUIDED; LIVE | Keep unchanged. |
| 23 | `tutorial_gas_travel_underground` | correct | CAT:285; GUIDED; LIVE | Keep unchanged. |
| 24 | `tutorial_underground_table` | correct | CAT:297; GUIDED; LIVE | Keep unchanged. |
| 25 | `tutorial_blackjack_clean_deal` | correct | CAT:309; GUIDED; LIVE | Keep unchanged. |
| 26 | `tutorial_blackjack_clean_finish` | correct | CAT:321; GUIDED; LIVE | Keep unchanged; Hit and Stand remain live. |
| 27 | `tutorial_blackjack_raise` | correct | CAT:333; GUIDED; LIVE | Keep unchanged; felt chip control remains live. |
| 28 | `tutorial_blackjack_raised_deal` | correct | CAT:345; GUIDED; LIVE | Keep unchanged. |
| 29 | `tutorial_blackjack_heat_precheck` | correct | CAT:357; GUIDED; LIVE | Keep unchanged. |
| 30 | `tutorial_blackjack_lookaway` | correct | CAT:368; GUIDED; LIVE | Keep unchanged. |
| 31 | `tutorial_blackjack_peek` | correct | CAT:380; GUIDED; LIVE | Keep unchanged. |
| 32 | `tutorial_blackjack_peek_finish` | correct | CAT:392; GUIDED; LIVE | Keep unchanged. |
| 33 | `tutorial_blackjack_count_start` | correct | CAT:404; GUIDED; LIVE | Keep unchanged. |
| 34 | `tutorial_blackjack_count_all` | correct | CAT:422; GUIDED; LIVE | Keep unchanged. |
| 35 | `tutorial_blackjack_count_finish` | correct | CAT:434; GUIDED; LIVE | Keep unchanged. |
| 36 | `tutorial_heat_warning` | correct | CAT:446; GUIDED; LIVE | Keep unchanged. |
| 37 | `tutorial_leave_blackjack` | correct | CAT:458; GUIDED; LIVE | Keep unchanged. |
| 38 | `tutorial_drink_intro` | correct | CAT:470; GUIDED; LIVE | Keep unchanged. |
| 39 | `tutorial_accept_invitation` | correct | CAT:482; GUIDED; LIVE | Keep unchanged. |
| 40 | `tutorial_pal_goodbye_map` | correct | CAT:494; GUIDED; LIVE | Keep unchanged. |
| 41 | `tutorial_travel_grand` | correct | CAT:506; GUIDED; LIVE | Keep unchanged. |
| 42 | `tutorial_host_entry` | correct | CAT:518; GUIDED; LIVE | Keep unchanged. |
| 43 | `tutorial_rourke_intro` | correct | CAT:529; GUIDED; LIVE | Keep unchanged. |
| 44 | `tutorial_take_comp` | correct | CAT:540; GUIDED; LIVE | Keep unchanged. |
| 45 | `tutorial_enter_cage` | correct | CAT:552; GUIDED; LIVE | Keep unchanged. |
| 46 | `tutorial_open_linda` | correct | CAT:564; GUIDED; LIVE | Keep unchanged. |
| 47 | `tutorial_buy_cage_chips` | correct | CAT:576; GUIDED; LIVE | Keep unchanged. |
| 48 | `tutorial_cage_shop` | correct | CAT:588; GUIDED; LIVE | Keep unchanged. |
| 49 | `tutorial_return_main_floor` | correct | CAT:600; GUIDED; LIVE | Keep unchanged. |
| 50 | `tutorial_enter_grand_table` | correct | CAT:612; GUIDED; LIVE | Keep unchanged. |
| 51 | `tutorial_earn_bronze` | correct | CAT:624; GUIDED; LIVE | Keep unchanged. |
| 52 | `tutorial_leave_grand_table` | correct | CAT:636; GUIDED; LIVE | Keep unchanged. |
| 53 | `tutorial_return_cage` | correct | CAT:648; GUIDED; LIVE | Keep unchanged. |
| 54 | `tutorial_reopen_linda` | correct | CAT:660; GUIDED; LIVE | Keep unchanged. |
| 55 | `tutorial_claim_bronze` | correct | CAT:672; GUIDED; LIVE | Keep unchanged. |
| 56 | `tutorial_meta_home_card` | correct | CAT:684; GUIDED; LIVE | Keep unchanged. |
| 57 | `tip06_tonight_changes_rooms` | stale | CAT:697; PUBLIC | Split scenario-objective teaching from truthful rumor-use teaching; do not promise a rumor from scenario state alone. |
| 58 | `tip06_delivery_route` | stale | CAT:706; PUBLIC; LIVE | Narrow to a carried package route and add a distinct lookout-hold lesson at the hold boundary. |
| 59 | `tip06_numbers_book` | correct | CAT:716; PUBLIC | Keep unchanged; it stays on the honest public Numbers surface. |
| 60 | `tip06_crew_standing` | correct | CAT:725; PUBLIC | Keep; add missing back-room poker/tell teaching separately. |
| 61 | `tip06_coin_pusher` | stale | CAT:734; PUBLIC; LIVE | Rewrite for carriage drag, charged drop, stop, token cups, and heavy feature goals. |
| 62 | `tip06_craps_pass_line` | stale | CAT:743; PUBLIC; LIVE | Rewrite the accurate Pass rule together with the current grab/drag/release physical throw. |
| 63 | `tip06_venue_depth` | correct | CAT:752; PUBLIC | Keep unchanged; it preserves discovery without naming hidden rooms. |

## Authoring decisions unlocked by this classification

1. Rewrite the four stale contextual tips; do not retain conflated triggers or
   obsolete physical-game wording.
2. Preserve the 56 guided lessons byte-for-byte.
3. Add the smallest just-in-time normal-run lessons for back-room poker/tells,
   lookout holds, Police Sweep reading, scenario objectives, truthful rumor use,
   and the physical craps throw.
4. Prefer precise public predicates and actions over arrival-only triggers; a run
   that ignores Crew and never reaches these systems must see none of them.
