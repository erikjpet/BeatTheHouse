extends "res://scripts/tests/gala_failure_aftermath_check.gd"

const GalaEngine := preload("res://scripts/core/scenario_engine.gd")

func _initialize() -> void:
	var failures: Array = []
	_library = ContentLibraryScript.new(); _library.load(false)
	var definition: Dictionary = _library.scenario(GALA_ID).duplicate(true)
	_current_host = _production_host(definition, failures)
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GalaEngine.LEGACY_GALA_TERMINAL_PATH))
	var legacy := definition.duplicate(true); legacy["sequence"] = original.sequence; legacy["sequence_authoring"] = original.authoring
	var state := _state_at_phase(legacy, "work_2", "legacy-public-floor", failures)
	var result := _apply(state, legacy, "reopen_public_gala_floor", "legacy-public-floor:accepted")
	var old_terminal := _dict(result.get("state", {}))
	_expect(bool(result.get("ok", false)) and str(old_terminal.get("phase_id", "")) == "terminal_success" and old_terminal.get("resolved_outcomes", []) == ["cover_identity_accepted"], "synthetic old public-floor route has its genuine historical mapping", failures)
	var environment := {"scenario_id": GALA_ID, "scenario_sequence_state": old_terminal}
	var selected := GalaEngine.recorded_terminal_definition(environment, definition)
	_expect(not selected.is_empty() and str(selected.get("sequence", {}).get("sequence_signature", "")) == str(legacy.sequence.sequence_signature), "old public-floor outcome selects exact prior authored content", failures)
	_expect(Schema.validate_definition(selected, OperationRegistry, _dict(_current_host.get("target_inventory", {}))).is_empty(), "selected prior content passes independent production-host target validation", failures)
	var rebuilt := GalaEngine._rebuild_receipted_semantic_mutations(old_terminal, selected, _host_semantics())
	var replayed := _dict(rebuilt.get("state", {}))
	_expect(bool(rebuilt.get("ok", false)), "old public-floor journal passes unchanged strict causal replay", failures)
	for key in ["command_receipts", "command_receipt_records", "branch_resolution_records", "resolved_outcomes", "objective_progress", "last_feedback"]:
		_expect(_wire_canonical(old_terminal.get(key)) == _wire_canonical(replayed.get(key)), "old public-floor replay preserves " + str(key), failures)
	var bad := old_terminal.duplicate(true); bad.command_receipt_records[0]["fingerprint"] = "0".repeat(64)
	_expect(not bool(GalaEngine._rebuild_receipted_semantic_mutations(bad, selected, _host_semantics()).get("ok", true)), "historical public-floor selection cannot accept a forged journal", failures)
	for command in ["reopen_public_gala_floor", "fail_gala_credentials"]:
		var fresh := _state_at_phase(definition, "work_2", "current-" + str(command), failures)
		var completed := _apply(fresh, definition, str(command), "current:" + str(command))
		var current_state := _dict(completed.get("state", {}))
		_expect(bool(completed.get("ok", false)), "new route completes normally: " + str(command), failures)
		_expect(GalaEngine.recorded_terminal_definition({"scenario_id": GALA_ID, "scenario_sequence_state": current_state}, definition).is_empty(), "new route never receives historical content: " + str(command), failures)
	_expect(GalaEngine.recorded_terminal_definition({"scenario_id": "other", "scenario_sequence_state": old_terminal}, definition).is_empty(), "foreign installed scenario cannot select Gala compatibility content", failures)
	_expect(GalaEngine.recorded_terminal_definition({"scenario_id": GALA_ID, "scenario_sequence_state": state}, definition).is_empty(), "active old partial state uses current authored content", failures)
	gala_facts.append({"fidelity": "Synthetic previously authored public-floor branch, production-composed independent target inventory and unchanged causal verifier; no captured reward or player outcome replay", "old_outcome": old_terminal.get("resolved_outcomes"), "legacy_signature": selected.get("sequence", {}).get("sequence_signature")})
	_finish(failures)
