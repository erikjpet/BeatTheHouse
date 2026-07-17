class_name EnvironmentInstance
extends RefCounted

# One generated location, regardless of venue type.

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")

const ENVIRONMENT_BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
const GENERATED_LAYOUT_VERSION := 10
const EMPTY_MUSIC_NOTE := -999
const SALS_PAWN_COUNTER_ID := "sals_pawn_counter"
const PAWN_SHOP_ARCHETYPE_ID := "pawn_shop"

var id: String = ""
var archetype_id: String = ""
var world_node_id: String = ""
var world_map_travel: bool = false
var kind: String = ""
var display_name: String = ""
var tier: int = 1
var depth: int = 0
var art_key: String = ""
var visual_context: Dictionary = {}
var layout: Dictionary = {}
var security_profile: Dictionary = {}
var music_profile: Dictionary = {}
var economic_profile: Dictionary = {}
var objective_hint: String = ""
var demo_objective: Dictionary = {}
var game_ids: Array = []
var game_states: Dictionary = {}
var event_ids: Array = []
var item_offers: Array = []
var home_profile: Dictionary = {}
var home_containers: Array = []
var home_container_index: int = 0
var home_lost: bool = false
var parent_archetype: String = ""
var service_ids: Array = []
var lender_hooks: Array = []
var suspicion_cues: Array = []
var travel_hooks: Array = []
var next_archetypes: Array = []
var object_fixtures: Array = []
var local_narrative_flags: Dictionary = {}
var mood: String = ""
var turns: int = 0
var resolved_event_ids: Array = []
var travel_locked_actions: int = 0
var travel_lock_remaining: int = 0


# Builds one environment from an archetype and content library.
static func from_archetype(archetype: Dictionary, p_depth: int, rng: RngStream, library: ContentLibrary = null, challenge_config: Dictionary = {}) -> EnvironmentInstance:
	if library != null:
		archetype = library.environment_archetype_for_challenge(archetype, challenge_config)
	var environment := EnvironmentInstance.new()
	environment.depth = p_depth
	environment.tier = int(archetype.get("tier", 1))
	environment.kind = archetype.get("kind", "unknown")
	environment.archetype_id = archetype.get("id", "unknown")
	environment.id = "%s_%03d" % [environment.archetype_id, p_depth + 1]
	environment.display_name = _build_name(archetype, rng)
	environment.art_key = _art_key(archetype)
	environment.visual_context = _simulation_visual_context(archetype, environment.art_key)
	environment.layout = _generated_layout_variant(archetype, rng.fork("layout:%s" % environment.id))
	environment.security_profile = _copy_dict(archetype.get("security_profile", {}))
	environment.music_profile = _generated_music_profile(archetype, environment, rng)
	environment.economic_profile = _copy_dict(archetype.get("economic_profile", {}))
	environment.objective_hint = str(archetype.get("objective_hint", ""))
	environment.demo_objective = _copy_dict(archetype.get("demo_objective", {}))
	var game_pool := _filtered_game_pool(archetype, library, challenge_config)
	var required_games := _filtered_required_games(archetype, game_pool)
	environment.game_ids = _pick_ids_with_required(game_pool, archetype.get("game_count", 1), required_games, rng)
	environment.game_states = {}
	environment.event_ids = _pick_events(archetype, rng.fork("events:%s" % environment.id), library)
	environment.item_offers = _build_offers(archetype, rng, library, challenge_config)
	environment.home_profile = _copy_dict(archetype.get("home_profile", {}))
	environment.home_containers = []
	environment.parent_archetype = str(archetype.get("parent_archetype", ""))
	environment.service_ids = _copy_array(archetype.get("service_pool", []))
	environment.lender_hooks = _pick_lenders(archetype, rng.fork("lenders:%s" % environment.id))
	environment.suspicion_cues = _copy_array(archetype.get("suspicion_cues", environment.security_profile.get("visible_cues", [])))
	environment.travel_hooks = _copy_array(archetype.get("travel_hooks", []))
	environment.next_archetypes = _copy_array(archetype.get("next_archetypes", []))
	environment.object_fixtures = _copy_array(archetype.get("object_fixtures", []))
	var rare_route_rng := rng.fork("rare_next:%s" % environment.id)
	_append_rare_archetypes(environment.next_archetypes, archetype, rare_route_rng)
	environment.local_narrative_flags = _copy_dict(archetype.get("local_narrative_flags", {}))
	environment.mood = rng.pick(archetype.get("moods", ["watchful"]), "watchful")
	environment.travel_locked_actions = maxi(0, int(archetype.get("travel_locked_actions", 0)))
	environment.travel_lock_remaining = environment.travel_locked_actions
	environment.layout = ensure_generated_layout(environment.to_dict())
	return environment


# Restores a generated environment from saveable data.
static func from_dict(data: Dictionary) -> EnvironmentInstance:
	var environment := EnvironmentInstance.new()
	environment.id = str(data.get("id", ""))
	environment.archetype_id = str(data.get("archetype_id", ""))
	environment.world_node_id = str(data.get("world_node_id", environment.archetype_id)).strip_edges()
	environment.world_map_travel = bool(data.get("world_map_travel", false))
	environment.kind = str(data.get("kind", ""))
	environment.display_name = str(data.get("display_name", ""))
	environment.tier = int(data.get("tier", 1))
	environment.depth = int(data.get("depth", 0))
	environment.art_key = str(data.get("art_key", _copy_dict(data.get("visual_context", {})).get("art_key", "")))
	environment.visual_context = _strip_presentation_paths(_copy_dict(data.get("visual_context", {})), environment.art_key)
	environment.layout = ensure_generated_layout(data)
	environment.security_profile = _copy_dict(data.get("security_profile", {}))
	environment.music_profile = _copy_dict(data.get("music_profile", {}))
	environment.economic_profile = _copy_dict(data.get("economic_profile", {}))
	environment.objective_hint = str(data.get("objective_hint", ""))
	environment.demo_objective = _copy_dict(data.get("demo_objective", {}))
	environment.game_ids = _copy_array(data.get("game_ids", []))
	environment.game_states = _copy_dict(data.get("game_states", {}))
	environment.event_ids = _copy_array(data.get("event_ids", []))
	environment.item_offers = _copy_array(data.get("item_offers", []))
	environment.home_profile = _copy_dict(data.get("home_profile", {}))
	environment.home_containers = _copy_array(data.get("home_containers", []))
	environment.home_container_index = maxi(0, int(data.get("home_container_index", 0)))
	environment.home_lost = bool(data.get("home_lost", false))
	environment.parent_archetype = str(data.get("parent_archetype", ""))
	environment.service_ids = _copy_array(data.get("service_ids", []))
	environment.lender_hooks = _copy_array(data.get("lender_hooks", []))
	environment.suspicion_cues = _copy_array(data.get("suspicion_cues", []))
	environment.travel_hooks = _copy_array(data.get("travel_hooks", []))
	environment.next_archetypes = _copy_array(data.get("next_archetypes", []))
	environment.object_fixtures = _copy_array(data.get("object_fixtures", []))
	environment.local_narrative_flags = _copy_dict(data.get("local_narrative_flags", {}))
	environment.mood = str(data.get("mood", ""))
	environment.turns = int(data.get("turns", 0))
	environment.resolved_event_ids = _copy_array(data.get("resolved_event_ids", []))
	environment.travel_locked_actions = maxi(0, int(data.get("travel_locked_actions", 0)))
	environment.travel_lock_remaining = maxi(0, int(data.get("travel_lock_remaining", environment.travel_locked_actions)))
	return environment


# Converts the environment to saveable data.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"archetype_id": archetype_id,
		"world_node_id": world_node_id,
		"world_map_travel": world_map_travel,
		"kind": kind,
		"display_name": display_name,
		"tier": tier,
		"depth": depth,
		"art_key": art_key,
		"visual_context": visual_context.duplicate(true),
		"layout": layout.duplicate(true),
		"security_profile": security_profile.duplicate(true),
		"music_profile": music_profile.duplicate(true),
		"economic_profile": economic_profile.duplicate(true),
		"objective_hint": objective_hint,
		"demo_objective": demo_objective.duplicate(true),
		"game_ids": game_ids.duplicate(true),
		"game_states": game_states.duplicate(true),
		"event_ids": event_ids.duplicate(true),
		"item_offers": item_offers.duplicate(true),
		"home_profile": home_profile.duplicate(true),
		"home_containers": home_containers.duplicate(true),
		"home_container_index": home_container_index,
		"home_lost": home_lost,
		"parent_archetype": parent_archetype,
		"service_ids": service_ids.duplicate(true),
		"lender_hooks": lender_hooks.duplicate(true),
		"suspicion_cues": suspicion_cues.duplicate(true),
		"travel_hooks": travel_hooks.duplicate(true),
		"next_archetypes": next_archetypes.duplicate(true),
		"object_fixtures": object_fixtures.duplicate(true),
		"local_narrative_flags": local_narrative_flags.duplicate(true),
		"mood": mood,
		"turns": turns,
		"resolved_event_ids": resolved_event_ids.duplicate(true),
		"travel_locked_actions": travel_locked_actions,
		"travel_lock_remaining": travel_lock_remaining,
	}


# Ensures a generated environment owns stable object placement keyed by object id.
static func ensure_generated_layout(environment_data: Dictionary) -> Dictionary:
	var layout := _copy_dict(environment_data.get("layout", {}))
	var object_rects := _copy_dict(layout.get("object_rects", {}))
	if int(layout.get("generated_object_rect_version", 0)) != GENERATED_LAYOUT_VERSION:
		object_rects = {}
	var include_route_travel_rects := not bool(environment_data.get("world_map_travel", false))
	var active_entries := _active_object_layout_entries(environment_data)
	var active_object_ids := _active_object_ids_from_entries(active_entries)
	var prioritize_services := bool(layout.get("prioritize_service_spots", false))
	_prune_inactive_object_rects(object_rects, active_object_ids)
	_assign_string_object_rects(object_rects, layout, "game", _copy_array(environment_data.get("game_ids", [])), "game_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "event", _copy_array(environment_data.get("event_ids", [])), "event_spots", active_object_ids)
	if not prioritize_services:
		_assign_item_offer_rects(object_rects, layout, _copy_array(environment_data.get("item_offers", [])), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "shopkeeper:merchant", "shopkeeper", 0, "shopkeeper_spots", _shopkeeper_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "travel:leave", "travel", 0, "travel_spots", not _travel_target_ids(environment_data).is_empty(), active_object_ids)
	_assign_string_object_rects(object_rects, layout, "casino_fixture", _casino_fixture_ids(environment_data), "casino_fixture_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "travel", _grand_casino_local_target_ids(environment_data), "casino_door_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "service", _copy_array(environment_data.get("service_ids", [])), "service_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "lender", _copy_array(environment_data.get("lender_hooks", [])), "lender_spots", active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _filter_unique_object_layout_entries(_game_hook_layout_entries(environment_data)), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_tenure:status", "home_tenure", 0, "home_tenure_spots", _home_tenure_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_sleep:bed", "home_sleep", 0, "home_sleep_spots", _home_sleep_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_storage:place", "home_storage", 0, "home_storage_spots", _home_storage_should_exist(environment_data), active_object_ids)
	_assign_string_object_rects(object_rects, layout, "home_container", _home_container_ids(environment_data), "home_container_spots", active_object_ids)
	if prioritize_services:
		_assign_item_offer_rects(object_rects, layout, _copy_array(environment_data.get("item_offers", [])), active_object_ids)
	_resolve_active_object_rect_collisions(object_rects, layout, active_entries)
	if include_route_travel_rects:
		var route_active_ids := active_object_ids.duplicate(true)
		for target_id in _travel_target_ids(environment_data):
			route_active_ids["travel:%s" % target_id] = true
		_assign_string_object_rects(object_rects, layout, "travel", _travel_target_ids(environment_data), "travel_spots", route_active_ids)
	layout["object_rects"] = object_rects
	layout["generated_object_rect_version"] = GENERATED_LAYOUT_VERSION
	return layout


# Creates a generated display name from archetype name parts.
static func _build_name(archetype: Dictionary, rng: RngStream) -> String:
	var prefixes: Array = archetype.get("name_prefixes", ["Unnamed"])
	var nouns: Array = archetype.get("name_nouns", ["Room"])
	return "%s %s" % [rng.pick(prefixes, "Unnamed"), rng.pick(nouns, "Room")]


# Adds rare route hooks with deterministic per-instance odds.
static func _append_rare_archetypes(target: Array, archetype: Dictionary, rng: RngStream) -> void:
	var rare_ids := _string_array(archetype.get("rare_next_archetypes", []))
	if rare_ids.is_empty():
		return
	var chance := clampi(int(archetype.get("rare_next_chance_percent", 8)), 0, 100)
	if chance <= 0 or rng.randi_range(1, 100) > chance:
		return
	for archetype_id in rare_ids:
		if not target.has(archetype_id):
			target.append(archetype_id)


# Generates one saved composition profile for venues that request unique music.
static func _generated_music_profile(archetype: Dictionary, environment: EnvironmentInstance, rng: RngStream) -> Dictionary:
	var profile := _copy_dict(archetype.get("music_profile", {}))
	if str(profile.get("procedural_variant", "")) != "jazz_club":
		return profile
	var progression_options := [
		[0, 3, 4, 5],
		[0, 5, 3, 4],
		[0, 2, 5, 4],
		[0, 6, 3, 5],
	]
	var mode_options := ["dorian", "minor", "harmonic_minor"]
	var texture_options := ["jazz", "funk_jazz"]
	var root_options := [41, 43, 46, 48, 50]
	var title_prefixes := ["Blue", "Velvet", "After Hours", "Fifth Street", "Midnight"]
	var title_nouns := ["Turnaround", "Pocket", "Standard", "Break", "Cadence"]
	var progression_value: Variant = rng.pick(progression_options, [0, 3, 4, 5])
	var progression: Array = [0, 3, 4, 5]
	if typeof(progression_value) == TYPE_ARRAY:
		progression = (progression_value as Array).duplicate(true)
	var motif := _generated_jazz_motif(rng)
	profile["theme"] = "classical jazz club"
	profile["texture"] = str(rng.pick(texture_options, "jazz"))
	profile["mode"] = str(rng.pick(mode_options, "dorian"))
	profile["bpm"] = rng.randi_range(88, 116)
	profile["root_midi"] = int(rng.pick(root_options, 46))
	profile["progression"] = progression.duplicate(true)
	profile["motif"] = motif
	profile["arrangement_phrases"] = rng.randi_range(4, 6)
	profile["generated_title"] = "%s %s" % [str(rng.pick(title_prefixes, "Blue")), str(rng.pick(title_nouns, "Standard"))]
	profile["generated_signature"] = "%s:%s:%d:%s:%s" % [
		str(environment.id),
		str(profile.get("mode", "")),
		int(profile.get("root_midi", 0)),
		JSON.stringify(profile.get("progression", [])),
		JSON.stringify(profile.get("motif", [])),
	]
	return profile


static func _generated_jazz_motif(rng: RngStream) -> Array:
	var degrees := [0, 1, 2, 3, 4, 5, 6, 7]
	var motif: Array = []
	for index in range(16):
		if index % 4 == 3 and rng.randi_range(1, 100) <= 72:
			motif.append(EMPTY_MUSIC_NOTE)
		elif index % 2 == 1 and rng.randi_range(1, 100) <= 42:
			motif.append(EMPTY_MUSIC_NOTE)
		else:
			motif.append(int(rng.pick(degrees, 0)))
	return motif


# Returns the presentation manifest key for this environment.
static func _art_key(archetype: Dictionary) -> String:
	var visual := _copy_dict(archetype.get("visual_context", {}))
	var key := str(archetype.get("art_key", visual.get("art_key", "")))
	if not key.is_empty():
		return key
	return str(archetype.get("id", "unknown"))


# Keeps first-person visual identity in simulation without concrete asset paths.
static func _simulation_visual_context(archetype: Dictionary, p_art_key: String) -> Dictionary:
	return _strip_presentation_paths(_copy_dict(archetype.get("visual_context", {})), p_art_key)


# Builds the per-instance room layout variant. Authored object families stay in their
# authored zones, while encounters can trade spots between runs.
static func _generated_layout_variant(archetype: Dictionary, rng: RngStream) -> Dictionary:
	var layout := _copy_dict(archetype.get("layout", {}))
	var randomized_fields := _string_array(archetype.get("randomized_spot_fields", ["event_spots", "lender_spots"]))
	for field_name_value in randomized_fields:
		var field_name := str(field_name_value)
		var spots := _copy_array(layout.get(field_name, []))
		if spots.size() > 1:
			layout[field_name] = rng.pick_many(spots, spots.size())
	return layout


# Removes presentation-only paths from generated environment state.
static func _strip_presentation_paths(visual: Dictionary, p_art_key: String) -> Dictionary:
	visual.erase("asset_path")
	visual.erase("scene_asset_path")
	visual["art_key"] = p_art_key
	return visual


# Builds priced item offers from the archetype item pool.
static func _build_offers(archetype: Dictionary, rng: RngStream, library: ContentLibrary, challenge_config: Dictionary = {}) -> Array:
	if library == null:
		return []
	var offers: Array = []
	var economic_profile := _copy_dict(archetype.get("economic_profile", {}))
	var price_multiplier := 1.0
	if economic_profile.has("shop_price_multiplier"):
		price_multiplier = clampf(float(economic_profile.get("shop_price_multiplier", 1.0)), 0.5, 1.5)
	var sale_price_multiplier := maxf(0.0, float(economic_profile.get("shop_sale_price_multiplier", 0.0)))
	var item_pool := library.shop_item_pool_for_challenge(archetype.get("item_pool", []), challenge_config)
	var item_ids := _pick_ids(item_pool, archetype.get("item_count", 0), rng)
	for item_id in item_ids:
		var item := library.item(item_id)
		if item.is_empty():
			continue
		var min_price := int(item.get("price_min", 1))
		var max_price := int(item.get("price_max", min_price))
		var price := rng.randi_range(min_price, max_price)
		if not is_equal_approx(price_multiplier, 1.0):
			price = maxi(1, int(floor(float(price) * price_multiplier)))
		if sale_price_multiplier > 0.0:
			var sale_price := _item_sale_price(item)
			price = maxi(1, int(ceil(float(sale_price) * sale_price_multiplier)))
		offers.append({
			"id": item_id,
			"display_name": item.get("display_name", item_id),
			"price": price,
			"price_min": min_price,
			"price_max": max_price,
		})
	return offers


static func _item_sale_price(item: Dictionary) -> int:
	if item.has("sale_price"):
		return maxi(0, int(item.get("sale_price", 0)))
	var price_min := int(item.get("price_min", 0))
	var price_max := int(item.get("price_max", price_min))
	return maxi(0, int(round(float(price_min + price_max) * 0.25)))


static func _filtered_game_pool(archetype: Dictionary, library: ContentLibrary, challenge_config: Dictionary = {}) -> Array:
	var pool := _copy_array(archetype.get("game_pool", []))
	if library == null:
		return _string_array(pool)
	return library.filter_game_ids_for_challenge(pool, challenge_config)


static func _filtered_required_games(archetype: Dictionary, filtered_pool: Array) -> Array:
	var required: Array = []
	for required_id in _string_array(archetype.get("required_game_ids", [])):
		if filtered_pool.has(required_id):
			required.append(required_id)
	return required


# Picks a per-instance subset of lender hooks when the archetype declares a count.
static func _pick_lenders(archetype: Dictionary, rng: RngStream) -> Array:
	var pool := _string_array(archetype.get("lender_hooks", []))
	var archetype_id := str(archetype.get("id", "")).strip_edges()
	if archetype_id != PAWN_SHOP_ARCHETYPE_ID:
		pool.erase(SALS_PAWN_COUNTER_ID)
	if pool.is_empty():
		return []
	if not archetype.has("lender_count"):
		return rng.pick_many(pool, pool.size())
	var required_lenders := _string_array(archetype.get("required_lender_hooks", []))
	if archetype_id != PAWN_SHOP_ARCHETYPE_ID:
		required_lenders.erase(SALS_PAWN_COUNTER_ID)
	var selected := _pick_ids_with_required(pool, archetype.get("lender_count", pool.size()), required_lenders, rng)
	return rng.pick_many(selected, selected.size())


# Picks event ids that match the environment scopes.
static func _pick_events(archetype: Dictionary, rng: RngStream, library: ContentLibrary) -> Array:
	if library == null:
		var fallback_events := _pick_ids(archetype.get("event_pool", []), archetype.get("event_count", 1), rng)
		return rng.pick_many(fallback_events, fallback_events.size())
	var pool: Array = archetype.get("event_pool", [])
	var scopes: Array = archetype.get("event_scopes", [])
	var candidates: Array = []
	for event in library.events:
		var event_id: String = event.get("id", "")
		if event_id.is_empty():
			continue
		if str(event.get("interaction_mode", "interactable")) != "interactable":
			continue
		if not pool.is_empty() and not pool.has(event_id):
			continue
		if _event_fits(event, scopes):
			candidates.append(event_id)
	var required_events: Array = []
	for required_id in _string_array(archetype.get("required_event_ids", [])):
		if candidates.has(required_id):
			required_events.append(required_id)
	var picked_events := _filter_unique_event_ids(_pick_ids_with_required(candidates, archetype.get("event_count", 1), required_events, rng), library)
	return rng.pick_many(picked_events, picked_events.size())


static func _filter_unique_event_ids(event_ids: Array, library: ContentLibrary) -> Array:
	if library == null:
		return event_ids
	var result: Array = []
	var class_indexes: Dictionary = {}
	for event_id_value in event_ids:
		var event_id := str(event_id_value).strip_edges()
		if event_id.is_empty():
			continue
		var event := library.event(event_id)
		var unique_class := str(event.get("unique_object_class", "")).strip_edges()
		if unique_class.is_empty() or bool(event.get("allow_duplicate_unique_class", false)):
			result.append(event_id)
			continue
		if not class_indexes.has(unique_class):
			class_indexes[unique_class] = result.size()
			result.append(event_id)
			continue
		var existing_index := int(class_indexes[unique_class])
		var existing_id := str(result[existing_index])
		var existing := library.event(existing_id)
		if int(event.get("unique_object_priority", 0)) > int(existing.get("unique_object_priority", 0)):
			result[existing_index] = event_id
	return result


# Checks whether an event can appear in the environment scopes.
static func _event_fits(event: Dictionary, scopes: Array) -> bool:
	var event_scopes: Array = event.get("scopes", [])
	if event_scopes.has("any"):
		return true
	for scope in scopes:
		if event_scopes.has(scope):
			return true
	return false


# Picks a fixed or ranged number of unique ids from a pool.
static func _pick_ids(pool: Array, requested_count: Variant, rng: RngStream) -> Array:
	var count := _count(requested_count, rng)
	return rng.pick_many(pool, max(0, count))


# Picks unique ids while preserving explicit must-spawn ids.
static func _pick_ids_with_required(pool: Array, requested_count: Variant, required_ids: Variant, rng: RngStream) -> Array:
	var normalized_pool := _string_array(pool)
	var required: Array = []
	for required_id in _string_array(required_ids):
		if normalized_pool.has(required_id) and not required.has(required_id):
			required.append(required_id)
	var count := maxi(_count(requested_count, rng), required.size())
	var remaining_pool: Array = []
	for pool_id in normalized_pool:
		if not required.has(pool_id):
			remaining_pool.append(pool_id)
	var picks := rng.pick_many(remaining_pool, maxi(0, count - required.size()))
	var selected := {}
	for required_id in required:
		selected[required_id] = true
	for pick_value in picks:
		var pick_id := str(pick_value)
		if not pick_id.is_empty():
			selected[pick_id] = true
	var result: Array = []
	for pool_id in normalized_pool:
		if bool(selected.get(pool_id, false)):
			result.append(pool_id)
	return result


# Resolves a fixed count or random count range.
static func _count(requested_count: Variant, rng: RngStream) -> int:
	if typeof(requested_count) == TYPE_ARRAY:
		var range_values: Array = requested_count
		if range_values.size() >= 2:
			return rng.randi_range(int(range_values[0]), int(range_values[1]))
	return int(requested_count)


# Assigns stable rects to simple string-id object families.
static func _assign_string_object_rects(object_rects: Dictionary, layout: Dictionary, object_type: String, ids: Array, spot_field: String, active_object_ids: Dictionary) -> void:
	var stable_ids := _string_array(ids)
	for index in range(stable_ids.size()):
		_assign_single_object_rect(object_rects, layout, "%s:%s" % [object_type, stable_ids[index]], object_type, index, spot_field, true, active_object_ids)


static func _assign_object_layout_entries(object_rects: Dictionary, layout: Dictionary, entries: Array, active_object_ids: Dictionary) -> void:
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		_assign_single_object_rect(
			object_rects,
			layout,
			str(entry.get("object_id", "")),
			str(entry.get("object_type", "")),
			int(entry.get("index", 0)),
			str(entry.get("spot_field", "")),
			true,
			active_object_ids
		)


# Assigns stable rects to generated item offers by item id.
static func _assign_item_offer_rects(object_rects: Dictionary, layout: Dictionary, offers: Array, active_object_ids: Dictionary) -> void:
	var item_ids: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty() and not item_ids.has(item_id):
			item_ids.append(item_id)
	for index in range(item_ids.size()):
		_assign_single_object_rect(object_rects, layout, "item:%s" % item_ids[index], "item", index, "item_spots", true, active_object_ids)


# Assigns one object rect without disturbing an existing generated rect.
static func _assign_single_object_rect(object_rects: Dictionary, layout: Dictionary, object_id: String, object_type: String, index: int, spot_field: String, should_assign: bool, active_object_ids: Dictionary) -> void:
	if not should_assign or object_id.is_empty() or object_rects.has(object_id):
		return
	var rect := _object_rect_from_layout(layout, object_type, index, spot_field)
	rect = _first_available_object_rect(object_rects, active_object_ids, object_id, layout, object_type, index, spot_field, rect)
	object_rects[object_id] = _rect_to_dict(rect)


# Keeps late-added objects from taking a spot already owned by a persistent object.
static func _first_available_object_rect(object_rects: Dictionary, active_object_ids: Dictionary, object_id: String, layout: Dictionary, object_type: String, index: int, spot_field: String, desired_rect: Rect2) -> Rect2:
	if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, desired_rect):
		return desired_rect
	var slot_count := maxi(maxi(_layout_spot_count(layout, spot_field), index + 1), 8)
	for slot_index in range(slot_count):
		var candidate := _object_rect_from_layout(layout, object_type, slot_index, spot_field)
		if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, candidate):
			return candidate
	for candidate_value in _fallback_grid_object_rects(object_type, index, desired_rect):
		var candidate: Rect2 = candidate_value
		if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, candidate):
			return candidate
	return desired_rect


static func _layout_spot_count(layout: Dictionary, spot_field: String) -> int:
	if spot_field.is_empty():
		return 0
	var spots: Variant = layout.get(spot_field, [])
	if typeof(spots) != TYPE_ARRAY:
		return 0
	return (spots as Array).size()


static func _object_rect_collides_with_active(object_rects: Dictionary, active_object_ids: Dictionary, object_id: String, rect: Rect2) -> bool:
	for key in object_rects.keys():
		var existing_id := str(key)
		if existing_id == object_id or not bool(active_object_ids.get(existing_id, false)):
			continue
		var existing_rect := _rect_from_dict(object_rects.get(key, {}))
		if existing_rect.size.x <= 0.0 or existing_rect.size.y <= 0.0:
			continue
		if _rects_overlap_with_layout_gap(existing_rect, rect):
			return true
	return false


static func _rects_overlap_with_layout_gap(a: Rect2, b: Rect2) -> bool:
	var gap := Vector2(8.0 / ENVIRONMENT_BOARD_SIZE.x, 8.0 / ENVIRONMENT_BOARD_SIZE.y)
	var a_padded := Rect2(a.position - gap, a.size + gap * 2.0)
	var b_padded := Rect2(b.position - gap, b.size + gap * 2.0)
	return a_padded.intersects(b_padded)


# Returns authored spot placement when available, otherwise the generated fallback slot.
static func _object_rect_from_layout(layout: Dictionary, object_type: String, index: int, spot_field: String) -> Rect2:
	var fallback_rect := _fallback_object_rect(object_type, index)
	var spot := _layout_spot(layout, spot_field, index)
	if spot.x < 0.0 or spot.y < 0.0:
		return fallback_rect
	var center := Vector2(
		clampf(spot.x / ENVIRONMENT_BOARD_SIZE.x, 0.0, 1.0),
		clampf(spot.y / ENVIRONMENT_BOARD_SIZE.y, 0.0, 1.0)
	)
	return _clamped_rect_from_center(center, fallback_rect.size)


# Mirrors the foundation UI fallback slots so generated layouts remain stable without authored spots.
static func _fallback_object_rect(object_type: String, index: int) -> Rect2:
	var center := Vector2(0.5, 0.5)
	var size := Vector2(0.12, 0.18)
	match object_type:
		"game":
			center = Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13)
			size = Vector2(118.0 / ENVIRONMENT_BOARD_SIZE.x, 72.0 / ENVIRONMENT_BOARD_SIZE.y)
		"event":
			center = Vector2(0.68 + float(index % 2) * 0.12, 0.42 + float(index / 2) * 0.14)
			size = Vector2(100.0 / ENVIRONMENT_BOARD_SIZE.x, 64.0 / ENVIRONMENT_BOARD_SIZE.y)
		"item":
			var item_columns := 5
			center = Vector2(0.20 + float(index % item_columns) * 0.15, 0.36 + float(index / item_columns) * 0.14)
			size = Vector2(90.0 / ENVIRONMENT_BOARD_SIZE.x, 54.0 / ENVIRONMENT_BOARD_SIZE.y)
		"shopkeeper":
			center = Vector2(0.80, 0.34)
			size = Vector2(108.0 / ENVIRONMENT_BOARD_SIZE.x, 70.0 / ENVIRONMENT_BOARD_SIZE.y)
		"game_hook":
			var hook_columns := 5
			center = Vector2(0.18 + float(index % hook_columns) * 0.16, 0.82 - float(index / hook_columns) * 0.14)
			size = Vector2(104.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"travel":
			var travel_centers := [
				Vector2(0.84, 0.34),
				Vector2(0.84, 0.60),
				Vector2(0.50, 0.18),
				Vector2(0.50, 0.50),
				Vector2(0.30, 0.28),
				Vector2(0.30, 0.78),
				Vector2(0.64, 0.30),
				Vector2(0.64, 0.70),
				Vector2(0.84, 0.84),
			]
			center = travel_centers[index % travel_centers.size()]
			size = Vector2(118.0 / ENVIRONMENT_BOARD_SIZE.x, 64.0 / ENVIRONMENT_BOARD_SIZE.y)
		"service":
			var service_columns := 6
			center = Vector2(0.14 + float(index % service_columns) * 0.14, 0.30 + float(index / service_columns) * 0.13)
			size = Vector2(96.0 / ENVIRONMENT_BOARD_SIZE.x, 54.0 / ENVIRONMENT_BOARD_SIZE.y)
		"lender":
			var lender_columns := 5
			center = Vector2(0.22 + float(index % lender_columns) * 0.15, 0.70 + float(index / lender_columns) * 0.12)
			size = Vector2(102.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_tenure":
			center = Vector2(0.78, 0.46)
			size = Vector2(116.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_sleep":
			center = Vector2(0.50, 0.42)
			size = Vector2(150.0 / ENVIRONMENT_BOARD_SIZE.x, 74.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_storage":
			center = Vector2(0.20, 0.72)
			size = Vector2(108.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_container":
			var container_columns := 4
			center = Vector2(0.22 + float(index % container_columns) * 0.18, 0.76 + float(index / container_columns) * 0.11)
			size = Vector2(104.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
	return _clamped_rect_from_center(center, size)


# Reads an authored board-coordinate spot from a generated layout.
static func _layout_spot(layout: Dictionary, spot_field: String, index: int) -> Vector2:
	if spot_field.is_empty():
		return Vector2(-1.0, -1.0)
	var spots: Variant = layout.get(spot_field, [])
	if typeof(spots) != TYPE_ARRAY or index < 0 or index >= (spots as Array).size():
		return Vector2(-1.0, -1.0)
	return _layout_spot_to_board_position((spots as Array)[index])


# Converts supported authoring spot formats to board coordinates.
static func _layout_spot_to_board_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		var spot_i := value as Vector2i
		return Vector2(float(spot_i.x), float(spot_i.y))
	if typeof(value) == TYPE_ARRAY:
		var parts := value as Array
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var data := value as Dictionary
		return Vector2(float(data.get("x", -1.0)), float(data.get("y", -1.0)))
	return Vector2(-1.0, -1.0)


# Keeps generated rects in the normalized environment canvas.
static func _clamped_rect_from_center(center: Vector2, size: Vector2) -> Rect2:
	var clamped_size := Vector2(clampf(size.x, 0.08, 0.22), clampf(size.y, 0.12, 0.28))
	var max_position := Vector2(0.98, 0.96) - clamped_size
	var position := center - clamped_size * 0.5
	return Rect2(
		Vector2(
			clampf(position.x, 0.02, maxf(0.02, max_position.x)),
			clampf(position.y, 0.04, maxf(0.04, max_position.y))
		),
		clamped_size
	)


# Converts a normalized rect to saveable primitive data.
static func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


static func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


static func _resolve_active_object_rect_collisions(object_rects: Dictionary, layout: Dictionary, active_entries: Array) -> void:
	var kept_rects: Dictionary = {}
	for entry_value in active_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var object_id := str(entry.get("object_id", ""))
		if object_id.is_empty():
			continue
		var object_type := str(entry.get("object_type", ""))
		var index := int(entry.get("index", 0))
		var spot_field := str(entry.get("spot_field", ""))
		var rect := _rect_from_dict(object_rects.get(object_id, {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or _object_rect_collides_with_any(kept_rects, rect):
			var desired_rect := _object_rect_from_layout(layout, object_type, index, spot_field)
			rect = _first_noncolliding_object_rect(kept_rects, layout, object_type, index, spot_field, desired_rect)
			object_rects[object_id] = _rect_to_dict(rect)
		kept_rects[object_id] = _rect_to_dict(rect)


static func _first_noncolliding_object_rect(placed_rects: Dictionary, layout: Dictionary, object_type: String, index: int, spot_field: String, desired_rect: Rect2) -> Rect2:
	if not _object_rect_collides_with_any(placed_rects, desired_rect):
		return desired_rect
	var slot_count := maxi(maxi(_layout_spot_count(layout, spot_field), index + 1), 48)
	for slot_index in range(slot_count):
		var candidate := _object_rect_from_layout(layout, object_type, slot_index, spot_field)
		if not _object_rect_collides_with_any(placed_rects, candidate):
			return candidate
	for candidate_value in _fallback_grid_object_rects(object_type, index, desired_rect):
		var candidate: Rect2 = candidate_value
		if not _object_rect_collides_with_any(placed_rects, candidate):
			return candidate
	return desired_rect


static func _object_rect_collides_with_any(placed_rects: Dictionary, rect: Rect2) -> bool:
	for key in placed_rects.keys():
		var existing_rect := _rect_from_dict(placed_rects.get(key, {}))
		if existing_rect.size.x <= 0.0 or existing_rect.size.y <= 0.0:
			continue
		if _rects_overlap_with_layout_gap(existing_rect, rect):
			return true
	return false


static func _fallback_grid_object_rects(object_type: String, index: int, desired_rect: Rect2) -> Array:
	var size := _fallback_object_rect(object_type, index).size
	var desired_center := desired_rect.position + desired_rect.size * 0.5
	var centers := [
		Vector2(0.12, 0.20),
		Vector2(0.28, 0.20),
		Vector2(0.44, 0.20),
		Vector2(0.60, 0.20),
		Vector2(0.76, 0.20),
		Vector2(0.88, 0.20),
		Vector2(0.12, 0.34),
		Vector2(0.28, 0.34),
		Vector2(0.44, 0.34),
		Vector2(0.60, 0.34),
		Vector2(0.76, 0.34),
		Vector2(0.88, 0.34),
		Vector2(0.12, 0.48),
		Vector2(0.28, 0.48),
		Vector2(0.44, 0.48),
		Vector2(0.60, 0.48),
		Vector2(0.76, 0.48),
		Vector2(0.88, 0.48),
		Vector2(0.12, 0.62),
		Vector2(0.28, 0.62),
		Vector2(0.44, 0.62),
		Vector2(0.60, 0.62),
		Vector2(0.76, 0.62),
		Vector2(0.88, 0.62),
		Vector2(0.12, 0.76),
		Vector2(0.28, 0.76),
		Vector2(0.44, 0.76),
		Vector2(0.60, 0.76),
		Vector2(0.76, 0.76),
		Vector2(0.88, 0.76),
		Vector2(0.12, 0.88),
		Vector2(0.28, 0.88),
		Vector2(0.44, 0.88),
		Vector2(0.60, 0.88),
		Vector2(0.76, 0.88),
		Vector2(0.88, 0.88),
	]
	var scored: Array = []
	for center_value in centers:
		var center: Vector2 = center_value
		var rect := _clamped_rect_from_center(center, size)
		var candidate_center := rect.position + rect.size * 0.5
		scored.append({
			"rect": rect,
			"score": desired_center.distance_squared_to(candidate_center),
		})
	scored.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _sort_layout_rect_candidate(a, b)
	)
	var result: Array = []
	for entry_value in scored:
		var entry: Dictionary = entry_value
		result.append(entry.get("rect", Rect2()))
	return result


static func _sort_layout_rect_candidate(a: Variant, b: Variant) -> bool:
	var entry_a: Dictionary = a
	var entry_b: Dictionary = b
	var score_a := float(entry_a.get("score", 0.0))
	var score_b := float(entry_b.get("score", 0.0))
	if score_a == score_b:
		var rect_a: Rect2 = entry_a.get("rect", Rect2())
		var rect_b: Rect2 = entry_b.get("rect", Rect2())
		if rect_a.position.y == rect_b.position.y:
			return rect_a.position.x < rect_b.position.x
		return rect_a.position.y < rect_b.position.y
	return score_a < score_b


static func _active_object_layout_entries(environment_data: Dictionary) -> Array:
	var entries: Array = []
	_append_string_layout_entries(entries, "game", _copy_array(environment_data.get("game_ids", [])), "game_spots")
	_append_string_layout_entries(entries, "event", _copy_array(environment_data.get("event_ids", [])), "event_spots")
	var layout := _copy_dict(environment_data.get("layout", {}))
	var prioritize_services := bool(layout.get("prioritize_service_spots", false))
	if not prioritize_services:
		_append_item_offer_layout_entries(entries, _copy_array(environment_data.get("item_offers", [])))
	if _shopkeeper_should_exist(environment_data):
		entries.append({"object_id": "shopkeeper:merchant", "object_type": "shopkeeper", "index": 0, "spot_field": "shopkeeper_spots"})
	if not _travel_target_ids(environment_data).is_empty():
		entries.append({"object_id": "travel:leave", "object_type": "travel", "index": 0, "spot_field": "travel_spots"})
	_append_string_layout_entries(entries, "casino_fixture", _casino_fixture_ids(environment_data), "casino_fixture_spots")
	_append_string_layout_entries(entries, "travel", _grand_casino_local_target_ids(environment_data), "casino_door_spots")
	_append_string_layout_entries(entries, "service", _copy_array(environment_data.get("service_ids", [])), "service_spots")
	_append_string_layout_entries(entries, "lender", _copy_array(environment_data.get("lender_hooks", [])), "lender_spots")
	entries.append_array(_game_hook_layout_entries(environment_data))
	if _home_tenure_should_exist(environment_data):
		entries.append({"object_id": "home_tenure:status", "object_type": "home_tenure", "index": 0, "spot_field": "home_tenure_spots"})
	if _home_sleep_should_exist(environment_data):
		entries.append({"object_id": "home_sleep:bed", "object_type": "home_sleep", "index": 0, "spot_field": "home_sleep_spots"})
	if _home_storage_should_exist(environment_data):
		entries.append({"object_id": "home_storage:place", "object_type": "home_storage", "index": 0, "spot_field": "home_storage_spots"})
	_append_string_layout_entries(entries, "home_container", _home_container_ids(environment_data), "home_container_spots")
	if prioritize_services:
		_append_item_offer_layout_entries(entries, _copy_array(environment_data.get("item_offers", [])))
	return _filter_unique_object_layout_entries(entries)


static func _append_string_layout_entries(entries: Array, object_type: String, ids: Array, spot_field: String) -> void:
	var stable_ids := _string_array(ids)
	for index in range(stable_ids.size()):
		entries.append({
			"object_id": "%s:%s" % [object_type, stable_ids[index]],
			"object_type": object_type,
			"index": index,
			"spot_field": spot_field,
		})


static func _append_item_offer_layout_entries(entries: Array, offers: Array) -> void:
	var item_ids: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty() and not item_ids.has(item_id):
			item_ids.append(item_id)
	for index in range(item_ids.size()):
		entries.append({
			"object_id": "item:%s" % item_ids[index],
			"object_type": "item",
			"index": index,
			"spot_field": "item_spots",
		})


static func _active_object_ids_from_entries(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((entry_value as Dictionary).get("object_id", ""))
		if not object_id.is_empty():
			result[object_id] = true
	return result


static func _active_object_ids(environment_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for game_id in _string_array(environment_data.get("game_ids", [])):
		result["game:%s" % game_id] = true
	for event_id in _string_array(environment_data.get("event_ids", [])):
		result["event:%s" % event_id] = true
	for offer in _copy_array(environment_data.get("item_offers", [])):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty():
			result["item:%s" % item_id] = true
	if _shopkeeper_should_exist(environment_data):
		result["shopkeeper:merchant"] = true
	if not _travel_target_ids(environment_data).is_empty():
		result["travel:leave"] = true
	for fixture_id in _casino_fixture_ids(environment_data):
		result["casino_fixture:%s" % fixture_id] = true
	for target_id in _grand_casino_local_target_ids(environment_data):
		result["travel:%s" % target_id] = true
	for service_id in _string_array(environment_data.get("service_ids", [])):
		result["service:%s" % service_id] = true
	for lender_id in _string_array(environment_data.get("lender_hooks", [])):
		result["lender:%s" % lender_id] = true
	for entry_value in _game_hook_layout_entries(environment_data):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((entry_value as Dictionary).get("object_id", ""))
		if not object_id.is_empty():
			result[object_id] = true
	if _home_tenure_should_exist(environment_data):
		result["home_tenure:status"] = true
	if _home_sleep_should_exist(environment_data):
		result["home_sleep:bed"] = true
	if _home_storage_should_exist(environment_data):
		result["home_storage:place"] = true
	for container_id in _home_container_ids(environment_data):
		result["home_container:%s" % container_id] = true
	return result


static func _prune_inactive_object_rects(object_rects: Dictionary, active_object_ids: Dictionary) -> void:
	for key in object_rects.keys():
		var object_id := str(key)
		if _is_managed_object_id(object_id) and not bool(active_object_ids.get(object_id, false)):
			object_rects.erase(key)


static func _is_managed_object_id(object_id: String) -> bool:
	for prefix in ["game:", "event:", "item:", "shopkeeper:", "travel:", "service:", "lender:", "game_hook:", "dialogue:", "casino_fixture:", "home_tenure:", "home_sleep:", "home_storage:", "home_container:"]:
		if object_id.begins_with(prefix):
			return true
	return false


# Returns unique route target ids in the same order the UI exposes them.
static func _travel_target_ids(environment_data: Dictionary) -> Array:
	var result: Array = []
	for source in [
		environment_data.get("next_archetypes", []),
		environment_data.get("travel_hooks", []),
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


static func _casino_fixture_ids(environment_data: Dictionary) -> Array:
	if not _is_grand_casino_archetype(environment_data):
		return []
	var flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var result: Array = []
	for fixture_value in flags.get("casino_fixtures", []):
		if typeof(fixture_value) != TYPE_DICTIONARY:
			continue
		var fixture_id := str((fixture_value as Dictionary).get("id", "")).strip_edges()
		if not fixture_id.is_empty() and not result.has(fixture_id):
			result.append(fixture_id)
	return result


static func _grand_casino_local_target_ids(environment_data: Dictionary) -> Array:
	if not _is_grand_casino_archetype(environment_data):
		return []
	var flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	return _string_array(flags.get("casino_room_targets", []))


static func _is_grand_casino_archetype(environment_data: Dictionary) -> bool:
	var archetype_id := str(environment_data.get("archetype_id", environment_data.get("id", ""))).strip_edges()
	return archetype_id == "grand_casino" or archetype_id == "grand_casino_high_limit" or archetype_id == "grand_casino_back_room"


static func _game_hook_layout_entries(environment_data: Dictionary) -> Array:
	var result: Array = []
	var game_states := _copy_dict(environment_data.get("game_states", {}))
	for game_id in _string_array(environment_data.get("game_ids", [])):
		var machine: Variant = game_states.get(game_id, {})
		if typeof(machine) != TYPE_DICTIONARY:
			continue
		for hook in _copy_array((machine as Dictionary).get("environment_hooks", [])):
			if typeof(hook) != TYPE_DICTIONARY:
				continue
			var hook_data: Dictionary = hook
			var hook_id := str(hook_data.get("id", ""))
			if hook_id.is_empty():
				continue
			var object_id := str(hook_data.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook_data.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, hook_id]
			result.append({
				"object_id": object_id,
				"object_type": "game_hook",
				"index": result.size(),
				"spot_field": "game_hook_spots",
				"unique_object_class": str(hook_data.get("unique_object_class", "")).strip_edges(),
				"unique_object_priority": int(hook_data.get("unique_object_priority", 0)),
				"allow_duplicate_unique_class": bool(hook_data.get("allow_duplicate_unique_class", false)),
			})
	return result


static func _filter_unique_object_layout_entries(entries: Array) -> Array:
	var result: Array = []
	var class_indexes: Dictionary = {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var unique_class := str(entry.get("unique_object_class", "")).strip_edges()
		if unique_class.is_empty() or bool(entry.get("allow_duplicate_unique_class", false)):
			result.append(entry)
			continue
		if not class_indexes.has(unique_class):
			class_indexes[unique_class] = result.size()
			result.append(entry)
			continue
		var existing_index := int(class_indexes[unique_class])
		var existing: Dictionary = result[existing_index]
		if int(entry.get("unique_object_priority", 0)) > int(existing.get("unique_object_priority", 0)):
			result[existing_index] = entry
	return result


static func _home_container_ids(environment_data: Dictionary) -> Array:
	var result: Array = []
	for container_value in _copy_array(environment_data.get("home_containers", [])):
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		var container_id := str(container.get("id", "")).strip_edges()
		if not container_id.is_empty() and not result.has(container_id):
			result.append(container_id)
	return result


static func _home_tenure_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


static func _home_sleep_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


static func _home_storage_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


# Returns whether this environment should expose a merchant prop.
static func _shopkeeper_should_exist(environment_data: Dictionary) -> bool:
	if _object_fixture_declared(environment_data, "shopkeeper:merchant"):
		return true
	if not _copy_array(environment_data.get("item_offers", [])).is_empty():
		return true
	return str(environment_data.get("kind", "")) == "shop"


static func _object_fixture_declared(environment_data: Dictionary, object_id: String) -> bool:
	if object_id.is_empty():
		return false
	for fixture_id in _string_array(environment_data.get("object_fixtures", [])):
		if fixture_id == object_id:
			return true
	return false


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value.duplicate(true)


# Safely converts an array-like value to non-empty strings.
static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value.duplicate(true)
