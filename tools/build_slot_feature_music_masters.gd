extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const PCM_ROOT := "res://.tmp/slot_feature_music_pcm"
const PROFILES := {
	"buffalo": {"bpm": 78.0, "root_midi": 42, "bars": 2},
	"arcade": {"bpm": 96.0, "root_midi": 52, "bars": 2},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PCM_ROOT))
	var player = ProceduralMusicPlayerScript.new()
	var rendered: Array = []
	for style_value in PROFILES.keys():
		var style := str(style_value)
		var profile: Dictionary = PROFILES.get(style, {}) as Dictionary
		var bpm := float(profile.get("bpm", 96.0))
		var bars := int(profile.get("bars", 2))
		var step_period := 60.0 / maxf(1.0, bpm) * 0.5
		var frames := maxi(1, int(step_period * 8.0 * float(bars) * float(ProceduralMusicPlayerScript.SAMPLE_RATE)))
		var stem_data: Dictionary = player.call("_feature_stem_pcm_data", style, int(profile.get("root_midi", 45)), bpm, frames, bars)
		var style_root := "%s/%s" % [PCM_ROOT, style]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(style_root))
		for role_value in ProceduralMusicPlayerScript.MUSIC_STEM_ROLES:
			var role := str(role_value)
			var data: PackedByteArray = stem_data.get(role, PackedByteArray())
			if data.size() != frames * 2:
				push_error("Invalid %s/%s feature stem data." % [style, role])
				player.free()
				quit(1)
				return
			var stream := AudioStreamWAV.new()
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			stream.mix_rate = ProceduralMusicPlayerScript.SAMPLE_RATE
			stream.data = data
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = frames
			var output_base := "%s/%s" % [style_root, role]
			var error := stream.save_to_wav(output_base)
			if error != OK:
				push_error("Could not save %s/%s feature stem: %s" % [style, role, error_string(error)])
				player.free()
				quit(1)
				return
			rendered.append({"style": style, "role": role, "frames": frames, "path": "%s.wav" % output_base})
	player.free()
	print(JSON.stringify({"count": rendered.size(), "files": rendered}))
	quit(0)
