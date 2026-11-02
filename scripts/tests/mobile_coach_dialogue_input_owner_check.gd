extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const WholeApp := preload("res://scripts/tests/mobile_viewport_whole_app_check.gd")

# Reuse the qualified native fixture's platform predicate and native-window
# settings substitution. Production Main, CoachOverlay, TalkDock and GUI input
# stay real; this is native evidence, not exported Web or physical-phone proof.
var app: Variant
var observer: Variant
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _settle(frames: int = 12) -> void:
	for _frame in range(frames):
		await process_frame


func _protected(run: RunState) -> PackedByteArray:
	return var_to_bytes([run.bankroll, run.grand_casino_chips, run.suspicion,
		run.rng_state, run.story_log, run.inventory, run.debt, run.crew_jobs,
		run.active_delivery_run, run.current_environment.get("game_states", {})])


func _tap(control: Control, description: String, expected_presses: int = 1) -> bool:
	if not _check(is_instance_valid(control) and control.is_visible_in_tree(), description + " exists and is visible"):
		return false
	var button := control as BaseButton
	if button != null and not _check(not button.disabled, description + " is enabled"):
		return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _settle(6)
	var rect: Rect2 = control.get_global_rect()
	if not _check(root.get_visible_rect().encloses(rect), description + " full hit rectangle fits the actual viewport"):
		return false
	var logical: Vector2 = rect.get_center()
	var physical: Vector2 = root.get_final_transform() * logical
	var count := [0]
	var pressed := func(): count[0] += 1
	if button != null:
		button.pressed.connect(pressed)
	var touch_count: int = observer.touch_positions.size()
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = physical
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _settle(8)
	if is_instance_valid(button):
		button.pressed.disconnect(pressed)
		_check(count[0] == expected_presses, description + " actual connected press count is " + str(expected_presses))
	_check(observer.touch_positions.size() > touch_count and observer.touch_positions.back().distance_to(logical) <= 1.0,
		description + " real touch transforms onto its drawn logical target")
	facts[description] = {"logical": logical, "physical": physical, "presses": count[0]}
	return true


func _coexistence_snapshot() -> Dictionary:
	var coach: Variant = app.coach_overlay
	var dock: Variant = app.talk_dock
	return {"coach_panel": coach.panel.get_global_rect(), "coach_dismiss": coach.ok_button.get_global_rect(),
		"close": dock.collapse_button.get_global_rect(), "dock": dock.panel.get_global_rect(),
		"coach_tree_index": coach.get_index(), "dock_tree_index": dock.get_index(),
		"coach_z": coach.z_index, "dock_z": dock.z_index,
		"coach_mouse_filter": coach.panel.mouse_filter, "lesson": coach.active_lesson_id(),
		"anchor_id": coach.active_anchor_id(), "anchor": coach.active_anchor_rect()}


func _run() -> void:
	var mode := OS.get_environment("BTH31_COACH_CASE")
	var private_root := OS.get_environment("BTH31_PRIVATE_ROOT")
	if not ["375", "390", "375_max", "390_max", "375_order_control", "375_modal"].has(mode) \
			or private_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(private_root + "/"):
		quit(2)
		return
	var maximum := mode.ends_with("_max")
	root.size = Vector2i(375, 667) if mode.begins_with("375") else Vector2i(390, 844)
	Input.use_accumulated_input = false
	observer = WholeApp.Observer.new()
	root.add_child(observer)
	var settings: UserSettings = WholeApp.PhoneSettings.new()
	settings.ui_scale = 1.3 if maximum else 1.0
	settings.text_size = "large" if maximum else "normal"
	settings.play_on_small_screen = maximum
	settings.coach_tips_enabled = true
	_check(settings.save() == OK, "fresh synthetic local settings saved without a profile/key transfer")
	app = MainScene.instantiate()
	app.set_script(WholeApp.App)
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await _settle(16)
	_check(app.get_global_rect().is_equal_approx(root.get_visible_rect()), "authored Main root fills the actual native phone viewport")
	_check(app._ensure_run_ui_built(), "real run UI dependencies build")
	app._ensure_full_content_library_loaded()
	await _settle(12)
	_check(app.new_run_button.text == "PLAY", "fresh profile exposes ordinary Play, not an imported checkpoint")
	if not await _tap(app.new_run_button, "ordinary_Play"):
		_finish(mode)
		return
	await _settle(20)
	var run: RunState = app.run_state
	if not _check(run != null and run.is_tutorial_run(), "ordinary connected Play creates the real guided run"):
		_finish(mode)
		return
	var coach: Variant = app.coach_overlay
	var dock: Variant = app.talk_dock
	_check(dock.visible and dock.conversation_active and app._talk_entry_is_pal_tutorial_dialogue(dock.entry), "initial authored Pal dialogue is active")
	_check(coach.panel.is_visible_in_tree() and not coach.panel_suppressed, "same unfinished coach card coexists visibly without Skip tip")
	_check(coach.active_anchor_kind() == "interactable_object", "real initial lesson anchors an ordinary room object")
	_check(coach.tips_enabled and app.user_settings.coach_tips_enabled, "tutorial/help remains enabled")
	if maximum:
		_check(is_equal_approx(app._accessibility_font_scale(), 1.458), "actual supported maximum font settings are applied")
	var protected_before := _protected(run)
	var lesson: String = coach.active_lesson_id()
	var seen_before: PackedByteArray = var_to_bytes(coach.seen)
	var copy_before: String = coach.copy_label.text
	facts["initial"] = _coexistence_snapshot()
	if mode == "375_order_control":
		# Fault-injection control reproduces the old renderer's exact final tree
		# order without changing any geometry, model, guard or production code.
		coach.move_to_front()
		_check(coach.panel.get_global_rect().intersects(dock.collapse_button.get_global_rect()), "old-order control has the observed coach/Close overlap")
		await _tap(dock.collapse_button, "old_order_Close_control", 0)
		_check(dock.conversation_active, "old-order GUI control reproduces visible but blocked Close")
		_check(_protected(run) == protected_before, "old-order rejected touch has no finance/history/RNG effects")
		var geometry_before: Array = [coach.panel.get_global_rect(), dock.panel.get_global_rect(), dock.collapse_button.get_global_rect()]
		app._sync_coach_panel_for_talk_dock()
		_check(geometry_before == [coach.panel.get_global_rect(), dock.panel.get_global_rect(), dock.collapse_button.get_global_rect()], "production owner correction changes picking order without moving the help or dialogue")
	elif mode == "375_modal":
		await _tap(app.top_menu_button, "coexisting_Menu")
		_check(app.run_menu_overlay.visible and not dock.visible and not coach.panel.visible, "Run Menu retains existing dialogue/coach suppression")
		_check(app.run_menu_overlay.get_index() > dock.get_index(), "Pal correction never promotes hidden dialogue over Run Menu")
		await _tap(app.run_menu_resume_button, "coexisting_Resume")
		_check(dock.visible and coach.panel.is_visible_in_tree() and coach.active_lesson_id() == lesson, "Resume restores the same unfinished coexisting guidance")
		_check(_protected(run) == protected_before, "Menu/Resume has no finance/history/RNG effects")
	_check(dock.get_index() > coach.get_index(), "visible higher-z Pal controls also follow coach in GUI picking order")
	_check(dock.z_index > coach.z_index and coach.panel.mouse_filter == Control.MOUSE_FILTER_STOP, "existing visual order and tutorial panel input semantics stay intact")
	facts["before_Close"] = _coexistence_snapshot()
	if not await _tap(dock.collapse_button, "initial_Pal_Close"):
		_finish(mode)
		return
	_check(not dock.visible and not dock.conversation_active, "one real touch closes Pal without first using Skip tip")
	_check(coach.panel.is_visible_in_tree() and coach.active_lesson_id() == lesson and coach.copy_label.text == copy_before, "Close retains the same visible unfinished coach and its authored instruction")
	_check(var_to_bytes(coach.seen) == seen_before, "Close does not complete or skip the lesson")
	_check(_protected(run) == protected_before, "neutral Close changes no finance/inventory/game/debt/history/RNG")
	var anchor_id: String = coach.active_anchor_id()
	var anchor: Rect2 = app.environment_canvas.global_rect_for_object(anchor_id)
	_check(anchor.has_area() and root.get_visible_rect().encloses(anchor), "original highlighted room target remains drawn inside the viewport")
	var point: Vector2 = root.get_final_transform() * anchor.get_center()
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _settle(16)
	_check(app.environment_canvas.selected_object_id == anchor_id, "real touch still focuses the original lesson anchor after Close")
	_check(_protected(run) == protected_before, "anchor inspection triggers no pickup, reward or financial/game/RNG effect")
	_check(coach.active_lesson_id() == lesson and coach.ok_button.is_visible_in_tree(), "help and its normal dismiss control remain available after anchor focus")
	# Coach's existing _input owns the complete dismiss gesture and directly
	# calls its callback; it deliberately does not forward Button.pressed.
	await _tap(coach.ok_button, "normal_Skip_tip_after_proofs", 0)
	_check(coach.active_lesson_id() != lesson, "existing Skip tip callback still dismisses the lesson when deliberately requested")
	_check(_protected(run) == protected_before, "deliberate help dismissal has no finance/inventory/game/history/RNG effect")
	_finish(mode)


func _finish(mode: String) -> void:
	var result := {"task_id": "BTH-31", "finding": "BTH-31-WEB-375-COACH-DIALOGUE-OVERLAP", "case": mode,
		"checks": checks, "failures": failures, "facts": facts,
		"scope": "Real authored Main and ordinary Play; native phone platform/window fixture only. Connected ScreenTouch input, no pressed.emit, imported state/key or paid action. Not Web proof."}
	var out := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
	print("BTH31_COACH_INPUT ", JSON.stringify(result))
	if is_instance_valid(app):
		root.remove_child(app)
		app.free()
	quit(0 if failures.is_empty() else 1)
