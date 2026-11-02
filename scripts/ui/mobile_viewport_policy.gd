extends RefCounted

# Match the real portrait aspect using a phone-sized logical width. Device pixel
# ratio cancels from the aspect; pointer coordinates remain Godot's responsibility.
# Landscape retains the existing authored canvas and its ordinary letterbox.
const PORTRAIT_WIDTH := 390
const DESKTOP_SIZE := Vector2i(1280, 720)


static func target_size(window_pixels: Vector2i, supported_platform: bool, authored_size: Vector2i = DESKTOP_SIZE) -> Vector2i:
	if not supported_platform or window_pixels.x <= 0 or window_pixels.y <= 0 or window_pixels.x >= window_pixels.y:
		return authored_size
	return Vector2i(PORTRAIT_WIDTH, maxi(PORTRAIT_WIDTH + 1, roundi(float(PORTRAIT_WIDTH) * window_pixels.y / window_pixels.x)))


static func portrait_layout(canvas_size: Vector2) -> bool:
	return canvas_size.x > 0.0 and canvas_size.y > canvas_size.x
