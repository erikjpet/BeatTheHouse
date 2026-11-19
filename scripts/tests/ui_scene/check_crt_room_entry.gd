extends SceneTree

# Rendered acceptance from synthetic, production-generated homes and disposable
# meta housing tiers. This does not claim an organically played run or Web QA.
# Fixture setup never launches a game or bypasses the rendered console control.
const MainScene := preload("res://scenes/main.tscn")
const Console := preload("res://scripts/core/home_practice_console.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const APPROVED_ROOT := "e:/codexqa/bth/"

var app: Control
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var pointer_diagnostics: Array[Dictionary] = []
var screenshots: Array[String] = []
var evidence_dir := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _guarded_rendered_environment():
		_finish()
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "crt_room_entry_fresh")
	root.add_child(app)
	await _settle(3)
	app.call("_ensure_full_content_library_loaded")
	if not _check(bool(app.call("_ensure_run_ui_built")), "Production room UI builds."):
		_finish()
		return
	_check(not bool(app.call("_has_foundation_save")), "The disposable room slot begins without a Continue save.")
	for archetype_id in ["motel_room", "apartment", "house"]:
		await _run_room(archetype_id)
	for housing_tier in ["motel_room", "apartment", "house"]:
		await _meta_room(housing_tier)
	_finish()


func _guarded_rendered_environment() -> bool:
	if not _check(DisplayServer.get_name() != "headless", "This capture requires a native display, without --headless."):
		return false
	for key in ["BTH_QA_WORKSPACE", "BTH_QA_RUN_DIR", "BTH_QA_PROFILE_DIR", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_QA_EVIDENCE_DIR"]:
		if not _check(_approved_path(OS.get_environment(key)), "%s uses explicitly admitted E: QA storage." % key):
			return false
	for key in ["BTH_CAPTURED_FIXTURE", "BTH_WEB_STORAGE_PROFILE"]:
		if not _check(OS.get_environment(key).is_empty(), "%s is absent; no captured or player profile is opened." % key):
			return false
	if not _check(_approved_path(ProjectSettings.globalize_path("res://")) and _approved_path(OS.get_user_data_dir()), "Checkout and engine user data stay under the approved E: root."):
		return false
	evidence_dir = OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/").simplify_path()
	return _check(DirAccess.dir_exists_absolute(evidence_dir), "The storage guard prepared the evidence directory before launch.")


func _approved_path(value: String) -> bool:
	return not value.is_empty() and value.replace("\\", "/").simplify_path().to_lower().begins_with(APPROVED_ROOT)


func _run_room(archetype_id: String) -> void:
	await _reset_fixture_host()
	var library: ContentLibrary = app.get("library")
	var candidate := RunState.new()
	candidate.start_new("CRT-RENDERED-ROOM-%s" % archetype_id)
	candidate.home_state = {"active": true, "lost": false, "home_archetype_id": archetype_id, "home_node_id": archetype_id, "tenure": {}}
	var generator := RunGenerator.new(library)
	var generated := generator.environment_test_result(candidate, {"archetype_id": archetype_id, "scenario_id": "__none", "generation_key": "crt-rendered-room", "depth": 0})
	if not _check(bool(generated.get("ok", false)), "%s production room fixture generates: %s" % [archetype_id, str(generated.get("errors", []))]):
		return
	candidate._store_current_local_suspicion()
	app.set("run_state", candidate)
	app.set("generator", generator)
	app.set("dev_game_test_mode", false)
	app.set("dev_environment_test_mode", false)
	app.set("meta_session_active", false)
	app.set("meta_session_location_id", "")
	app.set("current_game", null)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_bind_run_state_presentation_signals")
	app.call("_refresh_run_action_service")
	app.call("_queue_room_publication_check")
	app.call("_refresh")
	await _settle_rendered(2)
	await _exercise_origin("room-" + archetype_id, candidate, generator, false)


func _meta_room(housing_tier: String) -> void:
	await _reset_fixture_host()
	# Setup only: choose this tier in a fresh disposable collection. Entry and all
	# subsequent pointer controls use the actual production meta-home path.
	var collection: MetaCollectionService = app.get("meta_collection_service")
	collection._store["housing_tier"] = housing_tier
	if not _check(collection.save() == OK, "%s disposable meta housing fixture saves." % housing_tier):
		return
	app.call("open_meta_home")
	await _settle_rendered(2)
	var candidate: RunState = app.get("run_state")
	if not _check(candidate != null and bool(app.call("_is_meta_session")), "%s opens through production meta-home entry." % housing_tier):
		return
	candidate._store_current_local_suspicion()
	await _exercise_origin("meta-" + housing_tier, candidate, app.get("generator"), true)


func _reset_fixture_host() -> void:
	# Drain the preceding owned fixture's input and deferred presentation before
	# replacing it. A failed assertion must not leak a late click into the next
	# synthetic room or mistake a visible CRT for a room screenshot.
	Input.flush_buffered_events()
	await _settle_rendered(2)
	for _attempt in range(3):
		if not bool(app.call("_crt_practice_active")):
			break
		app.call("close_game_test_menu")
		await _settle_rendered(2)
	for helper in ["close_settings_menu", "close_run_menu", "close_meta_item_interaction", "_hide_event_choice_popup", "_hide_run_inventory_popup", "_hide_run_journal_popup", "_hide_world_map_overlay"]:
		app.call(helper)
	app.call("clear_interaction_focus")
	if bool(app.call("_is_meta_session")):
		app.call("_exit_meta_session")
	# End only the synthetic fixture; do not invoke run-result/save lifecycle.
	app.set("run_state", null)
	app.set("current_game", null)
	app.set("pending_autosave", false)
	app.set("dev_game_test_mode", false)
	app.set("dev_environment_test_mode", false)
	app.set("meta_session_active", false)
	app.set("meta_session_location_id", "")
	app.call("_set_current_screen", "START")
	app.call("_refresh")
	await _settle_rendered(2)


func _exercise_origin(case_name: String, candidate: RunState, generator: Variant, meta: bool) -> void:
	if not _check(str(app.get("current_screen")) == "ENVIRONMENT" and not bool(app.call("_crt_practice_active")), "%s is the ordinary originating room before capture." % case_name):
		return
	var object: Dictionary = app.call("_interactable_object", Console.OBJECT_ID)
	if not _check(not object.is_empty() and bool(object.get("enabled", false)) and bool(object.get("interactive", false)), "%s publishes an enabled physical television/console." % case_name):
		return
	var canvas := app.get("environment_canvas") as Control
	if not _check(canvas != null and canvas.is_visible_in_tree(), "%s has a visible production environment canvas." % case_name):
		return
	var authority := Binder.validate_base_layout_authority(candidate.current_environment)
	_check(bool(authority.get("ok", false)), "%s retains closed room slot authority: %s" % [case_name, str(authority.get("errors", []))])
	_check_old_slot_geometry(candidate.current_environment, case_name)
	var target: Rect2 = canvas.call("global_rect_for_object", Console.OBJECT_ID)
	var visible := canvas.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	_check(target.has_area() and visible.encloses(target), "%s television/console target is entirely visible in the native viewport." % case_name)
	if not target.has_area():
		return
	var local_point := canvas.get_global_transform_with_canvas().affine_inverse() * target.get_center()
	_check(str(canvas.call("object_id_at_local_position", local_point)) == Console.OBJECT_ID, "%s rendered target center resolves to this console." % case_name)
	var spatial: Dictionary = canvas.call("current_view_snapshot")
	for value in spatial.get("objects", []):
		var other: Dictionary = value
		var other_id := str(other.get("id", ""))
		if other_id == Console.OBJECT_ID or not bool(other.get("interactive", true)):
			continue
		var other_rect: Rect2 = canvas.call("global_rect_for_object", other_id)
		_check(not target.intersects(other_rect), "%s console target does not overlap accepted control %s." % [case_name, other_id])
	if meta:
		var upgrade: Dictionary = app.call("_interactable_object", "meta_upgrade:home")
		var upgrade_rect: Rect2 = canvas.call("global_rect_for_object", "meta_upgrade:home")
		_check(not upgrade.is_empty() and upgrade_rect.has_area() and visible.encloses(upgrade_rect) and not target.intersects(upgrade_rect), "%s retains a separate visible Home Upgrade Sign." % case_name)
	await _capture(case_name + ".png")
	await _move_pointer(target.get_center())
	# Hover/focus may pan the live camera. Resolve the actual rendered target
	# again after input and layout have settled instead of clicking a stale point.
	target = canvas.call("global_rect_for_object", Console.OBJECT_ID)
	await _move_pointer(target.get_center())
	if not _canvas_receives_pointer(canvas, case_name + " television center"):
		return
	await _mouse_tap(target.get_center())
	var selected := false
	for _frame in range(180):
		var selected_view: Dictionary = canvas.call("current_view_snapshot")
		if str(selected_view.get("selected_object_id", "")) == Console.OBJECT_ID:
			selected = true
			break
		await process_frame
	if not _check(selected, "%s ordinary single-click selects the rendered television." % case_name):
		return
	var play_point := await _stable_selected_action_point(canvas)
	if not _check(play_point != Vector2(-1, -1) and canvas.get_global_rect().has_point(play_point), "%s selected television exposes a visible rendered Play button." % case_name):
		return
	await _move_pointer(play_point)
	play_point = await _stable_selected_action_point(canvas)
	if not _check(play_point != Vector2(-1, -1) and canvas.get_global_rect().has_point(play_point), "%s rendered Play button remains visible after hover settles." % case_name):
		return
	await _move_pointer(play_point)
	if not _canvas_receives_pointer(canvas, case_name + " rendered Play button"):
		return
	candidate._store_current_local_suspicion()
	var before := _origin_state(candidate)
	var collection: MetaCollectionService = app.get("meta_collection_service")
	var meta_before := collection.snapshot().duplicate(true)
	await _capture(case_name + "-selected.png")
	# Capturing pixels yields a rendered frame. Requery the actual action after
	# that yield, and record every press/release boundary before changing code.
	play_point = await _stable_selected_action_point(canvas)
	if not _check(play_point != Vector2(-1, -1), "%s Play remains rendered after screenshot capture." % case_name):
		return
	await _move_pointer(play_point)
	if not _canvas_receives_pointer(canvas, case_name + " live Play before press"):
		_record_pointer(case_name, "play_covered_before_press", canvas, play_point)
		return
	if not await _play_pointer_tap(case_name, canvas, play_point):
		return
	var unexpected_game: GameModule = app.get("current_game")
	var entered := false
	if str(app.get("current_screen")) != "GAME" and unexpected_game == null:
		entered = await _wait_screen("CRT")
	entered = entered and bool(app.call("_crt_practice_active"))
	unexpected_game = app.get("current_game")
	_record_pointer(case_name, "play_after_screen_wait", canvas, play_point)
	if not _check(entered, "%s rendered Play opens the CRT selector; actual screen=%s game=%s CRT=%s." % [case_name, str(app.get("current_screen")), unexpected_game.get_id() if unexpected_game != null else "none", str(app.call("_crt_practice_active"))]):
		await _capture(case_name + "-play-failed-actual.png")
		return
	var menu := app.get("game_test_menu") as Control
	_check(menu != null and menu.is_visible_in_tree(), "%s selector is visibly mounted." % case_name)
	await _capture(case_name + "-crt.png")
	var exit_button := menu.get("exit_button") as Button if menu != null else null
	if not _check(exit_button != null and exit_button.is_visible_in_tree(), "%s exposes the rendered Exit TV button." % case_name):
		return
	if not await _stable_control_hover(exit_button, case_name + " Exit TV", canvas):
		return
	var exit_position: Vector2 = menu.call("display_hit_point", exit_button)
	_record_pointer(case_name, "exit_before_press", canvas, exit_position)
	await _mouse_tap(exit_position)
	_record_pointer(case_name, "exit_after_click", canvas, exit_position)
	var restored := await _wait_screen("ENVIRONMENT")
	_check(restored and app.get("run_state") == candidate and app.get("generator") == generator, "%s Exit TV restores the exact original run/generator/room." % case_name)
	_check(not bool(app.call("_crt_practice_active")) and bool(app.call("_is_meta_session")) == meta, "%s Exit TV restores the original run/meta context." % case_name)
	_check(_origin_state(candidate) == before, "%s selector entry/exit preserves run, room, home and RNG state." % case_name)
	_check(collection.snapshot() == meta_before, "%s selector entry/exit preserves the meta collection." % case_name)
	_check(canvas.is_visible_in_tree() and not menu.is_visible_in_tree(), "%s Exit TV returns the visible originating room." % case_name)
	cases.append({"case": case_name, "meta": meta, "archetype_id": candidate.current_environment.get("archetype_id", ""), "target_global_rect": _rect_data(target), "slot_errors": authority.get("errors", []), "origin_identity_preserved": _origin_state(candidate) == before})


func _check_old_slot_geometry(environment: Dictionary, case_name: String) -> void:
	var original := Placement._shipping_surface_map(environment)
	# Compare the additive feature at its composition boundary. The full live
	# surface map may also contain existing approved developer slot overrides;
	# those retain their separate authority and are validated above by the binder.
	var current := Console.surface_map(environment, original)
	var slots: Dictionary = {}
	for value in current.get("fixed_slots", []):
		var slot: Dictionary = value
		slots[str(slot.get("id", ""))] = slot
	for value in original.get("fixed_slots", []):
		var slot: Dictionary = value
		var slot_id := str(slot.get("id", ""))
		_check(slots.get(slot_id, {}) == slot, "%s preserves accepted slot geometry %s." % [case_name, slot_id])
	for field in ["fixed_object_slot_ids", "fixed_category_slot_ids", "object_family_ids", "class_overrides"]:
		var original_mapping: Dictionary = original.get(field, {})
		var current_mapping: Dictionary = current.get(field, {})
		for key in original_mapping:
			_check(current_mapping.get(key) == original_mapping[key], "%s preserves accepted %s entry %s." % [case_name, field, str(key)])


func _origin_state(state: RunState) -> Dictionary:
	return {"run": state.to_dict().duplicate(true), "room": state.current_environment.duplicate(true), "home": state.home_state.duplicate(true), "rng_seed": state.rng_seed, "rng_state": state.rng_state}


func _move_pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - root.get_mouse_position()
	Input.parse_input_event(event)
	await _settle_rendered(2)


func _mouse_tap(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await _settle_rendered(2)


func _canvas_receives_pointer(canvas: Control, label: String) -> bool:
	var hovered := root.gui_get_hovered_control()
	return _check(hovered == canvas or hovered != null and canvas.is_ancestor_of(hovered), "%s receives actual canvas pointer input; covering control=%s." % [label, str(hovered.get_path()) if hovered != null else "none"])


func _live_selected_action_point(canvas: Control) -> Vector2:
	if canvas == null or not canvas.is_visible_in_tree():
		return Vector2(-1, -1)
	var local: Vector2 = canvas.call("local_position_for_selected_info_action_button")
	return canvas.get_global_transform_with_canvas() * local if local.x >= 0 and local.y >= 0 else Vector2(-1, -1)


func _play_pointer_tap(case_name: String, canvas: Control, planned_point: Vector2) -> bool:
	var point := _live_selected_action_point(canvas)
	_record_pointer(case_name, "play_immediately_before_press", canvas, planned_point)
	if not _check(point != Vector2(-1, -1) and canvas.get_global_rect().has_point(point), "%s live Play is present immediately before mouse press." % case_name):
		return false
	# No retry is performed after this accepted pointer press. If it enters a
	# game directly, retain that observation as a possible click-through defect.
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	Input.parse_input_event(event)
	_record_pointer(case_name, "play_immediately_after_press", canvas, point)
	await process_frame
	_record_pointer(case_name, "play_immediately_before_release", canvas, point)
	# A physical click releases where it pressed. The diagnostic above requeries
	# the live old action (or its absence) without moving onto a new screen row.
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	_record_pointer(case_name, "play_immediately_after_release", canvas, point)
	await _settle_rendered(2)
	_record_pointer(case_name, "play_after_two_rendered_frames", canvas, point)
	return true


func _stable_control_hover(control: Control, label: String, canvas: Control) -> bool:
	if not _check(control != null and control.is_visible_in_tree(), "%s has a visible control." % label):
		return false
	var menu := app.get("game_test_menu") as Control
	for attempt in range(3):
		var rect := control.get_global_rect()
		var point: Vector2 = menu.call("display_hit_point", control)
		await _move_pointer(point)
		var fresh := control.get_global_rect()
		var hovered := control.get_viewport().gui_get_hovered_control()
		var display_point: Vector2 = menu.call("global_to_display", point)
		_record_pointer(label, "exit_hover_attempt_%d" % (attempt + 1), canvas, point)
		pointer_diagnostics.append({"case": label, "phase": "crt_display_exit_hover", "attempt": attempt + 1, "root_position": {"x": point.x, "y": point.y}, "display_position": {"x": display_point.x, "y": display_point.y}, "display_hovered_control": str(hovered.get_path()) if hovered != null else "none"})
		if fresh.has_area() and fresh.get_center().distance_to(rect.get_center()) <= 0.25 \
				and fresh.has_point(display_point) and (hovered == control or hovered != null and control.is_ancestor_of(hovered)):
			return _check(true, "%s receives actual pointer input at its current rendered center." % label)
	var covering := control.get_viewport().gui_get_hovered_control()
	return _check(false, "%s remains covered after three fresh-rectangle hover attempts; covering control=%s." % [label, str(covering.get_path()) if covering != null else "none"])


func _record_pointer(case_name: String, phase: String, canvas: Control, requested: Vector2) -> void:
	var hovered := root.gui_get_hovered_control()
	var game: GameModule = app.get("current_game")
	var menu := app.get("game_test_menu") as Control
	var live_action := _live_selected_action_point(canvas)
	var row := {
		"case": case_name, "phase": phase,
		"requested_position": {"x": requested.x, "y": requested.y},
		"live_action_position": {"x": live_action.x, "y": live_action.y},
		"root_mouse_position": {"x": root.get_mouse_position().x, "y": root.get_mouse_position().y},
		"hovered_control": str(hovered.get_path()) if hovered != null else "none",
		"current_screen": str(app.get("current_screen")),
		"current_game_id": game.get_id() if game != null else "",
		"crt_active": bool(app.call("_crt_practice_active")),
		"menu_visible": menu != null and menu.is_visible_in_tree(),
		"canvas_visible": canvas != null and canvas.is_visible_in_tree(),
	}
	pointer_diagnostics.append(row)
	print("CRT_ROOM_POINTER %s" % JSON.stringify(row))


func _stable_selected_action_point(canvas: Control) -> Vector2:
	var previous := Vector2(-1, -1)
	for _attempt in range(90):
		var local: Vector2 = canvas.call("local_position_for_selected_info_action_button")
		if local.x < 0 or local.y < 0:
			await _settle_rendered(2)
			continue
		var global := canvas.get_global_transform_with_canvas() * local
		if previous != Vector2(-1, -1) and previous.distance_to(global) <= 0.25:
			return global
		previous = global
		await _settle_rendered(2)
	return Vector2(-1, -1)


func _wait_screen(expected: String) -> bool:
	for _frame in range(180):
		if str(app.get("current_screen")) == expected:
			await _settle_rendered(2)
			return str(app.get("current_screen")) == expected
		await process_frame
	return false


func _settle_rendered(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _check(image != null and not image.is_empty(), "Rendered viewport pixels exist for %s." % filename):
		return
	var path := evidence_dir.path_join(filename)
	var error := image.save_png(path)
	_check(error == OK and image.get_size() == Vector2i(1280, 720), "Rendered native screenshot %s saves at 1280x720." % filename)
	if error == OK:
		screenshots.append(path)


func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _settle(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame


func _check(passed: bool, message: String) -> bool:
	checks += 1
	if not passed:
		failures.append(message)
		push_error(message)
	return passed


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "cases": cases, "screenshots": screenshots, "pointer_diagnostics": pointer_diagnostics, "fidelity": "Rendered native MainScene; synthetic production-generated Motel Room/Apartment/House and fresh disposable meta housing tiers; actual mapped single-click selection, rendered Play button and Exit TV. No organically played run, player save or Web claim."}
	if not evidence_dir.is_empty():
		var output := FileAccess.open(evidence_dir.path_join("crt-room-entry-result.json"), FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(report, "\t") + "\n")
	print("CRT_ROOM_ENTRY %s" % JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
