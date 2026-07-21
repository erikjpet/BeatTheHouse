class_name CageEconomyModel
extends RefCounted

const ROOM_ID := "grand_casino_cage"
const COUNTER_FIXTURE_ID := "cage_counter"
const ATM_FIXTURE_ID := "cage_atm"
const GIFT_SHOP_FIXTURE_ID := "cage_gift_shop"
const ATM_DEBT_ID := "grand_casino_atm_marker"
const ATM_DEBT_BALANCE_NAME := "grand_casino_atm_debt"

const LOAN_INCREMENT := 50
const LOAN_CAP := 500
const ORIGINATION_FEE := 0
const DAILY_INTEREST_RATE := 0.05
const INTEREST_MINUTE_OF_DAY := 180
const MINUTES_PER_DAY := 1440


static func borrow_preview(current_debt: int, amount: int) -> Dictionary:
	var normalized_debt := maxi(0, current_debt)
	var valid_increment := amount > 0 and amount % LOAN_INCREMENT == 0
	var resulting_debt := normalized_debt + maxi(0, amount)
	var allowed := valid_increment and normalized_debt < LOAN_CAP and resulting_debt <= LOAN_CAP
	var reason := ""
	if not valid_increment:
		reason = "Borrow in $%d increments." % LOAN_INCREMENT
	elif normalized_debt >= LOAN_CAP:
		reason = "The $%d marker limit is already reached." % LOAN_CAP
	elif resulting_debt > LOAN_CAP:
		reason = "That draw would exceed the $%d marker limit." % LOAN_CAP
	return {
		"ok": allowed,
		"amount": amount if allowed else 0,
		"cash_received": amount if allowed else 0,
		"debt_before": normalized_debt,
		"debt_after": resulting_debt if allowed else normalized_debt,
		"reason": reason,
	}


static func interest_balance(old_balance: int, rate: float = DAILY_INTEREST_RATE) -> int:
	if old_balance <= 0:
		return 0
	return int(ceili(float(old_balance) * (1.0 + maxf(0.0, rate))))


static func boundary_index_at_or_before(absolute_minutes: int) -> int:
	return int(floor(float(absolute_minutes - INTEREST_MINUTE_OF_DAY) / float(MINUTES_PER_DAY)))


static func next_interest_boundary(absolute_minutes: int) -> int:
	return INTEREST_MINUTE_OF_DAY + (boundary_index_at_or_before(absolute_minutes) + 1) * MINUTES_PER_DAY


static func crossed_interest_boundary_indices(previous_minutes: int, current_minutes: int, processed_index: int) -> Array:
	var result: Array = []
	if current_minutes <= previous_minutes:
		return result
	var first_index := maxi(processed_index + 1, boundary_index_at_or_before(previous_minutes) + 1)
	var final_index := boundary_index_at_or_before(current_minutes)
	for boundary_index in range(first_index, final_index + 1):
		result.append(boundary_index)
	return result


static func cashout_preview(current_chips: int, requested_chips: int, exchange_rate: int, current_debt: int, bankroll: int) -> Dictionary:
	var normalized_rate := maxi(1, exchange_rate)
	var normalized_debt := maxi(0, current_debt)
	var valid := requested_chips > 0 and requested_chips <= maxi(0, current_chips)
	var gross_value := requested_chips * normalized_rate if valid else 0
	var debt_paid := mini(gross_value, normalized_debt)
	var cash_paid := gross_value - debt_paid
	return {
		"ok": valid,
		"requested_chips": requested_chips,
		"exchange_rate": normalized_rate,
		"gross_value": gross_value,
		"debt_before": normalized_debt,
		"debt_paid": debt_paid,
		"debt_after": normalized_debt - debt_paid,
		"cash_paid": cash_paid,
		"chips_before": maxi(0, current_chips),
		"chips_after": maxi(0, current_chips) - requested_chips if valid else maxi(0, current_chips),
		"cash_before": bankroll,
		"cash_after": bankroll + cash_paid,
		"reason": "" if valid else "Choose a positive chip amount no greater than your balance.",
	}


static func repayment_preview(current_debt: int, bankroll: int, requested_amount: int) -> Dictionary:
	var normalized_debt := maxi(0, current_debt)
	var maximum := mini(normalized_debt, maxi(0, bankroll))
	var valid := requested_amount >= 1 and requested_amount <= maximum
	return {
		"ok": valid,
		"amount": requested_amount if valid else 0,
		"debt_before": normalized_debt,
		"debt_after": normalized_debt - requested_amount if valid else normalized_debt,
		"cash_before": bankroll,
		"cash_after": bankroll - requested_amount if valid else bankroll,
		"reason": "" if valid else "Choose a whole-dollar amount covered by both cash and marker balance.",
	}
