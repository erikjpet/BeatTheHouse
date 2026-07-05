extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")

const DEFAULT_ITERATIONS := 12000
const DEFAULT_WARMUP := 600
const SAMPLE_RATE := 22050

var iterations := DEFAULT_ITERATIONS
var warmup_iterations := DEFAULT_WARMUP
var output_path := "res://.tmp/audio_perf_probe/report.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	iterations = maxi(100, int(_env_string("BTH_AUDIO_PERF_ITERATIONS", str(DEFAULT_ITERATIONS))))
	warmup_iterations = maxi(10, int(_env_string("BTH_AUDIO_PERF_WARMUP", str(DEFAULT_WARMUP))))
	var requested_out := _env_string("BTH_AUDIO_PERF_OUT", ".tmp/audio_perf_probe/report.json")
	output_path = "res://" + requested_out.replace("\\", "/").trim_prefix("./").trim_prefix(".\\")
	var report := {
		"tool": "audio_perf_probe",
		"iterations": iterations,
		"warmup_iterations": warmup_iterations,
		"music": _measure_music(),
		"sfx": _measure_sfx(),
	}
	_write_report(report)
	print(JSON.stringify(report))
	quit(0)


func _measure_music() -> Dictionary:
	var player: ProceduralMusicPlayer = ProceduralMusicPlayerScript.new()
	root.add_child(player)
	var state := _music_state()
	player.update_music_state(state)
	for _index in range(warmup_iterations):
		player._process(1.0 / 60.0)
	var steady := _measure_loop(func() -> void:
		player._process(1.0 / 60.0)
	)
	player.update_music_state(_music_state(true))
	var transitioning := _measure_loop(func() -> void:
		player._process(1.0 / 60.0)
	)
	var graph := player.music_fx_snapshot({}).get("graph", {}) as Dictionary
	var player_instantiated := bool(player.music_fx_snapshot({}).get("player_instantiated", false))
	player.free()
	return {
		"steady_process": steady,
		"transition_process": transitioning,
		"effect_count": int(graph.get("effect_count", 0)),
		"player_instantiated": player_instantiated,
	}


func _measure_sfx() -> Dictionary:
	var player: SfxPlayer = SfxPlayerScript.new()
	root.add_child(player)
	player.call("_ensure_players")
	var cold_started := Time.get_ticks_usec()
	var cold_streams := 0
	for event_id in ["roulette_chip_place", "roulette_ball_loop", "blackjack_card", "bonus_start_pinball", "jackpot_buffalo", "pull_tab_click"]:
		var stream: AudioStreamWAV = player.call("preview_event_stream", event_id)
		if stream != null:
			cold_streams += 1
	var cold_usec := maxi(0, Time.get_ticks_usec() - cold_started)
	for _index in range(warmup_iterations):
		player.call("_play", "roulette_chip_place", -4.0, 1.0)
	var warm_play := _measure_loop(func() -> void:
		player.call("_play", "roulette_chip_place", -4.0, 1.0)
	)
	var roulette_sync_state := {
		"last_result": {"bankroll_delta": 25},
	}
	var roulette_sync := _measure_loop(func() -> void:
		player.sync_roulette_state(roulette_sync_state, 2.0, true, "probe-spin", 0.0, false, "")
	)
	var player_count := int((player.get("_players") as Array).size()) if player.get("_players") is Array else 0
	var cache_count := int((player.get("_stream_cache") as Dictionary).size()) if player.get("_stream_cache") is Dictionary else 0
	player.free()
	return {
		"cold_streams": cold_streams,
		"cold_stream_total_ms": float(cold_usec) / 1000.0,
		"warm_play": warm_play,
		"roulette_sync_active": roulette_sync,
		"pooled_players": player_count,
		"cached_streams": cache_count,
	}


func _measure_loop(callable: Callable) -> Dictionary:
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var object_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var started := Time.get_ticks_usec()
	for _index in range(iterations):
		callable.call()
	var elapsed := maxi(0, Time.get_ticks_usec() - started)
	var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var object_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	return {
		"total_ms": snappedf(float(elapsed) / 1000.0, 0.001),
		"avg_usec": snappedf(float(elapsed) / float(iterations), 0.001),
		"memory_delta": memory_after - memory_before,
		"object_delta": object_after - object_before,
	}


func _music_state(drunk: bool = false) -> Dictionary:
	var drunk_level := 82 if drunk else 0
	return {
		"environment": {
			"id": "probe_room",
			"name": "Probe Room",
			"archetype_id": "neon_bar",
			"kind": "casino",
			"visual_context": {
				"scene_type": "casino",
				"room_scale": 0.62,
			},
			"music_profile": {
				"theme": "neon",
				"palette_id": "probe",
			},
		},
		"visual_context": {
			"scene_type": "casino",
			"room_scale": 0.62,
		},
		"heat": 38 if not drunk else 92,
		"drunk_level": drunk_level,
		"pit_boss_watch": {"active": drunk, "watched": drunk},
		"staff_attention": {"active": drunk},
	}


func _write_report(report: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))


func _env_string(key: String, fallback: String) -> String:
	var value := OS.get_environment(key)
	if value.is_empty():
		return fallback
	return value
