class_name InventoryContainerCatalog
extends RefCounted

const CATALOG_PATH := "res://data/ui/inventory_containers.json"
const ITEMS_PATH := "res://data/items/items.json"
const REQUIRED_TYPES := ["bag", "backpack", "suitcase", "trunk", "loose_carry", "home_storage"]

static var _catalog_cache: Dictionary = {}
static var _capacity_cache: Dictionary = {}


static func load_catalog(force_reload: bool = false) -> Dictionary:
	if not force_reload and not _catalog_cache.is_empty():
		return _catalog_cache.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var catalog := _catalog_from_parsed(parsed)
	if catalog.is_empty():
		_catalog_cache = _fallback_catalog()
		return _catalog_cache.duplicate(true)
	catalog["validation_errors"] = validate_catalog(catalog)
	_catalog_cache = catalog
	return _catalog_cache.duplicate(true)


static func presentation(container_type: String, catalog: Dictionary = {}) -> Dictionary:
	var source := catalog if not catalog.is_empty() else load_catalog()
	var presentations: Dictionary = source.get("presentations", {}) if typeof(source.get("presentations", {})) == TYPE_DICTIONARY else {}
	var clean_type := container_type.strip_edges().to_lower()
	if presentations.has(clean_type) and typeof(presentations.get(clean_type)) == TYPE_DICTIONARY:
		return (presentations.get(clean_type) as Dictionary).duplicate(true)
	return _fallback_presentation(clean_type)


static func slot_rects(container_type: String, requested_count: int, catalog: Dictionary = {}) -> Array:
	var definition := presentation(container_type, catalog)
	var authored := _rect_array(definition.get("slots", []))
	var count := maxi(0, requested_count)
	if not authored.is_empty() and count <= authored.size():
		return authored.slice(0, count)
	var bounds := _rect_from_value(definition.get("dynamic_bounds", [0.14, 0.18, 0.72, 0.68]), Rect2(0.14, 0.18, 0.72, 0.68))
	return _generated_rects(count, bounds, maxi(1, int(definition.get("dynamic_columns", 4))))


static func validate_catalog(catalog: Dictionary = {}) -> Array:
	var errors: Array = []
	var source := catalog
	if source.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		source = _catalog_from_parsed(parsed)
		if source.is_empty():
			return ["Inventory container catalog is not valid JSON."]
	var presentations: Dictionary = source.get("presentations", {}) if typeof(source.get("presentations", {})) == TYPE_DICTIONARY else {}
	var capacities := authoritative_capacities()
	for required_type in REQUIRED_TYPES:
		if not presentations.has(required_type) or typeof(presentations.get(required_type)) != TYPE_DICTIONARY:
			errors.append("Missing inventory presentation: %s." % required_type)
	for type_value in presentations.keys():
		var container_type := str(type_value)
		var definition: Dictionary = presentations.get(type_value, {})
		var background_path := str(definition.get("background_path", "")).strip_edges()
		if background_path.is_empty() or not ResourceLoader.exists(background_path):
			errors.append("Missing background art for %s: %s." % [container_type, background_path])
		var foreground_path := str(definition.get("foreground_path", "")).strip_edges()
		if not foreground_path.is_empty():
			if not ResourceLoader.exists(foreground_path):
				errors.append("Missing foreground art for %s: %s." % [container_type, foreground_path])
		elif bool(definition.get("foreground_required", false)):
			errors.append("Missing required foreground art for %s." % container_type)
		if not background_path.is_empty() and not foreground_path.is_empty() and ResourceLoader.exists(background_path) and ResourceLoader.exists(foreground_path):
			var background_texture := load(background_path) as Texture2D
			var foreground_texture := load(foreground_path) as Texture2D
			if background_texture != null and foreground_texture != null and background_texture.get_size() != foreground_texture.get_size():
				errors.append("Foreground/background dimensions differ for %s." % container_type)
		var rects := _rect_array(definition.get("slots", []))
		for index in range(rects.size()):
			var rect: Rect2 = rects[index]
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1.0 or rect.end.y > 1.0:
				errors.append("Slot %d for %s is outside normalized bounds." % [index, container_type])
			for other_index in range(index):
				var other: Rect2 = rects[other_index]
				var overlap := rect.intersection(other)
				if overlap.size.x > 0.015 and overlap.size.y > 0.015:
					errors.append("Slots %d and %d overlap for %s." % [other_index, index, container_type])
		var capacity_item_id := str(definition.get("capacity_item_id", ""))
		if not capacity_item_id.is_empty():
			var capacity := int(capacities.get(capacity_item_id, -1))
			if capacity < 0:
				errors.append("Unknown capacity item for %s: %s." % [container_type, capacity_item_id])
			elif rects.size() != capacity:
				errors.append("%s has %d authored slots but authoritative capacity is %d." % [container_type, rects.size(), capacity])
	return errors


static func _catalog_from_parsed(parsed: Variant) -> Dictionary:
	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	var presentations: Dictionary = {}
	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := (value as Dictionary).duplicate(true)
		var container_type := str(row.get("container_type", "")).strip_edges().to_lower()
		if container_type.is_empty():
			continue
		row.erase("container_type")
		presentations[container_type] = row
	return {"schema_version": 1, "presentations": presentations} if not presentations.is_empty() else {}


static func authoritative_capacities(force_reload: bool = false) -> Dictionary:
	if not force_reload and not _capacity_cache.is_empty():
		return _capacity_cache.duplicate(true)
	_capacity_cache = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = value
		var item_id := str(item.get("id", "")).strip_edges()
		var capacity := maxi(0, int(item.get("container_capacity", 0)))
		if not item_id.is_empty() and capacity > 0:
			_capacity_cache[item_id] = capacity
	return _capacity_cache.duplicate(true)


static func _generated_rects(count: int, bounds: Rect2, preferred_columns: int) -> Array:
	var result: Array = []
	if count <= 0:
		return result
	var columns := mini(maxi(1, preferred_columns), count)
	var rows := int(ceil(float(count) / float(columns)))
	var gap := 0.018
	var cell_size := Vector2(
		maxf(0.02, (bounds.size.x - gap * float(columns - 1)) / float(columns)),
		maxf(0.02, (bounds.size.y - gap * float(rows - 1)) / float(rows))
	)
	for index in range(count):
		var column := index % columns
		var row := index / columns
		result.append(Rect2(
			bounds.position + Vector2(float(column) * (cell_size.x + gap), float(row) * (cell_size.y + gap)),
			cell_size
		))
	return result


static func _rect_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for rect_value in value as Array:
		var rect := _rect_from_value(rect_value, Rect2())
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			result.append(rect)
	return result


static func _rect_from_value(value: Variant, fallback: Rect2) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_ARRAY:
		var parts: Array = value
		if parts.size() >= 4:
			return Rect2(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		return Rect2(float(data.get("x", fallback.position.x)), float(data.get("y", fallback.position.y)), float(data.get("w", fallback.size.x)), float(data.get("h", fallback.size.y)))
	return fallback


static func _fallback_catalog() -> Dictionary:
	return {
		"schema_version": 1,
		"presentations": {},
		"validation_errors": ["Inventory container catalog could not be loaded."],
	}


static func _fallback_presentation(container_type: String) -> Dictionary:
	return {
		"display_name": container_type.replace("_", " ").capitalize() if not container_type.is_empty() else "Inventory",
		"background_path": "",
		"dynamic_bounds": [0.12, 0.16, 0.76, 0.70],
		"dynamic_columns": 4,
		"item_icon_scale": 0.70,
		"slots": [],
	}
