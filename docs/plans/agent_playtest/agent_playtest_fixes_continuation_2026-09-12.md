# Agent Playtest Fixes 02 Continuation - 2026-09-12/13

## Status and inherited handoff

DONE - BUG-24 through BUG-31 are validated and fixed. All Fixes 01 and Fixes 02 changes remain uncommitted and unstaged in the shared fix worktree; nothing was pushed.

Historical disposition: these fixes were subsequently accepted and integrated
into `main`. Absolute worktree and `.tmp` links retain original provenance but
no longer resolve because the temporary trees were deliberately removed.

- Predecessor: Fixes 01 prompt `Status: DONE`; predecessor report read in full.
- Fix worktree: `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes` (logical path `D:\Projects\Beat-The-House-worktrees\playtest-fixes`).
- Branch/HEAD: `codex/agent-playtest-fixes` at `56de66598a2bcdbc3f171f090b48c361daf35563`.
- Inherited unstaged content-diff hash: `6c108b64a8766e5f4c6f58089d4e939610671b49`.
- Final combined unstaged content-diff hash: `45add38e02d9de93e2ecae3f2092f32714ab5431`.
- Inherited content: 25 tracked files with 519 insertions/67 deletions and three untracked files. Six additional paths were timestamp/line-ending-only `M` entries. No inherited hunk was discarded.
- Final content: 30 tracked files with 741 insertions/107 deletions and four untracked files. The only new untracked source is `scripts/tests/foundation/playtest_fixes02_contract.gd`; the other three are inherited Fixes 01 fixture/harness files.
- Harness: both `agent_playtest_session.gd` and `.ps1` match the latest `agent-playtest` copies (SHA-256 `8B57E93C8E3379DAF4ADF6ED6904719BBB0996531215F0F098FEFB32E56D1FB1` and `CE928B599CD515273C4A450F1A8E1EE534E5D65D181FA9E7FB466159C1BC316A`). The inherited PowerShell harness received only the latest validation-only complete-JSON wait behavior.

## Baseline

- `tools/validate_project.ps1`: PASS, 106.3 s.
- Foundation smoke runtime report: PASS, 6 checks/0 failures, 52.553 s. The enclosing baseline wrapper later encountered the same native-process liveness stall recorded by Fixes 01.
- Isolated inherited targeted suites: Baccarat PASS (292 ms test), Blackjack PASS (3.463 s), Roulette PASS (646 ms), Bar Dice PASS (63.729 s).
- All eight original production `main.tscn` streams were replayed: BUG-24 26/26, BUG-25 68/68, BUG-26 22/22, BUG-27 35/35, BUG-28 22/22, BUG-29 24/24, BUG-30 23/23, BUG-31 22/22 commands.
- Old generated routes drifted before some late reported states. The original screenshots plus deterministic production model/presentation seams were therefore used for those cases; no result was inferred from a rejected command.

## Summary

All eight findings are **VALID** and fixed. There are zero NOT-A-BUG, NEEDS-DESIGN, OWNED-ELSEWHERE, or unresolved continuation findings.

| Bug | Class and corrected root cause | Fixed | Regression | Product files | Evidence |
| --- | --- | ---: | --- | --- | --- |
| BUG-24 | VALID - Baccarat inherited the shared LEAVE rectangle, which intersected its fixed explainer. | Yes | `playtest_fixes02_regressions / BUG-24` | `baccarat.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b3/0013.png), [after](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/sessions/fixed_bug24/0011.png) |
| BUG-25 | VALID - inline consequences received a fixed one-line detail slot and truncating draw call. | Yes | BUG-25 short/long/extreme/compact geometry | `pixel_scene_canvas.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c5/0063.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |
| BUG-26 | VALID - semantically identical scenario description and action summary were both projected. | Yes | BUG-26 normalized duplicate/distinct copy | `environment_interaction_view_model.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d4/0021.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |
| BUG-27 | VALID - the headline consumed wager settlement transfer instead of semantic round net. | Yes | BUG-27 loss/win/push/surrender/split/side/caught/save | `blackjack.gd`, `foundation_main.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b5/0026.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |
| BUG-28 | VALID - Bar Dice used `prompt.left(74)` at an unbounded position. | Yes | BUG-28 bounded console geometry | `bar_dice.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b6/0019.png), [after](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/sessions/fixed_bug28/0014.png) |
| BUG-29 | VALID - an explicitly empty transient rebet list shadowed authoritative `table.last_bets`. | Yes | BUG-29 settle/clear/rebet | `roulette.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b7/0013.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |
| BUG-30 | VALID - chained entry construction bypassed speaker hydration and replaced nested overrides. | Yes | BUG-30 chain/roster/faceless/fallback/save | `event_module.gd`, `talk_dock.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c7/0021.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |
| BUG-31 | VALID - lender presentation exposed only generic deltas, not the exact debt model. | Yes | BUG-31 four lenders/offer/confirm/result/family/save | `run_action_service.gd`, `event_module.gd`, `foundation_main.gd` | [before](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d7/0020.png), [green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log) |

## Required red/green proof

`playtest_fixes02_regressions` was first registered and run against the inherited Fixes 01 product state. It failed 26 assertions spanning all eight bugs, as required: [red log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/red_regression.log) and [red report](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/isolated_project/.tmp/playtest_fixes02_red.json).

After implementation, the expanded contract passed with zero failures. The final combined run also passed `playtest_fixes01_regressions` (2.206 s), `playtest_fixes02_regressions` (80 ms), `event_module_foundation` (1.295 s), and `save_service_foundation_round_trip` (2.894 s): [final green log](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_green.log).

## Per-bug records

### BUG-24 - Baccarat LEAVE geometry

Two inherited captures showed the default LEAVE rectangle (`x=776..862`) crossing the hand explainer (`x=684..876`). Baccarat now publishes named `BACCARAT_EXPLAINER_RECT` and `BACCARAT_SURFACE_BACK_RECT` geometry, uses the same explainer rectangle for drawing, and places LEAVE at `Rect2(590, 22, 86, 34)`. The regression asserts both positive geometry and non-intersection. The post-fix 1280x720 capture was visually inspected and shows both regions readable and independently hittable. This follows recommended option A.

### BUG-25 - wrapped inline consequence detail

Trace reached `_selected_info_action_area_height`, `_selected_info_action_entries_for_rect`, `_object_info_size`, and `_draw_selected_object_info`. The canvas now measures multiline text with the active font and available width, caps it at four lines, allocates matching card/action height, and draws it with `draw_multiline_string`. The test covers short, long, extreme, and compact-mode content and ensures detail stays inside its card. No per-frame arrays, `duplicate()`, or collection rebuilds were added. This follows option A.

### BUG-26 - semantic scenario deduplication

The view model now normalizes case and whitespace before comparing scenario `short_description` with `action_summary`; it suppresses only equivalent copy and retains distinct action guidance. Tests cover both branches. This applies the recommended suppression at the presentation boundary without changing authored scenario data.

### BUG-27 - Blackjack semantic result delta

Settlement transfer remains in `bankroll_delta` for accounting. Blackjack separately computes `round_net_delta = main + side + security`, publishes `outcome_bankroll_delta`, and uses that semantic value for the headline, result board, payout label, patron/ritual projections, story result, and shared HUD/result feedback. Cases cover normal loss and win, push, surrender, split net push, side-bet win/loss, and caught-cheat penalty; serialization preserves the semantic result. No RNG or hidden-card state changed. This follows option A.

### BUG-28 - bounded Bar Dice guidance

The character-count truncation was removed. Both active guidance and settled status now render centered/fitted inside the named `BAR_DICE_GUIDANCE_RECT` (`Rect2(452, CONSOLE_Y + 61, 432, 20)`). The regression rejects the old `.left(74)` path and protects the console boundary. The 1280x720 after capture was visually inspected and contains the full line. This follows option A.

### BUG-29 - authoritative Roulette rebet

`_roulette_rebet_layout` now prefers a non-empty authoritative `table.last_bets` and falls back to transient session data only when appropriate. Surface state, realtime state, normalization, and the REBET command share that helper. A deterministic settled layout survives CLEAR and is restored by REBET. Roulette's RNG and winning-number behavior are untouched. This follows option A.

### BUG-30 - chained speaker hydration

Triggered event entry defaults are now built at the same content boundary as direct events, nested speaker overrides are merged instead of replacing authored values, and roster identity/timing metadata is hydrated before enqueue. `TalkDock` preserves an authored faceless alias such as “Unknown Caller” and uses “Unknown” only when the alias is truly absent. Tests cover chained defaults, an explicit mood override, roster metadata, faceless display, unnamed fallback, and serialization. This follows option A.

### BUG-31 - exact lender terms

`RunActionService` derives disclosure from the exact debt delta used on acceptance rather than duplicating constants. Authored voice remains first, followed by principal, repayment total, interest/favor structure, and deadline in the option, confirmation, and result. Tests cover street lender `$25/$28/10%/3 turns`, motel friend `$20/$22/10%/4 turns`, Crew `$45/2 favors/0%/2 turns`, family `$30/$33/10%/6 turns`, Vic debt serialization, and the chained family offer. This follows option A and intentionally does not rebalance terms.

## Incidental predecessor coverage

None of BUG-24 through BUG-31 was already fixed by Fixes 01. Fixes 01 did provide adjacent infrastructure used here: wrapped environment result feedback, canonical event result publication, local risk summaries, and Roulette visual changes. Those inherited hunks were preserved and are not counted as Fixes 02 edits.

## Not fixed / owner decisions

No continuation bug was left unfixed and no new owner decision is required. The separate Fixes 01 BUG-10 placement ownership remains unchanged. Existing broad-suite failures listed below were not expanded into this bug-fix scope.

## Overlap and merge notes

Files already changed by Fixes 01 were extended at function boundaries:

- `event_module.gd`: preserved inherited `_traveler_context_choice`; Fixes 02 extends `choices`, `_consequence_deltas`, `_apply_trigger_event_hook`, and adds trigger-default/merge helpers for BUG-30/31.
- `run_action_service.gd`: preserved inherited `_inventory_behavior_summary`; Fixes 02 extends `hook_option` and `_dynamic_lender_result` and adds model-derived lender-term helpers.
- `roulette.gd`: preserved inherited `_draw_roulette_wheel` label-radius correction; Fixes 02 changes only rebet consumers/normalization and adds `_roulette_rebet_layout`.
- `environment_interaction_view_model.gd`: preserved Fixes 01 per-game `game_risk_summary`; Fixes 02 extends `make_interactable_object` and adds semantic scenario-summary deduplication.
- `foundation_main.gd`: preserved all Fixes 01 lifecycle, tutorial, feedback, purchase, save/load, and settings changes; Fixes 02 extends `_lender_conversation_option`, `_environment_result_feedback_view`, and `_style_hud_for_recent_consequence` so semantic deltas/terms reach shared presentation. Accounting/hold balance still uses the settlement transfer.
- `pixel_scene_canvas.gd`: this file was not a Fixes 01 content change (the predecessor report deliberately left it untouched); Fixes 02 owns the multiline action-detail geometry here. The main checkout has separate uncommitted placement work in this path and must reconcile it manually.

## Gates, replay, save/Continue, and performance

### Automated gates

| Gate | Result | Attribution |
| --- | --- | --- |
| `validate_project.ps1` | PASS after implementation (104.2 s), PASS after final review (106.9 s), and PASS inside all final broad invocations (105.1/104.8/108.3/105.8 s) | Fixes 02 clean |
| Fixes 02 regression | RED 26 assertions on inherited state; GREEN 0 after | Required proof |
| Fixes 01 + Fixes 02 + event + save contracts | PASS, 0 failures | Combined changes clean |
| Baccarat targeted | PASS, 294 ms test | Clean |
| Blackjack targeted | PASS, 3.526 s test | Clean |
| Roulette targeted | PASS, 638 ms test | Clean |
| Bar Dice targeted | PASS, 63.274 s including 3x1000 rounds | Clean |
| Final Smoke | Foundation runtime PASS (66.017 s); import/load/launchers/Dave/Roulette audio PASS. Foundation content TIMEOUT 240.040 s; UI Path A failure; performance probe nonzero for inaccessible late probes. | Same inherited native/fixture/coverage classes, not caused by Fixes 02 |
| Final `FoundationSuite games` | import/load PASS; games surfaces and math reports complete, content stage TIMEOUT; wrapper TIMEOUT 307.482 s | Inherited slow content/Coin Pusher ceiling |
| Final `FoundationSuite systems` | import/load PASS; wrapper TIMEOUT 307.161 s | Inherited systems shard ceiling |
| Final `FoundationSuite ui` | all listed UI stages PASS except Path A departure fixture missing the apartment visited-return route | Reproduced pre-existing fixture failure; unrelated to changed functions |

The first final games invocation lacked `GODOT_BIN` after its validation pass and stopped with the explicit configuration error; it was rerun correctly and is not counted as a product gate. A simultaneous systems attempt was rejected immediately by the runner's concurrency lock while UI owned it; systems was rerun alone. Structured reports: [Smoke](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_smoke/summary.json), [games](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_games/summary.json), [systems](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_systems2/summary.json), [UI](C:/Users/theep/.codex/worktrees/Beat-The-House-playtest-fixes/.tmp/playtest_fixes02/final_ui/summary.json).

An adjacent `lender_debt_foundation` run reached an existing `parking_lot_tip`/`crew::package_handoff` scenario-placement overlap and follow-on delivery failures. The targeted event/lender/debt contracts pass; no continuation change touches that placement.

### Player-path replay

All eight original routes were replayed again after fixes with a PNG and result JSON for every command, 242 command/result pairs total:

| Group/session | Results | Rejected due to generated route/tutorial drift | Script errors |
| --- | ---: | ---: | ---: |
| G8 BUG-24 | 26 | 4 | 0 |
| G8 BUG-25 | 68 | 27 | 0 |
| G8 BUG-26 | 22 | 9 | 0 |
| G8 BUG-28 | 22 | 3 | 0 |
| G9 BUG-27 | 35 | 17 | 0 |
| G9 BUG-29 | 24 | 3 | 0 |
| G10 BUG-30 | 23 | 6 | 0 |
| G10 BUG-31 | 22 | 12 | 0 |

This supplies 138 visible-input actions in G8, 59 in G9, and 45 in G10, each above the requested 40-action neighboring-behavior floor. Three sessions emitted only an ObjectDB leak warning at process exit. Visual after-state proof is strong for BUG-24/28; route drift prevented the old streams from serving as visual state proof for several later bugs, for which the green production-seam assertions above are the evidence.

The inherited Fixes 01 player pass already completed an actual Save -> process quit -> relaunch -> Continue cycle (152 commands). For this continuation, state-specific round-trip assertions preserve a completed Blackjack semantic result, a queued/hydrated family-loan chain, and Vic's exact accepted debt; `save_service_foundation_round_trip` also passes. A single visible route combining all three states could not be reproduced because the old generated route drifted, so the report does not mislabel that replay as successful.

### Performance and liveness

The final performance probe's relevant resolve paths are all within `perf06_budget_table.json`:

| Game | Avg ms | P95 ms | Max ms | Budget avg/P95/max ms |
| --- | ---: | ---: | ---: | ---: |
| Bar Dice | 0.615 | 0.650 | 0.697 | 1.5 / 3.0 / 4.0 |
| Blackjack | 3.318 | 3.605 | 3.630 | 4.5 / 5.5 / 7.0 |
| Baccarat | 1.028 | 1.078 | 1.169 | 1.25 / 1.75 / 3.0 |
| Roulette | 1.348 | 1.475 | 1.485 | 2.0 / 3.0 / 4.0 |

Idle liveness advanced for Blackjack (51), Baccarat (50), and Roulette (50), all above the floor of 8. The synthetic Blackjack guard also proved that a suppressed animation records zero and fails, while restored animation advances 49. Bar Dice's resolve/progress contract and 3x1000-round suite pass, but the shared probe does not publish a separate Bar Dice idle counter. The overall performance process is nonzero only because the inherited full-cap Coin Pusher path prevents access to late `talk_dock_active` and `eviction_map_transition` probes. Room/canvas geometry is explicitly covered in normal and compact BUG-25 assertions and 1280x720 captures; the shared probe has no independent room-canvas timing row.

## Changed files by continuation bug

- BUG-24: `scripts/games/baccarat.gd`.
- BUG-25: `scripts/ui/pixel_scene_canvas.gd`.
- BUG-26: `scripts/ui/environment_interaction_view_model.gd`.
- BUG-27: `scripts/games/blackjack.gd`; `scripts/ui/foundation_main.gd`.
- BUG-28: `scripts/games/bar_dice.gd`.
- BUG-29: `scripts/games/roulette.gd`.
- BUG-30: `scripts/core/event_module.gd`; `scripts/ui/talk_dock.gd`.
- BUG-31: `scripts/core/run_action_service.gd`; `scripts/core/event_module.gd`; `scripts/ui/foundation_main.gd`.
- Regression/tool registration: `scripts/tests/foundation/playtest_fixes02_contract.gd`; `scripts/tests/foundation/check_core_content.gd`; `tools/foundation_systems_shards.ps1`.
- Validation-only inherited harness update: `tools/agent_playtest_session.ps1`.

No save-schema shape changed, no migration was required, no deterministic RNG stream changed, no hidden information entered presentation state, and no new per-frame copies/collection rebuilds were introduced.

## Completion integrity

- Final fix-worktree branch/HEAD match the inherited handoff.
- No staged files, commit, push, merge, stash, or reset.
- All Godot processes started by this task were closed; none remained at final cleanup.
- The main checkout was changed only in this report and the Fixes 02 prompt execution record/status. Existing unrelated main-checkout modifications were preserved.
