extends SceneTree

const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

var activations: Array = []


func _init() -> void:
	var canvas: GameSurfaceCanvas = GameSurfaceCanvasScript.new()
	canvas.surface_action.connect(func(action: String, index: int, confirm_requested: bool) -> void:
		activations.append({"action": action, "index": index, "confirm_requested": confirm_requested})
	)
	canvas.surface_add_exact_hover_hit(Rect2(10, 10, 44, 44), "blackjack_count_icon", 3)
	canvas.call("_set_hovered_surface_region", Vector2(20, 20))
	canvas.call("_set_hovered_surface_region", Vector2(24, 24))
	if activations.size() != 1:
		push_error("Count bubble hover emitted %d activations instead of one while the pointer remained inside." % activations.size())
		canvas.free()
		quit(1)
		return
	var activation: Dictionary = activations[0]
	if str(activation.get("action", "")) != "blackjack_count_icon" or int(activation.get("index", -1)) != 3 or bool(activation.get("confirm_requested", true)):
		push_error("Count bubble hover did not emit the normal blackjack count action contract.")
		canvas.free()
		quit(1)
		return
	canvas.call("_set_hovered_surface_region", Vector2(80, 80))
	canvas.call("_set_hovered_surface_region", Vector2(20, 20))
	if activations.size() != 2:
		push_error("Count bubble did not reactivate after the pointer left and re-entered.")
		canvas.free()
		quit(1)
		return
	print("BLACKJACK_COUNT_HOVER_PROBE_PASS")
	canvas.free()
	quit(0)
