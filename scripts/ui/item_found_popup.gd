class_name ItemFoundPopup
extends Control

const DISPLAY_SECONDS := 3.0
const POPUP_SIZE := Vector2(390, 112)
const VIEWPORT_MARGIN := Vector2(18, 18)

var pending_items: Array = []
var current_item: Dictionary = {}

var panel: Panel
var item_icon: TextureRect
var title_label: Label
var body_label: Label
var dismiss_timer: Timer
var attention_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_position_panel()


func show_item(item: Dictionary, texture: Texture2D) -> void:
	if item.is_empty():
		return
	pending_items.append({
		"item": item.duplicate(true),
		"texture": texture,
	})
	if current_item.is_empty():
		_show_next_item()


func clear_all() -> void:
	pending_items.clear()
	current_item = {}
	visible = false
	if dismiss_timer != null:
		dismiss_timer.stop()
	_stop_attention_animation()
	if item_icon != null:
		item_icon.texture = null


func dismiss_current() -> void:
	if dismiss_timer != null:
		dismiss_timer.stop()
	_stop_attention_animation()
	visible = false
	current_item = {}
	if pending_items.is_empty():
		if item_icon != null:
			item_icon.texture = null
		return
	call_deferred("_show_next_item")


func current_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"item_id": str(current_item.get("id", "")),
		"display_name": str(current_item.get("display_name", "")),
		"message": body_label.text if body_label != null else "",
		"presentation": "internal_dialogue",
		"duration_seconds": DISPLAY_SECONDS,
		"remaining_seconds": dismiss_timer.time_left if dismiss_timer != null and not dismiss_timer.is_stopped() else 0.0,
		"queued_count": pending_items.size(),
		"has_item_texture": item_icon != null and item_icon.texture != null,
		"panel_rect": panel.get_global_rect() if panel != null and visible else Rect2(),
		"screen_rect": get_global_rect(),
	}


func _build() -> void:
	panel = FoundationWidgets.panel(Color("#080817", 0.98), VisualStyle.CYAN)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = POPUP_SIZE
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(88, 88)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#060611", 1.0), VisualStyle.YELLOW, 2))
	row.add_child(icon_frame)

	item_icon = TextureRect.new()
	item_icon.custom_minimum_size = Vector2(80, 80)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(item_icon)

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 5)
	copy.custom_minimum_size = Vector2(260, 88)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)

	title_label = FoundationWidgets.label("INNER THOUGHT", 12)
	FoundationWidgets.set_control_font_color(title_label, VisualStyle.YELLOW)
	copy.add_child(title_label)

	body_label = FoundationWidgets.label("", 17)
	body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body_label.max_lines_visible = 1
	body_label.clip_text = true
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(body_label)

	dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	dismiss_timer.wait_time = DISPLAY_SECONDS
	dismiss_timer.timeout.connect(Callable(self, "dismiss_current"))
	add_child(dismiss_timer)


func _show_next_item() -> void:
	if pending_items.is_empty():
		current_item = {}
		visible = false
		return
	var queued: Dictionary = pending_items.pop_front()
	current_item = (queued.get("item", {}) as Dictionary).duplicate(true)
	var item_id := str(current_item.get("id", "")).strip_edges()
	var display_name := str(current_item.get("display_name", item_id.replace("_", " ").capitalize())).strip_edges()
	current_item["id"] = item_id
	current_item["display_name"] = display_name
	item_icon.texture = queued.get("texture") as Texture2D
	body_label.text = "You found the %s item." % display_name
	visible = true
	move_to_front()
	_position_panel()
	dismiss_timer.start(DISPLAY_SECONDS)
	_play_attention_animation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_panel()


func _position_panel() -> void:
	if panel == null:
		return
	var available := Vector2(
		maxf(260.0, size.x - VIEWPORT_MARGIN.x * 2.0),
		maxf(90.0, size.y - VIEWPORT_MARGIN.y * 2.0)
	)
	var target_size := Vector2(minf(POPUP_SIZE.x, available.x), minf(POPUP_SIZE.y, available.y))
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = VIEWPORT_MARGIN.x
	panel.offset_right = VIEWPORT_MARGIN.x + target_size.x
	panel.offset_top = -VIEWPORT_MARGIN.y - target_size.y
	panel.offset_bottom = -VIEWPORT_MARGIN.y


func _play_attention_animation() -> void:
	if panel == null:
		return
	_stop_attention_animation()
	panel.modulate = Color(1.0, 1.0, 1.0, 0.82)
	panel.position.x = VIEWPORT_MARGIN.x - 12.0
	attention_tween = create_tween()
	attention_tween.set_trans(Tween.TRANS_CUBIC)
	attention_tween.set_ease(Tween.EASE_OUT)
	attention_tween.tween_property(panel, "position:x", VIEWPORT_MARGIN.x, 0.14)
	attention_tween.parallel().tween_property(panel, "modulate", Color.WHITE, 0.14)


func _stop_attention_animation() -> void:
	if attention_tween != null and attention_tween.is_valid():
		attention_tween.kill()
	attention_tween = null
	if panel != null:
		panel.modulate = Color.WHITE
