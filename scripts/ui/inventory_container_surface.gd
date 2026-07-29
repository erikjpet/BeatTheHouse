class_name InventoryContainerSurface
extends Control

signal slot_hovered(selection_key: String)
signal slot_selected(selection_key: String)
signal slot_confirmed(selection_key: String)
signal container_changed(container_key: String)

const CatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const DEFAULT_STAGE_SIZE := Vector2(350, 350)
const SMALL_SCREEN_PAGE_SIZE := 5

var _texture_provider: Callable = Callable()
var _catalog: Dictionary = {}
var _model: Dictionary = {}
var _containers: Array = []
var _active_container_index := 0
var _active_page_index := 0
var _selected_key := ""
var _hovered_key := ""
var _focused_key := ""
var _reduced_motion := false
var _small_screen_mode := false

var _container_label: Label
var _previous_button: Button
var _next_button: Button
var _stage: Control
var _container_art_layer: Control
var _container_foreground_layer: Control
var _background: TextureRect
var _fallback_panel: Panel
var _slot_layer: Control
var _foreground: TextureRect
var _empty_label: Label
var _container_backgrounds: Array = []
var _container_foregrounds: Array = []
var _container_fallbacks: Array = []
var _container_labels: Array = []
var _container_art_rects: Dictionary = {}
var _slot_buttons: Array = []
var _slot_icons: Array = []
var _slot_markers: Array = []
var _slot_underlines: Array = []
var _slot_name_labels: Array = []
var _slot_count_labels: Array = []
var _slot_group_labels: Array = []
var _slot_models: Array = []
var _slot_rects: Dictionary = {}


func _init() -> void:
	_build()


func configure(texture_provider: Callable, catalog: Dictionary = {}) -> void:
	_texture_provider = texture_provider
	_catalog = catalog.duplicate(true) if not catalog.is_empty() else CatalogScript.load_catalog()
	_render_active_container()


func update_model(model: Dictionary) -> void:
	var previous_hint := _selection_reconciliation_hint()
	var previous_key := _selected_key
	_model = model.duplicate(true)
	_containers = _dictionary_array(_model.get("containers", []))
	if _containers.is_empty():
		_containers = [_legacy_loose_container(_model)]
	_selected_key = str(_model.get("selected_key", _selection_key_from_legacy(_model.get("selected", {})))).strip_edges()
	if not previous_key.is_empty() and not bool(_model.get("focus_explicit", false)) and _selection_location(previous_key).is_empty():
		_selected_key = previous_key
	var requested_container := str(_model.get("active_container_key", "")).strip_edges()
	_active_container_index = _container_index(requested_container)
	if _active_container_index < 0:
		_active_container_index = 0
	_reconcile_selection(previous_hint)
	_render_active_container()


func selected_key() -> String:
	return _selected_key


func focus_selection(selection_key: String, emit_intent: bool = true) -> void:
	var clean_key := selection_key.strip_edges()
	if clean_key.is_empty():
		return
	var location := _selection_location(clean_key)
	if location.is_empty():
		return
	var next_container_index := int(location.get("container_index", _active_container_index))
	var changed_container := next_container_index != _active_container_index
	_active_container_index = next_container_index
	_selected_key = clean_key
	_model["selected_key"] = _selected_key
	if changed_container or _small_screen_mode:
		_render_active_container()
	else:
		_apply_slot_styles()
	_focus_button_for_key(_selected_key)
	if emit_intent:
		slot_selected.emit(_selected_key)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_apply_slot_styles()


func set_small_screen_mode(enabled: bool) -> void:
	if _small_screen_mode == enabled:
		return
	_small_screen_mode = enabled
	_active_page_index = 0
	if _previous_button != null:
		_previous_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT, enabled)
	if _next_button != null:
		_next_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT, enabled)
	_render_active_container()


func set_stage_minimum_size(minimum_size: Vector2) -> void:
	custom_minimum_size = Vector2(maxf(96.0, minimum_size.x), maxf(56.0, minimum_size.y))
	if _stage != null:
		var switcher_allowance := FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT + float(VisualStyle.SPACE_2)
		_stage.custom_minimum_size = Vector2(
			maxf(96.0, minimum_size.x - float(VisualStyle.SPACE_2)),
			maxf(24.0, minimum_size.y - switcher_allowance)
		)
		_layout_slots()


func active_container_key() -> String:
	var container := _active_container()
	return str(container.get("key", ""))


func item_for_selection(selection_key: String) -> Dictionary:
	var location := _selection_location(selection_key)
	if location.is_empty():
		return {}
	var slot: Dictionary = location.get("slot", {})
	return (slot.get("item", {}) as Dictionary).duplicate(true) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}


func rendered_slot_count() -> int:
	return _slot_models.size()


func layout_snapshot() -> Dictionary:
	var slots: Array = []
	for slot_value in _slot_models:
		var slot: Dictionary = slot_value
		var visible_index := slots.size()
		var key := str(slot.get("selection_key", ""))
		var rect: Rect2 = _slot_rects.get(key if not key.is_empty() else "empty:%d" % int(slot.get("slot_index", 0)), Rect2())
		var icon_rect := (_slot_icons[visible_index] as TextureRect).get_global_rect() if visible_index < _slot_icons.size() else Rect2()
		slots.append({
			"slot_index": int(slot.get("slot_index", 0)),
			"selection_key": key,
			"occupied": bool(slot.get("occupied", false)),
			"rect": rect,
			"icon_rect": icon_rect,
			"name_rect": (_slot_name_labels[visible_index] as Label).get_global_rect() if visible_index < _slot_name_labels.size() else Rect2(),
			"count_rect": (_slot_count_labels[visible_index] as Label).get_global_rect() if visible_index < _slot_count_labels.size() else Rect2(),
			"group_rect": (_slot_group_labels[visible_index] as Label).get_global_rect() if visible_index < _slot_group_labels.size() else Rect2(),
			"rarity": str(_copy_dict(slot.get("item", {})).get("tier", "")),
		})
	return {
		"active_container_key": active_container_key(),
		"active_container_type": str(_active_container().get("container_type", "loose_carry")),
		"active_container_capacity": int(_active_container().get("capacity", 0)),
		"active_container_occupied_count": _occupied_slot_count(_active_container()),
		"container_count": _containers.size(),
		"active_page_index": _active_page_index,
		"visible_page_count": _page_count(_active_container()),
		"visible_container_count": _visible_container_indices().size(),
		"container_rects": _container_rect_snapshots(),
		"stage_rect": _stage.get_global_rect() if _stage != null else Rect2(),
		"empty_text_rect": _empty_label.get_global_rect() if _empty_label != null else Rect2(),
		"stable_bounds_signature": "%s|%.1f|%.1f" % [active_container_key(), _stage.size.x if _stage != null else 0.0, _stage.size.y if _stage != null else 0.0],
		"selected_key": _selected_key,
		"hovered_key": _hovered_key,
		"focused_key": _focused_key,
		"multi_selected_keys": _string_array(_model.get("multi_selected_keys", [])),
		"slots": slots,
		"pool_count": _slot_buttons.size(),
		"rendered_slot_count": _slot_models.size(),
		"texture_binding_count": _texture_binding_count(),
		"unique_texture_count": _unique_texture_count(),
		"small_screen_mode": _small_screen_mode,
		"reduced_motion": _reduced_motion,
		"high_contrast": VisualStyle.high_contrast_enabled,
		"item_presentation": "rarity_card_grid" if _grouped_card_mode() else "transparent_cutout",
		"selection_cue": "rarity_outline_card" if _grouped_card_mode() else "underline_and_marker",
	}


func _texture_binding_count() -> int:
	var count := 0
	for background_value in _container_backgrounds:
		var background := background_value as TextureRect
		if background.visible and background.texture != null:
			count += 1
	for foreground_value in _container_foregrounds:
		var foreground := foreground_value as TextureRect
		if foreground.visible and foreground.texture != null:
			count += 1
	for icon_value in _slot_icons:
		var icon := icon_value as TextureRect
		if icon.visible and icon.texture != null:
			count += 1
	return count


func _unique_texture_count() -> int:
	var ids: Dictionary = {}
	for background_value in _container_backgrounds:
		var background := background_value as TextureRect
		if background.visible and background.texture != null:
			ids[background.texture.get_instance_id()] = true
	for foreground_value in _container_foregrounds:
		var foreground := foreground_value as TextureRect
		if foreground.visible and foreground.texture != null:
			ids[foreground.texture.get_instance_id()] = true
	for icon_value in _slot_icons:
		var icon := icon_value as TextureRect
		if icon.visible and icon.texture != null:
			ids[icon.texture.get_instance_id()] = true
	return ids.size()


func _build() -> void:
	custom_minimum_size = DEFAULT_STAGE_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 4)
	add_child(stack)

	var switcher := HBoxContainer.new()
	switcher.add_theme_constant_override("separation", 6)
	stack.add_child(switcher)
	_previous_button = FoundationWidgets.button("<", Callable(self, "_change_container").bind(-1))
	_previous_button.custom_minimum_size = Vector2(42, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	_previous_button.tooltip_text = "Previous container"
	switcher.add_child(_previous_button)
	_container_label = FoundationWidgets.label("Inventory", 13)
	_container_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FoundationWidgets.set_control_font_color(_container_label, VisualStyle.YELLOW)
	switcher.add_child(_container_label)
	_next_button = FoundationWidgets.button(">", Callable(self, "_change_container").bind(1))
	_next_button.custom_minimum_size = Vector2(42, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	_next_button.tooltip_text = "Next container"
	switcher.add_child(_next_button)

	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(310, 300)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	_stage.resized.connect(_layout_slots)
	stack.add_child(_stage)

	_container_art_layer = Control.new()
	_container_art_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container_art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_container_art_layer)

	_fallback_panel = Panel.new()
	_fallback_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.AMBER, 2))
	_fallback_panel.visible = false
	_stage.add_child(_fallback_panel)

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Container plates are authored directly in the shared limited palette; do
	# not apply a second tint that would bury their intentional material cues.
	_background.modulate = Color.WHITE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.visible = false
	_stage.add_child(_background)

	_slot_layer = Control.new()
	_slot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(_slot_layer)

	_foreground = TextureRect.new()
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.visible = false
	_stage.add_child(_foreground)

	_container_foreground_layer = Control.new()
	_container_foreground_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container_foreground_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_container_foreground_layer)

	_empty_label = FoundationWidgets.muted_label("No items here.", 13)
	_empty_label.set_anchors_preset(Control.PRESET_CENTER)
	_empty_label.position = Vector2(-70, -12)
	_empty_label.size = Vector2(140, 24)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_empty_label)


func _render_active_container() -> void:
	if _stage == null:
		return
	_ensure_container_art_pool(_containers.size())
	_container_art_rects.clear()
	_slot_models = []
	var aggregate_used_count := 0
	if _grouped_card_mode():
		_render_grouped_card_container()
		return
	for index in range(_container_backgrounds.size()):
		(_container_backgrounds[index] as TextureRect).visible = false
		(_container_foregrounds[index] as TextureRect).visible = false
		(_container_fallbacks[index] as Panel).visible = false
		(_container_labels[index] as Label).visible = false
	var paged_active_container := _small_screen_mode
	for container_index_value in _visible_container_indices():
		var container_index := int(container_index_value)
		var container: Dictionary = _containers[container_index]
		var container_type := str(container.get("container_type", "loose_carry"))
		var presentation := CatalogScript.presentation(container_type, _catalog)
		var background := _container_backgrounds[container_index] as TextureRect
		var foreground := _container_foregrounds[container_index] as TextureRect
		var fallback := _container_fallbacks[container_index] as Panel
		background.texture = _texture(str(presentation.get("background_path", "")))
		foreground.texture = _texture(str(presentation.get("foreground_path", "")))
		background.visible = true
		foreground.visible = foreground.texture != null
		fallback.visible = background.texture == null
		(_container_labels[container_index] as Label).visible = true
		var all_slots := _normalized_slots(container)
		var page_size := _page_size(all_slots.size()) if paged_active_container else maxi(1, all_slots.size())
		var page_count := maxi(1, int(ceil(float(all_slots.size()) / float(page_size))))
		if paged_active_container and not _selected_key.is_empty():
			for slot_index in range(all_slots.size()):
				if str((all_slots[slot_index] as Dictionary).get("selection_key", "")) == _selected_key:
					_active_page_index = slot_index / page_size
					break
		var page_index := clampi(_active_page_index, 0, page_count - 1) if paged_active_container else 0
		if paged_active_container:
			_active_page_index = page_index
		var visible_slots := all_slots.slice(page_index * page_size, mini(all_slots.size(), (page_index + 1) * page_size))
		for slot_index in range(visible_slots.size()):
			var slot: Dictionary = visible_slots[slot_index]
			slot["container_index"] = container_index
			slot["container_key"] = str(container.get("key", ""))
			slot["presentation_slot_index"] = page_index * page_size + slot_index
			_slot_models.append(slot)
		for slot_value in all_slots:
			if bool((slot_value as Dictionary).get("occupied", false)):
				aggregate_used_count += 1
	_ensure_slot_pool(_slot_models.size())
	for index in range(_slot_buttons.size()):
		var button := _slot_buttons[index] as Button
		button.visible = index < _slot_models.size()
		(_slot_icons[index] as TextureRect).visible = button.visible
		(_slot_markers[index] as Label).visible = button.visible
		(_slot_underlines[index] as ColorRect).visible = false
		(_slot_name_labels[index] as Label).visible = false
		(_slot_count_labels[index] as Label).visible = false
		(_slot_group_labels[index] as Label).visible = false
		if not button.visible:
			continue
		var slot: Dictionary = _slot_models[index]
		var occupied := bool(slot.get("occupied", false))
		var item: Dictionary = slot.get("item", {}) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}
		button.disabled = not occupied
		button.mouse_filter = Control.MOUSE_FILTER_STOP if occupied else Control.MOUSE_FILTER_IGNORE
		(_slot_icons[index] as TextureRect).texture = _texture(str(item.get("asset_path", item.get("icon_path", "")))) if occupied else null
		(_slot_markers[index] as Label).text = str(slot.get("state_marker", "")) if occupied else ""
		button.tooltip_text = _slot_tooltip(slot)
	var current_page_count := _page_count(_active_container()) if paged_active_container else 1
	_container_label.text = _surface_summary_label(current_page_count)
	_previous_button.visible = _containers.size() > 1 or current_page_count > 1
	_next_button.visible = _containers.size() > 1 or current_page_count > 1
	_empty_label.visible = aggregate_used_count == 0
	_layout_slots()
	_apply_slot_styles()


func _render_grouped_card_container() -> void:
	for index in range(_container_backgrounds.size()):
		(_container_backgrounds[index] as TextureRect).visible = false
		(_container_foregrounds[index] as TextureRect).visible = false
		(_container_fallbacks[index] as Panel).visible = false
		(_container_labels[index] as Label).visible = false
	var container_index := clampi(_active_container_index, 0, maxi(0, _containers.size() - 1))
	var container := _active_container()
	var all_slots := _normalized_slots(container)
	var page_size := _grouped_card_page_size()
	var page_count := maxi(1, int(ceil(float(all_slots.size()) / float(page_size))))
	if not _selected_key.is_empty():
		for slot_index in range(all_slots.size()):
			if str((all_slots[slot_index] as Dictionary).get("selection_key", "")) == _selected_key:
				_active_page_index = slot_index / page_size
				break
	_active_page_index = clampi(_active_page_index, 0, page_count - 1)
	var visible_slots := all_slots.slice(_active_page_index * page_size, mini(all_slots.size(), (_active_page_index + 1) * page_size))
	for slot_index in range(visible_slots.size()):
		var slot: Dictionary = visible_slots[slot_index]
		slot["container_index"] = container_index
		slot["container_key"] = str(container.get("key", ""))
		slot["presentation_slot_index"] = _active_page_index * page_size + slot_index
		_slot_models.append(slot)
	_ensure_slot_pool(_slot_models.size())
	for index in range(_slot_buttons.size()):
		var visible := index < _slot_models.size()
		var button := _slot_buttons[index] as Button
		button.visible = visible
		(_slot_icons[index] as TextureRect).visible = visible
		(_slot_markers[index] as Label).visible = visible
		(_slot_underlines[index] as ColorRect).visible = false
		(_slot_name_labels[index] as Label).visible = visible
		(_slot_count_labels[index] as Label).visible = visible
		(_slot_group_labels[index] as Label).visible = visible
		if not visible:
			continue
		var slot: Dictionary = _slot_models[index]
		var occupied := bool(slot.get("occupied", false))
		var item: Dictionary = slot.get("item", {}) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}
		button.disabled = not occupied
		button.mouse_filter = Control.MOUSE_FILTER_STOP if occupied else Control.MOUSE_FILTER_IGNORE
		(_slot_icons[index] as TextureRect).texture = _texture(str(item.get("asset_path", item.get("icon_path", "")))) if occupied else null
		(_slot_name_labels[index] as Label).text = str(item.get("display_name", "Item")).left(24) if occupied else ""
		(_slot_count_labels[index] as Label).text = "x%d" % maxi(1, int(item.get("count", 1))) if occupied else ""
		(_slot_group_labels[index] as Label).text = str(item.get("group_label", item.get("collection_display_name", ""))).left(28) if occupied else ""
		(_slot_markers[index] as Label).text = str(slot.get("state_marker", "")) if occupied else ""
		button.tooltip_text = _slot_tooltip(slot)
	_container_label.text = _surface_summary_label(page_count)
	_previous_button.visible = page_count > 1
	_next_button.visible = page_count > 1
	_empty_label.visible = _occupied_slot_count(container) == 0
	_layout_slots()
	_apply_slot_styles()


func _visible_container_indices() -> Array:
	if _containers.is_empty():
		return []
	if _small_screen_mode and _containers.size() > 1:
		return [clampi(_active_container_index, 0, _containers.size() - 1)]
	var result: Array = []
	for index in range(_containers.size()):
		result.append(index)
	return result


func _normalized_slots(container: Dictionary) -> Array:
	var slots := _dictionary_array(container.get("slots", []))
	var capacity := maxi(0, int(container.get("capacity", 0)))
	var target_count := capacity if capacity > 0 else slots.size()
	while slots.size() < target_count:
		slots.append({"slot_index": slots.size(), "occupied": false, "selection_key": "", "item": {}})
	for index in range(slots.size()):
		slots[index]["slot_index"] = index
	return slots


func _ensure_container_art_pool(count: int) -> void:
	for index in range(_container_backgrounds.size()):
		var visible := index < count
		(_container_backgrounds[index] as TextureRect).visible = visible
		(_container_foregrounds[index] as TextureRect).visible = visible
		(_container_fallbacks[index] as Panel).visible = visible and (_container_backgrounds[index] as TextureRect).texture == null
		(_container_labels[index] as Label).visible = visible
	while _container_backgrounds.size() < count:
		var fallback := Panel.new()
		fallback.add_theme_stylebox_override("panel", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.AMBER, 2))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container_art_layer.add_child(fallback)
		_container_fallbacks.append(fallback)

		var background := TextureRect.new()
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.modulate = Color.WHITE
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container_art_layer.add_child(background)
		_container_backgrounds.append(background)

		var foreground := TextureRect.new()
		foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container_foreground_layer.add_child(foreground)
		_container_foregrounds.append(foreground)

		var label := FoundationWidgets.label("", 11)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		FoundationWidgets.set_control_font_color(label, VisualStyle.YELLOW)
		_container_foreground_layer.add_child(label)
		_container_labels.append(label)


func _layout_container_art() -> void:
	_container_art_rects.clear()
	if _stage == null:
		return
	var visible_indices := _visible_container_indices()
	var count := visible_indices.size()
	if count <= 0:
		return
	var gap := 8.0
	var label_height := 22.0
	var columns := count if count <= 2 else mini(3, int(ceil(sqrt(float(count)))))
	var rows := maxi(1, int(ceil(float(count) / float(columns))))
	var cell_size := Vector2(
		maxf(1.0, (_stage.size.x - gap * float(columns - 1)) / float(columns)),
		maxf(1.0, (_stage.size.y - gap * float(rows - 1)) / float(rows))
	)
	for visible_index in range(count):
		var container_index := int(visible_indices[visible_index])
		var row := visible_index / columns
		var column := visible_index % columns
		var cell_pos := Vector2(float(column) * (cell_size.x + gap), float(row) * (cell_size.y + gap))
		var board_side := floorf(minf(cell_size.x, maxf(1.0, cell_size.y - label_height)))
		var board_rect := Rect2(
			cell_pos + Vector2(floorf((cell_size.x - board_side) * 0.5), label_height),
			Vector2(board_side, board_side)
		)
		_container_art_rects[container_index] = board_rect
		var container: Dictionary = _containers[container_index]
		var used_count := _occupied_slot_count(container)
		var capacity := int(container.get("capacity", 0))
		var count_text := "%d/%d" % [used_count, capacity] if capacity > 0 else "%d items" % used_count
		var label := _container_labels[container_index] as Label
		label.position = cell_pos
		label.size = Vector2(cell_size.x, label_height)
		label.text = "%s  %s" % [str(container.get("display_name", "Container")).left(22), count_text]
		var fallback := _container_fallbacks[container_index] as Panel
		var background := _container_backgrounds[container_index] as TextureRect
		var foreground := _container_foregrounds[container_index] as TextureRect
		for control in [fallback, background, foreground]:
			var node := control as Control
			node.position = board_rect.position
			node.size = board_rect.size


func _container_art_rect(container_index: int) -> Rect2:
	if _container_art_rects.has(container_index):
		return _container_art_rects[container_index] as Rect2
	return _art_rect()


func _occupied_slot_count(container: Dictionary) -> int:
	var used_count := 0
	for slot_value in _normalized_slots(container):
		if bool((slot_value as Dictionary).get("occupied", false)):
			used_count += 1
	return used_count


func _surface_summary_label(page_count: int) -> String:
	if _containers.size() == 1 or _small_screen_mode:
		var container := _active_container()
		var presentation := CatalogScript.presentation(str(container.get("container_type", "loose_carry")), _catalog)
		var used_count := _occupied_slot_count(container)
		var capacity := int(container.get("capacity", 0))
		var count_text := "%d/%d" % [used_count, capacity] if capacity > 0 else "%d items" % used_count
		if page_count > 1:
			count_text += "  Page %d/%d" % [_active_page_index + 1, page_count]
		return "%s  -  %s" % [str(container.get("display_name", presentation.get("display_name", "Inventory"))), count_text]
	return "Inventory containers  -  %d visible" % _visible_container_indices().size()


func _container_rect_snapshots() -> Array:
	var result: Array = []
	for index_value in _visible_container_indices():
		var index := int(index_value)
		var container: Dictionary = _containers[index] if index < _containers.size() else {}
		result.append({
			"key": str(container.get("key", "")),
			"display_name": str(container.get("display_name", "")),
			"rect": _container_art_rects.get(index, Rect2()),
		})
	return result


func _ensure_slot_pool(count: int) -> void:
	while _slot_buttons.size() < count:
		var index := _slot_buttons.size()
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.flat = true
		button.text = ""
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(Callable(self, "_on_slot_pressed").bind(index))
		button.mouse_entered.connect(Callable(self, "_on_slot_hovered").bind(index))
		button.mouse_exited.connect(Callable(self, "_on_slot_unhovered").bind(index))
		button.focus_entered.connect(Callable(self, "_on_slot_focused").bind(index))
		button.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(index))
		_slot_layer.add_child(button)

		var underline := ColorRect.new()
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underline.visible = false
		button.add_child(underline)
		_slot_underlines.append(underline)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_slot_icons.append(icon)

		var marker := Label.new()
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		marker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_theme_font_size_override("font_size", 11)
		marker.add_theme_constant_override("outline_size", 3)
		marker.add_theme_color_override("font_outline_color", Color(VisualStyle.DARK, 0.96))
		button.add_child(marker)
		_slot_markers.append(marker)

		var group_label := FoundationWidgets.muted_label("", VisualStyle.TYPE_MICRO)
		group_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		group_label.clip_text = true
		group_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(group_label)
		_slot_group_labels.append(group_label)

		var name_label := FoundationWidgets.label("", VisualStyle.TYPE_CAPTION)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		_slot_name_labels.append(name_label)

		var count_label := FoundationWidgets.label("", VisualStyle.TYPE_MICRO)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
		_slot_count_labels.append(count_label)
		_slot_buttons.append(button)


func _layout_slots() -> void:
	if _stage == null:
		return
	if _grouped_card_mode():
		_layout_grouped_card_slots()
		return
	_layout_container_art()
	_slot_rects.clear()
	if _slot_models.is_empty():
		return
	for index in range(_slot_models.size()):
		var slot: Dictionary = _slot_models[index]
		var container_index := clampi(int(slot.get("container_index", _active_container_index)), 0, maxi(0, _containers.size() - 1))
		var container: Dictionary = _containers[container_index] if container_index < _containers.size() else _active_container()
		var container_type := str(container.get("container_type", "loose_carry"))
		var full_slot_count := maxi(_normalized_slots(container).size(), int(container.get("capacity", 0)))
		var page_reflow := _small_screen_mode and full_slot_count > SMALL_SCREEN_PAGE_SIZE
		var normalized_rects := CatalogScript.slot_rects("small_screen_page" if page_reflow else container_type, _slot_models.size() if page_reflow else full_slot_count, _catalog)
		var presentation := CatalogScript.presentation(container_type, _catalog)
		var icon_scale := clampf(float(presentation.get("item_icon_scale", 0.70)), 0.25, 1.0)
		var art_rect := _container_art_rect(container_index)
		var presentation_index := index if page_reflow else int(slot.get("presentation_slot_index", index))
		if presentation_index >= normalized_rects.size() or index >= _slot_buttons.size():
			continue
		var normalized: Rect2 = normalized_rects[presentation_index]
		var pixel_rect := Rect2(
			art_rect.position + normalized.position * art_rect.size,
			normalized.size * art_rect.size
		)
		var minimum_target := SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT if _small_screen_mode else FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT
		if bool((_slot_models[index] as Dictionary).get("occupied", false)):
			var expanded_size := Vector2(maxf(pixel_rect.size.x, minimum_target), maxf(pixel_rect.size.y, minimum_target))
			pixel_rect.position -= (expanded_size - pixel_rect.size) * 0.5
			pixel_rect.size = expanded_size
			pixel_rect.position.x = clampf(pixel_rect.position.x, art_rect.position.x, maxf(art_rect.position.x, art_rect.end.x - pixel_rect.size.x))
			pixel_rect.position.y = clampf(pixel_rect.position.y, art_rect.position.y, maxf(art_rect.position.y, art_rect.end.y - pixel_rect.size.y))
		var button := _slot_buttons[index] as Button
		button.position = pixel_rect.position
		button.size = pixel_rect.size
		var icon := _slot_icons[index] as TextureRect
		var icon_side := floorf(minf(pixel_rect.size.x, pixel_rect.size.y) * icon_scale)
		icon.size = Vector2(icon_side, icon_side)
		# Objects rest against the compartment floor instead of floating in the
		# geometric center. The tiny deterministic offset breaks up card-grid
		# regularity without blurring the pixel art with rotation.
		var visual_index := int((_slot_models[index] as Dictionary).get("presentation_slot_index", index))
		var horizontal_nudge := float((visual_index % 3) - 1) * maxf(1.0, pixel_rect.size.x * 0.012)
		icon.position = Vector2(
			floorf((button.size.x - icon_side) * 0.5 + horizontal_nudge),
			floorf(maxf(0.0, button.size.y - icon_side - button.size.y * 0.06))
		)
		icon.pivot_offset = icon.size * 0.5
		var underline := _slot_underlines[index] as ColorRect
		underline.size = Vector2(maxf(12.0, icon_side * 0.56), maxf(2.0, floorf(icon_side * 0.045)))
		underline.position = Vector2(
			floorf((button.size.x - underline.size.x) * 0.5 + horizontal_nudge),
			floorf(minf(button.size.y - underline.size.y, icon.position.y + icon.size.y * 0.91))
		)
		var marker := _slot_markers[index] as Label
		marker.position = Vector2(maxf(0.0, button.size.x - 34.0), maxf(0.0, button.size.y - 24.0))
		marker.size = Vector2(minf(32.0, button.size.x), minf(22.0, button.size.y))
		var key := str((_slot_models[index] as Dictionary).get("selection_key", ""))
		_slot_rects[key if not key.is_empty() else "empty:%d" % index] = Rect2(button.global_position, button.size)


func _layout_grouped_card_slots() -> void:
	_slot_rects.clear()
	if _slot_models.is_empty():
		return
	var gap := float(VisualStyle.SPACE_4)
	var columns := _grouped_card_columns()
	var card_width := floorf((_stage.size.x - gap * float(columns - 1)) / float(columns))
	var card_height := maxf(VisualStyle.TOUCH_TARGET * 2.0, minf(VisualStyle.TOUCH_TARGET * 3.0, (_stage.size.y - gap * float(maxi(1, int(ceil(float(_slot_models.size()) / float(columns)))) - 1)) / float(maxi(1, int(ceil(float(_slot_models.size()) / float(columns)))))))
	for index in range(_slot_models.size()):
		var row := index / columns
		var column := index % columns
		var pixel_rect := Rect2(
			Vector2(float(column) * (card_width + gap), float(row) * (card_height + gap)),
			Vector2(card_width, card_height)
		)
		var button := _slot_buttons[index] as Button
		button.position = pixel_rect.position
		button.size = pixel_rect.size
		var pad := float(VisualStyle.SPACE_3)
		var group_label := _slot_group_labels[index] as Label
		group_label.position = Vector2(pad, pad)
		group_label.size = Vector2(maxf(1.0, button.size.x - pad * 2.0 - VisualStyle.ICON_SMALL.x), VisualStyle.TYPE_CAPTION + VisualStyle.SPACE_2)
		var count_label := _slot_count_labels[index] as Label
		count_label.position = Vector2(maxf(0.0, button.size.x - VisualStyle.ICON_SMALL.x - pad), pad)
		count_label.size = Vector2(VisualStyle.ICON_SMALL.x, VisualStyle.TYPE_CAPTION + VisualStyle.SPACE_2)
		var icon := _slot_icons[index] as TextureRect
		var icon_side := minf(button.size.x - pad * 2.0, button.size.y * 0.42)
		icon.size = Vector2(icon_side, icon_side)
		icon.position = Vector2(floorf((button.size.x - icon_side) * 0.5), floorf(button.size.y * 0.22))
		var name_label := _slot_name_labels[index] as Label
		name_label.position = Vector2(pad, maxf(icon.position.y + icon.size.y + VisualStyle.SPACE_2, button.size.y - VisualStyle.TOUCH_TARGET))
		name_label.size = Vector2(maxf(1.0, button.size.x - pad * 2.0), minf(VisualStyle.TOUCH_TARGET, button.size.y - name_label.position.y - pad))
		var underline := _slot_underlines[index] as ColorRect
		underline.size = Vector2(maxf(VisualStyle.TOUCH_TARGET, button.size.x - pad * 2.0), VisualStyle.BORDER_STANDARD)
		underline.position = Vector2(pad, button.size.y - pad - underline.size.y)
		var marker := _slot_markers[index] as Label
		marker.position = Vector2(maxf(0.0, button.size.x - VisualStyle.ICON_SMALL.x), maxf(0.0, button.size.y - VisualStyle.ICON_SMALL.y))
		marker.size = VisualStyle.ICON_SMALL
		var key := str((_slot_models[index] as Dictionary).get("selection_key", ""))
		_slot_rects[key if not key.is_empty() else "empty:%d" % index] = Rect2(button.global_position, button.size)


func _art_rect() -> Rect2:
	var side := minf(_stage.size.x, _stage.size.y)
	return Rect2(Vector2(floorf((_stage.size.x - side) * 0.5), floorf((_stage.size.y - side) * 0.5)), Vector2(side, side))


func _apply_slot_styles() -> void:
	if _grouped_card_mode():
		_apply_grouped_card_styles()
		return
	for index in range(mini(_slot_models.size(), _slot_buttons.size())):
		var slot: Dictionary = _slot_models[index]
		var button := _slot_buttons[index] as Button
		var icon := _slot_icons[index] as TextureRect
		var marker := _slot_markers[index] as Label
		var underline := _slot_underlines[index] as ColorRect
		var key := str(slot.get("selection_key", ""))
		var selected := not key.is_empty() and key == _selected_key
		var focused := not key.is_empty() and key == _focused_key
		var hovered := not key.is_empty() and key == _hovered_key
		var cue := ""
		var accent := Color.TRANSPARENT
		if selected:
			cue = "◆"
			accent = VisualStyle.YELLOW
		elif focused:
			cue = "◇"
			accent = VisualStyle.CYAN
		elif hovered:
			cue = "•"
			accent = VisualStyle.TEAL
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			button.add_theme_stylebox_override(state, empty_style)
		underline.visible = not cue.is_empty()
		underline.color = accent
		var state_marker := str(slot.get("state_marker", "")).strip_edges()
		marker.text = "%s %s" % [cue, state_marker] if not cue.is_empty() and not state_marker.is_empty() else cue if not cue.is_empty() else state_marker
		marker.add_theme_color_override("font_color", accent if not cue.is_empty() else Color(VisualStyle.SOFT, 0.68))
		var disabled_reason := str(slot.get("disabled_reason", "")).strip_edges()
		icon.modulate = Color(1.0, 1.0, 1.0, 0.55) if not disabled_reason.is_empty() and not selected else Color.WHITE
		# The underline/marker already communicates focus. Scaling the object itself
		# makes a nearly full-size model spill out of its physical recess and adds a
		# showy pulse that fights the container art.
		icon.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.scale = Vector2.ONE


func _apply_grouped_card_styles() -> void:
	for index in range(mini(_slot_models.size(), _slot_buttons.size())):
		var slot: Dictionary = _slot_models[index]
		var item: Dictionary = slot.get("item", {}) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}
		var button := _slot_buttons[index] as Button
		var icon := _slot_icons[index] as TextureRect
		var marker := _slot_markers[index] as Label
		var underline := _slot_underlines[index] as ColorRect
		var group_label := _slot_group_labels[index] as Label
		var name_label := _slot_name_labels[index] as Label
		var count_label := _slot_count_labels[index] as Label
		var key := str(slot.get("selection_key", ""))
		var selected := not key.is_empty() and key == _selected_key
		var focused := not key.is_empty() and key == _focused_key
		var hovered := not key.is_empty() and key == _hovered_key
		var outline := VisualStyle.rarity_outline_color(str(item.get("tier", "")))
		var fill := Color(VisualStyle.role("surface_raised"), 0.96)
		if selected:
			fill = Color(outline, 0.24)
		elif focused or hovered:
			fill = Color(outline, 0.16)
		var border_width := VisualStyle.BORDER_FOCUS if selected else VisualStyle.BORDER_STANDARD
		var style := VisualStyle.pixel_box(fill, outline, border_width)
		for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		var cue := "◆" if selected else "◇" if focused else "•" if hovered else ""
		underline.visible = not cue.is_empty()
		underline.color = outline
		var state_marker := str(slot.get("state_marker", "")).strip_edges()
		marker.text = "%s %s" % [cue, state_marker] if not cue.is_empty() and not state_marker.is_empty() else cue if not cue.is_empty() else state_marker
		marker.add_theme_color_override("font_color", outline)
		FoundationWidgets.set_control_font_color(group_label, outline)
		FoundationWidgets.set_control_font_color(count_label, outline)
		FoundationWidgets.set_control_font_color(name_label, VisualStyle.role("text_primary"))
		var disabled_reason := str(slot.get("disabled_reason", "")).strip_edges()
		icon.modulate = Color(VisualStyle.WHITE, 0.55) if not disabled_reason.is_empty() and not selected else Color.WHITE
		icon.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.scale = Vector2.ONE


func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= _slot_models.size():
		return
	var key := str((_slot_models[index] as Dictionary).get("selection_key", ""))
	if key.is_empty():
		return
	if key == _selected_key:
		slot_confirmed.emit(key)
		return
	focus_selection(key, true)


func _on_slot_hovered(index: int) -> void:
	if index < 0 or index >= _slot_models.size():
		return
	_hovered_key = str((_slot_models[index] as Dictionary).get("selection_key", ""))
	_apply_slot_styles()
	if not _hovered_key.is_empty():
		slot_hovered.emit(_hovered_key)


func _on_slot_unhovered(index: int) -> void:
	if index >= 0 and index < _slot_models.size() and _hovered_key == str((_slot_models[index] as Dictionary).get("selection_key", "")):
		_hovered_key = ""
		_apply_slot_styles()


func _on_slot_focused(index: int) -> void:
	if index < 0 or index >= _slot_models.size():
		return
	_focused_key = str((_slot_models[index] as Dictionary).get("selection_key", ""))
	_apply_slot_styles()


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_pressed(index)
		accept_event()
		return
	if not event is InputEventKey and not event is InputEventJoypadButton:
		return
	if event.is_action_pressed("ui_page_up") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER):
		_change_container(-1)
		accept_event()
		return
	if event.is_action_pressed("ui_page_down") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		_change_container(1)
		accept_event()
		return
	var direction := Vector2.ZERO
	if event.is_action_pressed("ui_left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2.RIGHT
	elif event.is_action_pressed("ui_up"):
		direction = Vector2.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		_focus_neighbor(index, direction)
		accept_event()


func _focus_neighbor(from_index: int, direction: Vector2) -> void:
	if from_index < 0 or from_index >= _slot_models.size():
		return
	var from_button := _slot_buttons[from_index] as Button
	var origin := from_button.position + from_button.size * 0.5
	var best_index := -1
	var best_score := INF
	for index in range(_slot_models.size()):
		if index == from_index or not bool((_slot_models[index] as Dictionary).get("occupied", false)):
			continue
		var button := _slot_buttons[index] as Button
		var delta := button.position + button.size * 0.5 - origin
		if delta.dot(direction) <= 0.0:
			continue
		var lateral := absf(delta.dot(Vector2(-direction.y, direction.x)))
		var score := delta.length() + lateral * 1.8 + float(index) * 0.0001
		if score < best_score:
			best_score = score
			best_index = index
	if best_index >= 0:
		(_slot_buttons[best_index] as Button).grab_focus()


func _change_container(delta: int) -> void:
	var current_page_count := _page_count(_active_container())
	if _containers.size() <= 1 and current_page_count <= 1:
		return
	var next_page := _active_page_index + delta
	if next_page >= 0 and next_page < current_page_count:
		_active_page_index = next_page
	else:
		_active_container_index = posmod(_active_container_index + delta, _containers.size())
		var destination_pages := _page_count(_active_container())
		_active_page_index = destination_pages - 1 if delta < 0 else 0
	_selected_key = _first_preferred_key_on_page(_active_container_index, _active_page_index)
	if _selected_key.is_empty():
		_reconcile_selection_in_active_container()
	_render_active_container()
	container_changed.emit(active_container_key())


func _reconcile_selection(previous_hint: Dictionary = {}) -> void:
	if not _selected_key.is_empty():
		var location := _selection_location(_selected_key)
		if not location.is_empty():
			_active_container_index = int(location.get("container_index", _active_container_index))
			return
	var previous_container_key := str(previous_hint.get("container_key", ""))
	var same_context := str(previous_hint.get("mode", "")) == str(_model.get("mode", ""))
	var previous_container_index := _container_index(previous_container_key) if same_context else -1
	if previous_container_index >= 0:
		var nearest_key := _nearest_occupied_key(previous_container_index, previous_hint)
		if not nearest_key.is_empty():
			_selected_key = nearest_key
			_active_container_index = previous_container_index
			_model["selected_key"] = _selected_key
			return
	_selected_key = _first_preferred_key(_active_container_index)
	if _selected_key.is_empty():
		for index in range(_containers.size()):
			_selected_key = _first_preferred_key(index)
			if not _selected_key.is_empty():
				_active_container_index = index
				break
	_model["selected_key"] = _selected_key


func _selection_reconciliation_hint() -> Dictionary:
	if _selected_key.is_empty():
		return {}
	var location := _selection_location(_selected_key)
	if location.is_empty():
		return {}
	var container: Dictionary = location.get("container", {})
	var slots := _dictionary_array(container.get("slots", []))
	var slot: Dictionary = location.get("slot", {})
	var slot_index := int(slot.get("slot_index", slots.find(slot)))
	var rects := CatalogScript.slot_rects(str(container.get("container_type", "loose_carry")), maxi(slots.size(), int(container.get("capacity", 0))), _catalog)
	var center := Vector2(float(slot_index), 0.0)
	if slot_index >= 0 and slot_index < rects.size():
		var rect: Rect2 = rects[slot_index]
		center = rect.get_center()
	return {"container_key": str(container.get("key", "")), "center": center, "slot_index": slot_index, "mode": str(_model.get("mode", ""))}


func _nearest_occupied_key(container_index: int, hint: Dictionary) -> String:
	if container_index < 0 or container_index >= _containers.size():
		return ""
	var container: Dictionary = _containers[container_index]
	var slots := _dictionary_array(container.get("slots", []))
	var rects := CatalogScript.slot_rects(str(container.get("container_type", "loose_carry")), maxi(slots.size(), int(container.get("capacity", 0))), _catalog)
	var wanted_center: Vector2 = hint.get("center", Vector2.ZERO) if typeof(hint.get("center", Vector2.ZERO)) == TYPE_VECTOR2 else Vector2.ZERO
	var best_key := ""
	var best_score := INF
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if not bool(slot.get("occupied", false)):
			continue
		var key := str(slot.get("selection_key", ""))
		if key.is_empty():
			continue
		var center := Vector2(float(index), 0.0)
		if index < rects.size():
			center = (rects[index] as Rect2).get_center()
		var score := center.distance_squared_to(wanted_center) + float(index) * 0.000001
		if score < best_score:
			best_score = score
			best_key = key
	return best_key


func _reconcile_selection_in_active_container() -> void:
	_selected_key = _first_preferred_key(_active_container_index)
	_model["selected_key"] = _selected_key


func _first_preferred_key(container_index: int) -> String:
	if container_index < 0 or container_index >= _containers.size():
		return ""
	var first_inspectable := ""
	for slot_value in _dictionary_array((_containers[container_index] as Dictionary).get("slots", [])):
		if not bool(slot_value.get("occupied", false)):
			continue
		var key := str(slot_value.get("selection_key", ""))
		if key.is_empty():
			continue
		if first_inspectable.is_empty():
			first_inspectable = key
		if bool(slot_value.get("actionable", false)) and str(slot_value.get("disabled_reason", "")).is_empty():
			return key
	return first_inspectable


func _first_occupied_key(container_index: int) -> String:
	return _first_preferred_key(container_index)


func _first_preferred_key_on_page(container_index: int, page_index: int) -> String:
	if container_index < 0 or container_index >= _containers.size():
		return ""
	var slots := _dictionary_array((_containers[container_index] as Dictionary).get("slots", []))
	var page_size := _page_size(maxi(slots.size(), int((_containers[container_index] as Dictionary).get("capacity", 0))))
	var start := maxi(0, page_index) * page_size
	var first_inspectable := ""
	for index in range(start, mini(slots.size(), start + page_size)):
		var slot: Dictionary = slots[index]
		var key := str(slot.get("selection_key", ""))
		if not bool(slot.get("occupied", false)) or key.is_empty():
			continue
		if first_inspectable.is_empty():
			first_inspectable = key
		if bool(slot.get("actionable", false)) and str(slot.get("disabled_reason", "")).is_empty():
			return key
	return first_inspectable


func _first_occupied_key_on_page(container_index: int, page_index: int) -> String:
	return _first_preferred_key_on_page(container_index, page_index)


func _page_size(slot_count: int) -> int:
	if _grouped_card_mode():
		return _grouped_card_page_size()
	return SMALL_SCREEN_PAGE_SIZE if _small_screen_mode and slot_count > SMALL_SCREEN_PAGE_SIZE else maxi(1, slot_count)


func _page_count(container: Dictionary) -> int:
	var slot_count := maxi(_dictionary_array(container.get("slots", [])).size(), int(container.get("capacity", 0)))
	return maxi(1, int(ceil(float(slot_count) / float(_page_size(slot_count)))))


func _grouped_card_mode() -> bool:
	var layout: Dictionary = _model.get("layout", {}) if typeof(_model.get("layout", {})) == TYPE_DICTIONARY else {}
	return str(layout.get("presentation", "")) == "grouped_card_grid"


func _grouped_card_columns(area_size: Vector2 = Vector2.ZERO) -> int:
	if area_size == Vector2.ZERO and _stage != null:
		area_size = _stage.size
	if area_size.x <= 0.0:
		return 1
	var minimum_width := VisualStyle.TOUCH_TARGET * (3.2 if _small_screen_mode else 3.6)
	return maxi(1, int(floor((area_size.x + float(VisualStyle.SPACE_4)) / (minimum_width + float(VisualStyle.SPACE_4)))))


func _grouped_card_page_size() -> int:
	var area_size := _grouped_card_stage_size_estimate()
	if area_size.y <= 0.0:
		return 8 if _small_screen_mode else 12
	var columns := _grouped_card_columns(area_size)
	var minimum_height := VisualStyle.TOUCH_TARGET * (2.25 if _small_screen_mode else 2.5)
	var rows := maxi(1, int(floor((area_size.y + float(VisualStyle.SPACE_4)) / (minimum_height + float(VisualStyle.SPACE_4)))))
	return maxi(1, columns * rows)


func _grouped_card_stage_size_estimate() -> Vector2:
	if _stage == null:
		return Vector2.ZERO
	var minimum_size := _stage.custom_minimum_size
	if _stage.size.x > minimum_size.x and _stage.size.y > minimum_size.y:
		return _stage.size
	var header_allowance := FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT + float(VisualStyle.SPACE_2)
	return Vector2(
		maxf(minimum_size.x, size.x),
		maxf(minimum_size.y, size.y - header_allowance)
	)


func _selection_location(selection_key: String) -> Dictionary:
	for container_index in range(_containers.size()):
		var container: Dictionary = _containers[container_index]
		for slot_value in _dictionary_array(container.get("slots", [])):
			if str(slot_value.get("selection_key", "")) == selection_key:
				return {"container_index": container_index, "container": container, "slot": slot_value}
	return {}


func _focus_button_for_key(selection_key: String) -> void:
	for index in range(_slot_models.size()):
		if str((_slot_models[index] as Dictionary).get("selection_key", "")) == selection_key:
			(_slot_buttons[index] as Button).grab_focus()
			return


func _active_container() -> Dictionary:
	if _containers.is_empty() or _active_container_index < 0 or _active_container_index >= _containers.size():
		return {"key": "loose", "container_type": "loose_carry", "display_name": "Loose Carry", "capacity": 0, "slots": []}
	return (_containers[_active_container_index] as Dictionary).duplicate(true)


func _container_index(container_key: String) -> int:
	if container_key.is_empty():
		return -1
	for index in range(_containers.size()):
		if str((_containers[index] as Dictionary).get("key", "")) == container_key:
			return index
	return -1


func _legacy_loose_container(model: Dictionary) -> Dictionary:
	var slots: Array = []
	for item_value in _dictionary_array(model.get("items", [])):
		var source := str(item_value.get("storage_source", "carried"))
		var item_id := str(item_value.get("id", ""))
		slots.append({
			"slot_index": slots.size(),
			"occupied": true,
			"selection_key": "run:%s:%s" % [source, item_id],
			"item": item_value,
		})
	return {"key": "legacy_loose", "container_type": "loose_carry", "display_name": "Loose Carry", "capacity": 0, "slots": slots}


func _selection_key_from_legacy(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	var selected: Dictionary = value
	var item_id := str(selected.get("id", ""))
	if item_id.is_empty():
		return ""
	return "run:%s:%s" % [str(selected.get("source", "carried")), item_id]


func _slot_tooltip(slot: Dictionary) -> String:
	if not bool(slot.get("occupied", false)):
		return "Empty space"
	var item: Dictionary = slot.get("item", {}) if typeof(slot.get("item", {})) == TYPE_DICTIONARY else {}
	var text := str(item.get("display_name", "Item"))
	var disabled_reason := str(slot.get("disabled_reason", item.get("disabled_reason", ""))).strip_edges()
	if not disabled_reason.is_empty():
		text += "\n%s" % disabled_reason
	return text


func _texture(path: String) -> Texture2D:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return null
	if _texture_provider.is_valid():
		var provided: Variant = _texture_provider.call(clean_path)
		if provided is Texture2D:
			return provided as Texture2D
	var loaded: Variant = load(clean_path)
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


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(str(entry))
	return result
