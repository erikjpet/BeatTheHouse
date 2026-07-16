class_name CageWindow
extends Control

signal close_requested
signal buy_chips_requested(amount: int)
signal cash_out_requested
signal review_requested

const POPUP_SIZE := Vector2(760, 460)
const POPUP_MARGIN := 14.0
const PORTRAIT_TEXT_WIDTH := 196.0
const CONTENT_TEXT_WIDTH := 470.0
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")

var _model: Dictionary = {}
var _panel: PanelContainer
var _content_box: VBoxContainer
var _portrait_model: Control
var _portrait_name: Label
var _portrait_line: Label
var _small_screen_mode := false


func _init() -> void:
	_build()


func open(model: Dictionary) -> void:
	visible = true
	update_model(model)
	move_to_front()
	_position_popup()
	call_deferred("_position_popup")
	if _portrait_model != null:
		_portrait_model.call("set_animation_active", true)


func update_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_render()
	_position_popup()


func close() -> void:
	visible = false
	_model = {}
	if _portrait_model != null:
		_portrait_model.call("set_animation_active", false)


func is_open() -> bool:
	return visible


func set_small_screen_mode(enabled: bool) -> void:
	_small_screen_mode = enabled
	_position_popup()


func set_reduce_motion(enabled: bool) -> void:
	if _portrait_model != null:
		_portrait_model.call("set_reduce_motion", enabled)


func current_view_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"model": _model.duplicate(true),
		"popup_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"portrait_animated": bool(_portrait_model.get("animation_active")) if _portrait_model != null else false,
		"small_screen_mode": _small_screen_mode,
	}


func _build() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("#02030a", 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = FoundationWidgets.panel_container(Color("#080817", 0.99), VisualStyle.AMBER)
	_panel.custom_minimum_size = POPUP_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := FoundationWidgets.label("The Cage", 20)
	FoundationWidgets.set_control_font_color(title, VisualStyle.YELLOW)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FoundationWidgets.button("Close", Callable(self, "_emit_close")))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var portrait_panel := FoundationWidgets.panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	portrait_panel.custom_minimum_size = Vector2(220, 360)
	body.add_child(portrait_panel)
	var portrait_stack := VBoxContainer.new()
	portrait_stack.add_theme_constant_override("separation", 4)
	portrait_panel.add_child(portrait_stack)
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(200, 245)
	portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_stack.add_child(portrait_holder)
	_portrait_model = TalkDockScript.create_portrait_model()
	portrait_holder.add_child(_portrait_model)
	_portrait_model.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_name = FoundationWidgets.label("Linda", 17)
	FoundationWidgets.set_control_font_color(_portrait_name, VisualStyle.YELLOW)
	portrait_stack.add_child(_portrait_name)
	_portrait_line = FoundationWidgets.label("", 12)
	_portrait_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portrait_line.custom_minimum_size.x = PORTRAIT_TEXT_WIDTH
	portrait_stack.add_child(_portrait_line)
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 6)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content_box)


func _render() -> void:
	if _content_box == null:
		return
	FoundationWidgets.clear(_content_box)
	var host: Dictionary = _model.get("host", {}) if typeof(_model.get("host", {})) == TYPE_DICTIONARY else {}
	if _portrait_name != null:
		_portrait_name.text = str(host.get("name", "Linda"))
	if _portrait_line != null:
		_portrait_line.text = str(host.get("line", ""))
	if _portrait_model != null:
		_portrait_model.call("set_speaker", host)
	var balance: Dictionary = _model.get("balance", {}) if typeof(_model.get("balance", {})) == TYPE_DICTIONARY else {}
	_content_box.add_child(_section("Chip Window"))
	_content_box.add_child(_content_label("Cash $%d   |   Chips %d   |   Total %d" % [int(balance.get("cash", 0)), int(balance.get("chips", 0)), int(balance.get("total", 0))], 15))
	_content_box.add_child(_content_label("Exchange rate: $%d for 1 chip. Transfers do not affect score spending." % int(balance.get("rate", 1)), 11, true))
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 6)
	for amount_value in _model.get("buy_options", []):
		var amount := int(amount_value)
		buy_row.add_child(FoundationWidgets.button("Buy %d" % amount, Callable(self, "_emit_buy").bind(amount)))
	var cash_out := FoundationWidgets.button("Cash Out All", Callable(self, "_emit_cash_out"))
	cash_out.disabled = not bool(_model.get("can_cash_out", false))
	buy_row.add_child(cash_out)
	_content_box.add_child(buy_row)
	var card: Dictionary = _model.get("card", {}) if typeof(_model.get("card", {})) == TYPE_DICTIONARY else {}
	_content_box.add_child(_section("Players Card - %s" % str(card.get("tier", "Unranked"))))
	_content_box.add_child(_content_label(str(card.get("progress", "")), 12))
	_content_box.add_child(_content_label(str(card.get("benefit", "")), 11, true))
	var review_label := _content_label(str(card.get("review_title", "Review in progress")), 13)
	FoundationWidgets.set_control_font_color(review_label, VisualStyle.CYAN if bool(card.get("can_review", false)) else VisualStyle.ORANGE)
	_content_box.add_child(review_label)
	_content_box.add_child(_content_label(str(card.get("review_detail", "")), 11))
	var review_button := FoundationWidgets.button("Complete Players Card Review", Callable(self, "_emit_review"))
	review_button.disabled = not bool(card.get("can_review", false))
	_content_box.add_child(review_button)
	_content_box.add_child(_section("Promotions / Comps"))
	var promotions: Array = _model.get("promotions", []) if typeof(_model.get("promotions", [])) == TYPE_ARRAY else []
	var promotion_labels: Array[String] = []
	for promotion_value in promotions:
		promotion_labels.append(str(promotion_value))
	_content_box.add_child(_content_label(str(_model.get("promotions_empty", "No promotions available.")), 11, true) if promotion_labels.is_empty() else _content_label(" | ".join(promotion_labels), 11))


func _content_label(text: String, font_size: int, muted: bool = false) -> Label:
	var label := FoundationWidgets.muted_label(text, font_size) if muted else FoundationWidgets.label(text, font_size)
	label.custom_minimum_size.x = CONTENT_TEXT_WIDTH
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _section(text: String) -> Label:
	var label := _content_label(text, 14)
	FoundationWidgets.set_control_font_color(label, VisualStyle.YELLOW)
	return label


func _position_popup() -> void:
	if _panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var popup_size := Vector2(minf(POPUP_SIZE.x, viewport_size.x - POPUP_MARGIN * 2.0), minf(POPUP_SIZE.y, viewport_size.y - POPUP_MARGIN * 2.0))
	var popup_position := (viewport_size - popup_size) * 0.5
	_panel.custom_minimum_size = popup_size
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = popup_position.x
	_panel.offset_top = popup_position.y
	_panel.offset_right = popup_position.x + popup_size.x
	_panel.offset_bottom = popup_position.y + popup_size.y


func _emit_close() -> void:
	close_requested.emit()


func _emit_buy(amount: int) -> void:
	buy_chips_requested.emit(amount)


func _emit_cash_out() -> void:
	cash_out_requested.emit()


func _emit_review() -> void:
	review_requested.emit()
