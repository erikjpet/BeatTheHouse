extends SceneTree

const SlotScript := preload("res://scripts/games/slot.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_machine_contract(SlotScript.new().slot_machine_ritual_contract(), "slot.machine_session", ["credits", "commitment", "activation", "outcome_staging", "feature", "payout_or_handpay"])
	_check_machine_contract(VideoPokerScript.new().video_poker_ritual_contract(), "video_poker.machine_session", ["credits", "commitment", "initial_deal", "hold_selection", "draw", "result_read", "double_up", "payout_or_handpay"])
	_check_live_projections_and_tactile_rejection()
	_check_observer_equivalence()
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


func _check_live_projections_and_tactile_rejection() -> void:
	var slot = SlotScript.new()
	var slot_projection: Dictionary = slot.call("_slot_live_ritual_projection", {"last_classification": "win", "active_bonus": {}}, {"bankroll": 95, "selected_bet_total_credits": 5, "slot_payout": 20, "slot_celebration_tier": "win"}, null)
	_check(str(slot_projection.get("phase_id", "")) == "payout_or_handpay", "Slot result did not stage before returning to credits.")
	_check(int(slot_projection.get("credits", -1)) == 95 and str(slot_projection.get("denomination_label", "")) == "5 CREDIT", "Slot cabinet did not consume live credit/denomination state.")
	_check(str((slot_projection.get("neighbours", {}) as Dictionary).get("authority", "")) == "none", "Slot neighbour projection gained outcome authority.")
	var begin: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "begin", Vector2(900, 360), {}, null, {})
	var rejected: Dictionary = slot.surface_pointer_command("slot_handle_pull_gesture", 0, "end", Vector2(900, 370), begin.get("ui_state", {}), null, {})
	_check(str(rejected.get("action_id", "")).is_empty(), "Incomplete Slot handle pull emitted a spin command.")
	var poker = VideoPokerScript.new()
	var poker_projection: Dictionary = poker.call("_video_poker_live_ritual_projection", "hold", {"credits": 80, "coin_label": "25c", "bet_credits": 5, "holds": [1, 3], "drawn_indices": []}, {}, {}, true, {})
	_check(str(poker_projection.get("phase_id", "")) == "hold_selection", "Video Poker live hand did not project hold selection.")
	_check((poker_projection.get("held_indices", []) as Array) == [1, 3], "Video Poker cabinet projection lost exact held-card indices.")
	_check(str((poker_projection.get("neighbours", {}) as Dictionary).get("authority", "")) == "none", "Video Poker neighbour projection gained outcome authority.")


func _exact_keys(record: Dictionary, expected: Array) -> bool:
	var actual := record.keys()
	actual.sort()
	expected.sort()
	return actual == expected


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
