extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SCENARIO_OBJECT_ID := "scenario::runtime_retention_fixture"
const RUNTIME_OBJECT_ID := "runtime:retention_fixture"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	var environment := _generated_jazz_environment(library)
	_check(not environment.is_empty(), "could not generate the Jazz Club fixture")
	if environment.is_empty():
		_finish()
		return

	environment["scenario_state"] = {
		"id": "runtime_retention_fixture",
		"phase_index": 0,
		"phase_action_counter": 0,
	}
	environment["scenario_render_snapshot"] = {
		"ok": true,
		"scenario_id": "runtime_retention_fixture",
		"phase_id": "arrival",
		"visual_objects": [{
			"object_id": SCENARIO_OBJECT_ID,
			"stable_object_id": "runtime_retention_fixture",
			"object_type": "scenario_object",
			"placement_class": "surface_item",
			"slot_id": "scenario.surface_item_1",
			"render_key": "paper_note",
			"present": true,
			"visible": true,
		}],
		"interaction_overlays": [],
	}
	environment["runtime_object_manifest_entries"] = [_runtime_entry("first")]
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)

	var initial_manifest := _dict(environment.get("object_manifest", {}))
	var retained_scenario_row := _active_row(initial_manifest, SCENARIO_OBJECT_ID).duplicate(true)
	var initial_runtime_row := _active_row(initial_manifest, RUNTIME_OBJECT_ID)
	var durable_source_digest := str(initial_manifest.get("source_digest", ""))
	_check(EnvironmentInstanceScript.object_manifest_errors(environment).is_empty(), "initial manifest is invalid")
	_check(not retained_scenario_row.is_empty(), "initial scenario row was not produced")
	_check(not initial_runtime_row.is_empty(), "initial runtime row was not produced")
	_check(_has_binding(environment, SCENARIO_OBJECT_ID), "initial scenario row has no slot binding")
	_check(_has_binding(environment, RUNTIME_OBJECT_ID), "initial runtime row has no slot binding")

	# Save-shaped environments omit the renderer snapshot. A runtime-only metadata
	# update must still preserve the exact trusted scenario row.
	environment.erase("scenario_render_snapshot")
	environment["runtime_object_manifest_entries"] = [_runtime_entry("second")]
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	var updated_manifest := _dict(environment.get("object_manifest", {}))
	_check(str(updated_manifest.get("source_digest", "")) == durable_source_digest, "runtime-only metadata changed the durable source digest")
	_check(_active_row(updated_manifest, SCENARIO_OBJECT_ID) == retained_scenario_row, "runtime-only metadata discarded or rewrote the retained scenario row")
	_check(str(_dict(_active_row(updated_manifest, RUNTIME_OBJECT_ID).get("metadata", {})).get("phase", "")) == "second", "runtime metadata did not refresh in the manifest row")

	# The active-room save copy keeps its live projection, while every nested
	# inactive layer is canonicalized without runtime-owned rows.
	var layered_environment := environment.duplicate(true)
	layered_environment["layer_states"] = {"fixture_layer": environment.duplicate(true)}
	var live_projection := RunStateScript._environment_for_persistent_storage(layered_environment, true, true)
	_check(_array(live_projection.get("runtime_object_manifest_entries", [])).size() == 1, "active-room persistence removed its runtime source")
	_check(not _active_row(_dict(live_projection.get("object_manifest", {})), RUNTIME_OBJECT_ID).is_empty(), "active-room persistence removed its runtime manifest row")
	_check(_has_binding(live_projection, RUNTIME_OBJECT_ID), "active-room persistence removed its runtime binding")
	var nested_projection := _dict(_dict(live_projection.get("layer_states", {})).get("fixture_layer", {}))
	_check(_array(nested_projection.get("runtime_object_manifest_entries", [])).is_empty(), "active-room persistence retained runtime sources in an inactive layer")
	_check(_active_row(_dict(nested_projection.get("object_manifest", {})), RUNTIME_OBJECT_ID).is_empty(), "active-room persistence retained a runtime row in an inactive layer")
	_check(_active_row(_dict(nested_projection.get("object_manifest", {})), SCENARIO_OBJECT_ID) == retained_scenario_row, "inactive-layer persistence discarded or rewrote the durable scenario row")
	_check(_has_binding(nested_projection, SCENARIO_OBJECT_ID), "inactive-layer persistence removed the durable scenario binding")
	_check(not _dict(_dict(nested_projection.get("layout", {})).get("slot_bindings", {})).has(RUNTIME_OBJECT_ID), "inactive-layer persistence retained a runtime binding")
	_check(not _dict(_dict(nested_projection.get("layout", {})).get("object_rects", {})).has(RUNTIME_OBJECT_ID), "inactive-layer persistence retained runtime geometry")

	# Offscreen persistence removes the whole runtime projection. Reconciliation
	# must remove its row and geometry while retaining scenario inventory exactly.
	var stripped_environment := RunStateScript._environment_for_persistent_storage(environment)
	var stripped_manifest := _dict(stripped_environment.get("object_manifest", {}))
	var stripped_layout := _dict(stripped_environment.get("layout", {}))
	_check(_array(stripped_environment.get("runtime_object_manifest_entries", [])).is_empty(), "offscreen persistence retained its runtime source")
	_check(EnvironmentInstanceScript.object_manifest_errors(stripped_environment).is_empty(), "runtime-stripped manifest is invalid")
	_check(str(stripped_manifest.get("source_digest", "")) == durable_source_digest, "removing runtime projection changed the durable source digest")
	_check(_active_row(stripped_manifest, SCENARIO_OBJECT_ID) == retained_scenario_row, "removing runtime projection discarded or rewrote the retained scenario row")
	_check(_active_row(stripped_manifest, RUNTIME_OBJECT_ID).is_empty(), "removed runtime projection retained an active manifest row")
	_check(_has_binding(stripped_environment, SCENARIO_OBJECT_ID), "retained scenario row lost its slot binding")
	_check(not _dict(stripped_layout.get("slot_bindings", {})).has(RUNTIME_OBJECT_ID), "removed runtime projection retained a slot binding")
	_check(not _dict(stripped_layout.get("object_rects", {})).has(RUNTIME_OBJECT_ID), "removed runtime projection retained room geometry")

	var stable_manifest := stripped_manifest.duplicate(true)
	stripped_environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(stripped_environment, library)
	_check(_dict(stripped_environment.get("object_manifest", {})) == stable_manifest, "unchanged reconciliation rewrote the runtime-stripped manifest")
	_finish()


func _generated_jazz_environment(library: ContentLibrary) -> Dictionary:
	var archetype := library.environment_archetype("jazz_club")
	if archetype.is_empty():
		return {}
	var rng := RngStreamScript.new()
	rng.configure(RngStreamScript.derive_seed(902_806, 902_806, "runtime-manifest-retention"))
	return EnvironmentInstanceScript.from_archetype(archetype, 2, rng, library).to_dict()


func _runtime_entry(phase: String) -> Dictionary:
	return {
		"object_id": RUNTIME_OBJECT_ID,
		"runtime_owner": "retention_fixture",
		"object_type": "dialogue",
		"visual_type": "character",
		"source_id": "retention_fixture",
		"slot_family": "scenario",
		"placement_class": "standing_person",
		"render_key": "patron",
		"label": "Runtime Fixture",
		"visual_prop": "patron",
		"spot_field": "runtime_object_manifest_entries",
		"index": 0,
		"required": true,
		"active": true,
		"physical": true,
		"action_ids": [],
		"metadata": {"phase": phase},
	}


func _active_row(manifest: Dictionary, object_id: String) -> Dictionary:
	for row_value in _array(manifest.get("rows", [])):
		var row := _dict(row_value)
		if bool(row.get("active", false)) and bool(row.get("physical", false)) \
				and str(row.get("presentation_object_id", row.get("object_id", ""))) == object_id:
			return row
	return {}


func _has_binding(environment: Dictionary, object_id: String) -> bool:
	return _dict(_dict(environment.get("layout", {})).get("slot_bindings", {})).has(object_id)


func _finish() -> void:
	if _failures.is_empty():
		print("ENVIRONMENT RUNTIME MANIFEST RETENTION CHECK ok=true")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
