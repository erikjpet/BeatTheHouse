extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const DEFAULT_ROUNDS := 10000
const REPORT_PATH := "res://.tmp/video_poker/rtp_audit.json"
const CABINETS := [
	{"cabinet_id": "jacks_or_better", "variant_id": "jacks_or_better", "tier_id": "full_pay", "hands": 1, "label": "Jacks or Better", "schedule": "9/6", "optimal_rtp": 0.9954, "sample_min": 0.88, "sample_max": 1.12},
	{"cabinet_id": "double_deuces", "variant_id": "deuces_wild", "tier_id": "full_pay", "hands": 2, "label": "Double Deuces", "schedule": "Illinois 25/15/9/4/4/3", "optimal_rtp": 0.9891, "sample_min": 0.78, "sample_max": 1.12},
	{"cabinet_id": "triple_double_bonus", "variant_id": "double_double_bonus", "tier_id": "full_pay", "hands": 3, "label": "Triple Double Bonus", "schedule": "10/6 DDB", "optimal_rtp": 1.0007, "sample_min": 0.80, "sample_max": 1.18},
]

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rounds := DEFAULT_ROUNDS
	var env_rounds := OS.get_environment("BTH_VIDEO_POKER_RTP_ROUNDS").strip_edges()
	if not env_rounds.is_empty():
		rounds = maxi(100, int(env_rounds))
	var library := ContentLibraryScript.new()
	library.load()
	var game := _video_poker_game(library)
	var rows: Array = []
	if game == null:
		failures.append("Could not load video_poker game module.")
	else:
		for cabinet_value in CABINETS:
			var cabinet: Dictionary = cabinet_value
			rows.append(_audit_cabinet(game, cabinet, rounds))
	var report := {
		"tool": "video_poker_rtp_audit",
		"rounds_per_cabinet": rounds,
		"rows": rows,
		"failures": failures,
		"passed": failures.is_empty(),
	}
	_write_json(REPORT_PATH, report)
	for row_value in rows:
		var row: Dictionary = row_value
		print("VIDEO_POKER_RTP %s hands=%d bet=%d return=%d cost=%d rtp=%.4f" % [
			str(row.get("cabinet_id", "")),
			int(row.get("hands", 0)),
			int(row.get("bet_per_round", 0)),
			int(row.get("total_return", 0)),
			int(row.get("total_cost", 0)),
			float(row.get("rtp", 0.0)),
		])
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _video_poker_game(library) -> GameModule:
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		if str(definition.get("id", "")) != "video_poker":
			continue
		var script_path := str(definition.get("module_path", ""))
		var module_script: Script = load(script_path)
		if module_script == null:
			return null
		var instance: Object = module_script.new()
		if not instance is GameModule:
			return null
		var game: GameModule = instance
		game.setup(definition, library)
		return game
	return null


func _audit_cabinet(game: GameModule, cabinet: Dictionary, rounds: int) -> Dictionary:
	var run_state := _fresh_run(game, cabinet)
	_assert_locked_paytable(game, run_state, cabinet)
	var rng := run_state.create_rng("video_poker_rtp_%s" % str(cabinet.get("cabinet_id", "")))
	var staked := 0
	var returned := 0
	var wins := 0
	var top_hit := ""
	var top_return := 0
	for round_index in range(rounds):
		var before := int(run_state.bankroll)
		var result := _play_hand(game, run_state, rng)
		var bet := int(result.get("video_poker_bet", 0))
		var gross := int(result.get("video_poker_gross", 0))
		staked += bet
		returned += gross
		if gross > 0:
			wins += 1
		if gross > top_return:
			top_return = gross
			top_hit = str(result.get("video_poker_pay_label", ""))
		if int(run_state.bankroll) < 1000000:
			run_state.bankroll = before
	var rtp := float(returned) / float(maxi(1, staked))
	var sample_min := float(cabinet.get("sample_min", 0.0))
	var sample_max := float(cabinet.get("sample_max", 2.0))
	if rtp < sample_min or rtp > sample_max:
		failures.append("%s recommendation-policy RTP %.4f outside declared %.4f-%.4f band." % [str(cabinet.get("label", "")), rtp, sample_min, sample_max])
	return {
		"cabinet_id": str(cabinet.get("cabinet_id", "")),
		"label": str(cabinet.get("label", "")),
		"variant_id": str(cabinet.get("variant_id", "")),
		"tier_id": str(cabinet.get("tier_id", "")),
		"hands": int(cabinet.get("hands", 1)),
		"schedule": str(cabinet.get("schedule", "")),
		"declared_optimal_rtp": float(cabinet.get("optimal_rtp", 0.0)),
		"sample_band": [sample_min, sample_max],
		"sample_policy": "deterministic concise hold recommendation",
		"rounds": rounds,
		"bet_per_round": int(round(float(staked) / float(maxi(1, rounds)))),
		"total_cost": staked,
		"total_return": returned,
		"rtp": rtp,
		"win_rate": float(wins) / float(maxi(1, rounds)),
		"top_hit": top_hit,
		"top_return": top_return,
	}


func _assert_locked_paytable(game: GameModule, run_state: RunState, cabinet: Dictionary) -> void:
	var state: Dictionary = game.call("_machine_state", run_state, run_state.current_environment)
	var variant: Dictionary = game.call("_variant", state)
	var actual := {}
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value if typeof(row_value) == TYPE_DICTIONARY else {}
		actual[str(row.get("key", ""))] = int(row.get("mult", 0))
	var expected := {}
	match str(cabinet.get("cabinet_id", "")):
		"jacks_or_better":
			expected = {"full_house": 9, "flush": 6, "straight": 4, "jacks_or_better": 1}
		"double_deuces":
			expected = {"wild_royal": 25, "five_kind": 15, "straight_flush": 9, "four_kind": 4, "full_house": 4, "flush": 3, "straight": 2, "three_kind": 1}
		"triple_double_bonus":
			expected = {"four_aces_kicker": 400, "four_2_4_kicker": 160, "four_aces": 160, "four_2_4": 80, "four_5_k": 50, "full_house": 10, "flush": 6}
	for key_value in expected.keys():
		var key := str(key_value)
		if int(actual.get(key, -1)) != int(expected.get(key, -2)):
			failures.append("%s paytable row %s expected %d, got %d." % [str(cabinet.get("label", "")), key, int(expected.get(key, 0)), int(actual.get(key, -1))])


func _fresh_run(game: GameModule, cabinet: Dictionary) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("VIDEO-POKER-RTP-%s" % str(cabinet.get("cabinet_id", "")))
	run_state.bankroll = 100000000
	var environment := {
		"id": "video_poker_rtp_room",
		"archetype_id": "casino",
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"game_ids": ["video_poker"],
	}
	var state: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("vp_rtp_state"))
	state["cabinet_id"] = str(cabinet.get("cabinet_id", "jacks_or_better"))
	state["variant_id"] = str(cabinet.get("variant_id", "jacks_or_better"))
	state["paytable_tier_id"] = str(cabinet.get("tier_id", "full_pay"))
	state["multi_hand_count"] = int(cabinet.get("hands", 1))
	state["coin_denominations"] = [{"label": "$1", "credits": 1}]
	state["denomination_index"] = 0
	state["last_result"] = {}
	environment["game_states"] = {"video_poker": state}
	run_state.current_environment = environment
	return run_state


func _play_hand(game: GameModule, run_state: RunState, rng) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var ui := {"bet_level": 4, "denomination_index": 0, "hand_active": true}
	var state: Dictionary = game.call("_machine_state", run_state, environment)
	var variant: Dictionary = game.call("_variant", state)
	var hand: Array = game.call("_opening_hand", run_state, state)
	ui["holds"] = game.call("_suggested_holds", hand, variant)
	return game.resolve_with_context("draw", 0, run_state, environment, rng, ui)


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var dir := absolute.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
