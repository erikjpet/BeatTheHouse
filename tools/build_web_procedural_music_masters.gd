extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const ARCHETYPES_PATH := "res://data/environments/archetypes.json"
const PCM_ROOT := "res://.tmp/web_procedural_music_pcm"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PCM_ROOT))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARCHETYPES_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Environment archetypes are not an array: %s" % ARCHETYPES_PATH)
		quit(1)
		return
	var player = ProceduralMusicPlayerScript.new()
	var rendered: Array = []
	for archetype_value in parsed as Array:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var environment: Dictionary = (archetype_value as Dictionary).duplicate(true)
		var archetype_id := str(environment.get("id", "")).strip_edges()
		var music_profile: Dictionary = environment.get("music_profile", {}) as Dictionary
		if archetype_id.is_empty() or not str(music_profile.get("authored_track_id", "")).strip_edges().is_empty():
			continue
		environment["archetype_id"] = archetype_id
		var profile: Dictionary = player.call("_music_profile_from_environment", environment, 0)
		var token: int = player.call("_current_generation_token")
		var stem_set: Dictionary = player.call(
			"_web_music_bed_stem_set",
			profile,
			ProceduralMusicPlayerScript.WEB_AUDIO_MUSIC_BED_SECONDS,
			"web_prebuilt",
			token
		)
		var stems: Dictionary = stem_set.get("stems", {}) as Dictionary
		var stream: AudioStreamWAV = stems.get("pad") as AudioStreamWAV
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.is_empty():
			push_error("Could not render procedural Web music master: %s" % archetype_id)
			player.free()
			quit(1)
			return
		var output_base := "%s/%s" % [PCM_ROOT, archetype_id]
		var error := stream.save_to_wav(output_base)
		if error != OK:
			push_error("Could not save procedural Web music master: %s (%s)" % [archetype_id, error_string(error)])
			player.free()
			quit(1)
			return
		rendered.append({
			"archetype_id": archetype_id,
			"frames": int(stem_set.get("loop_frames", 0)),
			"sample_rate": stream.mix_rate,
			"path": "%s.wav" % output_base,
		})
	player.free()
	print(JSON.stringify({"count": rendered.size(), "files": rendered}))
	quit(0)
