class_name ScenarioExtensionDispatch
extends RefCounted

const BASE_EXTENSION_ID := "semantic_v1"
const HANDLER_ROOT := "res://scripts/core/scenario_handlers"
const RENDERER_ROOT := "res://scripts/ui/scenario_renderers"
const PACKAGE_EXTENSIONS := {
	"env06_7_shops_streets": "shops_streets",
	"env06_7_roadside_shelter": "roadside_shelter",
	"env06_7_bars_road": "bars_road",
	"env06_7_punchline_clubs": "punchline_clubs",
	"env06_7_queen_public": "queen_public",
}
const ALLOWED_EXTENSION_IDS := [BASE_EXTENSION_ID, "shops_streets", "roadside_shelter", "bars_road", "punchline_clubs", "queen_public"]


static func validate_package_extensions(package_id: String, handler_pack: String, renderer_id: String) -> Array:
	var errors: Array = []
	var expected := str(PACKAGE_EXTENSIONS.get(package_id, ""))
	if expected.is_empty():
		errors.append("scenario package_id %s is outside the fixed depth-program extension registry." % package_id)
		return errors
	if handler_pack != expected or renderer_id != expected:
		errors.append("scenario package %s must use handler_pack and renderer_id %s." % [package_id, expected])
		return errors
	errors.append_array(_validate_extension(_handler_path(handler_pack), handler_pack, "prepare_command", "handler"))
	errors.append_array(_validate_extension(_renderer_path(renderer_id), renderer_id, "prepare", "renderer"))
	return errors


static func prepare_command(definition: Dictionary, command: Dictionary, context: Dictionary) -> Dictionary:
	var extension_id := str(definition.get("sequence_handler_pack", BASE_EXTENSION_ID)).strip_edges()
	if extension_id.is_empty(): extension_id = BASE_EXTENSION_ID
	var loaded := _load_extension(_handler_path(extension_id), extension_id, "prepare_command", "handler")
	if not bool(loaded.get("ok", false)):
		return loaded
	var instance: Variant = loaded.get("instance")
	var result: Variant = instance.call("prepare_command", command.duplicate(true), context.duplicate(true))
	if typeof(result) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["scenario handler %s returned an invalid command result." % extension_id]}
	var response := (result as Dictionary).duplicate(true)
	var contract_errors := _handler_response_errors(response, command, context)
	if not contract_errors.is_empty():
		return {"ok": false, "errors": contract_errors}
	return response


static func prepare_render(definition: Dictionary, environment: Dictionary, projection: Dictionary) -> Dictionary:
	var extension_id := str(definition.get("sequence_renderer_id", BASE_EXTENSION_ID)).strip_edges()
	if extension_id.is_empty(): extension_id = BASE_EXTENSION_ID
	var loaded := _load_extension(_renderer_path(extension_id), extension_id, "prepare", "renderer")
	if not bool(loaded.get("ok", false)):
		return {"schema_version": 1, "ok": false, "errors": _array(loaded.get("errors", [])), "visual_objects": [], "interaction_overlays": []}
	var instance: Variant = loaded.get("instance")
	var result: Variant = instance.call("prepare", environment.duplicate(true), projection.duplicate(true))
	if typeof(result) != TYPE_DICTIONARY:
		return {"schema_version": 1, "ok": false, "errors": ["scenario renderer %s returned an invalid prepared snapshot." % extension_id], "visual_objects": [], "interaction_overlays": []}
	var response := (result as Dictionary).duplicate(true)
	var contract_errors := _renderer_response_errors(response)
	if not contract_errors.is_empty():
		return {"schema_version": 1, "ok": false, "errors": contract_errors, "visual_objects": [], "interaction_overlays": []}
	response["renderer_id"] = extension_id
	return response


static func extension_paths(extension_id: String) -> Dictionary:
	return {"handler": _handler_path(extension_id), "renderer": _renderer_path(extension_id)}


static func _validate_extension(path: String, extension_id: String, method_name: String, kind: String) -> Array:
	var loaded := _load_extension(path, extension_id, method_name, kind)
	return _array(loaded.get("errors", [])) if not bool(loaded.get("ok", false)) else []


static func _load_extension(path: String, extension_id: String, method_name: String, kind: String) -> Dictionary:
	if not ALLOWED_EXTENSION_IDS.has(extension_id):
		return {"ok": false, "errors": ["scenario %s extension %s is outside the fixed extension allowlist." % [kind, extension_id]]}
	if extension_id.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["scenario %s extension %s is missing at %s." % [kind, extension_id, path]]}
	var resource := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE)
	if not resource is Script or not (resource as Script).can_instantiate():
		return {"ok": false, "errors": ["scenario %s extension %s is not a loadable script." % [kind, extension_id]]}
	var script := resource as Script
	var instance: Variant = script.new()
	if instance == null or not instance.has_method("extension_id") or not instance.has_method(method_name):
		return {"ok": false, "errors": ["scenario %s extension %s does not implement the required contract." % [kind, extension_id]]}
	if str(instance.call("extension_id")) != extension_id:
		return {"ok": false, "errors": ["scenario %s extension at %s declares the wrong extension_id." % [kind, path]]}
	return {"ok": true, "instance": instance, "errors": []}


static func _handler_response_errors(response: Dictionary, original_command: Dictionary, original_context: Dictionary) -> Array:
	var errors: Array = []
	if not response.has("ok") or typeof(response.get("ok")) != TYPE_BOOL:
		errors.append("scenario handler result requires boolean ok.")
	if typeof(response.get("errors", [])) != TYPE_ARRAY:
		errors.append("scenario handler result requires errors array.")
	if typeof(response.get("command", {})) != TYPE_DICTIONARY or typeof(response.get("context", {})) != TYPE_DICTIONARY:
		errors.append("scenario handler result requires command and context dictionaries.")
		return errors
	var command := response.get("command", {}) as Dictionary
	var context := response.get("context", {}) as Dictionary
	for key in ["schema_version", "command_id", "node_id", "expected_phase", "idempotency_key", "owner_namespace", "stable_object_id"]:
		if command.get(key) != original_command.get(key):
			errors.append("scenario handler cannot rewrite authoritative command.%s." % key)
	if typeof(command.get("payload", {})) != TYPE_DICTIONARY:
		errors.append("scenario handler command.payload must remain a dictionary.")
	if context != original_context:
		errors.append("scenario handler cannot rewrite authoritative runtime context.")
	return errors


static func _renderer_response_errors(response: Dictionary) -> Array:
	var errors: Array = []
	if not response.has("ok") or typeof(response.get("ok")) != TYPE_BOOL:
		errors.append("scenario renderer result requires boolean ok.")
	if typeof(response.get("errors", [])) != TYPE_ARRAY:
		errors.append("scenario renderer result requires errors array.")
	for key in ["visual_objects", "interaction_overlays", "services", "games", "routes", "active_stages"]:
		if typeof(response.get(key, [])) != TYPE_ARRAY:
			errors.append("scenario renderer result requires %s array." % key)
	if not bool(response.get("ok", false)):
		if not _array(response.get("visual_objects", [])).is_empty() or not _array(response.get("interaction_overlays", [])).is_empty():
			errors.append("scenario renderer failure must publish no visuals or interactions.")
	return errors


static func _handler_path(extension_id: String) -> String:
	return "%s/%s.gd" % [HANDLER_ROOT, extension_id]


static func _renderer_path(extension_id: String) -> String:
	return "%s/%s.gd" % [RENDERER_ROOT, extension_id]


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
