class_name SlotFamilyPinball
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")
const FeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const FAMILY_ID := "pinball"
const FEATURE_CLASS := "bonus"
const FILL_REEL_SYMBOLS := [
	["BUMPER", "CHERRY"],
	["BALL", "BAR"],
	["SPINNER", "7"],
	["CHERRY", "BAR"],
	["BALL", "SPINNER"],
	["BUMPER", "7"],
]


func outcome_table(machine: Dictionary, definition: Dictionary, _free_spin: bool) -> Array:
	var config: Dictionary = _pinball_config(definition)
	var table: Array = _dictionary_array(config.get("outcome_table", []))
	return _adjusted_table(table, str(machine.get("math_variant_id", "standard")))


func force_outcome_symbols(machine: Dictionary, grid: Array, entry: Dictionary, rng: RngStream, definition: Dictionary) -> Array:
	var result: Array = MathScript.clone_grid(grid)
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var classification := str(entry.get("classification", "zero_loss"))
	var placement: Dictionary = {}
	_fill_nonpaying_grid(result, rng)
	match classification:
		"near_miss":
			var line_info := _random_payline(reel_count, row_count, mini(3, reel_count), rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for index in range(cells.size()):
				var cell: Dictionary = cells[index]
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "PINBALL" if index < 2 else _safe_pinball_fill_symbol(int(cell.get("reel", 0)), int(cell.get("row", 0)), "PINBALL"))
			placement = {"kind": "tease", "symbol": "PINBALL", "cells": cells.slice(0, mini(2, cells.size())), "line_index": int(line_info.get("line_index", center_row))}
		"ldw":
			var line_info := _random_payline(reel_count, row_count, mini(3, reel_count), rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for cell in cells:
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "CHERRY")
			_stop_pinball_extension(result, int(line_info.get("line_index", center_row)), cells, "CHERRY")
			placement = {"kind": "line", "symbol": "CHERRY", "cells": cells, "line_index": int(line_info.get("line_index", center_row))}
		"true_win":
			var format_id := str(machine.get("format_id", "classic_3_reel"))
			var win_plan: Dictionary = _pinball_true_win_plan(reel_count, format_id, rng, definition)
			var win_count := clampi(int(win_plan.get("count", 3)), mini(3, reel_count), reel_count)
			var symbol := str(win_plan.get("symbol", "BALL"))
			var wild_cell_index := int(win_plan.get("wild_cell_index", -1))
			var wild_symbol := str(win_plan.get("wild_symbol", "DOUBLE"))
			var line_info := _random_payline(reel_count, row_count, win_count, rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for index in range(cells.size()):
				var cell: Dictionary = cells[index]
				var placed_symbol := wild_symbol if index == wild_cell_index else symbol
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), placed_symbol)
			_stop_pinball_extension(result, int(line_info.get("line_index", center_row)), cells, symbol)
			placement = {"kind": "line", "symbol": symbol, "cells": cells, "line_index": int(line_info.get("line_index", center_row))}
		"bonus":
			var cells: Array = MathScript.random_cells(reel_count, row_count, mini(3, reel_count * row_count), rng)
			for cell in cells:
				MathScript.set_cell(result, int((cell as Dictionary).get("reel", 0)), int((cell as Dictionary).get("row", 0)), "PINBALL")
			placement = {"kind": "feature", "symbol": "PINBALL", "cells": cells, "line_index": -1}
	if not placement.is_empty():
		entry["forced_placement"] = placement
	if classification != "bonus":
		_sanitize_pinball_grid(result, definition, _protected_cell_lookup(_copy_array(placement.get("cells", []))))
	return result


func payout_for(entry: Dictionary, stake: int, stake_cost: int, machine: Dictionary, definition: Dictionary) -> int:
	var classification := str(entry.get("classification", "zero_loss"))
	var math_variant: Dictionary = _variant_by_id(definition.get("slot_math_variants", []), str(machine.get("math_variant_id", "standard")))
	var normal_scale := float(math_variant.get("normal_pay_scale", 1.0))
	match classification:
		"ldw":
			if stake_cost <= 1:
				return 0
			return maxi(1, stake_cost + int(entry.get("payout", -1)))
		"true_win":
			var multiplier := float(entry.get("payout_multiplier", 3.0))
			return mini(stake * 2000, int(ceil(float(stake) * multiplier * normal_scale)))
		"bonus":
			return 0
		_:
			return maxi(0, int(entry.get("payout", 0)))


func grid_payout_for_entry(grid: Array, stake: int, stake_cost: int = -1, machine: Dictionary = {}, definition: Dictionary = {}, entry: Dictionary = {}) -> int:
	var classification := str(entry.get("classification", ""))
	var forced_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	if (classification == "true_win" or classification == "ldw") and str(forced_placement.get("kind", "")) == "line":
		var cells: Array = _copy_array(forced_placement.get("cells", []))
		if cells.size() >= mini(3, maxi(1, grid.size())):
			var safe_stake := maxi(1, stake)
			var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
			var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
			var line_symbols: Array = []
			for cell_value in cells:
				var cell: Dictionary = _copy_dict(cell_value)
				line_symbols.append(_cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0))))
			return _line_payout(line_symbols, safe_stake, safe_stake_cost, symbols)
	return grid_payout(grid, stake, stake_cost, machine, definition)


func grid_payout(grid: Array, stake: int, stake_cost: int = -1, _machine: Dictionary = {}, definition: Dictionary = {}) -> int:
	var safe_stake := maxi(1, stake)
	var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
	var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
	var row_count := _grid_row_count(grid)
	var reel_count := grid.size()
	var best := 0
	for line_index in range(MathScript.payline_count(row_count)):
		var cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		var line_symbols: Array = []
		for cell_value in cells:
			var cell: Dictionary = _copy_dict(cell_value)
			line_symbols.append(_cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0))))
		for start_index in range(line_symbols.size()):
			var segment: Array = line_symbols.slice(start_index, line_symbols.size())
			best = maxi(best, _line_payout(segment, safe_stake, safe_stake_cost, symbols))
	return best


func opens_feature(classification: String) -> bool:
	return classification == FEATURE_CLASS


func open_feature(machine: Dictionary, stake: int, rng: RngStream, definition: Dictionary, item_effects: Dictionary = {}) -> Dictionary:
	var bonus_variant: Dictionary = _variant_by_id(definition.get("slot_bonus_variants", []), str(machine.get("bonus_variant_id", "plain")))
	var math_variant: Dictionary = _variant_by_id(definition.get("slot_math_variants", []), str(machine.get("math_variant_id", "standard")))
	var mode := _feature_mode(machine)
	var step_bonus := maxi(0, int(bonus_variant.get("bonus_step_bonus", 0)))
	var feature_scale := float(bonus_variant.get("feature_scale", 1.0)) * float(math_variant.get("bonus_scale", 1.0))
	var feature := FeatureScript.new()
	return feature.open(machine, mode, stake, rng, {
		"ball_budget": _feature_ball_budget(machine, stake, mode, step_bonus),
		"cap": _session_cap(stake, mode, feature_scale),
		"feature_scale": feature_scale,
		"item_effects": _pinball_item_effects(item_effects),
		"bet_id": str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2")),
	})


func nudge_entry(_machine: Dictionary, definition: Dictionary) -> Dictionary:
	for entry_value in _dictionary_array(_pinball_config(definition).get("outcome_table", [])):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == "bonus":
			return entry.duplicate(true)
	return {"id": "bonus", "classification": "bonus", "weight": 1, "payout_multiplier": 0.0}


func apply_nudge_to_grid(machine: Dictionary, grid: Array) -> Dictionary:
	var result: Array = MathScript.clone_grid(grid)
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var reel_index := mini(2, maxi(0, int(machine.get("reel_count", 3)) - 1))
	MathScript.set_cell(result, reel_index, center_row, "PINBALL")
	return {
		"grid": result,
		"tease_event": {
			"type": "nudge_shift",
			"family": FAMILY_ID,
			"reel_index": reel_index,
			"shift": 1,
			"converted_to": "bonus",
		},
	}


func step_bonus(machine: Dictionary, action_id: String, rng: RngStream, definition: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var feature := FeatureScript.new()
	return feature.step(machine, action_id, rng, definition, ui_state)


func shot_table(definition: Dictionary) -> Array:
	return _dictionary_array(_pinball_config(definition).get("shot_table", []))


func feature_mode_for_machine(machine: Dictionary) -> String:
	return _feature_mode(machine)


func preview_feature_award(machine: Dictionary, stake: int, definition: Dictionary, seed_rng: RngStream, inputs: Array) -> int:
	var feature := FeatureScript.new()
	return feature.preview(machine, stake, definition, seed_rng, inputs)



func _feature_ball_budget(machine: Dictionary, stake: int, mode: String, step_bonus: int) -> int:
	if mode == "em_bumper_drop":
		return mini(8, _starting_balls(machine, stake) + step_bonus)
	if mode == "lane_multiball":
		return mini(7, 4 + mini(2, step_bonus))
	if stake <= 2:
		return mini(5, 2 + mini(1, step_bonus))
	if stake <= 5:
		return mini(6, 3 + mini(1, step_bonus))
	if stake <= 10:
		return mini(7, 4 + mini(1, step_bonus))
	return mini(7, 5 + mini(1, step_bonus))


func _default_launch_power(mode: String, rng: RngStream) -> int:
	if mode == "lane_multiball":
		return rng.randi_range(54, 66)
	if mode == "video_feature":
		return rng.randi_range(62, 76)
	return rng.randi_range(68, 82)


func _layout_id_for_mode(mode: String) -> String:
	if mode == "lane_multiball":
		return "lane_multiball"
	if mode == "video_feature":
		return "video_feature"
	return "em_bumper_drop"


func _session_cap(stake: int, mode: String, feature_scale: float) -> int:
	var multiplier := 18.0
	if mode == "lane_multiball":
		multiplier = 16.0
	elif mode == "video_feature":
		multiplier = 10.0
	return maxi(1, int(round(float(stake) * multiplier * maxf(0.35, feature_scale))))


func _pinball_item_effects(item_effects: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in item_effects.keys():
		var key := str(key_value)
		if key.begins_with("slot_pinball_"):
			result[key] = item_effects[key_value]
	return result



func _feature_mode(machine: Dictionary) -> String:
	match str(machine.get("format_id", "classic_3_reel")):
		"line_5x3":
			return "lane_multiball"
		"video_feature":
			return "video_feature"
		_:
			return "em_bumper_drop"



func _starting_balls(machine: Dictionary, stake: int) -> int:
	if str(machine.get("format_id", "")) != "classic_3_reel":
		return 5
	if stake <= 2:
		return 1
	if stake <= 5:
		return 2
	if stake <= 10:
		return 3
	if stake <= 15:
		return 4
	return 5



func _adjusted_table(table: Array, math_id: String) -> Array:
	var result: Array = []
	for entry_value in table:
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var id := str(entry.get("id", ""))
		var weight := int(entry.get("weight", 0))
		if math_id == "steady":
			if id == "ldw":
				weight = int(round(float(weight) * 1.08))
			elif id == "true_win":
				weight = int(round(float(weight) * 0.96))
			elif id == "bonus":
				weight = int(round(float(weight) * 0.90))
		elif math_id == "volatile":
			if id == "zero_loss":
				weight = int(round(float(weight) * 1.04))
			elif id == "ldw":
				weight = int(round(float(weight) * 0.88))
			elif id == "bonus":
				weight = int(round(float(weight) * 1.20))
		entry["weight"] = maxi(0, weight)
		result.append(entry)
	return _normalize_table_total(result, 1000)


func _normalize_table_total(table: Array, target_total: int) -> Array:
	var total := 0
	for entry_value in table:
		total += maxi(0, int((entry_value as Dictionary).get("weight", 0)))
	var delta := target_total - total
	for i in range(table.size()):
		var entry: Dictionary = table[i]
		if str(entry.get("id", "")) == "zero_loss":
			entry["weight"] = maxi(0, int(entry.get("weight", 0)) + delta)
			table[i] = entry
			break
	return table


func _bonus_step_result(complete: bool, award: int, message: String, active: Dictionary) -> Dictionary:
	return {
		"complete": complete,
		"award": maxi(0, award),
		"message": message,
		"active_bonus": active.duplicate(true),
	}


func _fill_nonpaying_grid(grid: Array, rng: RngStream = null) -> void:
	var seed := _grid_seed(grid)
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			var cell_seed := seed
			if rng != null:
				cell_seed = posmod(cell_seed + rng.randi_range(0, 100000), 100003)
			column[row_index] = _pinball_fill_symbol(reel_index, row_index, cell_seed)
		grid[reel_index] = column


func _pinball_win_symbol_for_count(win_count: int, format_id: String, rng: RngStream) -> String:
	var roll := rng.randi_range(1, 100)
	if win_count >= 5:
		return "BUMPER" if roll >= 40 else "CHERRY"
	if win_count >= 4:
		return "BUMPER" if roll >= 66 else "CHERRY"
	if format_id != "classic_3_reel":
		return "BUMPER" if roll >= 45 else "BALL"
	if roll <= 50:
		return "BALL"
	if roll <= 80:
		return "SPINNER"
	if roll <= 96:
		return "BAR"
	return "7"


func _pinball_true_win_plan(reel_count: int, format_id: String, rng: RngStream, definition: Dictionary) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var config: Dictionary = _pinball_config(definition)
	var symbols: Dictionary = _symbol_lookup(config)
	var profiles_by_format: Dictionary = _copy_dict(config.get("true_win_profiles", {}))
	var raw_profiles: Array = _dictionary_array(profiles_by_format.get(format_id, []))
	if raw_profiles.is_empty() and format_id != "classic_3_reel":
		raw_profiles = _dictionary_array(profiles_by_format.get("line_5x3", []))
	var candidates: Array = []
	var minimum_count := mini(3, safe_reels)
	for profile_value in raw_profiles:
		var profile: Dictionary = profile_value
		var symbol := str(profile.get("symbol", ""))
		var count := int(profile.get("count", 3))
		if count < minimum_count or count > safe_reels:
			continue
		if symbol.is_empty() or not symbols.has(symbol) or _pinball_wild(symbol):
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(symbol, {}))
		if str(symbol_def.get("role", "")) == "bonus_scatter":
			continue
		candidates.append(profile.duplicate(true))
	if candidates.is_empty():
		return _pinball_legacy_true_win_plan(safe_reels, format_id, rng)
	var picked: Dictionary = MathScript.weighted_pick(candidates, rng)
	var picked_count := clampi(int(picked.get("count", 3)), minimum_count, safe_reels)
	var wild_symbol := str(picked.get("wild_symbol", "DOUBLE"))
	if not _pinball_wild(wild_symbol):
		wild_symbol = "DOUBLE"
	var wild_cell_index := -1
	var wild_chance := clampi(int(picked.get("wild_chance", 0)), 0, 100)
	if wild_chance > 0 and rng.randi_range(1, 100) <= wild_chance:
		wild_cell_index = rng.randi_range(0, picked_count - 1)
	return {
		"count": picked_count,
		"symbol": str(picked.get("symbol", "BALL")),
		"wild_cell_index": wild_cell_index,
		"wild_symbol": wild_symbol,
	}


func _pinball_legacy_true_win_plan(reel_count: int, format_id: String, rng: RngStream) -> Dictionary:
	var max_win_count := mini(5, reel_count)
	var win_count := 3
	var roll := rng.randi_range(1, 100)
	if format_id == "video_feature":
		max_win_count = mini(6, reel_count)
		if max_win_count >= 6 and roll >= 100:
			win_count = 6
		elif max_win_count >= 5 and roll >= 98:
			win_count = 5
		elif max_win_count >= 4 and roll >= 93:
			win_count = 4
	elif format_id == "line_5x3":
		if max_win_count >= 5 and roll >= 100:
			win_count = 5
		elif max_win_count >= 4 and roll >= 94:
			win_count = 4
	elif max_win_count >= 4 and roll >= 99:
		win_count = 4
	return {
		"count": win_count,
		"symbol": _pinball_win_symbol_for_count(win_count, format_id, rng),
		"wild_cell_index": -1,
		"wild_symbol": "DOUBLE",
	}


func _sanitize_pinball_grid(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> void:
	_limit_symbol_count(grid, "PINBALL", 2, protected_cells)
	var guard := 0
	while guard < 96:
		var violation: Dictionary = _first_pinball_win_violation(grid, definition, protected_cells)
		if violation.is_empty():
			return
		var break_cell: Dictionary = _first_unprotected_cell(_copy_array(violation.get("cells", [])), protected_cells)
		if break_cell.is_empty():
			return
		MathScript.set_cell(grid, int(break_cell.get("reel", 0)), int(break_cell.get("row", 0)), "BLANK")
		guard += 1


func _first_pinball_win_violation(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
	var row_count := _grid_row_count(grid)
	var reel_count := grid.size()
	for line_index in range(MathScript.payline_count(row_count)):
		var line_cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		for start_index in range(line_cells.size()):
			for candidate_value in symbols.keys():
				var candidate := str(candidate_value)
				var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
				if str(symbol_def.get("role", "")) == "bonus_scatter" or _pinball_wild(candidate):
					continue
				var cells: Array = []
				for cell_index in range(start_index, line_cells.size()):
					var cell: Dictionary = _copy_dict(line_cells[cell_index])
					var symbol := _cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0)))
					if symbol == candidate or _pinball_wild(symbol):
						cells.append(cell)
					else:
						break
				if cells.size() >= 3 and not _all_cells_protected(cells, protected_cells):
					return {"cells": cells, "symbol": candidate, "line_index": line_index}
	return {}


func _limit_symbol_count(grid: Array, symbol_id: String, max_count: int, protected_cells: Dictionary) -> void:
	var seen := 0
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if str(column[row_index]) != symbol_id:
				continue
			seen += 1
			if seen > max_count and not bool(protected_cells.get("%d:%d" % [reel_index, row_index], false)):
				column[row_index] = "BLANK"
		grid[reel_index] = column


func _protected_cell_lookup(cells: Array) -> Dictionary:
	var lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		lookup["%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))]] = true
	return lookup


func _first_unprotected_cell(cells: Array, protected_cells: Dictionary) -> Dictionary:
	var index := cells.size() - 1
	while index >= 0:
		var cell: Dictionary = _copy_dict(cells[index])
		if not bool(protected_cells.get("%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))], false)):
			return cell
		index -= 1
	return {}


func _all_cells_protected(cells: Array, protected_cells: Dictionary) -> bool:
	if cells.is_empty():
		return false
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		if not bool(protected_cells.get("%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))], false)):
			return false
	return true


func _random_payline(reel_count: int, row_count: int, count: int, rng: RngStream) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var target_count := mini(maxi(1, count), safe_reels)
	var start_reel := rng.randi_range(0, maxi(0, safe_reels - target_count))
	var line_index := rng.randi_range(0, MathScript.payline_count(safe_rows) - 1)
	return {
		"line_index": line_index,
		"start_reel": start_reel,
		"cells": MathScript.payline_cells_from(safe_reels, safe_rows, line_index, start_reel, target_count),
	}


func _stop_pinball_extension(grid: Array, line_index: int, cells: Array, symbol: String) -> void:
	if cells.is_empty() or grid.is_empty():
		return
	var row_count := _grid_row_count(grid)
	var min_reel := grid.size()
	var max_reel := -1
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		min_reel = mini(min_reel, reel_index)
		max_reel = maxi(max_reel, reel_index)
	for stop_reel in [min_reel - 1, max_reel + 1]:
		if stop_reel < 0 or stop_reel >= grid.size():
			continue
		var stop_cells: Array = MathScript.payline_cells_from(grid.size(), row_count, line_index, stop_reel, 1)
		if stop_cells.is_empty():
			continue
		var stop_cell: Dictionary = _copy_dict(stop_cells[0])
		var stop_row := int(stop_cell.get("row", 0))
		var column: Array = grid[stop_reel] if typeof(grid[stop_reel]) == TYPE_ARRAY else []
		if stop_row >= 0 and stop_row < column.size():
			var current_symbol := str(column[stop_row])
			if current_symbol == symbol or _pinball_wild(current_symbol):
				column[stop_row] = _safe_pinball_fill_symbol(stop_reel, stop_row, symbol)
		grid[stop_reel] = column


func _safe_pinball_fill_symbol(reel_index: int, row_index: int, avoid_symbol: String) -> String:
	var symbol := _pinball_fill_symbol(reel_index, row_index, reel_index + row_index + 1)
	if symbol == avoid_symbol or _pinball_wild(symbol):
		return "BAR" if avoid_symbol != "BAR" else "BALL"
	return symbol


func _pinball_fill_symbol(reel_index: int, row_index: int, seed: int) -> String:
	var choices: Array = FILL_REEL_SYMBOLS[posmod(reel_index, FILL_REEL_SYMBOLS.size())]
	return str(choices[posmod(seed + reel_index * 3 + row_index, choices.size())])


func _grid_seed(grid: Array) -> int:
	var seed := 0
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			var text := str(column[row_index])
			for char_index in range(text.length()):
				seed = posmod(seed + text.unicode_at(char_index) + reel_index * 17 + row_index * 31, 9973)
	return seed


func _line_payout(line_symbols: Array, stake: int, stake_cost: int, symbols: Dictionary) -> int:
	if line_symbols.is_empty():
		return 0
	var candidates: Array = []
	for symbol_value in line_symbols:
		var symbol := str(symbol_value)
		if _pinball_wild(symbol):
			continue
		if not symbols.has(symbol):
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(symbol, {}))
		if str(symbol_def.get("role", "")) == "bonus_scatter":
			continue
		candidates.append(symbol)
	if candidates.is_empty():
		candidates = ["BALL"]
	var best := 0
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		var consecutive := 0
		var multiplier := 1
		for symbol_value in line_symbols:
			var symbol := str(symbol_value)
			if symbol == candidate or _pinball_wild(symbol):
				consecutive += 1
				multiplier = mini(8, multiplier * _pinball_multiplier(symbol))
			else:
				break
		if consecutive < 3:
			continue
		if candidate == "CHERRY" and consecutive == 3 and stake_cost > 1:
			best = maxi(best, maxi(1, stake_cost - 1))
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
		var pay_key := "pay%d" % mini(consecutive, 6)
		var pay := int(symbol_def.get(pay_key, symbol_def.get("triple", 0)))
		best = maxi(best, stake * pay * multiplier)
	return best


func _pinball_wild(symbol: String) -> bool:
	return symbol == "WILD" or symbol == "DOUBLE" or symbol == "DOUBLE_7"


func _pinball_multiplier(symbol: String) -> int:
	if symbol == "DOUBLE" or symbol == "DOUBLE_7":
		return 2
	return 1


func _symbol_lookup(config: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for symbol_value in _dictionary_array(config.get("symbols", [])):
		var symbol: Dictionary = symbol_value
		result[str(symbol.get("id", ""))] = symbol.duplicate(true)
	return result


func _cell_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return "BLANK"
	return str(column[row_index])


func _grid_row_count(grid: Array) -> int:
	if grid.is_empty() or typeof(grid[0]) != TYPE_ARRAY:
		return 1
	return maxi(1, (grid[0] as Array).size())


func _pinball_config(definition: Dictionary) -> Dictionary:
	return _copy_dict(definition.get("slot_pinball_config", {}))


func _variant_by_id(entries_value: Variant, variant_id: String) -> Dictionary:
	for entry_value in _dictionary_array(entries_value):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == variant_id:
			return entry.duplicate(true)
	return {}


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
