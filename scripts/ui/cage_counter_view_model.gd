class_name CageCounterViewModel
extends RefCounted

const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")


static func build(run_state: RunState) -> Dictionary:
	if run_state == null or not run_state.is_grand_casino_environment():
		return {}
	var objective := run_state.demo_objective_status()
	var flags := run_state.narrative_flags
	var prestige := run_state.grand_casino_prestige_status()
	var card_eligible := bool(objective.get("players_card_eligible", true))
	var review_blocked := bool(flags.get("grand_casino_attention_high_roller_review", false)) or bool(objective.get("showdown_pending", false)) or bool(objective.get("showdown_active", false))
	var claim_ready := bool(objective.get("players_card_ready_to_claim", false))
	var can_claim := bool(objective.get("players_card_can_claim", false)) and not review_blocked
	var next_tier_label := str(objective.get("players_card_next_tier_label", "Next"))
	var review_state := "progress"
	var review_title := "Tier progress"
	if not card_eligible:
		review_state = "ineligible"
		review_title = "Card program closed"
	elif can_claim:
		review_state = "ready"
		review_title = "%s ready" % next_tier_label
	elif claim_ready:
		review_state = "blocked"
		review_title = "%s claim on hold" % next_tier_label
	elif review_blocked:
		review_state = "blocked"
		review_title = "Review routed to Rourke"
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
	var cashout := CageEconomyModelScript.cashout_preview(run_state.grand_casino_chips, run_state.grand_casino_chips, rate, _atm_debt(run_state), run_state.bankroll)
	return {
		"title": "Cashout Counter",
		"host": {
			"id": "linda",
			"name": "Linda",
			"role": "cage_host",
			"silhouette": "featureless",
			"presentation": "faceless_silhouette",
			"face_layers": [],
			"line": _linda_line(objective, review_state),
		},
		"balance": {
			"cash": run_state.bankroll,
			"chips": run_state.grand_casino_chips,
			"rate": rate,
			"atm_debt": _atm_debt(run_state),
			"total": run_state.grand_casino_total_money(),
		},
		"buy_options": _buy_options(run_state.bankroll, rate),
		"can_cash_out": run_state.grand_casino_chips > 0,
		"cashout_preview": cashout,
		"card": {
			"tier": str(objective.get("players_card_tier_label", "Unranked")),
			"progress": _card_progress(objective),
			"benefit": benefit_text,
			"benefits": benefits,
			"eligible": card_eligible,
			"review_state": review_state,
			"review_title": review_title,
			"review_detail": _review_detail(objective, flags, review_state),
			"ready_to_claim": claim_ready,
			"can_claim": can_claim,
			"can_review": can_claim,
			"prestige": {
				"active": bool(prestige.get("active", false)),
				"title": "Prestige run recognized",
				"summary": "Linda recognizes your carried card. Initial attention is lower and the clean standard is tighter.",
			},
		},
		"promotions": promotions,
		"promotions_empty": "Cheat evidence closed this account for the run." if not card_eligible else "No promotions or comps are available right now.",
		"comp_actions": [
			{"id": "drink", "label": "Use Drink Comp", "enabled": card_eligible and drink_comps > 0},
			{"id": "suite_rest", "label": "Use Suite Rest", "enabled": card_eligible and suite_rests > 0},
		],
	}


static func service_summary(run_state: RunState, node_id: String) -> String:
	var model := build(run_state)
	if model.is_empty():
		return "Linda keeps the account closed."
	var balance: Dictionary = model.get("balance", {})
	var card: Dictionary = model.get("card", {})
	match node_id:
		"chips":
			var preview: Dictionary = model.get("cashout_preview", {})
			return "Cash $%d. Chips %d at %d:1. Cashout pays $%d to the marker and $%d to you." % [int(balance.get("cash", 0)), int(balance.get("chips", 0)), int(balance.get("rate", 1)), int(preview.get("debt_paid", 0)), int(preview.get("cash_paid", 0))]
		"card":
			return "%s. %s %s" % [str(card.get("tier", "Unranked")), str(card.get("progress", "")), str(card.get("review_detail", ""))]
		"comps":
			var promotions: Array = model.get("promotions", [])
			return ", ".join(promotions) if not promotions.is_empty() else str(model.get("promotions_empty", "No promotions are ready."))
	return "Cash $%d. Chips %d. Casino marker $%d. %s" % [int(balance.get("cash", 0)), int(balance.get("chips", 0)), int(balance.get("atm_debt", 0)), str(card.get("progress", ""))]


static func _atm_debt(run_state: RunState) -> int:
	return int(run_state.call("grand_casino_atm_debt")) if run_state.has_method("grand_casino_atm_debt") else 0


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
	return "%s: %d/%d games, $%d/$%d segment net, heat %d/%d." % [
		next_label,
		int(objective.get("players_card_segment_games", 0)),
		int(objective.get("players_card_next_min_games", 0)),
		int(objective.get("players_card_segment_net_winnings", 0)),
		int(objective.get("players_card_next_net_winnings", 0)),
		int(objective.get("players_card_segment_max_heat", objective.get("current_heat", 0))),
		int(objective.get("players_card_next_max_heat", 0)),
	]


static func _review_detail(objective: Dictionary, flags: Dictionary, state: String) -> String:
	if state == "ineligible":
		return "Cheat evidence permanently closes every Players Card tier this run."
	if state == "ready":
		return "Clean play is verified. Linda can issue the next tier here."
	if state == "blocked":
		return str(objective.get("players_card_claim_block_reason", "Casino attention has frozen the review."))
	return "Keep play clean and heat controlled. Current heat: %d." % int(objective.get("current_heat", 0))


static func _linda_line(objective: Dictionary, state: String) -> String:
	if state == "ineligible":
		return "I cannot put a card on an account with evidence."
	if state == "ready":
		return "Your next tier is ready. I can issue it here."
	if state == "blocked":
		return "Rourke put a hold on this review. The floor will come for you."
	return "%s is on the account. Keep the count clean." % str(objective.get("players_card_tier_label", "Unranked"))


static func _copy_strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		result.append(str(entry_value))
	return result
