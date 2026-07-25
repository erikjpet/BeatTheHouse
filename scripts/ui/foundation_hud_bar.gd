class_name FoundationHudBar
extends PanelContainer

signal time_requested

const SegmentedMeterScript := preload("res://scripts/ui/segmented_meter.gd")
const UIArtScript := preload("res://scripts/ui/ui_art.gd")

var wallet_value: Label
var wallet_delta: Label
var chips_chip: HBoxContainer
var chips_value: Label
var heat_meter: SegmentedMeter
var heat_value: Label
var drunk_meter: SegmentedMeter
var drunk_value: Label
var status_tray: HBoxContainer
var time_button: Button
var time_detail: Label
var reduce_motion := false
var _last_bankroll := 0
var _has_rendered := false


func _ready() -> void:
	add_theme_stylebox_override("panel", VisualStyle.state_box("normal"))
	_build()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled


func render(model: Dictionary) -> void:
	if wallet_value == null:
		return
	var bankroll := int(model.get("bankroll", 0))
	wallet_value.text = "$%d" % bankroll
	var bankroll_delta := int(model.get("bankroll_delta", bankroll - _last_bankroll if _has_rendered else 0))
	_render_delta(bankroll_delta)
	_last_bankroll = bankroll
	_has_rendered = true

	chips_chip.visible = bool(model.get("show_chips", false))
	chips_value.text = "%d" % int(model.get("chips", 0))

	var heat := float(model.get("heat_level", 0.0))
	heat_meter.configure("heat", heat)
	heat_value.text = "%d" % roundi(heat)
	var drunk := float(model.get("drunk_level", 0.0))
	var pending := float(model.get("pending_drunk_absorption", 0.0))
	drunk_meter.configure("drunk", drunk, pending)
	drunk_value.text = "%d%s" % [roundi(drunk), " +%d" % roundi(pending) if pending > 0.0 else ""]

	time_button.text = str(model.get("clock_display", "Night"))
	time_button.tooltip_text = str(model.get("clock_tooltip", "Open the day/night schedule."))
	time_detail.text = time_button.tooltip_text
	_render_status_icons(model.get("status_icons", []))


func current_snapshot() -> Dictionary:
	return {
		"rect": get_global_rect(),
		"wallet": wallet_value.text if wallet_value != null else "",
		"wallet_delta": wallet_delta.text if wallet_delta != null else "",
		"chips_visible": chips_chip != null and chips_chip.visible,
		"chips": chips_value.text if chips_value != null else "",
		"heat": heat_meter.current_snapshot() if heat_meter != null else {},
		"drunk": drunk_meter.current_snapshot() if drunk_meter != null else {},
		"status_icon_count": status_tray.get_child_count() if status_tray != null else 0,
		"time_interactive": time_button != null and not time_button.disabled,
		"time_detail_visible": time_detail != null and time_detail.visible,
		"reduce_motion": reduce_motion,
	}


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	var wallet_chip := _value_chip("wallet", "Bankroll")
	wallet_value = wallet_chip.get_meta("value_label") as Label
	row.add_child(wallet_chip)
	wallet_delta = FoundationWidgets.label("", VisualStyle.TYPE_CAPTION)
	wallet_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	FoundationWidgets.set_control_font_color(wallet_delta, VisualStyle.role("success"))
	wallet_chip.add_child(wallet_delta)

	chips_chip = _value_chip("casino_chips", "Chips")
	chips_value = chips_chip.get_meta("value_label") as Label
	row.add_child(chips_chip)

	var heat_group := _meter_group("heat", "Heat")
	heat_meter = heat_group.get_meta("meter") as SegmentedMeter
	heat_value = heat_group.get_meta("value_label") as Label
	row.add_child(heat_group)

	var drunk_group := _meter_group("drink", "Drunk")
	drunk_meter = drunk_group.get_meta("meter") as SegmentedMeter
	drunk_value = drunk_group.get_meta("value_label") as Label
	row.add_child(drunk_group)

	status_tray = HBoxContainer.new()
	status_tray.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	status_tray.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(status_tray)

	var time_stack := VBoxContainer.new()
	time_stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	row.add_child(time_stack)
	time_button = FoundationWidgets.variant_button("", _on_time_pressed)
	time_button.icon = UIArtScript.icon("time")
	time_button.expand_icon = true
	time_button.tooltip_text = "Open the day/night schedule."
	time_stack.add_child(time_button)
	time_detail = FoundationWidgets.muted_label("", VisualStyle.TYPE_CAPTION)
	time_detail.visible = false
	time_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_detail.custom_minimum_size.x = VisualStyle.TOOLTIP_MAX_WIDTH
	time_stack.add_child(time_detail)


func _value_chip(icon_id: String, title: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	var icon_rect := TextureRect.new()
	icon_rect.texture = UIArtScript.icon(icon_id)
	icon_rect.custom_minimum_size = VisualStyle.ICON_MEDIUM
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon_rect)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	chip.add_child(stack)
	var title_label := FoundationWidgets.muted_label(title, VisualStyle.TYPE_MICRO)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(title_label)
	var value_label := FoundationWidgets.label("", VisualStyle.TYPE_BODY_LARGE)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(value_label)
	chip.set_meta("value_label", value_label)
	return chip


func _meter_group(icon_id: String, title: String) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	var icon_rect := TextureRect.new()
	icon_rect.texture = UIArtScript.icon(icon_id)
	icon_rect.custom_minimum_size = VisualStyle.ICON_MEDIUM
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon_rect)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	group.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	stack.add_child(heading_row)
	var title_label := FoundationWidgets.muted_label(title, VisualStyle.TYPE_MICRO)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading_row.add_child(title_label)
	var value_label := FoundationWidgets.label("", VisualStyle.TYPE_CAPTION)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading_row.add_child(value_label)
	var meter: SegmentedMeter = SegmentedMeterScript.new()
	stack.add_child(meter)
	group.set_meta("meter", meter)
	group.set_meta("value_label", value_label)
	return group


func _render_delta(delta: int) -> void:
	wallet_delta.text = "%+d" % delta if delta != 0 else ""
	if delta == 0 or reduce_motion:
		wallet_delta.modulate = Color.WHITE
		return
	wallet_delta.modulate = Color(VisualStyle.role("success" if delta > 0 else "danger"), 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(wallet_delta, "modulate:a", 1.0, VisualStyle.MOTION_QUICK)
	tween.tween_interval(VisualStyle.MOTION_STANDARD)
	tween.tween_property(wallet_delta, "modulate:a", 0.0, VisualStyle.MOTION_SLOW)


func _render_status_icons(statuses_value: Variant) -> void:
	FoundationWidgets.clear(status_tray)
	if typeof(statuses_value) != TYPE_ARRAY:
		return
	for status_value in statuses_value:
		if typeof(status_value) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = status_value
		var icon_rect := TextureRect.new()
		icon_rect.texture = UIArtScript.icon(str(status.get("icon", "alert")))
		icon_rect.custom_minimum_size = VisualStyle.ICON_SMALL
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.tooltip_text = str(status.get("tooltip", status.get("label", "")))
		status_tray.add_child(icon_rect)


func _on_time_pressed() -> void:
	time_detail.visible = not time_detail.visible
	time_requested.emit()
