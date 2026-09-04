extends Node

# Release-export wrapper for the existing production-core endgame driver.  The
# same scene runs in Windows and Web exports; only diagnostic timings and the
# platform label are excluded from the semantic parity hash.

const EndgameProbeScript := preload("res://tools/endgame_metrics_probe.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")

const MARKER := "INTEG06_1_TERMINAL_SOAK="
const SCHEMA := "beat_the_house.integ06_1_terminal_soak_shard/v1"
const VERSION := 1
const DEFAULT_MAX_ACTIONS := 132
const DEFAULT_SAVE_LOAD_STRIDE := 7
const CASES := [
	{"id": "clean_prepared_01", "scenario_id": "clean_prepared", "seed": "INTEG06-1-CLEAN-PREPARED-001", "crew_ignoring_control": false},
	{"id": "clean_prepared_02", "scenario_id": "clean_prepared", "seed": "INTEG06-1-CLEAN-PREPARED-002", "crew_ignoring_control": false},
	{"id": "clean_tight_01", "scenario_id": "clean_tight", "seed": "INTEG06-1-CLEAN-TIGHT-001", "crew_ignoring_control": false},
	{"id": "clean_tight_02", "scenario_id": "clean_tight", "seed": "INTEG06-1-CLEAN-TIGHT-002", "crew_ignoring_control": false},
	{"id": "cheat_prepared_01", "scenario_id": "cheat_prepared", "seed": "INTEG06-1-CHEAT-PREPARED-001", "crew_ignoring_control": false},
	{"id": "cheat_prepared_02", "scenario_id": "cheat_prepared", "seed": "INTEG06-1-CHEAT-PREPARED-002", "crew_ignoring_control": false},
	{"id": "cheat_tight_01", "scenario_id": "cheat_tight", "seed": "INTEG06-1-CHEAT-TIGHT-001", "crew_ignoring_control": false},
	{"id": "cheat_tight_02", "scenario_id": "cheat_tight", "seed": "INTEG06-1-CHEAT-TIGHT-002", "crew_ignoring_control": false},
	{"id": "crew_ignored_control", "scenario_id": "clean_prepared", "seed": "INTEG06-1-CREW-IGNORED-001", "crew_ignoring_control": true},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _options()
	var shard_index := maxi(0, int(options.get("shard-index", 0)))
	var shard_count := maxi(1, int(options.get("shard-count", 1)))
	var max_actions := maxi(1, int(options.get("max-actions", DEFAULT_MAX_ACTIONS)))
	var save_load_stride := maxi(1, int(options.get("save-load-stride", DEFAULT_SAVE_LOAD_STRIDE)))
	var failures: Array = []
	if shard_index >= shard_count:
		failures.append("Shard index must be below shard count.")
	OS.set_environment("BTH_INTEG06_1_EMBED_ENDGAME", "1")
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", "user://integ06_1_terminal_profile.json")
	var probe: Variant = EndgameProbeScript.new()
	var library: Variant = ContentLibraryScript.new()
	library.load(false)
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	probe.set("library", library)
	probe.set("generator", RunGeneratorScript.new(library))
	probe.set("integration_capture_trace", true)
	probe.set("integration_save_load_stride", save_load_stride)
	probe.set("integration_save_slot_prefix", "integ06_1_terminal_%d" % shard_index)
	probe.call("_build_game_modules")

	var profile: Variant = ProfileInventoryScript.new()
	profile.from_dict({})
	var rows: Array = []
	var semantic_cases: Array = []
	var seed_ids: Array = []
	var started_usec := Time.get_ticks_usec()
	for case_index in range(CASES.size()):
		if case_index % shard_count != shard_index:
			continue
		var case_data: Dictionary = CASES[case_index]
		var scenario := _scenario(str(case_data.get("scenario_id", "")))
		if scenario.is_empty():
			failures.append("Unknown terminal-soak scenario: %s" % str(case_data.get("scenario_id", "")))
			continue
		probe.set("integration_ignore_crew", bool(case_data.get("crew_ignoring_control", false)))
		var case_started_usec := Time.get_ticks_usec()
		var run: Dictionary = probe.call("_simulate_run", case_index, scenario, str(case_data.get("seed", "")), max_actions)
		var elapsed_ms := float(Time.get_ticks_usec() - case_started_usec) / 1000.0
		var terminal := bool(run.get("won", false)) or bool(run.get("lost", false))
		var route := str(run.get("victory_route", "")) if bool(run.get("won", false)) else str(run.get("failure_reason", ""))
		var profile_result: Dictionary = {}
		if terminal:
			profile_result = profile.record_run_result(_profile_snapshot(run, case_index))
		var save_points := _array(run.get("save_load_points", []))
		var save_failures := _array(run.get("save_load_failures", []))
		var row_passed := terminal and save_points.size() >= 3 and save_failures.is_empty() and bool(profile_result.get("ok", false))
		if not terminal:
			failures.append("%s did not reach a terminal state within %d actions." % [str(case_data.get("id", "")), max_actions])
		if save_points.size() < 3:
			failures.append("%s produced fewer than three mid-run save/load points." % str(case_data.get("id", "")))
		for save_failure in save_failures:
			failures.append("%s save/load: %s" % [str(case_data.get("id", "")), str(save_failure)])
		if terminal and not bool(profile_result.get("ok", false)):
			failures.append("%s terminal result was rejected by ProfileInventory." % str(case_data.get("id", "")))
		var semantic_case := {
			"case_id": str(case_data.get("id", "")),
			"scenario_id": str(case_data.get("scenario_id", "")),
			"seed": str(case_data.get("seed", "")),
			"crew_ignoring_control": bool(case_data.get("crew_ignoring_control", false)),
			"trace": _array(run.get("semantic_trace", [])),
			"terminal": {"status": str(run.get("final_status", "")), "won": bool(run.get("won", false)), "lost": bool(run.get("lost", false)), "route": route},
			"save_load_points": save_points,
		}
		semantic_cases.append(semantic_case)
		seed_ids.append(str(case_data.get("seed", "")))
		rows.append({
			"case_id": str(case_data.get("id", "")),
			"seed": str(case_data.get("seed", "")),
			"scenario_id": str(case_data.get("scenario_id", "")),
			"policy": str(run.get("policy", "")),
			"crew_ignoring_control": bool(case_data.get("crew_ignoring_control", false)),
			"actions": int(run.get("actions", 0)),
			"game_actions": int(run.get("game_actions", 0)),
			"travel_count": int(run.get("travel_count", 0)),
			"event_actions": int(run.get("events_resolved", 0)),
			"service_actions": int(run.get("service_uses", 0)),
			"lender_actions": int(run.get("lender_uses", 0)),
			"lender_ids": _array(run.get("lender_ids", [])),
			"visited_archetypes": _array(run.get("visited_archetypes", [])),
			"game_mix": _dict(run.get("game_mix", {})),
			"save_load_count": save_points.size(),
			"save_load_failures": save_failures,
			"elapsed_ms": snapped(elapsed_ms, 0.001),
			"terminal": {"status": str(run.get("final_status", "")), "route": route, "failure_reason": str(run.get("failure_reason", "")), "profile_recorded": bool(profile_result.get("ok", false))},
			"state_bytes": JSON.stringify(run.get("integration_final_state", {})).to_utf8_buffer().size(),
			"semantic_trace_sha256": JSON.stringify(semantic_case).sha256_text(),
			"passed": row_passed,
		})

	var profile_save_error: Error = profile.save()
	var restored_profile: Variant = ProfileInventoryScript.new()
	restored_profile.load()
	var profile_expected := rows.filter(func(row: Dictionary) -> bool: return bool(_dict(row.get("terminal", {})).get("profile_recorded", false))).size()
	var profile_persisted := profile_save_error == OK and restored_profile.loaded_from_disk and restored_profile.run_history.size() == profile_expected
	if not profile_persisted:
		failures.append("ProfileInventory did not persist exactly one history row per terminal soak case.")
	var semantic_payload := {"schema": SCHEMA, "version": VERSION, "cases": semantic_cases}
	var elapsed_total_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var max_state_bytes := 0
	for row_value in rows:
		max_state_bytes = maxi(max_state_bytes, int(_dict(row_value).get("state_bytes", 0)))
	var report := {
		"schema": SCHEMA,
		"version": VERSION,
		"candidate_commit": str(options.get("candidate-commit", "")),
		"candidate_tree": str(options.get("candidate-tree", "")),
		"tool_source_sha256": str(options.get("tool-source-sha256", "")),
		"profile": {"evidence_profile": str(options.get("evidence-profile", "")), "path": str(options.get("profile-path", "")), "sha256": str(options.get("profile-sha256", ""))},
		"shard": {"index": shard_index, "count": shard_count, "seed_ids": seed_ids},
		"platform": OS.get_name(),
		"active_systems": _observed_systems(rows),
		"authored_max_counts": {"documented_seed_cases": CASES.size(), "save_load_stride_actions": save_load_stride, "max_actions_per_case": max_actions},
		"phase_samples": [],
		"phase_samples_status": {"available": false, "reason": "Core-policy terminal evidence; frame trajectory is owned by the paired perf06_1 release measurement."},
		"lifecycle_status": "clean" if failures.is_empty() else "failed",
		"terminal": {"status": "covered" if rows.all(func(row: Dictionary) -> bool: return bool(row.get("passed", false))) else "incomplete", "route": "multiple", "failure_reason": "", "profile_recorded": profile_persisted},
		"semantic_trace_sha256": JSON.stringify(semantic_payload).sha256_text(),
		"save_load_points": rows.reduce(func(total: int, row: Dictionary) -> int: return total + int(row.get("save_load_count", 0)), 0),
		"retained_counters": {"available": true, "measured": ["resources", "objects", "nodes", "orphans", "state_bytes"], "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "state_bytes": max_state_bytes},
		"allocation_copy_counters": {"available": false, "allocations": null, "shallow_copies": null, "deep_copies": null, "bytes": null, "source": "not_instrumented_by_terminal_policy_driver"},
		"elapsed_ms": snapped(elapsed_total_ms, 0.001),
		"rows": rows,
		"profile_history_count": restored_profile.run_history.size(),
		"profile_persisted": profile_persisted,
		"artifacts": [],
		"failures": failures,
		"passed": failures.is_empty() and not rows.is_empty(),
	}
	var out_path := str(options.get("out", "")).strip_edges()
	if not out_path.is_empty():
		_write_report(out_path, report)
	print("%s%s" % [MARKER, JSON.stringify(report)])
	get_tree().quit(0 if bool(report.get("passed", false)) else 1)


func _scenario(scenario_id: String) -> Dictionary:
	for scenario_value in EndgameProbeScript.SCENARIOS:
		if typeof(scenario_value) == TYPE_DICTIONARY and str((scenario_value as Dictionary).get("id", "")) == scenario_id:
			return (scenario_value as Dictionary).duplicate(true)
	return {}


func _profile_snapshot(run: Dictionary, case_index: int) -> Dictionary:
	var won := bool(run.get("won", false))
	var route := str(run.get("victory_route", "")) if won else str(run.get("failure_reason", ""))
	return {
		"seed": str(run.get("seed", "")),
		"route": route,
		"outcome": "victory" if won else "failure",
		"failure_reason": "" if won else str(run.get("failure_reason", "")),
		"final_bankroll": int(run.get("final_bankroll", 0)),
		"day_count": 1,
		"duration_actions": int(run.get("actions", 0)),
		"completed_date": "2026-09-%02d" % (case_index + 1),
		"completed_unix": 1788220800 + case_index,
		"games_played": _dict(run.get("game_mix", {})),
	}


func _observed_systems(rows: Array) -> Array:
	var systems := {"run_state": true, "run_generator": true, "world_map": true, "save_load": true, "profile": true}
	for row_value in rows:
		var row := _dict(row_value)
		if int(row.get("game_actions", 0)) > 0: systems["game"] = true
		if int(row.get("event_actions", 0)) > 0: systems["event"] = true
		if int(row.get("service_actions", 0)) > 0: systems["service"] = true
		if int(row.get("lender_actions", 0)) > 0: systems["lender"] = true
		if not _array(row.get("visited_archetypes", [])).is_empty(): systems["environment"] = true
	var result: Array = systems.keys()
	result.sort()
	return result


func _options() -> Dictionary:
	var result := {}
	for argument_value in OS.get_cmdline_user_args():
		_parse_option(str(argument_value), result)
	if OS.has_feature("web"):
		var query_json: Variant = JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(window.location.search)))")
		var parsed: Variant = JSON.parse_string(str(query_json))
		if typeof(parsed) == TYPE_DICTIONARY:
			for key_value in (parsed as Dictionary).keys():
				result[str(key_value)] = str((parsed as Dictionary).get(key_value, ""))
	return result


func _parse_option(argument: String, result: Dictionary) -> void:
	if not argument.begins_with("--"):
		return
	var clean := argument.trim_prefix("--")
	var separator := clean.find("=")
	result[clean if separator < 0 else clean.substr(0, separator)] = true if separator < 0 else clean.substr(separator + 1)


func _write_report(path: String, report: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
