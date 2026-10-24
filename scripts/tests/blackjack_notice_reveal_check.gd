extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")

class NoticeSurface extends RefCounted:
	var active := true
	var labels: Array[String] = []
	func surface_animation_active(channel: String) -> bool:
		return active and channel == Blackjack.DEAL_ANIMATION_CHANNEL
	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass
	func surface_label_centered(text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		labels.append(text)

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var game := Blackjack.new()
	var surface := NoticeSurface.new()
	# Reproduced ordinary hand: player 4C/8H/KH busts while dealer A/2/...
	# is still revealing. Also cover a watched hand, which uses the same notice.
	for summary in ["Dealer 19. H1 busts at 22 (-5). Main -5", "You watch the blackjack hand without wagering. Dealer 19"]:
		var state := {
			"deal_animation_id": "notice-reveal-regression",
			"deal_animation_events": [{"zone": "dealer", "card": {"rank": 6, "suit": "clubs"}, "delay_msec": 1200}],
			"last_result": {"summary": summary},
			"table_notice": summary,
		}
		var original := JSON.stringify(state)
		var pending := _notice(game, surface, state)
		_check(not pending.contains("Dealer 19") and not pending.contains("-5"), "Pending notice must hide final dealer total and settlement.")
		_check(pending.to_lower().contains("settlement follows"), "Pending notice must explain the reveal wait.")
		surface.active = false
		_check(_notice(game, surface, state) == summary.left(78), "Completed reveal must restore the existing summary.")
		surface.active = true
		state["deal_animation_events"] = []
		_check(_notice(game, surface, state) == summary.left(78), "A settled/cold-restored hand with no deal events must show its summary.")
		state["deal_animation_events"] = [{"zone": "dealer", "card": {"rank": 6, "suit": "clubs"}, "delay_msec": 1200}]
		_check(JSON.stringify(state) == original, "Drawing must not mutate the result or deal authority state.")
	_check(_notice(game, surface, {"table_notice": "Choose HIT or STAND."}) == "Choose HIT or STAND.", "An ordinary player decision must retain its notice.")
	_check(_notice(game, surface, {"active_hand_status": "Your turn"}) == "Your turn", "The existing active-hand fallback must remain visible.")
	print("BLACKJACK_NOTICE_REVEAL_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _notice(game, surface: NoticeSurface, state: Dictionary) -> String:
	surface.labels.clear()
	game._draw_blackjack_table_notice(surface, state)
	return surface.labels[0] if not surface.labels.is_empty() else ""

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
