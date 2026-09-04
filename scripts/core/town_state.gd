class_name TownState
extends RefCounted

const CONDITIONS_PATH := "res://data/town/conditions.json"
const TownNetworkScript := preload("res://scripts/core/town_network.gd")
const PoliceSweepModelScript := preload("res://scripts/core/police_sweep_model.gd")
const SCHEMA_VERSION := 3
const DEFAULT_TURN_HORIZON := 240
const WEATHER_IDS := ["clear", "rain", "fog", "storm"]
const DAY_TYPE_IDS := ["payday", "midweek"]
const HAPPENING_IDS := ["fight_night", "festival_weekend", "rolling_blackout", "police_sweep"]
const RISK_BANDS := ["low", "medium", "high"]
const VAULT_PROGRESSIVE_RUMOR_CLASS := "vault_progressive"

static var _conditions_cache: Dictionary = {}

var seed_value: int = 1
var action_index: int = 0
var turn_horizon: int = DEFAULT_TURN_HORIZON
var weather_schedule: Array = []
var calendar_cycle: Array = []
var calendar_offset_actions: int = 0
var happenings: Array = []
var living_world: TownNetwork
var police_sweep: PoliceSweepModel
var _host_capability: RefCounted
var progressive_meters: Dictionary = {}

var _conditions: Dictionary = {}
var _weather_by_action: PackedStringArray = PackedStringArray()
var _weather_segment_by_action: PackedInt32Array = PackedInt32Array()
var _weather_definition_by_id: Dictionary = {}
var _happening_definition_by_id: Dictionary = {}
var _weather_id := "clear"
var _day_type_id := "midweek"
var _active_happening_ids: Array = []
var _active_happening_lookup: Dictionary = {}
var _active_town_flags: Dictionary = {}
var _scenario_weight_by_tag: Dictionary = {}
var _scenario_weight_by_archetype: Dictionary = {}
var _scenario_weight_by_id: Dictionary = {}
var _travel_profile: Dictionary = {}
var _music_modifier_profile: Dictionary = {}
var _economic_modifier_profile: Dictionary = {}


static func conditions() -> Dictionary:
	if not _conditions_cache.is_empty():
		return _conditions_cache
	if not FileAccess.file_exists(CONDITIONS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONDITIONS_PATH))
	if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty():
		parsed = (parsed as Array)[0]
	if typeof(parsed) == TYPE_DICTIONARY:
		_conditions_cache = parsed as Dictionary
	return _conditions_cache


func generate(p_seed_value: int, source_conditions: Dictionary = {}) -> void:
	seed_value = maxi(1, p_seed_value)
	action_index = 0
	_conditions = source_conditions if not source_conditions.is_empty() else conditions()
	turn_horizon = maxi(1, int(_conditions.get("turn_horizon", DEFAULT_TURN_HORIZON)))
	_index_definitions()
	var root_rng := RngStream.new()
	root_rng.configure(seed_value, seed_value)
	_generate_weather_schedule(root_rng.fork("town_weather"))
	_generate_calendar(root_rng.fork("town_calendar"))
	_generate_happenings(root_rng.fork("town_happenings"))
	progressive_meters = {}
	living_world = TownNetworkScript.new()
	living_world.generate(seed_value)
	police_sweep = PoliceSweepModelScript.new()
	police_sweep.reset(seed_value, _police_sweep_config())
	if _host_capability != null: police_sweep.bind_host_capability(_host_capability)
	_refresh_current_profiles()


func restore(source: Dictionary, p_seed_value: int, source_conditions: Dictionary = {}) -> bool:
	var source_schema := int(source.get("schema_version", 0))
	if source_schema < 1 or source_schema > SCHEMA_VERSION:
		generate(p_seed_value, source_conditions)
		return false
	seed_value = maxi(1, int(source.get("seed_value", p_seed_value)))
	action_index = maxi(0, int(source.get("action_index", 0)))
	turn_horizon = maxi(1, int(source.get("turn_horizon", DEFAULT_TURN_HORIZON)))
	_conditions = source_conditions if not source_conditions.is_empty() else conditions()
	weather_schedule = _dictionary_array(source.get("weather_schedule", []))
	calendar_cycle = _dictionary_array(source.get("calendar_cycle", []))
	calendar_offset_actions = maxi(0, int(source.get("calendar_offset_actions", 0)))
	happenings = _dictionary_array(source.get("happenings", []))
	progressive_meters = _dictionary(source.get("progressive_meters", {})).duplicate(true) if source_schema >= 3 else {}
	living_world = TownNetworkScript.new()
	var living_world_value: Variant = source.get("living_world", {})
	if typeof(living_world_value) == TYPE_DICTIONARY and not (living_world_value as Dictionary).is_empty():
		living_world.restore(living_world_value as Dictionary, seed_value)
	else:
		living_world.generate(seed_value)
		living_world.advance_to(action_index)
	police_sweep = PoliceSweepModelScript.new()
	if _host_capability != null: police_sweep.bind_host_capability(_host_capability)
	var sweep_value: Variant = source.get("police_sweep", {})
	if source_schema >= 2 and typeof(sweep_value) == TYPE_DICTIONARY and not (sweep_value as Dictionary).is_empty():
		police_sweep.restore(sweep_value as Dictionary, seed_value, _police_sweep_config())
	else:
		police_sweep.disable(seed_value, _police_sweep_config())
	police_sweep.align_restored_action_index(action_index)
	_index_definitions()
	if weather_schedule.is_empty() or calendar_cycle.is_empty():
		generate(p_seed_value, source_conditions)
		return false
	_rebuild_weather_index()
	_refresh_current_profiles()
	return true


func advance_actions(amount: int = 1) -> void:
	if amount <= 0:
		return
	action_index = maxi(0, action_index + amount)
	if living_world != null:
		living_world.advance_to(action_index)
	if police_sweep != null:
		police_sweep.advance_to(action_index)
	_advance_progressive_meters(amount)
	_refresh_current_profiles()
	_sync_condition_rumor_facts()
	_sync_sweep_rumor_facts()
	_sync_progressive_rumor_facts()


func register_progressive_meter(meter_id: String, payload: Dictionary) -> Dictionary:
	var clean_id := meter_id.strip_edges()
	var node_id := str(payload.get("target_node_id", "")).strip_edges()
	if clean_id.is_empty() or node_id.is_empty():
		return {}
	if not progressive_meters.has(clean_id):
		var floor_value := maxi(0, int(payload.get("floor", 0)))
		progressive_meters[clean_id] = {
			"id": clean_id,
			"target_node_id": node_id,
			"target_name": str(payload.get("target_name", node_id)),
			"value": maxi(floor_value, int(payload.get("initial_value", floor_value))),
			"floor": floor_value,
			"growth_per_action": maxi(0, int(payload.get("growth_per_action", 0))),
			"crowded": bool(payload.get("crowded", false)),
			"registered_action": action_index,
		}
	_sync_progressive_rumor_fact(clean_id)
	return progressive_meter(clean_id)


func progressive_meter(meter_id: String) -> Dictionary:
	return _dictionary(progressive_meters.get(meter_id.strip_edges(), {})).duplicate(true)


func set_progressive_meter_value(meter_id: String, value: int) -> Dictionary:
	var clean_id := meter_id.strip_edges()
	var meter := _dictionary(progressive_meters.get(clean_id, {}))
	if meter.is_empty():
		return {}
	meter["value"] = maxi(int(meter.get("floor", 0)), value)
	progressive_meters[clean_id] = meter
	_sync_progressive_rumor_fact(clean_id)
	return meter.duplicate(true)


func _advance_progressive_meters(amount: int) -> void:
	for meter_id_value in progressive_meters.keys():
		var meter_id := str(meter_id_value)
		var meter := _dictionary(progressive_meters.get(meter_id, {}))
		meter["value"] = maxi(int(meter.get("floor", 0)), int(meter.get("value", 0)) + maxi(0, int(meter.get("growth_per_action", 0))) * amount)
		progressive_meters[meter_id] = meter


func configure_world(map_data: Dictionary, synchronize_rumor_facts: bool = true) -> void:
	if living_world == null:
		living_world = TownNetworkScript.new()
		living_world.generate(seed_value)
	living_world.configure_world(map_data)
	if police_sweep == null:
		police_sweep = PoliceSweepModelScript.new()
		police_sweep.reset(seed_value, _police_sweep_config())
	police_sweep.configure_world(map_data, _police_sweep_happening(), _police_sweep_config(), action_index)
	_refresh_current_profiles()
	if synchronize_rumor_facts:
		_sync_condition_rumor_facts()
		_sync_sweep_rumor_facts()


func disable_police_sweep_for_legacy_save() -> void:
	if police_sweep == null:
		police_sweep = PoliceSweepModelScript.new()
	police_sweep.disable(seed_value, _police_sweep_config())
	var retained: Array = []
	for happening in happenings:
		if str(happening.get("id", "")) != "police_sweep":
			retained.append(happening)
	happenings = retained
	_refresh_current_profiles()
	_sync_sweep_rumor_facts()


func bind_host_capability(capability: RefCounted) -> bool:
	if capability == null or _host_capability != null:
		return false
	_host_capability = capability
	if police_sweep != null:
		police_sweep.bind_host_capability(capability)
	return true


func sweep_status(host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	return police_sweep.intel_status(host_capability, intel_enabled) if police_sweep != null else {}


func sweep_internal_status() -> Dictionary:
	return police_sweep.status() if police_sweep != null else {}


func sweep_map_marker(host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	return police_sweep.map_marker(host_capability, intel_enabled) if police_sweep != null else {}


func report_sweep_intel_at_boundary(host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	return police_sweep.report_intel_at_boundary(host_capability, intel_enabled) if police_sweep != null else {}


func record_sweep_sighting(source: String = "direct", host_capability: Variant = null) -> Dictionary:
	return police_sweep.record_personal_sighting(source, host_capability) if police_sweep != null else {}


func sweep_is_at(node_id: String) -> bool:
	return police_sweep != null and police_sweep.is_at(node_id)


func sweep_is_adjacent(node_id: String) -> bool:
	return police_sweep != null and police_sweep.is_adjacent(node_id)


func sweep_adjacent_sighting_due(node_id: String) -> bool:
	return police_sweep != null and police_sweep.adjacent_sighting_due(node_id)


func claim_sweep_encounter(node_id: String, host_capability: Variant = null) -> Dictionary:
	return police_sweep.claim_encounter(node_id, host_capability) if police_sweep != null else {}


func swept_window(node_id: String) -> Dictionary:
	return police_sweep.swept_window(node_id) if police_sweep != null else {}


func request_sweep_reroute(candidate_node_ids: Array, request_token: String) -> Dictionary:
	if police_sweep == null:
		return {}
	var result := police_sweep.request_reroute_toward(candidate_node_ids, request_token)
	_sync_sweep_rumor_facts()
	return result


func sweep_encounter_config() -> Dictionary:
	return _dictionary(_police_sweep_config().get("encounter", {})).duplicate(true)


func seed_scenario_for_node(node_id: String, scenario: Dictionary) -> bool:
	return living_world != null and living_world.seed_scenario_for_node(node_id, scenario)


func seeded_scenario_for_node(node_id: String) -> Dictionary:
	return living_world.seeded_scenario_for_node(node_id) if living_world != null else {}


func seeded_scenario_definition_for_node(node_id: String) -> Dictionary:
	return living_world.seeded_scenario_definition_for_node(node_id) if living_world != null else {}


func _seeded_scenario_definition_for_node_readonly(node_id: String) -> Dictionary:
	return living_world._seeded_scenario_definition_for_node_readonly(node_id) if living_world != null else {}


func register_rumor_fact(fact_class: String, fact_id: String, payload: Dictionary) -> bool:
	return living_world != null and living_world.register_rumor_fact(fact_class, fact_id, payload)


func rumor_fact(fact_id: String) -> Dictionary:
	return living_world.rumor_fact(fact_id) if living_world != null else {}


func rumor_facts(fact_class: String = "") -> Array:
	return living_world.rumor_facts(fact_class) if living_world != null else []


func rumors_for_venue(node_id: String, speaker_side: String, count: int = 1, rng: RngStream = null) -> Array:
	return living_world.rumors_for_venue(node_id, speaker_side, count, rng) if living_world != null else []


func hear_rumor(rumor_id: String) -> Dictionary:
	return living_world.hear_rumor(rumor_id) if living_world != null else {}


func hear_rendered_rumor(rumor: Dictionary) -> Dictionary:
	return living_world.hear_rendered_rumor(rumor) if living_world != null else {}


func heard_rumor_for_node(node_id: String) -> Dictionary:
	return living_world.heard_rumor_for_node(node_id) if living_world != null else {}


func rumor_trace_is_live(rumor: Dictionary) -> bool:
	return living_world != null and living_world.rumor_trace_is_live(rumor)


func traveler_node(character_id: String) -> String:
	return living_world.traveler_node(character_id) if living_world != null else ""


func travelers_at(node_id: String) -> Array:
	return living_world.travelers_at(node_id) if living_world != null else []


func traveler_state(character_id: String) -> Dictionary:
	return living_world.traveler_state(character_id) if living_world != null else {}


func traveler_context_line(character_id: String) -> String:
	return living_world.traveler_context_line(character_id) if living_world != null else ""


func departed_traveler_modifier(node_id: String, character_id: String) -> Dictionary:
	return living_world.departed_traveler_modifier(node_id, character_id) if living_world != null else {}


func register_reputation_incident_type(incident_type: String, definition: Dictionary) -> bool:
	return living_world != null and living_world.register_reputation_incident_type(incident_type, definition)


func record_reputation_incident(incident_type: String, node_id: String, magnitude: float = 1.0, context: Dictionary = {}) -> Dictionary:
	return living_world.record_reputation_incident(incident_type, node_id, magnitude, context) if living_world != null else {}


func local_reputation(node_id: String) -> Dictionary:
	return living_world.local_reputation(node_id) if living_world != null else {}


func reputation_value(node_id: String, incident_type: String = "") -> float:
	return living_world.reputation_value(node_id, incident_type) if living_world != null else 0.0


func weather_now() -> String:
	return _weather_id


func day_type() -> String:
	return _day_type_id


func active_happenings() -> Array:
	var visible := _active_happening_ids.duplicate()
	visible.erase("police_sweep")
	return visible


func happening_active(id: String) -> bool:
	if id.strip_edges() == "police_sweep":
		return false
	return _active_happening_lookup.has(id)


func town_flag_active(id: String) -> bool:
	if id.strip_edges() == "police_sweep":
		return false
	return _active_town_flags.has(id)


func scenario_weight_multiplier(archetype_id: String, scenario_id: String, tags: Array) -> float:
	var multiplier := float(_scenario_weight_by_archetype.get(archetype_id, 1.0))
	multiplier *= float(_scenario_weight_by_id.get(scenario_id, 1.0))
	for tag_value in tags:
		multiplier *= float(_scenario_weight_by_tag.get(str(tag_value), 1.0))
	if police_sweep != null:
		multiplier *= police_sweep.scenario_pressure_multiplier(archetype_id, scenario_id, tags)
	return maxf(0.0, multiplier)


func travel_modifier_profile() -> Dictionary:
	return _travel_profile


func music_modifier_profile() -> Dictionary:
	return _music_modifier_profile


func economic_modifier_profile() -> Dictionary:
	return _economic_modifier_profile


func status_line() -> String:
	return "%s outside · %s" % [_display_name(_weather_id), _display_name(_day_type_id)]


func snapshot(deep_copy_seeded_definitions: bool = true) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"turn_horizon": turn_horizon,
		"weather_schedule": weather_schedule.duplicate(true),
		"calendar_cycle": calendar_cycle.duplicate(true),
		"calendar_offset_actions": calendar_offset_actions,
		"happenings": happenings.duplicate(true),
		"progressive_meters": progressive_meters.duplicate(true),
		"living_world": living_world.snapshot(deep_copy_seeded_definitions) if living_world != null else {},
		"police_sweep": police_sweep.snapshot() if police_sweep != null else {},
	}


func public_snapshot() -> Dictionary:
	var visible_happenings := active_happenings()
	var visible_flags: Array = _active_town_flags.keys()
	visible_flags.erase("police_sweep")
	return {
		"weather": _weather_id,
		"day_type": _day_type_id,
		"active_happenings": visible_happenings,
		"active_town_flags": visible_flags,
		"status_line": status_line(),
		"sweep_marker": sweep_map_marker(),
	}


func _index_definitions() -> void:
	_weather_definition_by_id = {}
	for definition in _dictionary_array(_conditions.get("weather_states", [])):
		_weather_definition_by_id[str(definition.get("id", ""))] = definition
	_happening_definition_by_id = {}
	var happening_config := _dictionary(_conditions.get("happenings", {}))
	for definition in _dictionary_array(happening_config.get("definitions", [])):
		_happening_definition_by_id[str(definition.get("id", ""))] = definition


func _generate_weather_schedule(rng: RngStream) -> void:
	weather_schedule = []
	var definitions := _dictionary_array(_conditions.get("weather_states", []))
	if definitions.is_empty():
		definitions = [{"id": "clear", "dwell_actions": [turn_horizon, turn_horizon], "modifiers": {}}]
	var definition_index := rng.randi_range(0, definitions.size() - 1)
	var cursor := 0
	while cursor < turn_horizon:
		var definition: Dictionary = definitions[definition_index]
		var dwell := _int_range(definition.get("dwell_actions", [8, 12]), 8, 12)
		var duration := rng.randi_range(int(dwell[0]), int(dwell[1]))
		var end_action := mini(turn_horizon, cursor + maxi(1, duration))
		weather_schedule.append({
			"id": str(definition.get("id", "clear")),
			"start_action": cursor,
			"end_action": end_action,
			"modifiers": _dictionary(definition.get("modifiers", {})).duplicate(true),
		})
		cursor = end_action
		definition_index = (definition_index + 1) % definitions.size()
	_rebuild_weather_index()


func _rebuild_weather_index() -> void:
	_weather_by_action = PackedStringArray()
	_weather_by_action.resize(turn_horizon)
	_weather_by_action.fill("clear")
	_weather_segment_by_action = PackedInt32Array()
	_weather_segment_by_action.resize(turn_horizon)
	_weather_segment_by_action.fill(0)
	for segment_index in range(weather_schedule.size()):
		var segment: Dictionary = weather_schedule[segment_index]
		var weather_id := str(segment.get("id", "clear"))
		var start := clampi(int(segment.get("start_action", 0)), 0, turn_horizon)
		var end := clampi(int(segment.get("end_action", start + 1)), start, turn_horizon)
		for index in range(start, end):
			_weather_by_action[index] = weather_id
			_weather_segment_by_action[index] = segment_index


func _generate_calendar(rng: RngStream) -> void:
	var calendar := _dictionary(_conditions.get("calendar", {}))
	calendar_cycle = _dictionary_array(calendar.get("cycle", []))
	if calendar_cycle.is_empty():
		calendar_cycle = [{"id": "midweek", "duration_actions": turn_horizon, "modifiers": {}}]
	var period := _calendar_period()
	calendar_offset_actions = rng.randi_range(0, maxi(0, period - 1))


func _generate_happenings(rng: RngStream) -> void:
	happenings = []
	var happening_config := _dictionary(_conditions.get("happenings", {}))
	var definitions: Array = []
	for definition in _dictionary_array(happening_config.get("definitions", [])):
		var spawn_chance := clampi(int(definition.get("spawn_chance_percent", 100)), 0, 100)
		if spawn_chance <= 0 or (spawn_chance < 100 and rng.randi_range(1, 100) > spawn_chance):
			continue
		definitions.append(definition)
	var count_range := _int_range(happening_config.get("count_range", [0, 2]), 0, 2)
	var count := clampi(rng.randi_range(int(count_range[0]), int(count_range[1])), 0, mini(2, definitions.size()))
	for definition_value in rng.pick_many(definitions, count):
		var definition: Dictionary = definition_value
		var duration_range := _int_range(definition.get("duration_actions", [12, 24]), 12, 24)
		var duration := rng.randi_range(int(duration_range[0]), int(duration_range[1]))
		var latest_start := maxi(0, turn_horizon - duration)
		var start_range := _int_range(definition.get("start_action_range", [0, latest_start]), 0, latest_start)
		var start_action := rng.randi_range(clampi(int(start_range[0]), 0, latest_start), clampi(int(start_range[1]), 0, latest_start))
		happenings.append({
			"id": str(definition.get("id", "")),
			"display_name": str(definition.get("display_name", "")),
			"start_action": start_action,
			"end_action": mini(turn_horizon, start_action + maxi(1, duration)),
			"modifiers": _dictionary(definition.get("modifiers", {})).duplicate(true),
		})
	happenings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("start_action", 0)) == int(b.get("start_action", 0)):
			return str(a.get("id", "")) < str(b.get("id", ""))
		return int(a.get("start_action", 0)) < int(b.get("start_action", 0))
	)


func _refresh_current_profiles() -> void:
	_weather_id = "clear" if _weather_by_action.is_empty() else _weather_by_action[mini(action_index, _weather_by_action.size() - 1)]
	_day_type_id = _calendar_day_type_at(action_index)
	_active_happening_ids = []
	_active_happening_lookup = {}
	_active_town_flags = {}
	for happening in happenings:
		if action_index < int(happening.get("start_action", 0)) or action_index >= int(happening.get("end_action", 0)):
			continue
		var id := str(happening.get("id", ""))
		if id.is_empty():
			continue
		_active_happening_ids.append(id)
		_active_happening_lookup[id] = true
		var modifiers := _dictionary(happening.get("modifiers", {}))
		for flag_value in modifiers.get("town_flags", []):
			var flag_id := str(flag_value).strip_edges()
			if not flag_id.is_empty():
				_active_town_flags[flag_id] = true
	_rebuild_modifier_profiles()


func _sync_condition_rumor_facts() -> void:
	if living_world == null or living_world.node_metadata.is_empty():
		return
	living_world.remove_rumor_facts(TownNetworkScript.RUMOR_CLASS_CONDITION)
	var sources: Array = []
	for happening in happenings:
		var start_action := maxi(0, int(happening.get("start_action", 0)))
		var end_action := maxi(start_action + 1, int(happening.get("end_action", start_action + 1)))
		if action_index >= end_action or start_action > action_index + 12:
			continue
		var happening_id := str(happening.get("id", "")).strip_edges()
		if happening_id.is_empty():
			continue
		sources.append({
			"source_id": happening_id,
			"display_name": str(happening.get("display_name", happening_id.replace("_", " ").capitalize())),
			"condition_line": "%s is moving through town." % str(happening.get("display_name", happening_id.replace("_", " ").capitalize())),
			"start_action": start_action,
			"end_action": end_action,
			"incoming_window_actions": 12,
		})
	for segment in weather_schedule:
		var start_action := maxi(0, int(segment.get("start_action", 0)))
		var end_action := maxi(start_action + 1, int(segment.get("end_action", start_action + 1)))
		if action_index >= end_action or start_action > action_index + 12:
			continue
		var weather_id := str(segment.get("id", "clear")).strip_edges()
		if weather_id == "clear":
			continue
		sources.append({
			"source_id": "weather:%s:%d" % [weather_id, start_action],
			"display_name": _display_name(weather_id),
			"condition_line": "%s is moving in." % _display_name(weather_id),
			"start_action": start_action,
			"end_action": end_action,
			"incoming_window_actions": 12,
		})
	var node_ids: Array = living_world.node_metadata.keys()
	node_ids.sort()
	for source in sources:
		for node_id_value in node_ids:
			var node_id := str(node_id_value)
			var source_id := str(source.get("source_id", ""))
			var payload: Dictionary = (source as Dictionary).duplicate(true)
			payload["target_node_id"] = node_id
			living_world.register_rumor_fact(
				TownNetworkScript.RUMOR_CLASS_CONDITION,
				"condition:%s:%s" % [source_id.replace(":", "_"), node_id],
				payload
			)
	for node_id_value in node_ids:
		var node_id := str(node_id_value)
		var cass_modifier := living_world.departed_traveler_modifier(node_id, "cass_rival_counter")
		if cass_modifier.is_empty():
			continue
		living_world.register_rumor_fact(TownNetworkScript.RUMOR_CLASS_CONDITION, "condition:cass_left:%s" % node_id, {
			"target_node_id": node_id,
			"source_id": "cass_rival_counter",
			"display_name": "Cass Venn",
			"condition_line": "Cass Venn already worked that room.",
			"start_action": int(cass_modifier.get("departed_action", action_index)),
			"end_action": action_index + maxi(1, int(cass_modifier.get("remaining_actions", 1))),
			"incoming_window_actions": 0,
		})
	var silas_state := living_world.traveler_state("silas_snitch")
	var silas_node := str(silas_state.get("node_id", ""))
	if not silas_node.is_empty():
		living_world.register_rumor_fact(TownNetworkScript.RUMOR_CLASS_CONDITION, "condition:silas_drinks:%s" % silas_node, {
			"target_node_id": silas_node,
			"source_id": "silas_snitch",
			"display_name": "Silas Crow",
			"condition_line": "Silas Crow is drinking there.",
			"start_action": int(silas_state.get("arrived_action", action_index)),
			"end_action": int(silas_state.get("depart_action", action_index + 1)),
			"incoming_window_actions": 0,
		})


func _sync_sweep_rumor_facts() -> void:
	if living_world == null:
		return
	living_world.remove_rumor_facts(TownNetworkScript.RUMOR_CLASS_SWEEP)
	var sweep := sweep_internal_status()
	if not bool(sweep.get("active", false)):
		return
	var current_node := str(sweep.get("current_node_id", ""))
	var previous_node := str(sweep.get("previous_node_id", ""))
	var heading_node := str(sweep.get("heading_node_id", ""))
	var recent_node := previous_node if not previous_node.is_empty() else current_node
	var age := maxi(0, action_index - int(sweep.get("arrived_action", action_index)))
	var heading_name := _living_world_node_label(heading_node) if not heading_node.is_empty() else "out of town"
	living_world.register_rumor_fact(TownNetworkScript.RUMOR_CLASS_SWEEP, "sweep:recent", {
		"target_node_id": recent_node,
		"source_id": "police_sweep",
		"fact_detail": "there %d turns ago, headed toward %s" % [age, heading_name],
		"track_segment_index": int(sweep.get("segment_index", -1)),
		"truth_node_id": current_node,
	})
	if not heading_node.is_empty():
		living_world.register_rumor_fact(TownNetworkScript.RUMOR_CLASS_SWEEP, "sweep:heading", {
			"target_node_id": heading_node,
			"source_id": "police_sweep",
			"fact_detail": "headed this way from %s" % _living_world_node_label(current_node),
			"track_segment_index": int(sweep.get("segment_index", -1)),
			"truth_node_id": current_node,
		})


func _sync_progressive_rumor_facts() -> void:
	if living_world == null:
		return
	for meter_id_value in progressive_meters.keys():
		_sync_progressive_rumor_fact(str(meter_id_value))


func _sync_progressive_rumor_fact(meter_id: String) -> void:
	if living_world == null:
		return
	var meter := _dictionary(progressive_meters.get(meter_id, {}))
	if meter.is_empty():
		return
	var value := maxi(0, int(meter.get("value", 0)))
	var detail := "fat at $%d" % value if value >= 240 else "building at $%d" % value if value >= 170 else "thin at $%d" % value
	living_world.register_rumor_fact(VAULT_PROGRESSIVE_RUMOR_CLASS, "vault:%s" % str(meter.get("target_node_id", meter_id)), {
		"target_node_id": str(meter.get("target_node_id", "")),
		"target_name": str(meter.get("target_name", meter.get("target_node_id", ""))),
		"source_id": meter_id,
		"fact_detail": detail,
		"meter_value": value,
		"meter_id": meter_id,
	})


func _rebuild_modifier_profiles() -> void:
	_scenario_weight_by_tag = {}
	_scenario_weight_by_archetype = {}
	_scenario_weight_by_id = {}
	_travel_profile = {
		"cost_multiplier": 1.0,
		"risk_multiplier": 1.0,
		"risk_band_delta": 0,
	}
	_music_modifier_profile = {
		"ambience_delta": 0.0,
		"volume_multiplier": 1.0,
		"texture_override": "",
	}
	_economic_modifier_profile = {
		"stake_floor_multiplier": 1.0,
		"stake_ceiling_multiplier": 1.0,
		"crowd_density_multiplier": 1.0,
	}
	var weather_segment_index := 0 if _weather_segment_by_action.is_empty() else _weather_segment_by_action[mini(action_index, _weather_segment_by_action.size() - 1)]
	var weather_segment: Dictionary = weather_schedule[clampi(weather_segment_index, 0, maxi(0, weather_schedule.size() - 1))] if not weather_schedule.is_empty() else {}
	var weather_modifiers := _dictionary(weather_segment.get("modifiers", {}))
	_merge_scenario_modifiers(weather_modifiers)
	_travel_profile["cost_multiplier"] = maxf(0.0, float(weather_modifiers.get("travel_cost_multiplier", 1.0)))
	_travel_profile["risk_multiplier"] = maxf(0.0, float(weather_modifiers.get("travel_risk_multiplier", 1.0)))
	_travel_profile["risk_band_delta"] = clampi(int(weather_modifiers.get("travel_risk_band_delta", 0)), -2, 2)
	_merge_music_modifiers(_dictionary(weather_modifiers.get("music", {})))
	for happening in happenings:
		var happening_id := str(happening.get("id", ""))
		if not _active_happening_lookup.has(happening_id):
			continue
		var modifiers := _dictionary(happening.get("modifiers", {}))
		_merge_scenario_modifiers(modifiers)
		_merge_music_modifiers(_dictionary(modifiers.get("music", {})))
	var day_definition := _calendar_definition(_day_type_id)
	var day_modifiers := _dictionary(day_definition.get("modifiers", {}))
	_merge_scenario_modifiers(day_modifiers)
	var economy := _dictionary(day_modifiers.get("economy", {}))
	for key in _economic_modifier_profile.keys():
		_economic_modifier_profile[key] = maxf(0.0, float(economy.get(key, _economic_modifier_profile[key])))


func _merge_scenario_modifiers(modifiers: Dictionary) -> void:
	_multiply_lookup(_scenario_weight_by_tag, _dictionary(modifiers.get("scenario_weight_by_tag", {})))
	_multiply_lookup(_scenario_weight_by_archetype, _dictionary(modifiers.get("scenario_weight_by_archetype", {})))
	_multiply_lookup(_scenario_weight_by_id, _dictionary(modifiers.get("scenario_weight_by_id", {})))


func _merge_music_modifiers(modifiers: Dictionary) -> void:
	_music_modifier_profile["ambience_delta"] = float(_music_modifier_profile.get("ambience_delta", 0.0)) + float(modifiers.get("ambience_delta", 0.0))
	_music_modifier_profile["volume_multiplier"] = float(_music_modifier_profile.get("volume_multiplier", 1.0)) * maxf(0.0, float(modifiers.get("volume_multiplier", 1.0)))
	var texture_override := str(modifiers.get("texture_override", "")).strip_edges()
	if not texture_override.is_empty():
		_music_modifier_profile["texture_override"] = texture_override


func _multiply_lookup(target: Dictionary, source: Dictionary) -> void:
	for key_value in source.keys():
		var key := str(key_value)
		target[key] = float(target.get(key, 1.0)) * maxf(0.0, float(source.get(key_value, 1.0)))


func _calendar_day_type_at(index: int) -> String:
	var period := _calendar_period()
	var cursor := (maxi(0, index) + calendar_offset_actions) % period
	for definition in calendar_cycle:
		var duration := maxi(1, int(definition.get("duration_actions", 1)))
		if cursor < duration:
			return str(definition.get("id", "midweek"))
		cursor -= duration
	return "midweek"


func _calendar_period() -> int:
	var period := 0
	for definition in calendar_cycle:
		period += maxi(1, int(definition.get("duration_actions", 1)))
	return maxi(1, period)


func _calendar_definition(id: String) -> Dictionary:
	for definition in calendar_cycle:
		if str(definition.get("id", "")) == id:
			return definition
	return {}


func _police_sweep_happening() -> Dictionary:
	for happening in happenings:
		if str(happening.get("id", "")) == "police_sweep":
			return happening
	return {}


func _police_sweep_config() -> Dictionary:
	var definition := _dictionary(_happening_definition_by_id.get("police_sweep", {}))
	return _dictionary(definition.get("sweep", {})).duplicate(true)


func _living_world_node_label(node_id: String) -> String:
	if living_world == null:
		return node_id.replace("_", " ").capitalize()
	return str(_dictionary(living_world.node_metadata.get(node_id, {})).get("label", node_id.replace("_", " ").capitalize()))


func _display_name(id: String) -> String:
	if _weather_definition_by_id.has(id):
		return str((_weather_definition_by_id[id] as Dictionary).get("display_name", id.capitalize()))
	var calendar_definition := _calendar_definition(id)
	if not calendar_definition.is_empty():
		return str(calendar_definition.get("display_name", id.capitalize()))
	return id.replace("_", " ").capitalize()


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


static func _int_range(value: Variant, fallback_min: int, fallback_max: int) -> Array:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		var first := int((value as Array)[0])
		var second := int((value as Array)[1])
		return [mini(first, second), maxi(first, second)]
	return [mini(fallback_min, fallback_max), maxi(fallback_min, fallback_max)]
