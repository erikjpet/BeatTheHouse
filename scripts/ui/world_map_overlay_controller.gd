class_name WorldMapOverlayController
extends RefCounted

signal refresh_requested()
signal message_requested(text: String)
signal travel_requested(target_id: String, label: String, choice: Dictionary)
signal meta_travel_requested(target_id: String)
signal node_pressed(node_id: String)

const WORLD_MAP_NODE_BUTTON_POOL_SIZE := 24
const WORLD_MAP_DETAIL_BADGE_CELL_POOL_SIZE := 6
const VisualStyle := preload("res://scripts/ui/visual_style.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")

var overlay: Control
var holder: Control
var nodes_layer: Control
var title_label: Label
var detail_popup: PanelContainer
var detail_label: Label
var badge_slot: VBoxContainer
var confirm_button: Button
var badge_row: HFlowContainer
var badge_cells: Array = []
var button_ids: Array = []
var button_layout_size := Vector2(-1.0, -1.0)
var detail_badges_key := "__unset__"
var detail_badges_snapshot: Array = []
var selected_node_id: String = ""
var selected_travel_target_id: String = ""
var selected_travel_label: String = ""
var snapshot_cache_key: String = ""
var canvas_snapshot_key: String = ""


func clear_selection() -> void:
	selected_node_id = ""
	selected_travel_target_id = ""
	selected_travel_label = ""
	snapshot_cache_key = ""
	canvas_snapshot_key = ""
	detail_badges_key = "__unset__"


func configure_nodes(overlay_node: Control, holder_node: Control, nodes_layer_node: Control, title_node: Label, detail_popup_node: PanelContainer, detail_node: Label, badge_slot_node: VBoxContainer, confirm_node: Button) -> void:
	overlay = overlay_node
	holder = holder_node
	nodes_layer = nodes_layer_node
	title_label = title_node
	detail_popup = detail_popup_node
	detail_label = detail_node
	badge_slot = badge_slot_node
	confirm_button = confirm_node


func is_visible() -> bool:
	return overlay != null and overlay.visible


func show_overlay() -> void:
	if overlay == null:
		return
	overlay.visible = true
	overlay.move_to_front()


func hide_overlay() -> void:
	if overlay != null:
		overlay.visible = false


func reset_button_layout() -> void:
	button_layout_size = Vector2(-1.0, -1.0)


func apply_title(text: String) -> void:
	if title_label != null:
		title_label.text = text


func apply_detail(text: String, badges: Array, confirm_enabled: bool) -> void:
	if detail_label != null:
		detail_label.text = text
	set_confirm_enabled(confirm_enabled)
	set_detail_badges(badges)


func set_confirm_enabled(enabled: bool) -> void:
	if confirm_button != null:
		confirm_button.disabled = not enabled


func sync_canvas_snapshot(snapshot: Dictionary, snapshot_key: String) -> void:
	if nodes_layer != null and nodes_layer.has_method("set_map_snapshot") and canvas_snapshot_key != snapshot_key:
		nodes_layer.call("set_map_snapshot", snapshot)
		canvas_snapshot_key = snapshot_key


func sync_node_buttons(snapshot: Dictionary) -> void:
	if nodes_layer == null:
		return
	_ensure_node_button_pool()
	var node_ids := node_ids(snapshot)
	var layer_size := _layer_size()
	if node_ids != button_ids or layer_size != button_layout_size:
		clear_node_buttons()
		_add_node_buttons(snapshot)
		button_ids = node_ids.duplicate()
		button_layout_size = layer_size
	else:
		_position_node_buttons(snapshot)


func clear_node_buttons() -> void:
	if nodes_layer == null:
		return
	for index in range(WORLD_MAP_NODE_BUTTON_POOL_SIZE):
		var button := _pool_button(index)
		if button == null:
			continue
		button.visible = false
		button.disabled = true
		button.tooltip_text = ""
		button.set_meta("node_id", "")
		button.name = "WorldMapNodePool_%02d" % index
	button_ids = []
	button_layout_size = Vector2(-1.0, -1.0)


func node_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty():
			ids.append(node_id)
	return ids


func position_detail_popup(snapshot: Dictionary) -> void:
	if detail_popup == null or holder == null:
		return
	var node_id := selected_node_id.strip_edges()
	if node_id.is_empty() or not node_ids(snapshot).has(node_id):
		detail_popup.visible = false
		return
	var holder_size := holder.size
	if holder_size.x <= 0.0 or holder_size.y <= 0.0:
		holder_size = Vector2(800, 430)
	var popup_size := Vector2(276, 150)
	detail_popup.size = popup_size
	detail_popup.visible = true
	var center := holder_size * 0.5
	if nodes_layer != null and nodes_layer.has_method("local_position_for_node") and bool(nodes_layer.call("node_is_in_view", node_id)):
		center = nodes_layer.call("local_position_for_node", node_id) as Vector2
	var margin := 12.0
	var x := center.x + 30.0
	if x + popup_size.x > holder_size.x - margin:
		x = center.x - popup_size.x - 30.0
	var y := center.y - popup_size.y * 0.5
	x = clampf(x, margin, maxf(margin, holder_size.x - popup_size.x - margin))
	y = clampf(y, margin, maxf(margin, holder_size.y - popup_size.y - margin))
	detail_popup.position = Vector2(roundf(x), roundf(y))


func set_detail_badges(badges_value: Variant) -> void:
	if badge_slot == null:
		return
	_ensure_detail_badge_pool()
	var badges := _copy_array(badges_value)
	detail_badges_snapshot = badges.duplicate(true)
	var should_show := not badges.is_empty()
	var badges_key := JSON.stringify(badges)
	if badges_key == detail_badges_key and badge_slot.visible == should_show:
		if not should_show or badge_slot.get_child_count() > 0:
			return
	detail_badges_key = badges_key
	badge_slot.visible = should_show
	if badges.is_empty():
		_update_detail_badge_cells([])
		return
	_update_detail_badge_cells(badges)


func detail_badge_prewarm_sample() -> Array:
	return AttributeBadgesScript.for_world_map_detail("casino", {
		"risk_decay": 35,
		"risk_event": {
			"chance_percent": 75,
			"suspicion_delta": 2,
		},
	})


func detail_badges() -> Array:
	return detail_badges_snapshot.duplicate(true)


func handle_holder_gui_input(event: InputEvent) -> bool:
	if selected_node_id.is_empty():
		return false
	var local_position := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
		local_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		pressed = touch_event.pressed
		local_position = touch_event.position
	if not pressed:
		return false
	if _detail_popup_contains_local_position(local_position):
		return false
	if _node_button_contains_holder_position(local_position):
		return false
	clear_selection()
	return true


func select_run_node(node_id: String, current_node_id: String, visible_node_ids: Array, choice: Dictionary) -> Dictionary:
	var clean_id := node_id.strip_edges()
	if clean_id.is_empty():
		return _result(false, "", true)
	if not visible_node_ids.has(clean_id):
		return _result(false, "That stop is not on your map from here.", true)
	selected_node_id = clean_id
	if clean_id == current_node_id:
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "You are here.", true)
	if choice.is_empty():
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "That stop is not available from here right now.", true)
	var enabled := bool(choice.get("enabled", true))
	selected_travel_target_id = clean_id if enabled else ""
	selected_travel_label = str(choice.get("label", clean_id)) if enabled else ""
	var message := "Selected travel: %s." % str(choice.get("label", clean_id))
	if not enabled:
		message = str(choice.get("disabled_reason", "That route is not available right now."))
	return _result(enabled, message, true)


func select_meta_node(node_id: String, location_id: String, node_ids: Array, choice: Dictionary) -> Dictionary:
	if not node_ids.has(node_id):
		return _result(false, "That meta stop is not available.", true)
	selected_node_id = node_id
	if node_id == location_id:
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "You are here.", true)
	selected_travel_target_id = node_id
	selected_travel_label = str(choice.get("label", node_id))
	return _result(true, "Selected travel: %s." % selected_travel_label, true)


func confirm_run_selection(choice: Dictionary) -> Dictionary:
	var confirmed_target_id := selected_node_id
	if confirmed_target_id.is_empty() and not selected_travel_target_id.is_empty():
		confirmed_target_id = selected_travel_target_id
	if confirmed_target_id.is_empty():
		return _confirm_result("message", "", "", {}, "Select a map stop first.", true)
	if choice.is_empty():
		return _confirm_result("message", confirmed_target_id, "", {}, "That stop is not available from here right now.", true)
	if not bool(choice.get("enabled", true)):
		return _confirm_result("message", confirmed_target_id, "", {}, str(choice.get("disabled_reason", "That route is not available right now.")), true)
	selected_travel_target_id = str(choice.get("id", ""))
	selected_travel_label = str(choice.get("label", selected_travel_target_id))
	return _confirm_result("travel", selected_travel_target_id, selected_travel_label, choice, "", false)


func confirm_meta_selection(location_id: String, choice: Dictionary) -> Dictionary:
	if selected_node_id == location_id:
		return _confirm_result("message", selected_node_id, "", {}, "You are here.", true)
	if choice.is_empty():
		return _confirm_result("message", selected_node_id, "", {}, "That meta stop is not available.", true)
	return _confirm_result("meta_travel", str(choice.get("id", "home")), str(choice.get("label", choice.get("id", ""))), choice, "", false)


func sync_from_host(node_id: String, target_id: String, target_label: String, cache_key: String, canvas_key: String) -> void:
	selected_node_id = node_id
	selected_travel_target_id = target_id
	selected_travel_label = target_label
	snapshot_cache_key = cache_key
	canvas_snapshot_key = canvas_key


func export_state() -> Dictionary:
	return {
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
		"snapshot_cache_key": snapshot_cache_key,
		"canvas_snapshot_key": canvas_snapshot_key,
	}


func _layer_size() -> Vector2:
	if nodes_layer == null:
		return Vector2(540, 390)
	var layer_size := nodes_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		return Vector2(540, 390)
	return layer_size


func _add_node_buttons(snapshot: Dictionary) -> void:
	if nodes_layer == null:
		return
	_ensure_node_button_pool()
	var index := 0
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			continue
		if index >= WORLD_MAP_NODE_BUTTON_POOL_SIZE:
			break
		var button := _pool_button(index)
		if button == null:
			continue
		button.custom_minimum_size = Vector2(46, 46)
		button.size = Vector2(46, 46)
		button.position = _node_button_position(node_id, node) - button.size * 0.5
		var in_view := _node_is_in_canvas_view(node_id)
		button.visible = in_view
		button.disabled = not in_view
		button.tooltip_text = str(node.get("label", node_id))
		button.set_meta("node_id", node_id)
		button.name = "WorldMapNode_%s" % node_id
		index += 1


func _position_node_buttons(snapshot: Dictionary) -> void:
	if nodes_layer == null:
		return
	_ensure_node_button_pool()
	var index := 0
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			continue
		if index >= WORLD_MAP_NODE_BUTTON_POOL_SIZE:
			break
		var button := _pool_button(index)
		if button == null:
			continue
		button.position = _node_button_position(node_id, node) - button.size * 0.5
		var in_view := _node_is_in_canvas_view(node_id)
		button.visible = in_view
		button.disabled = not in_view
		button.tooltip_text = str(node.get("label", node_id))
		button.set_meta("node_id", node_id)
		button.name = "WorldMapNode_%s" % node_id
		index += 1


func _node_button_position(node_id: String, node: Dictionary) -> Vector2:
	var layer_size := _layer_size()
	var inset := Vector2(32.0, 28.0)
	var drawable := Vector2(maxf(1.0, layer_size.x - inset.x * 2.0), maxf(1.0, layer_size.y - inset.y * 2.0))
	var position: Dictionary = node.get("position", {}) if typeof(node.get("position", {})) == TYPE_DICTIONARY else {}
	var center := inset + Vector2(clampf(float(position.get("x", 0.5)), 0.0, 1.0), clampf(float(position.get("y", 0.5)), 0.0, 1.0)) * drawable
	if nodes_layer != null and nodes_layer.size.x > 0.0 and nodes_layer.size.y > 0.0 and nodes_layer.has_method("local_position_for_node"):
		center = nodes_layer.call("local_position_for_node", node_id) as Vector2
	return center


func _node_is_in_canvas_view(node_id: String) -> bool:
	if nodes_layer == null or not nodes_layer.has_method("node_is_in_view"):
		return true
	return bool(nodes_layer.call("node_is_in_view", node_id))


func _ensure_detail_badge_pool() -> void:
	if badge_slot == null:
		return
	if badge_row == null:
		badge_row = HFlowContainer.new()
		badge_row.add_theme_constant_override("h_separation", 4)
		badge_row.add_theme_constant_override("v_separation", 4)
		badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge_slot.add_child(badge_row)
	while badge_cells.size() < WORLD_MAP_DETAIL_BADGE_CELL_POOL_SIZE:
		var cell := PanelContainer.new()
		cell.visible = false
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_ARROW
		cell.custom_minimum_size = Vector2(24.0, 22.0)
		cell.add_theme_stylebox_override("panel", _badge_cell_style(VisualStyle.CYAN_2))
		var cell_box := HBoxContainer.new()
		cell_box.add_theme_constant_override("separation", 3)
		cell.add_child(cell_box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell_box.add_child(icon)
		var label := Label.new()
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.custom_minimum_size = Vector2(112.0, 0.0)
		label.visible = false
		cell_box.add_child(label)
		cell.mouse_entered.connect(func() -> void:
			cell.custom_minimum_size = Vector2(142.0, 22.0)
			label.visible = not label.text.strip_edges().is_empty()
		)
		cell.mouse_exited.connect(func() -> void:
			label.visible = false
			cell.custom_minimum_size = Vector2(24.0, 22.0)
		)
		badge_row.add_child(cell)
		badge_cells.append({
			"cell": cell,
			"icon": icon,
			"label": label,
		})


func _update_detail_badge_cells(badges: Array) -> void:
	var max_count := badge_cells.size()
	for index in range(max_count):
		var cell_data: Dictionary = badge_cells[index]
		var cell := cell_data.get("cell", null) as PanelContainer
		var icon := cell_data.get("icon", null) as TextureRect
		var label := cell_data.get("label", null) as Label
		if cell == null or icon == null or label == null:
			continue
		if index >= badges.size() or typeof(badges[index]) != TYPE_DICTIONARY:
			cell.visible = false
			icon.texture = null
			label.text = ""
			label.visible = false
			continue
		var badge: Dictionary = badges[index]
		var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
		if glyph_id.is_empty():
			cell.visible = false
			icon.texture = null
			label.text = ""
			label.visible = false
			continue
		var accent := VisualStyle.color(AttributeBadgesScript.palette_token_for_badge(badge), VisualStyle.CYAN_2)
		var detail_text := _badge_tooltip_text(badge)
		cell.visible = true
		cell.tooltip_text = detail_text
		cell.custom_minimum_size = Vector2(24.0, 22.0)
		cell.add_theme_stylebox_override("panel", _badge_cell_style(accent))
		icon.texture = AttributeBadgeRowScript.texture_for_badge(badge, 16, false)
		label.text = detail_text
		label.visible = false
		label.add_theme_color_override("font_color", VisualStyle.accessible_color(accent))


func _badge_cell_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.border_color = VisualStyle.accessible_color(accent)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 3
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _badge_tooltip_text(badge: Dictionary) -> String:
	var tooltip := str(badge.get("tooltip", "")).strip_edges()
	var value_text := str(badge.get("value_text", "")).strip_edges()
	if not tooltip.is_empty() and not value_text.is_empty() and tooltip.find(value_text) < 0:
		return "%s: %s" % [tooltip, value_text]
	if not tooltip.is_empty():
		return tooltip
	var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
	var glyph := AttributeBadgesScript.glyph_definition(glyph_id)
	var label := str(glyph.get("label", glyph_id)).strip_edges()
	if not value_text.is_empty():
		return "%s: %s" % [label, value_text]
	return str(glyph.get("description", label))


func _hit_button(callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.pressed.connect(callback)
	return button


func _ensure_node_button_pool() -> void:
	if nodes_layer == null:
		return
	for index in range(WORLD_MAP_NODE_BUTTON_POOL_SIZE):
		if _pool_button(index) != null:
			continue
		var button := _hit_button(Callable(self, "_on_pool_button_pressed").bind(index))
		button.name = "WorldMapNodePool_%02d" % index
		button.custom_minimum_size = Vector2(46, 46)
		button.size = Vector2(46, 46)
		button.visible = false
		button.disabled = true
		button.set_meta("pool_index", index)
		button.set_meta("node_id", "")
		nodes_layer.add_child(button)


func _pool_button(index: int) -> Button:
	if nodes_layer == null:
		return null
	for child in nodes_layer.get_children():
		if child is Button and int(child.get_meta("pool_index", -1)) == index:
			return child as Button
	return null


func _on_pool_button_pressed(index: int) -> void:
	var button := _pool_button(index)
	if button == null:
		return
	var node_id := str(button.get_meta("node_id", "")).strip_edges()
	if node_id.is_empty():
		return
	node_pressed.emit(node_id)


func _detail_popup_contains_local_position(local_position: Vector2) -> bool:
	if detail_popup == null or not detail_popup.visible:
		return false
	return Rect2(detail_popup.position, detail_popup.size).has_point(local_position)


func _node_button_contains_holder_position(local_position: Vector2) -> bool:
	if nodes_layer == null:
		return false
	var nodes_layer_offset := nodes_layer.position
	for index in range(WORLD_MAP_NODE_BUTTON_POOL_SIZE):
		var button := _pool_button(index)
		if button == null or not button.visible or button.disabled:
			continue
		var rect := Rect2(nodes_layer_offset + button.position, button.size)
		if rect.has_point(local_position):
			return true
	return false


func _result(ok: bool, message: String, refresh: bool) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"refresh": refresh,
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
	}


func _confirm_result(action: String, target_id: String, label: String, choice: Dictionary, message: String, refresh: bool) -> Dictionary:
	return {
		"action": action,
		"target_id": target_id,
		"label": label,
		"choice": choice.duplicate(true),
		"message": message,
		"refresh": refresh,
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
	}


func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
