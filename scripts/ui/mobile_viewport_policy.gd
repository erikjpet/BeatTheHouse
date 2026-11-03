extends RefCounted

# The 0.6 game is authored at 16:9 on every platform and orientation. Keep its
# logical canvas fixed; the Window's kept-aspect stretch owns phone letterboxing
# and pointer coordinates. Portrait UI helpers must not change that contract.
const DESKTOP_SIZE := Vector2i(1280, 720)


static func target_size(_window_pixels: Vector2i, _supported_platform: bool, authored_size: Vector2i = DESKTOP_SIZE) -> Vector2i:
	return authored_size


static func portrait_layout(canvas_size: Vector2) -> bool:
	return canvas_size.x > 0.0 and canvas_size.y > canvas_size.x
