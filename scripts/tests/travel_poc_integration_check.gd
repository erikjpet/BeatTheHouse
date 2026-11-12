extends SceneTree

# Runs the production host and synchronous transaction. All state is generated
# in the guard-owned throwaway profile, never a player's save.
const MainScene := preload("res://scenes/main.tscn")
const Generator := preload("res://scripts/core/run_generator.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
var failures: Array[String] = []
var checks := 0
var app: Control
var target_id := ""

class RejectingGenerator extends RunGenerator:
	func travel_environment_result(run: RunState, _target: String, _prevalidated: bool = false) -> Dictionary:
		run.bankroll -= 17
		run.travel_journey_receipt = {"poison": true}
		return {"ok":false, "errors":["Injected destination rejection."]}

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _state(run: RunState) -> Dictionary:
	var travel_entries := 0
	for entry in run.story_log:
		if entry is Dictionary and str(entry.get("type", "")) in ["travel", "travel_risk_event"]: travel_entries += 1
	return {"bankroll":run.bankroll, "clock":run.game_clock_minutes, "node":run.current_world_node_id(), "count":run.environment_travel_count(), "rng_seed":run.rng_seed, "rng_state":run.rng_state, "suspicion":run.suspicion, "drunk_level":run.drunk_level, "pending_events":run.pending_triggered_events.duplicate(true), "active_event":run.active_triggered_event.duplicate(true), "travel_log_entries":travel_entries}

func _different_keys(a: Dictionary, b: Dictionary) -> Array:
	var result: Array = []
	for key in a:
		if a[key] != b.get(key): result.append(key)
	return result

func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	var choice: Dictionary = {}
	var choices: Array = []
	# Topology is seeded: choose an ordinary generated test world that actually
	# offers this route. Do not add an edge or bypass discovery/access policy.
	for seed_index in range(24):
		if not app.start_foundation_run("TRAVEL-POC-BACK-ALLEY-%d" % seed_index, {"modifiers":{"home_archetype_id":"back_alley"}}, false):
			continue
		choices = app._travel_choice_view_list()
		for candidate in choices:
			var route: Dictionary = candidate.get("route", {})
			if str(route.get("destination_archetype", "")) == "bar" and bool(candidate.get("enabled", false)):
				target_id = str(candidate.get("id", ""))
				choice = app._travel_choice(target_id)
				break
		if not choice.is_empty(): break
	_expect(str(app.run_state.current_environment.get("archetype_id", "")) == "back_alley", "actual generated Back Alley start")
	var baseline: Dictionary = app.run_state.to_dict()
	_expect(not choice.is_empty() and bool(choice.get("enabled", false)), "actual generated route to bar is enabled")
	if choice.is_empty() or not bool(choice.get("enabled", false)):
		print(JSON.stringify({"choice":choice, "choices":choices, "targets":app._travel_target_ids(), "failures":failures}))
		app.free()
		quit(1)
		return
	if "--capture-travel" in OS.get_cmdline_user_args():
		await _capture(choice)
		return
	var reference := {}
	for flow in ["watch", "skip", "reduced", "missing", "web_atomic"]:
		app._clear_input_guard_modal_state()
		app.run_state = RunState.new()
		app.run_state.from_dict(baseline)
		app.generator = Generator.new(app.library)
		# Republish the restored run before using the public menu authority.
		app._refresh()
		app.user_settings.reduce_motion = flow == "reduced"
		app.travel_transition_force_web_runtime_for_test = flow == "web_atomic"
		app._build_travel_cinematic_overlay()
		app.travel_cinematic_overlay.force_missing_art_for_test = flow == "missing"
		var before := _state(app.run_state)
		var result: Dictionary = _menu_travel(target_id, flow == "web_atomic")
		_expect(bool(result.get("ok", false)), flow + " transaction succeeds")
		_expect(not app.travel_transition_active and app.travel_presentation_active, flow + " returns synchronously with independent owner")
		_expect(app._modal_contract_blocks_player_input() and app._simulation_progression_paused(), flow + " presentation blocks input and simulation")
		_expect(app.coach_overlay.presentation_suspended and not app.coach_overlay.visible and overlay_above_room_ui(), flow + " coach and room overlays remain behind scene")
		if flow == "watch":
			var lesson: Dictionary = app.coach_overlay.active_lesson.duplicate(true)
			var prepared: Dictionary = app.coach_overlay.prepared_snapshot.duplicate(true)
			var sentinel := {"id":"travel_coach_preservation", "scope":"tutorial_run"}
			app.coach_overlay.active_lesson = sentinel.duplicate(true)
			app.coach_overlay.prepared_snapshot = {"gating":true}
			app._refresh_coach_at_boundary()
			app.coach_overlay._render_active(false)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = Vector2(1120, 80)
			_expect(not app.coach_overlay.visible and not app.coach_overlay._consume_blocked_pointer_input(press) and app.coach_overlay.active_lesson == sentinel, "active tutorial coach preserves lesson and cannot eat Skip click")
			app.coach_overlay.active_lesson = lesson
			app.coach_overlay.prepared_snapshot = prepared
		_expect(app.run_state.current_world_node_id() == target_id, flow + " underlying arrival committed")
		_expect(app.current_travel_presentation_snapshot().get("appearance", {}) == Appearance.normalized(Appearance.from_run(app.run_state, app.library)), flow + " canonical appearance comes from actual run support without invented wearables")
		var settled := _state(app.run_state)
		app.continuous_environment_clock_enabled = true
		app._advance_run_game_clock(20.0)
		app.continuous_environment_clock_enabled = false
		_expect(_state(app.run_state) == settled, flow + " clock does not advance under presentation")
		var repeated: Dictionary = app._travel_to(target_id, "Bar", choice, true)
		_expect(not bool(repeated.get("ok", true)) and _state(app.run_state) == settled, flow + " repeated travel rejected without mutation")
		_expect(not app._show_next_pending_triggered_event(), flow + " queued modal cannot overlap")
		var overlay: Control = app.travel_cinematic_overlay
		_expect(is_equal_approx(float(overlay.DURATION_SECONDS), 8.0), flow + " shared 8 second presentation duration")
		if flow in ["watch", "web_atomic"]:
			for seconds in [0.8, 1.6, 2.1, 2.75, 3.8, 5.3, 6.15, 6.4, 6.95, 7.575, 7.95, overlay.DURATION_SECONDS]:
				seed(90123)
				var expected_global_rng := randi()
				seed(90123)
				overlay.advance_presentation(float(seconds) - float(overlay.elapsed))
				_expect(randi() == expected_global_rng and _state(app.run_state) == settled, flow + " sample %.1f never consumes RNG or mutates settlement" % seconds)
		else:
			overlay.skip_to_receipt()
		_expect(overlay.phase == "receipt" and app.travel_presentation_active, flow + " completion is safely deferred")
		_expect(_state(app.run_state) == settled, flow + " watch or skip never settles gameplay")
		await process_frame
		_expect(app.travel_presentation_active == (flow in ["reduced", "missing"]), flow + " only static outcomes wait for Continue")
		overlay.acknowledge()
		overlay.acknowledge()
		_expect(not app.travel_presentation_active and not bool(app.run_state.travel_journey_receipt.get("receipt_pending", true)), flow + " acknowledgment releases once")
		_expect(_state(app.run_state) == settled, flow + " acknowledgment has no gameplay effects")
		_expect(int(app.run_state.travel_journey_receipt.get("base_minutes", -1)) == app.run_state.game_clock_minutes - int(before["clock"]), flow + " receipt minutes match one settlement")
		if reference.is_empty(): reference = settled
		else: _expect(settled == reference, flow + " equivalent financial/time/location/counter/RNG/queue state")
		await process_frame
	# Failure does not create a receipt or leave either ownership flag active.
	app._clear_input_guard_modal_state()
	app.run_state = RunState.new()
	app.run_state.from_dict(baseline)
	app.generator = RejectingGenerator.new(app.library)
	# Match the production load path, which settles restored scenario projection
	# before accepting player travel, rather than comparing an unrendered clone.
	app._refresh()
	var before_failure: Dictionary = app.run_state.to_dict()
	var failed: Dictionary = app._travel_to(target_id, "Bar", choice, true)
	print(JSON.stringify({"failure_changed_keys":_different_keys(before_failure, app.run_state.to_dict()), "environment_changed_keys":_different_keys(before_failure["current_environment"], app.run_state.to_dict()["current_environment"]), "failed_result":failed}))
	_expect(not bool(failed.get("ok", true)) and app.run_state.to_dict() == before_failure, "destination failure restores all run/receipt fields")
	_expect(not app.travel_transition_active and not app.travel_presentation_active, "destination failure leaves no successful scene")
	var disabled := choice.duplicate(true)
	disabled["enabled"] = false
	var invalid: Dictionary = app._travel_to(target_id, "Bar", disabled, true)
	_expect(not bool(invalid.get("ok", true)) and app.run_state.to_dict() == before_failure, "rejected route creates no journey")
	# Exercise the production save/load bridge with an unresolved receipt.
	app.generator = Generator.new(app.library)
	app.travel_cinematic_overlay.force_missing_art_for_test = false
	app.user_settings.reduce_motion = false
	var saved_trip: Dictionary = _menu_travel(target_id, true)
	print(JSON.stringify({"receipt_after_saved_trip":app.run_state.travel_journey_receipt, "saved_trip_ok":saved_trip.get("ok")}))
	_expect(bool(saved_trip.get("ok", false)), "pending receipt save fixture commits")
	var committed := _state(app.run_state)
	app.save_service.wait_for_async_save()
	app.autosave_slot_id = "travel_poc_pending_receipt"
	# Use the real host publication/queue/flush path while ownership is active.
	app._refresh()
	app.pending_autosave_after_frame = -1
	app.pending_autosave_not_before_msec = 0
	app._flush_pending_autosave_if_ready()
	for _i in range(8):
		await process_frame
		app._flush_pending_autosave_if_ready()
	app.save_service.wait_for_async_save()
	_expect(app.save_service.has_run(app.autosave_slot_id), "pending receipt saved by host while scene still owns input")
	var raw_loaded: RunState = app.save_service.load_run(app.autosave_slot_id)
	print(JSON.stringify({"receipt_before_ui_load":raw_loaded.travel_journey_receipt if raw_loaded != null else {}}))
	app._cancel_travel_presentation()
	_expect(app._load_foundation_run_from_slot(false), "pending receipt reload succeeds")
	print(JSON.stringify({"reload_presentation":app.current_travel_presentation_snapshot(), "reload_receipt":app.run_state.travel_journey_receipt, "reload_changed_keys":_different_keys(committed, _state(app.run_state))}))
	_expect(app.travel_presentation_active and app.travel_cinematic_overlay.phase == "receipt", "reload shows summary without replay")
	_expect(_state(app.run_state) == committed, "reload does not charge advance move count or reroll")
	app.travel_cinematic_overlay.acknowledge()
	_expect(not bool(app.run_state.travel_journey_receipt.get("receipt_pending", true)), "loaded receipt acknowledged")
	var stale: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
	stale["receipt_pending"] = true
	stale["effective_destination_environment_id"] = "old_bar_instance"
	app.run_state.travel_journey_receipt = stale
	var before_stale := _state(app.run_state)
	app._begin_travel_presentation(stale, true)
	var stale_view: Dictionary = app.current_travel_presentation_snapshot()
	_expect(stale_view.get("phase") == "receipt" and stale_view.get("title") == "PREVIOUS JOURNEY" and stale_view.get("continue_text") == "Continue", "mismatched pending receipt is historical static summary")
	_expect(_state(app.run_state) == before_stale, "historical pending receipt never applies travel effects")
	app._cancel_travel_presentation()
	_expect(not app.travel_presentation_active and bool(app.run_state.travel_journey_receipt.get("receipt_pending", false)), "teardown releases lock without acknowledging saved receipt")
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	print(JSON.stringify({"suite":"travel_poc_integration", "checks":checks, "passed":failures.is_empty(), "failures":failures}))
	app.free()
	quit(0 if failures.is_empty() else 1)

func overlay_above_room_ui() -> bool:
	return app.travel_cinematic_overlay.z_index > app.coach_overlay.z_index and app.travel_cinematic_overlay.z_index > 100

func _menu_travel(target: String, require_immediate_result: bool = false) -> Dictionary:
	return {"ok":app.select_travel_option(target) and app.confirm_selected_travel(require_immediate_result)}

func _capture(choice: Dictionary) -> void:
	# This is the same host, route, transaction and overlay as normal play.
	# Godot Movie Maker captures its real rendered frames at fixed FPS.
	for _i in range(15): await process_frame
	var result: Dictionary = _menu_travel(target_id, true)
	if not bool(result.get("ok", false)) or not app.travel_presentation_active:
		push_error("Capture transaction failed.")
		quit(1)
		return
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	var before := _state(app.run_state)
	var duration: float = app.travel_cinematic_overlay.DURATION_SECONDS
	var sample_frames: Array[int] = [1]
	for seconds in [1.0, 1.6, 2.1, 2.75, 3.6, 4.4, 5.15, 6.0, 6.15, 6.4, 6.95, 7.575, 7.95, duration + 0.8]:
		sample_frames.append(int(round(float(seconds) * 30.0)))
	# Movie Maker's established fixed 30 FPS includes the complete runtime clip
	# plus the automatically entered destination; no old-duration frame bound.
	var capture_frames := int(ceil((duration + 2.2) * 30.0))
	for frame in range(capture_frames):
		await process_frame
		if frame in sample_frames:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence.path_join("travel_%03d.png" % frame))
	_expect(not app.travel_presentation_active and not app.travel_cinematic_overlay.active and _state(app.run_state) == before, "recorded scene automatically enters destination without gameplay mutation")
	print(JSON.stringify({"capture_view":app.current_travel_presentation_snapshot(), "title_visible":app.travel_cinematic_overlay.get("_title").visible, "title_rect":str(app.travel_cinematic_overlay.get("_title").get_global_rect()), "details_visible":app.travel_cinematic_overlay.get("_details").visible}))
	app.travel_cinematic_overlay.acknowledge()
	for _i in range(30): await process_frame
	print(JSON.stringify({"suite":"travel_poc_capture", "passed":failures.is_empty(), "failures":failures, "receipt":app.run_state.travel_journey_receipt}))
	app.free()
	quit(0 if failures.is_empty() else 1)
