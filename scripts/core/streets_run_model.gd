class_name StreetsRunModel
extends RefCounted

const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SCHEMA_VERSION := 1
const MODES := ["package", "multi_stop", "hold", "chase"]
const ORDER_MODES := ["ordered", "free"]
const STATUSES := ["active", "resolved"]
const DIRECTIONS := {
	"up": {"x": 0, "y": -1},
	"down": {"x": 0, "y": 1},
	"left": {"x": -1, "y": 0},
	"right": {"x": 1, "y": 0},
}
const BOARD_SIZE_BY_DISTANCE := {
	"same": {"x": 6, "y": 5},
	"near": {"x": 8, "y": 6},
	"local": {"x": 10, "y": 7},
	"far": {"x": 12, "y": 8},
	"remote": {"x": 14, "y": 9},
}


# Builds the immutable board and mutable action state once. All later changes
# happen only at action boundaries, so an open board has no idle work.
static func begin(spec: Dictionary, world_context: Dictionary, run_seed: int) -> Dictionary:
	var mode := str(spec.get("mode", "package")).strip_edges().to_lower()
	if not MODES.has(mode):
		return {}
	var origin_id := str(spec.get("origin_node_id", "street_start")).strip_edges()
	var destination_id := str(spec.get("destination_node_id", "street_drop")).strip_edges()
	if origin_id.is_empty() or destination_id.is_empty():
		return {}
	var attempt := maxi(0, int(spec.get("attempt", 0)))
	var edge_key := _edge_key(origin_id, destination_id)
	var board_seed := _stable_hash("%d:%s:%d:%s" % [run_seed, edge_key, attempt, str(spec.get("route_id", mode))])
	var rng := RngStreamScript.new()
	rng.configure(board_seed)
	var distance := str(spec.get("distance", "near")).strip_edges().to_lower()
	if not BOARD_SIZE_BY_DISTANCE.has(distance):
		distance = "near"
	var size: Dictionary = BOARD_SIZE_BY_DISTANCE[distance]
	var width := int(size.get("x", 8))
	var height := int(size.get("y", 6))
	var route_y := rng.randi_range(1, height - 2)
	var conditions := _normalize_conditions(world_context)
	var board := _generate_board(rng, width, height, route_y, conditions, mode, spec)
	var stops := _generate_stops(rng, _dictionary_array(spec.get("stops", [])), board, route_y)
	var deadline_default := width + height + (stops.size() * 3)
	var deadline := maxi(1, int(spec.get("deadline_actions", deadline_default)))
	var hot_start := mode == "chase"
	var hold_zone := _hold_zone(spec, board)
	var state := {
		"schema_version": SCHEMA_VERSION,
		"mode": mode,
		"status": "active",
		"outcome": "",
		"route_id": str(spec.get("route_id", mode)).strip_edges(),
		"job_id": str(spec.get("job_id", "")).strip_edges(),
		"source_event_id": str(spec.get("source_event_id", "")).strip_edges(),
		"origin_node_id": origin_id,
		"destination_node_id": destination_id,
		"distance": distance,
		"attempt": attempt,
		"board_seed": board_seed,
		"board": board,
		"conditions": conditions,
		"player": hold_zone.duplicate(true) if mode == "hold" else {"x": 0, "y": route_y},
		"turn": 0,
		"deadline_actions": deadline,
		"deadline_remaining": deadline,
		"pursuit_turns": maxi(2, int(spec.get("pursuit_turns", 4))),
		"pursuit_remaining": maxi(2, int(spec.get("pursuit_turns", 4))) if hot_start else -1,
		"spotted": hot_start,
		"times_spotted": 1 if hot_start else 0,
		"ducked": false,
		"cargo_id": str(spec.get("cargo_id", "package" if mode in ["package", "multi_stop"] else "")).strip_edges(),
		"cargo_state": "carried" if mode in ["package", "multi_stop"] else "none",
		"stash_position": {},
		"stops": stops,
		"order_mode": _order_mode(spec),
		"hold_zone": hold_zone,
		"hold_window": _hold_window(spec),
		"signal_called": false,
		"assists": _normalize_assists(spec.get("assists", [])),
		"used_assists": [],
		"snitch_seen": false,
		"hazards_hit": 0,
		"noise": 0,
		"resolution": {},
		"consumer_payload": _dictionary(spec.get("consumer_payload", {})).duplicate(true),
		"travel_continuation": _normalize_travel_continuation(spec.get("travel_continuation", {})),
	}
	return normalize_state(state)


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var mode := str(source.get("mode", "")).strip_edges().to_lower()
	var status := str(source.get("status", "")).strip_edges().to_lower()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION or not MODES.has(mode) or not STATUSES.has(status):
		return {}
	var normalized := source.duplicate(true)
	normalized["turn"] = maxi(0, int(source.get("turn", 0)))
	normalized["deadline_remaining"] = maxi(0, int(source.get("deadline_remaining", 0)))
	normalized["pursuit_remaining"] = int(source.get("pursuit_remaining", -1))
	normalized["player"] = _position(source.get("player", {}))
	normalized["stash_position"] = _position(source.get("stash_position", {}), true)
	normalized["stops"] = _dictionary_array(source.get("stops", []))
	normalized["assists"] = _string_array(source.get("assists", []))
	normalized["used_assists"] = _string_array(source.get("used_assists", []))
	normalized["resolution"] = _dictionary(source.get("resolution", {})).duplicate(true)
	normalized["travel_continuation"] = _normalize_travel_continuation(source.get("travel_continuation", {}))
	return normalized


static func apply_action(source_state: Dictionary, action: Dictionary) -> Dictionary:
	var state := normalize_state(source_state)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return {"ok": false, "message": "That run is already in the rearview.", "state": state}
	var verb := str(action.get("verb", "")).strip_edges().to_lower()
	if not legal_verbs(state).has(verb):
		return {"ok": false, "message": "That move is not on tonight's route.", "state": state}
	var message := ""
	var counted_action := true
	match verb:
		"move":
			message = _apply_move(state, action)
			if message.begins_with("BLOCKED:"):
				return {"ok": false, "message": message.trim_prefix("BLOCKED:"), "state": state}
		"wait":
			state["ducked"] = false
			message = "You let the block breathe."
		"duck":
			if not _cell_has_cover(state, _dictionary(state.get("player", {}))):
				return {"ok": false, "message": "Nothing here will hide your outline.", "state": state}
			state["ducked"] = true
			message = "You fold into the scenery."
		"stash":
			message = _apply_stash(state)
			if message.begins_with("BLOCKED:"):
				return {"ok": false, "message": message.trim_prefix("BLOCKED:"), "state": state}
		"ditch":
			state["cargo_state"] = "ditched"
			_resolve(state, "failed", "ditched", "The package takes the fall. You walk clean.")
			message = str(_dictionary(state.get("resolution", {})).get("message", ""))
		"signal":
			message = _apply_signal(state)
		"assist":
			message = _apply_assist(state, str(action.get("assist_id", "")))
			if message.begins_with("BLOCKED:"):
				return {"ok": false, "message": message.trim_prefix("BLOCKED:"), "state": state}
		_:
			counted_action = false
	if counted_action and str(state.get("status", "")) == "active":
		_advance_boundary(state, verb)
	if str(state.get("status", "")) == "active":
		_check_mode_progress(state)
	if str(state.get("status", "")) == "resolved":
		message = str(_dictionary(state.get("resolution", {})).get("message", message))
	return {
		"ok": true,
		"message": message,
		"state": state,
		"resolved": str(state.get("status", "")) == "resolved",
		"resolution": _dictionary(state.get("resolution", {})).duplicate(true),
	}


static func snapshot(source_state: Dictionary) -> Dictionary:
	var state := normalize_state(source_state)
	if state.is_empty():
		return {}
	var result := state.duplicate(true)
	result["board"] = _public_board(state)
	var conditions := _dictionary(state.get("conditions", {}))
	result["conditions"] = {
		"weather": str(conditions.get("weather", "clear")),
		"day_type": str(conditions.get("day_type", "midweek")),
		"happenings": _string_array(conditions.get("happenings", [])),
	}
	result.erase("consumer_payload")
	var continuation := _dictionary(state.get("travel_continuation", {}))
	result["travel_continuation_pending"] = str(state.get("status", "")) == "resolved" \
		and bool(continuation.get("enabled", false)) \
		and not bool(continuation.get("consumed", false))
	result.erase("travel_continuation")
	result.erase("job_id")
	result.erase("source_event_id")
	result.erase("world_applied")
	result["legal_actions"] = legal_verbs(state)
	result["objective"] = _objective_text(state)
	result["board_signature"] = board_signature(state)
	return result


static func legal_verbs(state: Dictionary) -> Array:
	if str(state.get("status", "")) != "active":
		return []
	var verbs: Array = ["move", "wait"]
	if _cell_has_cover(state, _dictionary(state.get("player", {}))):
		verbs.append("duck")
	if str(state.get("cargo_state", "")) in ["carried", "stashed"] and _cell_kind(state, _dictionary(state.get("player", {}))) == "stash":
		verbs.append("stash")
	if str(state.get("cargo_state", "")) in ["carried", "stashed"]:
		verbs.append("ditch")
	if str(state.get("mode", "")) == "hold":
		verbs.append("signal")
	if str(state.get("mode", "")) == "chase" and _unused_assists(state).size() > 0:
		verbs.append("assist")
	return verbs


static func board_signature(state: Dictionary) -> String:
	var board := _dictionary(state.get("board", {}))
	return str(_stable_hash(JSON.stringify({
		"seed": state.get("board_seed", 0),
		"cells": board.get("cells", []),
		"patrols": board.get("patrols", []),
		"stops": state.get("stops", []),
	})))


static func _public_board(state: Dictionary) -> Dictionary:
	var board := _dictionary(state.get("board", {}))
	var public_board := board.duplicate(true)
	var visible_patrols: Array = []
	for patrol in _dictionary_array(board.get("patrols", [])):
		var route: Array = patrol.get("route", []) if typeof(patrol.get("route", [])) == TYPE_ARRAY else []
		if route.is_empty():
			continue
		var phase := posmod(int(patrol.get("phase", 0)), route.size())
		var next_phase := posmod(phase + int(patrol.get("step", 1)), route.size())
		var position := _dictionary(route[phase])
		var next_position := _dictionary(route[next_phase])
		visible_patrols.append({
			"id": str(patrol.get("id", "blue")),
			"position": position.duplicate(true),
			"facing": {
				"x": int(next_position.get("x", 0)) - int(position.get("x", 0)),
				"y": int(next_position.get("y", 0)) - int(position.get("y", 0)),
			},
			"sight": int(patrol.get("sight", 3)),
		})
	public_board["patrols"] = visible_patrols
	return public_board


static func _generate_board(rng: RngStream, width: int, height: int, route_y: int, conditions: Dictionary, mode: String, spec: Dictionary) -> Dictionary:
	var cells: Array = []
	var spine_x := rng.randi_range(2, width - 3)
	for y in range(height):
		for x in range(width):
			var on_spine := y == route_y or x == spine_x or x == 0 or x == width - 1
			var blocked := not on_spine and rng.randi_range(0, 9999) < 1600
			cells.append({"x": x, "y": y, "kind": "building" if blocked else "street", "cover": false, "hazard": false})
	var crowd_count := int(conditions.get("crowd_density", 0))
	for _index in range(crowd_count):
		_paint_random_cell(rng, cells, width, height, ["street"], "crowd", true, route_y)
	var blackout_count := int(conditions.get("blackout_blocks", 0))
	for _index in range(blackout_count):
		_paint_random_cell(rng, cells, width, height, ["street"], "blackout", true, route_y)
	var stash_count := 2 if mode in ["package", "multi_stop", "chase"] else 1
	for _index in range(stash_count):
		_paint_random_cell(rng, cells, width, height, ["street", "blackout"], "stash", true, route_y)
	_paint_random_cell(rng, cells, width, height, ["street"], "alley", false, route_y)
	_paint_random_cell(rng, cells, width, height, ["street"], "snitch", false, route_y)
	var patrol_count := clampi(1 + int(conditions.get("patrol_density", 0)), 1, 8)
	var patrols: Array = []
	for index in range(patrol_count):
		var horizontal := index % 2 == 0
		var lane := route_y if horizontal else spine_x
		var route: Array = []
		if horizontal:
			for x in range(width):
				route.append({"x": x, "y": lane})
			for x in range(width - 2, 0, -1):
				route.append({"x": x, "y": lane})
		else:
			for y in range(height):
				route.append({"x": lane, "y": y})
			for y in range(height - 2, 0, -1):
				route.append({"x": lane, "y": y})
		patrols.append({
			"id": "blue_%02d" % index,
			"route": route,
			"phase": rng.randi_range(0, maxi(0, route.size() - 1)),
			"step": 1 if rng.randi_range(0, 1) == 0 else -1,
			"sight": maxi(1, 4 - int(conditions.get("sight_reduction", 0))),
		})
	return {
		"width": width,
		"height": height,
		"route_y": route_y,
		"cells": cells,
		"patrols": patrols,
		"origin": {"x": 0, "y": route_y},
		"destination": {"x": width - 1, "y": route_y},
		"destination_label": str(spec.get("destination_label", "the drop")),
	}


static func _generate_stops(rng: RngStream, requested: Array, board: Dictionary, route_y: int) -> Array:
	var result: Array = []
	var width := int(board.get("width", 8))
	var height := int(board.get("height", 6))
	for index in range(requested.size()):
		var source: Dictionary = requested[index]
		var position := _position(source.get("position", {}), true)
		if position.is_empty() or not _is_passable(board, position):
			position = {"x": clampi(1 + ((index + 1) * (width - 2) / (requested.size() + 1)), 1, width - 2), "y": route_y}
			if not _is_passable(board, position):
				position = {"x": rng.randi_range(1, width - 2), "y": rng.randi_range(0, height - 1)}
		result.append({
			"id": str(source.get("id", "stop_%02d" % index)).strip_edges(),
			"node_id": str(source.get("node_id", "")).strip_edges(),
			"label": str(source.get("label", "Stop %d" % (index + 1))),
			"position": position,
			"visited": false,
			"visited_turn": -1,
		})
	return result


static func _paint_random_cell(rng: RngStream, cells: Array, width: int, height: int, allowed: Array, kind: String, cover: bool, route_y: int) -> void:
	for _try in range(48):
		var x := rng.randi_range(1, width - 2)
		var y := rng.randi_range(0, height - 1)
		if x == 1 and y == route_y:
			continue
		var cell: Dictionary = cells[(y * width) + x]
		if not allowed.has(str(cell.get("kind", ""))):
			continue
		cell["kind"] = kind
		cell["cover"] = cover
		cell["hazard"] = kind == "blackout" and rng.randi_range(0, 9999) < 4500
		cells[(y * width) + x] = cell
		return


static func _apply_move(state: Dictionary, action: Dictionary) -> String:
	var direction := _action_direction(action)
	if direction.is_empty():
		return "BLOCKED:Pick a corner, then move."
	var pace := str(action.get("pace", "walk")).strip_edges().to_lower()
	if not ["walk", "run"].has(pace):
		pace = "walk"
	var steps := 1
	if pace == "run":
		steps = 1 if str(_dictionary(state.get("conditions", {})).get("weather", "clear")) in ["rain", "fog", "storm"] else 2
		state["noise"] = int(state.get("noise", 0)) + 2
	state["ducked"] = false
	var moved := 0
	for _step in range(steps):
		var player := _dictionary(state.get("player", {}))
		var target := {"x": int(player.get("x", 0)) + int(direction.get("x", 0)), "y": int(player.get("y", 0)) + int(direction.get("y", 0))}
		if not _is_passable(_dictionary(state.get("board", {})), target):
			break
		state["player"] = target
		moved += 1
		var kind := _cell_kind(state, target)
		if kind == "crowd":
			state["ducked"] = true
			break
		if kind == "blackout" and _cell(state, target).get("hazard", false):
			state["hazards_hit"] = int(state.get("hazards_hit", 0)) + 1
			state["noise"] = int(state.get("noise", 0)) + 1
		if kind == "snitch":
			state["snitch_seen"] = true
		if kind == "alley" and pace == "run":
			state["noise"] = int(state.get("noise", 0)) + 1
	if moved == 0:
		return "BLOCKED:Brick wall. Pick another corner."
	return "You cut %s through the block." % ("quick" if pace == "run" else "quiet")


static func _apply_stash(state: Dictionary) -> String:
	if _cell_kind(state, _dictionary(state.get("player", {}))) != "stash":
		return "BLOCKED:No box here."
	var cargo_state := str(state.get("cargo_state", "none"))
	if cargo_state == "carried":
		state["cargo_state"] = "stashed"
		state["stash_position"] = _dictionary(state.get("player", {})).duplicate(true)
		state["pursuit_remaining"] = -1
		state["spotted"] = false
		state["ducked"] = true
		return "The box swallows the heat. The route stays alive."
	if cargo_state == "stashed" and _same_position(_dictionary(state.get("player", {})), _dictionary(state.get("stash_position", {}))):
		state["cargo_state"] = "carried"
		state["stash_position"] = {}
		state["ducked"] = false
		return "Package back under your coat."
	return "BLOCKED:Your package is stashed on another block."


static func _apply_signal(state: Dictionary) -> String:
	if str(state.get("mode", "")) != "hold":
		return "BLOCKED:Nobody is listening for that signal."
	if not _in_hold_zone(state):
		_resolve(state, "failed", "signal_outside_zone", "Wrong corner. Wrong signal. The job folds.")
		return "Wrong corner."
	var window := _dictionary(state.get("hold_window", {}))
	var turn := int(state.get("turn", 0))
	if turn < int(window.get("start", 1)) or turn > int(window.get("end", 3)):
		_resolve(state, "failed", "missed_signal_window", "The signal lands dead. The window is gone.")
		return "The window is gone."
	state["signal_called"] = true
	_resolve(state, "success", "signaled", "Right light, right second. They move.")
	return "Signal clean."


static func _apply_assist(state: Dictionary, assist_id: String) -> String:
	if str(state.get("mode", "")) != "chase":
		return "BLOCKED:Crew assists are saved for the hot ride."
	var clean_id := assist_id.strip_edges()
	if clean_id.is_empty():
		var unused := _unused_assists(state)
		if unused.is_empty():
			return "BLOCKED:Everybody already spent their trick."
		clean_id = str(unused[0])
	if not _string_array(state.get("assists", [])).has(clean_id) or _string_array(state.get("used_assists", [])).has(clean_id):
		return "BLOCKED:That favor is not in your pocket."
	var used := _string_array(state.get("used_assists", []))
	used.append(clean_id)
	state["used_assists"] = used
	state["pursuit_remaining"] = int(state.get("pursuit_remaining", 0)) + 2
	return "%s buys you two corners." % clean_id.replace("_", " ").capitalize()


static func _advance_boundary(state: Dictionary, verb: String) -> void:
	state["turn"] = int(state.get("turn", 0)) + 1
	state["deadline_remaining"] = maxi(0, int(state.get("deadline_remaining", 0)) - 1)
	_advance_patrols(state)
	var newly_spotted := _player_is_seen(state, verb == "move" and int(state.get("noise", 0)) > 0)
	if newly_spotted and not bool(state.get("spotted", false)):
		state["spotted"] = true
		state["times_spotted"] = int(state.get("times_spotted", 0)) + 1
		state["pursuit_remaining"] = int(state.get("pursuit_turns", 4))
	elif int(state.get("pursuit_remaining", -1)) >= 0:
		state["pursuit_remaining"] = int(state.get("pursuit_remaining", 0)) - 1
	state["noise"] = maxi(0, int(state.get("noise", 0)) - 1)
	if int(state.get("pursuit_remaining", -1)) == 0:
		if _destination_ready(state):
			_resolve(state, "success", "escaped", "You beat the blue lights by one clean corner.")
			return
		state["cargo_state"] = "confiscated" if str(state.get("cargo_state", "none")) != "none" else "none"
		_resolve(state, "failed", "caught", "The clock hits zero. Blue lights take the block.")
		return
	if int(state.get("deadline_remaining", 0)) == 0:
		_resolve(state, "failed", "deadline", "The route closes before you do.")


static func _advance_patrols(state: Dictionary) -> void:
	var board := _dictionary(state.get("board", {}))
	var patrols := _dictionary_array(board.get("patrols", []))
	for index in range(patrols.size()):
		var patrol: Dictionary = patrols[index]
		var route: Array = patrol.get("route", []) if typeof(patrol.get("route", [])) == TYPE_ARRAY else []
		if route.is_empty():
			continue
		patrol["phase"] = posmod(int(patrol.get("phase", 0)) + int(patrol.get("step", 1)), route.size())
		patrols[index] = patrol
	board["patrols"] = patrols
	state["board"] = board


static func _player_is_seen(state: Dictionary, noisy: bool) -> bool:
	if bool(state.get("ducked", false)):
		return false
	var player := _dictionary(state.get("player", {}))
	var board := _dictionary(state.get("board", {}))
	for patrol in _dictionary_array(board.get("patrols", [])):
		var route: Array = patrol.get("route", []) if typeof(patrol.get("route", [])) == TYPE_ARRAY else []
		if route.is_empty():
			continue
		var patrol_position := _dictionary(route[posmod(int(patrol.get("phase", 0)), route.size())])
		var distance := absi(int(player.get("x", 0)) - int(patrol_position.get("x", 0))) + absi(int(player.get("y", 0)) - int(patrol_position.get("y", 0)))
		var next_phase := posmod(int(patrol.get("phase", 0)) + int(patrol.get("step", 1)), route.size())
		var next_position := _dictionary(route[next_phase])
		var facing := {"x": int(next_position.get("x", 0)) - int(patrol_position.get("x", 0)), "y": int(next_position.get("y", 0)) - int(patrol_position.get("y", 0))}
		var delta := {"x": int(player.get("x", 0)) - int(patrol_position.get("x", 0)), "y": int(player.get("y", 0)) - int(patrol_position.get("y", 0))}
		var aligned := (int(delta.get("x", 0)) == 0 or int(delta.get("y", 0)) == 0) and (int(delta.get("x", 0)) * int(facing.get("x", 0)) + int(delta.get("y", 0)) * int(facing.get("y", 0))) > 0
		var sight := int(patrol.get("sight", 3)) + (1 if noisy else 0)
		if aligned and distance <= sight and not _line_blocked(board, patrol_position, player):
			return true
		if noisy and distance <= 1:
			return true
	return false


static func _line_blocked(board: Dictionary, start: Dictionary, finish: Dictionary) -> bool:
	var dx := signi(int(finish.get("x", 0)) - int(start.get("x", 0)))
	var dy := signi(int(finish.get("y", 0)) - int(start.get("y", 0)))
	var cursor := {"x": int(start.get("x", 0)) + dx, "y": int(start.get("y", 0)) + dy}
	while not _same_position(cursor, finish):
		var kind := str(_cell_from_board(board, cursor).get("kind", "building"))
		if kind in ["building", "crowd"]:
			return true
		cursor = {"x": int(cursor.get("x", 0)) + dx, "y": int(cursor.get("y", 0)) + dy}
	return false


static func _check_mode_progress(state: Dictionary) -> void:
	var mode := str(state.get("mode", ""))
	if mode == "hold":
		if not _in_hold_zone(state) and int(state.get("turn", 0)) >= int(_dictionary(state.get("hold_window", {})).get("start", 1)):
			_resolve(state, "failed", "left_hold", "You leave the mark naked. Somebody clocks it.")
		return
	if mode == "multi_stop":
		_visit_stop(state)
	var destination := _dictionary(_dictionary(state.get("board", {})).get("destination", {}))
	if not _same_position(_dictionary(state.get("player", {})), destination):
		return
	if str(state.get("cargo_state", "none")) == "stashed":
		return
	if mode == "multi_stop" and not _all_stops_visited(state):
		return
	_resolve(state, "success", "delivered" if mode != "chase" else "escaped", "Clean through. The street keeps your name quiet.")


static func _visit_stop(state: Dictionary) -> void:
	var stops := _dictionary_array(state.get("stops", []))
	var player := _dictionary(state.get("player", {}))
	var order_mode := str(state.get("order_mode", "ordered"))
	for index in range(stops.size()):
		var stop: Dictionary = stops[index]
		if bool(stop.get("visited", false)) or not _same_position(player, _dictionary(stop.get("position", {}))):
			continue
		if order_mode == "ordered" and index > 0 and not bool(stops[index - 1].get("visited", false)):
			return
		stop["visited"] = true
		stop["visited_turn"] = int(state.get("turn", 0))
		stops[index] = stop
		break
	state["stops"] = stops


static func _resolve(state: Dictionary, outcome: String, reason: String, message: String) -> void:
	if str(state.get("status", "")) == "resolved":
		return
	state["status"] = "resolved"
	state["outcome"] = outcome
	state["resolution"] = {
		"outcome": outcome,
		"reason": reason,
		"message": message,
		"turns_used": int(state.get("turn", 0)),
		"clean": outcome == "success" and not bool(state.get("spotted", false)) and int(state.get("hazards_hit", 0)) == 0,
		"cargo_state": str(state.get("cargo_state", "none")),
		"snitch_seen": bool(state.get("snitch_seen", false)),
	}


static func _normalize_conditions(source: Dictionary) -> Dictionary:
	var weather := str(source.get("weather", "clear")).strip_edges().to_lower()
	if not ["clear", "rain", "fog", "storm"].has(weather):
		weather = "clear"
	var happenings := _string_array(source.get("happenings", []))
	var heat := clampi(int(source.get("heat", 0)), 0, 100)
	var reputation := clampi(int(round(float(source.get("reputation", 0.0)))), -100, 100)
	var sweep_delta := clampi(int(source.get("sweep_density_delta", 0)), 0, 4)
	var patrol_density := (heat / 30) + (maxi(0, reputation) / 35) + sweep_delta
	var crowd_density := 0
	if happenings.has("fight_night"):
		crowd_density += 3
	if happenings.has("festival_weekend"):
		crowd_density += 4
	if str(source.get("day_type", "midweek")) == "payday":
		patrol_density += 1
		crowd_density += 2
	var blackout_blocks := 3 if happenings.has("rolling_blackout") else 0
	return {
		"weather": weather,
		"day_type": str(source.get("day_type", "midweek")),
		"happenings": happenings,
		"heat": heat,
		"reputation": reputation,
		"sweep_density_delta": sweep_delta,
		"patrol_density": patrol_density,
		"crowd_density": crowd_density,
		"blackout_blocks": blackout_blocks,
		"sight_reduction": 2 if weather == "fog" else 1 if weather in ["rain", "storm"] else 0,
	}


static func _hold_zone(spec: Dictionary, board: Dictionary) -> Dictionary:
	var authored := _position(spec.get("hold_zone", {}), true)
	if not authored.is_empty() and _is_passable(board, authored):
		return authored
	return {"x": maxi(1, int(board.get("width", 8)) / 2), "y": int(board.get("route_y", 2))}


static func _hold_window(spec: Dictionary) -> Dictionary:
	var source := _dictionary(spec.get("signal_window", {}))
	var start := maxi(1, int(source.get("start", 2)))
	return {"start": start, "end": maxi(start, int(source.get("end", start + 2)))}


static func _order_mode(spec: Dictionary) -> String:
	var mode := str(spec.get("order_mode", "ordered")).strip_edges().to_lower()
	return mode if ORDER_MODES.has(mode) else "ordered"


static func _normalize_assists(value: Variant) -> Array:
	var assists := _string_array(value)
	var result: Array = []
	for assist_id in assists:
		if not result.has(assist_id):
			result.append(assist_id)
	return result


static func _unused_assists(state: Dictionary) -> Array:
	var result: Array = []
	var used := _string_array(state.get("used_assists", []))
	for assist_id in _string_array(state.get("assists", [])):
		if not used.has(assist_id):
			result.append(assist_id)
	return result


static func _in_hold_zone(state: Dictionary) -> bool:
	return _same_position(_dictionary(state.get("player", {})), _dictionary(state.get("hold_zone", {})))


static func _all_stops_visited(state: Dictionary) -> bool:
	for stop in _dictionary_array(state.get("stops", [])):
		if not bool(stop.get("visited", false)):
			return false
	return true


static func _destination_ready(state: Dictionary) -> bool:
	var destination := _dictionary(_dictionary(state.get("board", {})).get("destination", {}))
	if not _same_position(_dictionary(state.get("player", {})), destination):
		return false
	if str(state.get("cargo_state", "none")) == "stashed":
		return false
	return str(state.get("mode", "")) != "multi_stop" or _all_stops_visited(state)


static func _objective_text(state: Dictionary) -> String:
	match str(state.get("mode", "")):
		"multi_stop":
			var visited := 0
			var stops := _dictionary_array(state.get("stops", []))
			for stop in stops:
				visited += 1 if bool(stop.get("visited", false)) else 0
			return "Make the rounds: %d/%d stops, %d ticks left." % [visited, stops.size(), int(state.get("deadline_remaining", 0))]
		"hold":
			var window := _dictionary(state.get("hold_window", {}))
			return "Hold the mark. Signal on ticks %d-%d." % [int(window.get("start", 0)), int(window.get("end", 0))]
		"chase":
			return "Rook's car or cuffs. Pursuit: %d." % maxi(0, int(state.get("pursuit_remaining", 0)))
		_:
			return "Get the package across. %d ticks left." % int(state.get("deadline_remaining", 0))


static func _action_direction(action: Dictionary) -> Dictionary:
	var direction_value: Variant = action.get("direction", {})
	if typeof(direction_value) == TYPE_STRING:
		return _dictionary(DIRECTIONS.get(str(direction_value).to_lower(), {})).duplicate(true)
	var direction := _position(direction_value, true)
	if absi(int(direction.get("x", 0))) + absi(int(direction.get("y", 0))) != 1:
		return {}
	return direction


static func _cell_has_cover(state: Dictionary, position: Dictionary) -> bool:
	return bool(_cell(state, position).get("cover", false))


static func _cell_kind(state: Dictionary, position: Dictionary) -> String:
	return str(_cell(state, position).get("kind", "building"))


static func _cell(state: Dictionary, position: Dictionary) -> Dictionary:
	return _cell_from_board(_dictionary(state.get("board", {})), position)


static func _cell_from_board(board: Dictionary, position: Dictionary) -> Dictionary:
	var width := int(board.get("width", 0))
	var height := int(board.get("height", 0))
	var x := int(position.get("x", -1))
	var y := int(position.get("y", -1))
	if x < 0 or y < 0 or x >= width or y >= height:
		return {}
	var cells: Array = board.get("cells", []) if typeof(board.get("cells", [])) == TYPE_ARRAY else []
	var index := (y * width) + x
	return _dictionary(cells[index]) if index < cells.size() else {}


static func _is_passable(board: Dictionary, position: Dictionary) -> bool:
	return str(_cell_from_board(board, position).get("kind", "building")) != "building"


static func _same_position(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and int(a.get("x", -99)) == int(b.get("x", -98)) and int(a.get("y", -99)) == int(b.get("y", -98))


static func _position(value: Variant, allow_empty: bool = false) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {} if allow_empty else {"x": 0, "y": 0}
	var source: Dictionary = value
	if allow_empty and (not source.has("x") or not source.has("y")):
		return {}
	return {"x": int(source.get("x", 0)), "y": int(source.get("y", 0))}


static func _normalize_travel_continuation(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var target_id := str(source.get("target_id", "")).strip_edges()
	if not bool(source.get("enabled", false)) or target_id.is_empty():
		return {}
	return {
		"enabled": true,
		"target_id": target_id,
		"target_label": str(source.get("target_label", target_id.replace("_", " ").capitalize())).strip_edges(),
		"choice_data": _dictionary(source.get("choice_data", {})).duplicate(true),
		"consumed": bool(source.get("consumed", false)),
	}


static func _edge_key(origin_id: String, destination_id: String) -> String:
	var ids := [origin_id, destination_id]
	ids.sort()
	return "%s>%s" % [ids[0], ids[1]]


static func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return maxi(1, hash_value)


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) == TYPE_DICTIONARY:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
