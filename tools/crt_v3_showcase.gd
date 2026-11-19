extends "res://scripts/tests/ui_scene/check_crt_console_navigation.gd"

# One real Movie Maker take, including the AudioServer mix in the native AVI.
# Launch only through the fresh E: guarded runner after source identity checks:
# godot --path <E: source> --resolution 1280x720 --fixed-fps 30 \
#   --write-movie <fresh evidence>/crt-v3-showcase.avi \
#   --log-file <fresh evidence>/godot.log --script res://tools/crt_v3_showcase.gd
# The existing navigation base supplies only real warped GUI/pointer helpers.
# No video/audio synthesis, direct cue calls, profile import or save cleanup.

const SHOWCASE_FPS := 30
const SHOWCASE_SEED := "CRT-V3-HOME-SHOWCASE-061"
const SHOWCASE_SLOT := "crt_v3_showcase_fresh"
const TARGET_TAKE_FRAMES := SHOWCASE_FPS * 42
const MAX_TAKE_FRAMES := SHOWCASE_FPS * 50
const MAX_BOOT_FRAMES := SHOWCASE_FPS * 30

var _take_start := -1
var _take_end := -1
var _finished := false
var _movie_path := ""
var _markers: Array[Dictionary] = []
var _origin: RunState
var _origin_identity: Dictionary = {}
var _home_start_identity: Dictionary = {}
var _restored_identity: Dictionary = {}
var _restored_profile_meta: Dictionary = {}
var _entry_observed := false
var _exit_observed := false
var _profile_meta_before: Dictionary = {}
var _slot_during_crt: Dictionary = {}
var _selection_ids: Array[String] = []
var _expected_selection_ids: Array[String] = []
var _accepted_ids: Array[String] = []
var _practice_purchase_price := 0


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	if not _guarded_rendered_environment() or not _movie_contract():
		_finish()
		return
	for env_name in ["BTH_CAPTURED_FIXTURE", "BTH_WEB_STORAGE_PROFILE"]:
		if not _require(OS.get_environment(env_name).strip_edges().is_empty(), "Fresh native showcase has no imported fixture/storage override: " + env_name):
			return
	process_frame.connect(_showcase_frame_budget)
	process_frame.connect(_showcase_observe_boundaries)
	Engine.max_fps = SHOWCASE_FPS
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	# Supported fresh replay fixture, prepared before the take. The ordinary
	# environment clock and presentation retain their normal live behavior.
	app.set("autosave_slot_id", SHOWCASE_SLOT)
	root.add_child(app)
	await _rendered_frames(5)
	if not _require(not bool(app.call("_has_foundation_save")), "Fresh showcase slot has no prior Continue save."):
		return
	if not _require(bool(app.call("start_foundation_run", SHOWCASE_SEED,
			{"modifiers": {"home_archetype_id": "house"}}, false)), "Public challenge configuration starts an ordinary Home run."):
		return
	await _rendered_frames(5)
	_origin = app.get("run_state") as RunState
	if not _require(_home_origin_ready(), "The actual ordinary House/Home environment is ready before the take."):
		return
	if not await _drain_ordinary_save_before_take():
		_finish()
		return
	_take_start = Engine.get_process_frames()
	_home_start_identity = _protected_identity(_origin)
	_showcase_mark("take_start_home_ready")
	await _showcase_hold(3.0)
	if not await _enter_tv_by_normal_input():
		_finish()
		return
	menu = app.get("game_test_menu") as Control
	if not _require(menu != null and menu.is_visible_in_tree(), "Home Play opens the actual CRT selector."):
		return
	menu.connect("user_selection_changed", _showcase_selection)
	menu.connect("launch_accepted", _showcase_accepted)
	var seed := app.get("game_test_seed_input") as LineEdit
	if not _require(seed != null and seed.text == "PRACTICE", "The real CRT retains its normal PRACTICE seed."):
		return
	_showcase_mark("crt_music_hold")
	await _showcase_hold(8.0)
	if not _require(_entry_observed and not app.get("save_service").async_save_in_flight(), "CRT entry is recorded and any legitimate ordinary write has settled before the paid practice segment."):
		return
	_slot_during_crt = _regular_slot_hashes()
	var first_moves: Array[String] = ["pull_tabs", "blackjack", "scratch_tickets"]
	if str(menu.get("selected_game_id")) == first_moves[0]:
		first_moves[0] = "bar_dice"
	for game_id in first_moves:
		if not await _hover_game_by_normal_input(game_id):
			_finish()
			return
		_expected_selection_ids.append(game_id)
		await _showcase_hold(1.6)
	if not _require(_selection_ids == _expected_selection_ids, "Three deliberate real selection changes emit exactly three move signals."):
		return
	await _showcase_hold(1.0)
	if not await _click_control(_game_button("scratch_tickets"), "Confirm Scratch Tickets practice"):
		_finish()
		return
	if not _require(_current_game_id() == "scratch_tickets" and _accepted_ids == ["scratch_tickets"], "Real confirmation launches Scratch practice once."):
		return
	_showcase_mark("practice_scratch_confirmed")
	await _showcase_hold(3.0)
	if not await _buy_one_ticket_by_normal_input():
		_finish()
		return
	await _showcase_hold(4.0)
	if not await _leave_by_pointer():
		_finish()
		return
	if not _require(str(menu.get("selected_game_id")) == "scratch_tickets" and seed.text == "PRACTICE", "Normal Leave retains selector and seed."):
		return
	if not _require(_regular_slot_hashes() == _slot_during_crt, "A paid practice purchase never changes the ordinary Continue slot."):
		return
	_showcase_mark("normal_leave_to_crt")
	await _showcase_hold(3.0)
	for game_id in ["blackjack", "baccarat"]:
		if not await _hover_game_by_normal_input(game_id):
			_finish()
			return
		_expected_selection_ids.append(game_id)
		await _showcase_hold(1.6)
	if not await _click_control(menu.get("exit_button") as Control, "Exit TV to Home"):
		_finish()
		return
	await _rendered_frames(3)
	if not _require(_home_origin_ready() and app.get("run_state") == _origin and not bool(app.call("_crt_practice_active")), "Exit TV restores the exact ordinary Home origin."):
		return
	if not _require(_exit_observed and _restored_identity == _origin_identity and _restored_profile_meta == _profile_meta_before, "CRT entry/exit boundaries preserve Home cash, clock, Heat, inventory, RNG and profile/meta state; ordinary idle clock remains live."):
		return
	if not _require(seed.text == "PRACTICE" and _selection_ids == _expected_selection_ids, "Return focus adds no move cue; later real moves remain distinct and seed is retained."):
		return
	_showcase_mark("exit_tv_home_restored")
	await _showcase_hold(3.0)
	var remaining := TARGET_TAKE_FRAMES - (Engine.get_process_frames() - _take_start)
	if remaining > 0:
		await _rendered_frames(remaining)
	_take_end = Engine.get_process_frames()
	_showcase_mark("take_end_home_ready")
	_finish()


func _movie_contract() -> bool:
	# Engine flags may be absent from OS.get_cmdline_args(). Query the real
	# Movie Maker engine state instead; the guarded launch fixes FPS to 30.
	_movie_path = Engine.get_write_movie_path().replace("\\", "/").simplify_path()
	var expected := evidence_dir.path_join("crt-v3-showcase.avi")
	return _check_contract(_movie_path.to_lower() == expected.to_lower(), "Movie output is the exact fresh guarded evidence AVI.")


func _check_contract(ok: bool, label: String) -> bool:
	_check(ok, label)
	return ok


func _require(ok: bool, label: String) -> bool:
	_check(ok, label)
	if not ok:
		_finish()
	return ok


func _home_origin_ready() -> bool:
	var state := app.get("run_state") as RunState
	return state != null and str(app.get("current_screen")) == "ENVIRONMENT" \
		and str(state.current_environment.get("archetype_id", "")) == "house" \
		and str(state.current_environment.get("kind", "")) == "home" \
		and not bool(app.get("dev_game_test_mode")) and not bool(app.call("_is_meta_session"))


func _drain_ordinary_save_before_take() -> bool:
	for _frame in range(180):
		var service: SaveService = app.get("save_service")
		if not bool(app.get("pending_autosave")) and (service == null or not service.async_save_in_flight()):
			return true
		await _rendered_frames(1)
	return _check_contract(false, "Ordinary setup save completes before the movie take.")


func _enter_tv_by_normal_input() -> bool:
	var canvas := app.get("environment_canvas") as Control
	if not _check_contract(canvas != null and canvas.is_visible_in_tree(), "Home has its rendered environment canvas."):
		return false
	var target: Rect2 = canvas.call("global_rect_for_object", "home_console:tv")
	if not _check_contract(target.has_area(), "Home publishes the real television pointer target."):
		return false
	await _move_pointer(target.get_center())
	target = canvas.call("global_rect_for_object", "home_console:tv")
	await _mouse_tap(target.get_center())
	await _rendered_frames(2)
	var point := await _stable_home_play_point(canvas)
	if not _check_contract(point != Vector2(-1, -1), "Selected television exposes its actual Play control."):
		return false
	await _move_pointer(point)
	point = await _stable_home_play_point(canvas)
	if not _check_contract(point != Vector2(-1, -1), "Television Play stays stable after hover."):
		return false
	_showcase_mark("home_tv_play")
	await _mouse_tap(point)
	for _frame in range(120):
		if str(app.get("current_screen")) == "CRT" and app.get("current_game") == null:
			_showcase_observe_boundaries()
			return true
		await _rendered_frames(1)
	return _check_contract(false, "Normal Home Play reaches CRT without click-through.")


func _stable_home_play_point(canvas: Control) -> Vector2:
	var previous := Vector2(-1, -1)
	for _frame in range(60):
		var local: Vector2 = canvas.call("local_position_for_selected_info_action_button")
		if local.x >= 0 and local.y >= 0:
			var point := canvas.get_global_transform_with_canvas() * local
			if previous != Vector2(-1, -1) and previous.distance_to(point) <= 0.25:
				return point
			previous = point
		await _rendered_frames(1)
	return Vector2(-1, -1)


func _hover_game_by_normal_input(game_id: String) -> bool:
	var button := _game_button(game_id)
	if not _check_contract(button != null and button.is_visible_in_tree() and not button.disabled, "Visible enabled menu choice: " + game_id):
		return false
	await _move_pointer(_hit_point(button))
	var hovered := menu.call("get_display_hovered_control") as Control
	return _check_contract(str(menu.get("selected_game_id")) == game_id
		and (hovered == button or hovered != null and button.is_ancestor_of(hovered)), "Real warped pointer hover selects " + game_id)


func _buy_one_ticket_by_normal_input() -> bool:
	var practice := app.get("run_state") as RunState
	var surface := app.get("game_surface_canvas") as Control
	if not _check_contract(practice != null and practice != _origin and surface != null, "A distinct practice state and its normal rendered surface are active."):
		return false
	var before_cash := practice.bankroll
	var rect: Rect2 = surface.call("global_rect_for_surface_action", "scratch_buy", 0)
	if not _check_contract(rect.has_area(), "Scratch exposes its actual single-ticket Buy control."):
		return false
	await _move_pointer(rect.get_center())
	await _mouse_tap(rect.get_center())
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if str(popup.get("popup_type", "")) == "wager_confirmation" and bool(popup.get("visible", false)):
		var choices := app.get("event_choice_popup_choices_list") as Control
		if not _check_contract(choices != null, "The normal wager confirmation presents actual choices."):
			return false
		var confirm: Button
		for node in choices.find_children("*", "Button", true, false):
			if node is Button and node.text == "Confirm Bet":
				confirm = node
				break
		if not await _click_control(confirm, "Normal Confirm Bet"):
			return false
	await _rendered_frames(4)
	_practice_purchase_price = before_cash - practice.bankroll
	var machine: Dictionary = practice.current_environment.get("game_states", {}).get("scratch_tickets", {})
	_showcase_mark("practice_paid_ticket")
	return _check_contract(_practice_purchase_price > 0 and not (machine.get("tray_stack", []) as Array).is_empty(), "Real Buy spends only practice money and dispenses a ticket.")


func _protected_identity(state: RunState) -> Dictionary:
	return {"room_id": str(state.current_environment.get("id", "")), "archetype": str(state.current_environment.get("archetype_id", "")),
		"cash": state.bankroll, "clock": state.game_clock_minutes, "heat": state.suspicion.duplicate(true),
		"inventory": state.inventory.duplicate(true), "home": state.home_state.duplicate(true),
		"rng_seed": str(state.rng_seed), "rng_state": str(state.rng_state)}


func _profile_meta_state() -> Dictionary:
	var profile: ProfileInventory = app.get("profile_inventory")
	var collection: MetaCollectionService = app.get("meta_collection_service")
	return {"profile": profile.to_dict().duplicate(true), "meta": collection.snapshot().duplicate(true)}


func _regular_slot_hashes() -> Dictionary:
	var service: SaveService = app.get("save_service")
	var result := {}
	for path in [service.run_save_path(SHOWCASE_SLOT), service.backup_save_path(SHOWCASE_SLOT)]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result


func _showcase_selection(game_id: String) -> void:
	_selection_ids.append(game_id)
	_showcase_mark("user_selection_" + game_id)


func _showcase_accepted(game_id: String) -> void:
	_accepted_ids.append(game_id)
	_showcase_mark("launch_accepted_" + game_id)


func _showcase_mark(label: String) -> void:
	var frame := Engine.get_process_frames()
	_markers.append({"label": label, "frame": frame, "seconds_from_movie_start": float(frame) / SHOWCASE_FPS})
	print("CRT_V3_SHOWCASE_MARKER " + JSON.stringify(_markers.back()))


func _showcase_hold(seconds: float) -> void:
	await _rendered_frames(roundi(seconds * SHOWCASE_FPS))


func _showcase_observe_boundaries() -> void:
	if _finished or _take_start < 0 or app == null or _origin == null:
		return
	# SceneTree.process_frame observes the accepted UI transition before the
	# next ordinary Node._process clock update. These are observations only.
	if not _entry_observed and str(app.get("current_screen")) == "CRT" and bool(app.call("_crt_practice_active")):
		_origin_identity = _protected_identity(_origin)
		_profile_meta_before = _profile_meta_state()
		_entry_observed = true
		_showcase_mark("crt_entry_boundary")
	elif _entry_observed and not _exit_observed and _home_origin_ready() and app.get("run_state") == _origin and not bool(app.call("_crt_practice_active")):
		_restored_identity = _protected_identity(_origin)
		_restored_profile_meta = _profile_meta_state()
		_exit_observed = true
		_showcase_mark("home_restored_boundary")


func _showcase_frame_budget() -> void:
	if _finished:
		return
	var frame := Engine.get_process_frames()
	if (_take_start < 0 and frame > MAX_BOOT_FRAMES) or (_take_start >= 0 and frame - _take_start > MAX_TAKE_FRAMES):
		_check(false, "The bounded Movie Maker boot/take frame budget was exceeded; retain this failed take.")
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var result := {"schema": "bth.crt_v3_showcase/v1", "passed": failures.is_empty() and _take_start >= 0 and _take_end > _take_start,
		"checks": checks, "failures": failures, "movie": _movie_path, "fps": SHOWCASE_FPS, "pixels": [1280, 720],
		"take_start_frame": _take_start, "take_end_frame_exclusive": _take_end,
		"take_seconds": float(_take_end - _take_start) / SHOWCASE_FPS if _take_end >= 0 else 0.0,
		"markers": _markers, "selection_ids": _selection_ids, "expected_selection_ids": _expected_selection_ids, "launch_accepted_ids": _accepted_ids,
		"practice_purchase_price": _practice_purchase_price, "origin_at_crt_entry": _origin_identity,
		"home_at_take_start": _home_start_identity, "home_at_crt_exit": _restored_identity,
		"home_at_take_end": _protected_identity(_origin) if _origin != null else {},
		"ordinary_clock_behavior": "Unmodified live default; state equality compares CRT entry and first restored Home observation, before the next ordinary clock update.",
		"input_fidelity": "Normal parsed pointer/GUI input only from Home onward; supported public House challenge fixture before take.",
		"audio_fidelity": "Native Movie Maker AVI records the actual synchronized AudioServer mix; no replacement audio or reconstructed animation.",
		"audio_driver": AudioServer.get_driver_name(), "mix_rate": AudioServer.get_mix_rate(),
		"elapsed_msec": Time.get_ticks_msec() - started_msec}
	if evidence_dir.to_lower().begins_with(APPROVED_ROOT) and DirAccess.dir_exists_absolute(evidence_dir):
		var file := FileAccess.open(evidence_dir.path_join("crt-v3-showcase.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
		else:
			result["passed"] = false
			push_error("Showcase timing/result receipt could not be written.")
	print("CRT_V3_SHOWCASE_RESULT " + JSON.stringify(result))
	quit(0 if bool(result["passed"]) else 1)
