# Tutorial verification

Date: 2026-08-01
Binding specification: `docs/todone/tutorial_guided_run_rework_prompt.md`
Verification output root: `.tmp/tut_verify/`

Implementation fix commit: `aadd80ee` (`fix tutorial first route and binding guidance`).

## Verdict

**TUTORIAL COMPLETE PER SPEC — all 20 proven.**

The verification was run independently against production data, modules, room generation, game actions, dialogue UI, and save serialization. It found and fixed one gameplay defect: the generated world map overrode the tutorial apartment override and revealed the gas casino before the corner-store beat. The first reveal is now constrained by the tutorial-only `tutorial_initial_map_targets` modifier. It also corrected four binding dialogue phrases and expanded the proof harness so the Cage capture uses its real generated shop stock.

## Requirement table

| # | Status | Proof |
|---:|:---:|---|
| 1 | PASS | All 48 tutorial lessons audit as `delivery=dialogue` and have non-empty coach anchors in `.tmp/tut_verify/tutorial_guided_run_audit.json`; production TalkDock + highlighted X-ray capture: `.tmp/tut_verify/captures/01_dialogue_highlight_apartment_pal.png`. |
| 2 | PASS | `authored_contract.ambient_tip_ids=[]` in `.tmp/tut_verify/tutorial_guided_run_audit.json`; `tools/tutorial_seed_audit.gd::_verify_authored_contract` rejects any `tip_first_*` or `tip_starter_card_home` lesson. Neither route emits an ambient lesson. |
| 3 | PASS | `docs/plans/0.5_voice_bible.md` defines Pal as the early-run guide and uses “your pal”; audited character is `pal_tutorial_guide`, display name `Pal`. In-character production capture: `01_dialogue_highlight_apartment_pal.png`. |
| 4 | PASS | Voice bible and character data define `Vivienne Vale` (`vivienne_grand_host`), distinct from Linda. Tutorial handoff: `13_grand_host_vivienne_reward_system.png`; normal-run production greeting: `18_normal_run_host_greeting.png`; isolation audit records `host_greeting_dialogue=normal_grand_host_greeting`. |
| 5 | PASS | Both driven routes start in `apartment`, expose only `xray_glasses`, buy it through `RunActionService`, and confirm it in run inventory. Capture: `02_apartment_xray_inventory.png`; route proof: `routes[*].apartment` in the JSON audit. |
| 6 | FIXED | Generated map discovery had exposed `gas_station_casino` at the apartment. Added tutorial-only `tutorial_initial_map_targets=[corner_store]` and a guarded first-reveal constraint in `RunGenerator`; both routes now report `first_destinations=[corner_store]`. Capture: `03_first_map_corner_store_only.png`; 100/100 tutorial traversal sweep starts with only Corner Store. |
| 7 | FIXED | Both actual store offers are inspected by the authored ordered lesson chain and one is bought through `RunActionService`; The Crew is present; the real family call/accept path creates debt; `follow_tip` sets `underground_tip` and reveals both branches. Binding copy was tightened to “last place you turn” and “may lead somewhere useful later.” Captures: `04_corner_family_loan_real_debt.png`, `05_parking_tip_opens_path_a_and_b.png`; assertions: `tutorial_seed_audit.gd::_run_route` and `check_core_content.gd::_check_onboarding_tutorial_arc`. |
| 8 | PASS | Authored Pal copy says `strongly recommend` and explicitly permits `skip`. Full `path_a` and `path_b_skip` driven audits both pass, claim Bronze, and end at `tutorial_bronze_card`; 100-run tutorial sweep alternates 50 of each with zero stuck states. |
| 9 | PASS | Path A uses the production pull-tab module, its X-ray target is ticket 3 from the top (`offset=2`, ticket `#011`, payout `$100`), buys/peels/files the stack, then redeems `$103` through the real clerk action. Captures: `06_path_a_xray_winner_near_bottom.png`, `07_path_a_clerk_payout_100.png`; JSON: `routes[0].pull_tabs`. |
| 10 | PASS | Production Blackjack surface places a normal hand, settles it, then creates a raised `$4` bet through the chip selector/deal action. Capture: `08_path_b_raised_bet_chips.png`; JSON fields: `normal_hand_settled=true`, `raised_bet=4`, `raised_deal_ok=true` on both routes. |
| 11 | FIXED | The driven test invokes the existing `blackjack_distraction` and `blackjack_peek` surface commands; both routes record a real `blackjack:drink_pass:*` lookaway and `peek_had_window=true`. Pal now explicitly calls it the easiest cheat, says Drink Pass spills a drink, and states caught heat/table-close consequences. Capture: `09_path_b_real_lookaway_peek.png`; copy assertions in both audit and FoundationSuite. |
| 12 | PASS | The driven Blackjack audit selects all real count icons, then independently expires all icons on a cloned hand and resolves `count_cards`; missed pulses add Heat (`38`/`70` depending route/capture). Capture: `11_path_b_count_miss_heat_warning.png` visibly shows missed bubbles, Heat 70, and Pal’s police-or-worse warning; JSON: `count_all_selected=true`, `count_miss_heat_delta>0`. |
| 13 | FIXED | The production invitation event resolves `accept_first_invitation`, sets `grand_casino_invite`, and both routes enter the Grand Casino. Pal copy now explicitly says to keep an eye on the environment, look at/open/accept the invite; departure copy says Pal is banned, warns about cheating/Rourke, says goodbye, and wishes luck. Capture: `12_high_roller_invitation_accept.png`; audit copy + route assertions. |
| 14 | PASS | Production captures show Vivienne taking over, explaining rewards (`13_grand_host_vivienne_reward_system.png`), and Rourke’s clean-play/“my casino” introduction (`14_rourke_clean_play_intro.png`). Character/dialogue identities are asserted by the authored-contract audit. |
| 15 | PASS | Tutorial config forces `comped_suite_offer=take_comp`; both driven routes resolve the real event and assert `grand_casino_event_comped_suite_offer_take_comp=true`. Capture: `15_forced_free_comp.png`. |
| 16 | PASS | Both routes enter the Cage through `RunGenerator.enter_grand_casino_room`, generate three real chips-only shop offers, buy 10 chips with `buy_grand_casino_chips`, and audit Linda’s extended cash/chips/debt-first cashout text. Capture `16_linda_extended_chips_shop_debt.png` visibly shows Chips 10, three shop offers, and the extended explanation. |
| 17 | PASS | Each route settles a real Grand Casino Blackjack hand using chips, reaches the tutorial-compressed Bronze eligibility, returns to Linda, claims Bronze, and ends via `tutorial_bronze_card`. Capture: `17_bronze_award_golden_card_goal.png`; route JSON has `players_card_awarded_tier=bronze` and `tutorial_end_route=tutorial_bronze_card`. |
| 18 | PASS | Authored-contract audit finds exactly one Rourke heat-threshold lesson at 85 and rejects an escalation ladder (`rourke_warning_levels=[85]`). The warning remains post-tutorial; there are no every-20 thresholds. |
| 19 | PASS | `.tmp/tut_verify/tutorial_guided_run_audit.json::normal_run_isolation` proves tutorial modifier keys absent, deterministic same-seed normal home/item JSON, normal family-phone chance `0.75`, identical unscripted pull-tab stock, normal Grand thresholds `30/5/30`, and card thresholds Bronze `1/5/30`, Silver `3/15/30`, Gold `5/30/30`. Only `normal_grand_host_greeting` is present; capture: `18_normal_run_host_greeting.png`. |
| 20 | PASS | Both routes restore the active Pal `map_corner` node and completed inventory step after `RunState.to_dict/from_dict`. Tutorial sweep: 100 iterations, 50 Path A + 50 skip, zero stuck. General stuck sweep: 100 seeds, zero stuck. Determinism: 10 seeds, two processes, 320 checkpoints each, identical hash `3634294742`. All gates below pass. |

## Both-route driven proof

The executable audit is `tools/tutorial_seed_audit.gd`; its machine-readable and concise reports are `.tmp/tut_verify/tutorial_guided_run_audit.json` and `.tmp/tut_verify/tutorial_guided_run_audit.md`.

| Route | Apartment/store | Optional pull tabs | Real Blackjack | Grand Casino | End |
|---|---|---|---|---|---|
| Path A | X-ray picked up; only Corner first; item bought; Crew present; family debt created; tip followed | X-ray target at offset 2; three tickets bought; `$103` clerk redemption | Normal hand settled; bet raised to `$4`; Drink Pass lookaway + peek; all-count and miss-heat paths resolved | Forced comp; Cage entered; 10 chips bought; table hand settled; Bronze claimed | `tutorial_bronze_card`, run ended, no soft-lock |
| Skip Path A | Same required apartment/store route | `skipped=true`; traveled directly to underground | Normal hand settled; bet raised to `$4`; real lookaway/peek; all-count and miss-heat paths resolved | Forced comp; Cage/chips/table/Bronze sequence identical | `tutorial_bronze_card`, run ended, no soft-lock |

## Normal-run isolation

The normal control uses a non-tutorial challenge config and fixed seeds. It compares serialized home/item generation and pull-tab machine state byte-for-byte across independent runs, asserts that every tutorial forcing key is absent, checks the authored normal loan chance and every normal card threshold, and separately verifies that merely supplying the tutorial pull-tab offset without `tutorial_run` cannot script stock. Result: PASS. The normal Host greeting is the sole deliberate normal-run addition.

## Gate results

| Gate | Result | Evidence |
|---|:---:|---|
| `tools/validate_project.ps1` | PASS | Foundation architecture validation passed on final source. |
| `check_godot.ps1 -FoundationSuite all -TimeoutSec 300` | PASS | `.tmp/tut_verify/gates/foundation_all_final/summary.json`; includes supported content/tutorial, systems, games, contracts, and UI checks. |
| Tutorial two-route audit | PASS | `.tmp/tut_verify/tutorial_guided_run_audit.json`; both routes ended; 100 alternating tutorial traversals, zero stuck. |
| `foundation_determinism_probe.ps1 -SeedCount 10` | PASS | `.tmp/foundation_determinism_probe/run_a.json`, `run_b.json`; 320 checkpoints, identical hash `3634294742`. |
| `foundation_stuck_state_sweep.ps1 -SeedCount 100` | PASS | Final gate console: 100 seeds, 48 slot scenarios, 9 wait scenarios, zero stuck. |
| `foundation_visual_qa.ps1` | PASS | `user://foundation_visual_qa_report.json` and `.tmp/tut_verify/gates/foundation_visual_qa_final.log`; production visual/input flow completed. |
| Tutorial production captures | PASS | 18 PNGs under `.tmp/tut_verify/captures/`; capture runner exited 0 and the key captures were visually inspected. |

No test, budget, determinism rule, zero-copy path, or idle-liveness threshold was weakened.
