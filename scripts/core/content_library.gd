class_name ContentLibrary
extends RefCounted

# Loads and validates README-defined foundation content packs.

const ENVIRONMENT_ARCHETYPES_PATH := "res://data/environments/archetypes.json"
const GAMES_PATH := "res://data/games/games.json"
const ITEMS_PATH := "res://data/items/items.json"
const CONTENT_GROUPS_PATH := "res://data/content_groups/groups.json"
const EVENTS_PATH := "res://data/events/events.json"
const DIALOGUES_PATH := "res://data/dialogue/dialogues.json"
const CHALLENGES_PATH := "res://data/challenges/challenges.json"
const LENDERS_PATH := "res://data/debt/lenders.json"
const SERVICES_PATH := "res://data/services/services.json"
const TRAVEL_ROUTES_PATH := "res://data/travel/routes.json"
const MUSIC_MANIFEST_PATH := "res://data/audio/music_manifest.json"
const MUSIC_ASSET_ROOT := "res://assets/audio/music"
const MIN_AUTHORED_MUSIC_LOOP_SECONDS := 12.0

var environment_archetypes: Array = []
var games: Array = []
var items: Array = []
var content_groups: Array = []
var events: Array = []
var dialogues: Array = []
var challenges: Array = []
var lenders: Array = []
var services: Array = []
var travel_routes: Array = []
var music_tracks: Array = []
var validation_errors: Array = []
var validation_warnings: Array = []
var _load_errors: Array = []
var _indexes: Dictionary = {}
var _load_timing: Dictionary = {}
var _load_pack_timings: Array = []


# Returns the active README pack paths required by the foundation path.
static func required_pack_paths() -> Dictionary:
	return {
		"environment_archetypes": ENVIRONMENT_ARCHETYPES_PATH,
		"games": GAMES_PATH,
		"items": ITEMS_PATH,
		"content_groups": CONTENT_GROUPS_PATH,
		"events": EVENTS_PATH,
		"dialogues": DIALOGUES_PATH,
	}


# Returns future README pack paths that are known but optional until needed.
static func future_pack_paths() -> Dictionary:
	return {
		"challenges": CHALLENGES_PATH,
		"lenders": LENDERS_PATH,
		"services": SERVICES_PATH,
		"travel_routes": TRAVEL_ROUTES_PATH,
		"music_tracks": MUSIC_MANIFEST_PATH,
	}


# Loads the active packs and any future packs that already exist.
func load() -> Dictionary:
	var load_started_usec := Time.get_ticks_usec()
	_load_errors = []
	_load_pack_timings = []
	environment_archetypes = _load_array(ENVIRONMENT_ARCHETYPES_PATH, true)
	games = _load_array(GAMES_PATH, true)
	items = _load_array(ITEMS_PATH, true)
	content_groups = _load_array(CONTENT_GROUPS_PATH, true)
	events = _normalize_event_definitions(_load_array(EVENTS_PATH, true))
	dialogues = _normalize_dialogue_definitions(_load_array(DIALOGUES_PATH, true))
	challenges = _load_array(CHALLENGES_PATH, false)
	lenders = _load_array(LENDERS_PATH, false)
	services = _load_array(SERVICES_PATH, false)
	travel_routes = _load_array(TRAVEL_ROUTES_PATH, false)
	music_tracks = _load_array(MUSIC_MANIFEST_PATH, false)
	var parse_complete_usec := Time.get_ticks_usec()
	_rebuild_indexes()
	var index_complete_usec := Time.get_ticks_usec()
	validate()
	var validate_complete_usec := Time.get_ticks_usec()
	_load_timing = {
		"total_ms": _elapsed_ms(load_started_usec, validate_complete_usec),
		"parse_ms": _elapsed_ms(load_started_usec, parse_complete_usec),
		"index_ms": _elapsed_ms(parse_complete_usec, index_complete_usec),
		"validate_ms": _elapsed_ms(index_complete_usec, validate_complete_usec),
		"packs": _load_pack_timings.duplicate(true),
	}
	return {
		"environment_archetypes": environment_archetypes,
		"games": games,
		"items": items,
		"content_groups": content_groups,
		"events": events,
		"dialogues": dialogues,
		"challenges": challenges,
		"lenders": lenders,
		"services": services,
		"travel_routes": travel_routes,
		"music_tracks": music_tracks,
	}


# Validates loaded packs without reading demo runtime data.
func validate() -> Array:
	events = _normalize_event_definitions(events)
	dialogues = _normalize_dialogue_definitions(dialogues)
	validation_errors = _load_errors.duplicate(true)
	validation_warnings = []
	_validate_collection("environment_archetypes", environment_archetypes, [
		"id",
		"kind",
		"tier",
		"name_prefixes",
		"name_nouns",
		"visual_context",
		"security_profile",
		"economic_profile",
		"game_pool",
		"game_count",
		"item_pool",
		"item_count",
		"event_pool",
		"event_count",
		"service_pool",
		"lender_hooks",
		"suspicion_cues",
		"travel_hooks",
		"local_narrative_flags",
	])
	_validate_collection("games", games, [
		"id",
		"display_name",
		"family",
		"module_path",
		"legal_actions",
		"cheat_actions",
	])
	_validate_collection("items", items, [
		"id",
		"display_name",
		"class",
		"domain",
		"price_min",
		"price_max",
		"effect",
	])
	_validate_collection("content_groups", content_groups, [
		"id",
		"display_name",
		"description",
		"default_enabled",
		"game_ids",
		"item_ids",
	])
	_validate_collection("events", events, [
		"id",
		"display_name",
		"type",
		"scopes",
		"trigger",
		"payload",
	])
	_validate_collection("dialogues", dialogues, [
		"id",
		"speaker",
		"start",
		"nodes",
	])
	_validate_collection("challenges", challenges, [
		"id",
		"title",
		"description",
		"modifiers",
		"completion_flag",
	])
	_validate_collection("lenders", lenders, [
		"id",
		"display_name",
		"lender_type",
		"description",
		"debt_profile",
		"consequences",
	])
	_validate_collection("services", services, [
		"id",
		"display_name",
		"category",
		"description",
		"cost",
		"effect",
	])
	_validate_collection("travel_routes", travel_routes, [
		"id",
		"label",
		"destination_archetype",
		"description",
		"cost",
		"risk",
	])
	_validate_collection("music_tracks", music_tracks, [
		"id",
		"bpm",
		"bars",
		"loop_frames",
		"stems",
	])
	_validate_game_definitions()
	_validate_item_definitions()
	_validate_content_group_definitions()
	_validate_challenge_definitions()
	_validate_event_definitions()
	_validate_dialogue_definitions()
	_validate_lender_definitions()
	_validate_service_definitions()
	_validate_travel_route_definitions()
	_validate_music_manifest_definitions()
	_validate_environment_references()
	return validation_errors.duplicate(true)


# Returns archetypes available at the requested progression tier.
func archetypes_for(tier: int) -> Array:
	var candidates: Array = []
	for archetype in environment_archetypes:
		if int(archetype.get("tier", 1)) <= tier:
			candidates.append(archetype)
	return candidates


# Finds a game definition by id.
func game(game_id: String) -> Dictionary:
	return _lookup("games", games, game_id)


# Finds an item definition by id.
func item(item_id: String) -> Dictionary:
	return _lookup("items", items, item_id)


# Finds a run content group definition by id.
func content_group(group_id: String) -> Dictionary:
	return _lookup("content_groups", content_groups, group_id)


# Returns the content groups enabled by default for a normal run.
func default_content_group_ids() -> Array:
	var result: Array = []
	for group_value in content_groups:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		var group_id := str(group.get("id", "")).strip_edges()
		if group_id.is_empty():
			continue
		if bool(group.get("default_enabled", true)) and not result.has(group_id):
			result.append(group_id)
	return result


# Normalizes player-selected group ids while preserving content pack order.
func normalize_content_group_ids(value: Variant) -> Array:
	var requested := _string_set(value)
	var result: Array = []
	for group_value in content_groups:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group_id := str((group_value as Dictionary).get("id", "")).strip_edges()
		if not group_id.is_empty() and bool(requested.get(group_id, false)):
			result.append(group_id)
	return result


# Reads selected content groups from a RunState challenge config.
func enabled_content_group_ids(challenge_config: Dictionary = {}) -> Array:
	var modifiers := _as_dict(challenge_config.get("modifiers", {}))
	var has_selection := modifiers.has("content_groups") or challenge_config.has("content_groups")
	if not has_selection:
		return default_content_group_ids()
	var selected_value: Variant = modifiers.get("content_groups", challenge_config.get("content_groups", []))
	return normalize_content_group_ids(selected_value)


# Builds UI-ready group options without hardcoding ids in FoundationMain.
func content_group_options(selected_group_ids: Array = []) -> Array:
	var selected := _string_set(selected_group_ids)
	var result: Array = []
	for group_value in content_groups:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		var group_id := str(group.get("id", "")).strip_edges()
		if group_id.is_empty():
			continue
		result.append({
			"id": group_id,
			"display_name": str(group.get("display_name", group_id.capitalize())),
			"description": str(group.get("description", "")),
			"default_enabled": bool(group.get("default_enabled", true)),
			"selected": bool(selected.get(group_id, false)),
			"game_ids": _string_array(group.get("game_ids", [])),
			"item_ids": _string_array(group.get("item_ids", [])),
		})
	return result


# Returns true if a game definition belongs to at least one enabled group.
func game_enabled_for_challenge(game_id: String, challenge_config: Dictionary = {}) -> bool:
	return _definition_enabled_for_groups(game(game_id), enabled_content_group_ids(challenge_config))


# Returns true if an item definition belongs to at least one enabled group.
func item_enabled_for_challenge(item_id: String, challenge_config: Dictionary = {}) -> bool:
	return _definition_enabled_for_groups(item(item_id), enabled_content_group_ids(challenge_config))


# Filters a list of game ids against run content groups.
func filter_game_ids_for_challenge(ids: Variant, challenge_config: Dictionary = {}) -> Array:
	var enabled := enabled_content_group_ids(challenge_config)
	var result: Array = []
	for game_id in _string_array(ids):
		if _definition_enabled_for_groups(game(game_id), enabled):
			result.append(game_id)
	return result


# Filters a list of item ids against run content groups.
func filter_item_ids_for_challenge(ids: Variant, challenge_config: Dictionary = {}) -> Array:
	var enabled := enabled_content_group_ids(challenge_config)
	var result: Array = []
	for item_id in _string_array(ids):
		if _definition_enabled_for_groups(item(item_id), enabled):
			result.append(item_id)
	return result


# Builds the item pool used by generated shops. Authored archetype pools stay as
# the front of the list, then enabled buyable content-group items fill in so new
# modular item packs are reachable without hand-editing every shop archetype.
func shop_item_pool_for_challenge(archetype_item_pool: Variant, challenge_config: Dictionary = {}) -> Array:
	var result := filter_item_ids_for_challenge(archetype_item_pool, challenge_config)
	var seen := _string_set(result)
	var enabled := enabled_content_group_ids(challenge_config)
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item_def: Dictionary = item_value
		var item_id := str(item_def.get("id", "")).strip_edges()
		if item_id.is_empty() or bool(seen.get(item_id, false)):
			continue
		if not bool(item_def.get("sellable", true)):
			continue
		if not _definition_enabled_for_groups(item_def, enabled):
			continue
		result.append(item_id)
		seen[item_id] = true
	return result


# Finds an event definition by id.
func event(event_id: String) -> Dictionary:
	return _lookup("events", events, event_id)


# Finds a dialogue definition by id.
func dialogue(dialogue_id: String) -> Dictionary:
	return _lookup("dialogues", dialogues, dialogue_id)


# Finds a challenge definition by id.
func challenge(challenge_id: String) -> Dictionary:
	return _lookup("challenges", challenges, challenge_id)


# Builds UI-ready challenge options without hardcoding ids in FoundationMain.
func challenge_options(selected_challenge_id: String = "") -> Array:
	var result: Array = []
	for challenge_value in challenges:
		if typeof(challenge_value) != TYPE_DICTIONARY:
			continue
		var challenge_def: Dictionary = challenge_value
		var challenge_id := str(challenge_def.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		result.append({
			"id": challenge_id,
			"title": str(challenge_def.get("title", challenge_id.capitalize())),
			"description": str(challenge_def.get("description", "")),
			"completion_flag": str(challenge_def.get("completion_flag", "")),
			"modifiers": _as_dict(challenge_def.get("modifiers", {})),
			"selected": challenge_id == selected_challenge_id,
		})
	return result


# Converts a challenge definition into the RunState custom-challenge contract.
func challenge_config_for(challenge_id: String, seed_text: String) -> Dictionary:
	var challenge_def := challenge(challenge_id)
	if challenge_def.is_empty():
		return RunState.standard_challenge(seed_text)
	var config := RunState.custom_challenge(challenge_id, seed_text, _as_dict(challenge_def.get("modifiers", {})))
	config["title"] = str(challenge_def.get("title", challenge_id.capitalize()))
	config["description"] = str(challenge_def.get("description", ""))
	config["completion_flag"] = str(challenge_def.get("completion_flag", ""))
	return config


# Finds a lender definition by id.
func lender(lender_id: String) -> Dictionary:
	return _lookup("lenders", lenders, lender_id)


# Finds a service definition by id.
func service(service_id: String) -> Dictionary:
	return _lookup("services", services, service_id)


# Finds a travel route definition by id.
func route(route_id: String) -> Dictionary:
	return _lookup("travel_routes", travel_routes, route_id)


# Finds an authored music track manifest entry by id.
func music_track(track_id: String) -> Dictionary:
	return _lookup("music_tracks", music_tracks, track_id)


# Reads one JSON array content pack from disk.
func _load_array(path: String, required: bool) -> Array:
	var started_usec := Time.get_ticks_usec()
	if not FileAccess.file_exists(path):
		if required:
			_load_errors.append("Missing required content pack: %s" % path)
		_load_pack_timings.append({
			"path": path,
			"exists": false,
			"required": required,
			"bytes": 0,
			"entries": 0,
			"duration_ms": _elapsed_ms(started_usec, Time.get_ticks_usec()),
			"parse_ms": 0.0,
		})
		return []
	var text := FileAccess.get_file_as_string(path)
	var parse_started_usec := Time.get_ticks_usec()
	var parsed: Variant = JSON.parse_string(text)
	var parse_complete_usec := Time.get_ticks_usec()
	if typeof(parsed) != TYPE_ARRAY:
		_load_errors.append("Content file must contain a JSON array: %s" % path)
		_load_pack_timings.append({
			"path": path,
			"exists": true,
			"required": required,
			"bytes": text.length(),
			"entries": 0,
			"duration_ms": _elapsed_ms(started_usec, parse_complete_usec),
			"parse_ms": _elapsed_ms(parse_started_usec, parse_complete_usec),
		})
		return []
	var result: Array = parsed
	_load_pack_timings.append({
		"path": path,
		"exists": true,
		"required": required,
		"bytes": text.length(),
		"entries": result.size(),
		"duration_ms": _elapsed_ms(started_usec, parse_complete_usec),
		"parse_ms": _elapsed_ms(parse_started_usec, parse_complete_usec),
	})
	return parsed


static func _normalize_event_definitions(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			result.append(value)
			continue
		result.append(_normalize_event_definition(value as Dictionary))
	return result


static func _normalize_event_definition(event_def: Dictionary) -> Dictionary:
	var normalized := event_def.duplicate(true)
	var presentation := str(normalized.get("presentation", "modal")).strip_edges().to_lower()
	if not ["talk", "modal"].has(presentation):
		presentation = "modal"
	normalized["presentation"] = presentation
	normalized["speaker"] = _normalize_event_speaker(normalized.get("speaker", {}))
	var trigger := _as_dict(normalized.get("trigger", {"type": "manual"}))
	if trigger.is_empty():
		trigger = {"type": "manual"}
	var trigger_type := str(trigger.get("type", "manual")).strip_edges().to_lower()
	if trigger_type.is_empty():
		trigger_type = "manual"
	trigger["type"] = trigger_type
	match trigger_type:
		"heat_threshold":
			trigger["level"] = clampi(int(trigger.get("level", 65)), 0, 100)
		"table_approach":
			trigger["games"] = _string_array(trigger.get("games", []))
			trigger["min_hands"] = maxi(0, int(trigger.get("min_hands", trigger.get("min_rounds", 1))))
			trigger["chance"] = clampf(float(trigger.get("chance", 1.0)), 0.0, 1.0)
	normalized["trigger"] = trigger
	var payload := _as_dict(normalized.get("payload", {}))
	payload["timing"] = _normalize_event_timing(payload.get("timing", {}))
	normalized["payload"] = payload
	return normalized


static func _normalize_dialogue_definitions(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			result.append(value)
			continue
		result.append(_normalize_dialogue_definition(value as Dictionary))
	return result


static func _normalize_dialogue_definition(dialogue_def: Dictionary) -> Dictionary:
	var normalized := dialogue_def.duplicate(true)
	normalized["speaker"] = _normalize_event_speaker(normalized.get("speaker", {}))
	return normalized


static func _normalize_event_speaker(value: Variant) -> Dictionary:
	var source := _as_dict(value)
	var role := str(source.get("role", "stranger")).strip_edges().to_lower()
	if not ["patron", "staff", "stranger", "lender"].has(role):
		role = "stranger"
	var bind := str(source.get("bind", "none")).strip_edges().to_lower()
	if not ["table_patron", "none"].has(bind):
		bind = "none"
	return {
		"role": role,
		"name": str(source.get("name", "")).strip_edges(),
		"silhouette": str(source.get("silhouette", "")).strip_edges(),
		"bind": bind,
	}


static func _normalize_event_timing(value: Variant) -> Dictionary:
	var source := _as_dict(value)
	var expires := bool(source.get("expires", false))
	var duration_actions := maxi(0, int(source.get("duration_actions", 0)))
	if not expires:
		duration_actions = 0
	var timeout_choice_id := str(source.get("timeout_choice_id", "")).strip_edges()
	return {
		"expires": expires and duration_actions > 0 and not timeout_choice_id.is_empty(),
		"duration_actions": duration_actions,
		"timeout_choice_id": timeout_choice_id,
	}


# Rebuilds id indexes for loaded content arrays. Fixture tests can still assign
# arrays directly; _lookup refreshes a stale or missing index on demand.
func _rebuild_indexes() -> void:
	_indexes = {
		"games": _index_by_id(games),
		"items": _index_by_id(items),
		"content_groups": _index_by_id(content_groups),
		"events": _index_by_id(events),
		"dialogues": _index_by_id(dialogues),
		"challenges": _index_by_id(challenges),
		"lenders": _index_by_id(lenders),
		"services": _index_by_id(services),
		"travel_routes": _index_by_id(travel_routes),
		"music_tracks": _index_by_id(music_tracks),
	}


func debug_soak_snapshot() -> Dictionary:
	var index_sizes := {}
	for key_value in _indexes.keys():
		var key := str(key_value)
		var value: Variant = _indexes.get(key, {})
		index_sizes[key] = (value as Dictionary).size() if typeof(value) == TYPE_DICTIONARY else 0
	return {
		"pack_counts": {
			"environment_archetypes": environment_archetypes.size(),
			"games": games.size(),
			"items": items.size(),
			"content_groups": content_groups.size(),
			"events": events.size(),
			"dialogues": dialogues.size(),
			"challenges": challenges.size(),
			"lenders": lenders.size(),
			"services": services.size(),
			"travel_routes": travel_routes.size(),
			"music_tracks": music_tracks.size(),
		},
		"index_sizes": index_sizes,
		"validation_errors": validation_errors.size(),
		"validation_warnings": validation_warnings.size(),
	}


func load_timing_snapshot() -> Dictionary:
	return _load_timing.duplicate(true)


static func _elapsed_ms(start_usec: int, end_usec: int) -> float:
	return float(maxi(0, end_usec - start_usec)) / 1000.0


# Validates required fields and duplicate ids for one content array.
func _validate_collection(label: String, values: Array, required_fields: Array) -> void:
	var seen := {}
	for index in range(values.size()):
		var value: Variant = values[index]
		if typeof(value) != TYPE_DICTIONARY:
			validation_errors.append("%s[%d] must be a dictionary." % [label, index])
			continue
		var entry: Dictionary = value
		var id := str(entry.get("id", "")).strip_edges()
		if id.is_empty():
			validation_errors.append("%s[%d] is missing required id." % [label, index])
		elif seen.has(id):
			validation_errors.append("%s contains duplicate id: %s" % [label, id])
		else:
			seen[id] = true
		for field in required_fields:
			if not entry.has(field):
				validation_errors.append("%s %s is missing required field: %s" % [label, id, field])
			elif typeof(entry[field]) == TYPE_NIL:
				validation_errors.append("%s %s has null required field: %s" % [label, id, field])


# Validates module routing and action shape for game definitions.
func _validate_game_definitions() -> void:
	var group_ids := _ids_for(content_groups)
	for game_def in games:
		if typeof(game_def) != TYPE_DICTIONARY:
			continue
		var game_id := str(game_def.get("id", "")).strip_edges()
		_validate_content_group_tags("games %s content_groups" % game_id, game_def.get("content_groups", []), group_ids)
		var module_path := str(game_def.get("module_path", "")).strip_edges()
		if module_path.is_empty():
			validation_errors.append("games %s is missing module_path." % game_id)
		elif not FileAccess.file_exists(module_path):
			validation_errors.append("games %s references missing module_path: %s" % [game_id, module_path])
		_validate_actions("games %s legal_actions" % game_id, game_def.get("legal_actions", []))
		_validate_actions("games %s cheat_actions" % game_id, game_def.get("cheat_actions", []))


# Validates an action list without interpreting game-specific rules.
func _validate_actions(label: String, actions: Variant) -> void:
	if typeof(actions) != TYPE_ARRAY:
		validation_errors.append("%s must be an array." % label)
		return
	var seen := {}
	for index in range(actions.size()):
		var action: Variant = actions[index]
		if typeof(action) != TYPE_DICTIONARY:
			validation_errors.append("%s[%d] must be a dictionary." % [label, index])
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id.is_empty():
			validation_errors.append("%s[%d] is missing id." % [label, index])
		elif seen.has(action_id):
			validation_errors.append("%s contains duplicate action id: %s" % [label, action_id])
		else:
			seen[action_id] = true
		if not action.has("label"):
			validation_errors.append("%s %s is missing label." % [label, action_id])


# Validates item shape used by the first foundation loop.
func _validate_item_definitions() -> void:
	var group_ids := _ids_for(content_groups)
	var allowed_rarity := {
		"common": true,
		"uncommon": true,
		"rare": true,
		"epic": true,
		"legendary": true,
	}
	for item_def in items:
		if typeof(item_def) != TYPE_DICTIONARY:
			continue
		var item_id := str(item_def.get("id", "")).strip_edges()
		_validate_content_group_tags("items %s content_groups" % item_id, item_def.get("content_groups", []), group_ids)
		if int(item_def.get("price_min", 0)) > int(item_def.get("price_max", 0)):
			validation_errors.append("items %s has price_min greater than price_max." % item_id)
		if typeof(item_def.get("effect", {})) != TYPE_DICTIONARY:
			validation_errors.append("items %s effect must be a dictionary." % item_id)
		var rarity := str(item_def.get("rarity", "")).strip_edges().to_lower()
		if not rarity.is_empty() and not bool(allowed_rarity.get(rarity, false)):
			validation_errors.append("items %s has unsupported rarity: %s." % [item_id, rarity])
		_validate_art_asset("items %s" % item_id, item_def)
		if str(item_def.get("icon_key", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing icon_key." % item_id)
		if str(item_def.get("environment_prop", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing environment_prop." % item_id)
		if str(item_def.get("surface", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing surface." % item_id)


# Validates content-group definitions and their game/item references.
func _validate_content_group_definitions() -> void:
	var game_ids := _ids_for(games)
	var item_ids := _ids_for(items)
	var grouped_games := {}
	var grouped_items := {}
	for group_def in content_groups:
		if typeof(group_def) != TYPE_DICTIONARY:
			continue
		var group_id := str(group_def.get("id", "")).strip_edges()
		if typeof(group_def.get("default_enabled", true)) != TYPE_BOOL:
			validation_errors.append("content_groups %s default_enabled must be a boolean." % group_id)
		_validate_id_references("content_groups %s game_ids" % group_id, group_def.get("game_ids", []), game_ids)
		_validate_id_references("content_groups %s item_ids" % group_id, group_def.get("item_ids", []), item_ids)
		for game_id in _string_array(group_def.get("game_ids", [])):
			grouped_games[game_id] = true
		for item_id in _string_array(group_def.get("item_ids", [])):
			grouped_items[item_id] = true
	for game_def in games:
		if typeof(game_def) != TYPE_DICTIONARY:
			continue
		var game_id := str((game_def as Dictionary).get("id", "")).strip_edges()
		if not game_id.is_empty() and not bool(grouped_games.get(game_id, false)):
			validation_errors.append("games %s is not referenced by any content group." % game_id)
	for item_def in items:
		if typeof(item_def) != TYPE_DICTIONARY:
			continue
		var item_id := str((item_def as Dictionary).get("id", "")).strip_edges()
		if not item_id.is_empty() and not bool(grouped_items.get(item_id, false)):
			validation_errors.append("items %s is not referenced by any content group." % item_id)


func _validate_content_group_tags(label: String, ids: Variant, valid_ids: Dictionary) -> void:
	if typeof(ids) != TYPE_ARRAY:
		validation_errors.append("%s must be an array." % label)
		return
	var group_ids := _string_array(ids)
	if group_ids.is_empty():
		validation_errors.append("%s must include at least one group id." % label)
		return
	_validate_id_references(label, group_ids, valid_ids)


# Validates challenge definitions and the modifier vocabulary consumed by RunState.
func _validate_challenge_definitions() -> void:
	var group_ids := _ids_for(content_groups)
	for challenge_value in challenges:
		if typeof(challenge_value) != TYPE_DICTIONARY:
			continue
		var challenge_def: Dictionary = challenge_value
		var challenge_id := str(challenge_def.get("id", "")).strip_edges()
		var completion_flag := str(challenge_def.get("completion_flag", "")).strip_edges()
		if completion_flag.is_empty():
			validation_errors.append("challenges %s completion_flag must be non-empty." % challenge_id)
		if str(challenge_def.get("title", "")).strip_edges().is_empty():
			validation_errors.append("challenges %s title must be non-empty." % challenge_id)
		if str(challenge_def.get("description", "")).strip_edges().is_empty():
			validation_errors.append("challenges %s description must be non-empty." % challenge_id)
		var modifiers_value: Variant = challenge_def.get("modifiers", {})
		if typeof(modifiers_value) != TYPE_DICTIONARY:
			validation_errors.append("challenges %s modifiers must be a dictionary." % challenge_id)
			continue
		var modifiers: Dictionary = modifiers_value
		if modifiers.is_empty():
			validation_errors.append("challenges %s modifiers must not be empty." % challenge_id)
			continue
		_validate_challenge_modifiers(challenge_id, modifiers, group_ids)


func _validate_challenge_modifiers(challenge_id: String, modifiers: Dictionary, group_ids: Dictionary) -> void:
	var known_keys := {
		"content_groups": true,
		"starting_bankroll": true,
		"starting_bankroll_delta": true,
		"baseline_luck_delta": true,
		"starting_heat": true,
		"starting_debt": true,
		"blocked_service_categories": true,
		"service_cost_multipliers": true,
		"disable_cheat_actions": true,
		"local_risk_decay_percent_delta": true,
		"local_heat_turn_decay_interval_delta": true,
		"grand_casino_high_roller_net_delta": true,
		"grand_casino_high_roller_max_heat_delta": true,
	}
	for key_value in modifiers.keys():
		var key := str(key_value)
		if not bool(known_keys.get(key, false)):
			validation_errors.append("challenges %s modifiers has unknown key: %s" % [challenge_id, key])
	if modifiers.has("content_groups"):
		_validate_id_references("challenges %s modifiers.content_groups" % challenge_id, modifiers.get("content_groups", []), group_ids)
	for key in ["starting_bankroll", "starting_bankroll_delta", "baseline_luck_delta", "starting_heat", "local_risk_decay_percent_delta", "local_heat_turn_decay_interval_delta", "grand_casino_high_roller_net_delta", "grand_casino_high_roller_max_heat_delta"]:
		if modifiers.has(key) and not _variant_is_number(modifiers.get(key, 0)):
			validation_errors.append("challenges %s modifiers.%s must be numeric." % [challenge_id, key])
	if modifiers.has("starting_bankroll") and int(modifiers.get("starting_bankroll", 0)) <= 0:
		validation_errors.append("challenges %s modifiers.starting_bankroll must be positive." % challenge_id)
	if modifiers.has("starting_heat"):
		var heat := int(modifiers.get("starting_heat", 0))
		if heat < 0 or heat > 100:
			validation_errors.append("challenges %s modifiers.starting_heat must be between 0 and 100." % challenge_id)
	if modifiers.has("starting_debt"):
		_validate_challenge_starting_debt(challenge_id, modifiers.get("starting_debt", []))
	if modifiers.has("blocked_service_categories"):
		_validate_non_empty_string_array("challenges %s modifiers.blocked_service_categories" % challenge_id, modifiers.get("blocked_service_categories", []))
	if modifiers.has("service_cost_multipliers"):
		_validate_challenge_service_cost_multipliers(challenge_id, modifiers.get("service_cost_multipliers", {}))
	if modifiers.has("disable_cheat_actions") and typeof(modifiers.get("disable_cheat_actions", false)) != TYPE_BOOL:
		validation_errors.append("challenges %s modifiers.disable_cheat_actions must be a boolean." % challenge_id)


func _validate_challenge_starting_debt(challenge_id: String, debts: Variant) -> void:
	if typeof(debts) != TYPE_ARRAY:
		validation_errors.append("challenges %s modifiers.starting_debt must be an array." % challenge_id)
		return
	for index in range((debts as Array).size()):
		var debt_value: Variant = (debts as Array)[index]
		if typeof(debt_value) != TYPE_DICTIONARY:
			validation_errors.append("challenges %s starting_debt[%d] must be a dictionary." % [challenge_id, index])
			continue
		var debt: Dictionary = debt_value
		if str(debt.get("id", "")).strip_edges().is_empty():
			validation_errors.append("challenges %s starting_debt[%d] is missing id." % [challenge_id, index])
		if str(debt.get("lender_id", "")).strip_edges().is_empty():
			validation_errors.append("challenges %s starting_debt[%d] is missing lender_id." % [challenge_id, index])
		if int(debt.get("balance", 0)) <= 0:
			validation_errors.append("challenges %s starting_debt[%d] balance must be positive." % [challenge_id, index])


func _validate_challenge_service_cost_multipliers(challenge_id: String, value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		validation_errors.append("challenges %s modifiers.service_cost_multipliers must be a dictionary." % challenge_id)
		return
	var multipliers: Dictionary = value
	for key_value in multipliers.keys():
		var key := str(key_value).strip_edges()
		if key.is_empty():
			validation_errors.append("challenges %s modifiers.service_cost_multipliers contains an empty category." % challenge_id)
		var multiplier_value: Variant = multipliers.get(key_value, 1.0)
		if not _variant_is_number(multiplier_value):
			validation_errors.append("challenges %s service cost multiplier %s must be numeric." % [challenge_id, key])
			continue
		if float(multiplier_value) < 0.0:
			validation_errors.append("challenges %s service cost multiplier %s must be non-negative." % [challenge_id, key])


func _validate_non_empty_string_array(label: String, value: Variant) -> void:
	if typeof(value) != TYPE_ARRAY:
		validation_errors.append("%s must be an array." % label)
		return
	for index in range((value as Array).size()):
		var text := str((value as Array)[index]).strip_edges()
		if text.is_empty():
			validation_errors.append("%s[%d] must be non-empty." % [label, index])


# Validates event choice payloads and route references inside consequences.
func _validate_event_definitions() -> void:
	var archetype_ids := _ids_for(environment_archetypes)
	var route_ids := _ids_for(travel_routes)
	var game_ids := _ids_for(games)
	var event_ids := _ids_for(events)
	var dialogue_ids := _ids_for(dialogues)
	var event_modes := {}
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY:
			var event_data: Dictionary = event_value
			var mode_id := str(event_data.get("id", "")).strip_edges()
			if not mode_id.is_empty():
				event_modes[mode_id] = str(event_data.get("interaction_mode", "")).strip_edges()
	for event_def in events:
		if typeof(event_def) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_def.get("id", "")).strip_edges()
		_validate_art_asset("events %s" % event_id, event_def)
		var dialogue_id := str(event_def.get("dialogue_id", "")).strip_edges()
		if not dialogue_id.is_empty() and not bool(dialogue_ids.get(dialogue_id, false)):
			validation_errors.append("events %s references unknown dialogue_id: %s" % [event_id, dialogue_id])
		var interaction_mode := str(event_def.get("interaction_mode", "")).strip_edges()
		if interaction_mode.is_empty():
			validation_errors.append("events %s is missing interaction_mode." % event_id)
		elif not ["interactable", "triggered"].has(interaction_mode):
			validation_errors.append("events %s has unknown interaction_mode: %s" % [event_id, interaction_mode])
		var presentation := str(event_def.get("presentation", "modal")).strip_edges()
		if not ["talk", "modal"].has(presentation):
			validation_errors.append("events %s has unknown presentation: %s" % [event_id, presentation])
		var speaker: Dictionary = _as_dict(event_def.get("speaker", {}))
		if not ["patron", "staff", "stranger", "lender"].has(str(speaker.get("role", "stranger"))):
			validation_errors.append("events %s speaker role is invalid." % event_id)
		if not ["table_patron", "none"].has(str(speaker.get("bind", "none"))):
			validation_errors.append("events %s speaker bind is invalid." % event_id)
		var icon_key := str(event_def.get("icon_key", "")).strip_edges()
		var environment_prop := str(event_def.get("environment_prop", "")).strip_edges()
		if interaction_mode == "triggered":
			if not icon_key.is_empty():
				validation_errors.append("events %s is triggered and must not declare icon_key." % event_id)
			if not environment_prop.is_empty():
				validation_errors.append("events %s is triggered and must not declare environment_prop." % event_id)
		else:
			if icon_key.is_empty():
				validation_errors.append("events %s is missing icon_key." % event_id)
			elif icon_key == "event":
				validation_errors.append("events %s must not use the generic event icon_key." % event_id)
			if environment_prop.is_empty():
				validation_errors.append("events %s is missing environment_prop." % event_id)
			if str(event_def.get("start_summary", "")).strip_edges().is_empty():
				validation_errors.append("events %s is missing start_summary." % event_id)
		var trigger: Dictionary = _as_dict(event_def.get("trigger", {}))
		var trigger_type := str(trigger.get("type", "manual")).strip_edges()
		if not ["manual", "timed", "travel", "random", "heat_threshold", "table_approach"].has(trigger_type):
			validation_errors.append("events %s has unknown trigger type: %s" % [event_id, trigger_type])
		if trigger_type == "heat_threshold":
			var level := int(trigger.get("level", 0))
			if level <= 0 or level > 100:
				validation_errors.append("events %s heat_threshold level must be 1-100." % event_id)
		elif trigger_type == "table_approach":
			_validate_id_references("events %s table_approach games" % event_id, trigger.get("games", []), game_ids)
			if int(trigger.get("min_hands", 0)) < 0:
				validation_errors.append("events %s table_approach min_hands must be non-negative." % event_id)
			var table_chance_value: Variant = trigger.get("chance", 1.0)
			if not _variant_is_number(table_chance_value):
				validation_errors.append("events %s table_approach chance must be numeric." % event_id)
			else:
				var table_chance := float(table_chance_value)
				if table_chance < 0.0 or table_chance > 1.0:
					validation_errors.append("events %s table_approach chance must be between 0 and 1." % event_id)
		var payload: Variant = event_def.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			validation_errors.append("events %s payload must be a dictionary." % event_id)
			continue
		var timing: Dictionary = _as_dict((payload as Dictionary).get("timing", {}))
		if bool(timing.get("expires", false)):
			if int(timing.get("duration_actions", 0)) <= 0:
				validation_errors.append("events %s timing duration_actions must be positive when expires is true." % event_id)
			if str(timing.get("timeout_choice_id", "")).strip_edges().is_empty():
				validation_errors.append("events %s timing timeout_choice_id is required when expires is true." % event_id)
		var choices: Variant = (payload as Dictionary).get("choices", [])
		if typeof(choices) != TYPE_ARRAY:
			validation_errors.append("events %s payload choices must be an array." % event_id)
			continue
		var seen_choices := {}
		for index in range(choices.size()):
			var choice: Variant = choices[index]
			if typeof(choice) != TYPE_DICTIONARY:
				validation_errors.append("events %s choice[%d] must be a dictionary." % [event_id, index])
				continue
			var choice_id := str(choice.get("id", "")).strip_edges()
			if choice_id.is_empty():
				validation_errors.append("events %s choice[%d] is missing id." % [event_id, index])
			elif seen_choices.has(choice_id):
				validation_errors.append("events %s contains duplicate choice id: %s" % [event_id, choice_id])
			else:
				seen_choices[choice_id] = true
			if not choice.has("label"):
				validation_errors.append("events %s choice %s is missing label." % [event_id, choice_id])
			var consequences: Dictionary = _as_dict(choice.get("consequences", {}))
			_validate_id_references("events %s choice %s set_next_archetypes" % [event_id, choice_id], consequences.get("set_next_archetypes", []), archetype_ids)
			_validate_id_references("events %s choice %s add_next_archetypes" % [event_id, choice_id], consequences.get("add_next_archetypes", []), archetype_ids)
			_validate_dialogue_effect_references("events %s choice %s" % [event_id, choice_id], consequences, archetype_ids, route_ids)
			var trigger_event := _as_dict(consequences.get("trigger_event", {}))
			if not trigger_event.is_empty():
				var trigger_event_id := str(trigger_event.get("event_id", "")).strip_edges()
				if trigger_event_id.is_empty():
					validation_errors.append("events %s choice %s trigger_event is missing event_id." % [event_id, choice_id])
				elif not bool(event_ids.get(trigger_event_id, false)):
					validation_errors.append("events %s choice %s trigger_event references unknown event: %s" % [event_id, choice_id, trigger_event_id])
				elif str(event_modes.get(trigger_event_id, "")) != "triggered":
					validation_errors.append("events %s choice %s trigger_event target must be triggered: %s" % [event_id, choice_id, trigger_event_id])
				var chance_value: Variant = trigger_event.get("chance", 1.0)
				if not _variant_is_number(chance_value):
					validation_errors.append("events %s choice %s trigger_event chance must be numeric." % [event_id, choice_id])
				else:
					var chance := float(chance_value)
					if chance < 0.0 or chance > 1.0:
						validation_errors.append("events %s choice %s trigger_event chance must be between 0 and 1." % [event_id, choice_id])


# Validates dialogue graph structure and consequence references.
func _validate_dialogue_definitions() -> void:
	var archetype_ids := _ids_for(environment_archetypes)
	var route_ids := _ids_for(travel_routes)
	for dialogue_value in dialogues:
		if typeof(dialogue_value) != TYPE_DICTIONARY:
			continue
		var dialogue: Dictionary = dialogue_value
		var dialogue_id := str(dialogue.get("id", "")).strip_edges()
		var speaker: Dictionary = _as_dict(dialogue.get("speaker", {}))
		if not ["patron", "staff", "stranger", "lender"].has(str(speaker.get("role", "stranger"))):
			validation_errors.append("dialogues %s speaker role is invalid." % dialogue_id)
		var start_id := str(dialogue.get("start", "")).strip_edges()
		var nodes: Dictionary = _dialogue_nodes_map(dialogue.get("nodes", {}))
		if nodes.is_empty():
			validation_errors.append("dialogues %s nodes must contain at least one node." % dialogue_id)
			continue
		if start_id.is_empty() or not nodes.has(start_id):
			validation_errors.append("dialogues %s start references missing node: %s" % [dialogue_id, start_id])
		for node_id_value in nodes.keys():
			var node_id := str(node_id_value).strip_edges()
			if node_id.is_empty():
				validation_errors.append("dialogues %s has an empty node id." % dialogue_id)
				continue
			var node_value: Variant = nodes.get(node_id, {})
			if typeof(node_value) != TYPE_DICTIONARY:
				validation_errors.append("dialogues %s node %s must be a dictionary." % [dialogue_id, node_id])
				continue
			var node: Dictionary = node_value
			if str(node.get("text", "")).strip_edges().is_empty():
				validation_errors.append("dialogues %s node %s is missing text." % [dialogue_id, node_id])
			var choices_value: Variant = node.get("choices", [])
			if typeof(choices_value) != TYPE_ARRAY:
				validation_errors.append("dialogues %s node %s choices must be an array." % [dialogue_id, node_id])
				continue
			var choices: Array = choices_value
			if choices.size() > 4:
				validation_errors.append("dialogues %s node %s has more than four choices." % [dialogue_id, node_id])
			var seen_choices := {}
			for choice_index in range(choices.size()):
				var choice_value: Variant = choices[choice_index]
				if typeof(choice_value) != TYPE_DICTIONARY:
					validation_errors.append("dialogues %s node %s choice[%d] must be a dictionary." % [dialogue_id, node_id, choice_index])
					continue
				var choice: Dictionary = choice_value
				var choice_id := str(choice.get("id", "")).strip_edges()
				if choice_id.is_empty():
					validation_errors.append("dialogues %s node %s choice[%d] is missing id." % [dialogue_id, node_id, choice_index])
				elif seen_choices.has(choice_id):
					validation_errors.append("dialogues %s node %s contains duplicate choice id: %s" % [dialogue_id, node_id, choice_id])
				else:
					seen_choices[choice_id] = true
				if str(choice.get("label", "")).strip_edges().is_empty():
					validation_errors.append("dialogues %s node %s choice %s is missing label." % [dialogue_id, node_id, choice_id])
				var goto_id := str(choice.get("goto", "")).strip_edges()
				var ends := bool(choice.get("end", false))
				if goto_id.is_empty() and not ends:
					validation_errors.append("dialogues %s node %s choice %s must declare goto or end." % [dialogue_id, node_id, choice_id])
				if not goto_id.is_empty() and not nodes.has(goto_id):
					validation_errors.append("dialogues %s node %s choice %s references missing goto: %s" % [dialogue_id, node_id, choice_id, goto_id])
				var effects: Dictionary = _as_dict(choice.get("effects", choice.get("consequences", {})))
				_validate_dialogue_effect_references("dialogues %s node %s choice %s" % [dialogue_id, node_id, choice_id], effects, archetype_ids, route_ids)


func _validate_dialogue_effect_references(label: String, effects: Dictionary, archetype_ids: Dictionary, route_ids: Dictionary) -> void:
	_validate_id_references("%s set_next_archetypes" % label, effects.get("set_next_archetypes", []), archetype_ids)
	_validate_id_references("%s add_next_archetypes" % label, effects.get("add_next_archetypes", []), archetype_ids)
	_validate_id_references("%s travel_hooks_add" % label, effects.get("travel_hooks_add", []), archetype_ids)
	for route_id in _single_or_array_strings(effects.get("unlock_travel_route", effects.get("unlock_travel_routes", []))):
		if not bool(route_ids.get(route_id, false)):
			validation_errors.append("%s unlock_travel_route references unknown route: %s" % [label, route_id])


static func _dialogue_nodes_map(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) != TYPE_ARRAY:
		return {}
	var result := {}
	for node_value in value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		if node_id.is_empty():
			continue
		result[node_id] = node.duplicate(true)
	return result


static func _single_or_array_strings(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return _string_array(value)
	var text := str(value).strip_edges()
	return [] if text.is_empty() else [text]


# Validates replaceable art metadata used by environment object presentation.
func _validate_art_asset(label: String, entry: Dictionary) -> void:
	var asset_path := str(entry.get("asset_path", "")).strip_edges()
	if asset_path.is_empty():
		validation_errors.append("%s is missing asset_path." % label)
		return
	if not asset_path.begins_with("res://assets/art/"):
		validation_errors.append("%s asset_path must stay under res://assets/art/." % label)
		return
	if not FileAccess.file_exists(asset_path):
		validation_errors.append("%s references missing asset_path: %s" % [label, asset_path])


# Validates lender profile data without adding debt lifecycle behavior.
func _validate_lender_definitions() -> void:
	for lender_def in lenders:
		if typeof(lender_def) != TYPE_DICTIONARY:
			continue
		var lender_id := str(lender_def.get("id", "")).strip_edges()
		var profile: Variant = lender_def.get("debt_profile", {})
		if typeof(profile) != TYPE_DICTIONARY:
			validation_errors.append("lenders %s debt_profile must be a dictionary." % lender_id)
			continue
		var profile_data: Dictionary = profile
		var principal_min := int(profile_data.get("principal_min", 0))
		var principal_max := int(profile_data.get("principal_max", principal_min))
		if principal_min < 0 or principal_max < 0:
			validation_errors.append("lenders %s principal values must be non-negative." % lender_id)
		if principal_min > principal_max:
			validation_errors.append("lenders %s principal_min greater than principal_max." % lender_id)
		if int(profile_data.get("deadline_turns", 0)) < 0:
			validation_errors.append("lenders %s deadline_turns must be non-negative." % lender_id)
		if typeof(lender_def.get("consequences", [])) != TYPE_ARRAY:
			validation_errors.append("lenders %s consequences must be an array." % lender_id)


# Validates service data that can later map cleanly to result-deltas.
func _validate_service_definitions() -> void:
	for service_def in services:
		if typeof(service_def) != TYPE_DICTIONARY:
			continue
		var service_id := str(service_def.get("id", "")).strip_edges()
		if int(service_def.get("cost", 0)) < 0:
			validation_errors.append("services %s cost must be non-negative." % service_id)
		if typeof(service_def.get("effect", {})) != TYPE_DICTIONARY:
			validation_errors.append("services %s effect must be a dictionary." % service_id)
		if service_def.has("availability") and typeof(service_def.get("availability", {})) != TYPE_DICTIONARY:
			validation_errors.append("services %s availability must be a dictionary." % service_id)


# Validates route identities and destination references.
func _validate_travel_route_definitions() -> void:
	var archetype_ids := _ids_for(environment_archetypes)
	for route_def in travel_routes:
		if typeof(route_def) != TYPE_DICTIONARY:
			continue
		var route_id := str(route_def.get("id", "")).strip_edges()
		if int(route_def.get("cost", 0)) < 0:
			validation_errors.append("travel_routes %s cost must be non-negative." % route_id)
		var distance := str(route_def.get("distance", "")).strip_edges().to_lower()
		if not distance.is_empty() and not ["same", "near", "local", "far", "remote"].has(distance):
			validation_errors.append("travel_routes %s distance must be same, near, local, far, or remote." % route_id)
		if route_def.has("risk_decay"):
			var risk_decay := int(route_def.get("risk_decay", 0))
			if risk_decay < 0 or risk_decay > 100:
				validation_errors.append("travel_routes %s risk_decay must be between 0 and 100." % route_id)
		if route_def.has("risk_event"):
			var risk_event: Variant = route_def.get("risk_event", {})
			if typeof(risk_event) != TYPE_DICTIONARY:
				validation_errors.append("travel_routes %s risk_event must be a dictionary." % route_id)
			else:
				var risk_event_data: Dictionary = risk_event
				var chance := int(risk_event_data.get("chance_percent", 0))
				if chance < 0 or chance > 100:
					validation_errors.append("travel_routes %s risk_event chance_percent must be between 0 and 100." % route_id)
				if str(risk_event_data.get("id", "")).strip_edges().is_empty():
					validation_errors.append("travel_routes %s risk_event is missing id." % route_id)
		if route_def.has("requires_travel_count_min") and int(route_def.get("requires_travel_count_min", 0)) < 0:
			validation_errors.append("travel_routes %s requires_travel_count_min must be non-negative." % route_id)
		if route_def.has("hide_until_travel_count_met") and typeof(route_def.get("hide_until_travel_count_met", false)) != TYPE_BOOL:
			validation_errors.append("travel_routes %s hide_until_travel_count_met must be a boolean." % route_id)
		if route_def.has("locked_hint") and typeof(route_def.get("locked_hint", false)) != TYPE_BOOL:
			validation_errors.append("travel_routes %s locked_hint must be a boolean." % route_id)
		var destination := str(route_def.get("destination_archetype", "")).strip_edges()
		if destination.is_empty():
			validation_errors.append("travel_routes %s is missing destination_archetype." % route_id)
		elif not archetype_ids.has(destination):
			validation_errors.append("travel_routes %s references unknown destination_archetype: %s" % [route_id, destination])


# Validates authored music stem manifests without requiring every venue to use one.
func _validate_music_manifest_definitions() -> void:
	var allowed_roles := {
		"pad": true,
		"bass": true,
		"bass_dark": true,
		"lead": true,
		"drums_low": true,
		"drums_high": true,
		"drums_high_double": true,
		"tension": true,
		"texture": true,
	}
	for track_value in music_tracks:
		if typeof(track_value) != TYPE_DICTIONARY:
			continue
		var track: Dictionary = track_value
		var track_id := str(track.get("id", "")).strip_edges()
		if float(track.get("bpm", 0.0)) <= 0.0:
			validation_errors.append("music_tracks %s bpm must be positive." % track_id)
		if int(track.get("bars", 0)) <= 0:
			validation_errors.append("music_tracks %s bars must be positive." % track_id)
		if int(track.get("loop_frames", 0)) <= 0:
			validation_errors.append("music_tracks %s loop_frames must be positive." % track_id)
		var stems_value: Variant = track.get("stems", {})
		if typeof(stems_value) != TYPE_DICTIONARY:
			validation_errors.append("music_tracks %s stems must be a dictionary." % track_id)
			continue
		var stems: Dictionary = stems_value
		if stems.is_empty():
			validation_errors.append("music_tracks %s must declare at least one stem." % track_id)
		for role_value in stems.keys():
			var role := str(role_value).strip_edges()
			if not bool(allowed_roles.get(role, false)):
				validation_errors.append("music_tracks %s has unknown stem role: %s." % [track_id, role])
				continue
			var stem_filename := _music_file_name(stems.get(role_value))
			_validate_music_asset_file("music_tracks %s stem %s" % [track_id, role], track_id, stem_filename)
			_validate_music_loop_asset("music_tracks %s stem %s" % [track_id, role], track_id, stem_filename, int(track.get("loop_frames", 0)))
		var stingers_value: Variant = track.get("stingers", {})
		if typeof(stingers_value) == TYPE_DICTIONARY:
			var stingers: Dictionary = stingers_value
			for cue_value in stingers.keys():
				var cue_id := str(cue_value).strip_edges()
				if cue_id.is_empty():
					validation_errors.append("music_tracks %s contains an empty stinger cue." % track_id)
					continue
				_validate_music_asset_file("music_tracks %s stinger %s" % [track_id, cue_id], track_id, _music_file_name(stingers.get(cue_value)))
		elif typeof(stingers_value) != TYPE_NIL:
			validation_errors.append("music_tracks %s stingers must be a dictionary when present." % track_id)


func _validate_music_asset_file(label: String, track_id: String, filename: String) -> void:
	if filename.is_empty():
		validation_errors.append("%s is missing file." % label)
		return
	if filename.find("..") >= 0 or filename.find("/") >= 0 or filename.find("\\") >= 0:
		validation_errors.append("%s file must stay inside its track folder." % label)
		return
	var lowered := filename.to_lower()
	if not lowered.ends_with(".wav") and not lowered.ends_with(".ogg"):
		validation_errors.append("%s file must be WAV or OGG: %s." % [label, filename])
		return
	var path := "%s/%s/%s" % [MUSIC_ASSET_ROOT, track_id, filename]
	if not FileAccess.file_exists(path):
		validation_errors.append("%s references missing file: %s." % [label, path])


func _validate_music_loop_asset(label: String, track_id: String, filename: String, loop_frames: int) -> void:
	if filename.is_empty() or filename.find("..") >= 0 or filename.find("/") >= 0 or filename.find("\\") >= 0:
		return
	if not filename.to_lower().ends_with(".wav"):
		return
	var path := "%s/%s/%s" % [MUSIC_ASSET_ROOT, track_id, filename]
	var info := _wav_info(path)
	if info.is_empty():
		return
	var sample_rate := int(info.get("sample_rate", 0))
	var data_frames := int(info.get("frames", 0))
	if sample_rate <= 0 or data_frames <= 0:
		return
	if loop_frames > data_frames:
		validation_errors.append("%s loop_frames %d exceeds WAV frame count %d." % [label, loop_frames, data_frames])
	var min_loop_frames := int(float(sample_rate) * MIN_AUTHORED_MUSIC_LOOP_SECONDS)
	if loop_frames < min_loop_frames:
		validation_errors.append("%s loop is %.1fs; authored room music must be at least %.1fs." % [label, float(loop_frames) / float(sample_rate), MIN_AUTHORED_MUSIC_LOOP_SECONDS])


static func _wav_info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return {}
	if _ascii_from_bytes(bytes, 0, 4) != "RIFF" or _ascii_from_bytes(bytes, 8, 4) != "WAVE":
		return {}
	var offset := 12
	var channels := 1
	var sample_rate := 0
	var bits_per_sample := 0
	var data_size := 0
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii_from_bytes(bytes, offset, 4)
		var chunk_size := _u32_le(bytes, offset + 4)
		var chunk_data := offset + 8
		if chunk_id == "fmt " and chunk_data + 16 <= bytes.size():
			channels = maxi(1, _u16_le(bytes, chunk_data + 2))
			sample_rate = maxi(1, _u32_le(bytes, chunk_data + 4))
			bits_per_sample = _u16_le(bytes, chunk_data + 14)
		elif chunk_id == "data":
			data_size = mini(chunk_size, bytes.size() - chunk_data)
			break
		offset = chunk_data + chunk_size + (chunk_size % 2)
	if sample_rate <= 0 or bits_per_sample <= 0 or data_size <= 0:
		return {}
	var bytes_per_sample := maxi(1, int(bits_per_sample / 8))
	var frame_bytes := maxi(1, channels * bytes_per_sample)
	return {
		"sample_rate": sample_rate,
		"channels": channels,
		"bits_per_sample": bits_per_sample,
		"frames": int(data_size / frame_bytes),
	}


static func _ascii_from_bytes(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars := PackedByteArray()
	chars.resize(length)
	for index in range(length):
		chars[index] = bytes[offset + index] if offset + index < bytes.size() else 0
	return chars.get_string_from_ascii()


static func _u16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 1 >= bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 3 >= bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)


static func _music_file_name(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		return str((value as Dictionary).get("file", "")).strip_edges()
	return str(value).strip_edges()


# Validates references from environments into active foundation packs.
func _validate_environment_references() -> void:
	var archetype_ids := _ids_for(environment_archetypes)
	var game_ids := _ids_for(games)
	var item_ids := _ids_for(items)
	var event_ids := _ids_for(events)
	var service_ids := _ids_for(services)
	var lender_ids := _ids_for(lenders)
	var route_ids := _ids_for(travel_routes)
	for archetype in environment_archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		_validate_environment_open_hours(archetype_id, archetype.get("open_hours", null))
		_validate_id_references("environment %s game_pool" % archetype_id, archetype.get("game_pool", []), game_ids)
		_validate_id_references("environment %s required_game_ids" % archetype_id, archetype.get("required_game_ids", []), game_ids)
		_validate_required_game_pool(archetype_id, archetype)
		_validate_id_references("environment %s item_pool" % archetype_id, archetype.get("item_pool", []), item_ids)
		_validate_id_references("environment %s event_pool" % archetype_id, archetype.get("event_pool", []), event_ids)
		_validate_id_references("environment %s service_pool" % archetype_id, archetype.get("service_pool", []), service_ids)
		_validate_id_references("environment %s lender_hooks" % archetype_id, archetype.get("lender_hooks", []), lender_ids)
		_validate_id_references("environment %s required_lender_hooks" % archetype_id, archetype.get("required_lender_hooks", []), lender_ids)
		_validate_count_range("environment %s lender_count" % archetype_id, archetype.get("lender_count", null), _string_array(archetype.get("lender_hooks", [])).size())
		_validate_id_references("environment %s travel_hooks" % archetype_id, archetype.get("travel_hooks", []), archetype_ids)
		if not route_ids.is_empty():
			_validate_id_references("environment %s travel_hooks route metadata" % archetype_id, archetype.get("travel_hooks", []), route_ids)
		_validate_id_references("environment %s next_archetypes" % archetype_id, archetype.get("next_archetypes", []), archetype_ids)
		var economic_profile: Dictionary = _as_dict(archetype.get("economic_profile", {}))
		var game_limit_overrides: Dictionary = _as_dict(economic_profile.get("game_stake_ceiling_overrides", {}))
		for game_id_value in game_limit_overrides.keys():
			var game_id := str(game_id_value).strip_edges()
			if game_id.is_empty():
				validation_errors.append("environment %s game_stake_ceiling_overrides contains an empty game id." % archetype_id)
			elif not game_ids.has(game_id):
				validation_errors.append("environment %s game_stake_ceiling_overrides references unknown game id: %s" % [archetype_id, game_id])
			if typeof(game_limit_overrides.get(game_id_value)) != TYPE_INT and typeof(game_limit_overrides.get(game_id_value)) != TYPE_FLOAT:
				validation_errors.append("environment %s game_stake_ceiling_overrides.%s must be numeric." % [archetype_id, game_id])
			elif int(game_limit_overrides.get(game_id_value, 0)) < 0:
				validation_errors.append("environment %s game_stake_ceiling_overrides.%s must be non-negative." % [archetype_id, game_id])
		var music_profile: Dictionary = _as_dict(archetype.get("music_profile", {}))
		var authored_track_id := str(music_profile.get("authored_track_id", "")).strip_edges()
		if not authored_track_id.is_empty() and music_track(authored_track_id).is_empty():
			validation_warnings.append("environment %s references unavailable authored_track_id %s; procedural music will be used." % [archetype_id, authored_track_id])


func _validate_environment_open_hours(archetype_id: String, value: Variant) -> void:
	if value == null:
		return
	if typeof(value) != TYPE_DICTIONARY:
		validation_errors.append("environment %s open_hours must be null or a dictionary." % archetype_id)
		return
	var hours: Dictionary = value
	for key in ["open_minute", "close_minute"]:
		if not hours.has(key):
			validation_errors.append("environment %s open_hours is missing %s." % [archetype_id, key])
			continue
		var minute_value: Variant = hours.get(key, 0)
		if not _variant_is_number(minute_value):
			validation_errors.append("environment %s open_hours.%s must be numeric." % [archetype_id, key])
			continue
		var minute := int(minute_value)
		if minute < 0 or minute > 1439:
			validation_errors.append("environment %s open_hours.%s must be between 0 and 1439." % [archetype_id, key])


func _validate_required_game_pool(archetype_id: String, archetype: Dictionary) -> void:
	var game_pool := _string_array(archetype.get("game_pool", []))
	for required_id in _string_array(archetype.get("required_game_ids", [])):
		if not game_pool.has(required_id):
			validation_errors.append("environment %s required_game_ids includes %s but game_pool does not." % [archetype_id, required_id])


func _validate_count_range(label: String, value: Variant, pool_size: int) -> void:
	if value == null:
		return
	var values: Array = []
	if typeof(value) == TYPE_ARRAY:
		values = value
	else:
		values = [value]
	if values.is_empty() or values.size() > 2:
		validation_errors.append("%s must be a number or two-number range." % label)
		return
	for count_value in values:
		if not _variant_is_number(count_value):
			validation_errors.append("%s must contain only numeric values." % label)
			return
	var min_count := int(values[0])
	var max_count := int(values[values.size() - 1])
	if min_count < 0 or max_count < 0:
		validation_errors.append("%s must be non-negative." % label)
	if min_count > max_count:
		validation_errors.append("%s minimum must not exceed maximum." % label)
	if max_count > pool_size:
		validation_errors.append("%s cannot exceed its source pool size." % label)


# Validates that every id in a reference array exists in the supplied index.
func _validate_id_references(label: String, ids: Variant, valid_ids: Dictionary) -> void:
	if typeof(ids) != TYPE_ARRAY:
		if typeof(ids) != TYPE_NIL:
			validation_errors.append("%s must be an array." % label)
		return
	for id_value in ids:
		var id := str(id_value).strip_edges()
		if id.is_empty():
			validation_errors.append("%s contains an empty id." % label)
		elif not valid_ids.has(id):
			validation_errors.append("%s references unknown id: %s" % [label, id])


# Builds an id set from a content array.
static func _ids_for(values: Array) -> Dictionary:
	var ids := {}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := str((value as Dictionary).get("id", "")).strip_edges()
		if not id.is_empty():
			ids[id] = true
	return ids


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry).strip_edges()
		if not id.is_empty() and not result.has(id):
			result.append(id)
	return result


static func _string_set(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for id in _string_array(value):
		result[id] = true
	return result


static func _definition_enabled_for_groups(definition: Dictionary, enabled_group_ids: Array) -> bool:
	if definition.is_empty():
		return false
	var groups := _string_array(definition.get("content_groups", []))
	if groups.is_empty():
		return true
	var enabled := _string_set(enabled_group_ids)
	for group_id in groups:
		if bool(enabled.get(group_id, false)):
			return true
	return false


static func _variant_is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


# Safely returns dictionary values.
static func _as_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


# Returns a dictionary by id through the cached lookup table.
func _lookup(index_name: String, values: Array, id: String) -> Dictionary:
	var index: Dictionary = _indexes.get(index_name, {})
	if index.size() != values.size() or not index.has(id):
		index = _index_by_id(values)
		_indexes[index_name] = index
	return index.get(id, {})


# Builds a dictionary keyed by content id.
static func _index_by_id(values: Array) -> Dictionary:
	var index := {}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := str(value.get("id", ""))
		if not id.is_empty():
			index[id] = value
	return index
