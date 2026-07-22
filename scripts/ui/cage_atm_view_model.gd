class_name CageAtmViewModel
extends RefCounted

const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")


static func build(run_state: RunState) -> Dictionary:
	if run_state == null:
		return {}
	var status := run_state.grand_casino_atm_status()
	var debt := maxi(0, int(status.get("debt", 0)))
	var cash := maxi(0, int(status.get("cash", 0)))
	var next_boundary := int(status.get("next_interest_absolute_minute", 0))
	var borrow_options: Array = []
	for amount in range(CageEconomyModelScript.LOAN_INCREMENT, CageEconomyModelScript.LOAN_CAP + 1, CageEconomyModelScript.LOAN_INCREMENT):
		var preview := CageEconomyModelScript.borrow_preview(debt, amount)
		if bool(preview.get("ok", false)):
			borrow_options.append(preview)
	var repay_options: Array = []
	for amount in [1, 10, 50]:
		var preview := CageEconomyModelScript.repayment_preview(debt, cash, amount)
		repay_options.append({
			"amount": amount,
			"enabled": bool(preview.get("ok", false)),
			"reason": str(preview.get("reason", "")),
			"preview": preview,
		})
	var payoff := mini(debt, cash)
	return {
		"title": "Grand Casino ATM",
		"debt": debt,
		"cash": cash,
		"available_credit": int(status.get("available_credit", 0)),
		"loan_increment": CageEconomyModelScript.LOAN_INCREMENT,
		"loan_cap": CageEconomyModelScript.LOAN_CAP,
		"origination_fee": CageEconomyModelScript.ORIGINATION_FEE,
		"borrow_options": borrow_options,
		"repay_options": repay_options,
		"payoff_amount": payoff,
		"can_pay_in_full": debt > 0 and cash >= debt,
		"next_interest_absolute_minute": next_boundary,
		"next_interest_label": "Day %d, 3 AM" % (int(floor(float(next_boundary) / 1440.0)) + 1),
		"interest_rate_percent": int(round(CageEconomyModelScript.DAILY_INTEREST_RATE * 100.0)),
		"projected_next_balance": int(status.get("projected_next_balance", 0)),
		"summary": "Marker $%d. Cash $%d. Next 5%% at Day %d, 3 AM: $%d." % [
			debt,
			cash,
			int(floor(float(next_boundary) / 1440.0)) + 1,
			int(status.get("projected_next_balance", 0)),
		],
	}


static func inline_actions(run_state: RunState) -> Array:
	var model := build(run_state)
	if model.is_empty():
		return []
	var debt := int(model.get("debt", 0))
	var cash := int(model.get("cash", 0))
	var actions: Array = []
	var borrow := CageEconomyModelScript.borrow_preview(debt, CageEconomyModelScript.LOAN_INCREMENT)
	actions.append({
		"id": "borrow_50",
		"emit_object_id": "cage_atm_action:borrow:50",
		"label": "Borrow $50",
		"detail": "Receive $50; marker becomes $%d." % int(borrow.get("debt_after", debt)),
		"enabled": bool(borrow.get("ok", false)),
		"disabled_reason": str(borrow.get("reason", "")),
	})
	for amount in [1, 50]:
		var repay := CageEconomyModelScript.repayment_preview(debt, cash, amount)
		actions.append({
			"id": "repay_%d" % amount,
			"emit_object_id": "cage_atm_action:repay:%d" % amount,
			"label": "Repay $%d" % amount,
			"detail": "Cash payment; marker becomes $%d." % int(repay.get("debt_after", debt)),
			"enabled": bool(repay.get("ok", false)),
			"disabled_reason": str(repay.get("reason", "")),
		})
	actions.append({
		"id": "repay_full",
		"emit_object_id": "cage_atm_action:repay:full",
		"label": "Pay in Full",
		"detail": "Pay $%d cash and clear the marker." % debt,
		"enabled": debt > 0 and cash >= debt,
		"disabled_reason": "Need $%d cash to settle in full." % debt if debt > cash else "No marker balance.",
	})
	return actions
