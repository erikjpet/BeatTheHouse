# Playtest Fixes 03 — Post-fix player replay repairs

**Status:** COMPLETE — fixes remain uncommitted for independent re-audit  
**Date:** 2026-09-13  
**Worktree:** `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes`  
**Branch:** `codex/agent-playtest-fixes`  
**HEAD:** `56de66598a2bcdbc3f171f090b48c361daf35563`  
**Inherited fingerprint:** `45add38e02d9de93e2ecae3f2092f32714ab5431`  
**Final fingerprint:** `b9d78d8d0bc676de82be656dff15f4e07143e06b`

**Historical disposition:** The fixes were subsequently accepted and
integrated into `main`. Absolute worktree and `.tmp` links below preserve the
recorded evidence locations but no longer resolve after deliberate temporary
worktree cleanup.

## Baseline

The inherited worktree contained the combined uncommitted Fixes 01+02 patch: 30 tracked files, +741/−107, plus the inherited fixture/harness files. No file was staged. The complete inherited diff was inspected before edits and preserved except where a failed player-visible fix was deliberately extended.

| Gate | Baseline result |
|---|---|
| `validate_project.ps1` | PASS — 109 s |
| Smoke | TIMEOUT — external 364 s ceiling; same inherited slow content/native process class |
| `playtest_fixes01_regressions` | PASS — 2.449 s, 0 failures |
| `playtest_fixes02_regressions` | PASS — 84 ms, 0 failures |

## Summary

All 13 owned findings are fixed or re-verified. The 12 product-fix items passed the required visible replay twice. BUG-26 failed when finally reached through the production projection, was corrected at the allowed view-model boundary, then passed twice. There are no unresolved owner decisions in this prompt's scope.

| Bug | Class; root cause | Fixed? | Regression | Visible replay | Fixes 03 files | Before / after |
|---|---|---:|---|---|---|---|
| BUG-07 | VALID — `coach_overlay.gd:_consume_blocked_pointer_input:426` recognized the coach only, then TalkDock only; skipped phone guidance could also queue debt before its predicates. | Yes | `playtest_fixes03_regressions`; follow-up red/green; 1,622-boundary stress | 2/2 mouse+keyboard, shield, phone, debt gating | `coach_overlay.gd`, `foundation_main.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0056.png) / [after A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug07_guard_a1/0034.png), [after B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug07_guard_b1/0042.png) |
| BUG-08 | VALID — `foundation_main.gd:_publish_numbers_result:18680` published feedback without the canonical structured-HUD render. | Yes | rendered HUD bankroll/delta | 2/2 — $87/−1 | `foundation_main.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_c5/0044.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug08_green_a/0094.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug08_green_b/0040.png) |
| BUG-09 | VALID — same stale HUD boundary as BUG-08 after Silas's one-time tip. | Yes | rendered HUD bankroll/delta plus one-time guard | 2/2 — $38/−12 and $43/−12 | `foundation_main.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_c6/0102.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug09_a/0161.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug09_b/0070.png) |
| BUG-12 | VALID — `foundation_main.gd:_present_item_purchase_result:5618` cleared the offer, but tutorial refresh reselected it; explicit later player focus was not distinguished from tutorial focus. | Yes | purchase-result ownership plus real canvas-focus continuation | 2/2 — sold card cleared, no Buy; UI flow green to next item | `foundation_main.gd`, UI flow test | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_c1/0016.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug12_b/0014.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug12_c/0013.png) |
| BUG-19 | VALID — disabled seed state had no dedicated visible status control. | Yes | setup-builder/status-label assertion | 2/2 | `foundation_main.gd`, `foundation_screen_builder.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_d3/0003.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug19_green_a/0002.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug19_23_green_b/0002.png) |
| BUG-23 | VALID — `settings_menu.gd:_build:81` trapped focus but its `ScrollContainer` did not follow it. | Yes | real `follow_focus` control assertion | 2/2, including small-screen | `settings_menu.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_d2/0025.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug23_green_a/0016.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug19_23_green_b/0016.png) |
| BUG-30 | VALID-DIFFERENT-CAUSE — `talk_dock.gd:_speaker_display_name:1136` overwrote a hydrated faceless caller with `Unknown Caller`. | Yes | production Counter Phone chain to rendered nameplate | 2/2 — Gabe Mercer | `talk_dock.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_c3/0036.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug07_guard_a1/0034.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug07_guard_b1/0042.png) |
| BUG-31 | VALID-DIFFERENT-CAUSE — event-chain choices lost exact terms between `event_module.gd:_lender_terms_choice:92`, action projection, and `foundation_main.gd:_lender_conversation_option:13840`. | Yes | exact non-cash terms survive offer/confirm/result | 2/2 — $45, two favors, 0%, two turns | `event_module.gd`, `foundation_action_view_model.gd`, `foundation_main.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/verify31_c2/0078.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_d1/0115.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_d5/0081.png) |
| BUG-32 | VALID — `blackjack.gd:_sync_count_challenge_icons:7132` derived pulse identity from unstable/card-colliding data after HIT. | Yes | unique persisted pulse IDs, hit registration, split/dealer coverage | 2/2 — post-HIT icon clickable | `blackjack.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_b2/0176.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug32_green_c/0030.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug32_green_d/0029.png) |
| BUG-33 | VALID — `foundation_main.gd:_challenge_with_meta_home_for_run:15725` overwrote an explicit home with profile meta defaults. | Yes | explicit-vs-absent precedence | 2/2 Motel plus Apartment | `foundation_main.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_d2/0064.png) / [Motel](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_d1/0103.png), [Apartment](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_c2/0122.png) |
| BUG-35 | VALID — `slot.gd:_slot_bonus_watchdog_status:1847` deferred a drained feature; `pinball_feature.gd:live_status:343` read a copied stale launched count; intermediate live steps could pay accumulated award early. | Yes | zero-ball due status, runtime simulator count, completion-only award | 2/2 — automatic settle, one $22 payout, no zero-ball Launch | three Pinball/Slot files plus `slot.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_b4/0049.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug35_fix_a/0026.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug35_fix_b/0026.png) |
| BUG-36 | VALID — Craps working bets did not persist funding source, and Grand Casino routing reclassified the refund as chips. | Yes | cash/chip/street/interruption/save migration matrix | 2/2 — $5 returned to cash, chips unchanged | `craps.gd`, `run_state.gd`, `foundation_main.gd` | [before](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/claim06_b5/0021.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug36_green_b/0023.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug36_green_c/0023.png) |
| BUG-26 | VALID-DIFFERENT-CAUSE — the inherited dedup handled the synthetic record, but production rewrote it to `scenario_sequence`/`owner_namespace=scenario` after the view-model pass. | Yes | production-shape list dedup | RED 2/2, then GREEN 2/2 through resolution without travel | `environment_interaction_view_model.gd`, `foundation_main.gd`, Fixes 02 contract | [red](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug26_green_a1/0044.png) / [A](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug26_green_c2/0046.png), [B](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/fixes03_bug26_green_d2/0045.png) |

## Why the prior fixes missed

- BUG-07: test asserted the shield blocks a covered rectangle at `coach_overlay.gd:_consume_blocked_pointer_input`; player sees TalkDock and selected inline room controls resolved through separate owners. The old protection test was kept and expanded to ownership plus dependent-predicate behavior.
- BUG-08: test asserted canonical bankroll/result publication at `run_state.gd:numbers_buy_slip`; player sees the structured HUD from `foundation_main.gd:_refresh_embedded_action_hud`. The assertion moved to a rendered-HUD probe.
- BUG-09: test asserted one-time purchase state and result dictionary at `run_state.gd:numbers_buy_silas_tip`; player sees stale HUD money/delta. The old guard was kept and rendered-HUD coverage added.
- BUG-12: test asserted source ordering in `_apply_item_offer_after_input_guard`; player sees a re-entrant tutorial refocus/cached selected card. The test moved to `_present_item_purchase_result`, result ownership, and the real canvas focus callback.
- BUG-19: test asserted that the seed field was disabled; player sees no reason beside it. The old check was expanded to require the dedicated visible label.
- BUG-23: test asserted modal focus trapping; player sees focus move below the viewport. The old trap test was kept and the real `ScrollContainer.follow_focus` state added.
- BUG-30: test asserted the chained queue entry was hydrated; player sees `TalkDock._speaker_display_name` replace the hydrated faceless caller with Unknown. The queue test was kept and a production rendered-nameplate test added.
- BUG-31: test asserted exact terms on ordinary lender records; player sees an event-chain choice whose action view-model dropped terms. Ordinary lender coverage was kept and the event-chain offer/confirm/result path added.

## Per-bug records

### BUG-07

The inherited failure was visible in `verify31_d1` and the historical Pal-over-Straight capture. The repair registers TalkDock as a tutorial input owner while leaving empty dock/room space blocked. A no-regression run then exposed a second-order defect: skipping the phone pointer marked its dependency seen, and `_queue_frontier_guardrail` queued debt guidance using only surface/dependency checks. A focused contract failed before the predicate repair and passed after it: [red](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes03/bug07_followup_red.log), [green](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes03/bug07_followup_green.log).

Fresh A/B sessions passed mouse and keyboard TalkDock choices, unrelated Numbers-object shielding, phone Skip-tip with debt still absent, `Make the call`, and debt guidance only after confirmation. The exact historical Pal/OptionButton overlap could not be recreated because Pal was no longer open when Numbers Book appeared; the generic live shield plus the direct covered-control contract cover that protection without claiming a fresh intersecting screenshot.

### BUG-08 / BUG-09

Both handlers now end at the canonical embedded HUD refresh. No second manual wallet writer was added. BUG-09's one-time knowledge/disabled-option guard remains intact. Same-frame screenshots and JSON agree with canonical bankroll and current-action delta in both fresh runs per bug.

### BUG-12

Purchase presentation now clears spatial selection before showing the result and holds that boundary against tutorial re-entry. A later deliberate canvas click clears the pending result and enters the selected room object; programmatic tutorial focus does not. The original double-click path passed twice with no stale Buy action. The first UI rerun exposed the old internal-focus test path; after moving it to the real canvas callback, UI advanced to the known Path A failure.

### BUG-19 / BUG-23

The start screen now shows a short fixed-lesson-seed line beside the disabled field. Settings uses `follow_focus`; Tab/Shift-Tab reached the low controls at 1280×720 and the compact pass kept the focused control visible.

### BUG-30 / BUG-31

Faceless delivery no longer forces Unknown over a hydrated speaker. Both final phone runs rendered `Gabe Mercer — Brother-in-Law`. Event-chain loan choices now carry the same exact terms object used to create the obligation through action projection into the confirmation. The two visible Crew-chain runs selected Rook and Bishop dynamically and each showed `Borrow $45. Repay 2 favors (0% cash interest) in 2 turns`; direct production-chain coverage holds the exact Lucky-shaped data case. Authored voice remains beside terms.

### BUG-32

Counting pulses use source-aware card identity plus a persisted monotonic, collision-checked serial. The post-HIT ninth pulse registered and accepted input in both runs; contracts also cover split/dealer/save identity. Heat/surveillance rules were not changed.

### BUG-33

Meta home defaults apply only when the start configuration has no explicit `home_archetype_id`. Two Motel starts retained motel state/tenure objects. An additional fresh Apartment selection survived closing/reopening setup and started in Apartment with all 14 content groups intact.

### BUG-35

The watchdog settles zero-live-work Pinball on the next host tick. `live_status` reads the live simulator's launched count without copying collections, and incomplete live actions publish zero award so the accumulated total pays once at completion. Both runs finished `LEFT 0 / LIVE 0`, removed Launch, applied $22 once, did not repay on another tick, and retained the bankroll after leaving.

### BUG-36

Working bets store a versioned funding map. Placement allocates cash/chips, settlement reconciles the record, take-down/interruption refunds by that record, and `currency_deltas_final` prevents Grand Casino host routing from converting it again. Direct coverage includes cash-funded casino, chip-funded Grand Casino, street, interruption, migration, and save round trip. Both player runs returned $5 to bankroll with chips still zero.

### BUG-26

The first two production replays proved the instruction still duplicated after controller projection. The final list boundary now normalizes production `scenario*` ownership and removes only semantically identical action-summary copy. Both green runs displayed the contested-lot instruction once, advanced arrival → work → authentication → resolution/aftermath in Wet Alley, and did not travel.

## Not fixed / owner decisions

None within BUG-07, 08, 09, 12, 19, 23, 26, 30, 31, 32, 33, 35, or 36.

## Held for spawn-slot work

BUG-10, BUG-34, and BUG-37 were not changed. The Fixes 01/02 worktree already contains inherited modifications in `environment_interaction_controller.gd` and `pixel_scene_canvas.gd`; Fixes 03 did not edit those held hunks. The broad contracts still report placement/label collisions and the UI Path A fixture still omits Apartment, consistent with the separate spawn-slot owner.

## Overlap notes

Fixes 03 lines in shared inherited files are limited to these functions:

- `coach_overlay.gd`: `notify_dialogue_completed`, `_render_active`, `_dialogue_acknowledged_instruction`, tutorial input-owner helpers, `_queue_frontier_guardrail`. Inherited BUG-06 acknowledgement behavior remains.
- `foundation_main.gd`: `_build_coach_overlay`, `_on_environment_object_focused`, `_present_item_purchase_result`, `_publish_numbers_result`, `_lender_conversation_option`, `_interactable_object_view_list`, `_challenge_with_meta_home_for_run`, `_refresh_start_screen`, `_mandatory_tutorial_seed_locked`, `_focus_tutorial_corner_store_purchase_lesson`, `_item_purchase_result_owns_room_focus`, and wager-funding handoff in `_resolve_game_action`. Other Fixes 01/02 lifecycle/HUD/result hunks remain.
- `event_module.gd`: `_lender_terms_choice` only; triggered-entry hydration is inherited Fixes 02.
- `run_state.gd`: `route_grand_casino_game_currency` final-delta branch; Numbers state/result changes are inherited Fixes 01.
- `blackjack.gd`: count pulse identity/sync fields around `_sync_count_challenge_icons`; round-net presentation changes are inherited Fixes 02.
- `craps.gd`: working-bet funding migration/allocation/reconciliation/refund functions. Inherited surface-audio changes remain.
- `slot.gd`, `pinball_feature.gd`, `slot_resolver.gd`: zero-ball due status, runtime live status, completion-only award. Unrelated inherited Slot changes remain.
- `environment_interaction_view_model.gd`: final production-shape dedup helper; held placement/render geometry remains untouched.

## Gates, performance, and no-regression replay

| Gate | Final result | Attribution |
|---|---|---|
| `validate_project.ps1` | PASS repeatedly; final wrapper validations 106–110 s | Clean |
| Fixes 01 + 02 + 03 regressions | PASS — 2.325 s / 123 ms / 131 ms, 0 failures | Clean; [report](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes03/final_fix_regressions.json) |
| Full contracts | FAIL after 287.8 s; all three fix suites, coach, slots, game modules, events, saves pass | Inherited/held placement, scenario, crew golden, Path A/lender placement failures; [summary](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/f3contracts/summary.json) |
| Slot / Pinball targeted | PASS — 12.413 s test time, zero failures | Clean; [report](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes03/target_slot.json) |
| Blackjack targeted | TIMEOUT/native process liveness; no report | Same inherited standalone/native runner class. `all_game_module_contracts`, Fixes 03 pulse contract, and two visible post-HIT runs pass. |
| Craps targeted | TIMEOUT at 120 s; no report | Same inherited standalone/native runner class. Refund matrix and two visible runs pass. |
| `FoundationSuite games` | TIMEOUT — 307.341 s after validation/load pass | Matches predecessor 307.482 s slow content/Coin Pusher ceiling; [summary](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/f3games/summary.json) |
| `FoundationSuite systems` | TIMEOUT — 307.335 s after validation/load pass | Matches predecessor 307.161 s; [summary](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/f3systems/summary.json) |
| `FoundationSuite ui` | FAIL — only Path A missing Apartment after purchase-flow correction | Inherited fixture; [summary](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/f3ui_retry/summary.json) |
| Smoke | TIMEOUT — foundation content 240.043 s; validation/import/load pass | Matches inherited slow content/native class; [summary](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/f3smoke/summary.json) |
| Tutorial guardrail stress | PASS — 1,622 irregular boundaries | Clean after BUG-07 follow-up |
| Performance probe | Core measurements pass; overall FAIL only two inherited late-Crew-dialogue coverage errors | Blackjack resolve avg/p95/max 3.261/3.524/3.583 ms vs 4.5/5.5/7; Craps 1.230/1.276/1.377; Slot 1.568/3.020/3.128 vs 6/8/10. Liveness guard restored 49 ticks and passed. [report](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes03/performance_final.json) |

Pinball's zero-copy completion/liveness is exercised by the passing full Slot suite and two 1280×720 visible feature sessions. Settings additionally passed compact/small-screen focus replay. The foundation performance probe does not emit a separate `pinball_feature_session` observation; that missing row is not called a pass.

Visible no-regression replays passed:

- BUG-05 modal hides/restores tutorial TalkDock: `fixes03_noreg_b/0009–0010`.
- BUG-06 acknowledged X-Ray instruction remains: `fixes03_noreg_b/0003`.
- BUG-16 successful family loan shows current $88/+30 HUD and Result: `fixes03_noreg_b4/0023–0027`.
- BUG-17 Quarter Falls shows game-local risk copy: `fixes03_noreg_b/0015`.
- BUG-22 Instant Coffee remains passive-only: `fixes03_noreg_b4/0033` and `fixes03_noreg_c_bug22/0037`.
- BUG-27 round-net headline matches −1 and exact prior −11 outcomes: `fixes03_noreg_b4/0053`, `fixes03_noreg_c_bug27_exact/0105`.
- BUG-29 Roulette clear/rebet restores the exact layout twice: `fixes03_noreg_b4/0074–0081`, exact prior seed `fixes03_noreg_c_bug29/0014–0015`.
- Save → quit → Continue passed with active tutorial input (`fixes03_bug08_green_b/0044–0057`) and an accepted Crew loan (`claim06_d1/0118–0120`). Craps working-bet save round trip is covered by the registered migration contract; the visible cash take-down passed twice.

## Changed files

Fixes 03 product changes:

- BUG-07: `scripts/ui/coach_overlay.gd`, `scripts/ui/foundation_main.gd`.
- BUG-08/09/12/19/31/33/36 host paths: `scripts/ui/foundation_main.gd`; BUG-19 also `foundation_screen_builder.gd`; BUG-31 also `foundation_action_view_model.gd` and `scripts/core/event_module.gd`; BUG-36 also `scripts/core/run_state.gd`.
- BUG-23: `scripts/ui/settings_menu.gd`.
- BUG-30: `scripts/ui/talk_dock.gd`.
- BUG-32: `scripts/games/blackjack.gd`.
- BUG-35: `scripts/games/slot.gd`, `scripts/games/slots/pinball/pinball_feature.gd`, `scripts/games/slots/slot_resolver.gd`.
- BUG-36: `scripts/games/craps.gd`.
- BUG-26: `scripts/ui/environment_interaction_view_model.gd` and final host projection in `foundation_main.gd`.

Tests/registration changed:

- `scripts/tests/foundation/playtest_fixes03_contract.gd` (new), `playtest_fixes02_contract.gd`, `check_core_content.gd`.
- `scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd`.
- `tools/foundation_systems_shards.ps1`.

Harness/scratch remains untracked/ignored under `tools/agent_playtest_session.*` and `.tmp/playtest_fixes03/`. The final combined worktree is uncommitted, has no staged files, and preserves the inherited Fixes 01+02 changes.
