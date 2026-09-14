# Playtest Fixes 01 — Validation and Fix Report

Date executed: 2026-09-12 through 2026-09-13  
Base commit: `56de66598a2bcdbc3f171f090b48c361daf35563`  
Fix worktree: `D:\Projects\Beat-The-House-worktrees\playtest-fixes` (physical path `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes`)  
Branch: `codex/agent-playtest-fixes`  
State: all fixes are uncommitted; nothing was pushed, merged, stashed, reset, or staged.

The sweep harness was copied into the fix worktree as untracked validation tooling: `tools/agent_playtest_session.gd` and `tools/agent_playtest_session.ps1`.

## Header and evidence index

Classification totals: **22 VALID**, **1 OWNED ELSEWHERE**, zero NOT-A-BUG, zero NEEDS-DESIGN. Fixed: **22/22 owned VALID bugs**. BUG-10 remains with the reusable spawn-slot owner because the exact path is already modified in the main checkout.

Shared automated evidence:

- Red on base: [`playtest_fixes01_regressions.log`](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes01/red/playtest_fixes01_regressions.log) — 22 expected failures.
- Green after fixes: [`final_focused.log`](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes01/green/final_focused.log) — `playtest_fixes01_regressions` and `coin_pusher_exit_settle_bound`, 0 failures.
- Final repository validation: [`validate_project_final2.log`](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes01/final_gates/validate_project_final2.log) — pass in 106.7 seconds.
- Before player evidence is under `D:\Projects\Beat-The-House-worktrees\agent-playtest\.tmp\agent_playtest\2026-09-12\`.
- After player evidence is under `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes\.tmp\agent_playtest\2026-09-13\`.

Pre-existing/infrastructure gate failures retained rather than broadened into this sweep:

- Registered native DLL runs of Smoke/games can terminate Godot with exit `-1` without a readable shard report. Both the newly built DLL and the existing main-checkout DLL reproduce it. With an empty extension list, the isolated Video Poker contract passes.
- `games -NoImport` reaches the slow content/Coin Pusher portion and exceeds the 300-second shard ceiling after the earlier game surface and math checks pass.
- `systems -NoImport` exceeds the same ceiling while reporting stale crew golden/placement and other existing failures. An untouched-base export reproduces the relevant crew golden failures.
- `ui -NoImport` reports the existing Path A map fixture missing the apartment return route. The untouched base reproduces it.
- `tutorial_dialogue_trigger_cadence_check` fails its pre-existing stale games-source hash/canonical isolated fixture. `tutorial_talk_target_nonoverlap_check` fails because `tutorial_blackjack_raise` has an empty target staging rect; the untouched base reproduces the non-overlap failure.
- The performance probe completes the requested game/room measurements within budget, then exits nonzero on the existing inaccessible late-run Crew dialogue probe and its missing coverage record.

## Summary

| Bug | Validation class and confirmed/corrected cause | Fixed? | Regression | Changed product files | Before / after evidence |
|---|---|---:|---|---|---|
| BUG-01 | VALID — start/load accepted an empty or exitless environment; a reused generator could retain failed-install state. | Yes | `playtest_fixes01_regressions / BUG-01` | `foundation_main.gd`; broken-save fixture | `fx01_d2_r1/r2` / `after_fixes01_pt_d2` |
| BUG-02 | VALID — settle ticks were bounded, but backlog/input/shim work was not; modal actions could race the exit. | Yes | `BUG-02`; `coin_pusher_exit_settle_bound` | `foundation_main.gd`, `coin_pusher.gd`, `coin_pusher_live_session.gd` | `fx01_a2_r1`, `fx01_c3_r2b` / `after_fixes01_pt_a2_final2` |
| BUG-03 | VALID, corrected cause — Pull Tabs omitted `environment_archetype_id`, so the host treated Grand Casino currency as chips while the module charged cash. Scratch Tickets already routed correctly. | Yes | `BUG-03`; pull/scratch currency contracts | `pull_tabs.gd` | `fx01_b_r1/r2` / `after_fixes01_pt_b` |
| BUG-04 | VALID — Craps emitted Blackjack/Roulette cue classes absent from `craps_table`. | Yes | `BUG-04`; SFX audit | `craps.gd` | `fx01_b_r1/r2` stderr / `after_fixes01_pt_b` stderr clean |
| BUG-05 | VALID — modal ownership hid coach focus but did not suspend the tutorial Talk dock. | Yes | `BUG-05` | `foundation_main.gd` | `fx01_d_r1/r2` / `after_fixes01_pt_d` |
| BUG-06 | VALID — dialogue acknowledgement cleared its presentation before the active instruction was projected. | Yes | `BUG-06` | `coach_overlay.gd` | `fx01_a_r1/r2` / `after_fixes01_pt_a` |
| BUG-07 | VALID — only the coach bubble consumed input; the rest of the overlay passed pointer input through. | Yes | `BUG-07` | `coach_overlay.gd` | `fx01_c_r1/r2` plus red seam / `after_fixes01_pt_c` plus green seam |
| BUG-08 | VALID — Numbers slip confirmation never published the result through the canonical feedback state. | Yes | `BUG-08` | `foundation_main.gd`, `run_state.gd` | `fx01_c_r1/r2` plus red seam / `after_fixes01_pt_c` plus green seam |
| BUG-09 | VALID — Silas charged before checking whether the one-time knowledge purchase had already resolved; UI stayed enabled and feedback was non-canonical. | Yes | `BUG-09`; `numbers_contract` | `numbers_model.gd`, `run_state.gd`, `foundation_main.gd` | `fx01_d2_r1/r2` / `after_fixes01_pt_d2` |
| BUG-10 | OWNED ELSEWHERE — Vic/lender placement is on the main checkout's in-progress reusable spawn-slot path. | No, owner overlap | Existing environment audits | None | `fx01_c_r1/r2`; retest after spawn-slot integration |
| BUG-11 | VALID — Video Poker wager changes returned the incoming hand/hold UI dictionary intact. | Yes | `BUG-11`; Video Poker suite | `video_poker.gd` | `fx01_a3_r1/r2` / `after_fixes01_pt_a3` |
| BUG-12 | VALID — post-purchase affinity refocus ran before the stable purchase result screen was presented. | Yes | `BUG-12` | `foundation_main.gd` | `fx01_d_r1/r2` / `after_fixes01_pt_d` |
| BUG-13 | VALID — practice launch cleared result dictionaries but not the structured HUD wallet delta. | Yes | `BUG-13` | `foundation_main.gd` | `fx01_b_r1/r2` / `after_fixes01_pt_b` |
| BUG-14 | VALID — Dave's first-stop template could receive an empty previous-place value. | Yes | `BUG-14`; production fresh-generation seam | `event_module.gd` | `fx01_c_r1/r2` plus red seam / `after_fixes01_pt_c` plus green seam |
| BUG-15 | VALID — `crew_world` emitted phone cues its profile did not declare; the audit did not verify all declared/used mappings. | Yes | `BUG-15`; expanded SFX audit | SFX manifest, audit | `fx01_d_r1/r2` stderr / audit pass and clean after stderr |
| BUG-16 | VALID — event choice resolution applied state but left stale recent-result feedback. | Yes | `BUG-16` | `foundation_main.gd` | `fx01_c_r1/r2` plus red seam / `after_fixes01_pt_c` plus green seam |
| BUG-17 | VALID — interaction cards copied one global room risk string to every game. | Yes | `BUG-17` | interaction controller/view model | `fx01_a_r1/r2` / `after_fixes01_pt_a` |
| BUG-18 | VALID — result text was truncated to 64 characters and drawn in a fixed non-wrapping label. | Yes | `BUG-18` | `foundation_main.gd` | `fx01_a_r1/r2` / normal and small-screen PNGs |
| BUG-19 | VALID — mandatory onboarding displayed an editable seed even though it intentionally used the teaching seed. | Yes | `BUG-19` | `foundation_main.gd` | `fx01_a_r1/r2` / `after_fixes01_pt_a` |
| BUG-20 | VALID — Roulette number/result labels were positioned beyond the wheel radius. | Yes | `BUG-20`; Roulette visual contract | `roulette.gd` | `fx01_a4_r1/r2` / `after_fixes01_pt_a4` |
| BUG-21 | VALID — min/max raise controls were always drawn and hit-registered. | Yes | `BUG-21`; Crew Poker suite | `crew_draw_poker.gd` | `fx01_b2_r1/r2` / `after_fixes01_pt_b2` |
| BUG-22 | VALID — item class was interpreted before active/passive capability, misdescribing passive consumables. | Yes | `BUG-22` | `run_action_service.gd` | `fx01_c4_r1/r2` / `after_fixes01_pt_c4` |
| BUG-23 | VALID for Settings — no focus trap or previous-focus restoration. Inventory and Run Menu did not share the defect. | Yes | `BUG-23` | `settings_menu.gd` | `fx01_d_r1/r2` / `after_fixes01_pt_d` |

## Per-bug records

### BUG-01 — transactional start/load recovery

Two fresh-profile replays reproduced Resume into a blank room, and the base regression failed. `start_foundation_run` did not validate the installed first environment and reused a generator capable of retaining failed-install diagnostics; load accepted an empty/exitless current environment. New runs now receive a fresh generator and fail safely before autosave/render if generation is unplayable. Loads validate the room, deterministically regenerate the current node when possible, autosave the recovery, or open the travel map when a safe regeneration is unavailable. The fixture `playtest_empty_environment_save.json` verifies same-seed recovery to the expected playable first room. Green focused contract and `after_fixes01_pt_d2` provide after evidence.

### BUG-02 — bounded Coin Pusher exit

The original Vault Drop Leave route stayed on the machine. Trace showed `MAX_SETTLE_TICKS` bounded only solver settlement, not accumulator drain, queued inputs, or shim-recovery work. The session now tracks one absolute `exit_work_ticks` budget across every exit phase, caps each chunk to the remaining budget, exposes "Leaving...", blocks modal/menu re-entry during the exit, and records the real settle-tick count in the durable snapshot. `coin_pusher_exit_settle_bound` covers all three cabinet variations and passes in 72 ms.

The fixed native replay initially exposed a related pre-existing cache-coherency edge: Quarter Falls can replenish a rider by editing the authoritative GDScript body array while the native cache retains its compact body vector. `_sync_physical_features` now invalidates that cache before the next tick. Final `after_fixes01_pt_a2_final2` processed all 42 commands, left the machine, and recorded zero script/conservation errors.

### BUG-03 — Pull Tabs currency ownership

The provisional diagnosis of a universally duplicated wager delta was too broad. Production tracing showed the Pull Tabs result omitted the room archetype. In a Grand Casino/practice host this made the shared currency router fund chips while the module's own result applied the cash debit, producing the apparent double charge. Both single-ticket and ticket-set results now carry `environment_archetype_id`. Scratch Tickets already supplied the correct identity and was not changed. Pull Tabs and Scratch currency/conservation contracts are green.

### BUG-04 — Craps audio classes

All Craps surface actions were audited. Cross-profile `blackjack_chip` and `roulette_chip_sweep` emissions were replaced by declared `craps_chip_place`, `craps_chip_remove`, `craps_dice_throw`, `craps_dice_land`, and `craps_table_clear` cues as appropriate. The expanded surface-SFX audit passes 13 profiles and 83 event streams; fixed replays have no undeclared-cue stderr.

### BUG-05 — modal/tutorial Talk ownership

Settings, Inventory, and Run Menu were opened during active tutorial Talk. `_refresh_talk_dock` now treats those modal owners like blocking decisions, and each open/close path refreshes Talk visibility. The queued lesson remains intact and returns after close. Focused contract and tutorial guardrail checks pass.

### BUG-06 — acknowledged instruction retention

`CoachOverlay.notify_dialogue_completed` now records the acknowledged lesson instruction, and `_render_active` projects that instruction while the lesson is still active instead of blanking the coach. The state is cleared only at the next legitimate lesson boundary. Replay and focused contract are green.

### BUG-07 — overlay pointer shield

The root coach layer now consumes blocked mouse button, motion, touch, and drag input while guidance owns input. Allowed tutorial controls still pass through the existing action allowlist. This intentionally causes several old coordinate commands in the fixed C/D replay streams to be rejected instead of activating controls under the overlay; there are no script errors and the focused input-shield contract passes.

### BUG-08 — Numbers slip result

Slip purchase now publishes a canonical `game_hook` result with source/action identity and a bankroll delta. It clears competing game/item result owners before updating `last_hook_result`. The production seam and focused contract are green.

### BUG-09 — Silas idempotency

The Numbers model rejects an already purchased route tip or already known daily handle. `RunState` now asks the model first, charges only a successful purchase, and returns canonical deltas. Silas status exposes `tip_available`; the UI disables the spent one-time option and publishes success/failure through the same Numbers result path. `numbers_contract` and the focused contract pass; the second purchase no longer changes bankroll.

### BUG-10 — Vic placement

Not changed. The main checkout already modifies `environment_interaction_view_model.gd`, `pixel_scene_canvas.gd`, `environment_placement.gd`, `scenario_layout_resolver.gd`, placement surfaces, and new spawn-slot data. The owner must ensure the Punchline back room has an explicit interactive `lender:street_lender` slot, integrate that work, and replay Vic's route. Adding a competing placement scheme here would create a high-risk merge conflict.

### BUG-11 — Video Poker wager reset

`_bet_command` now returns a shallow copy with active-hand, hold, marked-hold, selection, deal, and draw transients removed, then explicitly sets `hand_active=false` and an empty hold list. Persistent surface preferences remain intact. Video Poker suite and replay pass.

### BUG-12 — purchase result versus affinity focus

The purchase handler now stores a shallow pending affinity result, renders the stable purchase result first, and applies affinity refocus only when returning to the environment. This preserves the purchased item/result panel and still keeps the intended follow-up focus. Replay and focused regression pass.

### BUG-13 — practice wallet delta

Practice launch now calls `structured_hud.reset_wallet_delta()` before constructing the new game-test environment. The first practice frame no longer inherits a previous run's cash pulse. Replay and focused regression pass.

### BUG-14 — Dave first-stop copy

The production first-generation seam confirmed the traveler line could retain a placeholder or empty-location punctuation. The fix intentionally deviates from adding a new character/itinerary field: new authored fields altered generated bytes. `EventModule._traveler_context_choice` instead rejects unresolved placeholder output and reuses Dave's existing authored event payload `summary`. This preserves never-visited generation bytes while providing clean first-stop copy. A strict base/fix generation comparison was identical except for the expected randomized encrypted `crew_state` blob; the fresh generated Dave event regression passes.

### BUG-15 — crew-world phone audio

`crew_world` now maps both `phone_call` and `phone_out_of_service` to existing generated masters. The audit was expanded to validate required classes and every profile/event-stream declaration, catching adjacent manifest omissions without adding new audio assets. Audit result: 13 profiles, 83 streams, pass.

### BUG-16 — event choice feedback

Successful `resolve_event_choice` calls now clear competing result owners and copy the event result into `last_hook_result` before downstream refresh/showdown handling. State application remains unchanged. Focused contract passes.

### BUG-17 — game-local risk

The controller no longer injects a global risk string into every interaction row. The view model derives `game_risk_summary` from each game's local cheat actions/cues and attaches it only to that game. Existing main-checkout changes in the same functions must be manually reconciled; see merge notes.

### BUG-18 — wrapped result feedback

The environment result panel grew from 46 to 72 pixels, uses smart word wrapping, and no longer truncates either the message or appended cash/heat deltas. Normal evidence: [`after_fixes01_pt_b2/0005.png`](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/after_fixes01_pt_b2/0005.png). Small-screen evidence: [`bug18_small_screen/0016.png`](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/agent_playtest/2026-09-13/bug18_small_screen/0016.png), where the same 52-character result wraps to two lines without clipping.

### BUG-19 — mandatory tutorial seed

When a fresh profile must enter First Night and no challenge overrides it, the seed field is now non-editable, its tooltip explains the teaching seed, and the start-status line says the seed is fixed. Non-tutorial/challenge starts remain editable. Replay and focused contract pass.

### BUG-20 — Roulette rim labels

Number and result label radii were moved from `WHEEL_RADIUS + 17` inside the wheel boundary. The Roulette visual contract was updated to enforce the in-wheel coordinates. Suite and replay pass.

### BUG-21 — bounded raise controls

`_draw_raise_selector` computes decrement/increment availability from the current amount and min/max. Disabled controls receive muted styling and are not registered as hit targets; enabled controls retain existing IDs and behavior. Only this boundary function was touched in the file shared with `backroom-poker-tweaks`. Crew Poker suite and replay pass.

### BUG-22 — active/passive item copy

`_inventory_behavior_summary` now branches on active capability first. Passive items use passive/container/permanent language regardless of a broad `consumable` class; only active consumables say they are spent on use. The contract checks Instant Coffee and scans every passive item for the bad phrase. Replay passes.

### BUG-23 — Settings focus containment

Settings caches focusable controls, remembers the previous owner, explicitly cycles Tab/Shift+Tab within visible enabled settings controls, focuses the first setting on open, and restores the previous owner after close. Inspection showed Inventory and Run Menu already retained focus inside their modal ownership paths, so they were not broadened. Focused contract and replay pass.

## Not fixed / owner decisions

- **BUG-10 — OWNED ELSEWHERE.** The reusable spawn-slot owner must decide the final explicit Vic lender slot and complete the production replay after integrating their main-checkout work. This is the only owner decision needed from this sweep.

## Merge notes

Main-checkout overlap:

- `scripts/ui/environment_interaction_controller.gd` — `interactable_object_view_list`: this work removes the global `_risk_cue_text()` argument. Preserve the main checkout's reusable spawn/object list changes and pass the same object records through without a room-global risk string.
- `scripts/ui/environment_interaction_view_model.gd` — `interactable_object_view_list` and new helper `game_risk_summary`: preserve the main checkout's spawn-slot/layout additions, then retain the per-game risk derivation and `risk_summary` assignment from this branch.
- `scripts/core/run_state.gd` — `numbers_silas_status`, `numbers_buy_slip`, `numbers_buy_silas_tip`: preserve any main-checkout state/schema edits; retain `tip_available`, canonical bankroll deltas, and charge-after-model-success ordering.

`backroom-poker-tweaks` overlap:

- `scripts/games/crew_draw_poker.gd` — `_draw_raise_selector` only: reconcile the other branch's selector visuals/behavior while retaining bound-aware enabled styling and omission of disabled hit targets.

`game-prop-art` overlap:

- None. `pixel_scene_canvas.gd` was deliberately untouched.

The main checkout also contains an uncommitted `playtest_fixes02_continuation_2026-09-12_prompt.md` from the follow-up request. It was preserved and is not part of this sweep's output.

## Gates, tutorials, performance, and player replay

### Automated gates

| Gate | Result | Attribution |
|---|---|---|
| `validate_project.ps1` | PASS (final 106.7 s) | Current fixes clean |
| Focused `playtest_fixes01_regressions` | RED 22 on base; GREEN 0 after | Required regression proof |
| `coin_pusher_exit_settle_bound` | PASS, 72 ms | Current fixes clean |
| Smoke with import/native | Godot exit `-1` at foundation content | Native registration/process infrastructure; reproduced with existing and rebuilt DLL |
| games with native | Shards exit `-1`, unreadable reports | Same native registration/process issue |
| games `-NoImport` / empty extension | Earlier game surfaces and math through Slot pass; suite exceeds 300 s in slow content/Coin Pusher | Existing runtime ceiling |
| systems `-NoImport` | Exceeds 300 s; existing crew golden/placement and other failures | Reproduced on untouched base where relevant |
| ui `-NoImport` | FAIL: Path A missing apartment return route | Reproduced on untouched base |
| Touched game suites | Pull Tabs, Scratch Tickets, Craps, Video Poker, Roulette, Crew Poker pass | Current fixes clean |
| Full Coin Pusher suite | Exceeds available process/runtime ceiling; focused 72 ms bound and combined contracts pass | Existing suite runtime limitation |
| Surface SFX audit | PASS: 13 profiles / 83 streams | Current fixes clean |
| Tutorial guardrail recovery | PASS: 1,622 irregular boundaries | Current fixes clean |
| Tutorial corner-shop order | PASS | Current fixes clean |
| Tutorial dialogue cadence | FAIL: stale source hash/canonical isolated fixture | Pre-existing |
| Tutorial target non-overlap | FAIL: empty `tutorial_blackjack_raise` target rect | Pre-existing, clean-base reproduced |

### Performance

The baseline invocation through the required D: junction was rejected by the native-tool reparse-point guard, so no valid before timing sample exists. The after probe was rerun from the physical worktree with native-v3; all requested measured paths were within `perf06_budget_table.json`, all relevant liveness counters advanced, and only the pre-existing late-run Crew dialogue coverage failure made the overall process nonzero.

| Path | Avg ms | P95 ms | Max ms |
|---|---:|---:|---:|
| Pull Tabs resolve | 0.784 | 0.873 | 1.039 |
| Scratch Tickets resolve | 1.227 | 3.379 | 3.613 |
| Roulette resolve | 1.500 | 1.636 | 1.728 |
| Crew Poker resolve | 1.456 | 1.620 | 1.658 |
| Video Poker resolve | 1.097 | 1.188 | 1.270 |
| Coin Pusher active carriage frame | 6.860 | 6.918 | 7.024 |
| Coin Pusher active carriage draw | 3.156 | 3.307 | 3.368 |

Coin Pusher used `native_v3`, stayed below its 22 ms frame-P95 and 7 ms draw-P95 budgets, and showed physical motion/liveness. Relevant game progress counts were at least 49 frames/8 checks; no fixed path regressed a budget.

### Player-path replay

All ten original command streams were replayed on the fixed build, totaling 916 completed command/result pairs. There were zero harness script errors in the final sessions. Rejected commands are expected route drift: the corrected tutorial input shield blocks old clicks beneath active guidance, and some old streams depended on clean-profile state no longer present at that point. These rejections were retained as evidence rather than weakening the shield.

| Session | Results | Rejected | Script errors |
|---|---:|---:|---:|
| `after_fixes01_pt_a` | 151 | 75 | 0 |
| `after_fixes01_pt_a2_final2` | 42 | 1 | 0 |
| `after_fixes01_pt_a3` | 41 | 8 | 0 |
| `after_fixes01_pt_a4` | 41 | 3 | 0 |
| `after_fixes01_pt_b` | 213 | 30 | 0 |
| `after_fixes01_pt_b2` | 32 | 4 | 0 |
| `after_fixes01_pt_c` | 152 | 118 | 0 |
| `after_fixes01_pt_c4` | 41 | 25 | 0 |
| `after_fixes01_pt_d` | 151 | 87 | 0 |
| `after_fixes01_pt_d2` | 52 | 29 | 0 |

`after_fixes01_pt_c` includes the full save → quit → relaunch → Continue cycle; the replay required two game-process starts and completed all 152 results. Group regression coverage is supplied by the 40+ action A, B, C, and D sessions, with focused contracts covering any old commands intentionally rejected by the new input ownership.

## Changed files grouped by bug

- BUG-01: `scripts/ui/foundation_main.gd`; `scripts/tests/fixtures/playtest_empty_environment_save.json`; combined regression.
- BUG-02 and related Coin Pusher cache finding: `scripts/ui/foundation_main.gd`; `scripts/games/coin_pusher.gd`; `scripts/games/coin_pusher/coin_pusher_live_session.gd`; `scripts/tests/foundation/check_coin_pusher.gd`; combined/bound contracts.
- BUG-03: `scripts/games/pull_tabs.gd`; `scripts/tests/foundation/check_table_games.gd`; `scripts/tests/foundation/check_scratch_tickets.gd` (cross-game conservation assertion).
- BUG-04: `scripts/games/craps.gd`; SFX audit and combined regression.
- BUG-05, BUG-08, BUG-12, BUG-13, BUG-16, BUG-18, BUG-19: `scripts/ui/foundation_main.gd`; combined regression and relevant existing suites.
- BUG-06 and BUG-07: `scripts/ui/coach_overlay.gd`; combined regression/tutorial checks.
- BUG-09: `scripts/core/numbers_model.gd`; `scripts/core/run_state.gd`; `scripts/ui/foundation_main.gd`; `scripts/tests/foundation/numbers_contract.gd`.
- BUG-10: no files.
- BUG-11: `scripts/games/video_poker.gd`; combined/table-game tests.
- BUG-14: `scripts/core/event_module.gd`; combined production-seam regression.
- BUG-15: `data/audio/surface_sfx_manifest.json`; `tools/audio06_1_surface_sfx_audit.gd`.
- BUG-17: `scripts/ui/environment_interaction_controller.gd`; `scripts/ui/environment_interaction_view_model.gd`.
- BUG-20: `scripts/games/roulette.gd`; `scripts/tests/foundation/check_table_games.gd`.
- BUG-21: `scripts/games/crew_draw_poker.gd`; combined/Crew Poker tests.
- BUG-22: `scripts/core/run_action_service.gd`; combined regression.
- Shared regression registration: `scripts/tests/foundation/check_core_content.gd`; `tools/foundation_systems_shards.ps1`.
- Validation-only, untracked in fix worktree: `tools/agent_playtest_session.gd`; `tools/agent_playtest_session.ps1`.

Git may display timestamp/line-ending-only `M` entries for `data/characters/characters.json`, `data/events/events.json`, `data/town/itineraries.json`, `scripts/core/town_network.gd`, `scripts/games/scratch_tickets.gd`, and `scripts/games/coin_pusher/coin_pusher_solver.gd`; `git diff` contains no content changes for those paths, and they must not be included when applying the fix.
