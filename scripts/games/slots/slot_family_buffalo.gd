class_name SlotFamilyBuffalo
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")

const FAMILY_ID := "buffalo"
const CARD_SYMBOLS := ["A", "K", "Q", "J", "10"]
const ANIMAL_SYMBOLS := ["EAGLE", "WOLF", "HORSE", "ELK"]
const LOCK_SYMBOLS := ["BUFFALO", "CASH"]
const WILD_SYMBOLS := ["SUNSET", "SUNSET_2X", "SUNSET_3X"]
const FEATURE_CLASSES := ["free_games", "hold_and_spin", "monster_feature"]
const FREE_GAMES_RETRIGGER_THRESHOLD := 3
const FREE_GAMES_RETRIGGER_GRANT := 8
const FREE_GAMES_MAX_TOTAL_STEPS := 60
const GRAND_PRIZE_STATE_KEY := "buffalo_grand_prize"
const GRAND_PRIZE_INITIAL_MULTIPLIER_KEY := "buffalo_grand_prize_initial_multiplier"
const GRAND_PRIZE_SPINS_KEY := "buffalo_grand_prize_spins"
const GRAND_PRIZE_BASE_MULTIPLIER := 50
const GRAND_PRIZE_INCREMENT_RATE := 0.50
const FILL_REEL_SYMBOLS := [
	["A", "K", "BUFFALO", "WOLF", "BLANK"],
	["Q", "J", "CASH", "ELK", "BLANK"],
	["10", "A", "CASH", "HORSE", "BLANK"],
	["K", "Q", "CASH", "EAGLE", "BLANK"],
	["J", "10", "BUFFALO", "WOLF", "BLANK"],
	["A", "K", "CASH", "ELK", "BLANK"],
]


func outcome_table(machine: Dictionary, definition: Dictionary, _free_spin: bool) -> Array:
	var config: Dictionary = _buffalo_config(definition)
	var tables: Dictionary = _copy_dict(config.get("outcome_tables", {}))
	var format_id := str(machine.get("format_id", "classic_3_reel"))
	var table_id := "video_feature" if format_id == "video_feature" else "base"
	var table: Array = _dictionary_array(tables.get(table_id, []))
	if format_id == "classic_3_reel":
		table = _heritage_table(table)
	return _adjusted_table(table, str(machine.get("math_variant_id", "standard")), table_id)


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
			var cells_near: Array = MathScript.random_line_cells(reel_count, row_count, mini(3, reel_count), rng)
			var tease_coin_count := 1 + posmod(_grid_seed(result), 2)
			tease_coin_count = mini(tease_coin_count, cells_near.size())
			for index in range(cells_near.size()):
				var cell: Dictionary = cells_near[index]
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "GOLD_TOKEN" if index < tease_coin_count else _buffalo_fill_symbol(int(cell.get("reel", 0)), int(cell.get("row", 0)), _grid_seed(result)))
			placement = {"kind": "tease", "symbol": "GOLD_TOKEN", "cells": cells_near.slice(0, tease_coin_count), "skill_line_cells": cells_near, "side_effect_gold_token_count": mini(2, cells_near.size()), "line_index": int((cells_near[0] as Dictionary).get("row", center_row)) if not cells_near.is_empty() else center_row}
		"ldw":
			var ldw_plan: Dictionary = _full_payline_plan(reel_count, row_count, rng)
			var cells_ldw: Array = _copy_array(ldw_plan.get("cells", []))
			for cell in cells_ldw:
				MathScript.set_cell(result, int((cell as Dictionary).get("reel", 0)), int((cell as Dictionary).get("row", 0)), "10")
			_trim_forced_reel_matches(result, cells_ldw, "10")
			placement = {"kind": "line", "symbol": "10", "cells": cells_ldw, "line_index": int(ldw_plan.get("line_index", center_row))}
		"true_win":
			var win_plan := _buffalo_true_win_plan(reel_count, str(machine.get("format_id", "")), rng, definition)
			var line_plan: Dictionary = _full_payline_plan(reel_count, row_count, rng)
			var symbol := str(win_plan.get("symbol", "BUFFALO"))
			var wild_reel := int(win_plan.get("wild_reel", -1))
			var wild_cell_index := int(win_plan.get("wild_cell_index", -1))
			var wild_symbol := str(win_plan.get("wild_symbol", "SUNSET_2X"))
			var cells_win: Array = _copy_array(line_plan.get("cells", []))
			for index in range(cells_win.size()):
				var cell: Dictionary = cells_win[index]
				var reel := int(cell.get("reel", index))
				var placed_symbol := wild_symbol if reel == wild_reel or index == wild_cell_index else symbol
				if bool(win_plan.get("classic_dual_wild", false)) and reel == 2:
					placed_symbol = "SUNSET_3X"
				MathScript.set_cell(result, reel, int(cell.get("row", center_row)), placed_symbol)
			if int(win_plan.get("extra_reel", -1)) >= 0 and row_count > 1 and not cells_win.is_empty():
				var extra_index := clampi(int(win_plan.get("extra_reel", 1)), 0, cells_win.size() - 1)
				var extra_anchor: Dictionary = _copy_dict(cells_win[extra_index])
				var extra_reel := clampi(int(extra_anchor.get("reel", extra_index)), 0, reel_count - 1)
				var occupied_rows := {}
				for cell_value in cells_win:
					var cell: Dictionary = _copy_dict(cell_value)
					if int(cell.get("reel", -1)) == extra_reel:
						occupied_rows[int(cell.get("row", -1))] = true
				var extra_target := mini(maxi(1, int(win_plan.get("extra_count", 1))), maxi(1, row_count - occupied_rows.size()))
				for _extra_index in range(extra_target):
					var extra_row := rng.randi_range(0, row_count - 1)
					var guard := 0
					while bool(occupied_rows.get(extra_row, false)) and guard < row_count + 1:
						extra_row = posmod(extra_row + 1, row_count)
						guard += 1
					if bool(occupied_rows.get(extra_row, false)):
						continue
					occupied_rows[extra_row] = true
					MathScript.set_cell(result, extra_reel, extra_row, symbol)
					cells_win.append({"reel": extra_reel, "row": extra_row})
			_trim_forced_reel_matches(result, cells_win, symbol)
			placement = {"kind": "line", "symbol": symbol, "cells": cells_win, "line_index": int(line_plan.get("line_index", center_row))}
		"free_games":
			var cells_free: Array = MathScript.random_cells(reel_count, row_count, 3, rng)
			for cell in cells_free:
				MathScript.set_cell(result, int((cell as Dictionary).get("reel", 0)), int((cell as Dictionary).get("row", 0)), "GOLD_TOKEN")
			placement = {"kind": "feature", "symbol": "GOLD_TOKEN", "cells": cells_free, "line_index": -1}
		"hold_and_spin":
			var config: Dictionary = _buffalo_config(definition)
			var hold_config: Dictionary = _copy_dict(config.get("hold_and_spin", {}))
			var trigger_count := clampi(int(hold_config.get("lock_trigger_count", 8)), 3, reel_count * row_count)
			var locks: Array = MathScript.random_cells(reel_count, row_count, trigger_count, rng)
			for cell_value in locks:
				var cell: Dictionary = _copy_dict(cell_value)
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "GOLD_TOKEN")
			placement = {"kind": "feature", "symbol": "GOLD_TOKEN", "cells": locks, "line_index": -1}
		"monster_feature":
			var cells_monster: Array = MathScript.random_cells(reel_count, row_count, mini(6, reel_count * row_count), rng)
			for cell in cells_monster:
				MathScript.set_cell(result, int((cell as Dictionary).get("reel", 0)), int((cell as Dictionary).get("row", 0)), "GOLD_TOKEN")
			if reel_count >= 3:
				MathScript.set_cell(result, 2, rng.randi_range(0, row_count - 1), "BUFFALO")
			placement = {"kind": "feature", "symbol": "GOLD_TOKEN", "cells": cells_monster, "line_index": -1}
	if not placement.is_empty():
		entry["forced_placement"] = placement
	if not FEATURE_CLASSES.has(classification):
		_sanitize_buffalo_grid(result, definition, _protected_cell_lookup(_copy_array(placement.get("cells", []))))
	return result


func _ways_cells(reel_count: int, row_count: int, count: int, rng: RngStream) -> Array:
	var cells: Array = []
	var safe_reels := maxi(1, reel_count)
	var target_count := mini(maxi(1, count), safe_reels)
	var start_reel := rng.randi_range(0, maxi(0, safe_reels - target_count))
	for offset in range(target_count):
		var reel_index := start_reel + offset
		cells.append({"reel": reel_index, "row": rng.randi_range(0, maxi(1, row_count) - 1)})
	return cells


func _full_payline_plan(reel_count: int, row_count: int, rng: RngStream) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var line_index := rng.randi_range(0, MathScript.payline_count(safe_rows) - 1)
	return {
		"line_index": line_index,
		"cells": MathScript.payline_cells(safe_reels, safe_rows, line_index),
	}


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
			var multiplier := float(entry.get("payout_multiplier", 2.45))
			if str(machine.get("format_id", "")) == "classic_3_reel":
				multiplier *= 1.85
			return mini(stake * 1200, int(ceil(float(stake) * multiplier * normal_scale)))
		"free_games", "hold_and_spin", "monster_feature":
			return 0
		_:
			return maxi(0, int(entry.get("payout", 0)))


func opens_feature(classification: String) -> bool:
	return FEATURE_CLASSES.has(classification)


func open_feature(machine: Dictionary, entry: Dictionary, stake: int, rng: RngStream, definition: Dictionary) -> Dictionary:
	var classification := str(entry.get("classification", "free_games"))
	var bonus_variant: Dictionary = _variant_by_id(definition.get("slot_bonus_variants", []), str(machine.get("bonus_variant_id", "plain")))
	var math_variant: Dictionary = _variant_by_id(definition.get("slot_math_variants", []), str(machine.get("math_variant_id", "standard")))
	var feature_scale := float(bonus_variant.get("feature_scale", 1.0)) * float(math_variant.get("bonus_scale", 1.0))
	if classification == "monster_feature":
		return _wheel_feature(machine, stake, feature_scale, rng)
	if classification == "hold_and_spin":
		var hold_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
		return _hold_feature(machine, stake, feature_scale, maxi(0, int(bonus_variant.get("bonus_step_bonus", 0))), _copy_array(hold_placement.get("cells", [])))
	var free_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var forced_scatter_count := _copy_array(free_placement.get("cells", [])).size()
	var scatter_count := maxi(3, forced_scatter_count if forced_scatter_count > 0 else MathScript.count_symbol(machine.get("last_grid", []), "GOLD_TOKEN"))
	return _free_games_feature(machine, stake, feature_scale, scatter_count, maxi(0, int(bonus_variant.get("bonus_step_bonus", 0))))


func nudge_entry(machine: Dictionary, definition: Dictionary) -> Dictionary:
	var target_id := "free_games"
	if str(machine.get("format_id", "")) != "classic_3_reel" and MathScript.count_symbols(machine.get("last_grid", []), LOCK_SYMBOLS) >= 7:
		target_id = "hold_and_spin"
	var table: Array = outcome_table(machine, definition, false)
	for entry_value in table:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == target_id:
			return entry.duplicate(true)
	return {"id": "free_games", "classification": "free_games", "weight": 1, "payout_multiplier": 0.0}


func apply_nudge_to_grid(machine: Dictionary, grid: Array) -> Dictionary:
	var result: Array = MathScript.clone_grid(grid)
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var reel_index := mini(2, maxi(0, int(machine.get("reel_count", 3)) - 1))
	MathScript.set_cell(result, reel_index, center_row, "GOLD_TOKEN")
	return {
		"grid": result,
		"tease_event": {
			"type": "nudge_shift",
			"family": FAMILY_ID,
			"reel_index": reel_index,
			"shift": 1,
			"converted_to": "free_games",
		},
	}


func step_bonus(machine: Dictionary, action_id: String, rng: RngStream, _definition: Dictionary, _ui_state: Dictionary = {}) -> Dictionary:
	var active: Dictionary = _copy_dict(machine.get("active_bonus", {}))
	if active.is_empty() or not bool(active.get("active", false)):
		return _bonus_step_result(false, 0, "No buffalo feature is active.", active)
	active["slot_item_effects"] = _copy_dict(_ui_state.get("slot_item_effects", {}))
	var mode := str(active.get("mode", ""))
	if mode == "wheel":
		return _step_wheel(machine, active, action_id, rng)
	if mode == "hold_and_spin":
		return _step_hold(machine, active, rng)
	return _step_free_games(machine, active, rng)


func apply_grid_side_effects(machine: Dictionary, grid: Array, stake: int, entry: Dictionary = {}, definition: Dictionary = {}) -> Dictionary:
	var bet_id := str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2"))
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
	if bucket.is_empty():
		bucket = {"gold_buffalo_heads": 0, "gold_buffalo_max_seen": 0, "must_hit_meter": 100, "must_hit_ready": false, "feature_completion_count": 0}
	var placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var placement_cells: Array = _copy_array(placement.get("cells", []))
	var placement_lookup: Dictionary = _cell_lookup(placement_cells)
	var side_counts: Dictionary = _grid_side_effect_counts(grid, entry)
	var animal_count := int(side_counts.get("animal_count", 0))
	var buffalo_count := int(side_counts.get("buffalo_count", 0))
	var conversion_award := 0
	var conversion := false
	if animal_count > 0:
		bonus_state["gold_buffalo_total_collected"] = maxi(0, int(bonus_state.get("gold_buffalo_total_collected", 0))) + animal_count
		bucket["gold_buffalo_heads"] = int(bucket.get("gold_buffalo_heads", 0)) + animal_count
		bucket["gold_buffalo_max_seen"] = maxi(int(bucket.get("gold_buffalo_max_seen", 0)), int(bucket.get("gold_buffalo_heads", 0)))
	if int(bucket.get("gold_buffalo_heads", 0)) >= 15:
		var pre_payout := grid_payout(grid, stake)
		var converted: Array = MathScript.clone_grid(grid)
		for reel_index in range(converted.size()):
			var column: Array = converted[reel_index] as Array
			for row_index in range(column.size()):
				if ANIMAL_SYMBOLS.has(str(column[row_index])) and bool(placement_lookup.get(_coin_cell_key(reel_index, row_index), false)):
					column[row_index] = "BUFFALO"
			converted[reel_index] = column
		_sanitize_buffalo_grid(converted, definition, _protected_cell_lookup(placement_cells))
		var post_payout := grid_payout(converted, stake)
		conversion_award = maxi(0, mini(stake * 4, post_payout - pre_payout))
		bucket["gold_buffalo_heads"] = 0
		bonus_state["gold_buffalo_conversions"] = maxi(0, int(bonus_state.get("gold_buffalo_conversions", 0))) + 1
		conversion = true
		grid = converted
	bucket["must_hit_meter"] = maxi(100, int(bucket.get("must_hit_meter", 100)) + buffalo_count * 8)
	if int(bucket.get("must_hit_meter", 100)) >= 1800:
		bucket["must_hit_ready"] = true
	buckets[bet_id] = bucket
	bonus_state["per_bet"] = buckets
	machine["bonus_state"] = bonus_state
	return {
		"grid": grid,
		"animal_count": animal_count,
		"buffalo_count": buffalo_count,
		"gold_token_count": int(side_counts.get("gold_token_count", 0)),
		"lock_count": int(side_counts.get("lock_count", 0)),
		"conversion": conversion,
		"conversion_award": conversion_award,
		"bucket": bucket.duplicate(true),
	}


func _grid_side_effect_counts(grid: Array, entry: Dictionary) -> Dictionary:
	var placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	var cells: Array = _copy_array(placement.get("cells", []))
	if cells.is_empty():
		return {
			"animal_count": 0,
			"buffalo_count": 0,
			"gold_token_count": 0,
			"lock_count": 0,
		}
	var animal_count := 0
	var buffalo_count := 0
	var gold_token_count := 0
	var lock_count := 0
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var symbol := _grid_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1)))
		if ANIMAL_SYMBOLS.has(symbol):
			animal_count += 1
		if symbol == "BUFFALO":
			buffalo_count += 1
		if symbol == "GOLD_TOKEN":
			gold_token_count += 1
		if LOCK_SYMBOLS.has(symbol):
			lock_count += 1
	gold_token_count = maxi(gold_token_count, int(placement.get("side_effect_gold_token_count", gold_token_count)))
	return {
		"animal_count": animal_count,
		"buffalo_count": buffalo_count,
		"gold_token_count": gold_token_count,
		"lock_count": lock_count,
	}


func _cell_lookup(cells: Array) -> Dictionary:
	var lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		lookup[_coin_cell_key(int(cell.get("reel", -1)), int(cell.get("row", -1)))] = true
	return lookup


func grid_payout_for_entry(grid: Array, stake: int, stake_cost: int = -1, machine: Dictionary = {}, definition: Dictionary = {}, entry: Dictionary = {}) -> int:
	var classification := str(entry.get("classification", ""))
	var forced_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	if (classification == "true_win" or classification == "ldw") and str(forced_placement.get("kind", "")) == "line":
		var forced_line_payout := _forced_line_payout(grid, stake, stake_cost, definition, forced_placement)
		if forced_line_payout >= 0:
			return forced_line_payout
	if (classification == "true_win" or classification == "ldw") and str(forced_placement.get("kind", "")) == "ways":
		var forced_payout := _forced_ways_payout(grid, stake, stake_cost, definition, forced_placement)
		if forced_payout >= 0:
			return forced_payout
	return grid_payout(grid, stake, stake_cost, machine, definition)


func _forced_line_payout(grid: Array, stake: int, stake_cost: int, definition: Dictionary, forced_placement: Dictionary) -> int:
	var cells: Array = _copy_array(forced_placement.get("cells", []))
	var symbol_id := str(forced_placement.get("symbol", ""))
	if cells.is_empty() or symbol_id.is_empty():
		return -1
	var symbols: Dictionary = _buffalo_symbol_lookup(_buffalo_config(definition))
	if not symbols.has(symbol_id):
		return -1
	var actual_symbol := _actual_forced_ways_symbol(grid, cells, symbol_id, symbols)
	if not actual_symbol.is_empty() and actual_symbol != symbol_id and symbols.has(actual_symbol):
		symbol_id = actual_symbol
	return _line_payout_for_cells(grid, cells, symbol_id, stake, stake_cost, symbols)


func _forced_ways_payout(grid: Array, stake: int, stake_cost: int, definition: Dictionary, forced_placement: Dictionary) -> int:
	var cells: Array = _copy_array(forced_placement.get("cells", []))
	var symbol_id := str(forced_placement.get("symbol", ""))
	if cells.is_empty() or symbol_id.is_empty():
		return -1
	var symbols: Dictionary = _buffalo_symbol_lookup(_buffalo_config(definition))
	var actual_symbol := _actual_forced_ways_symbol(grid, cells, symbol_id, symbols)
	if not actual_symbol.is_empty() and actual_symbol != symbol_id and symbols.has(actual_symbol):
		symbol_id = actual_symbol
	if not symbols.has(symbol_id):
		return -1
	var reel_lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		if reel_index >= 0 and reel_index < grid.size():
			reel_lookup[reel_index] = true
	if reel_lookup.size() < mini(3, maxi(1, grid.size())):
		return -1
	var ways := 1
	for reel_value in reel_lookup.keys():
		var reel_index := int(reel_value)
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		var weighted_matches := 0
		for cell in column:
			var symbol := str(cell)
			if symbol == symbol_id or (not actual_symbol.is_empty() and symbol == actual_symbol):
				weighted_matches += 1
			elif WILD_SYMBOLS.has(symbol):
				weighted_matches += _wild_multiplier(symbol)
		if weighted_matches <= 0:
			return 0
		ways *= weighted_matches
	var safe_stake := maxi(1, stake)
	var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
	var consecutive := reel_lookup.size()
	if symbol_id == "10" and consecutive == 3 and safe_stake_cost > 1:
		return maxi(1, safe_stake_cost - 1)
	var symbol_def: Dictionary = _copy_dict(symbols.get(symbol_id, {}))
	var pay_key := "pay%d" % mini(consecutive, 6)
	var pay := int(symbol_def.get(pay_key, 0))
	return safe_stake * pay * ways


func grid_payout(grid: Array, stake: int, stake_cost: int = -1, _machine: Dictionary = {}, definition: Dictionary = {}) -> int:
	var safe_stake := maxi(1, stake)
	var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
	var symbols: Dictionary = _buffalo_symbol_lookup(_buffalo_config(definition))
	var best := 0
	var reel_count := maxi(1, grid.size())
	var row_count := _grid_row_count(grid)
	var line_count := MathScript.payline_count(row_count)
	for line_index in range(line_count):
		var cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		var match: Dictionary = _line_match_for_cells(grid, cells)
		var candidate := str(match.get("symbol", ""))
		if candidate.is_empty() or not symbols.has(candidate):
			continue
		if candidate == "10" and safe_stake_cost > 1:
			best = maxi(best, maxi(1, safe_stake_cost - 1))
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
		var pay_key := "pay%d" % mini(cells.size(), 6)
		var pay := int(symbol_def.get(pay_key, 0))
		best = maxi(best, safe_stake * pay * maxi(1, int(match.get("multiplier", 1))))
	return best


func _line_match_for_cells(grid: Array, cells: Array) -> Dictionary:
	if cells.size() < maxi(1, grid.size()):
		return {}
	var symbol := ""
	var multiplier := 1
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var current := _grid_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1)))
		if current.is_empty() or current == "BLANK":
			return {}
		if WILD_SYMBOLS.has(current):
			multiplier *= _wild_multiplier(current)
			continue
		if symbol.is_empty():
			symbol = current
			continue
		if current != symbol:
			return {}
	if symbol.is_empty():
		symbol = "BUFFALO"
	return {"symbol": symbol, "multiplier": maxi(1, multiplier)}


func _line_payout_for_cells(grid: Array, cells: Array, candidate: String, stake: int, stake_cost: int, symbols: Dictionary) -> int:
	if cells.size() < maxi(1, grid.size()):
		return 0
	var multiplier := 1
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var symbol := _grid_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1)))
		if symbol == candidate:
			continue
		if WILD_SYMBOLS.has(symbol):
			multiplier *= _wild_multiplier(symbol)
			continue
		return 0
	if candidate == "10" and stake_cost > 1:
		return maxi(1, stake_cost - 1)
	var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
	var pay_key := "pay%d" % mini(cells.size(), 6)
	var pay := int(symbol_def.get(pay_key, 0))
	return maxi(0, stake) * pay * multiplier


func _actual_forced_ways_symbol(grid: Array, cells: Array, original_symbol: String, symbols: Dictionary) -> String:
	var fallback_symbol := ""
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		if row_index < 0 or row_index >= column.size():
			continue
		var symbol := str(column[row_index])
		if symbol == original_symbol:
			return original_symbol
		if WILD_SYMBOLS.has(symbol):
			continue
		if fallback_symbol.is_empty() and symbols.has(symbol):
			fallback_symbol = symbol
	return fallback_symbol


func eligible_jackpot_tiers(bet_id: String) -> Array:
	match bet_id:
		"bet_2":
			return ["mini", "grand"]
		"bet_5", "bet_10":
			return ["mini", "minor", "grand"]
		"bet_15":
			return ["mini", "minor", "major", "grand"]
		"bet_20":
			return ["mini", "minor", "major", "grand"]
		_:
			return ["mini", "grand"]


func jackpot_award_for_bet(bet_id: String, stake: int, desired_tier: String = "grand") -> Dictionary:
	var tiers: Dictionary = {"mini": 25, "minor": 75, "major": 250, "grand": GRAND_PRIZE_BASE_MULTIPLIER}
	var eligible: Array = eligible_jackpot_tiers(bet_id)
	var tier := desired_tier
	if not eligible.has(tier):
		tier = str(eligible[eligible.size() - 1])
	return {"tier": tier, "award": stake * int(tiers.get(tier, 25)), "eligible": eligible}


func base_grand_prize(stake: int, _bet_id: String = "bet_10") -> int:
	return maxi(1, stake) * GRAND_PRIZE_BASE_MULTIPLIER


func current_grand_prize(machine: Dictionary, stake: int, bet_id: String = "bet_10") -> int:
	var bucket: Dictionary = _grand_prize_bucket(machine, bet_id)
	var stored := maxi(0, int(bucket.get(GRAND_PRIZE_STATE_KEY, 0)))
	if stored > 0:
		return stored
	return base_grand_prize(stake, bet_id)


func advance_grand_prize(machine: Dictionary, stake_cost: int, stake: int, bet_id: String = "bet_10") -> int:
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
	var current := maxi(0, int(bucket.get(GRAND_PRIZE_STATE_KEY, 0)))
	if current <= 0:
		current = base_grand_prize(stake, bet_id)
	var increment := maxi(1, int(ceil(float(maxi(1, stake_cost)) * GRAND_PRIZE_INCREMENT_RATE)))
	current += increment
	bucket[GRAND_PRIZE_STATE_KEY] = current
	if int(bucket.get(GRAND_PRIZE_INITIAL_MULTIPLIER_KEY, 0)) <= 0:
		bucket[GRAND_PRIZE_INITIAL_MULTIPLIER_KEY] = GRAND_PRIZE_BASE_MULTIPLIER
	bucket[GRAND_PRIZE_SPINS_KEY] = maxi(0, int(bucket.get(GRAND_PRIZE_SPINS_KEY, 0))) + 1
	buckets[bet_id] = bucket
	bonus_state["per_bet"] = buckets
	bonus_state.erase(GRAND_PRIZE_STATE_KEY)
	machine["bonus_state"] = bonus_state
	return current


func reset_grand_prize(machine: Dictionary, stake: int, bet_id: String = "bet_10") -> void:
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
	bucket[GRAND_PRIZE_STATE_KEY] = base_grand_prize(stake, bet_id)
	bucket[GRAND_PRIZE_INITIAL_MULTIPLIER_KEY] = GRAND_PRIZE_BASE_MULTIPLIER
	bucket[GRAND_PRIZE_SPINS_KEY] = 0
	buckets[bet_id] = bucket
	bonus_state["per_bet"] = buckets
	bonus_state.erase(GRAND_PRIZE_STATE_KEY)
	machine["bonus_state"] = bonus_state


func _grand_prize_bucket(machine: Dictionary, bet_id: String) -> Dictionary:
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	return _copy_dict(buckets.get(bet_id, {}))


func hold_award_for_lock_count(stake: int, lock_count: int, max_cells: int, bet_id: String = "bet_10", grand_prize: int = -1) -> int:
	var safe_count := clampi(lock_count, 0, maxi(1, max_cells))
	var base := stake * safe_count
	var coin_bonus := stake * int(floor(float(safe_count) / 4.0))
	var multiplier := 1 + int(floor(float(safe_count) / 12.0))
	var total := (base + coin_bonus) * multiplier
	if safe_count >= max_cells:
		total += _full_screen_jackpot_award(bet_id, stake, grand_prize)
	return maxi(0, total)


func _free_games_feature(machine: Dictionary, stake: int, feature_scale: float, scatter_count: int, step_bonus: int) -> Dictionary:
	var bet_id := str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2"))
	var grand_prize := current_grand_prize(machine, stake, bet_id)
	var spins := 8
	if scatter_count >= 5:
		spins = 20
	elif scatter_count >= 4:
		spins = 15
	spins += step_bonus
	var format_id := str(machine.get("format_id", ""))
	var cap_multiplier := 74
	if format_id == "line_5x3":
		cap_multiplier = 58
	elif format_id == "classic_3_reel":
		cap_multiplier = 120
	return {
		"active": true,
		"complete": false,
		"family": FAMILY_ID,
		"mode": "free_games",
		"display_mode": "stampede_free_games",
		"bet_id": bet_id,
		"stake": stake,
		"pending_award": 0,
		"feature_total": 0,
		"awarded": 0,
		"remaining_steps": spins,
		"total_steps": spins,
		"step_index": 0,
		"retrigger_count": 0,
		"spin_win_total": 0,
		"collected_coins": [],
		"last_collected_coins": [],
		"coins_collected": 0,
		"coins_since_retrigger": 0,
		"coin_total": 0,
		"coin_collect_total": 0,
		"coin_collect_awarded": false,
		"coin_reveals": [],
		"coin_reveal_total": 0,
		"last_retrigger_grant": 0,
		"history": [],
		"feature_phase": "transition",
		"collection_meter": {"value": 0, "threshold": FREE_GAMES_RETRIGGER_THRESHOLD, "cycle": 0, "total": 0, "next_retrigger": FREE_GAMES_RETRIGGER_THRESHOLD},
		"jackpot_ladder": _jackpot_ladder_state(bet_id, stake, "", machine),
		"grand_prize": grand_prize,
		"grand_prize_awarded": 0,
		"jackpot_tier": "",
		"choices": [],
		"session_cap": maxi(1, stake * cap_multiplier),
		"feature_scale": feature_scale,
	}


func _hold_feature(machine: Dictionary, stake: int, feature_scale: float, step_bonus: int, forced_lock_cells: Array = []) -> Dictionary:
	var locks: Array = _initial_locks_from_cells(machine, forced_lock_cells, stake) if not forced_lock_cells.is_empty() else _initial_locks(machine)
	var reel_count := maxi(1, int(machine.get("reel_count", 5)))
	var row_count := maxi(1, int(machine.get("row_count", 3)))
	var max_cells := maxi(1, reel_count * row_count)
	var bet_id := str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2"))
	var grand_prize := current_grand_prize(machine, stake, bet_id)
	var session_cap := maxi(1, stake * 55)
	var current_total := _hold_lock_total(locks, stake, max_cells, bet_id, grand_prize)
	if locks.size() >= max_cells:
		session_cap = maxi(session_cap, current_total)
	current_total = mini(current_total, session_cap)
	return {
		"active": true,
		"complete": false,
		"family": FAMILY_ID,
		"mode": "hold_and_spin",
		"display_mode": "gold_stampede_lock",
		"bet_id": bet_id,
		"stake": stake,
		"pending_award": current_total,
		"feature_total": current_total,
		"awarded": 0,
		"remaining_steps": 3 + step_bonus,
		"total_steps": 3 + step_bonus,
		"step_index": 0,
		"respins_remaining": 3 + step_bonus,
		"max_cells": max_cells,
		"reel_count": reel_count,
		"row_count": row_count,
		"locks": locks,
		"history": [],
		"feature_phase": "transition",
		"fill_meter": {"locked": locks.size(), "max": max_cells, "ratio": float(locks.size()) / float(maxi(1, max_cells))},
		"jackpot_ladder": _jackpot_ladder_state(bet_id, stake, "", machine),
		"last_lock_events": [],
		"grand_prize": grand_prize,
		"grand_prize_awarded": 0,
		"session_cap": session_cap,
		"feature_scale": feature_scale,
	}


func _wheel_feature(machine: Dictionary, stake: int, feature_scale: float, rng: RngStream) -> Dictionary:
	var bet_id := str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2"))
	var choices: Array = [
		{"id": "free_games", "label": "Free Games", "route": "free_games"},
		{"id": "hold_and_spin", "label": "Coin Link", "route": "hold_and_spin"},
		{"id": "jackpot_boost", "label": "Jackpot Boost", "route": "jackpot_boost"},
	]
	var rotation := rng.randi_range(0, choices.size() - 1)
	if rotation > 0:
		choices = choices.slice(rotation, choices.size()) + choices.slice(0, rotation)
	return {
		"active": true,
		"complete": false,
		"family": FAMILY_ID,
		"mode": "wheel",
		"display_mode": "sunset_wheel_trophy",
		"gateway_type": "trophy_pick",
		"trophy_pick_active": true,
		"bet_id": bet_id,
		"stake": stake,
		"pending_award": 0,
		"feature_total": 0,
		"awarded": 0,
		"remaining_steps": 1,
		"total_steps": 1,
		"step_index": 0,
		"choices": choices,
		"trophy_choices": _trophy_choices_from_choices(choices, bet_id, stake),
		"trophy_reveals": [],
		"history": [],
		"feature_phase": "transition",
		"jackpot_ladder": _jackpot_ladder_state(bet_id, stake, "", machine),
		"session_cap": stake * 72,
		"feature_scale": feature_scale,
		"wheel_angle": rng.randi_range(0, 359),
	}


func _step_wheel(machine: Dictionary, active: Dictionary, action_id: String, rng: RngStream) -> Dictionary:
	var choices: Array = _dictionary_array(active.get("choices", []))
	var choice_index := 1
	if action_id == "slot_bonus_left":
		choice_index = 0
	elif action_id == "slot_bonus_right":
		choice_index = 2
	choice_index = clampi(choice_index, 0, maxi(0, choices.size() - 1))
	var choice: Dictionary = choices[choice_index] if not choices.is_empty() else {"id": "free_games", "route": "free_games"}
	var history: Array = _dictionary_array(active.get("history", []))
	var trophy_choices: Array = _dictionary_array(active.get("trophy_choices", []))
	var reveal: Dictionary = _trophy_reveal_for_choice(choice, choice_index, trophy_choices, active, rng)
	var wheel_stop := int(active.get("wheel_angle", 0)) + rng.randi_range(80, 220)
	history.append({"id": "trophy_pick_reveal", "choice_id": str(choice.get("id", "free_games")), "route": str(choice.get("route", "free_games")), "choice_index": choice_index, "wheel_stop": wheel_stop, "reveal": reveal})
	active["history"] = history
	active["selected_path"] = str(choice.get("id", "free_games"))
	active["trophy_pick_active"] = false
	active["trophy_reveals"] = [reveal]
	active["feature_phase"] = "play"
	var route := str(choice.get("route", "free_games"))
	if route == "free_games":
		var routed: Dictionary = _free_games_feature(machine, int(active.get("stake", 0)), float(active.get("feature_scale", 1.0)) * 1.08, 4, 2)
		routed["history"] = history
		routed["feature_origin"] = "trophy_pick"
		routed["trophy_reveals"] = [reveal]
		routed["trophy_selected_path"] = str(choice.get("id", "free_games"))
		routed["jackpot_ladder"] = _jackpot_ladder_state(str(active.get("bet_id", "bet_2")), int(active.get("stake", 0)), "", machine)
		machine["active_bonus"] = routed
		return _bonus_step_result(false, 0, "Wheel routes into free games.", routed)
	if route == "hold_and_spin":
		var routed_hold: Dictionary = _hold_feature(machine, int(active.get("stake", 0)), float(active.get("feature_scale", 1.0)) * 1.10, 1)
		routed_hold["history"] = history
		routed_hold["feature_origin"] = "trophy_pick"
		routed_hold["trophy_reveals"] = [reveal]
		routed_hold["trophy_selected_path"] = str(choice.get("id", "hold_and_spin"))
		routed_hold["jackpot_ladder"] = _jackpot_ladder_state(str(active.get("bet_id", "bet_2")), int(active.get("stake", 0)), "", machine)
		machine["active_bonus"] = routed_hold
		return _bonus_step_result(false, 0, "Wheel routes into coin link.", routed_hold)
	var jackpot: Dictionary = jackpot_award_for_bet(str(active.get("bet_id", "bet_2")), int(active.get("stake", 0)), "grand")
	var award := mini(maxi(1, int(active.get("session_cap", int(active.get("stake", 0)) * 70))), int(jackpot.get("award", 0)) + int(active.get("stake", 0)) * rng.randi_range(8, 18))
	active["active"] = false
	active["complete"] = true
	active["feature_phase"] = "celebration"
	active["awarded"] = award
	active["pending_award"] = award
	active["feature_total"] = award
	active["jackpot_tier"] = str(jackpot.get("tier", "mini"))
	active["jackpot_ladder"] = _jackpot_ladder_state(str(active.get("bet_id", "bet_2")), int(active.get("stake", 0)), str(jackpot.get("tier", "mini")), machine)
	machine["active_bonus"] = {"active": false, "complete": true}
	return _bonus_step_result(true, award, "Wheel jackpot pays $%d." % award, active)


func _step_hold(machine: Dictionary, active: Dictionary, rng: RngStream) -> Dictionary:
	var history: Array = _dictionary_array(active.get("history", []))
	var locks: Array = _dictionary_array(active.get("locks", []))
	var max_cells := maxi(1, int(active.get("max_cells", 15)))
	var row_count := maxi(1, int(active.get("row_count", machine.get("row_count", 3))))
	var stake := maxi(1, int(active.get("stake", 1)))
	var bet_id := str(active.get("bet_id", "bet_2"))
	var grand_prize := maxi(current_grand_prize(machine, stake, bet_id), int(active.get("grand_prize", 0)))
	var added_count := 0
	var new_lock_events: Array = []
	var open_cells := max_cells - locks.size()
	if open_cells > 0:
		var chance := clampi(46 - locks.size(), 16, 48)
		if max_cells <= 20:
			chance = clampi(22 - locks.size(), 3, 24)
		var attempts := 1
		if str(active.get("display_mode", "")) == "gold_stampede_lock" and max_cells > 20 and locks.size() >= max_cells / 2:
			attempts = 2
		for _attempt in range(attempts):
			if open_cells <= 0:
				break
			if rng.randi_range(1, 100) <= chance:
				var lock: Dictionary = _new_lock(locks, max_cells, stake, row_count, rng, _copy_dict(active.get("slot_item_effects", {})))
				lock["source"] = "respin"
				lock["reveal_start_msec"] = 1700 + added_count * 180
				lock["reveal_duration_msec"] = 360
				locks.append(lock)
				new_lock_events.append(lock.duplicate(true))
				added_count += 1
				open_cells -= 1
	var full_screen := locks.size() >= max_cells
	var session_cap := maxi(1, int(active.get("session_cap", stake * 55)))
	var raw_feature_total := _hold_lock_total(locks, stake, max_cells, bet_id, grand_prize)
	if full_screen:
		session_cap = maxi(session_cap, raw_feature_total)
	var feature_total := mini(session_cap, raw_feature_total)
	active["locks"] = locks
	active["feature_total"] = feature_total
	active["pending_award"] = feature_total
	active["fill_meter"] = {"locked": locks.size(), "max": max_cells, "ratio": float(locks.size()) / float(maxi(1, max_cells))}
	active["last_lock_events"] = new_lock_events
	active["grand_prize"] = grand_prize
	active["jackpot_ladder"] = _jackpot_ladder_state(bet_id, stake, str(active.get("jackpot_tier", "")), machine)
	active["feature_phase"] = "play"
	active["step_index"] = int(active.get("step_index", 0)) + 1
	if added_count > 0:
		active["respins_remaining"] = 3
		active["remaining_steps"] = 3
	else:
		active["respins_remaining"] = maxi(0, int(active.get("respins_remaining", active.get("remaining_steps", 3))) - 1)
		active["remaining_steps"] = int(active.get("respins_remaining", 0))
	if int(active.get("step_index", 0)) >= 24:
		active["remaining_steps"] = 0
		active["respins_remaining"] = 0
	history.append({"id": "coin_lock_respin", "step": int(active.get("step_index", 0)), "added_locks": added_count, "lock_count": locks.size(), "award": feature_total, "respins_remaining": int(active.get("respins_remaining", 0))})
	active["history"] = history
	if full_screen:
		active["jackpot_tier"] = "grand" if _grand_prize_eligible(bet_id) else str(jackpot_award_for_bet(bet_id, stake, "grand").get("tier", "mini"))
		active["grand_prize_awarded"] = grand_prize if _grand_prize_eligible(bet_id) else 0
		active["jackpot_ladder"] = _jackpot_ladder_state(bet_id, stake, str(active.get("jackpot_tier", "")), machine)
	var display: Dictionary = _hold_respin_display(machine, active, locks, new_lock_events, rng)
	if int(active.get("remaining_steps", 0)) <= 0 or locks.size() >= max_cells:
		active["active"] = false
		active["complete"] = true
		active["feature_phase"] = "celebration"
		active["awarded"] = feature_total
		machine["active_bonus"] = {"active": false, "complete": true}
		var complete_message := "Grand Stampede pays $%d." % feature_total if full_screen and _grand_prize_eligible(bet_id) else "Gold Stampede pays $%d." % feature_total
		var complete_step := _bonus_step_result(true, feature_total, complete_message, active)
		complete_step["grand_prize_awarded"] = int(active.get("grand_prize_awarded", 0))
		complete_step["jackpot_tier"] = str(active.get("jackpot_tier", ""))
		complete_step.merge(display, true)
		return complete_step
	machine["active_bonus"] = active
	var step := _bonus_step_result(false, 0, "Coins locked: %d." % locks.size(), active)
	step.merge(display, true)
	return step


func _step_free_games(machine: Dictionary, active: Dictionary, rng: RngStream) -> Dictionary:
	var history: Array = _dictionary_array(active.get("history", []))
	var stake := maxi(1, int(active.get("stake", 1)))
	var bet_id := str(active.get("bet_id", _copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2")))
	var reel_count := maxi(1, int(machine.get("reel_count", 5)))
	var row_count := maxi(1, int(machine.get("row_count", 4)))
	var reel_strips: Array = _copy_array(machine.get("bonus_reel_strips", machine.get("reel_strips", [])))
	if reel_strips.is_empty():
		reel_strips = _copy_array(machine.get("reel_strips", []))
	var stops: Array = MathScript.pick_reel_stops(reel_strips, rng)
	var grid: Array = MathScript.project_grid(reel_strips, stops, reel_count, row_count)
	var coin_result: Dictionary = _collect_free_game_coins(active, grid, stake, float(active.get("feature_scale", 1.0)), rng)
	var collected_coins: Array = _dictionary_array(coin_result.get("collected_coins", []))
	var new_coins: Array = _dictionary_array(coin_result.get("new_coins", []))
	var coin_total := maxi(0, int(coin_result.get("coin_total", 0)))
	var coins_collected := maxi(0, int(coin_result.get("coins_collected", 0)))
	var coins_since_retrigger := maxi(0, int(coin_result.get("coins_since_retrigger", 0)))
	var retrigger := 0
	var retrigger_events := 0
	var projected_total_steps := maxi(0, int(active.get("total_steps", 0)))
	while coins_since_retrigger >= FREE_GAMES_RETRIGGER_THRESHOLD and projected_total_steps + FREE_GAMES_RETRIGGER_GRANT <= FREE_GAMES_MAX_TOTAL_STEPS:
		coins_since_retrigger -= FREE_GAMES_RETRIGGER_THRESHOLD
		retrigger += FREE_GAMES_RETRIGGER_GRANT
		retrigger_events += 1
		projected_total_steps += FREE_GAMES_RETRIGGER_GRANT
	var grid_award := grid_payout(grid, stake)
	var spin_award := grid_award
	var spin_win_total := maxi(0, int(active.get("spin_win_total", active.get("feature_total", 0)))) + spin_award
	active["spin_win_total"] = spin_win_total
	active["feature_total"] = spin_win_total
	active["pending_award"] = spin_win_total
	active["collected_coins"] = collected_coins
	active["last_collected_coins"] = new_coins
	active["coins_collected"] = coins_collected
	active["coins_since_retrigger"] = coins_since_retrigger
	active["coin_total"] = coin_total
	active["coin_collect_total"] = 0
	active["coin_collect_awarded"] = false
	active["coin_reveals"] = []
	active["coin_reveal_total"] = 0
	active["last_retrigger_grant"] = retrigger
	active["collection_meter"] = _coin_collection_meter(active)
	active["feature_phase"] = "play"
	active["step_index"] = int(active.get("step_index", 0)) + 1
	active["remaining_steps"] = maxi(0, int(active.get("remaining_steps", 0)) - 1 + retrigger)
	if retrigger > 0:
		active["total_steps"] = int(active.get("total_steps", 0)) + retrigger
		active["retrigger_count"] = int(active.get("retrigger_count", 0)) + retrigger_events
	var classification := "true_win" if spin_award > stake else "ldw" if spin_award > 0 else "zero_loss"
	history.append({"id": "stampede_free_spin", "step": int(active.get("step_index", 0)), "gold_tokens": new_coins.size(), "coin_hits": new_coins.duplicate(true), "coins_collected": coins_collected, "coins_since_retrigger": coins_since_retrigger, "coin_award": int(coin_result.get("coin_award", 0)), "coin_total": coin_total, "retrigger": retrigger, "retrigger_events": retrigger_events, "grid_award": grid_award, "award": spin_award, "running_total": spin_win_total, "grid": grid.duplicate(true), "reel_stops": stops.duplicate(true), "classification": classification})
	active["history"] = history
	var cell_capacity := maxi(1, reel_count * row_count)
	var full_screen := MathScript.count_symbol(grid, "GOLD_TOKEN") >= cell_capacity
	if full_screen:
		active["remaining_steps"] = 0
	if int(active.get("remaining_steps", 0)) <= 0:
		var grand_prize := maxi(current_grand_prize(machine, stake, bet_id), int(active.get("grand_prize", 0)))
		var grand_award := _full_screen_jackpot_award(bet_id, stake, grand_prize) if full_screen else 0
		var final_total := spin_win_total + coin_total + grand_award if full_screen else mini(maxi(1, int(active.get("session_cap", stake * 70))), spin_win_total + coin_total)
		var coin_reveals: Array = _coin_reveal_sequence(collected_coins, coin_total if full_screen else mini(coin_total, final_total))
		var credited_coin_total := _coin_reveal_total(coin_reveals)
		var credited_spin_total := maxi(0, final_total - credited_coin_total)
		active["spin_win_total"] = credited_spin_total
		active["feature_total"] = final_total
		active["pending_award"] = final_total
		active["coin_collect_total"] = credited_coin_total
		active["coin_collect_awarded"] = credited_coin_total > 0
		active["coin_reveals"] = coin_reveals
		active["coin_reveal_total"] = credited_coin_total
		active["active"] = false
		active["complete"] = true
		active["feature_phase"] = "coin_collect"
		active["awarded"] = final_total
		active["collection_meter"] = _coin_collection_meter(active)
		active["full_screen_grand"] = full_screen
		active["grand_prize"] = grand_prize
		active["grand_prize_awarded"] = grand_award
		if full_screen:
			active["jackpot_tier"] = "grand" if _grand_prize_eligible(bet_id) else str(jackpot_award_for_bet(bet_id, stake, "grand").get("tier", "mini"))
			active["feature_phase"] = "grand_jackpot"
			active["jackpot_ladder"] = _jackpot_ladder_state(bet_id, stake, str(active.get("jackpot_tier", "")), machine)
		machine["last_bonus_replay"] = active.duplicate(true)
		machine["active_bonus"] = {"active": false, "complete": true}
		var complete_message := "Grand Stampede jackpot pays $%d, including Grand $%d and $%d in coins." % [final_total, grand_award, credited_coin_total] if full_screen else "Stampede free games pay $%d, including $%d in coins." % [final_total, credited_coin_total]
		var complete_step := _bonus_step_result(true, final_total, complete_message, active)
		complete_step["id"] = "stampede_free_spin"
		complete_step["grid"] = grid.duplicate(true)
		complete_step["reel_stops"] = stops.duplicate(true)
		complete_step["classification"] = classification
		complete_step["spin_award"] = spin_award
		complete_step["coin_collect_total"] = credited_coin_total
		complete_step["grand_prize_awarded"] = grand_award
		complete_step["jackpot_tier"] = str(active.get("jackpot_tier", ""))
		return complete_step
	machine["active_bonus"] = active
	var step := _bonus_step_result(false, 0, "Stampede free spin adds $%d and banks $%d in coins." % [spin_award, int(coin_result.get("coin_award", 0))], active)
	step["id"] = "stampede_free_spin"
	step["grid"] = grid.duplicate(true)
	step["reel_stops"] = stops.duplicate(true)
	step["classification"] = classification
	step["spin_award"] = spin_award
	return step


func _collect_free_game_coins(active: Dictionary, grid: Array, stake: int, feature_scale: float, rng: RngStream) -> Dictionary:
	var collected: Array = _dictionary_array(active.get("collected_coins", []))
	var by_cell: Dictionary = {}
	for index in range(collected.size()):
		var coin: Dictionary = _copy_dict(collected[index])
		by_cell[_coin_cell_key(int(coin.get("reel", 0)), int(coin.get("row", 0)))] = index
	var new_coins: Array = []
	var added_value := 0
	var coins_collected := maxi(0, int(active.get("coins_collected", 0)))
	var coins_since_retrigger := maxi(0, int(active.get("coins_since_retrigger", 0)))
	var coin_total := maxi(0, int(active.get("coin_total", 0)))
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			if str(column[row_index]) != "GOLD_TOKEN":
				continue
			var value_info: Dictionary = _free_game_coin_value(stake, feature_scale, rng, _copy_dict(active.get("slot_item_effects", {})))
			var value := maxi(1, int(value_info.get("value", stake)))
			var key := _coin_cell_key(reel_index, row_index)
			var coin: Dictionary = {
				"reel": reel_index,
				"row": row_index,
				"value": value,
				"added_value": value,
				"tier": str(value_info.get("tier", "")),
				"symbol": "GOLD_TOKEN",
				"count": 1,
				"step": int(active.get("step_index", 0)) + 1,
			}
			if by_cell.has(key):
				var existing_index := int(by_cell.get(key, 0))
				var existing: Dictionary = _copy_dict(collected[existing_index])
				existing["value"] = maxi(0, int(existing.get("value", 0))) + value
				existing["added_value"] = value
				existing["tier"] = str(value_info.get("tier", existing.get("tier", "")))
				existing["count"] = maxi(1, int(existing.get("count", 1))) + 1
				existing["step"] = int(active.get("step_index", 0)) + 1
				collected[existing_index] = existing
				coin = existing.duplicate(true)
			else:
				by_cell[key] = collected.size()
				collected.append(coin.duplicate(true))
			new_coins.append(coin.duplicate(true))
			added_value += value
			coin_total += value
			coins_collected += 1
			coins_since_retrigger += 1
	return {
		"collected_coins": collected,
		"new_coins": new_coins,
		"coin_award": added_value,
		"coin_total": coin_total,
		"coins_collected": coins_collected,
		"coins_since_retrigger": coins_since_retrigger,
	}


func _coin_reveal_sequence(collected_coins: Array, target_total: int) -> Array:
	var coins: Array = _dictionary_array(collected_coins)
	var reveal_count := coins.size()
	var safe_total := maxi(0, target_total)
	var result: Array = []
	if reveal_count <= 0 or safe_total <= 0:
		return result
	var original_total := 0
	for coin_value in coins:
		var coin: Dictionary = _copy_dict(coin_value)
		original_total += maxi(0, int(coin.get("value", 0)))
	var remaining := safe_total
	for index in range(reveal_count):
		var coin: Dictionary = _copy_dict(coins[index])
		var remaining_cells := reveal_count - index
		var value := 0
		if remaining > 0:
			if safe_total >= reveal_count:
				value = 1
				remaining -= 1
			else:
				value = 1 if index < safe_total else 0
				remaining = maxi(0, remaining - value)
		if remaining > 0:
			var weighted := 0
			if original_total > 0:
				weighted = int(floor(float(maxi(0, int(coin.get("value", 0)))) / float(original_total) * float(safe_total - mini(safe_total, reveal_count))))
			var max_extra := maxi(0, remaining - maxi(0, remaining_cells - 1))
			var extra := mini(max_extra, weighted)
			value += extra
			remaining -= extra
		coin["index"] = index
		coin["original_value"] = maxi(0, int(coin.get("value", 0)))
		coin["value"] = value
		coin["revealed"] = false
		coin["reveal_start_msec"] = 180 + index * 170
		coin["reveal_duration_msec"] = 320
		result.append(coin)
	if remaining > 0 and not result.is_empty():
		var last_index := result.size() - 1
		var last: Dictionary = _copy_dict(result[last_index])
		last["value"] = maxi(0, int(last.get("value", 0))) + remaining
		result[last_index] = last
	return result


func _coin_reveal_total(reveals: Array) -> int:
	var total := 0
	for reveal_value in reveals:
		var reveal: Dictionary = _copy_dict(reveal_value)
		total += maxi(0, int(reveal.get("value", 0)))
	return total


func _free_game_coin_value(stake: int, feature_scale: float, rng: RngStream, item_effects: Dictionary = {}) -> Dictionary:
	var roll := rng.randi_range(1, 1000)
	var value := stake
	var tier := ""
	if roll <= 30:
		tier = "major"
		value = stake * 28
	elif roll <= 95:
		tier = "minor"
		value = stake * 11
	elif roll <= 190:
		tier = "mini"
		value = stake * 5
	elif roll <= 330:
		value = stake * 4
	elif roll <= 560:
		value = stake * 3
	else:
		value = stake * rng.randi_range(1, 2)
	var upgrade_chance := clampi(int(item_effects.get("slot_gold_tooth_coin_upgrade_chance", 0)), 0, 100)
	if upgrade_chance > 0 and rng.randi_range(1, 100) <= upgrade_chance:
		var multiplier := maxi(2, int(item_effects.get("slot_gold_tooth_coin_multiplier", 2)))
		value *= multiplier
		if tier.is_empty():
			tier = "bright"
	return {"value": maxi(1, int(round(float(value) * maxf(0.25, feature_scale)))), "tier": tier}


func _coin_collection_meter(active: Dictionary) -> Dictionary:
	var cycle := maxi(0, int(active.get("coins_since_retrigger", 0)))
	var total := maxi(0, int(active.get("coins_collected", 0)))
	return {
		"value": cycle,
		"threshold": FREE_GAMES_RETRIGGER_THRESHOLD,
		"cycle": cycle,
		"total": total,
		"coin_total": maxi(0, int(active.get("coin_total", 0))),
		"next_retrigger": FREE_GAMES_RETRIGGER_THRESHOLD - mini(cycle, FREE_GAMES_RETRIGGER_THRESHOLD),
	}


func _coin_cell_key(reel_index: int, row_index: int) -> String:
	return "%d:%d" % [reel_index, row_index]


func _trophy_choices_from_choices(choices: Array, bet_id: String, stake: int) -> Array:
	var trophies: Array = []
	for index in range(choices.size()):
		var choice: Dictionary = _copy_dict(choices[index])
		var route := str(choice.get("route", choice.get("id", "")))
		var tier := ""
		var award_hint := 0
		if route == "jackpot_boost":
			var jackpot: Dictionary = jackpot_award_for_bet(bet_id, stake, "grand")
			tier = str(jackpot.get("tier", "mini"))
			award_hint = int(jackpot.get("award", 0))
		trophies.append({
			"index": index,
			"id": str(choice.get("id", "")),
			"label": str(choice.get("label", "")),
			"route": route,
			"tier": tier,
			"award_hint": award_hint,
			"revealed": false,
		})
	return trophies


func _trophy_reveal_for_choice(choice: Dictionary, choice_index: int, trophy_choices: Array, active: Dictionary, rng: RngStream) -> Dictionary:
	var reveal: Dictionary = {}
	if choice_index >= 0 and choice_index < trophy_choices.size():
		reveal = _copy_dict(trophy_choices[choice_index])
	else:
		reveal = {"index": choice_index, "id": str(choice.get("id", "")), "label": str(choice.get("label", "")), "route": str(choice.get("route", ""))}
	reveal["revealed"] = true
	reveal["pick_flash"] = rng.randi_range(2, 5)
	if str(reveal.get("route", "")) == "jackpot_boost":
		var jackpot: Dictionary = jackpot_award_for_bet(str(active.get("bet_id", "bet_2")), int(active.get("stake", 0)), "grand")
		reveal["tier"] = str(jackpot.get("tier", "mini"))
		reveal["award_hint"] = int(jackpot.get("award", 0))
	return reveal


func _jackpot_ladder_state(bet_id: String, stake: int, lit_tier: String, machine: Dictionary = {}) -> Dictionary:
	var eligible: Array = eligible_jackpot_tiers(bet_id)
	var tiers: Array = []
	for tier_id in ["mini", "minor", "major", "grand"]:
		var jackpot: Dictionary = jackpot_award_for_bet(bet_id, stake, tier_id)
		var award := int(jackpot.get("award", 0))
		if tier_id == "grand" and not machine.is_empty():
			award = current_grand_prize(machine, stake, bet_id)
		tiers.append({
			"id": tier_id,
			"eligible": eligible.has(tier_id),
			"lit": lit_tier == tier_id or (lit_tier == "grand" and tier_id == "grand"),
			"award": award,
		})
	return {
		"visible": true,
		"tiers": tiers,
		"lit_tier": lit_tier,
		"eligible": eligible,
	}


func _new_lock(existing_locks: Array, max_cells: int, stake: int, row_count: int, rng: RngStream, item_effects: Dictionary = {}) -> Dictionary:
	var occupied: Dictionary = {}
	for lock_value in existing_locks:
		var lock: Dictionary = _copy_dict(lock_value)
		occupied[int(lock.get("cell", 0))] = true
	var cell := rng.randi_range(0, maxi(0, max_cells - 1))
	var guard := 0
	while bool(occupied.get(cell, false)) and guard < max_cells + 2:
		cell = posmod(cell + 1, max_cells)
		guard += 1
	var roll := rng.randi_range(1, 1000)
	var value := stake * 2
	var symbol := "BUFFALO"
	var multiplier := 1
	var tier := ""
	if roll <= 30:
		tier = "major"
		value = stake * 28
		symbol = "CASH"
	elif roll <= 95:
		tier = "minor"
		value = stake * 11
		symbol = "CASH"
	elif roll <= 190:
		tier = "mini"
		value = stake * 5
		symbol = "CASH"
	elif roll <= 330:
		multiplier = 3
		value = stake * 2
	elif roll <= 560:
		multiplier = 2
		value = stake * 2
	else:
		value = stake * rng.randi_range(1, 3)
	var upgrade_chance := clampi(int(item_effects.get("slot_gold_tooth_coin_upgrade_chance", 0)), 0, 100)
	if upgrade_chance > 0 and rng.randi_range(1, 100) <= upgrade_chance:
		var tooth_multiplier := maxi(2, int(item_effects.get("slot_gold_tooth_coin_multiplier", 2)))
		value *= tooth_multiplier
		if tier.is_empty():
			tier = "bright"
		symbol = "CASH"
	var safe_rows := maxi(1, row_count)
	return {"cell": cell, "reel": int(cell / safe_rows), "row": cell % safe_rows, "symbol": symbol, "value": value, "multiplier": multiplier, "tier": tier}


func _hold_respin_display(machine: Dictionary, active: Dictionary, locks: Array, new_lock_events: Array, rng: RngStream) -> Dictionary:
	var reel_count := maxi(1, int(active.get("reel_count", machine.get("reel_count", 5))))
	var row_count := maxi(1, int(active.get("row_count", machine.get("row_count", 3))))
	var reel_strips: Array = _copy_array(machine.get("bonus_reel_strips", machine.get("reel_strips", [])))
	if reel_strips.is_empty():
		reel_strips = _copy_array(machine.get("reel_strips", []))
	var stops: Array = MathScript.pick_reel_stops(reel_strips, rng)
	var grid: Array = MathScript.project_grid(reel_strips, stops, reel_count, row_count)
	var lock_lookup: Dictionary = {}
	for lock_value in locks:
		var lock: Dictionary = _copy_dict(lock_value)
		var cell: Dictionary = _hold_lock_cell(lock, row_count)
		var reel := int(cell.get("reel", -1))
		var row := int(cell.get("row", -1))
		if reel < 0 or row < 0:
			continue
		lock_lookup["%d:%d" % [reel, row]] = true
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			var key := "%d:%d" % [reel_index, row_index]
			if bool(lock_lookup.get(key, false)):
				column[row_index] = "GOLD_TOKEN"
			elif str(column[row_index]) == "GOLD_TOKEN":
				column[row_index] = _buffalo_fill_symbol(reel_index, row_index, _grid_seed(grid))
		grid[reel_index] = column
	return {
		"id": "gold_stampede_respin",
		"classification": "hold_and_spin",
		"grid": grid.duplicate(true),
		"reel_stops": stops.duplicate(true),
		"forced_placement": {"kind": "feature", "symbol": "GOLD_TOKEN", "cells": _hold_lock_cells(new_lock_events), "line_index": -1},
		"spin_award": 0,
	}


func _hold_lock_total(locks: Array, stake: int, max_cells: int, bet_id: String, grand_prize: int = -1) -> int:
	var sum := 0
	var multiplier_bonus := 0
	for lock_value in locks:
		var lock: Dictionary = _copy_dict(lock_value)
		sum += maxi(0, int(lock.get("value", stake)))
		multiplier_bonus += maxi(0, int(lock.get("multiplier", 1)) - 1)
	var total := int(round(float(sum) * (1.0 + minf(1.5, float(multiplier_bonus) * 0.18))))
	if locks.size() >= max_cells:
		total += _full_screen_jackpot_award(bet_id, stake, grand_prize)
	return maxi(0, total)


func _full_screen_jackpot_award(bet_id: String, stake: int, grand_prize: int = -1) -> int:
	if _grand_prize_eligible(bet_id):
		return grand_prize if grand_prize > 0 else base_grand_prize(stake, bet_id)
	return int(jackpot_award_for_bet(bet_id, stake, "grand").get("award", 0))


func _grand_prize_eligible(bet_id: String) -> bool:
	return eligible_jackpot_tiers(bet_id).has("grand")


func _initial_locks(machine: Dictionary) -> Array:
	var locks: Array = []
	var grid: Array = machine.get("last_grid", [])
	var stake := int(_copy_dict(machine.get("bet_ladder", {})).get("selected_total", 10))
	var cell_index := 0
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			var symbol := str(column[row_index])
			if LOCK_SYMBOLS.has(symbol):
				locks.append({"cell": cell_index, "reel": reel_index, "row": row_index, "symbol": symbol, "value": stake * (3 if symbol == "CASH" else 1), "multiplier": 1, "source": "trigger", "reveal_start_msec": 0, "reveal_duration_msec": 0})
			cell_index += 1
	return locks


func _initial_locks_from_cells(machine: Dictionary, cells: Array, stake: int) -> Array:
	var locks: Array = []
	var grid: Array = machine.get("last_grid", [])
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index < 0 or row_index < 0:
			continue
		var symbol := "GOLD_TOKEN"
		if reel_index < grid.size() and typeof(grid[reel_index]) == TYPE_ARRAY:
			var column: Array = grid[reel_index] as Array
			if row_index < column.size() and (LOCK_SYMBOLS.has(str(column[row_index])) or str(column[row_index]) == "GOLD_TOKEN"):
				symbol = str(column[row_index])
		locks.append({
			"cell": reel_index * row_count + row_index,
			"reel": reel_index,
			"row": row_index,
			"symbol": symbol,
			"value": stake * (3 if symbol == "CASH" or symbol == "GOLD_TOKEN" else 1),
			"multiplier": 1,
			"source": "trigger",
			"reveal_start_msec": 0,
			"reveal_duration_msec": 0,
		})
	return locks


func _hold_lock_cell(lock: Dictionary, row_count: int) -> Dictionary:
	if lock.has("reel") and lock.has("row"):
		return {"reel": int(lock.get("reel", -1)), "row": int(lock.get("row", -1))}
	var safe_rows := maxi(1, row_count)
	var cell := maxi(0, int(lock.get("cell", 0)))
	return {"reel": int(cell / safe_rows), "row": cell % safe_rows}


func _hold_lock_cells(locks: Array) -> Array:
	var result: Array = []
	for lock_value in locks:
		var lock: Dictionary = _copy_dict(lock_value)
		if lock.has("reel") and lock.has("row"):
			result.append({"reel": int(lock.get("reel", -1)), "row": int(lock.get("row", -1))})
	return result


func _heritage_table(table: Array) -> Array:
	var result: Array = []
	var removed_weight := 0
	var free_index := -1
	for entry_value in table:
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		if str(entry.get("classification", "")) == "hold_and_spin" or str(entry.get("classification", "")) == "monster_feature":
			removed_weight += int(entry.get("weight", 0))
			continue
		if str(entry.get("id", "")) == "free_games":
			free_index = result.size()
		result.append(entry)
	if free_index >= 0 and removed_weight > 0:
		var free_entry: Dictionary = result[free_index]
		free_entry["weight"] = maxi(1, int(free_entry.get("weight", 0)) + removed_weight)
		result[free_index] = free_entry
	return result


func _adjusted_table(table: Array, math_id: String, table_id: String) -> Array:
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
			elif id == "monster_feature" or id == "hold_and_spin":
				weight = int(round(float(weight) * 0.88))
		elif math_id == "volatile":
			if id == "zero_loss":
				weight = int(round(float(weight) * 1.03))
			elif id == "ldw":
				weight = int(round(float(weight) * 0.90))
			elif id == "monster_feature" or id == "hold_and_spin":
				weight = int(round(float(weight) * 1.25))
		entry["weight"] = maxi(0, weight)
		result.append(entry)
	return _normalize_table_total(result, 10000, table_id)


func _normalize_table_total(table: Array, target_total: int, _table_id: String) -> Array:
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
			column[row_index] = _buffalo_fill_symbol(reel_index, row_index, cell_seed)
		grid[reel_index] = column


func _sanitize_buffalo_grid(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> void:
	_limit_symbol_count(grid, "GOLD_TOKEN", 0, protected_cells)
	var guard := 0
	while guard < 128:
		var violation: Dictionary = _first_buffalo_ways_violation(grid, definition, protected_cells)
		if violation.is_empty():
			return
		var break_cell: Dictionary = _first_unprotected_cell(_copy_array(violation.get("cells", [])), protected_cells)
		if break_cell.is_empty():
			return
		MathScript.set_cell(grid, int(break_cell.get("reel", 0)), int(break_cell.get("row", 0)), "BLANK")
		guard += 1


func _first_buffalo_ways_violation(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var symbols: Dictionary = _buffalo_symbol_lookup(_buffalo_config(definition))
	var reel_count := maxi(1, grid.size())
	var row_count := _grid_row_count(grid)
	var line_count := MathScript.payline_count(row_count)
	for line_index in range(line_count):
		var cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		var match: Dictionary = _line_match_for_cells(grid, cells)
		var candidate := str(match.get("symbol", ""))
		if not candidate.is_empty() and symbols.has(candidate) and not _all_cells_protected(cells, protected_cells):
			return {"cells": cells, "symbol": candidate, "start_reel": 0, "line_index": line_index}
	return {}


func _first_buffalo_ways_violation_legacy(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var symbols: Dictionary = _buffalo_symbol_lookup(_buffalo_config(definition))
	for candidate_value in symbols.keys():
		var candidate := str(candidate_value)
		var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
		if int(symbol_def.get("pay3", 0)) <= 0:
			continue
		for start_reel in range(grid.size()):
			var consecutive := 0
			var cells: Array = []
			for reel_index in range(start_reel, grid.size()):
				var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
				var reel_cells: Array = []
				for row_index in range(column.size()):
					var symbol := str(column[row_index])
					if symbol == candidate or WILD_SYMBOLS.has(symbol):
						reel_cells.append({"reel": reel_index, "row": row_index})
				if reel_cells.is_empty():
					break
				consecutive += 1
				cells.append_array(reel_cells)
			if consecutive >= 3 and not _all_cells_protected(cells, protected_cells):
				return {"cells": cells, "symbol": candidate, "start_reel": start_reel}
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


func _grid_row_count(grid: Array) -> int:
	var rows := 1
	for column_value in grid:
		if typeof(column_value) == TYPE_ARRAY:
			rows = maxi(rows, (column_value as Array).size())
	return rows


func _buffalo_true_win_plan(reel_count: int, format_id: String, rng: RngStream, definition: Dictionary) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var profile_plan: Dictionary = _buffalo_true_win_profile_plan(safe_reels, format_id, rng, definition)
	if not profile_plan.is_empty():
		return profile_plan
	if safe_reels <= 3:
		var classic_roll := rng.randi_range(1, 100)
		var classic_symbol := "BUFFALO"
		if classic_roll > 45 and classic_roll <= 78:
			classic_symbol = str(ANIMAL_SYMBOLS[rng.randi_range(0, ANIMAL_SYMBOLS.size() - 1)])
		elif classic_roll > 78:
			classic_symbol = str(CARD_SYMBOLS[rng.randi_range(0, CARD_SYMBOLS.size() - 2)])
		return {"count": mini(3, safe_reels), "symbol": classic_symbol, "wild_reel": 1, "wild_symbol": "SUNSET_2X", "classic_dual_wild": true}
	var roll := rng.randi_range(1, 100)
	var low_symbols := ["A", "K", "Q", "J"]
	var animal_symbols := ["ELK", "HORSE", "WOLF"]
	var premium_symbols := ["EAGLE", "BUFFALO"]
	var symbol := str(low_symbols[rng.randi_range(0, low_symbols.size() - 1)])
	var wild_cell_index := -1
	var wild_symbol := ""
	if roll <= 8:
		symbol = str(premium_symbols[rng.randi_range(0, premium_symbols.size() - 1)])
	elif roll <= 34:
		symbol = str(animal_symbols[rng.randi_range(0, animal_symbols.size() - 1)])
	if rng.randi_range(1, 100) <= (4 if format_id == "video_feature" or format_id == "line_5x3" else 3):
		wild_cell_index = rng.randi_range(0, safe_reels - 1)
		wild_symbol = str(WILD_SYMBOLS[rng.randi_range(0, WILD_SYMBOLS.size() - 1)])
	return {"count": safe_reels, "symbol": symbol, "wild_reel": -1, "wild_cell_index": wild_cell_index, "wild_symbol": wild_symbol, "extra_reel": -1, "extra_count": 0}


func _buffalo_true_win_profile_plan(reel_count: int, format_id: String, rng: RngStream, definition: Dictionary) -> Dictionary:
	var config: Dictionary = _buffalo_config(definition)
	var symbols: Dictionary = _buffalo_symbol_lookup(config)
	var profiles_by_format: Dictionary = _copy_dict(config.get("true_win_profiles", {}))
	var raw_profiles: Array = _dictionary_array(profiles_by_format.get(format_id, []))
	if raw_profiles.is_empty() and reel_count <= 3:
		raw_profiles = _dictionary_array(profiles_by_format.get("classic_3_reel", []))
	elif raw_profiles.is_empty():
		raw_profiles = _dictionary_array(profiles_by_format.get("line_5x3", []))
	var candidates: Array = []
	for profile_value in raw_profiles:
		var profile: Dictionary = profile_value
		var symbol := str(profile.get("symbol", ""))
		if symbol.is_empty() or not symbols.has(symbol):
			continue
		candidates.append(profile.duplicate(true))
	if candidates.is_empty():
		return {}
	var picked: Dictionary = MathScript.weighted_pick(candidates, rng)
	var symbol := str(picked.get("symbol", "BUFFALO"))
	if reel_count <= 3:
		var wild_mode := str(picked.get("wild_mode", "single_2x"))
		var wild_reel := 1 if reel_count >= 2 else -1
		var wild_symbol := "SUNSET_2X"
		var dual_wild := false
		match wild_mode:
			"single_3x":
				wild_symbol = "SUNSET_3X"
			"dual_2x3x":
				wild_symbol = "SUNSET_2X"
				dual_wild = reel_count >= 3
			"none":
				wild_reel = -1
			_:
				wild_symbol = "SUNSET_2X"
		return {
			"count": mini(3, reel_count),
			"symbol": symbol,
			"wild_reel": wild_reel,
			"wild_symbol": wild_symbol,
			"classic_dual_wild": dual_wild,
		}
	var wild_cell_index := -1
	var wild_symbol := ""
	var wild_chance := clampi(int(picked.get("wild_chance", 0)), 0, 100)
	if wild_chance > 0 and rng.randi_range(1, 100) <= wild_chance:
		wild_cell_index = rng.randi_range(0, reel_count - 1)
		wild_symbol = _buffalo_profile_wild_symbol(picked, rng)
	return {
		"count": reel_count,
		"symbol": symbol,
		"wild_reel": -1,
		"wild_cell_index": wild_cell_index,
		"wild_symbol": wild_symbol,
		"extra_reel": -1,
		"extra_count": 0,
	}


func _buffalo_profile_wild_symbol(profile: Dictionary, rng: RngStream) -> String:
	var wild_symbols: Array = _string_array(profile.get("wild_symbols", []))
	if wild_symbols.is_empty():
		wild_symbols = ["SUNSET_2X", "SUNSET_2X", "SUNSET_3X"]
	var wild_symbol := str(wild_symbols[rng.randi_range(0, wild_symbols.size() - 1)])
	if not WILD_SYMBOLS.has(wild_symbol):
		return "SUNSET_2X"
	return wild_symbol


func _stop_ways_extension(grid: Array, cells: Array, symbol: String) -> void:
	if cells.is_empty() or grid.is_empty():
		return
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
		var column: Array = grid[stop_reel] if typeof(grid[stop_reel]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			if str(column[row_index]) == symbol or WILD_SYMBOLS.has(str(column[row_index])):
				column[row_index] = _safe_buffalo_fill_symbol(stop_reel, row_index, symbol)
		grid[stop_reel] = column


func _trim_forced_reel_matches(grid: Array, cells: Array, symbol: String) -> void:
	if cells.is_empty() or symbol.is_empty():
		return
	var keep := {}
	var reel_lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		var row_index := int(cell.get("row", -1))
		if reel_index < 0 or row_index < 0:
			continue
		keep["%d:%d" % [reel_index, row_index]] = true
		reel_lookup[reel_index] = true
	for reel_value in reel_lookup.keys():
		var reel_index := int(reel_value)
		if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if bool(keep.get("%d:%d" % [reel_index, row_index], false)):
				continue
			var current := str(column[row_index])
			if current == symbol or WILD_SYMBOLS.has(current):
				column[row_index] = _safe_buffalo_fill_symbol(reel_index, row_index, symbol)
		grid[reel_index] = column


func _safe_buffalo_fill_symbol(reel_index: int, row_index: int, avoid_symbol: String) -> String:
	var symbol := _buffalo_fill_symbol(reel_index, row_index, reel_index + row_index + 3)
	if symbol == avoid_symbol or WILD_SYMBOLS.has(symbol):
		return "A" if avoid_symbol != "A" else "K"
	return symbol


func _buffalo_fill_symbol(reel_index: int, row_index: int, seed: int) -> String:
	var choices: Array = FILL_REEL_SYMBOLS[posmod(reel_index, FILL_REEL_SYMBOLS.size())]
	var symbol := str(choices[posmod(seed + reel_index * 5 + row_index, choices.size())])
	if symbol == "GOLD_TOKEN":
		return "A" if posmod(reel_index + row_index, 2) == 0 else "K"
	return symbol


func _grid_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return ""
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return ""
	return str(column[row_index])


func _grid_seed(grid: Array) -> int:
	var seed := 0
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			var text := str(column[row_index])
			for char_index in range(text.length()):
				seed = posmod(seed + text.unicode_at(char_index) + reel_index * 19 + row_index * 23, 7919)
	return seed


func _wild_multiplier(symbol: String) -> int:
	if symbol == "SUNSET_3X":
		return 3
	if symbol == "SUNSET_2X":
		return 2
	return 1


func _buffalo_symbol_lookup(config: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for symbol_value in _dictionary_array(config.get("symbols", [])):
		var symbol: Dictionary = symbol_value
		if int(symbol.get("pay3", 0)) > 0:
			result[str(symbol.get("id", ""))] = symbol.duplicate(true)
	if result.is_empty():
		result = {
			"BUFFALO": {"id": "BUFFALO", "pay3": 1, "pay4": 3, "pay5": 8},
			"EAGLE": {"id": "EAGLE", "pay3": 1, "pay4": 2, "pay5": 5},
			"WOLF": {"id": "WOLF", "pay3": 1, "pay4": 2, "pay5": 4},
			"HORSE": {"id": "HORSE", "pay3": 1, "pay4": 2, "pay5": 4},
			"ELK": {"id": "ELK", "pay3": 1, "pay4": 2, "pay5": 3},
			"A": {"id": "A", "pay3": 1, "pay4": 1, "pay5": 2},
			"K": {"id": "K", "pay3": 1, "pay4": 1, "pay5": 2},
			"Q": {"id": "Q", "pay3": 1, "pay4": 1, "pay5": 2},
			"J": {"id": "J", "pay3": 1, "pay4": 1, "pay5": 2},
			"10": {"id": "10", "pay3": 1, "pay4": 1, "pay5": 2},
		}
	return result


func _buffalo_config(definition: Dictionary) -> Dictionary:
	return _copy_dict(definition.get("slot_buffalo_config", {}))


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


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		result.append(str(entry))
	return result


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)
