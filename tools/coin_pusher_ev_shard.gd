extends SceneTree

const CoinPusherGame := preload("res://scripts/games/coin_pusher.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const LiveSession := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")
const Ridge := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")
const Vault := preload("res://scripts/games/coin_pusher/vault_drop.gd")

const DEFAULT_ACCEPTED := 25000
const POLICY_TICKS := 20
const PHASE_BIN_COUNT := 12
const RAIL_FRACTIONS := [0, 250, 500, 750, 1000]
const PROGRESS_ATTEMPT_INTERVAL := 256
const MAX_CONSECUTIVE_REFUSALS_WITHOUT_ACCEPT := 4096

var machine_id := "quarter_falls"
var shard_index := 0
var accepted_target := DEFAULT_ACCEPTED
var out_path := "res://.tmp/coin_pusher_ev_shard.json"
var gutter_x_override := -1
var runner_provenance := {}
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--machine="):
			machine_id = argument.trim_prefix("--machine=").strip_edges()
		elif argument.begins_with("--shard="):
			shard_index = int(argument.trim_prefix("--shard="))
		elif argument.begins_with("--accepted="):
			accepted_target = maxi(1, int(argument.trim_prefix("--accepted=")))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=").strip_edges()
		elif argument.begins_with("--gutter-x="):
			gutter_x_override = int(argument.trim_prefix("--gutter-x="))
		elif argument.begins_with("--runner-provenance-base64="):
			var encoded := argument.trim_prefix("--runner-provenance-base64=").strip_edges()
			var decoded := Marshalls.base64_to_raw(encoded).get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(decoded)
			if typeof(parsed) == TYPE_DICTIONARY:
				runner_provenance = parsed as Dictionary
	call_deferred("_run")


func _run() -> void:
	var started_usec := Time.get_ticks_usec()
	if runner_provenance.is_empty():
		push_error("EV shard requires harness-bound runner provenance.")
		quit(1)
		return
	var library = ContentLibraryScript.new()
	library.load(false)
	var game = CoinPusherGame.new()
	game.setup(library.game("coin_pusher"), library)
	var definition: Dictionary = game.call("_machine_definition", machine_id)
	var variation_config: Dictionary = game.call("_variation_config", machine_id)
	if definition.is_empty() or not machine_id in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		_finish({"passed": false, "error": "Unknown production machine definition: %s" % machine_id})
		return
	if gutter_x_override >= 0:
		var overridden_geometry: Dictionary = (definition.get("geometry", {}) as Dictionary).duplicate(true)
		overridden_geometry["gutter_x"] = gutter_x_override
		definition["geometry"] = overridden_geometry
	var seed := "pusherv3_4_ev:%s:shard:%d" % [machine_id, shard_index]
	var root_rng := _rng(seed)
	var opening_count := int(game.call("_opening_coin_count"))
	var simulation := Solver.create_machine(root_rng.fork("opening"), definition, opening_count)
	var variation_state := {}
	if machine_id == "jackpot_ridge":
		variation_state = Ridge.initial_state(variation_config, root_rng.fork("ridge"), int(game.call("_lane_count")), int(game.call("_cell_count")))
	elif machine_id == "vault_drop":
		variation_state = Vault.initial_state(variation_config, root_rng.fork("vault"), int(game.call("_lane_count")), int(game.call("_cell_count")), "ev_shard_%d" % shard_index)
	var machine := {
		"variation_id": machine_id,
		"variation_state": variation_state,
		"simulation": simulation,
		"riders": game.call("_seed_prize_riders", {"scenario_game_modifiers": {"coin_pusher": {"prize_item_ids": ["coffee"]}}}, root_rng.fork("quarter_riders")) if machine_id == "quarter_falls" else [],
		"prize_goal_progress": 0,
		"prize_goal_completions": 0,
		"rider_serial": 0,
		"action_count": 0,
	}
	game.call("_sync_physical_features", machine)
	machine["rider_serial"] = (machine.get("riders", []) as Array).size()
	LiveSession.begin(machine, definition, 950000 + shard_index)
	var opening_stock := _body_kind_counts(simulation.get("bodies", []))
	var opening_origin := int(simulation.get("opening_body_count", 0))
	var policy := _policy_descriptor(definition)
	var policy_hash := _sha256(policy)
	var geometry_hash := _sha256({
		"geometry": definition.get("geometry", {}),
		"stroke": definition.get("stroke", {}),
		"apparatus": definition.get("apparatus", {}),
		"coins": definition.get("coins", {}),
		"ceiling": definition.get("ceiling", 0),
	})
	var phase_bins: Array = []
	for _index in range(PHASE_BIN_COUNT):
		phase_bins.append(0)
	var apparatus_counts := {}
	var player_accepted := 0
	var player_refused := 0
	var consecutive_refusals := 0
	var progression_ticks := 0
	var invariant_failures := 0
	var base_tray_coin_count := 0
	var base_tray_coin_value := 0
	var ridge_credited_coin_value := 0
	var opening_tray_coin_count := 0
	var opening_tray_coin_value := 0
	var feature_tray_count := 0
	var feature_gutter_count := 0
	var target_accounting := {"captures": {}, "consumed_by_origin": {"paid_coin": 0, "opening_coin": 0, "feature": 0}, "instant_payout_value": 0, "bonus_drop_award_count": 0}
	var physically_banked_fragment_ids: Array[String] = []
	var drop_rng := root_rng.fork("accepted_inserts")
	var event_rng := root_rng.fork("physical_events")
	while player_accepted < accepted_target:
		var apparatus_label := _apply_apparatus_policy(simulation, definition, player_accepted)
		var before_features := int(simulation.get("accepted_inserts", 0))
		game.call("_prepare_variation_action", machine)
		game.call("_sync_physical_features", machine)
		var feature_insert_delta := int(simulation.get("accepted_inserts", 0)) - before_features
		if feature_insert_delta < 0:
			_fail("Feature reconciliation reduced accepted insert count.")
		var dropped: Dictionary = Solver.add_coin(simulation, drop_rng, int(simulation.get("carriage_x", _definition_width(definition) / 2)), 1, {"ev_shard": shard_index, "ev_insert": player_accepted})
		if not bool(dropped.get("accepted", false)):
			player_refused += 1
			consecutive_refusals += 1
			_print_progress_if_due(started_usec, simulation, player_accepted, player_refused)
			var relief := _advance_and_consume(game, machine, event_rng, POLICY_TICKS)
			progression_ticks += POLICY_TICKS
			invariant_failures += 0 if bool(relief.get("invariants_ok", false)) else 1
			var relief_accounting := _drain_tray(simulation, game)
			base_tray_coin_count += int(relief_accounting["coin_count"])
			base_tray_coin_value += int(relief_accounting["coin_value"])
			ridge_credited_coin_value += int(relief_accounting["credited_coin_value"])
			opening_tray_coin_count += int(relief_accounting["opening_coin_count"])
			opening_tray_coin_value += int(relief_accounting["opening_coin_value"])
			feature_tray_count += int(relief_accounting["feature_count"])
			_append_unique_strings(physically_banked_fragment_ids, relief.get("fragment_ids", []))
			feature_gutter_count += int(relief.get("feature_gutter_count", 0))
			_accumulate_target_accounting(target_accounting, relief.get("target_accounting", {}))
			if consecutive_refusals >= MAX_CONSECUTIVE_REFUSALS_WITHOUT_ACCEPT:
				_finish_liveness_failure(started_usec, simulation, player_accepted, player_refused, consecutive_refusals, policy_hash, geometry_hash)
				return
			continue
		var period_ticks := maxi(1, int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
		var phase_bin := clampi(int(int(simulation.get("phase_fp", 0)) * PHASE_BIN_COUNT / (period_ticks * Solver.FP)), 0, PHASE_BIN_COUNT - 1)
		phase_bins[phase_bin] = int(phase_bins[phase_bin]) + 1
		apparatus_counts[apparatus_label] = int(apparatus_counts.get(apparatus_label, 0)) + 1
		player_accepted += 1
		consecutive_refusals = 0
		_print_progress_if_due(started_usec, simulation, player_accepted, player_refused)
		machine["action_count"] = player_accepted
		# The production live-session enqueue performs this action-boundary
		# transition. The unattended EV harness inserts directly into the solver,
		# so it must mirror the same generic "first committed drop starts play"
		# contract instead of leaving the newly parked cabinet motionless.
		if player_accepted == 1 and not bool(simulation.get("skill_stop_engaged", false)):
			simulation["motor_target_rate_fp"] = int(simulation.get("motor_run_rate_fp", Solver.FP))
		var advanced := _advance_and_consume(game, machine, event_rng, POLICY_TICKS)
		progression_ticks += POLICY_TICKS
		invariant_failures += 0 if bool(advanced.get("invariants_ok", false)) else 1
		_append_unique_strings(physically_banked_fragment_ids, advanced.get("fragment_ids", []))
		feature_gutter_count += int(advanced.get("feature_gutter_count", 0))
		_accumulate_target_accounting(target_accounting, advanced.get("target_accounting", {}))
		if player_accepted % 128 == 0:
			var accounting := _drain_tray(simulation, game)
			base_tray_coin_count += int(accounting["coin_count"])
			base_tray_coin_value += int(accounting["coin_value"])
			ridge_credited_coin_value += int(accounting["credited_coin_value"])
			opening_tray_coin_count += int(accounting["opening_coin_count"])
			opening_tray_coin_value += int(accounting["opening_coin_value"])
			feature_tray_count += int(accounting["feature_count"])
	var final_accounting := _drain_tray(simulation, game)
	base_tray_coin_count += int(final_accounting["coin_count"])
	base_tray_coin_value += int(final_accounting["coin_value"])
	ridge_credited_coin_value += int(final_accounting["credited_coin_value"])
	opening_tray_coin_count += int(final_accounting["opening_coin_count"])
	opening_tray_coin_value += int(final_accounting["opening_coin_value"])
	feature_tray_count += int(final_accounting["feature_count"])
	var ending_stock := _body_kind_counts(simulation.get("bodies", []))
	var gutter_stock := _ledger_kind_counts(simulation.get("gutter_ledger", []))
	var ending_origin := _body_origin_counts(simulation.get("bodies", []))
	var gutter_origin := _ledger_origin_counts(simulation.get("gutter_ledger", []))
	var feature_insert_count := int(simulation.get("accepted_inserts", 0)) - player_accepted
	var feature_bonus_drop_award_count := 0
	for queue_value in machine.get("drop_queue", []):
		if typeof(queue_value) != TYPE_DICTIONARY:
			continue
		var queued_bonus: Dictionary = queue_value
		var queued_provenance: Dictionary = queued_bonus.get("provenance", {}) if typeof(queued_bonus.get("provenance", {})) == TYPE_DICTIONARY else {}
		if queued_provenance.has("feature_bonus"):
			feature_bonus_drop_award_count += maxi(0, int(queued_bonus.get("remaining", 0)))
	var origin_by_kind_reconciliation := {
		"paid_coin": {"origin": player_accepted, "terminal": base_tray_coin_count + int(ending_origin.get("paid_coin", 0)) + int(gutter_origin.get("paid_coin", 0)) + int((target_accounting["consumed_by_origin"] as Dictionary).get("paid_coin", 0))},
		"opening_coin": {"origin": opening_origin, "terminal": opening_tray_coin_count + int(ending_origin.get("opening_coin", 0)) + int(gutter_origin.get("opening_coin", 0)) + int((target_accounting["consumed_by_origin"] as Dictionary).get("opening_coin", 0))},
		"feature": {"origin": feature_insert_count, "terminal": feature_tray_count + int(ending_origin.get("feature", 0)) + int(gutter_origin.get("feature", 0)) + int((target_accounting["consumed_by_origin"] as Dictionary).get("feature", 0))},
	}
	var origin_by_kind_ok := true
	for reconciliation_value in origin_by_kind_reconciliation.values():
		var reconciliation: Dictionary = reconciliation_value
		origin_by_kind_ok = origin_by_kind_ok and int(reconciliation.get("origin", -1)) == int(reconciliation.get("terminal", -2))
	var origin := int(simulation.get("opening_body_count", 0)) + int(simulation.get("accepted_inserts", 0))
	var terminal := (simulation.get("bodies", []) as Array).size() + (simulation.get("tray_ledger", []) as Array).size() + (simulation.get("gutter_ledger", []) as Array).size() + int(simulation.get("collected_count", 0)) + int(simulation.get("cup_consumed_count", 0))
	var drop_cost := maxi(1, int((definition.get("coins", {}) as Dictionary).get("drop_cost", 1)))
	var wagered := player_accepted * drop_cost
	var physical_roi := float(base_tray_coin_value) / float(maxi(1, wagered))
	var credited_roi := float(ridge_credited_coin_value) / float(maxi(1, wagered))
	var ending_paid_coin_value := int(ending_origin.get("paid_coin", 0)) * int((definition.get("coins", {}) as Dictionary).get("value", 1))
	var stock_adjusted_roi_upper := float(base_tray_coin_value + ending_paid_coin_value) / float(maxi(1, wagered))
	var ending_feature_positions: Array = []
	for body_value in simulation.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		if str(body.get("kind", "coin")) == "coin":
			continue
		ending_feature_positions.append({
			"id": str(body.get("id", "")),
			"kind": str(body.get("kind", "")),
			"x": int(body.get("x", 0)),
			"y": int(body.get("y", 0)),
			"z": int(body.get("z", 0)),
			"support_kind": str(body.get("support_kind", "")),
			"carried_sleep": bool(body.get("carried_sleep", false)),
		})
	var vault_banked_before_options := int(variation_state.get("banked_fragments", 0)) if machine_id == "vault_drop" else 0
	var vault_fragment_reconciled := machine_id != "vault_drop" or vault_banked_before_options == physically_banked_fragment_ids.size()
	if not vault_fragment_reconciled:
		_fail("Vault physically banked fragment IDs did not reconcile to production state (%d IDs, %d banked)." % [physically_banked_fragment_ids.size(), vault_banked_before_options])
	var vault_option_sampling := _resolve_banked_vault_options(variation_state, variation_config, physically_banked_fragment_ids) if machine_id == "vault_drop" else {}
	var vault_option_balance_reconciled := machine_id != "vault_drop" or bool(vault_option_sampling.get("token_balance_reconciled", false))
	var coverage_ok := phase_bins.all(func(value): return int(value) > 0) and apparatus_counts.values().all(func(value): return int(value) > 0)
	var conservation_ok := origin == terminal
	var report := {
		"schema": "coin_pusher_v3_physical_ev_shard_v2",
		"machine_id": machine_id,
		"shard_index": shard_index,
		"seed": seed,
		"accepted_target": accepted_target,
		"accepted_player_inserts": player_accepted,
		"refused_attempts_returned": player_refused,
		"progression_ticks": progression_ticks,
		"machine_instances": 1,
		"pile_resets": 0,
		"no_favorable_reset": true,
		"diagnostic_geometry_override": {"gutter_x": gutter_x_override} if gutter_x_override >= 0 else {},
		"solver_backend": Solver.last_step_backend_for_test(),
		"policy": policy,
		"policy_sha256": policy_hash,
		"geometry_sha256": geometry_hash,
		"runner_provenance": runner_provenance.duplicate(true),
		"coverage": {"phase_bins": phase_bins, "apparatus": apparatus_counts, "complete": coverage_ok},
		"accounting": {
			"opening_origin_count": opening_origin,
			"opening_stock_by_kind": opening_stock,
			"solver_accepted_inserts_including_features": int(simulation.get("accepted_inserts", 0)),
			"player_accepted_inserts": player_accepted,
			"feature_accepted_inserts": feature_insert_count,
			"ending_active_by_kind": ending_stock,
			"ending_active_by_origin": ending_origin,
			"ending_active_count": (simulation.get("bodies", []) as Array).size(),
			"ending_feature_positions": ending_feature_positions,
			"tray_after_collection_count": (simulation.get("tray_ledger", []) as Array).size(),
			"gutter_by_kind": gutter_stock,
			"gutter_by_origin": gutter_origin,
			"gutter_count": (simulation.get("gutter_ledger", []) as Array).size(),
			"collected_count": int(simulation.get("collected_count", 0)),
			"cup_consumed_count": int(simulation.get("cup_consumed_count", 0)),
			"cup_consumed_by_origin": (target_accounting["consumed_by_origin"] as Dictionary).duplicate(true),
			"origin_count": origin,
			"terminal_count": terminal,
			"conservation_ok": conservation_ok,
			"origin_by_kind_reconciliation": origin_by_kind_reconciliation,
			"origin_by_kind_reconciliation_ok": origin_by_kind_ok,
		},
		"economy": {
			"wagered": wagered,
			"base_physical_coin_tray_count": base_tray_coin_count,
			"base_physical_coin_tray_value": base_tray_coin_value,
			"base_physical_coin_to_tray_roi": physical_roi,
			"ending_active_paid_coin_value": ending_paid_coin_value,
			"ending_active_paid_coin_count": int(ending_origin.get("paid_coin", 0)),
			"paid_gutter_coin_count_terminal_lost": int(gutter_origin.get("paid_coin", 0)),
			"stock_adjusted_physical_roi_interval": [physical_roi, stock_adjusted_roi_upper],
			"stock_interval_method": "lower is paid-origin tray value; upper adds every unresolved active paid-origin coin; paid gutter remains terminal loss",
			"opening_coin_tray_count_excluded_from_roi": opening_tray_coin_count,
			"opening_coin_tray_value_excluded_from_roi": opening_tray_coin_value,
			"ridge_credited_coin_tray_value": ridge_credited_coin_value,
			"ridge_credited_roi": credited_roi,
			"feature_tray_count_excluded_from_base_roi": feature_tray_count,
			"feature_gutter_count": feature_gutter_count,
			"feature_bonus_drop_award_count_excluded_from_base_roi": feature_bonus_drop_award_count,
			"quarter_prize_goal_completions": int(machine.get("prize_goal_completions", 0)),
			"plinko_target_capture_counts": (target_accounting["captures"] as Dictionary).duplicate(true),
			"plinko_target_instant_payout_value_excluded_from_base_roi": int(target_accounting["instant_payout_value"]),
			"plinko_target_bonus_drop_award_count_excluded_from_base_roi": int(target_accounting["bonus_drop_award_count"]),
			"plinko_target_value_merged_into_physical_roi": false,
			"physically_banked_fragments_excluded_from_base_roi": physically_banked_fragment_ids.size(),
			"physically_banked_fragment_ids": physically_banked_fragment_ids,
			"vault_banked_fragments_before_options": vault_banked_before_options,
			"vault_banked_fragments_after_options": int(variation_state.get("banked_fragments", 0)) if machine_id == "vault_drop" else 0,
			"vault_option_value_sampling": vault_option_sampling,
			"vault_option_value_sampling_sha256": _sha256(vault_option_sampling) if machine_id == "vault_drop" else "",
			"vault_option_value_merged_into_physical_roi": false,
			"documented_physical_roi_band": (definition.get("economy", {}) as Dictionary).get("documented_ev_band", []),
		},
		"assertions": {
			"accepted_exact": player_accepted == accepted_target,
			"real_solver_progression": progression_ticks > player_accepted,
			"coverage_complete": coverage_ok,
			"conservation": conservation_ok,
			"origin_by_kind_reconciliation": origin_by_kind_ok,
			"invariants": invariant_failures == 0,
			"no_favorable_reset": true,
			"native_solver": Solver.last_step_backend_for_test() == "native_v3",
			"vault_physical_fragment_ids_reconciled": vault_fragment_reconciled,
			"vault_option_token_balance_reconciled": vault_option_balance_reconciled,
		},
		"elapsed_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
	}
	report["passed"] = (report["assertions"] as Dictionary).values().all(func(value): return bool(value))
	_finish(report)


func _resolve_banked_vault_options(state: Dictionary, config: Dictionary, physical_ids: Array[String]) -> Dictionary:
	var banked_before := int(state.get("banked_fragments", 0))
	var tokens: Array[String] = physical_ids.duplicate()
	var outcomes: Array = []
	var spent_tokens: Array[String] = []
	var refund_tokens: Array[String] = []
	var cash_total := 0
	var fixed_cash_total := 0
	var progressive_cash_total := 0
	var item_ids: Array[String] = []
	var refund_count := 0
	var reset_count := 0
	var jackpot_count := 0
	var kind_counts := {}
	var cursor := 0
	while cursor < tokens.size():
		if int(state.get("banked_fragments", 0)) <= 0:
			break
		if not bool(state.get("vault_round_active", false)) and not bool(Vault.start_round(state).get("ok", false)):
			break
		var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
		var unopened: Array[int] = []
		for cell_index in range(cells.size()):
			if typeof(cells[cell_index]) == TYPE_DICTIONARY and not bool((cells[cell_index] as Dictionary).get("opened", false)):
				unopened.append(cell_index)
		if unopened.is_empty():
			break
		var token_id := tokens[cursor]
		var selected_cell := unopened[cursor % unopened.size()]
		var meter_before := int(state.get("meter_value", 0))
		var opened := Vault.open_cell(state, selected_cell)
		if not bool(opened.get("ok", false)):
			break
		cursor += 1
		spent_tokens.append(token_id)
		var kind := str(opened.get("kind", ""))
		var cash := int(opened.get("cash", 0))
		var refunded := int(opened.get("fragment_refund", 0))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		cash_total += cash
		if bool(opened.get("jackpot", false)):
			progressive_cash_total += cash
			jackpot_count += 1
		else:
			fixed_cash_total += cash
		if bool(opened.get("reset", false)):
			reset_count += 1
		for item_id in opened.get("items", []):
			item_ids.append(str(item_id))
		for refund_index in range(refunded):
			var refund_id := "%s/refund/%d" % [token_id, refund_index]
			tokens.append(refund_id)
			refund_tokens.append(refund_id)
		refund_count += refunded
		if bool(opened.get("reset", false)) or bool(opened.get("jackpot", false)):
			state["meter_value"] = int(config.get("progressive_floor", 120))
		outcomes.append({
			"source_token_id": token_id,
			"source_is_physically_banked": physical_ids.has(token_id),
			"cell_index": selected_cell,
			"kind": kind,
			"cash": cash,
			"items": (opened.get("items", []) as Array).duplicate(),
			"fragment_refund": refunded,
			"reset": bool(opened.get("reset", false)),
			"jackpot": bool(opened.get("jackpot", false)),
			"progressive_meter_before": meter_before,
			"progressive_meter_after": int(state.get("meter_value", 0)),
		})
	var unspent_tokens := tokens.slice(cursor)
	var unspent_physical_ids: Array[String] = []
	var unspent_refund_ids: Array[String] = []
	for token_value in unspent_tokens:
		var unspent_id := str(token_value)
		if physical_ids.has(unspent_id):
			unspent_physical_ids.append(unspent_id)
		else:
			unspent_refund_ids.append(unspent_id)
	var token_balance_reconciled := unspent_tokens.size() == int(state.get("banked_fragments", 0))
	return {
		"method": "production_state_physically_banked_fragment_chain_v1",
		"selection_policy": "event-order tokens; cell index is spent ordinal modulo currently unopened cells",
		"physical_fragment_ids": physical_ids,
		"physical_fragment_count": physical_ids.size(),
		"production_banked_before": banked_before,
		"physical_id_count_reconciled": banked_before == physical_ids.size(),
		"spent_token_ids": spent_tokens,
		"refund_token_ids": refund_tokens,
		"unspent_token_ids": unspent_tokens,
		"unspent_physical_fragment_ids": unspent_physical_ids,
		"unspent_refund_token_ids": unspent_refund_ids,
		"production_banked_after": int(state.get("banked_fragments", 0)),
		"token_balance_reconciled": token_balance_reconciled,
		"outcomes": outcomes,
		"kind_counts": kind_counts,
		"cash_total": cash_total,
		"measured_cash_option_value_per_physically_banked_fragment": float(cash_total) / float(maxi(1, physical_ids.size())),
		"fixed_cash_total": fixed_cash_total,
		"progressive_cash_total": progressive_cash_total,
		"item_ids": item_ids,
		"fragment_refund_count": refund_count,
		"reset_count": reset_count,
		"jackpot_count": jackpot_count,
		"merged_into_coin_to_tray_roi": false,
	}


func _advance_and_consume(game, machine: Dictionary, rng: RngStream, ticks: int) -> Dictionary:
	var simulation: Dictionary = machine["simulation"]
	var stepped := Solver.step_ticks(simulation, {"motor_enabled": true}, ticks)
	var events: Array = stepped.get("events", []) if typeof(stepped.get("events", [])) == TYPE_ARRAY else []
	# This harness measures paid physical ROI. Cup-funded children and instant
	# payouts are recorded as separate feature value, never injected into the base
	# pile or allowed to accumulate as an unserviced live-session queue.
	var physical_events: Array = []
	var target_accounting := {"captures": {}, "consumed_by_origin": {"paid_coin": 0, "opening_coin": 0, "feature": 0}, "instant_payout_value": 0, "bonus_drop_award_count": 0}
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "plinko_cup":
			physical_events.append(event)
			continue
		var target_id := str(event.get("target_id", ""))
		var captures: Dictionary = target_accounting["captures"]
		captures[target_id] = int(captures.get(target_id, 0)) + 1
		var metadata: Dictionary = event.get("metadata", {}) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
		var provenance: Dictionary = metadata.get("provenance", {}) if typeof(metadata.get("provenance", {})) == TYPE_DICTIONARY else {}
		var origin_key := "feature" if bool(event.get("bonus_origin", false)) or bool(metadata.get("bonus_origin", false)) else "paid_coin" if provenance.has("ev_shard") else "opening_coin"
		var consumed: Dictionary = target_accounting["consumed_by_origin"]
		consumed[origin_key] = int(consumed.get(origin_key, 0)) + 1
		var reward: Dictionary = event.get("reward", {}) if typeof(event.get("reward", {})) == TYPE_DICTIONARY else {}
		if str(reward.get("kind", "")) == "instant_payout":
			target_accounting["instant_payout_value"] = int(target_accounting["instant_payout_value"]) + maxi(0, int(reward.get("value", 0)))
		elif str(reward.get("kind", "")) == "drop_multiplier":
			target_accounting["bonus_drop_award_count"] = int(target_accounting["bonus_drop_award_count"]) + maxi(0, int(reward.get("count", 0)))
	game.call("_consume_physics_events", null, machine, physical_events, rng)
	var fragment_ids: Array[String] = []
	var feature_gutter_count := 0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var body_kind := str(event.get("body_kind", ""))
		var outcome := str(event.get("outcome", ""))
		if body_kind == "fragment" and outcome == "tray":
			var metadata: Dictionary = event.get("metadata", {}) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
			var fragment_id := str(metadata.get("feature_id", ""))
			if not fragment_id.is_empty() and not fragment_ids.has(fragment_id):
				fragment_ids.append(fragment_id)
		if body_kind != "coin" and outcome == "gutter":
			feature_gutter_count += 1
	var invariants: Dictionary = stepped.get("invariants", {}) if typeof(stepped.get("invariants", {})) == TYPE_DICTIONARY else {}
	return {"invariants_ok": bool(invariants.get("energy_ok", false)) and bool(invariants.get("conservation_ok", false)), "fragment_ids": fragment_ids, "feature_gutter_count": feature_gutter_count, "target_accounting": target_accounting}


func _accumulate_target_accounting(total: Dictionary, delta_value: Variant) -> void:
	if typeof(delta_value) != TYPE_DICTIONARY:
		return
	var delta: Dictionary = delta_value
	for target_id in (delta.get("captures", {}) as Dictionary):
		(total["captures"] as Dictionary)[target_id] = int((total["captures"] as Dictionary).get(target_id, 0)) + int((delta["captures"] as Dictionary)[target_id])
	for origin_key in (delta.get("consumed_by_origin", {}) as Dictionary):
		(total["consumed_by_origin"] as Dictionary)[origin_key] = int((total["consumed_by_origin"] as Dictionary).get(origin_key, 0)) + int((delta["consumed_by_origin"] as Dictionary)[origin_key])
	total["instant_payout_value"] = int(total["instant_payout_value"]) + int(delta.get("instant_payout_value", 0))
	total["bonus_drop_award_count"] = int(total["bonus_drop_award_count"]) + int(delta.get("bonus_drop_award_count", 0))


func _append_unique_strings(target: Array[String], values: Variant) -> void:
	if typeof(values) != TYPE_ARRAY:
		return
	for value in values:
		var text := str(value)
		if not text.is_empty() and not target.has(text):
			target.append(text)


func _drain_tray(simulation: Dictionary, game) -> Dictionary:
	var coin_count := 0
	var coin_value := 0
	var credited_coin_value := 0
	var opening_coin_count := 0
	var opening_coin_value := 0
	var feature_count := 0
	var ledger: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	for entry_value in ledger:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("kind", "coin")) == "coin":
			var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
			var value := maxi(0, int(entry.get("value", 0)))
			if provenance.has("ev_shard"):
				coin_count += 1
				coin_value += value
				credited_coin_value += value * maxi(1, int(provenance.get("ridge_multiplier", 1)))
			else:
				opening_coin_count += 1
				opening_coin_value += value
		else:
			feature_count += 1
	Solver.collect_tray(simulation)
	return {"coin_count": coin_count, "coin_value": coin_value, "credited_coin_value": credited_coin_value, "opening_coin_count": opening_coin_count, "opening_coin_value": opening_coin_value, "feature_count": feature_count}


func _apply_apparatus_policy(simulation: Dictionary, definition: Dictionary, accepted_index: int) -> String:
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		var hole_index := accepted_index % maxi(1, holes.size())
		Solver.select_hole(simulation, hole_index)
		return "hole_%d" % hole_index
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	var fraction := int(RAIL_FRACTIONS[accepted_index % RAIL_FRACTIONS.size()])
	Solver.set_carriage(simulation, rail_min + (rail_max - rail_min) * fraction / 1000)
	return "rail_%d" % fraction


func _policy_descriptor(definition: Dictionary) -> Dictionary:
	return {
		"id": "persistent_round_robin_v1",
		"ticks_after_each_attempt": POLICY_TICKS,
		"phase_bin_count": PHASE_BIN_COUNT,
		"rail_fractions_milli": RAIL_FRACTIONS,
		"hole_selection": "accepted_index_mod_hole_count",
		"ceiling_behavior": "refused coin returned; same persistent machine advances and retries",
		"collection": "tray collected every 128 accepted drops; collection does not advance or reset physics",
		"tail_progression": "no favorable tail; unresolved active paid stock is reported as a conservative identified ROI interval",
		"apparatus_type": str((definition.get("apparatus", {}) as Dictionary).get("type", "")),
	}


func _print_progress_if_due(started_usec: int, simulation: Dictionary, accepted: int, refused: int) -> void:
	var attempts := accepted + refused
	if attempts <= 0 or attempts % PROGRESS_ATTEMPT_INTERVAL != 0:
		return
	print("COIN_PUSHER_EV_SHARD_PROGRESS machine=%s shard=%d accepted=%d/%d refused=%d active=%d tray=%d gutter=%d elapsed_seconds=%.3f" % [
		machine_id,
		shard_index,
		accepted,
		accepted_target,
		refused,
		(simulation.get("bodies", []) as Array).size(),
		(simulation.get("tray_ledger", []) as Array).size(),
		(simulation.get("gutter_ledger", []) as Array).size(),
		float(Time.get_ticks_usec() - started_usec) / 1000000.0,
	])


func _finish_liveness_failure(started_usec: int, simulation: Dictionary, accepted: int, refused: int, consecutive_refusals: int, policy_hash: String, geometry_hash: String) -> void:
	var detail := "No accepted insert after %d consecutive ceiling refusals; stopped before further persistent-machine progression could exhaust host resources." % consecutive_refusals
	_finish({
		"schema": "coin_pusher_v3_physical_ev_shard_failure_v1",
		"machine_id": machine_id,
		"shard_index": shard_index,
		"accepted_target": accepted_target,
		"accepted_player_inserts": accepted,
		"refused_attempts_returned": refused,
		"consecutive_refusals_without_accept": consecutive_refusals,
		"failure_kind": "no_accepted_progress",
		"failure_detail": detail,
		"guard": {
			"schema": "coin_pusher_ev_no_progress_guard_v1",
			"kind": "deterministic_consecutive_refusal_limit",
			"limit": MAX_CONSECUTIVE_REFUSALS_WITHOUT_ACCEPT,
			"ticks_after_each_refusal": POLICY_TICKS,
		},
		"state": {
			"active": (simulation.get("bodies", []) as Array).size(),
			"tray": (simulation.get("tray_ledger", []) as Array).size(),
			"gutter": (simulation.get("gutter_ledger", []) as Array).size(),
			"solver_accepted_inserts_including_features": int(simulation.get("accepted_inserts", 0)),
			"solver_refused_inserts": int(simulation.get("refused_inserts", 0)),
		},
		"solver_backend": Solver.last_step_backend_for_test(),
		"policy_sha256": policy_hash,
		"geometry_sha256": geometry_hash,
		"runner_provenance": runner_provenance.duplicate(true),
		"elapsed_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"passed": false,
	})


func _body_kind_counts(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var kind := str((value as Dictionary).get("kind", "coin"))
			result[kind] = int(result.get(kind, 0)) + 1
	return result


func _ledger_kind_counts(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var kind := str((value as Dictionary).get("kind", "coin"))
			result[kind] = int(result.get(kind, 0)) + 1
	return result


func _body_origin_counts(values: Array) -> Dictionary:
	var result := {"paid_coin": 0, "opening_coin": 0, "feature": 0}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if str(body.get("kind", "coin")) != "coin":
			result["feature"] = int(result["feature"]) + 1
			continue
		var meta: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		var provenance: Dictionary = meta.get("provenance", {}) if typeof(meta.get("provenance", {})) == TYPE_DICTIONARY else {}
		var key := "paid_coin" if provenance.has("ev_shard") else "opening_coin"
		result[key] = int(result[key]) + 1
	return result


func _ledger_origin_counts(values: Array) -> Dictionary:
	var result := {"paid_coin": 0, "opening_coin": 0, "feature": 0}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if str(entry.get("kind", "coin")) != "coin":
			result["feature"] = int(result["feature"]) + 1
			continue
		var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
		var key := "paid_coin" if provenance.has("ev_shard") else "opening_coin"
		result[key] = int(result[key]) + 1
	return result


func _definition_width(definition: Dictionary) -> int:
	return int((definition.get("geometry", {}) as Dictionary).get("width", Solver.WIDTH))


func _sha256(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value, "", true).to_utf8_buffer())
	return context.finish().hex_encode()


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write EV shard report: %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var passed := bool(report.get("passed", false)) and not failed
	print("COIN_PUSHER_EV_SHARD_%s machine=%s shard=%d accepted=%d out=%s" % ["PASS" if passed else "FAIL", machine_id, shard_index, int(report.get("accepted_player_inserts", 0)), ProjectSettings.globalize_path(out_path)])
	quit(0 if passed else 1)
