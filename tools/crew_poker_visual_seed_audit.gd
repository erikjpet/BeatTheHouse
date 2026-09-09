extends RefCounted

# Pure production-model proof for the pinned visual capture seed. The seed
# traverses the same RunState + initial RunGenerator path as the capture. Its
# untouched action RNG is then proven across resident orderings through the
# first Hold'em flop. No beat, card, or RNG state is injected by the audit.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const CrewDrawPokerGameScript := preload("res://scripts/games/crew_draw_poker.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const FIXTURE_SEED := "CREW-POKER-PUNCHLINE-VISUAL-00"
const TABLE_GAME_RNG_KEY := "environment_layer_games::back_room"
const TABLE_STATE_RNG_KEY := "environment_game_state:small_underground_casino_001:crew_draw_poker"
const RESIDENTS: Array[String] = ["crew_mags", "crew_rook", "crew_lucky"]
const INPUT_SEQUENCE: Array[String] = ["poker_deal", "ordered_observe_or_call_until_flop"]


static func audit_pinned_seed(library: ContentLibrary) -> Dictionary:
	if library == null:
		return {"passed": false, "failure": "Content library is unavailable.", "seed": FIXTURE_SEED}
	var result := _audit_candidate(library, FIXTURE_SEED)
	result["pinned_seed_assertion"] = true
	return result


static func _audit_candidate(library: ContentLibrary, seed_text: String) -> Dictionary:
	var source_run: RunState = RunStateScript.new()
	source_run.start_new(seed_text)
	source_run.begin_act(1)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(source_run)
	var action_rng := {"seed": source_run.rng_seed, "state": source_run.rng_state}
	var orders: Array[Dictionary] = []
	var passed := true
	for resident_order in [RESIDENTS.duplicate(), [RESIDENTS[1], RESIDENTS[0]]]:
		var order_result := _audit_order(library, seed_text, action_rng, resident_order as Array)
		orders.append(order_result)
		passed = passed and bool(order_result.get("passed", false))
	return {
		"passed": passed,
		"seed": seed_text,
		"action_rng_after_foundation_generation": action_rng,
		"table_rng_streams": [TABLE_GAME_RNG_KEY, TABLE_STATE_RNG_KEY],
		"residents": RESIDENTS.duplicate(),
		"input_sequence": INPUT_SEQUENCE.duplicate(),
		"seat_orders": orders,
	}


static func _audit_order(library: ContentLibrary, seed_text: String, action_rng: Dictionary, resident_order: Array) -> Dictionary:
	var game: GameModule = CrewDrawPokerGameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var audit_run: RunState = RunStateScript.new()
	audit_run.start_new(seed_text)
	audit_run.rng_seed = int(action_rng.get("seed", 1))
	audit_run.rng_state = int(action_rng.get("state", 1))
	audit_run.bankroll = 500
	for member_id in RESIDENTS:
		audit_run.crew_add_trust(member_id, CrewStateModelScript.rank_threshold("made"), "visual_seed_audit")
	var environment := {
		"id": "crew_poker_visual_seed_audit",
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"resident_member_ids": resident_order.duplicate(),
		"game_ids": ["crew_draw_poker"],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 6},
		"game_states": {},
	}
	var table_base_rng: RngStream = RngStreamScript.new()
	table_base_rng.configure(int(action_rng.get("seed", 1)), int(action_rng.get("state", 1)))
	var table_rng := table_base_rng.fork(TABLE_GAME_RNG_KEY).fork(TABLE_STATE_RNG_KEY)
	var generated := game.generate_environment_state(audit_run, environment, table_rng)
	environment["game_states"] = {"crew_draw_poker": generated}
	audit_run.current_environment = environment
	var deal := _resolve_action(game, audit_run, "deal")
	var progressed := bool(deal.get("ok", false))
	var actions: Array = ["deal"]
	for _step in range(16):
		var table: Dictionary = audit_run.current_environment.get("game_states", {}).get("crew_draw_poker", {})
		if str(table.get("phase", "")) == "flop" or str(table.get("phase", "")) == "idle":
			break
		var legal_ids: Array = []
		for action_value in game.legal_actions(audit_run, audit_run.current_environment):
			legal_ids.append(str((action_value as Dictionary).get("id", "")))
		var next_action := "observe" if legal_ids.has("observe") else "call" if legal_ids.has("call") else ""
		if next_action.is_empty():
			progressed = false
			break
		var step_result := _resolve_action(game, audit_run, next_action)
		actions.append(next_action)
		progressed = progressed and bool(step_result.get("ok", false))
		if not progressed:
			break
	var surface := game.surface_state(audit_run, audit_run.current_environment, {})
	var generated_members: Array = generated.get("members", []) if typeof(generated.get("members", [])) == TYPE_ARRAY else []
	var order_passed := bool(deal.get("ok", false)) \
		and progressed \
		and str(surface.get("phase", "")) in ["flop", "idle"] \
		and int(surface.get("hand_number", -1)) == 0 \
		and generated_members.size() == 3 \
		and (surface.get("community_cards", []) as Array).size() in [0, 3]
	return {
		"passed": order_passed,
		"resident_input": resident_order.duplicate(),
		"generated_members": generated_members.duplicate(),
		"deal_ok": bool(deal.get("ok", false)),
		"progressed": progressed,
		"actions": actions,
		"phase": str(surface.get("phase", "")),
		"hand_number": int(surface.get("hand_number", -1)),
		"community_card_count": (surface.get("community_cards", []) as Array).size(),
	}


static func _resolve_action(game: GameModule, audit_run: RunState, action_id: String) -> Dictionary:
	var rng := audit_run.create_rng()
	var result := game.resolve_with_context(action_id, 2, audit_run, audit_run.current_environment, rng, {})
	if bool(result.get("ok", false)):
		audit_run.advance_environment_turns(1)
		GameModuleScript.apply_result(audit_run, result, rng)
	return result
