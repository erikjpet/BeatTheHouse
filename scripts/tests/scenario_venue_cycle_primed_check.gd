extends SceneTree

# Synthetic generator-only regression for town priming before lazy destination
# refresh. Uses authored Motel content and ordinary generation/clock/command
# APIs. It does not qualify Host fare handling, a captured save, or Web input.
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const Operations := preload("res://scripts/core/scenario_operation_registry.gd")
const SCENARIO := "motel_wedding_overflow"
const SEED := "SYNTHETIC-MOTEL-PRIMED-VENUE-001"
const DAY_SIX_NOON := 5 * 1440 + 720
const DAY_SEVEN := 6 * 1440
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"scope": "Synthetic generator-only pinned Motel; priming before lazy stored-room refresh, authenticated command, ordinary clock APIs. No Host fare, actual player save, process-cold or Web claim."}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-") and ProjectSettings.globalize_path("user://").contains("native-private-"), "explicit disposable distribution and resident roots required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "synthetic regression excludes captured and browser-profile inputs"):
		_finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	var base := _fixture(library)
	if base.is_empty():
		_finish(); return
	if OS.get_environment("BTH_PRIMED_CASE") == "forged_retirement":
		_reject_retirement_tamper(base, library)
		_finish(); return
	_boundary(base, library, "preclose", DAY_SEVEN + 149, "active", false)
	_boundary(base, library, "exact_close", DAY_SEVEN + 150, "closed", true)
	_boundary(base, library, "deadzone0330", DAY_SEVEN + 210, "closed", true)
	_boundary(base, library, "reopen0400", DAY_SEVEN + 240, "active", true)
	_reject_mismatch(base, library)
	_reject_retirement_tamper(base, library)
	_active_none(library)
	_layer_presence_contract(library)
	_finish()

func _fixture(library: ContentLibrary) -> Dictionary:
	var run := RunState.new()
	run.start_new(SEED, RunState.custom_challenge("motel_primed_venue", SEED, {"scenario_pins": {"motel": SCENARIO}}))
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	generator.next_environment(run)
	if not _check(not run.current_environment.is_empty(), "normal generator creates synthetic source"):
		return {}
	if not _check(bool(run.advance_game_clock_minutes(DAY_SIX_NOON - run.game_clock_minutes).get("ok", false)), "ordinary clock advances to Day6 noon"):
		return {}
	var arrived := generator.travel_environment_result(run, "motel", true)
	if not _check(bool(arrived.get("ok", false)) and str(run.current_environment.get("scenario_id", "")) == SCENARIO, "production generator installs pinned Day6 Wedding Motel"):
		facts["fixture_arrival"] = arrived.get("errors", [])
		return {}
	if not _command(run, "read_room_key_trail", "synthetic_motel_key_trail"):
		return {}
	var departed := generator.travel_environment_result(run, "gas_station_casino", true)
	if not _check(bool(departed.get("ok", false)) and run.current_world_node_id() != "motel", "normal generator departs and retains visited Motel"):
		facts["fixture_departure"] = departed.get("errors", [])
		return {}
	# Establish ordinary persisted defaults before exact in-process comparisons.
	var cache := run.scenario_definition_cache_snapshot()
	run.from_dict(run.to_dict())
	run.restore_scenario_definition_cache(cache)
	if not _check(bool(run.scenario_finalize_installed_environment(library).get("ok", false)), "restored synthetic source finalizes normally"):
		return {}
	var node := WorldMap.node_by_id(run.world_map, "motel")
	var room: Dictionary = node.get("environment", {})
	if not _check(str(node.get("state", "")) == WorldMap.STATE_VISITED and str(room.get("scenario_id", "")) == SCENARIO and not room.get("scenario_sequence_state", {}).get("command_receipts", []).is_empty(), "stored Day6 Motel retains authenticated command journal"):
		return {}
	facts["fixture"] = {"source": run.current_world_node_id(), "clock": run.game_clock_minutes, "stored_cycle": room.get("environment_situation_cycle_id", ""), "command_receipts": room.get("scenario_sequence_state", {}).get("command_receipts", [])}
	return {"snapshot": run.to_dict(), "cache": run.scenario_definition_cache_snapshot()}

func _restored(base: Dictionary, library: ContentLibrary, target: int) -> RunState:
	var run := RunState.new()
	run.from_dict(base.snapshot.duplicate(true))
	run.restore_scenario_definition_cache(base.cache)
	if not _check(bool(run.scenario_finalize_installed_environment(library).get("ok", false)), "synthetic sibling restores valid source authority"):
		return null
	if not _check(bool(run.advance_game_clock_minutes(target - run.game_clock_minutes).get("ok", false)), "ordinary clock reaches synthetic destination-observation time"):
		return null
	# The ordinary day rollover creates a new rival cast without neutral Heat
	# bookkeeping keys; from_dict adds their existing zero defaults on rollback.
	# Establish that official saved shape BEFORE priming or the rejection probe,
	# rather than dropping fields or normalizing the measured before/after state.
	var defaults: Array = []
	for index in range(run.rival_cheaters.size()):
		for key in ["last_heat_gain", "last_heat_action"]:
			if not run.rival_cheaters[index].has(key): defaults.append({"path": "rival_cheaters/%d/%s" % [index, key], "before_present": false, "official_load_default": 0})
	run.rival_cheaters = RunState._normalize_rival_cheaters(run.rival_cheaters)
	facts["fixture_rival_load_defaults"] = defaults
	return run

func _boundary(base: Dictionary, library: ContentLibrary, label: String, target: int, phase: String, retire: bool) -> void:
	var run := _restored(base, library, target)
	if run == null: return
	var generator := RunGenerator.new(library)
	var node := WorldMap.node_by_id(run.world_map, "motel")
	var original: Dictionary = node.get("environment", {}).duplicate(true)
	var old_cycle := str(original.get("environment_situation_cycle_id", ""))
	var old_state: Dictionary = original.get("scenario_sequence_state", {}).duplicate(true)
	var old_history: Dictionary = run.environment_situation_cycle("motel").get("history", {}).duplicate(true)
	var source := Runtime.content_fingerprint(run.current_environment)
	var protected := Runtime.content_fingerprint(_protected(run))
	generator._prime_town_scenarios(run, run.world_map)
	var primed: Dictionary = run.environment_situation_cycle("motel").duplicate(true)
	_check(str(primed.get("phase", "")) == phase, label + " town priming chooses current schedule phase")
	if phase == "closed":
		_check(str(primed.get("cycle_id", "")) == old_cycle and str(primed.get("scenario_id", "")).is_empty(), label + " same-opening closed prime precedes old-room refresh")
	var result := _lazy(run, generator)
	var join := generator._trusted_scenario_install_data(run, result) if not result.is_empty() else {"ok": false, "errors": generator._last_environment_install_errors}
	facts[label] = {"primed_phase": primed.get("phase", ""), "old_cycle": old_cycle, "selected": result.get("scenario_id", ""), "join_errors": join.get("errors", []), "lazy_errors": generator._last_environment_install_errors.duplicate(true)}
	if not _check(not result.is_empty() and bool(join.get("ok", false)), label + " primed lazy destination passes strict seeded install join"):
		return
	_check(Runtime.content_fingerprint(run.current_environment) == source and Runtime.content_fingerprint(_protected(run)) == protected, label + " lazy generation preserves source and protected gameplay")
	_check(Runtime.content_fingerprint(result.get("game_states", {})) == Runtime.content_fingerprint(original.get("game_states", {})), label + " stored paid game states retained exactly")
	var record := run.environment_situation_cycle("motel")
	var history: Dictionary = record.get("history", {})
	_check(history.size() == old_history.size() + (1 if retire else 0), label + " retires accepted old journal exactly once when due")
	if phase == "closed":
		_check(str(result.get("scenario_id", "")).is_empty() and result.get("scenario_state", {}).is_empty() and result.get("scenario_sequence_state", {}).is_empty() and result.get("scenario_sequence_projection", {}).is_empty(), label + " room has no retained primary scenario during deadzone")
	elif retire:
		_check(str(result.get("environment_situation_cycle_id", "")) != old_cycle and str(result.get("environment_situation_cycle_id", "")) == str(primed.get("cycle_id", "")), label + " reopening uses the newly primed cycle once")
	else:
		_check(str(result.get("scenario_id", "")) == SCENARIO and Runtime.content_fingerprint(result.get("scenario_sequence_state", {})) == Runtime.content_fingerprint(old_state), label + " preclose retains original accepted active room")
	if retire:
		_check(history.values().any(func(entry): return entry.get("sequence_state", {}).get("command_receipts", []) == old_state.get("command_receipts", [])), label + " retirement preserves original command receipt history")
	var installed := generator._install_environment(run, result)
	if not _check(bool(installed.get("ok", false)) and bool(run.validate_room_action_authority().get("ok", false)), label + " refreshed room installs with strict action authority"):
		return
	run.store_current_world_node_environment()
	var stable := Runtime.content_fingerprint(run.environment_situation_cycle("motel"))
	generator._prime_town_scenarios(run, run.world_map)
	var repeated := _lazy(run, generator)
	_check(not repeated.is_empty() and Runtime.content_fingerprint(run.environment_situation_cycle("motel")) == stable, label + " repeat priming and destination refresh never reselect or retire twice")

func _reject_mismatch(base: Dictionary, library: ContentLibrary) -> void:
	var run := _restored(base, library, DAY_SEVEN + 149)
	if run == null: return
	var generator := RunGenerator.new(library)
	generator._prime_town_scenarios(run, run.world_map)
	var other: Dictionary = {}
	for definition in library._scenarios_for_archetype_readonly("motel"):
		if str(definition.get("id", "")) != SCENARIO:
			other = definition; break
	if not _check(not other.is_empty() and run.seed_scenario_for_node("motel", other), "synthetic mismatch changes only a valid same-archetype seed after priming"):
		return
	var before := Runtime.content_fingerprint(run.to_dict())
	var room := _lazy(run, generator)
	var rejected := generator._trusted_scenario_install_data(run, room)
	_check(not bool(rejected.get("ok", true)) and rejected.get("errors", []).any(func(error): return str(error).contains("does not match the destination node")), "active same-cycle forged seed mismatch still rejects")
	_check(Runtime.content_fingerprint(run.to_dict()) == before, "rejected same-cycle mismatch preserves complete serialized source run")
	facts["forged_seed"] = rejected.get("errors", [])

func _reject_retirement_tamper(base: Dictionary, library: ContentLibrary) -> void:
	var run := _restored(base, library, DAY_SEVEN + 210)
	if run == null: return
	var generator := RunGenerator.new(library)
	generator._prime_town_scenarios(run, run.world_map)
	var node := WorldMap.node_by_id(run.world_map, "motel")
	var room: Dictionary = node.get("environment", {})
	var state: Dictionary = room.get("scenario_sequence_state", {})
	var receipts: Array = state.get("command_receipts", [])
	if not _check(not receipts.is_empty(), "forged retirement control has an actual accepted command receipt"):
		return
	state.get("command_fingerprints", {})[str(receipts[0])] = "synthetic-forged-command-fingerprint"
	# node_by_id intentionally returns a detached copy. Publish this explicitly
	# synthetic invalid input into its disposable map before exercising retirement.
	run.world_map = WorldMap.store_runtime_environment(run.world_map, "motel", room)
	_check(str(WorldMap.node_by_id(run.world_map, "motel").get("environment", {}).get("scenario_sequence_state", {}).get("command_fingerprints", {}).get(str(receipts[0]), "")) == "synthetic-forged-command-fingerprint", "forged retirement control is actually stored in its disposable destination")
	var before_state := run.to_dict().duplicate(true)
	var before := Runtime.content_fingerprint(before_state)
	var rejected := _lazy(run, generator)
	_check(rejected.is_empty() and not generator._last_environment_install_errors.is_empty(), "primed closed destination cannot retire or re-sign forged command authority")
	_check(Runtime.content_fingerprint(run.to_dict()) == before, "rejected forged retirement preserves complete serialized run and stored room")
	facts["forged_retirement"] = generator._last_environment_install_errors.duplicate(true)
	facts["forged_retirement_differences"] = _differences(before_state, run.to_dict())

func _active_none(library: ContentLibrary) -> void:
	var run := RunState.new()
	# Supported complete tutorial-room override deliberately selects no scenario.
	run.start_new(SEED + "-NONE", RunState.custom_challenge("motel_active_none", SEED + "-NONE", {"tutorial_environment_overrides": {"motel": {}}}))
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	generator.next_environment(run)
	var arrival := generator.travel_environment_result(run, "motel", true)
	if not _check(bool(arrival.get("ok", false)) and str(run.environment_situation_cycle("motel").get("phase", "")) == "active" and str(run.current_environment.get("scenario_id", "")).is_empty(), "supported active no-primary room generated"):
		facts["active_none_setup"] = arrival.get("errors", []); return
	run.store_current_world_node_environment()
	var record := Runtime.content_fingerprint(run.environment_situation_cycle("motel"))
	var protected := Runtime.content_fingerprint(_protected(run))
	for repeat in range(2):
		generator._prime_town_scenarios(run, run.world_map)
		var room := _lazy(run, generator)
		_check(not room.is_empty() and str(room.get("scenario_id", "")).is_empty() and Runtime.content_fingerprint(run.environment_situation_cycle("motel")) == record, "active no-primary current cycle remains empty on repeated prime and lazy refresh")
	_check(Runtime.content_fingerprint(_protected(run)) == protected, "active no-primary repeat changes no protected gameplay")

func _layer_presence_contract(library: ContentLibrary) -> void:
	var generator := RunGenerator.new(library)
	if not _check(generator.has_method("_venue_cycle_room_has_retained_scenario"), "closed fastpath exposes focused retained-scenario predicate"):
		return
	var mirror := {"current_layer_id": "lobby", "layer_states": {"lobby": {"scenario_id": SCENARIO}}}
	_check(not bool(generator.call("_venue_cycle_room_has_retained_scenario", mirror)), "top current body overrides its stale stored current-layer mirror")
	var other := mirror.duplicate(true)
	other["layer_states"]["guest"] = {"scenario_sequence_state": {"definition_id": SCENARIO}}
	_check(bool(generator.call("_venue_cycle_room_has_retained_scenario", other)), "retained scenario on another layer prevents closed fastpath")
	var legacy := {"scenario_id": "", "scenario_state": {"id": SCENARIO}}
	_check(bool(generator.call("_venue_cycle_room_has_retained_scenario", legacy)), "nonempty legacy state counts as retained even with empty explicit identity")

func _lazy(run: RunState, generator: RunGenerator) -> Dictionary:
	var rng := run.create_rng("synthetic_motel_lazy_destination")
	return generator._world_environment_data_for_node(run, run.world_map, WorldMap.node_by_id(run.world_map, "motel"), rng)

func _command(run: RunState, command_id: String, receipt: String) -> bool:
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
	var definition := run._scenario_sequence_definition_readonly()
	var interactions: Dictionary = Operations.resolved_semantic_state(state.get("semantic_state", {})).get("interactions", {})
	var availability: Dictionary = {}
	for key in interactions: availability[str(key)] = bool(interactions[key].get("enabled", true))
	for key in interactions:
		var interaction: Dictionary = interactions[key]
		for action in interaction.get("available_actions", []):
			if str(action.get("id", "")) != command_id: continue
			var owner := str(interaction.get("owner_namespace", ""))
			var stable := str(interaction.get("stable_object_id", ""))
			var descriptor := Runtime._command_descriptor(state, definition, owner, stable, command_id, {"host_interaction_availability": availability})
			var result := run.scenario_sequence_command(command_id, receipt, {}, owner, stable, availability, str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))
			return _check(bool(result.get("ok", false)), "real authenticated Motel command creates protected retirement history")
	facts["missing_command"] = {"id": command_id, "interactions": interactions}
	return _check(false, "authored initial Motel command is available")

func _protected(run: RunState) -> Dictionary:
	var raw := run.to_dict()
	var result: Dictionary = {}
	for key in ["bankroll", "grand_casino_chips", "debt", "inventory", "crew_state", "active_delivery_run", "numbers_state", "rng_seed", "rng_state", "game_clock_minutes", "story_log", "run_spending_score", "run_status"]:
		result[key] = raw.get(key)
	return result

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _differences(before: Variant, after: Variant, path: String = "run") -> Array:
	var result: Array = []
	if typeof(before) != typeof(after):
		return [{"path": path, "before_type": type_string(typeof(before)), "after_type": type_string(typeof(after))}]
	if typeof(before) == TYPE_DICTIONARY:
		var keys: Array = before.keys()
		for key in after:
			if not keys.has(key): keys.append(key)
		for key in keys:
			if not before.has(key) or not after.has(key): result.append({"path": path + "/" + str(key), "kind": "missing_key"})
			else: result.append_array(_differences(before[key], after[key], path + "/" + str(key)))
			if result.size() >= 20: break
	elif typeof(before) == TYPE_ARRAY:
		if before.size() != after.size(): result.append({"path": path, "kind": "array_size", "before": before.size(), "after": after.size()})
		for index in range(mini(before.size(), after.size())):
			result.append_array(_differences(before[index], after[index], path + "/" + str(index)))
			if result.size() >= 20: break
	elif before != after:
		result.append({"path": path, "kind": "value", "before": before if typeof(before) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_NIL] else str(before).sha256_text(), "after": after if typeof(after) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_NIL] else str(after).sha256_text()})
	return result.slice(0, 20)

func _finish() -> void:
	facts["source_sha256"] = {"generator": FileAccess.get_sha256("res://scripts/core/run_generator.gd"), "test": FileAccess.get_sha256("res://scripts/tests/scenario_venue_cycle_primed_check.gd")}
	var result := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("VENUE_CYCLE_PRIMED_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
