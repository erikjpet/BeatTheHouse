class_name FoundationWidgets
extends RefCounted

const ACCESSIBILITY_BASE_FONT_META := "accessibility_base_font_size"
const ACCESSIBILITY_BASE_COLOR_META := "accessibility_base_font_color"
const DEFAULT_CONTROL_FONT_SIZE := 13
const MIN_NATIVE_TOUCH_TARGET_HEIGHT := 40.0


static func panel_container(fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, 1))
	return panel


static func panel(fill: Color, border: Color) -> Panel:
	var panel_node := Panel.new()
	panel_node.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, 1))
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
	var button_node := Button.new()
	button_node.text = text
	button_node.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_control_font_color(button_node, VisualStyle.WHITE)
	set_control_font_size(button_node, DEFAULT_CONTROL_FONT_SIZE)
	button_node.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.CYAN_2, 1))
	button_node.add_theme_stylebox_override("hover", VisualStyle.pixel_box(VisualStyle.DARK_3, VisualStyle.CYAN, 1))
	button_node.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.YELLOW, 1))
	button_node.add_theme_stylebox_override("disabled", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.SHADOW, 1))
	button_node.pressed.connect(callback)
	return button_node


static func add_detail_row(stack: VBoxContainer, label_text: String, value_text: String, muted: bool = false) -> void:
	var value := value_text.strip_edges()
	if value.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(row)
	var key := muted_label("%s:" % label_text.strip_edges(), 11)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.clip_text = true
	key.custom_minimum_size = Vector2(72, 0)
	key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(key)
	var value_label := muted_label(value, 12) if muted else label(value, 12)
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
	button_node.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.YELLOW, 1))
	button_node.add_theme_stylebox_override("hover", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.AMBER, 1))
	button_node.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.WHITE, 1))


static func clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
