class_name ScenarioSemanticPresentationContract
extends RefCounted

const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)


static func check(_library: Variant, failures: Array) -> void:
	_check_ordinary_interaction_coexistence(failures)
	_check_public_removal_tombstones(failures)
	_check_visible_semantic_geometry(failures)


static func _check_ordinary_interaction_coexistence(failures: Array) -> void:
	var untouched := _base_record("game:cards", "game", "Deal cards")
	var targeted := _base_record("travel:leave", "base", "Leave")
	var removed := _base_record("event:closed", "event", "Closed event")
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
		projection
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
		"semantic_zones": {"floor": {"bounds": [0.0, 0.0, 900.0, 430.0]}},
		"semantic_anchors": {
			"crate_anchor": {"zone_id": "floor", "position": [180.0, 160.0]},
			"actor_start": {"zone_id": "floor", "position": [340.0, 230.0]},
			"actor_end": {"zone_id": "floor", "position": [620.0, 230.0]},
		},
	}
	var projection := _geometry_projection()
	var prepared := ScenarioSemanticViewModelScript.prepare_projection([], projection, environment)
	if not bool(prepared.get("ok", false)) or int(_dict(prepared.get("layout_audit", {})).get("collision_adjustment_count", 0)) != 1:
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
	if actor.is_empty() or not actor_rect.get_center().is_equal_approx(Vector2(620.0 / BOARD_SIZE.x, 230.0 / BOARD_SIZE.y)) or str(actor.get("actor_pose", "")) != "brace" or str(actor.get("actor_behavior", "")) != "flee" or str(actor.get("actor_route_id", "")) != "base::world:actor_end":
		failures.append("Actor position/route/pose/behavior did not reach the visible presentation record.")

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
	if not bool(view.get("reduce_motion", false)) or str(canvas_actor.get("actor_pose", "")) != "brace" or _array(canvas_actor.get("actor_route_points", [])).size() != 2:
		failures.append("Canvas did not retain authored actor pose/route state under reduced motion.")
	var character_actor := _dict(canvas_actor.get("character_actor", {}))
	var members := _array(character_actor.get("members", []))
	var actor_style := canvas.call("_character_actor_style", _dict(members[0] if not members.is_empty() else {}), character_actor, false, 99.0)
	if str(_dict(actor_style).get("pose", "")) != "brace":
		failures.append("Actor drawing replaced the authored reduced-motion pose with an idle animation pose.")
	canvas.set_small_screen_mode(true)
	var small_layout := _layout_entry(_dict(canvas.current_view_snapshot().get("object_layout", {})), "scenario::crate")
	var small_rect := _snapshot_rect(small_layout.get("rect", {}))
	if small_rect.size.x < 104.0 or small_rect.size.y < 76.0 or canvas.object_id_at_local_position(small_rect.get_center()) != "scenario::crate":
		failures.append("Small-screen scenario geometry did not expand and preserve its correlated hit region.")
	canvas.free()

	var revealed := projection.duplicate(true)
	revealed["semantic_state"]["scene_objects"]["scenario::crate"]["enabled"] = true
	var revealed_records := EnvironmentInteractionControllerScript.project_sequence_interactions([], revealed, environment)
	if not bool(_record(revealed_records, "scenario::crate").get("enabled", false)):
		failures.append("Scene enable/reveal semantics did not restore the rendered object.")
	var hidden := projection.duplicate(true)
	hidden["semantic_state"]["scene_objects"]["scenario::crate"]["visible"] = false
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
					"enabled": true, "disabled_reason": "The crate is locked.", "focus_order": 1,
					"available_actions": [{"id": "inspect", "label": "Inspect", "action_origin_receipt_key": "phase:crate"}],
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


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
