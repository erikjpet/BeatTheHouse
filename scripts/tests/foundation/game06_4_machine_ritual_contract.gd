extends SceneTree

const SlotScript := preload("res://scripts/games/slot.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const ActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_machine_contract(SlotScript.new().slot_machine_ritual_contract(), "slot.machine_session", ["bankroll", "commitment", "activation", "outcome_staging", "feature", "payout_or_handpay"])
	_check_machine_contract(VideoPokerScript.new().video_poker_ritual_contract(), "video_poker.machine_session", ["bankroll", "commitment", "initial_deal", "hold_selection", "draw", "result_read", "double_up", "payout"])
	_check_live_projections_and_tactile_rejection()
	_check_observer_equivalence()
	_check_executable_machine_paths()
	if failures.is_empty():
		print("game06_4_machine_ritual_contract: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	print("game06_4_machine_ritual_contract: FAIL (%d)" % failures.size())
	quit(1)


func _check_machine_contract(contract: Dictionary, ritual_id: String, expected_phases: Array) -> void:
	_check(str(contract.get("contract", "")) == "game_ritual/1", "%s did not bind the frozen contract." % ritual_id)
	_check(str(contract.get("ritual_id", "")) == ritual_id, "%s ritual id changed." % ritual_id)
	_check(str(contract.get("initial_phase", "")) == str(expected_phases[0]), "%s initial phase is not the truthful direct-bankroll phase." % ritual_id)
	var expected_keys := ["action_declarations", "actors", "contract", "declared_targets", "energy", "game_facts", "handler_registry", "initial_phase", "pointer_verbs", "ritual_id", "ritual_persistence", "ritual_phases", "scene_objects", "staged_commitment"]
	var actual_keys := contract.keys()
	expected_keys.sort()
	actual_keys.sort()
	_check(actual_keys == expected_keys, "%s is not a closed top-level ritual record." % ritual_id)
	var phase_ids: Array = []
	for phase_value in contract.get("ritual_phases", []):
		var phase: Dictionary = phase_value if typeof(phase_value) == TYPE_DICTIONARY else {}
		phase_ids.append(str(phase.get("id", "")))
		_check(_exact_keys(phase, ["entry_conditions", "entry_operations", "id", "permitted_actions", "terminal", "transitions"]), "%s phase %s is open or incomplete." % [ritual_id, str(phase.get("id", ""))])
	_check(phase_ids == expected_phases, "%s phase order is incomplete." % ritual_id)
	var declarations: Dictionary = {}
	for declaration_value in contract.get("action_declarations", []):
		var declaration: Dictionary = declaration_value if typeof(declaration_value) == TYPE_DICTIONARY else {}
		declarations[str(declaration.get("action_id", ""))] = true
	for phase_value in contract.get("ritual_phases", []):
		for action_id in (phase_value as Dictionary).get("permitted_actions", []):
			_check(bool(declarations.get(str(action_id), false)), "%s phase action %s has no declaration." % [ritual_id, str(action_id)])
	for pointer_value in contract.get("pointer_verbs", []):
		var pointer: Dictionary = pointer_value if typeof(pointer_value) == TYPE_DICTIONARY else {}
		_check((pointer.get("rejection_effects", []) as Array).is_empty(), "%s pointer rejection gained effects." % ritual_id)
		for input_kind in ["keyboard", "controller", "reduced_motion"]:
			var equivalent: Dictionary = (pointer.get("equivalents", {}) as Dictionary).get(input_kind, {})
			_check(str(equivalent.get("action_id", "")) == str(pointer.get("accepted_action", "")), "%s %s equivalent changes authority." % [ritual_id, input_kind])
	var energy: Dictionary = contract.get("energy", {})
	for tier_value in energy.get("tiers", []):
		var tier: Dictionary = tier_value if typeof(tier_value) == TYPE_DICTIONARY else {}
		var material := (tier.get("actor_operations", []) as Array).size() + (tier.get("object_operations", []) as Array).size() + (tier.get("interaction_operations", []) as Array).size()
		_check(material > 0, "%s energy tier %s is audio/text-only." % [ritual_id, str(tier.get("id", ""))])
	var handler: Dictionary = (contract.get("handler_registry", []) as Array)[0]
	_check(str(handler.get("authority", "")).begins_with("sealed_host_"), "%s handler trusts unsealed authority." % ritual_id)
	_check(str(handler.get("rejection", "")) == "side_effect_free", "%s rejection policy can mutate." % ritual_id)
	var persistence: Dictionary = contract.get("ritual_persistence", {})
	_check((persistence.get("save_boundaries", []) as Array) == expected_phases, "%s does not persist every legal phase." % ritual_id)


func _check_observer_equivalence() -> void:
	# Neither declaration accepts a caller capability. Otherwise-identical callers
	# therefore receive byte-identical records even if they locally claim literal,
	# nested, substituted, signed-looking, or recomputed authority.
	var slot_a := JSON.stringify(SlotScript.new().slot_machine_ritual_contract())
	var slot_b := JSON.stringify(SlotScript.new().slot_machine_ritual_contract())
	var poker_a := JSON.stringify(VideoPokerScript.new().video_poker_ritual_contract())
	var poker_b := JSON.stringify(VideoPokerScript.new().video_poker_ritual_contract())
	_check(slot_a == slot_b, "Slot observer projections differ without authentic host capability.")
	_check(poker_a == poker_b, "Video Poker observer projections differ without authentic host capability.")
	var hostile_claims := [
		{"authority": "literal"},
		{"nested": {"authority": "sealed_host_slot_game_rules"}},
		{"authority": "substituted", "host": {}},
		{"authority": "signed-looking", "signature": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
		{"authority": "recomputed", "digest": slot_a.sha256_text()},
	]
	for claim in hostile_claims:
		_check(JSON.stringify(SlotScript.new().slot_machine_ritual_contract()) == slot_a, "Hostile Slot caller claim changed a static observer projection: %s" % JSON.stringify(claim))
		_check(JSON.stringify(VideoPokerScript.new().video_poker_ritual_contract()) == poker_a, "Hostile Video Poker caller claim changed a static observer projection: %s" % JSON.stringify(claim))


func _check_live_projections_and_tactile_rejection() -> void:
	var slot = SlotScript.new()
	var slot_projection: Dictionary = slot.call("_slot_live_ritual_projection", {"last_classification": "win", "active_bonus": {}}, {"bankroll": 95, "selected_bet_total_credits": 5, "slot_payout": 20, "slot_celebration_tier": "win"}, null)
	_check(str(slot_projection.get("phase_id", "")) == "payout_or_handpay", "Slot result did not stage before returning to bankroll.")
	_check(int(slot_projection.get("cash_balance", -1)) == 95 and str(slot_projection.get("denomination_label", "")) == "$5 BET", "Slot cabinet did not consume live cash/bet state.")
	_check(not bool(slot_projection.get("machine_credit_ledger_available", true)), "Slot invented a machine-credit ledger.")
	var slot_actors: Dictionary = slot_projection.get("actors", {})
	_check(str((slot_actors.get("neighbour_seats", {}) as Dictionary).get("authority", "")) == "none", "Slot neighbour projection gained outcome authority.")
	_check((slot_projection.get("scene_objects", {}) as Dictionary).has("cabinet_tower_light"), "Slot declared tower-light identity is not live.")
	var begin: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "begin", Vector2(900, 360), {}, null, {})
	var rejected: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "end", Vector2(900, 370), begin.get("ui_state", {}), null, {})
	_check(str(rejected.get("action_id", "")).is_empty(), "Incomplete Slot handle pull emitted a spin command.")
	var poker = VideoPokerScript.new()
	var poker_projection: Dictionary = poker.call("_video_poker_live_ritual_projection", "hold", {"bankroll": 80, "coin_label": "25c", "bet_credits": 5, "holds": [1, 3], "drawn_indices": []}, {}, {}, true, {})
	_check(str(poker_projection.get("phase_id", "")) == "hold_selection", "Video Poker live hand did not project hold selection.")
	_check((poker_projection.get("held_indices", []) as Array) == [1, 3], "Video Poker cabinet projection lost exact held-card indices.")
	var poker_actors: Dictionary = poker_projection.get("actors", {})
	_check(str((poker_actors.get("neighbour_seats", {}) as Dictionary).get("authority", "")) == "none", "Video Poker neighbour projection gained outcome authority.")
	_check((poker_projection.get("scene_objects", {}) as Dictionary).has("cabinet_tower_light"), "Video Poker declared tower-light identity is not live.")
	var invented_handpay: Dictionary = poker.call("_video_poker_live_ritual_projection", "settled", {"bankroll": 80, "coin_label": "25c", "bet_credits": 5, "win_credits": 5000, "holds": [], "drawn_indices": [0]}, {}, {}, false, {"win_credits": 5000, "handpay_required": true})
	_check(str(invented_handpay.get("tower_state", "")) != "handpay", "Video Poker still invents hand-pay from a local payout threshold.")


func _check_executable_machine_paths() -> void:
	var library = ContentLibraryScript.new()
	library.load()
	_check_authority_provider(SlotScript.new(), library.game("slot"), "slot", true)
	_check_authority_provider(VideoPokerScript.new(), library.game("video_poker"), "video_poker", false)
	_check_slot_spin_and_host_ack(library)
	_check_video_poker_targeted_inputs(library)


func _check_authority_provider(game, definition: Dictionary, game_id: String, pointer_hosted: bool) -> void:
	game.setup(definition)
	var contract: Dictionary = game.sealed_action_authority_contract()
	_check(game.sealed_action_authority_script() != null, "%s did not provide sealed action authority." % game_id)
	_check(str(contract.get("resolve_proposal_method", "")) == "_machine_game_resolve_proposal", "%s resolve provider is not closed." % game_id)
	_check(str(contract.get("wager_cost_proposal_method", "")) == "_machine_game_wager_cost_proposal", "%s wager provider is not closed." % game_id)
	_check(str(contract.get("authoritative_result_marker", "")) == "sealed_action_authoritative", "%s authoritative result marker is absent." % game_id)
	_check(bool(contract.get("host_pointer_intent", false)) == pointer_hosted, "%s pointer-host policy changed." % game_id)


func _check_slot_spin_and_host_ack(library) -> void:
	var slot = SlotScript.new()
	slot.setup(library.game("slot"), library)
	var run_state = RunStateScript.new()
	run_state.start_new("GAME06-4-SLOT-LIVE")
	run_state.bankroll = 1000
	var environment := {"id": "game06_4_slot", "archetype_id": "casino", "kind": "casino", "game_ids": ["slot"], "game_states": {}}
	run_state.set_environment(environment)
	environment = run_state.current_environment
	slot.enter(run_state, environment)
	var forged_before := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	GameModule.apply_result(run_state, {"ok": true, "game_id": "slot", "source_id": "slot", "action_id": "spin", "sealed_action_authoritative": true, "deltas": {"bankroll_delta": 999}}, run_state.create_rng("forged_slot_apply"))
	_check(RuntimeScript.canonical_json(run_state.to_save_snapshot()) == forged_before, "Slot accepted a direct unreceipted authoritative apply.")
	var spin_command: Dictionary = slot.surface_action_command("slot_spin", 0, false, {}, run_state, environment)
	var before_cash: int = int(run_state.bankroll)
	var result := _host_resolve(slot, run_state, "spin", int(spin_command.get("set_stake", 0)))
	_check(bool(result.get("ok", false)) and bool(result.get("blackjack_host_committed", false)) and bool(result.get("sealed_action_authoritative", false)), "Slot spin did not commit through the sealed direct-bankroll host.")
	_check(typeof(result.get("blackjack_host_apply_receipt", null)) == TYPE_DICTIONARY, "Slot sealed settlement omitted its exact apply receipt.")
	_check(int((slot.call("_read_machine", run_state.current_environment) as Dictionary).get("spin_count", 0)) == 1, "Slot sealed spin did not advance the authoritative machine lifecycle once.")
	_check(run_state.bankroll == before_cash + int(result.get("bankroll_delta", 0)), "Slot sealed direct-bankroll conservation failed.")
	var live_surface: Dictionary = slot.surface_state(run_state, run_state.current_environment, {})
	_check(bool(live_surface.get("surface_animates_idle", false)), "Slot live cabinet lost the nonzero idle-liveness contract.")
	var machine_bytes_before := JSON.stringify(slot.call("_peek_machine", run_state.current_environment))
	var realtime_patch: Dictionary = slot.surface_realtime_state_patch(run_state, run_state.current_environment, {"surface_time_msec": 1}, live_surface)
	_check(not realtime_patch.has("ritual_projection") and JSON.stringify(slot.call("_peek_machine", run_state.current_environment)) == machine_bytes_before, "Slot realtime evidence path copied/projected or mutated ritual authority per frame.")
	var machine: Dictionary = slot.call("_read_machine", run_state.current_environment)
	machine["spin_count"] = 2
	machine["last_outcome_id"] = "authoritative_jackpot"
	machine["last_classification"] = "jackpot"
	machine["slot_celebration_tier"] = "jackpot"
	slot.call("_write_machine", run_state.current_environment, machine, false)
	var substitute = RunStateScript.new()
	substitute.start_new("GAME06-4-SUBSTITUTE")
	var hostile: Dictionary = slot.call("_slot_handpay_acknowledgement", substitute, run_state.current_environment, {"authority": "sealed_host_slot_game_rules", "signature": "signed-looking"})
	_check(not bool(hostile.get("ok", false)) and str(hostile.get("error_code", "")) == "unsealed_authority", "Slot accepted substituted/signed-looking hand-pay authority.")
	var hostile_snapshot := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	var hostile_live: Dictionary = slot.call("_slot_handpay_acknowledgement", run_state, run_state.current_environment, {"authority": "sealed_host_slot_game_rules"}, true)
	var hostile_direct_sealed: Dictionary = slot.call("_slot_sealed_handpay_acknowledgement_result", run_state, run_state.current_environment)
	_check(not bool(hostile_live.get("ok", false)) and str(hostile_live.get("error_code", "")) == "unsealed_authority", "Slot accepted a cached live RunState plus caller-authored proposal flag.")
	_check(not bool(hostile_direct_sealed.get("ok", false)), "Slot direct sealed acknowledgement helper returned a committable result.")
	_check(RuntimeScript.canonical_json(run_state.to_save_snapshot()) == hostile_snapshot, "Slot direct acknowledgement helpers mutated canonical state outside Foundation.")
	var ack_before := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	var ack_cash_before := int(run_state.bankroll)
	var ack_rng_before := run_state.rng_state
	var accepted := _host_resolve(slot, run_state, "slot_handpay_acknowledge", 0)
	_check(bool(accepted.get("ok", false)) and bool(accepted.get("slot_handpay_acknowledgement", false)), "Slot did not seal the attendant acknowledgement.")
	_check(run_state.bankroll == ack_cash_before and run_state.rng_state == ack_rng_before and not bool(accepted.get("sealed_action_authoritative", false)), "Slot acknowledgement changed settlement or RNG authority.")
	var ack_delivery: Dictionary = accepted.get("blackjack_host_delivery", {})
	var accepted_snapshot := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	var replay := _host_resolve(slot, run_state, "slot_handpay_acknowledge", 0, ack_delivery)
	var replay_canonical := replay.duplicate(true)
	replay_canonical.erase("blackjack_host_replay")
	_check(replay.has("blackjack_host_replay") and RuntimeScript.canonical_json(replay_canonical) == RuntimeScript.canonical_json(accepted), "Slot acknowledgement replay was not the exact cached receipt.")
	_check(RuntimeScript.canonical_json(run_state.to_save_snapshot()) == accepted_snapshot and accepted_snapshot != ack_before, "Slot acknowledgement replay mutated state or the first acknowledgement did not persist.")
	var restored = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var revisit_slot = SlotScript.new()
	revisit_slot.setup(library.game("slot"), library)
	revisit_slot.enter(restored, restored.current_environment)
	var revisit_machine: Dictionary = revisit_slot.call("_read_machine", restored.current_environment)
	_check(str(revisit_machine.get("ritual_acknowledged_result_id", "")) == str(accepted.get("slot_handpay_result_id", "")), "Slot save/revisit lost the receipted hand-pay acknowledgement.")


func _check_video_poker_targeted_inputs(library) -> void:
	var poker = VideoPokerScript.new()
	poker.setup(library.game("video_poker"), library)
	var run_state = RunStateScript.new()
	run_state.start_new("GAME06-4-POKER-LIVE")
	run_state.bankroll = 1000
	var environment := {"id": "game06_4_poker", "archetype_id": "casino", "kind": "casino", "game_ids": ["video_poker"], "game_states": {}}
	var machine: Dictionary = poker.generate_environment_state(run_state, environment, run_state.create_rng("game06_4_poker_machine"))
	environment["game_states"] = {"video_poker": machine}
	run_state.set_environment(environment)
	environment = run_state.current_environment
	poker.enter(run_state, environment)
	var surface: Dictionary = poker.surface_state(run_state, environment, {})
	_check(not (surface.get("surface_action_bindings", {}) as Dictionary).is_empty(), "Video Poker live surface action bindings are empty.")
	_check(bool(surface.get("surface_animates_idle", false)) and not bool(surface.get("surface_realtime_state_refresh", false)), "Video Poker cabinet does not expose bounded idle liveness without a full realtime rebuild.")
	var pointer_deal: Dictionary = poker.video_poker_ritual_input_command("pointer", "video_poker_deal", 0, {}, run_state, environment)
	var keyboard_deal: Dictionary = poker.video_poker_ritual_input_command("keyboard", "video_poker_deal", 0, {}, run_state, environment)
	var controller_deal: Dictionary = poker.video_poker_ritual_input_command("controller", "video_poker_deal", 0, {}, run_state, environment)
	for deal in [pointer_deal, keyboard_deal, controller_deal]:
		_check(bool((deal as Dictionary).get("handled", false)) and bool((deal as Dictionary).get("preserve_surface_ui_state", false)), "Video Poker deal equivalent did not reach the live command path.")
	var dealt_ui: Dictionary = pointer_deal.get("ui_state", {})
	var pointer_hold: Dictionary = poker.video_poker_ritual_input_command("pointer", "video_poker_hold", 3, dealt_ui, run_state, environment)
	var keyboard_hold: Dictionary = poker.video_poker_ritual_input_command("keyboard", "video_poker_hold", 3, dealt_ui, run_state, environment)
	var controller_hold: Dictionary = poker.video_poker_ritual_input_command("controller", "video_poker_hold", 3, dealt_ui, run_state, environment)
	var reduced_hold: Dictionary = poker.video_poker_ritual_input_command("reduced_motion", "video_poker_hold", 3, dealt_ui, run_state, environment)
	for hold in [pointer_hold, keyboard_hold, controller_hold, reduced_hold]:
		_check(((hold as Dictionary).get("ui_state", {}) as Dictionary).get("holds", []) == [3], "Video Poker input equivalent changed the targeted hold index.")
	var draw_ui: Dictionary = pointer_hold.get("ui_state", {})
	var draw_command: Dictionary = poker.video_poker_ritual_input_command("controller", "video_poker_draw", 0, draw_ui, run_state, environment)
	_check(str(draw_command.get("action_id", "")) == "draw", "Video Poker targeted draw did not reach the shipped resolver action.")
	_seed_host_session(poker, run_state, draw_command.get("ui_state", {}))
	var before_cash: int = int(run_state.bankroll)
	var result := _host_resolve(poker, run_state, "draw", int(draw_command.get("set_stake", 0)))
	_check(bool(result.get("ok", false)) and bool(result.get("blackjack_host_committed", false)) and bool(result.get("sealed_action_authoritative", false)) and (result.get("video_poker_drawn_indices", []) as Array).size() == 4, "Video Poker sealed deal/hold/draw lifecycle did not preserve exactly one held index.")
	_check(typeof(result.get("blackjack_host_apply_receipt", null)) == TYPE_DICTIONARY, "Video Poker sealed settlement omitted its exact apply receipt.")
	_check(run_state.bankroll == before_cash + int(result.get("bankroll_delta", 0)), "Video Poker sealed direct-bankroll conservation failed.")
	var committed_snapshot := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	var delivery: Dictionary = result.get("blackjack_host_delivery", {})
	var replay := _host_resolve(poker, run_state, "draw", int(draw_command.get("set_stake", 0)), delivery)
	var replay_canonical := replay.duplicate(true)
	replay_canonical.erase("blackjack_host_replay")
	_check(replay.has("blackjack_host_replay") and RuntimeScript.canonical_json(replay_canonical) == RuntimeScript.canonical_json(result), "Video Poker settlement replay was not the exact cached response.")
	_check(RuntimeScript.canonical_json(run_state.to_save_snapshot()) == committed_snapshot, "Video Poker replay duplicated money, RNG, or result state.")
	var hostile_delivery := delivery.duplicate(true)
	hostile_delivery["stake"] = int(draw_command.get("set_stake", 0)) + 1
	var hostile_before := RuntimeScript.canonical_json(run_state.to_save_snapshot())
	var hostile := _host_resolve(poker, run_state, "draw", int(draw_command.get("set_stake", 0)) + 1, hostile_delivery)
	_check(not bool(hostile.get("ok", true)) and str(hostile.get("error_code", "")) in ["receipt_content_conflict", "stale_boundary"], "Video Poker accepted hostile replay content.")
	_check(RuntimeScript.canonical_json(run_state.to_save_snapshot()) == hostile_before, "Video Poker hostile replay changed canonical state.")
	var restored = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var revisit_poker = VideoPokerScript.new()
	revisit_poker.setup(library.game("video_poker"), library)
	revisit_poker.enter(restored, restored.current_environment)
	var revisit_surface: Dictionary = revisit_poker.surface_state(restored, restored.current_environment, {})
	_check(str(revisit_surface.get("result_pay_label", "")) == str(result.get("video_poker_pay_label", "")), "Video Poker save/revisit lost the authoritative result/paytable line.")


func _host_resolve(game, run_state, action_id: String, stake: int, delivery: Dictionary = {}) -> Dictionary:
	var host = FoundationMainScript.new()
	host.set("current_game", game)
	var cache := {}
	cache[game.get_id()] = game
	host.set("game_module_cache", cache)
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", action_id, stake, delivery)
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


func _exact_keys(record: Dictionary, expected: Array) -> bool:
	var actual := record.keys()
	actual.sort()
	expected.sort()
	return actual == expected


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
