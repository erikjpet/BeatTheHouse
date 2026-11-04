extends SceneTree

# Synthetic generator-only contract. The caller-owned case explicitly owns
# and restores the generator snapshot; it does not exercise UI fare rollback.
# No player save, Host, real wager or browser profile is used.
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SEED := "BTH-SCENARIO-WEDDING-001-ARRIVAL"
const SCENARIO := "delta_queen_wedding_charter"
const REJECTION := "Synthetic destination arrival flush rejection."
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class RejectArrivalRun extends RunState:
	var reject_arrival := false
	var rejected_arrivals := 0

	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		if reject_arrival:
			for value in current_environment.get("scenario_sequence_state", {}).get("fact_queue", []):
				if str(value.get("fact_type", "")) == "travel_arrived":
					rejected_arrivals += 1
					return {"ok": false, "errors": ["Synthetic destination arrival flush rejection."]}
		return super.scenario_flush_facts(boundary_serial)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit disposable distribution root required"):
		_finish(); return
	if not _check(ProjectSettings.globalize_path("user://").contains("native-private-"), "resolved user storage is disposable"):
		_finish(); return
	facts = {
		"id": "BTH-SCENARIO-WEDDING-001",
		"fidelity": "Synthetic generator-only pinned challenge, normal clock advance to19:00 and prevalidated destination. Direct and explicit caller-owned rollback; no UI fare/route acceptance, captured save, Host or Web claim.",
		"seed": SEED,
	}
	var library := ContentLibrary.new()
	library.load(false)
	_direct_rollback(library)
	_caller_owned_rollback(library)
	_suppressed_sequence(library)
	_finish()

func _fixture(library: ContentLibrary, apply_mutations: bool = true) -> Dictionary:
	var run := RejectArrivalRun.new()
	var modifiers := {"scenario_pins": {"delta_queen": SCENARIO}, "scenario_pins_apply_mutations": apply_mutations}
	run.start_new(SEED, RunState.custom_challenge("travel_arrival_rollback", SEED, modifiers))
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	generator.next_environment(run)
	if not _check(not run.current_environment.is_empty() and run.current_world_node_id() != "delta_queen", "fixture generates an actual source room before destination"):
		return {}
	var minutes := 19 * 60 - run.game_minute_of_day()
	if minutes < 0: minutes += 24 * 60
	if not _check(bool(run.advance_game_clock_minutes(minutes).get("ok", false)), "fixture normally advances to open19:00 hours"):
		return {}
	# Compare the same ordinary save-restoration shape on both sides. Fresh
	# generation can omit neutral defaults that from_dict legitimately adds.
	run.from_dict(run.to_dict())
	var finalized := run.scenario_finalize_installed_environment(library)
	if not _check(bool(finalized.get("ok", false)), "restored fixture finalizes its ordinary installed-room authority"):
		return {}
	if not _check(bool(run.publish_room_presentation().get("ok", false)), "restored fixture publishes its authenticated source room"):
		return {}
	run.reject_arrival = true
	return {"run": run, "generator": generator}

func _direct_rollback(library: ContentLibrary) -> void:
	var fixture := _fixture(library)
	if fixture.is_empty(): return
	var run: RejectArrivalRun = fixture["run"]
	var generator: RunGenerator = fixture["generator"]
	var source_id := run.current_world_node_id()
	var before_state := run.to_dict().duplicate(true)
	var before := Runtime.content_fingerprint(before_state)
	var source_environment := run.current_environment.duplicate(true)
	var result := generator.travel_environment_result(run, "delta_queen", true)
	_check(not bool(result.get("ok", true)) and result.get("errors", []).has(REJECTION), "direct facade exposes arrival-flush rejection")
	_check(run.rejected_arrivals == 1, "direct failure is injected only after a real arrival was queued")
	_check(run.current_world_node_id() == source_id and _fingerprint(run) == before, "direct rejection restores full durable run map room money clock and RNG")
	_check(result.get("environment", {}) == source_environment, "direct rejection returns the restored source environment")
	facts["direct"] = {"ok": result.get("ok"), "errors": result.get("errors"), "source_id": source_id, "restored_id": run.current_world_node_id(), "full_snapshot_equal": _fingerprint(run) == before, "before_fingerprint": before, "after_fingerprint": _fingerprint(run), "rollback_diffs": _deep_diffs(before_state, run.to_dict())}

func _caller_owned_rollback(library: ContentLibrary) -> void:
	var fixture := _fixture(library)
	if fixture.is_empty(): return
	var run: RejectArrivalRun = fixture["run"]
	var generator: RunGenerator = fixture["generator"]
	var source_id := run.current_world_node_id()
	var before_state := run.to_dict().duplicate(true)
	var before := Runtime.content_fingerprint(before_state)
	var rollback := generator._travel_rollback_snapshot(run)
	var result := generator.travel_environment_result_with_caller_rollback(run, "delta_queen", true)
	_check(not bool(result.get("ok", true)) and result.get("errors", []).has(REJECTION), "caller-owned facade exposes arrival-flush rejection")
	_check(run.rejected_arrivals == 1 and run.current_world_node_id() == "delta_queen", "caller-owned rejection leaves installed candidate for its caller to restore")
	_check(_fingerprint(run) != before, "caller-owned facade does not silently restore the caller transaction")
	generator._restore_travel_snapshot(run, rollback)
	_check(run.current_world_node_id() == source_id and _fingerprint(run) == before, "explicit caller rollback restores full durable source snapshot")
	var restored_diffs := _deep_diffs(before_state, run.to_dict())
	# The wrapper must relinquish rollback ownership even when the call rejects.
	var retry := generator.travel_environment_result(run, "delta_queen", true)
	_check(not bool(retry.get("ok", true)) and run.rejected_arrivals == 2 and _fingerprint(run) == before, "a later direct call owns and restores its own rejected transaction")
	facts["caller_owned"] = {"ok": result.get("ok"), "errors": result.get("errors"), "source_id": source_id, "restored_id": run.current_world_node_id(), "full_snapshot_equal": _fingerprint(run) == before, "before_fingerprint": before, "after_retry_fingerprint": _fingerprint(run), "explicit_restore_diffs": restored_diffs, "retry_restore_diffs": _deep_diffs(before_state, run.to_dict()), "scope": "explicit generator snapshot owner; not full UI fare acceptance"}

func _suppressed_sequence(library: ContentLibrary) -> void:
	# Supported challenge suppression retains the authored scenario identity while
	# disabling its dynamic sequence; no sealed state or content is rewritten.
	var fixture := _fixture(library, false)
	if fixture.is_empty(): return
	var run: RejectArrivalRun = fixture["run"]
	var generator: RunGenerator = fixture["generator"]
	var money := {"cash": run.bankroll, "chips": run.grand_casino_chips}
	var clock := run.game_clock_minutes
	var result := generator.travel_environment_result(run, "delta_queen", true)
	_check(bool(result.get("ok", false)) and run.current_world_node_id() == "delta_queen", "supported sequence-suppressed destination remains accepted")
	_check(run.scenario_sequence_is_suppressed(SCENARIO, "delta_queen"), "inactive control uses supported challenge suppression")
	_check(run.rejected_arrivals == 0, "inactive destination does not invent a queued active-sequence arrival")
	var flushed := run.scenario_flush_facts()
	_check(bool(flushed.get("inactive", false)), "suppressed destination reports inactive fact flushing")
	_check(result.get("environment", {}) == run.current_environment, "inactive destination returns its live installed environment")
	_check({"cash": run.bankroll, "chips": run.grand_casino_chips} == money and run.game_clock_minutes == clock, "generator-only inactive arrival adds no fare or clock charge")
	facts["suppressed"] = {"ok": result.get("ok"), "errors": result.get("errors"), "inactive": flushed.get("inactive", false), "destination": run.current_world_node_id()}

func _fingerprint(run: RunState) -> String:
	return Runtime.content_fingerprint(run.to_dict())

func _deep_diffs(before: Variant, after: Variant) -> Array:
	var result: Array = []
	_diff_values(before, after, "run", result)
	return result

func _diff_values(before: Variant, after: Variant, path: String, result: Array) -> void:
	# All input is synthetic. Bound diagnostics while retaining exact scalar
	# types/values, which distinguishes normalization from lost durable state.
	if result.size() >= 100: return
	if typeof(before) != typeof(after):
		result.append({"path": path, "kind": "type", "before_type": type_string(typeof(before)), "after_type": type_string(typeof(after)), "before": _diagnostic_value(before), "after": _diagnostic_value(after)})
		return
	if typeof(before) == TYPE_DICTIONARY:
		var keys: Array = before.keys()
		for key in after:
			if not keys.has(key): keys.append(key)
		keys.sort()
		for key in keys:
			var child_path := path + "." + str(key)
			if not before.has(key) or not after.has(key):
				result.append({"path": child_path, "kind": "missing_key", "before_present": before.has(key), "after_present": after.has(key), "before": _diagnostic_value(before.get(key)), "after": _diagnostic_value(after.get(key))})
			else:
				_diff_values(before[key], after[key], child_path, result)
			if result.size() >= 100: return
	elif typeof(before) == TYPE_ARRAY:
		if before.size() != after.size():
			result.append({"path": path, "kind": "array_size", "before": before.size(), "after": after.size()})
		for index in range(mini(before.size(), after.size())):
			_diff_values(before[index], after[index], "%s[%d]" % [path, index], result)
			if result.size() >= 100: return
	elif before != after:
		result.append({"path": path, "kind": "value", "before": _diagnostic_value(before), "after": _diagnostic_value(after)})

func _diagnostic_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY: return {"dictionary_size": value.size()}
	if typeof(value) == TYPE_ARRAY: return {"array_size": value.size()}
	if typeof(value) == TYPE_STRING and value.length() > 180: return value.substr(0, 180) + "..."
	return value

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "test_sha256": FileAccess.get_sha256("res://scripts/tests/travel_arrival_rollback_check.gd")}, "  "))
			file.close()
	print("TRAVEL_ARRIVAL_ROLLBACK checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
