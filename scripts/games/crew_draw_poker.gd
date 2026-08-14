class_name CrewDrawPokerGame
extends GameModule

# Friendly, honest five-card draw. All random deck/policy/presentation choices
# consume the injected run RNG; the module never inspects undealt cards to act.

const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const PlayingCardRendererScript := preload("res://scripts/games/playing_card_renderer.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")

const STATE_SCHEMA := "crew_draw_table"
const STATE_VERSION := 1
const PLAYER_ID := "player"
const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_PINK := VisualStyleScript.PINK
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const MEMBER_NAMES := {
	"crew_rook": "Rook", "crew_velvet": "Velvet", "crew_knuckles": "Knuckles",
	"crew_switch": "Switch", "crew_mags": "Mags", "crew_bishop": "Bishop", "crew_lucky": "Lucky",
}


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result := super.enter(run_state, environment)
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		result["message"] = "The table is friendly, not open. An associate at the table has to vouch for your chair."
	else:
		result["message"] = "The back-room table plays five-card draw: ante, bet, one draw, bet, showdown. Cash stays friendly."
	return result


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var tuning := CrewPokerModelScript.config()
	var candidates := _string_array(environment.get("resident_member_ids", []))
	if candidates.size() < 2:
		candidates = CrewStateModelScript.MEMBER_IDS.duplicate()
	var bounds: Array = tuning.get("opponent_count", [2, 3]) if typeof(tuning.get("opponent_count", [2, 3])) == TYPE_ARRAY else [2, 3]
	var minimum := clampi(int(bounds[0]) if not bounds.is_empty() else 2, 2, 3)
	var maximum := clampi(int(bounds[1]) if bounds.size() > 1 else minimum, minimum, 3)
	var count := clampi(rng.randi_range(minimum, maximum), 2, mini(3, candidates.size()))
	var members := rng.pick_many(candidates, count)
	return {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"members": members,
		"phase": "idle",
		"hand_number": 0,
		"session_swing": 0,
		"session_settled": false,
		"pot": 0,
		"shoe": [],
		"player_cards": [],
		"seats": [],
		"x": [],
		"beat": {},
		"last_result": {},
	}


func legal_actions(run_state: RunState, environment: Dictionary) -> Array:
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		return []
	var phase := str(state.get("phase", "idle"))
	match phase:
		"idle":
			if bool(state.get("session_settled", false)):
				return []
			return [_action("deal", "Ante & Deal", "Ante the friendly stake and deal five cards."), _action("cash_out", "Leave Table", "Settle the session and stand up.")]
		"before", "after":
			return [
				_action("call", "Check / Call", "Match the live bet and continue."),
				_action("raise", "Raise", "Make one friendly raise; the Crew may call or fold."),
				_action("fold", "Fold", "Release the hand. Hidden cards teach nothing."),
			]
		"draw":
			return [_action("draw", "Draw", "Keep selected cards and draw replacements."), _action("fold", "Fold", "Release the hand without a showdown.")]
	return []


func cheat_actions(_run_state: RunState, _environment: Dictionary) -> Array:
	return []


func wager_cost_for_context(action_id: String, _stake: int, _run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	var state := _table_state(environment)
	var tuning := CrewPokerModelScript.config()
	match action_id:
		"deal":
			var ante := int(tuning.get("ante", 2))
			return ante if _loss_room(state, ante) == ante else 0
		"call":
			var call_cost := int(state.get("to_call", 0))
			return call_cost if _loss_room(state, call_cost) == call_cost else 0
		"raise":
			var raise_cost := int(state.get("to_call", 0)) + int(tuning.get("raise_unit", 2))
			return raise_cost if _loss_room(state, raise_cost) == raise_cost else 0
	return 0


func wager_activity_incomplete(_run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> bool:
	return ["before", "draw", "after"].has(str(_table_state(environment).get("phase", "idle")))


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var state := _table_state(environment)
	var phase := str(state.get("phase", "idle"))
	var held := _index_array(ui_state.get("poker_held", []))
	var members := _string_array(state.get("members", []))
	var seats: Array = []
	for seat_value in _dict_array(state.get("seats", [])):
		var seat := (seat_value as Dictionary).duplicate(true)
		var member_id := str(seat.get("member_id", ""))
		seat["name"] = str(MEMBER_NAMES.get(member_id, member_id))
		if phase != "showdown" and not bool(seat.get("revealed", false)):
			seat["cards"] = _hidden_cards(5)
		seat.erase("policy")
		seats.append(seat)
	var beat := _copy_dict(state.get("beat", {}))
	var presentation := {}
	if not beat.is_empty():
		var authored_patterns := CrewPokerModelScript.patterns(str(beat.get("m", "")))
		var authored_index := int(beat.get("i", -1))
		if authored_index >= 0 and authored_index < authored_patterns.size():
			var authored: Dictionary = authored_patterns[authored_index]
			for presentation_key in ["channel", "timing_msec", "portrait_variant", "line", "quirk"]:
				presentation[presentation_key] = authored.get(presentation_key)
	var last := _copy_dict(state.get("last_result", {}))
	var actions_now := legal_actions(run_state, environment)
	return GameModule.surface_spec({
		"surface_renderer": "crew_draw_poker",
		"surface_life": "crew_table",
		"surface_cast": "crew",
		"surface_controls_native": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": true,
		"display_name": get_display_name(),
		"phase": phase,
		"members": members,
		"seats": seats,
		"player_cards": _card_array(state.get("player_cards", [])),
		"held": held,
		"pot": int(state.get("pot", 0)),
		"to_call": int(state.get("to_call", 0)),
		"hand_number": int(state.get("hand_number", 0)),
		"hand_cap": int(CrewPokerModelScript.config().get("session_hand_cap", 5)),
		"session_swing": int(state.get("session_swing", 0)),
		"swing_cap": int(CrewPokerModelScript.config().get("session_swing_cap", 24)),
		"buy_in_open": _buy_in_open(run_state, state),
		"observation": presentation,
		"banter": _banter_for_state(state),
		"last_result": last,
		"result_message": str(last.get("message", "")),
		"legal_actions": actions_now,
		"cheat_actions": [],
		"native_selected_surface_actions": [],
		"surface_audio": GameModule.surface_audio_spec({"profile_id": "crew_cards", "action_cues": {"poker_deal": "card_deal", "poker_draw": "card_draw", "poker_call": "chips_place", "poker_raise": "chips_place", "poker_fold": "card_fold"}}),
	})


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	var next := ui_state.duplicate(true)
	if surface_action == "poker_card":
		var held := _index_array(next.get("poker_held", []))
		if held.has(index):
			held.erase(index)
		elif index >= 0 and index < 5:
			held.append(index)
			held.sort()
		next["poker_held"] = held
		return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Selected cards stay. The rest draw."})
	var action_id := ""
	if surface_action.begins_with("poker_"):
		action_id = surface_action.trim_prefix("poker_")
	if action_id.is_empty():
		return {"handled": false}
	return GameModule.surface_command({
		"handled": true,
		"ui_state": next,
		"action_id": action_id,
		"action_kind": "legal",
		"resolve": true,
		"preserve_surface_ui_state": action_id == "draw",
		"selected_index": index,
		"message": "The table acts.",
	})


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		return _result(action_id, environment, 0, "Nobody at the table can vouch for your buy-in.", false)
	var bankroll_delta := 0
	var message := ""
	match action_id:
		"deal":
			var dealt := _deal_hand(run_state, state, rng)
			if not bool(dealt.get("ok", true)):
				return _result(action_id, environment, 0, str(dealt.get("message", "The deal is closed.")), false)
			bankroll_delta = int(dealt.get("delta", 0))
			message = str(dealt.get("message", "Cards are out."))
		"call":
			var called := _player_bet(state, false, run_state, rng)
			if not bool(called.get("ok", true)):
				return _result(action_id, environment, 0, str(called.get("message", "The call is closed.")), false)
			bankroll_delta = int(called.get("delta", 0))
			message = str(called.get("message", "Called."))
		"raise":
			var raised := _player_bet(state, true, run_state, rng)
			if not bool(raised.get("ok", true)):
				return _result(action_id, environment, 0, str(raised.get("message", "The raise is closed.")), false)
			bankroll_delta = int(raised.get("delta", 0))
			message = str(raised.get("message", "Raised."))
		"draw":
			var drawn := _player_draw(state, _index_array(ui_state.get("poker_held", [])), rng)
			if not bool(drawn.get("ok", true)):
				return _result(action_id, environment, 0, str(drawn.get("message", "The draw is closed.")), false)
			message = str(drawn.get("message", "Draw complete."))
		"fold":
			message = _finish_fold(state, run_state)
		"cash_out":
			message = _settle_session(state, run_state)
		_:
			return _result(action_id, environment, 0, "That move is not open at this table.", false)
	_update_environment_state(environment, state)
	var result := _result(action_id, environment, bankroll_delta, message, true)
	result["ui_state"] = {} if action_id != "draw" else {"poker_held": []}
	result["preserve_surface_ui_state"] = action_id == "draw"
	return result


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "crew_draw_poker":
		return false
	surface.surface_begin_design_space(surface.surface_board_size())
	_draw_room(surface)
	surface.surface_title("BACK-ROOM DRAW", Vector2(330, 30), C_YELLOW)
	surface.surface_label("POT $%d   SESSION %+$d / %d" % [int(state.get("pot", 0)), int(state.get("session_swing", 0)), int(state.get("swing_cap", 24))], Vector2(312, 54), 14, C_SOFT)
	_draw_seats(surface, state)
	_draw_player(surface, state)
	_draw_observation(surface, state)
	_draw_controls(surface, state)
	surface.surface_end_design_space()
	return true


func environment_object_state(_run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {"prop": "card_table", "label": "Back-Room Poker", "status": "A friendly five-card draw is running."}


static func scripted_session(seed: int, member_id: String, force_showdown: bool = true) -> Dictionary:
	# QA helper: every call is independently reproducible and exposes only test
	# facts. Runtime UI never invokes this seam.
	var rng := RngStream.new()
	rng.configure(seed)
	var deck := CardShoeScript.build_shoe(1, rng)
	var first := CardShoeScript.draw_cards(deck, 10)
	var player: Array = (first.get("cards", []) as Array).slice(0, 5)
	var npc: Array = (first.get("cards", []) as Array).slice(5, 10)
	var action := CrewPokerModelScript.npc_action(member_id, npc, "after", false, rng)
	return {"player": player, "npc": npc, "action": action, "showdown": force_showdown, "winner": CrewPokerModelScript.compare_hands(player, npc)}


func _deal_hand(run_state: RunState, state: Dictionary, rng: RngStream) -> Dictionary:
	if str(state.get("phase", "idle")) != "idle" or bool(state.get("session_settled", false)):
		return {"ok": false, "delta": 0, "message": "Finish the live hand first."}
	var tuning := CrewPokerModelScript.config()
	var ante := int(tuning.get("ante", 2))
	if _loss_room(state, ante) != ante or run_state.bankroll < ante:
		return {"ok": false, "delta": 0, "message": "The friendly ante is beyond this session's remaining cash."}
	var deck := CardShoeScript.build_shoe(1, rng)
	var draw := CardShoeScript.draw_cards(deck, 5)
	state["player_cards"] = draw.get("cards", [])
	deck = draw.get("shoe", [])
	var seats: Array = []
	for member_id in _string_array(state.get("members", [])):
		draw = CardShoeScript.draw_cards(deck, 5)
		deck = draw.get("shoe", [])
		seats.append({"member_id": member_id, "cards": draw.get("cards", []), "active": true, "revealed": false, "contribution": ante, "draw_count": -1, "last_action": "ante"})
	state["shoe"] = deck
	state["seats"] = seats
	state["pot"] = ante * (seats.size() + 1)
	state["player_contribution"] = ante
	state["x"] = []
	state["beat"] = {}
	state["phase"] = "before"
	state["to_call"] = _npc_betting_round(state, "before", false, rng)
	state["session_swing"] = int(state.get("session_swing", 0)) - ante
	return {"ok": true, "delta": -ante, "message": "Five each. $%d to call before the draw." % int(state.get("to_call", 0))}


func _player_bet(state: Dictionary, raising: bool, run_state: RunState, rng: RngStream) -> Dictionary:
	var phase := str(state.get("phase", ""))
	if not ["before", "after"].has(phase):
		return {"ok": false, "delta": 0, "message": "No bet is waiting."}
	var tuning := CrewPokerModelScript.config()
	var cost := int(state.get("to_call", 0)) + (int(tuning.get("raise_unit", 2)) if raising else 0)
	if _loss_room(state, cost) != cost or cost > run_state.bankroll:
		return {"ok": false, "delta": 0, "message": "That call exceeds the friendly session limit."}
	state["pot"] = int(state.get("pot", 0)) + cost
	state["player_contribution"] = int(state.get("player_contribution", 0)) + cost
	state["session_swing"] = int(state.get("session_swing", 0)) - cost
	if raising:
		var seats: Array = state.get("seats", [])
		for index in range(seats.size()):
			var seat: Dictionary = seats[index]
			if not bool(seat.get("active", false)):
				continue
			var action := CrewPokerModelScript.npc_action(str(seat.get("member_id", "")), _card_array(seat.get("cards", [])), phase, true, rng)
			seat["last_action"] = action
			if action == "fold":
				seat["active"] = false
			else:
				var extra := int(tuning.get("raise_unit", 2))
				seat["contribution"] = int(seat.get("contribution", 0)) + extra
				state["pot"] = int(state.get("pot", 0)) + extra
			seats[index] = seat
		state["seats"] = seats
	if phase == "before":
		_npc_draw_all(state, rng)
		state["phase"] = "draw"
		state["to_call"] = 0
		return {"ok": true, "delta": -cost, "message": "%s. Pick the cards you keep." % ("Raised" if raising else "Called")}
	var showdown := _showdown(state, run_state)
	return {"ok": true, "delta": -cost + int(showdown.get("payout", 0)), "message": str(showdown.get("message", "Showdown."))}


func _player_draw(state: Dictionary, held: Array, rng: RngStream) -> Dictionary:
	if str(state.get("phase", "")) != "draw":
		return {"ok": false, "message": "The draw is closed."}
	var cards := _card_array(state.get("player_cards", []))
	var shoe := _card_array(state.get("shoe", []))
	var replace: Array = []
	for index in range(cards.size()):
		if not held.has(index):
			replace.append(index)
	var draw := CardShoeScript.draw_cards(shoe, replace.size())
	var replacements := _card_array(draw.get("cards", []))
	for index in range(replace.size()):
		cards[int(replace[index])] = replacements[index]
	state["player_cards"] = cards
	state["shoe"] = draw.get("shoe", [])
	state["phase"] = "after"
	state["beat"] = {}
	state["to_call"] = _npc_betting_round(state, "after", false, rng)
	return {"ok": true, "message": "You draw %d. $%d to call after the draw." % [replace.size(), int(state.get("to_call", 0))]}


func _npc_betting_round(state: Dictionary, phase: String, facing_raise: bool, rng: RngStream) -> int:
	var tuning := CrewPokerModelScript.config()
	var bet := int(tuning.get("bet_unit", 2))
	var raise_unit := int(tuning.get("raise_unit", 2))
	var highest := 0
	var seats: Array = state.get("seats", [])
	for index in range(seats.size()):
		var seat: Dictionary = seats[index]
		if not bool(seat.get("active", false)):
			continue
		var action := CrewPokerModelScript.npc_action(str(seat.get("member_id", "")), _card_array(seat.get("cards", [])), phase, facing_raise, rng)
		seat["last_action"] = action
		if action == "fold":
			seat["active"] = false
		else:
			var amount := bet + (raise_unit if action == "raise" else 0)
			seat["contribution"] = int(seat.get("contribution", 0)) + amount
			state["pot"] = int(state.get("pot", 0)) + amount
			highest = maxi(highest, amount)
			if phase == "after":
				_maybe_surface(state, seat, action, rng)
		seats[index] = seat
	state["seats"] = seats
	return highest


func _npc_draw_all(state: Dictionary, rng: RngStream) -> void:
	var shoe := _card_array(state.get("shoe", []))
	var seats: Array = state.get("seats", [])
	for index in range(seats.size()):
		var seat: Dictionary = seats[index]
		if not bool(seat.get("active", false)):
			continue
		var member_id := str(seat.get("member_id", ""))
		var cards := _card_array(seat.get("cards", []))
		var replace := CrewPokerModelScript.draw_indices(cards, CrewPokerModelScript.policy(member_id))
		var draw := CardShoeScript.draw_cards(shoe, replace.size())
		var replacements := _card_array(draw.get("cards", []))
		shoe = _card_array(draw.get("shoe", []))
		for draw_index in range(replace.size()):
			cards[int(replace[draw_index])] = replacements[draw_index]
		seat["cards"] = cards
		seat["draw_count"] = replace.size()
		seats[index] = seat
		_maybe_surface(state, seat, "draw", rng)
	state["shoe"] = shoe
	state["seats"] = seats


func _maybe_surface(state: Dictionary, seat: Dictionary, action: String, rng: RngStream) -> void:
	var member_id := str(seat.get("member_id", ""))
	var authored := CrewPokerModelScript.surface_pattern(member_id, _card_array(seat.get("cards", [])), action, int(seat.get("draw_count", -1)), rng)
	if authored.is_empty():
		return
	var authored_patterns := CrewPokerModelScript.patterns(member_id)
	var authored_index := -1
	for index in range(authored_patterns.size()):
		if str((authored_patterns[index] as Dictionary).get("state_key", "")) == str(authored.get("state_key", "")):
			authored_index = index
			break
	if authored_index < 0:
		return
	var neutral := {"m": member_id, "i": authored_index}
	state["beat"] = neutral
	var shown: Array = state.get("x", [])
	if not shown.has(neutral):
		shown.append(neutral)
	state["x"] = shown


func _showdown(state: Dictionary, run_state: RunState) -> Dictionary:
	var contenders: Array = [{"id": PLAYER_ID, "cards": _card_array(state.get("player_cards", []))}]
	var seats: Array = state.get("seats", [])
	for index in range(seats.size()):
		var seat: Dictionary = seats[index]
		if bool(seat.get("active", false)):
			seat["revealed"] = true
			contenders.append({"id": str(seat.get("member_id", "")), "cards": _card_array(seat.get("cards", []))})
		seats[index] = seat
	state["seats"] = seats
	var winners: Array = []
	var best_cards: Array = []
	for contender_value in contenders:
		var contender: Dictionary = contender_value
		var cards := _card_array(contender.get("cards", []))
		if winners.is_empty() or CrewPokerModelScript.compare_hands(cards, best_cards) > 0:
			winners = [str(contender.get("id", ""))]
			best_cards = cards
		elif CrewPokerModelScript.compare_hands(cards, best_cards) == 0:
			winners.append(str(contender.get("id", "")))
	var shares := CrewPokerModelScript.split_pot(int(state.get("pot", 0)), winners)
	var raw_payout := int(shares.get(PLAYER_ID, 0))
	var payout := mini(raw_payout, _win_room(state, raw_payout))
	state["session_swing"] = int(state.get("session_swing", 0)) + payout
	for shown_value in _dict_array(state.get("x", [])):
		var shown: Dictionary = shown_value
		var shown_member := str(shown.get("m", ""))
		var shown_patterns := CrewPokerModelScript.patterns(shown_member)
		var shown_index := int(shown.get("i", -1))
		if shown_index >= 0 and shown_index < shown_patterns.size() and (winners.has(shown_member) or _seat_active(seats, shown_member)):
			run_state.crew_record_pattern(shown_member, str((shown_patterns[shown_index] as Dictionary).get("state_key", "")))
	var player_score := CrewPokerModelScript.evaluate_hand(state.get("player_cards", []))
	var message := "%s. %s" % [str(player_score.get("label", "Hand")), "You take $%d." % payout if raw_payout > 0 else "%s takes it." % _winner_names(winners)]
	_finish_hand(state, run_state, {"winners": winners, "payout": payout, "message": message})
	return {"payout": payout, "message": message}


func _finish_fold(state: Dictionary, run_state: RunState) -> String:
	if not ["before", "draw", "after"].has(str(state.get("phase", ""))):
		return "There is no live hand to fold."
	var active: Array = []
	for seat_value in _dict_array(state.get("seats", [])):
		if bool((seat_value as Dictionary).get("active", false)):
			active.append(str((seat_value as Dictionary).get("member_id", "")))
	var message := "%s gathers the pot. No cards turn over." % _winner_names([active[0]] if not active.is_empty() else [])
	_finish_hand(state, run_state, {"winners": active.slice(0, 1), "payout": 0, "message": message})
	return message


func _finish_hand(state: Dictionary, run_state: RunState, last: Dictionary) -> void:
	state["hand_number"] = int(state.get("hand_number", 0)) + 1
	state["last_result"] = last
	state["phase"] = "idle"
	state["pot"] = 0
	state["to_call"] = 0
	state["x"] = []
	state["beat"] = {}
	if int(state.get("hand_number", 0)) >= int(CrewPokerModelScript.config().get("session_hand_cap", 5)):
		_settle_session(state, run_state)


func _settle_session(state: Dictionary, run_state: RunState) -> String:
	if bool(state.get("session_settled", false)):
		return "The friendly money is already settled."
	if int(state.get("hand_number", 0)) > 0:
		run_state.crew_record_poker_session(_string_array(state.get("members", [])), int(state.get("session_swing", 0)))
	state["session_settled"] = true
	return "The table settles at %+$d. Nobody makes it bigger than it is." % int(state.get("session_swing", 0))


func _buy_in_open(run_state: RunState, state: Dictionary) -> bool:
	if run_state == null:
		return false
	for member_id in _string_array(state.get("members", [])):
		if CrewStateModelScript.RANK_IDS.find(run_state.crew_rank(member_id)) >= CrewStateModelScript.RANK_IDS.find("associate"):
			return true
	return false


func _loss_room(state: Dictionary, wanted: int) -> int:
	var cap := int(CrewPokerModelScript.config().get("session_swing_cap", 24))
	return mini(maxi(0, wanted), maxi(0, cap + int(state.get("session_swing", 0))))


func _win_room(state: Dictionary, wanted: int) -> int:
	var cap := int(CrewPokerModelScript.config().get("session_swing_cap", 24))
	return mini(maxi(0, wanted), maxi(0, cap - int(state.get("session_swing", 0))))


func _table_state(environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("schema", "")) == STATE_SCHEMA:
		return (value as Dictionary).duplicate(true)
	return {"schema": STATE_SCHEMA, "version": STATE_VERSION, "members": [], "phase": "idle", "hand_number": 0, "session_swing": 0, "session_settled": false, "pot": 0, "shoe": [], "player_cards": [], "seats": [], "x": [], "beat": {}, "last_result": {}}


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	states = states.duplicate(true)
	states[get_id()] = state.duplicate(true)
	environment["game_states"] = states


func _result(action_id: String, environment: Dictionary, delta: int, message: String, ok: bool) -> Dictionary:
	var result := GameModule.build_action_result({"ok": ok, "source_id": get_id(), "game_id": get_id(), "action_id": action_id, "action_kind": "legal", "environment_id": str(environment.get("id", "")), "environment_archetype_id": str(environment.get("archetype_id", "")), "bankroll_delta": delta, "won": delta > 0, "message": message})
	result["host_apply_result"] = ok
	result["surface_audio_cue"] = "card_showdown" if action_id == "call" or action_id == "raise" else ""
	return result


func _action(id: String, label: String, summary: String) -> Dictionary:
	return {"id": id, "label": label, "summary": summary, "win_chance": 0, "payout_mult": 0}


func _seat_active(seats: Array, member_id: String) -> bool:
	for seat_value in seats:
		if typeof(seat_value) == TYPE_DICTIONARY and str((seat_value as Dictionary).get("member_id", "")) == member_id:
			return bool((seat_value as Dictionary).get("active", false))
	return false


func _winner_names(winners: Array) -> String:
	var names: Array = []
	for winner_value in winners:
		var winner := str(winner_value)
		names.append("you" if winner == PLAYER_ID else str(MEMBER_NAMES.get(winner, winner)))
	return " and ".join(names) if not names.is_empty() else "The room"


func _banter_for_state(state: Dictionary) -> String:
	var members := _string_array(state.get("members", []))
	if members.is_empty():
		return "The bare table waits."
	var lines: Dictionary = CrewPokerModelScript.config().get("banter", {}) if typeof(CrewPokerModelScript.config().get("banter", {})) == TYPE_DICTIONARY else {}
	var member_id := str(members[int(state.get("hand_number", 0)) % members.size()])
	var options: Array = lines.get(member_id, []) if typeof(lines.get(member_id, [])) == TYPE_ARRAY else []
	return str(options[int(state.get("hand_number", 0)) % options.size()]) if not options.is_empty() else "%s cuts the deck." % MEMBER_NAMES.get(member_id, member_id)


func _draw_room(surface) -> void:
	surface.draw_rect(Rect2(20, 20, 860, 380), Color("#08090d"))
	var lamp := 0.50 + sin(surface.surface_flicker() * 1.7) * 0.08
	surface.draw_circle(Vector2(450, 70), 18.0, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, lamp))
	surface.draw_rect(Rect2(54, 82, 792, 238), Color("#17131d"))
	surface.draw_rect(Rect2(118, 104, 664, 224), Color("#173a35"))
	surface.draw_rect(Rect2(118, 104, 664, 224), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.35), false, 2)


func _draw_seats(surface, state: Dictionary) -> void:
	var positions := [Vector2(92, 104), Vector2(354, 78), Vector2(664, 104)]
	var seats := _dict_array(state.get("seats", []))
	var members := _string_array(state.get("members", []))
	for index in range(maxi(seats.size(), members.size())):
		var seat: Dictionary = seats[index] if index < seats.size() else {"member_id": members[index], "cards": _hidden_cards(5), "active": true}
		var pos: Vector2 = positions[index]
		var name := str(MEMBER_NAMES.get(str(seat.get("member_id", "")), "Crew"))
		var color := C_SOFT if bool(seat.get("active", true)) else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.4)
		surface.surface_label(name.to_upper(), pos, 14, color)
		var cards := _card_array(seat.get("cards", []))
		for card_index in range(cards.size()):
			PlayingCardRendererScript.draw_card(surface, cards[card_index], Rect2(pos + Vector2(card_index * 20, 10), Vector2(18, 27)))
		surface.surface_label(str(seat.get("last_action", "")).capitalize(), pos + Vector2(0, 52), 11, C_YELLOW)


func _draw_player(surface, state: Dictionary) -> void:
	var cards := _card_array(state.get("player_cards", []))
	var held := _index_array(state.get("held", []))
	var start := Vector2(294, 232)
	for index in range(cards.size()):
		var rect := Rect2(start + Vector2(index * 64, 0), Vector2(52, 74))
		PlayingCardRendererScript.draw_card(surface, cards[index], rect, {"held": held.has(index)})
		if str(state.get("phase", "")) == "draw":
			surface.surface_add_hit(rect.grow(4), "poker_card", index)
			surface.surface_label("KEEP" if held.has(index) else "DRAW", rect.position + Vector2(7, 88), 10, C_TEAL if held.has(index) else C_PINK)


func _draw_observation(surface, state: Dictionary) -> void:
	var observation := _copy_dict(state.get("observation", {}))
	var text := str(observation.get("line", observation.get("quirk", "")))
	if text.is_empty():
		text = str(state.get("banter", "The room keeps its own time."))
	surface.draw_rect(Rect2(172, 325, 556, 38), Color(0.03, 0.03, 0.05, 0.88))
	surface.surface_label(text.left(76), Vector2(188, 349), 12, C_SOFT)


func _draw_controls(surface, state: Dictionary) -> void:
	var actions := _dict_array(state.get("legal_actions", []))
	var x := 168.0
	for index in range(actions.size()):
		var action: Dictionary = actions[index]
		var rect := Rect2(x, 370, 150, 38)
		surface.draw_rect(rect, Color("#241b32"))
		surface.draw_rect(rect, C_CYAN, false, 1)
		surface.surface_label_centered(str(action.get("label", "ACT")).to_upper(), rect, 12, C_WHITE)
		surface.surface_add_hit(rect, "poker_%s" % str(action.get("id", "")), index)
		x += 164.0
	if not bool(state.get("buy_in_open", false)):
		surface.surface_label_centered("ASSOCIATE VOUCH REQUIRED", Rect2(240, 372, 420, 34), 14, C_PINK)


func _hidden_cards(count: int) -> Array:
	var result: Array = []
	for _index in range(count):
		result.append({"hidden": true})
	return result


func _card_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for card_value in value:
			if typeof(card_value) == TYPE_DICTIONARY:
				result.append((card_value as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			var text := str(entry).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


func _index_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			var index := int(entry)
			if index >= 0 and index < 5 and not result.has(index):
				result.append(index)
	result.sort()
	return result


func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
