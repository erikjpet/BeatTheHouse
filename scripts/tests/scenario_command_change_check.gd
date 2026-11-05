extends SceneTree

# BTH061-AUDIT-COMMAND-CHANGE-DETECTOR-008: public result/receipt contract.
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const Contract := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

var failures: Array = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _run() -> void:
	var definition: Dictionary = Contract._runtime_definition()
	var interaction: Dictionary = definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][-1]["interaction"].duplicate(true)
	var actions: Array = interaction.get("available_actions", []).duplicate(true)
	actions.append({"id": "observe", "label": "Observe", "input_action": "confirm", "non_color_state": "ready"})
	interaction["available_actions"] = actions
	definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][-1]["interaction"] = interaction
	definition["sequence"]["sequence_signature"] = Schema.calculated_signature_hash(definition)
	var initial := Runtime.initial_state(definition, "bar_node", "command-change-contract", Contract._fixture_host_semantics(definition))
	var initial_bytes := var_to_bytes(initial)
	var command: Dictionary = Contract._runtime_command(initial, definition, "observe", "bar_node", "arrival", "change:observe", {}, "scenario", "command_console")
	var command_bytes := var_to_bytes(command)
	var result := Runtime.apply_command(initial, definition, command, {"available_funds": 2})
	_expect(bool(result.get("ok", false)), "Fresh observe command must succeed.")
	_expect(bool(result.get("changed", false)), "Accepted fresh command must report its durable receipt change.")
	_expect(not bool(result.get("replayed", true)), "Fresh command must not be replayed.")
	_expect(var_to_bytes(initial) == initial_bytes and var_to_bytes(command) == command_bytes, "Default command application must preserve caller inputs.")
	if not bool(result.get("ok", false)):
		_finish()
		return
	var state: Dictionary = result["state"]
	_expect(state.get("command_receipts", []) == ["change:observe"], "Fresh success must retain exactly its new lifetime receipt.")
	_expect(state.get("phase_id") == initial.get("phase_id") and state.get("local_state") == initial.get("local_state"), "Observe fixture must keep its phase and local-state values.")
	var legacy := state.duplicate(true)
	legacy["command_results"]["change:observe"]["changed"] = false
	var legacy_bytes := var_to_bytes(legacy)
	var replay := Runtime.apply_command(legacy, definition, command, {"available_funds": 0})
	_expect(bool(replay.get("ok", false)) and bool(replay.get("replayed", false)), "Stored command must replay at zero available funds.")
	_expect(replay.has("changed") and not bool(replay["changed"]), "Legacy cached changed=false must remain false on replay.")
	_expect(var_to_bytes(legacy) == legacy_bytes, "Replay must preserve the caller's stored state.")
	var conflict := command.duplicate(true)
	conflict["payload"] = {"different": true}
	var rejected := Runtime.apply_command(legacy, definition, conflict, {"available_funds": 2})
	_expect(not bool(rejected.get("ok", true)), "Conflicting reuse of an accepted receipt must fail closed.")
	_expect(var_to_bytes(legacy) == legacy_bytes, "Conflicting replay must preserve the caller's stored state.")
	var bad_definition := definition.duplicate(true)
	bad_definition["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [Contract._operation_fixture("scene_ops", "set_state", 9999)]
	var expected_rollback := Runtime.normalize_state(initial, bad_definition)
	var rollback_command: Dictionary = Contract._runtime_command(initial, bad_definition, "prepare", "bar_node", "arrival", "change:rollback", {}, "scenario", "command_console")
	var rollback := Runtime.apply_command(initial, bad_definition, rollback_command, {"available_funds": 2})
	_expect(not bool(rollback.get("ok", true)) and int(rollback.get("cost", -1)) == 0, "Post-handler branch failure must retain the zero-cost rollback path.")
	_expect(var_to_bytes(rollback.get("state", {})) == var_to_bytes(expected_rollback), "Rollback must return the complete normalized pre-command state.")
	_expect(var_to_bytes(initial) == initial_bytes, "Rollback must not mutate the caller's input state.")
	_finish()


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var output_path := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output_path.is_empty():
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(report, "  ") + "\n")
			output.close()
	print("SCENARIO_COMMAND_CHANGE_CHECK " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
