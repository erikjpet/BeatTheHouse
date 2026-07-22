class_name ScratchTicketsGame
extends GameModule

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const SURFACE_DESIGN_SIZE := Vector2(VisualStyleScript.GAME_BOARD_SIZE)
const C_DARK := VisualStyleScript.DARK
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const C_CYAN := VisualStyleScript.CYAN
const C_YELLOW := VisualStyleScript.YELLOW
const C_PINK := VisualStyleScript.PINK
const BUY_ACTION := "buy_scratch_ticket"
const SCRUB_ACTION := "scratch_scrub"
const SCRATCH_ALL_ACTION := "scratch_all"
const SETTLE_ACTION := "settle_scratch_ticket"
const REVEAL_ACTION := "scratch_reveal"
const DISPENSE_CHANNEL := "scratch_ticket_dispense"
const FILE_CHANNEL := "scratch_ticket_file"
const SWEEP_CHANNEL := "scratch_section_sweep"
const DISPENSE_DURATION_MSEC := 760
const FILE_DURATION_MSEC := 620
const SWEEP_DURATION_MSEC := 280
const SCRATCH_AUDIO_LOOP := "scratch_paper_foley_loop"
const REDEEM_HOOK_ID := "scratch_ticket_clerk"
const REDEEM_ACTION_ID := "redeem_scratch_winners"
const MACHINE_RECT := Rect2(18, 13, 278, 404)
const PLAY_SURFACE_RECT := Rect2(306, 48, 586, 370)
const DEFAULT_TICKET_RECT := Rect2(422, 54, 354, 356)
const DEFAULT_SCRATCH_RECT := Rect2(444, 169, 310, 176)
const STATUS_HUD_RECT := Rect2(306, 8, 460, 34)
const BIG_WIN_THRESHOLD := 100
const STOCK_SLOT_COUNT := 4
const COLLECTION_TOTAL := 7
const DEFAULT_BRUSH_RADIUS := 15.0
const DEFAULT_PASS_REMOVAL := 0.66
const DEFAULT_SWEEP_THRESHOLD := 0.80
const DEFAULT_MASK_COLUMNS := 48
const DEFAULT_MASK_ROWS := 32

var active_ticket_rect := DEFAULT_TICKET_RECT
var active_scratch_rect := DEFAULT_SCRATCH_RECT


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var result := super.enter(run_state, environment)
	result["message"] = "The scratcher vending machine hums beside the clerk. Pick a slot, then drag across the latex."
	result["scratch_stock_count"] = _dictionary_array(machine.get("stock", [])).size()
	return result


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": [],
		"stake_floor": 1,
		"stake_ceiling": maxi(1, run_state.bankroll),
		"base_stake_ceiling": maxi(1, run_state.bankroll),
		"economy_state": run_state.economy(),
		"economy_pressure_applied": false,
	}


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return _generate_machine_state(run_state, environment, rng)


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var active_ticket := _copy_dict(machine.get("active_ticket", {}))
	var stock := _stock_view(machine)
	var crumbs := _dictionary_array(ui_state.get("scratch_crumbs", []))
	var discovered := _string_array(run_state.narrative_flags.get("scratch_ticket_types_discovered", [])) if run_state != null else []
	var last_dispense_id := str(machine.get("last_dispense_id", ""))
	var last_file_id := str(machine.get("last_file_id", ""))
	var reduce_motion := _reduce_motion_enabled(ui_state)
	var compact_mode := _small_screen_enabled(ui_state)
	var compact_tab := str(ui_state.get("scratch_compact_tab", "ticket" if not active_ticket.is_empty() else "machine"))
	if compact_tab not in ["machine", "ticket"]:
		compact_tab = "ticket" if not active_ticket.is_empty() else "machine"
	var sweep_duration := 0 if reduce_motion else SWEEP_DURATION_MSEC
	_configure_active_ticket_layout(active_ticket, compact_mode)
	return GameModule.surface_spec({
		"surface_renderer": "scratch_tickets",
		"surface_life": "scratch_vending_machine",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_embeds_outcomes": true,
		"surface_realtime_state_refresh": false,
		"surface_pointer_coalesce_moves": true,
		"machine_name": str(machine.get("machine_name", "Highway Scratch Center")),
		"scratch_stock": stock,
		"scratch_ticket": active_ticket,
		"scratch_pending_payout": _pending_payout(machine),
		"scratch_current_winnings": _pending_payout(machine),
		"scratch_active_price": int(active_ticket.get("price", 0)),
		"scratch_winner_count": _dictionary_array(machine.get("winner_pile", [])).size(),
		"scratch_loser_count": _dictionary_array(machine.get("loser_pile", [])).size(),
		"scratch_winner_pile": _dictionary_array(machine.get("winner_pile", [])).duplicate(true),
		"scratch_loser_pile": _dictionary_array(machine.get("loser_pile", [])).duplicate(true),
		"scratch_last_settled_ticket": _copy_dict(machine.get("last_settled_ticket", {})),
		"scratch_last_settled_pile": str(machine.get("last_settled_pile", "")),
		"scratch_machine_style": "physical_lottery_vending_cabinet",
		"scratch_machine_art_features": ["floor_unit", "jackpot_marquee", "glass_stock_rows", "branded_side_panel", "selection_buttons", "dispensing_tray"],
		"scratch_ticket_face_style": "portrait_printed_lottery_ticket",
		"scratch_dispense_animation": not last_dispense_id.is_empty(),
		"scratch_crumbs": crumbs,
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_reduce_motion": reduce_motion,
		"scratch_compact_mode": compact_mode,
		"scratch_compact_tab": compact_tab,
		"scratch_ui_mode": "compact_tabs" if compact_mode else "machine_surface_split",
		"scratch_core_surface_scroll": false,
		"scratch_all_available": not active_ticket.is_empty(),
		"scratch_size_id": str(active_ticket.get("size_id", "")),
		"scratch_size_orientation": _size_orientation(str(active_ticket.get("size_id", ""))),
		"scratch_ticket_rect": {"x": active_ticket_rect.position.x, "y": active_ticket_rect.position.y, "w": active_ticket_rect.size.x, "h": active_ticket_rect.size.y},
		"scratch_brush_radius": float(_copy_dict(active_ticket.get("scratch", {})).get("brush_radius", DEFAULT_BRUSH_RADIUS)),
		"scratch_drunk_level": run_state.drunk_level if run_state != null else 0,
		"scratch_collection_count": discovered.size(),
		"scratch_collection_total": COLLECTION_TOTAL,
		"scratch_xray_peeks": _dictionary_array(active_ticket.get("xray_peeks", [])),
		"scratch_fortune": str(active_ticket.get("fortune_tier", "")),
		"scratch_penalty_shields": int(machine.get("penalty_shields_remaining", 0)),
		"scratch_rules": "Drag anywhere on the latex. Rework each patch; sections sweep clean at 80%. Winners cash at the clerk.",
		"surface_animation_channels": [
			GameModule.surface_animation_channel(DISPENSE_CHANNEL, last_dispense_id, DISPENSE_DURATION_MSEC, int(machine.get("dispense_started_msec", 0)), {"metadata": {"ticket_id": str(active_ticket.get("id", "")), "slot": int(machine.get("last_dispense_slot", 0))}}),
			GameModule.surface_animation_channel(FILE_CHANNEL, last_file_id, FILE_DURATION_MSEC, int(machine.get("file_started_msec", 0)), {"metadata": {"pile": str(machine.get("last_settled_pile", ""))}}),
			GameModule.surface_animation_channel(SWEEP_CHANNEL, str(machine.get("last_sweep_id", "")), sweep_duration, int(machine.get("sweep_started_msec", 0)), {"metadata": {"section": str(machine.get("last_sweep_section", ""))}}),
		],
		"surface_ui_protected_regions": [
			{"x": MACHINE_RECT.position.x, "y": MACHINE_RECT.position.y, "w": MACHINE_RECT.size.x, "h": MACHINE_RECT.size.y},
			{"x": STATUS_HUD_RECT.position.x, "y": STATUS_HUD_RECT.position.y, "w": STATUS_HUD_RECT.size.x, "h": STATUS_HUD_RECT.size.y},
			{"x": active_ticket_rect.position.x, "y": active_ticket_rect.position.y, "w": active_ticket_rect.size.x, "h": active_ticket_rect.size.y},
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "scratch_ticket_machine",
			"action_cues": {BUY_ACTION: "ticket_dispenser", SCRATCH_ALL_ACTION: "ticket_peel"},
		}),
	})


func surface_pointer_uses_lightweight_ui_state(surface_action: String) -> bool:
	return surface_action == SCRUB_ACTION


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "scratch_tickets":
		return false
	surface.surface_begin_design_space(SURFACE_DESIGN_SIZE)
	if bool(state.get("scratch_compact_mode", false)):
		var compact_tab := str(state.get("scratch_compact_tab", "machine"))
		_draw_compact_tabs(surface, compact_tab)
		if compact_tab == "machine":
			_draw_machine(surface, state)
		else:
			_draw_ticket(surface, state)
			_draw_surface_hud(surface, state)
			_draw_dispense_animation(surface, state)
			_draw_file_animation(surface, state)
	else:
		_draw_machine(surface, state)
		_draw_ticket(surface, state)
		_draw_surface_hud(surface, state)
		_draw_dispense_animation(surface, state)
		_draw_file_animation(surface, state)
	return true


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	match surface_action:
		"scratch_compact_machine", "scratch_compact_ticket":
			var tab_state := ui_state.duplicate(false)
			tab_state["scratch_compact_tab"] = "machine" if surface_action.ends_with("machine") else "ticket"
			return GameModule.surface_command({"ui_state": tab_state, "message": "Ticket machine." if surface_action.ends_with("machine") else "Scratch surface."})
		"scratch_buy":
			var stock := _dictionary_array(machine.get("stock", []))
			if index < 0 or index >= stock.size():
				return GameModule.surface_command({"message": "That vending slot is empty."})
			if not _copy_dict(machine.get("active_ticket", {})).is_empty():
				return GameModule.surface_command({"message": "Finish the ticket on the play surface first."})
			var slot: Dictionary = stock[index]
			var price := maxi(1, int(slot.get("price", 1)))
			if int(slot.get("remaining", 0)) <= 0:
				return GameModule.surface_command({"message": "%s is sold out." % str(slot.get("display_name", "That ticket"))})
			if run_state.bankroll < price:
				return GameModule.surface_command({"message": "You need $%d for that ticket." % price})
			var next_state := ui_state.duplicate(true)
			next_state["scratch_stock_index"] = index
			next_state["scratch_compact_tab"] = "ticket"
			return GameModule.surface_command({
				"ui_state": next_state,
				"action_id": BUY_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"set_stake": price,
				"selected_index": index,
			})
		SCRATCH_ALL_ACTION:
			if _copy_dict(machine.get("active_ticket", {})).is_empty():
				return GameModule.surface_command({"message": "Buy a ticket first."})
			_reveal_all(machine)
			_write_machine_state(environment, machine, run_state)
			return GameModule.surface_command({
				"action_id": SETTLE_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"message": "The remaining latex crumbles away.",
			})
	return {"handled": false}


func surface_pointer_command(surface_action: String, _index: int, phase: String, board_position: Vector2, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if surface_action != SCRUB_ACTION:
		return {"handled": false}
	var next_state := ui_state.duplicate(false)
	var machine := _ensure_machine_state(run_state, environment, true)
	if phase == "begin":
		next_state["scratch_drag_active"] = true
		next_state["scratch_drag_moved"] = false
		next_state["scratch_last_pointer"] = board_position
		next_state["scratch_crumbs"] = []
		return _scratch_pointer_surface_command(machine, next_state)
	if phase == "end":
		next_state["scratch_drag_active"] = false
		next_state.erase("scratch_last_pointer")
		return _scratch_pointer_surface_command(machine, next_state, {"surface_audio_loop_stop": SCRATCH_AUDIO_LOOP})
	if phase != "move" or not bool(next_state.get("scratch_drag_active", false)):
		return _scratch_pointer_surface_command(machine, next_state)
	var previous: Vector2 = next_state.get("scratch_last_pointer", board_position)
	next_state["scratch_last_pointer"] = board_position
	if previous.distance_squared_to(board_position) < 2.25:
		return _scratch_pointer_surface_command(machine, next_state)
	next_state["scratch_drag_moved"] = true
	var scratch_result := _scratch_segment(machine, previous, board_position)
	if int(scratch_result.get("erased_samples", 0)) <= 0:
		return _scratch_pointer_surface_command(machine, next_state, {"surface_audio_loop_stop": SCRATCH_AUDIO_LOOP})
	var reduce_motion := _reduce_motion_enabled(next_state)
	next_state["scratch_crumbs"] = [] if reduce_motion else _crumbs_for_segment(previous, board_position, int(scratch_result.get("erased_samples", 0)))
	if not _dictionary_array(scratch_result.get("swept_sections", [])).is_empty():
		machine["sweep_started_msec"] = GameModule.deterministic_time_msec(run_state, next_state)
	_write_machine_state(environment, machine, run_state)
	var completed := bool(scratch_result.get("ticket_complete", false))
	var penalty := int(scratch_result.get("penalty", 0))
	var distance := previous.distance_to(board_position)
	var activity := clampf(distance / 24.0, 0.0, 1.0)
	var command := {
		"environment_changed": false,
		"message": str(scratch_result.get("message", "Latex flakes away.")),
		"surface_audio_loop_start": SCRATCH_AUDIO_LOOP,
		"surface_audio_loop_volume_db": lerpf(-19.0, -10.5, activity),
		"surface_audio_loop_pitch": lerpf(0.92, 1.06, activity),
	}
	if completed or penalty > 0:
		command.erase("surface_audio_loop_start")
		command["surface_audio_loop_stop"] = SCRATCH_AUDIO_LOOP
		command["action_id"] = SETTLE_ACTION if completed else REVEAL_ACTION
		command["action_kind"] = "legal"
		command["direct_resolve"] = true
		command["skip_stake_validation"] = true
	return _scratch_pointer_surface_command(machine, next_state, command)


func _scratch_pointer_surface_command(machine: Dictionary, ui_state: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var command := extra.duplicate(false)
	command["ui_state"] = ui_state
	command["surface_transient"] = true
	command["surface_state_patch"] = {
		"scratch_ticket": machine.get("active_ticket", {}),
		"scratch_crumbs": ui_state.get("scratch_crumbs", []),
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_penalty_shields": int(machine.get("penalty_shields_remaining", 0)),
		"scratch_reduce_motion": _reduce_motion_enabled(ui_state),
		"surface_animation_channels": _scratch_animation_channels(machine, _reduce_motion_enabled(ui_state)),
	}
	return GameModule.surface_command(command, true)


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id != BUY_ACTION:
		return 0
	var machine := _ensure_machine_state(run_state, environment, false)
	var stock := _dictionary_array(machine.get("stock", []))
	var index := int(ui_state.get("scratch_stock_index", 0))
	if index < 0 or index >= stock.size():
		return maxi(0, stake)
	return maxi(1, int((stock[index] as Dictionary).get("price", stake)))


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	match action_id:
		BUY_ACTION:
			return _resolve_purchase(stake, run_state, environment, rng, ui_state)
		REVEAL_ACTION:
			return _resolve_reveal(run_state, environment, rng, false)
		SETTLE_ACTION:
			return _resolve_reveal(run_state, environment, rng, true)
	return _scratch_empty_result(action_id, environment, "That scratch-ticket action is unavailable.")


func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _read_machine_state(run_state, environment)
	var payout := _pending_payout(machine)
	var winners := _dictionary_array(machine.get("winner_pile", [])).size()
	return [{
		"id": REDEEM_HOOK_ID,
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"label": "Scratch-Ticket Clerk",
		"short_description": "Checks and cashes scratched winners.",
		"enabled": true,
		"recovery": payout > 0,
		"action_summary": "Cash %d winner%s for $%d." % [winners, "" if winners == 1 else "s", payout] if winners > 0 else "No scratched winners to cash.",
		"effect_summary": "$%d waits at the counter." % payout if payout > 0 else "Scratch a winner, then bring it here.",
		"risk_summary": "Large prizes draw the clerk's attention.",
		"cost_summary": "",
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "service",
		"unique_object_class": "scratch_ticket_clerk",
		"unique_object_priority": 100,
		"available_actions": [{"id": REDEEM_ACTION_ID, "label": "Cash tickets"}],
		"confirm_action_id": REDEEM_ACTION_ID,
	}]


func environment_action_command(hook_id: String, action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	if hook_id != REDEEM_HOOK_ID or action_id != REDEEM_ACTION_ID:
		return {"handled": false}
	return {"handled": true, "result": _resolve_redemption(run_state, environment, rng)}


func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var active := _copy_dict(machine.get("active_ticket", {}))
	var payout := _pending_payout(machine)
	return {
		"active": not active.is_empty() or payout > 0,
		"bankroll_zero_failure_deferred": run_state != null and run_state.bankroll <= 0 and (not active.is_empty() or payout > 0),
		"pending_payout": payout,
		"unresolved_ticket_count": 0 if active.is_empty() else 1,
		"status_label": "CASH $%d" % payout if payout > 0 else "SCRATCHING" if not active.is_empty() else "",
		"status_summary": "$%d in scratched winners; %s." % [payout, "one ticket in progress" if not active.is_empty() else "surface clear"],
	}


func simulate_ticket_type(type_id: String, rng: RngStream, luck_modifier: int = 0) -> Dictionary:
	var ticket_type := _ticket_type(type_id)
	if ticket_type.is_empty() or rng == null:
		return {}
	var ticket := _roll_ticket(ticket_type, rng, luck_modifier, "simulation")
	return {
		"type_id": type_id,
		"price": int(ticket_type.get("price", 0)),
		"payout": int(ticket.get("payout", 0)),
		"penalty": 0,
		"net_return": int(ticket.get("payout", 0)),
		"outcome_id": str(ticket.get("outcome_id", "")),
		"mechanic_result": ticket.get("mechanic_result", {}),
		"outcome_fixed_at_purchase": true,
	}


func measure_rtp(type_id: String, samples: int = 20000, seed_text: String = "SCRATCH-RTP") -> Dictionary:
	var ticket_type := _ticket_type(type_id)
	var table := _dictionary_array(ticket_type.get("prize_table", []))
	var total_weight := 0
	for entry_value in table:
		total_weight += maxi(0, int((entry_value as Dictionary).get("weight", 0)))
	var price := maxi(1, int(ticket_type.get("price", 1)))
	var stream_seed := RunState.text_to_seed("%s:%s" % [seed_text, type_id])
	var stream_state := posmod(stream_seed, RngStream.MODULUS)
	if stream_state == 0:
		stream_state = 1
	var total_cost := 0
	var total_return := 0
	for _sample in range(maxi(1, samples)):
		stream_state = int((stream_state * RngStream.MULTIPLIER) % RngStream.MODULUS)
		var roll := 1 + int(stream_state % maxi(1, total_weight))
		var cursor := 0
		var payout := 0
		for entry_value in table:
			var entry: Dictionary = entry_value
			cursor += maxi(0, int(entry.get("weight", 0)))
			if roll <= cursor:
				payout = maxi(0, int(entry.get("payout", 0)))
				break
		total_cost += price
		total_return += payout
	return {
		"type_id": type_id,
		"samples": maxi(1, samples),
		"cost": total_cost,
		"return": total_return,
		"rtp": float(total_return) / float(maxi(1, total_cost)),
	}


func _resolve_purchase(_stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	if not _copy_dict(machine.get("active_ticket", {})).is_empty():
		return _scratch_empty_result(BUY_ACTION, environment, "Finish the active ticket first.")
	var stock := _dictionary_array(machine.get("stock", []))
	var stock_index := int(ui_state.get("scratch_stock_index", 0))
	if stock_index < 0 or stock_index >= stock.size():
		return _scratch_empty_result(BUY_ACTION, environment, "That vending slot is empty.")
	var slot: Dictionary = stock[stock_index]
	var price := maxi(1, int(slot.get("price", 1)))
	if int(slot.get("remaining", 0)) <= 0:
		return _scratch_empty_result(BUY_ACTION, environment, "%s is sold out." % str(slot.get("display_name", "That ticket")))
	if run_state.bankroll < price:
		return _scratch_empty_result(BUY_ACTION, environment, "Not enough cash for this ticket.")
	var ticket_type := _ticket_type(str(slot.get("type_id", "")))
	if ticket_type.is_empty():
		return _scratch_empty_result(BUY_ACTION, environment, "That ticket type is unavailable.")
	var purchase_number := int(machine.get("purchased_count", 0)) + 1
	var luck := run_state.effective_luck() if run_state != null else 0
	var ticket := _roll_ticket(ticket_type, rng, luck, "%s:%d" % [str(environment.get("id", "room")), purchase_number])
	_stamp_ticket_origin(ticket, environment)
	var xray_capacity := maxi(0, run_state.item_effect_total("scratch_peek_cells", get_family()) if run_state != null else 0)
	if xray_capacity > 0:
		ticket["xray_peeks"] = _xray_peeks(ticket, mini(xray_capacity, rng.randi_range(2, 3)), rng)
	var tarot_strength := maxi(0, run_state.item_effect_total("scratch_fortune_hint", get_family()) if run_state != null else 0)
	if tarot_strength > 0:
		ticket["fortune_tier"] = _fortune_tier(ticket)
	var shield_capacity := maxi(0, run_state.item_effect_total("scratch_penalty_shields", get_family()) if run_state != null else 0)
	_reserve_penalty_shields(ticket, shield_capacity)
	machine["penalty_shields_remaining"] = shield_capacity
	slot["remaining"] = maxi(0, int(slot.get("remaining", 0)) - 1)
	stock[stock_index] = slot
	machine["stock"] = stock
	machine["active_ticket"] = ticket
	machine["purchased_count"] = purchase_number
	machine["last_ticket_id"] = str(ticket.get("id", ""))
	machine["last_dispense_id"] = "scratch-dispense:%s" % str(ticket.get("id", purchase_number))
	machine["last_dispense_slot"] = stock_index
	machine["dispense_started_msec"] = GameModule.deterministic_time_msec(run_state, ui_state)
	_write_machine_state(environment, machine, run_state)
	var message := "%s slides onto the counter. Drag across the silver latex to reveal it." % str(ticket.get("display_name", "A scratch ticket"))
	if not _dictionary_array(ticket.get("xray_peeks", [])).is_empty():
		message += " X-Ray Glasses ghost %d symbols through the coating." % _dictionary_array(ticket.get("xray_peeks", [])).size()
	if not str(ticket.get("fortune_tier", "")).is_empty():
		message += " The tarot reads %s." % str(ticket.get("fortune_tier", "")).to_upper()
	var xray_heat := maxi(0, run_state.item_effect_total("scratch_peek_heat", get_family(), "cheat") if run_state != null and xray_capacity > 0 else 0)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -price
	deltas["suspicion_delta"] = xray_heat
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": BUY_ACTION,
		"ticket_id": str(ticket.get("id", "")),
		"ticket_type": str(ticket.get("type_id", "")),
		"cost": price,
		"bankroll_delta": -price,
		"luck_modifier": luck,
		"outcome_fixed_at_purchase": true,
		"xray_peek_count": _dictionary_array(ticket.get("xray_peeks", [])).size(),
		"xray_surveillance_heat": xray_heat,
		"environment_id": str(environment.get("id", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": BUY_ACTION,
		"action_kind": "legal",
		"stake": price,
		"bankroll_delta": -price,
		"suspicion_delta": xray_heat,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	# The result and machine state share the purchase-fixed ticket. Consumers
	# treat action results as immutable, so copying the full latex mask here only
	# adds a second allocation at the purchase boundary.
	result["scratch_ticket"] = ticket
	result["scratch_outcome_fixed_at_purchase"] = true
	result["scratch_luck_modifier"] = luck
	result["scratch_xray_peeks"] = _dictionary_array(ticket.get("xray_peeks", [])).duplicate(true)
	result["scratch_fortune"] = str(ticket.get("fortune_tier", ""))
	result["defer_bankroll_zero_failure"] = true
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_reveal(run_state: RunState, environment: Dictionary, rng: RngStream, settle: bool) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var ticket := _copy_dict(machine.get("active_ticket", {}))
	if ticket.is_empty():
		return _scratch_empty_result(SETTLE_ACTION if settle else REVEAL_ACTION, environment, "There is no ticket on the scratch surface.")
	var payout := int(ticket.get("payout", 0))
	var message := "The printed result shows through."
	if settle:
		if not _ticket_complete(ticket):
			return _scratch_empty_result(SETTLE_ACTION, environment, "Some latex still covers this ticket.")
		ticket["settled"] = true
		var pile_name := "winner_pile" if payout > 0 else "loser_pile"
		var pile := _dictionary_array(machine.get(pile_name, []))
		pile.append(ticket)
		machine[pile_name] = pile
		machine["active_ticket"] = {}
		machine["last_settled_ticket"] = ticket.duplicate(true)
		machine["last_settled_pile"] = pile_name
		machine["last_file_id"] = "scratch-file:%s" % str(ticket.get("id", pile.size()))
		machine["file_started_msec"] = 0
		message = "%s wins $%d. The clerk must cash it." % [str(ticket.get("display_name", "Ticket")), payout] if payout > 0 else "%s is a loser." % str(ticket.get("display_name", "Ticket"))
	_write_machine_state(environment, machine, run_state)
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "scratch_ticket_settle" if settle else "scratch_ticket_reveal",
		"game_id": get_id(),
		"action_id": SETTLE_ACTION if settle else REVEAL_ACTION,
		"ticket_id": str(ticket.get("id", "")),
		"ticket_type": str(ticket.get("type_id", "")),
		"pending_clerk_payout": payout if settle else 0,
		"bankroll_delta": 0,
		"suspicion_delta": 0,
		"environment_id": str(environment.get("id", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": SETTLE_ACTION if settle else REVEAL_ACTION,
		"action_kind": "legal",
		"stake": 0,
		"bankroll_delta": 0,
		"deltas": deltas,
		"won": settle and payout > 0,
		"payout": 0,
		"pending_payout": payout if settle else 0,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result["defer_bankroll_zero_failure"] = not _copy_dict(machine.get("active_ticket", {})).is_empty() or _pending_payout(machine) > 0
	if settle:
		result["scratch_discovered_type_id"] = str(ticket.get("type_id", ""))
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_redemption(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var winners := _dictionary_array(machine.get("winner_pile", []))
	if winners.is_empty():
		return _scratch_empty_result(REDEEM_ACTION_ID, environment, "The clerk has no winning scratchers to cash.")
	var payout := 0
	var big_wins := 0
	for ticket_value in winners:
		var ticket: Dictionary = ticket_value
		var ticket_payout := maxi(0, int(ticket.get("payout", 0)))
		payout += ticket_payout
		if ticket_payout >= BIG_WIN_THRESHOLD:
			big_wins += 1
	var heat := big_wins * 4
	machine["winner_pile"] = []
	machine["redeemed_count"] = int(machine.get("redeemed_count", 0)) + winners.size()
	_write_machine_state(environment, machine, run_state)
	var message := "The clerk scans %d ticket%s and counts out $%d." % [winners.size(), "" if winners.size() == 1 else "s", payout]
	if heat > 0:
		message += " The large payout draws attention +%d." % heat
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = payout
	deltas["suspicion_delta"] = heat
	deltas["messages"] = [message]
	deltas["story_log"] = [{"type": "scratch_ticket_redemption", "game_id": get_id(), "action_id": REDEEM_ACTION_ID, "ticket_count": winners.size(), "bankroll_delta": payout, "suspicion_delta": heat, "environment_id": str(environment.get("id", ""))}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": REDEEM_ACTION_ID,
		"action_kind": "legal",
		"stake": 0,
		"bankroll_delta": payout,
		"suspicion_delta": heat,
		"deltas": deltas,
		"won": payout > 0,
		"payout": payout,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	GameModule.apply_result(run_state, result, rng)
	return result


func _generate_machine_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var day_key := int(environment.get("generated_day", environment.get("day", 0)))
	var stream_key := "scratch-stock:%s:day:%d" % [str(environment.get("id", "room")), day_key]
	var root_rng := rng if rng != null else _seeded_rng("scratch-stock-root:%s" % str(environment.get("id", "room")))
	var machine_rng := root_rng.fork(stream_key)
	var stock: Array = []
	for ticket_type_value in _weighted_stock_types(machine_rng, STOCK_SLOT_COUNT):
		var ticket_type: Dictionary = ticket_type_value
		var count_range := _int_array(ticket_type.get("stock_count", [2, 4]))
		var minimum := int(count_range[0]) if not count_range.is_empty() else 2
		var maximum := int(count_range[1]) if count_range.size() > 1 else minimum
		stock.append({
			"type_id": str(ticket_type.get("id", "")),
			"display_name": str(ticket_type.get("display_name", "Ticket")),
			"price": maxi(1, int(ticket_type.get("price", 1))),
			"remaining": machine_rng.randi_range(minimum, maximum),
			"stock_weight": maxi(1, int(ticket_type.get("stock_weight", 1))),
			"size_id": str(ticket_type.get("size_id", "medium_square")),
			"palette": _copy_dict(_copy_dict(ticket_type.get("face", {})).get("palette", {})),
		})
	return {
		"schema": "scratch_ticket_machine_state",
		"version": 1,
		"machine_name": "Highway Scratch Center",
		"stock_day": int(environment.get("generated_day", environment.get("day", 0))),
		"stock_stream_key": stream_key,
		"stock_weighting": "inverse_price_without_replacement",
		"stock": stock,
		"environment_hooks": [{
			"id": REDEEM_HOOK_ID,
			"kind": "redeemer",
			"label": "Scratch-Ticket Clerk",
			"unique_object_class": "scratch_ticket_clerk",
			"unique_object_priority": 100,
		}],
		"active_ticket": {},
		"winner_pile": [],
		"loser_pile": [],
		"pending_penalty": 0,
		"penalty_shields_remaining": 0,
		"purchased_count": 0,
		"redeemed_count": 0,
		"last_dispense_id": "",
		"last_dispense_slot": 0,
		"dispense_started_msec": 0,
		"last_settled_ticket": {},
		"last_settled_pile": "",
		"last_file_id": "",
		"file_started_msec": 0,
		"last_sweep_id": "",
		"last_sweep_section": "",
		"sweep_started_msec": 0,
	}


func _weighted_stock_types(rng: RngStream, count: int) -> Array:
	var candidates := _ticket_types().duplicate(true)
	var selected: Array = []
	while not candidates.is_empty() and selected.size() < maxi(0, count):
		var total_weight := 0
		for candidate_value in candidates:
			total_weight += maxi(1, int((candidate_value as Dictionary).get("stock_weight", 1)))
		var roll := rng.randi_range(1, maxi(1, total_weight))
		var cursor := 0
		var selected_index := candidates.size() - 1
		for index in range(candidates.size()):
			cursor += maxi(1, int((candidates[index] as Dictionary).get("stock_weight", 1)))
			if roll <= cursor:
				selected_index = index
				break
		selected.append(candidates[selected_index])
		candidates.remove_at(selected_index)
	return selected


func _roll_ticket(ticket_type: Dictionary, rng: RngStream, luck_modifier: int, purchase_key: String) -> Dictionary:
	var prize := _weighted_prize(ticket_type, rng, luck_modifier)
	var mechanic := _copy_dict(ticket_type.get("mechanic", {}))
	var content := _build_mechanic_content(str(mechanic.get("type", "")), mechanic, prize, rng)
	var ticket_id := "%s:%s:%s" % [str(ticket_type.get("id", "ticket")), purchase_key, str(rng.randi_range(100000, 999999))]
	var ticket := {
		"id": ticket_id,
		"type_id": str(ticket_type.get("id", "")),
		"display_name": str(ticket_type.get("display_name", "Scratch Ticket")),
		"price": maxi(1, int(ticket_type.get("price", 1))),
		"top_prize": _definition_top_prize(ticket_type),
		"size_id": str(ticket_type.get("size_id", "medium_square")),
		"face": _copy_dict(ticket_type.get("face", {})),
		"mechanic": mechanic,
		"scratch": _copy_dict(ticket_type.get("scratch", {})),
		"outcome_id": str(prize.get("id", "blank")),
		"payout": maxi(0, int(prize.get("payout", 0))),
		"outcome": prize.duplicate(true),
		"mechanic_result": content,
		"spots": _dictionary_array(content.get("spots", [])),
		"outcome_fixed_at_purchase": true,
		"luck_modifier": luck_modifier,
		"settled": false,
	}
	var evaluated := _evaluate_mechanic(ticket)
	if evaluated != int(prize.get("payout", 0)):
		push_error("Scratch mechanic %s printed $%d but outcome row requires $%d." % [str(ticket.get("type_id", "")), evaluated, int(prize.get("payout", 0))])
		ticket["payout"] = maxi(0, int(prize.get("payout", 0)))
	else:
		ticket["payout"] = evaluated
	_initialize_ticket_mask(ticket, ticket_type)
	return ticket


func _definition_top_prize(ticket_type: Dictionary) -> int:
	var top := 0
	for prize_value in _dictionary_array(ticket_type.get("prize_table", [])):
		top = maxi(top, int((prize_value as Dictionary).get("payout", 0)))
	return top


func _initialize_ticket_mask(ticket: Dictionary, ticket_type: Dictionary) -> void:
	var scratch := _copy_dict(ticket_type.get("scratch", {}))
	var mask_columns := maxi(24, int(scratch.get("mask_columns", DEFAULT_MASK_COLUMNS)))
	var mask_rows := maxi(18, int(scratch.get("mask_rows", DEFAULT_MASK_ROWS)))
	scratch["mask_columns"] = mask_columns
	scratch["mask_rows"] = mask_rows
	scratch["brush_radius"] = maxf(8.0, float(scratch.get("brush_radius", DEFAULT_BRUSH_RADIUS)))
	scratch["pass_removal"] = clampf(float(scratch.get("pass_removal", DEFAULT_PASS_REMOVAL)), 0.10, 0.90)
	scratch["sweep_threshold"] = clampf(float(scratch.get("sweep_threshold", DEFAULT_SWEEP_THRESHOLD)), 0.50, 0.98)
	ticket["scratch"] = scratch
	var definitions := _dictionary_array(ticket_type.get("sections", []))
	if definitions.is_empty():
		definitions = [{"id": "play", "label": "PLAY AREA", "rect": [0.0, 0.0, 1.0, 1.0]}]
	var sections: Array = []
	for index in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		sections.append({
			"id": str(definition.get("id", "section_%d" % index)),
			"label": str(definition.get("label", "SECTION %d" % (index + 1))),
			"rect": _normalized_rect_array(definition.get("rect", [0.0, 0.0, 1.0, 1.0])),
			"sample_total": 0,
			"mask_remaining_units": 0,
			"coverage": 0.0,
			"revealed": false,
		})
	var mask: Array = []
	mask.resize(mask_columns * mask_rows)
	mask.fill(0)
	# Section rectangles are non-overlapping normalized print areas. Rasterize
	# their integer bounds directly instead of re-running dictionary lookups for
	# every mask sample; the mask remains ticket-wide and presentation-only.
	for section_index in range(sections.size()):
		var section: Dictionary = sections[section_index]
		var values: Array = section.get("rect", [])
		var left := float(values[0])
		var top := float(values[1])
		var right := minf(1.0, left + float(values[2]))
		var bottom := minf(1.0, top + float(values[3]))
		var column_start := clampi(int(ceil(left * float(mask_columns) - 0.5)), 0, mask_columns)
		var column_end := clampi(int(ceil(right * float(mask_columns) - 0.5)), column_start, mask_columns)
		var row_start := clampi(int(ceil(top * float(mask_rows) - 0.5)), 0, mask_rows)
		var row_end := clampi(int(ceil(bottom * float(mask_rows) - 0.5)), row_start, mask_rows)
		var sample_total := 0
		for row in range(row_start, row_end):
			var row_offset := row * mask_columns
			for column in range(column_start, column_end):
				var sample_index := row_offset + column
				if int(mask[sample_index]) != 0:
					continue
				mask[sample_index] = 255
				sample_total += 1
		section["sample_total"] = sample_total
		section["mask_remaining_units"] = sample_total * 255
		sections[section_index] = section
	ticket["sections"] = sections
	ticket["latex_mask"] = mask
	ticket["mask_revision"] = 0


func _build_mechanic_content(mechanic_type: String, mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	match mechanic_type:
		"match_two_of_three":
			return _build_two_fer_content(mechanic, prize, rng)
		"key_number_match":
			return _build_lucky_sevens_content(prize)
		"tic_tac_toe":
			return _build_tic_tac_gold_content(prize)
		"crossword":
			return _build_crossword_content(mechanic, prize)
		"bingo":
			return _build_bingo_content(prize)
		"beat_dealer_poker":
			return _build_holdem_content(mechanic, prize)
		"multi_game_vault":
			return _build_vault_content(prize)
	return {"spots": []}


func _build_two_fer_content(mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	var match_symbol := str(prize.get("match_symbol", ""))
	var symbols: Array = ["CLOVER", "BELL", "STAR"]
	if not match_symbol.is_empty():
		var other := "BELL" if match_symbol != "BELL" else "STAR"
		symbols = [match_symbol, match_symbol, other]
	_shuffle_array(symbols, rng)
	var spots: Array = []
	for index in range(symbols.size()):
		spots.append({"index": index, "section_id": "play", "symbol": str(symbols[index]), "role": "pair_spot"})
	return {"spots": spots, "symbols": symbols, "legend": _copy_dict(mechanic.get("legend", {}))}


func _build_lucky_sevens_content(prize: Dictionary) -> Dictionary:
	var winning_seven := bool(prize.get("winning_seven", false))
	var winning_numbers: Array = [7, 19] if winning_seven else [12, 23]
	var your_numbers: Array = [3, 9, 16, 28, 31, 40]
	var your_seven_count := clampi(int(prize.get("your_seven_count", 0)), 0, 6)
	var match_count := clampi(int(prize.get("match_count", 0)), 0, 6 - your_seven_count)
	for index in range(your_seven_count):
		your_numbers[index] = 7
	for index in range(match_count):
		your_numbers[your_seven_count + index] = int(winning_numbers[index % winning_numbers.size()])
	var winner_count := 6 if winning_seven else your_seven_count + match_count
	var prizes := _split_amount(maxi(0, int(prize.get("payout", 0))), winner_count)
	var your_spots: Array = []
	var spots: Array = []
	for index in range(winning_numbers.size()):
		spots.append({"index": spots.size(), "section_id": "winning_numbers", "number": int(winning_numbers[index]), "role": "winning_number"})
	var prize_cursor := 0
	for index in range(your_numbers.size()):
		var number := int(your_numbers[index])
		var winner := winning_seven or number == 7 or winning_numbers.has(number)
		var amount := int(prizes[prize_cursor]) if winner and prize_cursor < prizes.size() else 0
		if winner:
			prize_cursor += 1
		var spot := {"index": spots.size(), "section_id": "your_numbers", "number": number, "prize": amount, "winner": winner, "auto_seven": number == 7, "role": "your_number"}
		your_spots.append(spot)
		spots.append(spot)
	return {"spots": spots, "winning_numbers": winning_numbers, "your_numbers": your_spots, "winning_seven": winning_seven}


func _build_tic_tac_gold_content(prize: Dictionary) -> Dictionary:
	var requested_lines := clampi(int(prize.get("line_count", 0)), 0, 8)
	var marks := _tic_marks_for_line_count(requested_lines)
	var completed := _tic_completed_lines(marks)
	var bonus := bool(prize.get("bonus", false))
	var payout := maxi(0, int(prize.get("payout", 0)))
	var bonus_prize := payout if bonus else 0
	var line_amounts := _split_amount(payout - bonus_prize, completed.size())
	var line_prizes: Array = []
	line_prizes.resize(8)
	line_prizes.fill(0)
	for index in range(completed.size()):
		line_prizes[int(completed[index])] = int(line_amounts[index])
	var spots: Array = []
	for index in range(9):
		spots.append({"index": index, "section_id": "board", "mark": "WIN" if bool(marks[index]) else "MISS", "role": "board_mark"})
	spots.append({"index": 9, "section_id": "bonus", "mark": "GOLD" if bonus else "DUST", "prize": bonus_prize, "role": "bonus"})
	return {"spots": spots, "marks": marks, "completed_lines": completed, "line_prizes": line_prizes, "bonus": bonus, "bonus_prize": bonus_prize}


func _build_crossword_content(mechanic: Dictionary, prize: Dictionary) -> Dictionary:
	var words := _string_array(mechanic.get("words", []))
	var completed_count := clampi(int(prize.get("word_count", 0)), 0, words.size())
	var completed_words: Array = []
	for index in range(completed_count):
		completed_words.append(words[index])
	var bank: Array = []
	for word_value in completed_words:
		for character_index in range(str(word_value).length()):
			var letter := str(word_value).substr(character_index, 1)
			if not bank.has(letter):
				bank.append(letter)
	for filler_index in range("ETAOINSHRDLUCMFWYP".length()):
		var filler := "ETAOINSHRDLUCMFWYP".substr(filler_index, 1)
		if not bank.has(filler):
			bank.append(filler)
		if bank.size() >= 18:
			break
	var spots: Array = []
	for index in range(bank.size()):
		spots.append({"index": spots.size(), "section_id": "letter_bank", "letter": str(bank[index]), "role": "bank_letter"})
	for word_value in words:
		spots.append({"index": spots.size(), "section_id": "crossword", "word": str(word_value), "complete": completed_words.has(word_value), "role": "crossword_word"})
	return {"spots": spots, "letter_bank": bank, "words": words, "completed_words": completed_words, "word_count": completed_count, "legend": _copy_dict(mechanic.get("legend", {}))}


func _build_bingo_content(prize: Dictionary) -> Dictionary:
	var caller_numbers := _bingo_called_numbers()
	var total_lines := maxi(0, int(prize.get("line_count", 0)))
	var blackout_cards := clampi(int(prize.get("blackout_cards", 0)), 0, 4)
	var cards: Array = []
	var spots: Array = []
	for number in caller_numbers:
		spots.append({"index": spots.size(), "section_id": "callers", "number": int(number), "role": "caller"})
	var paying_card_count := blackout_cards if blackout_cards > 0 else mini(4, int(ceil(float(total_lines) / 2.0)))
	var card_payouts := _split_amount(maxi(0, int(prize.get("payout", 0))), maxi(1, paying_card_count))
	var payout_cursor := 0
	var remaining_lines := 0 if blackout_cards > 0 else total_lines
	for card_index in range(4):
		var blackout := card_index < blackout_cards
		var daubed: Array = []
		daubed.resize(25)
		daubed.fill(false)
		if blackout:
			daubed.fill(true)
		else:
			daubed[12] = true
			var requested_card_lines := mini(remaining_lines, 2)
			remaining_lines -= requested_card_lines
			for line_index in range(requested_card_lines):
				for column in range(5):
					daubed[line_index * 5 + column] = true
		var numbers := _bingo_card_numbers(card_index, daubed, caller_numbers)
		for cell_index in range(25):
			daubed[cell_index] = cell_index == 12 or caller_numbers.has(int(numbers[cell_index]))
		var card_lines := _bingo_completed_line_count(daubed)
		var pays := blackout or card_lines > 0
		var card_payout := int(card_payouts[payout_cursor]) if pays and payout_cursor < card_payouts.size() else 0
		if pays:
			payout_cursor += 1
		var card := {"index": card_index, "numbers": numbers, "daubed": daubed, "completed_lines": card_lines, "blackout": blackout, "payout": card_payout}
		cards.append(card)
		for cell_index in range(25):
			spots.append({"index": spots.size(), "section_id": "card_%d" % (card_index + 1), "number": int(numbers[cell_index]), "daubed": bool(daubed[cell_index]), "role": "bingo_cell"})
	return {"spots": spots, "caller_numbers": caller_numbers, "cards": cards, "line_count": total_lines, "blackout_cards": blackout_cards}


func _bingo_called_numbers() -> Array:
	return [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 43, 46, 49, 52, 55, 58, 61, 64, 67, 70, 73]


func _bingo_card_numbers(card_index: int, daubed: Array, caller_numbers: Array) -> Array:
	var numbers: Array = []
	numbers.resize(25)
	var called_by_column: Array = [[], [], [], [], []]
	var uncalled_by_column: Array = [[], [], [], [], []]
	for column in range(5):
		for number in range(column * 15 + 1, column * 15 + 16):
			if caller_numbers.has(number):
				(called_by_column[column] as Array).append(number)
			else:
				(uncalled_by_column[column] as Array).append(number)
	var called_cursor := [0, 0, 0, 0, 0]
	var uncalled_cursor := [0, 0, 0, 0, 0]
	for cell_index in range(25):
		if cell_index == 12:
			numbers[cell_index] = 0
			continue
		var column := cell_index % 5
		var pool: Array = called_by_column[column] if bool(daubed[cell_index]) else uncalled_by_column[column]
		var cursor: Array = called_cursor if bool(daubed[cell_index]) else uncalled_cursor
		var pool_index := (int(cursor[column]) + card_index) % pool.size()
		numbers[cell_index] = int(pool[pool_index])
		cursor[column] = int(cursor[column]) + 1
	return numbers


func _bingo_completed_line_count(daubed: Array) -> int:
	if daubed.size() < 25:
		return 0
	var lines := 0
	for row in range(5):
		var row_complete := true
		for column in range(5):
			row_complete = row_complete and bool(daubed[row * 5 + column])
		lines += 1 if row_complete else 0
	for column in range(5):
		var column_complete := true
		for row in range(5):
			column_complete = column_complete and bool(daubed[row * 5 + column])
		lines += 1 if column_complete else 0
	var diagonal_a := true
	var diagonal_b := true
	for index in range(5):
		diagonal_a = diagonal_a and bool(daubed[index * 5 + index])
		diagonal_b = diagonal_b and bool(daubed[index * 5 + (4 - index)])
	lines += 1 if diagonal_a else 0
	lines += 1 if diagonal_b else 0
	return lines


func _build_holdem_content(mechanic: Dictionary, prize: Dictionary) -> Dictionary:
	var your_rank := str(prize.get("your_rank", "HIGH CARD"))
	var dealer_rank := str(prize.get("dealer_rank", "PAIR"))
	var rank_order := _string_array(mechanic.get("rank_order", []))
	var wild := bool(prize.get("wild", false))
	var base_your_rank := your_rank
	var final_rank_index := rank_order.find(your_rank)
	if wild and final_rank_index > 0:
		base_your_rank = str(rank_order[final_rank_index - 1])
	var your_hand := _poker_hand_for_rank(your_rank, bool(prize.get("pocket_aces", false)))
	var dealer_hand := _poker_hand_for_rank(dealer_rank, false)
	var spots: Array = []
	for card_value in your_hand:
		spots.append({"index": spots.size(), "section_id": "your_hand", "card": str(card_value), "role": "your_card"})
	for card_value in dealer_hand:
		spots.append({"index": spots.size(), "section_id": "dealer_hand", "card": str(card_value), "role": "dealer_card"})
	spots.append({"index": spots.size(), "section_id": "wild", "card": "WILD" if wild else "NO WILD", "role": "wild"})
	return {"spots": spots, "your_hand": your_hand, "dealer_hand": dealer_hand, "base_your_rank": base_your_rank, "your_rank": your_rank, "dealer_rank": dealer_rank, "wild": wild, "pocket_aces": bool(prize.get("pocket_aces", false)), "printed_prize": maxi(0, int(prize.get("payout", 0)))}


func _build_vault_content(prize: Dictionary) -> Dictionary:
	var payout := maxi(0, int(prize.get("payout", 0)))
	var multiplier := clampi(int(prize.get("multiplier", 2)), 2, 20)
	var hit_count := clampi(int(prize.get("ladder_hits", 0)), 0, 5)
	var gold_bar := bool(prize.get("gold_bar", false))
	var vault_win := bool(prize.get("vault_win", false))
	var winning_rungs := 5 if gold_bar else hit_count
	var ladder_total := payout / 5 if vault_win else payout
	var vault_payout := payout - ladder_total
	var ladder_base_total := ladder_total / multiplier
	var ladder_remainder := ladder_total - ladder_base_total * multiplier
	var ladder_base_prizes := _split_amount(ladder_base_total, winning_rungs)
	var ladder: Array = []
	var spots: Array = [{"index": 0, "section_id": "multiplier", "multiplier": multiplier, "role": "multiplier"}]
	for rung in range(5):
		var match_win := rung < winning_rungs
		var base_prize := int(ladder_base_prizes[rung]) if rung < ladder_base_prizes.size() else 0
		var multiplied_prize := base_prize * multiplier + (ladder_remainder if rung == 0 and match_win else 0)
		var entry := {"rung": rung + 1, "match": match_win, "base_prize": base_prize, "payout": multiplied_prize}
		ladder.append(entry)
		spots.append({"index": spots.size(), "section_id": "cash_ladder", "rung": rung + 1, "match": match_win, "base_prize": base_prize, "payout": multiplied_prize, "role": "ladder"})
	spots.append({"index": spots.size(), "section_id": "gold_bar", "symbol": "GOLD BAR" if gold_bar else "BRASS", "win_all": gold_bar, "role": "gold_bar"})
	spots.append({"index": spots.size(), "section_id": "final_vault", "symbol": "OPEN" if vault_win else "SEALED", "payout": vault_payout, "role": "vault"})
	return {"spots": spots, "multiplier": multiplier, "ladder": ladder, "gold_bar": gold_bar, "vault_win": vault_win, "vault_payout": vault_payout}


func _evaluate_mechanic(ticket: Dictionary) -> int:
	var mechanic: Dictionary = ticket.get("mechanic", {}) if typeof(ticket.get("mechanic", {})) == TYPE_DICTIONARY else {}
	var result: Dictionary = ticket.get("mechanic_result", {}) if typeof(ticket.get("mechanic_result", {})) == TYPE_DICTIONARY else {}
	match str(mechanic.get("type", "")):
		"match_two_of_three":
			var symbols: Array = result.get("symbols", []) if typeof(result.get("symbols", [])) == TYPE_ARRAY else []
			var legend: Dictionary = result.get("legend", {}) if typeof(result.get("legend", {})) == TYPE_DICTIONARY else {}
			for symbol_value in symbols:
				if symbols.count(symbol_value) >= 2:
					return maxi(0, int(legend.get(str(symbol_value), 0)))
		"key_number_match":
			var winning: Array = result.get("winning_numbers", []) if typeof(result.get("winning_numbers", [])) == TYPE_ARRAY else []
			var win_all := winning.has(7)
			var total := 0
			for spot_value in _dictionary_array(result.get("your_numbers", [])):
				var spot: Dictionary = spot_value
				var number := int(spot.get("number", -1))
				if win_all or number == 7 or winning.has(number):
					total += maxi(0, int(spot.get("prize", 0)))
			return total
		"tic_tac_toe":
			var total := maxi(0, int(result.get("bonus_prize", 0))) if bool(result.get("bonus", false)) else 0
			var line_prizes: Array = result.get("line_prizes", []) if typeof(result.get("line_prizes", [])) == TYPE_ARRAY else []
			for line_index in _tic_completed_lines(result.get("marks", []) if typeof(result.get("marks", [])) == TYPE_ARRAY else []):
				if int(line_index) < line_prizes.size():
					total += maxi(0, int(line_prizes[int(line_index)]))
			return total
		"crossword":
			var legend: Dictionary = result.get("legend", {}) if typeof(result.get("legend", {})) == TYPE_DICTIONARY else {}
			return maxi(0, int(legend.get(str(int(result.get("word_count", 0))), 0)))
		"bingo":
			var total := 0
			for card_value in _dictionary_array(result.get("cards", [])):
				total += maxi(0, int((card_value as Dictionary).get("payout", 0)))
			return total
		"beat_dealer_poker":
			var pocket_aces := bool(result.get("pocket_aces", false))
			var rank_order := _string_array(mechanic.get("rank_order", []))
			var your_rank := rank_order.find(str(result.get("your_rank", "")))
			var dealer_rank := rank_order.find(str(result.get("dealer_rank", "")))
			return maxi(0, int(result.get("printed_prize", 0))) if pocket_aces or your_rank > dealer_rank else 0
		"multi_game_vault":
			var total := maxi(0, int(result.get("vault_payout", 0))) if bool(result.get("vault_win", false)) else 0
			var multiplier := clampi(int(result.get("multiplier", 2)), 2, 20)
			var gold_bar := bool(result.get("gold_bar", false))
			for rung_value in _dictionary_array(result.get("ladder", [])):
				var rung: Dictionary = rung_value
				if bool(rung.get("match", false)) or gold_bar:
					total += maxi(0, int(rung.get("base_prize", 0)) * multiplier)
					if int(rung.get("base_prize", 0)) * multiplier != int(rung.get("payout", 0)):
						total += maxi(0, int(rung.get("payout", 0)) - int(rung.get("base_prize", 0)) * multiplier)
			return total
	return 0


func _split_amount(total: int, count: int) -> Array:
	var result: Array = []
	if count <= 0:
		return result
	var base := floori(float(maxi(0, total)) / float(count))
	var remainder := maxi(0, total) % count
	for index in range(count):
		result.append(base + (1 if index < remainder else 0))
	return result


func _shuffle_array(values: Array, rng: RngStream) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _tic_line_indices() -> Array:
	return [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]


func _tic_completed_lines(marks: Array) -> Array:
	var result: Array = []
	if marks.size() < 9:
		return result
	var lines := _tic_line_indices()
	for line_index in range(lines.size()):
		var line: Array = lines[line_index]
		if bool(marks[int(line[0])]) and bool(marks[int(line[1])]) and bool(marks[int(line[2])]):
			result.append(line_index)
	return result


func _tic_marks_for_line_count(line_count: int) -> Array:
	for bits in range(512):
		var marks: Array = []
		for index in range(9):
			marks.append((bits & (1 << index)) != 0)
		if _tic_completed_lines(marks).size() == line_count:
			return marks
	var full: Array = []
	full.resize(9)
	full.fill(line_count >= 8)
	return full


func _poker_hand_for_rank(rank_name: String, pocket_aces: bool) -> Array:
	if pocket_aces:
		return ["AS", "AH", "7C", "5D", "2S"]
	match rank_name:
		"PAIR": return ["KS", "KH", "8D", "5C", "2H"]
		"TWO PAIR": return ["QS", "QH", "8D", "8C", "2H"]
		"STRAIGHT": return ["9S", "8H", "7D", "6C", "5H"]
		"FLUSH": return ["KS", "JS", "8S", "5S", "2S"]
		"FULL HOUSE": return ["JS", "JH", "JD", "5C", "5H"]
		"FOUR KIND": return ["9S", "9H", "9D", "9C", "2H"]
		"STRAIGHT FLUSH": return ["9S", "8S", "7S", "6S", "5S"]
		"ROYAL FLUSH": return ["AS", "KS", "QS", "JS", "10S"]
	return ["AS", "JD", "8C", "5H", "2S"]


func _weighted_prize(ticket_type: Dictionary, rng: RngStream, luck_modifier: int) -> Dictionary:
	var table := _dictionary_array(ticket_type.get("prize_table", []))
	if table.is_empty():
		return {"id": "blank", "payout": 0}
	var total := 0
	for entry_value in table:
		total += maxi(0, int((entry_value as Dictionary).get("weight", 0)))
	var roll := clampi(rng.randi_range(1, maxi(1, total)) + luck_modifier * 18, 1, maxi(1, total))
	var cursor := 0
	for entry_value in table:
		var entry: Dictionary = entry_value
		cursor += maxi(0, int(entry.get("weight", 0)))
		if roll <= cursor:
			return entry.duplicate(true)
	return (table[table.size() - 1] as Dictionary).duplicate(true)


func _reserve_penalty_shields(ticket: Dictionary, count: int) -> void:
	var assist := maxi(0, count)
	ticket["lucky_penny_assist"] = assist
	if assist <= 0:
		return
	var scratch := _copy_dict(ticket.get("scratch", {}))
	scratch["sweep_threshold"] = maxf(0.75, float(scratch.get("sweep_threshold", DEFAULT_SWEEP_THRESHOLD)) - minf(0.05, float(assist) * 0.01))
	ticket["scratch"] = scratch
func _scratch_segment(machine: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var ticket_value: Variant = machine.get("active_ticket", {})
	if typeof(ticket_value) != TYPE_DICTIONARY or (ticket_value as Dictionary).is_empty():
		return {"erased_samples": 0, "message": "Buy a ticket first."}
	var ticket: Dictionary = ticket_value
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var brush_radius := maxf(8.0, float(scratch.get("brush_radius", DEFAULT_BRUSH_RADIUS)))
	var brush_radius_squared := brush_radius * brush_radius
	var removal := clampf(float(scratch.get("pass_removal", DEFAULT_PASS_REMOVAL)), 0.10, 0.90)
	var threshold := clampf(float(scratch.get("sweep_threshold", DEFAULT_SWEEP_THRESHOLD)), 0.50, 0.98)
	var mask_columns := maxi(24, int(scratch.get("mask_columns", DEFAULT_MASK_COLUMNS)))
	var mask_rows := maxi(18, int(scratch.get("mask_rows", DEFAULT_MASK_ROWS)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	var sections: Array = ticket.get("sections", []) if typeof(ticket.get("sections", [])) == TYPE_ARRAY else []
	if mask.size() != mask_columns * mask_rows or sections.is_empty():
		return {"erased_samples": 0, "message": "This ticket's coating is damaged."}
	var scratch_rect := _ticket_scratch_rect(ticket)
	var segment_bounds := Rect2(Vector2(minf(from.x, to.x), minf(from.y, to.y)), Vector2(absf(to.x - from.x), absf(to.y - from.y))).grow(brush_radius)
	if not scratch_rect.intersects(segment_bounds):
		return {"erased_samples": 0, "message": "Drag across the printed latex."}
	var erased_samples := 0
	var erased_units := 0
	var interpolated_dabs := maxi(1, int(ceil(from.distance_to(to) / maxf(2.0, brush_radius * 0.35))))
	for sample_index in range(mask.size()):
		var old_alpha := int(mask[sample_index])
		if old_alpha <= 0:
			continue
		var normalized := _mask_sample_normalized(sample_index, mask_columns, mask_rows)
		var sample_point := scratch_rect.position + normalized * scratch_rect.size
		if not segment_bounds.has_point(sample_point) or _distance_squared_to_segment(sample_point, from, to) > brush_radius_squared:
			continue
		var section_index := _section_index_at_normalized(sections, normalized)
		if section_index < 0 or bool((sections[section_index] as Dictionary).get("revealed", false)):
			continue
		var new_alpha := 0 if old_alpha <= 2 else clampi(int(round(float(old_alpha) * (1.0 - removal))), 0, old_alpha - 1)
		var removed_units := old_alpha - new_alpha
		mask[sample_index] = new_alpha
		erased_samples += 1
		erased_units += removed_units
		var section: Dictionary = sections[section_index]
		section["mask_remaining_units"] = maxi(0, int(section.get("mask_remaining_units", 0)) - removed_units)
		sections[section_index] = section
	var swept_sections: Array = []
	for section_index in range(sections.size()):
		var section: Dictionary = sections[section_index]
		if bool(section.get("revealed", false)):
			continue
		var total_units := maxi(1, int(section.get("sample_total", 0)) * 255)
		var coverage := 1.0 - float(section.get("mask_remaining_units", total_units)) / float(total_units)
		section["coverage"] = clampf(coverage, 0.0, 1.0)
		if coverage >= threshold:
			_clear_mask_section(mask, sections, section_index, mask_columns, mask_rows)
			section = sections[section_index]
			section["revealed"] = true
			section["coverage"] = 1.0
			section["mask_remaining_units"] = 0
			sections[section_index] = section
			swept_sections.append(section)
			machine["last_sweep_section"] = str(section.get("id", "section_%d" % section_index))
			machine["last_sweep_id"] = "scratch-sweep:%s:%s:%d" % [str(ticket.get("id", "ticket")), str(section.get("id", section_index)), int(ticket.get("mask_revision", 0)) + 1]
	ticket["latex_mask"] = mask
	ticket["sections"] = sections
	ticket["mask_revision"] = int(ticket.get("mask_revision", 0)) + 1
	var complete := _ticket_complete(ticket)
	var message := "Soft flakes lift; another pass will open the patch."
	if not swept_sections.is_empty():
		message = "%s sweeps clean." % str((swept_sections[0] as Dictionary).get("label", "The section"))
	return {"erased_samples": erased_samples, "erased_units": erased_units, "interpolated_dabs": interpolated_dabs, "swept_sections": swept_sections, "penalty": 0, "ticket_complete": complete, "message": message}


func _reveal_all(machine: Dictionary) -> void:
	var ticket := _copy_dict(machine.get("active_ticket", {}))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	for sample_index in range(mask.size()):
		mask[sample_index] = 0
	ticket["latex_mask"] = mask
	var sections: Array = ticket.get("sections", []) if typeof(ticket.get("sections", [])) == TYPE_ARRAY else []
	for section_index in range(sections.size()):
		var section: Dictionary = sections[section_index]
		section["revealed"] = true
		section["coverage"] = 1.0
		section["mask_remaining_units"] = 0
		sections[section_index] = section
		ticket["sections"] = sections
	machine["active_ticket"] = ticket


func _draw_machine(surface, state: Dictionary) -> void:
	var shadow := Rect2(MACHINE_RECT.position + Vector2(8, 7), MACHINE_RECT.size)
	surface.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.42))
	var cabinet := [MACHINE_RECT.position + Vector2(8, 0), MACHINE_RECT.position + Vector2(MACHINE_RECT.size.x - 9, 0), MACHINE_RECT.position + Vector2(MACHINE_RECT.size.x, 12), MACHINE_RECT.end - Vector2(0, 11), MACHINE_RECT.end - Vector2(12, 0), MACHINE_RECT.position + Vector2(10, MACHINE_RECT.size.y), MACHINE_RECT.position + Vector2(0, MACHINE_RECT.size.y - 13), MACHINE_RECT.position + Vector2(0, 14)]
	surface.draw_polygon(cabinet, [Color("#9f1d2c")])
	var marquee := Rect2(MACHINE_RECT.position + Vector2(8, 8), Vector2(MACHINE_RECT.size.x - 16, 58))
	surface.draw_rect(marquee, Color("#ef3649"))
	surface.draw_rect(marquee, Color("#ffcf49"), false, 3)
	for ray in range(12):
		var angle := float(ray) * TAU / 12.0
		surface.draw_line(marquee.get_center(), marquee.get_center() + Vector2(cos(angle), sin(angle)) * 36.0, Color(1.0, 0.85, 0.25, 0.16), 3)
	surface.surface_label_centered("GOLD ROAD", Rect2(marquee.position + Vector2(8, 8), Vector2(marquee.size.x - 16, 22)), 19, C_WHITE)
	surface.surface_label_centered("NIGHT OWL JACKPOT • SCRATCH HERE", Rect2(marquee.position + Vector2(8, 34), Vector2(marquee.size.x - 16, 14)), 8, C_YELLOW)
	var side_panel := Rect2(MACHINE_RECT.position + Vector2(9, 72), Vector2(48, 250))
	surface.draw_rect(side_panel, Color("#0c8d88"))
	surface.draw_rect(side_panel, Color("#72eee0"), false, 2)
	for stripe in range(7):
		surface.draw_polygon([side_panel.position + Vector2(0, stripe * 38), side_panel.position + Vector2(48, stripe * 38 + 15), side_panel.position + Vector2(48, stripe * 38 + 29), side_panel.position + Vector2(0, stripe * 38 + 14)], [Color(1.0, 0.85, 0.25, 0.10)])
	for index in range(4):
		surface.surface_label_centered(["GOLD", "ROAD", "LUCK", "CO." ][index], Rect2(side_panel.position + Vector2(3, 22 + index * 52), Vector2(42, 22)), 10, C_WHITE)
	var glass := Rect2(MACHINE_RECT.position + Vector2(63, 72), Vector2(204, 250))
	surface.draw_rect(glass, Color("#070b12"))
	surface.draw_rect(glass, Color("#90a8b5"), false, 3)
	surface.draw_polygon([glass.position + Vector2(7, 4), glass.position + Vector2(36, 4), glass.position + Vector2(112, glass.size.y - 4), glass.position + Vector2(82, glass.size.y - 4)], [Color(0.65, 0.90, 1.0, 0.055)])
	var stock := _array_ref(state.get("scratch_stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		var rect := Rect2(glass.position + Vector2(7, 7 + index * 59), Vector2(glass.size.x - 14, 54))
		_draw_vending_window(surface, slot, rect, index)
		if int(slot.get("remaining", 0)) > 0:
			surface.surface_add_hit(rect, "scratch_buy", index)
	var payment := Rect2(MACHINE_RECT.position + Vector2(17, 329), Vector2(68, 31))
	surface.draw_rect(payment, Color("#361019"))
	surface.draw_rect(payment, Color("#ff6070"), false, 2)
	surface.surface_label_centered("CASH", payment, 9, C_WHITE)
	surface.draw_rect(Rect2(payment.position + Vector2(48, 8), Vector2(10, 15)), Color("#050608"))
	var status := Rect2(MACHINE_RECT.position + Vector2(93, 329), Vector2(166, 31))
	surface.draw_rect(status, Color("#15241f"))
	surface.surface_label_centered("SELECT A LIT ROW", status, 9, Color("#66f0ad"))
	var chute := Rect2(MACHINE_RECT.position + Vector2(42, 367), Vector2(MACHINE_RECT.size.x - 84, 27))
	surface.draw_rect(chute, Color("#24070d"))
	surface.draw_rect(chute, Color("#ffb05f"), false, 2)
	surface.draw_rect(chute.grow(-6), Color("#040507"))
	surface.surface_label_centered("TAKE TICKET", chute, 8, C_SOFT)
	for foot_x in [24.0, MACHINE_RECT.size.x - 38.0]:
		surface.draw_rect(Rect2(MACHINE_RECT.position + Vector2(foot_x, 397), Vector2(14, 7)), Color("#32151a"))
	surface.surface_label_centered("%d/%d PRINTS FOUND" % [int(state.get("scratch_collection_count", 0)), int(state.get("scratch_collection_total", COLLECTION_TOTAL))], Rect2(MACHINE_RECT.position + Vector2(91, 399), Vector2(150, 10)), 6, C_YELLOW)


func _draw_compact_tabs(surface, active_tab: String) -> void:
	var origin := Vector2(306, 8) if active_tab == "machine" else Vector2(18, 8)
	_draw_compact_tab(surface, Rect2(origin, Vector2(118, 30)), "MACHINE", "scratch_compact_machine", active_tab == "machine")
	_draw_compact_tab(surface, Rect2(origin + Vector2(124, 0), Vector2(118, 30)), "TICKET", "scratch_compact_ticket", active_tab == "ticket")


func _draw_compact_tab(surface, rect: Rect2, label: String, action: String, selected: bool) -> void:
	surface.draw_rect(rect, Color("#17644c") if selected else Color("#171313"))
	surface.draw_rect(rect, Color("#69efb3") if selected else Color("#7d6249"), false, 2)
	surface.surface_label_centered(label, rect, 9, C_WHITE if selected else C_SOFT)
	surface.surface_add_hit(rect, action, 0)


func _draw_vending_window(surface, slot: Dictionary, rect: Rect2, index: int) -> void:
	var palette := _dict_ref(slot.get("palette", {}))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var sold_out := int(slot.get("remaining", 0)) <= 0
	surface.draw_rect(rect, Color("#171c25"))
	surface.draw_rect(rect, Color("#4f5f6b"), false, 1)
	var mini_size := _dispenser_ticket_size(str(slot.get("size_id", "medium_square")))
	mini_size *= 0.68
	var ticket := Rect2(rect.position + Vector2(8.0 + (58.0 - mini_size.x) * 0.5, (rect.size.y - mini_size.y) * 0.5), mini_size)
	surface.draw_rect(Rect2(ticket.position + Vector2(3, 3), ticket.size), Color(0.0, 0.0, 0.0, 0.42))
	surface.draw_rect(ticket, Color(paper.r * (0.42 if sold_out else 1.0), paper.g * (0.42 if sold_out else 1.0), paper.b * (0.42 if sold_out else 1.0)))
	surface.draw_rect(Rect2(ticket.position, Vector2(ticket.size.x, minf(18.0, ticket.size.y * 0.30))), Color(accent.r, accent.g, accent.b, 0.45 if sold_out else 1.0))
	surface.surface_label_centered(str(slot.get("display_name", "Ticket")).to_upper().left(15), Rect2(ticket.position + Vector2(2, 2), Vector2(ticket.size.x - 4, minf(14.0, ticket.size.y * 0.28))), 6, C_DARK if not sold_out else C_SOFT)
	for mark_index in range(6):
		var mark_center := ticket.position + Vector2(ticket.size.x * (0.25 + float(mark_index % 3) * 0.25), ticket.size.y * (0.56 + float(mark_index / 3) * 0.25))
		surface.draw_circle(mark_center, maxf(2.0, minf(ticket.size.x, ticket.size.y) * 0.07), Color(accent.r, accent.g, accent.b, 0.22 if sold_out else 0.72))
	surface.surface_label(str(slot.get("display_name", "Ticket")).to_upper().left(20), rect.position + Vector2(72, 16), 7, C_SOFT)
	surface.surface_label("SOLD OUT" if sold_out else "$%d • %d LEFT" % [int(slot.get("price", 1)), int(slot.get("remaining", 0))], rect.position + Vector2(72, 35), 8, C_PINK if sold_out else C_WHITE)
	var button := Rect2(rect.end - Vector2(31, 39), Vector2(23, 29))
	surface.draw_rect(button, Color("#4a111b") if sold_out else Color("#14734e"))
	surface.draw_rect(button, C_PINK if sold_out else Color("#65f2ac"), false, 2)
	surface.surface_label_centered(str(index + 1), button, 10, C_WHITE)


func _dispenser_ticket_size(size_id: String) -> Vector2:
	match size_id:
		"small_rectangle": return Vector2(88, 38)
		"medium_square": return Vector2(58, 58)
		"large_rectangle": return Vector2(88, 58)
		"tall": return Vector2(43, 66)
	return Vector2(58, 58)


func _draw_ticket(surface, state: Dictionary) -> void:
	var ticket := _dict_ref(state.get("scratch_ticket", {}))
	_configure_active_ticket_layout(ticket, bool(state.get("scratch_compact_mode", false)))
	_draw_counter_mat(surface)
	if ticket.is_empty() or bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		_draw_empty_ticket_outline(surface)
		return
	var face := _dict_ref(ticket.get("face", {}))
	var palette := _dict_ref(face.get("palette", {}))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var latex := Color(str(palette.get("latex", "#b9bcc8")))
	var trim := Color(str(palette.get("trim", "#ffd447")))
	var ticket_shape := [active_ticket_rect.position + Vector2(7, 0), active_ticket_rect.end - Vector2(7, active_ticket_rect.size.y), active_ticket_rect.end - Vector2(0, 7), active_ticket_rect.end - Vector2(7, 0), active_ticket_rect.position + Vector2(7, active_ticket_rect.size.y), active_ticket_rect.position + Vector2(0, active_ticket_rect.size.y - 7), active_ticket_rect.position + Vector2(0, 7)]
	var shadow_shape: Array = []
	for point_value in ticket_shape:
		shadow_shape.append((point_value as Vector2) + Vector2(5, 5))
	surface.draw_polygon(shadow_shape, [Color(0.0, 0.0, 0.0, 0.35)])
	surface.draw_polygon(ticket_shape, [paper])
	surface.draw_rect(active_ticket_rect.grow(-4), trim, false, 3)
	_draw_ticket_background(surface, ticket, paper, ink, accent, trim)
	var title_rect := Rect2(active_ticket_rect.position + Vector2(20, 10), Vector2(active_ticket_rect.size.x - 40, 38))
	surface.surface_label_centered(str(ticket.get("display_name", "SCRATCH TICKET")).to_upper(), title_rect, 23 if str(ticket.get("display_name", "")).length() < 15 else 19, ink)
	var price_badge := Rect2(active_ticket_rect.position + Vector2(8, 8), Vector2(38, 30))
	surface.draw_circle(price_badge.get_center(), 19, accent)
	surface.surface_label_centered("$%d" % int(ticket.get("price", 1)), price_badge, 14, C_WHITE)
	var top_prize := int(ticket.get("top_prize", 0))
	surface.surface_label_centered("WIN UP TO $%d" % top_prize, Rect2(active_ticket_rect.position + Vector2(34, 50), Vector2(active_ticket_rect.size.x - 68, 20)), 12, trim if paper.get_luminance() < 0.45 else accent)
	var mechanic := _dict_ref(ticket.get("mechanic", {}))
	var play_label := _ticket_play_label(str(ticket.get("type_id", "")), mechanic)
	surface.surface_label_centered(play_label, Rect2(active_ticket_rect.position + Vector2(20, 72), Vector2(active_ticket_rect.size.x - 40, 18)), 8, ink)
	var fortune := str(state.get("scratch_fortune", ""))
	if not fortune.is_empty():
		surface.surface_label("TAROT: %s" % fortune.to_upper(), active_ticket_rect.position + Vector2(active_ticket_rect.size.x - 112, 104), 7, accent)
	if int(state.get("scratch_penalty_shields", 0)) > 0:
		surface.surface_label("PENNY ASSIST", active_ticket_rect.position + Vector2(20, 104), 7, accent)
	var xray_peeks := _array_ref(state.get("scratch_xray_peeks", []))
	_draw_mechanic_result(surface, ticket, ink, accent, trim)
	_draw_ticket_latex_mask(surface, ticket, latex)
	_draw_xray_peeks(surface, xray_peeks, accent)
	_draw_section_status(surface, ticket, accent, trim)
	var scratch_rect := _ticket_scratch_rect(ticket)
	surface.surface_add_drag_hit(scratch_rect.grow(5), SCRUB_ACTION, 0)
	_draw_ticket_rules(surface, ticket, ink, accent, trim)
	var crumbs := _array_ref(state.get("scratch_crumbs", []))
	for crumb_value in crumbs:
		var crumb: Dictionary = crumb_value
		var point := Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0)))
		surface.draw_circle(point, float(crumb.get("r", 2.0)), latex)
	_draw_brush_feedback(surface, state, latex)
	_draw_sweep_feedback(surface, state, trim)


func _draw_mechanic_result(surface, ticket: Dictionary, ink: Color, accent: Color, trim: Color) -> void:
	var result: Dictionary = ticket.get("mechanic_result", {}) if typeof(ticket.get("mechanic_result", {})) == TYPE_DICTIONARY else {}
	var play_rect := active_scratch_rect
	match str(ticket.get("type_id", "")):
		"two_fer":
			var symbols: Array = result.get("symbols", []) if typeof(result.get("symbols", [])) == TYPE_ARRAY else []
			for index in range(symbols.size()):
				var width := play_rect.size.x / 3.0 - 10.0
				var rect := Rect2(play_rect.position + Vector2(5.0 + float(index) * (width + 10.0), 8.0), Vector2(width, play_rect.size.y - 16.0))
				surface.draw_circle(rect.get_center(), 39.0, Color(accent.r, accent.g, accent.b, 0.12))
				surface.draw_circle(rect.get_center(), 39.0, accent, false, 2)
				surface.surface_label_centered(str(symbols[index]), rect, 13, ink)
		"lucky_7s":
			var winning: Array = result.get("winning_numbers", []) if typeof(result.get("winning_numbers", [])) == TYPE_ARRAY else []
			for index in range(winning.size()):
				_draw_number_medallion(surface, Rect2(play_rect.position + Vector2(play_rect.size.x * 0.27 + float(index) * play_rect.size.x * 0.28, 2.0), Vector2(play_rect.size.x * 0.20, play_rect.size.y * 0.23)), int(winning[index]), ink, trim)
			var your_numbers := _array_ref(result.get("your_numbers", []))
			for index in range(your_numbers.size()):
				var spot: Dictionary = your_numbers[index]
				var rect := Rect2(play_rect.position + Vector2(6.0 + float(index % 3) * play_rect.size.x / 3.0, play_rect.size.y * 0.34 + float(index / 3) * play_rect.size.y * 0.31), Vector2(play_rect.size.x / 3.0 - 12.0, play_rect.size.y * 0.26))
				_draw_number_medallion(surface, rect, int(spot.get("number", 0)), ink, accent)
				surface.surface_label_centered("$%d" % int(spot.get("prize", 0)), Rect2(rect.position + Vector2(0, 31), Vector2(rect.size.x, 13)), 7, ink)
		"tic_tac_gold":
			var marks: Array = result.get("marks", []) if typeof(result.get("marks", [])) == TYPE_ARRAY else []
			for index in range(mini(9, marks.size())):
				var board_size := minf(play_rect.size.y, play_rect.size.x * 0.68)
				var rect := Rect2(play_rect.position + Vector2(float(index % 3) * board_size / 3.0, float(index / 3) * board_size / 3.0), Vector2(board_size / 3.0 - 4.0, board_size / 3.0 - 4.0))
				surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.10))
				surface.draw_rect(rect, trim, false, 2)
				surface.surface_label_centered("WIN" if bool(marks[index]) else "—", rect, 13, trim if bool(marks[index]) else ink)
			var bonus_rect := Rect2(play_rect.position + Vector2(play_rect.size.x * 0.73, play_rect.size.y * 0.22), Vector2(play_rect.size.x * 0.25, play_rect.size.y * 0.56))
			surface.draw_rect(bonus_rect, Color(trim.r, trim.g, trim.b, 0.14))
			surface.draw_rect(bonus_rect, trim, false, 3)
			surface.surface_label_centered("GOLD" if bool(result.get("bonus", false)) else "DUST", bonus_rect, 13, ink)
		"crossword_corner":
			var bank: Array = result.get("letter_bank", []) if typeof(result.get("letter_bank", [])) == TYPE_ARRAY else []
			for index in range(bank.size()):
				var rect := Rect2(play_rect.position + Vector2(float(index % 3) * play_rect.size.x * 0.075, float(index / 3) * play_rect.size.y / 6.0 + 3.0), Vector2(play_rect.size.x * 0.065, play_rect.size.y / 6.0 - 4.0))
				surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.13))
				surface.surface_label_centered(str(bank[index]), rect, 9, ink)
			var words: Array = result.get("words", []) if typeof(result.get("words", [])) == TYPE_ARRAY else []
			var completed: Array = result.get("completed_words", []) if typeof(result.get("completed_words", [])) == TYPE_ARRAY else []
			for index in range(words.size()):
				var rect := Rect2(play_rect.position + Vector2(play_rect.size.x * 0.31, 3.0 + float(index) * play_rect.size.y / 7.0), Vector2(play_rect.size.x * 0.67, play_rect.size.y / 7.0 - 3.0))
				surface.draw_rect(rect, Color(trim.r, trim.g, trim.b, 0.16) if completed.has(words[index]) else Color(ink.r, ink.g, ink.b, 0.06))
				surface.surface_label("%s  %s" % ["✓" if completed.has(words[index]) else "·", str(words[index])], rect.position + Vector2(7, 15), 10, ink)
		"bonus_bingo":
			var callers: Array = result.get("caller_numbers", []) if typeof(result.get("caller_numbers", [])) == TYPE_ARRAY else []
			for index in range(callers.size()):
				var center := play_rect.position + Vector2(8.0 + float(index % 4) * play_rect.size.x * 0.055, 10.0 + float(index / 4) * play_rect.size.y / 6.0)
				surface.draw_circle(center, 7.0, Color(trim.r, trim.g, trim.b, 0.32))
				surface.surface_label_centered(str(callers[index]), Rect2(center - Vector2(7, 7), Vector2(14, 14)), 6, ink)
			var cards := _array_ref(result.get("cards", []))
			for card_index in range(cards.size()):
				_draw_bingo_card(surface, cards[card_index], Rect2(play_rect.position + Vector2(play_rect.size.x * (0.29 + float(card_index % 2) * 0.36), play_rect.size.y * (0.02 + float(card_index / 2) * 0.50)), Vector2(play_rect.size.x * 0.31, play_rect.size.y * 0.44)), ink, accent, trim)
		"high_roller_holdem":
			_draw_poker_hand(surface, result.get("your_hand", []) if typeof(result.get("your_hand", [])) == TYPE_ARRAY else [], play_rect.position + Vector2(5, 14), ink, accent, play_rect.size.x)
			_draw_poker_hand(surface, result.get("dealer_hand", []) if typeof(result.get("dealer_hand", [])) == TYPE_ARRAY else [], play_rect.position + Vector2(5, play_rect.size.y * 0.47), ink, Color("#8e9d98"), play_rect.size.x)
			surface.surface_label("YOU: %s" % str(result.get("your_rank", "")), play_rect.position + Vector2(5, 10), 7, trim)
			surface.surface_label("HOUSE: %s" % str(result.get("dealer_rank", "")), play_rect.position + Vector2(5, play_rect.size.y * 0.44), 7, ink)
			var wild_label := "WILD %s → %s" % [str(result.get("base_your_rank", "")), str(result.get("your_rank", ""))] if bool(result.get("wild", false)) else "NO WILD"
			surface.surface_label_centered("POCKET ACES — WIN ALL" if bool(result.get("pocket_aces", false)) else wild_label, Rect2(play_rect.position + Vector2(12, play_rect.size.y - 21), Vector2(play_rect.size.x - 24, 18)), 8, trim)
		"golden_vault":
			surface.surface_label_centered("%d×" % int(result.get("multiplier", 2)), Rect2(play_rect.position + Vector2(play_rect.size.x * 0.20, 1), Vector2(play_rect.size.x * 0.60, play_rect.size.y * 0.14)), 18, trim)
			var ladder := _array_ref(result.get("ladder", []))
			for index in range(ladder.size()):
				var rung: Dictionary = ladder[index]
				var rect := Rect2(play_rect.position + Vector2(play_rect.size.x * 0.10, play_rect.size.y * (0.18 + float(index) * 0.105)), Vector2(play_rect.size.x * 0.80, play_rect.size.y * 0.085))
				surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.12 + float(index) * 0.025))
				surface.surface_label("RUNG %d" % int(rung.get("rung", index + 1)), rect.position + Vector2(7, 14), 8, ink)
				var rung_text := "$%d × %d = $%d" % [int(rung.get("base_prize", 0)), int(result.get("multiplier", 2)), int(rung.get("payout", 0))] if bool(rung.get("match", false)) else "LOCKED"
				surface.surface_label(rung_text, rect.position + Vector2(76, 14), 7, trim if bool(rung.get("match", false)) else ink)
			surface.surface_label_centered("GOLD BAR — WIN ALL" if bool(result.get("gold_bar", false)) else "BRASS BAR", Rect2(play_rect.position + Vector2(play_rect.size.x * 0.10, play_rect.size.y * 0.74), Vector2(play_rect.size.x * 0.80, play_rect.size.y * 0.09)), 8, trim)
			surface.surface_label_centered("VAULT OPEN  $%d" % int(result.get("vault_payout", 0)) if bool(result.get("vault_win", false)) else "VAULT SEALED", Rect2(play_rect.position + Vector2(play_rect.size.x * 0.10, play_rect.size.y * 0.88), Vector2(play_rect.size.x * 0.80, play_rect.size.y * 0.09)), 8, trim)


func _draw_number_medallion(surface, rect: Rect2, number: int, ink: Color, accent: Color) -> void:
	surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.45, Color(accent.r, accent.g, accent.b, 0.28))
	surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.45, accent, false, 2)
	surface.surface_label_centered(str(number), rect, 14, ink)


func _draw_bingo_card(surface, card: Dictionary, rect: Rect2, ink: Color, accent: Color, trim: Color) -> void:
	var numbers: Array = card.get("numbers", []) if typeof(card.get("numbers", [])) == TYPE_ARRAY else []
	var daubed: Array = card.get("daubed", []) if typeof(card.get("daubed", [])) == TYPE_ARRAY else []
	surface.draw_rect(rect, Color(ink.r, ink.g, ink.b, 0.06))
	surface.draw_rect(rect, trim if bool(card.get("blackout", false)) else accent, false, 2)
	for index in range(mini(25, numbers.size())):
		var cell := Rect2(rect.position + Vector2(float(index % 5) * rect.size.x / 5.0, float(index / 5) * rect.size.y / 5.0), rect.size / 5.0)
		if index < daubed.size() and bool(daubed[index]):
			surface.draw_circle(cell.get_center(), 6, Color(accent.r, accent.g, accent.b, 0.42))
		surface.surface_label_centered("FREE" if index == 12 else str(numbers[index]), cell, 4 if index == 12 else 5, ink)


func _draw_poker_hand(surface, cards: Array, origin: Vector2, ink: Color, accent: Color, available_width: float) -> void:
	var gap := maxf(2.0, available_width * 0.012)
	var width := (available_width - 10.0 - gap * 4.0) / 5.0
	for index in range(cards.size()):
		var rect := Rect2(origin + Vector2(float(index) * (width + gap), 5), Vector2(width, 58))
		surface.draw_rect(rect, Color("#fff5d8"))
		surface.draw_rect(rect, accent, false, 2)
		surface.surface_label_centered(str(cards[index]), rect, 10, ink)


func _draw_xray_peeks(surface, peeks: Array, accent: Color) -> void:
	if peeks.is_empty():
		return
	var values: Array = []
	for peek_value in peeks:
		values.append(str((peek_value as Dictionary).get("symbol", "?")))
	var banner := Rect2(active_scratch_rect.get_center() - Vector2(74, 15), Vector2(148, 30))
	surface.draw_rect(banner, Color(accent.r, accent.g, accent.b, 0.18))
	surface.draw_rect(banner, accent, false, 1)
	surface.surface_label_centered("X-RAY  %s" % " / ".join(values), banner, 8, accent)


func _draw_counter_mat(surface) -> void:
	var mat := PLAY_SURFACE_RECT
	surface.draw_rect(mat, Color("#321d18"))
	for stripe in range(9):
		var y := mat.position.y + 8.0 + float(stripe) * 47.0
		surface.draw_line(Vector2(mat.position.x + 3, y), Vector2(mat.end.x - 3, y - 13), Color(1.0, 0.78, 0.54, 0.035), 2)


func _draw_empty_ticket_outline(surface) -> void:
	active_ticket_rect = DEFAULT_TICKET_RECT
	active_scratch_rect = DEFAULT_SCRATCH_RECT
	surface.draw_rect(PLAY_SURFACE_RECT, Color("#191513"))
	for corner in range(4):
		var offset := Vector2(13 if corner % 2 == 0 else PLAY_SURFACE_RECT.size.x - 33, 19 if corner < 2 else PLAY_SURFACE_RECT.size.y - 39)
		surface.draw_rect(Rect2(PLAY_SURFACE_RECT.position + offset, Vector2(20, 20)), Color("#6b5143"), false, 2)
	surface.surface_label_centered("TICKET LANDING TRAY", Rect2(PLAY_SURFACE_RECT.position + Vector2(28, 154), Vector2(PLAY_SURFACE_RECT.size.x - 56, 28)), 16, Color("#a78a77"))
	surface.surface_label_centered("Choose a printed ticket from the cabinet", Rect2(PLAY_SURFACE_RECT.position + Vector2(24, 186), Vector2(PLAY_SURFACE_RECT.size.x - 48, 20)), 9, Color("#816b5e"))


func _draw_ticket_background(surface, ticket: Dictionary, paper: Color, ink: Color, accent: Color, trim: Color) -> void:
	# SA2_PER_FRAME_OK: bounded decorative geometry (at most 18 marks) is the ticket face itself; no state duplication or unbounded allocation.
	var face := _dict_ref(ticket.get("face", {}))
	var layout := str(face.get("layout", "classic_nine"))
	match layout:
		"two_fer_burst":
			for ray in range(18):
				var angle := float(ray) * TAU / 18.0
				surface.draw_line(active_ticket_rect.position + Vector2(active_ticket_rect.size.x * 0.5, 70), active_ticket_rect.position + Vector2(active_ticket_rect.size.x * 0.5, 70) + Vector2(cos(angle), sin(angle)) * active_ticket_rect.size.x * 0.44, Color(accent.r, accent.g, accent.b, 0.09), 3)
		"lucky_seven_neon":
			for seven in range(7):
				var point := active_ticket_rect.position + Vector2(24 + (seven * 47) % maxi(40, int(active_ticket_rect.size.x - 46)), 92 + (seven * 67) % maxi(60, int(active_ticket_rect.size.y - 130)))
				surface.surface_label_centered("7", Rect2(point, Vector2(22, 24)), 15, Color(accent.r, accent.g, accent.b, 0.10))
		"tic_tac_gold":
			for stripe in range(10):
				var x := active_ticket_rect.position.x + float(stripe) * 44.0 - 40.0
				surface.draw_polygon([Vector2(x, active_ticket_rect.position.y + 92), Vector2(x + 18, active_ticket_rect.position.y + 92), Vector2(x + 62, active_ticket_rect.position.y + 132), Vector2(x + 44, active_ticket_rect.position.y + 132)], [Color(trim.r, trim.g, trim.b, 0.10)]) # SA2_PER_FRAME_OK: bounded four-point gold stripe.
		"golden_vault":
			for ring in range(5):
				surface.draw_circle(active_ticket_rect.position + Vector2(active_ticket_rect.size.x * 0.5, 96), 30.0 + float(ring) * 11.0, Color(accent.r, accent.g, accent.b, 0.07), false, 3)
			surface.draw_circle(active_ticket_rect.get_center() + Vector2(0, 40), active_ticket_rect.size.x * 0.35, Color(trim.r, trim.g, trim.b, 0.08), false, 6)
		"corner_crossword":
			for line_index in range(9):
				var offset := float(line_index) * 38.0
				surface.draw_line(active_ticket_rect.position + Vector2(10 + offset, 92), active_ticket_rect.position + Vector2(10 + offset, active_ticket_rect.size.y - 20), Color(ink.r, ink.g, ink.b, 0.05), 1)
		"four_card_bingo":
			for ball in range(14):
				var point := active_ticket_rect.position + Vector2(16 + (ball * 71) % maxi(40, int(active_ticket_rect.size.x - 30)), 94 + (ball * 43) % maxi(60, int(active_ticket_rect.size.y - 115)))
				surface.draw_circle(point, 9 + float(ball % 3), Color(accent.r, accent.g, accent.b, 0.07))
		"high_roller_felt":
			for diamond in range(7):
				var center := active_ticket_rect.position + Vector2(30 + (diamond * 46) % maxi(40, int(active_ticket_rect.size.x - 45)), 112 + (diamond % 2) * maxf(80, active_ticket_rect.size.y - 160))
				surface.draw_polygon([center + Vector2(0, -12), center + Vector2(8, 0), center + Vector2(0, 12), center + Vector2(-8, 0)], [Color(trim.r, trim.g, trim.b, 0.13)])


func _draw_ticket_latex_mask(surface, ticket: Dictionary, latex: Color) -> void:
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var columns := maxi(24, int(scratch.get("mask_columns", DEFAULT_MASK_COLUMNS)))
	var rows := maxi(18, int(scratch.get("mask_rows", DEFAULT_MASK_ROWS)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	if mask.size() != columns * rows:
		return
	var rect := _ticket_scratch_rect(ticket)
	var sample_size := Vector2(rect.size.x / float(columns), rect.size.y / float(rows))
	# Runs of equal alpha keep the high-resolution buffer cheap to draw without copying it.
	for row in range(rows):
		var column := 0
		while column < columns:
			var alpha := int(mask[row * columns + column])
			if alpha <= 0:
				column += 1
				continue
			var run_end := column + 1
			while run_end < columns and int(mask[row * columns + run_end]) == alpha:
				run_end += 1
			var run_rect := Rect2(rect.position + Vector2(float(column) * sample_size.x, float(row) * sample_size.y), Vector2(float(run_end - column) * sample_size.x + 0.5, sample_size.y + 0.5))
			surface.draw_rect(run_rect, Color(latex.r, latex.g, latex.b, float(alpha) / 255.0))
			column = run_end


func _draw_brush_feedback(surface, state: Dictionary, latex: Color) -> void:
	if not bool(state.get("scratch_drag_active", false)):
		return
	var point: Vector2 = state.get("scratch_last_pointer", Vector2.ZERO)
	var drunk_level := maxi(0, int(state.get("scratch_drunk_level", 0)))
	if drunk_level > 0 and not bool(state.get("scratch_reduce_motion", false)):
		var time := float(surface.surface_render_elapsed_sec)
		point += Vector2(sin(time * 9.0), cos(time * 7.0)) * minf(4.0, float(drunk_level) * 0.08)
	var radius := maxf(8.0, float(state.get("scratch_brush_radius", DEFAULT_BRUSH_RADIUS)))
	surface.draw_circle(point, radius, Color(1.0, 1.0, 1.0, 0.12), false, 2)
	surface.draw_circle(point + Vector2(-radius * 0.25, -radius * 0.18), 2.0, Color(latex.r, latex.g, latex.b, 0.85))


func _draw_sweep_feedback(surface, state: Dictionary, trim: Color) -> void:
	if bool(state.get("scratch_reduce_motion", false)) or not bool(surface.surface_animation_active(SWEEP_CHANNEL)):
		return
	var progress: float = float(surface.surface_animation_progress(SWEEP_CHANNEL))
	var rect := _ticket_scratch_rect(state.get("scratch_ticket", {}) if typeof(state.get("scratch_ticket", {})) == TYPE_DICTIONARY else {})
	var x := lerpf(rect.position.x, rect.end.x, progress)
	surface.draw_rect(Rect2(Vector2(x - 8.0, rect.position.y), Vector2(16.0, rect.size.y)), Color(trim.r, trim.g, trim.b, 0.24 * (1.0 - progress)))


func _ticket_play_label(type_id: String, _mechanic: Dictionary) -> String:
	match type_id:
		"two_fer": return "MATCH ANY TWO OF THREE SYMBOLS"
		"lucky_7s": return "MATCH NUMBERS — EVERY 7 HAS POWER"
		"tic_tac_gold": return "COMPLETE WIN LINES — CHECK THE BONUS"
		"crossword_corner": return "REVEAL LETTERS — COMPLETE THREE OR MORE WORDS"
		"bonus_bingo": return "CALL 24 NUMBERS — FINISH LINES OR BLACKOUT"
		"high_roller_holdem": return "BEAT THE DEALER — WILD AND POCKET ACES PAY"
		"golden_vault": return "CLIMB THE LADDER — BREAK THE FINAL VAULT"
	return "SCRATCH THE PRINTED PLAY AREAS"


func _draw_ticket_rules(surface, ticket: Dictionary, ink: Color, accent: Color, trim: Color) -> void:
	var mechanic := _dict_ref(ticket.get("mechanic", {}))
	var lines := _array_ref(mechanic.get("rules", []))
	var rules_height := 54.0 if active_ticket_rect.size.y >= 300.0 else 42.0
	var rules_rect := Rect2(active_ticket_rect.position + Vector2(14, active_ticket_rect.size.y - rules_height - 7), Vector2(active_ticket_rect.size.x - 28, rules_height))
	surface.draw_rect(rules_rect, Color(0.0, 0.0, 0.0, 0.09))
	surface.draw_rect(rules_rect, Color(accent.r, accent.g, accent.b, 0.65), false, 1)
	for index in range(lines.size()):
		surface.surface_label(str(lines[index]).left(64), rules_rect.position + Vector2(7, 11 + index * 9), 6 if active_ticket_rect.size.x < 330 else 7, ink)
	var serial := str(ticket.get("id", "000000")).right(12).to_upper()
	if rules_height >= 50.0:
		surface.surface_label("VOID IF ALTERED  •  %s" % serial, rules_rect.position + Vector2(7, rules_height - 5), 5, Color(ink.r, ink.g, ink.b, 0.72))
	surface.draw_rect(Rect2(active_ticket_rect.position + Vector2(4, active_ticket_rect.size.y - 3), Vector2(active_ticket_rect.size.x - 8, 3)), trim)


func _draw_surface_hud(surface, state: Dictionary) -> void:
	var ticket := _dict_ref(state.get("scratch_ticket", {}))
	var pending := int(state.get("scratch_current_winnings", 0))
	surface.draw_rect(STATUS_HUD_RECT, Color("#171313"))
	surface.draw_rect(STATUS_HUD_RECT, Color("#7d6249"), false, 2)
	var name := str(ticket.get("display_name", "SELECT A TICKET")).to_upper()
	var price := int(ticket.get("price", 0))
	surface.surface_label(name.left(22), STATUS_HUD_RECT.position + Vector2(10, 22), 9, C_WHITE)
	surface.surface_label("PRICE $%d" % price if price > 0 else "SELECT ROW", STATUS_HUD_RECT.position + Vector2(145, 22), 8, C_YELLOW)
	surface.surface_label("DUE $%d" % pending, STATUS_HUD_RECT.position + Vector2(215, 22), 8, Color("#62e3a2") if pending > 0 else C_SOFT)
	var clerk_rect := Rect2(STATUS_HUD_RECT.end - Vector2(166, 29), Vector2(84, 24))
	surface.draw_rect(clerk_rect, Color("#16452f") if pending > 0 else Color("#25211d"))
	surface.draw_rect(clerk_rect, Color("#62e3a2") if pending > 0 else Color("#756858"), false, 1)
	surface.surface_label_centered("CASH AT CLERK", clerk_rect, 7, C_WHITE if pending > 0 else C_SOFT)
	if ticket.is_empty():
		return
	var all_rect := Rect2(STATUS_HUD_RECT.end - Vector2(78, 29), Vector2(72, 24))
	var reduced := bool(state.get("scratch_reduce_motion", false))
	surface.draw_rect(all_rect, Color("#613047") if not reduced else Color("#17644c"))
	surface.draw_rect(all_rect, C_PINK if not reduced else Color("#69efb3"), false, 2)
	surface.surface_label_centered("SCRATCH ALL", all_rect, 7, C_WHITE)
	surface.surface_add_hit(all_rect, SCRATCH_ALL_ACTION, 0)


func _draw_section_status(surface, ticket: Dictionary, accent: Color, trim: Color) -> void:
	var sections := _array_ref(ticket.get("sections", []))
	if sections.is_empty():
		return
	var gap := 3.0
	var width := (active_scratch_rect.size.x - gap * float(sections.size() - 1)) / float(sections.size())
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		var rect := Rect2(active_scratch_rect.position + Vector2(float(index) * (width + gap), -13), Vector2(width, 10))
		var coverage := clampf(float(section.get("coverage", 0.0)), 0.0, 1.0)
		surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.28))
		surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x * coverage, rect.size.y)), trim if bool(section.get("revealed", false)) else Color(accent.r, accent.g, accent.b, 0.70))
		surface.surface_label_centered("%s %d%%" % [str(section.get("label", "AREA")).left(9), int(round(coverage * 100.0))], rect, 5, C_WHITE)


func _draw_mini_scratch_ticket(surface, ticket: Dictionary, rect: Rect2, alpha: float) -> void:
	var face := _dict_ref(ticket.get("face", {}))
	var palette := _dict_ref(face.get("palette", ticket.get("palette", {})))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.0, 0.0, 0.0, 0.18 * alpha))
	surface.draw_rect(rect, Color(paper.r, paper.g, paper.b, alpha))
	surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(7.0, rect.size.y * 0.24))), Color(accent.r, accent.g, accent.b, alpha))
	surface.surface_label(str(ticket.get("display_name", "TICKET")).to_upper().left(12), rect.position + Vector2(4, minf(16.0, rect.size.y * 0.44)), 6, Color(ink.r, ink.g, ink.b, alpha))
	for mark in range(3):
		surface.draw_circle(rect.position + Vector2(rect.size.x * (0.35 + mark * 0.20), rect.size.y * 0.72), maxf(2.0, rect.size.y * 0.08), Color(accent.r, accent.g, accent.b, 0.45 * alpha))


func _draw_dispense_animation(surface, state: Dictionary) -> void:
	if not bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		return
	var ticket := _dict_ref(state.get("scratch_ticket", {}))
	if ticket.is_empty():
		return
	var slot := clampi(int(surface.surface_animation_metadata(DISPENSE_CHANNEL).get("slot", 0)), 0, 3)
	var progress := _ease_out_cubic(surface.surface_animation_progress(DISPENSE_CHANNEL))
	var source := MACHINE_RECT.position + Vector2(170, 106 + slot * 59)
	var chute := MACHINE_RECT.position + Vector2(MACHINE_RECT.size.x * 0.5, 381)
	var target := active_ticket_rect.get_center()
	var position := source.lerp(chute, clampf(progress * 2.0, 0.0, 1.0)) if progress < 0.5 else chute.lerp(target, clampf((progress - 0.5) * 2.0, 0.0, 1.0))
	var size := Vector2(80, 56).lerp(active_ticket_rect.size * 0.82, progress)
	_draw_mini_scratch_ticket(surface, ticket, Rect2(position - size * 0.5, size), 1.0)
	surface.draw_rect(Rect2(position - size * 0.5, size).grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.25 * (1.0 - progress)), false, 3)


func _draw_file_animation(surface, state: Dictionary) -> void:
	if not bool(surface.surface_animation_active(FILE_CHANNEL)):
		return
	var ticket := _dict_ref(state.get("scratch_last_settled_ticket", {}))
	if ticket.is_empty():
		return
	var progress := _ease_in_out_cubic(surface.surface_animation_progress(FILE_CHANNEL))
	var winner := str(state.get("scratch_last_settled_pile", "")) == "winner_pile"
	var width: float = 110.0
	var target: Vector2 = STATUS_HUD_RECT.position + Vector2(294.0, 2.0) if winner else STATUS_HUD_RECT.position + Vector2(382.0, 2.0)
	var source := active_ticket_rect.position + Vector2(24, 72)
	var position := source.lerp(target, progress)
	var size := Vector2(244, 280).lerp(Vector2(width - 22, 38), progress)
	_draw_mini_scratch_ticket(surface, ticket, Rect2(position, size), 1.0 - progress * 0.25)


func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


func _ease_in_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


func _xray_peeks(ticket: Dictionary, count: int, rng: RngStream) -> Array:
	var spots := _dictionary_array(ticket.get("spots", []))
	var available := range(spots.size())
	var result: Array = []
	while not available.is_empty() and result.size() < maxi(0, count):
		var pick_index := rng.randi_range(0, available.size() - 1)
		var cell_index := int(available[pick_index])
		available.remove_at(pick_index)
		var spot: Dictionary = spots[cell_index]
		var value := str(spot.get("symbol", spot.get("number", spot.get("letter", spot.get("card", spot.get("mark", spot.get("word", "?")))))))
		result.append({"index": cell_index, "symbol": value, "section_id": str(spot.get("section_id", ""))})
	return result


func _fortune_tier(ticket: Dictionary) -> String:
	var payout := maxi(0, int(ticket.get("payout", 0)))
	var price := maxi(1, int(ticket.get("price", 1)))
	if payout <= 0:
		return "cold"
	return "hot" if payout >= price * 5 else "warm"


func _stock_view(machine: Dictionary) -> Array:
	var result: Array = []
	for value in _dictionary_array(machine.get("stock", [])):
		result.append((value as Dictionary).duplicate(true))
	return result


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var states := _game_states_for_write(environment)
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		var machine := value as Dictionary
		_sync_portable_ticket_state(run_state, environment, machine)
		return machine
	var generated := _generate_machine_state(run_state, environment, null)
	_sync_portable_ticket_state(run_state, environment, generated)
	if persist:
		states[get_id()] = generated
		environment["game_states"] = states
	return generated


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) == TYPE_DICTIONARY:
		var value: Variant = (states_value as Dictionary).get(get_id(), {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			var machine := value as Dictionary
			_sync_portable_ticket_state(run_state, environment, machine)
			return machine
	var generated := _generate_machine_state(run_state, environment, null)
	_sync_portable_ticket_state(run_state, environment, generated)
	return generated


func _write_machine_state(environment: Dictionary, machine: Dictionary, run_state: RunState = null) -> void:
	var states := _game_states_for_write(environment)
	states[get_id()] = machine
	environment["game_states"] = states
	if run_state != null:
		run_state.remember_portable_ticket_state(get_id(), environment, _portable_ticket_player_state(machine))


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
	for field in ["active_ticket", "winner_pile", "loser_pile", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			machine[field] = portable[field]


func _portable_ticket_player_state(machine: Dictionary) -> Dictionary:
	return {
		"active_ticket": machine.get("active_ticket", {}),
		"winner_pile": machine.get("winner_pile", []),
		"loser_pile": machine.get("loser_pile", []),
		"pending_penalty": maxi(0, int(machine.get("pending_penalty", 0))),
		"penalty_shields_remaining": maxi(0, int(machine.get("penalty_shields_remaining", 0))),
		"last_settled_ticket": _copy_dict(machine.get("last_settled_ticket", {})),
		"last_settled_pile": str(machine.get("last_settled_pile", "")),
		"last_file_id": str(machine.get("last_file_id", "")),
		"file_started_msec": maxi(0, int(machine.get("file_started_msec", 0))),
		"last_sweep_id": str(machine.get("last_sweep_id", "")),
		"last_sweep_section": str(machine.get("last_sweep_section", "")),
		"sweep_started_msec": maxi(0, int(machine.get("sweep_started_msec", 0))),
	}


func _portable_ticket_count(state: Dictionary) -> int:
	return (0 if _copy_dict(state.get("active_ticket", {})).is_empty() else 1) + _dictionary_array(state.get("winner_pile", [])).size() + _dictionary_array(state.get("loser_pile", [])).size()


func _stamp_ticket_origin(ticket: Dictionary, environment: Dictionary) -> void:
	if ticket.is_empty():
		return
	ticket["origin_key"] = RunState.portable_ticket_origin_key(environment)
	ticket["origin_name"] = RunState.portable_ticket_origin_name(environment)
	ticket["origin_environment_id"] = str(environment.get("id", "")).strip_edges()
	ticket["origin_world_node_id"] = str(environment.get("world_node_id", "")).strip_edges()


func _stamp_machine_ticket_origins(machine: Dictionary, environment: Dictionary) -> void:
	var active_value: Variant = machine.get("active_ticket", {})
	if typeof(active_value) == TYPE_DICTIONARY:
		_stamp_ticket_origin(active_value as Dictionary, environment)
	for field in ["winner_pile", "loser_pile"]:
		for ticket_value in _dictionary_array(machine.get(field, [])):
			_stamp_ticket_origin(ticket_value as Dictionary, environment)


func _game_states_for_write(environment: Dictionary) -> Dictionary:
	var value: Variant = environment.get("game_states", {})
	return (value as Dictionary).duplicate(false) if typeof(value) == TYPE_DICTIONARY else {}


func _ticket_types() -> Array:
	if library != null:
		return _dictionary_array(library.scratch_ticket_types)
	return []


func _ticket_type(type_id: String) -> Dictionary:
	for value in _ticket_types():
		var ticket_type: Dictionary = value
		if str(ticket_type.get("id", "")) == type_id:
			return ticket_type
	return {}


func _pending_payout(machine: Dictionary) -> int:
	var total := 0
	for value in _dictionary_array(machine.get("winner_pile", [])):
		total += maxi(0, int((value as Dictionary).get("payout", 0)))
	return total


func _ticket_complete(ticket: Dictionary) -> bool:
	var sections_value: Variant = ticket.get("sections", [])
	if typeof(sections_value) == TYPE_ARRAY and not (sections_value as Array).is_empty():
		for section_value in sections_value as Array:
			if typeof(section_value) != TYPE_DICTIONARY or not bool((section_value as Dictionary).get("revealed", false)):
				return false
		return true
	return false


func _ticket_scratch_rect(_ticket: Dictionary) -> Rect2:
	var size_id := str(_ticket.get("size_id", "medium_square"))
	var rect := _ticket_rect_for_size(size_id, false)
	return _scratch_rect_for_ticket_rect(size_id, rect)


func _ticket_rect_for_size(size_id: String, _compact: bool = false) -> Rect2:
	var size := Vector2(354, 356)
	match size_id:
		"small_rectangle": size = Vector2(500, 224)
		"medium_square": size = Vector2(354, 356)
		"large_rectangle": size = Vector2(548, 356)
		"tall": size = Vector2(292, 366)
	return Rect2(PLAY_SURFACE_RECT.get_center() - size * 0.5, size)


func _size_orientation(size_id: String) -> String:
	match size_id:
		"small_rectangle": return "wide_short"
		"medium_square": return "balanced"
		"large_rectangle": return "wide_tall"
		"tall": return "narrow_tall"
	return "balanced"


func _scratch_rect_for_ticket_rect(size_id: String, rect: Rect2) -> Rect2:
	var header := 100.0
	var footer := 69.0
	var side := 22.0
	if size_id == "small_rectangle":
		header = 76.0
		footer = 49.0
		side = 24.0
	elif size_id == "tall":
		side = 18.0
	return Rect2(rect.position + Vector2(side, header), Vector2(rect.size.x - side * 2.0, rect.size.y - header - footer))


func _configure_active_ticket_layout(ticket: Dictionary, compact: bool) -> void:
	var size_id := str(ticket.get("size_id", "medium_square")) if not ticket.is_empty() else "medium_square"
	active_ticket_rect = _ticket_rect_for_size(size_id, compact)
	active_scratch_rect = _scratch_rect_for_ticket_rect(size_id, active_ticket_rect)


func _mask_sample_normalized(sample_index: int, columns: int, rows: int) -> Vector2:
	return Vector2((float(sample_index % columns) + 0.5) / float(columns), (float(sample_index / columns) + 0.5) / float(rows))


func _normalized_rect_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 4:
		return [0.0, 0.0, 1.0, 1.0]
	var source := value as Array
	return [clampf(float(source[0]), 0.0, 1.0), clampf(float(source[1]), 0.0, 1.0), clampf(float(source[2]), 0.01, 1.0), clampf(float(source[3]), 0.01, 1.0)]


func _section_index_at_normalized(sections: Array, normalized: Vector2) -> int:
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		var values: Array = section.get("rect", []) if typeof(section.get("rect", [])) == TYPE_ARRAY else []
		if values.size() < 4:
			continue
		var rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		if rect.has_point(normalized):
			return index
	return -1


func _clear_mask_section(mask: Array, sections: Array, section_index: int, columns: int, rows: int) -> void:
	for sample_index in range(mask.size()):
		if int(mask[sample_index]) <= 0:
			continue
		if _section_index_at_normalized(sections, _mask_sample_normalized(sample_index, columns, rows)) == section_index:
			mask[sample_index] = 0


func _reduce_motion_enabled(ui_state: Dictionary) -> bool:
	if bool(ui_state.get("reduce_motion", false)):
		return true
	var runtime: Dictionary = ui_state.get("surface_runtime_status", {}) if typeof(ui_state.get("surface_runtime_status", {})) == TYPE_DICTIONARY else {}
	return bool(runtime.get("reduce_motion", false))


func _small_screen_enabled(ui_state: Dictionary) -> bool:
	if bool(ui_state.get("small_screen", false)):
		return true
	var runtime: Dictionary = ui_state.get("surface_runtime_status", {}) if typeof(ui_state.get("surface_runtime_status", {})) == TYPE_DICTIONARY else {}
	return bool(runtime.get("small_screen_mode", false))


func _scratch_animation_channels(machine: Dictionary, reduce_motion: bool) -> Array:
	return [
		GameModule.surface_animation_channel(DISPENSE_CHANNEL, str(machine.get("last_dispense_id", "")), DISPENSE_DURATION_MSEC, int(machine.get("dispense_started_msec", 0)), {"metadata": {"ticket_id": str(_copy_dict(machine.get("active_ticket", {})).get("id", "")), "slot": int(machine.get("last_dispense_slot", 0))}}),
		GameModule.surface_animation_channel(FILE_CHANNEL, str(machine.get("last_file_id", "")), FILE_DURATION_MSEC, int(machine.get("file_started_msec", 0)), {"metadata": {"pile": str(machine.get("last_settled_pile", ""))}}),
		GameModule.surface_animation_channel(SWEEP_CHANNEL, str(machine.get("last_sweep_id", "")), 0 if reduce_motion else SWEEP_DURATION_MSEC, int(machine.get("sweep_started_msec", 0)), {"metadata": {"section": str(machine.get("last_sweep_section", ""))}}),
	]


func _distance_squared_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var delta := to - from
	var length_squared := delta.length_squared()
	if length_squared <= 0.0001:
		return point.distance_squared_to(from)
	var t := clampf((point - from).dot(delta) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(from + delta * t)


func _crumbs_for_segment(from: Vector2, to: Vector2, erased_samples: int) -> Array:
	var result: Array = []
	var count := mini(8, maxi(2, erased_samples / 3))
	for index in range(count):
		var t := float(index + 1) / float(count + 1)
		var point := from.lerp(to, t)
		result.append({"x": point.x + float((index % 3) - 1) * 4.0, "y": point.y + float((index % 2) * 2 - 1) * 5.0, "r": 1.5 + float(index % 2)})
	return result


func _scratch_empty_result(action_id: String, environment: Dictionary, message: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "legal",
		"stake": 0,
		"bankroll_delta": 0,
		"deltas": GameModule.empty_result_deltas(),
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})


func _seeded_rng(stream_key: String) -> RngStream:
	var rng := RngStream.new()
	var seed := RunState.text_to_seed(stream_key)
	rng.configure(seed, seed)
	return rng


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


func _dict_ref(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array_ref(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(str(entry))
	return result


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(int(entry))
	return result
