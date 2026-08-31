# teach06_2 current lesson audit (dependency-held pre-stage)

Status: **UNREVIEWED — do not use as acceptance evidence**  
Trace base: `9ea919fe9b53ab3ae37e085ed462febaa8ad76f8`  
Catalog: `data/tutorial/lessons.json` (63 entries: 56 `tutorial_run`, 7 `normal_run`)

This is the section 1 classification artifact only. It makes no product, lesson,
coach, runtime, or test change. The required `depth06_1`, `game06_8`, and
`world06_7` heads are not on this base, so this audit deliberately does not
authorize lesson edits or final acceptance. No runtime or expensive gate was run.

## Result

| Classification | Count |
| --- | ---: |
| correct | 62 |
| stale | 1 |
| redundant | 0 |
| broken | 0 |

`tip06_coin_pusher` is stale on the current base: its copy teaches a paid drop,
lane aim, and nudges, while the current public surface exposes a draggable
carriage and a hold-to-charge drop. It must be rewritten or retired only after
the physical-game dependencies land. No lesson is classified redundant from a
static trace: diegetic sufficiency requires the dependency-complete cold run.

## Evidence and dependency legend

- **CAT** — exact authored entry and trigger/anchor/copy at the cited line in
  `data/tutorial/lessons.json`.
- **SEQ** — the contract freezes the exact 56 guided IDs and seven contextual
  IDs (`scripts/tests/foundation/onboarding_06_contract.gd:7-31,89-90`).
- **GUIDE** — current static assertions cover dialogue delivery, map anchors,
  Blackjack boundaries, Cage placement, Heat, and drink sequencing
  (`scripts/tests/foundation/check_core_content.gd:3848-3938`). Recovery stress
  traverses every authored guided frontier
  (`scripts/tests/tutorial_guardrail_recovery_stress_check.gd:35-60`).
- **PTAB** — the authored pull-tab action IDs remain live command boundaries
  (`scripts/tests/foundation/check_table_games.gd:5691-5733,5818-5865`).
- **BJ** — current Blackjack maps and renders the authored action IDs
  (`scripts/games/blackjack.gd:539-567,2253-2325,2937`).
- **CTX** — current positive/negative contextual matrices are at
  `scripts/tests/foundation/onboarding_06_contract.gd:97-135`; the public context
  is projected at `scripts/ui/coach_overlay.gd:300-318`.
- **PUSH** — current coin-pusher public verbs are `coin_pusher_carriage_drag` and
  `coin_pusher_drop_charge` (`scripts/games/coin_pusher.gd:6,233-249`), rendered
  as drag and hold regions
  (`scripts/games/coin_pusher/coin_pusher_renderer.gd:589,623`).
- **D1** — re-audit after `depth06_1`; **G8** — re-audit after `game06_8`;
  **W7** — re-audit after `world06_7`; **—** — no known dependency-owned surface.

“Correct” below means the copy, trigger, and target agree with the code on the
trace base. It is not a claim that dependency-complete pointer placement,
diegetic redundancy, density, or cold-run order has passed.

## All 63 existing lessons

| # | Lesson | Class | Exact current trace | Unresolved dependency | Disposition |
| ---: | --- | --- | --- | --- | --- |
| 1 | `tutorial_apartment_xray` | correct | CAT:3-10; SEQ; GUIDE | W7 | Keep; re-trace world anchor. |
| 2 | `tutorial_inventory_xray` | correct | CAT:15-22; SEQ; GUIDE | — | Keep. |
| 3 | `tutorial_open_map_corner` | correct | CAT:27-34; SEQ; GUIDE | W7 | Keep; re-trace travel surface. |
| 4 | `tutorial_travel_corner` | correct | CAT:39-46; SEQ; GUIDE | W7 | Keep; re-trace route target. |
| 5 | `tutorial_inspect_coffee` | correct | CAT:51-59; SEQ; GUIDE | W7 | Keep; re-trace fixture. |
| 6 | `tutorial_inspect_pencil` | correct | CAT:64-71; SEQ; GUIDE | W7 | Keep; re-trace fixture. |
| 7 | `tutorial_buy_store_item` | correct | CAT:76-83; SEQ; GUIDE | W7 | Keep; re-trace fixture. |
| 8 | `tutorial_buy_remaining_store_item` | correct | CAT:88-99; SEQ; GUIDE | W7 | Keep; re-trace conditional anchor. |
| 9 | `tutorial_crew_warning` | correct | CAT:104-111; SEQ; GUIDE | W7 | Keep; re-trace crew handoff. |
| 10 | `tutorial_family_phone` | correct | CAT:115-122; SEQ; GUIDE | W7 | Keep; re-trace event fixture. |
| 11 | `tutorial_family_debt` | correct | CAT:127-134; SEQ; GUIDE | — | Keep. |
| 12 | `tutorial_parking_tip` | correct | CAT:138-145; SEQ; GUIDE | W7 | Keep; re-trace event fixture. |
| 13 | `tutorial_route_map` | correct | CAT:150-157; SEQ; GUIDE | W7 | Keep; re-trace route choice. |
| 14 | `tutorial_route_choice` | correct | CAT:162-169; SEQ; GUIDE | W7 | Keep; re-trace route target. |
| 15 | `tutorial_gas_machine` | correct | CAT:174-181; SEQ; PTAB | D1,G8,W7 | Re-trace game entry and diegetic need. |
| 16 | `tutorial_gas_peek` | correct | CAT:186-195; SEQ; PTAB | D1,G8 | Re-trace physical verb and exact Heat copy. |
| 17 | `tutorial_gas_peek_heat` | correct | CAT:198-205; SEQ; GUIDE | D1,G8 | Re-trace physical sequence. |
| 18 | `tutorial_gas_xray_buy` | correct | CAT:209-224; SEQ; PTAB | D1,G8 | Re-trace buy/collect verbs. |
| 19 | `tutorial_gas_peel` | correct | CAT:227-246; SEQ; PTAB | D1,G8 | Re-trace reveal/file verbs. |
| 20 | `tutorial_gas_leave_machine` | correct | CAT:249-256; SEQ; PTAB | D1,G8 | Re-trace surface exit. |
| 21 | `tutorial_gas_redeem` | correct | CAT:261-268; SEQ; GUIDE | D1,G8,W7 | Re-trace redeemer fixture. |
| 22 | `tutorial_gas_map_underground` | correct | CAT:273-280; SEQ; GUIDE | W7 | Re-trace travel surface. |
| 23 | `tutorial_gas_travel_underground` | correct | CAT:285-292; SEQ; GUIDE | W7 | Re-trace route target. |
| 24 | `tutorial_underground_table` | correct | CAT:297-304; SEQ; BJ | D1,G8,W7 | Re-trace game entry and diegetic need. |
| 25 | `tutorial_blackjack_clean_deal` | correct | CAT:309-318; SEQ; BJ; GUIDE | D1,G8 | Re-trace physical deal. |
| 26 | `tutorial_blackjack_clean_finish` | correct | CAT:321-330; SEQ; BJ; GUIDE | D1,G8 | Re-trace hit/stand. |
| 27 | `tutorial_blackjack_raise` | correct | CAT:333-342; SEQ; BJ; GUIDE | D1,G8 | Re-trace chip control. |
| 28 | `tutorial_blackjack_raised_deal` | correct | CAT:345-354; SEQ; BJ; GUIDE | D1,G8 | Re-trace physical deal. |
| 29 | `tutorial_blackjack_heat_precheck` | correct | CAT:357-364; SEQ; GUIDE | D1,G8 | Re-trace timing/diegetic need. |
| 30 | `tutorial_blackjack_lookaway` | correct | CAT:368-375; SEQ; BJ; GUIDE | D1,G8 | Re-trace distraction verb. |
| 31 | `tutorial_blackjack_peek` | correct | CAT:380-389; SEQ; BJ; GUIDE | D1,G8 | Re-trace lookaway target. |
| 32 | `tutorial_blackjack_peek_finish` | correct | CAT:392-401; SEQ; BJ; GUIDE | D1,G8 | Re-trace finish controls. |
| 33 | `tutorial_blackjack_count_start` | correct | CAT:404-419; SEQ; BJ; GUIDE | D1,G8 | Re-trace count toggle/deal. |
| 34 | `tutorial_blackjack_count_all` | correct | CAT:422-431; SEQ; BJ; GUIDE | D1,G8 | Re-trace count bubbles. |
| 35 | `tutorial_blackjack_count_finish` | correct | CAT:434-443; SEQ; BJ; GUIDE | D1,G8 | Re-trace finish boundary. |
| 36 | `tutorial_heat_warning` | correct | CAT:446-454; SEQ; GUIDE | D1,G8 | Re-trace timing/density. |
| 37 | `tutorial_leave_blackjack` | correct | CAT:458-467; SEQ; BJ; GUIDE | D1,G8 | Re-trace surface exit. |
| 38 | `tutorial_drink_intro` | correct | CAT:470-477; SEQ; GUIDE | W7 | Re-trace service fixture. |
| 39 | `tutorial_accept_invitation` | correct | CAT:482-489; SEQ; GUIDE | W7 | Re-trace event fixture. |
| 40 | `tutorial_pal_goodbye_map` | correct | CAT:494-501; SEQ; GUIDE | W7 | Re-trace travel surface. |
| 41 | `tutorial_travel_grand` | correct | CAT:506-513; SEQ; GUIDE | W7 | Re-trace route target. |
| 42 | `tutorial_host_entry` | correct | CAT:518-525; SEQ; GUIDE | W7 | Re-trace host fixture. |
| 43 | `tutorial_rourke_intro` | correct | CAT:529-536; SEQ; GUIDE | W7 | Re-trace host/Heat sequence. |
| 44 | `tutorial_take_comp` | correct | CAT:540-547; SEQ; GUIDE | W7 | Re-trace event fixture. |
| 45 | `tutorial_enter_cage` | correct | CAT:552-559; SEQ; GUIDE | W7 | Re-trace depth route. |
| 46 | `tutorial_open_linda` | correct | CAT:564-571; SEQ; GUIDE | W7 | Re-trace Cage fixture. |
| 47 | `tutorial_buy_cage_chips` | correct | CAT:576-583; SEQ; GUIDE | W7 | Re-trace counter surface. |
| 48 | `tutorial_cage_shop` | correct | CAT:588-595; SEQ; GUIDE | W7 | Re-trace item placement. |
| 49 | `tutorial_return_main_floor` | correct | CAT:600-607; SEQ; GUIDE | W7 | Re-trace depth route. |
| 50 | `tutorial_enter_grand_table` | correct | CAT:612-619; SEQ; BJ; GUIDE | D1,G8,W7 | Re-trace game entry and diegetic need. |
| 51 | `tutorial_earn_bronze` | correct | CAT:624-631; SEQ; BJ; GUIDE | D1,G8,W7 | Re-trace settlement objective. |
| 52 | `tutorial_leave_grand_table` | correct | CAT:636-643; SEQ; BJ; GUIDE | D1,G8 | Re-trace surface exit. |
| 53 | `tutorial_return_cage` | correct | CAT:648-655; SEQ; GUIDE | W7 | Re-trace depth route. |
| 54 | `tutorial_reopen_linda` | correct | CAT:660-667; SEQ; GUIDE | W7 | Re-trace Cage fixture. |
| 55 | `tutorial_claim_bronze` | correct | CAT:672-679; SEQ; GUIDE | W7 | Re-trace objective handoff. |
| 56 | `tutorial_meta_home_card` | correct | CAT:684-691; SEQ; GUIDE | — | Keep. |
| 57 | `tip06_tonight_changes_rooms` | correct | CAT:697-702; CTX | W7 | Keep pending scenario/rumor re-trace. |
| 58 | `tip06_delivery_route` | correct | CAT:706-711; CTX | W7 | Keep pending delivery/route re-trace. |
| 59 | `tip06_numbers_book` | correct | CAT:716-721; CTX | W7 | Keep pending world-truth/secrecy re-trace. |
| 60 | `tip06_crew_standing` | correct | CAT:725-730; CTX | W7 | Keep pending trust-ladder re-trace. |
| 61 | `tip06_coin_pusher` | stale | CAT:734-739; PUSH | D1,G8 | Rewrite or retire after dependency-complete surface/cold run. |
| 62 | `tip06_craps_pass_line` | correct | CAT:743-748; CTX | D1,G8 | Keep pending physical craps/diegetic re-trace. |
| 63 | `tip06_venue_depth` | correct | CAT:752-757; CTX | W7 | Keep pending venue-depth re-trace. |

## Required dependency-complete follow-up

Before any lesson is edited, all three required rows must be DONE and their
accepted heads must be present. Then:

1. Re-run the 63-row trace against the landed surfaces, resolving every D1/G8/W7
   marker and explicitly deciding whether each physical-game lesson became
   redundant.
2. Play the cold first run and crew-ignoring run, and perform pointer/overlap QA
   at 1280×720, small screen, and reduced motion. Static evidence above cannot
   establish those properties.
3. Resolve `tip06_coin_pusher` first; its current wording must not ship unchanged.
4. Only after the updated classification is accepted may section 2 add, modify,
   or retire lessons and extend the existing tests.
