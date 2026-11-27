extends RefCounted

const WAIT := "wait 12"
const CLEAN_RESPONSES := {
	"eye_in_the_sky": "change_table",
	"blackjack_counter_probe": "play_dumb",
	"shift_change": "ignore",
	"floor_staff_heat_warning": "play_cool",
	"pit_boss_heat_warning": "walk_now",
	"rival_counter": "drop_word",
	"counter_payoff": "wave_off",
	"staff_shift_tip": "save_cash",
	"on_the_house": "refuse",
	"lights_out": "freeze",
	"lights_out_return": "stand_still",
	"whale_sighting": "fade",
	"lay_low_booth": "sit_out",
	"door_bribe": "pay",
	"lucky_streak_temptation": "pocket",
	"machine_jam": "wait",
}


static func decide(view: Dictionary, policy: String) -> String:
	var environment: Dictionary = view.get("environment", {})
	var at_grand := str(environment.get("archetype_id", "")).begins_with("grand_casino")
	var clickable: Dictionary = view.get("clickable", {})
	var screen: Dictionary = view.get("screen", {})
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	if bool(popup.get("visible", false)):
		if str(screen.get("overlay_state", {}).get("event_choice_popup_type", "")) == "wager_confirmation":
			for button: Dictionary in clickable.get("buttons", []):
				if button.get("text") == "Change Stake" and bool(button.get("enabled", false)) \
						and bool(button.get("fully_visible", false)):
					return "click_button Change Stake"
			return WAIT
		return _response(popup, popup.get("choices", []))
	if bool(talk.get("visible", false)):
		return _response(talk, clickable.get("talk_choices", []))
	var game: Dictionary = view.get("game", {})
	if not at_grand or screen.get("screen") != "GAME" or game.get("game_id") != "blackjack" \
			or bool(game.get("boss_duel_active", false)):
		return ""
	var actions: Array = clickable.get("game_surface_actions", [])
	var retry := _action(actions, "blackjack_retry_pending")
	if not retry.is_empty():
		return retry
	var phase := str(game.get("phase", ""))
	if phase == "barred":
		return _back(actions)
	var progress: Dictionary = view.get("gold_progress", {})
	var hud: Dictionary = view.get("status_hud", {})
	if phase == "betting":
		if bool(progress.get("awaiting_settlement", false)):
			return WAIT
		if bool(progress.get("leave_after_settlement", false)) and bool(view.get("ordinary_round_in_progress", false)):
			return _back(actions)
		return _wager(game, hud, progress, actions, policy)
	if bool(game.get("settle_available", false)) or phase == "settling":
		var settle := _action(actions, "blackjack_settle")
		return settle if not settle.is_empty() else WAIT
	if phase != "decision":
		return WAIT
	return _hand_action(game, hud, progress, actions, policy)


static func _response(surface: Dictionary, choices: Array) -> String:
	var preferred := str(CLEAN_RESPONSES.get(surface.get("event_id", ""), ""))
	if preferred.is_empty():
		return ""
	if not bool(surface.get("render_valid", false)):
		return WAIT
	if surface.has("body_complete") and not bool(surface["body_complete"]):
		return WAIT
	for choice: Dictionary in choices:
		if choice.get("id") == preferred and bool(choice.get("enabled", false)):
			return "click_choice " + preferred
	return ""


static func _wager(game: Dictionary, hud: Dictionary, progress: Dictionary, actions: Array, policy: String) -> String:
	var minimum := int(game.get("stake_min", 0))
	var maximum := int(game.get("stake_max", 0))
	var selected := int(game.get("selected_stake", 0))
	if minimum <= 0 or selected <= 0 or not bool(hud.get("chips_rendered", false)):
		return WAIT
	var chips := int(hud.get("chips", 0))
	var liquidity := _total_liquidity(hud)
	var safe_maximum := mini(maximum, mini(chips, liquidity - 1))
	if safe_maximum < minimum:
		return _back(actions)
	var target := _wager_target(minimum, safe_maximum, liquidity, progress, policy)
	if selected != target:
		var edit := _wager_edit(game, actions, selected, target, minimum)
		return edit if not edit.is_empty() else WAIT
	var deal := _action(actions, "blackjack_deal")
	if bool(game.get("can_deal", false)) and not deal.is_empty():
		return deal
	return WAIT


static func _wager_target(minimum: int, maximum: int, liquidity: int, progress: Dictionary, policy: String) -> int:
	if bool(progress.get("force_minimum", false)):
		return minimum
	var net_remaining := int(progress.get("net_remaining", 0))
	# Protect earned profit while finishing the hand requirement. A minimum win
	# also closes a one-hand gap whenever it already covers the remaining dollars.
	if progress.has("net_remaining") and (net_remaining == 0 \
			or (net_remaining <= minimum and int(progress.get("hands_remaining", 1)) <= 1)):
		return minimum
	if policy == "risk_aware":
		# Spread exposure over the remaining qualifying hands while retaining a
		# recovery bankroll. Once the hand count is met, size to the visible gap.
		var hands_remaining := maxi(1, int(progress.get("hands_remaining", 1)))
		var needed_per_hand := ceili(float(net_remaining) / float(hands_remaining))
		var liquidity_cap := maxi(minimum, floori(float(liquidity) / 4.0))
		return clampi(needed_per_hand, minimum, mini(maximum, liquidity_cap))
	if (progress.get("tier") == "silver" and int(progress.get("settled_hands", 0)) == 0) \
			or int(progress.get("consecutive_losses", 0)) >= 2:
		return maximum
	if int(progress.get("last_round_delta", 0)) > 0 and int(progress.get("segment_net", 0)) > 0 \
			and net_remaining > 0 and net_remaining <= 12:
		return mini(maximum, minimum + 10)
	return minimum


static func _wager_edit(game: Dictionary, actions: Array, selected: int, target: int, minimum: int) -> String:
	if target == minimum:
		return _action(actions, "blackjack_clear_bet")
	var denominations: Array = game.get("chip_denominations", [1])
	if selected < target:
		var max_bet := _action(actions, "blackjack_max_bet")
		var maximum := int(game.get("stake_max", 0))
		if target == maximum and not max_bet.is_empty():
			return max_bet
		if game.get("blackjack_presentation") == "wagering" and not bool(game.get("wager_rail_tap_disabled", false)):
			var add := _chip_edit_plan(actions, denominations, target - selected, "blackjack_wager_place_gesture")
			if not add.is_empty():
				var trim := _chip_edit_plan(actions, denominations, maximum - target, "blackjack_remove_chip")
				if max_bet.is_empty() or trim.is_empty() or int(add["clicks"]) <= 1 + int(trim["clicks"]):
					return str(add["command"])
		return max_bet
	return str(_chip_edit_plan(actions, denominations, selected - target, "blackjack_remove_chip").get("command", ""))


static func _chip_edit_plan(actions: Array, denominations: Array, difference: int, action: String) -> Dictionary:
	var available := {}
	for index in range(denominations.size()):
		var denomination := int(denominations[index])
		if denomination <= 0 or denomination > difference:
			continue
		var command := _action(actions, action, index)
		if not command.is_empty():
			available[denomination] = command
	var sizes := available.keys()
	sizes.sort()
	sizes.reverse()
	var first_command := ""
	var clicks := 0
	for size: int in sizes:
		var uses := floori(float(difference) / float(size))
		if uses == 0:
			continue
		if first_command.is_empty():
			first_command = str(available[size])
		clicks += uses
		difference -= uses * size
	if difference == 0 and clicks > 0:
		return {"command": first_command, "clicks": clicks}
	return {}


static func _hand_action(game: Dictionary, hud: Dictionary, progress: Dictionary, actions: Array, policy: String) -> String:
	var hit := _action(actions, "blackjack_hit") if bool(game.get("can_hit", false)) else ""
	var stand := _action(actions, "blackjack_stand") if bool(game.get("can_stand", false)) else ""
	if hit.is_empty():
		return stand if not stand.is_empty() else WAIT
	if stand.is_empty():
		return hit
	var total := int(game.get("blackjack_total", 0))
	if total <= 0:
		return WAIT
	var up_card: Dictionary = game.get("dealer_up_card", {})
	var dealer := _rank_value(int(up_card.get("rank", 0)))
	if dealer == 0 or policy == "baseline":
		return hit if total < 17 else stand
	var soft := bool(game.get("blackjack_soft", false))
	var current_stake := int(game.get("selected_stake", 0))
	var reserve := maxi(1, int(game.get("stake_min", 1)))
	var liquidity := _total_liquidity(hud)
	var can_raise := current_stake > 0 and liquidity - current_stake >= reserve
	if policy == "risk_aware":
		# The original stake is already on the felt at this point. Preserve a
		# second live wager when extra exposure would not help the visible target.
		var remaining := int(progress.get("net_remaining", 0))
		var hands_remaining := int(progress.get("hands_remaining", 1))
		can_raise = can_raise and (liquidity >= current_stake + reserve * 2 \
			or (hands_remaining <= 1 and remaining > current_stake))
	var double := _action(actions, "blackjack_double") if can_raise and bool(game.get("can_double", false)) else ""
	var split := _action(actions, "blackjack_split") if can_raise and bool(game.get("can_split", false)) else ""
	var surrender := _action(actions, "blackjack_surrender") if bool(game.get("can_surrender", false)) else ""
	if not soft and not surrender.is_empty() and ((total == 16 and dealer >= 9) or (total == 15 and dealer == 10)):
		return surrender
	var pair := _pair_value(game)
	var rules := str(game.get("table_rules_text", "")).to_lower()
	var double_after_split := "das" in rules and not ("nodas" in rules or "no das" in rules)
	if not split.is_empty() and _should_split(pair, dealer, double_after_split):
		return split
	if soft:
		if total >= 19 or (total == 18 and dealer in [2, 7, 8]):
			return stand
		var double_minimum := 3 if total >= 17 else 4 if total >= 15 else 5
		if not double.is_empty() and total >= 13 and dealer >= double_minimum and dealer <= 6:
			return double
		return stand if total == 18 and dealer <= 6 else hit
	if total >= 17 or (total >= 13 and dealer >= 2 and dealer <= 6) or (total == 12 and dealer >= 4 and dealer <= 6):
		return stand
	if not double.is_empty() and (total == 11 or (total == 10 and dealer <= 9) \
			or (total == 9 and dealer >= 3 and dealer <= 6)):
		return double
	return hit


static func _pair_value(game: Dictionary) -> int:
	var hands: Array = game.get("player_hands", [])
	var hand_index := int(game.get("active_hand_index", 0))
	if hand_index < 0 or hand_index >= hands.size():
		return 0
	var cards: Array = hands[hand_index].get("cards", [])
	if cards.size() != 2 or cards[0].get("rank") != cards[1].get("rank"):
		return 0
	return _rank_value(int(cards[0].get("rank", 0)))


static func _should_split(pair: int, dealer: int, double_after_split: bool) -> bool:
	match pair:
		11, 8:
			return true
		9:
			return dealer in [2, 3, 4, 5, 6, 8, 9]
		7, 3, 2:
			return dealer >= 2 and dealer <= 7
		6:
			return dealer >= 2 and dealer <= 6
		4:
			return double_after_split and dealer in [5, 6]
	return false


static func _rank_value(rank: int) -> int:
	return 11 if rank == 14 else mini(rank, 10)


static func _total_liquidity(hud: Dictionary) -> int:
	var cash := int(hud.get("bankroll", 0)) if bool(hud.get("bankroll_rendered", false)) else 0
	var chips := int(hud.get("chips", 0)) if bool(hud.get("chips_rendered", false)) else 0
	return cash + chips


static func _back(actions: Array) -> String:
	var command := _action(actions, "surface_back")
	if command.is_empty():
		command = _action(actions, "leave_game")
	return command if not command.is_empty() else WAIT


static func _action(actions: Array, id: String, requested_index: int = -2) -> String:
	for action: Dictionary in actions:
		if action.get("action") != id or not bool(action.get("enabled", false)):
			continue
		var index := int(action.get("index", 0))
		if requested_index == -2 or index == requested_index:
			return "click_action %s %d" % [id, index]
	return ""
