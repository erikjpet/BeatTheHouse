class_name ScenarioSemanticPresentationContract
extends RefCounted

const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")

const BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
const SMALL_SCREEN_TARGET := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)


static func check(library: Variant, failures: Array) -> void:
	_check_ordinary_interaction_coexistence(failures)
	_check_public_removal_tombstones(failures)
	_check_finalized_canvas_authority(library, failures)
	_check_atomic_finalization_layout(library, failures)
	_check_finalized_accessibility(library, failures)
	_check_finalized_actor_route(library, failures)
	_check_committed_projection_mismatch(library, failures)
	_check_atomic_projection_failures(failures)


static func _check_finalized_canvas_authority(library: Variant, failures: Array) -> void:
	var definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var command_visual := _command_visual(definition)
	var command_object := _dict(command_visual.get("object", {}))
	command_object["bounds"] = {"w": 32, "h": 24}
	command_visual["object"] = command_object
	_reseal_definition(definition)
	var run_state := RunStateScript.new()
	run_state.current_environment = _finalization_environment(definition)
	var presentation := _production_presentation()
	# Deliberately stale producer data: focus_rect is the producer geometry used
	# by semantic stamping, while normalized_rect used to outrank it on canvas.
	presentation["normalized_rect"] = {"x": 0.72, "y": 0.66, "w": 0.08, "h": 0.09}
	run_state.scenario_prepare_semantic_finalization()
	var finalized := run_state.scenario_finalize_base_semantics([presentation], library, _production_layout_context())
	if not bool(finalized.get("ok", false)):
		failures.append("Validated RunState finalization rejected the sealed-canvas fixture: %s" % JSON.stringify(finalized.get("errors", [])))
		return
	var projected := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), finalized)
	var records := _array(projected.get("records", []))
	var slot := _record(records, "game:slot")
	var command := _record(records, "scenario::command_console")
	var slot_normalized := _dict(slot.get("normalized_rect", {}))
	if not bool(projected.get("ok", false)) or not bool(run_state.current_environment.get("scenario_semantic_ready", false)) or str(run_state.current_environment.get("scenario_layout_authority_digest", "")) != str(projected.get("layout_authority_digest", "")):
		failures.append("RunState finalization did not atomically publish the exact projection/layout authority consumed by presentation.")
	if not is_equal_approx(float(slot_normalized.get("x", -1.0)), 0.1) or not is_equal_approx(float(slot_normalized.get("y", -1.0)), 0.1):
		failures.append("Sealed authority did not replace a stale normalized_rect on an otherwise untouched base control.")
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({
		"id": "finalized_canvas_authority",
		"archetype_id": "bar",
		"interactable_objects": records,
		"scenario_layout_audit": finalized.get("layout_audit", {}),
		"scenario_layout_authority_digest": finalized.get("layout_authority_digest", ""),
	})
	var view := _dict(canvas.current_view_snapshot())
	var slot_rect := _snapshot_rect(_layout_entry(_dict(view.get("object_layout", {})), "game:slot").get("rect", {}))
	var command_rect := _snapshot_rect(_layout_entry(_dict(view.get("object_layout", {})), "scenario::command_console").get("rect", {}))
	if not slot_rect.position.is_equal_approx(Vector2(90.0, 43.0)) or not slot_rect.size.is_equal_approx(Vector2(108.0, 77.4)) or canvas.object_id_at_local_position(slot_rect.get_center()) != "game:slot":
		failures.append("Public canvas draw/hit routing diverged from sealed base geometry after stale normalized_rect replacement.")
	if command.is_empty() or not command_rect.size.is_equal_approx(Vector2(32.0, 24.0)) or canvas.object_id_at_local_position(command_rect.get_center()) != "scenario::command_console":
		failures.append("Public canvas reintroduced the legacy 72x48 minimum after validating a sub-minimum scenario authority.")
	canvas.set_small_screen_mode(true)
	var small_view := _dict(canvas.current_view_snapshot())
	var small_command_rect := _snapshot_rect(_layout_entry(_dict(small_view.get("object_layout", {})), "scenario::command_console").get("rect", {}))
	if not small_command_rect.size.is_equal_approx(SMALL_SCREEN_TARGET) or canvas.object_id_at_local_position(small_command_rect.get_center()) != "scenario::command_console":
		failures.append("Public small-screen draw/hit routing did not use the exact expanded sealed authority.")
	var evidence := _dict(small_view.get("scenario_layout_evidence", {}))
	if int(evidence.get("authority_digest_count", 0)) != 1 or int(evidence.get("authority_count", 0)) != records.size():
		failures.append("Public canvas snapshot did not preserve one correlated authority digest across the finalized record set.")
	canvas.free()
	var forged_finalized := finalized.duplicate(true)
	forged_finalized["layout_authority"]["game::game:slot"]["normalized_hit_rect"]["x"] = 0.77
	var forged_projection := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), forged_finalized)
	if bool(forged_projection.get("ok", true)) or not _contains_text(_array(forged_projection.get("errors", [])), "digest correlation"):
		failures.append("Public finalized projection accepted geometry that diverged from its committed authority digest.")


static func _check_atomic_finalization_layout(library: Variant, failures: Array) -> void:
	var invalid_definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var command_visual := _command_visual(invalid_definition)
	var command_object := _dict(command_visual.get("object", {}))
	command_object["anchor_id"] = "missing_finalization_anchor"
	command_visual["object"] = command_object
	_reseal_definition(invalid_definition)
	var invalid_run := RunStateScript.new()
	invalid_run.current_environment = _finalization_environment(invalid_definition)
	invalid_run.scenario_prepare_semantic_finalization()
	var before := JSON.stringify(invalid_run.current_environment)
	var rejected := invalid_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	if bool(rejected.get("ok", true)) or JSON.stringify(invalid_run.current_environment) != before or invalid_run.current_environment.has("scenario_semantic_ready") or invalid_run.current_environment.has("scenario_sequence_state") or invalid_run.current_environment.has("scenario_layout_authority_digest"):
		failures.append("Layout rejection partially committed readiness, reentry state, projection, or authority instead of rolling back the detached finalization candidate.")

	var valid_run := RunStateScript.new()
	valid_run.current_environment = _finalization_environment(ScenarioSequenceContractScript.finalization_fixture_definition())
	valid_run.scenario_prepare_semantic_finalization()
	var finalized := valid_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	var causal_before := JSON.stringify(valid_run.current_environment.get("scenario_sequence_state", {}))
	var invalidated := valid_run.scenario_reject_layout_projection(["fixture projection mismatch"], {"valid": false})
	if not bool(finalized.get("ok", false)) or bool(invalidated.get("ok", true)) or valid_run.current_environment.has("scenario_semantic_ready") or not _dict(valid_run.current_environment.get("scenario_sequence_projection", {})).is_empty() or str(valid_run.current_environment.get("scenario_layout_authority_digest", "x")) != "" or JSON.stringify(valid_run.current_environment.get("scenario_sequence_state", {})) != causal_before:
		failures.append("Post-finalization projection rejection did not invalidate ephemeral authority while preserving the durable causal journal.")


static func _check_finalized_actor_route(library: Variant, failures: Array) -> void:
	var definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	var actor_ops: Array = phase.get("actor_ops", [])
	actor_ops.append({
		"family": "actor_ops",
		"op": "spawn",
		"receipt_id": "actor_spawn_route_guard",
		"owner_namespace": "scenario",
		"stable_object_id": "route_guard",
		"actor": {"label": "Route guard", "actor_id": "route_guard", "anchor_id": "bar_actor", "behavior": "patrol", "route_id": "base::world:bar", "pose": "brace"},
	})
	phase["actor_ops"] = actor_ops
	_append_interaction(definition, {
		"owner_namespace": "scenario",
		"stable_object_id": "route_guard",
		"presentation_object_id": "scenario::route_guard",
		"label": "Route guard",
		"state_label": "Available",
		"prompt": "Inspect the routed guard.",
		"enabled": true,
		"disabled_reason": "",
		"available_actions": [{"id": "inspect_guard", "label": "Inspect", "input_action": "confirm", "non_color_state": "ready"}],
		"input_actions": ["confirm"],
		"non_color_state": "available",
		"focus_order": 6,
		"hit_bounds": {"w": 72, "h": 80},
		"normalized_hit_rect": {"x": 0.3, "y": 0.2, "w": 0.08, "h": 0.18},
		"min_target_size": 44,
		"safe_exit": false,
		"alternate_exit": false,
	})
	var cleanup: Dictionary = definition["sequence"]["cleanup"]
	var cleanup_ops: Array = cleanup.get("operations", [])
	cleanup_ops.append({"family": "actor_ops", "op": "despawn", "receipt_id": "cleanup_actor_route_guard", "owner_namespace": "scenario", "stable_object_id": "route_guard"})
	cleanup["operations"] = cleanup_ops
	_reseal_definition(definition)
	var run_state := RunStateScript.new()
	run_state.current_environment = _finalization_environment(definition)
	run_state.current_environment["semantic_anchors"]["bar"] = {"position": [860.0, 390.0]}
	run_state.scenario_prepare_semantic_finalization()
	var trusted_base := [_production_presentation()]
	var finalized := run_state.scenario_finalize_base_semantics(trusted_base, library, _production_layout_context())
	var projected_candidate := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), finalized)
	var projected := EnvironmentInteractionControllerScript.committed_projection_status_result(run_state, projected_candidate, trusted_base)
	var actor := _record(_array(projected.get("records", [])), "scenario::route_guard")
	var authority_record := _dict(_dict(finalized.get("layout_authority", {})).get("scenario::route_guard", {}))
	var route_points := _array(actor.get("actor_route_points", []))
	var route_stage := _dict(actor.get("actor_route_stage", {}))
	if not bool(finalized.get("ok", false)) or not bool(projected.get("ok", false)) or route_points.size() != 2 or route_stage.is_empty():
		failures.append("Validated finalization did not preserve authored actor route staging in the public projection: %s" % JSON.stringify(finalized.get("errors", [])))
		return
	var normal_start := _canvas_point(route_points[0])
	var normal_endpoint := _canvas_point(route_points[1])
	var small_start := _canvas_point(route_stage.get("small_screen_start", {}))
	var small_endpoint := _canvas_point(route_stage.get("small_screen_endpoint", {}))
	var reduced_endpoint := _canvas_point(route_stage.get("reduced_motion_endpoint", {}))
	var duration := float(route_stage.get("duration_sec", 0.0))
	var expected_duration := clampf(normal_start.distance_to(normal_endpoint) / 82.0, 0.75, 8.0)
	if str(authority_record.get("presentation_object_id", "")) != "scenario::route_guard" \
		or not bool(authority_record.get("presentation_required", false)) \
		or not bool(authority_record.get("presentation_visible", false)) \
		or not bool(authority_record.get("presentation_interactive", false)) \
		or str(route_stage.get("mode", "")) != "ping_pong" \
		or not is_equal_approx(duration, expected_duration) \
		or not normal_endpoint.is_equal_approx(Vector2(860.0, 390.0)) \
		or not reduced_endpoint.is_equal_approx(normal_endpoint) \
		or not small_endpoint.is_equal_approx(Vector2(848.0, 390.0)) \
		or normal_endpoint.is_equal_approx(small_endpoint) \
		or normal_start.is_equal_approx(normal_endpoint) \
		or small_start.is_equal_approx(small_endpoint):
		failures.append("Finalized route authority did not seal distinct normal/small endpoints, explicit duration, reduced endpoint, and ping-pong order.")
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({"id": "finalized_route", "archetype_id": "bar", "reduce_motion": false, "interactable_objects": projected.get("records", [])})
	var start_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not start_rect.get_center().is_equal_approx(normal_start) or not start_rect.size.is_equal_approx(Vector2(72.0, 80.0)) or canvas.object_id_at_local_position(start_rect.get_center()) != "scenario::route_guard":
		failures.append("Public non-reduced canvas did not draw/hit the routed actor at its sealed normal start and size.")
	canvas.actor_route_time = duration * 0.5
	var midpoint_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not midpoint_rect.get_center().is_equal_approx(normal_start.lerp(normal_endpoint, 0.5)) or not midpoint_rect.size.is_equal_approx(Vector2(72.0, 80.0)) or canvas.object_id_at_local_position(midpoint_rect.get_center()) != "scenario::route_guard":
		failures.append("Public non-reduced canvas did not draw/hit the routed actor at the explicit-duration midpoint.")
	canvas.actor_route_time = duration
	var endpoint_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not endpoint_rect.get_center().is_equal_approx(normal_endpoint) or not endpoint_rect.size.is_equal_approx(Vector2(72.0, 80.0)) or canvas.object_id_at_local_position(endpoint_rect.get_center()) != "scenario::route_guard":
		failures.append("Public non-reduced canvas did not draw/hit the routed actor at the explicit-duration endpoint.")
	canvas.actor_route_time = duration * 2.0
	var returned_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not returned_rect.get_center().is_equal_approx(normal_start) or canvas.object_id_at_local_position(returned_rect.get_center()) != "scenario::route_guard":
		failures.append("Public canvas did not honor sealed ping-pong ordering after one full route cycle.")
	canvas.actor_route_time = duration
	canvas.set_small_screen_mode(true)
	var small_actor_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not small_actor_rect.get_center().is_equal_approx(small_endpoint) or not small_actor_rect.size.is_equal_approx(Vector2(SMALL_SCREEN_TARGET.x, 80.0)) or canvas.object_id_at_local_position(small_actor_rect.get_center()) != "scenario::route_guard" or not _rect_inside_canvas(small_actor_rect):
		failures.append("Public small-screen canvas did not use the sealed expanded size and board-clamped endpoint.")
	canvas.set_small_screen_mode(false)
	canvas.render_environment_snapshot({"id": "finalized_reduced_route", "archetype_id": "bar", "reduce_motion": true, "interactable_objects": projected.get("records", [])})
	var reduced_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not reduced_rect.get_center().is_equal_approx(reduced_endpoint) or not reduced_rect.size.is_equal_approx(Vector2(72.0, 80.0)) or canvas.object_id_at_local_position(reduced_rect.get_center()) != "scenario::route_guard":
		failures.append("Public reduced-motion canvas did not draw/hit the sealed normal reduced endpoint.")
	canvas.set_small_screen_mode(true)
	var reduced_small_rect := _canvas_object_rect(canvas, "scenario::route_guard")
	if not reduced_small_rect.get_center().is_equal_approx(small_endpoint) or not reduced_small_rect.size.is_equal_approx(Vector2(SMALL_SCREEN_TARGET.x, 80.0)) or canvas.object_id_at_local_position(reduced_small_rect.get_center()) != "scenario::route_guard" or not _rect_inside_canvas(reduced_small_rect):
		failures.append("Public reduced-motion small-screen canvas diverged from the sealed clamped endpoint or expanded size.")
	canvas.free()

	var forged_authority_finalized := finalized.duplicate(true)
	forged_authority_finalized["layout_authority"]["scenario::route_guard"]["presentation_object_id"] = "game:slot"
	var forged_authority_projection := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), forged_authority_finalized)
	if bool(forged_authority_projection.get("ok", true)):
		failures.append("Finalized presentation-object identity mutation did not break the closed authority digest before projection.")

	for semantic_mutation_value in ["normalized_hit_rect", "small_screen_rect", "z_order", "route_point_start", "route_point_endpoint", "stage_start", "stage_endpoint", "stage_reduced_endpoint", "stage_small_start", "stage_small_endpoint", "stage_duration", "stage_mode"]:
		var semantic_mutation := str(semantic_mutation_value)
		var forged_finalized := finalized.duplicate(true)
		var forged_actor: Dictionary = forged_finalized["projection"]["semantic_state"]["actors"]["scenario::route_guard"]
		_mutate_route_actor(forged_actor, semantic_mutation)
		var forged_projection := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), forged_finalized)
		if bool(forged_projection.get("ok", true)):
			failures.append("Finalized semantic actor mutation %s did not reject against sealed route authority." % semantic_mutation)

	var committed_environment := run_state.current_environment.duplicate(true)
	var forged_canvas = PixelSceneCanvasScript.new()
	forged_canvas.size = BOARD_SIZE
	for projected_mutation_value in ["delete_route_guard", "delete_game_slot", "delete_command_console", "extra_record", "object_id_collision", "scenario_layout_resolved", "owner_namespace", "stable_object_id", "visible", "interactive", "semantic_actor_deletion", "semantic_interaction_deletion", "semantic_owner_namespace", "semantic_stable_object_id", "semantic_presence_conflict", "semantic_tombstone", "semantic_visibility", "normalized_rect", "small_screen_rect", "scenario_z_order", "route_point_start", "route_point_endpoint", "stage_start", "stage_endpoint", "stage_reduced_endpoint", "stage_small_start", "stage_small_endpoint", "stage_duration", "stage_mode", "authority_identity", "authority_digest", "duplicate_record"]:
		var projected_mutation := str(projected_mutation_value)
		run_state.current_environment = committed_environment.duplicate(true)
		var forged_record_projection := projected.duplicate(true)
		var forged_projected_records: Array = forged_record_projection["records"]
		var forged_projected_actor := _mutable_record(forged_record_projection.get("records", []), "scenario::route_guard")
		match projected_mutation:
			"delete_route_guard":
				_remove_projected_record(forged_projected_records, "scenario::route_guard")
			"delete_game_slot":
				_remove_projected_record(forged_projected_records, "game:slot")
			"delete_command_console":
				_remove_projected_record(forged_projected_records, "scenario::command_console")
			"extra_record":
				var extra_record := forged_projected_actor.duplicate(true)
				extra_record["object_id"] = "scenario::extra_guard"
				extra_record["owner_namespace"] = "scenario"
				extra_record["stable_object_id"] = "extra_guard"
				extra_record["scenario_layout_authority_identity"] = "scenario::extra_guard"
				forged_projected_records.append(extra_record)
			"duplicate_record":
				forged_projected_records.append(forged_projected_actor.duplicate(true))
			"semantic_actor_deletion":
				forged_record_projection["projection"]["semantic_state"]["actors"].erase("scenario::route_guard")
			"semantic_interaction_deletion":
				forged_record_projection["projection"]["semantic_state"]["interactions"].erase("scenario::route_guard")
			"semantic_owner_namespace":
				forged_record_projection["projection"]["semantic_state"]["actors"]["scenario::route_guard"]["owner_namespace"] = "base"
			"semantic_stable_object_id":
				forged_record_projection["projection"]["semantic_state"]["actors"]["scenario::route_guard"]["stable_object_id"] = "forged_route_guard"
			"semantic_presence_conflict":
				forged_record_projection["projection"]["semantic_state"]["actors"]["scenario::route_guard"]["present"] = false
			"semantic_tombstone":
				forged_record_projection["projection"]["semantic_state"]["actors"]["scenario::route_guard"]["present"] = false
				forged_record_projection["projection"]["semantic_state"]["interactions"]["scenario::route_guard"]["present"] = false
			"semantic_visibility":
				forged_record_projection["projection"]["semantic_state"]["actors"]["scenario::route_guard"]["visible"] = false
			_:
				_mutate_projected_route_actor(forged_projected_actor, projected_mutation)
		var committed_forgery := EnvironmentInteractionControllerScript.committed_projection_status_result(run_state, forged_record_projection, trusted_base)
		var forged_records := _array(committed_forgery.get("records", []))
		if bool(committed_forgery.get("ok", true)) or not _record(forged_records, "scenario::route_guard").is_empty() or not _record(forged_records, "scenario::command_console").is_empty() or _record(forged_records, "game:slot").is_empty() or _record(forged_records, "scenario::presentation_failure").is_empty() or _records_have_scenario_actions(forged_records):
			failures.append("Projected actor mutation %s reached presentation instead of trusted base plus disabled fallback." % projected_mutation)
		forged_canvas.render_environment_snapshot({"id": "forged_finalized_route_%s" % projected_mutation, "archetype_id": "bar", "reduce_motion": true, "interactable_objects": forged_records})
		var failure_rect := _canvas_object_rect(forged_canvas, "scenario::presentation_failure")
		if not _object(_array(forged_canvas.current_view_snapshot().get("objects", [])), "scenario::route_guard").is_empty() or forged_canvas.object_id_at_local_position(failure_rect.get_center()) != "scenario::presentation_failure":
			failures.append("Public canvas draw/hit routing exposed projected actor mutation %s before consuming the explicit failure result." % projected_mutation)
	forged_canvas.free()
	run_state.current_environment = committed_environment


static func _check_committed_projection_mismatch(library: Variant, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.current_environment = _finalization_environment(ScenarioSequenceContractScript.finalization_fixture_definition())
	var trusted_base := [_production_presentation()]
	run_state.scenario_prepare_semantic_finalization()
	var finalized := run_state.scenario_finalize_base_semantics(trusted_base, library, _production_layout_context())
	var first_projection := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), finalized)
	var replayed := run_state.scenario_finalize_base_semantics(trusted_base, library, _production_layout_context())
	if str(finalized.get("layout_authority_digest", "")) != str(replayed.get("layout_authority_digest", "")) or JSON.stringify(finalized.get("layout_authority", {})) != JSON.stringify(replayed.get("layout_authority", {})):
		failures.append("Semantic replay changed the sealed presentation-identity mapping or its authority digest.")
	# Model a stale presentation result racing a newer replay commit without
	# changing the projected records themselves.
	run_state.current_environment["scenario_layout_authority_digest"] = "0".repeat(64)
	var rejected := EnvironmentInteractionControllerScript.committed_projection_status_result(run_state, first_projection, trusted_base)
	var records := _array(rejected.get("records", []))
	if not bool(finalized.get("ok", false)) or not bool(first_projection.get("ok", false)) or not bool(replayed.get("ok", false)) or not bool(replayed.get("replayed", false)) or bool(rejected.get("ok", true)) or not _record(records, "scenario::command_console").is_empty() or _record(records, "game:slot").is_empty() or _record(records, "scenario::presentation_failure").is_empty() or _records_have_scenario_actions(records):
		failures.append("Committed-digest replay mismatch returned stale projected scenario records instead of trusted base plus disabled fallback.")
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({"id": "stale_replay_projection", "archetype_id": "bar", "interactable_objects": records})
	var view := _dict(canvas.current_view_snapshot())
	var failure_rect := _snapshot_rect(_layout_entry(_dict(view.get("object_layout", {})), "scenario::presentation_failure").get("rect", {}))
	if not _object(_array(view.get("objects", [])), "scenario::command_console").is_empty() or canvas.object_id_at_local_position(failure_rect.get_center()) != "scenario::presentation_failure":
		failures.append("Public canvas consumed stale replay projection records during committed-digest rejection.")
	canvas.free()


static func _check_finalized_accessibility(library: Variant, failures: Array) -> void:
	var cases := [
		{"id": "talkdock", "anchor": [285.0, 120.0], "bounds": {"w": 20, "h": 20}, "role": "control", "context": {"reserved_overlay_board_rect": {"x": 306.0, "y": 112.0, "w": 100.0, "h": 18.0}, "small_screen_mode": true, "reduce_motion": true, "production_canvas": true}, "needle": "TalkDock"},
		{"id": "lane", "anchor": [285.0, 355.0], "bounds": {"w": 20, "h": 20}, "role": "obstacle", "context": _production_layout_context(), "needle": "access lane"},
	]
	for case_value in cases:
		var case := _dict(case_value)
		var definition := ScenarioSequenceContractScript.finalization_fixture_definition()
		var command_visual := _command_visual(definition)
		var command_object := _dict(command_visual.get("object", {}))
		command_object["bounds"] = _dict(case.get("bounds", {}))
		command_object["role"] = str(case.get("role", "control"))
		command_visual["object"] = command_object
		_reseal_definition(definition)
		var run_state := RunStateScript.new()
		run_state.current_environment = _finalization_environment(definition)
		run_state.current_environment["semantic_anchors"]["bar_actor"]["position"] = _array(case.get("anchor", []))
		run_state.scenario_prepare_semantic_finalization()
		var rejected := run_state.scenario_finalize_base_semantics([_production_presentation()], library, _dict(case.get("context", {})))
		if bool(rejected.get("ok", true)) or not _contains_text(_array(rejected.get("errors", [])), str(case.get("needle", ""))) or run_state.current_environment.has("scenario_semantic_ready"):
			failures.append("Validated finalization did not reject the expanded small-screen %s hostile layout atomically: %s" % [str(case.get("id", "")), JSON.stringify(rejected.get("errors", []))])

	_check_finalized_expanded_path_and_label(library, failures)
	_check_explicit_alternate_exit(library, failures)


static func _check_finalized_expanded_path_and_label(library: Variant, failures: Array) -> void:
	var path_definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var path_visual := _command_visual(path_definition)
	var path_object := _dict(path_visual.get("object", {}))
	path_object["anchor_id"] = "path_target"
	path_object["bounds"] = {"w": 32, "h": 32}
	path_visual["object"] = path_object
	_append_scene_visual(path_definition, "expanded_path_blocker", "Path blocker", "obstacle", "path_blocker", {"w": 20, "h": 20})
	_reseal_definition(path_definition)
	var path_run := RunStateScript.new()
	path_run.current_environment = _finalization_environment(path_definition)
	path_run.current_environment["semantic_anchors"]["path_target"] = {"position": [450.0, 215.0]}
	path_run.current_environment["semantic_anchors"]["path_blocker"] = {"position": [470.0, 300.0]}
	path_run.scenario_prepare_semantic_finalization()
	var path_rejected := path_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	var path_errors := _array(path_rejected.get("errors", []))
	if bool(path_rejected.get("ok", true)) or not _contains_text(path_errors, "Expanded small-screen scenario obstruction") or not _contains_text(path_errors, "not reachable"):
		failures.append("Validated finalization did not evaluate expanded obstacle path and interaction reachability in parallel with normal geometry: %s" % JSON.stringify(path_errors))

	var label_definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var label_visual := _command_visual(label_definition)
	var label_object := _dict(label_visual.get("object", {}))
	label_object["label"] = "Small expanded label"
	label_object["anchor_id"] = "small_label"
	label_object["bounds"] = {"w": 20, "h": 20}
	label_visual["object"] = label_object
	_append_scene_visual(label_definition, "large_label", "Large stable label", "prop", "large_label", {"w": 60, "h": 60})
	_reseal_definition(label_definition)
	var label_run := RunStateScript.new()
	label_run.current_environment = _finalization_environment(label_definition)
	label_run.current_environment["semantic_anchors"]["small_label"] = {"position": [380.0, 100.0]}
	label_run.current_environment["semantic_anchors"]["large_label"] = {"position": [300.0, 100.0]}
	label_run.scenario_prepare_semantic_finalization()
	var label_rejected := label_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	if bool(label_rejected.get("ok", true)) or not _contains_text(_array(label_rejected.get("errors", [])), "text-safe in expanded small-screen"):
		failures.append("Validated finalization did not reject expanded-only label overlap with the production label geometry: %s" % JSON.stringify(label_rejected.get("errors", [])))


static func _check_explicit_alternate_exit(library: Variant, failures: Array) -> void:
	var guessed_definition := ScenarioSequenceContractScript.finalization_fixture_definition()
	var blocked_exit := _command_interaction(guessed_definition)
	blocked_exit["enabled"] = false
	blocked_exit["state_label"] = "Blocked"
	blocked_exit["disabled_reason"] = "The marked exit is blocked."
	blocked_exit["available_actions"] = []
	blocked_exit["safe_exit"] = true
	blocked_exit["alternate_exit"] = false
	_append_scene_visual(guessed_definition, "leave_objective_route", "Leave objective route", "control", "alternate_exit_anchor", {"w": 72, "h": 56})
	_append_interaction(guessed_definition, {
		"owner_namespace": "scenario",
		"stable_object_id": "leave_objective_route",
		"presentation_object_id": "scenario::leave_objective_route",
		"label": "Leave objective route",
		"state_label": "Available",
		"prompt": "Use the alternate objective route.",
		"enabled": true,
		"disabled_reason": "",
		"available_actions": [{"id": "prepare", "label": "Leave now", "input_action": "confirm", "non_color_state": "ready"}],
		"input_actions": ["confirm"],
		"non_color_state": "available",
		"focus_order": 5,
		"hit_bounds": {"w": 72, "h": 56},
		"normalized_hit_rect": {"x": 0.65, "y": 0.4, "w": 0.08, "h": 0.13},
		"min_target_size": 44,
		"safe_exit": false,
		"alternate_exit": false,
	})
	_configure_alternate_exit_proof(guessed_definition)
	_reseal_definition(guessed_definition)
	var guessed_run := RunStateScript.new()
	guessed_run.current_environment = _finalization_environment(guessed_definition)
	guessed_run.current_environment["semantic_anchors"]["alternate_exit_anchor"] = {"position": [650.0, 200.0]}
	guessed_run.scenario_prepare_semantic_finalization()
	var guessed_rejected := guessed_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	if bool(guessed_rejected.get("ok", true)) or not _contains_text(_array(guessed_rejected.get("errors", [])), "alternate objective"):
		failures.append("Exit/objective words still inferred alternate-exit authority without an explicit authored boolean.")

	var explicit_definition := guessed_definition.duplicate(true)
	var explicit_interaction := _command_interaction_by_id(explicit_definition, "leave_objective_route")
	explicit_interaction["alternate_exit"] = true
	_reseal_definition(explicit_definition)
	var explicit_run := RunStateScript.new()
	explicit_run.current_environment = _finalization_environment(explicit_definition)
	explicit_run.current_environment["semantic_anchors"]["alternate_exit_anchor"] = {"position": [650.0, 200.0]}
	explicit_run.scenario_prepare_semantic_finalization()
	var explicit_finalized := explicit_run.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	if not bool(explicit_finalized.get("ok", false)):
		failures.append("An explicit authored alternate_exit boolean did not satisfy the blocked-exit contract: %s" % JSON.stringify(explicit_finalized.get("errors", [])))


static func _check_ordinary_interaction_coexistence(failures: Array) -> void:
	var untouched := _base_record("game:cards", "game", "Deal cards")
	var targeted := _base_record("travel:leave", "base", "Leave")
	var removed := _base_record("event:closed", "event", "Closed event")
	untouched["focus_rect"] = Rect2(0.08, 0.20, 0.12, 0.16)
	targeted["focus_rect"] = Rect2(0.40, 0.20, 0.12, 0.16)
	removed["focus_rect"] = Rect2(0.72, 0.20, 0.12, 0.16)
	var projection := {
		"semantic_state": {
			"scene_objects": {},
			"interactions": {
				"base::travel:leave": {
					"owner_namespace": "base",
					"stable_object_id": "travel:leave",
					"present": true,
					"label": "Marked exit",
					"prompt": "Take the marked exit.",
					"state_label": "Open",
					"enabled": true,
					"available_actions": [{
						"id": "scenario_leave",
						"label": "Use marked exit",
						"action_origin_receipt_key": "phase:exit",
					}],
				},
				"event::event:closed": {
					"owner_namespace": "event",
					"stable_object_id": "event:closed",
					"present": false,
				},
			},
		},
	}
	var records := EnvironmentInteractionControllerScript.project_sequence_interactions(
		[untouched, targeted, removed],
		projection,
		{"id": "ordinary_projection_fixture"}
	)
	var untouched_result := _record(records, "game:cards")
	var targeted_result := _record(records, "travel:leave")
	if untouched_result.is_empty() or str(untouched_result.get("confirm_action_id", "")) != "activate":
		failures.append("An active sequence removed or rewrote an unrelated ordinary interaction.")
	if not _array(untouched_result.get("scenario_sequence_actions", [])).is_empty():
		failures.append("An unrelated ordinary interaction gained scenario command authority.")
	if targeted_result.is_empty() or str(targeted_result.get("confirm_action_id", "")) != "scenario_leave" or _array(targeted_result.get("scenario_sequence_actions", [])).size() != 1:
		failures.append("A declared scenario target did not exclusively receive its authored scenario action.")
	if not _record(records, "event:closed").is_empty():
		failures.append("A declared public removal tombstone did not suppress its exact base interaction.")


static func _check_public_removal_tombstones(failures: Array) -> void:
	var identity := "base::door"
	var semantic := {
		"declared_targets": {"interactions": [identity]},
		"target_inventory": {"interactions": [identity]},
		"base_interactions": [{
			"owner_namespace": "base",
			"stable_object_id": "door",
			"enabled": true,
			"available_actions": [],
		}],
	}
	var removed := OperationRegistryScript.apply_operations(semantic, "interaction_ops", [{
		"family": "interaction_ops",
		"op": "remove",
		"receipt_id": "remove_door",
		"owner_namespace": "base",
		"stable_object_id": "door",
	}], "presentation:phase:remove")
	var public_state := OperationRegistryScript.public_semantic_state(_dict(removed.get("state", {})))
	var tombstone := _dict(_dict(public_state.get("interactions", {})).get(identity, {}))
	if not bool(removed.get("ok", false)) or tombstone != {
		"owner_namespace": "base",
		"stable_object_id": "door",
		"present": false,
	}:
		failures.append("A declared base removal did not expose the exact closed public presence tombstone.")
	if JSON.stringify(public_state).contains("receipt_id") or JSON.stringify(public_state).contains("tombstones"):
		failures.append("The public removal marker leaked operation receipt or tombstone journal internals.")


static func _check_visible_semantic_geometry(failures: Array) -> void:
	var environment := {
		"layout": {"object_rects": {}},
		"semantic_zones": {"floor": {"bounds": [0.0, 0.0, BOARD_SIZE.x, BOARD_SIZE.y]}},
		"semantic_anchors": {
			"crate_anchor": {"zone_id": "floor", "position": [180.0, 160.0]},
			"actor_start": {"zone_id": "floor", "position": [340.0, 230.0]},
			"actor_end": {"zone_id": "floor", "position": [620.0, 230.0]},
		},
	}
	var projection := _geometry_projection()
	var prepared := ScenarioSemanticViewModelScript.prepare_projection([], projection, environment)
	var layout_audit := _dict(prepared.get("layout_audit", {}))
	if not bool(prepared.get("ok", false)) or int(layout_audit.get("collision_adjustment_count", 0)) < 2 or int(layout_audit.get("small_screen_overlap_count", -1)) != 0 or not bool(layout_audit.get("deterministic_z_order", false)) or str(prepared.get("layout_authority_digest", "")).length() != 64:
		failures.append("Bounded scenario geometry did not resolve or deterministically separate colliding authored visuals: %s" % JSON.stringify(prepared.get("errors", [])))
		return
	var records := EnvironmentInteractionControllerScript.project_sequence_interactions([], projection, environment)
	var crate := _record(records, "scenario::crate")
	var actor := _record(records, "scenario::guard")
	var crate_rect: Rect2 = crate.get("focus_rect", Rect2())
	var actor_rect: Rect2 = actor.get("focus_rect", Rect2())
	if crate.is_empty() or not crate_rect.get_center().is_equal_approx(Vector2(180.0 / BOARD_SIZE.x, 160.0 / BOARD_SIZE.y)) or not crate_rect.size.is_equal_approx(Vector2(90.0 / BOARD_SIZE.x, 60.0 / BOARD_SIZE.y)):
		failures.append("Scene spawn/move bounds did not reach the interaction presentation geometry.")
	if bool(crate.get("enabled", true)) or str(crate.get("semantic_state", "")) != "locked" or str(crate.get("semantic_appearance", "")) != "striped":
		failures.append("Scene disable/state/appearance semantics did not reach the visible presentation record.")
	if actor.is_empty() or actor_rect.get_center().is_equal_approx(Vector2(620.0 / BOARD_SIZE.x, 230.0 / BOARD_SIZE.y)) or str(actor.get("actor_pose", "")) != "brace" or str(actor.get("actor_behavior", "")) != "flee" or str(actor.get("actor_route_id", "")) != "base::world:actor_end" or _dict(actor.get("actor_route_stage", {})).is_empty():
		failures.append("Actor start/route/pose/behavior did not reach deterministic staged presentation metadata.")

	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({
		"id": "semantic_geometry_fixture",
		"archetype_id": "bar",
		"display_name": "Semantic geometry fixture",
		"reduce_motion": true,
		"interactable_objects": records,
	})
	var view := _dict(canvas.current_view_snapshot())
	var crate_layout := _layout_entry(_dict(view.get("object_layout", {})), "scenario::crate")
	var canvas_crate_rect := _snapshot_rect(crate_layout.get("rect", {}))
	var canvas_actor := _object(_array(view.get("objects", [])), "scenario::guard")
	if canvas_crate_rect.size.x < 90.0 or canvas_crate_rect.size.y < 60.0 or canvas.object_id_at_local_position(canvas_crate_rect.get_center()) != "scenario::crate":
		failures.append("Canvas draw geometry and scenario interaction hit geometry are not correlated.")
	var reduced_actor_layout := _layout_entry(_dict(view.get("object_layout", {})), "scenario::guard")
	var reduced_actor_rect := _snapshot_rect(reduced_actor_layout.get("rect", {}))
	if not bool(view.get("reduce_motion", false)) or str(canvas_actor.get("actor_pose", "")) != "brace" or _array(canvas_actor.get("actor_route_points", [])).size() != 2 or not reduced_actor_rect.get_center().is_equal_approx(Vector2(620.0, 230.0)):
		failures.append("Canvas did not use the explicit actor route endpoint as its reduced-motion fallback.")
	var evidence := _dict(view.get("scenario_layout_evidence", {}))
	if int(evidence.get("authority_count", 0)) < 3 or int(evidence.get("authority_digest_count", 0)) != 1:
		failures.append("Canvas did not expose capture-ready correlated layout-authority evidence.")
	canvas.set_small_screen_mode(true)
	var small_layout := _layout_entry(_dict(canvas.current_view_snapshot().get("object_layout", {})), "scenario::crate")
	var small_rect := _snapshot_rect(small_layout.get("rect", {}))
	if small_rect.size.x < SMALL_SCREEN_TARGET.x or small_rect.size.y < SMALL_SCREEN_TARGET.y or canvas.object_id_at_local_position(small_rect.get_center()) != "scenario::crate":
		failures.append("Small-screen scenario geometry did not expand and preserve its correlated hit region.")
	canvas.free()

	var revealed := projection.duplicate(true)
	revealed["semantic_state"]["scene_objects"]["scenario::crate"]["enabled"] = true
	revealed["semantic_state"]["interactions"]["scenario::crate"]["enabled"] = true
	revealed["semantic_state"]["interactions"]["scenario::crate"]["available_actions"] = [{"id": "inspect", "label": "Inspect", "action_origin_receipt_key": "phase:crate"}]
	var revealed_records := EnvironmentInteractionControllerScript.project_sequence_interactions([], revealed, environment)
	if not bool(_record(revealed_records, "scenario::crate").get("enabled", false)):
		failures.append("Scene enable/reveal semantics did not restore the rendered object.")
	var hidden := projection.duplicate(true)
	hidden["semantic_state"]["scene_objects"]["scenario::crate"]["visible"] = false
	hidden["semantic_state"]["interactions"]["scenario::crate"]["present"] = false
	var hidden_canvas = PixelSceneCanvasScript.new()
	hidden_canvas.size = BOARD_SIZE
	hidden_canvas.render_environment_snapshot({
		"id": "semantic_hidden_fixture",
		"archetype_id": "bar",
		"interactable_objects": EnvironmentInteractionControllerScript.project_sequence_interactions([], hidden, environment),
	})
	if not _object(_array(hidden_canvas.current_view_snapshot().get("objects", [])), "scenario::crate").is_empty():
		failures.append("Scene hide semantics remained visible or hittable on the canvas.")
	hidden_canvas.free()


static func _check_atomic_projection_failures(failures: Array) -> void:
	var base := _base_record("door", "base", "Ordinary door")
	base["focus_rect"] = Rect2(0.62, 0.18, 0.10, 0.14)
	var targeted_projection := {
		"semantic_state": {
			"scene_objects": {},
			"actors": {},
			"interactions": {
				"base::door": _interaction_payload("base", "door", "Scenario door", true),
			},
		},
	}
	var missing_layout := EnvironmentInteractionControllerScript.project_sequence_interaction_result([base], targeted_projection)
	var preserved := _record(_array(missing_layout.get("records", [])), "door")
	var missing_failure := _record(_array(missing_layout.get("records", [])), "scenario::presentation_failure")
	if bool(missing_layout.get("ok", true)) or preserved.is_empty() or preserved.get("focus_rect", Rect2()) != base.get("focus_rect", Rect2()) or str(preserved.get("confirm_action_id", "")) != "activate" or missing_failure.is_empty() or bool(missing_failure.get("enabled", true)) or not _array(missing_failure.get("available_actions", [])).is_empty() or (missing_failure.get("focus_rect", Rect2()) as Rect2).intersects(base.get("focus_rect", Rect2())):
		failures.append("An empty mandatory layout bypassed atomic projection failure or did not preserve ordinary controls with a visible disabled fallback.")

	var stale_projection := targeted_projection.duplicate(true)
	stale_projection["semantic_state"]["scene_objects"] = {
		"base::door": {
			"owner_namespace": "base", "stable_object_id": "door", "present": true,
			"label": "Scenario door", "role": "exit", "anchor_id": "missing_anchor",
			"bounds": {"w": 90.0, "h": 60.0}, "visible": true, "enabled": true,
		},
	}
	var stale_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([base], stale_projection, {"id": "stale_fixture", "semantic_anchors": {}})
	var stale_base := _record(_array(stale_result.get("records", [])), "door")
	if bool(stale_result.get("ok", true)) or stale_base.get("focus_rect", Rect2()) != base.get("focus_rect", Rect2()) or str(stale_base.get("confirm_action_id", "")) != "activate" or not _array(stale_base.get("scenario_sequence_actions", [])).is_empty():
		failures.append("Invalid matching scene geometry combined stale base visuals with new scenario action authority.")

	var orphan_projection := {
		"semantic_state": {
			"scene_objects": {}, "actors": {},
			"interactions": {
				"scenario::orphan": _interaction_payload("scenario", "orphan", "Orphan control", true),
			},
		},
	}
	orphan_projection["semantic_state"]["interactions"]["scenario::orphan"]["normalized_hit_rect"] = {"x": 0.2, "y": 0.2, "w": 0.2, "h": 0.2}
	var orphan_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([], orphan_projection, {"id": "orphan_fixture"})
	var orphan_wrapper := EnvironmentInteractionControllerScript.project_sequence_interactions([], orphan_projection, {"id": "orphan_fixture"})
	if bool(orphan_result.get("ok", true)) or not _record(_array(orphan_result.get("records", [])), "scenario::orphan").is_empty() or _record(orphan_wrapper, "scenario::presentation_failure").is_empty() or not _contains_text(_array(orphan_result.get("errors", [])), "raw hit rectangles"):
		failures.append("An orphan semantic rectangle became hit authority or the compatibility caller ignored structured projection errors.")

	var left := _base_record("left", "base", "Left control")
	left["focus_rect"] = Rect2(0.20, 0.30, 44.0 / BOARD_SIZE.x, 44.0 / BOARD_SIZE.y)
	var right := _base_record("right", "base", "Right control")
	right["focus_rect"] = Rect2(0.29, 0.30, 44.0 / BOARD_SIZE.x, 44.0 / BOARD_SIZE.y)
	var ambiguous_projection := {
		"semantic_state": {
			"scene_objects": {}, "actors": {},
			"interactions": {
				"base::left": _interaction_payload("base", "left", "Left control", true),
				"base::right": _interaction_payload("base", "right", "Right control", true),
			},
		},
	}
	var ambiguous := EnvironmentInteractionControllerScript.project_sequence_interaction_result([left, right], ambiguous_projection, {"id": "expanded_fixture"})
	if bool(ambiguous.get("ok", true)) or not _contains_text(_array(ambiguous.get("errors", [])), "expanded small-screen"):
		failures.append("Expanded small-screen hit ambiguity was accepted and left reverse draw order as interaction authority.")
	var invalid_settings_environment := {
		"id": "production_settings_fixture",
		"_scenario_layout_context": {
			"reserved_overlay_board_rect": {},
			"small_screen_mode": "yes",
			"reduce_motion": false,
			"production_canvas": true,
		},
	}
	var invalid_settings := EnvironmentInteractionControllerScript.project_sequence_interaction_result([base], targeted_projection, invalid_settings_environment)
	if bool(invalid_settings.get("ok", true)) or not _contains_text(_array(invalid_settings.get("errors", [])), "setting small_screen_mode must be boolean"):
		failures.append("Malformed production accessibility settings bypassed structured layout validation.")
	var divergent_interaction := _interaction_payload("scenario", "disabled_visual", "Disabled visual", true)
	var divergent_projection := {
		"semantic_state": {
			"scene_objects": {
				"scenario::disabled_visual": {
					"owner_namespace": "scenario", "stable_object_id": "disabled_visual", "present": true,
					"label": "Disabled visual", "role": "control", "anchor_id": "control",
					"bounds": {"w": 72.0, "h": 52.0}, "visible": true, "enabled": false,
				},
			},
			"actors": {},
			"interactions": {"scenario::disabled_visual": divergent_interaction},
		},
	}
	var divergent := EnvironmentInteractionControllerScript.project_sequence_interaction_result([], divergent_projection, {"id": "divergence_fixture", "semantic_anchors": {"control": {"position": [450.0, 180.0]}}})
	if bool(divergent.get("ok", true)) or not _contains_text(_array(divergent.get("errors", [])), "remains actionable") or not _record(_array(divergent.get("records", [])), "scenario::disabled_visual").is_empty():
		failures.append("Actionable scenario semantics diverged from a disabled visual instead of failing atomically.")


static func _check_accessibility_failures(failures: Array) -> void:
	var obstruction := {
		"semantic_state": {
			"scene_objects": {
				"scenario::barricade": {
					"owner_namespace": "scenario", "stable_object_id": "barricade", "present": true,
					"label": "Barricade", "role": "obstacle", "anchor_id": "lane",
					"bounds": {"w": 760.0, "h": 34.0}, "visible": true, "enabled": true,
				},
			},
			"actors": {}, "interactions": {},
		},
	}
	var obstruction_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([], obstruction, {
		"id": "obstruction_fixture",
		"semantic_anchors": {"lane": {"position": [450.0, 396.0]}},
	})
	if bool(obstruction_result.get("ok", true)) or not _contains_text(_array(obstruction_result.get("errors", [])), "access lane"):
		failures.append("A scenario obstruction blocked the mandatory walk/access lane without failing projection.")

	var overlay_and_text := {
		"semantic_state": {
			"scene_objects": {
				"scenario::overlay_target": {
					"owner_namespace": "scenario", "stable_object_id": "overlay_target", "present": true,
					"label": "Readable target", "role": "control", "anchor_id": "overlay_anchor",
					"bounds": {"w": 80.0, "h": 54.0}, "visible": true, "enabled": true,
				},
				"scenario::bad_text": {
					"owner_namespace": "scenario", "stable_object_id": "bad_text", "present": true,
					"label": "X".repeat(80), "role": "prop", "anchor_id": "text_anchor",
					"bounds": {"w": 60.0, "h": 48.0}, "visible": true, "enabled": true,
				},
			},
			"actors": {}, "interactions": {},
		},
	}
	var overlay_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([], overlay_and_text, {
		"id": "overlay_fixture",
		"semantic_anchors": {
			"overlay_anchor": {"position": [450.0, 100.0]},
			"text_anchor": {"position": [720.0, 220.0]},
		},
		"_scenario_layout_context": {
			"reserved_overlay_board_rect": {"x": 360.0, "y": 40.0, "w": 180.0, "h": 130.0},
			"small_screen_mode": true,
			"reduce_motion": true,
			"production_canvas": true,
		},
	})
	if bool(overlay_result.get("ok", true)) or not _contains_text(_array(overlay_result.get("errors", [])), "TalkDock") or not _contains_text(_array(overlay_result.get("errors", [])), "readable label"):
		failures.append("Reserved-overlay or bounded text-safety violations did not fail the production layout context.")

	var exit := _base_record("blocked_exit", "base", "Blocked exit")
	exit["focus_rect"] = Rect2(0.74, 0.34, 0.10, 0.16)
	var exit_interaction := _interaction_payload("base", "blocked_exit", "Blocked exit", false)
	exit_interaction["safe_exit"] = true
	var exit_projection := {"semantic_state": {"scene_objects": {}, "actors": {}, "interactions": {"base::blocked_exit": exit_interaction}}}
	var exit_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([exit], exit_projection, {"id": "exit_fixture"})
	if bool(exit_result.get("ok", true)) or not _contains_text(_array(exit_result.get("errors", [])), "alternate objective or exit"):
		failures.append("A blocked exit projected without a readable reachable alternate objective or exit action.")

	var endpoint_collision := {
		"semantic_state": {
			"scene_objects": {
				"scenario::endpoint_prop": {
					"owner_namespace": "scenario", "stable_object_id": "endpoint_prop", "present": true,
					"label": "Endpoint prop", "role": "prop", "anchor_id": "endpoint",
					"bounds": {"w": 72.0, "h": 72.0}, "visible": true, "enabled": true,
				},
			},
			"actors": {
				"scenario::runner": {
					"owner_namespace": "scenario", "stable_object_id": "runner", "present": true,
					"label": "Runner", "actor_id": "runner", "anchor_id": "start",
					"behavior": "depart", "route_id": "base::world:endpoint", "pose": "run",
				},
			},
			"routes": {"base::world:endpoint": {"owner_namespace": "base", "stable_object_id": "world:endpoint", "present": true, "source_id": "endpoint", "enabled": true}},
			"interactions": {},
		},
	}
	var endpoint_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result([], endpoint_collision, {
		"id": "endpoint_fixture",
		"semantic_anchors": {
			"start": {"position": [220.0, 220.0]},
			"endpoint": {"position": [620.0, 220.0]},
		},
	})
	if bool(endpoint_result.get("ok", true)) or not _contains_text(_array(endpoint_result.get("errors", [])), "route endpoint collides"):
		failures.append("A moving actor route/reduced-motion endpoint collided with another visual without failing projection.")


static func _geometry_projection() -> Dictionary:
	return {
		"semantic_state": {
			"scene_objects": {
				"scenario::crate": {
					"owner_namespace": "scenario", "stable_object_id": "crate", "present": true,
					"label": "Locked crate", "role": "obstacle", "anchor_id": "crate_anchor", "zone_id": "floor",
					"bounds": {"w": 90.0, "h": 60.0}, "visible": true, "enabled": false,
					"state": "locked", "appearance": "striped",
				},
				"scenario::crate_overlap": {
					"owner_namespace": "scenario", "stable_object_id": "crate_overlap", "present": true,
					"label": "Second crate", "role": "prop", "anchor_id": "crate_anchor", "zone_id": "floor",
					"bounds": {"w": 90.0, "h": 60.0}, "visible": true, "enabled": true,
				},
			},
			"actors": {
				"scenario::guard": {
					"owner_namespace": "scenario", "stable_object_id": "guard", "present": true,
					"label": "Running guard", "actor_id": "guard_actor", "anchor_id": "actor_start", "zone_id": "floor",
					"behavior": "flee", "route_id": "base::world:actor_end", "pose": "brace",
				},
			},
			"routes": {
				"base::world:actor_end": {
					"owner_namespace": "base", "stable_object_id": "world:actor_end", "present": true,
					"source_id": "actor_end", "enabled": true,
				},
			},
			"interactions": {
				"scenario::crate": {
					"owner_namespace": "scenario", "stable_object_id": "crate", "present": true,
					"label": "Locked crate", "prompt": "Inspect the locked crate.", "state_label": "Locked",
					"enabled": false, "disabled_reason": "The crate is locked.", "focus_order": 1,
					"available_actions": [],
				},
			},
		},
	}


static func _finalization_environment(definition: Dictionary) -> Dictionary:
	return {
		"id": "bar_001",
		"archetype_id": "bar",
		"world_node_id": "bar_node",
		"environment_visit_id": "visit_1",
		"scenario_sequence_definition": definition,
		"game_ids": ["slot"],
		"event_ids": ["late_shift_discount"],
		"service_ids": ["house_drink"],
		"lender_hooks": [],
		"item_offers": [],
		"travel_hooks": ["bar"],
		"next_archetypes": [],
		"semantic_anchors": {
			"bar_floor_100": {"position": [90.0, 120.0]},
			"bar_actor": {"position": [180.0, 120.0]},
		},
		"layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}}},
	}


static func _production_presentation() -> Dictionary:
	return EnvironmentInteractionViewModelScript.make_interactable_object({
		"object_id": "game:slot",
		"object_type": "game",
		"source_id": "slot",
		"interactive": true,
		"label": "Slot",
		"prompt": "Choose an action.",
		"enabled": true,
		"available_actions": [{"id": "enter_game", "label": "Enter"}],
		"focus_rect": Rect2(0.1, 0.1, 0.12, 0.18),
	}, {})


static func _production_layout_context() -> Dictionary:
	return {
		"reserved_overlay_board_rect": {},
		"small_screen_mode": false,
		"reduce_motion": false,
		"production_canvas": true,
	}


static func _command_visual(definition: Dictionary) -> Dictionary:
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	for operation_value in phase.get("scene_ops", []):
		var operation := operation_value as Dictionary
		if str(operation.get("stable_object_id", "")) == "command_console":
			return operation
	return {}


static func _command_interaction(definition: Dictionary) -> Dictionary:
	return _command_interaction_by_id(definition, "command_console")


static func _command_interaction_by_id(definition: Dictionary, stable_id: String) -> Dictionary:
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	for operation_value in phase.get("interaction_ops", []):
		var operation := operation_value as Dictionary
		if str(operation.get("stable_object_id", "")) == stable_id:
			return operation.get("interaction", {}) as Dictionary
	return {}


static func _append_scene_visual(definition: Dictionary, stable_id: String, label: String, role: String, anchor_id: String, bounds: Dictionary) -> void:
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	var scene_ops: Array = phase.get("scene_ops", [])
	scene_ops.append({
		"family": "scene_ops",
		"op": "spawn",
		"receipt_id": "scene_spawn_%s" % stable_id,
		"owner_namespace": "scenario",
		"stable_object_id": stable_id,
		"object": {"label": label, "role": role, "anchor_id": anchor_id, "bounds": bounds.duplicate(true), "visible": true, "enabled": true},
	})
	phase["scene_ops"] = scene_ops
	_append_cleanup(definition, "scene_ops", stable_id)


static func _append_interaction(definition: Dictionary, interaction: Dictionary) -> void:
	var stable_id := str(interaction.get("stable_object_id", ""))
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	var interaction_ops: Array = phase.get("interaction_ops", [])
	interaction_ops.append({
		"family": "interaction_ops",
		"op": "add",
		"receipt_id": "interaction_add_%s" % stable_id,
		"owner_namespace": "scenario",
		"stable_object_id": stable_id,
		"interaction": interaction.duplicate(true),
	})
	phase["interaction_ops"] = interaction_ops
	_append_cleanup(definition, "interaction_ops", stable_id)


static func _append_cleanup(definition: Dictionary, family: String, stable_id: String) -> void:
	var cleanup: Dictionary = definition["sequence"]["cleanup"]
	var operations: Array = cleanup.get("operations", [])
	operations.append({"family": family, "op": "remove", "receipt_id": "cleanup_%s_%s" % [family.trim_suffix("_ops"), stable_id], "owner_namespace": "scenario", "stable_object_id": stable_id})
	cleanup["operations"] = operations


static func _configure_alternate_exit_proof(definition: Dictionary) -> void:
	var phase: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]
	phase["objective_ids"] = ["clear_exit"]
	phase["branches"] = [{"id": "continue", "condition": {"type": "command", "command_id": "prepare"}, "next_phase": "aftermath"}]
	var interaction_ops: Array = phase.get("interaction_ops", [])
	interaction_ops.append({
		"family": "interaction_ops",
		"op": "gate",
		"receipt_id": "interaction_gate_declared_exit",
		"owner_namespace": "scenario",
		"stable_object_id": "declared_exit_gate",
		"mode": "gate",
		"target_owner_namespace": "game",
		"target_stable_object_id": "game:slot",
		"enabled": false,
		"disabled_reason": "The ordinary route is blocked.",
	})
	phase["interaction_ops"] = interaction_ops


static func _reseal_definition(definition: Dictionary) -> void:
	definition["sequence"]["sequence_signature"] = ScenarioSequenceSchemaScript.calculated_signature_hash(definition)


static func _base_record(object_id: String, owner: String, label: String) -> Dictionary:
	return {
		"object_id": object_id,
		"object_type": "travel" if object_id.begins_with("travel:") else "game" if object_id.begins_with("game:") else "event",
		"visual_type": "fixture",
		"source_id": object_id.get_slice(":", 1),
		"owner_namespace": owner,
		"stable_object_id": object_id,
		"label": label,
		"interactive": true,
		"enabled": true,
		"available_actions": [{"id": "activate", "label": "Activate"}],
		"confirm_action_id": "activate",
		"scenario_sequence_actions": [],
		"focus_rect": Rect2(0.2, 0.2, 0.12, 0.16),
	}


static func _interaction_payload(owner: String, stable_id: String, label: String, enabled: bool) -> Dictionary:
	return {
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"present": true,
		"label": label,
		"prompt": "Inspect %s." % label.to_lower(),
		"state_label": "Available" if enabled else "Blocked",
		"enabled": enabled,
		"disabled_reason": "This route is visibly blocked." if not enabled else "",
		"non_color_state": "available" if enabled else "blocked",
		"focus_order": 1,
		"available_actions": [{"id": "scenario_action", "label": "Act", "action_origin_receipt_key": "phase:test"}] if enabled else [],
	}


static func _record(records: Array, object_id: String) -> Dictionary:
	for value in records:
		var record := _dict(value)
		if str(record.get("object_id", "")) == object_id:
			return record
	return {}


static func _mutable_record(records_value: Variant, object_id: String) -> Dictionary:
	if typeof(records_value) != TYPE_ARRAY:
		return {}
	for value in records_value as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("object_id", "")) == object_id:
			return value as Dictionary
	return {}


static func _records_have_scenario_actions(records: Array) -> bool:
	for value in records:
		if not _array(_dict(value).get("scenario_sequence_actions", [])).is_empty():
			return true
	return false


static func _canvas_point(value: Variant) -> Vector2:
	var point := _dict(value)
	return Vector2(float(point.get("x", -1.0)) * BOARD_SIZE.x, float(point.get("y", -1.0)) * BOARD_SIZE.y)


static func _canvas_object_rect(canvas: Variant, object_id: String) -> Rect2:
	var view := _dict(canvas.current_view_snapshot())
	return _snapshot_rect(_layout_entry(_dict(view.get("object_layout", {})), object_id).get("rect", {}))


static func _rect_inside_canvas(rect: Rect2) -> bool:
	return rect.has_area() and rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= BOARD_SIZE.x + 0.01 and rect.end.y <= BOARD_SIZE.y + 0.01


static func _mutate_route_actor(actor: Dictionary, mutation: String) -> void:
	match mutation:
		"normalized_hit_rect", "small_screen_rect":
			var rect := _dict(actor.get(mutation, {}))
			rect["x"] = float(rect.get("x", 0.0)) + 0.01
			actor[mutation] = rect
		"z_order":
			actor["z_order"] = int(actor.get("z_order", 0)) + 1
		"route_point_start", "route_point_endpoint":
			var points := _array(actor.get("route_points", []))
			var point_index := 0 if mutation == "route_point_start" else 1
			points[point_index] = {"x": 0.13, "y": 0.77}
			actor["route_points"] = points
		_:
			var stage := _dict(actor.get("route_stage", {}))
			_mutate_route_stage(stage, mutation)
			actor["route_stage"] = stage


static func _mutate_projected_route_actor(actor: Dictionary, mutation: String) -> void:
	match mutation:
		"object_id_collision":
			actor["object_id"] = "game:slot"
		"scenario_layout_resolved":
			actor["scenario_layout_resolved"] = false
		"owner_namespace":
			actor["owner_namespace"] = "base"
		"stable_object_id":
			actor["stable_object_id"] = "forged_route_guard"
		"visible":
			actor["visible"] = false
		"interactive":
			actor["interactive"] = false
		"normalized_rect", "small_screen_rect":
			var rect := _dict(actor.get(mutation, {}))
			rect["x"] = float(rect.get("x", 0.0)) + 0.01
			actor[mutation] = rect
		"scenario_z_order":
			actor["scenario_z_order"] = int(actor.get("scenario_z_order", 0)) + 1
		"route_point_start", "route_point_endpoint":
			var points := _array(actor.get("actor_route_points", []))
			var point_index := 0 if mutation == "route_point_start" else 1
			points[point_index] = {"x": 0.13, "y": 0.77}
			actor["actor_route_points"] = points
		"authority_identity":
			actor["scenario_layout_authority_identity"] = "scenario::command_console"
		"authority_digest":
			actor["scenario_layout_authority_digest"] = "0".repeat(64)
		_:
			var stage := _dict(actor.get("actor_route_stage", {}))
			_mutate_route_stage(stage, mutation)
			actor["actor_route_stage"] = stage


static func _remove_projected_record(records: Array, object_id: String) -> void:
	for index in range(records.size() - 1, -1, -1):
		if str(_dict(records[index]).get("object_id", "")) == object_id:
			records.remove_at(index)
			return


static func _mutate_route_stage(stage: Dictionary, mutation: String) -> void:
	match mutation:
		"stage_start":
			stage["start"] = {"x": 0.13, "y": 0.77}
		"stage_endpoint":
			stage["endpoint"] = {"x": 0.13, "y": 0.77}
		"stage_reduced_endpoint":
			stage["reduced_motion_endpoint"] = {"x": 0.13, "y": 0.77}
		"stage_small_start":
			stage["small_screen_start"] = {"x": 0.13, "y": 0.77}
		"stage_small_endpoint":
			stage["small_screen_endpoint"] = {"x": 0.13, "y": 0.77}
		"stage_duration":
			stage["duration_sec"] = float(stage.get("duration_sec", 0.0)) + 0.5
		"stage_mode":
			stage["mode"] = "to_endpoint"


static func _object(objects: Array, object_id: String) -> Dictionary:
	for value in objects:
		var object_data := _dict(value)
		if str(object_data.get("id", "")) == object_id:
			return object_data
	return {}


static func _layout_entry(layout: Dictionary, object_id: String) -> Dictionary:
	for value in _array(layout.get("objects", [])):
		var entry := _dict(value)
		if str(entry.get("id", "")) == object_id:
			return entry
	return {}


static func _snapshot_rect(value: Variant) -> Rect2:
	var rect := _dict(value)
	return Rect2(
		float(rect.get("x", 0.0)),
		float(rect.get("y", 0.0)),
		float(rect.get("w", 0.0)),
		float(rect.get("h", 0.0))
	)


static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
