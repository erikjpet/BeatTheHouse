extends SceneTree

# Synthetic presentation contracts; the genuine dealer-ace paid-hand path is
# retained separately under BTH-BLACKJACK-INSURANCE-CONTROL-001.
const Blackjack := preload("res://scripts/games/blackjack.gd")

class OfferSurface extends RefCounted:
	var hits: Array = []
	var labels: Array[String] = []
	var hovered_index := -1
	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass
	func surface_label(text: String, _position: Vector2, _size: int, _color: Color) -> void:
		labels.append(text)
	func surface_label_centered(text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		labels.append(text)
	func surface_add_hit(rect: Rect2, action: String, index: int) -> void:
		hits.append({"rect": rect, "action": action, "index": index})
	func surface_region_hovered(action: String, index: int) -> bool:
		return action == "blackjack_side_bet" and index == hovered_index

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var game := Blackjack.new()
	var surface := OfferSurface.new()
	var normal := [{"id": "twenty_one_three", "label": "21+3", "surface_enabled": true}, {"id": "buster", "label": "Buster", "surface_enabled": true}]
	var state := {"side_bets_available": normal, "side_bets_active": [], "side_bet_stakes": {"twenty_one_three": 5, "buster": 5, "insurance": 10}, "can_change_side_bets": true}
	game._draw_side_bet_felt(surface, state)
	_check(surface.hits.size() == 2, "Ordinary two-offer table keeps both controls.")
	if surface.hits.size() == 2:
		_check(surface.hits[0].rect == Rect2(284, 374, 134, 24) and surface.hits[0].index == 0, "Existing first control geometry and index are unchanged.")
		_check(surface.hits[1].rect == Rect2(430, 374, 134, 24) and surface.hits[1].index == 1, "Existing second control geometry and index are unchanged.")
	var insurance := {"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1", "surface_enabled": true}
	state["side_bets_available"] = normal.duplicate(true)
	state["side_bets_available"].append(insurance)
	var before := JSON.stringify(state)
	surface.hits.clear(); surface.labels.clear()
	game._draw_side_bet_felt(surface, state)
	_check(surface.hits.size() == 3, "Conditional Insurance is drawn and registered after both permanent offers.")
	_check(surface.labels.has("Insurance") and surface.labels.has("$10"), "Full existing Insurance label and price remain visible.")
	var panel := Rect2(272, 350, 302, 68)
	if surface.hits.size() == 3:
		for i in range(3):
			_check(surface.hits[i].action == "blackjack_side_bet" and surface.hits[i].index == i, "Compacted controls preserve their provider action/index identity.")
			_check(panel.encloses(surface.hits[i].rect), "Every conditional control stays inside the existing fixed panel.")
			for j in range(i):
				_check(not surface.hits[i].rect.intersects(surface.hits[j].rect), "Conditional button rectangles do not overlap.")
	surface.hovered_index = 2; surface.labels.clear()
	game._draw_side_bet_rule_overlay(surface, state)
	_check(surface.labels.has("SIDE BET RULES") and surface.labels.has("INSURANCE"), "The actual third hover target exposes its existing Insurance rules.")
	_check(JSON.stringify(state) == before, "Rendering and hover never mutate public wager/hand state.")
	for option in state["side_bets_available"]:
		option["surface_enabled"] = option["id"] == "insurance"
	surface.hits.clear()
	game._draw_side_bet_felt(surface, state)
	_check(surface.hits.size() == 1 and surface.hits[0].index == 2, "Mid-hand locked permanent bets leave only legal Insurance interactive.")
	state["side_bets_available"][2]["surface_enabled"] = false
	surface.hits.clear()
	game._draw_side_bet_felt(surface, state)
	_check(surface.hits.is_empty(), "Disabled Insurance never publishes an action.")
	state["side_bets_available"] = []
	surface.hits.clear(); surface.labels.clear()
	game._draw_side_bet_felt(surface, state)
	_check(surface.hits.is_empty() and surface.labels.has("none on this table"), "Zero-offer tables keep their existing empty presentation.")
	_check(game._normalize_side_bets([normal[0], normal[1], {"id": "perfect_pairs", "label": "Perfect Pairs"}]).size() == 2, "Permanent table generation still caps ordinary side bets at two.")
	print("BLACKJACK_INSURANCE_CONTROL_GEOMETRY " + JSON.stringify({"checks": checks, "failures": failures, "fixture": "synthetic existing renderer/control contracts; native paid Insurance path separate"}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
