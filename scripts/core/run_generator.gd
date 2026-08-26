class_name RunGenerator
extends RefCounted

# Builds deterministic environments from library data.

const GrandCasinoShowdownModelScript := preload("res://scripts/core/grand_casino_showdown_model.gd")
const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")

var library: ContentLibrary


# Stores the content library used for generation.
func _init(p_library: ContentLibrary) -> void:
	library = p_library


# Builds and assigns the next environment for a run. A prevalidated target is
# reserved for the travel UI after it validates arrival hours, then advances the clock.
func next_environment(run_state: RunState, target_archetype_id: String = "", target_prevalidated: bool = false) -> EnvironmentInstance:
	var rng := run_state.create_rng()
	if run_state.has_world_map() or run_state.current_environment.is_empty():
		return _next_world_environment(run_state, target_archetype_id, rng, target_prevalidated)
	var depth := run_state.environment_travel_count()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _pick_archetype(run_state, depth, rng, target_archetype_id)
	var scenario := _select_scenario(run_state, str(archetype.get("id", "")), rng)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config, scenario)
	var environment_data := environment.to_dict()
	run_state.apply_town_generation_modifiers(environment_data, rng)
	CrewRecruitmentModelScript.apply_to_environment(run_state, environment_data)
	environment_data["game_states"] = _generated_game_states(run_state, environment_data, rng)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	var source_id := run_state.current_world_node_id()
	var destination_id := str(environment_data.get("world_node_id", environment_data.get("archetype_id", ""))).strip_edges()
	run_state.scenario_publish_travel("travel_departed", source_id, destination_id, "legacy")
	run_state.scenario_flush_facts()
	run_state.save_rng(rng)
	run_state.set_environment(environment_data)
	run_state.scenario_publish_travel("travel_arrived", source_id, run_state.current_world_node_id(), "legacy")
	return EnvironmentInstance.from_dict(run_state.current_environment)


# Builds the next environment from a cloned run so route previews do not mutate state.
func preview_environment(run_state: RunState, target_archetype_id: String = "") -> Dictionary:
	if run_state == null:
		return {}
	var stored_preview := _stored_world_environment_preview(run_state, target_archetype_id)
	if not stored_preview.is_empty():
		return stored_preview
	# Exact scouting only consumes the destination's public offers/hooks. Cloning
	# the full run copied every portable ticket and every visited room for each
	# route card. Build the deterministic preview from the same logical run fields
	# with accumulated player-owned payloads and stored room bodies omitted.
	var preview_state := RunState.new()
	var preview_data := run_state.to_save_snapshot()
	# Historical receipts and timeline samples are not generation inputs. Copying
	# and normalizing them for each scouted route made preview cost grow with run
	# age even though they cannot affect the destination. Progression remains in
	# narrative/story flags, while environment_history is retained because its
	# count participates in deterministic depth generation.
	preview_data["story_log"] = []
	preview_data["story_log_archive_count"] = run_state.story_log_entry_count()
	# from_dict synthesizes a baseline when heat history is empty. Retain one
	# compact sample so the preview clone remains read-only with respect to the
	# authoritative current heat while avoiding the full timeline copy.
	var preview_heat_sample: Dictionary = {}
	if not run_state.heat_history.is_empty() and typeof(run_state.heat_history[run_state.heat_history.size() - 1]) == TYPE_DICTIONARY:
		preview_heat_sample = (run_state.heat_history[run_state.heat_history.size() - 1] as Dictionary).duplicate(false)
	else:
		preview_heat_sample = {
			"action_index": run_state.environment_travel_count(),
			"game_clock_minutes": run_state.game_clock_minutes,
			"heat_value": run_state.suspicion_level(),
			"environment_id": str(run_state.current_environment.get("id", "")),
		}
	preview_data["heat_history"] = [preview_heat_sample]
	preview_data["pending_triggered_events"] = []
	preview_data["pending_bags"] = []
	preview_data["active_triggered_event"] = {}
	preview_data["grand_casino_atm_interest_notifications"] = []
	preview_data["portable_ticket_piles"] = {}
	preview_data["world_map"] = WorldMap.normalize_topology(run_state.world_map)
	preview_data["current_environment"] = RunState.environment_context_snapshot(run_state.current_environment)
	preview_data["grand_casino_room_states"] = {}
	preview_state.from_dict(preview_data)
	var environment := next_environment(preview_state, target_archetype_id)
	return _travel_preview_environment_projection(environment.to_dict())


func _stored_world_environment_preview(run_state: RunState, target_archetype_id: String) -> Dictionary:
	if not run_state.has_world_map():
		return {}
	var clean_target := target_archetype_id.strip_edges()
	var nodes_value: Variant = run_state.world_map.get("nodes", [])
	if clean_target.is_empty() or typeof(nodes_value) != TYPE_ARRAY:
		return {}
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if str(node.get("id", "")) != clean_target:
			continue
		var environment_value: Variant = node.get("environment", {})
		if typeof(environment_value) == TYPE_DICTIONARY and not (environment_value as Dictionary).is_empty():
			return _travel_preview_environment_projection(environment_value as Dictionary)
		return {}
	return {}


func _travel_preview_environment_projection(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["tier", "kind", "game_ids", "service_ids", "lender_hooks", "item_offers", "travel_locked_actions"]:
		if not environment.has(key):
			continue
		var value: Variant = environment.get(key)
		if typeof(value) == TYPE_ARRAY:
			result[key] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			result[key] = (value as Dictionary).duplicate(true)
		else:
			result[key] = value
	return result


# Swaps casino sub-environments without moving the world-map cursor.
func enter_grand_casino_room(run_state: RunState, target_archetype_id: String) -> bool:
	if run_state == null or not run_state.is_grand_casino_environment(run_state.current_environment):
		return false
	var target_id := target_archetype_id.strip_edges()
	if not RunState.GRAND_CASINO_ARCHETYPE_IDS.has(target_id):
		return false
	var flags: Dictionary = run_state.current_environment.get("local_narrative_flags", {}) if typeof(run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var access := run_state.grand_casino_room_access_status(target_id, int(flags.get("casino_high_limit_buy_in", 60)))
	if not bool(access.get("available", false)):
		return false
	var source_room_id := str(run_state.current_environment.get("archetype_id", "")).strip_edges()
	if source_room_id != target_id:
		run_state.scenario_publish_travel("travel_departed", source_room_id, target_id, "grand_room")
		run_state.scenario_flush_facts()
	run_state.store_grand_casino_room_environment(run_state.current_environment)
	var environment_data := run_state.grand_casino_room_environment(target_id)
	if environment_data.is_empty():
		var archetype := _archetype_by_id(target_id)
		if archetype.is_empty():
			return false
		var rng := run_state.create_rng()
		var depth := maxi(0, int(run_state.current_environment.get("depth", run_state.environment_travel_count())))
		var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config)
		environment_data = environment.to_dict()
		run_state.apply_town_generation_modifiers(environment_data, rng)
		environment_data["game_states"] = _generated_game_states(run_state, environment_data, rng)
		run_state.save_rng(rng)
	_apply_cage_gift_shop_stock(run_state, environment_data)
	environment_data["world_node_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
	environment_data["world_map_travel"] = true
	_apply_world_travel_targets(environment_data, run_state, run_state.world_map, RunState.GRAND_CASINO_ARCHETYPE_ID)
	# Grand Casino subrooms share one canonical world node. Apply seeded Crew
	# placement only after that identity is present, and reapply it for restored
	# rooms so itinerary rotation happens at the same revisit boundary as town.
	CrewRecruitmentModelScript.apply_to_environment(run_state, environment_data)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	run_state.set_environment(environment_data)
	if source_room_id != target_id:
		run_state.scenario_publish_travel("travel_arrived", source_room_id, target_id, "grand_room")
	return true


# Changes floors inside one layered venue without world travel or route cost.
func enter_environment_layer(run_state: RunState, target_layer_id: String, advance_action: bool = true) -> Dictionary:
	if run_state == null or not run_state.is_layered_environment():
		return {"ok": false, "message": "This venue has no interior layers."}
	var target_id := target_layer_id.strip_edges()
	var access := run_state.environment_layer_access_status(target_id)
	if not bool(access.get("available", false)):
		return {"ok": false, "hidden": bool(access.get("hidden", false)), "message": str(access.get("reason", "The door stays shut."))}
	if bool(access.get("discover_on_enter", false)):
		run_state.discover_environment_layer(target_id, str(access.get("access_method", "access")))
	if advance_action:
		run_state.advance_environment_turns(1)
	var layer_state := run_state.environment_layer_state(target_id)
	if layer_state.is_empty():
		var archetype_id := str(run_state.current_environment.get("archetype_id", "")).strip_edges()
		var archetype := _archetype_by_id(archetype_id)
		if archetype.is_empty():
			return {"ok": false, "message": "The room definition is missing."}
		var layer_rng := run_state.create_rng("environment_layer:%s:%s" % [str(run_state.current_environment.get("world_node_id", archetype_id)), target_id])
		var scenario_state := ScenarioEngineScript.normalize_state(run_state.current_environment.get("scenario_state", {}))
		var generated := EnvironmentInstance.from_archetype_layer(
			archetype,
			target_id,
			int(run_state.current_environment.get("depth", 0)),
			layer_rng,
			library,
			run_state.challenge_config,
			scenario_state
		)
		layer_state = generated.to_dict()
	if layer_state.is_empty():
		return {"ok": false, "message": "The room could not be restored."}
	if not layer_state.has("town_conditions"):
		run_state.apply_town_generation_modifiers(layer_state)
	var stored_game_states: Variant = layer_state.get("game_states", null)
	if typeof(stored_game_states) != TYPE_DICTIONARY or (stored_game_states as Dictionary).is_empty() and not _copy_array(layer_state.get("game_ids", [])).is_empty():
		var game_rng := run_state.create_rng("environment_layer_games:%s:%s" % [str(run_state.current_environment.get("world_node_id", run_state.current_environment.get("archetype_id", ""))), target_id])
		layer_state["game_states"] = _generated_game_states(run_state, layer_state, game_rng)
	if run_state.has_world_map():
		_apply_world_travel_targets(layer_state, run_state, run_state.world_map, run_state.current_world_node_id())
	layer_state["layout"] = EnvironmentInstance.ensure_generated_layout(layer_state)
	var source_layer_id := str(run_state.current_environment.get("current_layer_id", "")).strip_edges()
	if source_layer_id != target_id:
		run_state.scenario_publish_travel("travel_departed", source_layer_id, target_id, "layer")
		run_state.scenario_flush_facts()
	if not run_state.install_environment_layer_state(target_id, layer_state):
		return {"ok": false, "message": "The room could not be entered."}
	if source_layer_id != target_id:
		run_state.scenario_publish_travel("travel_arrived", source_layer_id, target_id, "layer")
	# Scenario reconciliation and layer installation can replace flat event
	# arrays. Recompute recruitment/presence against the final active layer so
	# real side-door entries and restored revisits expose the authored fallback.
	CrewRecruitmentModelScript.apply_to_environment(run_state, run_state.current_environment)
	if run_state.has_world_map():
		run_state.store_current_world_node_environment()
	return {
		"ok": true,
		"layer_id": target_id,
		"access_method": str(access.get("access_method", "open")),
		"message": str(layer_state.get("layer_entry_message", "You pass through the interior door.")),
	}


func _apply_cage_gift_shop_stock(run_state: RunState, environment_data: Dictionary) -> void:
	if str(environment_data.get("archetype_id", "")) != RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return
	if typeof(environment_data.get("cage_gift_shop_state", {})) == TYPE_DICTIONARY and not (environment_data.get("cage_gift_shop_state", {}) as Dictionary).is_empty():
		return
	var flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var shop_config: Dictionary = flags.get("casino_gift_shop", {}) if typeof(flags.get("casino_gift_shop", {})) == TYPE_DICTIONARY else {}
	var showdown_event := library.event(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID) if library != null else {}
	var showdown_payload: Dictionary = showdown_event.get("payload", {}) if typeof(showdown_event.get("payload", {})) == TYPE_DICTIONARY else {}
	var pat_down_config: Dictionary = showdown_payload.get("pat_down", {}) if typeof(showdown_payload.get("pat_down", {})) == TYPE_DICTIONARY else {}
	var allowed: Array = []
	var seen := {}
	for candidate_value in _copy_array(shop_config.get("candidate_offers", [])):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate := (candidate_value as Dictionary).duplicate(true)
		var item_id := str(candidate.get("item_id", candidate.get("id", ""))).strip_edges()
		if item_id.is_empty() or seen.has(item_id) or library.item(item_id).is_empty():
			continue
		if GrandCasinoShowdownModelScript.item_forbidden_by_pat_down(item_id, pat_down_config):
			continue
		seen[item_id] = true
		candidate["id"] = item_id
		candidate["item_id"] = item_id
		candidate["chip_price"] = maxi(1, int(candidate.get("chip_price", 1)))
		candidate["sold"] = false
		allowed.append(candidate)
	var stock_range := _int_range(shop_config.get("stock_count", [3, 4]), 3, 4)
	var minimum := clampi(int(stock_range[0]), 3, 4)
	var maximum := clampi(int(stock_range[1]), minimum, 4)
	if allowed.size() < minimum:
		environment_data["cage_gift_shop_state"] = {"version": 1, "stock": [], "error": "Fewer than three pat-down-safe candidates."}
		return
	var stock_rng := run_state.create_rng("cage_gift_shop").fork("stock:%s:%d" % [run_state.seed_text, int(environment_data.get("depth", 0))])
	var count := stock_rng.randi_range(minimum, mini(maximum, allowed.size()))
	var stock: Array = []
	for selected_value in stock_rng.pick_many(allowed, count):
		stock.append((selected_value as Dictionary).duplicate(true))
	environment_data["cage_gift_shop_state"] = {
		"version": 1,
		"stock": stock,
		"stock_count": stock.size(),
		"fork_state": stock_rng.state_value,
	}


func world_route_for_target(run_state: RunState, target_archetype_id: String) -> Dictionary:
	if run_state == null or not run_state.has_world_map():
		return library.route(target_archetype_id) if library != null else {}
	var map := WorldMap.new(library)
	return map.route_for_target(run_state.world_map, run_state.current_world_node_id(), target_archetype_id)


func world_map_snapshot(run_state: RunState, selected_id: String = "") -> Dictionary:
	if run_state == null:
		return {}
	return WorldMap.snapshot(run_state.world_map, selected_id)


func _next_world_environment(run_state: RunState, target_archetype_id: String, rng: RngStream, target_prevalidated: bool = false) -> EnvironmentInstance:
	var map := WorldMap.new(library)
	var initialized_tutorial_map := false
	if not run_state.has_world_map():
		var initial_map := map.build(run_state, rng.fork("world_map"))
		run_state.set_world_map(_apply_tutorial_initial_map_targets(initial_map, run_state))
		initialized_tutorial_map = run_state.is_tutorial_run()
	var map_data := run_state.world_map
	run_state.configure_town_world(map_data)
	_prime_town_scenarios(run_state, map_data)
	var target_id := target_archetype_id.strip_edges()
	var current_node_id := run_state.current_world_node_id()
	if run_state.current_environment.is_empty() and target_id.is_empty():
		target_id = WorldMap.current_node_id(map_data)
	elif not target_id.is_empty() and not target_prevalidated and not _world_target_is_available(run_state, map_data, current_node_id, target_id):
		return EnvironmentInstance.from_dict(run_state.current_environment)
	elif target_id.is_empty():
		target_id = _fallback_world_neighbor(run_state, map_data, current_node_id)
	if target_id.is_empty():
		return EnvironmentInstance.from_dict(run_state.current_environment) if not run_state.current_environment.is_empty() else _legacy_next_environment(run_state, target_archetype_id, rng)
	var node := WorldMap.node_by_id(map_data, target_id)
	if node.is_empty():
		return EnvironmentInstance.from_dict(run_state.current_environment) if not run_state.current_environment.is_empty() else _legacy_next_environment(run_state, target_archetype_id, rng)
	if run_state.has_world_map() and not run_state.current_environment.is_empty():
		if current_node_id != target_id:
			run_state.scenario_publish_travel("travel_departed", current_node_id, target_id, "world")
			run_state.scenario_flush_facts()
		run_state.store_current_world_node_environment()
	var environment_data := _world_environment_data_for_node(run_state, map_data, node, rng)
	run_state.set_environment(environment_data)
	run_state.enter_world_node(target_id, run_state.current_environment)
	if not current_node_id.is_empty() and current_node_id != target_id:
		run_state.scenario_publish_travel("travel_arrived", current_node_id, target_id, "world")
	_apply_tutorial_authored_travel_targets(run_state, target_id)
	if initialized_tutorial_map:
		# enter_node() normally reveals every neighbor. Reapply the authored first
		# reveal after entering the apartment so Gas Casino cannot leak onto the
		# first tutorial map before the Corner Store route beat.
		run_state.set_world_map(_apply_tutorial_initial_map_targets(run_state.world_map, run_state))
	run_state.save_rng(rng)
	return EnvironmentInstance.from_dict(run_state.current_environment)


func _apply_tutorial_authored_travel_targets(run_state: RunState, environment_id: String) -> void:
	if run_state == null or not run_state.is_tutorial_run():
		return
	var modifiers := run_state.challenge_modifiers()
	var overrides: Dictionary = modifiers.get("tutorial_environment_overrides", {}) if typeof(modifiers.get("tutorial_environment_overrides", {})) == TYPE_DICTIONARY else {}
	var override: Dictionary = overrides.get(environment_id, {}) if typeof(overrides.get(environment_id, {})) == TYPE_DICTIONARY else {}
	if not override.has("next_archetypes") and not override.has("travel_hooks"):
		return
	var targets: Array = []
	for source in [_string_array(override.get("next_archetypes", [])), _string_array(override.get("travel_hooks", []))]:
		for target_id_value in source:
			var target_id := str(target_id_value)
			if not target_id.is_empty() and not targets.has(target_id):
				targets.append(target_id)
	run_state.set_next_archetypes(targets)
	run_state.current_environment["travel_hooks"] = targets.duplicate()
	run_state.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(run_state.current_environment)
	if run_state.has_world_map():
		run_state.store_current_world_node_environment()


# Constrains only the tutorial's first map reveal. Later event choices unlock
# their authored destinations through RunState.add_next_archetypes().
func _apply_tutorial_initial_map_targets(map_data: Dictionary, run_state: RunState) -> Dictionary:
	if run_state == null or not run_state.is_tutorial_run():
		return map_data
	var configured: Variant = run_state.challenge_modifiers().get("tutorial_initial_map_targets", [])
	if typeof(configured) != TYPE_ARRAY or (configured as Array).is_empty():
		return map_data
	var allowed := {str(map_data.get("start_node_id", "")): true}
	for target_value in configured:
		var target_id := str(target_value).strip_edges()
		if not target_id.is_empty():
			allowed[target_id] = true
	var constrained := map_data.duplicate(true)
	var nodes: Array = constrained.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var node_id := str(node.get("id", ""))
		if allowed.has(node_id):
			node["seen"] = true
			if node_id != str(constrained.get("start_node_id", "")):
				node["state"] = WorldMap.STATE_REVEALED
				node["discovered_at_spawn"] = true
				node["discovery_source"] = WorldMap.DISCOVERY_SOURCE_SPAWN
		else:
			node["state"] = WorldMap.STATE_HIDDEN
			node["seen"] = false
			node["discovered_at_spawn"] = false
			node["discovery_source"] = WorldMap.DISCOVERY_SOURCE_NONE
			node.erase("discovered_by_travel")
			node.erase("unlocked")
		nodes[index] = node
	constrained["nodes"] = nodes
	return constrained


func _legacy_next_environment(run_state: RunState, target_archetype_id: String, rng: RngStream) -> EnvironmentInstance:
	var depth := run_state.environment_travel_count()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _pick_archetype(run_state, depth, rng, target_archetype_id)
	var scenario := _select_scenario(run_state, str(archetype.get("id", "")), rng)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config, scenario)
	var environment_data := environment.to_dict()
	run_state.apply_town_generation_modifiers(environment_data, rng)
	CrewRecruitmentModelScript.apply_to_environment(run_state, environment_data)
	environment_data["game_states"] = _generated_game_states(run_state, environment_data, rng)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	run_state.save_rng(rng)
	run_state.set_environment(environment_data)
	return EnvironmentInstance.from_dict(run_state.current_environment)


func _world_environment_data_for_node(run_state: RunState, map_data: Dictionary, node: Dictionary, rng: RngStream) -> Dictionary:
	var node_id := str(node.get("id", "")).strip_edges()
	var stored_environment: Dictionary = node.get("environment", {}) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {}
	if not stored_environment.is_empty() and str(node.get("state", "")) == WorldMap.STATE_VISITED:
		var restored := stored_environment.duplicate(true)
		run_state.apply_town_living_world_context(restored, rng.fork("town_reentry:%s" % node_id))
		CrewRecruitmentModelScript.apply_to_environment(run_state, restored)
		_apply_world_travel_targets(restored, run_state, map_data, node_id)
		restored["world_node_id"] = node_id
		ScenarioEngineScript.ensure_sequence_state(restored, run_state.seeded_scenario_definition_for_node(node_id))
		restored["layout"] = EnvironmentInstance.ensure_generated_layout(restored)
		return restored
	var depth := run_state.environment_travel_count()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _archetype_by_id(node_id)
	if archetype.is_empty():
		archetype = _pick_archetype(run_state, depth, rng, node_id)
	var scenario := _select_scenario(run_state, str(archetype.get("id", node_id)), rng)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config, scenario)
	var environment_data := environment.to_dict()
	run_state.apply_town_generation_modifiers(environment_data, rng)
	# Game generation hooks may publish node-scoped facts. Give them the stable
	# world-node identity before generating their canonical machine state.
	environment_data["world_node_id"] = node_id
	ScenarioEngineScript.ensure_sequence_state(environment_data, scenario)
	CrewRecruitmentModelScript.apply_to_environment(run_state, environment_data)
	environment_data["game_states"] = _generated_game_states(run_state, environment_data, rng)
	if str(archetype.get("kind", "")) == "home":
		_apply_home_profile(run_state, environment_data, archetype, node_id, rng.fork("home_profile:%s" % node_id))
	_apply_world_travel_targets(environment_data, run_state, map_data, node_id)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	return environment_data


func _apply_world_travel_targets(environment_data: Dictionary, run_state: RunState, map_data: Dictionary, node_id: String) -> void:
	var targets := _world_travel_target_ids(run_state, map_data, node_id)
	for local_target_id in _grand_casino_local_target_ids(environment_data):
		if not targets.has(local_target_id):
			targets.append(local_target_id)
	environment_data["next_archetypes"] = targets.duplicate(true)
	environment_data["travel_hooks"] = targets.duplicate(true)
	environment_data["world_map_travel"] = true


func _grand_casino_local_target_ids(environment_data: Dictionary) -> Array:
	var local_flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var result: Array = []
	for target_id_value in local_flags.get("casino_room_targets", []):
		var target_id := str(target_id_value).strip_edges()
		if not target_id.is_empty() and RunState.GRAND_CASINO_ARCHETYPE_IDS.has(target_id) and not result.has(target_id):
			result.append(target_id)
	return result


func _fallback_world_neighbor(run_state: RunState, map_data: Dictionary, source_id: String) -> String:
	var travel_targets := _available_world_travel_target_ids(run_state, map_data, source_id)
	if not travel_targets.is_empty():
		return str(travel_targets[0])
	return ""


func _world_travel_target_ids(run_state: RunState, map_data: Dictionary, source_id: String) -> Array:
	return WorldMap.travel_target_ids(map_data, source_id, WorldMap.TRAVEL_NEW_TARGET_LIMIT, WorldMap.TRAVEL_TOTAL_TARGET_LIMIT, _enabled_world_route_ids(run_state, map_data, source_id))


func _available_world_travel_target_ids(run_state: RunState, map_data: Dictionary, source_id: String) -> Array:
	return WorldMap.travel_target_ids(map_data, source_id, WorldMap.TRAVEL_NEW_TARGET_LIMIT, WorldMap.TRAVEL_TOTAL_TARGET_LIMIT, _available_world_route_ids(run_state, map_data, source_id))


func _world_target_is_available(run_state: RunState, map_data: Dictionary, source_id: String, target_id: String) -> bool:
	if not _world_travel_target_ids(run_state, map_data, source_id).has(target_id):
		return false
	var map := WorldMap.new(library)
	var route := map.route_for_target(map_data, source_id, target_id)
	if route.is_empty():
		return false
	var status := run_state.travel_route_status(route)
	if not bool(status.get("available", false)) or bool(status.get("hidden", false)) or bool(status.get("locked", false)):
		return false
	var archetype := _archetype_by_id(target_id)
	var arrival_minute := (run_state.game_minute_of_day() + maxi(1, int(route.get("distance_blocks", 1))) * 6) % EnvironmentHours.MINUTES_PER_DAY
	return TutorialFlowScript.environment_open_at(run_state, archetype, arrival_minute)


func _enabled_world_route_ids(run_state: RunState, map_data: Dictionary, source_id: String) -> Array:
	return _world_route_ids(run_state, map_data, source_id, true)


func _available_world_route_ids(run_state: RunState, map_data: Dictionary, source_id: String) -> Array:
	return _world_route_ids(run_state, map_data, source_id, false)


func _world_route_ids(run_state: RunState, map_data: Dictionary, source_id: String, include_locked: bool) -> Array:
	var result: Array = []
	if run_state == null:
		return result
	var map := WorldMap.new(library)
	for target_id_value in WorldMap.visible_node_ids(map_data):
		var target_id := str(target_id_value)
		if target_id == source_id or not WorldMap.has_path(map_data, source_id, target_id, true):
			continue
		var route := map.route_for_target(map_data, source_id, target_id)
		if route.is_empty():
			continue
		var archetype := _archetype_by_id(target_id)
		var arrival_minute := (run_state.game_minute_of_day() + maxi(1, int(route.get("distance_blocks", 1))) * 6) % EnvironmentHours.MINUTES_PER_DAY
		if not TutorialFlowScript.environment_open_at(run_state, archetype, arrival_minute):
			continue
		var status := run_state.travel_route_status(route)
		if not bool(status.get("hidden", false)) and (bool(status.get("available", true)) or (include_locked and bool(status.get("locked", false)))):
			result.append(target_id)
	return result


# Picks the starting, routed, or tier fallback archetype.
func _pick_archetype(run_state: RunState, depth: int, rng: RngStream, target_archetype_id: String = "") -> Dictionary:
	if depth == 0:
		var selected_home := run_state.selected_home_archetype_id()
		if selected_home != RunState.HOME_SELECTION_RANDOM:
			var selected_archetype := _archetype_by_id(selected_home)
			if not selected_archetype.is_empty():
				return selected_archetype
		var starts := _start_archetypes()
		var shop_starts := _archetypes_with_shop_items(starts, true, run_state.challenge_config)
		if not shop_starts.is_empty():
			return rng.pick(shop_starts, {})
		var shop_tier_one := _archetypes_with_shop_items(library.archetypes_for(1), false, run_state.challenge_config)
		if not shop_tier_one.is_empty():
			return rng.pick(shop_tier_one, {})
		var playable_starts := _archetypes_with_games(starts, true, run_state.challenge_config)
		if not playable_starts.is_empty():
			return rng.pick(playable_starts, {})
		var playable_tier_one := _archetypes_with_games(library.archetypes_for(1), false, run_state.challenge_config)
		if not playable_tier_one.is_empty():
			return rng.pick(playable_tier_one, {})
		if not starts.is_empty():
			return rng.pick(starts, {})

	var next_ids: Array = run_state.current_environment.get("next_archetypes", [])
	if not target_archetype_id.is_empty() and next_ids.has(target_archetype_id):
		var target := _archetype_by_id(target_archetype_id)
		if not target.is_empty():
			return target

	var routed := _archetypes_by_id(next_ids)
	if not routed.is_empty():
		return _weighted_pick_archetype(routed, rng)

	var tier := clampi(depth + 1, 1, 4)
	return _weighted_pick_archetype(library.archetypes_for(tier), rng)


# Returns archetypes marked as valid run starts.
func _start_archetypes() -> Array:
	var starts: Array = []
	for archetype in library.environment_archetypes:
		if bool(archetype.get("is_start", false)):
			starts.append(archetype)
	return starts


# Returns shop archetypes that can offer items before the first wager.
func _archetypes_with_shop_items(archetypes: Array, include_rare: bool = true, challenge_config: Dictionary = {}) -> Array:
	var matches: Array = []
	for archetype in archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = archetype
		if str(data.get("kind", "")) != "shop":
			continue
		var filtered_item_pool := library.shop_item_pool_for_challenge(data.get("item_pool", []), challenge_config) if library != null else _string_array(data.get("item_pool", []))
		if filtered_item_pool.is_empty():
			continue
		if _count_ceiling(data.get("item_count", 0)) <= 0:
			continue
		if not include_rare and str(data.get("rarity", "")).to_lower() == "rare":
			continue
		matches.append(data)
	return matches


# Returns archetypes with at least one game option.
func _archetypes_with_games(archetypes: Array, include_rare: bool = true, challenge_config: Dictionary = {}) -> Array:
	var matches: Array = []
	for archetype in archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = archetype
		var filtered_game_pool := library.filter_game_ids_for_challenge(data.get("game_pool", []), challenge_config) if library != null else _string_array(data.get("game_pool", []))
		if filtered_game_pool.is_empty():
			continue
		if not include_rare and str(data.get("rarity", "")).to_lower() == "rare":
			continue
		matches.append(data)
	return matches


# Returns archetypes matching a list of ids.
func _archetypes_by_id(ids: Array) -> Array:
	var matches: Array = []
	for archetype in library.environment_archetypes:
		if ids.has(archetype.get("id", "")):
			matches.append(archetype)
	return matches


# Returns one archetype matching an id.
func _archetype_by_id(id: String) -> Dictionary:
	for archetype in library.environment_archetypes:
		if archetype.get("id", "") == id:
			return archetype
	return {}


func _prime_town_scenarios(run_state: RunState, map_data: Dictionary) -> void:
	if run_state == null or library == null:
		return
	var node_ids: Array = []
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_id := str((node_value as Dictionary).get("id", "")).strip_edges()
		if not node_id.is_empty():
			node_ids.append(node_id)
	node_ids.sort()
	for node_id_value in node_ids:
		var node_id := str(node_id_value)
		if not run_state.seeded_scenario_for_node(node_id).is_empty():
			continue
		var scenario_rng := run_state.create_rng("town_scenario_seed:%s" % node_id)
		var scenario := _select_scenario(run_state, node_id, scenario_rng)
		if not scenario.is_empty():
			run_state.seed_scenario_for_node(node_id, scenario)


func _select_scenario(run_state: RunState, archetype_id: String, rng: RngStream) -> Dictionary:
	if run_state == null or library == null or rng == null:
		return {}
	var pool := library.scenarios_for_archetype(archetype_id)
	if pool.is_empty():
		return {}
	var seeded_definition := run_state.seeded_scenario_definition_for_node(archetype_id)
	if not seeded_definition.is_empty():
		return seeded_definition
	var seeded := run_state.seeded_scenario_for_node(archetype_id)
	var seeded_id := str(seeded.get("id", "")).strip_edges()
	if not seeded_id.is_empty():
		for definition_value in pool:
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var definition: Dictionary = definition_value
			if str(definition.get("id", "")) == seeded_id:
				return definition.duplicate(true)
	var modifiers := _copy_dict(run_state.challenge_config.get("modifiers", {}))
	var pins := _copy_dict(modifiers.get("scenario_pins", {}))
	var pinned_id := str(pins.get(archetype_id, "")).strip_edges()
	if not pinned_id.is_empty():
		for definition_value in pool:
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var pinned: Dictionary = definition_value
			if str(pinned.get("id", "")) == pinned_id:
				run_state.remember_scenario_selection(archetype_id, pinned_id)
				var selected_pin := pinned.duplicate(true)
				# Challenge authors may pin the name of tonight without letting its
				# overlay disturb a controlled teaching or test environment.
				if not bool(modifiers.get("scenario_pins_apply_mutations", true)):
					selected_pin["mutations"] = {}
					selected_pin["phases"] = []
				return selected_pin
		return {}
	var excludes := _copy_dict(modifiers.get("scenario_excludes", {}))
	var excluded_ids := _string_array(excludes.get(archetype_id, []))
	var candidates: Array = []
	for definition_value in pool:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var scenario_id := str(definition.get("id", "")).strip_edges()
		if scenario_id.is_empty() or excluded_ids.has(scenario_id):
			continue
		candidates.append(definition)
	if candidates.is_empty():
		return {}
	var recent := run_state.recent_scenario_ids(archetype_id)
	var weighted: Array = []
	var total_weight := 0
	for definition_value in candidates:
		var definition: Dictionary = definition_value
		var scenario_id := str(definition.get("id", ""))
		var repeat_multiplier := 1.0
		var recent_index := recent.find(scenario_id)
		if recent_index == 0 and candidates.size() > 1:
			repeat_multiplier = 0.0
		elif recent_index == 1:
			repeat_multiplier = 0.35
		elif recent_index >= 2:
			repeat_multiplier = 0.60
		var town_multiplier := 1.0
		if run_state.has_method("scenario_weight_multiplier"):
			town_multiplier = maxf(0.0, float(run_state.call("scenario_weight_multiplier", archetype_id, scenario_id, _string_array(definition.get("town_weight_tags", [])))))
		var scaled_weight := maxi(0, int(round(float(definition.get("weight", 1.0)) * repeat_multiplier * town_multiplier * 1000.0)))
		if scaled_weight <= 0:
			continue
		total_weight += scaled_weight
		weighted.append({"definition": definition, "ceiling": total_weight})
	if weighted.is_empty() or total_weight <= 0:
		return {}
	var roll := rng.randi_range(1, total_weight)
	var selected: Dictionary = weighted[weighted.size() - 1].get("definition", {})
	for entry_value in weighted:
		var entry: Dictionary = entry_value
		if roll <= int(entry.get("ceiling", total_weight)):
			selected = entry.get("definition", {})
			break
	var selected_id := str(selected.get("id", ""))
	run_state.remember_scenario_selection(archetype_id, selected_id)
	return selected.duplicate(true)


# Picks one archetype while respecting optional low-weight rare venues.
func _weighted_pick_archetype(archetypes: Array, rng: RngStream) -> Dictionary:
	var weighted: Array = []
	for archetype_value in archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var weight := maxi(1, int(archetype.get("spawn_weight", 10)))
		if str(archetype.get("rarity", "")).to_lower() == "rare" and not archetype.has("spawn_weight"):
			weight = 1
		var remaining := weight
		while remaining > 0:
			weighted.append(archetype)
			remaining -= 1
	return rng.pick(weighted, {})


func _apply_home_profile(run_state: RunState, environment_data: Dictionary, archetype: Dictionary, node_id: String, rng: RngStream) -> void:
	var effective_archetype := library.environment_archetype_for_challenge(archetype, run_state.challenge_config) if library != null else archetype
	var profile := _copy_dict(environment_data.get("home_profile", effective_archetype.get("home_profile", {})))
	if profile.is_empty():
		return
	run_state.initialize_home_from_profile(effective_archetype, node_id, profile)
	var cash_range := _int_range(profile.get("starting_cash", [RunState.DEFAULT_BANKROLL, RunState.DEFAULT_BANKROLL]), RunState.DEFAULT_BANKROLL, RunState.DEFAULT_BANKROLL)
	var starting_cash := rng.randi_range(int(cash_range[0]), int(cash_range[1]))
	run_state.change_bankroll(starting_cash - run_state.bankroll)
	var starting_pool := _home_starting_item_pool(profile, run_state.challenge_config)
	var starting_item_offers := _home_starting_item_offers(profile, starting_pool, rng)
	var containers := _meta_collection_starting_containers(run_state.challenge_config)
	if containers.is_empty():
		containers = _home_starting_containers(profile, starting_pool, rng)
	environment_data["home_profile"] = profile.duplicate(true)
	environment_data["item_offers"] = starting_item_offers
	environment_data["home_containers"] = containers
	environment_data["home_container_index"] = containers.size()
	environment_data["home_lost"] = false


func _home_starting_item_offers(profile: Dictionary, starting_pool: Array, rng: RngStream) -> Array:
	var offers: Array = []
	var starting_items_count := maxi(0, int(profile.get("starting_items", 0)))
	for item_id_value in rng.pick_many(starting_pool, starting_items_count):
		var item_id := str(item_id_value).strip_edges()
		if item_id.is_empty():
			continue
		var definition: Dictionary = library.item(item_id) if library != null else {}
		offers.append({
			"id": item_id,
			"display_name": str(definition.get("display_name", item_id.replace("_", " ").capitalize())),
			"price": 0,
			"pickup": true,
			"source": "home_start",
		})
	return offers


func _home_starting_item_pool(profile: Dictionary, challenge_config: Dictionary) -> Array:
	var pool := _string_array(profile.get("starting_item_pool", []))
	if pool.is_empty():
		if library == null:
			return pool
		for item_value in library.items:
			if typeof(item_value) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_value
			var item_id := str(item.get("id", "")).strip_edges()
			if item_id.is_empty():
				continue
			var item_class := str(item.get("class", "")).strip_edges().to_lower()
			if item_class == "container":
				continue
			pool.append(item_id)
	if library != null:
		pool = library.filter_item_ids_for_challenge(pool, challenge_config)
	return pool


func _home_starting_containers(profile: Dictionary, starting_pool: Array, rng: RngStream) -> Array:
	var containers: Array = []
	var index := 0
	for container_value in _copy_array(profile.get("starting_containers", [])):
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = container_value
		var item_id := str(entry.get("item_id", entry.get("id", ""))).strip_edges()
		if item_id.is_empty():
			continue
		index += 1
		var definition: Dictionary = library.item(item_id) if library != null else {}
		var capacity := _container_capacity(item_id, int(entry.get("capacity", 0)))
		var stored_items: Array = []
		var random_count := maxi(0, int(entry.get("contains_random_items", 0)))
		for stored_item_value in rng.pick_many(starting_pool, random_count):
			var stored_item_id := str(stored_item_value).strip_edges()
			if not stored_item_id.is_empty():
				stored_items.append(stored_item_id)
		if capacity > 0 and stored_items.size() > capacity:
			stored_items = stored_items.slice(0, capacity)
		containers.append({
			"id": "%s_%02d" % [item_id, index],
			"item_id": item_id,
			"display_name": str(definition.get("display_name", item_id.replace("_", " ").capitalize())),
			"capacity": capacity,
			"items": stored_items,
		})
	return containers


func _meta_collection_starting_containers(challenge_config: Dictionary) -> Array:
	var modifiers := _copy_dict(challenge_config.get("modifiers", {}))
	if not bool(modifiers.get("meta_collection_enabled", false)):
		return []
	var containers: Array = []
	for container_value in _copy_array(modifiers.get("meta_collection_containers", [])):
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = _copy_dict(container_value)
		var item_id := str(container.get("item_id", "")).strip_edges()
		var capacity := _container_capacity(item_id, int(container.get("capacity", 0)))
		if item_id.is_empty() or capacity <= 0:
			continue
		var definition: Dictionary = library.item(item_id) if library != null else {}
		container["display_name"] = str(definition.get("display_name", item_id.replace("_", " ").capitalize()))
		container["capacity"] = capacity
		container["meta_loadout"] = true
		containers.append(container)
	return containers


func _container_capacity(item_id: String, fallback: int) -> int:
	var capacity := maxi(0, fallback)
	var definition: Dictionary = library.item(item_id) if library != null else {}
	if definition.is_empty():
		return capacity
	capacity = maxi(capacity, int(definition.get("container_capacity", 0)))
	var effect := _copy_dict(definition.get("effect", {}))
	return maxi(capacity, int(effect.get("container_capacity", 0)))


func _int_range(value: Variant, fallback_min: int, fallback_max: int) -> Array:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.size() >= 2:
			var first := int(values[0])
			var second := int(values[1])
			return [mini(first, second), maxi(first, second)]
	return [mini(fallback_min, fallback_max), maxi(fallback_min, fallback_max)]


# Lets GameModule instances attach generated per-environment state before entry.
func _generated_game_states(run_state: RunState, environment_data: Dictionary, rng: RngStream) -> Dictionary:
	var states := _copy_dict(environment_data.get("game_states", {}))
	for game_id in _string_array(environment_data.get("game_ids", [])):
		var definition := library.game(game_id)
		var game: GameModule = _create_game_module(definition)
		if game == null:
			continue
		var state_rng := rng.fork("environment_game_state:%s:%s" % [str(environment_data.get("id", "")), game_id])
		var generated_base := false
		if not states.has(game_id):
			var generated: Dictionary = game.generate_environment_state(run_state, environment_data, state_rng)
			if typeof(generated) == TYPE_DICTIONARY and not (generated as Dictionary).is_empty():
				states[game_id] = (generated as Dictionary).duplicate(true)
				game.environment_state_generated(run_state, environment_data, states[game_id] as Dictionary)
				generated_base = true
		var fixture_count := maxi(1, int(_copy_dict(_copy_dict(environment_data.get("layout", {})).get("game_fixture_counts", {})).get(game_id, 1)))
		if fixture_count <= 1 or not game.has_method("generate_environment_fixture_states"):
			continue
		var fixture_states_value: Variant = game.call("generate_environment_fixture_states", run_state, environment_data, state_rng.fork("fixtures"), fixture_count)
		if typeof(fixture_states_value) != TYPE_DICTIONARY:
			continue
		for fixture_key_value in (fixture_states_value as Dictionary).keys():
			var fixture_key := str(fixture_key_value)
			if fixture_key.is_empty():
				continue
			if states.has(fixture_key) and not (fixture_key == game_id and generated_base):
				continue
			var fixture_state_value: Variant = (fixture_states_value as Dictionary).get(fixture_key, {})
			if typeof(fixture_state_value) == TYPE_DICTIONARY and not (fixture_state_value as Dictionary).is_empty():
				states[fixture_key] = (fixture_state_value as Dictionary).duplicate(true)
	return states


func _create_game_module(definition: Dictionary) -> GameModule:
	var module_path := str(definition.get("module_path", ""))
	if module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		return null
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _count_ceiling(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		var max_count := 0
		for entry in values:
			max_count = maxi(max_count, int(entry))
		return max_count
	return int(value)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
