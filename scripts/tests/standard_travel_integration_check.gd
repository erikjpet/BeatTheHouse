extends SceneTree

# Production-host tests and Movie Maker capture. Every fixture is an enabled
# route in an ordinary generated world; no graph, route, wallet or clock edits.
const MainScene := preload("res://scenes/main.tscn")
const Generator := preload("res://scripts/core/run_generator.gd")
const World := preload("res://scripts/core/world_map.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const MODES := ["walk", "bus", "taxi", "night_cab"]
const HOMES := ["back_alley", "apartment", "motel_room", "house"]
const SHARED_DURATION := 8.0
# Discovered through bounded production starts and legal travel (see finder).
# These are replay recipes, never synthetic map or route fixtures.
const KNOWN_FIXTURES := {
	"walk":{"seed":"STANDARD-TRAVEL-apartment-0", "home":"apartment", "steps":["bar"], "target":"back_alley"},
	"bus":{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":[], "target":"corner_store"},
	"taxi":{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":[], "target":"gas_station_casino"},
	"night_cab":{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":["gas_station_casino", "motel"], "target":"bar"},
}
var failures: Array[String] = []
var checks := 0
var app: Control
var fixtures: Dictionary = {}
var completion_count := 0
var shared_ui_contract: Dictionary = {}
var requested_modes: Array = MODES

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _state(run: RunState) -> Dictionary:
	var travel_entries := 0
	for entry in run.story_log:
		if entry is Dictionary and str(entry.get("type", "")) in ["travel", "travel_risk_event"]:
			travel_entries += 1
	return {"bankroll":run.bankroll, "clock":run.game_clock_minutes, "node":run.current_world_node_id(), "count":run.environment_travel_count(), "rng_seed":run.rng_seed, "rng_state":run.rng_state, "suspicion":run.suspicion.duplicate(true), "drunk_level":run.drunk_level, "pending_events":run.pending_triggered_events.duplicate(true), "active_event":run.active_triggered_event.duplicate(true), "travel_log_entries":travel_entries}

func _menu_travel(target: String, require_immediate_result: bool = false) -> Dictionary:
	# Exercise the public menu boundary. Never forge the presentation opt-in.
	return {"ok":app.select_travel_option(target) and app.confirm_selected_travel(require_immediate_result)}

func _same_saved_values(a: Variant, b: Variant) -> bool:
	# The production JSON codec can represent nested integer cue values as
	# floats after loading. Compare their exact numeric values, not Dictionary's
	# strict nested Variant tags. Do not use tolerances or discard any fields.
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_saved_values(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same_saved_values(a[index], b[index]): return false
		return true
	return a == b

func _run() -> void:
	var selected_mode := ""
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--capture-mode="):
			selected_mode = argument.trim_prefix("--capture-mode=")
	if not selected_mode.is_empty() and selected_mode not in MODES:
		push_error("--capture-mode must be walk, bus, taxi or night_cab")
		quit(1)
		return
	app = MainScene.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	requested_modes = MODES if selected_mode.is_empty() else [selected_mode]
	_discover_fixtures()
	var selected_modes: Array = requested_modes
	for mode in selected_modes:
		_expect(fixtures.has(mode), "actual generated enabled " + mode + " fixture found")
	if failures.is_empty() and "--find-fixtures" not in arguments:
		app._build_travel_cinematic_overlay()
		app.travel_cinematic_overlay.completed.connect(_on_presentation_completed)
		if "--capture-standard" in arguments:
			await _capture(selected_mode if not selected_mode.is_empty() else "bus")
		else:
			for mode in selected_modes:
				await _test_mode(mode)
			_test_local_door_excluded()
	var suite := "standard_travel_fixture_discovery" if "--find-fixtures" in arguments else "standard_travel_capture" if "--capture-standard" in arguments else "standard_travel_integration"
	print(JSON.stringify({"suite":suite, "checks":checks, "passed":failures.is_empty(), "failures":failures, "found":fixtures.keys(), "selected_modes":selected_modes, "shared_ui_contract":shared_ui_contract}))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)

func _discover_fixtures() -> void:
	for mode in requested_modes:
		var recipe: Dictionary = KNOWN_FIXTURES[mode]
		app._cancel_travel_presentation()
		if not app.start_foundation_run(recipe["seed"], {"modifiers":{"home_archetype_id":recipe["home"]}}, false): continue
		var replay_ok := true
		for target in recipe["steps"]:
			var step_choice: Dictionary = app._travel_choice(target)
			if not bool(step_choice.get("enabled", false)):
				replay_ok = false
				break
			var step_result: Dictionary = app._travel_to(target, str(step_choice.get("label", "")), step_choice, true)
			if not bool(step_result.get("ok", false)):
				replay_ok = false
				break
			if app.travel_presentation_active:
				app.travel_cinematic_overlay.skip_to_receipt()
				app.travel_cinematic_overlay.acknowledge()
		if not replay_ok: continue
		var choice: Dictionary = app._travel_choice(recipe["target"])
		if not bool(choice.get("enabled", false)) or World.travel_method_kind(choice.get("route", {})) != mode: continue
		var before: Dictionary = app.run_state.to_dict()
		var result: Dictionary = app._travel_to(recipe["target"], str(choice.get("label", "")), choice, true)
		var receipt: Dictionary = app.run_state.travel_journey_receipt
		if bool(result.get("ok", false)) and not receipt.is_empty() and not bool(receipt.get("route_risk", {}).get("triggered", false)):
			fixtures[mode] = {"baseline":before, "choice":choice.duplicate(true), "seed":recipe["seed"], "home":recipe["home"], "steps":recipe["steps"].duplicate()}
			print(JSON.stringify({"fixture_mode":mode, "seed":recipe["seed"], "home":recipe["home"], "steps":recipe["steps"], "source":receipt.get("origin_node_id"), "target":recipe["target"], "clock":before["game_clock_minutes"], "cost":choice.get("cost"), "travel_minutes":choice.get("travel_minutes"), "route":choice.get("route", {}), "receipt":receipt}))
	if _all_requested_found(): return
	for seed_index in range(4):
		for home in HOMES:
			if _all_requested_found(): return
			var seed_text := "STANDARD-TRAVEL-%s-%d" % [home, seed_index]
			if not app.start_foundation_run(seed_text, {"modifiers":{"home_archetype_id":home}}, false):
				continue
			var queue: Array = [{"baseline":app.run_state.to_dict(), "steps":[]}]
			var visited: Dictionary = {}
			var explored := 0
			while not queue.is_empty() and explored < 64:
				if _all_requested_found(): return
				var entry: Dictionary = queue.pop_front()
				_restore(entry["baseline"])
				var source_id: String = app.run_state.current_world_node_id()
				if visited.has(source_id): continue
				visited[source_id] = true
				explored += 1
				var candidates: Array = app._travel_choice_view_list().duplicate(true)
				for candidate in candidates:
					if not bool(candidate.get("enabled", false)): continue
					_restore(entry["baseline"])
					var target_id := str(candidate.get("id", ""))
					var choice: Dictionary = app._travel_choice(target_id)
					var route: Dictionary = choice.get("route", {})
					var mode := World.travel_method_kind(route)
					var before: Dictionary = app.run_state.to_dict()
					var result: Dictionary = app._travel_to(target_id, str(choice.get("label", "")), choice, true)
					if not bool(result.get("ok", false)): continue
					var receipt: Dictionary = app.run_state.travel_journey_receipt
					var local_route := bool(choice.get("local_door", false)) or str(route.get("travel_method", "")).to_lower() in ["door", "inside", "begin"]
					if mode in requested_modes and not fixtures.has(mode) and not local_route and not receipt.is_empty() and not bool(receipt.get("route_risk", {}).get("triggered", false)):
						fixtures[mode] = {"baseline":before, "choice":choice.duplicate(true), "seed":seed_text, "home":home, "steps":entry["steps"].duplicate(true)}
						print(JSON.stringify({"fixture_mode":mode, "seed":seed_text, "home":home, "steps":entry["steps"], "source":source_id, "target":target_id, "clock":before["game_clock_minutes"], "cost":choice.get("cost"), "travel_minutes":choice.get("travel_minutes"), "route":route, "receipt":receipt}))
					if app.travel_presentation_active:
						app.travel_cinematic_overlay.skip_to_receipt()
						app.travel_cinematic_overlay.acknowledge()
					var steps: Array = entry["steps"].duplicate(true)
					steps.append(target_id)
					if steps.size() <= 6 and not visited.has(target_id) and not app.run_state.is_terminal():
						queue.append({"baseline":app.run_state.to_dict(), "steps":steps})
			print(JSON.stringify({"explored_seed":seed_text, "nodes":visited.keys(), "found":fixtures.keys()}))

func _all_requested_found() -> bool:
	for mode in requested_modes:
		if not fixtures.has(mode): return false
	return true

func _restore(baseline: Dictionary) -> void:
	app._cancel_travel_presentation()
	app._clear_input_guard_modal_state()
	app.pending_autosave = false
	app.run_state = RunState.new()
	app.run_state.from_dict(baseline)
	app.generator = Generator.new(app.library)
	app._refresh()

func _on_presentation_completed(_journey_id: String) -> void:
	completion_count += 1

func _ui_contract() -> Dictionary:
	var overlay: Control = app.travel_cinematic_overlay
	var result := {"script":overlay.get_script().resource_path, "z_index":overlay.z_index, "duration_seconds":overlay.DURATION_SECONDS}
	for key in ["_title", "_details", "_caption", "_summary_scroll", "_skip", "_continue"]:
		var control: Control = overlay.get(key)
		var contract_size := control.size
		if key == "_continue":
			# Different real destination names wrap to different text minima.
			# Deferred completion lets Godot finish shaping them between cases.
			# Check the exact live bounds before comparing the shared authored box.
			var authored := Vector2(236.0, 58.0) * overlay.size / Vector2(1280.0, 720.0)
			_expect(control.size.is_equal_approx(authored.max(control.get_combined_minimum_size())), "Continue geometry matches the shared box and current destination text minimum")
			contract_size = authored
		result[key] = {"position":str(control.position), "size":str(contract_size), "font_size":control.get_theme_font_size("font_size")}
	return result

func _test_mode(mode: String) -> void:
	var fixture: Dictionary = fixtures[mode]
	var baseline: Dictionary = fixture["baseline"]
	var target_id := str(fixture["choice"].get("id", ""))
	var reference: Dictionary = {}
	for flow in ["watch", "skip", "reduced", "missing", "web_atomic"]:
		_restore(baseline)
		var choice: Dictionary = app._travel_choice(target_id)
		var prefix: String = mode + "/" + str(flow) + ": "
		app.user_settings.reduce_motion = flow == "reduced"
		app.travel_transition_force_web_runtime_for_test = flow == "web_atomic"
		app.travel_cinematic_overlay.force_missing_art_for_test = flow == "missing"
		var before := _state(app.run_state)
		var result: Dictionary = _menu_travel(target_id, flow == "web_atomic")
		_expect(bool(result.get("ok", false)), prefix + "production transaction succeeds")
		_expect(not app.travel_transition_active and app.travel_presentation_active, prefix + "synchronous settlement has independent presentation owner")
		if not app.travel_presentation_active:
			print(JSON.stringify({"mode":mode, "flow":flow, "result":result, "receipt":app.run_state.travel_journey_receipt}))
			continue
		var overlay: Control = app.travel_cinematic_overlay
		var view: Dictionary = app.current_travel_presentation_snapshot()
		var receipt: Dictionary = app.run_state.travel_journey_receipt
		var settled := _state(app.run_state)
		_expect(app._modal_contract_blocks_player_input() and app._simulation_progression_paused(), prefix + "input and simulation remain paused")
		_expect(app.coach_overlay.presentation_suspended and not app.coach_overlay.visible and overlay.z_index > app.coach_overlay.z_index and overlay.z_index > 100, prefix + "coach and room overlays remain behind shared scene")
		_expect(app.run_state.current_world_node_id() == target_id and receipt.get("effective_destination_node_id") == target_id and receipt.get("effective_destination_environment_id") == app.run_state.current_environment.get("id"), prefix + "world destination matches the installed environment")
		_expect(receipt.get("origin_label") == baseline["current_environment"].get("display_name") and receipt.get("destination_label") == app.run_state.current_environment.get("display_name"), prefix + "frozen labels use actual installed origin and destination")
		_expect(view.get("mode") == mode and receipt.get("travel_method_kind") == mode and receipt.get("travel_method_label") == World.travel_method_label(mode), prefix + "canonical mode agrees across route receipt and renderer")
		_expect(receipt.get("presentation_key") in ["standard_travel_typical_v1", "back_alley_bar_typical_v1"] and not bool(receipt.get("route_risk", {}).get("triggered", false)), prefix + "unadjusted journey uses recognized typical presentation")
		_expect(is_equal_approx(float(view.get("duration_seconds", 0.0)), SHARED_DURATION) and is_equal_approx(float(overlay.DURATION_SECONDS), SHARED_DURATION), prefix + "shared 8 second duration")
		_expect(view.get("appearance", {}) == Appearance.normalized(Appearance.from_run(app.run_state, app.library)), prefix + "canonical player appearance is frozen from the real run")
		_expect(str(view.get("title", "")).contains(str(receipt.get("destination_label", "")).to_upper()) and view.get("destination_label") == receipt.get("destination_label") and view.get("origin_label") == receipt.get("origin_label"), prefix + "shared title names actual destination")
		_expect(not str(view.get("entrance_kind", "")).is_empty(), prefix + "destination entrance contract is explicit")
		var contract := _ui_contract()
		if shared_ui_contract.is_empty(): shared_ui_contract = contract
		else: _expect(contract == shared_ui_contract, prefix + "all modes use identical shared UI geometry controls and styling")
		if flow in ["reduced", "missing"]:
			_expect(overlay.phase == "receipt" and bool(view.get("static", false)), prefix + "fallback is an immediate static summary")
		else:
			_expect(overlay.phase != "receipt" and not bool(view.get("static", true)) and bool(view.get("has_art", false)), prefix + "real assets start the selected animation")
		app.continuous_environment_clock_enabled = true
		app._advance_run_game_clock(20.0)
		app.continuous_environment_clock_enabled = false
		_expect(_state(app.run_state) == settled, prefix + "presentation blocks continuous clock")
		var repeated: Dictionary = app._travel_to(target_id, str(choice.get("label", "")), choice, true)
		_expect(not bool(repeated.get("ok", true)) and _state(app.run_state) == settled, prefix + "second departure is rejected without double charging")
		_expect(not app._show_next_pending_triggered_event(), prefix + "queued event cannot overlap presentation")
		var completed_before := completion_count
		if flow in ["watch", "web_atomic"]:
			for sample in [0.8, 1.6, 2.1, 2.75, 3.8, 5.3, 6.15, 6.4, 6.95, 7.575, 7.95, SHARED_DURATION]:
				seed(80123)
				var expected_global_rng := randi()
				seed(80123)
				overlay.advance_presentation(sample - float(overlay.elapsed))
				_expect(randi() == expected_global_rng and _state(app.run_state) == settled, prefix + "sample %.1f does not consume RNG or mutate gameplay" % sample)
				if sample < SHARED_DURATION:
					var choreography: Dictionary = app.current_travel_presentation_snapshot().get("choreography", {})
					_expect(choreography.has("beat") and choreography.has("destination_door_open"), prefix + "sample %.1f follows shared choreography contract" % sample)
		else:
			overlay.skip_to_receipt()
		_expect(overlay.phase == "receipt" and app.travel_presentation_active and completion_count == completed_before, prefix + "completion is deferred outside the animation/input callback")
		_expect(_state(app.run_state) == settled, prefix + "watch or skip has no effects")
		await process_frame
		if flow in ["reduced", "missing"]:
			_expect(app.travel_presentation_active and completion_count == completed_before, prefix + "static summary still requires acknowledgment")
		else:
			_expect(not app.travel_presentation_active and completion_count == completed_before + 1, prefix + "finished or skipped cinematic enters destination automatically")
		overlay.acknowledge()
		overlay.acknowledge()
		_expect(completion_count == completed_before + 1 and not app.travel_presentation_active and not bool(app.run_state.travel_journey_receipt.get("receipt_pending", true)), prefix + "acknowledgment emits and releases ownership exactly once")
		_expect(_state(app.run_state) == settled, prefix + "acknowledgment does not charge move count advance time or roll RNG")
		_expect(int(receipt.get("base_minutes", -1)) == int(settled["clock"]) - int(before["clock"]) and int(settled["count"]) == int(before["count"]) + 1, prefix + "one travel settlement matches receipt time and count")
		_expect(int(before["bankroll"]) - int(settled["bankroll"]) == int(receipt.get("quoted_departure_fare", -1)), prefix + "one quoted fare charged for uneventful journey")
		if reference.is_empty(): reference = settled
		else: _expect(reference == settled, prefix + "all paths settle identical money time location count RNG and event state")
		await process_frame
	_restore(baseline)
	var disabled_choice: Dictionary = app._travel_choice(target_id).duplicate(true)
	disabled_choice["enabled"] = false
	var rejection_state := _state(app.run_state)
	var rejection_receipt: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
	var rejected: Dictionary = app._travel_to(target_id, str(disabled_choice.get("label", "")), disabled_choice, true)
	_expect(not bool(rejected.get("ok", true)) and _state(app.run_state) == rejection_state and app.run_state.travel_journey_receipt == rejection_receipt, mode + "/rejection: disabled journey changes neither gameplay nor prior receipt")
	_expect(not app.travel_transition_active and not app.travel_presentation_active, mode + "/rejection: rejected route leaves both owners inactive")
	await _test_reload(mode, fixture)
	print(JSON.stringify({"mode_complete":mode, "checks":checks, "failure_count":failures.size(), "fixture_seed":fixture["seed"], "steps":fixture["steps"]}))

func _test_reload(mode: String, fixture: Dictionary) -> void:
	_restore(fixture["baseline"])
	app.user_settings.reduce_motion = false
	app.travel_cinematic_overlay.force_missing_art_for_test = false
	app.travel_transition_force_web_runtime_for_test = false
	var target_id := str(fixture["choice"].get("id", ""))
	var choice: Dictionary = app._travel_choice(target_id)
	var result: Dictionary = _menu_travel(target_id, true)
	_expect(bool(result.get("ok", false)) and app.travel_presentation_active, mode + "/reload: pending journey commits")
	var committed := _state(app.run_state)
	app.save_service.wait_for_async_save()
	app.autosave_slot_id = "standard_travel_pending_" + mode
	# Exercise the real host publication, autosave queue and flush, while the
	# scene owns input. No direct save-service write substitutes for this path.
	app._refresh()
	app.pending_autosave_after_frame = -1
	app.pending_autosave_not_before_msec = 0
	app._flush_pending_autosave_if_ready()
	for _i in range(8):
		await process_frame
		app._flush_pending_autosave_if_ready()
	app.save_service.wait_for_async_save()
	_expect(app.save_service.has_run(app.autosave_slot_id), mode + "/reload: real host autosave writes while presentation owns input")
	var raw_loaded: RunState = app.save_service.load_run(app.autosave_slot_id)
	_expect(raw_loaded != null and bool(raw_loaded.travel_journey_receipt.get("receipt_pending", false)), mode + "/reload: stored receipt remains pending")
	app._cancel_travel_presentation()
	_expect(app._load_foundation_run_from_slot(false), mode + "/reload: production save-load bridge restores")
	var view: Dictionary = app.current_travel_presentation_snapshot()
	_expect(app.travel_presentation_active and view.get("phase") == "receipt" and bool(view.get("static", false)), mode + "/reload: pending receipt is static and never replays animation")
	if not _same_saved_values(_state(app.run_state), committed):
		print(JSON.stringify({"reload_state_difference_mode":mode, "before":committed, "after":_state(app.run_state)}))
	_expect(_same_saved_values(_state(app.run_state), committed), mode + "/reload: no second fare clock move counter risk or RNG change")
	app.travel_cinematic_overlay.acknowledge()
	_expect(not bool(app.run_state.travel_journey_receipt.get("receipt_pending", true)) and _same_saved_values(_state(app.run_state), committed), mode + "/reload: loaded receipt acknowledges without gameplay effects")
	var stale: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
	stale["receipt_pending"] = true
	stale["effective_destination_environment_id"] = "historical_environment"
	app.run_state.travel_journey_receipt = stale
	app._begin_travel_presentation(stale, true)
	view = app.current_travel_presentation_snapshot()
	_expect(view.get("phase") == "receipt" and view.get("title") == "PREVIOUS JOURNEY" and view.get("continue_text") == "Continue", mode + "/reload: mismatched receipt is historical text only")
	app._cancel_travel_presentation()
	_expect(not app.travel_presentation_active and bool(app.run_state.travel_journey_receipt.get("receipt_pending", false)) and _same_saved_values(_state(app.run_state), committed), mode + "/reload: teardown releases owner without acknowledging or settling again")

func _test_local_door_excluded() -> void:
	app._cancel_travel_presentation()
	_expect(app.start_foundation_run("STANDARD-TRAVEL-LOCAL-DOOR", {"modifiers":{"home_archetype_id":"motel_room"}}, false), "local door: generated home start")
	var target_id: String = app._parent_home_parent_target_id()
	var choice: Dictionary = app._local_parent_home_door_travel_choice(target_id)
	_expect(not choice.is_empty() and bool(choice.get("enabled", false)) and bool(choice.get("local_door", false)), "local door: real enabled room-to-lobby choice")
	if choice.is_empty(): return
	var result: Dictionary = app._travel_to(target_id, str(choice.get("label", "Lobby")), choice, true)
	_expect(bool(result.get("ok", false)) and app.run_state.current_world_node_id() == target_id, "local door: production room-to-lobby move commits")
	_expect(app.run_state.travel_journey_receipt.is_empty() and not app.travel_presentation_active, "local door: no standard journey or presentation for local movement")

func _capture(mode: String) -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(not evidence.is_empty() and evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/"), "capture uses admitted E: evidence directory")
	if not failures.is_empty(): return
	var fixture: Dictionary = fixtures[mode]
	_restore(fixture["baseline"])
	app.user_settings.reduce_motion = false
	app.travel_cinematic_overlay.force_missing_art_for_test = false
	app.travel_transition_force_web_runtime_for_test = false
	for _i in range(15): await process_frame
	var target_id := str(fixture["choice"].get("id", ""))
	var choice: Dictionary = app._travel_choice(target_id)
	var result: Dictionary = _menu_travel(target_id, true)
	_expect(bool(result.get("ok", false)) and app.travel_presentation_active, "capture commits through actual Main/_travel_to/overlay")
	var initial_view: Dictionary = app.current_travel_presentation_snapshot()
	_expect(initial_view.get("mode") == mode and not bool(initial_view.get("static", true)), "capture animates actual selected route mode")
	if not failures.is_empty(): return
	var settled := _state(app.run_state)
	var samples: Array = []
	var completed_before := completion_count
	var duration: float = app.travel_cinematic_overlay.DURATION_SECONDS
	var sample_frames: Array[int] = [1]
	for seconds in [1.0, 1.6, 2.1, 2.75, 3.6, 4.4, 5.15, 6.0, 6.15, 6.4, 6.95, 7.575, 7.95, duration + 0.8]:
		sample_frames.append(int(round(float(seconds) * 30.0)))
	var capture_frames := int(ceil((duration + 2.2) * 30.0))
	# Godot Movie Maker runs the production scene at fixed 30 FPS. The harness
	# only observes naturally rendered frames; it does not drive pose or time.
	for frame in range(capture_frames):
		await process_frame
		_expect(_state(app.run_state) == settled, "capture frame %d preserves settled gameplay" % frame)
		if frame in sample_frames:
			await RenderingServer.frame_post_draw
			var path := evidence.path_join("standard_%s_%03d.png" % [mode, frame])
			_expect(root.get_texture().get_image().save_png(path) == OK, "capture sample %d written" % frame)
			samples.append({"frame":frame, "view":app.current_travel_presentation_snapshot(), "path":path})
	_expect(not app.travel_cinematic_overlay.active and not app.travel_presentation_active, "capture naturally enters the destination without Continue")
	app.travel_cinematic_overlay.acknowledge()
	app.travel_cinematic_overlay.acknowledge()
	_expect(completion_count == completed_before + 1 and not app.travel_presentation_active and _state(app.run_state) == settled, "capture acknowledgment releases once with no effects")
	for _i in range(30): await process_frame
	var report := {"mode":mode, "seed":fixture["seed"], "home":fixture["home"], "steps":fixture["steps"], "route":choice.get("route", {}), "receipt":app.run_state.travel_journey_receipt, "initial_view":initial_view, "samples":samples, "settled_state":settled, "final_state":_state(app.run_state), "passed":failures.is_empty(), "failures":failures}
	var report_file := FileAccess.open(evidence.path_join("standard_%s_capture.json" % mode), FileAccess.WRITE)
	_expect(report_file != null, "capture report opened")
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print(JSON.stringify({"capture_mode":mode, "receipt":report["receipt"], "sample_count":samples.size(), "passed":failures.is_empty()}))
