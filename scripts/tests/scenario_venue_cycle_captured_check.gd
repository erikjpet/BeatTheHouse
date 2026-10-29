extends SceneTree
const Host := preload("res://scripts/ui/foundation_main.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const EngineScript := preload("res://scripts/core/scenario_engine.gd")
const Semantic := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const WorldAdapter := preload("res://scripts/core/crew_world_sequence_adapter.gd")
var checks := 0
var failures: Array = []
var facts: Dictionary = {}
var clock_reference: RunState
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private root required"): _finish(); return
	var mode := OS.get_environment("BTH_VENUE_CASE")
	if mode != "restore_only": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official saved baseline loaded"): _finish(); return
	var protected := _protected(baseline)
	clock_reference = RunState.new(); clock_reference.from_dict(baseline.to_dict())
	var original_receipts: Array = baseline.current_environment.get("scenario_sequence_state", {}).get("command_receipts", []).duplicate(true)
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true; root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal host Continue"): app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	var archetype := str(run.current_environment.archetype_id)
	facts = {"mode": mode, "archetype": archetype, "initial_clock": run.game_clock_minutes, "initial_scenario": run.current_environment.get("scenario_id", ""), "original_receipts": original_receipts}
	if protected.get("game_states", {}) != _protected(run).get("game_states", {}):
		facts["initial_game_state_diff_paths"] = _different_paths(protected.get("game_states", {}), _protected(run).get("game_states", {})).map(func(x): return x.get("path", ""))
	_check(_protected(run) == protected, "Continue/legacy retirement preserves protected gameplay")
	# Detached ordinary-clock/game-owner control. It never runs the new venue
	# coordinator, so restock/visit changes cannot mask a lifecycle reset.
	clock_reference.from_dict(run.to_dict())
	clock_reference.current_environment = run.current_environment.duplicate(true)
	clock_reference.restore_scenario_definition_cache(run.scenario_definition_cache_snapshot())
	_check(bool(clock_reference.scenario_finalize_installed_environment(app.library).get("ok", false)), "ordinary-clock control has valid independent room authority")
	if mode == "restore_only":
		_check(_different_paths(baseline.environment_situation_cycles_by_node, run.environment_situation_cycles_by_node).is_empty(), "independent-process cycle and historical journals unchanged")
		_check(bool(run.validate_room_action_authority().get("ok", false)), "independent-process current room authority valid")
		_check(not app._interactable_object_view_list().is_empty(), "independent-process base controls usable")
		facts["history_count"] = run.environment_situation_cycle(archetype).get("history", {}).size()
		app.queue_free(); await process_frame; _finish(); return
	var lifecycle := run.environment_situation_cycle(archetype).duplicate(true)
	_check(int(lifecycle.get("schedule_version", 0)) == 1, "new schedule metadata durable")
	if mode in ["bar", "store"]:
		if mode == "bar": _scope_controls(app)
		_check(not str(run.current_environment.get("scenario_id", "")).is_empty(), "original in-session scenario retained")
		var close_minute := 180 if mode == "bar" else 60
		var open_minute := 660 if mode == "bar" else 360
		var close_at := _next_minute(run.game_clock_minutes, close_minute)
		_check(_advance(app, close_at - 1), "advance normally to minute before close")
		_check(not str(run.current_environment.get("scenario_id", "")).is_empty(), "no early retirement")
		_check(_advance(app, close_at), "advance normally to exact close")
		_assert_closed(app, original_receipts)
		var history: Dictionary = run.environment_situation_cycle(archetype).get("history", {}).duplicate(true)
		_check(_advance(app, _next_minute(run.game_clock_minutes, open_minute) - 1), "advance to before reopening")
		_assert_closed(app, original_receipts)
		_check(run.environment_situation_cycle(archetype).get("history", {}) == history, "closed clock checks never duplicate cleanup")
		_check(_advance(app, run.game_clock_minutes + 1), "advance to exact reopening")
		_check(str(run.environment_situation_cycle(archetype).phase) == "active", "one reopened selection cycle")
	elif mode in ["motel", "midnight", "layers"]:
		var current_cycle := str(run.current_environment.environment_situation_cycle_id)
		if mode == "midnight":
			_check(_advance(app, _next_minute(run.game_clock_minutes, 0)), "advance through midnight")
			_check(str(run.current_environment.environment_situation_cycle_id) == current_cycle, "midnight does not replace24h cycle")
		var close_at := _next_minute(run.game_clock_minutes, 150)
		_check(_advance(app, close_at - 1), "24h02:29 reached")
		var before_cycle := str(run.current_environment.environment_situation_cycle_id)
		_check(_advance(app, close_at), "24h exact02:30 reached")
		_assert_closed(app, original_receipts)
		_check(_advance(app, close_at + 89), "24h03:59 reached")
		_assert_closed(app, original_receipts)
		_check(_advance(app, close_at + 90), "24h exact04:00 reached")
		_check(str(run.current_environment.environment_situation_cycle_id) != before_cycle and str(run.environment_situation_cycle(archetype).phase) == "active", "one new cycle at04:00")
		if mode == "layers":
			var layers: Dictionary = run.current_environment.get("layer_states", {})
			_check(layers.size() == 3, "all three authored underground floors retained")
			for layer in layers:
				_check(str(layers[layer].get("environment_situation_cycle_id", "")) == str(run.current_environment.environment_situation_cycle_id), "all floors share one current venue cycle")
				_check(EnvironmentInstance.object_manifest_errors(layers[layer]).is_empty(), "every retained floor has a strict physical manifest")
	else:
		_assert_closed(app, original_receipts)
		var schedule := EnvironmentHours.scenario_cycle_status(app.generator._archetype_by_id(archetype), run.game_clock_minutes)
		_check(_advance(app, int(schedule.next_open_at)), "closed legacy save reaches next opening")
		_check(str(run.environment_situation_cycle(archetype).phase) == "active", "closed-save new cycle begins once")
	_check(_protected(run) == protected, "all rollover gameplay funds/items/paid games/history/RNG unchanged")
	_check(not str(run.current_environment.get("scenario_id", "")).is_empty() or run.scenario_for_node(archetype).is_empty(), "empty current selection never advertises the previous town seed")
	_check(_different_paths(clock_reference.current_environment.get("game_states", {}), run.current_environment.get("game_states", {})).is_empty(), "entire initialized machines equal unchanged ordinary-clock/game-owner control")
	facts["changed_protected_keys"] = _different_keys(protected, _protected(run))
	facts["changed_narrative_keys"] = _different_keys(protected.get("narrative_flags", {}), _protected(run).get("narrative_flags", {}))
	var stable_record := run.environment_situation_cycle(archetype).duplicate(true)
	var stable_scenario: Dictionary = run.current_environment.get("scenario_sequence_state", {}).duplicate(true)
	for repeat in range(3): app._prepare_room_presentation_at_boundary()
	_check(run.environment_situation_cycle(archetype) == stable_record, "refresh never reselects or re-retires current cycle")
	_check(run.current_environment.get("scenario_sequence_state", {}) == stable_scenario, "refresh never repeats arrival/reward initialization")
	_check(not app._interactable_object_view_list().is_empty() and not _has_room_unavailable(app), "base room remains usable and published")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "strict room action authority remains valid")
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Main Menu after Save")
	await process_frame; app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "official fresh-service Continue")
	run = app.run_state
	_check(_protected(run) == protected, "Save/Continue protected paid state and history exact")
	_check(_different_paths(clock_reference.current_environment.get("game_states", {}), run.current_environment.get("game_states", {})).is_empty(), "initialized machine state survives lifecycle Save/Continue exactly")
	_check(_different_paths(stable_record, run.environment_situation_cycle(archetype)).is_empty(), "every cycle selection/retirement key and value restores exactly")
	if run.environment_situation_cycle(archetype) != stable_record:
		facts["cycle_restore_diff"] = _different_paths(stable_record, run.environment_situation_cycle(archetype))
	_check(str(run.current_environment.get("environment_situation_cycle_id", "")) == str(stable_record.cycle_id), "serialized environment retains explicit cycle stamp")
	facts["final_clock"] = run.game_clock_minutes; facts["final_scenario"] = run.current_environment.get("scenario_id", "")
	facts["history_count"] = run.environment_situation_cycle(archetype).get("history", {}).size()
	facts["cash"] = run.bankroll; facts["Heat"] = run.suspicion_level()
	app.queue_free(); await process_frame; _finish()
func _advance(app: Host, target: int) -> bool:
	var run: RunState = app.run_state
	if target < run.game_clock_minutes: return false
	var result := run.advance_game_clock_minutes(target - run.game_clock_minutes)
	if not bool(result.get("ok", false)): facts["clock_error"] = result; return false
	var ordinary_clock := clock_reference.advance_game_clock_minutes(target - clock_reference.game_clock_minutes)
	_check(bool(ordinary_clock.get("ok", false)) and run.narrative_flags.get("character_offer_cycles", {}) == clock_reference.narrative_flags.get("character_offer_cycles", {}), "character-offer cadence matches unchanged ordinary-clock control")
	var control_finalization := clock_reference.scenario_finalize_installed_environment(app.library)
	if not bool(control_finalization.get("ok", false)): facts["clock_control_error"] = control_finalization; return false
	for id in clock_reference.current_environment.get("game_ids", []):
		var game := app._game_module_for_id(str(id))
		if game == null: continue
		var prepared := game.prepare_environment_presentation_boundary(clock_reference, clock_reference.current_environment)
		if not bool(prepared.get("ok", false)): facts["clock_control_error"] = prepared; return false
	var cycle_result := app.generator.refresh_current_venue_scenario_cycle(run)
	if not bool(cycle_result.get("ok", false)):
		facts["cycle_error"] = cycle_result
		return false
	app._prepare_room_presentation_at_boundary()
	var expected := EnvironmentHours.scenario_cycle_status(app.library.environment_archetype_for_challenge(app.generator._archetype_by_id(str(run.current_environment.archetype_id)), run.challenge_config), target)
	return str(run.environment_situation_cycle(str(run.current_environment.archetype_id)).get("phase", "")) == ("active" if expected.active else "closed")
func _assert_closed(app: Host, original: Array) -> void:
	var run: RunState = app.run_state
	_check(str(run.current_environment.get("scenario_id", "")).is_empty() and run.current_environment.get("scenario_state", {}).is_empty(), "no current scenario while closed")
	_check(run.scenario_sequence_projection().is_empty(), "no scenario active or terminal projection while closed")
	var history: Dictionary = run.environment_situation_cycle(str(run.current_environment.archetype_id)).get("history", {})
	var original_found := false
	for record in history.values():
		if record.get("sequence_state", {}).get("command_receipts", []) == original: original_found = true
	_check(original_found, "original accepted command journal retained in cycle history")
	for object in app._interactable_object_view_list():
		_check(not str(object.get("object_id", "")).begins_with("scenario::") or not str(object.get("world_sequence_owner_token", "")).is_empty(), "no environment-scenario-owned actor/prop/task lingers")
	for layer in run.current_environment.get("layer_states", {}).values():
		_check(str(layer.get("scenario_id", "")).is_empty() and layer.get("scenario_sequence_state", {}).is_empty(), "no active or aftermath scenario on any closed floor")
func _protected(run: RunState) -> Dictionary:
	var s := run.to_dict(); var r: Dictionary = {}
	for key in ["bankroll", "grand_casino_chips", "debt", "grand_casino_atm_debt", "suspicion", "inventory", "home_state", "crew_state", "numbers_state", "rng_seed", "rng_state", "story_log", "narrative_flags", "run_spending_score", "run_status", "scenario_host_transaction_ledger", "active_delivery_run", "world_sequence_registrations"]: r[key] = s.get(key)
	r["current_world_owners"] = WorldAdapter.durable_container(run.current_environment.get("world_sequence_instances", {}))
	r["narrative_flags"] = r.get("narrative_flags", {}).duplicate(true)
	r["narrative_flags"].erase("character_offer_cycles")
	var games: Dictionary = run.current_environment.get("game_states", {}).duplicate(true)
	# Reuse ROOM028's already-qualified legacy visit/paid-asset boundary. The
	# old Grease fixture predates its committed Scratch scalper visit/restock.
	# Normalize only absent-empty paid piles; preserve every nonempty ticket and
	# paid accounting field. Entire initialized machines are checked separately.
	if games.has("scratch_tickets"):
		var scratch: Dictionary = games["scratch_tickets"]
		var paid: Dictionary = {"active_ticket": scratch.get("active_ticket", {})}
		for key in ["tray_stack", "pending_queue", "winner_pile", "loser_pile", "history"]: paid[key] = scratch.get(key, [])
		for key in ["purchase_count", "redemption_count", "ticket_sequence", "pending_payout", "coin_in", "coin_out", "loser_archive_count"]: paid[key] = scratch.get(key, 0)
		r["scratch_paid"] = paid
		games.erase("scratch_tickets")
	r["game_states"] = games
	return r.duplicate(true)
func _different_keys(before: Dictionary, after: Dictionary) -> Array:
	var result: Array = []
	for key in before:
		if before[key] != after.get(key): result.append(key)
	return result
func _different_paths(before: Variant, after: Variant, prefix: String = "") -> Array:
	var result: Array = []
	if before == after: return result
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		for key in before:
			if not after.has(key): result.append({"path": prefix + "/" + str(key), "kind": "missing_key"})
			else: result.append_array(_different_paths(before[key], after.get(key), prefix + "/" + str(key)))
		for key in after:
			if not before.has(key): result.append({"path": prefix + "/" + str(key), "kind": "new_key"})
	elif typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY and before.size() == after.size():
		for i in range(before.size()): result.append_array(_different_paths(before[i], after[i], prefix + "/" + str(i)))
	else:
		result.append({"path": prefix, "before_type": typeof(before), "after_type": typeof(after), "before": before if typeof(before) in [TYPE_INT, TYPE_FLOAT, TYPE_NIL] else str(before).sha256_text(), "after": after if typeof(after) in [TYPE_INT, TYPE_FLOAT, TYPE_NIL] else str(after).sha256_text()})
	return result.slice(0, 30)
func _has_room_unavailable(app: Host) -> bool:
	return app._interactable_object_view_list().any(func(x): return str(x.get("object_id", "")) == "room:unavailable")
func _next_minute(now: int, minute: int) -> int:
	return (int(floor(float(now) / 1440.0)) + (1 if now % 1440 >= minute else 0)) * 1440 + minute
func _scope_controls(app: Host) -> void:
	var run: RunState = app.run_state
	var before := run.to_dict()
	var definition := run.scenario_sequence_definition()
	var semantics := EngineScript.sequence_host_semantics(run.current_environment)
	var a := Runtime.initial_state(definition, run.current_world_node_id(), "venue_cycle_v1:fixture:cycleA", semantics, true)
	var b := Runtime.initial_state(definition, run.current_world_node_id(), "venue_cycle_v1:fixture:cycleB", semantics, true)
	_check(not a.is_empty() and a.get("errors", []).is_empty() and b.get("errors", []).is_empty(), "synthetic same-scenario two-cycle initial authorities valid")
	var tokens: Array = []
	var keys: Array = []
	for state in [a, b]:
		var projection := Runtime.public_projection(state, definition, true)
		var values: Array = []
		var receipt_keys: Array = []
		for interaction in projection.get("semantic_state", {}).get("interactions", {}).values():
			for action in Semantic.inline_actions_for_interaction(interaction, 0):
				values.append(action.get("emit_object_id", "")); receipt_keys.append(action.get("scenario_idempotency_key", ""))
		tokens.append(values)
		keys.append(receipt_keys)
	_check(not tokens[0].is_empty() and tokens[0] != tokens[1], "same authored actions receive distinct cycle-scoped public tokens")
	_check(not keys[0].is_empty() and keys[0] != keys[1], "same authored actions receive distinct cross-cycle idempotency keys")
	_check(not Runtime.normalize_state(a, definition, semantics).is_empty() and not Runtime.normalize_state(b, definition, semantics).is_empty(), "cycle-scoped operation journals pass normal causal validation")
	_check(run.to_dict() == before, "synthetic scope controls never mutate genuine run or RNG")
func _install(bundle: String) -> void:
	var user := ProjectSettings.globalize_path("user://"); var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "private captured save copied")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "private captured authority copied")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)): DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix)
func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok
func _finish() -> void:
	var hashes: Dictionary = {}
	for name in ["scripts/core/environment_hours.gd", "scripts/core/environment_instance.gd", "scripts/core/run_generator.gd", "scripts/core/run_state.gd", "scripts/core/scenario_sequence_runtime.gd", "scripts/core/scenario_venue_cycle.gd", "scripts/ui/foundation_main.gd", "scripts/ui/scenario_semantic_view_model.gd", "scripts/tests/scenario_venue_cycle_captured_check.gd", "scripts/tests/scenario_venue_cycle_edge_check.gd"]:
		hashes[name] = FileAccess.get_sha256("res://" + name)
	facts["source_sha256"] = hashes
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  ")); file.close()
	print("VENUE_CYCLE_CAPTURED checks=", checks, " failures=", JSON.stringify(failures)); quit(0 if failures.is_empty() else 1)
