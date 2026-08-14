class_name TownState
extends RefCounted

const CONDITIONS_PATH := "res://data/town/conditions.json"
const SCHEMA_VERSION := 1
const DEFAULT_TURN_HORIZON := 240
const WEATHER_IDS := ["clear", "rain", "fog", "storm"]
const DAY_TYPE_IDS := ["payday", "midweek"]
const HAPPENING_IDS := ["fight_night", "festival_weekend", "rolling_blackout"]
const RISK_BANDS := ["low", "medium", "high"]

static var _conditions_cache: Dictionary = {}

var seed_value: int = 1
var action_index: int = 0
var turn_horizon: int = DEFAULT_TURN_HORIZON
var weather_schedule: Array = []
var calendar_cycle: Array = []
var calendar_offset_actions: int = 0
var happenings: Array = []

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
	_refresh_current_profiles()


func restore(source: Dictionary, p_seed_value: int, source_conditions: Dictionary = {}) -> bool:
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
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
	_refresh_current_profiles()


func weather_now() -> String:
	return _weather_id


func day_type() -> String:
	return _day_type_id


func active_happenings() -> Array:
	return _active_happening_ids


func happening_active(id: String) -> bool:
	return _active_happening_lookup.has(id)


func town_flag_active(id: String) -> bool:
	return _active_town_flags.has(id)


func scenario_weight_multiplier(archetype_id: String, scenario_id: String, tags: Array) -> float:
	var multiplier := float(_scenario_weight_by_archetype.get(archetype_id, 1.0))
	multiplier *= float(_scenario_weight_by_id.get(scenario_id, 1.0))
	for tag_value in tags:
		multiplier *= float(_scenario_weight_by_tag.get(str(tag_value), 1.0))
	return maxf(0.0, multiplier)


func travel_modifier_profile() -> Dictionary:
	return _travel_profile


func music_modifier_profile() -> Dictionary:
	return _music_modifier_profile


func economic_modifier_profile() -> Dictionary:
	return _economic_modifier_profile


func status_line() -> String:
	return "%s outside · %s" % [_display_name(_weather_id), _display_name(_day_type_id)]


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"turn_horizon": turn_horizon,
		"weather_schedule": weather_schedule.duplicate(true),
		"calendar_cycle": calendar_cycle.duplicate(true),
		"calendar_offset_actions": calendar_offset_actions,
		"happenings": happenings.duplicate(true),
	}


func public_snapshot() -> Dictionary:
	return {
		"weather": _weather_id,
		"day_type": _day_type_id,
		"active_happenings": _active_happening_ids.duplicate(),
		"active_town_flags": _active_town_flags.keys(),
		"status_line": status_line(),
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
	var definitions := _dictionary_array(happening_config.get("definitions", []))
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
