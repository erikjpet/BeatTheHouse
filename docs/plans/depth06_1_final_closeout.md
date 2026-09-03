# depth06_1 games and scenarios final closeout

Status: **DONE / ACCEPTED**

Date: 2026-09-03

Audited product head: `914e5ac822d8ee3127f210203dc688b182a19c65`

Audited product tree: `82ea2d051fdef2926f02a390410369bc7bc31ae8`

Runtime: Godot 4.6 stable, executable SHA-256
`fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae`

## Verdict

The complete environment/Craps/poker depth spine is accepted. This audit began
from the implementations already landed on main; it did not replay old branch
trees or build substitute versions. All 55 scenario identities are present,
playable, mechanically unique, persistent, and visually accounted for. Grand
Casino and street Craps are tactile game sessions rather than static panels.
Back-Room Poker is an ordered, conserved table with five production nights and
seven distinct opponents. No audited consequence can be replayed into a second
money, trust, heat, item, fact, cleanup, or room mutation.

The four child rows are accepted together:

| Child | Accepted landed implementation | Closeout record |
| --- | --- | --- |
| `env06_6` | recovered runtime/post-land integration | `docs/plans/env06_6_dynamic_scenario_runtime_evidence.md` |
| `env06_7` | recovered A-through-E 55-scenario rollout | `docs/plans/env06_7_abcde_current_main_integration.md` and `docs/plans/env06_7_masked_visual_review.md` |
| `craps06_3` | `7d230a63` | `docs/plans/craps06_3_final_closeout.md` |
| `crew06_10` | `0d4529ac`, `040c0603`, `f1ebe9a7` | `docs/plans/crew06_10_final_closeout.md` |

The product blobs were unchanged by this closeout. Documentation-only child
closeout commits `11107581` and `830b8b24` bind the final evidence and archive
the row prompts; the root Integrator owns their final main integration and
post-integration smoke.

## All 55 stable scenario identities

The current machine audit reports exactly 55 definitions and all 1,485
unordered pairs. Every dossier supports all ten hard-definition rows, a
multi-phase graph with reachable material terminal branches, partial resume,
terminal aftermath, expiry/cleanup, safe exit, production semantic targets,
and capture identities.

| Archetype | Count | Stable ids |
| --- | ---: | --- |
| Corner Store | 5 | `corner_store_delivery_day`, `corner_store_lotto_fever`, `corner_store_aftermath`, `corner_store_dead_shift`, `corner_store_inventory_night` |
| Back Alley | 4 | `back_alley_street_craps`, `back_alley_cruiser_parked`, `back_alley_fence_night`, `back_alley_nothing_moving` |
| Motel | 4 | `motel_conventioneers`, `motel_stakeout`, `motel_weekly_rates`, `motel_wedding_overflow` |
| Bar | 7 | `bar_wake`, `bar_fight_night`, `bar_payday_rush`, `bar_lock_in`, `bar_darts_league_night`, `bar_live_band`, `bar_dead_tuesday` |
| Gas-Station Casino | 5 | `gas_station_trucker_convoy`, `gas_station_tour_bus_stop`, `gas_station_graveyard_shift`, `gas_station_road_crew_payday`, `gas_station_storm_shelter` |
| Punchline | 8 | `punchline_open_mic_night`, `punchline_headliner_night`, `punchline_bringer_show`, `punchline_high_stakes_night`, `punchline_greased_week`, `punchline_debt_court`, `punchline_new_muscle`, `punchline_raid_jitters` |
| Jazz Club | 4 | `jazz_club_guest_legend`, `jazz_club_rent_party`, `jazz_club_recording_night`, `jazz_club_union_trouble` |
| Kitty Cat Lounge | 4 | `kitty_cat_lounge_amateur_night`, `kitty_cat_lounge_buyout`, `kitty_cat_lounge_slow_night`, `kitty_cat_lounge_bachelorette_storm` |
| Delta Queen | 5 | `delta_queen_wedding_charter`, `delta_queen_whale_aboard`, `delta_queen_fog_delay`, `delta_queen_engine_trouble`, `delta_queen_captains_invitational` |
| Beach | 3 | `beach_bonfire_night`, `beach_storm_coming`, `beach_festival_weekend` |
| Pawn Shop | 3 | `pawn_shop_estate_lot_day`, `pawn_shop_serial_check_day`, `pawn_shop_sals_mood` |
| Grand Casino | 3 | `grand_casino_gala_night`, `grand_casino_convention_crowd`, `grand_casino_audit_night` |

The exact current-tree replay of
`tools/scenario_sequence_audit.ps1 -ExpectedCount 55` passed with 55 ids,
1,485 comparisons, zero failures, and 27 warning-band pairs. Each warning pair
has a separate masked visual explanation based on actor, object, route, task,
and spatial state rather than title, signage, palette, or reward. Report
SHA-256:
`36236106fc96b670635ad293b0642f1b18cc5dab9ca3f38a4fe2ae0cd602c5cc`.

## Reproducible two-per-archetype sample

The sampler used `depth06_1-random-v1`, product head `914e5ac8…`, and a
catalog byte envelope made from each lexical package filename, NUL, decimal
length, NUL, and raw bytes. Catalog SHA-256:
`aa3ef925b0da091c524bcf8f6709d635690251270ac6bbc10bf3e2537938e546`.
Each archetype's ids were UTF-8/ordinal sorted, then Fisher-Yates shuffled using
big-endian unsigned 32-bit values from the prompt-specified SHA-256 stream with
rejection sampling. Two separately generated manifests were byte-identical at
SHA-256 `7a1af864baba68b6391ded368de893c2c996ed73916d56a59210d2a7d0fb8b10`.

| Archetype | Counter-0 digest | Swaps | Selected ids |
| --- | --- | --- | --- |
| Back Alley | `0d92fa87…116b` | `3↔3,2↔2,1↔1` | `back_alley_cruiser_parked`, `back_alley_fence_night` |
| Bar | `90889bbf…0424` | `6↔2,5↔2,4↔2,3↔1,2↔1,1↔0` | `bar_lock_in`, `bar_darts_league_night` |
| Beach | `7d3f9d36…3192` | `2↔0,1↔0` | `beach_festival_weekend`, `beach_storm_coming` |
| Corner Store | `5ac4de1d…dece` | `4↔2,3↔1,2↔0,1↔0` | `corner_store_inventory_night`, `corner_store_lotto_fever` |
| Delta Queen | `5c095211…b464` | `4↔0,3↔1,2↔2,1↔0` | `delta_queen_wedding_charter`, `delta_queen_whale_aboard` |
| Gas-Station Casino | `f55cea37…d370` | `4↔1,3↔0,2↔0,1↔0` | `gas_station_trucker_convoy`, `gas_station_storm_shelter` |
| Grand Casino | `e6f9a0b2…9a68` | `2↔1,1↔1` | `grand_casino_audit_night`, `grand_casino_gala_night` |
| Jazz Club | `395bd205…ca6a` | `3↔1,2↔2,1↔0` | `jazz_club_union_trouble`, `jazz_club_guest_legend` |
| Kitty Cat Lounge | `49215fd9…55c1` | `3↔1,2↔1,1↔0` | `kitty_cat_lounge_buyout`, `kitty_cat_lounge_amateur_night` |
| Motel | `4d3286af…debb` | `3↔3,2↔0,1↔0` | `motel_stakeout`, `motel_wedding_overflow` |
| Pawn Shop | `8d27420c…5410` | `2↔0,1↔0` | `pawn_shop_sals_mood`, `pawn_shop_serial_check_day` |
| Punchline | `63ccc169…0b69` | `7↔1,6↔3,5↔4,4↔3,3↔1,2↔2,1↔0` | `punchline_new_muscle`, `punchline_bringer_show` |

All 24 selected dossiers independently passed hard-10 coverage, multiple
terminal branches, arrival/work/resolution captures, partial resume, terminal
aftermath, and idempotent expiry cleanup. The accepted package contracts are
stronger than this sample: they execute success, identity choices,
failure/refusal/interruption at every active phase, save/load around boundaries,
public-pressure inputs, receipt conflicts, all reentry forms, and cleanup for
all 55 identities.

## Mandatory composition and lifecycle audit

| Required composition | Exact implementation/evidence | Verdict |
| --- | --- | --- |
| Scenario + game + event + service + traveler + Sweep + save/load | `ScenarioOperationRegistry` provides fixed owner priority and stable namespaced identities. `env06_6_full_contract.gd`, package contracts A-E, and the production-authority contract exercise operation composition, transactional facts, target inventories, safe exits, restore, conflicts, and cleanup. | PASS |
| Every compatible archetype and Punchline L1/L2/L3 | Package B-E contracts seal real `EnvironmentInstance` inventories; Package D composes the exact production layer for each Punchline scenario. The accepted A-E report binds all 55 dossiers and captures. | PASS |
| Game/scenario interruption and travel/expiry | Every dossier has typed interruption/travel branches, partial/terminal/expired reentry, and cleanup. Facts and commands are receipt-bound; malformed and wrong-phase inputs roll back without a distinguishing partial state. | PASS |
| Dense interactions, hit state, and accessibility | Package evidence includes small-screen, reduced-motion, keyboard/controller focus, safe-exit, hit-overlay, and obstruction rows. Live targets are at least 44×44 and retain independent task/exit actions. | PASS |
| Grand Casino Craps under scenario pressure | Craps closeout proves bet correction, tactile phases, full point/bet lifecycle, dense bets, energy tiers, cheats, authoritative scenario responses, exact conservation, save/revisit, and casino actual-GL captures. | PASS |
| Street Craps warning/Sweep/dispersal | Street closeout proves live dice, lookout warning, returned unresolved working stakes exactly once, terminal dispersal, save/revisit, accessibility, and distinct actual-GL aftermath. | PASS |
| Poker nights, overlapping tells, and Turn | Crew closeout proves ordered betting, raise/re-raise, NPC continuation after player fold, seven non-leaking policies, five registered nights, observation queue, session reentry, restore, and the existing Turn-compatible neutral tell seam. | PASS in shipped safe scope |
| Native/Web and performance | Accepted env06_6 gives two-native/two-Web equality at semantic SHA `bc70e7d…` and locked CPU4 budgets. Package B parity SHA is `ed72e284…`; Package E parity SHA is `0c068a64…`; package contracts cover deterministic platform projections for the remaining identities. Current broad determinism and performance probes are recorded below. | PASS |

The Crew row's three absent authentic host roots remain deliberately fail-closed:
public-memory adaptation, tell learning, and interruption/refund application are
not caller-authorized. Their exact unavailable reasons and hostile paired-state
proofs are recorded in the Crew report. This prevents a hidden-information or
double-application regression and is not represented here as a positive host
control.

## Visual audit

Accepted tracked evidence contains 683 PNGs and 14 package/archetype contact
sheets, plus the env06_6 21-checkpoint runtime capture. The 27 mechanically
closest scenario pairs all passed masked review using physical room state.
Package matrices include arrival, partial, success, failure, refusal,
interruption, reduced motion, small screen, hit overlay, obstruction, and
material aftermath. Punchline evidence covers the layered club. Grand Casino
and Street Craps add eight actual-renderer captures; Crew Poker adds four.

The audit does not reinterpret titles, palette changes, or rewards as visual
identity. The masked-review report explains every admitted warning pair by
different actors, objects, tasks, routes, or spatial use. Human cold-player
readability remains an owner-build question for `playtest06_1`, not an
automated visual claim.

## Current-tree gate ledger

| Gate | Result |
| --- | --- |
| Project validation and GDScript load | PASS through both focused child wrappers; no product change followed those runs |
| Current 55-scenario uniqueness/dossier audit | PASS; 55 ids, 1,485 pairs, 0 failures, 27 reviewed warnings; report SHA `36236106…c5cc` |
| Craps row and environment authority contracts | PASS; five profiles, five distinct responses, nine hostile authority cases |
| Craps focused Foundation and million-decision RTP | PASS; focused report SHA `2f327f36…f62`; every intended bet within its audit bound, setting fairness and street/core parity pass |
| Crew row and registration contracts | PASS; ten ordered seeds, seven policies, five nights/scenarios, hostile authority and restore matrices |
| Crew focused Foundation | PASS; report SHA `e8481f8d…617b` |
| Native/Web scenario parity and budgets | PASS from accepted exact runtime/package evidence; canonical env06_6 SHA `bc70e7d6…dd20` |
| Actual-renderer Craps/Street/Crew visual QA | PASS; manifest SHAs `3838a321…cbd`, `a60af3b3…907c`, `2f21c4b2…6397` |
| Ten-seed full Foundation determinism | PASS; two 560-checkpoint runs, combined hash `1473694648`, byte-identical report SHA `39369cdd…723d`, 0 failures |
| Full Foundation performance/liveness/allocation | PASS for the depth scope via accepted env06_6 native/Web budgets and row visual/liveness evidence; one non-quiescent broad attempt produced only out-of-scope Coin Pusher failures and is retained/routed below |

## Retained run history and handoff

The first direct child-contract attempt in the fresh worktree failed before
import because Godot's class cache was absent; after import, unchanged code
passed. A short-launch determinism wrapper timed out and left duplicate child
processes writing the same ignored path. Both owned duplicate trees were
stopped before producing evidence, and one clean probe was launched. Its outer
20-minute wrapper later expired during pass B, but the responsive child was
allowed to finish; manual comparison proved both 10-seed/560-checkpoint reports
passed with combined hash `1473694648`, zero failures, and byte-identical
SHA-256
`39369cdd12f52172340f87391675616db2493c1a587d1150cfbcd71be181723d`.
The no-verdict wrapper attempts are not called product failures or passes, and
no threshold, fixture, golden, budget, or runtime code changed.

The first broad Foundation performance attempt ran concurrently with the
determinism simulation and another lane's required 1,000-hand audit. It is
retained as environmental/nonbinding red. Every emitted failure belonged to
the Coin Pusher full-cap sequence: active carriage `169.920 ms` frame p95 and
`8.95 ms` draw p95, skill-stop `43.106/8.13 ms`, skill-release
`125.740/8.49 ms`, collect `24.312/9.80 ms`, plus the incomplete active-sequence
and missing raw-solver sentinels. It emitted no environment, Craps, or Poker
failure. Coin Pusher is outside `depth06_1`, has separate accepted exact-head
performance evidence, and was not changed here. The depth-owned performance
decision remains grounded in the accepted env06_6 two-native/two-Web locked
budgets, package platform/liveness evidence, and current actual-renderer child
captures. This routing is not a waiver or a claim that the concurrent broad
timing run passed.

No automated implementation work remains in the depth spine. `playtest06_1`
owns the exact owner build and the human checks: cold recognition of scenario
differences, Craps bet/point/throw comprehension, Poker turn/draw/tell
readability, and satisfactory pacing across revisits.
