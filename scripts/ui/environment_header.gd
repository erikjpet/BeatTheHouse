class_name EnvironmentHeader
extends PanelContainer

const CONFIG_PATH := "res://data/ui/environment_ui.json"
const UIArtScript := preload("res://scripts/ui/ui_art.gd")

static var _config_cache: Dictionary = {}

var title_art: TextureRect
var accessible_title: Label
var blurb_label: Label
var goal_label: Label
var options_row: HBoxContainer
var current_archetype_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", VisualStyle.state_box("normal"))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func render(environment: Dictionary, goal_text: String) -> void:
	if title_art == null:
		return
	var archetype_id := str(environment.get("archetype_id", environment.get("kind", ""))).strip_edges()
	var display_name := str(environment.get("display_name", archetype_id.replace("_", " ").capitalize()))
	var config := _config_for(archetype_id)
	current_archetype_id = archetype_id
	title_art.texture = UIArtScript.environment_title(archetype_id)
	accessible_title.text = display_name
	accessible_title.tooltip_text = "%s title plate" % display_name
	blurb_label.text = str(config.get("blurb", "Click objects to inspect this room."))
	var rendered_goal := goal_text.strip_edges()
	if rendered_goal.is_empty():
		rendered_goal = "Inspect the room and choose an available action."
	goal_label.text = "Goal · %s" % rendered_goal
	FoundationWidgets.clear(options_row)
	for option_value in _array(config.get("options", [])):
		var option_label := FoundationWidgets.muted_label(str(option_value), VisualStyle.TYPE_CAPTION)
		option_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		options_row.add_child(option_label)
	var interaction_hint := FoundationWidgets.muted_label(
		"Click objects to inspect; double-click glowing props to act.",
		VisualStyle.TYPE_CAPTION
	)
	interaction_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	options_row.add_child(interaction_hint)


func current_snapshot() -> Dictionary:
	return {
		"archetype_id": current_archetype_id,
		"title_texture": title_art.texture.resource_path if title_art != null and title_art.texture != null else "",
		"accessible_title": accessible_title.text if accessible_title != null else "",
		"blurb": blurb_label.text if blurb_label != null else "",
		"goal": goal_label.text if goal_label != null else "",
		"option_count": options_row.get_child_count() - 1 if options_row != null else 0,
		"data_path": CONFIG_PATH,
		"fallback_ready": true,
	}


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)
	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	row.add_child(title_stack)
	title_art = TextureRect.new()
	title_art.custom_minimum_size = VisualStyle.ENVIRONMENT_TITLE_SIZE
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_child(title_art)
	accessible_title = FoundationWidgets.label("", VisualStyle.TYPE_MICRO)
	accessible_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	accessible_title.clip_text = true
	title_stack.add_child(accessible_title)
	var copy_stack := VBoxContainer.new()
	copy_stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	copy_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy_stack)
	blurb_label = FoundationWidgets.label("", VisualStyle.TYPE_SMALL)
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.max_lines_visible = 2
	copy_stack.add_child(blurb_label)
	goal_label = FoundationWidgets.label("", VisualStyle.TYPE_SMALL)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_label.clip_text = true
	FoundationWidgets.set_control_font_color(goal_label, VisualStyle.role("focus"))
	copy_stack.add_child(goal_label)
	options_row = HBoxContainer.new()
	options_row.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	copy_stack.add_child(options_row)


static func _config_for(archetype_id: String) -> Dictionary:
	if _config_cache.is_empty():
		_config_cache = _load_config()
	var value: Variant = _config_cache.get(archetype_id, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	var indexed: Dictionary = {}
	for entry_value in parsed:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get("id", "")).strip_edges()
		if not entry_id.is_empty():
			indexed[entry_id] = entry.duplicate(true)
	return indexed


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
