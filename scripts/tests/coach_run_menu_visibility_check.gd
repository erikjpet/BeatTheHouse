extends SceneTree

# Synthetic host/real coach/menu geometry and GUI routing. The Save callback is
# replaced by a counter; this does not qualify save persistence or resident QA.
const Coach := preload("res://scripts/ui/coach_overlay.gd")
const Talk := preload("res://scripts/ui/talk_dock.gd")

class MenuOnly:
	extends "res://scripts/ui/foundation_main.gd"
	var saves := 0

	func _ready() -> void:
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)

	func _refresh_run_menu() -> void:
		run_menu_status_label.text = "Apartment | Cash 80 | Heat 0\nSynthetic menu interaction check"
		run_menu_save_button.disabled = false

	func _refresh() -> void:
		pass

	func _refresh_talk_dock() -> void:
		_sync_coach_panel_for_talk_dock()

	func _guard_blocking_decision_or_transition() -> bool:
		return false

	func _stop_surface_feature_music() -> void:
		pass

	func save_run_from_menu() -> void:
		saves += 1
		_hide_run_menu()


var checks := 0
var failures: Array[String] = []
var cases: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(390, 844)]:
		await _check_viewport(viewport_size)
	print("COACH_RUN_MENU_VISIBILITY_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "save_persistence_verified": false, "physical_mobile_touch_verified": false}))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	root.add_child(viewport)
	var host := MenuOnly.new()
	host.size = Vector2(viewport_size)
	host.current_screen = host.SCREEN_ENVIRONMENT
	viewport.add_child(host)
	host.coach_overlay = Coach.new()
	host.add_child(host.coach_overlay)
	host.coach_overlay.set_lessons([{
		"id": "map_followup_fixture", "scope": "tutorial_run",
		"trigger": {"screen": "ENVIRONMENT"},
		"anchor": {"kind": "hud_element", "id": "map"},
		"copy": "Take the bus to the Gas Station, then look at the tickets.",
		"completion": {"type": "anchored_action", "action_id": "map"},
	}])
	host.coach_overlay.evaluate_at_boundary({"screen": "ENVIRONMENT", "run": {"tutorial": true}, "viewport_rect": Rect2(Vector2.ZERO, Vector2(viewport_size)), "anchor_rects": {}})
	host.call("_build_run_menu_overlay")
	host.talk_dock = Talk.new()
	host.add_child(host.talk_dock)
	var completed: Array = []
	host.coach_overlay.lesson_completed.connect(func(lesson_id: String) -> void: completed.append(lesson_id))
	await _settle()
	var coach: Coach = host.coach_overlay
	_check(coach.panel.is_visible_in_tree(), "Fixture must show the pending lesson before opening Run Menu.")
	_check(coach.active_lesson_id() == "map_followup_fixture", "The valid Environment Map lesson must actually be active before menu input.")
	if not coach.panel.is_visible_in_tree() or coach.active_lesson_id() != "map_followup_fixture":
		viewport.queue_free()
		await process_frame
		return
	var lesson_before: Dictionary = coach.active_lesson.duplicate(true)
	var seen_before: Dictionary = coach.seen.duplicate(true)
	var bubble: Rect2 = coach.panel.get_global_rect()
	host.open_run_menu()
	await _settle()
	host.call("_layout_run_menu_panel")
	await _settle()
	var save := host.run_menu_save_button
	_check(bubble.intersects(host.run_menu_panel.get_global_rect()), "Fixture must reproduce the competing centered menu/card geometry.")
	_check(not coach.panel.is_visible_in_tree() and not coach.focus_layer.is_visible_in_tree(), "Run Menu must suppress both coach card and world focus.")
	_check(coach.active_lesson == lesson_before and coach.seen == seen_before and completed.is_empty(), "Opening Run Menu must not dismiss or complete the lesson.")
	# TalkDock refreshes can happen after open_run_menu; they must retain the
	# menu's suppression even when no natural conversation is active.
	host.call("_sync_coach_panel_for_talk_dock")
	_check(not coach.panel.visible, "TalkDock refresh uncovered the Run Menu.")
	var save_rect := save.get_global_rect()
	var save_exposed := save.is_visible_in_tree() and not save.disabled \
		and host.run_menu_scroll.get_global_rect().encloses(save_rect) \
		and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(save_rect)
	_check(save_exposed, "Save must be exposed inside its scroll area and viewport before any pointer input.")
	# A failing candidate/baseline must never turn this regression into a forced
	# covered-control click. Stop this case before pointer delivery instead.
	if coach.panel.is_visible_in_tree() or not save_exposed:
		host.close_run_menu()
		viewport.queue_free()
		await process_frame
		return
	await _motion(viewport, save.get_global_rect().get_center())
	var hovered := viewport.gui_get_hovered_control()
	var save_owns_pointer := hovered == save or (hovered != null and save.is_ancestor_of(hovered))
	_check(save_owns_pointer, "GUI hit testing must reach the visible Save control.")
	if not save_owns_pointer:
		host.close_run_menu()
		viewport.queue_free()
		await process_frame
		return
	await _click(viewport, save.get_global_rect().get_center())
	_check(host.saves == 1 and not host.run_menu_overlay.visible, "One visible Save gesture must route exactly once to its callback.")
	_check(coach.panel.visible and coach.active_lesson == lesson_before and completed.is_empty(), "Closing the menu must restore the same unfinished lesson.")
	host.open_run_menu()
	await _settle()
	_check(not coach.panel.is_visible_in_tree(), "Second menu open must also clear the coach card before Resume input.")
	if coach.panel.is_visible_in_tree():
		host.close_run_menu()
		viewport.queue_free()
		await process_frame
		return
	await _click(viewport, host.run_menu_resume_button.get_global_rect().get_center())
	_check(not host.run_menu_overlay.visible and host.saves == 1 and coach.panel.visible, "Resume must restore the lesson without saving or skipping it.")
	# Exercise both suppression owners and both update orders, using only
	# synthetic TalkDock state. No real conversation or tutorial action is run.
	host.talk_dock.entry = {"dialogue_id": "natural_fixture"}
	host.talk_dock.conversation_active = true
	host.call("_sync_coach_panel_for_talk_dock")
	_check(not coach.panel.visible, "Natural-conversation suppression was lost.")
	host.open_run_menu()
	await _settle()
	host.close_run_menu()
	_check(not coach.panel.visible, "Closing Run Menu uncovered an active natural conversation.")
	host.talk_dock.conversation_active = false
	host.call("_sync_coach_panel_for_talk_dock")
	_check(coach.panel.visible, "Ending both owners did not restore the lesson card.")
	host.open_run_menu()
	await _settle()
	host.talk_dock.conversation_active = true
	host.call("_sync_coach_panel_for_talk_dock")
	host.talk_dock.conversation_active = false
	host.call("_sync_coach_panel_for_talk_dock")
	_check(not coach.panel.visible, "Ending a conversation while Run Menu is open must keep its controls clear.")
	host.close_run_menu()
	await _settle()
	host.talk_dock.entry = {"dialogue_id": "tutorial_pal_guidance"}
	host.talk_dock.conversation_active = true
	host.call("_sync_coach_panel_for_talk_dock")
	_check(coach.panel.visible, "The existing Pal dialogue exception must remain readable outside Run Menu.")
	host.talk_dock.conversation_active = false
	host.call("_sync_coach_panel_for_talk_dock")
	_check(coach.active_lesson == lesson_before and coach.seen == seen_before and completed.is_empty(), "Visibility cycles changed tutorial progress.")
	await _settle()
	await _click(viewport, coach.ok_button.get_global_rect().get_center())
	_check(completed == ["map_followup_fixture"] and coach.active_lesson_id().is_empty(), "An explicitly clicked visible Skip tip must retain its authored completion behavior.")
	# Directly cover the one-shot dialogue request guard reached by panel
	# rerenders. This synthetic signal case does not run a story/game action.
	var dialogue_requests: Array[String] = []
	coach.restore_seen({})
	coach.set_lessons([{
		"id": "dialogue_once_fixture", "scope": "tutorial_run",
		"trigger": {"screen": "ENVIRONMENT"}, "anchor": {"kind": "none"},
		"copy": "A pending voiced instruction.", "delivery": "dialogue",
		"dialogue_id": "tutorial_pal_guidance", "dialogue_node": "start",
		"completion": {"type": "explicit_ok"},
	}])
	coach.dialogue_requested.connect(func(lesson_id: String, dialogue_id: String, dialogue_node: String) -> void:
		dialogue_requests.append("%s|%s|%s" % [lesson_id, dialogue_id, dialogue_node]))
	coach.evaluate_at_boundary({"screen": "ENVIRONMENT", "run": {"tutorial": true}, "viewport_rect": Rect2(Vector2.ZERO, Vector2(viewport_size)), "anchor_rects": {}})
	await _settle()
	_check(dialogue_requests.size() == 1 and coach.active_lesson_id() == "dialogue_once_fixture", "A new voiced lesson must request its dialogue exactly once.")
	var voiced_lesson_before: Dictionary = coach.active_lesson.duplicate(true)
	var voiced_seen_before: Dictionary = coach.seen.duplicate(true)
	var completed_before: Array = completed.duplicate()
	host.open_run_menu()
	await _settle()
	_check(dialogue_requests.size() == 1 and not coach.panel.visible and not coach.focus_layer.visible, "Menu suppression must not redispatch an active voiced instruction.")
	host.close_run_menu()
	host.call("_sync_coach_focus_visibility")
	host.call("_sync_coach_panel_for_talk_dock")
	await _settle()
	_check(dialogue_requests.size() == 1 and coach.active_lesson == voiced_lesson_before and coach.seen == voiced_seen_before and completed == completed_before, "Restoration and repeated sync must preserve one dialogue request and unfinished lesson progress.")
	cases.append({"logical_viewport": str(viewport_size), "prior_card_rect": str(bubble), "save_rect": str(save.get_global_rect()), "save_callback_count": host.saves, "dialogue_request_count": dialogue_requests.size()})
	viewport.queue_free()
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame

func _motion(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame

func _click(viewport: Viewport, point: Vector2) -> void:
	await _motion(viewport, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
