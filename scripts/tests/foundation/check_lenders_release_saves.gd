extends "res://scripts/tests/foundation/check_items_events_world.gd"

const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const CageWindowViewModelScript := preload("res://scripts/ui/cage_window_view_model.gd")


func _check_run_report_foundation(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("RUN-REPORT-FOUNDATION")
	run_state.set_environment({"id": "bar_fixture", "world_node_id": "bar", "archetype_id": "bar", "display_name": "Fixture Bar"})
	run_state.add_suspicion("report_spike", 34, "behavior", true, {"environment_id": "bar_fixture"})
	run_state.advance_environment_turns(2)
	run_state.set_environment({"id": "casino_fixture", "world_node_id": "grand_casino", "archetype_id": "grand_casino", "display_name": "Grand Casino"})
	if run_state.heat_history.size() < 3 or not bool((run_state.heat_history[-1] as Dictionary).get("transition", false)):
		failures.append("Run report heat history did not record heat changes and environment transitions.")
	if int((run_state.heat_history[-1] as Dictionary).get("game_clock_minutes", -1)) != run_state.game_clock_minutes:
		failures.append("Run report heat history did not timestamp transitions with the existing game clock.")
	if run_state.environment_history.is_empty() or int((run_state.environment_history[0] as Dictionary).get("entered_game_clock_minutes", -1)) != RunState.GAME_CLOCK_START_MINUTE or int(run_state.current_environment.get("entered_game_clock_minutes", -1)) != run_state.game_clock_minutes:
		failures.append("Run environment visits did not retain their game-clock entry times.")
	var saved := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved)
	if JSON.stringify(restored.heat_history) != JSON.stringify(run_state.heat_history):
		failures.append("Run report heat history did not survive save/load exactly.")
	var oversized: Array = []
	for index in range(600):
		oversized.append({"action_index": index, "heat_value": 100 if index == 311 else index % 47, "environment_id": "venue_%d" % int(index / 100), "environment_name": "Venue", "transition": index % 100 == 0})
	var compacted := RunStateScript.downsample_heat_history(oversized, RunStateScript.HEAT_HISTORY_COMPACT_TARGET)
	if compacted.size() > RunStateScript.HEAT_HISTORY_COMPACT_TARGET:
		failures.append("Run report heat history downsampling exceeded its compact target.")
	var preserved_peak := false
	for value in compacted:
		if int((value as Dictionary).get("action_index", -1)) == 311 and int((value as Dictionary).get("heat_value", 0)) == 100:
			preserved_peak = true
	if not preserved_peak:
		failures.append("Run report heat downsampling did not preserve an obvious spike.")

	var story := [
		{"type": "game_action", "game_id": "slot", "bankroll_delta": 120},
		{"type": "game_action", "game_id": "slot", "bankroll_delta": -20},
		{"type": "game_action", "game_id": "bar_dice", "bankroll_delta": -85},
		{"type": "item_sale", "item_id": "instant_coffee", "sale_price": 7},
		{"type": "item_purchase", "item_id": "creased_luck_card", "price": 9},
		{"type": "lender_hook", "id": "sal", "label": "Sal", "bankroll_delta": 20, "debt_changes": [{"id": "pawn_redeemed", "lender_id": "sal", "principal": 20, "balance": 22, "debt_kind": "pawn", "collateral_item_id": "instant_coffee", "collateral_item_name": "Instant Coffee"}]},
		{"type": "debt_paid", "debt_id": "pawn_redeemed", "lender_id": "sal", "collateral_item_id": "instant_coffee", "bankroll_delta": -22},
		{"type": "lender_hook", "id": "sal", "label": "Sal", "bankroll_delta": 30, "debt_changes": [{"id": "pawn_forfeit", "lender_id": "sal", "principal": 30, "balance": 33, "debt_kind": "pawn", "collateral_item_id": "creased_luck_card", "collateral_item_name": "Creased Luck Card"}]},
		{"type": "debt_default", "debt_id": "pawn_forfeit", "lender_id": "sal"},
		{"type": "lender_hook", "id": "crew", "label": "The Crew", "bankroll_delta": 50, "debt_changes": [{"id": "cash_default", "lender_id": "crew", "principal": 50, "balance": 50, "debt_kind": "cash"}]},
		{"type": "debt_default", "debt_id": "cash_default", "lender_id": "crew"},
	]
	var money := RunReportViewModelScript.build_money_rows(story, {"games": {"slot": {"display_name": "Slots"}, "bar_dice": {"display_name": "Bar Dice"}}})
	if money.is_empty() or int((money[0] as Dictionary).get("net", 0)) != 100:
		failures.append("Run report money aggregation did not net and absolute-sort scripted game results.")
	var debts := RunReportViewModelScript.build_debt_ledger([], story)
	if debts.size() != 3 or JSON.stringify(debts).find("redeemed") == -1 or JSON.stringify(debts).find("collateral kept") == -1 or JSON.stringify(debts).find("defaulted") == -1:
		failures.append("Run report debt ledger did not reconstruct paid, defaulted, redeemed, and forfeited outcomes.")
	var items := RunReportViewModelScript.build_item_fates(["instant_coffee", "instant_coffee"], [], story, {"instant_coffee": {"display_name": "Instant Coffee"}, "creased_luck_card": {"display_name": "Creased Luck Card"}})
	if int(((items.get("kept", []) as Array)[0] as Dictionary).get("count", 0)) != 2 or JSON.stringify(items).find("forfeited") == -1 or JSON.stringify(items).find("sold") == -1:
		failures.append("Run report item fate aggregation did not collapse kept duplicates or retain pawn/sale fates.")

	var timeline := RunReportViewModelScript.build_timeline(run_state.heat_history, {"visited_path": ["bar", "grand_casino"], "nodes": [{"id": "bar", "display_name": "Bar", "position": {"x": 0.1, "y": 0.4}}, {"id": "grand_casino", "display_name": "Grand Casino", "position": {"x": 0.9, "y": 0.5}}]}, 8)
	var boundary := RunReportViewModelScript.cursor_for_progress(timeline, 1.0)
	if not bool(timeline.get("precomputed", false)) or int(boundary.get("action_index", -1)) != 8 or int(boundary.get("leg_index", -1)) != 1:
		failures.append("Run report shared timeline did not map action, travel leg, and heat sample boundaries.")

	var registry := RunReportViewModelScript.load_outcome_registry()
	var base_data := run_state.to_dict()
	for reason in [RunState.FAILURE_BANKROLL_ZERO, RunState.FAILURE_STRANDED, RunState.FAILURE_POLICE_CAPTURE, RunState.FAILURE_CASINO_TAKEN_OUT_BACK, RunState.FAILURE_ABANDONED]:
		base_data["run_status"] = RunState.RUN_STATUS_FAILED
		base_data["run_failure_reason"] = reason
		base_data["run_failure_message"] = "Fixture ending for %s." % reason
		var outcome := RunReportViewModelScript.build_outcome(base_data, registry)
		if str(outcome.get("icon_key", "")).is_empty() or str(outcome.get("title", "")).is_empty() or str(outcome.get("how", "")).is_empty() or str(outcome.get("where", "")).find("Fixture Bar") == -1 and str(outcome.get("where", "")).find("Grand Casino") == -1:
			failures.append("Run report failure outcome %s missed its icon/title/where/how contract." % reason)
	for route in [RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, RunState.GRAND_CASINO_SHOWDOWN_ROUTE]:
		base_data["run_status"] = RunState.RUN_STATUS_ENDED
		base_data["narrative_flags"] = {"demo_victory": true, "demo_victory_route": route, "demo_victory_message": "Fixture victory."}
		var outcome := RunReportViewModelScript.build_outcome(base_data, registry)
		if str(outcome.get("icon_key", "")).is_empty() or not bool(outcome.get("won", false)) or str(outcome.get("where", "")).is_empty():
			failures.append("Run report victory route %s missed its distinct outcome contract." % route)

func _check_suspicion_security_foundation(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SUSPICION-SECURITY")
	var game := GameModule.new()
	game.setup({
		"id": "security_pressure_game",
		"display_name": "Security Pressure Game",
		"family": "fixture",
		"legal_actions": [{"id": "legal_fixture", "label": "Play Clean", "win_chance": 50, "payout_mult": 2}],
		"cheat_actions": [{"id": "risky_fixture", "label": "Palm The Card", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
	})
	var environment := {
		"id": "security_pressure_environment",
		"kind": "casino",
		"tier": 1,
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 20,
		},
	}
	var quiet_actions := game.actions(run_state, environment)
	var quiet_cheat_actions: Array = quiet_actions.get("cheat_actions", [])
	if quiet_cheat_actions.is_empty():
		failures.append("Security pressure fixture did not expose a risky action.")
		return
	var quiet_risk := int((quiet_cheat_actions[0] as Dictionary).get("suspicion_delta", 0))
	if quiet_risk != 2:
		failures.append("Quiet security pressure should not alter base risky action suspicion.")

	run_state.add_suspicion("watchful_floor", 25, "behavior", false, {"environment_id": "security_pressure_environment"})
	if run_state.suspicion_level() != 25:
		failures.append("RunState suspicion_level did not expose bounded suspicion.")
	if run_state.security_risk_bonus("cheat") <= 0:
		failures.append("Elevated suspicion did not produce risky-action pressure.")
	if run_state.security_pressure_summary().is_empty() or run_state.security_pressure_summary().contains("25"):
		failures.append("Security pressure summary should be behavior-first, not raw-meter-first.")
	var pressured_actions := game.actions(run_state, environment)
	var pressured_cheat_actions: Array = pressured_actions.get("cheat_actions", [])
	var pressured_risk := int((pressured_cheat_actions[0] as Dictionary).get("suspicion_delta", 0))
	if pressured_risk <= quiet_risk:
		failures.append("Suspicion did not increase visible risky-action consequence.")
	if int((pressured_cheat_actions[0] as Dictionary).get("security_pressure_bonus", 0)) <= 0:
		failures.append("Risky-action view did not expose security pressure bonus.")

	var before_suspicion := run_state.suspicion_level()
	var before_cue_count := (run_state.suspicion.get("cues", []) as Array).size()
	var result := game.resolve("risky_fixture", 1, run_state, environment, run_state.create_rng())
	if int(result.get("suspicion_delta", 0)) != pressured_risk:
		failures.append("Risky action result did not apply security-adjusted suspicion.")
	if run_state.suspicion_level() != before_suspicion + pressured_risk:
		failures.append("Risky action did not update RunState suspicion by adjusted consequence.")
	if (run_state.suspicion.get("cues", []) as Array).size() <= before_cue_count:
		failures.append("Risky action did not add a behavior cue.")
	if not str(result.get("message", "")).contains("risky moves draw more heat"):
		failures.append("Risky action result did not communicate security pressure.")

	var high_heat_run: RunState = RunStateScript.new()
	high_heat_run.start_new("HIGH-HEAT-PRESSURE")
	high_heat_run.add_suspicion("heated_floor", 66, "behavior", false, {"environment_id": "security_pressure_environment"})
	var high_heat_actions := game.actions(high_heat_run, environment)
	var high_heat_cheat_actions: Array = high_heat_actions.get("cheat_actions", [])
	var high_heat_risk := int((high_heat_cheat_actions[0] as Dictionary).get("suspicion_delta", 0)) if not high_heat_cheat_actions.is_empty() else 0
	if high_heat_risk <= pressured_risk:
		failures.append("High heat did not materially increase risky-action heat consequence.")
	var high_heat_result := game.resolve("risky_fixture", 10, high_heat_run, environment, high_heat_run.create_rng())
	var high_heat_story: Dictionary = {}
	var high_heat_story_log: Array = high_heat_result.get("deltas", {}).get("story_log", [])
	if not high_heat_story_log.is_empty() and typeof(high_heat_story_log[0]) == TYPE_DICTIONARY:
		high_heat_story = high_heat_story_log[0] as Dictionary
	if int(high_heat_story.get("security_bankroll_delta", 0)) >= 0:
		failures.append("High heat did not add a material security cost to risky action results.")
	if not str(high_heat_result.get("message", "")).contains("shakedown") and not str(high_heat_result.get("message", "")).contains("costly"):
		failures.append("High heat result did not communicate the security consequence.")

	var severe_heat_run: RunState = RunStateScript.new()
	severe_heat_run.start_new("SEVERE-HEAT-PRESSURE")
	severe_heat_run.add_suspicion("closing_in", 92, "behavior", false, {"environment_id": "security_pressure_environment"})
	var severe_heat_result := game.resolve("risky_fixture", 1, severe_heat_run, environment, severe_heat_run.create_rng())
	if not bool(severe_heat_result.get("ended", false)):
		failures.append("Very high heat did not create visible run-ending pressure.")
	if severe_heat_run.run_status != RunState.RUN_STATUS_FAILED:
		failures.append("Very high heat did not fail the run through RunState.")
	if severe_heat_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Very high heat failure was not recorded as police capture.")
	if not str(severe_heat_result.get("message", "")).contains("cuffs"):
		failures.append("Very high heat result did not explain the police capture consequence.")

	var capture_run: RunState = RunStateScript.new()
	capture_run.start_new("DIRECT-POLICE-CAPTURE")
	capture_run.add_suspicion("risk_meter_full", 100, "behavior", true, {"environment_id": "security_pressure_environment"})
	if capture_run.run_status != RunState.RUN_STATUS_FAILED or capture_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Risk meter reaching 100 did not immediately fail the run as police capture.")

	var event := EventModule.new()
	event.setup({
		"id": "security_pressure_event",
		"display_name": "Security Pressure Event",
		"type": "security",
		"min_suspicion": run_state.suspicion_level() + 5,
		"payload": {
			"choices": [{"id": "wait", "label": "Wait", "consequences": {"suspicion_delta": 1}}],
		},
	})
	if event.can_trigger(run_state, environment):
		failures.append("Suspicion-gated event triggered before enough pressure was present.")
	run_state.add_suspicion("guard_attention", 5, "behavior", false, {"environment_id": "security_pressure_environment"})
	if not event.can_trigger(run_state, environment):
		failures.append("Suspicion-gated event did not trigger after enough pressure was present.")

	var local_heat_run: RunState = RunStateScript.new()
	local_heat_run.start_new("LOCAL-HEAT-MEMORY")
	local_heat_run.set_environment({"id": "gas_station_casino_001", "archetype_id": "gas_station_casino"})
	local_heat_run.add_suspicion("hot_table", 80, "behavior", false, {"environment_id": "gas_station_casino_001"})
	var far_travel := local_heat_run.begin_travel_suspicion_decay({"distance": "far", "risk_decay": 85}, "motel")
	local_heat_run.set_environment({"id": "motel_002", "archetype_id": "motel"})
	var far_decay := local_heat_run.finish_travel_suspicion_decay(far_travel)
	if int(far_decay.get("cooled", 0)) <= 0:
		failures.append("Far travel did not cool local heat before arrival.")
	if local_heat_run.suspicion_level() > 15:
		failures.append("Far travel carried too much local heat into a distant environment.")
	var far_return := local_heat_run.begin_travel_suspicion_decay({"distance": "far", "risk_decay": 85}, "gas_station_casino")
	local_heat_run.set_environment({"id": "gas_station_casino_003", "archetype_id": "gas_station_casino"})
	local_heat_run.finish_travel_suspicion_decay(far_return)
	if local_heat_run.suspicion_level() < 70 or local_heat_run.suspicion_level() > 75:
		failures.append("Returning to a hot venue should remember heat with only a small cooldown.")

	var near_heat_run: RunState = RunStateScript.new()
	near_heat_run.start_new("NEAR-HEAT-MEMORY")
	near_heat_run.set_environment({"id": "gas_station_casino_001", "archetype_id": "gas_station_casino"})
	near_heat_run.add_suspicion("hot_table", 80, "behavior", false, {"environment_id": "gas_station_casino_001"})
	var near_travel := near_heat_run.begin_travel_suspicion_decay({"distance": "near", "risk_decay": 12}, "bar")
	near_heat_run.set_environment({"id": "bar_002", "archetype_id": "bar"})
	near_heat_run.finish_travel_suspicion_decay(near_travel)
	var near_return := near_heat_run.begin_travel_suspicion_decay({"distance": "near", "risk_decay": 12}, "gas_station_casino")
	near_heat_run.set_environment({"id": "gas_station_casino_003", "archetype_id": "gas_station_casino"})
	near_heat_run.finish_travel_suspicion_decay(near_return)
	if near_heat_run.suspicion_level() < 65:
		failures.append("Nearby travel should preserve most local heat when returning to the source venue.")
	var same_heat_run: RunState = RunStateScript.new()
	same_heat_run.start_new("SAME-HEAT-MEMORY")
	same_heat_run.set_environment({"id": "bar_001", "archetype_id": "bar"})
	same_heat_run.add_suspicion("watched_bar", 40, "behavior", false, {"environment_id": "bar_001"})
	var same_travel := same_heat_run.begin_travel_suspicion_decay({"distance": "same", "risk_decay": 0}, "bar")
	same_heat_run.set_environment({"id": "bar_002", "archetype_id": "bar"})
	same_heat_run.finish_travel_suspicion_decay(same_travel)
	if same_heat_run.suspicion_level() != 40:
		failures.append("Same-location travel should not cool local heat.")
	var near_snapshot := near_heat_run.to_dict()
	var near_restored: RunState = RunStateScript.new()
	near_restored.from_dict(near_snapshot)
	if near_restored.suspicion_level() != near_heat_run.suspicion_level():
		failures.append("Local heat memory did not survive RunState serialization.")

	var time_heat_run: RunState = RunStateScript.new()
	time_heat_run.start_new("TIME-HEAT-COOLING")
	time_heat_run.set_environment({"id": "bar_001", "archetype_id": "bar"})
	time_heat_run.add_suspicion("regulars_watch", 20, "behavior", false, {"environment_id": "bar_001"})
	time_heat_run.advance_environment_turns(1)
	if time_heat_run.suspicion_level() != 20:
		failures.append("In-room heat cooled too quickly after one turn.")
	time_heat_run.advance_environment_turns(1)
	if time_heat_run.suspicion_level() != 19:
		failures.append("In-room heat did not cool slowly over time.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_suspicion"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save suspicion/security state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload suspicion/security state.")
		elif loaded.suspicion_level() != run_state.suspicion_level():
			failures.append("Suspicion level did not survive SaveService load.")
		elif (loaded.suspicion.get("cues", []) as Array).size() != (run_state.suspicion.get("cues", []) as Array).size():
			failures.append("Suspicion cues did not survive SaveService load.")
		elif loaded.security_risk_bonus("cheat") != run_state.security_risk_bonus("cheat"):
			failures.append("Security pressure bonus did not survive SaveService load.")

	var severe_slot_id := "foundation_check_severe_heat"
	var severe_save_error: Error = save_service.save_run(severe_heat_run, severe_slot_id)
	if severe_save_error != OK:
		failures.append("Save service could not save severe heat state: %s." % severe_save_error)
	else:
		var loaded_severe = save_service.load_run(severe_slot_id)
		if loaded_severe == null:
			failures.append("Save service could not reload severe heat state.")
		elif loaded_severe.suspicion_level() != severe_heat_run.suspicion_level():
			failures.append("Severe heat level did not survive SaveService load.")
		elif loaded_severe.run_status != severe_heat_run.run_status:
			failures.append("Severe heat run-ending pressure did not survive SaveService load.")
		elif loaded_severe.run_failure_reason != severe_heat_run.run_failure_reason:
			failures.append("Severe heat failure reason did not survive SaveService load.")


func _check_music_fx_foundation(library: ContentLibrary, failures: Array) -> void:
	var first_environment: Dictionary = {}
	var boss_environment: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if first_environment.is_empty():
			first_environment = archetype.duplicate(true)
		if str(archetype.get("id", "")) == "grand_casino":
			boss_environment = archetype.duplicate(true)
	if first_environment.is_empty() or boss_environment.is_empty():
		failures.append("Music FX foundation fixture could not find environment archetypes.")
		return

	var graph_a: Dictionary = ProceduralMusicPlayerScript.ensure_music_fx_bus_graph()
	var graph_b: Dictionary = ProceduralMusicPlayerScript.ensure_music_fx_bus_graph()
	if int(graph_a.get("effect_count", 0)) != 3 or int(graph_b.get("effect_count", 0)) != 3:
		failures.append("Music master bus should contain only low-pass, chorus, and safety limiter effects.")
	if JSON.stringify(graph_a.get("effects", [])) != JSON.stringify(graph_b.get("effects", [])):
		failures.append("Music FX bus graph was not idempotent across repeated startup calls.")
	var effect_types: Array = []
	var enabled: Array = []
	for effect_value in (graph_b.get("effects", []) as Array):
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		effect_types.append(str(effect.get("type", "")))
		enabled.append(bool(effect.get("enabled", false)))
	var expected_types := [
		"AudioEffectLowPassFilter",
		"AudioEffectChorus",
		"AudioEffectLimiter",
	]
	if JSON.stringify(effect_types) != JSON.stringify(expected_types):
		failures.append("Music FX bus graph order/types changed: %s." % JSON.stringify(effect_types))
	if enabled.size() == 3 and (bool(enabled[0]) or bool(enabled[1]) or not bool(enabled[2])):
		failures.append("Music master bus should bypass low-pass/chorus and keep the safety limiter active.")
	var send_graph: Dictionary = graph_b.get("send_buses", {}) as Dictionary
	var send_buses: Dictionary = send_graph.get("buses", {}) as Dictionary
	var expected_send_types := {
		"band_pass": "AudioEffectBandPassFilter",
		"delay": "AudioEffectDelay",
		"distortion": "AudioEffectDistortion",
		"reverb": "AudioEffectReverb",
		"compressor": "AudioEffectCompressor",
	}
	for effect_key in expected_send_types.keys():
		var send_bus: Dictionary = send_buses.get(effect_key, {}) as Dictionary
		if str(send_bus.get("send", "")) != "Music" or str(send_bus.get("effect_type", "")) != str(expected_send_types.get(effect_key, "")) or not bool(send_bus.get("independent_role_sends", false)):
			failures.append("Music %s send bus did not expose independent per-instrument routing." % effect_key)

	var web_contract: Dictionary = WebAudioBridgeScript.mix_contract_snapshot()
	if not bool(web_contract.get("stream_bridge_enabled", false)) or not bool(web_contract.get("pcm_stream_bridge_default", false)):
		failures.append("Web export should use the browser PCM stream bridge so music/SFX remain audible when native web playback is silent.")
	if bool(web_contract.get("script_has_oscillator_fallback", true)):
		failures.append("Web audio bridge must not fall back to oscillator synth cues; those produced the browser hum regression.")
	if int(web_contract.get("version", 0)) < 4 or not bool(web_contract.get("script_has_version_guard", false)):
		failures.append("Web audio bridge did not expose a versioned replacement guard.")
	if not bool(web_contract.get("script_has_highpass", false)) or float(web_contract.get("highpass_hz", 0.0)) < 30.0:
		failures.append("Web audio bridge must high-pass browser output to prevent sub-bass overload.")
	if not bool(web_contract.get("script_has_compressor", false)) or float(web_contract.get("compressor_ratio", 0.0)) < 1.5:
		failures.append("Web audio bridge must keep a browser-side compressor before destination output.")
	if not bool(web_contract.get("script_has_pcm_decoder", false)) or not bool(web_contract.get("script_has_music_stems", false)):
		failures.append("Web audio bridge must decode PCM buffers and play the normal music stem set.")
	if not bool(web_contract.get("script_accepts_json_payloads", false)):
		failures.append("Web audio bridge JavaScript methods must parse JSON string payloads from direct interface calls.")
	if not bool(web_contract.get("script_has_loop_stop", false)):
		failures.append("Web audio bridge must expose explicit loop stopping for reel/roulette browser loops.")
	if int(web_contract.get("music_mix_min_interval_msec", 0)) < 100:
		failures.append("Web audio bridge must throttle browser mix calls so music fades do not stall the web main thread.")
	if not bool(web_contract.get("bridge_uses_direct_interface", false)) or not bool(web_contract.get("telemetry_uses_call_payload_names", false)):
		failures.append("Web audio bridge must report direct-call payload telemetry instead of eval byte telemetry.")
	if not bool(web_contract.get("bridge_skips_silent_music_stems", false)):
		failures.append("Web audio bridge must skip silent music stems before serializing browser PCM payloads.")
	if not bool(web_contract.get("bridge_skips_duplicate_music_stems", false)):
		failures.append("Web audio bridge must skip duplicate music stem payloads before crossing JavaScriptBridge.")
	if not bool(web_contract.get("bridge_skips_duplicate_music_stops", false)):
		failures.append("Web audio bridge must skip duplicate browser music stops before crossing JavaScriptBridge.")
	if not bool(web_contract.get("script_limits_sfx_gain", false)) or float(web_contract.get("sfx_max_gain", 2.0)) > 1.25:
		failures.append("Web audio bridge SFX gain staging can clip browser output.")
	if float(web_contract.get("master_gain", 1.0)) * float(web_contract.get("output_gain", 1.0)) > 0.75:
		failures.append("Web audio bridge master/output gain leaves too little headroom.")
	var web_audio_bridge_text := FileAccess.get_file_as_string("res://scripts/ui/web_audio_bridge.gd")
	if _foundation_string_occurrence_count(web_audio_bridge_text, "JavaScriptBridge.eval(") != 1:
		failures.append("Web audio bridge should use JavaScriptBridge.eval only for one-time bridge installation.")
	if web_audio_bridge_text.find("JavaScriptBridge.get_interface(\"BTHWebAudio\")") < 0:
		failures.append("Web audio bridge should cache BTHWebAudio through JavaScriptBridge.get_interface after installation.")
	if web_audio_bridge_text.find("\"call_counts\"") < 0 or web_audio_bridge_text.find("\"payload_bytes\"") < 0:
		failures.append("Web audio bridge debug stats should expose call_counts and payload_bytes telemetry.")
	var foundation_main_text := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	if foundation_main_text.find("_suppress_web_music_for_game_surface") != -1 or foundation_main_text.find("OS.has_feature(\"web\") and current_screen == SCREEN_GAME") != -1:
		failures.append("Web procedural music should keep playing inside game surfaces instead of being suppressed on entry.")

	var player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	get_root().add_child(player)
	var initial_snapshot: Dictionary = player.music_fx_snapshot({})
	if bool(initial_snapshot.get("player_instantiated", true)):
		failures.append("Headless procedural music player should not instantiate AudioStreamPlayer playback.")
	var music_latency: Dictionary = player.music_generation_latency_snapshot_for_environment(first_environment, 20)
	var web_bed_seconds := float(music_latency.get("web_bed_seconds", 0.0))
	var web_bed_pcm_bytes := int(music_latency.get("web_bed_pcm_bytes", 0))
	var web_bed_cap_bytes := int(music_latency.get("web_bed_bridge_cap_bytes", 0))
	if web_bed_seconds < 30.0:
		failures.append("Web procedural music bed should be long-form, not a short startup loop.")
	if web_bed_pcm_bytes <= 0 or web_bed_cap_bytes <= 0 or web_bed_pcm_bytes > web_bed_cap_bytes:
		failures.append("Web procedural music bed must fit the browser PCM bridge budget.")
	if web_bed_seconds <= float(music_latency.get("instant_seconds", 0.0)) * 4.0:
		failures.append("Web procedural music bed should be substantially longer than the desktop instant bed.")
	var first_music_profile_value: Variant = first_environment.get("music_profile", {})
	var first_music_profile: Dictionary = {}
	if typeof(first_music_profile_value) == TYPE_DICTIONARY:
		first_music_profile = first_music_profile_value as Dictionary
	if not str(first_music_profile.get("authored_track_id", "")).is_empty():
		if str(music_latency.get("web_mixdown_source", "")) != "authored":
			failures.append("Web music bridge should downmix authored room music instead of replacing it with generated filler.")
		if float(music_latency.get("web_mixdown_seconds", 0.0)) < 20.0:
			failures.append("Web authored room music mixdown should preserve a long-form loop.")
	var boss_music_latency: Dictionary = player.music_generation_latency_snapshot_for_environment(boss_environment, 20)
	if str(music_latency.get("web_bed_track_id", "")) == str(boss_music_latency.get("web_bed_track_id", "")):
		failures.append("Web procedural music bed track ids should change between environment archetypes.")
	if str(music_latency.get("web_bed_cache_key", "")) == str(boss_music_latency.get("web_bed_cache_key", "")):
		failures.append("Web procedural music bed cache keys should change between environment archetypes.")

	var sober: Dictionary = _music_fx_target(player, {
		"environment": first_environment,
		"visual_context": first_environment.get("visual_context", {}),
		"heat": 20,
		"drunk_level": 0,
	})
	var drunk: Dictionary = _music_fx_target(player, {
		"environment": first_environment,
		"visual_context": first_environment.get("visual_context", {}),
		"heat": 20,
		"drunk_level": 85,
	})
	if float(drunk.get("chorus_depth", 0.0)) <= float(sober.get("chorus_depth", 0.0)) + 0.20:
		failures.append("Music FX drunk tier did not materially raise chorus depth.")
	if float(drunk.get("pitch_wobble_cents", 0.0)) <= 6.0:
		failures.append("Music FX drunk tier did not expose slow pitch wobble.")
	if float(drunk.get("lowpass_cutoff_hz", 20000.0)) >= float(sober.get("lowpass_cutoff_hz", 0.0)) - 2000.0:
		failures.append("Music FX drunk tier did not close the low-pass filter.")
	if float(drunk.get("delay_amount", 0.0)) <= float(sober.get("delay_amount", 0.0)) + 0.20:
		failures.append("Music FX drunk tier did not raise the per-instrument delay sends.")

	var heat_low: Dictionary = _music_fx_target(player, {
		"environment": first_environment,
		"visual_context": first_environment.get("visual_context", {}),
		"heat": 20,
	})
	var heat_high: Dictionary = _music_fx_target(player, {
		"environment": first_environment,
		"visual_context": first_environment.get("visual_context", {}),
		"heat": 90,
	})
	if float(heat_high.get("distortion_drive", 0.0)) <= float(heat_low.get("distortion_drive", 0.0)) + 0.04:
		failures.append("Music FX heat mapping did not add subtle high-heat distortion.")

	var unwatched: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 30,
		"pit_boss_watch": {"active": true, "watched": false},
		"staff_attention": {"active": false},
		"boss_floor": false,
	})
	var watched: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 30,
		"pit_boss_watch": {"active": true, "watched": true},
		"staff_attention": {"active": true},
		"boss_floor": false,
	})
	if float(watched.get("watch_bandpass_amount", 0.0)) <= float(unwatched.get("watch_bandpass_amount", 0.0)) + 0.10:
		failures.append("Music FX watch/staff attention did not expose the surveillance tinge.")
	if float(watched.get("watch_bandpass_q", 0.0)) <= float(unwatched.get("watch_bandpass_q", 0.0)) + 0.5:
		failures.append("Music FX attention did not narrow the true band-pass as attention rose.")
	var watched_send_snapshot: Dictionary = player.music_fx_snapshot({"watched": true, "attention_level": 90.0})
	var watched_send_matrix: Dictionary = watched_send_snapshot.get("send_matrix", {}) as Dictionary
	if float(((watched_send_matrix.get("band_pass", {}) as Dictionary).get("lead", 0.0))) <= 0.2:
		failures.append("Music FX attention did not route the lead into its band-pass send.")

	var calm_boss: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 30,
		"boss_floor": true,
	})
	var showdown: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 30,
		"boss_floor": true,
		"showdown_pending": true,
	})
	if float(showdown.get("distortion_drive", 0.0)) <= float(calm_boss.get("distortion_drive", 0.0)) + 0.10:
		failures.append("Music FX showdown did not push danger distortion beyond the boss-floor bed.")
	if float(showdown.get("compressor_pump", 0.0)) <= float(calm_boss.get("compressor_pump", 0.0)) + 0.25:
		failures.append("Music FX showdown did not increase compressor pump.")
	if float(calm_boss.get("reverb_size", 0.0)) <= float(sober.get("reverb_size", 1.0)):
		failures.append("Music FX venue room scale did not open reverb on the boss floor.")

	var settings := UserSettingsScript.new()
	settings.audio_calm = true
	settings.play_on_small_screen = true
	var restored_settings: UserSettings = UserSettingsScript.new()
	restored_settings.from_dict(settings.to_dict())
	if not restored_settings.audio_calm:
		failures.append("Audio-calm setting did not round-trip through UserSettings.")
	if not restored_settings.play_on_small_screen:
		failures.append("Play-on-small-screen setting did not round-trip through UserSettings.")
	player.audio_calm = false
	var intense_showdown: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 95,
		"boss_floor": true,
		"showdown_pending": true,
		"drunk_level": 85,
	})
	player.audio_calm = true
	var calm_showdown: Dictionary = _music_fx_target(player, {
		"environment": boss_environment,
		"visual_context": boss_environment.get("visual_context", {}),
		"heat": 95,
		"boss_floor": true,
		"showdown_pending": true,
		"drunk_level": 85,
	})
	if float(calm_showdown.get("distortion_drive", 0.0)) >= float(intense_showdown.get("distortion_drive", 0.0)):
		failures.append("Audio-calm did not damp Music FX distortion.")
	if float(calm_showdown.get("compressor_pump", 0.0)) >= float(intense_showdown.get("compressor_pump", 0.0)):
		failures.append("Audio-calm did not damp Music FX compressor pump.")
	player.queue_free()


func _music_fx_target(player: ProceduralMusicPlayer, snapshot: Dictionary) -> Dictionary:
	var fx_snapshot: Dictionary = player.music_fx_snapshot(snapshot)
	return fx_snapshot.get("target", {}) as Dictionary


func _check_music_stem_director_foundation(library: ContentLibrary, failures: Array) -> void:
	var player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	var stem_buses: Dictionary = ProceduralMusicPlayerScript.ensure_music_stem_bus_graph()
	var bus_roles: Dictionary = stem_buses.get("buses", {}) as Dictionary
	for role in ["pad", "bass", "bass_dark", "lead", "drums_low", "drums_high", "drums_high_double", "tension", "texture"]:
		var role_bus: Dictionary = bus_roles.get(role, {}) as Dictionary
		if str(role_bus.get("send", "")) != "Music":
			failures.append("Music stem bus %s was not routed into the Music bus." % role)

	var authored_track := library.music_track("corner_store_sparse_fixture")
	if authored_track.is_empty():
		failures.append("ContentLibrary did not load the authored sparse music track fixture.")
	var invalid_library: ContentLibrary = ContentLibraryScript.new()
	invalid_library.music_tracks = [{
		"id": "bad_music_entry",
		"bpm": 0,
		"bars": 1,
		"loop_frames": 100,
		"stems": {"pad": "missing.wav"},
	}]
	var invalid_errors := invalid_library.validate()
	if invalid_errors.is_empty():
		failures.append("ContentLibrary music manifest validation did not reject a bad authored entry.")

	var authored_environment := _music_environment_with_authored_track(library)
	var procedural_environment := _music_environment_without_authored_track(library)
	if authored_environment.is_empty() or procedural_environment.is_empty():
		failures.append("Music stem foundation could not find authored and procedural environment fixtures.")
		return

	var authored_manifest: Dictionary = player.music_stem_manifest_snapshot_for_environment(authored_environment, 20)
	if str(authored_manifest.get("source", "")) != "authored":
		failures.append("Authored music profile did not resolve the sparse authored provider.")
	if not bool(authored_manifest.get("sync_ok", false)):
		failures.append("Authored sparse stem set did not expose synchronized loop metadata.")
	if int(authored_manifest.get("sample_rate", 0)) != 44100 or int(authored_manifest.get("bit_depth", 0)) != 16:
		failures.append("Authored music did not preserve the native 16-bit/44.1 kHz delivery contract.")
	if int(authored_manifest.get("loop_frames", 0)) < 44100 * 12:
		failures.append("Authored corner-store music fixture should be a long ambient bed, not a short repeated loop.")
	if int(authored_manifest.get("bars", 0)) < 8:
		failures.append("Authored corner-store music fixture should span multiple bars before looping.")
	if not bool(authored_manifest.get("sparse", false)):
		failures.append("Authored sparse fixture should report absent roles as silent.")
	var authored_roles: Dictionary = authored_manifest.get("roles", {}) as Dictionary
	if not bool((authored_roles.get("pad", {}) as Dictionary).get("present", false)) or not bool((authored_roles.get("tension", {}) as Dictionary).get("present", false)):
		failures.append("Authored fixture did not expose its pad+tension stems.")
	if bool((authored_roles.get("bass", {}) as Dictionary).get("present", false)):
		failures.append("Sparse authored fixture should leave absent bass silent.")
	var authored_hot: Dictionary = player.music_stem_manifest_snapshot_for_environment(authored_environment, 90)
	if str(authored_hot.get("cache_key", "")) == str(authored_manifest.get("cache_key", "")):
		failures.append("Authored intensity bank did not select a new phrase-ready variation at high heat.")
	if str(((authored_manifest.get("selected_variants", {}) as Dictionary).get("tension", {}) as Dictionary).get("id", "")) != "tension_low":
		failures.append("Authored low-intensity bank did not select its low tension variant.")
	if str(((authored_hot.get("selected_variants", {}) as Dictionary).get("tension", {}) as Dictionary).get("id", "")) != "tension_high":
		failures.append("Authored high-intensity bank did not select its high tension variant.")
	var authored_relative_key: Dictionary = player.music_stem_manifest_snapshot_for_environment(authored_environment, 20, {"harmonic_section": "B"})
	if str(authored_relative_key.get("selection_key", "")) == str(authored_manifest.get("selection_key", "")) or str((authored_relative_key.get("selection_context", {}) as Dictionary).get("harmonic_section", "")) != "B":
		failures.append("Authored harmonic bank did not preserve its relative-key section selection.")
	var stinger_modes: Dictionary = authored_manifest.get("stinger_loop_modes", {}) as Dictionary
	var fill_modes: Dictionary = authored_manifest.get("fill_loop_modes", {}) as Dictionary
	if int(stinger_modes.get("win_fixture", -1)) != AudioStreamWAV.LOOP_DISABLED or int(fill_modes.get("drum_fill_fixture", -1)) != AudioStreamWAV.LOOP_DISABLED:
		failures.append("Authored stingers and fills must load as one-shots unless explicitly declared looping.")
	var transition_policy: Dictionary = player.music_transition_policy_snapshot_for_environment(authored_environment, 20)
	if str(transition_policy.get("quantize", "")) != "phrase" or int(transition_policy.get("phrase_bars", 0)) != 4 or not bool(transition_policy.get("filler_clips", false)):
		failures.append("Authored transition policy did not expose four-bar phrase and filler-aware switching.")

	var fallback_environment := procedural_environment.duplicate(true)
	var fallback_profile: Dictionary = (fallback_environment.get("music_profile", {}) as Dictionary).duplicate(true)
	fallback_profile["authored_track_id"] = "missing_music_track"
	fallback_environment["music_profile"] = fallback_profile
	var fallback_manifest: Dictionary = player.music_stem_manifest_snapshot_for_environment(fallback_environment, 30)
	if str(fallback_manifest.get("source", "")) != "procedural":
		failures.append("Missing authored_track_id did not silently fall back to procedural stems.")

	var cache_keys := {}
	for heat in [0, 50, 90]:
		var heat_manifest: Dictionary = player.music_stem_manifest_snapshot_for_environment(procedural_environment, int(heat))
		cache_keys[str(heat_manifest.get("cache_key", ""))] = true
		if bool(heat_manifest.get("cache_key_uses_heat", true)):
			failures.append("Procedural music manifest reported a heat-bearing cache key.")
	if cache_keys.size() != 1:
		failures.append("Procedural music cache should hold one stem set across heat sweeps, got %d keys." % cache_keys.size())

	for index in range(10):
		var seeded_environment := procedural_environment.duplicate(true)
		seeded_environment["id"] = "music_seed_%02d" % index
		var manifest: Dictionary = player.music_stem_manifest_snapshot_for_environment(seeded_environment, (index * 11) % 100)
		if str(manifest.get("source", "")) != "procedural":
			failures.append("Procedural stem seed fixture resolved the wrong provider at index %d." % index)
		if not bool(manifest.get("sync_ok", false)):
			failures.append("Procedural stem manifest was not sample-synced at index %d." % index)
		if (manifest.get("present_roles", []) as Array).size() != 9:
			failures.append("Procedural stem manifest should expose seven roles plus two variants at index %d." % index)
	var baked_manifest: Dictionary = player.music_stem_manifest_snapshot_for_environment(procedural_environment, 40, {}, true)
	if not bool(baked_manifest.get("sync_ok", false)) or int(baked_manifest.get("loop_frames", 0)) <= 0:
		failures.append("Baked procedural stem set did not preserve one loop length authority.")

	var calm := {"heat": 20, "bankroll": 120, "debt": []}
	var hot := {"heat": 90, "bankroll": 120, "debt": []}
	var watched := {"heat": 35, "pit_boss_watch": {"active": true, "watched": true}, "staff_attention": {"active": true}}
	var debt_pressure := {"heat": 25, "bankroll": 24, "debt": [{"id": "note", "status": "overdue", "balance": 80}]}
	var showdown := {"heat": 80, "showdown_pending": true, "boss_floor": true}
	var calm_mix: Dictionary = (player.music_mix_snapshot(calm).get("target", {}) as Dictionary)
	var hot_mix: Dictionary = (player.music_mix_snapshot(hot).get("target", {}) as Dictionary)
	if float(hot_mix.get("drums_high", 0.0)) <= float(calm_mix.get("drums_high", 0.0)) + 0.30:
		failures.append("MusicDirector heat matrix did not raise high drum density.")
	if float(hot_mix.get("tension", 0.0)) <= float(calm_mix.get("tension", 0.0)) + 0.10:
		failures.append("MusicDirector heat matrix did not creep in tension above 60 heat.")
	var watched_mix: Dictionary = (player.music_mix_snapshot(watched).get("target", {}) as Dictionary)
	if float(watched_mix.get("tension", 0.0)) <= float(calm_mix.get("tension", 0.0)) + 0.35:
		failures.append("MusicDirector watch matrix did not lift tension.")
	if float(watched_mix.get("lead", 1.0)) >= float(calm_mix.get("lead", 0.0)):
		failures.append("MusicDirector watch matrix did not pull lead back.")
	var debt_mix: Dictionary = (player.music_mix_snapshot(debt_pressure).get("target", {}) as Dictionary)
	if float(debt_mix.get("bass_dark", 0.0)) <= float(calm_mix.get("bass_dark", 0.0)) + 0.40:
		failures.append("MusicDirector debt pressure did not swap toward dark bass.")
	if float(debt_mix.get("pad", 1.0)) >= float(calm_mix.get("pad", 0.0)):
		failures.append("MusicDirector debt pressure did not thin the pad.")
	var showdown_mix: Dictionary = (player.music_mix_snapshot(showdown).get("target", {}) as Dictionary)
	if float(showdown_mix.get("tension", 0.0)) < 0.95 or float(showdown_mix.get("pad", 1.0)) > 0.20:
		failures.append("MusicDirector showdown mix did not enter percussion/heartbeat danger state.")
	var deterministic_a := JSON.stringify(player.music_mix_snapshot(hot).get("target", {}))
	var deterministic_b := JSON.stringify(player.music_mix_snapshot(hot).get("target", {}))
	if deterministic_a != deterministic_b:
		failures.append("MusicDirector mix snapshot changed for identical scripted input.")

	var quantized_player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	quantized_player.update_music_state(calm)
	quantized_player.update_music_state(watched)
	var mid_bar: Dictionary = quantized_player.music_mix_snapshot({}, 0.50)
	var pending_mid: Dictionary = mid_bar.get("pending", {}) as Dictionary
	if pending_mid.is_empty():
		failures.append("MusicDirector watch change did not wait for the next bar.")
	var target_mid: Dictionary = mid_bar.get("target", {}) as Dictionary
	if float(target_mid.get("tension", 0.0)) > 0.10:
		failures.append("MusicDirector quantized tension unmuted before the bar boundary.")
	var boundary := float(pending_mid.get("target_position", 0.0))
	var after_bar: Dictionary = quantized_player.music_mix_snapshot({}, boundary + 0.01)
	if not (after_bar.get("pending", {}) as Dictionary).is_empty():
		failures.append("MusicDirector pending change did not resolve at the bar boundary.")
	var target_after: Dictionary = after_bar.get("target", {}) as Dictionary
	if float(target_after.get("tension", 0.0)) <= 0.35:
		failures.append("MusicDirector quantized tension did not apply at the bar boundary.")

	var feature_player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	feature_player.update_feature_music_state({
		"active": true,
		"cue_id": "bonus_music_buffalo",
		"feature_music": {
			"cue_id": "bonus_music_buffalo",
			"duck_background_music": true,
			"volume_db": -10.0,
		},
		"feature_scene": {
			"active": true,
			"scene_id": "feature_fixture",
		},
	})
	var feature_mid: Dictionary = feature_player.music_feature_snapshot({}, 0.50)
	var feature_pending: Dictionary = feature_mid.get("pending", {}) as Dictionary
	if feature_pending.is_empty():
		failures.append("Feature music layer did not wait for the next bar.")
	var feature_target_mid: Dictionary = feature_mid.get("target", {}) as Dictionary
	if float(feature_target_mid.get("feature", 0.0)) > 0.01 or float(feature_target_mid.get("venue_duck", 0.0)) > 0.01:
		failures.append("Feature music layer applied before the bar boundary.")
	var feature_boundary := float(feature_pending.get("target_position", 0.0))
	var feature_after: Dictionary = feature_player.music_feature_snapshot({}, feature_boundary + 0.01)
	var feature_target_after: Dictionary = feature_after.get("target", {}) as Dictionary
	if float(feature_target_after.get("feature", 0.0)) <= 0.50 or float(feature_target_after.get("venue_duck", 0.0)) <= 0.40:
		failures.append("Feature music layer did not apply gain and venue ducking at the bar boundary.")
	feature_player.play_feature_stinger("pinball_super_jackpot", {})
	var stinger_pending_snapshot: Dictionary = feature_player.music_feature_snapshot({}, 0.01)
	var pending_stingers: Array = stinger_pending_snapshot.get("pending_stingers", []) as Array
	if pending_stingers.is_empty():
		failures.append("Feature stinger did not schedule to the next beat.")
	else:
		var pending_stinger: Dictionary = pending_stingers[0] as Dictionary
		var stinger_after: Dictionary = feature_player.music_feature_snapshot({}, float(pending_stinger.get("target_position", 0.0)) + 0.01)
		if (stinger_after.get("stinger_history", []) as Array).is_empty():
			failures.append("Feature stinger did not resolve at its quantized beat.")
	var one_shot_stream: AudioStreamWAV = feature_player.call("_feature_stinger_stream", "big_win", "arcade", 120.0)
	if one_shot_stream == null or one_shot_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		failures.append("Generated music stingers must be one-shot streams.")
	var event_player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	event_player.update_music_state({"big_win": true, "last_bankroll_delta": 75, "big_win_event_token": "fixture:1"})
	var event_start: Dictionary = event_player.music_event_envelope_snapshot({}, 0.0)
	if int(event_start.get("bars_remaining", 0)) != 4:
		failures.append("Big-win event did not schedule a four-musical-bar envelope.")
	var event_bar_seconds := float((event_start.get("envelope", {}) as Dictionary).get("start_bar", 1)) * float(event_player.music_mix_snapshot().get("bar_seconds", 0.0))
	var event_after: Dictionary = event_player.music_event_envelope_snapshot({}, event_bar_seconds + float(event_player.music_mix_snapshot().get("bar_seconds", 0.0)) * 4.01)
	if bool(event_after.get("active", true)) or int(event_after.get("bars_remaining", -1)) != 0:
		failures.append("Big-win event envelope did not expire after consuming four musical bars.")
	event_player.update_music_state({"big_win": true, "last_bankroll_delta": 90, "big_win_event_token": "fixture:2"})
	var cooldown_event: Dictionary = event_player.music_event_envelope_snapshot({}, event_bar_seconds + float(event_player.music_mix_snapshot().get("bar_seconds", 0.0)) * 4.01)
	if str((cooldown_event.get("envelope", {}) as Dictionary).get("event_token", "")) != "fixture:1":
		failures.append("Big-win event cooldown did not prevent an immediate envelope retrigger.")

	var sfx_text := FileAccess.get_file_as_string("res://scripts/ui/sfx_player.gd")
	if sfx_text.find("_sample_bonus_music") != -1:
		failures.append("SfxPlayer still contains generated bonus music samplers.")
	var sfx := SfxPlayerScript.new()
	var director_cues: Array = sfx.debug_music_director_cue_ids()
	if not director_cues.has("bonus_music_buffalo") or not director_cues.has("bonus_music_pinball"):
		failures.append("SfxPlayer did not keep feature music cue ids routed to the MusicDirector.")
	var bonus_preview: AudioStreamWAV = sfx.preview_event_stream("bonus_music_pinball")
	if bonus_preview != null and bonus_preview.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		failures.append("SfxPlayer still treats feature music cues as local looping SFX.")

	var jazz_environment := _music_environment_by_archetype(library, "jazz_club")
	var grand_environment := _music_environment_by_archetype(library, "grand_casino")
	var motel_environment := _music_environment_by_archetype(library, "motel")
	if jazz_environment.is_empty() or grand_environment.is_empty() or motel_environment.is_empty():
		failures.append("Music composition fixtures could not find jazz, grand, and motel archetypes.")
	else:
		var jazz_theory: Dictionary = player.music_theory_snapshot_for_environment(jazz_environment, 20)
		var grand_theory: Dictionary = player.music_theory_snapshot_for_environment(grand_environment, 20)
		var motel_theory: Dictionary = player.music_theory_snapshot_for_environment(motel_environment, 20)
		if str(jazz_theory.get("arrangement_form", "")) != "AABA" or int(jazz_theory.get("bridge_phrase_index", -1)) < 0:
			failures.append("Music theory snapshot did not expose AABA bridge form.")
		if float(jazz_theory.get("swing_amount", 0.0)) <= float(grand_theory.get("swing_amount", 0.0)) + 0.05:
			failures.append("Jazz music theory did not expose a stronger swing amount than grand casino.")
		if (jazz_theory.get("voicing_inversions", []) as Array).is_empty() or (jazz_theory.get("chord_voicings", []) as Array).is_empty():
			failures.append("Music theory snapshot did not expose voice-led pad inversions.")
		var jazz_palette: Dictionary = jazz_theory.get("instrument_palette", {}) as Dictionary
		var grand_palette: Dictionary = grand_theory.get("instrument_palette", {}) as Dictionary
		var motel_palette: Dictionary = motel_theory.get("instrument_palette", {}) as Dictionary
		if str(jazz_palette.get("id", "")) == str(grand_palette.get("id", "")) or str(motel_palette.get("id", "")) == str(grand_palette.get("id", "")):
			failures.append("Music instrument palettes did not differ by venue archetype.")


func _music_environment_with_authored_track(library: ContentLibrary) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var profile: Dictionary = archetype.get("music_profile", {}) as Dictionary
		if not str(profile.get("authored_track_id", "")).strip_edges().is_empty():
			return archetype.duplicate(true)
	return {}


func _music_environment_without_authored_track(library: ContentLibrary) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var profile: Dictionary = archetype.get("music_profile", {}) as Dictionary
		if str(profile.get("authored_track_id", "")).strip_edges().is_empty():
			return archetype.duplicate(true)
	return {}


func _music_environment_by_archetype(library: ContentLibrary, archetype_id: String) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if str(archetype.get("id", "")) == archetype_id:
			return archetype.duplicate(true)
	return {}


# Checks one deterministic vertical slice where M2 systems affect each other through existing contracts.
func _check_m2_system_interaction_scenario(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("M2-SYSTEM-SCENARIO")
	run_state.game_clock_minutes = 20 * 60
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var start_environment: EnvironmentInstance = generator.next_environment(run_state)
	var environment_target := _first_target_with_game(library, _unique_strings(start_environment.next_archetypes, start_environment.travel_hooks), "")
	var environment: EnvironmentInstance = generator.next_environment(run_state, environment_target)
	if run_state.current_environment.is_empty():
		failures.append("M2 scenario did not enter a generated environment.")
		return
	if environment.game_ids.is_empty():
		failures.append("M2 scenario generated environment without a game option.")
		return

	run_state.change_bankroll(RunState.DEFAULT_BANKROLL - run_state.bankroll)
	var pressure_result := _fixture_system_pressure_result(run_state.current_environment, -60, "A cold streak tightens the run.")
	GameModule.apply_result(run_state, pressure_result)
	if run_state.economy() != "volatile":
		failures.append("M2 scenario did not create observable economy pressure.")

	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("M2 scenario item fixture is missing: instant_coffee.")
		return
	GameModule.apply_result(run_state, _fixture_item_purchase_result(item_def, 4, str(run_state.current_environment.get("id", ""))))
	if not run_state.inventory.has("instant_coffee"):
		failures.append("M2 scenario did not buy an item through result-delta inventory.")

	var game: GameModule = null
	var risky_action: Dictionary = {}
	for candidate_id_value in environment.game_ids:
		var candidate_id := str(candidate_id_value)
		var candidate_game_value = _load_surface_contract_game(library, candidate_id, failures)
		if candidate_game_value == null or not candidate_game_value is GameModule:
			continue
		var candidate_game: GameModule = candidate_game_value
		var candidate_actions := candidate_game.actions(run_state, run_state.current_environment)
		var candidate_cheats: Array = candidate_actions.get("cheat_actions", []) if typeof(candidate_actions.get("cheat_actions", [])) == TYPE_ARRAY else []
		if candidate_cheats.is_empty():
			continue
		var positive_heat_action: Dictionary = {}
		for candidate_action_value in candidate_cheats:
			if typeof(candidate_action_value) != TYPE_DICTIONARY:
				continue
			var candidate_action: Dictionary = candidate_action_value
			if int(candidate_action.get("suspicion_delta", 0)) > 0:
				positive_heat_action = candidate_action.duplicate(true)
				break
		if positive_heat_action.is_empty():
			continue
		game = candidate_game
		risky_action = positive_heat_action
		break
	if game == null:
		failures.append("M2 scenario generated no game with a risky action.")
		return
	var before_suspicion := run_state.suspicion_level()
	var risky_action_id := str(risky_action.get("id", ""))
	var risky_result := game.resolve(risky_action_id, 5, run_state, run_state.current_environment, run_state.create_rng())
	_check_action_result_shape(risky_result, "cheat", failures)
	if bool(risky_result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, risky_result, run_state.create_rng("m2_risky_host_apply"))
	if run_state.suspicion_level() <= before_suspicion:
		failures.append("M2 scenario risky action did not change suspicion/security state.")
	if (run_state.suspicion.get("cues", []) as Array).is_empty():
		failures.append("M2 scenario risky action did not create a security cue.")

	var scenario_environment := run_state.current_environment.duplicate(true)
	var event_ids := _string_array_from_variant(scenario_environment.get("event_ids", []))
	if not event_ids.has("parking_lot_tip"):
		event_ids.append("parking_lot_tip")
	scenario_environment["event_ids"] = event_ids
	var travel_hooks := _string_array_from_variant(scenario_environment.get("travel_hooks", []))
	if not travel_hooks.has("small_underground_casino"):
		travel_hooks.append("small_underground_casino")
	scenario_environment["travel_hooks"] = travel_hooks
	run_state.set_environment(scenario_environment)

	var underground_route := library.route("small_underground_casino")
	if underground_route.is_empty():
		failures.append("M2 scenario route fixture is missing: small_underground_casino.")
		return
	if bool(run_state.travel_route_status(underground_route).get("available", true)):
		failures.append("M2 scenario route should be locked before the event outcome.")
	var event_def := library.event("parking_lot_tip")
	if event_def.is_empty():
		failures.append("M2 scenario event fixture is missing: parking_lot_tip.")
		return
	var event := EventModule.new()
	event.setup(event_def)
	if not event.can_trigger(run_state, run_state.current_environment):
		failures.append("M2 scenario event did not respond as eligible from current system state.")
		return
	var event_before := _run_state_result_snapshot(run_state)
	var event_result := event.resolve(run_state, run_state.current_environment, "follow_tip")
	_check_event_result_delta_shape(event_result, failures)
	_check_event_result_applied(event_before, run_state, event_result, "M2 scenario event result", failures)
	if not bool(run_state.narrative_flags.get("underground_tip", false)):
		failures.append("M2 scenario event did not set its downstream travel flag.")
	if not bool(run_state.travel_route_status(underground_route).get("available", false)):
		failures.append("M2 scenario event outcome did not unlock the gated route choice.")

	var before_travel_bankroll := run_state.bankroll
	var before_travel_suspicion := run_state.suspicion_level()
	var travel_result := _fixture_travel_result(run_state, underground_route, "small_underground_casino")
	GameModule.apply_result(run_state, travel_result)
	if run_state.bankroll != before_travel_bankroll - int(underground_route.get("cost", 0)):
		failures.append("M2 scenario travel cost did not apply through result-delta.")
	if run_state.suspicion_level() != before_travel_suspicion + int(underground_route.get("suspicion_delta", 0)):
		failures.append("M2 scenario travel risk did not apply through result-delta.")

	var lender := library.lender("street_lender")
	if lender.is_empty():
		failures.append("M2 scenario lender fixture is missing: street_lender.")
		return
	var lender_result := _fixture_lender_result(run_state, lender, "street_lender")
	GameModule.apply_result(run_state, lender_result)
	if run_state.debt.is_empty():
		failures.append("M2 scenario supported lender did not add debt.")
	if run_state.economy() != "distressed":
		failures.append("M2 scenario debt plus low bankroll did not affect economy pressure.")

	var service := library.service("cashier_tip")
	if service.is_empty():
		failures.append("M2 scenario service fixture is missing: cashier_tip.")
		return
	var service_before_bankroll := run_state.bankroll
	var service_before_suspicion := run_state.suspicion_level()
	var service_result := _fixture_service_result(run_state, service, "cashier_tip")
	GameModule.apply_result(run_state, service_result)
	if run_state.bankroll != service_before_bankroll - int(service.get("cost", 0)):
		failures.append("M2 scenario service cost did not apply through result-delta.")
	if run_state.suspicion_level() >= service_before_suspicion:
		failures.append("M2 scenario supported service did not reduce suspicion pressure.")

	var expected := _save_service_expected_snapshot(run_state)
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_m2_system_scenario"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save M2 system scenario state: %s." % save_error)
		return
	var loaded = save_service.load_run(slot_id)
	if loaded == null:
		failures.append("Save service could not reload M2 system scenario state.")
		return
	_check_run_state_save_round_trip(expected, loaded.to_dict(), failures)


# Checks the boss-floor demo objective triggers and resolves The House Calls through RunState.
func _check_demo_boss_objective_foundation(library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino boss archetype is missing.")
		return
	_check_grand_casino_spatial_split(library, boss_archetype, failures)
	_check_grand_casino_chips_and_cage(library, boss_archetype, failures)
	_check_grand_casino_players_card_tiers(library, boss_archetype, failures)
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	if objective.is_empty() or str(objective.get("type", "")) != "bankroll_target":
		failures.append("Grand Casino must define a bankroll-target demo objective.")
		return
	var finale_event_id := str(objective.get("finale_event_id", ""))
	if finale_event_id != "the_house_calls":
		failures.append("Grand Casino demo objective must route into The House Calls finale event.")
		return
	if int(objective.get("target_bankroll", -1)) != 0:
		failures.append("Grand Casino Players Card objective should not require a total bankroll target.")
	var route := library.route("grand_casino")
	if route.is_empty() or int(route.get("cost", 0)) < 70:
		failures.append("Grand Casino route must exist and keep a meaningful buy-in.")
	elif int(route.get("requires_travel_count_min", 0)) < 1 or not bool(route.get("hide_until_travel_count_met", false)):
		failures.append("Grand Casino route should stay hidden until at least one travel has occurred.")
	var underground := _archetype_by_id(library, "small_underground_casino")
	if underground.is_empty() or not _string_array(underground.get("next_archetypes", [])).has("grand_casino"):
		failures.append("Underground casino must route to the Grand Casino boss floor.")
	for boss_event_id in ["pit_boss_sweep", "comped_suite_offer", "eye_in_the_sky", "high_roller_cashout", "the_house_calls"]:
		var event := library.event(boss_event_id)
		if event.is_empty() or not _string_array(event.get("scopes", [])).has("boss"):
			failures.append("Boss-only event is missing or not scoped to boss: %s." % boss_event_id)
	var finale_event := library.event(finale_event_id)
	if finale_event.is_empty() or str(finale_event.get("type", "")) != "landmark":
		failures.append("The House Calls must be authored as a landmark boss event.")
		return
	var high_roller_event := library.event("high_roller_cashout")
	if high_roller_event.is_empty() or str(high_roller_event.get("type", "")) != "landmark":
		failures.append("High-roller cashout must be authored as a landmark boss event.")
		return

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("M2-FUN-BOSS")
	var rng := run_state.create_rng("boss-objective")
	var environment := EnvironmentInstance.from_archetype(boss_archetype, 3, rng, library)
	run_state.set_environment(environment.to_dict())
	var high_roller_target := int(objective.get("high_roller_target_bankroll", 0))
	var high_roller_net := int(objective.get("high_roller_net_winnings", 0))
	var high_roller_min_games := int(objective.get("high_roller_min_grand_casino_games", 0))
	var high_roller_max_heat := int(objective.get("high_roller_max_heat", -1))
	var showdown_heat_threshold := int(objective.get("showdown_heat_threshold", 0))
	var forced_showdown_heat_threshold := int(objective.get("forced_showdown_heat_threshold", 0))
	if high_roller_target != 0:
		failures.append("Grand Casino Players Card objective should be gated by net Grand Casino winnings, not total bankroll.")
	if high_roller_net != 30 or high_roller_min_games != 5:
		failures.append("Grand Casino Gold review should use the data-tuned five-game, $30 net target.")
	if high_roller_net <= 0 or high_roller_min_games <= 0 or high_roller_max_heat < 0:
		failures.append("Grand Casino clean lane must define net winnings, game count, and max heat.")
	if showdown_heat_threshold <= high_roller_max_heat or forced_showdown_heat_threshold <= showdown_heat_threshold:
		failures.append("Grand Casino heat lane thresholds should escalate above clean-route heat.")
	if str(objective.get("showdown_event_id", "")) != "the_house_calls":
		failures.append("Grand Casino heat lane must name The House Calls as showdown_event_id.")
	if str(objective.get("high_roller_event_id", "")) != "high_roller_cashout":
		failures.append("Grand Casino clean lane must name high_roller_cashout as high_roller_event_id.")

	var travel_sync_run: RunState = RunStateScript.new()
	travel_sync_run.start_new("M2-FUN-BOSS-TRAVEL-SYNC")
	travel_sync_run.bankroll = 350
	travel_sync_run.set_environment(environment.to_dict())
	var route_cost := maxi(0, int(route.get("cost", 100)))
	var expected_entry_after_cost := travel_sync_run.bankroll - route_cost
	var travel_sync_deltas := GameModule.empty_result_deltas()
	travel_sync_deltas["bankroll_delta"] = -route_cost
	var travel_sync_result := GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": "travel",
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"deltas": travel_sync_deltas,
		"environment_id": str(travel_sync_run.current_environment.get("id", "")),
		"environment_archetype_id": "grand_casino",
		"message": "Travel sync fixture.",
	})
	GameModule.apply_result(travel_sync_run, travel_sync_result)
	if int(travel_sync_run.narrative_flags.get("grand_casino_entry_bankroll", -1)) != expected_entry_after_cost:
		failures.append("Grand Casino entry bankroll should be recorded after the travel buy-in is paid.")
	if int(travel_sync_run.demo_objective_status().get("grand_casino_net_winnings", -1)) != 0:
		failures.append("Grand Casino net winnings should start at $0 after the travel buy-in is paid.")

	var entry_bankroll := int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.bankroll))
	run_state.bankroll = entry_bankroll + high_roller_net - 1
	var status_before := run_state.demo_objective_status()
	if not bool(status_before.get("active", false)) or not bool(status_before.get("grand_casino_objective", false)):
		failures.append("Boss objective should report the Grand Casino dual-lane model.")
	if bool(status_before.get("complete", true)) or bool(status_before.get("high_roller_ready", false)) or bool(status_before.get("showdown_pending", false)):
		failures.append("Boss objective should be incomplete below clean and heat route targets.")
	var lanes: Dictionary = status_before.get("lanes", {})
	if not lanes.has("clean") or not lanes.has("heat"):
		failures.append("Grand Casino objective status did not expose both clean and heat lanes.")

	var non_boss_run: RunState = RunStateScript.new()
	non_boss_run.start_new("M2-FUN-BOSS-NON-BOSS")
	var non_boss_environment := environment.to_dict()
	non_boss_environment["id"] = "casino_non_boss_objective_fixture"
	non_boss_environment["archetype_id"] = "gas_station_casino"
	non_boss_environment["kind"] = "casino"
	non_boss_environment["event_ids"] = []
	non_boss_run.set_environment(non_boss_environment)
	non_boss_run.bankroll = RunState.DEFAULT_BANKROLL + high_roller_net
	var non_boss_status := non_boss_run.demo_objective_status()
	if bool(non_boss_status.get("active", false)):
		failures.append("Grand Casino boss objective should not appear outside the boss floor.")
	non_boss_run.evaluate_environment_objective_state()
	if bool(non_boss_run.narrative_flags.get("demo_finale_pending", false)) or _string_array(non_boss_run.current_environment.get("event_ids", [])).has(finale_event_id):
		failures.append("The House Calls triggered outside the boss floor.")
	if non_boss_run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Non-boss objective fixture should not end or fail the run.")

	var clean_run: RunState = RunStateScript.new()
	clean_run.start_new("M2-FUN-BOSS-CLEAN")
	clean_run.set_environment(environment.to_dict())
	for game_index in range(high_roller_min_games):
		var progress_deltas := GameModule.empty_result_deltas()
		progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 10 + game_index}]
		var progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "clean_progress",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": progress_deltas,
			"environment_id": str(clean_run.current_environment.get("id", "")),
			"message": "Clean boss-floor progress.",
		})
		clean_run.record_grand_casino_game_result(progress_result)
	clean_run.bankroll = int(clean_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	clean_run.evaluate_environment_objective_state()
	var clean_status := clean_run.demo_objective_status()
	if not bool(clean_status.get("high_roller_ready", false)) or not bool(clean_status.get("players_card_ready", false)) or not bool(clean_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("Grand Casino clean lane did not report Players Card readiness.")
	if bool(clean_run.narrative_flags.get("demo_victory", false)) or clean_run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Grand Casino clean lane should not set victory during A1 state reporting.")
	var ready_cage := CageWindowViewModelScript.build(clean_run)
	var ready_card: Dictionary = ready_cage.get("card", {}) if typeof(ready_cage.get("card", {})) == TYPE_DICTIONARY else {}
	if str(_copy_dict(ready_cage.get("host", {})).get("name", "")) != "Linda" or not bool(ready_card.get("can_review", false)) or str(ready_card.get("review_state", "")) != "ready":
		failures.append("Cage view model did not expose Linda and the ready Players Card review.")
	if _copy_array(ready_cage.get("promotions", [])).is_empty():
		failures.append("Cage view model did not populate Players Card tier benefits and comps.")

	var save_service: SaveService = SaveServiceScript.new()
	var clean_slot_id := "foundation_check_grand_casino_clean_ready"
	var save_error: Error = save_service.save_run(clean_run, clean_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Grand Casino clean objective state: %s." % save_error)
		return
	var loaded_clean = save_service.load_run(clean_slot_id)
	if loaded_clean == null:
		failures.append("Save service could not reload Grand Casino clean objective state.")
		return
	var loaded_clean_status: Dictionary = loaded_clean.demo_objective_status()
	if not bool(loaded_clean_status.get("high_roller_ready", false)) or int(loaded_clean_status.get("grand_casino_games_played", 0)) != high_roller_min_games:
		failures.append("Grand Casino clean objective metadata did not survive SaveService load.")
	if _string_array(loaded_clean.current_environment.get("event_ids", [])).has("high_roller_cashout"):
		failures.append("Players Card review should remain at the Cage instead of the Grand Casino event surface.")
	var high_roller_module := EventModule.new()
	high_roller_module.setup(high_roller_event)
	var high_roller_choices: Array = high_roller_module.choices(loaded_clean, loaded_clean.current_environment)
	if high_roller_choices.size() != 1 or str((high_roller_choices[0] as Dictionary).get("id", "")) != "high_roller_cashout":
		failures.append("Cage Players Card action should expose one deliberate claim response when clean readiness is pending.")
	var cashout_result := high_roller_module.resolve(loaded_clean, loaded_clean.current_environment, "high_roller_cashout")
	if not bool(cashout_result.get("ok", false)) or loaded_clean.run_status != RunState.RUN_STATUS_ENDED:
		failures.append("Players Card claim did not end the run in demo victory.")
	if not bool(loaded_clean.narrative_flags.get("demo_victory", false)) or str(loaded_clean.narrative_flags.get("demo_victory_route", "")) != "high_roller_cashout":
		failures.append("Players Card claim did not set the canonical clean victory route.")
	if bool(loaded_clean.narrative_flags.get("high_roller_cashout_pending", true)) or bool(loaded_clean.narrative_flags.get("grand_casino_high_roller_ready", true)):
		failures.append("Players Card claim did not clear pending clean-route flags.")
	if str(loaded_clean.current_demo_victory_message()).find("Players Card") == -1:
		failures.append("Players Card victory message did not mention the card.")
	var high_roller_victory_round_trip_status := "unsaved"
	var high_roller_win_slot_id := "foundation_check_high_roller_cashout_win"
	save_error = save_service.save_run(loaded_clean, high_roller_win_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Players Card win state: %s." % save_error)
		return
	var loaded_high_roller_win = save_service.load_run(high_roller_win_slot_id)
	if loaded_high_roller_win == null:
		failures.append("Save service could not reload Players Card win state.")
		return
	high_roller_victory_round_trip_status = str(loaded_high_roller_win.run_status)
	if loaded_high_roller_win.run_status != RunState.RUN_STATUS_ENDED or not bool(loaded_high_roller_win.narrative_flags.get("demo_victory", false)):
		failures.append("Players Card win status did not survive SaveService load.")
	if str(loaded_high_roller_win.narrative_flags.get("demo_victory_route", "")) != "high_roller_cashout":
		failures.append("Players Card win route did not survive SaveService load.")
	if bool(loaded_high_roller_win.narrative_flags.get("high_roller_cashout_pending", true)) or bool(loaded_high_roller_win.narrative_flags.get("grand_casino_high_roller_ready", true)):
		failures.append("Players Card win reloaded with pending clean-route flags.")
	if str(loaded_high_roller_win.current_demo_victory_message()).find("Players Card") == -1:
		failures.append("Players Card win message did not survive SaveService load.")

	var cheated_cashout_run: RunState = RunStateScript.new()
	cheated_cashout_run.start_new("M2-FUN-BOSS-CHEATED-CASHOUT")
	cheated_cashout_run.set_environment(environment.to_dict())
	var cheat_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "peek_fixture",
		"action_kind": "cheat",
		"stake": 0,
		"deltas": GameModule.empty_result_deltas(),
		"environment_id": str(cheated_cashout_run.current_environment.get("id", "")),
		"message": "Cheat evidence fixture.",
	})
	cheated_cashout_run.record_grand_casino_game_result(cheat_result)
	for game_index in range(high_roller_min_games):
		var cheated_progress_deltas := GameModule.empty_result_deltas()
		cheated_progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 12 + game_index}]
		var cheated_progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "cheated_progress",
			"action_kind": "legal",
			"stake": 12 + game_index,
			"deltas": cheated_progress_deltas,
			"environment_id": str(cheated_cashout_run.current_environment.get("id", "")),
			"message": "Cheated cashout progress.",
		})
		cheated_cashout_run.record_grand_casino_game_result(cheated_progress_result)
	cheated_cashout_run.bankroll = int(cheated_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	cheated_cashout_run.evaluate_environment_objective_state()
	var cheated_cashout_status := cheated_cashout_run.demo_objective_status()
	if bool(cheated_cashout_status.get("high_roller_ready", false)) or bool(cheated_cashout_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("Cheated Grand Casino player should not receive the Players Card.")
	if not bool(cheated_cashout_status.get("showdown_pending", false)) or str(cheated_cashout_run.narrative_flags.get("grand_casino_showdown_trigger_reason", "")) != "dirty_money":
		failures.append("Cheated Grand Casino money target should route to the Pit Boss Showdown.")
	if int(cheated_cashout_status.get("grand_casino_open_cheat_actions", 0)) <= 0:
		failures.append("Grand Casino open cheat action count was not tracked.")
	var blocked_cage := CageWindowViewModelScript.build(cheated_cashout_run)
	var blocked_card: Dictionary = blocked_cage.get("card", {}) if typeof(blocked_cage.get("card", {})) == TYPE_DICTIONARY else {}
	if str(blocked_card.get("review_state", "")) != "ineligible" or bool(blocked_card.get("can_review", true)) or str(blocked_card.get("review_detail", "")).find("permanently") == -1:
		failures.append("Cage view model did not make permanent Players Card ineligibility visible.")

	var hot_cashout_run: RunState = RunStateScript.new()
	hot_cashout_run.start_new("M2-FUN-BOSS-HOT-CASHOUT")
	hot_cashout_run.set_environment(environment.to_dict())
	hot_cashout_run.add_suspicion("cashout_heat_fixture", high_roller_max_heat + 1, "behavior")
	for game_index in range(high_roller_min_games):
		var hot_progress_deltas := GameModule.empty_result_deltas()
		hot_progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 14 + game_index}]
		var hot_progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "hot_progress",
			"action_kind": "legal",
			"stake": 14 + game_index,
			"deltas": hot_progress_deltas,
			"environment_id": str(hot_cashout_run.current_environment.get("id", "")),
			"message": "Hot cashout progress.",
		})
		hot_cashout_run.record_grand_casino_game_result(hot_progress_result)
	hot_cashout_run.bankroll = int(hot_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	hot_cashout_run.evaluate_environment_objective_state()
	var hot_cashout_status := hot_cashout_run.demo_objective_status()
	if bool(hot_cashout_status.get("high_roller_ready", false)) or bool(hot_cashout_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("High-heat Grand Casino player should not receive the Players Card.")
	if not bool(hot_cashout_status.get("showdown_pending", false)):
		failures.append("High-heat Grand Casino money target should route to the Pit Boss Showdown.")
	if int(hot_cashout_status.get("grand_casino_max_heat", 0)) <= high_roller_max_heat:
		failures.append("Grand Casino max visit heat was not tracked for cashout eligibility.")

	var non_boss_cashout_environment := non_boss_environment.duplicate(true)
	non_boss_cashout_environment["event_ids"] = ["high_roller_cashout"]
	var non_boss_cashout_run: RunState = RunStateScript.new()
	non_boss_cashout_run.start_new("M2-FUN-BOSS-NON-BOSS-CASHOUT")
	non_boss_cashout_run.set_environment(non_boss_cashout_environment)
	non_boss_cashout_run.narrative_flags["high_roller_cashout_pending"] = true
	if high_roller_module.can_trigger(non_boss_cashout_run, non_boss_cashout_run.current_environment):
		failures.append("Players Card event should appear only in the Grand Casino.")

	run_state.current_environment["turns"] = 0
	run_state.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	run_state.evaluate_environment_objective_state()
	var showdown_status := run_state.demo_objective_status()
	if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Boss objective should trigger the finale before ending the run.")
	if bool(run_state.narrative_flags.get("demo_victory", false)):
		failures.append("Heat lane set demo victory before The House Calls branch resolved.")
	if not bool(showdown_status.get("showdown_pending", false)) or not bool(run_state.narrative_flags.get("demo_finale_pending", false)):
		failures.append("Grand Casino heat lane did not mark The House Calls as pending.")
	if not bool(showdown_status.get("staff_attention_active", false)):
		failures.append("Grand Casino heat lane did not expose staff attention while pending.")
	if not _string_array(run_state.current_environment.get("event_ids", [])).has(finale_event_id):
		failures.append("Boss objective did not inject The House Calls into the active event list.")
	var finale_module := EventModule.new()
	finale_module.setup(finale_event)
	if not finale_module.can_trigger(run_state, run_state.current_environment):
		failures.append("The House Calls did not become triggerable at the boss target.")
	var showdown_slot_id := "foundation_check_grand_casino_showdown_pending"
	save_error = save_service.save_run(run_state, showdown_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Grand Casino showdown objective state: %s." % save_error)
		return
	var loaded_showdown = save_service.load_run(showdown_slot_id)
	if loaded_showdown == null:
		failures.append("Save service could not reload Grand Casino showdown objective state.")
		return
	var loaded_showdown_status: Dictionary = loaded_showdown.demo_objective_status()
	if loaded_showdown.run_status != RunState.RUN_STATUS_ACTIVE or not bool(loaded_showdown_status.get("showdown_pending", false)):
		failures.append("Grand Casino showdown objective state did not survive SaveService load.")
	if bool(loaded_showdown.narrative_flags.get("demo_victory", false)):
		failures.append("Grand Casino showdown pending state should not become victory after SaveService load.")

	var watched_heat_run: RunState = RunStateScript.new()
	watched_heat_run.start_new("M2-FUN-BOSS-WATCHED-HEAT")
	watched_heat_run.set_environment(environment.to_dict())
	watched_heat_run.current_environment["turns"] = 0
	var watched_pressure := watched_heat_run.security_action_pressure("cheat", 10, 100)
	if bool(watched_pressure.get("ended", true)):
		failures.append("Grand Casino security pressure should not return generic capture while Rourke can reroute.")
	var watched_heat_deltas := GameModule.empty_result_deltas()
	watched_heat_deltas["suspicion_delta"] = 100
	watched_heat_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 10, "pit_boss_heat_bonus": 30}]
	watched_heat_deltas["messages"] = ["Watched heat fixture."]
	var watched_heat_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "watched_heat_fixture",
		"action_kind": "cheat",
		"stake": 10,
		"suspicion_delta": 100,
		"deltas": watched_heat_deltas,
		"environment_id": str(watched_heat_run.current_environment.get("id", "")),
		"message": "Watched heat fixture.",
	})
	GameModule.apply_result(watched_heat_run, watched_heat_result)
	var watched_heat_status := watched_heat_run.demo_objective_status()
	if watched_heat_run.run_status != RunState.RUN_STATUS_ACTIVE or not bool(watched_heat_status.get("showdown_pending", false)):
		failures.append("Watched Grand Casino heat should queue showdown without police capture.")
	if watched_heat_run.run_failure_reason == RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Watched Grand Casino heat incorrectly recorded police capture.")
	var event_count_after_first := _count_string_occurrences(watched_heat_run.current_environment.get("event_ids", []), finale_event_id)
	watched_heat_run.add_suspicion("repeat_heat_fixture", 5, "behavior")
	var event_count_after_repeat := _count_string_occurrences(watched_heat_run.current_environment.get("event_ids", []), finale_event_id)
	if event_count_after_repeat != event_count_after_first:
		failures.append("Repeated Grand Casino heat duplicated the showdown event.")

	var forced_heat_run: RunState = RunStateScript.new()
	forced_heat_run.start_new("M2-FUN-BOSS-FORCED-HEAT")
	forced_heat_run.set_environment(environment.to_dict())
	var forced_initial_watch := forced_heat_run.pit_boss_watch_status(forced_heat_run.current_environment)
	forced_heat_run.current_environment["turns"] = int(forced_initial_watch.get("watched_turns", 2))
	forced_heat_run.current_environment["event_ids"] = []
	forced_heat_run.add_suspicion("forced_heat_fixture", forced_showdown_heat_threshold, "behavior")
	var forced_heat_status := forced_heat_run.demo_objective_status()
	if forced_heat_run.run_status != RunState.RUN_STATUS_ACTIVE or not bool(forced_heat_status.get("showdown_pending", false)):
		failures.append("Unwatched forced Grand Casino heat should establish attention and queue showdown.")
	if not bool(forced_heat_run.narrative_flags.get("grand_casino_attention_forced_heat", false)):
		failures.append("Forced Grand Casino heat did not record the forced attention flag.")
	var forced_story_found := false
	for entry_value in forced_heat_run.story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "grand_casino_heat_reroute":
			forced_story_found = true
			break
	if not forced_story_found:
		failures.append("Forced Grand Casino heat did not log a clear reroute story entry.")

	var outside_heat_run: RunState = RunStateScript.new()
	outside_heat_run.start_new("M2-FUN-BOSS-OUTSIDE-HEAT")
	outside_heat_run.set_environment(non_boss_environment)
	outside_heat_run.add_suspicion("outside_heat_fixture", 100, "behavior")
	if outside_heat_run.run_status != RunState.RUN_STATUS_FAILED or outside_heat_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Outside Grand Casino heat 100 should still fail as police_capture.")

	var watched_run: RunState = RunStateScript.new()
	watched_run.start_new("M2-FUN-BOSS-WATCH")
	watched_run.set_environment(environment.to_dict())
	watched_run.current_environment["turns"] = 0
	var watched_status := watched_run.pit_boss_watch_status(watched_run.current_environment)
	if not bool(watched_status.get("active", false)) or not bool(watched_status.get("watched", false)):
		failures.append("Pit boss watch state should be active and watched at turn zero.")
	watched_run.current_environment["turns"] = int(watched_status.get("watched_turns", 2))
	var clear_status := watched_run.pit_boss_watch_status(watched_run.current_environment)
	if bool(clear_status.get("watched", true)):
		failures.append("Pit boss watch state should have an unwatched cycle window.")
	var game: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	if game != null:
		watched_run.current_environment["turns"] = 0
		var watched_actions: Array = game.cheat_actions(watched_run, watched_run.current_environment)
		watched_run.current_environment["turns"] = int(watched_status.get("watched_turns", 2))
		var clear_actions: Array = game.cheat_actions(watched_run, watched_run.current_environment)
		if watched_actions.is_empty() or clear_actions.is_empty():
			failures.append("Boss watch fixture needs cheat actions to compare heat.")
		elif int((watched_actions[0] as Dictionary).get("suspicion_delta", 0)) <= int((clear_actions[0] as Dictionary).get("suspicion_delta", 0)):
			failures.append("Cheating while watched did not add extra pit-boss heat.")

	var finale_payload: Dictionary = {}
	var finale_payload_value: Variant = finale_event.get("payload", {})
	if typeof(finale_payload_value) == TYPE_DICTIONARY:
		finale_payload = (finale_payload_value as Dictionary).duplicate(true)
	var showdown_config: Dictionary = {}
	var showdown_tuning_value: Variant = finale_payload.get("showdown_tuning", {})
	if typeof(showdown_tuning_value) == TYPE_DICTIONARY:
		showdown_config = (showdown_tuning_value as Dictionary).duplicate(true)
	showdown_config["success_message"] = str(finale_payload.get("success_message", ""))
	showdown_config["failure_message"] = str(finale_payload.get("failure_message", ""))

	var active_run: RunState = RunStateScript.new()
	active_run.start_new("M2-FUN-HOUSE-CALLS-ACTIVE")
	active_run.set_environment(environment.to_dict())
	active_run.current_environment["turns"] = 0
	active_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	active_run.evaluate_environment_objective_state()
	if not finale_module.can_trigger(active_run, active_run.current_environment):
		failures.append("The House Calls should trigger from the pending showdown flag.")
	var pending_choices: Array = finale_module.choices(active_run, active_run.current_environment)
	if pending_choices.size() != 1 or str((pending_choices[0] as Dictionary).get("id", "")) != "enter_back_room":
		failures.append("Pending showdown should expose only the back-room arrival beat.")
	var arrival_result := finale_module.resolve(active_run, active_run.current_environment, "enter_back_room")
	if not bool(arrival_result.get("ok", false)) or not bool(active_run.narrative_flags.get("grand_casino_showdown_active", false)):
		failures.append("Back-room arrival did not start the active Pit Boss Showdown.")
	if str(active_run.narrative_flags.get("grand_casino_showdown_step", "")) != "pressure_choice":
		failures.append("Back-room arrival did not preserve the pressure-choice showdown step.")
	var pressure_choices: Array = finale_module.choices(active_run, active_run.current_environment)
	var pressure_choice_ids: Array = []
	for pressure_choice_value in pressure_choices:
		if typeof(pressure_choice_value) == TYPE_DICTIONARY:
			pressure_choice_ids.append(str((pressure_choice_value as Dictionary).get("id", "")))
	if not pressure_choice_ids.has("hold_steady") or not pressure_choice_ids.has("talk_down") or not pressure_choice_ids.has("take_the_edge"):
		failures.append("Active showdown did not expose all pressure choices.")
	var active_slot_id := "foundation_check_house_calls_active"
	save_error = save_service.save_run(active_run, active_slot_id)
	if save_error != OK:
		failures.append("Save service could not save active showdown state: %s." % save_error)
		return
	var loaded_active = save_service.load_run(active_slot_id)
	if loaded_active == null:
		failures.append("Save service could not reload active showdown state.")
		return
	if not bool(loaded_active.narrative_flags.get("grand_casino_showdown_active", false)) or str(loaded_active.narrative_flags.get("grand_casino_showdown_step", "")) != "pressure_choice":
		failures.append("Active showdown step did not survive SaveService load.")
	var loaded_pressure_choices: Array = finale_module.choices(loaded_active, loaded_active.current_environment)
	if loaded_pressure_choices.size() != 3:
		failures.append("Loaded active showdown did not preserve pressure choices.")

	var clean_preview := active_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var clean_check: Dictionary = {}
	var clean_check_value: Variant = clean_preview.get("check", {})
	if typeof(clean_check_value) == TYPE_DICTIONARY:
		clean_check = clean_check_value as Dictionary
	var item_run: RunState = RunStateScript.new()
	item_run.start_new("M2-FUN-HOUSE-CALLS-ITEM")
	item_run.set_environment(environment.to_dict())
	item_run.current_environment["turns"] = 0
	item_run.add_item("cheap_sunglasses")
	item_run.add_item("card_counters_notes")
	item_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	item_run.evaluate_environment_objective_state()
	finale_module.resolve(item_run, item_run.current_environment, "enter_back_room")
	var item_preview := item_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var item_check: Dictionary = {}
	var item_check_value: Variant = item_preview.get("check", {})
	if typeof(item_check_value) == TYPE_DICTIONARY:
		item_check = item_check_value as Dictionary
	if int(item_check.get("success_chance", 0)) <= int(clean_check.get("success_chance", 0)):
		failures.append("Item-assisted showdown preview did not improve the check chance.")
	var dirty_preview_run: RunState = RunStateScript.new()
	dirty_preview_run.start_new("M2-FUN-HOUSE-CALLS-DIRTY-PREVIEW")
	dirty_preview_run.set_environment(environment.to_dict())
	dirty_preview_run.current_environment["turns"] = 0
	dirty_preview_run.narrative_flags["grand_casino_cheat_evidence"] = true
	dirty_preview_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	dirty_preview_run.evaluate_environment_objective_state()
	finale_module.resolve(dirty_preview_run, dirty_preview_run.current_environment, "enter_back_room")
	var dirty_preview := dirty_preview_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var dirty_check: Dictionary = {}
	var dirty_check_value: Variant = dirty_preview.get("check", {})
	if typeof(dirty_check_value) == TYPE_DICTIONARY:
		dirty_check = dirty_check_value as Dictionary
	if int(clean_check.get("success_chance", 0)) <= int(dirty_check.get("success_chance", 0)):
		failures.append("Clean-play showdown preview did not beat the dirty-evidence check chance.")

	var win_run: RunState = null
	var win_result: Dictionary = {}
	for index in range(80):
		var candidate: RunState = RunStateScript.new()
		candidate.start_new("M2-FUN-HOUSE-CALLS-WIN-%d" % index)
		candidate.set_environment(environment.to_dict())
		candidate.current_environment["turns"] = 0
		candidate.add_item("cheap_sunglasses")
		candidate.add_item("card_counters_notes")
		candidate.narrative_flags["grand_casino_event_pit_boss_sweep_lay_low"] = true
		candidate.narrative_flags["grand_casino_event_eye_in_the_sky_change_table"] = true
		candidate.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
		candidate.evaluate_environment_objective_state()
		finale_module.resolve(candidate, candidate.current_environment, "enter_back_room")
		var preview := candidate.grand_casino_showdown_status(showdown_config, "hold_steady")
		var preview_check: Dictionary = {}
		var preview_check_value: Variant = preview.get("check", {})
		if typeof(preview_check_value) == TYPE_DICTIONARY:
			preview_check = preview_check_value as Dictionary
		if bool(preview_check.get("success", false)):
			win_run = candidate
			win_result = finale_module.resolve(win_run, win_run.current_environment, "hold_steady")
			break
	if win_run == null:
		failures.append("Could not find a deterministic successful Pit Boss Showdown fixture.")
	else:
		if not bool(win_result.get("ok", false)) or win_run.run_status != RunState.RUN_STATUS_ENDED:
			failures.append("Pit Boss Showdown success did not end in demo victory.")
		if not bool(win_run.narrative_flags.get("demo_victory", false)) or str(win_run.narrative_flags.get("demo_victory_route", "")) != "pit_boss_showdown":
			failures.append("Pit Boss Showdown success did not set the canonical victory route.")
		if bool(win_run.narrative_flags.get("grand_casino_showdown_pending", true)) or bool(win_run.narrative_flags.get("grand_casino_showdown_active", true)):
			failures.append("Pit Boss Showdown success did not clear pending/active flags.")
		if str(win_run.current_demo_victory_message()).find("winnings") == -1:
			failures.append("Pit Boss Showdown victory message did not mention walking with winnings.")
		var win_status := win_run.demo_objective_status()
		if str(win_status.get("objective_state", "")) != "victory":
			failures.append("Grand Casino objective status did not report victory after showdown success.")
		var win_slot_id := "foundation_check_house_calls_win"
		save_error = save_service.save_run(win_run, win_slot_id)
		if save_error != OK:
			failures.append("Save service could not save House Calls win state: %s." % save_error)
			return
		var loaded_win = save_service.load_run(win_slot_id)
		if loaded_win == null:
			failures.append("Save service could not reload House Calls win state.")
			return
		if loaded_win.run_status != RunState.RUN_STATUS_ENDED or not bool(loaded_win.narrative_flags.get("demo_victory", false)):
			failures.append("House Calls win status did not survive SaveService load.")

	var failure_run: RunState = null
	var failure_result: Dictionary = {}
	for index in range(80):
		var candidate: RunState = RunStateScript.new()
		candidate.start_new("M2-FUN-HOUSE-CALLS-FAIL-%d" % index)
		candidate.set_environment(environment.to_dict())
		candidate.current_environment["turns"] = 0
		candidate.add_item("marked_cards")
		candidate.add_item("foil_sleeve")
		candidate.add_item("weighted_keyring")
		candidate.add_item("xray_glasses")
		candidate.add_item("tab_detector")
		candidate.drunk_level = 75
		candidate.alcoholic_level = 100
		candidate.add_debt({"id": "showdown_debt_one", "lender_id": "street_lender", "balance": 40, "status": "active"})
		candidate.add_debt({"id": "showdown_debt_two", "lender_id": "motel_friend", "balance": 30, "status": "overdue"})
		candidate.narrative_flags["grand_casino_event_pit_boss_sweep_act_natural"] = true
		candidate.narrative_flags["grand_casino_event_eye_in_the_sky_press_anyway"] = true
		candidate.narrative_flags["grand_casino_event_comped_suite_offer_take_comp"] = true
		candidate.add_suspicion("boss_heat_fixture", 100, "behavior")
		candidate.evaluate_environment_objective_state()
		finale_module.resolve(candidate, candidate.current_environment, "enter_back_room")
		var preview := candidate.grand_casino_showdown_status(showdown_config, "take_the_edge")
		var preview_check: Dictionary = {}
		var preview_check_value: Variant = preview.get("check", {})
		if typeof(preview_check_value) == TYPE_DICTIONARY:
			preview_check = preview_check_value as Dictionary
		if not bool(preview_check.get("success", true)):
			failure_run = candidate
			failure_result = finale_module.resolve(failure_run, failure_run.current_environment, "take_the_edge")
			break
	if failure_run == null:
		failures.append("Could not find a deterministic failed Pit Boss Showdown fixture.")
	else:
		if not bool(failure_result.get("ok", false)) or failure_run.run_status != RunState.RUN_STATUS_FAILED:
			failures.append("Pit Boss Showdown failure did not fail the run.")
		if failure_run.run_failure_reason != RunState.FAILURE_CASINO_TAKEN_OUT_BACK:
			failures.append("Pit Boss Showdown failure did not record casino_taken_out_back.")
		if str(failure_run.run_failure_message).find("police") != -1 or str(failure_run.run_failure_message).find("cuffs") != -1:
			failures.append("Pit Boss Showdown failure used generic police-capture copy.")
		if bool(failure_run.narrative_flags.get("grand_casino_showdown_pending", true)) or bool(failure_run.narrative_flags.get("grand_casino_showdown_active", true)):
			failures.append("Pit Boss Showdown failure did not clear pending/active flags.")
		var failure_status := failure_run.demo_objective_status()
		if str(failure_status.get("objective_state", "")) != "failure":
			failures.append("Grand Casino objective status did not report failure after showdown loss.")
		var failure_slot_id := "foundation_check_house_calls_failure"
		save_error = save_service.save_run(failure_run, failure_slot_id)
		if save_error != OK:
			failures.append("Save service could not save House Calls failure state: %s." % save_error)
			return
		var loaded_failure = save_service.load_run(failure_slot_id)
		if loaded_failure == null:
			failures.append("Save service could not reload House Calls failure state.")
			return
		if loaded_failure.run_status != RunState.RUN_STATUS_FAILED or loaded_failure.run_failure_reason != RunState.FAILURE_CASINO_TAKEN_OUT_BACK:
			failures.append("House Calls failure status did not survive SaveService load.")
	print("GRAND_CASINO_OBJECTIVE_LANES clean_ready=%s showdown_pending=%s outside_active=%s games=%d" % [
		str(clean_status.get("high_roller_ready", false)),
		str(showdown_status.get("showdown_pending", false)),
		str(non_boss_status.get("active", false)),
		int(loaded_clean_status.get("grand_casino_games_played", 0)),
	])
	print("GRAND_CASINO_HEAT_REROUTE watched_pending=%s forced_pending=%s outside_reason=%s duplicate_events=%d" % [
		str(watched_heat_status.get("showdown_pending", false)),
		str(forced_heat_status.get("showdown_pending", false)),
		str(outside_heat_run.run_failure_reason),
		event_count_after_repeat,
	])
	var showdown_win_status := "missing"
	if win_run != null:
		showdown_win_status = str(win_run.run_status)
	var showdown_failure_reason := "missing"
	if failure_run != null:
		showdown_failure_reason = str(failure_run.run_failure_reason)
	print("HOUSE_CALLS_SHOWDOWN trigger=%s active_step=%s win=%s failure=%s item_chance=%d clean_chance=%d dirty_chance=%d" % [
		str(run_state.narrative_flags.get("demo_finale_event_id", "")),
		str(active_run.narrative_flags.get("grand_casino_showdown_step", "")),
		showdown_win_status,
		showdown_failure_reason,
		int(item_check.get("success_chance", 0)),
		int(clean_check.get("success_chance", 0)),
		int(dirty_check.get("success_chance", 0)),
	])
	print("HIGH_ROLLER_CASHOUT route=%s cheated_pending=%s hot_pending=%s max_heat=%d event_visible=%s" % [
		str(loaded_clean.narrative_flags.get("demo_victory_route", "")),
		str(cheated_cashout_status.get("showdown_pending", false)),
		str(hot_cashout_status.get("showdown_pending", false)),
		int(hot_cashout_status.get("grand_casino_max_heat", 0)),
		str(_string_array(clean_run.current_environment.get("event_ids", [])).has("high_roller_cashout")),
	])
	print("GRAND_CASINO_ENDGAME_MATRIX high_roller_loaded=%s showdown_loaded=%s taken_out_back_loaded=%s pending_loaded=%s clean_ready_loaded=%s" % [
		high_roller_victory_round_trip_status,
		showdown_win_status,
		showdown_failure_reason,
		str(loaded_showdown.run_status),
		str(loaded_clean_status.get("high_roller_ready", false)),
	])


func _check_grand_casino_players_card_tiers(library: ContentLibrary, main_archetype: Dictionary, failures: Array) -> void:
	var objective: Dictionary = main_archetype.get("demo_objective", {}) if typeof(main_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var bronze_games := int(objective.get("players_card_bronze_min_games", 0))
	var bronze_net := int(objective.get("players_card_bronze_net_winnings", 0))
	var silver_games := int(objective.get("players_card_silver_min_games", 0))
	var silver_net := int(objective.get("players_card_silver_net_winnings", 0))
	var gold_games := int(objective.get("players_card_gold_min_games", 0))
	var gold_net := int(objective.get("players_card_gold_net_winnings", 0))
	if bronze_games <= 0 or bronze_net <= 0 or silver_games <= bronze_games or silver_net <= bronze_net or gold_games <= silver_games or gold_net <= silver_net:
		failures.append("Players Card Bronze, Silver, and Gold thresholds must rise in data-authored order.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("GC-PLAYERS-CARD-TIERS")
	var environment := EnvironmentInstance.from_archetype(main_archetype, 3, run_state.create_rng("gc_card_tiers_environment"), library)
	run_state.set_environment(environment.to_dict())
	_record_players_card_clean_games(run_state, bronze_games)
	var entry_bankroll := int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.grand_casino_total_money()))
	run_state.bankroll = maxi(0, entry_bankroll + bronze_net - run_state.grand_casino_chips)
	run_state.evaluate_environment_objective_state()
	var bronze_status := run_state.demo_objective_status()
	if str(bronze_status.get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE:
		failures.append("Scripted clean play did not cross the Bronze Players Card threshold.")
	if run_state.grand_casino_chips != int(objective.get("players_card_bronze_chip_bonus", 0)) or int(run_state.narrative_flags.get("grand_casino_comp_drink_tokens", 0)) != int(objective.get("players_card_bronze_drink_comps", 0)):
		failures.append("Bronze did not grant its data-tuned chip and drink comps.")
	if str(run_state.next_pending_talk_event().get("dialogue_id", "")) != "linda_bronze_tier":
		failures.append("Bronze tier-up did not enqueue Linda's talk-dock scene.")
	_record_players_card_clean_games(run_state, silver_games)
	entry_bankroll = int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.grand_casino_total_money()))
	run_state.bankroll = maxi(0, entry_bankroll + silver_net - run_state.grand_casino_chips)
	run_state.evaluate_environment_objective_state()
	var silver_status := run_state.demo_objective_status()
	if str(silver_status.get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER:
		failures.append("Scripted clean play did not cross the Silver Players Card threshold.")
	var silver_access := run_state.grand_casino_room_access_status(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60)
	if not bool(silver_access.get("available", false)) or str(silver_access.get("access_method", "")) != "silver_card" or int(silver_access.get("cost", -1)) != 0:
		failures.append("Silver Players Card did not open the High-Limit Room without a cash buy-in.")
	if not bool(run_state.narrative_flags.get("grand_casino_linda_look_away_available", false)) or int(run_state.narrative_flags.get("grand_casino_comp_suite_rests", 0)) != int(objective.get("players_card_silver_suite_rests", 0)):
		failures.append("Silver did not grant Linda's look-away and suite-rest benefits.")
	var expected_net_before_comps := int(silver_status.get("grand_casino_net_winnings", -1))
	if expected_net_before_comps != silver_net:
		failures.append("Tier chip comps incorrectly changed canonical Grand Casino net winnings.")
	var silver_payload := run_state.to_dict()
	var loaded_silver: RunState = RunStateScript.new()
	loaded_silver.from_dict(silver_payload)
	if str(loaded_silver.demo_objective_status().get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER or not bool(loaded_silver.narrative_flags.get("grand_casino_high_limit_access", false)):
		failures.append("Silver tier and benefits did not survive save/load.")
	var legacy_payload := silver_payload.duplicate(true)
	var legacy_flags: Dictionary = legacy_payload.get("narrative_flags", {}).duplicate(true)
	var awarded_chip_comps := int(objective.get("players_card_bronze_chip_bonus", 0)) + int(objective.get("players_card_silver_chip_bonus", 0))
	legacy_payload["grand_casino_chips"] = maxi(0, int(legacy_payload.get("grand_casino_chips", 0)) - awarded_chip_comps)
	legacy_flags["grand_casino_entry_bankroll"] = maxi(0, int(legacy_flags.get("grand_casino_entry_bankroll", 0)) - awarded_chip_comps)
	for key in legacy_flags.keys().duplicate():
		var key_text := str(key)
		if key_text.begins_with("grand_casino_players_card_") or key_text.begins_with("grand_casino_comp_") or key_text.begins_with("grand_casino_linda_look_away"):
			legacy_flags.erase(key)
	legacy_flags.erase("grand_casino_high_limit_access")
	legacy_flags.erase("grand_casino_high_limit_access_method")
	legacy_payload["narrative_flags"] = legacy_flags
	var legacy_run: RunState = RunStateScript.new()
	legacy_run.from_dict(legacy_payload)
	if str(legacy_run.demo_objective_status().get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER or not bool(legacy_run.narrative_flags.get("grand_casino_high_limit_access", false)):
		failures.append("Legacy Grand Casino save did not derive Silver tier and benefits from existing counters.")
	var look_away_max := int(objective.get("players_card_look_away_max_heat_gain", 0))
	var too_large := run_state.add_suspicion("linda_large_heat", look_away_max + 1, "behavior", false, {"action_kind": "risky"})
	if too_large != look_away_max + 1 or not bool(run_state.narrative_flags.get("grand_casino_linda_look_away_available", false)):
		failures.append("Linda consumed the look-away on heat above its data threshold.")
	run_state.add_suspicion("linda_large_heat_reset", -(look_away_max + 1), "recovery")
	var cheat_heat := run_state.add_suspicion("linda_cheat_heat", look_away_max, "behavior", false, {"action_kind": "cheat"})
	if cheat_heat != look_away_max or not bool(run_state.narrative_flags.get("grand_casino_linda_look_away_available", false)):
		failures.append("Linda consumed the clean-path look-away on a cheat action.")
	run_state.add_suspicion("linda_cheat_heat_reset", -look_away_max, "recovery")
	var forgiven := run_state.add_suspicion("linda_small_heat", look_away_max, "behavior", false, {"action_kind": "risky"})
	var second_gain := run_state.add_suspicion("linda_second_heat", look_away_max, "behavior", false, {"action_kind": "risky"})
	if forgiven != 0 or second_gain != look_away_max or not bool(run_state.narrative_flags.get("grand_casino_linda_look_away_consumed", false)):
		failures.append("Linda's Silver look-away did not forgive exactly one eligible small heat gain.")
	var look_away_story := false
	for story_value in run_state.story_log:
		if typeof(story_value) == TYPE_DICTIONARY and str((story_value as Dictionary).get("type", "")) == "grand_casino_linda_look_away":
			look_away_story = true
			break
	if not look_away_story:
		failures.append("Linda's consumed look-away did not log its story line.")
	var drink_before := int(run_state.narrative_flags.get("grand_casino_comp_drink_tokens", 0))
	var drink_result := run_state.grand_casino_players_card_comp_result("drink")
	GameModule.apply_result(run_state, drink_result)
	if not bool(drink_result.get("ok", false)) or int(run_state.narrative_flags.get("grand_casino_comp_drink_tokens", 0)) != drink_before - 1:
		failures.append("Players Card drink comp did not resolve through shared service deltas.")
	run_state.change_drunk(50)
	var heat_before_rest := run_state.suspicion_level()
	var drunk_before_rest := run_state.drunk_level
	var rest_result := run_state.grand_casino_players_card_comp_result("suite_rest")
	GameModule.apply_result(run_state, rest_result)
	run_state.advance_game_clock_minutes(int(rest_result.get("duration_minutes", 0)))
	if not bool(rest_result.get("ok", false)) or run_state.suspicion_level() >= heat_before_rest or run_state.drunk_level >= drunk_before_rest or int(rest_result.get("duration_minutes", 0)) != int(objective.get("players_card_suite_rest_minutes", 0)):
		failures.append("Players Card suite rest did not reuse service deltas for time, heat, and drunk recovery.")
	_record_players_card_clean_games(run_state, gold_games)
	entry_bankroll = int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.grand_casino_total_money()))
	run_state.bankroll = maxi(0, entry_bankroll + gold_net - run_state.grand_casino_chips)
	run_state.evaluate_environment_objective_state()
	var gold_status := run_state.demo_objective_status()
	if str(gold_status.get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD or not bool(gold_status.get("high_roller_ready", false)):
		failures.append("Scripted clean play did not cross Gold into deliberate Cage review readiness.")
	var gold_result := run_state.apply_demo_finale_result({
		"event_id": RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
		"branch": "win_clean",
		"message": "Linda issues the Gold Players Card and lets you leave with your winnings.",
	})
	if not bool(gold_result.get("complete", false)) or run_state.run_status != RunState.RUN_STATUS_ENDED or str(run_state.narrative_flags.get("demo_victory_route", "")) != RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID or not bool(run_state.narrative_flags.get("act_two_seam_ready", false)):
		failures.append("Linda's Gold review did not complete the canonical clean victory end-to-end.")
	var evidence_run: RunState = RunStateScript.new()
	evidence_run.start_new("GC-PLAYERS-CARD-EVIDENCE")
	evidence_run.set_environment(environment.to_dict())
	_record_players_card_clean_games(evidence_run, silver_games)
	entry_bankroll = int(evidence_run.narrative_flags.get("grand_casino_entry_bankroll", evidence_run.grand_casino_total_money()))
	evidence_run.bankroll = maxi(0, entry_bankroll + silver_net - evidence_run.grand_casino_chips)
	evidence_run.evaluate_environment_objective_state()
	evidence_run.narrative_flags["grand_casino_cheat_evidence"] = true
	evidence_run.evaluate_environment_objective_state()
	var evidence_status := evidence_run.demo_objective_status()
	var evidence_cage := CageWindowViewModelScript.build(evidence_run)
	var evidence_card: Dictionary = evidence_cage.get("card", {}) if typeof(evidence_cage.get("card", {})) == TYPE_DICTIONARY else {}
	if bool(evidence_status.get("players_card_eligible", true)) or str(evidence_card.get("review_state", "")) != "ineligible" or str(evidence_card.get("review_detail", "")).find("permanently") == -1:
		failures.append("Cheat evidence did not permanently lock every Players Card tier in the Cage window.")
	var evidence_access := evidence_run.grand_casino_room_access_status(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60)
	if not bool(evidence_access.get("cash_buy_in_required", false)) or str(evidence_access.get("access_method", "")) != "cash_buy_in":
		failures.append("Cheat evidence did not revoke Silver access while preserving the independent cash buy-in path.")
	for dialogue_id in ["linda_bronze_tier", "linda_silver_tier", "linda_gold_review", "linda_main_floor_ambient_1", "linda_main_floor_ambient_2", "linda_main_floor_ambient_3"]:
		var dialogue := library.dialogue(dialogue_id)
		var speaker: Dictionary = dialogue.get("speaker", {}) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
		if dialogue.is_empty() or str(speaker.get("name", "")) != "Linda":
			failures.append("Linda dialogue scene is missing or misattributed: %s." % dialogue_id)
	print("GRAND_CASINO_CARD_TIERS bronze=%d/%d silver=%d/%d gold=%d/%d look_away=%d dialogues=6" % [bronze_games, bronze_net, silver_games, silver_net, gold_games, gold_net, look_away_max])


func _record_players_card_clean_games(run_state: RunState, target_games: int) -> void:
	var current_games := maxi(0, int(run_state.narrative_flags.get("grand_casino_games_played", 0)))
	for game_index in range(current_games, maxi(current_games, target_games)):
		var deltas := GameModule.empty_result_deltas()
		deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 5 + game_index}]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "card_tier_clean_progress",
			"action_kind": "legal",
			"stake": 5 + game_index,
			"deltas": deltas,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
			"message": "Clean Players Card progress.",
		})
		run_state.record_grand_casino_game_result(result)


func _check_grand_casino_chips_and_cage(library: ContentLibrary, main_archetype: Dictionary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("GC-CHIPS-CAGE")
	var environment := EnvironmentInstance.from_archetype(main_archetype, 3, run_state.create_rng("gc_chips_environment"), library)
	run_state.set_environment(environment.to_dict())
	run_state.bankroll = 100
	var score_before := run_state.run_spending_score
	var buy_result := run_state.buy_grand_casino_chips(40, run_state.grand_casino_chip_exchange_rate())
	if not bool(buy_result.get("ok", false)) or run_state.bankroll != 60 or run_state.grand_casino_chips != 40 or run_state.grand_casino_total_money() != 100:
		failures.append("Grand Casino 1:1 table buy-in did not conserve cash plus chips.")
	if run_state.wager_balance_for_game("blackjack", run_state.current_environment) != 40 or run_state.wager_capacity_for_game("blackjack", run_state.current_environment) != 100:
		failures.append("Grand Casino table balance did not keep actual chips separate from explicitly convertible cash capacity.")
	if run_state.run_spending_score != score_before:
		failures.append("Grand Casino chip buy-in incorrectly counted a currency transfer as score spending.")

	for table_id in RunState.GRAND_CASINO_TABLE_GAME_IDS:
		var table_deltas := GameModule.empty_result_deltas()
		table_deltas["bankroll_delta"] = -2
		var table_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": table_id,
			"game_id": table_id,
			"action_id": "chips_fixture",
			"action_kind": "legal",
			"stake": 2,
			"deltas": table_deltas,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"message": "Casino table chips fixture.",
		})
		var cash_before := run_state.bankroll
		var chips_before := run_state.grand_casino_chips
		GameModule.apply_result(run_state, table_result)
		if run_state.bankroll != cash_before or run_state.grand_casino_chips != chips_before - 2 or int(table_result.get("chips_delta", 0)) != -2 or str(table_result.get("currency", "")) != "chips":
			failures.append("Grand Casino table result did not route %s from bankroll_delta to chips." % table_id)

	var machine_deltas := GameModule.empty_result_deltas()
	machine_deltas["bankroll_delta"] = 7
	var machine_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "slot",
		"game_id": "slot",
		"action_id": "spin",
		"action_kind": "legal",
		"stake": 1,
		"deltas": machine_deltas,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": "Casino machine cash fixture.",
	})
	var machine_cash_before := run_state.bankroll
	var machine_chips_before := run_state.grand_casino_chips
	GameModule.apply_result(run_state, machine_result)
	if run_state.bankroll != machine_cash_before + 7 or run_state.grand_casino_chips != machine_chips_before or machine_result.has("chips_delta"):
		failures.append("Grand Casino machine result did not remain cash-only.")

	var outside_environment := run_state.current_environment.duplicate(true)
	outside_environment["id"] = "outside_table_currency_fixture"
	outside_environment["archetype_id"] = "gas_station_casino"
	outside_environment["world_node_id"] = "gas_station_casino"
	run_state.set_environment(outside_environment)
	var outside_deltas := GameModule.empty_result_deltas()
	outside_deltas["bankroll_delta"] = -3
	var outside_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "outside_cash_fixture",
		"action_kind": "legal",
		"stake": 3,
		"deltas": outside_deltas,
		"environment_id": "outside_table_currency_fixture",
		"message": "Outside table cash fixture.",
	})
	var outside_cash_before := run_state.bankroll
	var outside_chips_before := run_state.grand_casino_chips
	GameModule.apply_result(run_state, outside_result)
	if run_state.bankroll != outside_cash_before - 3 or run_state.grand_casino_chips != outside_chips_before or outside_result.has("chips_delta"):
		failures.append("Blackjack outside the Grand Casino did not remain cash-only.")

	run_state.set_environment(environment.to_dict())
	var saved := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved)
	if restored.grand_casino_chips != run_state.grand_casino_chips or str(restored.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_ARCHETYPE_ID:
		failures.append("Grand Casino chip balance or Cage availability did not survive save/load.")
	var total_before_cash_out := restored.grand_casino_total_money()
	var score_before_cash_out := restored.run_spending_score
	var cash_out_result := restored.cash_out_grand_casino_chips(-1, restored.grand_casino_chip_exchange_rate())
	if not bool(cash_out_result.get("ok", false)) or restored.grand_casino_chips != 0 or restored.grand_casino_total_money() != total_before_cash_out:
		failures.append("Grand Casino cash-out did not conserve total money.")
	if restored.run_spending_score != score_before_cash_out:
		failures.append("Grand Casino chip cash-out incorrectly changed score spending.")


func _check_grand_casino_spatial_split(library: ContentLibrary, main_archetype: Dictionary, failures: Array) -> void:
	var high_limit := _archetype_by_id(library, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)
	var back_room := _archetype_by_id(library, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID)
	if high_limit.is_empty() or back_room.is_empty():
		failures.append("Grand Casino spatial split is missing the High-Limit or Back Room archetype.")
		return
	if not bool(high_limit.get("map_hidden", false)) or not bool(back_room.get("map_hidden", false)):
		failures.append("Grand Casino subrooms must be hidden from world-map node generation.")
	var main_games := _string_array(main_archetype.get("game_pool", []))
	var high_games := _string_array(high_limit.get("game_pool", []))
	for machine_id in ["slot", "video_poker", "pull_tabs", "bar_dice"]:
		if not main_games.has(machine_id):
			failures.append("Grand Casino Main Floor is missing required machine/bar game: %s." % machine_id)
	for table_id in ["blackjack", "baccarat", "roulette"]:
		if main_games.has(table_id) or not high_games.has(table_id):
			failures.append("Grand Casino table placement did not isolate %s to the High-Limit Room." % table_id)
	if high_games.has("video_poker"):
		failures.append("Grand Casino High-Limit Room incorrectly includes video poker.")
	if int(_copy_dict(high_limit.get("economic_profile", {})).get("stake_floor", 0)) <= int(_copy_dict(main_archetype.get("economic_profile", {})).get("stake_floor", 0)):
		failures.append("Grand Casino High-Limit Room stake floor is not higher than the Main Floor.")

	for seed_index in range(12):
		var map_run: RunState = RunStateScript.new()
		map_run.start_new("GC-SPATIAL-MAP-%02d" % seed_index)
		var map_data := WorldMapScript.new(library).build(map_run, map_run.create_rng("gc_spatial_map"))
		var grand_node_count := 0
		for node_value in _copy_array(map_data.get("nodes", [])):
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node_id := str((node_value as Dictionary).get("id", ""))
			if node_id.begins_with("grand_casino"):
				grand_node_count += 1
		if grand_node_count != 1 or not WorldMapScript.node_by_id(map_data, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID).is_empty() or not WorldMapScript.node_by_id(map_data, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID).is_empty():
			failures.append("World map seed %d did not contain exactly one Grand Casino node." % seed_index)
			break

	var run_state := _grand_casino_spatial_fixture_run(library, "GC-SPATIAL-SHARED", failures)
	if run_state == null:
		return
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var layout := _copy_dict(run_state.current_environment.get("layout", {}))
	var object_rects := _copy_dict(layout.get("object_rects", {}))
	for object_id in ["casino_fixture:cage", "casino_fixture:host_desk", "travel:grand_casino_high_limit", "travel:grand_casino_back_room"]:
		if not object_rects.has(object_id):
			failures.append("Grand Casino Main Floor layout is missing authored object placement: %s." % object_id)
	var buy_in := int(_copy_dict(run_state.current_environment.get("local_narrative_flags", {})).get("casino_high_limit_buy_in", 60))
	run_state.bankroll = maxi(0, buy_in - 1)
	if bool(run_state.grand_casino_room_access_status(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, buy_in).get("available", true)):
		failures.append("Grand Casino High-Limit door admitted a player without card access or enough cash.")
	run_state.bankroll = buy_in + 40
	var cash_access := run_state.grand_casino_room_access_status(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, buy_in)
	if not bool(cash_access.get("available", false)) or int(cash_access.get("cost", 0)) != buy_in:
		failures.append("Grand Casino High-Limit cash buy-in gate did not admit and price an eligible player.")
	if bool(run_state.grand_casino_room_access_status(RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, buy_in).get("available", true)) or generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID):
		failures.append("Grand Casino Back Room was reachable without the showdown.")

	run_state.add_suspicion("gc_room_shared_heat", 23, "behavior")
	run_state.narrative_flags["grand_casino_attention_eye_in_the_sky"] = true
	run_state.narrative_flags["grand_casino_cheat_evidence"] = true
	run_state.record_grand_casino_game_result({"ok": true, "game_id": "slot", "action_kind": "legal", "stake": 5})
	var entry_bankroll := int(run_state.narrative_flags.get("grand_casino_entry_bankroll", -1))
	run_state.narrative_flags["grand_casino_high_limit_access"] = true
	run_state.narrative_flags["grand_casino_high_limit_access_method"] = "fixture_card"
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID):
		failures.append("Grand Casino room seam could not enter the High-Limit Room with access.")
		return
	if run_state.current_world_node_id() != RunState.GRAND_CASINO_ARCHETYPE_ID or str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
		failures.append("Grand Casino local room move changed the world node or missed the High-Limit archetype.")
	if run_state.suspicion_level() != 23 or not bool(run_state.narrative_flags.get("grand_casino_attention_eye_in_the_sky", false)) or not bool(run_state.narrative_flags.get("grand_casino_cheat_evidence", false)):
		failures.append("Grand Casino room move did not preserve shared heat, attention, and evidence.")
	if int(run_state.narrative_flags.get("grand_casino_games_played", 0)) != 1 or int(run_state.narrative_flags.get("grand_casino_entry_bankroll", -2)) != entry_bankroll:
		failures.append("Grand Casino room move reset shared objective counters or entry bankroll.")
	run_state.store_current_world_node_environment()
	var stored_main := _copy_dict(WorldMapScript.node_by_id(run_state.world_map, RunState.GRAND_CASINO_ARCHETYPE_ID).get("environment", {}))
	if str(stored_main.get("archetype_id", "")) != RunState.GRAND_CASINO_ARCHETYPE_ID:
		failures.append("Grand Casino world node stored a subroom instead of the Main Floor snapshot.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if str(restored.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID or restored.grand_casino_room_environment(RunState.GRAND_CASINO_ARCHETYPE_ID).is_empty() or restored.suspicion_level() != 23:
		failures.append("Grand Casino room cache, position, or shared heat did not survive save/load.")
	if not generator.enter_grand_casino_room(restored, RunState.GRAND_CASINO_ARCHETYPE_ID):
		failures.append("Grand Casino room seam could not return from High-Limit to Main Floor.")

	var clean_run := _grand_casino_spatial_fixture_run(library, "GC-SPATIAL-CLEAN", failures)
	if clean_run == null:
		return
	var clean_generator: RunGenerator = RunGeneratorScript.new(library)
	clean_run.record_grand_casino_game_result({"ok": true, "game_id": "slot", "action_kind": "legal", "stake": 5})
	clean_run.narrative_flags["grand_casino_high_limit_access"] = true
	if not clean_generator.enter_grand_casino_room(clean_run, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID):
		failures.append("Grand Casino split clean-route fixture could not enter High-Limit.")
		return
	var objective := _copy_dict(clean_run.current_environment.get("demo_objective", {}))
	var min_games := maxi(1, int(objective.get("high_roller_min_grand_casino_games", 5)))
	for game_index in range(1, min_games):
		clean_run.record_grand_casino_game_result({"ok": true, "game_id": "blackjack", "action_kind": "legal", "stake": 25})
	clean_run.bankroll = int(clean_run.narrative_flags.get("grand_casino_entry_bankroll", clean_run.bankroll)) + maxi(1, int(objective.get("high_roller_net_winnings", 30)))
	var split_status := clean_run.evaluate_environment_objective_state()
	if not bool(split_status.get("high_roller_ready", false)) or int(split_status.get("grand_casino_games_played", 0)) != min_games:
		failures.append("Grand Casino clean route did not complete its ready transition with play split across rooms.")


func _grand_casino_spatial_fixture_run(library: ContentLibrary, seed_text: String, failures: Array) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	var map_data := WorldMapScript.new(library).build(run_state, run_state.create_rng("gc_spatial_fixture_map"))
	run_state.set_world_map(map_data)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var generated := generator.next_environment(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID, true)
	if generated == null or str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_ARCHETYPE_ID:
		failures.append("Grand Casino spatial fixture could not generate the Main Floor under the world node.")
		return null
	return run_state


# Checks bankrupt failure, supported lender recovery, save/load, and victory/failure separation.
func _check_recovery_loss_pressure_foundation(library: ContentLibrary, failures: Array) -> void:
	var failed_run: RunState = RunStateScript.new()
	failed_run.start_new("M2-FUN-LOSS")
	failed_run.change_bankroll(-failed_run.bankroll)
	if failed_run.bankroll != 0:
		failures.append("Loss pressure fixture did not reach zero bankroll.")
	if failed_run.run_status != RunState.RUN_STATUS_FAILED:
		failures.append("Zero bankroll without recovery did not mark the run failed.")
	if failed_run.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO:
		failures.append("Zero bankroll failure did not record a bankroll-zero reason.")
	if failed_run.economy() != "insolvent":
		failures.append("Zero bankroll without recovery did not mark the economy insolvent.")
	var failed_pressure := failed_run.recovery_pressure_status(false)
	if not bool(failed_pressure.get("failed", false)):
		failures.append("Recovery pressure status did not expose a clear failed state.")
	if str(failed_pressure.get("summary", "")).find("out of money") == -1:
		failures.append("Failed pressure summary is not player-facing enough.")
	var failed_save_service: SaveService = SaveServiceScript.new()
	var failed_slot := "foundation_check_loss_pressure"
	var failed_save_error: Error = failed_save_service.save_run(failed_run, failed_slot)
	if failed_save_error != OK:
		failures.append("Save service could not save failed run state: %s." % failed_save_error)
	else:
		var loaded_failed = failed_save_service.load_run(failed_slot)
		if loaded_failed == null:
			failures.append("Save service could not reload failed run state.")
		elif loaded_failed.run_status != RunState.RUN_STATUS_FAILED or loaded_failed.economy() != "insolvent":
			failures.append("Failed run status/economy did not survive SaveService load.")
		elif loaded_failed.run_failure_reason != failed_run.run_failure_reason:
			failures.append("Failed run reason did not survive SaveService load.")

	var lender := library.lender("street_lender")
	if lender.is_empty():
		failures.append("Recovery pressure needs supported lender fixture: street_lender.")
		return
	var recovery_run: RunState = RunStateScript.new()
	recovery_run.start_new("M2-FUN-RECOVERY")
	recovery_run.set_environment({
		"id": "back_alley_recovery_fixture",
		"archetype_id": "back_alley",
		"kind": "shop",
		"lender_hooks": ["street_lender"],
	})
	recovery_run.change_bankroll(-(recovery_run.bankroll - 1))
	var recovery_status := RunTerminalEvaluatorScript.evaluate(recovery_run, library)
	if bool(recovery_status.get("failed", false)) or not bool(recovery_status.get("lender_available", false)):
		failures.append("Low-bankroll lender recovery was not recognized before zero cash.")
	var lender_result := _fixture_lender_result(recovery_run, lender, "street_lender")
	GameModule.apply_result(recovery_run, lender_result)
	if recovery_run.bankroll <= 0:
		failures.append("Supported lender recovery did not restore positive bankroll.")
	if recovery_run.debt.is_empty():
		failures.append("Supported lender recovery did not create debt pressure.")
	if recovery_run.run_status == RunState.RUN_STATUS_FAILED:
		failures.append("Supported lender recovery left the run in failed status.")
	var post_recovery_pressure := recovery_run.recovery_pressure_status(false)
	if bool(post_recovery_pressure.get("failed", false)):
		failures.append("Post-lender recovery still reports a failed pressure state.")
	var recovery_save_service: SaveService = SaveServiceScript.new()
	var recovery_slot := "foundation_check_recovery_pressure"
	var recovery_save_error: Error = recovery_save_service.save_run(recovery_run, recovery_slot)
	if recovery_save_error != OK:
		failures.append("Save service could not save recovery run state: %s." % recovery_save_error)
	else:
		var loaded_recovery = recovery_save_service.load_run(recovery_slot)
		if loaded_recovery == null:
			failures.append("Save service could not reload recovery run state.")
		elif loaded_recovery.bankroll != recovery_run.bankroll or loaded_recovery.debt.size() != recovery_run.debt.size() or loaded_recovery.run_status != recovery_run.run_status:
			failures.append("Recovery run pressure did not survive SaveService load.")

	var victory_run: RunState = RunStateScript.new()
	victory_run.start_new("M2-FUN-VICTORY-NOT-FAILURE")
	victory_run.change_bankroll(-(victory_run.bankroll - 1))
	var victory_deltas := GameModule.empty_result_deltas()
	victory_deltas["flags_set"] = {"demo_victory": true}
	victory_deltas["ended"] = true
	victory_deltas["messages"] = ["Demo Victory: you beat the house for now."]
	GameModule.apply_result(victory_run, GameModule.build_action_result({
		"ok": true,
		"type": "event",
		"source_id": "fixture_victory",
		"action_id": "demo_victory",
		"deltas": victory_deltas,
		"message": "Demo Victory: you beat the house for now.",
	}))
	var victory_pressure := victory_run.recovery_pressure_status(false)
	if victory_run.run_status != GameModule.RESULT_ENDED:
		failures.append("Victory result did not preserve ended run status after zero-bankroll pressure.")
	if bool(victory_pressure.get("failed", true)) or str(victory_pressure.get("state", "")) != "victory":
		failures.append("Victory state conflicted with failure pressure.")

	var stranded_run: RunState = RunStateScript.new()
	stranded_run.start_new("M2-FUN-STRANDED")
	stranded_run.set_environment({
		"id": "stranded_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 5},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"lender_hooks": [],
	})
	stranded_run.change_bankroll(-(stranded_run.bankroll - 1))
	var stranded_status := RunTerminalEvaluatorScript.evaluate_and_apply(stranded_run, library)
	if not bool(stranded_status.get("failed", false)) or stranded_run.run_failure_reason != RunState.FAILURE_STRANDED:
		failures.append("No-wager/no-recovery state did not fail as stranded.")

	var travel_escape_run: RunState = RunStateScript.new()
	travel_escape_run.start_new("M2-FUN-TRAVEL-ESCAPE")
	travel_escape_run.set_environment({
		"id": "travel_escape_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 5},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": ["corner_store"],
		"next_archetypes": [],
		"lender_hooks": [],
	})
	travel_escape_run.change_bankroll(-(travel_escape_run.bankroll - 2))
	var travel_escape_status := RunTerminalEvaluatorScript.evaluate_and_apply(travel_escape_run, library)
	if bool(travel_escape_status.get("failed", false)) or not bool(travel_escape_status.get("travel_available", false)):
		failures.append("Affordable travel was not preserved as a low-bankroll recovery path.")
	_check_broke_pull_tab_deferred_terminal_boundary(library, failures)
	_check_broke_idle_terminal_evaluator_not_per_frame(library, failures)


func _check_broke_pull_tab_deferred_terminal_boundary(library: ContentLibrary, failures: Array) -> void:
	var pull_tabs: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs == null:
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BROKE-PULL-TAB-DEFERRED")
	var environment := {
		"id": "broke_pull_tab_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 1},
		"game_ids": ["pull_tabs"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"lender_hooks": [],
		"game_states": {},
	}
	var machine := pull_tabs.generate_environment_state(run_state, environment, run_state.create_rng("broke_pull_tabs"))
	machine["tray_stack"] = [{"symbols": ["A", "B", "C"], "payout": 0}]
	environment["game_states"] = {"pull_tabs": machine}
	run_state.set_environment(environment)
	run_state.change_bankroll(-run_state.bankroll, true)
	var deferred_status := RunTerminalEvaluatorScript.evaluate(run_state, library)
	if bool(deferred_status.get("failed", false)) or not bool(deferred_status.get("bankroll_zero_deferred", false)):
		failures.append("Unresolved pull-tab ticket did not preserve zero-bankroll deferred recovery.")
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var stored_machine: Dictionary = states.get("pull_tabs", {}) if typeof(states.get("pull_tabs", {})) == TYPE_DICTIONARY else {}
	stored_machine["tray_stack"] = []
	stored_machine["ticket_stack"] = []
	stored_machine["winner_pile"] = []
	states["pull_tabs"] = stored_machine
	run_state.current_environment["game_states"] = states
	var failed_status := RunTerminalEvaluatorScript.evaluate_and_apply(run_state, library)
	if not bool(failed_status.get("failed", false)) or run_state.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO:
		failures.append("Clearing zero-bankroll pull-tab recovery did not fail at the action boundary with bankroll-zero reason.")


func _check_broke_idle_terminal_evaluator_not_per_frame(library: ContentLibrary, failures: Array) -> void:
	var pull_tabs: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs == null:
		return
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Broke-idle terminal evaluator fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Broke-idle terminal evaluator fixture requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BROKE-IDLE-NO-POLL")
	var environment := {
		"id": "broke_idle_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 1},
		"game_ids": ["pull_tabs"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"lender_hooks": [],
		"game_states": {},
	}
	var machine := pull_tabs.generate_environment_state(run_state, environment, run_state.create_rng("broke_idle_pull_tabs"))
	machine["tray_stack"] = [{"symbols": ["A", "B", "C"], "payout": 0}]
	environment["game_states"] = {"pull_tabs": machine}
	run_state.set_environment(environment)
	run_state.change_bankroll(-run_state.bankroll, true)
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		failures.append("Broke-idle deferred fixture failed before idle frame sampling.")
		_sb4_dispose_app(app)
		return
	app.set("terminal_evaluator_call_count", 0)
	for _frame_index in range(12):
		app.call("_process", 1.0 / 60.0)
	var call_count := int(app.get("terminal_evaluator_call_count"))
	if call_count != 0:
		failures.append("Broke-idle frames invoked the terminal evaluator %d time(s); expected action-boundary only." % call_count)
	_sb4_dispose_app(app)


func _save_service_expected_snapshot(run_state: RunState) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(run_state.to_dict()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return run_state.to_dict()
	var normalized: RunState = RunStateScript.new()
	normalized.from_dict(parsed as Dictionary)
	return normalized.to_dict()


func _fixture_system_pressure_result(environment: Dictionary, bankroll_delta: int, message: String) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["story_log"] = [{
		"type": "economy_pressure",
		"id": "m2_system_scenario",
		"bankroll_delta": bankroll_delta,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	}]
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "economy_pressure",
		"source_id": "m2_system_scenario",
		"action_id": "cash_pressure",
		"action_kind": "economy",
		"environment_id": str(environment.get("id", "")),
		"bankroll_delta": bankroll_delta,
		"deltas": deltas,
		"message": message,
	})


func _string_array_from_variant(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _unique_strings(first: Array, second: Array) -> Array:
	var result: Array = []
	for source in [first, second]:
		for id in _string_array_from_variant(source):
			if not result.has(id):
				result.append(id)
	return result


# Resolves one foundation game action before saving, if generated content allows it.
func _resolve_first_save_test_action(library: ContentLibrary, run_state: RunState, environment: EnvironmentInstance, failures: Array) -> void:
	if environment.game_ids.is_empty():
		failures.append("SaveService round trip needs a generated game option.")
		return
	var game_id := str(environment.game_ids[0])
	var definition := library.game(game_id)
	if definition.is_empty():
		failures.append("SaveService round trip generated unknown game: %s." % game_id)
		return
	var module_path := str(definition.get("module_path", ""))
	if module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		failures.append("SaveService round trip game module points at demo runtime/UI path: %s." % module_path)
		return
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("SaveService round trip could not load game module: %s." % module_path)
		return
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("SaveService round trip game module does not extend GameModule: %s." % module_path)
		return
	var game: GameModule = module_instance
	game.setup(definition, library)
	var legal_actions: Array = game.actions(run_state, environment.to_dict()).get("legal_actions", [])
	if legal_actions.is_empty():
		failures.append("SaveService round trip game did not expose a legal action.")
		return
	var result := game.resolve(str(legal_actions[0].get("id", "")), 1, run_state, environment.to_dict(), run_state.create_rng())
	_check_action_result_shape(result, "legal", failures)


# Checks the saved file is a foundation RunState payload, not profile/settings/demo data.
func _check_save_payload_file(save_path: String, failures: Array) -> void:
	var saved_text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(saved_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("SaveService wrote non-dictionary save data.")
		return
	var payload: Dictionary = parsed
	if payload.get("schema", "") != SaveService.SAVE_SCHEMA:
		failures.append("SaveService save payload is missing the foundation run schema.")
	if int(payload.get("version", 0)) != SaveService.SAVE_VERSION:
		failures.append("SaveService save payload version is not current.")
	if not payload.has("run_state"):
		failures.append("SaveService save payload is missing RunState data.")
	if payload.has("settings") or payload.has("profile") or payload.has("profile_inventory"):
		failures.append("SaveService mixed settings/profile persistence into run persistence.")
	var run_data: Variant = payload.get("run_state", {})
	if typeof(run_data) == TYPE_DICTIONARY:
		var run_dict: Dictionary = run_data
		if run_dict.has("profile_inventory"):
			failures.append("SaveService RunState payload included profile inventory.")


# Compares saved and loaded RunState domains.
func _check_run_state_save_round_trip(expected: Dictionary, actual: Dictionary, failures: Array) -> void:
	var keys := [
		"seed_text",
		"seed_value",
		"rng_seed",
		"rng_state",
		"challenge_config",
		"bankroll",
		"economic_state",
		"inventory",
		"debt",
		"suspicion",
		"current_environment",
		"pending_triggered_events",
		"active_triggered_event",
		"environment_history",
		"unlocked_travel",
		"narrative_flags",
		"story_flags",
		"story_log",
		"closing_time_state",
		"run_status",
		"run_spending_score",
	]
	for key in keys:
		if JSON.stringify(expected.get(key)) != JSON.stringify(actual.get(key)):
			failures.append("SaveService did not preserve RunState key: %s." % key)


# Checks the README one-structure EnvironmentInstance shape.
func _check_environment_instance_shape(environment: EnvironmentInstance, require_game: bool, failures: Array) -> void:
	if environment == null:
		failures.append("RunGenerator returned a null EnvironmentInstance.")
		return
	var data := environment.to_dict()
	if data.is_empty():
		failures.append("EnvironmentInstance did not produce saveable dictionary output.")
	if environment.id.is_empty():
		failures.append("EnvironmentInstance is missing generated id.")
	if environment.archetype_id.is_empty():
		failures.append("EnvironmentInstance is missing venue archetype identity.")
	if environment.display_name.is_empty():
		failures.append("EnvironmentInstance is missing display identity.")
	if environment.tier < 1:
		failures.append("EnvironmentInstance tier must be positive.")
	if environment.art_key.is_empty():
		failures.append("EnvironmentInstance is missing art reference key.")
	var layout: Variant = data.get("layout", {})
	if typeof(layout) != TYPE_DICTIONARY:
		failures.append("EnvironmentInstance layout should serialize generated object placement data.")
	else:
		var object_rects: Variant = (layout as Dictionary).get("object_rects", {})
		if typeof(object_rects) != TYPE_DICTIONARY:
			failures.append("EnvironmentInstance layout should include stable object_rects.")
		else:
			for event_id in environment.event_ids:
				if not (object_rects as Dictionary).has("event:%s" % str(event_id)):
					failures.append("EnvironmentInstance layout is missing event object placement.")
					break
			for offer in environment.item_offers:
				if typeof(offer) == TYPE_DICTIONARY and not (object_rects as Dictionary).has("item:%s" % str((offer as Dictionary).get("id", ""))):
					failures.append("EnvironmentInstance layout is missing item offer placement.")
					break
			if not _unique_strings(environment.next_archetypes, environment.travel_hooks).is_empty() and not (object_rects as Dictionary).has("travel:leave"):
				failures.append("EnvironmentInstance layout is missing the world-map Leave travel object placement.")
	if data.get("visual_context", {}).has("asset_path"):
		failures.append("EnvironmentInstance visual context should not serialize concrete PNG asset paths.")
	if data.get("visual_context", {}).has("scene_asset_path"):
		failures.append("EnvironmentInstance visual context should not serialize concrete scene asset paths.")
	if environment.security_profile.is_empty():
		failures.append("EnvironmentInstance is missing security profile.")
	if environment.economic_profile.is_empty():
		failures.append("EnvironmentInstance is missing economy pressure data.")
	if require_game and environment.game_ids.is_empty():
		failures.append("First foundation EnvironmentInstance should expose at least one game option.")
	if environment.kind != "home" and environment.event_ids.is_empty():
		failures.append("EnvironmentInstance should expose event hooks.")
	if environment.travel_hooks.is_empty() and environment.next_archetypes.is_empty():
		failures.append("EnvironmentInstance should expose travel hooks or next archetypes.")
	if typeof(data.get("item_offers", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance item opportunities should serialize as an array.")
	if typeof(data.get("service_ids", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance services should serialize as an array.")
	if typeof(data.get("lender_hooks", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance lender hooks should serialize as an array.")
	if typeof(data.get("suspicion_cues", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance suspicion cues should serialize as an array.")
	if typeof(data.get("local_narrative_flags", {})) != TYPE_DICTIONARY:
		failures.append("EnvironmentInstance local flags should serialize as a dictionary.")
	var restored := EnvironmentInstance.from_dict(data)
	if JSON.stringify(restored.to_dict()) != JSON.stringify(data):
		failures.append("EnvironmentInstance did not preserve saveable data through from_dict.")


# Checks that tests are exercising README pack paths through ContentLibrary.
func _check_canonical_pack_paths(failures: Array) -> void:
	var required_paths := ContentLibraryScript.required_pack_paths()
	for pack_name in required_paths.keys():
		var path := str(required_paths[pack_name])
		_check_foundation_pack_path(path, failures)
		if not FileAccess.file_exists(path):
			failures.append("Missing required foundation pack %s at %s." % [pack_name, path])

	var future_paths := ContentLibraryScript.future_pack_paths()
	for path in future_paths.values():
		_check_foundation_pack_path(str(path), failures)


# Ensures canonical foundation paths stay outside the demo runtime pack folder.
func _check_foundation_pack_path(path: String, failures: Array) -> void:
	if not path.begins_with("res://data/"):
		failures.append("Foundation pack path must live under res://data/: %s." % path)
	if path.begins_with("res://data/runtime/"):
		failures.append("Foundation pack path must not point at demo runtime data: %s." % path)


# Checks the canonical M2 packs without forcing unused future packs to exist.
func _check_m2_pack_availability(library: ContentLibrary, failures: Array) -> void:
	var future_paths := ContentLibraryScript.future_pack_paths()
	for pack_name in ["lenders", "services", "travel_routes"]:
		var path := str(future_paths.get(pack_name, ""))
		if path.is_empty():
			failures.append("ContentLibrary is missing M2 pack path: %s." % pack_name)
		elif not FileAccess.file_exists(path):
			failures.append("Missing M2 content pack %s at %s." % [pack_name, path])

	if library.lenders.is_empty():
		failures.append("M2 lender pack should load at least one lender definition.")
	if library.services.is_empty():
		failures.append("M2 service pack should load at least one service definition.")
	if library.travel_routes.is_empty():
		failures.append("M2 travel route pack should load at least one route definition.")

	for lender_hook in _all_environment_ids(library.environment_archetypes, "lender_hooks"):
		if library.lender(lender_hook).is_empty():
			failures.append("Environment lender hook is missing lender pack definition: %s." % lender_hook)

	for service_id in _all_environment_ids(library.environment_archetypes, "service_pool"):
		if library.service(service_id).is_empty():
			failures.append("Environment service hook is missing service pack definition: %s." % service_id)

	for travel_id in _all_environment_ids(library.environment_archetypes, "travel_hooks"):
		var route := library.route(travel_id)
		if route.is_empty():
			failures.append("Environment travel hook is missing route pack metadata: %s." % travel_id)
		elif str(route.get("destination_archetype", "")).is_empty():
			failures.append("Travel route is missing destination_archetype: %s." % travel_id)


func _check_tier_two_venue_progression(library: ContentLibrary, failures: Array) -> void:
	var kitty := _archetype_by_id(library, "kitty_cat_lounge")
	var delta := _archetype_by_id(library, "delta_queen")
	if kitty.is_empty():
		failures.append("T4.1 tier-2 venue kitty_cat_lounge is missing.")
	if delta.is_empty():
		failures.append("T4.1 tier-2 venue delta_queen is missing.")
	if kitty.is_empty() or delta.is_empty():
		return
	if int(kitty.get("tier", 0)) != 2 or str(kitty.get("kind", "")) != "casino":
		failures.append("Kitty Cat Lounge must be a tier-2 casino archetype.")
	if int(delta.get("tier", 0)) != 2 or str(delta.get("kind", "")) != "casino":
		failures.append("Delta Queen must be a tier-2 casino archetype.")
	if not _string_array(kitty.get("service_pool", [])).has("kitty_burlesque_show"):
		failures.append("Kitty Cat Lounge is missing its heat-management show service.")
	if not _string_array(kitty.get("game_pool", [])).has("roulette"):
		failures.append("Kitty Cat Lounge should reuse roulette as its house wheel.")
	for required_game in ["blackjack", "roulette", "video_poker"]:
		if not _string_array(delta.get("game_pool", [])).has(required_game):
			failures.append("Delta Queen is missing mid-stakes game %s." % required_game)
	if int(delta.get("travel_locked_actions", 0)) < 2:
		failures.append("Delta Queen must declare a travel_locked_actions ride duration.")
	var kitty_route := library.route("kitty_cat_lounge")
	var delta_route := library.route("delta_queen")
	if kitty_route.is_empty():
		failures.append("Travel route metadata for Kitty Cat Lounge is missing.")
	if delta_route.is_empty():
		failures.append("Travel route metadata for Delta Queen is missing.")
	elif typeof(delta_route.get("availability_window", {})) != TYPE_DICTIONARY or (delta_route.get("availability_window", {}) as Dictionary).is_empty():
		failures.append("Delta Queen route must define an availability_window schedule.")
	var tier_one_sources := ["bar", "gas_station_casino", "small_underground_casino"]
	var tier_one_to_tier_two := false
	for source_id in tier_one_sources:
		var source := _archetype_by_id(library, source_id)
		var targets := _unique_strings(_string_array(source.get("next_archetypes", [])), _string_array(source.get("travel_hooks", [])))
		if targets.has("kitty_cat_lounge") or targets.has("delta_queen"):
			tier_one_to_tier_two = true
	if not tier_one_to_tier_two:
		failures.append("No tier-1 casino routes into the tier-2 venues.")
	var kitty_targets := _unique_strings(_string_array(kitty.get("next_archetypes", [])), _string_array(kitty.get("travel_hooks", [])))
	var delta_targets := _unique_strings(_string_array(delta.get("next_archetypes", [])), _string_array(delta.get("travel_hooks", [])))
	if not kitty_targets.has("grand_casino") or not delta_targets.has("grand_casino"):
		failures.append("Tier-2 venues must route onward to the Grand Casino.")
	var underground := _archetype_by_id(library, "small_underground_casino")
	var underground_targets := _unique_strings(_string_array(underground.get("next_archetypes", [])), _string_array(underground.get("travel_hooks", [])))
	if not underground_targets.has("grand_casino"):
		failures.append("Small Underground Casino lost its direct Grand Casino shortcut.")
	_check_grand_casino_invite_gate(library, kitty, delta, failures)
	_check_tier_two_route_gates(library, delta, delta_route, failures)


func _check_tier_two_route_gates(library: ContentLibrary, delta: Dictionary, delta_route: Dictionary, failures: Array) -> void:
	if delta_route.is_empty():
		return
	var bar := _archetype_by_id(library, "bar")
	var route_run: RunState = RunStateScript.new()
	route_run.start_new("TIER2-ROUTE-GATE")
	route_run.bankroll = 500
	route_run.environment_history.append({"id": "corner_store_001", "archetype_id": "corner_store"})
	var bar_env := EnvironmentInstance.from_archetype(bar, 1, route_run.create_rng("bar_env"), library)
	route_run.set_environment(bar_env.to_dict())
	route_run.current_environment["turns"] = 2
	var closed_status := route_run.travel_route_status(delta_route)
	if bool(closed_status.get("available", true)):
		failures.append("Delta Queen route should close when the boarding window is away from the dock.")
	route_run.current_environment["turns"] = 4
	var open_status := route_run.travel_route_status(delta_route)
	if not bool(open_status.get("available", false)):
		failures.append("Delta Queen route should open on its scheduled boarding turn: %s." % str(open_status.get("disabled_reason", "")))
	var delta_run: RunState = RunStateScript.new()
	delta_run.start_new("TIER2-LOCK-GATE")
	delta_run.bankroll = 500
	delta_run.environment_history.append({"id": "small_underground_casino_002", "archetype_id": "small_underground_casino"})
	var delta_env := EnvironmentInstance.from_archetype(delta, 2, delta_run.create_rng("delta_env"), library)
	delta_run.set_environment(delta_env.to_dict())
	var expected_lock := int(delta.get("travel_locked_actions", 0))
	if delta_run.current_travel_lock_remaining() != expected_lock:
		failures.append("Delta Queen travel lock did not initialize from the archetype.")
	var grand_route := library.route("grand_casino")
	var locked_status := delta_run.travel_route_status(grand_route)
	if bool(locked_status.get("available", true)):
		failures.append("Delta Queen allowed travel before its ride lock expired.")
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(delta_run.to_dict())
	if loaded.current_travel_lock_remaining() != expected_lock:
		failures.append("Delta Queen travel lock did not survive save/load.")
	loaded.advance_environment_turns(maxi(0, expected_lock - 1))
	if expected_lock > 1 and loaded.current_travel_lock_remaining() <= 0:
		failures.append("Delta Queen travel lock expired too early.")
	loaded.advance_environment_turns(1)
	if loaded.current_travel_lock_remaining() != 0:
		failures.append("Delta Queen travel lock did not expire after the required action count.")
	var unlocked_status := loaded.travel_route_status(grand_route)
	if bool(unlocked_status.get("available", true)) or bool(unlocked_status.get("hidden", true)) or not bool(unlocked_status.get("locked", false)):
		failures.append("Delta Queen did not expose Grand Casino as a visible locked route before the invitation was earned.")
	loaded.narrative_flags["grand_casino_invite"] = true
	var invite_status := loaded.travel_route_status(grand_route)
	if not bool(invite_status.get("available", false)) or bool(invite_status.get("hidden", true)) or bool(invite_status.get("locked", true)):
		failures.append("Delta Queen did not allow onward travel after ride lock and invitation: %s." % str(invite_status.get("disabled_reason", "")))


func _check_grand_casino_invite_gate(library: ContentLibrary, kitty: Dictionary, delta: Dictionary, failures: Array) -> void:
	var invite_definition := library.event("grand_casino_invite")
	if invite_definition.is_empty():
		failures.append("Grand Casino invite event is missing.")
		return
	for archetype in [kitty, delta]:
		var archetype_id := str((archetype as Dictionary).get("id", ""))
		if not _string_array((archetype as Dictionary).get("event_pool", [])).has("grand_casino_invite"):
			failures.append("%s event pool does not include the Grand Casino invite." % archetype_id)
		if not _string_array((archetype as Dictionary).get("required_event_ids", [])).has("grand_casino_invite"):
			failures.append("%s does not require the Grand Casino invite event." % archetype_id)
	for seed_index in range(8):
		var seed_text := "GRAND-INVITE-SPAWN-%d" % seed_index
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(seed_text)
		for archetype in [kitty, delta]:
			var archetype_data := archetype as Dictionary
			var environment := EnvironmentInstance.from_archetype(archetype_data, 2, run_state.create_rng("%s:%s" % [seed_text, str(archetype_data.get("id", ""))]), library).to_dict()
			if not _string_array(environment.get("event_ids", [])).has("grand_casino_invite"):
				failures.append("%s did not guarantee Grand Casino invite for seed %s." % [str(archetype_data.get("id", "")), seed_text])
	var decline_run: RunState = RunStateScript.new()
	decline_run.start_new("GRAND-INVITE-DECLINE")
	var decline_env := EnvironmentInstance.from_archetype(delta, 2, decline_run.create_rng("decline_delta"), library).to_dict()
	decline_run.set_environment(decline_env)
	var invite_module := EventModule.new()
	invite_module.setup(invite_definition, library)
	if not invite_module.can_trigger(decline_run, decline_env):
		failures.append("Grand Casino invite did not trigger at a tier-2 casino before acceptance.")
	var decline_result := invite_module.resolve(decline_run, decline_env, "not_yet")
	if not bool(decline_result.get("ok", false)):
		failures.append("Grand Casino invite decline choice did not resolve.")
	if bool(decline_run.narrative_flags.get("grand_casino_invite", false)) or _string_array(decline_run.current_environment.get("resolved_event_ids", [])).has("grand_casino_invite"):
		failures.append("Declining Grand Casino invite set the flag or resolved the event.")
	if not invite_module.can_trigger(decline_run, decline_run.current_environment):
		failures.append("Declining Grand Casino invite did not leave the event re-openable.")
	var accept_run: RunState = RunStateScript.new()
	accept_run.start_new("GRAND-INVITE-ACCEPT")
	accept_run.bankroll = 500
	accept_run.environment_history.append({"id": "visited_once", "archetype_id": "corner_store"})
	var world_map := WorldMapScript.new(library)
	accept_run.set_world_map(world_map.build(accept_run, accept_run.create_rng("grand_invite_map")))
	var accept_env := EnvironmentInstance.from_archetype(delta, 2, accept_run.create_rng("accept_delta"), library).to_dict()
	accept_run.set_environment(accept_env)
	accept_run.current_environment["travel_lock_remaining"] = 0
	var locked_route := library.route("grand_casino")
	var locked_status := accept_run.travel_route_status(locked_route)
	if bool(locked_status.get("available", true)) or bool(locked_status.get("hidden", true)) or not bool(locked_status.get("locked", false)):
		failures.append("Grand Casino route was not exposed as a locked route before accepting the invite.")
	var underground_locked_status := accept_run.travel_route_status(library.route("small_underground_casino"))
	if bool(underground_locked_status.get("available", true)) or not bool(underground_locked_status.get("hidden", false)) or bool(underground_locked_status.get("locked", false)):
		failures.append("Underground route without locked_hint should remain fully hidden before its tip.")
	_check_grand_casino_locked_route_ui(library, delta, locked_route, failures)
	var accept_result := invite_module.resolve(accept_run, accept_run.current_environment, "accept_invite")
	if not bool(accept_result.get("ok", false)) or not bool(accept_run.narrative_flags.get("grand_casino_invite", false)):
		failures.append("Accepting Grand Casino invite did not set the unlock flag.")
	if not _string_array(accept_run.current_environment.get("resolved_event_ids", [])).has("grand_casino_invite"):
		failures.append("Accepting Grand Casino invite did not resolve the event instance.")
	var grand_node := WorldMapScript.node_by_id(accept_run.world_map, "grand_casino")
	if not bool(grand_node.get("unlocked", false)) or str(grand_node.get("discovery_source", "")) != WorldMapScript.DISCOVERY_SOURCE_EVENT:
		failures.append("Accepting Grand Casino invite did not unlock the Grand Casino map node as an event discovery.")
	var unlocked_status := accept_run.travel_route_status(locked_route)
	if not bool(unlocked_status.get("available", false)) or bool(unlocked_status.get("hidden", true)) or bool(unlocked_status.get("locked", true)):
		failures.append("Grand Casino route did not become available after accepting the invite.")
	var suppressed_env := EnvironmentInstance.from_archetype(kitty, 2, accept_run.create_rng("suppressed_kitty"), library).to_dict()
	if invite_module.can_trigger(accept_run, suppressed_env):
		failures.append("Grand Casino invite copy at the other tier-2 venue was not suppressed after acceptance.")
	var save_service: SaveService = SaveServiceScript.new()
	var accept_slot := "foundation_check_grand_invite_accept"
	var save_error: Error = save_service.save_run(accept_run, accept_slot)
	if save_error != OK:
		failures.append("Save service could not save Grand Casino invite progress: %s." % save_error)
	else:
		var loaded_accept = save_service.load_run(accept_slot)
		if loaded_accept == null:
			failures.append("Save service could not reload Grand Casino invite progress.")
		else:
			var loaded_status: Dictionary = loaded_accept.travel_route_status(locked_route)
			if not bool(loaded_status.get("available", false)):
				failures.append("Grand Casino invite route availability did not survive save/load.")
	var gated_run: RunState = RunStateScript.new()
	gated_run.start_new("GRAND-INVITE-GATED-LOAD")
	gated_run.bankroll = 500
	gated_run.environment_history.append({"id": "visited_once", "archetype_id": "corner_store"})
	var gated_slot := "foundation_check_grand_invite_gated"
	var gated_save_error: Error = save_service.save_run(gated_run, gated_slot)
	if gated_save_error == OK:
		var loaded_gated = save_service.load_run(gated_slot)
		if loaded_gated != null:
			var gated_status: Dictionary = loaded_gated.travel_route_status(locked_route)
			if bool(gated_status.get("available", true)) or bool(gated_status.get("hidden", true)) or not bool(gated_status.get("locked", false)):
				failures.append("Grand Casino locked route hint did not survive save/load without the invite flag.")


func _check_grand_casino_locked_route_ui(library: ContentLibrary, delta: Dictionary, locked_route: Dictionary, failures: Array) -> void:
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Grand Casino locked route UI fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Grand Casino locked route UI fixture requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return
	var ui_run: RunState = RunStateScript.new()
	ui_run.start_new("GRAND-LOCKED-ROUTE-UI")
	ui_run.bankroll = 500
	ui_run.environment_history.append({"id": "visited_once", "archetype_id": "corner_store"})
	var world_map := WorldMapScript.new(library)
	ui_run.set_world_map(world_map.build(ui_run, ui_run.create_rng("grand_locked_ui_map")))
	var delta_env := EnvironmentInstance.from_archetype(delta, 2, ui_run.create_rng("grand_locked_ui_delta"), library).to_dict()
	delta_env["travel_lock_remaining"] = 0
	ui_run.set_environment(delta_env)
	ui_run.world_map = WorldMapScript.unlock_nodes(ui_run.world_map, ["delta_queen", "grand_casino"], WorldMapScript.DISCOVERY_SOURCE_EVENT)
	ui_run.world_map = WorldMapScript.enter_node(ui_run.world_map, "delta_queen", ui_run.current_environment)
	app.set("library", library)
	app.set("generator", RunGeneratorScript.new(library))
	app.set("run_state", ui_run)
	app.set("current_game", null)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	var choices: Array = app.call("_travel_choice_view_list")
	var grand_choice: Dictionary = {}
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if str(choice.get("id", "")) == "grand_casino":
			grand_choice = choice
			break
	if grand_choice.is_empty():
		failures.append("Grand Casino locked route did not render in the travel list.")
	else:
		if bool(grand_choice.get("enabled", true)) or not bool(grand_choice.get("locked", false)):
			failures.append("Grand Casino locked route travel row was not disabled and marked locked.")
		if str(grand_choice.get("disabled_reason", "")).find("invitation") == -1:
			failures.append("Grand Casino locked route row did not show the invitation condition.")
		if not grand_choice.has("cost") or not grand_choice.has("distance") or not grand_choice.has("distance_blocks"):
			failures.append("Grand Casino locked route row did not retain its read-only travel cost and distance details.")
	if bool(app.call("select_travel_option", "grand_casino")):
		failures.append("Grand Casino locked route was selectable from the travel list.")
	if not str(app.get("selected_travel_target_id")).is_empty():
		failures.append("Grand Casino locked route armed selected_travel_target_id.")
	var map_snapshot: Dictionary = app.call("_world_map_snapshot")
	var grand_node: Dictionary = {}
	for node_value in _copy_array(map_snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if str(node.get("id", "")) == "grand_casino":
			grand_node = node
			break
	if not grand_node.is_empty():
		failures.append("Grand Casino map node was visible before the player accepted its invitation.")
	if bool(app.call("select_world_map_node", "grand_casino")):
		failures.append("Grand Casino locked map node was selectable for travel.")
	if not str(app.get("selected_travel_target_id")).is_empty():
		failures.append("Grand Casino locked map node armed selected_travel_target_id.")
	var unlocked_run: RunState = RunStateScript.new()
	unlocked_run.from_dict(ui_run.to_dict())
	unlocked_run.narrative_flags["grand_casino_invite"] = true
	var unlocked_status := unlocked_run.travel_route_status(locked_route)
	if not bool(unlocked_status.get("available", false)) or bool(unlocked_status.get("hidden", true)) or bool(unlocked_status.get("locked", true)):
		failures.append("Grand Casino locked_hint route did not return normal status after the invite flag.")
	_sb4_dispose_app(app)


# Collects unique ids from one array field across environment archetypes.
func _all_environment_ids(archetypes: Array, field_name: String) -> Array:
	var result: Array = []
	for archetype in archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var values: Variant = (archetype as Dictionary).get(field_name, [])
		if typeof(values) != TYPE_ARRAY:
			continue
		for value in values:
			var id := str(value).strip_edges()
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result


func _check_baccarat_grand_casino_only(library: ContentLibrary, failures: Array) -> void:
	var found_baccarat_in_grand := false
	var found_roulette_in_grand := false
	var roulette_rooms := ["kitty_cat_lounge", "delta_queen", RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID]
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		var pool := _string_array(archetype.get("game_pool", []))
		if pool.has("baccarat"):
			if archetype_id != RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
				failures.append("Baccarat must only appear in the Grand Casino High-Limit Room, but %s includes it." % archetype_id)
			else:
				found_baccarat_in_grand = true
		if pool.has("roulette"):
			if not roulette_rooms.has(archetype_id):
				failures.append("Roulette must only appear in the Grand Casino High-Limit Room or T4.1 tier-2 wheel venues, but %s includes it." % archetype_id)
			if archetype_id == RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
				found_roulette_in_grand = true
		if archetype_id == RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			var count_range: Array = archetype.get("game_count", []) if typeof(archetype.get("game_count", [])) == TYPE_ARRAY else []
			if count_range.size() < 2 or int(count_range[0]) < pool.size() or int(count_range[1]) < pool.size():
				failures.append("Grand Casino High-Limit Room does not guarantee every premium table is present.")
	if not found_baccarat_in_grand:
		failures.append("Baccarat must be present in the Grand Casino High-Limit game pool.")
	if not found_roulette_in_grand:
		failures.append("Roulette must be present in the Grand Casino High-Limit game pool.")


# Checks generated item offer prices.
func _check_offer_prices(offers: Array, library: ContentLibrary, failures: Array) -> void:
	var seen: Array = []
	for offer in offers:
		var item_id: String = offer.get("id", "")
		if seen.has(item_id):
			failures.append("Generated duplicate shop item offer: %s." % item_id)
		seen.append(item_id)
		var item := library.item(item_id)
		if item.is_empty():
			failures.append("Generated offer references unknown item: %s." % item_id)
			continue
		var price := int(offer.get("price", -1))
		if price < int(item.get("price_min", 0)) or price > int(item.get("price_max", 0)):
			failures.append("Generated item price outside range: %s." % item_id)


# Checks that room-facing items and events have replaceable art metadata.
func _check_content_art_presentation(library: ContentLibrary, failures: Array) -> void:
	var item_icon_keys: Dictionary = {}
	var item_asset_paths: Dictionary = {}
	for item in library.items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_data: Dictionary = item
		var item_id := str(item_data.get("id", ""))
		_check_replaceable_asset("items %s" % item_id, item_data, failures)
		for key in ["icon_key", "environment_prop", "surface"]:
			if str(item_data.get(key, "")).strip_edges().is_empty():
				failures.append("items %s is missing %s for room/inventory presentation." % [item_id, key])
		var icon_key := str(item_data.get("icon_key", "")).strip_edges()
		if not icon_key.is_empty():
			if item_icon_keys.has(icon_key):
				failures.append("items %s and %s share icon_key %s." % [str(item_icon_keys.get(icon_key, "")), item_id, icon_key])
			else:
				item_icon_keys[icon_key] = item_id
		var asset_path := str(item_data.get("asset_path", "")).strip_edges()
		if not asset_path.is_empty():
			if item_asset_paths.has(asset_path):
				failures.append("items %s and %s share asset_path %s." % [str(item_asset_paths.get(asset_path, "")), item_id, asset_path])
			else:
				item_asset_paths[asset_path] = item_id
	for event in library.events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event
		var event_id := str(event_data.get("id", ""))
		_check_replaceable_asset("events %s" % event_id, event_data, failures)
		var interaction_mode := str(event_data.get("interaction_mode", "")).strip_edges()
		var icon_key := str(event_data.get("icon_key", "")).strip_edges()
		var environment_prop := str(event_data.get("environment_prop", "")).strip_edges()
		if interaction_mode == "triggered":
			if not icon_key.is_empty() or not environment_prop.is_empty():
				failures.append("events %s is triggered and should not define room presentation keys." % event_id)
		else:
			if icon_key.is_empty() or icon_key == "event":
				failures.append("events %s must define a non-generic icon_key." % event_id)
			for key in ["environment_prop", "start_summary"]:
				if str(event_data.get(key, "")).strip_edges().is_empty():
					failures.append("events %s is missing %s for room interaction presentation." % [event_id, key])


func _check_blackjack_control_hit_regions(harness: SurfaceHarness, failures: Array) -> void:
	var control_actions := [
		"blackjack_hit",
		"blackjack_stand",
		"blackjack_double",
		"blackjack_split",
		"blackjack_peek",
		"blackjack_surrender",
	]
	var regions: Array = []
	for region_value in harness.hit_regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var action := str(region.get("action", ""))
		if not control_actions.has(action):
			continue
		var rect: Rect2 = region.get("rect", Rect2())
		regions.append({"action": action, "rect": rect})
		if not bool(region.get("exact", false)):
			failures.append("Blackjack control button %s uses an expanded hitbox instead of the visible button rect." % action)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("Blackjack control button %s registered an empty hitbox." % action)
	for action_value in control_actions:
		var expected_action := str(action_value)
		var found := false
		for region_value in regions:
			var region: Dictionary = region_value
			if str(region.get("action", "")) == expected_action:
				found = true
				break
		if not found:
			failures.append("Blackjack control button %s did not register a surface hit region." % expected_action)
	for i in range(regions.size()):
		var first: Dictionary = regions[i]
		var first_rect: Rect2 = first.get("rect", Rect2())
		for j in range(i + 1, regions.size()):
			var second: Dictionary = regions[j]
			var second_rect: Rect2 = second.get("rect", Rect2())
			if first_rect.intersects(second_rect):
				failures.append("Blackjack control hitboxes overlap: %s and %s." % [str(first.get("action", "")), str(second.get("action", ""))])


func _check_blackjack_item_content(library: ContentLibrary, failures: Array) -> void:
	var required_effects := {
		"marked_cards": ["blackjack_peek_heat_delta", "blackjack_dealer_catch_chance", "blackjack_peek_loss_reduction"],
		"card_counters_notes": ["blackjack_count_tolerance", "blackjack_count_window_msec", "blackjack_count_heat_delta", "blackjack_count_cover", "blackjack_count_edge_bonus"],
		"side_bet_chart": ["blackjack_side_bet_bonus", "blackjack_side_bet_loss_reduction", "blackjack_side_bet_flat_bonus"],
		"basic_strategy_card": ["blackjack_basic_strategy_card"],
		"lucky_ladies_compact": ["blackjack_lucky_ladies_stake_multiplier", "blackjack_lucky_ladies_payout_multiplier"],
		"coolers_cufflinks": ["blackjack_failed_peek_heat_absorb"],
		"broken_cufflinks": ["blackjack_peek_window_percent", "repair_cost", "repair_to_item"],
		"high_roller_watch": ["blackjack_table_limit_multiplier", "blackjack_table_minimum_to_previous_max"],
	}
	var reachable_blackjack_items: Array = []
	for item_id in required_effects.keys():
		var item := library.item(str(item_id))
		if item.is_empty():
			failures.append("Blackjack support item is missing from item content: %s." % item_id)
			continue
		var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
		for effect_key in required_effects[item_id]:
			if not effect.has(str(effect_key)):
				failures.append("Blackjack support item %s is missing effect key %s." % [item_id, effect_key])
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if _item_count_ceiling(archetype.get("item_count", 0)) <= 0:
			continue
		var pool := library.shop_item_pool_for_challenge(archetype.get("item_pool", []), {})
		for item_id in required_effects.keys():
			if pool.has(str(item_id)) and not reachable_blackjack_items.has(str(item_id)):
				reachable_blackjack_items.append(str(item_id))
	for item_id in required_effects.keys():
		var item := library.item(str(item_id))
		if bool(item.get("sellable", true)) and not reachable_blackjack_items.has(str(item_id)):
			failures.append("Blackjack support item is not reachable from any generated item pool: %s." % item_id)
	var repair_run_state: RunState = RunStateScript.new()
	repair_run_state.start_new("BLACKJACK-CUFFLINK-REPAIR")
	repair_run_state.change_bankroll(100)
	repair_run_state.set_environment({
		"id": "blackjack_repair_shop",
		"archetype_id": "corner_store",
		"kind": "shop",
		"display_name": "Repair Shop",
		"item_offers": [],
	})
	repair_run_state.add_item("broken_cufflinks")
	var repair_service: RunActionService = RunActionServiceScript.new()
	repair_service.setup(library, repair_run_state)
	var repair_result: Dictionary = repair_service.repair_inventory_item("broken_cufflinks")
	if not bool(repair_result.get("ok", false)):
		failures.append("Shopkeeper could not repair Broken Cufflinks.")
	else:
		if repair_run_state.inventory.has("broken_cufflinks") or not repair_run_state.inventory.has("coolers_cufflinks"):
			failures.append("Broken Cufflinks repair did not swap inventory items.")
		if repair_run_state.bankroll != 150:
			failures.append("Broken Cufflinks repair did not cost exactly $50.")


func _item_count_ceiling(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.is_empty():
			return 0
		return int(values[values.size() - 1])
	return int(value)


func _check_replaceable_asset(label: String, data: Dictionary, failures: Array) -> void:
	var asset_path := str(data.get("asset_path", "")).strip_edges()
	if asset_path.is_empty():
		failures.append("%s is missing asset_path." % label)
	elif not asset_path.begins_with("res://assets/art/"):
		failures.append("%s asset_path must stay under res://assets/art/." % label)
	elif not FileAccess.file_exists(asset_path):
		failures.append("%s references missing asset_path: %s." % [label, asset_path])


# Checks generated events against allowed scopes.
func _check_events(event_ids: Array, library: ContentLibrary, scopes: Array, failures: Array) -> void:
	if event_ids.size() < 2 or event_ids.size() > 4:
		failures.append("Environment should generate 2-4 events.")
	for event_id in event_ids:
		var event := library.event(event_id)
		if event.is_empty():
			failures.append("Generated unknown event: %s." % event_id)
			continue
		var event_scopes: Array = event.get("scopes", [])
		var matches := event_scopes.has("any")
		for scope in scopes:
			matches = matches or event_scopes.has(scope)
		if not matches:
			failures.append("Generated event does not match environment scope: %s." % event_id)


# Creates in-memory content for contract checks.
func _fixture_library() -> ContentLibrary:
	var library := ContentLibraryScript.new()
	library.environment_archetypes = [
		{
			"id": "fixture_environment",
			"tier": 1,
			"name_prefixes": ["Fixture"],
			"name_nouns": ["Venue"],
			"visual_context": {
				"perspective": "first_person",
				"scene_type": "fixture",
			},
			"security_profile": {
				"strictness": "fixture",
				"visible_cues": ["fixture cue"],
			},
			"economic_profile": {
				"stake_floor": 1,
				"stake_ceiling": 10,
			},
			"game_pool": ["fixture_game"],
			"game_count": [1, 1],
			"event_pool": ["fixture_event"],
			"event_count": [1, 1],
			"item_pool": ["fixture_item"],
			"item_count": [1, 1],
			"service_pool": ["fixture_service"],
			"lender_hooks": ["fixture_lender"],
			"suspicion_cues": ["fixture behavior cue"],
			"travel_hooks": ["fixture_route"],
			"next_archetypes": ["fixture_environment"],
			"local_narrative_flags": {
				"fixture_flag": true,
			},
			"moods": ["fixture_mood"],
		},
	]
	library.games = [
		{
			"id": "fixture_game",
			"module": "base",
			"family": "fixture",
			"display_name": "Fixture Game",
			"intro": "Fixture game contract.",
			"legal_actions": [{"id": "legal_fixture", "label": "Legal Fixture", "win_chance": 55, "payout_mult": 2}],
			"cheat_actions": [{"id": "cheat_fixture", "label": "Cheat Fixture", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
		},
	]
	library.items = [
		{
			"id": "fixture_item",
			"class": "permanent",
			"domain": "global",
			"effect": {"win_chance": 1},
		},
	]
	library.events = [
		{
			"id": "fixture_event",
			"type": "security",
			"scopes": ["any"],
			"tier_min": 1,
			"min_suspicion": 0,
			"consequences": {
				"suspicion_delta": 1,
			},
			"payload": {
				"summary": "Fixture event contract.",
				"choices": [
					{"id": "raise_heat", "label": "Raise Heat", "text": "Fixture heat rises.", "consequences": {"suspicion_delta": 2, "flags": {"fixture_event_flag": true}, "resolve_event": true}},
				],
			},
		},
	]
	library.challenges = [
		RunState.custom_challenge("fixture_challenge", "FIXTURE-SEED", {"fixture": true}),
	]
	library.lenders = [
		{
			"id": "fixture_lender",
			"source": "fixture",
			"display_name": "Fixture Lender",
			"risk_profile": "fixture",
			"consequences": ["fixture_consequence"],
		},
	]
	library.services = [
		{
			"id": "fixture_service",
			"type": "fixture",
			"cost": 1,
			"effect": {},
		},
	]
	library.travel_routes = [
		{
			"id": "fixture_route",
			"display_name": "Fixture Route",
			"cost": 1,
			"destination_tier_hint": 1,
		},
	]
	return library


func _check_card_shoe_core_primitives(failures: Array) -> void:
	var shoe: Array = [
		{"rank": 14, "suit": 0, "deck": 0},
		"bad-card",
		{"rank": 10, "suit": 1, "deck": 0},
		{"rank": 5, "suit": 2, "deck": 0},
		{"rank": 7, "suit": 3, "deck": 1},
	]
	var original_json := JSON.stringify(shoe)
	var draw: Dictionary = CardShoeScript.draw_cards(shoe, 2)
	var drawn_cards: Array = draw.get("cards", [])
	var remaining_shoe: Array = draw.get("shoe", [])
	if JSON.stringify(shoe) != original_json:
		failures.append("CardShoe.draw_cards mutated the source shoe.")
	if drawn_cards.size() != 2 or remaining_shoe.size() != 2 or int(draw.get("remaining", -1)) != 2:
		failures.append("CardShoe.draw_cards did not preserve draw/remaining counts while filtering malformed cards.")
	else:
		var first_drawn: Dictionary = drawn_cards[0]
		var second_drawn: Dictionary = drawn_cards[1]
		var first_remaining: Dictionary = remaining_shoe[0]
		if int(first_drawn.get("rank", 0)) != 14 or int(second_drawn.get("rank", 0)) != 10 or int(first_remaining.get("rank", 0)) != 5:
			failures.append("CardShoe.draw_cards changed deterministic card order.")
	var composition: Dictionary = CardShoeScript.remaining_composition(shoe)
	if JSON.stringify(shoe) != original_json:
		failures.append("CardShoe.remaining_composition mutated the source shoe.")
	if CardShoeScript.remaining_count(shoe) != 4 or int(composition.get("total", 0)) != 4:
		failures.append("CardShoe remaining helpers did not ignore malformed card entries.")
	if int(composition.get("high_cards", 0)) != 2 or int(composition.get("low_cards", 0)) != 1 or int(composition.get("neutral_cards", 0)) != 1:
		failures.append("CardShoe.remaining_composition changed hi-lo bucket counts.")


# Checks seed and generation determinism.
func _check_rng(library: ContentLibrary, failures: Array) -> void:
	var rng_a := RngStream.new()
	rng_a.configure(12345)
	var rng_b := RngStream.new()
	rng_b.configure(12345)
	var rng_a_values := [rng_a.randi_range(0, 10), rng_a.randi_range(0, 10), rng_a.randi_range(0, 10)]
	var rng_b_values := [rng_b.randi_range(0, 10), rng_b.randi_range(0, 10), rng_b.randi_range(0, 10)]
	if JSON.stringify(rng_a_values) != JSON.stringify(rng_b_values):
		failures.append("RngStream is not deterministic.")
	var rng_snapshot := rng_a.snapshot()
	var rng_restored := RngStream.new()
	rng_restored.restore(rng_snapshot)
	if rng_a.randi_range(0, 100) != rng_restored.randi_range(0, 100):
		failures.append("RngStream snapshot/restore did not preserve stream state.")
	_check_keyed_rng_streams(failures)

	var custom_challenge := RunState.custom_challenge("foundation_smoke", "FOUNDATION-TEST-SEED", {"stake_pressure": "test"})
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a = generator_a.next_environment(run_a)
	var environment_b = generator_b.next_environment(run_b)

	if JSON.stringify(environment_a.to_dict()) != JSON.stringify(environment_b.to_dict()):
		failures.append("Same fixture seed did not generate the same fixture environment.")
	if run_a.rng_state != run_b.rng_state:
		failures.append("Same fixture seed did not leave the same RunState RNG state after generation.")
	_check_same_seed_game_result(library, custom_challenge, failures)

	var different_challenge_run: RunState = RunStateScript.new()
	different_challenge_run.start_new("FOUNDATION-TEST-SEED", RunState.custom_challenge("foundation_smoke", "FOUNDATION-TEST-SEED", {"stake_pressure": "different"}))
	if different_challenge_run.seed_value == run_a.seed_value:
		failures.append("Challenge modifiers did not affect deterministic seed value.")
	var different_challenge_rng := different_challenge_run.create_rng()
	var baseline_challenge_rng := RunStateScript.new()
	baseline_challenge_rng.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	if JSON.stringify(different_challenge_rng.snapshot()) == JSON.stringify(baseline_challenge_rng.create_rng().snapshot()):
		failures.append("Different challenge modifiers did not change the deterministic stream snapshot.")
	if different_challenge_rng.randi_range(1, 1000000) == baseline_challenge_rng.create_rng().randi_range(1, 1000000):
		failures.append("Different challenge modifiers did not change the deterministic stream.")


# Checks named RNG streams are stable and distinct.
func _check_keyed_rng_streams(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREAM-SEED", RunState.custom_challenge("stream_keys", "STREAM-SEED", {"fixture": true}))
	var state_before := run_state.rng_state
	var environment_stream_a := run_state.create_rng("environment")
	var environment_stream_b := run_state.create_rng("environment")
	var game_stream := run_state.create_rng("game")
	var environment_value_a := environment_stream_a.randi_range(1, 1000000)
	var environment_value_b := environment_stream_b.randi_range(1, 1000000)
	var game_value := game_stream.randi_range(1, 1000000)
	if environment_stream_a.seed_value != environment_stream_b.seed_value:
		failures.append("Same RunState stream key did not derive the same stream seed.")
	if environment_stream_a.seed_value == game_stream.seed_value:
		failures.append("Different RunState stream keys did not derive distinct stream seeds.")
	if environment_value_a != environment_value_b:
		failures.append("Same RunState stream key did not produce the same deterministic stream.")
	if environment_value_a == game_value:
		failures.append("Different RunState stream keys did not produce distinct deterministic streams.")
	if run_state.rng_state != state_before:
		failures.append("RunState.create_rng with a stream key mutated stored RNG state.")


# Checks deterministic game resolution through the foundation RNG path.
func _check_same_seed_game_result(library: ContentLibrary, challenge: Dictionary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("FOUNDATION-TEST-SEED", challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("FOUNDATION-TEST-SEED", challenge)
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a = generator_a.next_environment(run_a)
	var environment_b = generator_b.next_environment(run_b)
	var game_a := GameModule.new()
	game_a.setup(library.game("fixture_game"))
	var game_b := GameModule.new()
	game_b.setup(library.game("fixture_game"))
	var result_a := game_a.resolve("legal_fixture", 1, run_a, environment_a.to_dict(), run_a.create_rng())
	var result_b := game_b.resolve("legal_fixture", 1, run_b, environment_b.to_dict(), run_b.create_rng())
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Same seed and challenge did not produce the same foundation game result.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Same foundation game result did not leave matching RunState snapshots.")


# Checks that RunState owns foundation run state and round-trips every required domain.
func _check_run_state_source_of_truth(library: ContentLibrary, failures: Array) -> void:
	var challenge := RunState.custom_challenge("run_state_round_trip", "RUNSTATE-SEED", {"route": "fixture", "pressure": "low"})
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("IGNORED-SEED", challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("IGNORED-SEED", challenge)
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("RunState.start_new is not deterministic for the same seed and challenge.")

	var rng_a := run_a.create_rng()
	var rng_b := run_b.create_rng()
	if rng_a.randi_range(1, 1000) != rng_b.randi_range(1, 1000):
		failures.append("RunState did not create deterministic RNG streams from initial state.")

	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment = generator.next_environment(run_a)
	var history_probe: RunState = RunStateScript.new()
	history_probe.start_new("HISTORY-COMPACTION-SEED", challenge)
	var previous_environment: Dictionary = environment.duplicate(true)
	previous_environment["runtime_state"] = {"large_transient_machine_state": [1, 2, 3, 4]}
	history_probe.current_environment = previous_environment
	history_probe.set_environment(environment)
	var compact_history: Dictionary = history_probe.environment_history[0] if not history_probe.environment_history.is_empty() else {}
	if compact_history.has("runtime_state") or not compact_history.has("id") or not compact_history.has("archetype_id"):
		failures.append("RunState environment history retained full runtime state instead of a compact visited-location record.")
	run_a.change_bankroll(-17)
	run_a.add_item("fixture_item")
	run_a.set_active_item("fixture_item")
	run_a.add_debt({
		"id": "fixture_debt",
		"lender_id": "fixture_lender",
		"balance": 30,
		"status": "active",
	})
	run_a.add_suspicion("fixture_behavior", 4, "behavior", false, {"environment_id": environment.id})
	run_a.narrative_flags["fixture_flag"] = true
	run_a.set_story_flag("fixture_story_flag", true)
	run_a.log_story({"type": "round_trip", "id": "fixture_story", "environment_id": environment.id})
	run_a.record_score_spending(13, "round_trip_fixture")
	run_a.advance_environment_turns(2)
	run_a.resolve_event("fixture_event")
	run_a.set_next_archetypes(["fixture_environment"])
	var advanced_rng := run_a.create_rng()
	advanced_rng.randi_range(1, 1000)
	run_a.save_rng(advanced_rng)

	var snapshot := run_a.to_dict()
	_check_run_state_snapshot_keys(snapshot, failures)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	_assert_equal(run_a.seed_text, restored.seed_text, "RunState seed_text did not survive round-trip.", failures)
	_assert_equal(run_a.seed_value, restored.seed_value, "RunState seed_value did not survive round-trip.", failures)
	_assert_equal(run_a.rng_seed, restored.rng_seed, "RunState rng_seed did not survive round-trip.", failures)
	_assert_equal(run_a.rng_state, restored.rng_state, "RunState rng_state did not survive round-trip.", failures)
	_assert_json_equal(run_a.challenge_config, restored.challenge_config, "RunState challenge config did not survive round-trip.", failures)
	_assert_equal(run_a.bankroll, restored.bankroll, "RunState bankroll did not survive round-trip.", failures)
	_assert_equal(run_a.economic_state, restored.economic_state, "RunState economic state did not survive round-trip.", failures)
	_assert_json_equal(run_a.inventory, restored.inventory, "RunState inventory did not survive round-trip.", failures)
	_assert_equal(run_a.active_item_id, restored.active_item_id, "RunState active item did not survive round-trip.", failures)
	_assert_json_equal(run_a.debt, restored.debt, "RunState debt did not survive round-trip.", failures)
	_assert_json_equal(run_a.suspicion, restored.suspicion, "RunState suspicion did not survive round-trip.", failures)
	_assert_json_equal(run_a.current_environment, restored.current_environment, "RunState current environment did not survive round-trip.", failures)
	_assert_json_equal(run_a.environment_history, restored.environment_history, "RunState environment history did not survive round-trip.", failures)
	_assert_json_equal(run_a.unlocked_travel, restored.unlocked_travel, "RunState travel hooks did not survive round-trip.", failures)
	_assert_json_equal(run_a.narrative_flags, restored.narrative_flags, "RunState narrative flags did not survive round-trip.", failures)
	_assert_json_equal(run_a.story_flags, restored.story_flags, "RunState story flags did not survive round-trip.", failures)
	_assert_json_equal(run_a.story_log, restored.story_log, "RunState story log did not survive round-trip.", failures)
	_assert_equal(run_a.run_status, restored.run_status, "RunState run status did not survive round-trip.", failures)
	_assert_equal(run_a.run_spending_score, restored.run_spending_score, "RunState score spending did not survive round-trip.", failures)

	var original_rng := run_a.create_rng()
	var restored_rng := restored.create_rng()
	if original_rng.randi_range(1, 1000) != restored_rng.randi_range(1, 1000):
		failures.append("RunState restored RNG state did not continue the same stream.")

	snapshot["inventory"].append("mutated_item")
	snapshot["debt"][0]["balance"] = 999
	snapshot["suspicion"]["cues"][0]["context"]["environment_id"] = "mutated_environment"
	snapshot["current_environment"]["id"] = "mutated_environment"
	snapshot["narrative_flags"]["fixture_flag"] = false
	snapshot["story_flags"]["fixture_story_flag"] = false
	snapshot["story_log"][0]["id"] = "mutated_story"
	if restored.inventory.has("mutated_item"):
		failures.append("RunState.from_dict retained mutable inventory source data.")
	if int(restored.debt[0].get("balance", 0)) == 999:
		failures.append("RunState.from_dict retained mutable debt source data.")
	if str(restored.suspicion.get("cues", [])[0].get("context", {}).get("environment_id", "")) == "mutated_environment":
		failures.append("RunState.from_dict retained mutable suspicion source data.")
	if restored.current_environment.get("id", "") == "mutated_environment":
		failures.append("RunState.from_dict retained mutable environment source data.")
	if not bool(restored.narrative_flags.get("fixture_flag", false)):
		failures.append("RunState.from_dict retained mutable flag source data.")
	if not bool(restored.story_flags.get("fixture_story_flag", false)):
		failures.append("RunState.from_dict retained mutable story flag source data.")
	if str(restored.story_log[0].get("id", "")) == "mutated_story":
		failures.append("RunState.from_dict retained mutable story source data.")


func _check_save_load_interrupt_fuzz_foundation(library: ContentLibrary, failures: Array) -> void:
	_check_save_load_seed_sweep(library, failures)
	_check_save_load_targeted_midstates(library, failures)
	_check_save_load_030_compat_fixture(library, failures)
	_check_save_load_033_compat_fixture(library, failures)


func _check_save_load_seed_sweep(library: ContentLibrary, failures: Array) -> void:
	for seed_index in range(SAVE_LOAD_FUZZ_SEEDS):
		var seed_text := "SB3-FUZZ-%02d" % seed_index
		var challenge := RunState.custom_challenge("sb3_save_fuzz", seed_text, {
			"starting_bankroll": 4500,
			"baseline_luck_delta": 1 if seed_index % 2 == 0 else 0,
			"starting_heat": 4 if seed_index % 3 == 0 else 0,
			"hidden_seed": true,
		})
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(seed_text, challenge)
		var generator: RunGenerator = RunGeneratorScript.new(library)
		generator.next_environment(run_state)
		for action_index in range(SAVE_LOAD_FUZZ_ACTIONS_PER_SEED):
			var label := "%s/action_%02d" % [seed_text, action_index]
			var advanced := _save_load_fuzz_drive_action(library, generator, run_state, action_index, label, failures)
			if not advanced and not run_state.is_terminal():
				failures.append("SB.3 save/load fuzz could not find a legal continuation at %s." % label)
				break
			var restored := _save_load_checkpoint(library, run_state, label, true, failures)
			if restored != null:
				run_state = restored
			if run_state.is_terminal():
				break


func _save_load_fuzz_drive_action(library: ContentLibrary, generator: RunGenerator, run_state: RunState, action_index: int, label: String, failures: Array) -> bool:
	if run_state == null or run_state.is_terminal():
		return false
	if run_state.current_environment.is_empty():
		generator.next_environment(run_state)
	if _save_load_fuzz_resolve_triggered_event(library, run_state, label, failures):
		return true
	if action_index % 7 == 3 and _save_load_fuzz_use_service_item_or_lender(library, run_state):
		return true
	if action_index % 5 == 4 and _save_load_fuzz_travel(generator, run_state):
		return true
	if _save_load_fuzz_play_game(library, run_state, action_index, label, failures):
		return true
	if _save_load_fuzz_use_service_item_or_lender(library, run_state):
		return true
	return _save_load_fuzz_travel(generator, run_state)


func _save_load_fuzz_resolve_triggered_event(library: ContentLibrary, run_state: RunState, label: String, failures: Array) -> bool:
	var entry := _copy_dict(run_state.active_triggered_event)
	if entry.is_empty():
		entry = run_state.next_pending_triggered_event()
		if entry.is_empty():
			return false
		entry = run_state.begin_triggered_event_resolution(entry)
	var event_id := str(entry.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		run_state.complete_triggered_event_resolution()
		return true
	var definition := library.event(event_id)
	if definition.is_empty():
		failures.append("SB.3 save/load fuzz found unknown triggered event %s at %s." % [event_id, label])
		run_state.complete_triggered_event_resolution(event_id)
		return true
	var event := EventModule.new()
	event.setup(definition, library)
	var choices := event.choices(run_state, run_state.current_environment)
	if choices.is_empty():
		run_state.complete_triggered_event_resolution(event_id)
		return true
	var choice: Dictionary = choices[0] if typeof(choices[0]) == TYPE_DICTIONARY else {}
	var choice_id := str(choice.get("id", "")).strip_edges()
	if choice_id.is_empty():
		run_state.complete_triggered_event_resolution(event_id)
		return true
	event.resolve(run_state, run_state.current_environment, choice_id)
	run_state.complete_triggered_event_resolution(event_id)
	return true


func _save_load_fuzz_use_service_item_or_lender(library: ContentLibrary, run_state: RunState) -> bool:
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	for service_value in resolver.service_hook_view_list():
		if typeof(service_value) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = service_value
		if bool(service.get("enabled", false)) and bool(service.get("mutation_supported", false)):
			var service_result := resolver.use_hook("service", str(service.get("id", "")))
			return bool(service_result.get("ok", false))
	for lender_value in resolver.lender_hook_view_list():
		if typeof(lender_value) != TYPE_DICTIONARY:
			continue
		var lender: Dictionary = lender_value
		if bool(lender.get("enabled", false)) and bool(lender.get("mutation_supported", false)):
			var lender_result := resolver.use_hook("lender", str(lender.get("id", "")))
			return bool(lender_result.get("ok", false))
	for offer_value in resolver.item_offer_view_list():
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		if bool(offer.get("affordable", false)):
			var item_result := resolver.buy_item_offer(str(offer.get("id", "")))
			return bool(item_result.get("ok", false))
	return false


func _save_load_fuzz_travel(generator: RunGenerator, run_state: RunState) -> bool:
	if run_state == null or generator == null or not run_state.has_world_map():
		return false
	var current_node_id := run_state.current_world_node_id()
	for target_value in WorldMapScript.travel_target_ids(run_state.world_map, current_node_id):
		var target_id := str(target_value)
		if target_id.is_empty() or target_id == current_node_id:
			continue
		var route := generator.world_route_for_target(run_state, target_id)
		if route.is_empty():
			continue
		var status := run_state.travel_route_status(route)
		if not bool(status.get("available", false)):
			continue
		var cost := maxi(0, int(status.get("cost", route.get("cost", 0))))
		var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
		generator.next_environment(run_state, target_id)
		run_state.finish_travel_suspicion_decay(travel_heat)
		if cost > 0:
			GameModule.apply_result(run_state, _world_map_travel_charge_result(target_id, cost))
		return true
	return false


func _save_load_fuzz_play_game(library: ContentLibrary, run_state: RunState, action_index: int, _label: String, failures: Array) -> bool:
	var game_ids := _string_array(run_state.current_environment.get("game_ids", []))
	if game_ids.is_empty():
		return false
	var start_index := posmod(action_index, game_ids.size())
	for offset in range(game_ids.size()):
		var game_id := str(game_ids[posmod(start_index + offset, game_ids.size())])
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		if game_id == "slot" and _save_load_fuzz_play_slot_bonus(game, run_state, action_index):
			return true
		var actions: Dictionary = game.actions(run_state, run_state.current_environment)
		var legal_actions: Array = actions.get("legal_actions", []) if typeof(actions.get("legal_actions", [])) == TYPE_ARRAY else []
		var combined_actions: Array = []
		combined_actions.append_array(legal_actions)
		var cheat_actions: Array = actions.get("cheat_actions", []) if typeof(actions.get("cheat_actions", [])) == TYPE_ARRAY else []
		combined_actions.append_array(cheat_actions)
		var stake_floor := maxi(1, int(actions.get("stake_floor", 1)))
		var stake_ceiling := maxi(stake_floor, int(actions.get("stake_ceiling", stake_floor)))
		var stake := clampi(10, stake_floor, stake_ceiling)
		for action_value in combined_actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_value
			if not bool(action.get("enabled", true)):
				continue
			var action_id := str(action.get("id", "")).strip_edges()
			if action_id.is_empty():
				continue
			var rng := run_state.create_rng("sb3_fuzz_%s_%s_%02d" % [game_id, action_id, action_index])
			var result: Dictionary = game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, {})
			if bool(result.get("ok", false)):
				GameModule.apply_result(run_state, result, rng)
				return true
	return false


func _save_load_fuzz_play_slot_bonus(game: GameModule, run_state: RunState, action_index: int) -> bool:
	var machine: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if machine.is_empty() or not SlotMachineStateScript.active_bonus_incomplete(machine):
		return false
	var active: Dictionary = machine.get("active_bonus", {}) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	var family := str(active.get("family", machine.get("type_id", "")))
	var mode := str(active.get("mode", ""))
	var candidates := ["slot_bonus_launch"]
	if family == "pinball":
		match action_index % 3:
			1:
				candidates = ["slot_bonus_left", "slot_bonus_launch"]
			2:
				candidates = ["slot_bonus_right", "slot_bonus_launch"]
			_:
				candidates = ["slot_bonus_launch"]
		candidates.append("slot_bonus_watchdog")
	elif family == "buffalo" and mode == "wheel":
		candidates = ["slot_bonus_right", "slot_bonus_launch"]
	var ui_state := {
		"surface_time_msec": 4000 + action_index * 500,
		"drunk_scaled_surface_time_msec": 4000 + action_index * 500,
	}
	if family == "pinball":
		ui_state = {}
	for action_id in candidates:
		var rng := run_state.create_rng("sb3_fuzz_slot_bonus_%s_%02d" % [action_id, action_index])
		var result: Dictionary = game.resolve_with_context(str(action_id), 0, run_state, run_state.current_environment, rng, ui_state)
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
			return true
	return false


func _save_load_checkpoint(library: ContentLibrary, run_state: RunState, label: String, assert_continuation: bool, failures: Array) -> RunState:
	var before_signature := _save_load_action_signature(library, run_state, failures)
	var before_snapshot := _save_load_canonical_run_snapshot(run_state.to_dict())
	var before_json := JSON.stringify(before_snapshot)
	var parsed: Variant = JSON.parse_string(before_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("SB.3 %s RunState snapshot did not JSON-parse." % label)
		return null
	var restored: RunState = RunStateScript.new()
	restored.from_dict(parsed as Dictionary)
	var after_snapshot := _save_load_canonical_run_snapshot(restored.to_dict())
	var after_json := JSON.stringify(after_snapshot)
	if after_json != before_json:
		failures.append("SB.3 %s RunState to_dict -> from_dict -> to_dict was not byte-identical at %s." % [label, _save_load_first_mismatch(before_snapshot, after_snapshot)])
	var second: RunState = RunStateScript.new()
	second.from_dict(after_snapshot)
	if JSON.stringify(_save_load_canonical_run_snapshot(second.to_dict())) != after_json:
		failures.append("SB.3 %s RunState normalization was not idempotent on the second load." % label)
	var after_signature := _save_load_action_signature(library, restored, failures)
	if JSON.stringify(before_signature) != JSON.stringify(after_signature):
		failures.append("SB.3 %s legal action signature changed after save/load." % label)
	if assert_continuation and not restored.is_terminal():
		var continuation: RunState = RunStateScript.new()
		continuation.from_dict(restored.to_dict())
		var continuation_generator: RunGenerator = RunGeneratorScript.new(library)
		for step in range(SAVE_LOAD_FUZZ_CONTINUATION_STEPS):
			if continuation.is_terminal():
				break
			if not _save_load_fuzz_drive_action(library, continuation_generator, continuation, step, "%s/continue_%02d" % [label, step], failures):
				failures.append("SB.3 %s restored clone could not continue for step %d." % [label, step])
				break
	return restored


func _save_load_canonical_run_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = _save_load_canonical_value(snapshot) as Dictionary
	var pending_events: Array = result.get("pending_triggered_events", []) if typeof(result.get("pending_triggered_events", [])) == TYPE_ARRAY else []
	if not pending_events.is_empty():
		result["pending_triggered_events"] = _save_load_canonical_triggered_event_entries(pending_events)
	var active_event: Dictionary = result.get("active_triggered_event", {}) if typeof(result.get("active_triggered_event", {})) == TYPE_DICTIONARY else {}
	if not active_event.is_empty() and not active_event.has("active"):
		active_event["active"] = true
		result["active_triggered_event"] = active_event
	var environment: Dictionary = result.get("current_environment", {}) if typeof(result.get("current_environment", {})) == TYPE_DICTIONARY else {}
	var suspicion: Dictionary = result.get("suspicion", {}) if typeof(result.get("suspicion", {})) == TYPE_DICTIONARY else {}
	if environment.is_empty() or suspicion.is_empty():
		return result
	var location_id := _save_load_suspicion_location_id(environment)
	if location_id.is_empty():
		return result
	var local_levels: Dictionary = suspicion.get("local_levels", {}) if typeof(suspicion.get("local_levels", {})) == TYPE_DICTIONARY else {}
	if not local_levels.has(location_id):
		local_levels[location_id] = clampi(int(suspicion.get("level", 0)), 0, 100)
		suspicion["local_levels"] = local_levels
		result["suspicion"] = suspicion
	return result


func _save_load_canonical_triggered_event_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("event_id", entry.get("id", ""))).strip_edges().is_empty():
			continue
		if not entry.has("active"):
			entry["active"] = false
		result.append(entry)
	return result


func _save_load_suspicion_location_id(environment: Dictionary) -> String:
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if not archetype_id.is_empty():
		return archetype_id
	var environment_id := str(environment.get("id", "")).strip_edges()
	var separator := environment_id.rfind("_")
	if separator > 0 and separator < environment_id.length() - 1:
		var suffix := environment_id.substr(separator + 1)
		if suffix.is_valid_int():
			return environment_id.substr(0, separator)
	return environment_id


func _save_load_canonical_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var result: Dictionary = {}
			for key in source.keys():
				result[key] = _save_load_canonical_value(source[key])
			return result
		TYPE_ARRAY:
			var source_array: Array = value
			var result_array: Array = []
			for entry in source_array:
				result_array.append(_save_load_canonical_value(entry))
			return result_array
		TYPE_FLOAT:
			return _save_load_canonical_float(float(value))
		TYPE_VECTOR2:
			var point: Vector2 = value
			return {
				"x": _save_load_canonical_float(point.x),
				"y": _save_load_canonical_float(point.y),
			}
		TYPE_VECTOR2I:
			var point_i: Vector2i = value
			return {
				"x": point_i.x,
				"y": point_i.y,
			}
		TYPE_RECT2:
			var rect: Rect2 = value
			return {
				"x": _save_load_canonical_float(rect.position.x),
				"y": _save_load_canonical_float(rect.position.y),
				"w": _save_load_canonical_float(rect.size.x),
				"h": _save_load_canonical_float(rect.size.y),
			}
		TYPE_RECT2I:
			var rect_i: Rect2i = value
			return {
				"x": rect_i.position.x,
				"y": rect_i.position.y,
				"w": rect_i.size.x,
				"h": rect_i.size.y,
			}
		_:
			return value


func _save_load_canonical_float(value: float) -> Variant:
	var rounded_integer: float = round(value)
	if absf(value - rounded_integer) <= SAVE_LOAD_CANONICAL_INTEGER_EPSILON:
		return int(rounded_integer)
	return snappedf(value, SAVE_LOAD_CANONICAL_FLOAT_STEP)


func _save_load_action_signature(library: ContentLibrary, run_state: RunState, failures: Array) -> Dictionary:
	var signature := {
		"terminal": run_state.run_status if run_state != null else "missing",
		"environment_id": "",
		"world_node_id": "",
		"games": [],
		"travel_targets": [],
		"pending_triggered_count": 0,
		"active_triggered_event": "",
	}
	if run_state == null:
		return signature
	signature["environment_id"] = str(run_state.current_environment.get("id", ""))
	signature["world_node_id"] = run_state.current_world_node_id()
	signature["pending_triggered_count"] = run_state.pending_triggered_events.size()
	signature["active_triggered_event"] = str(run_state.active_triggered_event.get("event_id", ""))
	if run_state.has_world_map():
		signature["travel_targets"] = _string_array(WorldMapScript.travel_target_ids(run_state.world_map, run_state.current_world_node_id()))
	var game_signatures: Array = []
	for game_id_value in _string_array(run_state.current_environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var actions: Dictionary = game.actions(run_state, run_state.current_environment)
		game_signatures.append({
			"id": game_id,
			"stake_floor": int(actions.get("stake_floor", 0)),
			"stake_ceiling": int(actions.get("stake_ceiling", 0)),
			"legal": _save_load_action_id_signature(actions.get("legal_actions", [])),
			"cheat": _save_load_action_id_signature(actions.get("cheat_actions", [])),
		})
	signature["games"] = game_signatures
	return signature


func _save_load_action_id_signature(actions_value: Variant) -> Array:
	var result: Array = []
	if typeof(actions_value) != TYPE_ARRAY:
		return result
	for action_value in actions_value:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		result.append({
			"id": str(action.get("id", "")),
			"enabled": bool(action.get("enabled", true)),
			"kind": str(action.get("kind", action.get("action_kind", ""))),
			"cost": int(action.get("cost", action.get("stake", 0))),
		})
	return result


func _save_load_first_mismatch(expected: Variant, actual: Variant, path: String = "$") -> String:
	if typeof(expected) != typeof(actual):
		return "%s type %d != %d" % [path, typeof(expected), typeof(actual)]
	if typeof(expected) == TYPE_DICTIONARY:
		var expected_dict: Dictionary = expected
		var actual_dict: Dictionary = actual
		for key in expected_dict.keys():
			if not actual_dict.has(key):
				return "%s.%s missing" % [path, str(key)]
			var nested := _save_load_first_mismatch(expected_dict[key], actual_dict[key], "%s.%s" % [path, str(key)])
			if not nested.is_empty():
				return nested
		for key in actual_dict.keys():
			if not expected_dict.has(key):
				return "%s.%s added" % [path, str(key)]
		return ""
	if typeof(expected) == TYPE_ARRAY:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return "%s size %d != %d" % [path, expected_array.size(), actual_array.size()]
		for index in range(expected_array.size()):
			var nested := _save_load_first_mismatch(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	if expected != actual:
		return "%s %s != %s" % [path, str(expected), str(actual)]
	return ""


func _check_save_load_targeted_midstates(library: ContentLibrary, failures: Array) -> void:
	var slot_game: GameModule = _slot_game(library, failures)
	if slot_game != null:
		_check_save_load_slot_midstates(library, slot_game, failures)
	_check_save_load_skill_challenge_midstates(library, failures)
	_check_save_load_world_event_lender_midstates(library, failures)


func _check_save_load_slot_midstates(library: ContentLibrary, slot_game: GameModule, failures: Array) -> void:
	var definition := library.game("slot")
	var pinball = SlotFamilyPinballScript.new()
	var pinball_run: RunState = _slot_run_state("SB3-PINBALL-LIVE", 100000)
	var pinball_environment: Dictionary = _slot_environment()
	var pinball_machine: Dictionary = _slot_machine(definition, pinball_run, "pinball", "classic_3_reel", "standard", "plain")
	pinball_machine["active_bonus"] = pinball.open_feature(pinball_machine, 10, pinball_run.create_rng("sb3_pinball_open"), definition)
	_slot_store_machine(pinball_run, pinball_environment, pinball_machine)
	var launch_rng := pinball_run.create_rng("sb3_pinball_launch")
	var launch_result: Dictionary = slot_game.resolve_with_context("slot_bonus_launch", 0, pinball_run, pinball_environment, launch_rng, {"surface_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000})
	if bool(launch_result.get("ok", false)):
		GameModule.apply_result(pinball_run, launch_result, launch_rng)
	_save_load_checkpoint(library, _save_load_canonical_run(pinball_run), "target/pinball_live_balls", true, failures)

	var buffalo = SlotFamilyBuffaloScript.new()
	var buffalo_run: RunState = _slot_run_state("SB3-BUFFALO-HOLD", 100000)
	var buffalo_environment: Dictionary = _slot_environment()
	var buffalo_machine: Dictionary = _slot_machine(definition, buffalo_run, "buffalo", "video_feature", "standard", "plain")
	buffalo_machine["active_bonus"] = buffalo.open_feature(buffalo_machine, {"classification": "hold_and_spin"}, 10, buffalo_run.create_rng("sb3_buffalo_hold_open"), definition)
	_slot_store_machine(buffalo_run, buffalo_environment, buffalo_machine)
	_save_load_checkpoint(library, _save_load_canonical_run(buffalo_run), "target/buffalo_hold_and_spin", true, failures)

	var nudge_sample := _slot_spin_until_classification(definition, "pinball", "line_5x3", "near_miss", "SB3-NUDGE-PENDING", failures)
	if not nudge_sample.is_empty():
		var nudge_run: RunState = nudge_sample.get("run_state", null)
		var nudge_environment: Dictionary = _slot_environment()
		_slot_store_machine(nudge_run, nudge_environment, _slot_dict(nudge_sample.get("machine", {})))
		_save_load_checkpoint(library, _save_load_canonical_run(nudge_run), "target/nudge_offer_pending", true, failures)

	var autoplay_run: RunState = _slot_run_state("SB3-SLOT-AUTOPLAY", 100000)
	var autoplay_environment: Dictionary = _slot_environment()
	var autoplay_machine: Dictionary = _slot_machine(definition, autoplay_run, "pinball", "line_5x3", "standard", "plain")
	autoplay_machine["slot_autoplay_active"] = true
	autoplay_machine["slot_autoplay_next_msec"] = 1500
	_slot_store_machine(autoplay_run, autoplay_environment, autoplay_machine)
	_save_load_checkpoint(library, _save_load_canonical_run(autoplay_run), "target/slot_autoplay_active", true, failures)


func _check_save_load_skill_challenge_midstates(library: ContentLibrary, failures: Array) -> void:
	var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	if blackjack != null:
		var blackjack_run: RunState = _mutation_firewall_game_run_state(library, blackjack, "blackjack")
		var deal_command: Dictionary = blackjack.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, blackjack_run, blackjack_run.current_environment)
		var count_command: Dictionary = blackjack.surface_action_command("blackjack_count_toggle", 0, false, deal_command.get("ui_state", {}), blackjack_run, blackjack_run.current_environment)
		var count_ui: Dictionary = count_command.get("ui_state", {}) if typeof(count_command.get("ui_state", {})) == TYPE_DICTIONARY else {}
		if _copy_dict(count_ui.get("count_challenge", {})).is_empty():
			failures.append("SB.3 blackjack count mid-state fixture did not start count_challenge.")
		_save_load_checkpoint(library, _save_load_canonical_run(blackjack_run), "target/blackjack_count_midstep", true, failures)

	var video_poker: GameModule = _load_surface_contract_game(library, "video_poker", failures)
	if video_poker != null:
		var poker_fixture := _video_poker_holdout_item_fixture(video_poker, "")
		var poker_run := poker_fixture.get("run_state", null) as RunState
		if poker_run == null or _copy_dict(poker_fixture.get("challenge", {})).is_empty():
			failures.append("SB.3 video poker holdout mid-state fixture did not start holdout_challenge.")
		else:
			poker_run.current_environment["game_ids"] = ["video_poker"]
			_save_load_checkpoint(library, _save_load_canonical_run(poker_run), "target/video_poker_holdout_midstep", true, failures)

	var bar_dice: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if bar_dice != null:
		var dice_fixture := _bar_dice_controlled_roll_item_fixture(bar_dice, "")
		var dice_run := dice_fixture.get("run_state", null) as RunState
		if dice_run == null or _copy_dict(dice_fixture.get("challenge", {})).is_empty():
			failures.append("SB.3 bar dice controlled-roll mid-state fixture did not start controlled_roll.")
		else:
			_save_load_checkpoint(library, _save_load_canonical_run(dice_run), "target/bar_dice_controlled_roll_midstep", true, failures)

	var roulette: GameModule = _load_surface_contract_game(library, "roulette", failures)
	if roulette != null:
		var roulette_fixture := _roulette_past_post_item_fixture(roulette, library, "")
		var roulette_run := roulette_fixture.get("run_state", null) as RunState
		if roulette_run == null or _copy_dict(roulette_fixture.get("challenge", {})).is_empty():
			failures.append("SB.3 roulette past-post mid-state fixture did not start past_post_challenge.")
		else:
			_save_load_checkpoint(library, _save_load_canonical_run(roulette_run), "target/roulette_past_post_midstep", true, failures)

	var baccarat: GameModule = _load_surface_contract_game(library, "baccarat", failures)
	if baccarat != null:
		var baccarat_fixture := _baccarat_edge_sort_item_fixture(baccarat, "")
		var baccarat_run := baccarat_fixture.get("run_state", null) as RunState
		if baccarat_run == null or _copy_dict(baccarat_fixture.get("challenge", {})).is_empty():
			failures.append("SB.3 baccarat edge-sort mid-state fixture did not start edge_sort_challenge.")
		else:
			_save_load_checkpoint(library, _save_load_canonical_run(baccarat_run), "target/baccarat_edge_sort_midstep", true, failures)


func _check_save_load_world_event_lender_midstates(library: ContentLibrary, failures: Array) -> void:
	var world_run: RunState = RunStateScript.new()
	world_run.start_new("SB3-WORLD-MAP-OPEN", RunState.custom_challenge("sb3_world", "SB3-WORLD-MAP-OPEN", {"starting_bankroll": 3000}))
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(world_run)
	WorldMapScript.snapshot(world_run.world_map, world_run.current_world_node_id())
	_save_load_checkpoint(library, world_run, "target/world_map_open_snapshot", true, failures)

	var travel_lock_run: RunState = RunStateScript.new()
	travel_lock_run.start_new("SB3-TRAVEL-LOCK", RunState.custom_challenge("sb3_travel_lock", "SB3-TRAVEL-LOCK", {"starting_bankroll": 3000}))
	generator.next_environment(travel_lock_run)
	generator.next_environment(travel_lock_run, "gas_station_casino")
	travel_lock_run.current_environment["travel_locked_actions"] = 3
	travel_lock_run.current_environment["travel_lock_remaining"] = 2
	_save_load_checkpoint(library, travel_lock_run, "target/travel_lock_active", true, failures)

	var event_run: RunState = RunStateScript.new()
	event_run.start_new("SB3-TRIGGERED-EVENT")
	generator.next_environment(event_run)
	var event_id := _save_load_first_event_id(library)
	if event_id.is_empty() or not event_run.enqueue_triggered_event(event_id, "sb3_fixture", {"trigger": "save_load"}):
		failures.append("SB.3 triggered-event queue fixture could not enqueue an event.")
	else:
		_save_load_checkpoint(library, event_run, "target/triggered_event_pending", true, failures)
		event_run.begin_triggered_event_resolution(event_run.next_pending_triggered_event())
		_save_load_checkpoint(library, event_run, "target/triggered_event_active", true, failures)

	var lender_definition := _first_definition(library.lenders)
	if lender_definition.is_empty():
		failures.append("SB.3 lender mid-schedule fixture could not find lender content.")
	else:
		var lender_run: RunState = RunStateScript.new()
		lender_run.start_new("SB3-LENDER-MID", RunState.custom_challenge("sb3_lender", "SB3-LENDER-MID", {"starting_bankroll": 500}))
		lender_run.set_environment({
			"id": "sb3_lender_room",
			"display_name": "SB3 Lender Room",
			"kind": "casino",
			"archetype_id": "sb3_lender_fixture",
			"game_ids": ["video_poker"],
			"game_states": {},
			"economic_profile": {"stake_floor": 1, "stake_ceiling": 20},
			"security_profile": {},
			"lender_hooks": [str(lender_definition.get("id", ""))],
			"layout": {},
		})
		var video_poker_game: GameModule = _load_surface_contract_game(library, "video_poker", failures)
		if video_poker_game != null:
			var game_states := _copy_dict(lender_run.current_environment.get("game_states", {}))
			game_states["video_poker"] = video_poker_game.generate_environment_state(lender_run, lender_run.current_environment, lender_run.create_rng("sb3_lender_video_poker_state"))
			lender_run.current_environment["game_states"] = game_states
		var resolver: RunActionService = RunActionServiceScript.new()
		resolver.setup(library, lender_run)
		var lender_result := resolver.use_hook("lender", str(lender_definition.get("id", "")))
		if not bool(lender_result.get("ok", false)) or lender_run.debt.is_empty():
			failures.append("SB.3 lender mid-schedule fixture could not open debt.")
		else:
			lender_run.advance_environment_turns(1)
			_save_load_checkpoint(library, lender_run, "target/lender_mid_schedule", true, failures)

	var challenge_run: RunState = RunStateScript.new()
	challenge_run.start_new("SB3-CHALLENGE-MOD", RunState.custom_challenge("sb3_mid_modifier", "SB3-CHALLENGE-MOD", {
		"starting_bankroll": 777,
		"starting_heat": 12,
		"baseline_luck_delta": 2,
		"local_heat_turn_decay_interval_delta": -1,
	}))
	generator.next_environment(challenge_run)
	challenge_run.advance_environment_turns(2)
	_save_load_checkpoint(library, challenge_run, "target/challenge_mid_modifier", true, failures)


func _save_load_first_event_id(library: ContentLibrary) -> String:
	if not library.event("family_loan").is_empty():
		return "family_loan"
	var definition := _first_definition(library.events)
	return str(definition.get("id", ""))


func _save_load_canonical_run(run_state: RunState) -> RunState:
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	return restored


func _check_save_load_030_compat_fixture(library: ContentLibrary, failures: Array) -> void:
	if not FileAccess.file_exists(SAVE_COMPAT_030_FIXTURE_PATH):
		failures.append("SB.3 missing 0.3.0 save compatibility fixture: %s." % SAVE_COMPAT_030_FIXTURE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_COMPAT_030_FIXTURE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.0 save compatibility fixture did not parse as a dictionary.")
		return
	var payload: Dictionary = parsed
	var save_service: SaveService = SaveServiceScript.new()
	var run_data_value: Variant = save_service.call("_run_data_from_payload", payload)
	if typeof(run_data_value) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.0 save compatibility fixture did not produce RunState data.")
		return
	var run_data: Dictionary = run_data_value
	if not run_data.has("legacy_unknown_root"):
		failures.append("SB.3 0.3.0 save fixture no longer covers unknown root-key tolerance.")
	if int(run_data.get("act", 0)) != 1:
		failures.append("SB.3 0.3.0 save compatibility did not add the Act 1 marker.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_data)
	var normalized := restored.to_dict()
	if int(restored.act_index) != 1 or int(normalized.get("act", 0)) != 1:
		failures.append("SB.3 0.3.0 markerless save did not load as Act 1.")
	if normalized.has("legacy_unknown_root"):
		failures.append("SB.3 0.3.0 save compatibility kept an unknown RunState root key.")
	var second: RunState = RunStateScript.new()
	second.from_dict(normalized)
	if JSON.stringify(second.to_dict()) != JSON.stringify(normalized):
		failures.append("SB.3 0.3.0 save compatibility fixture was not idempotent after normalization.")
	_save_load_checkpoint(library, restored, "compat/0_3_0_fixture", true, failures)


func _check_save_load_033_compat_fixture(library: ContentLibrary, failures: Array) -> void:
	if not FileAccess.file_exists(SAVE_COMPAT_033_FIXTURE_PATH):
		failures.append("SB.3 missing 0.3.3 save compatibility fixture: %s." % SAVE_COMPAT_033_FIXTURE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_COMPAT_033_FIXTURE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.3 save compatibility fixture did not parse as a dictionary.")
		return
	var payload: Dictionary = parsed
	var source_run_data: Dictionary = payload.get("run_state", {}) if typeof(payload.get("run_state", {})) == TYPE_DICTIONARY else {}
	for absent_field in ["game_clock_minutes", "closing_time_state", "act", "act_index", "home_state", "pending_bags"]:
		if source_run_data.has(absent_field):
			failures.append("SB.3 0.3.3 fixture must stay pre-v0.4 for field %s." % absent_field)
	var save_service: SaveService = SaveServiceScript.new()
	var run_data_value: Variant = save_service.call("_run_data_from_payload", payload)
	if typeof(run_data_value) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.3 save compatibility fixture did not produce RunState data.")
		return
	var run_data: Dictionary = run_data_value
	if not run_data.has("legacy_unknown_033_root"):
		failures.append("SB.3 0.3.3 save fixture no longer covers unknown root-key tolerance.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_data)
	var normalized := restored.to_dict()
	if normalized.has("legacy_unknown_033_root"):
		failures.append("SB.3 0.3.3 save compatibility kept an unknown RunState root key.")
	if int(normalized.get("act", 0)) != 1 or int(restored.act_index) != 1:
		failures.append("SB.3 0.3.3 markerless save did not normalize to Act 1.")
	if int(normalized.get("game_clock_minutes", -1)) != RunState.GAME_CLOCK_START_MINUTE:
		failures.append("SB.3 0.3.3 save did not normalize the new game clock default.")
	if typeof(normalized.get("closing_time_state", null)) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.3 save did not normalize closing time state.")
	if typeof(normalized.get("home_state", null)) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.3 save did not normalize home state.")
	var bags: Array = normalized.get("pending_bags", []) if typeof(normalized.get("pending_bags", [])) == TYPE_ARRAY else []
	if bags.size() != 1:
		failures.append("SB.3 0.3.3 save did not migrate the legacy pending_bag field.")
	var talk_entry: Dictionary = restored.next_pending_talk_event()
	if str(talk_entry.get("event_id", "")) != "suspicious_patron" or str(talk_entry.get("presentation", "")) != "talk":
		failures.append("SB.3 0.3.3 save did not preserve the pending talk event.")
	if typeof(talk_entry.get("speaker", null)) != TYPE_DICTIONARY or typeof(talk_entry.get("timing", null)) != TYPE_DICTIONARY:
		failures.append("SB.3 0.3.3 save did not normalize talk speaker/timing fields.")
	var second: RunState = RunStateScript.new()
	second.from_dict(normalized)
	if JSON.stringify(second.to_dict()) != JSON.stringify(normalized):
		failures.append("SB.3 0.3.3 save compatibility fixture was not idempotent after normalization.")
	_save_load_checkpoint(library, restored, "compat/0_3_3_fixture", true, failures)


# Verifies real-time gameplay logic is derived from absolute milliseconds, not frame counts.
func _check_locked_logic_rate_foundation(library: ContentLibrary, failures: Array) -> void:
	var absorption_30: Dictionary = _locked_rate_absorption_fixture(33)
	var absorption_144: Dictionary = _locked_rate_absorption_fixture(7)
	if JSON.stringify(absorption_30) != JSON.stringify(absorption_144):
		failures.append("Alcohol absorption produced different logic events at 30fps and 144fps simulations.")

	var bar_30: Dictionary = _locked_rate_bar_dice_fixture(library, 33, failures)
	var bar_144: Dictionary = _locked_rate_bar_dice_fixture(library, 7, failures)
	if not bar_30.is_empty() and not bar_144.is_empty() and JSON.stringify(bar_30) != JSON.stringify(bar_144):
		failures.append("Bar Dice controlled-roll timing produced different outcomes at 30fps and 144fps simulations.")


func _locked_rate_absorption_fixture(step_msec: int) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("LOCKED-RATE-ALCOHOL")
	run_state.pending_drunk_absorption = [{
		"remaining": 6,
		"interval_msec": RunState.DRUNK_ABSORPTION_INTERVAL_MSEC,
		"next_msec": RunState.DRUNK_ABSORPTION_INTERVAL_MSEC,
		"queued_msec": 0,
	}]
	var event_times := [
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC,
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 2,
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 3,
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 4,
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 5,
		RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 6,
	]
	var events: Array = []
	for time_msec_value in _locked_rate_time_points(0, RunState.DRUNK_ABSORPTION_INTERVAL_MSEC * 6, step_msec, event_times):
		var time_msec := int(time_msec_value)
		var update: Dictionary = run_state.update_drunk_absorption(time_msec)
		var applied := int(update.get("applied", 0))
		if applied > 0:
			events.append({
				"msec": time_msec,
				"applied": applied,
				"drunk": run_state.drunk_level,
				"pending": run_state.pending_drunk_absorption_amount(),
			})
	return {
		"events": events,
		"drunk": run_state.drunk_level,
		"pending": run_state.pending_drunk_absorption_amount(),
	}


func _locked_rate_bar_dice_fixture(library: ContentLibrary, step_msec: int, failures: Array) -> Dictionary:
	var game: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if game == null:
		return {}
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("LOCKED-RATE-BAR-DICE")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	var active_environment: Dictionary = run_state.current_environment
	var start_msec := 12000
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {"surface_time_msec": start_msec}, run_state, active_environment)
	if not bool(roll_command.get("handled", false)):
		failures.append("Locked-rate Bar Dice fixture could not start a roll.")
		return {}
	var roll_ui: Dictionary = roll_command.get("ui_state", {"surface_time_msec": start_msec})
	roll_ui["surface_time_msec"] = start_msec
	var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, roll_ui, run_state, active_environment)
	if not bool(load_command.get("handled", false)):
		failures.append("Locked-rate Bar Dice fixture could not arm loaded toss.")
		return {}
	var load_ui: Dictionary = load_command.get("ui_state", roll_ui)
	var challenge: Dictionary = load_ui.get("controlled_roll", {}) if typeof(load_ui.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	if challenge.is_empty():
		failures.append("Locked-rate Bar Dice fixture did not create a controlled-roll challenge.")
		return {}
	var period := maxi(1, int(challenge.get("meter_period_msec", 1300)))
	var input_msec := int(challenge.get("target_msec", start_msec))
	while input_msec < start_msec:
		input_msec += period
	var surface_samples := 0
	for time_msec_value in _locked_rate_time_points(start_msec, input_msec, step_msec, [input_msec]):
		var sample_ui: Dictionary = load_ui.duplicate(true)
		sample_ui["surface_time_msec"] = int(time_msec_value)
		var surface: Dictionary = game.surface_state(run_state, active_environment, sample_ui)
		if str(surface.get("surface_renderer", "")) != "dice_table":
			failures.append("Locked-rate Bar Dice fixture sampled the wrong renderer.")
			return {}
		surface_samples += 1
	var release_ui: Dictionary = load_ui.duplicate(true)
	release_ui["surface_time_msec"] = input_msec
	release_ui["controlled_roll_input_msec"] = input_msec
	var release_command: Dictionary = game.surface_action_command("bar_dice_release", 0, false, release_ui, run_state, active_environment)
	if not bool(release_command.get("handled", false)):
		failures.append("Locked-rate Bar Dice fixture could not release loaded toss.")
		return {}
	var resolved_ui: Dictionary = release_command.get("ui_state", release_ui)
	var controlled: Dictionary = resolved_ui.get("controlled_roll", {}) if typeof(resolved_ui.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	var result: Dictionary = game.resolve_with_context("loaded_toss", 10, run_state, active_environment, run_state.create_rng("locked_rate_bar_dice_resolve"), resolved_ui)
	if not bool(result.get("ok", false)):
		failures.append("Locked-rate Bar Dice fixture did not resolve loaded toss.")
		return {}
	return {
		"target_msec": int(challenge.get("target_msec", 0)),
		"input_msec": int(controlled.get("input_msec", 0)),
		"skill_grade": str(controlled.get("skill_grade", "")),
		"skill_margin_msec": int(controlled.get("skill_margin_msec", 0)),
		"skill_accuracy": int(controlled.get("skill_accuracy", 0)),
		"desired_face": int(controlled.get("desired_face", 0)),
		"desired_die_index": int(controlled.get("desired_die_index", -1)),
		"result_grade": str(result.get("bar_dice_controlled_roll_grade", "")),
		"result_margin_msec": int(result.get("bar_dice_controlled_roll_margin_msec", 0)),
		"result_applied": bool(result.get("bar_dice_controlled_roll_applied", false)),
		"player_dice": (result.get("bar_dice_player_dice", []) as Array).duplicate(),
		"outcome": str(result.get("bar_dice_outcome", "")),
		"bankroll_delta": int(result.get("bankroll_delta", 0)),
		"suspicion_delta": int(result.get("suspicion_delta", 0)),
		"surface_samples": surface_samples > 0,
	}


func _locked_rate_time_points(start_msec: int, end_msec: int, step_msec: int, scripted_times: Array) -> Array:
	var point_map := {}
	var cursor := start_msec
	var safe_end := maxi(start_msec, end_msec)
	var safe_step := maxi(1, step_msec)
	while cursor < safe_end:
		cursor = mini(safe_end, cursor + safe_step)
		point_map[str(cursor)] = true
	for value in scripted_times:
		var scripted_msec := clampi(int(value), start_msec, safe_end)
		point_map[str(scripted_msec)] = true
	var points: Array = []
	for key in point_map.keys():
		points.append(int(key))
	points.sort()
	return points


# Ensures RunState serialization stays inside simulation domains.
func _check_run_state_snapshot_keys(snapshot: Dictionary, failures: Array) -> void:
	var required_keys := [
		"seed_text",
		"seed_value",
		"rng_seed",
		"rng_state",
		"challenge_config",
		"bankroll",
		"economic_state",
		"inventory",
		"active_item_id",
		"debt",
		"suspicion",
		"current_environment",
		"world_map",
		"environment_history",
		"unlocked_travel",
		"narrative_flags",
		"story_log",
		"run_status",
		"run_spending_score",
	]
	for key in required_keys:
		if not snapshot.has(key):
			failures.append("RunState snapshot is missing required key: %s." % key)
	var forbidden_keys := [
		"ui_selection",
		"focus",
		"hover",
		"overlay_state",
		"button_metadata",
		"transient_scene_cache",
		"profile_inventory",
		"art_layout_state",
		"game_state",
	]
	for key in forbidden_keys:
		if snapshot.has(key):
			failures.append("RunState snapshot contains forbidden UI/profile key: %s." % key)


# Compares scalar values in foundation checks.
func _assert_equal(actual: Variant, expected: Variant, message: String, failures: Array) -> void:
	if actual != expected:
		failures.append(message)


# Compares dictionaries and arrays in foundation checks.
func _assert_json_equal(actual: Variant, expected: Variant, message: String, failures: Array) -> void:
	if JSON.stringify(actual) != JSON.stringify(expected):
		failures.append(message)


# Checks core contracts with fixture content.
func _check_contracts(library: ContentLibrary, failures: Array) -> void:
	var custom_challenge := RunState.custom_challenge("foundation_contracts", "FOUNDATION-CONTRACT-SEED", {"fixture": true})
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("FOUNDATION-CONTRACT-SEED", custom_challenge)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment = generator.next_environment(run_state)

	if environment.lender_hooks.is_empty():
		failures.append("Environment contract did not include debt/lender hooks.")
	if environment.suspicion_cues.is_empty():
		failures.append("Environment contract did not include behavior-first suspicion cues.")
	if environment.local_narrative_flags.is_empty():
		failures.append("Environment contract did not include local narrative flags.")
	var environment_data: Dictionary = environment.to_dict()
	environment_data["game_ids"].append("mutated_game")
	if environment.game_ids.has("mutated_game"):
		failures.append("EnvironmentInstance.to_dict leaked mutable arrays.")
	var restored_environment := EnvironmentInstance.from_dict(environment.to_dict())
	if JSON.stringify(restored_environment.to_dict()) != JSON.stringify(environment.to_dict()):
		failures.append("EnvironmentInstance.from_dict did not preserve saveable data.")

	var game := GameModule.new()
	game.setup(library.game("fixture_game"))
	var action_presentation: Dictionary = game.actions(run_state, environment.to_dict())
	if action_presentation.get("legal_actions", []).is_empty():
		failures.append("Game module contract did not present legal actions.")
	if action_presentation.get("cheat_actions", []).is_empty():
		failures.append("Game module contract did not present cheat actions.")
	var mutated_actions: Array = action_presentation.get("legal_actions", [])
	mutated_actions[0]["id"] = "mutated_action"
	if game.legal_actions(run_state, environment.to_dict())[0].get("id", "") == "mutated_action":
		failures.append("GameModule action presentation leaked mutable definitions.")
	var legal_before := _run_state_result_snapshot(run_state)
	var rng := run_state.create_rng()
	var unresolved_result: Dictionary = game.resolve("legal_fixture", 1, run_state, environment.to_dict(), rng)
	if unresolved_result.get("game_id", "") != "fixture_game":
		failures.append("Base game module did not return a structured result.")
	_check_action_result_shape(unresolved_result, "legal", failures)
	_check_action_result_applied(legal_before, run_state, unresolved_result, "legal contract result", failures)
	var cheat_before := _run_state_result_snapshot(run_state)
	var cheat_result := game.resolve("cheat_fixture", 1, run_state, environment.to_dict(), run_state.create_rng())
	_check_action_result_shape(cheat_result, "cheat", failures)
	_check_action_result_applied(cheat_before, run_state, cheat_result, "cheat contract result", failures)
	var invalid_bankroll := run_state.bankroll
	var invalid_result := game.resolve("missing_fixture", 1, run_state, environment.to_dict(), rng)
	if bool(invalid_result.get("ok", true)):
		failures.append("Game module accepted an unavailable action.")
	if run_state.bankroll != invalid_bankroll:
		failures.append("Unavailable game action mutated RunState.")

	var event := EventModule.new()
	event.setup(library.event("fixture_event"))
	if not event.can_trigger(run_state, environment.to_dict()):
		failures.append("Event module contract did not trigger from fixture state.")
	var event_before := _run_state_result_snapshot(run_state)
	var event_result := event.resolve(run_state, environment.to_dict(), "raise_heat")
	_check_event_result_delta_shape(event_result, failures)
	_check_event_result_applied(event_before, run_state, event_result, "fixture event result", failures)
	if not bool(run_state.narrative_flags.get("fixture_event_flag", false)):
		failures.append("Event module did not apply flag consequences.")

	var item_effect := ItemEffect.new()
