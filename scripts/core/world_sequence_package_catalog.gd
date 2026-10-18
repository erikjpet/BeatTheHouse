class_name WorldSequencePackageCatalog
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

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
	"world06_6_quiet_read": "res://data/crew/world06_6_heist_sequences.json",
	"world06_6_closed_door": "res://data/crew/world06_6_heist_sequences.json",
}
const MAX_PACKAGES_PER_FILE := 64

static var _cache: Dictionary = {}


static func entry(package_id: String) -> Dictionary:
	return JsonCoerceScript._copy_dict(entry_result(package_id).get("entry", {}))


static func entry_result(package_id: String) -> Dictionary:
	var clean_id := package_id.strip_edges()
	if clean_id.is_empty() or clean_id != package_id or not PACKAGE_PATHS.has(clean_id):
		return _failure("unknown_package_id")
	if _cache.has(clean_id):
		return _success(JsonCoerceScript._copy_dict(_cache.get(clean_id, {})))
	var result := _entry_result_from_path(str(PACKAGE_PATHS.get(clean_id, "")), clean_id)
	if bool(result.get("ok", false)):
		_cache[clean_id] = JsonCoerceScript._copy_dict(result.get("entry", {}))
	return result


static func _entry_result_from_path(path: String, package_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("World sequence package file is missing: %s" % path)
		return _failure("package_file_missing", path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("World sequence package file could not be read: %s (error %d)" % [path, FileAccess.get_open_error()])
		return _failure("package_file_unreadable", path)
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		push_error("World sequence package file read failed: %s (error %d)" % [path, read_error])
		return _failure("package_file_unreadable", path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("package_file_corrupt", path)
	return _entry_result_from_payload(parser.data, package_id, path)


static func _entry_result_from_payload(parsed: Variant, package_id: String, path: String = "") -> Dictionary:
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).is_empty():
		return _failure("package_file_invalid", path)
	if (parsed as Array).size() > MAX_PACKAGES_PER_FILE:
		return _failure("package_file_too_large", path)
	var package: Dictionary = {}
	for package_value in parsed as Array:
		if typeof(package_value) == TYPE_DICTIONARY and str((package_value as Dictionary).get("package_id", "")) == package_id:
			package = package_value as Dictionary
			break
	if package.is_empty():
		return _failure("package_id_not_in_file", path)
	var definitions: Array = package.get("definitions", []) if typeof(package.get("definitions", [])) == TYPE_ARRAY else []
	if definitions.size() != 1 or typeof(definitions[0]) != TYPE_DICTIONARY:
		return _failure("package_definition_invalid", path)
	var result := JsonCoerceScript._copy_dict(definitions[0])
	return _success(result, path)


static func _success(package_entry: Dictionary, path: String = "") -> Dictionary:
	return {"ok": true, "error_code": "", "path": path, "entry": package_entry.duplicate(true)}


static func _failure(error_code: String, path: String = "") -> Dictionary:
	return {"ok": false, "error_code": error_code, "path": path, "entry": {}}
