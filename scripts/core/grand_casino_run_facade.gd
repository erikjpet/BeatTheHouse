class_name GrandCasinoRunFacade
extends RefCounted

const ROURKE_MOVE_EVALUATION_ACTIONS := 3
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

var chips := 0
var room_states: Dictionary = {}
var staffing: Dictionary = {}
var rourke_current_room := ""
var rourke_current_spot := ""
var rourke_facing := "right"
var rourke_actions_until_move := ROURKE_MOVE_EVALUATION_ACTIONS
var rourke_off_floor_actions := 0
var rourke_floor_action_index := 0
var linda_cage_state: Dictionary = {}
var room_heat_accumulators: Dictionary = {}
var rival_cheaters: Array = []
var rival_cheater_day := 0
var rourke_escort_state: Dictionary = {}
var atm_interest_boundary_index := -1
var atm_interest_notifications: Array = []
var _run_ref: WeakRef
var _run:
	get: return _run_ref.get_ref() if _run_ref != null else null
	set(value): _run_ref = weakref(value) if value != null else null

var grand_casino_chips: int:
	get: return chips
	set(value): chips = value
var grand_casino_room_states: Dictionary:
	get: return room_states
	set(value): room_states = value
var grand_casino_staffing: Dictionary:
	get: return staffing
	set(value): staffing = value
var grand_casino_room_heat_accumulators: Dictionary:
	get: return room_heat_accumulators
	set(value): room_heat_accumulators = value
var grand_casino_atm_interest_boundary_index: int:
	get: return atm_interest_boundary_index
	set(value): atm_interest_boundary_index = value
var grand_casino_atm_interest_notifications: Array:
	get: return atm_interest_notifications
	set(value): atm_interest_notifications = value


func bind(run_state: Object) -> GrandCasinoRunFacade:
	_run = run_state
	return self


func total_money(bankroll_value: int) -> int:
	return bankroll_value + chips


func chip_exchange_rate(environment: Dictionary) -> int:
	var flags: Dictionary = environment.get("local_narrative_flags", {}) if typeof(environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	return maxi(1, int(flags.get("casino_chip_cash_rate", 1)))


func grand_casino_room_environment(archetype_id: String) -> Dictionary:
	var room: Variant = grand_casino_room_states.get(archetype_id.strip_edges(), {})
	return (room as Dictionary).duplicate(true) if typeof(room) == TYPE_DICTIONARY else {}


func grand_casino_room_access_status(target_archetype_id: String, high_limit_buy_in: int = 60) -> Dictionary:
	var target_id := target_archetype_id.strip_edges()
	if not _run.is_grand_casino_environment():
		return {"available": false, "reason": "The casino interior is not available here."}
	if _run.tutorial_main_floor_only():
		if target_id == _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Locked for this lesson. The Main Floor has everything you need; a Players Card can open High-Limit on later runs."}
		if target_id == _run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Lesson lock: Rourke's Back Room can wait its turn."}
		if target_id == _run.GRAND_CASINO_ARCHETYPE_ID or target_id == _run.GRAND_CASINO_CAGE_ARCHETYPE_ID:
			return {"available": true, "access_method": "tutorial_main_floor", "cost": 0}
	if bool(_run.narrative_flags.get("grand_casino_showdown_active", false)):
		if target_id == _run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID and str(_run.narrative_flags.get("grand_casino_showdown_step", "")) == _run.GRAND_CASINO_SHOWDOWN_STEP_DUEL:
			return {"available": true, "access_method": "showdown", "cost": 0}
		return {"available": false, "locked": true, "reason": "Rourke keeps that door shut until the duel is done."}
	if target_id == _run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
		return {"available": false, "locked": true, "reason": "Locked. Rourke opens it only when the house calls."}
	if target_id == _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
		if bool(_run.narrative_flags.get("grand_casino_high_limit_access", false)):
			return {"available": true, "access_method": str(_run.narrative_flags.get("grand_casino_high_limit_access_method", "card")), "cost": 0}
		var buy_in := maxi(0, high_limit_buy_in)
		if _run.bankroll < buy_in:
			return {"available": false, "locked": true, "cash_buy_in_required": true, "cost": buy_in, "reason": "High-Limit requires Silver card access or a $%d cash buy-in." % buy_in}
		return {"available": true, "cash_buy_in_required": true, "access_method": "cash_buy_in", "cost": buy_in}
	if target_id == _run.GRAND_CASINO_ARCHETYPE_ID or target_id == _run.GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"available": true, "access_method": "interior", "cost": 0}
	return {"available": false, "reason": "That room is not part of the Grand Casino."}


func grand_casino_table_uses_chips(game_id: String, environment: Dictionary = {}) -> bool:
	return grand_casino_game_uses_chips(game_id, environment)


func grand_casino_game_uses_chips(game_id: String, environment: Dictionary = {}) -> bool:
	if not _run.GRAND_CASINO_CHIP_GAME_IDS.has(game_id):
		return false
	var source = _run.current_environment if environment.is_empty() else environment
	var archetype_id := str(source.get("archetype_id", ""))
	if _run.GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return true
	var environment_id := str(source.get("id", ""))
	if not environment_id.begins_with("grand_casino_"):
		return false
	return _run._is_grand_casino_environment(source)


func grand_casino_total_money() -> int:
	return total_money(_run.bankroll)


func grand_casino_chip_exchange_rate() -> int:
	return chip_exchange_rate(_run.current_environment)


func grand_casino_atm_debt() -> int:
	var index = _run._debt_index(_run.CageEconomyModelScript.ATM_DEBT_ID)
	if index < 0 or typeof(_run.debt[index]) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((_run.debt[index] as Dictionary).get("balance", 0)))


func grand_casino_atm_debt_entry() -> Dictionary:
	var index = _run._debt_index(_run.CageEconomyModelScript.ATM_DEBT_ID)
	return (_run.debt[index] as Dictionary).duplicate(true) if index >= 0 and typeof(_run.debt[index]) == TYPE_DICTIONARY else {}


func grand_casino_atm_status() -> Dictionary:
	var balance := grand_casino_atm_debt()
	var next_boundary = _run.CageEconomyModelScript.next_interest_boundary(_run.game_clock_minutes)
	return {
		"debt": balance,
		"cash": _run.bankroll,
		"loan_increment": _run.CageEconomyModelScript.LOAN_INCREMENT,
		"loan_cap": _run.CageEconomyModelScript.LOAN_CAP,
		"daily_interest_rate": _run.CageEconomyModelScript.DAILY_INTEREST_RATE,
		"interest_minute_of_day": _run.CageEconomyModelScript.INTEREST_MINUTE_OF_DAY,
		"next_interest_absolute_minute": next_boundary,
		"projected_next_balance": _run.CageEconomyModelScript.interest_balance(balance),
		"available_credit": maxi(0, _run.CageEconomyModelScript.LOAN_CAP - balance),
		"interest_boundary_index": grand_casino_atm_interest_boundary_index,
	}


func grand_casino_atm_pending_interest_notifications() -> Array:
	return grand_casino_atm_interest_notifications.duplicate(true)


func grand_casino_players_card_comp_result(comp_id: String) -> Dictionary:
	if not _run._is_grand_casino_environment(_run.current_environment):
		return {"ok": false, "message": "Players Card comps are available only inside the Grand Casino."}
	var status = _run.demo_objective_status()
	if not bool(status.get("players_card_eligible", false)):
		return {"ok": false, "message": "Cheat evidence closed the Players Card comp account."}
	var config := _grand_casino_objective_config(JsonCoerceScript._copy_dict(_run.current_environment.get("demo_objective", {})))
	var clean_id := comp_id.strip_edges().to_lower()
	var deltas := {
		"bankroll_delta": 0,
		"chips_delta": 0,
		"suspicion_delta": 0,
		"alcohol_intake": 0,
		"drunk_delta": 0,
		"pending_drunk_absorption_delta": 0,
		"flags_set": {},
		"story_log": [],
		"messages": [],
	}
	var message := ""
	var duration_minutes := 0
	match clean_id:
		"drink":
			var tokens := maxi(0, int(_run.narrative_flags.get("grand_casino_comp_drink_tokens", 0)))
			if tokens <= 0:
				return {"ok": false, "message": "No drink comps remain."}
			var alcohol := maxi(0, int(config.get("players_card_comp_drink_alcohol", 0)))
			var service_status = _run.service_hook_status({"id": "players_card_drink_comp", "cost": 0, "category": "alcohol", "effect": {"alcohol_intake": alcohol}})
			if not bool(service_status.get("available", false)):
				return {"ok": false, "message": str(service_status.get("disabled_reason", "The drink comp cannot help right now."))}
			deltas["alcohol_intake"] = alcohol
			(deltas["flags_set"] as Dictionary)["grand_casino_comp_drink_tokens"] = tokens - 1
			message = "Linda sends a quiet house drink to the bar."
		"suite_rest":
			var rests := maxi(0, int(_run.narrative_flags.get("grand_casino_comp_suite_rests", 0)))
			if rests <= 0:
				return {"ok": false, "message": "No suite rests remain."}
			var heat_recovery := mini(_run.suspicion_level(), maxi(0, int(config.get("players_card_suite_heat_recovery", 0))))
			var drunk_recovery := mini(_run.drunk_level, maxi(0, int(config.get("players_card_suite_drunk_recovery", 0))))
			duration_minutes = maxi(0, int(config.get("players_card_suite_rest_minutes", 0)))
			deltas["suspicion_delta"] = -heat_recovery
			deltas["drunk_delta"] = -drunk_recovery
			deltas["pending_drunk_absorption_delta"] = -_run.pending_drunk_absorption_amount()
			(deltas["flags_set"] as Dictionary)["grand_casino_comp_suite_rests"] = rests - 1
			message = "Linda turns the suite key. Four quiet hours clear your head."
		_:
			return {"ok": false, "message": "That Players Card comp is not available."}
	var story_entry := {
		"type": "service_hook",
		"id": "players_card_%s_comp" % clean_id,
		"label": "Players Card %s" % clean_id.replace("_", " ").capitalize(),
		"environment_id": str(_run.current_environment.get("id", "")),
		"environment_archetype_id": str(_run.current_environment.get("archetype_id", "")),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"drunk_delta": int(deltas.get("drunk_delta", 0)),
		"duration_minutes": duration_minutes,
		"message": message,
	}
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	return {
		"ok": true,
		"type": "service_hook",
		"source_id": "players_card_%s_comp" % clean_id,
		"action_id": "use_service",
		"action_kind": "service",
		"environment_id": str(_run.current_environment.get("id", "")),
		"environment_archetype_id": str(_run.current_environment.get("archetype_id", "")),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"duration_minutes": duration_minutes,
		"message": message,
	}


func _grand_casino_result_wager_funding_amount(result: Dictionary, bankroll_delta: int) -> int:
	var game_id := str(result.get("game_id", result.get("source_id", ""))).strip_edges()
	var action_id := str(result.get("action_id", "")).strip_edges()
	if game_id == "blackjack":
		if action_id != "blackjack_place_bet":
			return 0
		return maxi(0, -bankroll_delta)
	var wager := maxi(0, int(result.get("stake", 0)))
	if game_id == "roulette":
		wager = maxi(wager, int(result.get("roulette_total_wager", 0)))
	elif game_id == "baccarat":
		wager = maxi(wager, int(result.get("baccarat_total_wager", 0)))
	elif game_id == "craps":
		wager = maxi(wager, int(result.get("craps_total_wager", 0)))
	return maxi(wager, maxi(0, -bankroll_delta))


func grand_casino_prestige_status() -> Dictionary:
	var modifiers = _run.challenge_modifiers()
	var active := bool(modifiers.get("grand_casino_prestige", false))
	return {
		"active": active,
		"card_instance_ids": JsonCoerceScript._copy_array(modifiers.get("grand_casino_prestige_card_instance_ids", [])) if active else [],
		"recognition_heat_delta": mini(0, int(modifiers.get("grand_casino_prestige_recognition_heat_delta", 0))) if active else 0,
		"clean_heat_ceiling_delta": mini(0, int(modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta", 0))) if active else 0,
		"drop_tier_bonus_steps": maxi(0, int(modifiers.get("meta_collection_drop_tier_bonus_steps", 0))) if active else 0,
		"recognition_applied": bool(_run.narrative_flags.get("grand_casino_prestige_recognition_applied", false)),
	}


func grand_casino_heat_reroute_available() -> bool:
	if _run.run_status == _run.RUN_STATUS_ENDED or _run.run_status == _run.RUN_STATUS_FAILED:
		return false
	if _run.tutorial_main_floor_only():
		return false
	if not _run._is_grand_casino_environment(_run.current_environment):
		return false
	var status = _run.demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return false
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return true
	return bool(status.get("heat_route_ready", false)) or bool(status.get("dirty_money_showdown_ready", false))


func grand_casino_staff_attention_status(environment: Dictionary = {}, forced_heat_threshold: int = 95) -> Dictionary:
	var source = environment if not environment.is_empty() else _run.current_environment
	if not _run._is_grand_casino_environment(source):
		return {
			"active": false,
			"sources": [],
			"watch": {"active": false},
			"summary": "",
		}
	var sources: Array = []
	var watch_status = _run.pit_boss_watch_status(source)
	if bool(watch_status.get("active", false)) and bool(watch_status.get("watched", false)):
		sources.append("rourke_watch")
	if bool(_run.narrative_flags.get("grand_casino_watched_cheat_evidence", false)) or bool(_run.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
		_run._append_unique_string(sources, "watched_cheat")
	if bool(_run.narrative_flags.get("grand_casino_attention_pit_boss_sweep", false)):
		_run._append_unique_string(sources, "pit_boss_sweep")
	if bool(_run.narrative_flags.get("grand_casino_attention_eye_in_the_sky", false)):
		_run._append_unique_string(sources, "eye_in_the_sky")
	for event_source in _grand_casino_active_security_event_sources(source):
		_run._append_unique_string(sources, str(event_source))
	if bool(_run.narrative_flags.get("grand_casino_attention_watched_risky", false)):
		_run._append_unique_string(sources, "watched_risky")
	if bool(_run.narrative_flags.get("grand_casino_attention_host", false)):
		_run._append_unique_string(sources, "host")
	if bool(_run.narrative_flags.get("grand_casino_attention_high_roller_review", false)):
		_run._append_unique_string(sources, "high_roller_review")
	if bool(_run.narrative_flags.get("grand_casino_attention_forced_heat", false)) or _run.suspicion_level() >= forced_heat_threshold:
		_run._append_unique_string(sources, "forced_heat")
	var source_labels := {
		"rourke_watch": "Rourke watching",
		"watched_cheat": "watched edge",
		"pit_boss_sweep": "pit sweep",
		"eye_in_the_sky": "camera review",
		"watched_risky": "watched risky play",
		"host": "host attention",
		"high_roller_review": "Players Card review",
		"forced_heat": "heat spike",
	}
	var label_parts: Array = []
	for source_id in sources:
		label_parts.append(str(source_labels.get(str(source_id), str(source_id).replace("_", " "))))
	var summary := "No staff attention."
	if not label_parts.is_empty():
		summary = "Staff attention: %s." % ", ".join(label_parts)
	return {
		"active": not sources.is_empty(),
		"sources": sources,
		"watch": watch_status,
		"summary": summary,
	}


func _grand_casino_demo_objective_status(source: Dictionary, objective: Dictionary) -> Dictionary:
	if not _run._is_grand_casino_environment(source):
		return {
			"active": false,
			"id": str(objective.get("id", "")),
			"grand_casino_objective": false,
		}
	var config := _grand_casino_objective_config(objective)
	var target_bankroll := int(config.get("high_roller_target_bankroll", 0))
	var total_money := grand_casino_total_money()
	var entry_bankroll := int(_run.narrative_flags.get("grand_casino_entry_bankroll", total_money))
	var net_winnings := total_money - entry_bankroll
	var required_net := int(config.get("high_roller_net_winnings", 0))
	var games_played := maxi(0, int(_run.narrative_flags.get("grand_casino_games_played", 0)))
	var min_games := int(config.get("high_roller_min_grand_casino_games", 0))
	var max_heat := int(config.get("high_roller_max_heat", 100))
	var current_heat = _run.suspicion_level()
	var max_visit_heat := maxi(current_heat, int(_run.narrative_flags.get("grand_casino_max_heat", current_heat)))
	var showdown_threshold := int(config.get("showdown_heat_threshold", 70))
	var forced_threshold := int(config.get("forced_showdown_heat_threshold", 95))
	var staff_attention := grand_casino_staff_attention_status(source, forced_threshold)
	var staff_sources := JsonCoerceScript._copy_array(staff_attention.get("sources", []))
	var cheat_evidence := bool(_run.narrative_flags.get("grand_casino_cheat_evidence", false))
	var watched_cheat_evidence := bool(_run.narrative_flags.get("grand_casino_watched_cheat_evidence", false))
	var card_eligible := not bool(_run.narrative_flags.get("grand_casino_players_card_ineligible", false)) and not cheat_evidence and not watched_cheat_evidence
	var card_tier := _grand_casino_players_card_awarded_tier()
	var card_tier_label := card_tier.capitalize() if card_tier != _run.GRAND_CASINO_PLAYERS_CARD_TIER_NONE else "Unranked"
	if not card_eligible:
		card_tier_label = "%s (program closed)" % card_tier_label
	var next_tier := _grand_casino_players_card_next_definition(config, card_tier) if card_eligible else {}
	var next_tier_id := str(next_tier.get("id", ""))
	var next_tier_label := str(next_tier.get("label", ""))
	var next_tier_min_games := int(next_tier.get("min_games", min_games))
	var next_tier_net := int(next_tier.get("net_winnings", required_net))
	var next_tier_max_heat := int(next_tier.get("max_heat", max_heat))
	var segment_games := maxi(0, int(_run.narrative_flags.get("grand_casino_players_card_segment_games", 0)))
	var segment_net := int(_run.narrative_flags.get("grand_casino_players_card_segment_net_winnings", 0))
	var segment_max_heat := clampi(int(_run.narrative_flags.get("grand_casino_players_card_segment_max_heat", current_heat)), 0, 100)
	var ready_to_claim := bool(_run.narrative_flags.get("grand_casino_players_card_ready_to_claim", false)) and not next_tier_id.is_empty() and card_eligible
	var card_debt := grand_casino_atm_debt() if has_method("grand_casino_atm_debt") else 0
	var claim_block_reason := ""
	if not card_eligible:
		claim_block_reason = "Cheat evidence permanently closes the Players Card program for this run."
	elif bool(_run.narrative_flags.get("grand_casino_showdown_pending", false)) or bool(_run.narrative_flags.get("grand_casino_showdown_active", false)):
		claim_block_reason = "Rourke's showdown has priority over the Players Card program."
	elif card_debt > 0:
		claim_block_reason = "Settle the $%d Grand Casino ATM marker before Linda can issue %s." % [card_debt, next_tier_label]
	elif not ready_to_claim:
		claim_block_reason = "%s requirements are still in progress." % next_tier_label if not next_tier_label.is_empty() else "No later Players Card tier remains."
	var card_benefits := _grand_casino_players_card_benefits(config, card_tier)
	var money_target_met := net_winnings >= required_net
	if required_net <= 0 and target_bankroll > 0:
		money_target_met = total_money >= target_bankroll
	var game_target_met := games_played >= min_games
	var heat_clean := max_visit_heat <= max_heat
	var high_roller_ready = next_tier_id == _run.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD and ready_to_claim and card_debt <= 0 and claim_block_reason.is_empty()
	var high_roller_pending := bool(_run.narrative_flags.get("high_roller_cashout_pending", false))
	var showdown_event_id := str(config.get("showdown_event_id", _run.GRAND_CASINO_SHOWDOWN_EVENT_ID))
	var high_roller_event_id := str(config.get("high_roller_event_id", _run.GRAND_CASINO_HIGH_ROLLER_EVENT_ID))
	var showdown_disabled = _run.tutorial_main_floor_only()
	var showdown_pending := false if showdown_disabled else bool(_run.narrative_flags.get("grand_casino_showdown_pending", false))
	showdown_pending = showdown_pending or (
		not showdown_disabled
		and bool(_run.narrative_flags.get("demo_finale_pending", false))
		and str(_run.narrative_flags.get("demo_finale_event_id", "")) == showdown_event_id
	)
	var showdown_active := false if showdown_disabled else bool(_run.narrative_flags.get("grand_casino_showdown_active", false))
	var staff_attention_active := bool(staff_attention.get("active", false))
	var heat_route_ready = not showdown_disabled and ((current_heat >= showdown_threshold and staff_attention_active) or current_heat >= forced_threshold)
	var dirty_money_showdown_ready = not showdown_disabled and money_target_met and (cheat_evidence or watched_cheat_evidence or max_visit_heat > max_heat)
	var objective_state := _grand_casino_derived_state(source, high_roller_ready or high_roller_pending, showdown_pending, showdown_active)
	var complete := bool(_run.narrative_flags.get("demo_victory", false))
	var remaining_bankroll := maxi(0, target_bankroll - total_money)
	var remaining_net := maxi(0, required_net - net_winnings)
	var remaining_games := maxi(0, min_games - games_played)
	var summary := _grand_casino_objective_summary(
		high_roller_ready or high_roller_pending,
		showdown_pending or showdown_active,
		heat_route_ready,
		dirty_money_showdown_ready,
		money_target_met,
		game_target_met,
		target_bankroll,
		required_net,
		remaining_games
	)
	return {
		"active": true,
		"id": str(objective.get("id", "")),
		"type": str(objective.get("type", "")),
		"title": str(objective.get("title", "Beat the Grand Casino")),
		"summary": summary,
		"authored_summary": str(objective.get("summary", "")),
		"target_bankroll": target_bankroll,
		"current_bankroll": _run.bankroll,
		"remaining_bankroll": remaining_bankroll,
		"complete": complete,
		"victory_message": str(objective.get("victory_message", "Demo Victory: you beat the Grand Casino floor.")),
		"finale_required": true,
		"finale_event_id": showdown_event_id,
		"finale_pending": showdown_pending,
		"grand_casino_objective": true,
		"objective_state": objective_state,
		"grand_casino_entry_bankroll": entry_bankroll,
		"grand_casino_net_winnings": net_winnings,
		"grand_casino_open_cheat_actions": maxi(0, int(_run.narrative_flags.get("grand_casino_open_cheat_actions", 0))),
		"high_roller_target_bankroll": target_bankroll,
		"high_roller_net_winnings": required_net,
		"high_roller_remaining_net_winnings": remaining_net,
		"high_roller_min_grand_casino_games": min_games,
		"grand_casino_games_played": games_played,
		"high_roller_remaining_games": remaining_games,
		"high_roller_max_heat": max_heat,
		"current_heat": current_heat,
		"grand_casino_max_heat": max_visit_heat,
		"high_roller_ready": high_roller_ready or high_roller_pending,
		"high_roller_cashout_pending": high_roller_pending,
		"high_roller_event_id": high_roller_event_id,
		"players_card_ready": high_roller_ready or high_roller_pending,
		"players_card_event_id": high_roller_event_id,
		"players_card_required_net_winnings": required_net,
		"players_card_remaining_net_winnings": remaining_net,
		"players_card_tier": card_tier,
		"players_card_awarded_tier": card_tier,
		"players_card_tier_label": card_tier_label,
		"players_card_eligible": card_eligible,
		"players_card_ineligible_reason": "Cheat evidence permanently closes the Players Card program for this run." if not card_eligible else "",
		"players_card_next_tier": next_tier_id,
		"players_card_next_tier_label": next_tier_label,
		"players_card_next_min_games": next_tier_min_games,
		"players_card_next_net_winnings": next_tier_net,
		"players_card_next_max_heat": next_tier_max_heat,
		"players_card_segment_games": segment_games,
		"players_card_segment_net_winnings": segment_net,
		"players_card_segment_max_heat": segment_max_heat,
		"players_card_next_remaining_games": maxi(0, next_tier_min_games - segment_games),
		"players_card_next_remaining_net_winnings": maxi(0, next_tier_net - segment_net),
		"players_card_ready_to_claim": ready_to_claim,
		"players_card_can_claim": ready_to_claim and claim_block_reason.is_empty(),
		"players_card_claim_block_reason": claim_block_reason,
		"grand_casino_atm_debt": card_debt,
		"players_card_benefits": card_benefits,
		"players_card_next_benefits": JsonCoerceScript._copy_array(next_tier.get("benefits", [])),
		"players_card_drink_comps": maxi(0, int(_run.narrative_flags.get("grand_casino_comp_drink_tokens", 0))),
		"players_card_suite_rests": maxi(0, int(_run.narrative_flags.get("grand_casino_comp_suite_rests", 0))),
		"players_card_look_away_available": bool(_run.narrative_flags.get("grand_casino_linda_look_away_available", false)),
		"prestige": grand_casino_prestige_status(),
		"cheat_evidence": cheat_evidence,
		"watched_cheat_evidence": watched_cheat_evidence,
		"showdown_heat_threshold": showdown_threshold,
		"forced_showdown_heat_threshold": forced_threshold,
		"showdown_event_id": showdown_event_id,
		"showdown_pending": showdown_pending,
		"showdown_active": showdown_active,
		"showdown_ready": heat_route_ready or dirty_money_showdown_ready,
		"heat_route_ready": heat_route_ready,
		"dirty_money_showdown_ready": dirty_money_showdown_ready,
		"staff_attention": staff_attention,
		"staff_attention_active": staff_attention_active,
		"staff_attention_sources": staff_sources,
		"pit_boss_watch": JsonCoerceScript._copy_dict(staff_attention.get("watch", {})),
		"goal_text": summary,
		"lanes": {
			"clean": {
				"route": _run.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
				"label": "players_card",
				"event_id": high_roller_event_id,
				"ready": high_roller_ready or high_roller_pending,
				"pending": high_roller_pending,
				"target_bankroll": target_bankroll,
				"net_winnings": required_net,
				"players_card_required_net_winnings": required_net,
				"min_games": min_games,
				"max_heat": max_heat,
			},
			"heat": {
				"route": "pit_boss_showdown",
				"event_id": showdown_event_id,
				"ready": heat_route_ready or dirty_money_showdown_ready,
				"pending": showdown_pending,
				"heat_threshold": showdown_threshold,
				"forced_heat_threshold": forced_threshold,
				"staff_attention": staff_attention_active,
			},
		},
	}


func grand_casino_showdown_status(config: Dictionary = {}, _preview_choice_id: String = "") -> Dictionary:
	var duel_terms := JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_terms", {}))
	return {
		"event_id": _run.GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"pending": bool(_run.narrative_flags.get("grand_casino_showdown_pending", false)),
		"active": bool(_run.narrative_flags.get("grand_casino_showdown_active", false)),
		"step": str(_run.narrative_flags.get("grand_casino_showdown_step", "")),
		"attempt": maxi(0, int(_run.narrative_flags.get("grand_casino_showdown_attempt", 0))),
		"trigger_reason": str(_run.narrative_flags.get("grand_casino_showdown_trigger_reason", "")),
		"pressure_choice": str(_run.narrative_flags.get("grand_casino_showdown_pressure_choice", "")),
		"walk": grand_casino_showdown_walk_status(),
		"pat_down": JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_showdown_pat_down", {})),
		"interrogation": grand_casino_showdown_interrogation_status(config),
		"duel_terms": duel_terms,
		"duel": JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_state", {})),
	}


func grand_casino_showdown_walk_status() -> Dictionary:
	return {
		"ditch_used": bool(_run.narrative_flags.get("grand_casino_showdown_ditch_used", false)),
		"method": str(_run.narrative_flags.get("grand_casino_showdown_ditch_method", "")),
		"item_id": str(_run.narrative_flags.get("grand_casino_showdown_ditch_item_id", "")),
		"crew_available": _run.GrandCasinoShowdownModelScript.crew_interacted(_run.narrative_flags, _run.debt),
		"inventory": _run.inventory.duplicate(true),
		"trash_seen": bool(_run.narrative_flags.get("grand_casino_showdown_trash_seen", false)),
		"trash_flavor": str(_run.narrative_flags.get("grand_casino_showdown_trash_flavor", "")),
	}


func grand_casino_showdown_interrogation_status(config: Dictionary = {}) -> Dictionary:
	var evidence_ids := JsonCoerceScript._copy_array(_run.narrative_flags.get("grand_casino_showdown_interrogation_evidence", []))
	var beat_index := maxi(0, int(_run.narrative_flags.get("grand_casino_showdown_interrogation_beat", 0)))
	var interrogation_config := JsonCoerceScript._copy_dict(config.get("interrogation", {}))
	var definitions := JsonCoerceScript._copy_array(interrogation_config.get("evidence", []))
	var evidence_definition = _run._showdown_evidence_definition(definitions, str(evidence_ids[beat_index]) if beat_index < evidence_ids.size() else "")
	var snapshot := _grand_casino_showdown_fact_snapshot()
	return {
		"beat_index": beat_index,
		"beat_number": mini(evidence_ids.size(), beat_index + 1) if not evidence_ids.is_empty() else 0,
		"beat_count": evidence_ids.size(),
		"evidence_ids": evidence_ids,
		"evidence_id": str(evidence_definition.get("id", "")),
		"evidence_text": _run.GrandCasinoShowdownModelScript.evidence_text(evidence_definition, snapshot) if not evidence_definition.is_empty() else "",
		"answers": JsonCoerceScript._copy_array(_run.narrative_flags.get("grand_casino_showdown_interrogation_answers", [])),
		"stakes": JsonCoerceScript._copy_dict(snapshot.get("modifiers", {})),
	}


func grand_casino_showdown_interrogation_choices(config: Dictionary = {}) -> Array:
	if str(_run.narrative_flags.get("grand_casino_showdown_step", "")) != _run.GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
		return []
	var interrogation_config := JsonCoerceScript._copy_dict(config.get("interrogation", {}))
	var snapshot := _grand_casino_showdown_fact_snapshot()
	var choices: Array = []
	for choice_value in JsonCoerceScript._copy_array(interrogation_config.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice := (choice_value as Dictionary).duplicate(true)
		var choice_id := str(choice.get("id", ""))
		var strength = _run.GrandCasinoShowdownModelScript.response_strength(choice_id, snapshot)
		choice["strength"] = int(strength.get("strength", 0))
		choice["pressure_modifier"] = int(strength.get("pressure_modifier", 0))
		choice["fact_modifier"] = int(strength.get("fact_modifier", 0))
		choice["fact_label"] = str(strength.get("fact_label", "the run record"))
		choice["text"] = str(choice.get("text", "")).replace("{strength}", _run._signed_showdown_value(int(choice["strength"])))
		choice["consequence_summary"] = str(choice.get("consequence_summary", "")).replace("{strength}", _run._signed_showdown_value(int(choice["strength"])))
		choices.append(choice)
	return choices


func grand_casino_duel_active(environment: Dictionary = {}) -> bool:
	var source = _run.current_environment if environment.is_empty() else environment
	var duel_state_value: Variant = _run.narrative_flags.get("grand_casino_duel_state", {})
	var duel_status := str((duel_state_value as Dictionary).get("status", "")) if typeof(duel_state_value) == TYPE_DICTIONARY else ""
	return (
		_run._is_grand_casino_environment(source)
		and bool(_run.narrative_flags.get("grand_casino_showdown_active", false))
		and str(_run.narrative_flags.get("grand_casino_showdown_step", "")) == _run.GRAND_CASINO_SHOWDOWN_STEP_DUEL
		and duel_status == "active"
	)


func grand_casino_duel_status() -> Dictionary:
	var state := JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_state", {}))
	if state.is_empty() and bool(_run.narrative_flags.get("grand_casino_showdown_active", false)) and not JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_terms", {})).is_empty():
		state = _run._begin_grand_casino_duel(JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_terms", {})))
	return state


func grand_casino_duel_terms() -> Dictionary:
	return JsonCoerceScript._copy_dict(_run.narrative_flags.get("grand_casino_duel_terms", {}))


func grand_casino_duel_session() -> Dictionary:
	return JsonCoerceScript._copy_dict(grand_casino_duel_status().get("blackjack_session", {}))


func grand_casino_duel_session_readonly() -> Dictionary:
	var state_value: Variant = _run.narrative_flags.get("grand_casino_duel_state", {})
	if typeof(state_value) != TYPE_DICTIONARY:
		return {}
	var session_value: Variant = (state_value as Dictionary).get("blackjack_session", {})
	return session_value as Dictionary if typeof(session_value) == TYPE_DICTIONARY else {}


func grand_casino_duel_action_time_msec() -> int:
	var state := grand_casino_duel_status()
	var input_index := maxi(0, int(state.get("input_index", 0))) + 1
	state["input_index"] = input_index
	_run.narrative_flags["grand_casino_duel_state"] = state
	return _run.simulation_time_msec() + input_index * 250


func grand_casino_duel_current_edge() -> Dictionary:
	return _run.GrandCasinoDuelModelScript.current_edge(grand_casino_duel_status())


func grand_casino_duel_call_out(edge_id: String) -> Dictionary:
	var terms := grand_casino_duel_terms()
	var outcome = _run.GrandCasinoDuelModelScript.call_out(grand_casino_duel_status(), edge_id, terms)
	if not bool(outcome.get("ok", false)):
		return outcome
	var state := JsonCoerceScript._copy_dict(outcome.get("state", {}))
	_run.narrative_flags["grand_casino_duel_state"] = state
	_run.log_story({
		"type": "grand_casino_duel_callout",
		"event_id": _run.GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"hand": int(state.get("hand_index", 0)) + 1,
		"edge_id": edge_id,
		"correct": bool(outcome.get("correct", false)),
		"stack_swing": int(outcome.get("swing", 0)),
		"message": str(outcome.get("message", "Rourke marks the call.")),
	})
	_run._finalize_grand_casino_duel_if_complete(state)
	outcome["state"] = state
	return outcome


func _grand_casino_showdown_fact_snapshot() -> Dictionary:
	var open_debt_count := 0
	for debt_value in _run.debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		if ["active", "overdue", "favor_due"].has(str(debt_data.get("status", "active"))):
			open_debt_count += 1
	var tier := str(_run.narrative_flags.get("grand_casino_players_card_highest_tier", _run.narrative_flags.get("grand_casino_players_card_tier", _run.GRAND_CASINO_PLAYERS_CARD_TIER_NONE)))
	var linda_standing := clampi(_grand_casino_players_card_tier_index(tier) * 2, 0, 6)
	for story_value in _run.story_log:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = story_value
		if str(story.get("type", "")) == "service_hook" and str(story.get("id", "")).begins_with("players_card_"):
			linda_standing = mini(6, linda_standing + 1)
	var prior_cameo = _run._story_log_has_type("event", "rourke_scouting_cameo")
	prior_cameo = prior_cameo or bool(_run.narrative_flags.get("grand_casino_event_pit_boss_sweep_lay_low", false)) or bool(_run.narrative_flags.get("grand_casino_event_eye_in_the_sky_press_anyway", false))
	var used_surveillance := false
	for item_id in ["xray_glasses", "tab_detector", "tarot_card"]:
		if bool(_run.narrative_flags.get("grand_casino_used_%s" % item_id, false)):
			used_surveillance = true
			break
	return {
		"heat": _run.suspicion_level(),
		"watched_cheat": bool(_run.narrative_flags.get("grand_casino_watched_cheat_evidence", false)),
		"cheat_evidence": bool(_run.narrative_flags.get("grand_casino_cheat_evidence", false)),
		"card_ineligible": bool(_run.narrative_flags.get("grand_casino_players_card_ineligible", false)),
		"attention_sources": JsonCoerceScript._copy_array(_run.narrative_flags.get("grand_casino_showdown_attention_sources", _run.narrative_flags.get("grand_casino_staff_attention_sources", []))),
		"open_debt_count": open_debt_count,
		"drunk_level": _run.drunk_level,
		"games_played": maxi(0, int(_run.narrative_flags.get("grand_casino_games_played", 0))),
		"net_winnings": int(_run.narrative_flags.get("grand_casino_net_winnings", 0)),
		"prior_cameo": prior_cameo,
		"linda_standing": linda_standing,
		"crew_ties": _run.GrandCasinoShowdownModelScript.crew_interacted(_run.narrative_flags, _run.debt),
		"used_surveillance": used_surveillance,
		"modifiers": _grand_casino_showdown_modifier_breakdown("hold_steady"),
	}


func _grand_casino_showdown_modifier_breakdown(choice_id: String) -> Dictionary:
	var pressure_choice := choice_id.strip_edges()
	var effective_cheat_evidence := bool(_run.narrative_flags.get("grand_casino_cheat_evidence", false))
	var effective_watched_evidence := bool(_run.narrative_flags.get("grand_casino_watched_cheat_evidence", false))
	if pressure_choice == "take_the_edge":
		effective_cheat_evidence = true
		effective_watched_evidence = true
	var pressure_modifier := 0
	match pressure_choice:
		"hold_steady":
			pressure_modifier = -4 if effective_cheat_evidence or effective_watched_evidence else 8
		"talk_down":
			pressure_modifier = 4
		"take_the_edge":
			pressure_modifier = 16
		_:
			pressure_modifier = 0
	var max_heat := 100
	var status = _run.demo_objective_status()
	if bool(status.get("grand_casino_objective", false)):
		max_heat = int(status.get("high_roller_max_heat", 100))
	var heat_penalty := clampi(int(floor(float(maxi(0, _run.suspicion_level() - max_heat)) / 5.0)) * 2, 0, 28)
	var evidence_penalty := 20 if effective_watched_evidence else 10 if effective_cheat_evidence else 0
	var clean_play_modifier := 0
	if not effective_cheat_evidence and not effective_watched_evidence:
		clean_play_modifier = 10 if _run.suspicion_level() <= max_heat else 4
	var item_modifier := _grand_casino_showdown_item_modifier(effective_cheat_evidence or effective_watched_evidence)
	var alcohol_debt_penalty := _grand_casino_showdown_alcohol_debt_penalty()
	var prior_modifier := _grand_casino_showdown_prior_boss_modifier()
	return {
		"pressure_choice_modifier": pressure_modifier,
		"clean_play_modifier": clean_play_modifier,
		"item_modifier": item_modifier,
		"prior_boss_event_modifier": prior_modifier,
		"heat_penalty": heat_penalty,
		"evidence_penalty": evidence_penalty,
		"alcohol_debt_penalty": alcohol_debt_penalty,
	}


func _grand_casino_showdown_item_modifier(has_cheat_evidence: bool) -> int:
	var raw_modifier := 0
	if _run.inventory.has("cheap_sunglasses"):
		raw_modifier += 4
	if _run.inventory.has("card_counters_notes") and not has_cheat_evidence:
		raw_modifier += 4
	if _run.inventory.has("scratch_pad") and not has_cheat_evidence:
		raw_modifier += 2
	if _run.inventory.has("creased_luck_card"):
		raw_modifier += 2
	if _run.inventory.has("lucky_keychain"):
		raw_modifier += 2
	var contraband_count := 0
	for item_id in ["marked_cards", "foil_sleeve", "weighted_keyring"]:
		if _run.inventory.has(item_id):
			contraband_count += 1
	raw_modifier -= mini(18, contraband_count * 6)
	var surveillance_count := 0
	for item_id in ["xray_glasses", "tab_detector", "tarot_card"]:
		if _run.inventory.has(item_id) or bool(_run.narrative_flags.get("grand_casino_used_%s" % item_id, false)):
			surveillance_count += 1
	raw_modifier -= mini(16, surveillance_count * 8)
	return clampi(raw_modifier, -24, 10)


func _grand_casino_showdown_alcohol_debt_penalty() -> int:
	var drunk_penalty := 0
	if _run.drunk_level >= 71:
		drunk_penalty = 14
	elif _run.drunk_level >= 46:
		drunk_penalty = 10
	elif _run.drunk_level >= 26:
		drunk_penalty = 6
	elif _run.drunk_level >= 11:
		drunk_penalty = 3
	var dependence_gap = _run.alcoholic_level - _run.drunk_level
	var dependence_penalty := 0
	if dependence_gap >= 60:
		dependence_penalty = 8
	elif dependence_gap >= 30:
		dependence_penalty = 4
	var open_debt_count := 0
	for debt_entry in _run.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status == "active" or debt_status == "overdue":
			open_debt_count += 1
	var debt_penalty := mini(9, open_debt_count * 3)
	return clampi(drunk_penalty + dependence_penalty + debt_penalty, 0, 24)


func _grand_casino_showdown_prior_boss_modifier() -> int:
	var raw_modifier := 0
	if bool(_run.narrative_flags.get("grand_casino_event_pit_boss_sweep_lay_low", false)):
		raw_modifier += 4
	if bool(_run.narrative_flags.get("grand_casino_event_pit_boss_sweep_act_natural", false)):
		raw_modifier -= 3
	if bool(_run.narrative_flags.get("grand_casino_event_eye_in_the_sky_change_table", false)):
		raw_modifier += 5
	if bool(_run.narrative_flags.get("grand_casino_event_eye_in_the_sky_press_anyway", false)):
		raw_modifier -= 8
	if bool(_run.narrative_flags.get("grand_casino_event_comped_suite_offer_decline", false)):
		raw_modifier += 3
	if bool(_run.narrative_flags.get("grand_casino_event_comped_suite_offer_take_comp", false)):
		raw_modifier -= 4
	return clampi(raw_modifier, -12, 10)


func grand_casino_living_floor_snapshot(environment: Dictionary = {}) -> Dictionary:
	var source = _run.current_environment if environment.is_empty() else environment
	var player_room := _grand_casino_room_id_for_environment(source)
	if player_room.is_empty():
		return {}
	var visible_rivals: Array = []
	for rival_value in rival_cheaters:
		if typeof(rival_value) != TYPE_DICTIONARY:
			continue
		var rival := rival_value as Dictionary
		if str(rival.get("room", "")) == player_room:
			visible_rivals.append(rival.duplicate(true))
	var escort := rourke_escort_state.duplicate(true)
	var escort_visible = not escort.is_empty() and player_room == _run.GRAND_CASINO_ARCHETYPE_ID and rourke_off_floor_actions > 0
	if escort_visible:
		escort["progress"] = clampf(1.0 - float(rourke_off_floor_actions) / float(maxi(1, _run.ROURKE_OFF_FLOOR_ACTIONS)), 0.0, 1.0)
	else:
		escort = {}
	return {
		"player_room": player_room,
		"room_heat": grand_casino_room_heat_accumulators.duplicate(true),
		"rourke": {
			"on_floor": rourke_off_floor_actions <= 0 and not rourke_current_room.is_empty(),
			"present": rourke_off_floor_actions <= 0 and rourke_current_room == player_room,
			"room": rourke_current_room,
			"spot": rourke_current_spot,
			"facing": rourke_facing,
			"actions_until_move": rourke_actions_until_move,
			"off_floor_actions": rourke_off_floor_actions,
		},
		"rivals": visible_rivals,
		"rival_count": rival_cheaters.size(),
		"rival_day": rival_cheater_day,
		"escort": escort,
	}


func grand_casino_staffing_snapshot(environment: Dictionary = {}) -> Dictionary:
	var source = _run.current_environment if environment.is_empty() else environment
	if not _run._is_grand_casino_environment(source):
		return {}
	return _grand_casino_staffing_projection(source)


func grand_casino_staff_member_for_game(game_id: String, environment: Dictionary = {}) -> Dictionary:
	var source = _run.current_environment if environment.is_empty() else environment
	if not _run._is_grand_casino_environment(source):
		return {}
	_run._initialize_grand_casino_staffing(source)
	var role_id := "bartender" if game_id == "bar_dice" else game_id.strip_edges()
	var assignments: Dictionary = grand_casino_staffing.get("assignments", {}) if typeof(grand_casino_staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var assignment: Variant = assignments.get(role_id, {})
	return assignment if typeof(assignment) == TYPE_DICTIONARY else {}


func grand_casino_staff_member_for_game_preview(game_id: String, environment: Dictionary = {}) -> Dictionary:
	var source = _run.current_environment if environment.is_empty() else environment
	if not _run._is_grand_casino_environment(source):
		return {}
	var staffing := _grand_casino_staffing_projection(source)
	var role_id := "bartender" if game_id == "bar_dice" else game_id.strip_edges()
	var assignments: Dictionary = staffing.get("assignments", {}) if typeof(staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var assignment: Variant = assignments.get(role_id, {})
	return (assignment as Dictionary).duplicate(true) if typeof(assignment) == TYPE_DICTIONARY else {}


func grand_casino_staff_profile_rng(role_id: String, assignment_id: String, day_index: int) -> RngStream:
	return _run._create_seeded_run_rng("gc_staff_profile:%s:%s:%d" % [role_id.strip_edges(), assignment_id.strip_edges(), maxi(1, day_index)])


func _grand_casino_staffing_projection(environment: Dictionary) -> Dictionary:
	var current_day = _run.game_day()
	if int(grand_casino_staffing.get("day", 0)) == current_day and not _grand_casino_staff_assignments(grand_casino_staffing).is_empty():
		return grand_casino_staffing.duplicate(true)
	var projected := _grand_casino_staffing_for_day(current_day, _grand_casino_staff_config(environment))
	projected["entry_cue"] = JsonCoerceScript._copy_dict(grand_casino_staffing.get("entry_cue", {}))
	projected["rotation_cue_shown_day"] = maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0)))
	return projected


func _grand_casino_staffing_for_day(day_index: int, config_override: Dictionary = {}) -> Dictionary:
	var target_day := maxi(1, day_index)
	var config := config_override.duplicate(true) if not config_override.is_empty() else _grand_casino_staff_config()
	var chance := clampi(int(config.get("rotation_chance_percent", _run.GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT)), 0, 100)
	var assignments: Dictionary = {}
	for timeline_day in range(1, target_day + 1):
		var day_rng = _run._create_seeded_run_rng("gc_staff_day:%d" % timeline_day)
		var next_assignments: Dictionary = {}
		for role_value in _run.GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var roster := _grand_casino_staff_roster(config, role_id)
			var previous: Dictionary = assignments.get(role_id, {}) if typeof(assignments.get(role_id, {})) == TYPE_DICTIONARY else {}
			var role_rng = day_rng.fork(role_id)
			var rotate = timeline_day == 1 or previous.is_empty() or role_rng.randi_range(1, 100) <= chance
			var selected := _grand_casino_staff_pick(roster, previous, role_rng, rotate)
			selected["role_id"] = role_id
			selected["day"] = timeline_day
			next_assignments[role_id] = selected
		assignments = next_assignments
	var prior_assignments := _grand_casino_staff_assignments(grand_casino_staffing)
	var rotated_roles: Array = []
	if target_day > 1:
		var previous_timeline := _grand_casino_staffing_for_previous_day(target_day - 1, config, chance)
		for role_value in _run.GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var previous_id := str(JsonCoerceScript._copy_dict(previous_timeline.get(role_id, {})).get("id", ""))
			var current_id := str(JsonCoerceScript._copy_dict(assignments.get(role_id, {})).get("id", ""))
			if not current_id.is_empty() and current_id != previous_id:
				rotated_roles.append(role_id)
	if not prior_assignments.is_empty() and int(grand_casino_staffing.get("day", 0)) == target_day:
		rotated_roles = JsonCoerceScript._copy_array(grand_casino_staffing.get("rotated_roles", rotated_roles))
	return {
		"day": target_day,
		"rotation_chance_percent": chance,
		"assignments": assignments,
		"rotated_roles": rotated_roles,
		"rotation_occurred": not rotated_roles.is_empty(),
		"constants": {
			"rourke": {"id": "rourke", "name": "Rourke"},
			"linda": {"id": "linda", "name": "Linda"},
		},
		"entry_cue": {},
		"rotation_cue_shown_day": maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0))),
	}


func _grand_casino_staffing_for_previous_day(day_index: int, config: Dictionary, chance: int) -> Dictionary:
	var assignments: Dictionary = {}
	for timeline_day in range(1, maxi(1, day_index) + 1):
		var day_rng = _run._create_seeded_run_rng("gc_staff_day:%d" % timeline_day)
		var next_assignments: Dictionary = {}
		for role_value in _run.GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var roster := _grand_casino_staff_roster(config, role_id)
			var previous: Dictionary = assignments.get(role_id, {}) if typeof(assignments.get(role_id, {})) == TYPE_DICTIONARY else {}
			var role_rng = day_rng.fork(role_id)
			var rotate = timeline_day == 1 or previous.is_empty() or role_rng.randi_range(1, 100) <= chance
			var selected := _grand_casino_staff_pick(roster, previous, role_rng, rotate)
			selected["role_id"] = role_id
			selected["day"] = timeline_day
			next_assignments[role_id] = selected
		assignments = next_assignments
	return assignments


func _grand_casino_staff_pick(roster: Array, previous: Dictionary, rng: RngStream, rotate: bool) -> Dictionary:
	if roster.is_empty():
		return {}
	if not rotate and not previous.is_empty():
		return previous.duplicate(true)
	var choices: Array = []
	var previous_id := str(previous.get("id", ""))
	for member_value in roster:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member := member_value as Dictionary
		if roster.size() > 1 and str(member.get("id", "")) == previous_id:
			continue
		choices.append(member)
	if choices.is_empty():
		choices = roster
	var selected: Variant = rng.pick(choices, choices[0])
	return (selected as Dictionary).duplicate(true) if typeof(selected) == TYPE_DICTIONARY else {}


func _grand_casino_staff_config(environment: Dictionary = {}) -> Dictionary:
	var candidates: Array = []
	if not environment.is_empty():
		candidates.append(environment)
	candidates.append(_run.current_environment)
	candidates.append(grand_casino_room_states.get(_run.GRAND_CASINO_ARCHETYPE_ID, {}))
	for environment_value in candidates:
		if typeof(environment_value) != TYPE_DICTIONARY:
			continue
		var candidate_environment := environment_value as Dictionary
		var flags: Dictionary = candidate_environment.get("local_narrative_flags", {}) if typeof(candidate_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
		var config: Variant = flags.get("grand_casino_staff_rotation", {})
		if typeof(config) == TYPE_DICTIONARY and not (config as Dictionary).is_empty():
			return (config as Dictionary).duplicate(true)
	return {
		"rotation_chance_percent": _run.GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT,
		"rosters": _run.GRAND_CASINO_STAFF_DEFAULT_ROSTERS.duplicate(true),
		"memory_lines": _run.GRAND_CASINO_MEMORY_DEFAULT_LINES.duplicate(true),
		"rotation_cue_lines": ["New faces have taken their places at the felt."],
		"memory_high_heat_threshold": 50,
	}


func _grand_casino_staff_roster(config: Dictionary, role_id: String) -> Array:
	var rosters: Dictionary = config.get("rosters", {}) if typeof(config.get("rosters", {})) == TYPE_DICTIONARY else {}
	var roster: Variant = rosters.get(role_id, _run.GRAND_CASINO_STAFF_DEFAULT_ROSTERS.get(role_id, []))
	return (roster as Array).duplicate(true) if typeof(roster) == TYPE_ARRAY else []


func _grand_casino_has_prior_visit() -> bool:
	for entry_value in _run.environment_history:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		if _run.GRAND_CASINO_ARCHETYPE_IDS.has(str(entry.get("archetype_id", ""))):
			return true
	return false


func _grand_casino_dominant_memory_key(config: Dictionary) -> String:
	var remembered_pressure := bool(_run.narrative_flags.get("grand_casino_showdown_pending", false)) \
		or bool(_run.narrative_flags.get("grand_casino_showdown_active", false)) \
		or bool(_run.narrative_flags.get("grand_casino_staff_attention", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_pit_boss_sweep", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_eye_in_the_sky", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_watched_risky", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_host", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_high_roller_review", false)) \
		or bool(_run.narrative_flags.get("grand_casino_attention_forced_heat", false))
	if remembered_pressure:
		return "showdown_pressure"
	var objective_status = _run.demo_objective_status()
	if bool(_run.narrative_flags.get("grand_casino_high_roller_ready", false)) \
		or bool(_run.narrative_flags.get("high_roller_cashout_pending", false)) \
		or bool(objective_status.get("players_card_ready", false)):
		return "pending_review"
	if bool(_run.narrative_flags.get("grand_casino_cheat_evidence", false)) or bool(_run.narrative_flags.get("grand_casino_watched_cheat_evidence", false)):
		return "cheat_evidence"
	var high_heat_threshold := clampi(int(config.get("memory_high_heat_threshold", 50)), 0, 100)
	if maxi(_run.suspicion_level(), int(_run.narrative_flags.get("grand_casino_max_heat", 0))) >= high_heat_threshold:
		return "high_heat"
	return "returning"


static func _grand_casino_staff_assignments(staffing: Dictionary) -> Dictionary:
	var assignments: Variant = staffing.get("assignments", {})
	return assignments if typeof(assignments) == TYPE_DICTIONARY else {}


func _grand_casino_room_id_from_context(context: Dictionary) -> String:
	var archetype_id := str(context.get("environment_archetype_id", "")).strip_edges()
	if _run.GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return archetype_id
	var environment_id := str(context.get("environment_id", "")).strip_edges()
	for room_id_value in [_run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, _run.GRAND_CASINO_ARCHETYPE_ID]:
		var room_id := str(room_id_value)
		if environment_id == room_id or environment_id.begins_with("%s_" % room_id):
			return room_id
	return _grand_casino_room_id_for_environment(_run.current_environment)


func _grand_casino_room_id_for_environment(environment: Dictionary) -> String:
	if environment.is_empty():
		return ""
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if _run.GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return archetype_id
	var environment_id := str(environment.get("id", "")).strip_edges()
	for room_id_value in [_run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, _run.GRAND_CASINO_ARCHETYPE_ID]:
		var room_id := str(room_id_value)
		if environment_id == room_id or environment_id.begins_with("%s_" % room_id):
			return room_id
	return ""


func _grand_casino_room_display_name(room_id: String) -> String:
	match room_id:
		_run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			return "High-Limit Room"
		_run.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
			return "Back Room"
		_:
			return "Main Floor"


func _grand_casino_active_security_event_sources(environment: Dictionary) -> Array:
	var sources: Array = []
	var resolved_event_ids := JsonCoerceScript._copy_array(environment.get("resolved_event_ids", []))
	for event_id_value in JsonCoerceScript._copy_array(environment.get("event_ids", [])):
		var event_id := str(event_id_value)
		if resolved_event_ids.has(event_id):
			continue
		if event_id == "pit_boss_sweep" or event_id == "eye_in_the_sky":
			_run._append_unique_string(sources, event_id)
	return sources


func _grand_casino_objective_config(objective: Dictionary) -> Dictionary:
	var target_bankroll := maxi(0, int(objective.get("target_bankroll", objective.get("high_roller_target_bankroll", 0))))
	var high_roller_target := maxi(0, int(objective.get("high_roller_target_bankroll", target_bankroll)))
	var modifiers = _run.challenge_modifiers()
	var prestige_heat_delta := mini(0, int(modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta", 0))) if bool(modifiers.get("grand_casino_prestige", false)) else 0
	var high_roller_net := maxi(0, int(objective.get("high_roller_net_winnings", 0)) + int(modifiers.get("grand_casino_high_roller_net_delta", 0)))
	var high_roller_max_heat := clampi(int(objective.get("high_roller_max_heat", 100)) + int(modifiers.get("grand_casino_high_roller_max_heat_delta", 0)) + prestige_heat_delta, 0, 100)
	var config := {
		"target_bankroll": target_bankroll,
		"high_roller_target_bankroll": high_roller_target,
		"high_roller_net_winnings": high_roller_net,
		"high_roller_min_grand_casino_games": maxi(0, int(objective.get("high_roller_min_grand_casino_games", 0))),
		"high_roller_max_heat": high_roller_max_heat,
		"showdown_heat_threshold": clampi(int(objective.get("showdown_heat_threshold", 70)), 0, 100),
		"forced_showdown_heat_threshold": clampi(int(objective.get("forced_showdown_heat_threshold", 95)), 0, 100),
		"showdown_event_id": str(objective.get("showdown_event_id", objective.get("finale_event_id", _run.GRAND_CASINO_SHOWDOWN_EVENT_ID))).strip_edges(),
		"high_roller_event_id": str(objective.get("high_roller_event_id", _run.GRAND_CASINO_HIGH_ROLLER_EVENT_ID)).strip_edges(),
	}
	var card_defaults := {
		"players_card_bronze_min_games": 1,
		"players_card_bronze_net_winnings": 5,
		"players_card_bronze_max_heat": 30,
		"players_card_bronze_chip_bonus": 5,
		"players_card_bronze_drink_comps": 1,
		"players_card_silver_min_games": 3,
		"players_card_silver_net_winnings": 15,
		"players_card_silver_max_heat": 30,
		"players_card_silver_chip_bonus": 10,
		"players_card_silver_drink_comps": 1,
		"players_card_silver_suite_rests": 1,
		"players_card_gold_min_games": int(config.get("high_roller_min_grand_casino_games", 5)),
		"players_card_gold_net_winnings": high_roller_net,
		"players_card_gold_max_heat": high_roller_max_heat,
		"players_card_look_away_max_heat_gain": 5,
		"players_card_comp_drink_alcohol": 8,
		"players_card_suite_rest_minutes": 240,
		"players_card_suite_heat_recovery": 12,
		"players_card_suite_drunk_recovery": 24,
	}
	for key in card_defaults:
		var configured_value := int(objective.get(key, card_defaults[key]))
		if _run.is_tutorial_run() and key == "players_card_bronze_net_winnings":
			config[key] = clampi(configured_value, -10000, 10000)
		else:
			config[key] = maxi(0, configured_value)
	for heat_key in ["players_card_bronze_max_heat", "players_card_silver_max_heat", "players_card_gold_max_heat"]:
		config[heat_key] = clampi(int(objective.get(heat_key, card_defaults[heat_key])) + prestige_heat_delta, 0, 100)
	config["players_card_gold_min_games"] = maxi(int(config.get("players_card_gold_min_games", 0)), int(config.get("high_roller_min_grand_casino_games", 0)))
	config["players_card_gold_net_winnings"] = maxi(int(config.get("players_card_gold_net_winnings", 0)), high_roller_net)
	config["players_card_gold_max_heat"] = clampi(int(config.get("players_card_gold_max_heat", high_roller_max_heat)), 0, 100)
	return config


func _grand_casino_players_card_awarded_tier() -> String:
	var tier_id := str(_run.narrative_flags.get(
		"grand_casino_players_card_awarded_tier",
		_run.narrative_flags.get("grand_casino_players_card_tier", _run.GRAND_CASINO_PLAYERS_CARD_TIER_NONE)
	)).strip_edges().to_lower()
	return tier_id if _run.GRAND_CASINO_PLAYERS_CARD_TIERS.has(tier_id) else _run.GRAND_CASINO_PLAYERS_CARD_TIER_NONE


func _grand_casino_players_card_tier_index(tier_id: String) -> int:
	var index = _run.GRAND_CASINO_PLAYERS_CARD_TIERS.find(tier_id.strip_edges().to_lower())
	return maxi(0, index)


func _grand_casino_players_card_tier_definitions(config: Dictionary) -> Array:
	return [
		{
			"id": _run.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE,
			"label": "Bronze",
			"min_games": int(config.get("players_card_bronze_min_games", 1)),
			"net_winnings": int(config.get("players_card_bronze_net_winnings", 5)),
			"max_heat": int(config.get("players_card_bronze_max_heat", 30)),
			"chip_bonus": int(config.get("players_card_bronze_chip_bonus", 0)),
			"drink_comps": int(config.get("players_card_bronze_drink_comps", 0)),
			"suite_rests": 0,
			"benefits": ["Bar drink comp", "Small chip bonus", "Linda conversations"],
		},
		{
			"id": _run.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER,
			"label": "Silver",
			"min_games": int(config.get("players_card_silver_min_games", 3)),
			"net_winnings": int(config.get("players_card_silver_net_winnings", 15)),
			"max_heat": int(config.get("players_card_silver_max_heat", 30)),
			"chip_bonus": int(config.get("players_card_silver_chip_bonus", 0)),
			"drink_comps": int(config.get("players_card_silver_drink_comps", 0)),
			"suite_rests": int(config.get("players_card_silver_suite_rests", 0)),
			"benefits": ["High-Limit Room access", "Improved comps", "One Linda look-away", "Suite rest"],
		},
		{
			"id": _run.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD,
			"label": "Gold",
			"min_games": int(config.get("players_card_gold_min_games", config.get("high_roller_min_grand_casino_games", 5))),
			"net_winnings": int(config.get("players_card_gold_net_winnings", config.get("high_roller_net_winnings", 30))),
			"max_heat": int(config.get("players_card_gold_max_heat", config.get("high_roller_max_heat", 30))),
			"chip_bonus": 0,
			"drink_comps": 0,
			"suite_rests": 0,
			"benefits": ["Gold review completes the clean route"],
		},
	]


func _grand_casino_players_card_tier_definition(config: Dictionary, tier_id: String) -> Dictionary:
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if str(definition.get("id", "")) == tier_id:
			return definition
	return {}


func _grand_casino_players_card_next_definition(config: Dictionary, tier_id: String) -> Dictionary:
	var current_index := _grand_casino_players_card_tier_index(tier_id)
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if _grand_casino_players_card_tier_index(str(definition.get("id", ""))) > current_index:
			return definition
	return {}


func _grand_casino_players_card_benefits(config: Dictionary, tier_id: String) -> Array:
	var benefits: Array = []
	var current_index := _grand_casino_players_card_tier_index(tier_id)
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if _grand_casino_players_card_tier_index(str(definition.get("id", ""))) > current_index:
			break
		for benefit_value in JsonCoerceScript._copy_array(definition.get("benefits", [])):
			var benefit := str(benefit_value)
			if not benefits.has(benefit):
				benefits.append(benefit)
	return benefits


func _grand_casino_derived_state(source: Dictionary, high_roller_ready: bool, showdown_pending: bool, showdown_active: bool) -> String:
	if _run.run_status == _run.RUN_STATUS_ENDED and bool(_run.narrative_flags.get("demo_victory", false)):
		return _run.GRAND_CASINO_STATE_VICTORY
	if _run.run_status == _run.RUN_STATUS_FAILED:
		return _run.GRAND_CASINO_STATE_FAILURE
	if showdown_active:
		return _run.GRAND_CASINO_STATE_SHOWDOWN_ACTIVE
	if showdown_pending:
		return _run.GRAND_CASINO_STATE_SHOWDOWN_PENDING
	if high_roller_ready:
		return _run.GRAND_CASINO_STATE_HIGH_ROLLER_READY
	if _run._is_grand_casino_environment(source):
		return _run.GRAND_CASINO_STATE_INCOMPLETE
	return _run.GRAND_CASINO_STATE_PRE


func _grand_casino_objective_summary(high_roller_ready: bool, showdown_pending: bool, heat_route_ready: bool, dirty_money_showdown_ready: bool, money_target_met: bool, game_target_met: bool, _target_bankroll: int, required_net: int, remaining_games: int) -> String:
	if showdown_pending:
		return "Rourke wants you past the friendly lights."
	if high_roller_ready:
		return "Gold Players Card review is ready at the Cage."
	if dirty_money_showdown_ready:
		return "The Players Card review put your win on Rourke's desk."
	if heat_route_ready:
		return "Your heat has Rourke walking toward the table."
	if not money_target_met:
		return "Win $%d clean on the Grand Casino floor toward Gold." % required_net
	if not game_target_met:
		return "Play %d more Grand Casino game%s before Linda can open Gold review." % [remaining_games, "" if remaining_games == 1 else "s"]
	return "Keep heat low so Linda can open Gold review."


func _grand_casino_result_has_wager(result: Dictionary) -> bool:
	# Blackjack debits the wager on Deal, then returns the settled outcome as a
	# separate result. The wager-placement receipt is not a completed hand and
	# must never advance Players Card progress.
	if str(result.get("game_id", "")) == "blackjack":
		return str(result.get("action_id", "")) == "play_basic" and int(result.get("stake", 0)) > 0
	if int(result.get("stake", 0)) > 0 or int(result.get("stake_cost", 0)) > 0:
		return true
	var deltas := JsonCoerceScript._copy_dict(result.get("deltas", {}))
	for key in ["stake_cost", "slot_stake_cost", "bar_dice_stake", "video_poker_bet", "baccarat_total_wager", "roulette_total_wager"]:
		if int(result.get(key, deltas.get(key, 0))) > 0:
			return true
	for entry_value in JsonCoerceScript._copy_array(deltas.get("story_log", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if int(entry.get("stake_cost", 0)) > 0:
			return true
	return false


func _grand_casino_result_pit_boss_heat_bonus(result: Dictionary) -> int:
	var bonus := 0
	var deltas := JsonCoerceScript._copy_dict(result.get("deltas", {}))
	for key in ["pit_boss_heat_bonus", "slot_pit_boss_heat_bonus"]:
		bonus = maxi(bonus, int(result.get(key, deltas.get(key, 0))))
	for entry_value in JsonCoerceScript._copy_array(deltas.get("story_log", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		bonus = maxi(bonus, int(entry.get("pit_boss_heat_bonus", 0)))
	return bonus


func _grand_casino_room_states_for_save(deep_copy: bool = true) -> Dictionary:
	var result: Dictionary = {}
	var active_room_id := ""
	if _run._is_grand_casino_environment(_run.current_environment):
		active_room_id = str(_run.current_environment.get("archetype_id", _run.GRAND_CASINO_ARCHETYPE_ID)).strip_edges()
	for room_id_value in _run.GRAND_CASINO_ARCHETYPE_IDS:
		var room_id := str(room_id_value)
		# current_environment already serializes the active room. Re-inserting it
		# on load avoids duplicating that potentially large game/layout payload.
		if room_id == active_room_id:
			continue
		var room: Variant = grand_casino_room_states.get(room_id, {})
		if typeof(room) == TYPE_DICTIONARY and not (room as Dictionary).is_empty():
			result[room_id] = _run._environment_for_persistent_storage(room as Dictionary, deep_copy)
	return result
