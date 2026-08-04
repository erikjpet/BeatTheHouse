# 0.5 First-Time-Player Tutorial Completion Report

Date: 2026-08-03

Candidate branch: `agent/v05-pre-human-playtest-rework`

Scope: agent-verifiable pre-human completion; TUT-N17 remains human-only.

## Verdict

**PRE-HUMAN TUTORIAL CANDIDATE READY — TUT-N17 PENDING HUMAN.**

The authored tutorial now completes through the legitimate 1280x720 Web UI
with real pointer input for New Run and Replay Lessons, through both Path A and
the authored Path B skip. No generic Skip control, state injection, test-only
teleport, or save editing was used. The automated matrix is green. This is not
final tutorial approval: five cold-player sessions and their comprehension
checks are intentionally reserved for the owner/human playtest.

## Root causes and repairs

- Challenge entry was losing the authored Apartment home and starting the
  legacy ambient lesson chain. Challenge identity, home archetype, tutorial
  scope, and forced inventory are now established together for both entry
  paths; `tip_first_*` and Dealer's Advice are excluded from a guided run.
- Tutorial guidance previously owned input and used stale panel coordinates.
  The coach highlight is now visual and mouse-pass-through, resolves the live
  rendered target rectangle, follows camera/layout changes, and fails hidden
  when the target does not exist.
- TalkDock and modal lifecycles could overlap or survive navigation. Inventory,
  Run Menu, map, scene, and main-menu transitions now suspend, restore, or
  clear the tutorial presentation under explicit ownership rules.
- Action acknowledgements and ordinary dialogue could race the lesson state.
  Requested actions advance the matching lesson once, inventory waits for
  close before travel guidance, and the family-phone dialogue resumes the
  tutorial naturally.
- Several teaching beats were only labels. The authored copy and objectives
  now cover the run model, item behavior, debt math, pull-tab procedure,
  Blackjack basics, Peek/counting/Heat, Bronze progress, Grand Casino shopping,
  and the normal-run handoff. Long lines were shortened to fit the safe area.
- Environment reservation was computed differently by layout and rendering,
  causing false overlap failures and target drift. Both paths now use the same
  visibility-aware TalkDock reservation.

## Requirement traceability

| ID | Status | Proof |
| --- | --- | --- |
| TUT-N01 | PASS | Pal, Host, Rourke, Linda, choices, and responses fit the 1280x720 TalkDock; opening fit capture `new_run_path_b/01_apartment_opening_text_fit.png`; automated text-fit assertions pass in UI/all suites. |
| TUT-N02 | PASS | Dock reservation keeps the requested object visible; door/map and camera-shift captures `new_run_path_b/05_leave_highlight_tracks_camera.png` and `06_map_only_corner_store_dialogue_above.png`. |
| TUT-N03 | PASS | Apartment dialogue explains bankroll, $0/Heat loss, Drunk/time, items, spending/gambling/travel/debt, and Players Card purpose; current objective remains visible. |
| TUT-N04 | PASS | Deterministic Blackjack teaching covers 21, bust, comparison, values, Hit, Stand, wager selection, and wager lock before Peek/counting. Path captures begin at `new_run_path_b/20_real_drink_pass_lookaway.png`. |
| TUT-N05 | PASS | Authored perfect and miss/retry paths explain Heat risk, avoidance, recovery, and caught consequence; Replay Path A deliberately missed once, recovered without a soft-lock, then passed in `replay_path_a/09_count_complete.png`. |
| TUT-N06 | PASS | Result/objective output is cleared or replaced at travel, game, and guided-dialogue boundaries; the four route endings show no stale game result. |
| TUT-N07 | PASS | Linda's content is split and fitted; Bronze award, recap, persistence teaching, and first-night handoff are visible in `new_run_path_b/31_bronze_claimed.png`, `32_ending_persistence_teaching.png`, and `34_first_night_finished.png`. |
| TUT-N08 | PASS | X-ray inspection teaches effect/type and passive/active/equipped/consumable/permanent behavior plus the active slot; inventory action advances once (`new_run_path_b/04_inventory_open_advances_once.png`). |
| TUT-N09 | PASS | Store price/remaining bankroll and family loan/source/debt/cashout order are numerical; real loan capture `new_run_path_b/11_natural_phone_dialogue_resumes_tutorial.png`. |
| TUT-N10 | PASS | Path A teaches stack position/distance/cost and distinct Buy, Collect, Peel, File/Piles, Leave, and Redeem steps, including fixed-at-purchase outcome; `replay_path_a/07_scripted_xray_winner_revealed.png` and `08_winner_cashed_at_clerk.png`. |
| TUT-N11 | PASS | Blackjack guidance identifies cheat source/consumption, information benefit, count values/running benefit, miss penalty, and caught result; real lookaway, Peek, and all bubbles in `new_run_path_b/20_real_drink_pass_lookaway.png` through `22_all_count_bubbles_selected.png`. |
| TUT-N12 | PASS | Numerical Bronze progress reaches a clear return-to-Linda state; `new_run_path_b/30_bronze_ready_from_real_table_play.png` and `31_bronze_claimed.png`. |
| TUT-N13 | PASS | Linda cash/chips/shop/debt content is split; comp reward/storage is stated; chip purchase and one shop offer inspection are required and captured in `new_run_path_b/26_forced_comp_taken.png`, `28_linda_chips_bought.png`, and `29_gift_shop_checked.png`. |
| TUT-N14 | PASS | Guidance no longer disables unrelated input; unmet actions explain the live objective and keep the correct visual target highlighted. Strict rendered input and lifecycle sweep pass. |
| TUT-N15 | PASS | Map presents cost, time/open state, and route choice; first map exposes only Corner Store, later map only Gas Casino/Underground (`new_run_path_b/06_map_only_corner_store_dialogue_above.png`, `14_map_gas_or_underground_only.png`). |
| TUT-N16 | PASS | Repeated multi-step copy is shortened; dialogue advances on the requested action exactly once and waits for modal close where needed. |
| TUT-N17 | **PENDING HUMAN** | Requires five cold testers, including two without Blackjack knowledge, 5/5 unassisted completion, and at least 80% core-concept comprehension. No agent claim substitutes for this gate. |
| TUT-N18 | PASS | Clean-origin New Run and Replay Lessons deterministically render Apartment with the correct challenge/world/environment identity; captures `new_run_path_b/01_apartment_opening_text_fit.png` and `replay_path_a/02_apartment_start.png`; core-content assertions pass. |
| TUT-N19 | PASS | Guided scope emits Pal/TalkDock lessons and no Dealer's Advice or `tip_first_*`; scripted authored-contract report has an empty ambient ID list and both UI entry paths were inspected. |
| TUT-N20 | PASS | Apartment storage contains one forced X-ray Glasses item, pickup transfers once, inventory displays it, and boundary save/load neither loses nor duplicates it; normal-run isolation remains green. |
| TUT-N21 | PASS | Highlight tracks the current screen transform and actual hit region, is mouse-pass-through, and hides safely. Door, map, pull-tab, and invitation targets were clicked at the highlighted location in real-interface runs. |
| TUT-N22 | PASS | Inventory, Run Menu, map, scene, and main-menu ownership sweep passes; evidence `lifecycle/07_inventory_highlight_suppressed_fixed.png`, `08_run_menu_highlight_suppressed_fixed.png`, and `10_tutorial_main_menu_cleanup_fixed.png`. |
| TUT-N23 | PASS | Recovery advances to a valid live state and does not loop backward; automated missing/offscreen/modal/save-load/menu cases pass. Acceptance routes did not use generic Skip. |
| TUT-N24 | PASS | Requested and unrelated allowed actions remain usable under/after dialogue; each expected action resolves the matching dialogue once. Natural phone dialogue resumes the lesson (`replay_path_a/04_phone_natural_dialogue_resumed.png`). |
| TUT-N25 | PASS | Scene labels and secondary object text use the raised-contrast palette and remain readable at 1280x720 across the captured matrix; visual QA passes. |

## Real-interface route matrix

All paths used a fresh Web debug export and actual UI pointer input at
1280x720.

| Entry | Route | Result | Evidence root |
| --- | --- | --- | --- |
| Clean-origin New Run | Path A | PASS; Bronze, recap, tutorial end, no intervention | `.tmp/v05_prehuman_real_interface/path_a_rerun/` |
| Clean-origin New Run | Path B authored optional skip | PASS; Bronze, recap, tutorial end, no intervention | `.tmp/v05_prehuman_real_interface/new_run_path_b/` |
| Replay Lessons | Path A | PASS; real pull-tab winner/cashout, count recovery, Bronze, tutorial end | `.tmp/v05_prehuman_real_interface/replay_path_a/` |
| Replay Lessons | Path B authored optional skip | PASS; Bronze and tutorial end, no intervention | `.tmp/v05_prehuman_real_interface/path_b/` |

The full matrix covers Apartment/storage/inventory, camera-shifted door and
map, Corner Store purchase/loan, both optional paths, Underground Blackjack,
real lookaway/Peek/counting, invitation, Grand Casino Host/Rourke/comp/Linda/
chips/shop/Bronze, completion, and normal-run handoff. Modal lifecycle evidence
is under `.tmp/v05_prehuman_real_interface/lifecycle/`. The final clean export
log is `.tmp/v05_prehuman_real_interface/mirrored_routes_final_clean_export.log`.

## Exact-source automated results

| Gate | Result | Evidence |
| --- | --- | --- |
| Project validation | PASS | `.tmp/v05_prehuman_phase2/validate_exact_source.log` |
| Every FoundationSuite (`all`) | PASS | `.tmp/v05_prehuman_phase2/foundation_all_exact_source.log` and latest `.tmp/test_reports/*/summary.json` |
| Two scripted routes | PASS | `.tmp/v05_prehuman_phase2/tutorial_exact_source/tutorial_guided_run_audit.json` |
| Tutorial alternating traversal sweep | PASS, 100/100 | same audit report |
| Lesson-boundary save/load | PASS | same audit report |
| Normal-run isolation | PASS | same audit report; home/item spawns, loans, pull-tab stock, and card thresholds retain normal behavior |
| Determinism | PASS, 10 seeds/two processes | `.tmp/v05_prehuman_phase2/determinism_exact_source.log`, `.tmp/foundation_determinism_probe/run_a.json`, `run_b.json` |
| General stuck-state sweep | PASS, 100 seeds | `.tmp/v05_prehuman_phase2/stuck_100_exact_source.log` |
| Visual QA | PASS | `.tmp/v05_prehuman_phase2/visual_qa_exact_source.log` |
| Strict rendered mouse batch | PASS, 2/2, zero true failures | `.tmp/v05_prehuman_phase2/strict_mouse_exact_source/aggregate_summary.json` |

## Human gate preparation

For each of five cold players, start from a clean profile, record route choice
and whether they complete without assistance, then ask them to explain: the
run win/loss conditions; Bankroll versus chips; Heat and Drunk; item types and
active slot; debt/cashout order; fixed-at-purchase pull tabs; Blackjack Hit,
Stand, bust and wager lock; Peek/counting risk; Players Card progress; and the
next normal-run goal. Two participants must begin without Blackjack knowledge.
TUT-N17 passes only at 5/5 unassisted completion and at least 80% aggregate
core-concept comprehension.
