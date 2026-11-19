extends SceneTree

# One original CRT profile only. Run in a fresh admitted E: Job; never rebuild
# unrelated music or write generated masters into a developer/source profile.
const Music := preload("res://scripts/ui/procedural_music_player.gd")

func _init() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/")
	if not evidence.to_lower().begins_with("e:/codexqa/bth/runs/"):
		push_error("CRT music bake requires fresh admitted E: evidence.")
		quit(2)
		return
	var player := Music.new()
	var environment := player.crt_practice_theme_environment()
	var stream: AudioStreamWAV = player.preview_stream_for_environment(environment, 0)
	if stream == null or stream.mix_rate != 44100 or stream.stereo or stream.data.size() != 3528000:
		push_error("CRT profile did not render its exact40s mono44.1kHz PCM16 master.")
		player.free()
		quit(1)
		return
	var base := evidence.path_join("crt-practice-master")
	var error := stream.save_to_wav(base)
	if error != OK:
		push_error("CRT master write failed: %s" % error)
		player.free()
		quit(1)
		return
	var path := base + ".wav"
	var result := {"passed": true, "path": path, "sha256": FileAccess.get_sha256(path), "rate": stream.mix_rate, "channels": 1, "frames": 1764000, "seconds": 40, "bpm": 96, "bars": 16, "profile": environment}
	var output := FileAccess.open(evidence.path_join("crt-music-bake.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("CRT_MUSIC_BAKE " + JSON.stringify(result))
	player.free()
	quit(0)
