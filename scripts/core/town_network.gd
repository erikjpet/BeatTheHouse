class_name TownNetwork
extends RefCounted

const RUMORS_PATH := "res://data/town/rumors.json"
const ITINERARIES_PATH := "res://data/town/itineraries.json"
const REPUTATION_PATH := "res://data/town/reputation.json"
const CHARACTERS_PATH := "res://data/characters/characters.json"
const SCHEMA_VERSION := 1
const DEFAULT_HORIZON := 240
const RUMOR_CLASS_SCENARIO := "scenario"
const RUMOR_CLASS_CONDITION := "town_condition"
const RUMOR_CLASS_PUSHER := "pusher_pile"
const RUMOR_CLASS_NUMBERS := "numbers_whisper"
const RUMOR_CLASS_SWEEP := "sweep_sighting"

static var _rumor_data_cache: Dictionary = {}
static var _itinerary_data_cache: Dictionary = {}
static var _reputation_data_cache: Dictionary = {}
static var _character_data_cache: Array = []

var seed_value: int = 1
var action_index: int = 0
var node_metadata: Dictionary = {}
var edges: Array = []
var itinerary_schedules: Dictionary = {}
var rumor_registry: Dictionary = {}
var heard_by_node: Dictionary = {}
var seeded_scenarios_by_node: Dictionary = {}
var seeded_scenario_definitions_by_node: Dictionary = {}
var reputation_incidents: Array = []
var reputation_type_registry: Dictionary = {}
var reputation_sequence: int = 0


func generate(p_seed_value: int) -> void:
	seed_value = maxi(1, p_seed_value)
	action_index = 0
	node_metadata = {}
	edges = []
	itinerary_schedules = {}
	rumor_registry = {}
	heard_by_node = {}
	seeded_scenarios_by_node = {}
	seeded_scenario_definitions_by_node = {}
	reputation_incidents = []
	reputation_sequence = 0
	reputation_type_registry = _dictionary(_reputation_data().get("incident_types", {})).duplicate(true)


func restore(source: Dictionary, p_seed_value: int) -> bool:
	generate(p_seed_value)
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	seed_value = maxi(1, int(source.get("seed_value", p_seed_value)))
	action_index = maxi(0, int(source.get("action_index", 0)))
	node_metadata = _dictionary(source.get("node_metadata", {})).duplicate(true)
	edges = _dictionary_array(source.get("edges", []))
	itinerary_schedules = _dictionary(source.get("itinerary_schedules", {})).duplicate(true)
	rumor_registry = _normalize_fact_registry(source.get("rumor_registry", {}))
	heard_by_node = _dictionary(source.get("heard_by_node", {})).duplicate(true)
	seeded_scenarios_by_node = _dictionary(source.get("seeded_scenarios_by_node", {})).duplicate(true)
	seeded_scenario_definitions_by_node = _dictionary(source.get("seeded_scenario_definitions_by_node", {})).duplicate(true)
	reputation_incidents = _dictionary_array(source.get("reputation_incidents", []))
	reputation_type_registry = _dictionary(source.get("reputation_type_registry", reputation_type_registry)).duplicate(true)
	reputation_sequence = maxi(0, int(source.get("reputation_sequence", reputation_incidents.size())))
	_prune_expired_incidents()
	return true


func configure_world(map_data: Dictionary) -> void:
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return
	var next_metadata: Dictionary = {}
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", node.get("archetype_id", ""))).strip_edges()
		if node_id.is_empty():
			continue
		next_metadata[node_id] = {
			"id": node_id,
			"label": str(node.get("label", node_id.replace("_", " ").capitalize())),
			"kind": str(node.get("kind", "")),
			"tier": int(node.get("tier", 1)),
		}
	node_metadata = next_metadata
	edges = _normalize_edges(map_data.get("edges", []))
	if itinerary_schedules.is_empty():
		_generate_itineraries()


func advance_to(next_action_index: int) -> void:
	action_index = maxi(action_index, next_action_index)
	_prune_expired_incidents()


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"node_metadata": node_metadata.duplicate(true),
		"edges": edges.duplicate(true),
		"itinerary_schedules": itinerary_schedules.duplicate(true),
		"rumor_registry": rumor_registry.duplicate(true),
		"heard_by_node": heard_by_node.duplicate(true),
		"seeded_scenarios_by_node": seeded_scenarios_by_node.duplicate(true),
		"seeded_scenario_definitions_by_node": seeded_scenario_definitions_by_node.duplicate(true),
		"reputation_incidents": reputation_incidents.duplicate(true),
		"reputation_type_registry": reputation_type_registry.duplicate(true),
		"reputation_sequence": reputation_sequence,
	}


func seed_scenario_for_node(node_id: String, scenario: Dictionary) -> bool:
	var clean_node := node_id.strip_edges()
	var scenario_id := str(scenario.get("id", "")).strip_edges()
	if clean_node.is_empty() or scenario_id.is_empty():
		return false
	var public_scenario := {
		"id": scenario_id,
		"archetype_id": str(scenario.get("archetype_id", clean_node)),
		"display_name": str(scenario.get("display_name", scenario_id.replace("_", " ").capitalize())),
		"tags": _string_array(scenario.get("tags", [])),
	}
	seeded_scenarios_by_node[clean_node] = public_scenario
	# Cache the canonical selector output, not a later content-library lookup.
	# Challenge pins can preserve identity while intentionally suppressing the
	# authored mutation/phase payload for controlled tutorial rooms.
	seeded_scenario_definitions_by_node[clean_node] = scenario.duplicate(true)
	return register_rumor_fact(RUMOR_CLASS_SCENARIO, "scenario:%s" % clean_node, {
		"target_node_id": clean_node,
		"source_id": scenario_id,
		"scenario_id": scenario_id,
		"scenario_name": str(public_scenario.get("display_name", scenario_id)),
	})


func seeded_scenario_for_node(node_id: String) -> Dictionary:
	return _dictionary(seeded_scenarios_by_node.get(node_id.strip_edges(), {})).duplicate(true)


func seeded_scenario_definition_for_node(node_id: String) -> Dictionary:
	return _seeded_scenario_definition_for_node_readonly(node_id).duplicate(true)


func _seeded_scenario_definition_for_node_readonly(node_id: String) -> Dictionary:
	return _dictionary(seeded_scenario_definitions_by_node.get(node_id.strip_edges(), {}))


func register_rumor_fact(fact_class: String, fact_id: String, payload: Dictionary) -> bool:
	var clean_class := fact_class.strip_edges().to_lower()
	var clean_id := fact_id.strip_edges()
	if clean_class.is_empty() or clean_id.is_empty() or not _rumor_fact_classes().has(clean_class):
		return false
	var target_node_id := str(payload.get("target_node_id", "")).strip_edges()
	var fact := {
		"id": clean_id,
		"class": clean_class,
		"target_node_id": target_node_id,
		"source_id": str(payload.get("source_id", clean_id)).strip_edges(),
		"payload": payload.duplicate(true),
		"registered_action": action_index,
	}
	rumor_registry[clean_id] = fact
	return true


func remove_rumor_facts(fact_class: String) -> void:
	var clean_class := fact_class.strip_edges().to_lower()
	for fact_id_value in rumor_registry.keys():
		var fact_id := str(fact_id_value)
		var fact := _dictionary(rumor_registry.get(fact_id, {}))
		if str(fact.get("class", "")) == clean_class:
			rumor_registry.erase(fact_id)


func rumor_fact(fact_id: String) -> Dictionary:
	return _dictionary(rumor_registry.get(fact_id.strip_edges(), {})).duplicate(true)


func rumor_facts(fact_class: String = "") -> Array:
	var clean_class := fact_class.strip_edges().to_lower()
	var result: Array = []
	var ids: Array = rumor_registry.keys()
	ids.sort()
	for fact_id_value in ids:
		var fact := _dictionary(rumor_registry.get(fact_id_value, {}))
		if not clean_class.is_empty() and str(fact.get("class", "")) != clean_class:
			continue
		result.append(fact.duplicate(true))
	return result


func rumors_for_venue(node_id: String, speaker_side: String, count: int = 1, rng: RngStream = null) -> Array:
	var clean_node := node_id.strip_edges()
	var candidates: Array = []
	for fact in rumor_facts():
		var target_node_id := str(fact.get("target_node_id", ""))
		if target_node_id.is_empty() or target_node_id == clean_node or heard_by_node.has(target_node_id):
			continue
		if _rumor_fact_is_true(fact):
			candidates.append(fact)
	if candidates.is_empty() or count <= 0:
		return []
	var selection_rng := rng
	if selection_rng == null:
		selection_rng = RngStream.new()
		selection_rng.configure(seed_value, seed_value)
		selection_rng = selection_rng.fork("town_rumor:%s:%d" % [clean_node, action_index])
	var selected := selection_rng.pick_many(candidates, mini(count, candidates.size()))
	var rendered: Array = []
	for fact_value in selected:
		if typeof(fact_value) != TYPE_DICTIONARY:
			continue
		var rumor := _render_rumor(fact_value as Dictionary, speaker_side, selection_rng)
		if rumor.is_empty():
			continue
		assert(_rumor_trace_is_live(rumor), "Generated rumor lost its live truth source: %s" % JSON.stringify(rumor))
		rendered.append(rumor)
	return rendered


func hear_rumor(rumor_id: String) -> Dictionary:
	var clean_id := rumor_id.strip_edges()
	if clean_id.is_empty():
		return {}
	for node_id_value in heard_by_node.keys():
		var heard := _dictionary(heard_by_node.get(node_id_value, {}))
		if str(heard.get("id", "")) == clean_id:
			return heard.duplicate(true)
	var fact_id := clean_id.trim_prefix("rumor:")
	var fact := rumor_fact(fact_id)
	if fact.is_empty() or not _rumor_fact_is_true(fact):
		return {}
	var rumor := _render_rumor(fact, "neutral", null)
	if rumor.is_empty():
		return {}
	var target_node_id := str(rumor.get("target_node_id", ""))
	heard_by_node[target_node_id] = rumor.duplicate(true)
	return rumor


func hear_rendered_rumor(rumor: Dictionary) -> Dictionary:
	if rumor.is_empty() or not _rumor_trace_is_live(rumor):
		return {}
	var target_node_id := str(rumor.get("target_node_id", "")).strip_edges()
	if target_node_id.is_empty():
		return {}
	heard_by_node[target_node_id] = rumor.duplicate(true)
	return rumor.duplicate(true)


func heard_rumor_for_node(node_id: String) -> Dictionary:
	return _dictionary(heard_by_node.get(node_id.strip_edges(), {})).duplicate(true)


func rumor_trace_is_live(rumor: Dictionary) -> bool:
	return _rumor_trace_is_live(rumor)


func traveler_node(character_id: String) -> String:
	return str(traveler_state(character_id).get("node_id", ""))


func travelers_at(node_id: String) -> Array:
	var clean_node := node_id.strip_edges()
	var result: Array = []
	var character_ids: Array = itinerary_schedules.keys()
	character_ids.sort()
	for character_id_value in character_ids:
		var state := traveler_state(str(character_id_value))
		if str(state.get("node_id", "")) == clean_node:
			result.append(str(character_id_value))
	return result


func traveler_state(character_id: String) -> Dictionary:
	var clean_id := character_id.strip_edges()
	var schedule_value: Variant = itinerary_schedules.get(clean_id, [])
	if typeof(schedule_value) != TYPE_ARRAY:
		return {}
	var schedule: Array = schedule_value
	for index in range(schedule.size()):
		if typeof(schedule[index]) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = schedule[index]
		if action_index < int(segment.get("start_action", 0)) or action_index >= int(segment.get("end_action", action_index + 1)):
			continue
		return {
			"character_id": clean_id,
			"node_id": str(segment.get("node_id", "")),
			"previous_node_id": str(schedule[index - 1].get("node_id", "")) if index > 0 and typeof(schedule[index - 1]) == TYPE_DICTIONARY else "",
			"arrived_action": int(segment.get("start_action", 0)),
			"depart_action": int(segment.get("end_action", 0)),
			"segment_index": index,
		}
	return {}


func traveler_context_line(character_id: String) -> String:
	var definition := _itinerary_definition(character_id)
	var line_key := str(definition.get("where_been_line_key", "")).strip_edges()
	var lines := _character_voice_lines(character_id, line_key) if not line_key.is_empty() else _string_array(definition.get("where_been_lines", []))
	var state := traveler_state(character_id)
	if lines.is_empty() or state.is_empty():
		return ""
	var index := _stable_hash("%s:%d" % [character_id, int(state.get("segment_index", 0))]) % lines.size()
	var line := str(lines[index])
	line = line.replace("{current_name}", _node_label(str(state.get("node_id", ""))))
	line = line.replace("{previous_name}", _node_label(str(state.get("previous_node_id", ""))))
	return line


func departed_traveler_modifier(node_id: String, character_id: String) -> Dictionary:
	var definition := _itinerary_definition(character_id)
	var modifier := _dictionary(definition.get("departed_modifier", {}))
	if modifier.is_empty():
		return {}
	var decay_actions := maxi(0, int(modifier.get("decay_actions", 0)))
	var schedule_value: Variant = itinerary_schedules.get(character_id, [])
	if typeof(schedule_value) != TYPE_ARRAY:
		return {}
	var best_departure := -1
	for segment_value in schedule_value as Array:
		if typeof(segment_value) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_value
		var departed_at := int(segment.get("end_action", 0))
		if str(segment.get("node_id", "")) != node_id or action_index < departed_at or action_index >= departed_at + decay_actions:
			continue
		best_departure = maxi(best_departure, departed_at)
	if best_departure < 0:
		return {}
	var result := modifier.duplicate(true)
	result["character_id"] = character_id
	result["node_id"] = node_id
	result["departed_action"] = best_departure
	result["remaining_actions"] = maxi(0, best_departure + decay_actions - action_index)
	return result


func register_reputation_incident_type(incident_type: String, definition: Dictionary) -> bool:
	var clean_type := incident_type.strip_edges().to_lower()
	if clean_type.is_empty() or definition.is_empty():
		return false
	reputation_type_registry[clean_type] = definition.duplicate(true)
	return true


func record_reputation_incident(incident_type: String, node_id: String, magnitude: float = 1.0, context: Dictionary = {}) -> Dictionary:
	var clean_type := incident_type.strip_edges().to_lower()
	var clean_node := node_id.strip_edges()
	var definition := _dictionary(reputation_type_registry.get(clean_type, {}))
	if clean_type.is_empty() or clean_node.is_empty() or definition.is_empty() or not node_metadata.has(clean_node):
		return {}
	reputation_sequence += 1
	var duration := maxi(1, int(definition.get("duration_actions", 16)))
	var incident := {
		"id": "reputation:%04d" % reputation_sequence,
		"type": clean_type,
		"source_node_id": clean_node,
		"magnitude": maxf(0.0, magnitude),
		"created_action": action_index,
		"expires_action": action_index + duration,
		"hop_distances": _hop_distances(clean_node, maxi(0, int(definition.get("max_hops", 3)))),
		"context": context.duplicate(true),
	}
	reputation_incidents.append(incident)
	var max_incidents := maxi(1, int(_reputation_data().get("max_incidents", 32)))
	if reputation_incidents.size() > max_incidents:
		reputation_incidents = reputation_incidents.slice(reputation_incidents.size() - max_incidents, reputation_incidents.size())
	return incident.duplicate(true)


func reputation_value(node_id: String, incident_type: String = "") -> float:
	var local := local_reputation(node_id)
	var clean_type := incident_type.strip_edges().to_lower()
	if clean_type.is_empty():
		return float(local.get("attention", 0.0))
	return float(_dictionary(local.get("values_by_type", {})).get(clean_type, 0.0))


func local_reputation(node_id: String) -> Dictionary:
	var clean_node := node_id.strip_edges()
	var values_by_type: Dictionary = {}
	var attention := 0.0
	for incident_value in reputation_incidents:
		if typeof(incident_value) != TYPE_DICTIONARY:
			continue
		var incident: Dictionary = incident_value
		if action_index >= int(incident.get("expires_action", action_index)):
			continue
		var distances := _dictionary(incident.get("hop_distances", {}))
		if not distances.has(clean_node):
			continue
		var distance := int(distances.get(clean_node, 999))
		var age := maxi(0, action_index - int(incident.get("created_action", action_index)))
		if distance > age + 1:
			continue
		var incident_type := str(incident.get("type", ""))
		var definition := _dictionary(reputation_type_registry.get(incident_type, {}))
		var decay := clampf(float(definition.get("hop_decay", 0.5)), 0.0, 1.0)
		var value := float(incident.get("magnitude", 1.0)) * pow(decay, distance)
		values_by_type[incident_type] = float(values_by_type.get(incident_type, 0.0)) + value
		attention += value * float(definition.get("attention", 0.0))
	var thresholds := _dictionary(_reputation_data().get("door_thresholds", {}))
	var door_delta := 0
	if attention >= float(thresholds.get("stricter_min", 0.75)):
		door_delta = 1
	elif attention <= float(thresholds.get("looser_max", -0.75)):
		door_delta = -1
	var staff_tone := "watchful" if attention > 0.1 else "warm" if attention < -0.1 else "neutral"
	var staff_lines := _string_array(_dictionary(_reputation_data().get("staff_lines", {})).get(staff_tone, []))
	var staff_line := ""
	if not staff_lines.is_empty():
		staff_line = str(staff_lines[_stable_hash("%s:%s:%d" % [clean_node, staff_tone, action_index]) % staff_lines.size()])
	var reaction := _rare_reaction(clean_node, attention)
	return {
		"node_id": clean_node,
		"values_by_type": values_by_type,
		"attention": attention,
		"door_strictness_delta": door_delta,
		"staff_tone": staff_tone,
		"staff_line": staff_line,
		"rare_reaction": reaction,
	}


func _generate_itineraries() -> void:
	itinerary_schedules = {}
	var traveler_definitions := _dictionary_array(_itinerary_data().get("travelers", []))
	for definition in traveler_definitions:
		var character_id := str(definition.get("character_id", "")).strip_edges()
		var allowed_nodes := _eligible_itinerary_nodes(definition)
		if character_id.is_empty() or allowed_nodes.is_empty():
			continue
		var root_rng := RngStream.new()
		root_rng.configure(seed_value, seed_value)
		var rng := root_rng.fork("town_itinerary:%s" % character_id)
		var dwell := _int_range(definition.get("dwell_actions", [4, 8]), 4, 8)
		var horizon := maxi(1, int(definition.get("schedule_actions", DEFAULT_HORIZON)))
		var schedule: Array = []
		var current_node := str(rng.pick(allowed_nodes, allowed_nodes[0]))
		var cursor := 0
		while cursor < horizon:
			var duration := rng.randi_range(int(dwell[0]), int(dwell[1]))
			var end_action := mini(horizon, cursor + maxi(1, duration))
			schedule.append({"node_id": current_node, "start_action": cursor, "end_action": end_action})
			cursor = end_action
			current_node = _next_itinerary_node(current_node, allowed_nodes, rng)
		itinerary_schedules[character_id] = schedule


func _eligible_itinerary_nodes(definition: Dictionary) -> Array:
	var configured := _string_array(definition.get("allowed_nodes", []))
	var result: Array = []
	for node_id in configured:
		if node_metadata.has(node_id):
			result.append(node_id)
	if not result.is_empty():
		return result
	var ids: Array = node_metadata.keys()
	ids.sort()
	return ids


func _next_itinerary_node(current_node: String, allowed_nodes: Array, rng: RngStream) -> String:
	var candidates: Array = []
	for neighbor in _neighbors(current_node):
		if allowed_nodes.has(neighbor) and neighbor != current_node:
			candidates.append(neighbor)
	if candidates.is_empty():
		for node_id in allowed_nodes:
			if node_id != current_node:
				candidates.append(node_id)
	return str(rng.pick(candidates, current_node))


func _render_rumor(fact: Dictionary, speaker_side: String, rng: RngStream) -> Dictionary:
	var fact_class := str(fact.get("class", ""))
	var templates_by_class := _dictionary(_dictionary(_rumor_data().get("templates", {})).get(fact_class, {}))
	var side := speaker_side.strip_edges().to_lower()
	if side.is_empty() or not templates_by_class.has(side):
		side = "neutral"
	var templates := _string_array(templates_by_class.get(side, templates_by_class.get("neutral", [])))
	if templates.is_empty():
		return {}
	var selection_rng := rng
	if selection_rng == null:
		selection_rng = RngStream.new()
		selection_rng.configure(seed_value, seed_value)
		selection_rng = selection_rng.fork("town_rumor_render:%s:%s" % [str(fact.get("id", "")), side])
	var template := str(selection_rng.pick(templates, templates[0]))
	var payload := _dictionary(fact.get("payload", {}))
	var target_node_id := str(fact.get("target_node_id", payload.get("target_node_id", "")))
	var replacements := {
		"target_name": _node_label(target_node_id),
		"scenario_name": str(payload.get("scenario_name", payload.get("scenario_id", "tonight's business"))),
		"condition_line": str(payload.get("condition_line", payload.get("display_name", "Something is moving across town."))),
		"fact_detail": str(payload.get("fact_detail", "word is moving")),
	}
	var line := template
	for key_value in replacements.keys():
		line = line.replace("{%s}" % str(key_value), str(replacements.get(key_value, "")))
	return {
		"id": "rumor:%s" % str(fact.get("id", "")),
		"fact_id": str(fact.get("id", "")),
		"class": fact_class,
		"target_node_id": target_node_id,
		"source_id": str(fact.get("source_id", "")),
		"speaker_side": side,
		"line": line,
		"truth_trace": {
			"fact_id": str(fact.get("id", "")),
			"class": fact_class,
			"source_id": str(fact.get("source_id", "")),
			"target_node_id": target_node_id,
		},
	}


func _rumor_trace_is_live(rumor: Dictionary) -> bool:
	var trace := _dictionary(rumor.get("truth_trace", {}))
	var fact := rumor_fact(str(trace.get("fact_id", rumor.get("fact_id", ""))))
	if fact.is_empty() or not _rumor_fact_is_true(fact):
		return false
	return str(trace.get("class", "")) == str(fact.get("class", "")) \
		and str(trace.get("source_id", "")) == str(fact.get("source_id", "")) \
		and str(trace.get("target_node_id", "")) == str(fact.get("target_node_id", ""))


func _rumor_fact_is_true(fact: Dictionary) -> bool:
	var fact_class := str(fact.get("class", ""))
	var payload := _dictionary(fact.get("payload", {}))
	match fact_class:
		RUMOR_CLASS_SCENARIO:
			var seeded := seeded_scenario_for_node(str(fact.get("target_node_id", "")))
			return not seeded.is_empty() and str(seeded.get("id", "")) == str(payload.get("scenario_id", fact.get("source_id", "")))
		RUMOR_CLASS_CONDITION:
			var starts := maxi(0, int(payload.get("start_action", 0)))
			var ends := maxi(starts + 1, int(payload.get("end_action", starts + 1)))
			return action_index < ends and starts <= action_index + maxi(1, int(payload.get("incoming_window_actions", 12)))
		_:
			return rumor_registry.has(str(fact.get("id", "")))


func _rare_reaction(node_id: String, attention: float) -> Dictionary:
	var config := _dictionary(_reputation_data().get("rare_reaction", {}))
	if absf(attention) < float(config.get("minimum_attention", 0.75)):
		return {}
	var chance := clampi(int(config.get("chance_percent", 12)), 0, 100)
	var roll := (_stable_hash("reputation_reaction:%s:%d" % [node_id, action_index]) % 100) + 1
	if roll > chance:
		return {}
	return {
		"id": "town_reputation_reaction",
		"tone": "watchful" if attention > 0.0 else "warm",
		"roll": roll,
		"chance_percent": chance,
	}


func _hop_distances(source_node_id: String, max_hops: int) -> Dictionary:
	var distances := {source_node_id: 0}
	var queue: Array = [source_node_id]
	var cursor := 0
	while cursor < queue.size():
		var node_id := str(queue[cursor])
		cursor += 1
		var distance := int(distances.get(node_id, 0))
		if distance >= max_hops:
			continue
		for neighbor in _neighbors(node_id):
			if distances.has(neighbor):
				continue
			distances[neighbor] = distance + 1
			queue.append(neighbor)
	return distances


func _neighbors(node_id: String) -> Array:
	var result: Array = []
	for edge in edges:
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		if a == node_id and not result.has(b):
			result.append(b)
		elif b == node_id and not result.has(a):
			result.append(a)
	result.sort()
	return result


func _prune_expired_incidents() -> void:
	var active: Array = []
	for incident_value in reputation_incidents:
		if typeof(incident_value) == TYPE_DICTIONARY and action_index < int((incident_value as Dictionary).get("expires_action", action_index)):
			active.append((incident_value as Dictionary).duplicate(true))
	reputation_incidents = active


func _itinerary_definition(character_id: String) -> Dictionary:
	for definition in _dictionary_array(_itinerary_data().get("travelers", [])):
		if str(definition.get("character_id", "")) == character_id:
			return definition
	return {}


func _node_label(node_id: String) -> String:
	return str(_dictionary(node_metadata.get(node_id, {})).get("label", node_id.replace("_", " ").capitalize()))


func _rumor_fact_classes() -> Array:
	return _string_array(_rumor_data().get("fact_classes", []))


func _normalize_fact_registry(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dictionary(value)
	for fact_id_value in source.keys():
		var fact := _dictionary(source.get(fact_id_value, {}))
		if not fact.is_empty():
			result[str(fact_id_value)] = fact.duplicate(true)
	return result


func _normalize_edges(value: Variant) -> Array:
	var result: Array = []
	for edge in _dictionary_array(value):
		var a := str(edge.get("a", "")).strip_edges()
		var b := str(edge.get("b", "")).strip_edges()
		if a.is_empty() or b.is_empty() or not node_metadata.has(a) or not node_metadata.has(b):
			continue
		result.append({"a": a, "b": b})
	return result


static func _rumor_data() -> Dictionary:
	if _rumor_data_cache.is_empty():
		_rumor_data_cache = _load_dictionary(RUMORS_PATH)
	return _rumor_data_cache


static func _itinerary_data() -> Dictionary:
	if _itinerary_data_cache.is_empty():
		_itinerary_data_cache = _load_dictionary(ITINERARIES_PATH)
	return _itinerary_data_cache


static func _reputation_data() -> Dictionary:
	if _reputation_data_cache.is_empty():
		_reputation_data_cache = _load_dictionary(REPUTATION_PATH)
	return _reputation_data_cache


static func _character_voice_lines(character_id: String, line_key: String) -> Array:
	if _character_data_cache.is_empty():
		_character_data_cache = _load_array(CHARACTERS_PATH)
	for character_value in _character_data_cache:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue
		var character: Dictionary = character_value
		if str(character.get("id", "")) != character_id:
			continue
		var voice := _dictionary(character.get("voice", {}))
		return _string_array(_dictionary(voice.get("lines", {})).get(line_key, []))
	return []


static func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty():
		parsed = (parsed as Array)[0]
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


static func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


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
