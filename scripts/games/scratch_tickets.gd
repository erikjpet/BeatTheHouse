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
const TICKET_RECT := Rect2(316, 13, 332, 404)
const GRID_RECT := Rect2(338, 150, 288, 188)
const PILES_RECT := Rect2(664, 196, 218, 221)
const BIG_WIN_THRESHOLD := 100
const STOCK_SLOT_COUNT := 4
const COLLECTION_TOTAL := 10
const DEFAULT_BRUSH_RADIUS := 15.0
const DEFAULT_PASS_REMOVAL := 0.66
const DEFAULT_SWEEP_THRESHOLD := 0.80
const DEFAULT_MASK_COLUMNS := 48
const DEFAULT_MASK_ROWS := 32


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
	var sweep_duration := 0 if reduce_motion else SWEEP_DURATION_MSEC
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
		"scratch_winner_count": _dictionary_array(machine.get("winner_pile", [])).size(),
		"scratch_loser_count": _dictionary_array(machine.get("loser_pile", [])).size(),
		"scratch_winner_pile": _dictionary_array(machine.get("winner_pile", [])).duplicate(true),
		"scratch_loser_pile": _dictionary_array(machine.get("loser_pile", [])).duplicate(true),
		"scratch_last_settled_ticket": _copy_dict(machine.get("last_settled_ticket", {})),
		"scratch_last_settled_pile": str(machine.get("last_settled_pile", "")),
		"scratch_machine_style": "physical_lottery_vending_cabinet",
		"scratch_ticket_face_style": "portrait_printed_lottery_ticket",
		"scratch_dispense_animation": not last_dispense_id.is_empty(),
		"scratch_crumbs": crumbs,
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_reduce_motion": reduce_motion,
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
			{"x": TICKET_RECT.position.x, "y": TICKET_RECT.position.y, "w": TICKET_RECT.size.x, "h": TICKET_RECT.size.y},
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
	_draw_machine(surface, state)
	_draw_ticket(surface, state)
	_draw_sorted_piles(surface, state)
	_draw_dispense_animation(surface, state)
	_draw_file_animation(surface, state)
	return true


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	match surface_action:
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
	var prize := _weighted_prize(ticket_type, rng, luck_modifier)
	var grid := _copy_dict(ticket_type.get("grid", {}))
	var columns := maxi(1, int(grid.get("columns", 3)))
	var rows := maxi(1, int(grid.get("rows", 3)))
	var symbols := _simulated_symbols(ticket_type, prize, columns, rows, rng)
	var penalty := _simulated_penalty(ticket_type, symbols, rng)
	return {
		"type_id": type_id,
		"price": int(ticket_type.get("price", 0)),
		"payout": int(prize.get("payout", 0)),
		"penalty": penalty,
		"net_return": int(prize.get("audit_return", prize.get("payout", 0))) - penalty,
		"symbols": symbols,
	}


func _simulated_symbols(ticket_type: Dictionary, prize: Dictionary, columns: int, rows: int, rng: RngStream) -> Array:
	var pool := _string_array(ticket_type.get("symbol_pool", []))
	if pool.is_empty():
		pool = ["STAR", "BAR", "BELL", "7"]
	var symbols: Array = []
	for _index in range(columns * rows):
		symbols.append(str(rng.pick(pool, "STAR")))
	var winning_symbol := str(prize.get("winning_symbol", ""))
	var protected: Dictionary = {}
	if not winning_symbol.is_empty() and symbols.size() >= 3:
		var row := rng.randi_range(0, rows - 1)
		for column in range(mini(3, columns)):
			var index := row * columns + column
			symbols[index] = winning_symbol
			protected[index] = true
	else:
		_break_accidental_matches(symbols, columns, rows, rng, pool)
	var gimmick := _copy_dict(ticket_type.get("gimmick", {}))
	if str(gimmick.get("type", "")) == "shock_penalty":
		var chance := clampi(int(gimmick.get("penalty_chance_percent", 0)), 0, 100)
		for index in range(symbols.size()):
			if not protected.has(index) and rng.randi_range(1, 100) <= chance:
				symbols[index] = str(gimmick.get("penalty_symbol", "SHOCK"))
	return symbols


func _simulated_penalty(ticket_type: Dictionary, symbols: Array, rng: RngStream) -> int:
	var gimmick := _copy_dict(ticket_type.get("gimmick", {}))
	var penalty_symbol := str(gimmick.get("penalty_symbol", "SHOCK"))
	var amount := _int_array(gimmick.get("penalty_amount", [1, 1]))
	var minimum := int(amount[0]) if not amount.is_empty() else 1
	var maximum := int(amount[1]) if amount.size() > 1 else minimum
	var total := 0
	for symbol_value in symbols:
		if str(symbol_value) == penalty_symbol:
			total += rng.randi_range(minimum, maximum)
	return total


func measure_rtp(type_id: String, samples: int = 20000, seed_text: String = "SCRATCH-RTP") -> Dictionary:
	var ticket_type := _ticket_type(type_id)
	var table := _dictionary_array(ticket_type.get("prize_table", []))
	var total_weight := 0
	for entry_value in table:
		total_weight += maxi(0, int((entry_value as Dictionary).get("weight", 0)))
	var grid := _copy_dict(ticket_type.get("grid", {}))
	var cell_count := maxi(1, int(grid.get("columns", 3)) * int(grid.get("rows", 3)))
	var gimmick := _copy_dict(ticket_type.get("gimmick", {}))
	var shock := str(gimmick.get("type", "")) == "shock_penalty"
	var shock_chance := clampi(int(gimmick.get("penalty_chance_percent", 0)), 0, 100)
	var shock_amount := _int_array(gimmick.get("penalty_amount", [1, 1]))
	var shock_minimum := int(shock_amount[0]) if not shock_amount.is_empty() else 1
	var shock_maximum := int(shock_amount[1]) if shock_amount.size() > 1 else shock_minimum
	var losing_penalty_lookup := _penalty_lookup(_penalty_distribution(cell_count, shock_chance, shock_minimum, shock_maximum)) if shock else []
	var winning_penalty_lookup := _penalty_lookup(_penalty_distribution(maxi(0, cell_count - 3), shock_chance, shock_minimum, shock_maximum)) if shock else []
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
		var winning := false
		for entry_value in table:
			var entry: Dictionary = entry_value
			cursor += maxi(0, int(entry.get("weight", 0)))
			if roll <= cursor:
				payout = maxi(0, int(entry.get("audit_return", entry.get("payout", 0))))
				winning = not str(entry.get("winning_symbol", "")).is_empty()
				break
		var penalty := 0
		if shock:
			stream_state = int((stream_state * RngStream.MULTIPLIER) % RngStream.MODULUS)
			var lookup: Array = winning_penalty_lookup if winning else losing_penalty_lookup
			penalty = int(lookup[int(stream_state % lookup.size())])
		total_cost += price
		total_return += payout - penalty
	return {
		"type_id": type_id,
		"samples": maxi(1, samples),
		"cost": total_cost,
		"return": total_return,
		"rtp": float(total_return) / float(maxi(1, total_cost)),
	}


func _penalty_distribution(cell_count: int, chance_percent: int, minimum: int, maximum: int) -> Array:
	var probabilities: Array = [1.0]
	var amount_count := maxi(1, maximum - minimum + 1)
	var hit_probability := clampf(float(chance_percent) / 100.0, 0.0, 1.0)
	var amount_probability := hit_probability / float(amount_count)
	for _cell in range(maxi(0, cell_count)):
		var next: Array = []
		for _index in range(probabilities.size() + maximum):
			next.append(0.0)
		for total in range(probabilities.size()):
			var probability := float(probabilities[total])
			next[total] = float(next[total]) + probability * (1.0 - hit_probability)
			for amount in range(minimum, maximum + 1):
				next[total + amount] = float(next[total + amount]) + probability * amount_probability
		probabilities = next
	return probabilities


func _sample_penalty_distribution(probabilities: Array, rng: RngStream) -> int:
	if probabilities.is_empty():
		return 0
	var roll := float(rng.randi_range(1, 1000000)) / 1000000.0
	var cumulative := 0.0
	for penalty in range(probabilities.size()):
		cumulative += float(probabilities[penalty])
		if roll <= cumulative:
			return penalty
	return probabilities.size() - 1


func _penalty_lookup(probabilities: Array, slots: int = 10000) -> Array:
	var result: Array = []
	var cumulative := 0.0
	var penalty := 0
	for slot in range(maxi(1, slots)):
		var target := (float(slot) + 0.5) / float(maxi(1, slots))
		while penalty < probabilities.size() - 1 and target > cumulative + float(probabilities[penalty]):
			cumulative += float(probabilities[penalty])
			penalty += 1
		result.append(penalty)
	return result


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
	result["scratch_ticket"] = ticket.duplicate(true)
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
	var pending_penalty := maxi(0, int(machine.get("pending_penalty", 0)))
	machine["pending_penalty"] = 0
	var penalty_paid := mini(pending_penalty, maxi(0, run_state.bankroll)) if run_state != null else pending_penalty
	var payout := int(ticket.get("payout", 0))
	var settle_heat := 0
	var free_ticket: Dictionary = {}
	var luck_buff := 0
	var message := "A SHOCK symbol zaps $%d." % penalty_paid if penalty_paid > 0 else "The printed symbol comes clean."
	if settle:
		if not _ticket_complete(ticket):
			return _scratch_empty_result(SETTLE_ACTION, environment, "Some latex still covers this ticket.")
		ticket["settled"] = true
		ticket["penalty_paid"] = int(ticket.get("penalty_paid", 0)) + penalty_paid
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
		var gimmick := _copy_dict(ticket.get("gimmick", {}))
		if str(gimmick.get("type", "")) == "devils_cut" and int(ticket.get("cut", 0)) > 0:
			settle_heat = maxi(0, int(gimmick.get("heat", 0)))
			message += " The DEVIL keeps $%d from the printed $%d and draws +%d heat." % [int(ticket.get("cut", 0)), int(ticket.get("gross_payout", payout)), settle_heat]
		luck_buff = maxi(0, int(ticket.get("luck_buff", 0)))
		if luck_buff > 0 and run_state != null:
			var luck_turns := maxi(1, int(ticket.get("luck_turns", 1)))
			var current_turn := maxi(0, int(run_state.current_environment.get("turns", 0)))
			run_state.narrative_flags["scratch_midnight_luck_bonus"] = luck_buff
			run_state.narrative_flags["scratch_midnight_luck_expires_turn"] = current_turn + luck_turns + 1
			message += " Midnight luck rises +%d for %d turns." % [luck_buff, luck_turns]
		if payout <= 0 and bool(ticket.get("second_chance", false)):
			var free_type := _ticket_type(str(gimmick.get("free_type_id", "lucky_7s")))
			if not free_type.is_empty():
				free_ticket = _roll_ticket(free_type, rng.fork("second-chance:%s" % str(ticket.get("id", "ticket"))), run_state.effective_luck() if run_state != null else 0, "free:%s" % str(ticket.get("id", "ticket")))
				free_ticket["price"] = 0
				free_ticket["free_ticket"] = true
				_stamp_ticket_origin(free_ticket, environment)
				machine["active_ticket"] = free_ticket
				message += " SECOND CHANCE immediately dispenses a free Lucky 7s."
		if penalty_paid > 0:
			message += " SHOCK symbols already took $%d." % penalty_paid
	_write_machine_state(environment, machine, run_state)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -penalty_paid
	deltas["suspicion_delta"] = settle_heat
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "scratch_ticket_settle" if settle else "scratch_ticket_reveal",
		"game_id": get_id(),
		"action_id": SETTLE_ACTION if settle else REVEAL_ACTION,
		"ticket_id": str(ticket.get("id", "")),
		"ticket_type": str(ticket.get("type_id", "")),
		"pending_clerk_payout": payout if settle else 0,
		"penalty": penalty_paid,
		"devils_cut_heat": settle_heat,
		"luck_buff": luck_buff,
		"second_chance_dispensed": not free_ticket.is_empty(),
		"bankroll_delta": -penalty_paid,
		"suspicion_delta": settle_heat,
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
		"bankroll_delta": -penalty_paid,
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
	result["scratch_second_chance_ticket"] = free_ticket.duplicate(true)
	result["scratch_luck_buff"] = luck_buff
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
	var machine_rng := rng if rng != null else _seeded_rng("scratch-stock:%s:day:%d" % [str(environment.get("id", "room")), day_key])
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
			"palette": _copy_dict(_copy_dict(ticket_type.get("face", {})).get("palette", {})),
		})
	return {
		"schema": "scratch_ticket_machine_state",
		"version": 1,
		"machine_name": "Highway Scratch Center",
		"stock_day": int(environment.get("generated_day", environment.get("day", 0))),
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
	var columns := maxi(1, int(_copy_dict(ticket_type.get("grid", {})).get("columns", 3)))
	var rows := maxi(1, int(_copy_dict(ticket_type.get("grid", {})).get("rows", 3)))
	var cells := _build_cells(ticket_type, prize, columns, rows, rng)
	var ticket_id := "%s:%s:%s" % [str(ticket_type.get("id", "ticket")), purchase_key, str(rng.randi_range(100000, 999999))]
	var ticket := {
		"id": ticket_id,
		"type_id": str(ticket_type.get("id", "")),
		"display_name": str(ticket_type.get("display_name", "Scratch Ticket")),
		"price": maxi(1, int(ticket_type.get("price", 1))),
		"face": _copy_dict(ticket_type.get("face", {})),
		"grid": {"columns": columns, "rows": rows},
		"gimmick": _copy_dict(ticket_type.get("gimmick", {})),
		"scratch": _copy_dict(ticket_type.get("scratch", {})),
		"outcome_id": str(prize.get("id", "blank")),
		"payout": maxi(0, int(prize.get("payout", 0))),
		"outcome": prize.duplicate(true),
		"gross_payout": maxi(0, int(prize.get("gross_payout", prize.get("payout", 0)))),
		"cut": maxi(0, int(prize.get("cut", 0))),
		"second_chance": bool(prize.get("second_chance", false)),
		"audit_return": maxi(0, int(prize.get("audit_return", prize.get("payout", 0)))),
		"multiplier_symbol": str(prize.get("multiplier_symbol", "")),
		"winning_word": str(prize.get("winning_word", "")),
		"luck_buff": maxi(0, int(prize.get("luck_buff", 0))),
		"luck_turns": maxi(0, int(prize.get("luck_turns", 0))),
		"cells": cells,
		"outcome_fixed_at_purchase": true,
		"luck_modifier": luck_modifier,
		"settled": false,
		"penalty_paid": 0,
	}
	_initialize_ticket_mask(ticket, ticket_type)
	return ticket


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
	for sample_index in range(mask.size()):
		var normalized := _mask_sample_normalized(sample_index, mask_columns, mask_rows)
		var section_index := _section_index_at_normalized(sections, normalized)
		mask[sample_index] = 255 if section_index >= 0 else 0
		if section_index >= 0:
			var section: Dictionary = sections[section_index]
			section["sample_total"] = int(section.get("sample_total", 0)) + 1
			section["mask_remaining_units"] = int(section.get("mask_remaining_units", 0)) + 255
			sections[section_index] = section
	ticket["sections"] = sections
	ticket["latex_mask"] = mask
	ticket["mask_revision"] = 0


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


func _build_cells(ticket_type: Dictionary, prize: Dictionary, columns: int, rows: int, rng: RngStream) -> Array:
	var pool := _string_array(ticket_type.get("symbol_pool", []))
	if pool.is_empty():
		pool = ["STAR", "BAR", "BELL", "7"]
	var total := columns * rows
	var symbols: Array = []
	for _index in range(total):
		symbols.append(str(rng.pick(pool, "STAR")))
	var winning_symbol := str(prize.get("winning_symbol", ""))
	var winning_word := str(prize.get("winning_word", ""))
	var protected: Dictionary = {}
	if not winning_word.is_empty() and columns >= winning_word.length():
		for column in range(mini(columns, winning_word.length())):
			symbols[column] = winning_word.substr(column, 1)
			protected[column] = true
	elif not winning_symbol.is_empty() and total >= 3:
		var row := rng.randi_range(0, rows - 1)
		for column in range(mini(3, columns)):
			var index := row * columns + column
			symbols[index] = winning_symbol
			protected[index] = true
	else:
		_break_accidental_matches(symbols, columns, rows, rng, pool)
	var gimmick := _copy_dict(ticket_type.get("gimmick", {}))
	var gimmick_type := str(gimmick.get("type", ""))
	if gimmick_type == "multiplier_lines" and not str(prize.get("multiplier_symbol", "")).is_empty():
		_place_special_symbol(symbols, protected, str(prize.get("multiplier_symbol", "")))
	elif gimmick_type == "bonus_box" and not winning_symbol.is_empty():
		_place_special_symbol(symbols, protected, str(gimmick.get("bonus_symbol", "BONUS")))
	elif gimmick_type == "second_chance" and bool(prize.get("second_chance", false)):
		_place_special_symbol(symbols, protected, "FREE")
	elif gimmick_type == "devils_cut" and int(prize.get("cut", 0)) > 0:
		_place_special_symbol(symbols, protected, str(gimmick.get("devil_symbol", "DEVIL")))
	elif gimmick_type == "rare_luck" and int(prize.get("luck_buff", 0)) > 0:
		_place_special_symbol(symbols, protected, str(gimmick.get("rare_symbol", "RARE")))
	if str(gimmick.get("type", "")) == "shock_penalty":
		var chance := clampi(int(gimmick.get("penalty_chance_percent", 0)), 0, 100)
		for index in range(total):
			if protected.has(index):
				continue
			if rng.randi_range(1, 100) <= chance:
				symbols[index] = str(gimmick.get("penalty_symbol", "SHOCK"))
	var scratch := _copy_dict(ticket_type.get("scratch", {}))
	var mask_columns := maxi(2, int(scratch.get("mask_columns", 6)))
	var mask_rows := maxi(2, int(scratch.get("mask_rows", 4)))
	var cells: Array = []
	for index in range(total):
		var symbol := str(symbols[index])
		var penalty := 0
		if symbol == str(gimmick.get("penalty_symbol", "SHOCK")):
			var amount := _int_array(gimmick.get("penalty_amount", [1, 1]))
			var minimum := int(amount[0]) if not amount.is_empty() else 1
			var maximum := int(amount[1]) if amount.size() > 1 else minimum
			penalty = rng.randi_range(minimum, maximum)
		var mask: Array = []
		for _sample in range(mask_columns * mask_rows):
			mask.append(1)
		var role := "bonus_area" if symbol == str(gimmick.get("bonus_symbol", "BONUS")) else "play_area"
		cells.append({"index": index, "symbol": symbol, "role": role, "penalty": penalty, "penalty_queued": false, "penalty_shielded": false, "revealed": false, "mask": mask, "mask_remaining": mask.size(), "scratched_ratio": 0.0})
	return cells


func _place_special_symbol(symbols: Array, protected: Dictionary, symbol: String) -> void:
	for index in range(symbols.size() - 1, -1, -1):
		if not protected.has(index):
			symbols[index] = symbol
			protected[index] = true
			return


func _reserve_penalty_shields(ticket: Dictionary, count: int) -> void:
	var cells := _dictionary_array(ticket.get("cells", []))
	var remaining := maxi(0, count)
	for cell_value in cells:
		var cell: Dictionary = cell_value
		cell["penalty_shield_reserved"] = int(cell.get("penalty", 0)) > 0 and remaining > 0
		if bool(cell.get("penalty_shield_reserved", false)):
			remaining -= 1
	ticket["cells"] = cells


func _break_accidental_matches(symbols: Array, columns: int, rows: int, rng: RngStream, pool: Array) -> void:
	if columns < 3:
		return
	for row in range(rows):
		var start := row * columns
		if str(symbols[start]) == str(symbols[start + 1]) and str(symbols[start]) == str(symbols[start + 2]):
			var replacement := str(rng.pick(pool, "STAR"))
			while replacement == str(symbols[start]) and pool.size() > 1:
				replacement = str(rng.pick(pool, "STAR"))
			symbols[start + 2] = replacement


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
	if not swept_sections.is_empty():
		_reveal_legacy_cells_for_completed_ticket_sections(ticket)
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
	var cells := _dictionary_array(ticket.get("cells", []))
	var penalty := 0
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		cell["revealed"] = true
		cell["scratched_ratio"] = 1.0
		cell["mask"] = _zero_mask(_int_array(cell.get("mask", [])).size())
		cell["mask_remaining"] = 0
		if int(cell.get("penalty", 0)) > 0 and not bool(cell.get("penalty_queued", false)):
			cell["penalty_queued"] = true
			if bool(cell.get("penalty_shield_reserved", false)) and int(machine.get("penalty_shields_remaining", 0)) > 0:
				machine["penalty_shields_remaining"] = int(machine.get("penalty_shields_remaining", 0)) - 1
				cell["penalty_shielded"] = true
			else:
				penalty += int(cell.get("penalty", 0))
		var gimmick := _copy_dict(ticket.get("gimmick", {}))
		if str(gimmick.get("type", "")) == "bonus_box" and str(cell.get("symbol", "")) == str(gimmick.get("key_symbol", "KEY")):
			ticket["bonus_unlocked"] = true
		cells[index] = cell
	ticket["cells"] = cells
	machine["active_ticket"] = ticket
	machine["pending_penalty"] = int(machine.get("pending_penalty", 0)) + penalty


func _draw_machine(surface, state: Dictionary) -> void:
	var shadow := Rect2(MACHINE_RECT.position + Vector2(7, 6), MACHINE_RECT.size)
	surface.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.36))
	surface.draw_polygon([
		MACHINE_RECT.position + Vector2(10, 0), MACHINE_RECT.position + Vector2(MACHINE_RECT.size.x - 12, 0),
		MACHINE_RECT.position + Vector2(MACHINE_RECT.size.x, 13), MACHINE_RECT.end - Vector2(0, 13),
		MACHINE_RECT.end - Vector2(12, 0), MACHINE_RECT.position + Vector2(12, MACHINE_RECT.size.y),
		MACHINE_RECT.position + Vector2(0, MACHINE_RECT.size.y - 15), MACHINE_RECT.position + Vector2(0, 14),
	], [Color("#b61f2b")])
	surface.draw_rect(Rect2(MACHINE_RECT.position + Vector2(9, 10), Vector2(MACHINE_RECT.size.x - 18, 56)), Color("#e8343e"))
	surface.draw_rect(Rect2(MACHINE_RECT.position + Vector2(15, 72), Vector2(MACHINE_RECT.size.x - 30, 236)), Color("#171822"))
	surface.draw_rect(Rect2(MACHINE_RECT.position + Vector2(19, 76), Vector2(MACHINE_RECT.size.x - 38, 228)), Color("#080a0f"))
	surface.surface_label_centered("HIGHWAY LOTTERY", Rect2(MACHINE_RECT.position + Vector2(16, 18), Vector2(MACHINE_RECT.size.x - 32, 22)), 18, C_WHITE)
	surface.surface_label_centered("SCRATCH TICKET CENTER", Rect2(MACHINE_RECT.position + Vector2(16, 42), Vector2(MACHINE_RECT.size.x - 32, 15)), 10, C_YELLOW)
	var stock := _dictionary_array(state.get("scratch_stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		var column := index % 2
		var row := index / 2
		var rect := Rect2(MACHINE_RECT.position + Vector2(26 + column * 119, 82 + row * 108), Vector2(108, 96))
		_draw_vending_window(surface, slot, rect, index)
		if int(slot.get("remaining", 0)) > 0:
			surface.surface_add_hit(rect, "scratch_buy", index)
	var control := Rect2(MACHINE_RECT.position + Vector2(20, 317), Vector2(MACHINE_RECT.size.x - 40, 28))
	surface.draw_rect(control, Color("#66121d"))
	surface.draw_rect(control, Color("#ff5964"), false, 2)
	surface.surface_label("DISPENSE", control.position + Vector2(10, 19), 11, C_WHITE)
	for light_index in range(4):
		surface.draw_circle(control.position + Vector2(105 + light_index * 21, 14), 4, Color("#62f6bb") if light_index < stock.size() else Color("#39151a"))
	var chute := Rect2(MACHINE_RECT.position + Vector2(39, 353), Vector2(MACHINE_RECT.size.x - 78, 30))
	surface.draw_rect(chute, Color("#28070c"))
	surface.draw_rect(chute, Color("#ff9b6b"), false, 2)
	surface.draw_rect(chute.grow(-7), Color("#060609"))
	surface.surface_label_centered("TICKET CHUTE", chute, 9, C_SOFT)
	surface.surface_label_centered("%d/%d DESIGNS FOUND" % [int(state.get("scratch_collection_count", 0)), int(state.get("scratch_collection_total", COLLECTION_TOTAL))], Rect2(MACHINE_RECT.position + Vector2(20, 386), Vector2(MACHINE_RECT.size.x - 40, 12)), 8, C_YELLOW)


func _draw_vending_window(surface, slot: Dictionary, rect: Rect2, index: int) -> void:
	var palette := _copy_dict(slot.get("palette", {}))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var sold_out := int(slot.get("remaining", 0)) <= 0
	surface.draw_rect(rect, Color("#252731"))
	surface.draw_rect(rect, Color("#808392"), false, 2)
	var ticket := Rect2(rect.position + Vector2(13, 7), Vector2(82, 66))
	surface.draw_rect(Rect2(ticket.position + Vector2(3, 3), ticket.size), Color(0.0, 0.0, 0.0, 0.42))
	surface.draw_rect(ticket, Color(paper.r * (0.42 if sold_out else 1.0), paper.g * (0.42 if sold_out else 1.0), paper.b * (0.42 if sold_out else 1.0)))
	surface.draw_rect(Rect2(ticket.position, Vector2(ticket.size.x, 20)), Color(accent.r, accent.g, accent.b, 0.45 if sold_out else 1.0))
	surface.surface_label_centered(str(slot.get("display_name", "Ticket")).to_upper().left(15), Rect2(ticket.position + Vector2(3, 3), Vector2(ticket.size.x - 6, 15)), 8, C_DARK if not sold_out else C_SOFT)
	for mark_index in range(6):
		var mark_center := ticket.position + Vector2(18 + (mark_index % 3) * 23, 33 + (mark_index / 3) * 18)
		surface.draw_circle(mark_center, 6, Color(accent.r, accent.g, accent.b, 0.22 if sold_out else 0.72))
		surface.draw_circle(mark_center, 3, Color(paper.r, paper.g, paper.b, 0.85))
	surface.draw_rect(Rect2(rect.position + Vector2(7, 77), Vector2(94, 14)), Color("#08090d"))
	surface.surface_label("%d" % (index + 1), rect.position + Vector2(10, 88), 8, C_SOFT)
	surface.surface_label_centered("SOLD OUT" if sold_out else "$%d  /  %d LEFT" % [int(slot.get("price", 1)), int(slot.get("remaining", 0))], Rect2(rect.position + Vector2(21, 77), Vector2(76, 14)), 8, C_PINK if sold_out else C_WHITE)
	surface.draw_circle(rect.position + Vector2(99, 84), 3, Color("#ff3d50") if sold_out else Color("#54f39c"))


func _draw_ticket(surface, state: Dictionary) -> void:
	var ticket := _copy_dict(state.get("scratch_ticket", {}))
	_draw_counter_mat(surface)
	if ticket.is_empty() or bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		_draw_empty_ticket_outline(surface)
		return
	var face := _copy_dict(ticket.get("face", {}))
	var palette := _copy_dict(face.get("palette", {}))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var latex := Color(str(palette.get("latex", "#b9bcc8")))
	var trim := Color(str(palette.get("trim", "#ffd447")))
	var ticket_shape := [TICKET_RECT.position + Vector2(7, 0), TICKET_RECT.end - Vector2(7, TICKET_RECT.size.y), TICKET_RECT.end - Vector2(0, 7), TICKET_RECT.end - Vector2(7, 0), TICKET_RECT.position + Vector2(7, TICKET_RECT.size.y), TICKET_RECT.position + Vector2(0, TICKET_RECT.size.y - 7), TICKET_RECT.position + Vector2(0, 7)]
	var shadow_shape: Array = []
	for point_value in ticket_shape:
		shadow_shape.append((point_value as Vector2) + Vector2(5, 5))
	surface.draw_polygon(shadow_shape, [Color(0.0, 0.0, 0.0, 0.35)])
	surface.draw_polygon(ticket_shape, [paper])
	surface.draw_rect(TICKET_RECT.grow(-4), trim, false, 3)
	_draw_ticket_background(surface, ticket, paper, ink, accent, trim)
	var title_rect := Rect2(TICKET_RECT.position + Vector2(20, 14), Vector2(TICKET_RECT.size.x - 40, 47))
	surface.surface_label_centered(str(ticket.get("display_name", "SCRATCH TICKET")).to_upper(), title_rect, 23 if str(ticket.get("display_name", "")).length() < 15 else 19, ink)
	var price_badge := Rect2(TICKET_RECT.position + Vector2(8, 8), Vector2(38, 30))
	surface.draw_circle(price_badge.get_center(), 19, accent)
	surface.surface_label_centered("$%d" % int(ticket.get("price", 1)), price_badge, 14, C_WHITE)
	var top_prize := _ticket_top_prize(str(ticket.get("type_id", "")))
	surface.surface_label_centered("WIN UP TO $%d" % top_prize, Rect2(TICKET_RECT.position + Vector2(34, 66), Vector2(TICKET_RECT.size.x - 68, 24)), 14, trim if paper.get_luminance() < 0.45 else accent)
	var gimmick := _copy_dict(ticket.get("gimmick", {}))
	var play_label := _ticket_play_label(str(ticket.get("type_id", "")), gimmick)
	surface.surface_label_centered(play_label, Rect2(TICKET_RECT.position + Vector2(28, 100), Vector2(TICKET_RECT.size.x - 56, 20)), 10, ink)
	var fortune := str(state.get("scratch_fortune", ""))
	if not fortune.is_empty():
		surface.surface_label("TAROT: %s" % fortune.to_upper(), TICKET_RECT.position + Vector2(190, 131), 8, accent)
	if int(state.get("scratch_penalty_shields", 0)) > 0:
		surface.surface_label("PENNY SHIELD", TICKET_RECT.position + Vector2(24, 131), 8, accent)
	var grid := _copy_dict(ticket.get("grid", {}))
	var columns := maxi(1, int(grid.get("columns", 3)))
	var rows := maxi(1, int(grid.get("rows", 3)))
	var cells := _dictionary_array(ticket.get("cells", []))
	var scratch := _copy_dict(ticket.get("scratch", {}))
	var xray_peeks := _dictionary_array(state.get("scratch_xray_peeks", []))
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		var rect := _ticket_cell_rect(ticket, index)
		_draw_play_field(surface, str(face.get("layout", "classic_nine")), rect, index, paper, accent, trim, str(cell.get("role", "")))
		_draw_symbol(surface, str(cell.get("symbol", "?")), rect, ink, accent)
		var peek := _peek_for_cell(xray_peeks, index)
		if not peek.is_empty():
			surface.draw_rect(rect.grow(-5), Color(accent.r, accent.g, accent.b, 0.08))
	_draw_ticket_latex_mask(surface, ticket, latex)
	var scratch_rect := _ticket_scratch_rect(ticket)
	surface.surface_add_drag_hit(scratch_rect.grow(5), SCRUB_ACTION, 0)
	_draw_ticket_rules(surface, ticket, ink, accent, trim)
	var button := Rect2(TICKET_RECT.position + Vector2(224, 363), Vector2(91, 24))
	surface.draw_circle(button.position + Vector2(12, 12), 11, trim)
	surface.draw_rect(Rect2(button.position + Vector2(12, 1), Vector2(button.size.x - 12, 22)), Color(accent.r, accent.g, accent.b, 0.16))
	surface.draw_rect(Rect2(button.position + Vector2(12, 1), Vector2(button.size.x - 12, 22)), accent, false, 1)
	surface.surface_label("FAST SCRATCH", button.position + Vector2(19, 16), 8, accent)
	surface.surface_add_hit(button, SCRATCH_ALL_ACTION, 0)
	var crumbs := _dictionary_array(state.get("scratch_crumbs", []))
	for crumb_value in crumbs:
		var crumb: Dictionary = crumb_value
		var point := Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0)))
		surface.draw_circle(point, float(crumb.get("r", 2.0)), latex)
	_draw_brush_feedback(surface, state, latex)
	_draw_sweep_feedback(surface, state, trim)


func _draw_symbol(surface, symbol: String, rect: Rect2, ink: Color, accent: Color) -> void:
	var color := C_YELLOW if symbol in ["SHOCK", "BONUS", "2X", "5X", "10X"] else accent if symbol in ["7", "VOLT", "COW", "KEY", "FREE", "DEVIL", "RARE"] else ink
	var center := rect.get_center()
	if symbol in ["7", "VOLT", "SHOCK"]:
		surface.draw_polygon([center + Vector2(-6, -12), center + Vector2(3, -12), center + Vector2(-1, -3), center + Vector2(8, -3), center + Vector2(-7, 13), center + Vector2(-2, 2), center + Vector2(-10, 2)], [color])
	elif symbol in ["STAR", "RARE", "COMET"]:
		var points: Array = []
		for point_index in range(10):
			var radius := 12.0 if point_index % 2 == 0 else 5.0
			var angle := -PI * 0.5 + float(point_index) * PI / 5.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		surface.draw_polygon(points, [color])
	else:
		surface.surface_label_centered(symbol.left(8), rect.grow(-3), 13 if symbol.length() > 5 else 16, color)


func _draw_counter_mat(surface) -> void:
	var mat := Rect2(TICKET_RECT.position - Vector2(9, 5), TICKET_RECT.size + Vector2(18, 10))
	surface.draw_rect(mat, Color("#321d18"))
	for stripe in range(9):
		var y := mat.position.y + 8.0 + float(stripe) * 47.0
		surface.draw_line(Vector2(mat.position.x + 3, y), Vector2(mat.end.x - 3, y - 13), Color(1.0, 0.78, 0.54, 0.035), 2)


func _draw_empty_ticket_outline(surface) -> void:
	surface.draw_rect(TICKET_RECT, Color("#191513"))
	for corner in range(4):
		var offset := Vector2(13 if corner % 2 == 0 else TICKET_RECT.size.x - 33, 19 if corner < 2 else TICKET_RECT.size.y - 39)
		surface.draw_rect(Rect2(TICKET_RECT.position + offset, Vector2(20, 20)), Color("#6b5143"), false, 2)
	surface.surface_label_centered("TICKET LANDING TRAY", Rect2(TICKET_RECT.position + Vector2(28, 164), Vector2(TICKET_RECT.size.x - 56, 28)), 16, Color("#a78a77"))
	surface.surface_label_centered("Choose a printed ticket from the cabinet", Rect2(TICKET_RECT.position + Vector2(24, 196), Vector2(TICKET_RECT.size.x - 48, 20)), 9, Color("#816b5e"))


func _draw_ticket_background(surface, ticket: Dictionary, paper: Color, ink: Color, accent: Color, trim: Color) -> void:
	# SA2_PER_FRAME_OK: bounded decorative geometry (at most 18 marks) is the ticket face itself; no state duplication or unbounded allocation.
	var face := _copy_dict(ticket.get("face", {}))
	var layout := str(face.get("layout", "classic_nine"))
	match layout:
		"classic_nine":
			for ray in range(18):
				var angle := float(ray) * TAU / 18.0
				surface.draw_line(TICKET_RECT.position + Vector2(166, 70), TICKET_RECT.position + Vector2(166, 70) + Vector2(cos(angle), sin(angle)) * 150.0, Color(accent.r, accent.g, accent.b, 0.09), 3)
		"pasture_nine":
			surface.draw_rect(Rect2(TICKET_RECT.position + Vector2(8, 93), Vector2(TICKET_RECT.size.x - 16, 45)), Color(accent.r, accent.g, accent.b, 0.16))
			for cloud in range(5):
				surface.draw_circle(TICKET_RECT.position + Vector2(35 + cloud * 70, 105 + (cloud % 2) * 10), 14, Color(1.0, 1.0, 1.0, 0.28))
		"warning_nine":
			for stripe in range(10):
				var x := TICKET_RECT.position.x + float(stripe) * 44.0 - 40.0
				surface.draw_polygon([Vector2(x, TICKET_RECT.position.y + 92), Vector2(x + 18, TICKET_RECT.position.y + 92), Vector2(x + 62, TICKET_RECT.position.y + 132), Vector2(x + 44, TICKET_RECT.position.y + 132)], [Color(trim.r, trim.g, trim.b, 0.16)]) # SA2_PER_FRAME_OK: bounded four-point printed hazard stripe.
		"gold_lines", "premium_filigree":
			for ring in range(5):
				surface.draw_circle(TICKET_RECT.position + Vector2(166, 96), 36.0 + float(ring) * 14.0, Color(accent.r, accent.g, accent.b, 0.07), false, 3)
		"key_and_bonus":
			surface.draw_circle(TICKET_RECT.position + Vector2(166, 96), 27, Color(accent.r, accent.g, accent.b, 0.18))
			surface.draw_rect(Rect2(TICKET_RECT.position + Vector2(158, 96), Vector2(16, 38)), Color(accent.r, accent.g, accent.b, 0.18))
		"crossword_grid":
			for line_index in range(9):
				var offset := float(line_index) * 38.0
				surface.draw_line(TICKET_RECT.position + Vector2(10 + offset, 92), TICKET_RECT.position + Vector2(10 + offset, 135), Color(ink.r, ink.g, ink.b, 0.08), 1)
		"double_arrow":
			surface.draw_polygon([TICKET_RECT.position + Vector2(36, 110), TICKET_RECT.position + Vector2(105, 80), TICKET_RECT.position + Vector2(105, 99), TICKET_RECT.position + Vector2(225, 99), TICKET_RECT.position + Vector2(225, 80), TICKET_RECT.position + Vector2(296, 110), TICKET_RECT.position + Vector2(225, 140), TICKET_RECT.position + Vector2(225, 121), TICKET_RECT.position + Vector2(105, 121), TICKET_RECT.position + Vector2(105, 140)], [Color(accent.r, accent.g, accent.b, 0.16)])
		"infernal_contract":
			for flame in range(8):
				var base := TICKET_RECT.position + Vector2(18 + flame * 42, 136)
				surface.draw_polygon([base, base + Vector2(10, -30 - (flame % 3) * 8), base + Vector2(22, 0)], [Color(accent.r, accent.g, accent.b, 0.13)])
		"moon_constellation":
			for star in range(18):
				var point := TICKET_RECT.position + Vector2(15 + (star * 73) % 300, 85 + (star * 47) % 270)
				surface.draw_circle(point, 1.5 + float(star % 2), Color(trim.r, trim.g, trim.b, 0.45))


func _draw_play_field(surface, layout: String, rect: Rect2, index: int, paper: Color, accent: Color, trim: Color, role: String) -> void:
	# SA2_PER_FRAME_OK: one bounded four-point field outline per printed scratch spot is required immediate-mode geometry.
	var base := Color(paper.r * 0.90, paper.g * 0.90, paper.b * 0.90)
	if layout in ["classic_nine", "pasture_nine", "premium_filigree", "moon_constellation"]:
		surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.46, base)
		surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.46, accent, false, 2)
	elif layout in ["warning_nine", "double_arrow"]:
		var c := rect.get_center()
		var diamond := [Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y), Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)] # SA2_PER_FRAME_OK: bounded four-point printed play field.
		surface.draw_polygon(diamond, [base])
		for edge_index in range(4):
			surface.draw_line(diamond[edge_index], diamond[(edge_index + 1) % 4], accent, 2)
	elif layout == "gold_lines":
		_draw_pill(surface, rect, base, accent)
	else:
		surface.draw_rect(rect, base)
		surface.draw_rect(rect, accent, false, 2 if layout == "crossword_grid" else 1)
	if role == "bonus_area":
		surface.draw_rect(rect.grow(3), trim, false, 3)
		surface.surface_label_centered("BONUS", Rect2(rect.position + Vector2(0, -10), Vector2(rect.size.x, 9)), 7, trim)
	elif index < 3 and layout != "crossword_grid":
		surface.surface_label_centered("PLAY %d" % (index + 1), Rect2(rect.position + Vector2(0, -8), Vector2(rect.size.x, 8)), 6, accent)


func _draw_latex_field(surface, layout: String, rect: Rect2, latex: Color, _index: int) -> void:
	# SA2_PER_FRAME_OK: one bounded four-point latex mask and three flecks per unrevealed spot are required immediate-mode geometry.
	if layout in ["classic_nine", "pasture_nine", "premium_filigree", "moon_constellation"]:
		surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.44, latex)
	elif layout in ["warning_nine", "double_arrow"]:
		var c := rect.get_center()
		surface.draw_polygon([Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y), Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)], [latex]) # SA2_PER_FRAME_OK: bounded four-point latex coating geometry.
	elif layout == "gold_lines":
		_draw_pill(surface, rect, latex, Color(latex.r * 0.78, latex.g * 0.78, latex.b * 0.78))
	else:
		surface.draw_rect(rect, latex)
	for fleck in range(3):
		var point := rect.position + Vector2(7 + (fleck * 19 + _index * 7) % maxi(8, int(rect.size.x - 12)), 7 + (fleck * 13 + _index * 5) % maxi(8, int(rect.size.y - 12)))
		surface.draw_circle(point, 1, Color(1.0, 1.0, 1.0, 0.30))


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
	var progress := surface.surface_animation_progress(SWEEP_CHANNEL)
	var rect := _ticket_scratch_rect(state.get("scratch_ticket", {}) if typeof(state.get("scratch_ticket", {})) == TYPE_DICTIONARY else {})
	var x := lerpf(rect.position.x, rect.end.x, progress)
	surface.draw_rect(Rect2(Vector2(x - 8.0, rect.position.y), Vector2(16.0, rect.size.y)), Color(trim.r, trim.g, trim.b, 0.24 * (1.0 - progress)))


func _draw_pill(surface, rect: Rect2, fill: Color, border: Color) -> void:
	var radius := minf(rect.size.y * 0.5, rect.size.x * 0.25)
	surface.draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), fill)
	surface.draw_circle(rect.position + Vector2(radius, rect.size.y * 0.5), radius, fill)
	surface.draw_circle(rect.position + Vector2(rect.size.x - radius, rect.size.y * 0.5), radius, fill)
	surface.draw_line(rect.position + Vector2(radius, 0), rect.position + Vector2(rect.size.x - radius, 0), border, 1)
	surface.draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), border, 1)


func _ticket_play_label(type_id: String, gimmick: Dictionary) -> String:
	match type_id:
		"word_hunt": return "SCRATCH THE LETTER GRID - COMPLETE A PRIZE WORD"
		"bonus_box": return "FIND THE KEY - THEN OPEN THE GOLD BONUS BOX"
		"gold_rush_doubler": return "MATCH 3 - MULTIPLIER SYMBOLS BOOST THE PRIZE"
		"high_voltage": return "MATCH 3 - SHOCK SYMBOLS ZAP CASH ON REVEAL"
		"second_chance": return "MATCH 3 - FREE TICKET SYMBOL GETS AN ENCORE"
		"devils_cut": return "MATCH 3 - THE DEVIL KEEPS HIS PRINTED CUT"
		"fools_gold": return "MATCH 3 - READ THE PRIZE ODDS BEFORE YOU BUY"
		"midnight_rare": return "MATCH 3 - RARE SYMBOLS CALL UP MIDNIGHT LUCK"
	return "SCRATCH EACH SPOT - MATCH 3 SYMBOLS TO WIN"


func _draw_ticket_rules(surface, ticket: Dictionary, ink: Color, accent: Color, trim: Color) -> void:
	var type_id := str(ticket.get("type_id", ""))
	var lines := _ticket_rule_lines(type_id)
	var rules_rect := Rect2(TICKET_RECT.position + Vector2(17, 337), Vector2(TICKET_RECT.size.x - 34, 59))
	surface.draw_rect(rules_rect, Color(0.0, 0.0, 0.0, 0.09))
	surface.draw_rect(rules_rect, Color(accent.r, accent.g, accent.b, 0.65), false, 1)
	for index in range(lines.size()):
		surface.surface_label(str(lines[index]), rules_rect.position + Vector2(7, 12 + index * 10), 7, ink)
	var serial := str(ticket.get("id", "000000")).right(12).to_upper()
	surface.surface_label("VOID IF ALTERED  •  %s" % serial, rules_rect.position + Vector2(7, 53), 6, Color(ink.r, ink.g, ink.b, 0.72))
	surface.draw_rect(Rect2(TICKET_RECT.position + Vector2(4, 401), Vector2(TICKET_RECT.size.x - 8, 3)), trim)


func _ticket_rule_lines(type_id: String) -> Array:
	match type_id:
		"bonus_box": return ["Reveal three matching symbols to win.", "A KEY unlocks the separately marked BONUS spot.", "Winning tickets must be cashed by the clerk."]
		"word_hunt": return ["Scratch all letters. Complete the printed prize word.", "More scratching, fixed result: reveal order never changes it.", "Winning tickets must be cashed by the clerk."]
		"high_voltage": return ["Reveal three matching symbols to win the prize shown.", "Each SHOCK symbol immediately deducts its printed charge.", "Winning tickets must be cashed by the clerk."]
		"devils_cut": return ["Reveal three matching symbols to win the gross prize.", "The DEVIL keeps the printed cut and may draw attention.", "Net winning tickets must be cashed by the clerk."]
		"fools_gold": return ["Reveal three matching symbols to win the listed amount.", "Premium ticket. Tiny prize table. Glitter is not value.", "Winning tickets must be cashed by the clerk."]
	return ["Scratch the complete play area. Match three to win.", "Outcome is printed when dispensed; scratch order cannot change it.", "Take winning tickets to the clerk for payment."]


func _ticket_top_prize(type_id: String) -> int:
	var top := 0
	for prize_value in _dictionary_array(_ticket_type(type_id).get("prize_table", [])):
		top = maxi(top, int((prize_value as Dictionary).get("gross_payout", (prize_value as Dictionary).get("payout", 0))))
	return top


func _ticket_cell_rect(ticket: Dictionary, index: int) -> Rect2:
	var grid := _copy_dict(ticket.get("grid", {}))
	var columns := maxi(1, int(grid.get("columns", 3)))
	var rows := maxi(1, int(grid.get("rows", 3)))
	return _cell_rect(index, columns, rows)


func _draw_sorted_piles(surface, state: Dictionary) -> void:
	var winners := _dictionary_array(state.get("scratch_winner_pile", []))
	var losers := _dictionary_array(state.get("scratch_loser_pile", []))
	var pending := int(state.get("scratch_pending_payout", 0))
	var header := Rect2(PILES_RECT.position.x, 13, PILES_RECT.size.x, 168)
	surface.draw_rect(header, Color("#18191b"))
	surface.draw_rect(header, Color("#6f5a43"), false, 2)
	surface.surface_label_centered("CLERK", Rect2(header.position + Vector2(9, 9), Vector2(94, 20)), 14, C_WHITE)
	surface.surface_label_centered("CASHOUT", Rect2(header.position + Vector2(9, 30), Vector2(94, 16)), 10, C_YELLOW)
	surface.draw_rect(Rect2(header.position + Vector2(19, 55), Vector2(header.size.x - 38, 60)), Color("#f4e4bd"))
	surface.surface_label_centered("WINNERS DUE", Rect2(header.position + Vector2(24, 61), Vector2(header.size.x - 48, 14)), 9, C_DARK)
	surface.surface_label_centered("$%d" % pending, Rect2(header.position + Vector2(24, 78), Vector2(header.size.x - 48, 29)), 24, Color("#1c6d48") if pending > 0 else Color("#777064"))
	surface.surface_label_centered("Take the green pile to the clerk", Rect2(header.position + Vector2(10, 128), Vector2(header.size.x - 20, 16)), 8, C_SOFT)
	surface.surface_label_centered("PAYOUTS ARE NOT AUTOMATIC", Rect2(header.position + Vector2(10, 147), Vector2(header.size.x - 20, 12)), 7, C_YELLOW)
	surface.draw_rect(PILES_RECT, Color("#111114"))
	surface.draw_rect(PILES_RECT, Color("#78644e"), false, 2)
	var gap := 8.0
	var width := (PILES_RECT.size.x - gap - 12.0) * 0.5
	_draw_ticket_pile(surface, Rect2(PILES_RECT.position + Vector2(4, 4), Vector2(width, PILES_RECT.size.y - 8)), winners, true)
	_draw_ticket_pile(surface, Rect2(PILES_RECT.position + Vector2(8 + width, 4), Vector2(width, PILES_RECT.size.y - 8)), losers, false)


func _draw_ticket_pile(surface, rect: Rect2, tickets: Array, winner: bool) -> void:
	var accent := Color("#54d8a0") if winner else Color("#e48a57")
	surface.draw_rect(rect, Color("#080b0a") if winner else Color("#0c0908"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.35), false, 1)
	surface.surface_label("WINNERS" if winner else "LOSERS", rect.position + Vector2(7, 15), 9, accent)
	surface.surface_label(str(tickets.size()), rect.position + Vector2(rect.size.x - 18, 15), 9, accent)
	if tickets.is_empty():
		for ghost in range(4):
			var ghost_rect := Rect2(rect.position + Vector2(16 + ghost * 2, 62 + ghost * 21), Vector2(rect.size.x - 32, 30))
			surface.draw_rect(ghost_rect, Color(1.0, 0.95, 0.80, 0.055))
			surface.draw_rect(ghost_rect, Color(accent.r, accent.g, accent.b, 0.12), false, 1)
		return
	var visible := mini(7, tickets.size())
	for draw_index in range(visible):
		var source_index := tickets.size() - visible + draw_index
		var ticket: Dictionary = tickets[source_index]
		var jitter := Vector2(0, 0) if winner else Vector2(float((source_index * 7) % 9) - 4.0, float((source_index * 11) % 5) - 2.0)
		var mini_rect := Rect2(rect.position + Vector2(13 + (draw_index if winner else source_index % 3), rect.size.y - 48 - draw_index * 18) + jitter, Vector2(rect.size.x - 27, 36))
		_draw_mini_scratch_ticket(surface, ticket, mini_rect, 1.0)


func _draw_mini_scratch_ticket(surface, ticket: Dictionary, rect: Rect2, alpha: float) -> void:
	var palette := _copy_dict(_copy_dict(ticket.get("face", {})).get("palette", ticket.get("palette", {})))
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
	var ticket := _copy_dict(state.get("scratch_ticket", {}))
	if ticket.is_empty():
		return
	var slot := clampi(int(surface.surface_animation_metadata(DISPENSE_CHANNEL).get("slot", 0)), 0, 3)
	var progress := _ease_out_cubic(surface.surface_animation_progress(DISPENSE_CHANNEL))
	var source := MACHINE_RECT.position + Vector2(80 + (slot % 2) * 119, 160 + (slot / 2) * 108)
	var chute := MACHINE_RECT.position + Vector2(95, 354)
	var target := TICKET_RECT.position + Vector2(42, 38)
	var position := source.lerp(chute, clampf(progress * 2.0, 0.0, 1.0)) if progress < 0.5 else chute.lerp(target, clampf((progress - 0.5) * 2.0, 0.0, 1.0))
	var size := Vector2(80, 56).lerp(Vector2(248, 302), progress)
	_draw_mini_scratch_ticket(surface, ticket, Rect2(position - size * 0.5, size), 1.0)
	surface.draw_rect(Rect2(position - size * 0.5, size).grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.25 * (1.0 - progress)), false, 3)


func _draw_file_animation(surface, state: Dictionary) -> void:
	if not bool(surface.surface_animation_active(FILE_CHANNEL)):
		return
	var ticket := _copy_dict(state.get("scratch_last_settled_ticket", {}))
	if ticket.is_empty():
		return
	var progress := _ease_in_out_cubic(surface.surface_animation_progress(FILE_CHANNEL))
	var winner := str(state.get("scratch_last_settled_pile", "")) == "winner_pile"
	var gap := 8.0
	var width := (PILES_RECT.size.x - gap - 12.0) * 0.5
	var target := PILES_RECT.position + Vector2(17, 150) if winner else PILES_RECT.position + Vector2(21 + width, 158)
	var source := TICKET_RECT.position + Vector2(44, 96)
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
	var cells := _dictionary_array(ticket.get("cells", []))
	var available := range(cells.size())
	var result: Array = []
	while not available.is_empty() and result.size() < maxi(0, count):
		var pick_index := rng.randi_range(0, available.size() - 1)
		var cell_index := int(available[pick_index])
		available.remove_at(pick_index)
		result.append({"index": cell_index, "symbol": str((cells[cell_index] as Dictionary).get("symbol", ""))})
	return result


func _peek_for_cell(peeks: Array, index: int) -> Dictionary:
	for peek_value in peeks:
		var peek: Dictionary = peek_value
		if int(peek.get("index", -1)) == index:
			return peek
	return {}


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
	var cells_value: Variant = ticket.get("cells", [])
	var cells: Array = cells_value if typeof(cells_value) == TYPE_ARRAY else []
	if cells.is_empty():
		return false
	for value in cells:
		if not bool((value as Dictionary).get("revealed", false)):
			return false
	return true


func _ticket_penalty_total(ticket: Dictionary) -> int:
	var total := 0
	for value in _dictionary_array(ticket.get("cells", [])):
		total += maxi(0, int((value as Dictionary).get("penalty", 0)))
	return total


func _ticket_symbols(ticket: Dictionary) -> Array:
	var result: Array = []
	for value in _dictionary_array(ticket.get("cells", [])):
		result.append(str((value as Dictionary).get("symbol", "")))
	return result


func _ticket_scratch_rect(_ticket: Dictionary) -> Rect2:
	return GRID_RECT


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


func _reveal_legacy_cells_for_completed_ticket_sections(ticket: Dictionary) -> void:
	if not _ticket_complete(ticket):
		return
	var cells: Array = ticket.get("cells", []) if typeof(ticket.get("cells", [])) == TYPE_ARRAY else []
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		cell["revealed"] = true
		cell["scratched_ratio"] = 1.0
		cells[index] = cell
	ticket["cells"] = cells


func _reduce_motion_enabled(ui_state: Dictionary) -> bool:
	if bool(ui_state.get("reduce_motion", false)):
		return true
	var runtime: Dictionary = ui_state.get("surface_runtime_status", {}) if typeof(ui_state.get("surface_runtime_status", {})) == TYPE_DICTIONARY else {}
	return bool(runtime.get("reduce_motion", false))


func _scratch_animation_channels(machine: Dictionary, reduce_motion: bool) -> Array:
	return [
		GameModule.surface_animation_channel(DISPENSE_CHANNEL, str(machine.get("last_dispense_id", "")), DISPENSE_DURATION_MSEC, int(machine.get("dispense_started_msec", 0)), {"metadata": {"ticket_id": str(_copy_dict(machine.get("active_ticket", {})).get("id", "")), "slot": int(machine.get("last_dispense_slot", 0))}}),
		GameModule.surface_animation_channel(FILE_CHANNEL, str(machine.get("last_file_id", "")), FILE_DURATION_MSEC, int(machine.get("file_started_msec", 0)), {"metadata": {"pile": str(machine.get("last_settled_pile", ""))}}),
		GameModule.surface_animation_channel(SWEEP_CHANNEL, str(machine.get("last_sweep_id", "")), 0 if reduce_motion else SWEEP_DURATION_MSEC, int(machine.get("sweep_started_msec", 0)), {"metadata": {"section": str(machine.get("last_sweep_section", ""))}}),
	]


func _cell_rect(index: int, columns: int, rows: int) -> Rect2:
	var column := index % maxi(1, columns)
	var row := index / maxi(1, columns)
	var gap := 8.0
	var width := (GRID_RECT.size.x - gap * float(columns - 1)) / float(columns)
	var height := (GRID_RECT.size.y - gap * float(rows - 1)) / float(rows)
	return Rect2(GRID_RECT.position + Vector2(float(column) * (width + gap), float(row) * (height + gap)), Vector2(width, height))


func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	return sqrt(_distance_squared_to_segment(point, from, to))


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


func _zero_mask(size: int) -> Array:
	var result: Array = []
	for _index in range(maxi(0, size)):
		result.append(0)
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
