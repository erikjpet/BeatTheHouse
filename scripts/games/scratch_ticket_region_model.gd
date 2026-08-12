class_name ScratchTicketRegionModel
extends RefCounted

const LAYOUT_VERSION := 9
const REGION_DATA_PATH := "res://data/games/scratch_ticket_regions.json"
const ART_ROOT := "res://assets/art/scratch_tickets/layers/"
const MECHANIC_INSET_CELLS := 1.0
const MASK_COLUMNS := 256.0
const MASK_ROWS := 192.0

static var _data_cache: Dictionary = {}


static func build(ticket: Dictionary) -> Array:
	var spots := _dictionary_array(ticket.get("spots", []))
	var definitions := _dictionary_array(_data().get("regions", {}).get(str(ticket.get("type_id", "")), []))
	var regions: Array = []
	for index in range(mini(spots.size(), definitions.size())):
		var definition: Dictionary = definitions[index]
		var art_rect := normalized_rect(definition.get("art_rect", []))
		# Mechanics use a declared one-mask-cell inset. This keeps foil coverage a
		# little generous while making art_rect and rect independently testable.
		var rect := inset_rect(art_rect, MECHANIC_INSET_CELLS / MASK_COLUMNS, MECHANIC_INSET_CELLS / MASK_ROWS)
		var spot: Dictionary = spots[index]
		regions.append({
			"id": str(definition.get("id", "region_%02d" % index)),
			"layout_version": LAYOUT_VERSION,
			"spot_index": int(spot.get("index", index)),
			"section_id": str(definition.get("section_id", spot.get("section_id", "play"))),
			"label": str(definition.get("label", "SPOT %d" % (index + 1))),
			"role": str(spot.get("role", "")),
			"rect": rect,
			"art_rect": art_rect,
			"content_split": definition.get("content_split", []),
			"mask_shape": str(definition.get("shape", "rect")),
			"sample_total": 0,
			"mask_remaining_units": 0,
			"coverage": 0.0,
			"revealed": false,
		})
	return regions


static func rect_for(region: Dictionary, art_frame: Rect2, field: String = "art_rect") -> Rect2:
	var values := normalized_rect(region.get(field, []))
	return Rect2(
		art_frame.position + Vector2(float(values[0]) * art_frame.size.x, float(values[1]) * art_frame.size.y),
		Vector2(float(values[2]) * art_frame.size.x, float(values[3]) * art_frame.size.y)
	)


static func art_size(type_id: String) -> Vector2:
	var source: Dictionary = _data().get("source_art", {}).get(type_id, {})
	return Vector2(float(source.get("w", 1)), float(source.get("h", 1)))


static func art_file(type_id: String) -> String:
	return ART_ROOT + str(_data().get("source_art", {}).get(type_id, {}).get("file", ""))


static func source_sha256(type_id: String) -> String:
	return str(_data().get("source_art", {}).get(type_id, {}).get("sha256", ""))


static func art_frame(ticket_rect: Rect2, art_dimensions: Vector2) -> Rect2:
	if art_dimensions.x <= 0.0 or art_dimensions.y <= 0.0:
		return ticket_rect
	var scale := minf(ticket_rect.size.x / art_dimensions.x, ticket_rect.size.y / art_dimensions.y)
	var fitted := art_dimensions * scale
	return Rect2(ticket_rect.get_center() - fitted * 0.5, fitted)


static func normalized_rect(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 4:
		push_error("Scratch ticket region data contains an invalid measured rectangle.")
		return []
	var source: Array = value
	return [
		clampf(float(source[0]), 0.0, 1.0),
		clampf(float(source[1]), 0.0, 1.0),
		clampf(float(source[2]), 0.001, 1.0),
		clampf(float(source[3]), 0.001, 1.0),
	]


static func inset_rect(values: Array, inset_x: float, inset_y: float) -> Array:
	var rect := normalized_rect(values)
	return [float(rect[0]) + inset_x, float(rect[1]) + inset_y, maxf(0.001, float(rect[2]) - inset_x * 2.0), maxf(0.001, float(rect[3]) - inset_y * 2.0)]


static func _data() -> Dictionary:
	if not _data_cache.is_empty():
		return _data_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGION_DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Scratch ticket measured region data is missing or invalid: %s" % REGION_DATA_PATH)
		return {}
	_data_cache = parsed as Dictionary
	if int(_data_cache.get("layout_version", 0)) != LAYOUT_VERSION:
		push_error("Scratch ticket region data layout version does not match runtime layout version.")
	return _data_cache


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result
