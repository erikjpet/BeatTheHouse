extends SceneTree

const SlotScript := preload("res://scripts/games/slot.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_machine_contract(SlotScript.new().slot_machine_ritual_contract(), "slot.machine_session", ["credits", "commitment", "activation", "outcome_staging", "feature", "payout_or_handpay"])
	_check_machine_contract(VideoPokerScript.new().video_poker_ritual_contract(), "video_poker.machine_session", ["credits", "commitment", "initial_deal", "hold_selection", "draw", "result_read", "double_up", "payout_or_handpay"])
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
	_check(str(slot_projection.get("phase_id", "")) == "payout_or_handpay", "Slot result did not stage before returning to credits.")
	_check(int(slot_projection.get("cash_balance", -1)) == 95 and str(slot_projection.get("denomination_label", "")) == "5 CREDIT", "Slot cabinet did not consume live cash/denomination state.")
	_check(not bool(slot_projection.get("machine_credit_ledger_available", true)), "Slot invented a machine-credit ledger.")
	var slot_actors: Dictionary = slot_projection.get("actors", {})
	_check(str((slot_actors.get("neighbour_seats", {}) as Dictionary).get("authority", "")) == "none", "Slot neighbour projection gained outcome authority.")
	_check((slot_projection.get("scene_objects", {}) as Dictionary).has("cabinet_tower_light"), "Slot declared tower-light identity is not live.")
	var begin: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "begin", Vector2(900, 360), {}, null, {})
	var rejected: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "end", Vector2(900, 370), begin.get("ui_state", {}), null, {})
	_check(str(rejected.get("action_id", "")).is_empty(), "Incomplete Slot handle pull emitted a spin command.")
	var poker = VideoPokerScript.new()
	var poker_projection: Dictionary = poker.call("_video_poker_live_ritual_projection", "hold", {"credits": 80, "coin_label": "25c", "bet_credits": 5, "holds": [1, 3], "drawn_indices": []}, {}, {}, true, {})
	_check(str(poker_projection.get("phase_id", "")) == "hold_selection", "Video Poker live hand did not project hold selection.")
	_check((poker_projection.get("held_indices", []) as Array) == [1, 3], "Video Poker cabinet projection lost exact held-card indices.")
	var poker_actors: Dictionary = poker_projection.get("actors", {})
	_check(str((poker_actors.get("neighbour_seats", {}) as Dictionary).get("authority", "")) == "none", "Video Poker neighbour projection gained outcome authority.")
	_check((poker_projection.get("scene_objects", {}) as Dictionary).has("cabinet_tower_light"), "Video Poker declared tower-light identity is not live.")
	var invented_handpay: Dictionary = poker.call("_video_poker_live_ritual_projection", "settled", {"credits": 80, "coin_label": "25c", "bet_credits": 5, "win_credits": 5000, "holds": [], "drawn_indices": [0]}, {}, {}, false, {"win_credits": 5000})
	_check(str(invented_handpay.get("tower_state", "")) != "handpay", "Video Poker still invents hand-pay from a local payout threshold.")


func _check_executable_machine_paths() -> void:
	var library = ContentLibraryScript.new()
	library.load()
	_check_slot_spin_and_host_ack(library)
	_check_video_poker_targeted_inputs(library)


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
	var spin_command: Dictionary = slot.surface_action_command("slot_spin", 0, false, {}, run_state, environment)
	var before_cash: int = int(run_state.bankroll)
	var result: Dictionary = slot.resolve_with_context("spin", int(spin_command.get("set_stake", 0)), run_state, environment, run_state.create_rng("game06_4_slot_spin"), {})
	_check(bool(result.get("ok", false)), "Slot live spin did not resolve through its shipped authority.")
	_check(int((slot.call("_read_machine", environment) as Dictionary).get("spin_count", 0)) == 1, "Slot live spin did not advance the authoritative machine lifecycle once.")
	GameModule.apply_result(run_state, result, run_state.create_rng("game06_4_slot_apply"))
	_check(run_state.bankroll == before_cash + int(result.get("bankroll_delta", 0)), "Slot shipped cash conservation changed at the host apply boundary.")
	var live_surface: Dictionary = slot.surface_state(run_state, environment, {})
	_check(bool(live_surface.get("surface_animates_idle", false)), "Slot live cabinet lost the nonzero idle-liveness contract.")
	var machine_bytes_before := JSON.stringify(slot.call("_peek_machine", environment))
	var realtime_patch: Dictionary = slot.surface_realtime_state_patch(run_state, environment, {"surface_time_msec": 1}, live_surface)
	_check(not realtime_patch.has("ritual_projection") and JSON.stringify(slot.call("_peek_machine", environment)) == machine_bytes_before, "Slot realtime evidence path copied/projected or mutated ritual authority per frame.")
	var machine: Dictionary = slot.call("_read_machine", environment)
	machine["spin_count"] = 2
	machine["last_outcome_id"] = "authoritative_jackpot"
	machine["last_classification"] = "jackpot"
	machine["slot_celebration_tier"] = "jackpot"
	slot.call("_write_machine", environment, machine, false)
	var substitute = RunStateScript.new()
	substitute.start_new("GAME06-4-SUBSTITUTE")
	var hostile: Dictionary = slot.call("_slot_handpay_acknowledgement", substitute, environment, {"authority": "sealed_host_slot_game_rules", "signature": "signed-looking"})
	_check(not bool(hostile.get("ok", false)) and str(hostile.get("error_code", "")) == "unsealed_authority", "Slot accepted substituted/signed-looking hand-pay authority.")
	var accepted: Dictionary = slot.call("_slot_handpay_acknowledgement", run_state, environment, {"nested": {"authority": "wrong"}})
	_check(bool(accepted.get("ok", false)) and bool(accepted.get("caller_claims_ignored", false)), "Slot did not root acknowledgement in the exact live host object.")
	var restored = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var revisit_slot = SlotScript.new()
	revisit_slot.setup(library.game("slot"), library)
	revisit_slot.enter(restored, restored.current_environment)
	var revisit_machine: Dictionary = revisit_slot.call("_read_machine", restored.current_environment)
	_check(str(revisit_machine.get("ritual_acknowledged_result_id", "")) == str(accepted.get("result_id", "")), "Slot save/revisit lost the receipted hand-pay acknowledgement.")


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
	var before_cash: int = int(run_state.bankroll)
	var result: Dictionary = poker.resolve_with_context("draw", int(draw_command.get("set_stake", 0)), run_state, environment, run_state.create_rng("game06_4_poker_draw"), draw_command.get("ui_state", {}))
	_check(bool(result.get("ok", false)) and (result.get("video_poker_drawn_indices", []) as Array).size() == 4, "Video Poker live deal/hold/draw lifecycle did not preserve exactly one held index.")
	_check(run_state.bankroll == before_cash + int(result.get("bankroll_delta", 0)), "Video Poker shipped cash conservation changed at its existing apply boundary.")
	var restored = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var revisit_poker = VideoPokerScript.new()
	revisit_poker.setup(library.game("video_poker"), library)
	revisit_poker.enter(restored, restored.current_environment)
	var revisit_surface: Dictionary = revisit_poker.surface_state(restored, restored.current_environment, {})
	_check(str(revisit_surface.get("result_pay_label", "")) == str(result.get("video_poker_pay_label", "")), "Video Poker save/revisit lost the authoritative result/paytable line.")


func _exact_keys(record: Dictionary, expected: Array) -> bool:
	var actual := record.keys()
	actual.sort()
	expected.sort()
	return actual == expected


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
