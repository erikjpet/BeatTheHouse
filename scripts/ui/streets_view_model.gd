class_name StreetsViewModel
extends RefCounted

const GLYPHS := {
	"street": "·",
	"building": "■",
	"crowd": "▓",
	"blackout": "░",
	"stash": "□",
	"alley": "↗",
	"snitch": "◉",
}


static func build(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var board: Dictionary = snapshot.get("board", {}) if typeof(snapshot.get("board", {})) == TYPE_DICTIONARY else {}
	var width := maxi(1, int(board.get("width", 1)))
	var height := maxi(1, int(board.get("height", 1)))
	var player: Dictionary = snapshot.get("player", {}) if typeof(snapshot.get("player", {})) == TYPE_DICTIONARY else {}
	var patrol_positions := {}
	for patrol_value in board.get("patrols", []):
		if typeof(patrol_value) != TYPE_DICTIONARY:
			continue
		var patrol: Dictionary = patrol_value
		var position: Dictionary = patrol.get("position", {}) if typeof(patrol.get("position", {})) == TYPE_DICTIONARY else {}
		patrol_positions[_key(position)] = patrol
	var stop_positions := {}
	for index in range((snapshot.get("stops", []) as Array).size()):
		var stop_value: Variant = (snapshot.get("stops", []) as Array)[index]
		if typeof(stop_value) != TYPE_DICTIONARY:
			continue
		var stop: Dictionary = stop_value
		var position: Dictionary = stop.get("position", {}) if typeof(stop.get("position", {})) == TYPE_DICTIONARY else {}
		stop_positions[_key(position)] = {"index": index, "visited": bool(stop.get("visited", false)), "label": str(stop.get("label", "Stop"))}
	var cells: Array = []
	for cell_value in board.get("cells", []):
		if typeof(cell_value) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = cell_value
		var key := _key(cell)
		var kind := str(cell.get("kind", "building"))
		var glyph := str(GLYPHS.get(kind, "·"))
		var tone := kind
		var tooltip := kind.replace("_", " ").capitalize()
		if stop_positions.has(key):
			var stop: Dictionary = stop_positions[key]
			glyph = "✓" if bool(stop.get("visited", false)) else str(int(stop.get("index", 0)) + 1)
			tone = "stop_done" if bool(stop.get("visited", false)) else "stop"
			tooltip = str(stop.get("label", "Stop"))
		if patrol_positions.has(key):
			glyph = "◆"
			tone = "patrol"
			tooltip = "Blue sightline"
		if int(player.get("x", -1)) == int(cell.get("x", -2)) and int(player.get("y", -1)) == int(cell.get("y", -2)):
			glyph = "@"
			tone = "player"
			tooltip = "You"
		elif int(cell.get("x", -1)) == int((board.get("destination", {}) as Dictionary).get("x", -2)) and int(cell.get("y", -1)) == int((board.get("destination", {}) as Dictionary).get("y", -2)):
			glyph = "▣"
			tone = "destination"
			tooltip = str(board.get("destination_label", "The drop"))
		cells.append({
			"x": int(cell.get("x", 0)),
			"y": int(cell.get("y", 0)),
			"kind": kind,
			"glyph": glyph,
			"tone": tone,
			"tooltip": tooltip,
			"passable": kind != "building",
		})
	var pursuit := int(snapshot.get("pursuit_remaining", -1))
	var conditions: Dictionary = snapshot.get("conditions", {}) if typeof(snapshot.get("conditions", {})) == TYPE_DICTIONARY else {}
	return {
		"route_id": str(snapshot.get("route_id", "streets")),
		"title": _mode_title(str(snapshot.get("mode", "package"))),
		"objective": str(snapshot.get("objective", "Keep moving.")),
		"condition_line": "%s · %s" % [str(conditions.get("weather", "clear")).capitalize(), str(conditions.get("day_type", "midweek")).replace("_", " ").capitalize()],
		"status_line": "Tick %d · Deadline %d%s" % [int(snapshot.get("turn", 0)), int(snapshot.get("deadline_remaining", 0)), " · PURSUIT %d" % pursuit if pursuit >= 0 else ""],
		"width": width,
		"height": height,
		"cells": cells,
		"player": player.duplicate(true),
		"legal_actions": (snapshot.get("legal_actions", []) as Array).duplicate(),
		"assists": (snapshot.get("assists", []) as Array).duplicate(),
		"used_assists": (snapshot.get("used_assists", []) as Array).duplicate(),
		"pursuit_active": pursuit >= 0,
	}


static func move_action(model: Dictionary, x: int, y: int, pace: String) -> Dictionary:
	var player: Dictionary = model.get("player", {}) if typeof(model.get("player", {})) == TYPE_DICTIONARY else {}
	var dx := x - int(player.get("x", 0))
	var dy := y - int(player.get("y", 0))
	if absi(dx) + absi(dy) != 1:
		return {}
	return {"verb": "move", "direction": {"x": dx, "y": dy}, "pace": "run" if pace == "run" else "walk"}


static func _mode_title(mode: String) -> String:
	match mode:
		"multi_stop":
			return "THE ROUNDS"
		"hold":
			return "HOLD THE CORNER"
		"chase":
			return "GETAWAY"
		_:
			return "RUN THE PACKAGE"


static func _key(position: Dictionary) -> String:
	return "%d:%d" % [int(position.get("x", -1)), int(position.get("y", -1))]
