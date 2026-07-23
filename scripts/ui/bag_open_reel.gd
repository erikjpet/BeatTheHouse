class_name BagOpenReel
extends Control

signal close_requested

const PANEL_SIZE := Vector2(1040, 620)
const PANEL_MARGIN := 12.0
const REEL_HEIGHT := 132.0
const SHOWCASE_CARD_SIZE := Vector2(70, 82)

var _texture_provider: Callable = Callable()
var _model: Dictionary = {}
var _sequence: Array = []
var _contents: Array = []
var _texture_cache: Dictionary = {}
var _elapsed_sec := 0.0
var _spin_complete := true
var _small_screen_mode := false
var _reduced_motion := false
var _panel_rect := Rect2()
var _reel_rect := Rect2()
var _showcase_rect := Rect2()
var _landing_rect := Rect2()
var _button: Button


func _init() -> void:
	_build()


func configure(texture_provider: Callable) -> void:
	_texture_provider = texture_provider


func open(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_sequence = _dictionary_array(_model.get("sequence", []))
	_contents = _dictionary_array(_model.get("contents", []))
	_reduced_motion = bool(_model.get("reduce_motion", false))
	_elapsed_sec = float(_model.get("spin_duration_sec", 0.0)) if _reduced_motion else 0.0
	_spin_complete = _reduced_motion or float(_model.get("spin_duration_sec", 0.0)) <= 0.0
	_warm_texture_cache()
	visible = true
	move_to_front()
	_update_button()
	_position_button()
	set_process(not _spin_complete)
	queue_redraw()


func close() -> void:
	visible = false
	_model = {}
	_sequence = []
	_contents = []
	_elapsed_sec = 0.0
	_spin_complete = true
	set_process(false)
	queue_redraw()


func is_open() -> bool:
	return visible


func set_small_screen_mode(enabled: bool) -> void:
	_small_screen_mode = enabled
	_position_button()
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if visible and enabled:
		finish_spin()


func finish_spin() -> void:
	_elapsed_sec = float(_model.get("spin_duration_sec", 0.0))
	_spin_complete = true
	set_process(false)
	_update_button()
	queue_redraw()


func layout_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"component": str(_model.get("component", "")),
		"committed_instance_id": int(_model.get("committed_instance_id", 0)),
		"committed_itemdef_id": int(_model.get("committed_itemdef_id", -1)),
		"landing_itemdef_id": int(_copy_dict(_model.get("committed_item", {})).get("itemdef_id", -1)),
		"landing_index": int(_model.get("landing_index", 0)),
		"sequence_count": _sequence.size(),
		"contents_count": _contents.size(),
		"spin_complete": _spin_complete,
		"reduce_motion": _reduced_motion,
		"small_screen_mode": _small_screen_mode,
		"panel_rect": _panel_rect,
		"reel_rect": _reel_rect,
		"showcase_rect": _showcase_rect,
		"landing_rect": _landing_rect,
		"marker_x": _reel_rect.get_center().x,
	}


func _build() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button = FoundationWidgets.button("Skip", Callable(self, "_on_button_pressed"))
	_button.custom_minimum_size = Vector2(128, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	add_child(_button)


func _process(delta: float) -> void:
	if _spin_complete or not visible:
		return
	_elapsed_sec += maxf(0.0, delta)
	if _elapsed_sec >= float(_model.get("spin_duration_sec", 0.0)):
		finish_spin()
	else:
		queue_redraw()


func _draw() -> void:
	if not visible or _model.is_empty():
		return
	_update_rects()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.68), true)
	draw_rect(_panel_rect, VisualStyle.color("dark_2", VisualStyle.DARK_2), true)
	draw_rect(_panel_rect, VisualStyle.color("amber", VisualStyle.AMBER), false, 2.0)
	_draw_header()
	_draw_reel()
	_draw_result()
	_draw_showcase()
	_position_button()


func _draw_header() -> void:
	var title := "BAG OPENING REEL"
	var subtitle := "%s  •  cosmetic reveal, item already granted" % str(_model.get("bag_display_name", "Collection Bag"))
	_draw_label(title, _panel_rect.position + Vector2(22, 34), 22, VisualStyle.color("yellow", VisualStyle.YELLOW))
	_draw_label(subtitle, _panel_rect.position + Vector2(24, 58), 12, VisualStyle.color("cyan", VisualStyle.CYAN))


func _draw_reel() -> void:
	draw_rect(_reel_rect, Color("#050711"), true)
	draw_rect(_reel_rect, VisualStyle.color("cyan_2", VisualStyle.CYAN_2), false, 2.0)
	var progress := _spin_progress()
	var ease := 1.0 - pow(1.0 - progress, 3.0)
	var start_offset := _reel_rect.size.x * 1.22
	var offset := (1.0 - ease) * start_offset
	var card_width := float(_model.get("card_width", BagOpenReelViewModel.CARD_WIDTH))
	var card_gap := float(_model.get("card_gap", BagOpenReelViewModel.CARD_GAP))
	var step := card_width + card_gap
	var landing_index := int(_model.get("landing_index", BagOpenReelViewModel.LANDING_INDEX))
	var center_x := _reel_rect.get_center().x
	for index in range(_sequence.size()):
		var x := center_x + (float(index - landing_index) * step) + offset - card_width * 0.5
		if x > _reel_rect.end.x or x + card_width < _reel_rect.position.x:
			continue
		var rect := Rect2(Vector2(x, _reel_rect.position.y + 18.0), Vector2(card_width, _reel_rect.size.y - 36.0))
		_draw_item_card(_sequence[index] as Dictionary, rect, bool((_sequence[index] as Dictionary).get("landing", false)) and _spin_complete)
		if index == landing_index:
			_landing_rect = rect
	var marker_x := _reel_rect.get_center().x
	draw_line(Vector2(marker_x, _reel_rect.position.y - 9.0), Vector2(marker_x, _reel_rect.end.y + 9.0), VisualStyle.color("yellow", VisualStyle.YELLOW), 3.0)
	draw_polygon([
		Vector2(marker_x - 9.0, _reel_rect.position.y - 11.0),
		Vector2(marker_x + 9.0, _reel_rect.position.y - 11.0),
		Vector2(marker_x, _reel_rect.position.y + 7.0),
	], [VisualStyle.color("yellow", VisualStyle.YELLOW)])


func _draw_result() -> void:
	var card: Dictionary = _model.get("committed_item", {}) if typeof(_model.get("committed_item", {})) == TYPE_DICTIONARY else {}
	var result_rect := Rect2(_panel_rect.position + Vector2(24, 252), Vector2(_panel_rect.size.x - 48, 64))
	var outline: Color = card.get("outline_color", VisualStyle.color("soft", VisualStyle.SOFT))
	draw_rect(result_rect, Color(outline.r, outline.g, outline.b, 0.14), true)
	draw_rect(result_rect, outline, false, 2.0)
	var prefix := "REVEALED" if _spin_complete else "OPENING"
	_draw_label("%s: %s" % [prefix, str(_model.get("won_display_name", "Collection Item"))], result_rect.position + Vector2(14, 24), 18, VisualStyle.color("white", VisualStyle.WHITE))
	_draw_label("%s rarity  •  %s" % [str(_model.get("won_rarity", "")).to_upper(), str(_model.get("won_condition", "in collection"))], result_rect.position + Vector2(14, 47), 11, outline)


func _draw_showcase() -> void:
	_draw_label("Full possible contents", _showcase_rect.position + Vector2(0, -12), 14, VisualStyle.color("cyan", VisualStyle.CYAN))
	draw_rect(_showcase_rect, Color("#060817"), true)
	draw_rect(_showcase_rect, VisualStyle.color("purple", VisualStyle.PURPLE), false, 1.0)
	var x := _showcase_rect.position.x + 10.0
	var y := _showcase_rect.position.y + 12.0
	var previous_tier := ""
	for index in range(_contents.size()):
		var card: Dictionary = _contents[index]
		var tier := str(card.get("tier", ""))
		if tier != previous_tier and not previous_tier.is_empty():
			x += SHOWCASE_CARD_SIZE.x * 0.35
		if x + SHOWCASE_CARD_SIZE.x > _showcase_rect.end.x - 10.0:
			x = _showcase_rect.position.x + 10.0
			y += SHOWCASE_CARD_SIZE.y + 10.0
		if y + SHOWCASE_CARD_SIZE.y > _showcase_rect.end.y:
			break
		_draw_item_card(card, Rect2(Vector2(x, y), SHOWCASE_CARD_SIZE), false, 8)
		x += SHOWCASE_CARD_SIZE.x + 8.0
		previous_tier = tier


func _draw_item_card(card: Dictionary, rect: Rect2, selected: bool, name_font_size: int = 9) -> void:
	var outline: Color = card.get("outline_color", VisualStyle.color("soft", VisualStyle.SOFT))
	var fill := Color("#0f1228")
	if selected:
		fill = Color(outline.r, outline.g, outline.b, 0.22)
	draw_rect(rect, fill, true)
	draw_rect(rect, outline, false, 3.0 if selected else 2.0)
	var texture := _texture(str(card.get("asset_path", "")))
	var icon_rect := Rect2(rect.position + Vector2(rect.size.x * 0.22, 9.0), Vector2(rect.size.x * 0.56, rect.size.y * 0.42))
	if texture != null:
		draw_texture_rect(texture, icon_rect, false)
	else:
		draw_rect(icon_rect, Color(outline.r, outline.g, outline.b, 0.20), true)
		_draw_label(str(card.get("display_name", "?")).left(2).to_upper(), icon_rect.position + Vector2(5, icon_rect.size.y * 0.60), 14, outline)
	var tier := str(card.get("tier", "")).to_upper()
	_draw_centered(tier, Rect2(rect.position + Vector2(4, rect.size.y - 30), Vector2(rect.size.x - 8, 11)), 8, outline)
	_draw_centered(str(card.get("display_name", "Item")).left(18), Rect2(rect.position + Vector2(4, rect.size.y - 14), Vector2(rect.size.x - 8, 11)), name_font_size, VisualStyle.color("soft", VisualStyle.SOFT))


func _update_rects() -> void:
	var available := Vector2(maxf(1.0, size.x - PANEL_MARGIN * 2.0), maxf(1.0, size.y - PANEL_MARGIN * 2.0))
	var panel_size := Vector2(minf(PANEL_SIZE.x, available.x), minf(PANEL_SIZE.y, available.y))
	_panel_rect = Rect2((size - panel_size) * 0.5, panel_size)
	_reel_rect = Rect2(_panel_rect.position + Vector2(24, 92), Vector2(_panel_rect.size.x - 48, REEL_HEIGHT if not _small_screen_mode else 112.0))
	_showcase_rect = Rect2(_panel_rect.position + Vector2(24, 348 if not _small_screen_mode else 332), Vector2(_panel_rect.size.x - 48, maxf(132.0, _panel_rect.end.y - (_panel_rect.position.y + (348 if not _small_screen_mode else 332)) - 24.0)))


func _position_button() -> void:
	if _button == null:
		return
	_update_rects()
	_button.position = _panel_rect.position + Vector2(_panel_rect.size.x - 154.0, 24.0)
	_button.size = Vector2(128.0, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)


func _spin_progress() -> float:
	var duration := float(_model.get("spin_duration_sec", 0.0))
	if _spin_complete or duration <= 0.0:
		return 1.0
	return clampf(_elapsed_sec / duration, 0.0, 1.0)


func _on_button_pressed() -> void:
	if not _spin_complete:
		finish_spin()
	else:
		close_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if not visible or _spin_complete or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		finish_spin()
		accept_event()


func _update_button() -> void:
	if _button != null:
		_button.text = "Continue" if _spin_complete else "Skip"


func _warm_texture_cache() -> void:
	_texture_cache.clear()
	for card_value in _sequence:
		var path := str((card_value as Dictionary).get("asset_path", ""))
		if not path.is_empty() and not _texture_cache.has(path):
			_texture_cache[path] = _texture(path)
	for card_value in _contents:
		var path := str((card_value as Dictionary).get("asset_path", ""))
		if not path.is_empty() and not _texture_cache.has(path):
			_texture_cache[path] = _texture(path)


func _texture(path: String) -> Texture2D:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return null
	if _texture_cache.has(clean_path):
		return _texture_cache[clean_path] as Texture2D
	if _texture_provider.is_valid():
		var provided: Variant = _texture_provider.call(clean_path)
		return provided as Texture2D if provided is Texture2D else null
	var loaded: Variant = load(clean_path)
	return loaded as Texture2D if loaded is Texture2D else null


func _draw_label(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.70))
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), rect.position + Vector2(1, rect.size.y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(0, 0, 0, 0.70))
	draw_string(get_theme_default_font(), rect.position + Vector2(0, rect.size.y - 1), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
