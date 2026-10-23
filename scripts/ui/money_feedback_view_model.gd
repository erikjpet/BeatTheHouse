class_name MoneyFeedbackViewModel
extends RefCounted

# Presentation only. Amounts come from applied monetary mutations, never HUD
# balance comparisons. A frame coalesces a transfer's two legs without inventing
# income, while profile gold remains a separate monetary unit.
static func add_delta(pending: Dictionary, currency: String, delta: int) -> void:
	if currency in ["cash", "chips", "gold"] and delta != 0:
		pending[currency] = int(pending.get(currency, 0)) + delta


static func build(pending: Dictionary, push_currency: String = "", chip_cash_rate: int = 1) -> Array:
	var entries: Array = []
	var cash := int(pending.get("cash", 0))
	var chips := int(pending.get("chips", 0))
	if cash != 0 and chips != 0:
		# The Cage's canonical rate values chips when both accounts change.
		_append(entries, cash + chips * maxi(1, chip_cash_rate), "cash")
	else:
		_append(entries, cash, "cash")
		_append(entries, chips, "chips")
	_append(entries, int(pending.get("gold", 0)), "gold")
	if entries.is_empty() and pending.is_empty() and push_currency in ["cash", "chips"]:
		entries.append({"delta": 0, "currency": push_currency, "text": "0", "tone": "text_muted"})
	return entries


# Accumulate only entries already released to the HUD. Never exchange units or
# infer a settlement/push from a visible total crossing zero.
static func accumulate_visible(visible: Array, incoming: Array) -> Array:
	var totals: Dictionary = {}
	for group in [visible, incoming]:
		for entry in group:
			var currency := str(entry.get("currency", ""))
			if currency in ["cash", "chips", "gold"]:
				totals[currency] = int(totals.get(currency, 0)) + int(entry.get("delta", 0))
	var entries: Array = []
	for currency in totals:
		_append(entries, int(totals[currency]), str(currency))
	if entries.is_empty() and not totals.is_empty():
		entries.append({"delta": 0, "currency": totals.keys()[0], "text": "0", "tone": "text_muted"})
	return entries


static func _append(entries: Array, amount: int, currency: String) -> void:
	if amount == 0:
		return
	var sign_text := "+" if amount > 0 else "−"
	var unit := "$" if currency == "cash" else "◈" if currency == "chips" else ""
	var text := "%s%s%d%s" % [sign_text, unit, absi(amount), "g" if currency == "gold" else ""]
	entries.append({"delta": amount, "currency": currency, "text": text, "tone": "success" if amount > 0 else "danger"})


# A zero balance change alone is never a push. Require an applied settlement
# and an explicit push outcome for every settled hand/bet, not offsetting wins.
static func explicit_push_currency(result: Dictionary) -> String:
	if not bool(result.get("ok", false)) or bool(result.get("replayed", false)) or result.has("blackjack_host_replay"):
		return ""
	var settlement_value: Variant = result.get("settlement", {})
	if typeof(settlement_value) != TYPE_DICTIONARY:
		return ""
	var settlement: Dictionary = settlement_value
	if not settlement.has("delta") or int(settlement.get("delta", 1)) != 0:
		return ""
	var currency := str(settlement.get("currency", ""))
	if currency not in ["cash", "chips"]:
		return ""
	if str(result.get("outcome", "")) == "push" or bool(result.get("push", false)):
		return currency
	var found_push := false
	for key in ["blackjack_hand_results", "blackjack_side_bet_results", "baccarat_bet_results", "craps_bet_results"]:
		var rows_value: Variant = result.get(key, [])
		if typeof(rows_value) != TYPE_ARRAY or (rows_value as Array).is_empty():
			continue
		for row_value in rows_value:
			if typeof(row_value) != TYPE_DICTIONARY:
				return ""
			var row: Dictionary = row_value
			if str(row.get("outcome", "")) != "push" and not bool(row.get("push", false)):
				return ""
		found_push = true
	return currency if found_push else ""
