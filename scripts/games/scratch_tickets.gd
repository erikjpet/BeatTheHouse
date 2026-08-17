class_name ScratchTicketsGame
extends GameModule

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const BackgroundRendererScript := preload("res://scripts/games/scratch_ticket_background_renderer.gd")
const IconRendererScript := preload("res://scripts/games/scratch_ticket_icon_renderer.gd")
const FoilRendererScript := preload("res://scripts/games/scratch_ticket_foil_renderer.gd")
const MaskScript := preload("res://scripts/games/scratch_ticket_mask.gd")
const MachineRendererScript := preload("res://scripts/games/scratch_ticket_machine_renderer.gd")
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
const FILE_TICKET_ACTION := "scratch_file_ticket"
const DISCARD_TICKET_ACTION := "scratch_discard"
const DISPENSE_CHANNEL := "scratch_ticket_dispense"
const FILE_CHANNEL := "scratch_ticket_file"
const SWEEP_CHANNEL := "scratch_box_pop"
const DISPENSE_DURATION_MSEC := 760
const FILE_DURATION_MSEC := 620
const SWEEP_DURATION_MSEC := 220
const SCRATCH_AUDIO_LOOP := "scratch_paper_foley_loop"
const SCRATCH_POP_CUE := "scratch_box_pop"
const REDEEM_HOOK_ID := "scratch_ticket_clerk"
const REDEEM_ACTION_ID := "redeem_scratch_winners"
const SCALPER_HOOK_ID := "scratch_ticket_scalper"
const SCALPER_DIALOGUE_KNOWS_ID := "scratch_ticket_scalper_knows"
const SCALPER_DIALOGUE_OBLIVIOUS_ID := "scratch_ticket_scalper_oblivious"
const RESTOCK_INTERVAL_MINUTES := 180
const RESTOCK_ZERO_PERCENT := 50
const RESTOCK_ONE_PERCENT := 40
const RESTOCK_TWO_PERCENT := 10
const SCALPER_VISIT_CHANCE_PERCENT := 30
const SCALPER_KNOWS_CHANCE_PERCENT := 50
const MACHINE_RECT := Rect2(18, 13, 278, 404)
const PLAY_SURFACE_RECT := Rect2(306, 48, 586, 370)
const DEFAULT_TICKET_RECT := Rect2(422, 54, 354, 356)
const DEFAULT_SCRATCH_RECT := Rect2(444, 169, 310, 176)
const STATUS_HUD_RECT := Rect2(306, 8, 460, 34)
const WIN_PILE_RECT := Rect2(318, 184, 82, 54)
const LOSS_PILE_RECT := Rect2(318, 292, 82, 54)
const BIG_WIN_THRESHOLD := 100
const COLLECTION_TOTAL := 7
const DEFAULT_BRUSH_RADIUS := 15.0
const DEFAULT_PASS_REMOVAL := 0.66
const DEFAULT_SWEEP_THRESHOLD := 0.80
const DEFAULT_MASK_COLUMNS := MaskScript.MASK_COLUMNS
const DEFAULT_MASK_ROWS := MaskScript.MASK_ROWS
const DISCARD_ARM_DISTANCE := 120.0
const DISCARD_DROP_DISTANCE := 190.0
const MACHINE_STATE_VERSION := 4
const REGION_LAYOUT_VERSION := RegionModelScript.LAYOUT_VERSION

var active_ticket_rect := DEFAULT_TICKET_RECT


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	# Rasterize each authored foil layout once when the machine opens. Purchases
	# then clone a full-resolution template instead of rebuilding identical
	# geometry while the ticket dispense animation is starting.
	for ticket_type_value in _ticket_types():
		MaskScript.prime(ticket_type_value as Dictionary)
	var machine := _ensure_machine_state(run_state, environment, false)
	var result := super.enter(run_state, environment)
	result["message"] = "The scratcher vending machine hums beside the clerk. Stock releases in small unposted batches; pick a live slot, then drag across the latex."
	result["scratch_stock_count"] = _dictionary_array(machine.get("stock", [])).size()
	result["scratch_stock_available"] = _stock_total(machine)
	result["scratch_scalper_present"] = bool(machine.get("scalper_present", false))
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
	var machine := _ensure_machine_state(run_state, environment, false)
	var active_ticket := _dict_ref(machine.get("active_ticket", {}))
	var stock := _stock_view(machine)
	var queue := _dictionary_array(machine.get("pending_queue", []))
	var crumbs := _dictionary_array(ui_state.get("scratch_crumbs", []))
	var discovered := _string_array(run_state.narrative_flags.get("scratch_ticket_types_discovered", [])) if run_state != null else []
	var collection_complete := discovered.size() >= COLLECTION_TOTAL
	var last_dispense_id := str(machine.get("last_dispense_id", ""))
	var last_file_id := str(machine.get("last_file_id", ""))
	var reduce_motion := _reduce_motion_enabled(ui_state)
	var compact_mode := _small_screen_enabled(ui_state)
	var compact_tab := str(ui_state.get("scratch_compact_tab", "ticket" if not active_ticket.is_empty() else "machine"))
	if compact_tab not in ["machine", "ticket"]:
		compact_tab = "ticket" if not active_ticket.is_empty() else "machine"
	var sweep_duration := 0 if reduce_motion else SWEEP_DURATION_MSEC
	_configure_active_ticket_layout(active_ticket, compact_mode)
	var result_ready := bool(active_ticket.get("result_ready", false))
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
		"scratch_stock_available": _stock_total(machine),
		"scratch_restock_interval_minutes": RESTOCK_INTERVAL_MINUTES,
		"scratch_restock_schedule_public": false,
		"scratch_scalper_present": bool(machine.get("scalper_present", false)),
		"scratch_ticket": active_ticket,
		"scratch_queue": queue,
		"scratch_queue_count": queue.size(),
		"scratch_result_ready": result_ready,
		"scratch_result_summary": _ticket_result_summary(active_ticket),
		"scratch_result_reason": _ticket_win_reason(active_ticket) if result_ready else "",
		"scratch_pending_payout": _pending_payout(machine),
		"scratch_current_winnings": _visible_pending_payout(machine),
		"scratch_active_price": int(active_ticket.get("price", 0)),
		"scratch_winner_count": _dictionary_array(machine.get("winner_pile", [])).size(),
		"scratch_loser_count": _dictionary_array(machine.get("loser_pile", [])).size() + maxi(0, int(machine.get("loser_archive_count", 0))),
		"scratch_winner_pile": machine.get("winner_pile", []),
		"scratch_loser_pile": machine.get("loser_pile", []),
		"scratch_last_settled_ticket": _copy_dict(machine.get("last_settled_ticket", {})),
		"scratch_last_settled_pile": str(machine.get("last_settled_pile", "")),
		"scratch_machine_style": "physical_lottery_vending_cabinet",
		"scratch_machine_art_features": ["floor_unit", "jackpot_marquee", "glass_stock_rows", "branded_side_panel", "selection_buttons", "dispensing_tray", "waste_basket", "cabinet_lighting"],
		"scratch_ticket_face_style": "strict_three_layer_printed_ticket",
		"scratch_ticket_render_layers": _ticket_render_layers(active_ticket),
		"scratch_foil_style_id": _ticket_foil_style_id(active_ticket),
		"scratch_mask_kind": str(_dict_ref(active_ticket.get("scratch", {})).get("mask_kind", "")),
		"scratch_discard_rule": "Discarded winners are filed safely and remain payable at the clerk.",
		"scratch_discard_interaction": "Deliberately drag the ticket into the highlighted basket opening.",
		"scratch_discard_available": not active_ticket.is_empty(),
		"scratch_dispense_animation": not last_dispense_id.is_empty(),
		"scratch_crumbs": crumbs,
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_drag_origin": ui_state.get("scratch_drag_origin", Vector2.ZERO),
		"scratch_trash_armed": bool(ui_state.get("scratch_trash_armed", false)),
		"scratch_discard_drag_progress": float(ui_state.get("scratch_discard_drag_progress", 0.0)),
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
		"scratch_collection_complete": collection_complete,
		"scratch_collection_status": "FULL SET FOUND" if collection_complete else "%d/%d PRINTS FOUND" % [discovered.size(), COLLECTION_TOTAL],
		"scratch_xray_peeks": _dictionary_array(active_ticket.get("xray_peeks", [])) if result_ready else [],
		"scratch_fortune": str(active_ticket.get("fortune_tier", "")) if result_ready else "",
		"scratch_penalty_shields": int(machine.get("penalty_shields_remaining", 0)),
		"scratch_rules": "%s Winners wait for the clerk." % _ticket_play_label(str(active_ticket.get("type_id", "")), _dict_ref(active_ticket.get("mechanic", {}))) if not active_ticket.is_empty() else _machine_empty_rules(machine, stock),
		"surface_animation_channels": [
			GameModule.surface_animation_channel(DISPENSE_CHANNEL, last_dispense_id, DISPENSE_DURATION_MSEC, int(machine.get("dispense_started_msec", 0)), {"metadata": {"ticket_id": str(active_ticket.get("id", "")), "slot": int(machine.get("last_dispense_slot", 0))}}),
			GameModule.surface_animation_channel(FILE_CHANNEL, last_file_id, FILE_DURATION_MSEC, int(machine.get("file_started_msec", 0)), {"metadata": {"pile": str(machine.get("last_settled_pile", ""))}}),
			GameModule.surface_animation_channel(SWEEP_CHANNEL, str(machine.get("last_sweep_id", "")), sweep_duration, int(machine.get("sweep_started_msec", 0)), {"metadata": {"region": str(machine.get("last_sweep_section", ""))}}),
		],
		"surface_ui_protected_regions": [
			{"x": MACHINE_RECT.position.x, "y": MACHINE_RECT.position.y, "w": MACHINE_RECT.size.x, "h": MACHINE_RECT.size.y},
			{"x": STATUS_HUD_RECT.position.x, "y": STATUS_HUD_RECT.position.y, "w": STATUS_HUD_RECT.size.x, "h": STATUS_HUD_RECT.size.y},
			{"x": active_ticket_rect.position.x, "y": active_ticket_rect.position.y, "w": active_ticket_rect.size.x, "h": active_ticket_rect.size.y},
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "scratch_ticket_machine",
			"action_cues": {BUY_ACTION: "ticket_dispenser", SCRATCH_ALL_ACTION: "ticket_peel", FILE_TICKET_ACTION: "paper_peel", SCRATCH_POP_CUE: SCRATCH_POP_CUE},
		}),
	})


func surface_pointer_uses_lightweight_ui_state(surface_action: String) -> bool:
	return surface_action == SCRUB_ACTION


func draw_surface(surface, state: Dictionary, render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "scratch_tickets":
		return false
	surface.surface_begin_design_space(SURFACE_DESIGN_SIZE)
	if bool(state.get("scratch_compact_mode", false)):
		var compact_tab := str(state.get("scratch_compact_tab", "machine"))
		_draw_compact_tabs(surface, compact_tab)
		if compact_tab == "machine":
			MachineRendererScript.draw(surface, state, MACHINE_RECT)
		else:
			_draw_ticket(surface, state, render_context)
			_draw_surface_hud(surface, state)
			_draw_dispense_animation(surface, state)
			_draw_file_animation(surface, state)
	else:
		MachineRendererScript.draw(surface, state, MACHINE_RECT)
		_draw_ticket(surface, state, render_context)
		_draw_surface_hud(surface, state)
		_draw_dispense_animation(surface, state)
		_draw_file_animation(surface, state)
	return true


func _ticket_render_layers(ticket: Dictionary) -> Array:
	if ticket.is_empty():
		return []
	return ["background", "icons", "foil"]


func _ticket_foil_style_id(ticket: Dictionary) -> String:
	if ticket.is_empty():
		return ""
	return FoilRendererScript.style_id(ticket)


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	match surface_action:
		"scratch_compact_machine", "scratch_compact_ticket":
			var tab_state := ui_state.duplicate(false)
			tab_state["scratch_compact_tab"] = "machine" if surface_action.ends_with("machine") else "ticket"
			return GameModule.surface_command({"ui_state": tab_state, "message": "Ticket machine." if surface_action.ends_with("machine") else "Scratch surface."})
		"scratch_buy":
			var stock := _dictionary_array(machine.get("stock", []))
			var quantity := 1 + maxi(0, int(index / 100))
			var stock_index := posmod(index, 100)
			if stock_index < 0 or stock_index >= stock.size():
				return GameModule.surface_command({"message": "That vending slot is empty."})
			var slot: Dictionary = stock[stock_index]
			var price := maxi(1, int(slot.get("price", 1)))
			if int(slot.get("remaining", 0)) < quantity:
				return GameModule.surface_command({"message": "%s is sold out." % str(slot.get("display_name", "That ticket"))})
			if run_state.bankroll < price * quantity:
				return GameModule.surface_command({"message": "You need $%d for that stack." % (price * quantity)})
			var next_state := ui_state.duplicate(true)
			next_state["scratch_stock_index"] = stock_index
			next_state["scratch_buy_quantity"] = quantity
			next_state["scratch_compact_tab"] = "ticket"
			return GameModule.surface_command({
				"ui_state": next_state,
				"action_id": BUY_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"set_stake": price * quantity,
				"selected_index": stock_index,
			})
		SCRATCH_ALL_ACTION:
			var active_ticket := _dict_ref(machine.get("active_ticket", {}))
			if active_ticket.is_empty():
				return GameModule.surface_command({"message": "Buy a ticket first."})
			_reveal_all(machine)
			_write_machine_state(environment, machine, run_state)
			return GameModule.surface_command({
				"environment_changed": true,
				"message": "The remaining latex crumbles away. Read the result, then click the ticket to file it.",
				"surface_audio_cue": "ticket_win" if int(active_ticket.get("payout", 0)) > 0 else SCRATCH_POP_CUE,
			})
		FILE_TICKET_ACTION:
			if _dict_ref(machine.get("active_ticket", {})).is_empty():
				return GameModule.surface_command({"message": "There is no ticket to file."})
			if not _ticket_complete(_dict_ref(machine.get("active_ticket", {}))):
				return GameModule.surface_command({"message": "Scratch every box before filing."})
			return GameModule.surface_command({
				"action_id": SETTLE_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"preserve_surface_ui_state": false,
				"message": "Ticket filed.",
			})
		DISCARD_TICKET_ACTION:
			if _dict_ref(machine.get("active_ticket", {})).is_empty():
				return GameModule.surface_command({"message": "There is no ticket to discard."})
			var discard_state := ui_state.duplicate(false)
			discard_state["scratch_discard_unfinished"] = true
			return GameModule.surface_command({
				"ui_state": discard_state,
				"action_id": SETTLE_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"preserve_surface_ui_state": false,
				"message": "Ticket dropped in the waste basket.",
			})
	return {"handled": false}


func surface_pointer_command(surface_action: String, _index: int, phase: String, board_position: Vector2, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if surface_action != SCRUB_ACTION:
		return {"handled": false}
	var next_state := ui_state
	var machine := _machine_state_for_pointer(run_state, environment)
	if phase == "begin":
		next_state["scratch_drag_active"] = true
		next_state["scratch_drag_moved"] = false
		next_state["scratch_last_pointer"] = board_position
		next_state["scratch_drag_origin"] = board_position
		next_state["scratch_trash_armed"] = false
		next_state["scratch_discard_drag_progress"] = 0.0
		next_state["scratch_crumbs"] = []
		return _scratch_pointer_surface_command(machine, next_state)
	if phase == "end":
		var drag_origin: Vector2 = next_state.get("scratch_drag_origin", board_position)
		var drop_rect := MachineRendererScript.waste_basket_drop_rect(MACHINE_RECT)
		var deliberate_drop := bool(next_state.get("scratch_drag_moved", false))
		deliberate_drop = deliberate_drop and bool(next_state.get("scratch_trash_armed", false))
		deliberate_drop = deliberate_drop and drag_origin.distance_to(board_position) >= DISCARD_DROP_DISTANCE
		deliberate_drop = deliberate_drop and drop_rect.has_point(board_position)
		next_state["scratch_drag_active"] = false
		next_state.erase("scratch_last_pointer")
		next_state.erase("scratch_drag_origin")
		next_state["scratch_trash_armed"] = false
		next_state["scratch_discard_drag_progress"] = 0.0
		next_state["scratch_crumbs"] = []
		if deliberate_drop and not _dict_ref(machine.get("active_ticket", {})).is_empty():
			next_state["scratch_discard_unfinished"] = true
			return GameModule.surface_command({
				"ui_state": next_state,
				"action_id": SETTLE_ACTION,
				"action_kind": "legal",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"preserve_surface_ui_state": false,
				"message": "Ticket swiped into the waste basket.",
				"surface_audio_loop_stop": SCRATCH_AUDIO_LOOP,
				"surface_audio_cue": "paper_peel",
			})
		_write_machine_state(environment, machine, run_state, false)
		return _scratch_pointer_surface_command(machine, next_state, {"surface_audio_loop_stop": SCRATCH_AUDIO_LOOP})
	if phase != "move" or not bool(next_state.get("scratch_drag_active", false)):
		return _scratch_pointer_surface_command(machine, next_state)
	var previous: Vector2 = next_state.get("scratch_last_pointer", board_position)
	next_state["scratch_last_pointer"] = board_position
	if previous.distance_squared_to(board_position) < 2.25:
		return _scratch_pointer_surface_command(machine, next_state)
	next_state["scratch_drag_moved"] = true
	var drag_origin: Vector2 = next_state.get("scratch_drag_origin", previous)
	var active_ticket := _dict_ref(machine.get("active_ticket", {}))
	var discard_progress := _discard_drag_progress(drag_origin, board_position, active_ticket)
	next_state["scratch_discard_drag_progress"] = discard_progress
	if discard_progress >= 0.52:
		next_state["scratch_trash_armed"] = true
	var scratch_result := _scratch_segment(machine, previous, board_position)
	if int(scratch_result.get("erased_samples", 0)) <= 0:
		return _scratch_pointer_surface_command(machine, next_state, {"surface_audio_loop_stop": SCRATCH_AUDIO_LOOP})
	var reduce_motion := _reduce_motion_enabled(next_state)
	next_state["scratch_crumbs"] = [] if reduce_motion else _crumbs_for_segment(previous, board_position, int(scratch_result.get("erased_samples", 0)))
	var swept_sections: Array = scratch_result.get("swept_sections", []) if typeof(scratch_result.get("swept_sections", [])) == TYPE_ARRAY else []
	if not swept_sections.is_empty():
		machine["sweep_started_msec"] = GameModule.deterministic_time_msec(run_state, next_state)
	var completed := bool(scratch_result.get("ticket_complete", false))
	if completed:
		_write_machine_state(environment, machine, run_state, false)
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
	if not swept_sections.is_empty():
		command["surface_audio_cue"] = SCRATCH_POP_CUE
	if completed:
		command.erase("surface_audio_loop_start")
		command["surface_audio_loop_stop"] = SCRATCH_AUDIO_LOOP
		command["environment_changed"] = true
		command["message"] = "%s Click the ticket to file it." % str(scratch_result.get("message", "Result revealed."))
		if int(_dict_ref(machine.get("active_ticket", {})).get("payout", 0)) > 0:
			command["surface_audio_cue"] = "ticket_win"
	elif penalty > 0:
		command.erase("surface_audio_loop_start")
		command["surface_audio_loop_stop"] = SCRATCH_AUDIO_LOOP
		command["action_id"] = REVEAL_ACTION
		command["action_kind"] = "legal"
		command["direct_resolve"] = true
		command["skip_stake_validation"] = true
	return _scratch_pointer_surface_command(machine, next_state, command, not swept_sections.is_empty())


func _scratch_pointer_surface_command(machine: Dictionary, ui_state: Dictionary, extra: Dictionary = {}, refresh_animation_channels: bool = false) -> Dictionary:
	var command := extra
	var active_ticket: Dictionary = machine.get("active_ticket", {}) if typeof(machine.get("active_ticket", {})) == TYPE_DICTIONARY else {}
	var pending_queue: Array = machine.get("pending_queue", []) if typeof(machine.get("pending_queue", [])) == TYPE_ARRAY else []
	var reduce_motion := _reduce_motion_enabled(ui_state)
	command["handled"] = true
	command["ui_state"] = ui_state
	command["surface_transient"] = true
	var patch := {
		"scratch_ticket": active_ticket,
		"scratch_queue": pending_queue,
		"scratch_queue_count": pending_queue.size(),
		"scratch_result_ready": bool(active_ticket.get("result_ready", false)),
		"scratch_result_summary": _ticket_result_summary(active_ticket),
		"scratch_result_reason": _ticket_win_reason(active_ticket) if bool(active_ticket.get("result_ready", false)) else "",
		"scratch_current_winnings": _visible_pending_payout(machine),
		"scratch_crumbs": ui_state.get("scratch_crumbs", []),
		"scratch_drag_active": bool(ui_state.get("scratch_drag_active", false)),
		"scratch_last_pointer": ui_state.get("scratch_last_pointer", Vector2.ZERO),
		"scratch_drag_origin": ui_state.get("scratch_drag_origin", Vector2.ZERO),
		"scratch_trash_armed": bool(ui_state.get("scratch_trash_armed", false)),
		"scratch_discard_drag_progress": float(ui_state.get("scratch_discard_drag_progress", 0.0)),
		"scratch_penalty_shields": int(machine.get("penalty_shields_remaining", 0)),
		"scratch_reduce_motion": reduce_motion,
	}
	if refresh_animation_channels:
		patch["surface_animation_channels"] = _scratch_animation_channels(machine, reduce_motion)
	command["surface_state_patch"] = patch
	return command


func _discard_drag_progress(origin: Vector2, point: Vector2, ticket: Dictionary = {}) -> float:
	var pointer_frame := _ticket_art_frame(ticket, active_ticket_rect) if not ticket.is_empty() else active_ticket_rect
	if not pointer_frame.grow(4.0).has_point(origin):
		return 0.0
	var basket := MachineRendererScript.waste_basket_drop_rect(MACHINE_RECT)
	var approach := basket.grow(46.0)
	if not approach.has_point(point):
		return 0.0
	var leftward_distance := origin.x - point.x
	var total_distance := origin.distance_to(point)
	if leftward_distance < DISCARD_ARM_DISTANCE or total_distance < DISCARD_ARM_DISTANCE:
		return 0.0
	var travel_progress := inverse_lerp(DISCARD_ARM_DISTANCE, DISCARD_DROP_DISTANCE, total_distance)
	var target_progress := 1.0 - clampf(point.distance_to(basket.get_center()) / maxf(1.0, approach.size.length() * 0.5), 0.0, 1.0)
	return clampf(maxf(travel_progress, target_progress), 0.0, 1.0)


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id != BUY_ACTION:
		return 0
	var machine := _ensure_machine_state(run_state, environment, false)
	var stock := _dictionary_array(machine.get("stock", []))
	var index := int(ui_state.get("scratch_stock_index", 0))
	var quantity := maxi(1, int(ui_state.get("scratch_buy_quantity", 1)))
	if index < 0 or index >= stock.size():
		return maxi(0, stake)
	return maxi(1, int((stock[index] as Dictionary).get("price", stake))) * quantity


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	match action_id:
		BUY_ACTION:
			return _resolve_purchase(stake, run_state, environment, rng, ui_state)
		REVEAL_ACTION:
			return _resolve_reveal(run_state, environment, rng, false, false)
		SETTLE_ACTION:
			return _resolve_reveal(run_state, environment, rng, true, bool(ui_state.get("scratch_discard_unfinished", false)))
	return _scratch_empty_result(action_id, environment, "That scratch-ticket action is unavailable.")


func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _ensure_machine_state(run_state, environment, false)
	var payout := _pending_payout(machine)
	var winners := _dictionary_array(machine.get("winner_pile", [])).size()
	var label := _redeemer_label(environment)
	var objects: Array = [{
		"id": REDEEM_HOOK_ID,
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"label": label,
		"short_description": "Turns the room's winning scratchers into cash.",
		"enabled": true,
		"recovery": payout > 0,
		"action_summary": "Cash %d winner%s for $%d." % [winners, "" if winners == 1 else "s", payout] if winners > 0 else "No scratched winners to cash.",
		"effect_summary": "$%d waits at the counter." % payout if payout > 0 else "Scratch a winner, then bring it here.",
		"risk_summary": "Large prizes draw the clerk's attention.",
		"cost_summary": "",
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "service",
		"unique_object_class": "lottery_redemption_clerk",
		"unique_object_priority": 120 if payout > 0 else 90,
		"available_actions": [{"id": REDEEM_ACTION_ID, "label": "Cash In"}],
		"confirm_action_id": REDEEM_ACTION_ID,
	}]
	if bool(machine.get("scalper_present", false)):
		var knows_schedule := bool(machine.get("scalper_knows_schedule", false))
		var dialogue_id := SCALPER_DIALOGUE_KNOWS_ID if knows_schedule else SCALPER_DIALOGUE_OBLIVIOUS_ID
		objects.append({
			"id": SCALPER_HOOK_ID,
			"object_id": "dialogue:%s" % SCALPER_HOOK_ID,
			"label": "Scalper",
			"short_description": "A reseller camps beside the empty scratch-ticket machine.",
			"enabled": true,
			"action_summary": "Ask about the machine's restock.",
			"effect_summary": "He may know the next release time—or pretend he does not.",
			"risk_summary": "Every slot is empty while he is watching it.",
			"cost_summary": "",
			"dialogue_id": dialogue_id,
			"dialogue_summary": _scalper_dialogue_summary(machine, knows_schedule),
			"visual_key": "scalper",
			"visual_type": "character",
			"icon_key": "clerk_chat",
			"unique_object_class": SCALPER_HOOK_ID,
			"unique_object_priority": 130,
			"available_actions": [{"id": "start_dialogue", "label": "Talk"}],
			"confirm_action_id": "start_dialogue",
		})
	return objects


func environment_action_command(hook_id: String, action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	if hook_id != REDEEM_HOOK_ID or action_id != REDEEM_ACTION_ID:
		return {"handled": false}
	return {"handled": true, "result": _resolve_redemption(run_state, environment, rng)}


func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var active := _dict_ref(machine.get("active_ticket", {}))
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
	var stock := _dictionary_array(machine.get("stock", []))
	var stock_index := int(ui_state.get("scratch_stock_index", 0))
	var quantity := maxi(1, int(ui_state.get("scratch_buy_quantity", 1)))
	if stock_index < 0 or stock_index >= stock.size():
		return _scratch_empty_result(BUY_ACTION, environment, "That vending slot is empty.")
	var slot: Dictionary = stock[stock_index]
	var price := maxi(1, int(slot.get("price", 1)))
	if int(slot.get("remaining", 0)) < quantity:
		return _scratch_empty_result(BUY_ACTION, environment, "%s is sold out." % str(slot.get("display_name", "That ticket")))
	var total_price := price * quantity
	if run_state.bankroll < total_price:
		return _scratch_empty_result(BUY_ACTION, environment, "Not enough cash for this ticket stack.")
	var ticket_type := _ticket_type(str(slot.get("type_id", "")))
	if ticket_type.is_empty():
		return _scratch_empty_result(BUY_ACTION, environment, "That ticket type is unavailable.")
	var first_purchase_number := int(machine.get("purchased_count", 0)) + 1
	var luck := run_state.effective_luck() if run_state != null else 0
	var xray_capacity := maxi(0, run_state.item_effect_total("scratch_peek_cells", get_family()) if run_state != null else 0)
	var tarot_strength := maxi(0, run_state.item_effect_total("scratch_fortune_hint", get_family()) if run_state != null else 0)
	var shield_capacity := maxi(0, run_state.item_effect_total("scratch_penalty_shields", get_family()) if run_state != null else 0)
	var queue := _dictionary_array(machine.get("pending_queue", []))
	var purchased_tickets: Array = []
	var active_value: Variant = machine.get("active_ticket", {})
	var has_active_ticket := typeof(active_value) == TYPE_DICTIONARY and not (active_value as Dictionary).is_empty()
	for offset in range(quantity):
		var purchase_number := first_purchase_number + offset
		var ticket_rng := rng if quantity == 1 and rng != null else (rng.fork("scratch-purchase:%d" % purchase_number) if rng != null else _seeded_rng("scratch-purchase:%d" % purchase_number))
		var ticket := _roll_ticket(ticket_type, ticket_rng, luck, "%s:%d" % [str(environment.get("id", "room")), purchase_number], false)
		_stamp_ticket_origin(ticket, environment)
		if xray_capacity > 0:
			ticket["xray_peeks"] = _xray_peeks(ticket, mini(xray_capacity, ticket_rng.randi_range(2, 3)), ticket_rng)
		if tarot_strength > 0:
			ticket["fortune_tier"] = _fortune_tier(ticket)
		_reserve_penalty_shields(ticket, shield_capacity)
		purchased_tickets.append(ticket)
		if not has_active_ticket:
			# Queued tickets intentionally stay compact until they reach the table,
			# but the visible ticket must have its authored mask before its first
			# frame. Initializing it on the first drag makes the foil suddenly pop
			# into existence over the background artwork.
			_ensure_ticket_regions(ticket)
			machine["active_ticket"] = ticket
			machine["penalty_shields_remaining"] = shield_capacity
			has_active_ticket = true
		else:
			queue.append(ticket)
	slot["remaining"] = maxi(0, int(slot.get("remaining", 0)) - quantity)
	stock[stock_index] = slot
	machine["stock"] = stock
	machine["pending_queue"] = queue
	machine["purchased_count"] = first_purchase_number + quantity - 1
	var first_ticket: Dictionary = purchased_tickets[0] if not purchased_tickets.is_empty() else {}
	machine["last_ticket_id"] = str(first_ticket.get("id", ""))
	machine["last_dispense_id"] = "scratch-dispense:%s" % str(first_ticket.get("id", first_purchase_number))
	machine["last_dispense_slot"] = stock_index
	machine["dispense_started_msec"] = GameModule.deterministic_time_msec(run_state, ui_state)
	_write_machine_state(environment, machine, run_state, false)
	var message := "%s%s paid for now. Scratch one at a time." % [str(first_ticket.get("display_name", "A scratch ticket")), " x%d" % quantity if quantity > 1 else ""]
	if not _dictionary_array(first_ticket.get("xray_peeks", [])).is_empty():
		message += " X-Ray Glasses ghost %d symbols through the coating." % _dictionary_array(first_ticket.get("xray_peeks", [])).size()
	if not str(first_ticket.get("fortune_tier", "")).is_empty():
		message += " The tarot reads %s." % str(first_ticket.get("fortune_tier", "")).to_upper()
	var xray_heat := maxi(0, run_state.item_effect_total("scratch_peek_heat", get_family(), "cheat") if run_state != null and xray_capacity > 0 else 0)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -total_price
	deltas["suspicion_delta"] = xray_heat
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": BUY_ACTION,
		"ticket_id": str(first_ticket.get("id", "")),
		"ticket_type": str(first_ticket.get("type_id", "")),
		"cost": total_price,
		"quantity": quantity,
		"bankroll_delta": -total_price,
		"luck_modifier": luck,
		"outcome_fixed_at_purchase": true,
		"xray_peek_count": _dictionary_array(first_ticket.get("xray_peeks", [])).size(),
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
		"stake": total_price,
		"bankroll_delta": -total_price,
		"suspicion_delta": xray_heat,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	# The live active ticket owns the high-resolution mask. Action results are
	# deep-copied for presentation/history, so return mask-free purchase receipts
	# rather than duplicating 49,152 samples at the purchase boundary.
	var purchase_receipts: Array = []
	for purchased_value in purchased_tickets:
		if typeof(purchased_value) != TYPE_DICTIONARY:
			continue
		var receipt := (purchased_value as Dictionary).duplicate(false)
		for runtime_field in ["latex_mask", "scratch_regions", "sections"]:
			receipt.erase(runtime_field)
		purchase_receipts.append(receipt)
	result["scratch_ticket"] = purchase_receipts[0] if not purchase_receipts.is_empty() else {}
	result["scratch_purchased_tickets"] = purchase_receipts
	result["scratch_buy_quantity"] = quantity
	result["scratch_outcome_fixed_at_purchase"] = true
	result["suppress_music_outcome"] = true
	result["surface_audio_cue"] = "ticket_dispenser"
	result["surface_audio_context"] = {"action": "scratch_buy"}
	result["scratch_luck_modifier"] = luck
	result["scratch_xray_peeks"] = _dictionary_array(first_ticket.get("xray_peeks", [])).duplicate(true)
	result["scratch_fortune"] = str(first_ticket.get("fortune_tier", ""))
	result["defer_bankroll_zero_failure"] = true
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_reveal(run_state: RunState, environment: Dictionary, rng: RngStream, settle: bool, discard_unfinished: bool = false) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	var ticket := _dict_ref(machine.get("active_ticket", {}))
	if ticket.is_empty():
		return _scratch_empty_result(SETTLE_ACTION if settle else REVEAL_ACTION, environment, "There is no ticket on the scratch surface.")
	var payout := int(ticket.get("payout", 0))
	var message := "The printed result shows through."
	if settle:
		if not _ticket_complete(ticket) and not discard_unfinished:
			return _scratch_empty_result(SETTLE_ACTION, environment, "Some latex still covers this ticket.")
		ticket["settled"] = true
		ticket["result_ready"] = true
		ticket["discarded_unfinished"] = discard_unfinished
		ticket = MaskScript.compact_settled(ticket)
		var pile_name := "winner_pile" if payout > 0 else "loser_pile"
		var pile := _dictionary_array(machine.get(pile_name, []))
		pile.append(ticket)
		machine[pile_name] = pile
		var queue := _dictionary_array(machine.get("pending_queue", []))
		var next_ticket := {}
		if not queue.is_empty():
			next_ticket = queue.pop_front()
			if typeof(next_ticket) == TYPE_DICTIONARY:
				_ensure_ticket_regions(next_ticket)
		machine["pending_queue"] = queue
		machine["active_ticket"] = next_ticket
		if typeof(next_ticket) == TYPE_DICTIONARY and not (next_ticket as Dictionary).is_empty():
			machine["penalty_shields_remaining"] = maxi(0, int((next_ticket as Dictionary).get("lucky_penny_assist", 0)))
		else:
			machine["penalty_shields_remaining"] = 0
		machine["last_settled_ticket"] = ticket.duplicate(false)
		machine["last_settled_pile"] = pile_name
		machine["last_file_id"] = "scratch-file:%s" % str(ticket.get("id", pile.size()))
		machine["file_started_msec"] = GameModule.deterministic_time_msec(run_state, {})
		if discard_unfinished:
			message = "%s discarded. %s" % [
				str(ticket.get("display_name", "Ticket")),
				"Any winner is filed safely for clerk redemption." if payout > 0 else "No prize was forfeited.",
			]
		else:
			message = "%s: %s %s" % [str(ticket.get("display_name", "Ticket")), _ticket_result_summary(ticket), _ticket_win_reason(ticket)]
		if typeof(next_ticket) == TYPE_DICTIONARY and not (next_ticket as Dictionary).is_empty():
			message += " Next up: %s." % str((next_ticket as Dictionary).get("display_name", "ticket"))
	else:
		ticket["result_ready"] = _ticket_complete(ticket)
		machine["active_ticket"] = ticket
	_write_machine_state(environment, machine, run_state)
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "scratch_ticket_discard" if discard_unfinished else "scratch_ticket_settle" if settle else "scratch_ticket_reveal",
		"game_id": get_id(),
		"action_id": SETTLE_ACTION if settle else REVEAL_ACTION,
		"ticket_id": str(ticket.get("id", "")),
		"ticket_type": str(ticket.get("type_id", "")),
		"pending_clerk_payout": payout if settle else 0,
		"discarded_unfinished": discard_unfinished,
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
	result["defer_bankroll_zero_failure"] = not _dict_ref(machine.get("active_ticket", {})).is_empty() or not _dictionary_array(machine.get("pending_queue", [])).is_empty() or _pending_payout(machine) > 0
	result["scratch_discarded_unfinished"] = discard_unfinished
	result["scratch_discard_preserved_winner"] = discard_unfinished and payout > 0
	result["suppress_music_outcome"] = settle
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
	return result


func _redeemer_label(environment: Dictionary) -> String:
	var scene_type := str(environment.get("visual_context", {}).get("scene_type", ""))
	if scene_type == "bar" or str(environment.get("archetype_id", "")) == "bar":
		return "Bartender"
	return "Lottery Clerk"


func _generate_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var day_key := int(environment.get("generated_day", environment.get("day", 0)))
	var stream_key := "scratch-stock:%s:day:%d" % [str(environment.get("id", "room")), day_key]
	var root_rng := rng if rng != null else _seeded_rng("scratch-stock-root:%s" % str(environment.get("id", "room")))
	var machine_rng := root_rng.fork(stream_key)
	var current_absolute_minute := maxi(0, run_state.game_clock_minutes) if run_state != null else maxi(0, day_key * 1440)
	var restock_phase_minute := machine_rng.randi_range(0, RESTOCK_INTERVAL_MINUTES - 1)
	var stock: Array = []
	for ticket_type_value in _ticket_types():
		var ticket_type: Dictionary = ticket_type_value
		var count_range := _int_array(ticket_type.get("stock_count", [0, 5]))
		var maximum := clampi(int(count_range[1]) if count_range.size() > 1 else 5, 1, 5)
		var stock_roll := machine_rng.randi_range(0, 19)
		var remaining := 0 if stock_roll < 15 else mini(maximum, stock_roll - 14)
		stock.append({
			"type_id": str(ticket_type.get("id", "")),
			"display_name": str(ticket_type.get("display_name", "Ticket")),
			"price": maxi(1, int(ticket_type.get("price", 1))),
			"remaining": remaining,
			"capacity": maximum,
			"stock_weight": maxi(1, int(ticket_type.get("stock_weight", 1))),
			"size_id": str(ticket_type.get("size_id", "medium_square")),
			"palette": _copy_dict(_copy_dict(ticket_type.get("face", {})).get("palette", {})),
		})
	var initially_empty := _stock_total_from_rows(stock) <= 0
	var initial_scalper_present := initially_empty and run_state != null and not run_state.is_tutorial_run()
	var initial_scalper_knows := initial_scalper_present and scalper_knows_for_roll(machine_rng.randi_range(0, 99))
	var initial_visit_token := _scratch_visit_token(run_state, environment) if initial_scalper_present else ""
	return {
		"schema": "scratch_ticket_machine_state",
		"version": MACHINE_STATE_VERSION,
		"machine_name": "Highway Scratch Center",
		"stock_day": int(environment.get("generated_day", environment.get("day", 0))),
		"stock_stream_key": stream_key,
		"stock_weighting": "full_roster_75_out_of_stock_1_to_5",
		"restock_interval_minutes": RESTOCK_INTERVAL_MINUTES,
		"restock_distribution": "50_percent_0_40_percent_1_10_percent_2",
		"restock_phase_minute": restock_phase_minute,
		"restock_cursor_absolute_minute": current_absolute_minute,
		"next_restock_absolute_minute": _next_restock_after(current_absolute_minute, restock_phase_minute),
		"last_restock_scheduled_count": 0,
		"last_restock_stocked_count": 0,
		"restock_event_count": 0,
		"scalper_visit_chance_percent": SCALPER_VISIT_CHANCE_PERCENT,
		# A machine generated with no sellable tickets always has a scalper already
		# camping it. Stocked machines keep the normal seeded visit chance below.
		"scalper_present": initial_scalper_present,
		"scalper_knows_schedule": initial_scalper_knows,
		"scalper_visit_token": initial_visit_token,
		"scalper_cleared_count": 0,
		"scalper_intercepted_restock_count": 0,
		"stock": stock,
		"environment_hooks": [{
			"id": REDEEM_HOOK_ID,
			"kind": "redeemer",
			"label": "Scratch-Ticket Clerk",
			"unique_object_class": "scratch_ticket_clerk",
			"unique_object_priority": 100,
		}, {
			"id": SCALPER_HOOK_ID,
			"kind": "dialogue",
			"label": "Scalper",
			"object_id": "dialogue:%s" % SCALPER_HOOK_ID,
			"unique_object_class": SCALPER_HOOK_ID,
			"unique_object_priority": 130,
		}],
		"active_ticket": {},
		"pending_queue": [],
		"winner_pile": [],
		"loser_pile": [],
		"loser_archive_count": 0,
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


func _roll_ticket(ticket_type: Dictionary, rng: RngStream, luck_modifier: int, purchase_key: String, initialize_mask: bool = true) -> Dictionary:
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
	if initialize_mask:
		_initialize_ticket_mask(ticket, ticket_type)
	return ticket


func _definition_top_prize(ticket_type: Dictionary) -> int:
	var top := 0
	for prize_value in _dictionary_array(ticket_type.get("prize_table", [])):
		top = maxi(top, int((prize_value as Dictionary).get("payout", 0)))
	return top


func _initialize_ticket_mask(ticket: Dictionary, ticket_type: Dictionary) -> void:
	MaskScript.initialize(ticket, ticket_type)


func _ticket_art_regions(ticket: Dictionary) -> Array:
	return RegionModelScript.build(ticket)

func _ensure_ticket_regions(ticket: Dictionary) -> void:
	MaskScript.ensure(ticket)


func _sections_from_regions(regions: Array) -> Array:
	return MaskScript.sections_from_regions(regions)

func _build_mechanic_content(mechanic_type: String, mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	match mechanic_type:
		"match_two_of_three":
			return _build_two_fer_content(mechanic, prize, rng)
		"key_number_match":
			return _build_lucky_sevens_content(prize, rng)
		"tic_tac_toe":
			return _build_tic_tac_gold_content(prize, rng)
		"crossword":
			return _build_crossword_content(mechanic, prize, rng)
		"bingo":
			return _build_bingo_content(prize, rng)
		"beat_dealer_poker":
			return _build_holdem_content(mechanic, prize, rng)
		"multi_game_vault":
			return _build_vault_content(prize, rng)
	return {"spots": []}


func _build_two_fer_content(mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	var match_symbol := str(prize.get("match_symbol", ""))
	var symbol_pool: Array = ["CLOVER", "BELL", "STAR", "2FER"]
	var symbols: Array = ["CLOVER", "BELL", "STAR"]
	if not match_symbol.is_empty():
		symbol_pool.erase(match_symbol)
		var other := str(symbol_pool[rng.randi_range(0, symbol_pool.size() - 1)])
		symbols = [match_symbol, match_symbol, other]
	else:
		_shuffle_array(symbol_pool, rng)
		symbols = [symbol_pool[0], symbol_pool[1], symbol_pool[2]]
	_shuffle_array(symbols, rng)
	var spots: Array = []
	for index in range(symbols.size()):
		spots.append({"index": index, "section_id": "play", "symbol": str(symbols[index]), "role": "pair_spot"})
	return {"spots": spots, "symbols": symbols, "legend": _copy_dict(mechanic.get("legend", {}))}


func _build_lucky_sevens_content(prize: Dictionary, rng: RngStream) -> Dictionary:
	var winning_seven := bool(prize.get("winning_seven", false))
	var bonus := bool(prize.get("bonus", false))
	var bonus_prize := 50 if bonus else 0
	var number_pool: Array = []
	for number in range(1, 41):
		if number != 7:
			number_pool.append(number)
	_shuffle_array(number_pool, rng)
	var winning_numbers: Array = [7, number_pool.pop_back()] if winning_seven else [number_pool.pop_back(), number_pool.pop_back()]
	var your_numbers: Array = []
	while your_numbers.size() < 6:
		var candidate := int(number_pool.pop_back())
		if not winning_numbers.has(candidate):
			your_numbers.append(candidate)
	var your_seven_count := clampi(int(prize.get("your_seven_count", 0)), 0, 6)
	var match_count := clampi(int(prize.get("match_count", 0)), 0, 6 - your_seven_count)
	for index in range(your_seven_count):
		your_numbers[index] = 7
	for index in range(match_count):
		your_numbers[your_seven_count + index] = int(winning_numbers[index % winning_numbers.size()])
	_shuffle_array(your_numbers, rng)
	var winner_count := 6 if winning_seven else your_seven_count + match_count
	var prizes := _split_amount(maxi(0, int(prize.get("payout", 0)) - bonus_prize), winner_count)
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
	var bonus_spot := {"index": spots.size(), "section_id": "bonus", "number": 7 if bonus else int(number_pool.pop_back()), "prize": bonus_prize, "winner": bonus, "role": "bonus_number"}
	spots.append(bonus_spot)
	return {"spots": spots, "winning_numbers": winning_numbers, "your_numbers": your_spots, "winning_seven": winning_seven, "bonus": bonus, "bonus_prize": bonus_prize, "bonus_number": int(bonus_spot.get("number", 0))}


func _build_tic_tac_gold_content(prize: Dictionary, rng: RngStream) -> Dictionary:
	var requested_lines := clampi(int(prize.get("line_count", 0)), 0, 8)
	var marks := _tic_marks_for_line_count_with_rng(requested_lines, rng)
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
		spots.append({"index": index, "section_id": "board", "mark": "WIN" if bool(marks[index]) else "MISS", "role": "board_mark", "variant": rng.randi_range(0, 7)})
	spots.append({"index": 9, "section_id": "bonus", "mark": "GOLD" if bonus else "DUST", "prize": bonus_prize, "role": "bonus", "variant": rng.randi_range(0, 7)})
	return {"spots": spots, "marks": marks, "completed_lines": completed, "line_prizes": line_prizes, "bonus": bonus, "bonus_prize": bonus_prize, "print_variant": rng.randi_range(1000, 9999)}


func _build_crossword_content(mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	var words := _crossword_layout_words(_string_array(mechanic.get("words", [])))
	var completion_order := words.duplicate(false)
	_shuffle_array(completion_order, rng)
	var completed_count := clampi(int(prize.get("word_count", 0)), 0, words.size())
	var completed_words: Array = []
	for index in range(completed_count):
		completed_words.append(completion_order[index])
	var bank: Array = []
	for word_value in completed_words:
		for character_index in range(str(word_value).length()):
			var letter := str(word_value).substr(character_index, 1)
			if not bank.has(letter):
				bank.append(letter)
	var fillers: Array = []
	for filler_index in range("ETAOINSHRDLUCMFWYP".length()):
		fillers.append("ETAOINSHRDLUCMFWYP".substr(filler_index, 1))
	_shuffle_array(fillers, rng)
	for filler_value in fillers:
		var filler := str(filler_value)
		if not bank.has(filler):
			bank.append(filler)
		if bank.size() >= 18:
			break
	_shuffle_array(bank, rng)
	var spots: Array = []
	for index in range(bank.size()):
		spots.append({"index": spots.size(), "section_id": "letter_bank", "letter": str(bank[index]), "bank_index": index, "role": "bank_letter"})
	var cell_map: Dictionary = {}
	for entry in _crossword_layout_entries(words):
		var word := str(entry.get("word", ""))
		var across := str(entry.get("dir", "")) == "across"
		for letter_index in range(word.length()):
			var column := int(entry.get("x", 0)) + (letter_index if across else 0)
			var row := int(entry.get("y", 0)) + (0 if across else letter_index)
			var key := "%d,%d" % [column, row]
			var letter := word.substr(letter_index, 1)
			var cell: Dictionary = cell_map.get(key, {"column": column, "row": row, "letter": letter, "words": [], "complete": false, "matched": bank.has(letter)})
			var cell_words: Array = cell.get("words", []) if typeof(cell.get("words", [])) == TYPE_ARRAY else []
			if not cell_words.has(word):
				cell_words.append(word)
			cell["words"] = cell_words
			cell["complete"] = bool(cell.get("complete", false)) or completed_words.has(word)
			cell["matched"] = bool(cell.get("matched", false)) or bank.has(letter)
			cell_map[key] = cell
	var keys := cell_map.keys()
	keys.sort()
	for key in keys:
		var cell: Dictionary = cell_map[key]
		cell["index"] = spots.size()
		cell["section_id"] = "crossword"
		cell["role"] = "crossword_cell"
		spots.append(cell)
	return {"spots": spots, "letter_bank": bank, "words": words, "completed_words": completed_words, "word_count": completed_count, "legend": _copy_dict(mechanic.get("legend", {})), "crossword_layout": _crossword_layout_entries(words)}


func _crossword_layout_words(fallback_words: Array) -> Array:
	var configured := _string_array(fallback_words)
	var defaults := ["CASH", "HOUSE", "SLOT", "GOLD", "LUCK", "RISK", "VAULT"]
	var words: Array = []
	for default_word in defaults:
		words.append(default_word if configured.has(default_word) else default_word)
	return words


func _crossword_layout_entries(words: Array) -> Array:
	var wanted := _string_array(words)
	var entries := [
		{"word": "CASH", "dir": "across", "x": 1, "y": 1},
		{"word": "HOUSE", "dir": "down", "x": 4, "y": 1},
		{"word": "SLOT", "dir": "across", "x": 4, "y": 4},
		{"word": "GOLD", "dir": "down", "x": 6, "y": 3},
		{"word": "LUCK", "dir": "across", "x": 2, "y": 7},
		{"word": "RISK", "dir": "across", "x": 1, "y": 9},
		{"word": "VAULT", "dir": "down", "x": 9, "y": 2},
	]
	var result: Array = []
	for entry in entries:
		if wanted.has(str((entry as Dictionary).get("word", ""))):
			result.append((entry as Dictionary).duplicate(true))
	return result


func _build_bingo_content(prize: Dictionary, rng: RngStream) -> Dictionary:
	var caller_numbers := _bingo_called_numbers(rng)
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


func _bingo_called_numbers(rng: RngStream = null) -> Array:
	if rng == null:
		return [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 43, 46, 49, 52, 55, 58, 61, 64, 67, 70, 73]
	var result: Array = []
	var counts := [5, 5, 4, 5, 5]
	for column in range(5):
		var pool: Array = []
		for number in range(column * 15 + 1, column * 15 + 16):
			pool.append(number)
		_shuffle_array(pool, rng)
		for index in range(int(counts[column])):
			result.append(pool[index])
	_shuffle_array(result, rng)
	return result


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


func _build_holdem_content(mechanic: Dictionary, prize: Dictionary, rng: RngStream) -> Dictionary:
	var your_rank := str(prize.get("your_rank", "HIGH CARD"))
	var dealer_rank := str(prize.get("dealer_rank", "PAIR"))
	var rank_order := _string_array(mechanic.get("rank_order", []))
	var wild := bool(prize.get("wild", false))
	var base_your_rank := your_rank
	var final_rank_index := rank_order.find(your_rank)
	if wild and final_rank_index > 0:
		base_your_rank = str(rank_order[final_rank_index - 1])
	var your_hand := _poker_hand_for_rank(your_rank, bool(prize.get("pocket_aces", false)), rng)
	var dealer_hand := _poker_hand_for_rank(dealer_rank, false, rng)
	_shuffle_array(your_hand, rng)
	_shuffle_array(dealer_hand, rng)
	var spots: Array = []
	for card_value in your_hand:
		spots.append({"index": spots.size(), "section_id": "your_hand", "card": str(card_value), "role": "your_card"})
	for card_value in dealer_hand:
		spots.append({"index": spots.size(), "section_id": "dealer_hand", "card": str(card_value), "role": "dealer_card"})
	spots.append({"index": spots.size(), "section_id": "wild", "card": "WILD" if wild else "NO WILD", "role": "wild"})
	return {"spots": spots, "your_hand": your_hand, "dealer_hand": dealer_hand, "base_your_rank": base_your_rank, "your_rank": your_rank, "dealer_rank": dealer_rank, "wild": wild, "pocket_aces": bool(prize.get("pocket_aces", false)), "printed_prize": maxi(0, int(prize.get("payout", 0)))}


func _build_vault_content(prize: Dictionary, rng: RngStream) -> Dictionary:
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
	var ladder_base_prizes := _random_split_amount(ladder_base_total, winning_rungs, rng)
	var rung_order := [0, 1, 2, 3, 4]
	_shuffle_array(rung_order, rng)
	var winning_indices: Array = rung_order.slice(0, winning_rungs)
	var ladder: Array = []
	var spots: Array = [{"index": 0, "section_id": "multiplier", "multiplier": multiplier, "role": "multiplier"}]
	var payout_cursor := 0
	for rung in range(5):
		var match_win := winning_indices.has(rung)
		var base_prize := int(ladder_base_prizes[payout_cursor]) if match_win and payout_cursor < ladder_base_prizes.size() else 0
		var multiplied_prize := base_prize * multiplier + (ladder_remainder if payout_cursor == 0 and match_win else 0)
		if match_win:
			payout_cursor += 1
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
			if bool(result.get("bonus", false)) and int(result.get("bonus_number", 0)) == 7:
				total += maxi(0, int(result.get("bonus_prize", 0)))
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


func _tic_marks_for_line_count_with_rng(line_count: int, rng: RngStream) -> Array:
	var candidates: Array = []
	for bits in range(512):
		var marks: Array = []
		for index in range(9):
			marks.append((bits & (1 << index)) != 0)
		if _tic_completed_lines(marks).size() == line_count:
			candidates.append(marks)
	if candidates.is_empty():
		return _tic_marks_for_line_count(line_count)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _poker_hand_for_rank(rank_name: String, pocket_aces: bool, rng: RngStream = null) -> Array:
	var suit_offset := rng.randi_range(0, 3) if rng != null else 0
	var rank_offset := rng.randi_range(0, 7) if rng != null else 0
	if pocket_aces:
		return [_card_code(14, suit_offset), _card_code(14, suit_offset + 1), _card_code(9 + rank_offset % 4, suit_offset + 2), _card_code(5 + rank_offset % 3, suit_offset + 3), _card_code(2 + rank_offset % 2, suit_offset)]
	match rank_name:
		"PAIR":
			var pair_rank := 10 + rank_offset % 4
			return [_card_code(pair_rank, suit_offset), _card_code(pair_rank, suit_offset + 1), _card_code(8, suit_offset + 2), _card_code(5, suit_offset + 3), _card_code(2, suit_offset)]
		"TWO PAIR":
			var high_pair := 11 + rank_offset % 3
			var low_pair := 6 + rank_offset % 3
			return [_card_code(high_pair, suit_offset), _card_code(high_pair, suit_offset + 1), _card_code(low_pair, suit_offset + 2), _card_code(low_pair, suit_offset + 3), _card_code(2, suit_offset)]
		"STRAIGHT":
			var straight_high := 8 + rank_offset % 5
			var straight_hand: Array = []
			for index in range(5):
				straight_hand.append(_card_code(straight_high - index, suit_offset + index))
			return straight_hand
		"FLUSH":
			var flush_hand: Array = []
			for rank in [13, 11, 8, 5 + rank_offset % 2, 2]:
				flush_hand.append(_card_code(rank, suit_offset))
			return flush_hand
		"FULL HOUSE":
			var triple_rank := 10 + rank_offset % 4
			var pair_rank := 4 + rank_offset % 4
			return [_card_code(triple_rank, suit_offset), _card_code(triple_rank, suit_offset + 1), _card_code(triple_rank, suit_offset + 2), _card_code(pair_rank, suit_offset), _card_code(pair_rank, suit_offset + 1)]
		"FOUR KIND":
			var quad_rank := 7 + rank_offset % 7
			var quad_hand: Array = []
			for suit in range(4):
				quad_hand.append(_card_code(quad_rank, suit))
			quad_hand.append(_card_code(2 + rank_offset % 3, suit_offset))
			return quad_hand
		"STRAIGHT FLUSH":
			var flush_high := 8 + rank_offset % 5
			var straight_flush_hand: Array = []
			for index in range(5):
				straight_flush_hand.append(_card_code(flush_high - index, suit_offset))
			return straight_flush_hand
		"ROYAL FLUSH":
			var royal_hand: Array = []
			for rank in [14, 13, 12, 11, 10]:
				royal_hand.append(_card_code(rank, suit_offset))
			return royal_hand
	return [_card_code(14, suit_offset), _card_code(11, suit_offset + 3), _card_code(8, suit_offset + 2), _card_code(5, suit_offset + 1), _card_code(2 + rank_offset % 2, suit_offset)]


func _card_code(rank: int, suit: int) -> String:
	var rank_label := "A" if rank == 14 else "K" if rank == 13 else "Q" if rank == 12 else "J" if rank == 11 else str(rank)
	return "%s%s" % [rank_label, ["S", "H", "C", "D"][posmod(suit, 4)]]


func _random_split_amount(total: int, count: int, rng: RngStream) -> Array:
	if count <= 0:
		return []
	if rng == null or count == 1:
		return _split_amount(total, count)
	var weights: Array = []
	var weight_total := 0
	for _index in range(count):
		var weight := rng.randi_range(2, 11)
		weights.append(weight)
		weight_total += weight
	var result: Array = []
	var assigned := 0
	for index in range(count):
		var amount := maxi(0, int(floor(float(total) * float(weights[index]) / float(weight_total))))
		result.append(amount)
		assigned += amount
	var remainder_index := rng.randi_range(0, count - 1)
	result[remainder_index] = int(result[remainder_index]) + maxi(0, total - assigned)
	var result_total := 0
	for amount in result:
		result_total += int(amount)
	if result_total != total:
		result[0] = int(result[0]) + (total - result_total)
	return result


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
	var result := MaskScript.scratch(ticket, from, to, _ticket_scratch_rect(ticket))
	var swept: Array = result.get("swept_regions", []) if typeof(result.get("swept_regions", [])) == TYPE_ARRAY else []
	if not swept.is_empty():
		var last_region: Dictionary = swept.back()
		machine["last_sweep_section"] = str(last_region.get("id", "region"))
		machine["last_sweep_id"] = "scratch-pop:%s:%s:%d" % [str(ticket.get("id", "ticket")), str(last_region.get("id", "region")), int(ticket.get("mask_revision", 0))]
	return result


func _reveal_all(machine: Dictionary) -> void:
	var ticket_value: Variant = machine.get("active_ticket", {})
	if typeof(ticket_value) != TYPE_DICTIONARY or (ticket_value as Dictionary).is_empty():
		return
	MaskScript.reveal_all(ticket_value as Dictionary)

func _draw_compact_tabs(surface, active_tab: String) -> void:
	var origin := Vector2(306, 8) if active_tab == "machine" else Vector2(18, 8)
	_draw_compact_tab(surface, Rect2(origin, Vector2(118, 30)), "MACHINE", "scratch_compact_machine", active_tab == "machine")
	_draw_compact_tab(surface, Rect2(origin + Vector2(124, 0), Vector2(118, 30)), "TICKET", "scratch_compact_ticket", active_tab == "ticket")


func _draw_compact_tab(surface, rect: Rect2, label: String, action: String, selected: bool) -> void:
	surface.draw_rect(rect, Color("#17644c") if selected else Color("#171313"))
	surface.draw_rect(rect, Color("#69efb3") if selected else Color("#7d6249"), false, 2)
	surface.surface_label_centered(label, rect, 9, C_WHITE if selected else C_SOFT)
	surface.surface_add_hit(rect, action, 0)


func _draw_ticket(surface, state: Dictionary, render_context: Dictionary = {}) -> void:
	var ticket := _dict_ref(state.get("scratch_ticket", {}))
	_configure_active_ticket_layout(ticket, bool(state.get("scratch_compact_mode", false)))
	_draw_counter_mat(surface)
	_draw_result_piles(surface, state)
	_draw_queue_stack(surface, state)
	if ticket.is_empty() or bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		_draw_empty_ticket_outline(surface)
		return
	var render_rect := active_ticket_rect
	if bool(state.get("scratch_drag_active", false)):
		var pointer: Vector2 = state.get("scratch_last_pointer", active_ticket_rect.get_center())
		var discard_drag := clampf(float(state.get("scratch_discard_drag_progress", 0.0)), 0.0, 1.0)
		if discard_drag > 0.0:
			var dragged_size := active_ticket_rect.size.lerp(Vector2(120, 76), discard_drag)
			var dragged_center := active_ticket_rect.get_center().lerp(pointer + Vector2(45, -50), discard_drag)
			render_rect = Rect2(dragged_center - dragged_size * 0.5, dragged_size)
	var art_frame := _ticket_art_frame(ticket, render_rect)
	var layer_count := clampi(int(render_context.get("scratch_layer_count", state.get("scratch_debug_layer_count", 3))), 1, 3)
	BackgroundRendererScript.draw(surface, ticket, art_frame)
	if layer_count >= 2:
		IconRendererScript.draw(surface, ticket, art_frame)
	if layer_count >= 3:
		FoilRendererScript.draw(surface, ticket, art_frame, state)
	if bool(ticket.get("result_ready", false)):
		surface.surface_draw_ready_badge(art_frame, "CLICK TO FILE")
		surface.surface_add_exact_invisible_hit(art_frame, FILE_TICKET_ACTION, 0)
	else:
		surface.surface_add_drag_hit(art_frame.grow(2), SCRUB_ACTION, 0)


func _draw_counter_mat(surface) -> void:
	surface.draw_rect(PLAY_SURFACE_RECT, Color("#201a17"))
	for stripe in range(11):
		var y := PLAY_SURFACE_RECT.position.y + 10.0 + float(stripe) * 34.0
		surface.draw_line(Vector2(PLAY_SURFACE_RECT.position.x + 6, y), Vector2(PLAY_SURFACE_RECT.end.x - 6, y), Color(0.50, 0.36, 0.25, 0.09), 1)
	surface.draw_rect(PLAY_SURFACE_RECT, Color("#6f5641"), false, 2)


func _draw_queue_stack(surface, state: Dictionary) -> void:
	var queue := _array_ref(state.get("scratch_queue", []))
	var count := int(state.get("scratch_queue_count", queue.size()))
	if count <= 0:
		return
	var origin := PLAY_SURFACE_RECT.end - Vector2(104, 88)
	for index in range(mini(4, count)):
		var ticket: Dictionary = queue[index] if index < queue.size() and typeof(queue[index]) == TYPE_DICTIONARY else {}
		_draw_mini_scratch_ticket(surface, ticket, Rect2(origin + Vector2(float(index) * 7.0, float(index) * 5.0), Vector2(74, 48)), 0.72)
	var badge := Rect2(origin + Vector2(2, 55), Vector2(88, 21))
	surface.draw_rect(badge, Color("#171313"))
	surface.draw_rect(badge, Color("#ffcf49"), false, 2)
	surface.surface_label_centered("%d WAITING" % count, badge, 7, C_WHITE)


func _draw_result_piles(surface, state: Dictionary) -> void:
	_draw_result_pile(surface, _array_ref(state.get("scratch_winner_pile", [])), WIN_PILE_RECT, true, int(state.get("scratch_winner_count", -1)))
	_draw_result_pile(surface, _array_ref(state.get("scratch_loser_pile", [])), LOSS_PILE_RECT, false, int(state.get("scratch_loser_count", -1)))


func _draw_result_pile(surface, tickets: Array, rect: Rect2, winner: bool, total_count: int = -1) -> void:
	var accent := Color("#62e3a2") if winner else Color("#c6cdd3")
	var backing := Color("#102a20") if winner else Color("#262b30")
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.18))
	surface.draw_rect(rect, accent, false, 2)
	var shown := mini(3, tickets.size())
	for offset in range(shown):
		var ticket_index := tickets.size() - shown + offset
		var ticket: Dictionary = tickets[ticket_index] if typeof(tickets[ticket_index]) == TYPE_DICTIONARY else {}
		_draw_mini_scratch_ticket(surface, ticket, Rect2(rect.position + Vector2(5.0 + offset * 4.0, 5.0 + offset * 3.0), Vector2(66, 38)), 0.90)
	var badge := Rect2(rect.position + Vector2(-2, rect.size.y + 3), Vector2(rect.size.x + 4, 19))
	surface.draw_rect(badge, backing)
	surface.draw_rect(badge, accent, false, 2)
	var count := tickets.size() if total_count < 0 else maxi(0, total_count)
	var label := "%d WIN%s" % [count, "" if count == 1 else "S"] if winner else "%d DUD%s" % [count, "" if count == 1 else "S"]
	surface.surface_label_centered(label, badge, 7, C_WHITE)


func _draw_empty_ticket_outline(surface) -> void:
	surface.draw_rect(active_ticket_rect, Color(0.0, 0.0, 0.0, 0.16))
	surface.draw_rect(active_ticket_rect, Color("#7d6249"), false, 2)
	surface.surface_label_centered("SELECT A STOCKED ROW", active_ticket_rect, 11, C_SOFT)


func _draw_surface_hud(surface, state: Dictionary) -> void:
	var ticket := _dict_ref(state.get("scratch_ticket", {}))
	var pending := int(state.get("scratch_current_winnings", 0))
	surface.draw_rect(STATUS_HUD_RECT, Color("#171313"))
	surface.draw_rect(STATUS_HUD_RECT, Color("#7d6249"), false, 2)
	var name := str(ticket.get("display_name", "SELECT A TICKET")).to_upper()
	if bool(ticket.get("result_ready", false)):
		name = str(state.get("scratch_result_summary", "RESULT READY")).to_upper()
	surface.surface_label(name.left(21), STATUS_HUD_RECT.position + Vector2(9, 22), 8, C_WHITE)
	surface.surface_label("$%d" % int(ticket.get("price", 0)) if not ticket.is_empty() else "--", STATUS_HUD_RECT.position + Vector2(133, 22), 8, C_YELLOW)
	surface.surface_label("DUE $%d" % pending, STATUS_HUD_RECT.position + Vector2(177, 22), 8, Color("#62e3a2") if pending > 0 else C_SOFT)
	surface.surface_label("Q %d" % int(state.get("scratch_queue_count", 0)), STATUS_HUD_RECT.position + Vector2(244, 22), 8, C_YELLOW)
	if ticket.is_empty():
		return
	if bool(ticket.get("result_ready", false)):
		var won := int(ticket.get("payout", 0)) > 0
		var instruction_rect := Rect2(STATUS_HUD_RECT.position + Vector2(306, 5), Vector2(148, 24))
		surface.surface_label_centered("CLICK TICKET  $%d" % int(ticket.get("payout", 0)) if won else "CLICK TICKET", instruction_rect, 7, Color("#69efb3") if won else C_SOFT)
		return
	var all_rect := Rect2(STATUS_HUD_RECT.position + Vector2(306, 5), Vector2(70, 24))
	surface.draw_rect(all_rect, Color("#17644c") if bool(state.get("scratch_reduce_motion", false)) else Color("#613047"))
	surface.draw_rect(all_rect, Color("#69efb3") if bool(state.get("scratch_reduce_motion", false)) else C_PINK, false, 2)
	surface.surface_label_centered("CLEAR ALL", all_rect, 7, C_WHITE)
	surface.surface_add_hit(all_rect, SCRATCH_ALL_ACTION, 0)
	var drag_hint := Rect2(STATUS_HUD_RECT.position + Vector2(382, 5), Vector2(72, 24))
	surface.draw_rect(drag_hint, Color("#252a2f"))
	surface.draw_rect(drag_hint, Color("#7f8991"), false, 1)
	surface.surface_label_centered("DRAG TO BIN", drag_hint, 6, C_SOFT)


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
	var slot := clampi(int(surface.surface_animation_metadata(DISPENSE_CHANNEL).get("slot", 0)), 0, 6)
	var progress := _ease_out_cubic(surface.surface_animation_progress(DISPENSE_CHANNEL))
	var source := MACHINE_RECT.position + Vector2(178, 94 + slot * 32)
	var chute := MACHINE_RECT.position + Vector2(104, 380)
	var target := active_ticket_rect.get_center()
	var position := source.lerp(chute, clampf(progress * 2.0, 0.0, 1.0)) if progress < 0.5 else chute.lerp(target, clampf((progress - 0.5) * 2.0, 0.0, 1.0))
	var size := Vector2(74, 48).lerp(active_ticket_rect.size * 0.82, progress)
	_draw_mini_scratch_ticket(surface, ticket, Rect2(position - size * 0.5, size), 1.0)
	surface.draw_rect(Rect2(position - size * 0.5, size).grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.25 * (1.0 - progress)), false, 3)


func _draw_file_animation(surface, state: Dictionary) -> void:
	if not bool(surface.surface_animation_active(FILE_CHANNEL)):
		return
	var ticket := _dict_ref(state.get("scratch_last_settled_ticket", {}))
	if ticket.is_empty():
		return
	var progress := _ease_in_out_cubic(surface.surface_animation_progress(FILE_CHANNEL))
	var discarded := bool(ticket.get("discarded_unfinished", false))
	var winner := str(state.get("scratch_last_settled_pile", "")) == "winner_pile"
	var basket := MachineRendererScript.waste_basket_rect(MACHINE_RECT)
	var target := basket.get_center() if discarded else WIN_PILE_RECT.get_center() if winner else LOSS_PILE_RECT.get_center()
	var source := active_ticket_rect.get_center()
	var position := source.lerp(target, progress)
	var size := active_ticket_rect.size.lerp(Vector2(54, 38), progress)
	_draw_mini_scratch_ticket(surface, ticket, Rect2(position - size * 0.5, size), 1.0 - progress * 0.35)


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


func _machine_empty_rules(machine: Dictionary, stock: Array) -> String:
	for slot_value in stock:
		if typeof(slot_value) == TYPE_DICTIONARY and int((slot_value as Dictionary).get("remaining", 0)) > 0:
			return "Buy a ticket, scratch each silver box, then file the result."
	if bool(machine.get("scalper_present", false)):
		return "A scalper is camped beside the machine. Every slot is empty while he watches the release."
	return "This machine is sold out for now. It releases a small batch every three hours, but posts no countdown."


static func restock_count_for_roll(roll: int) -> int:
	var normalized_roll := posmod(roll, 100)
	if normalized_roll < RESTOCK_ZERO_PERCENT:
		return 0
	if normalized_roll < RESTOCK_ZERO_PERCENT + RESTOCK_ONE_PERCENT:
		return 1
	return 2


static func scalper_present_for_roll(roll: int) -> bool:
	return posmod(roll, 100) < SCALPER_VISIT_CHANCE_PERCENT


static func scalper_knows_for_roll(roll: int) -> bool:
	return posmod(roll, 100) < SCALPER_KNOWS_CHANCE_PERCENT


static func _next_restock_after(absolute_minute: int, phase_minute: int) -> int:
	var cursor := maxi(0, absolute_minute)
	var phase := clampi(phase_minute, 0, RESTOCK_INTERVAL_MINUTES - 1)
	var cycle_start := cursor - posmod(cursor, RESTOCK_INTERVAL_MINUTES)
	var candidate := cycle_start + phase
	if candidate <= cursor:
		candidate += RESTOCK_INTERVAL_MINUTES
	return candidate


func _advance_restock_schedule(run_state: RunState, environment: Dictionary, machine: Dictionary) -> bool:
	if run_state == null:
		return false
	var now := maxi(0, run_state.game_clock_minutes)
	var phase := clampi(int(machine.get("restock_phase_minute", 0)), 0, RESTOCK_INTERVAL_MINUTES - 1)
	var cursor := maxi(0, int(machine.get("restock_cursor_absolute_minute", now)))
	var next_boundary := _next_restock_after(cursor, phase)
	var changed := false
	while next_boundary <= now:
		var rng := run_state.create_rng("scratch-restock:%s:%d" % [_machine_identity(environment), next_boundary])
		var scheduled_count := restock_count_for_roll(rng.randi_range(0, 99))
		var stocked_count := 0
		if bool(machine.get("scalper_present", false)):
			machine["scalper_intercepted_restock_count"] = int(machine.get("scalper_intercepted_restock_count", 0)) + scheduled_count
		else:
			stocked_count = _add_restock_tickets(machine, scheduled_count, rng)
		machine["last_restock_scheduled_count"] = scheduled_count
		machine["last_restock_stocked_count"] = stocked_count
		machine["restock_event_count"] = int(machine.get("restock_event_count", 0)) + 1
		cursor = next_boundary
		next_boundary = _next_restock_after(cursor, phase)
		changed = true
	machine["restock_cursor_absolute_minute"] = cursor
	machine["next_restock_absolute_minute"] = next_boundary
	return changed


func _add_restock_tickets(machine: Dictionary, count: int, rng: RngStream) -> int:
	var stock := _dictionary_array(machine.get("stock", []))
	var added := 0
	for _ticket_index in range(clampi(count, 0, 2)):
		var eligible_indexes: Array[int] = []
		var total_weight := 0
		for index in range(stock.size()):
			var slot: Dictionary = stock[index]
			if int(slot.get("remaining", 0)) >= int(slot.get("capacity", 5)):
				continue
			eligible_indexes.append(index)
			total_weight += maxi(1, int(slot.get("stock_weight", 1)))
		if eligible_indexes.is_empty() or total_weight <= 0:
			break
		var pick := rng.randi_range(1, total_weight)
		var chosen_index := int(eligible_indexes.back())
		for index in eligible_indexes:
			pick -= maxi(1, int((stock[index] as Dictionary).get("stock_weight", 1)))
			if pick <= 0:
				chosen_index = index
				break
		var chosen: Dictionary = stock[chosen_index]
		chosen["remaining"] = int(chosen.get("remaining", 0)) + 1
		stock[chosen_index] = chosen
		added += 1
	machine["stock"] = stock
	return added


func _refresh_scalper_for_visit(run_state: RunState, environment: Dictionary, machine: Dictionary) -> bool:
	if run_state == null:
		return false
	var visit_token := _scratch_visit_token(run_state, environment)
	if run_state.is_tutorial_run():
		var tutorial_changed := bool(machine.get("scalper_present", false)) or bool(machine.get("scalper_knows_schedule", false))
		machine["scalper_present"] = false
		machine["scalper_knows_schedule"] = false
		machine["scalper_visit_token"] = visit_token
		return tutorial_changed
	var same_visit := visit_token == str(machine.get("scalper_visit_token", ""))
	if same_visit and (bool(machine.get("scalper_present", false)) or _stock_total(machine) > 0):
		return false
	machine["scalper_visit_token"] = visit_token
	var rng := run_state.create_rng("scratch-scalper:%s:%s" % [_machine_identity(environment), visit_token])
	# Empty-on-arrival is the encounter condition itself. The percentage roll is
	# only needed when a stocked machine may be intercepted and cleared.
	var present := _stock_total(machine) <= 0 or scalper_present_for_roll(rng.randi_range(0, 99))
	var knows_schedule := present and scalper_knows_for_roll(rng.randi_range(0, 99))
	machine["scalper_present"] = present
	machine["scalper_knows_schedule"] = knows_schedule
	machine["scalper_cleared_count"] = _clear_machine_stock(machine) if present else 0
	return true


func _clear_machine_stock(machine: Dictionary) -> int:
	var stock := _dictionary_array(machine.get("stock", []))
	var cleared := 0
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		cleared += maxi(0, int(slot.get("remaining", 0)))
		slot["remaining"] = 0
		stock[index] = slot
	machine["stock"] = stock
	return cleared


func _stock_total(machine: Dictionary) -> int:
	return _stock_total_from_rows(_dictionary_array(machine.get("stock", [])))


func _stock_total_from_rows(stock: Array) -> int:
	var total := 0
	for slot_value in stock:
		total += maxi(0, int((slot_value as Dictionary).get("remaining", 0)))
	return total


func _scratch_visit_token(run_state: RunState, environment: Dictionary) -> String:
	var entered_at := maxi(0, int(environment.get("entered_game_clock_minutes", run_state.game_clock_minutes if run_state != null else 0)))
	return "%s@%d" % [_machine_identity(environment), entered_at]


func _machine_identity(environment: Dictionary) -> String:
	return RunState.portable_ticket_origin_key(environment)


func _scalper_dialogue_summary(machine: Dictionary, knows_schedule: bool) -> String:
	if knows_schedule:
		var next_restock := int(machine.get("next_restock_absolute_minute", 0))
		return "I keep the clerk's schedule. This machine resets every three hours: %s, then %s, then %s. Be here before the clerk wheels past." % [
			_clock_text_at_absolute_minute(next_restock),
			_clock_text_at_absolute_minute(next_restock + RESTOCK_INTERVAL_MINUTES),
			_clock_text_at_absolute_minute(next_restock + RESTOCK_INTERVAL_MINUTES * 2),
		]
	return "Restock time? Never heard of one. I am just standing beside an empty machine because I like the carpet."


static func _clock_text_at_absolute_minute(absolute_minute: int) -> String:
	var safe_minute := maxi(0, absolute_minute)
	var day := int(floor(float(safe_minute) / 1440.0)) + 1
	var minute_of_day := safe_minute % 1440
	var hour_24 := int(floor(float(minute_of_day) / 60.0)) % 24
	var minute := minute_of_day % 60
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "Day %d, %d:%02d %s" % [day, hour_12, minute, "AM" if hour_24 < 12 else "PM"]


func _ticket_play_label(type_id: String, _mechanic: Dictionary) -> String:
	match type_id:
		"two_fer": return "Match any two symbols."
		"lucky_7s": return "Match a winning number; every 7 has power."
		"tic_tac_gold": return "Complete win lines and check the bonus."
		"crossword_corner": return "Reveal 18 letters and complete at least three words."
		"bonus_bingo": return "Call 24 numbers and complete lines or a blackout."
		"high_roller_holdem": return "Beat the dealer with the better five-card hand."
		"golden_vault": return "Match ladder rungs, multiply, and open the vault."
	return "Scratch every printed result area."


func _normalize_machine_state(machine: Dictionary, run_state: RunState = null) -> void:
	if _machine_state_is_current(machine):
		return
	var needs_upgrade := int(machine.get("version", 1)) < MACHINE_STATE_VERSION or not machine.has("pending_queue")
	if not machine.has("pending_queue"):
		machine["pending_queue"] = []
	if not machine.has("winner_pile"):
		machine["winner_pile"] = []
	if not machine.has("loser_pile"):
		machine["loser_pile"] = []
	machine["loser_archive_count"] = maxi(0, int(machine.get("loser_archive_count", 0)))
	var active_value: Variant = machine.get("active_ticket", {})
	if typeof(active_value) == TYPE_DICTIONARY:
		var active: Dictionary = active_value
		if _ticket_region_upgrade_needed(active) or needs_upgrade:
			_ensure_ticket_regions(active)
		machine["active_ticket"] = active
	if needs_upgrade:
		for field in ["pending_queue", "winner_pile", "loser_pile"]:
			var tickets := _dictionary_array(machine.get(field, []))
			for index in range(tickets.size()):
				var ticket: Dictionary = tickets[index]
				if bool(ticket.get("mask_compacted", false)):
					continue
				if _ticket_region_upgrade_needed(ticket) or needs_upgrade:
					_ensure_ticket_regions(ticket)
					tickets[index] = ticket
			machine[field] = tickets
	var stock := _dictionary_array(machine.get("stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		var ticket_type := _ticket_type(str(slot.get("type_id", "")))
		var count_range := _int_array(ticket_type.get("stock_count", [0, 5]))
		var default_capacity := clampi(int(count_range[1]) if count_range.size() > 1 else 5, 1, 5)
		slot["capacity"] = maxi(1, int(slot.get("capacity", default_capacity)))
		slot["remaining"] = clampi(int(slot.get("remaining", 0)), 0, int(slot.get("capacity", default_capacity)))
		stock[index] = slot
	machine["stock"] = stock
	var phase_fallback := posmod(RunState.text_to_seed(str(machine.get("stock_stream_key", "scratch-restock"))), RESTOCK_INTERVAL_MINUTES)
	var phase := clampi(int(machine.get("restock_phase_minute", phase_fallback)), 0, RESTOCK_INTERVAL_MINUTES - 1)
	var current_absolute_minute := maxi(0, run_state.game_clock_minutes) if run_state != null else maxi(0, int(machine.get("stock_day", 0)) * 1440)
	var cursor := maxi(0, int(machine.get("restock_cursor_absolute_minute", current_absolute_minute)))
	machine["restock_interval_minutes"] = RESTOCK_INTERVAL_MINUTES
	machine["restock_distribution"] = "50_percent_0_40_percent_1_10_percent_2"
	machine["restock_phase_minute"] = phase
	machine["restock_cursor_absolute_minute"] = cursor
	machine["next_restock_absolute_minute"] = maxi(cursor + 1, int(machine.get("next_restock_absolute_minute", _next_restock_after(cursor, phase))))
	machine["last_restock_scheduled_count"] = clampi(int(machine.get("last_restock_scheduled_count", 0)), 0, 2)
	machine["last_restock_stocked_count"] = clampi(int(machine.get("last_restock_stocked_count", 0)), 0, 2)
	machine["restock_event_count"] = maxi(0, int(machine.get("restock_event_count", 0)))
	machine["scalper_visit_chance_percent"] = SCALPER_VISIT_CHANCE_PERCENT
	machine["scalper_present"] = bool(machine.get("scalper_present", false))
	machine["scalper_knows_schedule"] = bool(machine.get("scalper_knows_schedule", false))
	machine["scalper_visit_token"] = str(machine.get("scalper_visit_token", ""))
	machine["scalper_cleared_count"] = maxi(0, int(machine.get("scalper_cleared_count", 0)))
	machine["scalper_intercepted_restock_count"] = maxi(0, int(machine.get("scalper_intercepted_restock_count", 0)))
	machine["version"] = maxi(MACHINE_STATE_VERSION, int(machine.get("version", 1)))


func _machine_state_is_current(machine: Dictionary) -> bool:
	if int(machine.get("version", 0)) < MACHINE_STATE_VERSION:
		return false
	if str(machine.get("schema", "")) != "scratch_ticket_machine_state":
		return false
	for field in ["stock", "pending_queue", "winner_pile", "loser_pile"]:
		if typeof(machine.get(field, null)) != TYPE_ARRAY:
			return false
	if typeof(machine.get("active_ticket", null)) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = machine.get("active_ticket", {}) as Dictionary
	if _ticket_region_upgrade_needed(active):
		return false
	return machine.has("restock_phase_minute") and machine.has("restock_cursor_absolute_minute") and machine.has("next_restock_absolute_minute")


func _ticket_region_upgrade_needed(ticket: Dictionary) -> bool:
	if ticket.is_empty():
		return false
	if bool(ticket.get("mask_compacted", false)):
		return false
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var columns := maxi(24, int(scratch.get("mask_columns", DEFAULT_MASK_COLUMNS)))
	var rows := maxi(18, int(scratch.get("mask_rows", DEFAULT_MASK_ROWS)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	var regions_value: Variant = ticket.get("scratch_regions", [])
	if typeof(regions_value) != TYPE_ARRAY or (regions_value as Array).is_empty() or mask.size() != columns * rows:
		return true
	if int(ticket.get("region_layout_version", 0)) != REGION_LAYOUT_VERSION:
		return true
	var first_region_value: Variant = (regions_value as Array)[0]
	if typeof(first_region_value) != TYPE_DICTIONARY:
		return true
	var first_region: Dictionary = first_region_value as Dictionary
	if int(first_region.get("layout_version", 0)) != REGION_LAYOUT_VERSION:
		return true
	return int(first_region.get("sample_total", 0)) <= 0


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	var states: Dictionary = states_value as Dictionary if typeof(states_value) == TYPE_DICTIONARY else {}
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		var machine := value as Dictionary if persist else (value as Dictionary).duplicate(true)
		_normalize_machine_state(machine, run_state)
		# Project elapsed restocks and the visit-scoped scalper on the owned copy
		# used by presentation reads. Persistent callers receive the same
		# deterministic projection and commit it at their action boundary.
		_refresh_scalper_for_visit(run_state, environment, machine)
		_advance_restock_schedule(run_state, environment, machine)
		if persist:
			_sync_portable_ticket_state(run_state, environment, machine)
		else:
			_merge_portable_ticket_state_readonly(run_state, environment, machine)
		return machine
	var generated := _generate_machine_state(run_state, environment, null)
	_normalize_machine_state(generated, run_state)
	_refresh_scalper_for_visit(run_state, environment, generated)
	_advance_restock_schedule(run_state, environment, generated)
	if persist:
		_sync_portable_ticket_state(run_state, environment, generated)
	else:
		_merge_portable_ticket_state_readonly(run_state, environment, generated)
	if persist:
		var writable_states := states.duplicate(false)
		writable_states[get_id()] = generated
		environment["game_states"] = writable_states
	return generated


func _machine_state_for_pointer(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		return value as Dictionary
	return _ensure_machine_state(run_state, environment, true)


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) == TYPE_DICTIONARY:
		var value: Variant = (states_value as Dictionary).get(get_id(), {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			var machine := (value as Dictionary).duplicate(true)
			_normalize_machine_state(machine, run_state)
			_sync_portable_ticket_state(run_state, environment, machine)
			return machine
	var generated := _generate_machine_state(run_state, environment, null)
	_normalize_machine_state(generated, run_state)
	_sync_portable_ticket_state(run_state, environment, generated)
	return generated


func _write_machine_state(environment: Dictionary, machine: Dictionary, run_state: RunState = null, normalize_before_write: bool = true) -> void:
	if normalize_before_write:
		_normalize_machine_state(machine, run_state)
	var portable := RunState.compact_portable_ticket_state(get_id(), _portable_ticket_player_state(machine), false)
	for field in ["active_ticket", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			machine[field] = portable[field]
	var states := _game_states_for_write(environment)
	states[get_id()] = machine
	environment["game_states"] = states
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
	for field in ["active_ticket", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			machine[field] = portable[field]
	_normalize_machine_state(machine, run_state)


func _merge_portable_ticket_state_readonly(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var portable := run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		return
	for field in ["active_ticket", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			var value: Variant = portable[field]
			if typeof(value) == TYPE_DICTIONARY:
				machine[field] = (value as Dictionary).duplicate(true)
			elif typeof(value) == TYPE_ARRAY:
				machine[field] = (value as Array).duplicate(true)
			else:
				machine[field] = value
	_normalize_machine_state(machine, run_state)


func _portable_ticket_player_state(machine: Dictionary) -> Dictionary:
	return {
		"active_ticket": machine.get("active_ticket", {}),
		"pending_queue": machine.get("pending_queue", []),
		"winner_pile": machine.get("winner_pile", []),
		"loser_pile": machine.get("loser_pile", []),
		"loser_archive_count": maxi(0, int(machine.get("loser_archive_count", 0))),
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
	return (0 if _dict_ref(state.get("active_ticket", {})).is_empty() else 1) + _dictionary_array(state.get("pending_queue", [])).size() + _dictionary_array(state.get("winner_pile", [])).size() + _dictionary_array(state.get("loser_pile", [])).size() + maxi(0, int(state.get("loser_archive_count", 0)))


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
	for field in ["pending_queue", "winner_pile", "loser_pile"]:
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


func _ticket_result_summary(ticket: Dictionary) -> String:
	if ticket.is_empty() or not bool(ticket.get("result_ready", false)):
		return ""
	var payout := maxi(0, int(ticket.get("payout", 0)))
	return "WIN $%d" % payout if payout > 0 else "NO WIN"


func _ticket_win_reason(ticket: Dictionary) -> String:
	if ticket.is_empty():
		return ""
	var result := _dict_ref(ticket.get("mechanic_result", {}))
	var payout := maxi(0, int(ticket.get("payout", 0)))
	match str(ticket.get("type_id", "")):
		"two_fer":
			var symbols: Array = result.get("symbols", []) if typeof(result.get("symbols", [])) == TYPE_ARRAY else []
			for symbol_value in symbols:
				if symbols.count(symbol_value) >= 2:
					return "Matched two %s symbols." % str(symbol_value).capitalize()
			return "No two symbols matched."
		"lucky_7s":
			if bool(result.get("bonus", false)) and int(result.get("bonus_number", 0)) == 7:
				return "Bonus 7 paid $%d." % int(result.get("bonus_prize", 0))
			if bool(result.get("winning_seven", false)):
				return "Winning 7 pays every prize."
			var winners := 0
			for spot_value in _dictionary_array(result.get("your_numbers", [])):
				if bool((spot_value as Dictionary).get("winner", false)):
					winners += 1
			return "%d number%s paid." % [winners, "" if winners == 1 else "s"] if winners > 0 else "No number matched and no 7 appeared."
		"tic_tac_gold":
			var lines := _array_ref(result.get("completed_lines", [])).size()
			if bool(result.get("bonus", false)):
				return "Bonus GOLD paid%s." % (" with %d win line%s" % [lines, "" if lines == 1 else "s"] if lines > 0 else "")
			return "%d win line%s completed." % [lines, "" if lines == 1 else "s"] if lines > 0 else "No full WIN line."
		"crossword_corner":
			var words := int(result.get("word_count", 0))
			return "%d word%s completed." % [words, "" if words == 1 else "s"] if payout > 0 else "Fewer than three words completed."
		"bonus_bingo":
			var lines := int(result.get("line_count", 0))
			var blackouts := int(result.get("blackout_cards", 0))
			if blackouts > 0:
				return "%d blackout card%s paid." % [blackouts, "" if blackouts == 1 else "s"]
			return "%d bingo line%s paid." % [lines, "" if lines == 1 else "s"] if lines > 0 else "No bingo line completed."
		"high_roller_holdem":
			if bool(result.get("pocket_aces", false)):
				return "Pocket aces paid the full prize."
			if payout > 0:
				return "Your %s beat the dealer's %s." % [str(result.get("your_rank", "hand")).capitalize(), str(result.get("dealer_rank", "hand")).capitalize()]
			return "Dealer's %s beat your %s." % [str(result.get("dealer_rank", "hand")).capitalize(), str(result.get("your_rank", "hand")).capitalize()]
		"golden_vault":
			if bool(result.get("vault_win", false)) and bool(result.get("gold_bar", false)):
				return "Gold bar and final vault both opened."
			if bool(result.get("vault_win", false)):
				return "The final vault opened."
			if bool(result.get("gold_bar", false)):
				return "Gold bar paid every ladder rung."
			var hits := 0
			for rung_value in _dictionary_array(result.get("ladder", [])):
				if bool((rung_value as Dictionary).get("match", false)):
					hits += 1
			return "%d ladder rung%s matched." % [hits, "" if hits == 1 else "s"] if hits > 0 else "The vault stayed sealed."
	return "Ticket complete."


func _pending_payout(machine: Dictionary) -> int:
	var total := 0
	for value in _dictionary_array(machine.get("winner_pile", [])):
		total += maxi(0, int((value as Dictionary).get("payout", 0)))
	return total


func _visible_pending_payout(machine: Dictionary) -> int:
	var total := _pending_payout(machine)
	var active: Dictionary = machine.get("active_ticket", {}) if typeof(machine.get("active_ticket", {})) == TYPE_DICTIONARY else {}
	if bool(active.get("result_ready", false)) and not bool(active.get("settled", false)):
		total += maxi(0, int(active.get("payout", 0)))
	return total


func _ticket_complete(ticket: Dictionary) -> bool:
	return MaskScript.ticket_complete(ticket)


func _ticket_scratch_rect(_ticket: Dictionary) -> Rect2:
	var size_id := str(_ticket.get("size_id", "medium_square"))
	return _ticket_art_frame(_ticket, _ticket_rect_for_size(size_id, false))


func _ticket_art_frame(ticket: Dictionary, ticket_rect: Rect2) -> Rect2:
	return RegionModelScript.art_frame(ticket_rect, RegionModelScript.art_size(str(ticket.get("type_id", ""))))


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


func _configure_active_ticket_layout(ticket: Dictionary, compact: bool) -> void:
	var size_id := str(ticket.get("size_id", "medium_square")) if not ticket.is_empty() else "medium_square"
	active_ticket_rect = _ticket_rect_for_size(size_id, compact)

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
		GameModule.surface_animation_channel(DISPENSE_CHANNEL, str(machine.get("last_dispense_id", "")), DISPENSE_DURATION_MSEC, int(machine.get("dispense_started_msec", 0)), {"metadata": {"ticket_id": str(_dict_ref(machine.get("active_ticket", {})).get("id", "")), "slot": int(machine.get("last_dispense_slot", 0))}}),
		GameModule.surface_animation_channel(FILE_CHANNEL, str(machine.get("last_file_id", "")), FILE_DURATION_MSEC, int(machine.get("file_started_msec", 0)), {"metadata": {"pile": str(machine.get("last_settled_pile", ""))}}),
		GameModule.surface_animation_channel(SWEEP_CHANNEL, str(machine.get("last_sweep_id", "")), 0 if reduce_motion else SWEEP_DURATION_MSEC, int(machine.get("sweep_started_msec", 0)), {"metadata": {"region": str(machine.get("last_sweep_section", ""))}}),
	]


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
