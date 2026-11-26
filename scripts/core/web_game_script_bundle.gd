extends RefCounted

# The single-threaded Web export compiles these scripts before the title
# becomes interactive. This script retains the cabinet and room resources
# together so traveling and opening machines do not compile them again.
const SCRIPTS := [
	preload("res://scripts/games/scratch_ticket_room_game.gd"),
	preload("res://scripts/games/pull_tab_room_game.gd"),
	preload("res://scripts/games/slots/slot_room_game.gd"),
	preload("res://scripts/games/video_poker_room_source.gd"),
	preload("res://scripts/games/scratch_tickets.gd"),
	preload("res://scripts/games/pull_tabs.gd"),
	preload("res://scripts/games/slot.gd"),
	preload("res://scripts/games/bar_dice.gd"),
	preload("res://scripts/games/blackjack.gd"),
	preload("res://scripts/games/baccarat.gd"),
	preload("res://scripts/games/craps.gd"),
	preload("res://scripts/games/roulette.gd"),
	preload("res://scripts/games/crew_draw_poker.gd"),
	preload("res://scripts/games/video_poker.gd"),
	preload("res://scripts/games/coin_pusher.gd"),
]
