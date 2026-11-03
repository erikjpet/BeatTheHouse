class_name FoundationHudBar
extends PanelContainer

# Main run HUD for money, bankroll, time, Heat, debt, and status feedback,
# including compact layout and reduced-motion behavior.

signal time_requested

const SegmentedMeterScript := preload("res://scripts/ui/segmented_meter.gd")
const UIArtScript := preload("res://scripts/ui/ui_art.gd")
const HudTimeWatchScript := preload("res://scripts/ui/hud_time_watch.gd")
const HeatFeedbackVisualsScript := preload("res://scripts/ui/heat_feedback_visuals.gd")
const MoneyFeedbackViewModelScript := preload("res://scripts/ui/money_feedback_view_model.gd")
const PlayerTextScript := preload("res://scripts/ui/player_text.gd")
const ModalFocusScopeScript := preload("res://scripts/ui/modal_focus_scope.gd")

# The shell reserves the remaining width for its four persistent actions. Text
# must not alter these columns; exact values are available from Run details.
const HUD_VALUE_WIDTH := 60.0
const HUD_CHIPS_WIDTH := 44.0
const HUD_METER_WIDTH := 76.0
const HUD_CLOCK_WIDTH := 146.0

var wallet_value: Label
var wallet_delta: Label
var wallet_delta_icon: TextureRect
var wallet_delta_panel: PanelContainer
var wallet_chip: HBoxContainer
var meta_wallet_chip: HBoxContainer
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
var run_bar: Container
var meta_bar: Container
var landscape_run_bar: HBoxContainer
var landscape_meta_bar: HBoxContainer
var portrait_run_bar: HFlowContainer
var portrait_meta_bar: HFlowContainer
var portrait_layout_enabled := false
var meta_location_value: Label
var meta_gold_value: Label
var meta_goal_value: Label
var reduce_motion := false
var compact_mode := false
var _last_bankroll := 0
var _last_bankroll_delta := 0
var _wallet_delta_tone := ""
const MONEY_FEEDBACK_DURATION_SEC := 1.6
var _money_feedback_elapsed_sec := MONEY_FEEDBACK_DURATION_SEC
var _money_feedback_presentations := 0
var _money_feedback_entries: Array = []
var _has_rendered := false
var _status_icons_key := ""
var _heat_feedback_elapsed_sec := HeatFeedbackVisualsScript.GAIN_DURATION_SEC
var _heat_feedback_amount := 0
var _heat_feedback_intensity := 0.0
var status_button: Button
var meta_details_button: Button
var details_overlay: Control
var details_panel: PanelContainer
var details_scroll: ScrollContainer
var details_text: Label
var details_close: Button
var _details_focus_scope := ModalFocusScopeScript.new()
var _status_details: Array[Dictionary] = []
var _clock_explanation := "Open the day/night schedule."
var _details_opener: Control


func _ready() -> void:
	add_theme_stylebox_override("panel", VisualStyle.state_box("normal"))
	_build()
	visibility_changed.connect(_on_hud_visibility_changed)
	resized.connect(_position_money_feedback)
	set_process(false)


func set_reduce_motion(enabled: bool) -> void:
	if reduce_motion == enabled:
		return
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
	if wallet_delta_icon != null:
		wallet_delta_icon.visible = false
	_money_feedback_elapsed_sec = MONEY_FEEDBACK_DURATION_SEC
	_money_feedback_entries = []
	if wallet_delta_panel != null:
		wallet_delta_panel.modulate.a = 0.0
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
	var meter_size := Vector2(HUD_METER_WIDTH, 14.0 if compact_mode else 18.0)
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
	render_money(bankroll, int(model.get("chips", 0)), bool(model.get("show_chips", false)))

	var heat := float(model.get("heat_level", 0.0))
	heat_meter.configure("heat", heat)
	var heat_text := "%d" % roundi(heat)
	if heat_value.text != heat_text:
		heat_value.text = heat_text
	var drunk := float(model.get("drunk_level", 0.0))
	var pending := float(model.get("pending_drunk_absorption", 0.0))
	drunk_meter.configure("drunk", drunk, pending)
	var drunk_text := "%d%s" % [roundi(drunk), " +%d" % roundi(pending) if pending > 0.0 else ""]
	if drunk_value.text != drunk_text:
		drunk_value.text = drunk_text

	render_clock(model)
	_render_status_icons(model.get("status_icons", []))
	_refresh_open_details()


func render_money(bankroll: int, chips: int, show_chips: bool, bankroll_delta: int = 0) -> void:
	if wallet_value == null:
		return
	render_bankroll(bankroll, bankroll_delta)
	if chips_chip.visible != show_chips:
		chips_chip.visible = show_chips
	var chips_text := "%d" % chips
	if chips_value.text != chips_text:
		chips_value.text = chips_text
	chips_value.tooltip_text = "Chips: " + chips_text
	_refresh_open_details()


func render_bankroll(bankroll: int, _bankroll_delta: int = 0) -> void:
	if wallet_value == null:
		return
	var wallet_text := "$%d" % bankroll
	if wallet_value.text != wallet_text:
		wallet_value.text = wallet_text
		# Refresh the immediate value stack without resetting this clipped label
		# to its 1px text minimum when the balance changes.
		(wallet_value.get_parent() as Container).queue_sort()
		wallet_value.queue_redraw()
	_last_bankroll = bankroll
	_has_rendered = true
	wallet_value.tooltip_text = "Bankroll: " + wallet_text
	_refresh_open_details()


func render_clock(model: Dictionary) -> void:
	if time_watch == null or time_day_label == null or time_exact_label == null or time_button == null or time_detail == null:
		return
	var clock_parts := _clock_parts(model)
	var clock_day := int(clock_parts.get("day", 1))
	var minute_of_day := int(clock_parts.get("minute_of_day", 0))
	var exact_display := str(clock_parts.get("exact_display", "12:00 AM"))
	var day_text := "DAY %d" % clock_day
	if time_day_label.text != day_text:
		time_day_label.text = day_text
	if time_exact_label.text != exact_display:
		time_exact_label.text = exact_display
	time_watch.set_minute_of_day(minute_of_day)
	var clock_tooltip := str(model.get("clock_tooltip", "Open the day/night schedule."))
	_clock_explanation = clock_tooltip
	if time_button.tooltip_text != clock_tooltip:
		time_button.tooltip_text = clock_tooltip
	if time_detail.text != clock_tooltip:
		time_detail.text = clock_tooltip
	_refresh_open_details()


func current_snapshot() -> Dictionary:
	var mode := "meta" if meta_bar != null and meta_bar.visible else "run"
	var snapshot := {
		"rect": get_global_rect(),
		"wallet": wallet_value.text if wallet_value != null else "",
		"wallet_delta": wallet_delta.text if wallet_delta != null else "",
		"wallet_delta_icon": wallet_delta_icon.texture.resource_path if wallet_delta_icon != null and wallet_delta_icon.visible and wallet_delta_icon.texture != null else "",
		"wallet_delta_alpha": wallet_delta.modulate.a if wallet_delta != null else 0.0,
		"wallet_delta_tone": _wallet_delta_tone,
		"wallet_delta_static": reduce_motion,
		"wallet_delta_component": true,
		"wallet_delta_presentations": _money_feedback_presentations,
		"wallet_delta_active": _money_feedback_elapsed_sec < MONEY_FEEDBACK_DURATION_SEC,
		"wallet_delta_rect": wallet_delta_panel.get_global_rect() if wallet_delta_panel != null else Rect2(),
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
		"status_icon_count": _status_details.size(),
		"visible_status_icon_count": status_tray.get_child_count() if status_tray != null else 0,
		"time_interactive": time_button != null and not time_button.disabled,
		"time_day": time_day_label.text if time_day_label != null else "",
		"time_exact": time_exact_label.text if time_exact_label != null else "",
		"time_watch": time_watch.current_snapshot() if time_watch != null else {},
		"time_detail_visible": details_overlay != null and details_overlay.visible,
		"details_visible": details_overlay != null and details_overlay.visible,
		"details_text": details_text.text if details_text != null else "",
		"details_rect": details_panel.get_global_rect() if details_panel != null else Rect2(),
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
			control = status_button
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
	landscape_run_bar = row
	row.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	wallet_chip = _value_chip("wallet", "Bankroll")
	wallet_value = wallet_chip.get_meta("value_label") as Label
	row.add_child(wallet_chip)
	wallet_delta_panel = PanelContainer.new()
	wallet_delta_panel.name = "WalletDelta"
	wallet_delta_panel.custom_minimum_size = Vector2(84, 26)
	wallet_delta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_delta_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_delta_panel.modulate.a = 0.0
	var delta_row := HBoxContainer.new()
	delta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	delta_row.add_theme_constant_override("separation", 4)
	delta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_delta_panel.add_child(delta_row)
	wallet_delta_icon = TextureRect.new()
	wallet_delta_icon.name = "ChipDeltaIcon"
	wallet_delta_icon.texture = UIArtScript.icon("casino_chips")
	wallet_delta_icon.custom_minimum_size = Vector2(18, 18)
	wallet_delta_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallet_delta_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet_delta_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_delta_icon.visible = false
	delta_row.add_child(wallet_delta_icon)
	wallet_delta = FoundationWidgets.label("", VisualStyle.TYPE_MICRO)
	wallet_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_delta.clip_text = true
	wallet_delta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wallet_delta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delta_row.add_child(wallet_delta)
	# A plain Control owns the badge so its text cannot participate in the row's
	# minimum-size calculation. Feedback briefly replaces the caption above the
	# bottom-aligned balance, leaving the current amount readable throughout.
	var feedback_overlay := Control.new()
	feedback_overlay.name = "MoneyFeedbackOverlay"
	feedback_overlay.z_index = 1
	feedback_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback_overlay)
	feedback_overlay.add_child(wallet_delta_panel)
	wallet_delta_panel.position = Vector2.ZERO
	wallet_delta_panel.size = Vector2(84, 26)

	chips_chip = _value_chip("casino_chips", "Chips")
	(chips_chip.get_meta("value_stack") as Control).custom_minimum_size.x = HUD_CHIPS_WIDTH
	chips_value = chips_chip.get_meta("value_label") as Label
	row.add_child(chips_chip)

	var heat_group := _meter_group("heat", "Heat")
	heat_meter = heat_group.get_meta("meter") as SegmentedMeter
	heat_value = heat_group.get_meta("value_label") as Label
	heat_delta_badge = FoundationWidgets.label("", VisualStyle.TYPE_MICRO)
	heat_delta_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	heat_delta_badge.visible = false
	heat_delta_badge.tooltip_text = "Heat gained by the last action."
	heat_delta_badge.clip_text = true
	heat_delta_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FoundationWidgets.set_control_font_color(heat_delta_badge, Color("#ffd166"))
	# This transient badge overlays the meter instead of creating a new
	# minimum-width column when Heat changes.
	heat_meter.add_child(heat_delta_badge)
	heat_delta_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heat_delta_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heat_delta_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(heat_group)

	var drunk_group := _meter_group("drink", "Drunk")
	drunk_meter = drunk_group.get_meta("meter") as SegmentedMeter
	drunk_value = drunk_group.get_meta("value_label") as Label
	row.add_child(drunk_group)

	status_tray = HBoxContainer.new()
	status_tray.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	status_tray.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_button = FoundationWidgets.variant_button("Info", _on_details_pressed)
	status_button.name = "RunDetails"
	status_button.custom_minimum_size = Vector2(64, 40)
	status_button.clip_text = true
	status_button.accessibility_name = "Run details and status effects"
	status_button.tooltip_text = "Read exact values and all status effects."
	row.add_child(status_button)
	status_button.add_child(status_tray)
	status_tray.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_tray.grow_vertical = Control.GROW_DIRECTION_BOTH

	var time_stack := VBoxContainer.new()
	time_stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	time_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(time_stack)
	time_button = FoundationWidgets.variant_button("", _on_time_pressed)
	time_button.custom_minimum_size = Vector2(HUD_CLOCK_WIDTH, 40)
	time_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	time_button.accessibility_name = "Clock and run details"
	time_button.tooltip_text = "Open the day/night schedule."
	var time_margin := MarginContainer.new()
	time_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_margin.add_theme_constant_override("margin_left", VisualStyle.SPACE_3)
	time_margin.add_theme_constant_override("margin_right", VisualStyle.SPACE_3)
	time_margin.add_theme_constant_override("margin_top", 0)
	time_margin.add_theme_constant_override("margin_bottom", 0)
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
	time_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(time_copy)
	time_day_label = FoundationWidgets.muted_label("DAY 1", VisualStyle.TYPE_MICRO)
	time_day_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_day_label.clip_text = true
	time_day_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	time_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_copy.add_child(time_day_label)
	time_exact_label = FoundationWidgets.label("12:00 AM", VisualStyle.TYPE_BODY_LARGE)
	time_exact_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_exact_label.clip_text = true
	time_exact_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	time_exact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_copy.add_child(time_exact_label)
	time_stack.add_child(time_button)
	time_detail = FoundationWidgets.muted_label("", VisualStyle.TYPE_CAPTION)
	time_detail.visible = false
	time_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_detail.custom_minimum_size.x = VisualStyle.TOOLTIP_MAX_WIDTH
	# Retain the source label for snapshot/API compatibility, outside the row.
	feedback_overlay.add_child(time_detail)

	meta_bar = HBoxContainer.new()
	landscape_meta_bar = meta_bar as HBoxContainer
	meta_bar.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	meta_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_bar.visible = false
	add_child(meta_bar)
	var location_chip := _value_chip("home", "Location")
	meta_location_value = location_chip.get_meta("value_label") as Label
	meta_bar.add_child(location_chip)
	var gold_chip := _value_chip("wallet", "Gold")
	meta_wallet_chip = gold_chip
	meta_gold_value = gold_chip.get_meta("value_label") as Label
	meta_bar.add_child(gold_chip)
	var goal_chip := _value_chip("luck", "Next tier")
	meta_goal_value = goal_chip.get_meta("value_label") as Label
	meta_bar.add_child(goal_chip)
	meta_details_button = FoundationWidgets.variant_button("Info", _on_details_pressed)
	meta_details_button.custom_minimum_size = Vector2(64, 40)
	meta_details_button.clip_text = true
	meta_details_button.accessibility_name = "Home details and exact values"
	meta_bar.add_child(meta_details_button)
	_build_details_overlay()
	heat_meter.custom_minimum_size = Vector2(HUD_METER_WIDTH, 14)
	drunk_meter.custom_minimum_size = Vector2(HUD_METER_WIDTH, 14)


func set_portrait_layout(enabled: bool, available_width: float) -> void:
	if landscape_run_bar == null:
		return
	if enabled != portrait_layout_enabled:
		if portrait_run_bar == null:
			portrait_run_bar = _portrait_flow()
			portrait_meta_bar = _portrait_flow()
			add_child(portrait_run_bar)
			add_child(portrait_meta_bar)
		var next_run: Container = portrait_run_bar if enabled else landscape_run_bar
		var next_meta: Container = portrait_meta_bar if enabled else landscape_meta_bar
		_move_row_contents(run_bar, next_run)
		_move_row_contents(meta_bar, next_meta)
		run_bar = next_run
		meta_bar = next_meta
		portrait_layout_enabled = enabled
	var minimum_width := maxf(1.0, available_width) if enabled else 0.0
	if not is_equal_approx(custom_minimum_size.x, minimum_width):
		custom_minimum_size.x = minimum_width


func _portrait_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", VisualStyle.SPACE_5)
	flow.add_theme_constant_override("v_separation", VisualStyle.SPACE_2)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.visible = false
	return flow


func _move_row_contents(source: Container, target: Container) -> void:
	var was_visible := source.visible
	for child in source.get_children():
		child.reparent(target, false)
	source.visible = false
	target.visible = was_visible


func _render_meta(model: Dictionary) -> void:
	_set_meta_mode(true)
	meta_location_value.text = str(model.get("location_text", "Home"))
	meta_gold_value.text = str(model.get("gold_text", "%dg" % int(model.get("gold", 0))))
	meta_goal_value.text = str(model.get("next_goal_text", "Top tier"))
	_refresh_open_details()


func _set_meta_mode(enabled: bool) -> void:
	if run_bar != null and run_bar.visible == enabled:
		run_bar.visible = not enabled
	if meta_bar != null and meta_bar.visible != enabled:
		meta_bar.visible = enabled
	call_deferred("_position_money_feedback")


func _position_money_feedback() -> void:
	var target := meta_wallet_chip if meta_bar != null and meta_bar.visible else wallet_chip
	if wallet_delta_panel != null and target != null and target.is_inside_tree():
		wallet_delta_panel.global_position = target.global_position


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
	icon_rect.custom_minimum_size = VisualStyle.ICON_SMALL
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon_rect)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = HUD_VALUE_WIDTH
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	chip.add_child(stack)
	var title_label := FoundationWidgets.muted_label(title, VisualStyle.TYPE_MICRO)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(title_label)
	var value_label := FoundationWidgets.label("", VisualStyle.TYPE_BODY_LARGE)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack.add_child(value_label)
	chip.set_meta("value_label", value_label)
	chip.set_meta("value_stack", stack)
	return chip


func _meter_group(icon_id: String, title: String) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	var icon_rect := TextureRect.new()
	icon_rect.texture = UIArtScript.icon(icon_id)
	icon_rect.custom_minimum_size = VisualStyle.ICON_SMALL
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon_rect)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = HUD_METER_WIDTH
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	group.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	stack.add_child(heading_row)
	var title_label := FoundationWidgets.muted_label(title, VisualStyle.TYPE_MICRO)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.custom_minimum_size.x = 42.0
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_row.add_child(title_label)
	var value_label := FoundationWidgets.label("", VisualStyle.TYPE_CAPTION)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.clip_text = true
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_row.add_child(value_label)
	var meter: SegmentedMeter = SegmentedMeterScript.new()
	meter.custom_minimum_size = Vector2(HUD_METER_WIDTH, 14)
	stack.add_child(meter)
	group.set_meta("meter", meter)
	group.set_meta("value_label", value_label)
	group.set_meta("heading_row", heading_row)
	return group


func _process(delta: float) -> void:
	if _money_feedback_elapsed_sec < MONEY_FEEDBACK_DURATION_SEC:
		_money_feedback_elapsed_sec += maxf(0.0, delta)
		var remaining := MONEY_FEEDBACK_DURATION_SEC - _money_feedback_elapsed_sec
		wallet_delta_panel.modulate.a = 1.0 if reduce_motion and remaining > 0.0 else clampf(remaining / 0.22, 0.0, 1.0)
		if remaining <= 0.0:
			_money_feedback_entries = []
	if _heat_feedback_active():
		_heat_feedback_elapsed_sec += maxf(0.0, delta)
		if not _heat_feedback_active():
			_cancel_heat_feedback()
		else:
			_update_heat_feedback_presentation()
	set_process(_heat_feedback_active() or _money_feedback_elapsed_sec < MONEY_FEEDBACK_DURATION_SEC)


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
	set_process(_money_feedback_elapsed_sec < MONEY_FEEDBACK_DURATION_SEC)
	if heat_meter != null:
		heat_meter.set_feedback_pulse(0, 0.0)
	if heat_delta_badge != null:
		heat_delta_badge.visible = false
		heat_delta_badge.text = ""
		heat_delta_badge.modulate = Color.WHITE


# Only applied-event delivery calls this method. Rendering balances, restoring
# a save, and refreshing the HUD cannot manufacture or replay a money event.
func present_money_feedback(entries: Array) -> void:
	if entries.is_empty() or wallet_delta_panel == null:
		return
	var visible: Array = _money_feedback_entries if _money_feedback_elapsed_sec < MONEY_FEEDBACK_DURATION_SEC else []
	_money_feedback_entries = MoneyFeedbackViewModelScript.accumulate_visible(visible, entries)
	entries = _money_feedback_entries
	var amounts: PackedStringArray = []
	var tone := str((entries[0] as Dictionary).get("tone", "text_muted"))
	var has_chips := false
	for entry_value in entries:
		var entry: Dictionary = entry_value
		amounts.append(str(entry.get("text", "")))
		has_chips = has_chips or str(entry.get("currency", "")) == "chips"
		if str(entry.get("tone", "text_muted")) != tone:
			tone = "text_muted"
	wallet_delta.text = "  ".join(amounts)
	wallet_delta_icon.visible = has_chips
	_wallet_delta_tone = tone
	var accent := VisualStyle.role(tone)
	var style := VisualStyle.pixel_box(VisualStyle.DARK_2, accent, 2)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	wallet_delta_panel.add_theme_stylebox_override("panel", style)
	# A Control retains a prior larger theme minimum after that theme changes.
	# Reapply the bounded badge size once its compact style is installed.
	wallet_delta_panel.size = Vector2(84, 26)
	FoundationWidgets.set_control_font_color(wallet_delta, accent)
	wallet_delta.modulate = Color.WHITE
	wallet_delta_panel.modulate.a = 1.0
	_position_money_feedback()
	_money_feedback_elapsed_sec = 0.0
	_money_feedback_presentations += 1
	_refresh_open_details()
	set_process(true)


func _render_status_icons(statuses_value: Variant) -> void:
	if typeof(statuses_value) != TYPE_ARRAY:
		if not _status_icons_key.is_empty():
			FoundationWidgets.clear(status_tray)
			_status_icons_key = ""
		_status_details.clear()
		status_button.text = "Info"
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
	_status_details.clear()
	for status_value in statuses:
		if typeof(status_value) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = status_value
		_status_details.append(status.duplicate(true))
		if status_tray.get_child_count() >= 2:
			continue
		var icon_rect := TextureRect.new()
		icon_rect.set_meta("status_id", str(status.get("id", "")))
		icon_rect.texture = UIArtScript.icon(str(status.get("icon", "alert")))
		icon_rect.custom_minimum_size = VisualStyle.ICON_SMALL
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.tooltip_text = str(status.get("tooltip", status.get("label", "")))
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_tray.add_child(icon_rect)
	status_button.text = "Info" if _status_details.is_empty() else ""
	status_button.tooltip_text = "Run details: %d status effects. Read all exact values and effects." % _status_details.size()
	status_button.accessibility_name = "Run details, %d status effects" % _status_details.size()


func _on_time_pressed() -> void:
	if bool(time_button.get_meta("bth31_canceled_gesture", false)):
		return
	_open_details(time_button)
	time_requested.emit()


func _on_details_pressed() -> void:
	_open_details(meta_details_button if meta_bar.visible else status_button)


func _build_details_overlay() -> void:
	# The pinned Web runtime omits CanvasLayer. A top-level Control remains a
	# separate GUI root outside the clipped HUD's layout and transform hierarchy,
	# while staying owned by the HUD for visibility, focus and lifetime cleanup.
	details_overlay = Control.new()
	details_overlay.name = "HudDetails"
	details_overlay.set_as_top_level(true)
	details_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	details_overlay.z_as_relative = false
	details_overlay.z_index = 4095
	details_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	details_overlay.visible = false
	add_child(details_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_on_details_shade_input)
	details_overlay.add_child(shade)
	details_panel = PanelContainer.new()
	details_panel.add_theme_stylebox_override("panel", VisualStyle.state_box("normal"))
	details_overlay.add_child(details_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	details_panel.add_child(stack)
	var heading := FoundationWidgets.label("Run details", VisualStyle.TYPE_HEADING)
	heading.name = "HudDetailsHeading"
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.clip_text = true
	stack.add_child(heading)
	details_scroll = ScrollContainer.new()
	details_scroll.name = "HudDetailsScroll"
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.follow_focus = true
	details_scroll.focus_mode = Control.FOCUS_ALL
	details_scroll.accessibility_name = "Exact values and status effects; scroll to read"
	stack.add_child(details_scroll)
	details_text = FoundationWidgets.label("", VisualStyle.TYPE_BODY_LARGE)
	details_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_scroll.add_child(details_text)
	details_close = FoundationWidgets.variant_button("Close", close_details)
	details_close.name = "CloseHudDetails"
	details_close.custom_minimum_size.y = 52
	stack.add_child(details_close)
	get_viewport().size_changed.connect(_layout_details)
	_layout_details()
	set_process_input(true)


func _open_details(opener: Control) -> void:
	if details_overlay == null:
		return
	_details_opener = opener
	_refresh_details_text()
	details_overlay.show()
	_layout_details()
	details_scroll.scroll_vertical = 0
	_details_focus_scope.push_scope(details_overlay, details_close, opener, [details_scroll, details_close])


func close_details() -> void:
	if details_overlay == null or not details_overlay.visible:
		return
	details_overlay.hide()
	_details_focus_scope.pop_scope(details_overlay)
	_details_opener = null


func details_is_visible() -> bool:
	return details_overlay != null and details_overlay.visible


func _layout_details() -> void:
	if details_panel == null or not is_inside_tree():
		return
	var available := get_viewport_rect().size
	details_overlay.position = Vector2.ZERO
	details_overlay.size = available
	var panel_size := Vector2(minf(600.0, maxf(1.0, available.x - 32.0)), minf(520.0, maxf(1.0, available.y - 32.0)))
	details_panel.position = (available - panel_size) * 0.5
	details_panel.size = panel_size


func _refresh_open_details() -> void:
	if details_overlay != null and details_overlay.visible:
		_refresh_details_text()


func _refresh_details_text() -> void:
	if details_text == null:
		return
	var lines: PackedStringArray = []
	if meta_bar != null and meta_bar.visible:
		for field in _meta_field_snapshot():
			lines.append("%s: %s" % [str(field.get("label", "")), str(field.get("value", ""))])
	else:
		lines.append("Bankroll: " + wallet_value.text)
		if chips_chip.visible:
			lines.append("Chips: " + chips_value.text)
		lines.append("Heat: " + heat_value.text)
		if _heat_feedback_amount > 0:
			lines.append("Last Heat gain: +%d" % _heat_feedback_amount)
		lines.append("Drunk: " + drunk_value.text)
		lines.append("%s, %s" % [time_day_label.text, time_exact_label.text])
		lines.append(_clock_explanation)
		for status in _status_details:
			lines.append("%s: %s" % [str(status.get("label", status.get("id", "Status"))), str(status.get("tooltip", ""))])
	if not wallet_delta.text.is_empty():
		lines.append("Last money change: " + wallet_delta.text)
	details_text.text = "\n\n".join(lines)


func _on_details_shade_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed()) \
			or (event is InputEventScreenTouch and event.is_pressed()):
		close_details()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if details_overlay == null or not details_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_details()
		get_viewport().set_input_as_handled()
		return
	if event.is_pressed() and get_viewport().gui_get_focus_owner() == details_scroll:
		var amount := 0
		if event.is_action_pressed("ui_up"):
			amount = -40
		elif event.is_action_pressed("ui_down"):
			amount = 40
		elif event.is_action_pressed("ui_page_up"):
			amount = -int(details_scroll.size.y)
		elif event.is_action_pressed("ui_page_down"):
			amount = int(details_scroll.size.y)
		if amount != 0:
			details_scroll.scroll_vertical += amount
			get_viewport().set_input_as_handled()
			return
	_details_focus_scope.handle_input(event)


func _on_hud_visibility_changed() -> void:
	if not is_visible_in_tree():
		close_details()


func _exit_tree() -> void:
	if details_overlay != null:
		_details_focus_scope.pop_scope(details_overlay)
	_details_focus_scope.clear()


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
	return PlayerTextScript.format_time_of_day(minute_of_day)
