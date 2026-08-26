class_name ScenarioSemanticPresentationContract
extends RefCounted

const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
const SMALL_SCREEN_TARGET := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)


static func check(_library: Variant, failures: Array) -> void:
	_check_ordinary_interaction_coexistence(failures)
	_check_public_removal_tombstones(failures)
	_check_visible_semantic_geometry(failures)
	_check_atomic_projection_failures(failures)
	_check_accessibility_failures(failures)


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
	var character_actor := _dict(canvas_actor.get("character_actor", {}))
	var members := _array(character_actor.get("members", []))
	var actor_style := canvas.call("_character_actor_style", _dict(members[0] if not members.is_empty() else {}), character_actor, false, 99.0)
	if str(_dict(actor_style).get("pose", "")) != "brace":
		failures.append("Actor drawing replaced the authored reduced-motion pose with an idle animation pose.")
	canvas.render_environment_snapshot({
		"id": "semantic_geometry_fixture",
		"archetype_id": "bar",
		"display_name": "Semantic geometry fixture",
		"reduce_motion": false,
		"interactable_objects": records,
	})
	var route_duration := float(_dict(actor.get("actor_route_stage", {})).get("duration_sec", 1.0))
	canvas.set("actor_route_time", route_duration * 0.5)
	var moving_layout := _layout_entry(_dict(canvas.current_view_snapshot().get("object_layout", {})), "scenario::guard")
	var moving_center := _snapshot_rect(moving_layout.get("rect", {})).get_center()
	var route_start := actor_rect.get_center() * BOARD_SIZE
	var route_endpoint := Vector2(620.0, 230.0)
	if not moving_center.is_equal_approx(route_start.lerp(route_endpoint, 0.5)):
		failures.append("Normal-motion actor staging did not traverse the sealed route deterministically.")
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
