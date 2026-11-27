extends RefCounted

const Opening := preload("res://tools/rourke_solver/rourke_opening_policy.gd")
const TIERS := ["bronze", "silver", "gold"]
const STANDARD_HANDS := [1, 3, 5]
const STANDARD_NET := [5, 15, 30]
const OPENING_CHIPS := 50
const WAIT := "wait 16"
const DEAL_POLL_FRAMES := 48
const DEAL_WAIT_FRAMES := 480
const DEAL_PRESENTATION_LIMIT_FRAMES := 720
const MAX_TABLE_RESEATS := 2
const ACTIVE_TABLE_PRESENTATIONS := ["initial_deal", "dealer_procedure", "settlement", "player_turn"]
const WARNING_CHOICES := {
	"eye_in_the_sky": "change_table",
	"blackjack_counter_probe": "play_dumb",
	"shift_change": "ignore",
	"floor_staff_heat_warning": "play_cool",
	"pit_boss_heat_warning": "walk_now",
}

var room := Opening.new()
var progress_pattern := RegEx.create_from_string("(?i)(bronze|silver|gold)(?: progress)?: (\\d+)/(\\d+) games, \\$(-?\\d+)/\\$(\\d+) segment net, heat (\\d+)/(\\d+)")
var marker_pattern := RegEx.create_from_string("(?i)casino marker \\$(\\d+)")
var marker_claim_pattern := RegEx.create_from_string("Settle the \\$(\\d+) Grand Casino ATM marker before Linda can issue")
var tier_index := 0
var required_hands := 1
var required_net := 5
var heat_ceiling := 30
var peak_heat := 0
var settled_hands := 0
var segment_baseline := -1
var consecutive_losses := 0
var last_round_delta := 0
var table_minimum := 5
var marker_balance := 0
var last_visible_cash := -1
var hand_open := false
var hand_advanced := false
var betting_polls := 0
var hand_start_total := -1
var hand_start_message := ""
var hand_total_before_warning := -1
var recovery_venue := ""
var deal_wait_frames := 0
var table_reseats := 0
var recovery_back_command := ""
var force_minimum := false
var opening_buy_in := false
var ledger_checked := false
var checked_at_hand := -1
var claim_ready := false
var suite_rest_requested := false
var result_map_closed := false
var accepted_gold := false
var blocked_reason := ""


func decide(view: Dictionary) -> String:
	recovery_back_command = ""
	var screen: Dictionary = view.get("screen", {})
	var game: Dictionary = view.get("game", {})
	var hud: Dictionary = view.get("status_hud", {})
	var room_id := str(view.get("environment", {}).get("archetype_id", ""))
	var screen_id := str(screen.get("screen", ""))
	var cash := _hud_value(hud, "bankroll")
	var chips := _hud_value(hud, "chips")
	var heat := int(hud.get("heat_level", 0)) if bool(hud.get("heat_rendered", false)) else -1
	if room_id != recovery_venue:
		recovery_venue = room_id
		last_visible_cash = -1
		_reset_table_recovery()
	if not room_id.begins_with("grand_casino"):
		return ""
	if cash >= 0:
		last_visible_cash = cash
	# Ordinary Blackjack settles in chips. Remember cash seen before the hand
	# when its label is obscured by a table warning or a result overlay.
	var total := _observed_total(view)
	if segment_baseline < 0 and total >= 0:
		segment_baseline = total
	if heat >= 0:
		peak_heat = maxi(peak_heat, heat)
	if not opening_buy_in and (chips >= OPENING_CHIPS or (chips >= table_minimum and cash >= 0 and cash < 25)):
		opening_buy_in = true
	if str(game.get("game_id", "")) == "blackjack" and int(game.get("stake_min", 0)) > 0:
		table_minimum = int(game["stake_min"])
	_update_hand(game, total)
	if not hand_open:
		_read_progress(str(view.get("objective_text", "")), total)
	var talk: Dictionary = view.get("talk", {})
	if bool(talk.get("render_valid", false)) and bool(talk.get("body_complete", false)):
		_read_progress(str(talk.get("summary", "")), total)
	if bool(hud.get("debt_indicator", {}).get("rendered", false)) and not bool(hud.get("debt_indicator", {}).get("present", false)):
		marker_balance = 0
	var settled_total := hand_start_total if hand_open and hand_start_total >= 0 else total
	var segment_net := settled_total - segment_baseline if settled_total >= 0 and segment_baseline >= 0 else 0
	var due := claim_ready or (settled_hands >= required_hands and segment_net >= required_net and checked_at_hand != settled_hands)
	var can_clear_marker := total >= marker_balance
	var claim := due and (marker_balance == 0 or can_clear_marker)
	var cool := tier_index == 2 and heat >= heat_ceiling - 4 and peak_heat <= heat_ceiling and not suite_rest_requested
	view["gold_progress"] = {
		"tier": TIERS[tier_index], "settled_hands": settled_hands, "segment_net": segment_net,
		"hands_remaining": maxi(0, required_hands - settled_hands), "net_remaining": maxi(0, required_net - segment_net),
		"peak_heat": peak_heat, "heat_ceiling": heat_ceiling, "marker_balance": marker_balance,
		"consecutive_losses": consecutive_losses, "last_round_delta": last_round_delta,
		"force_minimum": force_minimum, "awaiting_settlement": hand_open,
		"claim_ready": claim_ready, "blocked_reason": blocked_reason,
	}
	if accepted_gold:
		return WAIT
	var fund := chips >= 0 and (not opening_buy_in or chips < table_minimum)
	var modal := _modal(view, cash, chips, claim, cool, fund)
	if not modal.is_empty():
		return modal
	if bool(view.get("event_popup", {}).get("visible", false)) or bool(talk.get("visible", false)):
		return ""
	if not blocked_reason.is_empty():
		return WAIT
	if peak_heat > heat_ceiling and ledger_checked:
		blocked_reason = "Players Card segment peak Heat exceeded Linda's ceiling."
		return WAIT
	if bool(screen.get("travel_transition_active", false)) or bool(view.get("spatial", {}).get("loading", false)):
		return WAIT
	if screen_id == "GAME":
		if not hand_open and (claim or cool or fund) and str(game.get("phase", "")) in ["betting", "barred"]:
			var back := Opening.surface_action(view, ["surface_back", "leave_game"])
			return back if not back.is_empty() else WAIT
		return _recover_table(view, game)
	if bool(screen.get("world_map_overlay_visible", false)):
		return Opening.button(view, ["Close"])
	if screen_id != "RESULT":
		result_map_closed = false
	elif not result_map_closed:
		var map := room.room_object(view, "travel:leave", ["Open Map"], ["Open Map", "Leave: Open Map"])
		if not map.is_empty():
			return map
	if screen_id not in ["ENVIRONMENT", "RESULT"] or chips < 0 or cash < 0:
		return WAIT
	if room_id == "grand_casino_cage":
		if claim and marker_balance > 0 and cash >= marker_balance:
			return _atm(view, ["Pay in Full"])
		if fund and not claim and cash < 25 and chips < table_minimum:
			return _atm(view, ["Borrow $50"])
		if claim or cool or fund or not ledger_checked:
			# The selected ATM card can cover the counter's hit area.
			if view.get("spatial", {}).get("selected_object_id") == "casino_fixture:cage_atm":
				return "click_blank_room"
			return room.room_object(view, "casino_fixture:cage_counter", ["Talk", "Open", "Inspect"], ["Cashout Counter: Inspect"])
		return _main_floor(view)
	if room_id != "grand_casino":
		return _main_floor(view)
	if claim or cool or fund or not ledger_checked:
		return room.room_object(view, "travel:grand_casino_cage", ["Enter Room", "Travel", "Enter"], ["Grand Casino Cage: Enter Room", "Cage: Enter Room"])
	return room.room_object(view, "game:blackjack", ["Enter", "Play"], ["Blackjack: Play", "Blackjack: Enter"])


func _recover_table(view: Dictionary, game: Dictionary) -> String:
	if hand_open or game.get("game_id") != "blackjack" or game.get("phase") != "betting":
		return ""
	if not Opening.surface_action(view, ["blackjack_deal"]).is_empty():
		deal_wait_frames = 0
		return ""
	var presentation := str(game.get("blackjack_presentation", ""))
	var wait_limit := DEAL_PRESENTATION_LIMIT_FRAMES if presentation in ACTIVE_TABLE_PRESENTATIONS else DEAL_WAIT_FRAMES
	if deal_wait_frames < wait_limit:
		deal_wait_frames += DEAL_POLL_FRAMES
		return "wait %d" % DEAL_POLL_FRAMES
	var back := Opening.surface_action(view, ["surface_back", "leave_game"])
	if table_reseats >= MAX_TABLE_RESEATS or back.is_empty():
		blocked_reason = "Blackjack did not restore a visible Deal control after waiting for the table to settle."
		return WAIT
	recovery_back_command = back
	return back


func _reset_table_recovery() -> void:
	deal_wait_frames = 0
	table_reseats = 0


func recheck_after_room_recovery() -> void:
	hand_open = false
	hand_advanced = false
	ledger_checked = false
	checked_at_hand = -1
	_reset_table_recovery()


func record_input(command: String, view: Dictionary) -> void:
	if not recovery_back_command.is_empty() and command == recovery_back_command:
		table_reseats += 1
		deal_wait_frames = 0
	elif command.begins_with("click_action blackjack_deal"):
		hand_open = true
		hand_advanced = false
		betting_polls = 0
		hand_start_total = _observed_total(view)
		hand_start_message = str(view.get("game", {}).get("outcome_message", ""))
		hand_total_before_warning = -1
	elif command.begins_with("click_choice ") and str(view.get("screen", {}).get("screen", "")) == "GAME":
		if command == "click_choice change_table" and hand_open and hand_advanced:
			hand_total_before_warning = _observed_total(view)
	elif command.begins_with("click_button ") and command == Opening.button(view, ["Change Stake"]):
		hand_open = false
		force_minimum = true
	elif command.begins_with("click_button ") and bool(view.get("screen", {}).get("world_map_overlay_visible", false)):
		if command == Opening.button(view, ["Close"]):
			result_map_closed = true
	elif command == "click_choice cage_comp_suite":
		suite_rest_requested = true
	elif command == "click_choice accept_gold_card":
		accepted_gold = true
	elif (tier_index == 0 and command == "click_choice thank_linda") or (tier_index == 1 and command == "click_choice take_silver"):
		tier_index += 1
		required_hands = STANDARD_HANDS[tier_index]
		required_net = STANDARD_NET[tier_index]
		settled_hands = 0
		consecutive_losses = 0
		last_round_delta = 0
		segment_baseline = _observed_total(view)
		peak_heat = int(view.get("status_hud", {}).get("heat_level", 0))
		ledger_checked = false
		checked_at_hand = -1
		claim_ready = false


func _modal(view: Dictionary, cash: int, chips: int, claim: bool, cool: bool, fund: bool) -> String:
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	var popup_visible := bool(popup.get("visible", false))
	if not popup_visible and not bool(talk.get("visible", false)):
		return ""
	if popup_visible and str(view.get("screen", {}).get("overlay_state", {}).get("event_choice_popup_type", "")) == "wager_confirmation":
		var change := Opening.button(view, ["Change Stake"])
		return change if not change.is_empty() else WAIT
	var surface := popup if popup_visible else talk
	if not bool(surface.get("render_valid", false)) or (not popup_visible and not bool(surface.get("body_complete", false))):
		return WAIT
	var choices: Array = popup.get("choices", []) if popup_visible else view.get("clickable", {}).get("talk_choices", [])
	var id := str(surface.get("event_id", ""))
	var warning := str(WARNING_CHOICES.get(id, ""))
	if not warning.is_empty():
		return _choice(choices, [warning])
	match id:
		"dialogue:linda_bronze_tier": return _choice(choices, ["thank_linda"])
		"dialogue:linda_silver_tier": return _choice(choices, ["take_silver"])
		"dialogue:linda_gold_review": return _choice(choices, ["accept_gold_card"])
		"dialogue:linda_cage_services": return _linda(choices, cash, chips, claim, cool, fund)
		"the_house_calls":
			blocked_reason = "The House Calls interrupted the Clean route."
			return WAIT
	return _choice(choices, ["continue", "play_dumb", "ignore", "leave_it", "walk_away", "decline", "close", "leave_counter"], "")


func _linda(choices: Array, cash: int, chips: int, claim: bool, cool: bool, fund: bool) -> String:
	var ready := _choice(choices, ["cage_claim_card"], "")
	if not ready.is_empty():
		claim_ready = true
		return ready
	if _has_choice(choices, "cage_claim_card"):
		ledger_checked = true
		checked_at_hand = settled_hands
		return _choice(choices, ["back_main"])
	if _has_choice(choices, "cage_buy_25"):
		if claim and marker_balance > cash and chips > 0:
			return _choice(choices, ["cage_cashout_all"])
		if fund and not claim:
			return _choice(choices, ["cage_buy_50", "cage_buy_25", "back_main"])
		return _choice(choices, ["back_main"])
	if _has_choice(choices, "cage_comp_suite"):
		var rest := _choice(choices, ["cage_comp_suite"], "") if cool else ""
		if rest.is_empty():
			suite_rest_requested = true
			return _choice(choices, ["back_main"])
		return rest
	if claim and marker_balance > 0:
		return _choice(choices, ["open_chips", "leave_counter"] if marker_balance > cash else ["leave_counter"])
	if fund and cash >= 25 and not claim:
		return _choice(choices, ["open_chips", "leave_counter"])
	if claim or not ledger_checked:
		return _choice(choices, ["open_card", "leave_counter"])
	if cool:
		return _choice(choices, ["open_comps", "leave_counter"])
	return _choice(choices, ["leave_counter"])


func _read_progress(text: String, total: int) -> void:
	var marker := marker_pattern.search(text)
	if marker != null:
		marker_balance = int(marker.get_string(1))
	var marker_claim := marker_claim_pattern.search(text)
	if marker_claim != null:
		marker_balance = int(marker_claim.get_string(1))
		claim_ready = true
	if text.contains("Cheat evidence permanently closes"):
		blocked_reason = "Cheat evidence closed Linda's Players Card program."
	elif text.contains("Rourke's showdown has priority"):
		blocked_reason = "Rourke's showdown took priority over Linda's Players Card."
	if text.contains("ready. Claim it from Linda") or text.contains(" ready. Settle the $"):
		claim_ready = true
	var progress := progress_pattern.search(text)
	if progress == null or progress.get_string(1).to_lower() != TIERS[tier_index]:
		return
	var visible_hands := int(progress.get_string(2))
	# A queued label can lag the current hand; keep the newer settled count.
	if visible_hands >= settled_hands:
		settled_hands = visible_hands
		if total >= 0:
			segment_baseline = total - int(progress.get_string(4))
	required_hands = int(progress.get_string(3))
	required_net = int(progress.get_string(5))
	peak_heat = maxi(peak_heat, int(progress.get_string(6)))
	heat_ceiling = int(progress.get_string(7))


func _update_hand(game: Dictionary, total: int) -> void:
	if not hand_open or str(game.get("game_id", "")) != "blackjack":
		return
	var phase := str(game.get("phase", ""))
	if phase == "barred":
		hand_open = false
		return
	if phase in ["dealing", "decision", "settling"]:
		if not hand_advanced:
			_reset_table_recovery()
		hand_advanced = true
		return
	if phase != "betting" or total < 0:
		return
	var message := str(game.get("outcome_message", ""))
	if not hand_advanced and (message == hand_start_message or not bool(game.get("has_recent_outcome", false))):
		betting_polls += 1
		if betting_polls >= 3:
			hand_open = false
		return
	settled_hands += 1
	var result_total := hand_total_before_warning if hand_total_before_warning >= 0 else total
	last_round_delta = result_total - hand_start_total if hand_start_total >= 0 else 0
	consecutive_losses = consecutive_losses + 1 if last_round_delta < 0 else 0
	force_minimum = false
	hand_open = false
	_reset_table_recovery()


func _atm(view: Dictionary, labels: Array) -> String:
	var subject := "casino_fixture:cage_atm"
	for row in view.get("clickable", {}).get("room_actions", []):
		if row.get("selected_object_id") == subject and row.get("label") in labels and not bool(row.get("enabled", false)):
			blocked_reason = str(row.get("disabled_reason", "The Cage ATM action is unavailable."))
			return WAIT
	return room.room_object(view, subject, labels, ["Casino ATM: " + str(labels[0])])


func _main_floor(view: Dictionary) -> String:
	return room.room_object(view, "travel:grand_casino", ["Enter Room", "Travel", "Enter"], ["Grand Casino Main Floor: Enter Room", "Main Floor: Enter Room"])


static func _has_choice(choices: Array, id: String) -> bool:
	for row in choices:
		if row.get("id") == id:
			return true
	return false


static func _choice(choices: Array, ids: Array, fallback: String = WAIT) -> String:
	for id in ids:
		for row in choices:
			if row.get("id") == id and bool(row.get("enabled", false)):
				return "click_choice " + str(id)
	return fallback


static func _hud_value(hud: Dictionary, key: String) -> int:
	return int(hud.get(key, 0)) if bool(hud.get(key + "_rendered", false)) else -1


func _observed_total(view: Dictionary) -> int:
	var hud: Dictionary = view.get("status_hud", {})
	var cash := _hud_value(hud, "bankroll")
	var chips := _hud_value(hud, "chips")
	if cash < 0 and view.get("screen", {}).get("screen") == "GAME":
		cash = last_visible_cash
	return cash + chips if cash >= 0 and chips >= 0 else -1
