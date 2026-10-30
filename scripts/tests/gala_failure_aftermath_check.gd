extends "res://scripts/tests/foundation/env06_7_package_e_contract.gd"

# Synthetic production-owner sequence checks, not captured-save or Web proof.
# Run the maintained canonical package signer first after runtime admission.
const GALA_ID := "grand_casino_gala_night"
var gala_checks := 0
var gala_facts: Array = []


func _initialize() -> void:
	var failures: Array = []
	_library = ContentLibraryScript.new()
	_library.load(false)
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	var entry: Dictionary = {}
	for row in package.get("scenarios", []):
		if str(row.get("scenario_id", "")) == GALA_ID: entry = row
	if entry.is_empty(): _finish(["Gala authored entry missing"]); return
	var definition := {"id": GALA_ID, "archetype_id": "grand_casino", "sequence": entry.sequence, "sequence_package_id": "env06_7_queen_public", "sequence_handler_pack": "queen_public", "sequence_renderer_id": "queen_public", "sequence_authoring": entry.authoring}
	_current_host = _production_host(definition, failures)
	failures.append_array(Schema.validate_definition(definition, OperationRegistry, _dict(_current_host.get("target_inventory", {}))))
	_check_frozen_identity(definition, entry, failures)
	if not failures.is_empty(): _finish(failures); return
	for phase in ["arrival", "work_1", "work_2", "work_3"]:
		var command_id := "fail_gala_credentials" if phase == "work_2" else "fail_" + GALA_ID
		_command_route(definition, phase, command_id, "terminal_failure", "credential_failed", "failure", failures)
		_command_route(definition, phase, "refuse_" + GALA_ID, "terminal_refused", "credential_failed", "ignore", failures)
		var source: String = "gala_interrupt_" + str(phase)
		var state := _state_at_phase(definition, phase, source, failures)
		var interrupted := _fact_route(state, definition, "travel_departed", {"source_id": GALA_ID, "target_id": "world_map", "travel_kind": "ordinary"}, source + ":depart")
		_terminal(definition, interrupted, "terminal_interrupted", "gala_interrupted", "cancel", source, failures)
		if phase != "arrival":
			var pressure := _fact_route(state, definition, "service_result", _valid_payload("service_result"), source + ":service")
			_terminal(definition, pressure, "terminal_failure", "credential_failed", "failure", source + ":pressure", failures)
	_command_route(definition, "work_2", "reopen_public_gala_floor", "terminal_public_floor", "public_floor_reopened", "success", failures)
	_command_route(definition, "work_3", "choose_gala_identity", "terminal_success", "cover_identity_accepted", "success", failures)
	var cover_state := _state_at_phase(definition, "work_2", "gala_cover", failures)
	var cover := _apply(cover_state, definition, "assume_gala_cover_identity", "gala:cover")
	_expect(bool(cover.get("ok", false)) and str(cover.get("state", {}).get("phase_id", "")) == "work_3", "cover choice retains its authored work3 continuation", failures)
	var completed_cover := _apply(_dict(cover.get("state", {})), definition, "choose_gala_identity", "gala:cover:complete")
	_terminal(definition, completed_cover, "terminal_success", "cover_identity_accepted", "success", "gala_cover", failures)
	_finish(failures)


func _command_route(definition: Dictionary, phase: String, command_id: String, terminal_phase: String, aftermath: String, objective: String, failures: Array) -> void:
	var source := "gala_" + phase + "_" + command_id
	var state := _state_at_phase(definition, phase, source, failures)
	var envelope := _command(state, definition, command_id, source + ":command")
	var result := Runtime.apply_command(state, definition, envelope)
	_terminal(definition, result, terminal_phase, aftermath, objective, source, failures)
	var terminal := _dict(result.get("state", {}))
	var replay := Runtime.apply_command(terminal, definition, envelope)
	_expect(bool(replay.get("ok", false)) and bool(replay.get("replayed", false)) and _wire_canonical(replay.get("state", {})) == _wire_canonical(terminal), source + " exact accepted command replay changes no history/aftermath", failures)


func _terminal(definition: Dictionary, result: Dictionary, phase: String, aftermath: String, objective: String, source: String, failures: Array) -> void:
	var state := _dict(result.get("state", {}))
	_expect(bool(result.get("ok", false)) and str(state.get("status", "")) == "aftermath" and str(state.get("phase_id", "")) == phase, source + " exact terminal phase", failures)
	_expect(state.get("resolved_outcomes", []) == [aftermath] and str(state.get("objective_progress", {}).get("main_task", {}).get("outcome", "")) == objective, source + " objective and aftermath agree", failures)
	_expect(str(state.get("last_feedback", "")) == str(definition.sequence.aftermath[aftermath].revisit_feedback), source + " matching authored feedback", failures)
	if aftermath == "credential_failed":
		for object_value in state.get("semantic_state", {}).get("scene_objects", {}).values():
			_expect(str(object_value.get("appearance", "")) != "public_floor_reopened", source + " failure has no successful public-floor scenery", failures)
	_expect(_round_trip(state, definition), source + " official owner normalization retains complete public projection and receipts", failures)
	var revisit := Runtime.apply_reentry(state, definition, source + ":revisit", _host_semantics())
	var revisited := _dict(revisit.get("state", {}))
	_expect(bool(revisit.get("ok", false)) and revisited.get("resolved_outcomes", []) == [aftermath] and revisited.get("command_receipts", []) == state.get("command_receipts", []) and str(revisited.get("last_feedback", "")) == str(state.get("last_feedback", "")), source + " revisit retains aftermath without another accepted command", failures)
	var stale := _apply(state, definition, "claim_coat_token", source + ":stale_task")
	_expect(not bool(stale.get("ok", true)) and _wire_canonical(stale.get("state", {})) == _wire_canonical(state), source + " terminal task cannot restart", failures)
	gala_facts.append({"source": source, "phase": state.get("phase_id"), "aftermath": state.get("resolved_outcomes"), "objective": state.get("objective_progress", {}).get("main_task", {}).get("outcome"), "accepted_commands": state.get("command_receipts", []).size(), "feedback": state.get("last_feedback")})


func _expect(ok: bool, label: String, failures: Array) -> void:
	gala_checks += 1
	if not ok: failures.append(label)


func _finish(failures: Array) -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": gala_checks, "failures": failures, "routes": gala_facts, "fidelity": "Synthetic production-composed sequence owner commands/facts; not captured player-save or visual Web acceptance", "package_sha256": FileAccess.get_sha256(PACKAGE_PATH)}, "  "))
	print("GALA_FAILURE_AFTERMATH checks=", gala_checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
