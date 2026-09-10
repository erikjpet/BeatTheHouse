extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const BlackjackAuthorityTestDriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition := library.game("blackjack")
	var module_script: Script = load(str(definition.get("module_path", "")))
	var game: GameModule = module_script.new()
	game.setup(definition, library)

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-MANUAL-COUNT-SETTLE")
	run_state.change_bankroll(1000)
	var environment := {
		"id": "blackjack_manual_count_settle_room",
		"archetype_id": "grand_casino",
		"display_name": "Manual Count Settlement Room",
		"depth": 3,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "low"},
	}
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("table"))
	var original_shoe: Array = table.get("shoe", [])
	var forced_opening: Array = [
		{"rank": 5, "suit": 0, "deck": 90},
		{"rank": 14, "suit": 1, "deck": 90},
		{"rank": 6, "suit": 2, "deck": 90},
		{"rank": 13, "suit": 3, "deck": 90},
	]
	forced_opening.append_array(original_shoe)
	table["shoe"] = forced_opening
	table["shoe_remaining"] = forced_opening.size()
	table["patrons"] = []
	table["counting_enabled"] = true
	environment["game_states"] = {"blackjack": table}
	run_state.current_environment = environment

	var deal := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_deal", 5, run_state, environment, 0, false, 10000)
	_check(str(deal.get("action_id", "")) == "blackjack_place_bet", "The visible Deal control did not issue its sealed wager action.")
	var dealt := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, deal, 5, run_state, run_state.current_environment)
	_check(bool(dealt.get("ok", false)), "The visible Deal control did not resolve through production authority: %s" % JSON.stringify(dealt))

	var preview := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_settle", 5, run_state, run_state.current_environment, 0, false, 12000)
	_check(bool(preview.get("handled", false)) and str(preview.get("action_id", "")).is_empty(), "The first visible Settle click did not stage the count reveal: %s" % JSON.stringify(preview))
	var session := _canonical_session(run_state.current_environment)
	_check(bool(session.get("settlement_count_revealed", false)), "The first visible Settle click did not persist the terminal count preview.")

	var challenge: Dictionary = session.get("count_challenge", {})
	var icons: Array = challenge.get("icons", [])
	for icon_index in range(icons.size()):
		var icon: Dictionary = icons[icon_index]
		var click_msec := int(icon.get("spawn_msec", 12000)) + 1
		var claim := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_count_icon", 5, run_state, run_state.current_environment, icon_index, false, click_msec)
		_check(bool(claim.get("handled", false)), "Count bubble %d was not selectable through the visible production route: %s" % [icon_index, JSON.stringify(claim)])

	session = _canonical_session(run_state.current_environment)
	var settle_msec := 12000
	for icon_value in (session.get("count_challenge", {}) as Dictionary).get("icons", []):
		if typeof(icon_value) == TYPE_DICTIONARY:
			settle_msec = maxi(settle_msec, int((icon_value as Dictionary).get("spawn_msec", 0)) + 2)
	var settle := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_settle", 5, run_state, run_state.current_environment, 0, false, settle_msec)
	_check(str(settle.get("action_id", "")) == "play_basic", "The visible Settle control did not issue the sealed hand resolution with counting on: %s" % JSON.stringify(settle))
	var result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, settle, 5, run_state, run_state.current_environment)
	_check(bool(result.get("ok", false)), "The visible Settle control did not resolve the counted hand: %s" % JSON.stringify(result))
	_check(not bool(game.call("_has_dealt_hand", _canonical_session(run_state.current_environment))), "The counted hand remained active after the visible Settle action.")

	if failures.is_empty():
		print("BLACKJACK_MANUAL_COUNT_SETTLE_PROBE_PASS icons=%d" % icons.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _canonical_session(environment: Dictionary) -> Dictionary:
	var table: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	var binding := "blackjack:%s:%s" % [str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding)
	return (ledger.get("session", {}) as Dictionary).duplicate(true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
