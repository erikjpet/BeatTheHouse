class_name WorldMap
extends RefCounted

# Persistent deterministic travel graph for Act 1 runs.

const VERSION := 1
const GRAND_CASINO_ID := "grand_casino"
const UNDERGROUND_SHORTCUT_ID := "small_underground_casino"
const BEACH_ID := "beach"
const BEACH_GATEWAY_ID := "delta_queen"
const STATE_HIDDEN := "hidden"
const STATE_REVEALED := "revealed"
const STATE_VISITED := "visited"
const DISCOVERY_SOURCE_NONE := ""
const DISCOVERY_SOURCE_SPAWN := "spawn"
const DISCOVERY_SOURCE_EVENT := "event"
const DISCOVERY_SOURCE_TRAVEL := "travel"
const DISTANCE_NEAR := "near"
const DISTANCE_LOCAL := "local"
const DISTANCE_FAR := "far"
const DISTANCE_REMOTE := "remote"
const MAP_BACKGROUND_PATH := "res://assets/art/map_backgrounds/cyberpunk_city_overhead.png"
const TRAVEL_NEW_TARGET_LIMIT := 2
const TRAVEL_TOTAL_TARGET_LIMIT := 3
const BAND_COST_SCALE := {
	DISTANCE_NEAR: 1.0,
	DISTANCE_LOCAL: 1.35,
	DISTANCE_FAR: 1.75,
	DISTANCE_REMOTE: 2.25,
}

var library: ContentLibrary


func _init(p_library: ContentLibrary = null) -> void:
	library = p_library


func build(run_state: RunState, rng: RngStream) -> Dictionary:
	if library == null or run_state == null or rng == null:
		return {}
	var archetypes_by_id := _archetypes_by_id()
	if archetypes_by_id.is_empty():
		return {}
	var start_id := _pick_start_id(archetypes_by_id, run_state, rng)
	var ids: Array = []
	for id_value in _sorted_keys(archetypes_by_id):
		var archetype_id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(archetype_id, {})
		if str(archetype.get("kind", "")) == "home" and archetype_id != start_id:
			continue
		ids.append(archetype_id)
	if ids.size() < 2:
		return {}
	var nodes: Array = []
	var positions := _layout_positions(ids, archetypes_by_id, start_id, rng.fork("world_map_layout"))
	var edges := _build_edges(ids, archetypes_by_id, positions, start_id)
	var discovered_at_spawn_ids := _initial_discovered_ids(ids, start_id, edges, archetypes_by_id, rng.fork("world_map_discovery"))
	for id_value in ids:
		var archetype_id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(archetype_id, {})
		var position: Dictionary = positions.get(archetype_id, {"x": 0.5, "y": 0.5})
		var discovered_at_spawn := discovered_at_spawn_ids.has(archetype_id)
		nodes.append({
			"id": archetype_id,
			"archetype_id": archetype_id,
			"label": _node_label(archetype),
			"kind": str(archetype.get("kind", "")),
			"tier": int(archetype.get("tier", 1)),
			"game_capacity": _archetype_game_capacity(archetype),
			"position": position.duplicate(true),
			"state": STATE_REVEALED if discovered_at_spawn else STATE_HIDDEN,
			"discovered_at_spawn": discovered_at_spawn,
			"discovery_source": DISCOVERY_SOURCE_SPAWN if discovered_at_spawn else DISCOVERY_SOURCE_NONE,
			"route_spawn_open": _route_is_spawn_open(archetype_id),
			"icon_path": _map_icon_path(archetype_id),
			"flavor": _archetype_flavor(archetype),
			"scouted": false,
			"environment": {},
		})
	var map_data := normalize({
		"version": VERSION,
		"seed_text": run_state.seed_text,
		"start_node_id": start_id,
		"current_node_id": start_id,
		"nodes": nodes,
		"edges": edges,
		"visited_path": [],
	})
	map_data = enter_node(map_data, start_id, {})
	return map_data


func route_for_target(map_data: Dictionary, current_id: String, target_id: String) -> Dictionary:
	var normalized := normalize(map_data)
	var source_id := current_id.strip_edges()
	var destination_id := target_id.strip_edges()
	if source_id.is_empty() or destination_id.is_empty() or source_id == destination_id:
		return {}
	if not _travel_target_allowed_from_source(source_id, destination_id):
		return {}
	var source_node := node_by_id(normalized, source_id)
	var destination_node := node_by_id(normalized, destination_id)
	var direct_revisit_path := false
	var path := _path_between_normalized(normalized, source_id, destination_id, true)
	if path.size() < 2:
		if source_node.is_empty() or destination_node.is_empty() or str(destination_node.get("state", STATE_HIDDEN)) != STATE_VISITED:
			return {}
		path = [source_id, destination_id]
		direct_revisit_path = true
	var route := library.route(destination_id).duplicate(true) if library != null else {}
	var edge_lookup := _edge_lookup(normalized)
	var distance_blocks := _path_distance_blocks_prepared(edge_lookup, path)
	if direct_revisit_path:
		var source_position: Dictionary = source_node.get("position", {"x": 0.5, "y": 0.5}) if typeof(source_node.get("position", {})) == TYPE_DICTIONARY else {"x": 0.5, "y": 0.5}
		var destination_position: Dictionary = destination_node.get("position", {"x": 0.5, "y": 0.5}) if typeof(destination_node.get("position", {})) == TYPE_DICTIONARY else {"x": 0.5, "y": 0.5}
		var direct_distance := Vector2(float(source_position.get("x", 0.5)), float(source_position.get("y", 0.5))).distance_to(Vector2(float(destination_position.get("x", 0.5)), float(destination_position.get("y", 0.5))))
		distance_blocks = maxi(1, ceili(direct_distance * 15.0))
	var band := _distance_band(distance_blocks)
	var base_cost := _path_base_cost_prepared(edge_lookup, path)
	var generated_cost := _path_cost_prepared(edge_lookup, path)
	var risk_decay := _path_risk_decay_prepared(edge_lookup, path, band)
	var edge_id := _route_edge_id_prepared(edge_lookup, path)
	if direct_revisit_path:
		edge_id = "revisit:%s:%s" % [source_id, destination_id]
	if route.is_empty():
		route = {
			"id": destination_id,
			"destination_archetype": destination_id,
			"distance": band,
			"risk_decay": risk_decay,
		}
	if base_cost <= 0:
		base_cost = _base_cost_for_band(band)
	if generated_cost <= 0:
		generated_cost = maxi(0, ceili(float(base_cost) * float(BAND_COST_SCALE.get(band, 1.0))))
	var destination_cost := maxi(0, int(route.get("cost", 0)))
	if destination_cost > 0:
		base_cost = maxi(base_cost, destination_cost)
		generated_cost = maxi(generated_cost, destination_cost)
	route["id"] = destination_id
	route["destination_archetype"] = destination_id
	route["from_archetype"] = source_id
	route["target_node_id"] = destination_id
	route["world_edge_id"] = edge_id
	route["world_path"] = path.duplicate(true)
	route["distance"] = band
	route["distance_blocks"] = distance_blocks
	route["base_cost"] = base_cost
	route["cost"] = generated_cost
	route["risk_decay"] = risk_decay
	route["path_stop_count"] = path.size()
	route["travel_method"] = _travel_method_for_band(band)
	if str(route.get("method", "")).strip_edges().is_empty():
		route["method"] = str(route.get("travel_method", ""))
	route["generated_world_route"] = true
	return route


func preview_for_target(map_data: Dictionary, target_id: String) -> Dictionary:
	var node := node_by_id(map_data, target_id)
	if node.is_empty():
		return {}
	var environment: Dictionary = node.get("environment", {}) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {}
	return environment.duplicate(true)


static func normalize(map_data: Dictionary) -> Dictionary:
	if map_data.is_empty():
		return {}
	var normalized := map_data.duplicate(true)
	normalized["version"] = maxi(1, int(normalized.get("version", VERSION)))
	normalized["seed_text"] = str(normalized.get("seed_text", ""))
	normalized["start_node_id"] = str(normalized.get("start_node_id", ""))
	normalized["current_node_id"] = str(normalized.get("current_node_id", normalized.get("start_node_id", "")))
	normalized["nodes"] = _normalize_nodes(_copy_array(normalized.get("nodes", [])))
	normalized["edges"] = _normalize_edges(_copy_array(normalized.get("edges", [])))
	normalized["visited_path"] = _string_array(normalized.get("visited_path", []))
	return normalized


static func current_node_id(map_data: Dictionary) -> String:
	return str(map_data.get("current_node_id", map_data.get("start_node_id", ""))).strip_edges()


static func node_by_id(map_data: Dictionary, node_id: String) -> Dictionary:
	var wanted_id := node_id.strip_edges()
	if wanted_id.is_empty():
		return {}
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return {}
	for node_value in nodes_value:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if str(node.get("id", "")) == wanted_id:
			return node.duplicate(true)
	return {}


static func node_state(map_data: Dictionary, node_id: String) -> String:
	var node := node_by_id(map_data, node_id)
	return str(node.get("state", STATE_HIDDEN))


static func visible_node_ids(map_data: Dictionary) -> Array:
	var result: Array = []
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return result
	for node_value in nodes_value:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty() and _node_is_visible(node):
			result.append(node_id)
	return result


static func is_node_visible(map_data: Dictionary, node_id: String) -> bool:
	var node := node_by_id(map_data, node_id)
	if node.is_empty():
		return false
	return _node_is_visible(node)


static func neighbor_ids(map_data: Dictionary, node_id: String, visible_only: bool = false) -> Array:
	var visible_lookup := _visible_node_lookup(map_data) if visible_only else {}
	return _neighbor_ids_with_visible_lookup(map_data, node_id, visible_only, visible_lookup)


static func _neighbor_ids_with_visible_lookup(map_data: Dictionary, node_id: String, visible_only: bool, visible_lookup: Dictionary) -> Array:
	var result: Array = []
	var source_id := node_id.strip_edges()
	if source_id.is_empty():
		return result
	var edges_value: Variant = map_data.get("edges", [])
	if typeof(edges_value) != TYPE_ARRAY:
		return result
	for edge_value in edges_value:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		var other := ""
		if a == source_id:
			other = b
		elif b == source_id:
			other = a
		if other.is_empty() or result.has(other):
			continue
		if visible_only and not visible_lookup.has(other):
			continue
		result.append(other)
	return result


static func _visible_node_lookup(map_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for visible_id_value in visible_node_ids(map_data):
		var visible_id := str(visible_id_value)
		if not visible_id.is_empty():
			result[visible_id] = true
	return result


static func _visible_ids_and_lookup(map_data: Dictionary) -> Dictionary:
	var ids: Array = []
	var lookup: Dictionary = {}
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return {"ids": ids, "lookup": lookup}
	for node_value in nodes_value:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or not _node_is_visible(node):
			continue
		ids.append(node_id)
		lookup[node_id] = true
	return {"ids": ids, "lookup": lookup}


static func _node_lookup(map_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return result
	for node_value in nodes_value:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty():
			result[node_id] = node
	return result


static func _edge_lookup(map_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var edges_value: Variant = map_data.get("edges", [])
	if typeof(edges_value) != TYPE_ARRAY:
		return result
	for edge_value in edges_value:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var edge_id := str(edge.get("id", ""))
		if not edge_id.is_empty():
			result[edge_id] = edge
	return result


static func are_neighbors(map_data: Dictionary, a: String, b: String) -> bool:
	return not edge_between(map_data, a, b).is_empty()


static func has_path(map_data: Dictionary, a: String, b: String, visible_only: bool = true) -> bool:
	return path_between(map_data, a, b, visible_only).size() >= 2


static func path_between(map_data: Dictionary, a: String, b: String, visible_only: bool = true) -> Array:
	var normalized := normalize(map_data)
	return _path_between_normalized(normalized, a, b, visible_only)


static func _path_between_normalized(normalized: Dictionary, a: String, b: String, visible_only: bool = true) -> Array:
	var visible_lookup: Dictionary = _visible_node_lookup(normalized) if visible_only else {}
	return _path_between_prepared(normalized, a, b, visible_only, visible_lookup)


static func _path_between_prepared(map_data: Dictionary, a: String, b: String, visible_only: bool, visible_lookup: Dictionary) -> Array:
	var source_id := a.strip_edges()
	var target_id := b.strip_edges()
	var result: Array = []
	if source_id.is_empty() or target_id.is_empty():
		return result
	if source_id == target_id:
		result.append(source_id)
		return result
	if visible_only:
		if not visible_lookup.has(source_id) or not visible_lookup.has(target_id):
			return result
	var queue: Array = [source_id]
	var previous_by_id: Dictionary = {}
	previous_by_id[source_id] = ""
	var head := 0
	while head < queue.size():
		var current_id := str(queue[head])
		head += 1
		for neighbor_value in _neighbor_ids_with_visible_lookup(map_data, current_id, visible_only, visible_lookup):
			var neighbor_id := str(neighbor_value)
			if previous_by_id.has(neighbor_id):
				continue
			previous_by_id[neighbor_id] = current_id
			if neighbor_id == target_id:
				return _reconstruct_path(previous_by_id, source_id, target_id)
			queue.append(neighbor_id)
	return result


static func edge_between(map_data: Dictionary, a: String, b: String) -> Dictionary:
	var edge_id := _edge_id(a, b)
	if edge_id.is_empty():
		return {}
	var edges_value: Variant = map_data.get("edges", [])
	if typeof(edges_value) != TYPE_ARRAY:
		return {}
	for edge_value in edges_value:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if str(edge.get("id", "")) == edge_id:
			return edge.duplicate(true)
	return {}


static func travel_target_ids(map_data: Dictionary, node_id: String = "", max_new: int = TRAVEL_NEW_TARGET_LIMIT, max_total: int = TRAVEL_TOTAL_TARGET_LIMIT, enabled_target_ids: Array = []) -> Array:
	var normalized := normalize(map_data)
	var source_id := node_id.strip_edges()
	if source_id.is_empty():
		source_id = current_node_id(normalized)
	var result: Array = []
	var visible_data := _visible_ids_and_lookup(normalized)
	var visible_ids: Array = visible_data.get("ids", [])
	var visible_lookup: Dictionary = visible_data.get("lookup", {})
	if source_id.is_empty() or not visible_lookup.has(source_id):
		return result
	var total_limit := maxi(0, max_total)
	var new_limit := mini(maxi(0, max_new), total_limit)
	var enabled_lookup := _enabled_target_lookup(enabled_target_ids)
	var node_lookup := _node_lookup(normalized)
	var edge_lookup := _edge_lookup(normalized)
	var visited_path := _string_array(normalized.get("visited_path", []))
	var new_candidates := _travel_candidate_entries_prepared(normalized, source_id, false, enabled_lookup, visible_ids, visible_lookup, node_lookup, edge_lookup, visited_path)
	var old_candidates := _travel_candidate_entries_prepared(normalized, source_id, true, enabled_lookup, visible_ids, visible_lookup, node_lookup, edge_lookup, visited_path)
	var enabled_new_candidates := _filter_candidates_by_enabled(new_candidates, true)
	var fallback_new_candidates := _filter_candidates_by_enabled(new_candidates, false)
	var enabled_old_candidates := _filter_candidates_by_enabled(old_candidates, true)
	var fallback_old_candidates := _filter_candidates_by_enabled(old_candidates, false)
	for candidate_value in enabled_new_candidates:
		if result.size() >= new_limit:
			break
		var candidate: Dictionary = candidate_value
		var target_id := str(candidate.get("id", ""))
		if not target_id.is_empty() and not result.has(target_id):
			result.append(target_id)
	for candidate_value in enabled_old_candidates:
		if result.size() >= total_limit:
			break
		var candidate: Dictionary = candidate_value
		var target_id := str(candidate.get("id", ""))
		if target_id.is_empty() or result.has(target_id):
			continue
		result.append(target_id)
	for candidate_value in fallback_new_candidates:
		if result.size() >= total_limit or result.size() >= maxi(1, new_limit):
			break
		var candidate: Dictionary = candidate_value
		var target_id := str(candidate.get("id", ""))
		if not target_id.is_empty() and not result.has(target_id):
			result.append(target_id)
	for candidate_value in fallback_old_candidates:
		if result.size() >= total_limit:
			break
		var candidate: Dictionary = candidate_value
		var target_id := str(candidate.get("id", ""))
		if not target_id.is_empty() and not result.has(target_id):
			result.append(target_id)
	var priority_candidates := enabled_new_candidates + enabled_old_candidates
	if source_id == BEACH_GATEWAY_ID:
		result = _ensure_visible_neighbor_target(result, source_id, BEACH_ID, total_limit, visible_lookup, edge_lookup, node_lookup)
	elif source_id == BEACH_ID:
		result = _ensure_visible_neighbor_target(result, source_id, BEACH_GATEWAY_ID, total_limit, visible_lookup, edge_lookup, node_lookup)
	result = _ensure_priority_target(result, priority_candidates, GRAND_CASINO_ID, total_limit)
	return result


static func store_environment(map_data: Dictionary, node_id: String, environment_data: Dictionary) -> Dictionary:
	var target_id := node_id.strip_edges()
	if target_id.is_empty() or environment_data.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		if str(node.get("id", "")) != target_id:
			continue
		node["environment"] = environment_data.duplicate(true)
		nodes[index] = node
		break
	normalized["nodes"] = nodes
	return normalized


static func enter_node(map_data: Dictionary, node_id: String, environment_data: Dictionary = {}) -> Dictionary:
	var target_id := node_id.strip_edges()
	if target_id.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	normalized["current_node_id"] = target_id
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		if str(node.get("id", "")) == target_id:
			node["state"] = STATE_VISITED
			if not environment_data.is_empty():
				node["environment"] = environment_data.duplicate(true)
			nodes[index] = node
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var candidate_node_id := str(node.get("id", ""))
		if candidate_node_id.is_empty() or str(node.get("state", STATE_HIDDEN)) != STATE_HIDDEN:
			continue
		if not are_neighbors(normalized, target_id, candidate_node_id):
			continue
		node["state"] = STATE_REVEALED
		node["discovery_source"] = DISCOVERY_SOURCE_TRAVEL
		node["discovered_by_travel"] = true
		nodes[index] = node
	normalized["nodes"] = nodes
	var path: Array = _string_array(normalized.get("visited_path", []))
	if path.is_empty() or str(path[path.size() - 1]) != target_id:
		path.append(target_id)
	normalized["visited_path"] = path
	return normalized


static func mark_scouted(map_data: Dictionary, node_id: String) -> Dictionary:
	var target_id := node_id.strip_edges()
	if target_id.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		if str(node.get("id", "")) == target_id:
			node["scouted"] = true
			nodes[index] = node
			break
	normalized["nodes"] = nodes
	return normalized


static func unlock_nodes(map_data: Dictionary, node_ids: Array, source: String = DISCOVERY_SOURCE_EVENT) -> Dictionary:
	if node_ids.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	var unlock_ids := _string_array(node_ids)
	var clean_source := source.strip_edges().to_lower()
	if clean_source.is_empty():
		clean_source = DISCOVERY_SOURCE_EVENT
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var node_id := str(node.get("id", ""))
		if not unlock_ids.has(node_id):
			continue
		if str(node.get("state", STATE_HIDDEN)) != STATE_VISITED:
			node["state"] = STATE_REVEALED
		if clean_source == DISCOVERY_SOURCE_SPAWN:
			node["discovered_at_spawn"] = true
		else:
			node["unlocked"] = true
		node["discovery_source"] = clean_source
		nodes[index] = node
	normalized["nodes"] = nodes
	return normalized


static func refresh_shop_node_environments(map_data: Dictionary, node_ids: Array) -> Dictionary:
	if node_ids.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	var refresh_ids := _string_array(node_ids)
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var node_id := str(node.get("id", ""))
		if not refresh_ids.has(node_id):
			continue
		if str(node.get("kind", "")).strip_edges().to_lower() != "shop":
			continue
		node["environment"] = {}
		nodes[index] = node
	normalized["nodes"] = nodes
	return normalized


static func mark_home_lost(map_data: Dictionary, node_id: String) -> Dictionary:
	var target_id := node_id.strip_edges()
	if target_id.is_empty():
		return normalize(map_data)
	var normalized := normalize(map_data)
	var nodes: Array = normalized.get("nodes", [])
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		if str(node.get("id", "")) != target_id:
			continue
		node["home_lost"] = true
		node["environment"] = {}
		node["flavor"] = "Home access is gone; anything stored there was lost."
		nodes[index] = node
		break
	normalized["nodes"] = nodes
	return normalized


static func snapshot(map_data: Dictionary, selected_id: String = "") -> Dictionary:
	var normalized := normalize(map_data)
	var visible_ids: Array = []
	var visible_lookup: Dictionary = {}
	var visible_nodes: Array = []
	var nodes: Array = normalized.get("nodes", [])
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or not _node_is_visible(node):
			continue
		visible_ids.append(node_id)
		visible_lookup[node_id] = true
		visible_nodes.append(_snapshot_node(node))
	var visible_edges: Array = []
	var edges: Array = normalized.get("edges", [])
	for edge_value in edges:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if visible_lookup.has(str(edge.get("a", ""))) and visible_lookup.has(str(edge.get("b", ""))):
			visible_edges.append(edge.duplicate(true))
	var clean_selected_id := selected_id.strip_edges()
	if not visible_lookup.has(clean_selected_id):
		clean_selected_id = ""
	return {
		"version": VERSION,
		"current_node_id": current_node_id(normalized),
		"selected_node_id": clean_selected_id,
		"visible_node_ids": visible_ids,
		"nodes": visible_nodes,
		"edges": visible_edges,
		"visited_path": _string_array(normalized.get("visited_path", [])),
		"background_path": MAP_BACKGROUND_PATH,
	}


func _archetypes_by_id() -> Dictionary:
	var result: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var id := str(archetype.get("id", "")).strip_edges()
		if id.is_empty() or bool(archetype.get("disabled", false)):
			continue
		result[id] = archetype.duplicate(true)
	return result


func _pick_start_id(archetypes_by_id: Dictionary, run_state: RunState, rng: RngStream) -> String:
	var selected_home := run_state.selected_home_archetype_id() if run_state != null else RunState.HOME_SELECTION_RANDOM
	if selected_home != RunState.HOME_SELECTION_RANDOM and archetypes_by_id.has(selected_home):
		return selected_home
	var home_ids: Array = []
	for id_value in _sorted_keys(archetypes_by_id):
		var id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		if str(archetype.get("kind", "")) == "home" or bool(archetype.get("is_home_start", false)):
			home_ids.append(id)
	if not home_ids.is_empty():
		return str(rng.pick(home_ids, str(home_ids[0])))
	var shop_starts: Array = []
	var starts: Array = []
	var tier_one: Array = []
	for id_value in _sorted_keys(archetypes_by_id):
		var id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		if bool(archetype.get("is_start", false)):
			starts.append(id)
			if str(archetype.get("kind", "")) == "shop":
				shop_starts.append(id)
		if int(archetype.get("tier", 1)) <= 1:
			tier_one.append(id)
	var candidates := shop_starts
	if candidates.is_empty():
		candidates = starts
	if candidates.is_empty():
		candidates = tier_one
	if candidates.is_empty():
		candidates = _sorted_keys(archetypes_by_id)
	return str(rng.pick(candidates, str(candidates[0])))


func _layout_positions(ids: Array, archetypes_by_id: Dictionary, start_id: String, rng: RngStream) -> Dictionary:
	var positions: Dictionary = {}
	for id_value in ids:
		var id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		var tier := clampi(int(archetype.get("tier", 1)), 1, 4)
		var id_rng := rng.fork("node:%s" % id)
		var anchor := _city_anchor_for_node(id, archetype, tier)
		var x_jitter := float(id_rng.randi_range(-3, 3)) / 100.0
		var y_jitter := float(id_rng.randi_range(-4, 4)) / 100.0
		var x := clampf(anchor.x + x_jitter, 0.06, 0.94)
		var y := clampf(anchor.y + y_jitter, 0.08, 0.92)
		if id == GRAND_CASINO_ID:
			x = clampf(anchor.x + float(id_rng.randi_range(-1, 1)) / 100.0, 0.86, 0.95)
			y = clampf(anchor.y + float(id_rng.randi_range(-3, 3)) / 100.0, 0.24, 0.78)
		elif id == start_id:
			x = clampf(x - 0.035, 0.06, 0.94)
		positions[id] = {"x": x, "y": y}
	return _spread_positions(ids, positions)


func _city_anchor_for_node(id: String, archetype: Dictionary, tier: int) -> Vector2:
	match id:
		"apartment":
			return Vector2(0.13, 0.32)
		"motel_room":
			return Vector2(0.21, 0.19)
		"house":
			return Vector2(0.11, 0.62)
		"corner_store":
			return Vector2(0.16, 0.45)
		"back_alley":
			return Vector2(0.29, 0.70)
		"motel":
			return Vector2(0.25, 0.24)
		"jazz_club":
			return Vector2(0.42, 0.42)
		"bar":
			return Vector2(0.49, 0.64)
		"gas_station_casino":
			return Vector2(0.50, 0.22)
		"small_underground_casino":
			return Vector2(0.62, 0.78)
		"kitty_cat_lounge":
			return Vector2(0.70, 0.48)
		"delta_queen":
			return Vector2(0.76, 0.20)
		"beach":
			return Vector2(0.80, 0.22)
		GRAND_CASINO_ID:
			return Vector2(0.90, 0.49)
	var kind := str(archetype.get("kind", "")).strip_edges()
	if kind == "home":
		return Vector2(0.12, 0.38)
	var kind_offset := 0.08 if kind == "casino" else -0.04
	var x := clampf(0.16 + float(tier - 1) * 0.24 + kind_offset, 0.08, 0.90)
	var y_seed := float(abs(hash(id)) % 64) / 100.0
	return Vector2(x, clampf(0.18 + y_seed, 0.12, 0.88))


func _spread_positions(ids: Array, source_positions: Dictionary) -> Dictionary:
	var positions := source_positions.duplicate(true)
	for pass_index in range(3):
		for id_a_value in ids:
			var id_a := str(id_a_value)
			var a: Dictionary = positions.get(id_a, {"x": 0.5, "y": 0.5})
			for id_b_value in ids:
				var id_b := str(id_b_value)
				if id_a >= id_b:
					continue
				var b: Dictionary = positions.get(id_b, {"x": 0.5, "y": 0.5})
				var dx := float(a.get("x", 0.5)) - float(b.get("x", 0.5))
				var dy := float(a.get("y", 0.5)) - float(b.get("y", 0.5))
				if absf(dx) >= 0.085 or absf(dy) >= 0.085:
					continue
				var push := 0.035 + float(pass_index) * 0.01
				a["y"] = clampf(float(a.get("y", 0.5)) + push, 0.08, 0.92)
				b["y"] = clampf(float(b.get("y", 0.5)) - push, 0.08, 0.92)
				positions[id_a] = a
				positions[id_b] = b
	return _enforce_beach_delta_adjacency(positions)


func _enforce_beach_delta_adjacency(positions: Dictionary) -> Dictionary:
	if not positions.has("beach") or not positions.has("delta_queen"):
		return positions
	var delta: Dictionary = positions.get("delta_queen", {})
	var delta_position := Vector2(float(delta.get("x", 0.76)), float(delta.get("y", 0.20)))
	var beach_position := Vector2(
		clampf(delta_position.x + 0.045, 0.06, 0.94),
		clampf(delta_position.y + 0.015, 0.08, 0.92)
	)
	positions["beach"] = {"x": beach_position.x, "y": beach_position.y}
	return positions


func _build_edges(ids: Array, archetypes_by_id: Dictionary, positions: Dictionary, start_id: String) -> Array:
	var edges_by_id: Dictionary = {}
	for source_id_value in ids:
		var source_id := str(source_id_value)
		var source: Dictionary = archetypes_by_id.get(source_id, {})
		var authored_targets := _ranked_target_ids(source_id, _unique_strings(_copy_array(source.get("next_archetypes", [])), _copy_array(source.get("travel_hooks", []))), archetypes_by_id, positions)
		for target_id_value in authored_targets:
			var target_id := str(target_id_value)
			if not archetypes_by_id.has(target_id):
				continue
			if _node_degree(edges_by_id, source_id) >= _target_degree(source_id, archetypes_by_id):
				break
			if _node_degree(edges_by_id, target_id) >= _target_degree(target_id, archetypes_by_id) + 1:
				continue
			_add_edge(edges_by_id, source_id, target_id, positions)
	for source_id_value in ids:
		var source_id := str(source_id_value)
		var nearest := _nearest_ids(source_id, ids, archetypes_by_id, positions)
		var target_degree := mini(_target_degree(source_id, archetypes_by_id), 2 if ids.size() > 5 else 1)
		for target_id in nearest:
			if _node_degree(edges_by_id, source_id) >= target_degree:
				break
			if _node_degree(edges_by_id, str(target_id)) >= _target_degree(str(target_id), archetypes_by_id) + 1:
				continue
			_add_edge(edges_by_id, source_id, str(target_id), positions)
	_guarantee_start_edges(edges_by_id, ids, archetypes_by_id, positions, start_id)
	_guarantee_progression_edges(edges_by_id, ids, archetypes_by_id, positions)
	if archetypes_by_id.has("beach") and archetypes_by_id.has("delta_queen"):
		_add_edge(edges_by_id, "beach", "delta_queen", positions)
	if archetypes_by_id.has(UNDERGROUND_SHORTCUT_ID) and archetypes_by_id.has(GRAND_CASINO_ID):
		_add_edge(edges_by_id, UNDERGROUND_SHORTCUT_ID, GRAND_CASINO_ID, positions)
	_connect_components(edges_by_id, ids, positions)
	var edge_ids := _sorted_keys(edges_by_id)
	var edges: Array = []
	for edge_id_value in edge_ids:
		edges.append(edges_by_id[str(edge_id_value)])
	return edges


func _guarantee_start_edges(edges_by_id: Dictionary, ids: Array, archetypes_by_id: Dictionary, positions: Dictionary, start_id: String) -> void:
	if start_id.is_empty() or not ids.has(start_id):
		return
	var open_targets: Array = []
	var fallback_targets: Array = []
	var start_archetype: Dictionary = archetypes_by_id.get(start_id, {})
	var parent_id := str(start_archetype.get("parent_archetype", "")).strip_edges()
	if not parent_id.is_empty() and ids.has(parent_id):
		open_targets.append(parent_id)
	for target_id_value in ids:
		var target_id := str(target_id_value)
		if target_id == start_id:
			continue
		var target_archetype: Dictionary = archetypes_by_id.get(target_id, {})
		if int(target_archetype.get("tier", 1)) > 2:
			continue
		if _route_is_spawn_open(target_id) and _archetype_has_games_for_discovery(target_archetype):
			if not open_targets.has(target_id):
				open_targets.append(target_id)
		elif _route_is_spawn_open(target_id) and not fallback_targets.has(target_id):
			fallback_targets.append(target_id)
	var ranked_targets := _ranked_target_ids(start_id, open_targets, archetypes_by_id, positions)
	if ranked_targets.size() < TRAVEL_NEW_TARGET_LIMIT:
		for fallback_id in _ranked_target_ids(start_id, fallback_targets, archetypes_by_id, positions):
			if not ranked_targets.has(str(fallback_id)):
				ranked_targets.append(str(fallback_id))
	for index in range(mini(TRAVEL_NEW_TARGET_LIMIT, ranked_targets.size())):
		_add_edge(edges_by_id, start_id, str(ranked_targets[index]), positions)


func _guarantee_progression_edges(edges_by_id: Dictionary, ids: Array, archetypes_by_id: Dictionary, positions: Dictionary) -> void:
	var tier_one := _ids_for_tier(ids, archetypes_by_id, 1)
	var tier_two := _ids_for_tier(ids, archetypes_by_id, 2)
	if not tier_one.is_empty() and not tier_two.is_empty():
		for target_id in tier_two:
			var nearest_tier_one := _nearest_from_pool(str(target_id), tier_one, positions)
			if not nearest_tier_one.is_empty():
				_add_edge(edges_by_id, nearest_tier_one, str(target_id), positions)
	if not tier_two.is_empty() and ids.has(GRAND_CASINO_ID):
		var grand_sources := _ranked_target_ids(GRAND_CASINO_ID, tier_two, archetypes_by_id, positions)
		for index in range(mini(2, grand_sources.size())):
			_add_edge(edges_by_id, str(grand_sources[index]), GRAND_CASINO_ID, positions)
	elif not tier_one.is_empty() and ids.has(GRAND_CASINO_ID):
		_add_edge(edges_by_id, str(tier_one[0]), GRAND_CASINO_ID, positions)


func _add_edge(edges_by_id: Dictionary, a: String, b: String, positions: Dictionary) -> void:
	var edge_id := _edge_id(a, b)
	if edge_id.is_empty() or edges_by_id.has(edge_id):
		return
	if _is_beach_route_pair(a, b) and not _is_beach_gateway_pair(a, b):
		return
	var pa: Dictionary = positions.get(a, {"x": 0.5, "y": 0.5})
	var pb: Dictionary = positions.get(b, {"x": 0.5, "y": 0.5})
	var distance := Vector2(float(pa.get("x", 0.5)), float(pa.get("y", 0.5))).distance_to(Vector2(float(pb.get("x", 0.5)), float(pb.get("y", 0.5))))
	var blocks := maxi(1, ceili(distance * 15.0))
	var band := _distance_band(blocks)
	var route := library.route(b) if library != null else {}
	var base_cost := maxi(0, int(route.get("cost", _base_cost_for_band(band))))
	var scaled_cost := maxi(0, ceili(float(base_cost) * float(BAND_COST_SCALE.get(band, 1.0))))
	var risk_decay := int(route.get("risk_decay", _risk_decay_for_band(band)))
	edges_by_id[edge_id] = {
		"id": edge_id,
		"a": a,
		"b": b,
		"distance": band,
		"distance_blocks": blocks,
		"base_cost": base_cost,
		"cost": scaled_cost,
		"risk_decay": clampi(risk_decay, 0, 100),
		"travel_method": _travel_method_for_band(band),
	}


func _nearest_ids(source_id: String, ids: Array, archetypes_by_id: Dictionary, positions: Dictionary) -> Array:
	var source: Dictionary = archetypes_by_id.get(source_id, {})
	var source_tier := int(source.get("tier", 1))
	var scored: Array = []
	for target_id_value in ids:
		var target_id := str(target_id_value)
		if target_id == source_id:
			continue
		var target: Dictionary = archetypes_by_id.get(target_id, {})
		var tier_gap := absi(int(target.get("tier", 1)) - source_tier)
		var score := _position_distance_score(source_id, target_id, positions) + float(tier_gap) * 0.35
		scored.append({"id": target_id, "score": score})
	scored.sort_custom(Callable(self, "_sort_score_entry"))
	var result: Array = []
	for entry_value in scored:
		var entry: Dictionary = entry_value
		result.append(str(entry.get("id", "")))
	return result


func _ranked_target_ids(source_id: String, target_ids: Array, archetypes_by_id: Dictionary, positions: Dictionary) -> Array:
	var source: Dictionary = archetypes_by_id.get(source_id, {})
	var source_tier := int(source.get("tier", 1))
	var scored: Array = []
	for target_id_value in target_ids:
		var target_id := str(target_id_value)
		if target_id == source_id or not archetypes_by_id.has(target_id):
			continue
		var target: Dictionary = archetypes_by_id.get(target_id, {})
		var target_tier := int(target.get("tier", 1))
		var tier_gap := absi(target_tier - source_tier)
		var score := _position_distance_score(source_id, target_id, positions) + float(tier_gap) * 0.18
		if target_tier == source_tier + 1:
			score -= 0.08
		if source_id == GRAND_CASINO_ID or target_id == GRAND_CASINO_ID:
			score += 0.22 if maxi(source_tier, target_tier) < 2 else 0.0
		scored.append({"id": target_id, "score": score})
	scored.sort_custom(Callable(self, "_sort_score_entry"))
	var result: Array = []
	for entry_value in scored:
		var entry: Dictionary = entry_value
		result.append(str(entry.get("id", "")))
	return result


func _nearest_from_pool(source_id: String, pool: Array, positions: Dictionary) -> String:
	var best_id := ""
	var best_score := INF
	for target_id_value in pool:
		var target_id := str(target_id_value)
		var score := _position_distance_score(source_id, target_id, positions)
		if score < best_score:
			best_score = score
			best_id = target_id
	return best_id


func _position_distance_score(a: String, b: String, positions: Dictionary) -> float:
	var pa: Dictionary = positions.get(a, {"x": 0.5, "y": 0.5})
	var pb: Dictionary = positions.get(b, {"x": 0.5, "y": 0.5})
	return Vector2(float(pa.get("x", 0.5)), float(pa.get("y", 0.5))).distance_to(Vector2(float(pb.get("x", 0.5)), float(pb.get("y", 0.5))))


func _sort_ids_by_x(a: Variant, b: Variant, positions: Dictionary) -> bool:
	var pa: Dictionary = positions.get(str(a), {"x": 0.5, "y": 0.5})
	var pb: Dictionary = positions.get(str(b), {"x": 0.5, "y": 0.5})
	if float(pa.get("x", 0.5)) == float(pb.get("x", 0.5)):
		return str(a) < str(b)
	return float(pa.get("x", 0.5)) < float(pb.get("x", 0.5))


func _sort_score_entry(a: Variant, b: Variant) -> bool:
	var entry_a: Dictionary = a
	var entry_b: Dictionary = b
	if float(entry_a.get("score", 0.0)) == float(entry_b.get("score", 0.0)):
		return str(entry_a.get("id", "")) < str(entry_b.get("id", ""))
	return float(entry_a.get("score", 0.0)) < float(entry_b.get("score", 0.0))


func _node_degree(edges_by_id: Dictionary, node_id: String) -> int:
	var count := 0
	for edge_value in edges_by_id.values():
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if str(edge.get("a", "")) == node_id or str(edge.get("b", "")) == node_id:
			count += 1
	return count


func _target_degree(node_id: String, archetypes_by_id: Dictionary) -> int:
	if node_id == GRAND_CASINO_ID:
		return 2
	var archetype: Dictionary = archetypes_by_id.get(node_id, {})
	if int(archetype.get("tier", 1)) >= 2:
		return 3
	return 3


func _connect_components(edges_by_id: Dictionary, ids: Array, positions: Dictionary) -> void:
	var components := _edge_components(edges_by_id, ids)
	while components.size() > 1:
		var base: Array = components[0]
		var best_a := ""
		var best_b := ""
		var best_score := INF
		for component_index in range(1, components.size()):
			var component: Array = components[component_index]
			for a_value in base:
				var a := str(a_value)
				for b_value in component:
					var b := str(b_value)
					var score := _position_distance_score(a, b, positions)
					if score < best_score:
						best_score = score
						best_a = a
						best_b = b
		if best_a.is_empty() or best_b.is_empty():
			return
		_add_edge(edges_by_id, best_a, best_b, positions)
		components = _edge_components(edges_by_id, ids)


func _edge_components(edges_by_id: Dictionary, ids: Array) -> Array:
	var remaining: Array = []
	for id_value in ids:
		remaining.append(str(id_value))
	var components: Array = []
	while not remaining.is_empty():
		var start_id := str(remaining.pop_front())
		var component: Array = []
		var queue: Array = [start_id]
		while not queue.is_empty():
			var current_id := str(queue.pop_front())
			if component.has(current_id):
				continue
			component.append(current_id)
			remaining.erase(current_id)
			for neighbor_id in _edge_neighbor_ids(edges_by_id.values(), current_id):
				if not component.has(str(neighbor_id)):
					queue.append(str(neighbor_id))
		components.append(component)
	return components


func _ids_for_tier(ids: Array, archetypes_by_id: Dictionary, tier: int) -> Array:
	var result: Array = []
	for id_value in ids:
		var id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		if int(archetype.get("tier", 1)) == tier:
			result.append(id)
	return result


func _node_label(archetype: Dictionary) -> String:
	var display_name := str(archetype.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	var nouns := _string_array(archetype.get("name_nouns", []))
	if not nouns.is_empty():
		return str(nouns[0])
	return str(archetype.get("id", "Unknown")).replace("_", " ").capitalize()


func _archetype_flavor(archetype: Dictionary) -> String:
	var visual_context: Dictionary = archetype.get("visual_context", {}) if typeof(archetype.get("visual_context", {})) == TYPE_DICTIONARY else {}
	var description := str(visual_context.get("description", "")).strip_edges()
	if not description.is_empty():
		return description
	var objective_hint := str(archetype.get("objective_hint", "")).strip_edges()
	if not objective_hint.is_empty():
		return objective_hint
	var kind := str(archetype.get("kind", "")).strip_edges()
	if not kind.is_empty():
		return "A %s stop on the city map." % kind
	return "A stop on the city map."


func _initial_discovered_ids(ids: Array, start_id: String, edges: Array, archetypes_by_id: Dictionary, rng: RngStream) -> Array:
	var discovered: Array = [start_id]
	var start_neighbors := _edge_neighbor_ids(edges, start_id)
	var game_neighbors: Array = []
	var open_game_neighbors: Array = []
	for neighbor_id_value in start_neighbors:
		var neighbor_id := str(neighbor_id_value)
		var neighbor_archetype: Dictionary = archetypes_by_id.get(neighbor_id, {})
		if _archetype_has_games_for_discovery(neighbor_archetype):
			game_neighbors.append(neighbor_id)
			if _route_is_spawn_open(neighbor_id):
				open_game_neighbors.append(neighbor_id)
	var game_pick_pool := open_game_neighbors if not open_game_neighbors.is_empty() else game_neighbors
	if not game_pick_pool.is_empty():
		var game_pick := str(rng.pick(game_pick_pool, str(game_pick_pool[0])))
		if not discovered.has(game_pick):
			discovered.append(game_pick)
	var desired_start_destinations := mini(TRAVEL_NEW_TARGET_LIMIT, start_neighbors.size())
	var extra_guaranteed_count := maxi(0, desired_start_destinations - (discovered.size() - 1))
	if extra_guaranteed_count > 0:
		var remaining_open_game_neighbors: Array = []
		var remaining_open_neighbors: Array = []
		var remaining_locked_neighbors: Array = []
		for neighbor_id_value in start_neighbors:
			var neighbor_id := str(neighbor_id_value)
			if discovered.has(neighbor_id):
				continue
			var neighbor_archetype: Dictionary = archetypes_by_id.get(neighbor_id, {})
			if _route_is_spawn_open(neighbor_id) and _archetype_has_games_for_discovery(neighbor_archetype):
				remaining_open_game_neighbors.append(neighbor_id)
			elif _route_is_spawn_open(neighbor_id):
				remaining_open_neighbors.append(neighbor_id)
			else:
				remaining_locked_neighbors.append(neighbor_id)
		extra_guaranteed_count = _append_discovery_picks(discovered, remaining_open_game_neighbors, extra_guaranteed_count, rng)
		extra_guaranteed_count = _append_discovery_picks(discovered, remaining_open_neighbors, extra_guaranteed_count, rng)
		_append_discovery_picks(discovered, remaining_locked_neighbors, extra_guaranteed_count, rng)
	for id_value in ids:
		var id := str(id_value)
		if discovered.has(id):
			continue
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		var tier := clampi(int(archetype.get("tier", 1)), 1, 4)
		var roll := rng.randi_range(1, 100)
		var chance := 0
		if tier <= 1:
			chance = 10
		elif tier == 2:
			chance = 6
		if str(archetype.get("rarity", "")).to_lower() == "rare":
			chance = mini(chance, 8)
		if id == GRAND_CASINO_ID:
			chance = 0
		if roll <= chance:
			discovered.append(id)
	return discovered


func _append_discovery_picks(discovered: Array, candidates: Array, remaining_count: int, rng: RngStream) -> int:
	if remaining_count <= 0 or candidates.is_empty():
		return remaining_count
	for picked_id in rng.pick_many(candidates, mini(remaining_count, candidates.size())):
		var picked_text := str(picked_id)
		if not discovered.has(picked_text):
			discovered.append(picked_text)
			remaining_count -= 1
			if remaining_count <= 0:
				return 0
	return remaining_count


func _archetype_has_games_for_discovery(archetype: Dictionary) -> bool:
	return not _string_array(archetype.get("required_game_ids", [])).is_empty() or not _string_array(archetype.get("game_pool", [])).is_empty()


func _archetype_game_capacity(archetype: Dictionary) -> int:
	var game_ids := _string_array(archetype.get("game_pool", []))
	for required_id in _string_array(archetype.get("required_game_ids", [])):
		if not game_ids.has(str(required_id)):
			game_ids.append(str(required_id))
	if game_ids.is_empty():
		return 0
	return mini(game_ids.size(), maxi(_count_ceiling(archetype.get("game_count", 0)), _string_array(archetype.get("required_game_ids", [])).size()))


func _count_ceiling(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		var max_count := 0
		for entry in values:
			max_count = maxi(max_count, int(entry))
		return max_count
	return int(value)


func _route_is_spawn_open(archetype_id: String) -> bool:
	if library == null:
		return true
	var route := library.route(archetype_id)
	if route.is_empty():
		return true
	return _copy_dict(route.get("requires_flags", {})).is_empty() and maxi(0, int(route.get("requires_travel_count_min", 0))) == 0 and not bool(route.get("hide_until_travel_count_met", false)) and _copy_dict(route.get("availability_window", {})).is_empty()


func _edge_neighbor_ids(edges: Array, source_id: String) -> Array:
	var result: Array = []
	for edge_value in edges:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		var other := ""
		if a == source_id:
			other = b
		elif b == source_id:
			other = a
		if not other.is_empty() and not result.has(other):
			result.append(other)
	result.sort()
	return result


static func _map_icon_path(archetype_id: String) -> String:
	var clean_id := archetype_id.strip_edges()
	if clean_id.is_empty():
		return ""
	return "res://assets/art/map_icons/%s.png" % clean_id


static func _normalize_nodes(nodes: Array) -> Array:
	var result: Array = []
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = node_value
		var id := str(source.get("id", source.get("archetype_id", ""))).strip_edges()
		if id.is_empty():
			continue
		var position := _copy_dict(source.get("position", {}))
		var discovery_source := str(source.get("discovery_source", source.get("unlock_source", ""))).strip_edges().to_lower()
		var discovered_at_spawn := bool(source.get("discovered_at_spawn", false))
		var unlocked := bool(source.get("unlocked", false))
		if discovered_at_spawn and discovery_source.is_empty():
			discovery_source = DISCOVERY_SOURCE_SPAWN
		elif unlocked and discovery_source.is_empty():
			discovery_source = DISCOVERY_SOURCE_EVENT
		result.append({
			"id": id,
			"archetype_id": str(source.get("archetype_id", id)),
			"label": str(source.get("label", id.replace("_", " ").capitalize())),
			"kind": str(source.get("kind", "")),
			"tier": int(source.get("tier", 1)),
			"game_capacity": maxi(0, int(source.get("game_capacity", 0))),
			"position": {
				"x": clampf(float(position.get("x", 0.5)), 0.0, 1.0),
				"y": clampf(float(position.get("y", 0.5)), 0.0, 1.0),
			},
			"state": _normalized_state(str(source.get("state", STATE_HIDDEN))),
			"discovered_at_spawn": discovered_at_spawn,
			"unlocked": unlocked,
			"discovery_source": discovery_source,
			"route_spawn_open": bool(source.get("route_spawn_open", true)),
			"icon_path": str(source.get("icon_path", _map_icon_path(id))),
			"flavor": str(source.get("flavor", "")),
			"scouted": bool(source.get("scouted", false)),
			"home_lost": bool(source.get("home_lost", false)),
			"environment": _copy_dict(source.get("environment", {})),
		})
	return result


static func _normalize_edges(edges: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for edge_value in edges:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = edge_value
		var a := str(source.get("a", "")).strip_edges()
		var b := str(source.get("b", "")).strip_edges()
		var edge_id := _edge_id(a, b)
		if edge_id.is_empty() or seen.has(edge_id):
			continue
		seen[edge_id] = true
		var distance_band := _distance_band(maxi(1, int(source.get("distance_blocks", 1))))
		if source.has("distance"):
			var authored_distance := str(source.get("distance", "")).strip_edges().to_lower()
			if BAND_COST_SCALE.has(authored_distance):
				distance_band = authored_distance
		result.append({
			"id": edge_id,
			"a": a,
			"b": b,
			"distance": distance_band,
			"distance_blocks": maxi(1, int(source.get("distance_blocks", 1))),
			"base_cost": maxi(0, int(source.get("base_cost", source.get("cost", 0)))),
			"cost": maxi(0, int(source.get("cost", 0))),
			"risk_decay": clampi(int(source.get("risk_decay", _risk_decay_for_band(distance_band))), 0, 100),
			"travel_method": str(source.get("travel_method", _travel_method_for_band(distance_band))),
		})
	return result


static func _normalized_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	if [STATE_HIDDEN, STATE_REVEALED, STATE_VISITED].has(normalized):
		return normalized
	return STATE_HIDDEN


static func _node_is_visible(node: Dictionary) -> bool:
	var state := str(node.get("state", STATE_HIDDEN))
	if state == STATE_VISITED:
		return true
	if state != STATE_REVEALED:
		return false
	var discovery_source := str(node.get("discovery_source", node.get("unlock_source", ""))).strip_edges().to_lower()
	return bool(node.get("discovered_at_spawn", false)) or bool(node.get("unlocked", false)) or discovery_source == DISCOVERY_SOURCE_SPAWN or discovery_source == DISCOVERY_SOURCE_EVENT or discovery_source == DISCOVERY_SOURCE_TRAVEL


static func _snapshot_node(node: Dictionary) -> Dictionary:
	return {
		"id": str(node.get("id", "")),
		"archetype_id": str(node.get("archetype_id", node.get("id", ""))),
		"label": str(node.get("label", "")),
		"kind": str(node.get("kind", "")),
		"tier": int(node.get("tier", 1)),
		"game_capacity": int(node.get("game_capacity", 0)),
		"position": _copy_dict(node.get("position", {})),
		"state": str(node.get("state", STATE_HIDDEN)),
		"discovered_at_spawn": bool(node.get("discovered_at_spawn", false)),
		"unlocked": bool(node.get("unlocked", false)),
		"discovery_source": str(node.get("discovery_source", "")),
		"route_spawn_open": bool(node.get("route_spawn_open", true)),
		"scouted": bool(node.get("scouted", false)),
		"icon_path": str(node.get("icon_path", _map_icon_path(str(node.get("archetype_id", node.get("id", "")))))),
		"flavor": str(node.get("flavor", "")),
		"home_lost": bool(node.get("home_lost", false)),
	}


static func _enabled_target_lookup(enabled_target_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id_value in _string_array(enabled_target_ids):
		result[str(id_value)] = true
	return result


static func _candidate_enabled_hint(node: Dictionary, target_id: String, enabled_lookup: Dictionary) -> bool:
	if not enabled_lookup.is_empty():
		return bool(enabled_lookup.get(target_id, false))
	return bool(node.get("route_spawn_open", true))


static func _filter_candidates_by_enabled(candidates: Array, enabled: bool) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if bool(candidate.get("enabled_hint", true)) == enabled:
			result.append(candidate)
	return result


static func _ensure_priority_target(result: Array, candidates: Array, target_id: String, total_limit: int) -> Array:
	var normalized_result := result.duplicate(true)
	if total_limit <= 0 or target_id.is_empty() or normalized_result.has(target_id):
		return normalized_result
	var found := false
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if str(candidate.get("id", "")) == target_id and bool(candidate.get("enabled_hint", true)):
			found = true
			break
	if not found:
		return normalized_result
	if normalized_result.size() < total_limit:
		normalized_result.append(target_id)
	elif not normalized_result.is_empty():
		normalized_result[normalized_result.size() - 1] = target_id
	return normalized_result


static func _ensure_visible_neighbor_target(result: Array, source_id: String, target_id: String, total_limit: int, visible_lookup: Dictionary, edge_lookup: Dictionary, node_lookup: Dictionary) -> Array:
	var normalized_result := result.duplicate(true)
	if total_limit <= 0 or source_id.is_empty() or target_id.is_empty() or normalized_result.has(target_id):
		return normalized_result
	if not visible_lookup.has(source_id) or not visible_lookup.has(target_id):
		return normalized_result
	if not edge_lookup.has(_edge_id(source_id, target_id)):
		return normalized_result
	var target_node: Dictionary = node_lookup.get(target_id, {})
	if target_node.is_empty() or bool(target_node.get("home_lost", false)):
		return normalized_result
	if normalized_result.size() < total_limit:
		normalized_result.append(target_id)
	elif not normalized_result.is_empty():
		normalized_result[normalized_result.size() - 1] = target_id
	return normalized_result


static func _travel_candidate_entries(map_data: Dictionary, source_id: String, visited_only: bool, enabled_lookup: Dictionary = {}) -> Array:
	var visible_data := _visible_ids_and_lookup(map_data)
	var visible_ids: Array = visible_data.get("ids", [])
	var visible_lookup: Dictionary = visible_data.get("lookup", {})
	var node_lookup := _node_lookup(map_data)
	var edge_lookup := _edge_lookup(map_data)
	var visited_path := _string_array(map_data.get("visited_path", []))
	return _travel_candidate_entries_prepared(map_data, source_id, visited_only, enabled_lookup, visible_ids, visible_lookup, node_lookup, edge_lookup, visited_path)


static func _travel_candidate_entries_prepared(map_data: Dictionary, source_id: String, visited_only: bool, enabled_lookup: Dictionary, visible_ids: Array, visible_lookup: Dictionary, node_lookup: Dictionary, edge_lookup: Dictionary, visited_path: Array) -> Array:
	var entries: Array = []
	for target_id_value in visible_ids:
		var target_id := str(target_id_value)
		if target_id == source_id:
			continue
		if not _travel_target_allowed_from_source(source_id, target_id):
			continue
		var node: Dictionary = node_lookup.get(target_id, {})
		if node.is_empty():
			continue
		if bool(node.get("home_lost", false)):
			continue
		var is_visited := str(node.get("state", STATE_HIDDEN)) == STATE_VISITED
		if is_visited != visited_only:
			continue
		var path := _path_between_prepared(map_data, source_id, target_id, true, visible_lookup)
		if path.size() < 2:
			if not visited_only:
				continue
			path = [source_id, target_id]
		var blocks := _path_distance_blocks_prepared(edge_lookup, path)
		var direct_edge: Dictionary = edge_lookup.get(_edge_id(str(path[0]), str(path[1])), {})
		if visited_only and path.size() == 2 and direct_edge.is_empty():
			var source_node: Dictionary = node_lookup.get(source_id, {})
			var source_position: Dictionary = source_node.get("position", {"x": 0.5, "y": 0.5}) if typeof(source_node.get("position", {})) == TYPE_DICTIONARY else {"x": 0.5, "y": 0.5}
			var target_position: Dictionary = node.get("position", {"x": 0.5, "y": 0.5}) if typeof(node.get("position", {})) == TYPE_DICTIONARY else {"x": 0.5, "y": 0.5}
			var direct_distance := Vector2(float(source_position.get("x", 0.5)), float(source_position.get("y", 0.5))).distance_to(Vector2(float(target_position.get("x", 0.5)), float(target_position.get("y", 0.5))))
			blocks = maxi(1, ceili(direct_distance * 15.0))
		var cost := _path_cost_prepared(edge_lookup, path)
		if cost <= 0:
			var band := _distance_band(blocks)
			cost = maxi(0, ceili(float(_base_cost_for_band(band)) * float(BAND_COST_SCALE.get(band, 1.0))))
		var last_visit_index := _last_index_of(visited_path, target_id)
		var enabled_hint := _candidate_enabled_hint(node, target_id, enabled_lookup)
		var score := float(blocks) + float(cost) * 0.08 + float(int(node.get("tier", 1))) * 0.18
		if visited_only:
			score = float(blocks) * 0.55 + float(cost) * 0.06 - float(last_visit_index) * 0.10
		else:
			var kind := str(node.get("kind", "")).strip_edges()
			if kind == "casino" or kind == "boss":
				score -= 1.5
			elif kind == "shop":
				score += 1.0
			var game_capacity := int(node.get("game_capacity", 0))
			if game_capacity >= 2:
				score -= 4.0
			elif game_capacity == 1:
				score += 0.5
		if not enabled_hint:
			score += 100.0
		entries.append({
			"id": target_id,
			"path": path.duplicate(true),
			"distance_blocks": blocks,
			"cost": cost,
			"visited": is_visited,
			"enabled_hint": enabled_hint,
			"last_visit_index": last_visit_index,
			"score": score,
		})
	entries.sort_custom(Callable(WorldMap, "_sort_travel_candidate"))
	return entries


static func _travel_target_allowed_from_source(source_id: String, target_id: String) -> bool:
	var source := source_id.strip_edges()
	var target := target_id.strip_edges()
	if target != BEACH_ID:
		return true
	return source == BEACH_GATEWAY_ID


static func _is_beach_route_pair(a: String, b: String) -> bool:
	return a.strip_edges() == BEACH_ID or b.strip_edges() == BEACH_ID


static func _is_beach_gateway_pair(a: String, b: String) -> bool:
	var left := a.strip_edges()
	var right := b.strip_edges()
	return (left == BEACH_ID and right == BEACH_GATEWAY_ID) or (left == BEACH_GATEWAY_ID and right == BEACH_ID)


static func _sort_travel_candidate(a: Variant, b: Variant) -> bool:
	var entry_a: Dictionary = a
	var entry_b: Dictionary = b
	var score_a := float(entry_a.get("score", 0.0))
	var score_b := float(entry_b.get("score", 0.0))
	if score_a == score_b:
		return str(entry_a.get("id", "")) < str(entry_b.get("id", ""))
	return score_a < score_b


static func _reconstruct_path(previous_by_id: Dictionary, source_id: String, target_id: String) -> Array:
	var path: Array = [target_id]
	var current_id := target_id
	var guard := 0
	while current_id != source_id and guard < previous_by_id.size() + 2:
		current_id = str(previous_by_id.get(current_id, ""))
		if current_id.is_empty():
			return []
		path.push_front(current_id)
		guard += 1
	if path.is_empty() or str(path[0]) != source_id:
		return []
	return path


static func _path_distance_blocks(map_data: Dictionary, path: Array) -> int:
	var blocks := 0
	for edge in _path_edges(map_data, path):
		var edge_data: Dictionary = edge
		blocks += maxi(1, int(edge_data.get("distance_blocks", 1)))
	return maxi(1, blocks)


static func _path_base_cost(map_data: Dictionary, path: Array) -> int:
	var total := 0
	for edge in _path_edges(map_data, path):
		var edge_data: Dictionary = edge
		total += maxi(0, int(edge_data.get("base_cost", edge_data.get("cost", 0))))
	return total


static func _path_cost(map_data: Dictionary, path: Array) -> int:
	var total := 0
	for edge in _path_edges(map_data, path):
		var edge_data: Dictionary = edge
		total += maxi(0, int(edge_data.get("cost", edge_data.get("base_cost", 0))))
	return total


static func _path_risk_decay(map_data: Dictionary, path: Array, band: String) -> int:
	var risk_decay := _risk_decay_for_band(band)
	for edge in _path_edges(map_data, path):
		var edge_data: Dictionary = edge
		risk_decay = maxi(risk_decay, int(edge_data.get("risk_decay", 0)))
	return clampi(risk_decay, 0, 100)


static func _route_edge_id(map_data: Dictionary, path: Array) -> String:
	if path.size() == 2:
		var direct_edge := edge_between(map_data, str(path[0]), str(path[1]))
		if not direct_edge.is_empty():
			return str(direct_edge.get("id", _edge_id(str(path[0]), str(path[1]))))
	return "path:%s" % "->".join(path)


static func _path_edges(map_data: Dictionary, path: Array) -> Array:
	var edges: Array = []
	for index in range(path.size() - 1):
		var edge := edge_between(map_data, str(path[index]), str(path[index + 1]))
		if edge.is_empty():
			return []
		edges.append(edge)
	return edges


static func _path_distance_blocks_prepared(edge_lookup: Dictionary, path: Array) -> int:
	var blocks := 0
	for index in range(path.size() - 1):
		var edge: Dictionary = edge_lookup.get(_edge_id(str(path[index]), str(path[index + 1])), {})
		if edge.is_empty():
			return 1
		blocks += maxi(1, int(edge.get("distance_blocks", 1)))
	return maxi(1, blocks)


static func _path_base_cost_prepared(edge_lookup: Dictionary, path: Array) -> int:
	var total := 0
	for index in range(path.size() - 1):
		var edge: Dictionary = edge_lookup.get(_edge_id(str(path[index]), str(path[index + 1])), {})
		if edge.is_empty():
			return 0
		total += maxi(0, int(edge.get("base_cost", edge.get("cost", 0))))
	return total


static func _path_cost_prepared(edge_lookup: Dictionary, path: Array) -> int:
	var total := 0
	for index in range(path.size() - 1):
		var edge: Dictionary = edge_lookup.get(_edge_id(str(path[index]), str(path[index + 1])), {})
		if edge.is_empty():
			return 0
		total += maxi(0, int(edge.get("cost", edge.get("base_cost", 0))))
	return total


static func _path_risk_decay_prepared(edge_lookup: Dictionary, path: Array, band: String) -> int:
	var risk_decay := _risk_decay_for_band(band)
	for index in range(path.size() - 1):
		var edge: Dictionary = edge_lookup.get(_edge_id(str(path[index]), str(path[index + 1])), {})
		if edge.is_empty():
			return clampi(risk_decay, 0, 100)
		risk_decay = maxi(risk_decay, int(edge.get("risk_decay", 0)))
	return clampi(risk_decay, 0, 100)


static func _route_edge_id_prepared(edge_lookup: Dictionary, path: Array) -> String:
	if path.size() == 2:
		var edge: Dictionary = edge_lookup.get(_edge_id(str(path[0]), str(path[1])), {})
		if not edge.is_empty():
			return str(edge.get("id", _edge_id(str(path[0]), str(path[1]))))
	return "path:%s" % "->".join(path)


static func _last_index_of(values: Array, target_id: String) -> int:
	for index in range(values.size() - 1, -1, -1):
		if str(values[index]) == target_id:
			return index
	return -1


static func _travel_method_for_band(band: String) -> String:
	match band:
		DISTANCE_NEAR:
			return "Walk"
		DISTANCE_LOCAL:
			return "Bus ticket"
		DISTANCE_FAR:
			return "Taxi ride"
		_:
			return "Night cab"


static func _distance_band(blocks: int) -> String:
	if blocks <= 3:
		return DISTANCE_NEAR
	if blocks <= 6:
		return DISTANCE_LOCAL
	if blocks <= 10:
		return DISTANCE_FAR
	return DISTANCE_REMOTE


static func _base_cost_for_band(band: String) -> int:
	match band:
		DISTANCE_NEAR:
			return 1
		DISTANCE_LOCAL:
			return 2
		DISTANCE_FAR:
			return 5
		_:
			return 10


static func _risk_decay_for_band(band: String) -> int:
	match band:
		DISTANCE_NEAR:
			return 18
		DISTANCE_LOCAL:
			return 35
		DISTANCE_FAR:
			return 70
		_:
			return 95


static func _edge_id(a: String, b: String) -> String:
	var left := a.strip_edges()
	var right := b.strip_edges()
	if left.is_empty() or right.is_empty() or left == right:
		return ""
	if left < right:
		return "%s--%s" % [left, right]
	return "%s--%s" % [right, left]


static func _sorted_keys(source: Dictionary) -> Array:
	var result: Array = []
	for key in source.keys():
		result.append(str(key))
	result.sort()
	return result


static func _unique_strings(a: Array, b: Array = []) -> Array:
	var result: Array = []
	for source in [a, b]:
		for value in source:
			var text := str(value).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
