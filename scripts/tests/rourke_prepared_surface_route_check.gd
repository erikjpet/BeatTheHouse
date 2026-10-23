extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures: Array[String] = []

class LegacyHost extends "res://scripts/ui/sealed_action_host.gd":
	func _sealed_action_host_evidence_fingerprint(evidence: Dictionary, _candidate: RunState) -> String:
		return Runtime.canonical_fingerprint(evidence)

class ScenarioRun extends RunState:
	func scenario_sequence_present() -> bool:
		return true

class ObservedMain extends Main:
	var legacy_route := false
	var selections := 0
	var prepared_direct := 0
	var input_clock := 100000
	var stand_usec := 0

	func _current_game_surface_input_time_msec() -> int:
		return input_clock

	func select_game_action(action_id: String, action_kind: String, input_route_guarded: bool = false) -> void:
		selections += 1
		super.select_game_action(action_id, action_kind, input_route_guarded)

	func _apply_game_surface_command(command: Dictionary, index: int = -1, confirm_requested: bool = false, notify_coach: bool = true, input_route_guarded: bool = false) -> bool:
		if command.has("_sealed_action_host_prepared") and bool(command.get("direct_resolve", false)):
			prepared_direct += 1
			if legacy_route:
				command = command.duplicate(false)
				command["direct_resolve"] = false
				command.erase("set_stake")
		return super._apply_game_surface_command(command, index, confirm_requested, notify_coach, input_route_guarded)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		quit(2)
		return
	var current := await _hand(false)
	var legacy := await _hand(true)
	_check(current.snapshot == legacy.snapshot, "complete public state, RNG, balances and table match generic selection route")
	_check(current.authority == legacy.authority, "native proposal encoding preserves exact authority ledger and receipts")
	_check(current.selections == 0 and legacy.selections == 1, "only duplicate generic selection is removed")
	_check(current.prepared_direct == 1 and legacy.prepared_direct == 1, "published settlement uses a prepared sealed delivery")
	_check(current.stacks == [112, 95] and legacy.stacks == current.stacks, "real fixture closes first duel hand once")
	_check_scope()
	print("ROURKE_PREPARED_SURFACE_ROUTE ", JSON.stringify({"current_usec": current.usec, "legacy_usec": legacy.usec, "current_selections": current.selections, "legacy_selections": legacy.selections, "stacks": current.stacks}))
	for message in failures: push_error(message)
	print("ROURKE_PREPARED_SURFACE_ROUTE_CHECK ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _hand(legacy: bool) -> Dictionary:
	var app := ObservedMain.new()
	app.legacy_route = legacy
	root.add_child(app)
	if legacy: app._sealed_action_host = LegacyHost.new(app)
	app.continuous_environment_clock_enabled = false
	app._ensure_run_ui_built()
	var destination: String = app.save_service.run_save_path(app.autosave_slot_id)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	_check(app.load_foundation_run(), "real fixture loads through production save path")
	if app.current_game == null:
		_check(app.activate_interactable_object("game:blackjack"), "real Back Room table enters")
	app._on_game_surface_action("blackjack_deal", 0)
	await process_frame
	await process_frame
	app.input_clock += 5000
	var started := Time.get_ticks_usec()
	app._on_game_surface_action("blackjack_stand", 0)
	var elapsed := Time.get_ticks_usec() - started
	var snapshot: Dictionary = app.run_state.to_save_snapshot().duplicate(true)
	var ledger: Dictionary = snapshot.current_environment.game_states.blackjack.get(Authority.LEDGER_KEY, {})
	var authority := Runtime.canonical_json(ledger)
	_strip_metadata(snapshot)
	var crew: Dictionary = snapshot.get("crew_state", {})
	crew.erase("a")
	crew.erase("z")
	var duel: Dictionary = app.run_state.grand_casino_duel_status()
	var result := {"snapshot": Runtime.canonical_json(snapshot), "authority": authority, "selections": app.selections, "prepared_direct": app.prepared_direct, "usec": elapsed, "stacks": [duel.get("player_stack"), duel.get("rourke_stack")]}
	app.free()
	await process_frame
	return result

func _check_scope() -> void:
	var game := Blackjack.new()
	var run := RunState.new()
	run.current_environment = {"local_narrative_flags": {"blackjack_boss_variant": "rourke_duel"}}
	_check(game._blackjack_prepared_direct_resolve_allowed(run, "play_basic"), "prepared route opts into the Rourke room")
	_check(not game._blackjack_prepared_direct_resolve_allowed(run, "crew_play:probe"), "Crew actions retain conservative route")
	_check(not game._blackjack_prepared_direct_resolve_allowed(run, "peek_hole_card"), "only completed-hand settlement opts into direct preparation")
	run.challenge_config = {"tutorial": true}
	_check(not game._blackjack_prepared_direct_resolve_allowed(run, "play_basic"), "tutorials retain conservative route")
	run.challenge_config = {}
	run.current_environment = {}
	_check(not game._blackjack_prepared_direct_resolve_allowed(run, "play_basic"), "ordinary tables retain existing route")
	var scenario := ScenarioRun.new()
	scenario.current_environment = {"local_narrative_flags": {"blackjack_boss_variant": "rourke_duel"}}
	_check(not game._blackjack_prepared_direct_resolve_allowed(scenario, "play_basic"), "scenario-bound tables retain conservative route")
	_check(not game._blackjack_prepared_direct_resolve_allowed(null, "play_basic"), "missing candidate fails closed")

func _strip_metadata(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in [Authority.LEDGER_KEY, Authority.PENDING_APPLY_RECEIPT_KEY, "environment_runtime_revision"]: value.erase(key)
		for key in value: _strip_metadata(value[key])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _strip_metadata(child)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
