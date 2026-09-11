extends SceneTree

# Permanent room-playability gate. Every scenario is pinned into its authored
# archetype and entered through production travel, then finalized with the same
# 1280x720 layout context used by the visible host. ScenarioLayoutResolver
# validates both normal and expanded small-screen hit/label geometry per run.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const EnvironmentReadabilityContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")

const SEED_FAMILIES := [
	"SEEDSWEEP-A",
	"SEEDSWEEP-B",
	"SEEDSWEEP-C",
	"SEEDSWEEP-D",
	"PM-VERIFY",
	"REFINE06-E",
	"REFINE06-F",
	"REFINE06-G",
]
const EXPECTED_SCENARIOS := 55
const EXPECTED_BARRIER_OBJECTS := 25
const EXPECTED_BARRIER_PLACEMENTS := 39
const LAYOUT_CONTEXT := {"viewport_size": {"x": 1280, "y": 720}}

var _fixture_activated_id := ""
var _fixture_input_events: Array = []
var _fixture_map_visible := false
var _fixture_serialized_state := {"bankroll": 50, "current_node_id": "motel"}
var _requested_scenario := ""
var _requested_seed_family := ""
var _reachable_state_checks := 0
var _reachable_layout_checks := 0


class ExactCanvasFixture:
	extends Control

	func _init() -> void:
		size = Vector2(900.0, 430.0)

	func current_view_snapshot() -> Dictionary:
		return {
			"board_rect": {"x": 0.0, "y": 0.0, "w": 900.0, "h": 430.0},
			"objects": [
				{"id": "travel:motel_room", "label": "Room Door", "object_type": "travel", "position": Vector2(0.25, 0.5), "size": Vector2(100.0, 60.0), "visible": true, "enabled": true, "interactive": true},
				{"id": "travel:leave", "label": "Leave", "object_type": "travel", "position": Vector2(0.75, 0.5), "size": Vector2(100.0, 60.0), "visible": true, "enabled": true, "interactive": true},
			],
		}

	func object_id_at_local_position(local_position: Vector2) -> String:
		if local_position.distance_to(Vector2(675.0, 215.0)) <= 55.0:
			return "travel:leave"
		if local_position.distance_to(Vector2(225.0, 215.0)) <= 55.0:
			return "travel:motel_room"
		return ""


func _init() -> void:
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value)
		if argument.begins_with("--scenario="):
			_requested_scenario = argument.trim_prefix("--scenario=")
		elif argument.begins_with("--seed-family="):
			_requested_seed_family = argument.trim_prefix("--seed-family=")
	call_deferred("_run")


func _run() -> void:
	if _requested_seed_family.is_empty() and _requested_scenario.is_empty():
		_run_parallel_seed_families()
		return
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		for error_value in library.validation_errors:
			failures.append("Content validation failed: %s" % str(error_value))
		_finish(failures, 0)
		return
	var definitions := _scenario_definitions(library)
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("Multi-seed finalization expected %d scenarios, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
		_finish(failures, 0)
		return
	_check_exact_object_helper(failures)
	_check_barrier_placements(library, definitions, failures)
	if not _requested_scenario.is_empty():
		definitions = definitions.filter(func(definition: Variant) -> bool: return str(_dict(definition).get("id", "")) == _requested_scenario)
		if definitions.is_empty():
			failures.append("Unknown requested scenario: %s." % _requested_scenario)
			_finish(failures, 0, definitions.size(), 1)
			return
	var completed := 0
	var seed_families := SEED_FAMILIES.duplicate()
	if not _requested_seed_family.is_empty():
		seed_families = [_requested_seed_family]
	for seed_family_value in seed_families:
		var seed_family := str(seed_family_value)
		for definition_value in definitions:
			var definition := _dict(definition_value)
			var scenario_id := str(definition.get("id", ""))
			print("SCENARIO_ROOM_MULTISEED_FINALIZATION CHECK %s/%s" % [seed_family, scenario_id])
			var archetype_id := str(definition.get("archetype_id", ""))
			var original_pool: Array = _array(library.environment_scenarios.get(archetype_id, [])).duplicate(true)
			library.environment_scenarios[archetype_id] = [definition.duplicate(true)]
			var case_failures: Array = []
			var run_state := RunStateScript.new()
			run_state.start_new("%s-%s" % [seed_family, scenario_id])
			var generator := RunGeneratorScript.new(library)
			var initial := HarnessProductionFidelityScript.generate_and_finalize(generator, run_state, case_failures, "%s/%s initial room" % [seed_family, scenario_id], "", false, LAYOUT_CONTEXT)
			var target_node := _node_for_archetype(run_state, archetype_id)
			var arrival: Dictionary = {}
			if bool(initial.get("ok", false)) and not target_node.is_empty():
				arrival = HarnessProductionFidelityScript.travel_and_finalize(generator, run_state, target_node, true, library, case_failures, "%s/%s scenario room" % [seed_family, scenario_id], LAYOUT_CONTEXT)
			elif target_node.is_empty():
				case_failures.append("%s/%s has no generated node for archetype %s." % [seed_family, scenario_id, archetype_id])
			if bool(arrival.get("ok", false)):
				var finalized := _dict(arrival.get("finalization", {}))
				var audit := _dict(finalized.get("layout_audit", {}))
				if str(run_state.current_environment.get("scenario_id", "")) != scenario_id:
					case_failures.append("%s/%s arrived with scenario %s." % [seed_family, scenario_id, str(run_state.current_environment.get("scenario_id", ""))])
				if not bool(run_state.current_environment.get("scenario_semantic_ready", false)):
					case_failures.append("%s/%s arrived without scenario_semantic_ready." % [seed_family, scenario_id])
				if bool(finalized.get("inactive", false)) or not bool(audit.get("valid", false)):
					case_failures.append("%s/%s did not produce an active valid normal/small-screen layout audit: %s" % [seed_family, scenario_id, JSON.stringify(audit)])
				_reachable_state_checks += _check_reachable_grounding_states(run_state, definition, seed_family, case_failures)
			var generated_layout := _dict(run_state.current_environment.get("layout", {}))
			if not _array(generated_layout.get("placement_errors", [])).is_empty():
				case_failures.append("%s/%s base placement errors: %s" % [seed_family, scenario_id, JSON.stringify(generated_layout.get("placement_errors", []))])
			if not _array(generated_layout.get("placement_fallback_ids", [])).is_empty():
				case_failures.append("%s/%s base placement used fallback slots: %s" % [seed_family, scenario_id, JSON.stringify(generated_layout.get("placement_fallback_ids", []))])
			library.environment_scenarios[archetype_id] = original_pool
			if case_failures.is_empty():
				completed += 1
			else:
				failures.append_array(case_failures)
	# The established static contract freezes the full 1,108-object/673-action
	# census, preventing a collision repair from deleting scenario content.
	EnvironmentReadabilityContractScript.check_static(library, failures)
	_finish(failures, completed, definitions.size(), seed_families.size())


func _run_parallel_seed_families() -> void:
	var workers: Array[Thread] = []
	var failures: Array = []
	for seed_family_value in SEED_FAMILIES:
		var worker := Thread.new()
		var start_error := worker.start(_run_seed_family_process.bind(str(seed_family_value)))
		if start_error != OK:
			failures.append("Could not start seed-family worker %s: %s." % [str(seed_family_value), error_string(start_error)])
			continue
		workers.append(worker)
	var reachable_states := 0
	var distinct_layouts := 0
	for worker in workers:
		var result := _dict(worker.wait_to_finish())
		var output := str(result.get("output", ""))
		if int(result.get("exit_code", 1)) != 0:
			failures.append("Seed-family worker %s failed:\n%s" % [str(result.get("seed_family", "unknown")), output])
			continue
		var summary := _parse_worker_summary(output)
		if summary.is_empty():
			failures.append("Seed-family worker %s returned no finalization summary:\n%s" % [str(result.get("seed_family", "unknown")), output])
			continue
		reachable_states += int(summary.get("reachable_states", 0))
		distinct_layouts += int(summary.get("distinct_layouts", 0))
		print(str(summary.get("line", "")))
	if not failures.is_empty() or workers.size() != SEED_FAMILIES.size():
		for failure in failures:
			printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL %s" % str(failure))
		printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL completed=0 expected=%d failures=%d" % [SEED_FAMILIES.size() * EXPECTED_SCENARIOS, failures.size()])
		quit(1)
		return
	print("SCENARIO_ROOM_MULTISEED_FINALIZATION PASS families=%d scenarios=%d finalizations=%d reachable_states=%d distinct_layouts=%d normal_and_small=validated routes=validated object_census=preserved" % [SEED_FAMILIES.size(), EXPECTED_SCENARIOS, SEED_FAMILIES.size() * EXPECTED_SCENARIOS, reachable_states, distinct_layouts])
	quit(0)


func _run_seed_family_process(seed_family: String) -> Dictionary:
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/scenario_room_multiseed_finalization.gd",
		"--", "--seed-family=%s" % seed_family,
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true, false)
	return {"seed_family": seed_family, "exit_code": exit_code, "output": "\n".join(output)}


func _parse_worker_summary(output: String) -> Dictionary:
	var pattern := RegEx.new()
	if pattern.compile("SCENARIO_ROOM_MULTISEED_FINALIZATION PASS families=1 scenarios=55 finalizations=55 reachable_states=([0-9]+) distinct_layouts=([0-9]+)") != OK:
		return {}
	var match_result := pattern.search(output)
	if match_result == null:
		return {}
	return {
		"reachable_states": int(match_result.get_string(1)),
		"distinct_layouts": int(match_result.get_string(2)),
		"line": match_result.get_string(0),
	}


func _finish(failures: Array, completed: int, scenario_count: int = EXPECTED_SCENARIOS, seed_count: int = SEED_FAMILIES.size()) -> void:
	var expected := seed_count * scenario_count
	if failures.is_empty() and completed == expected:
		print("SCENARIO_ROOM_MULTISEED_FINALIZATION PASS families=%d scenarios=%d finalizations=%d reachable_states=%d distinct_layouts=%d normal_and_small=validated routes=validated object_census=preserved" % [seed_count, scenario_count, completed, _reachable_state_checks, _reachable_layout_checks])
		quit(0)
		return
	for failure in failures:
		printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL %s" % str(failure))
	printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL completed=%d expected=%d failures=%d" % [completed, expected, failures.size()])
	quit(1)


func _check_reachable_grounding_states(run_state: Variant, fallback_definition: Dictionary, seed_family: String, failures: Array) -> int:
	var environment := _dict(run_state.current_environment).duplicate(false)
	var definition := _dict(environment.get("scenario_sequence_definition", fallback_definition))
	var initial_state := _dict(environment.get("scenario_sequence_state", {}))
	var scenario_id := str(definition.get("id", fallback_definition.get("id", "")))
	var trace := EnvironmentReadabilityContractScript.reachable_public_states(definition, initial_state, scenario_id)
	for error_value in _array(trace.get("errors", [])):
		failures.append("%s/%s reachable trace: %s" % [seed_family, scenario_id, str(error_value)])
	var checked := 0
	var base_records := _array(environment.get("scenario_layout_base_records", []))
	var resolved_signatures: Dictionary = {}
	for state_value in _array(trace.get("states", [])):
		var state_record := _dict(state_value)
		var state := _dict(state_record.get("state", {}))
		var path := str(state_record.get("path", "state"))
		var projection := ScenarioSequenceRuntimeScript.public_projection(state, definition)
		var signature := _grounding_projection_signature(projection)
		if resolved_signatures.has(signature):
			checked += 1
			continue
		var resolved := ScenarioLayoutResolverScript.resolve(base_records, projection, environment)
		if not bool(resolved.get("ok", false)):
			failures.append("%s/%s/%s grounding failed: %s" % [seed_family, scenario_id, path, JSON.stringify(resolved.get("errors", []))])
			continue
		resolved_signatures[signature] = true
		_reachable_layout_checks += 1
		var audit := _dict(resolved.get("layout_audit", {}))
		if not bool(audit.get("valid", false)):
			failures.append("%s/%s/%s layout audit is invalid." % [seed_family, scenario_id, path])
			continue
		var semantic := _dict(_dict(resolved.get("projection", {})).get("semantic_state", {}))
		for collection_key in ["scene_objects", "actors"]:
			for visual_value in _dict(semantic.get(collection_key, {})).values():
				var visual := _dict(visual_value)
				if not bool(visual.get("present", true)):
					continue
				var placement_class := str(visual.get("placement_class", ""))
				var identity := "%s::%s" % [str(visual.get("owner_namespace", "scenario")), str(visual.get("stable_object_id", ""))]
				var rect := _normalized_pixel_rect(visual.get("normalized_hit_rect", {}))
				if placement_class not in EnvironmentPlacementScript.CLASSES or not EnvironmentPlacementScript.valid_rect(environment, placement_class, rect):
					failures.append("%s/%s/%s %s has class-invalid grounded geometry (%s)." % [seed_family, scenario_id, path, identity, placement_class])
				_check_route_grounding(environment, visual, placement_class, rect.size, "%s/%s/%s %s" % [seed_family, scenario_id, path, identity], failures)
		checked += 1
	return checked


func _grounding_projection_signature(projection: Dictionary) -> String:
	var semantic := _dict(projection.get("semantic_state", {}))
	var geometry := {
		"status": str(projection.get("status", "")),
		"scene_objects": {},
		"actors": {},
		"interactions": _interaction_grounding_signature(_dict(semantic.get("interactions", {}))),
		"services": semantic.get("services", {}),
		"games": semantic.get("games", {}),
		"routes": semantic.get("routes", {}),
	}
	for collection_key in ["scene_objects", "actors"]:
		var records: Dictionary = {}
		for identity_value in _dict(semantic.get(collection_key, {})).keys():
			var identity := str(identity_value)
			var visual := _dict(_dict(semantic.get(collection_key, {})).get(identity_value, {}))
			var relevant: Dictionary = {}
			for key in ["present", "label", "anchor_id", "zone_id", "bounds", "role", "placement_class", "icon_key", "prop", "behavior", "route_id"]:
				if visual.has(key):
					relevant[key] = visual.get(key)
			records[identity] = relevant
		geometry[collection_key] = records
	return JSON.stringify(geometry).sha256_text()


func _interaction_grounding_signature(interactions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for identity_value in interactions.keys():
		var identity := str(identity_value)
		var interaction := _dict(interactions.get(identity_value, {}))
		var relevant: Dictionary = {}
		for key in ["present", "enabled", "label", "prompt", "disabled_reason", "safe_exit", "alternate_exit", "owner_namespace", "presentation_object_id"]:
			if interaction.has(key):
				relevant[key] = interaction.get(key)
		relevant["has_actions"] = not _array(interaction.get("available_actions", [])).is_empty()
		result[identity] = relevant
	return result


func _check_route_grounding(environment: Dictionary, visual: Dictionary, placement_class: String, size: Vector2, label: String, failures: Array) -> void:
	var route_stage := _dict(visual.get("route_stage", {}))
	if route_stage.is_empty():
		return
	for point_key in ["start", "endpoint", "reduced_motion_endpoint"]:
		var point_data := _dict(route_stage.get(point_key, {}))
		if point_data.is_empty():
			continue
		var center := Vector2(float(point_data.get("x", 0.0)) * 900.0, float(point_data.get("y", 0.0)) * 430.0)
		var route_rect := Rect2(center - size * 0.5, size)
		if not EnvironmentPlacementScript.valid_rect(environment, placement_class, route_rect):
			failures.append("%s route %s leaves its %s surface." % [label, point_key, placement_class])


func _normalized_pixel_rect(value: Variant) -> Rect2:
	var data := _dict(value)
	return Rect2(
		float(data.get("x", 0.0)) * 900.0,
		float(data.get("y", 0.0)) * 430.0,
		float(data.get("w", 0.0)) * 900.0,
		float(data.get("h", 0.0)) * 430.0
	)


func _scenario_definitions(library: Variant) -> Array:
	var result: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var definition := SequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty():
				result.append(definition.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


func _check_barrier_placements(library: Variant, definitions: Array, failures: Array) -> void:
	var object_count := 0
	var placement_count := 0
	var role_counts := {"obstacle": 0, "barrier": 0, "blockade": 0}
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var known: Dictionary = {}
		_collect_barrier_objects(_dict(definition.get("sequence", {})), known)
		object_count += known.size()
		for object_value in known.values():
			var role := str(_dict(object_value).get("role", "")).to_lower()
			role_counts[role] = int(role_counts.get(role, 0)) + 1
		var placements: Array = []
		_collect_barrier_placement_ops(_dict(definition.get("sequence", {})), known, placements)
		placement_count += placements.size()
		var environment := _dict(library.environment_archetype(str(definition.get("archetype_id", ""))))
		for placement_value in placements:
			var placement_op := _dict(placement_value)
			var stable_id := str(placement_op.get("stable_object_id", ""))
			var base_object := _dict(known.get(stable_id, {}))
			var payload := _dict(placement_op.get("object", {}))
			var anchor_id := str(placement_op.get("anchor_id", payload.get("anchor_id", base_object.get("anchor_id", ""))))
			var zone_id := str(placement_op.get("zone_id", payload.get("zone_id", base_object.get("zone_id", ""))))
			var center := ScenarioLayoutResolverScript._resolve_center(environment, anchor_id, zone_id)
			var bounds := _dict(base_object.get("bounds", {}))
			var size := Vector2(float(bounds.get("w", 48.0)), float(bounds.get("h", 48.0)))
			var authored := ScenarioLayoutResolverScript._clamp_inside_board(Rect2(center - size * 0.5, size))
			var resolved := ScenarioLayoutResolverScript._collision_safe_rect(
				"scenario::%s" % stable_id,
				authored,
				[],
				str(base_object.get("label", "")),
				ScenarioLayoutResolverScript.WALK_LANE
			)
			var rect: Rect2 = resolved.get("rect", authored)
			var small_rect := ScenarioLayoutResolverScript._expanded_rect(rect, ScenarioLayoutResolverScript.SMALL_SCREEN_TARGET)
			if bool(resolved.get("colliding", true)) or rect.intersects(ScenarioLayoutResolverScript.WALK_LANE) or small_rect.intersects(ScenarioLayoutResolverScript.WALK_LANE):
				failures.append("Barrier placement %s/%s op=%s anchor=%s zone=%s intersects WALK_LANE in normal or expanded small-screen geometry." % [str(definition.get("id", "")), stable_id, str(placement_op.get("op", "")), anchor_id, zone_id])
	if object_count != EXPECTED_BARRIER_OBJECTS or placement_count != EXPECTED_BARRIER_PLACEMENTS or role_counts != {"obstacle": 7, "barrier": 18, "blockade": 0}:
		failures.append("Barrier sweep census changed: objects=%d placements=%d roles=%s." % [object_count, placement_count, JSON.stringify(role_counts)])


func _check_exact_object_helper(failures: Array) -> void:
	var canvas := ExactCanvasFixture.new()
	_fixture_activated_id = ""
	_fixture_input_events = [{"object_id": "travel:motel_room", "label": "Room Door"}]
	_fixture_map_visible = false
	_fixture_serialized_state = {"bankroll": 50, "current_node_id": "motel"}
	var serialized_before_leave := JSON.stringify(_fixture_serialized_state)
	var activated := HarnessProductionFidelityScript.activate_exact_canvas_object(
		canvas,
		"travel:leave",
		Callable(self, "_activate_fixture_object"),
		failures,
		"Exact-object regression"
	)
	if not bool(activated.get("ok", false)) or _fixture_activated_id != "travel:leave":
		failures.append("Exact-object helper did not bypass render-first travel:motel_room for travel:leave.")
	var second_input: Dictionary = _dict(_fixture_input_events[1]) if _fixture_input_events.size() > 1 else {}
	if str(second_input.get("object_id", "")) != "travel:leave" or not _fixture_map_visible:
		failures.append("Parent-venue regression did not record travel:leave as its second input and open the map: %s." % JSON.stringify({"inputs": _fixture_input_events, "map_visible": _fixture_map_visible}))
	if JSON.stringify(_fixture_serialized_state) != serialized_before_leave:
		failures.append("Parent-venue travel:leave activation mutated serialized run state before route confirmation.")
	var missing_failures: Array = []
	var missing := HarnessProductionFidelityScript.resolve_exact_canvas_object(canvas, "travel:missing", missing_failures, "Exact-object no-fallback regression")
	if bool(missing.get("ok", true)) or missing_failures.is_empty():
		failures.append("Exact-object helper silently fell back from a missing semantic id.")
	canvas.free()


func _activate_fixture_object(object_data: Dictionary, _local_hit_position: Vector2) -> bool:
	_fixture_activated_id = str(object_data.get("id", ""))
	_fixture_input_events.append({"object_id": _fixture_activated_id, "label": str(object_data.get("label", ""))})
	_fixture_map_visible = _fixture_activated_id == "travel:leave"
	return true


func _collect_barrier_objects(value: Variant, known: Dictionary) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			_collect_barrier_objects(child, known)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var data := value as Dictionary
	if str(data.get("family", "")) == "scene_ops" and str(data.get("op", "")) == "spawn":
		var object_data := _dict(data.get("object", {}))
		if str(object_data.get("role", "")).to_lower() in ["obstacle", "barrier", "blockade"]:
			known[str(data.get("stable_object_id", ""))] = object_data.duplicate(true)
	for child in data.values():
		_collect_barrier_objects(child, known)


func _collect_barrier_placement_ops(value: Variant, known: Dictionary, placements: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			_collect_barrier_placement_ops(child, known, placements)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var data := value as Dictionary
	if str(data.get("family", "")) == "scene_ops" and str(data.get("op", "")) in ["spawn", "move", "set_position"] and known.has(str(data.get("stable_object_id", ""))):
		placements.append(data.duplicate(true))
	for child in data.values():
		_collect_barrier_placement_ops(child, known, placements)


func _node_for_archetype(run_state: Variant, archetype_id: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
