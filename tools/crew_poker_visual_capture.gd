extends SceneTree

# Deterministic, renderer-backed visual evidence for the Crew's five-card draw
# table. Run windowed so the viewport texture contains real rendered pixels.

const MainScene := preload("res://scenes/main.tscn")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const OUTPUT_DIR := "res://.tmp/crew_poker_visual_qa"
const MANIFEST_PATH := OUTPUT_DIR + "/manifest.json"
const CAPTURE_SIZE := Vector2i(1280, 720)
const TABLE_MEMBERS := ["crew_rook", "crew_velvet"]
const MIN_HIT_SIZE := 44.0

var app: Control
var canvas: Control
var run_state: RunState
var captures: Array[Dictionary] = []
var failed := false
var liveness_evidence: Dictionary = {}
var reduced_motion_evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#08070d"))
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "crew_poker_visual_capture")
	root.add_child(app)
	await _settle(8)
	app.call("start_game_test_session", "crew_draw_poker")
	await _settle(8)
	run_state = app.get("run_state") as RunState
	canvas = app.get("game_surface_canvas") as Control
	if run_state == null or canvas == null:
		_fail("Crew poker capture could not access the production run or table canvas.")
		_finish()
		return
	var table := _table()
	if table.is_empty():
		_fail("Crew poker capture could not access the generated table state.")
		_finish()
		return
	table["members"] = TABLE_MEMBERS.duplicate()
	for member_id in TABLE_MEMBERS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("associate"), "visual_capture_fixture")
	app.call("_refresh")
	await _settle(5)
	if not canvas.visible or str((canvas.call("realtime_surface_state") as Dictionary).get("surface_renderer", "")) != "crew_draw_poker":
		_fail("Crew poker capture did not route through the production table renderer.")
		_finish()
		return

	await _capture_surface(
		"01_entry_idle_1280x720.png",
		"entry_idle",
		["poker_deal", "poker_cash_out"],
		0
	)
	_capture_idle_liveness()

	if not bool(app.call("_handle_module_surface_action", "poker_deal", 0, false)):
		_fail("Crew poker capture could not resolve Ante & Deal through the production action path.")
	if not failed:
		await _settle(4)
		if not bool(app.call("_handle_module_surface_action", "poker_call", 0, false)):
			_fail("Crew poker capture could not resolve the opening call through the production action path.")
	if not failed:
		await _settle(4)
		app.call("_handle_module_surface_action", "poker_card", 0, false)
		app.call("_handle_module_surface_action", "poker_card", 2, false)
		await _settle(3)
		await _capture_surface(
			"02_active_draw_1280x720.png",
			"active_draw",
			["poker_draw", "poker_fold"],
			5
		)

	if not failed and not bool(app.call("_handle_module_surface_action", "poker_draw", 0, false)):
		_fail("Crew poker capture could not resolve the draw through the production action path.")
	if not failed:
		await _settle(4)
		table = _table()
		# Rook's second authored pattern is the portrait-channel chin/posture beat.
		table["beat"] = {"m": "crew_rook", "i": 1}
		app.call("_refresh")
		await _settle(4)
		var tell_state := canvas.call("realtime_surface_state") as Dictionary
		var observation: Dictionary = tell_state.get("observation", {}) if typeof(tell_state.get("observation", {})) == TYPE_DICTIONARY else {}
		if str(observation.get("channel", "")) != "portrait" \
				or str(observation.get("member_id", "")) != "crew_rook" \
				or str(observation.get("portrait_variant", "")) != "chin_down":
			_fail("Crew poker capture did not surface the authored subtle portrait presentation.")
		await _capture_surface(
			"03_authored_subtle_tell_1280x720.png",
			"authored_subtle_tell",
			["poker_call", "poker_raise", "poker_fold"],
			0
		)

	if not failed:
		var reduced_state := (canvas.call("realtime_surface_state") as Dictionary).duplicate(true)
		reduced_state["reduce_motion"] = true
		canvas.call("render_game_snapshot", reduced_state)
		await _settle(3)
		_capture_reduced_motion_stability()
		await _capture_surface(
			"04_reduced_motion_static_1280x720.png",
			"reduced_motion_static",
			["poker_call", "poker_raise", "poker_fold"],
			0
		)

	_finish()


func _capture_idle_liveness() -> void:
	canvas.call("reset_performance_counters")
	var before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after: Dictionary = canvas.call("debug_surface_motion_sample")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var passed := before != after and int(runtime.get("surface_animation_redraw_count", 0)) > 0
	liveness_evidence = {
		"passed": passed,
		"before": before,
		"after": after,
		"redraw_count": int(runtime.get("surface_animation_redraw_count", 0)),
	}
	if not passed:
		_fail("Crew poker idle lamp motion or redraw liveness did not advance.")


func _capture_reduced_motion_stability() -> void:
	canvas.call("reset_performance_counters")
	var before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after: Dictionary = canvas.call("debug_surface_motion_sample")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var passed := before == after \
		and int(runtime.get("surface_animation_redraw_count", 0)) == 0 \
		and bool(runtime.get("reduce_motion", false))
	reduced_motion_evidence = {
		"passed": passed,
		"before": before,
		"after": after,
		"redraw_count": int(runtime.get("surface_animation_redraw_count", 0)),
		"reduce_motion": bool(runtime.get("reduce_motion", false)),
	}
	if not passed:
		_fail("Crew poker reduced-motion renderer did not remain static.")


func _capture_surface(file_name: String, capture_id: String, expected_actions: Array, expected_card_targets: int) -> void:
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var state := canvas.call("realtime_surface_state") as Dictionary
	var view := canvas.call("current_view_snapshot") as Dictionary
	var poker_hits := _poker_hit_regions(view.get("surface_hit_actions", []))
	var target_evidence := _assert_hit_regions(poker_hits, expected_actions, expected_card_targets)
	var hidden_leaks := _hidden_label_leaks(state)
	if not bool(target_evidence.get("passed", false)):
		_fail("Crew poker %s capture failed hit-target bounds/overlap assertions." % capture_id)
	if not hidden_leaks.is_empty():
		_fail("Crew poker %s capture exposed hidden authored labels." % capture_id)
	var image := root.get_viewport().get_texture().get_image()
	var saved := false
	if image == null:
		_fail("Crew poker viewport capture is unavailable; run the helper windowed.")
	else:
		if image.get_size() != CAPTURE_SIZE:
			image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
		var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
		saved = error == OK
		if not saved:
			_fail("Could not save Crew poker capture %s (error %d)." % [file_name, error])
	captures.append({
		"id": capture_id,
		"file": file_name,
		"saved": saved,
		"phase": str(state.get("phase", "")),
		"renderer": str(state.get("surface_renderer", "")),
		"hit_targets": target_evidence,
		"hidden_labels_absent": hidden_leaks.is_empty(),
		"hidden_label_offenders": hidden_leaks,
		"observation_channel": str((state.get("observation", {}) as Dictionary).get("channel", "")) if typeof(state.get("observation", {})) == TYPE_DICTIONARY else "",
		"reduce_motion": bool(state.get("reduce_motion", false)),
	})


func _assert_hit_regions(hits: Array, expected_actions: Array, expected_card_targets: int) -> Dictionary:
	var board := Rect2(Vector2.ZERO, canvas.call("surface_board_size") as Vector2)
	var actions: Array[String] = []
	var card_targets := 0
	var bounds_passed := true
	var size_passed := true
	var overlap_passed := true
	var snapshots: Array[Dictionary] = []
	for hit_value in hits:
		var hit: Dictionary = hit_value
		var rect: Rect2 = hit.get("rect", Rect2())
		var action := str(hit.get("action", ""))
		actions.append(action)
		if action == "poker_card":
			card_targets += 1
		bounds_passed = bounds_passed and rect.size.x > 0.0 and rect.size.y > 0.0 and board.encloses(rect)
		size_passed = size_passed and rect.size.x >= MIN_HIT_SIZE and rect.size.y >= MIN_HIT_SIZE
		snapshots.append({
			"action": action,
			"index": int(hit.get("index", -1)),
			"rect": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
		})
	for first_index in range(hits.size()):
		var first_rect: Rect2 = (hits[first_index] as Dictionary).get("rect", Rect2())
		for second_index in range(first_index + 1, hits.size()):
			var second_rect: Rect2 = (hits[second_index] as Dictionary).get("rect", Rect2())
			if first_rect.intersects(second_rect):
				overlap_passed = false
	var actions_passed := true
	for expected_value in expected_actions:
		actions_passed = actions_passed and actions.has(str(expected_value))
	var card_count_passed := card_targets == expected_card_targets
	return {
		"passed": bounds_passed and size_passed and overlap_passed and actions_passed and card_count_passed,
		"bounds_passed": bounds_passed,
		"minimum_size_passed": size_passed,
		"no_overlap_passed": overlap_passed,
		"expected_actions_passed": actions_passed,
		"card_target_count_passed": card_count_passed,
		"card_target_count": card_targets,
		"targets": snapshots,
	}


func _poker_hit_regions(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for hit_value in value as Array:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		if str(hit.get("action", "")).begins_with("poker_"):
			result.append(hit)
	return result


func _hidden_label_leaks(surface_state: Dictionary) -> Array[Dictionary]:
	# Hidden schema names must be exact dictionary keys. A substring scan would
	# incorrectly classify public fields such as `alcohol_condition` as the
	# private authored `condition` key.
	var forbidden_keys: Array[String] = ["state_key", "condition", "frequency_percent", "learned_exposures", "tell_learned"]
	var state_tokens: Array[String] = []
	var condition_tokens: Array[String] = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		for pattern_value in CrewPokerModelScript.patterns(member_id):
			if typeof(pattern_value) != TYPE_DICTIONARY:
				continue
			var pattern: Dictionary = pattern_value
			var state_token := str(pattern.get("state_key", ""))
			var condition_token := str(pattern.get("condition", ""))
			if not state_token.is_empty() and not state_tokens.has(state_token):
				state_tokens.append(state_token)
			if not condition_token.is_empty() and not condition_tokens.has(condition_token):
				condition_tokens.append(condition_token)
	var leaks: Array[Dictionary] = []
	_audit_hidden_labels(surface_state, "$", forbidden_keys, state_tokens, condition_tokens, leaks)
	return leaks


func _audit_hidden_labels(value: Variant, path: String, forbidden_keys: Array[String], state_tokens: Array[String], condition_tokens: Array[String], leaks: Array[Dictionary]) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var source := value as Dictionary
			for raw_key in source.keys():
				var key := str(raw_key)
				var child_path := "%s.%s" % [path, key]
				if forbidden_keys.has(key):
					leaks.append({"kind": "hidden_field", "path": child_path, "token": key})
				_audit_hidden_labels(source.get(raw_key), child_path, forbidden_keys, state_tokens, condition_tokens, leaks)
		TYPE_ARRAY:
			var source := value as Array
			for index in range(source.size()):
				_audit_hidden_labels(source[index], "%s[%d]" % [path, index], forbidden_keys, state_tokens, condition_tokens, leaks)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			# Opaque state ids are unique and remain forbidden even when accidentally
			# embedded in a longer public label. Generic authored conditions are only
			# failures when projected as their own structured/public string value.
			for token in state_tokens:
				if text.contains(token):
					leaks.append({"kind": "authored_state_token", "path": path, "token": token})
			for token in condition_tokens:
				if text == token:
					leaks.append({"kind": "authored_condition_value", "path": path, "token": token})


func _table() -> Dictionary:
	if run_state == null:
		return {}
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get("crew_draw_poker", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _write_manifest() -> void:
	var files_passed := captures.size() == 4
	var layout_and_targets_passed := captures.size() == 4
	var hidden_labels_passed := captures.size() == 4
	for capture in captures:
		files_passed = files_passed and bool(capture.get("saved", false))
		layout_and_targets_passed = layout_and_targets_passed and bool((capture.get("hit_targets", {}) as Dictionary).get("passed", false))
		hidden_labels_passed = hidden_labels_passed and bool(capture.get("hidden_labels_absent", false))
	var manifest := {
		"tool": "crew_poker_visual_capture",
		"fixture": "Crew five-card draw production renderer",
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"passed": not failed and files_passed and layout_and_targets_passed and hidden_labels_passed \
			and bool(liveness_evidence.get("passed", false)) \
			and bool(reduced_motion_evidence.get("passed", false)),
		"captures": captures,
		"assertions": {
			"all_pngs_saved": files_passed,
			"bounds_no_overlap_and_hit_targets": layout_and_targets_passed,
			"idle_liveness_advances": liveness_evidence,
			"reduced_motion_static": reduced_motion_evidence,
			"hidden_authored_labels_absent": hidden_labels_passed,
		},
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write Crew poker visual capture manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish() -> void:
	_write_manifest()
	var exit_code := 1 if failed else 0
	print("CREW_POKER_VISUAL_CAPTURE_%s captures=%d dir=%s" % ["PASS" if exit_code == 0 else "FAIL", captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	quit(exit_code)
