extends RefCounted

# Permanent crew06_7 contract: explicit activation, physical presence/rank/context,
# bounded windows/costs, deterministic detection, persistence, and heat pressure.

const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const BaccaratScript := preload("res://scripts/games/baccarat.gd")
const CrewPlayModelScript := preload("res://scripts/core/crew_play_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


static func check(library: ContentLibrary, failures: Array) -> void:
	for failure in CrewPlayModelScript.validate_content(CrewStateModelScript.MEMBER_IDS):
		failures.append("Crew plays content: %s" % str(failure))
	_check_requirement_matrix(library, failures)
	_check_spotter_window_and_blackjack_seam(library, failures)
	_check_big_player_pair(library, failures)
	_check_distraction_and_grievance(library, failures)
	_check_chip_dump_conservation(library, failures)
	_check_table_flood_and_concurrency(library, failures)
	_check_detection_determinism(library, failures)
	_check_save_load_mid_window(library, failures)
	_check_heat_pressure(library, failures)


static func _check_requirement_matrix(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-REQUIREMENTS", ["crew_switch", "crew_velvet"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:spotter"):
		failures.append("Spotter surfaced below Made rank.")
	_make_made(run, ["crew_switch", "crew_velvet"])
	var available := _action_ids(blackjack.legal_actions(run, run.current_environment))
	if not available.has("crew_play:spotter") or not available.has("crew_play:distraction"):
		failures.append("Made, physically present Switch/Velvet did not expose their blackjack plays.")
	run.current_environment["crew_presence"] = [{"member_id": "crew_velvet", "rank": "made"}]
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:spotter"):
		failures.append("Spotter surfaced while Switch was absent from the production crew_presence field.")
	var baccarat := _module(BaccaratScript, library, "baccarat")
	if _action_ids(baccarat.legal_actions(run, run.current_environment)).has("crew_play:spotter"):
		failures.append("Spotter surfaced outside blackjack context.")
	if run.crew_member_present("crew_switch") or run.crew_present_member_ids() != ["crew_velvet"]:
		failures.append("Shared presence readers disagreed with authoritative environment crew_presence.")


static func _check_spotter_window_and_blackjack_seam(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-SPOTTER", ["crew_switch"])
	_make_made(run, ["crew_switch"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	var before_cash := run.bankroll
	var result := blackjack.resolve_with_context("crew_play:spotter", 5, run, run.current_environment, run.create_rng(), {})
	if not bool(result.get("ok", false)) or not run.crew_play_active("spotter") or run.bankroll != before_cash - 8:
		failures.append("Spotter did not activate explicitly with its visible $8 cut.")
	if run.crew_play_adjust_suspicion(20, "blackjack") != 13 \
		or run.crew_play_effect_int("spotter", "blackjack_count_tolerance", 0) != 1:
		failures.append("Spotter did not expose the blackjack suspicion/count-assist seam.")
	# The host advances the activation boundary after resolve; four subsequent
	# boundaries remain, then the effect closes exactly.
	run.advance_environment_turns(1)
	if int(_status(run, "spotter").get("remaining_boundaries", -1)) != 4:
		failures.append("Spotter did not publish four remaining action boundaries after activation.")
	run.advance_environment_turns(3)
	if not run.crew_play_active("spotter"):
		failures.append("Spotter ended before its fourth effect boundary.")
	run.advance_environment_turns(1)
	if run.crew_play_active("spotter") or run.crew_play_adjust_suspicion(20, "blackjack") != 20:
		failures.append("Spotter did not end exactly at the configured boundary.")
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:spotter"):
		failures.append("Spotter left a dead action button while Switch was cooling down.")


static func _check_big_player_pair(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-BIG-PLAYER", ["crew_switch", "crew_rook"])
	_make_made(run, ["crew_switch", "crew_rook"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:big_player"):
		failures.append("Big Player surfaced without Spotter active.")
	blackjack.resolve_with_context("crew_play:spotter", 5, run, run.current_environment, run.create_rng(), {})
	if not _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:big_player"):
		failures.append("Spotter did not unlock a second present Made member's Big Player call-in.")
	var result := blackjack.resolve_with_context("crew_play:big_player", 5, run, run.current_environment, run.create_rng(), {})
	var table := _table(run.current_environment, "blackjack")
	if not bool(result.get("ok", false)) or not bool(table.get("crew_pre_warmed", false)) \
		or int(table.get("running_count", 0)) < 3 or int(table.get("recorded_running_count", 0)) != int(table.get("running_count", 0)):
		failures.append("Big Player did not transfer the spotted state into a visible pre-warmed blackjack shoe.")


static func _check_distraction_and_grievance(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-DISTRACTION", ["crew_velvet"])
	_make_made(run, ["crew_velvet"])
	run.add_suspicion("fixture", 70, "fixture", true)
	var blackjack := _module(BlackjackScript, library, "blackjack")
	var result := blackjack.resolve_with_context("crew_play:distraction", 5, run, run.current_environment, run.create_rng(), {})
	if not bool(result.get("ok", false)) or run.suspicion_level() != 52:
		failures.append("Distraction did not apply its immediate local 18-point heat dump.")
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:distraction"):
		failures.append("Spent Distraction remained available in the compact action affordance.")
	run.add_suspicion("security_escalation", 13, "security", true, {"action_kind": "cheat"})
	var grievances := run.crew_grievances("crew_velvet")
	if grievances.size() != 1 or str((grievances[0] as Dictionary).get("kind", "")) != "distraction_heat_dumped":
		failures.append("A security threshold crossing while Velvet was spent did not write exactly one distraction grievance.")
	run.add_suspicion("second_escalation", 3, "security", true, {"action_kind": "cheat"})
	if run.crew_grievances("crew_velvet").size() != 1:
		failures.append("Distraction security liability wrote its grievance more than once.")


static func _check_chip_dump_conservation(library: ContentLibrary, failures: Array) -> void:
	var first := _run("CREW-PLAYS-CHIP-DUMP", ["crew_bishop"], "baccarat")
	_make_made(first, ["crew_bishop"])
	first.grand_casino_chips = 10
	var baccarat := _module(BaccaratScript, library, "baccarat")
	var before_total := first.bankroll + first.grand_casino_chips
	var result := baccarat.resolve_with_context("crew_play:chip_dump", 20, first, first.current_environment, first.create_rng(), {})
	if not bool(result.get("ok", false)) or first.bankroll != 54 or first.grand_casino_chips != 50 \
		or first.bankroll + first.grand_casino_chips != before_total - 6:
		failures.append("Chip Dump did not conserve player/member value minus the authored $6 fee.")
	var second := _run("CREW-PLAYS-CHIP-DUMP", ["crew_bishop"], "baccarat")
	_make_made(second, ["crew_bishop"])
	second.grand_casino_chips = 10
	var replay := baccarat.resolve_with_context("crew_play:chip_dump", 20, second, second.current_environment, second.create_rng(), {})
	if bool(result.get("crew_play_detected", false)) != bool(replay.get("crew_play_detected", false)) \
		or first.suspicion_level() != second.suspicion_level():
		failures.append("Chip Dump detection was not deterministic for the same seed/action sequence.")


static func _check_table_flood_and_concurrency(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-FLOOD", ["crew_rook", "crew_mags", "crew_switch"])
	_make_made(run, ["crew_rook", "crew_mags", "crew_switch"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	var result := blackjack.resolve_with_context("crew_play:table_flood", 5, run, run.current_environment, run.create_rng(), {})
	if not bool(result.get("ok", false)) or run.crew_play_adjust_detection_chance(50) != 30 \
		or _string_array(result.get("crew_play_member_ids", [])).size() != 2:
		failures.append("Table Flood did not require two present Made members or apply its 60% cheat-detection multiplier.")
	if _action_ids(blackjack.legal_actions(run, run.current_environment)).has("crew_play:spotter"):
		failures.append("The one-window concurrency cap allowed Spotter beside Table Flood.")
	var single := _run("CREW-PLAYS-FLOOD-SINGLE", ["crew_rook"])
	_make_made(single, ["crew_rook"])
	if _action_ids(blackjack.legal_actions(single, single.current_environment)).has("crew_play:table_flood"):
		failures.append("Table Flood surfaced with only one physically present member.")


static func _check_detection_determinism(library: ContentLibrary, failures: Array) -> void:
	var burned_seed := ""
	for index in range(1, 80):
		var seed := "CREW-SPOTTER-BURN-%d" % index
		var run := _watched_run(seed)
		_make_made(run, ["crew_switch"])
		var blackjack := _module(BlackjackScript, library, "blackjack")
		blackjack.resolve_with_context("crew_play:spotter", 5, run, run.current_environment, run.create_rng(), {})
		run.advance_environment_turns(1)
		if not run.crew_play_active("spotter"):
			burned_seed = seed
			break
	if burned_seed.is_empty():
		failures.append("Spotter's seeded watched-pit burn path was unreachable across 79 seeds.")
		return
	var hashes: Array = []
	for repeat in range(2):
		var replay := _watched_run(burned_seed)
		_make_made(replay, ["crew_switch"])
		var blackjack := _module(BlackjackScript, library, "blackjack")
		blackjack.resolve_with_context("crew_play:spotter", 5, replay, replay.current_environment, replay.create_rng(), {})
		replay.advance_environment_turns(1)
		hashes.append(JSON.stringify(replay.to_dict()).sha256_text())
	if hashes[0] != hashes[1]:
		failures.append("Spotter watched-pit detection replay diverged for the same seed.")


static func _check_save_load_mid_window(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-SAVE", ["crew_rook", "crew_mags"])
	_make_made(run, ["crew_rook", "crew_mags"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	blackjack.resolve_with_context("crew_play:table_flood", 5, run, run.current_environment, run.create_rng(), {})
	run.advance_environment_turns(1)
	var expected := run.crew_play_active_status("blackjack")
	var restored := RunStateScript.new()
	restored.from_dict(run.to_dict())
	if restored.crew_play_active_status("blackjack") != expected or restored.crew_play_adjust_detection_chance(50) != 30:
		failures.append("Save/load mid-window did not restore exact Table Flood state/effect.")
	var untouched := _run("CREW-PLAYS-UNTOUCHED", [])
	if (_dict(untouched.to_dict().get("crew_state", {}))).has("plays"):
		failures.append("An untouched run serialized neutral coordinated-play state.")


static func _check_heat_pressure(library: ContentLibrary, failures: Array) -> void:
	var run := _run("CREW-PLAYS-HEAT-PRESSURE", ["crew_switch"])
	_make_made(run, ["crew_switch"])
	var blackjack := _module(BlackjackScript, library, "blackjack")
	blackjack.resolve_with_context("crew_play:spotter", 5, run, run.current_environment, run.create_rng(), {})
	run.advance_environment_turns(1)
	for index in range(8):
		var pressure := run.crew_play_adjust_suspicion(12, "blackjack")
		run.add_suspicion("aggressive_fixture_%d" % index, pressure, "behavior", true, {"action_kind": "cheat"}, true)
		run.advance_environment_turns(1)
		if run.suspicion_level() >= 85:
			break
	if run.suspicion_level() < 85:
		failures.append("Sustained aggressive blackjack failed to reach severe heat despite spending the maximum Spotter relief window.")


static func _run(seed: String, present_members: Array, game_id: String = "blackjack") -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed)
	run.bankroll = 100
	var presence: Array = []
	for member_id in present_members:
		presence.append({"member_id": str(member_id), "rank": "made", "line": "fixture"})
	var table := {
		"schema": "blackjack_table_state" if game_id == "blackjack" else "baccarat_table_state",
		"running_count": 0,
		"recorded_running_count": 0,
	}
	run.set_environment({
		"id": "grand_casino_fixture",
		"archetype_id": "grand_casino",
		"world_node_id": "grand_casino",
		"kind": "casino",
		"active_game_id": game_id,
		"crew_presence": presence,
		"game_states": {game_id: table},
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 100},
		"security_profile": {"strictness": "high"},
		"turns": 0,
	})
	return run


static func _watched_run(seed: String) -> RunState:
	var run := _run(seed, ["crew_switch"])
	run.current_environment["security_profile"] = {
		"strictness": "boss",
		"pit_boss": {"enabled": true, "cycle_length": 4, "watched_turns": 4, "cheat_heat_bonus": 20},
	}
	run.rourke_current_room = "grand_casino"
	run.rourke_current_spot = "blackjack_pit"
	return run


static func _make_made(run: RunState, member_ids: Array) -> void:
	for member_id in member_ids:
		run.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "fixture")


static func _module(script: Script, library: ContentLibrary, game_id: String) -> GameModule:
	var module: GameModule = script.new()
	module.setup(library.game(game_id), library)
	return module


static func _status(run: RunState, play_id: String) -> Dictionary:
	for value in run.crew_play_active_status():
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("play_id", "")) == play_id:
			return value as Dictionary
	return {}


static func _table(environment: Dictionary, game_id: String) -> Dictionary:
	var states := _dict(environment.get("game_states", {}))
	return _dict(states.get(game_id, {}))


static func _action_ids(actions: Array) -> Array:
	var result: Array = []
	for value in actions:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(str((value as Dictionary).get("id", "")))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			result.append(str(entry))
	return result


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
