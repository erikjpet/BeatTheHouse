extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Fixture := preload("res://scripts/tests/pull_tab_grand_fixture.gd")
const SLOT := "foundation_ui_autosave"
const FLOOR_SLOT := "pull_tab_grand_floor"
const SEED := "BTH061-PULLTABS-GRAND-INDEPENDENT-1"
const AUDIT_SEED := "BTH061-PULLTABS-GRAND-AUDIT-INDEPENDENT-1"
const AUDIT_SCENARIO := "grand_casino_audit_night"
var failures: Array[String] = []
var checks := 0
var completed := false
var fixture_facts: Dictionary = {}


func _initialize() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		completed = true
		push_error("Independent Grand save check requires an explicitly isolated distribution root")
		quit(1)
		return
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _progress(stage: String) -> void:
	print("PULL_TAB_GRAND_PROGRESS stage=", stage, " ticks_msec=", Time.get_ticks_msec())


func _pile(run: RunState) -> Dictionary:
	return run.portable_ticket_state("pull_tabs", run.current_environment)


func _snapshot(run: RunState) -> Dictionary:
	var machine: Dictionary = run.current_environment.get("game_states", {}).get("pull_tabs", {})
	var card_bits: Dictionary = {}
	for value in run.inventory:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var meta: Dictionary = value.get("meta_collection", {})
		if int(meta.get("itemdef_id", 0)) != 9500:
			continue
		var bits: Dictionary = {}
		for key in ["potency", "condition", "resonance", "usage"]:
			bits[key] = var_to_bytes(float(meta.get("floats", {}).get(key, -1.0))).hex_encode()
		card_bits[str(value.get("id", ""))] = bits
	var snapshot: Dictionary = {
		"pile": _pile(run), "cash": run.bankroll, "chips": run.grand_casino_chips,
		"rng": str(run.rng_state), "heat": run.suspicion_level(),
		"tickets_sold": machine.get("tickets_sold", 0), "deals": machine.get("deals", []),
		"inventory": run.inventory, "card_float_bits": card_bits,
		"pending_bags": run.pending_bags, "challenge_modifiers": run.challenge_modifiers(),
	}
	if OS.get_cmdline_user_args().has("--audit"):
		snapshot["scenario_id"] = run.current_environment.get("scenario_id", "")
	if OS.get_cmdline_user_args().has("--audit") or OS.get_cmdline_user_args().has("--elapsed"):
		snapshot["clock_minutes"] = run.game_clock_minutes
	return JSON.parse_string(JSON.stringify(snapshot))


func _expected_path() -> String:
	return SaveService.new().run_save_path(SLOT).get_base_dir().path_join("pull_tab_grand_expected.json")


func _verify_slot(slot: String, expected: Dictionary) -> void:
	var loaded: RunState = SaveService.new().load_run(slot)
	if not _check(loaded != null, slot + " is not loadable"):
		return
	_check(_snapshot(loaded) == expected, slot + " changed ticket/stock/wallet/Heat/exactRNG/card/bag")
	_check(_pile(loaded).get("tray_stack", []).is_empty() and _pile(loaded).get("ticket_stack", []).size() == 1, slot + " lost collected custody")


func _check_navigation_state(actual: Dictionary, saved: Dictionary, label: String) -> void:
	# Enter/Leave legitimately consume game time. Keep exact clock comparison at
	# Save/load, while requiring monotonic time and protected state on navigation.
	var actual_protected := actual.duplicate(true)
	var saved_protected := saved.duplicate(true)
	actual_protected.erase("clock_minutes")
	saved_protected.erase("clock_minutes")
	_check(actual_protected == saved_protected, label + " changed protected state")
	if saved.has("clock_minutes"):
		_check(actual.has("clock_minutes") and int(actual["clock_minutes"]) >= int(saved["clock_minutes"]), label + " moved the game clock backward")


func _advance_elapsed_clock(run: RunState, label: String) -> bool:
	# Exercise a new elapsed-time generation without changing ticket outcomes.
	# Use the production clock API rather than rewriting an encoded save value.
	var before := _snapshot(run)
	var previous_minutes := run.game_clock_minutes
	var advance_result: Dictionary = run.advance_game_clock_minutes(45)
	var after := _snapshot(run)
	var advances: Array = fixture_facts.get("elapsed_clock_advances", [])
	advances.append({
		"boundary": label, "minutes": 45, "before": previous_minutes,
		"after": run.game_clock_minutes, "result": advance_result.duplicate(true),
	})
	fixture_facts["elapsed_clock_advances"] = advances
	var before_protected := before.duplicate(true)
	var after_protected := after.duplicate(true)
	before_protected.erase("clock_minutes")
	after_protected.erase("clock_minutes")
	var ok := _check(bool(advance_result.get("ok", false)), label + " production elapsed clock advance failed: " + JSON.stringify(advance_result))
	ok = _check(run.game_clock_minutes == previous_minutes + 45, label + " did not advance exactly 45 minutes") and ok
	ok = _check(after_protected == before_protected, label + " elapsed clock advance changed protected nonclock state") and ok
	return ok


func _verify_synthetic_pending_menu_guards(app: Control) -> void:
	# This models only the host's pending-acknowledgment state. It does not run
	# the Web adapter or claim that a real browser transaction has completed.
	var first_check := checks
	var service: SaveService = app.get("save_service")
	_progress("synthetic_guard_before_worker_drain")
	_check(service.wait_for_async_save() == OK, "synthetic pending guard could not drain earlier native write")
	_progress("synthetic_guard_after_worker_drain")
	app.call("open_run_menu")
	_progress("synthetic_guard_menu_opened")
	_check(bool(app.get("run_menu_overlay").visible), "synthetic pending guard requires an actual visible menu")
	var controls: Array = app.get("run_menu_action_controls")
	_check(controls.size() == 9, "synthetic pending guard did not find all nine menu controls")
	var disabled_before: Array = []
	for control in controls:
		disabled_before.append(bool(control.disabled))
	var run: RunState = app.get("run_state")
	var slot := str(app.get("autosave_slot_id"))
	var before := _snapshot(run)
	var saved_path := service.run_save_path(slot)
	var saved_sha := FileAccess.get_sha256(saved_path)
	_progress("synthetic_guard_baseline_hashed")
	_check(not saved_sha.is_empty(), "synthetic pending guard requires an existing baseline save")
	app.set("_web_manual_save_pending", true)
	app.call("_refresh_run_menu")
	_progress("synthetic_guard_busy_controls_refreshed")
	var all_disabled := true
	for control in controls:
		all_disabled = all_disabled and bool(control.disabled)
	_check(all_disabled, "synthetic pending guard left a menu control enabled")
	for action in ["close_run_menu", "load_run_from_menu", "abandon_run_from_menu", "return_to_main_menu", "save_run_from_menu"]:
		_progress("synthetic_guard_before_" + action)
		app.call(action)
		_progress("synthetic_guard_after_" + action)
		_check(bool(app.get("run_menu_overlay").visible) and bool(app.get("_web_manual_save_pending")), "synthetic pending guard allowed " + action)
		_check(app.get("run_state") == run and str(app.get("autosave_slot_id")) == slot \
				and _snapshot(app.get("run_state")) == before and FileAccess.get_sha256(saved_path) == saved_sha,
				"synthetic pending guard mutated run/slot/protected state/saved bytes via " + action)
	app.set("_web_manual_save_pending", false)
	app.call("_refresh_run_menu")
	_progress("synthetic_guard_normal_controls_restored")
	var disabled_after: Array = []
	for control in controls:
		disabled_after.append(bool(control.disabled))
	_check(disabled_after == disabled_before and bool(app.get("run_menu_overlay").visible), "synthetic pending guard did not restore normal menu controls")
	fixture_facts["synthetic_pending_menu_guard"] = {
		"scope": "Native synthetic pending flag; not real Web persistence evidence",
		"checks": checks - first_check, "controls": controls.size(), "baseline_sha256": saved_sha,
	}


func _run() -> void:
	_progress("run_start")
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	_progress("host_added")
	for _frame in range(4):
		await process_frame
	_progress("host_initial_frames_complete")
	app.get("user_settings").coach_tips_enabled = false
	if OS.get_cmdline_user_args().has("--cold"):
		var expected_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(_expected_path()))
		if not _check(typeof(expected_value) == TYPE_DICTIONARY and not (expected_value as Dictionary).is_empty(), "cold check requires retained warm receipt"):
			await _finish(app)
			return
		var receipt: Dictionary = expected_value
		# Earlier generic receipts stored one direct snapshot. New runs retain
		# each actual Save boundary separately because navigation can advance time.
		var by_slot: Dictionary = receipt.get("by_slot", {})
		for slot in [SLOT, FLOOR_SLOT]:
			var expected: Dictionary = by_slot.get(slot, {}) if receipt.has("by_slot") else receipt
			if not _check(not expected.is_empty(), slot + " is missing its warm Save receipt"):
				continue
			_verify_slot(slot, expected)
			app.set("autosave_slot_id", slot)
			if not _check(bool(app.call("load_foundation_run")), slot + " cold Continue failed"):
				continue
			_check(_snapshot(app.get("run_state")) == expected, slot + " cold host changed saved state")
			if _check(bool(app.call("enter_game", "pull_tabs")), slot + " cold machine entry failed"):
				var entered := _snapshot(app.get("run_state"))
				_check_navigation_state(entered, expected, slot + " cold re-entry")
				app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
				_check(_snapshot(app.get("run_state")) == entered, slot + " repeat Collect changed state")
		await _finish(app)
		return
	# Initialize only an independently generated fixture; no original campaign is
	# loaded and no purchased ticket or result is constructed by this check.
	if not _check(not app.get("save_service").has_run(SLOT), "warm producer requires a fresh isolated save namespace"):
		await _finish(app)
		return
	var fixture_options: Dictionary = {}
	var seed := SEED
	if OS.get_cmdline_user_args().has("--audit"):
		seed = AUDIT_SEED
		fixture_options = {"scenario_id": AUDIT_SCENARIO, "clock_minutes": 3120}
	_progress("fixture_create_begin")
	var setup: Dictionary = Fixture.create(app, seed, fixture_options)
	_progress("fixture_create_complete")
	fixture_facts = setup.get("facts", {})
	if OS.get_cmdline_user_args().has("--elapsed"):
		fixture_facts["elapsed_clock_mode"] = true
	if not _check(bool(setup.get("ok", false)), "independent Grand setup: " + JSON.stringify(setup.get("errors", []))):
		await _finish(app)
		return
	var generated: RunState = setup.get("run")
	var initial := _snapshot(generated)
	_progress("baseline_save_begin")
	if not _check(app.get("save_service").save_run(generated, SLOT) == OK, "official independent baseline Save failed"):
		await _finish(app)
		return
	_progress("baseline_save_complete")
	if not _check(bool(app.call("load_foundation_run")), "normal baseline Continue failed"):
		await _finish(app)
		return
	_progress("baseline_continue_complete")
	var run: RunState = app.get("run_state")
	_check(_snapshot(run) == initial, "baseline Continue changed independent wallet/card/bag/stock/exactRNG")
	if OS.get_cmdline_user_args().has("--prepare"):
		# Export only this freshly generated pre-purchase state and its own fresh
		# companions for first-boot Web preloading. No ticket has been purchased.
		_check(app.get("meta_collection_service").save() == OK, "independent preparation meta Save failed")
		_check(app.get("user_settings").save() == OK, "independent preparation settings Save failed")
		fixture_facts["mode"] = "prepare_only_no_ticket_purchase"
		fixture_facts["baseline_save"] = ProjectSettings.globalize_path(app.get("save_service").run_save_path(SLOT))
		fixture_facts["own_authority_companion"] = ProjectSettings.globalize_path("user://.crew_host_authority_v1")
		await _finish(app)
		return
	if not _check(bool(app.call("enter_game", "pull_tabs")), "normal independent Grand Pull Tabs entry failed"):
		await _finish(app)
		return
	_progress("machine_entered")
	var row := int(fixture_facts.get("two_dollar_deal_index", -1))
	app.call("_on_game_surface_action", "pull_tab_buy", row, false)
	for _frame in range(6):
		await process_frame
	_progress("purchase_frames_complete")
	if not _check(run.bankroll == 94 and run.grand_casino_chips == 13 and _pile(run).get("tray_stack", []).size() == 1, "one normal $2 purchase must debit only15->13chips"):
		await _finish(app)
		return
	var purchased := _snapshot(run)
	fixture_facts["purchased_ticket"] = _pile(run).get("tray_stack", [])[0].duplicate(true)
	app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
	if not _check(_pile(run).get("ticket_stack", []).size() == 1 and _pile(run).get("tray_stack", []).is_empty(), "warm Grand collection failed"):
		await _finish(app)
		return
	var expected := _snapshot(run)
	var protected_keys: Array = ["cash", "chips", "rng", "heat", "tickets_sold", "deals", "inventory", "card_float_bits", "pending_bags", "challenge_modifiers"]
	if OS.get_cmdline_user_args().has("--audit"):
		protected_keys.append("scenario_id")
	if OS.get_cmdline_user_args().has("--audit") or OS.get_cmdline_user_args().has("--elapsed"):
		protected_keys.append("clock_minutes")
	for key in protected_keys:
		_check(expected[key] == purchased[key], "Collect changed protected " + key)
	if OS.get_cmdline_user_args().has("--elapsed"):
		if not _advance_elapsed_clock(run, "machine_before_save"):
			await _finish(app)
			return
		expected = _snapshot(run)
	_progress("collection_invariants_complete")
	_verify_synthetic_pending_menu_guards(app)
	_progress("synthetic_guard_complete")
	app.call("open_run_menu")
	_progress("machine_save_begin")
	app.call("save_run_from_menu")
	_progress("machine_save_returned")
	_check(not bool(app.get("run_menu_overlay").visible), "Grand machine Menu Save not accepted")
	_verify_slot(SLOT, expected)
	if _check(bool(app.call("load_foundation_run")), "Grand warm Continue failed"):
		_check(_snapshot(app.get("run_state")) == expected, "Grand warm Continue changed ticket/stock/wallet/Heat/exactRNG/card/bag")
		if _check(bool(app.call("enter_game", "pull_tabs")), "Grand warm machine re-entry failed"):
			var entered := _snapshot(app.get("run_state"))
			_check_navigation_state(entered, expected, "Grand warm re-entry")
			app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
			_check(_snapshot(app.get("run_state")) == entered, "Grand repeat Collect changed state")
	app.call("back_to_environment")
	app.set("autosave_slot_id", FLOOR_SLOT)
	var floor_run: RunState = app.get("run_state")
	_check_navigation_state(_snapshot(floor_run), expected, "Grand floor return")
	if OS.get_cmdline_user_args().has("--elapsed"):
		if not _advance_elapsed_clock(floor_run, "floor_before_save"):
			await _finish(app)
			return
	var floor_expected := _snapshot(floor_run)
	app.call("open_run_menu")
	_progress("floor_save_begin")
	app.call("save_run_from_menu")
	_progress("floor_save_returned")
	_check(not bool(app.get("run_menu_overlay").visible), "Grand floor Menu Save not accepted")
	_verify_slot(FLOOR_SLOT, floor_expected)
	var file := FileAccess.open(_expected_path(), FileAccess.WRITE)
	_check(file != null, "Grand expected receipt write failed")
	if file != null:
		file.store_string(JSON.stringify({"by_slot": {SLOT: expected, FLOOR_SLOT: floor_expected}}))
		file.close()
	await _finish(app)


func _finish(app: Control) -> void:
	_progress("finish_before_worker_drain")
	app.get("save_service").wait_for_async_save()
	_progress("finish_after_worker_drain")
	app.queue_free()
	for _frame in range(8):
		await process_frame
	completed = true
	print("PULL_TAB_GRAND_SAVE cold=", OS.get_cmdline_user_args().has("--cold"), " checks=", checks, " failures=", JSON.stringify(failures), " fixture=", JSON.stringify(fixture_facts))
	quit(0 if failures.is_empty() else 1)


func _finalize() -> void:
	if not completed:
		push_error("Independent Grand save check exited before completing")
