class_name TravelJourneyReceipt
extends RefCounted

# Presentation-only evidence of a travel transaction that has already committed.
# This model never resolves risk, spends fare, advances time, or consumes RNG.
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const LEGACY_SCHEMA_VERSION := 1
const SCHEMA_VERSION := 2
const STANDARD_PRESENTATION_KEY := "standard_travel_typical_v1"
const PRESENTATION_KEY := "back_alley_bar_typical_v1"
const STATIC_PRESENTATION_KEY := "static_receipt"
const MAX_TEXT_LENGTH := 4096
const MAX_ID_LENGTH := 256
const MAX_LABEL_LENGTH := 256
const STANDARD_METHOD_KINDS := ["walk", "bus", "taxi", "night_cab"]
const LOCAL_METHOD_LABELS := ["door", "inside", "begin"]
const MAX_PATH_STOPS := 64
const MAX_EXACT_NUMBER := 9007199254740991


static func build(run_state: Object, previous_environment: Dictionary, destination_environment: Dictionary, target_id: String, route: Dictionary, departure_route_status: Dictionary, route_risk: Dictionary, travel_result: Dictionary) -> Dictionary:
	if run_state == null or not _is_world_journey(previous_environment, destination_environment, route):
		return {}
	if travel_result.has("ok") and (typeof(travel_result.get("ok")) != TYPE_BOOL or not travel_result.get("ok")):
		return {}
	var origin_id := _text(previous_environment.get("id"), MAX_ID_LENGTH)
	var destination_id := _text(destination_environment.get("id"), MAX_ID_LENGTH)
	var origin_node := _text(previous_environment.get("world_node_id"), MAX_ID_LENGTH)
	var destination_node := _text(destination_environment.get("world_node_id"), MAX_ID_LENGTH)
	var intended_id := target_id.strip_edges().left(MAX_ID_LENGTH)
	var base_minutes := _integer(route.get("travel_minutes"), 0)
	var arrival := _integer(route.get("arrived_game_clock_minutes", run_state.get("game_clock_minutes")), 0)
	var departure := _integer(route.get("departed_game_clock_minutes", previous_environment.get("departed_game_clock_minutes")), maxi(0, arrival - base_minutes))
	var travel_count := _integer(run_state.call("environment_travel_count"), 0) if run_state.has_method("environment_travel_count") else 0
	var method_kind := _committed_method_kind(route)
	var risk := _risk_snapshot(route_risk)
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"journey_id": "travel_" + JSON.stringify([
			run_state.get("seed_text"), run_state.get("seed_value"), origin_id, intended_id,
			destination_id, _text(route.get("id"), MAX_ID_LENGTH), travel_count, departure, arrival,
		]).sha256_text(),
		"origin_environment_id": origin_id,
		"origin_node_id": origin_node,
		"origin_archetype_id": _archetype(previous_environment),
		"origin_label": _environment_label(previous_environment),
		"intended_destination_id": intended_id,
		"effective_destination_environment_id": destination_id,
		"effective_destination_node_id": destination_node,
		"effective_destination_archetype_id": _archetype(destination_environment),
		"destination_label": _environment_label(destination_environment),
		"travel_count": travel_count,
		"travel_method_kind": method_kind,
		"travel_method_label": WorldMapScript.travel_method_label(method_kind),
		"departed_game_clock_minutes": departure,
		"arrived_game_clock_minutes": arrival,
		"base_minutes": base_minutes,
		"extra_minutes": 0,
		"distance": _text(route.get("distance", departure_route_status.get("distance")), 32),
		"distance_blocks": _integer(route.get("distance_blocks"), 0),
		"world_path": _path_snapshot(route.get("world_path")),
		# Never re-quote after destination installation: origin-specific discounts
		# and offered rides have already been settled by the host transaction.
		"quoted_departure_fare": _integer(departure_route_status.get("cost"), 0),
		"route_risk": risk,
		"outcome_label": _outcome_label(risk),
		"receipt_text": _text(travel_result.get("message"), MAX_TEXT_LENGTH),
		"presentation_key": PRESENTATION_KEY if _archetype(previous_environment) == "back_alley" and _archetype(destination_environment) == "bar" else STANDARD_PRESENTATION_KEY,
		"commit_status": "committed",
		"receipt_pending": true,
	}
	return normalize(receipt)


# A save is not an instruction. Read only bounded, whitelisted data; unknown
# versions/visuals retain their frozen receipt as text, never regenerate effects.
static func normalize(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
	var version := _integer(source.get("schema_version"), 0, 0, 2147483647)
	var journey_id := _text(source.get("journey_id"), MAX_ID_LENGTH)
	var receipt_text := _text(source.get("receipt_text"), MAX_TEXT_LENGTH)
	if version < 1 or _text(source.get("commit_status"), 32) != "committed" or journey_id.is_empty() or receipt_text.is_empty():
		return {}
	var result := {
		"schema_version": version,
		"journey_id": journey_id,
		"commit_status": "committed",
		"receipt_pending": source.get("receipt_pending") == true if typeof(source.get("receipt_pending")) == TYPE_BOOL else false,
		"receipt_text": receipt_text,
		"presentation_key": STATIC_PRESENTATION_KEY,
	}
	# Do not reinterpret a newer schema's numeric fields as known gameplay facts.
	if version not in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION]:
		return result
	for key in ["origin_environment_id", "origin_node_id", "origin_archetype_id", "intended_destination_id", "effective_destination_environment_id", "effective_destination_node_id", "effective_destination_archetype_id"]:
		result[key] = _text(source.get(key), MAX_ID_LENGTH)
	if result["origin_archetype_id"].is_empty() or result["effective_destination_archetype_id"].is_empty() \
			or result["origin_environment_id"].is_empty() or result["effective_destination_environment_id"].is_empty() \
			or result["intended_destination_id"].is_empty():
		return {}
	var legacy_pair: bool = result["origin_archetype_id"] == "back_alley" and result["effective_destination_archetype_id"] == "bar"
	if version == LEGACY_SCHEMA_VERSION:
		# Keep the original v1 shape and eligibility. Do not invent frozen labels
		# that were never stored by an old save.
		if not legacy_pair:
			return {}
	else:
		if result["origin_node_id"].is_empty() or result["effective_destination_node_id"].is_empty() \
				or result["origin_node_id"] == result["effective_destination_node_id"] \
				or result["origin_environment_id"] == result["effective_destination_environment_id"]:
			return {}
		result["origin_label"] = _label(source.get("origin_label"), result["origin_archetype_id"])
		result["destination_label"] = _label(source.get("destination_label"), result["effective_destination_archetype_id"])
	var method_kind := _text(source.get("travel_method_kind"), 32)
	var known_method := method_kind in STANDARD_METHOD_KINDS
	result["travel_method_kind"] = method_kind if known_method else "unknown"
	result["travel_method_label"] = WorldMapScript.travel_method_label(method_kind) if known_method else "Travel"
	for key in ["travel_count", "departed_game_clock_minutes", "arrived_game_clock_minutes", "base_minutes", "quoted_departure_fare", "distance_blocks"]:
		result[key] = _integer(source.get(key), 0)
	# Neither supported version adds travel timing or outcome variants.
	result["extra_minutes"] = 0
	result["distance"] = _text(source.get("distance"), 32)
	result["world_path"] = _path_snapshot(source.get("world_path"))
	result["route_risk"] = _risk_snapshot(source.get("route_risk"))
	result["outcome_label"] = _outcome_label(result["route_risk"])
	var presentation_key := _text(source.get("presentation_key"), MAX_ID_LENGTH)
	var known_presentation: bool = presentation_key == PRESENTATION_KEY and legacy_pair \
			or version == SCHEMA_VERSION and presentation_key == STANDARD_PRESENTATION_KEY
	if known_presentation and known_method and not bool(result["route_risk"].get("triggered", false)) \
			and result["arrived_game_clock_minutes"] >= result["departed_game_clock_minutes"]:
		result["presentation_key"] = presentation_key
	return result


# The host calls build only after committing travel. Distinct installed world
# nodes prove the scope without consulting/mutating map state or route quotes.
# Local route labels must be checked before the gameplay canonicalizer: its
# distance fallback turns Door/Inside/Begin into walk (or even night_cab).
static func _is_world_journey(origin: Dictionary, destination: Dictionary, route: Dictionary) -> bool:
	# The host captures this before rewriting local route copy to a gameplay
	# canonical mode. An explicit rejection remains authoritative afterward.
	if route.has("presentation_world_travel") and (typeof(route.get("presentation_world_travel")) != TYPE_BOOL or not route.get("presentation_world_travel")):
		return false
	if _archetype(origin).is_empty() or _archetype(destination).is_empty():
		return false
	if _text(origin.get("kind"), 32) == "meta" or _text(destination.get("kind"), 32) == "meta":
		return false
	for key in ["local_casino_room", "local_door", "local_child_area_transition"]:
		if route.get(key) == true and typeof(route.get(key)) == TYPE_BOOL:
			return false
	var origin_node := _text(origin.get("world_node_id"), MAX_ID_LENGTH).strip_edges()
	var destination_node := _text(destination.get("world_node_id"), MAX_ID_LENGTH).strip_edges()
	if origin_node.is_empty() or destination_node.is_empty() or origin_node == destination_node:
		return false
	if _text(origin.get("id"), MAX_ID_LENGTH) == _text(destination.get("id"), MAX_ID_LENGTH):
		return false
	for key in ["travel_method_kind", "travel_method", "method"]:
		if _text(route.get(key), MAX_ID_LENGTH).strip_edges().to_lower() in LOCAL_METHOD_LABELS:
			return false
	return true


static func _committed_method_kind(route: Dictionary) -> String:
	# Generated world routes already carry the actual canonical mode. An
	# explicitly unknown mode is not permission to fabricate one from distance.
	if route.has("travel_method_kind"):
		var explicit_kind := _text(route.get("travel_method_kind"), 32).strip_edges().to_lower()
		return explicit_kind if explicit_kind in STANDARD_METHOD_KINDS else "unknown"
	var label := _text(route.get("travel_method", route.get("method")), MAX_ID_LENGTH).strip_edges().to_lower()
	# Accept the same legacy travel words as WorldMap, but never its fallback.
	if label in STANDARD_METHOD_KINDS or label.contains("walk") or label.contains("bus") \
			or label.contains("taxi") or label.contains("night cab"):
		return WorldMapScript.travel_method_kind(label)
	return "unknown"


static func _environment_label(environment: Dictionary) -> String:
	return _label(environment.get("display_name"), _archetype(environment))


static func _label(value: Variant, archetype_id: String) -> String:
	var label := _text(value, MAX_LABEL_LENGTH).strip_edges()
	return label if not label.is_empty() else archetype_id.capitalize().left(MAX_LABEL_LENGTH)


static func _archetype(environment: Dictionary) -> String:
	return _text(environment.get("archetype_id"), MAX_ID_LENGTH)


static func _text(value: Variant, limit: int) -> String:
	return (value as String).left(limit) if typeof(value) == TYPE_STRING else ""


static func _integer(value: Variant, fallback: int, minimum: int = 0, maximum: int = MAX_EXACT_NUMBER) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(value, minimum, maximum)
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value >= minimum and value <= maximum and value == floor(value):
		return int(value)
	return fallback


static func _path_snapshot(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value
	for index in range(mini(MAX_PATH_STOPS, source.size())):
		var stop := _text(source[index], MAX_ID_LENGTH)
		if not stop.is_empty():
			result.append(stop)
	return result


static func _risk_snapshot(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
	return {
		"id": _text(source.get("id"), MAX_ID_LENGTH),
		"label": _text(source.get("label"), MAX_ID_LENGTH),
		"triggered": source.get("triggered") == true if typeof(source.get("triggered")) == TYPE_BOOL else false,
		"chance_percent": _integer(source.get("chance_percent"), 0, 0, 100),
		"roll": _integer(source.get("roll"), 0, 0, 100),
		"bankroll_delta": _integer(source.get("bankroll_delta"), 0, -MAX_EXACT_NUMBER),
		"suspicion_delta": _integer(source.get("suspicion_delta"), 0, -MAX_EXACT_NUMBER),
		"message": _text(source.get("message"), MAX_TEXT_LENGTH),
	}


static func _outcome_label(risk: Dictionary) -> String:
	if not bool(risk.get("triggered", false)):
		return "Uneventful travel"
	var label := _text(risk.get("label"), MAX_ID_LENGTH)
	return label if not label.is_empty() else "Route risk occurred"
