extends SceneTree

const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")


func _init() -> void:
	var destination_root := "res://assets/audio/sfx_web"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_root))
	var player := SfxPlayerScript.new()
	var total_bytes := 0
	var count := 0
	for event_value in SfxPlayerScript.WEB_DELIVERY_EVENT_IDS:
		var event_id := str(event_value)
		var stream: AudioStreamWAV = player.preview_event_stream(event_id)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.is_empty():
			push_error("Could not render Web SFX master: %s" % event_id)
			quit(1)
			return
		var path := "%s/%s.bthsfx" % [destination_root, event_id]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write Web SFX master: %s" % path)
			quit(1)
			return
		var loop_enabled := stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
		file.store_line("BTHS|1|%d|%d|%d" % [stream.mix_rate, stream.loop_end, 1 if loop_enabled else 0])
		file.store_string(Marshalls.raw_to_base64(stream.data))
		file.close()
		var keep := FileAccess.open("%s.import" % path, FileAccess.WRITE)
		keep.store_string("[remap]\n\nimporter=\"keep\"\n")
		keep.close()
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		count += 1
	player.free()
	print(JSON.stringify({"count": count, "bytes": total_bytes, "sample_rate": SfxPlayerScript.SAMPLE_RATE}))
	quit(0)
