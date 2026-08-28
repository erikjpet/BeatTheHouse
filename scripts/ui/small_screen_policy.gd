class_name SmallScreenPolicy
extends RefCounted

# Central sizing contract for the optional phone/tablet interaction mode.
# Keep gameplay and desktop presentation independent from these values so the
# larger-target mode can evolve with the wider 0.5 UI rework.

const CONTROL_TOUCH_TARGET_HEIGHT := 52.0
const MAP_NODE_TOUCH_TARGET_SIZE := 60.0
const SURFACE_TOUCH_HIT_SIZE := Vector2(56.0, 56.0)
const ENVIRONMENT_OBJECT_HIT_SIZE := Vector2(104.0, 76.0)
const ENVIRONMENT_ACTION_HEIGHT := 34.0
const ENVIRONMENT_INLINE_ACTION_HEIGHT := 34.0
const FONT_SCALE := 1.08
const CONTROL_SCALE := 1.30
const SETTINGS_SIDE_MARGIN := 72


static func control_height(base_height: float, enabled: bool) -> float:
	return maxf(base_height, CONTROL_TOUCH_TARGET_HEIGHT) if enabled else base_height


static func map_node_size(enabled: bool) -> Vector2:
	return Vector2.ONE * (MAP_NODE_TOUCH_TARGET_SIZE if enabled else 46.0)


static func surface_hit_size(enabled: bool, desktop_size: Vector2) -> Vector2:
	return Vector2(
		maxf(desktop_size.x, SURFACE_TOUCH_HIT_SIZE.x),
		maxf(desktop_size.y, SURFACE_TOUCH_HIT_SIZE.y)
	) if enabled else desktop_size


static func environment_hit_size(enabled: bool) -> Vector2:
	return ENVIRONMENT_OBJECT_HIT_SIZE if enabled else Vector2.ZERO


static func snapshot(enabled: bool) -> Dictionary:
	return {
		"enabled": enabled,
		"minimum_control_height": CONTROL_TOUCH_TARGET_HEIGHT if enabled else 0.0,
		"map_node_target_size": MAP_NODE_TOUCH_TARGET_SIZE if enabled else 46.0,
		"surface_hit_size": SURFACE_TOUCH_HIT_SIZE if enabled else Vector2(44.0, 44.0),
		"environment_object_hit_size": ENVIRONMENT_OBJECT_HIT_SIZE if enabled else Vector2.ZERO,
		"font_scale": FONT_SCALE if enabled else 1.0,
		"control_scale": CONTROL_SCALE if enabled else 1.0,
	}
