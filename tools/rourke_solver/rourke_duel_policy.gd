extends RefCounted

# Each alternative evaluates the same player-facing hand and control signals.
const WAIT := "wait 12"
const CLASSIFIED_ITEMS := [
	"marked_cards", "foil_sleeve", "weighted_keyring", "xray_glasses", "tab_detector", "tarot_card",
]
const WARNING_CHOICES := {
	"eye_in_the_sky": "press_anyway",
	"blackjack_counter_probe": "play_dumb",
	"floor_staff_heat_warning": "talk_back",
	"pit_boss_heat_warning": "walk_now",
}
# Incidental encounters can interrupt travel as well as play at the Grand.
const INCIDENTAL_CHOICES := {
	"shift_change": "ignore",
	"rival_counter": "play_through",
	"counter_payoff": "take_signal",
	"staff_shift_tip": "save_cash",
	"on_the_house": "refuse",
	"lights_out": "freeze",
	"lights_out_return": "stand_still",
	"whale_sighting": "fade",
	"lay_low_booth": "keep_moving",
	"door_bribe": "walk_past",
	"lucky_streak_temptation": "pocket",
	"machine_jam": "wait",
}
const VICTORY_MARGIN := -60


static func decide(observation: Dictionary, policy: String = "balanced") -> String:
	var public: Dictionary = observation.get("observable", observation)
	var clickable: Dictionary = observation.get("clickable", public.get("clickable", {}))
	var screen: Dictionary = public.get("screen", {})
	var game: Dictionary = public.get("game", {})
	var environment: Dictionary = public.get("environment", {})
	var duel := bool(game.get("boss_duel_active", false))
	var grand := str(environment.get("archetype_id", "")).begins_with("grand_casino")
	var blackjack := str(screen.get("screen", "")) == "GAME" and str(game.get("game_id", "")) == "blackjack"
	var popup: Dictionary = public.get("event_popup", {})
	var talk: Dictionary = public.get("talk", {})
	if bool(popup.get("visible", false)):
		var overlay: Dictionary = screen.get("overlay_state", {})
		if grand and str(overlay.get("event_choice_popup_type", "")) == "wager_confirmation":
			return _confirm_wager(clickable)
		return _visible_choice(popup, popup.get("choices", []), grand or blackjack)
	if bool(talk.get("visible", false)) and bool(talk.get("expanded", false)):
		return _visible_choice(talk, clickable.get("talk_choices", []), grand or blackjack)
	if not blackjack or not (grand or duel):
		return ""
	var actions: Array = clickable.get("game_surface_actions", [])
	var priority := _first_action(actions, ["ending.ack", "showdown_exit", "blackjack_retry_pending"])
	if not priority.is_empty():
		return priority
	var phase := str(game.get("phase", ""))
	if phase == "barred":
		return _back(actions)
	if phase == "betting":
		if not duel:
			var launched := bool(observation.get("ordinary_round_in_progress", public.get("ordinary_round_in_progress", false)))
			var minimum := int(game.get("stake_min", 0))
			var hud: Dictionary = public.get("status_hud", {})
			var short := bool(hud.get("chips_rendered", false)) and int(hud.get("chips", 0)) < minimum
			if launched or short:
				return _back(actions)
			if int(game.get("selected_stake", minimum)) > minimum:
				var clear := _action(actions, "blackjack_clear_bet")
				return clear if not clear.is_empty() else WAIT
		var deal := _action(actions, "blackjack_deal")
		return deal if bool(game.get("can_deal", false)) and not deal.is_empty() else WAIT
	if duel:
		var call := _rourke_call(game, actions)
		if not call.is_empty():
			return call
	if bool(game.get("settle_available", false)) or phase == "settling":
		var settle := _action(actions, "blackjack_settle")
		return settle if bool(game.get("settle_available", false)) and not settle.is_empty() else WAIT
	if phase != "decision":
		return WAIT
	if not duel and bool(game.get("peek_available", false)) and not bool(game.get("dealer_hole_visible", false)):
		var peek := _action(actions, "blackjack_peek")
		if bool(game.get("peek_window_open", false)) and not peek.is_empty():
			return peek
		var distraction := _action(actions, "blackjack_distraction")
		if not distraction.is_empty():
			return distraction
	var hit := _action(actions, "blackjack_hit") if bool(game.get("can_hit", false)) else ""
	var stand := _action(actions, "blackjack_stand") if bool(game.get("can_stand", false)) else ""
	var double := ""
	if duel and policy == "risk_aware" and bool(game.get("can_double", false)):
		double = _action(actions, "blackjack_double")
	if hit.is_empty():
		return stand if not stand.is_empty() else WAIT
	if stand.is_empty():
		return hit
	return _choose_hand(game, policy, hit, stand, double)


static func _visible_choice(surface: Dictionary, choices: Array, route_context: bool) -> String:
	if not bool(surface.get("render_valid", false)):
		return WAIT if route_context else ""
	if surface.has("body_complete") and not bool(surface["body_complete"]):
		return WAIT if route_context else ""
	var event_id := str(surface.get("event_id", ""))
	var incidental := str(INCIDENTAL_CHOICES.get(event_id, ""))
	if not incidental.is_empty() and _enabled_choice(choices, incidental):
		return "click_choice " + incidental
	if event_id == "the_house_calls":
		for choice in ["enter_back_room", "face_rourke", "take_the_edge"]:
			if _enabled_choice(choices, choice):
				return "click_choice %s" % choice
		if _enabled_choice(choices, "keep_everything"):
			for item_id in CLASSIFIED_ITEMS:
				for prefix in ["hand_to_crew__", "trash_item__"]:
					var choice: String = prefix + item_id
					if _enabled_choice(choices, choice):
						return "click_choice %s" % choice
			return "click_choice keep_everything"
	var warning := str(WARNING_CHOICES.get(event_id, ""))
	if route_context and not warning.is_empty() and _enabled_choice(choices, warning):
		return "click_choice %s" % warning
	return ""


static func _enabled_choice(choices: Array, expected_id: String) -> bool:
	for choice: Dictionary in choices:
		if choice.get("id") == expected_id and bool(choice.get("enabled", false)):
			return true
	return false


static func _confirm_wager(clickable: Dictionary) -> String:
	for button: Dictionary in clickable.get("buttons", []):
		if button.get("text") == "Confirm Bet" and bool(button.get("enabled", false)) \
				and bool(button.get("fully_visible", true)):
			return "click_button Confirm Bet"
	return WAIT


static func _rourke_call(game: Dictionary, actions: Array) -> String:
	if bool(game.get("boss_callout_used", false)) or bool(game.get("can_deal", false)):
		return ""
	var tell := str(game.get("boss_tell", ""))
	var wanted := ""
	if tell.begins_with("Rourke squares one slug twice"):
		wanted = "deck_stack"
	elif tell.begins_with("His thumb stays under the down card"):
		wanted = "hole_swap"
	if wanted.is_empty():
		return ""
	var callouts: Array = game.get("boss_callouts", [])
	for callout: Dictionary in callouts:
		var index := int(callout.get("index", -1))
		if callout.get("id") == wanted and index >= 0:
			var call := _action(actions, "blackjack_boss_callout", index)
			return call if not call.is_empty() else WAIT
	return WAIT


static func _back(actions: Array) -> String:
	var back := _first_action(actions, ["surface_back", "leave_game"])
	return back if not back.is_empty() else WAIT


static func _first_action(actions: Array, names: Array) -> String:
	for name: String in names:
		var command := _action(actions, name)
		if not command.is_empty():
			return command
	return ""


static func _action(actions: Array, name: String, index: int = -2) -> String:
	for action: Dictionary in actions:
		if action.get("action") != name or not bool(action.get("enabled", false)):
			continue
		var public_index := int(action.get("index", 0))
		if index == -2 or index == public_index:
			return "click_action %s %d" % [name, public_index]
	return ""


static func _choose_hand(game: Dictionary, policy: String, hit: String, stand: String, double: String) -> String:
	var hands: Array = game.get("player_hands", [])
	var hand_index := int(game.get("active_hand_index", 0))
	var hand: Dictionary = hands[hand_index] if hand_index >= 0 and hand_index < hands.size() else {}
	var total := int(hand.get("total", game.get("blackjack_total", 0)))
	if total < 1:
		return WAIT
	var up := _card_value(game.get("dealer_up_card", {}))
	if policy == "baseline" or up == 0:
		return hit if total < 17 else stand
	var soft := bool(hand.get("soft", game.get("blackjack_soft", false)))
	var shown: Array = game.get("dealer_cards", []) if bool(game.get("dealer_hole_visible", false)) else []
	var hole := _card_value(shown[1]) if shown.size() > 1 else 0
	if up + hole == 11 and mini(up, hole) == 1:
		return stand
	var rules := str(game.get("table_rules_text", "")).to_lower()
	var hits_soft_17 := "hits soft 17" in rules or "h17" in rules
	var distribution := _dealer_distribution(up, hole, hits_soft_17)
	var utilities := _transfer_utilities(game, policy)
	var memo := {}
	var stand_value := _stand_value(total, distribution, utilities, 1)
	var hit_value := 0.0
	var double_value := 0.0
	for value in range(1, 11):
		var next := _add_card(total, soft, value)
		var weight := _card_weight(value)
		hit_value += weight * _hand_value(next.x, next.y == 1, distribution, utilities, memo)
		if not double.is_empty():
			double_value += weight * _stand_value(next.x, distribution, utilities, 2)
	if not double.is_empty() and double_value > maxf(hit_value, stand_value) + 0.000001:
		return double
	return hit if hit_value > stand_value + 0.000001 else stand


static func _card_value(card: Dictionary) -> int:
	var rank := int(card.get("rank", 0))
	return 1 if rank == 14 else mini(rank, 10)


static func _card_weight(value: int) -> float:
	return (4.0 if value == 10 else 1.0) / 13.0


static func _add_card(total: int, soft: bool, value: int) -> Vector2i:
	var next_total := total + value
	if value == 1 and next_total + 10 <= 21 and not soft:
		return Vector2i(next_total + 10, 1)
	if soft and next_total > 21:
		return Vector2i(next_total - 10, 0)
	return Vector2i(next_total, int(soft))


static func _dealer_distribution(up: int, hole: int, hits_soft_17: bool) -> PackedFloat64Array:
	# The six entries represent dealer 17 through 21, then bust. The rank
	# weights approximate a shoe without using any undealt cards or seed data.
	var result := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var opening := _add_card(0, false, up)
	var memo := {}
	if hole > 0:
		var start := _add_card(opening.x, opening.y == 1, hole)
		return _dealer_tail(start.x, start.y == 1, hits_soft_17, memo)
	var probability := 0.0
	for value in range(1, 11):
		var start := _add_card(opening.x, opening.y == 1, value)
		# A live decision proves the dealer's automatic blackjack check passed.
		if start.x == 21:
			continue
		var weight := _card_weight(value)
		probability += weight
		var tail := _dealer_tail(start.x, start.y == 1, hits_soft_17, memo)
		for index in result.size():
			result[index] += weight * tail[index]
	for index in result.size():
		result[index] /= probability
	return result


static func _dealer_tail(total: int, soft: bool, hits_soft_17: bool, memo: Dictionary) -> PackedFloat64Array:
	var key := Vector2i(total, int(soft))
	if memo.has(key):
		return memo[key]
	var result := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if total > 21:
		result[5] = 1.0
	elif total >= 17 and not (total == 17 and soft and hits_soft_17):
		result[total - 17] = 1.0
	else:
		for value in range(1, 11):
			var next := _add_card(total, soft, value)
			var tail := _dealer_tail(next.x, next.y == 1, hits_soft_17, memo)
			var weight := _card_weight(value)
			for index in result.size():
				result[index] += weight * tail[index]
	memo[key] = result
	return result


static func _stand_value(total: int, distribution: PackedFloat64Array, utilities: Dictionary, units: int) -> float:
	if total > 21:
		return float(utilities[-units])
	var value := distribution[5] * float(utilities[units])
	for index in range(5):
		var dealer := index + 17
		var transfer := units if total > dealer else -units if total < dealer else 0
		value += distribution[index] * float(utilities[transfer])
	return value


static func _hand_value(total: int, soft: bool, distribution: PackedFloat64Array, utilities: Dictionary, memo: Dictionary) -> float:
	var key := Vector2i(total, int(soft))
	if memo.has(key):
		return float(memo[key])
	var result := _stand_value(total, distribution, utilities, 1)
	if total < 21:
		var hit_value := 0.0
		for value in range(1, 11):
			var next := _add_card(total, soft, value)
			hit_value += _card_weight(value) * _hand_value(next.x, next.y == 1, distribution, utilities, memo)
		result = maxf(result, hit_value)
	memo[key] = result
	return result


static func _transfer_utilities(game: Dictionary, policy: String) -> Dictionary:
	if policy != "risk_aware" or not bool(game.get("boss_duel_active", false)):
		return {-2: -2.0, -1: -1.0, 0: 0.0, 1: 1.0, 2: 2.0}
	var player := int(game.get("boss_player_stack", 0))
	var rourke := int(game.get("boss_rourke_stack", 0))
	var ante := maxi(1, int(game.get("selected_stake", 20)))
	var rounds := clampi(int(game.get("boss_hand_limit", 5)) - int(game.get("boss_hand_number", 1)), 0, 4)
	var memo := {}
	var result := {}
	for units in range(-2, 3):
		var transfer := clampi(units * ante, -player, rourke)
		var victory := _future_victory(player + transfer, rourke - transfer, rounds, ante, memo)
		# Prefer the better chip result by a small amount when survival is tied.
		result[units] = victory + 0.0001 * transfer
	return result


static func _future_victory(player: int, rourke: int, rounds: int, ante: int, memo: Dictionary) -> float:
	if player <= 0:
		return 0.0
	if rourke <= 0:
		return 1.0
	if rounds == 0:
		return float(player - rourke >= VICTORY_MARGIN)
	var key := Vector2i(player, rounds)
	if memo.has(key):
		return float(memo[key])
	# Approximate unseen future hands from aggregate blackjack frequencies.
	# The future callout chance is a planning prior, never the actual schedule.
	var result := 0.0
	for call_index in range(2):
		var call := 0 if call_index == 0 else mini(18, rourke)
		var call_weight := 0.30 if call_index == 0 else 0.70
		if call == rourke:
			result += call_weight
			continue
		for outcome in [[-ante, 0.47], [0, 0.085], [ante, 0.40], [floori(1.5 * ante), 0.045]]:
			var transfer := clampi(int(outcome[0]), -player - call, rourke - call)
			result += call_weight * float(outcome[1]) * _future_victory(
				player + call + transfer, rourke - call - transfer, rounds - 1, ante, memo
			)
	memo[key] = result
	return result
