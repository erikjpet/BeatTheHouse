class_name CageWindowViewModel
extends RefCounted


static func build(run_state: RunState) -> Dictionary:
	if run_state == null or not run_state.is_grand_casino_environment():
		return {}
	var objective := run_state.demo_objective_status()
	var flags := run_state.narrative_flags
	var card_eligible := bool(objective.get("players_card_eligible", true))
	var review_blocked := bool(flags.get("grand_casino_attention_high_roller_review", false)) or bool(objective.get("showdown_pending", false)) or bool(objective.get("showdown_active", false))
	var review_ready := card_eligible and not review_blocked and (bool(objective.get("high_roller_ready", false)) or bool(flags.get("high_roller_cashout_pending", false)))
	var review_state := "progress"
	var review_title := "Tier progress"
	if not card_eligible:
		review_state = "ineligible"
		review_title = "Card program closed"
	elif review_ready:
		review_state = "ready"
		review_title = "Gold review ready"
	elif review_blocked:
		review_state = "blocked"
		review_title = "Review routed to Rourke"
	var review_detail := _review_detail(objective, flags, review_state)
	var linda_line := _linda_line(objective, review_state)
	var rate := run_state.grand_casino_chip_exchange_rate()
	var benefits := _copy_strings(objective.get("players_card_benefits", []))
	var promotions := benefits.duplicate()
	var drink_comps := maxi(0, int(objective.get("players_card_drink_comps", 0)))
	var suite_rests := maxi(0, int(objective.get("players_card_suite_rests", 0)))
	if drink_comps > 0:
		promotions.append("%d drink comp%s ready" % [drink_comps, "" if drink_comps == 1 else "s"])
	if suite_rests > 0:
		promotions.append("%d suite rest%s ready" % [suite_rests, "" if suite_rests == 1 else "s"])
	if bool(objective.get("players_card_look_away_available", false)):
		promotions.append("Linda look-away ready")
	var benefit_text := "No tier benefits yet."
	if not benefits.is_empty():
		benefit_text = "Benefits: %s" % ", ".join(benefits)
	var promotions_empty := "No promotions or comps are available right now."
	if not card_eligible:
		promotions_empty = "Cheat evidence closed this account for the run."
	return {
		"title": "The Cage",
		"host": {
			"id": "linda",
			"name": "Linda",
			"role": "cage_host",
			"silhouette": "vest",
			"hair_color": "#2a1824",
			"jacket_color": "#234052",
			"line": linda_line,
		},
		"balance": {
			"cash": run_state.bankroll,
			"chips": run_state.grand_casino_chips,
			"rate": rate,
			"total": run_state.grand_casino_total_money(),
		},
		"buy_options": _buy_options(run_state.bankroll, rate),
		"can_cash_out": run_state.grand_casino_chips > 0,
		"card": {
			"tier": str(objective.get("players_card_tier_label", "Unranked")),
			"progress": _card_progress(objective),
			"benefit": benefit_text,
			"benefits": benefits,
			"eligible": card_eligible,
			"review_state": review_state,
			"review_title": review_title,
			"review_detail": review_detail,
			"can_review": review_ready,
		},
		"promotions": promotions,
		"promotions_empty": promotions_empty,
		"comp_actions": [
			{"id": "drink", "label": "Use Drink Comp", "enabled": card_eligible and drink_comps > 0},
			{"id": "suite_rest", "label": "Use Suite Rest", "enabled": card_eligible and suite_rests > 0},
		],
	}


static func _buy_options(bankroll: int, rate: int) -> Array:
	var result: Array = []
	var maximum := maxi(0, bankroll / maxi(1, rate))
	for amount in [25, 50]:
		if amount <= maximum:
			result.append(amount)
	if maximum > 0 and not result.has(maximum):
		result.append(maximum)
	return result


static func _card_progress(objective: Dictionary) -> String:
	if not bool(objective.get("players_card_eligible", true)):
		return str(objective.get("players_card_ineligible_reason", "Cheat evidence closed the card program for this run."))
	var next_label := str(objective.get("players_card_next_tier_label", ""))
	if next_label.is_empty():
		return "Gold earned. Complete Linda's review at the Cage."
	return "%s: %d/%d games, $%d/$%d net, heat %d/%d." % [
		next_label,
		int(objective.get("grand_casino_games_played", 0)),
		int(objective.get("players_card_next_min_games", 0)),
		int(objective.get("grand_casino_net_winnings", 0)),
		int(objective.get("players_card_next_net_winnings", 0)),
		int(objective.get("grand_casino_max_heat", objective.get("current_heat", 0))),
		int(objective.get("players_card_next_max_heat", 0)),
	]


static func _review_detail(objective: Dictionary, flags: Dictionary, state: String) -> String:
	if state == "ineligible":
		return "Cheat evidence permanently closes every Players Card tier this run."
	if state == "ready":
		return "Clean play is verified. Complete Linda's Gold review before heat changes it."
	if state == "blocked":
		var reason := str(flags.get("grand_casino_showdown_trigger_reason", "")).strip_edges()
		if reason == "dirty_money" or bool(flags.get("grand_casino_cheat_evidence", false)):
			return "The win cannot clear clean review; Linda has routed the account to Rourke."
		return "Casino attention has frozen the review and routed the account to Rourke."
	var heat := int(objective.get("current_heat", 0))
	return "Keep play clean and heat controlled. Current heat: %d." % heat


static func _linda_line(objective: Dictionary, state: String) -> String:
	if state == "ineligible":
		return "I cannot put a card on an account with evidence."
	if state == "ready":
		return "Your Gold review is ready. I can finish it here."
	if state == "blocked":
		return "Rourke put a hold on this review. The floor will come for you."
	var tier := str(objective.get("players_card_tier_label", "Unranked"))
	return "%s is on the account. Keep the count clean." % tier


static func _copy_strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		result.append(str(entry_value))
	return result
