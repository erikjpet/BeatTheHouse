extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		_check_archetype(archetype_value as Dictionary, library)
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_archetype(archetype: Dictionary, library: ContentLibrary) -> void:
	var archetype_id := str(archetype.get("id", "")).strip_edges()
	if archetype_id.is_empty():
		return
	var totals := {"variants": 0, "scenarios": 0, "phases": 0, "objects": 0, "slotted": 0}
	var layers := _dict(archetype.get("layers", {}))
	var layer_ids: Array = [""] if layers.is_empty() else layers.keys()
	layer_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var definitions := _scenario_definitions(library, archetype_id)
	for layer_id_value in layer_ids:
		var layer_id := str(layer_id_value)
		totals["variants"] = int(totals.get("variants", 0)) + 1
		_check_room_pass(archetype, layer_id, {}, library, "%s:%s:base" % [archetype_id, layer_id], totals)
		for definition_value in definitions:
			var definition := _dict(definition_value)
			var definition_layer := str(definition.get("layer_id", "")).strip_edges()
			if not layer_id.is_empty() and not definition_layer.is_empty() and definition_layer != layer_id:
				continue
			if layer_id.is_empty() and not definition_layer.is_empty():
				continue
			totals["scenarios"] = int(totals.get("scenarios", 0)) + 1
			_check_room_pass(archetype, layer_id, definition, library, "%s:%s:%s" % [archetype_id, layer_id, str(definition.get("id", ""))], totals)
	print("SLOT CHECK %s variants=%d scenarios=%d phases=%d objects=%d slotted=%d ok=%s" % [
		archetype_id,
		int(totals.get("variants", 0)),
		int(totals.get("scenarios", 0)),
		int(totals.get("phases", 0)),
		int(totals.get("objects", 0)),
		int(totals.get("slotted", 0)),
		str(not _has_failure_prefix(archetype_id)).to_lower(),
	])


func _check_room_pass(archetype: Dictionary, layer_id: String, definition: Dictionary, library: ContentLibrary, salt: String, totals: Dictionary) -> void:
	var run := RunStateScript.new()
	run.start_new("SLOT-CHECK-%s" % salt)
	var rng = run.create_rng("room_slot_occupancy")
	var instance = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library, {}, definition) \
			if layer_id.is_empty() else EnvironmentInstanceScript.from_archetype_layer(archetype, layer_id, 1, rng, library, {}, definition)
	var environment := instance.to_dict()
	var entries: Array = EnvironmentInstanceScript.active_object_manifest_rows(environment)
	var generation_occupancy: Dictionary = {}
	var generated := EnvironmentSlotBinderScript.bind_base_layout(environment, entries, generation_occupancy)
	if not bool(generated.get("ok", false)):
		_fail(salt, "base generation failed: %s" % JSON.stringify(generated.get("errors", [])))
		return
	_assert_manifest_bijection(salt, entries, _dict(generated.get("slot_bindings", {})))
	var layout := _dict(environment.get("layout", {}))
	layout["slot_schema_version"] = int(generated.get("slot_schema_version", 0))
	layout["slot_map_digest"] = str(generated.get("slot_map_digest", ""))
	layout["slot_binding_digest"] = str(generated.get("binding_digest", ""))
	layout["slot_bindings"] = _dict(generated.get("slot_bindings", {}))
	layout["slot_overflow_ids"] = _array(generated.get("overflow_ids", []))
	layout["object_rects"] = _dict(generated.get("object_rects", {}))
	environment["layout"] = layout
	var records := _base_records(entries)
	# Production removes geometry-free Room Actions by attaching their actions to
	# a visible person or fixture before the physical slot binder runs. Exercise
	# that same composition boundary on the real generated inventory; this sweep
	# must not invent an extra physical actor that production never creates.
	records = EnvironmentInteractionControllerScript._attach_action_only_records(records)
	var room_occupancy: Dictionary = {}
	var live := EnvironmentSlotBinderScript.bind_base_records(environment, records, _dict(layout.get("slot_bindings", {})), room_occupancy)
	if not bool(live.get("ok", false)):
		_fail(salt, "live base binding failed: %s" % JSON.stringify(live.get("errors", [])))
		return
	var live_bindings := _dict(live.get("slot_bindings", {}))
	_assert_every_object_bound(salt, records, live_bindings, totals)
	_assert_unique_slots(salt, live_bindings, {}, totals)
	if definition.is_empty() or not ScenarioSequenceSchemaScript.is_sequence(definition):
		return
	for phase_id_value in ScenarioSequenceSchemaScript.phase_ids(definition):
		var phase_id := str(phase_id_value)
		var semantic := ScenarioSequenceRuntimeScript.state_semantics_for_definition(definition, phase_id)
		var visual_entries := _scenario_visual_entries(semantic, environment)
		var phase_occupancy := room_occupancy.duplicate(true)
		var scenario := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, visual_entries, phase_occupancy)
		totals["phases"] = int(totals.get("phases", 0)) + 1
		if not bool(scenario.get("ok", false)):
			_fail("%s/%s" % [salt, phase_id], "scenario binding failed: %s" % JSON.stringify(scenario.get("errors", [])))
			continue
		var scenario_bindings := _dict(scenario.get("slot_bindings", {}))
		_assert_every_object_bound("%s/%s" % [salt, phase_id], visual_entries, scenario_bindings, totals, "identity")
		_assert_unique_slots("%s/%s" % [salt, phase_id], live_bindings, scenario_bindings, totals)


func _scenario_definitions(library: ContentLibrary, archetype_id: String) -> Array:
	var result: Array = []
	for scenario_value in _array(library.environment_scenarios.get(archetype_id, [])):
		var scenario_id := str(_dict(scenario_value).get("id", "")).strip_edges()
		if scenario_id.is_empty():
			continue
		var definition := library.scenario(scenario_id)
		if not definition.is_empty():
			result.append(definition)
	result.sort_custom(func(left: Variant, right: Variant) -> bool: return str(_dict(left).get("id", "")) < str(_dict(right).get("id", "")))
	return result


func _base_records(entries: Array) -> Array:
	var records: Array = []
	for entry_value in entries:
		var entry := _dict(entry_value)
		if str(entry.get("object_id", "")).strip_edges().is_empty():
			continue
		entry["visual_type"] = str(entry.get("object_type", ""))
		entry["label"] = str(entry.get("object_id", ""))
		entry["visible"] = true
		entry["interactive"] = true
		entry["layout_spot_field"] = str(entry.get("spot_field", ""))
		entry["layout_index"] = int(entry.get("index", 0))
		records.append(entry)
	return records


func _scenario_visual_entries(semantic: Dictionary, environment: Dictionary) -> Array:
	var result: Array = []
	var interactions := _dict(semantic.get("interactions", {}))
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	for collection_value in [[semantic.get("scene_objects", {}), false], [semantic.get("actors", {}), true]]:
		var collection := _dict((collection_value as Array)[0])
		var actor := bool((collection_value as Array)[1])
		for identity_value in collection.keys():
			var identity := str(identity_value)
			var object_semantic := _dict(collection.get(identity_value, {}))
			if not bool(object_semantic.get("present", true)):
				continue
			var safe_exit := bool(_dict(interactions.get(identity, {})).get("safe_exit", false))
			var entry := {
				"identity": identity,
				"semantic": object_semantic,
				"actor": actor,
				"safe_exit": safe_exit,
				"placement_class": "doorway" if safe_exit else "",
			}
			if not safe_exit and EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(surface_map, entry):
				var art_key := EnvironmentSlotBinderScript.scenario_visual_art_key(surface_map, entry)
				entry["placement_class"] = EnvironmentPlacementScript.classify(object_semantic, "actor" if actor else "scene_object", identity, art_key)
			result.append(entry)
	return result


func _assert_every_object_bound(label: String, objects: Array, bindings: Dictionary, totals: Dictionary, identity_key: String = "object_id") -> void:
	var seen: Dictionary = {}
	for object_value in objects:
		var object_record := _dict(object_value)
		var identity := str(object_record.get(identity_key, "")).strip_edges()
		if identity.is_empty() or seen.has(identity):
			continue
		if identity_key == "object_id" and not EnvironmentSlotBinderScript.base_record_requires_room_slot(object_record):
			continue
		if identity_key == "identity" and str(object_record.get("placement_class", "")).strip_edges().is_empty():
			continue
		seen[identity] = true
		var binding := _dict(bindings.get(identity, {}))
		var mode := str(binding.get("presentation_mode", ""))
		if binding.is_empty() or mode != "room":
			_fail(label, "%s is not bound to a room slot" % identity)
			continue
		if str(binding.get("slot_id", "")).strip_edges().is_empty():
			_fail(label, "%s has a room binding without a slot" % identity)
		totals["objects"] = int(totals.get("objects", 0)) + 1
		totals["slotted"] = int(totals.get("slotted", 0)) + 1


func _assert_manifest_bijection(label: String, rows: Array, bindings: Dictionary) -> void:
	var expected: Dictionary = {}
	for row_value in rows:
		var row := _dict(row_value)
		if not bool(row.get("active", false)) or not bool(row.get("physical", false)):
			continue
		var object_id := str(row.get("object_id", row.get("presentation_object_id", ""))).strip_edges()
		if object_id.is_empty():
			_fail(label, "manifest contains an active physical row without presentation identity")
			continue
		expected[object_id] = str(row.get("family", ""))
	for object_id_value in expected.keys():
		var object_id := str(object_id_value)
		var binding := _dict(bindings.get(object_id, {}))
		if binding.is_empty():
			_fail(label, "manifest physical object %s has no slot binding" % object_id)
		elif str(binding.get("slot_family", "")) != str(expected.get(object_id, "")):
			_fail(label, "manifest physical object %s crossed from %s to %s" % [object_id, str(expected.get(object_id, "")), str(binding.get("slot_family", ""))])
	for object_id_value in bindings.keys():
		if not expected.has(str(object_id_value)):
			_fail(label, "slot binding %s has no active physical manifest row" % str(object_id_value))


func _assert_unique_slots(label: String, base_bindings: Dictionary, scenario_bindings: Dictionary, _totals: Dictionary) -> void:
	var occupied: Dictionary = {}
	for collection_value in [base_bindings, scenario_bindings]:
		var collection := _dict(collection_value)
		var identities := collection.keys()
		identities.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for identity_value in identities:
			var identity := str(identity_value)
			var binding := _dict(collection.get(identity_value, {}))
			if str(binding.get("presentation_mode", "")) != "room":
				continue
			var claim_ids: Array = [str(binding.get("slot_id", ""))]
			var route_end := str(_dict(binding.get("route", {})).get("end_slot_id", "")).strip_edges()
			if not route_end.is_empty() and not claim_ids.has(route_end):
				claim_ids.append(route_end)
			for slot_id_value in claim_ids:
				var slot_id := str(slot_id_value).strip_edges()
				if slot_id.is_empty():
					continue
				var holder := str(occupied.get(slot_id, ""))
				if not holder.is_empty() and holder != identity:
					_fail(label, "slot %s is shared by %s and %s" % [slot_id, holder, identity])
				else:
					occupied[slot_id] = identity


func _has_failure_prefix(archetype_id: String) -> bool:
	for failure in _failures:
		if failure.begins_with("%s:" % archetype_id):
			return true
	return false


func _fail(label: String, message: String) -> void:
	_failures.append("%s: %s" % [label, message])


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
