extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const OUTPUT_BASE := "res://review_artifacts/main_menu_redesign/03_main_menu_theme"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review_artifacts/main_menu_redesign"))
	var player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	var stream: AudioStreamWAV = player.preview_stream_for_environment(player.main_menu_theme_environment(), 0)
	if stream == null or stream.data.is_empty():
		push_error("Could not generate main-menu theme preview.")
		quit(1)
		return
	var error := stream.save_to_wav(OUTPUT_BASE)
	if error != OK:
		push_error("Could not save main-menu theme preview (error %d)." % error)
		quit(1)
		return
	print("MAIN_MENU_THEME_EXPORT_PASS path=%s.wav" % ProjectSettings.globalize_path(OUTPUT_BASE))
	stream = null
	player.free()
	quit(0)
