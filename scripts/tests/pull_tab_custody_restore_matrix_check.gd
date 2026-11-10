extends SceneTree

# BTH061-PULLTABS-SAVE-001: independent unopened-ticket custody boundaries.
# Original campaign/profile/save data are never read. Each case buys one newly
# generated naturally priced $2 ticket; no ticket result is selected or altered.
const MainScene := preload("res://scenes/main.tscn")
const Fixture := preload("res://scripts/tests/pull_tab_grand_fixture.gd")
const Provenance := preload("res://scripts/tests/save_generation_provenance.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const CASES := ["tray_reload", "floor_reload", "stale_location", "readonly_views"]
const PLAYER_FIELDS := ["tray_stack", "ticket_stack", "winner_pile", "loser_pile", "loser_archive_count"]
var failures: Array[String] = []
var skipped: Array = []
var checks := 0
var completed := false
var facts: Dictionary = {}


func _initialize() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty() or OS.has_feature("web"):
		completed = true
		push_error("Custody matrix requires a fresh isolated native distribution root")
		quit(1)
		return
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _progress(stage: String) -> void:
	print("PULL_TAB_CUSTODY_PROGRESS stage=", stage, " ticks_msec=", Time.get_ticks_msec())


func _slot(case_id: String) -> String:
	return "pull_tab_custody_" + case_id


func _receipt_path() -> String:
	return SaveService.new().run_save_path(_slot(CASES[0])).get_base_dir().path_join("pull_tab_custody_matrix_expected.json")


func _pile(run: RunState) -> Dictionary:
	return run.portable_ticket_state("pull_tabs", run.current_environment)


func _snapshot(run: RunState) -> Dictionary:
	var machine: Dictionary = run.current_environment.get("game_states", {}).get("pull_tabs", {})
	var card_bits := {}
	for value in run.inventory:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var meta: Dictionary = value.get("meta_collection", {})
		if int(meta.get("itemdef_id", 0)) != 9500:
			continue
		var bits := {}
		for key in ["potency", "condition", "resonance", "usage"]:
			bits[key] = var_to_bytes(float(meta.get("floats", {}).get(key, -1.0))).hex_encode()
		card_bits[str(value.get("id", ""))] = bits
	return JSON.parse_string(JSON.stringify({
		"pile": _pile(run), "cash": run.bankroll, "chips": run.grand_casino_chips,
		"heat": run.suspicion_level(), "rng": str(run.rng_state),
		"deals": machine.get("deals", []), "tickets_sold": machine.get("tickets_sold", 0),
		"inventory": run.inventory, "card_float_bits": card_bits, "pending_bags": run.pending_bags,
		"challenge_modifiers": run.challenge_modifiers(),
		"clock_minutes": run.game_clock_minutes, "scenario_id": run.current_environment.get("scenario_id", ""),
	}))


func _protected(snapshot: Dictionary, keep_pile: bool = true) -> Dictionary:
	var result := snapshot.duplicate(true)
	result.erase("clock_minutes")
	if not keep_pile:
		result.erase("pile")
	return result


func _verify_custody(run: RunState, ticket_id: String, label: String) -> void:
	var pile := _pile(run)
	var count := 0
	for field in ["tray_stack", "ticket_stack", "winner_pile", "loser_pile"]:
		for ticket in pile.get(field, []):
			if str(ticket.get("id", "")) == ticket_id:
				count += 1
	var stack: Array = pile.get("ticket_stack", [])
	_check(not ticket_id.is_empty() and count == 1 and stack.size() == 1 \
			and str(stack[0].get("id", "")) == ticket_id and pile.get("tray_stack", []).is_empty(), label + " lost/duplicated collected identity or restored its tray")
	var machine: Dictionary = run.current_environment.get("game_states", {}).get("pull_tabs", {})
	_check(machine.get("tray_stack", []).is_empty() and machine.get("ticket_stack", []) == pile.get("ticket_stack", []), label + " current room disagrees with canonical custody")


func _menu_save(app: Control, slot: String, label: String) -> bool:
	app.set("autosave_slot_id", slot)
	app.call("open_run_menu")
	app.call("save_run_from_menu")
	Provenance.record(label + " menu_save_return", app.get("save_service"), slot, _snapshot(app.get("run_state")), app)
	return _check(not bool(app.get("run_menu_overlay").visible), label + " Menu Save was not accepted")


func _location_storage_audit(value: Variant) -> Dictionary:
	var result := {"ok": true, "rooms": 0}
	if typeof(value) == TYPE_DICTIONARY:
		var body: Dictionary = value
		var states: Variant = body.get("game_states", {})
		if typeof(states) == TYPE_DICTIONARY and typeof(states.get("pull_tabs")) == TYPE_DICTIONARY:
			result["rooms"] = 1
			var machine: Dictionary = states.get("pull_tabs")
			for field in PLAYER_FIELDS:
				if machine.has(field):
					result["ok"] = false
		# Only nested room/layer snapshots are location copies; authored scenario
		# definitions and presentation receipts are not independent custody stores.
		var layers: Dictionary = body.get("layer_states", {}) if typeof(body.get("layer_states", {})) == TYPE_DICTIONARY else {}
		for key in layers:
			var child := _location_storage_audit(layers[key])
			result["ok"] = bool(result["ok"]) and bool(child["ok"])
			result["rooms"] = int(result["rooms"]) + int(child["rooms"])
	elif typeof(value) == TYPE_ARRAY:
		for child_value in value:
			var child := _location_storage_audit(child_value)
			result["ok"] = bool(result["ok"]) and bool(child["ok"])
			result["rooms"] = int(result["rooms"]) + int(child["rooms"])
	return result


func _verify_saved(slot: String, expected: Dictionary, ticket_id: String, label: String) -> void:
	var service := SaveService.new()
	var before := Provenance.fingerprints(service, slot)
	Provenance.record(label + " before_load", service, slot, {})
	var loaded: RunState = service.load_run(slot)
	Provenance.record(label + " first_load_return", service, slot, _snapshot(loaded) if loaded != null else {})
	_check(Provenance.fingerprints(service, slot) == before, label + " load changed primary/backup bytes")
	_check(str(service.last_load_result().get("outcome", "")) == SaveService.LOAD_OUTCOME_PRIMARY, label + " unexpectedly fell back from generated primary")
	if not _check(loaded != null, label + " save is not loadable"):
		return
	_check(_snapshot(loaded) == expected, label + " saved generation changed protected state/exact clock")
	_verify_custody(loaded, ticket_id, label + " disk")
	# Inspect only this fixture's official envelope; decode without changing it.
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.run_save_path(slot)))
	if not _check(typeof(payload) == TYPE_DICTIONARY, label + " envelope is unavailable"):
		return
	var decoded := Codec.decode(Codec.unpack_from_storage(payload.get("run_state", {})))
	var origin := RunState.portable_ticket_origin_key(loaded.current_environment)
	var stored_pile: Dictionary = decoded.get("portable_ticket_piles", {}).get("pull_tabs", {}).get(origin, {})
	_check(JSON.parse_string(JSON.stringify(stored_pile)) == expected.get("pile", {}), label + " serialized canonical pile differs")
	var locations: Array = [decoded.get("current_environment", {})]
	for node in decoded.get("world_map", {}).get("nodes", []):
		if typeof(node) == TYPE_DICTIONARY:
			locations.append(node.get("environment", {}))
	var rooms: Dictionary = decoded.get("grand_casino_room_states", {})
	for room in rooms.values():
		locations.append(room)
	var audit := _location_storage_audit(locations)
	_check(bool(audit["ok"]) and int(audit["rooms"]) > 0, label + " location copies retain duplicate player custody")


func _collect(app: Control, ticket_id: String, label: String) -> void:
	var run: RunState = app.get("run_state")
	var before := _snapshot(run)
	app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
	_verify_custody(run, ticket_id, label)
	_check(_protected(_snapshot(run), false) == _protected(before, false), label + " changed stock/wallet/Heat/RNG/Gold/Blue")


func _reenter_and_repeat(app: Control, expected: Dictionary, ticket_id: String, label: String) -> void:
	if not _check(bool(app.call("enter_game", "pull_tabs")), label + " machine re-entry failed"):
		return
	var run: RunState = app.get("run_state")
	_verify_custody(run, ticket_id, label)
	var entered := _snapshot(run)
	_check(_protected(entered) == _protected(expected) and int(entered["clock_minutes"]) >= int(expected["clock_minutes"]), label + " re-entry changed protected state or reversed clock")
	app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
	_check(_snapshot(run) == entered, label + " empty repeat Collect changed state")


func _run_case(app: Control, case_id: String) -> Dictionary:
	var slot := _slot(case_id)
	var service: SaveService = app.get("save_service")
	if not _check(not service.has_run(slot), case_id + " producer requires a fresh slot"):
		return {}
	app.set("autosave_slot_id", slot)
	_progress(case_id + " fixture")
	var setup := Fixture.create(app, "BTH061-PULLTABS-CUSTODY-" + case_id.to_upper() + "-1", {"scenario_id": "grand_casino_audit_night", "clock_minutes": 3120})
	if not _check(bool(setup.get("ok", false)), case_id + " fixture failed: " + JSON.stringify(setup.get("errors", []))):
		return {}
	var generated: RunState = setup.get("run")
	if not _check(service.save_run(generated, slot) == OK and bool(app.call("load_foundation_run")), case_id + " official baseline Save/Continue failed"):
		return {}
	if not _check(bool(app.call("enter_game", "pull_tabs")), case_id + " machine entry failed"):
		return {}
	app.call("_on_game_surface_action", "pull_tab_buy", int(setup.get("facts", {}).get("two_dollar_deal_index", -1)), false)
	for _frame in range(6):
		await process_frame
	var run: RunState = app.get("run_state")
	var tray: Array = _pile(run).get("tray_stack", [])
	if not _check(tray.size() == 1 and run.bankroll == 94 and run.grand_casino_chips == 13 and run.suspicion_level() == 0, case_id + " one $2 purchase did not produce exactly one paid tray ticket"):
		return {}
	var ticket_id := str(tray[0].get("id", ""))
	run.store_current_world_node_environment()
	run.store_grand_casino_room_environment(run.current_environment)
	var pre_environment := run.current_environment.duplicate(true)
	var pre_world := run.world_map.duplicate(true)
	var pre_rooms := run.grand_casino_room_states.duplicate(true)
	var pre_ui: Dictionary = app.get("game_surface_ui_state").duplicate(true)
	var purchased := _snapshot(run)
	if case_id == "tray_reload":
		if not _menu_save(app, slot, case_id + " precollect"):
			return {}
		if not _check(bool(app.call("load_foundation_run")) and bool(app.call("enter_game", "pull_tabs")), case_id + " precollect warm reload failed"):
			return {}
		run = app.get("run_state")
		_check(_pile(run).get("tray_stack", []).size() == 1 and str(_pile(run).get("tray_stack", [])[0].get("id", "")) == ticket_id, case_id + " precollect reload changed ticket identity")
		_check(_protected(_snapshot(run)) == _protected(purchased), case_id + " precollect reload/re-entry changed stock/wallet/Heat/RNG/Gold/Blue")
		# Register a new older tray-generation save, then collect and immediately
		# force Menu Save without a harness drain or another process frame.
		_check(service.begin_save_run(run, slot) == OK, case_id + " could not register older tray-generation save")
		_check(service.async_save_in_flight(), case_id + " older tray-generation job is not registered")
	_collect(app, ticket_id, case_id + " collection")
	var expected := _snapshot(run)
	if case_id == "stale_location":
		# Synthetic fault model: replay captured VALID precollection location/UI
		# copies only. Preserve canonical collected ownership and every seal byte.
		run.current_environment = pre_environment.duplicate(true)
		run.world_map = pre_world.duplicate(true)
		run.grand_casino_room_states = pre_rooms.duplicate(true)
		if not bool(run.validate_room_action_authority().get("ok", false)):
			var reason := "Captured precollect location copies fail current authority; no seal bypass attempted"
			skipped.append({"case": case_id, "reason": reason})
			_progress(case_id + " SKIPPED " + reason)
			return {}
		_check(true, case_id + " captured stale location authority")
		app.call("_store_current_game_surface_ui_state", pre_ui)
		var game: GameModule = app.get("current_game")
		game.checkpoint_surface_ui_state(pre_ui, run, run.current_environment)
		_check(_snapshot(run) == expected, case_id + " checkpoint overwrote canonical collected ownership/protected state")
	if case_id == "readonly_views":
		var game: GameModule = app.get("current_game")
		var location_before := run.current_environment.duplicate(true)
		for _repeat in range(3):
			var view := game.surface_state(run, run.current_environment, pre_ui)
			game.environment_runtime_state(run, run.current_environment)
			game.environment_object_state(run, run.current_environment)
			game.coach_state(run, run.current_environment, pre_ui)
			_check(view.get("pull_tab_tray_stack", []).is_empty() and view.get("pull_tab_stack", []).size() == 1, case_id + " projection returned stale custody")
			_check(_snapshot(run) == expected and run.current_environment == location_before, case_id + " read-only projection mutated protected state or raw room custody")
	_progress(case_id + " collected_save")
	if case_id == "tray_reload":
		_check(service.async_save_in_flight(), case_id + " earlier tray-generation job was not registered at manual Save")
	if not _menu_save(app, slot, case_id + " machine"):
		return {}
	_verify_saved(slot, expected, ticket_id, case_id + " machine")
	if case_id == "floor_reload":
		if not _check(bool(app.call("load_foundation_run")), case_id + " collected warm floor Load failed"):
			return {}
		run = app.get("run_state")
		_check(_snapshot(run) == expected, case_id + " warm floor Load changed collected generation")
		expected = _snapshot(run)
		if not _menu_save(app, slot, case_id + " floor"):
			return {}
		_verify_saved(slot, expected, ticket_id, case_id + " floor")
	if not _check(bool(app.call("load_foundation_run")), case_id + " final warm Continue failed"):
		return {}
	_check(_snapshot(app.get("run_state")) == expected, case_id + " final warm Continue changed saved generation")
	_reenter_and_repeat(app, expected, ticket_id, case_id + " warm")
	facts[case_id] = {"ticket_id": ticket_id, "seed": setup.get("facts", {}).get("seed", ""), "synthetic_fault_model": case_id == "stale_location"}
	if case_id == "stale_location":
		facts[case_id]["checkpoint_scope"] = "Captured unopened UI with no reveal input: tests canonical serialization/restore precedence, not deliberate reveal-write coverage."
	if case_id == "tray_reload":
		facts[case_id]["overlap_scope"] = "Earlier tray-generation job registered at Collect/force Save; native disk I/O may already have finished. No harness drain or frame yield before manual Save."
	return {"slot": slot, "ticket_id": ticket_id, "expected": expected}


func _run() -> void:
	_progress("start")
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	app.get("user_settings").coach_tips_enabled = false
	if OS.get_cmdline_user_args().has("--cold"):
		var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(_receipt_path()))
		if _check(typeof(receipt) == TYPE_DICTIONARY and typeof(receipt.get("cases")) == TYPE_ARRAY, "cold phase requires warm fixture receipt"):
			skipped = receipt.get("skipped", [])
			_check(receipt.get("cases", []).size() + skipped.size() == CASES.size(), "cold receipt does not account for all four independent cases")
			for value in receipt.get("cases", []):
				var row: Dictionary = value
				_progress(str(row.get("slot", "")) + " cold")
				_verify_saved(row["slot"], row["expected"], row["ticket_id"], row["slot"] + " cold")
				app.set("autosave_slot_id", row["slot"])
				if _check(bool(app.call("load_foundation_run")), row["slot"] + " cold Continue failed"):
					Provenance.record(row["slot"] + " first_cold_host_continue", app.get("save_service"), row["slot"], _snapshot(app.get("run_state")), app)
					_check(str(app.get("save_service").last_load_result().get("outcome", "")) == SaveService.LOAD_OUTCOME_PRIMARY, row["slot"] + " cold host unexpectedly fell back")
					_check(_snapshot(app.get("run_state")) == row["expected"], row["slot"] + " cold Continue changed exact generation")
					_reenter_and_repeat(app, row["expected"], row["ticket_id"], row["slot"] + " cold")
	else:
		var rows: Array = []
		for case_id in CASES:
			var row: Dictionary = await _run_case(app, case_id)
			if not row.is_empty():
				rows.append(row)
		_check(rows.size() + skipped.size() == CASES.size(), "warm matrix did not finish each independent case")
		var file := FileAccess.open(_receipt_path(), FileAccess.WRITE)
		if _check(file != null, "warm custody matrix receipt could not be written"):
			file.store_string(JSON.stringify({"cases": rows, "skipped": skipped}))
			file.close()
	app.get("save_service").wait_for_async_save()
	app.queue_free()
	for _frame in range(8):
		await process_frame
	completed = true
	print("PULL_TAB_CUSTODY_MATRIX cold=", OS.get_cmdline_user_args().has("--cold"), " checks=", checks, " failures=", JSON.stringify(failures), " skipped=", JSON.stringify(skipped), " facts=", JSON.stringify(facts))
	quit(0 if failures.is_empty() else 1)


func _finalize() -> void:
	if not completed:
		push_error("Custody matrix exited before completing")
