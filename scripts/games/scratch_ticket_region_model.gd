class_name ScratchTicketRegionModel
extends RefCounted

const LAYOUT_VERSION := 6
const CROSSWORD_COLUMNS := 11
const CROSSWORD_ROWS := 10
const CROSSWORD_GRID := [0.06, 0.32, 0.50, 0.48]
const CROSSWORD_BANK := [0.585, 0.42, 0.378, 0.37]


static func build(ticket: Dictionary) -> Array:
	var regions: Array = []
	var spots := _dictionary_array(ticket.get("spots", []))
	match str(ticket.get("type_id", "")):
		"two_fer":
			for index in range(mini(3, spots.size())):
				regions.append(_region(index, spots[index], "play", "SPOT %d" % (index + 1), [0.105 + float(index) * 0.292, 0.495, 0.225, 0.225]))
		"lucky_7s":
			for index in range(mini(2, spots.size())):
				regions.append(_region(index, spots[index], "winning_numbers", "WIN %d" % (index + 1), [0.105, 0.425 + float(index) * 0.145, 0.135, 0.105]))
			for index in range(2, mini(8, spots.size())):
				var your_index := index - 2
				regions.append(_region(index, spots[index], "your_numbers", "YOUR %d" % (your_index + 1), [0.335 + float(your_index % 3) * 0.205, 0.425 + float(your_index / 3) * 0.145, 0.145, 0.105]))
			if spots.size() > 8:
				regions.append(_region(8, spots[8], "bonus", "BONUS", [0.285, 0.755, 0.19, 0.13]))
		"tic_tac_gold":
			for index in range(mini(9, spots.size())):
				regions.append(_region(index, spots[index], "board", "GRID %d" % (index + 1), [0.10 + float(index % 3) * 0.205, 0.42 + float(index / 3) * 0.12, 0.17, 0.10]))
			if spots.size() > 9:
				regions.append(_region(9, spots[9], "bonus", "BONUS", [0.735, 0.505, 0.20, 0.16]))
		"crossword_corner":
			for index in range(spots.size()):
				var spot: Dictionary = spots[index]
				if str(spot.get("role", "")) == "bank_letter":
					var bank_index := int(spot.get("bank_index", index))
					regions.append(_region(index, spot, "letter_bank", "LETTER %d" % (bank_index + 1), _crossword_bank_rect(bank_index)))
				elif str(spot.get("role", "")) == "crossword_cell":
					regions.append(_region(index, spot, "crossword", "GRID %d,%d" % [int(spot.get("column", 0)) + 1, int(spot.get("row", 0)) + 1], _crossword_cell_rect(int(spot.get("column", 0)), int(spot.get("row", 0)))))
		"bonus_bingo":
			for index in range(mini(24, spots.size())):
				regions.append(_region(index, spots[index], "callers", "CALL %d" % (index + 1), [0.175 + float(index % 12) * 0.058, 0.295 + float(index / 12) * 0.065, 0.038, 0.050]))
			for card_index in range(4):
				var origin := Vector2(0.053 + float(card_index) * 0.231, 0.51)
				for cell_index in range(25):
					var spot_index := 24 + card_index * 25 + cell_index
					if spot_index < spots.size():
						regions.append(_region(spot_index, spots[spot_index], "card_%d" % (card_index + 1), "CARD %d-%d" % [card_index + 1, cell_index + 1], [origin.x + float(cell_index % 5) * 0.040, origin.y + float(cell_index / 5) * 0.052, 0.038, 0.050]))
		"high_roller_holdem":
			for index in range(mini(5, spots.size())):
				regions.append(_region(index, spots[index], "your_hand", "YOUR CARD %d" % (index + 1), [0.142 + float(index) * 0.151, 0.338, 0.11, 0.16]))
			for index in range(5, mini(10, spots.size())):
				var card_index := index - 5
				regions.append(_region(index, spots[index], "dealer_hand", "DEALER CARD %d" % (card_index + 1), [0.142 + float(card_index) * 0.151, 0.558, 0.11, 0.145]))
			if spots.size() > 10:
				regions.append(_region(10, spots[10], "wild", "WILD", [0.405, 0.748, 0.19, 0.075]))
		"golden_vault":
			if spots.size() > 0:
				regions.append(_region(0, spots[0], "multiplier", "MULTIPLIER", [0.17, 0.40, 0.66, 0.06]))
			for index in range(1, mini(6, spots.size())):
				regions.append(_region(index, spots[index], "cash_ladder", "RUNG %d" % index, [0.12, 0.51 + float(index - 1) * 0.052, 0.76, 0.043]))
			if spots.size() > 6:
				regions.append(_region(6, spots[6], "gold_bar", "GOLD BAR", [0.11, 0.80, 0.34, 0.07]))
			if spots.size() > 7:
				regions.append(_region(7, spots[7], "final_vault", "FINAL VAULT", [0.55, 0.80, 0.34, 0.07]))
	if regions.is_empty():
		for index in range(spots.size()):
			var spot: Dictionary = spots[index]
			regions.append(_region(index, spot, str(spot.get("section_id", "play")), "SPOT %d" % (index + 1), [0.05, 0.05, 0.90, 0.90]))
	return regions


static func rect_for(region: Dictionary, ticket_rect: Rect2) -> Rect2:
	var values: Array = region.get("rect", []) if typeof(region.get("rect", [])) == TYPE_ARRAY else []
	if values.size() < 4:
		return ticket_rect
	return Rect2(
		ticket_rect.position + Vector2(float(values[0]) * ticket_rect.size.x, float(values[1]) * ticket_rect.size.y),
		Vector2(float(values[2]) * ticket_rect.size.x, float(values[3]) * ticket_rect.size.y)
	)


static func normalized_rect(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 4:
		return [0.0, 0.0, 1.0, 1.0]
	var source: Array = value
	return [
		clampf(float(source[0]), 0.0, 1.0),
		clampf(float(source[1]), 0.0, 1.0),
		clampf(float(source[2]), 0.001, 1.0),
		clampf(float(source[3]), 0.001, 1.0),
	]


static func _region(index: int, spot: Dictionary, section_id: String, label: String, rect_values: Array) -> Dictionary:
	var rect := normalized_rect(rect_values)
	return {
		"id": "%s_%02d" % [section_id, index],
		"layout_version": LAYOUT_VERSION,
		"spot_index": int(spot.get("index", index)),
		"section_id": section_id,
		"label": label,
		"role": str(spot.get("role", "")),
		"rect": rect,
		"art_rect": rect.duplicate(false),
		"sample_total": 0,
		"mask_remaining_units": 0,
		"coverage": 0.0,
		"revealed": false,
	}


static func _crossword_cell_rect(column: int, row: int) -> Array:
	var grid := normalized_rect(CROSSWORD_GRID)
	var cell_width := float(grid[2]) / float(CROSSWORD_COLUMNS)
	var cell_height := float(grid[3]) / float(CROSSWORD_ROWS)
	return [float(grid[0]) + float(column) * cell_width, float(grid[1]) + float(row) * cell_height, cell_width, cell_height]


static func _crossword_bank_rect(index: int) -> Array:
	var bank := normalized_rect(CROSSWORD_BANK)
	var columns := 6
	var rows := 3
	var gap_x := 0.006
	var gap_y := 0.012
	var cell_width := (float(bank[2]) - gap_x * float(columns - 1)) / float(columns)
	var cell_height := (float(bank[3]) - gap_y * float(rows - 1)) / float(rows)
	var column := index % columns
	var row := index / columns
	return [float(bank[0]) + float(column) * (cell_width + gap_x), float(bank[1]) + float(row) * (cell_height + gap_y), cell_width, cell_height]


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result
