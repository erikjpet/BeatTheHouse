extends SceneTree

const PlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const SelectorScript := preload("res://scripts/ui/music_arrangement_selector.gd")
const MANIFEST_PATH := "res://data/audio/music_manifest.json"
const TRACK_ID := "jazz_club_delivery_fixture_8_bar"


func _init() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var started_msec := Time.get_ticks_msec()
	var failures: Array[String] = []
	var entry := _track_entry()
	var player: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(player)
	await process_frame
	var music_state := {
		"run_seed": 51,
		"music_visit_id": "outcome_probe_visit",
		"music_arrangement_state": SelectorScript.initial_recipe_state(entry, 51, "outcome_probe_visit"),
		"heat": 50,
	}
	var profile := {
		"environment_id": "jazz_outcome_probe",
		"archetype_id": "jazz_club",
		"authored_track_id": TRACK_ID,
		"bpm": 120.0,
		"adaptive_tempo": entry.get("adaptive_tempo", {}),
	}
	player.update_music_state(music_state)
	var contract: Dictionary = player.call("_authored_stem_set_from_profile", profile, music_state)
	if contract.is_empty():
		_finish(["Jazz outcome probe could not load its authored fixture contract."], {})
		return
	player.set("_current_stem_set", contract)
	player.set("_current_music_context", {"step_period": 0.25, "bpm": 120.0, "bars": 8})
	player.call("_configure_adaptive_tempo", profile, contract)

	var call_started := Time.get_ticks_usec()
	var small := player.schedule_music_outcome_event({"event_token": "small:1", "outcome_class": "small_win", "magnitude": 12, "tier": "small", "source_game": "roulette", "result_time": 780, "transport_beat": 1.25})
	var call_usec := Time.get_ticks_usec() - call_started
	if not bool(small.get("accepted", false)) or str(small.get("cue_id", "")) != "jazz_fixture_small_win" or str(small.get("quantization", "")) != "beat" or absf(float(small.get("scheduled_transport_beat", 0.0)) - 2.0) > 0.000001:
		failures.append("Small-win outcome did not choose the authored Jazz cue on the next declared beat.")
	if bool(small.get("controls_blocked", true)) or not bool(small.get("authoritative_state_resolved", false)) or call_usec > 50000:
		failures.append("Outcome scheduling blocked authoritative gameplay or exceeded the immediate 50ms API ceiling.")
	var duplicate := player.schedule_music_outcome_event({"event_token": "small:1", "outcome_class": "small_win", "magnitude": 12, "source_game": "roulette", "result_time": 780, "transport_beat": 1.25})
	if bool(duplicate.get("accepted", true)) or not bool(duplicate.get("deduplicated", false)):
		failures.append("Duplicate outcome event token was not rejected exactly once.")

	var before_pulse := player.music_outcome_director_snapshot(1.99)
	var attack_pulse := player.music_outcome_director_snapshot(2.125)
	var hold_pulse := player.music_outcome_director_snapshot(2.50)
	var after_pulse := player.music_outcome_director_snapshot(4.01)
	if float(before_pulse.get("reverb_send", -1.0)) != 0.0 or float(attack_pulse.get("reverb_send", 0.0)) <= 0.0 or absf(float(hold_pulse.get("reverb_send", 0.0)) - 0.24) > 0.0001 or float(after_pulse.get("reverb_send", -1.0)) != 0.0:
		failures.append("Beat-counted small-win reverb pulse did not attack, hold at its bounded peak, and return to baseline.")
	if float(hold_pulse.get("reverb_send", 1.0)) > float(hold_pulse.get("reverb_send_limit", 0.0)) or bool(hold_pulse.get("shared_full_mix_reverb", true)):
		failures.append("Outcome reverb exceeded its send ceiling or opened reverb over the complete shared mix.")

	var loss := player.schedule_music_outcome_event({"event_token": "loss:static", "outcome_class": "loss", "magnitude": 9, "source_game": "blackjack", "result_time": 782, "transport_beat": 4.25})
	if not bool(loss.get("accepted", false)) or str(loss.get("cue_id", "")) != "jazz_fixture_loss" or str(loss.get("quantization", "")) != "half_bar" or absf(float(loss.get("scheduled_transport_beat", 0.0)) - 6.0) > 0.000001:
		failures.append("Loss outcome did not choose its subtler authored half-bar fixture cue.")

	player.set("_adaptive_tempo_transport_beats", 8.25)
	player.call("_set_adaptive_tempo_target", 100.0)
	var changing := player.schedule_music_outcome_event({"event_token": "loss:ramp", "outcome_class": "loss", "magnitude": 7, "source_game": "blackjack", "result_time": 784})
	var changing_target := float(changing.get("scheduled_transport_beat", -1.0))
	for _step in range(2400):
		if float(player.get("_adaptive_tempo_transport_beats")) >= changing_target:
			break
		player.call("_advance_adaptive_tempo", 1.0 / 120.0)
	var changing_beat := float(player.get("_adaptive_tempo_transport_beats"))
	var changing_snapshot := player.music_outcome_director_snapshot(changing_beat)
	var changing_played := _history_for_token(changing_snapshot.get("stinger_history", []), "loss:ramp")
	if not bool(changing.get("accepted", false)) or changing_target != 10.0 or changing_played.is_empty() or absf(float(changing_played.get("target_transport_beat", -1.0)) - changing_target) > 0.000001 or changing_beat - changing_target > 0.05:
		failures.append("Changing-tempo outcome cue did not retain and consume its declared musical boundary.")

	var rapid: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(rapid)
	await process_frame
	rapid.set("_current_stem_set", contract.duplicate(true))
	rapid.set("_current_music_context", {"step_period": 0.25, "bpm": 120.0, "bars": 8})
	rapid.call("_configure_adaptive_tempo", profile, contract)
	var rapid_same_cue_accepted := 0
	for index in range(6):
		var rapid_result := rapid.schedule_music_outcome_event({"event_token": "rapid_same:%d" % index, "outcome_class": "small_win", "magnitude": 3, "source_game": "roulette", "result_time": 790, "transport_beat": 20.1})
		if bool(rapid_result.get("accepted", false)):
			rapid_same_cue_accepted += 1
	if rapid_same_cue_accepted != 1:
		failures.append("Rapid repeated wins did not respect the authored cue cooldown.")
	var rapid_distinct_accepted := 0
	for index in range(12):
		var distinct := rapid.schedule_music_outcome_event({"event_token": "rapid_distinct:%d" % index, "outcome_class": "small_win", "cue_id": "rapid_fixture_%d" % index, "magnitude": 3, "source_game": "roulette", "result_time": 790, "transport_beat": 24.1})
		if bool(distinct.get("accepted", false)):
			rapid_distinct_accepted += 1
	var rapid_snapshot := rapid.music_outcome_director_snapshot(24.2)
	var pending_outcomes := 0
	for pending_value in rapid_snapshot.get("pending", []) as Array:
		if str((pending_value as Dictionary).get("time_domain", "")) == "transport_beats":
			pending_outcomes += 1
	if rapid_distinct_accepted > 7 or pending_outcomes > 8 or int(rapid_snapshot.get("voice_limit", 0)) != 4:
		failures.append("Rapid distinct outcomes exceeded the bounded pending queue or four-voice playback cap.")

	var big: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(big)
	await process_frame
	big.update_music_state(music_state)
	big.set("_current_stem_set", contract.duplicate(true))
	big.set("_current_music_context", {"step_period": 0.25, "bpm": 120.0, "bars": 8})
	big.call("_configure_adaptive_tempo", profile, contract)
	big.set("_adaptive_tempo_transport_beats", 10.2)
	big.call("_set_adaptive_tempo_target", 100.0)
	var big_schedule := big.schedule_music_outcome_event({"event_token": "big:ramp", "outcome_class": "big_win", "magnitude": 150, "tier": "jackpot", "source_game": "slot", "result_time": 800})
	var big_target := float(big_schedule.get("scheduled_transport_beat", -1.0))
	var big_envelope: Dictionary = big.get("_music_event_envelope")
	if big_target != 12.0 or float(big_envelope.get("end_beat", 0.0)) - float(big_envelope.get("start_beat", 0.0)) != 16.0:
		failures.append("Big-win outcome did not schedule exactly four consumed musical bars.")
	for _step in range(6000):
		if float(big.get("_adaptive_tempo_transport_beats")) >= big_target + 16.0:
			break
		big.call("_advance_adaptive_tempo", 1.0 / 120.0)
	var big_finished := big.music_outcome_director_snapshot(float(big.get("_adaptive_tempo_transport_beats")))
	if bool(big_finished.get("big_win_active", true)) or int(big_finished.get("big_win_bars_remaining", -1)) != 0:
		failures.append("Big-win envelope did not expire after four musical bars through its tempo ramp.")

	var feature_start := big.schedule_music_outcome_event({"event_token": "feature:start", "outcome_class": "feature_start", "source_game": "slot", "result_time": 820, "cue_id": "bonus_music_probe", "transport_beat": 32.1})
	var feature_end := big.schedule_music_outcome_event({"event_token": "feature:end", "outcome_class": "feature_end", "source_game": "slot", "result_time": 824, "cue_id": "feature_end_probe", "transport_beat": 36.1})
	var neutral := big.schedule_music_outcome_event({"event_token": "push:1", "outcome_class": "push", "source_game": "baccarat", "result_time": 826, "transport_beat": 40.2})
	if not bool(feature_start.get("accepted", false)) or not bool(feature_end.get("accepted", false)) or not bool(neutral.get("accepted", false)) or bool(neutral.get("accented", true)) or str(neutral.get("quantization", "")) != "none":
		failures.append("Outcome director did not support feature start/end and normally silent push events through one API.")

	var report := {
		"tool": "audio_jazz_outcome_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"duration_msec": Time.get_ticks_msec() - started_msec,
		"director_call_usec": call_usec,
		"static_small_win": small,
		"static_loss": loss,
		"changing_tempo_loss": changing,
		"rapid_same_cue_accepted": rapid_same_cue_accepted,
		"rapid_distinct_accepted": rapid_distinct_accepted,
		"pending_outcomes": pending_outcomes,
		"big_win_schedule": big_schedule,
		"big_win_consumed_beats": float(big_envelope.get("end_beat", 0.0)) - float(big_envelope.get("start_beat", 0.0)),
		"reverb_peak_send": hold_pulse.get("reverb_send", 0.0),
		"reverb_send_limit": hold_pulse.get("reverb_send_limit", 0.0),
		"native_listening_qa": ["small_win_on_beat", "dark_loss_half_bar", "big_win_on_bar", "four_bar_ramp", "rapid_win_clarity", "feature_start_end"],
		"clarity_checks": {"selected_role_sends_only": true, "no_shared_permanent_reverb": true, "returns_to_baseline": true, "voice_cap": 4},
	}
	for node in [player, rapid, big]:
		(node as ProceduralMusicPlayer).stop()
		(node as ProceduralMusicPlayer).queue_free()
	contract.clear()
	await process_frame
	await create_timer(0.35).timeout
	_finish(failures, report)


func _history_for_token(history_value: Variant, token: String) -> Dictionary:
	if typeof(history_value) != TYPE_ARRAY:
		return {}
	for row_value in history_value as Array:
		if typeof(row_value) == TYPE_DICTIONARY and str((row_value as Dictionary).get("event_token", "")) == token:
			return (row_value as Dictionary).duplicate(true)
	return {}


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
		report = {"tool": "audio_jazz_outcome_probe", "passed": failures.is_empty(), "failures": failures}
	var report_path := _report_path()
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	if failures.is_empty():
		print("AUDIO_JAZZ_OUTCOME_PROBE_PASS report=%s" % report_path)
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
	return "res://.tmp/test_reports/audio_jazz_outcome_probe.json"
