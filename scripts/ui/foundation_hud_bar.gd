class_name FoundationHudBar
extends PanelContainer

signal time_requested

const SegmentedMeterScript := preload("res://scripts/ui/segmented_meter.gd")
const UIArtScript := preload("res://scripts/ui/ui_art.gd")
const HudTimeWatchScript := preload("res://scripts/ui/hud_time_watch.gd")
const HeatFeedbackVisualsScript := preload("res://scripts/ui/heat_feedback_visuals.gd")

var wallet_value: Label
var wallet_delta: Label
var chips_chip: HBoxContainer
var chips_value: Label
var heat_meter: SegmentedMeter
var heat_value: Label
var heat_delta_badge: Label
var drunk_meter: SegmentedMeter
var drunk_value: Label
var status_tray: HBoxContainer
var time_button: Button
var time_watch: HudTimeWatch
var time_day_label: Label
var time_exact_label: Label
var time_detail: Label
var run_bar: HBoxContainer
var meta_bar: HBoxContainer
var meta_location_value: Label
var meta_gold_value: Label
var meta_goal_value: Label
var reduce_motion := false
var compact_mode := false
var _last_bankroll := 0
var _last_bankroll_delta := 0
var _wallet_delta_tone := ""
var _has_rendered := false
var _status_icons_key := ""
var _heat_feedback_elapsed_sec := HeatFeedbackVisualsScript.GAIN_DURATION_SEC
var _heat_feedback_amount := 0
var _heat_feedback_intensity := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", VisualStyle.state_box("normal"))
	_build()
	set_process(false)


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	_update_heat_feedback_presentation()


func reset_wallet_delta() -> void:
	_last_bankroll = 0
	_last_bankroll_delta = 0
	_wallet_delta_tone = ""
	_has_rendered = false
	if wallet_delta != null:
		wallet_delta.text = ""
		wallet_delta.modulate = Color.WHITE
	cancel_heat_feedback()


func cancel_heat_feedback() -> void:
	_cancel_heat_feedback()


func present_heat_gain(applied_amount: int) -> void:
	if applied_amount <= 0:
		return
	_heat_feedback_amount = mini(100, _heat_feedback_amount + applied_amount) if _heat_feedback_active() else mini(100, applied_amount)
	_heat_feedback_intensity = HeatFeedbackVisualsScript.heat_gain_intensity(_heat_feedback_amount)
	_heat_feedback_elapsed_sec = 0.0
	if heat_delta_badge != null:
		heat_delta_badge.text = "+%d" % _heat_feedback_amount
		heat_delta_badge.visible = true
	set_process(true)
	_update_heat_feedback_presentation()


func set_compact_mode(enabled: bool) -> void:
	if compact_mode == enabled:
		return
	compact_mode = enabled
	var meter_size := VisualStyle.HUD_METER_COMPACT_SIZE if compact_mode else VisualStyle.HUD_METER_SIZE
	if heat_meter != null:
		heat_meter.custom_minimum_size = meter_size
	if drunk_meter != null:
		drunk_meter.custom_minimum_size = meter_size


func render(model: Dictionary) -> void:
	if wallet_value == null:
		return
	if str(model.get("mode", "run")) == "meta":
		_render_meta(model)
		return
	_set_meta_mode(false)
	var bankroll := int(model.get("bankroll", 0))
	wallet_value.text = "$%d" % bankroll
	var observed_delta := bankroll - _last_bankroll if _has_rendered else 0
	var bankroll_delta := int(model.get("bankroll_delta", observed_delta))
	if bankroll_delta == 0:
		bankroll_delta = observed_delta
	if bankroll_delta != 0:
		_last_bankroll_delta = bankroll_delta
	_render_delta(_last_bankroll_delta)
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

	render_clock(model)
	_render_status_icons(model.get("status_icons", []))


func render_clock(model: Dictionary) -> void:
	if time_watch == null or time_day_label == null or time_exact_label == null or time_button == null or time_detail == null:
		return
	var clock_parts := _clock_parts(model)
	var clock_day := int(clock_parts.get("day", 1))
	var minute_of_day := int(clock_parts.get("minute_of_day", 0))
	var exact_display := str(clock_parts.get("exact_display", "12:00 AM"))
	time_day_label.text = "DAY %d" % clock_day
	time_exact_label.text = exact_display
	time_watch.set_minute_of_day(minute_of_day)
	time_button.tooltip_text = str(model.get("clock_tooltip", "Open the day/night schedule."))
	time_detail.text = time_button.tooltip_text


func current_snapshot() -> Dictionary:
	var mode := "meta" if meta_bar != null and meta_bar.visible else "run"
	var snapshot := {
		"rect": get_global_rect(),
		"wallet": wallet_value.text if wallet_value != null else "",
		"wallet_delta": wallet_delta.text if wallet_delta != null else "",
		"wallet_delta_alpha": wallet_delta.modulate.a if wallet_delta != null else 0.0,
		"wallet_delta_tone": _wallet_delta_tone,
		"wallet_delta_static": true,
		"chips_visible": chips_chip != null and chips_chip.visible,
		"chips": chips_value.text if chips_value != null else "",
		"heat": heat_meter.current_snapshot() if heat_meter != null else {},
		"heat_delta_badge": heat_delta_badge.text if heat_delta_badge != null and heat_delta_badge.visible else "",
		"heat_feedback_active": _heat_feedback_active(),
		"heat_feedback_amount": _heat_feedback_amount,
		"heat_feedback_intensity": _heat_feedback_intensity,
		"heat_feedback_elapsed_sec": _heat_feedback_elapsed_sec,
		"heat_feedback_duration_sec": HeatFeedbackVisualsScript.GAIN_DURATION_SEC,
		"drunk": drunk_meter.current_snapshot() if drunk_meter != null else {},
		"status_icon_count": status_tray.get_child_count() if status_tray != null else 0,
		"time_interactive": time_button != null and not time_button.disabled,
		"time_day": time_day_label.text if time_day_label != null else "",
		"time_exact": time_exact_label.text if time_exact_label != null else "",
		"time_watch": time_watch.current_snapshot() if time_watch != null else {},
		"time_detail_visible": time_detail != null and time_detail.visible,
		"compact_mode": compact_mode,
		"reduce_motion": reduce_motion,
	}
	if mode == "meta":
		snapshot["mode"] = mode
		snapshot["meta_fields"] = _meta_field_snapshot()
	return snapshot


# Returns the rectangle of the control the player actually sees. Tutorial
# focus must never target the hidden legacy status label that predates this HUD.
func global_rect_for_element(element_id: String) -> Rect2:
	var control: Control
	match element_id.strip_edges().to_lower():
		"heat":
			control = heat_meter
		"chips":
			control = chips_chip
		"clock":
			control = time_button
		"debt":
			control = status_tray
		_:
			control = self
	if control != null and control.is_visible_in_tree():
		var rect := control.get_global_rect()
		if rect.has_area():
			return rect
	return get_global_rect() if is_visible_in_tree() else Rect2()


func _build() -> void:
	var row := HBoxContainer.new()
	run_bar = row
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
	var heat_heading_row := heat_group.get_meta("heading_row") as HBoxContainer
	heat_delta_badge = FoundationWidgets.label("", VisualStyle.TYPE_MICRO)
	heat_delta_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	heat_delta_badge.visible = false
	heat_delta_badge.tooltip_text = "Heat gained by the last action."
	FoundationWidgets.set_control_font_color(heat_delta_badge, Color("#ffd166"))
	heat_heading_row.add_child(heat_delta_badge)
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
	time_button.custom_minimum_size = VisualStyle.HUD_TIME_WIDGET_SIZE
	time_button.tooltip_text = "Open the day/night schedule."
	var time_margin := MarginContainer.new()
	time_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_margin.add_theme_constant_override("margin_left", VisualStyle.SPACE_3)
	time_margin.add_theme_constant_override("margin_right", VisualStyle.SPACE_3)
	time_margin.add_theme_constant_override("margin_top", VisualStyle.SPACE_3)
	time_margin.add_theme_constant_override("margin_bottom", VisualStyle.SPACE_3)
	time_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_button.add_child(time_margin)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_margin.add_child(time_row)
	time_watch = HudTimeWatchScript.new()
	time_row.add_child(time_watch)
	var time_copy := VBoxContainer.new()
	time_copy.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	time_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(time_copy)
	time_day_label = FoundationWidgets.muted_label("DAY 1", VisualStyle.TYPE_MICRO)
	time_day_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_copy.add_child(time_day_label)
	time_exact_label = FoundationWidgets.label("12:00 AM", VisualStyle.TYPE_BODY_LARGE)
	time_exact_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_exact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_copy.add_child(time_exact_label)
	time_stack.add_child(time_button)
	time_detail = FoundationWidgets.muted_label("", VisualStyle.TYPE_CAPTION)
	time_detail.visible = false
	time_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_detail.custom_minimum_size.x = VisualStyle.TOOLTIP_MAX_WIDTH
	time_stack.add_child(time_detail)

	meta_bar = HBoxContainer.new()
	meta_bar.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	meta_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_bar.visible = false
	add_child(meta_bar)
	var location_chip := _value_chip("home", "Location")
	meta_location_value = location_chip.get_meta("value_label") as Label
	meta_bar.add_child(location_chip)
	var gold_chip := _value_chip("wallet", "Gold")
	meta_gold_value = gold_chip.get_meta("value_label") as Label
	meta_bar.add_child(gold_chip)
	var goal_chip := _value_chip("luck", "Next tier")
	meta_goal_value = goal_chip.get_meta("value_label") as Label
	meta_bar.add_child(goal_chip)


func _render_meta(model: Dictionary) -> void:
	_set_meta_mode(true)
	meta_location_value.text = str(model.get("location_text", "Home"))
	meta_gold_value.text = str(model.get("gold_text", "%dg" % int(model.get("gold", 0))))
	meta_goal_value.text = str(model.get("next_goal_text", "Top tier"))
	reset_wallet_delta()


func _set_meta_mode(enabled: bool) -> void:
	if run_bar != null:
		run_bar.visible = not enabled
	if meta_bar != null:
		meta_bar.visible = enabled


func _meta_field_snapshot() -> Array:
	if meta_bar == null or not meta_bar.visible:
		return []
	return [
		{"id": "location", "label": "Location", "value": meta_location_value.text if meta_location_value != null else ""},
		{"id": "gold", "label": "Gold", "value": meta_gold_value.text if meta_gold_value != null else ""},
		{"id": "next_tier", "label": "Next tier", "value": meta_goal_value.text if meta_goal_value != null else ""},
	]


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
	group.set_meta("heading_row", heading_row)
	return group


func _process(delta: float) -> void:
	if not _heat_feedback_active():
		set_process(false)
		return
	_heat_feedback_elapsed_sec += maxf(0.0, delta)
	if not _heat_feedback_active():
		_cancel_heat_feedback()
		return
	_update_heat_feedback_presentation()


func _update_heat_feedback_presentation() -> void:
	if heat_meter == null:
		return
	if not _heat_feedback_active():
		heat_meter.set_feedback_pulse(0, 0.0)
		if heat_delta_badge != null:
			heat_delta_badge.visible = false
		return
	var strength := 0.72 if reduce_motion else _heat_feedback_strength()
	heat_meter.set_feedback_pulse(_heat_feedback_amount, strength)
	if heat_delta_badge != null:
		heat_delta_badge.visible = true
		heat_delta_badge.text = "+%d" % _heat_feedback_amount
		var badge_alpha := 1.0 if reduce_motion else clampf(strength * 1.35, 0.0, 1.0)
		heat_delta_badge.modulate = Color(1.0, 1.0, 1.0, badge_alpha)


func _heat_feedback_strength() -> float:
	return HeatFeedbackVisualsScript.heat_gain_pulse_strength(_heat_feedback_elapsed_sec)


func _heat_feedback_active() -> bool:
	return _heat_feedback_amount > 0 and _heat_feedback_elapsed_sec < HeatFeedbackVisualsScript.GAIN_DURATION_SEC


func _cancel_heat_feedback() -> void:
	_heat_feedback_elapsed_sec = HeatFeedbackVisualsScript.GAIN_DURATION_SEC
	_heat_feedback_amount = 0
	_heat_feedback_intensity = 0.0
	set_process(false)
	if heat_meter != null:
		heat_meter.set_feedback_pulse(0, 0.0)
	if heat_delta_badge != null:
		heat_delta_badge.visible = false
		heat_delta_badge.text = ""
		heat_delta_badge.modulate = Color.WHITE


func _render_delta(delta: int) -> void:
	wallet_delta.text = "%+d" % delta if delta != 0 else ""
	if delta == 0:
		_wallet_delta_tone = ""
		wallet_delta.modulate = Color.WHITE
		return
	_wallet_delta_tone = "success" if delta > 0 else "danger"
	FoundationWidgets.set_control_font_color(wallet_delta, VisualStyle.role(_wallet_delta_tone))
	wallet_delta.modulate = Color(Color.WHITE, VisualStyle.HUD_LAST_DELTA_ALPHA)


func _render_status_icons(statuses_value: Variant) -> void:
	if typeof(statuses_value) != TYPE_ARRAY:
		if not _status_icons_key.is_empty():
			FoundationWidgets.clear(status_tray)
			_status_icons_key = ""
		return
	var statuses: Array = statuses_value
	var key_parts: Array[String] = []
	for status_value in statuses:
		if typeof(status_value) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = status_value
		key_parts.append("%s|%s|%s" % [
			str(status.get("id", "")),
			str(status.get("icon", "alert")),
			str(status.get("tooltip", status.get("label", ""))),
		])
	var next_key := "\n".join(key_parts)
	if next_key == _status_icons_key:
		return
	_status_icons_key = next_key
	FoundationWidgets.clear(status_tray)
	for status_value in statuses:
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


func _clock_parts(model: Dictionary) -> Dictionary:
	if model.has("clock_day") and model.has("clock_minute_of_day"):
		var authoritative_minute := posmod(int(model.get("clock_minute_of_day", 0)), 1440)
		return {
			"day": maxi(1, int(model.get("clock_day", 1))),
			"minute_of_day": authoritative_minute,
			"exact_display": str(model.get("clock_exact_display", _exact_time_label(authoritative_minute))),
		}
	var display := str(model.get("clock_display", "Day 1 12 AM")).replace("·", " ")
	var tokens := display.split(" ", false)
	var day := 1
	var period := "AM"
	var hour := 12
	var minute := 0
	for index in range(tokens.size()):
		var token := str(tokens[index])
		if token.to_lower() in ["day", "night"] and index + 1 < tokens.size() and str(tokens[index + 1]).is_valid_int():
			day = maxi(1, int(tokens[index + 1]))
		if token.to_upper() in ["AM", "PM"]:
			period = token.to_upper()
			if index > 0:
				var time_parts := str(tokens[index - 1]).split(":", false)
				if not time_parts.is_empty() and str(time_parts[0]).is_valid_int():
					hour = clampi(int(time_parts[0]), 1, 12)
				if time_parts.size() > 1 and str(time_parts[1]).is_valid_int():
					minute = clampi(int(time_parts[1]), 0, 59)
	var hour_24 := hour % 12
	if period == "PM":
		hour_24 += 12
	var minute_of_day := hour_24 * 60 + minute
	return {
		"day": day,
		"minute_of_day": minute_of_day,
		"exact_display": _exact_time_label(minute_of_day),
	}


func _exact_time_label(minute_of_day: int) -> String:
	var normalized := posmod(minute_of_day, 1440)
	var hour_24 := int(floor(float(normalized) / 60.0))
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, normalized % 60, "AM" if hour_24 < 12 else "PM"]
