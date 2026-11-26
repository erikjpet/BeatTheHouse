class_name CrtPracticeMenu
extends VBoxContainer

signal user_selection_changed(game_id: String)
signal launch_accepted(game_id: String)

# Presentation only. FoundationMain owns generation and suspended save state.
# The complete 4:3 image and its input use the same barrel/analog transform.
const DISPLAY_SIZE := Vector2(768, 576)
const CURVATURE := 0.055
const CORNER_RADIUS := 0.065
const SCREEN_FILL := Color("#101024")
const PANEL_FILL := Color("#201b39")
const GLASS_SHADER := preload("res://scripts/ui/crt_practice_screen.gdshader")
const SCAN_SWEEP_SECONDS := 3.4
const SCAN_CYCLE_SECONDS := 9.0

class TelevisionCabinet extends Control:
	var glass_rect := Rect2()
	var cabinet_rect := Rect2()
	var console_rect := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#100e1b"))
		for row in range(0, int(size.y), 24):
			draw_line(Vector2(0, row), Vector2(size.x, row), Color("#191526"), 1)
		var shadow := cabinet_rect.grow(7)
		shadow.position += Vector2(0, 5)
		draw_rect(shadow, Color("#080712"))
		draw_rect(cabinet_rect, Color("#302b38"))
		draw_rect(cabinet_rect.grow(-3), Color("#736474"), false, 3)
		draw_rect(cabinet_rect.grow(-8), Color("#494050"), false, 2)
		draw_rect(glass_rect.grow(8), Color("#100e1c"))
		draw_rect(glass_rect.grow(4), Color("#181321"))
		var knob_x := glass_rect.end.x + (cabinet_rect.end.x - glass_rect.end.x) * 0.51
		var knob_radius := minf(16, (cabinet_rect.end.x - glass_rect.end.x) * 0.28)
		for fraction in [0.17, 0.32]:
			var center := Vector2(knob_x, cabinet_rect.position.y + cabinet_rect.size.y * fraction)
			draw_circle(center + Vector2(2, 3), knob_radius + 2, Color("#15111e"))
			draw_circle(center, knob_radius, Color("#b6a28e"))
			draw_circle(center, knob_radius - 4, Color("#514652"))
			draw_line(center + Vector2(-3, -knob_radius + 3), center + Vector2(3, knob_radius - 3), Color("#d6c3ad"), 2)
		for row in range(8):
			var y := cabinet_rect.position.y + cabinet_rect.size.y * 0.52 + row * maxf(4, cabinet_rect.size.y * 0.013)
			draw_rect(Rect2(knob_x - knob_radius, y, knob_radius * 2, 2), Color("#171321"))
		draw_circle(Vector2(knob_x, cabinet_rect.end.y - 19), 3, Color("#00ffd5"))
		draw_line(Vector2(cabinet_rect.end.x - 20, cabinet_rect.end.y), console_rect.position + Vector2(20, 4), Color("#080712"), 4)
		draw_rect(Rect2(console_rect.position + Vector2(3, 4), console_rect.size), Color("#080712"))
		draw_rect(console_rect, Color("#96858f"))
		draw_rect(console_rect.grow(-3), Color("#6b6072"), false, 2)
		draw_rect(Rect2(console_rect.position + Vector2(12, 5), Vector2(console_rect.size.x * 0.43, 5)), Color("#302b38"))
		draw_rect(Rect2(console_rect.position + Vector2(15, console_rect.size.y - 10), Vector2(14, 3)), Color("#ff2d78"))
		var pad := Rect2(console_rect.end.x - 118, console_rect.position.y + 4, 105, console_rect.size.y - 8)
		draw_rect(pad, Color("#494150"))
		draw_rect(Rect2(pad.position + Vector2(9, pad.size.y * 0.5 - 3), Vector2(20, 6)), Color("#181522"))
		draw_rect(Rect2(pad.position + Vector2(16, pad.size.y * 0.5 - 10), Vector2(6, 20)), Color("#181522"))
		draw_rect(Rect2(pad.position + Vector2(40, pad.size.y * 0.5), Vector2(10, 3)), Color("#b6a28e"))
		draw_circle(pad.position + Vector2(73, pad.size.y * 0.62), 5, Color("#ff2d78"))
		draw_circle(pad.position + Vector2(89, pad.size.y * 0.36), 5, Color("#ffb32d"))


class CartridgeBackdrop extends Control:
	const GLYPHS := {
		"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
		"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
		"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
		"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
		"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
		"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
		"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
		"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
		" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
	}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#101024"))
		for y in range(0, 576, 24):
			for x in range(0, 768, 24):
				if (x / 24 + y / 24) % 2 == 0:
					draw_rect(Rect2(x, y, 24, 24), Color("#16132c"))
		for x in range(-576, 768, 64):
			draw_line(Vector2(x, 576), Vector2(x + 576, 0), Color("#292044"), 1)
		draw_rect(Rect2(26, 22, 716, 106), Color("#090b1b"))
		draw_rect(Rect2(26, 22, 716, 106), Color("#7b3cff"), false, 3)
		draw_rect(Rect2(34, 30, 700, 90), Color("#241c3d"), false, 2)
		_draw_logo(Vector2(115, 40), Color("#24102f"), true)
		_draw_logo(Vector2(110, 35), Color("#ffe45c"), false)
		draw_line(Vector2(50, 142), Vector2(718, 142), Color("#00ffd5"), 2)
		draw_rect(Rect2(38, 468, 692, 64), Color("#090b1b"))
		draw_line(Vector2(38, 468), Vector2(730, 468), Color("#7b3cff"), 2)

	func _draw_logo(origin: Vector2, color: Color, shadow: bool) -> void:
		var text := "BEAT THE HOUSE"
		for letter in range(text.length()):
			var glyph: Array = GLYPHS.get(text[letter], GLYPHS[" "])
			for row in range(7):
				for column in range(5):
					if glyph[row][column] == "1":
						var pixel_color := color if shadow else color.lerp(Color("#ff6a27"), float(row) / 10.0)
						draw_rect(Rect2(origin + Vector2(letter * 42 + column * 7 + (6 - row), row * 7), Vector2(7, 7)), pixel_color)


class GameTile extends Button:
	var selected := false
	var ordinal := 0

	func _draw() -> void:
		var edge := Color("#ffe45c") if selected else (Color("#00ffd5") if has_focus() or is_hovered() else Color("#65527b"))
		var fill := Color("#3d2b52") if selected else Color("#201b39")
		draw_rect(Rect2(2, 3, size.x - 3, size.y - 3), Color("#080815"))
		draw_rect(Rect2(0, 0, size.x - 3, size.y - 4), fill)
		draw_rect(Rect2(0, 0, size.x - 3, size.y - 4), edge, false, 3 if selected or has_focus() else 1)
		draw_line(Vector2(5, 5), Vector2(size.x - 9, 5), Color("#9a63ff") if selected else Color("#4b3c60"), 2)
		if selected:
			draw_colored_polygon(PackedVector2Array([Vector2(7, 31), Vector2(17, 38), Vector2(7, 45)]), edge)
			draw_colored_polygon(PackedVector2Array([Vector2(size.x - 10, 31), Vector2(size.x - 20, 38), Vector2(size.x - 10, 45)]), edge)
		draw_string(get_theme_default_font(), Vector2(8, 18), "%02d" % (ordinal + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#a08ab5"))


var selected_game_id := ""
var exit_button: Button
var generation_button: Button
var setup_close_button: Button
var _host: Variant
var _game_buttons: Dictionary = {}
var _game_order: Array[String] = []
var _generation_panel: PanelContainer
var _seed_input: LineEdit
var _security: OptionButton
var _stage: TelevisionCabinet
var _display: TextureRect
var _display_viewport: SubViewport
var _display_root: Control
var _shader_material: ShaderMaterial
var _jitter := Vector2.ZERO
var _ripple_phase := 0.0
var _ripple_strength := 0.0
var _glass_displacement := Vector4.ZERO
var _roll_band := Vector2(1.18, 0.0)
var _cartridge_refresh_queued := false
var _reduce_motion := false
var _pointer_down := false
var _touch_index := -1
var _last_pointer := Vector2.ZERO
var _await_pointer_release := false
var _display_mouse_inside := false
var _restoring_selection := false
var _forwarding_real_mouse_motion := false
var _glass_entry_msec := 0


func configure(host: Variant) -> void:
	_host = host
	name = "CrtPracticeMenu"
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage = TelevisionCabinet.new()
	_stage.name = "TelevisionBezel"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stage)
	_stage.resized.connect(_layout_television)
	_display_viewport = SubViewport.new()
	_display_viewport.name = "CartridgeDisplay"
	_display_viewport.size = Vector2i(DISPLAY_SIZE)
	_display_viewport.disable_3d = true
	_display_viewport.gui_embed_subwindows = true
	_display_viewport.handle_input_locally = true
	_display_viewport.gui_disable_input = true
	_display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_display_viewport)
	_display_root = Control.new()
	_display_root.name = "CartridgeGameSelect"
	_display_root.size = DISPLAY_SIZE
	_display_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_viewport.add_child(_display_root)
	var backdrop := CartridgeBackdrop.new()
	backdrop.size = DISPLAY_SIZE
	_display_root.add_child(backdrop)
	_build_game_select()
	_build_generation_panel()
	_track_cartridge_visual(_display_viewport)
	_display = TextureRect.new()
	_display.name = "CrtDisplayTexture"
	_display.texture = _display_viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_STOP
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = GLASS_SHADER
	_shader_material.set_shader_parameter("curvature", CURVATURE)
	_shader_material.set_shader_parameter("corner_radius", CORNER_RADIUS)
	_display.material = _shader_material
	_stage.add_child(_display)
	_display.gui_input.connect(_on_display_gui_input)
	_display.mouse_entered.connect(_notify_display_mouse_entered)
	_display.mouse_exited.connect(_notify_display_mouse_exited)
	visibility_changed.connect(_on_visibility_changed)
	_wire_game_navigation()
	if not _game_order.is_empty():
		_remember_selection(_game_order[0], false)
	_layout_television.call_deferred()


func _build_game_select() -> void:
	# The original pixel lettering is drawn on the cartridge backdrop. The real
	# text remains present for accessibility and canonical title inspection.
	var title := _label("Beat the House", 36, Color(1, 1, 1, 0))
	title.name = "GameTitle"
	title.position = Vector2(105, 32)
	title.size = Vector2(560, 60)
	title.self_modulate.a = 0
	_display_root.add_child(title)
	var heading := _label("SELECT YOUR GAME", 19, VisualStyle.TEAL)
	heading.position = Vector2(40, 105)
	heading.size = Vector2(688, 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display_root.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "GameSelectGrid"
	grid.position = Vector2(46, 154)
	grid.size = Vector2(676, 304)
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_display_root.add_child(grid)
	for game_id_value in _host._implemented_game_ids():
		var game_id := str(game_id_value)
		var definition: Dictionary = _host.library.game(game_id)
		var button := GameTile.new()
		button.name = "Launch_%s" % game_id
		button.text = str(definition.get("display_name", game_id))
		button.ordinal = _game_order.size()
		button.set_meta("game_test_id", game_id)
		button.set_meta("game_icon_asset_path", str(definition.get("asset_path", "")))
		button.tooltip_text = str(definition.get("description", ""))
		# The fixed cartridge grid allocates 96 pixels per row. Text-size changes
		# affect the visible captions, never native Button's hidden text minimum.
		button.custom_minimum_size = Vector2(163, 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_host._set_control_font_size(button, 8)
		button.icon = _host._texture_for_image_asset_path(str(definition.get("asset_path", "")))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 1)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color(1, 1, 1, 0))
		button.pressed.connect(_launch_game.bind(game_id))
		button.focus_entered.connect(_remember_selection.bind(game_id))
		button.mouse_entered.connect(_on_game_hovered.bind(game_id))
		grid.add_child(button)
		var icon := TextureRect.new()
		icon.name = "ExistingGameIcon"
		icon.texture = button.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(57, 9)
		icon.size = Vector2(46, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var caption := _label(button.text, 15, VisualStyle.SOFT)
		caption.name = "NameLabel"
		caption.position = Vector2(7, 50)
		caption.size = Vector2(146, 40)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.max_lines_visible = 2
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(caption)
		_game_buttons[game_id] = button
		_game_order.append(game_id)
	var cartridge := _label("1 PLAYER\nPRACTICE ONLY", 17, VisualStyle.CYAN_2)
	cartridge.name = "PracticeCartridgeStamp"
	cartridge.custom_minimum_size = Vector2(163, 0)
	cartridge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cartridge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cartridge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cartridge.max_lines_visible = 2
	grid.add_child(cartridge)
	var seed_caption := _label("SEED", 13, VisualStyle.CYAN_2)
	seed_caption.position = Vector2(50, 488)
	seed_caption.size = Vector2(54, 28)
	_display_root.add_child(seed_caption)
	_seed_input = LineEdit.new()
	_seed_input.name = "PracticeSeed"
	_seed_input.text = "PRACTICE"
	_seed_input.placeholder_text = "Repeatable seed"
	_seed_input.position = Vector2(106, 480)
	_seed_input.size = Vector2(330, 44)
	_style_edit(_seed_input)
	_display_root.add_child(_seed_input)
	_host.game_test_seed_input = _seed_input
	generation_button = _screen_button("SETUP", "GenerationOptions", _toggle_generation)
	generation_button.position = Vector2(446, 480)
	generation_button.size = Vector2(128, 44)
	generation_button.toggle_mode = true
	_display_root.add_child(generation_button)
	exit_button = _screen_button("EXIT TV", "ExitTelevision", Callable(_host, "close_game_test_menu"))
	exit_button.position = Vector2(584, 480)
	exit_button.size = Vector2(134, 44)
	_display_root.add_child(exit_button)
	var status := _label("", 11, VisualStyle.SOFT)
	status.name = "PracticeConsoleStatus"
	status.position = Vector2(46, 538)
	status.size = Vector2(676, 20)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.clip_text = true
	_display_root.add_child(status)
	_host.game_test_status_label = status


func _build_generation_panel() -> void:
	_generation_panel = PanelContainer.new()
	_generation_panel.name = "GenerationInputs"
	_generation_panel.visible = false
	_generation_panel.position = Vector2(50, 150)
	_generation_panel.size = Vector2(668, 308)
	_generation_panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(PANEL_FILL, VisualStyle.YELLOW, 3))
	_display_root.add_child(_generation_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "SetupScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	_generation_panel.add_child(scroll)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 7)
	scroll.add_child(settings)
	var header := HBoxContainer.new()
	settings.add_child(header)
	var label := _label("PRACTICE SETUP", 20, VisualStyle.YELLOW)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	setup_close_button = _screen_button("DONE", "SetupDone", _close_generation)
	setup_close_button.custom_minimum_size = Vector2(112, 42)
	header.add_child(setup_close_button)
	var numeric_row := HBoxContainer.new()
	numeric_row.add_theme_constant_override("separation", 10)
	settings.add_child(numeric_row)
	for setting in [["Bankroll", "_game_test_bankroll"], ["Min", "_game_test_stake_floor"], ["Max", "_game_test_stake_ceiling"]]:
		var group: VBoxContainer = _host._game_test_spin_group(str(setting[0]), str(setting[1]))
		numeric_row.add_child(group)
		for child in group.get_children():
			if child is SpinBox:
				(child as SpinBox).custom_minimum_size.y = 42
			elif child is Label:
				(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	_security = OptionButton.new()
	_security.name = "PracticeSecurity"
	_security.custom_minimum_size = Vector2(104, 42)
	for strictness in ["low", "high", "boss"]:
		_security.add_item(str(strictness).capitalize())
		_security.set_item_metadata(_security.item_count - 1, strictness)
	_security.select(2)
	var security_group := VBoxContainer.new()
	security_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	security_group.add_child(_label("Security", 12, VisualStyle.CYAN_2))
	security_group.add_child(_security)
	numeric_row.add_child(security_group)
	_host.game_test_security_option = _security
	settings.add_child(_label("Generation overrides (JSON)", 13, VisualStyle.CYAN_2))
	var overrides := TextEdit.new()
	overrides.name = "GenerationOverrides"
	overrides.text = "{}"
	overrides.custom_minimum_size = Vector2(0, 94)
	overrides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overrides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_edit(overrides)
	settings.add_child(overrides)
	_host.game_test_generation_overrides_text = overrides
	var hint := _label("Seed and setup stay selected when you Leave a game.", 12, VisualStyle.SOFT)
	hint.clip_text = true
	settings.add_child(hint)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = _host._label(text_value, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host._set_control_font_color(label, color)
	return label


func _screen_button(text_value: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.pressed.connect(action)
	button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#30243f"), Color("#9a63ff"), 2))
	button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(Color("#473355"), VisualStyle.TEAL, 2))
	button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(Color("#473355"), VisualStyle.YELLOW, 2))
	button.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#473355"), VisualStyle.YELLOW, 3))
	_host._set_control_font_size(button, 16)
	_host._set_control_font_color(button, VisualStyle.SOFT)
	return button


func _style_edit(control: Control) -> void:
	control.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#090b1b"), VisualStyle.CYAN_2, 1))
	control.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#090b1b"), VisualStyle.YELLOW, 2))
	_host._set_control_font_color(control, VisualStyle.WHITE)
	_host._set_control_font_size(control, 16)


func _layout_television() -> void:
	if _display == null or _stage.size.x <= 0 or _stage.size.y <= 0:
		return
	var compact := _stage.size.y < 440
	var left := 10.0 if compact else 22.0
	var right := 30.0 if compact else 62.0
	var top := 10.0 if compact else 22.0
	var bottom := 10.0 if compact else 26.0
	var console_height := 24.0 if compact else 38.0
	var gap := 8.0 if compact else 12.0
	var height := maxf(1, minf((_stage.size.x - left - right - 8) * 0.75, _stage.size.y - top - bottom - console_height - gap))
	var glass_size := Vector2(height * 4.0 / 3.0, height)
	var cabinet_size := glass_size + Vector2(left + right, top + bottom)
	var cabinet_position := Vector2((_stage.size.x - cabinet_size.x) * 0.5, maxf(0, (_stage.size.y - cabinet_size.y - console_height - gap) * 0.5))
	_stage.cabinet_rect = Rect2(cabinet_position, cabinet_size)
	_stage.glass_rect = Rect2(cabinet_position + Vector2(left, top), glass_size)
	_stage.console_rect = Rect2(Vector2(cabinet_position.x + cabinet_size.x * 0.18, _stage.cabinet_rect.end.y + gap), Vector2(cabinet_size.x * 0.64, console_height))
	_display.position = _stage.glass_rect.position
	_display.size = _stage.glass_rect.size
	_stage.queue_redraw()


# Native controls still perform their usual redraws. Only the static cartridge
# image is retained between changes. The outer glass keeps animating every frame.
func _track_cartridge_visual(node: Node) -> void:
	if not node.child_entered_tree.is_connected(_track_cartridge_visual):
		node.child_entered_tree.connect(_track_cartridge_visual)
		node.child_exiting_tree.connect(_on_cartridge_child_removed)
		if node is CanvasItem:
			node.draw.connect(_refresh_cartridge_image)
			node.item_rect_changed.connect(_refresh_cartridge_image)
			node.visibility_changed.connect(_refresh_cartridge_image)
		elif node is Window:
			node.visibility_changed.connect(_refresh_cartridge_image)
		for child in node.get_children():
			_track_cartridge_visual(child)
	_refresh_cartridge_image()


func _on_cartridge_child_removed(_node: Node) -> void:
	_refresh_cartridge_image()


func _refresh_cartridge_image() -> void:
	if _cartridge_refresh_queued or not is_visible_in_tree():
		return
	_cartridge_refresh_queued = true
	_update_cartridge_image.call_deferred()


func _update_cartridge_image() -> void:
	_cartridge_refresh_queued = false
	if _display_viewport != null and is_visible_in_tree():
		_display_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _shader_material == null:
		return
	_reduce_motion = bool(_host._reduce_motion_enabled())
	var displacement := Vector4.ZERO
	var roll := Vector2(1.18, 0.0)
	if not _reduce_motion:
		var now_msec := Time.get_ticks_msec()
		var seconds := float(now_msec) / 1000.0
		var burst := pow(maxf(0, sin(seconds * 1.73) * sin(seconds * 0.63 + 1.1)), 4)
		displacement = Vector4(sin(seconds * 32.7) * 0.00035 * burst,
			sin(seconds * 19.1) * 0.00018 * burst, seconds * 2.3, 0.00034 * burst)
		# A prompt upward pass, then quiet glass without sending new uniforms.
		var sweep_time := fmod(float(now_msec - _glass_entry_msec) / 1000.0, SCAN_CYCLE_SECONDS)
		if sweep_time < SCAN_SWEEP_SECONDS:
			roll = Vector2(lerpf(1.18, -0.18, sweep_time / SCAN_SWEEP_SECONDS), 1.0)
	_jitter = Vector2(displacement.x, displacement.y)
	_ripple_phase = displacement.z
	_ripple_strength = displacement.w
	if displacement != _glass_displacement:
		_glass_displacement = displacement
		_shader_material.set_shader_parameter("glass_displacement", displacement)
	if roll != _roll_band:
		_roll_band = roll
		_shader_material.set_shader_parameter("roll_band", roll)
	if _await_pointer_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_await_pointer_release = false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _display_viewport == null or event.is_action("ui_cancel"):
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction:
		_display_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if _display_viewport == null:
		return
	_pointer_down = false
	_touch_index = -1
	_await_pointer_release = is_visible_in_tree() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not is_visible_in_tree():
		_close_generation(false)
		_display_viewport.gui_release_focus()
		# Godot's input-disable transition already drops mouse focus and sends
		# the viewport's mouse-leave cleanup. Both the overlay and this menu
		# can hide in one exit; an extra notify_mouse_exited() duplicates it.
		_display_viewport.gui_disable_input = true
		_display_mouse_inside = false
	else:
		_glass_entry_msec = Time.get_ticks_msec()
		_display_viewport.gui_disable_input = false
		_refresh_cartridge_image()


func _notify_display_mouse_entered() -> void:
	if _display_mouse_inside or not is_visible_in_tree() or _display_viewport.gui_disable_input:
		return
	_display_mouse_inside = true
	_display_viewport.notify_mouse_entered()


func _notify_display_mouse_exited() -> void:
	if not _display_mouse_inside:
		return
	_display_mouse_inside = false
	_display_viewport.notify_mouse_exited()


func _on_display_gui_input(event: InputEvent) -> void:
	# push_input does not synthesize emulation. Convert each real touch once and
	# ignore the project's emulated duplicate (also its emulated touch for mouse).
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		_display.accept_event()
		return
	if _await_pointer_release:
		var release := event as InputEventMouseButton
		if release != null and not release.pressed and release.button_index == MOUSE_BUTTON_LEFT:
			_await_pointer_release = false
		_display.accept_event()
		return
	if event is InputEventScreenTouch:
		_forward_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			var motion := InputEventMouseMotion.new()
			motion.position = _local_to_display(drag.position)
			motion.global_position = motion.position
			motion.relative = motion.position - _last_pointer
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			_last_pointer = motion.position
			_display_viewport.push_input(motion, true)
	elif event is InputEventMouse:
		var mouse := event as InputEventMouse
		var position: Vector2 = mouse.position
		var mouse_button := mouse as InputEventMouseButton
		if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and not _inside_glass(position / _display.size):
				_display.accept_event()
				return
			if not mouse_button.pressed and not _pointer_down:
				_display.accept_event()
				return
			_pointer_down = mouse_button.pressed
		var forwarded := event.duplicate() as InputEventMouse
		forwarded.position = _local_to_display(position)
		forwarded.global_position = forwarded.position
		if forwarded is InputEventMouseMotion:
			var forwarded_motion := forwarded as InputEventMouseMotion
			var original_motion := event as InputEventMouseMotion
			forwarded_motion.relative = forwarded.position - _local_to_display(position - original_motion.relative)
		_last_pointer = forwarded.position
		_notify_display_mouse_entered()
		_forwarding_real_mouse_motion = event is InputEventMouseMotion and _inside_glass(position / _display.size)
		_display_viewport.push_input(forwarded, true)
		# mouse_entered alone misses motion within a tile after keyboard navigation.
		# Query the actual GUI hit owner, so popup/seed/setup occlusion stays native.
		if _forwarding_real_mouse_motion and _inside_glass(position / _display.size):
			var hovered := _display_viewport.gui_get_hovered_control()
			if hovered is GameTile:
				_on_game_hovered(str(hovered.get_meta("game_test_id", "")))
		_forwarding_real_mouse_motion = false
	_display.accept_event()


func _forward_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index != -1 or not _inside_glass(event.position / _display.size):
			return
		_touch_index = event.index
	elif event.index != _touch_index:
		return
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = event.pressed
	pointer.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
	pointer.position = _local_to_display(event.position)
	pointer.global_position = pointer.position
	if event.canceled:
		# An OS-cancelled touch is not a confirm. Move the held pointer outside
		# before releasing so BaseButton clears its in-bounds press attempt.
		var cancel_motion := InputEventMouseMotion.new()
		cancel_motion.position = Vector2(-100, -100)
		cancel_motion.global_position = cancel_motion.position
		cancel_motion.relative = cancel_motion.position - _last_pointer
		cancel_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_display_viewport.push_input(cancel_motion, true)
		pointer.position = cancel_motion.position
		pointer.global_position = pointer.position
	_last_pointer = pointer.position
	_notify_display_mouse_entered()
	_display_viewport.push_input(pointer, true)
	if not event.pressed:
		_touch_index = -1


func _inside_glass(uv: Vector2) -> bool:
	var corner := Vector2(absf(uv.x - 0.5), absf(uv.y - 0.5)) - Vector2(0.5 - CORNER_RADIUS, 0.5 - CORNER_RADIUS)
	return Vector2(maxf(corner.x, 0), maxf(corner.y, 0)).length() <= CORNER_RADIUS and Rect2(Vector2.ZERO, Vector2.ONE).has_point(_warp_uv(uv))


func _warp_uv(uv: Vector2) -> Vector2:
	var centered := uv * 2.0 - Vector2.ONE
	var warped := centered * (1.0 + CURVATURE * centered.length_squared()) * 0.5 + Vector2(0.5, 0.5)
	warped += _jitter
	warped.x += sin(uv.y * 149.0 + _ripple_phase) * _ripple_strength
	return warped


func _local_to_display(local_point: Vector2) -> Vector2:
	return _warp_uv(local_point / _display.size) * DISPLAY_SIZE


func global_to_display(global_point: Vector2) -> Vector2:
	return _local_to_display(_display.get_global_transform_with_canvas().affine_inverse() * global_point)


func display_to_global(display_point: Vector2) -> Vector2:
	# This coefficient makes fixed-point inversion contractive. Include row
	# ripple in the same iteration so pointer and displayed text remain aligned.
	var target := display_point / DISPLAY_SIZE
	var uv := target
	for iteration in range(12):
		var offset := _jitter + Vector2(sin(uv.y * 149.0 + _ripple_phase) * _ripple_strength, 0)
		var centered := (target - offset) * 2.0 - Vector2.ONE
		var estimate := uv * 2.0 - Vector2.ONE
		uv = centered / (1.0 + CURVATURE * estimate.length_squared()) * 0.5 + Vector2(0.5, 0.5)
	return _display.get_global_transform_with_canvas() * (uv * _display.size)


func display_control_rect(control: Control) -> Rect2:
	return control.get_global_rect()


func display_hit_point(control: Control, normalized := Vector2(0.5, 0.5)) -> Vector2:
	var rect := display_control_rect(control)
	return display_to_global(rect.position + rect.size * normalized)


func get_display_focus_owner() -> Control:
	return _display_viewport.gui_get_focus_owner()


func get_display_hovered_control() -> Control:
	return _display_viewport.gui_get_hovered_control()


func get_display_viewport() -> SubViewport:
	return _display_viewport


func get_shader_material() -> ShaderMaterial:
	return _shader_material


func is_generation_open() -> bool:
	return _generation_panel.visible


func _toggle_generation() -> void:
	if generation_button.button_pressed:
		_generation_panel.visible = true
		for button in _game_buttons.values():
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		setup_close_button.grab_focus()
	else:
		_close_generation()


func _close_generation(restore_focus := true) -> void:
	if _generation_panel == null:
		return
	if _security != null:
		_security.get_popup().hide()
	_generation_panel.visible = false
	generation_button.set_pressed_no_signal(false)
	for button in _game_buttons.values():
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	if restore_focus and generation_button.is_visible_in_tree():
		generation_button.grab_focus()


func consume_back() -> bool:
	if _security.get_popup().visible:
		_security.get_popup().hide()
		_security.grab_focus()
		return true
	if _generation_panel.visible:
		_close_generation()
		return true
	return false


func _remember_selection(game_id: String, user_initiated: bool = true) -> void:
	if not _game_buttons.has(game_id) or selected_game_id == game_id:
		return
	selected_game_id = game_id
	for id_value in _game_buttons:
		var button: GameTile = _game_buttons[id_value]
		button.selected = str(id_value) == game_id
		button.queue_redraw()
	if user_initiated and not _restoring_selection and is_visible_in_tree():
		user_selection_changed.emit(game_id)


func _on_game_hovered(game_id: String) -> void:
	if not _forwarding_real_mouse_motion or not is_visible_in_tree() or _restoring_selection or _await_pointer_release \
			or (_generation_panel != null and _generation_panel.visible):
		return
	var button: Button = _game_buttons.get(game_id)
	if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
		# Update explicitly even if this tile already owns focus. The idempotent
		# selection guard keeps the ensuing focus_entered signal silent.
		_remember_selection(game_id)
		button.grab_focus()


func _launch_game(game_id: String) -> void:
	var button: Button = _game_buttons.get(game_id)
	if button == null or button.disabled:
		return
	_remember_selection(game_id)
	var result: Variant = _host.start_game_test_session(game_id)
	if typeof(result) == TYPE_DICTIONARY and typeof(result.get("ok", false)) == TYPE_BOOL \
			and result.get("ok", false):
		launch_accepted.emit(game_id)


func focus_selected_game() -> void:
	_restoring_selection = true
	_close_generation(false)
	var button: Button = _game_buttons.get(selected_game_id)
	if button == null and not _game_order.is_empty():
		button = _game_buttons.get(_game_order[0])
	if button != null:
		_remember_selection(str(button.get_meta("game_test_id", "")), false)
		button.grab_focus()
	_restoring_selection = false


func _wire_game_navigation() -> void:
	for index in range(_game_order.size()):
		var button: Button = _game_buttons[_game_order[index]]
		var previous: Control = _game_buttons[_game_order[index - 1]] if index > 0 else exit_button
		var following: Control = _game_buttons[_game_order[index + 1]] if index + 1 < _game_order.size() else _seed_input
		var above: Control = _game_buttons[_game_order[index - 4]] if index >= 4 else generation_button
		var below: Control = _game_buttons[_game_order[index + 4]] if index + 4 < _game_order.size() else _seed_input
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(following)
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(following)
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
	_seed_input.focus_next = _seed_input.get_path_to(generation_button)
	generation_button.focus_next = generation_button.get_path_to(exit_button)
	exit_button.focus_next = exit_button.get_path_to(_game_buttons[_game_order[0]])
	_seed_input.focus_previous = _seed_input.get_path_to(_game_buttons[_game_order.back()])
	generation_button.focus_previous = generation_button.get_path_to(_seed_input)
	exit_button.focus_previous = exit_button.get_path_to(generation_button)
