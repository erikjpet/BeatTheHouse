extends SceneTree

# Round 4 runtime binding sweep. Unlike the static slot checker, this installs
# real generated rooms through production travel, binds the authoritative base
# inventory, prepares scenario semantics, and finalizes every reachable phase.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioSequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const EnvironmentReadabilityContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")

const LAYOUT_CONTEXT := {"viewport_size": {"x": 1280, "y": 720}}
const DEFAULT_REPORT := "res://.tmp/owner_review/binding_sweep_round4.txt"
const GRAND_INTERIOR_ROOMS := ["grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage"]
const HOME_ROOMS := ["motel_room", "apartment", "house"]

var _report_path := DEFAULT_REPORT
var _room_filter := ""
var _scenario_filter := ""
var _rows: Array = []
var _failures: Array = []
var _runtime_case_count := 0
var _base_case_count := 0
var _phase_case_count := 0
var _travel_arrival_count := 0
var _parent_home_arrival_count := 0
var _home_start_arrival_count := 0
var _layer_return_arrival_count := 0


func _init() -> void:
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value)
		if argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--room="):
			_room_filter = argument.trim_prefix("--room=")
		elif argument.begins_with("--scenario="):
			_scenario_filter = argument.trim_prefix("--scenario=")
	call_deferred("_run")


func _run() -> void:
	var library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		_failures.append("content | %s" % str(error_value))
	if not _failures.is_empty():
		_finish()
		return

	var map_ids := _placement_map_ids()
	var definitions := _scenario_definitions(library)
	if map_ids.size() != 21:
		_failures.append("coverage | expected 21 placement maps, found %d" % map_ids.size())
	if definitions.size() != 55:
		_failures.append("coverage | expected 55 validated legal scenarios, found %d" % definitions.size())
	for map_id_value in map_ids:
		var map_id := str(map_id_value)
		if not _room_filter.is_empty() and map_id != _room_filter:
			continue
		print("ROUND4_BINDING_SWEEP base room=%s" % map_id)
		_sweep_base_map(library, map_id, "home_start" if HOME_ROOMS.has(map_id) else "travel")
		if map_id == "motel":
			_sweep_base_map(library, map_id, "parent_home")
		elif map_id == "small_underground_casino:club":
			_sweep_base_map(library, map_id, "layer_return")

	for definition_value in definitions:
		var definition := _dict(definition_value)
		if not _scenario_filter.is_empty() and str(definition.get("id", "")) != _scenario_filter:
			continue
		var definition_map := str(definition.get("archetype_id", ""))
		var definition_layer := str(definition.get("layer_id", "")).strip_edges()
		if not definition_layer.is_empty():
			definition_map = "%s:%s" % [definition_map, definition_layer]
		if not _room_filter.is_empty() and definition_map != _room_filter:
			continue
		print("ROUND4_BINDING_SWEEP scenario=%s room=%s" % [str(definition.get("id", "")), definition_map])
		_sweep_scenario(library, definition, "travel")
		if str(definition.get("archetype_id", "")) == "motel" and str(definition.get("layer_id", "")).strip_edges().is_empty():
			_sweep_scenario(library, definition, "parent_home")
		elif definition_map == "small_underground_casino:club":
			_sweep_scenario(library, definition, "layer_return")

	_finish()


func _sweep_base_map(library: Variant, map_id: String, arrival_kind: String) -> void:
	var archetype_id := map_id.get_slice(":", 0)
	var scenario_pool_id := "grand_casino" if GRAND_INTERIOR_ROOMS.has(archetype_id) else archetype_id
	var original_pool: Array = _array(library.environment_scenarios.get(scenario_pool_id, [])).duplicate(true)
	library.environment_scenarios[scenario_pool_id] = []
	var arrival := _arrive(library, map_id, {}, arrival_kind)
	library.environment_scenarios[scenario_pool_id] = original_pool
	_base_case_count += 1
	if not bool(arrival.get("ok", false)):
		_record_failure(map_id, "base", "base", arrival_kind, "arrival", _array(arrival.get("errors", [])))
		return
	var run_state = arrival.get("run_state")
	var result := _runtime_boundary(run_state, library, false)
	_record_result(map_id, "base", "base", arrival_kind, result)


func _sweep_scenario(library: Variant, definition: Dictionary, arrival_kind: String) -> void:
	var scenario_id := str(definition.get("id", ""))
	var archetype_id := str(definition.get("archetype_id", ""))
	var layer_id := str(definition.get("layer_id", "")).strip_edges()
	var map_id := "%s:%s" % [archetype_id, layer_id] if not layer_id.is_empty() else archetype_id
	var original_pool: Array = _array(library.environment_scenarios.get(archetype_id, [])).duplicate(true)
	library.environment_scenarios[archetype_id] = [definition.duplicate(true)]
	var arrival := _arrive(library, map_id, definition, arrival_kind)
	library.environment_scenarios[archetype_id] = original_pool
	if not bool(arrival.get("ok", false)):
		_record_failure(map_id, scenario_id, "arrival", arrival_kind, "arrival", _array(arrival.get("errors", [])))
		return
	var arrived_run = arrival.get("run_state")
	var arrived_environment := _dict(arrived_run.current_environment)
	var initial_state := _dict(arrived_environment.get("scenario_sequence_state", {}))
	if initial_state.is_empty():
		_record_failure(map_id, scenario_id, "arrival", arrival_kind, "trace", ["runtime arrival has no scenario_sequence_state"])
		return
	var trace := EnvironmentReadabilityContractScript.reachable_public_states(definition, initial_state, scenario_id)
	if not _array(trace.get("errors", [])).is_empty():
		_record_failure(map_id, scenario_id, "trace", arrival_kind, "trace", _array(trace.get("errors", [])))
	var phase_candidates: Dictionary = {}
	for state_value in _array(trace.get("states", [])):
		var state_record := _dict(state_value)
		var state := _dict(state_record.get("state", {}))
		var phase_id := str(state.get("phase_id", state_record.get("phase_id", ""))).strip_edges()
		if phase_id.is_empty():
			phase_id = "terminal:%s" % str(state.get("status", "unknown"))
		var candidate := {"record": state_record, "score": _state_physical_score(state, definition)}
		if not phase_candidates.has(phase_id) or int(candidate.get("score", 0)) > int(_dict(phase_candidates.get(phase_id, {})).get("score", 0)):
			phase_candidates[phase_id] = candidate
	var phase_ids: Array = phase_candidates.keys()
	phase_ids.sort()
	for phase_id_value in phase_ids:
		var phase_id := str(phase_id_value)
		var state_record := _dict(_dict(phase_candidates.get(phase_id, {})).get("record", {}))
		var state := _dict(state_record.get("state", {}))
		_phase_case_count += 1
		var phase_run = RunStateScript.new()
		phase_run.from_dict(arrived_run.to_dict())
		phase_run.current_environment = arrived_environment.duplicate(true)
		phase_run.cache_runtime_scenario_definition(definition.duplicate(true))
		phase_run.seed_scenario_for_node(phase_run.current_world_node_id(), definition.duplicate(true))
		phase_run.current_environment["scenario_sequence_state"] = state.duplicate(true)
		phase_run.current_environment[ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY] = ScenarioSequenceRuntimeScript.content_fingerprint(state)
		var result := _runtime_boundary(phase_run, library, true)
		_record_result(map_id, scenario_id, phase_id, arrival_kind, result, str(state_record.get("path", "")))


func _state_physical_score(state: Dictionary, definition: Dictionary) -> int:
	var projection := _dict(ScenarioSequenceRuntimeScript.public_projection(state, definition, true))
	var semantic := _dict(projection.get("semantic_state", {}))
	var score := 0
	for collection_key in ["scene_objects", "actors"]:
		for visual_value in _dict(semantic.get(collection_key, {})).values():
			if bool(_dict(visual_value).get("present", true)):
				score += 1
	return score


func _runtime_boundary(run_state: Variant, library: Variant, require_scenario: bool) -> Dictionary:
	_runtime_case_count += 1
	var errors: Array = []
	var environment := _dict(run_state.current_environment)
	var authoritative := EnvironmentBaseSemanticRecordsScript.authoritative_interactable_records(environment, library)
	if not bool(authoritative.get("ok", false)):
		errors.append_array(_prefixed("binder-authority", _array(authoritative.get("errors", []))))
	else:
		var layout := _dict(environment.get("layout", {}))
		var bound := EnvironmentSlotBinderScript.bind_base_records(environment, _array(authoritative.get("records", [])), _dict(layout.get("slot_bindings", {})))
		if not bool(bound.get("ok", false)):
			errors.append_array(_prefixed("binder", _array(bound.get("errors", []))))
		else:
			var physical_overflow := _physical_base_overflow(_array(bound.get("records", [])))
			if not physical_overflow.is_empty():
				errors.append("binder | physical base overflow: %s" % JSON.stringify(physical_overflow))

	var preparation := _dict(run_state.scenario_prepare_semantic_finalization())
	if not bool(preparation.get("ok", false)):
		errors.append_array(_prefixed("preparation", _array(preparation.get("errors", []))))
	elif require_scenario and bool(preparation.get("inactive", false)):
		errors.append("preparation | scenario definition was inactive during phase finalization")

	var finalized := _dict(run_state.scenario_finalize_installed_environment(library, LAYOUT_CONTEXT.duplicate(true)))
	if not bool(finalized.get("ok", false)):
		errors.append_array(_prefixed("finalization", _array(finalized.get("errors", []))))
	elif require_scenario and bool(finalized.get("inactive", false)):
		errors.append("finalization | scenario definition was inactive during phase finalization")
	elif not bool(finalized.get("inactive", false)):
		var audit := _dict(finalized.get("layout_audit", {}))
		if require_scenario and not bool(audit.get("valid", false)):
			errors.append("finalization | invalid layout audit: %s" % JSON.stringify(audit))
		var scenario_overflow := _physical_scenario_overflow(run_state.current_environment)
		if not scenario_overflow.is_empty():
			errors.append("finalization | physical scenario overflow: %s" % JSON.stringify(scenario_overflow))
	return {"ok": errors.is_empty(), "errors": errors}


func _arrive(library: Variant, map_id: String, definition: Dictionary, arrival_kind: String) -> Dictionary:
	var archetype_id := map_id.get_slice(":", 0)
	var layer_id := map_id.get_slice(":", 1) if map_id.contains(":") else ""
	var seed := "ROUND4-BIND-%s-%s-%s" % [arrival_kind, map_id.replace(":", "-"), str(definition.get("id", "base"))]
	var modifiers := {
		"home_archetype_id": map_id if arrival_kind == "home_start" else "motel_room" if arrival_kind == "parent_home" else "corner_store" if archetype_id != "corner_store" else "back_alley",
		"scenario_pins_apply_mutations": true,
	}
	if not definition.is_empty():
		modifiers["scenario_pins"] = {archetype_id: str(definition.get("id", ""))}
	var run_state = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.custom_challenge("round4_runtime_binding_sweep", seed, modifiers))
	var generator = RunGeneratorScript.new(library)
	var first = generator.next_environment(run_state)
	if first == null or run_state.current_environment.is_empty():
		return {"ok": false, "errors": ["initial production environment generation failed"]}
	if arrival_kind == "home_start":
		if str(run_state.current_environment.get("archetype_id", "")) != map_id:
			return {"ok": false, "errors": ["home start installed %s instead of %s" % [str(run_state.current_environment.get("archetype_id", "")), map_id]]}
		_home_start_arrival_count += 1
		return {"ok": true, "run_state": run_state, "generator": generator, "travel": {}, "errors": []}

	var target_archetype := "grand_casino" if GRAND_INTERIOR_ROOMS.has(archetype_id) else archetype_id
	var target_node := _node_for_archetype(run_state, target_archetype)
	if target_node.is_empty():
		return {"ok": false, "errors": ["no generated world node for archetype %s" % target_archetype]}
	var parent_home_source := str(run_state.current_environment.get("archetype_id", ""))
	if arrival_kind != "parent_home" and run_state.current_world_node_id() == target_node:
		var alternate := _alternate_node(run_state, target_node)
		if alternate.is_empty():
			return {"ok": false, "errors": ["no alternate source node for travel arrival into %s" % target_node]}
		var source_travel := generator.travel_environment_result(run_state, alternate, true)
		if not bool(source_travel.get("ok", false)):
			return {"ok": false, "errors": _prefixed("source-travel", _array(source_travel.get("errors", [])))}
	var travel := generator.travel_environment_result(run_state, target_node, true)
	if not bool(travel.get("ok", false)):
		return {"ok": false, "errors": _prefixed("travel", _array(travel.get("errors", [])))}

	if GRAND_INTERIOR_ROOMS.has(archetype_id):
		if archetype_id == "grand_casino_high_limit":
			run_state.narrative_flags["grand_casino_high_limit_access"] = true
			run_state.narrative_flags["grand_casino_high_limit_access_method"] = "round4_runtime_sweep"
		elif archetype_id == "grand_casino_back_room":
			run_state.narrative_flags["grand_casino_showdown_active"] = true
			run_state.narrative_flags["grand_casino_showdown_step"] = RunStateScript.GRAND_CASINO_SHOWDOWN_STEP_DUEL
		var room_arrival := generator.enter_grand_casino_room_result(run_state, archetype_id)
		if not bool(room_arrival.get("ok", false)):
			return {"ok": false, "errors": _prefixed("grand-room", _array(room_arrival.get("errors", [])))}
	elif arrival_kind == "layer_return":
		run_state.discover_environment_layer("casino", "round4_runtime_binding_sweep")
		var casino_arrival := generator.enter_environment_layer(run_state, "casino", false)
		if not bool(casino_arrival.get("ok", false)):
			return {"ok": false, "errors": ["layer-return-via-casino | %s" % str(casino_arrival.get("message", JSON.stringify(casino_arrival)))]}
		var club_arrival := generator.enter_environment_layer(run_state, "club", false)
		if not bool(club_arrival.get("ok", false)):
			return {"ok": false, "errors": ["layer-return-to-club | %s" % str(club_arrival.get("message", JSON.stringify(club_arrival)))]}
		_layer_return_arrival_count += 1
	elif not layer_id.is_empty():
		if layer_id == "back_room" and str(run_state.current_environment.get("current_layer_id", "")) != "casino":
			run_state.discover_environment_layer("casino", "round4_runtime_binding_sweep")
			var casino_arrival := generator.enter_environment_layer(run_state, "casino", false)
			if not bool(casino_arrival.get("ok", false)):
				return {"ok": false, "errors": ["layer-via-casino | %s" % str(casino_arrival.get("message", JSON.stringify(casino_arrival)))]}
		if str(run_state.current_environment.get("current_layer_id", "")) != layer_id:
			run_state.discover_environment_layer(layer_id, "round4_runtime_binding_sweep")
			var layer_arrival := generator.enter_environment_layer(run_state, layer_id, false)
			if not bool(layer_arrival.get("ok", false)):
				return {"ok": false, "errors": ["layer | %s" % str(layer_arrival.get("message", JSON.stringify(layer_arrival)))]}

	var actual_map := str(run_state.current_environment.get("archetype_id", ""))
	var actual_layer := str(run_state.current_environment.get("current_layer_id", "")).strip_edges()
	if not actual_layer.is_empty() and actual_layer != "main":
		actual_map = "%s:%s" % [actual_map, actual_layer]
	if actual_map != map_id and not (map_id == "small_underground_casino" and actual_map == "small_underground_casino:club"):
		return {"ok": false, "errors": ["arrival installed %s instead of %s" % [actual_map, map_id]]}
	if arrival_kind == "parent_home":
		if archetype_id != "motel" or parent_home_source != "motel_room":
			return {"ok": false, "errors": ["parent-home arrival was not motel_room -> motel: %s" % JSON.stringify(travel)]}
		_parent_home_arrival_count += 1
	else:
		_travel_arrival_count += 1
	return {"ok": true, "run_state": run_state, "generator": generator, "travel": travel, "errors": []}


func _physical_base_overflow(records: Array) -> Array:
	var result: Array = []
	for record_value in records:
		var record := _dict(record_value)
		if str(record.get("presentation_mode", "room")) == "overflow" and EnvironmentSlotBinderScript.base_record_requires_room_slot(record):
			result.append(str(record.get("object_id", "")))
	result.sort()
	return result


func _physical_scenario_overflow(environment: Dictionary) -> Array:
	var result: Array = []
	var projection := _dict(environment.get("scenario_sequence_projection", {}))
	var semantic := _dict(projection.get("semantic_state", {}))
	var interactions := _dict(semantic.get("interactions", {}))
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	for collection_key in ["scene_objects", "actors"]:
		var actor: bool = collection_key == "actors"
		for identity_value in _dict(semantic.get(collection_key, {})).keys():
			var identity := str(identity_value)
			var visual := _dict(_dict(semantic.get(collection_key, {})).get(identity_value, {}))
			if not bool(visual.get("present", true)) or str(visual.get("presentation_mode", "room")) != "overflow":
				continue
			var interaction := _dict(interactions.get(identity, {}))
			var entry := {
				"identity": identity,
				"semantic": visual,
				"actor": actor,
				"safe_exit": bool(interaction.get("safe_exit", false)),
				"placement_class": str(visual.get("placement_class", "")),
			}
			if EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(surface_map, entry):
				result.append(identity)
	result.sort()
	return result


func _record_result(map_id: String, scenario_id: String, phase_id: String, arrival_kind: String, result: Dictionary, path: String = "") -> void:
	if bool(result.get("ok", false)):
		_rows.append("PASS | room=%s | scenario=%s | phase=%s | arrival=%s%s" % [map_id, scenario_id, phase_id, arrival_kind, " | path=%s" % path if not path.is_empty() else ""])
		return
	_record_failure(map_id, scenario_id, phase_id, arrival_kind, "runtime", _array(result.get("errors", [])), path)


func _record_failure(map_id: String, scenario_id: String, phase_id: String, arrival_kind: String, stage: String, errors: Array, path: String = "") -> void:
	var exact_errors := errors if not errors.is_empty() else ["unknown failure"]
	for error_value in exact_errors:
		var row := "FAIL | room=%s | scenario=%s | phase=%s | arrival=%s | stage=%s%s | error=%s" % [map_id, scenario_id, phase_id, arrival_kind, stage, " | path=%s" % path if not path.is_empty() else "", str(error_value)]
		_rows.append(row)
		_failures.append(row)


func _finish() -> void:
	var lines: Array[String] = []
	lines.append("ROUND 4 RUNTIME BINDING SWEEP")
	lines.append("rooms=21 archetypes=18 scenarios=55 arrival_types=travel,parent_home,home_start,layer,layer_return,grand_interior")
	lines.append("runtime_cases=%d base_cases=%d phase_cases=%d travel_arrivals=%d parent_home_arrivals=%d home_start_arrivals=%d layer_return_arrivals=%d failures=%d" % [_runtime_case_count, _base_case_count, _phase_case_count, _travel_arrival_count, _parent_home_arrival_count, _home_start_arrival_count, _layer_return_arrival_count, _failures.size()])
	lines.append("physical_policy=games,people,shop_items,and_real_art_props_must_remain_in_room")
	lines.append("")
	for row_value in _rows:
		lines.append(str(row_value))
	lines.append("")
	lines.append("RESULT: %s" % ("PASS - zero failures" if _failures.is_empty() else "FAIL - %d failures" % _failures.size()))
	var absolute_path := ProjectSettings.globalize_path(_report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var output := FileAccess.open(absolute_path, FileAccess.WRITE)
	if output != null:
		output.store_string("\n".join(lines) + "\n")
	print("ROUND4_BINDING_SWEEP %s cases=%d failures=%d report=%s" % ["PASS" if _failures.is_empty() else "FAIL", _runtime_case_count, _failures.size(), absolute_path])
	for failure_value in _failures:
		printerr(str(failure_value))
	quit(0 if _failures.is_empty() else 1)


func _placement_map_ids() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/placement_surfaces.json"))
	var result: Array = []
	for map_value in _array(_dict(parsed).get("maps", [])):
		var map_id := str(_dict(map_value).get("id", "")).strip_edges()
		if not map_id.is_empty():
			result.append(map_id)
	result.sort()
	return result


func _scenario_definitions(library: Variant) -> Array:
	var result: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var overlaid := ScenarioSequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			var definition := _dict(library._runtime_validated_scenario_definition(overlaid))
			if not _dict(definition.get("sequence", {})).is_empty():
				result.append(definition.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


func _node_for_archetype(run_state: Variant, archetype_id: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _alternate_node(run_state: Variant, target_node: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node_id := str(_dict(node_value).get("id", ""))
		if not node_id.is_empty() and node_id != target_node:
			return node_id
	return ""


func _prefixed(stage: String, errors: Array) -> Array:
	var result: Array = []
	for error_value in errors:
		result.append("%s | %s" % [stage, str(error_value)])
	if result.is_empty():
		result.append("%s | unknown failure" % stage)
	return result


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
