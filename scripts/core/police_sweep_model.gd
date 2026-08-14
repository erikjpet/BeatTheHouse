class_name PoliceSweepModel
extends RefCounted

const SCHEMA_VERSION := 1
const GRAND_CASINO_IDS := [
	"grand_casino",
	"grand_casino_high_limit",
	"grand_casino_back_room",
	"grand_casino_cage",
]

var seed_value: int = 1
var action_index: int = 0
var configured: bool = false
var disabled: bool = false
var start_action: int = 0
var end_action: int = 0
var segments: Array = []
var segment_index: int = -1
var swept_windows_by_node: Dictionary = {}
var personal_marker: Dictionary = {}
var last_encounter_segment: int = -1
var last_encounter_node_id: String = ""
var last_adjacent_sighting_segment: int = -1
var config: Dictionary = {}
var reroute_history: Array = []

var _node_metadata: Dictionary = {}
var _neighbors_by_node: Dictionary = {}


func reset(p_seed_value: int, source_config: Dictionary = {}) -> void:
	seed_value = maxi(1, p_seed_value)
	action_index = 0
	configured = false
	disabled = false
	start_action = 0
	end_action = 0
	segments = []
	segment_index = -1
	swept_windows_by_node = {}
	personal_marker = {}
	last_encounter_segment = -1
	last_encounter_node_id = ""
	last_adjacent_sighting_segment = -1
	config = source_config.duplicate(true)
	reroute_history = []
	_node_metadata = {}
	_neighbors_by_node = {}


func disable(p_seed_value: int, source_config: Dictionary = {}) -> void:
	reset(p_seed_value, source_config)
	disabled = true
	configured = true


func configure_world(map_data: Dictionary, happening: Dictionary, source_config: Dictionary, current_action: int) -> void:
	action_index = maxi(0, current_action)
	config = source_config.duplicate(true)
	_index_world(map_data)
	if disabled:
		configured = true
		return
	if configured and not segments.is_empty():
		_sync_segment_index()
		return
	if happening.is_empty() or _eligible_node_ids().is_empty():
		return
	configured = true
	start_action = maxi(0, int(happening.get("start_action", 0)))
	end_action = maxi(start_action + 1, int(happening.get("end_action", start_action + 1)))
	_generate_segments()
	_sync_segment_index()
	var current := status()
	if bool(current.get("active", false)) and not last_encounter_node_id.is_empty() and str(current.get("current_node_id", "")) != last_encounter_node_id:
		last_encounter_node_id = ""


func advance_to(next_action_index: int) -> Array:
	var target := maxi(action_index, next_action_index)
	var departures: Array = []
	if disabled or segments.is_empty():
		action_index = target
		return departures
	var previous_index := segment_index
	action_index = target
	_sync_segment_index()
	var current := status()
	if bool(current.get("active", false)) and not last_encounter_node_id.is_empty() and str(current.get("current_node_id", "")) != last_encounter_node_id:
		last_encounter_node_id = ""
	if segment_index > previous_index:
		for index in range(maxi(0, previous_index), segment_index):
			if index < 0 or index >= segments.size():
				continue
			var segment: Dictionary = segments[index]
			var node_id := str(segment.get("node_id", ""))
			var departed_action := int(segment.get("end_action", action_index))
			var window_actions := maxi(1, int(config.get("swept_window_actions", 5)))
			var window := {
				"node_id": node_id,
				"start_action": departed_action,
				"end_action": departed_action + window_actions,
				"source_segment_index": index,
			}
			swept_windows_by_node[node_id] = window
			departures.append(window.duplicate(true))
	_prune_windows()
	return departures


func status() -> Dictionary:
	if disabled or segments.is_empty() or segment_index < 0 or segment_index >= segments.size():
		return {}
	var segment: Dictionary = segments[segment_index]
	var active := action_index >= start_action and action_index < end_action
	return {
		"spawned": true,
		"active": active,
		"current_node_id": str(segment.get("node_id", "")) if active else "",
		"previous_node_id": str(segments[segment_index - 1].get("node_id", "")) if active and segment_index > 0 else "",
		"heading_node_id": str(segments[segment_index + 1].get("node_id", "")) if active and segment_index + 1 < segments.size() else "",
		"arrived_action": int(segment.get("start_action", start_action)),
		"next_move_action": int(segment.get("end_action", end_action)),
		"start_action": start_action,
		"end_action": end_action,
		"segment_index": segment_index,
	}


func intel_status(capabilities: Dictionary) -> Dictionary:
	if not bool(capabilities.get("sweep_intel", false)):
		return {}
	return status()


func report_intel_at_boundary(capabilities: Dictionary, source: String = "crew_intel") -> Dictionary:
	if not bool(capabilities.get("sweep_intel", false)):
		return {}
	return record_personal_sighting(source)


func map_marker(_capabilities: Dictionary = {}) -> Dictionary:
	if personal_marker.is_empty():
		return {}
	var marker := personal_marker.duplicate(true)
	marker["stale_actions"] = maxi(0, action_index - int(marker.get("sighted_action", action_index)))
	marker["live"] = false
	return marker


func record_personal_sighting(source: String = "direct") -> Dictionary:
	var current := status()
	if not bool(current.get("active", false)):
		return {}
	personal_marker = {
		"node_id": str(current.get("current_node_id", "")),
		"heading_node_id": str(current.get("heading_node_id", "")),
		"sighted_action": action_index,
		"source": source,
		"segment_index": int(current.get("segment_index", -1)),
	}
	return map_marker()


func is_at(node_id: String) -> bool:
	var current := status()
	return bool(current.get("active", false)) and str(current.get("current_node_id", "")) == node_id.strip_edges()


func is_adjacent(node_id: String) -> bool:
	var current := status()
	if not bool(current.get("active", false)):
		return false
	return _string_array(_neighbors_by_node.get(str(current.get("current_node_id", "")), [])).has(node_id.strip_edges())


func adjacent_sighting_due(player_node_id: String) -> bool:
	if not is_adjacent(player_node_id):
		return false
	var current := status()
	var current_segment := int(current.get("segment_index", -1))
	if current_segment < 0 or current_segment == last_adjacent_sighting_segment:
		return false
	var chance := clampi(int(config.get("adjacent_sighting_chance_percent", 35)), 0, 100)
	var roll := (_stable_hash("%d:%s:%d:adjacent" % [seed_value, player_node_id, current_segment]) % 100) + 1
	if roll > chance:
		return false
	last_adjacent_sighting_segment = current_segment
	return true


func claim_encounter(node_id: String) -> Dictionary:
	if not is_at(node_id):
		return {}
	var current := status()
	var current_segment := int(current.get("segment_index", -1))
	if current_segment < 0 or current_segment == last_encounter_segment or node_id.strip_edges() == last_encounter_node_id:
		return {}
	last_encounter_segment = current_segment
	last_encounter_node_id = node_id.strip_edges()
	return {
		"segment_index": current_segment,
		"node_id": node_id.strip_edges(),
		"action_index": action_index,
		"encounter_seed": _stable_hash("%d:%d:sweep_encounter" % [seed_value, current_segment]),
		"sweep_departure_action": int(current.get("next_move_action", action_index + 1)),
	}


func swept_window(node_id: String) -> Dictionary:
	var window := _dictionary(swept_windows_by_node.get(node_id.strip_edges(), {}))
	if window.is_empty() or action_index < int(window.get("start_action", 0)) or action_index >= int(window.get("end_action", 0)):
		return {}
	var result := window.duplicate(true)
	result["remaining_actions"] = maxi(0, int(window.get("end_action", action_index)) - action_index)
	result["security_strictness_band_delta"] = -1
	result["cheat_window_open"] = true
	result["pusher_alarm_tolerance_band_delta"] = 1
	return result


# Narrow landed-consumer seam: deterministically rewrites future segments along
# the graph toward one eligible target. Current/past segments never move.
func request_reroute_toward(candidate_ids: Array, request_token: String) -> Dictionary:
	var current := status()
	var request := {
		"token": request_token.strip_edges(),
		"requested_action": action_index,
		"from_node_id": str(current.get("current_node_id", "")),
		"target_node_id": "",
		"path": [],
		"applied_segment_indices": [],
		"applied": false,
	}
	if disabled or not bool(current.get("active", false)) or segment_index + 1 >= segments.size():
		reroute_history.append(request)
		return request.duplicate(true)
	var resolved_candidates: Array = []
	for candidate_value in candidate_ids:
		var candidate := str(candidate_value).strip_edges()
		for node_id_value in _node_metadata.keys():
			var node_id := str(node_id_value)
			var metadata := _dictionary(_node_metadata.get(node_id, {}))
			if node_id == candidate or str(metadata.get("archetype_id", "")) == candidate:
				if not resolved_candidates.has(node_id) and node_id != str(current.get("current_node_id", "")):
					resolved_candidates.append(node_id)
	resolved_candidates.sort()
	if resolved_candidates.is_empty():
		reroute_history.append(request)
		return request.duplicate(true)
	var token := request_token.strip_edges()
	var target := str(resolved_candidates[_stable_hash("%d:%s:numbers_reroute" % [seed_value, token]) % resolved_candidates.size()])
	var path := _shortest_path(str(current.get("current_node_id", "")), target)
	request["target_node_id"] = target
	request["path"] = path.duplicate()
	if path.size() < 2:
		reroute_history.append(request)
		return request.duplicate(true)
	var applied_indices: Array = []
	for path_index in range(1, path.size()):
		var future_index := segment_index + path_index
		if future_index >= segments.size():
			break
		var segment := _dictionary(segments[future_index]).duplicate(true)
		segment["node_id"] = str(path[path_index])
		segment["reroute_token"] = token
		segments[future_index] = segment
		applied_indices.append(future_index)
	request["applied_segment_indices"] = applied_indices
	request["applied"] = not applied_indices.is_empty()
	reroute_history.append(request)
	return request.duplicate(true)


func scenario_pressure_multiplier(node_id: String, scenario_id: String, tags: Array) -> float:
	if GRAND_CASINO_IDS.has(node_id) or not is_adjacent(node_id):
		return 1.0
	var pressure := _dictionary(config.get("adjacent_scenario_pressure", {}))
	var multiplier := 1.0
	var by_id := _dictionary(pressure.get("scenario_weight_by_id", {}))
	multiplier *= float(by_id.get(scenario_id, 1.0))
	var by_tag := _dictionary(pressure.get("scenario_weight_by_tag", {}))
	for tag_value in tags:
		multiplier *= float(by_tag.get(str(tag_value), 1.0))
	return maxf(0.0, multiplier)


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"configured": configured,
		"disabled": disabled,
		"start_action": start_action,
		"end_action": end_action,
		"segments": segments.duplicate(true),
		"segment_index": segment_index,
		"swept_windows_by_node": swept_windows_by_node.duplicate(true),
		"personal_marker": personal_marker.duplicate(true),
		"last_encounter_segment": last_encounter_segment,
		"last_encounter_node_id": last_encounter_node_id,
		"last_adjacent_sighting_segment": last_adjacent_sighting_segment,
		"config": config.duplicate(true),
		"reroute_history": reroute_history.duplicate(true),
	}


func restore(source: Dictionary, p_seed_value: int, source_config: Dictionary = {}) -> bool:
	reset(p_seed_value, source_config)
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		disable(p_seed_value, source_config)
		return false
	seed_value = maxi(1, int(source.get("seed_value", p_seed_value)))
	action_index = maxi(0, int(source.get("action_index", 0)))
	configured = bool(source.get("configured", false))
	disabled = bool(source.get("disabled", false))
	start_action = maxi(0, int(source.get("start_action", 0)))
	end_action = maxi(start_action, int(source.get("end_action", start_action)))
	segments = _dictionary_array(source.get("segments", []))
	segment_index = int(source.get("segment_index", -1))
	swept_windows_by_node = _dictionary(source.get("swept_windows_by_node", {})).duplicate(true)
	personal_marker = _dictionary(source.get("personal_marker", {})).duplicate(true)
	last_encounter_segment = int(source.get("last_encounter_segment", -1))
	last_encounter_node_id = str(source.get("last_encounter_node_id", ""))
	last_adjacent_sighting_segment = int(source.get("last_adjacent_sighting_segment", -1))
	config = _dictionary(source.get("config", source_config)).duplicate(true)
	reroute_history = _dictionary_array(source.get("reroute_history", []))
	_sync_segment_index()
	_prune_windows()
	return true


func align_restored_action_index(restored_action_index: int) -> void:
	action_index = maxi(0, restored_action_index)
	_sync_segment_index()
	for node_id_value in swept_windows_by_node.keys():
		var node_id := str(node_id_value)
		var window := _dictionary(swept_windows_by_node.get(node_id, {}))
		if window.is_empty() or action_index < int(window.get("start_action", action_index)) or action_index >= int(window.get("end_action", action_index)):
			swept_windows_by_node.erase(node_id)


func _generate_segments() -> void:
	segments = []
	var eligible := _eligible_node_ids()
	if eligible.is_empty():
		return
	var root_rng := RngStream.new()
	root_rng.configure(seed_value, seed_value)
	var rng := root_rng.fork("police_sweep_track")
	var tier_one: Array = []
	for node_id in eligible:
		if int(_dictionary(_node_metadata.get(node_id, {})).get("tier", 1)) == 1:
			tier_one.append(node_id)
	var current_node := str(rng.pick(tier_one if not tier_one.is_empty() else eligible, eligible[0]))
	var dwell_range := _int_range(config.get("dwell_actions", [3, 6]), 3, 6)
	var cursor := start_action
	var index := 0
	while cursor < end_action:
		var dwell := rng.randi_range(int(dwell_range[0]), int(dwell_range[1]))
		var segment_end := mini(end_action, cursor + maxi(1, dwell))
		segments.append({
			"node_id": current_node,
			"start_action": cursor,
			"end_action": segment_end,
			"dwell_actions": segment_end - cursor,
		})
		cursor = segment_end
		if cursor >= end_action:
			break
		current_node = _next_node(current_node, 2 if index % 2 == 0 else 1, eligible, rng)
		index += 1


func _next_node(current_node: String, preferred_tier: int, eligible: Array, rng: RngStream) -> String:
	var neighbors := _string_array(_neighbors_by_node.get(current_node, []))
	var allowed: Array = []
	var preferred: Array = []
	for node_id in neighbors:
		if not eligible.has(node_id):
			continue
		allowed.append(node_id)
		if int(_dictionary(_node_metadata.get(node_id, {})).get("tier", 1)) == preferred_tier:
			preferred.append(node_id)
	var candidates := preferred if not preferred.is_empty() else allowed
	if candidates.is_empty():
		return current_node
	candidates.sort()
	return str(rng.pick(candidates, current_node))


func _sync_segment_index() -> void:
	if segments.is_empty() or action_index < start_action:
		segment_index = -1
		return
	if action_index >= end_action:
		segment_index = segments.size()
		return
	if segment_index < 0:
		segment_index = 0
	while segment_index + 1 < segments.size() and action_index >= int((segments[segment_index] as Dictionary).get("end_action", end_action)):
		segment_index += 1
	while segment_index > 0 and action_index < int((segments[segment_index] as Dictionary).get("start_action", start_action)):
		segment_index -= 1


func _index_world(map_data: Dictionary) -> void:
	_node_metadata = {}
	_neighbors_by_node = {}
	for node_value in _dictionary_array(map_data.get("nodes", [])):
		var node_id := str(node_value.get("id", node_value.get("archetype_id", ""))).strip_edges()
		if node_id.is_empty():
			continue
		_node_metadata[node_id] = {
			"id": node_id,
			"archetype_id": str(node_value.get("archetype_id", node_id)),
			"kind": str(node_value.get("kind", "")),
			"tier": maxi(1, int(node_value.get("tier", 1))),
		}
		_neighbors_by_node[node_id] = []
	for edge_value in _dictionary_array(map_data.get("edges", [])):
		var a := str(edge_value.get("a", "")).strip_edges()
		var b := str(edge_value.get("b", "")).strip_edges()
		if not _node_metadata.has(a) or not _node_metadata.has(b) or a == b:
			continue
		var a_neighbors := _string_array(_neighbors_by_node.get(a, []))
		var b_neighbors := _string_array(_neighbors_by_node.get(b, []))
		if not a_neighbors.has(b):
			a_neighbors.append(b)
		if not b_neighbors.has(a):
			b_neighbors.append(a)
		a_neighbors.sort()
		b_neighbors.sort()
		_neighbors_by_node[a] = a_neighbors
		_neighbors_by_node[b] = b_neighbors


func _eligible_node_ids() -> Array:
	var ids: Array = []
	for node_id_value in _node_metadata.keys():
		var node_id := str(node_id_value)
		var metadata := _dictionary(_node_metadata.get(node_id, {}))
		var kind := str(metadata.get("kind", "")).strip_edges().to_lower()
		if GRAND_CASINO_IDS.has(node_id) or node_id.begins_with("grand_casino") or kind == "boss":
			continue
		ids.append(node_id)
	ids.sort()
	return ids


func _prune_windows() -> void:
	for node_id_value in swept_windows_by_node.keys():
		var node_id := str(node_id_value)
		var window := _dictionary(swept_windows_by_node.get(node_id, {}))
		if window.is_empty() or action_index >= int(window.get("end_action", action_index)):
			swept_windows_by_node.erase(node_id)


func _shortest_path(start_node: String, target_node: String) -> Array:
	if start_node.is_empty() or target_node.is_empty() or not _node_metadata.has(start_node) or not _node_metadata.has(target_node):
		return []
	if start_node == target_node:
		return [start_node]
	var queue: Array = [start_node]
	var previous := {start_node: ""}
	while not queue.is_empty():
		var node_id := str(queue.pop_front())
		var neighbors := _string_array(_neighbors_by_node.get(node_id, []))
		neighbors.sort()
		for neighbor_value in neighbors:
			var neighbor := str(neighbor_value)
			if previous.has(neighbor):
				continue
			previous[neighbor] = node_id
			if neighbor == target_node:
				var path: Array = [target_node]
				var cursor := target_node
				while cursor != start_node:
					cursor = str(previous.get(cursor, ""))
					if cursor.is_empty():
						return []
					path.push_front(cursor)
				return path
			queue.append(neighbor)
	return []


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) == TYPE_DICTIONARY:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result


static func _int_range(value: Variant, fallback_min: int, fallback_max: int) -> Array:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		var first := int((value as Array)[0])
		var second := int((value as Array)[1])
		return [mini(first, second), maxi(first, second)]
	return [mini(fallback_min, fallback_max), maxi(fallback_min, fallback_max)]


static func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return maxi(1, hash_value)
