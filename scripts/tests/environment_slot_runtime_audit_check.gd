extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const LAYOUT_AUTHORITY_PATH := "res://data/environments/scenario_slot_layouts.json"
const COMMITTED_PLACEMENT_PATH := "res://data/environments/developer_placement_overrides.json"
const ISOLATED_USER_PLACEMENT_PATH := "res://.tmp/environment_slot_runtime_audit_check/user_overrides.json"
const EXPECTED_BASE_CONTEXTS := 20
const EXPECTED_SCENARIO_CONTEXTS := 55
const EXPECTED_CONTEXTS := EXPECTED_BASE_CONTEXTS + EXPECTED_SCENARIO_CONTEXTS
const SEEDS_PER_CONTEXT := 6
const ROOT_SEED := 174763
const MAX_REASONABLE_ROOM_OBJECTS := 20

var failures: Array[String] = []
var failure_keys: Dictionary = {}
var samples_checked := 0
var room_objects_checked := 0
var max_room_objects := 0
var max_room_objects_sample := ""
var previous_user_placement_path := ""
var previous_project_placement_path := ""
var isolated_user_placement_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_configure_source_geometry()
	var library := ContentLibraryScript.new()
	library.load(false)
	var authority := _read_json(LAYOUT_AUTHORITY_PATH)
	var contexts := _runtime_contexts(authority)
	var archetypes := _archetypes_by_id(library)
	for context_value in contexts:
		_audit_context(_dict(context_value), archetypes, library)

	_check_once(
		"sample_count",
		samples_checked == EXPECTED_CONTEXTS * SEEDS_PER_CONTEXT,
		"Runtime slot audit generated %d samples; expected %d." % [samples_checked, EXPECTED_CONTEXTS * SEEDS_PER_CONTEXT]
	)
	_check_once(
		"reasonable_room_object_max",
		max_room_objects <= MAX_REASONABLE_ROOM_OBJECTS,
		"Runtime slot audit found %d occupied room objects in %s; the reviewed limit is %d." % [
			max_room_objects, max_room_objects_sample, MAX_REASONABLE_ROOM_OBJECTS,
		]
	)
	_restore_placement_paths()
	if failures.is_empty():
		print("ENVIRONMENT_SLOT_RUNTIME_AUDIT_CHECK PASS contexts=%d seeds_per_context=%d samples=%d room_objects=%d max_room_objects=%d" % [
			contexts.size(), SEEDS_PER_CONTEXT, samples_checked, room_objects_checked, max_room_objects,
		])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT_SLOT_RUNTIME_AUDIT_CHECK FAIL contexts=%d seeds_per_context=%d samples=%d failures=%d" % [
		contexts.size(), SEEDS_PER_CONTEXT, samples_checked, failures.size(),
	])
	quit(1)


func _configure_source_geometry() -> void:
	previous_user_placement_path = OS.get_environment(DeveloperPlacementStoreScript.USER_PATH_ENV)
	previous_project_placement_path = OS.get_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV)
	isolated_user_placement_path = ProjectSettings.globalize_path(ISOLATED_USER_PLACEMENT_PATH)
	for path in [isolated_user_placement_path, "%s.bak" % isolated_user_placement_path]:
		if FileAccess.file_exists(path):
			_check_once(
				"isolated_user_cleanup:%s" % path,
				DirAccess.remove_absolute(path) == OK,
				"Runtime slot audit could not remove stale isolated placement file %s." % path
			)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, isolated_user_placement_path)
	OS.set_environment(
		DeveloperPlacementStoreScript.PROJECT_PATH_ENV,
		ProjectSettings.globalize_path(COMMITTED_PLACEMENT_PATH)
	)
	DeveloperPlacementStoreScript.reload()


func _restore_placement_paths() -> void:
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, previous_user_placement_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, previous_project_placement_path)
	DeveloperPlacementStoreScript.reload()
	for path in [isolated_user_placement_path, "%s.bak" % isolated_user_placement_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _runtime_contexts(authority: Dictionary) -> Array:
	var contexts: Array = []
	var seen: Dictionary = {}
	var base_ids := _array(authority.get("base_layout_ids", []))
	var layouts := _array(authority.get("layouts", []))
	_check_once(
		"base_context_count",
		base_ids.size() == EXPECTED_BASE_CONTEXTS,
		"Runtime slot authority declares %d base contexts; expected %d." % [base_ids.size(), EXPECTED_BASE_CONTEXTS]
	)
	_check_once(
		"scenario_context_count",
		layouts.size() == EXPECTED_SCENARIO_CONTEXTS,
		"Runtime slot authority declares %d scenario contexts; expected %d." % [layouts.size(), EXPECTED_SCENARIO_CONTEXTS]
	)
	_check_once(
		"declared_scenario_context_count",
		int(authority.get("layout_count", -1)) == EXPECTED_SCENARIO_CONTEXTS,
		"Runtime slot authority layout_count must remain %d." % EXPECTED_SCENARIO_CONTEXTS
	)
	for map_id_value in base_ids:
		var map_id := str(map_id_value).strip_edges()
		var context_id := "%s::base" % map_id
		if map_id.is_empty():
			_check_once("empty_base_context", false, "Runtime slot authority contains an empty base context ID.")
			continue
		if seen.has(context_id):
			_check_once("duplicate_context:%s" % context_id, false, "Runtime slot authority contains duplicate context %s." % context_id)
			continue
		seen[context_id] = true
		contexts.append({"context_id": context_id, "map_id": map_id, "scenario_id": ""})
	for layout_value in layouts:
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", "")).strip_edges()
		var scenario_id := str(layout.get("scenario_id", "")).strip_edges()
		var context_id := "%s::%s" % [map_id, scenario_id]
		if map_id.is_empty() or scenario_id.is_empty():
			_check_once("malformed_context:%s" % context_id, false, "Runtime slot authority contains a scenario context without map/scenario identity.")
			continue
		_check_once(
			"canonical_context:%s" % context_id,
			str(layout.get("layout_id", "")) == context_id,
			"Runtime slot authority context %s has a noncanonical layout_id." % context_id
		)
		if seen.has(context_id):
			_check_once("duplicate_context:%s" % context_id, false, "Runtime slot authority contains duplicate context %s." % context_id)
			continue
		seen[context_id] = true
		contexts.append({"context_id": context_id, "map_id": map_id, "scenario_id": scenario_id})
	contexts.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str(_dict(left).get("context_id", "")) < str(_dict(right).get("context_id", ""))
	)
	_check_once(
		"reachable_context_count",
		contexts.size() == EXPECTED_CONTEXTS,
		"Runtime slot audit found %d unique reachable contexts; expected %d." % [contexts.size(), EXPECTED_CONTEXTS]
	)
	return contexts


func _archetypes_by_id(library: ContentLibrary) -> Dictionary:
	var result: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if not archetype_id.is_empty():
			result[archetype_id] = archetype
	return result


func _audit_context(context: Dictionary, archetypes: Dictionary, library: ContentLibrary) -> void:
	var context_id := str(context.get("context_id", ""))
	var map_id := str(context.get("map_id", ""))
	var scenario_id := str(context.get("scenario_id", ""))
	var map_parts := map_id.split(":", false, 1)
	var archetype_id := str(map_parts[0]) if not map_parts.is_empty() else ""
	var layer_id := str(map_parts[1]) if map_parts.size() > 1 else ""
	var archetype := _dict(archetypes.get(archetype_id, {}))
	if archetype.is_empty():
		_check_once("missing_archetype:%s" % context_id, false, "%s has no runtime archetype %s." % [context_id, archetype_id])
		return
	var scenario_definition: Dictionary = {}
	if not scenario_id.is_empty():
		scenario_definition = library.scenario(scenario_id)
		if scenario_definition.is_empty():
			_check_once("missing_scenario:%s" % context_id, false, "%s has no runtime scenario definition." % context_id)
			return

	for seed_index in range(SEEDS_PER_CONTEXT):
		var rng := RngStreamScript.new()
		var seed := RngStreamScript.derive_seed(ROOT_SEED, ROOT_SEED, "%s:%d" % [context_id, seed_index])
		rng.configure(seed)
		var instance = EnvironmentInstanceScript.from_archetype(
			archetype, 1, rng, library, {}, scenario_definition
		) if layer_id.is_empty() else EnvironmentInstanceScript.from_archetype_layer(
			archetype, layer_id, 1, rng, library, {}, scenario_definition
		)
		var environment: Dictionary = instance.to_dict()
		samples_checked += 1
		var sample_id := "%s seed=%d" % [context_id, seed_index]
		_check_once(
			"generated_map:%s" % sample_id,
			str(environment.get("archetype_id", "")) == archetype_id,
			"%s generated the wrong archetype." % sample_id
		)
		if not layer_id.is_empty():
			_check_once(
				"generated_layer:%s" % sample_id,
				str(environment.get("current_layer_id", "")) == layer_id,
				"%s generated the wrong environment layer." % sample_id
			)
		var surface := EnvironmentPlacementScript.surface_map(environment)
		_check_once(
			"surface_map:%s" % sample_id,
			str(surface.get("id", "")) == map_id,
			"%s resolved placement map %s instead of %s." % [sample_id, str(surface.get("id", "")), map_id]
		)
		if not scenario_id.is_empty():
			_check_once(
				"scenario_layout:%s" % sample_id,
				str(surface.get("scenario_layout_id", "")) == context_id,
				"%s did not resolve its exact scenario slot layout." % sample_id
			)
		var slots_by_id := _active_slots(surface, sample_id)
		var surface_validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
		if not bool(surface_validation.get("ok", false)):
			_check_once(
				"invalid_surface:%s" % sample_id,
				false,
				"%s has invalid active slot authority: %s" % [sample_id, JSON.stringify(surface_validation.get("errors", []))]
			)
		var entries: Array = EnvironmentInstanceScript.active_object_manifest_rows(environment)
		var manifest_errors := EnvironmentInstanceScript.object_manifest_errors(environment)
		_check_once(
			"manifest_error:%s" % sample_id,
			manifest_errors.is_empty(),
			"%s generated an invalid live object manifest: %s" % [sample_id, JSON.stringify(manifest_errors)]
		)
		var live_binding := EnvironmentSlotBinderScript.validate_base_layout_authority(environment, entries)
		_audit_binding(sample_id, entries, slots_by_id, live_binding)
		var rebound := EnvironmentSlotBinderScript.bind_base_layout(environment, entries, {})
		if not bool(rebound.get("ok", false)):
			_check_once(
				"rebinding_error:%s" % sample_id,
				false,
				"%s could not rebind its live room objects: %s" % [sample_id, JSON.stringify(rebound.get("errors", []))]
			)
		if bool(live_binding.get("ok", false)) and bool(rebound.get("ok", false)):
			var live_digest := EnvironmentSlotBinderScript.binding_digest(_dict(live_binding.get("slot_bindings", {})))
			var rebound_digest := EnvironmentSlotBinderScript.binding_digest(_dict(rebound.get("slot_bindings", {})))
			_check_once(
				"binding_parity:%s" % sample_id,
				live_digest == rebound_digest,
				"%s sealed live bindings differ from a fresh deterministic binding." % sample_id
			)


func _active_slots(surface: Dictionary, sample_id: String) -> Dictionary:
	var result: Dictionary = {}
	var families: Dictionary = {}
	for family_value in EnvironmentSlotBinderScript.SLOT_FAMILIES:
		var family := str(family_value)
		for slot_value in _array(surface.get("%s_slots" % family, [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty():
				_check_once("empty_slot:%s:%s" % [sample_id, family], false, "%s has an active %s slot without an ID." % [sample_id, family])
				continue
			if result.has(slot_id):
				_check_once(
					"duplicate_slot:%s:%s" % [sample_id, slot_id],
					false,
					"%s has duplicate active slot ID %s in %s and %s." % [sample_id, slot_id, str(families.get(slot_id, "")), family]
				)
				continue
			result[slot_id] = slot
			families[slot_id] = family
	_check_once("no_slots:%s" % sample_id, not result.is_empty(), "%s has no active authored slots." % sample_id)
	return result


func _audit_binding(sample_id: String, entries: Array, slots_by_id: Dictionary, binding: Dictionary) -> void:
	if not bool(binding.get("ok", false)):
		_check_once(
			"binding_error:%s" % sample_id,
			false,
			"%s failed to bind live room objects: %s" % [sample_id, JSON.stringify(binding.get("errors", []))]
		)
	var bindings := _dict(binding.get("slot_bindings", {}))
	var expected_room_objects := _expected_room_object_ids(entries)
	for object_id_value in expected_room_objects.keys():
		var object_id := str(object_id_value)
		if not bindings.has(object_id):
			_check_once(
				"missing_binding:%s:%s" % [sample_id, object_id],
				false,
				"%s live room object %s has no slot binding." % [sample_id, object_id]
			)
			continue
		var expected_binding := _dict(bindings.get(object_id, {}))
		_check_once(
			"missing_room_slot:%s:%s" % [sample_id, object_id],
			str(expected_binding.get("presentation_mode", "")) == EnvironmentSlotBinderScript.PRESENTATION_ROOM,
			"%s live room object %s was not assigned an authored room slot." % [sample_id, object_id]
		)

	var slot_claims: Dictionary = {}
	var occupied_geometry: Array = []
	var sample_room_objects := 0
	var binding_ids := bindings.keys()
	binding_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for object_id_value in binding_ids:
		var object_id := str(object_id_value)
		var room_binding := _dict(bindings.get(object_id_value, {}))
		if str(room_binding.get("presentation_mode", "")) != EnvironmentSlotBinderScript.PRESENTATION_ROOM:
			continue
		room_objects_checked += 1
		sample_room_objects += 1
		var slot_id := str(room_binding.get("slot_id", "")).strip_edges()
		if slot_id.is_empty() or not slots_by_id.has(slot_id):
			_check_once(
				"missing_slot:%s:%s" % [sample_id, object_id],
				false,
				"%s live room object %s references missing slot %s." % [sample_id, object_id, slot_id]
			)
			continue
		if slot_claims.has(slot_id):
			_check_once(
				"duplicate_claim:%s:%s" % [sample_id, slot_id],
				false,
				"%s binds room objects %s and %s to slot %s." % [sample_id, str(slot_claims.get(slot_id, "")), object_id, slot_id]
			)
			continue
		slot_claims[slot_id] = object_id
		var slot := _dict(slots_by_id.get(slot_id, {}))
		var rect_value: Variant = _slot_hit_rect(slot)
		if typeof(rect_value) != TYPE_RECT2:
			_check_once(
				"missing_hit_rect:%s:%s" % [sample_id, slot_id],
				false,
				"%s occupied slot %s has no valid positive hit rectangle." % [sample_id, slot_id]
			)
			continue
		var current_rect := rect_value as Rect2
		for prior_value in occupied_geometry:
			var prior := _dict(prior_value)
			var prior_rect: Rect2 = prior.get("rect", Rect2())
			if current_rect.intersects(prior_rect):
				var prior_slot_id := str(prior.get("slot_id", ""))
				var pair := [prior_slot_id, slot_id]
				pair.sort()
				_check_once(
					"intersection:%s:%s:%s" % [sample_id, str(pair[0]), str(pair[1])],
					false,
					"%s occupied hit rectangles intersect: %s (%s) and %s (%s)." % [
						sample_id,
						prior_slot_id,
						str(prior.get("object_id", "")),
						slot_id,
						object_id,
					]
				)
		occupied_geometry.append({"object_id": object_id, "slot_id": slot_id, "rect": current_rect})
	if sample_room_objects > max_room_objects:
		max_room_objects = sample_room_objects
		max_room_objects_sample = sample_id

	for occupied_slot_value in _array(binding.get("occupied_slot_ids", [])):
		var occupied_slot_id := str(occupied_slot_value).strip_edges()
		_check_once(
			"missing_occupied_slot:%s:%s" % [sample_id, occupied_slot_id],
			slots_by_id.has(occupied_slot_id),
			"%s binding result reports missing occupied slot %s." % [sample_id, occupied_slot_id]
		)


func _expected_room_object_ids(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry_value in entries:
		var entry := _dict(entry_value)
		var object_id := str(entry.get("object_id", "")).strip_edges()
		if object_id.is_empty():
			continue
		var binding_source_id := str(entry.get("slot_binding_source_id", "")).strip_edges()
		if not binding_source_id.is_empty() and binding_source_id != object_id:
			continue
		if EnvironmentSlotBinderScript.base_record_requires_room_slot(entry):
			result[object_id] = true
	return result


func _slot_hit_rect(slot: Dictionary) -> Variant:
	var values := _array(slot.get("hit_rect", []))
	if values.size() != 4:
		return null
	var x := float(values[0])
	var y := float(values[1])
	var width := float(values[2])
	var height := float(values[3])
	if not is_finite(x) or not is_finite(y) or not is_finite(width) or not is_finite(height) or width <= 0.0 or height <= 0.0:
		return null
	return Rect2(x, y, width, height)


func _check_once(key: String, condition: bool, message: String) -> void:
	if condition or failure_keys.has(key):
		return
	failure_keys[key] = true
	failures.append(message)


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _dict(parsed)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
