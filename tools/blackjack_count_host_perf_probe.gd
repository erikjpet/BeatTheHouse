extends SceneTree

const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const AuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run: RunState = RunStateScript.new()
	run.start_new("BLACKJACK-COUNT-HOST-PERF")
	# A late-run shaped history makes an accidental whole-run clone measurable.
	for index in range(1800):
		run.story_log.append({"type": "fixture", "index": index, "detail": "bounded host performance history"})
	var environment := {
		"id": "blackjack_count_perf_room",
		"archetype_id": "small_underground_casino",
		"world_node_id": "small_underground_casino",
		"display_name": "Count Performance Table",
		"game_states": {},
	}
	run.current_environment = environment
	var game: BlackjackGame = BlackjackScript.new()
	game.setup({"id": "blackjack", "display_name": "Blackjack", "full_simulation": true})
	var table := game.generate_environment_state(run, environment, run.create_rng("count_perf_table"))
	(environment.get("game_states", {}) as Dictionary)["blackjack"] = table

	var host = FoundationMainScript.new()
	host.run_state = run
	host.current_game = game
	host.current_game_state_key = "blackjack"
	host.game_module_cache = {"blackjack": game}
	host.selected_stake = 5
	if not bool(host.call("_sealed_action_host_in_place_session_intent_allowed", "blackjack_count_icon")):
		_fail(host, game, "Count pulses were not admitted to the session-only host path.")
		return
	if bool(host.call("_sealed_action_host_in_place_session_intent_allowed", "blackjack_deal")):
		_fail(host, game, "An economic Blackjack action entered the session-only host path.")
		return
	if not bool(host.call("_sealed_action_host_normalize_environment_turn", {}, "count_cards")) or bool(host.call("_sealed_action_host_normalize_environment_turn", {}, "play_basic")):
		_fail(host, game, "Blackjack count recording did not own the exact no-extra-environment-turn declaration.")
		return
	var ledger: Dictionary = host.call("_sealed_action_host_ledger", run, true)
	var now := 20000
	var icons: Array = []
	for index in range(48):
		icons.append({
			"id": "perf:%d" % index,
			"count_value": 1 if index % 2 == 0 else -1,
			"spawn_msec": now - 10,
			"duration_msec": 5000,
			"x": 200 + index,
			"y": 180,
		})
	var session := {
		"selected_stake": 5,
		"counting_enabled": true,
		"count_attempted": true,
		"count_answered": false,
		"count_delta": 0,
		"cheats_used": {"count_cards": true},
		"count_challenge": {
			"challenge_id": "count_host_perf",
			"cards": [],
			"icons": icons,
			"tracked_card_keys": [],
			"icon_serial": icons.size(),
			"clicked_icons": [],
			"missed_icons": [],
			"resolved_icon_msec": {},
			"bad_hits": 0,
			"correct_hits": 0,
			"target_delta": 0,
			"recorded_delta": 0,
			"started_msec": now - 20,
		},
	}
	ledger = AuthorityScript.stage_session_cow(ledger, session)
	host.call("_sealed_action_host_store_ledger", run, ledger)

	var started_usec := Time.get_ticks_usec()
	var last_command: Dictionary = {}
	for index in range(icons.size()):
		var command: Dictionary = host.call("_sealed_action_host_surface_intent", "blackjack_count_icon", index, false, now)
		last_command = command
		if not bool(command.get("handled", false)):
			_fail(host, game, "Count pulse %d was rejected by the session-only host path: %s" % [index, JSON.stringify(command)])
			return
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var final_ledger: Dictionary = host.call("_sealed_action_host_ledger", run, false)
	var final_session: Dictionary = final_ledger.get("session", {})
	var clicked: Array = (final_session.get("count_challenge", {}) as Dictionary).get("clicked_icons", [])
	if clicked.size() != icons.size():
		_fail(host, game, "Session-only host lost count claims: expected %d, got %d." % [icons.size(), clicked.size()])
		return
	if typeof(last_command.get("surface_state_patch", null)) != TYPE_DICTIONARY:
		_fail(host, game, "Count pulse claim did not return the lightweight canvas patch that avoids a full UI refresh.")
		return
	# This is deliberately generous for loaded CI machines. The old detached path
	# scales with the 1,800-entry run and exceeds this budget by orders of magnitude.
	if elapsed_usec > 250000:
		_fail(host, game, "Claiming 48 count pulses took %.2f ms; expected <=250 ms without whole-run cloning." % (float(elapsed_usec) / 1000.0))
		return
	print("BLACKJACK_COUNT_HOST_PERF_PROBE_PASS elapsed_ms=%.2f claims=%d" % [float(elapsed_usec) / 1000.0, clicked.size()])
	host.free()
	game = null
	quit(0)


func _fail(host, game: BlackjackGame, message: String) -> void:
	push_error(message)
	host.free()
	game = null
	quit(1)
