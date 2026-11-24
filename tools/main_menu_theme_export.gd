extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const OUTPUT_FILENAME := "03_main_menu_theme"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_dir := OS.get_environment("BTH_ART_OUTPUT_DIR").strip_edges().replace("\\", "/")
	var output_dir := requested_dir.simplify_path().trim_suffix("/")
	var project_dir := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/")
	var output_key := output_dir.to_lower() if OS.has_feature("windows") else output_dir
	var project_key := project_dir.to_lower() if OS.has_feature("windows") else project_dir
	if requested_dir.is_empty() or not output_dir.is_absolute_path() or output_dir.begins_with("res://") or output_dir.begins_with("user://") \
			or output_key == project_key or output_key.begins_with(project_key + "/") \
			or (OS.has_feature("windows") and output_key.begins_with("c:/")) \
			or not DirAccess.dir_exists_absolute(output_dir):
		push_error("Set BTH_ART_OUTPUT_DIR to an existing absolute folder outside this checkout and not on C:.")
		quit(2)
		return
	var output_base := output_dir.path_join(OUTPUT_FILENAME)
	var player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	var stream: AudioStreamWAV = player.preview_stream_for_environment(player.main_menu_theme_environment(), 0)
	if stream == null or stream.data.is_empty():
		push_error("Could not generate main-menu theme preview.")
		quit(1)
		return
	var error := stream.save_to_wav(output_base)
	if error != OK:
		push_error("Could not save main-menu theme preview (error %d)." % error)
		quit(1)
		return
	print("MAIN_MENU_THEME_EXPORT_PASS path=%s.wav" % output_base)
	stream = null
	player.free()
	quit(0)
