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
var challenge_completions: Dictionary = {}


func load() -> void:
	items = []
	challenge_completions = {}
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
		"challenge_completions": challenge_completions.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	items = []
	challenge_completions = _normalize_challenge_completions(data.get("challenge_completions", data.get("completed_challenge_flags", {})))
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


func mark_challenge_completed(completion_flag: String, challenge_id: String = "", title: String = "") -> void:
	var flag := completion_flag.strip_edges()
	if flag.is_empty():
		return
	var entry := {
		"completed": true,
		"challenge_id": challenge_id.strip_edges(),
		"title": title.strip_edges(),
		"completed_unix": int(Time.get_unix_time_from_system()),
	}
	challenge_completions[flag] = entry


func has_challenge_completion(completion_flag: String) -> bool:
	var flag := completion_flag.strip_edges()
	if flag.is_empty() or not challenge_completions.has(flag):
		return false
	var value: Variant = challenge_completions.get(flag, {})
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_DICTIONARY:
		return bool((value as Dictionary).get("completed", false))
	return false


func _normalize_challenge_completions(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = value
	for key_value in source.keys():
		var flag := str(key_value).strip_edges()
		if flag.is_empty():
			continue
		var completion_value: Variant = source.get(key_value, {})
		if typeof(completion_value) == TYPE_BOOL:
			if bool(completion_value):
				result[flag] = {"completed": true}
		elif typeof(completion_value) == TYPE_DICTIONARY:
			var entry: Dictionary = completion_value
			if bool(entry.get("completed", false)):
				result[flag] = {
					"completed": true,
					"challenge_id": str(entry.get("challenge_id", "")).strip_edges(),
					"title": str(entry.get("title", "")).strip_edges(),
					"completed_unix": maxi(0, int(entry.get("completed_unix", 0))),
				}
	return result
