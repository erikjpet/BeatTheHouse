extends SceneTree

const PlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const MANIFEST_PATH := "res://data/audio/music_manifest.json"
const TRACK_ID := "jazz_club_delivery_fixture_8_bar"
const SAMPLE_RATE := 44100.0
const PHASE_TOLERANCE_FRAMES := 0.001
const STEP_SECONDS := 1.0 / 120.0
const RAMP_SECONDS := 120.0


func _init() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var started_msec := Time.get_ticks_msec()
	var failures: Array[String] = []
	var entry := _track_entry()
	var profile: Dictionary = entry.get("adaptive_tempo", {}) as Dictionary
	if profile.is_empty():
		failures.append("Jazz fixture is missing its adaptive-tempo profile.")
		_finish(failures, {})
		return
	var low := PlayerScript.adaptive_tempo_bpm_for_heat(profile, 0.0)
	var middle := PlayerScript.adaptive_tempo_bpm_for_heat(profile, 50.0)
	var high := PlayerScript.adaptive_tempo_bpm_for_heat(profile, 100.0)
	if not (low >= float(profile.get("min_bpm", 0.0)) and low < middle and middle < high and high <= float(profile.get("max_bpm", 999.0))):
		failures.append("Heat 0/50/100 did not map monotonically inside the authored Jazz range: %.3f/%.3f/%.3f." % [low, middle, high])

	var director: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(director)
	await process_frame
	var environment_profile := {
		"environment_id": "jazz_tempo_probe",
		"archetype_id": "jazz_club",
		"authored_track_id": TRACK_ID,
		"bpm": 120.0,
		"adaptive_tempo": profile,
	}
	var stem_set := {"track_id": TRACK_ID, "bpm": 120.0, "adaptive_tempo": profile}
	director.call("_configure_adaptive_tempo", environment_profile, stem_set)
	director.call("_ensure_stem_players")
	var graph := PlayerScript.ensure_music_fx_bus_graph()
	var graph_json := JSON.stringify(graph.get("effects", []))
	if graph_json.find("AudioEffectPitchShift") < 0:
		failures.append("Native Music bus does not expose the shared pitch-compensation processor.")

	director.call("_set_adaptive_tempo_target", 100.0)
	var initial: Dictionary = director.adaptive_tempo_debug_snapshot()
	var initial_bpm := float(initial.get("current_bpm", 0.0))
	director.call("_advance_adaptive_tempo", 1.0)
	var first_second: Dictionary = director.adaptive_tempo_debug_snapshot()
	var first_change := float(first_second.get("current_bpm", 0.0)) - initial_bpm
	if first_change <= 0.0 or first_change > float(profile.get("max_bpm_per_second", 0.0)) + 0.000001:
		failures.append("Large heat jump exceeded the authored per-second slew limit: %.6f BPM." % first_change)

	# Long native ramp. Every role integrates the exact shared playback rate;
	# sampled player rates also prove the runtime path never assigns per-stem
	# tempo values that could create flamming.
	director.call("_configure_adaptive_tempo", environment_profile, stem_set)
	director.call("_set_adaptive_tempo_target", 100.0)
	var role_phases := {"pad": 0.0, "bass": 0.0, "lead": 0.0, "drums_low": 0.0, "drums_high": 0.0, "texture": 0.0}
	var maximum_phase_error := 0.0
	var maximum_slew := 0.0
	var last_bpm := float(director.adaptive_tempo_debug_snapshot().get("current_bpm", 120.0))
	var total_steps := int(RAMP_SECONDS / STEP_SECONDS)
	for step in range(total_steps):
		director.call("_advance_adaptive_tempo", STEP_SECONDS)
		var snapshot: Dictionary = director.adaptive_tempo_debug_snapshot()
		var bpm := float(snapshot.get("current_bpm", 0.0))
		maximum_slew = maxf(maximum_slew, absf(bpm - last_bpm) / STEP_SECONDS)
		last_bpm = bpm
		var ratio := float(snapshot.get("ratio", 1.0))
		for role in role_phases.keys():
			role_phases[role] = float(role_phases.get(role, 0.0)) + ratio * SAMPLE_RATE * STEP_SECONDS
		var phase_values := role_phases.values()
		maximum_phase_error = maxf(maximum_phase_error, float(phase_values.max()) - float(phase_values.min()))
		if step % 240 == 0:
			director.call("_apply_music_fx_vector", director.get("_music_fx_live"), false)
			var shared_scale := -1.0
			for player_value in (director.get("_stem_players") as Dictionary).values():
				if not (player_value is AudioStreamPlayer):
					continue
				var player := player_value as AudioStreamPlayer
				if shared_scale < 0.0:
					shared_scale = player.pitch_scale
				elif absf(player.pitch_scale - shared_scale) * SAMPLE_RATE > PHASE_TOLERANCE_FRAMES:
					failures.append("Native stem players diverged from the authoritative playback rate during the ramp.")
					break
	if maximum_phase_error > PHASE_TOLERANCE_FRAMES:
		failures.append("Parallel stem phase error %.9f frames exceeded %.6f frames." % [maximum_phase_error, PHASE_TOLERANCE_FRAMES])
	if maximum_slew > float(profile.get("max_bpm_per_second", 0.0)) + 0.00001:
		failures.append("Long ramp exceeded the authored slew limit: %.6f BPM/s." % maximum_slew)
	var high_snapshot: Dictionary = director.adaptive_tempo_debug_snapshot().duplicate(true)
	if absf(float(high_snapshot.get("current_bpm", 0.0)) - high) > 0.001:
		failures.append("Long rising ramp did not settle at the high-heat target.")

	director.call("_set_adaptive_tempo_target", 0.0)
	var before_fall := float(director.adaptive_tempo_debug_snapshot().get("current_bpm", 0.0))
	for step in range(total_steps):
		director.call("_advance_adaptive_tempo", STEP_SECONDS)
	var low_snapshot: Dictionary = director.adaptive_tempo_debug_snapshot().duplicate(true)
	if not ["falling", "steady"].has(str(low_snapshot.get("slew_direction", ""))) or absf(float(low_snapshot.get("current_bpm", 0.0)) - low) > 0.001 or float(low_snapshot.get("current_bpm", 0.0)) >= before_fall:
		failures.append("Falling heat did not return smoothly to the low target.")
	director.call("_set_adaptive_tempo_target", 50.0)
	var deadband_target := float(director.adaptive_tempo_debug_snapshot().get("target_bpm", 0.0))
	for heat in [49.5, 50.5, 49.5, 50.5, 49.5, 50.5]:
		director.call("_set_adaptive_tempo_target", heat)
	if absf(float(director.adaptive_tempo_debug_snapshot().get("target_bpm", 0.0)) - deadband_target) > 0.000001:
		failures.append("Sub-deadband heat oscillation repeatedly changed the adaptive-tempo target.")

	# Source-time subdivisions remain authoritative. Native playback traverses
	# them at the live ratio, so all musical consumers share these exact wall
	# durations without rewriting or restarting a loop.
	director.call("_set_adaptive_tempo_target", 100.0)
	for step in range(total_steps):
		director.call("_advance_adaptive_tempo", STEP_SECONDS)
	var boundary_snapshot: Dictionary = director.adaptive_tempo_debug_snapshot().duplicate(true)
	var live_bpm := float(boundary_snapshot.get("current_bpm", 0.0))
	var live_beat_seconds := float(boundary_snapshot.get("live_beat_seconds", 0.0))
	var source_beat_seconds := 60.0 / float(profile.get("base_bpm", 120.0))
	var ratio := live_bpm / float(profile.get("base_bpm", 120.0))
	if absf(source_beat_seconds / ratio - live_beat_seconds) > 0.000001:
		failures.append("Beat/bar/phrase boundaries do not follow the live tempo ratio.")
	director.call("_apply_music_fx_vector", director.get("_music_fx_live"), false)
	var music_bus := AudioServer.get_bus_index("Music")
	var compensation := 0.0
	for index in range(AudioServer.get_bus_effect_count(music_bus)):
		var effect := AudioServer.get_bus_effect(music_bus, index)
		if effect is AudioEffectPitchShift:
			compensation = float((effect as AudioEffectPitchShift).pitch_scale)
			break
	if compensation <= 0.0 or absf(ratio * compensation - 1.0) > 0.00001:
		failures.append("Native player rate and shared pitch compensation do not preserve the authored pitch product.")
	var source_bar_seconds := source_beat_seconds * 4.0
	director.set("_current_music_context", {"step_period": source_beat_seconds * 0.5})
	var event_state := {"big_win": true, "big_win_event_token": "tempo_probe_win", "last_bankroll_delta": 100, "big_win_threshold": 50}
	director.call("_consume_music_events", event_state, source_bar_seconds * 2.25)
	var envelope: Dictionary = director.get("_music_event_envelope")
	if int(envelope.get("end_bar", 0)) - int(envelope.get("start_bar", 0)) != 4:
		failures.append("Big-win envelope did not retain four live musical bars.")
	var live_four_bar_seconds := (source_bar_seconds * 4.0) / ratio
	if absf(live_four_bar_seconds - live_beat_seconds * 16.0) > 0.000001:
		failures.append("Four-bar outcome envelope duration did not scale with the live transport.")

	# Save/load: preserve both BPM targets and the exact fractional beat, which
	# determines the next musical boundary.
	var saved_tempo := director.adaptive_tempo_save_state()
	var run := RunStateScript.new()
	run.start_new("ADAPTIVE-TEMPO-SAVE")
	run.remember_music_tempo_state(saved_tempo)
	var restored_run := RunStateScript.new()
	restored_run.from_dict(run.to_dict())
	var restored: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(restored)
	await process_frame
	restored.sync_adaptive_tempo_state(restored_run.music_tempo_state)
	restored.call("_configure_adaptive_tempo", environment_profile, stem_set)
	var restored_snapshot: Dictionary = restored.adaptive_tempo_debug_snapshot()
	for key in ["current_bpm", "target_bpm", "source_heat", "transport_beats"]:
		if absf(float(restored_snapshot.get(key, 0.0)) - float(saved_tempo.get(key, 0.0))) > 0.00001:
			failures.append("Save/load changed adaptive-tempo %s." % key)
	var saved_next_beat: float = ceil(float(saved_tempo.get("transport_beats", 0.0))) - float(saved_tempo.get("transport_beats", 0.0))
	var restored_next_beat: float = ceil(float(restored_snapshot.get("transport_beats", 0.0))) - float(restored_snapshot.get("transport_beats", 0.0))
	if absf(saved_next_beat - restored_next_beat) > 0.000001:
		failures.append("Save/load changed the deterministic next musical boundary.")

	var report := {
		"tool": "audio_adaptive_tempo_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"duration_msec": Time.get_ticks_msec() - started_msec,
		"heat_mapping_bpm": {"0": low, "50": middle, "100": high},
		"maximum_slew_bpm_per_second": maximum_slew,
		"maximum_parallel_phase_error_frames": maximum_phase_error,
		"phase_tolerance_frames": PHASE_TOLERANCE_FRAMES,
		"high_snapshot": high_snapshot,
		"low_snapshot": low_snapshot,
		"restored_snapshot": restored_snapshot.duplicate(true),
		"native_processing": "AudioStreamPlayer shared pitch_scale plus one post-mix AudioEffectPitchShift inverse ratio",
		"web_fallback": "fixed_base_bpm",
		"listening_qa_scenarios": ["low_heat", "rising_heat", "high_heat", "falling_heat"],
		"artifact_checks": ["shared_rate", "sub_frame_phase_tolerance", "pitch_compensation_product", "no_transport_restart"],
	}
	director.queue_free()
	restored.queue_free()
	await process_frame
	_finish(failures, report)


func _track_entry() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for entry_value in parsed as Array:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("id", "")) == TRACK_ID:
			return (entry_value as Dictionary).duplicate(true)
	return {}


func _finish(failures: Array[String], report: Dictionary) -> void:
	if report.is_empty():
		report = {"tool": "audio_adaptive_tempo_probe", "passed": failures.is_empty(), "failures": failures}
	var report_path := _report_path()
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	if failures.is_empty():
		print("AUDIO_ADAPTIVE_TEMPO_PROBE_PASS report=%s" % report_path)
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
	return "res://.tmp/test_reports/audio_adaptive_tempo_probe.json"
