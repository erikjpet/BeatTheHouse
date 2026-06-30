class_name ContentLibrary
extends RefCounted

# Loads and validates README-defined foundation content packs.

const ENVIRONMENT_ARCHETYPES_PATH := "res://data/environments/archetypes.json"
const GAMES_PATH := "res://data/games/games.json"
const ITEMS_PATH := "res://data/items/items.json"
const EVENTS_PATH := "res://data/events/events.json"
const CHALLENGES_PATH := "res://data/challenges/challenges.json"
const LENDERS_PATH := "res://data/debt/lenders.json"
const SERVICES_PATH := "res://data/services/services.json"
const TRAVEL_ROUTES_PATH := "res://data/travel/routes.json"
const PRESTIGE_PURCHASES_PATH := "res://data/prestige/purchases.json"

var environment_archetypes: Array = []
var games: Array = []
var items: Array = []
var events: Array = []
var challenges: Array = []
var lenders: Array = []
var services: Array = []
var travel_routes: Array = []
var prestige_purchases: Array = []
var validation_errors: Array = []
var validation_warnings: Array = []
var _load_errors: Array = []
var _indexes: Dictionary = {}


# Returns the active README pack paths required by the foundation path.
static func required_pack_paths() -> Dictionary:
	return {
		"environment_archetypes": ENVIRONMENT_ARCHETYPES_PATH,
		"games": GAMES_PATH,
		"items": ITEMS_PATH,
		"events": EVENTS_PATH,
	}


# Returns future README pack paths that are known but optional until needed.
static func future_pack_paths() -> Dictionary:
	return {
		"challenges": CHALLENGES_PATH,
		"lenders": LENDERS_PATH,
		"services": SERVICES_PATH,
		"travel_routes": TRAVEL_ROUTES_PATH,
		"prestige_purchases": PRESTIGE_PURCHASES_PATH,
	}


# Loads the active packs and any future packs that already exist.
func load() -> Dictionary:
	_load_errors = []
	environment_archetypes = _load_array(ENVIRONMENT_ARCHETYPES_PATH, true)
	games = _load_array(GAMES_PATH, true)
	items = _load_array(ITEMS_PATH, true)
	events = _load_array(EVENTS_PATH, true)
	challenges = _load_array(CHALLENGES_PATH, false)
	lenders = _load_array(LENDERS_PATH, false)
	services = _load_array(SERVICES_PATH, false)
	travel_routes = _load_array(TRAVEL_ROUTES_PATH, false)
	prestige_purchases = _load_array(PRESTIGE_PURCHASES_PATH, false)
	_rebuild_indexes()
	validate()
	return {
		"environment_archetypes": environment_archetypes,
		"games": games,
		"items": items,
		"events": events,
		"challenges": challenges,
		"lenders": lenders,
		"services": services,
		"travel_routes": travel_routes,
		"prestige_purchases": prestige_purchases,
	}


# Validates loaded packs without reading demo runtime data.
func validate() -> Array:
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
	_validate_collection("events", events, [
		"id",
		"display_name",
		"type",
		"scopes",
		"trigger",
		"payload",
	])
	_validate_collection("challenges", challenges, ["id"])
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
	_validate_collection("prestige_purchases", prestige_purchases, [
		"id",
		"display_name",
		"description",
		"type",
		"cost",
		"requirements",
		"effect",
	])
	_validate_game_definitions()
	_validate_item_definitions()
	_validate_event_definitions()
	_validate_lender_definitions()
	_validate_service_definitions()
	_validate_travel_route_definitions()
	_validate_prestige_purchase_definitions()
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


# Finds an event definition by id.
func event(event_id: String) -> Dictionary:
	return _lookup("events", events, event_id)


# Finds a challenge definition by id.
func challenge(challenge_id: String) -> Dictionary:
	return _lookup("challenges", challenges, challenge_id)


# Finds a lender definition by id.
func lender(lender_id: String) -> Dictionary:
	return _lookup("lenders", lenders, lender_id)


# Finds a service definition by id.
func service(service_id: String) -> Dictionary:
	return _lookup("services", services, service_id)


# Finds a travel route definition by id.
func route(route_id: String) -> Dictionary:
	return _lookup("travel_routes", travel_routes, route_id)


# Finds a prestige purchase definition by id.
func prestige(purchase_id: String) -> Dictionary:
	return _lookup("prestige_purchases", prestige_purchases, purchase_id)


# Reads one JSON array content pack from disk.
func _load_array(path: String, required: bool) -> Array:
	if not FileAccess.file_exists(path):
		if required:
			_load_errors.append("Missing required content pack: %s" % path)
		return []
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		_load_errors.append("Content file must contain a JSON array: %s" % path)
		return []
	return parsed


# Rebuilds id indexes for loaded content arrays. Fixture tests can still assign
# arrays directly; _lookup refreshes a stale or missing index on demand.
func _rebuild_indexes() -> void:
	_indexes = {
		"games": _index_by_id(games),
		"items": _index_by_id(items),
		"events": _index_by_id(events),
		"challenges": _index_by_id(challenges),
		"lenders": _index_by_id(lenders),
		"services": _index_by_id(services),
		"travel_routes": _index_by_id(travel_routes),
		"prestige_purchases": _index_by_id(prestige_purchases),
	}


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
	for game_def in games:
		if typeof(game_def) != TYPE_DICTIONARY:
			continue
		var game_id := str(game_def.get("id", "")).strip_edges()
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
	for item_def in items:
		if typeof(item_def) != TYPE_DICTIONARY:
			continue
		var item_id := str(item_def.get("id", "")).strip_edges()
		if int(item_def.get("price_min", 0)) > int(item_def.get("price_max", 0)):
			validation_errors.append("items %s has price_min greater than price_max." % item_id)
		if typeof(item_def.get("effect", {})) != TYPE_DICTIONARY:
			validation_errors.append("items %s effect must be a dictionary." % item_id)
		_validate_art_asset("items %s" % item_id, item_def)
		if str(item_def.get("icon_key", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing icon_key." % item_id)
		if str(item_def.get("environment_prop", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing environment_prop." % item_id)
		if str(item_def.get("surface", "")).strip_edges().is_empty():
			validation_errors.append("items %s is missing surface." % item_id)


# Validates event choice payloads and route references inside consequences.
func _validate_event_definitions() -> void:
	var archetype_ids := _ids_for(environment_archetypes)
	for event_def in events:
		if typeof(event_def) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_def.get("id", "")).strip_edges()
		_validate_art_asset("events %s" % event_id, event_def)
		var icon_key := str(event_def.get("icon_key", "")).strip_edges()
		if icon_key.is_empty():
			validation_errors.append("events %s is missing icon_key." % event_id)
		elif icon_key == "event":
			validation_errors.append("events %s must not use the generic event icon_key." % event_id)
		if str(event_def.get("environment_prop", "")).strip_edges().is_empty():
			validation_errors.append("events %s is missing environment_prop." % event_id)
		if str(event_def.get("start_summary", "")).strip_edges().is_empty():
			validation_errors.append("events %s is missing start_summary." % event_id)
		var payload: Variant = event_def.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			validation_errors.append("events %s payload must be a dictionary." % event_id)
			continue
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
		if route_def.has("requires_travel_count_min") and int(route_def.get("requires_travel_count_min", 0)) < 0:
			validation_errors.append("travel_routes %s requires_travel_count_min must be non-negative." % route_id)
		if route_def.has("hide_until_travel_count_met") and typeof(route_def.get("hide_until_travel_count_met", false)) != TYPE_BOOL:
			validation_errors.append("travel_routes %s hide_until_travel_count_met must be a boolean." % route_id)
		var destination := str(route_def.get("destination_archetype", "")).strip_edges()
		if destination.is_empty():
			validation_errors.append("travel_routes %s is missing destination_archetype." % route_id)
		elif not archetype_ids.has(destination):
			validation_errors.append("travel_routes %s references unknown destination_archetype: %s" % [route_id, destination])


# Validates prestige targets without expanding victory systems.
func _validate_prestige_purchase_definitions() -> void:
	for purchase_def in prestige_purchases:
		if typeof(purchase_def) != TYPE_DICTIONARY:
			continue
		var purchase_id := str(purchase_def.get("id", "")).strip_edges()
		if int(purchase_def.get("cost", 0)) < 0:
			validation_errors.append("prestige_purchases %s cost must be non-negative." % purchase_id)
		if typeof(purchase_def.get("requirements", {})) != TYPE_DICTIONARY:
			validation_errors.append("prestige_purchases %s requirements must be a dictionary." % purchase_id)
		if typeof(purchase_def.get("effect", {})) != TYPE_DICTIONARY:
			validation_errors.append("prestige_purchases %s effect must be a dictionary." % purchase_id)


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
		_validate_id_references("environment %s game_pool" % archetype_id, archetype.get("game_pool", []), game_ids)
		_validate_id_references("environment %s required_game_ids" % archetype_id, archetype.get("required_game_ids", []), game_ids)
		_validate_required_game_pool(archetype_id, archetype)
		_validate_id_references("environment %s item_pool" % archetype_id, archetype.get("item_pool", []), item_ids)
		_validate_id_references("environment %s event_pool" % archetype_id, archetype.get("event_pool", []), event_ids)
		_validate_id_references("environment %s service_pool" % archetype_id, archetype.get("service_pool", []), service_ids)
		_validate_id_references("environment %s lender_hooks" % archetype_id, archetype.get("lender_hooks", []), lender_ids)
		_validate_id_references("environment %s travel_hooks" % archetype_id, archetype.get("travel_hooks", []), archetype_ids)
		if not route_ids.is_empty():
			_validate_id_references("environment %s travel_hooks route metadata" % archetype_id, archetype.get("travel_hooks", []), route_ids)
		_validate_id_references("environment %s next_archetypes" % archetype_id, archetype.get("next_archetypes", []), archetype_ids)


func _validate_required_game_pool(archetype_id: String, archetype: Dictionary) -> void:
	var game_pool := _string_array(archetype.get("game_pool", []))
	for required_id in _string_array(archetype.get("required_game_ids", [])):
		if not game_pool.has(required_id):
			validation_errors.append("environment %s required_game_ids includes %s but game_pool does not." % [archetype_id, required_id])


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
