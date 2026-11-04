extends "res://scripts/tests/back_alley_travel_binding_check.gd"

# Genuine closed R03 snapshot, supplied locally with its authority companions.
# Normal Continue -> Map -> Motel -> one confirmation. No fixture clock/history
# edits. Synthetic negative siblings never enter the player's captured bundle.
class MotelObserver extends RunGenerator:
	var attempts := 0
	var before_lazy: Dictionary = {}
	var install: Dictionary = {}
	func _init(content: ContentLibrary) -> void: super(content)
	func _world_environment_data_for_node(run: RunState, map: Dictionary, node: Dictionary, rng: RngStream, options: Dictionary = {}) -> Dictionary:
		if str(node.get("id", "")) == "motel":
			var room: Dictionary = node.get("environment", {})
			var selection := run.environment_situation_cycle("motel")
			before_lazy = {"room_scenario": room.get("scenario_id", ""), "room_cycle": room.get("environment_situation_cycle_id", ""), "selection": {"cycle_id": selection.get("cycle_id", ""), "phase": selection.get("phase", ""), "scenario_id": selection.get("scenario_id", ""), "history_count": selection.get("history", {}).size()}, "seeded_id": run._seeded_scenario_definition_for_node_readonly("motel").get("id", "")}
		return super._world_environment_data_for_node(run, map, node, rng, options)
	func _trusted_scenario_install_data(run: RunState, room: Dictionary) -> Dictionary:
		attempts += 1
		var result := super._trusted_scenario_install_data(run, room)
		install = {"scenario_id": room.get("scenario_id", ""), "cycle": room.get("environment_situation_cycle_id", ""), "seeded_id": run._seeded_scenario_definition_for_node_readonly("motel").get("id", ""), "ok": result.get("ok", false), "errors": result.get("errors", [])}
		return result

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-") and ProjectSettings.globalize_path("user://").contains("native-private-"), "explicit isolated native storage required"):
		_finish(); return
	var cold := OS.get_environment("BTH_MOTEL_COLD") == "1"
	if not cold: _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	if not failures.is_empty(): _finish(); return
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official captured save and companion authority load"):
		_finish(); return
	facts = {"id": "BTH-TRAVEL-MOTEL-SEED-001", "fidelity": "Genuine captured R03; normal native Host Continue and one quoted Map confirmation; continuous clock frozen for deterministic observation", "mode": "cold" if cold else "warm", "initial": _public_run_facts(baseline)}
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal Host Continue"):
		await _close(app); _finish(); return
	var run: RunState = app.run_state
	if cold:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_MOTEL_EXPECTED"))).get("facts", {}).get("cold_expected", {})
		_check(not expected.is_empty(), "independent cold expectation exists")
		var actual := _motel_expectation(run)
		facts["cold_differences"] = _different_paths(expected, actual)
		_check(_persistent_fingerprint(expected) == _persistent_fingerprint(actual) and facts.cold_differences.is_empty(), "cold Continue preserves complete guarded values cycle history and room machines without a second trip")
		_motel_controls(app, "cold")
		facts["final"] = _public_run_facts(run)
		await _close(app); _finish(); return
	_check(_persistent_fingerprint(_protected(baseline)) == _persistent_fingerprint(_protected(run)), "Continue preserves captured protected gameplay")
	if not _check(run.current_world_node_id() == "jazz_club" and run.bankroll == 48, "captured checkpoint is Jazz with48 cash"):
		facts["source_id"] = run.current_world_node_id(); await _close(app); _finish(); return
	var observer := MotelObserver.new(app.library)
	app.generator = observer
	_check(app.open_world_map(), "normal Map opens")
	_check(app.select_world_map_node("motel"), "normal Motel selection")
	var quote: Dictionary = app._travel_choice("motel").duplicate(true)
	facts["quote"] = _public_quote(quote)
	if not _check(bool(quote.get("enabled", false)) and int(quote.get("cost", -1)) == 3 and int(quote.get("travel_minutes", -1)) == 24, "ordinary OPEN Motel3 bus24min quote"):
		await _close(app); _finish(); return
	var before := run.to_dict().duplicate(true)
	var before_history := _persistent_fingerprint(_motel_prior_outcomes(run))
	var story_start := run.story_log.size()
	var result: Dictionary = app.confirm_world_map_travel()
	facts["confirmations"] = 1
	facts["travel"] = {"ok": result.get("ok", false), "errors": result.get("errors", [])}
	facts["before_lazy"] = observer.before_lazy
	facts["install"] = observer.install
	facts["install_attempts"] = observer.attempts
	if not bool(result.get("ok", false)):
		facts["no_charge"] = {"cash_before": before.bankroll, "cash_after": run.bankroll, "clock_before": before.game_clock_minutes, "clock_after": run.game_clock_minutes, "full_snapshot_unchanged": _persistent_fingerprint(before) == _persistent_fingerprint(run.to_dict())}
		_check(facts.no_charge.full_snapshot_unchanged, "rejected trip preserves full serialized run including fare clock RNG and room")
		_check(false, "captured Jazz to Motel first trip succeeds")
		await _close(app); _finish(); return
	run = app.run_state
	_check(observer.attempts == 1 and bool(observer.install.get("ok", false)), "first destination install succeeds without suppression retry")
	_check(run.current_world_node_id() == "motel", "one confirmation reaches Motel")
	_check(run.game_clock_minutes == int(before.game_clock_minutes) + int(quote.travel_minutes), "quoted24min charged once")
	var travel_rows: Array = []
	var risk_rows: Array = []
	for row in run.story_log.slice(story_start):
		if str(row.get("type", "")) == "travel" and str(row.get("id", "")) == "motel": travel_rows.append(row)
		if str(row.get("type", "")) == "travel_risk_event" and str(row.get("route_id", "")) == "motel": risk_rows.append(row)
	_check(travel_rows.size() == 1, "exactly one accepted travel receipt")
	if not travel_rows.is_empty():
		var paid: Dictionary = travel_rows[0]
		var risk: Dictionary = paid.get("route_risk", {})
		var delta := int(risk.get("bankroll_delta", 0)) if bool(risk.get("triggered", false)) else 0
		_check(int(paid.get("route_cost", -1)) == 3 and run.bankroll == int(before.bankroll) - 3 + delta, "cash reflects one quoted3 fare and only the genuine route risk")
		_check(risk_rows.size() == (1 if bool(risk.get("triggered", false)) else 0), "route risk receipt at most once")
		facts["settlement"] = {"fare": paid.get("route_cost", 0), "cash": run.bankroll, "risk": risk, "travel_receipts": travel_rows.size(), "risk_receipts": risk_rows.size()}
	_check(_persistent_fingerprint(_motel_prior_outcomes(run)) == before_history, "prior refusal garment Silas inventory and Crew outcomes never replay or disappear")
	_motel_controls(app, "arrival")
	var expectation := _motel_expectation(run)
	for repeat in range(2): app._prepare_room_presentation_at_boundary()
	_check(_persistent_fingerprint(_motel_expectation(run)) == _persistent_fingerprint(expectation), "repeated publication preserves economy and retired history")
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Main Menu after explicit Save")
	app.save_service = SaveService.new()
	if _check(app.load_foundation_run(), "fresh SaveService Continue"):
		_check(_persistent_fingerprint(_motel_expectation(app.run_state)) == _persistent_fingerprint(expectation), "Save Continue preserves guarded state cycle history and machines")
		_motel_controls(app, "Save Continue")
	facts["cold_expected"] = _motel_expectation(app.run_state)
	facts["final"] = _public_run_facts(app.run_state)
	await _close(app)
	_finish()

func _motel_prior_outcomes(run: RunState) -> Dictionary:
	var snapshot := run.to_dict()
	var story: Array = []
	for row in run.story_log:
		if str(row.get("type", "")) not in ["travel", "travel_risk_event"]: story.append(row)
	return {"inventory": snapshot.get("inventory"), "debt": snapshot.get("debt"), "crew_state": snapshot.get("crew_state"), "active_delivery_run": snapshot.get("active_delivery_run"), "story": story}

func _motel_expectation(run: RunState) -> Dictionary:
	return {"public": _public_run_facts(run), "guard_digest": _persistent_fingerprint(_protected(run)), "cycle": run.environment_situation_cycle("motel").duplicate(true), "machines_digest": _persistent_fingerprint(run.current_environment.get("game_states", {}))}

func _motel_controls(app: Host, label: String) -> void:
	var run: RunState = app.run_state
	_check(bool(run.validate_room_action_authority().get("ok", false)), "%s strict Motel room authority" % label)
	_check(not app._interactable_object_view_list().is_empty() and not _has_room_unavailable(app), "%s populated usable Motel controls" % label)
	_check(str(run.current_environment.get("scenario_id", "")).is_empty() and run.scenario_sequence_projection().is_empty(), "%s deadzone has no live prior-cycle scenario" % label)
	_check(str(run.environment_situation_cycle("motel").get("phase", "")) == "closed", "%s lifecycle closed while24h access remains open" % label)
	facts[label + "_history_count"] = run.environment_situation_cycle("motel").get("history", {}).size()
	var before := _motel_expectation(run)
	_check(app.activate_interactable_object("travel:leave") and app.world_map_overlay != null and app.world_map_overlay.visible, "%s normal Leave opens Map" % label)
	_check(_persistent_fingerprint(before) == _persistent_fingerprint(_motel_expectation(run)), "%s Leave does not charge or replay outcomes" % label)
	app.close_world_map()

func _finish() -> void:
	facts["source_sha256"] = {}
	for name in ["scripts/core/run_generator.gd", "scripts/core/scenario_venue_cycle.gd", "scripts/ui/foundation_main.gd", "scripts/tests/motel_seed_captured_travel_check.gd"]:
		facts.source_sha256[name] = FileAccess.get_sha256("res://" + name)
	var receipt := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt, "  ")); file.close()
	print("MOTEL_SEED_CAPTURED ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
