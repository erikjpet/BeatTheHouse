extends Node

# Supported entry point: coin_pusher_export_parity_runner.tscn. A Node script
# launched directly with --script never enters the tree and cannot run _ready().

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const INPUT_PATH := "res://scripts/games/coin_pusher/coin_pusher_export_parity_input.json"
const RESULT_MARKER := "COIN_PUSHER_EXPORT_PARITY_RESULT="
const OPENING_BODY_COUNT := 40
const REPLAY_TICKS := 260


func _ready() -> void:
	call_deferred("_run_parity")


func _run_parity() -> void:
	var input_text := FileAccess.get_file_as_string(INPUT_PATH)
	var input_value: Variant = JSON.parse_string(input_text)
	if typeof(input_value) != TYPE_DICTIONARY:
		_publish({"ok": false, "error": "input_parse_failed"})
		return
	var input: Dictionary = input_value
	if str(input.get("schema", "")) != "coin_pusher_v3_export_parity_input" \
			or int(input.get("version", 0)) != 3 \
			or int(input.get("opening_body_count", -1)) != OPENING_BODY_COUNT \
			or int(input.get("replay_ticks", -1)) != REPLAY_TICKS \
			or typeof(input.get("input_trace", [])) != TYPE_ARRAY:
		_publish({"ok": false, "error": "input_contract_invalid"})
		return
	var library := ContentLibraryScript.new()
	library.load()
	var game_definition := library.game("coin_pusher")
	var machine_value: Variant = game_definition.get("coin_pusher_machine", {})
	if typeof(machine_value) != TYPE_DICTIONARY or (machine_value as Dictionary).is_empty():
		_publish({"ok": false, "error": "authored_machine_definition_missing"})
		return
	var machine_definition := (machine_value as Dictionary).duplicate(true)
	var seed := str(input.get("seed", "PUSHER-V3-CROSS-EXPORT"))
	var snapshot := CoinPusherSolverScript.create_machine(
		_rng("%s:snapshot" % seed), machine_definition, OPENING_BODY_COUNT
	)
	(snapshot.get("bodies", []) as Array).pop_back()
	snapshot["tray_ledger"] = [{"kind": "coin", "value": 3, "item_id": "", "provenance": {}}]
	var initial_digest := CoinPusherSolverScript.canonical_digest(snapshot)
	var initial_digest_json := _canonical_json(initial_digest)
	var start_tick := int(snapshot.get("tick", 0))
	var input_trace: Array = (input.get("input_trace", []) as Array).duplicate(true)
	var input_trace_json := _canonical_json(input_trace)
	var failures: Array[String] = []
	_validate_snapshot(snapshot, machine_definition, failures)
	_validate_input_trace(input_trace, start_tick, failures)

	var first := CoinPusherSolverScript.replay_input_trace(
		snapshot, _rng("%s:replay" % seed), input_trace, REPLAY_TICKS
	)
	var second := CoinPusherSolverScript.replay_input_trace(
		snapshot, _rng("%s:replay" % seed), input_trace, REPLAY_TICKS
	)
	var first_digest := CoinPusherSolverScript.canonical_digest(first)
	var second_digest := CoinPusherSolverScript.canonical_digest(second)
	var first_digest_json := _canonical_json(first_digest)
	var second_digest_json := _canonical_json(second_digest)
	var source_snapshot_unchanged := _canonical_json(CoinPusherSolverScript.canonical_digest(snapshot)) == initial_digest_json
	var repeat_exact := first_digest_json == second_digest_json
	if not source_snapshot_unchanged:
		failures.append("V3 export parity replay mutated its immutable source snapshot.")
	if not repeat_exact:
		failures.append("V3 export parity replay produced different canonical digests for the same tick-stamped input trace.")
	if int(first.get("tick", -1)) != start_tick + REPLAY_TICKS:
		failures.append("V3 export parity replay did not advance exactly %d fixed ticks." % REPLAY_TICKS)
	if int(first_digest.get("accepted_inserts", -1)) != 2:
		failures.append("V3 export parity replay did not apply both ordered drop inputs exactly once.")
	if int(first_digest.get("collected_count", -1)) != 1 or int(first_digest.get("collected_value", -1)) != 3 \
			or not (first_digest.get("tray_ledger", []) as Array).is_empty():
		failures.append("V3 export parity replay did not collect the preloaded nonempty tray exactly once.")
	if int(first_digest.get("motor_target_rate_fp", -1)) != CoinPusherSolverScript.FP:
		failures.append("V3 export parity replay did not apply the skill-stop release.")
	if first_digest_json == initial_digest_json:
		failures.append("V3 export parity replay produced no canonical state change.")

	var report := {
		"ok": failures.is_empty(),
		"schema": "coin_pusher_v3_export_parity",
		"version": 1,
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"distribution_feature": OS.has_feature("distribution_build"),
		"input_artifact_sha256": input_text.sha256_text(),
		"input_trace_sha256": input_trace_json.sha256_text(),
		"machine_definition_sha256": _canonical_json(machine_definition).sha256_text(),
		"initial_digest_sha256": initial_digest_json.sha256_text(),
		"final_digest_sha256": first_digest_json.sha256_text(),
		"repeat_digest_sha256": second_digest_json.sha256_text(),
		"source_snapshot_unchanged": source_snapshot_unchanged,
		"repeat_exact": repeat_exact,
		"solver_schema": str(snapshot.get("schema", "")),
		"solver_version": int(snapshot.get("version", 0)),
		"solver_fixed_hz": int(snapshot.get("fixed_hz", 0)),
		"solver_backend": CoinPusherSolverScript.last_step_backend_for_test(),
		"opening_body_count": int(snapshot.get("opening_body_count", -1)),
		"input_count": input_trace.size(),
		"replay_ticks": REPLAY_TICKS,
		"final_digest": first_digest_json,
		"final_simulation": first_digest,
		"failure_count": failures.size(),
		"failures": failures,
	}
	_publish(report)


func _validate_snapshot(snapshot: Dictionary, machine_definition: Dictionary, failures: Array[String]) -> void:
	if str(snapshot.get("schema", "")) != CoinPusherSolverScript.SCHEMA \
			or int(snapshot.get("version", 0)) != CoinPusherSolverScript.VERSION \
			or int(snapshot.get("fixed_hz", 0)) != 60:
		failures.append("create_machine did not publish the V3 fixed-point 60 Hz snapshot contract.")
	if snapshot.get("machine_definition", {}) != machine_definition:
		failures.append("create_machine did not preserve the exact authored coin_pusher_machine definition.")
	if int(snapshot.get("opening_body_count", -1)) != OPENING_BODY_COUNT \
			or (snapshot.get("bodies", []) as Array).size() != OPENING_BODY_COUNT - 1 \
			or (snapshot.get("tray_ledger", []) as Array).size() != 1:
		failures.append("Export parity fixture did not conserve exactly %d opening bodies across active stock plus its preloaded tray." % OPENING_BODY_COUNT)


func _validate_input_trace(trace: Array, start_tick: int, failures: Array[String]) -> void:
	var previous_tick := start_tick - 1
	var allowed_kinds := ["drop", "carriage", "hole", "skill_stop", "nudge", "collect"]
	for input_value in trace:
		if typeof(input_value) != TYPE_DICTIONARY:
			failures.append("V3 export parity input trace contains a non-dictionary entry.")
			continue
		var input: Dictionary = input_value
		var tick := int(input.get("tick", -1))
		if tick <= previous_tick or tick < start_tick or tick >= start_tick + REPLAY_TICKS:
			failures.append("V3 export parity input trace is not strictly ordered within the replay window at tick %d." % tick)
		if not allowed_kinds.has(str(input.get("kind", ""))):
			failures.append("V3 export parity input trace contains unsupported kind '%s'." % str(input.get("kind", "")))
		previous_tick = tick


func _canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash(seed))
	return rng


func _stable_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value


func _publish(report: Dictionary) -> void:
	var payload := JSON.stringify(report)
	print(RESULT_MARKER + payload)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BTHCoinPusherParity = JSON.parse(%s); document.title = 'BTH_COIN_PUSHER_PARITY_DONE';" % JSON.stringify(payload), true)
	else:
		get_tree().quit(0 if bool(report.get("ok", false)) else 1)
