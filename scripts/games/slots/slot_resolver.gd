class_name SlotResolver
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const BuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")

const SPIN_ACTION := "spin"
const NUDGE_ACTION := "nudge"
const BONUS_WATCHDOG_ACTION := "slot_bonus_watchdog"
const HOST_APPLY_FLAG := "host_apply_result"
const WIN_REVEAL_BEAT_SEC := 0.18
const BUFFALO_BONUS_MAX_ANIMATION_MSEC := 10000
const NUDGE_CHAIN_MAX_COINS := 5
const NUDGE_CHAIN_PEEK_CYCLE_MSEC := 1200
const NUDGE_CHAIN_FIRST_READY_PADDING_MSEC := 340
const NUDGE_CHAIN_PERFECT_MSEC := 75
const NUDGE_CHAIN_GOOD_MSEC := 210
const NUDGE_CHAIN_MISS_GRACE_MSEC := 140
const NUDGE_CHAIN_EXTRA_ATTEMPTS := 1

var pinball
var buffalo


func _init() -> void:
	pinball = PinballScript.new()
	buffalo = BuffaloScript.new()


func resolve_spin(machine: Dictionary, action_id: String, selected_bet: Dictionary, rng: RngStream, definition: Dictionary, environment: Dictionary = {}, normalize_machine: bool = true, audit_metrics_mode: bool = false, run_state: RunState = null, item_effects: Dictionary = {}, ui_state: Dictionary = {}) -> Dictionary:
	if normalize_machine:
		machine = StateScript.normalize(machine)
	var normalized_action := _normalize_action(action_id)
	var resolved_item_effects: Dictionary = item_effects.duplicate(true)
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
		var resolved_nudge: Dictionary = _resolve_reel_shift_nudge_offer(machine, family, offer, selected_bet, definition, ui_state)
		entry = _copy_dict(resolved_nudge.get("entry", {}))
		grid = _copy_array(resolved_nudge.get("grid", []))
		stops = _copy_array(resolved_nudge.get("stops", []))
		nudge_event = _copy_dict(resolved_nudge.get("tease_event", {}))
		nudge_applied = true
	else:
		entry = _select_entry(machine, family, definition, rng, free_spin, resolved_item_effects)
		entry = _apply_lucky_reel_grease_entry(machine, family, definition, rng, entry, normalized_action, stake_cost)
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
		if str(entry.get("classification", "")) == "near_miss":
			var prepared_nudge: Dictionary = _prepare_near_miss_nudge_target(machine, family, entry, grid, stops, selected_bet, definition)
			entry = _copy_dict(prepared_nudge.get("entry", entry))
			grid = _copy_array(prepared_nudge.get("grid", grid))
			stops = _copy_array(prepared_nudge.get("stops", stops))
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
			active_bonus = family.open_feature(machine, stake, rng, definition, resolved_item_effects)
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
	if is_cheat:
		_apply_slot_nudge_item_heat_state(machine, resolved_item_effects, nudge_event)
	var cross_effects: Dictionary = _slot_resolve_cross_effects(immediate_payout, stake, stake_cost, base_bankroll_delta, is_cheat, normalized_action, run_state, definition, environment, machine, resolved_item_effects)
	var luck_payout_bonus := int(cross_effects.get("luck_payout_bonus", 0))
	var item_payout_bonus := int(cross_effects.get("item_payout_bonus", 0))
	var item_loss_reduction := int(cross_effects.get("item_loss_reduction", 0))
	var slot_loss_refund := int(cross_effects.get("slot_loss_refund", 0))
	if luck_payout_bonus + item_payout_bonus > 0:
		immediate_payout = maxi(1, immediate_payout + luck_payout_bonus + item_payout_bonus)
	var bankroll_delta := immediate_payout - stake_cost
	if item_loss_reduction > 0 and bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + item_loss_reduction)
	if slot_loss_refund > 0 and bankroll_delta < 0:
		immediate_payout += slot_loss_refund
		bankroll_delta = mini(0, bankroll_delta + slot_loss_refund)
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
		machine["last_nudge_offer"] = _nudge_offer(machine, family, entry, grid, stops, classification, nudge_applied, selected_bet, definition, resolved_item_effects)
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
	machine["last_nudge_offer"] = _nudge_offer(machine, family, entry, grid, stops, classification, nudge_applied, selected_bet, definition, resolved_item_effects)
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
	var normalized_action := _normalize_bonus_action(action_id)
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
	var bonus_ui_state: Dictionary = ui_state.duplicate(true)
	bonus_ui_state["slot_item_effects"] = item_effects.duplicate(true)
	var step: Dictionary = family.step_bonus(machine, normalized_action, rng, definition, bonus_ui_state)
	_apply_bonus_step_display(machine, family_id, active_before, step)
	var complete := bool(step.get("complete", false))
	var award := maxi(0, int(step.get("award", 0)))
	if complete and award <= 0:
		award = _bonus_completion_award_from_step(step)
		if award > 0:
			step["award"] = award
	var luck_payout_bonus := 0
	var item_payout_bonus := 0
	var first_bonus_item_award := 0
	if award > 0:
		luck_payout_bonus = run_state.luck_payout_bonus(maxi(1, int(active_before.get("stake", 1))), true) if run_state != null else 0
		item_payout_bonus = int(item_effects.get("win_bonus", 0)) + int(item_effects.get("payout_delta", 0))
	if luck_payout_bonus + item_payout_bonus > 0:
		award = maxi(1, award + luck_payout_bonus + item_payout_bonus)
		step["award"] = award
		step["luck_payout_bonus"] = luck_payout_bonus
		step["item_payout_bonus"] = item_payout_bonus
	if award > 0:
		first_bonus_item_award = _slot_first_bonus_item_award(machine, award, item_effects)
		if first_bonus_item_award > 0:
			award += first_bonus_item_award
			step["award"] = award
			step["slot_first_bonus_item_award"] = first_bonus_item_award
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
		var completed_active: Dictionary = _finalize_bonus_completion_state(machine, active_before, step, award)
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
		"watchdog": normalized_action == BONUS_WATCHDOG_ACTION,
		"payout": award,
		"luck_payout_bonus": luck_payout_bonus,
		"item_payout_bonus": item_payout_bonus,
		"slot_first_bonus_item_award": first_bonus_item_award,
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
	result["slot_animation_id"] = str(machine.get("slot_animation_id", ""))
	result["slot_animation_duration_msec"] = int(machine.get("slot_animation_duration_msec", 0))
	result["slot_reel_timeline"] = _copy_array(machine.get("slot_reel_timeline", []))
	result["slot_reel_stop_times"] = _copy_array(machine.get("slot_reel_stop_times", []))
	result["slot_luck_payout_bonus"] = luck_payout_bonus
	result["slot_item_payout_bonus"] = item_payout_bonus
	result["slot_first_bonus_item_award"] = first_bonus_item_award
	result["slot_luck_win_chance_ignored"] = true
	result["slot_bonus_watchdog"] = normalized_action == BONUS_WATCHDOG_ACTION
	if complete:
		result.merge(_result_win_fields(machine), true)
	return {"machine": StateScript.normalize(machine), "result": result}


func _bonus_completion_award_from_step(step: Dictionary) -> int:
	var active: Dictionary = _copy_dict(step.get("active_bonus", {}))
	return maxi(maxi(maxi(0, int(active.get("awarded", 0))), int(active.get("feature_total", 0))), int(active.get("pending_award", 0)))


func _finalize_bonus_completion_state(machine: Dictionary, active_before: Dictionary, step: Dictionary, award: int) -> Dictionary:
	var completed_active: Dictionary = _copy_dict(step.get("active_bonus", {}))
	if completed_active.is_empty():
		completed_active = active_before.duplicate(true)
	var visual_total := maxi(maxi(maxi(0, award), int(completed_active.get("awarded", 0))), maxi(int(completed_active.get("feature_total", 0)), int(completed_active.get("pending_award", 0))))
	completed_active["active"] = false
	completed_active["complete"] = true
	completed_active["visual_replay"] = false
	completed_active["awarded"] = visual_total
	completed_active["feature_total"] = visual_total
	completed_active["pending_award"] = visual_total
	completed_active["remaining_steps"] = 0
	completed_active["balls_remaining"] = 0
	completed_active["active_ball_count"] = 0
	completed_active["launch_in_progress"] = false
	completed_active["respins_remaining"] = 0
	machine["last_bonus_replay"] = completed_active.duplicate(true)
	machine["last_bonus_total"] = visual_total
	machine["last_bonus_mode"] = str(completed_active.get("mode", active_before.get("mode", "")))
	machine["active_bonus"] = {"active": false, "complete": true}
	machine["slot_pending_feature_alert"] = false
	machine.erase("slot_pending_feature_alert_msec")
	machine.erase("slot_bonus_watchdog_since_msec")
	step["active_bonus"] = completed_active.duplicate(true)
	return completed_active


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
		machine["active_bonus"] = metric_active
	while StateScript.active_bonus_incomplete(machine) and guard < 80:
		var action_id := "slot_bonus_launch"
		var active: Dictionary = _copy_dict(machine.get("active_bonus", {}))
		if str(active.get("mode", "")) == "wheel":
			action_id = "slot_bonus_right"
		var step: Dictionary = family.step_bonus(machine, action_id, rng, definition)
		if bool(step.get("complete", false)):
			total += int(step.get("award", 0))
			if family_id == "buffalo":
				var completed_active: Dictionary = _copy_dict(step.get("active_bonus", {}))
				if int(completed_active.get("grand_prize_awarded", step.get("grand_prize_awarded", 0))) > 0:
					var bet_id := str(completed_active.get("bet_id", _copy_dict(metric_active_source.get("bet_ladder", {})).get("selected_id", "bet_2")))
					buffalo.reset_grand_prize(machine, maxi(1, int(completed_active.get("stake", 1))), bet_id)
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


func _select_entry(machine: Dictionary, family, definition: Dictionary, rng: RngStream, free_spin: bool, item_effects: Dictionary = {}) -> Dictionary:
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
	return MathScript.weighted_pick(_slot_item_adjusted_outcome_table(machine, family, definition, free_spin, item_effects), rng)


func _slot_item_adjusted_outcome_table(machine: Dictionary, family, definition: Dictionary, free_spin: bool, item_effects: Dictionary) -> Array:
	var table: Array = family.outcome_table(machine, definition, free_spin)
	if free_spin:
		return table
	var feature_bonus_percent := maxi(0, int(item_effects.get("slot_feature_weight_bonus_percent", 0)))
	var reel_win_percent := clampi(int(item_effects.get("slot_reel_win_weight_percent", 100)), 0, 1000)
	if feature_bonus_percent <= 0 and reel_win_percent == 100:
		return table
	var result: Array = []
	for entry_value in table:
		var entry: Dictionary = _copy_dict(entry_value)
		var base_weight := maxi(0, int(entry.get("weight", 0)))
		var classification := str(entry.get("classification", ""))
		if base_weight <= 0:
			result.append(entry)
			continue
		if family != null and bool(family.opens_feature(classification)):
			entry["weight"] = maxi(1, int(round(float(base_weight) * float(100 + feature_bonus_percent) / 100.0)))
			entry["slot_item_weight_adjusted"] = true
		elif classification == "ldw" or classification == "true_win":
			entry["weight"] = maxi(1, int(round(float(base_weight) * float(reel_win_percent) / 100.0)))
			entry["slot_item_weight_adjusted"] = true
		result.append(entry)
	return result


func _apply_lucky_reel_grease_entry(machine: Dictionary, family, definition: Dictionary, rng: RngStream, entry: Dictionary, action_id: String, stake_cost: int) -> Dictionary:
	if action_id != SPIN_ACTION or stake_cost <= 0:
		return entry
	var item_state: Dictionary = _copy_dict(machine.get("slot_item_state", {}))
	var remaining := maxi(0, int(item_state.get("lucky_reel_grease_spins", 0)))
	if remaining <= 0:
		item_state["lucky_reel_grease_last_tease"] = false
		machine["slot_item_state"] = item_state
		return entry
	var target := maxi(1, int(item_state.get("lucky_reel_grease_target", 3)))
	var current := clampi(int(item_state.get("lucky_reel_grease_near_misses", 0)), 0, target)
	var needed := maxi(0, target - current)
	var force_near_miss: bool = needed > 0 and rng.randi_range(1, remaining) <= needed
	var classification := str(entry.get("classification", "zero_loss"))
	var selected_opens_feature: bool = family != null and bool(family.opens_feature(classification))
	var adjusted: Dictionary = entry.duplicate(true)
	if force_near_miss:
		adjusted = _entry_for_classification(machine, family, definition, "near_miss")
		adjusted["lucky_reel_grease_forced"] = true
		current += 1
	elif selected_opens_feature or classification == "near_miss":
		adjusted = _entry_for_classification(machine, family, definition, "zero_loss")
		adjusted["lucky_reel_grease_blocked_bonus"] = selected_opens_feature
	adjusted["lucky_reel_grease_active"] = true
	remaining -= 1
	if remaining <= 0:
		item_state.erase("lucky_reel_grease_spins")
		item_state.erase("lucky_reel_grease_target")
		item_state.erase("lucky_reel_grease_near_misses")
	else:
		item_state["lucky_reel_grease_spins"] = remaining
		item_state["lucky_reel_grease_target"] = target
		item_state["lucky_reel_grease_near_misses"] = current
	item_state["lucky_reel_grease_last_tease"] = str(adjusted.get("classification", "")) == "near_miss"
	machine["slot_item_state"] = item_state
	return adjusted


func _apply_slot_nudge_item_heat_state(machine: Dictionary, item_effects: Dictionary, nudge_event: Dictionary) -> void:
	var item_state: Dictionary = _copy_dict(machine.get("slot_item_state", {}))
	var cold_charges := maxi(0, int(item_state.get("cold_quarters_charges", 0)))
	if cold_charges > 0:
		var reduction := maxi(0, int(item_effects.get("slot_cold_quarter_heat_reduction", 0)))
		if reduction > 0:
			item_effects["cheat_suspicion_delta"] = int(item_effects.get("cheat_suspicion_delta", 0)) - reduction
			item_effects["slot_cold_quarter_used"] = true
			cold_charges -= 1
			if cold_charges <= 0:
				item_state.erase("cold_quarters_charges")
			else:
				item_state["cold_quarters_charges"] = cold_charges
			item_effects["slot_cold_quarters_remaining"] = cold_charges
	var skill_outcome := str(nudge_event.get("skill_outcome", ""))
	if bool(nudge_event.get("lucky_reel_grease_active", false)) and (skill_outcome == "clean_miss" or skill_outcome == "blown"):
		var heat_bonus := maxi(0, int(item_state.get("lucky_reel_grease_failed_nudge_heat_bonus", 14)))
		item_effects["cheat_suspicion_delta"] = int(item_effects.get("cheat_suspicion_delta", 0)) + heat_bonus
		item_effects["slot_grease_failed_nudge_heat_bonus_applied"] = heat_bonus
	machine["slot_item_state"] = item_state


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


func _nudge_offer(machine: Dictionary, family, entry: Dictionary, grid: Array, stops: Array, classification: String, nudge_applied: bool, selected_bet: Dictionary = {}, definition: Dictionary = {}, item_effects: Dictionary = {}) -> Dictionary:
	if nudge_applied:
		return {}
	if classification != "near_miss":
		return {}
	return _coin_chain_offer(machine, family, entry, grid, stops, classification, selected_bet, definition, item_effects)


func _coin_chain_offer(machine: Dictionary, family, entry: Dictionary, grid: Array, stops: Array, classification: String, selected_bet: Dictionary = {}, definition: Dictionary = {}, item_effects: Dictionary = {}) -> Dictionary:
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var coin_count := clampi(row_count, 1, NUDGE_CHAIN_MAX_COINS)
	var stop_times := _rough_stop_times_for_machine(machine)
	var last_stop := 0.86
	for stop_value in stop_times:
		last_stop = maxf(last_stop, float(stop_value))
	var first_ready := int(round(last_stop * 1000.0)) + NUDGE_CHAIN_FIRST_READY_PADDING_MSEC
	var perfect_bonus := maxi(0, int(item_effects.get("slot_nudge_perfect_msec_bonus", 0)))
	var good_bonus := maxi(0, int(item_effects.get("slot_nudge_close_msec_bonus", 0)))
	var item_state: Dictionary = _copy_dict(machine.get("slot_item_state", {}))
	var split_note_armed := bool(item_state.get("split_reel_note_armed", false))
	if split_note_armed:
		perfect_bonus += maxi(0, int(item_effects.get("slot_split_reel_note_perfect_msec_bonus", 55)))
		good_bonus += maxi(0, int(item_effects.get("slot_split_reel_note_close_msec_bonus", 90)))
		item_state["split_reel_note_armed"] = false
		machine["slot_item_state"] = item_state
	var perfect_width := NUDGE_CHAIN_PERFECT_MSEC + perfect_bonus
	var good_width := maxi(perfect_width, NUDGE_CHAIN_GOOD_MSEC + good_bonus)
	var coins: Array = []
	for index in range(coin_count):
		coins.append({
			"index": index,
			"row": index,
			"side": "left" if index % 2 == 0 else "right",
			"ready_msec": first_ready if index == 0 else -1,
			"phase_offset_msec": index * 160,
			"collected": false,
			"grade": "",
			"award": 0,
			"spawned": index == 0,
		})
	var first_apex := first_ready + NUDGE_CHAIN_PEEK_CYCLE_MSEC / 2
	var max_attempts := coin_count + NUDGE_CHAIN_EXTRA_ATTEMPTS
	var duration := first_ready + NUDGE_CHAIN_PEEK_CYCLE_MSEC * (coin_count + NUDGE_CHAIN_EXTRA_ATTEMPTS + 1)
	var nudge_target: Dictionary = _nudge_target_payload(machine, family, entry, grid, stops, selected_bet, definition)
	return {
		"type": "coin_chain",
		"outcome_id": str(entry.get("id", "")),
		"classification": classification,
		"original_classification": classification,
		"grid": MathScript.clone_grid(grid),
		"stops": stops.duplicate(true),
		"spin_count": int(machine.get("spin_count", 0)),
		"event_id": "nudge-chain:%s:%d" % [str(machine.get("machine_key", "")), int(machine.get("spin_count", 0)) + 1],
		"family": str(machine.get("type_id", "pinball")),
		"format_id": str(machine.get("format_id", "classic_3_reel")),
		"coin_count": coin_count,
		"coins": coins,
		"active_index": 0,
		"collected_count": 0,
		"collected": [],
		"attempt_count": 0,
		"max_attempts": max_attempts,
		"banked_payout": 0,
		"peek_cycle_msec": NUDGE_CHAIN_PEEK_CYCLE_MSEC,
		"first_ready_msec": first_ready,
		"duration_msec": duration,
		"skill_perfect_msec": perfect_width,
		"skill_good_msec": good_width,
		"skill_close_msec": good_width,
		"skill_window_msec": {
			"start": first_apex - good_width,
			"perfect": first_apex,
			"end": first_apex + good_width,
		},
		"nudge_target": nudge_target,
		"lucky_reel_grease_active": bool(item_state.get("lucky_reel_grease_last_tease", false)) or bool(entry.get("lucky_reel_grease_active", false)),
		"split_reel_note": split_note_armed,
		"post_spin_available": true,
	}


func _prepare_near_miss_nudge_target(machine: Dictionary, family, entry: Dictionary, grid: Array, stops: Array, selected_bet: Dictionary, definition: Dictionary) -> Dictionary:
	var prepared_entry: Dictionary = entry.duplicate(true)
	var prepared_grid: Array = MathScript.clone_grid(grid)
	var prepared_stops: Array = _normalized_stops(stops, maxi(1, int(machine.get("reel_count", 3))))
	var context: Dictionary = _nudge_context_from_entry(machine, prepared_entry)
	if context.is_empty():
		return {"entry": prepared_entry, "grid": prepared_grid, "stops": prepared_stops}
	var missing_cells: Array = _copy_array(context.get("missing_cells", []))
	if missing_cells.is_empty():
		missing_cells = _copy_array(context.get("skill_line_cells", []))
	var symbol := str(context.get("symbol", ""))
	if symbol.is_empty():
		return {"entry": prepared_entry, "grid": prepared_grid, "stops": prepared_stops}
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var strips: Array = _copy_array(machine.get("reel_strips", []))
	for cell_value in missing_cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := clampi(int(cell.get("reel", 0)), 0, reel_count - 1)
		var row_index := clampi(int(cell.get("row", 0)), 0, row_count - 1)
		var strip: Array = _reel_strip(strips, reel_index)
		if strip.is_empty():
			continue
		for direction_value in [1, -1]:
			var direction := int(direction_value)
			for symbol_index in range(strip.size()):
				if str(strip[symbol_index]) != symbol:
					continue
				var target_stop := posmod(symbol_index - row_index, strip.size())
				var current_stop := posmod(target_stop - direction, strip.size())
				if current_stop == target_stop:
					continue
				var candidate_stops: Array = prepared_stops.duplicate(true)
				candidate_stops[reel_index] = current_stop
				var candidate_grid: Array = MathScript.project_grid(strips, candidate_stops, reel_count, row_count)
				_preserve_nudge_context_cells(candidate_grid, prepared_grid, context, reel_index, row_index)
				if _cell_symbol(candidate_grid, reel_index, row_index) == symbol:
					continue
				_scrub_unprotected_nudge_symbols(candidate_grid, machine, context, reel_index, row_index)
				var base_eval: Dictionary = _evaluate_nudge_grid(machine, family, candidate_grid, selected_bet, definition)
				if bool(base_eval.get("feature_triggered", false)) or int(base_eval.get("payout", 0)) > 0:
					continue
				prepared_entry["nudge_target"] = {
					"reel": reel_index,
					"row": row_index,
					"symbol": symbol,
					"direction": direction,
					"current_stop": current_stop,
					"target_stop": target_stop,
				}
				return {"entry": prepared_entry, "grid": candidate_grid, "stops": candidate_stops}
	return {"entry": prepared_entry, "grid": prepared_grid, "stops": prepared_stops}


func _nudge_context_from_entry(machine: Dictionary, entry: Dictionary) -> Dictionary:
	var placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var symbol := str(placement.get("symbol", ""))
	if symbol.is_empty():
		symbol = "GOLD_TOKEN" if str(machine.get("type_id", "")) == "buffalo" else "PINBALL"
	var present_cells: Array = _copy_array(placement.get("cells", []))
	var skill_line_cells: Array = _copy_array(placement.get("skill_line_cells", []))
	if skill_line_cells.is_empty() and not present_cells.is_empty():
		skill_line_cells = _infer_nudge_skill_line(machine, placement, present_cells)
	if skill_line_cells.is_empty():
		return {}
	var present_lookup: Dictionary = _cell_lookup_for_nudge(present_cells)
	var missing_cells: Array = []
	for cell_value in skill_line_cells:
		var cell: Dictionary = _copy_dict(cell_value)
		if not bool(present_lookup.get(_nudge_cell_key(int(cell.get("reel", -1)), int(cell.get("row", -1))), false)):
			missing_cells.append(cell)
	return {
		"symbol": symbol,
		"present_cells": present_cells,
		"skill_line_cells": skill_line_cells,
		"missing_cells": missing_cells,
	}


func _infer_nudge_skill_line(machine: Dictionary, placement: Dictionary, present_cells: Array) -> Array:
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var sorted_cells: Array = _cells_sorted_by_reel(present_cells)
	var first_cell: Dictionary = _copy_dict(sorted_cells[0]) if not sorted_cells.is_empty() else {}
	var start_reel := clampi(int(first_cell.get("reel", 0)), 0, reel_count - 1)
	var line_index := int(placement.get("line_index", int(first_cell.get("row", row_count / 2))))
	var target_count := mini(3, reel_count - start_reel)
	if target_count < mini(3, reel_count):
		start_reel = maxi(0, reel_count - mini(3, reel_count))
		target_count = mini(3, reel_count)
	return MathScript.payline_cells_from(reel_count, row_count, line_index, start_reel, target_count)


func _preserve_nudge_context_cells(target_grid: Array, source_grid: Array, context: Dictionary, target_reel: int, target_row: int) -> void:
	var symbol := str(context.get("symbol", ""))
	var present_lookup: Dictionary = {}
	for cell_value in _copy_array(context.get("present_cells", [])):
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index == target_reel and row_index == target_row:
			continue
		present_lookup[_nudge_cell_key(reel_index, row_index)] = true
		MathScript.set_cell(target_grid, reel_index, row_index, _cell_symbol(source_grid, reel_index, row_index))
	if symbol.is_empty():
		return
	for cell_value in _copy_array(context.get("skill_line_cells", [])):
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index == target_reel and row_index == target_row:
			continue
		if bool(present_lookup.get(_nudge_cell_key(reel_index, row_index), false)):
			continue
		MathScript.set_cell(target_grid, reel_index, row_index, symbol)


func _scrub_unprotected_nudge_symbols(grid: Array, machine: Dictionary, context: Dictionary, target_reel: int, target_row: int) -> void:
	var symbol := str(context.get("symbol", ""))
	if symbol.is_empty():
		return
	var protected: Dictionary = {}
	for cell_value in _copy_array(context.get("skill_line_cells", [])):
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index == target_reel and row_index == target_row:
			continue
		protected[_nudge_cell_key(reel_index, row_index)] = true
	for cell_value in _copy_array(context.get("present_cells", [])):
		var cell: Dictionary = _copy_dict(cell_value)
		protected[_nudge_cell_key(int(cell.get("reel", -1)), int(cell.get("row", -1)))] = true
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if str(column[row_index]) == symbol and not bool(protected.get(_nudge_cell_key(reel_index, row_index), false)):
				column[row_index] = _fallback_nudge_symbol(machine, reel_index, row_index, symbol)
		grid[reel_index] = column


func _fallback_nudge_symbol(machine: Dictionary, reel_index: int, row_index: int, avoid_symbol: String) -> String:
	var family_id := str(machine.get("type_id", "pinball"))
	var symbols := ["BUMPER", "CHERRY", "BALL", "BAR", "SPINNER", "7"]
	if family_id == "buffalo":
		symbols = ["A", "K", "Q", "J", "10", "WOLF", "ELK"]
	for offset in range(symbols.size()):
		var symbol := str(symbols[posmod(reel_index * 3 + row_index + offset, symbols.size())])
		if symbol != avoid_symbol:
			return symbol
	return "BLANK"


func _nudge_target_payload(machine: Dictionary, family, entry: Dictionary, grid: Array, stops: Array, selected_bet: Dictionary, definition: Dictionary) -> Dictionary:
	var target: Dictionary = _copy_dict(entry.get("nudge_target", {}))
	if target.is_empty():
		return {}
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var reel_index := clampi(int(target.get("reel", 0)), 0, reel_count - 1)
	var row_index := clampi(int(target.get("row", 0)), 0, maxi(0, int(machine.get("row_count", 1)) - 1))
	var direction := int(target.get("direction", 1))
	var strips: Array = _copy_array(machine.get("reel_strips", []))
	var strip: Array = _reel_strip(strips, reel_index)
	if strip.is_empty():
		return {}
	var original_stops: Array = _normalized_stops(stops, reel_count)
	var current_stop := clampi(int(target.get("current_stop", original_stops[reel_index])), 0, strip.size() - 1)
	original_stops[reel_index] = current_stop
	var target_stop := posmod(int(target.get("target_stop", current_stop + direction)), strip.size())
	var good_stop := posmod(target_stop + direction, strip.size())
	var perfect_grid: Array = _grid_with_reel_stop(machine, grid, reel_index, target_stop)
	var symbol := str(target.get("symbol", _cell_symbol(perfect_grid, reel_index, row_index)))
	if not symbol.is_empty() and _cell_symbol(perfect_grid, reel_index, row_index) != symbol:
		return {}
	var good_grid: Array = _grid_with_reel_stop(machine, grid, reel_index, good_stop)
	var perfect_stops: Array = original_stops.duplicate(true)
	perfect_stops[reel_index] = target_stop
	var good_stops: Array = original_stops.duplicate(true)
	good_stops[reel_index] = good_stop
	var perfect_eval: Dictionary = _evaluate_nudge_grid(machine, family, perfect_grid, selected_bet, definition)
	var good_eval: Dictionary = _evaluate_nudge_grid(machine, family, good_grid, selected_bet, definition)
	return {
		"reel": reel_index,
		"row": row_index,
		"symbol": symbol,
		"direction": direction,
		"current_stop": current_stop,
		"strip_size": strip.size(),
		"perfect": _nudge_candidate_payload(perfect_eval, perfect_grid, perfect_stops, reel_index, current_stop, target_stop, strip.size()),
		"good": _nudge_candidate_payload(good_eval, good_grid, good_stops, reel_index, current_stop, good_stop, strip.size()),
	}


func _nudge_candidate_payload(evaluation: Dictionary, grid: Array, stops: Array, reel_index: int, old_stop: int, new_stop: int, strip_size: int) -> Dictionary:
	return {
		"entry": _copy_dict(evaluation.get("entry", {})),
		"grid": MathScript.clone_grid(grid),
		"stops": stops.duplicate(true),
		"classification": str(evaluation.get("classification", "zero_loss")),
		"feature_triggered": bool(evaluation.get("feature_triggered", false)),
		"payout": maxi(0, int(evaluation.get("payout", 0))),
		"reel": reel_index,
		"old_stop": old_stop,
		"new_stop": new_stop,
		"shift": _signed_stop_delta(old_stop, new_stop, strip_size),
	}


func _resolve_reel_shift_nudge_offer(machine: Dictionary, family, offer: Dictionary, selected_bet: Dictionary, definition: Dictionary, ui_state: Dictionary) -> Dictionary:
	var coins: Array = _copy_array(offer.get("coins", []))
	var active_index := clampi(int(offer.get("active_index", 0)), 0, maxi(0, coins.size() - 1))
	var active_coin: Dictionary = _copy_dict(coins[active_index]) if active_index < coins.size() else {}
	var skill: Dictionary = _nudge_chain_skill_result(offer, active_coin, ui_state)
	var grade := str(skill.get("grade", "blown"))
	var original_grid: Array = MathScript.clone_grid(_copy_array(offer.get("grid", machine.get("last_grid", []))))
	var original_stops: Array = _normalized_stops(_copy_array(offer.get("stops", machine.get("reel_stops", []))), maxi(1, int(machine.get("reel_count", 3))))
	var target: Dictionary = _copy_dict(offer.get("nudge_target", {}))
	var candidate: Dictionary = {}
	if grade == "perfect":
		candidate = _copy_dict(target.get("perfect", {}))
	elif grade == "good":
		candidate = _copy_dict(target.get("good", {}))
	if candidate.is_empty():
		candidate = _nudge_candidate_payload(
			_evaluate_nudge_grid(machine, family, original_grid, selected_bet, definition),
			original_grid,
			original_stops,
			int(target.get("reel", 0)),
			int(target.get("current_stop", 0)),
			int(target.get("current_stop", 0)),
			maxi(1, int(target.get("strip_size", 1)))
		)
	var entry: Dictionary = _copy_dict(candidate.get("entry", {}))
	if entry.is_empty():
		entry = _entry_for_classification(machine, family, definition, str(candidate.get("classification", offer.get("classification", "near_miss"))))
	var event: Dictionary = {
		"type": "nudge_shift",
		"family": str(offer.get("family", machine.get("type_id", ""))),
		"skill_outcome": grade,
		"chain_grade": grade,
		"input_msec": int(skill.get("input_msec", -1)),
		"perfect_msec": int(skill.get("perfect_msec", -1)),
		"distance_msec": int(skill.get("distance_msec", 9999)),
		"reel_index": int(candidate.get("reel", target.get("reel", 0))),
		"row": int(target.get("row", active_coin.get("row", active_index))),
		"shift": int(candidate.get("shift", 0)) if grade == "perfect" or grade == "good" else 0,
		"old_stop": int(candidate.get("old_stop", target.get("current_stop", 0))),
		"new_stop": int(candidate.get("new_stop", target.get("current_stop", 0))),
		"target_symbol": str(target.get("symbol", "")),
		"converted_to": str(candidate.get("classification", "near_miss")),
		"normal_payout": maxi(0, int(candidate.get("payout", 0))),
		"feature_triggered": bool(candidate.get("feature_triggered", false)),
		"lucky_reel_grease_active": bool(offer.get("lucky_reel_grease_active", false)),
		"split_reel_note": bool(offer.get("split_reel_note", false)),
	}
	return {
		"entry": entry,
		"grid": _copy_array(candidate.get("grid", original_grid)),
		"stops": _copy_array(candidate.get("stops", original_stops)),
		"tease_event": event,
	}


func _evaluate_nudge_grid(machine: Dictionary, family, grid: Array, selected_bet: Dictionary, definition: Dictionary) -> Dictionary:
	var family_id := str(machine.get("type_id", "pinball"))
	var stake := maxi(1, int(selected_bet.get("total_credits", 2)))
	var feature_classification := _feature_classification_for_grid(machine, family_id, grid, definition)
	if not feature_classification.is_empty():
		var feature_entry: Dictionary = _entry_for_classification(machine, family, definition, feature_classification)
		feature_entry["forced_placement"] = _feature_placement_for_grid(machine, family_id, grid, feature_classification, definition)
		return {
			"classification": feature_classification,
			"feature_triggered": true,
			"payout": 0,
			"entry": feature_entry,
		}
	var line_entry: Dictionary = _entry_for_classification(machine, family, definition, "true_win")
	var payout := _grid_payout_for_family(family, grid, stake, 0, machine, definition, line_entry)
	if payout > 0:
		return {
			"classification": "true_win",
			"feature_triggered": false,
			"payout": payout,
			"entry": line_entry,
		}
	var miss_entry: Dictionary = _entry_for_classification(machine, family, definition, "near_miss")
	return {
		"classification": "near_miss",
		"feature_triggered": false,
		"payout": 0,
		"entry": miss_entry,
	}


func _feature_classification_for_grid(machine: Dictionary, family_id: String, grid: Array, definition: Dictionary) -> String:
	if family_id == "pinball":
		return "bonus" if MathScript.count_symbol(grid, "PINBALL") >= 3 else ""
	var gold_count := MathScript.count_symbol(grid, "GOLD_TOKEN")
	if gold_count <= 0:
		return ""
	var config: Dictionary = _copy_dict(definition.get("slot_buffalo_config", {}))
	var hold_config: Dictionary = _copy_dict(config.get("hold_and_spin", {}))
	var hold_trigger := clampi(int(hold_config.get("lock_trigger_count", 8)), 3, maxi(3, int(machine.get("reel_count", 3)) * int(machine.get("row_count", 1))))
	if str(machine.get("format_id", "")) != "classic_3_reel" and gold_count >= hold_trigger:
		return "hold_and_spin"
	if gold_count >= 6 and MathScript.count_symbol(grid, "BUFFALO") > 0:
		return "monster_feature"
	if gold_count >= 3:
		return "free_games"
	return ""


func _feature_placement_for_grid(machine: Dictionary, family_id: String, grid: Array, classification: String, _definition: Dictionary) -> Dictionary:
	var symbol := "GOLD_TOKEN" if family_id == "buffalo" else "PINBALL"
	var cells: Array = _symbol_cells(grid, symbol)
	if family_id == "buffalo" and classification == "monster_feature":
		cells = cells.slice(0, mini(6, cells.size()))
	elif classification == "hold_and_spin":
		cells = cells.slice(0, mini(maxi(3, int(machine.get("reel_count", 3))), cells.size()))
	else:
		cells = cells.slice(0, mini(3, cells.size()))
	return {
		"kind": "feature",
		"symbol": symbol,
		"cells": cells,
		"line_index": -1,
	}


func _grid_with_reel_stop(machine: Dictionary, base_grid: Array, reel_index: int, new_stop: int) -> Array:
	var result: Array = MathScript.clone_grid(base_grid)
	var strips: Array = _copy_array(machine.get("reel_strips", []))
	var strip: Array = _reel_strip(strips, reel_index)
	if strip.is_empty() or reel_index < 0 or reel_index >= result.size():
		return result
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var column: Array = []
	for row_index in range(row_count):
		column.append(str(strip[posmod(new_stop + row_index, strip.size())]))
	result[reel_index] = column
	return result


func _normalized_stops(stops: Array, reel_count: int) -> Array:
	var result: Array = []
	for reel_index in range(maxi(1, reel_count)):
		result.append(int(stops[reel_index]) if reel_index < stops.size() else 0)
	return result


func _reel_strip(strips: Array, reel_index: int) -> Array:
	if reel_index < 0 or reel_index >= strips.size() or typeof(strips[reel_index]) != TYPE_ARRAY:
		return []
	var result: Array = []
	var strip: Array = strips[reel_index] as Array
	for symbol_value in strip:
		result.append(str(symbol_value))
	return result


func _cell_lookup_for_nudge(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		result[_nudge_cell_key(int(cell.get("reel", -1)), int(cell.get("row", -1)))] = true
	return result


func _nudge_cell_key(reel_index: int, row_index: int) -> String:
	return "%d:%d" % [reel_index, row_index]


func _signed_stop_delta(old_stop: int, new_stop: int, strip_size: int) -> int:
	var size := maxi(1, strip_size)
	var forward := posmod(new_stop - old_stop, size)
	var backward := posmod(old_stop - new_stop, size)
	return forward if forward <= backward else -backward


func _nudge_chain_skill_result(offer: Dictionary, coin: Dictionary, ui_state: Dictionary) -> Dictionary:
	var input_msec := _nudge_chain_input_msec(ui_state)
	var ready_msec := maxi(0, int(coin.get("ready_msec", 0)))
	var cycle := maxi(1, int(offer.get("peek_cycle_msec", NUDGE_CHAIN_PEEK_CYCLE_MSEC)))
	var perfect_width := maxi(1, int(offer.get("skill_perfect_msec", NUDGE_CHAIN_PERFECT_MSEC)))
	var good_width := maxi(perfect_width, int(offer.get("skill_good_msec", offer.get("skill_close_msec", NUDGE_CHAIN_GOOD_MSEC))))
	if input_msec < 0:
		input_msec = ready_msec + cycle + good_width + 999
	var published_window: Dictionary = _copy_dict(offer.get("skill_window_msec", {}))
	if not published_window.is_empty():
		var window_start := int(published_window.get("start", ready_msec))
		var window_end := int(published_window.get("end", ready_msec + cycle))
		var window_perfect := int(published_window.get("perfect", ready_msec + cycle / 2))
		if input_msec < window_start or input_msec > window_end:
			var miss_grace := maxi(0, int(offer.get("skill_miss_grace_msec", NUDGE_CHAIN_MISS_GRACE_MSEC)))
			var near_miss := input_msec >= window_start - miss_grace and input_msec <= window_end + miss_grace
			return {
				"grade": "miss" if near_miss else "blown",
				"input_msec": input_msec,
				"perfect_msec": window_perfect,
				"distance_msec": absi(input_msec - window_perfect),
			}
	var local := input_msec - ready_msec
	var cycle_elapsed := posmod(local, cycle) if local >= 0 else -999999
	var apex_offset := cycle / 2
	var perfect_msec := ready_msec + int(floor(float(local) / float(cycle))) * cycle + apex_offset if local >= 0 else ready_msec + apex_offset
	if local >= 0 and cycle_elapsed > apex_offset + cycle / 2:
		perfect_msec += cycle
	var distance := absi(input_msec - perfect_msec)
	var grade := "miss"
	if local >= 0 and distance <= perfect_width:
		grade = "perfect"
	elif local >= 0 and distance <= good_width:
		grade = "good"
	return {
		"grade": grade,
		"input_msec": input_msec,
		"perfect_msec": perfect_msec,
		"distance_msec": distance,
	}


func _nudge_chain_input_msec(ui_state: Dictionary) -> int:
	if int(ui_state.get("slot_nudge_chain_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_nudge_chain_input_msec", -1))
	if int(ui_state.get("slot_tease_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_tease_input_msec", -1))
	var runtime: Dictionary = _copy_dict(ui_state.get("surface_runtime_status", {}))
	var animations: Dictionary = _copy_dict(runtime.get("surface_animations", {}))
	var chain: Dictionary = _copy_dict(animations.get("slot_nudge_chain", {}))
	if not chain.is_empty():
		return maxi(0, int(round(float(chain.get("elapsed", 0.0)) * 1000.0)))
	return -1


func _entry_for_classification(machine: Dictionary, family, definition: Dictionary, classification: String) -> Dictionary:
	var table: Array = family.outcome_table(machine, definition, false)
	for entry_value in table:
		var entry: Dictionary = entry_value
		if str(entry.get("classification", "")) == classification or str(entry.get("id", "")) == classification:
			return entry.duplicate(true)
	return {"id": classification, "classification": classification, "weight": 1, "payout": 0, "payout_multiplier": 0.0}


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


func _slot_first_bonus_item_award(machine: Dictionary, award: int, item_effects: Dictionary) -> int:
	var percent := maxi(0, int(item_effects.get("slot_first_bonus_bonus_percent", 0)))
	if percent <= 0 or award <= 0:
		return 0
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	if bool(bonus_state.get("neon_players_charm_used", false)):
		return 0
	var cap := maxi(1, int(item_effects.get("slot_first_bonus_bonus_cap", 40)))
	var bonus := mini(cap, maxi(1, int(round(float(award) * float(percent) / 100.0))))
	bonus_state["neon_players_charm_used"] = true
	machine["bonus_state"] = bonus_state
	return bonus


func _slot_resolve_cross_effects(payout: int, stake: int, stake_cost: int, bankroll_delta: int, is_cheat: bool, action_id: String, run_state: RunState, definition: Dictionary, environment: Dictionary, machine: Dictionary, item_effects: Dictionary) -> Dictionary:
	var effects := {
		"luck_payout_bonus": 0,
		"item_payout_bonus": 0,
		"item_loss_reduction": 0,
		"slot_loss_refund": 0,
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
	if bankroll_delta < 0 and stake_cost > 0 and str(machine.get("format_id", "")) == "classic_3_reel":
		var refund_percent := clampi(int(item_effects.get("slot_three_reel_loss_refund_percent", 0)), 0, 100)
		if refund_percent > 0:
			effects["slot_loss_refund"] = mini(absi(bankroll_delta), maxi(1, int(round(float(stake_cost) * float(refund_percent) / 100.0))))
	if is_cheat:
		var heat: Dictionary = _slot_cheat_heat(action_id, stake_basis, run_state, definition, environment, item_effects)
		for key in heat.keys():
			effects[key] = heat[key]
	effects["slot_cold_quarter_used"] = bool(item_effects.get("slot_cold_quarter_used", false))
	effects["slot_cold_quarters_remaining"] = maxi(0, int(item_effects.get("slot_cold_quarters_remaining", 0)))
	effects["slot_grease_failed_nudge_heat_bonus_applied"] = maxi(0, int(item_effects.get("slot_grease_failed_nudge_heat_bonus_applied", 0)))
	return effects


func _slot_cheat_heat(action_id: String, stake: int, run_state: RunState, definition: Dictionary, environment: Dictionary, item_effects: Dictionary) -> Dictionary:
	var cheat_def: Dictionary = _cheat_action_def(definition, action_id)
	var base_heat := int(cheat_def.get("suspicion_delta", 12))
	if run_state == null:
		return {
			"suspicion_delta": maxi(0, base_heat),
			"base_suspicion_delta": maxi(0, base_heat),
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
		"base_suspicion_delta": maxi(0, base_heat),
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
	var nudge_skill_outcome := _last_nudge_skill_outcome(machine) if action_id == NUDGE_ACTION else ""
	if action_id == NUDGE_ACTION and nudge_skill_outcome.is_empty():
		nudge_skill_outcome = "nudge_resolved"
	var nudge_skill_accuracy := _nudge_skill_accuracy(nudge_skill_outcome)
	var base_suspicion_delta := maxi(0, int(cross_effects.get("base_suspicion_delta", suspicion_delta)))
	var message := _message_for_spin(classification, payout, stake_cost, feature_triggered, active_bonus, nudge_applied)
	var slot_loss_refund := int(cross_effects.get("slot_loss_refund", 0))
	if slot_loss_refund > 0:
		message = "%s Coin-Return Shim kicks back $%d." % [message, slot_loss_refund]
	if bool(cross_effects.get("slot_cold_quarter_used", false)):
		message = "%s A Cold Quarter chills the heat." % message
	var grease_heat_bonus := int(cross_effects.get("slot_grease_failed_nudge_heat_bonus_applied", 0))
	if grease_heat_bonus > 0:
		message = "%s Grease makes the blown nudge draw extra heat." % message
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
		"slot_loss_refund": slot_loss_refund,
		"slot_cold_quarter_used": bool(cross_effects.get("slot_cold_quarter_used", false)),
		"slot_grease_failed_nudge_heat_bonus": grease_heat_bonus,
		"security_bankroll_delta": int(cross_effects.get("security_bankroll_delta", 0)),
		"skill_outcome": nudge_skill_outcome,
		"skill_grade": nudge_skill_outcome,
		"skill_accuracy": nudge_skill_accuracy,
		"skill_margin_msec": 0,
		"base_suspicion_delta": base_suspicion_delta,
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
		"skill_outcome": nudge_skill_outcome,
		"skill_grade": nudge_skill_outcome,
		"skill_accuracy": nudge_skill_accuracy,
		"skill_margin_msec": 0,
		"base_suspicion_delta": base_suspicion_delta,
		"skill_security_pressure_checked": action_id == NUDGE_ACTION,
		"security_message": security_message,
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
	result["slot_nudge_skill_outcome"] = nudge_skill_outcome
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
	result["slot_loss_refund"] = slot_loss_refund
	result["slot_cold_quarter_used"] = bool(cross_effects.get("slot_cold_quarter_used", false))
	result["slot_cold_quarters_remaining"] = int(cross_effects.get("slot_cold_quarters_remaining", 0))
	result["slot_grease_failed_nudge_heat_bonus"] = grease_heat_bonus
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
		if str(event.get("type", "")) == "nudge_shift" or str(event.get("type", "")) == "nudge_coin_chain":
			return str(event.get("skill_outcome", "legacy"))
	return ""


func _nudge_skill_accuracy(skill_outcome: String) -> int:
	var outcome := skill_outcome.to_lower()
	if outcome.find("perfect") >= 0:
		return 100
	if outcome.find("good") >= 0:
		return 75
	if outcome.find("close") >= 0 or outcome.find("partial") >= 0:
		return 50
	if outcome.find("miss") >= 0 or outcome.find("break") >= 0:
		return 0
	return 50


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
