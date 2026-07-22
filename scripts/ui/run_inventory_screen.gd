class_name RunInventoryScreen
extends Control

signal close_requested
signal item_selected(item_id: String, source: String)
signal set_active_requested(item_id: String)
signal sell_requested(item_id: String)
signal repair_requested(item_id: String)
signal pawn_requested(lender_id: String, item_id: String)
signal redeem_pawn_requested(lender_id: String, debt_id: String)
signal place_container_requested(item_id: String)
signal store_item_requested(container_id: String, item_id: String)
signal take_item_requested(container_id: String, item_id: String)
signal transfer_item_requested(from_container_id: String, to_container_id: String, item_id: String)

const RUN_INVENTORY_POPUP_SIZE := Vector2(1120, 620)
const RUN_INVENTORY_POPUP_MARGIN := 12.0
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")
const InventoryContainerSurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")
const InventoryContainerCatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")

var _texture_provider: Callable = Callable()
var _model: Dictionary = {}
var _selected_item_id: String = ""
var _selected_item_source: String = ""
var _selected_item_selection_key: String = ""

var _panel: PanelContainer
var _body: BoxContainer
var _inventory_panel: PanelContainer
var _inventory_header_label: Label
var _inventory_hint_label: Label
var _items_scroll: Control
var _container_surface: InventoryContainerSurface
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _title_label: Label
var _summary_label: Label
var _item_grid: GridContainer
var _detail_box: VBoxContainer
var _close_button: Button
var _empty_label: Label
var _small_screen_mode := false
var _reduced_motion := false


func _init() -> void:
	_build()


func configure(texture_provider: Callable) -> void:
	_texture_provider = texture_provider
	if _container_surface != null:
		_container_surface.configure(texture_provider, InventoryContainerCatalogScript.load_catalog())


func set_small_screen_mode(enabled: bool) -> void:
	if _small_screen_mode == enabled:
		return
	_small_screen_mode = enabled
	if _close_button != null:
		_close_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT, enabled)
	if _container_surface != null:
		_container_surface.set_small_screen_mode(enabled)
	_render()
	_position_popup()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _container_surface != null:
		_container_surface.set_reduced_motion(enabled)


func open(model: Dictionary) -> void:
	visible = true
	update_model(model)
	move_to_front()
	if _container_surface != null and not _container_surface.selected_key().is_empty():
		_container_surface.focus_selection(_container_surface.selected_key(), false)
	else:
		_close_button.grab_focus()
	_position_popup()
	call_deferred("_position_popup")


func update_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	var selected: Dictionary = _model.get("selected", {}) if typeof(_model.get("selected", {})) == TYPE_DICTIONARY else {}
	_selected_item_id = str(selected.get("id", "")).strip_edges()
	_selected_item_source = str(selected.get("source", "carried")).strip_edges()
	_selected_item_selection_key = str(_model.get("selected_key", selected.get("selection_key", ""))).strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_render()
	_sync_selection_from_surface()
	_position_popup()


func close() -> void:
	visible = false
	if _container_surface != null:
		_container_surface.update_model({})
	if _panel != null:
		_panel.position = Vector2.ZERO
		_panel.custom_minimum_size = RUN_INVENTORY_POPUP_SIZE
		_panel.size = RUN_INVENTORY_POPUP_SIZE
	_selected_item_id = ""
	_selected_item_source = ""
	_selected_item_selection_key = ""
	_model = {}


func is_open() -> bool:
	return visible


func selected_item_key() -> Dictionary:
	return {
		"id": _selected_item_id,
		"source": _selected_item_source,
		"selection_key": _selected_item_selection_key,
	}


func layout_rects() -> Dictionary:
	var spatial := _container_surface.layout_snapshot() if _container_surface != null else {}
	return {
		"popup_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"grid_rect": spatial.get("stage_rect", _items_scroll.get_global_rect() if _items_scroll != null else Rect2()),
		"detail_rect": _detail_panel.get_global_rect() if _detail_panel != null else Rect2(),
		"empty_text_rect": spatial.get("empty_text_rect", _empty_label.get_global_rect() if _empty_label != null else Rect2()),
		"screen_rect": get_global_rect(),
		"small_screen_mode": _small_screen_mode,
		"reduced_motion": _reduced_motion,
		"minimum_control_height": SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT if _small_screen_mode else FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT,
		"spatial": spatial,
	}


func rendered_item_child_count() -> int:
	return _container_surface.rendered_slot_count() if _container_surface != null else 0


func refresh_layout() -> void:
	_position_popup()


func select_item(item_id: String, source: String = "carried", emit_intent: bool = true) -> void:
	_selected_item_id = item_id.strip_edges()
	_selected_item_source = source.strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_model["selected"] = selected_item_key()
	var key := _selection_key_for_item(_selected_item_id, _selected_item_source)
	_selected_item_selection_key = key
	_model["selected_key"] = key
	if _container_surface != null and not key.is_empty():
		_container_surface.focus_selection(key, false)
	_render_selected_detail()
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
	_close_button = FoundationWidgets.button("Close", Callable(self, "_emit_close_requested"))
	_close_button.custom_minimum_size = Vector2(88, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(_close_button)

	_summary_label = FoundationWidgets.label("", 12)
	FoundationWidgets.set_control_font_color(_summary_label, VisualStyle.CYAN)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_summary_label)

	_body = BoxContainer.new()
	_body.vertical = false
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body)

	_inventory_panel = FoundationWidgets.panel_container(Color("#0b0b18", 0.96), VisualStyle.AMBER)
	_inventory_panel.custom_minimum_size = Vector2(420, 360)
	_inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.size_flags_stretch_ratio = 0.95
	_body.add_child(_inventory_panel)

	var inventory_stack := VBoxContainer.new()
	inventory_stack.add_theme_constant_override("separation", 6)
	inventory_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.add_child(inventory_stack)

	_inventory_header_label = FoundationWidgets.label("Bag Space", 15)
	FoundationWidgets.set_control_font_color(_inventory_header_label, VisualStyle.YELLOW)
	inventory_stack.add_child(_inventory_header_label)

	_inventory_hint_label = FoundationWidgets.muted_label("Click any item in any visible bag. Its actions appear on the right.", 12)
	_inventory_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_stack.add_child(_inventory_hint_label)

	_items_scroll = InventoryContainerSurfaceScript.new()
	_container_surface = _items_scroll as InventoryContainerSurface
	_container_surface.configure(_texture_provider, InventoryContainerCatalogScript.load_catalog())
	_container_surface.slot_selected.connect(_on_surface_slot_selected)
	_container_surface.slot_confirmed.connect(_on_surface_slot_confirmed)
	_items_scroll.custom_minimum_size = Vector2(640, 0)
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_stretch_ratio = 1.45
	inventory_stack.add_child(_items_scroll)

	_detail_panel = FoundationWidgets.panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	_detail_panel.custom_minimum_size = Vector2(520, 260)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 1.25
	_body.add_child(_detail_panel)
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
	if _container_surface == null:
		return
	_empty_label = null
	if _detail_box != null:
		FoundationWidgets.clear(_detail_box)
	var mode := _mode()
	var merchant_mode := mode == "merchant_sale" or mode == "pawn_counter"
	if _title_label != null:
		_title_label.text = str(_model.get("title", "Inventory"))
	if _summary_label != null:
		_summary_label.text = str(_model.get("summary", ""))
	var items := _item_array(_model.get("items", []))
	_container_surface.update_model(_model)
	_update_inventory_header(items)
	if items.is_empty():
		_render_detail({})
		return
	_sync_selection_from_surface()
	_render_detail(_selected_item(items), merchant_mode)
	_apply_small_screen_targets(self)


func _render_selected_detail() -> void:
	if _detail_box == null:
		return
	FoundationWidgets.clear(_detail_box)
	var items := _item_array(_model.get("items", []))
	var merchant_mode := _mode() == "merchant_sale" or _mode() == "pawn_counter"
	_render_detail(_selected_item(items), merchant_mode)


func _update_inventory_header(items: Array) -> void:
	if _inventory_header_label == null or _inventory_hint_label == null:
		return
	var containers := _copy_array(_model.get("containers", []))
	var occupied := items.size()
	var capacity := 0
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		capacity += maxi(0, int(container.get("capacity", 0)))
	var mode := _mode()
	if mode == "home_container":
		_inventory_header_label.text = "Bag Space  -  Carried inventory + all home containers"
		_inventory_hint_label.text = "Pick an item, then use the action panel to take it, store it, or move it directly to another visible container."
	elif mode == "place_container":
		_inventory_header_label.text = "Place Storage  -  carried containers"
		_inventory_hint_label.text = "Choose a bag, backpack, suitcase, or trunk to place at home."
	elif mode == "pawn_counter":
		_inventory_header_label.text = "Pawn Counter  -  inventory and tickets"
		_inventory_hint_label.text = "Choose an item or ticket, then use the action panel to pawn, cash, or redeem it."
	else:
		_inventory_header_label.text = "Full Inventory  -  %d item%s%s" % [occupied, "" if occupied == 1 else "s", " / %d slots" % capacity if capacity > 0 else ""]
		_inventory_hint_label.text = "Choose an item to read what it does and see whether it can be made active, repaired, sold, or stored."


func _sync_selection_from_surface() -> void:
	if _container_surface == null:
		return
	var item := _container_surface.item_for_selection(_container_surface.selected_key())
	if item.is_empty():
		return
	_selected_item_id = str(item.get("id", "")).strip_edges()
	_selected_item_source = str(item.get("storage_source", "carried")).strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_selected_item_selection_key = _container_surface.selected_key()
	_model["selected"] = selected_item_key()
	_model["selected_key"] = _container_surface.selected_key()


func _apply_small_screen_targets(node: Node) -> void:
	if _small_screen_mode:
		var control := node as BaseButton
		if control != null:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT)
	for child in node.get_children():
		_apply_small_screen_targets(child)


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
		_add_section_header("Selected Item")
		_detail_box.add_child(FoundationWidgets.muted_label("Select an icon from Bag Space to inspect it. Actions and transfer destinations will appear here.", 13))
		return
	_add_section_header("Selected Item", "What you picked and where it currently lives.")
	_add_selected_item_header(item)
	FoundationWidgets.add_detail_row(_detail_box, "Where", _item_location_label(item))
	FoundationWidgets.add_detail_row(_detail_box, "Type", "%s / %s" % [str(item.get("item_class", "unknown")).capitalize(), str(item.get("domain", "global")).capitalize()])
	if item.has("capacity") and int(item.get("capacity", 0)) > 0:
		FoundationWidgets.add_detail_row(_detail_box, "Stores", "%d items" % int(item.get("capacity", 0)))
	_add_section_header("What It Does", "Read before you move or equip it.")
	_add_attribute_badges(item)
	_add_collection_float_rows(item)
	var description := str(item.get("description", "")).strip_edges()
	_detail_box.add_child(FoundationWidgets.label(description if not description.is_empty() else "No description is available yet.", 12))
	if _mode() == "pawn_counter":
		_render_pawn_actions(item)
		return
	if merchant_mode:
		_render_merchant_actions(item)
		return
	match _mode():
		"place_container":
			_add_section_header("Action", "Place this carried container into your home.")
			FoundationWidgets.add_card_button(_detail_box, "Place at Home", Callable(self, "_emit_place_container_requested").bind(str(item.get("id", ""))), false, true)
		"home_container":
			_render_home_storage_actions(item)
		_:
			_render_inventory_actions(item)


func _add_selected_item_header(item: Dictionary) -> void:
	var display_name := str(item.get("display_name", item.get("id", "Item")))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(header)
	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", VisualStyle.pixel_box(VisualStyle.DARK_3, VisualStyle.CYAN_2, 1))
	header.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = _texture_for_item(item)
	icon.custom_minimum_size = Vector2(62, 62)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.add_child(icon)
	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 2)
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	var title := FoundationWidgets.label(display_name, 17)
	FoundationWidgets.set_control_font_color(title, VisualStyle.YELLOW)
	title_stack.add_child(title)
	var subtitle := FoundationWidgets.muted_label(_action_summary_for_item(item), 12)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(subtitle)


func _add_section_header(title_text: String, help_text: String = "") -> void:
	var title := FoundationWidgets.label(title_text.to_upper(), 12)
	FoundationWidgets.set_control_font_color(title, VisualStyle.AMBER)
	_detail_box.add_child(title)
	if not help_text.strip_edges().is_empty():
		var help := FoundationWidgets.muted_label(help_text, 11)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(help)


func _add_collection_float_rows(item: Dictionary) -> void:
	var meta_collection: Dictionary = item.get("meta_collection", {}) if typeof(item.get("meta_collection", {})) == TYPE_DICTIONARY else {}
	var floats: Dictionary = meta_collection.get("floats", {}) if typeof(meta_collection.get("floats", {})) == TYPE_DICTIONARY else {}
	if floats.is_empty():
		return
	FoundationWidgets.add_detail_row(_detail_box, "Floats", "P %.1f%%  C %.1f%%  R %.1f%%  U %.1f%%" % [float(floats.get("potency", 0.0)) * 100.0, float(floats.get("condition", 0.0)) * 100.0, float(floats.get("resonance", 0.0)) * 100.0, float(floats.get("usage", 0.0)) * 100.0])
	FoundationWidgets.add_detail_row(_detail_box, "Condition", str(meta_collection.get("condition_band", "unknown")).replace("_", " ").capitalize())


func _render_pawn_actions(item: Dictionary) -> void:
	_add_section_header("Counter Action", "Pawn, cash, or redeem the selected item.")
	var pawn_action := str(item.get("pawn_action", ""))
	if pawn_action == "pawn":
		FoundationWidgets.add_card_button(_detail_box, "Pawn for $%d" % int(item.get("loan_amount", 0)), Callable(self, "_emit_pawn_requested").bind(str(item.get("lender_id", "")), str(item.get("id", ""))), false, true)
	elif pawn_action == "cash_ticket_pile":
		FoundationWidgets.add_detail_row(_detail_box, "Winning value", "$%d" % int(item.get("ticket_face_value", 0)))
		FoundationWidgets.add_card_button(_detail_box, "Cash winners for $%d" % int(item.get("sal_cash_value", 0)), Callable(self, "_emit_pawn_requested").bind(str(item.get("lender_id", "")), str(item.get("id", ""))), false, true)
	elif pawn_action == "redeem":
		var turns := maxi(0, int(item.get("turns_remaining", 0)))
		FoundationWidgets.add_detail_row(_detail_box, "Due", "Now" if turns <= 0 else "%d turn%s" % [turns, "" if turns == 1 else "s"])
		if bool(item.get("pawn_action_enabled", false)):
			FoundationWidgets.add_card_button(_detail_box, "Redeem for $%d" % int(item.get("payoff_amount", 0)), Callable(self, "_emit_redeem_pawn_requested").bind(str(item.get("lender_id", "")), str(item.get("debt_id", ""))), false, true)
		else:
			FoundationWidgets.add_detail_row(_detail_box, "Redeem", str(item.get("disabled_reason", "Unavailable")), true)
	else:
		FoundationWidgets.add_detail_row(_detail_box, "Action", "No pawn action available.", true)


func _render_merchant_actions(item: Dictionary) -> void:
	_add_section_header("Shop Action", "Repair or sell the selected carried item.")
	var any_action := false
	if bool(item.get("repairable", false)):
		FoundationWidgets.add_card_button(_detail_box, "Repair for %d" % int(item.get("repair_cost", 0)), Callable(self, "_emit_repair_requested").bind(str(item.get("id", ""))), false, true)
		any_action = true
	if bool(item.get("sellable", false)):
		FoundationWidgets.add_card_button(_detail_box, "Sell for %d" % int(item.get("sale_price", 0)), Callable(self, "_emit_sell_requested").bind(str(item.get("id", ""))), false, true)
		any_action = true
	if not any_action:
		FoundationWidgets.add_detail_row(_detail_box, "Shop", "This item cannot be repaired or sold here.", true)


func _render_inventory_actions(item: Dictionary) -> void:
	_add_section_header("Actions", "What you can do with this inventory item right now.")
	if bool(item.get("active_item", false)):
		var selected := bool(item.get("active_selected", false))
		FoundationWidgets.add_card_button(_detail_box, "Currently active" if selected else "Set Active", Callable(self, "_emit_set_active_requested").bind(str(item.get("id", ""))), selected, selected)
	else:
		FoundationWidgets.add_detail_row(_detail_box, "Active item", "Passive, stored, or not usable as an active item.", true)
	if bool(item.get("repairable", false)):
		FoundationWidgets.add_detail_row(_detail_box, "Repair", "Visit a shopkeeper.", true)
	if bool(item.get("sellable", false)):
		FoundationWidgets.add_detail_row(_detail_box, "Sale", "Visit a merchant.", true)
	elif not bool(item.get("repairable", false)):
		FoundationWidgets.add_detail_row(_detail_box, "Sale", "Cannot sell.", true)


func _render_home_storage_actions(item: Dictionary) -> void:
	var source := str(item.get("storage_source", "carried"))
	if source == "carried" and bool(item.get("active_item", false)):
		_add_section_header("Use", "Carried active items can still be equipped before you store them.")
		var selected := bool(item.get("active_selected", false))
		FoundationWidgets.add_card_button(_detail_box, "Currently active" if selected else "Set Active", Callable(self, "_emit_set_active_requested").bind(str(item.get("id", ""))), selected, selected)
	_add_section_header("Move Item", _transfer_help_for_item(item))
	var container_id := str(item.get("container_id", _model.get("container_id", "")))
	if bool(item.get("container_read_only", false)) or source == "loadout":
		FoundationWidgets.add_detail_row(_detail_box, "Transfer", str(item.get("disabled_reason", "Packed meta-home items are read-only during this run.")), true)
	elif source == "container":
		FoundationWidgets.add_card_button(_detail_box, "Move to Inventory", Callable(self, "_emit_take_item_requested").bind(container_id, str(item.get("id", ""))), false, true)
		_add_storage_destination_buttons(item, container_id)
	elif bool(item.get("container_full", false)):
		FoundationWidgets.add_detail_row(_detail_box, "Store", "Every available home container is full.", true)
	else:
		_add_storage_destination_buttons(item, "")


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
	var stacked_layout := popup_size.x < 820.0
	if _items_scroll != null:
		_items_scroll.custom_minimum_size = Vector2(0.0, maxf(96.0, popup_size.y * 0.24)) if stacked_layout else Vector2(minf(460.0, maxf(320.0, popup_size.x * 0.38)), 0.0)
	if _body != null:
		_body.vertical = stacked_layout
	if _inventory_panel != null:
		_inventory_panel.custom_minimum_size = Vector2(maxf(240.0, popup_size.x - 16.0), maxf(118.0, popup_size.y * 0.34)) if stacked_layout else Vector2(420.0, 360.0)
	if _detail_panel != null:
		_detail_panel.custom_minimum_size = Vector2(maxf(240.0, popup_size.x - 16.0), maxf(82.0, popup_size.y * 0.22)) if stacked_layout else Vector2(minf(560.0, maxf(480.0, popup_size.x * 0.48)), minf(250.0, maxf(96.0, popup_size.y * 0.34)))
	var minimum_popup_size := _panel.get_combined_minimum_size()
	var final_popup_size := Vector2(
		minf(maxf(popup_size.x, minimum_popup_size.x), overlay_rect.size.x),
		minf(maxf(popup_size.y, minimum_popup_size.y), overlay_rect.size.y)
	)
	var centered_position := Vector2(
		floorf((overlay_rect.size.x - final_popup_size.x) * 0.5),
		floorf((overlay_rect.size.y - final_popup_size.y) * 0.5)
	)
	centered_position.x = clampf(centered_position.x, 0.0, maxf(0.0, overlay_rect.size.x - final_popup_size.x))
	centered_position.y = clampf(centered_position.y, 0.0, maxf(0.0, overlay_rect.size.y - final_popup_size.y))
	_panel.custom_minimum_size = final_popup_size
	_panel.set_size(final_popup_size)
	_panel.position = centered_position
	_panel.size = final_popup_size


func _configured_columns() -> int:
	var layout_value: Variant = _model.get("layout", {})
	if typeof(layout_value) != TYPE_DICTIONARY:
		return 2
	var layout: Dictionary = layout_value
	return maxi(1, int(layout.get("columns", 2)))


func _on_item_button_pressed(item_id: String, source: String) -> void:
	select_item(item_id, source, true)


func _on_surface_slot_selected(selection_key: String) -> void:
	if _container_surface == null:
		return
	var item := _container_surface.item_for_selection(selection_key)
	if item.is_empty():
		return
	_selected_item_id = str(item.get("id", "")).strip_edges()
	_selected_item_source = str(item.get("storage_source", "carried")).strip_edges()
	if _selected_item_source.is_empty():
		_selected_item_source = "carried"
	_selected_item_selection_key = selection_key
	_model["selected"] = selected_item_key()
	_model["selected_key"] = selection_key
	_render_selected_detail()
	item_selected.emit(_selected_item_id, _selected_item_source)


func _on_surface_slot_confirmed(selection_key: String) -> void:
	# A second confirm keeps permanent actions behind their explicit detail button.
	_on_surface_slot_selected(selection_key)


func _emit_close_requested() -> void:
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_requested.emit()
	get_viewport().set_input_as_handled()


func _emit_set_active_requested(item_id: String) -> void:
	set_active_requested.emit(item_id)


func _emit_sell_requested(item_id: String) -> void:
	sell_requested.emit(item_id)


func _emit_repair_requested(item_id: String) -> void:
	repair_requested.emit(item_id)


func _emit_pawn_requested(lender_id: String, item_id: String) -> void:
	pawn_requested.emit(lender_id, item_id)


func _emit_redeem_pawn_requested(lender_id: String, debt_id: String) -> void:
	redeem_pawn_requested.emit(lender_id, debt_id)


func _emit_place_container_requested(item_id: String) -> void:
	place_container_requested.emit(item_id)


func _emit_store_item_requested(container_id: String, item_id: String) -> void:
	store_item_requested.emit(container_id, item_id)


func _emit_take_item_requested(container_id: String, item_id: String) -> void:
	take_item_requested.emit(container_id, item_id)


func _emit_transfer_item_requested(from_container_id: String, to_container_id: String, item_id: String) -> void:
	transfer_item_requested.emit(from_container_id, to_container_id, item_id)


func _item_location_label(item: Dictionary) -> String:
	var source := str(item.get("storage_source", "carried"))
	match source:
		"pawn_ticket":
			return "Pawn ticket"
		"loadout":
			return "Packed loadout"
		"container":
			var container_name := str(item.get("container_display_name", "")).strip_edges()
			return "Stored in %s" % (container_name if not container_name.is_empty() else "home storage")
		_:
			return "Carried inventory"


func _action_summary_for_item(item: Dictionary) -> String:
	var source := str(item.get("storage_source", "carried"))
	if _mode() == "home_container":
		if source == "container":
			return "Stored item: take it with you or move it to another container."
		if source == "loadout":
			return "Packed by your meta-home loadout; visible here but read-only."
		return "Carried item: use it now or store it in a visible container."
	if _mode() == "place_container":
		return "Container item: place it at home to create storage."
	if _mode() == "pawn_counter":
		return "Counter item: review value, due time, and pawn actions."
	if bool(item.get("active_item", false)):
		return "Active-capable item."
	return "Inventory item."


func _transfer_help_for_item(item: Dictionary) -> String:
	var source := str(item.get("storage_source", "carried"))
	if source == "container":
		return "Choose carried inventory, or send it straight to another home container."
	if source == "loadout":
		return "Meta-home loadout items are shown for clarity but cannot be rearranged during this run."
	return "Choose exactly which home container receives this carried item."


func _destination_button_label(prefix: String, destination: Dictionary) -> String:
	var destination_name := str(destination.get("display_name", "Storage"))
	var capacity := int(destination.get("capacity", 0))
	if capacity > 0:
		return "%s %s  (%d/%d)" % [prefix, destination_name, int(destination.get("used", 0)), capacity]
	return "%s %s" % [prefix, destination_name]


func _add_storage_destination_buttons(item: Dictionary, from_container_id: String = "") -> void:
	var destinations := _copy_array(item.get("storage_destinations", []))
	if destinations.is_empty():
		if from_container_id.is_empty():
			var fallback_container_id := str(_model.get("container_id", ""))
			if not fallback_container_id.is_empty():
				FoundationWidgets.add_card_button(_detail_box, "Move to Storage", Callable(self, "_emit_store_item_requested").bind(fallback_container_id, str(item.get("id", ""))), false, true)
		else:
			FoundationWidgets.add_detail_row(_detail_box, "Move", "No other home containers are available.", true)
		return
	var item_id := str(item.get("id", ""))
	var added := 0
	for destination_value in destinations:
		if typeof(destination_value) != TYPE_DICTIONARY:
			continue
		var destination: Dictionary = destination_value
		var destination_id := str(destination.get("container_id", ""))
		if destination_id.is_empty():
			continue
		var destination_name := str(destination.get("display_name", "Storage"))
		if bool(destination.get("read_only", false)):
			FoundationWidgets.add_detail_row(_detail_box, destination_name, "Read-only.", true)
			continue
		if bool(destination.get("full", false)):
			FoundationWidgets.add_detail_row(_detail_box, destination_name, "Full.", true)
			continue
		if from_container_id.is_empty():
			FoundationWidgets.add_card_button(_detail_box, _destination_button_label("Store in", destination), Callable(self, "_emit_store_item_requested").bind(destination_id, item_id), false, true)
		else:
			FoundationWidgets.add_card_button(_detail_box, _destination_button_label("Move to", destination), Callable(self, "_emit_transfer_item_requested").bind(from_container_id, destination_id, item_id), false, true)
		added += 1
	if added == 0 and from_container_id.is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Store", "No open container space.", true)
	elif added == 0:
		FoundationWidgets.add_detail_row(_detail_box, "Move", "No open destination container.", true)


func _texture_for_item(item: Dictionary) -> Texture2D:
	if not _texture_provider.is_valid():
		return null
	return _texture_provider.call(str(item.get("asset_path", ""))) as Texture2D


func _grid_button_text(item: Dictionary) -> String:
	var display_name := str(item.get("display_name", item.get("id", "Item")))
	var source := str(item.get("storage_source", "carried"))
	var prefix := "STORED\n" if source == "container" else "TICKET\n" if source == "pawn_ticket" else ""
	return "%s%s" % [prefix, display_name.left(18)]


func _selection_key_for_item(item_id: String, source: String) -> String:
	for container_value in _model.get("containers", []):
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for slot_value in (container_value as Dictionary).get("slots", []):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var slot: Dictionary = slot_value
			var item: Dictionary = slot.get("item", {}) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}
			if str(item.get("id", "")) == item_id and str(item.get("storage_source", "carried")) == source:
				return str(slot.get("selection_key", ""))
	return "run:%s:%s" % [source, item_id]


func _has_selection(items: Array) -> bool:
	if _selected_item_id.is_empty():
		return false
	if not _selected_item_selection_key.is_empty():
		for item_value in items:
			var keyed_item: Dictionary = item_value
			if str(keyed_item.get("selection_key", "")) == _selected_item_selection_key:
				return true
	for item_value in items:
		var item: Dictionary = item_value
		if str(item.get("id", "")) == _selected_item_id and str(item.get("storage_source", "carried")) == _selected_item_source:
			return true
	return false


func _selected_item(items: Array) -> Dictionary:
	if not _selected_item_selection_key.is_empty():
		for item_value in items:
			var keyed_item: Dictionary = item_value
			if str(keyed_item.get("selection_key", "")) == _selected_item_selection_key:
				return keyed_item.duplicate(true)
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
