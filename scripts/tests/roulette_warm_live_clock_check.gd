extends SceneTree

# BTH061-ROULETTE-WARM-REVEAL-001. A fresh, explicitly staged independent B
# fixture, not normal travel or the original R08 campaign. MainScene, clocks,
# processing, pauses, authority, outcomes and autonomous redraw stay production.
# After the single paid Roulette Confirm, observation reads retained scalars only.
const MainScene := preload("res://scenes/main.tscn")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const SEED := "BTH061-ROULETTE-SEALED-PENDING-001-B"
const STAKE := 9
const SLOT := "foundation_ui_autosave"
const OBSERVATION_LIMIT_MSEC := 65000
const REVEAL_BOUND_MSEC := 9000

var private_root := ""
var checks := 0
var failures: Array[String] = []
var completed := false
var callbacks := {"deal": 0, "stand": 0, "wait": 0, "leave": 0, "chip": 0, "red": 0, "spin": 0, "confirm": 0}
var facts: Dictionary = {"seed": SEED, "original_state_used": false, "practice_used": false, "outcome_selection": false, "snapshots": [], "new_story_rows": []}
var story_cursor := 0
var paid_story_index := -1
var paid_spin_id := "" # Compared locally; never included in output.
var paid_spin_count := 0
var paid_request_count := 0
var before_confirm_rng := 0 # Compared locally; never included in output.
var before_confirm_host_msec := 0
var confirm_return_msec := 0


func _initialize() -> void:
	private_root = OS.get_environment("BTH_R08_ROULETTE_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not _private_paths():
		_finish()
		return
	call_deferred("_run")


func _inside(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	return not private_root.is_empty() and (normalized == private_root.to_lower() or normalized.begins_with(private_root.to_lower() + "/"))


func _private_paths() -> bool:
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root and not OS.has_feature("web"), "Explicit disposable native BTH_R08_ROULETTE_PRIVATE_ROOT required"):
		return false
	if not _check(_inside(ProjectSettings.globalize_path("user://")), "Actual user directory is private before host initialization"):
		return false
	for key in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path := OS.get_environment(key)
		if not _check(not path.is_empty() and _inside(ProjectSettings.globalize_path(path)), "Private incoming persistence containment: " + str(key)):
			return false
	for key in ["BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"]:
		var path := OS.get_environment(key)
		if not _check(path.is_empty() or _inside(ProjectSettings.globalize_path(path)), "Private optional placement containment: " + str(key)):
			return false
	return _check(OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").is_empty() and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "Shipped placement and no captured save or browser fixture inputs")


func _run() -> void:
	_phase_boundaries()
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	if await _prepare(app):
		if await _blackjack_wait_and_leave(app):
			await _roulette(app)
	await _close(app)
	completed = true
	_finish()


func _prepare(app: Control) -> bool:
	var service: SaveService = app.get("save_service")
	if not _check(service != null and _inside(ProjectSettings.globalize_path(service.run_save_path(SLOT))), "Actual production Continue slot remains inside the private root"):
		return false
	if not _check(not FileAccess.file_exists(service.run_save_path(SLOT)), "Fresh independent fixture requires an unused production Continue slot"):
		return false
	app.set("autosave_slot_id", SLOT)
	app.get("user_settings").coach_tips_enabled = false
	app.call("_ensure_full_content_library_loaded")
	if not _check(bool(app.call("_ensure_run_ui_built")), "Actual run interface builds"):
		return false
	var library: ContentLibrary = app.get("library")
	var run := RunState.new()
	run.start_new(SEED)
	run.begin_act(1)
	run.bankroll = 80
	run.grand_casino_chips = 0
	var archetype: Dictionary = library.environment_archetype("delta_queen").duplicate(true)
	if not _check(not archetype.is_empty(), "Shipped Riverboat archetype is available"):
		return false
	# Predeclared inputs only, before any generation; retain all three shipped games.
	var economy: Dictionary = archetype.get("economic_profile", {}).duplicate(true)
	economy["stake_floor"] = STAKE
	economy["stake_ceiling"] = 100
	economy["game_stake_floor_overrides"] = {"roulette": STAKE, "blackjack": STAKE}
	economy["game_stake_ceiling_overrides"] = {"roulette": 100}
	archetype["economic_profile"] = economy
	var generator := RunGenerator.new(library)
	var generation_rng := run.create_rng("r08_roulette_independent_fixture")
	var environment: Dictionary = EnvironmentInstance.from_archetype(archetype, 0, generation_rng, library, run.challenge_config).to_dict()
	environment["game_states"] = generator._generated_game_states(run, environment, generation_rng)
	for key in ["object_manifest", "object_manifest_digest", "object_manifest_revision"]:
		environment.erase(key)
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment, library)
	var installed: Dictionary = generator._install_environment(run, environment)
	if not _check(bool(installed.get("ok", false)), "Source-equivalent generated environment installation succeeds"):
		return false
	app.set("run_state", run)
	app.set("generator", generator)
	app.call("_bind_run_state_presentation_signals")
	app.call("_configure_coach_for_run")
	app.call("_refresh_run_action_service")
	app.call("_sync_presented_bankroll_to_actual")
	app.call("_queue_room_publication_check")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	if not (await _published(app)):
		return false
	var game_ids: Array = run.current_environment.get("game_ids", [])
	if not _check(game_ids.size() == 3 and game_ids.has("blackjack") and game_ids.has("roulette") and game_ids.has("video_poker") and not run.is_tutorial_run() and not bool(app.get("dev_game_test_mode")) and not bool(app.get("dev_environment_test_mode")) and not bool(app.call("_is_environment_test_session")), "Fixture retains shipped three-game set and ordinary cash authority without Practice"):
		return false
	var before_rng := run.rng_state
	var before_clock := run.game_clock_minutes
	if not _check(service.save_run(run, SLOT) == OK, "Official synchronous Save persists the prepaid fixture"):
		return false
	if not _check(int(app.get("meta_collection_service").save()) == OK and int(app.get("user_settings").save()) == OK and int(app.get("profile_inventory").save()) == OK, "Official companion services persist only the new private fixture"):
		return false
	if not _check(bool(app.call("load_foundation_run")), "Normal official Continue accepts the prepaid fixture"):
		return false
	var loaded: RunState = app.get("run_state") # Continue installs a new RunState.
	var table := _table(loaded)
	var proof := loaded.validate_room_action_authority()
	if not _check(loaded != run and loaded.seed_text == SEED and loaded.bankroll == 80 and loaded.grand_casino_chips == 0 and loaded.rng_state == before_rng and loaded.game_clock_minutes == before_clock and int(table.get("spin_count", -1)) == 0 and int(table.get("rules", {}).get("outside_min_each", -1)) == STAKE and _pending_total(loaded) == 0 and not _pending(loaded) and bool(proof.get("ok", false)), "Continue preserves new B fixture cash80/min9/spin0, RNG, clock and room authority"):
		return false
	facts["preparation"] = {"official_save_continue": true, "new_run_reference": loaded != run, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "clock": loaded.game_clock_minutes, "rng_unchanged": loaded.rng_state == before_rng, "room_authority_valid": bool(proof.get("ok", false)), "generated_table_name": str(table.get("table_name", ""))}
	return _check(bool(app.get("continuous_environment_clock_enabled")) and app.is_processing(), "Production continuous clock and host processing remain enabled")


func _published(app: Control) -> bool:
	for _frame in range(12):
		await process_frame
		if int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")):
			break
	var run: RunState = app.get("run_state")
	return _check(bool(run.validate_room_action_authority().get("ok", false)) and int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")), "Normal room publication has current action authority")


func _blackjack_wait_and_leave(app: Control) -> bool:
	if not _check(bool(app.call("enter_game", "blackjack")) and str(app.get("current_game_state_key")) == "blackjack" and bool(app.call("set_selected_stake", STAKE)), "Normal Blackjack entry and nine-unit selector succeed"):
		return false
	var run: RunState = app.get("run_state")
	var before_cash := run.bankroll
	callbacks["deal"] = 1
	app.call("_on_game_surface_action", "blackjack_deal", 0, false)
	var opening: Dictionary = app.get("last_game_result")
	if not _check(_accepted(opening, "blackjack", "blackjack_place_bet") and (app.get("run_state") as RunState).bankroll == before_cash - STAKE, "One normal Deal commits exactly one opening debit"):
		return false
	var deadline := Time.get_ticks_msec() + 20000
	var settled := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		run = app.get("run_state")
		var table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
		var ledger: Dictionary = table.get(Authority.LEDGER_KEY, {})
		var result: Dictionary = app.get("last_game_result")
		if not _check(bool(result.get("ok", false)) and (ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "Prior hand retains accepted state without stranded pending"):
			return false
		if int(table.get("hands_played", 0)) == 1 and not bool(app.get("deferred_embedded_refresh_pending")):
			settled = true
			break
		var canvas: Control = app.get("game_surface_canvas")
		var surface: Dictionary = canvas.call("realtime_surface_state")
		if int(callbacks.stand) == 0 and not bool(app.get("deferred_embedded_refresh_pending")) and bool(surface.get("can_stand", false)) and not bool(canvas.call("surface_animation_active", "blackjack_deal")) and not bool(app.call("_modal_contract_blocks_player_input")):
			var game: GameModule = app.get("current_game")
			var complete_before := bool(game.call("_all_hands_complete", ledger.get("session", {})))
			var prior_action := str(result.get("action_id", ""))
			callbacks["stand"] = 1
			app.call("_on_game_surface_action", "blackjack_stand", 0, false)
			run = app.get("run_state")
			var after: Dictionary = app.get("last_game_result")
			var after_ledger: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {}).get(Authority.LEDGER_KEY, {})
			var phase_progressed := not complete_before and bool(game.call("_all_hands_complete", after_ledger.get("session", {})))
			var fresh_result := bool(after.get("ok", false)) and bool(after.get(Authority.HOST_COMMITTED_KEY, false)) and str(after.get("action_id", "")) != prior_action
			if not _check(bool(after.get("ok", false)) and (after_ledger.get("pending_delivery", {}) as Dictionary).is_empty() and (fresh_result or phase_progressed), "Single native-ready Stand makes accepted hand progression without another Deal"):
				return false
		await create_timer(0.05).timeout
	if not _check(settled, "One natural Blackjack hand settles within the native readiness bound"):
		facts["fixture_limit"] = "Prior hand did not settle; no repeated Deal/Stand or Roulette input"
		return false
	run = app.get("run_state")
	facts["blackjack"] = {"cash": run.bankroll, "chips": run.grand_casino_chips, "clock": run.game_clock_minutes, "hands_played": run.current_environment.get("game_states", {}).get("blackjack", {}).get("hands_played", 0), "deal_dispatches": callbacks.deal, "stand_dispatches": callbacks.stand}
	# Only the naturally visible known Wait is eligible; never enqueue a scenario.
	var popup: Dictionary = app.get("pending_event_choice_popup_snapshot")
	var popup_visible := bool(app.call("_event_choice_popup_is_visible"))
	var known_wait_visible := popup_visible and str(popup.get("event_id", "")) == "machine_jam" and _has_wait_choice(popup)
	facts["natural_wait_visible"] = known_wait_visible
	if known_wait_visible:
		var wait_cash := run.bankroll
		var wait_rng := run.rng_state
		var wait_rows := _wait_count(run)
		callbacks["wait"] = 1
		if not _check(bool(app.call("_activate_event_response_action", "event_response:machine_jam:wait")), "One naturally visible Machine Jam Wait callback is accepted"):
			return false
		var wait_deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < wait_deadline:
			await process_frame
			if (app.get("_event_response_transaction") as Dictionary).is_empty() and not bool(app.get("event_choice_resolution_pending")):
				break
		run = app.get("run_state")
		facts["wait"] = {"cash_before": wait_cash, "cash_after": run.bankroll, "cash_delta": run.bankroll - wait_cash, "rng_unchanged": run.rng_state == wait_rng, "new_wait_rows": _wait_count(run) - wait_rows, "transaction_done": (app.get("_event_response_transaction") as Dictionary).is_empty(), "response_pending": bool(app.get("event_choice_resolution_pending"))}
		if not _check((app.get("_event_response_transaction") as Dictionary).is_empty() and not bool(app.get("event_choice_resolution_pending")) and _wait_count(run) == wait_rows + 1, "Single ordinary Wait finishes through normal frames and records one event row"):
			return false
	if not _check(not bool(app.call("_modal_contract_blocks_player_input")), "No unresolved modal blocks normal Leave; no other choice is made"):
		facts["fixture_limit"] = "Unresolved natural modal before Leave"
		return false
	run = app.get("run_state")
	var leave_cash := run.bankroll
	var leave_rng := run.rng_state
	callbacks["leave"] = 1
	app.call("_on_game_surface_action", "surface_back", 0, false)
	run = app.get("run_state")
	if not _check(str(app.get("current_screen")) == "ENVIRONMENT" and app.get("current_game") == null and run.bankroll == leave_cash and run.rng_state == leave_rng, "Normal Leave preserves settled wallet/RNG and returns to the floor"):
		return false
	if not (await _published(app)):
		return false
	return _check(not bool(app.get("presented_bankroll_hold_active")) and run.bankroll >= STAKE, "Floor has actual affordable cash and no previous presentation hold")


func _has_wait_choice(popup: Dictionary) -> bool:
	for value in popup.get("choices", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == "wait" and bool((value as Dictionary).get("enabled", true)) and not bool((value as Dictionary).get("disabled", false)):
			return true
	return false


func _wait_count(run: RunState) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY:
			var row: Dictionary = value
			if str(row.get("event_id", "")) == "machine_jam" and str(row.get("choice_id", "")) == "wait":
				count += 1
	return count


func _roulette(app: Control) -> void:
	if not _check(bool(app.call("enter_game", "roulette")) and str(app.get("current_game_state_key")) == "roulette" and str((app.get("current_game") as GameModule).get_id()) == "roulette", "Normal Roulette entry binds the real module/state key"):
		return
	var run: RunState = app.get("run_state")
	var table := _table(run)
	var denoms: Array = table.get("chip_denominations", [])
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var rendered_denoms: Array = surface.get("chip_denominations", [])
	var canonical_types: Array = []
	var rendered_types: Array = []
	var canonical_has_nine_by_int := false
	for value in denoms:
		canonical_types.append(type_string(typeof(value)))
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and int(value) == STAKE:
			canonical_has_nine_by_int = true
	for value in rendered_denoms:
		rendered_types.append(type_string(typeof(value)))
	facts["roulette_setup"] = {
		"spin_count": int(table.get("spin_count", -1)), "canonical_denominations": denoms.duplicate(true), "canonical_denom_types": canonical_types,
		"canonical_has_int_nine": denoms.has(STAKE), "canonical_has_nine_by_int_conversion": canonical_has_nine_by_int, "rendered_denominations": rendered_denoms.duplicate(true), "rendered_denom_types": rendered_types, "rendered_has_int_nine": rendered_denoms.has(STAKE),
		"outside_minimum": int(table.get("rules", {}).get("outside_min_each", -1)), "cash": run.bankroll, "chips": run.grand_casino_chips, "uses_chips": run.grand_casino_game_uses_chips("roulette", run.current_environment), "pending_delivery": _pending(run),
		"binding": {"screen": str(app.get("current_screen")), "module_id": (app.get("current_game") as GameModule).get_id(), "state_binding": str(app.get("current_game_state_key")), "active_game_id": str(run.current_environment.get("active_game_id", "")), "environment_id": str(run.current_environment.get("id", "")), "rendered_game_id": str(surface.get("game_id", ""))},
	}
	# The rendered rail and native callback both use Roulette's int-normalized,
	# sorted denominations. Raw JSON-loaded values remain observation only.
	if not _check(int(table.get("spin_count", -1)) == 0 and rendered_denoms.has(STAKE) and int(table.get("rules", {}).get("outside_min_each", -1)) == STAKE and not run.grand_casino_game_uses_chips("roulette", run.current_environment) and not _pending(run), "Unplayed generated cash table retains rendered min9 and no pending delivery"):
		return
	var targets: Array = surface.get("bet_targets", [])
	var red := -1
	for index in range(targets.size()):
		if str((targets[index] as Dictionary).get("type", "")) == "red":
			red = index
	if not _check(red >= 0 and app.is_processing() and canvas.is_processing() and canvas.is_visible_in_tree() and not paused, "Actual RED target and live native host/canvas are available"):
		return
	var cash_before := run.bankroll
	callbacks["chip"] = 1
	app.call("_on_game_surface_action", "roulette_chip", rendered_denoms.find(STAKE), false)
	await create_timer(0.4).timeout
	callbacks["red"] = 1
	app.call("_on_game_surface_action", "roulette_bet", red, false)
	run = app.get("run_state")
	if not _check(_pending_total(run) == STAKE and run.bankroll == cash_before, "One normal RED stages nine units without a debit"):
		return
	await create_timer(0.4).timeout
	callbacks["spin"] = 1
	app.call("_on_game_surface_action", "roulette_spin", 0, false)
	run = app.get("run_state")
	if not _check(bool(_session(run).get("roulette_spin_armed", false)) and not _pending(run) and run.bankroll == cash_before, "One normal SPIN arms without settlement"):
		return
	await create_timer(1.0).timeout
	run = app.get("run_state")
	before_confirm_rng = run.rng_state
	story_cursor = run.story_log_archive_count + run.story_log.size()
	before_confirm_host_msec = int(app.call("_environment_simulation_time_msec"))
	facts["snapshots"].append(_snapshot(app, "before-confirm"))
	callbacks["confirm"] = 1
	app.call("_on_game_surface_action", "roulette_spin", 0, false)
	confirm_return_msec = Time.get_ticks_msec()
	run = app.get("run_state")
	table = _table(run)
	paid_spin_id = str((table.get("last_result", {}) as Dictionary).get("spin_id", ""))
	paid_spin_count = int(table.get("spin_count", 0))
	paid_request_count = _requests(run)
	# Capture the first retained projection before yielding or asking for a rebuild.
	facts["snapshots"].append(_snapshot(app, "confirm-immediate"))
	_record_new_story(app)
	var result: Dictionary = app.get("last_game_result")
	if not _check(_accepted(result, "roulette", "spin_roulette") and not _pending(run) and paid_spin_count == 1 and paid_request_count == 1 and _pending_total(run) == 0, "One native Confirm commits one paid spin/request without pending delivery"):
		return
	if not _check(paid_story_index >= 0 and run.bankroll == cash_before + int(result.get("bankroll_delta", result.get("deltas", {}).get("bankroll_delta", 0))), "Paid natural result has one story row and conserves actual cash"):
		return
	facts["cash_before_roulette"] = cash_before
	await _observe(app)


func _observe(app: Control) -> void:
	var next_sample := 0
	var sample_times := [4000, 12000, 20000]
	var last_transition := _transition(app)
	var stalled := false
	var revealed := false
	var zero_after_paid := false
	var last_elapsed := 0
	var stop_reason := "bounded-observation-limit"
	while Time.get_ticks_msec() - confirm_return_msec < OBSERVATION_LIMIT_MSEC:
		# Timers/frames progress normally; no snapshot builder, clock setter,
		# advance, refresh, save, menu, navigation or further gameplay input here.
		await create_timer(0.05).timeout
		var elapsed := Time.get_ticks_msec() - confirm_return_msec
		last_elapsed = elapsed
		var new_zero := _record_new_story(app)
		var transition := _transition(app)
		var label := ""
		if next_sample < sample_times.size() and elapsed >= int(sample_times[next_sample]):
			label = "after-%d-ms" % int(sample_times[next_sample])
			next_sample += 1
		if transition != last_transition:
			label = label + "+state-change" if not label.is_empty() else "state-change"
			last_transition = transition
		if not label.is_empty():
			facts["snapshots"].append(_snapshot(app, label))
		var run: RunState = app.get("run_state")
		var canvas: Control = app.get("game_surface_canvas")
		var surface: Dictionary = canvas.call("realtime_surface_state")
		var result: Dictionary = app.get("last_game_result")
		zero_after_paid = zero_after_paid or new_zero
		if not bool(result.get("ok", false)) or _pending(run):
			stop_reason = "first-new-rejection-or-pending"
			facts["snapshots"].append(_snapshot(app, stop_reason))
			_check(false, "First new rejected result or pending delivery stops passive observation without another input")
			break
		if bool(app.call("_modal_contract_blocks_player_input")):
			stop_reason = "first-new-blocking-modal"
			facts["snapshots"].append(_snapshot(app, stop_reason))
			facts["fixture_limit"] = "A new natural blocking modal ended the unobscured observation; no response or further gameplay input"
			_check(false, "First new blocking modal stops passive observation without a choice")
			break
		var active_elapsed := int(app.call("_environment_simulation_time_msec")) - before_confirm_host_msec
		var paid_is_current := str((_table(run).get("last_result", {}) as Dictionary).get("spin_id", "")) == paid_spin_id
		var visible_paid := _contains_spin(surface.get("last_results", []), paid_spin_id)
		var hud: Dictionary = app.get("structured_hud").current_snapshot()
		var current_revealed := not bool(app.get("presented_bankroll_hold_active")) and not bool(surface.get("money_presentation_pending", true)) and visible_paid and int(surface.get("bankroll", -1)) == run.bankroll and str(hud.get("wallet", "")) == "$%d" % run.bankroll
		revealed = revealed or current_revealed
		# A half-second grace avoids classifying a boundary between host and timer
		# callbacks as a persistent failure. Measure active host time from Confirm,
		# not the possibly future result timestamp under investigation.
		if not stalled and paid_is_current and active_elapsed >= REVEAL_BOUND_MSEC + 500 and not current_revealed:
			stalled = true
			facts["snapshots"].append(_snapshot(app, "reveal-stall-beyond-active-bound"))
			_check(false, "Paid wallet/history remain withheld beyond nine active host seconds plus one boundary grace; continue read-only observation")
		if new_zero:
			stop_reason = "first-postpaid-zero-spin"
			facts["snapshots"].append(_snapshot(app, "first-postpaid-zero-spin-stop"))
			break
	facts["snapshots"].append(_snapshot(app, "observation-finished"))
	facts["observation"] = {"wall_elapsed_msec": last_elapsed, "bounded_limit_msec": OBSERVATION_LIMIT_MSEC, "stop_reason": stop_reason, "reveal_stall_observed": stalled, "paid_reveal_observed": revealed, "first_postpaid_zero_spin_observed": zero_after_paid, "explicit_callbacks": callbacks.duplicate(true)}
	_check(revealed, "Paid wallet and history reveal through normal live processing without menu refresh")
	var final_clocks := _clocks(app)
	var first: Dictionary = facts.snapshots[0].get("clocks", {})
	_check(int(final_clocks.get("process_frame", 0)) > int(first.get("process_frame", 0)) and int(final_clocks.get("host_simulation_msec", 0)) > int(first.get("host_simulation_msec", 0)) and int(final_clocks.get("canvas_simulation_msec", 0)) > int(first.get("canvas_simulation_msec", 0)), "Native host/canvas clocks and process frames progressed without scheduling overrides")


func _record_new_story(app: Control) -> bool:
	var run: RunState = app.get("run_state")
	var zero_after_paid := false
	var base := run.story_log_archive_count
	for local_index in range(maxi(0, story_cursor - base), run.story_log.size()):
		var value: Variant = run.story_log[local_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var index := base + local_index
		var safe: Dictionary = {"index": index, "explicit_confirm_callbacks": callbacks.confirm, "spin_count": int(_table(run).get("spin_count", 0)), "request_count": _requests(run), "spin_delta_from_paid": int(_table(run).get("spin_count", 0)) - paid_spin_count, "request_delta_from_paid": _requests(run) - paid_request_count}
		# Preserve key absence rather than defaulting an incomplete row into a sitout.
		for key in ["type", "game_id", "action_id", "stake", "total_wager", "sat_out", "bankroll_delta", "currency_delta"]:
			if row.has(key):
				safe[key] = row[key]
		facts["new_story_rows"].append(safe)
		var roulette_spin := str(row.get("game_id", "")) == "roulette" and str(row.get("action_id", "")) == "spin_roulette"
		if roulette_spin and row.has("stake") and int(row.stake) == STAKE and paid_story_index < 0:
			paid_story_index = index
		var explicit_zero := roulette_spin and row.has("stake") and row.has("total_wager") and row.has("sat_out") and row.has("bankroll_delta") and int(row.stake) == 0 and int(row.total_wager) == 0 and bool(row.sat_out) and int(row.bankroll_delta) == 0
		if explicit_zero and index > paid_story_index and paid_story_index >= 0 and int(callbacks.confirm) == 1 and int(_table(run).get("spin_count", 0)) > paid_spin_count and _requests(run) > paid_request_count:
			zero_after_paid = true
	story_cursor = base + run.story_log.size()
	return zero_after_paid


func _snapshot(app: Control, label: String) -> Dictionary:
	var run: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var retained_ui: Dictionary = app.get("game_surface_ui_state")
	var table := _table(run)
	var last: Dictionary = table.get("last_result", {})
	var result: Dictionary = app.get("last_game_result")
	var ledger: Dictionary = table.get(Authority.LEDGER_KEY, {})
	var timer: Dictionary = surface.get("table_round_timer", {})
	var hud: Dictionary = app.get("structured_hud").current_snapshot()
	var clocks := _clocks(app)
	var popup: Dictionary = app.get("pending_event_choice_popup_snapshot")
	var resolved := int(last.get("resolved_at_msec", -1))
	var raw := int(surface.get("surface_time_msec", -1))
	return {
		"label": label, "wall_msec": Time.get_ticks_msec(), "wall_since_confirm_return_msec": Time.get_ticks_msec() - confirm_return_msec if confirm_return_msec > 0 else -1,
		"clocks": clocks, "input_minus_host_msec": int(clocks.input_time_msec) - int(clocks.host_simulation_msec), "host_since_preconfirm_msec": int(clocks.host_simulation_msec) - before_confirm_host_msec,
		"retained_ui": {"raw_msec": retained_ui.get("surface_time_msec", -1), "presentation_msec": retained_ui.get("surface_presentation_time_msec", -1), "drunk_scaled_msec": retained_ui.get("drunk_scaled_surface_time_msec", -1)},
		"result": {"ok": bool(result.get("ok", false)), "game_id": str(result.get("game_id", "")), "action_id": str(result.get("action_id", "")), "committed": bool(result.get(Authority.HOST_COMMITTED_KEY, false)), "error_code": str(result.get("error_code", "")), "has_apply_receipt": not (result.get(Authority.HOST_APPLY_RECEIPT_KEY, {}) as Dictionary).is_empty()},
		"canonical": {"spin_count": int(table.get("spin_count", 0)), "resolved_at_msec": resolved, "has_last_spin": not str(last.get("spin_id", "")).is_empty(), "last_spin_is_paid": not paid_spin_id.is_empty() and str(last.get("spin_id", "")) == paid_spin_id, "history_count": (table.get("last_results", []) as Array).size(), "history_contains_paid": _contains_spin(table.get("last_results", []), paid_spin_id), "timer_started_msec": int(table.get("table_round_timer_started_msec", 0)), "request_count": _requests(run), "pending": not (ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "pending_stake": int((ledger.get("pending_delivery", {}) as Dictionary).get("stake", -1)), "draft_wager": _pending_total(run)},
		"rendered": {"raw_minus_resolved_msec": raw - resolved if resolved >= 0 else 0, "spin_elapsed_msec": int(surface.get("spin_elapsed_msec", -1)), "phase": str(surface.get("phase", "")), "money_pending": bool(surface.get("money_presentation_pending", false)), "settled": bool(surface.get("roulette_result_settled", false)), "realtime_refresh": bool(surface.get("surface_realtime_state_refresh", false)), "motion_active": bool(surface.get("roulette_motion_active", false)), "history_count": (surface.get("last_results", []) as Array).size(), "recent_count": (surface.get("recent_numbers", []) as Array).size(), "history_contains_paid": _contains_spin(surface.get("last_results", []), paid_spin_id), "bankroll": int(surface.get("bankroll", -1)), "timer_active": bool(timer.get("active", false)), "timer_due": bool(timer.get("due", false)), "timer_remaining_msec": int(timer.get("remaining_msec", -1))},
		"wallet": {"actual": run.bankroll, "chips": run.grand_casino_chips, "presented": int(app.call("_presented_bankroll")), "hold": bool(app.get("presented_bankroll_hold_active")), "cash_withheld": int((app.get("presented_money_withheld") as Dictionary).get("cash", 0)), "hud_text": str(hud.get("wallet", "")), "rng_changed_since_preconfirm": run.rng_state != before_confirm_rng},
		"binding": {"screen": str(app.get("current_screen")), "game_id": (app.get("current_game") as GameModule).get_id() if app.get("current_game") != null else "", "state_binding": str(app.get("current_game_state_key")), "active_game_id": str(run.current_environment.get("active_game_id", ""))},
		"processing": {"host": app.is_processing(), "canvas": canvas.is_processing(), "canvas_visible": canvas.is_visible_in_tree(), "tree_paused": paused, "lifecycle": app.call("application_lifecycle_snapshot"), "event_transaction": not (app.get("_event_response_transaction") as Dictionary).is_empty(), "event_response_pending": bool(app.get("event_choice_resolution_pending")), "popup_visible": bool(app.call("_event_choice_popup_is_visible")), "popup_event_id": str(popup.get("event_id", "")), "deferred_pending": bool(app.get("deferred_embedded_refresh_pending")), "deferred_scheduled": int(app.get("deferred_embedded_refresh_schedule_count")), "deferred_executed": int(app.get("deferred_embedded_refresh_execution_count")), "deferred_stale": int(app.get("deferred_embedded_refresh_stale_count")), "deferred_blocked_input": int(app.get("deferred_embedded_refresh_blocked_surface_input_count"))},
		"explicit_callbacks": callbacks.duplicate(true),
	}


func _transition(app: Control) -> Dictionary:
	var run: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	return {"story_count": run.story_log_archive_count + run.story_log.size(), "spin_count": int(_table(run).get("spin_count", 0)), "requests": _requests(run), "timer_start": int(_table(run).get("table_round_timer_started_msec", 0)), "phase": str(surface.get("phase", "")), "settled": bool(surface.get("roulette_result_settled", false)), "money_pending": bool(surface.get("money_presentation_pending", false)), "realtime_refresh": bool(surface.get("surface_realtime_state_refresh", false)), "history_count": (surface.get("last_results", []) as Array).size(), "hold": bool(app.get("presented_bankroll_hold_active")), "actual_cash": run.bankroll, "rendered_cash": int(surface.get("bankroll", -1)), "event_transaction": not (app.get("_event_response_transaction") as Dictionary).is_empty(), "popup_visible": bool(app.call("_event_choice_popup_is_visible"))}


func _clocks(app: Control) -> Dictionary:
	var run: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	return {"process_frame": Engine.get_process_frames(), "run_action_simulation_msec": run.simulation_msec, "game_clock_minutes": run.game_clock_minutes, "host_simulation_msec": app.call("_environment_simulation_time_msec"), "input_time_msec": app.call("_current_game_surface_input_time_msec"), "canvas_simulation_msec": canvas.call("surface_simulation_time_msec"), "canvas_presentation_msec": canvas.call("surface_presentation_time_msec"), "rendered_raw_msec": surface.get("surface_time_msec", -1), "rendered_presentation_msec": surface.get("surface_presentation_time_msec", -1), "rendered_drunk_scaled_msec": surface.get("drunk_scaled_surface_time_msec", -1)}


func _contains_spin(values: Array, spin_id: String) -> bool:
	if spin_id.is_empty():
		return false
	for value in values:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("spin_id", "")) == spin_id:
			return true
	return false


func _accepted(result: Dictionary, game_id: String, action_id: String) -> bool:
	return bool(result.get("ok", false)) and str(result.get("game_id", "")) == game_id and str(result.get("action_id", "")) == action_id and bool(result.get(Authority.HOST_COMMITTED_KEY, false))


func _table(run: RunState) -> Dictionary:
	return run.current_environment.get("game_states", {}).get("roulette", {})


func _session(run: RunState) -> Dictionary:
	return _table(run).get(Authority.LEDGER_KEY, {}).get("session", {})


func _requests(run: RunState) -> int:
	return (_table(run).get(Authority.LEDGER_KEY, {}).get("request_order", []) as Array).size()


func _pending(run: RunState) -> bool:
	return not (_table(run).get(Authority.LEDGER_KEY, {}).get("pending_delivery", {}) as Dictionary).is_empty()


func _pending_total(run: RunState) -> int:
	var total := 0
	for value in _session(run).get("roulette_bets", []):
		total += int((value as Dictionary).get("stake", 0))
	return total


func _close(app: Control) -> void:
	var service: SaveService = app.get("save_service")
	if service != null:
		service.wait_for_async_save()
	app.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	var source_sha256 := {"test": FileAccess.get_sha256("res://scripts/tests/roulette_warm_live_clock_check.gd"), "roulette": FileAccess.get_sha256("res://scripts/games/roulette.gd"), "foundation": FileAccess.get_sha256("res://scripts/ui/foundation_main.gd"), "canvas": FileAccess.get_sha256("res://scripts/ui/game_surface_canvas.gd"), "sealed_host": FileAccess.get_sha256("res://scripts/ui/sealed_action_host.gd")}
	print("ROULETTE_WARM_LIVE_CLOCK_RESULT " + JSON.stringify({"id": "BTH061-ROULETTE-WARM-REVEAL-001", "checks": checks, "failures": failures, "completed": completed, "facts": facts, "source_sha256": source_sha256, "fidelity": "Fresh own predeclared B/shipped-three-game cash80/min9 fixture with official native Save/Continue, one natural Blackjack hand, at most one naturally visible Machine Jam Wait and normal Leave, one RED9/SPIN/CONFIRM. Live MainScene host/canvas processing and clocks; retained scalar observation only after Confirm until first postpaid zero-stake spin or65s. No original state, raw cards/shoe/RNG/keys/receipts, outcome selection, forced refresh/clock/scheduling, further financial callback, product change, Web/raster or release acceptance claim."}))
	quit(0 if completed and failures.is_empty() else 1)


func _phase_boundaries() -> void:
	var module: GameModule = load("res://scripts/games/roulette.gd").new()
	var result := {"resolved_at_msec": 100000, "spin_id": "phase-boundary-only"}
	var future: Dictionary = module.call("_roulette_phase_status_for_result", result, 99967)
	_check(int(future.get("elapsed_msec", -1)) == 0 and bool(future.get("motion_active", false)) and bool(future.get("spin_active", false)), "Input clock lead stays at reveal start with autonomous motion active")
	var empty: Dictionary = module.call("_roulette_phase_status_for_result", {}, 99967)
	_check(int(empty.get("elapsed_msec", 0)) == -1 and not bool(empty.get("motion_active", true)), "Empty result retains inactive sentinel")
	for elapsed in [0, 5599, 5600, 7399, 7400, 8999, 9000]:
		var phase: Dictionary = module.call("_roulette_phase_status_for_result", result, 100000 + elapsed)
		_check(int(phase.get("elapsed_msec", -1)) == elapsed and bool(phase.get("motion_active", false)) == (elapsed < 9000), "Existing reveal duration remains unchanged at %dms" % elapsed)
		_check(bool(phase.get("spin_active", false)) == (elapsed < 5600) and bool(phase.get("payout_active", false)) == (elapsed >= 5600 and elapsed < 7400) and bool(phase.get("result_reveal_active", false)) == (elapsed >= 7400 and elapsed < 9000), "Existing spin/payout/result phases remain unchanged at %dms" % elapsed)
	module.set("completed_presentation_spin_id", "phase-boundary-only")
	var completed_phase: Dictionary = module.call("_roulette_phase_status_for_result", result, 99967)
	_check(int(completed_phase.get("elapsed_msec", -1)) == 9000 and not bool(completed_phase.get("motion_active", true)), "Completed reentry does not replay a future-stamped reveal")
