extends RefCounted


static func world_map_snapshot(host: Variant) -> Dictionary:
	if host.run_state == null:
		return {}
	if host._is_meta_session():
		var meta_cache_key = "meta|%s|%s|%s" % [
			host.meta_session_location_id,
			host.selected_world_map_node_id,
			host._meta_archetype_id_for_location(host.META_LOCATION_HOME),
		]
		if host.world_map_snapshot_cache_key == meta_cache_key:
			return host.world_map_snapshot_cache.duplicate(true)
		var meta_snapshot = host._meta_world_map_snapshot()
		host.world_map_snapshot_cache_key = meta_cache_key
		host.world_map_snapshot_cache = meta_snapshot.duplicate(true)
		return meta_snapshot
	var cache_key = "%s|map:%s" % [host._travel_base_cache_key(), host.selected_world_map_node_id]
	if host.world_map_snapshot_cache_key == cache_key:
		return host.world_map_snapshot_cache.duplicate(true)
	var snapshot = {}
	if host.generator != null:
		snapshot = host.generator.world_map_snapshot(host.run_state, host.selected_world_map_node_id)
	else:
		snapshot = host.WorldMapScript.snapshot(host.run_state.world_map, host.selected_world_map_node_id)
	var enriched = host._enriched_world_map_snapshot(snapshot)
	host.world_map_snapshot_cache_key = cache_key
	host.world_map_snapshot_cache = enriched.duplicate(true)
	return enriched


static func enriched_world_map_snapshot(host: Variant, snapshot: Dictionary) -> Dictionary:
	if host.run_state == null or not host.run_state.has_world_map():
		return snapshot
	var enriched = snapshot.duplicate(true)
	var current_id = host.run_state.current_world_node_id()
	var target_ids = host._travel_target_ids()
	var travel_enabled_ids: Array = []
	var travel_disabled_ids: Array = []
	var visible_target_ids: Array = []
	var travel_paths: Array = []
	var displayed_lookup: Dictionary = {}
	var visible_node_ids: Array = []
	var nodes: Array = []
	for node_value in host._copy_array(enriched.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = (node_value as Dictionary).duplicate(true)
		var node_id = str(node.get("id", "")).strip_edges()
		var is_current = node_id == current_id
		var is_target = target_ids.has(node_id)
		var route = host._world_route_for_target(node_id) if is_target and not is_current else {}
		var status = host.run_state.travel_route_status(route) if not route.is_empty() else {}
		var route_hidden = bool(status.get("hidden", false))
		var route_locked = bool(status.get("locked", false))
		var enabled = is_target and not is_current and not route.is_empty() and not route_hidden and bool(status.get("available", true))
		var visible_travel_target = is_target and not is_current and not route_hidden
		var open_status_text = ""
		var open_now = true
		var closing_soon = false
		if visible_travel_target:
			var node_archetype = host._environment_archetype(node_id)
			var arrival_minute = host._arrival_minute_for_route(route, false)
			var open_status = EnvironmentHours.status_at(node_archetype, arrival_minute)
			open_status_text = EnvironmentHours.travel_status_text(node_archetype, arrival_minute)
			open_now = bool(open_status.get("open", true))
			closing_soon = bool(open_status.get("closing_soon", false))
			if not open_now:
				enabled = false
		if not host._world_map_node_should_render(node, is_current, enabled):
			continue
		node["current"] = is_current
		node["travel_target"] = visible_travel_target
		node["travel_enabled"] = enabled
		node["travel_disabled_reason"] = ""
		if visible_travel_target:
			visible_target_ids.append(node_id)
			node["locked"] = route_locked
			if route_locked:
				node["travel_disabled_reason"] = str(status.get("disabled_reason", "That route is not available right now."))
				node["attribute_badges"] = []
				travel_disabled_ids.append(node_id)
				var locked_route_path = host._string_array(route.get("world_path", []))
				if locked_route_path.size() >= 2:
					travel_paths.append({
						"target_id": node_id,
						"path": locked_route_path,
						"enabled": false,
					})
				nodes.append(node)
				displayed_lookup[node_id] = true
				visible_node_ids.append(node_id)
				continue
			node["travel_method"] = host._world_map_travel_method({"route": route, "distance": str(status.get("distance", route.get("distance", "near")))})
			node["distance"] = str(status.get("distance", route.get("distance", "")))
			node["distance_blocks"] = int(route.get("distance_blocks", 0))
			node["cost"] = int(status.get("cost", route.get("cost", 0)))
			node["risk"] = str(status.get("risk", route.get("risk", "")))
			node["risk_decay"] = int(status.get("risk_decay", route.get("risk_decay", 0)))
			node["risk_event"] = host._copy_dict(status.get("risk_event", {}))
			node["open_status_text"] = open_status_text
			node["open_now"] = open_now
			node["closing_soon"] = closing_soon
			node["attribute_badges"] = host.AttributeBadgesScript.for_route({
				"cost": int(node.get("cost", 0)),
				"risk": str(node.get("risk", "")),
				"distance": str(node.get("distance", "")),
				"risk_decay": int(node.get("risk_decay", 0)),
				"risk_event": host._copy_dict(node.get("risk_event", {})),
			}, host._copy_dict(node.get("risk_event", {})))
			if enabled:
				travel_enabled_ids.append(node_id)
			else:
				var disabled_reason = str(status.get("disabled_reason", "That route is not available right now."))
				if not open_now and not open_status_text.is_empty():
					disabled_reason = open_status_text
				node["travel_disabled_reason"] = disabled_reason
				travel_disabled_ids.append(node_id)
			var route_path = host._string_array(route.get("world_path", []))
			if route_path.size() >= 2:
				travel_paths.append({
					"target_id": node_id,
					"path": route_path,
					"enabled": enabled,
				})
		elif not is_current:
			node["travel_disabled_reason"] = "Not on the route list from here right now."
		nodes.append(node)
		displayed_lookup[node_id] = true
		visible_node_ids.append(node_id)
	var visible_edges: Array = []
	for edge_value in host._copy_array(enriched.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if displayed_lookup.has(str(edge.get("a", ""))) and displayed_lookup.has(str(edge.get("b", ""))):
			visible_edges.append(edge.duplicate(true))
	var visible_path: Array = []
	for path_node_id_value in host._string_array(enriched.get("visited_path", [])):
		var path_node_id = str(path_node_id_value)
		if displayed_lookup.has(path_node_id):
			visible_path.append(path_node_id)
	var focus_node_ids: Array = []
	if displayed_lookup.has(current_id):
		focus_node_ids.append(current_id)
	for target_id_value in visible_target_ids:
		var target_id = str(target_id_value)
		if displayed_lookup.has(target_id) and not focus_node_ids.has(target_id):
			focus_node_ids.append(target_id)
	for enabled_id_value in travel_enabled_ids:
		var enabled_id = str(enabled_id_value)
		if displayed_lookup.has(enabled_id) and not focus_node_ids.has(enabled_id):
			focus_node_ids.append(enabled_id)
	if not displayed_lookup.has(str(enriched.get("selected_node_id", ""))):
		enriched["selected_node_id"] = ""
	enriched["visible_node_ids"] = visible_node_ids
	enriched["nodes"] = nodes
	enriched["edges"] = visible_edges
	enriched["visited_path"] = visible_path
	enriched["travel_target_ids"] = target_ids
	enriched["travel_enabled_node_ids"] = travel_enabled_ids
	enriched["travel_disabled_node_ids"] = travel_disabled_ids
	enriched["travel_paths"] = travel_paths
	enriched["map_focus_node_ids"] = focus_node_ids
	if str(enriched.get("background_path", "")).strip_edges().is_empty():
		enriched["background_path"] = host.WorldMapScript.MAP_BACKGROUND_PATH
	return enriched


static func world_map_node_should_render(host: Variant, node: Dictionary, is_current: bool, is_available_target: bool) -> bool:
	if is_current or is_available_target:
		return true
	var state = str(node.get("state", host.WorldMapScript.STATE_HIDDEN)).strip_edges().to_lower()
	return state == host.WorldMapScript.STATE_VISITED


static func world_route_for_target(host: Variant, target_id: String) -> Dictionary:
	var cache_key = host._travel_base_cache_key()
	if host.world_route_cache_key != cache_key:
		host.world_route_cache_key = cache_key
		host.world_route_cache = {}
	if host.world_route_cache.has(target_id):
		var cached_route: Dictionary = host.world_route_cache.get(target_id, {})
		return cached_route.duplicate(true)
	var route = {}
	if host.run_state != null and host.generator != null and host.run_state.has_world_map():
		route = host.generator.world_route_for_target(host.run_state, target_id)
	else:
		route = host.library.route(target_id) if host.library != null else {}
	host.world_route_cache[target_id] = route.duplicate(true)
	return route


static func travel_choice_view_list(host: Variant) -> Array:
	if host.run_state == null:
		return []
	var cache_key = "%s|selected:%s" % [host._travel_base_cache_key(), host.selected_travel_target_id]
	if host.travel_choice_cache_key == cache_key:
		return host.travel_choice_cache.duplicate(true)
	var ids = host._travel_target_ids()
	var choices: Array = []
	for target_id in ids:
		var choice = host._travel_choice(target_id, ids)
		if choice.is_empty():
			continue
		choice["selected"] = target_id == host.selected_travel_target_id
		choices.append(choice)
	host.travel_choice_cache_key = cache_key
	host.travel_choice_cache = choices.duplicate(true)
	return choices


static func travel_choice(host: Variant, target_id: String, known_target_ids: Array = []) -> Dictionary:
	if host._is_meta_session():
		return host._meta_travel_choice(target_id)
	var target_ids = known_target_ids if not known_target_ids.is_empty() else host._travel_target_ids()
	if target_id.is_empty() or not target_ids.has(target_id):
		return {}
	var local_door_choice = host._local_parent_home_door_travel_choice(target_id)
	if not local_door_choice.is_empty():
		return local_door_choice
	var route = host._world_route_for_target(target_id)
	var archetype = host._environment_archetype(target_id)
	var forced_walk_target = host._closing_time_walk_fallback_target_id() if host._closing_time_blocks_environment_actions() else ""
	var forced_walk = not forced_walk_target.is_empty() and forced_walk_target == target_id
	if forced_walk:
		route = route.duplicate(true)
		route["cost"] = 0
		route["base_cost"] = 0
		route["travel_method"] = "Walk"
		route["method"] = "Walk"
	var label = str(route.get("label", archetype.get("display_name", "")))
	if label.is_empty():
		label = host._travel_label_from_archetype(archetype, target_id)
	var choice = {
		"id": target_id,
		"label": label,
		"kind": str(archetype.get("kind", "")),
		"tier": int(archetype.get("tier", 1)),
		"description": str(route.get("description", "")),
		"route": route.duplicate(true),
	}
	if route.has("cost"):
		choice["cost"] = int(route.get("cost", 0))
	if route.has("risk"):
		choice["risk"] = str(route.get("risk", ""))
	if route.has("suspicion_delta"):
		choice["suspicion_delta"] = int(route.get("suspicion_delta", 0))
	if route.has("distance"):
		choice["distance"] = str(route.get("distance", ""))
	if route.has("distance_blocks"):
		choice["distance_blocks"] = int(route.get("distance_blocks", 0))
	if route.has("world_edge_id"):
		choice["world_edge_id"] = str(route.get("world_edge_id", ""))
	if route.has("risk_decay"):
		choice["risk_decay"] = int(route.get("risk_decay", 0))
	if route.has("condition_text"):
		choice["condition_text"] = str(route.get("condition_text", ""))
	var status = host.run_state.travel_route_status(route)
	var arrival_minute = host._arrival_minute_for_route(route, forced_walk)
	var open_status = host._environment_open_status_at(archetype, arrival_minute)
	choice["open_status"] = open_status.duplicate(true)
	choice["open_status_text"] = EnvironmentHours.travel_status_text(archetype, arrival_minute)
	choice["open_now"] = bool(open_status.get("open", true))
	choice["closing_soon"] = bool(open_status.get("closing_soon", false))
	choice["arrival_minute"] = arrival_minute
	choice["travel_minutes"] = host._travel_clock_minutes_for_route(route, forced_walk)
	choice["force_walk_fallback"] = forced_walk
	if bool(status.get("hidden", false)):
		return {}
	if bool(status.get("locked", false)):
		var locked_reason = str(status.get("disabled_reason", route.get("condition_text", "This route is locked for now."))).strip_edges()
		if locked_reason.is_empty():
			locked_reason = "This route is locked for now."
		return {
			"id": target_id,
			"label": label,
			"condition_text": locked_reason,
			"unlock_summary": str(status.get("unlock_summary", locked_reason)),
			"enabled": false,
			"disabled_reason": locked_reason,
			"locked": true,
			"attribute_badges": [],
		}
	choice["distance"] = str(status.get("distance", choice.get("distance", "")))
	choice["risk_decay"] = int(status.get("risk_decay", choice.get("risk_decay", 0)))
	choice["risk_text"] = str(status.get("risk_text", ""))
	choice["risk_event"] = host._copy_dict(status.get("risk_event", {}))
	choice["unlock_conditions"] = host._copy_array(status.get("unlock_conditions", []))
	choice["unlock_summary"] = str(status.get("unlock_summary", ""))
	if status.has("availability_turn"):
		choice["availability_turn"] = int(status.get("availability_turn", 0))
	if status.has("travel_lock_remaining"):
		choice["travel_lock_remaining"] = int(status.get("travel_lock_remaining", 0))
	var full_preview = host._travel_full_preview_enabled_for(target_id)
	var preview_environment = {}
	if full_preview and host.generator != null:
		preview_environment = host.generator.preview_environment(host.run_state, target_id)
	var preview = host.run_state.travel_route_preview(route, archetype, preview_environment, full_preview)
	choice["preview"] = preview
	choice["preview_level"] = str(preview.get("level", "partial"))
	choice["preview_lines"] = host._copy_array(preview.get("lines", []))
	var enabled = bool(status.get("available", true))
	var disabled_reason = str(status.get("disabled_reason", ""))
	if not bool(open_status.get("open", true)):
		enabled = false
		disabled_reason = str(open_status.get("disabled_reason", "Closed."))
	if forced_walk:
		enabled = true
		disabled_reason = ""
		choice["cost"] = 0
		choice["travel_method"] = "Walk"
	if not enabled and disabled_reason.strip_edges().is_empty():
		disabled_reason = str(choice.get("condition_text", ""))
	if not enabled and disabled_reason.strip_edges().is_empty():
		disabled_reason = "This route is locked for now."
	choice["enabled"] = enabled
	choice["disabled_reason"] = disabled_reason
	choice["attribute_badges"] = host.AttributeBadgesScript.for_route(choice, host._copy_dict(choice.get("risk_event", {})))
	return choice


static func travel_target_ids(host: Variant) -> Array:
	if host.run_state == null:
		return []
	if host._is_meta_session():
		return host._meta_travel_target_ids()
	var cache_key = host._travel_base_cache_key()
	if host.travel_target_ids_cache_key == cache_key:
		return host.travel_target_ids_cache.duplicate()
	var result: Array = []
	if host.run_state.has_world_map():
		var source_id = host.run_state.current_world_node_id()
		result = host.WorldMapScript.travel_target_ids(host.run_state.world_map, source_id, host.WorldMapScript.TRAVEL_NEW_TARGET_LIMIT, host.WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT, host._enabled_world_route_ids(source_id))
	else:
		for source in [
			host.run_state.current_environment.get("next_archetypes", []),
			host.run_state.current_environment.get("travel_hooks", []),
		]:
			for target_id in host._string_array(source):
				if not result.has(target_id):
					result.append(target_id)
	host.travel_target_ids_cache_key = cache_key
	host.travel_target_ids_cache = result.duplicate()
	return result


static func travel_base_cache_key(host: Variant) -> String:
	if host.run_state == null:
		return "no-run"
	var map_current_id = host.run_state.current_world_node_id() if host.run_state.has_world_map() else ""
	var map_visited_count = 0
	var map_node_count = 0
	var closing_status = host.run_state.closing_time_status()
	if host.run_state.has_world_map():
		map_visited_count = host._copy_array(host.run_state.world_map.get("visited_path", [])).size()
		map_node_count = host._copy_array(host.run_state.world_map.get("nodes", [])).size()
	return "%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%d|%s|%d" % [
		host.current_screen,
		str(host.run_state.current_environment.get("id", "")),
		map_current_id,
		host.run_state.environment_travel_count(),
		map_visited_count,
		map_node_count,
		host.run_state.bankroll,
		host.run_state.suspicion_level(),
		host.run_state.current_travel_lock_remaining(),
		host.run_state.unlocked_travel.size(),
		host.run_state.narrative_flags.size(),
		host.run_state.inventory.size(),
		str(host.run_state.current_environment.get("travel_lock_remaining", "")),
		host.run_state.game_minute_of_day(),
		str(closing_status.get("phase", "")),
		int(closing_status.get("grace_actions_remaining", 0)),
	]


static func invalidate_travel_view_cache(host: Variant) -> void:
	host.travel_target_ids_cache_key = ""
	host.travel_target_ids_cache = []
	host.travel_choice_cache_key = ""
	host.travel_choice_cache = []
	host.world_route_cache_key = ""
	host.world_route_cache = {}
	host.world_map_snapshot_cache_key = ""
	host.world_map_snapshot_cache = {}
	host.world_map_canvas_snapshot_key = ""


static func enabled_world_route_ids(host: Variant, source_id: String) -> Array:
	var result: Array = []
	if host.run_state == null or not host.run_state.has_world_map():
		return result
	var clean_source_id = source_id.strip_edges()
	if clean_source_id.is_empty():
		clean_source_id = host.run_state.current_world_node_id()
	for target_id_value in host.WorldMapScript.visible_node_ids(host.run_state.world_map):
		var target_id = str(target_id_value)
		if target_id == clean_source_id or not host.WorldMapScript.has_path(host.run_state.world_map, clean_source_id, target_id, true):
			continue
		var route = host._world_route_for_target(target_id)
		if route.is_empty():
			continue
		var archetype = host._environment_archetype(target_id)
		if not EnvironmentHours.environment_open_at(archetype, host._arrival_minute_for_route(route, false)):
			continue
		var status = host.run_state.travel_route_status(route)
		if not bool(status.get("hidden", false)) and (bool(status.get("available", true)) or bool(status.get("locked", false))):
			result.append(target_id)
	return result


static func current_environment_archetype(host: Variant) -> Dictionary:
	if host.run_state == null:
		return {}
	var archetype_id = str(host.run_state.current_environment.get("archetype_id", host.run_state.current_environment.get("world_node_id", ""))).strip_edges()
	return host._environment_archetype(archetype_id)


static func environment_open_status(host: Variant, archetype: Dictionary) -> Dictionary:
	if host.run_state == null:
		return EnvironmentHours.status_at(archetype, 0)
	return EnvironmentHours.status_at(archetype, host.run_state.game_minute_of_day())


static func environment_open_status_at(host: Variant, archetype: Dictionary, minute_of_day: int) -> Dictionary:
	return EnvironmentHours.status_at(archetype, minute_of_day)


static func travel_clock_minutes_for_route(host: Variant, route: Dictionary, force_walk: bool = false) -> int:
	var blocks = maxi(1, int(route.get("distance_blocks", 1)))
	var method = str(route.get("travel_method", route.get("method", ""))).strip_edges().to_lower()
	var per_block = host.WALK_CLOCK_MINUTES_PER_BLOCK if force_walk or method == "walk" else host.TRAVEL_CLOCK_MINUTES_PER_BLOCK
	return maxi(1, blocks * per_block)


static func arrival_minute_for_route(host: Variant, route: Dictionary, force_walk: bool = false) -> int:
	if host.run_state == null:
		return 0
	return (host.run_state.game_minute_of_day() + host._travel_clock_minutes_for_route(route, force_walk)) % EnvironmentHours.MINUTES_PER_DAY


static func environment_archetype(host: Variant, archetype_id: String) -> Dictionary:
	if host.library == null:
		return {}
	for archetype in host.library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


static func travel_label_from_archetype(host: Variant, archetype: Dictionary, fallback_id: String) -> String:
	var nouns: Array = archetype.get("name_nouns", [])
	if not nouns.is_empty():
		return str(nouns[0])
	return fallback_id.replace("_", " ").capitalize()


static func travel_full_preview_enabled(host: Variant) -> bool:
	if host.run_state == null:
		return false
	return host.run_state.travel_scouting_level() > 0


static func travel_full_preview_enabled_for(host: Variant, target_id: String) -> bool:
	if host._travel_full_preview_enabled():
		return true
	if host.run_state == null or not host.run_state.has_world_map():
		return false
	var node: Dictionary = host.WorldMapScript.node_by_id(host.run_state.world_map, target_id)
	return bool(node.get("scouted", false))


static func travel_preview_summary(host: Variant, choice: Dictionary) -> String:
	var preview_lines = host._copy_array(choice.get("preview_lines", []))
	if preview_lines.is_empty():
		return ""
	var level = str(choice.get("preview_level", "partial"))
	var prefix = "Scout" if level == "full" else "Preview"
	var first_line = str(preview_lines[0]).strip_edges()
	if first_line.begins_with("Preview:"):
		first_line = first_line.substr("Preview:".length()).strip_edges()
	return "%s: %s" % [prefix, first_line]


static func travel_risk_summary(host: Variant, choice: Dictionary) -> String:
	var parts: Array = []
	var risk = str(choice.get("risk", ""))
	if not risk.is_empty():
		parts.append(risk)
	var distance = str(choice.get("distance", ""))
	if not distance.is_empty():
		parts.append("%s distance" % distance)
	var risk_decay = int(choice.get("risk_decay", 0))
	if risk_decay >= 70:
		parts.append("heat cools sharply")
	elif risk_decay > 0:
		parts.append("heat cools")
	var suspicion_delta = int(choice.get("suspicion_delta", 0))
	if suspicion_delta > 0:
		parts.append("heat +%d" % suspicion_delta)
	var risk_text = str(choice.get("risk_text", "")).strip_edges()
	if not risk_text.is_empty():
		parts.append(risk_text)
	var risk_event = host._copy_dict(choice.get("risk_event", {}))
	if not risk_event.is_empty():
		var chance = int(risk_event.get("chance_percent", 0))
		var event_bits: Array = []
		var bankroll_delta = int(risk_event.get("bankroll_delta", 0))
		var event_heat = int(risk_event.get("suspicion_delta", 0))
		if bankroll_delta != 0:
			event_bits.append("%+d cash" % bankroll_delta)
		if event_heat > 0:
			event_bits.append("heat +%d" % event_heat)
		var consequence = ", ".join(event_bits)
		if consequence.is_empty():
			consequence = str(risk_event.get("label", "route event"))
		parts.append("%d%% %s" % [chance, consequence])
	return ", ".join(parts)


static func closing_time_walk_fallback_target_id(host: Variant) -> String:
	if host.run_state == null or not host.run_state.has_world_map() or not host._closing_time_blocks_environment_actions():
		return ""
	var current_id = host.run_state.current_world_node_id()
	var best_id = ""
	var best_score = 999999
	for target_id_value in host.WorldMapScript.visible_node_ids(host.run_state.world_map):
		var target_id = str(target_id_value).strip_edges()
		if target_id.is_empty() or target_id == current_id:
			continue
		var node: Dictionary = host.WorldMapScript.node_by_id(host.run_state.world_map, target_id)
		if str(node.get("state", host.WorldMapScript.STATE_HIDDEN)) != host.WorldMapScript.STATE_VISITED:
			continue
		var archetype = host._environment_archetype(target_id)
		var open_status = host._environment_open_status(archetype)
		var kind = str(archetype.get("kind", node.get("kind", ""))).strip_edges()
		if kind != "home" and not bool(open_status.get("always_open", false)):
			continue
		var route = host._world_route_for_target(target_id)
		if route.is_empty():
			continue
		var score = maxi(1, int(route.get("distance_blocks", 1)))
		if kind == "home":
			score -= 1000
		if best_id.is_empty() or score < best_score or (score == best_score and target_id < best_id):
			best_id = target_id
			best_score = score
	return best_id
