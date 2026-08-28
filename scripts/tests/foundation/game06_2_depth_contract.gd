extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const RitualRuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

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
	_check_contract(game)
	_check_declared_projection_ids(game)
	_check_phase_projection(game)
	_check_itemized_accounting(game)
	_check_charged_deal_envelope(game)
	_check_gesture_rejections_and_equivalence(game)
	_check_live_equivalent_bindings(game)
	_check_energy_and_restore_projection(game)
	_check_ten_seed_projection_isolation(game)
	_check_host_authority_and_replay(game)
	_check_failure_atomic_rng_retry(game)
	_check_mixed_rate_funding_rejection(game)
	if failures.is_empty():
		print("game06_2_depth_contract: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	print("game06_2_depth_contract: FAIL (%d)" % failures.size())
	quit(1)


func _check_contract(game: GameModule) -> void:
	var contract: Dictionary = game.call("blackjack_ritual_contract")
	_check(str(contract.get("contract", "")) == "game_ritual/1", "Blackjack did not declare the accepted ritual contract version.")
	_check(str(contract.get("ritual_id", "")) == "blackjack.standard_table", "Blackjack ritual id changed.")
	var expected_top_level := ["action_declarations", "actors", "contract", "declared_targets", "energy", "game_facts", "handler_registry", "initial_phase", "pointer_verbs", "ritual_id", "ritual_persistence", "ritual_phases", "scene_objects", "staged_commitment"]
	var actual_top_level := contract.keys()
	actual_top_level.sort()
	expected_top_level.sort()
	_check(actual_top_level == expected_top_level, "Blackjack ritual definition is not a closed game_ritual/1 record.")
	var phase_ids: Array = []
	for phase_value in contract.get("ritual_phases", []):
		phase_ids.append(str((phase_value as Dictionary).get("id", "")) if typeof(phase_value) == TYPE_DICTIONARY else "")
	_check(phase_ids == ["wagering", "initial_deal", "player_turn", "dealer_procedure", "settlement"], "Blackjack phase vocabulary is incomplete or reordered.")
	var staged: Dictionary = contract.get("staged_commitment", {}) if typeof(contract.get("staged_commitment", {})) == TYPE_DICTIONARY else {}
	var effects: Array = []
	for action_value in staged.get("actions", []):
		if typeof(action_value) == TYPE_DICTIONARY:
			effects.append(str((action_value as Dictionary).get("effect", "")))
	for effect in ["add_or_increment_one", "correct_one_pending_amount", "remove_one_pending_item", "reverse_last_pending_edit", "remove_all_pending_items", "copy_last_eligible_commitment", "copy_eligible_resolved_items", "authorize_pending_set"]:
		_check(effects.has(effect), "Missing staged commitment effect: %s." % effect)
	for total in ["available_funds", "pending_total", "at_risk_total", "returned_stake", "payout", "net_change"]:
		_check((staged.get("readable_totals", []) as Array).has(total), "Missing readable total: %s." % total)
	var gestures: Array = contract.get("pointer_verbs", []) if typeof(contract.get("pointer_verbs", [])) == TYPE_ARRAY else []
	_check(gestures.size() == 4, "Blackjack must declare place, cut, wave, and tap gesture packages.")
	for gesture_value in gestures:
		var gesture: Dictionary = gesture_value if typeof(gesture_value) == TYPE_DICTIONARY else {}
		_check((gesture.get("rejection_effects", []) as Array).is_empty(), "Gesture rejection gained an authoritative effect: %s." % str(gesture.get("id", "unknown")))
		var equivalents: Dictionary = gesture.get("equivalents", {}) if typeof(gesture.get("equivalents", {})) == TYPE_DICTIONARY else {}
		for input_kind in ["keyboard", "controller", "reduced_motion"]:
			_check(typeof(equivalents.get(input_kind, null)) == TYPE_DICTIONARY, "Gesture %s lost its %s equivalent." % [str(gesture.get("id", "unknown")), input_kind])
			var equivalent: Dictionary = equivalents.get(input_kind, {})
			_check(not str(equivalent.get("action_id", "")).is_empty(), "Gesture %s %s equivalent is not bound to a frozen action_id." % [str(gesture.get("id", "unknown")), input_kind])
			_check(str(equivalent.get("target_selection", "")) in ["focus", "cycle", "direct"], "Gesture %s %s equivalent has no canonical target selection." % [str(gesture.get("id", "unknown")), input_kind])
	var persistence: Dictionary = contract.get("ritual_persistence", {}) if typeof(contract.get("ritual_persistence", {})) == TYPE_DICTIONARY else {}
	_check(persistence.get("save_boundaries", []) == ["wagering", "initial_deal", "player_turn", "dealer_procedure", "settlement"], "Not every Blackjack action phase is a declared save boundary.")


func _check_declared_projection_ids(game: GameModule) -> void:
	var contract: Dictionary = game.call("blackjack_ritual_contract")
	var declared_actor_ids: Array = []
	for actor_value in contract.get("actors", []):
		if typeof(actor_value) == TYPE_DICTIONARY:
			declared_actor_ids.append(str((actor_value as Dictionary).get("id", "")))
	var declared_object_ids: Array = []
	for object_value in contract.get("scene_objects", []):
		if typeof(object_value) == TYPE_DICTIONARY:
			declared_object_ids.append(str((object_value as Dictionary).get("id", "")))
	var fixture := _fixture(game, "GAME06-2-DECLARATION-IDS", 3)
	var projection: Dictionary = game.surface_state(fixture.run, fixture.environment, {"selected_stake": 5, "surface_time_msec": 10000}).get("ritual_projection", {})
	for actor_value in projection.get("actors", []):
		var actor: Dictionary = actor_value if typeof(actor_value) == TYPE_DICTIONARY else {}
		_check(declared_actor_ids.has(str(actor.get("id", ""))), "Live actor projection used undeclared id %s." % str(actor.get("id", "")))
	for object_value in projection.get("scene_objects", []):
		var object_state: Dictionary = object_value if typeof(object_value) == TYPE_DICTIONARY else {}
		_check(declared_object_ids.has(str(object_state.get("id", ""))), "Live scene-object projection used undeclared id %s." % str(object_state.get("id", "")))


func _check_phase_projection(game: GameModule) -> void:
	var table := {"deck_count": 2, "cut_card_remaining": 28, "last_result": {}}
	var spec := {"selected_stake": 5, "shoe_remaining": 104, "patrons": [], "side_bets_active": [], "side_bet_stakes": {}, "can_deal": true}
	_check(_phase(game, table, {}, spec, false, false) == "wagering", "Empty Blackjack session did not project wagering.")
	_check(_phase(game, table, {}, spec, true, false) == "initial_deal", "Opening card staging did not project initial_deal.")
	var live := {"selected_stake": 5, "player_hands": [{"cards": [{"rank": 9, "suit": 0}, {"rank": 7, "suit": 1}], "stood": false, "wager_multiplier": 1}], "dealer_cards": [{"rank": 8, "suit": 2}, {"rank": 6, "suit": 3}], "active_hand_index": 0, "wager_debited": 5}
	_check(_phase(game, table, live, spec, false, false) == "player_turn", "Live hand did not project player_turn.")
	var complete := live.duplicate(true)
	(complete.get("player_hands", []) as Array)[0]["stood"] = true
	_check(_phase(game, table, complete, spec, false, false) == "dealer_procedure", "Finished player decisions did not project dealer_procedure.")
	_check(_phase(game, table, {}, spec, false, true) == "settlement", "Payout staging did not project settlement.")


func _phase(game: GameModule, table: Dictionary, session: Dictionary, spec: Dictionary, deal_active: bool, payout_active: bool) -> String:
	var projection: Dictionary = game.call("_blackjack_ritual_projection", null, {}, table.duplicate(true), session.duplicate(true), spec.duplicate(true), deal_active, payout_active)
	return str(projection.get("phase_id", ""))


func _check_itemized_accounting(game: GameModule) -> void:
	var last_result := {
		"bankroll_delta": 18,
		"hand_results": [
			{"outcome": "blackjack", "wager": 10, "bankroll_delta": 15},
			{"outcome": "push", "wager": 10, "bankroll_delta": 0},
			{"outcome": "surrender", "wager": 10, "bankroll_delta": -5},
			{"outcome": "bust", "wager": 10, "bankroll_delta": -10},
		],
		"side_bet_results": [{"id": "perfect_pairs", "stake": 2, "bankroll_delta": 18, "won": true, "detail": "perfect pair"}],
	}
	var resolutions: Array = game.call("_blackjack_item_resolutions", last_result)
	_check(resolutions.size() == 5, "Settlement projection was not itemized per hand and side wager.")
	var totals: Dictionary = game.call("_blackjack_settlement_totals", resolutions, last_result)
	_check(int(totals.get("returned_stake", -1)) == 27, "Returned-stake accounting did not distinguish blackjack, push, surrender, bust, and side win.")
	_check(int(totals.get("payout", -1)) == 33, "Profit/payout accounting did not remain separate from returned stake.")
	for resolution_value in resolutions:
		var resolution: Dictionary = resolution_value if typeof(resolution_value) == TYPE_DICTIONARY else {}
		_check(not str(resolution.get("reason", "")).is_empty(), "An itemized wager resolution has no public reason.")
		for field in ["item_id", "authoritative_result_id", "stake_disposition", "returned_stake", "payout", "net_change", "public_explanation"]:
			_check(resolution.has(field), "An itemized wager resolution omitted frozen authority field %s." % field)
	var pending: Dictionary = game.call("_blackjack_commitment_item", "wager.main", "wager.player", 5, "Main wager", "selected_chip", 2, true, "")
	for field in ["item_id", "target_id", "denomination", "amount", "source", "edit_ordinal", "eligibility", "disabled_reason"]:
		_check(pending.has(field), "A staged wager item omitted frozen field %s." % field)


func _check_charged_deal_envelope(game: GameModule) -> void:
	var fixture := _fixture(game, "GAME06-2-ENVELOPE", 4)
	var session := {"session_id": "blackjack:game06-2-envelope:0", "cards_consumed": 0, "active_hand_index": 0}
	var envelope: Dictionary = game.call("blackjack_ritual_deal_envelope", session, fixture.environment)
	_check(game.call("blackjack_ritual_deal_envelope_authorized", envelope, "wagering"), "Canonical charged-deal envelope did not bind to the Blackjack handler allowlist.")
	var contract: Dictionary = game.call("blackjack_ritual_contract")
	var charged_declarations := 0
	for declaration_value in contract.get("action_declarations", []):
		if typeof(declaration_value) == TYPE_DICTIONARY and str((declaration_value as Dictionary).get("action_id", "")) == "blackjack_place_bet":
			charged_declarations += 1
	_check(charged_declarations == 1, "Charged/resolving Blackjack deal action is not declared exactly once.")
	for mutation in ["action_id", "source_id", "target_id", "expected_phase"]:
		var hostile := envelope.duplicate(true)
		hostile[mutation] = "foreign.id"
		_check(not game.call("blackjack_ritual_deal_envelope_authorized", hostile, "wagering"), "Hostile charged envelope bypassed %s validation." % mutation)
	var cross_id := envelope.duplicate(true)
	(cross_id.get("boundary", {}) as Dictionary)["session_id"] = "blackjack:other-session:0"
	_check(not game.call("blackjack_ritual_deal_envelope_authorized", cross_id, "wagering"), "Cross-session boundary id was accepted.")
	var malformed := envelope.duplicate(true)
	malformed["caller_handler"] = "blackjack_authority"
	_check(not game.call("blackjack_ritual_deal_envelope_authorized", malformed, "wagering"), "Unknown caller handler field bypassed the closed envelope.")
	var wrong_phase := envelope.duplicate(true)
	_check(not game.call("blackjack_ritual_deal_envelope_authorized", wrong_phase, "player_turn"), "Wagering deal envelope was accepted in player_turn.")


func _check_gesture_rejections_and_equivalence(game: GameModule) -> void:
	var fixture := _fixture(game, "GAME06-2-GESTURES", 0)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	var bankroll_before := run.wager_balance_for_game("blackjack", environment)
	var ui := {"selected_stake": 5, "surface_time_msec": 10000}
	var begin: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "begin", Vector2(720, 120), ui, run, environment)
	var rejected: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "end", Vector2(620, 220), begin.get("ui_state", {}), run, environment)
	_check(str(rejected.get("action_id", "")).is_empty(), "Incomplete cut gesture produced an authoritative action.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Incomplete cut gesture charged bankroll.")
	var drag_begin: Dictionary = game.surface_pointer_command("blackjack_wager_place_gesture", 1, "begin", Vector2(75, 398), ui, run, environment)
	var placed: Dictionary = game.surface_pointer_command("blackjack_wager_place_gesture", 1, "end", Vector2(452, 304), drag_begin.get("ui_state", {}), run, environment)
	_check(int(placed.get("set_stake", 0)) > 5, "Chip drag did not reach the same staged-wager handler as the button path.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Staging a dragged chip charged before confirmation.")
	var corrected := game.surface_action_command("blackjack_correct_bet", 3, false, placed.get("ui_state", {}), run, environment)
	_check(int(corrected.get("set_stake", 0)) == 25, "Correct-one did not replace the pending main wager with the named denomination.")
	var removed := game.surface_action_command("blackjack_remove_chip", 1, false, corrected.get("ui_state", {}), run, environment)
	_check(int(removed.get("set_stake", 0)) == 20, "Remove-one did not pull the named denomination from the pending main wager.")
	var undone := game.surface_action_command("blackjack_undo_bet", 0, false, removed.get("ui_state", {}), run, environment)
	_check(int(undone.get("set_stake", 0)) == 25, "Undo did not restore the immediately previous pending wager.")
	var table: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	table["last_result"] = {"main_stake": 10, "side_bet_ids": [], "bankroll_delta": 0}
	var repeated := game.surface_action_command("blackjack_repeat_bet", 0, false, undone.get("ui_state", {}), run, environment)
	_check(int(repeated.get("set_stake", 0)) == 10, "Repeat did not stage the last eligible resolved wager.")
	var cut_begin: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "begin", Vector2(720, 120), repeated.get("ui_state", {}), run, environment)
	var cut: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "end", Vector2(720, 120), cut_begin.get("ui_state", {}), run, environment)
	_check(str(cut.get("action_id", "")) == "blackjack_place_bet" and bool(cut.get("direct_resolve", false)), "Cut gesture did not reach the same confirm/deal authority as keyboard/controller action.")
	_check(game.call("blackjack_ritual_deal_envelope_authorized", cut.get("ritual_command", {}), "wagering"), "Live cut/deal command bypassed the frozen ritual envelope.")
	_check(str(cut.get("ritual_handler_id", "")) == "blackjack_authority", "Live cut/deal command did not bind its declared handler.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Cut gesture mutated bankroll before the authoritative resolve boundary.")
	var duplicate_end := game.surface_pointer_command("blackjack_cut_gesture", 0, "end", Vector2(720, 120), cut.get("ui_state", {}), run, environment)
	_check(str(duplicate_end.get("action_id", "")).is_empty(), "Repeated cut end produced a second deal/commit command.")


func _check_live_equivalent_bindings(game: GameModule) -> void:
	var input_kinds := ["keyboard", "controller", "reduced_motion"]
	for input_index in range(input_kinds.size()):
		var input_kind: String = input_kinds[input_index]
		var fixture := _fixture(game, "GAME06-2-EQUIVALENT-%s" % input_kind, 10 + input_index)
		var run: RunState = fixture.run
		var environment: Dictionary = fixture.environment
		var bankroll_before := run.wager_balance_for_game("blackjack", environment)
		var ui := {"selected_stake": 5, "surface_time_msec": 11000}
		var placed: Dictionary = game.call("blackjack_ritual_equivalent_command", input_kind, "blackjack_wager_place_gesture", "cycle", "wager.player", 1, ui, run, environment)
		_check(int(placed.get("set_stake", 0)) > 5, "%s chip equivalent did not reach the live staged-wager binding." % input_kind)
		_check(str(placed.get("ritual_target_selection", "")) == "cycle" and str(placed.get("ritual_target_id", "")) == "wager.player", "%s chip equivalent lost target selection authority." % input_kind)
		_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "%s chip equivalent charged before confirm." % input_kind)
		var dealt: Dictionary = game.call("blackjack_ritual_equivalent_command", input_kind, "blackjack_cut_gesture", "focus", "shoe.primary", 0, placed.get("ui_state", {}), run, environment)
		_check(str(dealt.get("action_id", "")) == "blackjack_place_bet", "%s cut equivalent did not reach the charged deal boundary." % input_kind)
		_check(game.call("blackjack_ritual_deal_envelope_authorized", dealt.get("ritual_command", {}), "wagering"), "%s cut equivalent emitted an unauthenticated deal." % input_kind)
		_check(bool(dealt.get("ritual_reduced_motion", false)) == (input_kind == "reduced_motion"), "%s equivalent reported the wrong reduced-motion path." % input_kind)
		var hostile_target: Dictionary = game.call("blackjack_ritual_equivalent_command", input_kind, "blackjack_cut_gesture", "focus", "wager.player", 0, ui, run, environment)
		_check(str(hostile_target.get("action_id", "")).is_empty(), "%s cross-target equivalent reached an authoritative action." % input_kind)
		_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "%s hostile target changed bankroll." % input_kind)


func _check_ten_seed_projection_isolation(game: GameModule) -> void:
	for seed_index in range(10):
		var fixture := _fixture(game, "GAME06-2-SEED-%02d" % seed_index, seed_index)
		var run: RunState = fixture.run
		var environment: Dictionary = fixture.environment
		var table_before: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {}).duplicate(true)
		var state := game.surface_state(run, environment, {"selected_stake": 5, "surface_time_msec": 12000 + seed_index})
		var projection: Dictionary = state.get("ritual_projection", {}) if typeof(state.get("ritual_projection", {})) == TYPE_DICTIONARY else {}
		for actor_value in projection.get("actors", []):
			if typeof(actor_value) == TYPE_DICTIONARY and str((actor_value as Dictionary).get("role", "")) == "neighbour":
				_check(str((actor_value as Dictionary).get("authority", "")) == "none", "Seed %d projected a neighbour with outcome authority." % seed_index)
		var table_after: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {})
		_check(table_before == table_after, "Seed %d ritual projection mutated authoritative table state." % seed_index)


func _check_energy_and_restore_projection(game: GameModule) -> void:
	var contract: Dictionary = game.call("blackjack_ritual_contract")
	var energy: Dictionary = contract.get("energy", {}) if typeof(contract.get("energy", {})) == TYPE_DICTIONARY else {}
	for tier_value in energy.get("tiers", []):
		var tier: Dictionary = tier_value if typeof(tier_value) == TYPE_DICTIONARY else {}
		var material_count := (tier.get("actor_operations", []) as Array).size() + (tier.get("object_operations", []) as Array).size() + (tier.get("interaction_operations", []) as Array).size()
		_check(material_count > 0, "Energy tier %s changes only text/music." % str(tier.get("id", "unknown")))
	var fixture := _fixture(game, "GAME06-2-ENERGY-RESTORE", 20)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	var quiet := game.surface_state(run, environment, {"selected_stake": 5, "surface_time_msec": 15000})
	_check(str((quiet.get("ritual_projection", {}) as Dictionary).get("energy_tier", "")) == "quiet", "Open table did not begin with material quiet energy.")
	run.add_suspicion("game06_2_watch", 45, "behavior", true, {"environment_id": str(environment.get("id", ""))})
	var watched := game.surface_state(run, environment, {"selected_stake": 5, "surface_time_msec": 15001})
	var watched_projection: Dictionary = watched.get("ritual_projection", {})
	_check(str(watched_projection.get("energy_tier", "")) == "watched", "Mid heat did not move the pit actor to the rail.")
	_check(_actor_visible(watched_projection, "pit.primary"), "Watched energy remained metadata-only; pit actor was not visible.")
	run.add_suspicion("game06_2_hot", 30, "behavior", true, {"environment_id": str(environment.get("id", ""))})
	var hot := game.surface_state(run, environment, {"selected_stake": 5, "surface_time_msec": 15002})
	var hot_projection: Dictionary = hot.get("ritual_projection", {})
	_check(str(hot_projection.get("energy_tier", "")) == "hot", "High heat did not project hot table energy.")
	_check(not _object_enabled(hot_projection, "rail.open_space"), "Hot energy did not materially block/narrow the open rail interaction.")
	var shoe_before: Array = (((environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("shoe", []) as Array).duplicate(true)
	var snapshot := run.to_save_snapshot()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	var restored_environment := restored.current_environment
	var restored_state := game.surface_state(restored, restored_environment, {"selected_stake": 5, "surface_time_msec": 15002})
	var restored_projection: Dictionary = restored_state.get("ritual_projection", {})
	var shoe_after: Array = ((((restored_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("shoe", [])) as Array)
	_check(shoe_before == shoe_after, "Restore rerolled or reordered the authoritative Blackjack shoe.")
	_check(str(restored_projection.get("phase_id", "")) == "wagering" and str(restored_projection.get("energy_tier", "")) == "hot", "Restore did not rebuild the same legal phase and material energy projection.")


func _check_host_authority_and_replay(game: GameModule) -> void:
	var fixture := _prepared_authority_fixture(game, "GAME06-2-HOST-AUTHORITY", 31, 5)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	var session: Dictionary = fixture.session
	var before_direct := RitualRuntimeScript.canonical_json(run.to_save_snapshot())
	var direct_rng := run.create_rng("game06_2_direct_bypass")
	var direct := game.resolve("play_basic", 5, run, environment, direct_rng)
	var direct_context := game.resolve_with_context("play_basic", 999, run, environment, direct_rng, {
		"selected_stake": 999,
		"player_hands": [{"cards": [{"rank": 14, "suit": 0}, {"rank": 14, "suit": 1}], "stood": true}],
		"dealer_cards": [{"rank": 2, "suit": 0}, {"rank": 3, "suit": 1}],
		"cheats_used": {"peek_hole_card": true},
	})
	_check(not bool(direct.get("ok", true)) and not bool(direct_context.get("ok", true)), "Bare Blackjack resolve entry points did not fail closed.")
	_check(game.wager_cost_for_context("play_basic", 999, run, environment, session) == 0, "Bare Blackjack wager preview retained caller authority.")
	_check(RitualRuntimeScript.canonical_json(run.to_save_snapshot()) == before_direct, "Bare Blackjack resolve/cost changed authoritative RunState or RNG.")

	var forged_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "play_basic",
		"action_kind": "legal",
		"stake": 5,
		"bankroll_delta": 100,
		"deltas": {"bankroll_delta": 100},
		"environment_id": str(environment.get("id", "")),
	})
	GameModule.apply_result(run, forged_result, run.create_rng("game06_2_forged_apply"))
	_check(RitualRuntimeScript.canonical_json(run.to_save_snapshot()) == before_direct, "Forged Blackjack result bypassed the pending host receipt.")

	var table: Dictionary = game.call("_table_state_preview", run, environment)
	var forged_ui := session.duplicate(true)
	forged_ui["selected_stake"] = 999
	forged_ui["locked_stake"] = 999
	forged_ui["player_hands"] = [{"cards": [{"rank": 14, "suit": 0}, {"rank": 14, "suit": 1}], "stood": true}]
	forged_ui["dealer_cards"] = [{"rank": 2, "suit": 0}, {"rank": 3, "suit": 1}]
	forged_ui["cheats_used"] = {"peek_hole_card": true}
	var normalized: Dictionary = game.call("_normalized_session", run, environment, forged_ui, table)
	_check(int(normalized.get("locked_stake", 0)) == 5, "Caller UI replaced the host-owned Blackjack wager.")
	_check(normalized.get("player_hands", []) == session.get("player_hands", []), "Caller UI replaced host-owned Blackjack cards.")
	_check(not bool((normalized.get("cheats_used", {}) as Dictionary).get("peek_hole_card", false)), "Caller UI forged a Blackjack cheat fact.")

	var authority: RefCounted = BlackjackActionAuthorityScript.new(game, run, environment, 5, "game06_2_authority")
	var result: Dictionary = authority.call("submit_resolve_intent", "play_basic")
	_check(bool(result.get("ok", false)) and bool(result.get("blackjack_host_committed", false)), "Host Blackjack authority did not accept a prepared legal settlement.")
	var request_key := str(result.get("blackjack_host_request_key", ""))
	_check(not request_key.is_empty(), "Accepted Blackjack transaction has no host request key.")
	var committed_snapshot := RitualRuntimeScript.canonical_json(run.to_save_snapshot())
	var replay: Dictionary = authority.call("replay_request", request_key)
	_check(RitualRuntimeScript.canonical_json(replay) == RitualRuntimeScript.canonical_json(result), "Same-process Blackjack replay was not byte-identical.")
	_check(RitualRuntimeScript.canonical_json(run.to_save_snapshot()) == committed_snapshot, "Blackjack replay mutated committed state or RNG.")
	GameModule.apply_result(run, result, run.create_rng("game06_2_duplicate_apply"))
	_check(RitualRuntimeScript.canonical_json(run.to_save_snapshot()) == committed_snapshot, "Duplicate Blackjack result apply escaped exactly-once receipt consumption.")

	var restored: RunState = RunStateScript.new()
	restored.from_dict(run.to_save_snapshot())
	var restored_environment: Dictionary = restored.current_environment
	var restored_authority: RefCounted = BlackjackActionAuthorityScript.new(game, restored, restored_environment, 5, "game06_2_authority")
	var restored_before := RitualRuntimeScript.canonical_json(restored.to_save_snapshot())
	var restored_replay: Dictionary = restored_authority.call("replay_request", request_key)
	_check(RitualRuntimeScript.canonical_json(restored_replay) == RitualRuntimeScript.canonical_json(result), "Save/restore Blackjack replay was not byte-identical.")
	_check(RitualRuntimeScript.canonical_json(restored.to_save_snapshot()) == restored_before, "Save/restore replay mutated the restored transaction ledger.")
	var restored_table: Dictionary = game.call("_table_state_preview", restored, restored_environment)
	var restored_ledger: Dictionary = restored_table.get("_blackjack_action_authority", {})
	_check(int(restored_ledger.get("next_request_ordinal", 0)) >= 2 and (restored_ledger.get("request_order", []) as Array).has(request_key), "Blackjack host request sequence/cache did not survive restore.")


func _check_failure_atomic_rng_retry(game: GameModule) -> void:
	var retry_fixture := _prepared_authority_fixture(game, "GAME06-2-RNG-ROLLBACK", 32, 5)
	var control_fixture := _prepared_authority_fixture(game, "GAME06-2-RNG-ROLLBACK", 32, 5)
	var retry_run: RunState = retry_fixture.run
	var retry_environment: Dictionary = retry_fixture.environment
	var before := RitualRuntimeScript.canonical_json(retry_run.to_save_snapshot())
	var rejecting_authority: RefCounted = BlackjackActionAuthorityScript.new(
		game,
		retry_run,
		retry_environment,
		5,
		"game06_2_rollback",
		Callable(self, "_reject_blackjack_candidate")
	)
	var rejected: Dictionary = rejecting_authority.call("submit_resolve_intent", "play_basic")
	_check(not bool(rejected.get("ok", true)) and str(rejected.get("error_code", "")) == "candidate_rejected", "Post-RNG candidate rejection did not fail closed.")
	_check(RitualRuntimeScript.canonical_json(retry_run.to_save_snapshot()) == before, "Post-RNG candidate rejection burned funding, RNG, receipt, or request sequence.")
	var retry_authority: RefCounted = BlackjackActionAuthorityScript.new(game, retry_run, retry_environment, 5, "game06_2_rollback")
	var retry_result: Dictionary = retry_authority.call("submit_resolve_intent", "play_basic")
	var control_authority: RefCounted = BlackjackActionAuthorityScript.new(game, control_fixture.run, control_fixture.environment, 5, "game06_2_rollback")
	var control_result: Dictionary = control_authority.call("submit_resolve_intent", "play_basic")
	_check(RitualRuntimeScript.canonical_json(retry_result) == RitualRuntimeScript.canonical_json(control_result), "Legitimate retry after post-RNG rejection diverged from clean control.")
	_check(RitualRuntimeScript.canonical_json(retry_run.to_save_snapshot()) == RitualRuntimeScript.canonical_json(control_fixture.run.to_save_snapshot()), "Post-RNG retry committed different state/RNG than clean control.")


func _check_mixed_rate_funding_rejection(game: GameModule) -> void:
	var fixture := _prepared_authority_fixture(game, "GAME06-2-MIXED-RATE", 33, 3)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	environment["archetype_id"] = "grand_casino"
	environment["local_narrative_flags"] = {"casino_chip_cash_rate": 3}
	run.current_environment = environment
	run.bankroll = 2
	run.grand_casino_chips = 2
	var preview := run.preview_grand_casino_wager_funding("blackjack", 3, environment)
	_check(not bool(preview.get("ok", true)) and int(preview.get("cash_used", -1)) == 0, "Mixed-rate Blackjack funding preview accepted two chips plus insufficient cash.")
	var before := RitualRuntimeScript.canonical_json(run.to_save_snapshot())
	var authority: RefCounted = BlackjackActionAuthorityScript.new(game, run, environment, 3, "game06_2_mixed_rate")
	var rejected: Dictionary = authority.call("submit_resolve_intent", "play_basic")
	_check(not bool(rejected.get("ok", true)) and str(rejected.get("error_code", "")) == "insufficient_funds", "Blackjack authority accepted an underfunded mixed-rate wager.")
	_check(RitualRuntimeScript.canonical_json(run.to_save_snapshot()) == before, "Mixed-rate funding rejection changed chips, cash, RNG, or authority sequence.")


func _prepared_authority_fixture(game: GameModule, seed_text: String, seed_index: int, stake: int) -> Dictionary:
	var fixture := _fixture(game, seed_text, seed_index)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	var deal: Dictionary = game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": stake, "surface_time_msec": 20000}, run, environment)
	var stand: Dictionary = game.surface_action_command("blackjack_stand", 0, true, deal.get("ui_state", {}), run, environment)
	var session: Dictionary = stand.get("ui_state", {}) if typeof(stand.get("ui_state", {})) == TYPE_DICTIONARY else deal.get("ui_state", {})
	_seed_authority_session(game, run, environment, session)
	return {"run": run, "environment": environment, "session": session}


func _seed_authority_session(game: GameModule, run: RunState, environment: Dictionary, session: Dictionary) -> void:
	var table: Dictionary = game.call("_table_state", run, environment)
	table["_blackjack_action_authority"] = {
		"version": 1,
		"initialized": true,
		"next_request_ordinal": 1,
		"boundary_ordinal": 0,
		"session": session.duplicate(true),
		"request_cache": {},
		"request_order": [],
	}
	game.call("_update_environment_table", environment, table)
	run.current_environment = environment


func _reject_blackjack_candidate(_candidate: RunState, _result: Dictionary) -> bool:
	return false


func _actor_visible(projection: Dictionary, actor_id: String) -> bool:
	for actor_value in projection.get("actors", []):
		if typeof(actor_value) == TYPE_DICTIONARY and str((actor_value as Dictionary).get("id", "")) == actor_id:
			return bool((actor_value as Dictionary).get("visible", false))
	return false


func _object_enabled(projection: Dictionary, object_id: String) -> bool:
	for object_value in projection.get("scene_objects", []):
		if typeof(object_value) == TYPE_DICTIONARY and str((object_value as Dictionary).get("id", "")) == object_id:
			return bool((object_value as Dictionary).get("enabled", false))
	return false


func _fixture(game: GameModule, seed_text: String, seed_index: int) -> Dictionary:
	var run: RunState = RunStateScript.new()
	run.start_new(seed_text)
	run.change_bankroll(1000)
	var environment := {
		"id": "game06_2_room_%02d" % seed_index,
		"display_name": "Blackjack Contract Room",
		"depth": seed_index % 3,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "low"},
	}
	var table := game.generate_environment_state(run, environment, run.create_rng("table:%02d" % seed_index))
	environment["game_states"] = {"blackjack": table}
	run.current_environment = environment
	return {"run": run, "environment": environment}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
