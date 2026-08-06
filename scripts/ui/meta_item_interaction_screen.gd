class_name MetaItemInteractionScreen
extends Control

signal close_requested
signal selection_changed(selection_key: String)
signal action_requested(action_id: String, payload: Dictionary)

const SurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")
const CatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const ItemCardViewModelScript := preload("res://scripts/ui/item_card_view_model.gd")
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")
const POPUP_SIZE := Vector2(980, 600)
const POPUP_MARGIN := 12.0

var _texture_provider: Callable = Callable()
var _model: Dictionary = {}
var _small_screen_mode := false
var _reduced_motion := false

var _panel: PanelContainer
var _body: BoxContainer
var _title_label: Label
var _summary_label: Label
var _surface: InventoryContainerSurface
var _detail_panel: PanelContainer
var _detail_box: VBoxContainer
var _close_button: Button
var _focus_return_target: Control


func _init() -> void:
	_build()


func configure(texture_provider: Callable) -> void:
	_texture_provider = texture_provider
	_surface.configure(texture_provider, CatalogScript.load_catalog())


func open(model: Dictionary) -> void:
	if not visible:
		var focus_owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
		if focus_owner is Control and focus_owner != self and not is_ancestor_of(focus_owner):
			_focus_return_target = focus_owner as Control
	visible = true
	update_model(model)
	move_to_front()
	if not selected_key().is_empty():
		_surface.focus_selection(selected_key(), false)
	else:
		_close_button.grab_focus()
	_position_popup()
	call_deferred("_position_popup")


func update_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_title_label.text = str(_model.get("title", "Inventory"))
	_summary_label.text = str(_model.get("summary", ""))
	_surface.update_model(_model)
	_render_detail()
	_position_popup()


func close() -> void:
	var was_visible := visible
	visible = false
	_model = {}
	_surface.update_model({})
	FoundationWidgets.clear(_detail_box)
	if was_visible:
		call_deferred("_restore_previous_focus")


func _restore_previous_focus() -> void:
	if visible:
		return
	if is_instance_valid(_focus_return_target) and _focus_return_target.visible and _focus_return_target.focus_mode != Control.FOCUS_NONE:
		_focus_return_target.grab_focus()
	_focus_return_target = null


func is_open() -> bool:
	return visible


func selected_key() -> String:
	return _surface.selected_key()


func set_small_screen_mode(enabled: bool) -> void:
	_small_screen_mode = enabled
	_close_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT, enabled)
	_surface.set_small_screen_mode(enabled)
	_position_popup()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_surface.set_reduced_motion(enabled)


func layout_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"mode": str(_model.get("mode", "")),
		"popup_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"screen_rect": get_global_rect(),
		"detail_rect": _detail_panel.get_global_rect() if _detail_panel != null else Rect2(),
		"surface": _surface.layout_snapshot() if _surface != null else {},
		"selected_key": selected_key(),
		"item_count": _dictionary_array(_model.get("items", [])).size(),
		"small_screen_mode": _small_screen_mode,
		"reduced_motion": _reduced_motion,
	}


func _build() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = FoundationWidgets.panel_container(Color("#080817", 0.96), VisualStyle.AMBER)
	_panel.custom_minimum_size = POPUP_SIZE
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
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FoundationWidgets.set_control_font_color(_title_label, VisualStyle.YELLOW)
	header.add_child(_title_label)
	_close_button = FoundationWidgets.button("Close", Callable(self, "_emit_close"))
	_close_button.custom_minimum_size = Vector2(88, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(_close_button)
	_summary_label = FoundationWidgets.label("", 12)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FoundationWidgets.set_control_font_color(_summary_label, VisualStyle.CYAN)
	stack.add_child(_summary_label)
	_body = BoxContainer.new()
	_body.vertical = false
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body)
	_surface = SurfaceScript.new()
	_surface.custom_minimum_size = Vector2(480, 0)
	_surface.size_flags_stretch_ratio = 1.22
	_surface.slot_selected.connect(_on_slot_selected)
	_surface.slot_confirmed.connect(_on_slot_confirmed)
	_body.add_child(_surface)
	_detail_panel = FoundationWidgets.panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	_detail_panel.custom_minimum_size = Vector2(360, 280)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 0.90
	_body.add_child(_detail_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_box)


func _render_detail() -> void:
	FoundationWidgets.clear(_detail_box)
	var item := _surface.item_for_selection(_surface.selected_key())
	if item.is_empty():
		_detail_box.add_child(FoundationWidgets.muted_label(str(_model.get("empty_text", "Select an item.")), 13))
		_add_global_actions()
		return
	var header := HBoxContainer.new()
	var card := ItemCardViewModelScript.build(item)
	header.add_theme_constant_override("separation", 8)
	_detail_box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = _texture(str(item.get("asset_path", "")))
	icon.custom_minimum_size = Vector2(58, 58)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var title := FoundationWidgets.label(str(item.get("display_name", "Item")), 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FoundationWidgets.set_control_font_color(title, VisualStyle.YELLOW)
	header.add_child(title)
	FoundationWidgets.add_detail_row(_detail_box, "Where", str(item.get("storage_source", "stored")).replace("_", " ").capitalize())
	FoundationWidgets.add_detail_row(_detail_box, "Stack", str(card.get("stack_text", "+1")))
	FoundationWidgets.add_detail_row(_detail_box, "Affinity", str(card.get("affinity_label", "General")))
	var detail_badges: Array = card.get("badges", [])
	if not detail_badges.is_empty():
		AttributeBadgeRowScript.warm_cache(detail_badges, 16)
		_detail_box.add_child(AttributeBadgeRowScript.control_row(detail_badges, 16))
	if not str(item.get("collection_display_name", "")).is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Collection", str(item.get("collection_display_name", "")))
	if not str(item.get("tier", "")).is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Tier", str(item.get("tier", "")).capitalize())
	if int(item.get("instance_id", 0)) > 0:
		FoundationWidgets.add_detail_row(_detail_box, "Exact item", "#%d" % int(item.get("instance_id", 0)))
	if not str(item.get("source", "")).is_empty():
		var source_text := str(item.get("source", "")).replace("_", " ").capitalize()
		if not str(item.get("source_id", "")).is_empty():
			source_text += " · %s" % str(item.get("source_id", ""))
		FoundationWidgets.add_detail_row(_detail_box, "Source", source_text)
	var floats: Dictionary = item.get("floats", {}) if typeof(item.get("floats", {})) == TYPE_DICTIONARY else {}
	if not floats.is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Floats", "P %.1f%%  C %.1f%%  R %.1f%%  U %.1f%%" % [float(floats.get("potency", 0.0)) * 100.0, float(floats.get("condition", 0.0)) * 100.0, float(floats.get("resonance", 0.0)) * 100.0, float(floats.get("usage", 0.0)) * 100.0])
		FoundationWidgets.add_detail_row(_detail_box, "Condition", str(item.get("condition_band", "Unknown")))
	var description := str(item.get("description", ""))
	if not description.is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "About", description)
	var disabled_reason := str(item.get("disabled_reason", ""))
	if not disabled_reason.is_empty():
		FoundationWidgets.add_detail_row(_detail_box, "Unavailable", disabled_reason, true)
	if str(_model.get("mode", "")) == "meta_sale" and bool(item.get("sale_eligible", false)):
		_render_sale_breakdown(item)
	for action_value in _dictionary_array(item.get("actions", [])):
		_add_action(action_value)
	_add_global_actions()


func _render_sale_breakdown(item: Dictionary) -> void:
	var quote: Dictionary = item.get("sale_breakdown", {}) if typeof(item.get("sale_breakdown", {})) == TYPE_DICTIONARY else {}
	var final_price := int(item.get("sale_price", quote.get("price", 0)))
	var heading := FoundationWidgets.label("OFFER BREAKDOWN", VisualStyle.TYPE_SMALL)
	FoundationWidgets.set_control_font_color(heading, VisualStyle.role("warning"))
	_detail_box.add_child(heading)
	if quote.has("face_value"):
		FoundationWidgets.add_detail_row(_detail_box, "Face value", "%d gold" % int(quote.get("face_value", 0)))
		FoundationWidgets.add_detail_row(_detail_box, "Fence rate", "%d%%" % int(round(float(quote.get("gold_rate", 0.0)) * 100.0)))
	else:
		FoundationWidgets.add_detail_row(_detail_box, "Tier base", "%d gold" % int(quote.get("tier_base", final_price)))
		FoundationWidgets.add_detail_row(_detail_box, "Exact floats", "%+.0f%%" % ((float(quote.get("rarity_multiplier", 1.0)) - 1.0) * 100.0))
		FoundationWidgets.add_detail_row(_detail_box, "Sal's mode", "%d%%" % int(round(float(quote.get("listing_multiplier", 1.0)) * 100.0)))
	FoundationWidgets.add_detail_row(_detail_box, "Your offer", "%d gold" % final_price)


func _add_global_actions() -> void:
	var trade_summary := _dictionary_array(_model.get("trade_summary", []))
	if not trade_summary.is_empty():
		var heading := FoundationWidgets.label("Trade Inputs", 13)
		FoundationWidgets.set_control_font_color(heading, VisualStyle.CYAN)
		_detail_box.add_child(heading)
		for row in trade_summary:
			FoundationWidgets.add_detail_row(_detail_box, "#%d" % int(row.get("position", 0)), "%s · %s" % [str(row.get("display_name", "Item")), str(row.get("tier", "")).capitalize()])
	for action_value in _dictionary_array(_model.get("global_actions", [])):
		_add_action(action_value)


func _add_action(action: Dictionary) -> void:
	var enabled := bool(action.get("enabled", true))
	var label := str(action.get("label", action.get("id", "Action")))
	if enabled:
		FoundationWidgets.add_card_button(_detail_box, label, Callable(self, "_emit_action").bind(str(action.get("id", "")), _copy_dict(action.get("payload", {}))), false, true)
	else:
		FoundationWidgets.add_detail_row(_detail_box, label, str(action.get("disabled_reason", "Unavailable")), true)


func _on_slot_selected(selection_key: String) -> void:
	_model["selected_key"] = selection_key
	_render_detail()
	selection_changed.emit(selection_key)


func _on_slot_confirmed(selection_key: String) -> void:
	_on_slot_selected(selection_key)


func _emit_action(action_id: String, payload: Dictionary) -> void:
	action_requested.emit(action_id, payload.duplicate(true))


func _emit_close() -> void:
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_requested.emit()
	get_viewport().set_input_as_handled()


func _position_popup() -> void:
	if _panel == null:
		return
	var overlay_rect := get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var available := Vector2(maxf(1.0, overlay_rect.size.x - POPUP_MARGIN * 2.0), maxf(1.0, overlay_rect.size.y - POPUP_MARGIN * 2.0))
	var popup_size := Vector2(minf(POPUP_SIZE.x, available.x), minf(POPUP_SIZE.y, available.y))
	_body.vertical = popup_size.x < 760.0
	_surface.custom_minimum_size = Vector2(minf(480.0, maxf(240.0, popup_size.x * 0.52)), 0.0)
	_detail_panel.custom_minimum_size = Vector2(minf(360.0, maxf(240.0, popup_size.x * 0.40)), minf(280.0, maxf(100.0, popup_size.y * 0.35)))
	_panel.custom_minimum_size = popup_size
	_panel.size = popup_size
	_panel.position = Vector2(floorf((overlay_rect.size.x - popup_size.x) * 0.5), floorf((overlay_rect.size.y - popup_size.y) * 0.5))


func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_provider.is_valid():
		var provided: Variant = _texture_provider.call(path)
		if provided is Texture2D:
			return provided as Texture2D
	var loaded: Variant = load(path)
	return loaded as Texture2D if loaded is Texture2D else null


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
