class_name SlotRngMath
extends RefCounted

# Stateless deterministic helpers for slot generation and spin projection.


static func weighted_pick(entries: Array, rng: RngStream) -> Dictionary:
	var normalized: Array = []
	var total := 0
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var weight := maxi(0, int(entry.get("weight", 0)))
		entry["weight"] = weight
		normalized.append(entry)
		total += weight
	if normalized.is_empty():
		return {}
	if total <= 0:
		return (normalized[0] as Dictionary).duplicate(true)
	var roll := rng.randi_range(1, total)
	var running := 0
	for entry_value in normalized:
		var entry: Dictionary = entry_value
		running += maxi(0, int(entry.get("weight", 0)))
		if running >= roll:
			return entry.duplicate(true)
	return (normalized[normalized.size() - 1] as Dictionary).duplicate(true)


static func pick_reel_stops(reel_strips: Array, rng: RngStream) -> Array:
	var stops: Array = []
	for strip_value in reel_strips:
		var strip: Array = _string_array(strip_value)
		if strip.is_empty():
			stops.append(0)
		else:
			stops.append(rng.randi_range(0, strip.size() - 1))
	return stops


static func project_grid(reel_strips: Array, stops: Array, reel_count: int, row_count: int) -> Array:
	var grid: Array = []
	for reel_index in range(maxi(1, reel_count)):
		var strip: Array = []
		if reel_index < reel_strips.size():
			strip = _string_array(reel_strips[reel_index])
		if strip.is_empty():
			strip = ["BLANK"]
		var stop := int(stops[reel_index]) if reel_index < stops.size() else 0
		var column: Array = []
		for row_index in range(maxi(1, row_count)):
			var symbol_index := posmod(stop + row_index, strip.size())
			column.append(str(strip[symbol_index]))
		grid.append(column)
	return grid


static func clone_grid(grid: Array) -> Array:
	var result: Array = []
	for column_value in grid:
		if typeof(column_value) == TYPE_ARRAY:
			result.append((column_value as Array).duplicate(true))
		else:
			result.append([])
	return result


static func count_symbol(grid: Array, symbol_id: String) -> int:
	var total := 0
	for column_value in grid:
		if typeof(column_value) != TYPE_ARRAY:
			continue
		var column: Array = column_value
		for cell in column:
			if str(cell) == symbol_id:
				total += 1
	return total


static func count_symbols(grid: Array, symbol_ids: Array) -> int:
	var lookup := {}
	for symbol in symbol_ids:
		lookup[str(symbol)] = true
	var total := 0
	for column_value in grid:
		if typeof(column_value) != TYPE_ARRAY:
			continue
		var column: Array = column_value
		for cell in column:
			if bool(lookup.get(str(cell), false)):
				total += 1
	return total


static func set_cell(grid: Array, reel_index: int, row_index: int, symbol_id: String) -> void:
	if reel_index < 0 or reel_index >= grid.size():
		return
	if typeof(grid[reel_index]) != TYPE_ARRAY:
		return
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return
	column[row_index] = symbol_id
	grid[reel_index] = column


static func first_cells(reel_count: int, row_count: int, count: int) -> Array:
	var cells: Array = []
	for reel_index in range(maxi(1, reel_count)):
		for row_index in range(maxi(1, row_count)):
			cells.append({"reel": reel_index, "row": row_index})
			if cells.size() >= count:
				return cells
	return cells


static func random_cells(reel_count: int, row_count: int, count: int, rng: RngStream) -> Array:
	var available: Array = first_cells(reel_count, row_count, maxi(1, reel_count) * maxi(1, row_count))
	var result: Array = []
	var target := mini(maxi(0, count), available.size())
	while result.size() < target and not available.is_empty():
		var index := rng.randi_range(0, available.size() - 1)
		result.append((available[index] as Dictionary).duplicate(true))
		available.remove_at(index)
	return result


static func line_cells(reel_count: int, row_count: int, row_index: int = -1) -> Array:
	return line_cells_from(reel_count, row_count, row_index, 0, reel_count)


static func line_cells_from(reel_count: int, row_count: int, row_index: int = -1, start_reel: int = 0, count: int = -1) -> Array:
	var cells: Array = []
	var safe_reels := maxi(1, reel_count)
	var safe_row := clampi(row_index if row_index >= 0 else row_count / 2, 0, maxi(0, row_count - 1))
	var safe_start := clampi(start_reel, 0, safe_reels - 1)
	var target_count := safe_reels - safe_start if count <= 0 else mini(maxi(1, count), safe_reels - safe_start)
	for offset in range(target_count):
		var reel_index := safe_start + offset
		cells.append({"reel": reel_index, "row": safe_row})
	return cells


static func random_line_cells(reel_count: int, row_count: int, count: int, rng: RngStream) -> Array:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var target_count := mini(maxi(1, count), safe_reels)
	var start_reel := rng.randi_range(0, maxi(0, safe_reels - target_count))
	var row := rng.randi_range(0, safe_rows - 1)
	return line_cells_from(safe_reels, safe_rows, row, start_reel, target_count)


static func payline_count(row_count: int) -> int:
	var safe_rows := maxi(1, row_count)
	if safe_rows <= 1:
		return 1
	return safe_rows + 6


static func payline_cells(reel_count: int, row_count: int, line_index: int, count: int = -1) -> Array:
	return payline_cells_from(reel_count, row_count, line_index, 0, count)


static func payline_cells_from(reel_count: int, row_count: int, line_index: int, start_reel: int = 0, count: int = -1) -> Array:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var safe_start := clampi(start_reel, 0, safe_reels - 1)
	var target_count := safe_reels - safe_start if count <= 0 else mini(maxi(1, count), safe_reels - safe_start)
	var rows: Array = _payline_rows(safe_reels, safe_rows, line_index)
	var cells: Array = []
	for offset in range(target_count):
		var reel_index := safe_start + offset
		cells.append({"reel": reel_index, "row": int(rows[reel_index])})
	return cells


static func random_payline_cells(reel_count: int, row_count: int, count: int, rng: RngStream) -> Array:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var target_count := mini(maxi(1, count), safe_reels)
	var start_reel := rng.randi_range(0, maxi(0, safe_reels - target_count))
	var line_index := rng.randi_range(0, payline_count(safe_rows) - 1)
	return payline_cells_from(safe_reels, safe_rows, line_index, start_reel, target_count)


static func grid_to_string(grid: Array) -> String:
	var columns: Array = []
	for column_value in grid:
		columns.append(",".join(_string_array(column_value)))
	return "|".join(columns)


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(str(entry))
	return result


static func _payline_rows(reel_count: int, row_count: int, line_index: int) -> Array:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var rows: Array = []
	if safe_rows <= 1:
		for _reel_index in range(safe_reels):
			rows.append(0)
		return rows
	var normalized_index := posmod(line_index, payline_count(safe_rows))
	if normalized_index < safe_rows:
		for _reel_index in range(safe_reels):
			rows.append(normalized_index)
		return rows
	var pattern := normalized_index - safe_rows
	for reel_index in range(safe_reels):
		var t := 0.0 if safe_reels <= 1 else float(reel_index) / float(safe_reels - 1)
		match pattern:
			0:
				rows.append(clampi(int(round(t * float(safe_rows - 1))), 0, safe_rows - 1))
			1:
				rows.append(clampi(int(round((1.0 - t) * float(safe_rows - 1))), 0, safe_rows - 1))
			2:
				rows.append(clampi(int(round(absf(t * 2.0 - 1.0) * float(safe_rows - 1))), 0, safe_rows - 1))
			3:
				rows.append(clampi(int(round((1.0 - absf(t * 2.0 - 1.0)) * float(safe_rows - 1))), 0, safe_rows - 1))
			4:
				rows.append(0 if reel_index % 2 == 0 else safe_rows - 1)
			_:
				rows.append(safe_rows - 1 if reel_index % 2 == 0 else 0)
	return rows
