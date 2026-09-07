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
	call_deferred("_run")


func _run() -> void:
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
	var completed := 0
	for seed_family_value in SEED_FAMILIES:
		var seed_family := str(seed_family_value)
		for definition_value in definitions:
			var definition := _dict(definition_value)
			var scenario_id := str(definition.get("id", ""))
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
			library.environment_scenarios[archetype_id] = original_pool
			if case_failures.is_empty():
				completed += 1
			else:
				failures.append_array(case_failures)
	# The established static contract freezes the full 1,108-object/673-action
	# census, preventing a collision repair from deleting scenario content.
	EnvironmentReadabilityContractScript.check_static(library, failures)
	_finish(failures, completed)


func _finish(failures: Array, completed: int) -> void:
	var expected := SEED_FAMILIES.size() * EXPECTED_SCENARIOS
	if failures.is_empty() and completed == expected:
		print("SCENARIO_ROOM_MULTISEED_FINALIZATION PASS families=%d scenarios=%d finalizations=%d normal_and_small=validated object_census=preserved" % [SEED_FAMILIES.size(), EXPECTED_SCENARIOS, completed])
		quit(0)
		return
	for failure in failures:
		printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL %s" % str(failure))
	printerr("SCENARIO_ROOM_MULTISEED_FINALIZATION FAIL completed=%d expected=%d failures=%d" % [completed, expected, failures.size()])
	quit(1)


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
	var activated := HarnessProductionFidelityScript.activate_exact_canvas_object(
		canvas,
		"travel:leave",
		Callable(self, "_activate_fixture_object"),
		failures,
		"Exact-object regression"
	)
	if not bool(activated.get("ok", false)) or _fixture_activated_id != "travel:leave":
		failures.append("Exact-object helper did not bypass render-first travel:motel_room for travel:leave.")
	var missing_failures: Array = []
	var missing := HarnessProductionFidelityScript.resolve_exact_canvas_object(canvas, "travel:missing", missing_failures, "Exact-object no-fallback regression")
	if bool(missing.get("ok", true)) or missing_failures.is_empty():
		failures.append("Exact-object helper silently fell back from a missing semantic id.")
	canvas.free()


func _activate_fixture_object(object_data: Dictionary, _local_hit_position: Vector2) -> bool:
	_fixture_activated_id = str(object_data.get("id", ""))
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
