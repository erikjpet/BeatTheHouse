class_name ProfileInventory
extends RefCounted

# Profile-level inventory lives outside RunState and survives between runs.

const INVENTORY_PATH := "user://profile_inventory.json"
const REFERENCE_CHIP_ID := "profile_poker_chip"
const REFERENCE_CHIP := {
	"id": REFERENCE_CHIP_ID,
	"display_name": "Rain City Poker Chip",
	"description": "A neon casino chip kept in your profile stash.",
	"icon_key": "poker_chip",
	"quantity": 1,
}

var items: Array = []


func load() -> void:
	items = []
	if not FileAccess.file_exists(INVENTORY_PATH):
		return
	var text := FileAccess.get_file_as_string(INVENTORY_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed)


func save() -> Error:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	items = []
	var loaded: Variant = data.get("items", [])
	if typeof(loaded) != TYPE_ARRAY:
		return
	for item in loaded:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_data := item as Dictionary
		var item_id := str(item_data.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		items.append({
			"id": item_id,
			"display_name": str(item_data.get("display_name", item_id.capitalize())),
			"description": str(item_data.get("description", "")),
			"icon_key": str(item_data.get("icon_key", "")),
			"quantity": max(1, int(item_data.get("quantity", 1))),
		})


func reference_chip() -> Dictionary:
	return REFERENCE_CHIP.duplicate(true)


func add_reference_chip(quantity: int = 1) -> void:
	var chip: Dictionary = reference_chip()
	add_item(chip, quantity)


func add_item(item: Dictionary, quantity: int = 1) -> void:
	var item_id: String = str(item.get("id", "")).strip_edges()
	if item_id.is_empty():
		return
	var add_quantity: int = max(1, quantity)
	for entry in items:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == item_id:
			entry["quantity"] = int((entry as Dictionary).get("quantity", 1)) + add_quantity
			return
	var copy: Dictionary = item.duplicate(true)
	copy["quantity"] = add_quantity
	items.append(copy)


func has_item(item_id: String) -> bool:
	return item_quantity(item_id) > 0


func item_quantity(item_id: String) -> int:
	for entry in items:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == item_id:
			return int((entry as Dictionary).get("quantity", 0))
	return 0
