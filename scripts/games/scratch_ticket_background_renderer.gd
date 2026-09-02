class_name ScratchTicketBackgroundRenderer
extends RefCounted

const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const CROSSWORD_GRID_RECT := Rect2(0.06, 0.32, 0.50, 0.48)
const CROSSWORD_GRID_COLUMNS := 11
const CROSSWORD_GRID_ROWS := 10

const BACKGROUNDS := {
	"two_fer": preload("res://assets/art/scratch_tickets/layers/two_fer_background_pro.png"),
	"lucky_7s": preload("res://assets/art/scratch_tickets/layers/lucky_7s_background_pro.png"),
	"tic_tac_gold": preload("res://assets/art/scratch_tickets/layers/tic_tac_gold_background_pro.png"),
	"crossword_corner": preload("res://assets/art/scratch_tickets/layers/crossword_corner_background_pro.png"),
	"bonus_bingo": preload("res://assets/art/scratch_tickets/layers/bonus_bingo_background_pro.png"),
	"high_roller_holdem": preload("res://assets/art/scratch_tickets/layers/high_roller_holdem_background_pro.png"),
	"golden_vault": preload("res://assets/art/scratch_tickets/layers/golden_vault_background_pro.png"),
}


static func draw(surface, ticket: Dictionary, art_frame: Rect2) -> void:
	if ticket.is_empty():
		return
	var type_id := str(ticket.get("type_id", ""))
	var background: Texture2D = BACKGROUNDS.get(type_id)
	if background == null:
		return
	surface.draw_texture_rect(background, art_frame, false)
	if type_id == "crossword_corner":
		_draw_crossword_grid(surface, ticket, art_frame)


static func _draw_crossword_grid(surface, ticket: Dictionary, art_frame: Rect2) -> void:
	# Keep the authored newspaper illustration and frame, but repaint the puzzle
	# inset from the same region data used by foil, hit testing, and lettering.
	# That makes the denser interlocking layout mechanically impossible to drift.
	var grid := Rect2(
		art_frame.position + CROSSWORD_GRID_RECT.position * art_frame.size,
		CROSSWORD_GRID_RECT.size * art_frame.size
	)
	var cell_size := Vector2(grid.size.x / CROSSWORD_GRID_COLUMNS, grid.size.y / CROSSWORD_GRID_ROWS)
	for row in range(CROSSWORD_GRID_ROWS):
		for column in range(CROSSWORD_GRID_COLUMNS):
			var cell := Rect2(grid.position + Vector2(column, row) * cell_size, cell_size)
			var alternating := Color("#1b292c") if posmod(column + row, 2) == 0 else Color("#172328")
			surface.draw_rect(cell, alternating)
			surface.draw_rect(cell, Color("#4a5657"), false, maxf(0.7, art_frame.size.x / 548.0))
	var regions: Array = ticket.get("scratch_regions", []) as Array
	if regions.is_empty():
		regions = RegionModelScript.layout_template("crossword_corner")
	for region_value in regions:
		var region: Dictionary = region_value
		if str(region.get("section_id", "")) != "crossword":
			continue
		var cell := RegionModelScript.rect_for(region, art_frame, "art_rect")
		surface.draw_rect(cell, Color("#f2eed5"))
		surface.draw_rect(cell.grow(-maxf(0.8, art_frame.size.x / 548.0)), Color("#d9d2ad"), false, maxf(0.7, art_frame.size.x / 548.0))
