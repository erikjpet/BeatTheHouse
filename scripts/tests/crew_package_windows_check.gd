extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const DeliveryModel := preload("res://scripts/core/delivery_run_model.gd")
const Schedule := preload("res://scripts/core/crew_delivery_schedule.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const CrewFixture := preload("res://scripts/tests/foundation/crew_layer3_jobs_contract.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")

class LayoutHost extends Main:
	func _ready() -> void:
		set_process(false)

var failures: Array = []
var library: ContentLibrary


func _init() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_BUILD") != "1" or OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("Crew package check requires an explicitly isolated distribution data root.")
		quit(1)
		return
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("CHECK FAILED: " + message)


func make_run(seed: String) -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed)
	var generator := RunGeneratorScript.new(library)
	Fidelity.generate_and_finalize(generator, run, failures, seed)
	run.crew_add_trust("crew_rook", 50, "fixture")
	run.debt.append({"id": "crew_test_marker", "lender_id": "the_crew", "debt_kind": "favor", "balance": 1, "status": "favor_due", "default_consequence": "crew_favor_due", "turns_remaining": 1000, "next_pressure_turns": 1000})
	run.narrative_flags["crew_favor_pending"] = true
	run.advance_environment_turns(1)
	return run


func accept_favor(run: RunState) -> Dictionary:
	check(run.enqueue_triggered_event("crew_favor_delivery", "debt", {}, {"presentation": "talk"}), "host could not enqueue favor")
	var host := Main.new()
	host.run_state = run
	host.library = library
	var module: EventModule = host.call("_crew_delivery_event_module", library.event("crew_favor_delivery"))
	var views := module.choice_views(run, run.current_environment)
	var choice: Dictionary = {}
	for row in views:
		if str(row.get("id", "")) == "run_package": choice = row
	check(str(choice.get("text", "")).contains("Day "), "offer omits exact day/time")
	var offered := run.delivery_crew_offer("crew_favor_delivery", int(choice.get("crew_offer_clock", -1)))
	run.advance_environment_turns(2)
	run.advance_game_clock_minutes(1)
	var resolving_module: EventModule = host.call("_crew_delivery_event_module", library.event("crew_favor_delivery"))
	check(is_same(module, resolving_module), "UI discarded the advertised offer before acceptance")
	var accepted := resolving_module.resolve(run, run.current_environment, "run_package")
	host.free()
	check(bool(accepted.get("ok", false)) and run.delivery_has_active_run(), "normal event did not accept favor: %s" % accepted)
	var expected: Dictionary = offered.get("spec", {})
	check(run.active_delivery_run.get("consumer_payload", {}).get("meeting_windows", []) == expected.get("consumer_payload", {}).get("meeting_windows", []), "acceptance changed the advertised appointment")
	return accepted


func save_continue(run: RunState, slot: String) -> RunState:
	var saves := SaveServiceScript.new()
	check(saves.save_run(run, slot) == OK, "Save failed: %s" % saves.last_save_outcome)
	var restored: Variant = SaveServiceScript.new().load_run(slot)
	check(restored is RunState, "cold Continue failed")
	return restored if restored is RunState else run


func check_delivery_hud(run: RunState) -> void:
	# Build the production run shell without startup/gameplay. The package is
	# accepted through the normal event API above; UI projection must be read-only.
	var before := JSON.stringify([run.bankroll, run.rng_state, run.game_clock_minutes, run.active_delivery_run, run.debt])
	var host := LayoutHost.new()
	host.library = library
	host.run_state = run
	host.current_screen = host.SCREEN_ENVIRONMENT
	host.continuous_environment_clock_enabled = false
	root.add_child(host)
	host.screen_stack_root = Control.new()
	host.screen_stack_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(host.screen_stack_root)
	check(host._build_next_run_ui_stage(), "production HUD could not build")
	host.run_screen.visible = true
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		host.size = viewport_size
		host._refresh_delivery_action_strip()
		host._invalidate_run_screen_layout()
		host._apply_run_screen_layout()
		for frame in range(8):
			await process_frame
		var strip := host.delivery_action_strip
		var panel_rect := host.run_hud_panel.get_global_rect()
		check(strip.visible and strip.get_child_count() > 0, "active package HUD is missing at %s" % viewport_size)
		check(panel_rect.encloses(strip.get_global_rect()), "package HUD is clipped at %s" % viewport_size)
		for child in strip.get_children():
			check(panel_rect.encloses(child.get_global_rect()), "package term/action is outside clipped HUD at %s" % viewport_size)
		check(str(strip.get_child(0).text).contains("Day "), "persistent HUD omits appointment day/time")
		check(host.visual_panel_container.get_global_rect().position.y >= panel_rect.end.y, "room covers persistent package HUD")
	var active_height := host.run_hud_panel.size.y
	host.run_state = RunStateScript.new()
	host._refresh_delivery_action_strip()
	for frame in range(8):
		await process_frame
	check(not host.delivery_action_strip.visible and host.run_hud_panel.size.y < active_height, "finished delivery leaves stale HUD footprint")
	check(JSON.stringify([run.bankroll, run.rng_state, run.game_clock_minutes, run.active_delivery_run, run.debt]) == before, "HUD changed money/RNG/clock/delivery/debt")
	host.queue_free()
	await process_frame


func _run() -> void:
	library = ContentLibraryScript.new()
	library.load()
	var run := make_run("CREW-WINDOW-REAL-ROUTE")
	accept_favor(run)
	await check_delivery_hud(run)
	print("CREW_PACKAGE_APPOINTMENT " + run.delivery_timing_text())
	var original := run.active_delivery_run.duplicate(true)
	var jobs := run.crew_jobs.duplicate(true)
	var trust := run.crew_trust("crew_rook")
	for _click in range(3):
		check(not bool(run.resolve_crew_favor_delivery_job("run_package").get("ok", false)), "duplicate favor was accepted")
	run.current_environment["crew_presence"] = [{"member_id": "crew_rook"}]
	check(not bool(run.crew_job_accept_definition("rook_quiet_package").get("ok", false)), "alternate board package replaced active assignment")
	check(run.crew_jobs == jobs and run.active_delivery_run == original and run.crew_trust("crew_rook") == trust, "duplicate attempts mutated route/jobs/trust")
	var restored := save_continue(run, "crew_window_active")
	check(restored.active_delivery_run == original, "Save/Continue changed active window")
	check(not bool(restored.resolve_crew_favor_delivery_job("run_package").get("ok", false)), "Continue reopened accepted favor")
	# Native production generation/finalization and travel APIs, with the same
	# walking duration the UI applies before installing the destination.
	var target: Dictionary = restored.delivery_snapshot().get("targets", [])[0]
	var route := WorldMap.new(library).route_for_target(restored.world_map, restored.current_world_node_id(), str(target.get("node_id", "")))
	restored.advance_game_clock_minutes(maxi(1, int(route.get("distance_blocks", 1))) * 10)
	var generator := RunGeneratorScript.new(library)
	Fidelity.travel_and_finalize(generator, restored, str(target.get("node_id", "")), true, library, failures, "crew real walking arrival")
	var arrival := restored.delivery_resolve_travel_arrival(route, {})
	check(bool(arrival.get("ok", false)), "travel delivery projection failed: %s" % arrival)
	var window := Schedule.window_for(restored.active_delivery_run, str(target.get("node_id", "")))
	if restored.game_clock_minutes < int(window.get("opens", 0)):
		var early := restored.delivery_complete_handoff()
		check(not bool(early.get("ok", false)) and str(early.get("message", "")).contains("Day "), "early arrival did not explain availability")
	restored.advance_game_clock_minutes(int(window.get("opens", 0)) - restored.game_clock_minutes)
	restored = save_continue(restored, "crew_window_at_open")
	var cash_before := restored.bankroll
	var handoff := restored.delivery_complete_handoff()
	check(bool(handoff.get("ok", false)) and not restored.delivery_has_active_run(), "handoff at opening failed: %s" % handoff)
	check(restored.bankroll == cash_before + 22, "favor payout changed")
	var paid_cash := restored.bankroll
	restored = save_continue(restored, "crew_window_paid")
	restored.delivery_complete_handoff()
	restored.advance_game_clock_minutes(1440)
	check(restored.bankroll == paid_cash and int(restored.narrative_flags.get("profile_delivery_runs_completed", 0)) == 1, "reward/report duplicated after Continue")
	# Midnight and exact boundaries use a synthetic clock fixture, detached from
	# room generation, to exercise minute 0 and large time-skips without ambiguity.
	var spec := {"mode": "package", "run_id": "crew_boundary", "start_node_id": "motel", "targets": [{"node_id": "bar"}], "deadline_kind": "clock", "deadline_minutes": 70, "started_game_clock_minutes": 1400, "deadline_game_clock_minutes": 1470, "consumer_payload": {"meeting_windows": [{"node_id": "bar", "opens": 1440, "closes": 1470}]}}
	var state := DeliveryModel.begin(spec, 0)
	check(not state.is_empty(), "synthetic clock fixture is invalid")
	state = DeliveryModel.advance_clock(state, 1439)
	check(not Schedule.handoff_open(state, "bar"), "handoff opened before midnight")
	state = DeliveryModel.advance_clock(state, 1440)
	check(Schedule.handoff_open(state, "bar"), "handoff did not open at midnight")
	state = DeliveryModel.advance_clock(state, 1469)
	check(str(state.get("status", "")) == "active" and Schedule.handoff_open(state, "bar"), "last valid minute was rejected")
	state = DeliveryModel.advance_clock(state, 1470)
	check(str(state.get("status", "")) == "resolved", "closing minute did not expire")
	check(str(DeliveryModel.advance_clock(DeliveryModel.begin(spec, 0), 3000).get("status", "")) == "resolved", "time skip crossed window without failure")
	# Multiple stops each own a strict window. Missing the first is terminal even
	# when the final route deadline is still in the future.
	var multi_spec := spec.duplicate(true)
	multi_spec["mode"] = "multi_stop"
	multi_spec["targets"] = [{"node_id": "bar"}, {"node_id": "motel"}]
	multi_spec["deadline_game_clock_minutes"] = 1600
	multi_spec["deadline_minutes"] = 200
	multi_spec["consumer_payload"]["meeting_windows"].append({"node_id": "motel", "opens": 1570, "closes": 1600})
	check(str(DeliveryModel.advance_clock(DeliveryModel.begin(multi_spec, 0), 1470).get("status", "")) == "resolved", "route ignored a missed intermediate window")
	var board: RunState = CrewFixture._crew_run("CREW-BOARD-CLOCK")
	board.current_environment["crew_presence"] = [{"member_id": "crew_rook"}]
	var board_module := EventModuleScript.new()
	board_module.setup(library.event("crew_job_board"), library)
	var board_rows := board_module.choices(board, board.current_environment)
	var board_flavor_count := 0
	for row in board_rows:
		for flavor in library.event("crew_job_board").get("payload", {}).get("flavor_lines", []):
			if str(row.get("text", "")).contains(str(flavor)): board_flavor_count += 1
	check(board_flavor_count == 1, "appointment projection lost/repeated the board flavor")
	var board_choice := board_module.choice("accept_rook_quiet_package", board, board.current_environment)
	check(str(board_choice.get("text", "")).contains("Day "), "board offer omitted appointment")
	var board_started := board.crew_job_accept_definition("rook_quiet_package", int(board_choice.get("consequences", {}).get("event_hooks", [{}])[0].get("offered_clock", -1)))
	check(bool(board_started.get("ok", false)) and board.active_delivery_run.get("deadline_kind") == "clock", "board did not start a clock package: %s" % board_started)
	var board_jobs := board.crew_jobs.duplicate(true)
	check(not bool(board.resolve_crew_favor_delivery_job("run_package").get("ok", false)) and board.crew_jobs == board_jobs, "favor overwrote a board assignment")
	board = save_continue(board, "crew_board_clock")
	check(board.delivery_has_active_run() and board.active_delivery_run.get("deadline_kind") == "clock", "board assignment did not survive Continue")
	var collection := CrewFixture._crew_run("CREW-COLLECTION-UNCHANGED")
	var collection_started: Dictionary = CrewFixture._accept_job(collection, "knuckles_friendly_collection")
	check(bool(collection_started.get("ok", false)) and collection.active_delivery_run.get("deadline_kind") == "actions", "non-package collection timing changed")
	var missed := make_run("CREW-WINDOW-MISS")
	accept_favor(missed)
	var before_trust := missed.crew_trust("crew_rook")
	var before_heat := missed.suspicion_level()
	var closes := Schedule.next_deadline(missed.active_delivery_run)
	missed.advance_game_clock_minutes(closes - missed.game_clock_minutes)
	check(not missed.delivery_has_active_run() and missed.crew_trust("crew_rook") == before_trust - 5 and missed.suspicion_level() == before_heat + 9, "missed favor did not apply authored trust/Heat")
	check(str(missed.active_delivery_run.get("receipt", {}).get("failure_message", "")).contains("Missed delivery"), "failure omitted explicit message")
	var grievance_count := missed.crew_grievances().size()
	missed = save_continue(missed, "crew_window_missed")
	missed.advance_game_clock_minutes(60)
	check(missed.crew_trust("crew_rook") == before_trust - 5 and missed.suspicion_level() == before_heat + 9 and missed.crew_grievances().size() == grievance_count and int(missed.narrative_flags.get("profile_delivery_packages_lost", 0)) == 1, "failure duplicated after Continue")
	var legacy := make_run("CREW-WINDOW-LEGACY")
	accept_favor(legacy)
	var old := legacy.to_dict()
	var old_delivery: Dictionary = old.get("active_delivery_run", {})
	if old_delivery.is_empty():
		print("CREW_PACKAGE_WINDOWS incomplete: %s" % JSON.stringify(failures))
		quit(1)
		return
	old_delivery["deadline_kind"] = "actions"
	old_delivery["deadline_remaining"] = 1
	old_delivery["consumer_payload"].erase("meeting_windows")
	var migrated := RunStateScript.new()
	migrated.from_dict(old)
	check(migrated.delivery_has_active_run() and migrated.active_delivery_run.get("deadline_kind") == "clock" and migrated.crew_trust("crew_rook") == legacy.crew_trust("crew_rook"), "legacy migration penalized or lost active package")
	var migrated_windows: Array = migrated.active_delivery_run.get("consumer_payload", {}).get("meeting_windows", [])
	migrated = save_continue(migrated, "crew_window_migrated")
	check(migrated.active_delivery_run.get("consumer_payload", {}).get("meeting_windows", []) == migrated_windows, "Continue repeatedly extended migrated window")
	old_delivery["deadline_kind"] = "clock"
	old_delivery["deadline_game_clock_minutes"] = 1
	var expired_legacy := RunStateScript.new()
	expired_legacy.from_dict(old)
	check(expired_legacy.delivery_has_active_run() and Schedule.next_deadline(expired_legacy.active_delivery_run) > expired_legacy.game_clock_minutes, "old countdown was penalized instantly on Continue")
	var cooldown := make_run("CREW-COOLDOWN")
	check(cooldown.enqueue_triggered_event("crew_favor_delivery", "game_action", {}, {"presentation": "talk"}), "initial solicitation failed")
	cooldown.complete_talk_event_resolution("crew_favor_delivery")
	cooldown = save_continue(cooldown, "crew_cooldown")
	for _repeat in range(4):
		check(not cooldown.event_cadence_allows_world_event("crew_favor_delivery", "random", "game_action", library.event("crew_favor_delivery")) and not cooldown.enqueue_triggered_event("crew_favor_delivery"), "reentry/cold Continue bypassed cooldown")
	cooldown.advance_game_clock_minutes(359)
	check(not cooldown.crew_package_solicitation_available(), "cooldown ended early")
	cooldown.advance_game_clock_minutes(1)
	check(cooldown.crew_package_solicitation_available(), "six-hour cooldown did not end")
	cooldown.narrative_flags["grand_casino_showdown_active"] = true
	check(not cooldown.event_cadence_allows_world_event("crew_favor_delivery", "random", "game_action", library.event("crew_favor_delivery")), "Rourke scripted sequence permits solicitation")
	cooldown.pending_triggered_events.append({"event_id": "crew_favor_delivery", "presentation": "talk", "source": "legacy", "context": {}})
	cooldown = save_continue(cooldown, "crew_queued_during_showdown")
	check(cooldown.next_pending_talk_event().is_empty(), "Continue displayed an old queued Crew call during the showdown")
	print("CREW_PACKAGE_WINDOWS cases=duplicate_sources,save_continue,real_walking_route,early,opening,midnight,close,skip,once_failure,once_reward,legacy,cooldown,showdown failures=%s" % JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
