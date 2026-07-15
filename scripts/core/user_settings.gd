class_name UserSettings
extends RefCounted

# User preferences plus the engine calls that apply them.

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_PATH_ENV := "BTH_USER_SETTINGS_PATH"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const TEXT_SIZES := ["small", "normal", "large"]
const DRUNK_EFFECT_MODES := ["distortion", "classic"]
const HAPTICS_CUT_REASON := "Haptics are not used by the current demo input stack."

var resolution: Vector2i = Vector2i(1280, 720)
var window_mode: String = "windowed"
var vsync_enabled: bool = true
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var audio_calm: bool = false
var ui_scale: float = 1.0
var text_size: String = "normal"
var reduce_motion: bool = false
var drunk_effect_mode: String = "distortion"
var high_contrast: bool = false
var play_on_small_screen: bool = false
var selected_home_type_id: String = "random"


# Restores default preference values.
func reset() -> void:
	resolution = Vector2i(1280, 720)
	window_mode = "windowed"
	vsync_enabled = true
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 0.8
	audio_calm = false
	ui_scale = 1.0
	text_size = "normal"
	reduce_motion = false
	drunk_effect_mode = "distortion"
	high_contrast = false
	play_on_small_screen = false
	selected_home_type_id = "random"


# Loads preferences from disk or defaults.
func load() -> void:
	reset()
	var path := settings_path()
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed)


# Saves preferences to disk.
func save() -> Error:
	var file := FileAccess.open(settings_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


# Returns the live settings path, with test harnesses allowed to opt into isolation.
static func settings_path() -> String:
	var override := OS.get_environment(SETTINGS_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return SETTINGS_PATH


# Converts preferences to saveable data.
func to_dict() -> Dictionary:
	return {
		"resolution": {
			"width": resolution.x,
			"height": resolution.y,
		},
		"window_mode": window_mode,
		"vsync_enabled": vsync_enabled,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"audio_calm": audio_calm,
		"ui_scale": ui_scale,
		"text_size": text_size,
		"reduce_motion": reduce_motion,
		"drunk_effect_mode": drunk_effect_mode,
		"high_contrast": high_contrast,
		"play_on_small_screen": play_on_small_screen,
		"selected_home_type_id": selected_home_type_id,
	}


# Restores and clamps preference data.
func from_dict(data: Dictionary) -> void:
	var size: Dictionary = data.get("resolution", {})
	resolution = Vector2i(int(size.get("width", resolution.x)), int(size.get("height", resolution.y)))
	if not RESOLUTIONS.has(resolution):
		resolution = Vector2i(1280, 720)

	window_mode = data.get("window_mode", window_mode)
	if not WINDOW_MODES.has(window_mode):
		window_mode = "windowed"

	vsync_enabled = bool(data.get("vsync_enabled", vsync_enabled))
	master_volume = _volume(data.get("master_volume", master_volume))
	music_volume = _volume(data.get("music_volume", music_volume))
	sfx_volume = _volume(data.get("sfx_volume", sfx_volume))
	audio_calm = bool(data.get("audio_calm", audio_calm))
	ui_scale = clampf(float(data.get("ui_scale", ui_scale)), 0.85, 1.3)
	text_size = data.get("text_size", text_size)
	if not TEXT_SIZES.has(text_size):
		text_size = "normal"
	reduce_motion = bool(data.get("reduce_motion", reduce_motion))
	drunk_effect_mode = str(data.get("drunk_effect_mode", drunk_effect_mode))
	if not DRUNK_EFFECT_MODES.has(drunk_effect_mode):
		drunk_effect_mode = "distortion"
	high_contrast = bool(data.get("high_contrast", high_contrast))
	play_on_small_screen = bool(data.get("play_on_small_screen", play_on_small_screen))
	selected_home_type_id = str(data.get("selected_home_type_id", selected_home_type_id)).strip_edges()
	if selected_home_type_id.is_empty():
		selected_home_type_id = "random"


# Applies preferences to Godot services.
func apply() -> void:
	_bus(MUSIC_BUS)
	_bus(SFX_BUS)
	_apply_window()
	_apply_audio()


# Returns the selected resolution index.
func resolution_index() -> int:
	return max(0, RESOLUTIONS.find(resolution))


# Sets resolution from a UI index.
func set_resolution(index: int) -> void:
	resolution = RESOLUTIONS[clampi(index, 0, RESOLUTIONS.size() - 1)]


# Returns the selected window mode index.
func mode_index() -> int:
	return max(0, WINDOW_MODES.find(window_mode))


# Sets window mode from a UI index.
func set_mode(index: int) -> void:
	window_mode = WINDOW_MODES[clampi(index, 0, WINDOW_MODES.size() - 1)]


# Returns the selected text size index.
func text_index() -> int:
	return max(0, TEXT_SIZES.find(text_size))


# Sets text size from a UI index.
func set_text(index: int) -> void:
	text_size = TEXT_SIZES[clampi(index, 0, TEXT_SIZES.size() - 1)]


# Returns the font multiplier for the selected readability size.
func text_scale() -> float:
	match text_size:
		"small":
			return 0.92
		"large":
			return 1.16
		_:
			return 1.0


# Returns settings that are useful to UI and tests without exposing engine calls.
func accessibility_snapshot() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"text_size": text_size,
		"text_scale": text_scale(),
		"reduce_motion": reduce_motion,
		"audio_calm": audio_calm,
		"drunk_effect_mode": drunk_effect_mode,
		"high_contrast": high_contrast,
		"play_on_small_screen": play_on_small_screen,
		"haptics_supported": false,
		"haptics_cut_reason": HAPTICS_CUT_REASON,
	}


# Returns the selected drunk visual-effect index.
func drunk_effect_index() -> int:
	return max(0, DRUNK_EFFECT_MODES.find(drunk_effect_mode))


# Sets drunk visual effect from a UI index.
func set_drunk_effect(index: int) -> void:
	drunk_effect_mode = DRUNK_EFFECT_MODES[clampi(index, 0, DRUNK_EFFECT_MODES.size() - 1)]


# Applies current window and display settings.
func _apply_window() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	# Keep the demo framed to the selected 16:9 size so the UI can be authored
	# against a known canvas instead of spilling outside a resized window.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)

	match window_mode:
		"fullscreen":
			DisplayServer.window_set_min_size(Vector2i.ZERO)
			DisplayServer.window_set_max_size(Vector2i.ZERO)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_min_size(Vector2i.ZERO)
			DisplayServer.window_set_max_size(Vector2i.ZERO)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			var window_size := _safe_window_size()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_min_size(Vector2i.ZERO)
			DisplayServer.window_set_max_size(Vector2i.ZERO)
			DisplayServer.window_set_size(window_size)
			DisplayServer.window_set_min_size(window_size)
			DisplayServer.window_set_max_size(window_size)
			_center_window(window_size)


# Centers a windowed display on the current screen.
func _center_window(window_size: Vector2i) -> void:
	var screen_size := DisplayServer.screen_get_size()
	var position := Vector2i(
		max(0, int((screen_size.x - window_size.x) / 2)),
		max(0, int((screen_size.y - window_size.y) / 2))
	)
	DisplayServer.window_set_position(position)


# Keeps the selected 16:9 window inside the usable monitor area.
func _safe_window_size() -> Vector2i:
	var screen_size := DisplayServer.screen_get_size()
	if resolution.x <= screen_size.x and resolution.y <= screen_size.y:
		return resolution
	var width_scale := float(screen_size.x) / float(resolution.x)
	var height_scale := float(screen_size.y) / float(resolution.y)
	var scale: float = minf(minf(width_scale, height_scale), 1.0)
	var safe_width := maxi(640, int(floor(float(resolution.x) * scale)))
	var safe_height := int(round(float(safe_width) * 9.0 / 16.0))
	if safe_height > screen_size.y:
		safe_height = screen_size.y
		safe_width = int(round(float(safe_height) * 16.0 / 9.0))
	return Vector2i(safe_width, safe_height)


# Applies current audio bus volumes.
func _apply_audio() -> void:
	_set_volume("Master", master_volume)
	_set_volume(MUSIC_BUS, music_volume)
	_set_volume(SFX_BUS, sfx_volume)


# Finds or creates an audio bus.
func _bus(bus_name: String) -> int:
	# Create buses early so audio sliders have targets.
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	return bus_index


# Sets one audio bus volume from a linear value.
func _set_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped := _volume(value)
	var volume_db := -80.0 if clamped <= 0.0 else linear_to_db(clamped)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


# Clamps a value to the allowed volume range.
func _volume(value: Variant) -> float:
	return clampf(float(value), 0.0, 1.0)
