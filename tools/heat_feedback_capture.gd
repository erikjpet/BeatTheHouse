extends SceneTree

# Captures the real run UI at the peak of low and high Heat-gain responses.

const MainScene := preload("res://scenes/main.tscn")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const OUTPUT_DIR := "res://review_artifacts/heat_gain_feedback_implementation"
const CAPTURE_SIZE := Vector2i(1280, 720)
const SAVE_SLOT := "heat_feedback_capture"

var app: Control
var saved_files: Array[String] = []
var capture_failed := false
var audio_preview_profile: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_output)
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#08070d"))
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(3)
	app.call("start_foundation_run", "HEAT-FEEDBACK-CAPTURE")
	await _settle(4)

	var state: RunState = app.get("run_state")
	state.suspicion["level"] = 0
	app.call("_refresh")
	await _settle(2)
	state.add_suspicion("capture_low", 2, "probe", true)
	app.call("_refresh")
	await _advance_to_peak()
	await _save_viewport("01_environment_low_gain_plus_2.png")
	if capture_failed:
		quit(1)
		return

	_cancel_feedback()
	state.suspicion["level"] = 55
	app.call("_refresh")
	await _settle(2)
	state.add_suspicion("capture_high", 20, "probe", true)
	app.call("_refresh")
	await _advance_to_peak()
	await _save_viewport("02_environment_high_gain_plus_20.png")
	if capture_failed:
		quit(1)
		return

	app.call("start_game_test_session", "blackjack")
	await _settle(4)
	state = app.get("run_state") as RunState
	state.suspicion["level"] = 63
	app.call("_refresh")
	await _settle(2)
	state.add_suspicion("capture_game", 12, "probe", true)
	app.call("_refresh")
	await _advance_to_peak()
	await _save_viewport("03_game_view_gain_plus_12.png")
	if capture_failed:
		quit(1)
		return

	_save_audio_preview()
	if capture_failed:
		quit(1)
		return
	_write_manifest()
	print("HEAT_FEEDBACK_CAPTURE_PASS files=%d dir=%s" % [saved_files.size(), absolute_output])
	quit(0)


func _advance_to_peak() -> void:
	var overlay: Control = app.get("heat_gain_feedback_overlay")
	var hud: Control = app.get("structured_hud")
	if overlay != null:
		overlay.call("_process", 0.080)
	if hud != null:
		hud.call("_process", 0.080)
	await process_frame
	await process_frame


func _cancel_feedback() -> void:
	var overlay: Control = app.get("heat_gain_feedback_overlay")
	var hud: Control = app.get("structured_hud")
	if overlay != null:
		overlay.call("cancel")
	if hud != null:
		hud.call("cancel_heat_feedback")


func _save_viewport(filename: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		capture_failed = true
		push_error("Viewport capture is unavailable. Run this tool windowed, not with the dummy headless renderer.")
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var error := image.save_png(path)
	if error != OK:
		capture_failed = true
		push_error("Could not save Heat feedback screenshot %s (error %d)." % [path, error])
		return
	saved_files.append(filename)


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _save_audio_preview() -> void:
	var player = SfxPlayerScript.new()
	audio_preview_profile = player.call("heat_gain_audio_profile", 8)
	var source: AudioStreamWAV = player.call("render_event_master_stream", "heat_gain")
	if source == null or source.data.is_empty():
		capture_failed = true
		push_error("Could not render the Heat-gain audio preview.")
		player.free()
		return
	var preview := source.duplicate(true) as AudioStreamWAV
	var data := source.data.duplicate()
	var gain := pow(10.0, float(audio_preview_profile.get("volume_db", -13.0)) / 20.0)
	for offset in range(0, data.size(), 2):
		var sample := data.decode_s16(offset)
		data.encode_s16(offset, clampi(roundi(float(sample) * gain), -32768, 32767))
	preview.data = data
	var output_base := "%s/04_heat_gain_sound_plus_8" % OUTPUT_DIR
	var error := preview.save_to_wav(output_base)
	if error != OK:
		capture_failed = true
		push_error("Could not save the Heat-gain audio preview (error %d)." % error)
		player.free()
		return
	saved_files.append("04_heat_gain_sound_plus_8.wav")
	player.free()


func _write_manifest() -> void:
	var manifest := {
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"files": saved_files,
		"examples": [
			{"file": saved_files[0], "view": "environment", "heat_gain": 2, "description": "Light response for a small Heat gain."},
			{"file": saved_files[1], "view": "environment", "heat_gain": 20, "description": "Stronger response for a large single Heat gain."},
			{"file": saved_files[2], "view": "game", "heat_gain": 12, "description": "High-Heat game view showing the unified police-light strength and gain response."},
		],
		"audio_preview": {
			"file": "04_heat_gain_sound_plus_8.wav",
			"heat_gain": 8,
			"runtime_profile": audio_preview_profile,
			"description": "Mid-strength preview of the subtle radio-chirp Heat cue.",
		},
	}
	var file := FileAccess.open("%s/manifest.json" % OUTPUT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t") + "\n")
		saved_files.append("manifest.json")
