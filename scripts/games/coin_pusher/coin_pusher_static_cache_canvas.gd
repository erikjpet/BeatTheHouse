extends "res://scripts/ui/game_surface_canvas.gd"

signal static_cache_drawn

var static_renderer: RefCounted
var static_state: Dictionary = {}
var static_layer_index := 0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if static_renderer != null and static_renderer.has_method("draw_static_cache_layer"):
		static_renderer.call("draw_static_cache_layer", self, static_state, static_layer_index)
	static_cache_drawn.emit()
