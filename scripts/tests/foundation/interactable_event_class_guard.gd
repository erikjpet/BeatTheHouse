extends RefCounted

# Permanent icon-to-action contract. Generated event_ids are placement promises:
# every interactable event must either work now or be dormant solely because of
# an authored `conditions` gate. Normalization, scope, speaker synthesis, and
# empty-choice failures are never accepted as dormancy reasons.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED_COUNT := 10
const RAW_EVENTS_PATH := "res://data/events/events.json"


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_speaker_authorship_normalization(library, failures)
	_check_generated_environment_sweep(library, failures)
	_check_reintroduced_defect_fixture(library, failures)
	_check_beach_scenario_resolution(library, failures)


static func _check_speaker_authorship_normalization(library: ContentLibrary, failures: Array) -> void:
	var raw_events := _raw_event_definitions()
	if raw_events.is_empty():
		failures.append("Interactable event class guard could not read the authored event catalog.")
		return
	for raw_value in raw_events:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue
		var raw_event := raw_value as Dictionary
		var event_id := str(raw_event.get("id", "")).strip_edges()
		var normalized := library.event(event_id)
		var speaker := _dict(normalized.get("speaker", {}))
		if raw_event.has("speaker"):
			var expected := ContentLibraryScript._normalize_event_speaker(raw_event.get("speaker", {}))
			if JSON.stringify(speaker) != JSON.stringify(expected):
				failures.append("Authored speaker semantics shifted during normalization for %s." % event_id)
		elif bool(speaker.get("environment_actor", true)):
			failures.append("Synthesized speaker for %s incorrectly requires a room actor." % event_id)


static func _check_generated_environment_sweep(library: ContentLibrary, failures: Array) -> void:
	var covered_archetypes := {}
	var covered_layers := {}
	for seed_index in range(SEED_COUNT):
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype := archetype_value as Dictionary
			var archetype_id := str(archetype.get("id", "")).strip_edges()
			covered_archetypes[archetype_id] = true
			var scenarios: Array = [{}]
			# Base event pools are seed-selected, so sweep them at the full seed
			# count. Scenario event_pool_add overlays are deterministic; exhaust
			# every authored overlay once without multiplying identical work.
			if seed_index == 0:
				scenarios.append_array(library.scenarios_for_archetype(archetype_id))
			for scenario_value in scenarios:
				var scenario := _dict(scenario_value)
				var scenario_id := str(scenario.get("id", "baseline"))
				var run_state := RunStateScript.new()
				run_state.start_new("EVENT-GUARD-%02d-%s-%s" % [seed_index, archetype_id, scenario_id])
				var environment := EnvironmentInstanceScript.from_archetype(
					archetype,
					int(archetype.get("tier", 1)),
					run_state.create_rng("generated_environment"),
					library,
					{},
					scenario
				).to_dict()
				run_state.set_environment(environment)
				_check_environment(library, run_state, "%s/%s/seed-%02d" % [archetype_id, scenario_id, seed_index], failures)
				if run_state.is_layered_environment():
					covered_layers["%s:%s" % [archetype_id, str(run_state.current_environment.get("current_layer_id", ""))]] = true
					_enter_and_check_remaining_layers(library, run_state, scenario_id, seed_index, covered_layers, failures)
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype := archetype_value as Dictionary
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if not covered_archetypes.has(archetype_id):
			failures.append("Interactable event class guard skipped archetype %s." % archetype_id)
		for layer_id_value in _dict(archetype.get("layers", {})).keys():
			var layer_key := "%s:%s" % [archetype_id, str(layer_id_value)]
			if not covered_layers.has(layer_key):
				failures.append("Interactable event class guard did not enter generated layer %s." % layer_key)


static func _enter_and_check_remaining_layers(library: ContentLibrary, run_state: RunState, scenario_id: String, seed_index: int, covered_layers: Dictionary, failures: Array) -> void:
	var remaining := _string_array(run_state.current_environment.get("layer_ids", []))
	remaining.erase(str(run_state.current_environment.get("current_layer_id", "")))
	var generator := RunGeneratorScript.new(library)
	while not remaining.is_empty():
		var entered := false
		for transition_value in _array(run_state.current_environment.get("layer_transitions", [])):
			if typeof(transition_value) != TYPE_DICTIONARY:
				continue
			var target_layer_id := str((transition_value as Dictionary).get("target_layer_id", "")).strip_edges()
			if not remaining.has(target_layer_id):
				continue
			run_state.discover_environment_layer(target_layer_id, "class_guard")
			var result := generator.enter_environment_layer(run_state, target_layer_id, false)
			if not bool(result.get("ok", false)):
				failures.append("Interactable event class guard could not enter %s layer %s: %s" % [str(run_state.current_environment.get("archetype_id", "")), target_layer_id, str(result.get("message", "unknown failure"))])
				return
			remaining.erase(target_layer_id)
			entered = true
			var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
			covered_layers["%s:%s" % [archetype_id, target_layer_id]] = true
			_check_environment(library, run_state, "%s/%s/%s/seed-%02d" % [archetype_id, target_layer_id, scenario_id, seed_index], failures)
			break
		if not entered:
			failures.append("Interactable event class guard could not reach generated layers %s from %s." % [JSON.stringify(remaining), str(run_state.current_environment.get("current_layer_id", ""))])
			return


static func _check_environment(library: ContentLibrary, run_state: RunState, label: String, failures: Array) -> void:
	var environment := run_state.current_environment
	for event_id in _string_array(environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			failures.append("Generated environment %s placed unknown event %s." % [label, event_id])
			continue
		if str(definition.get("interaction_mode", "interactable")) != "interactable":
			failures.append("Generated environment %s placed non-interactable event %s as an icon." % [label, event_id])
			continue
		var violation := _event_violation(definition, library, run_state, environment)
		if not violation.is_empty():
			failures.append("Generated environment %s placed dead event icon %s: %s" % [label, event_id, violation])


static func _event_violation(definition: Dictionary, library: ContentLibrary, run_state: RunState, environment: Dictionary) -> String:
	var module := EventModuleScript.new()
	module.setup(definition, library)
	if module.can_trigger(run_state, environment):
		if module.choices(run_state, environment).is_empty():
			return "can_trigger passed but no authored choice is available"
		return ""
	var conditions := _dict(definition.get("conditions", {}))
	if conditions.is_empty():
		return "can_trigger failed without an authored condition"
	# A dormant icon is legitimate only when removing the authored condition is
	# sufficient to make the exact generated event work. This isolates the gate
	# reason and prevents normalization artifacts from being misclassified.
	if not module.can_trigger(run_state, environment, {"conditions_override": {}}):
		return "can_trigger failure is not explained exclusively by its authored condition"
	return ""


static func _check_reintroduced_defect_fixture(library: ContentLibrary, failures: Array) -> void:
	var definition := ContentLibraryScript._normalize_event_definition({
		"id": "synthesized_speaker_fixture",
		"display_name": "Synthesized Speaker Fixture",
		"interaction_mode": "interactable",
		"scopes": ["recovery"],
		"trigger": {"type": "manual"},
		"payload": {"choices": [{"id": "act", "label": "Act", "consequences": {"resolve_event": true}}]},
	})
	var environment := {
		"id": "synthesized_speaker_fixture_environment",
		"archetype_id": "fixture_recovery",
		"kind": "recovery",
		"tier": 2,
		"event_ids": ["synthesized_speaker_fixture"],
		"resolved_event_ids": [],
	}
	var run_state := RunStateScript.new()
	run_state.start_new("SYNTHESIZED-SPEAKER-FIXTURE")
	run_state.set_environment(environment)
	var repaired_violation := _event_violation(definition, library, run_state, run_state.current_environment)
	if not repaired_violation.is_empty():
		failures.append("Repaired synthesized-speaker fixture did not satisfy the icon-to-action guard: %s" % repaired_violation)
	var broken_definition := definition.duplicate(true)
	var broken_speaker := _dict(broken_definition.get("speaker", {}))
	broken_speaker["environment_actor"] = true
	broken_definition["speaker"] = broken_speaker
	var defect_violation := _event_violation(broken_definition, library, run_state, run_state.current_environment)
	if defect_violation.is_empty():
		failures.append("Interactable event class guard did not fail when the synthesized-speaker defect was reintroduced by fixture.")


static func _check_beach_scenario_resolution(library: ContentLibrary, failures: Array) -> void:
	var beach_scenarios := library.scenarios_for_archetype("beach")
	if beach_scenarios.size() != 3:
		failures.append("Beach end-to-end contract expected three authored scenarios, found %d." % beach_scenarios.size())
	for scenario_value in beach_scenarios:
		var scenario := _dict(scenario_value)
		var scenario_id := str(scenario.get("id", ""))
		var event_id := str(_dict(_dict(scenario.get("mutations", {})).get("exclusive_opportunity", {})).get("event_id", ""))
		var definition := library.event(event_id)
		var authored_choices := _array(_dict(definition.get("payload", {})).get("choices", []))
		if event_id.is_empty() or authored_choices.is_empty():
			failures.append("Beach scenario %s does not expose an authored interactable event with choices." % scenario_id)
			continue
		for choice_value in authored_choices:
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice := choice_value as Dictionary
			var choice_id := str(choice.get("id", ""))
			var run_state := RunStateScript.new()
			run_state.start_new("BEACH-RESOLVE-%s-%s" % [scenario_id, choice_id])
			run_state.bankroll = 100
			run_state.suspicion["level"] = 20
			var environment := EnvironmentInstanceScript.from_archetype(
				library.environment_archetype("beach"),
				2,
				run_state.create_rng("beach_scenario"),
				library,
				{},
				scenario
			).to_dict()
			run_state.set_environment(environment)
			if not _string_array(run_state.current_environment.get("event_ids", [])).has(event_id):
				failures.append("Beach scenario %s did not place its event %s in the generated environment." % [scenario_id, event_id])
				continue
			var module := EventModuleScript.new()
			module.setup(definition, library)
			if not module.can_trigger(run_state, run_state.current_environment) or module.choices(run_state, run_state.current_environment).is_empty():
				failures.append("Beach scenario %s did not present authored choices through the production event chain." % scenario_id)
				continue
			var bankroll_before := run_state.bankroll
			var suspicion_before := run_state.suspicion_level()
			var result := module.resolve(run_state, run_state.current_environment, choice_id)
			if not bool(result.get("ok", false)):
				failures.append("Beach event %s choice %s failed to resolve: %s" % [event_id, choice_id, str(result.get("message", ""))])
				continue
			if not _string_array(run_state.current_environment.get("resolved_event_ids", [])).has(event_id):
				failures.append("Beach event %s choice %s did not set its resolved-event flag." % [event_id, choice_id])
			var consequences := _dict(choice.get("consequences", {}))
			if run_state.bankroll != bankroll_before + int(consequences.get("bankroll_delta", 0)):
				failures.append("Beach event %s choice %s did not apply its bankroll consequence." % [event_id, choice_id])
			if run_state.suspicion_level() != clampi(suspicion_before + int(consequences.get("suspicion_delta", 0)), 0, 100):
				failures.append("Beach event %s choice %s did not apply its heat consequence." % [event_id, choice_id])
			for flag_value in _dict(consequences.get("flags", {})).keys():
				var flag_id := str(flag_value)
				if run_state.narrative_flags.get(flag_id, null) != _dict(consequences.get("flags", {})).get(flag_value):
					failures.append("Beach event %s choice %s did not apply flag %s." % [event_id, choice_id, flag_id])


static func _raw_event_definitions() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RAW_EVENTS_PATH))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _array(value):
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
