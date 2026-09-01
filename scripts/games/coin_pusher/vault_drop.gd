class_name VaultDropVariation
extends RefCounted


static func initial_state(config: Dictionary, rng: RngStream, lane_count: int, cell_count: int, node_id: String) -> Dictionary:
	var fragments: Array = []
	var fragment_count := maxi(3, int(config.get("opening_fragment_count", 6)))
	for index in range(fragment_count):
		fragments.append({
			"id": "vault_fragment_%02d" % index,
			"spawn_x_milli": rng.randi_range(80, 920),
			"spawn_depth_milli": rng.randi_range(100, 900),
		})
	var schedule: Array = []
	var cursor := 0
	for index in range(maxi(4, int(config.get("schedule_count", 16)))):
		cursor += rng.randi_range(maxi(1, int(config.get("spawn_gap_min", 2))), maxi(2, int(config.get("spawn_gap_max", 5))))
		schedule.append({
			"id": "vault_scheduled_%02d" % index, "spawn_action": cursor,
			"spawn_x_milli": rng.randi_range(80, 920), "spawn_depth_milli": rng.randi_range(100, 900),
		})
	var floor_value := maxi(0, int(config.get("progressive_floor", 120)))
	return {
		"meter_id": "vault_drop:%s" % node_id,
		"meter_value": rng.randi_range(maxi(floor_value, int(config.get("progressive_initial_min", floor_value))), maxi(floor_value, int(config.get("progressive_initial_max", floor_value + 100)))),
		"fragments": fragments,
		"fragment_schedule": schedule,
		"schedule_cursor": 0,
		"replenish_serial": 0,
		"replenish_rng": rng.fork("vault_replenish").snapshot(),
		"banked_fragments": 0,
		"key_streak_progress": 0,
		"vault_round_active": false,
		"vault_cycle_count": 0,
		"vault_cells": _seed_cells(config, rng),
		"peeked_cell": -1,
		"last_feature_message": "Fragments ride the ledge. Bank them for the vault.",
	}


static func prepare_action(state: Dictionary, action_count: int, config: Dictionary = {}) -> void:
	var schedule: Array = state.get("fragment_schedule", []) if typeof(state.get("fragment_schedule", [])) == TYPE_ARRAY else []
	var fragments: Array = state.get("fragments", []) if typeof(state.get("fragments", [])) == TYPE_ARRAY else []
	var cursor := maxi(0, int(state.get("schedule_cursor", 0)))
	while cursor < schedule.size() and int((schedule[cursor] as Dictionary).get("spawn_action", 0)) <= action_count:
		fragments.append((schedule[cursor] as Dictionary).duplicate(true))
		cursor += 1
	state["schedule_cursor"] = cursor
	state["fragments"] = fragments
	_replenish_fragments(state, config)


static func apply_physical_events(state: Dictionary, physics_events: Array) -> Dictionary:
	var fragments: Array = state.get("fragments", []) if typeof(state.get("fragments", [])) == TYPE_ARRAY else []
	var remaining: Array = []
	var banked := 0
	var lost := 0
	var outcomes := {}
	for event_value in physics_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("body_kind", event.get("kind", ""))) != "fragment":
			continue
		var metadata: Dictionary = event.get("metadata", {}) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
		outcomes[str(metadata.get("feature_id", ""))] = str(event.get("outcome", ""))
	for value in fragments:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var fragment: Dictionary = value
		var outcome := str(outcomes.get(str(fragment.get("id", "")), ""))
		if outcome == "tray":
			banked += 1
		elif outcome == "gutter":
			lost += 1
		else:
			remaining.append(fragment)
	state["fragments"] = remaining
	state["banked_fragments"] = int(state.get("banked_fragments", 0)) + banked
	if banked > 0:
		state["last_feature_message"] = "%d key fragment%s physically banked." % [banked, "" if banked == 1 else "s"]
	elif lost > 0:
		state["last_feature_message"] = "%d fragment%s lost to the gutter." % [lost, "" if lost == 1 else "s"]
	return {"fragments_banked": banked, "fragments_lost": lost}


static func start_round(state: Dictionary) -> Dictionary:
	if int(state.get("banked_fragments", 0)) <= 0:
		return {"ok": false, "message": "No key fragments banked."}
	if _unopened_cell_indices(state).is_empty():
		_reset_cells_for_next_cycle(state)
	state["vault_round_active"] = true
	state["last_feature_message"] = "Vault cycle %d open. Spend a fragment or stop with the rest." % (int(state.get("vault_cycle_count", 0)) + 1)
	return {"ok": true, "cycle": int(state.get("vault_cycle_count", 0)), "message": str(state.get("last_feature_message", ""))}


static func stop_round(state: Dictionary) -> Dictionary:
	state["vault_round_active"] = false
	state["last_feature_message"] = "Vault closed. Banked fragments stay with this machine."
	return {"ok": true, "message": str(state.get("last_feature_message", ""))}


static func open_cell(state: Dictionary, cell_index: int) -> Dictionary:
	if not bool(state.get("vault_round_active", false)):
		return {"ok": false, "message": "Open the vault round first."}
	if int(state.get("banked_fragments", 0)) <= 0:
		return {"ok": false, "message": "No key fragments left."}
	var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
	if cell_index < 0 or cell_index >= cells.size() or typeof(cells[cell_index]) != TYPE_DICTIONARY or bool((cells[cell_index] as Dictionary).get("opened", false)):
		return {"ok": false, "message": "That vault cell is unavailable."}
	var cell := (cells[cell_index] as Dictionary).duplicate(false)
	cell["opened"] = true
	cells[cell_index] = cell
	state["vault_cells"] = cells
	state["banked_fragments"] = maxi(0, int(state.get("banked_fragments", 0)) - 1)
	var result := {"ok": true, "cell_index": cell_index, "kind": str(cell.get("kind", "cash")), "cash": 0, "items": [], "fragment_refund": 0, "reset": false, "jackpot": false}
	match str(cell.get("kind", "cash")):
		"cash":
			result["cash"] = maxi(0, int(cell.get("cash", 0)))
		"item":
			result["items"] = [str(cell.get("item_id", "lucky_penny"))]
		"fragment_refund":
			var refund := maxi(1, int(cell.get("fragments", 2)))
			state["banked_fragments"] = int(state.get("banked_fragments", 0)) + refund
			result["fragment_refund"] = refund
		"reset":
			result["reset"] = true
		"jackpot":
			result["jackpot"] = true
			result["cash"] = maxi(0, int(state.get("meter_value", 0)))
	state["peeked_cell"] = -1 if int(state.get("peeked_cell", -1)) == cell_index else int(state.get("peeked_cell", -1))
	state["last_feature_message"] = _cell_message(result)
	if _unopened_cell_indices(state).is_empty() or int(state.get("banked_fragments", 0)) <= 0:
		state["vault_round_active"] = false
	return result


static func peek_cell(state: Dictionary, cell_index: int) -> Dictionary:
	var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
	if cell_index < 0 or cell_index >= cells.size() or typeof(cells[cell_index]) != TYPE_DICTIONARY or bool((cells[cell_index] as Dictionary).get("opened", false)):
		return {"ok": false, "message": "That cell gives the glasses nothing."}
	state["peeked_cell"] = cell_index
	var cell := (cells[cell_index] as Dictionary).duplicate(true)
	state["last_feature_message"] = "X-ray truth: cell %d holds %s." % [cell_index + 1, _cell_label(cell, int(state.get("meter_value", 0)))]
	return {"ok": true, "cell_index": cell_index, "cell": cell, "message": str(state.get("last_feature_message", ""))}


static func views(state: Dictionary) -> Dictionary:
	var fragment_views: Array = []
	for value in state.get("fragments", []):
		if typeof(value) == TYPE_DICTIONARY:
			fragment_views.append((value as Dictionary).duplicate(true))
	var cell_views: Array = []
	var peeked := int(state.get("peeked_cell", -1))
	var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
	for index in range(cells.size()):
		var cell: Dictionary = cells[index] if typeof(cells[index]) == TYPE_DICTIONARY else {}
		var visible := bool(cell.get("opened", false)) or index == peeked
		cell_views.append({
			"index": index, "opened": bool(cell.get("opened", false)), "peeked": index == peeked,
			"kind": str(cell.get("kind", "")) if visible else "hidden",
			"label": _cell_label(cell, int(state.get("meter_value", 0))) if visible else "?",
		})
	return {"fragments": fragment_views, "cells": cell_views}


static func _seed_cells(config: Dictionary, rng: RngStream) -> Array:
	var authored: Array = config.get("vault_cells", []) if typeof(config.get("vault_cells", [])) == TYPE_ARRAY else []
	var cells: Array = []
	for definition_value in authored:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		for _copy_index in range(maxi(1, int(definition.get("count", 1)))):
			var cell := definition.duplicate(true)
			cell.erase("count")
			cell["opened"] = false
			cells.append(cell)
	return rng.pick_many(cells, cells.size())


static func _replenish_fragments(state: Dictionary, config: Dictionary) -> void:
	var fragments: Array = state.get("fragments", []) if typeof(state.get("fragments", [])) == TYPE_ARRAY else []
	var floor_count := maxi(3, int(config.get("fragment_floor", 3)))
	if fragments.size() >= floor_count:
		return
	var serial := maxi(0, int(state.get("replenish_serial", 0)))
	var rng := RngStream.new()
	var snapshot: Dictionary = state.get("replenish_rng", {}) if typeof(state.get("replenish_rng", {})) == TYPE_DICTIONARY else {}
	if snapshot.is_empty():
		rng.configure(RngStream.derive_seed(914327, serial + 1, "vault_replenish"))
	else:
		rng.restore(snapshot)
	while fragments.size() < floor_count:
		fragments.append({
			"id": "vault_restock_%06d" % serial,
			"spawn_x_milli": rng.randi_range(80, 920),
			"spawn_depth_milli": rng.randi_range(200, 700),
		})
		serial += 1
	state["fragments"] = fragments
	state["replenish_serial"] = serial
	state["replenish_rng"] = rng.snapshot()


static func _unopened_cell_indices(state: Dictionary) -> Array:
	var result: Array = []
	var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
	for index in range(cells.size()):
		if typeof(cells[index]) == TYPE_DICTIONARY and not bool((cells[index] as Dictionary).get("opened", false)):
			result.append(index)
	return result


static func _reset_cells_for_next_cycle(state: Dictionary) -> void:
	var cells: Array = state.get("vault_cells", []) if typeof(state.get("vault_cells", [])) == TYPE_ARRAY else []
	for index in range(cells.size()):
		if typeof(cells[index]) != TYPE_DICTIONARY:
			continue
		var cell := (cells[index] as Dictionary).duplicate(false)
		cell["opened"] = false
		cells[index] = cell
	state["vault_cells"] = cells
	state["peeked_cell"] = -1
	state["vault_cycle_count"] = int(state.get("vault_cycle_count", 0)) + 1


static func _cell_message(result: Dictionary) -> String:
	match str(result.get("kind", "")):
		"cash": return "Vault cell pays $%d." % int(result.get("cash", 0))
		"item": return "Vault cell gives up an item."
		"fragment_refund": return "Vault cell refunds %d fragments." % int(result.get("fragment_refund", 0))
		"reset": return "RESET. The progressive slams to its honest floor."
		"jackpot": return "VAULT JACKPOT. $%d comes out." % int(result.get("cash", 0))
	return "Vault cell opens."


static func _cell_label(cell: Dictionary, meter_value: int) -> String:
	match str(cell.get("kind", "")):
		"cash": return "$%d" % int(cell.get("cash", 0))
		"item": return str(cell.get("item_id", "item")).replace("_", " ")
		"fragment_refund": return "+%d fragments" % int(cell.get("fragments", 0))
		"reset": return "RESET"
		"jackpot": return "JACKPOT $%d" % meter_value
	return "empty"
