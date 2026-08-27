extends RefCounted

const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)
const SCENARIO_OBJECT_ID := "scenario:scenario:console:night"
const DIRECT_TOKEN := "scenario_action:7:scenario:console%3Anight:brace%3Aexit"


class ActivationCapture:
	extends RefCounted
	var object_id := ""

	func record(value: String) -> void:
		object_id = value


static func check(failures: Array) -> void:
	_check_composed_actions_and_geometry(failures)
	_check_small_screen_expansion(failures)
	_check_competing_augment_presentation(failures)
	_check_fail_closed_presentation(failures)


static func _check_composed_actions_and_geometry(failures: Array) -> void:
	var prepared := _prepared_snapshot()
	var composed := ScenarioSemanticViewModelScript.compose([_base_record()], prepared, {})
	if not bool(composed.get("ok", false)):
		failures.append("Scenario presentation fixture did not compose: %s" % JSON.stringify(composed.get("errors", [])))
		return
	var records := _array(composed.get("records", []))
	var scenario_record := _record_by_id(records, SCENARIO_OBJECT_ID)
	if scenario_record.is_empty():
		failures.append("Scenario semantic interaction did not become a player-facing room record.")
		return
	var actions := _array(scenario_record.get("inline_actions", []))
	if actions.size() != 2:
		failures.append("Scenario presentation did not preserve both authored actions.")
		return
	var first_action := _dict(actions[0])
	if str(first_action.get("emit_object_id", "")) != DIRECT_TOKEN or str(first_action.get("input_action", "")) != "confirm":
		failures.append("Scenario direct-action token/input mapping is not stable or colon-safe.")
	var descriptor := ScenarioSemanticViewModelScript.action_descriptor_for_token(records, DIRECT_TOKEN)
	if descriptor != {
		"owner_namespace": "scenario",
		"stable_object_id": "console:night",
		"command_id": "brace:exit",
		"idempotency_key": "ui:7:scenario:console%3Anight:brace%3Aexit",
	}:
		failures.append("Scenario direct-action token did not resolve to the exact authoritative command descriptor.")

	var canvas = PixelSceneCanvasScript.new()
	var main_loop := Engine.get_main_loop()
	if not main_loop is SceneTree:
		failures.append("Scenario presentation contract requires an active SceneTree.")
		canvas.free()
		return
	var root := (main_loop as SceneTree).root
	root.add_child(canvas)
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({
		"id": "presentation_fixture",
		"archetype_id": "bar",
		"display_name": "Presentation Fixture",
		"interactable_objects": records,
		"scenario_render_snapshot": prepared,
	})
	var view := _dict(canvas.current_view_snapshot())
	var objects := _array(view.get("objects", []))
	var ids := _object_ids(objects)
	if ids.find(SCENARIO_OBJECT_ID) < 0 or ids.find("travel:leave") < 0 or ids.find("scenario:stage:arrival_shift") < 0:
		failures.append("Canvas did not consume composed scenario visuals/staging records.")
	elif not (ids.find(SCENARIO_OBJECT_ID) < ids.find("travel:leave") and ids.find("travel:leave") < ids.find("scenario:stage:arrival_shift")):
		failures.append("Canvas did not apply deterministic global scenario/base/stage z ordering.")
	var layout_entry := _layout_by_id(_dict(view.get("object_layout", {})), SCENARIO_OBJECT_ID)
	var draw_rect := _rect(_dict(layout_entry.get("rect", {})))
	if draw_rect.size.x < 72.0 or draw_rect.size.y < 48.0:
		failures.append("Scenario visual draw geometry did not preserve the bounded semantic target.")
	elif canvas.object_id_at_local_position(draw_rect.get_center()) != SCENARIO_OBJECT_ID:
		failures.append("Scenario draw geometry and interaction hit geometry are not correlated.")
	var reachable := canvas.keyboard_reachable_object_ids()
	if reachable != [SCENARIO_OBJECT_ID, "travel:leave"]:
		failures.append("Keyboard/controller focus does not preserve authored focus_order or excludes the wrong room objects: %s" % JSON.stringify(reachable))
	if not canvas._cycle_interactive_object(1) or str(canvas.current_view_snapshot().get("selected_object_id", "")) != SCENARIO_OBJECT_ID:
		failures.append("Keyboard/controller room-object cycling cannot reach the first scenario interaction.")
	var capture := ActivationCapture.new()
	canvas.object_activated.connect(capture.record)
	var authored_event := InputEventAction.new()
	authored_event.action = "ui_down"
	authored_event.pressed = true
	canvas._gui_input(authored_event)
	if capture.object_id != "scenario_action:7:scenario:console%3Anight:refuse":
		failures.append("Authored controller input did not take precedence over room/action navigation.")

	canvas.set_small_screen_mode(true)
	var small_view := _dict(canvas.current_view_snapshot())
	var small_entry := _layout_by_id(_dict(small_view.get("object_layout", {})), SCENARIO_OBJECT_ID)
	var small_rect := _rect(_dict(small_entry.get("rect", {})))
	if small_rect.size.x < 104.0 or small_rect.size.y < 76.0:
		failures.append("Canvas did not apply authored small-screen draw geometry.")
	elif canvas.object_id_at_local_position(small_rect.get_center()) != SCENARIO_OBJECT_ID:
		failures.append("Small-screen scenario draw and hit geometry diverged.")
	root.remove_child(canvas)
	canvas.free()


static func _check_small_screen_expansion(failures: Array) -> void:
	var semantic := {
		"scene_objects": {"scenario::edge_exit": {
			"owner_namespace": "scenario", "stable_object_id": "edge_exit", "label": "Edge exit",
			"role": "exit", "anchor_id": "layout:game:0", "bounds": {"w": 16.0, "h": 16.0},
			"visible": true, "enabled": true,
		}},
		"interactions": {"scenario::edge_exit": {
			"owner_namespace": "scenario", "stable_object_id": "edge_exit", "mode": "add",
			"label": "Edge exit", "state_label": "Open", "prompt": "Leave through the edge exit.",
			"enabled": true, "disabled_reason": "", "available_actions": [{"id": "leave", "label": "Leave", "input_action": "ui_accept", "non_color_state": "ready"}],
			"input_actions": ["ui_accept"], "non_color_state": "open", "focus_order": 1,
			"hit_bounds": {"w": 44.0, "h": 44.0}, "min_target_size": 44.0, "safe_exit": true, "alternate_exit": false,
		}},
	}
	var prepared := ScenarioLayoutResolverScript.prepare({"layout": {"game_spots": [{"x": 890.0, "y": 420.0}]}}, {"scenario_id": "small_screen_fixture", "phase_id": "arrival", "status": "active", "semantic_state": semantic})
	if not bool(prepared.get("ok", false)):
		failures.append("Small-screen layout fixture failed resolution: %s" % JSON.stringify(prepared.get("errors", [])))
		return
	var visual := _dict(_array(prepared.get("visual_objects", []))[0])
	var normal_rect := _rect(_dict(visual.get("normalized_rect", {})))
	var expanded_rect := _rect(_dict(visual.get("small_screen_rect", {})))
	normal_rect = Rect2(normal_rect.position * BOARD_SIZE, normal_rect.size * BOARD_SIZE)
	expanded_rect = Rect2(expanded_rect.position * BOARD_SIZE, expanded_rect.size * BOARD_SIZE)
	if normal_rect.size.x >= 104.0 or normal_rect.size.y >= 76.0:
		failures.append("Small-screen fixture did not begin with an undersized semantic visual.")
	if expanded_rect.size.x < 104.0 or expanded_rect.size.y < 76.0 or not is_equal_approx(expanded_rect.end.x, BOARD_SIZE.x) or not is_equal_approx(expanded_rect.end.y, BOARD_SIZE.y):
		failures.append("Small-screen resolver did not expand and clamp the undersized edge target.")
	var composed := ScenarioSemanticViewModelScript.compose([], prepared, {})
	if not bool(composed.get("ok", false)):
		failures.append("Small-screen resolved presentation did not compose: %s" % JSON.stringify(composed.get("errors", [])))
		return
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({"id": "small_screen_fixture", "archetype_id": "bar", "interactable_objects": _array(composed.get("records", [])), "scenario_render_snapshot": prepared})
	canvas.set_small_screen_mode(true)
	var entry := _layout_by_id(_dict(canvas.current_view_snapshot().get("object_layout", {})), "scenario:scenario:edge_exit")
	var consumed_rect := _rect(_dict(entry.get("rect", {})))
	if consumed_rect.size.x < 104.0 or consumed_rect.size.y < 76.0 or canvas.object_id_at_local_position(consumed_rect.get_center()) != "scenario:scenario:edge_exit":
		failures.append("Canvas did not consume the resolver's expanded/clamped small-screen hit geometry.")
	canvas.free()


static func _check_fail_closed_presentation(failures: Array) -> void:
	var disabled_base := _base_record()
	disabled_base["enabled"] = false
	disabled_base["disabled_reason"] = "Route unavailable."
	var augment_prepared := {
		"ok": true, "errors": [], "boundary_serial": 7, "visual_objects": [], "active_stages": [],
		"interaction_overlays": [{
			"owner_namespace": "scenario", "stable_object_id": "route_augment", "mode": "augment",
			"target_owner_namespace": "travel", "target_stable_object_id": "travel:leave",
			"available_actions": [{"id": "shortcut", "label": "Take shortcut", "input_action": "ui_accept", "non_color_state": "ready"}],
		}],
	}
	var disabled_composed := ScenarioSemanticViewModelScript.compose([disabled_base], augment_prepared, {})
	var disabled_token := "scenario_action:7:scenario:route_augment:shortcut"
	if not ScenarioSemanticViewModelScript.action_descriptor_for_token(_array(disabled_composed.get("records", [])), disabled_token).is_empty():
		failures.append("Disabled host interaction exposed a directly routable augmented scenario action.")

	var invalid_prepared := {
		"ok": false,
		"errors": ["fixture renderer rejected"],
		"visual_objects": [{
			"object_id": "scenario:scenario:leaked",
			"object_type": "scenario_object",
			"visual_type": "scenario_object",
			"label": "Leaked visual",
			"normalized_rect": {"x": 0.4, "y": 0.4, "w": 0.1, "h": 0.1},
		}],
	}
	var composed := ScenarioSemanticViewModelScript.compose([_base_record()], invalid_prepared, {})
	var records := _array(composed.get("records", []))
	var error_record := _record_by_id(records, "scenario:presentation_error")
	if bool(composed.get("ok", true)) or error_record.is_empty() or bool(error_record.get("interactive", true)):
		failures.append("Invalid scenario presentation did not fail closed with a noninteractive player-readable error.")
	if PixelSceneCanvasScript.should_draw_hotspot_hint(error_record, false):
		failures.append("Noninteractive scenario error records still advertise an interaction hotspot.")
	if PixelSceneCanvasScript.should_draw_hotspot_hint({"interactive": false, "disabled": false}, false):
		failures.append("Decorative scenario staging still advertises an interaction hotspot.")

	var canvas = PixelSceneCanvasScript.new()
	canvas.size = BOARD_SIZE
	canvas.render_environment_snapshot({
		"id": "failed_presentation_fixture",
		"archetype_id": "bar",
		"interactable_objects": records,
		"scenario_render_snapshot": invalid_prepared,
	})
	var objects := _array(canvas.current_view_snapshot().get("objects", []))
	if _object_ids(objects).has("scenario:scenario:leaked"):
		failures.append("Canvas leaked scenario visuals from an invalid renderer snapshot.")
	if canvas.keyboard_reachable_object_ids().has("scenario:presentation_error"):
		failures.append("Fail-closed scenario presentation error became keyboard/controller actionable.")
	canvas.free()


static func _check_competing_augment_presentation(failures: Array) -> void:
	var overlays: Array = []
	for owner in ["event", "sweep", "scenario"]:
		overlays.append({
			"owner_namespace": owner,
			"stable_object_id": "%s_route_augment" % owner,
			"mode": "augment",
			"target_owner_namespace": "traveler",
			"target_stable_object_id": "travel:leave",
			"available_actions": [{
				"id": "%s_shortcut" % owner,
				"label": "%s shortcut" % owner.capitalize(),
				"input_action": "ui_accept",
				"non_color_state": "ready",
			}],
		})
	var prepared := {
		"ok": true, "errors": [], "boundary_serial": 7,
		"visual_objects": [], "active_stages": [], "interaction_overlays": overlays,
	}
	var composed := ScenarioSemanticViewModelScript.compose([_base_record()], prepared, {})
	var record := _record_by_id(_array(composed.get("records", [])), "travel:leave")
	var public_text := JSON.stringify(record)
	if bool(composed.get("ok", true)) or record.is_empty():
		failures.append("Competing augment presentation did not fail closed around its retained winner.")
		return
	for forbidden_action in ["event_shortcut", "scenario_shortcut"]:
		if public_text.contains(forbidden_action):
			failures.append("Rejected lower-priority augment leaked into public action surfaces: %s." % forbidden_action)
		var token := "scenario_action:7:%s:%s_route_augment:%s" % [forbidden_action.trim_suffix("_shortcut"), forbidden_action.trim_suffix("_shortcut"), forbidden_action]
		if not ScenarioSemanticViewModelScript.action_descriptor_for_token([record], token).is_empty():
			failures.append("Rejected lower-priority augment retained a routable action token: %s." % forbidden_action)
	var augmented_ids: Array = []
	for action_value in _array(record.get("scenario_augmented_actions", [])):
		augmented_ids.append(str(_dict(action_value).get("id", "")))
	var augmented_inline_ids: Array = []
	for action_value in _array(record.get("scenario_augmented_inline_actions", [])):
		augmented_inline_ids.append(str(_dict(action_value).get("id", "")))
	var inline_ids: Array = []
	for action_value in _array(record.get("inline_actions", [])):
		inline_ids.append(str(_dict(action_value).get("id", "")))
	if augmented_ids != ["sweep_shortcut"] or augmented_inline_ids != ["sweep_shortcut"] or inline_ids != ["sweep_shortcut"]:
		failures.append("Winning sweep augment did not exclusively own available/inline public actions.")
	var sweep_token := "scenario_action:7:sweep:sweep_route_augment:sweep_shortcut"
	if ScenarioSemanticViewModelScript.action_descriptor_for_token([record], sweep_token).is_empty():
		failures.append("Accepted sweep augment lost its routable action token.")
	for private_key in ["accepted_overlay_source_identities", "effective_priority", "effective_owner_namespace", "effective_winner", "source_key"]:
		if public_text.contains(private_key):
			failures.append("Composed interaction leaked reducer-private overlay metadata %s." % private_key)

	var collision_overlay := {
		"owner_namespace": "sweep", "stable_object_id": "collision_augment", "mode": "augment",
		"target_owner_namespace": "traveler", "target_stable_object_id": "travel:leave",
		"available_actions": [
			{"id": "activate", "label": "Colliding activate", "input_action": "ui_accept", "non_color_state": "ready"},
			{"id": "sweep_unique", "label": "Sweep unique", "input_action": "ui_accept", "non_color_state": "ready"},
		],
	}
	var collision_prepared := prepared.duplicate(true)
	collision_prepared["interaction_overlays"] = [collision_overlay]
	var collision_composed := ScenarioSemanticViewModelScript.compose([_base_record()], collision_prepared, {})
	var collision_record := _record_by_id(_array(collision_composed.get("records", [])), "travel:leave")
	var collision_text := JSON.stringify(collision_record)
	if bool(collision_composed.get("ok", true)) \
		or collision_text.contains("sweep_unique") \
		or not _array(collision_record.get("scenario_augmented_actions", [])).is_empty() \
		or not _array(collision_record.get("scenario_augmented_inline_actions", [])).is_empty() \
		or not _array(collision_record.get("inline_actions", [])).is_empty() \
		or not ScenarioSemanticViewModelScript.action_descriptor_for_token([collision_record], "scenario_action:7:sweep:collision_augment:sweep_unique").is_empty():
		failures.append("Base activate collision leaked part of a rejected augment into public/token surfaces.")

	var equal_a := {
		"owner_namespace": "scenario", "stable_object_id": "a_equal_augment", "mode": "augment",
		"target_owner_namespace": "traveler", "target_stable_object_id": "travel:leave",
		"available_actions": [{"id": "duplicate_action", "label": "A duplicate", "input_action": "ui_accept", "non_color_state": "ready"}],
	}
	var equal_z := equal_a.duplicate(true)
	equal_z["stable_object_id"] = "z_equal_augment"
	equal_z["available_actions"] = [{"id": "duplicate_action", "label": "Z duplicate", "input_action": "ui_accept", "non_color_state": "ready"}]
	var equal_forward_prepared := prepared.duplicate(true)
	equal_forward_prepared["interaction_overlays"] = [equal_z, equal_a]
	var equal_reverse_prepared := prepared.duplicate(true)
	equal_reverse_prepared["interaction_overlays"] = [equal_a, equal_z]
	var equal_forward := ScenarioSemanticViewModelScript.compose([_base_record()], equal_forward_prepared, {})
	var equal_reverse := ScenarioSemanticViewModelScript.compose([_base_record()], equal_reverse_prepared, {})
	var equal_record := _record_by_id(_array(equal_forward.get("records", [])), "travel:leave")
	var a_token := "scenario_action:7:scenario:a_equal_augment:duplicate_action"
	var z_token := "scenario_action:7:scenario:z_equal_augment:duplicate_action"
	if JSON.stringify(equal_forward) != JSON.stringify(equal_reverse) \
		or bool(equal_forward.get("ok", true)) \
		or _array(equal_record.get("scenario_augmented_actions", [])).size() != 1 \
		or _array(equal_record.get("scenario_augmented_inline_actions", [])).size() != 1 \
		or _array(equal_record.get("inline_actions", [])).size() != 1 \
		or ScenarioSemanticViewModelScript.action_descriptor_for_token([equal_record], a_token).is_empty() \
		or not ScenarioSemanticViewModelScript.action_descriptor_for_token([equal_record], z_token).is_empty():
		failures.append("Same-priority duplicate augment did not preserve one deterministic inline/token winner.")


static func _prepared_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"scenario_id": "presentation_fixture",
		"phase_id": "arrival",
		"status": "active",
		"boundary_serial": 7,
		"ok": true,
		"errors": [],
		"warnings": [],
		"interaction_overlays": [{
			"owner_namespace": "scenario",
			"stable_object_id": "console:night",
			"mode": "add",
			"label": "Brace console",
			"state_label": "Exit lane exposed",
			"prompt": "Choose how to brace the lane.",
			"enabled": true,
			"disabled_reason": "",
			"available_actions": [
				{"id": "brace:exit", "label": "Brace exit", "input_action": "confirm", "non_color_state": "ready"},
				{"id": "refuse", "label": "Refuse", "input_action": "ui_down", "non_color_state": "choice"},
			],
			"input_actions": ["confirm", "ui_down"],
			"non_color_state": "ready",
			"focus_order": 1,
			"hit_bounds": {"w": 60.0, "h": 52.0},
			"min_target_size": 44.0,
			"safe_exit": true,
			"alternate_exit": false,
		}],
		"visual_objects": [{
			"object_id": SCENARIO_OBJECT_ID,
			"object_type": "scenario_object",
			"visual_type": "scenario_object",
			"source_id": "console:night",
			"label": "Brace console",
			"short_description": "A braced service console changes the exit lane.",
			"presence": "scenario",
			"interactive": false,
			"decorative": true,
			"enabled": true,
			"visible": true,
			"normalized_rect": {"x": 0.18, "y": 0.38, "w": 0.08, "h": 0.12},
			"focus_rect": {"x": 0.18, "y": 0.38, "w": 0.08, "h": 0.12},
			"small_screen_rect": {"x": 0.14, "y": 0.34, "w": 0.16, "h": 0.20},
			"owner_namespace": "scenario",
			"stable_object_id": "console:night",
			"semantic_identity": "scenario::console:night",
			"role": "obstacle",
			"state": "braced",
			"appearance": "striped",
			"non_color_state": "braced; striped",
			"z_order": 120,
		}],
		"services": [],
		"games": [],
		"routes": [],
		"active_stages": [{"stage_id": "arrival_shift", "message": "The console slides into place."}],
	}


static func _base_record() -> Dictionary:
	return {
		"object_id": "travel:leave",
		"object_type": "travel",
		"visual_type": "travel",
		"source_id": "leave",
		"label": "Leave",
		"short_description": "The marked exit remains clear.",
		"identity_summary": "Exit",
		"interactive": true,
		"decorative": false,
		"enabled": true,
		"normalized_rect": {"x": 0.76, "y": 0.68, "w": 0.14, "h": 0.15},
		"focus_rect": {"x": 0.76, "y": 0.68, "w": 0.14, "h": 0.15},
		"action_summary": "Leave through the marked door.",
		"available_actions": [{"id": "confirm_travel", "label": "Travel"}],
		"inline_actions": [],
		"confirm_action_id": "confirm_travel",
		"safe_exit": true,
		"alternate_exit": false,
		"focus_order": 20,
	}


static func _record_by_id(records: Array, object_id: String) -> Dictionary:
	for record_value in records:
		var record := _dict(record_value)
		if str(record.get("object_id", record.get("id", ""))) == object_id:
			return record
	return {}


static func _layout_by_id(layout: Dictionary, object_id: String) -> Dictionary:
	for entry_value in _array(layout.get("objects", [])):
		var entry := _dict(entry_value)
		if str(entry.get("id", "")) == object_id:
			return entry
	return {}


static func _object_ids(objects: Array) -> Array:
	var ids: Array = []
	for object_value in objects:
		ids.append(str(_dict(object_value).get("id", "")))
	return ids


static func _rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("w", 0.0)), float(value.get("h", 0.0)))


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
