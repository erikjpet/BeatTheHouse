extends SceneTree

# BTH-GAS-SCRATCHER-EXIT-001: independent generated host fixtures, not an
# import/replay of the unavailable reported campaign. Initial time/cash, an
# authored diagnostic scenario pin and an explicit already-visited stocked-room
# input are established before manifest construction and authority seals.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Map := preload("res://scripts/core/world_map.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Mask := preload("res://scripts/games/scratch_ticket_mask.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const CASES := [{"id": "close", "minute": 4469, "boundary": 4470}, {"id": "gap_middle", "minute": 4515, "boundary": -1}, {"id": "open", "minute": 4559, "boundary": 4560}, {"id": "day1_1630_117", "minute": 990, "boundary": -1, "post_purchase_cash": 117}]

class FixtureGenerator:
	extends RunGenerator
	var target_post_purchase_cash := -1
	var supply_inputs: Array = []
	var supply_input_count := 0
	var visited_input_count := 0
	func _init(content: ContentLibrary) -> void:
		super(content)
	func _generated_game_states(state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
		var states := super._generated_game_states(state, environment, rng)
		if str(environment.get("archetype_id", "")) != "gas_station_casino": return states
		var machine: Dictionary = states.get("scratch_tickets", {})
		var stock: Array = machine.get("stock", [])
		var first := -1
		var available := 0
		for index in range(stock.size()):
			var row: Dictionary = stock[index]
			if str(row.get("release_availability", "active")) == "held": continue
			available += int(row.get("remaining", 0))
			if first < 0 and int(row.get("capacity", 0)) >= 1: first = index
		var input := {"phase": "factory_before_manifest_and_seals", "fixture_kind": "synthetic_already_visited_stocked_room_not_natural_first_visit", "active_supply_before": available, "applied": false, "scalper_before": machine.get("scalper_present", false), "next_restock_preserved": machine.get("next_restock_absolute_minute", -1), "visited_changes": {}}
		if available == 0 and first >= 0:
			var row: Dictionary = stock[first]
			input.merge({"applied": true, "field": "stock[%d].remaining" % first, "from": row.get("remaining", 0), "to": 1, "type_id": row.get("type_id", ""), "price_preserved": row.get("price", 0)})
			row["remaining"] = 1
			supply_input_count += 1
		# Match the established one-arrival fixture: initialization models an
		# already-visited stocked room, rather than claiming a negative visit roll.
		var visited := {"scalper_visit_token": "%s@%d" % [RunState.portable_ticket_origin_key(environment), state.game_clock_minutes], "scalper_present": false, "scalper_knows_schedule": false}
		for key in visited:
			if machine.get(key) != visited[key]:
				input.visited_changes[key] = {"from": machine.get(key), "to": visited[key]}
				machine[key] = visited[key]
		if not input.visited_changes.is_empty(): visited_input_count += 1
		input["scalper_after"] = machine.get("scalper_present", false)
		input["visit_token_after"] = machine.get("scalper_visit_token", "")
		if target_post_purchase_cash >= 0:
			var cheapest := 2147483647
			for row in stock:
				if int(row.get("remaining", 0)) > 0 and str(row.get("release_availability", "active")) != "held":
					cheapest = mini(cheapest, int(row.get("price", 0)))
			if cheapest < 2147483647:
				input["preseal_cash_fixture"] = {"before": state.bankroll, "after": target_post_purchase_cash + cheapest, "normal_ticket_price": cheapest}
				state.change_bankroll(target_post_purchase_cash + cheapest - state.bankroll, true)
		supply_inputs.append(input)
		return states

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"fidelity": "Independent generated Gas rooms with explicit already-visited stocked-room initialization before seals; optional zero-to-one supply input and every scalper flag/token change recorded; prices/types/restocks/RNG/ticket outcomes unchanged; not natural-first-visit or original-campaign proof", "cold_scope": "warm host Save/Continue followed by separate-process same-profile host Continue; original campaign unavailable", "cases": {}}
var app: Control
var run: RunState
var case_facts: Dictionary
var case_id := ""
var phase := "warm"

func _init() -> void:
	phase = OS.get_environment("BTH_GAS_PHASE")
	if not ["warm", "cold"].has(phase):
		quit(64)
		return
	# This guard runs before a host or persistence service is instantiated.
	var private_root := _path(OS.get_environment("BTH_GAS_PRIVATE_ROOT"))
	var ready := not private_root.is_empty() and private_root.is_absolute_path()
	ready = ready and _path(ProjectSettings.globalize_path("user://")).begins_with(private_root + "/")
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_DEVELOPER_PLACEMENT_PATH", "BTH_TARGET_OUTPUT"]:
		ready = ready and _path(OS.get_environment(key)).begins_with(private_root + "/")
	for key in ["BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_DEVELOPER_PLACEMENT_PATH", "BTH_TARGET_OUTPUT"]:
		if phase == "warm":
			for suffix in ["", ".bak", ".tmp"]:
				ready = ready and not FileAccess.file_exists(OS.get_environment(key) + suffix)
	ready = ready and OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").strip_edges().is_empty()
	if not ready:
		push_error("REFUSED: user:// and every explicit persistence/output path must be inside BTH_GAS_PRIVATE_ROOT")
		quit(64)
		return
	call_deferred("_run")

func _path(value: String) -> String:
	return value.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(case_id + ": " + message)
	return ok

func _run() -> void:
	app = Host.new()
	app.set("continuous_environment_clock_enabled", false)
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	await process_frame
	await process_frame
	if not _check(bool(app.call("_ensure_run_ui_built")), "host UI builds"):
		_finish()
		return
	app.call("_ensure_full_content_library_loaded")
	if phase == "cold":
		await _run_cold()
		app.get("save_service").wait_for_async_save()
		app.queue_free()
		await process_frame
		_finish()
		return
	for row in CASES:
		case_id = str(row.id)
		case_facts = {"initial_clock": row.minute, "stages": []}
		facts.cases[case_id] = case_facts
		await _run_case(int(row.minute), int(row.boundary), int(row.get("post_purchase_cash", -1)))
		if not failures.is_empty(): break
	app.set("continuous_environment_clock_enabled", false)
	app.get("save_service").wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()

func _run_case(initial_minute: int, boundary: int, post_purchase_cash: int) -> void:
	app.get("save_service").wait_for_async_save()
	var seed := "BTH-GAS-SCRATCH-CLOCK-INDEPENDENT-" + case_id
	run = RunState.new()
	run.start_new(seed, RunState.custom_challenge("gas_scratch_clock", seed, {"scenario_pins": {"gas_station_casino": "gas_station_graveyard_shift"}}))
	run.begin_act(1)
	run.game_clock_minutes = initial_minute
	run.change_bankroll(1000 - run.bankroll, true)
	var library: ContentLibrary = app.get("library")
	run.set_world_map(Map.new(library).build(run, run.create_rng("gas_clock_fixture_world")))
	var generator := FixtureGenerator.new(library)
	generator.target_post_purchase_cash = post_purchase_cash
	var errors: Array = []
	var arrived := Fidelity.generate_and_finalize(generator, run, errors, "Gas clock fixture", "gas_station_casino", true)
	case_facts["generation_errors"] = errors
	case_facts["factory_supply_inputs"] = generator.supply_inputs
	case_facts["factory_supply_input_count"] = generator.supply_input_count
	case_facts["factory_visited_input_count"] = generator.visited_input_count
	if not _check(bool(arrived.get("ok", false)), "production generation/finalization: " + JSON.stringify(errors)): return
	if not _check(run.game_clock_minutes == initial_minute, "generation preserves declared initial clock"): return
	app.call("_reset_game_surface_runtime_state")
	app.set("current_game", null)
	app.set("run_state", run)
	app.set("generator", generator)
	app.set("environment_clock_fractional_minutes", 0.0)
	app.set("autosave_slot_id", "gas_scratch_clock_" + case_id)
	app.call("_bind_run_state_presentation_signals")
	app.call("_configure_coach_for_run")
	app.call("_refresh_run_action_service")
	app.call("_clear_input_guard_modal_state")
	app.call("_queue_room_publication_check")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh_runtime_environment_views")
	await process_frame
	await process_frame
	var practice := bool(run.current_environment.get("local_narrative_flags", {}).get("practice_session", false))
	case_facts["lifecycle"] = {"act": run.act_index, "tutorial": run.is_tutorial_run(), "practice": practice, "environment_test": app.call("_is_environment_test_session"), "run_status": run.run_status, "pending_terminal": app.call("_all_in_result_terminal_check_is_pending"), "objective": run.demo_objective_status()}
	if not _check(run.act_index == 1 and not run.is_tutorial_run() and not practice and not bool(app.call("_is_environment_test_session")), "fixture uses normal Act 1, not tutorial/practice/environment-test lifecycle"): return
	if not _check(run.run_status == RunState.RUN_STATUS_ACTIVE and not bool(app.call("_all_in_result_terminal_check_is_pending")), "initial fixture remains active without a pending terminal result"): return
	_capture("generated_room")
	if not _check(_base_controls_ok(), "generated base Leave and Scratchers controls are usable"): return
	if not _check(bool(app.call("enter_game", "scratch_tickets")), "ordinary Scratchers entry succeeds"): return
	if not await _gate("scratch_buy"): return
	var stock: Array = _machine().get("stock", [])
	var stock_index := -1
	var price := 2147483647
	var supply_rows: Array = []
	for index in range(stock.size()):
		var row: Dictionary = stock[index]
		supply_rows.append({"index": index, "type_id": row.get("type_id", ""), "price": row.get("price", 0), "remaining": row.get("remaining", 0), "capacity": row.get("capacity", 0), "release_availability": row.get("release_availability", "active")})
		if int(row.get("remaining", 0)) > 0 and str(row.get("release_availability", "active")) != "held" and int(row.get("price", 0)) < price:
			stock_index = index
			price = int(row.get("price", 0))
	case_facts["purchase_slot"] = stock_index
	case_facts["price"] = price
	case_facts["stock_observation"] = {"state_keys": run.current_environment.get("game_states", {}).keys(), "active_keys": run.current_environment.get("active_game_state_keys", {}), "host_state_key": app.get("current_game_state_key"), "module_id": app.get("current_game").get_id(), "raw_rows": supply_rows, "projected_rows": app.get("game_surface_canvas").get("state").get("scratch_stock", []), "scalper": _machine().get("scalper_present", false), "next_restock": _machine().get("next_restock_absolute_minute", -1)}
	if not _check(stock_index >= 0, "explicit pre-seal supply fixture exposes one normal-price ticket without a seed reroll or post-seal rewrite"): return
	var purchase_cash := run.bankroll
	case_facts["pre_purchase_cash"] = purchase_cash
	_capture("before_buy")
	app.call("_on_game_surface_action", "scratch_buy", stock_index)
	# Scratch actions advance action turns, not the wall clock. Let ordinary
	# no-input host processing cross the real minute during the live surface;
	# never inject a clock delta or rewrite an installed run's clock.
	if boundary >= 0 and not await _cross_boundary(boundary): return
	if not await _gate("scratch_collect_tray"): return
	_capture("after_buy")
	var tray: Array = _machine().get("tray_stack", [])
	if not _check(tray.size() == 1 and run.bankroll == purchase_cash - price, "one ordinary purchase debits once and delivers one ticket"): return
	var ticket_id := str(tray[0].get("id", ""))
	case_facts["ticket_id"] = ticket_id
	app.call("_on_game_surface_action", "scratch_collect_tray", 0)
	if not await _gate("scratch_all"): return
	_capture("after_collect")
	if not _check(str(_machine().get("active_ticket", {}).get("id", "")) == ticket_id and _machine().get("tray_stack", []).is_empty(), "collection preserves the generated ticket once"): return
	app.call("_on_game_surface_action", "scratch_all", 0)
	if not await _gate("scratch_file_ticket"): return
	_capture("after_scratch")
	if not _check(Mask.ticket_complete(_machine().get("active_ticket", {})), "normal Scratch All completes this generated ticket"): return
	app.call("_on_game_surface_action", "scratch_file_ticket", 0)
	if not await _gate("scratch_buy"): return
	_capture("after_file")
	if not _check(_filed_ids().count(ticket_id) == 1 and _machine().get("active_ticket", {}).is_empty(), "File retains exactly one generated settled ticket"): return
	_check(run.bankroll == purchase_cash - price, "Collect/Scratch/File add no debit or counter payout")
	app.call("back_to_environment")
	await process_frame
	await process_frame
	_capture("after_back")
	if not _check(str(app.get("current_screen")) == "ENVIRONMENT" and _base_controls_ok(), "Back preserves usable base controls even without scenario content"): return
	var expected := _protected()
	case_facts["saved_signature"] = expected.duplicate(true)
	if post_purchase_cash >= 0:
		_check(run.bankroll == post_purchase_cash and run.game_clock_minutes == 990, "independent reported money/time shape reached without modifying live outcomes")
	if not _check(bool(app.call("_autosave_foundation_run", "Gas clock fixture Save", true)), "normal host Save succeeds"): return
	var slot := str(app.get("autosave_slot_id"))
	var disk_service := SaveService.new()
	var disk: RunState = disk_service.load_run(slot)
	case_facts["disk_load_outcome"] = disk_service.last_load_result()
	case_facts["disk_signature"] = _protected_for(disk) if disk != null else {}
	case_facts["after_save_signature"] = _protected()
	case_facts["in_memory_container_equality"] = disk != null and _protected_for(disk) == expected
	case_facts["persistence_comparison"] = "Compare JSON values, not engine typed/untyped container identity; all full portable data retained in signatures. Cash/clock/Heat/RNG also retained as scalar witnesses."
	if not _check(disk != null and _same_saved_values(_protected_for(disk), expected), "fresh SaveService retains exact protected state"): return
	app.set("save_service", SaveService.new())
	if not _check(bool(app.call("load_foundation_run")), "normal host Continue with a fresh service succeeds"): return
	run = app.get("run_state")
	await process_frame
	await process_frame
	_capture("after_continue")
	_check(_same_saved_values(_protected(), expected) and _filed_ids().count(ticket_id) == 1, "Continue preserves clock/cash/Heat/RNG/ticket custody without repeated actions")
	_check(_base_controls_ok(), "Continue preserves usable base controls")
	await _exercise_leave("warm")

func _cross_boundary(boundary: int) -> bool:
	var began := Time.get_ticks_msec()
	case_facts["clock_before_wait"] = run.game_clock_minutes
	app.set("continuous_environment_clock_enabled", true)
	while run.game_clock_minutes < boundary and Time.get_ticks_msec() - began < 5000:
		await process_frame
	app.set("continuous_environment_clock_enabled", false)
	case_facts["boundary_wait"] = {"target": boundary, "clock_after": run.game_clock_minutes, "elapsed_msec": Time.get_ticks_msec() - began, "screen": app.get("current_screen"), "live_scratchers": app.get("current_game") != null and app.get("current_game").get_id() == "scratch_tickets", "blocking_message": app.call("_blocking_modal_message"), "simulation_paused": app.call("_simulation_progression_paused")}
	_capture("after_normal_clock_wait")
	var expected_scenario := "" if case_id == "close" else "gas_station_graveyard_shift"
	if not _check(str(run.current_environment.get("scenario_id", "")) == expected_scenario and not bool(app.get("_scenario_cycle_publication_failed")), "clock boundary publishes the expected scenario phase without rejection (expected " + expected_scenario + ")"): return false
	return _check(run.game_clock_minutes >= boundary and Time.get_ticks_msec() - began <= 5000 and str(app.get("current_screen")) == "GAME" and app.get("current_game") != null, "normal no-input processing crosses the boundary on the live Scratchers surface within five seconds; no blocking choice answered")

func _gate(next_action: String) -> bool:
	var deadline := Time.get_ticks_msec() + 7000
	await process_frame
	while bool(app.call("_deferred_embedded_refresh_blocks_current_surface_input")) or bool(app.get("game_surface_canvas").call("surface_action_is_blocked", next_action)) or bool(app.get("game_surface_canvas").call("surface_transition_animation_active")):
		if Time.get_ticks_msec() >= deadline:
			_capture("gate_timeout_" + next_action)
			return _check(false, "finite delivery/presentation gate did not release for " + next_action)
		await process_frame
	var blocked := str(app.call("_blocking_modal_message"))
	if not blocked.is_empty():
		case_facts["legitimate_blocking_state"] = blocked
		return _check(false, "authored decision/modal blocks progression; no choice resolved: " + blocked)
	return true

func _machine() -> Dictionary:
	return run.current_environment.get("game_states", {}).get("scratch_tickets", {})

func _filed_ids() -> Array:
	var ids: Array = []
	for field in ["winner_pile", "loser_pile"]:
		for ticket in _machine().get(field, []): ids.append(str(ticket.get("id", "")))
	return ids

func _base_controls_ok() -> bool:
	var controls := _controls()
	return bool(controls.get("travel:leave", {}).get("usable", false)) and bool(controls.get("game:scratch_tickets", {}).get("usable", false))

func _controls() -> Dictionary:
	var result: Dictionary = {}
	var canvas: Control = app.get("environment_canvas")
	for object in canvas.get("foundation_scene_objects"):
		var id := str(object.get("id", ""))
		if id == "travel:leave" or id.begins_with("game:"):
			var hit: Rect2 = canvas.call("_interaction_rect_for_object", object)
			result[id] = {"interactive": object.get("interactive", false), "disabled": object.get("disabled", false), "hit": {"x": hit.position.x, "y": hit.position.y, "w": hit.size.x, "h": hit.size.y}, "usable": bool(object.get("interactive", false)) and not bool(object.get("disabled", false)) and hit.has_area()}
	return result

func _capture(stage: String) -> void:
	var raw := Controller._object_manifest_join_proof(run.current_environment.duplicate(true))
	var authority := run.validate_room_action_authority()
	case_facts.stages.append({"stage": stage, "clock": run.game_clock_minutes, "scenario": run.current_environment.get("scenario_id", ""), "cash": run.bankroll, "heat": run.suspicion_level(), "rng": str(run.rng_state), "purchased": _machine().get("purchased_count", 0), "active_id": _machine().get("active_ticket", {}).get("id", ""), "filed_ids": _filed_ids(), "scalper": _machine().get("scalper_present", false), "next_restock": _machine().get("next_restock_absolute_minute", -1), "controls": _controls(), "raw_join_ok": raw.get("ok", false), "raw_join_errors": raw.get("errors", []), "authority_ok": authority.get("ok", false), "authority_errors": authority.get("errors", []), "cycle_publication_failed": app.get("_scenario_cycle_publication_failed"), "recovery_generation": app.get("room_recovery_generation"), "publication_generation": app.get("room_publication_generation")})
	_check(bool(raw.get("ok", false)) and bool(authority.get("ok", false)), stage + " retains raw room authority: " + JSON.stringify(raw.get("errors", [])) + JSON.stringify(authority.get("errors", [])))

func _protected() -> Dictionary:
	return _protected_for(run)

func _protected_for(state: RunState) -> Dictionary:
	return {"clock": state.game_clock_minutes, "cash": state.bankroll, "heat": state.suspicion_level(), "rng": str(state.rng_state), "portable": state.portable_ticket_piles.duplicate(true), "inventory": state.inventory.duplicate(true), "scenario": str(state.current_environment.get("scenario_id", "")), "environment_id": str(state.current_environment.get("id", ""))}

func _finish() -> void:
	facts["phase"] = phase
	facts["checks"] = checks
	facts["failures"] = failures
	var output := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(facts, "  "))
		output.close()
	print("GAS_SCRATCH_CLOCK checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)


func _run_cold() -> void:
	var warm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_GAS_WARM_REPORT")))
	if not _check(not warm.is_empty() and warm.get("failures", ["missing"]).is_empty(), "warm evidence is present and passed"):
		return
	for row in CASES:
		case_id = str(row.id)
		case_facts = {"stages": []}
		facts.cases[case_id] = case_facts
		app.set("autosave_slot_id", "gas_scratch_clock_" + case_id)
		var loaded := bool(app.call("load_foundation_run"))
		run = app.get("run_state")
		if not _check(loaded and run != null, "separate-process normal Continue succeeds"):
			return
		await process_frame
		await process_frame
		_capture("first_cold_continue")
		case_facts["load_outcome"] = app.get("save_service").last_load_result()
		_check(_same_saved_values(_protected(), warm.cases[case_id].saved_signature), "cold Continue preserves exact clock/cash/heat/RNG/ticket custody/scenario")
		_check(_base_controls_ok(), "cold Continue publishes usable base controls")
		await _exercise_leave("cold")
		if not failures.is_empty():
			return


func _exercise_leave(stage: String) -> void:
	var before := _protected()
	var activated := bool(app.call("activate_interactable_object", "travel:leave"))
	await process_frame
	case_facts[stage + "_leave"] = {"activated": activated, "map_visible": app.call("_world_map_overlay_is_visible")}
	_check(activated and bool(app.call("_world_map_overlay_is_visible")), stage + " ordinary Leave opens map")
	app.call("close_world_map")
	await process_frame
	_check(not bool(app.call("_world_map_overlay_is_visible")) and _base_controls_ok(), stage + " map Close restores room controls")
	_check(_protected() == before, stage + " Leave/Close does not debit, advance time, reroll or change ticket custody")


func _same_saved_values(left: Dictionary, right: Dictionary) -> bool:
	# Persistence returns ordinary JSON containers, while live fixture tickets
	# may use typed containers. Preserve and compare every JSON value without
	# asserting engine-only container typing survives serialization.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
