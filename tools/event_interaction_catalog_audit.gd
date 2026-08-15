extends SceneTree

# Reproducible fix06_1 catalog report. It compares current normalization with
# the legacy behavior by restoring environment_actor=true only on speakers that
# were absent from authored JSON, then evaluates can_trigger in declared hosts.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const RAW_EVENTS_PATH := "res://data/events/events.json"
const JSON_REPORT_PATH := "res://.tmp/fix06_1_full_catalog_audit.json"
const MARKDOWN_REPORT_PATH := "res://.tmp/fix06_1_full_catalog_audit.md"


func _init() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var raw_events := _raw_event_definitions()
	var raw_by_id := _index_by_id(raw_events)
	var hosts_by_event := _declared_hosts(library)
	var rows: Array = []
	var failures: Array = []
	var authored_count := 0
	var synthesized_count := 0
	var changed_count := 0
	for definition_value in library.events:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := (definition_value as Dictionary).duplicate(true)
		var event_id := str(definition.get("id", ""))
		var raw := _dict(raw_by_id.get(event_id, {}))
		var speaker_authored := raw.has("speaker")
		if speaker_authored:
			authored_count += 1
		else:
			synthesized_count += 1
		var hosts := _array(hosts_by_event.get(event_id, []))
		if hosts.is_empty():
			var fallback_hosts := {}
			_append_host(fallback_hosts, event_id, _fallback_host(library, definition))
			hosts = _array(fallback_hosts.get(event_id, []))
		var before_definition := definition.duplicate(true)
		if not speaker_authored:
			var legacy_speaker := _dict(before_definition.get("speaker", {}))
			legacy_speaker["environment_actor"] = true
			before_definition["speaker"] = legacy_speaker
		var before_true := 0
		var after_true := 0
		var after_working := 0
		var host_results: Array = []
		for host_value in hosts:
			var host := _dict(host_value)
			var environment := _dict(host.get("environment", {}))
			var run_state := _audit_run_state(event_id, environment)
			var context := _trigger_context(definition, environment)
			var before := _can_trigger(before_definition, library, run_state, environment, context)
			var after := _can_trigger(definition, library, run_state, environment, context)
			var choices_work := after and not _choices(definition, library, run_state, environment).is_empty()
			before_true += 1 if before else 0
			after_true += 1 if after else 0
			after_working += 1 if choices_work else 0
			host_results.append({
				"host": str(host.get("label", "unknown")),
				"kind": str(environment.get("kind", "")),
				"archetype_id": str(environment.get("archetype_id", "")),
				"before_can_trigger": before,
				"after_can_trigger": after,
				"after_has_choices": choices_work,
			})
			if before != after:
				changed_count += 1
				if speaker_authored or before or not after or not choices_work:
					failures.append("Unexpected behavior shift for %s in %s." % [event_id, str(host.get("label", "unknown"))])
		rows.append({
			"event_id": event_id,
			"speaker": "authored" if speaker_authored else "synthesized",
			"interaction_mode": str(definition.get("interaction_mode", "interactable")),
			"host_count": hosts.size(),
			"before_can_trigger": "%d/%d" % [before_true, hosts.size()],
			"after_can_trigger": "%d/%d" % [after_true, hosts.size()],
			"after_working_interactions": "%d/%d" % [after_working, hosts.size()],
			"changed": before_true != after_true,
			"hosts": host_results,
		})
	var report := {
		"tool": "event_interaction_catalog_audit",
		"event_count": rows.size(),
		"authored_speaker_count": authored_count,
		"synthesized_speaker_count": synthesized_count,
		"changed_host_observation_count": changed_count,
		"failure_count": failures.size(),
		"failures": failures,
		"rows": rows,
	}
	_write_text(JSON_REPORT_PATH, JSON.stringify(report, "\t"))
	_write_text(MARKDOWN_REPORT_PATH, _markdown_report(report))
	print("EVENT_INTERACTION_CATALOG_AUDIT events=%d authored=%d synthesized=%d changed_hosts=%d failures=%d" % [rows.size(), authored_count, synthesized_count, changed_count, failures.size()])
	print("JSON report: %s" % ProjectSettings.globalize_path(JSON_REPORT_PATH))
	print("Markdown report: %s" % ProjectSettings.globalize_path(MARKDOWN_REPORT_PATH))
	if failures.is_empty():
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _declared_hosts(library: ContentLibrary) -> Dictionary:
	var result := {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype := archetype_value as Dictionary
		var archetype_id := str(archetype.get("id", ""))
		var baseline := _generate_host(library, archetype, {}, "", "declared:%s" % archetype_id)
		for event_id in _string_array(archetype.get("event_pool", [])):
			_append_host(result, event_id, baseline)
		for layer_id_value in _dict(archetype.get("layers", {})).keys():
			var layer_id := str(layer_id_value)
			var layer := _dict(_dict(archetype.get("layers", {})).get(layer_id_value, {}))
			var layer_host := _generate_host(library, archetype, {}, layer_id, "declared:%s/%s" % [archetype_id, layer_id])
			for event_id in _string_array(layer.get("event_pool", [])):
				_append_host(result, event_id, layer_host)
	for archetype_key_value in library.environment_scenarios.keys():
		for scenario_value in _array(library.environment_scenarios.get(archetype_key_value, [])):
			if typeof(scenario_value) != TYPE_DICTIONARY:
				continue
			var scenario := scenario_value as Dictionary
			var archetype_id := str(scenario.get("archetype_id", archetype_key_value))
			var archetype := library.environment_archetype(archetype_id)
			if archetype.is_empty():
				continue
			var event_id := str(_dict(_dict(scenario.get("mutations", {})).get("exclusive_opportunity", {})).get("event_id", ""))
			if event_id.is_empty():
				continue
			var layer_id := str(scenario.get("layer_id", ""))
			var label := "scenario:%s/%s" % [archetype_id, str(scenario.get("id", ""))]
			_append_host(result, event_id, _generate_host(library, archetype, scenario, layer_id, label))
	return result


func _generate_host(library: ContentLibrary, archetype: Dictionary, scenario: Dictionary, layer_id: String, label: String) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("AUDIT-HOST-%s" % label)
	var rng := run_state.create_rng("environment")
	var environment := EnvironmentInstanceScript.from_archetype_layer(archetype, layer_id, int(archetype.get("tier", 1)), rng, library, {}, scenario).to_dict() if not layer_id.is_empty() else EnvironmentInstanceScript.from_archetype(archetype, int(archetype.get("tier", 1)), rng, library, {}, scenario).to_dict()
	return {"label": label, "environment": environment}


func _fallback_host(library: ContentLibrary, definition: Dictionary) -> Dictionary:
	var conditions := _dict(definition.get("conditions", {}))
	var preferred_archetypes := _string_array(conditions.get("archetype_ids", []))
	var scopes := _string_array(definition.get("scopes", []))
	for pass_index in range(2):
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype := archetype_value as Dictionary
			var archetype_id := str(archetype.get("id", ""))
			if pass_index == 0 and not preferred_archetypes.is_empty() and not preferred_archetypes.has(archetype_id):
				continue
			var kind := str(archetype.get("kind", ""))
			if not scopes.is_empty() and not scopes.has("any") and not scopes.has(kind):
				continue
			return _generate_host(library, archetype, {}, "", "compatible:%s" % archetype_id)
	return {"label": "synthetic:any", "environment": {"id": "audit_any", "archetype_id": "audit_any", "kind": "any", "tier": 3, "event_ids": [], "resolved_event_ids": []}}


func _append_host(result: Dictionary, event_id: String, host: Dictionary) -> void:
	if event_id.is_empty() or host.is_empty():
		return
	var hosts := _array(result.get(event_id, []))
	var label := str(host.get("label", ""))
	for existing_value in hosts:
		if typeof(existing_value) == TYPE_DICTIONARY and str((existing_value as Dictionary).get("label", "")) == label:
			return
	var stored := host.duplicate(true)
	var environment := _dict(stored.get("environment", {}))
	var event_ids := _string_array(environment.get("event_ids", []))
	if not event_ids.has(event_id):
		event_ids.append(event_id)
	environment["event_ids"] = event_ids
	environment["resolved_event_ids"] = []
	stored["environment"] = environment
	hosts.append(stored)
	result[event_id] = hosts


func _audit_run_state(event_id: String, environment: Dictionary) -> RunState:
	var run_state := RunStateScript.new()
	run_state.start_new("AUDIT-EVENT-%s-%s" % [event_id, str(environment.get("archetype_id", ""))])
	run_state.bankroll = 100
	run_state.suspicion["level"] = 0
	run_state.set_environment(environment.duplicate(true))
	return run_state


func _trigger_context(definition: Dictionary, environment: Dictionary) -> Dictionary:
	var trigger := _dict(definition.get("trigger", {}))
	var trigger_type := str(trigger.get("type", "manual"))
	var context: Dictionary = {}
	match trigger_type:
		"timed":
			context["turns"] = int(trigger.get("turns", trigger.get("min_turns", 0)))
		"travel":
			context["trigger"] = "travel"
		"random":
			context["trigger"] = "action"
			context["turns"] = int(trigger.get("turns", trigger.get("min_turns", 0)))
		"heat_threshold":
			context["trigger"] = "heat_threshold"
			context["threshold"] = int(trigger.get("level", 0))
		"table_approach":
			context["trigger"] = "table_approach"
			var games := _string_array(trigger.get("games", []))
			context["game_id"] = str(games[0]) if not games.is_empty() else str(_array(environment.get("game_ids", []))[0]) if not _array(environment.get("game_ids", [])).is_empty() else ""
			context["hands_played"] = int(trigger.get("min_hands", 0))
	var required_context := _dict(_dict(definition.get("conditions", {})).get("requires_context", {}))
	for key_value in required_context.keys():
		context[key_value] = required_context.get(key_value)
	return context


func _can_trigger(definition: Dictionary, library: ContentLibrary, run_state: RunState, environment: Dictionary, context: Dictionary) -> bool:
	var module := EventModuleScript.new()
	module.setup(definition, library)
	return module.can_trigger(run_state, environment, context)


func _choices(definition: Dictionary, library: ContentLibrary, run_state: RunState, environment: Dictionary) -> Array:
	var module := EventModuleScript.new()
	module.setup(definition, library)
	return module.choices(run_state, environment)


func _markdown_report(report: Dictionary) -> String:
	var lines: Array = [
		"# fix06_1 Full Event Catalog Audit",
		"",
		"Catalog: %d events — %d authored speakers, %d synthesized speakers." % [int(report.get("event_count", 0)), int(report.get("authored_speaker_count", 0)), int(report.get("synthesized_speaker_count", 0))],
		"",
		"`before` reintroduces the legacy normalization default only for events with no authored `speaker`. `after` uses the repaired normalization. Counts are `can_trigger=true / declared host observations`; `working` additionally requires non-empty choices.",
		"",
		"| Event | Speaker | Mode | Hosts | Before | After | Working after | Shift |",
		"| --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
	]
	for row_value in _array(report.get("rows", [])):
		var row := _dict(row_value)
		var changed_hosts: Array = []
		for host_value in _array(row.get("hosts", [])):
			if typeof(host_value) != TYPE_DICTIONARY:
				continue
			var host := host_value as Dictionary
			if bool(host.get("before_can_trigger", false)) != bool(host.get("after_can_trigger", false)):
				changed_hosts.append(str(host.get("host", "unknown")))
		var shift := "unchanged" if changed_hosts.is_empty() else "dead icon → working: %s" % ", ".join(changed_hosts)
		lines.append("| `%s` | %s | %s | %d | %s | %s | %s | %s |" % [str(row.get("event_id", "")), str(row.get("speaker", "")), str(row.get("interaction_mode", "")), int(row.get("host_count", 0)), str(row.get("before_can_trigger", "")), str(row.get("after_can_trigger", "")), str(row.get("after_working_interactions", "")), shift])
	lines.append("")
	lines.append("Failures: %d. Changed host observations: %d." % [int(report.get("failure_count", 0)), int(report.get("changed_host_observation_count", 0))])
	return "\n".join(lines) + "\n"


func _write_text(path: String, value: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.close()


func _raw_event_definitions() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RAW_EVENTS_PATH))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


func _index_by_id(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result[str((value as Dictionary).get("id", ""))] = (value as Dictionary).duplicate(true)
	return result


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _array(value):
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
