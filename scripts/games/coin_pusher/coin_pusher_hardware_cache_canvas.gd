extends "res://scripts/ui/game_surface_canvas.gd"

var hardware_renderer: RefCounted
var hardware_state: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# This retained CanvasItem owns only the cabinet hardware command list. Its
	# input regions are intentionally discarded; the production surface keeps
	# registering the same live hit targets on every parent draw.
	hit_regions = []
	if hardware_renderer != null and hardware_renderer.has_method("draw_hardware_cache_layer"):
		hardware_renderer.call("draw_hardware_cache_layer", self, hardware_state)
	hit_regions = []
