extends "res://scripts/tests/tutorial_dialogue_trigger_cadence_check.gd"

# Standalone historical tutorial-fixture authority check: 73 hostile controls.
# Preserves the validated diagnostic behavior and explicit --fixture-out CLI.
# Example: godot --headless --path . --script res://scripts/tests/tutorial_fixture_historical_authority_check.gd -- --fixture-out=<absolute-report.json>
# One fixture construction/restore; detached mutations only; no UI flow.
var _guard_probe_started: bool = false
var _guard_probe_failures: Array = []
var _guard_probe_cases: Array = []


func _init() -> void:
	call_deferred("_run_tutorial_fixture_guard_hostile_probe")


func _run() -> void:
	_run_tutorial_fixture_guard_hostile_probe()


func _run_dialogue_trigger_cadence_check() -> void:
	_run_tutorial_fixture_guard_hostile_probe()


func _run_tutorial_fixture_guard_hostile_probe() -> void:
	if _guard_probe_started:
		return
	_guard_probe_started = true
	var output_path: String = ""
	for argument_value: String in OS.get_cmdline_user_args():
		var argument: String = str(argument_value)
		if argument.begins_with("--fixture-out="):
			output_path = argument.trim_prefix("--fixture-out=").replace("\\", "/")
	if output_path.is_empty():
		push_error("Hostile fixture probe requires an explicit --fixture-out path.")
		quit(2)
		return

	# Exactly one baseline construction and one restore. No accepted observed
	# fingerprint is hard-coded: the inherited original pin stays authoritative.
	var baseline: Dictionary = _blackjack_count_fixture_baseline()
	var restored: Dictionary = _restore_blackjack_count_fixture(baseline)
	var data: Dictionary = baseline.get("data", {})
	var original_data_text: String = JSON.stringify(data)
	var baseline_fingerprint: String = str(baseline.get("fingerprint", ""))
	var restored_fingerprint: String = str(restored.get("fingerprint", ""))
	var historical_fingerprint: String = str(baseline.get("historical_fingerprint", ""))
	var independent_full_fingerprint: String = JSON.stringify(_normalize_fixture_private_capsules(data)).sha256_text()
	var independent_historical_fingerprint: String = _blackjack_fixture_historical_fingerprint(data)
	var round_trip_diff: Dictionary = restored.get("round_trip_diff", {})
	var positive_caller_unchanged: bool = JSON.stringify(data) == original_data_text
	_guard_require(not data.is_empty(), "baseline_data_present")
	_guard_require(bool(baseline.get("valid", false)), "original_fixture_valid")
	_guard_require(historical_fingerprint == BLACKJACK_FIXTURE_BASELINE_SHA256, "untouched_original_historical_pin")
	_guard_require(independent_historical_fingerprint == BLACKJACK_FIXTURE_BASELINE_SHA256, "positive_projection_matches_original_pin")
	_guard_require(positive_caller_unchanged, "positive_projection_preserves_caller")
	_guard_require(not baseline_fingerprint.is_empty(), "current_full_fingerprint_present")
	_guard_require(independent_full_fingerprint == baseline_fingerprint, "independent_current_full_fingerprint")
	_guard_require(restored_fingerprint == baseline_fingerprint, "restored_current_full_fingerprint")
	_guard_require(_blackjack_fixture_matches_baseline(restored, baseline), "existing_full_clone_heat_comparison")
	_guard_require(round_trip_diff.is_empty(), "existing_full_round_trip_diff_empty")
	_guard_require(int(baseline.get("heat", -1)) == 0 and int(restored.get("heat", -1)) == 0, "baseline_and_restore_zero_heat")

	var baseline_checks_passed: bool = _guard_probe_failures.is_empty()
	if baseline_checks_passed:
		var descriptors: Array = _guard_hostile_descriptors()
		_guard_require(descriptors.size() == 17, "seventeen_reviewed_differences_declared")
		for descriptor_value: Variant in descriptors:
			var descriptor: Dictionary = descriptor_value
			var case_id: String = str(descriptor.get("id", ""))
			var path: Array = descriptor.get("path", [])
			_guard_run_case(data, case_id + ":wrong_value", "reviewed_difference_wrong_value", path, descriptor.get("wrong_value"), false)
			_guard_run_case(data, case_id + ":missing", "reviewed_difference_missing", path, null, true)
			_guard_run_case(data, case_id + ":wrong_type", "reviewed_difference_wrong_type", path, descriptor.get("wrong_type"), false)

		# Unknown additions must reject, including additions inside whole objects
		# that the compatibility projection would otherwise erase or replace.
		var unknown_paths: Array = [
			["__guard_probe_unknown__"],
			["narrative_flags", "__guard_probe_unknown__"],
			["story_money_archive", "__guard_probe_unknown__"],
			["narrative_flags", "crew_delivery_migration", "__guard_probe_unknown__"],
			["current_environment", "layer_transitions", 1, "__guard_probe_unknown__"],
			["current_environment", "layer_states", "casino", "layer_transitions", 1, "__guard_probe_unknown__"],
		]
		for unknown_index_value: int in range(unknown_paths.size()):
			var unknown_index: int = int(unknown_index_value)
			var unknown_path: Array = unknown_paths[unknown_index]
			_guard_run_case(data, "unknown_addition:%d" % unknown_index, "unknown_addition", unknown_path, true, false, true)

		# Fields outside the reviewed projection retain the original hash gate.
		_guard_run_case(data, "original_pinned_field:bankroll", "original_pinned_field", ["bankroll"], int(data.get("bankroll", 0)) + 1, false)
		_guard_run_case(data, "original_pinned_field:tutorial_reprieve", "original_pinned_field", ["narrative_flags", "tutorial_blackjack_peek_reprieve_used"], false, false)

		# Structural type guards must reject without a Variant-indexing failure.
		var structural_paths: Array = [
			["narrative_flags"],
			["current_environment"],
			["current_environment", "layer_states"],
			["current_environment", "layer_states", "casino"],
			["current_environment", "layer_transitions"],
			["current_environment", "layer_states", "casino", "layer_transitions"],
		]
		for structural_index_value: int in range(structural_paths.size()):
			var structural_index: int = int(structural_index_value)
			var structural_path: Array = structural_paths[structural_index]
			_guard_run_case(data, "structure:%d:missing" % structural_index, "structural_missing", structural_path, null, true)
			_guard_run_case(data, "structure:%d:wrong_type" % structural_index, "structural_wrong_type", structural_path, "wrong-type", false)

		var environment: Dictionary = data.get("current_environment", {})
		var layer_states: Dictionary = environment.get("layer_states", {})
		var casino: Dictionary = layer_states.get("casino", {})
		var extra_current_transitions: Array = (environment.get("layer_transitions", []) as Array).duplicate(true)
		var extra_casino_transitions: Array = (casino.get("layer_transitions", []) as Array).duplicate(true)
		extra_current_transitions.append({"__guard_probe_unknown__": true})
		extra_casino_transitions.append({"__guard_probe_unknown__": true})
		_guard_run_case(data, "transition_count:current_environment", "unexpected_transition_count", ["current_environment", "layer_transitions"], extra_current_transitions, false)
		_guard_run_case(data, "transition_count:casino", "unexpected_transition_count", ["current_environment", "layer_states", "casino", "layer_transitions"], extra_casino_transitions, false)
		_guard_require(_guard_probe_cases.size() == 73, "all_seventy_three_hostile_cases_executed")

	var baseline_data_unchanged: bool = JSON.stringify(data) == original_data_text
	_guard_require(baseline_data_unchanged, "all_hostile_cases_preserve_baseline_data")
	var report: Dictionary = {
		"task_id": "BTH061-AUDIT-TUTORIAL-FIXTURE-001",
		"probe": "guarded_historical_projection_hostile_controls",
		"project_root": ProjectSettings.globalize_path("res://"),
		"engine_version": Engine.get_version_info(),
		"ui_instantiated": false,
		"baseline_constructions": 1,
		"baseline_restores": 1,
		"untouched_expected_historical_fingerprint": BLACKJACK_FIXTURE_BASELINE_SHA256,
		"historical_fingerprint": historical_fingerprint,
		"independent_historical_fingerprint": independent_historical_fingerprint,
		"current_full_fingerprint": baseline_fingerprint,
		"independent_current_full_fingerprint": independent_full_fingerprint,
		"restored_current_full_fingerprint": restored_fingerprint,
		"original_fixture_valid": bool(baseline.get("valid", false)),
		"heat": int(baseline.get("heat", -1)),
		"restored_heat": int(restored.get("heat", -1)),
		"round_trip_diff": round_trip_diff,
		"positive_caller_unchanged": positive_caller_unchanged,
		"baseline_data_unchanged_after_hostile_cases": baseline_data_unchanged,
		"baseline_checks_passed": baseline_checks_passed,
		"reviewed_difference_count": 17,
		"case_count": _guard_probe_cases.size(),
		"cases": _guard_probe_cases,
		"failures": _guard_probe_failures,
		"passed": _guard_probe_failures.is_empty(),
	}
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Hostile fixture probe could not open its explicit report path.")
		quit(2)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("TUTORIAL_FIXTURE_GUARD_HOSTILE_PROBE ", JSON.stringify({
		"passed": _guard_probe_failures.is_empty(),
		"case_count": _guard_probe_cases.size(),
		"failure_count": _guard_probe_failures.size(),
		"report": output_path,
	}))
	quit(0 if _guard_probe_failures.is_empty() else 1)


func _guard_require(condition: bool, label: String) -> void:
	if not condition:
		_guard_probe_failures.append(label)


func _guard_run_case(data: Dictionary, case_id: String, category: String, path: Array, wrong_value: Variant, erase_leaf: bool, allow_new_leaf: bool = false) -> void:
	var clone: Dictionary = data.duplicate(true)
	var injected: bool = _guard_mutate_path(clone, path, wrong_value, erase_leaf, allow_new_leaf)
	var caller_before: String = JSON.stringify(clone)
	var actual: String = _blackjack_fixture_historical_fingerprint(clone)
	var caller_unchanged: bool = JSON.stringify(clone) == caller_before
	var rejected: bool = actual != BLACKJACK_FIXTURE_BASELINE_SHA256
	var passed: bool = injected and rejected and caller_unchanged
	_guard_probe_cases.append({
		"id": case_id,
		"category": category,
		"path": path.duplicate(true),
		"mutation_injected": injected,
		"historical_fingerprint": actual,
		"rejected": rejected,
		"caller_unchanged": caller_unchanged,
		"passed": passed,
	})
	_guard_require(passed, case_id)


func _guard_mutate_path(data: Dictionary, path: Array, wrong_value: Variant, erase_leaf: bool, allow_new_leaf: bool) -> bool:
	if path.is_empty():
		return false
	var cursor: Variant = data
	for depth_value: int in range(path.size() - 1):
		var depth: int = int(depth_value)
		var key: Variant = path[depth]
		if typeof(cursor) == TYPE_DICTIONARY:
			var dictionary: Dictionary = cursor
			if not dictionary.has(key):
				return false
			cursor = dictionary[key]
		elif typeof(cursor) == TYPE_ARRAY and typeof(key) == TYPE_INT:
			var array: Array = cursor
			var index: int = int(key)
			if index < 0 or index >= array.size():
				return false
			cursor = array[index]
		else:
			return false
	var leaf: Variant = path[path.size() - 1]
	if typeof(cursor) != TYPE_DICTIONARY:
		return false
	var parent: Dictionary = cursor
	if not parent.has(leaf) and not allow_new_leaf:
		return false
	if erase_leaf:
		return parent.erase(leaf)
	if typeof(wrong_value) == TYPE_DICTIONARY:
		parent[leaf] = (wrong_value as Dictionary).duplicate(true)
	elif typeof(wrong_value) == TYPE_ARRAY:
		parent[leaf] = (wrong_value as Array).duplicate(true)
	else:
		parent[leaf] = wrong_value
	return true


func _guard_hostile_descriptors() -> Array:
	return [
		{"id": "save:story_money_archive", "path": ["story_money_archive"], "wrong_value": {"archived_entry_count": 0, "known_entry_count": 1, "schema": "bth.story_money_archive/v1", "sources": {}}, "wrong_type": "wrong-type"},
		{"id": "save:surface_clock_checkpoint_msec", "path": ["surface_clock_checkpoint_msec"], "wrong_value": -2, "wrong_type": "wrong-type"},
		{"id": "crew:borrow_count", "path": ["narrative_flags", "crew_delivery_borrow_count"], "wrong_value": 1, "wrong_type": "wrong-type"},
		{"id": "crew:loan_locations", "path": ["narrative_flags", "crew_delivery_loan_locations"], "wrong_value": ["guard-probe-location"], "wrong_type": "wrong-type"},
		{"id": "crew:migration", "path": ["narrative_flags", "crew_delivery_migration"], "wrong_value": {"historical_count_scope": "Open markers only; cleared borrowing history is not reconstructed.", "outstanding_deliveries": 1, "recorded_open_borrows": 0, "unknown_historical_borrow_count": false, "unknown_prior_completion_credit": false}, "wrong_type": "wrong-type"},
		{"id": "crew:obligations", "path": ["narrative_flags", "crew_delivery_obligations"], "wrong_value": 1, "wrong_type": "wrong-type"},
		{"id": "crew:post_miss", "path": ["narrative_flags", "crew_delivery_post_miss"], "wrong_value": true, "wrong_type": "wrong-type"},
		{"id": "crew:rules_version", "path": ["narrative_flags", "crew_delivery_rules_version"], "wrong_value": 2, "wrong_type": "wrong-type"},
		{"id": "crew:favor_pending", "path": ["narrative_flags", "crew_favor_pending"], "wrong_value": true, "wrong_type": "wrong-type"},
		{"id": "crew:marker_converted_to_cash", "path": ["narrative_flags", "crew_marker_converted_to_cash"], "wrong_value": true, "wrong_type": "wrong-type"},
		{"id": "crew:reputation", "path": ["narrative_flags", "crew_reputation"], "wrong_value": 1, "wrong_type": "wrong-type"},
		{"id": "door:current:min_crew_rank", "path": ["current_environment", "layer_transitions", 1, "access_paths", 0, "min_crew_rank"], "wrong_value": "associate", "wrong_type": 0},
		{"id": "door:current:requires_current_access", "path": ["current_environment", "layer_transitions", 1, "requires_current_access"], "wrong_value": false, "wrong_type": "wrong-type"},
		{"id": "door:current:locked_reason", "path": ["current_environment", "layer_transitions", 1, "locked_reason"], "wrong_value": "Rook keeps this door for associates.", "wrong_type": 0},
		{"id": "door:casino:min_crew_rank", "path": ["current_environment", "layer_states", "casino", "layer_transitions", 1, "access_paths", 0, "min_crew_rank"], "wrong_value": "associate", "wrong_type": 0},
		{"id": "door:casino:requires_current_access", "path": ["current_environment", "layer_states", "casino", "layer_transitions", 1, "requires_current_access"], "wrong_value": false, "wrong_type": "wrong-type"},
		{"id": "door:casino:locked_reason", "path": ["current_environment", "layer_states", "casino", "layer_transitions", 1, "locked_reason"], "wrong_value": "Rook keeps this door for associates.", "wrong_type": 0},
	]
