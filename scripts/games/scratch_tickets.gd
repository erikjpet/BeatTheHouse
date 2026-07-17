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
const REDEEM_HOOK_ID := "scratch_ticket_clerk"
const REDEEM_ACTION_ID := "redeem_scratch_winners"
const TICKET_RECT := Rect2(342, 66, 530, 304)
const GRID_RECT := Rect2(370, 132, 474, 190)
const MACHINE_RECT := Rect2(18, 18, 292, 394)
const BIG_WIN_THRESHOLD := 100


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
		"machine_name": str(machine.get("machine_name", "Highway Scratch Center")),
		"scratch_stock": stock,
		"scratch_ticket": active_ticket,
		"scratch_pending_payout": _pending_payout(machine),
		"scratch_winner_count": _dictionary_array(machine.get("winner_pile", [])).size(),
		"scratch_crumbs": crumbs,
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_drunk_level": run_state.drunk_level if run_state != null else 0,
		"scratch_rules": "Drag to scrub. A click alone reveals nothing. Cleared cells snap clean; winners cash at the clerk.",
		"surface_ui_protected_regions": [
			{"x": MACHINE_RECT.position.x, "y": MACHINE_RECT.position.y, "w": MACHINE_RECT.size.x, "h": MACHINE_RECT.size.y},
			{"x": TICKET_RECT.position.x, "y": TICKET_RECT.position.y, "w": TICKET_RECT.size.x, "h": TICKET_RECT.size.y},
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "scratch_ticket_machine",
			"action_cues": {BUY_ACTION: "ticket_dispenser", SCRATCH_ALL_ACTION: "ticket_peel"},
		}),
	})


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "scratch_tickets":
		return false
	surface.surface_begin_design_space(SURFACE_DESIGN_SIZE)
	_draw_machine(surface, state)
	_draw_ticket(surface, state)
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
			_write_machine_state(environment, machine)
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
	var next_state := ui_state.duplicate(true)
	if phase == "begin":
		next_state["scratch_drag_active"] = true
		next_state["scratch_drag_moved"] = false
		next_state["scratch_last_pointer"] = board_position
		next_state["scratch_crumbs"] = []
		return GameModule.surface_command({"ui_state": next_state})
	if phase == "end":
		next_state["scratch_drag_active"] = false
		next_state.erase("scratch_last_pointer")
		return GameModule.surface_command({"ui_state": next_state})
	if phase != "move" or not bool(next_state.get("scratch_drag_active", false)):
		return GameModule.surface_command({"ui_state": next_state})
	var previous: Vector2 = next_state.get("scratch_last_pointer", board_position)
	next_state["scratch_last_pointer"] = board_position
	if previous.distance_to(board_position) < 1.5:
		return GameModule.surface_command({"ui_state": next_state})
	next_state["scratch_drag_moved"] = true
	var machine := _ensure_machine_state(run_state, environment, true)
	var scratch_result := _scratch_segment(machine, previous, board_position)
	if int(scratch_result.get("erased_samples", 0)) <= 0:
		return GameModule.surface_command({"ui_state": next_state})
	next_state["scratch_crumbs"] = _crumbs_for_segment(previous, board_position, int(scratch_result.get("erased_samples", 0)))
	_write_machine_state(environment, machine)
	var completed := bool(scratch_result.get("ticket_complete", false))
	var penalty := int(scratch_result.get("penalty", 0))
	var command := {
		"ui_state": next_state,
		"environment_changed": false,
		"message": str(scratch_result.get("message", "Latex flakes away.")),
	}
	if completed or penalty > 0:
		command["action_id"] = SETTLE_ACTION if completed else REVEAL_ACTION
		command["action_kind"] = "legal"
		command["direct_resolve"] = true
		command["skip_stake_validation"] = true
	return GameModule.surface_command(command)


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
	return _empty_result(action_id, environment, "That scratch-ticket action is unavailable.")


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
	var ticket := _roll_ticket(ticket_type, rng, luck_modifier, "audit")
	return {
		"type_id": type_id,
		"price": int(ticket.get("price", 0)),
		"payout": int(ticket.get("payout", 0)),
		"penalty": _ticket_penalty_total(ticket),
		"net_return": int(ticket.get("payout", 0)) - _ticket_penalty_total(ticket),
		"symbols": _ticket_symbols(ticket),
	}


func measure_rtp(type_id: String, samples: int = 20000, seed_text: String = "SCRATCH-RTP") -> Dictionary:
	var rng := _seeded_rng("%s:%s" % [seed_text, type_id])
	var total_cost := 0
	var total_return := 0
	for _sample in range(maxi(1, samples)):
		var result := simulate_ticket_type(type_id, rng, 0)
		total_cost += int(result.get("price", 0))
		total_return += int(result.get("net_return", 0))
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
		return _empty_result(BUY_ACTION, environment, "Finish the active ticket first.")
	var stock := _dictionary_array(machine.get("stock", []))
	var stock_index := int(ui_state.get("scratch_stock_index", 0))
	if stock_index < 0 or stock_index >= stock.size():
		return _empty_result(BUY_ACTION, environment, "That vending slot is empty.")
	var slot: Dictionary = stock[stock_index]
	var price := maxi(1, int(slot.get("price", 1)))
	if int(slot.get("remaining", 0)) <= 0:
		return _empty_result(BUY_ACTION, environment, "%s is sold out." % str(slot.get("display_name", "That ticket")))
	if run_state.bankroll < price:
		return _empty_result(BUY_ACTION, environment, "Not enough cash for this ticket.")
	var ticket_type := _ticket_type(str(slot.get("type_id", "")))
	if ticket_type.is_empty():
		return _empty_result(BUY_ACTION, environment, "That ticket type is unavailable.")
	var purchase_number := int(machine.get("purchased_count", 0)) + 1
	var luck := run_state.effective_luck() if run_state != null else 0
	var ticket := _roll_ticket(ticket_type, rng, luck, "%s:%d" % [str(environment.get("id", "room")), purchase_number])
	slot["remaining"] = maxi(0, int(slot.get("remaining", 0)) - 1)
	stock[stock_index] = slot
	machine["stock"] = stock
	machine["active_ticket"] = ticket
	machine["purchased_count"] = purchase_number
	machine["last_ticket_id"] = str(ticket.get("id", ""))
	_write_machine_state(environment, machine)
	var message := "%s slides onto the counter. Drag across the silver latex to reveal it." % str(ticket.get("display_name", "A scratch ticket"))
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -price
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
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result["scratch_ticket"] = ticket.duplicate(true)
	result["scratch_outcome_fixed_at_purchase"] = true
	result["scratch_luck_modifier"] = luck
	result["defer_bankroll_zero_failure"] = true
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_reveal(run_state: RunState, environment: Dictionary, rng: RngStream, settle: bool) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var ticket := _copy_dict(machine.get("active_ticket", {}))
	if ticket.is_empty():
		return _empty_result(SETTLE_ACTION if settle else REVEAL_ACTION, environment, "There is no ticket on the scratch surface.")
	var pending_penalty := maxi(0, int(machine.get("pending_penalty", 0)))
	machine["pending_penalty"] = 0
	var penalty_paid := mini(pending_penalty, maxi(0, run_state.bankroll)) if run_state != null else pending_penalty
	var payout := int(ticket.get("payout", 0))
	var message := "A SHOCK symbol zaps $%d." % penalty_paid if penalty_paid > 0 else "The printed symbol comes clean."
	if settle:
		if not _ticket_complete(ticket):
			return _empty_result(SETTLE_ACTION, environment, "Some latex still covers this ticket.")
		ticket["settled"] = true
		ticket["penalty_paid"] = int(ticket.get("penalty_paid", 0)) + penalty_paid
		var pile_name := "winner_pile" if payout > 0 else "loser_pile"
		var pile := _dictionary_array(machine.get(pile_name, []))
		pile.append(ticket)
		machine[pile_name] = pile
		machine["active_ticket"] = {}
		message = "%s wins $%d. The clerk must cash it." % [str(ticket.get("display_name", "Ticket")), payout] if payout > 0 else "%s is a loser." % str(ticket.get("display_name", "Ticket"))
		if penalty_paid > 0:
			message += " SHOCK symbols already took $%d." % penalty_paid
	_write_machine_state(environment, machine)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -penalty_paid
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "scratch_ticket_settle" if settle else "scratch_ticket_reveal",
		"game_id": get_id(),
		"action_id": SETTLE_ACTION if settle else REVEAL_ACTION,
		"ticket_id": str(ticket.get("id", "")),
		"ticket_type": str(ticket.get("type_id", "")),
		"pending_clerk_payout": payout if settle else 0,
		"penalty": penalty_paid,
		"bankroll_delta": -penalty_paid,
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
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_redemption(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var winners := _dictionary_array(machine.get("winner_pile", []))
	if winners.is_empty():
		return _empty_result(REDEEM_ACTION_ID, environment, "The clerk has no winning scratchers to cash.")
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
	_write_machine_state(environment, machine)
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
	var machine_rng := rng if rng != null else _seeded_rng("scratch-stock:%s" % str(environment.get("id", "room")))
	var stock: Array = []
	for ticket_type_value in _ticket_types():
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
		"active_ticket": {},
		"winner_pile": [],
		"loser_pile": [],
		"pending_penalty": 0,
		"purchased_count": 0,
		"redeemed_count": 0,
	}


func _roll_ticket(ticket_type: Dictionary, rng: RngStream, luck_modifier: int, purchase_key: String) -> Dictionary:
	var prize := _weighted_prize(ticket_type, rng, luck_modifier)
	var columns := maxi(1, int(_copy_dict(ticket_type.get("grid", {})).get("columns", 3)))
	var rows := maxi(1, int(_copy_dict(ticket_type.get("grid", {})).get("rows", 3)))
	var cells := _build_cells(ticket_type, prize, columns, rows, rng)
	var ticket_id := "%s:%s:%s" % [str(ticket_type.get("id", "ticket")), purchase_key, str(rng.randi_range(100000, 999999))]
	return {
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
		"cells": cells,
		"outcome_fixed_at_purchase": true,
		"luck_modifier": luck_modifier,
		"settled": false,
		"penalty_paid": 0,
	}


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
	var protected: Dictionary = {}
	if not winning_symbol.is_empty() and total >= 3:
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
		cells.append({"index": index, "symbol": symbol, "penalty": penalty, "penalty_queued": false, "revealed": false, "mask": mask, "scratched_ratio": 0.0})
	return cells


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
	var ticket := _copy_dict(machine.get("active_ticket", {}))
	if ticket.is_empty():
		return {"erased_samples": 0, "message": "Buy a ticket first."}
	var cells := _dictionary_array(ticket.get("cells", []))
	var scratch := _copy_dict(ticket.get("scratch", {}))
	var brush_radius := maxf(8.0, float(scratch.get("brush_radius", 34.0)))
	var snap_threshold := clampf(float(scratch.get("snap_threshold", 0.60)), 0.15, 0.95)
	var mask_columns := maxi(2, int(scratch.get("mask_columns", 6)))
	var mask_rows := maxi(2, int(scratch.get("mask_rows", 4)))
	var grid := _copy_dict(ticket.get("grid", {}))
	var columns := maxi(1, int(grid.get("columns", 3)))
	var rows := maxi(1, int(grid.get("rows", 3)))
	var erased := 0
	var revealed: Array = []
	var penalty := 0
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		if bool(cell.get("revealed", false)):
			continue
		var rect := _cell_rect(index, columns, rows)
		var segment_bounds := Rect2(Vector2(minf(from.x, to.x), minf(from.y, to.y)), Vector2(absf(to.x - from.x), absf(to.y - from.y))).grow(1.0)
		if not rect.grow(brush_radius).intersects(segment_bounds):
			continue
		var mask := _int_array(cell.get("mask", []))
		for sample_index in range(mask.size()):
			if int(mask[sample_index]) == 0:
				continue
			var sample_column := sample_index % mask_columns
			var sample_row := sample_index / mask_columns
			var sample_point := rect.position + Vector2((float(sample_column) + 0.5) * rect.size.x / float(mask_columns), (float(sample_row) + 0.5) * rect.size.y / float(mask_rows))
			if _distance_to_segment(sample_point, from, to) <= brush_radius:
				mask[sample_index] = 0
				erased += 1
		var remaining := 0
		for value in mask:
			remaining += int(value)
		var scratched_ratio := 1.0 - float(remaining) / float(maxi(1, mask.size()))
		cell["mask"] = mask
		cell["scratched_ratio"] = scratched_ratio
		if scratched_ratio >= snap_threshold:
			cell["revealed"] = true
			cell["mask"] = _zero_mask(mask.size())
			cell["scratched_ratio"] = 1.0
			revealed.append(index)
			if int(cell.get("penalty", 0)) > 0 and not bool(cell.get("penalty_queued", false)):
				cell["penalty_queued"] = true
				penalty += int(cell.get("penalty", 0))
		cells[index] = cell
	ticket["cells"] = cells
	machine["active_ticket"] = ticket
	if penalty > 0:
		machine["pending_penalty"] = int(machine.get("pending_penalty", 0)) + penalty
	var complete := _ticket_complete(ticket)
	var message := "Latex flakes away."
	if not revealed.is_empty():
		message = "%d symbol%s snap%s clean." % [revealed.size(), "" if revealed.size() == 1 else "s", "s" if revealed.size() == 1 else ""]
	if penalty > 0:
		message += " SHOCK zaps $%d now." % penalty
	return {"erased_samples": erased, "revealed_cells": revealed, "penalty": penalty, "ticket_complete": complete, "message": message}


func _reveal_all(machine: Dictionary) -> void:
	var ticket := _copy_dict(machine.get("active_ticket", {}))
	var cells := _dictionary_array(ticket.get("cells", []))
	var penalty := 0
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		cell["revealed"] = true
		cell["scratched_ratio"] = 1.0
		cell["mask"] = _zero_mask(_int_array(cell.get("mask", [])).size())
		if int(cell.get("penalty", 0)) > 0 and not bool(cell.get("penalty_queued", false)):
			cell["penalty_queued"] = true
			penalty += int(cell.get("penalty", 0))
		cells[index] = cell
	ticket["cells"] = cells
	machine["active_ticket"] = ticket
	machine["pending_penalty"] = int(machine.get("pending_penalty", 0)) + penalty


func _draw_machine(surface, state: Dictionary) -> void:
	surface.draw_rect(MACHINE_RECT, Color("#111522"))
	surface.draw_rect(MACHINE_RECT, C_CYAN, false, 2)
	surface.surface_label_centered("SCRATCH CENTER", Rect2(30, 30, 268, 30), 20, C_YELLOW)
	surface.surface_label_centered("PICK A TICKET", Rect2(30, 60, 268, 18), 12, C_SOFT)
	var stock := _dictionary_array(state.get("scratch_stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		var rect := Rect2(34, 88 + index * 88, 260, 74)
		var palette := _copy_dict(slot.get("palette", {}))
		var accent := Color(str(palette.get("accent", "#35e0ff")))
		surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.13))
		surface.draw_rect(rect, accent, false, 2)
		surface.surface_label(str(slot.get("display_name", "Ticket")), rect.position + Vector2(10, 24), 17, C_WHITE)
		surface.surface_label("$%d  |  %d left" % [int(slot.get("price", 1)), int(slot.get("remaining", 0))], rect.position + Vector2(10, 50), 13, C_SOFT)
		if int(slot.get("remaining", 0)) > 0:
			surface.surface_add_hit(rect, "scratch_buy", index)
	surface.surface_label_centered("WINNERS CASH AT CLERK", Rect2(32, 372, 264, 24), 12, C_PINK)


func _draw_ticket(surface, state: Dictionary) -> void:
	var ticket := _copy_dict(state.get("scratch_ticket", {}))
	if ticket.is_empty():
		surface.draw_rect(TICKET_RECT, Color("#171b2a"))
		surface.draw_rect(TICKET_RECT, C_SOFT, false, 2)
		surface.surface_label_centered("BUY A TICKET", Rect2(370, 180, 474, 42), 28, C_SOFT)
		surface.surface_label_centered("It lands here ready to scrub.", Rect2(370, 224, 474, 24), 14, C_SOFT)
		return
	var face := _copy_dict(ticket.get("face", {}))
	var palette := _copy_dict(face.get("palette", {}))
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var latex := Color(str(palette.get("latex", "#b9bcc8")))
	var trim := Color(str(palette.get("trim", "#ffd447")))
	surface.draw_rect(TICKET_RECT, paper)
	surface.draw_rect(TICKET_RECT, trim, false, 4)
	surface.surface_label_centered(str(ticket.get("display_name", "SCRATCH TICKET")).to_upper(), Rect2(360, 78, 494, 38), 25, accent)
	surface.surface_label("$%d" % int(ticket.get("price", 1)), Vector2(814, 112), 16, ink)
	var grid := _copy_dict(ticket.get("grid", {}))
	var columns := maxi(1, int(grid.get("columns", 3)))
	var rows := maxi(1, int(grid.get("rows", 3)))
	var cells := _dictionary_array(ticket.get("cells", []))
	var scratch := _copy_dict(ticket.get("scratch", {}))
	var mask_columns := maxi(2, int(scratch.get("mask_columns", 6)))
	var mask_rows := maxi(2, int(scratch.get("mask_rows", 4)))
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		var rect := _cell_rect(index, columns, rows)
		surface.draw_rect(rect, Color(paper.r * 0.94, paper.g * 0.94, paper.b * 0.94))
		surface.draw_rect(rect, accent, false, 1)
		if bool(cell.get("revealed", false)):
			_draw_symbol(surface, str(cell.get("symbol", "?")), rect, ink, accent)
		else:
			surface.draw_rect(rect.grow(-2), latex)
			var mask := _int_array(cell.get("mask", []))
			for sample_index in range(mask.size()):
				if int(mask[sample_index]) != 0:
					continue
				var sample_column := sample_index % mask_columns
				var sample_row := sample_index / mask_columns
				var hole := Rect2(rect.position + Vector2(float(sample_column) * rect.size.x / float(mask_columns), float(sample_row) * rect.size.y / float(mask_rows)), Vector2(rect.size.x / float(mask_columns) + 1.0, rect.size.y / float(mask_rows) + 1.0)).grow(-1)
				surface.draw_rect(hole, paper)
	surface.surface_add_drag_hit(GRID_RECT, SCRUB_ACTION, 0)
	var button := Rect2(682, 334, 162, 28)
	surface.draw_rect(button, Color(accent.r, accent.g, accent.b, 0.18))
	surface.draw_rect(button, accent, false, 2)
	surface.surface_label_centered("SCRATCH ALL", button, 13, accent)
	surface.surface_add_hit(button, SCRATCH_ALL_ACTION, 0)
	var crumbs := _dictionary_array(state.get("scratch_crumbs", []))
	for crumb_value in crumbs:
		var crumb: Dictionary = crumb_value
		var point := Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0)))
		surface.draw_circle(point, float(crumb.get("r", 2.0)), latex)


func _draw_symbol(surface, symbol: String, rect: Rect2, ink: Color, accent: Color) -> void:
	var color := C_YELLOW if symbol == "SHOCK" else accent if symbol in ["7", "VOLT", "COW"] else ink
	surface.surface_label_centered(symbol.left(8), rect.grow(-4), 17, color)


func _stock_view(machine: Dictionary) -> Array:
	var result: Array = []
	for value in _dictionary_array(machine.get("stock", [])):
		result.append((value as Dictionary).duplicate(true))
	return result


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var states := _game_states_for_write(environment)
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		return value as Dictionary
	var generated := _generate_machine_state(run_state, environment, null)
	if persist:
		states[get_id()] = generated
		environment["game_states"] = states
	return generated


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) == TYPE_DICTIONARY:
		var value: Variant = (states_value as Dictionary).get(get_id(), {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return value as Dictionary
	return _generate_machine_state(run_state, environment, null)


func _write_machine_state(environment: Dictionary, machine: Dictionary) -> void:
	var states := _game_states_for_write(environment)
	states[get_id()] = machine
	environment["game_states"] = states


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
	var cells := _dictionary_array(ticket.get("cells", []))
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


func _cell_rect(index: int, columns: int, rows: int) -> Rect2:
	var column := index % maxi(1, columns)
	var row := index / maxi(1, columns)
	var gap := 8.0
	var width := (GRID_RECT.size.x - gap * float(columns - 1)) / float(columns)
	var height := (GRID_RECT.size.y - gap * float(rows - 1)) / float(rows)
	return Rect2(GRID_RECT.position + Vector2(float(column) * (width + gap), float(row) * (height + gap)), Vector2(width, height))


func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var delta := to - from
	var length_squared := delta.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from)
	var t := clampf((point - from).dot(delta) / length_squared, 0.0, 1.0)
	return point.distance_to(from + delta * t)


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


func _empty_result(action_id: String, environment: Dictionary, message: String) -> Dictionary:
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


func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


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
