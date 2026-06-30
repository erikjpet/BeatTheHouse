class_name SlotResolver
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const BuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")

const SPIN_ACTION := "spin"
const NUDGE_ACTION := "nudge"
const HOST_APPLY_FLAG := "host_apply_result"
const WIN_REVEAL_BEAT_SEC := 0.18
const BUFFALO_BONUS_MAX_ANIMATION_MSEC := 10000

var pinball
var buffalo


func _init() -> void:
	pinball = PinballScript.new()
	buffalo = BuffaloScript.new()


func resolve_spin(machine: Dictionary, action_id: String, selected_bet: Dictionary, rng: RngStream, definition: Dictionary, environment: Dictionary = {}, normalize_machine: bool = true, audit_metrics_mode: bool = false, run_state: RunState = null, item_effects: Dictionary = {}, ui_state: Dictionary = {}) -> Dictionary:
	if normalize_machine:
		machine = StateScript.normalize(machine)
	var normalized_action := _normalize_action(action_id)
	var family_id := str(machine.get("type_id", "pinball"))
	var family = _family_hook(family_id)
	var stake := maxi(1, int(selected_bet.get("total_credits", 2)))
	var bet_id := str(selected_bet.get("id", "bet_2"))
	var is_cheat := normalized_action == NUDGE_ACTION
	var had_offer := is_cheat and not _copy_dict(machine.get("last_nudge_offer", {})).is_empty()
	if StateScript.active_bonus_incomplete(machine) and not had_offer:
		return _blocked_result(machine, normalized_action, stake, environment, "Finish the active bonus first.")
	var free_spin := int(machine.get("free_spins", 0)) > 0 and normalized_action == SPIN_ACTION
	var stake_cost := 0 if had_offer else stake if is_cheat or not free_spin else 0
	if free_spin:
		machine["free_spins"] = maxi(0, int(machine.get("free_spins", 0)) - 1)

	var entry: Dictionary = {}
	var grid: Array = []
	var stops: Array = []
	var previous_grid: Array = [] if audit_metrics_mode else _copy_array(machine.get("last_grid", []))
	var nudge_applied := false
	var nudge_event: Dictionary = {}
	if had_offer:
		var offer: Dictionary = _copy_dict(machine.get("last_nudge_offer", {}))
		if family_id == "buffalo":
			var timed_nudge: Dictionary = _resolve_buffalo_nudge_offer(machine, family, offer, definition, ui_state)
			entry = _copy_dict(timed_nudge.get("entry", {}))
			grid = _copy_array(timed_nudge.get("grid", []))
			nudge_event = _copy_dict(timed_nudge.get("tease_event", {}))
		else:
			entry = family.nudge_entry(machine, definition)
			var shifted: Dictionary = family.apply_nudge_to_grid(machine, _copy_array(offer.get("grid", machine.get("last_grid", []))))
			grid = _copy_array(shifted.get("grid", []))
			nudge_event = _copy_dict(shifted.get("tease_event", {}))
		nudge_applied = true
		stops = _copy_array(offer.get("stops", machine.get("reel_stops", [])))
	else:
		entry = _select_entry(machine, family, definition, rng, free_spin)
		if audit_metrics_mode and family_id == "pinball":
			grid = _blank_grid(int(machine.get("reel_count", 3)), int(machine.get("row_count", 1)))
		else:
			var reel_strips: Array = []
			var reel_strips_value: Variant = machine.get("reel_strips", [])
			if audit_metrics_mode and typeof(reel_strips_value) == TYPE_ARRAY:
				reel_strips = reel_strips_value as Array
			else:
				reel_strips = _copy_array(reel_strips_value)
			stops = MathScript.pick_reel_stops(reel_strips, rng)
			grid = MathScript.project_grid(
				reel_strips,
				stops,
				int(machine.get("reel_count", 3)),
				int(machine.get("row_count", 1))
			)
		grid = family.force_outcome_symbols(machine, grid, entry, rng, definition)
		if is_cheat and str(entry.get("classification", "")) == "near_miss":
			var shifted_live: Dictionary = family.apply_nudge_to_grid(machine, grid)
			grid = _copy_array(shifted_live.get("grid", grid))
			nudge_event = _copy_dict(shifted_live.get("tease_event", {}))
			entry = family.nudge_entry(machine, definition)
			nudge_applied = true

	var classification := str(entry.get("classification", "zero_loss"))
	var side_effects: Dictionary = _derive_grid_side_effects(machine, grid, family_id, stake, entry, definition)
	var side_grid: Variant = side_effects.get("grid", grid)
	grid = side_grid as Array if audit_metrics_mode and typeof(side_grid) == TYPE_ARRAY else _copy_array(side_grid)
	var feature_triggered: bool = family.opens_feature(classification)
	var active_bonus: Dictionary = {}
	var headline_payout: int = 0 if feature_triggered else _grid_payout_for_family(family, grid, stake, stake_cost, machine, definition, entry)
	var immediate_payout := 0
	machine["last_grid"] = grid
	if family_id == "buffalo" and normalized_action == SPIN_ACTION and stake_cost > 0:
		buffalo.advance_grand_prize(machine, stake_cost, stake, bet_id)
	if feature_triggered:
		var preserved_bonus: Dictionary = _copy_dict(entry.get("preserve_active_bonus", {}))
		if not preserved_bonus.is_empty():
			active_bonus = preserved_bonus
		elif family_id == "pinball":
			active_bonus = family.open_feature(machine, stake, rng, definition)
		else:
			active_bonus = family.open_feature(machine, entry, stake, rng, definition)
		machine["active_bonus"] = active_bonus
		machine["last_bonus_total"] = maxi(0, int(active_bonus.get("feature_total", active_bonus.get("pending_award", 0))))
		machine["last_bonus_mode"] = str(active_bonus.get("mode", classification))
		machine["last_bonus_complete"] = false
	else:
		immediate_payout += headline_payout
		machine["active_bonus"] = {"active": false, "complete": true}
		machine["last_bonus_total"] = 0
		machine["last_bonus_mode"] = ""
		machine["last_bonus_complete"] = false

	var base_bankroll_delta := immediate_payout - stake_cost
	var cross_effects: Dictionary = _slot_resolve_cross_effects(immediate_payout, stake, stake_cost, base_bankroll_delta, is_cheat, normalized_action, run_state, definition, environment, item_effects)
	var luck_payout_bonus := int(cross_effects.get("luck_payout_bonus", 0))
	var item_payout_bonus := int(cross_effects.get("item_payout_bonus", 0))
	var item_loss_reduction := int(cross_effects.get("item_loss_reduction", 0))
	if luck_payout_bonus + item_payout_bonus > 0:
		immediate_payout = maxi(1, immediate_payout + luck_payout_bonus + item_payout_bonus)
	var bankroll_delta := immediate_payout - stake_cost
	if item_loss_reduction > 0 and bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + item_loss_reduction)
	var suspicion_delta := int(cross_effects.get("suspicion_delta", 0))
	var security_bankroll_delta := int(cross_effects.get("security_bankroll_delta", 0))
	if security_bankroll_delta != 0:
		bankroll_delta += security_bankroll_delta
	var finalized_classification := _final_classification(classification, immediate_payout, stake_cost, feature_triggered)
	var win_attribution: Dictionary = _win_attribution(machine, grid, family_id, finalized_classification, immediate_payout, stake, stake_cost, feature_triggered, active_bonus, side_effects, entry)
	_capture_previous_result(machine)
	_apply_win_attribution(machine, win_attribution)
	machine["spin_count"] = maxi(0, int(machine.get("spin_count", 0))) + 1
	machine["coin_in"] = maxi(0, int(machine.get("coin_in", 0))) + stake_cost
	machine["coin_out"] = maxi(0, int(machine.get("coin_out", 0))) + immediate_payout
	machine["reel_stops"] = stops.duplicate(true)
	machine["last_previous_grid"] = previous_grid
	machine["last_grid"] = grid
	machine["last_reels"] = stops.duplicate(true)
	machine["last_payout"] = immediate_payout
	machine["last_net"] = bankroll_delta
	machine["last_stake_cost"] = stake_cost
	machine["last_line_payout"] = headline_payout
	machine["last_classification"] = finalized_classification
	machine["last_outcome_id"] = str(entry.get("id", classification))
	if audit_metrics_mode:
		return {
			"machine": machine,
			"result": {
				"ok": true,
				"bankroll_delta": bankroll_delta,
				"slot_outcome_id": str(entry.get("id", "")),
				"slot_classification": finalized_classification,
				"slot_payout": immediate_payout,
				"slot_stake": stake,
				"slot_stake_cost": stake_cost,
				"slot_feature_triggered": feature_triggered,
				"slot_active_bonus": active_bonus.duplicate(true),
				"slot_gold_conversion": bool(side_effects.get("conversion", false)),
			},
		}
	machine["last_tease_events"] = _tease_events(classification, nudge_applied, nudge_event)
	machine["last_nudge_offer"] = _nudge_offer(machine, entry, grid, stops, classification, nudge_applied)
	var animation_plan: Dictionary = _animation_plan(machine, finalized_classification, active_bonus, win_attribution)
	if feature_triggered:
		active_bonus["animation_duration_msec"] = int(animation_plan.get("feature_duration_msec", 0))
		machine["active_bonus"] = active_bonus
	machine["slot_animation_id"] = str(animation_plan.get("id", ""))
	machine["slot_animation_duration_msec"] = int(animation_plan.get("duration_msec", 0))
	machine["slot_animation_started_msec"] = 0
	machine["slot_animation_plan"] = animation_plan.duplicate(true)
	machine["slot_reel_stop_times"] = _copy_array(animation_plan.get("reel_stop_times", []))
	machine["slot_reel_timeline"] = _copy_array(animation_plan.get("reel_timeline", []))
	machine["slot_bonus_start_time"] = float(animation_plan.get("bonus_start_time", 0.0))
	var result: Dictionary = _spin_result(machine, entry, normalized_action, stake, stake_cost, immediate_payout, bankroll_delta, suspicion_delta, environment, animation_plan, feature_triggered, active_bonus, side_effects, free_spin, nudge_applied, cross_effects)
	return {"machine": StateScript.normalize(machine) if normalize_machine else machine, "result": result}


func resolve_bonus_action(machine: Dictionary, action_id: String, rng: RngStream, definition: Dictionary, environment: Dictionary = {}, run_state: RunState = null, item_effects: Dictionary = {}, ui_state: Dictionary = {}) -> Dictionary:
	machine = StateScript.normalize(machine)
	var active_before: Dictionary = _copy_dict(machine.get("active_bonus", {}))
	if active_before.is_empty() or not bool(active_before.get("active", false)):
		return {
			"machine": machine,
			"result": _zero_result(machine, action_id, environment, "No bonus is active."),
		}
	var family_id := str(active_before.get("family", machine.get("type_id", "pinball")))
	var family = _family_hook_strict(family_id)
	if family == null:
		return {
			"machine": machine,
			"result": _zero_result(machine, action_id, environment, "Unknown bonus family: %s." % family_id),
		}
	var step: Dictionary = family.step_bonus(machine, _normalize_bonus_action(action_id), rng, definition, ui_state)
	_apply_bonus_step_display(machine, family_id, active_before, step)
	var award := maxi(0, int(step.get("award", 0)))
	var luck_payout_bonus := 0
	var item_payout_bonus := 0
	if award > 0:
		luck_payout_bonus = run_state.luck_payout_bonus(maxi(1, int(active_before.get("stake", 1))), true) if run_state != null else 0
		item_payout_bonus = int(item_effects.get("win_bonus", 0)) + int(item_effects.get("payout_delta", 0))
	if luck_payout_bonus + item_payout_bonus > 0:
		award = maxi(1, award + luck_payout_bonus + item_payout_bonus)
		step["award"] = award
		step["luck_payout_bonus"] = luck_payout_bonus
		step["item_payout_bonus"] = item_payout_bonus
	var complete := bool(step.get("complete", false))
	if complete:
		machine["coin_out"] = maxi(0, int(machine.get("coin_out", 0))) + award
		machine["last_bonus_complete"] = true
		machine["last_payout"] = award
		machine["last_net"] = award
		var bonus_win: Dictionary = _bonus_win_attribution(active_before, step, award)
		_apply_win_attribution(machine, bonus_win)
		var bonus_plan: Dictionary = _bonus_step_animation_plan(machine, active_before, step, bonus_win, true) if _bonus_step_uses_reel_animation(family_id, active_before, step) else _bonus_completion_animation_plan(machine, bonus_win)
		var replay_duration := maxi(0, int(step.get("replay_duration_msec", 0)))
		if replay_duration > 0:
			bonus_plan["duration_msec"] = maxi(int(bonus_plan.get("duration_msec", 0)), replay_duration)
			bonus_plan["feature_duration_msec"] = maxi(int(bonus_plan.get("feature_duration_msec", 0)), replay_duration)
		if family_id == "buffalo":
			bonus_plan = _cap_buffalo_animation_plan(machine, bonus_plan)
		machine["slot_animation_id"] = str(bonus_plan.get("id", ""))
		machine["slot_animation_duration_msec"] = int(bonus_plan.get("duration_msec", 0))
		machine["slot_animation_started_msec"] = 0
		machine["slot_animation_plan"] = bonus_plan.duplicate(true)
		machine["slot_reel_stop_times"] = _copy_array(bonus_plan.get("reel_stop_times", []))
		machine["slot_reel_timeline"] = _copy_array(bonus_plan.get("reel_timeline", []))
		machine["slot_bonus_start_time"] = float(bonus_plan.get("bonus_start_time", 0.0))
		var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
		bonus_state["feature_completions"] = maxi(0, int(bonus_state.get("feature_completions", 0))) + 1
		var bet_id := str(active_before.get("bet_id", "bet_2"))
		var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
		var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
		bucket["feature_completion_count"] = maxi(0, int(bucket.get("feature_completion_count", 0))) + 1
		buckets[bet_id] = bucket
		bonus_state["per_bet"] = buckets
		machine["bonus_state"] = bonus_state
		var completed_active: Dictionary = _copy_dict(step.get("active_bonus", {}))
		if family_id == "buffalo" and int(completed_active.get("grand_prize_awarded", 0)) > 0:
			buffalo.reset_grand_prize(machine, maxi(1, int(active_before.get("stake", 1))), bet_id)
	var message := str(step.get("message", "Bonus advances."))
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = award
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"slot_event": "slot_bonus_step",
		"game_id": "slot",
		"family": family_id,
		"action_id": action_id,
		"mode": str(active_before.get("mode", "")),
		"complete": complete,
		"payout": award,
		"luck_payout_bonus": luck_payout_bonus,
		"item_payout_bonus": item_payout_bonus,
		"bankroll_delta": award,
		"suspicion_delta": 0,
		"won": award > 0,
		"environment_id": str(environment.get("id", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "slot",
		"game_id": "slot",
		"action_id": action_id,
		"action_kind": "bonus",
		"stake": 0,
		"deltas": deltas,
		"won": award > 0,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result[HOST_APPLY_FLAG] = true
	result["slot_bonus_step"] = step
	result["slot_bonus_complete"] = complete
	result["slot_bonus_award"] = award
	result["slot_runtime_tick"] = action_id == "slot_bonus_tick"
	result["slot_animation_id"] = str(machine.get("slot_animation_id", ""))
	result["slot_animation_duration_msec"] = int(machine.get("slot_animation_duration_msec", 0))
	result["slot_reel_timeline"] = _copy_array(machine.get("slot_reel_timeline", []))
	result["slot_reel_stop_times"] = _copy_array(machine.get("slot_reel_stop_times", []))
	result["slot_luck_payout_bonus"] = luck_payout_bonus
	result["slot_item_payout_bonus"] = item_payout_bonus
	result["slot_luck_win_chance_ignored"] = true
	if complete:
		result.merge(_result_win_fields(machine), true)
	return {"machine": StateScript.normalize(machine), "result": result}


func complete_active_bonus_for_metrics(machine: Dictionary, rng: RngStream, definition: Dictionary) -> int:
	var total := 0
	var guard := 0
	var metric_active_source: Dictionary = _copy_dict(machine.get("active_bonus", {}))
	var family_id := str(metric_active_source.get("family", machine.get("type_id", "pinball")))
	var family = _family_hook(family_id)
	if family_id == "pinball":
		var metric_active: Dictionary = metric_active_source
		metric_active["headless"] = true
		if str(metric_active.get("mode", "")) == "video_feature":
			metric_active["reference_policy"] = true
		var metric_session: Dictionary = _copy_dict(metric_active.get("pinball_session", {}))
		if not metric_session.is_empty():
			metric_session["record_trajectory"] = false
			metric_active["pinball_session"] = metric_session
		machine["active_bonus"] = metric_active
	while StateScript.active_bonus_incomplete(machine) and guard < 80:
		var action_id := "slot_bonus_launch"
		var active: Dictionary = _copy_dict(machine.get("active_bonus", {}))
		if str(active.get("mode", "")) == "wheel":
			action_id = "slot_bonus_right"
		var step: Dictionary = family.step_bonus(machine, action_id, rng, definition)
		if bool(step.get("complete", false)):
			total += int(step.get("award", 0))
		guard += 1
	if StateScript.active_bonus_incomplete(machine):
		machine["active_bonus"] = {"active": false, "complete": true}
	return total


func monte_carlo_metrics(source_machine: Dictionary, definition: Dictionary, spins: int, stake: int, rng: RngStream) -> Dictionary:
	var machine: Dictionary = StateScript.normalize(source_machine.duplicate(true))
	var bet_id := "bet_%d" % stake
	if stake == 10:
		bet_id = "bet_10"
	StateScript.set_selected_bet(machine, bet_id)
	var bet: Dictionary = StateScript.selected_bet(machine)
	var total_delta := 0
	var total_stake := 0
	var hit_count := 0
	var true_win_count := 0
	var ldw_count := 0
	var near_miss_count := 0
	var feature_count := 0
	var outcome_counts := {}
	var conversion_count := 0
	var feature_award_cache: Dictionary = {}
	var feature_award_totals: Dictionary = {}
	var feature_award_counts: Dictionary = {}
	for _spin_index in range(maxi(0, spins)):
		if StateScript.active_bonus_incomplete(machine):
			machine["active_bonus"] = {"active": false, "complete": true}
		var resolved: Dictionary = resolve_spin(machine, SPIN_ACTION, bet, rng, definition, {}, false, true)
		var resolved_machine: Variant = resolved.get("machine", {})
		machine = resolved_machine as Dictionary if typeof(resolved_machine) == TYPE_DICTIONARY else {}
		var resolved_result: Variant = resolved.get("result", {})
		var result: Dictionary = resolved_result as Dictionary if typeof(resolved_result) == TYPE_DICTIONARY else {}
		var stake_cost := maxi(0, int(result.get("slot_stake_cost", stake)))
		var payout := maxi(0, int(result.get("slot_payout", 0)))
		total_delta += int(result.get("bankroll_delta", 0))
		total_stake += stake_cost
		var classification := str(result.get("slot_classification", ""))
		outcome_counts[classification] = int(outcome_counts.get(classification, 0)) + 1
		if payout > 0 or bool(result.get("slot_feature_triggered", false)):
			hit_count += 1
		if classification == "true_win":
			true_win_count += 1
		elif classification == "ldw":
			ldw_count += 1
		elif classification == "near_miss":
			near_miss_count += 1
		if bool(result.get("slot_feature_triggered", false)):
			feature_count += 1
			var active_bonus: Dictionary = _copy_dict(machine.get("active_bonus", {}))
			var feature_key := "%s:%s:%s:%d" % [str(machine.get("type_id", "")), str(machine.get("format_id", "")), str(active_bonus.get("mode", "")), stake]
			var feature_award := int(complete_active_bonus_for_metrics(machine, rng, definition))
			feature_award_totals[feature_key] = int(feature_award_totals.get(feature_key, 0)) + feature_award
			feature_award_counts[feature_key] = int(feature_award_counts.get(feature_key, 0)) + 1
			total_delta += feature_award
			machine["active_bonus"] = {"active": false, "complete": true}
		if bool(result.get("slot_gold_conversion", false)):
			conversion_count += 1
	if StateScript.active_bonus_incomplete(machine):
		machine["active_bonus"] = {"active": false, "complete": true}
	var safe_spins := maxi(1, spins)
	var safe_stake := maxi(1, total_stake)
	for feature_key_value in feature_award_totals.keys():
		var feature_key := str(feature_key_value)
		var count := maxi(1, int(feature_award_counts.get(feature_key, 0)))
		feature_award_cache[feature_key] = int(round(float(feature_award_totals.get(feature_key, 0)) / float(count)))
	return {
		"spins": spins,
		"stake": stake,
		"total_stake": total_stake,
		"net_delta": total_delta,
		"rtp": float(total_delta + total_stake) / float(safe_stake),
		"hit_frequency": float(hit_count) / float(safe_spins),
		"true_win_frequency": float(true_win_count) / float(safe_spins),
		"ldw_frequency": float(ldw_count) / float(safe_spins),
		"near_miss_frequency": float(near_miss_count) / float(safe_spins),
		"feature_frequency": float(feature_count) / float(safe_spins),
		"conversion_count": conversion_count,
		"feature_award_cache": feature_award_cache,
		"outcome_counts": outcome_counts,
		"machine": machine,
	}


func _metric_average_feature_award(source_machine: Dictionary, source_active: Dictionary, rng: RngStream, definition: Dictionary, samples: int) -> int:
	var sample_count := maxi(1, samples)
	var total := 0
	for _index in range(sample_count):
		var machine: Dictionary = source_machine.duplicate(true)
		machine["active_bonus"] = source_active.duplicate(true)
		total += complete_active_bonus_for_metrics(machine, rng, definition)
	return maxi(0, int(round(float(total) / float(sample_count))))


func _grid_payout_for_family(family, grid: Array, stake: int, stake_cost: int, machine: Dictionary, definition: Dictionary, entry: Dictionary) -> int:
	if family != null and family.has_method("grid_payout_for_entry"):
		return maxi(0, int(family.grid_payout_for_entry(grid, stake, stake_cost, machine, definition, entry)))
	if family != null and family.has_method("grid_payout"):
		return maxi(0, int(family.grid_payout(grid, stake, stake_cost, machine, definition)))
	return maxi(0, int(family.payout_for(entry, stake, stake_cost, machine, definition)))


func _select_entry(machine: Dictionary, family, definition: Dictionary, rng: RngStream, free_spin: bool) -> Dictionary:
	if str(machine.get("type_id", "")) == "buffalo":
		var bet_id := str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2"))
		var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
		var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
		var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
		if bool(bucket.get("must_hit_ready", false)):
			bucket["must_hit_ready"] = false
			bucket["must_hit_meter"] = 100
			buckets[bet_id] = bucket
			bonus_state["per_bet"] = buckets
			bonus_state["must_hit_forces"] = maxi(0, int(bonus_state.get("must_hit_forces", 0))) + 1
			machine["bonus_state"] = bonus_state
			var table: Array = family.outcome_table(machine, definition, free_spin)
			for entry_value in table:
				var entry: Dictionary = entry_value
				if str(entry.get("id", "")) == "free_games":
					entry["forced_by_meter"] = true
					return entry.duplicate(true)
	return MathScript.weighted_pick(family.outcome_table(machine, definition, free_spin), rng)


func _derive_grid_side_effects(machine: Dictionary, grid: Array, family_id: String, stake: int, entry: Dictionary = {}, definition: Dictionary = {}) -> Dictionary:
	if family_id == "buffalo":
		return buffalo.apply_grid_side_effects(machine, grid, stake, entry, definition)
	return {
		"grid": grid,
		"pinball_count": MathScript.count_symbol(grid, "PINBALL"),
		"gold_token_count": 0,
		"lock_count": 0,
		"conversion": false,
		"conversion_award": 0,
	}


func _final_classification(classification: String, payout: int, stake_cost: int, feature_triggered: bool) -> String:
	if feature_triggered:
		return classification
	if classification == "near_miss":
		return "near_miss"
	if payout > stake_cost:
		return "true_win"
	if payout > 0 and payout <= stake_cost:
		return "ldw"
	return "zero_loss"


func _tease_events(classification: String, nudge_applied: bool, nudge_event: Dictionary) -> Array:
	if nudge_applied:
		return [nudge_event]
	if classification == "near_miss":
		return [{"type": "near_miss", "banner": "SO CLOSE"}]
	return []


func _nudge_offer(machine: Dictionary, entry: Dictionary, grid: Array, stops: Array, classification: String, nudge_applied: bool) -> Dictionary:
	if nudge_applied:
		return {}
	var family_id := str(machine.get("type_id", "pinball"))
	if family_id == "buffalo":
		return _buffalo_nudge_offer(machine, entry, grid, stops, classification)
	if classification != "near_miss":
		return {}
	return {
		"outcome_id": str(entry.get("id", "")),
		"classification": classification,
		"grid": MathScript.clone_grid(grid),
		"stops": stops.duplicate(true),
		"spin_count": int(machine.get("spin_count", 0)),
		"post_spin_available": true,
	}


func _buffalo_nudge_offer(machine: Dictionary, entry: Dictionary, grid: Array, stops: Array, classification: String) -> Dictionary:
	if not ["near_miss", "free_games", "monster_feature"].has(classification):
		return {}
	var placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var cells: Array = _buffalo_offer_cells(grid, placement, classification)
	if cells.is_empty():
		return {}
	var sorted_cells: Array = _cells_sorted_by_reel(cells)
	var visible_count := mini(3, sorted_cells.size())
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var first_cell: Dictionary = _copy_dict(sorted_cells[0])
	var first_reel := clampi(int(first_cell.get("reel", 0)), 0, reel_count - 1)
	var second_reel := mini(reel_count - 1, first_reel + 1)
	if sorted_cells.size() > 1:
		var second_cell: Dictionary = _copy_dict(sorted_cells[1])
		second_reel = clampi(int(second_cell.get("reel", second_reel)), 0, reel_count - 1)
	var skill_line_cells: Array = _copy_array(placement.get("skill_line_cells", []))
	if skill_line_cells.is_empty():
		skill_line_cells = _skill_line_cells_from_tease(machine, sorted_cells)
	var window: Dictionary = _skill_window_for_reels(_rough_stop_times_for_machine(machine), first_reel, second_reel, visible_count)
	var offer: Dictionary = {
		"outcome_id": str(entry.get("id", "")),
		"classification": classification,
		"original_classification": classification,
		"grid": MathScript.clone_grid(grid),
		"stops": stops.duplicate(true),
		"spin_count": int(machine.get("spin_count", 0)),
		"visible_coin_count": visible_count,
		"coin_cells": sorted_cells,
		"skill_line_cells": skill_line_cells,
		"first_coin_reel": first_reel,
		"second_coin_reel": second_reel,
		"skill_window_msec": window,
		"skill_perfect_msec": 75,
		"skill_close_msec": 210,
		"post_spin_available": false,
	}
	if ["free_games", "monster_feature"].has(classification):
		offer["preserve_active_bonus"] = _copy_dict(machine.get("active_bonus", {}))
	return offer


func _resolve_buffalo_nudge_offer(machine: Dictionary, family, offer: Dictionary, definition: Dictionary, ui_state: Dictionary) -> Dictionary:
	var original_classification := str(offer.get("original_classification", offer.get("classification", "near_miss")))
	var skill: Dictionary = _nudge_skill_result(offer, ui_state)
	var outcome := str(skill.get("outcome", "miss"))
	var target_classification := "zero_loss"
	if outcome == "perfect":
		target_classification = original_classification if ["free_games", "monster_feature"].has(original_classification) else str(family.nudge_entry(machine, definition).get("classification", "free_games"))
	elif outcome == "close":
		target_classification = "near_miss"
	var entry: Dictionary = _entry_for_classification(machine, family, definition, target_classification)
	var grid: Array = _buffalo_nudge_grid_for_outcome(machine, offer, target_classification, outcome)
	entry["forced_placement"] = _buffalo_nudge_placement(machine, offer, target_classification, outcome, grid)
	if outcome == "perfect" and ["free_games", "monster_feature"].has(original_classification):
		var preserved: Dictionary = _copy_dict(offer.get("preserve_active_bonus", {}))
		if not preserved.is_empty():
			entry["preserve_active_bonus"] = preserved
	var event: Dictionary = {
		"type": "nudge_shift",
		"family": "buffalo",
		"skill_outcome": outcome,
		"input_msec": int(skill.get("input_msec", -1)),
		"perfect_msec": int(skill.get("perfect_msec", -1)),
		"distance_msec": int(skill.get("distance_msec", 9999)),
		"converted_to": target_classification,
		"original_classification": original_classification,
		"visible_coin_count": int(offer.get("visible_coin_count", 0)),
	}
	return {"entry": entry, "grid": grid, "tease_event": event}


func _nudge_skill_result(offer: Dictionary, ui_state: Dictionary) -> Dictionary:
	var window: Dictionary = _copy_dict(offer.get("skill_window_msec", {}))
	var start_msec := maxi(0, int(window.get("start", 0)))
	var end_msec := maxi(start_msec, int(window.get("end", start_msec + 1)))
	var perfect_msec := clampi(int(window.get("perfect", start_msec)), start_msec, end_msec)
	var input_msec := _nudge_input_msec(ui_state)
	if input_msec < 0:
		input_msec = end_msec + 999
	var distance := absi(input_msec - perfect_msec)
	var perfect_width := maxi(1, int(offer.get("skill_perfect_msec", 75)))
	var close_width := maxi(perfect_width, int(offer.get("skill_close_msec", 210)))
	var outcome := "miss"
	if input_msec >= start_msec and input_msec <= end_msec and distance <= perfect_width:
		outcome = "perfect"
	elif input_msec >= start_msec and input_msec <= end_msec and distance <= close_width:
		outcome = "close"
	return {
		"outcome": outcome,
		"input_msec": input_msec,
		"perfect_msec": perfect_msec,
		"distance_msec": distance,
	}


func _nudge_input_msec(ui_state: Dictionary) -> int:
	if int(ui_state.get("slot_tease_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_tease_input_msec", -1))
	if int(ui_state.get("slot_spin_elapsed_msec", -1)) >= 0:
		return int(ui_state.get("slot_spin_elapsed_msec", -1))
	var runtime: Dictionary = _copy_dict(ui_state.get("surface_runtime_status", {}))
	var animations: Dictionary = _copy_dict(runtime.get("surface_animations", {}))
	var spin: Dictionary = _copy_dict(animations.get("slot_spin", {}))
	if spin.is_empty():
		return -1
	return maxi(0, int(round(float(spin.get("elapsed", 0.0)) * 1000.0)))


func _entry_for_classification(machine: Dictionary, family, definition: Dictionary, classification: String) -> Dictionary:
	var table: Array = family.outcome_table(machine, definition, false)
	for entry_value in table:
		var entry: Dictionary = entry_value
		if str(entry.get("classification", "")) == classification or str(entry.get("id", "")) == classification:
			return entry.duplicate(true)
	return {"id": classification, "classification": classification, "weight": 1, "payout": 0, "payout_multiplier": 0.0}


func _buffalo_nudge_grid_for_outcome(machine: Dictionary, offer: Dictionary, target_classification: String, outcome: String) -> Array:
	var grid: Array = MathScript.clone_grid(_copy_array(offer.get("grid", [])))
	var target_cells: Array = _copy_array(offer.get("skill_line_cells", []))
	var visible_count := mini(3, int(offer.get("visible_coin_count", 0)))
	var target_coin_count := 0
	if target_classification == "free_games" or target_classification == "monster_feature":
		target_coin_count = 3
	elif target_classification == "near_miss":
		target_coin_count = mini(2, maxi(visible_count, 2 if outcome == "close" else visible_count))
	if target_cells.is_empty():
		target_cells = _skill_line_cells_from_tease(machine, _copy_array(offer.get("coin_cells", [])))
	for index in range(target_cells.size()):
		var cell: Dictionary = _copy_dict(target_cells[index])
		var reel_index := int(cell.get("reel", 0))
		var row_index := int(cell.get("row", 0))
		if index < target_coin_count:
			MathScript.set_cell(grid, reel_index, row_index, "GOLD_TOKEN")
		else:
			MathScript.set_cell(grid, reel_index, row_index, _fallback_non_gold_symbol(reel_index, row_index))
	_scrub_unprotected_gold_tokens(grid, target_cells.slice(0, target_coin_count))
	return grid


func _buffalo_nudge_placement(machine: Dictionary, offer: Dictionary, target_classification: String, outcome: String, grid: Array) -> Dictionary:
	var target_cells: Array = _copy_array(offer.get("skill_line_cells", []))
	if target_cells.is_empty():
		target_cells = _skill_line_cells_from_tease(machine, _copy_array(offer.get("coin_cells", [])))
	var placed: Array = []
	for cell_value in target_cells:
		var cell: Dictionary = _copy_dict(cell_value)
		if _cell_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1))) == "GOLD_TOKEN":
			placed.append(cell)
	var line_index := 0
	if not placed.is_empty():
		line_index = int((placed[0] as Dictionary).get("row", 0))
	var kind := "feature" if target_classification == "free_games" or target_classification == "monster_feature" else "tease" if target_classification == "near_miss" else "miss"
	return {
		"kind": kind,
		"symbol": "GOLD_TOKEN",
		"cells": placed,
		"skill_line_cells": target_cells,
		"line_index": line_index,
		"nudge_skill_outcome": outcome,
	}


func _buffalo_offer_cells(grid: Array, placement: Dictionary, classification: String) -> Array:
	var cells: Array = _copy_array(placement.get("cells", []))
	var result: Array = []
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		if _cell_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1))) == "GOLD_TOKEN":
			result.append(cell)
	if result.is_empty() and classification == "near_miss":
		result = _symbol_cells(grid, "GOLD_TOKEN")
	if result.size() > 3:
		result = result.slice(0, 3)
	return result


func _gold_tease_profile(machine: Dictionary, classification: String, win_attribution: Dictionary, base: float, step: float) -> Dictionary:
	if str(machine.get("type_id", "")) != "buffalo":
		return {}
	if str(win_attribution.get("symbol", "")) != "GOLD_TOKEN":
		return {}
	var cells: Array = _cells_sorted_by_reel(_copy_array(win_attribution.get("cells", [])))
	if cells.is_empty():
		return {}
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var coin_count := mini(3, cells.size())
	var first_cell: Dictionary = _copy_dict(cells[0])
	var first_reel := clampi(int(first_cell.get("reel", 0)), 0, reel_count - 1)
	var second_reel := mini(reel_count - 1, first_reel + 1)
	if cells.size() > 1:
		var second_cell: Dictionary = _copy_dict(cells[1])
		second_reel = clampi(int(second_cell.get("reel", second_reel)), 0, reel_count - 1)
	var start_tease := clampi(first_reel + 1, 0, reel_count - 1)
	if coin_count >= 2:
		start_tease = mini(start_tease, second_reel)
	var tease_reels: Array = []
	for reel_index in range(start_tease, reel_count):
		tease_reels.append(reel_index)
	var rough_stops: Array = []
	for reel_index in range(reel_count):
		rough_stops.append(base + step * float(reel_index))
	var window: Dictionary = _skill_window_for_reels(rough_stops, first_reel, second_reel, coin_count)
	return {
		"symbol": "GOLD_TOKEN",
		"classification": classification,
		"coin_count": coin_count,
		"first_coin_reel": first_reel,
		"second_coin_reel": second_reel,
		"tease_reels": tease_reels,
		"skill_window_msec": window,
	}


func _skill_window_for_reels(stops: Array, first_reel: int, second_reel: int, coin_count: int) -> Dictionary:
	var safe_stops: Array = stops.duplicate(true)
	var first_time := float(safe_stops[first_reel]) if first_reel >= 0 and first_reel < safe_stops.size() else 0.62
	var second_time := float(safe_stops[second_reel]) if second_reel >= 0 and second_reel < safe_stops.size() else first_time + 0.42
	var perfect := second_time + (0.30 if coin_count <= 1 else 0.18)
	var start := maxf(0.0, first_time + 0.16)
	var end := perfect + 0.28
	return {
		"start": int(round(start * 1000.0)),
		"perfect": int(round(perfect * 1000.0)),
		"end": int(round(end * 1000.0)),
	}


func _rough_stop_times_for_machine(machine: Dictionary) -> Array:
	var format_id := str(machine.get("format_id", "classic_3_reel"))
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var base := 0.86
	var step := 0.42
	if format_id == "line_5x3":
		base = 0.62
		step = 0.24
	elif format_id == "video_feature":
		base = 0.48
		step = 0.14
	var result: Array = []
	for reel_index in range(reel_count):
		result.append(base + step * float(reel_index))
	return result


func _skill_line_cells_from_tease(machine: Dictionary, cells: Array) -> Array:
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var row := clampi(row_count / 2, 0, row_count - 1)
	var start_reel := 0
	if not cells.is_empty():
		var first_cell: Dictionary = _copy_dict(_cells_sorted_by_reel(cells)[0])
		start_reel = clampi(int(first_cell.get("reel", 0)), 0, maxi(0, reel_count - 1))
		row = clampi(int(first_cell.get("row", row)), 0, row_count - 1)
	var target_count := mini(3, reel_count - start_reel)
	if target_count < mini(3, reel_count):
		start_reel = maxi(0, reel_count - mini(3, reel_count))
		target_count = mini(3, reel_count)
	return MathScript.line_cells_from(reel_count, row_count, row, start_reel, target_count)


func _cells_sorted_by_reel(cells: Array) -> Array:
	var result: Array = _copy_array(cells)
	result.sort_custom(func(a: Variant, b: Variant) -> bool:
		var cell_a: Dictionary = _copy_dict(a)
		var cell_b: Dictionary = _copy_dict(b)
		var reel_a := int(cell_a.get("reel", 0))
		var reel_b := int(cell_b.get("reel", 0))
		if reel_a == reel_b:
			return int(cell_a.get("row", 0)) < int(cell_b.get("row", 0))
		return reel_a < reel_b
	)
	return result


func _fallback_non_gold_symbol(reel_index: int, row_index: int) -> String:
	var symbols := ["A", "K", "Q", "J", "10", "WOLF", "ELK"]
	return str(symbols[posmod(reel_index * 3 + row_index, symbols.size())])


func _scrub_unprotected_gold_tokens(grid: Array, protected_cells: Array) -> void:
	var protected: Dictionary = {}
	for cell_value in protected_cells:
		var cell: Dictionary = _copy_dict(cell_value)
		protected["%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))]] = true
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if str(column[row_index]) == "GOLD_TOKEN" and not bool(protected.get("%d:%d" % [reel_index, row_index], false)):
				column[row_index] = _fallback_non_gold_symbol(reel_index, row_index)
		grid[reel_index] = column


func _animation_plan(machine: Dictionary, classification: String, active_bonus: Dictionary, win_attribution: Dictionary) -> Dictionary:
	var format_id := str(machine.get("format_id", "classic_3_reel"))
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var base := 0.86
	var step := 0.42
	var settle := 0.24
	if format_id == "line_5x3":
		base = 0.62
		step = 0.24
		settle = 0.20
	elif format_id == "video_feature":
		base = 0.48
		step = 0.14
		settle = 0.17
	var stop_times: Array = []
	var timeline: Array = []
	var tease_reel := reel_count - 1
	var gold_tease: Dictionary = _gold_tease_profile(machine, classification, win_attribution, base, step)
	var gold_tease_reels: Array = _copy_array(gold_tease.get("tease_reels", []))
	var gold_tease_lookup: Dictionary = {}
	for reel_value in gold_tease_reels:
		gold_tease_lookup[int(reel_value)] = true
	for reel_index in range(reel_count):
		var stop_time := base + step * float(reel_index)
		var tease := classification == "near_miss" and reel_index == tease_reel
		if not gold_tease.is_empty():
			tease = bool(gold_tease_lookup.get(reel_index, false))
		if tease:
			stop_time += 0.34 + 0.12 * float(int(gold_tease.get("coin_count", 1))) + 0.08 * float(reel_index)
		stop_times.append(stop_time)
		var spin_up_end := 0.16 + 0.025 * float(reel_index)
		var decel_start := maxf(spin_up_end + 0.10, stop_time - (0.68 if tease else 0.32))
		timeline.append({
			"reel": reel_index,
			"spin_up_start": 0.0,
			"spin_up_end": spin_up_end,
			"decel_start": decel_start,
			"stop_time": stop_time,
			"settle_end": stop_time + settle,
			"tease": tease,
			"tease_symbol": str(gold_tease.get("symbol", "")),
			"tease_level": int(gold_tease.get("coin_count", 0)),
			"tease_window": _copy_dict(gold_tease.get("skill_window_msec", {})),
			"phase_order": ["spin_up", "spin", "tease_slow_roll" if tease else "decel", "settle"],
		})
	var last_stop := float(stop_times[stop_times.size() - 1]) if not stop_times.is_empty() else base
	var bonus_steps := maxi(0, int(active_bonus.get("total_steps", 0))) if not active_bonus.is_empty() else 0
	var total := last_stop + settle
	var tier := str(win_attribution.get("tier", "none"))
	var celebration_duration := _celebration_duration_msec(tier)
	var celebration_start := total + WIN_REVEAL_BEAT_SEC
	if celebration_duration > 0:
		total += WIN_REVEAL_BEAT_SEC + float(celebration_duration) / 1000.0
	var feature_duration := 0
	if bonus_steps > 0:
		feature_duration = int(round(float(bonus_steps) * 720.0 + 900.0))
		total += float(feature_duration) / 1000.0
	var id := "%s:%d:%s" % [str(machine.get("machine_key", "")), int(machine.get("spin_count", 0)) + 1, classification]
	var plan := {
		"id": id,
		"duration_msec": int(ceil(total * 1000.0)),
		"reel_stop_times": stop_times,
		"reel_timeline": timeline,
		"bonus_start_time": last_stop + 0.40,
		"feature_duration_msec": feature_duration,
		"tease_active": classification == "near_miss" or not gold_tease.is_empty(),
		"tease_reel": tease_reel if classification == "near_miss" and gold_tease.is_empty() else int(gold_tease.get("first_coin_reel", -1)),
		"tease_reels": gold_tease_reels,
		"tease_coin_count": int(gold_tease.get("coin_count", 0)),
		"tease_first_coin_reel": int(gold_tease.get("first_coin_reel", -1)),
		"tease_second_coin_reel": int(gold_tease.get("second_coin_reel", -1)),
		"tease_skill_window_msec": _copy_dict(gold_tease.get("skill_window_msec", {})),
		"tease_text": str(win_attribution.get("reason", "")),
		"celebration_tier": tier,
		"celebration_start_msec": int(round(celebration_start * 1000.0)),
		"celebration_duration_msec": celebration_duration,
		"count_up_start_msec": int(round(celebration_start * 1000.0)),
		"count_up_end_msec": int(round(celebration_start * 1000.0)) + celebration_duration,
	}
	return _cap_buffalo_animation_plan(machine, plan)


func _bonus_completion_animation_plan(machine: Dictionary, win_attribution: Dictionary) -> Dictionary:
	var tier := str(win_attribution.get("tier", "none"))
	var celebration_duration := _celebration_duration_msec(tier)
	var duration := maxi(900, celebration_duration + 300)
	var plan := {
		"id": "bonus:%s:%d" % [str(machine.get("machine_key", "")), int(machine.get("spin_count", 0))],
		"duration_msec": duration,
		"reel_stop_times": [],
		"reel_timeline": [],
		"bonus_start_time": 0.0,
		"feature_duration_msec": duration,
		"tease_active": false,
		"tease_reel": -1,
		"tease_text": "",
		"celebration_tier": tier,
		"celebration_start_msec": 80,
		"celebration_duration_msec": celebration_duration,
		"count_up_start_msec": 80,
		"count_up_end_msec": 80 + celebration_duration,
	}
	return _cap_buffalo_animation_plan(machine, plan)


func _bonus_step_uses_reel_animation(family_id: String, active_before: Dictionary, step: Dictionary) -> bool:
	if family_id != "buffalo" or _copy_array(step.get("grid", [])).is_empty():
		return false
	var mode := str(active_before.get("mode", ""))
	return mode == "free_games" or mode == "hold_and_spin"


func _bonus_step_animation_plan(machine: Dictionary, active_before: Dictionary, step: Dictionary, win_attribution: Dictionary, completing: bool) -> Dictionary:
	var classification := str(step.get("classification", "bonus_step"))
	var plan: Dictionary = _animation_plan(machine, classification, {}, win_attribution)
	var step_active: Dictionary = _copy_dict(step.get("active_bonus", {}))
	var step_index := maxi(1, int(step_active.get("step_index", int(active_before.get("step_index", 0)) + 1)))
	var id_prefix := "bonus" if completing else "bonus-step"
	plan["id"] = "%s:%s:%d:%d:%s" % [id_prefix, str(machine.get("machine_key", "")), int(machine.get("spin_count", 0)), step_index, classification]
	plan["feature_duration_msec"] = 0
	if completing:
		var spin_duration := maxi(900, int(plan.get("duration_msec", 0)))
		var reveal_count := _copy_array(step_active.get("coin_reveals", [])).size()
		var collect_duration := 900 if int(step.get("coin_collect_total", step_active.get("coin_collect_total", 0))) > 0 else 450
		if reveal_count > 0:
			collect_duration = maxi(collect_duration, 520 + reveal_count * 170)
		var tier := str(win_attribution.get("tier", "feature"))
		var celebration_duration := _celebration_duration_msec(tier)
		var celebration_start := spin_duration + collect_duration
		plan["duration_msec"] = spin_duration + collect_duration + celebration_duration
		plan["feature_duration_msec"] = collect_duration + celebration_duration
		plan["coin_collect_start_msec"] = spin_duration
		plan["coin_collect_duration_msec"] = collect_duration
		plan["celebration_tier"] = tier
		plan["celebration_start_msec"] = celebration_start
		plan["celebration_duration_msec"] = celebration_duration
		plan["count_up_start_msec"] = celebration_start
		plan["count_up_end_msec"] = celebration_start + celebration_duration
	return _cap_buffalo_animation_plan(machine, plan)


func _cap_buffalo_animation_plan(machine: Dictionary, plan: Dictionary) -> Dictionary:
	if str(machine.get("type_id", "")) != "buffalo":
		return plan
	var duration := maxi(0, int(plan.get("duration_msec", 0)))
	if duration <= BUFFALO_BONUS_MAX_ANIMATION_MSEC:
		return plan
	plan["duration_msec"] = BUFFALO_BONUS_MAX_ANIMATION_MSEC
	if plan.has("feature_duration_msec"):
		plan["feature_duration_msec"] = mini(maxi(0, int(plan.get("feature_duration_msec", 0))), BUFFALO_BONUS_MAX_ANIMATION_MSEC)
	for key in ["celebration_start_msec", "count_up_start_msec", "count_up_end_msec"]:
		if plan.has(key):
			plan[key] = mini(maxi(0, int(plan.get(key, 0))), BUFFALO_BONUS_MAX_ANIMATION_MSEC)
	if plan.has("celebration_duration_msec"):
		var celebration_start := maxi(0, int(plan.get("celebration_start_msec", 0)))
		plan["celebration_duration_msec"] = mini(maxi(0, int(plan.get("celebration_duration_msec", 0))), maxi(0, BUFFALO_BONUS_MAX_ANIMATION_MSEC - celebration_start))
	if plan.has("coin_collect_duration_msec"):
		var collect_start := maxi(0, int(plan.get("coin_collect_start_msec", 0)))
		plan["coin_collect_duration_msec"] = mini(maxi(0, int(plan.get("coin_collect_duration_msec", 0))), maxi(0, BUFFALO_BONUS_MAX_ANIMATION_MSEC - collect_start))
	return plan


func _apply_animation_plan_to_machine(machine: Dictionary, plan: Dictionary) -> void:
	machine["slot_animation_id"] = str(plan.get("id", ""))
	machine["slot_animation_duration_msec"] = int(plan.get("duration_msec", 0))
	machine["slot_animation_started_msec"] = 0
	machine["slot_animation_plan"] = plan.duplicate(true)
	machine["slot_reel_stop_times"] = _copy_array(plan.get("reel_stop_times", []))
	machine["slot_reel_timeline"] = _copy_array(plan.get("reel_timeline", []))
	machine["slot_bonus_start_time"] = float(plan.get("bonus_start_time", 0.0))


func _apply_bonus_step_display(machine: Dictionary, family_id: String, active_before: Dictionary, step: Dictionary) -> void:
	var grid: Array = _copy_array(step.get("grid", []))
	if grid.is_empty():
		return
	var previous_grid: Array = _copy_array(machine.get("last_grid", []))
	machine["last_previous_grid"] = previous_grid
	machine["last_grid"] = grid
	var stops: Array = _copy_array(step.get("reel_stops", []))
	if not stops.is_empty():
		machine["reel_stops"] = stops.duplicate(true)
		machine["last_reels"] = stops.duplicate(true)
	var classification := str(step.get("classification", "bonus_step"))
	machine["last_classification"] = classification
	machine["last_outcome_id"] = str(step.get("id", classification))
	machine["last_line_payout"] = maxi(0, int(step.get("spin_award", 0)))
	var entry: Dictionary = {
		"id": str(step.get("id", classification)),
		"classification": classification,
		"forced_placement": _copy_dict(step.get("forced_placement", {})),
	}
	var attribution: Dictionary = _win_attribution(machine, grid, family_id, classification, int(step.get("spin_award", 0)), maxi(1, int(active_before.get("stake", 1))), 0, false, active_before, {}, entry)
	_apply_win_attribution(machine, attribution)
	if _bonus_step_uses_reel_animation(family_id, active_before, step) and not bool(step.get("complete", false)):
		_apply_animation_plan_to_machine(machine, _bonus_step_animation_plan(machine, active_before, step, attribution, false))


func _slot_resolve_cross_effects(payout: int, stake: int, stake_cost: int, bankroll_delta: int, is_cheat: bool, action_id: String, run_state: RunState, definition: Dictionary, environment: Dictionary, item_effects: Dictionary) -> Dictionary:
	var effects := {
		"luck_payout_bonus": 0,
		"item_payout_bonus": 0,
		"item_loss_reduction": 0,
		"suspicion_delta": 0,
		"security_bankroll_delta": 0,
		"security_message": "",
		"security_ended": false,
		"pit_boss_watched": false,
		"pit_boss_heat_bonus": 0,
	}
	var stake_basis := maxi(1, stake_cost if stake_cost > 0 else stake)
	if run_state != null and payout > 0:
		effects["luck_payout_bonus"] = run_state.luck_payout_bonus(stake_basis, true)
		effects["item_payout_bonus"] = int(item_effects.get("win_bonus", 0)) + int(item_effects.get("payout_delta", 0))
	elif bankroll_delta < 0:
		effects["item_loss_reduction"] = maxi(0, int(item_effects.get("loss_reduction", 0)))
	if is_cheat:
		var heat: Dictionary = _slot_cheat_heat(action_id, stake_basis, run_state, definition, environment, item_effects)
		for key in heat.keys():
			effects[key] = heat[key]
	return effects


func _slot_cheat_heat(action_id: String, stake: int, run_state: RunState, definition: Dictionary, environment: Dictionary, item_effects: Dictionary) -> Dictionary:
	var cheat_def: Dictionary = _cheat_action_def(definition, action_id)
	var base_heat := int(cheat_def.get("suspicion_delta", 12))
	if run_state == null:
		return {
			"suspicion_delta": maxi(0, base_heat),
			"security_bankroll_delta": 0,
			"security_message": "",
			"security_ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(0, base_heat + int(item_effects.get("cheat_suspicion_delta", 0)) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if raw_heat > 0 else 0
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", stake, run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var security_message := str(security_pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		security_message = "%s %s" % [pit_boss_summary, security_message]
		security_message = security_message.strip_edges()
	return {
		"suspicion_delta": suspicion_delta,
		"security_bankroll_delta": int(security_pressure.get("bankroll_delta", 0)),
		"security_message": security_message,
		"security_ended": bool(security_pressure.get("ended", false)),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
	}


func _cheat_action_def(definition: Dictionary, action_id: String) -> Dictionary:
	var actions: Array = definition.get("cheat_actions", []) if typeof(definition.get("cheat_actions", [])) == TYPE_ARRAY else []
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		if str(action.get("id", "")) == action_id:
			return action.duplicate(true)
	return {}


func _spin_result(machine: Dictionary, entry: Dictionary, action_id: String, stake: int, stake_cost: int, payout: int, bankroll_delta: int, suspicion_delta: int, environment: Dictionary, animation_plan: Dictionary, feature_triggered: bool, active_bonus: Dictionary, side_effects: Dictionary, free_spin: bool, nudge_applied: bool, cross_effects: Dictionary = {}) -> Dictionary:
	var classification := str(machine.get("last_classification", "zero_loss"))
	var message := _message_for_spin(classification, payout, stake_cost, feature_triggered, active_bonus, nudge_applied)
	var security_message := str(cross_effects.get("security_message", ""))
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["messages"] = [message]
	deltas["ended"] = bool(cross_effects.get("security_ended", false))
	deltas["story_log"] = [{
		"type": "game_action",
		"slot_event": "slot_spin",
		"game_id": "slot",
		"action_id": action_id,
		"family": str(machine.get("type_id", "")),
		"format_id": str(machine.get("format_id", "")),
		"outcome_id": str(entry.get("id", "")),
		"classification": classification,
		"stake_cost": stake_cost,
		"payout": payout,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"luck_payout_bonus": int(cross_effects.get("luck_payout_bonus", 0)),
		"item_payout_bonus": int(cross_effects.get("item_payout_bonus", 0)),
		"item_loss_reduction": int(cross_effects.get("item_loss_reduction", 0)),
		"security_bankroll_delta": int(cross_effects.get("security_bankroll_delta", 0)),
		"pit_boss_watched": bool(cross_effects.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(cross_effects.get("pit_boss_heat_bonus", 0)),
		"environment_id": str(environment.get("id", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "slot",
		"game_id": "slot",
		"action_id": action_id,
		"action_kind": "cheat" if action_id == NUDGE_ACTION else "legal",
		"stake": stake,
		"deltas": deltas,
		"won": payout > stake_cost or feature_triggered,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result[HOST_APPLY_FLAG] = true
	result["slot_outcome_id"] = str(entry.get("id", ""))
	result["slot_classification"] = classification
	result["slot_payout"] = payout
	result["slot_stake"] = stake
	result["slot_stake_cost"] = stake_cost
	result["slot_net"] = bankroll_delta
	result["slot_free_spin"] = free_spin
	result["slot_nudge_applied"] = nudge_applied
	result["slot_nudge_skill_outcome"] = _last_nudge_skill_outcome(machine)
	result["slot_feature_triggered"] = feature_triggered
	result["slot_active_bonus"] = active_bonus.duplicate(true)
	result["slot_grid"] = _copy_array(machine.get("last_grid", []))
	result["slot_reel_stops"] = _copy_array(machine.get("reel_stops", []))
	result["slot_animation_plan"] = animation_plan.duplicate(true)
	result["slot_animation_id"] = str(animation_plan.get("id", ""))
	result["slot_animation_duration_msec"] = int(animation_plan.get("duration_msec", 0))
	result["slot_reel_stop_times"] = _copy_array(animation_plan.get("reel_stop_times", []))
	result["slot_reel_timeline"] = _copy_array(animation_plan.get("reel_timeline", []))
	result["slot_bonus_start_time"] = float(animation_plan.get("bonus_start_time", 0.0))
	result["slot_gold_conversion"] = bool(side_effects.get("conversion", false))
	result["slot_conversion_award"] = int(side_effects.get("conversion_award", 0))
	result["slot_scatter_count"] = int(side_effects.get("gold_token_count", side_effects.get("pinball_count", 0)))
	result["slot_lock_count"] = int(side_effects.get("lock_count", 0))
	result["slot_luck_payout_bonus"] = int(cross_effects.get("luck_payout_bonus", 0))
	result["slot_item_payout_bonus"] = int(cross_effects.get("item_payout_bonus", 0))
	result["slot_item_loss_reduction"] = int(cross_effects.get("item_loss_reduction", 0))
	result["slot_security_bankroll_delta"] = int(cross_effects.get("security_bankroll_delta", 0))
	result["slot_pit_boss_watched"] = bool(cross_effects.get("pit_boss_watched", false))
	result["slot_pit_boss_heat_bonus"] = int(cross_effects.get("pit_boss_heat_bonus", 0))
	result["slot_luck_win_chance_ignored"] = true
	result.merge(_result_win_fields(machine), true)
	return result


func _message_for_spin(classification: String, payout: int, stake_cost: int, feature_triggered: bool, active_bonus: Dictionary, nudge_applied: bool) -> String:
	if feature_triggered:
		var mode := str(active_bonus.get("mode", classification)).replace("_", " ")
		return "Perfect nudge starts %s." % mode.capitalize() if nudge_applied else "Feature started: %s." % mode.capitalize()
	if nudge_applied:
		if classification == "near_miss":
			return "Nudge catches the tease, but not the feature."
		if payout > 0:
			return "Nudge lands for $%d before heat." % payout
		return "Nudge misses and breaks the spin."
	if classification == "near_miss":
		return "Near miss. A nudge is available."
	if payout > stake_cost:
		return "Slot pays $%d." % payout
	if payout > 0:
		return "Partial return: $%d." % payout
	return "No payout."


func _last_nudge_skill_outcome(machine: Dictionary) -> String:
	for event_value in _copy_array(machine.get("last_tease_events", [])):
		var event: Dictionary = _copy_dict(event_value)
		if str(event.get("type", "")) == "nudge_shift":
			return str(event.get("skill_outcome", "legacy"))
	return ""


func _win_attribution(machine: Dictionary, grid: Array, family_id: String, classification: String, payout: int, stake: int, stake_cost: int, feature_triggered: bool, active_bonus: Dictionary, side_effects: Dictionary, entry: Dictionary = {}) -> Dictionary:
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var trigger_symbol := "GOLD_TOKEN" if family_id == "buffalo" else "PINBALL"
	var forced_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var result: Dictionary = {
		"cells": [],
		"symbol": "",
		"count": 0,
		"kind": "none",
		"line_index": -1,
		"multiplier": 1,
		"amount": maxi(0, payout),
		"reason": "",
		"tier": "none",
	}
	if feature_triggered:
		var scatter_cells: Array = _placement_cells(forced_placement, trigger_symbol)
		if scatter_cells.is_empty():
			scatter_cells = _symbol_cells(grid, trigger_symbol)
		result["cells"] = scatter_cells
		result["symbol"] = trigger_symbol
		result["count"] = scatter_cells.size()
		result["kind"] = "feature"
		result["reason"] = "%d %s starts %s" % [scatter_cells.size(), trigger_symbol, str(active_bonus.get("mode", "bonus")).replace("_", " ").capitalize()]
		result["tier"] = "feature"
		return result
	if classification == "near_miss":
		var near_cells: Array = _placement_cells(forced_placement, trigger_symbol)
		if near_cells.is_empty():
			near_cells = _symbol_cells(grid, trigger_symbol)
		result["cells"] = near_cells
		result["symbol"] = trigger_symbol
		result["count"] = near_cells.size()
		result["kind"] = "tease"
		result["reason"] = "SO CLOSE - %d of 3 %s" % [near_cells.size(), trigger_symbol]
		result["tier"] = "tease"
		return result
	if classification == "true_win" or classification == "ldw":
		var line: Dictionary = _line_attribution(grid, family_id, reel_count, center_row, forced_placement)
		result["cells"] = _copy_array(line.get("cells", []))
		result["symbol"] = str(line.get("symbol", ""))
		result["count"] = int(line.get("count", 0))
		result["kind"] = str(line.get("kind", "ways" if family_id == "buffalo" and reel_count > 3 else "line"))
		result["line_index"] = int(line.get("line_index", -1))
		result["multiplier"] = maxi(1, int(line.get("multiplier", 1)))
		var count_label := "%dx %s" % [int(result.get("count", 0)), str(result.get("symbol", ""))]
		if result["kind"] == "ways":
			count_label = "%d %s, %d ways" % [int(result.get("count", 0)), str(result.get("symbol", "")), _ways_hint_for_cells(grid, str(result.get("symbol", "")), _copy_array(result.get("cells", [])))]
		result["reason"] = "%s on line %d" % [count_label, int(result.get("line_index", -1)) + 1] if result["kind"] == "line" else count_label
		if classification == "ldw":
			result["reason"] = "%s (small return)" % str(result.get("reason", ""))
		if int(result.get("multiplier", 1)) > 1:
			result["reason"] = "%s x%d" % [str(result.get("reason", "")), int(result.get("multiplier", 1))]
		result["tier"] = _win_tier(payout, stake_cost, str(result.get("kind", "line")), "")
		return result
	if int(side_effects.get("conversion_award", 0)) > 0:
		var buffalo_cells: Array = _symbol_cells(grid, "BUFFALO")
		result["cells"] = buffalo_cells
		result["symbol"] = "BUFFALO"
		result["count"] = buffalo_cells.size()
		result["kind"] = "ways"
		result["reason"] = "Gold Buffalo conversion"
		result["tier"] = _win_tier(payout, stake, "ways", "")
	return result


func _bonus_win_attribution(active_bonus: Dictionary, step: Dictionary, award: int) -> Dictionary:
	var mode := str(active_bonus.get("mode", step.get("mode", "feature")))
	var jackpot_tier := str(step.get("jackpot_tier", active_bonus.get("jackpot_tier", "")))
	return {
		"cells": [],
		"symbol": "",
		"count": 0,
		"kind": "feature",
		"line_index": -1,
		"multiplier": 1,
		"amount": maxi(0, award),
		"reason": "%s feature total" % mode.replace("_", " ").capitalize(),
		"tier": _win_tier(award, maxi(1, int(active_bonus.get("stake", 1))), "feature", jackpot_tier),
	}


func _line_attribution(grid: Array, family_id: String, reel_count: int, center_row: int, forced_placement: Dictionary = {}) -> Dictionary:
	var forced_cells: Array = _copy_array(forced_placement.get("cells", []))
	if not forced_cells.is_empty():
		var forced_symbol := str(forced_placement.get("symbol", ""))
		var multiplier_forced := 1
		for cell_value in forced_cells:
			var cell: Dictionary = _copy_dict(cell_value)
			multiplier_forced *= _symbol_multiplier(_cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0))))
		return {
			"cells": forced_cells,
			"symbol": forced_symbol,
			"count": forced_cells.size(),
			"multiplier": maxi(1, multiplier_forced),
			"kind": str(forced_placement.get("kind", "ways" if family_id == "buffalo" and reel_count > 3 else "line")),
			"line_index": int(forced_placement.get("line_index", -1)),
		}
	if family_id == "buffalo":
		var buffalo_line: Dictionary = _buffalo_full_line_attribution(grid, reel_count)
		if not buffalo_line.is_empty():
			return buffalo_line
	var symbol := ""
	for reel_index in range(reel_count):
		var cell_symbol := _cell_symbol(grid, reel_index, center_row)
		if not _wild_symbol(cell_symbol, family_id) and cell_symbol != "BLANK":
			symbol = cell_symbol
			break
	if symbol.is_empty():
		symbol = "BUFFALO" if family_id == "buffalo" else "BALL"
	var cells: Array = []
	var multiplier := 1
	for reel_index in range(reel_count):
		var current_symbol := _cell_symbol(grid, reel_index, center_row)
		if current_symbol == symbol or _wild_symbol(current_symbol, family_id):
			cells.append({"reel": reel_index, "row": center_row})
			multiplier *= _symbol_multiplier(current_symbol)
		else:
			break
	if cells.size() < mini(3, reel_count):
		cells = MathScript.line_cells(mini(3, reel_count), maxi(1, _grid_row_count(grid)), center_row)
	return {
		"cells": cells,
		"symbol": symbol,
		"count": cells.size(),
		"multiplier": maxi(1, multiplier),
		"kind": "ways" if family_id == "buffalo" and reel_count > 3 else "line",
		"line_index": center_row,
	}


func _buffalo_full_line_attribution(grid: Array, reel_count: int) -> Dictionary:
	var row_count := _grid_row_count(grid)
	for line_index in range(MathScript.payline_count(row_count)):
		var cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		var symbol := ""
		var multiplier := 1
		var compatible := true
		for cell_value in cells:
			var cell: Dictionary = _copy_dict(cell_value)
			var current_symbol := _cell_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1)))
			if current_symbol == "BLANK":
				compatible = false
				break
			if _wild_symbol(current_symbol, "buffalo"):
				multiplier *= _symbol_multiplier(current_symbol)
				continue
			if symbol.is_empty():
				symbol = current_symbol
				continue
			if current_symbol != symbol:
				compatible = false
				break
		if compatible:
			if symbol.is_empty():
				symbol = "BUFFALO"
			return {
				"cells": cells,
				"symbol": symbol,
				"count": cells.size(),
				"multiplier": maxi(1, multiplier),
				"kind": "line",
				"line_index": line_index,
			}
	return {}


func _placement_cells(placement: Dictionary, expected_symbol: String) -> Array:
	if placement.is_empty():
		return []
	var symbol := str(placement.get("symbol", ""))
	if not symbol.is_empty() and symbol != expected_symbol:
		return []
	return _copy_array(placement.get("cells", []))


func _symbol_cells(grid: Array, symbol_id: String) -> Array:
	var result: Array = []
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			if str(column[row_index]) == symbol_id:
				result.append({"reel": reel_index, "row": row_index})
	return result


func _cell_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return "BLANK"
	return str(column[row_index])


func _grid_row_count(grid: Array) -> int:
	if grid.is_empty() or typeof(grid[0]) != TYPE_ARRAY:
		return 1
	return maxi(1, (grid[0] as Array).size())


func _wild_symbol(symbol: String, family_id: String) -> bool:
	if family_id == "buffalo":
		return symbol == "SUNSET" or symbol == "SUNSET_2X" or symbol == "SUNSET_3X"
	return symbol == "WILD" or symbol == "DOUBLE" or symbol == "DOUBLE_7"


func _symbol_multiplier(symbol: String) -> int:
	if symbol == "SUNSET_3X":
		return 3
	if symbol == "SUNSET_2X" or symbol == "DOUBLE" or symbol == "DOUBLE_7":
		return 2
	return 1


func _ways_hint(grid: Array, symbol_id: String) -> int:
	var ways := 1
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		var matches := 0
		for symbol_value in column:
			var symbol := str(symbol_value)
			if symbol == symbol_id or _wild_symbol(symbol, "buffalo"):
				matches += 1
		if matches <= 0:
			break
		ways *= matches
	return maxi(1, ways)


func _ways_hint_for_cells(grid: Array, symbol_id: String, cells: Array) -> int:
	if cells.is_empty():
		return _ways_hint(grid, symbol_id)
	var reel_lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		if reel_index >= 0 and reel_index < grid.size():
			reel_lookup[reel_index] = true
	if reel_lookup.is_empty():
		return _ways_hint(grid, symbol_id)
	var ways := 1
	for reel_value in reel_lookup.keys():
		var reel_index := int(reel_value)
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		var matches := 0
		for symbol_value in column:
			var symbol := str(symbol_value)
			if symbol == symbol_id or _wild_symbol(symbol, "buffalo"):
				matches += 1
		ways *= maxi(1, matches)
	return maxi(1, ways)


func _win_tier(amount: int, stake: int, kind: String, jackpot_tier: String) -> String:
	var safe_stake := maxi(1, stake)
	if not jackpot_tier.is_empty():
		if jackpot_tier == "grand" or jackpot_tier == "major":
			return "jackpot"
		return "big"
	if amount <= 0:
		return "feature" if kind == "feature" else "none"
	if amount >= safe_stake * 250:
		return "jackpot"
	if amount >= safe_stake * 80:
		return "mega"
	if amount >= safe_stake * 20:
		return "big"
	if kind == "feature":
		return "feature"
	return "line"


func _celebration_duration_msec(tier: String) -> int:
	match tier:
		"jackpot":
			return 3000
		"mega":
			return 2200
		"big":
			return 1600
		"feature":
			return 1200
		"line":
			return 900
		_:
			return 0


func _apply_win_attribution(machine: Dictionary, win_attribution: Dictionary) -> void:
	machine["slot_win_cells"] = _copy_array(win_attribution.get("cells", []))
	machine["slot_win_symbol"] = str(win_attribution.get("symbol", ""))
	machine["slot_win_count"] = maxi(0, int(win_attribution.get("count", 0)))
	machine["slot_win_kind"] = str(win_attribution.get("kind", "none"))
	machine["slot_win_line_index"] = int(win_attribution.get("line_index", -1))
	machine["slot_win_multiplier"] = maxi(1, int(win_attribution.get("multiplier", 1)))
	machine["slot_win_amount"] = maxi(0, int(win_attribution.get("amount", 0)))
	machine["slot_win_reason"] = str(win_attribution.get("reason", ""))
	machine["slot_celebration_tier"] = str(win_attribution.get("tier", "none"))


func _capture_previous_result(machine: Dictionary) -> void:
	machine["previous_result_payout"] = maxi(0, int(machine.get("last_payout", 0)))
	machine["previous_result_net"] = int(machine.get("last_net", 0))
	machine["previous_result_classification"] = str(machine.get("last_classification", "idle"))
	machine["previous_result_reason"] = str(machine.get("slot_win_reason", ""))


func _result_win_fields(machine: Dictionary) -> Dictionary:
	return {
		"slot_win_cells": _copy_array(machine.get("slot_win_cells", [])),
		"slot_win_symbol": str(machine.get("slot_win_symbol", "")),
		"slot_win_count": maxi(0, int(machine.get("slot_win_count", 0))),
		"slot_win_kind": str(machine.get("slot_win_kind", "none")),
		"slot_win_line_index": int(machine.get("slot_win_line_index", -1)),
		"slot_win_multiplier": maxi(1, int(machine.get("slot_win_multiplier", 1))),
		"slot_win_amount": maxi(0, int(machine.get("slot_win_amount", 0))),
		"slot_win_reason": str(machine.get("slot_win_reason", "")),
		"slot_celebration_tier": str(machine.get("slot_celebration_tier", "none")),
	}


func _blocked_result(machine: Dictionary, action_id: String, stake: int, environment: Dictionary, message: String) -> Dictionary:
	return {
		"machine": machine,
		"result": GameModule.build_action_result({
			"ok": false,
			"type": "game_action",
			"source_id": "slot",
			"game_id": "slot",
			"action_id": action_id,
			"action_kind": "legal",
			"stake": stake,
			"environment_id": str(environment.get("id", "")),
			"message": message,
		}),
	}


func _zero_result(_machine: Dictionary, action_id: String, environment: Dictionary, message: String) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "slot",
		"game_id": "slot",
		"action_id": action_id,
		"action_kind": "bonus",
		"stake": 0,
		"deltas": deltas,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result[HOST_APPLY_FLAG] = true
	return result


func _family_hook(family_id: String):
	if family_id == "buffalo":
		return buffalo
	return pinball


func _family_hook_strict(family_id: String):
	if family_id == "pinball":
		return pinball
	if family_id == "buffalo":
		return buffalo
	return null


func _normalize_action(action_id: String) -> String:
	match action_id:
		"slot_spin", "spin":
			return SPIN_ACTION
		"slot_nudge", "nudge":
			return NUDGE_ACTION
		_:
			return action_id


func _normalize_bonus_action(action_id: String) -> String:
	match action_id:
		"launch":
			return "slot_bonus_launch"
		"left":
			return "slot_bonus_left"
		"right":
			return "slot_bonus_right"
		"tilt":
			return "slot_bonus_tilt"
		_:
			return action_id


func _blank_grid(reel_count: int, row_count: int) -> Array:
	var grid: Array = []
	for _reel_index in range(maxi(1, reel_count)):
		var column: Array = []
		for _row_index in range(maxi(1, row_count)):
			column.append("BLANK")
		grid.append(column)
	return grid


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
