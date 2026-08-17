extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioBacklogContractScript := preload("res://scripts/tests/foundation/scenario_backlog_contract.gd")

var output_path := "res://.tmp/env06_5/scenario_backlog_audit.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var failures: Array = library.validation_errors.duplicate(true)
	ScenarioBacklogContractScript.check(library, failures)
	var selection_counts := _selection_counts(library)
	var starved: Array = []
	for archetype_id_value in library.environment_scenarios.keys():
		for definition_value in library.scenarios_for_archetype(str(archetype_id_value)):
			if typeof(definition_value) == TYPE_DICTIONARY:
				var scenario_id := str((definition_value as Dictionary).get("id", ""))
				if int(selection_counts.get(scenario_id, 0)) <= 0:
					starved.append(scenario_id)
	var scenario_rows: Array = []
	var per_venue_totals: Dictionary = {}
	for archetype_id_value in library.environment_scenarios.keys():
		var archetype_id := str(archetype_id_value)
		per_venue_totals[archetype_id] = library.scenarios_for_archetype(archetype_id).size()
	for ids_value in ScenarioBacklogContractScript.BACKLOG_BY_ARCHETYPE.values():
		for scenario_id_value in ids_value as Array:
			var scenario_id := str(scenario_id_value)
			var definition := library.scenario(scenario_id)
			var mutations := _dict(definition.get("mutations", {}))
			var phase_ids: Array = []
			for phase_value in _array(definition.get("phases", [])):
				if typeof(phase_value) == TYPE_DICTIONARY:
					phase_ids.append(str((phase_value as Dictionary).get("id", "")))
			scenario_rows.append({
				"id": scenario_id,
				"archetype_id": str(definition.get("archetype_id", "")),
				"layer_id": str(definition.get("layer_id", "")),
				"mutation_axes": _mutation_axes(mutations),
				"exclusive_event_ids": _strings(mutations.get("event_pool_add", [])),
				"phase_ids": phase_ids,
				"town_weight_tags": _strings(definition.get("town_weight_tags", [])),
				"selection_hits": int(selection_counts.get(scenario_id, 0)),
			})
	var tutorial_config := library.challenge_config_for("tutorial_first_card", "BACKLOG-AUDIT-TUTORIAL")
	var tutorial_run := RunStateScript.new()
	tutorial_run.start_new("BACKLOG-AUDIT-TUTORIAL", tutorial_config)
	var tutorial_scenario: Dictionary = RunGeneratorScript.new(library).call("_select_scenario", tutorial_run, "corner_store", tutorial_run.create_rng("tutorial"))
	var report := {
		"passed": failures.is_empty() and starved.is_empty(),
		"failures": failures,
		"seed_count": ScenarioBacklogContractScript.SEED_COUNT,
		"catalog_total": _catalog_total(library),
		"launch_cut_total": _catalog_total(library) - scenario_rows.size(),
		"backlog_total": scenario_rows.size(),
		"backlog_exclusive_event_total": _backlog_event_total(scenario_rows),
		"full_catalog_reached": starved.is_empty(),
		"legacy_launch_seed_sweeps_preserved": not _has_failure_prefix(failures, "Expanded catalog crowded launch scenario"),
		"per_venue_totals": per_venue_totals,
		"selection_counts": selection_counts,
		"starved_scenario_ids": starved,
		"tutorial_neutral_scenario": {
			"id": str(tutorial_scenario.get("id", "")),
			"mutations_suppressed": _dict(tutorial_scenario.get("mutations", {})).is_empty(),
			"phases_suppressed": _array(tutorial_scenario.get("phases", [])).is_empty(),
		},
		"scenarios": scenario_rows,
	}
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write scenario backlog audit: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SCENARIO_BACKLOG_AUDIT %s catalog=%d backlog=%d starved=%d report=%s" % ["PASS" if bool(report.get("passed", false)) else "FAIL", int(report.get("catalog_total", 0)), scenario_rows.size(), starved.size(), absolute_path])
	for failure_value in failures:
		push_error(str(failure_value))
	quit(0 if bool(report.get("passed", false)) else 1)


func _selection_counts(library: ContentLibrary) -> Dictionary:
	var result: Dictionary = {}
	for seed_index in range(ScenarioBacklogContractScript.SEED_COUNT):
		var run_state := RunStateScript.new()
		run_state.start_new("BACKLOG-REACH-%02d" % seed_index)
		var generator := RunGeneratorScript.new(library)
		for archetype_id_value in library.environment_scenarios.keys():
			var archetype_id := str(archetype_id_value)
			var selected: Dictionary = generator.call("_select_scenario", run_state, archetype_id, run_state.create_rng("backlog_reach:%s" % archetype_id))
			var scenario_id := str(selected.get("id", ""))
			if not scenario_id.is_empty():
				result[scenario_id] = int(result.get(scenario_id, 0)) + 1
	return result


func _catalog_total(library: ContentLibrary) -> int:
	var total := 0
	for archetype_id_value in library.environment_scenarios.keys():
		total += library.scenarios_for_archetype(str(archetype_id_value)).size()
	return total


func _backlog_event_total(rows: Array) -> int:
	var total := 0
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY:
			total += _array((row_value as Dictionary).get("exclusive_event_ids", [])).size()
	return total


func _has_failure_prefix(failures: Array, prefix: String) -> bool:
	for failure_value in failures:
		if str(failure_value).begins_with(prefix):
			return true
	return false


func _mutation_axes(mutations: Dictionary) -> Array:
	var result: Array = []
	if mutations.has("patron_set") or mutations.has("staff_set"):
		result.append("patrons_staff")
	if mutations.has("event_pool_add") or mutations.has("event_pool_remove"):
		result.append("events")
	for axis in ["economic_profile_overrides", "game_modifier_hooks", "service_add", "service_remove", "security_overrides", "presentation", "music_profile_override"]:
		if mutations.has(axis):
			result.append(str(axis))
	return result


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			result.append(str(item))
	return result
