class_name TravelPresentationCatalog
extends RefCounted

# One route-neutral scene contract. UI, ownership and receipt behavior live in
# TravelCinematicOverlay; modes supply only assets, captions and choreography.
const LEGACY_KEY := "back_alley_bar_typical_v1"
const STANDARD_KEY := "standard_travel_typical_v1"
const MODES := ["walk", "bus", "taxi", "night_cab"]
const STREET_PATH := "res://assets/art/travel/back_alley_bar/street_strip.png"
const FOREGROUND_PATH := "res://assets/art/travel/back_alley_bar/foreground_strip.png"
const BUS_CONTRACT := "res://data/art/travel_back_alley_bar.json"
const VEHICLE_CONTRACT := "res://data/art/travel_standard_vehicles.json"
const STAGE_SIZE := Vector2(1152.0, 500.0)
const SOURCE_WIDTH_UV := 0.80
const MAIN_CAMERA_END_UV := 0.18
const BACKDROP_CAMERA_RATE := 0.35
const EXTERIOR_CONTRACTS := ["res://data/art/travel_exteriors_urban.json",
	"res://data/art/travel_exteriors_residential_music.json",
	"res://data/art/travel_exteriors_landmark_outdoor.json"]
const EXTERIOR_IDS := ["corner_store", "back_alley", "motel", "bar", "gas_station_casino",
	"small_underground_casino", "jazz_club", "kitty_cat_lounge", "delta_queen",
	"beach", "pawn_shop", "grand_casino", "motel_room", "apartment", "house"]
const CAPTIONS := {
	"walk": {"walk": "Walking to {destination}"},
	"bus": {"approach": "Bus from {origin}", "stop": "The bus stops near {destination}",
		"dropoff": "Stepping off at the curb", "departure": "The bus pulls away",
		"walk": "Walking to {destination}"},
	"taxi": {"approach": "Taxi ride to {destination}", "stop": "The taxi pulls up at the curb",
		"dropoff": "Stepping out of the taxi", "departure": "The taxi pulls away",
		"walk": "Approaching {destination}"},
	"night_cab": {"approach": "Night cab to {destination}", "stop": "The night cab stops at the curb",
		"dropoff": "Stepping out of the night cab", "departure": "The night cab pulls away",
		"walk": "Approaching {destination}"},
}


static func profile(receipt: Dictionary) -> Dictionary:
	var mode := str(receipt.get("travel_method_kind", ""))
	var legacy := str(receipt.get("presentation_key", "")) == LEGACY_KEY
	var key_ok := str(receipt.get("presentation_key", "")) in [LEGACY_KEY, STANDARD_KEY]
	var archetype := str(receipt.get("effective_destination_archetype_id", "bar" if legacy else ""))
	var exterior_id := "small_underground_casino" if archetype == "punchline_club" else archetype
	var exterior := exterior_contract(exterior_id)
	var origin := _label(receipt.get("origin_label"), "Back Alley" if legacy else _humanize(str(receipt.get("origin_archetype_id", "")), "Origin"))
	var destination := _label(receipt.get("destination_label"), "the bar" if legacy else _humanize(archetype, "Destination"))
	var entrance := str(exterior.get("arrival_kind", "open"))
	var threshold := _vector(exterior.get("threshold_uv", [0.78, 0.85]))
	var inside := _vector(exterior.get("inside_uv", [threshold.x, threshold.y]))
	var scene_scale := 1.0
	var avatar_height := 0.20
	if entrance == "door":
		var door_top := 1.0
		var door_bottom := 0.0
		for point in exterior.get("door_polygon_uv", []):
			door_top = minf(door_top, float(point[1]))
			door_bottom = maxf(door_bottom, float(point[1]))
		# Keep adult/vehicle proportions together across taller generated
		# frontages. This is presentation zoom, never a character-model change.
		scene_scale = clampf((door_bottom - door_top) / 0.25, 1.0, 1.4)
		# The measured sill is the floor, not an arbitrary upward depth offset.
		# Keep the same fitted adult height throughout exit, approach and entry.
		inside.y = door_bottom
		avatar_height = minf(0.20 * scene_scale, (door_bottom - door_top) * 0.82)
	# The facade and its extended road are one authored image. All modes use
	# the same close view; only the separate distant backdrop has slower motion.
	var road := float(exterior.get("road_y_uv", 0.95))
	var reference: Array = exterior.get("reference_size", [2.0, 1.0])
	var aspect := float(reference[0]) / maxf(1.0, float(reference[1]))
	var source_width := SOURCE_WIDTH_UV
	var view_height := minf(0.95, source_width * aspect * STAGE_SIZE.y / STAGE_SIZE.x)
	var top := 1.0 - view_height
	var backdrop_reference: Array = exterior.get("backdrop_reference_size", reference)
	var backdrop_aspect := float(backdrop_reference[0]) / maxf(1.0, float(backdrop_reference[1]))
	var backdrop_height := minf(0.95, source_width * backdrop_aspect * STAGE_SIZE.y / STAGE_SIZE.x)
	var backdrop_top := clampf(float(exterior.get("backdrop_source_top_y_uv", 0.25)), 0.0, 1.0 - backdrop_height)
	var motion := {"destination_anchor_uv": threshold, "destination_inside_uv": inside,
		"entrance_kind": entrance, "vehicle_road_y_uv": road, "camera_end_uv": MAIN_CAMERA_END_UV,
		"player_curb_uv": Vector2(threshold.x - 0.12, road)}
	if exterior.has("approach_waypoint_uv"):
		motion["approach_waypoint_uv"] = _vector(exterior["approach_waypoint_uv"])
	if entrance == "dock" and exterior.has("boarding_clearance_rect_uv"):
		# The painted boarding opening supplies a measured perspective target,
		# not a fabricated door animation. Recede continuously from quay to ship.
		var clearance := _rect(exterior["boarding_clearance_rect_uv"])
		var far_scale := clampf(clearance.size.y * 0.82 / avatar_height, 0.15, 0.58)
		var near_fraction := clampf((threshold.y - inside.y) / maxf(road - inside.y, 0.000001), 0.0, 1.0)
		motion["walkaway_end_scale"] = far_scale
		motion["walkaway_start_scale"] = lerpf(far_scale, 1.0, near_fraction)
		motion["walkaway_scale_during_approach"] = true
	var vehicle := _vehicle_contract(mode) if mode != "walk" else {}
	if not vehicle.is_empty():
		var source: Array = vehicle["source_px"]
		var door: Array = vehicle["door_rect_uv"]
		var wheels: Array = vehicle["wheels"]
		var width := (0.48 if mode == "bus" else 0.34) * scene_scale
		var door_center := float(door[0]) + float(door[2]) * 0.5
		var exit_x := threshold.x - (0.12 if mode == "bus" else 0.26)
		var stop := exit_x - width * door_center
		var world_height := width * aspect * float(source[3]) / float(source[2])
		motion.merge({"vehicle_width_uv": width, "vehicle_stop_left_uv": stop,
			"vehicle_door_center_uv": door_center,
			"vehicle_step_y_uv": road - world_height * (1.0 - float(door[1]) - float(door[3])),
			"vehicle_wheel_radius_uv": width * float(wheels[0]["radius_uv"][0]),
			"player_curb_uv": Vector2(stop + width * door_center + 0.04, road)}, true)
	var risk: Variant = receipt.get("route_risk", {})
	var incident := risk is Dictionary and bool(risk.get("triggered", false))
	var layered := bool(exterior.get("layered_scene", false)) and not str(exterior.get("backdrop_texture", "")).is_empty()
	return {"supported": key_ok and mode in MODES and not incident and not exterior.is_empty() and layered, "mode": mode,
		"origin_label": origin, "destination_label": destination, "exterior_id": exterior_id,
		"title": origin.to_upper() + "  /  " + destination.to_upper(),
		"continue_text": "Continue to " + destination, "entrance_kind": entrance,
		"street_path": exterior.get("texture", ""), "main_scene_path": exterior.get("texture", ""),
		"background_path": exterior.get("backdrop_texture", ""), "backdrop_path": exterior.get("backdrop_texture", ""),
		"doorway_path": exterior.get("doorway_texture", "") if entrance == "door" else "",
		"foreground_path": exterior.get("texture", ""), "foreground_kind": "integrated_scene",
		"source_top_y_uv": top, "source_width_uv": source_width, "view_height_uv": view_height,
		"view_bottom_uv": 1.0, "backdrop_source_width_uv": source_width,
		"backdrop_source_top_y_uv": backdrop_top, "backdrop_view_height_uv": backdrop_height,
		"backdrop_camera_rate": BACKDROP_CAMERA_RATE,
		"avatar_height_uv": avatar_height, "actor_scene_scale": scene_scale,
		"exterior": exterior, "vehicle": vehicle, "motion": motion}


static func caption(scene: Dictionary, beat: String) -> String:
	var destination := str(scene.get("destination_label", "Destination"))
	if beat == "open_door":
		return "Opening the door to " + destination
	if beat == "close_door":
		return "Inside " + destination
	if beat == "enter":
		return "Heading inside" if scene.get("entrance_kind") == "door" else "Arriving at " + destination
	if beat == "arrival":
		return "At " + destination
	var mode_copy: Dictionary = CAPTIONS.get(str(scene.get("mode", "")), {})
	return str(mode_copy.get(beat, "Traveling to {destination}")).replace("{origin}", str(scene.get("origin_label", "Origin"))).replace("{destination}", destination)


static func _vehicle_contract(mode: String) -> Dictionary:
	if mode == "bus":
		var old := _read_dictionary(BUS_CONTRACT)
		if old.is_empty(): return {}
		return validated_vehicle_contract({"texture": "res://assets/art/travel/back_alley_bar/bus_arrival.png",
			"interior_texture": old.get("bus_interior_texture", ""), "interior_reference_size": old.get("bus_interior_reference_size", []),
			"reference_size": old.get("reference_size", []), "source_px": old.get("bus_source_px", []),
			"door_rect_uv": old.get("bus_door_rect_uv", []), "wheels": old.get("bus_wheels", []),
			"door_animation": old.get("bus_door_animation", {})})
	var data := _read_dictionary(VEHICLE_CONTRACT)
	var vehicles: Variant = data.get("vehicles", {})
	return validated_vehicle_contract(vehicles.get(mode, {})) if vehicles is Dictionary else {}


static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return decoded if decoded is Dictionary else {}


static func _label(value: Variant, fallback: String) -> String:
	return value.strip_edges().left(96) if value is String and not value.strip_edges().is_empty() else fallback


static func _humanize(value: String, fallback: String) -> String:
	return value.replace("_", " ").capitalize() if not value.is_empty() else fallback


# Replacing placeholder art must fail closed to the static receipt if its
# composition contract is missing or malformed, never crash the common UI.
static func validated_vehicle_contract(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("texture") is String or not value["texture"].begins_with("res://"):
		return {}
	if value.has("interior_texture") and (not value["interior_texture"] is String or not value["interior_texture"].begins_with("res://")): return {}
	if value.has("interior_reference_size"):
		if not _finite_numbers(value["interior_reference_size"], 2): return {}
		if float(value["interior_reference_size"][0]) <= 0.0 or float(value["interior_reference_size"][1]) <= 0.0: return {}
	if not _finite_numbers(value.get("reference_size"), 2) or not _finite_numbers(value.get("source_px"), 4) or not _finite_numbers(value.get("door_rect_uv"), 4):
		return {}
	var reference := Vector2(float(value["reference_size"][0]), float(value["reference_size"][1]))
	var source := _rect(value["source_px"])
	var door := _rect(value["door_rect_uv"])
	if reference.x <= 0.0 or reference.y <= 0.0 or not source.has_area() or not Rect2(Vector2.ZERO, reference).encloses(source):
		return {}
	if not door.has_area() or not Rect2(Vector2.ZERO, Vector2.ONE).encloses(door):
		return {}
	var wheels: Variant = value.get("wheels")
	if not wheels is Array or wheels.size() != 2:
		return {}
	for wheel in wheels:
		if not wheel is Dictionary or not _finite_numbers(wheel.get("center_uv"), 2) or not _finite_numbers(wheel.get("radius_uv"), 2):
			return {}
		var center := Vector2(float(wheel["center_uv"][0]), float(wheel["center_uv"][1]))
		var radius := Vector2(float(wheel["radius_uv"][0]), float(wheel["radius_uv"][1]))
		if radius.x <= 0.0 or radius.y <= 0.0 or not Rect2(Vector2.ZERO, Vector2.ONE).encloses(Rect2(center - radius, radius * 2.0)):
			return {}
	return value.duplicate(true)


static func _finite_numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true


static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

static func exterior_contract(destination_id: String) -> Dictionary:
	for path in EXTERIOR_CONTRACTS:
		var data := _read_dictionary(path)
		if int(data.get("version", 0)) not in [1, 2]: continue
		var exteriors: Variant = data.get("exteriors", {})
		if exteriors is Dictionary and exteriors.has(destination_id):
			return validated_exterior_contract(exteriors[destination_id])
	return {}


static func validated_exterior_contract(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("texture") is String or not value["texture"].begins_with("res://"):
		return {}
	if not _finite_numbers(value.get("reference_size"), 2) or not _finite_numbers(value.get("threshold_uv"), 2) or not _finite_numbers(value.get("inside_uv"), 2):
		return {}
	if float(value["reference_size"][0]) <= 0.0 or float(value["reference_size"][1]) <= 0.0:
		return {}
	if value.has("layered_scene") and not value["layered_scene"] is bool: return {}
	if value.has("backdrop_texture") and (not value["backdrop_texture"] is String or not value["backdrop_texture"].begins_with("res://")): return {}
	if value.has("backdrop_reference_size"):
		if not _finite_numbers(value["backdrop_reference_size"], 2): return {}
		if float(value["backdrop_reference_size"][0]) <= 0.0 or float(value["backdrop_reference_size"][1]) <= 0.0: return {}
	if value.has("doorway_texture") and (not value["doorway_texture"] is String or not value["doorway_texture"].begins_with("res://")): return {}
	if value.has("doorway_reference_size"):
		if not _finite_numbers(value["doorway_reference_size"], 2): return {}
		if float(value["doorway_reference_size"][0]) <= 0.0 or float(value["doorway_reference_size"][1]) <= 0.0: return {}
	if value.has("backdrop_source_top_y_uv"):
		if not (value["backdrop_source_top_y_uv"] is float or value["backdrop_source_top_y_uv"] is int) or not is_finite(float(value["backdrop_source_top_y_uv"])): return {}
		if float(value["backdrop_source_top_y_uv"]) < 0.0 or float(value["backdrop_source_top_y_uv"]) > 1.0: return {}
	for key in ["threshold_uv", "inside_uv"]:
		var point := _vector(value[key])
		if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
			return {}
	if value.has("approach_waypoint_uv"):
		if not _finite_numbers(value["approach_waypoint_uv"], 2): return {}
		var waypoint := _vector(value["approach_waypoint_uv"])
		if waypoint.x < 0.0 or waypoint.x > 1.0 or waypoint.y < 0.0 or waypoint.y > 1.0: return {}
	if value.has("boarding_clearance_rect_uv"):
		if not _finite_numbers(value["boarding_clearance_rect_uv"], 4): return {}
		var boarding := _rect(value["boarding_clearance_rect_uv"])
		if not boarding.has_area() or not Rect2(Vector2.ZERO, Vector2.ONE).encloses(boarding): return {}
	var kind: Variant = value.get("arrival_kind")
	if kind not in ["door", "open", "passage", "dock"]:
		return {}
	if kind == "door":
		var polygon: Variant = value.get("door_polygon_uv")
		if not polygon is Array or polygon.size() < 3 or polygon.size() > 32:
			return {}
		for point in polygon:
			if not _finite_numbers(point, 2): return {}
			if float(point[0]) < 0.0 or float(point[0]) > 1.0 or float(point[1]) < 0.0 or float(point[1]) > 1.0:
				return {}
		if value.get("door_kind") not in ["hinged", "double_hinged"]:
			return {}
	if not (value.get("road_y_uv") is float or value.get("road_y_uv") is int) or not is_finite(float(value["road_y_uv"])) or float(value["road_y_uv"]) <= 0.0 or float(value["road_y_uv"]) > 1.0:
		return {}
	if value.has("source_top_y_uv") and (not (value["source_top_y_uv"] is float or value["source_top_y_uv"] is int) or not is_finite(float(value["source_top_y_uv"]))):
		return {}
	return value.duplicate(true)


static func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
