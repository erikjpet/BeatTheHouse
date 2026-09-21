class_name CrewDrawPokerGame
extends GameModule

# Friendly, honest Texas Hold'em. All deck, policy, and presentation choices
# consume the injected run RNG; opponents never inspect undealt or rival cards.

const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const PlayingCardRendererScript := preload("res://scripts/games/playing_card_renderer.gd")
const TableGameVisualsScript := preload("res://scripts/games/table_game_visuals.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")

const STATE_SCHEMA := "crew_draw_table"
const STATE_VERSION := 4
const PLAYER_ID := "player"
const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_PINK := VisualStyleScript.PINK
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const SEAT_LAYOUT := [
	{
		"block_origin": Vector2(18, 176),
		"character_foot": Vector2(60, 229),
		"hole_card_origin": Vector2(109, 190),
		"action_label_rect": Rect2(18, 245, 142, 16),
		"action_font_size": 10,
		"action_carries_name": false,
		"dealer_button_center": Vector2(174, 214),
		"bet_chip_center": Vector2(232, 256),
		"focus_rect": Rect2(18, 155, 166, 110),
	},
	{
		"block_origin": Vector2(150, 96),
		"character_foot": Vector2(192, 149),
		"hole_card_origin": Vector2(241, 110),
		"action_label_rect": Rect2(150, 165, 80, 16),
		"action_font_size": 10,
		"action_carries_name": false,
		"dealer_button_center": Vector2(310, 130),
		"bet_chip_center": Vector2(272, 188),
		"focus_rect": Rect2(145, 82, 174, 114),
	},
	{
		"block_origin": Vector2(408, 95),
		"character_foot": Vector2(450, 148),
		"hole_card_origin": Vector2(499, 106),
		"action_label_rect": Rect2(502, 142, 96, 16),
		"action_font_size": 8,
		"action_carries_name": true,
		"dealer_button_center": Vector2(590, 130),
		"bet_chip_center": Vector2(390, 145),
		"focus_rect": Rect2(404, 82, 196, 78),
	},
	{
		"block_origin": Vector2(604, 96),
		"character_foot": Vector2(646, 149),
		"hole_card_origin": Vector2(695, 110),
		"action_label_rect": Rect2(666, 165, 70, 16),
		"action_font_size": 10,
		"action_carries_name": false,
		"dealer_button_center": Vector2(758, 130),
		"bet_chip_center": Vector2(630, 188),
		"focus_rect": Rect2(599, 82, 174, 114),
	},
	{
		"block_origin": Vector2(736, 176),
		"character_foot": Vector2(778, 229),
		"hole_card_origin": Vector2(827, 190),
		"action_label_rect": Rect2(736, 245, 142, 16),
		"action_font_size": 10,
		"action_carries_name": false,
		"dealer_button_center": Vector2(726, 214),
		"bet_chip_center": Vector2(700, 256),
		"focus_rect": Rect2(716, 155, 166, 110),
	},
]
const MAX_OPPONENT_SEATS := 5
const SEAT_LAYOUT_INDICES := {
	1: [2],
	2: [0, 4],
	3: [0, 2, 4],
	4: [0, 1, 3, 4],
	5: [0, 1, 2, 3, 4],
}
const DEALER_STATION_LAYOUT := {
	"character_foot": Vector2(690, 330),
	"character_scale": 0.64,
	"deck_card_rect": Rect2(638, 292, 24, 35),
	"muck_rect": Rect2(718, 302, 28, 18),
	"pot_center": Vector2(590, 270),
	"name_label_rect": Rect2(720, 325, 58, 11),
	"station_bounds": Rect2(544, 238, 234, 99),
}
const CARD_ANIMATION_CHANNEL := "crew_poker_cards"
const CHIP_ANIMATION_CHANNEL := "crew_poker_chips"
const PAYOUT_ANIMATION_CHANNEL := "crew_poker_payout"
const HIDDEN_CARD := {"hidden": true}
const MEMBER_NAMES := {
	"crew_rook": "Rook", "crew_velvet": "Velvet", "crew_knuckles": "Knuckles",
	"crew_switch": "Switch", "crew_mags": "Mags", "crew_bishop": "Bishop", "crew_lucky": "Lucky",
}
const NIGHT_IDS := ["friendly_teaching", "hustle_test", "debt_court", "after_job", "raid_jitters"]
const OBSERVATION_DURATION_ACTIONS := 3
const ORDERED_ENGINE := "ordered_v1"

var draw_card_events_cache_id := ""
var draw_card_events_cache: Array = []
var draw_chip_events_cache_id := ""
var draw_chip_events_cache: Array = []
var last_npc_decision_usec := 0


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result := super.enter(run_state, environment)
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		result["message"] = "The table is friendly, not open. An associate at the table has to vouch for your chair."
	elif bool(state.get("session_settled", false)):
		result["message"] = "The last night is settled. A fresh visit can open a newly seeded table."
	else:
		result["message"] = "The crew is seated for Texas Hold'em: blinds, four betting streets, a shared board, and honest cards. Watch what they show—and choose what you show back."
	return result


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var tuning := CrewPokerModelScript.config()
	var residents: Array = []
	for resident_id in _string_array(environment.get("resident_member_ids", [])):
		if CrewStateModelScript.MEMBER_IDS.has(resident_id) and not residents.has(resident_id):
			residents.append(resident_id)
	var bounds: Array = tuning.get("opponent_count", [2, MAX_OPPONENT_SEATS]) if typeof(tuning.get("opponent_count", [2, MAX_OPPONENT_SEATS])) == TYPE_ARRAY else [2, MAX_OPPONENT_SEATS]
	var crew_selection := _select_table_crew(CrewStateModelScript.MEMBER_IDS, residents, bounds, rng)
	var members: Array = crew_selection.get("members", [])
	return {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"producer_id": "poker",
		"game_id": get_id(),
		"members": members,
		"dealer_member_id": str(crew_selection.get("dealer_member_id", "")),
		"phase": "idle",
		"hand_number": 0,
		"session_swing": 0,
		"session_settled": false,
		"session_index": 0,
		"night_id": _night_id(environment),
		"action_ordinal": 0,
		"observation_queue": [],
		"verified_observation_receipts": [],
		"turn_engine": ORDERED_ENGINE if _ordered_engine(environment) else "legacy_v1",
		"button_index": 0,
		"turn_owner": "",
		"turn_order": [],
		"turn_cursor": 0,
		"current_bet": 0,
		"last_raise_size": int(CrewPokerModelScript.config().get("raise_unit", 2)),
		"round_contributions": {},
		"acted_since_raise": [],
		"raise_count": 0,
		"player_active": true,
		"player_stack": int(tuning.get("session_swing_cap", 60)),
		"action_history": [],
		"session_memory": {},
		"seat_temperament": _neutral_temperament(members),
		"player_reads": _neutral_player_reads(),
		"hand_lines": _neutral_hand_lines(),
		"public_memory_receipt_id": "",
		"player_folded_hidden": false,
		"community_cards": [],
		"burn_cards": [],
		"dealer_actor": "",
		"small_blind_actor": "",
		"big_blind_actor": "",
		"player_all_in": false,
		"player_signal": {},
		"player_signal_history": [],
		"player_fake_tell_used_street": "",
		"tell_reputation": 50,
		"table_talk_history": [],
		"table_talk_hand_count": 0,
		"table_talk_last_ordinal": -999,
		"table_talk_members_this_hand": [],
		"npc_stacks": {},
		"pot": 0,
		"shoe": [],
		"player_cards": [],
		"seats": [],
		"x": [],
		"beat": {},
		"last_result": {},
	}


func _select_table_crew(available_value: Array, residents_value: Array, bounds: Array, rng: RngStream) -> Dictionary:
	var available: Array = []
	for member_id in available_value:
		if CrewStateModelScript.MEMBER_IDS.has(str(member_id)) and not available.has(str(member_id)):
			available.append(str(member_id))
	var residents: Array = []
	for member_id in residents_value:
		if available.has(str(member_id)) and not residents.has(str(member_id)):
			residents.append(str(member_id))
	# The house dealer is reserved before chairs are counted. Reduced-roster
	# fixtures therefore lose opponents first, while retaining at least two.
	var maximum_with_dealer := mini(MAX_OPPONENT_SEATS, maxi(2, available.size() - 1))
	var minimum := clampi(int(bounds[0]) if not bounds.is_empty() else maximum_with_dealer, 2, maximum_with_dealer)
	var maximum := clampi(int(bounds[1]) if bounds.size() > 1 else minimum, minimum, maximum_with_dealer)
	var count := rng.randi_range(minimum, maximum)
	var members: Array = residents.duplicate() if residents.size() <= count else rng.pick_many(residents, count)
	if members.size() < count:
		var fill: Array = []
		for member_id in available:
			if not members.has(member_id):
				fill.append(member_id)
		members.append_array(rng.pick_many(fill, count - members.size()))
	var unseated: Array = []
	for member_id in available:
		if not members.has(member_id):
			unseated.append(member_id)
	return {"members": members, "dealer_member_id": str(rng.pick(unseated, ""))}


func legal_actions(run_state: RunState, environment: Dictionary) -> Array:
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		return []
	if _ordered_engine(environment):
		return _ordered_legal_actions(state)
	var phase := str(state.get("phase", "idle"))
	match phase:
		"idle":
			if bool(state.get("session_settled", false)):
				return [_poker_action("new_session", "Open New Night", "Begin a fresh seeded session after the settlement boundary.")]
			return [_poker_action("deal", "Ante & Deal", "Ante the friendly stake and deal five cards."), _poker_action("cash_out", "Leave Table", "Settle the session and stand up.")]
		"before", "after":
			return [
				_poker_action("call", "Check / Call", "Match the live bet and continue."),
				_poker_action("raise", "Raise", "Make one friendly raise; the Crew may call or fold."),
				_poker_action("fold", "Fold", "Release the hand. Hidden cards teach nothing."),
			]
		"draw":
			return [_poker_action("draw", "Draw", "Keep selected cards and draw replacements."), _poker_action("fold", "Fold", "Release the hand without a showdown.")]
	return []


func cheat_actions(_run_state: RunState, _environment: Dictionary) -> Array:
	return []


func wager_cost_for_context(action_id: String, _stake: int, _run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	var state := _table_state(environment)
	var tuning := CrewPokerModelScript.config()
	if _ordered_engine(environment):
		match action_id:
			"deal":
				return _player_forced_blind(state)
			"call":
				return mini(maxi(0, int(state.get("current_bet", 0)) - _actor_round_contribution(state, PLAYER_ID)), int(state.get("player_stack", 0)))
			"raise":
				var player_round := _actor_round_contribution(state, PLAYER_ID)
				var minimum_raise_to := _minimum_raise_to(state)
				var maximum_raise_to := _maximum_raise_to(state)
				if maximum_raise_to < minimum_raise_to:
					return 0
				var selected_raise_to := clampi(int(ui_state.get("poker_raise_to", minimum_raise_to)), minimum_raise_to, maximum_raise_to)
				return mini(maxi(0, selected_raise_to - player_round), int(state.get("player_stack", 0)))
			"all_in":
				return int(state.get("player_stack", 0))
		return 0
	match action_id:
		"deal":
			var ante := int(tuning.get("ante", 2))
			return ante if _loss_room(state, ante) == ante else 0
		"new_session":
			return 0
		"call":
			var call_cost := int(state.get("to_call", 0))
			return call_cost if _loss_room(state, call_cost) == call_cost else 0
		"raise":
			var raise_cost := int(state.get("to_call", 0)) + int(tuning.get("raise_unit", 2))
			return raise_cost if _loss_room(state, raise_cost) == raise_cost else 0
	return 0


func wager_activity_incomplete(_run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> bool:
	return ["before", "draw", "after", "preflop", "flop", "turn", "river"].has(str(_table_state(environment).get("phase", "idle")))


func surface_realtime_patch_preserves_host_state() -> bool:
	# Card/chip/payout animation ticks cannot mutate any Foundation host state.
	return true


func surface_realtime_uses_lightweight_ui_state() -> bool:
	return true


func surface_realtime_ui_state_keys() -> Array:
	return ["poker_animation", "reduce_motion"]


func surface_realtime_state_patch(_run_state: RunState, _environment: Dictionary, ui_state: Dictionary, _current_surface_state: Dictionary = {}) -> Dictionary:
	var animation: Dictionary = ui_state.get("poker_animation", {}) if typeof(ui_state.get("poker_animation", {})) == TYPE_DICTIONARY else {}
	var presentation_msec := int(ui_state.get("surface_presentation_time_msec", ui_state.get("surface_time_msec", 0)))
	var reduce_motion := bool(ui_state.get("reduce_motion", false))
	return {
		"surface_realtime_state_refresh": _animation_bundle_live(animation, presentation_msec, reduce_motion),
		"surface_animation_channels": _surface_animation_channels(animation),
		"reduce_motion": reduce_motion,
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var state := _table_state(environment)
	var phase := str(state.get("phase", "idle"))
	var held := _index_array(ui_state.get("poker_held", []))
	var members := _string_array(state.get("members", []))
	var focused_speaker: Variant = ui_state.get("focused_talk_speaker", {})
	var seats: Array = []
	for seat_value in _dict_array(state.get("seats", [])):
		var seat := (seat_value as Dictionary).duplicate(true)
		var member_id := str(seat.get("member_id", ""))
		seat["name"] = str(MEMBER_NAMES.get(member_id, member_id))
		seat["style_summary"] = str(CrewPokerModelScript.policy(member_id).get("style_summary", ""))
		seat["character_model"] = _crew_character_model(member_id)
		seat["conversation_active"] = _speaker_matches_member(focused_speaker, member_id)
		if phase != "showdown" and not bool(seat.get("revealed", false)):
			seat["cards"] = _hidden_cards(2 if str(state.get("turn_engine", "legacy_v1")) == ORDERED_ENGINE else 5)
		seat.erase("policy")
		seat.erase("starting_stack")
		seat.erase("decision_intent")
		seats.append(seat)
	for member_id in members:
		var already_seated := false
		for seat_value in seats:
			if str((seat_value as Dictionary).get("member_id", "")) == member_id:
				already_seated = true
				break
		if already_seated:
			continue
		seats.append({
			"member_id": member_id,
			"name": str(MEMBER_NAMES.get(member_id, member_id)),
			"style_summary": str(CrewPokerModelScript.policy(member_id).get("style_summary", "")),
			"cards": [],
			"active": true,
			"all_in": false,
			"last_action": "ready",
			"character_model": _crew_character_model(member_id),
			"conversation_active": _speaker_matches_member(focused_speaker, member_id),
		})
	var table_talk_active := false
	for seat_value in seats:
		if bool((seat_value as Dictionary).get("conversation_active", false)):
			table_talk_active = true
			break
	var beat := _poker_dict(state.get("beat", {}))
	var visible_observations := _visible_observations(state)
	if not visible_observations.is_empty():
		beat = visible_observations[0]
	var presentation := {}
	if not beat.is_empty():
		var presentation_member := str(beat.get("m", ""))
		var authored_patterns := CrewPokerModelScript.patterns(presentation_member)
		var authored_index := int(beat.get("i", -1))
		if authored_index >= 0 and authored_index < authored_patterns.size():
			var authored: Dictionary = authored_patterns[authored_index]
			for presentation_key in ["channel", "timing_msec", "portrait_variant", "line", "quirk"]:
				presentation[presentation_key] = authored.get(presentation_key)
			presentation["member_id"] = presentation_member
			presentation["observation_id"] = str(beat.get("id", ""))
			presentation["start_ordinal"] = int(beat.get("start_ordinal", 0))
			presentation["duration_actions"] = int(beat.get("duration_actions", OBSERVATION_DURATION_ACTIONS))
	if str(presentation.get("channel", "")) == "portrait":
		for seat_index in range(seats.size()):
			var presentation_seat: Dictionary = seats[seat_index]
			if str(presentation_seat.get("member_id", "")) == str(presentation.get("member_id", "")):
				presentation_seat["portrait_variant"] = str(presentation.get("portrait_variant", ""))
				seats[seat_index] = presentation_seat
	var last := _poker_dict(state.get("last_result", {}))
	var actions_now := legal_actions(run_state, environment)
	var minimum_raise_to := _minimum_raise_to(state)
	var maximum_raise_to := _maximum_raise_to(state)
	var selected_raise_to := clampi(int(ui_state.get("poker_raise_to", minimum_raise_to)), minimum_raise_to, maxi(minimum_raise_to, maximum_raise_to))
	var raise_panel_open := bool(ui_state.get("poker_raise_panel_open", false)) and maximum_raise_to >= minimum_raise_to
	var animation: Dictionary = ui_state.get("poker_animation", {}) if typeof(ui_state.get("poker_animation", {})) == TYPE_DICTIONARY else {}
	var presentation_msec := int(ui_state.get("surface_presentation_time_msec", ui_state.get("surface_time_msec", 0)))
	var reduce_motion := bool(ui_state.get("reduce_motion", false))
	var animation_channels := _surface_animation_channels(animation)
	return GameModule.surface_spec({
		"surface_renderer": "crew_draw_poker",
		"surface_renderer_opaque": true,
		"surface_life": "crew_table",
		"surface_cast": "crew",
		"surface_controls_native": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": _animation_bundle_live(animation, presentation_msec, reduce_motion),
		"surface_template": "shared_table_game_v1",
		"animated_crew_count": seats.size() + (1 if not str(state.get("dealer_member_id", "")).is_empty() else 0),
		"table_talk_active": table_talk_active,
		"reduce_motion": reduce_motion,
		"surface_animation_channels": animation_channels,
		"display_name": get_display_name(),
		"phase": phase,
		"turn_engine": str(state.get("turn_engine", "legacy_v1")),
		"members": members,
		"dealer_member_id": str(state.get("dealer_member_id", "")),
		"dealer_name": _actor_name(str(state.get("dealer_member_id", ""))),
		"dealer_character_model": _crew_character_model(str(state.get("dealer_member_id", ""))),
		"dealer_station_layout": DEALER_STATION_LAYOUT,
		"poker_animation_kind": str(animation.get("kind", "")),
		"poker_animation_showdown": bool(animation.get("showdown", false)),
		"card_animation_id": str(animation.get("card_id", "")),
		"card_animation_events": animation.get("card_events", []),
		"chip_animation_id": str(animation.get("chip_id", "")),
		"chip_animation_events": animation.get("chip_events", []),
		"payout_animation_id": str(animation.get("payout_id", "")),
		"payout_animation_events": animation.get("payout_events", []),
		"seats": seats,
		"player_cards": _card_array(state.get("player_cards", [])),
		"community_cards": _card_array(state.get("community_cards", [])),
		"held": held,
		"pot": int(state.get("pot", 0)),
		"to_call": int(state.get("to_call", 0)),
		"turn_owner": str(state.get("turn_owner", "")),
		"turn_owner_name": _actor_name(str(state.get("turn_owner", ""))),
		"button_index": int(state.get("button_index", 0)),
		"current_bet": int(state.get("current_bet", 0)),
		"last_raise_size": int(state.get("last_raise_size", CrewPokerModelScript.config().get("raise_unit", 2))),
		"amount_to_call": maxi(0, int(state.get("current_bet", 0)) - _actor_round_contribution(state, PLAYER_ID)),
		"minimum_raise_to": minimum_raise_to,
		"maximum_raise_to": maximum_raise_to,
		"selected_raise_to": selected_raise_to,
		"raise_panel_open": raise_panel_open,
		"round_contributions": _poker_dict(state.get("round_contributions", {})),
		"chip_layout": _chip_layout(state),
		"raise_count": int(state.get("raise_count", 0)),
		"raise_cap": -1,
		"player_stack": int(state.get("player_stack", 0)),
		"player_all_in": bool(state.get("player_all_in", false)),
		"dealer_actor": str(state.get("dealer_actor", "")),
		"small_blind_actor": str(state.get("small_blind_actor", "")),
		"big_blind_actor": str(state.get("big_blind_actor", "")),
		"tell_style": str(ui_state.get("poker_tell_style", "strong")),
		"player_signal": _poker_dict(state.get("player_signal", {})),
		"tell_reputation": int(state.get("tell_reputation", 50)),
		"player_contribution": int(state.get("player_contribution", 0)),
		"action_history": _public_action_history(state.get("action_history", [])),
		"night_scene": _night_scene_state(state),
		"ritual_actors": _ordered_ritual_actors(state),
		"ritual_scene_objects": _ordered_ritual_objects(state),
		"hand_number": int(state.get("hand_number", 0)),
		"hand_cap": int(CrewPokerModelScript.config().get("session_hand_cap", 5)),
		"session_swing": int(state.get("session_swing", 0)),
		"swing_cap": int(CrewPokerModelScript.config().get("session_swing_cap", 60)),
		"buy_in_open": _buy_in_open(run_state, state),
		"observation": presentation,
		"observation_queue": _public_observation_queue(state),
		"action_ordinal": int(state.get("action_ordinal", 0)),
		"night_id": str(state.get("night_id", "friendly_teaching")),
		"banter": _banter_for_state(state),
		"last_result": last,
		"result_message": str(last.get("message", "")),
		"legal_actions": actions_now,
		"cheat_actions": [],
		"native_selected_surface_actions": [],
		"surface_audio": GameModule.surface_audio_spec({"profile_id": "crew_cards", "selection_seed": run_state.seed_value if run_state != null else 1, "action_cues": {"poker_deal": "card_deal", "poker_call": "chips_place", "poker_raise": "chips_place", "poker_all_in": "chips_place", "poker_fake_tell": "card_check", "poker_fold": "card_fold"}}),
	})


func _surface_animation_channels(animation: Dictionary) -> Array:
	var started := int(animation.get("started_msec", 0))
	var channels: Array = []
	for row in [
		{"channel": CARD_ANIMATION_CHANNEL, "id": str(animation.get("card_id", "")), "duration": int(animation.get("card_duration_msec", 0))},
		{"channel": CHIP_ANIMATION_CHANNEL, "id": str(animation.get("chip_id", "")), "duration": int(animation.get("chip_duration_msec", 0))},
		{"channel": PAYOUT_ANIMATION_CHANNEL, "id": str(animation.get("payout_id", "")), "duration": int(animation.get("payout_duration_msec", 0))},
	]:
		if not str(row.get("id", "")).is_empty():
			channels.append(GameModule.surface_animation_channel(str(row.get("channel", "")), str(row.get("id", "")), int(row.get("duration", 0)), started, {"clock_source": "presentation"}))
	return channels


func _animation_bundle_live(animation: Dictionary, now_msec: int, reduce_motion: bool) -> bool:
	if animation.is_empty() or reduce_motion:
		return false
	var started := int(animation.get("started_msec", 0))
	if started <= 0:
		return true
	var longest := maxi(int(animation.get("card_duration_msec", 0)), maxi(int(animation.get("chip_duration_msec", 0)), int(animation.get("payout_duration_msec", 0))))
	return now_msec < started + longest


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, _run_state: RunState, environment: Dictionary) -> Dictionary:
	var next := ui_state.duplicate(true)
	# A click always accepts the authoritative landing state before the requested
	# command is resolved; the old channel disappears and the command runs once.
	next.erase("poker_animation")
	var table := _table_state(environment)
	var minimum_raise_to := _minimum_raise_to(table)
	var maximum_raise_to := _maximum_raise_to(table)
	if surface_action == "poker_raise_open":
		if maximum_raise_to < minimum_raise_to:
			return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Your stack cannot make a legal raise."})
		next["poker_raise_panel_open"] = true
		next["poker_raise_to"] = clampi(int(next.get("poker_raise_to", minimum_raise_to)), minimum_raise_to, maximum_raise_to)
		return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Choose the total amount to raise to."})
	if surface_action in ["poker_raise_minus_five", "poker_raise_minus_one", "poker_raise_plus_one", "poker_raise_plus_five", "poker_raise_min", "poker_raise_max"]:
		if not bool(next.get("poker_raise_panel_open", false)) or maximum_raise_to < minimum_raise_to:
			return {"handled": false}
		var selected := clampi(int(next.get("poker_raise_to", minimum_raise_to)), minimum_raise_to, maximum_raise_to)
		match surface_action:
			"poker_raise_minus_five": selected -= 5
			"poker_raise_minus_one": selected -= 1
			"poker_raise_plus_one": selected += 1
			"poker_raise_plus_five": selected += 5
			"poker_raise_min": selected = minimum_raise_to
			"poker_raise_max": selected = maximum_raise_to
		next["poker_raise_to"] = clampi(selected, minimum_raise_to, maximum_raise_to)
		return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Raise target: $%d." % int(next["poker_raise_to"])})
	if surface_action == "poker_raise_cancel":
		next["poker_raise_panel_open"] = false
		return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Raise selection closed."})
	if surface_action == "poker_raise_confirm":
		if not bool(next.get("poker_raise_panel_open", false)) or maximum_raise_to < minimum_raise_to:
			return {"handled": false}
		next["poker_raise_to"] = clampi(int(next.get("poker_raise_to", minimum_raise_to)), minimum_raise_to, maximum_raise_to)
		next["poker_raise_panel_open"] = false
		return GameModule.surface_command({"handled": true, "ui_state": next, "action_id": "raise", "action_kind": "legal", "resolve": true, "selected_index": index, "message": "Raise to $%d." % int(next["poker_raise_to"])})
	if surface_action == "poker_tell_style":
		next["poker_tell_style"] = "weak" if index == 1 else "strong"
		return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "You prepare a %s signal." % str(next["poker_tell_style"])})
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
		"preserve_surface_ui_state": action_id in ["draw", "fake_tell"],
		"selected_index": index,
		"message": "The table acts.",
	})


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if _ordered_engine(environment):
		return _resolve_ordered(action_id, run_state, environment, rng, ui_state)
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		return _result(action_id, environment, 0, "Nobody at the table can vouch for your buy-in.", false)
	var legal_ids: Array = []
	for action_value in legal_actions(run_state, environment):
		if typeof(action_value) == TYPE_DICTIONARY:
			legal_ids.append(str((action_value as Dictionary).get("id", "")))
	if not legal_ids.has(action_id):
		var blocked_message := "Finish the live hand before leaving the table." if action_id == "cash_out" and ["before", "draw", "after"].has(str(state.get("phase", ""))) else "That move is not open in this part of the hand."
		return _result(action_id, environment, 0, blocked_message, false)
	var bankroll_delta := 0
	var message := ""
	match action_id:
		"new_session":
			_start_new_session(state, environment)
			message = "A fresh night begins. The button moves and the table cuts a new deck."
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
	state["action_ordinal"] = int(state.get("action_ordinal", 0)) + 1
	_update_environment_state(environment, state)
	var result := _result(action_id, environment, bankroll_delta, message, true)
	result["ui_state"] = {} if action_id != "draw" else {"poker_held": []}
	result["preserve_surface_ui_state"] = action_id == "draw"
	return result


func _ordered_legal_actions(state: Dictionary) -> Array:
	var phase := str(state.get("phase", "idle"))
	if phase == "idle":
		if bool(state.get("session_settled", false)):
			return [_poker_action("new_session", "Open New Night", "Start a newly seeded session after the settled boundary.")]
		var night_actions := _night_required_actions(state)
		if not night_actions.is_empty():
			return night_actions
		return [_poker_action("deal", "Deal Hold'em", "Move the button, post blinds, and deal two cards to every occupied chair."), _poker_action("cash_out", "Leave Table", "Settle once between hands.")]
	var owner := str(state.get("turn_owner", ""))
	if owner.is_empty():
		return []
	if owner != PLAYER_ID:
		return [_poker_action("observe", "Watch %s" % MEMBER_NAMES.get(owner, owner), "Advance exactly one visible Crew decision.")]
	if phase in ["preflop", "flop", "turn", "river"]:
		var due := maxi(0, int(state.get("current_bet", 0)) - _actor_round_contribution(state, PLAYER_ID))
		var stack := int(state.get("player_stack", 0))
		var loss_room := _loss_room(state, stack)
		var actions: Array = []
		if due == 0 or (stack >= due and loss_room >= due):
			actions.append(_poker_action("call", "Call $%d" % due if due > 0 else "Check", "Match exactly the live amount or check for zero."))
		if _maximum_raise_to(state) >= _minimum_raise_to(state):
			actions.insert(1, _poker_action("raise", "Choose Raise", "Choose any legal whole-dollar raise up to your full stack."))
		if stack > 0 and loss_room == stack:
			actions.append(_poker_action("all_in", "All In $%d" % stack, "Commit your remaining table stack."))
		if str(state.get("player_fake_tell_used_street", "")) != phase:
			actions.append(_poker_action("fake_tell", "Fake Tell", "Project strength or weakness without ending your turn."))
		actions.append(_poker_action("fold", "Fold", "Release the hand; hidden cards teach nothing."))
		return actions
	return []


func _minimum_raise_to(state: Dictionary) -> int:
	return int(state.get("current_bet", 0)) + maxi(1, int(state.get("last_raise_size", CrewPokerModelScript.config().get("raise_unit", 2))))


func _maximum_raise_to(state: Dictionary) -> int:
	var stack := maxi(0, int(state.get("player_stack", 0)))
	return _actor_round_contribution(state, PLAYER_ID) + _loss_room(state, stack)


func _resolve_ordered(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var state := _table_state(environment)
	if not _buy_in_open(run_state, state):
		return _result(action_id, environment, 0, "Nobody at the table can vouch for your buy-in.", false)
	var legal_ids: Array[String] = []
	for action in _ordered_legal_actions(state):
		legal_ids.append(str((action as Dictionary).get("id", "")))
	if not legal_ids.has(action_id):
		return _result(action_id, environment, 0, "That action is outside the current ordered turn.", false)
	var builds_presentation := ui_state.has("surface_presentation_time_msec") or ui_state.has("surface_time_msec")
	var before_state := _presentation_state_snapshot(state) if builds_presentation else {}
	var outcome := {"ok": true, "delta": 0, "message": "The table acts."}
	match action_id:
		"new_session":
			_start_new_session(state, environment)
			state["turn_engine"] = ORDERED_ENGINE
			state["player_stack"] = int(CrewPokerModelScript.config().get("session_swing_cap", 60))
			outcome["message"] = "A fresh night begins. The button moves and the table cuts a new deck."
		"deal":
			outcome = _deal_hand_ordered(run_state, state, rng)
		"observe":
			outcome = _ordered_npc_turn(state, rng, run_state)
		"call", "raise":
			outcome = _ordered_player_bet(state, action_id == "raise", run_state, rng, int(ui_state.get("poker_raise_to", _minimum_raise_to(state))))
		"all_in":
			outcome = _ordered_player_all_in(state, run_state, rng)
		"fake_tell":
			outcome = _ordered_player_fake_tell(state, str(ui_state.get("poker_tell_style", "strong")))
		"fold":
			outcome = _ordered_player_fold(state, run_state, rng)
		"cash_out":
			outcome["message"] = _settle_session(state, run_state)
		"answer_duty", "choose_company", "hide_table", "resume_table":
			outcome = _resolve_night_task(state, action_id)
		"abort_night":
			state["night_aftermath"] = "table_cleared_after_knock"
			outcome["message"] = _settle_session(state, run_state)
	if not bool(outcome.get("ok", false)):
		return _result(action_id, environment, 0, str(outcome.get("message", "The action is rejected without mutation.")), false)
	state["action_ordinal"] = int(state.get("action_ordinal", 0)) + 1
	# Pure simulations do not carry a presentation clock, so they skip allocating
	# visual events. The production surface and capture/test paths always do.
	var animation := _build_presentation_animation(before_state, state, action_id, ui_state) if builds_presentation else {}
	_update_environment_state(environment, state)
	var result := _result(action_id, environment, int(outcome.get("delta", 0)), str(outcome.get("message", "The table acts.")), true)
	var next_ui := ui_state.duplicate(true)
	if action_id == "draw":
		next_ui["poker_held"] = []
	if animation.is_empty():
		next_ui.erase("poker_animation")
	else:
		next_ui["poker_animation"] = animation
	result["ui_state"] = next_ui
	result["preserve_surface_ui_state"] = true
	if not animation.is_empty():
		var animation_kind := str(animation.get("kind", ""))
		result["surface_audio_cue"] = "card_fold" if animation_kind == "fold" else "card_deal" if not (animation.get("card_events", []) as Array).is_empty() else "chips_place"
	result["crew_poker_turn_receipt"] = "crew-poker:%d:%d" % [int(state.get("session_index", 0)), int(state.get("action_ordinal", 0))]
	result["crew_poker_public_facts"] = _ordered_public_facts(state, action_id)
	if typeof(outcome.get("table_talk_request")) == TYPE_DICTIONARY and not (outcome.get("table_talk_request") as Dictionary).is_empty():
		result["crew_poker_table_talk_request"] = (outcome.get("table_talk_request") as Dictionary).duplicate(true)
	if typeof(outcome.get("authority_gaps")) == TYPE_ARRAY and not (outcome.get("authority_gaps") as Array).is_empty():
		result["crew_poker_authority_gaps"] = (outcome.get("authority_gaps") as Array).duplicate()
	if not str(outcome.get("dependency_reason", "")).is_empty():
		result["dependency_reason"] = str(outcome.get("dependency_reason", ""))
	return result


func _deal_hand_ordered(run_state: RunState, state: Dictionary, rng: RngStream) -> Dictionary:
	if str(state.get("phase", "idle")) != "idle" or bool(state.get("session_settled", false)):
		return {"ok": false, "delta": 0, "message": "Finish the live hand first."}
	var tuning := CrewPokerModelScript.config()
	_decay_temperament(state)
	state["hand_lines"] = _neutral_hand_lines()
	var forced_blind := _player_forced_blind(state)
	if run_state.bankroll <= 0 or _loss_room(state, forced_blind) != forced_blind or run_state.bankroll < forced_blind:
		return {"ok": false, "delta": 0, "message": "The blind is beyond this session's remaining cash."}
	var deck := CardShoeScript.build_shoe(1, rng)
	var cap := int(tuning.get("buy_in", tuning.get("session_swing_cap", 60)))
	var stack_memory: Dictionary = state.get("npc_stacks", {}) if typeof(state.get("npc_stacks", {})) == TYPE_DICTIONARY else {}
	var seats: Array = []
	for member_id in _string_array(state.get("members", [])):
		var remembered_stack := int(stack_memory.get(member_id, cap))
		if remembered_stack < int(tuning.get("big_blind", 2)):
			remembered_stack = cap
		seats.append({"member_id": member_id, "cards": [], "active": true, "all_in": false, "revealed": false, "contribution": 0, "round_contribution": 0, "stack": remembered_stack, "starting_stack": remembered_stack, "draw_count": -1, "last_action": "waiting", "decision_intent": ""})
	# Deal one card at a time around the table, twice, so the button order is real
	# while the deck remains wholly owned by the injected deterministic RNG.
	state["seats"] = seats
	state["player_cards"] = []
	for _round in range(2):
		for actor in _all_actor_ids(state):
			var draw := CardShoeScript.draw_cards(deck, 1)
			deck = _card_array(draw.get("shoe", []))
			var dealt := _card_array(draw.get("cards", []))
			if actor == PLAYER_ID:
				var player_cards := _card_array(state.get("player_cards", []))
				player_cards.append_array(dealt)
				state["player_cards"] = player_cards
			else:
				var seat_index := _seat_index(state, str(actor))
				var live_seats: Array = state.get("seats", [])
				var seat: Dictionary = live_seats[seat_index]
				var hole := _card_array(seat.get("cards", []))
				hole.append_array(dealt)
				seat["cards"] = hole
				live_seats[seat_index] = seat
				state["seats"] = live_seats
	state["shoe"] = deck
	state["community_cards"] = []
	state["burn_cards"] = []
	state["pot"] = 0
	state["current_bet"] = 0
	state["last_raise_size"] = int(tuning.get("big_blind", tuning.get("raise_unit", 2)))
	state["round_contributions"] = {}
	state["player_contribution"] = 0
	state["player_stack"] = mini(int(state.get("player_stack", cap)), run_state.bankroll)
	state["player_active"] = true
	state["player_all_in"] = false
	state["player_signal"] = {}
	state["player_fake_tell_used_street"] = ""
	state["table_talk_hand_count"] = 0
	state["table_talk_last_ordinal"] = -999
	state["table_talk_members_this_hand"] = []
	state["x"] = []
	state["beat"] = {}
	var actors := _all_actor_ids(state)
	var button := int(state.get("button_index", 0)) % maxi(1, actors.size())
	state["dealer_actor"] = str(actors[button])
	state["small_blind_actor"] = str(actors[(button + 1) % actors.size()])
	state["big_blind_actor"] = str(actors[(button + 2) % actors.size()])
	var player_paid := 0
	player_paid += _commit_actor_chips(state, str(state.get("small_blind_actor", "")), int(tuning.get("small_blind", 1)))
	player_paid += _commit_actor_chips(state, str(state.get("big_blind_actor", "")), int(tuning.get("big_blind", 2)))
	state["session_swing"] = int(state.get("session_swing", 0)) - player_paid
	_start_holdem_round(state, "preflop")
	return {"ok": true, "delta": -player_paid, "message": "Two cards each. %s has the button; %s opens pre-flop." % [_actor_name(str(state.get("dealer_actor", ""))), _actor_name(str(state.get("turn_owner", "")))]}


func _start_holdem_round(state: Dictionary, phase: String) -> void:
	state["phase"] = phase
	var actors: Array = _all_actor_ids(state)
	if actors.is_empty():
		state["turn_owner"] = ""
		return
	var starting_actor := str(state.get("big_blind_actor", "")) if phase == "preflop" else str(state.get("dealer_actor", ""))
	var starting_index := actors.find(starting_actor)
	var order: Array = []
	for offset in range(1, actors.size() + 1):
		var actor := str(actors[(starting_index + offset) % actors.size()])
		if _actor_active(state, actor):
			order.append(actor)
	state["turn_order"] = order
	state["turn_cursor"] = 0
	state["turn_owner"] = _first_actor_who_can_act(state, order)
	if phase != "preflop":
		state["current_bet"] = 0
		state["last_raise_size"] = int(CrewPokerModelScript.config().get("big_blind", CrewPokerModelScript.config().get("raise_unit", 2)))
		state["round_contributions"] = {}
		for index in range((state.get("seats", []) as Array).size()):
			var seat: Dictionary = (state.get("seats", []) as Array)[index]
			seat["round_contribution"] = 0
			(state.get("seats", []) as Array)[index] = seat
	state["acted_since_raise"] = []
	state["raise_count"] = 0
	state["player_fake_tell_used_street"] = ""
	state["player_signal"] = {}


func _ordered_npc_turn(state: Dictionary, rng: RngStream, run_state: RunState) -> Dictionary:
	var actor := str(state.get("turn_owner", ""))
	if actor.is_empty() or actor == PLAYER_ID:
		return {"ok": false, "delta": 0, "message": "No Crew decision is waiting."}
	var seat_index := _seat_index(state, actor)
	if seat_index < 0:
		return {"ok": false, "delta": 0, "message": "The turn owner has no live seat."}
	var seats: Array = state.get("seats", [])
	var seat: Dictionary = seats[seat_index]
	var phase := str(state.get("phase", ""))
	var due := maxi(0, int(state.get("current_bet", 0)) - int(seat.get("round_contribution", 0)))
	var minimum_raise_size := maxi(1, int(state.get("last_raise_size", CrewPokerModelScript.config().get("raise_unit", 2))))
	var minimum_raise_to := int(state.get("current_bet", 0)) + minimum_raise_size
	var maximum_raise_to := int(seat.get("round_contribution", 0)) + maxi(0, int(seat.get("stack", 0)))
	var can_raise := maximum_raise_to >= minimum_raise_to
	var temperament: Dictionary = (state.get("seat_temperament", {}) as Dictionary).get(actor, {}) if typeof(state.get("seat_temperament", {})) == TYPE_DICTIONARY else {}
	var lines: Dictionary = state.get("hand_lines", {}) if typeof(state.get("hand_lines", {})) == TYPE_DICTIONARY else {}
	var checked: Dictionary = lines.get("checked_by_street", {}) if typeof(lines.get("checked_by_street", {})) == TYPE_DICTIONARY else {}
	var checked_actors := _string_array(checked.get(phase, []))
	var turn_order: Array = state.get("turn_order", []) if typeof(state.get("turn_order", [])) == TYPE_ARRAY else []
	var position := 50 if turn_order.size() <= 1 else int(round(float(maxi(0, turn_order.find(actor))) * 100.0 / float(turn_order.size() - 1)))
	var context := {
		"street": phase,
		"amount_to_call": due,
		"pot": int(state.get("pot", 0)),
		"stack": int(seat.get("stack", 0)),
		"current_bet": int(state.get("current_bet", 0)),
		"current_contribution": int(seat.get("round_contribution", 0)),
		"minimum_raise_to": minimum_raise_to,
		"maximum_raise_to": maximum_raise_to,
		"can_raise": can_raise,
		"raise_count": int(state.get("raise_count", 0)),
		"position": position,
		"active_opponents": maxi(1, _active_actor_ids(state).size() - 1),
		"was_preflop_aggressor": str(lines.get("preflop_aggressor", "")) == actor,
		"checked_this_street": checked_actors.has(actor),
		"player_signal": _poker_dict(state.get("player_signal", {})),
		"signal_credibility": int(state.get("tell_reputation", 50)),
		"player_reads": _player_read_rates(state),
		"observed_fold_rate": _observed_fold_rate(state),
		"tilt_level": int(temperament.get("tilt_level", 0)),
		"win_streak": int(temperament.get("win_streak", 0)),
		"stack_big_blinds": float(int(seat.get("stack", 0))) / float(maxi(1, int(CrewPokerModelScript.config().get("big_blind", 2)))),
	}
	var decision_started := Time.get_ticks_usec()
	var decision := CrewPokerModelScript.holdem_decision(actor, _card_array(seat.get("cards", [])), _card_array(state.get("community_cards", [])), context, rng)
	last_npc_decision_usec = Time.get_ticks_usec() - decision_started
	var action := str(decision.get("action", "call"))
	var intent := str(decision.get("intent", ""))
	var action_amount := 0
	if action == "fold":
		seat["active"] = false
		seat["last_action"] = "fold"
		seat["decision_intent"] = intent
		seats[seat_index] = seat
		state["seats"] = seats
		_record_ordered_action(state, actor, "fold", 0, false, intent)
	else:
		var prior_bet := int(state.get("current_bet", 0))
		var wants_aggression := action in ["bet", "raise", "all_in"]
		var target := maximum_raise_to if action == "all_in" else clampi(int(decision.get("target", minimum_raise_to)), minimum_raise_to, maximum_raise_to) if wants_aggression else prior_bet
		var amount := mini(maxi(due, target - int(seat.get("round_contribution", 0))) if wants_aggression else due, int(seat.get("stack", 0)))
		action_amount = amount
		seat["stack"] = int(seat.get("stack", 0)) - amount
		seat["contribution"] = int(seat.get("contribution", 0)) + amount
		seat["round_contribution"] = int(seat.get("round_contribution", 0)) + amount
		seat["all_in"] = int(seat.get("stack", 0)) == 0
		var increased_bet := wants_aggression and int(seat.get("round_contribution", 0)) > prior_bet
		var completed_raise := increased_bet and int(seat.get("round_contribution", 0)) >= prior_bet + minimum_raise_size
		var recorded_action := "all_in" if bool(seat.get("all_in", false)) and amount > 0 else "bet" if increased_bet and prior_bet == 0 else "raise" if increased_bet else "call" if due > 0 else "check"
		seat["last_action"] = recorded_action
		seat["decision_intent"] = intent
		seats[seat_index] = seat
		state["seats"] = seats
		state["pot"] = int(state.get("pot", 0)) + amount
		if increased_bet:
			state["current_bet"] = int(seat.get("round_contribution", 0))
		if completed_raise:
			state["last_raise_size"] = int(state.get("current_bet", 0)) - prior_bet
			state["raise_count"] = int(state.get("raise_count", 0)) + 1
		_record_ordered_action(state, actor, recorded_action, amount, completed_raise, intent)
		var tell_seat := seat.duplicate(true)
		var tell_cards := _card_array(seat.get("cards", []))
		tell_cards.append_array(_card_array(state.get("community_cards", [])))
		tell_seat["cards"] = tell_cards
		_maybe_surface(state, tell_seat, recorded_action, rng)
	var table_talk_request := _maybe_table_talk_request(state, actor, str(seat.get("last_action", action)))
	var advance := _advance_ordered_turn(state, rng, run_state)
	if not str(advance.get("message", "")).is_empty():
		return {"ok": true, "delta": int(advance.get("payout", 0)), "authority_gaps": (advance.get("authority_gaps", []) as Array), "dependency_reason": str(advance.get("dependency_reason", "")), "table_talk_request": table_talk_request, "message": str(advance.get("message", ""))}
	var visible_action := str(seat.get("last_action", action))
	var action_text := "folds" if visible_action == "fold" else "checks" if visible_action == "check" else "calls $%d" % due if visible_action == "call" else "bets $%d" % action_amount if visible_action == "bet" else "raises to $%d" % int(seat.get("round_contribution", 0)) if visible_action == "raise" else "shoves $%d" % action_amount
	return {"ok": true, "delta": 0, "table_talk_request": table_talk_request, "message": "%s %s. %s is next." % [_actor_name(actor), action_text, _actor_name(str(state.get("turn_owner", "")))]}


func _maybe_table_talk_request(state: Dictionary, member_id: String, action: String) -> Dictionary:
	if action not in ["check", "call", "bet", "raise", "all_in"] or not bool(state.get("player_active", false)):
		return {}
	var phase := str(state.get("phase", ""))
	if phase not in ["preflop", "flop", "turn", "river"]:
		return {}
	var tuning := CrewPokerModelScript.config()
	var active_opponents: Array = []
	for actor_value in _active_actor_ids(state):
		var actor := str(actor_value)
		if actor != PLAYER_ID:
			active_opponents.append(actor)
	var heads_up := active_opponents.size() == 1 and str(active_opponents[0]) == member_id
	var pot := int(state.get("pot", 0))
	var threshold := int(tuning.get("table_talk_heads_up_pot", 10)) if heads_up else int(tuning.get("table_talk_multiway_pot", 18))
	if pot < threshold:
		return {}
	if not heads_up and action not in ["bet", "raise", "all_in"]:
		return {}
	if int(state.get("table_talk_hand_count", 0)) >= int(tuning.get("table_talk_max_per_hand", 2)):
		return {}
	var ordinal := int(state.get("action_ordinal", 0))
	if ordinal - int(state.get("table_talk_last_ordinal", -999)) < int(tuning.get("table_talk_cooldown_actions", 3)):
		return {}
	var spoken_members := _string_array(state.get("table_talk_members_this_hand", []))
	if spoken_members.has(member_id):
		return {}
	var line_key := "poker_heads_up" if heads_up else "poker_big_pot"
	var node_id := "heads_up" if heads_up else "big_pot"
	if phase == "river":
		line_key = "poker_river"
		node_id = "river_pressure"
	elif action in ["bet", "raise", "all_in"]:
		line_key = "poker_raise"
		node_id = "raise_pressure"
	var event_id := "crew-poker-talk:%d:%d:%d:%s" % [int(state.get("session_index", 0)), int(state.get("hand_number", 0)), ordinal, member_id]
	var request := {
		"event_id": event_id,
		"game_id": get_id(),
		"member_id": member_id,
		"member_name": _actor_name(member_id),
		"seat_index": _seat_index(state, member_id),
		"line_key": line_key,
		"node_id": node_id,
		"phase": phase,
		"action": action,
		"pot": pot,
		"heads_up": heads_up,
		"hand_number": int(state.get("hand_number", 0)),
		"seat_count": _string_array(state.get("members", [])).size(),
	}
	spoken_members.append(member_id)
	state["table_talk_members_this_hand"] = spoken_members
	state["table_talk_hand_count"] = int(state.get("table_talk_hand_count", 0)) + 1
	state["table_talk_last_ordinal"] = ordinal
	var history := _dict_array(state.get("table_talk_history", []))
	history.append(request.duplicate(true))
	while history.size() > 12:
		history.pop_front()
	state["table_talk_history"] = history
	return request


func _ordered_player_bet(state: Dictionary, raising: bool, run_state: RunState, rng: RngStream, requested_raise_to: int = 0) -> Dictionary:
	if str(state.get("turn_owner", "")) != PLAYER_ID:
		return {"ok": false, "delta": 0, "message": "It is not your turn."}
	var rounds: Dictionary = state.get("round_contributions", {}) if typeof(state.get("round_contributions", {})) == TYPE_DICTIONARY else {}
	var player_round := int(rounds.get(PLAYER_ID, 0))
	var prior_bet := int(state.get("current_bet", 0))
	var due := maxi(0, prior_bet - player_round)
	var target := clampi(requested_raise_to, _minimum_raise_to(state), _maximum_raise_to(state)) if raising else prior_bet
	if raising and (requested_raise_to < _minimum_raise_to(state) or requested_raise_to > _maximum_raise_to(state)):
		return {"ok": false, "delta": 0, "message": "Choose a raise between $%d and $%d." % [_minimum_raise_to(state), _maximum_raise_to(state)]}
	var cost := maxi(0, target - player_round) if raising else due
	if cost > run_state.bankroll or cost > int(state.get("player_stack", 0)) or _loss_room(state, cost) != cost:
		return {"ok": false, "delta": 0, "message": "That action exceeds the friendly session ledger."}
	rounds[PLAYER_ID] = int(rounds.get(PLAYER_ID, 0)) + cost
	state["round_contributions"] = rounds
	state["player_contribution"] = int(state.get("player_contribution", 0)) + cost
	state["player_stack"] = int(state.get("player_stack", 0)) - cost
	state["player_all_in"] = int(state.get("player_stack", 0)) == 0
	state["pot"] = int(state.get("pot", 0)) + cost
	state["session_swing"] = int(state.get("session_swing", 0)) - cost
	if raising:
		state["current_bet"] = int(rounds.get(PLAYER_ID, 0))
		state["last_raise_size"] = int(state.get("current_bet", 0)) - prior_bet
		state["raise_count"] = int(state.get("raise_count", 0)) + 1
	var action_name := "all_in" if raising and bool(state.get("player_all_in", false)) else "raise" if raising else "call" if due > 0 else "check"
	_record_ordered_action(state, PLAYER_ID, action_name, cost, raising)
	var advance := _advance_ordered_turn(state, rng, run_state)
	var default_message := "You raise all in to $%d." % target if action_name == "all_in" else "You raise to $%d." % target if raising else "Called." if due > 0 else "Checked."
	return {"ok": true, "delta": -cost + int(advance.get("payout", 0)), "authority_gaps": (advance.get("authority_gaps", []) as Array).duplicate(), "dependency_reason": str(advance.get("dependency_reason", "")), "message": str(advance.get("message", default_message))}


func _ordered_player_all_in(state: Dictionary, run_state: RunState, rng: RngStream) -> Dictionary:
	if str(state.get("turn_owner", "")) != PLAYER_ID:
		return {"ok": false, "delta": 0, "message": "It is not your turn."}
	var cost := int(state.get("player_stack", 0))
	if cost <= 0 or cost > run_state.bankroll or _loss_room(state, cost) != cost:
		return {"ok": false, "delta": 0, "message": "There are no more table chips to commit."}
	var rounds: Dictionary = state.get("round_contributions", {}) if typeof(state.get("round_contributions", {})) == TYPE_DICTIONARY else {}
	var prior_bet := int(state.get("current_bet", 0))
	rounds[PLAYER_ID] = int(rounds.get(PLAYER_ID, 0)) + cost
	state["round_contributions"] = rounds
	state["player_contribution"] = int(state.get("player_contribution", 0)) + cost
	state["player_stack"] = 0
	state["player_all_in"] = true
	state["pot"] = int(state.get("pot", 0)) + cost
	state["session_swing"] = int(state.get("session_swing", 0)) - cost
	var all_in_total := int(rounds.get(PLAYER_ID, 0))
	var minimum_full_raise := maxi(1, int(state.get("last_raise_size", CrewPokerModelScript.config().get("raise_unit", 2))))
	var raised := all_in_total >= prior_bet + minimum_full_raise
	if all_in_total > prior_bet:
		state["current_bet"] = all_in_total
	if raised:
		state["last_raise_size"] = all_in_total - prior_bet
		state["raise_count"] = int(state.get("raise_count", 0)) + 1
	_record_ordered_action(state, PLAYER_ID, "all_in", cost, raised)
	var advance := _advance_ordered_turn(state, rng, run_state)
	return {"ok": true, "delta": -cost + int(advance.get("payout", 0)), "authority_gaps": (advance.get("authority_gaps", []) as Array).duplicate(), "dependency_reason": str(advance.get("dependency_reason", "")), "message": str(advance.get("message", "You move all your chips forward."))}


func _ordered_player_fake_tell(state: Dictionary, style: String) -> Dictionary:
	var phase := str(state.get("phase", ""))
	if str(state.get("turn_owner", "")) != PLAYER_ID or not phase in ["preflop", "flop", "turn", "river"]:
		return {"ok": false, "delta": 0, "message": "You can only shape a tell on your turn."}
	if str(state.get("player_fake_tell_used_street", "")) == phase:
		return {"ok": false, "delta": 0, "message": "They have already seen your performance this street."}
	style = "weak" if style == "weak" else "strong"
	state["player_signal"] = {"style": style, "street": phase, "ordinal": int(state.get("action_ordinal", 0))}
	var signals := _dict_array(state.get("player_signal_history", []))
	signals.append((state.get("player_signal", {}) as Dictionary).duplicate(true))
	state["player_signal_history"] = signals
	var reads: Dictionary = state.get("player_reads", {}) if typeof(state.get("player_reads", {})) == TYPE_DICTIONARY else _neutral_player_reads()
	reads["signals"] = mini(200, int(reads.get("signals", 0)) + 1)
	state["player_reads"] = reads
	state["player_fake_tell_used_street"] = phase
	var history := _dict_array(state.get("action_history", []))
	history.append({"ordinal": int(state.get("action_ordinal", 0)), "phase": phase, "actor": PLAYER_ID, "action": "signal_%s" % style, "amount": 0, "pot_after": int(state.get("pot", 0)), "current_bet": int(state.get("current_bet", 0))})
	state["action_history"] = history
	return {"ok": true, "delta": 0, "message": "You project %s. The table notices; your betting turn remains open." % ("confidence" if style == "strong" else "uncertainty")}


func _ordered_player_fold(state: Dictionary, run_state: RunState, rng: RngStream = null) -> Dictionary:
	state["player_active"] = false
	_record_ordered_action(state, PLAYER_ID, "fold", 0, false)
	state["player_folded_hidden"] = true
	var advance := _advance_ordered_turn(state, rng, run_state)
	var message := str(advance.get("message", "Your cards stay hidden. %s acts next." % _actor_name(str(state.get("turn_owner", "")))))
	return {"ok": true, "delta": 0, "message": message}


func _advance_ordered_turn(state: Dictionary, rng: RngStream, run_state: RunState = null) -> Dictionary:
	if _active_actor_ids(state).size() <= 1:
		if bool(state.get("player_active", false)):
			var raw_payout := int(state.get("pot", 0))
			var payout := mini(raw_payout, _win_room(state, raw_payout))
			state["session_swing"] = int(state.get("session_swing", 0)) + payout
			state["player_stack"] = int(state.get("player_stack", 0)) + raw_payout
			_update_temperament_after_hand(state, {PLAYER_ID: raw_payout})
			_finish_hand(state, run_state, {"winners": [PLAYER_ID], "awards": {PLAYER_ID: raw_payout}, "payout": payout, "table_payout": raw_payout, "message": "The table folds to you. You take $%d." % raw_payout})
			return {"payout": payout, "message": "The table folds to you. You take $%d." % raw_payout}
		var remaining := _active_actor_ids(state)
		var winners: Array = [str(remaining[0])] if not remaining.is_empty() else []
		if not winners.is_empty():
			_award_npc_stack(state, str(winners[0]), int(state.get("pot", 0)))
		_update_temperament_after_hand(state, {str(winners[0]): int(state.get("pot", 0))} if not winners.is_empty() else {})
		var message := "%s gathers the pot. Your folded cards stay hidden." % _winner_names(winners)
		_finish_hand(state, run_state, {"winners": winners, "awards": {str(winners[0]): int(state.get("pot", 0))} if not winners.is_empty() else {}, "payout": 0, "message": message})
		return {"payout": 0, "message": message}
	var phase := str(state.get("phase", ""))
	if _ordered_round_closed(state):
		return _advance_holdem_street(state, rng, run_state)
	_advance_cursor(state)
	return {}


func _advance_cursor(state: Dictionary) -> bool:
	var order: Array = state.get("turn_order", []) if typeof(state.get("turn_order", [])) == TYPE_ARRAY else []
	if order.is_empty():
		state["turn_owner"] = ""
		return true
	var cursor := int(state.get("turn_cursor", 0))
	for offset in range(1, order.size() + 1):
		var next := (cursor + offset) % order.size()
		var actor := str(order[next])
		if _actor_can_act(state, actor):
			state["turn_cursor"] = next
			state["turn_owner"] = actor
			return next <= cursor
	state["turn_owner"] = ""
	return true


func _ordered_round_closed(state: Dictionary) -> bool:
	var active := _actors_who_can_act(state)
	if active.size() <= 1:
		if active.is_empty():
			return true
		var lone := str(active[0])
		return _actor_round_contribution(state, lone) >= int(state.get("current_bet", 0)) or _active_actor_ids(state).size() <= 1
	var acted := _string_array(state.get("acted_since_raise", []))
	for actor in active:
		if not acted.has(str(actor)) or _actor_round_contribution(state, str(actor)) != int(state.get("current_bet", 0)):
			return false
	return true


func _advance_holdem_street(state: Dictionary, rng: RngStream, run_state: RunState) -> Dictionary:
	var phase := str(state.get("phase", "preflop"))
	if phase == "river":
		return _showdown(state, run_state)
	var next_phase := "flop" if phase == "preflop" else "turn" if phase == "flop" else "river"
	_burn_and_deal_board(state, 3 if next_phase == "flop" else 1)
	_start_holdem_round(state, next_phase)
	if _actors_who_can_act(state).size() <= 1:
		# When every remaining player is all-in, the board runs out immediately;
		# there are no fake decisions or observe clicks between deterministic cards.
		while str(state.get("phase", "")) != "river":
			var automatic_next := "turn" if str(state.get("phase", "")) == "flop" else "river"
			_burn_and_deal_board(state, 1)
			_start_holdem_round(state, automatic_next)
		return _showdown(state, run_state)
	return {"message": "The %s lands. %s acts first." % [next_phase, _actor_name(str(state.get("turn_owner", "")))]}


func _burn_and_deal_board(state: Dictionary, count: int) -> void:
	var shoe := _card_array(state.get("shoe", []))
	var burn := CardShoeScript.draw_cards(shoe, 1)
	shoe = _card_array(burn.get("shoe", []))
	var burns := _card_array(state.get("burn_cards", []))
	burns.append_array(_card_array(burn.get("cards", [])))
	var draw := CardShoeScript.draw_cards(shoe, count)
	var board := _card_array(state.get("community_cards", []))
	board.append_array(_card_array(draw.get("cards", [])))
	state["burn_cards"] = burns
	state["community_cards"] = board
	state["shoe"] = _card_array(draw.get("shoe", []))


func _all_actor_ids(state: Dictionary) -> Array:
	var result: Array = [PLAYER_ID]
	for member_id in _string_array(state.get("members", [])):
		result.append(member_id)
	return result


func _actors_who_can_act(state: Dictionary) -> Array:
	var result: Array = []
	for actor in _active_actor_ids(state):
		if _actor_can_act(state, str(actor)):
			result.append(str(actor))
	return result


func _actor_can_act(state: Dictionary, actor: String) -> bool:
	if not _actor_active(state, actor):
		return false
	if actor == PLAYER_ID:
		return not bool(state.get("player_all_in", false)) and int(state.get("player_stack", 0)) > 0
	var index := _seat_index(state, actor)
	return index >= 0 and not bool((state.get("seats", []) as Array)[index].get("all_in", false)) and int((state.get("seats", []) as Array)[index].get("stack", 0)) > 0


func _first_actor_who_can_act(state: Dictionary, order: Array) -> String:
	for actor in order:
		if _actor_can_act(state, str(actor)):
			return str(actor)
	return ""


func _commit_actor_chips(state: Dictionary, actor: String, wanted: int) -> int:
	if actor == PLAYER_ID:
		var amount := mini(maxi(0, wanted), int(state.get("player_stack", 0)))
		var rounds: Dictionary = state.get("round_contributions", {}) if typeof(state.get("round_contributions", {})) == TYPE_DICTIONARY else {}
		rounds[PLAYER_ID] = int(rounds.get(PLAYER_ID, 0)) + amount
		state["round_contributions"] = rounds
		state["player_stack"] = int(state.get("player_stack", 0)) - amount
		state["player_contribution"] = int(state.get("player_contribution", 0)) + amount
		state["player_all_in"] = int(state.get("player_stack", 0)) == 0
		state["pot"] = int(state.get("pot", 0)) + amount
		state["current_bet"] = maxi(int(state.get("current_bet", 0)), int(rounds.get(PLAYER_ID, 0)))
		return amount
	var index := _seat_index(state, actor)
	if index < 0:
		return 0
	var seats: Array = state.get("seats", [])
	var seat: Dictionary = seats[index]
	var npc_amount := mini(maxi(0, wanted), int(seat.get("stack", 0)))
	seat["stack"] = int(seat.get("stack", 0)) - npc_amount
	seat["contribution"] = int(seat.get("contribution", 0)) + npc_amount
	seat["round_contribution"] = int(seat.get("round_contribution", 0)) + npc_amount
	seat["all_in"] = int(seat.get("stack", 0)) == 0
	seat["last_action"] = "big blind" if wanted == int(CrewPokerModelScript.config().get("big_blind", 2)) else "small blind"
	seats[index] = seat
	state["seats"] = seats
	state["pot"] = int(state.get("pot", 0)) + npc_amount
	state["current_bet"] = maxi(int(state.get("current_bet", 0)), int(seat.get("round_contribution", 0)))
	return 0


func _award_npc_stack(state: Dictionary, actor: String, amount: int) -> void:
	var index := _seat_index(state, actor)
	if index < 0:
		return
	var seats: Array = state.get("seats", [])
	var seat: Dictionary = seats[index]
	seat["stack"] = int(seat.get("stack", 0)) + maxi(0, amount)
	seats[index] = seat
	state["seats"] = seats


func _player_forced_blind(state: Dictionary) -> int:
	var actors := _all_actor_ids(state)
	if actors.size() < 2:
		return 0
	var button := int(state.get("button_index", 0)) % actors.size()
	var tuning := CrewPokerModelScript.config()
	if str(actors[(button + 1) % actors.size()]) == PLAYER_ID:
		return int(tuning.get("small_blind", 1))
	if str(actors[(button + 2) % actors.size()]) == PLAYER_ID:
		return int(tuning.get("big_blind", 2))
	return 0


func _record_ordered_action(state: Dictionary, actor: String, action: String, amount: int, raised: bool, intent: String = "") -> void:
	var acted := _string_array(state.get("acted_since_raise", []))
	if raised:
		acted = [actor]
	elif not acted.has(actor):
		acted.append(actor)
	state["acted_since_raise"] = acted
	var phase := str(state.get("phase", ""))
	var history := _dict_array(state.get("action_history", []))
	var record := {"ordinal": int(state.get("action_ordinal", 0)), "phase": phase, "actor": actor, "action": action, "amount": amount, "pot_after": int(state.get("pot", 0)), "current_bet": int(state.get("current_bet", 0)), "raised": raised}
	if actor != PLAYER_ID and not intent.is_empty():
		record["intent"] = intent
	history.append(record)
	while history.size() > 40:
		history.pop_front()
	state["action_history"] = history
	var memory := derive_public_session_memory(history, int(state.get("session_swing", 0)))
	memory.erase("table")
	state["session_memory"] = memory
	_update_hand_lines(state, actor, action, raised)
	if actor == PLAYER_ID:
		_update_player_reads_from_action(state, action, amount)
	# A host command must authenticate the new public memory before it can drive
	# another NPC policy decision.
	state["public_memory_receipt_id"] = ""


static func derive_public_session_memory(action_history_value: Variant, session_swing: int) -> Dictionary:
	var result: Dictionary = {"table": {"raises": 0, "folds": 0, "session_swing": session_swing}}
	if typeof(action_history_value) != TYPE_ARRAY:
		return result
	var history: Array = action_history_value
	var start := maxi(0, history.size() - 40)
	for index in range(start, history.size()):
		if typeof(history[index]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = history[index]
		var actor := str(row.get("actor", ""))
		var action := str(row.get("action", ""))
		if actor.is_empty() or not ["ante", "check", "call", "bet", "raise", "all_in", "fold", "draw"].has(action):
			continue
		var actor_memory: Dictionary = result.get(actor, {}) if typeof(result.get(actor, {})) == TYPE_DICTIONARY else {}
		actor_memory["raises"] = int(actor_memory.get("raises", 0)) + (1 if action in ["bet", "raise", "all_in"] else 0)
		actor_memory["folds"] = int(actor_memory.get("folds", 0)) + (1 if action == "fold" else 0)
		actor_memory["last_action"] = action
		result[actor] = actor_memory
		var table: Dictionary = result["table"]
		table["raises"] = int(table.get("raises", 0)) + (1 if action in ["bet", "raise", "all_in"] else 0)
		table["folds"] = int(table.get("folds", 0)) + (1 if action == "fold" else 0)
		result["table"] = table
	return result


static func _neutral_hand_lines() -> Dictionary:
	return {"preflop_aggressor": "", "last_bettor_by_street": {}, "checked_by_street": {}}


static func _neutral_player_reads() -> Dictionary:
	return {"actions": 0, "faced_bets": 0, "folds_to_bets": 0, "raises": 0, "checks": 0, "showdowns": 0, "shown_bluffs": 0, "signals": 0}


static func _neutral_temperament(members: Array) -> Dictionary:
	var result := {}
	for member_value in members:
		result[str(member_value)] = {"tilt_level": 0, "tilt_hands": 0, "win_streak": 0}
	return result


func _update_hand_lines(state: Dictionary, actor: String, action: String, raised: bool) -> void:
	var phase := str(state.get("phase", ""))
	var lines: Dictionary = state.get("hand_lines", {}) if typeof(state.get("hand_lines", {})) == TYPE_DICTIONARY else _neutral_hand_lines()
	if phase == "preflop" and raised:
		lines["preflop_aggressor"] = actor
	if action in ["bet", "raise", "all_in"]:
		var bettors: Dictionary = lines.get("last_bettor_by_street", {}) if typeof(lines.get("last_bettor_by_street", {})) == TYPE_DICTIONARY else {}
		bettors[phase] = actor
		lines["last_bettor_by_street"] = bettors
	if action == "check":
		var checked: Dictionary = lines.get("checked_by_street", {}) if typeof(lines.get("checked_by_street", {})) == TYPE_DICTIONARY else {}
		var actors := _string_array(checked.get(phase, []))
		if not actors.has(actor):
			actors.append(actor)
		checked[phase] = actors
		lines["checked_by_street"] = checked
	state["hand_lines"] = lines


func _update_player_reads_from_action(state: Dictionary, action: String, amount: int) -> void:
	var reads: Dictionary = state.get("player_reads", {}) if typeof(state.get("player_reads", {})) == TYPE_DICTIONARY else _neutral_player_reads()
	reads["actions"] = mini(200, int(reads.get("actions", 0)) + 1)
	if action in ["raise", "all_in"]:
		reads["raises"] = mini(200, int(reads.get("raises", 0)) + 1)
	if action == "check":
		reads["checks"] = mini(200, int(reads.get("checks", 0)) + 1)
	if action == "fold" or action == "call" and amount > 0:
		reads["faced_bets"] = mini(200, int(reads.get("faced_bets", 0)) + 1)
		if action == "fold":
			reads["folds_to_bets"] = mini(200, int(reads.get("folds_to_bets", 0)) + 1)
	state["player_reads"] = reads


func _player_read_rates(state: Dictionary) -> Dictionary:
	var reads: Dictionary = state.get("player_reads", {}) if typeof(state.get("player_reads", {})) == TYPE_DICTIONARY else _neutral_player_reads()
	return {
		"fold_rate": float(reads.get("folds_to_bets", 0)) / float(maxi(1, int(reads.get("faced_bets", 0)))),
		"raise_rate": float(reads.get("raises", 0)) / float(maxi(1, int(reads.get("actions", 0)))),
		"shown_bluff_rate": float(reads.get("shown_bluffs", 0)) / float(maxi(1, int(reads.get("showdowns", 0)))),
	}


func _observed_fold_rate(state: Dictionary) -> float:
	var folds := 0
	var faced_actions := 0
	for row_value in _dict_array(state.get("action_history", [])):
		var row: Dictionary = row_value
		var action := str(row.get("action", ""))
		if action in ["fold", "call", "raise", "all_in"] and int(row.get("current_bet", 0)) > 0:
			faced_actions += 1
			folds += 1 if action == "fold" else 0
	return 0.30 if faced_actions == 0 else float(folds) / float(faced_actions)


func _decay_temperament(state: Dictionary) -> void:
	var source: Dictionary = state.get("seat_temperament", {}) if typeof(state.get("seat_temperament", {})) == TYPE_DICTIONARY else {}
	var result := _neutral_temperament(_string_array(state.get("members", [])))
	for member_id in result.keys():
		var mood: Dictionary = source.get(member_id, {}) if typeof(source.get(member_id, {})) == TYPE_DICTIONARY else {}
		var hands_left := maxi(0, int(mood.get("tilt_hands", 0)) - 1)
		result[member_id] = {
			"tilt_hands": hands_left,
			"tilt_level": maxi(0, int(mood.get("tilt_level", 0)) - (34 if hands_left > 0 else 100)),
			"win_streak": clampi(int(mood.get("win_streak", 0)), 0, 5),
		}
	state["seat_temperament"] = result


func _update_temperament_after_hand(state: Dictionary, awards: Dictionary) -> void:
	var moods: Dictionary = state.get("seat_temperament", {}) if typeof(state.get("seat_temperament", {})) == TYPE_DICTIONARY else _neutral_temperament(_string_array(state.get("members", [])))
	var big_blind := maxi(1, int(CrewPokerModelScript.config().get("big_blind", 2)))
	for seat_value in _dict_array(state.get("seats", [])):
		var seat: Dictionary = seat_value
		var member_id := str(seat.get("member_id", ""))
		var mood: Dictionary = moods.get(member_id, {"tilt_level": 0, "tilt_hands": 0, "win_streak": 0})
		var start_stack := int(seat.get("starting_stack", int(seat.get("stack", 0)) + int(seat.get("contribution", 0))))
		var finish_stack := int(seat.get("stack", 0))
		var net := finish_stack - start_stack
		if net <= -big_blind * 4:
			var authored_tilt := int(CrewPokerModelScript.policy(member_id).get("tilt", 50))
			mood["tilt_level"] = maxi(int(mood.get("tilt_level", 0)), authored_tilt)
			mood["tilt_hands"] = 3
			mood["win_streak"] = 0
		elif net > 0 or int(awards.get(member_id, 0)) > 0:
			mood["win_streak"] = mini(5, int(mood.get("win_streak", 0)) + 1)
		else:
			mood["win_streak"] = 0
		moods[member_id] = mood
	state["seat_temperament"] = moods


func _public_action_history(value: Variant) -> Array:
	var result: Array = []
	for row_value in _dict_array(value):
		var row := (row_value as Dictionary).duplicate(true)
		for private_key in ["intent", "equity", "draw_outs", "decision_msec"]:
			row.erase(private_key)
		result.append(row)
	return result


func _adaptive_npc_action(member_id: String, cards: Array, phase: String, facing_raise: bool, public_memory: Dictionary, rng: RngStream) -> String:
	var profile := CrewPokerModelScript.policy(member_id)
	var score := CrewPokerModelScript.evaluate_hand(cards)
	var category := int(score.get("category", 0))
	var strength := category * 12 + clampi(int(score.get("high", 0)) - 8, 0, 6)
	var table: Dictionary = public_memory.get("table", {}) if typeof(public_memory.get("table", {})) == TYPE_DICTIONARY else {}
	var player: Dictionary = public_memory.get(PLAYER_ID, {}) if typeof(public_memory.get(PLAYER_ID, {})) == TYPE_DICTIONARY else {}
	var self_memory: Dictionary = public_memory.get(member_id, {}) if typeof(public_memory.get(member_id, {})) == TYPE_DICTIONARY else {}
	# These bounded deltas consume only the authenticated public action ledger.
	# Each authored profile retains its distinct base policy and the one-roll RNG contract.
	var pressure := clampi(int(table.get("raises", 0)) + int(player.get("raises", 0)) - int(self_memory.get("raises", 0)), -3, 6)
	var swing_pressure := clampi(abs(int(table.get("session_swing", 0))) / 10, 0, 6)
	var tightness := clampi(int(profile.get("tightness", 50)) + pressure * 2, 1, 99)
	var aggression := clampi(int(profile.get("aggression", 50)) + int(self_memory.get("folds", 0)) * 2 - pressure + swing_pressure, 1, 99)
	var bluff := clampi(int(profile.get("bluff", 20)) + int(player.get("folds", 0)) * 3 - pressure, 0, 99)
	var roll: int = rng.randi_range(1, 100)
	if facing_raise and category == 0 and roll <= clampi(tightness - 25, 8, 72):
		return "fold"
	var raise_chance := clampi(int(float(aggression) / 3.0) + strength + (int(float(bluff) / 2.0) if category == 0 else 0) - (10 if phase == "before" else 0), 4, 88)
	if roll <= raise_chance:
		return "raise"
	if facing_raise and roll >= clampi(118 - tightness + strength, 30, 94):
		return "fold"
	return "call"


func _active_actor_ids(state: Dictionary) -> Array:
	var result: Array = []
	if bool(state.get("player_active", true)):
		result.append(PLAYER_ID)
	for seat in _dict_array(state.get("seats", [])):
		if bool(seat.get("active", false)):
			result.append(str(seat.get("member_id", "")))
	return result


func _actor_active(state: Dictionary, actor: String) -> bool:
	return bool(state.get("player_active", true)) if actor == PLAYER_ID else _seat_active(_dict_array(state.get("seats", [])), actor)


func _actor_round_contribution(state: Dictionary, actor: String) -> int:
	if actor == PLAYER_ID:
		var rounds: Dictionary = state.get("round_contributions", {}) if typeof(state.get("round_contributions", {})) == TYPE_DICTIONARY else {}
		return int(rounds.get(PLAYER_ID, 0))
	var index := _seat_index(state, actor)
	return int((state.get("seats", []) as Array)[index].get("round_contribution", 0)) if index >= 0 else 0


func _seat_index(state: Dictionary, member_id: String) -> int:
	var seats: Array = state.get("seats", []) if typeof(state.get("seats", [])) == TYPE_ARRAY else []
	for index in range(seats.size()):
		if str((seats[index] as Dictionary).get("member_id", "")) == member_id:
			return index
	return -1


func _actor_name(actor: String) -> String:
	return "You" if actor == PLAYER_ID else str(MEMBER_NAMES.get(actor, actor))


func _ordered_public_facts(state: Dictionary, action_id: String) -> Array:
	var boundary := "crew-poker:%d:%d" % [int(state.get("session_index", 0)), int(state.get("action_ordinal", 0))]
	var fact := {"fact_id": "%s:%s" % [boundary, action_id], "fact_type": "crew_poker.action_boundary", "fact_version": 1, "visibility": "public", "boundary": boundary, "cause": "action_resolution", "receipt_key": "%s:%s" % [boundary, action_id], "payload": {"night_id": str(state.get("night_id", "friendly_teaching")), "phase": str(state.get("phase", "idle")), "turn_owner": str(state.get("turn_owner", "")), "pot": int(state.get("pot", 0))}}
	fact["content_fingerprint"] = _canonical_ritual_json(fact).sha256_text()
	return [fact]


func _canonical_ritual_json(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var keys := _string_array(source.keys())
		keys.sort()
		var members: Array[String] = []
		for key in keys:
			members.append("%s:%s" % [JSON.stringify(key), _canonical_ritual_json(source.get(key))])
		return "{%s}" % ",".join(members)
	if typeof(value) == TYPE_ARRAY:
		var items: Array[String] = []
		for item in value:
			items.append(_canonical_ritual_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _build_presentation_animation(before: Dictionary, after: Dictionary, action_id: String, ui_state: Dictionary) -> Dictionary:
	if str(after.get("turn_engine", "legacy_v1")) != ORDERED_ENGINE:
		return {}
	var timing := _animation_tuning()
	var cards: Array = []
	var chips: Array = []
	var payout: Array = []
	var card_end := 0
	var chip_end := 0
	var payout_end := 0
	var before_phase := str(before.get("phase", "idle"))
	var after_phase := str(after.get("phase", "idle"))
	var card_flight := int(timing.get("card_flight_msec", 260))
	var stagger := int(timing.get("per_card_stagger_msec", 110))
	var deck_rect: Rect2 = DEALER_STATION_LAYOUT.get("deck_card_rect", Rect2())
	var muck_rect: Rect2 = DEALER_STATION_LAYOUT.get("muck_rect", Rect2())
	var collect_end := 0
	if action_id == "deal":
		var collect_duration := int(timing.get("collect_msec", 220))
		_append_collection_events(cards, before, deck_rect.position, collect_duration)
		collect_end = collect_duration + int(timing.get("shuffle_msec", 240))
		var actors := _all_actor_ids(after)
		var first_actor := str(after.get("small_blind_actor", ""))
		var first_index := actors.find(first_actor)
		for pass_index in range(2):
			for offset in range(actors.size()):
				var actor := str(actors[(first_index + offset) % actors.size()])
				var card_index := pass_index
				var card: Dictionary = HIDDEN_CARD
				if actor == PLAYER_ID:
					var player_cards := _card_array(after.get("player_cards", []))
					if card_index < player_cards.size():
						card = player_cards[card_index]
				var target := _actor_card_rect(after, actor, card_index)
				var delay := collect_end + (pass_index * actors.size() + offset) * stagger
				cards.append(_card_flight_event("deal", actor, card_index, card, deck_rect.position, target.position, deck_rect.size, target.size, delay, card_flight, actor == PLAYER_ID))
				card_end = maxi(card_end, delay + card_flight)
		for blind_actor in [str(after.get("small_blind_actor", "")), str(after.get("big_blind_actor", ""))]:
			var amount := _actor_round_contribution(after, blind_actor)
			if amount > 0:
				chips.append(_chip_flight_event("place", blind_actor, amount, _actor_chip_source(after, blind_actor), _actor_bet_center(after, blind_actor), collect_duration / 2, int(timing.get("chip_slide_msec", 260))))
				chip_end = maxi(chip_end, collect_duration / 2 + int(timing.get("chip_slide_msec", 260)))
	else:
		_append_fold_events(cards, before, after, muck_rect.position, timing)
		for card_event in cards:
			card_end = maxi(card_end, int((card_event as Dictionary).get("delay_msec", 0)) + int((card_event as Dictionary).get("duration_msec", 0)))
		_append_placed_chip_events(chips, before, after, timing)
		for chip_event in chips:
			chip_end = maxi(chip_end, int((chip_event as Dictionary).get("delay_msec", 0)) + int((chip_event as Dictionary).get("duration_msec", 0)))
		var street_changed := before_phase in ["preflop", "flop", "turn", "river"] and after_phase != before_phase
		var board_delay := 0
		if street_changed:
			var sweep_duration := int(timing.get("pot_sweep_msec", 360))
			_append_sweep_events(chips, before, sweep_duration)
			chip_end = maxi(chip_end, sweep_duration)
			board_delay = mini(sweep_duration, 150)
		var before_board := _card_array(before.get("community_cards", []))
		var after_board := _card_array(after.get("community_cards", []))
		for board_index in range(before_board.size(), after_board.size()):
			if board_index in [0, 3, 4]:
				cards.append(_card_flight_event("burn", "muck", board_index, HIDDEN_CARD, deck_rect.position, muck_rect.position, deck_rect.size, Vector2(24, 35), board_delay, card_flight, false))
				board_delay += stagger
			var board_target := _board_card_rect(board_index)
			cards.append(_card_flight_event("board", "board", board_index, after_board[board_index], deck_rect.position, board_target.position, deck_rect.size, board_target.size, board_delay, card_flight + int(timing.get("board_flip_msec", 180)), true))
			card_end = maxi(card_end, board_delay + card_flight + int(timing.get("board_flip_msec", 180)))
			board_delay += stagger
		var last: Dictionary = after.get("last_result", {}) if typeof(after.get("last_result", {})) == TYPE_DICTIONARY else {}
		var settlement := after_phase == "idle" and not last.is_empty() and int(after.get("hand_number", 0)) > int(before.get("hand_number", 0))
		if settlement:
			var flip_delay := card_end
			var showdown_stagger := int(timing.get("showdown_stagger_msec", 100))
			var flip_duration := int(timing.get("showdown_flip_msec", 180))
			for seat_value in _dict_array(after.get("seats", [])):
				var seat: Dictionary = seat_value
				if not bool(seat.get("revealed", false)):
					continue
				var actor := str(seat.get("member_id", ""))
				var hole := _card_array(seat.get("cards", []))
				for card_index in range(mini(2, hole.size())):
					var target := _actor_card_rect(after, actor, card_index)
					cards.append(_card_flight_event("showdown_flip", actor, card_index, hole[card_index], target.position, target.position, target.size, target.size, flip_delay, flip_duration, true))
					flip_delay += showdown_stagger
			card_end = maxi(card_end, flip_delay + flip_duration)
			var awards: Dictionary = last.get("awards", {}) if typeof(last.get("awards", {})) == TYPE_DICTIONARY else {}
			var payout_delay := card_end
			for winner_value in _string_array(last.get("winners", [])):
				var winner := str(winner_value)
				var amount := int(awards.get(winner, int(last.get("table_payout", 0)) if winner == PLAYER_ID else 0))
				if amount > 0:
					payout.append(_chip_flight_event("payout", winner, amount, DEALER_STATION_LAYOUT.get("pot_center", Vector2.ZERO), _actor_chip_source(after, winner), payout_delay, int(timing.get("payout_msec", 620))))
					payout_end = maxi(payout_end, payout_delay + int(timing.get("payout_msec", 620)))
	if cards.is_empty() and chips.is_empty() and payout.is_empty() and action_id != "deal":
		return {}
	var started := int(ui_state.get("surface_presentation_time_msec", ui_state.get("surface_time_msec", 0)))
	var session := int(after.get("session_index", 0))
	var hand := int(before.get("hand_number", after.get("hand_number", 0)))
	var ordinal := int(after.get("action_ordinal", 0))
	var identity := "%d:%d:%d" % [session, hand, ordinal]
	return {
		"kind": action_id,
		"started_msec": started,
		"card_id": "crew_poker_cards:%s" % identity if not cards.is_empty() or action_id == "deal" else "",
		"card_duration_msec": maxi(card_end, collect_end if action_id == "deal" else 0),
		"card_events": cards,
		"chip_id": "crew_poker_chips:%s" % identity if not chips.is_empty() else "",
		"chip_duration_msec": chip_end,
		"chip_events": chips,
		"payout_id": "crew_poker_payout:%s" % identity if not payout.is_empty() else "",
		"payout_duration_msec": payout_end,
		"payout_events": payout,
		"showdown": after_phase == "idle" and int(after.get("hand_number", 0)) > int(before.get("hand_number", 0)),
	}


func _presentation_state_snapshot(state: Dictionary) -> Dictionary:
	# Animation comparisons need a small immutable ledger, not the authoritative
	# shoe, history, observations, ritual memory, or other live-hand payloads.
	var seats: Array = []
	for seat_value in _dict_array(state.get("seats", [])):
		var seat: Dictionary = seat_value
		seats.append({
			"member_id": str(seat.get("member_id", "")),
			"cards": _card_array(seat.get("cards", [])),
			"active": bool(seat.get("active", false)),
			"revealed": bool(seat.get("revealed", false)),
			"stack": int(seat.get("stack", 0)),
			"contribution": int(seat.get("contribution", 0)),
			"round_contribution": int(seat.get("round_contribution", 0)),
			"all_in": bool(seat.get("all_in", false)),
		})
	return {
		"turn_engine": str(state.get("turn_engine", "legacy_v1")),
		"phase": str(state.get("phase", "idle")),
		"session_index": int(state.get("session_index", 0)),
		"hand_number": int(state.get("hand_number", 0)),
		"action_ordinal": int(state.get("action_ordinal", 0)),
		"members": _string_array(state.get("members", [])),
		"small_blind_actor": str(state.get("small_blind_actor", "")),
		"big_blind_actor": str(state.get("big_blind_actor", "")),
		"player_active": bool(state.get("player_active", true)),
		"player_cards": _card_array(state.get("player_cards", [])),
		"community_cards": _card_array(state.get("community_cards", [])),
		"round_contributions": _poker_dict(state.get("round_contributions", {})),
		"seats": seats,
	}


func _animation_tuning() -> Dictionary:
	var value: Variant = CrewPokerModelScript.config().get("animation", {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _append_collection_events(events: Array, state: Dictionary, deck_position: Vector2, duration_msec: int) -> void:
	var player_cards := _card_array(state.get("player_cards", []))
	for index in range(player_cards.size()):
		var source := _actor_card_rect(state, PLAYER_ID, index)
		events.append(_card_flight_event("collect", PLAYER_ID, index, player_cards[index], source.position, deck_position, source.size, Vector2(24, 35), 0, duration_msec, false))
	for seat_value in _dict_array(state.get("seats", [])):
		var seat: Dictionary = seat_value
		var actor := str(seat.get("member_id", ""))
		var hole := _card_array(seat.get("cards", []))
		for index in range(mini(2, hole.size())):
			var source := _actor_card_rect(state, actor, index)
			events.append(_card_flight_event("collect", actor, index, HIDDEN_CARD, source.position, deck_position, source.size, Vector2(24, 35), 0, duration_msec, false))
	var board := _card_array(state.get("community_cards", []))
	for index in range(board.size()):
		var source := _board_card_rect(index)
		events.append(_card_flight_event("collect", "board", index, board[index], source.position, deck_position, source.size, Vector2(24, 35), 0, duration_msec, false))


func _append_fold_events(events: Array, before: Dictionary, after: Dictionary, muck_position: Vector2, timing: Dictionary) -> void:
	var duration := int(timing.get("fold_msec", 300))
	if bool(before.get("player_active", true)) and not bool(after.get("player_active", true)):
		for index in range(mini(2, _card_array(before.get("player_cards", [])).size())):
			var source := _actor_card_rect(before, PLAYER_ID, index)
			events.append(_card_flight_event("fold", PLAYER_ID, index, HIDDEN_CARD, source.position, muck_position, source.size, Vector2(24, 35), index * 45, duration, false))
	var before_seats := _dict_array(before.get("seats", []))
	for before_seat_value in before_seats:
		var before_seat: Dictionary = before_seat_value
		var actor := str(before_seat.get("member_id", ""))
		var after_index := _seat_index(after, actor)
		if after_index < 0 or not bool(before_seat.get("active", false)) or bool((after.get("seats", []) as Array)[after_index].get("active", false)):
			continue
		for index in range(mini(2, _card_array(before_seat.get("cards", [])).size())):
			var source := _actor_card_rect(before, actor, index)
			events.append(_card_flight_event("fold", actor, index, HIDDEN_CARD, source.position, muck_position, source.size, Vector2(24, 35), index * 45, duration, false))


func _append_placed_chip_events(events: Array, before: Dictionary, after: Dictionary, timing: Dictionary) -> void:
	var duration := int(timing.get("chip_slide_msec", 260))
	for actor_value in _all_actor_ids(after):
		var actor := str(actor_value)
		var delta := _actor_round_contribution(after, actor) - _actor_round_contribution(before, actor)
		if delta > 0:
			events.append(_chip_flight_event("place", actor, delta, _actor_chip_source(after, actor), _actor_bet_center(after, actor), 0, duration))


func _append_sweep_events(events: Array, before: Dictionary, duration_msec: int) -> void:
	for actor_value in _all_actor_ids(before):
		var actor := str(actor_value)
		var amount := _actor_round_contribution(before, actor)
		if amount > 0:
			events.append(_chip_flight_event("sweep", actor, amount, _actor_bet_center(before, actor), DEALER_STATION_LAYOUT.get("pot_center", Vector2.ZERO), 0, duration_msec))


func _card_flight_event(kind: String, actor: String, card_index: int, card_value: Variant, from_position: Vector2, to_position: Vector2, from_size: Vector2, to_size: Vector2, delay_msec: int, duration_msec: int, reveal_on_land: bool) -> Dictionary:
	var card: Dictionary = (card_value as Dictionary).duplicate(true) if typeof(card_value) == TYPE_DICTIONARY else HIDDEN_CARD.duplicate()
	return {"kind": kind, "actor": actor, "card_index": card_index, "card": card, "from": [from_position.x, from_position.y], "to": [to_position.x, to_position.y], "from_size": [from_size.x, from_size.y], "to_size": [to_size.x, to_size.y], "delay_msec": maxi(0, delay_msec), "duration_msec": maxi(1, duration_msec), "reveal_on_land": reveal_on_land}


func _chip_flight_event(kind: String, actor: String, amount: int, from_position: Vector2, to_position: Vector2, delay_msec: int, duration_msec: int) -> Dictionary:
	return {"kind": kind, "actor": actor, "amount": maxi(0, amount), "from": [from_position.x, from_position.y], "to": [to_position.x, to_position.y], "delay_msec": maxi(0, delay_msec), "duration_msec": maxi(1, duration_msec)}


func _actor_card_rect(state: Dictionary, actor: String, card_index: int) -> Rect2:
	if actor == PLAYER_ID:
		return Rect2(Vector2(385, 245) + Vector2(card_index * 68, 0), Vector2(58, 81))
	var seat_index := _seat_index(state, actor)
	var count := mini(MAX_OPPONENT_SEATS, maxi(_dict_array(state.get("seats", [])).size(), _string_array(state.get("members", [])).size()))
	var indices := _seat_layout_indices(maxi(1, count))
	var layout: Dictionary = SEAT_LAYOUT[int(indices[clampi(seat_index, 0, indices.size() - 1)])]
	return Rect2((layout.get("hole_card_origin", Vector2.ZERO) as Vector2) + Vector2(card_index * 27, 0), Vector2(24, 35))


func _board_card_rect(card_index: int) -> Rect2:
	return Rect2(Vector2(305, 158) + Vector2(card_index * 59, 0), Vector2(50, 70))


func _actor_bet_center(state: Dictionary, actor: String) -> Vector2:
	if actor == PLAYER_ID:
		return Vector2(350, 280)
	var seat_index := _seat_index(state, actor)
	var indices := _seat_layout_indices(maxi(1, mini(MAX_OPPONENT_SEATS, _dict_array(state.get("seats", [])).size())))
	return SEAT_LAYOUT[int(indices[clampi(seat_index, 0, indices.size() - 1)])].get("bet_chip_center", Vector2.ZERO)


func _actor_chip_source(state: Dictionary, actor: String) -> Vector2:
	if actor == PLAYER_ID:
		return Vector2(326, 318)
	var seat_index := _seat_index(state, actor)
	var indices := _seat_layout_indices(maxi(1, mini(MAX_OPPONENT_SEATS, _dict_array(state.get("seats", [])).size())))
	return SEAT_LAYOUT[int(indices[clampi(seat_index, 0, indices.size() - 1)])].get("character_foot", Vector2.ZERO)


func _event_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "crew_draw_poker":
		return false
	surface.surface_begin_design_space(surface.surface_board_size())
	_prepare_animation_draw_cache(state)
	_draw_room(surface, state)
	_draw_dealer_station(surface, state)
	_draw_seats(surface, state)
	_draw_shared_board(surface, state)
	_draw_betting_chips(surface, state)
	_draw_player(surface, state)
	_draw_card_flights(surface, state)
	_draw_chip_flights(surface, state)
	if not bool(state.get("raise_panel_open", false)):
		_draw_observation(surface, state)
	_draw_controls(surface, state)
	surface.surface_end_design_space()
	return true


func surface_motion_signature(surface, state: Dictionary) -> Dictionary:
	# The lamp is the table's deliberately small idle motion. This signature lets
	# the shared liveness probe verify the renderer itself moves, and that the
	# accessibility freeze is not merely stopping redraw scheduling.
	var phase := float(surface.surface_flicker()) if surface != null and surface.has_method("surface_flicker") else 0.0
	var dealer_phase := sin(phase * 1.13 + float(str(state.get("dealer_member_id", "")).hash() % 17))
	return {
		"renderer": str(state.get("surface_renderer", "")),
		"lamp_alpha_milli": int(round((0.50 + sin(phase * 1.7) * 0.08) * 1000.0)),
		"dealer_shuffle_milli": int(round(dealer_phase * 1000.0)),
	}


func _prepare_animation_draw_cache(state: Dictionary) -> void:
	var card_id := str(state.get("card_animation_id", ""))
	if card_id != draw_card_events_cache_id:
		draw_card_events_cache_id = card_id
		draw_card_events_cache = state.get("card_animation_events", []) if typeof(state.get("card_animation_events", [])) == TYPE_ARRAY else []
	var chip_identity := "%s|%s" % [str(state.get("chip_animation_id", "")), str(state.get("payout_animation_id", ""))]
	if chip_identity != draw_chip_events_cache_id:
		draw_chip_events_cache_id = chip_identity
		draw_chip_events_cache = []
		if typeof(state.get("chip_animation_events", [])) == TYPE_ARRAY:
			draw_chip_events_cache.append_array(state.get("chip_animation_events", []))
		if typeof(state.get("payout_animation_events", [])) == TYPE_ARRAY:
			draw_chip_events_cache.append_array(state.get("payout_animation_events", []))


func environment_object_state(_run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {"prop": "card_table", "label": "Back-Room Hold'em", "status": "The crew is seated around a live Texas Hold'em table."}


func interrupt_for_room_scenario(_run_state: RunState, environment: Dictionary, disposition: String, reason: String) -> Dictionary:
	# This is deliberately a pure proposal seam. Caller strings never authorize a
	# live table mutation or refund. ScenarioHostTransaction must atomically commit
	# the exact replacement table/account effects; pause/resume remain held until
	# that host integration supplies a real command source.
	var state := _table_state(environment)
	var live := ["before", "draw", "after", "preflop", "flop", "turn", "river", "paused"].has(str(state.get("phase", "idle")))
	if not live or not ["pause", "resume", "abort"].has(disposition):
		return {"ok": false, "authoritative": false, "proposal_only": true, "bankroll_delta": 0, "message": "That interruption boundary is not legal now."}
	return {
		"ok": false,
		"authoritative": false,
		"proposal_only": true,
		"requires_host_transaction": true,
		"authority_gap": "host_room_interrupt_authority_unavailable",
		"bankroll_delta": 0,
		"proposal": {
			"kind": "interruption",
			"producer_id": "poker",
			"game_id": get_id(),
			"table_id": get_id(),
			"disposition": disposition,
			"reason_id": reason.strip_edges(),
			"session_index": int(state.get("session_index", 0)),
			"action_ordinal": int(state.get("action_ordinal", 0)),
			"refund_amount": maxi(0, int(state.get("player_contribution", 0))) if disposition == "abort" else 0,
		},
		"message": "The room host must commit this interruption atomically.",
	}


static func scripted_session(seed: int, member_id: String, force_showdown: bool = true) -> Dictionary:
	# QA helper: every call is independently reproducible and exposes only test
	# facts. Runtime UI never invokes this seam.
	var rng := RngStream.new()
	rng.configure(seed)
	var deck := CardShoeScript.build_shoe(1, rng)
	var first := CardShoeScript.draw_cards(deck, 9)
	var dealt: Array = first.get("cards", [])
	var player: Array = dealt.slice(0, 2)
	var npc: Array = dealt.slice(2, 4)
	var board: Array = dealt.slice(4, 9)
	var action := CrewPokerModelScript.holdem_action(member_id, npc, board.slice(0, 3), "flop", 2, 8, true, {}, 50, rng)
	var player_seven := player.duplicate(true)
	player_seven.append_array(board)
	var npc_seven := npc.duplicate(true)
	npc_seven.append_array(board)
	return {"player": player, "npc": npc, "board": board, "action": action, "showdown": force_showdown, "winner": CrewPokerModelScript.compare_holdem(player_seven, npc_seven)}


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
	var profile := CrewPokerModelScript.policy(member_id)
	var authored := CrewPokerModelScript.surface_pattern(member_id, _card_array(seat.get("cards", [])), action, int(seat.get("draw_count", -1)), rng, str(seat.get("decision_intent", "")), int(profile.get("tell_leak", 50)))
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
	# Legacy tables already own their live observation boundary: the authored
	# pattern is selected from hidden game state here and is learned only after
	# that seat reveals at showdown. Keep that shipped path intact while ordered
	# tables wait for the new host-sealed observation authority below.
	if str(state.get("turn_engine", "legacy_v1")) != ORDERED_ENGINE:
		var legacy_shown: Array = state.get("x", [])
		if not legacy_shown.has(neutral):
			legacy_shown.append(neutral)
		state["x"] = legacy_shown
		return
	var queue := _dict_array(state.get("observation_queue", []))
	var source_ordinal := int(state.get("action_ordinal", 0))
	var source_record := _source_action_record(state, member_id, action, source_ordinal)
	if source_record.is_empty():
		return
	var observation_id := "%s:%d:%s:%d" % [member_id, source_ordinal, action, queue.size()]
	queue.append({
		"id": observation_id,
		"m": member_id,
		"i": authored_index,
		"source_action": action,
		"source_record": source_record,
		"source_host_receipt_id": "",
		"start_ordinal": source_ordinal,
		"duration_actions": OBSERVATION_DURATION_ACTIONS,
		"channel": str(authored.get("channel", "posture")),
		"consumed": false,
		"verified": false,
	})
	state["observation_queue"] = queue
	var shown: Array = state.get("x", [])
	if not shown.has(neutral):
		shown.append(neutral)
	state["x"] = shown


func _showdown(state: Dictionary, run_state: RunState) -> Dictionary:
	var contenders: Array = []
	var board := _card_array(state.get("community_cards", []))
	if bool(state.get("player_active", true)):
		var player_seven := _card_array(state.get("player_cards", []))
		player_seven.append_array(board)
		contenders.append({"id": PLAYER_ID, "cards": player_seven})
	var seats: Array = state.get("seats", [])
	for index in range(seats.size()):
		var seat: Dictionary = seats[index]
		if bool(seat.get("active", false)):
			seat["revealed"] = true
			var seven := _card_array(seat.get("cards", []))
			seven.append_array(board)
			contenders.append({"id": str(seat.get("member_id", "")), "cards": seven})
		seats[index] = seat
	state["seats"] = seats
	var settlement := _settle_holdem_pots(state, contenders) if str(state.get("turn_engine", "legacy_v1")) == ORDERED_ENGINE else _settle_legacy_pot(state, contenders)
	var winners := _string_array(settlement.get("winners", []))
	var awards: Dictionary = settlement.get("awards", {}) if typeof(settlement.get("awards", {})) == TYPE_DICTIONARY else {}
	var raw_payout := int(awards.get(PLAYER_ID, 0))
	var payout := mini(raw_payout, _win_room(state, raw_payout))
	state["session_swing"] = int(state.get("session_swing", 0)) + payout
	state["player_stack"] = int(state.get("player_stack", 0)) + raw_payout
	for actor in awards.keys():
		if str(actor) == PLAYER_ID:
			continue
		var award_index := _seat_index(state, str(actor))
		if award_index >= 0:
			var award_seats: Array = state.get("seats", [])
			var award_seat: Dictionary = award_seats[award_index]
			award_seat["stack"] = int(award_seat.get("stack", 0)) + int(awards.get(actor, 0))
			award_seats[award_index] = award_seat
			state["seats"] = award_seats
	if str(state.get("turn_engine", "legacy_v1")) != ORDERED_ENGINE:
		for shown_value in _dict_array(state.get("x", [])):
			var legacy_shown: Dictionary = shown_value
			var legacy_member := str(legacy_shown.get("m", ""))
			var legacy_patterns := CrewPokerModelScript.patterns(legacy_member)
			var legacy_index := int(legacy_shown.get("i", -1))
			if legacy_index >= 0 and legacy_index < legacy_patterns.size() and (winners.has(legacy_member) or _seat_active(seats, legacy_member)):
				run_state.crew_record_pattern(legacy_member, str((legacy_patterns[legacy_index] as Dictionary).get("state_key", "")))
	var verified_receipts := _string_array(state.get("verified_observation_receipts", []))
	var queue := _dict_array(state.get("observation_queue", []))
	var authority_gaps: Array = []
	for queue_index in range(queue.size()):
		var shown: Dictionary = queue[queue_index]
		var shown_member := str(shown.get("m", ""))
		var shown_patterns := CrewPokerModelScript.patterns(shown_member)
		var shown_index := int(shown.get("i", -1))
		var verification_receipt := "tell-verify:%s" % str(shown.get("id", ""))
		if not bool(state.get("player_folded_hidden", false)) and _observation_provenance_valid(state, seats, shown, shown_patterns, run_state) and not verified_receipts.has(verification_receipt):
			# The host transaction already applied the exactly-once tell delta. This
			# model only acknowledges its sealed observation receipt; it never applies
			# a second authority from restored queue data.
			verified_receipts.append(verification_receipt)
			shown["verified"] = true
			shown["verification_receipt"] = verification_receipt
		queue[queue_index] = shown
	state["observation_queue"] = queue
	state["verified_observation_receipts"] = verified_receipts
	if not queue.is_empty() and not bool(state.get("player_folded_hidden", false)):
		authority_gaps.append("host_tell_observation_authority_unavailable")
	var player_cards := _card_array(state.get("player_cards", []))
	player_cards.append_array(board)
	var player_score := CrewPokerModelScript.evaluate_best_hand(player_cards) if bool(state.get("player_active", true)) else {}
	if bool(state.get("player_active", true)):
		var reads: Dictionary = state.get("player_reads", {}) if typeof(state.get("player_reads", {})) == TYPE_DICTIONARY else _neutral_player_reads()
		reads["showdowns"] = mini(200, int(reads.get("showdowns", 0)) + 1)
		var player_aggressed := false
		for row_value in _dict_array(state.get("action_history", [])):
			var row: Dictionary = row_value
			if str(row.get("actor", "")) == PLAYER_ID and str(row.get("action", "")) in ["raise", "all_in"]:
				player_aggressed = true
		if player_aggressed and int(player_score.get("category", 0)) == 0:
			reads["shown_bluffs"] = mini(200, int(reads.get("shown_bluffs", 0)) + 1)
		state["player_reads"] = reads
	_update_player_tell_reputation(state, int(player_score.get("category", 0)), winners.has(PLAYER_ID))
	var hand_label := str(player_score.get("label", "Hand")) if bool(state.get("player_active", true)) else "Your folded cards stay hidden"
	var message := "%s. %s" % [hand_label, "You take $%d." % payout if raw_payout > 0 else "%s takes it." % _winner_names(winners)]
	_update_temperament_after_hand(state, awards)
	_finish_hand(state, run_state, {"winners": winners, "awards": awards, "payout": payout, "table_payout": raw_payout, "message": message})
	return {"payout": payout, "authority_gaps": authority_gaps, "dependency_reason": "host_tell_observation_authority_unavailable" if not authority_gaps.is_empty() else "", "message": message}


func _settle_legacy_pot(state: Dictionary, contenders: Array) -> Dictionary:
	var winners: Array = []
	var best_cards: Array = []
	for contender_value in contenders:
		var contender: Dictionary = contender_value
		var actor := str(contender.get("id", ""))
		var cards := _card_array(contender.get("cards", []))
		if actor.is_empty() or cards.size() != 5:
			continue
		if winners.is_empty() or CrewPokerModelScript.compare_hands(cards, best_cards) > 0:
			winners = [actor]
			best_cards = cards
		elif CrewPokerModelScript.compare_hands(cards, best_cards) == 0:
			winners.append(actor)
	var awards := CrewPokerModelScript.split_pot(maxi(0, int(state.get("pot", 0))), winners)
	return {"awards": awards, "winners": winners}


func _settle_holdem_pots(state: Dictionary, contenders: Array) -> Dictionary:
	var eligible := {}
	for contender_value in contenders:
		var contender: Dictionary = contender_value
		eligible[str(contender.get("id", ""))] = _card_array(contender.get("cards", []))
	var contributions := {}
	if int(state.get("player_contribution", 0)) > 0:
		contributions[PLAYER_ID] = int(state.get("player_contribution", 0))
	for seat_value in _dict_array(state.get("seats", [])):
		var seat: Dictionary = seat_value
		if int(seat.get("contribution", 0)) > 0:
			contributions[str(seat.get("member_id", ""))] = int(seat.get("contribution", 0))
	var levels: Array = []
	for value in contributions.values():
		if int(value) > 0 and not levels.has(int(value)):
			levels.append(int(value))
	levels.sort()
	var awards := {}
	var all_winners: Array = []
	var prior := 0
	for level_value in levels:
		var level := int(level_value)
		var contributors: Array = []
		var layer_eligible: Array = []
		for actor in contributions.keys():
			if int(contributions.get(actor, 0)) >= level:
				contributors.append(str(actor))
				if eligible.has(actor):
					layer_eligible.append(str(actor))
		var layer_pot := (level - prior) * contributors.size()
		prior = level
		if layer_pot <= 0 or layer_eligible.is_empty():
			continue
		var layer_winners: Array = []
		var best_cards: Array = []
		for actor in layer_eligible:
			var cards := _card_array(eligible.get(actor, []))
			if layer_winners.is_empty() or CrewPokerModelScript.compare_holdem(cards, best_cards) > 0:
				layer_winners = [actor]
				best_cards = cards
			elif CrewPokerModelScript.compare_holdem(cards, best_cards) == 0:
				layer_winners.append(actor)
		var shares := CrewPokerModelScript.split_pot(layer_pot, layer_winners)
		for actor in shares.keys():
			awards[actor] = int(awards.get(actor, 0)) + int(shares.get(actor, 0))
			if not all_winners.has(str(actor)):
				all_winners.append(str(actor))
	return {"awards": awards, "winners": all_winners}


func _update_player_tell_reputation(state: Dictionary, category: int, player_won: bool) -> void:
	var signals := _dict_array(state.get("player_signal_history", []))
	if signals.is_empty():
		return
	var actually_strong := category >= 2
	var delta := 0
	for signal_value in signals:
		var claimed_strong := str((signal_value as Dictionary).get("style", "")) == "strong"
		var credible := claimed_strong == actually_strong
		delta += 2 if credible else -3
		if not credible and player_won:
			delta += 1
	state["tell_reputation"] = clampi(int(state.get("tell_reputation", 50)) + clampi(delta, -8, 6), 10, 90)


func _source_action_record(state: Dictionary, member_id: String, action: String, ordinal: int) -> Dictionary:
	var history := _dict_array(state.get("action_history", []))
	for index in range(history.size() - 1, -1, -1):
		var row: Dictionary = history[index]
		if int(row.get("ordinal", -1)) == ordinal and str(row.get("actor", "")) == member_id and str(row.get("action", "")) == action:
			return row.duplicate(true)
	return {}


func _observation_provenance_valid(state: Dictionary, seats: Array, observation: Dictionary, authored_patterns: Array, run_state: RunState) -> bool:
	var allowed := ["id", "m", "i", "source_action", "source_record", "source_host_receipt_id", "start_ordinal", "duration_actions", "channel", "consumed", "verified", "verification_receipt"]
	for key_value in observation.keys():
		if not allowed.has(str(key_value)):
			return false
	var member_id := str(observation.get("m", ""))
	var pattern_index := int(observation.get("i", -1))
	if pattern_index < 0 or pattern_index >= authored_patterns.size() or not _seat_revealed(seats, member_id):
		return false
	var action := str(observation.get("source_action", ""))
	var ordinal := int(observation.get("start_ordinal", -1))
	var source := _source_action_record(state, member_id, action, ordinal)
	if source.is_empty() or typeof(observation.get("source_record")) != TYPE_DICTIONARY or (observation.get("source_record") as Dictionary) != source:
		return false
	var authored: Dictionary = authored_patterns[pattern_index]
	if str(observation.get("channel", "")) != str(authored.get("channel", "posture")):
		return false
	var seat_index := -1
	for index in range(seats.size()):
		if str((seats[index] as Dictionary).get("member_id", "")) == member_id:
			seat_index = index
			break
	if seat_index < 0:
		return false
	var seat: Dictionary = seats[seat_index]
	var evidence_cards := _card_array(seat.get("cards", []))
	if str(state.get("turn_engine", "legacy_v1")) == ORDERED_ENGINE:
		evidence_cards.append_array(_card_array(state.get("community_cards", [])))
	if not CrewPokerModelScript.condition_matches(str(authored.get("condition", "")), evidence_cards, action, int(seat.get("draw_count", -1)), str(source.get("intent", ""))):
		return false
	return _host_observation_applied(run_state, state, observation, str(authored.get("state_key", "")))


func _host_observation_applied(run_state: RunState, state: Dictionary, observation: Dictionary, state_key: String) -> bool:
	# A generic caller-mintable receipt cannot authorize tell mutation. This stays
	# false until a host-owned observation producer seals the authored condition.
	return false


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
	var stack_memory := {}
	for seat_value in _dict_array(state.get("seats", [])):
		var stack_seat: Dictionary = seat_value
		stack_memory[str(stack_seat.get("member_id", ""))] = int(stack_seat.get("stack", 0))
	state["npc_stacks"] = stack_memory
	state["hand_number"] = int(state.get("hand_number", 0)) + 1
	state["last_result"] = last
	state["phase"] = "idle"
	state["pot"] = 0
	state["to_call"] = 0
	state["x"] = []
	state["beat"] = {}
	state["observation_queue"] = []
	state["player_folded_hidden"] = false
	state["turn_owner"] = ""
	state["turn_order"] = []
	state["acted_since_raise"] = []
	state["player_all_in"] = false
	state["player_signal"] = {}
	state["player_signal_history"] = []
	state["player_fake_tell_used_street"] = ""
	state["hand_lines"] = _neutral_hand_lines()
	state["button_index"] = int(state.get("button_index", 0)) + 1
	if bool(state.get("migrate_to_holdem_after_hand", false)):
		state["turn_engine"] = ORDERED_ENGINE
		state.erase("migrate_to_holdem_after_hand")
	var tuning := CrewPokerModelScript.config()
	var next_player_blind := _player_forced_blind(state)
	if int(state.get("hand_number", 0)) >= int(tuning.get("session_hand_cap", 5)) \
			or absi(int(state.get("session_swing", 0))) >= int(tuning.get("session_swing_cap", 60)) \
			or (next_player_blind > 0 and (_loss_room(state, next_player_blind) != next_player_blind or int(state.get("player_stack", 0)) < next_player_blind)):
		_settle_session(state, run_state)


func _settle_session(state: Dictionary, run_state: RunState) -> String:
	if bool(state.get("session_settled", false)):
		return "The friendly money is already settled."
	if int(state.get("hand_number", 0)) > 0:
		run_state.crew_record_poker_session(_string_array(state.get("members", [])), int(state.get("session_swing", 0)))
	state["session_settled"] = true
	return "The table settles at %s. Nobody makes it bigger than it is." % _signed_cash(int(state.get("session_swing", 0)))


func _start_new_session(state: Dictionary, environment: Dictionary) -> void:
	# The settlement boundary is the cooldown. Reentry is explicit and advances a
	# durable session identity; it never reuses a live deck or settlement receipt.
	state["session_index"] = int(state.get("session_index", 0)) + 1
	state["hand_number"] = 0
	state["session_swing"] = 0
	state["session_settled"] = false
	state["phase"] = "idle"
	state["dealer_member_id"] = _derived_dealer_member_id(state, environment)
	state["pot"] = 0
	state["shoe"] = []
	state["player_cards"] = []
	state["seats"] = []
	state["x"] = []
	state["beat"] = {}
	state["observation_queue"] = []
	state["verified_observation_receipts"] = []
	state["night_id"] = _night_id(environment)
	state["last_result"] = {}
	state["turn_owner"] = ""
	state["turn_order"] = []
	state["turn_cursor"] = 0
	state["current_bet"] = 0
	state["last_raise_size"] = int(CrewPokerModelScript.config().get("big_blind", CrewPokerModelScript.config().get("raise_unit", 2)))
	state["round_contributions"] = {}
	state["acted_since_raise"] = []
	state["raise_count"] = 0
	state["player_active"] = true
	state["player_stack"] = int(CrewPokerModelScript.config().get("session_swing_cap", 60))
	state["action_history"] = []
	state["session_memory"] = {}
	state["seat_temperament"] = _neutral_temperament(_string_array(state.get("members", [])))
	state["player_reads"] = _neutral_player_reads()
	state["hand_lines"] = _neutral_hand_lines()
	state["public_memory_receipt_id"] = ""
	state["player_folded_hidden"] = false
	state["community_cards"] = []
	state["burn_cards"] = []
	state["dealer_actor"] = ""
	state["small_blind_actor"] = ""
	state["big_blind_actor"] = ""
	state["player_all_in"] = false
	state["player_signal"] = {}
	state["player_signal_history"] = []
	state["player_fake_tell_used_street"] = ""
	state["tell_reputation"] = 50
	state["table_talk_history"] = []
	state["table_talk_hand_count"] = 0
	state["table_talk_last_ordinal"] = -999
	state["table_talk_members_this_hand"] = []
	state["npc_stacks"] = {}
	state["night_task_receipt"] = ""
	state["night_aftermath"] = ""


func _buy_in_open(run_state: RunState, state: Dictionary) -> bool:
	if run_state == null:
		return false
	for member_id in _string_array(state.get("members", [])):
		if CrewStateModelScript.RANK_IDS.find(run_state.crew_rank(member_id)) >= CrewStateModelScript.RANK_IDS.find("associate"):
			return true
	return false


func _loss_room(state: Dictionary, wanted: int) -> int:
	var cap := int(CrewPokerModelScript.config().get("session_swing_cap", 60))
	return mini(maxi(0, wanted), maxi(0, cap + int(state.get("session_swing", 0))))


func _win_room(state: Dictionary, wanted: int) -> int:
	var cap := int(CrewPokerModelScript.config().get("session_swing_cap", 60))
	return mini(maxi(0, wanted), maxi(0, cap - int(state.get("session_swing", 0))))


func _table_state(environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("schema", "")) == STATE_SCHEMA:
		var migrated := (value as Dictionary).duplicate(true)
		var source_version := int(migrated.get("version", 1))
		migrated["version"] = STATE_VERSION
		if not migrated.has("session_index"):
			migrated["session_index"] = 0
		if not migrated.has("night_id"):
			migrated["night_id"] = _night_id(environment)
		if not migrated.has("action_ordinal"):
			migrated["action_ordinal"] = 0
		if not migrated.has("observation_queue"):
			migrated["observation_queue"] = []
		if not migrated.has("verified_observation_receipts"):
			migrated["verified_observation_receipts"] = []
		for key in ["turn_order", "acted_since_raise", "action_history"]:
			if not migrated.has(key):
				migrated[key] = []
		for key in ["round_contributions", "session_memory"]:
			if not migrated.has(key):
				migrated[key] = {}
		if not migrated.has("seat_temperament"):
			migrated["seat_temperament"] = _neutral_temperament(_string_array(migrated.get("members", [])))
		if not migrated.has("player_reads"):
			migrated["player_reads"] = _neutral_player_reads()
		if not migrated.has("hand_lines"):
			migrated["hand_lines"] = _neutral_hand_lines()
		for key in ["button_index", "turn_cursor", "current_bet", "raise_count"]:
			if not migrated.has(key):
				migrated[key] = 0
		if not migrated.has("last_raise_size"):
			migrated["last_raise_size"] = int(CrewPokerModelScript.config().get("big_blind", CrewPokerModelScript.config().get("raise_unit", 2)))
		if not migrated.has("turn_owner"):
			migrated["turn_owner"] = ""
		if not migrated.has("turn_engine"):
			migrated["turn_engine"] = ORDERED_ENGINE if _ordered_engine(environment) else "legacy_v1"
		if not migrated.has("player_active"):
			migrated["player_active"] = true
		if not migrated.has("player_stack"):
			migrated["player_stack"] = int(CrewPokerModelScript.config().get("session_swing_cap", 60))
		if not migrated.has("public_memory_receipt_id"):
			migrated["public_memory_receipt_id"] = ""
		if not migrated.has("player_folded_hidden"):
			migrated["player_folded_hidden"] = false
		for array_key in ["community_cards", "burn_cards"]:
			if not migrated.has(array_key):
				migrated[array_key] = []
		for text_key in ["dealer_actor", "small_blind_actor", "big_blind_actor", "player_fake_tell_used_street"]:
			if not migrated.has(text_key):
				migrated[text_key] = ""
		if not migrated.has("player_all_in"):
			migrated["player_all_in"] = false
		if not migrated.has("player_signal"):
			migrated["player_signal"] = {}
		if not migrated.has("player_signal_history"):
			migrated["player_signal_history"] = []
		if not migrated.has("tell_reputation"):
			migrated["tell_reputation"] = 50
		if not migrated.has("table_talk_history"):
			migrated["table_talk_history"] = []
		if not migrated.has("table_talk_hand_count"):
			migrated["table_talk_hand_count"] = 0
		if not migrated.has("table_talk_last_ordinal"):
			migrated["table_talk_last_ordinal"] = -999
		if not migrated.has("table_talk_members_this_hand"):
			migrated["table_talk_members_this_hand"] = []
		if not migrated.has("npc_stacks"):
			migrated["npc_stacks"] = {}
		var migrated_dealer := str(migrated.get("dealer_member_id", ""))
		if migrated_dealer.is_empty() or _string_array(migrated.get("members", [])).has(migrated_dealer):
			migrated["dealer_member_id"] = _derived_dealer_member_id(migrated, environment)
		# Version-two ordered saves contain a live five-card draw hand. Let that
		# exact hand finish under its original rules, then switch at the safe hand
		# boundary; this preserves every already-paid chip and hidden card.
		if source_version < 3 and str(migrated.get("turn_engine", "")) == ORDERED_ENGINE and str(migrated.get("phase", "idle")) != "idle":
			migrated["turn_engine"] = "legacy_v1"
			migrated["migrate_to_holdem_after_hand"] = true
		return migrated
	var empty_state := {"schema": STATE_SCHEMA, "version": STATE_VERSION, "producer_id": "poker", "game_id": get_id(), "members": [], "phase": "idle", "hand_number": 0, "session_swing": 0, "session_settled": false, "session_index": 0, "night_id": _night_id(environment), "action_ordinal": 0, "observation_queue": [], "verified_observation_receipts": [], "pot": 0, "shoe": [], "player_cards": [], "community_cards": [], "burn_cards": [], "seats": [], "x": [], "beat": {}, "last_result": {}, "action_history": [], "session_memory": {}, "public_memory_receipt_id": "", "player_folded_hidden": false, "turn_engine": ORDERED_ENGINE if _ordered_engine(environment) else "legacy_v1", "button_index": 0, "turn_owner": "", "turn_order": [], "turn_cursor": 0, "current_bet": 0, "last_raise_size": int(CrewPokerModelScript.config().get("big_blind", CrewPokerModelScript.config().get("raise_unit", 2))), "round_contributions": {}, "acted_since_raise": [], "raise_count": 0, "player_active": true, "player_all_in": false, "player_stack": int(CrewPokerModelScript.config().get("buy_in", 60)), "player_contribution": 0, "dealer_actor": "", "dealer_member_id": "", "small_blind_actor": "", "big_blind_actor": "", "player_signal": {}, "player_signal_history": [], "player_fake_tell_used_street": "", "tell_reputation": 50, "table_talk_history": [], "table_talk_hand_count": 0, "table_talk_last_ordinal": -999, "table_talk_members_this_hand": [], "npc_stacks": {}}
	empty_state["seat_temperament"] = {}
	empty_state["player_reads"] = _neutral_player_reads()
	empty_state["hand_lines"] = _neutral_hand_lines()
	empty_state["dealer_member_id"] = _derived_dealer_member_id(empty_state, environment)
	return empty_state


func _derived_dealer_member_id(state: Dictionary, environment: Dictionary) -> String:
	var members := _string_array(state.get("members", []))
	var candidates: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if not members.has(str(member_id)):
			candidates.append(str(member_id))
	if candidates.is_empty():
		return ""
	var identity := "%s|%d|%s" % [str(environment.get("id", "crew_poker")), int(state.get("session_index", 0)), ",".join(members)]
	var index := RngStream.derive_seed(1, 1, "crew_poker_dealer|%s" % identity) % candidates.size()
	return str(candidates[index])


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	states = states.duplicate(true)
	states[get_id()] = state.duplicate(true)
	environment["game_states"] = states


func _result(action_id: String, environment: Dictionary, delta: int, message: String, ok: bool) -> Dictionary:
	var result := GameModule.build_action_result({"ok": ok, "source_id": get_id(), "game_id": get_id(), "action_id": action_id, "action_kind": "legal", "environment_id": str(environment.get("id", "")), "environment_archetype_id": str(environment.get("archetype_id", "")), "bankroll_delta": delta, "won": delta > 0, "message": message})
	result["host_apply_result"] = ok
	result["surface_audio_cue"] = "card_deal" if action_id == "deal" else "card_fold" if action_id == "fold" else "card_check" if action_id == "fake_tell" else "chips_place" if action_id in ["call", "raise", "all_in"] else ""
	return result


func _poker_action(id: String, label: String, summary: String) -> Dictionary:
	return {"id": id, "label": label, "summary": summary, "win_chance": 0, "payout_mult": 0}


func _signed_cash(value: int) -> String:
	return "+%d" % value if value >= 0 else "%d" % value


func _seat_active(seats: Array, member_id: String) -> bool:
	for seat_value in seats:
		if typeof(seat_value) == TYPE_DICTIONARY and str((seat_value as Dictionary).get("member_id", "")) == member_id:
			return bool((seat_value as Dictionary).get("active", false))
	return false


func _seat_revealed(seats: Array, member_id: String) -> bool:
	for seat_value in seats:
		if typeof(seat_value) == TYPE_DICTIONARY and str((seat_value as Dictionary).get("member_id", "")) == member_id:
			return bool((seat_value as Dictionary).get("revealed", false))
	return false


func _night_id(environment: Dictionary) -> String:
	var authoring: Dictionary = environment.get("sequence_authoring", {}) if typeof(environment.get("sequence_authoring", {})) == TYPE_DICTIONARY else {}
	var requested := str(environment.get("crew_poker_night_id", authoring.get("crew_poker_night_id", "friendly_teaching")))
	return requested if NIGHT_IDS.has(requested) else "friendly_teaching"


func _ordered_engine(environment: Dictionary) -> bool:
	var authoring: Dictionary = environment.get("sequence_authoring", {}) if typeof(environment.get("sequence_authoring", {})) == TYPE_DICTIONARY else {}
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var stored: Dictionary = states.get(get_id(), {}) if typeof(states.get(get_id(), {})) == TYPE_DICTIONARY else {}
	if str(stored.get("turn_engine", "")) == "legacy_v1":
		return false
	if int(stored.get("version", STATE_VERSION)) < 3 and str(stored.get("turn_engine", "")) == ORDERED_ENGINE and str(stored.get("phase", "idle")) != "idle":
		return false
	return str(environment.get("crew_poker_turn_engine", authoring.get("crew_poker_turn_engine", ORDERED_ENGINE))) != "legacy_v1"


func _night_required_actions(state: Dictionary) -> Array:
	if not str(state.get("night_task_receipt", "")).is_empty():
		return []
	match str(state.get("night_id", "friendly_teaching")):
		"debt_court":
			return [_poker_action("answer_duty", "Answer the Ledger", "Resolve the room duty before the next hand.")]
		"after_job":
			return [_poker_action("choose_company", "Choose Who Stays", "Set the table roster before cards are dealt.")]
		"raid_jitters":
			return [_poker_action("hide_table", "Hide the Table", "Clear the visible pot and wait out the knock."), _poker_action("abort_night", "End the Night", "Settle safely and leave the room changed.")]
	return []


func _resolve_night_task(state: Dictionary, action_id: String) -> Dictionary:
	var session := int(state.get("session_index", 0))
	state["night_task_receipt"] = "crew-poker-night:%s:%d:%s" % [str(state.get("night_id", "friendly_teaching")), session, action_id]
	match action_id:
		"answer_duty":
			state["night_aftermath"] = "ledger_duty_answered"
			return {"ok": true, "delta": 0, "message": "The ledger duty is answered. The waiting chair opens again."}
		"choose_company":
			state["night_aftermath"] = "company_choice_persisted"
			return {"ok": true, "delta": 0, "message": "The room accepts who stays. The remaining chairs define the night."}
		"hide_table":
			state["night_aftermath"] = "table_hidden_after_knock"
			return {"ok": true, "delta": 0, "message": "Chips vanish, cards flatten, and the lamp goes dark until the knock passes."}
		"resume_table":
			state["night_aftermath"] = "table_resumed_after_knock"
			return {"ok": true, "delta": 0, "message": "The lamp returns and the same ordered session resumes."}
	return {"ok": false, "delta": 0, "message": "That room task is not open."}


func _night_scene_state(state: Dictionary) -> Dictionary:
	match str(state.get("night_id", "friendly_teaching")):
		"hustle_test":
			return {"task": "survive_two_bounded_raises", "lamp": "hard_focus", "door": "closed", "chairs": "tight", "aftermath": "respect_test_recorded"}
		"debt_court":
			return {"task": "answer_duty_between_hands", "lamp": "ledger_pool", "door": "waiting_service", "chairs": "court", "aftermath": "duty_resolved"}
		"after_job":
			return {"task": "choose_who_stays", "lamp": "low_warm", "door": "open_to_hall", "chairs": "roster_dependent", "aftermath": "company_choice_persists"}
		"raid_jitters":
			return {"task": "pause_hide_or_abort", "lamp": "knock_blackout", "door": "barred", "chairs": "ready_to_clear", "aftermath": "table_hidden_or_aborted"}
		_:
			return {"task": "complete_teaching_hand", "lamp": "warm_table", "door": "private_open", "chairs": "friendly", "aftermath": "lesson_complete"}


func _ordered_ritual_actors(state: Dictionary) -> Array:
	var actors: Array = [{"id": PLAYER_ID, "anchor": "seat_south", "behavior": "acting" if str(state.get("turn_owner", "")) == PLAYER_ID else "watching", "bounds": Rect2(294, 220, 308, 94), "attention": str(state.get("turn_owner", ""))}]
	var seats := _dict_array(state.get("seats", []))
	var seat_count := mini(MAX_OPPONENT_SEATS, seats.size())
	var layout_indices := _seat_layout_indices(seat_count)
	for index in range(seat_count):
		var seat: Dictionary = seats[index]
		var layout: Dictionary = SEAT_LAYOUT[int(layout_indices[index])]
		actors.append({"id": str(seat.get("member_id", "")), "anchor": "seat_%d" % index, "behavior": str(seat.get("last_action", "watching")), "bounds": layout.get("focus_rect", Rect2()), "attention": str(state.get("turn_owner", "")), "present": true, "in_hand": bool(seat.get("active", false))})
	return actors


func _ordered_ritual_objects(state: Dictionary) -> Array:
	var scene := _night_scene_state(state)
	return [
		{"id": "poker_table", "state": str(state.get("phase", "idle")), "bounds": Rect2(118, 104, 664, 224), "functional_state": "live" if str(state.get("phase", "idle")) != "idle" else "ready", "z_order": 3},
		{"id": "pot", "state": "occupied" if int(state.get("pot", 0)) > 0 else "clear", "bounds": Rect2(410, 158, 80, 48), "amount": int(state.get("pot", 0)), "z_order": 7},
		{"id": "community_board", "state": str(state.get("phase", "idle")), "bounds": Rect2(305, 158, 286, 70), "card_count": _card_array(state.get("community_cards", [])).size(), "z_order": 6},
		{"id": "room_lamp", "state": str(scene.get("lamp", "warm_table")), "bounds": Rect2(424, 42, 52, 52), "functional_state": "lit", "z_order": 9},
		{"id": "private_door", "state": str(scene.get("door", "private_open")), "bounds": Rect2(802, 84, 56, 176), "functional_state": "available" if str(scene.get("door", "")) != "barred" else "blocked", "z_order": 2},
	]


func _visible_observations(state: Dictionary) -> Array:
	var result: Array = []
	var ordinal := int(state.get("action_ordinal", 0))
	for value in _dict_array(state.get("observation_queue", [])):
		var start := int(value.get("start_ordinal", 0))
		var duration := maxi(1, int(value.get("duration_actions", OBSERVATION_DURATION_ACTIONS)))
		if ordinal >= start and ordinal < start + duration:
			result.append(value)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start_ordinal", 0)) < int(b.get("start_ordinal", 0)) or (int(a.get("start_ordinal", 0)) == int(b.get("start_ordinal", 0)) and str(a.get("id", "")) < str(b.get("id", "")))
	)
	return result


func _public_observation_queue(state: Dictionary) -> Array:
	var result: Array = []
	for value in _visible_observations(state):
		result.append({
			"observation_id": str(value.get("id", "")),
			"member_id": str(value.get("m", "")),
			"source_action": str(value.get("source_action", "")),
			"start_ordinal": int(value.get("start_ordinal", 0)),
			"duration_actions": int(value.get("duration_actions", OBSERVATION_DURATION_ACTIONS)),
			"channel": str(value.get("channel", "posture")),
		})
	return result


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
	var hand_number := int(state.get("hand_number", 0))
	var dealer_id := str(state.get("dealer_member_id", ""))
	var dealer_lines: Dictionary = CrewPokerModelScript.config().get("dealer_banter", {}) if typeof(CrewPokerModelScript.config().get("dealer_banter", {})) == TYPE_DICTIONARY else {}
	var dealer_options: Array = dealer_lines.get(dealer_id, []) if typeof(dealer_lines.get(dealer_id, [])) == TYPE_ARRAY else []
	if str(state.get("phase", "idle")) == "idle" and not dealer_options.is_empty():
		return str(dealer_options[hand_number % dealer_options.size()])
	var lines: Dictionary = CrewPokerModelScript.config().get("banter", {}) if typeof(CrewPokerModelScript.config().get("banter", {})) == TYPE_DICTIONARY else {}
	var member_id := str(members[hand_number % members.size()])
	var options: Array = lines.get(member_id, []) if typeof(lines.get(member_id, [])) == TYPE_ARRAY else []
	return str(options[hand_number % options.size()]) if not options.is_empty() else "%s cuts the deck." % MEMBER_NAMES.get(member_id, member_id)


func _crew_character_model(member_id: String) -> Dictionary:
	if library == null:
		return {}
	var character := library.character(member_id)
	return _poker_dict(character.get("model", {}))


func _speaker_matches_member(speaker_value: Variant, member_id: String) -> bool:
	if typeof(speaker_value) != TYPE_DICTIONARY:
		return false
	var speaker: Dictionary = speaker_value
	return str(speaker.get("speaking_character_id", speaker.get("character_id", ""))) == member_id


func _draw_room(surface, state: Dictionary) -> void:
	var room_note := "STACK $%d | HAND %d/%d" % [int(state.get("player_stack", 0)), int(state.get("hand_number", 0)) + 1, int(state.get("hand_cap", 5))] if str(state.get("phase", "idle")) == "idle" else "%s | STK $%d | CALL $%d" % [str(state.get("phase", "idle")).to_upper(), int(state.get("player_stack", 0)), int(state.get("amount_to_call", 0))]
	TableGameVisualsScript.draw_room(surface, state, "Back-Room", "NO-LIMIT HOLD'EM | $1 / $2", room_note)
	TableGameVisualsScript.draw_table(surface)


func _draw_dealer_station(surface, state: Dictionary) -> void:
	var dealer_id := str(state.get("dealer_member_id", ""))
	if dealer_id.is_empty():
		return
	var model := _draw_dict_view(state.get("dealer_character_model", {}))
	var foot: Vector2 = DEALER_STATION_LAYOUT.get("character_foot", Vector2.ZERO)
	var scale := float(DEALER_STATION_LAYOUT.get("character_scale", 0.64))
	var clock: float = float(surface.surface_flicker()) + float(absi(dealer_id.hash()) % 1900) / 1000.0
	var dealing: bool = bool(surface.surface_animation_active(CARD_ANIMATION_CHANNEL))
	var accent := Color(str(model.get("accent_color", "#d5d8e6")))
	TableGameVisualsScript._draw_table_character(surface, {
		"name": "",
		"skin": Color(str(model.get("skin_color", "#c49371"))),
		"hair": Color(str(model.get("hair_color", "#171022"))),
		"jacket": Color(str(model.get("jacket_color", "#1d2030"))),
		"accent": accent,
		"pose": "snitch" if dealing else "idle",
		"eye_offset": 1.0,
		"blink": fposmod(clock, 3.2) > 3.02,
		"holding_card": dealing,
		"silhouette": str(model.get("silhouette", "coat")),
	}, foot, scale, clock)
	# Visor, sleeve bars, and apron make the stationary house dealer distinct
	# from the rotating player button without changing shared character poses.
	surface.draw_rect(Rect2(foot + Vector2(-10, -51) * scale, Vector2(20, 4) * scale), accent)
	surface.draw_rect(Rect2(foot + Vector2(-20, -34) * scale, Vector2(40, 24) * scale), Color(accent.r, accent.g, accent.b, 0.24))
	surface.draw_line(foot + Vector2(-27, -34) * scale, foot + Vector2(-34, -18) * scale, accent, 2.0)
	surface.draw_line(foot + Vector2(27, -34) * scale, foot + Vector2(34, -18) * scale, accent, 2.0)
	var deck_rect: Rect2 = DEALER_STATION_LAYOUT.get("deck_card_rect", Rect2())
	if not dealing:
		deck_rect.position += Vector2(sin(clock * 1.6) * 1.5, 0)
	for offset in range(3):
		PlayingCardRendererScript.draw_card_back(surface, Rect2(deck_rect.position + Vector2(offset * 2, -offset), deck_rect.size))
	var muck_rect: Rect2 = DEALER_STATION_LAYOUT.get("muck_rect", Rect2())
	for offset in range(2):
		PlayingCardRendererScript.draw_card_back(surface, Rect2(muck_rect.position + Vector2(offset * 3, -offset), muck_rect.size))
	surface.surface_label_centered("%s · DEALER" % str(state.get("dealer_name", "Crew")), DEALER_STATION_LAYOUT.get("name_label_rect", Rect2()), 8, accent)
	surface.surface_label_centered("POT", Rect2(Vector2(565, 282), Vector2(50, 10)), 8, C_SOFT)


func _draw_seats(surface, state: Dictionary) -> void:
	var seats: Array = state.get("seats", []) if typeof(state.get("seats", [])) == TYPE_ARRAY else []
	var members: Array = state.get("members", []) if typeof(state.get("members", [])) == TYPE_ARRAY else []
	var seat_count := mini(MAX_OPPONENT_SEATS, maxi(seats.size(), members.size()))
	var layout_indices := _seat_layout_indices(seat_count)
	for index in range(seat_count):
		var seat: Dictionary = seats[index] if index < seats.size() else {"member_id": members[index], "cards": _hidden_cards(2), "active": true}
		var layout: Dictionary = SEAT_LAYOUT[int(layout_indices[index])]
		var name := str(MEMBER_NAMES.get(str(seat.get("member_id", "")), "Crew"))
		var color := C_SOFT if bool(seat.get("active", true)) else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.4)
		var model := _poker_dict(seat.get("character_model", {}))
		if model.is_empty():
			model = _crew_character_model(str(seat.get("member_id", "")))
		var active := bool(seat.get("active", true)) or _fold_landing_waiting(surface, str(seat.get("member_id", "")))
		var talking := bool(seat.get("conversation_active", false))
		var last_action := str(seat.get("last_action", "waiting"))
		var pose := "covered" if not active else "snitch" if talking or last_action in ["raise", "all_in"] else "watching" if str(state.get("turn_owner", "")) == str(seat.get("member_id", "")) else "idle"
		var portrait_variant := str(seat.get("portrait_variant", ""))
		if not portrait_variant.is_empty() and active and not talking:
			pose = _portrait_variant_pose(portrait_variant)
		var accent := Color(str(model.get("accent_color", "#d5d8e6"))) if active else color
		var animation_offset := float(absi(str(seat.get("member_id", "")).hash()) % 2200) / 1000.0
		var portrait_scale := 1.0 + float((absi(portrait_variant.hash()) % 5) - 2) * 0.012 if not portrait_variant.is_empty() else 1.0
		TableGameVisualsScript._draw_table_character(surface, {
			"name": "" if bool(layout.get("action_carries_name", false)) else name,
			"skin": Color(str(model.get("skin_color", "#c49371"))),
			"hair": Color(str(model.get("hair_color", "#171022"))),
			"jacket": Color(str(model.get("jacket_color", "#1d2030"))),
			"accent": accent,
			"role": "crew",
			"pose": pose,
			"eye_offset": _portrait_variant_eye_offset(portrait_variant) if not portrait_variant.is_empty() else 2.0 if talking or pose == "watching" else 0.0,
			"blink": fposmod(surface.surface_flicker() + animation_offset, 3.1) > 2.94,
			"holding_card": active and not str(state.get("phase", "idle")) in ["idle", "showdown"],
			"silhouette": str(model.get("silhouette", "coat")),
		}, layout.get("character_foot", Vector2.ZERO), clampf(float(model.get("scale", 1.0)) * 0.72 * portrait_scale, 0.66, 0.84), surface.surface_flicker() + animation_offset)
		# Fold flights already carry both hidden cards into the dealer's muck. Do
		# not redraw the authoritative saved hand at the seat after that animation
		# finishes; inactive hands stay hidden for live play and restored saves.
		if _resting_hole_cards_visible(state, str(seat.get("member_id", ""))):
			var cards := _draw_array_view(seat.get("cards", []))
			for card_index in range(mini(2, cards.size())):
				if not _card_landing_waiting(surface, str(seat.get("member_id", "")), card_index):
					PlayingCardRendererScript.draw_card(surface, cards[card_index], Rect2((layout.get("hole_card_origin", Vector2.ZERO) as Vector2) + Vector2(card_index * 27, 0), Vector2(24, 35)))
		var action_text := str(seat.get("last_action", "")).replace("_", " ").capitalize()
		if bool(seat.get("all_in", false)):
			action_text = "ALL IN"
		var presented_action := "%s: %s" % [name, action_text] if bool(layout.get("action_carries_name", false)) and not action_text.is_empty() else action_text
		surface.surface_label_centered(presented_action, layout.get("action_label_rect", Rect2()), int(layout.get("action_font_size", 10)), C_YELLOW)
		if str(state.get("dealer_actor", "")) == str(seat.get("member_id", "")):
			_draw_button_marker(surface, layout.get("dealer_button_center", Vector2.ZERO))


func _portrait_variant_pose(variant: String) -> String:
	var normalized := variant.to_lower()
	if normalized.contains("eyes") or normalized.contains("glasses") or normalized.contains("brow"):
		return "watching"
	if normalized.contains("still") or normalized.contains("flat") or normalized.contains("down") or normalized.contains("settled"):
		return "covered"
	return "snitch"


func _portrait_variant_eye_offset(variant: String) -> float:
	var normalized := variant.to_lower()
	if normalized.contains("left") or normalized.contains("door"):
		return -3.0
	if normalized.contains("glasses") or normalized.contains("brow") or normalized.contains("chin"):
		return 1.0
	return 2.0


func _draw_button_marker(surface, center: Vector2) -> void:
	surface.draw_circle(center, 9.0, C_WHITE)
	surface.surface_label_centered("B", Rect2(center - Vector2(8, 8), Vector2(16, 16)), 9, C_DARK)


func _draw_shared_board(surface, state: Dictionary) -> void:
	var board := _draw_array_view(state.get("community_cards", []))
	var start := Vector2(305, 158)
	for index in range(5):
		var rect := Rect2(start + Vector2(index * 59, 0), Vector2(50, 70))
		if index < board.size():
			if not _card_landing_waiting(surface, "board", index):
				PlayingCardRendererScript.draw_card(surface, board[index], rect)
		else:
			surface.draw_rect(rect, Color(0.02, 0.08, 0.07, 0.55))
			surface.draw_rect(rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.32), false, 1.0)


func _chip_layout(state: Dictionary) -> Array:
	var layout: Array = []
	var rounds := _poker_dict(state.get("round_contributions", {}))
	var player_amount := maxi(0, int(rounds.get(PLAYER_ID, 0)))
	var current_round_total := player_amount
	var seats := _dict_array(state.get("seats", []))
	var seat_count := mini(MAX_OPPONENT_SEATS, seats.size())
	var layout_indices := _seat_layout_indices(seat_count)
	for index in range(seat_count):
		var seat: Dictionary = seats[index]
		var member_id := str(seat.get("member_id", ""))
		var amount := maxi(0, int(seat.get("round_contribution", 0)))
		current_round_total += amount
		if amount > 0:
			var seat_layout: Dictionary = SEAT_LAYOUT[int(layout_indices[index])]
			layout.append(_chip_layout_entry(member_id, amount, seat_layout.get("bet_chip_center", Vector2.ZERO), 2))
	if player_amount > 0:
		layout.append(_chip_layout_entry(PLAYER_ID, player_amount, Vector2(350, 280), 2))
	var swept_pot := maxi(0, int(state.get("pot", 0)) - current_round_total)
	if swept_pot > 0:
		layout.push_front(_chip_layout_entry("pot", swept_pot, DEALER_STATION_LAYOUT.get("pot_center", Vector2.ZERO), 6))
	return layout


func seat_focus_rect(opponent_count: int, seat_index: int) -> Rect2:
	var count := clampi(opponent_count, 1, MAX_OPPONENT_SEATS)
	var layout_indices := _seat_layout_indices(count)
	var clamped_index := clampi(seat_index, 0, count - 1)
	var layout: Dictionary = SEAT_LAYOUT[int(layout_indices[clamped_index])]
	return layout.get("focus_rect", Rect2())


func _seat_layout_indices(opponent_count: int) -> Array:
	return SEAT_LAYOUT_INDICES.get(clampi(opponent_count, 1, MAX_OPPONENT_SEATS), SEAT_LAYOUT_INDICES[MAX_OPPONENT_SEATS])


func _chip_layout_entry(owner_id: String, amount: int, center: Vector2, max_stacks: int) -> Dictionary:
	return {
		"owner_id": owner_id,
		"amount": amount,
		"center": center,
		"max_stacks": max_stacks,
		"bounds": _chip_cluster_bounds(amount, center, max_stacks),
	}


func _chip_cluster_bounds(amount: int, center: Vector2, max_stacks: int) -> Rect2:
	if amount <= 0 or max_stacks <= 0:
		return Rect2()
	var visible_chips := mini(clampi(amount, 1, 42), max_stacks * 8)
	var stack_count := mini(max_stacks, ceili(float(visible_chips) / 8.0))
	var tallest_stack := mini(8, visible_chips)
	var half_span := float(stack_count - 1) * 9.0
	var minimum := Vector2(center.x - half_span - 7.0, center.y - float(tallest_stack - 1) * 3.0 - 7.0)
	var maximum := Vector2(center.x + half_span + 7.0, center.y + 7.0)
	return Rect2(minimum, maximum - minimum)


func _draw_betting_chips(surface, state: Dictionary) -> void:
	var layout := _draw_array_view(state.get("chip_layout", []))
	for entry_value in layout:
		var entry: Dictionary = entry_value
		_draw_chip_cluster(surface, _resting_chip_amount(surface, entry), entry.get("center", Vector2.ZERO), int(entry.get("max_stacks", 1)))


func _draw_chip_cluster(surface, amount: int, center: Vector2, max_stacks: int) -> void:
	if amount <= 0 or max_stacks <= 0:
		return
	var visible_chips := clampi(amount, 1, 42)
	var stack_count := mini(max_stacks, ceili(float(visible_chips) / 8.0))
	var colors := [C_PINK, C_CYAN, C_YELLOW, C_WHITE]
	for stack_index in range(stack_count):
		var in_stack := mini(8, maxi(1, visible_chips - stack_index * 8))
		var x := center.x + (float(stack_index) - float(stack_count - 1) * 0.5) * 18.0
		var chip_color: Color = colors[stack_index % colors.size()]
		for chip_index in range(in_stack):
			var y := center.y - float(chip_index) * 3.0
			surface.draw_circle(Vector2(x, y), 7.0, Color("#090b10"))
			surface.draw_circle(Vector2(x, y - 1), 5.5, chip_color)


func _draw_player(surface, state: Dictionary) -> void:
	var cards := _draw_array_view(state.get("player_cards", []))
	if str(state.get("turn_engine", "legacy_v1")) != ORDERED_ENGINE:
		var held := _draw_array_view(state.get("held", []))
		var legacy_start := Vector2(294, 232)
		for legacy_index in range(cards.size()):
			var legacy_rect := Rect2(legacy_start + Vector2(legacy_index * 64, 0), Vector2(52, 74))
			PlayingCardRendererScript.draw_card(surface, cards[legacy_index], legacy_rect, {"held": held.has(legacy_index)})
			if str(state.get("phase", "")) == "draw":
				surface.surface_add_hit(legacy_rect.grow(4), "poker_card", legacy_index)
				surface.surface_label("KEEP" if held.has(legacy_index) else "DRAW", legacy_rect.position + Vector2(7, 88), 10, C_TEAL if held.has(legacy_index) else C_PINK)
		return
	var start := Vector2(385, 245)
	if _resting_hole_cards_visible(state, PLAYER_ID):
		for index in range(mini(2, cards.size())):
			var rect := Rect2(start + Vector2(index * 68, 0), Vector2(58, 81))
			if not _card_landing_waiting(surface, PLAYER_ID, index):
				PlayingCardRendererScript.draw_card(surface, cards[index], rect)
	if str(state.get("dealer_actor", "")) == PLAYER_ID:
		_draw_button_marker(surface, Vector2(522, 292))
	if bool(state.get("player_all_in", false)):
		surface.surface_label("ALL IN", Vector2(535, 286), 11, C_YELLOW)


func _resting_hole_cards_visible(state: Dictionary, actor: String) -> bool:
	if actor == PLAYER_ID:
		return bool(state.get("player_active", true))
	var seat_index := _seat_index(state, actor)
	if seat_index < 0:
		return false
	var seats := _dict_array(state.get("seats", []))
	return seat_index < seats.size() and bool((seats[seat_index] as Dictionary).get("active", false))


func _draw_card_flights(surface, _state: Dictionary) -> void:
	if not surface.surface_animation_active(CARD_ANIMATION_CHANNEL):
		return
	var elapsed_msec := float(surface.surface_elapsed(CARD_ANIMATION_CHANNEL)) * 1000.0
	for event_value in draw_card_events_cache:
		var event: Dictionary = event_value
		var delay := float(event.get("delay_msec", 0))
		var duration := maxf(1.0, float(event.get("duration_msec", 1)))
		if elapsed_msec < delay or elapsed_msec > delay + duration:
			continue
		var progress := TableGameVisualsScript.flight_progress(elapsed_msec, delay, duration)
		var from_position := _event_vector(event.get("from", []))
		var to_position := _event_vector(event.get("to", []))
		var from_size := _event_vector(event.get("from_size", []), Vector2(24, 35))
		var to_size := _event_vector(event.get("to_size", []), Vector2(24, 35))
		var size := from_size.lerp(to_size, progress)
		var position := TableGameVisualsScript.flight_position(from_position, to_position, progress, 16.0 if str(event.get("kind", "")) != "collect" else 9.0)
		var reveal := bool(event.get("reveal_on_land", false))
		var width_scale := TableGameVisualsScript.card_flip_width_scale(progress) if reveal else 1.0
		var draw_size := Vector2(size.x * width_scale, size.y)
		var rect := Rect2(position + Vector2((size.x - draw_size.x) * 0.5, 0), draw_size)
		surface.draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0, 0, 0, 0.24))
		var card: Variant = event.get("card", HIDDEN_CARD)
		if reveal and progress < 0.82:
			card = HIDDEN_CARD
		PlayingCardRendererScript.draw_card(surface, card, rect)


func _draw_chip_flights(surface, _state: Dictionary) -> void:
	for event_value in draw_chip_events_cache:
		var event: Dictionary = event_value
		var channel := PAYOUT_ANIMATION_CHANNEL if str(event.get("kind", "")) == "payout" else CHIP_ANIMATION_CHANNEL
		if not surface.surface_animation_active(channel):
			continue
		var elapsed_msec := float(surface.surface_elapsed(channel)) * 1000.0
		var delay := float(event.get("delay_msec", 0))
		var duration := maxf(1.0, float(event.get("duration_msec", 1)))
		if elapsed_msec < delay or elapsed_msec > delay + duration:
			continue
		var progress := TableGameVisualsScript.flight_progress(elapsed_msec, delay, duration)
		var center := TableGameVisualsScript.flight_position(_event_vector(event.get("from", [])), _event_vector(event.get("to", [])), progress, 10.0)
		_draw_chip_cluster(surface, mini(8, maxi(1, int(event.get("amount", 1)))), center, 1)


func _card_landing_waiting(surface, actor: String, card_index: int) -> bool:
	if not surface.surface_animation_active(CARD_ANIMATION_CHANNEL):
		return false
	var elapsed_msec := float(surface.surface_elapsed(CARD_ANIMATION_CHANNEL)) * 1000.0
	var latest_end := 0.0
	for event_value in draw_card_events_cache:
		var event: Dictionary = event_value
		if str(event.get("actor", "")) == actor and int(event.get("card_index", -1)) == card_index and str(event.get("kind", "")) in ["deal", "board", "fold", "showdown_flip"]:
			latest_end = maxf(latest_end, float(event.get("delay_msec", 0)) + float(event.get("duration_msec", 0)))
	return latest_end > 0.0 and elapsed_msec < latest_end


func _fold_landing_waiting(surface, actor: String) -> bool:
	if not surface.surface_animation_active(CARD_ANIMATION_CHANNEL):
		return false
	var elapsed_msec := float(surface.surface_elapsed(CARD_ANIMATION_CHANNEL)) * 1000.0
	for event_value in draw_card_events_cache:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "fold" and str(event.get("actor", "")) == actor and elapsed_msec < float(event.get("delay_msec", 0)) + float(event.get("duration_msec", 0)):
			return true
	return false


func _resting_chip_amount(surface, entry: Dictionary) -> int:
	var amount := int(entry.get("amount", 0))
	if not surface.surface_animation_active(CHIP_ANIMATION_CHANNEL):
		return amount
	var owner := str(entry.get("owner_id", ""))
	var elapsed_msec := float(surface.surface_elapsed(CHIP_ANIMATION_CHANNEL)) * 1000.0
	for event_value in draw_chip_events_cache:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "payout":
			continue
		var end := float(event.get("delay_msec", 0)) + float(event.get("duration_msec", 0))
		if elapsed_msec >= end:
			continue
		if str(event.get("kind", "")) == "place" and str(event.get("actor", "")) == owner:
			amount -= int(event.get("amount", 0))
		elif str(event.get("kind", "")) == "sweep" and owner == "pot":
			amount -= int(event.get("amount", 0))
	return maxi(0, amount)


func _draw_observation(surface, state: Dictionary) -> void:
	var observation := _draw_dict_view(state.get("observation", {}))
	var channel := str(observation.get("channel", ""))
	var text := ""
	match channel:
		"line":
			text = str(observation.get("line", ""))
		"portrait":
			text = str(observation.get("quirk", ""))
		"timing":
			# Timing is authored against the source action ordinal. Reduced motion
			# changes travel, never whether an ordered cue is present. Legacy v1
			# observations retain their shipped elapsed presentation contract until
			# assembly opts the table into ordered_v1.
			if str(observation.get("observation_id", "")).is_empty():
				var elapsed_msec := int(surface.surface_render_elapsed_msec()) if surface != null and surface.has_method("surface_render_elapsed_msec") else int(observation.get("timing_msec", 0))
				text = str(observation.get("line", "")) if elapsed_msec >= int(observation.get("timing_msec", 0)) else "The room holds one quiet beat."
			else:
				text = str(observation.get("line", "The room holds one quiet beat."))
		_:
			text = str(observation.get("quirk", observation.get("line", "")))
	if text.is_empty():
		text = str(state.get("banter", "The room keeps its own time."))
	surface.draw_rect(Rect2(138, 337, 548, 35), Color(0.03, 0.03, 0.05, 0.92))
	surface.surface_label(text.left(76), Vector2(152, 359), 11, C_SOFT)


func _draw_controls(surface, state: Dictionary) -> void:
	if bool(state.get("table_talk_active", false)):
		surface.surface_label("ANSWER THE TABLE TO CONTINUE", Vector2(226, 405), 11, C_CYAN)
		return
	var actions := _draw_array_view(state.get("legal_actions", []))
	var has_fake_tell := false
	var has_raise := false
	for action_value in actions:
		var action_id := str((action_value as Dictionary).get("id", ""))
		if action_id == "fake_tell":
			has_fake_tell = true
		elif action_id == "raise":
			has_raise = true
	if has_raise and bool(state.get("raise_panel_open", false)):
		_draw_raise_selector(surface, state)
		return
	if has_fake_tell:
		var tell_style := str(state.get("tell_style", "strong"))
		surface.surface_label("YOUR SIGNAL", Vector2(700, 346), 9, C_SOFT)
		for style_index in range(2):
			var style := "strong" if style_index == 0 else "weak"
			var style_rect := Rect2(697 + style_index * 78, 353, 72, 20)
			surface.draw_rect(style_rect, Color("#38233d") if tell_style == style else Color("#16131d"))
			surface.draw_rect(style_rect, C_PINK if tell_style == style else C_SOFT, false, 1.0)
			surface.surface_label_centered(style.to_upper(), style_rect, 9, C_WHITE)
			surface.surface_add_hit(style_rect, "poker_tell_style", style_index)
	var count := maxi(1, actions.size())
	var gap := 10.0
	var width := minf(150.0, (760.0 - gap * float(count - 1)) / float(count))
	var total := width * float(count) + gap * float(count - 1)
	var x := 450.0 - total * 0.5
	for index in range(actions.size()):
		var action: Dictionary = actions[index]
		var rect := Rect2(x, 382, width, 34)
		surface.draw_rect(rect, Color("#241b32"))
		var border := C_PINK if str(action.get("id", "")) == "fake_tell" else C_CYAN
		surface.draw_rect(rect, border, false, 1)
		surface.surface_label_centered(str(action.get("label", "ACT")).to_upper(), rect, 10 if actions.size() >= 5 else 12, C_WHITE)
		var action_id := str(action.get("id", ""))
		surface.surface_add_hit(rect, "poker_raise_open" if action_id == "raise" else "poker_%s" % action_id, index)
		x += width + gap
	if not bool(state.get("buy_in_open", false)):
		surface.surface_label_centered("ASSOCIATE VOUCH REQUIRED", Rect2(240, 372, 420, 34), 14, C_PINK)


func _draw_raise_selector(surface, state: Dictionary) -> void:
	var selected := int(state.get("selected_raise_to", state.get("minimum_raise_to", 0)))
	var minimum := int(state.get("minimum_raise_to", selected))
	var maximum := int(state.get("maximum_raise_to", selected))
	var raise_decrement_enabled := selected > minimum
	var raise_increment_enabled := selected < maximum
	surface.draw_rect(Rect2(120, 334, 660, 43), Color("#080a12"))
	surface.draw_rect(Rect2(120, 334, 660, 43), C_PINK, false, 1.0)
	surface.surface_label("CHOOSE ANY WHOLE-DOLLAR TOTAL", Vector2(134, 348), 9, C_SOFT)
	var selector_buttons := [
		{"action": "poker_raise_min", "label": "MIN $%d" % minimum, "rect": Rect2(310, 342, 76, 26), "enabled": raise_decrement_enabled},
		{"action": "poker_raise_minus_five", "label": "-5", "rect": Rect2(392, 342, 45, 26), "enabled": raise_decrement_enabled},
		{"action": "poker_raise_minus_one", "label": "-1", "rect": Rect2(443, 342, 45, 26), "enabled": raise_decrement_enabled},
		{"action": "", "label": "$%d" % selected, "rect": Rect2(494, 342, 62, 26)},
		{"action": "poker_raise_plus_one", "label": "+1", "rect": Rect2(562, 342, 45, 26), "enabled": raise_increment_enabled},
		{"action": "poker_raise_plus_five", "label": "+5", "rect": Rect2(613, 342, 45, 26), "enabled": raise_increment_enabled},
		{"action": "poker_raise_max", "label": "MAX $%d" % maximum, "rect": Rect2(664, 342, 102, 26), "enabled": raise_increment_enabled},
	]
	for button_value in selector_buttons:
		var button: Dictionary = button_value
		var rect: Rect2 = button.get("rect", Rect2())
		var action := str(button.get("action", ""))
		var enabled := bool(button.get("enabled", true))
		surface.draw_rect(rect, Color("#241b32") if not action.is_empty() and enabled else Color("#101826"))
		surface.draw_rect(rect, C_CYAN if not action.is_empty() and enabled else C_SOFT, false, 1.0)
		surface.surface_label_centered(str(button.get("label", "")), rect, 8, C_WHITE if enabled else C_SOFT)
		if not action.is_empty() and enabled:
			surface.surface_add_hit(rect, action)
	var confirm_rect := Rect2(246, 382, 270, 34)
	var cancel_rect := Rect2(526, 382, 128, 34)
	for control in [
		{"action": "poker_raise_confirm", "label": "RAISE TO $%d" % selected, "rect": confirm_rect, "color": C_PINK},
		{"action": "poker_raise_cancel", "label": "CANCEL", "rect": cancel_rect, "color": C_SOFT},
	]:
		var rect: Rect2 = control.get("rect", Rect2())
		var color: Color = control.get("color", C_SOFT)
		surface.draw_rect(rect, Color("#241b32"))
		surface.draw_rect(rect, color, false, 1.0)
		surface.surface_label_centered(str(control.get("label", "")), rect, 11, C_WHITE)
		surface.surface_add_hit(rect, str(control.get("action", "")))


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


func _poker_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


# The surface state is a read-only presentation snapshot. Keep rendering off the
# deep-copy helpers used by gameplay mutations.
static func _draw_dict_view(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _draw_array_view(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
