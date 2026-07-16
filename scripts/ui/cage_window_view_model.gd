class_name CageWindowViewModel
extends RefCounted


static func build(run_state: RunState) -> Dictionary:
	if run_state == null or not run_state.is_grand_casino_environment():
		return {}
	var objective := run_state.demo_objective_status()
	var flags := run_state.narrative_flags
	var review_blocked := bool(flags.get("grand_casino_attention_high_roller_review", false)) or bool(objective.get("showdown_pending", false)) or bool(objective.get("showdown_active", false))
	var review_ready := not review_blocked and (bool(objective.get("high_roller_ready", false)) or bool(flags.get("high_roller_cashout_pending", false)))
	var review_state := "ready" if review_ready else "blocked" if review_blocked else "progress"
	var review_title := "Review ready" if review_ready else "Review routed to Rourke" if review_blocked else "Review in progress"
	var review_detail := _review_detail(objective, flags, review_state)
	var linda_line := "Your Players Card review is ready. I can finish it here." if review_ready else "Rourke put a hold on this review. The floor will come for you." if review_blocked else "Cash and chips are even here. I keep the count clean."
	var rate := run_state.grand_casino_chip_exchange_rate()
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
			"tier": "Unranked",
			"progress": _card_progress(objective),
			"benefit": "Tier benefits arrive with the full Players Card program.",
			"review_state": review_state,
			"review_title": review_title,
			"review_detail": review_detail,
			"can_review": review_ready,
		},
		"promotions": [],
		"promotions_empty": "No promotions or comps are available right now.",
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
	var remaining_games := maxi(0, int(objective.get("high_roller_remaining_games", 0)))
	var remaining_net := maxi(0, int(objective.get("high_roller_remaining_net_winnings", 0)))
	if remaining_games <= 0 and remaining_net <= 0:
		return "Play and cash cleanly while Linda watches the account."
	return "%d settled game%s and %d net value remain." % [remaining_games, "" if remaining_games == 1 else "s", remaining_net]


static func _review_detail(objective: Dictionary, flags: Dictionary, state: String) -> String:
	if state == "ready":
		return "Clean play is verified. Claim the Players Card before heat changes the review."
	if state == "blocked":
		var reason := str(flags.get("grand_casino_showdown_trigger_reason", "")).strip_edges()
		if reason == "dirty_money" or bool(flags.get("grand_casino_cheat_evidence", false)):
			return "The win cannot clear clean review; Linda has routed the account to Rourke."
		return "Casino attention has frozen the review and routed the account to Rourke."
	var heat := int(objective.get("current_heat", 0))
	return "Keep play clean and heat controlled. Current heat: %d." % heat
