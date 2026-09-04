extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const CrewWorldSequenceAdapterScript := preload("res://scripts/core/crew_world_sequence_adapter.gd")

const DEFAULT_SEED := "WAVE-B-COMPOSITION-08"
const DEFAULT_REPORT_PATH := "res://.tmp/wave_b_composition_probe/report.json"
const RUMOR_VENUE_ID := "corner_store"
const RUMOR_TARGET_ID := "bar"
const PUNCHLINE_ID := "small_underground_casino"
const TRAVELER_ID := "dave_bus_regular"
const COMPOSITION_SAVE_SLOT := "integ06_1_maximal_composition"

var seed_text := DEFAULT_SEED
var report_path := DEFAULT_REPORT_PATH
var mode := "full"
var candidate_commit := ""
var candidate_tree := ""
var tool_source_sha256 := ""
var evidence_profile := ""
var evidence_profile_path := ""
var evidence_profile_sha256 := ""
var shard_index := 0
var shard_count := 1
var order_id := "save_load_replay_abandon"
var target_layer_id := ""
var failures: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_text = argument.trim_prefix("--seed=").strip_edges()
		elif argument.begins_with("--out="):
			report_path = _normalized_report_path(argument.trim_prefix("--out=").strip_edges())
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=").strip_edges()
		elif argument.begins_with("--candidate-commit="):
			candidate_commit = argument.trim_prefix("--candidate-commit=").strip_edges()
		elif argument.begins_with("--candidate-tree="):
			candidate_tree = argument.trim_prefix("--candidate-tree=").strip_edges()
		elif argument.begins_with("--tool-source-sha256="):
			tool_source_sha256 = argument.trim_prefix("--tool-source-sha256=").strip_edges()
		elif argument.begins_with("--evidence-profile="):
			evidence_profile = argument.trim_prefix("--evidence-profile=").strip_edges()
		elif argument.begins_with("--profile-path="):
			evidence_profile_path = argument.trim_prefix("--profile-path=").strip_edges()
		elif argument.begins_with("--profile-sha256="):
			evidence_profile_sha256 = argument.trim_prefix("--profile-sha256=").strip_edges()
		elif argument.begins_with("--shard-index="):
			shard_index = maxi(0, int(argument.trim_prefix("--shard-index=")))
		elif argument.begins_with("--shard-count="):
			shard_count = maxi(1, int(argument.trim_prefix("--shard-count=")))
		elif argument.begins_with("--order-id="):
			order_id = argument.trim_prefix("--order-id=").strip_edges()
		elif argument.begins_with("--target-layer-id="):
			target_layer_id = argument.trim_prefix("--target-layer-id=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	if mode == "delivery-matrix":
		_finish_delivery_matrix(_exercise_delivery_composition(library))
		return
	var selected := _select_production_run(library)
	var run_state: RunState = selected.get("run_state")
	var generator: RunGenerator = selected.get("generator")
	seed_text = str(selected.get("seed", seed_text))
	if run_state == null or generator == null:
		_require(false, "The requested production seed did not spawn Police Sweep with a live traveler itinerary.")
		_finish({"selected_seed": seed_text})
		return

	# Visit a real scenario-backed venue. The selector must persist the canonical
	# scenario chosen when the node is generated.
	var rumor_venue_travel := generator.travel_environment_result(run_state, RUMOR_VENUE_ID, true)
	_require(bool(rumor_venue_travel.get("ok", false)), "Production travel could not install the rumor venue: %s." % JSON.stringify(rumor_venue_travel.get("errors", [])))
	var source_scenario := run_state.scenario_for_node(RUMOR_VENUE_ID)
	_require(run_state.current_world_node_id() == RUMOR_VENUE_ID, "Production travel did not enter the rumor venue.")
	_require(not source_scenario.is_empty(), "The visited rumor venue did not retain its selected scenario.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(source_scenario.get("id", "")), "The visited rumor venue applied a different scenario than Town State selected.")

	# Ask Town State for a rendered rumor backed by its live registry, then hear it
	# through RunState so the world map receives the distinct heard tier.
	var scenario_rumor: Dictionary = {}
	for rumor_value in run_state.rumors_for_venue(RUMOR_VENUE_ID, "street", 64):
		if typeof(rumor_value) != TYPE_DICTIONARY:
			continue
		var rumor: Dictionary = rumor_value
		if str(rumor.get("class", "")) == "scenario" and str(rumor.get("target_node_id", "")) == RUMOR_TARGET_ID:
			scenario_rumor = rumor
			break
	_require(not scenario_rumor.is_empty(), "The production rumor registry did not render the target scenario rumor at the source venue.")
	_require(not scenario_rumor.is_empty() and run_state.town_state.rumor_trace_is_live(scenario_rumor), "The rendered scenario rumor was not backed by live Town State truth.")
	var heard := run_state.hear_rumor(str(scenario_rumor.get("id", "")))
	var heard_node := WorldMapScript.node_metadata_by_id(run_state.world_map, RUMOR_TARGET_ID)
	var route := library.route(RUMOR_TARGET_ID)
	var heard_preview := run_state.travel_route_preview(route, library.environment_archetype(RUMOR_TARGET_ID), {}, false)
	_require(str(heard.get("fact_id", "")) == str(scenario_rumor.get("fact_id", "")), "RunState did not hear the exact truth-sourced rumor offered at the venue.")
	_require(not _dict(heard_node.get("heard", {})).is_empty() and not bool(heard_node.get("scouted", false)), "Hearing the rumor did not upgrade the other map node to heard-only state.")
	_require(str(heard_preview.get("level", "")) == "heard" and _dict(heard_preview.get("heard_rumor", {})).get("fact_id", "") == heard.get("fact_id", ""), "The target route preview did not consume the heard-tier rumor payload.")
	_require(not heard_preview.has("game_ids") and not heard_preview.has("service_ids"), "The heard-tier route preview leaked full scouting fields.")

	# Advance the production town clock exactly to Dave's next itinerary boundary.
	var traveler_before := run_state.traveler_state(TRAVELER_ID)
	var traveler_before_node := str(traveler_before.get("node_id", ""))
	var traveler_depart_action := int(traveler_before.get("depart_action", 0))
	_require(not traveler_before.is_empty(), "The production traveler itinerary had no active Dave segment.")
	run_state.advance_environment_turns(maxi(1, traveler_depart_action - int(run_state.town_state.action_index)))
	var traveler_after := run_state.traveler_state(TRAVELER_ID)
	_require(not traveler_after.is_empty() and str(traveler_after.get("node_id", "")) != traveler_before_node, "The traveler itinerary did not advance at its production action boundary.")

	# Bring the same run to a live Police Sweep segment, then cross one movement
	# boundary and verify the node it left exposes the authored swept window.
	var sweep_track := run_state.town_state.police_sweep.snapshot()
	var sweep_before := run_state.town_state.sweep_internal_status()
	var sweep_start_action := int(sweep_track.get("start_action", 0))
	if int(run_state.town_state.action_index) < sweep_start_action:
		run_state.advance_environment_turns(sweep_start_action - int(run_state.town_state.action_index))
	sweep_before = run_state.town_state.sweep_internal_status()
	var swept_node_id := str(sweep_before.get("current_node_id", ""))
	var sweep_segment_before := int(sweep_before.get("segment_index", -1))
	var sweep_move_action := int(sweep_before.get("next_move_action", 0))
	_require(bool(sweep_before.get("active", false)) and not swept_node_id.is_empty(), "Police Sweep did not become active on its production track.")
	run_state.advance_environment_turns(maxi(1, sweep_move_action - int(run_state.town_state.action_index)))
	var sweep_after := run_state.town_state.sweep_internal_status()
	var swept_window := run_state.swept_window(swept_node_id)
	_require(int(sweep_after.get("segment_index", -1)) > sweep_segment_before, "Police Sweep did not advance to its next production track segment.")
	_require(bool(swept_window.get("cheat_window_open", false)) and int(swept_window.get("remaining_actions", 0)) > 0, "The departed Sweep node did not expose its authored swept window.")

	# Enter the rumored node after hearing it. Its generated scenario identity must
	# be the exact truth named by the rumor, proving scenario selection composes
	# across multiple visited nodes in this run.
	var rumor_target_travel := generator.travel_environment_result(run_state, RUMOR_TARGET_ID, true)
	_require(bool(rumor_target_travel.get("ok", false)), "Production travel could not install the heard scenario node: %s." % JSON.stringify(rumor_target_travel.get("errors", [])))
	var target_scenario := run_state.scenario_for_node(RUMOR_TARGET_ID)
	_require(run_state.current_world_node_id() == RUMOR_TARGET_ID, "Production travel did not enter the heard scenario node.")
	_require(str(target_scenario.get("id", "")) == str(heard.get("source_id", "")), "The entered node did not consume the exact scenario named by its truth-sourced rumor.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(target_scenario.get("id", "")), "The heard node's selected scenario was not applied to its generated environment.")
	_require(str(source_scenario.get("id", "")) != "" and str(target_scenario.get("id", "")) != "", "Scenario selection did not coexist across both visited nodes.")

	# Finally visit The Punchline through the same generator. The shipped Side Door
	# event discovers L2 from L1, and the production layer transition enters it.
	var punchline_travel := generator.travel_environment_result(run_state, PUNCHLINE_ID, true)
	_require(bool(punchline_travel.get("ok", false)), "Production travel could not install The Punchline: %s." % JSON.stringify(punchline_travel.get("errors", [])))
	var punchline_scenario := run_state.scenario_for_node(PUNCHLINE_ID)
	_require(str(run_state.current_environment.get("current_layer_id", "")) == "club", "The Punchline did not begin on its public L1 club layer.")
	_require(not punchline_scenario.is_empty() and str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "The Punchline lost its Tier-2 scenario while entering L1.")
	var punchline_layers := {"club": _layer_surface_inventory(run_state.current_environment)}
	var side_door: EventModule = EventModuleScript.new()
	side_door.setup(library.event("side_door"), library)
	var discovery_result := side_door.resolve(run_state, run_state.current_environment, "punchline_password")
	_require(bool(discovery_result.get("ok", false)) and bool(_dict(run_state.current_environment.get("layer_discovery", {})).get("casino", false)), "The shipped L1 Side Door choice did not discover Punchline L2.")
	var layer_result := generator.enter_environment_layer(run_state, "casino", false)
	_require(bool(layer_result.get("ok", false)) and str(run_state.current_environment.get("current_layer_id", "")) == "casino", "The production layer transition did not enter discovered Punchline L2: %s." % JSON.stringify(layer_result))
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "Punchline L2 entry lost the selected Tier-2 scenario.")
	punchline_layers["casino"] = _layer_surface_inventory(run_state.current_environment)
	run_state.crew_add_trust("crew_rook", 1000, "integ06_1_public_rank_progress")
	var back_room_result := generator.enter_environment_layer(run_state, "back_room", false)
	_require(bool(back_room_result.get("ok", false)) and str(run_state.current_environment.get("current_layer_id", "")) == "back_room", "The production made-rank path did not enter Punchline L3: %s." % JSON.stringify(back_room_result))
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "Punchline L3 entry lost the selected Tier-2 scenario.")
	punchline_layers["back_room"] = _layer_surface_inventory(run_state.current_environment)

	# Save in the deepest live layer, reload through the production SaveService,
	# leave, and revisit.  The world-node snapshot must retain the layer and the
	# scenario journal without replaying any one-shot consequence.
	var save_service: SaveService = SaveServiceScript.new()
	save_service.clear_run(COMPOSITION_SAVE_SLOT)
	var story_count_before_save := run_state.story_log.size()
	var layer_environment_before_save := run_state.current_environment.duplicate(true)
	var save_error := save_service.save_run(run_state, COMPOSITION_SAVE_SLOT)
	var loaded_variant: Variant = save_service.load_run(COMPOSITION_SAVE_SLOT) if save_error == OK else null
	_require(save_error == OK and loaded_variant is RunState, "Production SaveService could not round-trip the maximal Punchline state (error %d)." % save_error)
	if loaded_variant is RunState:
		run_state = loaded_variant as RunState
		_require(str(run_state.current_environment.get("current_layer_id", "")) == "back_room", "Save/load did not restore the active Punchline L3 layer.")
		_require(RunStateScript.scenario_restore_equivalent(layer_environment_before_save, run_state.current_environment), "Save/load changed the Punchline scenario restore contract.")
		_require(run_state.story_log.size() == story_count_before_save, "Save/load replayed a Punchline consequence.")
		var restored_punchline := run_state.scenario_finalize_installed_environment(library)
		_require(bool(restored_punchline.get("ok", false)), "Save/load could not restore Punchline's semantic departure records: %s." % JSON.stringify(restored_punchline.get("errors", [])))
	var departure := generator.travel_environment_result(run_state, RUMOR_TARGET_ID, true)
	var departure_room_finalized := run_state.scenario_finalize_installed_environment(library) if bool(departure.get("ok", false)) else {}
	var revisit := generator.travel_environment_result(run_state, PUNCHLINE_ID, true) if bool(departure_room_finalized.get("ok", false)) else {}
	_require(bool(departure.get("ok", false)) and bool(revisit.get("ok", false)), "Punchline abandonment/revisit travel did not remain safe.")
	_require(str(run_state.current_environment.get("current_layer_id", "")) == "back_room", "Punchline revisit did not restore the saved L3 layer.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "Punchline revisit reselected or lost its scenario identity.")
	_require(run_state.story_log.size() >= story_count_before_save, "Punchline revisit lost prior story consequences.")
	save_service.clear_run(COMPOSITION_SAVE_SLOT)

	var delivery_composition := _exercise_delivery_composition(library)

	_finish({
		"selected_seed": seed_text,
		"scenarios": {
			RUMOR_VENUE_ID: str(source_scenario.get("id", "")),
			RUMOR_TARGET_ID: str(target_scenario.get("id", "")),
			PUNCHLINE_ID: str(punchline_scenario.get("id", "")),
		},
		"rumor": {
			"fact_id": str(heard.get("fact_id", "")),
			"source_venue": RUMOR_VENUE_ID,
			"target_node": RUMOR_TARGET_ID,
			"preview_level": str(heard_preview.get("level", "")),
		},
		"traveler": {
			"character_id": TRAVELER_ID,
			"before_node": traveler_before_node,
			"after_node": str(traveler_after.get("node_id", "")),
		},
		"police_sweep": {
			"departed_node": swept_node_id,
			"segment_before": sweep_segment_before,
			"segment_after": int(sweep_after.get("segment_index", -1)),
			"window_remaining_actions": int(swept_window.get("remaining_actions", 0)),
		},
		"punchline": {
			"l1": "club",
			"l2": "casino",
			"l3": str(run_state.current_environment.get("current_layer_id", "")),
			"discovery_method": "punchline_password",
			"layer_surfaces": punchline_layers,
			"save_load_revisit": true,
			"departure_ok": bool(departure.get("ok", false)),
			"departure_room_finalized": bool(departure_room_finalized.get("ok", false)),
			"revisit_ok": bool(revisit.get("ok", false)),
		},
		"delivery_composition": delivery_composition,
	})


func _finish_delivery_matrix(delivery: Dictionary) -> void:
	var inventory := _dict(delivery.get("surface_inventory", {}))
	var lifecycle_passed := bool(delivery.get("save_load_exact", false)) \
		and bool(delivery.get("replay_idempotent", false)) \
		and bool(delivery.get("abandonment_clean", false)) \
		and bool(delivery.get("order_pre_replay_ok", false)) \
		and bool(delivery.get("order_travel_return_ok", false)) \
		and bool(delivery.get("order_expired_ok", false))
	var maximal_observed := bool(delivery.get("initial_maximal_live", false)) \
		and not str(delivery.get("scenario_id", "")).is_empty() \
		and not _array(inventory.get("game_ids", [])).is_empty() \
		and not _array(inventory.get("event_ids", [])).is_empty() \
		and not _array(inventory.get("service_ids", [])).is_empty() \
		and int(delivery.get("traveler_count", 0)) > 0 \
		and bool(delivery.get("sweep_active", false))
	var row := {
		"seed": seed_text,
		"archetype_id": str(delivery.get("target_archetype", "")),
		"node_id": str(delivery.get("target_node", "")),
		"scenario_id": str(delivery.get("scenario_id", "")),
		"layer_id": str(delivery.get("layer_id", "")),
		"game_ids": _array(inventory.get("game_ids", [])),
		"event_ids": _array(inventory.get("event_ids", [])),
		"service_ids": _array(inventory.get("service_ids", [])),
		"traveler_ids": _array(delivery.get("traveler_ids", [])),
		"traveler_count": int(delivery.get("traveler_count", 0)),
		"sweep_state": {"active": bool(delivery.get("sweep_active", false))},
		"crew_sequence_token": str(delivery.get("crew_sequence_token", "")),
		"eligibility_source": str(delivery.get("eligibility_source", "")),
		"event_selection": _dict(delivery.get("event_selection", {})),
		"order_id": order_id,
		"before_sha256": str(delivery.get("before_sha256", "")),
		"after_sha256": str(delivery.get("after_sha256", "")),
		"double_fire_count": 0 if bool(delivery.get("replay_idempotent", false)) else 1,
		"orphan_count": 0 if bool(delivery.get("abandonment_clean", false)) else 1,
		"state_bytes": JSON.stringify(delivery).to_utf8_buffer().size(),
		"maximal_observed": maximal_observed,
		"passed": lifecycle_passed,
	}
	var report := {
		"schema": "beat_the_house.integ06_1_composition_shard",
		"version": 1,
		"candidate_commit": candidate_commit,
		"candidate_tree": candidate_tree,
		"tool_source_sha256": tool_source_sha256,
		"profile": {"evidence_profile": evidence_profile, "path": evidence_profile_path, "sha256": evidence_profile_sha256},
		"shard": {"index": shard_index, "count": shard_count, "seed_ids": [seed_text]},
		"platform": OS.get_name(),
		"profile": "headless-production-selector",
		"active_systems": ["scenario", "crew_world_sequence", "event", "service", "traveler", "police_sweep", "game", "save_load"],
		"authored_max_counts": {"orders": 4, "punchline_layers": 3},
		"phase_samples": [],
		"lifecycle_status": "clean" if lifecycle_passed else "failed",
		"terminal": {},
		"semantic_trace_sha256": JSON.stringify(_normalize_json_numbers(row), "", true).sha256_text(),
		"save_load_points": ["mounted_mid_composition"],
		"retained_counters": {
			"available": true,
			"measured": ["nodes", "orphans", "state_bytes"],
			"nodes": int(delivery.get("world_node_count", 0)),
			"resources": null,
			"objects": null,
			"orphans": int(row.get("orphan_count", 0)),
			"state_bytes": JSON.stringify(delivery).to_utf8_buffer().size(),
		},
		"allocation_copy_counters": {
			"available": false,
			"allocations": null,
			"shallow_copies": null,
			"deep_copies": null,
			"bytes": null,
			"source": "not_instrumented_by_semantic_composition_probe",
		},
		"artifacts": [],
		"rows": [row],
		"delivery": delivery,
		"failures": failures.duplicate(),
		"passed": failures.is_empty() and lifecycle_passed,
	}
	_write_report(report)
	print("INTEG06_1_COMPOSITION_SHARD=%s" % JSON.stringify(report))
	quit(0 if bool(report.get("passed", false)) else 1)


func _exercise_delivery_composition(library: ContentLibrary) -> Dictionary:
	var supported_orders := [
		"save_load_replay_abandon",
		"replay_save_load_abandon",
		"travel_return_save_load_abandon",
		"save_load_abandon_travel_return",
		"expire_save_load_travel_return",
	]
	_require(supported_orders.has(order_id), "Unknown composition order: %s" % order_id)
	if not supported_orders.has(order_id):
		return {"order_id": order_id}
	var prepared := _prepare_natural_crew_delivery(library, "%s-DELIVERY" % seed_text)
	var run_state: RunState = prepared.get("run_state")
	var generator: RunGenerator = prepared.get("generator")
	_require(run_state != null and generator != null, "The production lender/cadence path did not naturally queue a Crew favor.")
	if run_state == null or generator == null:
		return {
			"eligibility_source": str(prepared.get("eligibility_source", "")),
			"crew_lender_node": str(prepared.get("crew_lender_node", "")),
			"event_selection": _dict(prepared.get("event_selection", {})),
		}
	var event_module: EventModule = EventModuleScript.new()
	event_module.setup(library.event("crew_favor_delivery"), library)
	var pending_entry := run_state.next_pending_triggered_event()
	var active_entry := run_state.begin_triggered_event_resolution(pending_entry)
	_require(str(active_entry.get("event_id", "")) == "crew_favor_delivery", "The production modal queue did not begin the naturally selected Crew favor.")
	var started := event_module.resolve(run_state, run_state.current_environment, "run_package")
	run_state.complete_triggered_event_resolution("crew_favor_delivery")
	var token := str(started.get("world_sequence_owner_token", ""))
	_require(bool(started.get("delivery_started", false)) and bool(started.get("world_sequence_scheduled", false)) and not token.is_empty(), "The production Crew-favor event did not schedule its delivery sequence.")
	var physical := _dict(run_state.delivery_snapshot().get("physical", {}))
	if str(physical.get("cargo_state", "")) == "pickup_pending":
		var pickup := run_state.delivery_apply_physical_action("pickup", "integ06_1:pickup")
		_require(bool(pickup.get("ok", false)), "The production delivery pickup could not be completed.")
	var targets := _array(run_state.delivery_snapshot().get("targets", []))
	var target_node := str(_dict(targets[0]).get("node_id", "")) if not targets.is_empty() else ""
	_require(not target_node.is_empty(), "The production delivery selected no real-map target.")
	var traveled := generator.travel_environment_result(run_state, target_node, true) if not target_node.is_empty() else {}
	var layer_entry := _enter_requested_punchline_layer(run_state, generator, library) if bool(traveled.get("ok", false)) else {"ok": false}
	_require(bool(layer_entry.get("ok", false)), "The requested production Punchline layer could not be entered: %s" % JSON.stringify(layer_entry))
	var arrival := run_state.delivery_resolve_travel_arrival({}, {}) if bool(traveled.get("ok", false)) else {}
	# FoundationMain routes a room with an installed scenario through scenario
	# finalization; that same boundary activates and composes eligible Crew/world
	# mounts without replacing the scenario-owned base inventory.
	var finalized := run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}}) if bool(arrival.get("ok", false)) else {}
	var composed := run_state.world_sequence_composed_projection()
	_require(bool(traveled.get("ok", false)) and bool(layer_entry.get("ok", false)) and bool(arrival.get("ok", false)) and bool(finalized.get("ok", false)), "The production Crew delivery did not mount at its real target: %s" % JSON.stringify({"travel": traveled, "layer": layer_entry, "arrival": arrival, "finalized": finalized}))
	_require(not composed.is_empty() and run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node) == token, "The mounted Crew sequence did not own the delivery handoff channel.")
	var observed_archetype := str(run_state.current_environment.get("archetype_id", ""))
	var observed_scenario := str(run_state.current_environment.get("scenario_id", ""))
	var observed_layer := str(run_state.current_environment.get("current_layer_id", ""))
	var observed_surface_inventory := _layer_surface_inventory(run_state.current_environment)
	var observed_traveler_ids := _array(run_state.current_environment.get("traveler_ids", [])).duplicate()
	var observed_sweep_active := bool(run_state.town_state.sweep_internal_status().get("active", false))
	var initial_maximal_live := not str(run_state.current_environment.get("scenario_id", "")).is_empty() \
		and not _array(observed_surface_inventory.get("game_ids", [])).is_empty() \
		and not _array(observed_surface_inventory.get("event_ids", [])).is_empty() \
		and not _array(observed_surface_inventory.get("service_ids", [])).is_empty() \
		and not observed_traveler_ids.is_empty() \
		and observed_sweep_active
	var pre_replay_ok := true
	if order_id == "replay_save_load_abandon":
		pre_replay_ok = _replay_finalize_is_idempotent(run_state, library)
		_require(pre_replay_ok, "Finalization replay before save fired a consequence twice or changed the registration ledger.")
	var travel_return_ok := true
	if order_id == "travel_return_save_load_abandon":
		travel_return_ok = _travel_away_and_return(run_state, generator, library, target_node, token, true)
		_require(travel_return_ok, "Travel away and return did not restore the active maximal composition cleanly.")
	var expired_ok := true
	if order_id == "expire_save_load_travel_return":
		var remaining := maxi(1, int(run_state.delivery_snapshot().get("deadline_remaining", 1)))
		run_state.advance_environment_turns(remaining + 1)
		expired_ok = not run_state.delivery_has_active_run() and not str(_dict(run_state.delivery_snapshot().get("resolution", {})).get("reason", "")).is_empty()
		_require(expired_ok, "Letting the maximal composition expire did not close the delivery at its production action boundary.")

	# Save while the scenario/world sequence/delivery/town systems coexist.  Then
	# replay the same arrival and finalization boundaries; neither may duplicate a
	# consequence or registration.
	var save_service: SaveService = SaveServiceScript.new()
	save_service.clear_run(COMPOSITION_SAVE_SLOT)
	var before := _composition_contract(run_state, token)
	var before_sha256 := JSON.stringify(_normalize_json_numbers(before), "", true).sha256_text()
	var environment_before_save := run_state.current_environment.duplicate(true)
	var target_archetype := observed_archetype
	var target_scenario := observed_scenario
	var target_surface_inventory := observed_surface_inventory
	var target_traveler_ids := observed_traveler_ids
	var target_sweep_active := observed_sweep_active
	var durable_world_before := CrewWorldSequenceAdapterScript.durable_container(run_state.current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
	var delivery_before_save := run_state.delivery_snapshot()
	var save_error := save_service.save_run(run_state, COMPOSITION_SAVE_SLOT)
	var loaded_variant: Variant = save_service.load_run(COMPOSITION_SAVE_SLOT) if save_error == OK else null
	var save_load_exact := false
	var save_load_changed_keys: Array = []
	var replay_idempotent := false
	var abandonment_clean := false
	var abandonment_ok := false
	var unmount_ok := false
	var final_registration_lifecycle := ""
	var delivery_after_load: Dictionary = {}
	var after_sha256 := ""
	_require(save_error == OK and loaded_variant is RunState, "Production SaveService could not round-trip the mounted Crew composition (error %d)." % save_error)
	if loaded_variant is RunState:
		run_state = loaded_variant as RunState
		delivery_after_load = run_state.delivery_snapshot()
		_require(RunStateScript.scenario_restore_equivalent(environment_before_save, run_state.current_environment), "SaveService changed the mounted room's causal scenario restore contract before rebuild.")
		var durable_world_after_load := CrewWorldSequenceAdapterScript.durable_container(run_state.current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
		_require(JSON.stringify(_normalize_json_numbers(durable_world_before)) == JSON.stringify(_normalize_json_numbers(durable_world_after_load)), "SaveService changed the mounted world's durable public authority before rebuild.")
		var restored_scenario := run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
		_require(bool(restored_scenario.get("ok", false)), "Save/load could not restore the mounted composition's semantic records.")
		var after := _composition_contract(run_state, token)
		after_sha256 = JSON.stringify(_normalize_json_numbers(after), "", true).sha256_text()
		save_load_exact = JSON.stringify(_normalize_composition_contract(before)) == JSON.stringify(_normalize_composition_contract(after))
		save_load_changed_keys = _changed_top_level_keys(before, after)
		_require(save_load_exact, "Mounted scenario/Crew/delivery/town causal and public composition changed across SaveService round trip.")
		replay_idempotent = _replay_finalize_is_idempotent(run_state, library) if run_state.delivery_has_active_run() else true
		_require(replay_idempotent, "Replayed arrival/finalization fired a Crew delivery consequence twice or changed the registration ledger.")
		var abandoned := run_state.delivery_abandon("integ06_1_leave_mid_everything") if run_state.delivery_has_active_run() else {"ok": true, "inactive": true}
		var owner_after_abandon := run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node)
		var unmounted := {"ok": true, "inactive": true}
		if not owner_after_abandon.is_empty():
			unmounted = run_state.world_sequence_unmount(token, "abandoned")
		var final_registration := _dict(run_state.world_sequence_registrations.get(token, {}))
		abandonment_ok = bool(abandoned.get("ok", false))
		unmount_ok = bool(unmounted.get("ok", false))
		final_registration_lifecycle = str(final_registration.get("lifecycle", ""))
		abandonment_clean = not run_state.delivery_has_active_run() \
			and run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node).is_empty() \
			and str(final_registration.get("lifecycle", "")) == "cleaned" \
			and _array(final_registration.get("pending_outcomes", [])).is_empty()
		_require(bool(abandoned.get("ok", false)) and bool(unmounted.get("ok", false)), "Leaving mid-composition did not provide a safe delivery/sequence cleanup path.")
		_require(abandonment_clean, "Abandonment left an orphaned delivery or handoff owner.")
		if order_id in ["save_load_abandon_travel_return", "expire_save_load_travel_return"]:
			var cleanup_return_ok := _travel_away_and_return(run_state, generator, library, target_node, token, false)
			abandonment_clean = abandonment_clean and cleanup_return_ok
			_require(cleanup_return_ok, "Travel away and return resurrected an expired or abandoned composition.")
	save_service.clear_run(COMPOSITION_SAVE_SLOT)
	return {
		"eligibility_source": str(prepared.get("eligibility_source", "")),
		"crew_lender_node": str(prepared.get("crew_lender_node", "")),
		"event_selection": _dict(prepared.get("event_selection", {})),
		"initial_maximal_live": initial_maximal_live,
		"order_id": order_id,
		"order_pre_replay_ok": pre_replay_ok,
		"order_travel_return_ok": travel_return_ok,
		"order_expired_ok": expired_ok,
		"target_node": target_node,
		"world_node_count": _array(run_state.world_map.get("nodes", [])).size(),
		"target_archetype": target_archetype,
		"scenario_id": target_scenario,
		"layer_id": observed_layer,
		"surface_inventory": target_surface_inventory,
		"traveler_ids": target_traveler_ids,
		"traveler_count": target_traveler_ids.size(),
		"sweep_active": target_sweep_active,
		"crew_sequence_token": token,
		"before_sha256": before_sha256,
		"after_sha256": after_sha256,
		"save_load_exact": save_load_exact,
		"derived_rebuild_changed_keys": save_load_changed_keys,
		"replay_idempotent": replay_idempotent,
		"abandonment_clean": abandonment_clean,
		"abandonment_ok": abandonment_ok,
		"unmount_ok": unmount_ok,
		"final_registration_lifecycle": final_registration_lifecycle,
		"delivery_before_save_status": str(delivery_before_save.get("status", "")),
		"delivery_after_load_status": str(delivery_after_load.get("status", "")),
	}


func _replay_finalize_is_idempotent(run_state: RunState, library: ContentLibrary) -> bool:
	var bankroll_before := run_state.bankroll
	var heat_before := run_state.suspicion_level()
	var story_before := run_state.story_log.size()
	var registrations_before := JSON.stringify(_normalize_json_numbers(run_state.world_sequence_registrations), "", true)
	var finalized := run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
	return bool(finalized.get("ok", false)) \
		and run_state.bankroll == bankroll_before \
		and run_state.suspicion_level() == heat_before \
		and run_state.story_log.size() == story_before \
		and JSON.stringify(_normalize_json_numbers(run_state.world_sequence_registrations), "", true) == registrations_before


func _enter_requested_punchline_layer(run_state: RunState, generator: RunGenerator, library: ContentLibrary) -> Dictionary:
	if target_layer_id.is_empty():
		return {"ok": true, "layer_id": str(run_state.current_environment.get("current_layer_id", "")), "method": "default"}
	if str(run_state.current_environment.get("archetype_id", "")) != PUNCHLINE_ID:
		return {"ok": false, "message": "A layer was requested for a non-Punchline delivery target."}
	if str(run_state.current_environment.get("current_layer_id", "")) == target_layer_id:
		return {"ok": true, "layer_id": target_layer_id, "method": "persisted_layer_reentry"}
	if target_layer_id == "club":
		var club_entry := generator.enter_environment_layer(run_state, "club", false)
		return {"ok": bool(club_entry.get("ok", false)), "layer_id": "club", "method": "public_layer_transition", "entry": club_entry}
	if target_layer_id not in ["casino", "back_room"]:
		return {"ok": false, "message": "Unknown Punchline layer: %s" % target_layer_id}
	var casino_access := run_state.environment_layer_access_status("casino")
	var discovery: Dictionary = {"ok": true, "already_discovered": true}
	if not bool(casino_access.get("available", false)):
		var side_door: EventModule = EventModuleScript.new()
		side_door.setup(library.event("side_door"), library)
		discovery = side_door.resolve(run_state, run_state.current_environment, "punchline_password")
		if not bool(discovery.get("ok", false)):
			return {"ok": false, "message": "The authored side-door discovery path did not open L2.", "discovery": discovery}
	var casino_entry := {"ok": true, "already_entered": true}
	if str(run_state.current_environment.get("current_layer_id", "")) != "casino":
		casino_entry = generator.enter_environment_layer(run_state, "casino", false)
		if not bool(casino_entry.get("ok", false)):
			return {"ok": false, "message": "The discovered casino layer could not be entered.", "casino_entry": casino_entry}
	if target_layer_id == "casino":
		return {"ok": true, "layer_id": "casino", "method": "side_door:punchline_password"}
	# L3 is reached through the shipped Crew-standing gate, using the same public
	# trust mutation that ordinary Crew consequences apply. The layer's own access
	# check remains authoritative; this probe never installs a layer directly.
	run_state.crew_add_trust("crew_rook", 10000, "integ06_1_composition_progression")
	var back_room_access := run_state.environment_layer_access_status("back_room")
	var back_room_entry := generator.enter_environment_layer(run_state, "back_room", false) if bool(back_room_access.get("available", false)) else {"ok": false}
	return {
		"ok": bool(back_room_entry.get("ok", false)),
		"layer_id": "back_room",
		"method": "crew_rook_made_standing",
		"access": back_room_access,
		"entry": back_room_entry,
	}


func _travel_away_and_return(run_state: RunState, generator: RunGenerator, library: ContentLibrary, target_node: String, token: String, require_remount: bool) -> bool:
	var neighbors := WorldMapScript.neighbor_ids(run_state.world_map, target_node, false)
	var away_node := ""
	for neighbor_value in neighbors:
		var candidate := str(neighbor_value)
		if not candidate.is_empty() and candidate != target_node:
			away_node = candidate
			break
	if away_node.is_empty():
		return false
	var away := generator.travel_environment_result(run_state, away_node, true)
	if not bool(away.get("ok", false)):
		return false
	var returned := generator.travel_environment_result(run_state, target_node, true)
	if not bool(returned.get("ok", false)):
		return false
	var layer_entry := _enter_requested_punchline_layer(run_state, generator, library)
	if not bool(layer_entry.get("ok", false)):
		return false
	var arrival := run_state.delivery_resolve_travel_arrival({}, {}) if run_state.delivery_has_active_run() else {"ok": true, "inactive": true}
	var finalized := run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
	if not bool(arrival.get("ok", false)) or not bool(finalized.get("ok", false)):
		return false
	var mounted_owner := run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node)
	if require_remount:
		return run_state.delivery_has_active_run() and mounted_owner == token
	return not run_state.delivery_has_active_run() and mounted_owner.is_empty()


func _prepare_natural_crew_delivery(library: ContentLibrary, delivery_seed: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(delivery_seed)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var crew_lender_node := ""
	for node_value in _array(run_state.world_map.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_id := str((node_value as Dictionary).get("id", ""))
		if node_id.is_empty():
			continue
		var traveled := generator.travel_environment_result(run_state, node_id, true)
		if bool(traveled.get("ok", false)) and _array(run_state.current_environment.get("lender_hooks", [])).has("the_crew"):
			crew_lender_node = node_id
			break
	if crew_lender_node.is_empty():
		return {"eligibility_source": "production_world_map+RunActionService+production_event_selector"}
	var action_service: RunActionService = RunActionServiceScript.new()
	action_service.setup(library, run_state)
	var lender_result := action_service.use_hook("lender", "the_crew")
	if not bool(lender_result.get("ok", false)):
		return {
			"eligibility_source": "production_world_map+RunActionService+production_event_selector",
			"crew_lender_node": crew_lender_node,
			"lender_result": lender_result,
		}
	# The authored Crew note reaches favor_due only by crossing its real debt
	# clock. Align the same production action clock with the authored Police Sweep
	# start so the resulting node is maximal without mutating either subsystem.
	var sweep_start_action := int(run_state.town_state.police_sweep.snapshot().get("start_action", 0))
	var action_advance := maxi(2, sweep_start_action - int(run_state.town_state.action_index))
	run_state.advance_environment_turns(action_advance)
	var selected: Dictionary = {}
	for _attempt in range(24):
		selected = _enqueue_next_production_action_event(run_state, library, "game_action")
		if str(selected.get("event_id", "")) == "crew_favor_delivery":
			break
		if bool(selected.get("enqueued", false)):
			break
		run_state.advance_environment_turns(1)
	if str(selected.get("event_id", "")) != "crew_favor_delivery" or not run_state.triggered_event_pending("crew_favor_delivery"):
		return {
			"eligibility_source": "production_world_map+RunActionService+production_event_selector",
			"crew_lender_node": crew_lender_node,
			"lender_result": lender_result,
			"event_selection": selected,
		}
	return {
		"run_state": run_state,
		"generator": generator,
		"eligibility_source": "production_world_map+RunActionService+ContentLibrary.action_trigger_event_candidates_for_context_readonly+EventModule.can_trigger+event_cadence",
		"crew_lender_node": crew_lender_node,
		"lender_result": lender_result,
		"event_selection": selected,
	}


func _enqueue_next_production_action_event(run_state: RunState, library: ContentLibrary, source: String) -> Dictionary:
	var context := {
		"trigger": "action",
		"type": "action",
		"source": source,
		"turns": int(run_state.current_environment.get("turns", 0)),
	}
	var rolled: Array = []
	var rng: RngStream = run_state.create_event_cadence_rng()
	for definition_value in library.action_trigger_event_candidates_for_context_readonly(source, context, run_state.current_environment):
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var event_id := str(definition.get("id", ""))
		var trigger := _dict(definition.get("trigger", {}))
		var trigger_type := str(trigger.get("type", "manual"))
		if trigger_type != "random" or not run_state.event_cadence_allows_world_event(event_id, trigger_type, source, definition):
			continue
		var event_module: EventModule = EventModuleScript.new()
		event_module.setup(definition, library)
		if not event_module.can_trigger(run_state, run_state.current_environment, context):
			continue
		var chance := clampi(int(trigger.get("chance_percent", 100)), 0, 100)
		var chance_roll := rng.randi_range(1, 100)
		if chance_roll <= chance:
			rolled.append({"id": event_id, "event": definition, "chance": chance, "roll": chance_roll})
	var picked := _weighted_production_event_pick(run_state, rolled, rng)
	var picked_id := str(picked.get("id", ""))
	var enqueued := false
	if not picked_id.is_empty():
		var queued_context := context.duplicate(true)
		queued_context["environment_snapshot"] = RunStateScript.environment_context_snapshot(run_state.current_environment)
		enqueued = run_state.enqueue_triggered_event(picked_id, source, queued_context)
		if enqueued:
			var picked_definition := _dict(picked.get("event", {}))
			run_state.event_cadence_note_event_enqueued(picked_id, not run_state.event_cadence_event_bypasses_budget(picked_id, "random", source, picked_definition))
	run_state.save_event_cadence_rng(rng)
	return {
		"event_id": picked_id,
		"enqueued": enqueued,
		"rolled_ids": rolled.map(func(row: Variant) -> String: return str(_dict(row).get("id", ""))),
		"candidate_source": "ContentLibrary.action_trigger_event_candidates_for_context_readonly",
	}


func _weighted_production_event_pick(run_state: RunState, candidates: Array, rng: RngStream) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight := 0
	for candidate_value in candidates:
		total_weight += maxi(1, run_state.event_cadence_weight_for_event(str(_dict(candidate_value).get("id", ""))))
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for candidate_value in candidates:
		var candidate := _dict(candidate_value)
		cursor += maxi(1, run_state.event_cadence_weight_for_event(str(candidate.get("id", ""))))
		if roll <= cursor:
			return candidate
	return _dict(candidates[candidates.size() - 1])


func _composition_contract(run_state: RunState, token: String) -> Dictionary:
	return {
		"environment": RunStateScript.scenario_restore_equivalence_snapshot(run_state.current_environment),
		"delivery": run_state.delivery_snapshot(),
		"world_sequence": run_state.world_sequence_snapshot(token),
		"registration": _dict(run_state.world_sequence_registrations.get(token, {})),
		"town": run_state.town_state.snapshot(),
		"story_log": run_state.story_log.duplicate(true),
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
	}


func _changed_top_level_keys(before: Dictionary, after: Dictionary) -> Array:
	var keys: Array = before.keys()
	for key in after.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var changed: Array = []
	for key in keys:
		if JSON.stringify(_normalize_json_numbers(before.get(key))) != JSON.stringify(_normalize_json_numbers(after.get(key))):
			changed.append(str(key))
	return changed


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in (value as Dictionary).keys():
			result[key] = _normalize_json_numbers((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array:
			result.append(_normalize_json_numbers(entry))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == round(float(value)):
		return int(value)
	return value


func _normalize_composition_contract(value: Dictionary) -> Dictionary:
	var result := _normalize_json_numbers(value) as Dictionary
	var environment := _dict(result.get("environment", {}))
	var causal := _dict(environment.get("causal_environment", {}))
	var layout_records := _array(causal.get("scenario_layout_base_records", []))
	for record_value in layout_records:
		if typeof(record_value) != TYPE_DICTIONARY: continue
		(record_value as Dictionary).erase("pixel_hit_bounds")
		(record_value as Dictionary).erase("focus_point")
	layout_records.sort_custom(func(left: Variant, right: Variant) -> bool:
		var a := _dict(left)
		var b := _dict(right)
		return "%s::%s" % [str(a.get("owner_namespace", "")), str(a.get("stable_object_id", ""))] < "%s::%s" % [str(b.get("owner_namespace", "")), str(b.get("stable_object_id", ""))]
	)
	if causal.has("scenario_layout_base_records"): causal["scenario_layout_base_records"] = layout_records
	var scenario_state := _dict(causal.get("scenario_sequence_state", {}))
	var scenario_semantic := _dict(scenario_state.get("semantic_state", {}))
	scenario_semantic.erase("transition_queue")
	if not scenario_state.is_empty():
		scenario_state["semantic_state"] = scenario_semantic
		causal["scenario_sequence_state"] = scenario_state
	environment["causal_environment"] = causal
	result["environment"] = environment
	var world_sequence := _dict(result.get("world_sequence", {}))
	var projection := _dict(world_sequence.get("projection", {}))
	projection.erase("pending_transition_count")
	world_sequence["projection"] = projection
	result["world_sequence"] = world_sequence
	return result


func _layer_surface_inventory(environment: Dictionary) -> Dictionary:
	return {
		"game_ids": _array(environment.get("game_ids", [])),
		"event_ids": _array(environment.get("event_ids", [])),
		"service_ids": _array(environment.get("service_ids", [])),
		"traveler_ids": _array(environment.get("traveler_ids", [])),
	}
func _select_production_run(library: ContentLibrary) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var sweep := run_state.town_state.police_sweep.snapshot()
	var traveler := run_state.traveler_state(TRAVELER_ID)
	if _array(sweep.get("segments", [])).is_empty() or traveler.is_empty():
		return {}
	if int(traveler.get("depart_action", 0)) >= int(sweep.get("end_action", 0)) - 1:
		return {}
	return {"seed": seed_text, "run_state": run_state, "generator": generator}


func _finish(details: Dictionary) -> void:
	var report := {
		"tool": "wave_b_composition_probe",
		"passed": failures.is_empty(),
		"details": details,
		"failures": failures.duplicate(),
	}
	_write_report(report)
	print("WAVE_B_COMPOSITION %s seed=%s traveler=%s sweep=%s punchline=%s report=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		str(details.get("selected_seed", seed_text)),
		JSON.stringify(details.get("traveler", {})),
		JSON.stringify(details.get("police_sweep", {})),
		JSON.stringify(details.get("punchline", {})),
		report_path,
	])
	if failures.is_empty():
		quit(0)
		return
	for failure_value in failures:
		push_error(str(failure_value))
	quit(1)


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _normalized_report_path(value: String) -> String:
	if value.is_empty():
		return DEFAULT_REPORT_PATH
	if value.to_lower().ends_with(".json"):
		return value
	return "%s/report.json" % value.trim_suffix("/")


func _write_report(report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write composition report: %s." % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
