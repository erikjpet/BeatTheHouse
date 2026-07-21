extends "res://scripts/tests/foundation/check_scratch_tickets.gd"

const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")


func _check_cage_environment_rework(_library: ContentLibrary, failures: Array) -> void:
	var exact_cashout := CageEconomyModelScript.cashout_preview(200, 200, 1, 150, 20)
	if not bool(exact_cashout.get("ok", false)) or int(exact_cashout.get("debt_after", -1)) != 0 or int(exact_cashout.get("chips_after", -1)) != 0 or int(exact_cashout.get("cash_paid", -1)) != 50:
		failures.append("Cage debt-first cashout contract did not settle debt 150/chips 200 into $50 cash.")
	var partial_cashout := CageEconomyModelScript.cashout_preview(100, 100, 1, 150, 20)
	if not bool(partial_cashout.get("ok", false)) or int(partial_cashout.get("debt_after", -1)) != 50 or int(partial_cashout.get("cash_paid", -1)) != 0:
		failures.append("Cage debt-first cashout contract did not accept a successful all-debt settlement.")
	var rate_cashout := CageEconomyModelScript.cashout_preview(100, 40, 2, 50, 20)
	if int(rate_cashout.get("gross_value", -1)) != 80 or int(rate_cashout.get("debt_paid", -1)) != 50 or int(rate_cashout.get("cash_paid", -1)) != 30:
		failures.append("Cage debt-first cashout contract did not apply the exchange rate to gross value.")
	for fixture in [
		{"old": 0, "expected": 0},
		{"old": 50, "expected": 53},
		{"old": 200, "expected": 210},
		{"old": 500, "expected": 525},
	]:
		if CageEconomyModelScript.interest_balance(int(fixture.get("old", 0))) != int(fixture.get("expected", 0)):
			failures.append("Cage ATM interest contract failed exact ceiling fixture %s." % JSON.stringify(fixture))
	var compounded := CageEconomyModelScript.interest_balance(CageEconomyModelScript.interest_balance(200))
	if compounded != 221:
		failures.append("Cage ATM interest contract did not compound $200 to $210 then $221.")
	var crossings := CageEconomyModelScript.crossed_interest_boundary_indices(179, 180 + 1440 * 2, -1)
	if crossings != [0, 1, 2]:
		failures.append("Cage ATM boundary contract did not enumerate every crossed 3:00 AM boundary.")
	var valid_borrow := CageEconomyModelScript.borrow_preview(450, 50)
	var capped_borrow := CageEconomyModelScript.borrow_preview(500, 50)
	var invalid_borrow := CageEconomyModelScript.borrow_preview(0, 25)
	if not bool(valid_borrow.get("ok", false)) or int(valid_borrow.get("debt_after", 0)) != 500 or bool(capped_borrow.get("ok", true)) or bool(invalid_borrow.get("ok", true)):
		failures.append("Cage ATM borrowing contract did not enforce $50 increments and the $500 new-credit cap.")
