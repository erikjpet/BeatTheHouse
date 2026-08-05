extends SceneTree

const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")


func _init() -> void:
	var destination_root := "res://assets/audio/sfx_native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_root))
	var player := SfxPlayerScript.new()
	var total_bytes := 0
	var count := 0
	for event_value in SfxPlayerScript.NATIVE_SLOT_DELIVERY_EVENTS.keys():
		var event_id := str(event_value)
		var stream: AudioStreamWAV = player.render_event_master_stream(event_id)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.is_empty():
			push_error("Could not render native slot SFX master: %s" % event_id)
			player.free()
			quit(1)
			return
		var path := "%s/%s.bthpcm" % [destination_root, event_id]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write native slot SFX master: %s" % path)
			player.free()
			quit(1)
			return
		file.store_buffer("BTHP".to_ascii_buffer())
		file.store_8(1)
		file.store_8(1)
		file.store_8(1 if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED else 0)
		file.store_8(0)
		file.store_32(stream.mix_rate)
		file.store_32(stream.data.size() / 2)
		file.store_buffer(stream.data)
		file.close()
		var keep := FileAccess.open("%s.import" % path, FileAccess.WRITE)
		keep.store_string("[remap]\n\nimporter=\"keep\"\n")
		keep.close()
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		count += 1
	player.free()
	print(JSON.stringify({"count": count, "bytes": total_bytes, "sample_rate": SfxPlayerScript.SAMPLE_RATE}))
	quit(0)
