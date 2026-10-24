extends SceneTree

const Renderer := preload("res://scripts/games/slots/slot_renderer.gd")
const Catalog := preload("res://scripts/games/slots/slot_catalog.gd")

class Surface extends RefCounted:
	var labels: Array[String] = []
	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass
	func surface_label(text: String, _position: Vector2, _size: int, _color: Color) -> void:
		labels.append(text)

class CapturedRenderer extends Renderer:
	var previews := 0
	var buffalo_previews := 0
	func _draw_pinball_playfield(_surface, _rect: Rect2, _state: Dictionary, _active: Dictionary, _accent: Color, _light: Color, _trim: Color, _bucket: int, _feature_msec: int) -> void:
		previews += 1
	func _draw_buffalo_feature(_surface, _rect: Rect2, _state: Dictionary, _definition: Dictionary, _active: Dictionary, _accent: Color, _light: Color, _trim: Color, _bucket: int, _feature_msec: int, _spin_msec: int) -> void:
		buffalo_previews += 1

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var renderer := CapturedRenderer.new()
	var catalog := Catalog.new()
	var surface := Surface.new()
	for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
		var skin: Dictionary = catalog.skin_for_machine({"type_id": "pinball", "format_id": format_id}, {})
		for bonus in [{}, {"active": false, "complete": true, "mode": "full_table", "feature_total": 8}]:
			var state := {"slot_type_id": "pinball", "slot_skin": skin, "slot_active_bonus": bonus, "bankroll": 11, "slot_selected_bet": 2, "rng_state": 12345}
			var original := JSON.stringify(state)
			renderer.previews = 0
			renderer._draw_feature_area(surface, state, {}, skin, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, 0, 0, 0)
			_check(renderer.previews == (0 if format_id == "video_feature" else 1), "Idle/completed %s must reserve overlapping READY panel while retaining separate playfield previews." % format_id)
			surface.labels.clear()
			renderer._draw_status_panel(surface, state, skin, Color.WHITE, Color.WHITE, Color.WHITE)
			_check(surface.labels.has(str(skin.feature_name).to_upper()) and surface.labels.has("READY"), "The actual cabinet feature name and READY must remain visible.")
			_check(JSON.stringify(state) == original, "Rendering must not mutate money, RNG or bonus state.")
		var active_state := {"slot_type_id": "pinball", "slot_active_bonus": {"active": true, "mode": "full_table"}}
		_check(renderer._pinball_takeover_active(active_state), "Active pinball must retain the existing full-screen takeover route.")
	for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
		var buffalo_skin: Dictionary = catalog.skin_for_machine({"type_id": "buffalo", "format_id": format_id}, {})
		for bonus in [{}, {"active": false, "complete": true, "mode": "free_games", "feature_total": 11}]:
			var state := {"slot_type_id": "buffalo", "slot_active_bonus": bonus, "bankroll": 37, "slot_selected_bet": 2, "rng_state": 1491348284}
			var original := JSON.stringify(state)
			renderer.buffalo_previews = 0
			renderer._draw_feature_area(surface, state, {}, buffalo_skin, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, 0, 0, 0)
			_check(renderer.buffalo_previews == (0 if format_id == "video_feature" else 1), "Idle/completed Buffalo %s must reserve overlapping READY panel while retaining separate previews." % format_id)
			surface.labels.clear()
			renderer._draw_status_panel(surface, state, buffalo_skin, Color.WHITE, Color.WHITE, Color.WHITE)
			_check(surface.labels.has(str(buffalo_skin.feature_name).to_upper().left(18)) and surface.labels.has("READY"), "Buffalo's actual feature name and READY must remain visible.")
			_check(JSON.stringify(state) == original, "Buffalo rendering must not mutate money, RNG or completed bonus state.")
		renderer.buffalo_previews = 0
		renderer._draw_feature_area(surface, {"slot_type_id": "buffalo", "slot_active_bonus": {"active": true, "mode": "free_games"}}, {}, buffalo_skin, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, 0, 0, 0)
		_check(renderer.buffalo_previews == 1, "Live Buffalo %s feature drawing must retain its existing route." % format_id)
	print("SLOT_FEATURE_PANEL_OVERLAP_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
