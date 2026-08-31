class_name WorldSequencePackageCatalog
extends RefCounted

# Trusted package discovery is deliberately separate from both EventModule and
# the generic adapter. Callers name an allowlisted package; only this catalog
# can turn that id into authored source, definition, channel and claim bytes.

const PACKAGE_PATHS := {
	"world06_1_crew_favor_delivery": "res://data/crew/world06_1_crew_favor_delivery_sequence.json",
	"world06_6_count_setup": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_count_play": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_count_getaway": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_whale_setup": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_whale_play": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_whale_interview": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_whale_getaway": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_quiet_clue": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_closed_door": "res://data/crew/world06_6_heist_sequences.json",
}

static var _cache: Dictionary = {}


static func entry(package_id: String) -> Dictionary:
	var clean_id := package_id.strip_edges()
	if clean_id.is_empty() or clean_id != package_id or not PACKAGE_PATHS.has(clean_id):
		return {}
	if _cache.has(clean_id):
		return _copy_dict(_cache.get(clean_id, {}))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(PACKAGE_PATHS.get(clean_id, ""))))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).is_empty() or (parsed as Array).size() > PACKAGE_PATHS.size():
		return {}
	var package: Dictionary = {}
	for package_value in parsed as Array:
		if typeof(package_value) == TYPE_DICTIONARY and str((package_value as Dictionary).get("package_id", "")) == clean_id:
			package = package_value as Dictionary
			break
	if package.is_empty():
		return {}
	var definitions: Array = package.get("definitions", []) if typeof(package.get("definitions", [])) == TYPE_ARRAY else []
	if definitions.size() != 1 or typeof(definitions[0]) != TYPE_DICTIONARY:
		return {}
	var result := _copy_dict(definitions[0])
	_cache[clean_id] = result.duplicate(true)
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
