class_name FoundationWidgets
extends RefCounted

const ACCESSIBILITY_BASE_FONT_META := "accessibility_base_font_size"
const ACCESSIBILITY_BASE_COLOR_META := "accessibility_base_font_color"
const DEFAULT_CONTROL_FONT_SIZE := VisualStyle.TYPE_BODY
const MIN_NATIVE_TOUCH_TARGET_HEIGHT := VisualStyle.TOUCH_TARGET


static func panel_container(fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, VisualStyle.BORDER_HAIRLINE))
	return panel


static func panel(fill: Color, border: Color) -> Panel:
	var panel_node := Panel.new()
	panel_node.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, VisualStyle.BORDER_HAIRLINE))
	return panel_node


static func label(text: String, size: int) -> Label:
	var label_node := Label.new()
	label_node.text = text
	set_control_font_color(label_node, VisualStyle.SOFT)
	set_control_font_size(label_node, size)
	label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label_node


static func muted_label(text: String, size: int) -> Label:
	var label_node := label(text, size)
	set_control_font_color(label_node, VisualStyle.CYAN_2)
	return label_node


static func button(text: String, callback: Callable) -> Button:
	return variant_button(text, callback)


static func variant_button(text: String, callback: Callable, variant: String = "default") -> Button:
	var button_node := Button.new()
	button_node.text = text
	button_node.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_control_font_color(button_node, VisualStyle.role("text_primary"))
	set_control_font_size(button_node, DEFAULT_CONTROL_FONT_SIZE)
	button_node.add_theme_stylebox_override("normal", VisualStyle.state_box("normal", variant))
	button_node.add_theme_stylebox_override("hover", VisualStyle.state_box("hover", variant))
	button_node.add_theme_stylebox_override("focus", VisualStyle.state_box("focus", variant))
	button_node.add_theme_stylebox_override("pressed", VisualStyle.state_box("selected", variant))
	button_node.add_theme_stylebox_override("disabled", VisualStyle.state_box("disabled", variant))
	button_node.pressed.connect(callback)
	return button_node


static func add_detail_row(stack: VBoxContainer, label_text: String, value_text: String, muted: bool = false) -> void:
	var value := value_text.strip_edges()
	if value.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(row)
	var key := muted_label("%s:" % label_text.strip_edges(), VisualStyle.TYPE_CAPTION)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.clip_text = true
	key.custom_minimum_size = Vector2(VisualStyle.SPACE_8 * 3.0, 0)
	key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(key)
	var value_label := muted_label(value, VisualStyle.TYPE_SMALL) if muted else label(value, VisualStyle.TYPE_SMALL)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)


static func add_card_button(stack: VBoxContainer, text: String, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var button_node := button(text, callback)
	button_node.disabled = disabled
	if primary:
		style_selected_button(button_node)
	stack.add_child(button_node)
	return button_node


static func set_control_font_size(control: Control, base_size: int) -> void:
	control.set_meta(ACCESSIBILITY_BASE_FONT_META, base_size)
	control.add_theme_font_size_override("font_size", maxi(8, base_size))


static func set_control_font_color(control: Control, color: Color) -> void:
	control.set_meta(ACCESSIBILITY_BASE_COLOR_META, color)
	control.add_theme_color_override("font_color", VisualStyle.accessible_color(color))


static func style_selected_button(button_node: Button) -> void:
	button_node.add_theme_stylebox_override("normal", VisualStyle.state_box("selected"))
	button_node.add_theme_stylebox_override("hover", VisualStyle.state_box("focus"))
	button_node.add_theme_stylebox_override("pressed", VisualStyle.state_box("armed"))


static func style_focusable(control: Control, selected: bool = false, armed: bool = false) -> void:
	var button_node := control as Button
	if button_node == null:
		return
	button_node.add_theme_stylebox_override("normal", VisualStyle.state_box("armed" if armed else "selected" if selected else "normal"))
	button_node.add_theme_stylebox_override("hover", VisualStyle.state_box("hover"))
	button_node.add_theme_stylebox_override("focus", VisualStyle.state_box("focus"))
	button_node.add_theme_stylebox_override("pressed", VisualStyle.state_box("armed"))


static func stat_chip(icon: Texture2D, label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	row.tooltip_text = "%s: %s" % [label_text, value_text]
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = VisualStyle.ICON_SMALL
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)
	var text := label("%s %s" % [label_text, value_text], VisualStyle.TYPE_SMALL)
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(text)
	return row


static func icon_label_row(icon: Texture2D, text_value: String, muted: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = VisualStyle.ICON_MEDIUM
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)
	var text := muted_label(text_value, VisualStyle.TYPE_BODY) if muted else label(text_value, VisualStyle.TYPE_BODY)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return row


static func tab_bar(entries: Array, selected_id: String, callback: Callable) -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get("id", ""))
		var tab := variant_button(str(entry.get("label", entry_id.capitalize())), callback.bind(entry_id))
		tab.toggle_mode = true
		tab.button_pressed = entry_id == selected_id
		style_focusable(tab, tab.button_pressed)
		tabs.add_child(tab)
	return tabs


static func tooltip(text_value: String) -> PanelContainer:
	var panel_node := panel_container(VisualStyle.role("surface_overlay"), VisualStyle.role("focus"))
	panel_node.custom_minimum_size.x = VisualStyle.TOOLTIP_MAX_WIDTH
	var text := label(text_value, VisualStyle.TYPE_SMALL)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_node.add_child(text)
	return panel_node


static func autosize_popup(panel_node: Control, viewport_size: Vector2, content_minimum: Vector2) -> Vector2:
	var width := clampf(
		content_minimum.x + float(VisualStyle.SPACE_6 * 2),
		VisualStyle.POPUP_MIN_WIDTH,
		minf(VisualStyle.POPUP_MAX_WIDTH, viewport_size.x - float(VisualStyle.SPACE_6 * 2))
	)
	var height := minf(
		content_minimum.y + float(VisualStyle.SPACE_6 * 2),
		viewport_size.y * VisualStyle.POPUP_MAX_HEIGHT_RATIO
	)
	panel_node.custom_minimum_size = Vector2(width, 0)
	panel_node.size = Vector2(width, height)
	return panel_node.size


static func clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
