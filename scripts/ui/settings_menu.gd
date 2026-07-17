class_name SettingsMenu
extends VBoxContainer

# Settings screen; edits a draft before applying.

signal back_requested
signal settings_applied
signal reset_tips_requested

const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")

const WINDOW_MODE_LABELS := ["Windowed", "Fullscreen", "Borderless"]
const TEXT_SIZE_LABELS := ["Small", "Normal", "Large"]
const DRUNK_EFFECT_LABELS := ["Wavy Distortion", "Classic Overlay"]
const ACCESSIBILITY_BASE_FONT_META := "accessibility_base_font_size"
const ACCESSIBILITY_BASE_MIN_SIZE_META := "accessibility_base_min_size"
const ACCESSIBILITY_BASE_COLOR_META := "accessibility_base_font_color"
const DEFAULT_SETTINGS_FONT_SIZE := 13

var settings: UserSettings
var draft: UserSettings

var status: Label
var resolution: OptionButton
var mode: OptionButton
var vsync: CheckBox
var master: HSlider
var master_text: Label
var music: HSlider
var music_text: Label
var sfx: HSlider
var sfx_text: Label
var audio_calm: CheckBox
var ui: HSlider
var ui_text: Label
var text_size: OptionButton
var reduce_motion: CheckBox
var drunk_effect: OptionButton
var high_contrast: CheckBox
var play_on_small_screen: CheckBox
var coach_tips: CheckBox
var reset_tips: Button
var haptics_note: Label


# Stores the settings object and builds the view.
func setup(p_settings: UserSettings) -> void:
	settings = p_settings
	draft = UserSettingsScript.new()
	_build()


# Opens the menu with a fresh draft.
func open() -> void:
	draft.from_dict(settings.to_dict())
	status.text = ""
	_sync()
	visible = true


# Creates all settings controls.
func _build() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	_section(box, "Video")
	resolution = _option(box, "Resolution", _res_labels())
	resolution.item_selected.connect(_on_resolution)
	mode = _option(box, "Window Mode", WINDOW_MODE_LABELS)
	mode.item_selected.connect(_on_mode)
	vsync = _check(box, "VSync")
	vsync.toggled.connect(_on_vsync)

	_section(box, "Audio")
	var master_row := _slider(box, "Master Volume")
	master = master_row["slider"]
	master_text = master_row["text"]
	master.value_changed.connect(_on_master)
	var music_row := _slider(box, "Music Volume")
	music = music_row["slider"]
	music_text = music_row["text"]
	music.value_changed.connect(_on_music)
	var sfx_row := _slider(box, "SFX Volume")
	sfx = sfx_row["slider"]
	sfx_text = sfx_row["text"]
	sfx.value_changed.connect(_on_sfx)
	audio_calm = _check(box, "Calmer Music")
	audio_calm.toggled.connect(_on_audio_calm)

	_section(box, "Interface")
	play_on_small_screen = _check(box, "Play on small screen")
	play_on_small_screen.tooltip_text = "Larger controls and touch targets for phones and tablets."
	play_on_small_screen.toggled.connect(_on_play_on_small_screen)
	_note(box, "Enlarges controls and tap areas for phone or tablet play. Disabled by default.")
	coach_tips = _check(box, "Coach tips")
	coach_tips.tooltip_text = "Show one-time dealer advice during normal runs."
	coach_tips.toggled.connect(_on_coach_tips)
	reset_tips = _button("Reset tips")
	reset_tips.tooltip_text = "Show first-time coach tips again."
	reset_tips.pressed.connect(_on_reset_tips)
	box.add_child(reset_tips)
	var ui_row := _slider(box, "UI Scale", 85, 130, 5)
	ui = ui_row["slider"]
	ui_text = ui_row["text"]
	ui.value_changed.connect(_on_ui)
	text_size = _option(box, "Text Size", TEXT_SIZE_LABELS)
	text_size.item_selected.connect(_on_text_size)
	high_contrast = _check(box, "High Contrast")
	high_contrast.toggled.connect(_on_high_contrast)
	drunk_effect = _option(box, "Drunk Effect", DRUNK_EFFECT_LABELS)
	drunk_effect.item_selected.connect(_on_drunk_effect)
	reduce_motion = _check(box, "Reduce Motion")
	reduce_motion.toggled.connect(_on_reduce_motion)
	haptics_note = _note(box, "Haptics are not used by this demo's input stack.")

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)

	var back := _button("Back")
	back.pressed.connect(back_requested.emit)
	actions.add_child(back)

	var defaults := _button("Restore Defaults")
	defaults.pressed.connect(_on_defaults)
	actions.add_child(defaults)

	var apply := _button("Apply")
	apply.pressed.connect(_on_apply)
	actions.add_child(apply)
	_apply_accessibility_settings()


# Adds a visual section heading.
func _section(parent: Control, text: String) -> void:
	parent.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	parent.add_child(label)


# Adds a labeled option row.
func _option(parent: Control, label_text: String, items: Array) -> OptionButton:
	var row := _row(parent, label_text)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		option.add_item(str(item))
	row.add_child(option)
	return option


# Adds a checkbox row.
func _check(parent: Control, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.custom_minimum_size = Vector2(0, 44)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(check)
	return check


# Adds a non-interactive release note for intentionally unsupported settings.
func _note(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", VisualStyleScript.color("cyan_2"))
	parent.add_child(label)
	return label


# Adds a slider row with a value label.
func _slider(parent: Control, label_text: String, min_value: float = 0, max_value: float = 100, step: float = 1) -> Dictionary:
	var row := _row(parent, label_text)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var text := Label.new()
	text.custom_minimum_size = Vector2(58, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)

	return {
		"slider": slider,
		"text": text,
	}


# Creates the label portion shared by option and slider rows.
func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


# Creates a standard settings action button.
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


# Copies draft values into the controls.
func _sync() -> void:
	resolution.select(draft.resolution_index())
	mode.select(draft.mode_index())
	vsync.button_pressed = draft.vsync_enabled
	master.value = roundi(draft.master_volume * 100.0)
	music.value = roundi(draft.music_volume * 100.0)
	sfx.value = roundi(draft.sfx_volume * 100.0)
	audio_calm.button_pressed = draft.audio_calm
	play_on_small_screen.button_pressed = draft.play_on_small_screen
	coach_tips.button_pressed = draft.coach_tips_enabled
	ui.value = roundi(draft.ui_scale * 100.0)
	text_size.select(draft.text_index())
	high_contrast.button_pressed = draft.high_contrast
	drunk_effect.select(draft.drunk_effect_index())
	reduce_motion.button_pressed = draft.reduce_motion
	_labels()
	_apply_accessibility_settings()


# Updates percentage text beside sliders.
func _labels() -> void:
	master_text.text = "%d%%" % int(master.value)
	music_text.text = "%d%%" % int(music.value)
	sfx_text.text = "%d%%" % int(sfx.value)
	ui_text.text = "%d%%" % int(ui.value)


# Saves the draft and applies it live.
func _save(message: String) -> void:
	# Commit the draft to disk and the live engine.
	settings.from_dict(draft.to_dict())
	settings.apply()
	VisualStyleScript.set_high_contrast_enabled(settings.high_contrast)
	var error: Error = settings.save()
	settings_applied.emit()
	status.text = message if error == OK else "Settings applied, but could not be saved."
	_apply_accessibility_settings()


# Applies current draft settings.
func _on_apply() -> void:
	_save("Settings saved.")


# Restores defaults and applies them.
func _on_defaults() -> void:
	draft.reset()
	_sync()
	_save("Defaults restored.")


# Updates draft resolution from the selected option.
func _on_resolution(index: int) -> void:
	draft.set_resolution(index)


# Updates draft window mode from the selected option.
func _on_mode(index: int) -> void:
	draft.set_mode(index)


# Updates draft VSync state.
func _on_vsync(enabled: bool) -> void:
	draft.vsync_enabled = enabled


# Updates draft master volume.
func _on_master(value: float) -> void:
	_set_percent("master_volume", value)


# Updates draft music volume.
func _on_music(value: float) -> void:
	_set_percent("music_volume", value)


# Updates draft sound effect volume.
func _on_sfx(value: float) -> void:
	_set_percent("sfx_volume", value)


func _on_audio_calm(enabled: bool) -> void:
	draft.audio_calm = enabled


func _on_play_on_small_screen(enabled: bool) -> void:
	draft.play_on_small_screen = enabled
	_apply_accessibility_settings()


func _on_coach_tips(enabled: bool) -> void:
	draft.coach_tips_enabled = enabled


func _on_reset_tips() -> void:
	reset_tips_requested.emit()
	status.text = "Coach tips reset."


# Updates draft UI scale.
func _on_ui(value: float) -> void:
	_set_percent("ui_scale", value)


# Applies one percent-based slider to the draft and refreshes its label.
func _set_percent(property_name: String, value: float) -> void:
	draft.set(property_name, value / 100.0)
	_labels()


# Updates draft text size.
func _on_text_size(index: int) -> void:
	draft.set_text(index)
	_apply_accessibility_settings()


# Updates draft high-contrast palette state.
func _on_high_contrast(enabled: bool) -> void:
	draft.high_contrast = enabled


# Updates draft drunk visual style.
func _on_drunk_effect(index: int) -> void:
	draft.set_drunk_effect(index)


# Updates draft reduce-motion state.
func _on_reduce_motion(enabled: bool) -> void:
	draft.reduce_motion = enabled


func current_settings_snapshot() -> Dictionary:
	var active_settings: UserSettings = draft if visible and draft != null else settings
	if active_settings == null:
		return {}
	return {
		"visible": visible,
		"ui_scale": float(active_settings.ui_scale),
		"text_size": str(active_settings.text_size),
		"text_scale": float(active_settings.text_scale()),
		"reduce_motion": bool(active_settings.reduce_motion),
		"audio_calm": bool(active_settings.audio_calm),
		"drunk_effect_mode": str(active_settings.drunk_effect_mode),
		"high_contrast": bool(active_settings.high_contrast),
		"play_on_small_screen": bool(active_settings.play_on_small_screen),
		"coach_tips_enabled": bool(active_settings.coach_tips_enabled),
		"reset_tips_available": reset_tips != null and not reset_tips.disabled,
		"haptics_supported": false,
		"haptics_cut_reason": UserSettingsScript.HAPTICS_CUT_REASON,
	}


# Builds human-readable resolution labels.
func _res_labels() -> Array:
	var labels: Array = []
	for size in UserSettings.RESOLUTIONS:
		labels.append("%d x %d" % [size.x, size.y])
	return labels


func _apply_accessibility_settings() -> void:
	var active_settings: UserSettings = draft if draft != null else settings
	var font_scale := 1.0
	var control_scale := 1.0
	var high_contrast_enabled := false
	if active_settings != null:
		font_scale = clampf(float(active_settings.text_scale()) * float(active_settings.ui_scale), 0.86, 1.35)
		control_scale = clampf(float(active_settings.ui_scale), 0.90, 1.18)
		if active_settings.play_on_small_screen:
			font_scale = minf(1.5, font_scale * SmallScreenPolicyScript.FONT_SCALE)
			control_scale = maxf(control_scale, SmallScreenPolicyScript.CONTROL_SCALE)
		high_contrast_enabled = bool(active_settings.high_contrast)
	VisualStyleScript.set_high_contrast_enabled(high_contrast_enabled)
	_apply_accessibility_to_node(self, font_scale, control_scale)


func _apply_accessibility_to_node(node: Node, font_scale: float, control_scale: float) -> void:
	var control := node as Control
	if control != null:
		_apply_accessibility_font(control, font_scale)
		_apply_accessibility_minimum_size(control, control_scale)
		_apply_accessibility_colors(control)
	for child in node.get_children():
		_apply_accessibility_to_node(child, font_scale, control_scale)


func _apply_accessibility_font(control: Control, font_scale: float) -> void:
	if not _control_uses_text(control):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_FONT_META):
		var base_size := DEFAULT_SETTINGS_FONT_SIZE
		if control.has_theme_font_size_override("font_size"):
			base_size = control.get_theme_font_size("font_size")
		control.set_meta(ACCESSIBILITY_BASE_FONT_META, base_size)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_FONT_META)
	var base_font_size := DEFAULT_SETTINGS_FONT_SIZE
	if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
		base_font_size = int(stored)
	control.add_theme_font_size_override("font_size", maxi(8, int(round(float(base_font_size) * font_scale))))


func _apply_accessibility_minimum_size(control: Control, control_scale: float) -> void:
	if not _control_uses_text(control) and not (control is HSlider):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_MIN_SIZE_META):
		control.set_meta(ACCESSIBILITY_BASE_MIN_SIZE_META, control.custom_minimum_size)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_MIN_SIZE_META)
	if typeof(stored) != TYPE_VECTOR2:
		return
	var base_size: Vector2 = stored
	var next_size := Vector2(base_size.x, base_size.y * control_scale)
	var active_settings: UserSettings = draft if draft != null else settings
	if active_settings != null and active_settings.play_on_small_screen and (control is BaseButton or control is LineEdit or control is SpinBox or control is HSlider):
		next_size.y = maxf(next_size.y, SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT)
	control.custom_minimum_size = next_size


func _apply_accessibility_colors(control: Control) -> void:
	if not _control_uses_text(control):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_COLOR_META):
		var base_color := VisualStyleScript.SOFT
		if control.has_theme_color_override("font_color"):
			base_color = control.get_theme_color("font_color")
		elif control is Button or control is LineEdit or control is OptionButton or control is CheckBox:
			base_color = VisualStyleScript.WHITE
		control.set_meta(ACCESSIBILITY_BASE_COLOR_META, base_color)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_COLOR_META)
	var color := VisualStyleScript.SOFT
	if typeof(stored) == TYPE_COLOR:
		color = stored
	control.add_theme_color_override("font_color", VisualStyleScript.accessible_color(color))


func _control_uses_text(control: Control) -> bool:
	return control is Label or control is Button or control is LineEdit or control is OptionButton or control is CheckBox or control is SpinBox
