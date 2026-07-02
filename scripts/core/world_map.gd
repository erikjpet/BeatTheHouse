class_name WorldMap
extends RefCounted

# Persistent deterministic travel graph for Act 1 runs.

const VERSION := 1
const GRAND_CASINO_ID := "grand_casino"
const UNDERGROUND_SHORTCUT_ID := "small_underground_casino"
const STATE_HIDDEN := "hidden"
const STATE_REVEALED := "revealed"
const STATE_VISITED := "visited"
const DISTANCE_NEAR := "near"
const DISTANCE_LOCAL := "local"
const DISTANCE_FAR := "far"
const DISTANCE_REMOTE := "remote"
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
	var ids := _sorted_keys(archetypes_by_id)
	if ids.size() < 2:
		return {}
	var start_id := _pick_start_id(archetypes_by_id, rng)
	var nodes: Array = []
	var positions := _layout_positions(ids, archetypes_by_id, start_id, rng.fork("world_map_layout"))
	for id_value in ids:
		var archetype_id := str(id_value)
		var archetype: Dictionary = archetypes_by_id.get(archetype_id, {})
		var position: Dictionary = positions.get(archetype_id, {"x": 0.5, "y": 0.5})
		nodes.append({
			"id": archetype_id,
			"archetype_id": archetype_id,
			"label": _node_label(archetype),
			"kind": str(archetype.get("kind", "")),
			"tier": int(archetype.get("tier", 1)),
			"position": position.duplicate(true),
			"state": STATE_HIDDEN,
			"scouted": false,
			"environment": {},
		})
	var edges := _build_edges(ids, archetypes_by_id, positions)
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
	var source_id := current_id.strip_edges()
	var destination_id := target_id.strip_edges()
	if source_id.is_empty() or destination_id.is_empty() or source_id == destination_id:
		return {}
	if not are_neighbors(map_data, source_id, destination_id):
		return {}
	var edge := edge_between(map_data, source_id, destination_id)
	if edge.is_empty():
		return {}
	var route := library.route(destination_id).duplicate(true) if library != null else {}
	if route.is_empty():
		route = {
			"id": destination_id,
			"destination_archetype": destination_id,
			"distance": str(edge.get("distance", DISTANCE_NEAR)),
			"risk_decay": int(edge.get("risk_decay", 12)),
		}
	var band := str(edge.get("distance", route.get("distance", DISTANCE_NEAR)))
	var base_cost := maxi(0, int(route.get("cost", _base_cost_for_band(band))))
	var generated_cost := maxi(0, ceili(float(base_cost) * float(BAND_COST_SCALE.get(band, 1.0))))
	route["id"] = destination_id
	route["destination_archetype"] = destination_id
	route["from_archetype"] = source_id
	route["target_node_id"] = destination_id
	route["world_edge_id"] = str(edge.get("id", _edge_id(source_id, destination_id)))
	route["distance"] = band
	route["distance_blocks"] = int(edge.get("distance_blocks", 1))
	route["base_cost"] = base_cost
	route["cost"] = generated_cost
	route["risk_decay"] = int(edge.get("risk_decay", route.get("risk_decay", 0)))
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
	for node_value in _copy_array(map_data.get("nodes", [])):
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
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var state := str(node.get("state", STATE_HIDDEN))
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty() and [STATE_REVEALED, STATE_VISITED].has(state):
			result.append(node_id)
	return result


static func neighbor_ids(map_data: Dictionary, node_id: String, visible_only: bool = false) -> Array:
	var result: Array = []
	var source_id := node_id.strip_edges()
	if source_id.is_empty():
		return result
	for edge_value in _copy_array(map_data.get("edges", [])):
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
		if visible_only and not visible_node_ids(map_data).has(other):
			continue
		result.append(other)
	return result


static func are_neighbors(map_data: Dictionary, a: String, b: String) -> bool:
	return not edge_between(map_data, a, b).is_empty()


static func edge_between(map_data: Dictionary, a: String, b: String) -> Dictionary:
	var edge_id := _edge_id(a, b)
	if edge_id.is_empty():
		return {}
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if str(edge.get("id", "")) == edge_id:
			return edge.duplicate(true)
	return {}


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
			continue
		if are_neighbors(normalized, target_id, str(node.get("id", ""))) and str(node.get("state", STATE_HIDDEN)) == STATE_HIDDEN:
			node["state"] = STATE_REVEALED
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


static func snapshot(map_data: Dictionary, selected_id: String = "") -> Dictionary:
	var normalized := normalize(map_data)
	var visible_ids := visible_node_ids(normalized)
	var visible_nodes: Array = []
	for node_value in _copy_array(normalized.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if visible_ids.has(str(node.get("id", ""))):
			visible_nodes.append(node.duplicate(true))
	var visible_edges: Array = []
	for edge_value in _copy_array(normalized.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		if visible_ids.has(str(edge.get("a", ""))) and visible_ids.has(str(edge.get("b", ""))):
			visible_edges.append(edge.duplicate(true))
	return {
		"version": VERSION,
		"current_node_id": current_node_id(normalized),
		"selected_node_id": selected_id,
		"visible_node_ids": visible_ids,
		"nodes": visible_nodes,
		"edges": visible_edges,
		"visited_path": _string_array(normalized.get("visited_path", [])),
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


func _pick_start_id(archetypes_by_id: Dictionary, rng: RngStream) -> String:
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
	for index in range(ids.size()):
		var id := str(ids[index])
		var archetype: Dictionary = archetypes_by_id.get(id, {})
		var tier := clampi(int(archetype.get("tier", 1)), 1, 4)
		var id_rng := rng.fork("node:%s" % id)
		var y_jitter := float(id_rng.randi_range(-18, 18)) / 100.0
		var x_jitter := float(id_rng.randi_range(-8, 8)) / 100.0
		var x := clampf(0.14 + float(tier - 1) * 0.22 + x_jitter, 0.06, 0.92)
		var y_base := 0.20 + float((index * 37) % 61) / 100.0
		var y := clampf(y_base + y_jitter, 0.12, 0.88)
		if id == GRAND_CASINO_ID:
			x = 0.93
			y = 0.50 + float(id_rng.randi_range(-5, 5)) / 100.0
		elif id == start_id:
			x = 0.08
			y = 0.50
		positions[id] = {"x": x, "y": y}
	return _spread_positions(ids, positions)


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
	return positions


func _build_edges(ids: Array, archetypes_by_id: Dictionary, positions: Dictionary) -> Array:
	var edges_by_id: Dictionary = {}
	for source_id_value in ids:
		var source_id := str(source_id_value)
		var source: Dictionary = archetypes_by_id.get(source_id, {})
		for target_id in _unique_strings(_copy_array(source.get("next_archetypes", [])), _copy_array(source.get("travel_hooks", []))):
			if archetypes_by_id.has(target_id):
				_add_edge(edges_by_id, source_id, target_id, positions)
	for source_id_value in ids:
		var source_id := str(source_id_value)
		var nearest := _nearest_ids(source_id, ids, archetypes_by_id, positions)
		var target_degree := 3 if ids.size() > 5 else 2
		for target_id in nearest:
			if _node_degree(edges_by_id, source_id) >= target_degree:
				break
			_add_edge(edges_by_id, source_id, str(target_id), positions)
	var x_sorted := ids.duplicate(true)
	x_sorted.sort_custom(Callable(self, "_sort_ids_by_x").bind(positions))
	for index in range(x_sorted.size() - 1):
		_add_edge(edges_by_id, str(x_sorted[index]), str(x_sorted[index + 1]), positions)
	_guarantee_progression_edges(edges_by_id, ids, archetypes_by_id, positions)
	if archetypes_by_id.has(UNDERGROUND_SHORTCUT_ID) and archetypes_by_id.has(GRAND_CASINO_ID):
		_add_edge(edges_by_id, UNDERGROUND_SHORTCUT_ID, GRAND_CASINO_ID, positions)
	var edge_ids := _sorted_keys(edges_by_id)
	var edges: Array = []
	for edge_id_value in edge_ids:
		edges.append(edges_by_id[str(edge_id_value)])
	return edges


func _guarantee_progression_edges(edges_by_id: Dictionary, ids: Array, archetypes_by_id: Dictionary, positions: Dictionary) -> void:
	var tier_one := _ids_for_tier(ids, archetypes_by_id, 1)
	var tier_two := _ids_for_tier(ids, archetypes_by_id, 2)
	if not tier_one.is_empty() and not tier_two.is_empty():
		for source_id in tier_one:
			var nearest_tier_two := _nearest_from_pool(str(source_id), tier_two, positions)
			if not nearest_tier_two.is_empty():
				_add_edge(edges_by_id, str(source_id), nearest_tier_two, positions)
	if not tier_two.is_empty() and ids.has(GRAND_CASINO_ID):
		for source_id in tier_two:
			_add_edge(edges_by_id, str(source_id), GRAND_CASINO_ID, positions)
	elif not tier_one.is_empty() and ids.has(GRAND_CASINO_ID):
		_add_edge(edges_by_id, str(tier_one[0]), GRAND_CASINO_ID, positions)


func _add_edge(edges_by_id: Dictionary, a: String, b: String, positions: Dictionary) -> void:
	var edge_id := _edge_id(a, b)
	if edge_id.is_empty() or edges_by_id.has(edge_id):
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
		result.append({
			"id": id,
			"archetype_id": str(source.get("archetype_id", id)),
			"label": str(source.get("label", id.replace("_", " ").capitalize())),
			"kind": str(source.get("kind", "")),
			"tier": int(source.get("tier", 1)),
			"position": {
				"x": clampf(float(position.get("x", 0.5)), 0.0, 1.0),
				"y": clampf(float(position.get("y", 0.5)), 0.0, 1.0),
			},
			"state": _normalized_state(str(source.get("state", STATE_HIDDEN))),
			"scouted": bool(source.get("scouted", false)),
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
		})
	return result


static func _normalized_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	if [STATE_HIDDEN, STATE_REVEALED, STATE_VISITED].has(normalized):
		return normalized
	return STATE_HIDDEN


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
