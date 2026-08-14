class_name StreetsController
extends RefCounted

signal action_requested(action: Dictionary)

const StreetsViewModelScript := preload("res://scripts/ui/streets_view_model.gd")

const COLOR_INK := Color("#070812")
const COLOR_PANEL := Color("#101427")
const COLOR_STREET := Color("#252d45")
const COLOR_BUILDING := Color("#090b13")
const COLOR_PLAYER := Color("#f7d66b")
const COLOR_PATROL := Color("#ef516d")
const COLOR_CROWD := Color("#6b4f91")
const COLOR_DARK := Color("#111522")
const COLOR_STASH := Color("#4dc6a4")
const COLOR_DESTINATION := Color("#5ec8ef")

var overlay: Control
var title_label: Label
var objective_label: Label
var condition_label: Label
var status_label: Label
var message_label: Label
var grid: GridContainer
var pace_button: Button
var verb_row: HBoxContainer
var liveness_indicator: Label
var cell_buttons: Array[Button] = []
var verb_buttons: Dictionary = {}
var model: Dictionary = {}
var board_key := ""
var pace := "walk"
var pulse_baseline_alpha := 0.35
var pulse_tween: Tween


func build(parent: Node) -> void:
	if overlay != null or parent == null:
		return
	overlay = Control.new()
	overlay.name = "StreetsOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color("#02030a", 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 650)
	panel.add_theme_stylebox_override("panel", _box(COLOR_PANEL, COLOR_DESTINATION, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	stack.add_child(heading)
	title_label = _label("THE STREETS", 25, COLOR_PLAYER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	liveness_indicator = _label("◆ BLUE LIGHTS", 14, COLOR_PATROL)
	liveness_indicator.modulate.a = pulse_baseline_alpha
	heading.add_child(liveness_indicator)
	objective_label = _label("", 16, Color("#e7e9f5"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(objective_label)
	var conditions_row := HBoxContainer.new()
	stack.add_child(conditions_row)
	condition_label = _label("", 13, COLOR_DESTINATION)
	condition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conditions_row.add_child(condition_label)
	status_label = _label("", 13, COLOR_PLAYER)
	conditions_row.add_child(status_label)
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(board_center)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	board_center.add_child(grid)
	message_label = _label("Click the next intersection. Keep it quiet.", 13, Color("#c7cada"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(message_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 7)
	stack.add_child(controls)
	pace_button = _action_button("PACE: WALK")
	pace_button.pressed.connect(_toggle_pace)
	controls.add_child(pace_button)
	verb_row = HBoxContainer.new()
	verb_row.add_theme_constant_override("separation", 7)
	controls.add_child(verb_row)
	for verb in ["wait", "duck", "stash", "signal", "assist", "ditch"]:
		var button := _action_button(str(verb).to_upper())
		button.pressed.connect(_request_verb.bind(str(verb)))
		verb_buttons[verb] = button
		verb_row.add_child(button)


func show_snapshot(snapshot: Dictionary, message: String = "") -> void:
	if overlay == null:
		return
	model = StreetsViewModelScript.build(snapshot)
	if model.is_empty():
		hide()
		return
	var next_board_key := "%s:%d:%d" % [str(model.get("route_id", "streets")), int(model.get("width", 1)), int(model.get("height", 1))]
	if next_board_key != board_key:
		_build_board(int(model.get("width", 1)), int(model.get("height", 1)))
		board_key = next_board_key
	_render()
	if not message.is_empty():
		message_label.text = message
	_start_idle_pulse()
	overlay.visible = true
	overlay.move_to_front()


func hide() -> void:
	_stop_idle_pulse()
	if overlay != null:
		overlay.visible = false


func is_visible() -> bool:
	return overlay != null and overlay.visible


# Returns movement measured from the actual pulsing label property. The label
# is driven by an engine tween, so no script process or per-frame allocation is
# required while the board sits open.
func measured_idle_liveness() -> float:
	if liveness_indicator == null or not is_instance_valid(liveness_indicator):
		return 0.0
	return absf(liveness_indicator.modulate.a - pulse_baseline_alpha)


func idle_animation_running() -> bool:
	return pulse_tween != null and pulse_tween.is_valid() and pulse_tween.is_running()


func _build_board(width: int, height: int) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cell_buttons.clear()
	grid.columns = width
	var horizontal_budget := (790.0 - (float(maxi(1, width) - 1) * 3.0)) / float(maxi(1, width))
	var vertical_budget := (360.0 - (float(maxi(1, height) - 1) * 3.0)) / float(maxi(1, height))
	var cell_size := clampf(minf(horizontal_budget, vertical_budget), 34.0, 62.0)
	for index in range(width * height):
		var button := Button.new()
		button.custom_minimum_size = Vector2(cell_size, cell_size)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_cell_pressed.bind(index))
		cell_buttons.append(button)
		grid.add_child(button)


func _render() -> void:
	title_label.text = str(model.get("title", "THE STREETS"))
	objective_label.text = str(model.get("objective", ""))
	condition_label.text = str(model.get("condition_line", ""))
	status_label.text = str(model.get("status_line", ""))
	var cells: Array = model.get("cells", []) if typeof(model.get("cells", [])) == TYPE_ARRAY else []
	for index in range(cell_buttons.size()):
		var button := cell_buttons[index]
		if index >= cells.size():
			button.visible = false
			continue
		var cell: Dictionary = cells[index]
		button.visible = true
		button.text = str(cell.get("glyph", "·"))
		button.tooltip_text = str(cell.get("tooltip", "Street"))
		button.disabled = not bool(cell.get("passable", false))
		button.set_meta("x", int(cell.get("x", 0)))
		button.set_meta("y", int(cell.get("y", 0)))
		var color := _tone_color(str(cell.get("tone", "street")))
		button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.16), 1))
		button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), COLOR_PLAYER, 2))
		button.add_theme_stylebox_override("pressed", _box(color.darkened(0.08), COLOR_DESTINATION, 2))
	var legal: Array = model.get("legal_actions", []) if typeof(model.get("legal_actions", [])) == TYPE_ARRAY else []
	for verb in verb_buttons.keys():
		var button: Button = verb_buttons[verb]
		button.visible = legal.has(str(verb))
	if verb_buttons.has("assist"):
		var assist_button: Button = verb_buttons["assist"]
		assist_button.text = "CREW ASSIST"


func _cell_pressed(index: int) -> void:
	if index < 0 or index >= cell_buttons.size():
		return
	var button := cell_buttons[index]
	var action := StreetsViewModelScript.move_action(model, int(button.get_meta("x", 0)), int(button.get_meta("y", 0)), pace)
	if action.is_empty():
		message_label.text = "One corner at a time."
		return
	action_requested.emit(action)


func _toggle_pace() -> void:
	pace = "run" if pace == "walk" else "walk"
	pace_button.text = "PACE: %s" % pace.to_upper()


func _request_verb(verb: String) -> void:
	var action := {"verb": verb}
	if verb == "assist":
		var used: Array = model.get("used_assists", []) if typeof(model.get("used_assists", [])) == TYPE_ARRAY else []
		for assist_id in model.get("assists", []):
			if not used.has(assist_id):
				action["assist_id"] = assist_id
				break
	action_requested.emit(action)


func _start_idle_pulse() -> void:
	if liveness_indicator == null:
		return
	if idle_animation_running():
		return
	_stop_idle_pulse()
	pulse_tween = liveness_indicator.create_tween().set_loops()
	pulse_tween.tween_property(liveness_indicator, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(liveness_indicator, "modulate:a", pulse_baseline_alpha, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null
	if liveness_indicator != null and is_instance_valid(liveness_indicator):
		liveness_indicator.modulate.a = pulse_baseline_alpha


static func _tone_color(tone: String) -> Color:
	match tone:
		"building":
			return COLOR_BUILDING
		"player", "stop_done":
			return COLOR_PLAYER.darkened(0.35)
		"patrol":
			return COLOR_PATROL.darkened(0.35)
		"crowd":
			return COLOR_CROWD
		"blackout":
			return COLOR_DARK
		"stash":
			return COLOR_STASH.darkened(0.35)
		"destination", "stop":
			return COLOR_DESTINATION.darkened(0.4)
		_:
			return COLOR_STREET


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func _action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116, 40)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _box(Color("#171d33"), Color("#536589"), 1))
	button.add_theme_stylebox_override("hover", _box(Color("#263453"), COLOR_DESTINATION, 2))
	button.add_theme_stylebox_override("pressed", _box(Color("#101526"), COLOR_PLAYER, 2))
	return button


static func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	return box
