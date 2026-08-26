class_name ScenarioSequenceCatalog
extends RefCounted

const ScenarioExtensionDispatchScript := preload("res://scripts/core/scenario_extension_dispatch.gd")

# Scenario packages are immutable JSON overlays loaded in lexical file order.
# They can add the dynamic sequence contract to a legacy scenario, but they can
# never replace its identity, weight, presentation mutation, or event pool.

const PACKAGE_SCHEMA_VERSION := 1
const DEFAULT_ROOT := "res://data/environments/scenario_sequences"
const LEGACY_CATALOG_PATH := "res://data/environments/scenarios.json"
const PACKAGE_KEYS := ["schema_version", "package_id", "handler_pack", "renderer_id", "scenarios"]
const ENTRY_KEYS := ["scenario_id", "sequence", "authoring"]
const AUTHORING_KEYS := [
	"arrival_summary", "player_verbs", "world_connections", "references",
	"capture_ids", "seed_evidence", "masked_visual_explanations",
]
const PACKAGE_ORDER := [
	"env06_7_shops_streets",
	"env06_7_bars_road",
	"env06_7_punchline_clubs",
	"env06_7_queen_public",
]

static var _default_catalog_cache: Dictionary = {}


static func load_catalog(root_path: String = DEFAULT_ROOT) -> Dictionary:
	var overlays: Dictionary = {}
	var packages: Array = []
	var failures: Array = []
	var claimed_packages: Dictionary = {}
	var claimed_handlers: Dictionary = {}
	var claimed_renderers: Dictionary = {}
	var files := _json_files(root_path, failures)
	for file_name_value in files:
		var file_name := str(file_name_value)
		var path := "%s/%s" % [root_path.trim_suffix("/"), file_name]
		var package_failures: Array = []
		var parsed := _parse_dictionary(path, package_failures)
		if parsed.is_empty():
			failures.append_array(package_failures)
			continue
		_validate_keys("scenario sequence package %s" % file_name, parsed, PACKAGE_KEYS, package_failures)
		if int(parsed.get("schema_version", 0)) != PACKAGE_SCHEMA_VERSION:
			package_failures.append("scenario sequence package %s schema_version must be %d." % [file_name, PACKAGE_SCHEMA_VERSION])
		var package_id := str(parsed.get("package_id", "")).strip_edges()
		var handler_pack := str(parsed.get("handler_pack", "")).strip_edges()
		var renderer_id := str(parsed.get("renderer_id", "")).strip_edges()
		if not _valid_id(package_id) or not _valid_id(handler_pack) or not _valid_id(renderer_id):
			package_failures.append("scenario sequence package %s requires stable package_id, handler_pack, and renderer_id." % file_name)
		if claimed_packages.has(package_id): package_failures.append("scenario sequence package_id %s is duplicated." % package_id)
		if claimed_handlers.has(handler_pack): package_failures.append("scenario sequence handler_pack %s is duplicated." % handler_pack)
		if claimed_renderers.has(renderer_id): package_failures.append("scenario sequence renderer_id %s is duplicated." % renderer_id)
		package_failures.append_array(ScenarioExtensionDispatchScript.validate_package_extensions(package_id, handler_pack, renderer_id))
		var package_row := {
			"package_id": package_id,
			"file_name": file_name,
			"handler_pack": handler_pack,
			"renderer_id": renderer_id,
			"scenario_ids": [],
		}
		var entries_value: Variant = parsed.get("scenarios", [])
		if typeof(entries_value) != TYPE_ARRAY:
			package_failures.append("scenario sequence package %s scenarios must be an array." % file_name)
			entries_value = []
		elif (entries_value as Array).is_empty():
			package_failures.append("scenario sequence package %s must not be empty." % file_name)
		var local_overlays: Dictionary = {}
		for index in range((entries_value as Array).size()):
			var entry_value: Variant = (entries_value as Array)[index]
			if typeof(entry_value) != TYPE_DICTIONARY:
				package_failures.append("scenario sequence package %s scenarios[%d] must be a dictionary." % [file_name, index])
				continue
			var entry := (entry_value as Dictionary).duplicate(true)
			_validate_keys("scenario sequence package %s scenarios[%d]" % [file_name, index], entry, ENTRY_KEYS, package_failures)
			var scenario_id := str(entry.get("scenario_id", "")).strip_edges()
			if not _valid_id(scenario_id):
				package_failures.append("scenario sequence package %s scenarios[%d] has invalid scenario_id." % [file_name, index])
				continue
			if overlays.has(scenario_id) or local_overlays.has(scenario_id):
				package_failures.append("scenario sequence scenario_id %s is claimed more than once." % scenario_id)
				continue
			if typeof(entry.get("sequence", {})) != TYPE_DICTIONARY or (entry.get("sequence", {}) as Dictionary).is_empty():
				package_failures.append("scenario sequence package %s scenario %s requires a sequence dictionary." % [file_name, scenario_id])
				continue
			var authoring := _dict(entry.get("authoring", {}))
			_validate_keys("scenario sequence package %s scenario %s authoring" % [file_name, scenario_id], authoring, AUTHORING_KEYS, package_failures)
			_validate_authoring(scenario_id, authoring, package_failures)
			local_overlays[scenario_id] = {
				"scenario_id": scenario_id,
				"package_id": package_id,
				"package_file": file_name,
				"handler_pack": handler_pack,
				"renderer_id": renderer_id,
				"sequence": _dict(entry.get("sequence", {})),
				"authoring": authoring,
			}
			(package_row["scenario_ids"] as Array).append(scenario_id)
		(package_row["scenario_ids"] as Array).sort()
		if not package_failures.is_empty():
			failures.append_array(package_failures)
			continue
		claimed_packages[package_id] = file_name
		claimed_handlers[handler_pack] = file_name
		claimed_renderers[renderer_id] = file_name
		for scenario_id_value in local_overlays.keys(): overlays[scenario_id_value] = local_overlays.get(scenario_id_value)
		packages.append(package_row)
	packages.sort_custom(Callable(ScenarioSequenceCatalog, "_sort_packages"))
	var active_overlays := overlays if failures.is_empty() else {}
	return {
		"ok": failures.is_empty(),
		"root_path": root_path,
		"files": files,
		"package_order": PACKAGE_ORDER.duplicate(),
		"packages": packages,
		"overlays": active_overlays,
		"rejected_overlay_count": overlays.size() if not failures.is_empty() else 0,
		"failures": failures,
	}


static func overlay_for(scenario_id: String, catalog: Dictionary = {}) -> Dictionary:
	var source := _default_catalog() if catalog.is_empty() else catalog
	if not bool(source.get("ok", false)):
		return {}
	return _dict(_dict(source.get("overlays", {})).get(scenario_id.strip_edges(), {}))


static func apply_overlay(definition: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	if definition.is_empty():
		return {}
	var scenario_id := str(definition.get("id", definition.get("scenario_id", ""))).strip_edges()
	var overlay := overlay_for(scenario_id, catalog)
	if overlay.is_empty():
		return definition.duplicate(true)
	var result := definition.duplicate(true)
	result["sequence"] = _dict(overlay.get("sequence", {}))
	result["sequence_package_id"] = str(overlay.get("package_id", ""))
	result["sequence_handler_pack"] = str(overlay.get("handler_pack", ""))
	result["sequence_renderer_id"] = str(overlay.get("renderer_id", ""))
	result["sequence_authoring"] = _dict(overlay.get("authoring", {}))
	return result


static func legacy_scenario_ids(path: String = LEGACY_CATALOG_PATH) -> Array:
	var failures: Array = []
	var source := _parse_dictionary(path, failures)
	var result: Array = []
	for archetype_value in source.keys():
		for definition_value in _array(source.get(archetype_value, [])):
			var scenario_id := str(_dict(definition_value).get("id", "")).strip_edges()
			if _valid_id(scenario_id) and not result.has(scenario_id):
				result.append(scenario_id)
	result.sort()
	return result


static func legacy_definition(scenario_id: String, path: String = LEGACY_CATALOG_PATH, catalog: Dictionary = {}) -> Dictionary:
	var wanted := scenario_id.strip_edges()
	if wanted.is_empty():
		return {}
	var failures: Array = []
	var source := _parse_dictionary(path, failures)
	for pool_value in source.values():
		for definition_value in _array(pool_value):
			var definition := _dict(definition_value)
			if str(definition.get("id", "")) == wanted:
				return apply_overlay(definition, catalog)
	return {}


static func clear_default_cache() -> void:
	_default_catalog_cache = {}


static func default_catalog_snapshot() -> Dictionary:
	return _default_catalog().duplicate(true)


static func _default_catalog() -> Dictionary:
	if _default_catalog_cache.is_empty():
		_default_catalog_cache = load_catalog(DEFAULT_ROOT)
	return _default_catalog_cache


static func _json_files(root_path: String, failures: Array) -> Array:
	var directory := DirAccess.open(root_path)
	if directory == null:
		failures.append("scenario sequence package directory is missing: %s" % root_path)
		return []
	var result: Array = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
			result.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


static func _parse_dictionary(path: String, failures: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		failures.append("scenario sequence content file is missing: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("scenario sequence content file must contain a JSON dictionary: %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


static func _validate_keys(label: String, value: Dictionary, allowed: Array, failures: Array) -> void:
	for key_value in value.keys():
		if not allowed.has(str(key_value)):
			failures.append("%s contains unknown key: %s." % [label, str(key_value)])


static func _validate_authoring(scenario_id: String, authoring: Dictionary, failures: Array) -> void:
	for key in ["arrival_summary", "player_verbs", "world_connections", "references", "capture_ids", "seed_evidence", "masked_visual_explanations"]:
		if not authoring.has(key): failures.append("scenario %s authoring is missing %s." % [scenario_id, key])
	if str(authoring.get("arrival_summary", "")).strip_edges().is_empty(): failures.append("scenario %s authoring arrival_summary is empty." % scenario_id)
	for key in ["player_verbs", "world_connections", "capture_ids"]:
		var values := _strict_id_array(authoring.get(key, []))
		if values.is_empty() or values.size() != _array(authoring.get(key, [])).size():
			failures.append("scenario %s authoring %s must be a non-empty unique stable-id array." % [scenario_id, key])
	var references := _dict(authoring.get("references", {}))
	if references.is_empty(): failures.append("scenario %s authoring references must be a non-empty dictionary." % scenario_id)
	for registry_value in references.keys():
		var registry := str(registry_value)
		if not ["events", "games", "services", "items", "actors", "objects"].has(registry):
			failures.append("scenario %s authoring references unknown registry %s." % [scenario_id, registry])
		elif registry == "objects":
			var object_refs := _strict_object_reference_array(references.get(registry, []))
			if object_refs.size() != _array(references.get(registry, [])).size():
				failures.append("scenario %s authoring references.objects must use unique owner::stable_id identities." % scenario_id)
		elif _strict_id_array(references.get(registry, [])).size() != _array(references.get(registry, [])).size():
			failures.append("scenario %s authoring references.%s must be a unique stable-id array." % [scenario_id, registry])
	var seed_evidence := _dict(authoring.get("seed_evidence", {}))
	if seed_evidence.is_empty(): failures.append("scenario %s authoring seed_evidence must be non-empty." % scenario_id)
	for seed_key_value in seed_evidence.keys():
		if not _valid_id(str(seed_key_value)) or not _bounded_evidence_value(seed_evidence.get(seed_key_value)):
			failures.append("scenario %s authoring seed_evidence.%s is not a bounded scalar/string-array value." % [scenario_id, str(seed_key_value)])
	var explanations := _dict(authoring.get("masked_visual_explanations", {}))
	for pair_key_value in explanations.keys():
		var pair_key := str(pair_key_value)
		if pair_key.split("::", false).size() != 2 or str(explanations.get(pair_key_value, "")).strip_edges().is_empty():
			failures.append("scenario %s authoring masked_visual_explanations requires canonical id::id keys and non-empty text." % scenario_id)


static func _strict_id_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY: return result
	for item_value in value as Array:
		var item := str(item_value).strip_edges()
		if not _valid_id(item) or result.has(item): return []
		result.append(item)
	return result


static func _strict_object_reference_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY: return result
	for item_value in value as Array:
		var item := str(item_value).strip_edges()
		var parts := item.split("::", false)
		if parts.size() != 2 or not ["base", "traveler", "service", "game", "event", "crew", "scenario", "sweep"].has(str(parts[0])) or not _valid_semantic_id(str(parts[1])) or result.has(item):
			return []
		result.append(item)
	return result


static func _valid_semantic_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty() or text.contains("::"): return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45 and code != 58:
			return false
	return true


static func _bounded_evidence_value(value: Variant) -> bool:
	if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]: return true
	if typeof(value) == TYPE_STRING: return not str(value).strip_edges().is_empty() and str(value).length() <= 256
	return _strict_id_array(value).size() == _array(value).size() and not _array(value).is_empty() if typeof(value) == TYPE_ARRAY else false


static func _sort_packages(a: Dictionary, b: Dictionary) -> bool:
	return PACKAGE_ORDER.find(str(a.get("package_id", ""))) < PACKAGE_ORDER.find(str(b.get("package_id", "")))


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45:
			return false
	return true


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
