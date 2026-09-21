extends Node

const SlotScript := preload("res://scripts/games/slot.gd")
const SlotGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const ActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")

const SENTINEL := "GAME06_4_MACHINE_GAMES_PLATFORM="
const SEEDS := [
	"GAME06-4-PARITY-01", "GAME06-4-PARITY-02", "GAME06-4-PARITY-03",
	"GAME06-4-PARITY-04", "GAME06-4-PARITY-05", "GAME06-4-PARITY-06",
	"GAME06-4-PARITY-07", "GAME06-4-PARITY-08", "GAME06-4-PARITY-09",
	"GAME06-4-PARITY-10",
]


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var failures: Array = []
	var library = ContentLibraryScript.new()
	library.load()
	var traces: Array = []
	for seed_value in SEEDS:
		var seed := str(seed_value)
		var first := _seed_trace(library, seed, failures)
		var repeat := _seed_trace(library, seed, failures)
		if JSON.stringify(first) != JSON.stringify(repeat):
			failures.append("Same-seed machine trace drifted for %s." % seed)
		traces.append(first)
	var semantic_json := JSON.stringify(traces)
	var semantic_sha256 := semantic_json.sha256_text()
	var report := {
		"schema": "game06_4_machine_games_platform_v1",
		"ok": failures.is_empty(),
		"platform": "Web" if OS.has_feature("web") else "native",
		"seed_count": SEEDS.size(),
		"semantic": traces,
		"semantic_sha256": semantic_sha256,
		"failures": failures,
	}
	var report_path := _argument("report")
	if not report_path.is_empty() and not OS.has_feature("web"):
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			report["ok"] = false
			failures.append("Could not write native platform report.")
		else:
			file.store_string(JSON.stringify(report, "  ", false) + "\n")
			file.close()
	print(SENTINEL + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)


func _seed_trace(library, seed: String, failures: Array) -> Dictionary:
	return {
		"seed": seed,
		"slot": _slot_trace(library, seed, failures),
		"slot_feature": _slot_feature_trace(library, seed, failures),
		"video_poker": _video_poker_trace(library, seed, failures),
	}


func _slot_trace(library, seed: String, failures: Array) -> Dictionary:
	var game = SlotScript.new()
	game.setup(library.game("slot"), library)
	var run_state = RunStateScript.new()
	run_state.start_new(seed + "-SLOT")
	run_state.bankroll = 10000
	var environment := {
		"id": "game06_4_platform_slot",
		"archetype_id": "casino",
		"kind": "casino",
		"game_ids": ["slot"],
		"game_states": {},
	}
	run_state.set_environment(environment)
	game.enter(run_state, run_state.current_environment)
	var command: Dictionary = game.surface_action_command("slot_spin", 0, false, {}, run_state, run_state.current_environment)
	var before_cash := int(run_state.bankroll)
	var result := _host_resolve(game, run_state, "spin", int(command.get("set_stake", 0)))
	var machine: Dictionary = game.call("_peek_machine", run_state.current_environment)
	var animation_start := int(machine.get("slot_animation_started_msec", 0))
	var surface: Dictionary = game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": animation_start + 30000})
	if not bool(result.get("ok", false)) or not bool(result.get("blackjack_host_committed", false)):
		failures.append("Slot did not settle through sealed authority for %s." % seed)
	if int(run_state.bankroll) != before_cash + int(result.get("bankroll_delta", 0)):
		failures.append("Slot bankroll conservation failed for %s." % seed)
	if int(surface.get("slot_payout", -1)) != int(machine.get("last_payout", 0)) or str(surface.get("slot_outcome_id", "")) != str(machine.get("last_outcome_id", "")):
		failures.append("Slot presentation/outcome mismatch for %s." % seed)
	var ritual: Dictionary = surface.get("ritual_projection", {}) if typeof(surface.get("ritual_projection", {})) == TYPE_DICTIONARY else {}
	return {
		"cabinet_id": str(machine.get("cabinet_variant_id", "")),
		"family": str(machine.get("type_id", "")),
		"format": str(machine.get("format_id", "")),
		"bet": int(result.get("slot_total_bet", command.get("set_stake", 0))),
		"payout": int(result.get("slot_payout", result.get("gross_payout", 0))),
		"bankroll_delta": int(result.get("bankroll_delta", 0)),
		"outcome_id": str(machine.get("last_outcome_id", "")),
		"classification": str(machine.get("last_classification", "")),
		"grid": machine.get("last_grid", []),
		"feature_mode": str((machine.get("active_bonus", {}) as Dictionary).get("mode", "")),
		"surface_phase": str(ritual.get("phase_id", "")),
		"surface_payout": int(surface.get("slot_payout", 0)),
	}


func _slot_feature_trace(library, seed: String, failures: Array) -> Dictionary:
	var definition: Dictionary = library.game("slot")
	var run_state = RunStateScript.new()
	run_state.start_new(seed + "-PINBALL")
	var generator = SlotGeneratorScript.new()
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("game06_4_platform_machine"))
	machine = SlotStateScript.set_selected_bet(machine, "bet_10")
	var pinball = SlotPinballScript.new()
	var rng = run_state.create_rng("game06_4_platform_feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var inputs := ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"]
	var input_index := 0
	var guard := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := str(inputs[input_index]) if input_index < inputs.size() else "slot_bonus_launch"
		input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = (step.get("active_bonus", {}) as Dictionary).duplicate(true)
		machine["active_bonus"] = active
		guard += 1
	if bool(active.get("active", false)):
		failures.append("Slot feature did not terminate for %s." % seed)
	return {
		"mode": str(active.get("mode", "")),
		"steps": guard,
		"total": int(active.get("feature_total", active.get("pending_award", 0))),
		"jackpot_tier": str(active.get("jackpot_tier", "")),
		"history": _feature_history_semantic(active.get("history", [])),
	}


func _video_poker_trace(library, seed: String, failures: Array) -> Dictionary:
	var game = VideoPokerScript.new()
	game.setup(library.game("video_poker"), library)
	var run_state = RunStateScript.new()
	run_state.start_new(seed + "-POKER")
	run_state.bankroll = 10000
	var environment := {
		"id": "game06_4_platform_poker",
		"archetype_id": "casino",
		"kind": "casino",
		"game_ids": ["video_poker"],
		"game_states": {},
	}
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("game06_4_platform_poker_machine"))
	environment["game_states"] = {"video_poker": machine}
	run_state.set_environment(environment)
	game.enter(run_state, run_state.current_environment)
	var deal: Dictionary = game.video_poker_ritual_input_command("pointer", "video_poker_deal", 0, {}, run_state, run_state.current_environment)
	var hold_index := _stable_index(seed, 5)
	var hold: Dictionary = game.video_poker_ritual_input_command("pointer", "video_poker_hold", hold_index, deal.get("ui_state", {}), run_state, run_state.current_environment)
	var draw: Dictionary = game.video_poker_ritual_input_command("pointer", "video_poker_draw", 0, hold.get("ui_state", {}), run_state, run_state.current_environment)
	_seed_host_session(game, run_state, draw.get("ui_state", {}))
	var before_cash := int(run_state.bankroll)
	var result := _host_resolve(game, run_state, "draw", int(draw.get("set_stake", 0)))
	var surface: Dictionary = game.surface_state(run_state, run_state.current_environment, {})
	if not bool(result.get("ok", false)) or not bool(result.get("blackjack_host_committed", false)):
		failures.append("Video Poker did not settle through sealed authority for %s." % seed)
	if int(run_state.bankroll) != before_cash + int(result.get("bankroll_delta", 0)):
		failures.append("Video Poker bankroll conservation failed for %s." % seed)
	if str(surface.get("result_pay_label", "")) != str(result.get("video_poker_pay_label", "")):
		failures.append("Video Poker presentation/payline mismatch for %s." % seed)
	return {
		"cabinet_id": str(machine.get("cabinet_id", "")),
		"variant_id": str(machine.get("variant_id", "")),
		"hand_count": int(machine.get("multi_hand_count", 1)),
		"held_index": hold_index,
		"drawn_indices": result.get("video_poker_drawn_indices", []),
		"final_hands": result.get("video_poker_hands", []),
		"pay_label": str(result.get("video_poker_pay_label", "")),
		"win_credits": int(result.get("video_poker_gross", 0)),
		"bankroll_delta": int(result.get("bankroll_delta", 0)),
		"surface_pay_label": str(surface.get("result_pay_label", "")),
		"handpay_present": surface.has("handpay_required") or str(surface.get("tower_state", "")) == "handpay",
	}


func _host_resolve(game, run_state, action_id: String, stake: int) -> Dictionary:
	var host = FoundationMainScript.new()
	host.set("current_game", game)
	var cache := {}
	cache[game.get_id()] = game
	host.set("game_module_cache", cache)
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", action_id, stake, {})
	host.free()
	return result


func _seed_host_session(game, run_state, session: Dictionary) -> void:
	var table: Dictionary = game.call("_table_state", run_state, run_state.current_environment)
	var binding := "%s:%s:%s" % [game.get_id(), str(run_state.current_environment.get("id", "unknown")), str(run_state.current_environment.get("archetype_id", "unknown"))]
	var ledger := ActionAuthorityScript.validate_persisted_ledger(table.get(ActionAuthorityScript.LEDGER_KEY, {}), binding, run_state.action_authority_checkpoint_fingerprint())
	if ledger.is_empty():
		ledger = ActionAuthorityScript.default_ledger(binding, run_state.action_authority_checkpoint_fingerprint())
	table[ActionAuthorityScript.LEDGER_KEY] = ActionAuthorityScript.stage_session(ledger, session)
	game.call("_update_environment_table", run_state.current_environment, table)


func _stable_index(seed: String, bound: int) -> int:
	var value := 2166136261
	for byte in seed.to_utf8_buffer():
		value = int((value ^ int(byte)) * 16777619) & 0x7fffffff
	return value % maxi(1, bound)


func _feature_history_semantic(value: Variant) -> Array:
	var rows: Array = []
	if typeof(value) != TYPE_ARRAY:
		return rows
	for step_value in value as Array:
		var step: Dictionary = step_value if typeof(step_value) == TYPE_DICTIONARY else {}
		var events: Array = []
		for event_value in step.get("event_log", []):
			var event: Dictionary = event_value if typeof(event_value) == TYPE_DICTIONARY else {}
			events.append({
				"id": str(event.get("element_id", "")),
				"type": str(event.get("element_type", "")),
				"award": int(event.get("award", 0)),
			})
		rows.append({
			"id": str(step.get("id", "")),
			"award": int(step.get("award", 0)),
			"total": int(step.get("total", 0)),
			"active_balls": int(step.get("active_balls", 0)),
			"trajectory_count": int(step.get("trajectory_count", 0)),
			"events": events,
		})
	return rows


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
