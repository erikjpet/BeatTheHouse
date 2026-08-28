extends SceneTree

const GameScript := preload("res://scripts/games/crew_draw_poker.gd")
const PokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const NIGHT_PATH := "res://data/games/rituals/crew06_10_poker_nights.json"
const MEMBER_IDS := ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]
const NIGHT_IDS := ["friendly_teaching", "hustle_test", "debt_court", "after_job", "raid_jitters"]

var failures: Array[String] = []


func _init() -> void:
	_check_night_package()
	var library := ContentLibrary.new()
	var load_report := library.load(false)
	if not bool(load_report.get("ok", false)) and library.game("crew_draw_poker").is_empty():
		failures.append("Content library could not load Crew Draw Poker.")
	else:
		_check_executable_nights(library)
		_check_profile_mechanics(library)
		_check_raise_and_fold_continuation(library)
		_check_interrupt_authority(library)
		_check_observation_restore_authority(library)
		_check_ordered_traces(library)
	if failures.is_empty():
		print("CREW06_10_DEPTH_CONTRACT PASS seeds=10 profiles=5 engine=ordered_v1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_night_package() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NIGHT_PATH))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1:
		failures.append("Poker-night package must be a one-record data array.")
		return
	var package: Dictionary = (parsed as Array)[0]
	if str(package.get("contract", "")) != "game_ritual/1" or str(package.get("contract_head", "")) != "a2760d816c781e711ff0923c296f97b786662453":
		failures.append("Poker nights do not consume the owner-frozen ritual contract.")
	var expected := NIGHT_IDS
	var actual: Array[String] = []
	for profile_value in package.get("profiles", []):
		var profile: Dictionary = profile_value
		actual.append(str(profile.get("id", "")))
		for key in ["phases", "required_task", "scene_operations", "aftermath", "actors", "objects"]:
			if not profile.has(key) or (typeof(profile.get(key)) == TYPE_ARRAY and (profile.get(key) as Array).is_empty()):
				failures.append("Night %s lacks %s." % [str(profile.get("id", "")), key])
	if actual != expected:
		failures.append("Poker-night profile identity/order changed: %s" % JSON.stringify(actual))


func _check_ordered_traces(library: ContentLibrary) -> void:
	for seed in range(10):
		var first := _ordered_trace(library, seed)
		var second := _ordered_trace(library, seed)
		if not bool(first.get("ok", false)):
			failures.append("Ordered trace %d failed: %s" % [seed, str(first.get("error", "unknown"))])
			continue
		if JSON.stringify(first.get("trace", [])) != JSON.stringify(second.get("trace", [])):
			failures.append("Ordered trace %d is not deterministic." % seed)


func _ordered_trace(library: ContentLibrary, seed: int) -> Dictionary:
	var game: GameModule = GameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var run := RunState.new()
	run.start_new("CREW06_10_ORDERED_%d" % seed)
	run.bankroll = 1000
	run.crew_add_trust("crew_mags", CrewStateModel.rank_threshold("associate"), "fixture")
	var environment := {
		"id": "crew06_10_ordered_%d" % seed,
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"resident_member_ids": ["crew_mags", "crew_lucky"],
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
		"crew_poker_turn_engine": "ordered_v1",
		"crew_poker_night_id": "friendly_teaching",
	}
	var table_rng := run.create_rng("crew06_10_table")
	environment["game_states"] = {"crew_draw_poker": game.generate_environment_state(run, environment, table_rng)}
	run.save_rng(table_rng)
	run.current_environment = environment
	var trace: Array = []
	var receipts: Array[String] = []
	for step in range(80):
		var state := _table(run)
		if not _pot_conserved(state):
			return {"ok": false, "error": "pot/contribution mismatch at step %d" % step}
		if step > 0 and str(state.get("phase", "")) == "idle":
			if int(state.get("hand_number", 0)) != 1:
				return {"ok": false, "error": "hand did not settle exactly once"}
			var restored := RunState.new()
			restored.from_dict(run.to_dict())
			if JSON.stringify(_table(restored)) != JSON.stringify(state):
				return {"ok": false, "error": "settled save/load changed ordered state"}
			return {"ok": true, "trace": trace}
		var actions := game.legal_actions(run, run.current_environment)
		if actions.is_empty():
			return {"ok": false, "error": "no legal action at step %d" % step}
		var ids: Array[String] = []
		for action in actions:
			ids.append(str((action as Dictionary).get("id", "")))
		var action_id := "deal" if ids.has("deal") else "observe" if ids.has("observe") else "draw" if ids.has("draw") else "call" if ids.has("call") else "fold"
		var before := JSON.stringify(state)
		var rng := run.create_rng("crew06_10_action_%d" % step)
		var result := game.resolve_with_context(action_id, 0, run, run.current_environment, rng, {"poker_held": [0, 2]} if action_id == "draw" else {})
		if not bool(result.get("ok", false)):
			if JSON.stringify(_table(run)) != before:
				return {"ok": false, "error": "rejected action mutated state"}
			return {"ok": false, "error": str(result.get("message", "action rejected"))}
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run, result, rng)
		var receipt := str(result.get("crew_poker_turn_receipt", ""))
		if receipt.is_empty() or receipts.has(receipt):
			return {"ok": false, "error": "missing or duplicate turn receipt"}
		receipts.append(receipt)
		var facts: Array = result.get("crew_poker_public_facts", []) if typeof(result.get("crew_poker_public_facts", [])) == TYPE_ARRAY else []
		if facts.size() != 1 or str((facts[0] as Dictionary).get("content_fingerprint", "")).length() != 64:
			return {"ok": false, "error": "public action fact lacks one canonical fingerprint"}
		var after := _table(run)
		trace.append({"action": action_id, "phase": str(after.get("phase", "")), "owner": str(after.get("turn_owner", "")), "pot": int(after.get("pot", 0)), "history": (after.get("action_history", []) as Array).size()})
		if step == 4:
			var pause: Dictionary = game.interrupt_for_room_scenario(run, run.current_environment, "pause", "fixture_knock")
			if not bool(pause.get("ok", false)) or int(_table(run).get("pot", -1)) != int(after.get("pot", -2)):
				return {"ok": false, "error": "pause changed the conserved pot"}
			var restored_mid := RunState.new()
			restored_mid.from_dict(run.to_dict())
			if JSON.stringify(_table(restored_mid)) != JSON.stringify(_table(run)):
				return {"ok": false, "error": "mid-hand save/load changed ordered state"}
			var resume: Dictionary = game.interrupt_for_room_scenario(run, run.current_environment, "resume", "fixture_knock")
			if not bool(resume.get("ok", false)) or str(_table(run).get("phase", "")) == "paused":
				return {"ok": false, "error": "paused hand did not resume exactly"}
	return {"ok": false, "error": "ordered trace did not terminate"}


func _pot_conserved(state: Dictionary) -> bool:
	if str(state.get("phase", "idle")) == "idle":
		return int(state.get("pot", 0)) == 0
	var total := int(state.get("player_contribution", 0))
	for seat_value in state.get("seats", []):
		total += int((seat_value as Dictionary).get("contribution", 0))
	return total == int(state.get("pot", 0))


func _table(run: RunState) -> Dictionary:
	var states: Dictionary = run.current_environment.get("game_states", {})
	return (states.get("crew_draw_poker", {}) as Dictionary).duplicate(true)
