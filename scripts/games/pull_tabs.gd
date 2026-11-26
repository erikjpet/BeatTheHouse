class_name PullTabsGame
extends "res://scripts/games/pull_tab_room_game.gd"

# Bar pull-tab module. It owns finite deal state in the current environment and
# maps the cabinet surface into the shared GameModule/RunState result path.

const SYMBOLS := ["CHERRY", "LEMON", "BELL", "BAR", "7", "CROWN"]
const TICKET_STACK_VIEW_LIMIT := 9
const TRAY_COLUMN_VIEW_LIMIT := 8
const SORTED_PILE_VIEW_LIMIT := 10
const ACTIVE_DISPENSE_EVENT_LIMIT := 48
const SORT_TICKET_ACTION := "sort_tab_ticket"
const RendererScript := preload("res://scripts/games/pull_tab_renderer.gd")
const PULL_TAB_DISPENSE_CHANNEL := MachineSpecScript.PULL_TAB_DISPENSE_CHANNEL
const PULL_TAB_DISPENSE_EVENT_DURATION_MSEC := MachineSpecScript.PULL_TAB_DISPENSE_EVENT_DURATION_MSEC
const PULL_TAB_REVEAL_CHANNEL := MachineSpecScript.PULL_TAB_REVEAL_CHANNEL
const PULL_TAB_REVEAL_TOTAL_MSEC := MachineSpecScript.PULL_TAB_REVEAL_TOTAL_MSEC
const PULL_TAB_FILE_CHANNEL := MachineSpecScript.PULL_TAB_FILE_CHANNEL
const PULL_TAB_FILE_DURATION_MSEC := 560
const PULL_TAB_BUY_SET_ACTION := "buy_tab_set"
const PULL_TAB_COLLECT_TRAY_ACTION := MachineSpecScript.PULL_TAB_COLLECT_TRAY_ACTION
const PULL_TAB_FILE_TICKET_ACTION := MachineSpecScript.PULL_TAB_FILE_TICKET_ACTION
const PULL_TAB_AUTO_OPEN_ACTION := MachineSpecScript.PULL_TAB_AUTO_OPEN_ACTION
const PULL_TAB_AUTO_OPEN_INITIAL_DELAY_MSEC := 90
const PULL_TAB_AUTO_OPEN_STEP_GAP_MSEC := 80
const PULL_TAB_GLIMMER_MIN_INTERVAL_MSEC := 25000
const PULL_TAB_GLIMMER_MAX_INTERVAL_MSEC := 35000
const PULL_TAB_GLIMMER_VISIBLE_MSEC := 1100
const PULL_TAB_GLIMMER_CANDIDATE_LIMIT := 16
const PULL_TAB_GLIMMER_UI_STATE_KEYS := [
	"pull_tab_glimmer_initialized",
	"pull_tab_glimmer_enabled",
	"pull_tab_glimmer_session_ordinal",
	"pull_tab_glimmer_event_ordinal",
	"pull_tab_glimmer_next_due_msec",
	"pull_tab_glimmer_hide_due_msec",
]
const PULL_TAB_AUTO_TICK_STATE_KEYS := [
	"pull_tab_auto_open_active",
	"pull_tab_auto_open_next_msec",
	"pull_tab_glimmer_initialized",
	"pull_tab_glimmer_enabled",
	"pull_tab_glimmer_session_ordinal",
	"pull_tab_glimmer_event_ordinal",
	"pull_tab_glimmer_next_due_msec",
	"pull_tab_glimmer_hide_due_msec",
]
const XRAY_GLASSES_ITEM_ID := "xray_glasses"
const TAB_DETECTOR_ITEM_ID := "tab_detector"
const TAROT_CARD_ITEM_ID := "tarot_card"
const TAB_DETECTOR_BASE_HEAT := 4
const TAB_PEEK_BASE_HEAT := 8
const TAB_PEEK_SUCCESS_PERCENT := 50
const PULL_TAB_LOW_TICKET_RATIO := 0.12
const PULL_TAB_THIN_TICKET_RATIO := 0.25
const PULL_TAB_LAST_TICKET_COUNT := 12
var _pull_tab_glimmer_session_ordinal := 0
var _pull_tab_glimmer_target: Dictionary = {}
var _pull_tab_glimmer_target_machine_fingerprint := ""


# Creates the entry message from the deal machine already generated with the room.
func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	_pull_tab_glimmer_session_ordinal += 1
	_pull_tab_glimmer_target = {}
	_pull_tab_glimmer_target_machine_fingerprint = ""
	var machine := _ensure_machine_state(run_state, environment, false)
	var result := super.enter(run_state, environment)
	result["message"] = "%s lays out four pull-tab deal rows for sale at the counter: sealed paper windows, posted prices, and a flare chart under glass." % _counter_staff_label(environment)
	result["pull_tab_machine_name"] = str(machine.get("machine_name", "Pull-Tab Counter Stock"))
	return result


# Provides display/input state for the pull-tab cabinet without mutating state.
func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var wager_currency := GameModule.presentation_currency_for_game(run_state, get_id(), environment)
	var pending_payout := _pending_winner_payout(machine)
	var stack_count := _array_size(machine.get("ticket_stack", []))
	var tray_count := _array_size(machine.get("tray_stack", []))
	var winner_count := _array_size(machine.get("winner_pile", []))
	var loser_count := _array_size(machine.get("loser_pile", [])) + maxi(0, int(machine.get("loser_archive_count", 0)))
	var dispense_events := _dispense_event_view_list(machine, ui_state)
	var dispense_duration_msec := _dispense_animation_duration_msec(dispense_events)
	var last_dispense_id := str(machine.get("last_dispense_id", machine.get("last_ticket_id", "")))
	if dispense_events.is_empty():
		last_dispense_id = ""
	var dispense_started_msec := int(machine.get("dispense_started_msec", 0)) if not last_dispense_id.is_empty() else 0
	var reveal_animation_id := str(ui_state.get("pull_tab_reveal_animation_id", ""))
	var reveal_ticket_id := str(ui_state.get("pull_tab_reveal_animation_ticket_id", ""))
	var file_animation_id := str(ui_state.get("pull_tab_file_animation_id", ""))
	var file_ticket := _pt_copy_dict(ui_state.get("pull_tab_file_animation_ticket", {}))
	var file_pile := str(ui_state.get("pull_tab_file_animation_pile", ""))
	var item_surface := _pull_tab_item_surface_state(machine, run_state)
	var presentation_time_msec := _pull_tab_presentation_time_msec(ui_state, run_state)
	# Build each visible receipt once. The old aggregate ripped-tabs field was
	# unused by the renderer and rebuilt both piles a second time on every click.
	var winner_pile_views := _ticket_pile_view_list(machine, "winner_pile")
	var loser_pile_views := _ticket_pile_view_list(machine, "loser_pile")
	var counter_ritual := _pull_tab_counter_ritual(machine, run_state, environment)
	var glimmer_projection := _pull_tab_glimmer_public_projection(machine, environment, ui_state)
	return GameModule.surface_spec({
		"surface_renderer": "pull_tab_machine",
		"surface_life": "counter_merchandise",
		"surface_cast": "counter_staff_and_stock",
		"counter_ritual": counter_ritual,
		"counter_phase": str(counter_ritual.get("phase", "selection")),
		"counter_actors": counter_ritual.get("actors", []),
		"counter_objects": counter_ritual.get("objects", []),
		"counter_attention": counter_ritual.get("attention", {}),
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_time_msec": int(ui_state.get("surface_time_msec", dispense_started_msec)),
		"surface_presentation_time_msec": presentation_time_msec,
		"surface_animates_idle": true,
		"surface_embeds_outcomes": true,
		"surface_ui_preference_keys": PULL_TAB_GLIMMER_UI_STATE_KEYS,
		"reduce_motion": bool(ui_state.get("reduce_motion", false)),
		"machine_name": str(machine.get("machine_name", "Pull-Tab Counter Stock")),
		"wager_currency": wager_currency,
		"pull_tab_rules": "Buy a ticket, then peel its three windows top to bottom. Match three symbols on a row to win.",
		"pull_tab_format": "Deal flare: game, form, serial, ticket count, price, prize chart. Ticket: same form/serial plus three sealed windows.",
		"pull_tab_item_state": item_surface,
		"pull_tab_deals": _deal_view_list(machine, run_state, item_surface),
		"pull_tab_stack": _ticket_stack_view(machine, ui_state),
		"pull_tab_tray_stack": _tray_ticket_view_list(machine),
		"pull_tab_tray_column_counts": _tray_column_counts(machine),
		"pull_tab_winner_pile": winner_pile_views,
		"pull_tab_loser_pile": loser_pile_views,
		"pull_tab_pending_payout": pending_payout,
		"pull_tab_pending_payout_label": PlayerTextScript.format_currency_account_balance(wager_currency, pending_payout),
		"pull_tab_pending_payout_text": PlayerTextScript.format_currency_amount(wager_currency, pending_payout),
		"pull_tab_redeemable_count": winner_count,
		"pull_tab_winner_count": winner_count,
		"pull_tab_loser_count": loser_count,
		"pull_tab_stack_count": stack_count,
		"pull_tab_tray_count": tray_count,
		"pull_tab_stack_cursor": _stack_cursor(ui_state, stack_count),
		"pull_tab_active_ticket_id": _active_ticket_id(machine, ui_state),
		"pull_tab_last_ticket_id": str(machine.get("last_ticket_id", "")),
		"pull_tab_last_dispense_id": last_dispense_id,
		"pull_tab_dispense_events": dispense_events,
		"pull_tab_reveal_animation_id": reveal_animation_id,
		"pull_tab_reveal_animation_ticket_id": reveal_ticket_id,
		"pull_tab_file_animation_id": file_animation_id,
		"pull_tab_file_animation_ticket": file_ticket,
		"pull_tab_file_animation_pile": file_pile,
		"pull_tab_auto_open_active": bool(ui_state.get("pull_tab_auto_open_active", false)),
		"pull_tab_glimmer": glimmer_projection,
		"native_selected_surface_actions": _selected_surface_actions(ui_state),
		"surface_action_bindings": {
			"legal": {"action": "pull_tab_buy", "index": 0},
			"cheat": {"action": "pull_tab_detector_scan", "index": 0},
		},
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				PULL_TAB_DISPENSE_CHANNEL,
				last_dispense_id,
				dispense_duration_msec,
				dispense_started_msec,
				{
					"clock_source": "presentation",
					"metadata": {"event_count": dispense_events.size(), "ticket_id": str(machine.get("last_ticket_id", ""))},
				}
			),
			GameModule.surface_animation_channel(
				PULL_TAB_REVEAL_CHANNEL,
				reveal_animation_id,
				PULL_TAB_REVEAL_TOTAL_MSEC,
				0,
				{"metadata": {"ticket_id": reveal_ticket_id}}
			),
			GameModule.surface_animation_channel(
				PULL_TAB_FILE_CHANNEL,
				file_animation_id,
				PULL_TAB_FILE_DURATION_MSEC,
				0,
				{"metadata": {"ticket_id": str(file_ticket.get("id", "")), "pile": file_pile}}
			),
		],
		"surface_action_blocks": [
			{"action": PULL_TAB_COLLECT_TRAY_ACTION, "while_animation": PULL_TAB_DISPENSE_CHANNEL},
			{"actions": ["pull_tab_reveal_next", "pull_tab_next_unopened", PULL_TAB_FILE_TICKET_ACTION, "pull_tab_prev", "pull_tab_next"], "while_animation": PULL_TAB_REVEAL_CHANNEL},
			{"actions": ["pull_tab_reveal_next", "pull_tab_next_unopened", PULL_TAB_FILE_TICKET_ACTION, "pull_tab_prev", "pull_tab_next"], "while_animation": PULL_TAB_FILE_CHANNEL},
		],
		"surface_ui_protected_regions": [
			{"x": 20, "y": 8, "w": 392, "h": 414},
			{"x": 430, "y": 18, "w": 448, "h": 394},
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "pull_tab_dispenser",
			"selection_seed": run_state.seed_value if run_state != null else 1,
			"action_cues": {
				"pull_tab_buy": "ticket_dispenser",
				"pull_tab_buy_all": "ticket_dispenser",
				PULL_TAB_COLLECT_TRAY_ACTION: "ticket_navigation",
				"pull_tab_reveal_next": "ticket_peel",
				PULL_TAB_AUTO_OPEN_ACTION: "ticket_navigation",
				PULL_TAB_FILE_TICKET_ACTION: "ticket_navigation",
				"pull_tab_prev": "ticket_navigation",
				"pull_tab_next": "ticket_navigation",
				"pull_tab_latest": "ticket_navigation",
				"pull_tab_next_unopened": "ticket_navigation",
				"pull_tab_detector_scan": "machine_button",
			},
			"state_sync": {
				"method": "pull_tab_dispense_state",
				"animation_channel": PULL_TAB_DISPENSE_CHANNEL,
			},
		}),
	})


# Draws the pull-tab merchandise display, active stack, and sorted piles.
func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	return RendererScript.draw(surface, surface_state)


# Resolves the room-side redemption hook. Payouts only happen here.
func environment_action_command(hook_id: String, action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	if hook_id != REDEEM_HOOK_ID or action_id != REDEEM_ACTION_ID:
		return {"handled": false}
	return {
		"handled": true,
		"result": _resolve_winner_redemption(run_state, environment, rng),
	}


# Active item entry point for pull-tab-specific gear. Keep immediate use/toggle
# behavior here and ticket-purchase effects in _apply_pull_tab_item_purchase_effects.
func active_item_command(item_id: String, run_state: RunState, environment: Dictionary, _rng: RngStream) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	match item_id:
		TAB_DETECTOR_ITEM_ID:
			return _toggle_tab_detector_active_item(machine, run_state, environment)
		TAROT_CARD_ITEM_ID:
			return _arm_tarot_card_active_item(machine, run_state, environment)
	return {"handled": false}


func _resolve_tab_detector_scan(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var item_state := _pull_tab_item_state(machine)
	var has_detector := _run_has_item(run_state, TAB_DETECTOR_ITEM_ID)
	var next_active := false
	var peek_succeeded := false
	var peek_count := maxi(0, int(item_state.get("tab_detector_peek_count", 0)))
	var peek_highlight_index := -1
	var base_heat := 0
	if has_detector:
		next_active = not bool(item_state.get("tab_detector_active", false))
		item_state["tab_detector_active"] = next_active
		item_state["tab_detector_peek_highlight_index"] = -1
	else:
		base_heat = TAB_PEEK_BASE_HEAT + peek_count
		peek_succeeded = _tab_peek_succeeds(run_state, peek_count, rng)
		peek_count += 1
		peek_highlight_index = _tab_detector_highlight_deal_index(machine) if peek_succeeded else -1
		item_state["tab_detector_peek_count"] = peek_count
		item_state["tab_detector_peek_success_count"] = maxi(0, int(item_state.get("tab_detector_peek_success_count", 0))) + (1 if peek_succeeded else 0)
		item_state["tab_detector_peek_last_succeeded"] = peek_succeeded
		item_state["tab_detector_peek_highlight_index"] = peek_highlight_index
	machine["item_state"] = item_state
	_write_machine_state(environment, machine, run_state)
	var heat: Dictionary = _pull_tab_peek_heat(base_heat, run_state, environment) if not has_detector else _pull_tab_cheat_heat(0, 1, run_state, environment)
	var suspicion_delta := int(heat.get("suspicion_delta", 0))
	var bankroll_delta := int(heat.get("bankroll_delta", 0))
	var security_message := str(heat.get("security_message", ""))
	var message := ""
	if has_detector:
		message = "Tab Detector switched on. The nearest live column is highlighted." if next_active else "Tab Detector switched off."
	elif peek_succeeded:
		message = "You peek through the flare case and catch a useful pulse on column %d." % (peek_highlight_index + 1)
	else:
		message = "You peek through the flare case, but the ticket stacks give you nothing."
	if suspicion_delta > 0:
		message += " Heat rises +%d." % suspicion_delta
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "tab_detector_scan",
		"item_id": TAB_DETECTOR_ITEM_ID,
		"item_owned": has_detector,
		"active": next_active,
		"peek_succeeded": peek_succeeded,
		"peek_count": peek_count,
		"peek_highlight_index": peek_highlight_index,
		"bankroll_delta": bankroll_delta,
		"currency": GameModule.presentation_currency_for_game(run_state, get_id(), environment),
		"currency_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"base_heat": base_heat,
		"base_suspicion_delta": int(heat.get("base_suspicion_delta", base_heat)),
		"pit_boss_watched": bool(heat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(heat.get("pit_boss_heat_bonus", 0)),
		"environment_id": str(environment.get("id", "")),
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	deltas["ended"] = bool(heat.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": "tab_detector_scan",
		"action_kind": "cheat",
		"stake": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"message": message,
	})
	result["pull_tab_detector_active"] = next_active
	result["pull_tab_peek_succeeded"] = peek_succeeded
	result["pull_tab_peek_count"] = peek_count
	result["pull_tab_peek_highlight_index"] = peek_highlight_index
	result["pull_tab_base_heat"] = base_heat
	result["pull_tab_pit_boss_watched"] = bool(heat.get("pit_boss_watched", false))
	var tutorial_lessons_completed: Dictionary = run_state.narrative_flags.get("tutorial_lessons_completed", {}) if run_state != null and typeof(run_state.narrative_flags.get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
	if run_state != null \
			and run_state.is_tutorial_run() \
			and str(environment.get("archetype_id", "")) == "gas_station_casino" \
			and not bool(tutorial_lessons_completed.get("tutorial_gas_peek", false)) \
			and not has_detector \
			and peek_count > 0 \
			and peek_count <= 4:
		var remaining_peeks := 4 - peek_count
		# Keep repeated Peek coaching in one live event. Further Peeks advance that
		# event in place, so input never leaves old reminders queued behind the current
		# one. The final Peek retires it before the Heat follow-up is presented.
		result["tutorial_dialogue_request"] = {
			"dialogue_id": "tutorial_pal_guidance" if remaining_peeks > 0 else "",
			"node_id": "gas_peek_again_%d" % remaining_peeks if remaining_peeks > 0 else "",
			"queue_key": "tutorial_intervention:pull_tab_peek_progress",
			"source_kind": "tutorial_intervention",
			"speaker": "Pal",
			"advance_existing": remaining_peeks > 0,
			"clear_existing": remaining_peeks <= 0,
		}
	GameModule.apply_result(run_state, result, rng)
	return result


static func peek_succeeds_for_roll(roll: int) -> bool:
	return clampi(roll, 1, 100) <= TAB_PEEK_SUCCESS_PERCENT


func _tab_peek_succeeds(run_state: RunState, peek_index: int, rng: RngStream) -> bool:
	if run_state != null and run_state.is_tutorial_run():
		var scripted_results: Array = run_state.challenge_modifiers().get("tutorial_pull_tab_peek_results", []) if typeof(run_state.challenge_modifiers().get("tutorial_pull_tab_peek_results", [])) == TYPE_ARRAY else []
		if peek_index >= 0 and peek_index < scripted_results.size():
			return bool(scripted_results[peek_index])
	if rng == null:
		return false
	return peek_succeeds_for_roll(rng.randi_range(1, 100))


func coach_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return {}
	var target_consumed := false
	var item_state := _pull_tab_item_state(machine)
	for target_value in _dictionary_array(item_state.get("xray_targets", [])):
		if bool((target_value as Dictionary).get("consumed", false)):
			target_consumed = true
			break
	return {
		"scripted_target_consumed": target_consumed,
		"scripted_target_filed": _scripted_xray_target_filed(machine),
		"scripted_target_ready_to_file": _scripted_xray_target_ready_to_file(machine, ui_state),
		"tray_count": _array_size(machine.get("tray_stack", [])),
		"play_stack_count": _array_size(machine.get("ticket_stack", [])),
		"pending_payout": _pending_winner_payout(machine),
		"redeemable_count": _array_size(machine.get("winner_pile", [])),
		"peek_count": maxi(0, int(item_state.get("tab_detector_peek_count", 0))),
		"peek_success_count": maxi(0, int(item_state.get("tab_detector_peek_success_count", 0))),
		"peek_last_succeeded": bool(item_state.get("tab_detector_peek_last_succeeded", false)),
	}


# Observe durable tutorial payment without normalizing stock or materializing a
# missing machine. Compact saves keep player piles in the per-origin record.
func tutorial_redemption_completed(run_state: RunState, environment: Dictionary) -> bool:
	if run_state == null or not run_state.is_tutorial_run() or environment.get("archetype_id", "") != "gas_station_casino":
		return false
	var states_value: Variant = environment.get("game_states")
	if typeof(states_value) != TYPE_DICTIONARY:
		return false
	var machine_value: Variant = (states_value as Dictionary).get(get_id())
	if typeof(machine_value) != TYPE_DICTIONARY:
		return false
	var machine: Dictionary = machine_value
	if machine.get("schema") != "pull_tab_machine_state" or not _tutorial_redemption_integer(machine.get("version")) or machine.get("version") != 1:
		return false
	var item_value: Variant = machine.get("item_state")
	if typeof(item_value) != TYPE_DICTIONARY:
		return false
	var targets_value: Variant = (item_value as Dictionary).get("xray_targets")
	var redeemed_value: Variant = machine.get("redeemed_pile")
	if typeof(targets_value) != TYPE_ARRAY or typeof(redeemed_value) != TYPE_ARRAY:
		return false
	var targets: Array = targets_value
	var redeemed: Array = redeemed_value
	if targets.is_empty() or targets.size() > XRAY_TARGET_COUNT or redeemed.is_empty() or redeemed.size() > 24:
		return false
	var origins_value: Variant = run_state.portable_ticket_piles.get(get_id(), {})
	if typeof(origins_value) != TYPE_DICTIONARY:
		return false
	var portable_value: Variant = (origins_value as Dictionary).get(RunState.portable_ticket_origin_key(environment), {})
	if typeof(portable_value) != TYPE_DICTIONARY:
		return false
	var portable: Dictionary = portable_value
	var winners_value: Variant = portable.get("winner_pile") if not portable.is_empty() else machine.get("winner_pile")
	if typeof(winners_value) != TYPE_ARRAY or not (winners_value as Array).is_empty():
		return false
	var consumed_targets := {}
	for target_value in targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			return false
		var target: Dictionary = target_value
		var deal_index: Variant = target.get("deal_index")
		var ticket_number: Variant = target.get("ticket_number")
		if typeof(target.get("consumed")) != TYPE_BOOL or not _tutorial_redemption_integer(deal_index) or deal_index >= PULL_TAB_MACHINE_COLUMN_COUNT or not _tutorial_redemption_integer(ticket_number) or ticket_number <= 0:
			return false
		if target.get("consumed") == true:
			consumed_targets["%d:%d" % [int(deal_index), int(ticket_number)]] = true
	if consumed_targets.is_empty():
		return false
	var matched := false
	for receipt_value in redeemed:
		if typeof(receipt_value) != TYPE_DICTIONARY:
			return false
		var receipt: Dictionary = receipt_value
		var deal_index: Variant = receipt.get("deal_index")
		var ticket_number: Variant = receipt.get("ticket_number_value", receipt.get("ticket_number"))
		var payout: Variant = receipt.get("payout")
		if not _tutorial_redemption_integer(deal_index) or deal_index >= PULL_TAB_MACHINE_COLUMN_COUNT or not _tutorial_redemption_integer(ticket_number) or ticket_number <= 0 or not _tutorial_redemption_integer(payout) or payout <= 0:
			return false
		if consumed_targets.has("%d:%d" % [int(deal_index), int(ticket_number)]):
			matched = true
	return matched


func _tutorial_redemption_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= 9007199254740991.0 and number == floor(number)


func _scripted_xray_target_ready_to_file(machine: Dictionary, ui_state: Dictionary) -> bool:
	for ticket_value in _ticket_stack_view(machine, ui_state):
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		if _ticket_is_consumed_xray_target(machine, ticket) and bool(ticket.get("fully_revealed", false)):
			return true
	return false


func _scripted_xray_target_filed(machine: Dictionary) -> bool:
	for pile_name in ["winner_pile", "redeemed_pile"]:
		for ticket_value in _array_view(machine.get(pile_name, [])):
			if typeof(ticket_value) == TYPE_DICTIONARY and _ticket_is_consumed_xray_target(machine, ticket_value as Dictionary):
				return true
	return false


# Compacted and legacy pull-tab saves can omit the per-ticket convenience flag
# while retaining the authoritative consumed X-ray target in item_state. Coach
# progression must follow that canonical identity or the real tutorial can
# reveal the scripted winner and still strand the File highlight on Peel.
func _ticket_is_consumed_xray_target(machine: Dictionary, ticket: Dictionary) -> bool:
	if bool(ticket.get("xray_target_consumed", false)):
		return true
	var ticket_number := int(ticket.get("ticket_number_value", 0))
	if ticket_number <= 0:
		ticket_number = int(str(ticket.get("ticket_number", "")).replace("#", ""))
	var deal_index := int(ticket.get("deal_index", -1))
	if ticket_number <= 0 or deal_index < 0:
		return false
	var item_state := _pull_tab_item_state(machine)
	for target_value in _dictionary_array(item_state.get("xray_targets", [])):
		var target: Dictionary = target_value
		if bool(target.get("consumed", false)) \
				and int(target.get("deal_index", -1)) == deal_index \
				and int(target.get("ticket_number", -1)) == ticket_number:
			return true
	return false


func _toggle_tab_detector_active_item(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if run_state == null or not run_state.inventory.has(TAB_DETECTOR_ITEM_ID):
		return {"handled": true, "message": "You do not have the Tab Detector."}
	var item_state := _pull_tab_item_state(machine)
	var next_active := not bool(item_state.get("tab_detector_active", false))
	item_state["tab_detector_active"] = next_active
	machine["item_state"] = item_state
	_write_machine_state(environment, machine, run_state)
	var message := "Tab Detector switched on. Winning buys will draw rising heat." if next_active else "Tab Detector switched off."
	return _pull_tab_active_item_result(TAB_DETECTOR_ITEM_ID, "toggle_tab_detector", next_active, message, environment, [])


func _arm_tarot_card_active_item(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if run_state == null or not run_state.inventory.has(TAROT_CARD_ITEM_ID):
		return {"handled": true, "message": "You do not have a Tarot Card."}
	var item_state := _pull_tab_item_state(machine)
	item_state["tarot_armed"] = true
	item_state["tarot_read_count"] = TAROT_READING_COUNT
	machine["item_state"] = item_state
	_write_machine_state(environment, machine, run_state)
	var message := "Tarot Card armed. The next bought ticket burns itself and reads the five tickets behind it."
	return _pull_tab_active_item_result(TAROT_CARD_ITEM_ID, "arm_tarot_card", true, message, environment, [TAROT_CARD_ITEM_ID])


func _pull_tab_active_item_result(item_id: String, action_id: String, active: bool, message: String, environment: Dictionary, inventory_remove: Array) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	if not inventory_remove.is_empty():
		deltas["inventory_remove"] = inventory_remove.duplicate()
	deltas["story_log"] = [{
		"type": "active_item",
		"game_id": get_id(),
		"item_id": item_id,
		"active": active,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	}]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "active_item",
		"source_id": item_id,
		"game_id": get_id(),
		"item_id": item_id,
		"action_id": action_id,
		"action_kind": "active_item",
		"bankroll_delta": 0,
		"suspicion_delta": 0,
		"deltas": deltas,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	return {"handled": true, "environment_changed": true, "result": result, "message": message}


# Converts dispenser clicks into UI-local reveal state or shared action results.
func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var deals := _deal_array(machine.get("deals", []))
	match surface_action:
		"pull_tab_buy":
			if index < 0 or index >= deals.size():
				return {"handled": true, "message": "That deal row is empty."}
			var deal: Dictionary = deals[index]
			var price := int(deal.get("price", 1))
			if int(deal.get("remaining", 0)) <= 0:
				return {"handled": true, "message": "%s is sold out." % str(deal.get("display_name", "That deal"))}
			if run_state != null and run_state.wager_capacity_for_game(get_id(), environment) < price:
				return {"handled": true, "message": "Not enough bankroll for a %s ticket." % str(deal.get("display_name", "pull-tab"))}
			return {
				"handled": true,
				"ui_state": _deal_ui_state(ui_state, index),
				"action_id": "buy_tab",
				"action_kind": "legal",
				"resolve": true,
				"direct_resolve": true,
				"set_stake": price,
				"selected_index": index,
				"message": "%s takes payment and slides over a %s pull tab." % [_counter_staff_label(environment), str(deal.get("display_name", "pull-tab"))],
			}
		"pull_tab_buy_all":
			var available_indices: Array = []
			var total_price := 0
			for deal_index in range(mini(PULL_TAB_MACHINE_COLUMN_COUNT, deals.size())):
				var deal: Dictionary = deals[deal_index]
				var price := maxi(1, int(deal.get("price", 1)))
				if int(deal.get("remaining", 0)) <= 0 or run_state.wager_capacity_for_game(get_id(), environment) < total_price + price:
					continue
				available_indices.append(deal_index)
				total_price += price
			if available_indices.is_empty():
				return {"handled": true, "message": "No full-row pull is affordable right now."}
			var next_state := ui_state.duplicate(true)
			next_state["pull_tab_deal_indices"] = available_indices
			next_state["pull_tab_stack_cursor"] = 0
			return {
				"handled": true,
				"ui_state": next_state,
				"action_id": PULL_TAB_BUY_SET_ACTION,
				"action_kind": "legal",
				"resolve": true,
				"set_stake": total_price,
				"selected_index": available_indices[0],
				"message": "The master button starts a four-column dispense cycle.",
			}
		"pull_tab_detector_scan":
			var detector_owned := _run_has_item(run_state, TAB_DETECTOR_ITEM_ID)
			var command := {
				"handled": true,
				"action_id": "tab_detector_scan",
				"action_kind": "cheat",
				"skip_stake_validation": true,
				"selected_index": 0,
				"message": "Tab Detector toggled." if detector_owned else "Peek selected. Press PEEK again to risk drawing attention.",
			}
			if detector_owned:
				command["resolve"] = true
				command["direct_resolve"] = true
			return command
		PULL_TAB_COLLECT_TRAY_ACTION:
			return _collect_tray_surface_command(machine, ui_state, run_state, environment)
		"pull_tab_reveal_next":
			return _reveal_next_command(machine, ui_state, run_state, environment)
		PULL_TAB_FILE_TICKET_ACTION:
			return _file_ticket_command(machine, ui_state)
		"pull_tab_prev":
			return _stack_navigation_command(machine, ui_state, -1)
		"pull_tab_next":
			return _stack_navigation_command(machine, ui_state, 1)
		"pull_tab_latest":
			return _stack_cursor_command(machine, ui_state, 0)
		"pull_tab_next_unopened":
			return _next_unopened_command(machine, ui_state)
		PULL_TAB_AUTO_OPEN_ACTION:
			return _toggle_auto_open_command(machine, ui_state)
	return {"handled": false}


func checkpoint_surface_ui_state(ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> void:
	var reveals := _pt_copy_dict(ui_state.get("pull_tab_reveals", {}))
	if reveals.is_empty():
		return
	var machine := _ensure_machine_state(run_state, environment, true)
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	var changed := false
	for index in range(tickets.size()):
		var ticket: Dictionary = tickets[index]
		var ticket_id := str(ticket.get("id", ""))
		var rows := _pt_copy_array(ticket.get("rows", []))
		var revealed := clampi(int(reveals.get(ticket_id, ticket.get("revealed_count", 0))), 0, rows.size())
		if revealed == int(ticket.get("revealed_count", 0)):
			continue
		ticket["revealed_count"] = revealed
		ticket["fully_revealed"] = revealed >= rows.size()
		tickets[index] = ticket
		changed = true
	if changed:
		machine["ticket_stack"] = tickets
		_write_machine_state(environment, machine, run_state)


func surface_uses_auto_tick() -> bool:
	return true


func surface_auto_tick_may_be_active(retained_ui_state: Dictionary) -> bool:
	return (
		not bool(retained_ui_state.get("pull_tab_glimmer_initialized", false))
		or bool(retained_ui_state.get("pull_tab_glimmer_enabled", false))
		or bool(retained_ui_state.get("pull_tab_auto_open_active", false))
	)


func surface_needs_auto_tick(ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> bool:
	var glimmer_surface_time := _pull_tab_glimmer_surface_time_msec(ui_state)
	var initialized := bool(ui_state.get("pull_tab_glimmer_initialized", false))
	var session_matches := int(ui_state.get("pull_tab_glimmer_session_ordinal", -1)) == _pull_tab_glimmer_session_ordinal
	if not initialized or not session_matches:
		return true
	if bool(ui_state.get("pull_tab_glimmer_enabled", false)):
		var hide_due_msec := int(ui_state.get("pull_tab_glimmer_hide_due_msec", 0))
		var glimmer_due_msec := int(ui_state.get("pull_tab_glimmer_next_due_msec", 0))
		if (hide_due_msec > 0 and glimmer_surface_time >= hide_due_msec) or glimmer_due_msec <= 0 or glimmer_surface_time >= glimmer_due_msec:
			return true
	if not bool(ui_state.get("pull_tab_auto_open_active", false)):
		return false
	var auto_open_surface_time := _pull_tab_surface_time_msec(ui_state)
	var auto_open_due_msec := int(ui_state.get("pull_tab_auto_open_next_msec", 0))
	return auto_open_due_msec <= 0 or auto_open_surface_time >= auto_open_due_msec


func surface_auto_tick_state_keys() -> Array:
	return PULL_TAB_AUTO_TICK_STATE_KEYS


func surface_auto_action_command(ui_state: Dictionary, _run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	var auto_open_surface_time := _pull_tab_surface_time_msec(ui_state)
	var glimmer_surface_time := _pull_tab_glimmer_surface_time_msec(ui_state)
	var machine := _read_machine_state(_run_state, environment)
	var auto_open_active := bool(ui_state.get("pull_tab_auto_open_active", false))
	var auto_open_next_msec := int(ui_state.get("pull_tab_auto_open_next_msec", 0))
	var auto_open_due := auto_open_active and (auto_open_next_msec <= 0 or auto_open_surface_time >= auto_open_next_msec)
	var glimmer_command := _pull_tab_glimmer_auto_command(ui_state, _run_state, environment, machine, glimmer_surface_time)
	if bool(glimmer_command.get("handled", false)):
		return glimmer_command
	if not auto_open_due:
		return {"handled": false}
	var tickets := _array_view(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return _stop_auto_open_command(ui_state, "Auto Open finished. No purchased tickets remain.")
	var cursor := _stack_cursor(ui_state, tickets.size())
	var ticket: Dictionary = tickets[cursor] if cursor >= 0 and cursor < tickets.size() and typeof(tickets[cursor]) == TYPE_DICTIONARY else {}
	var ticket_id := str(ticket.get("id", ""))
	var rows := _array_view(ticket.get("rows", []))
	var reveals_value: Variant = ui_state.get("pull_tab_reveals", {})
	var revealed_count := clampi(int(ticket.get("revealed_count", 0)), 0, rows.size())
	if typeof(reveals_value) == TYPE_DICTIONARY:
		revealed_count = maxi(revealed_count, clampi(int((reveals_value as Dictionary).get(ticket_id, 0)), 0, rows.size()))
	var command := _file_ticket_command(machine, ui_state) if not ticket_id.is_empty() and revealed_count >= rows.size() else _reveal_next_command(machine, ui_state, _run_state, environment)
	var command_state: Dictionary = command.get("ui_state", {}) if typeof(command.get("ui_state", {})) == TYPE_DICTIONARY else ui_state.duplicate(true)
	command_state["pull_tab_auto_open_active"] = true
	var action_delay := PULL_TAB_FILE_DURATION_MSEC if str(command.get("action_id", "")) == SORT_TICKET_ACTION else PULL_TAB_REVEAL_TOTAL_MSEC
	command_state["pull_tab_auto_open_next_msec"] = auto_open_surface_time + action_delay + PULL_TAB_AUTO_OPEN_STEP_GAP_MSEC
	command["ui_state"] = command_state
	if str(command.get("action_id", "")) == SORT_TICKET_ACTION:
		command["surface_audio_cue"] = "ticket_navigation"
		command["surface_audio_action"] = PULL_TAB_FILE_TICKET_ACTION
	elif command.has("ui_state"):
		if str(command.get("surface_audio_cue", "")).is_empty():
			command["surface_audio_cue"] = "ticket_peel"
		command["surface_audio_action"] = "pull_tab_reveal_next"
	return GameModule.surface_command(command)


func _pull_tab_glimmer_auto_command(ui_state: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, surface_time: int) -> Dictionary:
	if _pull_tab_glimmer_session_ordinal <= 0:
		_pull_tab_glimmer_session_ordinal = 1
	var initialized := (
		bool(ui_state.get("pull_tab_glimmer_initialized", false))
		and int(ui_state.get("pull_tab_glimmer_session_ordinal", -1)) == _pull_tab_glimmer_session_ordinal
	)
	if not initialized:
		_pull_tab_glimmer_target = {}
		_pull_tab_glimmer_target_machine_fingerprint = ""
		var initialized_state := ui_state.duplicate(true)
		initialized_state["pull_tab_glimmer_initialized"] = true
		initialized_state["pull_tab_glimmer_enabled"] = true
		initialized_state["pull_tab_glimmer_session_ordinal"] = _pull_tab_glimmer_session_ordinal
		initialized_state["pull_tab_glimmer_event_ordinal"] = 0
		initialized_state["pull_tab_glimmer_next_due_msec"] = surface_time + _pull_tab_glimmer_interval_msec(
			run_state,
			environment,
			machine,
			_pull_tab_glimmer_session_ordinal,
			0
		)
		initialized_state["pull_tab_glimmer_hide_due_msec"] = 0
		return GameModule.surface_command({
			"handled": true,
			"surface_transient": true,
			"ui_state": initialized_state,
		})
	if not bool(ui_state.get("pull_tab_glimmer_enabled", false)):
		return {"handled": false}
	var hide_due_msec := int(ui_state.get("pull_tab_glimmer_hide_due_msec", 0))
	if hide_due_msec > 0 and surface_time >= hide_due_msec:
		_pull_tab_glimmer_target = {}
		_pull_tab_glimmer_target_machine_fingerprint = ""
		var hidden_state := ui_state.duplicate(true)
		hidden_state["pull_tab_glimmer_hide_due_msec"] = 0
		return GameModule.surface_command({
			"handled": true,
			"surface_transient": true,
			"ui_state": hidden_state,
		})
	var next_due_msec := int(ui_state.get("pull_tab_glimmer_next_due_msec", 0))
	if next_due_msec > 0 and surface_time < next_due_msec:
		return {"handled": false}
	var event_ordinal := maxi(0, int(ui_state.get("pull_tab_glimmer_event_ordinal", 0))) + 1
	var candidates := _pull_tab_glimmer_candidate_pool(machine)
	_pull_tab_glimmer_target = _pull_tab_glimmer_choose_target(candidates, run_state, environment, machine, event_ordinal)
	_pull_tab_glimmer_target_machine_fingerprint = _pull_tab_glimmer_machine_fingerprint(machine, environment) if not _pull_tab_glimmer_target.is_empty() else ""
	var event_state := ui_state.duplicate(true)
	event_state["pull_tab_glimmer_event_ordinal"] = event_ordinal
	event_state["pull_tab_glimmer_next_due_msec"] = surface_time + _pull_tab_glimmer_interval_msec(
		run_state,
		environment,
		machine,
		_pull_tab_glimmer_session_ordinal,
		event_ordinal
	)
	event_state["pull_tab_glimmer_hide_due_msec"] = surface_time + PULL_TAB_GLIMMER_VISIBLE_MSEC if not _pull_tab_glimmer_target.is_empty() else 0
	return GameModule.surface_command({
		"handled": true,
		"surface_transient": true,
		"ui_state": event_state,
	})


func _pull_tab_glimmer_interval_msec(run_state: RunState, environment: Dictionary, machine: Dictionary, session_ordinal: int, event_ordinal: int) -> int:
	var rng := _pull_tab_glimmer_rng(run_state, environment, machine, session_ordinal, event_ordinal, "interval")
	return rng.randi_range(PULL_TAB_GLIMMER_MIN_INTERVAL_MSEC, PULL_TAB_GLIMMER_MAX_INTERVAL_MSEC)


func _pull_tab_glimmer_choose_target(candidates: Array, run_state: RunState, environment: Dictionary, machine: Dictionary, event_ordinal: int) -> Dictionary:
	if candidates.is_empty():
		return {}
	var rng := _pull_tab_glimmer_rng(
		run_state,
		environment,
		machine,
		_pull_tab_glimmer_session_ordinal,
		event_ordinal,
		"target"
	)
	var candidate: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	return {
		"deal_index": int(candidate.get("deal_index", -1)),
		"deal_id": str(candidate.get("deal_id", "")),
		"serial": str(candidate.get("serial", "")),
		"ticket_number": int(candidate.get("ticket_number", -1)),
		"prize_index": int(candidate.get("prize_index", -1)),
	}


func _pull_tab_glimmer_rng(run_state: RunState, environment: Dictionary, machine: Dictionary, session_ordinal: int, event_ordinal: int, subkey: String) -> RngStream:
	var run_seed := run_state.seed_value if run_state != null else 1
	var identity := _pull_tab_glimmer_machine_fingerprint(machine, environment)
	var stream_key := "pull_tab_glimmer|%s|session:%d|event:%d|%s" % [identity, session_ordinal, event_ordinal, subkey]
	var rng := RngStream.new()
	rng.configure(RngStream.derive_seed(run_seed, session_ordinal, stream_key))
	return rng


func _pull_tab_glimmer_candidate_pool(machine: Dictionary) -> Array:
	var candidates: Array = []
	var stable_order := 0
	var deals := _array_view(machine.get("deals", []))
	for deal_index in range(deals.size()):
		if typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var deal: Dictionary = deals[deal_index]
		var sleeve := _int_array(deal.get("ticket_sleeve", []))
		var prizes := _dictionary_array(deal.get("prizes", []))
		var unit_cursor := maxi(0, int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0)))))
		for offset in range(sleeve.size()):
			var prize_index := int(sleeve[offset])
			if prize_index < 0 or prize_index >= prizes.size():
				stable_order += 1
				continue
			var payout := maxi(0, int((prizes[prize_index] as Dictionary).get("payout", 0)))
			if payout > 0:
				candidates.append({
					"deal_index": deal_index,
					"deal_id": str(deal.get("id", "")),
					"serial": str(deal.get("serial", "")),
					"ticket_number": unit_cursor + offset + 1,
					"prize_index": prize_index,
					"payout": payout,
					"stable_order": stable_order,
				})
			stable_order += 1
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_payout := int(left.get("payout", 0))
		var right_payout := int(right.get("payout", 0))
		return left_payout > right_payout if left_payout != right_payout else int(left.get("stable_order", 0)) < int(right.get("stable_order", 0))
	)
	if candidates.size() > PULL_TAB_GLIMMER_CANDIDATE_LIMIT:
		candidates.resize(PULL_TAB_GLIMMER_CANDIDATE_LIMIT)
	return candidates


func _pull_tab_glimmer_public_projection(machine: Dictionary, environment: Dictionary, ui_state: Dictionary) -> Dictionary:
	var hidden := {"visible": false, "deal_index": -1, "offset": -1}
	if (
		not bool(ui_state.get("pull_tab_glimmer_initialized", false))
		or not bool(ui_state.get("pull_tab_glimmer_enabled", false))
		or int(ui_state.get("pull_tab_glimmer_session_ordinal", -1)) != _pull_tab_glimmer_session_ordinal
		or int(ui_state.get("pull_tab_glimmer_hide_due_msec", 0)) <= _pull_tab_glimmer_surface_time_msec(ui_state)
	):
		return hidden
	if _pull_tab_glimmer_target.is_empty():
		return hidden
	if _pull_tab_glimmer_target_machine_fingerprint != _pull_tab_glimmer_machine_fingerprint(machine, environment):
		return hidden
	var deal_index := int(_pull_tab_glimmer_target.get("deal_index", -1))
	var deals := _array_view(machine.get("deals", []))
	if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
		return hidden
	var deal: Dictionary = deals[deal_index]
	if (
		str(deal.get("id", "")) != str(_pull_tab_glimmer_target.get("deal_id", ""))
		or str(deal.get("serial", "")) != str(_pull_tab_glimmer_target.get("serial", ""))
	):
		return hidden
	var ticket_number := int(_pull_tab_glimmer_target.get("ticket_number", -1))
	var offset := ticket_number - maxi(0, int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0))))) - 1
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	if offset < 0 or offset >= sleeve.size():
		return hidden
	var prize_index := int(_pull_tab_glimmer_target.get("prize_index", -1))
	if int(sleeve[offset]) != prize_index:
		return hidden
	var prizes := _dictionary_array(deal.get("prizes", []))
	if prize_index < 0 or prize_index >= prizes.size() or int((prizes[prize_index] as Dictionary).get("payout", 0)) <= 0:
		return hidden
	return {"visible": true, "deal_index": deal_index, "offset": offset}


func _pull_tab_glimmer_machine_fingerprint(machine: Dictionary, environment: Dictionary) -> String:
	var deal_identity: Array = []
	for deal_value in _array_view(machine.get("deals", [])):
		if typeof(deal_value) != TYPE_DICTIONARY:
			continue
		var deal: Dictionary = deal_value
		deal_identity.append({
			"id": str(deal.get("id", "")),
			"serial": str(deal.get("serial", "")),
			"form": str(deal.get("form", "")),
			"ticket_count": int(deal.get("ticket_count", 0)),
			"initial_removed_count": int(deal.get("initial_removed_count", 0)),
		})
	var public_identity := {
		"game_id": get_id(),
		"state_key": transient_state_key_context(),
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"world_node_id": str(environment.get("world_node_id", environment.get("node_id", ""))),
		"machine_name": str(machine.get("machine_name", "")),
		"deals": deal_identity,
	}
	return JSON.stringify(public_identity).sha256_text()


# Resolves data-authored action buttons through the same finite-deal path used
# by visible dispenser clicks.
func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id == SORT_TICKET_ACTION or action_id == REDEEM_ACTION_ID:
		return 0
	if action_id == PULL_TAB_BUY_SET_ACTION:
		return maxi(0, stake)
	if action_id != "buy_tab":
		return 0
	var machine := _ensure_machine_state(run_state, environment, false)
	var deals := _array_view(machine.get("deals", []))
	if deals.is_empty():
		return 0
	var deal_index := clampi(int(ui_state.get("pull_tab_deal_index", 0)), 0, maxi(0, deals.size() - 1))
	var deal: Dictionary = deals[deal_index]
	if int(deal.get("remaining", 0)) <= 0:
		return 0
	return maxi(0, int(deal.get("price", stake)))


# Resolves the selected row by dispensing one finite-deal ticket.
func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "tab_detector_scan":
		return _resolve_tab_detector_scan(run_state, environment, rng)
	if action_id == SORT_TICKET_ACTION:
		return _resolve_ticket_sort(run_state, environment, rng, ui_state)
	if action_id == PULL_TAB_BUY_SET_ACTION:
		return _resolve_ticket_set_purchase(run_state, environment, rng, ui_state)
	var action := _action(action_id)
	if action.is_empty():
		return _empty_result(action_id, 0, environment, "That pull-tab control is not live. Pick a stocked row.")
	var machine := _ensure_machine_state(run_state, environment, true)
	var deals := _array_view(machine.get("deals", []))
	var deal_index := clampi(int(ui_state.get("pull_tab_deal_index", 0)), 0, maxi(0, deals.size() - 1))
	if deals.is_empty():
		return _empty_result(action_id, 0, environment, "The pull-tab box is empty.")
	# Preserve the action-result/test snapshot boundary without cloning every
	# other deal and sleeve in the machine. Mutated nested fields are replaced by
	# _draw_ticket_from_deal before this shell is written back.
	var deal: Dictionary = (deals[deal_index] as Dictionary).duplicate(false)
	var price := maxi(1, int(deal.get("price", 1)))
	if run_state.wager_capacity_for_game(get_id(), environment) < price:
		return _empty_result(action_id, price, environment, "Not enough bankroll for this ticket.")
	if int(deal.get("remaining", 0)) <= 0:
		return _empty_result(action_id, price, environment, "%s is sold out." % str(deal.get("display_name", "That deal")))

	var luck_modifier := 0
	var ticket := _draw_ticket_from_deal(deal, machine, false)
	if ticket.is_empty():
		return _empty_result(action_id, price, environment, "%s is sold out." % str(deal.get("display_name", "That deal")))
	ticket["deal_index"] = deal_index
	_stamp_ticket_origin(ticket, environment)
	var item_effects := _apply_pull_tab_item_purchase_effects(machine, deal, ticket, deal_index, run_state)
	_clear_tab_peek_hint(machine)
	deals[deal_index] = deal
	machine["deals"] = deals
	var tray_stack: Array = machine.get("tray_stack", []) if typeof(machine.get("tray_stack", [])) == TYPE_ARRAY else []
	tray_stack.append(ticket)
	machine["tray_stack"] = tray_stack
	machine["tickets_sold"] = int(machine.get("tickets_sold", 0)) + 1
	machine["last_ticket_id"] = str(ticket.get("id", ""))
	machine["last_deal_id"] = str(deal.get("id", ""))
	machine["last_counter_transaction"] = {
		"kind": "purchase",
		"phase": "handover",
		"ticket_count": 1,
		"tendered": price,
		"price": price,
		"change": 0,
		"ticket_id": str(ticket.get("id", "")),
		"completed": true,
	}
	_queue_dispense_events(machine, [ticket], [deal_index], _pull_tab_presentation_time_msec(ui_state, run_state))
	_write_machine_state(environment, machine, run_state)

	var payout := int(ticket.get("payout", 0))
	var bankroll_delta := -price
	var tarot_applied := bool(item_effects.get("tarot_applied", false))
	var detector_base_heat := int(item_effects.get("tab_detector_heat", 0))
	var detector_heat: Dictionary = _pull_tab_cheat_heat(detector_base_heat, price, run_state, environment)
	var suspicion_delta := int(detector_heat.get("suspicion_delta", 0))
	var security_bankroll_delta := int(detector_heat.get("bankroll_delta", 0))
	if security_bankroll_delta != 0:
		bankroll_delta += security_bankroll_delta
	var message := "THUMP. %s ticket %s drops into the tray. Peel the tabs top to bottom." % [
		str(deal.get("display_name", "Pull-tab")),
		str(ticket.get("ticket_number", "")),
	]
	if tarot_applied:
		message += " The tarot ink burns this ticket into a loser and marks the next five pulls."
	if suspicion_delta > 0:
		message += " The detector ping draws heat +%d." % suspicion_delta
	var security_message := str(detector_heat.get("security_message", ""))
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"deal_id": str(deal.get("id", "")),
		"deal_name": str(deal.get("display_name", "")),
		"ticket_id": str(ticket.get("id", "")),
		"ticket_number": str(ticket.get("ticket_number", "")),
		"tray_count": tray_stack.size(),
		"serial": str(deal.get("serial", "")),
		"form": str(deal.get("form", "")),
		"cost": price,
		"bankroll_delta": bankroll_delta,
		"currency": GameModule.presentation_currency_for_game(run_state, get_id(), environment),
		"currency_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"luck_modifier": luck_modifier,
		"tab_detector_heat": suspicion_delta,
		"tab_detector_base_heat": detector_base_heat,
		"security_bankroll_delta": security_bankroll_delta,
		"pit_boss_watched": bool(detector_heat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(detector_heat.get("pit_boss_heat_bonus", 0)),
		"tarot_applied": tarot_applied,
		"xray_target_consumed": bool(item_effects.get("xray_target_consumed", false)),
		"environment_id": str(environment.get("id", "")),
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat" if suspicion_delta > 0 else "legal",
		"stake": price,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"message": message,
	})
	_add_ticket_result_fields(result, ticket, deal, payout, price)
	result["defer_bankroll_zero_failure"] = _should_defer_bankroll_zero_failure(run_state, bankroll_delta, machine)
	result["pull_tab_detector_base_heat"] = detector_base_heat
	result["pull_tab_security_bankroll_delta"] = security_bankroll_delta
	result["pull_tab_pit_boss_watched"] = bool(detector_heat.get("pit_boss_watched", false))
	result["suppress_music_outcome"] = true
	_advance_action_rng(rng)
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_ticket_set_purchase(run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var deals := _deal_array(machine.get("deals", []))
	if deals.is_empty():
		return _empty_result(PULL_TAB_BUY_SET_ACTION, 0, environment, "The pull-tab box is empty.")
	var requested_indices := _int_array(ui_state.get("pull_tab_deal_indices", []))
	if requested_indices.is_empty():
		for deal_index in range(mini(PULL_TAB_MACHINE_COLUMN_COUNT, deals.size())):
			requested_indices.append(deal_index)
	var tickets: Array = []
	var ticket_deals: Array = []
	var deal_indices: Array = []
	var total_price := 0
	var luck_modifier := 0
	var total_detector_base_heat := 0
	var tarot_applied_count := 0
	for deal_index in requested_indices:
		if deal_index < 0 or deal_index >= deals.size():
			continue
		var deal: Dictionary = deals[deal_index]
		var price := maxi(1, int(deal.get("price", 1)))
		if int(deal.get("remaining", 0)) <= 0:
			continue
		if run_state.wager_capacity_for_game(get_id(), environment) < total_price + price:
			continue
		var ticket := _draw_ticket_from_deal(deal, machine, false)
		if ticket.is_empty():
			continue
		ticket["deal_index"] = deal_index
		_stamp_ticket_origin(ticket, environment)
		var item_effects := _apply_pull_tab_item_purchase_effects(machine, deal, ticket, deal_index, run_state)
		if bool(item_effects.get("tarot_applied", false)):
			tarot_applied_count += 1
		var detector_heat := int(item_effects.get("tab_detector_heat", 0))
		total_detector_base_heat += detector_heat
		deals[deal_index] = deal
		tickets.append(ticket)
		ticket_deals.append(deal.duplicate(true))
		deal_indices.append(deal_index)
		total_price += price
	if tickets.is_empty():
		return _empty_result(PULL_TAB_BUY_SET_ACTION, 0, environment, "No four-column pull is affordable right now.")
	_clear_tab_peek_hint(machine)
	var tray_stack := _ticket_array(machine.get("tray_stack", []))
	for ticket in tickets:
		tray_stack.append((ticket as Dictionary).duplicate(true))
	machine["deals"] = deals
	machine["tray_stack"] = tray_stack
	machine["tickets_sold"] = int(machine.get("tickets_sold", 0)) + tickets.size()
	machine["last_ticket_id"] = str((tickets[tickets.size() - 1] as Dictionary).get("id", ""))
	machine["last_deal_id"] = str((ticket_deals[ticket_deals.size() - 1] as Dictionary).get("id", ""))
	machine["last_counter_transaction"] = {
		"kind": "purchase",
		"phase": "handover",
		"ticket_count": tickets.size(),
		"tendered": total_price,
		"price": total_price,
		"change": 0,
		"ticket_id": str((tickets[0] as Dictionary).get("id", "")),
		"completed": true,
	}
	_queue_dispense_events(machine, tickets, deal_indices, _pull_tab_presentation_time_msec(ui_state, run_state))
	_write_machine_state(environment, machine, run_state)

	var story_log: Array = []
	var ticket_numbers: Array = []
	var payout_total := 0
	for i in range(tickets.size()):
		var ticket: Dictionary = tickets[i]
		var deal: Dictionary = ticket_deals[i]
		payout_total += int(ticket.get("payout", 0))
		ticket_numbers.append(str(ticket.get("ticket_number", "")))
		story_log.append({
			"type": "game_action",
			"game_id": get_id(),
			"action_id": PULL_TAB_BUY_SET_ACTION,
			"deal_id": str(deal.get("id", "")),
			"deal_name": str(deal.get("display_name", "")),
			"ticket_id": str(ticket.get("id", "")),
			"ticket_number": str(ticket.get("ticket_number", "")),
			"serial": str(deal.get("serial", "")),
			"form": str(deal.get("form", "")),
			"cost": int(ticket.get("price", 1)),
			"bankroll_delta": -int(ticket.get("price", 1)),
			"currency": GameModule.presentation_currency_for_game(run_state, get_id(), environment),
			"currency_delta": -int(ticket.get("price", 1)),
			"suspicion_delta": 0,
			"luck_modifier": luck_modifier,
			"tab_detector_base_heat": int(ticket.get("tab_detector_heat", 0)),
			"tarot_applied": bool(ticket.get("tarot_converted", false)),
			"xray_target_consumed": bool(ticket.get("xray_target_consumed", false)),
			"environment_id": str(environment.get("id", "")),
		})
	var message := "The master button cycles %d column%s: %s drop into the tray." % [
		tickets.size(),
		"" if tickets.size() == 1 else "s",
		", ".join(ticket_numbers),
	]
	if tarot_applied_count > 0:
		message += " Tarot burns the first ticket and prints a five-pull reading."
	var detector_heat: Dictionary = _pull_tab_cheat_heat(total_detector_base_heat, total_price, run_state, environment)
	var total_suspicion_delta := int(detector_heat.get("suspicion_delta", 0))
	var security_bankroll_delta := int(detector_heat.get("bankroll_delta", 0))
	var bankroll_delta := -total_price + security_bankroll_delta
	if total_suspicion_delta > 0:
		message += " Detector heat rises +%d." % total_suspicion_delta
	var security_message := str(detector_heat.get("security_message", ""))
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = total_suspicion_delta
	deltas["story_log"] = story_log
	deltas["messages"] = [message]
	deltas["ended"] = bool(detector_heat.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": PULL_TAB_BUY_SET_ACTION,
		"action_kind": "cheat" if total_suspicion_delta > 0 else "legal",
		"stake": total_price,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": total_suspicion_delta,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"message": message,
	})
	_add_ticket_result_fields(result, tickets[0], ticket_deals[0], int((tickets[0] as Dictionary).get("payout", 0)), total_price)
	result["pull_tab_tickets"] = _pt_copy_array(tickets)
	result["pull_tab_ticket_count"] = tickets.size()
	result["pull_tab_total_cost"] = total_price
	result["pull_tab_total_hidden_payout"] = payout_total
	result["pull_tab_detector_base_heat"] = total_detector_base_heat
	result["pull_tab_security_bankroll_delta"] = security_bankroll_delta
	result["pull_tab_pit_boss_watched"] = bool(detector_heat.get("pit_boss_watched", false))
	result["defer_bankroll_zero_failure"] = _should_defer_bankroll_zero_failure(run_state, bankroll_delta, machine)
	result["suppress_music_outcome"] = true
	_advance_action_rng(rng)
	GameModule.apply_result(run_state, result, rng)
	return result


func _collect_tray_surface_command(machine: Dictionary, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var tray_stack := _ticket_array(machine.get("tray_stack", []))
	if tray_stack.is_empty():
		return GameModule.surface_command({
			"message": "No purchased pull tabs are waiting at the counter.",
		})
	var play_stack := _ticket_array(machine.get("ticket_stack", []))
	for i in range(tray_stack.size()):
		play_stack.push_front((tray_stack[i] as Dictionary).duplicate(true))
	machine["ticket_stack"] = play_stack
	machine["tray_stack"] = []
	_write_machine_state(environment, machine, run_state)
	var next_state := ui_state.duplicate(true)
	next_state["pull_tab_stack_cursor"] = 0
	return GameModule.surface_command({
		"ui_state": next_state,
		"selected_index": 0,
		"message": "You sweep %d ticket%s from the tray into your play pile." % [tray_stack.size(), "" if tray_stack.size() == 1 else "s"],
		"environment_changed": true,
	})


func _resolve_ticket_sort(run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var stack := _ticket_array(machine.get("ticket_stack", []))
	var reveals := _pt_copy_dict(ui_state.get("pull_tab_reveals", {}))
	var preferred_ticket_id := str(ui_state.get("pull_tab_sort_ticket_id", ""))
	var ordered_indices: Array = []
	if not preferred_ticket_id.is_empty():
		for index in range(stack.size()):
			if str((stack[index] as Dictionary).get("id", "")) == preferred_ticket_id:
				ordered_indices.append(index)
				break
	for index in range(stack.size()):
		if not ordered_indices.has(index):
			ordered_indices.append(index)
	for index_value in ordered_indices:
		var index := int(index_value)
		if index < 0 or index >= stack.size():
			continue
		var ticket: Dictionary = stack[index]
		var ticket_id := str(ticket.get("id", ""))
		var rows := _pt_copy_array(ticket.get("rows", []))
		if maxi(int(ticket.get("revealed_count", 0)), int(reveals.get(ticket_id, 0))) < rows.size():
			continue
		stack.remove_at(index)
		ticket["sorted"] = true
		ticket["revealed_count"] = rows.size()
		ticket["fully_revealed"] = true
		var payout := int(ticket.get("payout", 0))
		var pile_name := "winner_pile" if payout > 0 else "loser_pile"
		var pile := _ticket_array(machine.get(pile_name, []))
		pile.append(ticket)
		machine[pile_name] = pile
		machine["ticket_stack"] = stack
		_write_machine_state(environment, machine, run_state)
		var deal := _deal_for_ticket(machine, ticket)
		var message := "%s %s is a dead pull. It drops into the loser pile." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", ""))]
		if payout > 0:
			message = "%s %s wins $%d. Take it back to the counter to redeem." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", "")), payout]
		var story_entry := {
			"type": "pull_tab_sort",
			"game_id": get_id(),
			"action_id": SORT_TICKET_ACTION,
			"deal_id": str(ticket.get("deal_id", "")),
			"ticket_id": ticket_id,
			"ticket_number": str(ticket.get("ticket_number", "")),
			"serial": str(ticket.get("serial", "")),
			"form": str(ticket.get("form", "")),
			"payout": payout,
			"bankroll_delta": 0,
			"currency": GameModule.presentation_currency_for_game(run_state, get_id(), environment),
			"currency_delta": 0,
			"pile": pile_name,
			"environment_id": str(environment.get("id", "")),
		}
		var deltas := GameModule.empty_result_deltas()
		deltas["story_log"] = [story_entry]
		deltas["messages"] = [message]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": get_id(),
			"game_id": get_id(),
			"action_id": SORT_TICKET_ACTION,
			"action_kind": "legal",
			"stake": 0,
			"bankroll_delta": 0,
			"deltas": deltas,
			"won": payout > 0,
			"environment_id": str(environment.get("id", "")),
			"message": message,
		})
		_add_ticket_result_fields(result, ticket, deal, payout, 0)
		result["defer_bankroll_zero_failure"] = _should_defer_bankroll_zero_failure(run_state, 0, machine)
		result["suppress_music_outcome"] = true
		_advance_action_rng(rng)
		GameModule.apply_result(run_state, result, rng)
		return result
	return _empty_result(SORT_TICKET_ACTION, 0, environment, "No opened pull-tab is ready to sort.")


func _resolve_winner_redemption(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var winner_pile := _ticket_array(machine.get("winner_pile", []))
	if winner_pile.is_empty():
		return _empty_result(REDEEM_ACTION_ID, 0, environment, "%s has no winning tabs to cash." % _redeemer_label(environment))
	var base_payout := _ticket_payout_total(winner_pile)
	var stake_basis := maxi(1, _ticket_cost_total(winner_pile))
	var luck_payout_bonus := run_state.luck_payout_bonus(stake_basis, true) if run_state != null and base_payout > 0 else 0
	var item_payout_bonus := 0
	if run_state != null and base_payout > 0:
		item_payout_bonus = _item_bonus("win_bonus", run_state, false) + _item_bonus("payout_delta", run_state, false)
	var payout := maxi(1, base_payout + luck_payout_bonus + item_payout_bonus) if base_payout > 0 else 0
	var redemption_context := _redemption_context(machine, winner_pile, run_state, environment, stake_basis)
	var suspicious_count := int(redemption_context.get("suspicious_ticket_count", 0))
	var fake_count := int(redemption_context.get("fake_ticket_count", 0))
	var suspicion_delta := int(redemption_context.get("heat", 0))
	var security_bankroll_delta := int(redemption_context.get("security_bankroll_delta", 0))
	var bankroll_delta := payout + security_bankroll_delta
	var cashout_count := int(machine.get("cashout_count", 0)) + 1
	var message := "%s pays $%d for %d winning tab%s." % [
		_redeemer_label(environment),
		payout,
		winner_pile.size(),
		"" if winner_pile.size() == 1 else "s",
	]
	if luck_payout_bonus + item_payout_bonus > 0:
		message += " Luck and gear add $%d." % (luck_payout_bonus + item_payout_bonus)
	if suspicion_delta > 0:
		message += " %s" % _redemption_attention_message(redemption_context)
	var security_message := str(redemption_context.get("security_message", ""))
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	machine["winner_pile"] = []
	machine["redeemed_pile"] = _redeemed_ticket_history(machine, winner_pile)
	machine["last_redeemed_payout"] = payout
	machine["last_redeemed_count"] = winner_pile.size()
	machine["cashout_count"] = cashout_count
	machine["last_counter_transaction"] = {
		"kind": "redemption",
		"phase": "payout",
		"ticket_count": winner_pile.size(),
		"payout": payout,
		"scrutiny": "extended" if suspicion_delta > 0 or payout >= CASHOUT_HIGH_VALUE_TICKET_THRESHOLD else "standard",
		"completed": true,
	}
	_write_machine_state(environment, machine, run_state)
	var story_entry := {
		"type": "pull_tab_redeem",
		"game_id": get_id(),
		"action_id": REDEEM_ACTION_ID,
		"ticket_count": winner_pile.size(),
		"payout": payout,
		"base_payout": base_payout,
		"luck_payout_bonus": luck_payout_bonus,
		"item_payout_bonus": item_payout_bonus,
		"bankroll_delta": bankroll_delta,
		"currency": GameModule.presentation_currency_for_game(run_state, get_id(), environment),
		"currency_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"suspicious_ticket_count": suspicious_count,
		"fake_ticket_count": fake_count,
		"loser_ticket_count": int(redemption_context.get("loser_ticket_count", 0)),
		"cashout_pattern_heat": int(redemption_context.get("pattern_heat", 0)),
		"security_bankroll_delta": security_bankroll_delta,
		"pit_boss_watched": bool(redemption_context.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(redemption_context.get("pit_boss_heat_bonus", 0)),
		"redemption_risk_reasons": _pt_copy_array(redemption_context.get("risk_reasons", [])),
		"environment_id": str(environment.get("id", "")),
		"message": message,
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	deltas["ended"] = bool(redemption_context.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_hook",
		"source_id": "%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"game_id": get_id(),
		"action_id": REDEEM_ACTION_ID,
		"action_kind": "cheat" if suspicion_delta > 0 else "redemption",
		"stake": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": payout > 0,
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"message": message,
	})
	result["pull_tab_redeemed_count"] = winner_pile.size()
	result["pull_tab_redeemed_payout"] = payout
	result["pull_tab_base_redeemed_payout"] = base_payout
	result["pull_tab_luck_payout_bonus"] = luck_payout_bonus
	result["pull_tab_item_payout_bonus"] = item_payout_bonus
	result["pull_tab_suspicious_ticket_count"] = suspicious_count
	result["pull_tab_fake_ticket_count"] = fake_count
	result["pull_tab_loser_trail_count"] = int(redemption_context.get("loser_ticket_count", 0))
	result["pull_tab_cashout_pattern_heat"] = int(redemption_context.get("pattern_heat", 0))
	result["pull_tab_security_bankroll_delta"] = security_bankroll_delta
	result["pull_tab_pit_boss_watched"] = bool(redemption_context.get("pit_boss_watched", false))
	result["pull_tab_redemption_risk_reasons"] = _pt_copy_array(redemption_context.get("risk_reasons", []))
	if suspicion_delta > 0:
		result["followup_dialogue"] = {
			"dialogue_id": CLERK_DIALOGUE_ID,
			"event_id": "pull_tab_suspicious_cashout:%s:%d" % [str(environment.get("id", environment.get("archetype_id", "room"))), cashout_count],
			"start_node": _suspicious_cashout_dialogue_node(redemption_context),
			"source_object_id": _counter_host_object_id(environment),
			"speaker": _counter_speaker_override(environment),
		}
	return result


func _deal_ui_state(ui_state: Dictionary, deal_index: int) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	next_state["pull_tab_deal_index"] = deal_index
	next_state["pull_tab_stack_cursor"] = 0
	return next_state


func _toggle_auto_open_command(machine: Dictionary, ui_state: Dictionary) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	var next_active := not bool(next_state.get("pull_tab_auto_open_active", false))
	if next_active and _array_size(machine.get("ticket_stack", [])) <= 0:
		return _stop_auto_open_command(next_state, "Collect purchased tickets before starting Auto Open.")
	next_state["pull_tab_auto_open_active"] = next_active
	next_state["pull_tab_auto_open_next_msec"] = _pull_tab_surface_time_msec(ui_state) + PULL_TAB_AUTO_OPEN_INITIAL_DELAY_MSEC if next_active else 0
	return GameModule.surface_command({
		"handled": true,
		"ui_state": next_state,
		"message": "Auto Open started." if next_active else "Auto Open stopped.",
	})


func _stop_auto_open_command(ui_state: Dictionary, message: String) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	next_state["pull_tab_auto_open_active"] = false
	next_state["pull_tab_auto_open_next_msec"] = 0
	return GameModule.surface_command({
		"handled": true,
		"ui_state": next_state,
		"message": message,
	})


func _pull_tab_surface_time_msec(ui_state: Dictionary) -> int:
	return int(ui_state.get("drunk_scaled_surface_time_msec", ui_state.get("surface_time_msec", Time.get_ticks_msec())))


# Presentation hints use the host's pause-safe real surface clock. Drunk time
# scaling remains an Auto Open cadence concern and must not stretch 25-35 real
# active seconds or the bounded visible glimmer.
func _pull_tab_glimmer_surface_time_msec(ui_state: Dictionary) -> int:
	return int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))


func _reveal_next_command(machine: Dictionary, ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	var reveals := _pt_copy_dict(next_state.get("pull_tab_reveals", {}))
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return {"handled": true, "message": "The tray is empty."}
	var cursor := _stack_cursor(ui_state, tickets.size())
	var ordered_indices := [cursor]
	for index in range(tickets.size()):
		if index != cursor:
			ordered_indices.append(index)
	for ticket_index in ordered_indices:
		if ticket_index < 0 or ticket_index >= tickets.size():
			continue
		var ticket: Dictionary = tickets[ticket_index]
		var ticket_id := str(ticket.get("id", ""))
		if ticket_id.is_empty():
			continue
		var rows := _pt_copy_array(ticket.get("rows", []))
		var revealed := maxi(clampi(int(ticket.get("revealed_count", 0)), 0, rows.size()), clampi(int(reveals.get(ticket_id, 0)), 0, rows.size()))
		if revealed >= rows.size():
			continue
		reveals[ticket_id] = rows.size()
		next_state["pull_tab_reveals"] = reveals
		next_state["pull_tab_stack_cursor"] = ticket_index
		var animation_id := "reveal:%s:%d" % [ticket_id, Time.get_ticks_msec()]
		next_state["pull_tab_reveal_animation_id"] = animation_id
		next_state["pull_tab_reveal_animation_ticket_id"] = ticket_id
		next_state.erase("pull_tab_sort_ticket_id")
		var message := "You catch the paper lip. Three windows peel open one after another."
		var command := {
			"handled": true,
			"ui_state": next_state,
			"selected_index": ticket_index,
			"message": message,
		}
		if int(ticket.get("payout", 0)) > 0:
			command["surface_audio_cue"] = "ticket_win"
			command["surface_audio_action"] = "pull_tab_reveal_next"
		return command
	return {"handled": true, "message": "Every ticket in the stack has been opened."}


func _file_ticket_command(machine: Dictionary, ui_state: Dictionary) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	var reveals := _pt_copy_dict(next_state.get("pull_tab_reveals", {}))
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return {"handled": true, "message": "No opened pull-tab is ready to file."}
	var cursor := _stack_cursor(ui_state, tickets.size())
	var ordered_indices := [cursor]
	for index in range(tickets.size()):
		if index != cursor:
			ordered_indices.append(index)
	for ticket_index in ordered_indices:
		if ticket_index < 0 or ticket_index >= tickets.size():
			continue
		var ticket: Dictionary = tickets[ticket_index]
		var ticket_id := str(ticket.get("id", ""))
		if ticket_id.is_empty():
			continue
		var rows := _pt_copy_array(ticket.get("rows", []))
		if maxi(int(ticket.get("revealed_count", 0)), int(reveals.get(ticket_id, 0))) < rows.size():
			continue
		var payout := int(ticket.get("payout", 0))
		var pile_name := "winner_pile" if payout > 0 else "loser_pile"
		var animation_id := "file:%s:%d" % [ticket_id, Time.get_ticks_msec()]
		next_state["pull_tab_stack_cursor"] = clampi(ticket_index, 0, maxi(0, tickets.size() - 2))
		next_state["pull_tab_sort_ticket_id"] = ticket_id
		next_state["pull_tab_file_animation_id"] = animation_id
		next_state["pull_tab_file_animation_ticket"] = ticket.duplicate(true)
		next_state["pull_tab_file_animation_pile"] = pile_name
		var message := "%s %s is filed into the loser pile." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", ""))]
		if payout > 0:
			message = "%s %s is filed with the winners for $%d." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", "")), payout]
		return {
			"handled": true,
			"ui_state": next_state,
			"selected_index": ticket_index,
			"action_id": SORT_TICKET_ACTION,
			"action_kind": "legal",
			"resolve": true,
			"direct_resolve": true,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
			"message": message,
		}
	return {"handled": true, "message": "Peel a ticket before filing it."}


func _stack_navigation_command(machine: Dictionary, ui_state: Dictionary, direction: int) -> Dictionary:
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return {"handled": true, "message": "The tray is empty."}
	var next_state := ui_state.duplicate(true)
	var cursor := _stack_cursor(ui_state, tickets.size())
	cursor = clampi(cursor + direction, 0, tickets.size() - 1)
	next_state["pull_tab_stack_cursor"] = cursor
	return {
		"handled": true,
		"ui_state": next_state,
		"selected_index": cursor,
		"message": "Ticket %d of %d selected." % [cursor + 1, tickets.size()],
	}


func _stack_cursor_command(machine: Dictionary, ui_state: Dictionary, cursor: int) -> Dictionary:
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return {"handled": true, "message": "The tray is empty."}
	var next_state := ui_state.duplicate(true)
	next_state["pull_tab_stack_cursor"] = clampi(cursor, 0, tickets.size() - 1)
	return {
		"handled": true,
		"ui_state": next_state,
		"selected_index": int(next_state.get("pull_tab_stack_cursor", 0)),
	}


func _next_unopened_command(machine: Dictionary, ui_state: Dictionary) -> Dictionary:
	var tickets := _ticket_array(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return {"handled": true, "message": "The tray is empty."}
	var reveals := _pt_copy_dict(ui_state.get("pull_tab_reveals", {}))
	var cursor := _stack_cursor(ui_state, tickets.size())
	for offset in range(1, tickets.size() + 1):
		var index := (cursor + offset) % tickets.size()
		var ticket: Dictionary = tickets[index]
		var ticket_id := str(ticket.get("id", ""))
		var rows := _pt_copy_array(ticket.get("rows", []))
		if maxi(int(ticket.get("revealed_count", 0)), int(reveals.get(ticket_id, 0))) < rows.size():
			return _stack_cursor_command(machine, ui_state, index)
	return {"handled": true, "message": "Every ticket in the stack has been opened."}


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	var game_states: Dictionary = states_value as Dictionary if typeof(states_value) == TYPE_DICTIONARY else {}
	var existing_value: Variant = game_states.get(get_id(), {})
	if typeof(existing_value) == TYPE_DICTIONARY and not (existing_value as Dictionary).is_empty():
		var existing: Dictionary = existing_value as Dictionary if persist else (existing_value as Dictionary).duplicate(true)
		if _machine_state_needs_normalization(existing):
			existing = _normalize_machine_state(existing)
			if persist:
				var writable_states := game_states.duplicate(false)
				writable_states[get_id()] = existing
				environment["game_states"] = writable_states
		if persist:
			_sync_portable_ticket_state(run_state, environment, existing)
		else:
			_merge_portable_ticket_state_readonly(run_state, environment, existing)
		return existing
	var generated := _generate_machine_state(run_state, environment)
	if persist:
		_sync_portable_ticket_state(run_state, environment, generated)
	else:
		_merge_portable_ticket_state_readonly(run_state, environment, generated)
	if persist:
		var writable_states := game_states.duplicate(false)
		writable_states[get_id()] = generated
		environment["game_states"] = writable_states
	return generated


func _game_states_for_write(environment: Dictionary) -> Dictionary:
	var value: Variant = environment.get("game_states", {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(false)
	return {}


func _machine_state_needs_normalization(machine: Dictionary) -> bool:
	if not machine.has("deals") or typeof(machine.get("deals", [])) != TYPE_ARRAY:
		return true
	for deal_value in _array_view(machine.get("deals", [])):
		if typeof(deal_value) != TYPE_DICTIONARY:
			return true
		var deal: Dictionary = deal_value
		if not deal.has("ticket_sleeve") and int(deal.get("remaining", 0)) > 0:
			return true
	if not machine.has("tray_stack") or not machine.has("ticket_stack") or not machine.has("winner_pile") or not machine.has("loser_pile"):
		return true
	if not machine.has("item_state") or typeof(machine.get("item_state", {})) != TYPE_DICTIONARY:
		return true
	return false


func _write_machine_state(environment: Dictionary, machine: Dictionary, run_state: RunState = null) -> void:
	var portable := RunState.compact_portable_ticket_state(get_id(), _portable_ticket_player_state(machine), false)
	for field in ["tray_stack", "ticket_stack", "winner_pile", "loser_pile", "loser_archive_count"]:
		if portable.has(field):
			machine[field] = portable[field]
	var game_states := _game_states_for_write(environment)
	game_states[get_id()] = machine
	environment["game_states"] = game_states
	if run_state != null:
		run_state.remember_portable_ticket_state(get_id(), environment, portable)


func _sync_portable_ticket_state(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var portable := run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		_stamp_machine_ticket_origins(machine, environment)
		var legacy := _portable_ticket_player_state(machine)
		if _portable_ticket_count(legacy) > 0:
			run_state.remember_portable_ticket_state(get_id(), environment, legacy)
			portable = run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		return
	for field in ["tray_stack", "ticket_stack", "winner_pile", "loser_pile"]:
		machine[field] = portable.get(field, [])
	machine["loser_archive_count"] = maxi(0, int(portable.get("loser_archive_count", 0)))


func _portable_ticket_player_state(machine: Dictionary) -> Dictionary:
	return {
		"tray_stack": _array_view(machine.get("tray_stack", [])),
		"ticket_stack": _array_view(machine.get("ticket_stack", [])),
		"winner_pile": _array_view(machine.get("winner_pile", [])),
		"loser_pile": _array_view(machine.get("loser_pile", [])),
		"loser_archive_count": maxi(0, int(machine.get("loser_archive_count", 0))),
	}


func _portable_ticket_count(state: Dictionary) -> int:
	return _array_size(state.get("tray_stack", [])) + _array_size(state.get("ticket_stack", [])) + _array_size(state.get("winner_pile", [])) + _array_size(state.get("loser_pile", [])) + maxi(0, int(state.get("loser_archive_count", 0)))


func _stamp_ticket_origin(ticket: Dictionary, environment: Dictionary) -> void:
	ticket["origin_key"] = RunState.portable_ticket_origin_key(environment)
	ticket["origin_name"] = RunState.portable_ticket_origin_name(environment)
	ticket["origin_environment_id"] = str(environment.get("id", "")).strip_edges()
	ticket["origin_world_node_id"] = str(environment.get("world_node_id", "")).strip_edges()


func _stamp_machine_ticket_origins(machine: Dictionary, environment: Dictionary) -> void:
	for field in ["tray_stack", "ticket_stack", "winner_pile", "loser_pile"]:
		for ticket_value in _array_view(machine.get(field, [])):
			if typeof(ticket_value) == TYPE_DICTIONARY:
				_stamp_ticket_origin(ticket_value as Dictionary, environment)


func _pull_tab_item_state(machine: Dictionary) -> Dictionary:
	var item_state := _normalize_pull_tab_item_state(machine)
	machine["item_state"] = item_state
	return item_state


func _pull_tab_item_surface_state(machine: Dictionary, run_state: RunState) -> Dictionary:
	var item_state := _pull_tab_item_state(machine)
	var xray_available := _run_has_item(run_state, XRAY_GLASSES_ITEM_ID)
	var detector_available := _run_has_item(run_state, TAB_DETECTOR_ITEM_ID)
	var peek_highlight_index := int(item_state.get("tab_detector_peek_highlight_index", -1)) if not detector_available else -1
	var xray_targets := _visible_xray_targets(machine) if xray_available else []
	var xray_target := (xray_targets[0] as Dictionary).duplicate(true) if not xray_targets.is_empty() else {}
	return {
		"xray_available": xray_available,
		"xray_target": xray_target,
		"xray_targets": xray_targets,
		"tab_detector_available": detector_available,
		"tab_detector_active": detector_available and bool(item_state.get("tab_detector_active", false)),
		"tab_detector_highlight_index": _tab_detector_highlight_deal_index(machine) if detector_available and bool(item_state.get("tab_detector_active", false)) else peek_highlight_index,
		"tab_detector_next_heat": TAB_DETECTOR_BASE_HEAT + maxi(0, int(item_state.get("tab_detector_heat_triggers", 0))),
		"tab_detector_peek_count": maxi(0, int(item_state.get("tab_detector_peek_count", 0))),
		"tab_detector_peek_success_count": maxi(0, int(item_state.get("tab_detector_peek_success_count", 0))),
		"tab_detector_peek_last_succeeded": bool(item_state.get("tab_detector_peek_last_succeeded", false)),
		"tarot_armed": bool(item_state.get("tarot_armed", false)),
	}


func _run_has_item(run_state: RunState, item_id: String) -> bool:
	return run_state != null and run_state.inventory.has(item_id)


func _xray_target_for_deal(machine: Dictionary, deal_index: int) -> Dictionary:
	var item_state := _pull_tab_item_state(machine)
	for target_value in _dictionary_array(item_state.get("xray_targets", [])):
		var target: Dictionary = target_value
		if bool(target.get("consumed", false)) or int(target.get("deal_index", -1)) != deal_index:
			continue
		return _current_xray_target_for_deal(machine, deal_index, target)
	return {}


func _visible_xray_targets(machine: Dictionary) -> Array:
	var result: Array = []
	var item_state := _pull_tab_item_state(machine)
	for target_value in _dictionary_array(item_state.get("xray_targets", [])):
		var target: Dictionary = target_value
		if bool(target.get("consumed", false)):
			continue
		var current_target := _current_xray_target_for_deal(machine, int(target.get("deal_index", -1)), target)
		if not current_target.is_empty():
			result.append(current_target)
	return result


func _current_xray_target_for_deal(machine: Dictionary, deal_index: int, source_target: Dictionary) -> Dictionary:
	var deals := _array_view(machine.get("deals", []))
	if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
		return {}
	var deal: Dictionary = deals[deal_index]
	var cursor := int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0))))
	var ticket_number := int(source_target.get("ticket_number", 0))
	var offset := ticket_number - cursor - 1
	if offset < 0:
		return {}
	if offset >= int(deal.get("remaining", 0)):
		return {}
	var target := source_target.duplicate(true)
	target["offset"] = offset
	target["tickets_until"] = offset + 1
	return target


func _tab_detector_active(machine: Dictionary, run_state: RunState) -> bool:
	if not _run_has_item(run_state, TAB_DETECTOR_ITEM_ID):
		return false
	return bool(_pull_tab_item_state(machine).get("tab_detector_active", false))


func _clear_tab_peek_hint(machine: Dictionary) -> void:
	var item_state := _pull_tab_item_state(machine)
	if int(item_state.get("tab_detector_peek_highlight_index", -1)) < 0:
		return
	item_state["tab_detector_peek_highlight_index"] = -1
	machine["item_state"] = item_state


func _tab_detector_highlight_deal_index(machine: Dictionary) -> int:
	var deals := _array_view(machine.get("deals", []))
	var best_index := -1
	var best_offset := 999999
	for deal_index in range(deals.size()):
		if typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var target := _closest_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		var offset := int(target.get("offset", 999999))
		if offset < best_offset:
			best_offset = offset
			best_index = deal_index
	return best_index


func _closest_winner_target(deal: Dictionary, deal_index: int) -> Dictionary:
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	var prizes := _dictionary_array(deal.get("prizes", []))
	for offset in range(sleeve.size()):
		var prize_index := int(sleeve[offset])
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		if int((prizes[prize_index] as Dictionary).get("payout", 0)) <= 0:
			continue
		return _winner_target_payload(deal, deal_index, prize_index, offset)
	return {}


func _tab_detector_purchase_heat(machine: Dictionary, ticket: Dictionary, run_state: RunState) -> int:
	if not _tab_detector_active(machine, run_state) or int(ticket.get("payout", 0)) <= 0:
		return 0
	var item_state := _pull_tab_item_state(machine)
	var trigger_count := maxi(0, int(item_state.get("tab_detector_heat_triggers", 0)))
	var heat := TAB_DETECTOR_BASE_HEAT + trigger_count
	item_state["tab_detector_heat_triggers"] = trigger_count + 1
	machine["item_state"] = item_state
	return heat


# Centralized hook for ticket-purchase item effects. Future pull-tab items that
# alter a bought ticket, consume a marked ticket, or add heat should branch here
# so single-column and master-button purchases stay behaviorally identical.
func _apply_pull_tab_item_purchase_effects(machine: Dictionary, deal: Dictionary, ticket: Dictionary, deal_index: int, run_state: RunState) -> Dictionary:
	var tarot_applied := _apply_tarot_if_armed(machine, deal, ticket, deal_index)
	var xray_consumed := _mark_xray_target_if_consumed(machine, deal_index, ticket)
	var detector_heat := _tab_detector_purchase_heat(machine, ticket, run_state)
	ticket["tarot_applied"] = tarot_applied
	ticket["xray_target_consumed"] = xray_consumed
	ticket["tab_detector_heat"] = detector_heat
	return {
		"tarot_applied": tarot_applied,
		"xray_target_consumed": xray_consumed,
		"tab_detector_heat": detector_heat,
	}


func _mark_xray_target_if_consumed(machine: Dictionary, deal_index: int, ticket: Dictionary) -> bool:
	var item_state := _pull_tab_item_state(machine)
	var ticket_number := int(ticket.get("ticket_number_value", 0))
	if ticket_number <= 0:
		ticket_number = int(str(ticket.get("ticket_number", "")).replace("#", ""))
	var targets := _dictionary_array(item_state.get("xray_targets", []))
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		if bool(target.get("consumed", false)) or int(target.get("deal_index", -1)) != deal_index:
			continue
		if ticket_number != int(target.get("ticket_number", -1)):
			continue
		target["consumed"] = true
		targets[index] = target
		item_state["xray_targets"] = targets
		machine["item_state"] = _sync_legacy_xray_fields(item_state)
		return true
	return false


func _apply_tarot_if_armed(machine: Dictionary, deal: Dictionary, ticket: Dictionary, deal_index: int) -> bool:
	var item_state := _pull_tab_item_state(machine)
	if not bool(item_state.get("tarot_armed", false)):
		return false
	var read_count := maxi(1, int(item_state.get("tarot_read_count", TAROT_READING_COUNT)))
	var reading := _tarot_reading_for_deal(deal, read_count)
	_convert_ticket_to_tarot_loser(ticket, deal, deal_index, reading)
	item_state["tarot_armed"] = false
	item_state["last_tarot_ticket_id"] = str(ticket.get("id", ""))
	machine["item_state"] = item_state
	return true


func _tarot_reading_for_deal(deal: Dictionary, count: int) -> Array:
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	var result: Array = []
	for offset in range(mini(maxi(0, count), sleeve.size())):
		result.append(_sleeve_entry_prize_view(deal, int(sleeve[offset]), offset))
	while result.size() < count:
		result.append({
			"offset": result.size(),
			"tickets_until": result.size() + 1,
			"payout": 0,
			"label": "Empty",
			"symbols": ["MISS"],
		})
	return result


func _sleeve_entry_prize_view(deal: Dictionary, sleeve_entry: int, offset: int) -> Dictionary:
	var prizes := _dictionary_array(deal.get("prizes", []))
	if sleeve_entry < 0 or sleeve_entry >= prizes.size():
		return {
			"offset": offset,
			"tickets_until": offset + 1,
			"payout": 0,
			"label": "No prize",
			"symbols": ["MISS"],
		}
	var prize: Dictionary = prizes[sleeve_entry]
	return {
		"offset": offset,
		"tickets_until": offset + 1,
		"payout": maxi(0, int(prize.get("payout", 0))),
		"label": str(prize.get("label", "")),
		"symbols": _string_array(prize.get("symbols", [])),
	}


func _convert_ticket_to_tarot_loser(ticket: Dictionary, deal: Dictionary, deal_index: int, reading: Array) -> void:
	var burned_payout := maxi(0, int(ticket.get("payout", 0)))
	var burned_label := str(ticket.get("prize_label", ""))
	var seed_key := "tarot:%s:%s" % [str(ticket.get("id", "")), str(deal.get("serial", ""))]
	if _dictionary_array(ticket.get("prize_rows", [])).is_empty():
		ticket["prize_rows"] = _prize_rows_for_view(_dictionary_array(deal.get("prizes", [])))
	ticket["rows"] = _ticket_rows({}, _seeded_rng(seed_key))
	ticket["winning_row_index"] = -1
	ticket["prize_label"] = ""
	ticket["payout"] = 0
	ticket["win_code"] = _win_code(deal, int(deal.get("unit_cursor", 0)), 0)
	ticket["tarot_converted"] = true
	ticket["tarot_deal_index"] = deal_index
	ticket["tarot_reading"] = _normalize_tarot_reading(reading, TAROT_READING_COUNT)
	ticket["burned_payout"] = burned_payout
	ticket["burned_prize_label"] = burned_label


func _draw_ticket_from_deal(deal: Dictionary, _machine: Dictionary, is_cheat: bool) -> Dictionary:
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	if sleeve.is_empty():
		deal["remaining"] = 0
		return {}
	var prize_index := int(sleeve.pop_front())
	var sold := int(deal.get("sold", 0)) + 1
	var ticket_number := int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0)))) + 1
	deal["ticket_sleeve"] = sleeve
	deal["remaining"] = sleeve.size()
	deal["sold"] = sold
	deal["unit_cursor"] = ticket_number
	var prizes := _dictionary_array(deal.get("prizes", []))
	var winning_prize := {}
	if prize_index >= 0 and prize_index < prizes.size():
		winning_prize = (prizes[prize_index] as Dictionary).duplicate(true) # SA2_PER_FRAME_OK: ticket-sale state mutation helper, not rendering/per-frame.
		winning_prize["remaining"] = maxi(0, int(winning_prize.get("remaining", 0)) - 1)
		prizes[prize_index] = winning_prize
		deal["prizes"] = _normalize_prizes(prizes)
	var rows := _ticket_rows_for_sleeve_entry(deal, winning_prize, ticket_number)
	var ticket_id := "%s:%s:%03d" % [str(deal.get("serial", "deal")), str(deal.get("id", "")), ticket_number]
	var prize_rows := _prize_rows_for_view(_dictionary_array(deal.get("prizes", [])))
	return {
		"id": ticket_id,
		"deal_id": str(deal.get("id", "")),
		"display_name": str(deal.get("display_name", "Pull Tab")),
		"theme": str(deal.get("theme", "")),
		"form": str(deal.get("form", "")),
		"serial": str(deal.get("serial", "")),
		"price": int(deal.get("price", 1)),
		"ticket_number": "#%03d" % ticket_number,
		"ticket_number_value": ticket_number,
		"rows": rows,
		"winning_row_index": int(winning_prize.get("row_index", -1)),
		"prize_label": str(winning_prize.get("label", "")),
		"payout": int(winning_prize.get("payout", 0)),
		"win_code": _win_code(deal, ticket_number, int(winning_prize.get("payout", 0))),
		"tainted": is_cheat,
		"fake": false,
		"sorted": false,
		"palette": _pt_copy_dict(deal.get("palette", {})),
		"prize_rows": prize_rows,
	}


func _ticket_rows_for_sleeve_entry(deal: Dictionary, winning_prize: Dictionary, ticket_number: int) -> Array:
	var seed_key := "%s:%s:%d:%d" % [
		str(deal.get("serial", "")),
		str(deal.get("id", "")),
		ticket_number,
		int(winning_prize.get("payout", 0)),
	]
	return _ticket_rows(winning_prize, _seeded_rng(seed_key))


func _advance_action_rng(rng: RngStream) -> void:
	if rng != null:
		rng.randi_range(0, 0)


func _ticket_rows(winning_prize: Dictionary, rng: RngStream) -> Array:
	var rows: Array = []
	var winning_row := -1
	if not winning_prize.is_empty():
		winning_row = rng.randi_range(0, 2)
		winning_prize["row_index"] = winning_row
	for row_index in range(3):
		if row_index == winning_row:
			rows.append(_string_array(winning_prize.get("symbols", [])))
		else:
			rows.append(_losing_row(rng))
	return rows


func _losing_row(rng: RngStream) -> Array:
	var row: Array = []
	while row.size() < 3:
		row.append(str(rng.pick(SYMBOLS, "CHERRY")))
	var first := str(row[0])
	if first == str(row[1]) and first == str(row[2]):
		var replacement := str(rng.pick(SYMBOLS, "LEMON"))
		while replacement == first:
			replacement = str(rng.pick(SYMBOLS, "LEMON"))
		row[2] = replacement
	return row


func _win_code(deal: Dictionary, ticket_number: int, payout: int) -> String:
	var seed_text := "%s:%s:%d:%d" % [str(deal.get("serial", "")), str(deal.get("form", "")), ticket_number, payout]
	return seed_text.sha256_text().left(6).to_upper()


func _deal_for_ticket(machine: Dictionary, ticket: Dictionary) -> Dictionary:
	var deal_id := str(ticket.get("deal_id", ""))
	for deal_value in _array_view(machine.get("deals", [])):
		if typeof(deal_value) != TYPE_DICTIONARY:
			continue
		var deal: Dictionary = deal_value
		if str(deal.get("id", "")) == deal_id:
			return deal
	return {}


func _add_ticket_result_fields(result: Dictionary, ticket: Dictionary, deal: Dictionary, payout: int, cost: int) -> void:
	result["pull_tab_ticket"] = _ticket_display_payload(ticket, deal)
	result["pull_tab_deal"] = deal.duplicate(true)
	result["pull_tab_payout"] = payout
	result["pull_tab_cost"] = cost
	result["pull_tab_rows"] = _pt_copy_array(ticket.get("rows", []))
	result["ticket_symbols"] = _ticket_result_symbols(ticket)
	result["match_count"] = _ticket_max_match_count(ticket)
	result["payout"] = payout


func _deal_view_list(machine: Dictionary, run_state: RunState, item_surface: Dictionary = {}) -> Array:
	var result: Array = []
	var deals := _array_view(machine.get("deals", []))
	if item_surface.is_empty():
		item_surface = _pull_tab_item_surface_state(machine, run_state)
	var detector_highlight_index := int(item_surface.get("tab_detector_highlight_index", -1))
	for index in range(deals.size()):
		if typeof(deals[index]) != TYPE_DICTIONARY:
			continue
		var deal: Dictionary = deals[index]
		var price := int(deal.get("price", 1))
		var remaining := int(deal.get("remaining", 0))
		var prizes := _dictionary_array(deal.get("prizes", []))
		var top_prize := _deal_top_prize_summary(deal)
		var tension := _deal_tension_state(deal)
		var xray_target := _xray_target_for_deal(machine, index) if bool(item_surface.get("xray_available", false)) else {}
		if not xray_target.is_empty():
			xray_target["total_cost"] = maxi(0, int(xray_target.get("tickets_until", 0))) * price
		var view: Dictionary = {
			"id": str(deal.get("id", "")),
			"index": index,
			"display_name": str(deal.get("display_name", "")),
			"theme": str(deal.get("theme", "")),
			"form": str(deal.get("form", "")),
			"serial": str(deal.get("serial", "")),
			"price": price,
			"ticket_count": int(deal.get("ticket_count", remaining)),
			"remaining": remaining,
			"sold": int(deal.get("sold", 0)),
			"initial_removed_count": int(deal.get("initial_removed_count", 0)),
			"enabled": run_state != null and run_state.wager_capacity_for_game(get_id()) >= price and remaining > 0,
			"prize_rows": _prize_rows_for_view(prizes),
			"palette": _pt_copy_dict(deal.get("palette", {})),
			"xray_target": xray_target,
			"tab_detector_highlight": index == detector_highlight_index,
			"tab_detector_active": bool(item_surface.get("tab_detector_active", false)),
			"tab_detector_next_heat": int(item_surface.get("tab_detector_next_heat", TAB_DETECTOR_BASE_HEAT)),
		}
		for key in top_prize.keys():
			view[key] = top_prize[key]
		for key in tension.keys():
			view[key] = tension[key]
		result.append(view)
	return result


func _deal_top_prize_summary(deal: Dictionary) -> Dictionary:
	var prizes := _dictionary_array(deal.get("prizes", []))
	var best: Dictionary = {}
	var best_payout := -1
	for prize_value in prizes:
		var prize: Dictionary = prize_value
		var payout := maxi(0, int(prize.get("payout", 0)))
		if payout <= best_payout:
			continue
		best = prize.duplicate(true)
		best_payout = payout
	if best.is_empty():
		return {
			"top_prize_label": "",
			"top_prize_payout": 0,
			"top_prize_count": 0,
			"top_prize_remaining": 0,
			"top_prize_available": false,
		}
	var remaining := maxi(0, int(best.get("remaining", best.get("count", 0))))
	return {
		"top_prize_label": str(best.get("label", "")),
		"top_prize_payout": maxi(0, int(best.get("payout", 0))),
		"top_prize_count": maxi(0, int(best.get("count", 0))),
		"top_prize_remaining": remaining,
		"top_prize_available": remaining > 0,
	}


func _deal_tension_state(deal: Dictionary) -> Dictionary:
	var ticket_count := maxi(1, int(deal.get("ticket_count", DEFAULT_DEAL_COUNT)))
	var remaining := clampi(int(deal.get("remaining", 0)), 0, ticket_count)
	var remaining_percent := int(round(100.0 * float(remaining) / float(ticket_count)))
	if remaining <= 0:
		return {
			"tension_state": "sold_out",
			"tension_label": "SOLD OUT",
			"last_tickets": false,
			"remaining_percent": 0,
		}
	var last_threshold := maxi(3, mini(PULL_TAB_LAST_TICKET_COUNT, int(round(float(ticket_count) * PULL_TAB_LOW_TICKET_RATIO))))
	if remaining <= last_threshold:
		return {
			"tension_state": "last_tickets",
			"tension_label": "LAST %d" % remaining,
			"last_tickets": true,
			"remaining_percent": remaining_percent,
		}
	if float(remaining) / float(ticket_count) <= PULL_TAB_THIN_TICKET_RATIO:
		return {
			"tension_state": "thin",
			"tension_label": "%d LEFT" % remaining,
			"last_tickets": false,
			"remaining_percent": remaining_percent,
		}
	return {
		"tension_state": "stocked",
		"tension_label": "%d LEFT" % remaining,
		"last_tickets": false,
		"remaining_percent": remaining_percent,
	}


func _ticket_stack_view(machine: Dictionary, ui_state: Dictionary) -> Array:
	var tickets := _array_view(machine.get("ticket_stack", []))
	var reveals := _pt_copy_dict(ui_state.get("pull_tab_reveals", {}))
	var reveal_ticket_id := str(ui_state.get("pull_tab_reveal_animation_ticket_id", ""))
	var reveal_animation_id := str(ui_state.get("pull_tab_reveal_animation_id", ""))
	var result: Array = []
	if tickets.is_empty():
		return result
	var cursor := _stack_cursor(ui_state, tickets.size())
	var source_indices := [cursor]
	var radius := 1
	while source_indices.size() < mini(tickets.size(), TICKET_STACK_VIEW_LIMIT):
		var right := cursor + radius
		if right < tickets.size():
			source_indices.append(right)
		if source_indices.size() >= mini(tickets.size(), TICKET_STACK_VIEW_LIMIT):
			break
		var left := cursor - radius
		if left >= 0:
			source_indices.append(left)
		radius += 1
		if left < 0 and right >= tickets.size():
			break
	for source_index in source_indices:
		var ticket := _ticket_dict(tickets[source_index])
		if ticket.is_empty():
			continue
		var ticket_id := str(ticket.get("id", ""))
		var rows := _pt_copy_array(ticket.get("rows", []))
		var revealed := maxi(clampi(int(ticket.get("revealed_count", 0)), 0, rows.size()), clampi(int(reveals.get(ticket_id, 0)), 0, rows.size()))
		var deal := _deal_for_ticket(machine, ticket)
		var ticket_view := _ticket_display_payload(ticket, deal)
		ticket_view["stack_index"] = source_index
		ticket_view["selected"] = source_index == cursor
		ticket_view["revealed_count"] = revealed
		ticket_view["fully_revealed"] = revealed >= rows.size()
		if ticket_id == reveal_ticket_id:
			ticket_view["reveal_animation_id"] = reveal_animation_id
		result.append(ticket_view)
	return result


func _tray_ticket_view_list(machine: Dictionary) -> Array:
	var tray := _array_view(machine.get("tray_stack", []))
	var visible_by_column: Array = []
	for _column in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		visible_by_column.append([])
	for index in range(tray.size() - 1, -1, -1):
		if typeof(tray[index]) != TYPE_DICTIONARY:
			continue
		var source_ticket: Dictionary = tray[index]
		var deal_index := _deal_index_for_ticket(machine, source_ticket)
		var column_tickets: Array = visible_by_column[deal_index]
		if column_tickets.size() >= TRAY_COLUMN_VIEW_LIMIT:
			continue
		var ticket := _ticket_dict(source_ticket)
		if ticket.is_empty():
			continue
		var deal := _deal_for_ticket(machine, ticket)
		var ticket_view := _ticket_display_payload(ticket, deal)
		ticket_view["deal_index"] = deal_index
		ticket_view["tray_index"] = index
		ticket_view["revealed_count"] = 0
		ticket_view["fully_revealed"] = false
		column_tickets.append(ticket_view)
	var result: Array = []
	for deal_index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var column_tickets: Array = visible_by_column[deal_index]
		column_tickets.reverse()
		result.append_array(column_tickets)
	return result


func _tray_column_counts(machine: Dictionary) -> Array:
	var counts: Array = []
	for _column in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		counts.append(0)
	for value in _array_view(machine.get("tray_stack", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var deal_index := _deal_index_for_ticket(machine, value as Dictionary)
		counts[deal_index] = int(counts[deal_index]) + 1
	return counts


func _deal_index_for_ticket(machine: Dictionary, ticket: Dictionary) -> int:
	if ticket.has("deal_index"):
		return clampi(int(ticket.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
	var deal_id := str(ticket.get("deal_id", ""))
	var deals := _array_view(machine.get("deals", []))
	for index in range(deals.size()):
		if typeof(deals[index]) != TYPE_DICTIONARY:
			continue
		if str((deals[index] as Dictionary).get("id", "")) == deal_id:
			return clampi(index, 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
	return 0


func _queue_dispense_events(machine: Dictionary, tickets: Array, deal_indices: Array, now_msec: int = -1) -> void:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var started_msec := int(machine.get("dispense_started_msec", 0))
	var active_events := _active_dispense_events(machine, now_msec)
	if started_msec <= 0 or active_events.is_empty():
		started_msec = now_msec
		active_events = []
	var start_offset_msec := maxi(0, now_msec - started_msec)
	var new_events := _dispense_events_for_tickets(tickets, deal_indices, start_offset_msec, active_events.size())
	active_events.append_array(new_events)
	if active_events.size() > ACTIVE_DISPENSE_EVENT_LIMIT:
		active_events = active_events.slice(active_events.size() - ACTIVE_DISPENSE_EVENT_LIMIT, active_events.size())
	machine["dispense_started_msec"] = started_msec
	machine["last_dispense_id"] = "dispense_batch:%d" % started_msec
	machine["last_dispense_events"] = active_events


func _dispense_events_for_tickets(tickets: Array, deal_indices: Array, base_start_msec: int = 0, sequence_offset: int = 0) -> Array:
	var events: Array = []
	for index in range(tickets.size()):
		if typeof(tickets[index]) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = tickets[index]
		var deal_index := int(deal_indices[index]) if index < deal_indices.size() else index
		var start_msec := maxi(0, base_start_msec) + index * PULL_TAB_DISPENSE_STAGGER_MSEC
		events.append({
			"ticket_id": str(ticket.get("id", "")),
			"ticket": _ticket_animation_payload(ticket),
			"deal_index": clampi(deal_index, 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1),
			"sequence_index": sequence_offset + index,
			"start_msec": start_msec,
			"drop_start_msec": PULL_TAB_DISPENSE_DROP_START_MSEC,
			"drop_duration_msec": PULL_TAB_DISPENSE_DROP_DURATION_MSEC,
		})
	return events


func _dispense_event_view_list(machine: Dictionary, ui_state: Dictionary = {}) -> Array:
	if ui_state.has("surface_presentation_time_msec") or ui_state.has("surface_time_msec"):
		return _active_dispense_events(machine, maxi(1, _pull_tab_presentation_time_msec(ui_state)))
	var started_msec := int(machine.get("dispense_started_msec", 0))
	if started_msec > 0:
		return _active_dispense_events(machine, started_msec)
	return _active_dispense_events(machine, Time.get_ticks_msec())


func _pull_tab_presentation_time_msec(ui_state: Dictionary, run_state: RunState = null) -> int:
	if ui_state.has("surface_presentation_time_msec"):
		return maxi(1, int(ui_state.get("surface_presentation_time_msec", 0)))
	return GameModule.deterministic_time_msec(run_state, ui_state)


func _active_dispense_events(machine: Dictionary, now_msec: int) -> Array:
	var started_msec := int(machine.get("dispense_started_msec", 0))
	# A re-entered game or cold Continue may restart the presentation clock.
	# An old visual receipt must not keep purchased tickets trapped in the tray.
	if started_msec <= 0 or now_msec < started_msec:
		return []
	var elapsed_msec := maxi(0, now_msec - started_msec)
	var result: Array = []
	for event_value in _dispense_event_array(machine.get("last_dispense_events", [])):
		var event: Dictionary = event_value
		var event_end_msec := int(event.get("start_msec", 0)) + PULL_TAB_DISPENSE_EVENT_DURATION_MSEC
		if elapsed_msec <= event_end_msec:
			result.append(event)
	if result.size() > ACTIVE_DISPENSE_EVENT_LIMIT:
		return result.slice(result.size() - ACTIVE_DISPENSE_EVENT_LIMIT, result.size())
	return result


func _dispense_animation_duration_msec(events: Array) -> int:
	if events.is_empty():
		return 0
	var last_start := 0
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY:
			last_start = maxi(last_start, int((event_value as Dictionary).get("start_msec", 0)))
	return last_start + PULL_TAB_DISPENSE_EVENT_DURATION_MSEC


func _ticket_pile_view_list(machine: Dictionary, pile_name: String) -> Array:
	var tickets := _array_view(machine.get(pile_name, []))
	var result: Array = []
	var start_index := maxi(0, tickets.size() - SORTED_PILE_VIEW_LIMIT)
	for ticket_index in range(start_index, tickets.size()):
		var ticket := _ticket_dict(tickets[ticket_index])
		if ticket.is_empty():
			continue
		# Sorted tickets are rendered as miniature pile receipts. Rebuilding their
		# full revealed rows and deal prize charts served no visible interaction.
		var view := ticket.duplicate(true)
		view["pile"] = pile_name
		view["stack_index"] = ticket_index
		view["pile_depth_index"] = maxi(0, int(ticket.get("pile_depth_index", ticket_index)))
		result.append(view)
	return result


func _should_defer_bankroll_zero_failure(run_state: RunState, bankroll_delta: int, machine: Dictionary) -> bool:
	if run_state == null:
		return false
	return run_state.wager_balance_for_game(get_id()) + bankroll_delta <= 0 and _pull_tab_bankroll_zero_failure_deferred(machine)


func _ticket_cost_total(tickets: Array) -> int:
	var total := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			total += maxi(1, int((ticket_value as Dictionary).get("price", 1)))
	return total


# Peek owns an exact escalating Heat ladder. Generic cheat-pressure bonuses must
# not silently turn the promised 8/9/10/11 sequence into larger values; room
# security can still react to the resulting total through its normal pressure
# outcome without changing the amount shown and charged by Peek itself.
func _pull_tab_peek_heat(base_heat: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	var exact_heat := maxi(0, base_heat)
	if run_state == null:
		return {
			"suspicion_delta": exact_heat,
			"base_suspicion_delta": exact_heat,
			"bankroll_delta": 0,
			"security_message": "",
			"ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	var pressure: Dictionary = run_state.security_action_pressure("cheat", 1, run_state.suspicion_level() + exact_heat) if exact_heat > 0 else {}
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var security_message := str(pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		security_message = "%s %s" % [pit_boss_summary, security_message]
		security_message = security_message.strip_edges()
	return {
		"suspicion_delta": exact_heat,
		"base_suspicion_delta": exact_heat,
		"bankroll_delta": int(pressure.get("bankroll_delta", 0)),
		"security_message": security_message,
		"ended": bool(pressure.get("ended", false)),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": 0,
	}


func _suspicious_cashout_dialogue_node(redemption_context: Dictionary) -> String:
	var reasons := _pt_copy_array(redemption_context.get("risk_reasons", []))
	if reasons.has("bent_or_fake_tabs"):
		return "suspicious_tampered"
	if reasons.has("bulk_winners_low_loser_trail"):
		return "suspicious_bulk"
	if reasons.has("repeated_high_value_winners_low_loser_trail"):
		return "suspicious_repeat"
	return "suspicious_general"


func _pull_tab_remaining_count(machine: Dictionary) -> int:
	var total := 0
	for deal_value in _array_view(machine.get("deals", [])):
		total += maxi(0, int((deal_value as Dictionary).get("remaining", 0)))
	return total


func _pull_tab_counter_ritual(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var winners := _array_view(machine.get("winner_pile", []))
	var losers := _array_view(machine.get("loser_pile", []))
	var play_stack := _array_view(machine.get("ticket_stack", []))
	var tray := _array_view(machine.get("tray_stack", []))
	var suspicion := run_state.suspicion_level() if run_state != null else 0
	var transaction := _pt_copy_dict(machine.get("last_counter_transaction", {}))
	var remaining_count := _pull_tab_remaining_count(machine)
	var phase := "selection"
	if not winners.is_empty():
		phase = "redemption_ready"
	elif not play_stack.is_empty():
		phase = "play"
	elif not tray.is_empty() or str(transaction.get("phase", "")) == "handover":
		phase = "handover"
	var staff_state := "idle"
	if suspicion >= 70:
		staff_state = "refusing"
	elif suspicion >= 45:
		staff_state = "suspicious"
	elif suspicion >= 20:
		staff_state = "watching"
	elif phase == "redemption_ready":
		staff_state = "paying_out"
	elif phase == "handover":
		staff_state = "serving"
	elif remaining_count <= 0:
		staff_state = "bored"
	var deal_rows: Array = []
	for deal_value in _array_view(machine.get("deals", [])):
		var deal: Dictionary = deal_value
		deal_rows.append({
			"deal_id": str(deal.get("id", "")),
			"remaining": maxi(0, int(deal.get("remaining", 0))),
			"material_energy": "lit" if int(deal.get("remaining", 0)) > 0 else "spent",
		})
	return {
		"version": 1,
		"phase": phase,
		"actors": [{
			"id": "counter_staff",
			"label": _redeemer_label(environment),
			"state": staff_state,
			"material_energy": "alert" if staff_state in ["watching", "suspicious", "refusing"] else "working" if staff_state in ["serving", "paying_out"] else "ambient",
		}],
		"objects": [
			{"id": "deal_rack", "state": "stocked" if remaining_count > 0 else "empty", "stock": deal_rows, "material_energy": "interactive" if remaining_count > 0 else "spent"},
			{"id": "counter", "state": phase, "material_energy": "active" if phase in ["handover", "redemption_ready"] else "ambient"},
			{"id": "losing_tab_pile", "count": losers.size() + maxi(0, int(machine.get("loser_archive_count", 0))), "visible": true, "material_energy": "spent"},
		],
		"transaction": transaction,
		"attention": {"tier": staff_state, "suspicion": suspicion, "reveals_hidden_outcomes": false},
	}


func _redeemed_ticket_history(machine: Dictionary, redeemed: Array) -> Array:
	var history := _ticket_array(machine.get("redeemed_pile", []))
	for ticket in redeemed:
		if typeof(ticket) == TYPE_DICTIONARY:
			history.push_front((ticket as Dictionary).duplicate(true))
	while history.size() > 24:
		history.pop_back()
	return history


func _ticket_result_symbols(ticket: Dictionary) -> Array:
	var rows := _pt_copy_array(ticket.get("rows", []))
	if rows.is_empty():
		return []
	var winning_row := clampi(int(ticket.get("winning_row_index", -1)), -1, rows.size() - 1)
	if winning_row >= 0:
		return _string_array(rows[winning_row])
	return _string_array(rows[0])


func _ticket_max_match_count(ticket: Dictionary) -> int:
	var rows := _pt_copy_array(ticket.get("rows", []))
	var best := 0
	for row_value in rows:
		var symbols := _string_array(row_value)
		var counts := {}
		for symbol in symbols:
			counts[symbol] = int(counts.get(symbol, 0)) + 1
			best = maxi(best, int(counts.get(symbol, 0)))
	return best


func _active_ticket_id(machine: Dictionary, ui_state: Dictionary) -> String:
	var tickets := _array_view(machine.get("ticket_stack", []))
	if tickets.is_empty():
		return ""
	var cursor := _stack_cursor(ui_state, tickets.size())
	if cursor >= 0 and cursor < tickets.size() and typeof(tickets[cursor]) == TYPE_DICTIONARY:
		return str((tickets[cursor] as Dictionary).get("id", ""))
	return ""


func _stack_cursor(ui_state: Dictionary, ticket_count: int) -> int:
	if ticket_count <= 0:
		return 0
	return clampi(int(ui_state.get("pull_tab_stack_cursor", 0)), 0, ticket_count - 1)


func _selected_surface_actions(ui_state: Dictionary) -> Array:
	var action_id := str(ui_state.get("selected_action_id", ""))
	var action_kind := str(ui_state.get("selected_action_kind", ""))
	if action_id == "buy_tab" and action_kind == "legal":
		return ["pull_tab_buy"]
	if action_id == "tab_detector_scan" and action_kind == "cheat":
		return ["pull_tab_detector_scan"]
	return []


func _ticket_display_payload(ticket: Dictionary, deal: Dictionary) -> Dictionary:
	var view := ticket.duplicate(true)
	view["prize_rows"] = _ticket_prize_rows_for_view(ticket, deal)
	if bool(view.get("tarot_converted", false)):
		view["tarot_reading"] = _normalize_tarot_reading(view.get("tarot_reading", []), TAROT_READING_COUNT)
	return view


func _ticket_prize_rows_for_view(ticket: Dictionary, deal: Dictionary) -> Array:
	var ticket_prizes := _dictionary_array(ticket.get("prize_rows", []))
	if not ticket_prizes.is_empty():
		return _prize_rows_for_view(ticket_prizes)
	if not deal.is_empty():
		return _prize_rows_for_view(_dictionary_array(deal.get("prizes", [])))
	return []


func _prize_rows_for_view(prizes: Array) -> Array:
	var result: Array = []
	for prize in prizes:
		if typeof(prize) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = prize
		result.append({
			"label": str(data.get("label", "")),
			"symbols": _string_array(data.get("symbols", [])),
			"payout": int(data.get("payout", 0)),
			"remaining": int(data.get("remaining", data.get("count", 0))),
			"count": int(data.get("count", 0)),
		})
	return result


func _normalize_tarot_reading(value: Variant, fill_count: int = 0) -> Array:
	var result: Array = []
	for entry in _dictionary_array(value):
		var symbols := _string_array(entry.get("symbols", []))
		if symbols.is_empty():
			symbols = ["MISS"]
		result.append({
			"offset": maxi(0, int(entry.get("offset", result.size()))),
			"tickets_until": maxi(1, int(entry.get("tickets_until", result.size() + 1))),
			"payout": maxi(0, int(entry.get("payout", 0))),
			"label": str(entry.get("label", "No prize")),
			"symbols": symbols,
		})
	while fill_count > 0 and result.size() < fill_count:
		result.append({
			"offset": result.size(),
			"tickets_until": result.size() + 1,
			"payout": 0,
			"label": "Empty",
			"symbols": ["MISS"],
		})
	return result




func environment_hook_is_recovery(hook_id: String, action_id: String) -> bool:
	return hook_id == "ticket_redeemer" and action_id in ["", "redeem_pull_tab_winners"]


func environment_coach_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	return {"scripted_target_redeemed": tutorial_redemption_completed(run_state, environment)}
