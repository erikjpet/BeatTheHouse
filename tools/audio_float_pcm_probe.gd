extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const MusicFloatPcmStreamScript := preload("res://scripts/ui/music_float_pcm_stream.gd")


func _init() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var started_msec := Time.get_ticks_msec()
	var failures: Array[String] = []
	var director: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()

	var jazz_8_environment := {
		"id": "jazz_delivery_8",
		"archetype_id": "jazz_club",
		"music_profile": {"authored_track_id": "jazz_club_delivery_fixture_8_bar", "palette_id": "jazz_delivery_8", "bpm": 120.0},
	}
	var jazz_8_manifest: Dictionary = director.music_stem_manifest_snapshot_for_environment(jazz_8_environment, 40)
	var jazz_source_format: Dictionary = jazz_8_manifest.get("source_audio_format", {}) as Dictionary
	var jazz_playback_format: Dictionary = jazz_8_manifest.get("playback_audio_format", {}) as Dictionary
	if str(jazz_8_manifest.get("source", "")) != "authored" or not bool(jazz_8_manifest.get("sync_ok", false)) or int(jazz_8_manifest.get("loop_frames", 0)) != 705600:
		failures.append("Native authored provider did not load the 24-bit 8-bar Jazz fixture as a synchronized set.")
	if int(jazz_source_format.get("bit_depth", 0)) != 24 or not bool(jazz_source_format.get("master_preserved", false)) or str(jazz_playback_format.get("sample_type", "")) != "float32" or not bool(jazz_playback_format.get("decoded_from_24_bit", false)):
		failures.append("Jazz snapshot did not expose preserved 24-bit source and native float PCM playback formats.")
	var precision_by_role: Dictionary = jazz_8_manifest.get("float_pcm_precision", {}) as Dictionary
	for role in ["pad", "bass", "lead", "drums_high"]:
		var precision: Dictionary = precision_by_role.get(role, {}) as Dictionary
		if str(precision.get("provider", "")) != "cached_float_pcm_generator" or int(precision.get("samples_beyond_16_bit", 0)) <= 0 or not bool(precision.get("low_order_information_preserved", false)) or int(precision.get("max_reconstruction_error_lsb", 99)) > 1:
			failures.append("Native Jazz float provider did not preserve real low-order PCM24 information for %s." % role)
	var low_order_a := MusicFloatPcmStreamScript.pcm24_to_float(65536)
	var low_order_b := MusicFloatPcmStreamScript.pcm24_to_float(65537)
	if low_order_a == low_order_b or int(round(low_order_a * 32768.0)) != int(round(low_order_b * 32768.0)):
		failures.append("24-bit float decoder did not preserve adjacent values that collapse to one 16-bit sample.")
	var jazz_delivery_files: Array = jazz_8_manifest.get("delivery_files", []) as Array
	if jazz_delivery_files.size() != 4 or JSON.stringify(jazz_delivery_files).find("JazzClub_Lead_Trumpet_1.wav") < 0 or JSON.stringify(jazz_delivery_files).find("pattern_number") < 0:
		failures.append("Jazz snapshot did not expose parsed delivery filename fields for selected stems.")
	var preferred_sends: Dictionary = jazz_8_manifest.get("preferred_dsp_sends", {}) as Dictionary
	if float((preferred_sends.get("lead", {}) as Dictionary).get("reverb", 0.0)) <= 0.0 or float((preferred_sends.get("pad", {}) as Dictionary).get("reverb", 0.0)) <= 0.0:
		failures.append("Jazz authored delivery did not preserve preferred stem-specific DSP sends.")
	var inherited_sends: Dictionary = director.call("_authored_delivery_snapshot", {"stems": {"lead": {"dsp_sends": {"reverb": 0.33}}}}, {"lead": {"file": "JazzClub_Lead_Trumpet_1.wav"}})
	var overridden_sends: Dictionary = director.call("_authored_delivery_snapshot", {"stems": {"lead": {"dsp_sends": {"reverb": 0.33}}}}, {"lead": {"file": "JazzClub_Lead_Trumpet_1.wav", "dsp_sends": {"reverb": 0.44}}})
	var dry_sends: Dictionary = director.call("_authored_delivery_snapshot", {"stems": {"lead": {"dsp_sends": {"reverb": 0.33}}}}, {"lead": {"file": "JazzClub_Lead_Trumpet_1.wav", "dsp_sends": {}}})
	if not is_equal_approx(float((((inherited_sends.get("preferred_dsp_sends", {}) as Dictionary).get("lead", {}) as Dictionary).get("reverb", 0.0))), 0.33) or not is_equal_approx(float((((overridden_sends.get("preferred_dsp_sends", {}) as Dictionary).get("lead", {}) as Dictionary).get("reverb", 0.0))), 0.44) or not ((dry_sends.get("preferred_dsp_sends", {}) as Dictionary).get("lead", {}) as Dictionary).is_empty():
		failures.append("Authored variant DSP preferences did not inherit, override, and explicitly clear role defaults.")
	var stinger_modes: Dictionary = jazz_8_manifest.get("stinger_loop_modes", {}) as Dictionary
	var fill_modes: Dictionary = jazz_8_manifest.get("fill_loop_modes", {}) as Dictionary
	for cue_id in ["jazz_fixture_small_win", "jazz_fixture_loss", "jazz_fixture_big_win"]:
		if int(stinger_modes.get(cue_id, -1)) != AudioStreamWAV.LOOP_DISABLED:
			failures.append("24-bit Jazz outcome stinger %s did not load as a one-shot float stream." % cue_id)
	if int(fill_modes.get("jazz_fixture_fill", -1)) != AudioStreamWAV.LOOP_DISABLED:
		failures.append("24-bit Jazz stingers and fills did not load as one-shot float streams.")

	var jazz_16_environment := jazz_8_environment.duplicate(true)
	jazz_16_environment["id"] = "jazz_delivery_16"
	jazz_16_environment["music_profile"] = {"authored_track_id": "jazz_club_delivery_fixture_16_bar", "palette_id": "jazz_delivery_16", "bpm": 120.0}
	var jazz_16_manifest: Dictionary = director.music_stem_manifest_snapshot_for_environment(jazz_16_environment, 40)
	if str(jazz_16_manifest.get("source", "")) != "authored" or not bool(jazz_16_manifest.get("sync_ok", false)) or int(jazz_16_manifest.get("loop_frames", 0)) != 1411200:
		failures.append("Native authored provider did not load the 24-bit 16-bar Jazz fixture.")
	var jazz_16_precision: Dictionary = (jazz_16_manifest.get("float_pcm_precision", {}) as Dictionary).get("pad", {}) as Dictionary
	if int(jazz_16_precision.get("frames", 0)) != 1411200 or not bool(jazz_16_precision.get("low_order_information_preserved", false)):
		failures.append("16-bar float provider did not retain its full decoded frame count and low-order information.")

	var launch_authority := ProceduralMusicPlayerScript.float_pcm_launch_frame_snapshot(3.125, 44100, 0, 705600, true)
	var aligned_launch := ProceduralMusicPlayerScript.float_pcm_launch_frame_snapshot(3.125 + 1.0 / 44100.0, 44100, 0, 705600, true, int(launch_authority.get("source_frame", -1)))
	if int(aligned_launch.get("source_frame", -1)) != int(launch_authority.get("source_frame", -2)) or int(aligned_launch.get("phase_error_frames", 99)) != 0:
		failures.append("Float PCM launch planner did not map group members onto one authoritative source frame.")

	# Exercise the actual AudioStreamGenerator path, not just its metadata.
	var contract: Dictionary = director.call("_authored_stem_set_from_profile", jazz_8_environment.get("music_profile", {}), {})
	var pad_stream: AudioStream = (contract.get("stems", {}) as Dictionary).get("pad", null)
	if not (pad_stream is MusicFloatPcmStream):
		failures.append("Jazz PCM24 stem did not resolve to MusicFloatPcmStream.")
	else:
		var voice_a := AudioStreamPlayer.new()
		var voice_b := AudioStreamPlayer.new()
		root.add_child(voice_a)
		root.add_child(voice_b)
		voice_a.stream = pad_stream
		voice_b.stream = pad_stream
		director.call("_play_audio_player", voice_a, 3.125, "native_probe_stems")
		director.call("_play_audio_player", voice_b, 3.125 + 1.0 / 44100.0, "native_probe_stems")
		var provider_snapshot: Dictionary = director.float_pcm_provider_snapshot()
		var matched_launch := false
		for launch_value in (provider_snapshot.get("launches", {}) as Dictionary).values():
			var launch: Dictionary = launch_value as Dictionary
			if str(launch.get("phase_group", "")) == "native_probe_stems" and int(launch.get("players", 0)) == 2 and int(launch.get("max_phase_error_frames", 99)) == 0:
				matched_launch = true
		if int(provider_snapshot.get("active_players", 0)) < 2 or not matched_launch:
			failures.append("Two live float generator players did not share the authoritative zero-error launch frame.")
		voice_a.stop()
		voice_b.stop()
		director.call("_feed_float_pcm_players")
		voice_a.stream = null
		voice_b.stream = null
		# Headless process frames can advance faster than the audio mixing thread.
		# Queue normal Node teardown, remove the director's playback references,
		# then allow more than one generator buffer of real mixer time to elapse.
		director.set("_float_pcm_player_states", {})
		voice_a.queue_free()
		voice_b.queue_free()
		await process_frame
		await create_timer(0.35).timeout

	var report := {
		"tool": "audio_float_pcm_probe",
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"failures": failures,
		"duration_msec": Time.get_ticks_msec() - started_msec,
		"fixture_8_frames": int(jazz_8_manifest.get("loop_frames", 0)),
		"fixture_16_frames": int(jazz_16_manifest.get("loop_frames", 0)),
		"source_bit_depth": int(jazz_source_format.get("bit_depth", 0)),
		"mixer_sample_type": str(jazz_playback_format.get("sample_type", "")),
	}
	var report_path := _report_path()
	_write_report(report_path, report)
	pad_stream = null
	contract.clear()
	jazz_8_manifest.clear()
	jazz_16_manifest.clear()
	director.free()
	await process_frame
	await create_timer(0.10).timeout
	if failures.is_empty():
		print("AUDIO_FLOAT_PCM_PROBE_PASS report=%s" % report_path)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _report_path() -> String:
	for value in OS.get_cmdline_user_args():
		var argument := str(value)
		if argument.begins_with("--report="):
			return argument.get_slice("=", 1)
	return "res://.tmp/test_reports/audio_float_pcm_probe.json"


func _write_report(path: String, report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
