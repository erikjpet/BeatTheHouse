# Deprecated and Unused Code Audit and Cleanup

Audited and cleaned 2026-10-08 against the feature-complete 0.6 source. The
pre-cleanup source is preserved in Git commit `9c7cc0f2`.

The cleanup removed the code proven unreachable or unreferenced while retaining
compatibility code still exercised by saves, tests, snapshots, or runtime
dispatch. The candidate inventories below record the pre-cleanup evidence and
their former line numbers; they are intentionally retained as release audit
history rather than a description of the current source layout.

## Cleanup result

- Removed the one unreachable retired start-screen implementation.
- Removed all 105 production functions in the identified unused call islands:
  51 core, 15 game, and 39 UI functions.
- Removed all 13 unused active-tool helpers: nine PowerShell and four Python.
- Removed the three orphan `.gd.uid` workspace artifacts.
- Re-scanned the production source after deletion. No uniquely named production
  function remains without an external reference, apart from Godot's
  `_unhandled_key_input` virtual callback.
- Preserved every live migration, save-repair, dynamic-contract, and
  compatibility path listed later in this report.

## Cleanup verification

- Baseline-to-cleanup declaration comparison confirms exactly 105 production
  functions were removed; no neighboring production function is missing.
- Godot's full editor scan parses all production scripts cleanly.
- `health06_1_dead_code_contract_test.ps1` and
  `health06_1_dead_code_contract.gd` pass, including the orphan-UID check.
- The focused scenario-engine contract passes with zero failures, and the
  all-game-module contract passes with zero failures.
- The no-pointer animation-liveness release gate passes after removal of the
  unused surface redraw-demand query.
- PowerShell and Python parse checks pass for every modified tool, and both code
  documentation checks pass for all production modules and game files.

## Scope and method

The audit covered:

- all 212 production GDScript modules and 11,363 functions under
  `scripts/core/`, `scripts/games/`, and `scripts/ui/`;
- active GDScript tests/tools, scenes, resources, JSON data, project settings,
  native Coin Pusher code, 126 active PowerShell tools, and 32 active Python
  tools as possible reference sites;
- direct calls, callable/string references, signals, script paths, `class_name`
  references, resource UIDs, and local call-graph descendants;
- unconditional-return reachability, explicit retired/deprecated markers,
  constant-false branches, warning suppressions, and orphan modules.

The symbol pass is deliberately conservative. A comment or quoted method name
counts as a reference, engine callbacks and `_on_*` signal callbacks are
excluded, and functions sharing the same name in multiple classes are not
declared unused. Computed dynamic method names cannot be proven statically, so
public candidates require a focused test before removal.

## Results

| Finding | Count | Disposition |
| --- | ---: | --- |
| Confirmed unreachable production blocks | 1 | Removed |
| Production functions in unused call islands | 105 | Removed |
| Unreferenced roots among those functions | 85 | No active repository caller |
| Helpers reachable only from an unused root | 20 | Remove with their root |
| Private candidates | 55 | Highest-confidence function removals |
| Public/static candidates | 50 | Internal API review before removal |
| Orphan production GDScript modules | 0 | No action |
| Orphan `.gd.uid` artifacts | 3 | Removed generated leftovers |
| Constant-false production branches | 0 | No action |
| Unused/unreachable warning suppressions | 0 | No action |
| Active PowerShell function candidates | 9 | Removed |
| Active Python function candidates | 4 | Removed |

Production candidates by area are 51 core functions, 15 game functions, and 39
UI functions. No production script is orphaned: every module has a path,
`class_name`, or UID reference outside itself. The native Coin Pusher entry
points are registered with Godot and every parsed file-local helper has another
native reference.

The repository health check does find three UID sidecars whose scripts no
longer exist:

- `scripts/ui/room_action_list.gd.uid`;
- `scripts/tests/rw06_1_overflow_action_ui_contract.gd.uid`;
- `scripts/tests/foundation/postfix06_2_environment_composition_contract.gd.uid`.

All three are ignored/untracked generated files rather than Git-tracked source,
but they are still stale workspace artifacts and currently make
`health06_1_dead_code_contract_test.ps1` fail its CH-22 orphan check.

## Confirmed unreachable block

`scripts/ui/foundation_screen_builder.gd:14-167` is the retired start-screen
implementation. `build_start_screen()` calls `_build_redesigned_start_screen()`
and returns on line 11, so the old panel, intro, challenge, settings, career,
inventory, collection, developer-library, and exit-button construction below
that return can never execute. The live replacement starts at line 169.

The unreachable block was deleted while retaining the call to
`_build_redesigned_start_screen()`. Removing its stale callable strings also
prevents them from making unrelated methods appear referenced in future textual
audits.

## Highest-value unused groups

| Group | Evidence | Candidate members |
| --- | --- | --- |
| Scenario causal-validation remnants | Fourteen functions form disconnected roots/subtrees; no active source, test, tool, data, or scene references them. | `ScenarioEngine._validated_branch_resolution_records`, its branch/cause helpers, `_causal_recorded_outcomes`, `_register_allowed_operations`, `_valid_phase_transition`, `_authored_cleanup_reasons`, `_all_branches`, `_record_keys`, and `sequence_record_visit` |
| Legacy terminal projections | The current terminal path calls `consequence_snapshot`, pressure/outcome helpers, and `game_result_from_story_log`; twelve older list/result helpers have no caller. | `environment_result_feedback`, suspicion/security/inventory/debt/flag/story list helpers, and `result_from_story_log` with their private helpers |
| Superseded route calculations | Current route/travel code does not call this older private path-cost island. | `_travel_candidate_entries`, `_path_distance_blocks`, `_path_base_cost`, `_path_cost`, `_path_risk_decay`, `_route_edge_id`, `_path_edges` |
| Old Hold'em seams | Ordered NPC turns now use `CrewPokerModel.npc_action`; the earlier adaptive method is unreferenced. The room-interruption proposal has no host caller. | `_adaptive_npc_action`, `interrupt_for_room_scenario` |
| Unused ritual painter | No game surface calls the generic ritual projection or its geometry helpers. | `TableGameVisuals.draw_ritual_projection`, `_ritual_rect`, `_ritual_vector` |
| Delivery reflow remnants | Authored fixed placement replaced this reflow path. | `_reflow_delivery_records`, `_delivery_occupied_rects`, `_delivery_available_rect`, `_delivery_board_bounded_rect` |
| Slot-state conveniences | Current slot resolution mutates through other state paths. | `write_owned_machine`, `per_bet_bucket`, `set_per_bet_bucket`, `_default_per_bet_bucket` |
| Dormant audio diagnostics | No runtime or test invokes these wrappers/subtrees. | `SfxPlayer.debug_event_delivery_has_signal`, `_pcm_stream_has_signal`, `WebAudioBridge.prewarm_stream`, `dispose_pcm` |

## Complete production candidate inventory

`callers=-` means the function name has no active repository reference outside
its declaration. A listed caller is itself part of this unused island.

### Core (51)

| File | Candidate functions |
| --- | --- |
| `attribute_badges.gd` | `from_deltas:275` |
| `blackjack_action_authority.gd` | `cancel_delivery:231`, `valid_receipt:331`, `commit_response_cow:366` |
| `delivery_run_model.gd` | `chase_verbs:346`, `_next_pending_target_index:722` |
| `developer_placement_store.gd` | `project_slot_overrides:98`, `shared_slot_overrides:112`, `scenario_slot_overrides:122`, `_runtime_reserve_slot:1060`, `_shared_scenario_slot:1069` |
| `environment_base_semantic_records.gd` | `_route_present:851` |
| `environment_instance.gd` | `_layout_spot_count:1204` |
| `environment_semantic_inventory.gd` | `_semantic_ids:1278` |
| `game_module.gd` | `surface_animation_status:644`, `set_result_message:876` |
| `save_service.gd` | `_rotate_primary_to_backup:347`, `_remove_absolute_if_exists:377` |
| `scenario_engine.gd` | `_validated_branch_resolution_records:634`, `_authored_branch:713`, `_branch_condition_matches_cause:720`, `_causal_recorded_outcomes:746`, `_authored_handler_for_cause:757`, `_command_completes_objective_step:773`, `_journal_receipt_condition_proven:783`, `_register_allowed_operations:805`, `_valid_phase_transition:824`, `_authored_cleanup_reasons:836`, `_all_branches:852`, `_record_keys:870`, `_append_unique_text:876`, `sequence_record_visit:880` |
| `scenario_extension_dispatch.gd` | `extension_paths:69` |
| `scenario_layout_resolver.gd` | `_translated_label_rect:1909`, `_zone_rect:1965`, `_rect_from_semantic_bounds:1971`, `_resolve_route_center:1978`, `_record_label_rect:2077` |
| `scenario_sequence_catalog.gd` | `legacy_scenario_ids:218`, `clear_default_cache:245` |
| `scenario_sequence_runtime.gd` | `_append_runtime_error:2131`, `_resolved_branch_outcomes:2373` |
| `scenario_sequence_schema.gd` | `_valid_receipt_id:2089` |
| `world_map.gd` | `refresh_shop_node_environments:997`, `_travel_candidate_entries:1983`, `_path_distance_blocks:2154`, `_path_base_cost:2162`, `_path_cost:2170`, `_path_risk_decay:2178`, `_route_edge_id:2186`, `_path_edges:2194` |

### Games (15)

| File | Candidate functions |
| --- | --- |
| `coin_pusher/coin_pusher_live_session.gd` | `_append_u16:735` |
| `coin_pusher/coin_pusher_solver.gd` | `_total_mass:2191`, `_position_clear:2268` |
| `crew_draw_poker.gd` | `_adaptive_npc_action:1703`, `interrupt_for_room_scenario:2089` |
| `scratch_ticket_region_model.gd` | `art_file:77` |
| `slots/slot_machine_state.gd` | `write_owned_machine:65`, `per_bet_bucket:207`, `set_per_bet_bucket:217`, `_default_per_bet_bucket:327` |
| `slots/slot_rng_math.gd` | `random_payline_cells:181`, `grid_to_string:190` |
| `table_game_visuals.gd` | `draw_ritual_projection:29`, `_ritual_rect:66`, `_ritual_vector:71` |

### UI (39)

| File | Candidate functions |
| --- | --- |
| `attribute_badge_row.gd` | `texture_cache_size:150` |
| `bag_open_reel_view_model.gd` | `snap_to_complete:55` |
| `environment_interaction_controller.gd` | `_delivery_occupied_rects:2010`, `_reflow_delivery_records:2041`, `_delivery_available_rect:2068`, `_delivery_board_bounded_rect:2074` |
| `environment_interaction_view_model.gd` | `layout_spot_to_board_position:700` (called only by the unused Foundation wrapper) |
| `foundation_hud_view_model.gd` | `next_objective_option:201`, `hud_meter:394` |
| `foundation_main.gd` | `_result_uses_game_bankroll_presentation:2196`, `_poll_game_module_script_prewarm:8441`, `_layout_spot_to_board_position:16179` |
| `foundation_widgets.gd` | `tab_bar:150`, `style_focusable:105` (called only by `tab_bar`) |
| `game_surface_canvas.gd` | `_surface_animation_redraw_demand:1614` |
| `pixel_scene_canvas.gd` | `_draw_watch_camera:4826`, `_grand_casino_staff_member:6222`, `_clear_draw_text_caches:7105` |
| `procedural_music_player.gd` | `profile_fingerprint:3245` |
| `run_report_view_model.gd` | `cursor_for_action:1114` |
| `sfx_player.gd` | `debug_event_delivery_has_signal:1202`, `_pcm_stream_has_signal:1211` |
| `talk_dock.gd` | `create_portrait_model:255` |
| `terminal_consequence_view_model.gd` | `environment_result_feedback:125`, `environment_result_feedback_text:148`, `suspicion_cue_view_list:295`, `security_cue_view_list:310`, `inventory_view_list:317`, `debt_view_list:325`, `debt_entry_view_line:332`, `debt_schedule_text:343`, `flag_view_list:353`, `flag_value_is_visible:361`, `story_message_view_list:372`, `result_from_story_log:393` |
| `ui_art.gd` | `clear_cache:89` |
| `visual_style.gd` | `type_size:187` |
| `web_audio_bridge.gd` | `prewarm_stream:681`, `dispose_pcm:828` |

## Removed active-tool candidates

These do not ship in the game, but they add maintenance surface.

### PowerShell (9)

- `rw06_1_environment_exact_seed_contract_test.ps1:1428` — `Test-PushedCandidate`
- `rw06_1_visual_capture_contract_test.ps1:515` — `Get-ExactOwnedResidualPids`
- `rw06_2_ending_replay.ps1:1344` — `Refresh-Look`
- `rw06_2_final_evidence_source_contract.ps1:249` — `Replace-SourceRegexOnce`
- `rw06_2_final_evidence_source_contract.ps1:385` — `Add-TopLevelHashtableEntry`
- `rw06_2_replay_source_contract.ps1:665` — `Get-PowerShellFunctionSource`
- `rw06_6_pull_tab_glimmer_contract.ps1:3444` — `Close-OwnedCacheGuardChecked`
- `rw06_q009_process_support.ps1:1445` — `Get-Q009SafeHandleFinalPath`
- `rw06_q009_process_support.ps1:2835` — `Get-ExactOwnedGodotResidualPids`

### Python (4)

- `author_scenario_slot_layouts.py:1372` — `place_provisional_geometry`
- `environment_fixed_slot_static_check.py:268` — `slot_has_physical_support`
- `generate_scratch_ticket_art.py:70` — `hex_color`
- `generate_trailer_cards.py:140` — `_draw_backdrop`

`setUp`, `tearDown`, and `setUpClass` methods that appear textually uncalled were
excluded because `unittest` invokes them by convention.

## Deprecated or compatibility code that is still live

Do not remove these merely because their names say legacy/compatibility:

- `scripts/ui/cheat_dock.gd` is a hidden compatibility adapter, but
  `FoundationMain` still constructs, updates, and snapshots it.
- `GameModule.finalize_routed_player_message()` is not used by production
  routing, but the player-text contract invokes it dynamically.
- `TutorialFlow.repair_legacy_tutorial_save()` is called during load and is
  covered by the dead-code health contract.
- `RunState` scenario, Streets/delivery, Crew, duel, and environment migration
  paths are reachable from `from_dict()` or current facades.
- Pull Tab legacy X-ray/ticket normalization and inventory loose-container
  fallback code are active save/schema repair paths.
- Bar Dice and Baccarat compatibility simulations remain reachable through
  their public simulation contracts even though live settlement uses sealed
  actions.
- `tools/rw06_1_author_fixed_slots.py` is explicitly retained as the one-time
  migration/reproducibility source, and
  `tools/rw06_1_apply_hand_authored_slots.py` is read by the static placement
  validator. Both refuse obsolete schema-v1 mutation under slot schema v2.

## Completed cleanup sequence

1. Removed the unreachable start-screen block.
2. Removed private unused roots and their exclusive helpers by domain.
3. Reviewed and removed the public/static candidates with no supported caller.
4. Removed the 13 unused active-tool helpers and parsed their owning scripts.
5. Retained live compatibility paths until their supported save/snapshot
   boundary is formally retired. The two slot-authoring tools remain for the
   reproducibility and static-validation reasons documented above.
