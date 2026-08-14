extends RefCounted

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const EXPECTED := {
	"small_underground_casino": ["punchline_open_mic_night", "punchline_headliner_night", "punchline_bringer_show", "punchline_high_stakes_night", "punchline_greased_week", "punchline_debt_court"],
	"jazz_club": ["jazz_club_guest_legend", "jazz_club_rent_party", "jazz_club_recording_night"],
	"kitty_cat_lounge": ["kitty_cat_lounge_amateur_night", "kitty_cat_lounge_buyout", "kitty_cat_lounge_slow_night"],
	"delta_queen": ["delta_queen_wedding_charter", "delta_queen_whale_aboard", "delta_queen_fog_delay", "delta_queen_engine_trouble"],
	"beach": ["beach_bonfire_night", "beach_storm_coming", "beach_festival_weekend"],
	"pawn_shop": ["pawn_shop_estate_lot_day", "pawn_shop_serial_check_day", "pawn_shop_sals_mood"],
	"grand_casino": ["grand_casino_gala_night", "grand_casino_convention_crowd", "grand_casino_audit_night"],
}
const SACRED_GRAND_FIELDS := [
	"demo_objective", "game_ids", "service_ids", "lender_hooks", "travel_hooks",
	"next_archetypes", "grand_casino_room", "grand_casino_room_links",
	"economic_profile", "security_profile",
]
const ALLOWED_GRAND_MUTATION_KEYS := [
	"staff_set", "patron_set", "event_pool_add", "game_modifier_hooks",
	"music_profile_override", "presentation", "exclusive_opportunity", "hook_flags",
]


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_catalog(library, failures)
	_check_seed_reach(library, failures)
	_check_punchline_layers(library, failures)
	_check_jazz_arc(library, failures)
	_check_engine_lock(library, failures)
	_check_debt_court(library, failures)
	_check_buyout_gate(library, failures)
	_check_estate_lot(library, failures)
	_check_anchor_ownership(library, failures)
	_check_grand_casino_routes(library, failures)


static func _check_catalog(library: ContentLibrary, failures: Array) -> void:
	var total := 0
	for archetype_id_value in EXPECTED.keys():
		var archetype_id := str(archetype_id_value)
		var expected_ids: Array = EXPECTED.get(archetype_id, [])
		var definitions := library.scenarios_for_archetype(archetype_id)
		var actual_ids: Array = []
		for definition_value in definitions:
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var definition := definition_value as Dictionary
			var scenario_id := str(definition.get("id", ""))
			actual_ids.append(scenario_id)
			var mutations := _dict(definition.get("mutations", {}))
			var axis_count := 0
			for axis in ["patron_set", "staff_set", "event_pool_add", "economic_profile_overrides", "game_modifier_hooks", "service_add", "music_profile_override", "security_overrides", "item_offer_add", "travel_lock_actions"]:
				if mutations.has(axis):
					axis_count += 1
			if axis_count < 3:
				failures.append("Scenario %s has fewer than three mutation axes." % scenario_id)
			if _dict(mutations.get("presentation", {})).is_empty() or _dict(mutations.get("exclusive_opportunity", {})).is_empty() or _dict(mutations.get("hook_flags", {})).is_empty():
				failures.append("Scenario %s is missing presentation, exclusive content, or hook flags." % scenario_id)
		if actual_ids != expected_ids:
			failures.append("Scenario catalog mismatch for %s: %s." % [archetype_id, JSON.stringify(actual_ids)])
		total += definitions.size()
	if total != 25:
		failures.append("Tier-2/Grand scenario catalog must contain exactly 25 entries, found %d." % total)


static func _check_seed_reach(library: ContentLibrary, failures: Array) -> void:
	var reached := {}
	for seed_index in range(20):
		var run_state := RunStateScript.new()
		run_state.start_new("TIER2-REACH-%02d" % seed_index)
		var generator := RunGeneratorScript.new(library)
		for archetype_id_value in EXPECTED.keys():
			var archetype_id := str(archetype_id_value)
			var selected: Dictionary = generator.call("_select_scenario", run_state, archetype_id, run_state.create_rng("tier2_reach:%s" % archetype_id))
			var scenario_id := str(selected.get("id", ""))
			if not scenario_id.is_empty():
				reached[scenario_id] = true
	for ids_value in EXPECTED.values():
		for scenario_id_value in ids_value as Array:
			if not reached.has(str(scenario_id_value)):
				failures.append("20-seed selector sweep starved %s." % str(scenario_id_value))


static func _check_punchline_layers(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype("small_underground_casino")
	for scenario_id_value in EXPECTED["small_underground_casino"]:
		var scenario_id := str(scenario_id_value)
		var definition := library.scenario(scenario_id)
		var target_layer := str(definition.get("layer_id", ""))
		var event_id := str(_dict(_dict(definition.get("mutations", {})).get("exclusive_opportunity", {})).get("event_id", ""))
		var event_definition := library.event(event_id)
		if not _array(event_definition.get("scopes", [])).has(target_layer):
			failures.append("Punchline scenario %s exclusive %s is not scoped to %s." % [scenario_id, event_id, target_layer])
		for layer_id in ["club", "casino"]:
			var run_state := RunStateScript.new()
			run_state.start_new("LAYER-%s-%s" % [scenario_id, layer_id])
			var environment := EnvironmentInstanceScript.from_archetype_layer(archetype, layer_id, 2, run_state.create_rng("layer"), library, {}, definition).to_dict()
			var attached := _array(environment.get("event_ids", [])).has(event_id)
			if layer_id == target_layer and not attached:
				failures.append("Punchline scenario %s did not attach to %s." % [scenario_id, layer_id])
			elif layer_id == target_layer:
				run_state.set_environment(environment)
				var module := EventModuleScript.new()
				module.setup(event_definition, library)
				if not module.can_trigger(run_state, run_state.current_environment):
					failures.append("Punchline scenario %s exclusive is attached but not selectable on %s." % [scenario_id, layer_id])
			elif attached:
				failures.append("Punchline scenario %s leaked into %s." % [scenario_id, layer_id])


static func _check_jazz_arc(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype("jazz_club")
	for scenario_id_value in EXPECTED["jazz_club"]:
		var scenario_id := str(scenario_id_value)
		var baseline_run := RunStateScript.new()
		baseline_run.start_new("JAZZ-%s" % scenario_id)
		var scenario_run := RunStateScript.new()
		scenario_run.start_new("JAZZ-%s" % scenario_id)
		var baseline := EnvironmentInstanceScript.from_archetype(archetype, 2, baseline_run.create_rng("jazz"), library).to_dict()
		var overlaid := EnvironmentInstanceScript.from_archetype(archetype, 2, scenario_run.create_rng("jazz"), library, {}, library.scenario(scenario_id)).to_dict()
		var baseline_music := _dict(baseline.get("music_profile", {}))
		var overlaid_music := _dict(overlaid.get("music_profile", {}))
		var baseline_choreography := _dict(baseline_music.get("layer_choreography", {}))
		var stage_ids: Array = []
		for stage_value in _array(baseline_choreography.get("stages", [])):
			if typeof(stage_value) == TYPE_DICTIONARY:
				stage_ids.append(str((stage_value as Dictionary).get("id", "")))
		if stage_ids != ["sparse", "build_bass", "build_drums", "peak", "release", "rebuild"]:
			failures.append("Jazz baseline lost its sparse-build-peak-release-rebuild stage order.")
		if not _json_equal(baseline_choreography, _dict(overlaid_music.get("layer_choreography", {}))):
			failures.append("Jazz scenario %s changed layer_choreography stage timing or order." % scenario_id)
		for field_name in ["choreography", "choreography_profile", "arrangement"]:
			if baseline_music.has(field_name) and not _json_equal(baseline_music.get(field_name), overlaid_music.get(field_name)):
				failures.append("Jazz scenario %s changed set-arc field %s." % [scenario_id, field_name])


static func _check_engine_lock(library: ContentLibrary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("ENGINE-LOCK")
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("delta_queen"), 2, run_state.create_rng("engine"), library, {}, library.scenario("delta_queen_engine_trouble")).to_dict()
	run_state.set_environment(environment)
	if run_state.current_travel_lock_remaining() != 5:
		failures.append("Engine Trouble did not engage its five-action travel lock.")
	run_state.advance_environment_turns(2)
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if restored.current_travel_lock_remaining() != 3:
		failures.append("Engine Trouble save/load did not preserve its mid-lock countdown.")
	restored.advance_environment_turns(3)
	if restored.current_travel_lock_remaining() != 0 or int(restored.current_environment.get("scenario_phase_index", -1)) != 2:
		failures.append("Engine Trouble did not expire its lock by the underway phase.")


static func _check_debt_court(library: ContentLibrary, failures: Array) -> void:
	var definition := library.scenario("punchline_debt_court")
	var archetype := library.environment_archetype("small_underground_casino")
	var run_state := RunStateScript.new()
	run_state.start_new("DEBT-COURT")
	run_state.bankroll = 500
	run_state.add_debt({"id": "debt_court_fixture", "lender_id": "street_lender", "debt_kind": "cash", "status": "active", "balance": 100, "principal": 100, "deadline_turns": 4, "turns_remaining": 4})
	run_state.set_environment(EnvironmentInstanceScript.from_archetype_layer(archetype, "casino", 2, run_state.create_rng("court"), library, {}, definition).to_dict())
	var module := EventModuleScript.new()
	module.setup(library.event("scenario_debt_court_office_hours"), library)
	var result := module.resolve(run_state, run_state.current_environment, "settle_the_marker")
	if not bool(result.get("ok", false)) or run_state.bankroll != 425 or not run_state.debt.is_empty() or not bool(run_state.narrative_flags.get("debt_court_settlement", false)):
		failures.append("Debt Court did not settle the $100 marker for the configured $75 payment.")
	var witness := RunStateScript.new()
	witness.start_new("DEBT-COURT-WITNESS")
	witness.set_environment(EnvironmentInstanceScript.from_archetype_layer(archetype, "casino", 2, witness.create_rng("court"), library, {}, definition).to_dict())
	var witness_result := module.resolve(witness, witness.current_environment, "watch_the_next_name")
	if not bool(witness_result.get("ok", false)) or not bool(witness.narrative_flags.get("debt_court_witness_beat", false)):
		failures.append("Debt Court did not deliver its no-debt witness beat.")


static func _check_buyout_gate(library: ContentLibrary, failures: Array) -> void:
	var module := EventModuleScript.new()
	module.setup(library.event("scenario_buyout_rope"), library)
	var environment := {"id": "buyout_fixture", "archetype_id": "kitty_cat_lounge", "kind": "casino", "tier": 2, "event_ids": ["scenario_buyout_rope"], "resolved_event_ids": []}
	var denied := RunStateScript.new()
	denied.start_new("BUYOUT-DENIED")
	denied.set_environment(environment.duplicate(true))
	if not bool(module.resolve(denied, denied.current_environment, "test_the_rope").get("ok", false)) or not bool(denied.narrative_flags.get("kitty_cat_buyout_denied", false)):
		failures.append("The Buyout did not preserve the authored denied path.")
	var admitted := RunStateScript.new()
	admitted.start_new("BUYOUT-ADMITTED")
	admitted.narrative_flags["grand_casino_invite"] = true
	admitted.set_environment(environment.duplicate(true))
	if not bool(module.resolve(admitted, admitted.current_environment, "use_the_name").get("ok", false)) or not bool(admitted.narrative_flags.get("velvet_buyout_contact", false)):
		failures.append("The Buyout did not admit a named guest or set Velvet's anchor.")


static func _check_estate_lot(library: ContentLibrary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("ESTATE-LOT")
	run_state.bankroll = 1000
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("pawn_shop"), 2, run_state.create_rng("estate"), library, {}, library.scenario("pawn_shop_estate_lot_day")).to_dict()
	run_state.set_environment(environment)
	var found := {}
	for offer_value in _array(run_state.current_environment.get("item_offers", [])):
		if typeof(offer_value) == TYPE_DICTIONARY and bool((offer_value as Dictionary).get("estate_lot", false)):
			found[str((offer_value as Dictionary).get("id", ""))] = offer_value
	if not found.has("roadside_map") or not found.has("false_bottom_cup") or not bool(_dict(found.get("roadside_map", {})).get("chain06_1_component", false)) or not bool(_dict(found.get("false_bottom_cup", {})).get("heist_plan_b_component", false)):
		failures.append("Estate Lot Day did not expose both one-off resale-shelf component offers.")
		return
	var resolver := RunActionServiceScript.new()
	resolver.setup(library, run_state)
	if not bool(resolver.buy_item_offer("roadside_map").get("ok", false)) or _offer_ids(run_state.current_environment).has("roadside_map"):
		failures.append("Estate Lot production purchase did not consume the Roadside Map offer.")
		return
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if _offer_ids(restored.current_environment).has("roadside_map") or not _offer_ids(restored.current_environment).has("false_bottom_cup"):
		failures.append("Estate Lot save/load regenerated a purchased offer or lost the unpurchased offer.")
		return
	var restored_resolver := RunActionServiceScript.new()
	restored_resolver.setup(library, restored)
	if bool(restored_resolver.buy_item_offer("roadside_map").get("ok", false)) or not bool(restored_resolver.buy_item_offer("false_bottom_cup").get("ok", false)):
		failures.append("Estate Lot one-off offers did not enforce production purchase/removal semantics.")
		return
	var twice_restored := RunStateScript.new()
	twice_restored.from_dict(restored.to_dict())
	var final_offer_ids := _offer_ids(twice_restored.current_environment)
	if final_offer_ids.has("roadside_map") or final_offer_ids.has("false_bottom_cup"):
		failures.append("Estate Lot purchased offers did not stay removed across a second save/load.")


static func _check_anchor_ownership(library: ContentLibrary, failures: Array) -> void:
	var whale := _dict(_dict(library.scenario("delta_queen_whale_aboard").get("mutations", {})).get("hook_flags", {}))
	var audit := _dict(_dict(library.scenario("grand_casino_audit_night").get("mutations", {})).get("hook_flags", {}))
	var gala := _dict(_dict(library.scenario("grand_casino_gala_night").get("mutations", {})).get("hook_flags", {}))
	if not bool(whale.get("heist_plan_b_criteria", false)) or not bool(audit.get("heist_plan_a_criteria", false)):
		failures.append("Whale Aboard and Audit Night did not own their required heist anchors.")
	for key_value in gala.keys():
		if str(key_value).contains("heist") or str(key_value).contains("plan_b"):
			failures.append("Gala Night acquired a heist criterion outside its allowed texture scope.")
	if not _array(library.scenario("pawn_shop_serial_check_day").get("town_weight_tags", [])).has("law:pressure"):
		failures.append("Serial-Check Day lost the Police Sweep pressure seam tag.")


static func _check_grand_casino_routes(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype("grand_casino")
	for scenario_id_value in EXPECTED["grand_casino"]:
		var scenario_id := str(scenario_id_value)
		var definition := library.scenario(scenario_id)
		var mutations := _dict(definition.get("mutations", {}))
		for mutation_key_value in mutations.keys():
			if not ALLOWED_GRAND_MUTATION_KEYS.has(str(mutation_key_value)):
				failures.append("Grand scenario %s exceeded texture/crowd/comps/heat scope with %s." % [scenario_id, str(mutation_key_value)])
		for modifier_key_value in _dict(mutations.get("game_modifier_hooks", {})).keys():
			if not ["comp_texture", "floor_heat"].has(str(modifier_key_value)):
				failures.append("Grand scenario %s restored forbidden gameplay modifier %s." % [scenario_id, str(modifier_key_value)])
		var hooks := _dict(mutations.get("hook_flags", {}))
		var expected_hooks := {
			"grand_casino_gala_night": {"gala_night": true},
			"grand_casino_convention_crowd": {"convention_crowd": true},
			"grand_casino_audit_night": {"audit_night": true, "heist_plan_a_criteria": true},
		}
		if not _json_equal(hooks, _dict(expected_hooks.get(scenario_id, {}))):
			failures.append("Grand scenario %s must expose only its exact inert identity/criterion flags." % scenario_id)
		var event_id := str(_dict(mutations.get("exclusive_opportunity", {})).get("event_id", ""))
		for choice_value in _array(_dict(library.event(event_id).get("payload", {})).get("choices", [])):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			for consequence_key_value in _dict((choice_value as Dictionary).get("consequences", {})).keys():
				if not ["suspicion_delta", "resolve_event"].has(str(consequence_key_value)):
					failures.append("Grand scenario %s exclusive restored non-heat consequence %s." % [scenario_id, str(consequence_key_value)])
		var baseline_run := RunStateScript.new()
		baseline_run.start_new("GRAND-%s" % scenario_id)
		var scenario_run := RunStateScript.new()
		scenario_run.start_new("GRAND-%s" % scenario_id)
		var baseline := EnvironmentInstanceScript.from_archetype(archetype, 3, baseline_run.create_rng("grand"), library).to_dict()
		var environment := EnvironmentInstanceScript.from_archetype(archetype, 3, scenario_run.create_rng("grand"), library, {}, definition).to_dict()
		for field_name in SACRED_GRAND_FIELDS:
			if baseline.has(field_name) and not _json_equal(baseline.get(field_name), environment.get(field_name)):
				failures.append("Grand scenario %s changed sacred field %s." % [scenario_id, field_name])
		_check_clean_route(library, scenario_id, environment, failures)
		_check_showdown_route(library, scenario_id, environment, failures)


static func _check_clean_route(library: ContentLibrary, scenario_id: String, environment: Dictionary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("CLEAN-%s" % scenario_id)
	run_state.set_environment(environment.duplicate(true))
	var generator := RunGeneratorScript.new(library)
	for expected_tier in [RunStateScript.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE, RunStateScript.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER]:
		var status := run_state.demo_objective_status()
		_qualify_card_segment(run_state, int(status.get("players_card_next_min_games", 0)), int(status.get("players_card_next_net_winnings", 0)))
		if not bool(generator.enter_grand_casino_room(run_state, RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID)):
			failures.append("Grand scenario %s blocked Cage entry on the clean route." % scenario_id)
			return
		var claim := run_state.claim_grand_casino_players_card_tier()
		if not bool(claim.get("ok", false)) or str(claim.get("tier", "")) != expected_tier:
			failures.append("Grand scenario %s blocked %s Players Card claim." % [scenario_id, expected_tier])
			return
		if not bool(generator.enter_grand_casino_room(run_state, RunStateScript.GRAND_CASINO_ARCHETYPE_ID)):
			failures.append("Grand scenario %s blocked return to the Main Floor." % scenario_id)
			return
	var gold_status := run_state.demo_objective_status()
	_qualify_card_segment(run_state, int(gold_status.get("players_card_next_min_games", 0)), int(gold_status.get("players_card_next_net_winnings", 0)))
	if not bool(generator.enter_grand_casino_room(run_state, RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID)):
		failures.append("Grand scenario %s blocked the Gold review." % scenario_id)
		return
	var cashout := EventModuleScript.new()
	cashout.setup(library.event("high_roller_cashout"), library)
	var result := cashout.resolve(run_state, run_state.current_environment, "high_roller_cashout")
	if not bool(result.get("ok", false)) or run_state.run_status != RunStateScript.RUN_STATUS_ENDED or str(run_state.narrative_flags.get("demo_victory_route", "")) != "high_roller_cashout":
		failures.append("Grand scenario %s did not complete the clean-route victory." % scenario_id)


static func _qualify_card_segment(run_state: RunState, game_count: int, net_winnings: int) -> void:
	var start_games := maxi(0, int(run_state.narrative_flags.get("grand_casino_games_played", 0)))
	for game_index in range(start_games, start_games + maxi(0, game_count)):
		var deltas := GameModuleScript.empty_result_deltas()
		deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 5 + game_index}]
		var result := GameModuleScript.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "play_basic",
			"action_kind": "legal",
			"stake": 5 + game_index,
			"deltas": deltas,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
			"message": "Clean scenario Players Card progress.",
		})
		run_state.record_grand_casino_game_result(result)
	var entry_bankroll := int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.grand_casino_total_money()))
	var segment_start_net := int(run_state.narrative_flags.get("grand_casino_players_card_segment_start_net_winnings", 0))
	run_state.bankroll = maxi(0, entry_bankroll + segment_start_net + net_winnings - run_state.grand_casino_chips)
	run_state.evaluate_environment_objective_state()


static func _check_showdown_route(library: ContentLibrary, scenario_id: String, environment: Dictionary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("SHOWDOWN-%s" % scenario_id)
	run_state.set_environment(environment.duplicate(true))
	run_state.narrative_flags["grand_casino_showdown_pending"] = true
	var module := EventModuleScript.new()
	module.setup(library.event(RunStateScript.GRAND_CASINO_SHOWDOWN_EVENT_ID), library)
	if not bool(module.resolve(run_state, run_state.current_environment, "enter_back_room").get("ok", false)):
		failures.append("Grand scenario %s blocked showdown start." % scenario_id)
		return
	if not bool(module.resolve(run_state, run_state.current_environment, "keep_everything").get("ok", false)) or not bool(module.resolve(run_state, run_state.current_environment, "face_rourke").get("ok", false)):
		failures.append("Grand scenario %s blocked showdown walk or pat-down." % scenario_id)
		return
	while str(run_state.narrative_flags.get("grand_casino_showdown_step", "")) == RunStateScript.GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
		if not bool(module.resolve(run_state, run_state.current_environment, "hold_steady").get("ok", false)):
			failures.append("Grand scenario %s blocked showdown interrogation." % scenario_id)
			return
	var duel := run_state.grand_casino_duel_status()
	if str(duel.get("status", "")) != "active":
		failures.append("Grand scenario %s did not reach the Rourke duel." % scenario_id)
		return
	duel["player_stack"] = 100
	duel["rourke_stack"] = 1
	run_state.narrative_flags["grand_casino_duel_state"] = duel
	run_state.apply_grand_casino_duel_hand({"transfer": 1, "message": "Scenario regression hand."})
	if run_state.run_status != RunStateScript.RUN_STATUS_ENDED or str(run_state.narrative_flags.get("demo_victory_route", "")) != RunStateScript.GRAND_CASINO_SHOWDOWN_ROUTE:
		failures.append("Grand scenario %s did not complete the showdown victory." % scenario_id)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _offer_ids(environment: Dictionary) -> Array:
	var result: Array = []
	for offer_value in _array(environment.get("item_offers", [])):
		if typeof(offer_value) == TYPE_DICTIONARY:
			result.append(str((offer_value as Dictionary).get("id", "")))
	return result


static func _json_equal(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)
