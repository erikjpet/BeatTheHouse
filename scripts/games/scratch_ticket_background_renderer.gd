class_name ScratchTicketBackgroundRenderer
extends RefCounted

const BACKGROUNDS := {
	"two_fer": preload("res://assets/art/scratch_tickets/layers/two_fer_background_pro.png"),
	"lucky_7s": preload("res://assets/art/scratch_tickets/layers/lucky_7s_background_pro.png"),
	"tic_tac_gold": preload("res://assets/art/scratch_tickets/layers/tic_tac_gold_background_pro.png"),
	"crossword_corner": preload("res://assets/art/scratch_tickets/layers/crossword_corner_background_pro.png"),
	"bonus_bingo": preload("res://assets/art/scratch_tickets/layers/bonus_bingo_background_pro.png"),
	"high_roller_holdem": preload("res://assets/art/scratch_tickets/layers/high_roller_holdem_background_pro.png"),
	"golden_vault": preload("res://assets/art/scratch_tickets/layers/golden_vault_background_pro.png"),
}


static func draw(surface, ticket: Dictionary, ticket_rect: Rect2) -> void:
	if ticket.is_empty():
		return
	var type_id := str(ticket.get("type_id", ""))
	var background: Texture2D = BACKGROUNDS.get(type_id)
	if background == null:
		return
	surface.draw_texture_rect(background, ticket_rect, false)
