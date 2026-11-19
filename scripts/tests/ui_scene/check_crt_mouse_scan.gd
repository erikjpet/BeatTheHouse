extends "res://tools/crt_v3_showcase.gd"

# Focused real-input CRT mouse/scan acceptance. Run only through the existing
# fresh E: guarded launcher, headed. No game/back/selection method substitutes.
# Two removable, mouse-ignoring gray swatches measure the actual glass shader;
# their center luminance rejects old geometry jitter as animation evidence.
const MOUSE_SCAN_SEED := "CRT-MOUSE-SCAN-061"
const EDITED_SEED := "CRT-MOUSE-061"
const BAND_SECONDS := 9.0
const BAND_INTERVAL := 0.125
var _ending := false
var _moves: Array[String] = []
var _launches: Array[String] = []
var _motion_samples: Array[Dictionary] = []
var _motion_summaries: Array[Dictionary] = []
var _mouse_events: Array[Dictionary] = []
var _probes: Array[ColorRect] = []
var _probe_heights: Array[float] = [0.245, 0.69]


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	if not _guarded_rendered_environment():
		_finish()
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("autosave_slot_id", "crt_mouse_scan_fresh")
	root.add_child(app)
	await _rendered_frames(5)
	if not _require(bool(app.call("start_foundation_run", MOUSE_SCAN_SEED,
			{"modifiers": {"home_archetype_id": "house"}}, false)), "Public generator starts the fresh ordinary Home fixture."):
		return
	await _rendered_frames(5)
	_origin = app.get("run_state") as RunState
	if not _require(_home_origin_ready(), "Actual Home is ready before pointer entry."):
		return
	await _capture("mouse-home-origin.png")
	if not await _enter_tv_by_normal_input():
		_finish()
		return
	menu = app.get("game_test_menu") as Control
	menu.connect("user_selection_changed", _mouse_move_signal)
	menu.connect("launch_accepted", _mouse_launch_signal)
	var counts := _actual_cue_counts()
	await _rendered_frames(12)
	_check(_moves.is_empty() and _launches.is_empty() and _actual_cue_counts() == counts,
		"Stationary pointer on entry creates no incidental move or launch cue.")
	await _capture("mouse-crt-entry.png")
	if not await _hover_exact("pull_tabs") or not await _hover_exact("blackjack"):
		_finish()
		return
	var unchanged := _moves.size()
	await _move_pointer(_hit_point(_game_button("blackjack"), Vector2(0.53, 0.52)))
	_check(_moves.size() == unchanged and _current_game_id().is_empty(), "Within-tile mouse motion does not duplicate selection or launch.")
	var seed := app.get("game_test_seed_input") as LineEdit
	if not await _click_control(seed, "Mouse-focus seed input"):
		_finish()
		return
	await _key_tap(KEY_A, 0, true)
	await _type_text(EDITED_SEED)
	_check(seed.text == EDITED_SEED and _focus_owner() == seed, "Mouse-focused seed accepts ordinary text entry without game navigation.")
	if not await _click_control(menu.get("generation_button") as Control, "Mouse Setup"):
		_finish()
		return
	var before_popup := _moves.size()
	await _move_pointer(_hit_point(_game_button("baccarat")))
	_check(bool(menu.call("is_generation_open")) and _moves.size() == before_popup and _current_game_id().is_empty(),
		"The visible Setup panel prevents hover selection/launch through the panel.")
	if not await _click_control(menu.find_child("SetupDone", true, false) as Control, "Mouse Done"):
		_finish()
		return
	if not await _hover_exact("scratch_tickets") or not await _click_control(_game_button("scratch_tickets"), "Mouse launch Scratch"):
		_finish()
		return
	await _rendered_frames(4)
	if not _require(_current_game_id() == "scratch_tickets" and _launches == ["scratch_tickets"], "A real mouse click launches Scratch exactly once."):
		return
	await _capture("mouse-scratch-game.png")
	if not await _buy_one_ticket_by_normal_input():
		_finish()
		return
	await create_timer(1.0).timeout
	var before_leave := _moves.size()
	if not await _leave_real_mouse("paid-scratch"):
		_finish()
		return
	_check(seed.text == EDITED_SEED and str(menu.get("selected_game_id")) == "scratch_tickets" and _moves.size() == before_leave,
		"Mouse Leave restores retained seed/selection silently.")
	if not await _hover_exact("baccarat"):
		_finish()
		return
	if not await _click_control(menu.get("exit_button") as Control, "Mouse Exit TV"):
		_finish()
		return
	await _rendered_frames(3)
	_check(_home_origin_ready() and app.get("run_state") == _origin, "The complete mouse Home-TV-game-Leave-CRT-Exit flow restores Home.")
	await _capture("mouse-home-restored.png")
	# A separate compact preservation pass covers the within-already-hovered bug.
	if not await _enter_tv_by_normal_input():
		_finish()
		return
	if not await _hover_exact("pull_tabs"):
		_finish()
		return
	await _key_tap(KEY_RIGHT)
	_check(str(menu.get("selected_game_id")) == "slot", "Keyboard Right still changes the highlighted game.")
	var before_rehover := _moves.size()
	await _move_pointer(_hit_point(_game_button("pull_tabs"), Vector2(0.54, 0.52)))
	_check(str(menu.get("selected_game_id")) == "pull_tabs" and _moves.size() == before_rehover + 1,
		"Motion inside the already-hovered tile restores that tile exactly once after keyboard navigation.")
	await _joy_tap(JOY_BUTTON_DPAD_DOWN)
	_check(str(menu.get("selected_game_id")) == "baccarat", "Controller Down still changes the highlighted game.")
	await _move_pointer(_hit_point(_game_button("scratch_tickets")))
	var launch_before_touch := _launches.size()
	await _touch_cancel(_hit_point(_game_button("scratch_tickets")))
	_check(_launches.size() == launch_before_touch and _current_game_id().is_empty(), "Cancelled touch does not launch.")
	await _touch_tap(_hit_point(_game_button("scratch_tickets")))
	await _rendered_frames(3)
	if not _require(_current_game_id() == "scratch_tickets" and _launches.size() == launch_before_touch + 1, "Ordinary accepted touch still launches exactly once."):
		return
	if not await _leave_real_mouse("touch-preservation-return"):
		_finish()
		return
	await _move_pointer(Vector2(4, 4))
	await _capture("scan-normal-context.png")
	_add_gray_probes()
	await _rendered_frames(3)
	await _measure_glass(false)
	var settings: Variant = app.get("user_settings")
	var prior_reduce := bool(settings.reduce_motion)
	settings.reduce_motion = true
	app.call("_apply_accessibility_settings")
	await _rendered_frames(4)
	await _measure_glass(true)
	settings.reduce_motion = prior_reduce
	app.call("_apply_accessibility_settings")
	for probe in _probes:
		probe.queue_free()
	_probes.clear()
	await _rendered_frames(3)
	await _capture("scan-final-normal-context.png")
	_check(_actual_cue_counts().get("crt_move", -1) == _moves.size() and _actual_cue_counts().get("crt_select", -1) == _launches.size(),
		"Actual SFX surface requests match semantic move and accepted-launch counts, with no duplicate hover/focus requests.")
	if not await _click_control(menu.get("exit_button") as Control, "Final mouse Exit TV"):
		_finish()
		return
	await _rendered_frames(2)
	_check(_home_origin_ready() and app.get("run_state") == _origin, "Final mouse Exit returns to the same Home origin.")
	_finish()


func _hover_exact(game_id: String) -> bool:
	var before := _moves.size()
	var changed := str(menu.get("selected_game_id")) != game_id
	var button := _game_button(game_id)
	await _move_pointer(_hit_point(button))
	var owner: Control = menu.call("get_display_hovered_control")
	var valid := owner == button or owner != null and button.is_ancestor_of(owner)
	return _check_contract(valid and str(menu.get("selected_game_id")) == game_id and _moves.size() == before + int(changed) and _current_game_id().is_empty(),
		"Real hover highlights %s once per changed ID and never launches." % game_id)


func _leave_real_mouse(label: String) -> bool:
	var surface := app.get("game_surface_canvas") as Control
	if not _check_contract(surface != null, label + ": actual game canvas is present."):
		return false
	var rect: Rect2 = surface.call("global_rect_for_surface_action", "surface_back", -1)
	if not _check_contract(rect.has_area(), label + ": real Leave hit rect exists."):
		return false
	await _move_pointer(rect.get_center())
	rect = surface.call("global_rect_for_surface_action", "surface_back", -1)
	_mouse_events.append(_leave_snapshot(label + "-before", rect.get_center(), rect))
	await _capture("mouse-leave-%s-before.png" % label)
	await _mouse_tap(rect.get_center())
	for _frame in range(240):
		if str(app.get("current_screen")) == "CRT" and app.get("current_game") == null and menu.is_visible_in_tree():
			await _rendered_frames(3)
			_mouse_events.append(_leave_snapshot(label + "-after", rect.get_center(), rect))
			await _capture("mouse-leave-%s-after.png" % label)
			return _check_contract(true, label + ": real mouse press/release Leave returns to CRT.")
		await _rendered_frames(1)
	_mouse_events.append(_leave_snapshot(label + "-failed", rect.get_center(), rect))
	await _capture("mouse-leave-%s-failed.png" % label)
	_check(false, label + ": real mouse Leave failed; event/hit/guard evidence retained. No touch or direct fallback used.")
	return false


func _leave_snapshot(label: String, point: Vector2, rect: Rect2) -> Dictionary:
	var hovered := root.gui_get_hovered_control()
	var focus := root.gui_get_focus_owner()
	return {"label": label, "device": "InputEventMouseButton native real-event path", "button": MOUSE_BUTTON_LEFT,
		"position": _point_data(point), "root_mouse": _point_data(root.get_mouse_position()), "hit_rect": _rect_data(rect),
		"hover_owner": str(hovered.get_path()) if hovered != null else "", "focus_owner": str(focus.get_path()) if focus != null else "",
		"screen": str(app.get("current_screen")), "game_id": _current_game_id(),
		"host_guards": _guard_values(app), "game_guards": _guard_values(app.get("current_game"))}


func _guard_values(object: Object) -> Dictionary:
	var result := {}
	if object == null: return result
	for property in object.get_property_list():
		var name := str(property.get("name", ""))
		if not (name.contains("settle") or name.contains("pending") or name.contains("terminal") or name.contains("decision") or name.contains("phase")):
			continue
		var value: Variant = object.get(name)
		if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: result[name] = value
	return result


func _touch_cancel(point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0; touch.position = point; touch.pressed = true
	Input.parse_input_event(touch)
	await _rendered_frames(2)
	var drag := InputEventScreenDrag.new()
	drag.index = 0; drag.position = Vector2(4, 4); drag.relative = drag.position - point
	Input.parse_input_event(drag)
	await _rendered_frames(2)
	touch = touch.duplicate(); touch.position = Vector2(4, 4); touch.pressed = false
	Input.parse_input_event(touch)
	await _rendered_frames(2)


func _actual_cue_counts() -> Dictionary:
	var result := {"crt_move": 0, "crt_select": 0}
	var player: Node = app.get("environment_sfx_player")
	if player == null: return result
	var trace: Array = player.get("_surface_selection_trace")
	for item in trace:
		var event_id := str(item.get("event_id", item.get("event_class", "")))
		if result.has(event_id): result[event_id] += 1
	return result


func _mouse_move_signal(game_id: String) -> void:
	_moves.append(game_id)


func _mouse_launch_signal(game_id: String) -> void:
	_launches.append(game_id)


func _add_gray_probes() -> void:
	var viewport: SubViewport = menu.call("get_display_viewport")
	var content := viewport.get_child(0) as Control
	for height in _probe_heights:
		var probe := ColorRect.new()
		probe.name = "QaOnlyGrayReference_%d" % _probes.size()
		probe.color = Color(0.65, 0.65, 0.65, 1.0)
		probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		probe.position = Vector2(610, height * 576.0 - 24.0)
		probe.size = Vector2(110, 48)
		content.add_child(probe)
		_probes.append(probe)


func _measure_glass(reduced: bool) -> void:
	var material: ShaderMaterial = menu.call("get_shader_material")
	var label := "reduced" if reduced else "moving"
	var expected_selection := str(menu.get("selected_game_id"))
	var pointer := root.get_mouse_position()
	var expected_moves := _moves.size()
	var rows: Array[Dictionary] = []
	var start := Time.get_ticks_msec()
	var next_capture := 0.0
	var first_glass: PackedByteArray
	var glass_static := true
	while true:
		await _rendered_frames(1)
		var elapsed := float(Time.get_ticks_msec() - start) / 1000.0
		var image := root.get_texture().get_image()
		var phase := float(material.get_shader_parameter("roll_phase"))
		var row := {"mode": label, "seconds": elapsed, "roll_phase": phase, "scan_phase": float(material.get_shader_parameter("scan_phase")),
			"jitter": material.get_shader_parameter("jitter"), "selection": str(menu.get("selected_game_id")), "pointer": _point_data(root.get_mouse_position()), "heights": []}
		for index in range(_probes.size()):
			row["heights"].append({"source_y": _probe_heights[index], "luminance": _gray_luminance(image, _probes[index]),
				"expected_roll": _roll_multiplier(_probe_heights[index], phase, reduced)})
		rows.append(row)
		if elapsed >= next_capture and next_capture <= 8.0:
			await _capture("scan-%s-%02d.png" % [label, int(next_capture)])
			var glass := menu.find_child("CrtDisplayTexture", true, false) as Control
			var crop := image.get_region(Rect2i(glass.get_global_rect())).get_data()
			if first_glass.is_empty(): first_glass = crop
			elif first_glass != crop: glass_static = false
			next_capture += 2.0
		if elapsed >= BAND_SECONDS: break
		await create_timer(BAND_INTERVAL).timeout
	var summary := {"mode": label, "samples": rows.size(), "seconds": rows[-1]["seconds"], "glass_static": glass_static, "heights": []}
	for index in range(_probes.size()):
		var values: Array[float] = []
		var expected: Array[float] = []
		for row in rows:
			values.append(float(row["heights"][index]["luminance"]))
			expected.append(float(row["heights"][index]["expected_roll"]))
		var low: float = values.min(); var high: float = values.max(); var mean := 0.0
		for value in values: mean += value / float(values.size())
		var contrast := (high - low) / maxf(0.001, mean)
		var correlation := _correlation(values, expected)
		var fact := {"source_y": _probe_heights[index], "minimum": low, "maximum": high, "mean": mean, "relative_contrast": contrast, "roll_correlation": correlation}
		summary["heights"].append(fact)
		if reduced:
			_check(contrast <= 0.0015, "Reduce Motion leaves actual gray luminance static at source height %.3f." % _probe_heights[index])
		else:
			_check(contrast >= 0.008 and correlation >= 0.65, "Actual luminance follows the broad moving band at source height %.3f (contrast %.5f, correlation %.4f)." % [_probe_heights[index], contrast, correlation])
	_check(str(menu.get("selected_game_id")) == expected_selection and _moves.size() == expected_moves and root.get_mouse_position().is_equal_approx(pointer),
		label + ": pointer and selection remain unchanged across the nine-second measurement.")
	if reduced:
		_check(glass_static and bool(material.get_shader_parameter("reduce_motion")) and is_zero_approx(float(material.get_shader_parameter("scan_phase"))) and is_zero_approx(float(material.get_shader_parameter("roll_phase"))),
			"Reduce Motion leaves the actual rendered glass and both luminance phases static.")
	_motion_samples.append_array(rows)
	_motion_summaries.append(summary)


func _gray_luminance(image: Image, probe: Control) -> float:
	var total := 0.0
	var count := 0
	# Interior fixed-source samples cancel content/geometry jitter and average an
	# odd 33-source-pixel scanline interval; broad roll remains measurable.
	for yi in range(33):
		for xi in range(7):
			var normalized := Vector2((31.0 + float(xi) * 8.0) / 110.0, (8.0 + float(yi)) / 48.0)
			var point := _hit_point(probe, normalized)
			var color := image.get_pixel(clampi(int(round(point.x)), 0, image.get_width() - 1), clampi(int(round(point.y)), 0, image.get_height() - 1))
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			count += 1
	return total / float(maxi(1, count))


func _roll_multiplier(height: float, phase: float, reduced: bool) -> float:
	if reduced: return 1.0
	var distance := absf(fposmod(height - phase + 0.5, 1.0) - 0.5)
	var t := clampf(distance / 0.16, 0.0, 1.0)
	return 1.0 - 0.035 * (1.0 - t * t * (3.0 - 2.0 * t))


func _correlation(left: Array[float], right: Array[float]) -> float:
	var lm := 0.0; var rm := 0.0
	for i in range(left.size()):
		lm += left[i] / float(left.size()); rm += right[i] / float(right.size())
	var covariance := 0.0; var lv := 0.0; var rv := 0.0
	for i in range(left.size()):
		var a := left[i] - lm; var b := right[i] - rm
		covariance += a * b; lv += a * a; rv += b * b
	return covariance / sqrt(lv * rv) if lv > 0.0 and rv > 0.0 else 0.0


func _finish() -> void:
	if _ending: return
	_ending = true
	var result := {"schema": "bth.crt_mouse_scan_native/v1", "passed": failures.is_empty(), "checks": checks, "failures": failures,
		"moves": _moves, "launches": _launches, "actual_cue_counts": _actual_cue_counts() if is_instance_valid(app) else {},
		"mouse_leave_events": _mouse_events, "click_attempts": click_attempts, "motion_summaries": _motion_summaries,
		"motion_samples": _motion_samples, "screenshots": screenshots, "elapsed_msec": Time.get_ticks_msec() - started_msec,
		"scope": "Real native mouse event flow and separate compact keyboard/controller/touch preservation; QA-only ignored gray swatches sample the actual glass shader at two source heights. No generic-frame-diff motion acceptance, no touch/direct-method substitute for mouse Leave, no browser or audible-output claim."}
	if not evidence_dir.is_empty():
		var file := FileAccess.open(evidence_dir.path_join("crt-mouse-scan-native.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "\t"))
	print("CRT_MOUSE_SCAN_NATIVE " + JSON.stringify(result))
	if is_instance_valid(app): app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
