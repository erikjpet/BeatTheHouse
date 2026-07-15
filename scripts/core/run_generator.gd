class_name RunGenerator
extends RefCounted

# Builds deterministic environments from library data.

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


func _next_world_environment(run_state: RunState, target_archetype_id: String, rng: RngStream, target_prevalidated: bool = false) -> EnvironmentInstance:
	var map := WorldMap.new(library)
	if not run_state.has_world_map():
		run_state.set_world_map(map.build(run_state, rng.fork("world_map")))
	var map_data := run_state.world_map
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
		run_state.store_current_world_node_environment()
	var environment_data := _world_environment_data_for_node(run_state, map_data, node, rng)
	run_state.set_environment(environment_data)
	run_state.enter_world_node(target_id, run_state.current_environment)
	run_state.save_rng(rng)
	return EnvironmentInstance.from_dict(run_state.current_environment)


func _legacy_next_environment(run_state: RunState, target_archetype_id: String, rng: RngStream) -> EnvironmentInstance:
	var depth := run_state.environment_travel_count()
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
		_apply_world_travel_targets(restored, run_state, map_data, node_id)
		restored["world_node_id"] = node_id
		restored["layout"] = EnvironmentInstance.ensure_generated_layout(restored)
		return restored
	var depth := run_state.environment_travel_count()
	if not run_state.current_environment.is_empty():
		depth += 1
	var archetype := _archetype_by_id(node_id)
	if archetype.is_empty():
		archetype = _pick_archetype(run_state, depth, rng, node_id)
	var environment := EnvironmentInstance.from_archetype(archetype, depth, rng, library, run_state.challenge_config)
	environment.game_states = _generated_game_states(run_state, environment.to_dict(), rng)
	var environment_data := environment.to_dict()
	environment_data["world_node_id"] = node_id
	if str(archetype.get("kind", "")) == "home":
		_apply_home_profile(run_state, environment_data, archetype, node_id, rng.fork("home_profile:%s" % node_id))
	_apply_world_travel_targets(environment_data, run_state, map_data, node_id)
	environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
	return environment_data


func _apply_world_travel_targets(environment_data: Dictionary, run_state: RunState, map_data: Dictionary, node_id: String) -> void:
	var targets := _world_travel_target_ids(run_state, map_data, node_id)
	environment_data["next_archetypes"] = targets.duplicate(true)
	environment_data["travel_hooks"] = targets.duplicate(true)
	environment_data["world_map_travel"] = true


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
	return EnvironmentHours.environment_open_at(archetype, arrival_minute)


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
		if not EnvironmentHours.environment_open_at(archetype, arrival_minute):
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
	var profile := _copy_dict(archetype.get("home_profile", {}))
	if profile.is_empty():
		return
	run_state.initialize_home_from_profile(archetype, node_id, profile)
	var cash_range := _int_range(profile.get("starting_cash", [RunState.DEFAULT_BANKROLL, RunState.DEFAULT_BANKROLL]), RunState.DEFAULT_BANKROLL, RunState.DEFAULT_BANKROLL)
	var starting_cash := rng.randi_range(int(cash_range[0]), int(cash_range[1]))
	run_state.change_bankroll(starting_cash - run_state.bankroll)
	var starting_pool := _home_starting_item_pool(profile, run_state.challenge_config)
	var starting_item_offers := _home_starting_item_offers(profile, starting_pool, rng)
	var containers := _home_starting_containers(profile, starting_pool, rng)
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
