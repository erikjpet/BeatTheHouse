class_name EnvironmentArtRenderer
extends Node

# Blend mode belongs to a CanvasItem. Retain one item per consecutive blend run,
# preserving manifest order, then composite
# this opaque background+animation surface below the unchanged counter/object
# drawing. It is requested only by the canvas's existing autonomous cadence.
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const StyleScript := preload("res://scripts/ui/visual_style.gd")
const BOARD := Rect2(0, 0, 900, 430)
var viewport: SubViewport
var texture: Texture2D
var entries: Array[AnimationLayer] = []
var ready_to_present := false


class BackgroundLayer:
	extends Node2D
	var pack: EnvironmentArtPack

	func _draw() -> void:
		draw_rect(BOARD, StyleScript.DARK)
		for y in range(0, 430, 17):
			draw_rect(Rect2(0, y, 900, 17), StyleScript.DARK_2 if (y / 17) % 2 == 0 else StyleScript.DARK_3)
		draw_rect(Rect2(0, 250, 900, 180), Color("#070710"))
		draw_texture_rect(pack.background, pack.background_rect, false)


class AnimationLayer:
	extends Node2D
	var animations: Array[PackScript.AnimationEntry] = []
	var clock := 0.0
	var reduced := false
	var low_detail := false

	func _draw() -> void:
		for entry in animations:
			if (reduced and entry.still_hidden) or (low_detail and not entry.web_low_detail):
				continue
			match entry.kind:
				PackScript.AnimationKind.FRAMES:
					draw_texture_rect_region(entry.texture, entry.rect, entry.frame_regions[entry.frame_at(clock, reduced)], entry.modulation)
				PackScript.AnimationKind.PULSE:
					var color := entry.modulation
					color.a = entry.pulse_at(clock, reduced)
					draw_texture_rect(entry.texture, entry.rect, false, color)
				PackScript.AnimationKind.MOVER:
					if entry.mover_visible_at(clock, reduced):
						_draw_clipped(entry, Rect2(entry.mover_at(clock, reduced), entry.size), entry.frame_regions[entry.frame_at(clock, reduced)], entry.clip if entry.has_clip else BOARD)
				PackScript.AnimationKind.SCROLL:
					var offset := entry.scroll_at(clock, reduced)
					var start := entry.rect.position + offset
					if offset.x > 0.0:
						start.x -= entry.rect.size.x
					if offset.y > 0.0:
						start.y -= entry.rect.size.y
					var y := start.y
					while y < entry.rect.end.y:
						var x := start.x
						while x < entry.rect.end.x:
							_draw_clipped(entry, Rect2(Vector2(x, y), entry.rect.size), entry.frame_regions[0], entry.rect)
							x += entry.rect.size.x
						y += entry.rect.size.y
				PackScript.AnimationKind.SWEEP:
					var beam := entry.sweep_at(clock, reduced) - entry.origin
					draw_set_transform(entry.origin, beam.angle(), Vector2.ONE)
					draw_texture_rect(entry.texture, Rect2(0, -entry.beam_thickness * 0.5, beam.length(), entry.beam_thickness), false, entry.modulation)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_clipped(entry: PackScript.AnimationEntry, destination: Rect2, source: Rect2, bounds: Rect2) -> void:
		var visible_rect := destination.intersection(bounds)
		if visible_rect.has_area():
			var region := Rect2(source.position + (visible_rect.position - destination.position) * 2.0, visible_rect.size * 2.0)
			draw_texture_rect_region(entry.texture, visible_rect, region, entry.modulation)


func configure(pack: EnvironmentArtPack) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1800, 860)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	texture = viewport.get_texture()
	var board := Node2D.new()
	board.scale = Vector2(2, 2)
	viewport.add_child(board)
	var background := BackgroundLayer.new()
	background.pack = pack
	board.add_child(background)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var layer: AnimationLayer
	var previous_additive := false
	for entry in pack.animations:
		if layer == null or previous_additive != entry.additive:
			layer = AnimationLayer.new()
			if entry.additive:
				layer.material = additive
			board.add_child(layer)
			entries.append(layer)
			previous_additive = entry.additive
		layer.animations.append(entry)
	RenderingServer.frame_post_draw.connect(_mark_presented, CONNECT_ONE_SHOT)


func _mark_presented() -> void:
	ready_to_present = true
	# Reduce Motion may need no further idle redraw. Publish the completed
	# initial surface once, independently of input and the animation cadence.
	var canvas := get_parent() as CanvasItem
	if canvas != null:
		canvas.queue_redraw()


func present(clock: float, reduced: bool, low_detail: bool) -> void:
	for layer in entries:
		layer.clock = clock
		layer.reduced = reduced
		layer.low_detail = low_detail
		layer.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
