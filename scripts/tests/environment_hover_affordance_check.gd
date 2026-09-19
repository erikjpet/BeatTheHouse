extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var holder := Control.new()
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	var canvas: Control = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900, 400)
	holder.add_child(canvas)
	canvas.call("render_environment_snapshot", {
		"id": "hover_affordance_fixture",
		"display_name": "Hover Affordance Fixture",
		"interactable_objects": [
			{
				"object_id": "event:actionable",
				"object_type": "event",
				"visual_type": "event",
				"source_id": "actionable",
				"label": "Open Invitation",
				"short_description": "Someone waves you over with an offer.",
				"identity_summary": "A live opportunity.",
				"interactive": true,
				"enabled": true,
				"available_actions": [{"id": "inspect_event_choices", "label": "Respond"}],
				"confirm_action_id": "inspect_event_choices",
				"normalized_rect": {"x": 0.10, "y": 0.34, "w": 0.18, "h": 0.22},
			},
			{
				"object_id": "event:view_only",
				"object_type": "event",
				"visual_type": "event",
				"source_id": "view_only",
				"label": "Old Poster",
				"short_description": "A faded notice from last week.",
				"interactive": false,
				"enabled": true,
				"normalized_rect": {"x": 0.62, "y": 0.34, "w": 0.18, "h": 0.22},
			},
		],
	})
	await process_frame

	canvas.call("_set_hovered_object", "event:actionable")
	var active_hover: Dictionary = canvas.call("current_view_snapshot").get("selected_info", {})
	_check(bool(active_hover.get("visible", false)), "Actionable hover did not show a tooltip.")
	_check(not bool(active_hover.get("expanded", true)), "Actionable hover exposed expanded details before focus.")
	_check(bool(active_hover.get("interaction_available", false)), "Actionable hover was not marked interactive.")
	_check(str(active_hover.get("interaction_icon", "")) == "action", "Actionable hover did not expose the action icon.")
	_check(str(active_hover.get("interaction_status", "")) == "Interactive", "Actionable hover status copy is unclear.")
	_check(not bool(active_hover.get("action_available", true)) and (active_hover.get("actions", []) as Array).is_empty(), "Actionable hover exposed controls before focus.")

	var active_rect: Rect2 = canvas.call("global_rect_for_object", "event:actionable")
	var active_local := canvas.get_global_transform().affine_inverse() * active_rect.get_center()
	_check(str(canvas.call("object_id_at_local_position", active_local)) == "event:actionable", "Actionable object was not hover-hittable.")
	canvas.call("_focus_object_at_local_position", active_local)
	var active_focus: Dictionary = canvas.call("current_view_snapshot").get("selected_info", {})
	_check(bool(active_focus.get("expanded", false)), "Clicking the actionable object did not expand its details.")
	_check(bool(active_focus.get("action_available", false)), "Focused actionable object did not expose its action.")

	canvas.call("set_selected_object", "")
	var passive_rect: Rect2 = canvas.call("global_rect_for_object", "event:view_only")
	var passive_local := canvas.get_global_transform().affine_inverse() * passive_rect.get_center()
	_check(str(canvas.call("object_id_at_local_position", passive_local)) == "event:view_only", "View-only object was not hover-hittable.")
	canvas.call("_set_hovered_object", "event:view_only")
	var passive_hover: Dictionary = canvas.call("current_view_snapshot").get("selected_info", {})
	_check(not bool(passive_hover.get("expanded", true)), "View-only hover exposed expanded details before focus.")
	_check(not bool(passive_hover.get("interaction_available", true)), "View-only hover was marked interactive.")
	_check(str(passive_hover.get("interaction_icon", "")) == "view_only", "View-only hover did not expose its distinct icon.")
	_check(str(passive_hover.get("interaction_status", "")) == "View only", "View-only hover status copy is unclear.")
	canvas.call("_focus_object_at_local_position", passive_local)
	var passive_focus: Dictionary = canvas.call("current_view_snapshot").get("selected_info", {})
	_check(bool(passive_focus.get("expanded", false)), "Clicking the view-only object did not expand its details.")
	_check(not bool(passive_focus.get("action_available", true)), "View-only focused object exposed an action.")

	holder.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENVIRONMENT_HOVER_AFFORDANCE_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT_HOVER_AFFORDANCE_CHECK FAIL count=%d" % failures.size())
	quit(1)
