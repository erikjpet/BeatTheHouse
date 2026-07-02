class_name PullTabsGame
extends GameModule

# Bar pull-tab module. It owns finite deal state in the current environment and
# maps the cabinet surface into the shared GameModule/RunState result path.

const SYMBOLS := ["CHERRY", "LEMON", "BELL", "BAR", "7", "CROWN"]
const TICKET_STACK_VIEW_LIMIT := 9
const TRAY_COLUMN_VIEW_LIMIT := 8
const SORTED_PILE_VIEW_LIMIT := 32
const ACTIVE_DISPENSE_EVENT_LIMIT := 48
const DEFAULT_DEAL_COUNT := 150
const MAX_DEAL_COUNT := 150
const REAL_PULL_TAB_UNIT_COUNT := 540
const PULL_TAB_INITIAL_REMOVED_MIN_RATIO := 0.04
const PULL_TAB_INITIAL_REMOVED_BAND_RATIO := 0.045
const PULL_TAB_INITIAL_REMOVED_JITTER_RATIO := 0.025
const PULL_TAB_UNIT_PRIZE_COUNTS := [
	{"id": "small", "symbol": "CHERRY", "multiplier": 1, "count": 126},
	{"id": "small_plus", "symbol": "LEMON", "multiplier": 2, "count": 25},
	{"id": "medium_small", "symbol": "BELL", "multiplier": 5, "count": 10},
	{"id": "medium", "symbol": "BAR", "multiplier": 10, "count": 2},
	{"id": "large", "symbol": "7", "multiplier": 30, "count": 1},
	{"id": "top", "symbol": "CROWN", "multiplier": 60, "count": 1},
]
const SORT_TICKET_ACTION := "sort_tab_ticket"
const REDEEM_HOOK_ID := "ticket_redeemer"
const REDEEM_ACTION_ID := "redeem_pull_tab_winners"
const CHEAT_REDEMPTION_HEAT := 7
const FAKE_TICKET_REDEMPTION_HEAT := 14
const CASHOUT_HIGH_VALUE_TICKET_THRESHOLD := 25
const CASHOUT_BULK_WINNER_THRESHOLD := 4
const CASHOUT_LOSER_TRAIL_PER_WINNER := 2
const CASHOUT_MIN_LOSER_TRAIL := 3
const CASHOUT_HISTORY_LOOKBACK := 12
const CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD := 2
const CASHOUT_REPEATED_HIGH_VALUE_HEAT := 5
const CASHOUT_LOW_LOSER_PATTERN_HEAT := 6
const CASHOUT_BULK_WINNER_HEAT_STEP := 2
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_AMBER := VisualStyleScript.AMBER
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const SURFACE_DESIGN_SIZE := Vector2(VisualStyleScript.GAME_BOARD_SIZE)
const PULL_TAB_DISPENSE_CHANNEL := "pull_tab_dispense"
const PULL_TAB_DISPENSE_EVENT_DURATION_MSEC := 760
const PULL_TAB_DISPENSE_STAGGER_MSEC := 430
const PULL_TAB_DISPENSE_DROP_START_MSEC := 240
const PULL_TAB_DISPENSE_DROP_DURATION_MSEC := 360
const PULL_TAB_REVEAL_CHANNEL := "pull_tab_reveal"
const PULL_TAB_REVEAL_ROW_DURATION_MSEC := 260
const PULL_TAB_REVEAL_STAGGER_MSEC := 310
const PULL_TAB_REVEAL_TOTAL_MSEC := 1020
const PULL_TAB_FILE_CHANNEL := "pull_tab_file"
const PULL_TAB_FILE_DURATION_MSEC := 560
const PULL_TAB_MACHINE_COLUMN_COUNT := 4
const PULL_TAB_BUY_SET_ACTION := "buy_tab_set"
const PULL_TAB_COLLECT_TRAY_ACTION := "pull_tab_collect_tray"
const PULL_TAB_FILE_TICKET_ACTION := "pull_tab_file_ticket"
const XRAY_GLASSES_ITEM_ID := "xray_glasses"
const TAB_DETECTOR_ITEM_ID := "tab_detector"
const TAROT_CARD_ITEM_ID := "tarot_card"
const XRAY_TARGET_COUNT := 2
const TAB_DETECTOR_BASE_HEAT := 4
const TAROT_READING_COUNT := 5


# Creates the entry message from the deal machine already generated with the room.
func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var result := super.enter(run_state, environment)
	result["message"] = "A pull-tab dispenser waits by the bar: four deals, sealed paper windows, and a flare chart under glass."
	result["pull_tab_machine_name"] = str(machine.get("machine_name", "Bar Pull-Tab Dispenser"))
	return result


# Pull tabs are priced per deal row, not by the venue's table stake.
func actions(run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, _environment),
		"cheat_actions": cheat_actions(run_state, _environment),
		"stake_floor": 1,
		"stake_ceiling": maxi(1, run_state.bankroll),
		"base_stake_ceiling": maxi(1, run_state.bankroll),
		"economy_state": run_state.economy(),
		"economy_pressure_applied": false,
	}


# Provides display/input state for the pull-tab cabinet without mutating state.
func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var stack_count := _array_size(machine.get("ticket_stack", []))
	var tray_count := _array_size(machine.get("tray_stack", []))
	var winner_count := _array_size(machine.get("winner_pile", []))
	var dispense_events := _dispense_event_view_list(machine)
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
	return GameModule.surface_spec({
		"surface_renderer": "pull_tab_machine",
		"surface_life": "ticket_dispenser",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_embeds_outcomes": true,
		"machine_name": str(machine.get("machine_name", "Bar Pull-Tab Dispenser")),
		"pull_tab_rules": "Buy a ticket, then peel its three windows top to bottom. Match three symbols on a row to win.",
		"pull_tab_format": "Deal flare: game, form, serial, ticket count, price, prize chart. Ticket: same form/serial plus three sealed windows.",
		"pull_tab_item_state": item_surface,
		"pull_tab_deals": _deal_view_list(machine, run_state, item_surface),
		"pull_tab_stack": _ticket_stack_view(machine, ui_state),
		"pull_tab_tray_stack": _tray_ticket_view_list(machine),
		"pull_tab_tray_column_counts": _tray_column_counts(machine),
		"pull_tab_ripped_tabs": _ripped_ticket_view_list(machine, ui_state),
		"pull_tab_winner_pile": _ticket_pile_view_list(machine, "winner_pile"),
		"pull_tab_loser_pile": _ticket_pile_view_list(machine, "loser_pile"),
		"pull_tab_pending_payout": _pending_winner_payout(machine),
		"pull_tab_redeemable_count": winner_count,
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
		"native_selected_surface_actions": _selected_surface_actions(ui_state),
		"surface_action_bindings": {
			"legal": {"action": "pull_tab_buy", "index": 0},
		},
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				PULL_TAB_DISPENSE_CHANNEL,
				last_dispense_id,
				dispense_duration_msec,
				dispense_started_msec,
				{"metadata": {"event_count": dispense_events.size(), "ticket_id": str(machine.get("last_ticket_id", ""))}}
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
			"action_cues": {
				"pull_tab_buy": "ticket_dispenser",
				"pull_tab_buy_all": "ticket_dispenser",
				PULL_TAB_COLLECT_TRAY_ACTION: "ticket_navigation",
				"pull_tab_reveal_next": "ticket_peel",
				PULL_TAB_FILE_TICKET_ACTION: "ticket_navigation",
				"pull_tab_prev": "ticket_navigation",
				"pull_tab_next": "ticket_navigation",
				"pull_tab_latest": "ticket_navigation",
				"pull_tab_next_unopened": "ticket_navigation",
			},
			"state_sync": {
				"method": "pull_tab_dispense_state",
				"animation_channel": PULL_TAB_DISPENSE_CHANNEL,
			},
		}),
	})


# Draws the pull-tab dispenser, active stack, and sorted winner/loser piles.
func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "pull_tab_machine":
		return false
	surface.surface_begin_design_space(SURFACE_DESIGN_SIZE)
	var deals := _dictionary_view_array(surface_state.get("pull_tab_deals", []))
	var stack := _dictionary_view_array(surface_state.get("pull_tab_stack", []))
	var tray_stack := _dictionary_view_array(surface_state.get("pull_tab_tray_stack", []))
	var winner_pile := _dictionary_view_array(surface_state.get("pull_tab_winner_pile", []))
	var loser_pile := _dictionary_view_array(surface_state.get("pull_tab_loser_pile", []))
	var cabinet := Rect2(20, 8, 390, 414)
	var stack_panel := Rect2(430, 18, 448, 394)
	_draw_pull_tab_cabinet(surface, cabinet, deals, tray_stack, surface_state)
	_draw_pull_tab_stack_panel(surface, stack_panel, surface_state, stack, winner_pile, loser_pile)
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)):
		_draw_pull_tab_dispense_animation(surface, surface_state, cabinet)
	return true


# Exposes a room-side clerk/cashier for redeeming sorted winning tabs.
func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return []
	var pending_payout := _pending_winner_payout(machine)
	var winner_count := _array_size(machine.get("winner_pile", []))
	var label := _redeemer_label(environment)
	return [{
		"id": REDEEM_HOOK_ID,
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"label": label,
		"short_description": "Cashes winning pull-tabs from this room.",
		"enabled": true,
		"recovery": pending_payout > 0,
		"action_summary": "Redeem %d winner%s for $%d." % [winner_count, "" if winner_count == 1 else "s", pending_payout] if winner_count > 0 else "No winning tabs to redeem.",
		"effect_summary": "Pending payout $%d." % pending_payout if pending_payout > 0 else "Sort winners here before cashing out.",
		"risk_summary": _redemption_risk_summary(machine, run_state),
		"cost_summary": "",
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "service",
		"available_actions": [{"id": REDEEM_ACTION_ID, "label": "Redeem tabs"}],
		"confirm_action_id": REDEEM_ACTION_ID,
	}]


func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return {}
	var pending_payout := _pending_winner_payout(machine)
	var winner_count := _array_size(machine.get("winner_pile", []))
	var stack_count := _array_size(machine.get("ticket_stack", []))
	var tray_count := _array_size(machine.get("tray_stack", []))
	var unresolved_count := _unresolved_pull_tab_ticket_count(machine)
	var deferred := run_state != null and run_state.bankroll <= 0 and _pull_tab_bankroll_zero_failure_deferred(machine)
	var status_bits: Array[String] = []
	if pending_payout > 0:
		status_bits.append("CASH $%d" % pending_payout)
	if tray_count > 0:
		status_bits.append("%d TRAY" % tray_count)
	if stack_count > 0:
		status_bits.append("%d OPEN" % stack_count)
	return {
		"active": unresolved_count > 0 or pending_payout > 0 or winner_count > 0,
		"bankroll_zero_failure_deferred": deferred,
		"pending_payout": pending_payout,
		"winner_count": winner_count,
		"stack_count": stack_count,
		"tray_count": tray_count,
		"unresolved_ticket_count": unresolved_count,
		"status_label": " ".join(status_bits),
		"status_summary": "Pending pull-tabs: %d tray, %d in play, $%d to redeem." % [tray_count, stack_count, pending_payout],
	}


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return {}
	var runtime_state := environment_runtime_state(run_state, environment)
	var pending_payout := _pending_winner_payout(machine)
	var winner_count := _array_size(machine.get("winner_pile", []))
	var stack_count := _array_size(machine.get("ticket_stack", []))
	var tray_count := _array_size(machine.get("tray_stack", []))
	var remaining := 0
	for deal in _deal_array(machine.get("deals", [])):
		remaining += int((deal as Dictionary).get("remaining", 0))
	var badge := ""
	if pending_payout > 0:
		badge = "CASH $%d" % pending_payout
	elif tray_count > 0:
		badge = "%d IN TRAY" % tray_count
	elif stack_count > 0:
		badge = "%d TAB%s" % [stack_count, "" if stack_count == 1 else "S"]
	runtime_state["status_label"] = badge
	runtime_state["tickets_remaining"] = remaining
	return {
		"status_summary": "%d tickets remain across four deal rows." % remaining,
		"effect_summary": "Pending payout $%d; %d tray ticket%s; %d in play." % [pending_payout, tray_count, "" if tray_count == 1 else "s", stack_count],
		"state_badge": badge,
		"runtime_state": runtime_state,
		"visual_state": {
			"machine_name": str(machine.get("machine_name", "Bar Pull-Tab Dispenser")),
			"pending_payout": pending_payout,
			"winner_count": winner_count,
			"stack_count": stack_count,
			"tray_count": tray_count,
			"tickets_remaining": remaining,
			"last_ticket_id": str(machine.get("last_ticket_id", "")),
		},
	}


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
	if run_state == null or not run_state.inventory.has(TAB_DETECTOR_ITEM_ID):
		return _empty_result("tab_detector_scan", 0, environment, "You do not have the Tab Detector.")
	var item_state := _pull_tab_item_state(machine)
	var next_active := not bool(item_state.get("tab_detector_active", false))
	item_state["tab_detector_active"] = next_active
	machine["item_state"] = item_state
	_write_machine_state(environment, machine)
	var action_def: Dictionary = _action("tab_detector_scan")
	var base_heat := int(action_def.get("suspicion_delta", TAB_DETECTOR_BASE_HEAT)) if next_active else 0
	var heat: Dictionary = _pull_tab_cheat_heat(base_heat, 1, run_state, environment)
	var suspicion_delta := int(heat.get("suspicion_delta", 0))
	var bankroll_delta := int(heat.get("bankroll_delta", 0))
	var security_message := str(heat.get("security_message", ""))
	var message := "Tab Detector switched on. Winning buys will draw rising heat." if next_active else "Tab Detector switched off."
	if suspicion_delta > 0:
		message += " Heat rises +%d." % suspicion_delta
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "tab_detector_scan",
		"item_id": TAB_DETECTOR_ITEM_ID,
		"active": next_active,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"base_heat": base_heat,
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
	result["pull_tab_base_heat"] = base_heat
	result["pull_tab_pit_boss_watched"] = bool(heat.get("pit_boss_watched", false))
	GameModule.apply_result(run_state, result, rng)
	return result


func _toggle_tab_detector_active_item(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if run_state == null or not run_state.inventory.has(TAB_DETECTOR_ITEM_ID):
		return {"handled": true, "message": "You do not have the Tab Detector."}
	var item_state := _pull_tab_item_state(machine)
	var next_active := not bool(item_state.get("tab_detector_active", false))
	item_state["tab_detector_active"] = next_active
	machine["item_state"] = item_state
	_write_machine_state(environment, machine)
	var message := "Tab Detector switched on. Winning buys will draw rising heat." if next_active else "Tab Detector switched off."
	return _pull_tab_active_item_result(TAB_DETECTOR_ITEM_ID, "toggle_tab_detector", next_active, message, environment, [])


func _arm_tarot_card_active_item(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if run_state == null or not run_state.inventory.has(TAROT_CARD_ITEM_ID):
		return {"handled": true, "message": "You do not have a Tarot Card."}
	var item_state := _pull_tab_item_state(machine)
	item_state["tarot_armed"] = true
	item_state["tarot_read_count"] = TAROT_READING_COUNT
	machine["item_state"] = item_state
	_write_machine_state(environment, machine)
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


# Generates finite deal state with the environment, before entry/selection.
func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return _generate_machine_state(run_state, environment, rng)


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
			return {
				"handled": true,
				"ui_state": _deal_ui_state(ui_state, index),
				"action_id": "buy_tab",
				"action_kind": "legal",
				"resolve": true,
				"direct_resolve": true,
				"set_stake": price,
				"selected_index": index,
				"message": "The dispenser button thumps and a %s ticket drops." % str(deal.get("display_name", "pull-tab")),
			}
		"pull_tab_buy_all":
			var available_indices: Array = []
			var total_price := 0
			for deal_index in range(mini(PULL_TAB_MACHINE_COLUMN_COUNT, deals.size())):
				var deal: Dictionary = deals[deal_index]
				var price := maxi(1, int(deal.get("price", 1)))
				if int(deal.get("remaining", 0)) <= 0 or run_state.bankroll < total_price + price:
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
		PULL_TAB_COLLECT_TRAY_ACTION:
			return _collect_tray_surface_command(machine, ui_state, environment)
		"pull_tab_reveal_next":
			return _reveal_next_command(machine, ui_state)
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
	return {"handled": false}


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
	var deals := _deal_array(machine.get("deals", []))
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
		return _empty_result(action_id, 0, environment, "Action is not available.")
	var machine := _ensure_machine_state(run_state, environment, true)
	var deals := _deal_array(machine.get("deals", []))
	var deal_index := clampi(int(ui_state.get("pull_tab_deal_index", 0)), 0, maxi(0, deals.size() - 1))
	if deals.is_empty():
		return _empty_result(action_id, 0, environment, "The pull-tab box is empty.")
	var deal: Dictionary = deals[deal_index]
	var price := maxi(1, int(deal.get("price", 1)))
	if run_state.bankroll < price:
		return _empty_result(action_id, price, environment, "Not enough bankroll for this ticket.")
	if int(deal.get("remaining", 0)) <= 0:
		return _empty_result(action_id, price, environment, "%s is sold out." % str(deal.get("display_name", "That deal")))

	var luck_modifier := 0
	var ticket := _draw_ticket_from_deal(deal, machine, false)
	if ticket.is_empty():
		return _empty_result(action_id, price, environment, "%s is sold out." % str(deal.get("display_name", "That deal")))
	ticket["deal_index"] = deal_index
	var item_effects := _apply_pull_tab_item_purchase_effects(machine, deal, ticket, deal_index, run_state)
	deals[deal_index] = deal
	machine["deals"] = deals
	var tray_stack := _ticket_array(machine.get("tray_stack", []))
	tray_stack.append(ticket)
	machine["tray_stack"] = tray_stack
	machine["tickets_sold"] = int(machine.get("tickets_sold", 0)) + 1
	machine["last_ticket_id"] = str(ticket.get("id", ""))
	machine["last_deal_id"] = str(deal.get("id", ""))
	_queue_dispense_events(machine, [ticket], [deal_index])
	_write_machine_state(environment, machine)

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
		"message": message,
	})
	_add_ticket_result_fields(result, ticket, deal, payout, price)
	result["defer_bankroll_zero_failure"] = _should_defer_bankroll_zero_failure(run_state, bankroll_delta, machine)
	result["pull_tab_detector_base_heat"] = detector_base_heat
	result["pull_tab_security_bankroll_delta"] = security_bankroll_delta
	result["pull_tab_pit_boss_watched"] = bool(detector_heat.get("pit_boss_watched", false))
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
		if run_state.bankroll < total_price + price:
			continue
		var ticket := _draw_ticket_from_deal(deal, machine, false)
		if ticket.is_empty():
			continue
		ticket["deal_index"] = deal_index
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
	var tray_stack := _ticket_array(machine.get("tray_stack", []))
	for ticket in tickets:
		tray_stack.append((ticket as Dictionary).duplicate(true))
	machine["deals"] = deals
	machine["tray_stack"] = tray_stack
	machine["tickets_sold"] = int(machine.get("tickets_sold", 0)) + tickets.size()
	machine["last_ticket_id"] = str((tickets[tickets.size() - 1] as Dictionary).get("id", ""))
	machine["last_deal_id"] = str((ticket_deals[ticket_deals.size() - 1] as Dictionary).get("id", ""))
	_queue_dispense_events(machine, tickets, deal_indices)
	_write_machine_state(environment, machine)

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
	_advance_action_rng(rng)
	GameModule.apply_result(run_state, result, rng)
	return result


func _collect_tray_surface_command(machine: Dictionary, ui_state: Dictionary, environment: Dictionary) -> Dictionary:
	var tray_stack := _ticket_array(machine.get("tray_stack", []))
	if tray_stack.is_empty():
		return GameModule.surface_command({
			"message": "The dispenser tray is empty.",
		})
	var play_stack := _ticket_array(machine.get("ticket_stack", []))
	for i in range(tray_stack.size()):
		play_stack.push_front((tray_stack[i] as Dictionary).duplicate(true))
	machine["ticket_stack"] = play_stack
	machine["tray_stack"] = []
	_write_machine_state(environment, machine)
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
		if int(reveals.get(ticket_id, 0)) < rows.size():
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
		_write_machine_state(environment, machine)
		var deal := _deal_for_ticket(machine, ticket)
		var message := "%s %s is a dead pull. It drops into the loser pile." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", ""))]
		if payout > 0:
			message = "%s %s wins $%d. Take it to the clerk to redeem." % [str(ticket.get("display_name", "Pull-tab")), str(ticket.get("ticket_number", "")), payout]
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
	_write_machine_state(environment, machine)
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
	return result


func _deal_ui_state(ui_state: Dictionary, deal_index: int) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	next_state["pull_tab_deal_index"] = deal_index
	next_state["pull_tab_stack_cursor"] = 0
	return next_state


func _reveal_next_command(machine: Dictionary, ui_state: Dictionary) -> Dictionary:
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
		var revealed := clampi(int(reveals.get(ticket_id, 0)), 0, rows.size())
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
		return {
			"handled": true,
			"ui_state": next_state,
			"selected_index": ticket_index,
			"message": message,
		}
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
		if int(reveals.get(ticket_id, 0)) < rows.size():
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
		if int(reveals.get(ticket_id, 0)) < rows.size():
			return _stack_cursor_command(machine, ui_state, index)
	return {"handled": true, "message": "Every ticket in the stack has been opened."}


func _generate_machine_state(_run_state: RunState, environment: Dictionary, rng_override: RngStream = null) -> Dictionary:
	var environment_id := str(environment.get("id", "room"))
	var machine_rng := rng_override
	if machine_rng == null:
		machine_rng = _seeded_rng("pull_tabs:%s" % environment_id)
	var deals: Array = []
	var templates := _deal_templates()
	for index in range(templates.size()):
		var template: Dictionary = (templates[index] as Dictionary).duplicate(true)
		var count := _generated_deal_ticket_count(template)
		var serial := "%03d-%05d" % [index + 1, machine_rng.randi_range(10000, 99999)]
		var prizes := _build_deal_prizes(template, count, machine_rng)
		var ticket_sleeve := _build_ticket_sleeve(prizes, count, machine_rng)
		var initial_removed_count := _initial_removed_ticket_count(count, index, machine_rng)
		var removed_summary := _burn_ticket_sleeve(ticket_sleeve, initial_removed_count, prizes)
		var deal := {
			"id": str(template.get("id", "deal_%d" % index)),
			"display_name": str(template.get("display_name", "Deal %d" % (index + 1))),
			"theme": str(template.get("theme", "")),
			"form": str(template.get("form", "PT-%03d" % index)),
			"serial": serial,
			"price": maxi(1, int(template.get("price", 1))),
			"ticket_count": count,
			"remaining": ticket_sleeve.size(),
			"sold": 0,
			"unit_cursor": initial_removed_count,
			"initial_removed_count": initial_removed_count,
			"initial_removed_winner_count": int(removed_summary.get("winner_count", 0)),
			"initial_removed_payout_total": int(removed_summary.get("payout_total", 0)),
			"palette": _pt_copy_dict(template.get("palette", {})),
			"prizes": _prizes_with_remaining_counts(prizes, ticket_sleeve),
			"ticket_sleeve": ticket_sleeve,
		}
		deals.append(deal)
	var item_state := _initial_pull_tab_item_state(deals, machine_rng)
	return {
		"schema": "pull_tab_machine_state",
		"version": 1,
		"machine_name": "Lucky Jar Pull-Tab Box",
		"deals": deals,
		"item_state": item_state,
		"environment_hooks": [{
			"id": REDEEM_HOOK_ID,
			"kind": "redeemer",
			"label": "Pull-Tab Clerk",
		}],
		"tray_stack": [],
		"ticket_stack": [],
		"winner_pile": [],
		"loser_pile": [],
		"tickets_sold": 0,
		"dispense_started_msec": 0,
		"last_dispense_id": "",
		"last_dispense_events": [],
	}


func _deal_templates() -> Array:
	return _dictionary_array(definition.get("pull_tab_deals", []))


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var game_states := _game_states_for_write(environment)
	var existing_value: Variant = game_states.get(get_id(), {})
	if typeof(existing_value) == TYPE_DICTIONARY and not (existing_value as Dictionary).is_empty():
		var existing: Dictionary = existing_value
		if _machine_state_needs_normalization(existing):
			existing = _normalize_machine_state(existing)
			if persist:
				game_states[get_id()] = existing
				environment["game_states"] = game_states
		return existing
	var generated := _generate_machine_state(run_state, environment)
	if persist:
		game_states[get_id()] = generated
		environment["game_states"] = game_states
	return generated


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) == TYPE_DICTIONARY:
		var game_states: Dictionary = game_states_value
		var machine_value: Variant = game_states.get(get_id(), {})
		if typeof(machine_value) == TYPE_DICTIONARY and not (machine_value as Dictionary).is_empty():
			return machine_value as Dictionary
	return _generate_machine_state(run_state, environment)


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


func _write_machine_state(environment: Dictionary, machine: Dictionary) -> void:
	var game_states := _game_states_for_write(environment)
	game_states[get_id()] = machine
	environment["game_states"] = game_states


func _normalize_machine_state(machine: Dictionary) -> Dictionary:
	if machine.is_empty():
		return {}
	var normalized := machine.duplicate(true)
	normalized["deals"] = _deal_array(normalized.get("deals", []))
	normalized["tray_stack"] = _ticket_array(normalized.get("tray_stack", []))
	normalized["ticket_stack"] = _ticket_array(normalized.get("ticket_stack", []))
	normalized["winner_pile"] = _ticket_array(normalized.get("winner_pile", []))
	normalized["loser_pile"] = _ticket_array(normalized.get("loser_pile", []))
	normalized["redeemed_pile"] = _ticket_array(normalized.get("redeemed_pile", []))
	normalized["environment_hooks"] = _environment_hook_array(normalized.get("environment_hooks", []))
	normalized["tickets_sold"] = int(normalized.get("tickets_sold", 0))
	normalized["item_state"] = _normalize_pull_tab_item_state(normalized)
	normalized["dispense_started_msec"] = maxi(0, int(normalized.get("dispense_started_msec", 0)))
	normalized["last_dispense_id"] = str(normalized.get("last_dispense_id", normalized.get("last_ticket_id", "")))
	normalized["last_dispense_events"] = _dispense_event_array(normalized.get("last_dispense_events", []))
	return normalized


func _initial_pull_tab_item_state(deals: Array, rng: RngStream) -> Dictionary:
	var xray_targets := _xray_targets_for_deal_indices(deals, _xray_selected_deal_indices(deals, rng))
	var item_state := {
		"xray_deal_indices": _xray_deal_indices_from_targets(xray_targets),
		"xray_targets": xray_targets,
		"tab_detector_active": false,
		"tab_detector_heat_triggers": 0,
		"tarot_armed": false,
		"tarot_read_count": TAROT_READING_COUNT,
		"last_tarot_ticket_id": "",
	}
	return _sync_legacy_xray_fields(item_state)


func _normalize_pull_tab_item_state(machine: Dictionary) -> Dictionary:
	var source := _pt_copy_dict(machine.get("item_state", {}))
	var deals := _array_view(machine.get("deals", []))
	var xray_targets := _normalize_xray_targets(source, deals)
	var item_state := {
		"xray_deal_indices": _xray_deal_indices_from_targets(xray_targets),
		"xray_targets": xray_targets,
		"tab_detector_active": bool(source.get("tab_detector_active", false)),
		"tab_detector_heat_triggers": maxi(0, int(source.get("tab_detector_heat_triggers", 0))),
		"tarot_armed": bool(source.get("tarot_armed", false)),
		"tarot_read_count": maxi(1, int(source.get("tarot_read_count", TAROT_READING_COUNT))),
		"last_tarot_ticket_id": str(source.get("last_tarot_ticket_id", "")),
	}
	return _sync_legacy_xray_fields(item_state)


func _xray_selected_deal_indices(deals: Array, rng: RngStream) -> Array:
	var candidates: Array = []
	for deal_index in range(deals.size()):
		if typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		if not _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index).is_empty():
			candidates.append(deal_index)
	if rng != null and candidates.size() > 1:
		for index in range(candidates.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var previous: int = int(candidates[index])
			candidates[index] = int(candidates[swap_index])
			candidates[swap_index] = previous
	return candidates.slice(0, mini(XRAY_TARGET_COUNT, candidates.size()))


func _xray_targets_for_deal_indices(deals: Array, deal_indices: Array) -> Array:
	var result: Array = []
	for value in deal_indices:
		var deal_index := int(value)
		if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var target := _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = false
		result.append(target)
	return result


func _normalize_xray_targets(source: Dictionary, deals: Array) -> Array:
	var targets: Array = []
	for target_value in _dictionary_array(source.get("xray_targets", [])):
		var target: Dictionary = target_value
		var consumed := bool(target.get("consumed", false))
		var deal_index := int(target.get("deal_index", -1))
		if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		if int(target.get("ticket_number", 0)) <= 0:
			target = _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = consumed
		targets.append(target)
	if targets.is_empty():
		var legacy_target := _pt_copy_dict(source.get("xray_target", {}))
		var legacy_index := int(source.get("xray_deal_index", int(legacy_target.get("deal_index", -1))))
		if legacy_target.is_empty() and legacy_index >= 0 and legacy_index < deals.size() and typeof(deals[legacy_index]) == TYPE_DICTIONARY:
			legacy_target = _highest_remaining_winner_target(deals[legacy_index] as Dictionary, legacy_index)
		if not legacy_target.is_empty():
			legacy_target["consumed"] = bool(source.get("xray_target_consumed", false))
			targets.append(legacy_target)
	var used_deal_indices := {}
	for target_value in targets:
		if typeof(target_value) == TYPE_DICTIONARY:
			used_deal_indices[int((target_value as Dictionary).get("deal_index", -1))] = true
	var desired_count := mini(XRAY_TARGET_COUNT, deals.size())
	for deal_index in range(deals.size()):
		if targets.size() >= desired_count:
			break
		if used_deal_indices.has(deal_index) or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var target := _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = false
		targets.append(target)
		used_deal_indices[deal_index] = true
	return targets.slice(0, mini(XRAY_TARGET_COUNT, targets.size()))


func _xray_deal_indices_from_targets(targets: Array) -> Array:
	var result: Array = []
	for target_value in targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var deal_index := int((target_value as Dictionary).get("deal_index", -1))
		if deal_index >= 0 and not result.has(deal_index):
			result.append(deal_index)
	return result


func _sync_legacy_xray_fields(item_state: Dictionary) -> Dictionary:
	var targets := _dictionary_array(item_state.get("xray_targets", []))
	var first_target := {}
	if not targets.is_empty():
		first_target = (targets[0] as Dictionary).duplicate(true)
	item_state["xray_targets"] = targets
	item_state["xray_deal_indices"] = _xray_deal_indices_from_targets(targets)
	item_state["xray_target"] = first_target
	item_state["xray_deal_index"] = int(first_target.get("deal_index", -1)) if not first_target.is_empty() else -1
	item_state["xray_target_consumed"] = bool(first_target.get("consumed", false)) if not first_target.is_empty() else false
	return item_state


func _pull_tab_item_state(machine: Dictionary) -> Dictionary:
	var item_state := _normalize_pull_tab_item_state(machine)
	machine["item_state"] = item_state
	return item_state


func _pull_tab_item_surface_state(machine: Dictionary, run_state: RunState) -> Dictionary:
	var item_state := _pull_tab_item_state(machine)
	var xray_available := _run_has_item(run_state, XRAY_GLASSES_ITEM_ID)
	var detector_available := _run_has_item(run_state, TAB_DETECTOR_ITEM_ID)
	var xray_targets := _visible_xray_targets(machine) if xray_available else []
	var xray_target := (xray_targets[0] as Dictionary).duplicate(true) if not xray_targets.is_empty() else {}
	return {
		"xray_available": xray_available,
		"xray_target": xray_target,
		"xray_targets": xray_targets,
		"tab_detector_available": detector_available,
		"tab_detector_active": detector_available and bool(item_state.get("tab_detector_active", false)),
		"tab_detector_highlight_index": _tab_detector_highlight_deal_index(machine) if detector_available and bool(item_state.get("tab_detector_active", false)) else -1,
		"tab_detector_next_heat": TAB_DETECTOR_BASE_HEAT + maxi(0, int(item_state.get("tab_detector_heat_triggers", 0))),
		"tarot_armed": bool(item_state.get("tarot_armed", false)),
	}


func _run_has_item(run_state: RunState, item_id: String) -> bool:
	return run_state != null and run_state.inventory.has(item_id)


func _highest_remaining_winner_target(deal: Dictionary, deal_index: int) -> Dictionary:
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	var prizes := _dictionary_array(deal.get("prizes", []))
	var best_target := {}
	var best_payout := 0
	for offset in range(sleeve.size()):
		var prize_index := int(sleeve[offset])
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		var prize: Dictionary = prizes[prize_index]
		var payout := maxi(0, int(prize.get("payout", 0)))
		if payout <= best_payout:
			continue
		best_payout = payout
		best_target = _winner_target_payload(deal, deal_index, prize_index, offset)
	return best_target


func _winner_target_payload(deal: Dictionary, deal_index: int, prize_index: int, offset: int) -> Dictionary:
	var prizes := _dictionary_array(deal.get("prizes", []))
	if prize_index < 0 or prize_index >= prizes.size():
		return {}
	var prize: Dictionary = prizes[prize_index]
	var ticket_number := int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0)))) + offset + 1
	return {
		"deal_index": deal_index,
		"deal_id": str(deal.get("id", "")),
		"ticket_number": ticket_number,
		"ticket_label": "#%03d" % ticket_number,
		"offset": offset,
		"tickets_until": offset + 1,
		"prize_index": prize_index,
		"payout": maxi(0, int(prize.get("payout", 0))),
		"label": str(prize.get("label", "")),
		"symbols": _string_array(prize.get("symbols", [])),
	}


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


func _generated_deal_ticket_count(template: Dictionary) -> int:
	var authored_count := int(template.get("ticket_count", DEFAULT_DEAL_COUNT))
	return clampi(authored_count, 1, MAX_DEAL_COUNT)


func _build_deal_prizes(template: Dictionary, ticket_count: int, _rng: RngStream) -> Array:
	var price := maxi(1, int(template.get("price", 1)))
	var result: Array = []
	for tier_index in range(PULL_TAB_UNIT_PRIZE_COUNTS.size()):
		var tier: Dictionary = PULL_TAB_UNIT_PRIZE_COUNTS[tier_index]
		var symbol := str(tier.get("symbol", "CHERRY"))
		var count := _scaled_unit_prize_count(int(tier.get("count", 0)), ticket_count, tier_index)
		var payout := price * maxi(1, int(tier.get("multiplier", 1)))
		result.append({
			"id": "%s_%s" % [str(template.get("id", "deal")), str(tier.get("id", "tier_%d" % tier_index))],
			"tier": str(tier.get("id", "tier_%d" % tier_index)),
			"label": "3 %s" % symbol,
			"symbols": [symbol, symbol, symbol],
			"payout": payout,
			"count": count,
			"remaining": count,
		})
	return _trim_prize_counts_to_ticket_count(result, ticket_count)


func _scaled_unit_prize_count(unit_count: int, ticket_count: int, tier_index: int) -> int:
	if ticket_count <= 0 or unit_count <= 0:
		return 0
	var scaled := int(round(float(ticket_count) * float(unit_count) / float(REAL_PULL_TAB_UNIT_COUNT)))
	if tier_index >= PULL_TAB_UNIT_PRIZE_COUNTS.size() - 2:
		return maxi(1, scaled)
	if tier_index == PULL_TAB_UNIT_PRIZE_COUNTS.size() - 3:
		return maxi(1, scaled)
	return maxi(0, scaled)


func _trim_prize_counts_to_ticket_count(prizes: Array, ticket_count: int) -> Array:
	var result := _normalize_prizes(prizes)
	var total := 0
	for prize in result:
		total += int((prize as Dictionary).get("count", 0))
	var max_winners := maxi(0, ticket_count - 1)
	var guard := 0
	while total > max_winners and guard < 1000:
		guard += 1
		for index in range(result.size()):
			var prize: Dictionary = result[index]
			var count := int(prize.get("count", 0))
			if count <= 0:
				continue
			if index >= result.size() - 2 and count <= 1:
				continue
			prize["count"] = count - 1
			prize["remaining"] = int(prize.get("count", 0))
			result[index] = prize
			total -= 1
			if total <= max_winners:
				break
	return result


func _build_ticket_sleeve(prizes: Array, ticket_count: int, rng: RngStream) -> Array:
	var sleeve: Array = []
	for prize_index in range(prizes.size()):
		var prize: Dictionary = prizes[prize_index]
		for _copy_index in range(maxi(0, int(prize.get("count", 0)))):
			if sleeve.size() < ticket_count:
				sleeve.append(prize_index)
	while sleeve.size() < ticket_count:
		sleeve.append(-1)
	return _shuffled_int_array(sleeve, rng)


func _initial_removed_ticket_count(ticket_count: int, deal_index: int, rng: RngStream) -> int:
	if ticket_count <= 1:
		return 0
	var base := int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_MIN_RATIO))
	var band := int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_BAND_RATIO))
	var jitter_max := maxi(1, int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_JITTER_RATIO)))
	var removed := base + deal_index * maxi(1, band) + rng.randi_range(0, jitter_max)
	return clampi(removed, 0, maxi(0, ticket_count - 1))


func _burn_ticket_sleeve(sleeve: Array, burn_count: int, prizes: Array) -> Dictionary:
	var removed_count := mini(maxi(0, burn_count), maxi(0, sleeve.size() - 1))
	var winner_count := 0
	var payout_total := 0
	for _index in range(removed_count):
		if sleeve.is_empty():
			break
		var prize_index := int(sleeve.pop_front())
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		var prize: Dictionary = prizes[prize_index]
		winner_count += 1
		payout_total += maxi(0, int(prize.get("payout", 0)))
	return {
		"count": removed_count,
		"winner_count": winner_count,
		"payout_total": payout_total,
	}


func _prizes_with_remaining_counts(prizes: Array, sleeve: Array) -> Array:
	var result := _normalize_prizes(prizes)
	var remaining_counts: Array = []
	for _index in range(result.size()):
		remaining_counts.append(0)
	for entry in sleeve:
		var prize_index := int(entry)
		if prize_index >= 0 and prize_index < remaining_counts.size():
			remaining_counts[prize_index] = int(remaining_counts[prize_index]) + 1
	for index in range(result.size()):
		var prize: Dictionary = result[index]
		prize["remaining"] = int(remaining_counts[index])
		result[index] = prize
	return result


func _shuffled_int_array(values: Array, rng: RngStream) -> Array:
	var result := _int_array(values)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var previous: int = int(result[index])
		result[index] = result[swap_index]
		result[swap_index] = previous
	return result


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
		winning_prize = (prizes[prize_index] as Dictionary).duplicate(true)
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
		result.append({
			"id": str(deal.get("id", "")),
			"index": index,
			"display_name": str(deal.get("display_name", "")),
			"theme": str(deal.get("theme", "")),
			"form": str(deal.get("form", "")),
			"serial": str(deal.get("serial", "")),
			"price": price,
			"ticket_count": int(deal.get("ticket_count", remaining)),
			"remaining": remaining,
			"enabled": run_state != null and run_state.bankroll >= price and remaining > 0,
			"prize_rows": _prize_rows_for_view(prizes),
			"palette": _pt_copy_dict(deal.get("palette", {})),
			"xray_target": _xray_target_for_deal(machine, index) if bool(item_surface.get("xray_available", false)) else {},
			"tab_detector_highlight": bool(item_surface.get("tab_detector_active", false)) and index == detector_highlight_index,
			"tab_detector_active": bool(item_surface.get("tab_detector_active", false)),
			"tab_detector_next_heat": int(item_surface.get("tab_detector_next_heat", TAB_DETECTOR_BASE_HEAT)),
		})
	return result


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
		var revealed := clampi(int(reveals.get(ticket_id, 0)), 0, rows.size())
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


func _queue_dispense_events(machine: Dictionary, tickets: Array, deal_indices: Array) -> void:
	var now_msec := Time.get_ticks_msec()
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
			"ticket": ticket.duplicate(true),
			"deal_index": clampi(deal_index, 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1),
			"sequence_index": sequence_offset + index,
			"start_msec": start_msec,
			"drop_start_msec": PULL_TAB_DISPENSE_DROP_START_MSEC,
			"drop_duration_msec": PULL_TAB_DISPENSE_DROP_DURATION_MSEC,
		})
	return events


func _dispense_event_view_list(machine: Dictionary) -> Array:
	return _active_dispense_events(machine, Time.get_ticks_msec())


func _active_dispense_events(machine: Dictionary, now_msec: int) -> Array:
	var started_msec := int(machine.get("dispense_started_msec", 0))
	if started_msec <= 0:
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


func _ripped_ticket_view_list(machine: Dictionary, _ui_state: Dictionary) -> Array:
	var result: Array = []
	result.append_array(_ticket_pile_view_list(machine, "winner_pile"))
	result.append_array(_ticket_pile_view_list(machine, "loser_pile"))
	if result.size() > 16:
		return result.slice(0, 16)
	return result


func _ticket_pile_view_list(machine: Dictionary, pile_name: String) -> Array:
	var tickets := _array_view(machine.get(pile_name, []))
	var result: Array = []
	var start_index := maxi(0, tickets.size() - SORTED_PILE_VIEW_LIMIT)
	for ticket_index in range(start_index, tickets.size()):
		var ticket := _ticket_dict(tickets[ticket_index])
		if ticket.is_empty():
			continue
		var rows := _pt_copy_array(ticket.get("rows", []))
		var deal := _deal_for_ticket(machine, ticket)
		var view := _ticket_display_payload(ticket, deal)
		view["pile"] = pile_name
		view["stack_index"] = ticket_index
		view["pile_depth_index"] = ticket_index
		view["revealed_count"] = rows.size()
		view["fully_revealed"] = true
		result.append(view)
	return result


func _pending_winner_payout(machine: Dictionary) -> int:
	return _ticket_payout_total(_array_view(machine.get("winner_pile", [])))


func _unresolved_pull_tab_ticket_count(machine: Dictionary) -> int:
	return _array_size(machine.get("tray_stack", [])) + _array_size(machine.get("ticket_stack", []))


func _pull_tab_bankroll_zero_failure_deferred(machine: Dictionary) -> bool:
	return _unresolved_pull_tab_ticket_count(machine) > 0 \
		or _array_size(machine.get("winner_pile", [])) > 0 \
		or _pending_winner_payout(machine) > 0


func _should_defer_bankroll_zero_failure(run_state: RunState, bankroll_delta: int, machine: Dictionary) -> bool:
	if run_state == null:
		return false
	return run_state.bankroll + bankroll_delta <= 0 and _pull_tab_bankroll_zero_failure_deferred(machine)


func _ticket_payout_total(tickets: Array) -> int:
	var total := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			total += maxi(0, int((ticket_value as Dictionary).get("payout", 0)))
	return total


func _ticket_cost_total(tickets: Array) -> int:
	var total := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			total += maxi(1, int((ticket_value as Dictionary).get("price", 1)))
	return total


func _suspicious_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		if bool(ticket.get("tainted", false)) or bool(ticket.get("fake", false)):
			count += 1
	return count


func _fake_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY and bool((ticket_value as Dictionary).get("fake", false)):
			count += 1
	return count


func _redemption_context(machine: Dictionary, tickets: Array, run_state: RunState, environment: Dictionary = {}, stake: int = 1) -> Dictionary:
	var winners := _ticket_array(tickets)
	var losers := _ticket_array(machine.get("loser_pile", []))
	var redeemed_history := _ticket_array(machine.get("redeemed_pile", []))
	var payout := _ticket_payout_total(winners)
	var suspicious_count := _suspicious_ticket_count(winners)
	var fake_count := _fake_ticket_count(winners)
	var current_high_value_count := _high_value_ticket_count(winners)
	var recent_history := _recent_ticket_history(redeemed_history, CASHOUT_HISTORY_LOOKBACK)
	var recent_high_value_count := _high_value_ticket_count(recent_history)
	var loser_count := losers.size()
	var winner_count := winners.size()
	var expected_loser_trail := _expected_cashout_loser_trail(winner_count)
	var low_loser_trail := winner_count > 0 and loser_count < expected_loser_trail
	var risk_reasons: Array = []
	var ticket_heat := suspicious_count * CHEAT_REDEMPTION_HEAT + fake_count * FAKE_TICKET_REDEMPTION_HEAT
	if suspicious_count > 0:
		risk_reasons.append("bent_or_fake_tabs")
	var pattern_heat := 0
	if low_loser_trail:
		var combined_high_value_count := current_high_value_count + recent_high_value_count
		if current_high_value_count > 0 and combined_high_value_count >= CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD:
			pattern_heat += CASHOUT_REPEATED_HIGH_VALUE_HEAT + maxi(0, combined_high_value_count - CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD)
			risk_reasons.append("repeated_high_value_winners_low_loser_trail")
		if winner_count >= CASHOUT_BULK_WINNER_THRESHOLD:
			pattern_heat += CASHOUT_LOW_LOSER_PATTERN_HEAT + maxi(0, winner_count - CASHOUT_BULK_WINNER_THRESHOLD) * CASHOUT_BULK_WINNER_HEAT_STEP
			risk_reasons.append("bulk_winners_low_loser_trail")
	var base_heat := ticket_heat + pattern_heat
	var heat: Dictionary = _pull_tab_cheat_heat(base_heat, stake, run_state, environment)
	return {
		"payout": payout,
		"winner_ticket_count": winner_count,
		"loser_ticket_count": loser_count,
		"expected_loser_trail": expected_loser_trail,
		"low_loser_trail": low_loser_trail,
		"suspicious_ticket_count": suspicious_count,
		"fake_ticket_count": fake_count,
		"current_high_value_ticket_count": current_high_value_count,
		"recent_high_value_ticket_count": recent_high_value_count,
		"ticket_heat": ticket_heat,
		"pattern_heat": pattern_heat,
		"base_heat": maxi(0, base_heat),
		"heat": int(heat.get("suspicion_delta", 0)),
		"security_bankroll_delta": int(heat.get("bankroll_delta", 0)),
		"security_message": str(heat.get("security_message", "")),
		"ended": bool(heat.get("ended", false)),
		"pit_boss_watched": bool(heat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(heat.get("pit_boss_heat_bonus", 0)),
		"risk_reasons": risk_reasons,
	}


func _pull_tab_cheat_heat(base_heat: int, stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	if base_heat <= 0:
		return {
			"suspicion_delta": 0,
			"bankroll_delta": 0,
			"security_message": "",
			"ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	if run_state == null:
		return {
			"suspicion_delta": maxi(0, base_heat),
			"bankroll_delta": 0,
			"security_message": "",
			"ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(0, base_heat + _item_bonus("cheat_suspicion_delta", run_state, true) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if raw_heat > 0 else 0
	var pressure: Dictionary = run_state.security_action_pressure("cheat", maxi(1, stake), run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var security_message := str(pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		security_message = "%s %s" % [pit_boss_summary, security_message]
		security_message = security_message.strip_edges()
	return {
		"suspicion_delta": suspicion_delta,
		"bankroll_delta": int(pressure.get("bankroll_delta", 0)),
		"security_message": security_message,
		"ended": bool(pressure.get("ended", false)),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
	}


func _redemption_risk_summary(machine: Dictionary, run_state: RunState) -> String:
	var winners := _ticket_array(machine.get("winner_pile", []))
	if winners.is_empty():
		return "No redemption risk yet."
	var redemption_context := _redemption_context(machine, winners, run_state)
	var suspicious_count := int(redemption_context.get("suspicious_ticket_count", 0))
	var heat := int(redemption_context.get("heat", 0))
	if heat <= 0:
		return "Routine cashout."
	if suspicious_count > 0:
		return "Bent or fake tabs may add heat +%d." % heat
	return "%s Heat +%d." % [_redemption_attention_message(redemption_context), heat]


func _redemption_attention_message(redemption_context: Dictionary) -> String:
	var reasons := _pt_copy_array(redemption_context.get("risk_reasons", []))
	if reasons.has("bent_or_fake_tabs"):
		return "The cashier studies the tabs for tampering."
	if reasons.has("bulk_winners_low_loser_trail") and reasons.has("repeated_high_value_winners_low_loser_trail"):
		return "The cashier notices a streak of valuable winners with too few dead tabs."
	if reasons.has("bulk_winners_low_loser_trail"):
		return "The cashier notices the winner stack is too thick for the dead tabs shown."
	if reasons.has("repeated_high_value_winners_low_loser_trail"):
		return "The cashier notices another high-value winner without enough dead tabs."
	return "The cashout draws attention."


func _expected_cashout_loser_trail(winner_count: int) -> int:
	if winner_count <= 0:
		return 0
	return maxi(CASHOUT_MIN_LOSER_TRAIL, winner_count * CASHOUT_LOSER_TRAIL_PER_WINNER)


func _recent_ticket_history(tickets: Array, limit: int) -> Array:
	var result: Array = []
	for ticket in _ticket_array(tickets):
		if result.size() >= limit:
			break
		result.append(ticket)
	return result


func _high_value_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		if int(ticket.get("payout", 0)) >= CASHOUT_HIGH_VALUE_TICKET_THRESHOLD:
			count += 1
	return count


func _redeemer_label(environment: Dictionary) -> String:
	var scene_type := str(environment.get("visual_context", {}).get("scene_type", ""))
	if scene_type == "bar" or str(environment.get("archetype_id", "")) == "bar":
		return "Bartender"
	return "Pull-Tab Clerk"


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


func _normalize_prizes(value: Variant) -> Array:
	var result: Array = []
	for prize in _dictionary_array(value):
		var prize_data: Dictionary = prize.duplicate(true)
		prize_data["count"] = maxi(0, int(prize_data.get("count", 0)))
		prize_data["remaining"] = maxi(0, int(prize_data.get("remaining", prize_data.get("count", 0))))
		prize_data["payout"] = maxi(0, int(prize_data.get("payout", 0)))
		prize_data["symbols"] = _string_array(prize_data.get("symbols", []))
		result.append(prize_data)
	return result


func _legacy_ticket_sleeve_for_deal(deal: Dictionary) -> Array:
	var remaining := maxi(0, int(deal.get("remaining", 0)))
	if remaining <= 0:
		return []
	var prizes := _normalize_prizes(deal.get("prizes", []))
	for index in range(prizes.size()):
		var prize: Dictionary = prizes[index]
		var remaining_prizes := maxi(0, int(prize.get("remaining", prize.get("count", 0))))
		prize["count"] = remaining_prizes
		prize["remaining"] = remaining_prizes
		prizes[index] = prize
	var serial := str(deal.get("serial", deal.get("id", "legacy")))
	return _build_ticket_sleeve(prizes, remaining, _seeded_rng("pull_tabs:legacy_sleeve:%s" % serial))


func _deal_array(value: Variant) -> Array:
	var result: Array = []
	for deal in _dictionary_array(value):
		var deal_data: Dictionary = deal.duplicate(true)
		deal_data["price"] = maxi(1, int(deal_data.get("price", 1)))
		deal_data["ticket_count"] = maxi(0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["remaining"] = clampi(int(deal_data.get("remaining", deal_data.get("ticket_count", DEFAULT_DEAL_COUNT))), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["sold"] = maxi(0, int(deal_data.get("sold", 0)))
		deal_data["unit_cursor"] = clampi(int(deal_data.get("unit_cursor", int(deal_data.get("initial_removed_count", 0)) + int(deal_data.get("sold", 0)))), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["initial_removed_count"] = clampi(int(deal_data.get("initial_removed_count", 0)), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["initial_removed_winner_count"] = maxi(0, int(deal_data.get("initial_removed_winner_count", 0)))
		deal_data["initial_removed_payout_total"] = maxi(0, int(deal_data.get("initial_removed_payout_total", 0)))
		deal_data["prizes"] = _normalize_prizes(deal_data.get("prizes", []))
		var sleeve := _int_array(deal_data.get("ticket_sleeve", []))
		if sleeve.is_empty() and int(deal_data.get("remaining", 0)) > 0:
			sleeve = _legacy_ticket_sleeve_for_deal(deal_data)
		deal_data["ticket_sleeve"] = sleeve
		if not sleeve.is_empty() or int(deal_data.get("remaining", 0)) <= 0:
			deal_data["remaining"] = sleeve.size()
		deal_data["palette"] = _pt_copy_dict(deal_data.get("palette", {}))
		result.append(deal_data)
	return result


func _ticket_array(value: Variant) -> Array:
	var result: Array = []
	for ticket in _array_view(value):
		var ticket_data := _ticket_dict(ticket)
		if not ticket_data.is_empty():
			result.append(ticket_data)
	return result


func _ticket_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var ticket_data: Dictionary = (value as Dictionary).duplicate(true)
	ticket_data["price"] = maxi(1, int(ticket_data.get("price", 1)))
	ticket_data["payout"] = maxi(0, int(ticket_data.get("payout", 0)))
	if ticket_data.has("deal_index"):
		ticket_data["deal_index"] = clampi(int(ticket_data.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
	ticket_data["rows"] = _pt_copy_array(ticket_data.get("rows", []))
	ticket_data["palette"] = _pt_copy_dict(ticket_data.get("palette", {}))
	ticket_data["tainted"] = bool(ticket_data.get("tainted", false))
	ticket_data["fake"] = bool(ticket_data.get("fake", false))
	ticket_data["sorted"] = bool(ticket_data.get("sorted", false))
	return ticket_data


func _dispense_event_array(value: Variant) -> Array:
	var result: Array = []
	for event in _dictionary_array(value):
		var data: Dictionary = event.duplicate(true)
		data["ticket_id"] = str(data.get("ticket_id", ""))
		data["ticket"] = _ticket_dict(data.get("ticket", {}))
		data["deal_index"] = clampi(int(data.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		data["sequence_index"] = maxi(0, int(data.get("sequence_index", result.size())))
		data["start_msec"] = maxi(0, int(data.get("start_msec", int(data.get("sequence_index", result.size())) * PULL_TAB_DISPENSE_STAGGER_MSEC)))
		data["drop_start_msec"] = maxi(0, int(data.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC)))
		data["drop_duration_msec"] = maxi(1, int(data.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC)))
		if not str(data.get("ticket_id", "")).is_empty():
			result.append(data)
	return result


func _environment_hook_array(value: Variant) -> Array:
	var hooks := _dictionary_array(value)
	if hooks.is_empty():
		return [{
			"id": REDEEM_HOOK_ID,
			"kind": "redeemer",
			"label": "Pull-Tab Clerk",
		}]
	return hooks


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(int(entry))
	return result


func _draw_pull_tab_cabinet(surface, cabinet: Rect2, deals: Array, tray_stack: Array, surface_state: Dictionary) -> void:
	var clock := float(surface.surface_flicker())
	var side := [
		cabinet.position + Vector2(54, 0),
		cabinet.position + Vector2(cabinet.size.x, 18),
		cabinet.position + Vector2(cabinet.size.x, cabinet.size.y),
		cabinet.position + Vector2(0, cabinet.size.y - 4),
		cabinet.position + Vector2(0, 58),
	]
	surface.draw_polygon(side, [Color("#08090c")])
	surface.draw_polygon([
		cabinet.position + Vector2(54, 0),
		cabinet.position + Vector2(cabinet.size.x, 18),
		cabinet.position + Vector2(cabinet.size.x - 22, 70),
		cabinet.position + Vector2(24, 54),
	], [Color("#1d222b")])
	surface.draw_rect(Rect2(cabinet.position + Vector2(0, 58), Vector2(cabinet.size.x - 22, cabinet.size.y - 60)), Color("#11141a"))
	surface.draw_rect(Rect2(cabinet.position + Vector2(10, 66), Vector2(cabinet.size.x - 42, cabinet.size.y - 76)), Color("#1b2028"))
	surface.draw_rect(Rect2(cabinet.position + Vector2(0, 58), Vector2(cabinet.size.x - 22, cabinet.size.y - 60)), Color("#3a404b"), false, 3)
	_draw_pull_tab_master_marquee(surface, Rect2(cabinet.position + Vector2(74, 16), Vector2(236, 44)))
	var window := Rect2(cabinet.position + Vector2(30, 82), Vector2(242, 166))
	_draw_pull_tab_window_stacks(surface, window, deals, surface_state)
	var control_panel := Rect2(cabinet.position + Vector2(282, 82), Vector2(76, 166))
	_draw_pull_tab_control_panel(surface, control_panel, deals)
	var button_rail := Rect2(cabinet.position + Vector2(18, 254), Vector2(340, 42))
	surface.draw_rect(button_rail, Color("#0c0e12"))
	surface.draw_rect(button_rail, Color("#353a43"), false, 2)
	for index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var deal := (deals[index] as Dictionary) if index < deals.size() else {}
		var button_rect := Rect2(button_rail.position + Vector2(14 + index * 56, 7), Vector2(44, 26))
		_draw_pull_tab_column_button(surface, deal, index, button_rect)
	var master_rect := Rect2(button_rail.position + Vector2(264, 6), Vector2(58, 28))
	_draw_pull_tab_master_button(surface, deals, master_rect)
	var tray := Rect2(cabinet.position + Vector2(24, 304), Vector2(300, 82))
	_draw_pull_tab_machine_tray(surface, tray, tray_stack, surface_state)
	var lower_cut := Rect2(cabinet.position + Vector2(24, 392), Vector2(300, 50))
	surface.draw_rect(lower_cut, Color("#151922"))
	surface.draw_rect(lower_cut, Color("#353a43"), false, 2)
	surface.draw_circle(cabinet.position + Vector2(198, 408), 3.0 + absf(sin(clock * 2.0)) * 0.7, Color("#da355a"))


func _draw_pull_tab_master_marquee(surface, rect: Rect2) -> void:
	var points := [
		rect.position + Vector2(0, 7),
		rect.position + Vector2(rect.size.x - 12, 0),
		rect.end - Vector2(0, 8),
		rect.position + Vector2(12, rect.size.y),
	]
	surface.draw_polygon(points, [Color("#f6f2e8")])
	for i in range(points.size()):
		surface.draw_line(points[i], points[(i + 1) % points.size()], Color("#2b3038"), 2)
	surface.surface_label("THE", rect.position + Vector2(-30, 18), 13, C_PINK)
	surface.surface_label("MASTER", rect.position + Vector2(44, 31), 27, C_PINK)
	surface.surface_label("4", rect.end + Vector2(8, -16), 20, C_PINK)


func _draw_pull_tab_window_stacks(surface, rect: Rect2, deals: Array, surface_state: Dictionary) -> void:
	surface.draw_rect(rect.grow(6), Color("#050608"))
	surface.draw_rect(rect, Color("#090b10"))
	surface.draw_rect(rect, Color("#d5e2e8"), false, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)), Color("#10131a"))
	for index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var deal := (deals[index] as Dictionary) if index < deals.size() else {}
		var column_rect := Rect2(rect.position + Vector2(18 + index * 52, 16), Vector2(38, rect.size.y - 32))
		_draw_pull_tab_column_stack(surface, column_rect, deal, index, surface_state)
	var glare_alpha := 0.10 + absf(sin(float(surface.surface_flicker()) * 1.7)) * 0.04
	surface.draw_polygon([
		rect.position + Vector2(12, 6),
		rect.position + Vector2(rect.size.x * 0.40, 6),
		rect.position + Vector2(rect.size.x * 0.24, rect.size.y - 8),
		rect.position + Vector2(4, rect.size.y - 8),
	], [Color(1.0, 1.0, 1.0, glare_alpha)])


func _draw_pull_tab_column_stack(surface, rect: Rect2, deal: Dictionary, index: int, surface_state: Dictionary) -> void:
	var palette: Dictionary = deal.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var count := maxi(1, int(deal.get("ticket_count", DEFAULT_DEAL_COUNT)))
	var remaining := clampi(int(deal.get("remaining", count)), 0, count)
	var ratio := clampf(float(remaining) / float(count), 0.0, 1.0)
	var min_height := 18.0 if remaining > 0 else 0.0
	var stack_height := maxf(min_height, rect.size.y * ratio)
	var stack_rect := Rect2(Vector2(rect.position.x, rect.end.y - stack_height), Vector2(rect.size.x, stack_height))
	surface.draw_rect(rect, Color("#06080d"))
	surface.draw_rect(rect, Color("#2e3440"), false, 1)
	if remaining <= 0:
		surface.draw_line(rect.position + Vector2(6, rect.size.y * 0.5), rect.end - Vector2(6, rect.size.y * 0.5), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.60), 2)
		return
	for row in range(0, int(stack_height), 7):
		var y := stack_rect.end.y - float(row)
		var shade := 0.86 - float((row / 7 + index) % 3) * 0.045
		surface.draw_rect(Rect2(stack_rect.position.x + 5, y - 4, stack_rect.size.x - 10, 4), Color(paper.r * shade, paper.g * shade, paper.b * shade, 0.95))
		surface.draw_rect(Rect2(stack_rect.position.x + 8, y - 3, stack_rect.size.x - 16, 1), Color(accent.r, accent.g, accent.b, 0.38))
	var top := Rect2(stack_rect.position + Vector2(4, -2), Vector2(stack_rect.size.x - 8, 10))
	surface.draw_rect(top, paper)
	surface.draw_rect(top, accent, false, 1)
	var xray_target := _pt_copy_dict(deal.get("xray_target", {}))
	if not xray_target.is_empty():
		var offset := clampi(int(xray_target.get("offset", 0)), 0, maxi(0, remaining - 1))
		var depth_ratio := clampf((float(offset) + 0.5) / float(maxi(1, remaining)), 0.0, 1.0)
		var target_y := stack_rect.end.y - stack_height * depth_ratio
		var glow := 0.55 + absf(sin(float(surface.surface_flicker()) * 4.7 + float(index))) * 0.30
		var glow_rect := Rect2(Vector2(stack_rect.position.x + 1, target_y - 5.0), Vector2(stack_rect.size.x - 2.0, 10.0))
		surface.draw_rect(glow_rect.grow(3.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.15 * glow))
		surface.draw_rect(glow_rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.72 * glow), false, 2)
		surface.surface_label("$%d" % int(xray_target.get("payout", 0)), glow_rect.position + Vector2(4, 8), 7, C_YELLOW)
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)) and bool(_dispense_column_active(surface_state, index)):
		surface.draw_rect(rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22), false, 2)


func _draw_pull_tab_control_panel(surface, rect: Rect2, deals: Array) -> void:
	surface.draw_rect(rect, Color("#ece9dd"))
	surface.draw_rect(rect, Color("#2b3038"), false, 2)
	surface.draw_circle(rect.position + Vector2(rect.size.x * 0.5, 14), 5, Color("#1b2028"))
	surface.draw_rect(Rect2(rect.position + Vector2(12, 28), Vector2(rect.size.x - 24, 12)), Color("#33c85a"))
	surface.surface_label("PLAY", rect.position + Vector2(19, 64), 12, C_PINK)
	surface.surface_label("THE", rect.position + Vector2(25, 82), 13, C_PINK)
	surface.surface_label("MASTER", rect.position + Vector2(8, 104), 17, C_PINK)
	surface.draw_rect(Rect2(rect.position + Vector2(14, 126), Vector2(rect.size.x - 28, 22)), Color("#16191f"))
	surface.draw_rect(Rect2(rect.position + Vector2(24, 133), Vector2(rect.size.x - 48, 5)), Color("#0b0d12"))


func _draw_pull_tab_column_button(surface, deal: Dictionary, index: int, rect: Rect2) -> void:
	var enabled := bool(deal.get("enabled", false))
	var palette: Dictionary = deal.get("palette", {})
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var hovered := bool(surface.surface_region_hovered("pull_tab_buy", index))
	var price := maxi(1, int(deal.get("price", 1)))
	var base := Color("#e8e3d2") if enabled else Color("#454850")
	if hovered and enabled:
		base = Color("#fff5c8")
	surface.draw_rect(rect, Color(0, 0, 0, 0.36))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), base)
	surface.draw_rect(rect, accent if enabled else Color("#2f3136"), false, 2 if hovered else 1)
	surface.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 12), Vector2(rect.size.x - 8, 8)), Color(0.0, 0.0, 0.0, 0.12 if enabled else 0.20))
	if bool(deal.get("tab_detector_highlight", false)):
		var pulse := 0.62 + absf(sin(Time.get_ticks_msec() / 160.0 + float(index))) * 0.36
		surface.draw_rect(rect.grow(4.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.16 * pulse))
		surface.draw_rect(rect.grow(3.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.88 * pulse), false, 2)
	var text_color := Color("#171217") if enabled else C_SOFT
	surface.surface_label_centered("%d" % (index + 1), Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 10)), 8, text_color)
	surface.surface_label_centered("$%d" % price, Rect2(rect.position + Vector2(3, rect.size.y - 13), Vector2(rect.size.x - 6, 10)), 8, text_color)
	if enabled:
		surface.surface_add_exact_invisible_hit(rect.grow(5), "pull_tab_buy", index)


func _draw_pull_tab_master_button(surface, deals: Array, rect: Rect2) -> void:
	var enabled := false
	for deal in deals:
		if typeof(deal) == TYPE_DICTIONARY and bool((deal as Dictionary).get("enabled", false)):
			enabled = true
			break
	var hovered := bool(surface.surface_region_hovered("pull_tab_buy_all", 0))
	var base := Color("#f4f0dc") if enabled else Color("#454850")
	if hovered and enabled:
		base = Color("#fff4b8")
	surface.draw_rect(rect, Color(0, 0, 0, 0.38))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), base)
	surface.draw_rect(rect, C_YELLOW if enabled else Color("#2f3136"), false, 2 if hovered else 1)
	surface.surface_label("ALL 4", rect.position + Vector2(10, 18), 10, Color("#171217") if enabled else C_SOFT)
	if enabled:
		surface.surface_add_invisible_hit(rect.grow(5), "pull_tab_buy_all", 0)


func _draw_pull_tab_machine_tray(surface, rect: Rect2, tray_stack: Array, surface_state: Dictionary) -> void:
	surface.draw_rect(rect, Color("#050608"))
	surface.draw_rect(Rect2(rect.position + Vector2(10, 14), Vector2(rect.size.x - 20, 40)), Color("#07080c"))
	surface.draw_rect(Rect2(rect.position + Vector2(14, 18), Vector2(rect.size.x - 28, 30)), Color("#111822"))
	surface.draw_rect(rect, Color("#393e48"), false, 2)
	var hidden_ids := _active_dispense_hidden_ticket_ids(surface, surface_state)
	var column_counts := _int_array(surface_state.get("pull_tab_tray_column_counts", []))
	var column_tickets: Array = []
	var hidden_counts: Array = []
	for _column in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		column_tickets.append([])
		hidden_counts.append(0)
	for ticket_value in tray_stack:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		var deal_index := clampi(int(ticket.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		if hidden_ids.has(str(ticket.get("id", ""))):
			hidden_counts[deal_index] = int(hidden_counts[deal_index]) + 1
			continue
		(column_tickets[deal_index] as Array).append(ticket)
	var visible_total := 0
	for deal_index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var pile_rect := _pull_tab_tray_column_pile_rect(rect, deal_index)
		var tickets: Array = column_tickets[deal_index]
		visible_total += tickets.size()
		var total_count := _tray_column_total(column_counts, deal_index, tickets.size()) - int(hidden_counts[deal_index])
		_draw_pull_tab_tray_column_pile(surface, pile_rect, tickets, maxi(total_count, tickets.size()), deal_index)
	if int(surface_state.get("pull_tab_tray_count", tray_stack.size())) <= 0 and visible_total <= 0:
		surface.surface_label("TRAY", rect.position + Vector2(122, 41), 13, C_AMBER)
	else:
		surface.surface_label("COLLECT TRAY", rect.position + Vector2(98, 70), 10, C_YELLOW)
		surface.surface_add_invisible_hit(rect, PULL_TAB_COLLECT_TRAY_ACTION, 0)


func _pull_tab_tray_column_pile_rect(rect: Rect2, deal_index: int) -> Rect2:
	var column_width := 50.0
	var gap := 6.0
	var start_x := rect.position.x + 8.0
	return Rect2(Vector2(start_x + float(deal_index) * (column_width + gap), rect.position.y + 18.0), Vector2(column_width, 38.0))


func _tray_column_total(column_counts: Array, deal_index: int, fallback: int) -> int:
	if deal_index >= 0 and deal_index < column_counts.size():
		return maxi(0, int(column_counts[deal_index]))
	return fallback


func _draw_pull_tab_tray_column_pile(surface, rect: Rect2, tickets: Array, total_count: int, deal_index: int) -> void:
	var accent := Color("#46515d")
	if not tickets.is_empty() and typeof(tickets[tickets.size() - 1]) == TYPE_DICTIONARY:
		var palette: Dictionary = (tickets[tickets.size() - 1] as Dictionary).get("palette", {})
		accent = Color(str(palette.get("accent", "#ff4fb3")))
	surface.draw_rect(rect, Color("#07090d"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.18), false, 1)
	if total_count <= 0:
		surface.surface_label(str(deal_index + 1), rect.position + Vector2(22, 28), 10, Color("#3c4651"))
		return
	var buried_count := maxi(0, total_count - tickets.size())
	var ticket_size := Vector2(rect.size.x - 8.0, 18.0)
	var bottom_y := rect.position.y + rect.size.y - ticket_size.y - 3.0
	var buried_lift := minf(10.0, float(buried_count) * 1.5)
	if buried_count > 0:
		for shadow_index in range(mini(buried_count, 5)):
			var shadow_rect := Rect2(
				Vector2(rect.position.x + 4.0, bottom_y - float(shadow_index) * 2.0),
				ticket_size
			)
			surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.08))
			surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.12), false, 1)
	for index in range(tickets.size()):
		if typeof(tickets[index]) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = tickets[index]
		var pos := Vector2(rect.position.x + 4.0 + float(index % 2), bottom_y - buried_lift - float(index) * 4.0)
		_draw_pull_tab_tray_ticket(surface, ticket, Rect2(pos, ticket_size), index)


func _draw_pull_tab_tray_ticket(surface, ticket: Dictionary, rect: Rect2, index: int) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var y_offset := float(index % 2) * 3.0
	var live_rect := Rect2(rect.position + Vector2(0, y_offset), rect.size)
	surface.draw_rect(live_rect, paper)
	surface.draw_rect(live_rect, accent, false, 1)
	surface.draw_rect(Rect2(live_rect.position + Vector2(6, 7), Vector2(live_rect.size.x - 12, 5)), Color(accent.r, accent.g, accent.b, 0.34))
	surface.surface_label(str(ticket.get("ticket_number", "")).left(5), live_rect.position + Vector2(8, 19), 7, Color("#21131d"))


func _draw_pull_tab_stack_panel(surface, rect: Rect2, surface_state: Dictionary, stack: Array, winner_pile: Array, loser_pile: Array) -> void:
	surface.draw_rect(rect, Color("#071015"))
	surface.draw_rect(rect, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22), false, 2)
	var count := int(surface_state.get("pull_tab_stack_count", stack.size()))
	var cursor := int(surface_state.get("pull_tab_stack_cursor", 0))
	var pending_payout := int(surface_state.get("pull_tab_pending_payout", 0))
	var active_rect := Rect2(rect.position + Vector2(42, 46), Vector2(310, 172))
	var pile_rect := Rect2(rect.position + Vector2(20, 236), Vector2(rect.size.x - 40, 138))
	var drawn_winner_pile := winner_pile.duplicate(false)
	var drawn_loser_pile := loser_pile.duplicate(false)
	if bool(surface.surface_animation_active(PULL_TAB_FILE_CHANNEL)):
		var filing_ticket := _pt_copy_dict(surface_state.get("pull_tab_file_animation_ticket", {}))
		var filing_ticket_id := str(filing_ticket.get("id", ""))
		drawn_winner_pile = _tickets_without_id(drawn_winner_pile, filing_ticket_id)
		drawn_loser_pile = _tickets_without_id(drawn_loser_pile, filing_ticket_id)
	surface.surface_label("TICKET PILE", rect.position + Vector2(14, 22), 18, C_CYAN)
	surface.surface_label("%d/%d" % [mini(cursor + 1, maxi(1, count)), count], rect.position + Vector2(118, 22), 14, C_SOFT)
	if pending_payout > 0:
		surface.surface_label("CASH $%d" % pending_payout, rect.position + Vector2(312, 23), 11, C_YELLOW)
	_draw_pull_tab_nav_button(surface, Rect2(rect.position + Vector2(170, 8), Vector2(32, 24)), "<", "pull_tab_prev", count > 1 and cursor > 0)
	_draw_pull_tab_nav_button(surface, Rect2(rect.position + Vector2(208, 8), Vector2(32, 24)), ">", "pull_tab_next", count > 1 and cursor < count - 1)
	_draw_pull_tab_nav_button(surface, Rect2(rect.position + Vector2(246, 8), Vector2(54, 24)), "OPEN", "pull_tab_next_unopened", count > 0)
	var display_stack := stack.duplicate(false)
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)) and not display_stack.is_empty():
		var arriving: Dictionary = display_stack[0]
		if str(arriving.get("id", "")) == str(surface.surface_animation_active_id(PULL_TAB_DISPENSE_CHANNEL)):
			display_stack.remove_at(0)
	if display_stack.is_empty():
		_draw_pull_tab_empty_pile(surface, Rect2(rect.position + Vector2(38, 56), Vector2(316, 148)), int(surface_state.get("pull_tab_tray_count", 0)))
		_draw_pull_tab_sorted_piles(surface, pile_rect, drawn_winner_pile, drawn_loser_pile)
		_draw_pull_tab_file_animation(surface, surface_state, active_rect, pile_rect)
		return
	for view_index in range(mini(display_stack.size() - 1, 5), 0, -1):
		var ticket: Dictionary = display_stack[view_index]
		_draw_pull_tab_mini_ticket(surface, ticket, Rect2(rect.position + Vector2(68 + view_index * 10, 56 + view_index * 5), Vector2(238, 138)), 0.18 + float(view_index) * 0.02)
	var active: Dictionary = display_stack[0]
	_draw_pull_tab_ticket(surface, active, active_rect, true)
	_draw_pull_tab_sorted_piles(surface, pile_rect, drawn_winner_pile, drawn_loser_pile)
	_draw_pull_tab_file_animation(surface, surface_state, active_rect, pile_rect)


func _draw_pull_tab_nav_button(surface, rect: Rect2, label: String, action: String, enabled: bool) -> void:
	surface.draw_rect(rect, Color("#13222a") if enabled else Color("#101317"))
	surface.draw_rect(rect, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.48 if enabled else 0.14), false, 2)
	surface.surface_label(label, rect.position + Vector2(8, 17), 10, C_WHITE if enabled else C_SOFT)
	if enabled:
		surface.surface_add_invisible_hit(rect, action)


func _draw_pull_tab_empty_pile(surface, rect: Rect2, tray_count: int = 0) -> void:
	surface.draw_rect(rect, Color("#0a0c12"))
	surface.draw_rect(rect, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.18), false, 2)
	for index in range(4):
		var ghost := Rect2(rect.position + Vector2(34 + index * 30, 64 - index * 5), Vector2(126, 58))
		surface.draw_rect(ghost, Color(1.0, 0.94, 0.80, 0.08))
		surface.draw_rect(ghost, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.16), false, 1)
	if tray_count > 0:
		surface.surface_label("COLLECT TRAY", rect.position + Vector2(84, 84), 18, C_YELLOW)
	else:
		surface.surface_label("BUY A ROW", rect.position + Vector2(104, 84), 18, C_SOFT)


func _draw_pull_tab_mini_ticket(surface, ticket: Dictionary, rect: Rect2, alpha: float) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	surface.draw_rect(rect, Color(paper.r, paper.g, paper.b, alpha))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha + 0.12), false, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(8, 10), Vector2(rect.size.x - 16, 20)), Color(accent.r, accent.g, accent.b, alpha))
	for row_index in range(3):
		surface.draw_rect(Rect2(rect.position + Vector2(18, 46 + row_index * 25), Vector2(rect.size.x - 36, 17)), Color(1.0, 1.0, 1.0, alpha))


func _draw_pull_tab_dispense_animation(surface, surface_state: Dictionary, cabinet: Rect2) -> void:
	var elapsed_msec := int(surface.surface_elapsed(PULL_TAB_DISPENSE_CHANNEL) * 1000.0)
	var tray_stack := _dictionary_view_array(surface_state.get("pull_tab_tray_stack", []))
	var events := _dispense_event_array(surface_state.get("pull_tab_dispense_events", []))
	for event_value in events:
		var event: Dictionary = event_value
		var local_msec := elapsed_msec - int(event.get("start_msec", 0))
		if local_msec < 0 or local_msec > PULL_TAB_DISPENSE_EVENT_DURATION_MSEC:
			continue
		var ticket := _ticket_dict(event.get("ticket", {}))
		if ticket.is_empty():
			ticket = _pull_tab_find_ticket(tray_stack, str(event.get("ticket_id", "")))
		if ticket.is_empty():
			continue
		var deal_index := clampi(int(event.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		var start := _pull_tab_column_drop_start(cabinet, deal_index)
		var chute := _pull_tab_column_drop_chute(cabinet, deal_index)
		var tray := _pull_tab_column_tray_target(cabinet, deal_index)
		var drop_start := int(event.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC))
		var drop_duration := maxi(1, int(event.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC)))
		var pos := start
		var alpha := 0.0
		var scale := 0.42
		if local_msec < drop_start:
			var latch_t := clampf(float(local_msec) / float(drop_start), 0.0, 1.0)
			pos = start.lerp(chute, _ease_in_out_cubic(latch_t))
			alpha = 0.22 + latch_t * 0.42
		else:
			var drop_t := clampf(float(local_msec - drop_start) / float(drop_duration), 0.0, 1.0)
			pos = chute.lerp(tray, _ease_out_cubic(drop_t))
			alpha = 0.94
			scale = lerpf(0.46, 0.60, drop_t)
		var ticket_rect := Rect2(pos, Vector2(94, 34) * scale)
		_draw_pull_tab_tray_ticket(surface, ticket, ticket_rect, deal_index)
		var pulse := maxf(0.0, 1.0 - float(local_msec) / float(PULL_TAB_DISPENSE_EVENT_DURATION_MSEC))
		surface.draw_rect(ticket_rect.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, alpha * 0.18 * pulse), false, 3)


func _pull_tab_column_drop_start(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(50 + deal_index * 52, 222)


func _pull_tab_column_drop_chute(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(44 + deal_index * 52, 286)


func _pull_tab_column_tray_target(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(36 + deal_index * 56, 326)


func _dispense_column_active(surface_state: Dictionary, deal_index: int) -> bool:
	var events := _dispense_event_array(surface_state.get("pull_tab_dispense_events", []))
	if events.is_empty():
		return false
	for event in events:
		if int((event as Dictionary).get("deal_index", -1)) == deal_index:
			return true
	return false


func _active_dispense_hidden_ticket_ids(surface, surface_state: Dictionary) -> Dictionary:
	var hidden := {}
	if not bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)):
		return hidden
	var elapsed_msec := int(surface.surface_elapsed(PULL_TAB_DISPENSE_CHANNEL) * 1000.0)
	for event_value in _dispense_event_array(surface_state.get("pull_tab_dispense_events", [])):
		var event: Dictionary = event_value
		var local_msec := elapsed_msec - int(event.get("start_msec", 0))
		var reveal_msec := int(event.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC)) + int(event.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC))
		if local_msec < reveal_msec:
			hidden[str(event.get("ticket_id", ""))] = true
	return hidden


func _draw_pull_tab_ticket(surface, ticket: Dictionary, rect: Rect2, interactive: bool = true) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var ink := Color(str(palette.get("ink", "#241027")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var trim := Color(str(palette.get("trim", "#ffd35a")))
	surface.draw_rect(rect, Color("#000000"))
	surface.draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size), Color(0.0, 0.0, 0.0, 0.18))
	surface.draw_rect(rect, paper)
	surface.draw_rect(rect, accent, false, 3)
	var header := Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 30))
	surface.draw_rect(header, trim)
	surface.draw_rect(header, accent, false, 2)
	surface.surface_label(str(ticket.get("display_name", "Pull Tab")).left(17).to_upper(), header.position + Vector2(8, 22), 15, ink)
	surface.surface_label(str(ticket.get("ticket_number", "")).left(7), header.position + Vector2(header.size.x - 58, 22), 10, ink)
	surface.surface_label("FORM %s  SERIAL %s  $%d" % [str(ticket.get("form", "")), str(ticket.get("serial", "")), int(ticket.get("price", 1))], rect.position + Vector2(12, 52), 9, ink)
	var prize_strip_width := 84.0
	_draw_pull_tab_ticket_prize_strip(surface, ticket, Rect2(rect.position + Vector2(rect.size.x - prize_strip_width - 12.0, 61), Vector2(prize_strip_width, 92)))
	var rows := _array_view(ticket.get("rows", []))
	var revealed_count := clampi(int(ticket.get("revealed_count", 0)), 0, rows.size())
	var reveal_animation_id := str(ticket.get("reveal_animation_id", ""))
	var reveal_animating: bool = interactive and not reveal_animation_id.is_empty() and surface.surface_animation_active_id(PULL_TAB_REVEAL_CHANNEL) == reveal_animation_id and surface.surface_animation_active(PULL_TAB_REVEAL_CHANNEL)
	var reveal_elapsed_msec: int = int(surface.surface_elapsed(PULL_TAB_REVEAL_CHANNEL) * 1000.0) if reveal_animating else PULL_TAB_REVEAL_TOTAL_MSEC
	var reveal_rows_complete: bool = not reveal_animating or reveal_elapsed_msec >= (2 * PULL_TAB_REVEAL_STAGGER_MSEC + PULL_TAB_REVEAL_ROW_DURATION_MSEC)
	var row_area_width: float = rect.size.x - prize_strip_width - 34.0
	for row_index in range(3):
		var row_rect := Rect2(rect.position + Vector2(12, 66 + row_index * 31), Vector2(row_area_width, 27))
		var row_progress: float = 1.0
		var row_revealed: bool = row_index < revealed_count
		if reveal_animating:
			var row_start := row_index * PULL_TAB_REVEAL_STAGGER_MSEC
			row_progress = clampf(float(reveal_elapsed_msec - row_start) / float(PULL_TAB_REVEAL_ROW_DURATION_MSEC), 0.0, 1.0)
			row_revealed = row_progress > 0.0
		_draw_pull_tab_row(surface, ticket, row_index, row_rect, row_revealed, row_index == revealed_count, interactive and not bool(ticket.get("fully_revealed", false)), row_progress)
	if bool(ticket.get("fully_revealed", false)) and reveal_rows_complete:
		var payout := int(ticket.get("payout", 0))
		var price := maxi(1, int(ticket.get("price", 1)))
		var banner := Rect2(rect.position + Vector2(12, rect.size.y - 26), Vector2(rect.size.x - 24, 19))
		var banner_color := C_YELLOW if payout > 0 else C_SOFT
		surface.draw_rect(banner, Color(banner_color.r, banner_color.g, banner_color.b, 0.18))
		surface.draw_rect(banner, Color(banner_color.r, banner_color.g, banner_color.b, 0.72), false, 1)
		var text := "PRIZE $%d  COST $%d" % [payout, price] if payout > 0 else "NO PRIZE  COST $%d" % price
		surface.surface_label(text.left(29), banner.position + Vector2(9, 14), 12, banner_color)
		if interactive:
			var hovered := bool(surface.surface_region_hovered(PULL_TAB_FILE_TICKET_ACTION))
			surface.draw_rect(rect.grow(3), Color(banner_color.r, banner_color.g, banner_color.b, 0.16 if hovered else 0.08), false, 3 if hovered else 2)
			surface.surface_draw_ready_badge(rect, "FILE")
			surface.surface_add_invisible_hit(rect, PULL_TAB_FILE_TICKET_ACTION)
	elif interactive and not bool(ticket.get("fully_revealed", false)):
		var hovered_peel := bool(surface.surface_region_hovered("pull_tab_reveal_next"))
		surface.draw_rect(rect.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.16 if hovered_peel else 0.08), false, 3 if hovered_peel else 2)
		surface.surface_draw_ready_badge(rect, "PEEL")
		surface.surface_add_exact_invisible_hit(rect, "pull_tab_reveal_next")


func _draw_pull_tab_ticket_prize_strip(surface, ticket: Dictionary, rect: Rect2) -> void:
	if bool(ticket.get("tarot_converted", false)):
		_draw_pull_tab_tarot_reading_strip(surface, ticket, rect)
		return
	surface.draw_rect(rect, Color("#f7fbff"))
	surface.draw_rect(rect, C_DARK, false, 1)
	surface.surface_label("LEGEND", rect.position + Vector2(6, 9), 7, C_DARK)
	var prize_rows := _dictionary_view_array(ticket.get("prize_rows", []))
	if prize_rows.is_empty():
		surface.surface_label("NO KEY", rect.position + Vector2(9, 47), 8, C_DARK)
		return
	for index in range(mini(6, prize_rows.size())):
		var row: Dictionary = prize_rows[index]
		var row_rect := Rect2(rect.position + Vector2(4, 15 + index * 12), Vector2(rect.size.x - 8, 11))
		_draw_pull_tab_prize_key_row(surface, row, row_rect, false, index + 1)


func _draw_pull_tab_tarot_reading_strip(surface, ticket: Dictionary, rect: Rect2) -> void:
	surface.draw_rect(rect, Color("#130719"))
	surface.draw_rect(rect, C_YELLOW, false, 1)
	surface.surface_label("NEXT 5", rect.position + Vector2(7, 9), 7, C_YELLOW)
	var reading := _dictionary_view_array(ticket.get("tarot_reading", []))
	if reading.is_empty():
		surface.surface_label("NO READING", rect.position + Vector2(5, 47), 7, C_WHITE)
		return
	for index in range(mini(5, reading.size())):
		var row: Dictionary = reading[index]
		var row_rect := Rect2(rect.position + Vector2(4, 15 + index * 14), Vector2(rect.size.x - 8, 12))
		_draw_pull_tab_prize_key_row(surface, row, row_rect, true, index + 1)
	var burned := int(ticket.get("burned_payout", 0))
	if burned > 0:
		surface.surface_label("BURN $%d" % burned, rect.position + Vector2(6, rect.size.y - 6), 6, C_PINK)


func _draw_pull_tab_prize_key_row(surface, row: Dictionary, rect: Rect2, tarot: bool, row_number: int) -> void:
	var payout := maxi(0, int(row.get("payout", 0)))
	var is_win := payout > 0
	var fill := Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18) if is_win else Color(1.0, 1.0, 1.0, 0.08)
	if not tarot:
		fill = Color("#fff7e4") if is_win else Color("#eef2f7")
	surface.draw_rect(rect, fill)
	surface.draw_rect(rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.52) if is_win else Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.26), false, 1)
	var text_color := C_YELLOW if is_win else (C_WHITE if tarot else C_DARK)
	if tarot:
		surface.surface_label("%d" % row_number, rect.position + Vector2(1, rect.size.y - 3), 6, text_color)
	var symbols := _string_array(row.get("symbols", []))
	var symbol_x := rect.position.x + (8.0 if tarot else 2.0)
	for symbol_index in range(3):
		var symbol := str(symbols[symbol_index] if symbol_index < symbols.size() else "MISS")
		var badge := Rect2(Vector2(symbol_x + float(symbol_index) * 9.5, rect.position.y + 2.0), Vector2(8.5, rect.size.y - 4.0))
		_draw_pull_tab_symbol_badge(surface, symbol, badge, is_win, tarot)
	surface.surface_label("$%d" % payout, rect.position + Vector2(rect.size.x - 25.0, rect.size.y - 3.0), 7, text_color)


func _draw_pull_tab_symbol_badge(surface, symbol: String, rect: Rect2, highlighted: bool, tarot: bool) -> void:
	var color := _pull_tab_symbol_badge_color(symbol)
	var alpha := 0.98 if highlighted else (0.82 if tarot else 0.72)
	surface.draw_rect(rect, Color(color.r, color.g, color.b, alpha))
	surface.draw_rect(rect, Color("#211722"), false, 1)
	var label_color := C_DARK if symbol in ["LEMON", "BELL", "CROWN", "7"] else C_WHITE
	surface.surface_label_centered(_pull_tab_symbol_abbrev(symbol), rect.grow(-0.5), 5, label_color)


func _pull_tab_symbol_abbrev(symbol: String) -> String:
	match symbol:
		"CHERRY":
			return "CH"
		"LEMON":
			return "LE"
		"BELL":
			return "BE"
		"BAR":
			return "BA"
		"7":
			return "7"
		"CROWN":
			return "CR"
		"MISS":
			return "--"
		_:
			return symbol.left(2).to_upper()


func _pull_tab_symbol_badge_color(symbol: String) -> Color:
	match symbol:
		"CHERRY":
			return C_PINK
		"LEMON":
			return C_YELLOW
		"BELL":
			return Color("#f6b14f")
		"BAR":
			return C_DARK
		"7":
			return Color("#f8e86a")
		"CROWN":
			return C_YELLOW
		_:
			return Color("#6f7787")


func _draw_pull_tab_row(surface, ticket: Dictionary, row_index: int, row_rect: Rect2, revealed: bool, next_to_open: bool, interactive: bool = true, reveal_progress: float = 1.0) -> void:
	surface.draw_rect(row_rect, Color("#f8f1de"))
	surface.draw_rect(row_rect, C_DARK, false, 1)
	var rows := _array_view(ticket.get("rows", []))
	var symbols := _string_array(rows[row_index] if row_index < rows.size() else [])
	var flap := Rect2(row_rect.position + Vector2(0, 1), Vector2(45, row_rect.size.y - 2))
	var window_start := row_rect.position + Vector2(52, 4)
	var progress := clampf(reveal_progress, 0.0, 1.0)
	if revealed:
		var fold := lerpf(39.0, 11.0, progress)
		var lift := sin(progress * PI) * 5.0
		surface.draw_polygon([
			flap.position + Vector2(1, 1),
			flap.position + Vector2(fold, -5 - lift),
			flap.position + Vector2(fold + 4, flap.size.y + 2 + lift * 0.35),
			flap.position + Vector2(5, flap.size.y - 2),
		], [Color("#e7d4bc")])
		surface.draw_line(flap.position + Vector2(fold + 5, 2), flap.position + Vector2(fold + 5, flap.size.y - 2), Color("#8a7465"), 1)
		if progress < 1.0:
			surface.draw_rect(row_rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 * (1.0 - progress)), false, 2)
	else:
		surface.draw_rect(flap, Color("#e6d0b4"))
		surface.draw_rect(flap, Color("#8a7465"), false, 1)
		for notch in range(3):
			surface.draw_line(flap.position + Vector2(5 + notch * 12, 4), flap.position + Vector2(5 + notch * 12, flap.size.y - 4), Color("#b7a48f"), 1)
		surface.surface_label("PULL", flap.position + Vector2(7, 18), 8, C_DARK)
	for symbol_index in range(3):
		var window_rect := Rect2(window_start + Vector2(symbol_index * 45, 0), Vector2(37, row_rect.size.y - 8))
		if revealed:
			surface.draw_rect(window_rect, C_DARK)
			_draw_pull_tab_symbol(surface, str(symbols[symbol_index] if symbol_index < symbols.size() else "?"), window_rect)
		else:
			surface.draw_rect(window_rect, Color("#fffaf0"))
			surface.draw_rect(window_rect, Color("#c8b495"), false, 1)
			surface.draw_line(window_rect.position + Vector2(4, 4), window_rect.end - Vector2(4, 4), Color("#d8c4a8"), 1)
			surface.draw_line(window_rect.position + Vector2(4, window_rect.size.y - 4), window_rect.position + Vector2(window_rect.size.x - 4, 4), Color("#d8c4a8"), 1)
	if next_to_open and interactive:
		surface.draw_rect(row_rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22), false, 2)
		surface.surface_add_exact_invisible_hit(row_rect, "pull_tab_reveal_next", row_index)


func _draw_pull_tab_sorted_piles(surface, rect: Rect2, winner_pile: Array, loser_pile: Array) -> void:
	var gap := 8.0
	var pile_width := (rect.size.x - gap) * 0.5
	_draw_pull_tab_ordered_winner_pile(surface, Rect2(rect.position, Vector2(pile_width, rect.size.y)), winner_pile)
	_draw_pull_tab_messy_loser_pile(surface, Rect2(rect.position + Vector2(pile_width + gap, 0), Vector2(pile_width, rect.size.y)), loser_pile)


func _draw_pull_tab_ordered_winner_pile(surface, rect: Rect2, ripped_tabs: Array) -> void:
	var accent := C_TEAL
	surface.draw_rect(rect, Color("#05080b"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.22), false, 1)
	surface.surface_label("WINNERS", rect.position + Vector2(7, 13), 9, accent)
	surface.surface_label(str(ripped_tabs.size()), rect.position + Vector2(rect.size.x - 18, 13), 9, accent)
	if ripped_tabs.is_empty():
		_draw_pull_tab_empty_stack_ghost(surface, rect, accent)
		return
	var visible := _visible_pile_tail(ripped_tabs, 7)
	var buried_count := maxi(0, _pile_depth_index(visible[0], 0))
	var buried_lift := minf(10.0, float(buried_count) * 1.2)
	var ticket_size := Vector2(rect.size.x - 34, 28)
	var bottom_y := rect.position.y + rect.size.y - ticket_size.y - 8.0
	if buried_count > 0:
		for shadow_index in range(mini(buried_count, 5)):
			var shadow_rect := Rect2(rect.position + Vector2(16 + shadow_index, rect.size.y - 36 - shadow_index * 2), ticket_size)
			surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.06))
			surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.12), false, 1)
	for index in range(visible.size()):
		var ticket: Dictionary = visible[index]
		var offset := Vector2(16 + mini(index, 4) * 2, bottom_y - rect.position.y - buried_lift - float(index) * 8.0)
		var ticket_rect := Rect2(rect.position + offset, ticket_size)
		_draw_pull_tab_pile_ticket(surface, ticket, ticket_rect, index, true)


func _draw_pull_tab_messy_loser_pile(surface, rect: Rect2, ripped_tabs: Array) -> void:
	var accent := C_AMBER
	surface.draw_rect(rect, Color("#080607"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.24), false, 1)
	surface.surface_label("LOSERS", rect.position + Vector2(7, 13), 9, accent)
	surface.surface_label(str(ripped_tabs.size()), rect.position + Vector2(rect.size.x - 18, 13), 9, accent)
	if ripped_tabs.is_empty():
		_draw_pull_tab_empty_stack_ghost(surface, rect, accent)
		return
	var visible := _visible_pile_tail(ripped_tabs, 10)
	var buried_count := maxi(0, _pile_depth_index(visible[0], 0))
	var buried_lift := minf(12.0, float(buried_count) * 1.1)
	var bottom_y := rect.position.y + rect.size.y - 31.0
	if buried_count > 0:
		for shadow_index in range(mini(buried_count, 6)):
			var shadow_rect := Rect2(rect.position + Vector2(18 + shadow_index * 2, rect.size.y - 35 - shadow_index * 2), Vector2(rect.size.x - 38, 24))
			surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.05))
			surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.10), false, 1)
	for index in range(visible.size()):
		var ticket: Dictionary = visible[index]
		var age_index := _pile_depth_index(ticket, index)
		var jitter := Vector2(float((age_index * 17) % 13) - 6.0, float((age_index * 11) % 9) - 4.0)
		var pos := Vector2(rect.position.x + 22.0 + float((age_index % 3) * 4), bottom_y - buried_lift - float(index) * 7.0) + jitter
		var size := Vector2(rect.size.x - 46.0 + float((age_index * 7) % 8), 23 + float((age_index * 5) % 5))
		_draw_pull_tab_pile_ticket(surface, ticket, Rect2(pos, size), index, false)


func _visible_pile_tail(tickets: Array, limit: int) -> Array:
	if tickets.size() <= limit:
		return tickets.duplicate(false)
	return tickets.slice(tickets.size() - limit, tickets.size())


func _pile_depth_index(ticket_value: Variant, fallback: int) -> int:
	if typeof(ticket_value) != TYPE_DICTIONARY:
		return fallback
	return maxi(0, int((ticket_value as Dictionary).get("pile_depth_index", fallback)))


func _draw_pull_tab_empty_stack_ghost(surface, rect: Rect2, accent: Color) -> void:
	for index in range(4):
		var ghost := Rect2(rect.position + Vector2(18 + index * 3, 40 + index * 10), Vector2(rect.size.x - 40, 24))
		surface.draw_rect(ghost, Color(1.0, 0.94, 0.80, 0.06))
		surface.draw_rect(ghost, Color(accent.r, accent.g, accent.b, 0.14), false, 1)


func _draw_pull_tab_pile_ticket(surface, ticket: Dictionary, rect: Rect2, index: int, ordered: bool) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var ink := Color(str(palette.get("ink", "#241027")))
	if ordered:
		surface.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.0, 0.0, 0.0, 0.22))
		surface.draw_rect(rect, paper)
		surface.draw_rect(rect, accent, false, 1)
	else:
		surface.draw_polygon([
			rect.position + Vector2(0, 2 + index % 3),
			rect.position + Vector2(rect.size.x * 0.28, 0),
			rect.position + Vector2(rect.size.x * 0.72, 2 + index % 4),
			rect.position + Vector2(rect.size.x, 1 + index % 2),
			rect.position + Vector2(rect.size.x - 3, rect.size.y),
			rect.position + Vector2(4, rect.size.y - 1),
		], [paper])
		surface.draw_line(rect.position + Vector2(2, 3), rect.position + Vector2(rect.size.x - 4, rect.size.y - 2), Color(0.0, 0.0, 0.0, 0.10), 1)
	surface.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 5)), accent)
	surface.surface_label(str(ticket.get("ticket_number", "")).left(6), rect.position + Vector2(6, rect.size.y - 5), 7, ink)
	if int(ticket.get("payout", 0)) > 0:
		surface.surface_label("$%d" % int(ticket.get("payout", 0)), rect.position + Vector2(rect.size.x - 26, rect.size.y - 5), 7, C_DARK)


func _draw_pull_tab_file_animation(surface, surface_state: Dictionary, source_rect: Rect2, piles_rect: Rect2) -> void:
	if not bool(surface.surface_animation_active(PULL_TAB_FILE_CHANNEL)):
		return
	var ticket := _pt_copy_dict(surface_state.get("pull_tab_file_animation_ticket", {}))
	if ticket.is_empty():
		return
	var pile_name := str(surface_state.get("pull_tab_file_animation_pile", "loser_pile"))
	var progress := _ease_in_out_cubic(surface.surface_animation_progress(PULL_TAB_FILE_CHANNEL))
	var gap := 8.0
	var pile_width := (piles_rect.size.x - gap) * 0.5
	var target_rect := Rect2(piles_rect.position + Vector2(22, 70), Vector2(102, 34))
	if pile_name == "loser_pile":
		target_rect = Rect2(piles_rect.position + Vector2(pile_width + gap + 28, 82), Vector2(86, 30))
	var pos := source_rect.position.lerp(target_rect.position, progress)
	var size := source_rect.size.lerp(target_rect.size, progress)
	var flying := Rect2(pos, size)
	var alpha := 1.0 - maxf(0.0, progress - 0.82) / 0.18
	surface.draw_rect(flying.grow(5), Color(0.0, 0.0, 0.0, 0.22 * alpha))
	_draw_pull_tab_mini_ticket(surface, ticket, flying, 0.92 * alpha)
	surface.draw_rect(flying.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.24 * (1.0 - progress)), false, 3)


func _draw_pull_tab_symbol(surface, symbol: String, rect: Rect2) -> void:
	var center := rect.position + rect.size * 0.5
	match symbol:
		"CHERRY":
			surface.draw_line(center + Vector2(0, -7), center + Vector2(-4, -2), C_TEAL, 1)
			surface.draw_circle(center + Vector2(-4, 2), maxf(2.0, rect.size.x * 0.18), C_PINK)
			surface.draw_circle(center + Vector2(4, 3), maxf(2.0, rect.size.x * 0.18), C_PINK_2)
		"LEMON":
			surface.draw_circle(center, maxf(3.0, rect.size.x * 0.28), C_YELLOW)
			surface.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), C_AMBER, 2)
		"BELL":
			surface.draw_polygon([
				center + Vector2(-8, 7),
				center + Vector2(8, 7),
				center + Vector2(5, -4),
				center + Vector2(-5, -4),
			], [C_YELLOW])
			surface.draw_circle(center + Vector2(0, 8), 2, Color("#ff9f43"))
		"BAR":
			var bar_rect := Rect2(center + Vector2(-13, -6), Vector2(26, 12))
			surface.draw_rect(bar_rect, C_DARK)
			surface.surface_label_centered("BAR", bar_rect.grow(-1.0), int(clampf(rect.size.y * 0.46, 6.0, 8.0)), C_WHITE)
		"7":
			surface.surface_label("7", center + Vector2(-5, rect.size.y * 0.32), int(clampf(rect.size.y * 0.80, 7.0, 16.0)), C_YELLOW)
		"CROWN":
			var crown := [
				center + Vector2(-9, 7),
				center + Vector2(-7, -5),
				center + Vector2(-3, 1),
				center + Vector2(0, -8),
				center + Vector2(3, 1),
				center + Vector2(7, -5),
				center + Vector2(9, 7),
			]
			surface.draw_polygon(crown, [C_YELLOW])
			surface.draw_line(center + Vector2(-8, 7), center + Vector2(8, 7), C_AMBER, 2)
		_:
			surface.surface_label(symbol.left(3), rect.position + Vector2(5, rect.size.y * 0.68), 8, C_WHITE)


func _pull_tab_find_ticket(stack: Array, ticket_id: String) -> Dictionary:
	for value in stack:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = value
		if str(ticket.get("id", "")) == ticket_id:
			return ticket
	return {}


func _tickets_without_id(tickets: Array, ticket_id: String) -> Array:
	if ticket_id.is_empty():
		return tickets.duplicate(false)
	var result: Array = []
	for value in tickets:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = value
		if str(ticket.get("id", "")) == ticket_id:
			continue
		result.append(ticket)
	return result


func _ease_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _ease_in_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	if clamped < 0.5:
		return 4.0 * clamped * clamped * clamped
	return 1.0 - pow(-2.0 * clamped + 2.0, 3.0) / 2.0


func _seeded_rng(stream_key: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(RunState.text_to_seed(stream_key), RunState.text_to_seed(stream_key))
	return rng


func _pt_copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _pt_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _dictionary_view_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry as Dictionary)
	return result


func _array_view(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


func _array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
