extends RefCounted

const OpeningPolicy := preload("res://tools/rourke_solver/rourke_opening_policy.gd")
const GoldBlackjack := preload("res://tools/gold_card_solver/gold_blackjack_policy.gd")

const WAIT := "wait 16"
const PROFIT_GOAL := 40
const PROFIT_HAND_LIMIT := 12
const COOL_HEAT_TARGET := 60
const COOL_EXCHANGE_LIMIT := 64
const HIGH_LIMIT_RESERVE := 40

var route_id := "balanced"
var rooms := OpeningPolicy.new()
var profit_entry_liquidity := -1
var profit_hands := 0
var pressure_started := false
var cooling := false
var cooling_done := false
var cooling_exchanges := 0
var declined_suite := false
var left_high_limit := false
var high_limit_minimum := 0
var high_limit_entry_pending := false
var high_limit_entry_polls := 0
var cooling_result_normalized := false


func configure(_target: String, selected_route: String) -> void:
	route_id = selected_route


func decide_gold(view: Dictionary, fallback_command: String) -> String:
	if route_id == "high_limit":
		var high_limit := _gold_high_limit(view)
		if not high_limit.is_empty():
			return high_limit
	if not fallback_command.is_empty() or _blocked_surface(view):
		return fallback_command
	var game: Dictionary = view.get("game", {})
	if not _is_ordinary_blackjack(game):
		return fallback_command
	if route_id == "minimum_stakes":
		var conservative := view.duplicate()
		var progress: Dictionary = view.get("gold_progress", {}).duplicate()
		var conservative_game := game.duplicate()
		progress["force_minimum"] = true
		conservative_game["can_double"] = false
		conservative_game["can_split"] = false
		conservative["gold_progress"] = progress
		conservative["game"] = conservative_game
		return GoldBlackjack.decide(conservative, "balanced")
	if route_id == "target_stakes" and str(game.get("phase", "")) == "betting":
		var progress: Dictionary = view.get("gold_progress", {})
		if bool(progress.get("awaiting_settlement", false)) or bool(progress.get("force_minimum", false)):
			return fallback_command
		var liquidity := _liquidity(view)
		var minimum := int(game.get("stake_min", 0))
		var desired := maxi(minimum, int(progress.get("net_remaining", minimum)))
		var exposure_limit := maxi(minimum, floori(float(liquidity) / 3.0))
		return _stage_wager(view, mini(desired, exposure_limit))
	return fallback_command


func decide_rourke(view: Dictionary) -> String:
	if not _location(view).begins_with("grand_casino"):
		return ""
	match route_id:
		"direct_peek":
			return _direct_peek(view)
		"profit_trigger":
			return _profit_route(view)
		"cool_before_duel":
			return _cool_route(view)
	return ""


func record_input(command: String, view: Dictionary) -> void:
	var game: Dictionary = view.get("game", {})
	if route_id == "profit_trigger" and not pressure_started and _is_ordinary_blackjack(game) \
			and command.begins_with("click_action blackjack_deal"):
		profit_hands += 1
	if route_id == "cool_before_duel" and cooling:
		if command in ["click_choice cage_buy_25", "click_choice cage_buy_50", "click_choice cage_cashout_all"]:
			cooling_exchanges += 1
		if command == "click_choice decline" and _modal_event(view) == "comped_suite_offer":
			declined_suite = true


func _gold_high_limit(view: Dictionary) -> String:
	var progress: Dictionary = view.get("gold_progress", {})
	if progress.get("tier") != "gold":
		return ""
	var location := _location(view)
	var game: Dictionary = view.get("game", {})
	var screen: Dictionary = view.get("screen", {})
	var screen_id := str(screen.get("screen", ""))
	var chips := _hud_value(view, "chips")
	if location == "grand_casino_high_limit" and _is_ordinary_blackjack(game):
		high_limit_minimum = maxi(high_limit_minimum, int(game.get("stake_min", 0)))
		if screen_id == "GAME" and str(game.get("phase", "")) == "betting" and chips >= 0 and chips < high_limit_minimum:
			left_high_limit = true
			return OpeningPolicy.surface_action(view, ["surface_back", "leave_game"])
	if location == "grand_casino_high_limit":
		high_limit_entry_pending = false
		if not _blocked_surface(view) and screen_id == "ENVIRONMENT" and not _gold_ready(progress) \
				and not left_high_limit and chips >= maxi(1, high_limit_minimum):
			return rooms.room_object(view, "game:blackjack", ["Enter", "Play"], ["Blackjack: Enter", "Blackjack: Play"])
		return ""
	if location != "grand_casino" or _blocked_surface(view) or left_high_limit or _gold_ready(progress):
		return ""
	if screen_id != "ENVIRONMENT" or chips < HIGH_LIMIT_RESERVE:
		return ""
	# Silver makes the genuine High Limit room accessible. A failed transition
	# leaves the normal Main Floor route available for the rest of this run.
	if high_limit_entry_pending:
		high_limit_entry_polls += 1
		if high_limit_entry_polls >= 8:
			left_high_limit = true
			return ""
	var route := rooms.room_object(view, "travel:grand_casino_high_limit", ["Enter Room"], ["Grand Casino High-Limit Room: Enter Room", "High-Limit Room: Enter Room"])
	if route.begins_with("click_action room ") or (not route.is_empty() and route == OpeningPolicy.button(
			view, ["Grand Casino High-Limit Room: Enter Room", "High-Limit Room: Enter Room"])):
		high_limit_entry_pending = true
	return route


func _direct_peek(view: Dictionary) -> String:
	var game: Dictionary = view.get("game", {})
	if not _is_ordinary_blackjack(game) or str(game.get("phase", "")) != "decision" \
			or not bool(game.get("peek_available", false)) or bool(game.get("dealer_hole_visible", false)) \
			or bool(game.get("settle_available", false)) or _blocked_surface(view):
		return ""
	# Use the same legal Peek input without staging a distraction first.
	return OpeningPolicy.surface_action(view, ["blackjack_peek"])


func _profit_route(view: Dictionary) -> String:
	if pressure_started:
		return ""
	var gross := _liquidity(view)
	var net := gross - _marker_balance(view)
	if gross > 0 and profit_entry_liquidity < 0:
		profit_entry_liquidity = net
	var game: Dictionary = view.get("game", {})
	if _blocked_surface(view):
		return GoldBlackjack.decide(view, "balanced")
	if not _is_ordinary_blackjack(game):
		return ""
	if str(game.get("phase", "")) == "betting":
		if bool(view.get("ordinary_round_in_progress", false)):
			return ""
		var minimum := int(game.get("stake_min", 0))
		var earned := net - profit_entry_liquidity
		if gross >= 0 and (earned >= PROFIT_GOAL or profit_hands >= PROFIT_HAND_LIMIT or gross < 35):
			pressure_started = true
			return ""
		# Try to earn the published dirty-money gate before making the first
		# watched move. Keep enough liquid funds for a pressure-route fallback.
		var desired := maxi(minimum, ceili(float(PROFIT_GOAL - earned) / 2.0))
		return _stage_wager(view, mini(desired, maxi(minimum, floori(float(gross) / 6.0))))
	return GoldBlackjack.decide(view, "balanced")


func _cool_route(view: Dictionary) -> String:
	if cooling_done and not cooling:
		return ""
	var heat := _hud_value(view, "heat_level", "heat_rendered")
	var event_id := _modal_event(view)
	if event_id == "eye_in_the_sky":
		return _choice(view, ["change_table"])
	if event_id == "floor_staff_heat_warning" and heat >= 85:
		return _choice(view, ["play_cool"])
	if event_id == "comped_suite_offer" and cooling:
		return _choice(view, ["decline"])
	var location := _location(view)
	var screen: Dictionary = view.get("screen", {})
	var screen_id := str(screen.get("screen", ""))
	if not cooling:
		if location != "grand_casino" or screen_id not in ["ENVIRONMENT", "RESULT"] \
				or heat <= COOL_HEAT_TARGET or not _house_calls_visible(view):
			return ""
		cooling = true
	var liquidity := _liquidity(view)
	var cash_short := liquidity >= 0 and liquidity - _marker_balance(view) < 25
	if heat >= 0 and (heat <= COOL_HEAT_TARGET or cooling_exchanges >= COOL_EXCHANGE_LIMIT or cash_short):
		cooling_done = true
	if event_id == "dialogue:linda_cage_services":
		return _cage_cooling_choice(view)
	if _blocked_surface(view):
		return ""
	if bool(screen.get("world_map_overlay_visible", false)):
		cooling_result_normalized = true
		return OpeningPolicy.button(view, ["Close"])
	if screen_id not in ["ENVIRONMENT", "RESULT"]:
		return ""
	if screen_id == "ENVIRONMENT":
		cooling_result_normalized = false
	elif not cooling_result_normalized:
		var map := rooms.room_object(view, "travel:leave", ["Open Map"], ["Open Map", "Leave: Open Map"])
		if not map.is_empty():
			return map
	if location == "grand_casino_cage":
		if cooling_done:
			return rooms.room_object(view, "travel:grand_casino", ["Enter Room"], ["Grand Casino Main Floor: Enter Room", "Main Floor: Enter Room"])
		return rooms.room_object(view, "casino_fixture:cage_counter", ["Talk", "Open", "Inspect"], ["Cashout Counter: Inspect"])
	if location != "grand_casino":
		return ""
	if cooling_done:
		cooling = false
		return ""
	if not declined_suite and not _canvas_object(view, "event:comped_suite_offer").is_empty():
		var suite := rooms.room_object(view, "event:comped_suite_offer", ["Decline", "Open", "Review Responses"])
		if not suite.is_empty():
			return suite
	return rooms.room_object(view, "travel:grand_casino_cage", ["Enter Room"], ["Grand Casino Cage: Enter Room", "Cage: Enter Room"])


func _cage_cooling_choice(view: Dictionary) -> String:
	if cooling_done:
		return _choice(view, ["leave_counter", "back_main"])
	var chips := _hud_value(view, "chips")
	var exchange := _choice(view, ["cage_cashout_all"] if chips > 0 else ["cage_buy_25", "cage_buy_50"])
	if not exchange.is_empty():
		return exchange
	return _choice(view, ["open_chips", "back_main"])


static func _stage_wager(view: Dictionary, requested: int) -> String:
	var game: Dictionary = view.get("game", {})
	var actions: Array = view.get("clickable", {}).get("game_surface_actions", [])
	var minimum := int(game.get("stake_min", 0))
	var maximum := mini(int(game.get("stake_max", 0)), mini(_hud_value(view, "chips"), _liquidity(view) - 1))
	var selected := int(game.get("selected_stake", 0))
	if minimum <= 0 or maximum < minimum or selected <= 0:
		return ""
	var desired := clampi(requested, minimum, maximum)
	if selected == desired:
		var deal := OpeningPolicy.surface_action(view, ["blackjack_deal"])
		return deal if not deal.is_empty() else WAIT
	var edit := GoldBlackjack._wager_edit(game, actions, selected, desired, minimum)
	return edit if not edit.is_empty() else WAIT


static func _is_ordinary_blackjack(game: Dictionary) -> bool:
	return game.get("game_id") == "blackjack" and not bool(game.get("boss_duel_active", false))


static func _gold_ready(progress: Dictionary) -> bool:
	return bool(progress.get("claim_ready", false)) or (int(progress.get("hands_remaining", 1)) <= 0 \
		and int(progress.get("net_remaining", 1)) <= 0)


static func _blocked_surface(view: Dictionary) -> bool:
	var screen: Dictionary = view.get("screen", {})
	return bool(view.get("event_popup", {}).get("visible", false)) or bool(view.get("talk", {}).get("visible", false)) \
		or bool(screen.get("travel_transition_active", false)) or bool(view.get("spatial", {}).get("loading", false))


static func _modal_event(view: Dictionary) -> String:
	var popup: Dictionary = view.get("event_popup", {})
	if bool(popup.get("visible", false)):
		return str(popup.get("event_id", ""))
	var talk: Dictionary = view.get("talk", {})
	return str(talk.get("event_id", "")) if bool(talk.get("visible", false)) else ""


static func _choice(view: Dictionary, choices: Array) -> String:
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	var is_popup := bool(popup.get("visible", false))
	var surface := popup if is_popup else talk
	if not bool(surface.get("render_valid", false)) or (not is_popup and not bool(surface.get("body_complete", false))):
		return WAIT
	var available: Array = popup.get("choices", []) if is_popup else view.get("clickable", {}).get("talk_choices", [])
	for id: String in choices:
		for choice: Dictionary in available:
			if choice.get("id") == id and bool(choice.get("enabled", false)):
				return "click_choice " + id
	return ""


static func _house_calls_visible(view: Dictionary) -> bool:
	return not _canvas_object(view, "event:the_house_calls").is_empty() \
		or not OpeningPolicy.button(view, ["The House Calls: Follow Rourke"]).is_empty()


static func _canvas_object(view: Dictionary, id: String) -> Dictionary:
	for object: Dictionary in view.get("clickable", {}).get("canvas_objects", []):
		if object.get("semantic_id") == id and bool(object.get("rendered", false)) and bool(object.get("enabled", false)):
			return object
	return {}


static func _hud_value(view: Dictionary, field: String, witness: String = "") -> int:
	var hud: Dictionary = view.get("status_hud", {})
	var visible_key := witness if not witness.is_empty() else field + "_rendered"
	return int(hud.get(field, -1)) if bool(hud.get(visible_key, false)) else -1


static func _liquidity(view: Dictionary) -> int:
	var cash := _hud_value(view, "bankroll")
	var chips := _hud_value(view, "chips")
	return cash + chips if cash >= 0 and chips >= 0 else -1


static func _marker_balance(view: Dictionary) -> int:
	var indicator: Dictionary = view.get("status_hud", {}).get("debt_indicator", {})
	if not bool(indicator.get("rendered", false)):
		return 0
	var text := str(indicator.get("tooltip", ""))
	var prefix := "Casino marker $"
	var begin := text.find(prefix)
	if begin < 0:
		return 0
	begin += prefix.length()
	var end := begin
	while end < text.length() and text[end].is_valid_int():
		end += 1
	return text.substr(begin, end - begin).to_int()


static func _location(view: Dictionary) -> String:
	return str(view.get("environment", {}).get("archetype_id", ""))
