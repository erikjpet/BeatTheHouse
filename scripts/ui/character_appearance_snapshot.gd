class_name CharacterAppearanceSnapshot
extends RefCounted

# A detached presentation value, never an owner of character or equipment state.
# These are TableGameVisuals._draw_table_character's canonical fallback colors.
const DEFAULT_MODEL := {
	"skin_color": "#c49371", "hair_color": "#171022",
	"jacket_color": "#1d2030", "accent_color": "#00f5ff",
	"silhouette": "coat", "scale": 1.0,
}
const SILHOUETTES := ["coat", "hoodie", "cap", "glasses", "rings"]
const ACCESSORY_KINDS := ["glasses", "cap", "rings"]
const EQUIPMENT_VISUALS := {
	"glasses": "glasses", "sunglasses": "glasses",
	"cap": "cap", "poker_hat": "cap", "rings": "rings",
}


static func from_character(definition: Dictionary, explicit_equipment_definitions: Array = []) -> Dictionary:
	# Accept a catalog character/actor member, or its model alone. Never select an
	# NPC identity on behalf of the player and never consume the run's RNG.
	var model_value: Variant = definition.get("model", definition)
	var model := normalize_model(model_value if typeof(model_value) == TYPE_DICTIONARY else {})
	var result := {
		"schema_version": 1,
		"source": "character_definition",
		"character_id": str(definition.get("id", "")),
		"display_name": str(definition.get("display_name", definition.get("name", ""))),
		"role": str(definition.get("role", "")),
		"model": model,
		"accessories": [],
		"unsupported_visual_ids": [],
		"active_item_id": "",
		"active_item_status": "none",
	}
	for value in explicit_equipment_definitions:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = value
		var kind := str(EQUIPMENT_VISUALS.get(str(item.get("environment_prop", "")), ""))
		var item_id := str(item.get("id", ""))
		if kind in ACCESSORY_KINDS:
			result["accessories"].append({"kind": kind, "item_id": item_id})
		elif not item_id.is_empty() and not result["unsupported_visual_ids"].has(item_id):
			result["unsupported_visual_ids"].append(item_id)
	return result


static func from_run(run: Variant, library: Variant) -> Dictionary:
	# CurrentRunState has no player model or wearable slots. Its one authoritative
	# selection is active_item_id. Owned passive items must NOT become worn gear.
	var result := from_character({})
	result["source"] = "run_default"
	var active_id := str(_field(run, "active_item_id", ""))
	result["active_item_id"] = active_id
	if active_id.is_empty():
		return result
	var inventory_value: Variant = _field(run, "inventory", [])
	var inventory: Array = inventory_value if typeof(inventory_value) == TYPE_ARRAY else []
	# Match the current active-slot setter and save-restorer: string IDs only.
	if not inventory.has(active_id):
		result["active_item_status"] = "not_carried"
		return result
	var definition := _item_definition(library, active_id)
	if definition.is_empty():
		result["active_item_status"] = "unknown_item"
		return result
	var effect_value: Variant = definition.get("effect", {})
	var effect: Dictionary = effect_value if typeof(effect_value) == TYPE_DICTIONARY else {}
	var item_class := str(definition.get("class", definition.get("item_type", ""))).to_lower()
	if item_class != "active" and not bool(effect.get("active_item", false)):
		result["active_item_status"] = "not_active_item"
		return result
	var equipped := from_character({}, [definition])
	result["accessories"] = equipped["accessories"]
	result["unsupported_visual_ids"] = equipped["unsupported_visual_ids"]
	result["active_item_status"] = "supported" if not equipped["accessories"].is_empty() else "unsupported_visual"
	return result


static func normalize_model(model: Dictionary) -> Dictionary:
	var result := DEFAULT_MODEL.duplicate(true)
	for field in ["skin_color", "hair_color", "jacket_color", "accent_color"]:
		result[field] = _safe_color(model.get(field), Color(DEFAULT_MODEL[field])).to_html(false).insert(0, "#")
	var silhouette := str(model.get("silhouette", "coat"))
	result["silhouette"] = silhouette if silhouette in SILHOUETTES else "coat"
	result["scale"] = _bounded_number(model.get("scale", 1.0), 1.0, 0.75, 1.25)
	return result


static func normalized(snapshot_value: Dictionary) -> Dictionary:
	# Whitelist serializable fields, so a view never retains a live RunState,
	# catalog reference, or mutable caller dictionary in its snapshot.
	var model_value: Variant = snapshot_value.get("model", {})
	var result := from_character({
		"id": str(snapshot_value.get("character_id", "")),
		"display_name": str(snapshot_value.get("display_name", "")),
		"role": str(snapshot_value.get("role", "")),
		"model": model_value if typeof(model_value) == TYPE_DICTIONARY else {},
	})
	result["source"] = str(snapshot_value.get("source", "character_definition"))
	result["active_item_id"] = str(snapshot_value.get("active_item_id", ""))
	result["active_item_status"] = str(snapshot_value.get("active_item_status", "none"))
	var accessories_value: Variant = snapshot_value.get("accessories", [])
	if typeof(accessories_value) == TYPE_ARRAY:
		for value in accessories_value:
			if typeof(value) == TYPE_DICTIONARY and str(value.get("kind", "")) in ACCESSORY_KINDS:
				result["accessories"].append({"kind": str(value["kind"]), "item_id": str(value.get("item_id", ""))})
	var unsupported_value: Variant = snapshot_value.get("unsupported_visual_ids", [])
	if typeof(unsupported_value) == TYPE_ARRAY:
		for value in unsupported_value:
			if typeof(value) == TYPE_STRING and not value.is_empty() and not result["unsupported_visual_ids"].has(value):
				result["unsupported_visual_ids"].append(value)
	return result


static func _safe_color(value: Variant, fallback: Color) -> Color:
	var color := fallback
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		color = Color(value)
	elif typeof(value) == TYPE_COLOR:
		color = value
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b):
		return fallback
	return Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0), 1.0)


static func _bounded_number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number := float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else fallback


static func _field(source: Variant, key: String, fallback: Variant) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		return source.get(key, fallback)
	if source is Object and is_instance_valid(source):
		for property in source.get_property_list():
			if str(property.get("name", "")) == key:
				return source.get(key)
	return fallback


static func _item_definition(library: Variant, item_id: String) -> Dictionary:
	# Read the loaded catalog directly. ContentLibrary.item() can populate a
	# lookup cache, and snapshot construction promises not to mutate either input.
	var items_value: Variant = _field(library, "items", [])
	if typeof(items_value) == TYPE_ARRAY:
		for value in items_value:
			if typeof(value) == TYPE_DICTIONARY and str(value.get("id", "")) == item_id:
				return value
	return {}
