class_name RunGenerator
extends RefCounted

# Builds deterministic environments from library data.

var library: ContentLibrary


# Stores the content library used for generation.
func _init(p_library: ContentLibrary) -> void:
	library = p_library


# Builds and assigns the next environment for a run.
func next_environment(run_state: RunState, target_archetype_id: String = "") -> EnvironmentInstance:
	var rng := run_state.create_rng()
	if run_state.has_world_map() or run_state.current_environment.is_empty():
		return _next_world_environment(run_state, target_archetype_id, rng)
	var depth := run_state.environment_history.size()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _pick_archetype(run_state, depth, rng, target_archetype_id)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config)
	environment.game_states = _generated_game_states(run_state, environment.to_dict(), rng)
	var environment_data := environment.to_dict()
	environment.layout = EnvironmentInstance.ensure_generated_layout(environment_data)
	run_state.save_rng(rng)
	run_state.set_environment(environment.to_dict())
	return environment


# Builds the next environment from a cloned run so route previews do not mutate state.
func preview_environment(run_state: RunState, target_archetype_id: String = "") -> Dictionary:
	if run_state == null:
		return {}
	var preview_state := RunState.new()
	preview_state.from_dict(run_state.to_dict())
	var environment := next_environment(preview_state, target_archetype_id)
	return environment.to_dict()


func world_route_for_target(run_state: RunState, target_archetype_id: String) -> Dictionary:
	if run_state == null or not run_state.has_world_map():
		return library.route(target_archetype_id) if library != null else {}
	var map := WorldMap.new(library)
	return map.route_for_target(run_state.world_map, run_state.current_world_node_id(), target_archetype_id)


func world_map_snapshot(run_state: RunState, selected_id: String = "") -> Dictionary:
	if run_state == null:
		return {}
	return WorldMap.snapshot(run_state.world_map, selected_id)


func _next_world_environment(run_state: RunState, target_archetype_id: String, rng: RngStream) -> EnvironmentInstance:
	var map := WorldMap.new(library)
	if not run_state.has_world_map():
		run_state.set_world_map(map.build(run_state, rng.fork("world_map")))
	if run_state.has_world_map() and not run_state.current_environment.is_empty():
		run_state.store_current_world_node_environment()
	var map_data := run_state.world_map
	var target_id := target_archetype_id.strip_edges()
	if run_state.current_environment.is_empty() and target_id.is_empty():
		target_id = WorldMap.current_node_id(map_data)
	elif not target_id.is_empty() and not WorldMap.are_neighbors(map_data, run_state.current_world_node_id(), target_id):
		target_id = _fallback_world_neighbor(map_data, run_state.current_world_node_id())
	elif target_id.is_empty():
		target_id = _fallback_world_neighbor(map_data, run_state.current_world_node_id())
	if target_id.is_empty():
		return _legacy_next_environment(run_state, target_archetype_id, rng)
	var node := WorldMap.node_by_id(map_data, target_id)
	if node.is_empty():
		return _legacy_next_environment(run_state, target_archetype_id, rng)
	var environment_data := _world_environment_data_for_node(run_state, map_data, node, rng)
	run_state.set_environment(environment_data)
	run_state.enter_world_node(target_id, run_state.current_environment)
	run_state.save_rng(rng)
	return EnvironmentInstance.from_dict(run_state.current_environment)


func _legacy_next_environment(run_state: RunState, target_archetype_id: String, rng: RngStream) -> EnvironmentInstance:
	var depth := run_state.environment_history.size()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _pick_archetype(run_state, depth, rng, target_archetype_id)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config)
	environment.game_states = _generated_game_states(run_state, environment.to_dict(), rng)
	var environment_data := environment.to_dict()
	environment.layout = EnvironmentInstance.ensure_generated_layout(environment_data)
	run_state.save_rng(rng)
	run_state.set_environment(environment.to_dict())
	return environment


func _world_environment_data_for_node(run_state: RunState, map_data: Dictionary, node: Dictionary, rng: RngStream) -> Dictionary:
	var node_id := str(node.get("id", "")).strip_edges()
	var stored_environment: Dictionary = node.get("environment", {}) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {}
	if not stored_environment.is_empty() and str(node.get("state", "")) == WorldMap.STATE_VISITED:
		var restored := stored_environment.duplicate(true)
		_apply_world_travel_targets(restored, map_data, node_id)
		restored["world_node_id"] = node_id
		restored["layout"] = EnvironmentInstance.ensure_generated_layout(restored)
		return restored
	var depth := run_state.environment_history.size()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _archetype_by_id(node_id)
	if archetype.is_empty():
		archetype = _pick_archetype(run_state, depth, rng, node_id)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config)
	environment.game_states = _generated_game_states(run_state, environment.to_dict(), rng)
	var environment_data := environment.to_dict()
	environment_data["world_node_id"] = node_id
	_apply_world_travel_targets(environment_data, map_data, node_id)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	return environment_data


func _apply_world_travel_targets(environment_data: Dictionary, map_data: Dictionary, node_id: String) -> void:
	var targets := WorldMap.neighbor_ids(map_data, node_id, false)
	environment_data["next_archetypes"] = targets.duplicate(true)
	environment_data["travel_hooks"] = targets.duplicate(true)
	environment_data["world_map_travel"] = true


func _fallback_world_neighbor(map_data: Dictionary, source_id: String) -> String:
	var visible_neighbors := WorldMap.neighbor_ids(map_data, source_id, true)
	if not visible_neighbors.is_empty():
		return str(visible_neighbors[0])
	var all_neighbors := WorldMap.neighbor_ids(map_data, source_id, false)
	if not all_neighbors.is_empty():
		return str(all_neighbors[0])
	return ""


# Picks the starting, routed, or tier fallback archetype.
func _pick_archetype(run_state: RunState, depth: int, rng: RngStream, target_archetype_id: String = "") -> Dictionary:
	if depth == 0:
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


# Lets GameModule instances attach generated per-environment state before entry.
func _generated_game_states(run_state: RunState, environment_data: Dictionary, rng: RngStream) -> Dictionary:
	var states := _copy_dict(environment_data.get("game_states", {}))
	for game_id in _string_array(environment_data.get("game_ids", [])):
		if states.has(game_id):
			continue
		var definition := library.game(game_id)
		var game: GameModule = _create_game_module(definition)
		if game == null:
			continue
		var state_rng := rng.fork("environment_game_state:%s:%s" % [str(environment_data.get("id", "")), game_id])
		var generated: Dictionary = game.generate_environment_state(run_state, environment_data, state_rng)
		if typeof(generated) == TYPE_DICTIONARY and not (generated as Dictionary).is_empty():
			states[game_id] = (generated as Dictionary).duplicate(true)
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
