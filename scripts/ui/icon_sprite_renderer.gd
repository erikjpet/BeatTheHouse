class_name IconSpriteRenderer
extends RefCounted

# Renders small pixel sprites from data-authored shape dictionaries. Runtime
# controllers and canvases use this helper so icons and badges are authored as
# data instead of content-id branches inside UI scripts.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const SPRITE_UNIT := 32.0


static func texture(sprite: Dictionary, size: int = 32, accent: Color = VisualStyleScript.CYAN, include_frame: bool = true) -> Texture2D:
	return ImageTexture.create_from_image(image(sprite, size, accent, include_frame))


static func image(sprite: Dictionary, size: int = 32, accent: Color = VisualStyleScript.CYAN, include_frame: bool = true) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if include_frame:
		_draw_image_frame(image, sprite, accent)
	for shape in sprite.get("shapes", []):
		_draw_image_shape(image, shape as Dictionary, accent)
	return image


static func draw_canvas(canvas: CanvasItem, sprite: Dictionary, rect: Rect2, accent: Color = VisualStyleScript.CYAN) -> void:
	for shape in sprite.get("shapes", []):
		_draw_canvas_shape(canvas, shape as Dictionary, rect, accent)


static func _draw_image_frame(image: Image, sprite: Dictionary, accent: Color) -> void:
	var frame: Dictionary = sprite.get("frame", {})
	if frame.is_empty():
		return
	_img_rect(image, 0, 0, image.get_width(), image.get_height(), _color(frame.get("outer", "dark"), accent))
	_img_rect(image, 1, 1, image.get_width() - 2, image.get_height() - 2, _color(frame.get("border", "cyan_2"), accent))
	_img_rect(image, 3, 3, image.get_width() - 6, image.get_height() - 6, _color(frame.get("fill", "dark_3"), accent))


static func _draw_image_shape(image: Image, shape: Dictionary, accent: Color) -> void:
	var scale := float(image.get_width()) / SPRITE_UNIT
	var color := _color(shape.get("color", "accent"), accent)
	match str(shape.get("type", "rect")):
		"circle":
			_img_circle(image, roundi(float(shape.get("cx", 16)) * scale), roundi(float(shape.get("cy", 16)) * scale), roundi(float(shape.get("r", 4)) * scale), color)
		"line":
			_img_line(
				image,
				Vector2i(roundi(float(shape.get("x1", 0)) * scale), roundi(float(shape.get("y1", 0)) * scale)),
				Vector2i(roundi(float(shape.get("x2", 0)) * scale), roundi(float(shape.get("y2", 0)) * scale)),
				maxi(1, roundi(float(shape.get("w", 1)) * scale)),
				color
			)
		_:
			_img_rect(
				image,
				roundi(float(shape.get("x", 0)) * scale),
				roundi(float(shape.get("y", 0)) * scale),
				roundi(float(shape.get("w", 1)) * scale),
				roundi(float(shape.get("h", 1)) * scale),
				color
			)


static func _draw_canvas_shape(canvas: CanvasItem, shape: Dictionary, rect: Rect2, accent: Color) -> void:
	var sx := rect.size.x / SPRITE_UNIT
	var sy := rect.size.y / SPRITE_UNIT
	var color := _color(shape.get("color", "accent"), accent)
	match str(shape.get("type", "rect")):
		"circle":
			var center := rect.position + Vector2(float(shape.get("cx", 16)) * sx, float(shape.get("cy", 16)) * sy)
			canvas.draw_circle(center, float(shape.get("r", 4)) * minf(sx, sy), color)
		"line":
			canvas.draw_line(
				rect.position + Vector2(float(shape.get("x1", 0)) * sx, float(shape.get("y1", 0)) * sy),
				rect.position + Vector2(float(shape.get("x2", 0)) * sx, float(shape.get("y2", 0)) * sy),
				color,
				maxf(1.0, float(shape.get("w", 1)) * minf(sx, sy))
			)
		_:
			canvas.draw_rect(
				Rect2(
					rect.position + Vector2(float(shape.get("x", 0)) * sx, float(shape.get("y", 0)) * sy),
					Vector2(float(shape.get("w", 1)) * sx, float(shape.get("h", 1)) * sy)
				),
				color
			)


static func _color(value: Variant, accent: Color) -> Color:
	if typeof(value) == TYPE_STRING:
		var key := str(value)
		if key == "accent":
			return accent
		return VisualStyleScript.color(key, accent)
	if typeof(value) == TYPE_COLOR:
		return value
	return accent


static func _img_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px in range(x, x + w):
		for py in range(y, y + h):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


static func _img_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for px in range(cx - radius, cx + radius + 1):
		for py in range(cy - radius, cy + radius + 1):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2 and px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


static func _img_line(image: Image, start: Vector2i, end: Vector2i, width: int, color: Color) -> void:
	var delta := end - start
	var steps := maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_img_rect(image, start.x, start.y, width, width, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var point := Vector2i(roundi(lerpf(float(start.x), float(end.x), t)), roundi(lerpf(float(start.y), float(end.y), t)))
		_img_rect(image, point.x - width / 2, point.y - width / 2, width, width, color)
