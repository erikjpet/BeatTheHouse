extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
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
var failures: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_text = argument.trim_prefix("--seed=").strip_edges()
		elif argument.begins_with("--out="):
			report_path = _normalized_report_path(argument.trim_prefix("--out=").strip_edges())
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
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


func _exercise_delivery_composition(library: ContentLibrary) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("%s-DELIVERY" % seed_text)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	run_state.enqueue_triggered_event("crew_favor_delivery", "integ06_1_composition")
	var event_module: EventModule = EventModuleScript.new()
	event_module.setup(library.event("crew_favor_delivery"), library)
	var started := event_module.resolve(run_state, run_state.current_environment, "run_package")
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
	var arrival := run_state.delivery_resolve_travel_arrival({}, {}) if bool(traveled.get("ok", false)) else {}
	# FoundationMain routes a room with an installed scenario through scenario
	# finalization; that same boundary activates and composes eligible Crew/world
	# mounts without replacing the scenario-owned base inventory.
	var finalized := run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}}) if bool(arrival.get("ok", false)) else {}
	var composed := run_state.world_sequence_composed_projection()
	_require(bool(traveled.get("ok", false)) and bool(arrival.get("ok", false)) and bool(finalized.get("ok", false)), "The production Crew delivery did not mount at its real target: %s" % JSON.stringify({"travel": traveled, "arrival": arrival, "finalized": finalized}))
	_require(not composed.is_empty() and run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node) == token, "The mounted Crew sequence did not own the delivery handoff channel.")

	# Save while the scenario/world sequence/delivery/town systems coexist.  Then
	# replay the same arrival and finalization boundaries; neither may duplicate a
	# consequence or registration.
	var save_service: SaveService = SaveServiceScript.new()
	save_service.clear_run(COMPOSITION_SAVE_SLOT)
	var before := _composition_contract(run_state, token)
	var environment_before_save := run_state.current_environment.duplicate(true)
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
		save_load_exact = JSON.stringify(_normalize_composition_contract(before)) == JSON.stringify(_normalize_composition_contract(after))
		save_load_changed_keys = _changed_top_level_keys(before, after)
		_require(save_load_exact, "Mounted scenario/Crew/delivery/town causal and public composition changed across SaveService round trip.")
		var bankroll_before_replay := run_state.bankroll
		var heat_before_replay := run_state.suspicion_level()
		var story_before_replay := run_state.story_log.size()
		var registrations_before_replay := JSON.stringify(run_state.world_sequence_registrations)
		run_state.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
		replay_idempotent = run_state.bankroll == bankroll_before_replay \
			and run_state.suspicion_level() == heat_before_replay \
			and run_state.story_log.size() == story_before_replay \
			and JSON.stringify(run_state.world_sequence_registrations) == registrations_before_replay
		_require(run_state.bankroll == bankroll_before_replay and run_state.suspicion_level() == heat_before_replay and run_state.story_log.size() == story_before_replay, "Replayed arrival/finalization fired a Crew delivery consequence twice.")
		_require(JSON.stringify(run_state.world_sequence_registrations) == registrations_before_replay, "Replayed arrival/finalization changed the Crew registration ledger.")
		var abandoned := run_state.delivery_abandon("integ06_1_leave_mid_everything")
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
	save_service.clear_run(COMPOSITION_SAVE_SLOT)
	return {
		"target_node": target_node,
		"scenario_id": str(run_state.current_environment.get("scenario_id", "")),
		"surface_inventory": _layer_surface_inventory(run_state.current_environment),
		"traveler_count": _array(run_state.current_environment.get("traveler_ids", [])).size(),
		"sweep_active": bool(run_state.town_state.sweep_internal_status().get("active", false)),
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
