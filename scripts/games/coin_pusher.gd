class_name CoinPusherGame
extends GameModule

const STATE_SCHEMA := "coin_pusher_discrete_pile"
const DROP_ACTION := "drop_quarter"
const DROP_CHARGE_ACTION := "coin_pusher_drop_charge"
const NUDGE_ACTION := "nudge_machine"
const COLLECT_ACTION := "coin_pusher_collect"
const SKILL_STOP_ACTION := "coin_pusher_skill_stop"
const CARRIAGE_LEFT_ACTION := "coin_pusher_carriage_left"
const CARRIAGE_RIGHT_ACTION := "coin_pusher_carriage_right"
const CARRIAGE_DRAG_ACTION := "coin_pusher_carriage_drag"
const HOLE_ACTION_PREFIX := "coin_pusher_hole_"
const VAULT_START_ACTION := "start_vault_round"
const VAULT_OPEN_ACTION := "open_vault_cell"
const VAULT_STOP_ACTION := "stop_vault_round"
const VAULT_PEEK_ACTION := "peek_vault_cell"
const NUDGE_FORCE_PREFIX := "coin_pusher_force_"
const NUDGE_DIRECTION_PREFIX := "coin_pusher_direction_"
const VAULT_CELL_PREFIX := "coin_pusher_vault_cell_"
const COLD_QUARTERS_ITEM_ID := "cold_quarters"
const SHIM_ITEM_ID := "coin_return_shim"
const RUMOR_CLASS := "pusher_pile"
const V3_RAIL_DRAG_RECT := Rect2(176, 142, 548, 112)
const JackpotRidgeScript := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")
const VaultDropScript := preload("res://scripts/games/coin_pusher/vault_drop.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const CoinPusherLiveSessionScript := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")
const CoinPusherRendererScript := preload("res://scripts/games/coin_pusher/coin_pusher_renderer.gd")
const V3_HEADLESS_MESSAGE := "Aim for bonus-token cups, use the stop to build pressure, and push the machine's heavy feature pieces into the win tray."

var _live_machines: Dictionary = {}
var _exit_settle_active := false
var _renderer := CoinPusherRendererScript.new()
var _machine_definition_cache: Dictionary = {}


func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	super.setup(p_definition, p_library)
	_machine_definition_cache.clear()


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func defers_embedded_action_presentation_refresh(run_state: RunState, _environment: Dictionary) -> bool:
	return run_state != null and not run_state.is_tutorial_run()


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	# Surface entry is presentation-only. Machine normalization, rumor updates,
	# and staff-watch consequences belong to generation/action boundaries.
	var busy := _machine_busy(environment)
	var machine := _read_machine_state(run_state, environment) if busy else _ensure_live_machine(run_state, environment)
	var result := super.enter(run_state, environment)
	if busy:
		result["message"] = "A convoy regular has the good machine tied up. Try another room or come back when the crowd moves."
	elif bool(machine.get("locked_down", false)):
		result["message"] = "Red lights. This cabinet is done for tonight. The rest of the room is still yours."
	elif _has_v3_simulation(machine):
		result["message"] = V3_HEADLESS_MESSAGE
	elif bool(machine.get("staff_watch_memory", false)):
		result["message"] = "%s is live again. Staff remember your hands and keep one eye here." % _variation_display_name(str(machine.get("variation_id", "quarter_falls")))
	else:
		result["message"] = _variation_intro(str(machine.get("variation_id", "quarter_falls")))
	return result


func legal_actions(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _read_machine_state(run_state, environment)
	if _machine_busy(environment) or bool(machine.get("locked_down", false)):
		return []
	var result: Array = []
	for action in super.legal_actions(run_state, environment):
		result.append(action)
	if str(machine.get("variation_id", "")) == "vault_drop":
		result.append({"id": VAULT_START_ACTION, "label": "Open Vault", "summary": "Spend banked fragments one cell at a time.", "win_chance": 0, "payout_mult": 0})
		result.append({"id": VAULT_OPEN_ACTION, "label": "Open Cell", "summary": "Spend one fragment on the selected vault cell.", "win_chance": 0, "payout_mult": 0})
		result.append({"id": VAULT_STOP_ACTION, "label": "Stop", "summary": "Close the vault and keep every unspent fragment here.", "win_chance": 100, "payout_mult": 0})
	return result


func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _read_machine_state(run_state, environment)
	if _machine_busy(environment) or bool(machine.get("locked_down", false)):
		return []
	var result := super.cheat_actions(run_state, environment)
	if not _machine_busy(environment) and str(machine.get("variation_id", "")) == "vault_drop" and run_state != null and run_state.inventory.has("xray_glasses"):
		result.append({"id": VAULT_PEEK_ACTION, "label": "X-Ray Peek", "summary": "Reveal exactly one selected vault cell truthfully.", "win_chance": 100, "payout_mult": 0, "suspicion_delta": 0})
	return result


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	var capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 0
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": cheat_actions(run_state, environment),
		"stake_floor": _drop_cost(),
		"stake_ceiling": maxi(_drop_cost(), capacity),
		"base_stake_ceiling": maxi(_drop_cost(), capacity),
		"economy_state": run_state.economy() if run_state != null else {},
		"economy_pressure_applied": false,
	}


func wager_cost_for_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	# Pricing is a read-only query used while composing environment/action UI.
	# It must never open a live simulation for a machine the player did not enter.
	if action_id == DROP_ACTION and _drop_refused(_read_machine_state(run_state, environment)):
		return 0
	return _drop_cost() if action_id == DROP_ACTION else 0


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _generate_machine_state(run_state, environment, rng)
	_initialize_owned_shim(run_state, machine)
	return machine


func environment_state_generated(run_state: RunState, environment: Dictionary, generated_state: Dictionary) -> void:
	_register_vault_progressive(run_state, environment, generated_state)
	_register_pile_rumor(run_state, environment, generated_state)


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	return {
		"coin_pusher_locked": bool(machine.get("locked_down", false)) or _machine_busy(environment),
		"coin_pusher_busy": _machine_busy(environment),
		"staff_watch": bool(machine.get("staff_watch_memory", false)),
		"status_line": "Machine occupied by the convoy." if _machine_busy(environment) else "Attendant keeps eyes on this cabinet." if bool(machine.get("staff_watch_memory", false)) else "%s waits under a live pile." % _variation_display_name(str(machine.get("variation_id", "quarter_falls"))),
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	# Generic presentation sweeps query surfaces without entering them and are
	# contractually read-only. Production `enter()` has already opened the live
	# machine, so only use that transient state when it exists.
	var key := _live_key(run_state, environment)
	var machine: Dictionary = _live_machines[key] if _live_machines.has(key) else _read_machine_state(run_state, environment)
	return _v3_headless_surface_state(machine, run_state, environment, ui_state)


func surface_action_command(surface_action: String, _index: int, _confirm_requested: bool, _ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if _machine_busy(environment):
		return GameModule.surface_command({"handled": true, "message": "The machine is occupied; no control responds."}, true)
	var machine := _ensure_live_machine(run_state, environment)
	_reconcile_tolerance_modifiers(run_state, environment, machine)
	var live_session: Dictionary = machine.get("live_session", {})
	if bool(live_session.get("input_locked", false)):
		return GameModule.surface_command({"handled": true, "message": "The controls lock while the last cascade settles."}, true)
	if bool(machine.get("locked_down", false)) and surface_action != COLLECT_ACTION:
		return GameModule.surface_command({"handled": true, "message": "The alarm lock leaves the cabinet dark. Only the tray remains reachable."}, true)
	if surface_action.begins_with(NUDGE_FORCE_PREFIX):
		var force := surface_action.trim_prefix(NUDGE_FORCE_PREFIX)
		var forces: Dictionary = _tuning().get("nudge_forces", {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
		if not forces.has(force):
			return {"handled": false}
		machine["nudge_force"] = force
		_write_live_durable(run_state, environment, machine, false)
		return GameModule.surface_command({"handled": true, "environment_changed": true, "preserve_surface_ui_state": true, "surface_state_patch": _v3_headless_surface_state(machine, run_state, environment)}, true)
	if surface_action.begins_with(NUDGE_DIRECTION_PREFIX):
		var direction := surface_action.trim_prefix(NUDGE_DIRECTION_PREFIX)
		if not direction in ["left", "front", "right"]:
			return {"handled": false}
		machine["nudge_direction"] = direction
		_write_live_durable(run_state, environment, machine, false)
		return GameModule.surface_command({"handled": true, "environment_changed": true, "preserve_surface_ui_state": true, "surface_state_patch": _v3_headless_surface_state(machine, run_state, environment)}, true)
	if surface_action.begins_with(VAULT_CELL_PREFIX):
		if str(machine.get("variation_id", "")) != "vault_drop":
			return {"handled": false}
		var cell_index := int(surface_action.trim_prefix(VAULT_CELL_PREFIX))
		var cells: Array = (_variation_state(machine).get("vault_cells", []) as Array)
		if cell_index < 0 or cell_index >= cells.size() or bool((cells[cell_index] as Dictionary).get("opened", false)):
			return GameModule.surface_command({"handled": true, "message": "That vault cell is unavailable."}, true)
		machine["vault_selected_cell"] = cell_index
		_write_live_durable(run_state, environment, machine, false)
		return GameModule.surface_command({"handled": true, "environment_changed": true, "preserve_surface_ui_state": true, "surface_state_patch": _v3_headless_surface_state(machine, run_state, environment)}, true)
	if surface_action in [VAULT_START_ACTION, VAULT_OPEN_ACTION, VAULT_STOP_ACTION, VAULT_PEEK_ACTION]:
		return GameModule.surface_command({
			"handled": true,
			"direct_resolve": true,
			"action_id": surface_action,
			"action_kind": "risky" if surface_action == VAULT_PEEK_ACTION else "legal",
			"set_stake": 0,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
		}, true)
	if surface_action.begins_with(HOLE_ACTION_PREFIX):
		var hole_index := int(surface_action.trim_prefix(HOLE_ACTION_PREFIX))
		var simulation := _simulation(machine)
		if _jammed_holes(machine, simulation).has(hole_index):
			return GameModule.surface_command({"handled": true, "message": "A dud puck is physically choking that entry. Push it clear first."}, true)
		var selected_x := CoinPusherSolverScript.select_hole(simulation, hole_index)
		machine["selected_nozzle_id"] = _selected_nozzle_id(machine, simulation)
		CoinPusherLiveSessionScript.queue_input(machine, {"kind": "hole", "index": int(simulation.get("selected_hole", 0))})
		_write_live_durable(run_state, environment, machine, false)
		return GameModule.surface_command({
			"handled": true,
			"environment_changed": true,
			"preserve_surface_ui_state": true,
			"surface_state_patch": {
				"coin_pusher_selected_hole": int(simulation.get("selected_hole", 0)),
				"coin_pusher_carriage_x": selected_x,
			},
		}, true)
	var immediate_patch: Dictionary = {}
	match surface_action:
		"coin_pusher_drop":
			if _drop_refused(machine):
				return GameModule.surface_command({"handled": true, "message": "The coin slot refuses the quarter; nothing was charged."}, true)
			return GameModule.surface_command({"handled": true, "direct_resolve": true, "action_id": DROP_ACTION, "action_kind": "legal", "set_stake": _drop_cost(), "skip_stake_validation": true, "preserve_surface_ui_state": true}, true)
		CARRIAGE_LEFT_ACTION, CARRIAGE_RIGHT_ACTION:
			var simulation := _simulation(machine)
			var rail: Dictionary = (_machine_definition(str(machine.get("variation_id", _variation_id()))).get("apparatus", {}) as Dictionary).get("rail", {})
			var speed := int(rail.get("speed_per_tick", 900))
			var direction := -1 if surface_action == CARRIAGE_LEFT_ACTION else 1
			var requested := int(simulation.get("carriage_x", 50000)) + direction * speed
			var actual := CoinPusherSolverScript.set_carriage(simulation, requested)
			CoinPusherLiveSessionScript.queue_input(machine, {"kind": "carriage", "x": actual})
			immediate_patch["coin_pusher_carriage_x"] = actual
			immediate_patch["coin_pusher_selected_hole"] = int(simulation.get("selected_hole", 0))
		SKILL_STOP_ACTION:
			var simulation := _simulation(machine)
			var engaged := not bool(simulation.get("skill_stop_engaged", false))
			var resume_rate := _variation_motor_rate_fp(machine)
			CoinPusherSolverScript.set_skill_stop(simulation, engaged, resume_rate)
			CoinPusherLiveSessionScript.queue_input(machine, {"kind": "skill_stop", "engaged": engaged, "resume_rate_fp": resume_rate})
			immediate_patch["coin_pusher_skill_stop_engaged"] = engaged
			immediate_patch["coin_pusher_motor_rate_fp"] = int(simulation.get("motor_rate_fp", 0))
		COLLECT_ACTION:
			return _collect_surface_command(run_state, environment, machine)
		_:
			return {"handled": false}
	_write_live_durable(run_state, environment, machine, false)
	immediate_patch.merge(_surface_action_view_patch(machine, run_state, environment, _ui_state), false)
	return GameModule.surface_command({"handled": true, "environment_changed": true, "preserve_surface_ui_state": true, "surface_state_patch": immediate_patch}, true)


func surface_pointer_uses_lightweight_ui_state(surface_action: String) -> bool:
	return surface_action in [CARRIAGE_DRAG_ACTION, DROP_CHARGE_ACTION]


func surface_pointer_command(surface_action: String, _index: int, phase: String, board_position: Vector2, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if not surface_action in [CARRIAGE_DRAG_ACTION, DROP_CHARGE_ACTION]:
		return {"handled": false}
	if _machine_busy(environment):
		return GameModule.surface_command({"handled": true, "message": "The machine is occupied; no control responds."}, true)
	var machine := _ensure_live_machine(run_state, environment)
	_reconcile_tolerance_modifiers(run_state, environment, machine)
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	if bool(session.get("input_locked", false)):
		return GameModule.surface_command({"handled": true, "message": "The controls lock while the last cascade settles."}, true)
	if bool(machine.get("locked_down", false)):
		return GameModule.surface_command({"handled": true, "message": "The carriage does not move while this cabinet is unavailable."}, true)
	var next_state := ui_state
	if surface_action == DROP_CHARGE_ACTION:
		var charge_simulation := _simulation(machine)
		if phase == "cancel":
			next_state.erase("coin_pusher_drop_charge_started_tick")
			next_state["coin_pusher_drop_charge_count"] = 0
			return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true, "surface_state_patch": {"coin_pusher_drop_charge_count": 0}}, true)
		if phase == "begin":
			next_state["coin_pusher_drop_charge_started_tick"] = int(charge_simulation.get("tick", 0))
			next_state["coin_pusher_drop_charge_count"] = 1
			return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true}, true)
		if phase == "move":
			var held_ticks := maxi(0, int(charge_simulation.get("tick", 0)) - int(next_state.get("coin_pusher_drop_charge_started_tick", charge_simulation.get("tick", 0))))
			next_state["coin_pusher_drop_charge_count"] = clampi(maxi(1, held_ticks / 6), 1, 60)
			return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true, "surface_state_patch": {"coin_pusher_drop_charge_count": int(next_state["coin_pusher_drop_charge_count"])}}, true)
		if phase == "end":
			var end_held_ticks := maxi(0, int(charge_simulation.get("tick", 0)) - int(next_state.get("coin_pusher_drop_charge_started_tick", charge_simulation.get("tick", 0))))
			var requested := clampi(maxi(1, end_held_ticks / 6), 1, 60)
			var affordable := run_state.wager_capacity_for_game(get_id(), environment) / maxi(1, _drop_cost()) if run_state != null else requested
			var count := mini(requested, maxi(0, affordable))
			next_state.erase("coin_pusher_drop_charge_started_tick")
			next_state["coin_pusher_drop_charge_count"] = 0
			if count <= 0:
				return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true, "message": "The slot needs another quarter."}, true)
			return GameModule.surface_command({"handled": true, "ui_state": next_state, "direct_resolve": true, "action_id": DROP_ACTION, "action_kind": "legal", "set_stake": count * _drop_cost(), "skip_stake_validation": true, "preserve_surface_ui_state": true}, true)
		return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true}, true)
	if phase == "begin":
		next_state["coin_pusher_rail_drag_active"] = true
	elif phase == "end":
		next_state["coin_pusher_rail_drag_active"] = false
	elif phase != "move" or not bool(next_state.get("coin_pusher_rail_drag_active", false)):
		return GameModule.surface_command({"handled": true, "ui_state": next_state, "preserve_surface_ui_state": true}, true)
	var simulation := _simulation(machine)
	var requested_x := _rail_x_from_board_position(machine, board_position)
	var previous_x := int(simulation.get("carriage_x", requested_x))
	var actual_x := CoinPusherSolverScript.set_carriage(simulation, requested_x)
	if actual_x != previous_x:
		CoinPusherLiveSessionScript.queue_input(machine, {"kind": "carriage", "x": actual_x})
	next_state["coin_pusher_rail_pointer_x"] = board_position.x
	return GameModule.surface_command({
		"handled": true,
		"ui_state": next_state,
		"preserve_surface_ui_state": true,
		"surface_state_patch": {"coin_pusher_carriage_x": actual_x},
	}, true)


func _apparatus_type(machine: Dictionary) -> String:
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	return str(apparatus.get("type", "rail_slot"))


func _selected_nozzle_id(machine: Dictionary, simulation: Dictionary) -> String:
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var nozzles: Array = apparatus.get("nozzles", []) if typeof(apparatus.get("nozzles", [])) == TYPE_ARRAY else []
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var selected := clampi(int(simulation.get("selected_hole", 0)), 0, maxi(0, nozzles.size() - 1))
		if selected < nozzles.size() and typeof(nozzles[selected]) == TYPE_DICTIONARY:
			return str((nozzles[selected] as Dictionary).get("id", "nozzle_%d" % selected))
		return "nozzle_%d" % selected
	if not nozzles.is_empty() and typeof(nozzles[0]) == TYPE_DICTIONARY:
		return str((nozzles[0] as Dictionary).get("id", "rail"))
	return "rail"


func _native_surface_actions(machine: Dictionary) -> Array:
	var result: Array = ["coin_pusher_drop", DROP_CHARGE_ACTION]
	if _apparatus_type(machine) == "hole_set":
		var apparatus: Dictionary = _machine_definition(str(machine.get("variation_id", _variation_id()))).get("apparatus", {})
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		for index in range(holes.size()):
			result.append("%s%d" % [HOLE_ACTION_PREFIX, index])
	else:
		result.append_array([CARRIAGE_LEFT_ACTION, CARRIAGE_RIGHT_ACTION])
	result.append_array([SKILL_STOP_ACTION, COLLECT_ACTION, "coin_pusher_nudge"])
	var forces: Dictionary = _tuning().get("nudge_forces", {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	for force in forces.keys():
		result.append(NUDGE_FORCE_PREFIX + str(force))
	for direction in ["left", "front", "right"]:
		result.append(NUDGE_DIRECTION_PREFIX + direction)
	if str(machine.get("variation_id", "")) == "vault_drop":
		result.append_array([VAULT_START_ACTION, VAULT_OPEN_ACTION, VAULT_STOP_ACTION, VAULT_PEEK_ACTION])
		for cell_index in range((_variation_state(machine).get("vault_cells", []) as Array).size()):
			result.append(VAULT_CELL_PREFIX + str(cell_index))
	return result


func _apparatus_action_bindings(machine: Dictionary, simulation: Dictionary) -> Dictionary:
	var bindings := {}
	if _apparatus_type(machine) == "hole_set":
		var apparatus: Dictionary = _machine_definition(str(machine.get("variation_id", _variation_id()))).get("apparatus", {})
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		var selected := clampi(int(simulation.get("selected_hole", 0)), 0, maxi(0, holes.size() - 1))
		var jammed := _jammed_holes(machine, simulation)
		for index in range(holes.size()):
			bindings["%s%d" % [HOLE_ACTION_PREFIX, index]] = {"label": str(index + 1), "enabled": not jammed.has(index), "lit": index == selected, "jammed": jammed.has(index)}
	else:
		bindings[CARRIAGE_LEFT_ACTION] = {"label": "<", "enabled": true}
		bindings[CARRIAGE_RIGHT_ACTION] = {"label": ">", "enabled": true}
	if str(machine.get("variation_id", "")) == "vault_drop":
		var state := _variation_state(machine)
		var has_fragments := int(state.get("banked_fragments", 0)) > 0
		var round_active := bool(state.get("vault_round_active", false))
		bindings[VAULT_START_ACTION] = {"label": "OPEN VAULT", "enabled": has_fragments and not round_active}
		bindings[VAULT_OPEN_ACTION] = {"label": "OPEN CELL", "enabled": has_fragments and round_active}
		bindings[VAULT_STOP_ACTION] = {"label": "STOP", "enabled": round_active}
		bindings[VAULT_PEEK_ACTION] = {"label": "X-RAY", "enabled": true}
		var selected_cell := int(machine.get("vault_selected_cell", 0))
		var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
		for cell_index in range(cells.size()):
			var opened := bool((cells[cell_index] as Dictionary).get("opened", false)) if typeof(cells[cell_index]) == TYPE_DICTIONARY else true
			bindings[VAULT_CELL_PREFIX + str(cell_index)] = {"label": str(cell_index + 1), "enabled": not opened, "lit": cell_index == selected_cell}
	var selected_force := str(machine.get("nudge_force", "tap"))
	var forces: Dictionary = _tuning().get("nudge_forces", {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	for force in forces.keys():
		bindings[NUDGE_FORCE_PREFIX + str(force)] = {"label": str(force).to_upper(), "enabled": true, "lit": str(force) == selected_force}
	var selected_direction := str(machine.get("nudge_direction", "front"))
	for direction in ["left", "front", "right"]:
		bindings[NUDGE_DIRECTION_PREFIX + direction] = {"label": str(direction).to_upper(), "enabled": true, "lit": str(direction) == selected_direction}
	return bindings


func _rail_x_from_board_position(machine: Dictionary, board_position: Vector2) -> int:
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var geometry: Dictionary = definition.get("geometry", {}) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	var layout: Dictionary = _renderer.debug_entry_hardware_layout_for_test({"coin_pusher_geometry": geometry, "coin_pusher_apparatus": apparatus, "coin_pusher_carriage_x": int(_simulation(machine).get("carriage_x", (rail_min + rail_max) / 2))})
	var drag_rect: Rect2 = layout.get("drag_rect", V3_RAIL_DRAG_RECT)
	var normalized := clampf((board_position.x - drag_rect.position.x) / maxf(1.0, drag_rect.size.x), 0.0, 1.0)
	return clampi(int(round(lerpf(float(rail_min), float(rail_max), normalized))), rail_min, rail_max)


func surface_motion_signature(_surface, surface_state: Dictionary) -> Dictionary:
	# This is deliberately an actual-solver signature. Presentation clocks may
	# smooth the cabinet later, but must never make a stuck live loop look alive.
	var body_checksum := 17
	for body_value in surface_state.get("coin_pusher_bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		body_checksum = int((body_checksum * 31 + str(body.get("id", "")).hash() + int(body.get("x", 0)) * 3 + int(body.get("y", 0)) * 5 + int(body.get("z", 0)) * 7) & 0x7fffffff)
	var rider_checksum := 23
	for rider_value in surface_state.get("coin_pusher_riders", []):
		if typeof(rider_value) != TYPE_DICTIONARY:
			continue
		var rider: Dictionary = rider_value
		rider_checksum = int((rider_checksum * 31 + str(rider.get("id", "")).hash() + int(rider.get("x", 0)) * 3 + int(rider.get("y", 0)) * 5 + int(rider.get("z", 0)) * 7) & 0x7fffffff)
	return {
		"liveness_ticks": int(surface_state.get("coin_pusher_liveness_ticks", 0)),
		"phase_fp": int(surface_state.get("coin_pusher_phase_fp", 0)),
		"face_y": int(surface_state.get("coin_pusher_face_position_y", 0)),
		"physics_body_checksum": body_checksum,
		"rider_checksum": rider_checksum,
	}


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	return _renderer.draw(surface, state)


func renderer_signature(state: Dictionary) -> Dictionary:
	return _renderer.render_signature(state)


func reset_renderer_performance_counters() -> void:
	_renderer.reset_performance_stage_counters()


func renderer_performance_counters() -> Dictionary:
	return _renderer.performance_stage_counters()


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, _rng: RngStream, _ui_state: Dictionary = {}) -> Dictionary:
	if _machine_busy(environment):
		return _empty_pusher_result(action_id, environment, "The machine is occupied; no control responds.")
	var machine := _ensure_live_machine(run_state, environment)
	_reconcile_tolerance_modifiers(run_state, environment, machine)
	if bool((machine.get("live_session", {}) as Dictionary).get("input_locked", false)):
		return _empty_pusher_result(action_id, environment, "The controls lock while the last cascade settles.")
	if _machine_busy(environment):
		return _empty_pusher_result(action_id, environment, "The good machine is occupied. Nothing moves until the convoy does.")
	if bool(machine.get("locked_down", false)):
		return _empty_pusher_result(action_id, environment, "Red light. This cabinet stays dead tonight; the rest of the room is open.")
	if action_id in [VAULT_START_ACTION, VAULT_OPEN_ACTION, VAULT_STOP_ACTION, VAULT_PEEK_ACTION]:
		return _resolve_vault_action(action_id, run_state, environment, machine, _ui_state)
	if action_id == DROP_ACTION:
		if _drop_refused(machine):
			var refused_result := _empty_pusher_result(action_id, environment, "The coin slot refuses the quarter; nothing was charged.")
			refused_result["surface_action_view_patch"] = _surface_action_view_patch(machine, run_state, environment, _ui_state)
			refused_result["preserve_surface_ui_state"] = true
			return refused_result
		var simulation := _simulation(machine)
		_prepare_variation_action(machine)
		_sync_physical_features(machine)
		var density := maxi(_cold_density(), int(machine.get("cold_quarters_density_armed", 0))) if bool(machine.get("cold_quarters_armed", false)) else 1
		machine["cold_quarters_armed"] = false
		machine["cold_quarters_density_armed"] = 0
		var provenance := _drop_provenance(machine)
		var requested_count := maxi(1, _stake / maxi(1, _drop_cost()))
		var nozzle_id := _selected_nozzle_id(machine, simulation)
		var queued_count := CoinPusherLiveSessionScript.enqueue_drops(machine, {"nozzle_id": nozzle_id, "density": density, "provenance": provenance, "chain_depth": 0, "bonus_origin": false}, requested_count)
		var total_cost := queued_count * _drop_cost()
		machine["action_count"] = int(machine.get("action_count", 0)) + queued_count
		machine["total_cost"] = int(machine.get("total_cost", 0)) + total_cost
		machine["last_message"] = "%d quarter%s queued through %s. The nozzle can move while they feed." % [queued_count, "" if queued_count == 1 else "s", nozzle_id]
		_write_live_durable(run_state, environment, machine, false)
		var deltas := GameModule.empty_result_deltas()
		deltas["bankroll_delta"] = -total_cost
		deltas["story_log"] = [_story_entry(DROP_ACTION, "legal", environment, -total_cost, 0, {"tick": int(simulation.get("tick", 0)), "carriage_x": int(simulation.get("carriage_x", 50000)), "nozzle_id": nozzle_id, "queued_count": queued_count})]
		deltas["messages"] = [str(machine["last_message"])]
		var result := GameModule.build_owned_action_result({"source_id": get_id(), "game_id": get_id(), "action_id": DROP_ACTION, "action_kind": "legal", "stake": total_cost, "environment_id": str(environment.get("id", "")), "deltas": deltas, "message": str(machine["last_message"])})
		result["host_apply_result"] = true
		result["surface_action_view_patch"] = _surface_action_view_patch(machine, run_state, environment, _ui_state)
		result["preserve_surface_ui_state"] = true
		return result
	if action_id == NUDGE_ACTION:
		return _resolve_live_nudge(run_state, environment, machine, _ui_state)
	return _empty_pusher_result(action_id, environment, "That control is not connected.")


func active_item_command(item_id: String, run_state: RunState, environment: Dictionary, _rng: RngStream) -> Dictionary:
	if item_id != COLD_QUARTERS_ITEM_ID or run_state == null or not run_state.inventory.has(item_id):
		return {"handled": false}
	if _machine_busy(environment):
		return {"handled": true, "message": "The machine is occupied; no control responds."}
	var machine := _ensure_live_machine(run_state, environment)
	_reconcile_tolerance_modifiers(run_state, environment, machine)
	if bool(machine.get("locked_down", false)):
		return {"handled": true, "message": "Cold metal won't wake a locked cabinet."}
	machine["cold_quarters_armed"] = true
	machine["cold_quarters_density_armed"] = maxi(_cold_density(), run_state.item_effect_total("coin_pusher_drop_density", "coin_pusher"))
	_write_live_durable(run_state, environment, machine, false)
	var deltas := GameModule.empty_result_deltas()
	deltas["inventory_remove"] = [item_id]
	var message := "Cold quarters loaded. The next drop hits heavy."
	deltas["messages"] = [message]
	var result := GameModule.build_owned_action_result({
		"source_id": get_id(), "game_id": get_id(), "action_id": "load_cold_quarters", "action_kind": "item",
		"environment_id": str(environment.get("id", "")), "deltas": deltas, "message": message,
	})
	return {"handled": true, "environment_changed": true, "result": result, "message": message}


func deterministic_state_digest(environment: Dictionary) -> String:
	var machine := _read_machine_state(null, environment)
	return JSON.stringify(_digest_state(machine), "", true)


func surface_realtime_state_patch(run_state: RunState, environment: Dictionary, ui_state: Dictionary, _current_surface_state: Dictionary) -> Dictionary:
	if _machine_busy(environment):
		# Occupancy is a hard absence boundary: project the durable snapshot, but
		# never open a live session or advance one tick behind the patron's back.
		return _v3_headless_surface_state(_read_machine_state(run_state, environment), run_state, environment, ui_state)
	var machine := _ensure_live_machine(run_state, environment)
	var advanced := CoinPusherLiveSessionScript.advance(machine, int(ui_state.get("surface_time_msec", 0)))
	var physics_events: Array = advanced.get("events", []) if typeof(advanced.get("events", [])) == TYPE_ARRAY else []
	_consume_live_physics_events(run_state, machine, physics_events)
	if physics_events.any(func(event: Variant) -> bool: return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) in ["tray", "gutter"]):
		_register_pile_rumor(run_state, environment, machine)
	_advance_tell_decay(machine, int(advanced.get("ticks", 0)))
	var request_autosave := false
	if int(advanced.get("ticks", 0)) > 0:
		var session: Dictionary = machine.get("live_session", {})
		var simulation := _simulation(machine)
		if bool(session.get("durable_dirty", false)) and not bool(session.get("durable_ready", false)) \
				and int(session.get("input_cursor", 0)) >= (session.get("input_trace", []) as Array).size() \
				and _queued_drop_count(machine) == 0 \
				and CoinPusherLiveSessionScript.all_steady(machine, bool(machine.get("motor_started", false)) and not bool(machine.get("locked_down", false))):
			CoinPusherLiveSessionScript.sync_native_body_state(machine)
			session["durable_ready"] = true
			session["durable_dirty"] = false
			session["last_persisted_tick"] = int(simulation.get("tick", 0))
			_write_live_durable(run_state, environment, machine, true)
			request_autosave = true
	var presentation_session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	# Realtime owns only fields that can actually change while the player watches.
	# Rebuilding the complete entry snapshot here duplicated catalog, economy,
	# cabinet, geometry, and body projection work on every rendered frame.
	var patch := _v3_realtime_presentation_patch(machine, run_state, environment)
	if ui_state.has("coin_pusher_drop_charge_started_tick"):
		var held_ticks := maxi(0, int(_simulation(machine).get("tick", 0)) - int(ui_state.get("coin_pusher_drop_charge_started_tick", 0)))
		patch["coin_pusher_drop_charge_count"] = clampi(maxi(1, held_ticks / 6), 1, 60)
	else:
		patch["coin_pusher_drop_charge_count"] = 0
	var audio_events := _presentation_audio_events(machine, physics_events)
	if not audio_events.is_empty():
		presentation_session["presentation_audio_serial"] = int(presentation_session.get("presentation_audio_serial", 0)) + 1
	patch["coin_pusher_audio_events"] = audio_events
	patch["coin_pusher_audio_serial"] = int(presentation_session.get("presentation_audio_serial", 0))
	patch["surface_realtime_state_refresh"] = true
	# The Web canvas owns a measured low-detail presentation cadence. Solver
	# patches still land every tick, but they must not bypass that scheduler and
	# force a complete 300-body draw for every 16 ms authority refresh.
	patch["surface_defer_patch_redraw"] = true
	patch["coin_pusher_ticks_advanced"] = int(advanced.get("ticks", 0))
	patch["request_foundation_autosave"] = request_autosave
	return patch


func surface_realtime_entry_anchor_patch(run_state: RunState, environment: Dictionary, ui_state: Dictionary, current_surface_state: Dictionary) -> Dictionary:
	# Entry already built the complete 300-body surface from this live session.
	# Anchor its clock without asking the realtime projector to publish those same
	# bodies a second time. A missing/incomplete session fails back to the normal
	# realtime path in FoundationMain.
	if _machine_busy(environment) or str(current_surface_state.get("game_id", "")) != get_id() \
			or int(current_surface_state.get("coin_pusher_body_count", 0)) <= 0:
		return {}
	var key := _live_key(run_state, environment)
	if not _live_machines.has(key):
		return {}
	var machine: Dictionary = _live_machines[key]
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	if session.is_empty() or not bool(session.get("open", false)) or int(session.get("last_clock_msec", -1)) >= 0:
		return {}
	var advanced := CoinPusherLiveSessionScript.advance(machine, int(ui_state.get("surface_time_msec", 0)))
	if int(advanced.get("ticks", -1)) != 0 or not (advanced.get("events", []) as Array).is_empty():
		return {}
	return {
		"surface_realtime_state_refresh": true,
		"coin_pusher_ticks_advanced": 0,
	}


func checkpoint_surface_ui_state(_ui_state: Dictionary, _run_state: RunState, environment: Dictionary) -> void:
	var key := _live_key(_run_state, environment)
	if not _live_machines.has(key):
		return
	begin_chunked_exit_settle(_run_state, environment)
	var result := {"done": false}
	while not bool(result.get("done", false)):
		result = advance_chunked_exit_settle(_run_state, environment, 64)
	finalize_chunked_exit_settle(_run_state, environment)


func checkpoint_surface_ui_state_for_save(_ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> void:
	pass


func foundation_save_ready(run_state: RunState, environment: Dictionary) -> bool:
	var key := _live_key(run_state, environment)
	if not _live_machines.has(key):
		return true
	var machine: Dictionary = _live_machines[key]
	var session: Dictionary = machine.get("live_session", {})
	return bool(session.get("durable_ready", false))


func requires_chunked_exit_settle(run_state: RunState, environment: Dictionary) -> bool:
	return _live_machines.has(_live_key(run_state, environment))


func begin_chunked_exit_settle(run_state: RunState, environment: Dictionary) -> Dictionary:
	var key := _live_key(run_state, environment)
	if not _live_machines.has(key):
		return {"started": false, "done": true}
	_exit_settle_active = true
	var machine: Dictionary = _live_machines[key]
	var result := CoinPusherLiveSessionScript.begin_chunked_settle(machine)
	_consume_live_physics_events(run_state, machine, result.get("events", []))
	_register_pile_rumor(run_state, environment, machine)
	return result


func advance_chunked_exit_settle(run_state: RunState, environment: Dictionary, tick_budget: int = 8) -> Dictionary:
	var key := _live_key(run_state, environment)
	if not _live_machines.has(key):
		return {"done": true, "ticks": 0}
	var machine: Dictionary = _live_machines[key]
	var result := CoinPusherLiveSessionScript.advance_chunked_settle(machine, tick_budget)
	var consumed := _consume_live_physics_events(run_state, machine, result.get("events", []))
	if int(result.get("ticks", 0)) > 0:
		_register_pile_rumor(run_state, environment, machine)
	_advance_tell_decay(machine, int(result.get("ticks", 0)))
	if bool(result.get("done", false)) and bool(consumed.get("shim_recovered", false)) and int(result.get("total_ticks", 0)) < CoinPusherLiveSessionScript.MAX_SETTLE_TICKS:
		result["done"] = false
	if bool(result.get("done", false)):
		CoinPusherLiveSessionScript.freeze_after_chunked_settle(machine, int(result.get("total_ticks", 0)))
	# The final chunk has already replaced the live simulation with its settled
	# snapshot. Project that snapshot too so the player sees the actual final
	# arrangement before the surface is dismissed.
	result["surface_state_patch"] = _v3_headless_surface_state(machine)
	if bool(result.get("done", false)):
		_write_live_durable(run_state, environment, machine, false)
		_live_machines.erase(key)
	return result


func finalize_chunked_exit_settle(run_state: RunState, environment: Dictionary) -> void:
	_live_machines.erase(_live_key(run_state, environment))
	_exit_settle_active = false


func _generate_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream = null) -> Dictionary:
	var local_rng := rng
	if local_rng == null:
		local_rng = RngStream.new()
		local_rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", "node"))]))
	var variation_rng := RngStream.new()
	variation_rng.configure(_stable_hash("coin_pusher_variation:%s:%s" % [str(run_state.seed_text if run_state != null else "fallback"), _environment_node_id(run_state, environment)]))
	var variation_id := _seeded_variation_id(environment, variation_rng)
	var variation_config := _variation_config(variation_id)
	var simulation := CoinPusherSolverScript.create_machine(local_rng.fork("fixed_point_pile"), _machine_definition(variation_id), _opening_coin_count(variation_id))
	# Keep never-visited world generation byte-identical to the Stage-1 snapshot.
	# Live apparatus defaults are initialized at the actual entry boundary.
	simulation.erase("carriage_x")
	simulation.erase("selected_hole")
	simulation.erase("collected_count")
	simulation.erase("collected_value")
	var base_tolerance := local_rng.randi_range(_tolerance_min(), _tolerance_max())
	var variation_tolerance := int(variation_config.get("alarm_tolerance_bonus", variation_config.get("alarm_tolerance_delta", 0)))
	var security_tolerance := _security_tolerance_delta(environment, run_state)
	var item_tolerance := JackpotRidgeScript.tolerance_band_bonus(run_state, variation_config) if variation_id == "jackpot_ridge" else 0
	var tolerance := maxi(1, base_tolerance + security_tolerance + variation_tolerance + item_tolerance)
	var node_id := _environment_node_id(run_state, environment)
	var variation_state: Dictionary = {}
	if variation_id == "jackpot_ridge":
		variation_state = JackpotRidgeScript.initial_state(variation_config, local_rng.fork("jackpot_ridge"), _lane_count(), _cell_count())
	elif variation_id == "vault_drop":
		variation_state = VaultDropScript.initial_state(variation_config, local_rng.fork("vault_drop"), _lane_count(), _cell_count(), node_id)
	var machine := {
		"schema": STATE_SCHEMA,
		"version": _state_version(),
		"variation_id": variation_id,
		"variation_state": variation_state,
		"simulation": simulation,
		"riders": _seed_prize_riders(environment, local_rng) if variation_id == "quarter_falls" else [],
		"prize_goal_progress": 0,
		"prize_goal_completions": 0,
		"rider_serial": 0,
		"action_count": 0,
		"tray_value": 0,
		"total_cost": 0,
		"total_payout": 0,
		"base_alarm_tolerance": base_tolerance,
		"alarm_tolerance_remaining": tolerance,
		"tolerance_modifier": tolerance - base_tolerance,
		"variation_tolerance_modifier": variation_tolerance,
		"applied_security_tolerance_modifier": security_tolerance,
		"applied_item_tolerance_modifier": item_tolerance,
		"tell_rung": 0,
		"tell_decay_remaining_ticks": 0,
		"locked_down": false,
		"lockdown_night": "",
		"staff_watch_memory": false,
		"suspicion_floor": 0,
		"cold_quarters_armed": false,
		"cold_quarters_density_armed": 0,
		"shim_initialized": false,
		"shim_uses_remaining": 0,
		"scenario_reset_token": _scenario_reset_token(environment),
		"last_message": _variation_intro(variation_id),
	}
	_sync_physical_features(machine)
	machine["rider_serial"] = (machine.get("riders", []) as Array).size()
	machine["settled_state"] = CoinPusherLiveSessionScript.make_snapshot(_simulation(machine), machine)
	machine.erase("simulation")
	return machine
func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var game_states := _game_states(environment)
	var value: Variant = game_states.get(get_id(), {})
	var machine: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	if not persist and not machine.is_empty() and not _machine_read_requires_reconciliation(machine, run_state, environment):
		return machine
	# Read paths may normalize an old schema, roll a nightly lock forward, or
	# initialize item state. Never let those operations write through an alias.
	if not persist and not machine.is_empty():
		machine = machine.duplicate(true)
	var reset_token := _scenario_reset_token(environment)
	if machine.is_empty():
		machine = _generate_machine_state(run_state, environment)
	elif str(machine.get("schema", "")) != STATE_SCHEMA:
		machine = _normalize_machine_state(machine, run_state, environment)
	elif int(machine.get("version", 0)) < _state_version():
		machine = _normalize_machine_state(machine, run_state, environment)
	elif not reset_token.is_empty() and reset_token != str(machine.get("scenario_reset_token", "")):
		machine = _generate_machine_state(run_state, environment)
		machine["scenario_reset_token"] = reset_token
	if bool(machine.get("locked_down", false)) and run_state != null and str(machine.get("lockdown_night", "")) != _night_id(run_state):
		machine["locked_down"] = false
		machine["lockdown_night"] = ""
		machine["tolerance_modifier"] = int(machine.get("applied_security_tolerance_modifier", 0)) + int(machine.get("variation_tolerance_modifier", 0)) + int(machine.get("applied_item_tolerance_modifier", 0))
		machine["alarm_tolerance_remaining"] = maxi(1, int(machine.get("base_alarm_tolerance", _tolerance_min())) + int(machine.get("tolerance_modifier", 0)))
		machine["tell_rung"] = 0
		machine["tell_decay_remaining_ticks"] = 0
	_initialize_owned_shim(run_state, machine)
	_reconcile_tolerance_modifiers(run_state, environment, machine)
	_sync_vault_meter(run_state, machine)
	if persist and bool(machine.get("v2_migration_pending", false)):
		machine.erase("v2_migration_pending")
		machine["v2_migration_logged"] = true
		if run_state != null:
			run_state.log_story({"type": "coin_pusher_v2_migrated", "game_id": get_id(), "environment_id": str(environment.get("id", "")), "tray_value": int(machine.get("tray_value", 0)), "message": "The rebuilt pusher carries the old tray forward and reseeds its changed playfield."})
	if persist:
		_write_machine_state(environment, machine)
	return machine


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	return _ensure_machine_state(run_state, environment, false)


func _write_machine_state(environment: Dictionary, machine: Dictionary) -> void:
	var game_states := _game_states(environment).duplicate(false)
	game_states[get_id()] = machine
	environment["game_states"] = game_states


func _initialize_owned_shim(run_state: RunState, machine: Dictionary) -> void:
	if run_state == null or bool(machine.get("shim_initialized", false)) or not run_state.inventory.has(SHIM_ITEM_ID):
		return
	machine["shim_initialized"] = true
	machine["shim_uses_remaining"] = _shim_uses(run_state)


func _game_states(environment: Dictionary) -> Dictionary:
	var value: Variant = environment.get("game_states", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _machine_read_requires_reconciliation(machine: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	if str(machine.get("schema", "")) != STATE_SCHEMA or int(machine.get("version", 0)) < _state_version():
		return true
	var reset_token := _scenario_reset_token(environment)
	if not reset_token.is_empty() and reset_token != str(machine.get("scenario_reset_token", "")):
		return true
	var has_live := typeof(machine.get("simulation", {})) == TYPE_DICTIONARY and str((machine.get("simulation", {}) as Dictionary).get("schema", "")) == CoinPusherSolverScript.SCHEMA
	var has_settled := typeof(machine.get("settled_state", {})) == TYPE_DICTIONARY and str((machine.get("settled_state", {}) as Dictionary).get("schema", "")) == CoinPusherLiveSessionScript.SNAPSHOT_SCHEMA
	if (not has_live and not has_settled) \
			or typeof(machine.get("variation_state", {})) != TYPE_DICTIONARY:
		return true
	if bool(machine.get("locked_down", false)) and run_state != null and str(machine.get("lockdown_night", "")) != _night_id(run_state):
		return true
	if run_state != null and not bool(machine.get("shim_initialized", false)) and run_state.inventory.has(SHIM_ITEM_ID):
		return true
	if run_state != null and str(machine.get("variation_id", "")) == "vault_drop":
		var variation_state: Dictionary = machine.get("variation_state", {})
		var meter := run_state.progressive_meter(str(variation_state.get("meter_id", "")))
		if not meter.is_empty() and int(variation_state.get("meter_value", 0)) != int(meter.get("value", variation_state.get("meter_value", 0))):
			return true
	var expected_security := _security_tolerance_delta(environment, run_state)
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	var expected_item := JackpotRidgeScript.tolerance_band_bonus(run_state, _variation_config(variation_id)) if variation_id == "jackpot_ridge" else 0
	if not machine.has("applied_security_tolerance_modifier") or not machine.has("applied_item_tolerance_modifier") \
			or int(machine.get("applied_security_tolerance_modifier", expected_security)) != expected_security \
			or int(machine.get("applied_item_tolerance_modifier", expected_item)) != expected_item:
		return true
	return not _physical_features_reconciled(machine)


func _reconcile_tolerance_modifiers(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	var expected_security := _security_tolerance_delta(environment, run_state)
	var expected_item := JackpotRidgeScript.tolerance_band_bonus(run_state, _variation_config(variation_id)) if variation_id == "jackpot_ridge" else 0
	var previous_item := int(machine.get("applied_item_tolerance_modifier", 0))
	var previous_security := int(machine.get("applied_security_tolerance_modifier", int(machine.get("tolerance_modifier", 0)) - int(machine.get("variation_tolerance_modifier", 0)) - previous_item))
	var modifier_delta := expected_security - previous_security + expected_item - previous_item
	if modifier_delta != 0 and not bool(machine.get("locked_down", false)):
		machine["alarm_tolerance_remaining"] = maxi(1, int(machine.get("alarm_tolerance_remaining", 1)) + modifier_delta)
	machine["applied_security_tolerance_modifier"] = expected_security
	machine["applied_item_tolerance_modifier"] = expected_item
	machine["tolerance_modifier"] = int(machine.get("variation_tolerance_modifier", 0)) + expected_security + expected_item


func _advance_tell_decay(machine: Dictionary, ticks: int) -> void:
	if ticks <= 0 or int(machine.get("tell_rung", 0)) <= 0:
		return
	var period := maxi(1, _int_tuning("tell_decay_ticks", 600))
	var remaining := int(machine.get("tell_decay_remaining_ticks", period)) - ticks
	var rung := int(machine.get("tell_rung", 0))
	while remaining <= 0 and rung > 0:
		rung -= 1
		remaining += period
	machine["tell_rung"] = rung
	machine["tell_decay_remaining_ticks"] = remaining if rung > 0 else 0


func _physical_features_reconciled(machine: Dictionary) -> bool:
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	var has_settled := typeof(machine.get("settled_state", {})) == TYPE_DICTIONARY and str((machine.get("settled_state", {}) as Dictionary).get("schema", "")) == CoinPusherLiveSessionScript.SNAPSHOT_SCHEMA
	if _has_v3_simulation(machine) or has_settled:
		# Physical feature reconciliation is an actual-entry boundary. Background
		# environment reads must leave never-visited world snapshots byte-identical.
		return true
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if simulation.is_empty():
		return false
	var variation_state: Dictionary = machine.get("variation_state", {}) if typeof(machine.get("variation_state", {})) == TYPE_DICTIONARY else {}
	var features: Array = machine.get("riders", []) if variation_id == "quarter_falls" else variation_state.get("pucks", []) if variation_id == "jackpot_ridge" else variation_state.get("fragments", [])
	var kind := "rider" if variation_id == "quarter_falls" else "puck" if variation_id == "jackpot_ridge" else "fragment"
	var desired := {}
	for feature_value in features:
		if typeof(feature_value) != TYPE_DICTIONARY:
			continue
		var feature_id := str((feature_value as Dictionary).get("id", ""))
		if not feature_id.is_empty():
			desired[feature_id] = true
	var seen := {}
	var bodies: Array = simulation.get("bodies", []) if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else []
	for body_value in bodies:
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("kind", "")) != kind:
			continue
		var metadata: Dictionary = (body_value as Dictionary).get("metadata", {}) if typeof((body_value as Dictionary).get("metadata", {})) == TYPE_DICTIONARY else {}
		var feature_id := str(metadata.get("feature_id", ""))
		if feature_id.is_empty() or not desired.has(feature_id) or seen.has(feature_id):
			return false
		seen[feature_id] = true
	return seen.size() == desired.size()


func _normalize_machine_state(source: Dictionary, run_state: RunState = null, environment: Dictionary = {}) -> Dictionary:
	var machine := source.duplicate(true)
	var has_live := typeof(machine.get("simulation", {})) == TYPE_DICTIONARY and str((machine.get("simulation", {}) as Dictionary).get("schema", "")) == CoinPusherSolverScript.SCHEMA
	var has_settled := typeof(machine.get("settled_state", {})) == TYPE_DICTIONARY and str((machine.get("settled_state", {}) as Dictionary).get("schema", "")) == CoinPusherLiveSessionScript.SNAPSHOT_SCHEMA
	var migrated_v2 := not has_live and not has_settled
	var legacy_tray_value := maxi(0, int(machine.get("tray_value", 0)))
	var migration_rng := RngStream.new()
	migration_rng.configure(_stable_hash("coin_pusher_physical_migration:%s:%s" % [_environment_node_id(run_state, environment), str(run_state.seed_text if run_state != null else "fallback")]))
	if migrated_v2:
		var migrated_variation_id := str(machine.get("variation_id", _variation_id()))
		machine["simulation"] = CoinPusherSolverScript.create_machine(migration_rng, _machine_definition(migrated_variation_id), mini(_opening_coin_count(migrated_variation_id), 250))
		var migrated_ledger: Array = []
		for _coin in range(legacy_tray_value):
			migrated_ledger.append({"kind": "coin", "value": 1, "item_id": "", "provenance": {"migration": "v2"}})
		var migrated_simulation: Dictionary = machine["simulation"]
		migrated_simulation["tray_ledger"] = migrated_ledger
		migrated_simulation["opening_body_count"] = (migrated_simulation.get("bodies", []) as Array).size() + migrated_ledger.size()
	machine.erase("lanes")
	machine["schema"] = STATE_SCHEMA
	machine["version"] = _state_version()
	var variation_id := str(machine.get("variation_id", _variation_id()))
	if not ["quarter_falls", "jackpot_ridge", "vault_drop"].has(variation_id) and variation_id != _variation_id():
		variation_id = _variation_id()
	machine["variation_id"] = variation_id
	if typeof(machine.get("variation_state", {})) != TYPE_DICTIONARY:
		machine["variation_state"] = {}
	if (machine.get("variation_state", {}) as Dictionary).is_empty() and variation_id != "quarter_falls":
		var rng := RngStream.new()
		rng.configure(_stable_hash("migrate:%s:%s" % [variation_id, _environment_node_id(run_state, environment)]))
		machine["variation_state"] = JackpotRidgeScript.initial_state(_variation_config(variation_id), rng, _lane_count(), _cell_count()) if variation_id == "jackpot_ridge" else VaultDropScript.initial_state(_variation_config(variation_id), rng, _lane_count(), _cell_count(), _environment_node_id(run_state, environment))
	for key in ["tray_value", "total_cost", "total_payout", "action_count", "tell_rung", "suspicion_floor"]:
		machine[key] = maxi(0, int(machine.get(key, 0)))
	machine["tell_decay_remaining_ticks"] = maxi(0, int(machine.get("tell_decay_remaining_ticks", 0)))
	machine["staff_watch_memory"] = bool(machine.get("staff_watch_memory", false))
	machine["locked_down"] = bool(machine.get("locked_down", false))
	if migrated_v2 and not bool(machine.get("v2_migration_logged", false)):
		machine["v2_migration_pending"] = true
	return machine


func _simulation(machine: Dictionary) -> Dictionary:
	var value: Variant = machine.get("simulation", {})
	if typeof(value) != TYPE_DICTIONARY:
		machine["simulation"] = {}
	return machine.get("simulation", {}) as Dictionary


func _has_v3_simulation(machine: Dictionary) -> bool:
	var simulation_value: Variant = machine.get("simulation", {})
	return typeof(simulation_value) == TYPE_DICTIONARY \
		and str((simulation_value as Dictionary).get("schema", "")) == CoinPusherSolverScript.SCHEMA


func _feature_hardware_descriptor(machine: Dictionary, vault_views: Dictionary) -> Dictionary:
	var force_options: Array = []
	var forces: Dictionary = _tuning().get("nudge_forces", {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	for force in forces.keys():
		force_options.append({"id": str(force), "label": str(force).to_upper(), "action": NUDGE_FORCE_PREFIX + str(force)})
	var direction_options: Array = []
	for direction in ["left", "front", "right"]:
		direction_options.append({"id": direction, "label": direction.left(1).to_upper(), "action": NUDGE_DIRECTION_PREFIX + direction})
	var result := {"schema": "coin_pusher_feature_hardware_v1", "selector_groups": [
		{"rect": Rect2(716, 352, 116, 18), "selected": str(machine.get("nudge_force", "tap")), "options": force_options},
		{"rect": Rect2(716, 404, 116, 18), "selected": str(machine.get("nudge_direction", "front")), "options": direction_options},
	], "panels": []}
	if vault_views.is_empty():
		return result
	var variation_state := _variation_state(machine)
	var round_active := bool(variation_state.get("vault_round_active", false))
	var controls: Array = [{"rect": Rect2(58, 404, 78, 20), "label": "VAULT %s" % ("OPEN" if round_active else "SHUT"), "lit": round_active}]
	var cells: Array = vault_views.get("cells", []) if typeof(vault_views.get("cells", [])) == TYPE_ARRAY else []
	for cell_index in range(cells.size()):
		var cell: Dictionary = cells[cell_index] if typeof(cells[cell_index]) == TYPE_DICTIONARY else {}
		controls.append({
			"rect": Rect2(142.0 + 31.0 * cell_index, 404.0, 28.0, 20.0),
			"label": str(cell.get("label", "?")),
			"action": str(cell.get("selection_action", VAULT_CELL_PREFIX + str(cell_index))),
			"index": cell_index,
			"selected": cell_index == int(machine.get("vault_selected_cell", -1)),
			"lit": bool(cell.get("opened", false)) or bool(cell.get("peeked", false)),
		})
	var action_ids := [VAULT_START_ACTION, VAULT_OPEN_ACTION, VAULT_STOP_ACTION, VAULT_PEEK_ACTION]
	var action_labels := ["OPEN", "CELL", "STOP", "X-RAY"]
	for action_index in range(action_ids.size()):
		controls.append({"rect": Rect2(336.0 + action_index * 62.0, 404.0, 58.0, 20.0), "label": action_labels[action_index], "action": action_ids[action_index], "index": action_index})
	result["panels"] = [{"rect": Rect2(52, 402, 540, 24), "controls": controls}]
	return result


func _v3_headless_surface_state(machine: Dictionary, run_state: RunState = null, environment: Dictionary = {}, ui_state: Dictionary = {}) -> Dictionary:
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var simulation := _simulation(machine) if _has_v3_simulation(machine) else CoinPusherLiveSessionScript.restore_snapshot(machine.get("settled_state", {}), definition)
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	# `begin()` already created the authoritative opening projection. Reuse it on
	# live entry; headless catalog reads without a session still project normally.
	var body_views: Array = session.get("presentation_current_bodies", []) if typeof(session.get("presentation_current_bodies", [])) == TYPE_ARRAY else []
	var body_projection_reused := not body_views.is_empty()
	if body_views.is_empty() and not (simulation.get("bodies", []) as Array).is_empty():
		body_views = CoinPusherSolverScript.body_views(simulation)
	var variation_id := str(machine.get("variation_id", _variation_id()))
	var feature_kind := "rider" if variation_id == "quarter_falls" else "puck" if variation_id == "jackpot_ridge" else "fragment"
	var feature_views := _feature_views(machine, feature_kind)
	var variation_state := _variation_state(machine)
	var vault_views: Dictionary = VaultDropScript.views(variation_state) if variation_id == "vault_drop" else {}
	var cabinet := _resolved_cabinet(variation_id)
	var geometry: Dictionary = (definition.get("geometry", {}) as Dictionary).duplicate(true) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = (definition.get("apparatus", {}) as Dictionary).duplicate(true) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	apparatus["drop_y"] = int(geometry.get("drop_y", CoinPusherSolverScript.DROP_Y))
	# Static-cache dependencies are authored/reinstall state, not live-frame
	# state. Fingerprint them while constructing the complete snapshot so the
	# shipped Web renderer never serializes these nested dictionaries per draw.
	var static_content_key := JSON.stringify([cabinet, geometry, apparatus], "", true).sha256_text()
	var tell_rung := clampi(int(machine.get("tell_rung", 0)), 0, _tell_labels().size() - 1)
	var goal := _machine_goal_state(machine, simulation)
	if not session.is_empty():
		session["presentation_binding_signature"] = _realtime_binding_signature(machine, simulation, tray)
	return GameModule.surface_spec({
		"surface_renderer": "coin_pusher",
		"surface_life": "coin_pusher_v3_alive_cabinet",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": true,
		"surface_pointer_coalesce_moves": true,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_action_catalog_key": _surface_action_catalog_key(machine, run_state, environment, ui_state),
		"surface_action_stake_view": _surface_action_stake_view(run_state, environment),
		"coin_pusher_alive_cabinet": true,
		"coin_pusher_solver_schema": str(simulation.get("schema", "")),
		"coin_pusher_solver_version": int(simulation.get("version", 0)),
		"coin_pusher_body_count": (simulation.get("bodies", []) as Array).size(),
		"coin_pusher_bodies": body_views,
		"coin_pusher_current_packed": session.get("presentation_current_packed", PackedInt64Array()),
		"coin_pusher_entry_body_projection_reused": body_projection_reused,
		"coin_pusher_previous_bodies": session.get("presentation_previous_bodies", body_views),
		"coin_pusher_previous_packed": session.get("presentation_previous_packed", PackedInt64Array()),
		"coin_pusher_presentation_view_serial": int(session.get("presentation_view_serial", 0)),
		"coin_pusher_interpolation_alpha": clampf(float(int(session.get("accumulator_units", 0))) / 1000.0, 0.0, 1.0),
		"coin_pusher_features": feature_views,
		"coin_pusher_feature_count": feature_views.size(),
		"coin_pusher_goal": goal,
		"coin_pusher_riders": feature_views if variation_id == "quarter_falls" else [],
		"coin_pusher_tell_rung": tell_rung,
		"coin_pusher_tell_label": str(_tell_labels()[tell_rung]),
		"coin_pusher_locked": bool(machine.get("locked_down", false)),
		"coin_pusher_phase_fp": int(simulation.get("phase_fp", 0)),
		"coin_pusher_face_position_y": int(simulation.get("face_y", 0)),
		"coin_pusher_previous_face_position_y": int(session.get("presentation_previous_face_y", simulation.get("face_y", 0))),
		"coin_pusher_carriage_x": int(simulation.get("carriage_x", 50000)),
		"coin_pusher_selected_hole": int(simulation.get("selected_hole", 0)),
		"coin_pusher_skill_stop_engaged": bool(simulation.get("skill_stop_engaged", false)),
		"coin_pusher_motor_rate_fp": int(simulation.get("motor_rate_fp", CoinPusherSolverScript.FP)),
		"coin_pusher_motor_started": bool(machine.get("motor_started", false)),
		"coin_pusher_selected_nozzle_id": str(machine.get("selected_nozzle_id", _selected_nozzle_id(machine, simulation))),
		"coin_pusher_drop_queue_count": _queued_drop_count(machine),
		"coin_pusher_drop_charge_count": int(ui_state.get("coin_pusher_drop_charge_count", 0)),
		"coin_pusher_tray_count": tray.size(),
		"coin_pusher_tray_value": _ledger_value(tray),
		"coin_pusher_input_trace_count": (session.get("input_trace", []) as Array).size() if typeof(session.get("input_trace", [])) == TYPE_ARRAY else 0,
		"coin_pusher_liveness_ticks": int(session.get("liveness_ticks", 0)),
		"coin_pusher_variation_id": variation_id,
		"coin_pusher_variation_name": _variation_display_name(variation_id),
		"coin_pusher_cabinet": cabinet,
		"coin_pusher_geometry": geometry,
		"coin_pusher_apparatus": apparatus,
		"coin_pusher_static_content_key": static_content_key,
		"coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", CoinPusherSolverScript.COIN_HEIGHT)) if typeof(definition.get("coins", {})) == TYPE_DICTIONARY else CoinPusherSolverScript.COIN_HEIGHT,
		"coin_pusher_coin_radius": int((definition.get("coins", {}) as Dictionary).get("radius", CoinPusherSolverScript.COIN_RADIUS)) if typeof(definition.get("coins", {})) == TYPE_DICTIONARY else CoinPusherSolverScript.COIN_RADIUS,
		"coin_pusher_ridge_multiplier": JackpotRidgeScript.payout_multiplier(variation_state) if variation_id == "jackpot_ridge" else 1,
		"coin_pusher_vault_meter": int(variation_state.get("meter_value", 0)) if variation_id == "vault_drop" else 0,
		"coin_pusher_vault_fragments": int(variation_state.get("banked_fragments", 0)) if variation_id == "vault_drop" else 0,
		"coin_pusher_vault_cells": vault_views.get("cells", []),
		"coin_pusher_vault_round_active": bool(variation_state.get("vault_round_active", false)) if variation_id == "vault_drop" else false,
		"coin_pusher_vault_peeked_cell": int(variation_state.get("peeked_cell", -1)) if variation_id == "vault_drop" else -1,
		"coin_pusher_vault_selected_cell": int(machine.get("vault_selected_cell", 0)),
		"coin_pusher_nudge_force": str(machine.get("nudge_force", "tap")),
		"coin_pusher_nudge_direction": str(machine.get("nudge_direction", "front")),
		"coin_pusher_nudge_forces": (_tuning().get("nudge_forces", {}) as Dictionary).duplicate(true) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {},
		"coin_pusher_feature_hardware": _feature_hardware_descriptor(machine, vault_views),
		"coin_pusher_audio_events": [],
		"coin_pusher_audio_serial": int(session.get("presentation_audio_serial", 0)),
		"coin_pusher_last_message": str(machine.get("last_message", V3_HEADLESS_MESSAGE)),
		"native_selected_surface_actions": _native_surface_actions(machine),
		"surface_action_bindings": _coin_pusher_action_bindings(machine, simulation, tray, run_state, environment),
		"surface_animation_channels": [],
		"surface_audio": GameModule.surface_audio_spec({"profile_id": "coin_pusher", "state_sync": {"method": "coin_pusher_state"}}),
	})


func _v3_realtime_presentation_patch(machine: Dictionary, run_state: RunState = null, environment: Dictionary = {}) -> Dictionary:
	var simulation := _simulation(machine)
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	var body_views: Array = session.get("presentation_current_bodies", []) if typeof(session.get("presentation_current_bodies", [])) == TYPE_ARRAY else []
	if body_views.is_empty() and not (simulation.get("bodies", []) as Array).is_empty():
		body_views = CoinPusherSolverScript.body_views(simulation)
	var previous_views: Array = session.get("presentation_previous_bodies", body_views) if typeof(session.get("presentation_previous_bodies", body_views)) == TYPE_ARRAY else body_views
	var current_packed: PackedInt64Array = session.get("presentation_current_packed", PackedInt64Array()) if typeof(session.get("presentation_current_packed", PackedInt64Array())) == TYPE_PACKED_INT64_ARRAY else PackedInt64Array()
	var tell_rung := clampi(int(machine.get("tell_rung", 0)), 0, _tell_labels().size() - 1)
	var variation_state := _variation_state(machine)
	var goal := _machine_goal_state(machine, simulation)
	var vault_views: Dictionary = VaultDropScript.views(variation_state) if str(machine.get("variation_id", "")) == "vault_drop" else {}
	var patch := {
		"coin_pusher_body_count": current_packed.size() / 9 if not current_packed.is_empty() else body_views.size(),
		"coin_pusher_feature_count": int(session.get("presentation_feature_count", 0)),
		"coin_pusher_goal": goal,
		"coin_pusher_bodies": body_views,
		"coin_pusher_current_packed": current_packed,
		"coin_pusher_previous_bodies": previous_views,
		"coin_pusher_previous_packed": session.get("presentation_previous_packed", PackedInt64Array()),
		"coin_pusher_presentation_view_serial": int(session.get("presentation_view_serial", 0)),
		"coin_pusher_interpolation_alpha": clampf(float(int(session.get("accumulator_units", 0))) / 1000.0, 0.0, 1.0),
		"coin_pusher_tell_rung": tell_rung,
		"coin_pusher_tell_label": str(_tell_labels()[tell_rung]),
		"coin_pusher_locked": bool(machine.get("locked_down", false)),
		"coin_pusher_carriage_x": int(simulation.get("carriage_x", 50000)),
		"coin_pusher_selected_hole": int(simulation.get("selected_hole", 0)),
		"coin_pusher_face_position_y": int(simulation.get("face_y", CoinPusherSolverScript.FACE_EXTENDED_Y)),
		"coin_pusher_previous_face_position_y": int(session.get("presentation_previous_face_y", simulation.get("face_y", CoinPusherSolverScript.FACE_EXTENDED_Y))),
		"coin_pusher_phase_fp": int(simulation.get("phase_fp", 0)),
		"coin_pusher_skill_stop_engaged": bool(simulation.get("skill_stop_engaged", false)),
		"coin_pusher_motor_rate_fp": int(simulation.get("motor_rate_fp", CoinPusherSolverScript.FP)),
		"coin_pusher_motor_started": bool(machine.get("motor_started", false)),
		"coin_pusher_selected_nozzle_id": str(machine.get("selected_nozzle_id", _selected_nozzle_id(machine, simulation))),
		"coin_pusher_drop_queue_count": _queued_drop_count(machine),
		"coin_pusher_tray_count": tray.size(),
		"coin_pusher_tray_value": _ledger_value(tray),
		"coin_pusher_input_trace_count": (machine.get("live_session", {}).get("input_trace", []) as Array).size() if typeof(machine.get("live_session", {}).get("input_trace", [])) == TYPE_ARRAY else 0,
		"coin_pusher_last_step_metrics": simulation.get("last_step_metrics", {}),
		"coin_pusher_liveness_ticks": int(session.get("liveness_ticks", 0)),
		"coin_pusher_last_message": str(machine.get("last_message", V3_HEADLESS_MESSAGE)),
		"coin_pusher_vault_cells": vault_views.get("cells", []),
		"coin_pusher_vault_round_active": bool(variation_state.get("vault_round_active", false)),
		"coin_pusher_vault_peeked_cell": int(variation_state.get("peeked_cell", -1)),
		"coin_pusher_vault_selected_cell": int(machine.get("vault_selected_cell", 0)),
		"coin_pusher_nudge_force": str(machine.get("nudge_force", "tap")),
		"coin_pusher_nudge_direction": str(machine.get("nudge_direction", "front")),
		"coin_pusher_feature_hardware": _feature_hardware_descriptor(machine, vault_views),
	}
	# The entry snapshot owns the full control catalog. Ordinary live ticks only
	# republish bindings when a control-visible state actually changes.
	var binding_signature := _realtime_binding_signature(machine, simulation, tray)
	if int(session.get("presentation_binding_signature", -1)) != binding_signature:
		patch["surface_action_bindings"] = _coin_pusher_action_bindings(machine, simulation, tray, run_state, environment)
		session["presentation_binding_signature"] = binding_signature
	return patch


func _realtime_binding_signature(machine: Dictionary, simulation: Dictionary, tray: Array) -> int:
	var variation_state := _variation_state(machine)
	return (1 if _drop_refused(machine) else 0) \
		| ((1 if bool(simulation.get("skill_stop_engaged", false)) else 0) << 1) \
		| ((1 if not tray.is_empty() else 0) << 2) \
		| ((1 if bool(machine.get("locked_down", false)) else 0) << 3) \
		| (clampi(int(simulation.get("selected_hole", 0)), 0, 3) << 4) \
		| ((1 if bool(variation_state.get("vault_round_active", false)) else 0) << 7) \
		| ((1 if int(variation_state.get("banked_fragments", 0)) > 0 else 0) << 8)


func _queued_drop_count(machine: Dictionary) -> int:
	var total := 0
	for item_value in machine.get("drop_queue", []):
		if typeof(item_value) == TYPE_DICTIONARY:
			total += maxi(0, int((item_value as Dictionary).get("remaining", 0)))
	return total


func _machine_goal_state(machine: Dictionary, simulation: Dictionary) -> Dictionary:
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	var variation_state := _variation_state(machine)
	match variation_id:
		"jackpot_ridge":
			var target := maxi(1, int(_variation_config(variation_id).get("ridge_run_goal", 3)))
			return {
				"id": "ridge_run",
				"title": "RIDGE RUN  x%d" % JackpotRidgeScript.payout_multiplier(variation_state),
				"instruction": "BANK %d MULTIPLIER PUCKS" % target,
				"progress": clampi(int(variation_state.get("ridge_goal_progress", 0)), 0, target),
				"target": target,
				"bonus_tokens": maxi(0, int(_variation_config(variation_id).get("ridge_run_bonus_tokens", 5))),
				"active": int(variation_state.get("ridge_run_cycles_remaining", 0)) > 0,
			}
		"vault_drop":
			var target := maxi(1, int(_variation_config(variation_id).get("key_streak_goal", 3)))
			return {
				"id": "vault_keys",
				"title": "VAULT KEYS  $%d" % int(variation_state.get("meter_value", 0)),
				"instruction": "PUSH 3 KEY FRAGMENTS: EACH ONE UNLOCKS A VAULT CELL",
				"progress": clampi(int(variation_state.get("key_streak_progress", 0)), 0, target),
				"target": target,
				"bonus_tokens": maxi(0, int(_variation_config(variation_id).get("key_streak_bonus_tokens", 6))),
				"active": bool(variation_state.get("vault_round_active", false)),
			}
		_:
			var target := maxi(1, _int_tuning("prize_goal_target", 3))
			return {
				"id": "prize_rush",
				"title": "PRIZE RUSH",
				"instruction": "PUSH %d HEAVY PRIZES INTO THE WIN TRAY" % target,
				"progress": clampi(int(machine.get("prize_goal_progress", 0)), 0, target),
				"target": target,
				"bonus_tokens": maxi(0, _int_tuning("prize_goal_bonus_tokens", 5)),
				"active": false,
			}


func _coin_pusher_action_bindings(machine: Dictionary, simulation: Dictionary, tray: Array, run_state: RunState = null, environment: Dictionary = {}) -> Dictionary:
	var result := {
		"coin_pusher_drop": {"label": "DROP", "enabled": not _drop_refused(machine)},
		DROP_CHARGE_ACTION: {"label": "HOLD TO DROP", "enabled": not _drop_refused(machine)},
		SKILL_STOP_ACTION: {"label": "RELEASE" if bool(simulation.get("skill_stop_engaged", false)) else "SKILL STOP", "enabled": true, "lit": bool(simulation.get("skill_stop_engaged", false))},
		COLLECT_ACTION: {"label": "COLLECT", "enabled": not tray.is_empty()},
		"coin_pusher_nudge": {"action": "surface_cheat", "index": 0, "label": "NUDGE", "enabled": true},
	}
	result.merge(_apparatus_action_bindings(machine, simulation), true)
	var busy := _machine_busy(environment)
	var locked := bool(machine.get("locked_down", false))
	for action_id in result.keys():
		var binding: Dictionary = result[action_id]
		if busy or (locked and str(action_id) != COLLECT_ACTION):
			binding["enabled"] = false
	if result.has(VAULT_PEEK_ACTION) and (run_state == null or not run_state.inventory.has("xray_glasses")):
		(result[VAULT_PEEK_ACTION] as Dictionary)["enabled"] = false
	return result


func _surface_action_view_patch(machine: Dictionary, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	# Deferred embedded actions only need the shallow, action-boundary scalars.
	# The following realtime patch remains the single owner of dense body views,
	# so a DROP never copies the full 300-body surface merely to refresh the HUD.
	var simulation := _simulation(machine)
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	return {
		# This surface already refreshes from its continuous live loop. Asking for
		# another dense body projection inside the deferred action refresh would
		# duplicate the same frame's work; the next live tick catches up from the
		# deterministic surface clock.
		"surface_action_realtime_refresh_required": false,
		"surface_action_catalog_key": _surface_action_catalog_key(machine, run_state, environment, ui_state),
		"surface_action_stake_view": _surface_action_stake_view(run_state, environment),
		"coin_pusher_action_count": int(machine.get("action_count", 0)),
		"coin_pusher_last_message": str(machine.get("last_message", V3_HEADLESS_MESSAGE)),
		"coin_pusher_goal": _machine_goal_state(machine, simulation),
		"coin_pusher_tray_count": tray.size(),
		"coin_pusher_tray_value": _ledger_value(tray),
		"coin_pusher_input_trace_count": (machine.get("live_session", {}).get("input_trace", []) as Array).size() if typeof(machine.get("live_session", {}).get("input_trace", [])) == TYPE_ARRAY else 0,
		"native_selected_surface_actions": _native_surface_actions(machine),
		"surface_action_bindings": _coin_pusher_action_bindings(machine, simulation, tray, run_state, environment),
	}


func _surface_action_catalog_key(machine: Dictionary, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> String:
	# These are the exact dependencies of legal_actions()/cheat_actions().
	# Body motion, carriage position, bankroll, and animation time do not alter
	# the catalog and therefore must not force it to be rebuilt every frame.
	var challenge_cheats_disabled := run_state != null and run_state.challenge_cheat_actions_disabled()
	var security_risk_bonus := run_state.security_risk_bonus("cheat") if run_state != null else 0
	var security_pressure_label := run_state.security_pressure_label() if run_state != null else ""
	var security_pressure_summary := run_state.security_pressure_summary() if run_state != null else ""
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	return JSON.stringify([
		get_id(),
		str(environment.get("id", "")),
		str(ui_state.get("selected_action_id", "")),
		str(ui_state.get("selected_action_kind", "")),
		_machine_busy(environment),
		bool(machine.get("locked_down", false)),
		str(machine.get("variation_id", _variation_id())),
		run_state != null and run_state.inventory.has("xray_glasses"),
		challenge_cheats_disabled,
		security_risk_bonus,
		security_pressure_label,
		security_pressure_summary,
		bool(pit_boss_status.get("active", false)),
		bool(pit_boss_status.get("watched", false)),
		int(pit_boss_status.get("cheat_heat_bonus", 0)),
		str(pit_boss_status.get("summary", "")),
	])


func _surface_action_stake_view(run_state: RunState, environment: Dictionary) -> Dictionary:
	var capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 0
	return {
		"stake_floor": _drop_cost(),
		"stake_ceiling": maxi(_drop_cost(), capacity),
		"base_stake_ceiling": maxi(_drop_cost(), capacity),
		"economy_state": run_state.economy() if run_state != null else {},
		"economy_pressure_applied": false,
	}


func _ensure_live_machine(run_state: RunState, environment: Dictionary) -> Dictionary:
	var key := _live_key(run_state, environment)
	if _live_machines.has(key):
		return _live_machines[key]
	# During the final rendered handoff, surface reads may still occur after the
	# solver was frozen. They must project the durable snapshot, never reopen it.
	if _exit_settle_active:
		return _read_machine_state(run_state, environment)
	var machine := _read_machine_state(run_state, environment).duplicate(true)
	var settled: Dictionary = machine.get("settled_state", {}) if typeof(machine.get("settled_state", {})) == TYPE_DICTIONARY else {}
	if _has_v3_simulation(machine) and str(settled.get("schema", "")) != CoinPusherLiveSessionScript.SNAPSHOT_SCHEMA:
		machine["settled_state"] = CoinPusherLiveSessionScript.make_snapshot(_simulation(machine), machine)
	var seed := _stable_hash("pusher_live:%s:%s" % [str(run_state.seed_text if run_state != null else "fallback"), _environment_node_id(run_state, environment)])
	CoinPusherLiveSessionScript.begin(machine, _machine_definition(str(machine.get("variation_id", _variation_id()))), seed)
	_sync_physical_features(machine)
	_sync_variation_motor(machine)
	_live_machines[key] = machine
	return machine


func _live_key(run_state: RunState, environment: Dictionary) -> String:
	return "%s:%s" % [_environment_node_id(run_state, environment), transient_state_key_context()]


func _write_live_durable(run_state: RunState, environment: Dictionary, live_machine: Dictionary, update_snapshot: bool) -> void:
	if bool(live_machine.get("v2_migration_pending", false)):
		live_machine.erase("v2_migration_pending")
		live_machine["v2_migration_logged"] = true
		if run_state != null:
			run_state.log_story({"type": "coin_pusher_v2_migrated", "game_id": get_id(), "environment_id": str(environment.get("id", "")), "tray_value": int(live_machine.get("tray_value", 0)), "message": "The rebuilt pusher carries the old tray forward and reseeds its changed playfield."})
	# Active ticks retain a large live simulation while the environment owns the
	# last settled checkpoint. Rebuilding the durable record by deep-copying the
	# live machine copied both 300-body graphs only to discard the simulation.
	# Patch the existing durable record instead, preserving its immutable settled
	# checkpoint until an explicit settle boundary replaces it.
	var game_states := _game_states(environment)
	var existing_value: Variant = game_states.get(get_id(), {})
	var durable: Dictionary = (existing_value as Dictionary).duplicate(false) if typeof(existing_value) == TYPE_DICTIONARY else {}
	for durable_key in durable.keys():
		if durable_key != "settled_state" and not live_machine.has(durable_key):
			durable.erase(durable_key)
	for live_key in live_machine.keys():
		if live_key in ["simulation", "live_session", "settled_state"]:
			continue
		var live_value: Variant = live_machine[live_key]
		durable[live_key] = live_value.duplicate(true) if typeof(live_value) in [TYPE_DICTIONARY, TYPE_ARRAY] else live_value
	if update_snapshot and _has_v3_simulation(live_machine):
		durable["settled_state"] = CoinPusherLiveSessionScript.make_snapshot(_simulation(live_machine), live_machine)
	elif not live_machine.has("simulation") and typeof(live_machine.get("settled_state", {})) == TYPE_DICTIONARY:
		# freeze_after_chunked_settle() has already replaced the active solver with
		# its final checkpoint. This is the explicit persistence boundary, so the
		# newly frozen state must replace the prior durable checkpoint.
		durable["settled_state"] = (live_machine.get("settled_state", {}) as Dictionary).duplicate(true)
	elif not durable.has("settled_state"):
		var settled_value: Variant = live_machine.get("settled_state", {})
		durable["settled_state"] = settled_value.duplicate(true) if typeof(settled_value) == TYPE_DICTIONARY else {}
	_write_machine_state(environment, durable)


func _drop_refused(machine: Dictionary) -> bool:
	if str(machine.get("variation_id", "")) == "jackpot_ridge":
		CoinPusherLiveSessionScript.sync_native_body_state(machine)
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var simulation := _simulation(machine) if _has_v3_simulation(machine) else CoinPusherLiveSessionScript.restore_snapshot(machine.get("settled_state", {}), definition)
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var packed: PackedInt64Array = session.get("presentation_current_packed", PackedInt64Array()) if typeof(session.get("presentation_current_packed", PackedInt64Array())) == TYPE_PACKED_INT64_ARRAY else PackedInt64Array()
	var live_body_count := packed.size() / 9 if not packed.is_empty() else (simulation.get("bodies", []) as Array).size()
	if simulation.is_empty() or live_body_count >= int(definition.get("ceiling", 600)):
		return true
	if str(machine.get("variation_id", "")) == "jackpot_ridge":
		return _jammed_holes(machine, simulation).has(int(simulation.get("selected_hole", 0)))
	return false


func _jammed_holes(machine: Dictionary, simulation: Dictionary) -> Array:
	if str(machine.get("variation_id", "")) != "jackpot_ridge":
		return []
	return JackpotRidgeScript.jammed_holes(_variation_state(machine), CoinPusherSolverScript.body_views(simulation), _machine_definition("jackpot_ridge"))


func _drop_provenance(machine: Dictionary) -> Dictionary:
	# Ridge value is sampled only when the physical coin crosses the tray lip.
	# Insertion-time provenance would incorrectly preserve an expired multiplier.
	return {}


func _variation_motor_rate_fp(machine: Dictionary) -> int:
	if str(machine.get("variation_id", "quarter_falls")) != "jackpot_ridge":
		return CoinPusherSolverScript.FP
	return CoinPusherSolverScript.FP * JackpotRidgeScript.motor_rate_multiplier(_variation_state(machine), _variation_config("jackpot_ridge"))


func _sync_variation_motor(machine: Dictionary) -> void:
	var simulation := _simulation(machine)
	if simulation.is_empty():
		return
	var desired := _variation_motor_rate_fp(machine)
	if int(simulation.get("motor_run_rate_fp", CoinPusherSolverScript.FP)) == desired:
		return
	CoinPusherSolverScript.set_motor_run_rate(simulation, desired)
	CoinPusherLiveSessionScript.queue_input(machine, {"kind": "motor_rate", "rate_fp": desired})


func _write_ridge_tray_multiplier(simulation: Dictionary, body_id: String, multiplier: int) -> void:
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	for index in range(tray.size() - 1, -1, -1):
		if typeof(tray[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = tray[index]
		if str(entry.get("body_id", "")) != body_id:
			continue
		var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
		provenance["variation_id"] = "jackpot_ridge"
		provenance["ridge_multiplier"] = maxi(1, multiplier)
		entry["provenance"] = provenance
		return


func _ledger_value(ledger: Array) -> int:
	var total := 0
	for entry_value in ledger:
		if typeof(entry_value) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_value
			var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
			total += maxi(0, int(entry.get("value", 0))) * maxi(1, int(provenance.get("ridge_multiplier", 1)))
	return total


func _collect_surface_command(run_state: RunState, environment: Dictionary, machine: Dictionary) -> Dictionary:
	var simulation := _simulation(machine)
	var tray: Array = (simulation.get("tray_ledger", []) as Array).duplicate(true)
	CoinPusherLiveSessionScript.queue_input(machine, {"kind": "collect"})
	var collected := CoinPusherSolverScript.collect_tray(simulation)
	var cash := _ledger_value(tray)
	var items: Array = collected.get("items", []) if typeof(collected.get("items", [])) == TYPE_ARRAY else []
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = cash
	deltas["inventory_add"] = items
	deltas["story_log"] = [_story_entry(COLLECT_ACTION, "free", environment, cash, 0, {"tray_count": tray.size()})]
	var message := "The tray is empty." if tray.is_empty() else "You collect $%d from %d tray pieces." % [cash, tray.size()]
	deltas["messages"] = [message]
	var result := GameModule.build_owned_action_result({"source_id": get_id(), "game_id": get_id(), "action_id": COLLECT_ACTION, "action_kind": "free", "environment_id": str(environment.get("id", "")), "deltas": deltas, "message": message})
	GameModule.apply_result(run_state, result)
	_write_live_durable(run_state, environment, machine, false)
	_register_pile_rumor(run_state, environment, machine)
	var patch := _surface_action_view_patch(machine, run_state, environment)
	patch["coin_pusher_collected_count"] = int(simulation.get("collected_count", 0))
	patch["coin_pusher_collected_value"] = int(simulation.get("collected_value", 0))
	return GameModule.surface_command({"handled": true, "environment_changed": true, "message": message, "surface_state_patch": patch, "preserve_surface_ui_state": true}, true)


func _resolve_live_nudge(run_state: RunState, environment: Dictionary, machine: Dictionary, ui_state: Dictionary) -> Dictionary:
	var force := str(ui_state.get("coin_pusher_force", machine.get("nudge_force", "tap")))
	var direction := str(ui_state.get("coin_pusher_direction", machine.get("nudge_direction", "front")))
	var force_data: Dictionary = (_tuning().get("nudge_forces", {}) as Dictionary).get(force, {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	var push_strength := maxi(1, int(force_data.get("push_strength", 1)))
	if str(machine.get("variation_id", "")) == "jackpot_ridge" and run_state != null and run_state.inventory.has("weighted_keyring"):
		push_strength += maxi(1, int(_variation_config("jackpot_ridge").get("nudge_force_granularity", 1)))
	var impulse := push_strength * 1200
	var x := -impulse if direction == "left" else impulse if direction == "right" else 0
	var y := -impulse if direction == "front" else 0
	var tolerance_cost := maxi(0, int(force_data.get("tolerance_cost", 1)))
	machine["alarm_tolerance_remaining"] = int(machine.get("alarm_tolerance_remaining", 1)) - tolerance_cost
	var alarmed := int(machine.get("alarm_tolerance_remaining", 0)) <= 0
	if alarmed:
		machine["locked_down"] = true
		machine["lockdown_night"] = _night_id(run_state)
		machine["staff_watch_memory"] = true
		machine["suspicion_floor"] = _watch_suspicion_floor()
	else:
		machine["tell_rung"] = maxi(int(machine.get("tell_rung", 0)), _tell_rung(machine))
		if int(machine.get("tell_rung", 0)) > 0:
			machine["tell_decay_remaining_ticks"] = maxi(1, _int_tuning("tell_decay_ticks", 600))
	CoinPusherLiveSessionScript.queue_input(machine, {"kind": "nudge", "x": x, "y": y})
	_write_live_durable(run_state, environment, machine, false)
	var heat := _alarm_heat() if alarmed else _attendant_glance_heat()
	var deltas := GameModule.empty_result_deltas()
	deltas["suspicion_delta"] = heat
	deltas["story_log"] = [_story_entry(NUDGE_ACTION, "cheat", environment, 0, heat, {"force": force, "direction": direction, "alarmed": alarmed})]
	var message := "The alarm chirps and the cabinet locks for the night." if alarmed else "The cabinet shifts. %s." % _tell_label(int(machine.get("tell_rung", 0)))
	deltas["messages"] = [message]
	var result := GameModule.build_owned_action_result({"source_id": get_id(), "game_id": get_id(), "action_id": NUDGE_ACTION, "action_kind": "cheat", "environment_id": str(environment.get("id", "")), "deltas": deltas, "message": message})
	result["host_apply_result"] = true
	result["surface_audio_cue"] = "coin_pusher_alarm" if alarmed else "coin_pusher_chirp"
	result["surface_audio_context"] = {"tell_rung": int(machine.get("tell_rung", 0)), "alarmed": alarmed}
	return result


func _consume_physics_events(run_state: RunState, machine: Dictionary, events: Array, rng: RngStream) -> Dictionary:
	var payout := 0
	var prizes: Array = []
	var gutter_count := 0
	var shim_recovered := false
	var riders: Array = machine.get("riders", []) if typeof(machine.get("riders", [])) == TYPE_ARRAY else []
	var remaining_riders: Array = []
	var rider_exits := {}
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_kind := str(event.get("kind", ""))
		if event_kind == "stroke_cycle":
			if variation_id == "jackpot_ridge":
				JackpotRidgeScript.advance_stroke_cycle(_variation_state(machine), int(event.get("stroke_cycle", 0)))
				_sync_variation_motor(machine)
			continue
		if event_kind == "plinko_cup":
			var reward: Dictionary = event.get("reward", {}) if typeof(event.get("reward", {})) == TYPE_DICTIONARY else {}
			if str(reward.get("kind", "")) == "instant_payout":
				var instant_value := maxi(0, int(reward.get("value", 0)))
				if instant_value > 0 and run_state != null:
					run_state.change_bankroll(instant_value)
					machine["total_payout"] = int(machine.get("total_payout", 0)) + instant_value
					machine["target_payout_value"] = int(machine.get("target_payout_value", 0)) + instant_value
			elif str(reward.get("kind", "")) == "drop_multiplier":
				var metadata: Dictionary = event.get("metadata", {}) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
				var provenance: Dictionary = metadata.get("provenance", {}) if typeof(metadata.get("provenance", {})) == TYPE_DICTIONARY else {}
				var definition := _machine_definition(variation_id)
				var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
				var depth := maxi(0, int(provenance.get("chain_depth", 0)))
				var depth_cap := maxi(1, int(apparatus.get("chain_depth_cap", 3)))
				var award_count := clampi(int(reward.get("count", 0)), 0, maxi(0, int(apparatus.get("chain_coin_cap", 60))))
				var nozzle_id := str(provenance.get("source_nozzle_id", _selected_nozzle_id(machine, _simulation(machine))))
				if depth < depth_cap and award_count > 0:
					CoinPusherLiveSessionScript.enqueue_drops(machine, {"nozzle_id": nozzle_id, "density": 1, "provenance": _drop_provenance(machine), "chain_depth": depth + 1, "parent_body_id": str(event.get("body_id", "")), "bonus_origin": true}, award_count)
			continue
		# Contact/peg/deposit events are presentation evidence only. Outcome
		# accounting consumes the solver's explicit terminal tray/gutter events;
		# avoid decoding body metadata for every collision in a dense drop.
		if event_kind != "tray" and event_kind != "gutter":
			continue
		var outcome := str(event.get("outcome", event_kind if event_kind in ["tray", "gutter"] else ""))
		var kind := str(event.get("body_kind", event_kind if not event_kind in ["tray", "gutter"] else "coin"))
		if outcome == "gutter":
			gutter_count += 1
		if kind == "coin":
			if outcome == "tray":
				payout += _coin_value()
				if variation_id == "jackpot_ridge":
					var ridge_state := _variation_state(machine)
					_write_ridge_tray_multiplier(_simulation(machine), str(event.get("body_id", "")), JackpotRidgeScript.payout_multiplier(ridge_state))
					var period := int((_machine_definition(variation_id).get("stroke", {}) as Dictionary).get("period_ticks", 240))
					JackpotRidgeScript.finish_drop(ridge_state, int(event.get("stroke_cycle", 0)), int(event.get("phase_fp", 0)), period)
			elif outcome == "gutter" and not shim_recovered and _shim_available(run_state, machine):
				machine["shim_uses_remaining"] = maxi(0, int(machine.get("shim_uses_remaining", 0)) - 1)
				var definition := _machine_definition(variation_id)
				var width := int((definition.get("geometry", {}) as Dictionary).get("width", CoinPusherSolverScript.WIDTH))
				var return_input := {
					"kind": "gutter_return",
					"body_id": str(event.get("body_id", "")),
					"body_kind": kind,
					"side": "left" if int(event.get("x", width / 2)) < width / 2 else "right",
					"radius": int(event.get("radius", CoinPusherSolverScript.COIN_RADIUS)),
					"height": int(event.get("height", CoinPusherSolverScript.COIN_HEIGHT)),
					"mass": int(event.get("mass", CoinPusherSolverScript.FP)),
					"metadata": (event.get("metadata", {}) as Dictionary).duplicate(true) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {},
				}
				var returned := CoinPusherSolverScript.return_gutter_body(_simulation(machine), return_input)
				if bool(returned.get("accepted", false)):
					CoinPusherLiveSessionScript.queue_input(machine, return_input)
					shim_recovered = true
		elif kind == "rider":
			var feature_id := str((event.get("metadata", {}) as Dictionary).get("feature_id", "")) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else ""
			rider_exits[feature_id] = outcome
		elif kind == "puck" and variation_id == "jackpot_ridge":
			var ridge_outcome := JackpotRidgeScript.apply_physical_events(_variation_state(machine), [event], _variation_config(variation_id), int(event.get("stroke_cycle", 0)))
			if bool(ridge_outcome.get("ridge_run_triggered", false)):
				var ridge_bonus := maxi(0, int(_variation_config(variation_id).get("ridge_run_bonus_tokens", 5)))
				var ridge_runs := maxi(1, int(ridge_outcome.get("ridge_runs_triggered", 1)))
				_enqueue_feature_bonus(machine, ridge_bonus * ridge_runs, "ridge_run")
				machine["last_message"] = "RIDGE RUN! The heavy pucks start a fast cycle and feed %d bonus tokens." % (ridge_bonus * ridge_runs)
			_sync_variation_motor(machine)
		elif kind == "fragment" and variation_id == "vault_drop":
			var vault_outcome := VaultDropScript.apply_physical_events(_variation_state(machine), [event])
			var fragments_banked := int(vault_outcome.get("fragments_banked", 0))
			if fragments_banked > 0:
				var vault_state := _variation_state(machine)
				var streak_target := maxi(1, int(_variation_config(variation_id).get("key_streak_goal", 3)))
				var streak := int(vault_state.get("key_streak_progress", 0)) + fragments_banked
				if streak >= streak_target:
					var vault_bonus := maxi(0, int(_variation_config(variation_id).get("key_streak_bonus_tokens", 6)))
					_enqueue_feature_bonus(machine, vault_bonus, "vault_key_streak")
					streak = posmod(streak, streak_target)
					machine["last_message"] = "KEY STREAK! Three heavy fragments feed %d bonus tokens. Open the vault cells when ready." % vault_bonus
				vault_state["key_streak_progress"] = streak
	for rider_value in riders:
		if typeof(rider_value) != TYPE_DICTIONARY:
			continue
		var rider: Dictionary = rider_value
		var rider_id := str(rider.get("id", ""))
		if not rider_exits.has(rider_id):
			remaining_riders.append(rider)
		elif str(rider_exits[rider_id]) == "tray":
			prizes.append(rider)
	machine["riders"] = remaining_riders
	if variation_id == "quarter_falls" and not rider_exits.is_empty():
		var prize_target := maxi(1, _int_tuning("prize_goal_target", 3))
		var prize_progress := int(machine.get("prize_goal_progress", 0)) + prizes.size()
		while prize_progress >= prize_target:
			prize_progress -= prize_target
			machine["prize_goal_completions"] = int(machine.get("prize_goal_completions", 0)) + 1
			var prize_bonus := maxi(0, _int_tuning("prize_goal_bonus_tokens", 5))
			_enqueue_feature_bonus(machine, prize_bonus, "prize_rush")
			machine["last_message"] = "PRIZE RUSH! The heavy prizes trip the bonus feeder for %d extra tokens." % prize_bonus
		machine["prize_goal_progress"] = prize_progress
		_replenish_quarter_riders(machine, rng)
		_sync_physical_features(machine)
	return {"payout": payout, "prizes": prizes, "gutter_count": gutter_count, "shim_recovered": shim_recovered}


func _enqueue_feature_bonus(machine: Dictionary, count: int, origin: String) -> int:
	if count <= 0 or not _has_v3_simulation(machine):
		return 0
	var simulation := _simulation(machine)
	var nozzle_id := _selected_nozzle_id(machine, simulation)
	return CoinPusherLiveSessionScript.enqueue_drops(machine, {
		"nozzle_id": nozzle_id,
		"density": 1,
		"provenance": {"feature_bonus": origin},
		"chain_depth": 0,
		"bonus_origin": true,
	}, count)


func _consume_live_physics_events(run_state: RunState, machine: Dictionary, events_value: Variant) -> Dictionary:
	if typeof(events_value) != TYPE_ARRAY or (events_value as Array).is_empty():
		return {"payout": 0, "prizes": [], "gutter_count": 0, "shim_recovered": false}
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var rng := RngStream.new()
	if typeof(session.get("rng", {})) == TYPE_DICTIONARY:
		rng.restore(session.get("rng", {}))
	else:
		rng.configure(1)
	var result := _consume_physics_events(run_state, machine, events_value as Array, rng)
	session["rng"] = rng.snapshot()
	return result


func _presentation_audio_events(machine: Dictionary, physics_events: Array) -> Array:
	var result: Array = []
	var good_drop_count := 0
	var bad_drop_count := 0
	var cup_count := 0
	var feature_bank_count := 0
	var feature_bank_kinds: Array = []
	var tray_count := 0
	var impact_count := 0
	var strongest_impact := 0
	var strongest_fall_height := 0
	var strongest_stack_depth := 0
	var strongest_impact_material := "coin_on_metal"
	var gutter_count := 0
	for event_value in physics_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var kind := str(event.get("kind", ""))
		match kind:
			"impact":
				if bool(event.get("first_support", false)):
					if str(event.get("landing_quality", "")) == "bed_level_good":
						good_drop_count += 1
					elif str(event.get("landing_quality", "")) == "supported_bad":
						bad_drop_count += 1
					continue
				var fall_height := maxi(0, int(event.get("fall_height", 0)))
				var impact_speed := maxi(0, int(event.get("impact_speed", 0)))
				var stack_depth := maxi(0, int(event.get("stack_depth", 0)))
				var intensity := clampi(160 + fall_height / 24 + impact_speed / 90 + stack_depth * 90, 160, 1000)
				impact_count += 1
				if intensity > strongest_impact:
					strongest_impact = intensity
					strongest_fall_height = fall_height
					strongest_stack_depth = stack_depth
					strongest_impact_material = "coin_on_coin" if str(event.get("support", "")) == "body" else "coin_on_metal"
			"peg_impact":
				var peg_speed := maxi(0, int(event.get("impact_speed", 0)))
				var peg_intensity := clampi(260 + peg_speed / 55, 300, 820)
				impact_count += 1
				if strongest_impact < peg_intensity:
					strongest_impact = peg_intensity
					strongest_fall_height = 0
					strongest_stack_depth = 0
					strongest_impact_material = "coin_on_metal"
			"tray":
				tray_count += 1
				var body_kind := str(event.get("body_kind", "coin"))
				if body_kind in ["rider", "puck", "fragment"]:
					feature_bank_count += 1
					if not feature_bank_kinds.has(body_kind):
						feature_bank_kinds.append(body_kind)
			"gutter":
				gutter_count += 1
			"plinko_cup":
				cup_count += 1
	if good_drop_count > 0:
		result.append({"kind": "good_drop", "intensity_milli": clampi(650 + good_drop_count * 60, 650, 1000), "metadata": {"group_count": good_drop_count}})
	if bad_drop_count > 0:
		result.append({"kind": "bad_drop", "intensity_milli": clampi(390 + bad_drop_count * 35, 390, 720), "metadata": {"group_count": bad_drop_count}})
	if cup_count > 0:
		result.append({"kind": "plinko_cup", "intensity_milli": clampi(760 + cup_count * 50, 760, 1000), "metadata": {"group_count": cup_count}})
	if feature_bank_count > 0:
		result.append({"kind": "feature_bank", "intensity_milli": clampi(840 + feature_bank_count * 55, 840, 1000), "metadata": {"group_count": feature_bank_count, "feature_kinds": feature_bank_kinds}})
	if impact_count > 0:
		result.append({"kind": "impact", "intensity_milli": strongest_impact, "metadata": {"fall_height_milli": strongest_fall_height, "stack_depth": strongest_stack_depth, "material": strongest_impact_material, "group_count": impact_count, "hard_impact": strongest_impact >= 520}})
	if tray_count > 0:
		result.append({"kind": "tray_landing", "intensity_milli": clampi(440 + tray_count * 75, 440, 1000), "metadata": {"group_count": tray_count, "group_index": 0}})
	if gutter_count > 0:
		result.append({"kind": "gutter_loss", "intensity_milli": clampi(520 + (gutter_count - 1) * 45, 520, 880), "metadata": {"group_count": gutter_count}})
	_append_motion_audio_events(machine, result)
	return result


func _append_motion_audio_events(machine: Dictionary, result: Array) -> void:
	# Classify ratchet/slide sound from the same consecutive public views the
	# renderer consumes. Solver contact events remain mechanics evidence; they do
	# not get relabeled as a cabinet sound merely because a body is awake.
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var simulation := _simulation(machine)
	var previous: Array = session.get("presentation_previous_bodies", []) if typeof(session.get("presentation_previous_bodies", [])) == TYPE_ARRAY else []
	var current: Array = session.get("presentation_current_bodies", []) if typeof(session.get("presentation_current_bodies", [])) == TYPE_ARRAY else []
	var previous_packed: PackedInt64Array = session.get("presentation_previous_packed", PackedInt64Array()) if typeof(session.get("presentation_previous_packed", PackedInt64Array())) == TYPE_PACKED_INT64_ARRAY else PackedInt64Array()
	var current_packed: PackedInt64Array = session.get("presentation_current_packed", PackedInt64Array()) if typeof(session.get("presentation_current_packed", PackedInt64Array())) == TYPE_PACKED_INT64_ARRAY else PackedInt64Array()
	var use_packed := not current_packed.is_empty() and current_packed.size() == previous_packed.size() and current_packed.size() % 9 == 0
	if not use_packed and (previous.size() != current.size() or current.is_empty()):
		return
	var previous_face := int(session.get("presentation_previous_face_y", simulation.get("face_y", 0)))
	var current_face := int(session.get("presentation_current_face_y", simulation.get("face_y", 0)))
	var retracting := current_face > previous_face
	var pushing := current_face < previous_face
	var face_delta := current_face - previous_face
	var definition := _machine_definition(str(machine.get("variation_id", _variation_id())))
	var geometry: Dictionary = definition.get("geometry", {}) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}
	var coins: Dictionary = definition.get("coins", {}) if typeof(definition.get("coins", {})) == TYPE_DICTIONARY else {}
	var plate_limit := int(geometry.get("back_plate_y", CoinPusherSolverScript.BACK_PLATE_Y)) - int(coins.get("radius", CoinPusherSolverScript.COIN_RADIUS))
	var simulation_tick := int(simulation.get("tick", 0))
	var plate_block_count := 0
	var moving_under_face := 0
	var last_plate_tick := int(session.get("presentation_last_plate_tick", -6))
	var last_slide_tick := int(session.get("presentation_last_slide_tick", -12))
	var classify_plate := retracting and simulation_tick - last_plate_tick >= 6
	var classify_slide := pushing and int(simulation.get("motor_rate_fp", 0)) > 0 and simulation_tick - last_slide_tick >= 12
	if use_packed:
		for offset in range(0, current_packed.size(), 9):
			if current_packed[offset] != previous_packed[offset]:
				return
			if classify_plate and previous_packed[offset + 8] == 1 and current_packed[offset + 8] == 1 \
					and absi(current_packed[offset + 3] - plate_limit) <= 100 \
					and current_packed[offset + 3] - previous_packed[offset + 3] < maxi(1, face_delta / 4):
				plate_block_count += 1
			if classify_slide and current_packed[offset + 8] == 2 \
					and current_packed[offset + 3] < previous_packed[offset + 3] - 25 \
					and absi(current_packed[offset + 3] - current_face) <= 12000:
				moving_under_face += 1
	else:
		for body_index in range(current.size()):
			var current_body: Dictionary = current[body_index]
			var previous_body: Dictionary = previous[body_index]
			if str(current_body.get("id", "")) != str(previous_body.get("id", "")):
				return
			# A plate clink is the actual blocked carry contact: the retracting
			# platform advances while a platform-supported body remains pinned at the
			# authored rear contact limit. A platform->deck deposit is intentionally
			# not classified as a plate sound.
			if classify_plate and str(previous_body.get("support_kind", "")) == "platform" and str(current_body.get("support_kind", "")) == "platform" \
					and absi(int(current_body.get("y", 0)) - plate_limit) <= 100 \
					and int(current_body.get("y", 0)) - int(previous_body.get("y", 0)) < maxi(1, face_delta / 4):
				plate_block_count += 1
			if classify_slide and str(current_body.get("support_kind", "")) == "deck" \
					and int(current_body.get("y", 0)) < int(previous_body.get("y", 0)) - 25 \
					and abs(int(current_body.get("y", 0)) - current_face) <= 12000:
				moving_under_face += 1
	if plate_block_count > 0:
		result.append({"kind": "plate_clink", "intensity_milli": clampi(420 + (plate_block_count - 1) * 35, 420, 760), "metadata": {"group_count": plate_block_count, "classification": "rear_plate_blocked_carry"}})
		session["presentation_last_plate_tick"] = simulation_tick
	if moving_under_face >= 4:
		result.append({"kind": "mass_slide", "intensity_milli": clampi(260 + moving_under_face * 12, 260, 850), "metadata": {"moving_count": moving_under_face, "classification": "forward_motion_under_face"}})
		session["presentation_last_slide_tick"] = simulation_tick


func _sync_physical_features(machine: Dictionary) -> void:
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	var simulation := _simulation(machine)
	if simulation.is_empty():
		return
	var features: Array = machine.get("riders", []) if variation_id == "quarter_falls" else (_variation_state(machine).get("pucks", []) if variation_id == "jackpot_ridge" else _variation_state(machine).get("fragments", []))
	var kind := "rider" if variation_id == "quarter_falls" else "puck" if variation_id == "jackpot_ridge" else "fragment"
	var desired_feature_ids := {}
	for value in features:
		if typeof(value) == TYPE_DICTIONARY:
			var desired_id := str((value as Dictionary).get("id", ""))
			if not desired_id.is_empty():
				desired_feature_ids[desired_id] = true
	# Bodies are authoritative physical pieces once created. Reconciliation may
	# add a missing ledger-owned body, but it never deletes or repositions one.
	# Terminal tray/gutter transitions are the only removal path.
	var bodies: Array = simulation.get("bodies", []) if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else []
	var existing := {}
	for value in bodies:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var metadata: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		existing[str(metadata.get("feature_id", ""))] = true
	for value in features:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var feature: Dictionary = value
		var feature_id := str(feature.get("id", ""))
		if feature_id.is_empty() or bool(existing.get(feature_id, false)):
			continue
		var machine_definition := _machine_definition(variation_id)
		var geometry: Dictionary = machine_definition.get("geometry", {}) if typeof(machine_definition.get("geometry", {})) == TYPE_DICTIONARY else {}
		var sub_game: Dictionary = machine_definition.get("sub_game", {}) if typeof(machine_definition.get("sub_game", {})) == TYPE_DICTIONARY else {}
		var coin_data: Dictionary = machine_definition.get("coins", {}) if typeof(machine_definition.get("coins", {})) == TYPE_DICTIONARY else {}
		var width := int(geometry.get("width", CoinPusherSolverScript.WIDTH))
		var lip := int(geometry.get("tray_lip_y", CoinPusherSolverScript.TRAY_LIP_Y))
		var face := int(geometry.get("face_extended_y", CoinPusherSolverScript.FACE_EXTENDED_Y))
		var radius := int(sub_game.get("feature_radius", CoinPusherSolverScript.OBJECT_RADIUS))
		var x_milli := clampi(int(feature.get("spawn_x_milli", 100 + int(feature.get("spawn_lane", feature.get("lane", 2))) * 200)), 0, 1000)
		var depth_milli := clampi(int(feature.get("spawn_depth_milli", int(feature.get("spawn_depth_slot", feature.get("cell", 2))) * 1000 / maxi(1, _cell_count() - 1))), 0, 1000)
		var feature_x := clampi(radius + (width - radius * 2) * x_milli / 1000, radius, width - radius)
		var depth_min := lip + radius + 600
		var depth_max := face - radius - 600
		var depth := depth_min + maxi(0, depth_max - depth_min) * depth_milli / 1000
		var metadata := feature.duplicate(true)
		metadata.erase("lane")
		metadata.erase("cell")
		metadata.erase("spawn_lane")
		metadata.erase("spawn_depth_slot")
		metadata["mass"] = int(sub_game.get("feature_mass", int(coin_data.get("mass", 1000)) * (3 if kind == "puck" else 2 if kind == "fragment" else 4)))
		metadata["radius"] = radius
		metadata["height"] = int(sub_game.get("feature_height", CoinPusherSolverScript.OBJECT_HEIGHT))
		var is_ridge_jam := kind == "puck" and str(feature.get("kind", "")) == "dud" and int(feature.get("jam_hole_index", -1)) >= 0
		if is_ridge_jam:
			var apparatus: Dictionary = machine_definition.get("apparatus", {}) if typeof(machine_definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
			var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
			var board: Dictionary = apparatus.get("drop_board", {}) if typeof(apparatus.get("drop_board", {})) == TYPE_DICTIONARY else {}
			var hole_index := clampi(int(feature.get("jam_hole_index", 0)), 0, maxi(0, holes.size() - 1))
			if not holes.is_empty():
				feature_x = int(holes[hole_index])
			depth = int(board.get("y", geometry.get("drop_y", 73000)))
		var placement := _opening_feature_support(simulation, feature_x, depth, radius, int(metadata.get("height", CoinPusherSolverScript.OBJECT_HEIGHT)))
		if not placement.is_empty():
			feature_x = int(placement.get("x", feature_x))
			depth = int(placement.get("y", depth))
			metadata["z"] = int(placement.get("z", geometry.get("deck_z", CoinPusherSolverScript.DECK_Z)))
			metadata["opening_support_id"] = str(placement.get("support_id", ""))
		else:
			metadata["z"] = int(geometry.get("platform_top_z", CoinPusherSolverScript.PLATFORM_TOP_Z)) if is_ridge_jam else int(geometry.get("deck_z", CoinPusherSolverScript.DECK_Z))
		metadata["value"] = maxi(0, int(feature.get("cash_value", 0)))
		var body := CoinPusherSolverScript.add_feature(simulation, kind, feature_id, feature_x, depth, metadata)
		if bool(body.get("accepted", false)):
			body["support_kind"] = "body" if not placement.is_empty() else "platform" if is_ridge_jam else "deck"
			body["support_ids"] = [str(placement.get("support_id", ""))] if not placement.is_empty() else []
			body["carried_sleep"] = bool(placement.get("carried", false)) if not placement.is_empty() else is_ridge_jam
			if not placement.is_empty():
				# Sleeping opening bodies still need the support centroid that the
				# solver normally records on a live contact.  Without it the first
				# support motion cannot advect or wake the feature, pinning it forever.
				body["support_anchor_x"] = int(placement.get("x", feature_x))
				body["support_anchor_y"] = int(placement.get("y", depth))
			body["rest_state"] = "resting"
			body["sleeping"] = true
			body["sleep_ticks"] = 8
		feature["body_id"] = str(body.get("id", ""))
		feature.erase("lane")
		feature.erase("cell")
		feature.erase("spawn_lane")
		feature.erase("spawn_depth_slot")


func _opening_feature_support(simulation: Dictionary, requested_x: int, requested_y: int, feature_radius: int, feature_height: int) -> Dictionary:
	var bodies: Array = simulation.get("bodies", []) if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else []
	var candidates: Array = []
	for body_value in bodies:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var support: Dictionary = body_value
		var metadata: Dictionary = support.get("meta", {}) if typeof(support.get("meta", {})) == TYPE_DICTIONARY else {}
		# Headline pieces belong to the lower pressure bed.  An upper coin can be
		# body-supported while still rooted on the moving platform; attaching a
		# prize to one of those coins makes it shuttle forever instead of advancing
		# toward the tray with the played-in pile.
		if str(support.get("kind", "")) != "coin" \
				or not bool(metadata.get("opening", false)) \
				or str(support.get("support_kind", "")) != "body" \
				or bool(support.get("carried_sleep", false)):
			continue
		var candidate := {
			"x": int(support.get("x", 0)),
			"y": int(support.get("y", 0)),
			# Compact snapshots quantize z to 100 units. Leave one quantization
			# step above the support so restore cannot turn exact contact into a
			# small initial penetration against neighbouring upper coins.
			"z": int(support.get("z", 0)) + int(support.get("height", 950)) + 100,
			"support_id": str(support.get("id", "")),
			"carried": bool(support.get("carried_sleep", false)),
		}
		var dx := int(candidate.get("x", 0)) - requested_x
		var dy := int(candidate.get("y", 0)) - requested_y
		candidate["distance_sq"] = dx * dx + dy * dy
		candidates.append(candidate)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := int(left.get("distance_sq", 0))
		var right_distance := int(right.get("distance_sq", 0))
		return left_distance < right_distance or (left_distance == right_distance and str(left.get("support_id", "")) < str(right.get("support_id", "")))
	)
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		var clear := true
		for body_value in bodies:
			if typeof(body_value) != TYPE_DICTIONARY:
				continue
			var body: Dictionary = body_value
			if str(body.get("id", "")) == str(candidate.get("support_id", "")):
				continue
			var candidate_z := int(candidate.get("z", 0))
			var body_z := int(body.get("z", 0))
			if candidate_z >= body_z + int(body.get("height", 950)) or body_z >= candidate_z + feature_height:
				continue
			var dx := int(candidate.get("x", 0)) - int(body.get("x", 0))
			var dy := int(candidate.get("y", 0)) - int(body.get("y", 0))
			var minimum := feature_radius + int(body.get("radius", 2350)) + 300
			if dx * dx + dy * dy < minimum * minimum:
				clear = false
				break
		if clear:
			candidate.erase("distance_sq")
			return candidate
	return {}


func _feature_views(machine: Dictionary, kind: String) -> Array:
	var result: Array = []
	for body_value in CoinPusherSolverScript.body_views(_simulation(machine)):
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("kind", "")) != kind:
			continue
		var body: Dictionary = body_value
		var metadata: Dictionary = body.get("metadata", {}) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {}
		var view := body.duplicate(true)
		for key in metadata.keys():
			view[key] = metadata[key]
		result.append(view)
	return result


func _security_tolerance_delta(environment: Dictionary, run_state: RunState = null) -> int:
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var band := str(security.get("machine_alarm_tolerance_band", security.get("strictness", "normal"))).to_lower()
	var channels: Dictionary = security.get("security_override_channels", {}) if typeof(security.get("security_override_channels", {})) == TYPE_DICTIONARY else {}
	var sweep: Dictionary = channels.get("police_sweep", {}) if typeof(channels.get("police_sweep", {})) == TYPE_DICTIONARY else {}
	var direct_delta := 0
	if sweep.is_empty():
		direct_delta = _security_band_delta(band) + int(security.get("pusher_alarm_tolerance_band_delta", 0))
	else:
		var base_band := str(sweep.get("base_machine_alarm_tolerance_band", "normal")).to_lower()
		direct_delta = _security_band_delta(base_band) + int(sweep.get("pusher_alarm_tolerance_band_delta", security.get("pusher_alarm_tolerance_band_delta", 0)))
	var adjacent_delta := _adjacent_scenario_tolerance_delta(run_state)
	return direct_delta if adjacent_delta == 0 else mini(direct_delta, adjacent_delta)


func _adjacent_scenario_tolerance_delta(run_state: RunState) -> int:
	if run_state == null or library == null or run_state.world_map.is_empty():
		return 0
	var current_node := run_state.current_world_node_id()
	if current_node.is_empty():
		return 0
	var strictest_delta := 0
	var edges: Array = run_state.world_map.get("edges", []) if typeof(run_state.world_map.get("edges", [])) == TYPE_ARRAY else []
	for edge_value in edges:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		var neighbor := b if a == current_node else a if b == current_node else ""
		if neighbor.is_empty():
			continue
		var public_scenario := run_state.scenario_for_node(neighbor)
		var scenario_definition := library.scenario(str(public_scenario.get("id", "")))
		var mutations: Dictionary = scenario_definition.get("mutations", {}) if typeof(scenario_definition.get("mutations", {})) == TYPE_DICTIONARY else {}
		var hooks: Dictionary = mutations.get("hook_flags", {}) if typeof(mutations.get("hook_flags", {})) == TYPE_DICTIONARY else {}
		var nearby_band := str(hooks.get("nearby_alarm_tolerance_band", "")).to_lower()
		if not nearby_band.is_empty():
			strictest_delta = mini(strictest_delta, _security_band_delta(nearby_band))
	return strictest_delta


func _tell_rung(machine: Dictionary) -> int:
	var tolerance := int(machine.get("alarm_tolerance_remaining", 0))
	var base := maxi(1, int(machine.get("base_alarm_tolerance", 1)) + int(machine.get("tolerance_modifier", 0)))
	if tolerance <= 0:
		return 3
	if tolerance <= maxi(1, base / 3):
		return 2
	if tolerance <= maxi(2, (base * 2) / 3):
		return 1
	return 0


func _tell_label(rung: int) -> String:
	var labels := _tell_labels()
	return str(labels[clampi(rung, 0, labels.size() - 1)])


func _shim_available(run_state: RunState, machine: Dictionary) -> bool:
	return run_state != null and run_state.inventory.has(SHIM_ITEM_ID) and int(machine.get("shim_uses_remaining", 0)) > 0


func _scenario_reset_token(environment: Dictionary) -> String:
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = modifiers.get("coin_pusher", {}) if typeof(modifiers.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	if not bool(pusher.get("reset_pile", false)):
		return ""
	return str(pusher.get("reset_token", environment.get("scenario_id", "scenario_reset")))


func _night_id(run_state: RunState) -> String:
	if run_state == null:
		return "night"
	return "%s:%d" % [str(run_state.seed_text), int(run_state.game_day())]


func _variation_state(machine: Dictionary) -> Dictionary:
	var value: Variant = machine.get("variation_state", {})
	if typeof(value) != TYPE_DICTIONARY:
		machine["variation_state"] = {}
	return machine.get("variation_state", {}) as Dictionary


func _prepare_variation_action(machine: Dictionary) -> void:
	var variation_state := _variation_state(machine)
	var variation_id := str(machine.get("variation_id", "quarter_falls"))
	match variation_id:
		"jackpot_ridge": JackpotRidgeScript.prepare_action(variation_state, int(machine.get("action_count", 0)), _variation_config(variation_id))
		"vault_drop": VaultDropScript.prepare_action(variation_state, int(machine.get("action_count", 0)), _variation_config(variation_id))


func _register_vault_progressive(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null or str(machine.get("variation_id", "")) != "vault_drop":
		return
	var state := _variation_state(machine)
	var config := _variation_config("vault_drop")
	var density := str((environment.get("scenario_presentation", {}) as Dictionary).get("crowd_density", "")) if typeof(environment.get("scenario_presentation", {})) == TYPE_DICTIONARY else ""
	var crowded := density in ["dense", "packed", "high"]
	var growth := int(config.get("progressive_crowded_growth_per_action", 4)) if crowded else int(config.get("progressive_growth_per_action", 2))
	var meter := run_state.register_progressive_meter(str(state.get("meter_id", "")), {
		"target_node_id": _environment_node_id(run_state, environment),
		"target_name": str(environment.get("name", environment.get("display_name", _environment_node_id(run_state, environment)))),
		"initial_value": int(state.get("meter_value", config.get("progressive_floor", 120))),
		"floor": int(config.get("progressive_floor", 120)),
		"growth_per_action": growth,
		"crowded": crowded,
	})
	if not meter.is_empty():
		state["meter_value"] = int(meter.get("value", state.get("meter_value", 0)))


func _sync_vault_meter(run_state: RunState, machine: Dictionary) -> void:
	if run_state == null or str(machine.get("variation_id", "")) != "vault_drop":
		return
	var state := _variation_state(machine)
	var meter := run_state.progressive_meter(str(state.get("meter_id", "")))
	if not meter.is_empty():
		state["meter_value"] = int(meter.get("value", state.get("meter_value", 0)))


func _resolve_vault_action(action_id: String, run_state: RunState, environment: Dictionary, machine: Dictionary, ui_state: Dictionary) -> Dictionary:
	if str(machine.get("variation_id", "")) != "vault_drop":
		return _empty_pusher_result(action_id, environment, "This cabinet has no vault door.")
	var state := _variation_state(machine)
	var cell_index := clampi(int(ui_state.get("coin_pusher_vault_cell", machine.get("vault_selected_cell", 0))), 0, maxi(0, (state.get("vault_cells", []) as Array).size() - 1))
	var outcome: Dictionary
	match action_id:
		VAULT_START_ACTION:
			outcome = VaultDropScript.start_round(state)
		VAULT_STOP_ACTION:
			outcome = VaultDropScript.stop_round(state)
		VAULT_PEEK_ACTION:
			if run_state == null or not run_state.inventory.has("xray_glasses"):
				return _empty_pusher_result(action_id, environment, "You need X-Ray Glasses for that cell.")
			outcome = VaultDropScript.peek_cell(state, cell_index)
		VAULT_OPEN_ACTION:
			outcome = VaultDropScript.open_cell(state, cell_index)
	if outcome.is_empty() or not bool(outcome.get("ok", false)):
		return _empty_pusher_result(action_id, environment, str(outcome.get("message", "The vault does not move.")))
	var config := _variation_config("vault_drop")
	if bool(outcome.get("reset", false)) or bool(outcome.get("jackpot", false)):
		var reset_meter := run_state.set_progressive_meter_value(str(state.get("meter_id", "")), int(config.get("progressive_floor", 120))) if run_state != null else {}
		state["meter_value"] = int(reset_meter.get("value", config.get("progressive_floor", 120)))
	var cash := maxi(0, int(outcome.get("cash", 0)))
	var items: Array = outcome.get("items", []) if typeof(outcome.get("items", [])) == TYPE_ARRAY else []
	var message := str(outcome.get("message", state.get("last_feature_message", "Vault moved.")))
	machine["last_message"] = message
	machine["action_count"] = int(machine.get("action_count", 0)) + 1
	if cash > 0:
		var simulation := _simulation(machine)
		var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
		tray.append({
			"body_id": "vault_reward_%d" % int(machine.get("action_count", 0)),
			"kind": "vault_reward",
			"value": cash,
			"item_id": "",
			"provenance": {"variation_id": "vault_drop", "cell_index": cell_index},
		})
		# The vault door dispenses an external award into the tray. Track its
		# origin honestly; it was never an opening or paid-insert body.
		simulation["external_origin_count"] = int(simulation.get("external_origin_count", 0)) + 1
	_write_live_durable(run_state, environment, machine, false)
	_register_pile_rumor(run_state, environment, machine)
	var deltas := GameModule.empty_result_deltas()
	deltas["inventory_add"] = items
	deltas["story_log"] = [_story_entry(action_id, "risky" if action_id == VAULT_PEEK_ACTION else "legal", environment, cash, 0, {
		"variation_id": "vault_drop", "cell_index": cell_index, "cell_kind": str(outcome.get("kind", "")),
		"fragments_remaining": int(state.get("banked_fragments", 0)), "meter_value": int(state.get("meter_value", 0)),
	})]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"source_id": get_id(), "game_id": get_id(), "action_id": action_id,
		"action_kind": "risky" if action_id == VAULT_PEEK_ACTION else "legal",
		"environment_id": str(environment.get("id", "")), "bankroll_delta": 0,
		"deltas": deltas, "won": cash > 0 or not items.is_empty(), "message": message,
	})
	result["host_apply_result"] = true
	result["preserve_surface_ui_state"] = true
	result["coin_pusher_variation_id"] = "vault_drop"
	result["coin_pusher_vault_outcome"] = outcome
	result["coin_pusher_vault_meter"] = int(state.get("meter_value", 0))
	result["coin_pusher_vault_fragments"] = int(state.get("banked_fragments", 0))
	return result


func _environment_node_id(run_state: RunState, environment: Dictionary) -> String:
	var node_id := str(environment.get("world_node_id", environment.get("id", ""))).strip_edges()
	if node_id.is_empty() and run_state != null:
		node_id = run_state.current_world_node_id()
	return node_id if not node_id.is_empty() else "pusher_node"


func _machine_busy(environment: Dictionary) -> bool:
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var occupancy := str(modifiers.get("machine_occupancy", "")).to_lower()
	return occupancy in ["high", "occupied", "busy"]


func _variation_display_name(variation_id: String) -> String:
	return str(_variation_config(variation_id).get("display_name", "Quarter Falls")) if variation_id != "quarter_falls" else "Quarter Falls"


func _variation_intro(variation_id: String) -> String:
	match variation_id:
		"jackpot_ridge": return "Goal: bank three heavy multiplier pucks to start Ridge Run and feed five bonus tokens. The three nozzles trade cup angles against puck pressure."
		"vault_drop": return "Goal: push heavy key fragments into the win tray to unlock vault cells. Every three banked keys feed six bonus tokens; the edge cups feed more."
	return "Goal: push three heavy prize riders into the win tray to start Prize Rush and feed five bonus tokens. Edge cups can extend the run."


func _register_pile_rumor(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var node_id := str(environment.get("world_node_id", ""))
	if node_id.is_empty():
		node_id = str(environment.get("id", ""))
	if node_id.is_empty():
		node_id = run_state.current_world_node_id()
	if node_id.is_empty():
		return
	var simulation := _simulation(machine) if _has_v3_simulation(machine) else CoinPusherLiveSessionScript.restore_snapshot(machine.get("settled_state", {}), _machine_definition(str(machine.get("variation_id", _variation_id()))))
	var hangers := CoinPusherSolverScript.edge_hanger_count(simulation)
	var pile_count := CoinPusherSolverScript.coin_count(simulation)
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	var fact_class := "pusher_tray_loaded" if not tray.is_empty() else RUMOR_CLASS
	var detail := "%d piece%s" % [tray.size(), "" if tray.size() == 1 else "s"] if not tray.is_empty() else "hanging off the lip" if hangers >= 2 else "fat in the middle" if pile_count >= int(float(_coin_cap()) * 0.72) else "still hungry"
	run_state.register_rumor_fact(fact_class, "pusher:%s" % node_id, {
		"target_node_id": node_id,
		"target_name": str(environment.get("name", environment.get("display_name", node_id))),
		"fact_detail": detail,
		"source_id": get_id(),
		"truth_trace": {"game_id": get_id(), "environment_id": str(environment.get("id", "")), "action_count": int(machine.get("action_count", 0)), "tray_count": tray.size()},
	})


func _staff_watch_suspicion_delta(run_state: RunState, machine: Dictionary) -> int:
	if run_state == null or not bool(machine.get("staff_watch_memory", false)):
		return 0
	return maxi(0, int(machine.get("suspicion_floor", 0)) - run_state.suspicion_level())


func _seed_prize_riders(environment: Dictionary, rng: RngStream) -> Array:
	var tuning := _tuning()
	var definitions: Array = tuning.get("prize_riders", []) if typeof(tuning.get("prize_riders", [])) == TYPE_ARRAY else []
	var scenario_items: Array = []
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = modifiers.get("coin_pusher", {}) if typeof(modifiers.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	if typeof(pusher.get("prize_item_ids", [])) == TYPE_ARRAY:
		scenario_items = pusher.get("prize_item_ids", [])
	var riders: Array = []
	var count := rng.randi_range(_prize_count_min(), _prize_count_max())
	for index in range(count):
		var picked: Dictionary = _weighted_prize(definitions, rng)
		if picked.is_empty():
			continue
		var item_id := str(picked.get("item_id", ""))
		if str(picked.get("kind", "")) == "scenario_item" and not scenario_items.is_empty():
			item_id = str(scenario_items[rng.randi_range(0, scenario_items.size() - 1)])
		if str(picked.get("kind", "")) == "scenario_item" and item_id.is_empty():
			continue
		riders.append({
			"id": "rider_%02d" % index,
			"kind": str(picked.get("kind", "chip_stack")),
			"label": str(picked.get("label", "chip stack")),
			"item_id": item_id,
			"cash_value": maxi(0, int(picked.get("cash_value", 0))),
			"spawn_lane": rng.randi_range(0, _lane_count() - 1),
			"spawn_depth_slot": rng.randi_range(1, mini(_prize_initial_cell_max(), _cell_count() - 1)),
		})
	return riders


func _replenish_quarter_riders(machine: Dictionary, rng: RngStream) -> void:
	var riders: Array = machine.get("riders", []) if typeof(machine.get("riders", [])) == TYPE_ARRAY else []
	var desired := maxi(1, _int_tuning("prize_rider_floor", 3))
	var definitions: Array = _tuning().get("prize_riders", []) if typeof(_tuning().get("prize_riders", [])) == TYPE_ARRAY else []
	var serial := maxi(riders.size(), int(machine.get("rider_serial", riders.size())))
	while riders.size() < desired:
		var picked := _weighted_prize(definitions, rng)
		# Scenario-only prizes need an authored item id.  A replenishing cabinet
		# cannot invent one after the scenario boundary, so fall back to a tangible
		# chip stack instead of spawning a blank prize.
		if picked.is_empty() or (str(picked.get("kind", "")) == "scenario_item" and str(picked.get("item_id", "")).is_empty()):
			picked = {"kind": "chip_stack", "label": "chip stack", "cash_value": 4, "item_id": ""}
		riders.append({
			"id": "rider_%04d" % serial,
			"kind": str(picked.get("kind", "chip_stack")),
			"label": str(picked.get("label", "chip stack")),
			"item_id": str(picked.get("item_id", "")),
			"cash_value": maxi(0, int(picked.get("cash_value", 0))),
			"spawn_x_milli": rng.randi_range(90, 910),
			"spawn_depth_milli": rng.randi_range(120, 760),
		})
		serial += 1
	machine["riders"] = riders
	machine["rider_serial"] = serial


func _weighted_prize(definitions: Array, rng: RngStream) -> Dictionary:
	var total := 0
	for value in definitions:
		if typeof(value) == TYPE_DICTIONARY:
			total += maxi(0, int((value as Dictionary).get("weight", 0)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for value in definitions:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		roll -= maxi(0, int((value as Dictionary).get("weight", 0)))
		if roll <= 0:
			return (value as Dictionary).duplicate(true)
	return {}


func _inventory_prizes(prizes: Array) -> Array:
	var result: Array = []
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			var item_id := str((value as Dictionary).get("item_id", ""))
			if not item_id.is_empty() and not result.has(item_id):
				result.append(item_id)
	return result


func _prize_cash(prizes: Array) -> int:
	var result := 0
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			result += maxi(0, int((value as Dictionary).get("cash_value", 0)))
	return result


func _prize_labels(prizes: Array) -> String:
	var labels: Array = []
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			labels.append(str((value as Dictionary).get("label", (value as Dictionary).get("item_id", "prize"))))
	return ", ".join(labels)


func _story_entry(action_id: String, kind: String, environment: Dictionary, bankroll_delta: int, heat: int, context: Dictionary) -> Dictionary:
	return {
		"type": "game_action", "source_id": get_id(), "game_id": get_id(), "action_id": action_id,
		"action_kind": kind, "environment_id": str(environment.get("id", "")), "bankroll_delta": bankroll_delta,
		"suspicion_delta": heat, "context": context,
	}


func _empty_pusher_result(action_id: String, environment: Dictionary, message: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false, "source_id": get_id(), "game_id": get_id(), "action_id": action_id,
		"environment_id": str(environment.get("id", "")), "message": message,
	})


func _digest_state(machine: Dictionary) -> Dictionary:
	var physical_state: Variant = CoinPusherSolverScript.canonical_digest(_simulation(machine)) if _has_v3_simulation(machine) else machine.get("settled_state", {})
	return {
		"schema": str(machine.get("schema", "")), "version": int(machine.get("version", 0)), "variation_id": str(machine.get("variation_id", "")),
		"variation_state": machine.get("variation_state", {}),
		"simulation": physical_state, "riders": machine.get("riders", []),
		"action_count": int(machine.get("action_count", 0)), "tray_value": int(machine.get("tray_value", 0)),
		"total_cost": int(machine.get("total_cost", 0)), "total_payout": int(machine.get("total_payout", 0)),
		"alarm_tolerance_remaining": int(machine.get("alarm_tolerance_remaining", 0)), "tell_rung": int(machine.get("tell_rung", 0)),
		"locked_down": bool(machine.get("locked_down", false)), "staff_watch_memory": bool(machine.get("staff_watch_memory", false)),
		"suspicion_floor": int(machine.get("suspicion_floor", 0)), "shim_uses_remaining": int(machine.get("shim_uses_remaining", 0)),
	}


func _tuning() -> Dictionary:
	var value: Variant = definition.get("coin_pusher_tuning", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _machine_definition(variation_id: String = "") -> Dictionary:
	var selected := variation_id.strip_edges()
	var cache_key := selected if not selected.is_empty() else "__base__"
	if _machine_definition_cache.has(cache_key):
		return _machine_definition_cache[cache_key]
	var value: Variant = definition.get("coin_pusher_machine", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var base: Dictionary = (value as Dictionary).duplicate(true)
	var machines: Dictionary = base.get("machines", {}) if typeof(base.get("machines", {})) == TYPE_DICTIONARY else {}
	base.erase("machines")
	if selected.is_empty() or selected == str(base.get("machine_id", "quarter_falls")):
		_machine_definition_cache[cache_key] = base
		return base
	var override: Dictionary = machines.get(selected, {}) if typeof(machines.get(selected, {})) == TYPE_DICTIONARY else {}
	for key in override.keys():
		base[key] = override[key].duplicate(true) if typeof(override[key]) in [TYPE_DICTIONARY, TYPE_ARRAY] else override[key]
	var sub_game := _variation_config(selected).duplicate(true)
	if typeof(override.get("sub_game", {})) == TYPE_DICTIONARY:
		sub_game.merge(override.get("sub_game", {}), true)
	base["sub_game"] = sub_game
	base["cabinet"] = _resolved_cabinet(selected)
	_machine_definition_cache[cache_key] = base
	return base


func _resolved_cabinet(variation_id: String) -> Dictionary:
	var authored: Dictionary = _machine_definition().get("cabinet", {}) if typeof(_machine_definition().get("cabinet", {})) == TYPE_DICTIONARY else {}
	var result := authored.duplicate(true)
	var variations: Dictionary = authored.get("variations", {}) if typeof(authored.get("variations", {})) == TYPE_DICTIONARY else {}
	var variation: Dictionary = variations.get(variation_id, {}) if typeof(variations.get(variation_id, {})) == TYPE_DICTIONARY else {}
	for key in variation.keys():
		result[key] = (variation.get(key) as Dictionary).duplicate(true) if typeof(variation.get(key)) == TYPE_DICTIONARY else variation.get(key)
	result.erase("variations")
	return result


func _variation_config(variation_id: String) -> Dictionary:
	var variations: Dictionary = _tuning().get("variations", {}) if typeof(_tuning().get("variations", {})) == TYPE_DICTIONARY else {}
	var value: Variant = variations.get(variation_id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _seeded_variation_id(environment: Dictionary, rng: RngStream) -> String:
	var authored_default := _variation_id()
	if authored_default != "quarter_falls":
		return authored_default
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = modifiers.get("coin_pusher", {}) if typeof(modifiers.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	var forced := str(pusher.get("variation_id", "")).strip_edges()
	if not forced.is_empty():
		return forced
	var distribution: Array = _tuning().get("variation_distribution", []) if typeof(_tuning().get("variation_distribution", [])) == TYPE_ARRAY else []
	var total := 0
	for value in distribution:
		if typeof(value) == TYPE_DICTIONARY:
			total += maxi(0, int((value as Dictionary).get("weight", 0)))
	if total <= 0:
		return authored_default
	var roll := rng.randi_range(1, total)
	for value in distribution:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		roll -= maxi(0, int((value as Dictionary).get("weight", 0)))
		if roll <= 0:
			return str((value as Dictionary).get("id", authored_default))
	return authored_default


func _int_tuning(key: String, fallback: int) -> int:
	return int(_tuning().get(key, fallback))


func _string_array_tuning(key: String, fallback: Array) -> Array:
	var source: Variant = _tuning().get(key, [])
	var result: Array = []
	if typeof(source) == TYPE_ARRAY:
		for value in source:
			var text := str(value)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result if not result.is_empty() else fallback.duplicate()


func _state_version() -> int:
	return maxi(1, _int_tuning("state_schema_version", 1))


func _variation_id() -> String:
	var authored := str(_tuning().get("variation_id", "quarter_falls"))
	return authored if not authored.is_empty() else "quarter_falls"


func _tell_labels() -> Array:
	return _string_array_tuning("tell_labels", ["steady", "cabinet rocks", "alarm chirps", "attendant looks over"])


func _security_band_delta(band: String) -> int:
	var deltas: Dictionary = _tuning().get("security_band_deltas", {}) if typeof(_tuning().get("security_band_deltas", {})) == TYPE_DICTIONARY else {}
	return int(deltas.get(band, 0))


func _lane_count() -> int:
	return clampi(_int_tuning("lane_count", 5), 3, 7)


func _cell_count() -> int:
	return clampi(_int_tuning("depth_slot_count", 6), 4, 8)


func _coin_cap() -> int:
	return clampi(_int_tuning("coin_cap", 48), 32, 160)


func _opening_coin_count(variation_id: String = "") -> int:
	var counts: Dictionary = _tuning().get("opening_coin_counts", {}) if typeof(_tuning().get("opening_coin_counts", {})) == TYPE_DICTIONARY else {}
	var selected_id := variation_id if not variation_id.is_empty() else _variation_id()
	return clampi(int(counts.get(selected_id, _int_tuning("opening_coin_count", 150))), 24, _coin_cap())


func _drop_cost() -> int:
	return maxi(1, _int_tuning("drop_cost", 1))


func _coin_value() -> int:
	return maxi(1, _int_tuning("coin_value", 1))


func _prize_initial_cell_max() -> int:
	return maxi(1, _int_tuning("prize_initial_cell_max", 3))


func _cold_density() -> int:
	return maxi(2, _int_tuning("cold_quarters_density", 3))


func _shim_uses(run_state: RunState = null) -> int:
	var authored := run_state.item_effect_total("coin_pusher_gutter_recovery_uses", "coin_pusher") if run_state != null else 0
	return maxi(1, authored if authored > 0 else _int_tuning("coin_return_shim_uses", 3))


func _alarm_heat() -> int:
	return maxi(8, _int_tuning("hard_alarm_heat", 22))


func _watch_suspicion_floor() -> int:
	return maxi(1, _int_tuning("staff_watch_suspicion_floor", 12))


func _attendant_glance_heat() -> int:
	return maxi(1, _int_tuning("attendant_glance_heat", 2))


func _tolerance_min() -> int:
	return maxi(2, _int_tuning("alarm_tolerance_min", 6))


func _tolerance_max() -> int:
	return maxi(_tolerance_min(), _int_tuning("alarm_tolerance_max", 9))


func _prize_count_min() -> int:
	return maxi(0, _int_tuning("prize_count_min", 1))


func _prize_count_max() -> int:
	return maxi(_prize_count_min(), _int_tuning("prize_count_max", 3))


func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619)
	return abs(value) if value != 0 else 1
