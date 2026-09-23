class_name PlayerText
extends RefCounted

# Shared player-facing text boundary. Simulation and authority code may retain
# detailed diagnostics, while presentation consumes stable keys and parameters.

const COUNT_FORMS := {
	"ticket": ["ticket", "tickets"],
	"active_row": ["active row", "active rows"],
	"action": ["action", "actions"],
	"chip": ["chip", "chips"],
	"tray_ticket": ["tray ticket", "tray tickets"],
	"deal_row": ["deal row", "deal rows"],
	"bet_won": ["won", "won"],
	"bet_lost": ["lost", "lost"],
	"bet_pushed": ["pushed", "pushed"],
}

const SEALED_ACTION_KEYS := {
	"invalid_intent": "sealed_action.unavailable",
	"pending_delivery": "sealed_action.pending",
	"stale_boundary": "sealed_action.stale",
	"unknown_receipt": "sealed_action.receipt_missing",
	"invalid_proposal": "sealed_action.unavailable",
	"apply_receipt_rejected": "sealed_action.retry_failed",
	"environment_turn_failed": "sealed_action.boundary_failed",
	"invalid_cache": "sealed_action.stale",
	"internal_fail_closed": "sealed_action.failed_closed",
}


static func sealed_action_message_key(error_code: String) -> String:
	return str(SEALED_ACTION_KEYS.get(error_code, "sealed_action.failed_closed"))


static func resolve(key: String, params: Dictionary = {}) -> String:
	match key:
		"sealed_action.pending":
			return "That action is still being delivered. Please wait."
		"sealed_action.stale":
			return "That action is no longer current. Review the table and try again."
		"sealed_action.receipt_missing":
			return "The action receipt could not be verified. Nothing was changed."
		"sealed_action.retry_failed":
			return "That action could not be completed. Nothing was changed."
		"sealed_action.boundary_failed":
			return "The room could not complete that action. Nothing was changed."
		"sealed_action.unavailable":
			return "That action is not available right now."
		"sealed_action.retrying":
			var retry_provider := str(params.get("provider_label", "")).strip_edges()
			return "Retrying the sealed action." if retry_provider.is_empty() else "Retrying %s's sealed action." % retry_provider
		"sealed_action.cancelled":
			var cancel_provider := str(params.get("provider_label", "")).strip_edges()
			return "The pending sealed action was cancelled." if cancel_provider.is_empty() else "%s's pending sealed action was cancelled." % cancel_provider
		"sealed_action.mismatch":
			var mismatch_provider := str(params.get("provider_label", "")).strip_edges()
			return "The sealed action no longer matches this request. Nothing was changed." if mismatch_provider.is_empty() else "%s's sealed action no longer matches this request. Nothing was changed." % mismatch_provider
		"sealed_action.failed_closed":
			return "That action could not be verified. Nothing was changed."
		"game.result.currency_settlement":
			if params.has("currency") and params.has("delta"):
				return format_settlement_delta(str(params.get("currency", "cash")), int(params.get("delta", 0)))
			return format_currency_settlement(int(params.get("cash_delta", 0)), int(params.get("chips_delta", 0)))
	return str(params.get("fallback", key))


static func count_text(noun_key: String, count: int) -> String:
	var forms: Array = COUNT_FORMS.get(noun_key, [noun_key.replace("_", " "), "%ss" % noun_key.replace("_", " ")])
	return "%d %s" % [count, str(forms[0] if count == 1 else forms[1])]


static func currency_account_label(currency: String) -> String:
	return "CHIPS" if currency.strip_edges().to_lower() == "chips" else "CASH"


static func format_currency_amount(currency: String, amount: int, uppercase_chip_noun: bool = false) -> String:
	if currency.strip_edges().to_lower() == "chips":
		var noun := "chip" if absi(amount) == 1 else "chips"
		return "%d %s" % [amount, noun.to_upper() if uppercase_chip_noun else noun]
	return "$%d" % amount


static func format_currency_account_balance(currency: String, amount: int) -> String:
	if currency.strip_edges().to_lower() == "chips":
		return "%s %d" % [currency_account_label(currency), amount]
	return "%s %s" % [currency_account_label(currency), format_currency_amount(currency, amount)]


static func join_sentences(parts: Array) -> String:
	var clean: Array[String] = []
	for value in parts:
		var part := str(value).strip_edges()
		if not part.is_empty():
			clean.append(part)
	return " ".join(clean)


static func format_time_of_day(total_minutes: int) -> String:
	var minute_of_day := posmod(total_minutes, 1440)
	var hour_24 := int(floor(float(minute_of_day) / 60.0)) % 24
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute_of_day % 60, "AM" if hour_24 < 12 else "PM"]


static func format_game_clock(total_minutes: int, include_day: bool = true, day_separator: String = " ") -> String:
	var safe_minutes := maxi(0, total_minutes)
	var time_text := format_time_of_day(safe_minutes)
	if not include_day:
		return time_text
	return "Day %d%s%s" % [int(floor(float(safe_minutes) / 1440.0)) + 1, day_separator, time_text]


static func format_currency_settlement(cash_delta: int, chips_delta: int) -> String:
	var parts: Array[String] = []
	if cash_delta != 0:
		parts.append(format_settlement_delta("cash", cash_delta))
	if chips_delta != 0:
		parts.append(format_settlement_delta("chips", chips_delta))
	return join_sentences(parts) if not parts.is_empty() else "No balance change."


static func format_settlement_delta(currency: String, delta: int) -> String:
	if currency.strip_edges().to_lower() == "chips":
		return "Chip change: %+d %s." % [delta, count_text("chip", absi(delta)).trim_prefix("%d " % absi(delta))]
	return "Cash change: %+d." % delta
