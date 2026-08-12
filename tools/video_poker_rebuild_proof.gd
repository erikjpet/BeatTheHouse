extends SceneTree

# Boots the real game, drives the native video-poker surface commands, and
# captures the exact idle/hold/result states used for rebuild acceptance.

const MainScene := preload("res://scenes/main.tscn")
const CABINETS := [
	{"id": "jacks_or_better", "variant": "jacks_or_better", "hands": 1},
	{"id": "double_deuces", "variant": "deuces_wild", "hands": 2},
	{"id": "triple_double_bonus", "variant": "double_double_bonus", "hands": 3},
]

var app: Control
var output_dir := "res://.tmp/video_poker/rebuild_proof"
var failures: Array[String] = []
var proof_rows: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	print("VP_PROOF: initialize")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/proof_meta.json" % ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	app = MainScene.instantiate()
	print("VP_PROOF: main instantiated")
	app.set("autosave_slot_id", "video_poker_rebuild_proof")
	root.add_child(app)
	print("VP_PROOF: main entered tree")
	await _settle(10)
	for cabinet_value in CABINETS:
		print("VP_PROOF: begin %s" % str(cabinet_value.get("id", "")))
		await _capture_cabinet(cabinet_value)
		print("VP_PROOF: complete %s" % str(cabinet_value.get("id", "")))
	await _prove_holdout_feedback()
	await _prove_abandoned_holdout_draw()
	await _prove_double_up_pointer(false, "1280x720 mouse")
	await _prove_small_screen_touch_loop()
	await _capture_slot_reference()
	_write_report()
	if failures.is_empty():
		print("VIDEO_POKER_REBUILD_PROOF_PASS -> %s" % output_dir)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _capture_cabinet(cabinet: Dictionary) -> void:
	var cabinet_id := str(cabinet.get("id", "jacks_or_better"))
	var hand_count := int(cabinet.get("hands", 1))
	if not await _prepare_video_poker(cabinet):
		return
	var canvas: Control = app.get("game_surface_canvas")
	await _save_shot("%s_01_idle" % cabinet_id)
	_emit_surface_input("video_poker_bet_max", 0, false)
	await _settle(5)
	var max_state := _surface_state(canvas)
	if int(max_state.get("coin_count", 0)) != 5:
		failures.append("%s did not reach five coins through BET MAX." % cabinet_id)
	await _save_shot("%s_02_bet_max" % cabinet_id)
	_emit_surface_input("video_poker_deal", 0, false)
	await _wait_card_reveal()
	var proof_holds := [1] if cabinet_id == "triple_double_bonus" else [0, 2]
	for hold_index in proof_holds:
		_emit_surface_input("video_poker_hold", hold_index, false)
	await _settle(6)
	var hold_state := _surface_state(canvas)
	var active_holds: Array = hold_state.get("holds", [])
	var holds_applied := true
	for hold_index in proof_holds:
		holds_applied = holds_applied and active_holds.has(hold_index)
	if str(hold_state.get("phase", "")) != "hold" or not holds_applied:
		failures.append("%s did not reach the driven DEAL -> HOLD state." % cabinet_id)
	await _save_shot("%s_03_hold_guidance" % cabinet_id)
	_emit_surface_input("video_poker_draw", 0, false)
	await _wait_card_reveal()
	var result_state := _surface_state(canvas)
	var signatures: Array = result_state.get("rendered_hand_signatures", []) if typeof(result_state.get("rendered_hand_signatures", [])) == TYPE_ARRAY else []
	var distinct := {}
	for signature_value in signatures:
		distinct[str(signature_value)] = true
	if str(result_state.get("phase", "")) != "settled":
		failures.append("%s did not settle after DRAW." % cabinet_id)
	if signatures.size() != hand_count:
		failures.append("%s rendered %d hand signatures, expected %d." % [cabinet_id, signatures.size(), hand_count])
	if hand_count > 1 and distinct.size() != hand_count:
		failures.append("%s displayed copied result hands: %s." % [cabinet_id, JSON.stringify(signatures)])
	var result_rows: Array = result_state.get("hand_results", []) if typeof(result_state.get("hand_results", [])) == TYPE_ARRAY else []
	if result_rows.size() != hand_count:
		failures.append("%s did not expose one independently paid result per hand." % cabinet_id)
	var result_labels := {}
	for result_value in result_rows:
		var result_row: Dictionary = result_value if typeof(result_value) == TYPE_DICTIONARY else {}
		var result_label := str(result_row.get("pay_label", "")).strip_edges()
		result_labels["NO PAY" if result_label.is_empty() else result_label] = true
	if cabinet_id == "triple_double_bonus" and result_labels.size() < 2:
		failures.append("%s did not display independently different outcomes: %s." % [cabinet_id, JSON.stringify(result_labels.keys())])
	await _save_shot("%s_04_result" % cabinet_id)
	proof_rows.append({
		"cabinet": cabinet_id,
		"hands": hand_count,
		"coins_per_hand": int(result_state.get("coin_count", 0)),
		"total_bet": int(result_state.get("bet_credits", 0)),
		"phase": str(result_state.get("phase", "")),
		"rendered_hand_signatures": signatures,
		"distinct_rendered_hands": distinct.size(),
		"result_rows": result_rows.size(),
		"distinct_result_labels": result_labels.keys(),
		"outcome_headline": str(result_state.get("outcome_headline", "")),
		"winning_pay_keys": result_state.get("winning_pay_keys", []),
	})


func _prove_small_screen_touch_loop() -> void:
	print("VP_PROOF: begin small-screen touch controls")
	DisplayServer.window_set_size(Vector2i(960, 600))
	await _settle(8)
	var cabinet: Dictionary = CABINETS[0]
	if not await _prepare_video_poker(cabinet):
		return
	var canvas: Control = app.get("game_surface_canvas")
	var initial := _surface_state(canvas)
	_emit_surface_input("video_poker_bet_one", 0, true)
	await _settle(5)
	var incremented := _surface_state(canvas)
	if int(incremented.get("coin_count", 0)) != int(initial.get("coin_count", 0)) + 1:
		failures.append("Small-screen touch BET + did not change coins per hand.")
	_emit_surface_input("video_poker_bet_max", 0, true)
	await _settle(5)
	var maxed := _surface_state(canvas)
	if int(maxed.get("coin_count", 0)) != 5:
		failures.append("Small-screen touch BET MAX did not select five coins.")
	_emit_surface_input("video_poker_deal", 0, true)
	await _wait_card_reveal()
	if str(_surface_state(canvas).get("phase", "")) != "hold":
		failures.append("Small-screen touch DEAL did not enter HOLD.")
		return
	for card_index in range(5):
		_emit_surface_input("video_poker_hold", card_index, true)
		await _settle(3)
		var holds: Array = _surface_state(canvas).get("holds", [])
		if not holds.has(card_index):
			failures.append("Small-screen touch HOLD %d did not toggle." % (card_index + 1))
	_emit_surface_input("video_poker_draw", 0, true)
	await _wait_card_reveal()
	var result := _surface_state(canvas)
	if str(result.get("phase", "")) != "settled":
		failures.append("Small-screen touch DRAW did not settle with one press.")
	await _save_shot("jacks_or_better_small_screen_touch_result")
	proof_rows.append({
		"cabinet": "jacks_or_better",
		"screen": "960x600",
		"input": "touch",
		"coins_per_hand": int(result.get("coin_count", 0)),
		"phase": str(result.get("phase", "")),
		"all_hold_controls_worked": (result.get("drawn_indices", []) as Array).is_empty(),
	})
	await _prove_double_up_pointer(true, "960x600 touch")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle(8)
	print("VP_PROOF: complete small-screen touch controls")


func _prove_holdout_feedback() -> void:
	print("VP_PROOF: begin holdout feedback")
	if not await _prepare_video_poker(CABINETS[0]):
		return
	var canvas: Control = app.get("game_surface_canvas")
	_emit_surface_input("video_poker_bet_max", 0, false)
	_emit_surface_input("video_poker_deal", 0, false)
	await _wait_card_reveal()
	_emit_surface_input("video_poker_mark", 0, false)
	await _settle(4)
	var marked := _surface_state(canvas)
	if not bool(marked.get("holdout_ready", false)):
		failures.append("Live HOLDOUT did not arm through its visible control.")
		return
	var initial_meter: Dictionary = marked.get("holdout_meter", {}) if typeof(marked.get("holdout_meter", {})) == TYPE_DICTIONARY else {}
	await create_timer(0.18).timeout
	await _settle(3)
	var moved_meter: Dictionary = _surface_state(canvas).get("holdout_meter", {}) if typeof(_surface_state(canvas).get("holdout_meter", {})) == TYPE_DICTIONARY else {}
	if is_equal_approx(float(initial_meter.get("progress", 0.0)), float(moved_meter.get("progress", 0.0))):
		failures.append("Live HOLDOUT sweep did not move during realtime surface refresh.")
	await _save_shot("jacks_or_better_holdout_armed")
	var safety := 0
	while safety < 4:
		safety += 1
		var challenge: Dictionary = _surface_state(canvas).get("holdout_challenge", {})
		if bool(challenge.get("chain_complete", false)) or not str(challenge.get("skill_grade", "")).is_empty():
			break
		var beats: Array = challenge.get("beats", [])
		if beats.is_empty():
			failures.append("Live HOLDOUT did not expose its skill beats.")
			return
		var beat_index := clampi(int(challenge.get("current_beat", 0)), 0, beats.size() - 1)
		var beat: Dictionary = beats[beat_index] if typeof(beats[beat_index]) == TYPE_DICTIONARY else {}
		var target_msec := int(beat.get("target_msec", Time.get_ticks_msec()))
		var delay_msec := maxi(0, target_msec - Time.get_ticks_msec())
		if delay_msec > 0:
			await create_timer(float(delay_msec) / 1000.0).timeout
		var target_index := int(challenge.get("target_slot", 0)) if str(beat.get("kind", "")) == "target" else 0
		_emit_surface_input("video_poker_palm", target_index, false)
		await _settle(3)
	var completed := _surface_state(canvas)
	var completed_grade := str(completed.get("holdout_grade", ""))
	if completed_grade != "perfect":
		failures.append("Live HOLDOUT inputs did not grade perfect.")
		return
	_emit_surface_input("video_poker_draw", 0, false)
	await _wait_card_reveal()
	var result := _surface_state(canvas)
	var detail := str(result.get("result_detail", ""))
	if detail.find("SWAPPED IN ") < 0 or detail.find("RESULT:") < 0:
		failures.append("Live HOLDOUT result did not visibly name the swapped card and resulting hand: %s" % detail)
	await _save_shot("jacks_or_better_holdout_result")
	proof_rows.append({
		"control": "holdout",
		"input": "1280x720 mouse",
		"grade": completed_grade,
		"result_detail": detail,
		"blunt_feedback_visible": detail.find("SWAPPED IN ") >= 0 and detail.find("RESULT:") >= 0,
	})
	print("VP_PROOF: complete holdout feedback")


func _prove_abandoned_holdout_draw() -> void:
	print("VP_PROOF: begin unfinished holdout DRAW escape")
	if not await _prepare_video_poker(CABINETS[0]):
		return
	var canvas: Control = app.get("game_surface_canvas")
	_emit_surface_input("video_poker_deal", 0, false)
	await _wait_card_reveal()
	_emit_surface_input("video_poker_mark", 0, false)
	await _settle(3)
	_emit_surface_input("video_poker_draw", 0, false)
	await _wait_card_reveal()
	var result := _surface_state(canvas)
	if str(result.get("phase", "")) != "settled":
		failures.append("DRAW did not settle an unfinished HOLDOUT in one press.")
	if int(result.get("result_suspicion_delta", 0)) <= 0:
		failures.append("Unfinished HOLDOUT DRAW escape did not apply miss-grade Heat.")
	proof_rows.append({
		"control": "holdout_abandon_draw",
		"single_press_resolution": str(result.get("phase", "")) == "settled",
		"heat_applied": int(result.get("result_suspicion_delta", 0)),
	})
	print("VP_PROOF: complete unfinished holdout DRAW escape")


func _prove_double_up_pointer(touch: bool, input_label: String) -> void:
	_install_double_up_fixture()
	await _settle(8)
	var canvas: Control = app.get("game_surface_canvas")
	var ready := _surface_state(canvas)
	if not bool(ready.get("double_up_available", false)):
		failures.append("%s DOUBLE UP fixture did not expose the control." % input_label)
		return
	_emit_surface_input("video_poker_double", 0, touch)
	await _settle(8)
	var open := _surface_state(canvas)
	if str(open.get("phase", "")) != "double_up":
		failures.append("%s DOUBLE UP did not open the gamble." % input_label)
		return
	if not touch:
		await _save_shot("jacks_or_better_double_up_open")
	for pick_index in range(4):
		var position: Vector2 = canvas.call("local_position_for_surface_action", "video_poker_double_pick", pick_index)
		if position.x < 0.0 or position.y < 0.0:
			failures.append("%s double-up pick %d has no visible hit target." % [input_label, pick_index + 1])
	_emit_surface_input("video_poker_double_pick", 2, touch)
	await _wait_card_reveal()
	if str(_surface_state(canvas).get("phase", "")) == "double_up":
		failures.append("%s double-up pick did not resolve on the first press." % input_label)
	if not touch:
		await _save_shot("jacks_or_better_double_up_result")
	proof_rows.append({
		"control": "double_up",
		"input": input_label,
		"all_four_pick_targets_visible": true,
		"single_press_resolution": str(_surface_state(canvas).get("phase", "")) != "double_up",
	})


func _install_double_up_fixture() -> void:
	var run_state: RunState = app.get("run_state")
	var environment: Dictionary = run_state.current_environment.duplicate(true)
	var game_states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = game_states.get("video_poker", {})
	var hand := [
		{"rank": 11, "suit": 0},
		{"rank": 11, "suit": 1},
		{"rank": 5, "suit": 2},
		{"rank": 8, "suit": 3},
		{"rank": 13, "suit": 0},
	]
	machine["last_result"] = {
		"hand": hand,
		"hands": [hand],
		"hand_results": [{"hand": hand, "pay_key": "jacks_or_better", "pay_label": "Jacks or Better", "total": 10}],
		"pay_key": "jacks_or_better",
		"pay_label": "Jacks or Better",
		"bet_level": 4,
		"coin_count": 5,
		"coin_value": 1,
		"bet_credits": 5,
		"gross_credits": 10,
		"win_credits": 5,
		"double_credits": 5,
		"double_chain": 0,
		"bankroll_delta": 5,
		"summary": "Jacks or Better. Paid 10 credits.",
	}
	game_states["video_poker"] = machine
	environment["game_states"] = game_states
	run_state.current_environment = environment
	app.call("_clear_selected_game_action")
	app.set("game_surface_ui_state", {})
	app.call("_refresh")


func _prepare_video_poker(cabinet: Dictionary) -> bool:
	print("VP_PROOF: starting run for %s" % str(cabinet.get("id", "")))
	app.call("start_foundation_run", "VP-REBUILD-PROOF-%s" % str(cabinet.get("id", "")), {}, false)
	print("VP_PROOF: run started for %s" % str(cabinet.get("id", "")))
	await _settle(8)
	var environment := _environment_from_archetype("delta_queen")
	if environment.is_empty():
		failures.append("Could not build the proof casino environment.")
		return false
	environment["game_ids"] = ["video_poker"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	environment["game_states"] = {
		"video_poker": {
			"schema": "video_poker_machine_state",
			"version": 4,
			"cabinet_id": str(cabinet.get("id", "jacks_or_better")),
			"variant_id": str(cabinet.get("variant", "jacks_or_better")),
			"paytable_tier_id": "full_pay",
			"coin_denominations": [{"label": "1c", "credits": 1}],
			"denomination_index": 0,
			"multi_hand_count": int(cabinet.get("hands", 1)),
			"progressive_meter": 400,
			"hands_played": 0,
			"last_result": {},
		},
	}
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 5000
	run_state.set_environment(environment)
	app.call("_clear_selected_game_action")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle(8)
	app.call("enter_game", "video_poker", "video_poker")
	print("VP_PROOF: entered game request for %s" % str(cabinet.get("id", "")))
	await _settle(12)
	if str(app.get("current_screen")) != "GAME":
		failures.append("Could not enter the %s video poker cabinet." % str(cabinet.get("id", "")))
		return false
	return true


func _capture_slot_reference() -> void:
	app.call("start_foundation_run", "VP-REBUILD-SLOT-PARITY", {}, false)
	await _settle(8)
	var environment := _environment_from_archetype("gas_station_casino")
	if environment.is_empty():
		failures.append("Could not build the slot-parity environment.")
		return
	environment["game_ids"] = ["slot"]
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 5000
	run_state.set_environment(environment)
	app.call("_refresh")
	await _settle(8)
	app.call("enter_game", "slot", "slot")
	await _settle(14)
	if str(app.get("current_screen")) == "GAME":
		await _save_shot("slot_machine_live_reference")
	else:
		failures.append("Could not enter a live slot machine for parity capture.")


func _environment_from_archetype(archetype_id: String) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var run_state: RunState = app.get("run_state")
	if library == null or run_state == null:
		return {}
	var archetype: Dictionary = library.environment_archetype(archetype_id)
	if archetype.is_empty():
		return {}
	var rng: RngStream = run_state.create_rng("video_poker_proof_environment:%s" % archetype_id)
	var instance: EnvironmentInstance = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var environment := instance.to_dict()
	environment["world_node_id"] = archetype_id
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.save_rng(rng)
	return environment


func _emit_surface_input(action: String, index: int, touch: bool) -> void:
	var canvas: Control = app.get("game_surface_canvas")
	if canvas == null:
		failures.append("Game surface disappeared before %s." % action)
		return
	var position: Vector2 = canvas.call("local_position_for_surface_action", action, index)
	if position.x < 0.0 or position.y < 0.0:
		failures.append("Visible hit target missing for %s[%d]." % [action, index])
		return
	if touch:
		var touch_event := InputEventScreenTouch.new()
		touch_event.pressed = true
		touch_event.position = position
		canvas.call("_gui_input", touch_event)
		return
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = position
	canvas.call("_gui_input", mouse_event)


func _surface_state(canvas: Control) -> Dictionary:
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("state", {}) if typeof(snapshot.get("state", {})) == TYPE_DICTIONARY else {}


func _save_shot(file_id: String) -> void:
	# A headless renderer never emits frame_post_draw for this full-app capture.
	# Tick the real root viewport explicitly so the same harness works in local
	# QA and the unattended proof run without introducing a SubViewport copy.
	for _frame in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [ProjectSettings.globalize_path(output_dir), file_id]
	var error := image.save_png(path)
	if error != OK:
		failures.append("Could not save proof capture %s (error %d)." % [file_id, error])


func _write_report() -> void:
	var report := {
		"tool": "video_poker_rebuild_proof",
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"proof": proof_rows,
		"failures": failures,
		"passed": failures.is_empty(),
	}
	var file := FileAccess.open("%s/proof_report.json" % ProjectSettings.globalize_path(output_dir), FileAccess.WRITE)
	if file == null:
		failures.append("Could not write the rebuild proof report.")
		return
	file.store_string(JSON.stringify(report, "\t"))


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _wait_card_reveal() -> void:
	await create_timer(0.9).timeout
	await _settle(5)
