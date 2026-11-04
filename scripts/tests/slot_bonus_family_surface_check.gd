extends SceneTree

# Synthetic recorded producers, production module/renderer/Canvas, real draw
# callbacks and InputEventScreenTouch. No manually published hits or draw stub.
# Run with a rendering-capable native backend; absent draws fail this contract.
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Slot := preload("res://scripts/games/slot.gd")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Generator := preload("res://scripts/games/slots/slot_machine_generator.gd")
const Pinball := preload("res://scripts/games/slots/slot_family_pinball.gd")
const Feature := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const Library := preload("res://scripts/core/content_library.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const FORMATS := ["classic_3_reel", "line_5x3", "video_feature"]
const TAGS := ["canonical", "missing", "empty"]
const NATIVE_CHOICES := {"slot_bonus_start_": 25, "slot_bonus_aim_": 25, "slot_bonus_power_": 21}

var checks := 0
var failures: Array[String] = []
var facts: Array = []
var library
var definition: Dictionary = {}
var completed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _private_roots():
		_finish()
		return
	library = Library.new()
	library.load()
	definition = library.game("slot")
	if not _check(not definition.is_empty(), "authored Slot definition loads"):
		_finish()
		return
	for format_id in FORMATS:
		var fixture := _fixture(str(format_id))
		var canonical_hits: Array = []
		for tag in TAGS:
			var result: Dictionary = await _check_surface(fixture, str(format_id), str(tag), false)
			if tag == "canonical":
				canonical_hits = result.get("hits", [])
			else:
				_check(result.get("hits", []) == canonical_hits, "%s/%s recovered native geometry equals canonical" % [format_id, tag])
		for tag in ["missing", "empty"]:
			await _check_surface(fixture, str(format_id), str(tag), true)
		await _check_realtime_recovery_transition(fixture, str(format_id))
	Feature.clear_runtime_session_cache()
	completed = true
	_finish()


func _fixture(format_id: String) -> Dictionary:
	var run := RunState.new()
	run.start_new("SLOT-FAMILY-SURFACE:" + format_id)
	run.bankroll = 100000
	run.grand_casino_chips = 25
	run.set_environment({"id": "slot_family_surface", "archetype_id": "bar", "kind": "casino", "game_ids": ["slot"], "game_states": {}, "economic_profile": {"stake_floor": 2, "stake_ceiling": 60}, "security_profile": {"risk": "loose"}})
	var machine: Dictionary = Generator.new().build_machine_from_ids(definition, {"format_id": format_id, "type_id": "pinball", "math_variant_id": "standard", "bonus_variant_id": "plain", "cabinet_variant_id": "neon_magenta"}, run.create_rng("recorded_machine"))
	machine = State.set_selected_bet(machine, "bet_10")
	var active: Dictionary = Pinball.new().open_feature(machine, 10, run.create_rng("recorded_feature"), definition)
	machine["active_bonus"] = active
	# Start after the finite trigger reveal. Idle scheduling stays production-owned.
	machine["slot_animation_id"] = ""
	machine["slot_bonus_trigger_revealed"] = true
	State.write_machine(run.current_environment, "slot", machine)
	return {"run": run.to_dict(), "machine": State.peek_machine(run.current_environment, "slot").duplicate(true), "runtime": Feature.runtime_transaction_checkpoint(active)}


func _check_surface(fixture: Dictionary, format_id: String, tag: String, invalid: bool) -> Dictionary:
	var label := "%s/%s/%s" % [format_id, "invalid" if invalid else "recoverable", tag]
	Feature.clear_runtime_session_cache()
	var run := RunState.new()
	run.from_dict(fixture.run)
	var machine: Dictionary = fixture.machine.duplicate(true)
	var active: Dictionary = machine.active_bonus
	if tag == "missing":
		active.erase("family")
	elif tag == "empty":
		active["family"] = ""
	if invalid:
		# A lost tag cannot authorize a fresh physics session from an absent seed.
		active["runtime_seed"] = 0
	State.write_machine(run.current_environment, "slot", machine)
	if tag == "missing":
		run.current_environment.game_states.slot.active_bonus.erase("family")
	if not invalid:
		_check(Feature.restore_runtime_transaction_checkpoint(active, fixture.runtime), label + " restores identical recorded warm runtime")
	var raw_before := Runtime.canonical_fingerprint(State.peek_machine(run.current_environment, "slot"))
	var economy_before := _economy_guard(run)
	var game := Slot.new()
	game.setup(definition, library)
	var snapshot: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 1000})
	_check(str(snapshot.get("slot_format_id", "")) == format_id, label + " retains recorded format")
	_check(bool(snapshot.get("slot_bonus_recovery_required", false)) == invalid, label + " reports exact recovery requirement")
	if invalid:
		_check(not str(snapshot.get("slot_bonus_recovery_message", "")).is_empty(), label + " explains recovery without discarding progress")
	else:
		var shown: Dictionary = snapshot.get("slot_active_bonus", {})
		_check(str(shown.get("family", "")) == "pinball" and bool(shown.get("active", false)), label + " presents active recorded Pinball")
	var canvas := Canvas.new()
	canvas.size = Vector2(960, 540)
	root.add_child(canvas)
	await process_frame
	var emitted: Array = []
	var blocked: Array = []
	canvas.surface_action.connect(func(action: String, index: int, confirmed: bool): emitted.append({"action": action, "index": index, "confirmed": confirmed}))
	canvas.surface_action_blocked.connect(func(action: String, reason: String): blocked.append({"action": action, "reason": reason}))
	canvas.set_game_module(game)
	var previous_draws: int = canvas.perf_draw_frame_total_count
	canvas.render_game_snapshot(snapshot)
	# The first 520 ms animate the camera and its 25 playfield start targets.
	# Compare every real hit only after that authored transition has settled and
	# a further autonomous draw has published its settled geometry. Do not change
	# the channel, clock, process flag or redraw cadence to align independent cases.
	var settled_draws := -1
	var settled_geometry_observed := false
	var draw_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < draw_deadline:
		await process_frame
		if not invalid and canvas.surface_elapsed("slot_feature") < 0.520:
			continue
		if settled_draws < 0:
			settled_draws = canvas.perf_draw_frame_total_count
			continue
		if canvas.perf_draw_frame_total_count > settled_draws and canvas.hit_region_state_revision == canvas.surface_state_revision:
			settled_geometry_observed = true
			break
	var observed := int(canvas.perf_draw_frame_total_count) > previous_draws
	_check(observed, label + " executes the actual Canvas draw callback")
	_check(settled_geometry_observed, label + " autonomously draws after the authored camera transition")
	_check(canvas.hit_region_state_revision == canvas.surface_state_revision, label + " publishes hits for the current snapshot")
	var hits := _hit_receipt(canvas.hit_regions)
	var expected := ["surface_back"] if invalid else _native_actions()
	var actual := _unique_actions(canvas.hit_regions)
	_check(actual == expected, label + " publishes exactly Leave-only recovery or native prelaunch controls")
	for action in expected:
		_check(canvas.global_rect_for_surface_action(str(action)).has_area(), label + " has real published geometry for " + str(action))
	for action in ["slot_spin", "slot_bet", "slot_auto_toggle", "slot_bonus_left", "slot_bonus_right", "slot_bonus_tilt"]:
		_check(not canvas.global_rect_for_surface_action(str(action)).has_area(), label + " exposes no obsolete or base-machine target " + str(action))
	if invalid:
		_check(canvas.hit_regions.size() == 1, label + " has one Leave hit and no hidden actionable controls")
		# Poke the former prototype row's launch location, as well as the current
		# native launch location. Neither can dispatch while recovery is required.
		var skin: Dictionary = snapshot.get("slot_skin", {})
		var controls: Dictionary = skin.get("controls", {})
		var old_launch := Vector2(float(controls.get("x", 0)) + 300.0, float(controls.get("y", 0)) + 38.0)
		_touch(canvas, canvas._board_to_screen(old_launch))
		_touch(canvas, canvas._board_to_screen(Vector2(825, 483)))
		_check(emitted.is_empty() and blocked.is_empty(), label + " stale prototype and native launch locations cannot dispatch")
		_touch_action(canvas, "surface_back", -1, emitted, label)
	else:
		# Exercise physical touch dispatch at both ends and the middle of each
		# exact-hit choice strip, plus the current native launch and Leave buttons.
		for prefix in NATIVE_CHOICES:
			var count := int(NATIVE_CHOICES[prefix])
			for index in [0, count / 2, count - 1]:
				_touch_action(canvas, "%s%02d" % [prefix, int(index)], int(index), emitted, label)
		_touch_action(canvas, "slot_bonus_launch", 0, emitted, label)
		_touch_action(canvas, "surface_back", -1, emitted, label)
	_check(blocked.is_empty(), label + " does not block its published native controls")
	_check(_economy_guard(run) == economy_before, label + " draw and touch routing preserve wallets RNG clocks turns and history")
	_check(Runtime.canonical_fingerprint(State.peek_machine(run.current_environment, "slot")) == raw_before, label + " draw and touch routing preserve the complete raw recorded machine")
	facts.append({"case": label, "draw_observed": observed, "settled_geometry_observed": settled_geometry_observed, "feature_elapsed_msec": int(round(canvas.surface_elapsed("slot_feature") * 1000.0)), "draw_count": canvas.perf_draw_frame_total_count - previous_draws, "hit_count": canvas.hit_regions.size(), "hits": hits, "actions": actual, "touches": emitted, "recovery_required": snapshot.get("slot_bonus_recovery_required", false)})
	canvas.clear_runtime_state()
	canvas.queue_free()
	await process_frame
	return {"hits": hits}


func _check_realtime_recovery_transition(fixture: Dictionary, format_id: String) -> void:
	var label := format_id + "/same-canvas-realtime-transition"
	Feature.clear_runtime_session_cache()
	var run := RunState.new()
	run.from_dict(fixture.run)
	var valid_raw: Dictionary = fixture.machine.duplicate(true)
	valid_raw.active_bonus["family"] = ""
	# Deliberate test-fixture swaps only: a lost tag with the recorded header and
	# known runtime, then that same header with seed zero, then the original header.
	# They model an external repair between queries, never a gameplay resumption.
	run.current_environment.game_states["slot"] = valid_raw.duplicate(true)
	_check(Feature.restore_runtime_transaction_checkpoint(valid_raw.active_bonus, fixture.runtime), label + " installs the exact recorded runtime checkpoint")
	var simulation_before := Runtime.canonical_fingerprint(fixture.runtime.get("sim", {}))
	var economy_before := _economy_guard(run)
	var game := Slot.new()
	game.setup(definition, library)
	var canvas := Canvas.new()
	canvas.size = Vector2(960, 540)
	root.add_child(canvas)
	await process_frame
	var emitted: Array = []
	var blocked: Array = []
	canvas.surface_action.connect(func(action: String, index: int, confirmed: bool): emitted.append({"action": action, "index": index, "confirmed": confirmed}))
	canvas.surface_action_blocked.connect(func(action: String, reason: String): blocked.append({"action": action, "reason": reason}))
	canvas.set_game_module(game)
	var valid_fingerprint := Runtime.canonical_fingerprint(valid_raw)
	canvas.render_game_snapshot(game.surface_state(run, run.current_environment, {"surface_time_msec": 1000}))
	_check(await _await_transition_draw(canvas, true), label + " initial Pinball draws autonomously after its camera settles")
	_check_transition_native(canvas, emitted, label + "/initial")
	var initial_hits := _hit_receipt(canvas.hit_regions)
	var initial_structure := _transition_structure(canvas.state)
	_check(Runtime.canonical_fingerprint(State.peek_machine(run.current_environment, "slot")) == valid_fingerprint, label + " initial view leaves the entire raw lost-tag record exact")
	_check(_economy_guard(run) == economy_before, label + " initial draw and touch preserve account RNG and clocks")
	var invalid_raw := valid_raw.duplicate(true)
	invalid_raw.active_bonus["runtime_seed"] = 0
	run.current_environment.game_states["slot"] = invalid_raw
	var invalid_fingerprint := Runtime.canonical_fingerprint(invalid_raw)
	var recovery_patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, {"surface_time_msec": 1032}, canvas.state)
	_check(bool(recovery_patch.get("slot_bonus_recovery_required", false)), label + " realtime invalid header requests recovery")
	_check(str(recovery_patch.get("slot_cabinet_identity", "")) == "slot_bonus_recovery", label + " recovery patch changes the structural cabinet identity")
	_check(not str(recovery_patch.get("slot_cabinet_signature", "")).is_empty() and str(recovery_patch.get("slot_cabinet_signature", "")) != str(initial_structure.get("slot_cabinet_signature", "")), label + " recovery patch changes the structural signature")
	canvas.apply_surface_state_patch(recovery_patch)
	_check(await _await_transition_draw(canvas, false), label + " same Canvas actually draws recovery")
	_check(canvas.hit_regions.size() == 1 and _unique_actions(canvas.hit_regions) == ["surface_back"], label + " recovery publishes exactly one Leave target")
	_check((canvas.state.get("slot_skin", {}) as Dictionary).is_empty() and (canvas.state.get("surface_animation_channels", []) as Array).is_empty() and (canvas.state.get("surface_action_bindings", {}) as Dictionary).is_empty(), label + " recovery clears the preceding skin channels and bindings")
	_check((canvas.state.get("surface_audio", {}) as Dictionary).is_empty(), label + " recovery clears the preceding native audio profile")
	var before_stale_touch := emitted.size()
	_touch(canvas, canvas._board_to_screen(Vector2(825, 483)))
	_check(emitted.size() == before_stale_touch, label + " prior native Launch location cannot dispatch during recovery")
	_touch_action(canvas, "surface_back", -1, emitted, label + "/recovery")
	var recovery_hits := _hit_receipt(canvas.hit_regions)
	_check(Runtime.canonical_fingerprint(State.peek_machine(run.current_environment, "slot")) == invalid_fingerprint, label + " recovery query and touch preserve the complete deliberately invalid record")
	_check(_economy_guard(run) == economy_before, label + " recovery draw and touch preserve account RNG and clocks")
	_check(Runtime.canonical_fingerprint(Feature.runtime_transaction_checkpoint(valid_raw.active_bonus).get("sim", {})) == simulation_before, label + " recovery never advances or replaces the known recorded physics")
	# Restore exact producer input and exact known solver state. No seed, board,
	# award or physics progress is generated to make the repaired view admissible.
	run.current_environment.game_states["slot"] = valid_raw.duplicate(true)
	_check(Feature.restore_runtime_transaction_checkpoint(valid_raw.active_bonus, fixture.runtime), label + " fixture restores the original recorded runtime without generating physics")
	var restored_patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, {"surface_time_msec": 1000}, canvas.state)
	_check(not bool(restored_patch.get("slot_bonus_recovery_required", true)), label + " restored recorded header exits recovery")
	_check(restored_patch.has("slot_skin") and restored_patch.has("surface_animation_channels") and restored_patch.has("surface_action_bindings"), label + " restored realtime patch provides a full structural Pinball replacement")
	_check(str(restored_patch.get("slot_cabinet_identity", "")) == "pinball", label + " restored patch selects native Pinball identity")
	canvas.apply_surface_state_patch(restored_patch)
	_check(await _await_transition_draw(canvas, true), label + " same Canvas draws the restored Pinball after its camera settles")
	_check_transition_native(canvas, emitted, label + "/restored")
	_check(_hit_receipt(canvas.hit_regions) == initial_hits, label + " restored Canvas republishes all 98 original native hit rectangles")
	_check(_transition_structure(canvas.state) == initial_structure, label + " restored skin channels bindings signature and audio structure equal the initial native state")
	_check(canvas.surface_animation_channels.has("slot_feature"), label + " restored Canvas installs its live native feature animation channel")
	_check(Runtime.canonical_fingerprint(State.peek_machine(run.current_environment, "slot")) == valid_fingerprint, label + " restored query and touch leave every raw recorded field exact")
	_check(_economy_guard(run) == economy_before, label + " the full in-place transition preserves account RNG and clocks")
	_check(Runtime.canonical_fingerprint(Feature.runtime_transaction_checkpoint(valid_raw.active_bonus).get("sim", {})) == simulation_before, label + " restored query and touch preserve the original recorded simulation")
	_check(blocked.is_empty(), label + " published transition controls remain touchable")
	facts.append({"case": label, "fixture_swaps": "exact recorded lost-tag header -> same header with runtime_seed zero -> original header and runtime checkpoint", "initial_hits": initial_hits, "recovery_hits": recovery_hits, "restored_hits": _hit_receipt(canvas.hit_regions), "restored_feature_elapsed_msec": int(round(canvas.surface_elapsed("slot_feature") * 1000.0)), "touches": emitted, "structural_roundtrip_equal": _transition_structure(canvas.state) == initial_structure})
	canvas.clear_runtime_state()
	canvas.queue_free()
	await process_frame
	Feature.clear_runtime_session_cache()


func _await_transition_draw(canvas: Control, settle_camera: bool) -> bool:
	var settled_draws := -1
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if settle_camera and canvas.surface_elapsed("slot_feature") < 0.520:
			continue
		if settled_draws < 0:
			settled_draws = canvas.perf_draw_frame_total_count
			continue
		if canvas.perf_draw_frame_total_count > settled_draws and canvas.hit_region_state_revision == canvas.surface_state_revision:
			return true
	return false


func _check_transition_native(canvas: Control, emitted: Array, label: String) -> void:
	_check(canvas.hit_regions.size() == 98 and _unique_actions(canvas.hit_regions) == _native_actions(), label + " publishes all 98 current native hits and the complete prelaunch action set")
	for action in _native_actions():
		_check(canvas.global_rect_for_surface_action(str(action)).has_area(), label + " publishes current geometry for " + str(action))
	for prefix in NATIVE_CHOICES:
		var count := int(NATIVE_CHOICES[prefix])
		for index in [0, count / 2, count - 1]:
			_touch_action(canvas, "%s%02d" % [prefix, int(index)], int(index), emitted, label)
	_touch_action(canvas, "slot_bonus_launch", 0, emitted, label)
	_touch_action(canvas, "surface_back", -1, emitted, label)


func _transition_structure(state: Dictionary) -> Dictionary:
	var result := {}
	for key in ["slot_cabinet_identity", "slot_cabinet_title", "slot_cabinet_signature", "slot_skin", "surface_animation_channels", "surface_action_bindings", "surface_audio"]:
		result[key] = state.get(key, null)
	return result.duplicate(true)


func _native_actions() -> Array:
	var actions := ["surface_back", "slot_bonus_launch"]
	for prefix in NATIVE_CHOICES:
		for index in range(int(NATIVE_CHOICES[prefix])):
			actions.append("%s%02d" % [prefix, index])
	actions.sort()
	return actions


func _unique_actions(regions: Array) -> Array:
	var actions: Array = []
	for region in regions:
		var action := str(region.get("action", ""))
		if not actions.has(action):
			actions.append(action)
	actions.sort()
	return actions


func _hit_receipt(regions: Array) -> Array:
	var receipt: Array = []
	for region in regions:
		var rect: Rect2 = region.get("rect", Rect2())
		receipt.append({"action": str(region.get("action", "")), "index": int(region.get("index", -1)), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	return receipt


func _touch_action(canvas: Control, action: String, index: int, emitted: Array, label: String) -> void:
	# Start choices also appear on the playfield rail. Select the last published
	# native control, matching Canvas hit priority and exercising the choice strip.
	var position := Vector2(-1, -1)
	for region_index in range(canvas.hit_regions.size() - 1, -1, -1):
		var region: Dictionary = canvas.hit_regions[region_index]
		if str(region.get("action", "")) == action and int(region.get("index", -1)) == index:
			var rect: Rect2 = region.get("rect", Rect2())
			position = canvas._board_to_screen(rect.get_center())
			break
	if not _check(position.x >= 0.0 and position.y >= 0.0, label + " locates rendered touch target " + action):
		return
	var before := emitted.size()
	_touch(canvas, position)
	_check(emitted.size() == before + 1 and str(emitted.back().action) == action and int(emitted.back().index) == index and not bool(emitted.back().confirmed), label + " physical touch dispatches exactly once to " + action)


func _touch(canvas: Control, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.index = 0
		event.pressed = pressed
		canvas._gui_input(event)


func _economy_guard(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "town": run.town_state.snapshot() if run.town_state != null else {}, "history": run.story_log.duplicate(true), "environment_turns": run.current_environment.get("turns", 0)}


func _private_roots() -> bool:
	var private_root := OS.get_environment("BTH_SLOT_FAMILY_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"):
		return false
	for key in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key):
			return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured player save or browser profile accepted")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested real-canvas matrix reaches final assertion")
	var report := {"id": "BTH061-AUDIT-SLOT-LEGACY-FAMILY-004", "stage": "family-real-surface", "checks": checks, "failures": failures, "facts": facts, "display_server": DisplayServer.get_name(), "source_sha256": {"slot": FileAccess.get_sha256("res://scripts/games/slot.gd"), "renderer": FileAccess.get_sha256("res://scripts/games/slots/slot_renderer.gd"), "canvas": FileAccess.get_sha256("res://scripts/ui/game_surface_canvas.gd"), "test": FileAccess.get_sha256("res://scripts/tests/slot_bonus_family_surface_check.gd")}, "fidelity": "Synthetic recorded Pinball producers in all three formats. Actual production Canvas draw, renderer hit publication and physical InputEventScreenTouch routing. Signals are observed without resolving game actions; no original save, browser input or completed physics-play claim. Missing draw callbacks fail explicitly."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("SLOT_BONUS_FAMILY_SURFACE_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
