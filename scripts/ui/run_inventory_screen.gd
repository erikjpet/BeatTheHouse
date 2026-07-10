class_name RunInventoryScreen
extends Control

signal close_requested
signal item_selected(item_id: String, source: String)
signal set_active_requested(item_id: String)
signal sell_requested(item_id: String)
signal repair_requested(item_id: String)
signal place_container_requested(item_id: String)
signal store_item_requested(container_id: String, item_id: String)
signal take_item_requested(container_id: String, item_id: String)

const RUN_INVENTORY_POPUP_SIZE := Vector2(820, 500)
const RUN_INVENTORY_POPUP_MARGIN := 12.0
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")

var _texture_provider: Callable = Callable()
var _model: Dictionary = {}
var _selected_item_id: String = ""
var _selected_item_source: String = ""

var _panel: PanelContainer
var _items_scroll: ScrollContainer
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _title_label: Label
var _summary_label: Label
var _item_grid: GridContainer
var _detail_box: VBoxContainer


func _init() -> void:
	_build()


func configure(texture_provider: Callable) -> void:
	_texture_provider = texture_provider


func open(model: Dictionary) -> void:
	visible = true
	update_model(model)
	move_to_front()
	_position_popup()
	call_deferred("_position_popup")


func update_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	var selected: Dictionary = _model.get("selected", {}) if typeof(_model.get("selected", {})) == TYPE_DICTIONARY else {}
	_selected_item_id = str(selected.get("id", "")).strip_edges()
	_selected_item_source = str(selected.get("source", "carried")).strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_render()
	_position_popup()


func close() -> void:
	visible = false
	if _item_grid != null:
		FoundationWidgets.clear(_item_grid)
	if _panel != null:
		_panel.position = Vector2.ZERO
		_panel.custom_minimum_size = RUN_INVENTORY_POPUP_SIZE
		_panel.size = RUN_INVENTORY_POPUP_SIZE
	_selected_item_id = ""
	_selected_item_source = ""
	_model = {}


func is_open() -> bool:
	return visible


func selected_item_key() -> Dictionary:
	return {
		"id": _selected_item_id,
		"source": _selected_item_source,
	}


func layout_rects() -> Dictionary:
	return {
		"popup_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"grid_rect": _items_scroll.get_global_rect() if _items_scroll != null else Rect2(),
		"detail_rect": _detail_panel.get_global_rect() if _detail_panel != null else Rect2(),
		"screen_rect": get_global_rect(),
	}


func rendered_item_child_count() -> int:
	return _item_grid.get_child_count() if _item_grid != null else 0


func refresh_layout() -> void:
	_position_popup()


func select_item(item_id: String, source: String = "carried", emit_intent: bool = true) -> void:
	_selected_item_id = item_id.strip_edges()
	_selected_item_source = source.strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_model["selected"] = selected_item_key()
	_render()
	_position_popup()
	call_deferred("_position_popup")
	if emit_intent:
		item_selected.emit(_selected_item_id, _selected_item_source)


func _build() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_panel = FoundationWidgets.panel_container(Color("#080817", 0.98), VisualStyle.AMBER)
	_panel.custom_minimum_size = RUN_INVENTORY_POPUP_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	_title_label = FoundationWidgets.label("Inventory", 18)
	FoundationWidgets.set_control_font_color(_title_label, VisualStyle.YELLOW)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close_button := FoundationWidgets.button("Close", Callable(self, "_emit_close_requested"))
	close_button.custom_minimum_size = Vector2(88, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(close_button)

	_summary_label = FoundationWidgets.label("", 12)
	FoundationWidgets.set_control_font_color(_summary_label, VisualStyle.CYAN)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_summary_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)

	_items_scroll = ScrollContainer.new()
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_items_scroll.custom_minimum_size = Vector2(286, 0)
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_stretch_ratio = 0.78
	body.add_child(_items_scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = 2
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 8)
	_item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_items_scroll.add_child(_item_grid)

	_detail_panel = FoundationWidgets.panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	_detail_panel.custom_minimum_size = Vector2(390, 260)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 1.22
	body.add_child(_detail_panel)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail_box)


func _render() -> void:
	if _item_grid == null:
		return
	FoundationWidgets.clear(_item_grid)
	if _detail_box != null:
		FoundationWidgets.clear(_detail_box)
	var mode := _mode()
	var merchant_mode := mode == "merchant_sale"
	if _title_label != null:
		_title_label.text = str(_model.get("title", "Inventory"))
	if _summary_label != null:
		_summary_label.text = str(_model.get("summary", ""))
	_item_grid.columns = _configured_columns()
	var items := _item_array(_model.get("items", []))
	if items.is_empty():
		_item_grid.add_child(FoundationWidgets.muted_label(str(_model.get("empty_text", "No run items yet.")), 13))
		_render_detail({})
		return
	if not _has_selection(items):
		var first_item: Dictionary = items[0]
		_selected_item_id = str(first_item.get("id", ""))
		_selected_item_source = str(first_item.get("storage_source", "carried"))
		if _selected_item_source.is_empty():
			_selected_item_source = "carried"
		_model["selected"] = selected_item_key()
	for item in items:
		_add_item_card(item, merchant_mode)
	_render_detail(_selected_item(items), merchant_mode)


func _add_item_card(item: Dictionary, merchant_mode: bool = false) -> void:
	if _item_grid == null:
		return
	var item_id := str(item.get("id", ""))
	var source := str(item.get("storage_source", "carried"))
	var selected := item_id == _selected_item_id and source == _selected_item_source
	var button_node := FoundationWidgets.button(_grid_button_text(item), Callable(self, "_on_item_button_pressed").bind(item_id, source))
	button_node.custom_minimum_size = Vector2(124, 112)
	button_node.size_flags_horizontal = Control.SIZE_FILL
	button_node.size_flags_vertical = Control.SIZE_FILL
	button_node.tooltip_text = str(item.get("display_name", item_id))
	button_node.icon = _texture_for_item(item)
	if selected:
		FoundationWidgets.style_selected_button(button_node)
	elif merchant_mode and bool(item.get("sellable", false)):
		button_node.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.TEAL, 1))
	_item_grid.add_child(button_node)


func _render_detail(item: Dictionary, merchant_mode: bool = false) -> void:
	if _detail_box == null:
		return
	FoundationWidgets.clear(_detail_box)
	if item.is_empty():
		_detail_box.add_child(FoundationWidgets.muted_label("Select an item to inspect details.", 13))
		return
	var display_name := str(item.get("display_name", item.get("id", "Item")))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = _texture_for_item(item)
	icon.custom_minimum_size = Vector2(54, 54)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var title := FoundationWidgets.label(display_name, 16)
	FoundationWidgets.set_control_font_color(title, VisualStyle.YELLOW)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var source := str(item.get("storage_source", "carried"))
	var location := "Stored" if source == "container" else "Carried"
	FoundationWidgets.add_detail_row(_detail_box, "Where", location)
	FoundationWidgets.add_detail_row(_detail_box, "Type", "%s / %s" % [str(item.get("item_class", "unknown")).capitalize(), str(item.get("domain", "global")).capitalize()])
	_add_attribute_badges(item)
	if item.has("capacity") and int(item.get("capacity", 0)) > 0:
		FoundationWidgets.add_detail_row(_detail_box, "Stores", "%d items" % int(item.get("capacity", 0)))
	var description := str(item.get("description", ""))
	if not description.is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Does", description)
	if merchant_mode:
		if bool(item.get("repairable", false)):
			FoundationWidgets.add_card_button(_detail_box, "Repair for %d" % int(item.get("repair_cost", 0)), Callable(self, "_emit_repair_requested").bind(str(item.get("id", ""))), false, true)
		if bool(item.get("sellable", false)):
			FoundationWidgets.add_card_button(_detail_box, "Sell for %d" % int(item.get("sale_price", 0)), Callable(self, "_emit_sell_requested").bind(str(item.get("id", ""))), false, true)
		elif not bool(item.get("repairable", false)):
			FoundationWidgets.add_detail_row(_detail_box, "Sale", "Cannot sell", true)
		return
	match _mode():
		"place_container":
			FoundationWidgets.add_card_button(_detail_box, "Place at Home", Callable(self, "_emit_place_container_requested").bind(str(item.get("id", ""))), false, true)
		"home_container":
			var container_id := str(_model.get("container_id", ""))
			if source == "container":
				FoundationWidgets.add_card_button(_detail_box, "Move to Inventory", Callable(self, "_emit_take_item_requested").bind(container_id, str(item.get("id", ""))), false, true)
			else:
				FoundationWidgets.add_card_button(_detail_box, "Move to Storage", Callable(self, "_emit_store_item_requested").bind(container_id, str(item.get("id", ""))), false, true)
		_:
			if bool(item.get("active_item", false)):
				var selected := bool(item.get("active_selected", false))
				FoundationWidgets.add_card_button(_detail_box, "Active Item" if selected else "Set Active", Callable(self, "_emit_set_active_requested").bind(str(item.get("id", ""))), selected, selected)
			if bool(item.get("repairable", false)):
				FoundationWidgets.add_detail_row(_detail_box, "Repair", "Shopkeeper", true)
			if bool(item.get("sellable", false)):
				FoundationWidgets.add_detail_row(_detail_box, "Sale", "Merchant", true)
			elif not bool(item.get("repairable", false)):
				FoundationWidgets.add_detail_row(_detail_box, "Sale", "Cannot sell", true)


func _add_attribute_badges(item: Dictionary) -> void:
	var badges := _copy_array(item.get("attribute_badges", []))
	if badges.is_empty():
		return
	AttributeBadgeRowScript.warm_cache(badges, 16)
	_detail_box.add_child(AttributeBadgeRowScript.control_row(badges, 16))


func _position_popup() -> void:
	if _panel == null:
		return
	var overlay_rect := get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var layout: Dictionary = _model.get("layout", {}) if typeof(_model.get("layout", {})) == TYPE_DICTIONARY else {}
	var preferred_size := RUN_INVENTORY_POPUP_SIZE
	var popup_size_value: Variant = layout.get("popup_size", preferred_size)
	if typeof(popup_size_value) == TYPE_VECTOR2:
		preferred_size = popup_size_value
	var available_size := Vector2(
		maxf(1.0, overlay_rect.size.x - RUN_INVENTORY_POPUP_MARGIN * 2.0),
		maxf(1.0, overlay_rect.size.y - RUN_INVENTORY_POPUP_MARGIN * 2.0)
	)
	var popup_size := Vector2(
		minf(preferred_size.x, available_size.x),
		minf(preferred_size.y, available_size.y)
	)
	if _items_scroll != null:
		_items_scroll.custom_minimum_size = Vector2(minf(286.0, maxf(180.0, popup_size.x * 0.34)), 0.0)
	if _item_grid != null:
		_item_grid.columns = 1 if popup_size.x < 700.0 else _configured_columns()
	if _detail_panel != null:
		_detail_panel.custom_minimum_size = Vector2(minf(390.0, maxf(240.0, popup_size.x * 0.48)), minf(260.0, maxf(96.0, popup_size.y * 0.34)))
	_panel.set_deferred("custom_minimum_size", popup_size)
	var centered_position := Vector2(
		floorf((overlay_rect.size.x - popup_size.x) * 0.5),
		floorf((overlay_rect.size.y - popup_size.y) * 0.5)
	)
	_panel.custom_minimum_size = popup_size
	_panel.set_size(popup_size)
	_panel.position = centered_position
	_panel.size = popup_size


func _configured_columns() -> int:
	var layout_value: Variant = _model.get("layout", {})
	if typeof(layout_value) != TYPE_DICTIONARY:
		return 2
	var layout: Dictionary = layout_value
	return maxi(1, int(layout.get("columns", 2)))


func _on_item_button_pressed(item_id: String, source: String) -> void:
	select_item(item_id, source, true)


func _emit_close_requested() -> void:
	close_requested.emit()


func _emit_set_active_requested(item_id: String) -> void:
	set_active_requested.emit(item_id)


func _emit_sell_requested(item_id: String) -> void:
	sell_requested.emit(item_id)


func _emit_repair_requested(item_id: String) -> void:
	repair_requested.emit(item_id)


func _emit_place_container_requested(item_id: String) -> void:
	place_container_requested.emit(item_id)


func _emit_store_item_requested(container_id: String, item_id: String) -> void:
	store_item_requested.emit(container_id, item_id)


func _emit_take_item_requested(container_id: String, item_id: String) -> void:
	take_item_requested.emit(container_id, item_id)


func _texture_for_item(item: Dictionary) -> Texture2D:
	if not _texture_provider.is_valid():
		return null
	return _texture_provider.call(str(item.get("asset_path", ""))) as Texture2D


func _grid_button_text(item: Dictionary) -> String:
	var display_name := str(item.get("display_name", item.get("id", "Item")))
	var prefix := "STORED\n" if str(item.get("storage_source", "carried")) == "container" else ""
	return "%s%s" % [prefix, display_name.left(18)]


func _has_selection(items: Array) -> bool:
	if _selected_item_id.is_empty():
		return false
	for item_value in items:
		var item: Dictionary = item_value
		if str(item.get("id", "")) == _selected_item_id and str(item.get("storage_source", "carried")) == _selected_item_source:
			return true
	return false


func _selected_item(items: Array) -> Dictionary:
	for item_value in items:
		var item: Dictionary = item_value
		if str(item.get("id", "")) == _selected_item_id and str(item.get("storage_source", "carried")) == _selected_item_source:
			return item.duplicate(true)
	return {}


func _item_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_value in value:
		if typeof(item_value) == TYPE_DICTIONARY:
			result.append((item_value as Dictionary).duplicate(true))
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _mode() -> String:
	return str(_model.get("mode", "inspect"))
