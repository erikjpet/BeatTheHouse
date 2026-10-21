extends SceneTree

# Finite private regression. The runner owns OS job limits/deadline, Dummy
# audio and isolated project/userdata setup before starting the engine.
# This creates one synthetic normal run; it never opens the preserved user run.
const SEED := "GAS-SCRATCH-ONE-EMPTY-STOCK-ARRIVAL"
const SCENARIO_ID := "gas_station_graveyard_shift"

var failures: Array[String] = []
var app: Control
var run: RecordingRun
var observations: Dictionary = {}


class RecordingRun:
	extends RunState

	var repro_phase := "setup"
	var record_membership := false
	var membership_receipts: Array = []

	func prepare_current_environment_object_membership_for_publication() -> Dictionary:
		var result := super.prepare_current_environment_object_membership_for_publication()
		if record_membership:
			var states: Dictionary = current_environment.get("game_states", {})
			var machine: Dictionary = states.get("scratch_tickets", {})
			membership_receipts.append({
				"phase": repro_phase,
				"ok": bool(result.get("ok", false)),
				"errors": (result.get("errors", []) as Array).duplicate(true),
				"scalper_present": bool(machine.get("scalper_present", false)),
				"semantic_ready_flag": bool(current_environment.get("scenario_semantic_ready", false)),
				"manifest_digest": str((current_environment.get("object_manifest", {}) as Dictionary).get("digest", "")),
				"placement_errors": ((current_environment.get("layout", {}) as Dictionary).get("placement_errors", []) as Array).duplicate(true),
			})
		return result


class FixtureGenerator:
	extends RunGenerator

	var fixture_stock_index := -1
	var fixture_price := 0
	var fixture_applied_count := 0

	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func _generated_game_states(run_state: RunState, environment_data: Dictionary, rng: RngStream) -> Dictionary:
		var states := super._generated_game_states(run_state, environment_data, rng)
		if str(environment_data.get("archetype_id", "")) != "gas_station_casino":
			return states
		var machine: Dictionary = (states.get("scratch_tickets", {}) as Dictionary).duplicate(true)
		var stock: Array = machine.get("stock", [])
		for index in range(stock.size()):
			var row: Dictionary = stock[index]
			if str(row.get("release_availability", "active")) == "held":
				continue
			row["remaining"] = 0
			if fixture_stock_index < 0 and int(row.get("capacity", 0)) >= 2:
				fixture_stock_index = index
				fixture_price = int(row.get("price", 0))
			stock[index] = row
		if fixture_stock_index < 0:
			return states
		(stock[fixture_stock_index] as Dictionary)["remaining"] = 2
		machine["stock"] = stock
		machine["scalper_present"] = false
		machine["scalper_knows_schedule"] = false
		machine["scalper_cleared_count"] = 0
		# set_environment will stamp this same visit clock during installation.
		machine["scalper_visit_token"] = "%s@%d" % [RunState.portable_ticket_origin_key(environment_data), run_state.game_clock_minutes]
		# Keep the real restock scheduler beyond this short fixture. This avoids an
		# accidental second arrival; no RNG is searched or overridden.
		machine["restock_phase_minute"] = 179
		machine["restock_cursor_absolute_minute"] = run_state.game_clock_minutes
		machine["next_restock_absolute_minute"] = 899
		states["scratch_tickets"] = machine
		fixture_applied_count += 1
		# The parent factory subsequently rebuilds the fresh candidate's manifest
		# and layout, then its normal install reconstructs trusted catalog authority
		# and finalizes scenario semantics. No sealed live authority is edited here.
		return states


func _init() -> void:
	# This must precede every run, scene, authority and profile operation. The
	# containing project must also have no autoloads (verified by the parent).
	if not _disposable_userdata_confirmed():
		push_error("REFUSED: resolved user:// must exactly equal BTH_SCRATCH_REPRO_USER_DIR.")
		quit(64)
		return
	if OS.get_environment("BTH_SCRATCH_REPRO_REPORT").is_empty():
		push_error("REFUSED: BTH_SCRATCH_REPRO_REPORT must name the parent's bounded local report file.")
		quit(64)
		return
	call_deferred("_run")


func _run() -> void:
	# A second, external process/job deadline remains necessary for synchronous
	# engine work. This timer is only an in-engine bound on the finite UI waits.
	create_timer(30.0).timeout.connect(func() -> void:
		failures.append("In-engine finite deadline expired.")
		_finish(124)
	)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var mask_script: Script = load("res://scripts/games/scratch_ticket_mask.gd")
	app = main_scene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "gas_scratch_one_arrival_disposable")
	root.add_child(app)
	await process_frame
	await process_frame
	if not _require(bool(app.call("_ensure_run_ui_built")), "Normal run UI could not be constructed."):
		_finish()
		return
	app.call("_ensure_full_content_library_loaded")
	var library: ContentLibrary = app.get("library")
	run = RecordingRun.new()
	run.start_new(SEED, RunState.custom_challenge("gas_scratch_one_arrival", SEED, {
		"scenario_pins": {"gas_station_casino": SCENARIO_ID},
	}))
	run.bankroll = 1000
	run.begin_act(1)
	var generator := FixtureGenerator.new(library)
	var installed := generator.travel_environment_result(run, "gas_station_casino", true)
	if not _require(bool(installed.get("ok", false)), "Normal Gas Station install failed: %s" % str(installed.get("errors", []))):
		_finish()
		return
	if not _require(generator.fixture_applied_count == 1 and generator.fixture_stock_index >= 0, "The stock fixture was not applied exactly once before sealing."):
		_finish()
		return
	# Validate a detached copy directly. Do not ask any current view snapshot to
	# finalize or repair the live run in order to manufacture a valid baseline.
	var interaction_script: Script = load("res://scripts/ui/environment_interaction_controller.gd")
	var baseline_proof: Dictionary = interaction_script._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations["baseline_join_proof"] = {"ok": bool(baseline_proof.get("ok", false)), "errors": (baseline_proof.get("errors", []) as Array).duplicate(true)}
	if not _require(bool(baseline_proof.get("ok", false)), "Normal factory baseline failed raw manifest join proof."):
		_finish()
		return
	app.set("run_state", run)
	app.set("generator", generator)
	app.call("_bind_run_state_presentation_signals")
	app.call("_configure_coach_for_run")
	app.call("_refresh_run_action_service")
	app.call("_clear_input_guard_modal_state")
	app.call("_queue_room_publication_check")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh_runtime_environment_views")
	await process_frame
	await process_frame
	var baseline := _snapshot("baseline")
	if not _require(str(run.current_environment.get("scenario_id", "")) == SCENARIO_ID, "Authored Graveyard Shift pin was not installed.") \
		or not _require(not run.is_tutorial_run() and not bool(app.call("_is_environment_test_session")), "Fixture accidentally entered a practice/tutorial lifecycle.") \
		or not _require(bool(run.call("_scenario_semantic_ready")), "Baseline production scenario proof is not valid.") \
		or not _require(int(baseline.get("stock_total", -1)) == 2 and not bool(baseline.get("scalper_present", true)), "Baseline is not a stocked same-visit machine without a scalper.") \
		or not _require(_enabled_room_objects() > 0, "Baseline normal room publication has no enabled objects."):
		_finish()
		return
	if not _require(bool(app.call("enter_game", "scratch_tickets")), "Normal scratch entry was rejected."):
		_finish()
		return
	run.record_membership = true
	run.repro_phase = "buy_two"
	# 100 + stock index is the production surface encoding for quantity two.
	app.call("_on_game_surface_action", "scratch_buy", 100 + generator.fixture_stock_index)
	await create_timer(3.1).timeout
	if not await _await_surface_gate(5000):
		_finish()
		return
	var purchased := _snapshot("purchased")
	if not _require(int(purchased.get("tray_count", -1)) == 2 and int(purchased.get("stock_total", -1)) == 0 and not bool(purchased.get("scalper_present", true)), "Normal purchase did not leave two delivered tickets and an empty raw machine without a scalper.") \
		or not _require(run.bankroll == 1000 - 2 * generator.fixture_price, "Purchase tender was not charged exactly once.") \
		or not _require(str((app.get("last_game_result") as Dictionary).get("action_id", "")) == "buy_scratch_ticket", "Buy did not resolve through the real action host."):
		_finish()
		return
	run.repro_phase = "collect_empty_stock_arrival"
	app.call("_on_game_surface_action", "scratch_collect_tray", 0)
	await process_frame
	await process_frame
	var collected := _snapshot("collected")
	if not _require(bool(collected.get("scalper_present", false)), "The deterministic same-visit empty-stock arrival did not commit.") \
		or not _require(int(collected.get("tray_count", -1)) == 0 and int(collected.get("queue_count", -1)) == 1 and not str(collected.get("active_id", "")).is_empty(), "Normal collection did not create one active and one queued ticket."):
		_finish()
		return
	run.repro_phase = "scratch_all"
	app.call("_on_game_surface_action", "scratch_all", 0)
	await process_frame
	if not _require(bool(mask_script.ticket_complete(_machine().get("active_ticket", {}))), "Real Scratch All did not complete the active ticket; input gate may already be blocked."):
		_snapshot("scratch_all_rejected")
		_finish()
		return
	var before_file := _snapshot("before_file")
	var expected_next_id := str((_machine().get("pending_queue", []) as Array)[0].get("id", ""))
	run.repro_phase = "file"
	app.call("_on_game_surface_action", "scratch_file_ticket", 0)
	await process_frame
	await process_frame
	if not await _await_surface_gate(5000):
		_finish()
		return
	var after_file := _snapshot("after_file")
	_require(int(after_file.get("restock_event_count", -1)) == 0, "Unexpected restock crossed during the one-arrival fixture.")
	observations["file_rollback_signature"] = str(after_file.get("active_id", "")) == str(before_file.get("active_id", "")) \
		and int(after_file.get("queue_count", -1)) == int(before_file.get("queue_count", -2)) \
		and str((app.get("last_game_result") as Dictionary).get("action_id", "")) == "buy_scratch_ticket"
	_require(str(after_file.get("active_id", "")) == expected_next_id and int(after_file.get("queue_count", -1)) == 0, "File did not advance exactly once to the queued ticket.")
	_require(int(after_file.get("filed_count", -1)) == int(before_file.get("filed_count", -1)) + 1, "File did not add exactly one winner/loser receipt.")
	_require(int(after_file.get("bankroll", -1)) == int(before_file.get("bankroll", -2)), "Filing changed bankroll; payout must remain pending at the counter.")
	_require(str((app.get("last_game_result") as Dictionary).get("action_id", "")) == "settle_scratch_ticket", "Host feedback retained the prior action after File.")
	run.repro_phase = "return_room"
	app.call("back_to_environment")
	await process_frame
	await process_frame
	observations["room_enabled_objects_after_back"] = _enabled_room_objects()
	observations["room_recovery_active"] = bool(app.call("_room_recovery_is_active")) if app.has_method("_room_recovery_is_active") else int(app.get("room_recovery_generation")) == int(app.get("room_publication_generation"))
	_snapshot("room_after_back")
	_require(_enabled_room_objects() > 0, "Returning from scratch published an empty room.")
	_require(bool(run.call("_scenario_semantic_ready")), "The normal transition invalidated scenario authority.")
	_finish()


func _machine() -> Dictionary:
	return (run.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})


func _snapshot(label: String) -> Dictionary:
	var environment := run.current_environment
	var machine := _machine()
	var stock_total := 0
	for row in machine.get("stock", []):
		if str(row.get("release_availability", "active")) != "held":
			stock_total += maxi(0, int(row.get("remaining", 0)))
	var result := {
		"clock": run.game_clock_minutes,
		"bankroll": run.bankroll,
		"scenario_id": str(environment.get("scenario_id", "")),
		"semantic_ready_flag": bool(environment.get("scenario_semantic_ready", false)),
		"semantic_digest": str(environment.get("scenario_semantic_digest", "")),
		"manifest_source_digest": str((environment.get("object_manifest", {}) as Dictionary).get("source_digest", "")),
		"scalper_present": bool(machine.get("scalper_present", false)),
		"scalper_visit_token": str(machine.get("scalper_visit_token", "")),
		"stock_total": stock_total,
		"restock_event_count": int(machine.get("restock_event_count", 0)),
		"tray_count": (machine.get("tray_stack", []) as Array).size(),
		"queue_count": (machine.get("pending_queue", []) as Array).size(),
		"active_id": str((machine.get("active_ticket", {}) as Dictionary).get("id", "")),
		"filed_count": (machine.get("winner_pile", []) as Array).size() + (machine.get("loser_pile", []) as Array).size() + int(machine.get("loser_archive_count", 0)),
		"last_counter_transaction": (machine.get("last_counter_transaction", {}) as Dictionary).duplicate(true),
		"lifecycle_errors": (environment.get("scenario_sequence_lifecycle_errors", []) as Array).duplicate(true),
		"placement_errors": ((environment.get("layout", {}) as Dictionary).get("placement_errors", []) as Array).duplicate(true),
	}
	observations[label] = result
	return result


func _enabled_room_objects() -> int:
	var canvas: Control = app.get("environment_canvas")
	if canvas == null:
		return 0
	var count := 0
	for value in canvas.get("foundation_scene_objects"):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = value
		if bool(object_data.get("interactive", false)) and not bool(object_data.get("decorative", false)) and not bool(object_data.get("disabled", false)) and not str(object_data.get("id", "")).is_empty():
			count += 1
	return count


func _await_surface_gate(max_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + max_msec
	while bool(app.call("_deferred_embedded_refresh_blocks_current_surface_input")):
		if Time.get_ticks_msec() >= deadline:
			return _require(false, "Deferred surface presentation did not release within the finite wait.")
		await process_frame
	return true


func _disposable_userdata_confirmed() -> bool:
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	var actual_directory := actual.replace("\\", "/").trim_suffix("/").to_lower()
	var expected_directory := expected.replace("\\", "/").trim_suffix("/").to_lower()
	observations["resolved_user_dir"] = actual
	observations["userdata_guard_passed"] = not expected_directory.is_empty() and actual_directory == expected_directory
	return not expected_directory.is_empty() and actual_directory == expected_directory


func _require(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced_exit_code: int = -1) -> void:
	if run != null:
		observations["membership_receipts"] = run.membership_receipts.duplicate(true)
	observations["failures"] = failures.duplicate()
	var report_text := JSON.stringify(observations)
	var report_written := false
	if report_text.to_utf8_buffer().size() <= 65536:
		var report := FileAccess.open(OS.get_environment("BTH_SCRATCH_REPRO_REPORT"), FileAccess.WRITE)
		if report != null:
			report.store_string(report_text)
			report_written = report.get_error() == OK
			report.close()
	if app != null:
		app.queue_free()
	var exit_code := forced_exit_code if forced_exit_code >= 0 else (0 if failures.is_empty() else 1)
	if not report_written:
		exit_code = 74
	print("GAS_SCRATCH_ONE_ARRIVAL status=%s failures=%d report_written=%s" % ["PASS" if exit_code == 0 else "FAIL", failures.size(), str(report_written)])
	quit(exit_code)
