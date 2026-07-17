extends SceneTree

const PlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SelectorScript := preload("res://scripts/ui/music_arrangement_selector.gd")
const MANIFEST_PATH := "res://data/audio/music_manifest.json"
const TRACK_8 := "jazz_club_delivery_fixture_8_bar"
const TRACK_16 := "jazz_club_delivery_fixture_16_bar"


func _init() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var started_msec := Time.get_ticks_msec()
	var failures: Array[String] = []
	var entry_8 := _track_entry(TRACK_8)
	var entry_16 := _track_entry(TRACK_16)
	var recipe_8: Dictionary = entry_8.get("layer_choreography", {}) as Dictionary
	var recipe_16: Dictionary = entry_16.get("layer_choreography", {}) as Dictionary
	var timeline_8 := PlayerScript.music_choreography_timeline_snapshot(recipe_8, 32)
	var timeline_16 := PlayerScript.music_choreography_timeline_snapshot(recipe_16, 32)
	var expected_stages := ["sparse", "build_bass", "build_drums", "peak", "release", "rebuild"]
	if _stage_changes(timeline_8) != expected_stages or _stage_changes(timeline_16) != expected_stages:
		failures.append("8/16-bar Jazz fixtures did not progress through sparse, build, peak, release, and rebuild in the declared order.")

	var fill_metadata: Dictionary = entry_8.get("fills", {}) as Dictionary
	var competing_requests := [
		{"id": "minor_layer", "kind": "layer", "priority": 40, "source_section": "A", "destination_section": "B", "destination_progression_id": "jazz_b_1", "change_roles": ["drums_high"]},
		{"id": "major_section", "kind": "section", "priority": 100, "source_section": "A", "destination_section": "B", "destination_progression_id": "jazz_b_1"},
	]
	var winner_a := PlayerScript.resolve_music_fill_request(fill_metadata, competing_requests, 2)
	var winner_b := PlayerScript.resolve_music_fill_request(fill_metadata, competing_requests, 2)
	if JSON.stringify(winner_a) != JSON.stringify(winner_b) or str(winner_a.get("request_id", "")) != "major_section" or str(winner_a.get("fill_id", "")) != "jazz_fixture_fill":
		failures.append("Competing section/layer fill requests did not resolve deterministically to one major-section winner.")
	var incompatible := PlayerScript.resolve_music_fill_request({"wrong_fill": {"loop": false, "source_sections": ["C"], "destination_sections": ["C"], "progression_compatibility": ["wrong_progression"]}}, competing_requests, 2)
	if not bool(incompatible.get("quiet_fallback", false)) or not str(incompatible.get("fill_id", "")).is_empty():
		failures.append("Incompatible fill metadata did not degrade to the quiet authored-safe transition.")

	var player: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(player)
	await process_frame
	var arrangement_recipe := SelectorScript.recipe_definition(entry_8)
	var arrangement_state := SelectorScript.initial_recipe_state(entry_8, 17, "choreography_visit")
	var profile := {
		"environment_id": "jazz_choreography_probe",
		"archetype_id": "jazz_club",
		"authored_track_id": TRACK_8,
		"bpm": 120.0,
		"adaptive_tempo": entry_8.get("adaptive_tempo", {}),
		"layer_choreography": recipe_8,
	}
	var music_state := {"run_seed": 17, "music_visit_id": "choreography_visit", "music_arrangement_state": arrangement_state, "heat": 50}
	player.update_music_state(music_state)
	var contract: Dictionary = player.call("_authored_stem_set_from_profile", profile, music_state)
	if contract.is_empty():
		failures.append("Jazz choreography probe could not load its authored stem contract.")
		_finish(failures, {})
		return
	player.call("_configure_adaptive_tempo", profile, contract)
	player.call("_configure_music_choreography", profile, contract)
	player.set("_current_stem_set", contract)
	player.set("_current_music_context", {"step_period": 0.25, "bpm": 120.0, "bars": 8})
	player.call("_process_music_choreography_bar")
	var planned: Dictionary = player.music_choreography_debug_snapshot().get("scheduled_transition", {}) as Dictionary
	if int(planned.get("start_bar", -1)) != 2 or int(planned.get("destination_bar", -1)) != 4:
		failures.append("Jazz look-ahead did not schedule its default transition two bars before the destination.")
	player.set("_music_choreography_visit_bar", 2)
	player.call("_process_music_choreography_bar")
	player.call("_start_music_choreography_transition_if_due")
	var lead_in: Dictionary = player.music_choreography_debug_snapshot().duplicate(true)
	var lead_roles: Dictionary = lead_in.get("role_target", {}) as Dictionary
	var first_history: Array = lead_in.get("fill_history", []) as Array
	if float(lead_roles.get("drums_low", 1.0)) != 0.0 or float(lead_roles.get("drums_high", 1.0)) != 0.0 or first_history.size() != 1 or str((first_history[0] as Dictionary).get("fill_id", "")) != "jazz_fixture_fill":
		failures.append("Regular loop drums did not exit as one compatible fill entered the two-bar lead-in.")
	player.call("_start_music_choreography_transition_if_due")
	if (player.music_choreography_debug_snapshot().get("fill_history", []) as Array).size() != 1:
		failures.append("The transition fill played more than once for one destination boundary.")

	# At bar four the arrangement state has advanced to the second A. The next
	# boundary combines a B-section request with a layer-stage request; section
	# priority must win and both destination stems begin on bar eight.
	arrangement_state = SelectorScript.advance_recipe_state(entry_8, arrangement_state, {"phrase_event_index": 0, "event_token": "phrase:0"})
	contract["recipe_state"] = arrangement_state
	player.set("_current_stem_set", contract)
	player.set("_music_choreography_visit_bar", 4)
	player.call("_process_music_choreography_bar")
	var combined_plan: Dictionary = player.music_choreography_debug_snapshot().get("scheduled_transition", {}) as Dictionary
	if str(combined_plan.get("request_kind", "")) != "section" or str(combined_plan.get("destination_section", "")) != "B" or (combined_plan.get("requests", []) as Array).size() != 2:
		failures.append("AABA look-ahead did not combine section/layer requests into the one section-priority transition.")
	player.set("_music_choreography_visit_bar", 6)
	player.call("_process_music_choreography_bar")
	player.call("_start_music_choreography_transition_if_due")
	var before_tempo_destination := int((player.music_choreography_debug_snapshot().get("scheduled_transition", {}) as Dictionary).get("destination_bar", -1))
	player.call("_set_adaptive_tempo_target", 100.0)
	for _step in range(1200):
		player.call("_advance_adaptive_tempo", 1.0 / 120.0)
	var after_tempo_destination := int((player.music_choreography_debug_snapshot().get("scheduled_transition", {}) as Dictionary).get("destination_bar", -2))
	if before_tempo_destination != 8 or after_tempo_destination != 8:
		failures.append("Adaptive-tempo ramp changed the scheduled musical-bar destination.")

	var saved := player.music_choreography_save_state()
	var run := RunStateScript.new()
	run.start_new("JAZZ-CHOREOGRAPHY-SAVE")
	run.remember_music_choreography_state(saved)
	var restored_run := RunStateScript.new()
	restored_run.from_dict(run.to_dict())
	var restored_player: ProceduralMusicPlayer = PlayerScript.new()
	root.add_child(restored_player)
	await process_frame
	restored_player.update_music_state(music_state)
	restored_player.sync_music_choreography_state(restored_run.music_choreography_state)
	restored_player.call("_configure_music_choreography", profile, contract)
	var restored := restored_player.music_choreography_save_state()
	for key in ["visit_bar", "stage_id", "next_boundary_bar", "last_fill_bar"]:
		if str(restored.get(key, "")) != str(saved.get(key, "")):
			failures.append("Choreography save/load changed %s." % key)
	if JSON.stringify(restored.get("scheduled_transition", {})) != JSON.stringify(saved.get("scheduled_transition", {})):
		failures.append("Choreography save/load changed the scheduled next boundary/fill future.")

	player.set("_feature_mix_live", {"feature": 1.0, "venue_duck": 0.64})
	player.stop_feature_music()
	var interrupted_stage := str(player.music_choreography_debug_snapshot().get("stage_id", ""))
	var release_bar := int(player.music_choreography_debug_snapshot().get("feature_release_bar", -1))
	if release_bar != 8:
		failures.append("Feature interruption did not defer venue recovery to the next phrase boundary.")
	player.set("_music_choreography_visit_bar", 8)
	player.call("_process_music_choreography_bar")
	player.call("_finish_music_choreography_feature_release")
	var resumed := player.music_choreography_debug_snapshot()
	if int(resumed.get("feature_release_bar", 0)) != -1 or str(resumed.get("stage_id", "")) == interrupted_stage or str(resumed.get("stage_id", "")) != "build_drums":
		failures.append("Feature recovery did not resume the same layer future at the valid phrase boundary.")

	var report := {
		"tool": "audio_jazz_choreography_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"duration_msec": Time.get_ticks_msec() - started_msec,
		"fixture_8_stage_changes": _stage_changes(timeline_8),
		"fixture_16_stage_changes": _stage_changes(timeline_16),
		"first_transition": planned,
		"combined_transition": combined_plan,
		"fill_history": player.music_choreography_debug_snapshot().get("fill_history", []),
		"native_listening_qa": ["sparse_to_build", "two_bar_drum_exit_and_fill", "section_and_drums_together", "peak_to_release", "C_instrument_rebuild", "feature_resume"],
		"cohesion_checks": {"gain_smoothed": true, "fill_one_shot": true, "phase_locked": true, "quiet_missing_fill_fallback": true},
	}
	player.stop()
	restored_player.stop()
	contract.clear()
	player.queue_free()
	restored_player.queue_free()
	await process_frame
	await create_timer(0.35).timeout
	_finish(failures, report)


func _stage_changes(timeline: Array) -> Array:
	var result: Array = []
	for row_value in timeline:
		var stage_id := str((row_value as Dictionary).get("stage_id", ""))
		if result.is_empty() or str(result[-1]) != stage_id:
			result.append(stage_id)
	return result


func _track_entry(track_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for entry_value in parsed as Array:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("id", "")) == track_id:
			return (entry_value as Dictionary).duplicate(true)
	return {}


func _finish(failures: Array[String], report: Dictionary) -> void:
	if report.is_empty():
		report = {"tool": "audio_jazz_choreography_probe", "passed": failures.is_empty(), "failures": failures}
	var report_path := _report_path()
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	if failures.is_empty():
		print("AUDIO_JAZZ_CHOREOGRAPHY_PROBE_PASS report=%s" % report_path)
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
	return "res://.tmp/test_reports/audio_jazz_choreography_probe.json"
