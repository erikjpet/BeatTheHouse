extends SceneTree

# Disposable synthetic practice Host states only. The normal launcher creates
# its authored first Heritage cabinet; one manual BET2 spin uses unchanged RNG.
# This is a native Host-handler/persistence check, not Web/OS-pointer gameplay.
const Main := preload("res://scripts/ui/foundation_main.gd")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const LEGACY := {"type": "game_action", "game_id": "slot", "action_id": "spin", "bankroll_delta": -7, "environment_archetype_id": "grand_casino"}

class PracticeHost extends Main:
	var fixture_venue := "gas_station_casino"
	func _game_test_bankroll() -> int: return 134
	func _game_test_stake_floor() -> int: return 1
	func _game_test_stake_ceiling() -> int: return 20
	func _game_test_archetype() -> Dictionary:
		for value in library.environment_archetypes:
			if str(value.get("id", "")) == fixture_venue: return value.duplicate(true)
		return {}
	func _prepare_game_test_prerequisites(game_id: String, environment: Dictionary) -> void:
		super._prepare_game_test_prerequisites(game_id, environment)
		if game_id == "slot":
			run_state.grand_casino_chips = 25
			run_state.baseline_luck = 0
			run_state.story_log = [LEGACY.duplicate(true)]

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"host": [], "cold": [], "seed_selection": "canonical launcher PRACTICE-SLOT; no seed search or outcome override", "profiles_or_keys_imported": false}
var private_root := ""
var references: Array = []
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	root.size = Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		await _host("gas_station_casino")
		if not OS.get_cmdline_user_args().has("--gas-only"): await _host("grand_casino")
		var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
		if _check(file != null, "private producer reference opens"):
			file.store_string(JSON.stringify(references, "\t")); file.close()
		completed = true
	_finish()


func _host(venue: String) -> void:
	var app := PracticeHost.new()
	app.fixture_venue = venue
	app.autosave_slot_id = "slot_journal_runtime_" + venue
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await _frames(2)
	if not _check(app._ensure_run_ui_built(), venue + " normal Host builds run UI"):
		await _cleanup(app); return
	app._ensure_full_content_library_loaded()
	var opened: Dictionary = app.start_game_test_session("slot")
	if not _check(bool(opened.get("ok", false)), venue + " normal practice launcher opens Slot"):
		await _cleanup(app); return
	await _frames(2)
	var key := str(app.current_game_state_key) if not str(app.current_game_state_key).is_empty() else "slot"
	var before := State.read_machine(app.run_state.current_environment, key)
	_check(str(app.run_state.current_environment.get("archetype_id", "")) == venue, venue + " fixture is installed in requested venue")
	_check(GameModule.presentation_currency_for_game(app.run_state, "slot", app.run_state.current_environment) == "cash", venue + " actual Slot policy uses cash even with funded Grand chips")
	_check(str(before.get("format_id", "")) == "classic_3_reel" and str(before.get("type_id", "")) == "pinball", venue + " launcher binds authored first Heritage cabinet")
	_check(app.run_state.bankroll == 134 and app.run_state.grand_casino_chips == 25, venue + " fixture funding is cash134 chips25 before wager")
	var before_selection := _economy_guard(app.run_state)
	app._on_game_surface_action("slot_bet", 0, false)
	await _frames(2)
	before = State.read_machine(app.run_state.current_environment, key)
	_check(int(State.selected_bet(before).get("total_credits", 0)) == 2, venue + " normal MIN selector chooses BET2")
	_check(_economy_guard(app.run_state) == before_selection, venue + " normal BET2 selector changes no wallet RNG clock or history")
	var history_size := app.run_state.story_log.size()
	app._on_game_surface_action("slot_spin", 0, false)
	await _frames(3)
	var after := State.read_machine(app.run_state.current_environment, key)
	var result: Dictionary = app.last_game_result
	if _check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "spin", venue + " ordinary manual SPIN accepts one naturally-generated result"):
		var net := int(after.get("last_net", 99999))
		_check(int(after.get("spin_count", 0)) == int(before.get("spin_count", 0)) + 1 and int(after.get("coin_in", 0)) == int(before.get("coin_in", 0)) + 2 and int(after.get("last_stake_cost", 0)) == 2, venue + " accepted spin places exactly one two-unit paid stake")
		_check(app.run_state.bankroll == 134 + net and app.run_state.grand_casino_chips == 25, venue + " one settlement changes only cash by actual result net")
		_check(int(result.get("bankroll_delta", 99999)) == net and net == int(after.get("last_payout", 0)) - 2, venue + " published result and machine net equal payout minus paid stake")
		_check(app.run_state.story_log.size() == history_size + 1, venue + " accepted spin appends exactly one receipt")
		if app.run_state.story_log.size() == history_size + 1:
			_assert_row(app.run_state, app.run_state.story_log.back(), net, venue)
		_assert_legacy(app.run_state, venue)
		_save_reference(app.run_state, "slot_journal_" + venue, net, key)
		facts.host.append({"venue": venue, "state_key": key, "seed_text": app.run_state.seed_text, "format": after.get("format_id", ""), "family": after.get("type_id", ""), "stake": after.get("last_stake_cost", 0), "payout": after.get("last_payout", 0), "net": net, "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "spin_count": after.get("spin_count", 0), "outcome_id": after.get("last_outcome_id", ""), "exact_reported_loss_shape": net == -2 and app.run_state.bankroll == 132})
	await _cleanup(app)


func _assert_row(run: RunState, entry: Dictionary, expected: int, label: String) -> void:
	_check(str(entry.get("game_id", "")) == "slot" and str(entry.get("currency", "")) == "cash" and entry.has("currency_delta") and int(entry.get("currency_delta", 99999)) == expected, label + " new Slot receipt records cash and exact settled net")
	var before := _protected(run)
	var lines: Array = Journal._recorded_money_detail_lines(entry)
	_check(lines == ["Bankroll %+d" % expected], label + " journal displays one exact cash amount")
	for repeat in range(3): Journal._recorded_money_detail_lines(entry)
	_check(_protected(run) == before, label + " repeated journal formatting preserves complete protected state")


func _assert_legacy(run: RunState, label: String) -> void:
	_check(run.story_log[0] == LEGACY and not run.story_log[0].has("currency"), label + " original unknown-unit Slot row remains exact")
	_check(Journal._recorded_money_detail_lines(run.story_log[0]) == ["Recorded change -7 (currency not recorded)"], label + " historical currency remains unknown despite current venue")


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "history": run.story_log.duplicate(true), "all_game_states": run.current_environment.get("game_states", {}).duplicate(true), "active_game_state_keys": run.current_environment.get("active_game_state_keys", {}).duplicate(true)}


func _economy_guard(run: RunState) -> Dictionary:
	# A normal selector may rewrite its cabinet controls; it must not transact.
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "history": run.story_log.duplicate(true)}


func _save_reference(run: RunState, slot: String, net: int, key: String) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores " + slot): return
	_check(_protected(run) == before, "official Save never transacts or rewrites history: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh SaveService officially loads " + slot): return
	_check(_persistent_fingerprint(_protected(loaded)) == _persistent_fingerprint(before), "official load preserves wallets RNG clocks complete history and ALL cabinet states: " + slot)
	_check(_money_lines(loaded) == _money_lines(run), "official load preserves every journal money line: " + slot)
	_assert_legacy(loaded, slot)
	# References are taken after one official codec load; cold compares a second
	# real load exactly, without reconstructing saves or changing their keys.
	references.append({"slot": slot, "net": net, "state_key": key, "protected_json": JSON.stringify(_protected(loaded)), "lines": _money_lines(loaded)})


func _cold() -> void:
	if not _check(FileAccess.file_exists(_reference_path()), "producer reference exists for independent cold process"): return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 2, "Gas and Grand producer save references both exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var before := _protected(loaded)
		_check(JSON.stringify(before) == str(reference.protected_json), "cold wallets RNG clocks complete history and ALL cabinet states equal producer load: " + str(reference.slot))
		_check(_money_lines(loaded) == reference.lines, "cold all recorded money lines match producer: " + str(reference.slot))
		_assert_row(loaded, loaded.story_log.back(), int(reference.net), str(reference.slot))
		_assert_legacy(loaded, str(reference.slot))
		_check(_protected(loaded) == before, "cold reader never repeats a spin or settlement: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "spin_count": State.read_machine(loaded.current_environment, str(reference.state_key)).get("spin_count", 0), "lines": _money_lines(loaded)})
	completed = true


func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for entry in run.story_log: lines.append(Journal._recorded_money_detail_lines(entry))
	return lines


func _persistent_fingerprint(value: Variant) -> String:
	# Only official JSON transport compares normalized numeric representation.
	# No fields are dropped; same-process immutability checks remain exact.
	return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _reference_path() -> String: return private_root.path_join("slot-journal-host-reference.json")


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured player save or browser profile is accepted")


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _cleanup(app: PracticeHost) -> void:
	app.set_process(false)
	if app.save_service != null: app.save_service.wait_for_async_save()
	if app.get_parent() != null: app.get_parent().remove_child(app)
	app.free()
	await process_frame


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested Host producer or cold stage reaches final assertion")
	var report := {"id": "JOURNAL-CURRENCY-SLOT753-RELATED", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "producer", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"slot": FileAccess.get_sha256("res://scripts/games/slot.gd"), "resolver": FileAccess.get_sha256("res://scripts/games/slots/slot_resolver.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/slot_journal_host_cold_check.gd")}, "fidelity": "Disposable canonical practice launcher, archetype/funding-only Host subclass, ordinary manual BET2/SPIN handler and unchanged RNG. Full history and all cabinets preserved through official SaveService and independent cold load. No original R04 profile, Web/OS pointer gameplay or normal main-menu Continue is claimed."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("SLOT_JOURNAL_HOST_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
