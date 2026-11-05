extends SceneTree

# Ordinary owned practice launcher plus maintained production-authority adapter.
# No Deal, outcome, wager funding, original profile, save or cold replay occurs.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")

# The bounded fixture uses start_game_test_session's synchronous UI builder.
# Do not leave the optional start-menu coroutine awaiting after host cleanup.
class PracticeHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void: pass

var checks := 0
var failures: Array[String] = []
var rows: Array = []
var fixture_facts: Array = []
var app: Variant
var protected: Dictionary = {}
var baseline := false
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	if not _private_root(): _finish(); return
	app = PracticeHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	var opened: Dictionary = app.start_game_test_session("blackjack")
	if not _check(bool(opened.get("ok", false)), "ordinary practice launcher opens Blackjack"): _finish(); return
	var view := _view()
	_check(app.run_state.bankroll == 100000 and app.run_state.grand_casino_chips == 0 and int(view.get("shoe_remaining", 0)) == 312, "ordinary practice starts cash100000 chips0 and generated full312-card shoe")
	_check(int(view.get("selected_stake", 0)) == 1 and int(view.get("stake_ceiling", 0)) == 200, "public practice terms are main1 and maximum200")
	protected = _protected()
	var pp := _side_index(view.get("side_bets_available", []), "perfect_pairs")
	var buster := _side_index(view.get("side_bets_available", []), "buster")
	if not _check(pp >= 0 and buster >= 0, "generated table offers Perfect Pairs and Buster"): _finish(); return
	_step("blackjack_side_bet", pp, 2, not baseline)
	_step("blackjack_side_bet", buster, 3, not baseline)
	_step("blackjack_clear_bet", 0, 1, not baseline)
	_step("blackjack_undo_bet", 0, 3, not baseline)
	_step("blackjack_clear_bet", 0, 1, not baseline)
	_step("blackjack_max_bet", 0, 200, not baseline)
	_step("blackjack_undo_bet", 0, 1, true)
	if not baseline:
		_step("blackjack_chip", 0, 2)
		_step("blackjack_correct_bet", 1, 5)
		_step("blackjack_remove_chip", 0, 4)
		_step("blackjack_undo_bet", 0, 5)
		_step("blackjack_clear_bet", 0, 1)
		_step("blackjack_patron_bet", 0)
		var risk := int(_view().get("total_wager_cost", 0))
		_step("blackjack_chip", 999, risk)
		_step("blackjack_side_bet", 999, risk)
		_step("blackjack_repeat_bet", 0, risk)
		_detached_commands()
	_check(_protected() == protected, "complete sequence leaves money shoe RNG clocks and history exact")
	completed = true
	_finish()


func _step(action: String, index: int, expected_risk: int = -1, check_notice: bool = true) -> void:
	var command := Driver.surface_intent(app.current_game, action, int(_view().get("selected_stake", 1)), app.run_state, app.run_state.current_environment, index, false, 100000)
	if command.has("set_stake"): app.selected_stake = int(command.set_stake)
	var view := _view()
	_check(bool(command.get("handled", false)) and not bool(command.get("resolve", false)) and not command.has("_sealed_action_host_delivery"), action + " remains an unfunded ordinary draft command")
	if expected_risk >= 0: _check(int(view.get("total_wager_cost", -1)) == expected_risk, action + " public total risk matches current draft")
	if check_notice: _check(str(view.get("table_notice", "")) == str(command.get("message", "")), action + " persistent public banner matches latest command rather than stale Buster risk")
	_check(_protected() == protected, action + " changes no cash chips shoe RNG clock or history")
	var before := Runtime.content_fingerprint(app.run_state.to_dict())
	for repeat in range(3): _view()
	_check(Runtime.content_fingerprint(app.run_state.to_dict()) == before, action + " repeated public projection cannot mutate full run")
	rows.append({"action": action, "main": view.get("selected_stake", 0), "risk": view.get("total_wager_cost", 0), "side_bets": view.get("side_bets_active", []), "notice": view.get("table_notice", ""), "command_message": command.get("message", "")})


func _detached_commands() -> void:
	# Command/presentation-only fixtures; these are not authenticated live hands,
	# resolved wagers, or evidence that a card outcome occurred. Never publish.
	var run := RunState.new()
	run.from_dict(app.run_state.to_dict())
	var key: String = app.current_game_state_key if not str(app.current_game_state_key).is_empty() else "blackjack"
	var table := _table().duplicate(true)
	table.erase(Authority.LEDGER_KEY)
	table["last_result"] = {"main_stake": 5, "side_bet_ids": [], "summary": "Previous completed result."}
	run.current_environment["game_states"][key] = table
	var game: GameModule = app.current_game
	var stale := {"selected_stake": 1, "table_notice": "Buster added. Total risk $3."}
	var before := Runtime.content_fingerprint(run.to_dict())
	for action in ["blackjack_repeat_bet", "blackjack_rebet"]:
		var command := game.surface_action_command(action, 0, false, stale.duplicate(true), run, run.current_environment)
		_check(int(command.get("set_stake", 0)) == 5 and str(command.get("ui_state", {}).get("table_notice", "")) == str(command.get("message", "")), action + " successful command refreshes its stored notice")
		var view := game.surface_state(run, run.current_environment, command.get("ui_state", {}))
		_check(str(view.get("table_notice", "")) == "Previous completed result.", action + " existing between-hands result-summary projection is preserved")
	var live := {"selected_stake": 5, "player_hands": [{"cards": [{"rank": 7, "suit": "clubs"}, {"rank": 6, "suit": "spades"}], "stood": false}], "dealer_cards": [{"rank": 14, "suit": "hearts"}, {"rank": 5, "suit": "clubs"}], "wager_debited": true, "table_notice": "Choose HIT or STAND.", "count_live_notice": "Count remains visible."}
	for action in ["blackjack_chip", "blackjack_clear_bet", "blackjack_max_bet"]:
		var command := game.surface_action_command(action, 0, false, live.duplicate(true), run, run.current_environment)
		_check(str(command.get("message", "")) == "Main bets are locked until the hand settles." and str(command.get("ui_state", {}).get("table_notice", "")) == str(command.get("message", "")), action + " live-hand guard retains exact existing message path")
		_check(int(command.get("ui_state", {}).get("selected_stake", 0)) == 5, action + " live guard cannot edit main wager")
	var insurance := _side_index(game.surface_state(run, run.current_environment, live).get("side_bets_available", []), "insurance")
	_check(insurance >= 0, "synthetic dealer-Ace presentation retains existing Insurance offer")
	var insurance_ok := false
	if insurance >= 0:
		var command := game.surface_action_command("blackjack_side_bet", insurance, false, live.duplicate(true), run, run.current_environment)
		insurance_ok = _check((command.get("ui_state", {}).get("blackjack_side_bets", []) as Array).has("insurance") and str(command.get("message", "")).begins_with("Insurance added."), "live Insurance retains original side-bet message and selection path")
	var count_session := {"table_notice": "Bet cleared to the table minimum.", "count_live_notice": "Count remains visible."}
	var count_ok := _check(game.call("_table_notice_for_session", count_session, table) == "Count remains visible. Bet cleared to the table minimum.", "count live notice composes with fresh draft notice")
	_check(Runtime.content_fingerprint(run.to_dict()) == before, "detached command and presentation fixtures preserve entire synthetic run")
	fixture_facts.append({"scope": "detached commands only", "successful_repeat_rebet": true, "live_main_guards": true, "insurance_and_count_composition": insurance_ok and count_ok, "published": false})


func _view() -> Dictionary: return app.current_game.surface_state(app.run_state, app.run_state.current_environment, {"selected_stake": app.selected_stake, "surface_time_msec": 100000})
func _table() -> Dictionary: return app.current_game.call("_table_state_preview", app.run_state, app.run_state.current_environment)
func _side_index(available: Array, id: String) -> int:
	for index in range(available.size()):
		if str(available[index].get("id", "")) == id: return index
	return -1
func _protected() -> Dictionary:
	var run: RunState = app.run_state
	var table := _table()
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "history": run.story_log.duplicate(true), "shoe": table.get("shoe", []).duplicate(true), "shoe_remaining": table.get("shoe_remaining", 0), "hands_played": table.get("hands_played", 0), "last_result": table.get("last_result", {}).duplicate(true)}
func _private_root() -> bool:
	var root_path := OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(root_path.is_absolute_path() and "native-private-" in root_path, "explicit owned disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == root_path or path.begins_with(root_path + "/"), "private containment: " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no original player save or browser profile accepted")
func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
func _finish() -> void:
	_check(completed, "bounded requested sequence reaches final assertion")
	var report := {"id": "BTH-BLACKJACK-DRAFT-RISK-NOTICE-001", "alias": "OBS-R12-BJ-STALE-DRAFT-NOTICE-1005", "mode": "baseline" if baseline else "final", "checks": checks, "failures": failures, "sequence": rows, "fixtures": fixture_facts, "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/blackjack.gd"), "driver": FileAccess.get_sha256("res://scripts/tests/foundation/blackjack_authority_test_driver.gd"), "test": FileAccess.get_sha256("res://scripts/tests/blackjack_draft_risk_notice_check.gd")}, "fidelity": "Owned ordinary Foundation practice launcher and unchanged maintained Driver.surface_intent; no Deal, payment, outcome, original save or Web input. Extra Repeat/Rebet/live/Insurance/count cases are detached command/presentation fixtures only. No fabricated sealed record is supplied."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	if app != null:
		if app.save_service != null: app.save_service.wait_for_async_save()
		if app.get_parent() != null: app.get_parent().remove_child(app)
		app.free()
	print("BLACKJACK_DRAFT_RISK_NOTICE_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
