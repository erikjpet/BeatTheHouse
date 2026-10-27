extends SceneTree

# Synthetic presentation contract: the warning and the unchanged resolver must
# agree for the same cabinet/modifiers, without a preview spending any state.
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const ViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var checks := 0
var records: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	var content: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	var definition: Dictionary = {}
	for value in content:
		if str(value.get("id", "")) == "slot":
			definition = value
	_expect(not definition.is_empty(), "slot definition is available")
	if definition.is_empty():
		_finish()
		return
	var game := SlotGameScript.new()
	game.setup(definition)
	for options in [
		{"id": "normal", "watched": false, "heat": 12},
		{"id": "watched", "heat": 42},
		{"id": "turned_away", "turns": 2, "heat": 12},
		{"id": "off_floor", "off_floor": 1, "heat": 12},
		{"id": "security", "suspicion": 60, "heat": 47},
		{"id": "alcohol", "drunk": 70, "heat": 55},
		{"id": "passive_reduction", "item": "cheap_sunglasses", "heat": 40},
		{"id": "passive_increase", "item": "foil_sleeve", "heat": 44},
		{"id": "cold_quarter", "cold": 10, "heat": 32},
		{"id": "grease_failure", "grease": true, "heat": 56},
		{"id": "grease_and_cold", "grease": true, "cold": 10, "heat": 46},
		{"id": "cold_zero", "cold": 60, "heat": 0},
	]:
		_check_case(game, library, definition, options)
	_check_fixture_projection(game, library, definition)
	var fallback := ViewModelScript.game_risk_summary(definition)
	_expect(fallback.contains("Base Heat") and fallback.contains("before modifiers"), "slot without a runtime preview labels authored Heat as base")
	# Games without a slot preview keep their existing authored risk copy.
	_expect(ViewModelScript.game_risk_summary({"cheat_actions": [{"summary": "Other game.", "suspicion_delta": 7}]}) == "Other game. Heat can rise by as much as 7.", "unrelated game copy is unchanged")
	_finish()


func _fixture(game: SlotGame, options: Dictionary) -> RunState:
	var run := RunStateScript.new()
	run.start_new("QA-UX012-%s" % str(options.get("id", "fixture")))
	run.bankroll = 1000
	if options.has("item"):
		run.add_item(str(options["item"]))
	run.suspicion = {"level": int(options.get("suspicion", 8))}
	run.drunk_level = int(options.get("drunk", 0))
	run.rourke_current_room = "grand_casino"
	run.rourke_off_floor_actions = int(options.get("off_floor", 0))
	var environment := {
		"id": "ux012_room", "archetype_id": "grand_casino", "kind": "casino",
		"game_ids": ["slot"], "game_states": {}, "turns": int(options.get("turns", 0)),
		"security_profile": {"pit_boss": {"enabled": bool(options.get("watched", true)), "label": "Rourke", "cheat_heat_bonus": 30, "cycle_length": 4, "watched_turns": 2}},
	}
	var machine: Dictionary = game.generator.build_machine_from_ids(game.definition, {"type_id": "pinball", "format_id": "classic_3_reel"}, run.create_rng("ux012_machine"))
	machine["last_nudge_offer"] = {
		"type": "coin_chain", "classification": "near_miss",
		"grid": machine.get("last_grid", []), "stops": machine.get("reel_stops", []),
		"coins": [{"ready_msec": 1000}], "skill_window_msec": {"start": 1300, "perfect": 1600, "end": 1900},
		"lucky_reel_grease_active": bool(options.get("grease", false)),
	}
	var cold := int(options.get("cold", 0))
	machine["slot_item_state"] = {"cold_quarters_charges": 2, "cold_quarter_heat_reduction": cold, "lucky_reel_grease_failed_nudge_heat_bonus": 14}
	StateScript.write_machine(environment, "slot", machine)
	run.current_environment = environment
	return run


func _risk(game: SlotGame, library: ContentLibrary, definition: Dictionary, run: RunState, count: int = 1) -> Array:
	var environment := run.current_environment
	var fixture_states := {}
	for index in range(count):
		var object_id := "game:slot" if index == 0 else "game:slot:%d" % (index + 1)
		var state_key := "slot" if index == 0 else "slot:%d" % (index + 1)
		fixture_states[object_id] = game.environment_object_state_for_state_key(run, environment, state_key)
	return ViewModelScript.interactable_object_view_list(run, library, {
		"game_sources": [{"id": "slot", "definition": definition, "object_state": game.environment_object_state(run, environment), "fixture_object_states": fixture_states}],
		"layout": {"game_fixture_counts": {"slot": count}},
	})


func _check_case(game: SlotGame, library: ContentLibrary, definition: Dictionary, options: Dictionary) -> void:
	var label := str(options.get("id", ""))
	var run := _fixture(game, options)
	var before := JSON.stringify(run.to_dict())
	var rows := _risk(game, library, definition, run)
	var risk := str(rows[0].get("risk_summary", "")) if not rows.is_empty() else ""
	var expected := int(options.get("heat", 0))
	_expect(_has_heat(risk, expected), "%s warning forecasts %d: %s" % [label, expected, risk])
	_expect(JSON.stringify(run.to_dict()) == before, "%s projection preserves all serialized state/RNG" % label)
	_expect(str(_risk(game, library, definition, run)[0].get("risk_summary", "")) == risk, "%s repeated projection is stable" % label)
	_expect(JSON.stringify(run.to_dict()) == before, "%s repeated projection spends no charges" % label)
	var environment := run.current_environment
	var resolved: Dictionary = game.resolver.resolve_spin(FunctionOptions.SlotResolveOptions.from({
		"machine": StateScript.read_machine(environment, "slot"), "action_id": "nudge",
		"selected_bet": StateScript.selected_bet(StateScript.read_machine(environment, "slot")),
		"rng": run.create_rng("ux012_resolve"), "definition": definition, "environment": environment,
		"run_state": run, "item_effects": game._slot_cross_game_item_effects(run, StateScript.read_machine(environment, "slot"), true),
		"ui_state": {"slot_nudge_chain_input_msec": 0},
	}))
	var result: Dictionary = resolved.get("result", {})
	_expect(bool(result.get("ok", false)), "%s normal resolver accepts synthetic pending nudge" % label)
	_expect(int(result.get("suspicion_delta", -1)) == expected, "%s unchanged resolver applies %d" % [label, expected])
	records.append({"case": label, "risk_summary": risk, "expected_heat": expected, "receipt_heat": result.get("suspicion_delta"), "base_heat": result.get("base_suspicion_delta"), "pit_boss_watched": result.get("pit_boss_watched")})


func _check_fixture_projection(game: SlotGame, library: ContentLibrary, definition: Dictionary) -> void:
	var run := _fixture(game, {})
	var second: Dictionary = StateScript.read_machine(run.current_environment, "slot")
	second["last_nudge_offer"]["lucky_reel_grease_active"] = true
	StateScript.write_machine(run.current_environment, "slot:2", second)
	var rows := _risk(game, library, definition, run, 2)
	_expect(rows.size() == 2 and _has_heat(str(rows[0].get("risk_summary", "")), 42) and _has_heat(str(rows[1].get("risk_summary", "")), 56), "each cabinet uses its own pending offer/item state")
	var save := SaveServiceScript.new()
	_expect(save.save_run(run, "ux012") == OK, "synthetic fixture saves through normal SaveService")
	var restored: Variant = SaveServiceScript.new().load_run("ux012")
	_expect(restored != null, "synthetic fixture cold loads through normal SaveService")
	if restored != null:
		var reloaded := _risk(game, library, definition, restored, 2)
		_expect(reloaded.size() == 2 and _has_heat(str(reloaded[0].get("risk_summary", "")), 42) and _has_heat(str(reloaded[1].get("risk_summary", "")), 56), "cold load preserves per-cabinet warning")


func _has_heat(text: String, expected: int) -> bool:
	return text.contains("as much as %d per nudge" % expected) if expected > 0 else text.contains("no Heat")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "cases": records, "fidelity": "Synthetic native projection and direct authoritative resolver; no player profile or rendered gameplay."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("SLOT_NUDGE_RISK_PREVIEW checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
