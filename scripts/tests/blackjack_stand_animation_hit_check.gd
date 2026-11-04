extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")

class ActionSurface extends RefCounted:
	var deal_active := true
	var hits: Array[String] = []
	var notices: Array[String] = []
	func surface_animation_active(channel: String) -> bool:
		return deal_active and channel == Blackjack.DEAL_ANIMATION_CHANNEL
	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass
	func surface_label(_text: String, _position: Vector2, _size: int, _color: Color) -> void:
		pass
	func surface_label_centered(text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		notices.append(text)
	func surface_draw_ready_badge(_rect: Rect2, _text: String) -> void:
		pass
	func surface_add_exact_hit(_rect: Rect2, action: String, _index: int) -> void:
		hits.append(action)
	func surface_add_invisible_hit(_rect: Rect2, action: String, _index: int) -> void:
		hits.append(action)
	func surface_region_hovered(_action: String, _index: int) -> bool:
		return false
	func surface_native_action_selected(_action: String) -> bool:
		return false

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var game := Blackjack.new()
	var surface := ActionSurface.new()
	var state := {
		"table_notice": "Cards are out. Play the live hand: hit, stand, double, or split.",
		"deal_animation_id": "synthetic-stand-presentation",
		"deal_animation_events": [{"zone": "player", "delay_msec": 150}],
		"can_hit": true, "can_stand": true, "can_double": true,
		"can_split": true, "can_surrender": true,
		"peek_available": true,
	}
	var original := JSON.stringify(state)
	_check(_draw_notice(game, surface, state).contains("Let the cards finish"), "Opening deal explains why Stand is waiting")
	game._draw_table_actions(surface, state)
	for action in ["blackjack_hit", "blackjack_stand", "blackjack_double", "blackjack_split", "blackjack_surrender"]:
		_check(not surface.hits.has(action), "Deal animation has no lit %s hit" % action)
	_check(surface.hits.has("blackjack_peek"), "Unblocked Peek remains available during deal")
	surface.deal_active = false
	surface.hits.clear()
	_check(_draw_notice(game, surface, state).contains("Play the live hand"), "Finished deal restores original hand prompt")
	game._draw_table_actions(surface, state)
	for action in ["blackjack_hit", "blackjack_stand", "blackjack_double", "blackjack_split", "blackjack_surrender"]:
		_check(surface.hits.has(action), "Finished deal exposes %s once" % action)
	_check(surface.hits.count("blackjack_stand") == 1, "Stand has one hit region after reveal")
	_check(JSON.stringify(state) == original, "Dynamic rendering does not mutate hand or wager state")
	var duel := state.duplicate(true)
	duel["boss_duel_active"] = true
	surface.deal_active = true
	surface.hits.clear()
	game._draw_table_actions(surface, duel)
	_check(not surface.hits.has("blackjack_stand"), "Duel Stand is dim during its deal")
	surface.deal_active = false
	surface.hits.clear()
	game._draw_table_actions(surface, duel)
	_check(surface.hits.has("blackjack_stand"), "Duel Stand returns after reveal")
	print("BLACKJACK_STAND_ANIMATION_HIT_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _draw_notice(game, surface: ActionSurface, state: Dictionary) -> String:
	surface.notices.clear()
	game._draw_blackjack_table_notice(surface, state)
	return surface.notices[0] if not surface.notices.is_empty() else ""

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
