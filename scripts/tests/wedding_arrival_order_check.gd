extends SceneTree

# Synthetic pinned challenge, generated through production world travel.
# Direct authenticated commands isolate causal ordering; no Host/rendered input,
# normal map discovery/fare, captured player save, or visual Web claim is made.
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const Operations := preload("res://scripts/core/scenario_operation_registry.gd")
const Event := preload("res://scripts/core/event_module.gd")
const SEED := "BTH-SCENARIO-WEDDING-001-ARRIVAL"
const SCENARIO := "delta_queen_wedding_charter"
const EVENT_ID := "scenario_wedding_best_man"
const SLOT := "wedding_arrival_order"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class RejectArrivalRun extends RunState:
	var reject_arrival := false
	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		if reject_arrival:
			for value in current_environment.get("scenario_sequence_state", {}).get("fact_queue", []):
				if str(value.get("fact_type", "")) == "travel_arrived":
					return {"ok": false, "errors": ["Synthetic destination arrival flush rejection."]}
		return super.scenario_flush_facts(boundary_serial)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-") and ProjectSettings.globalize_path("user://").contains("native-private-"), "explicit resolved disposable storage required"):
		_finish(); return
	var expect_old := OS.get_environment("BTH_WEDDING_EXPECT_OLD") == "1"
	facts = {"id": "BTH-SCENARIO-WEDDING-001", "fidelity": "Synthetic pinned challenge; normal clock to19:00, production travel facade with route prevalidated, direct authenticated RunState scenario commands, private SaveService save/load and real EventModule choice. No captured save, Host/rendered input, map fare or Web acceptance.", "seed": SEED, "expect_old": expect_old, "commands": []}
	var library := ContentLibrary.new()
	library.load(false)
	var run := RunState.new()
	run.start_new(SEED, _challenge())
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	generator.next_environment(run)
	if not _check(not run.current_world_node_id().is_empty() and run.current_world_node_id() != "delta_queen", "generated distinct source") or not _open_hours(run):
		_finish(); return
	var before := _protected(run)
	var travel := generator.travel_environment_result(run, "delta_queen", true)
	facts["travel"] = {"ok": travel.get("ok", false), "errors": travel.get("errors", [])}
	if not _check(bool(travel.get("ok", false)), "production facade installs Wedding destination"):
		_finish(); return
	_check(str(run.current_environment.get("scenario_id", "")) == SCENARIO and str(_state(run).get("phase_id", "")) == "arrival", "exact pinned Wedding initial phase")
	_check(_funds(run) == before.funds and run.game_clock_minutes == before.clock, "generator-only arrival adds no fare or clock")
	facts["arrival"] = {"queued": _queued_arrivals(run), "receipts": _arrival_receipts(run)}
	_check(_queued_arrivals(run).size() == (1 if expect_old else 0), "initial arrival queued only in old control")
	_check(_arrival_receipts(run).size() == (0 if expect_old else 1), "fixed arrival consumed once before first command")
	if not expect_old: _check(travel.get("environment", {}) == run.current_environment, "facade returns current post-arrival state")
	if not _check(bool(run.publish_room_presentation().get("ok", false)), "publish authenticated generated room"):
		_finish(); return
	var arrival_copy := run.to_dict()
	if not _command(run, "secure_ceremony_lane", "secure_lane"):
		_finish(); return
	_check(str(_state(run).get("phase_id", "")) == "work_1", "Secure Lane enters work1")
	var protected := _protected(run)
	var journal := _journal(run)
	var saves := SaveService.new()
	if not _check(saves.save_run(run, SLOT) == OK, "SaveService writes work1"):
		facts["save_error"] = saves.last_save_outcome; _finish(); return
	var loaded: RunState = SaveService.new().load_run(SLOT)
	if not _check(loaded != null, "fresh SaveService loads work1"):
		_finish(); return
	run = loaded
	if not _finalize_loaded_room(run, library): _finish(); return
	_check(_protected(run) == protected and _journal(run) == journal, "save/load preserves protected state and causal history")
	if not _command(run, "recover_ring_case", "recover_rings") or not _command(run, "steady_best_man", "steady_best_man"):
		_finish(); return
	_check(str(_state(run).get("phase_id", "")) == "work_3", "Steady Best Man enters work3 before answer")
	var requests := run.scenario_drain_event_requests()
	var delivered: Array = requests.get("requests", [])
	_check(bool(requests.get("ok", false)) and delivered.size() == 1 and str(delivered[0].get("event_id", "")) == EVENT_ID and str(delivered[0].get("resolution_id", "")) == "leave_him_smiling", "one exact best-man event request delivered")
	facts["requests"] = requests.get("requests", [])
	var money := _funds(run)
	var rng := run.rng_state
	var module := Event.new()
	module.setup(library.event(EVENT_ID), library)
	var answer := module.resolve(run, run.current_environment, "leave_him_smiling")
	facts["answer"] = {"ok": answer.get("ok", false), "message": answer.get("message", ""), "phase": _state(run).get("phase_id", ""), "outcomes": _state(run).get("resolved_outcomes", []), "branches": _state(run).get("branch_resolution_records", []).duplicate(true)}
	_check(bool(answer.get("ok", false)), "real EventModule Leave him smiling accepted")
	_check(_funds(run) == money and run.rng_state == rng, "nonrandom free answer preserves wallets and primary RNG")
	if expect_old:
		_check(str(_state(run).get("phase_id", "")) == "terminal_failure" and _state(run).get("resolved_outcomes", []) == ["table_opportunity"] and _pressure_branch(run), "old control reproduces delayed-arrival pressure failure")
	else:
		_check(str(_state(run).get("phase_id", "")) == "work_3" and str(_state(run).get("status", "")) == "active" and not _pressure_branch(run), "answer retains Deliver Rings without stale pressure")
		if _command(run, "deliver_rings", "deliver_rings"):
			_check(str(_state(run).get("phase_id", "")) == "terminal_success" and _state(run).get("resolved_outcomes", []) == ["ceremony_delivered"], "authored ceremony-delivered outcome")
		var complete_journal := _journal(run)
		var complete_protected := _protected(run)
		if _check(saves.save_run(run, SLOT) == OK, "SaveService writes completed ceremony"):
			var cold: RunState = SaveService.new().load_run(SLOT)
			if _check(cold != null, "fresh SaveService loads completed ceremony") and _finalize_loaded_room(cold, library):
				_check(_journal(cold) == complete_journal and _protected(cold) == complete_protected, "completed save/load retains receipts and protected state without replay")
		_negatives(library, arrival_copy)
	facts["final"] = {"phase": _state(run).get("phase_id", ""), "outcomes": _state(run).get("resolved_outcomes", []), "commands": _state(run).get("command_receipts", []).size(), "funds": _funds(run)}
	_finish()

func _challenge() -> Dictionary:
	return RunState.custom_challenge("wedding_arrival_order", SEED, {"scenario_pins": {"delta_queen": SCENARIO}})

func _command(run: RunState, command_id: String, receipt: String) -> bool:
	var state := _state(run)
	var definition := run._scenario_sequence_definition_readonly()
	var semantic := Operations.resolved_semantic_state(state.get("semantic_state", {}))
	var interactions: Dictionary = semantic.get("interactions", {})
	var availability: Dictionary = {}
	for key in interactions: availability[str(key)] = bool(interactions[key].get("enabled", true))
	var before := _protected(run)
	var count: int = state.get("command_receipts", []).size()
	for key in interactions:
		var interaction: Dictionary = interactions[key]
		for value in interaction.get("available_actions", []):
			if str(value.get("id", "")) != command_id: continue
			var owner := str(interaction.get("owner_namespace", ""))
			var stable_id := str(interaction.get("stable_object_id", ""))
			var descriptor := Runtime._command_descriptor(state, definition, owner, stable_id, command_id, {"host_interaction_availability": availability})
			var result := run.scenario_sequence_command(command_id, receipt, {}, owner, stable_id, availability, str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))
			facts.commands.append({"command": command_id, "ok": result.get("ok", false), "errors": result.get("errors", []), "phase": _state(run).get("phase_id", ""), "queued_arrivals": _queued_arrivals(run).size()})
			if not _check(bool(result.get("ok", false)), "authenticated command " + command_id): return false
			_check(_state(run).get("command_receipts", []).size() == count + 1 and _protected(run) == before, "one zero-cost receipt preserves money RNG clock " + command_id)
			return true
	facts["missing_command"] = {"command": command_id, "phase": state.get("phase_id", ""), "interactions": interactions.duplicate(true), "errors": semantic.get("interaction_resolution_errors", [])}
	return _check(false, "missing authenticated command " + command_id)

func _negatives(library: ContentLibrary, arrival_copy: Dictionary) -> void:
	# Copies of this synthetic generated arrival use normal restore/finalization.
	# New travel_arrived injection is explicitly synthetic pressure, not real travel.
	for mode in ["pressure", "fail", "refuse"]:
		var run := RunState.new()
		run.from_dict(arrival_copy)
		if not _finalize_loaded_room(run, library) or not _command(run, "secure_ceremony_lane", "negative_" + mode): return
		var before := _protected(run)
		if mode == "pressure":
			var arrival := run.scenario_publish_travel("travel_arrived", "motel", "delta_queen", "world")
			var flushed := run.scenario_flush_facts()
			_check(bool(arrival.get("ok", false)) and bool(flushed.get("ok", false)) and _pressure_branch(run) and str(_state(run).get("phase_id", "")) == "terminal_failure", "new arrival pressure remains authored")
		else:
			if not _command(run, ("fail_" if mode == "fail" else "refuse_") + SCENARIO, "negative_branch_" + mode): return
			_check(str(_state(run).get("phase_id", "")) == ("terminal_failure" if mode == "fail" else "terminal_refused"), "explicit " + mode + " remains authored")
		_check(_protected(run) == before, "negative branch invents no money RNG clock " + mode)
	var rejected := RejectArrivalRun.new()
	rejected.start_new(SEED, _challenge())
	rejected.begin_act(1)
	var generator := RunGenerator.new(library)
	generator.next_environment(rejected)
	if not _open_hours(rejected): return
	# Give this newly generated synthetic source its ordinary persisted shape.
	# from_dict installs default-zero reputation/local-Heat keys; establish those
	# before comparing rejection rollback, while keeping full equality required.
	rejected.from_dict(rejected.to_dict())
	if not _finalize_loaded_room(rejected, library): return
	rejected.reject_arrival = true
	var before_state := rejected.to_dict().duplicate(true)
	var before := Runtime.content_fingerprint(before_state)
	var result := generator.travel_environment_result(rejected, "delta_queen", true)
	var after_state := rejected.to_dict().duplicate(true)
	_check(not bool(result.get("ok", true)) and result.get("errors", []).has("Synthetic destination arrival flush rejection."), "arrival flush error returns through facade")
	_check(Runtime.content_fingerprint(after_state) == before, "rejected arrival restores complete source run map money RNG clock")
	facts["rejection"] = {"ok": result.get("ok", false), "errors": result.get("errors", []), "diffs": _different_paths(before_state, after_state), "before_fingerprint": before, "after_fingerprint": Runtime.content_fingerprint(after_state)}

func _open_hours(run: RunState) -> bool:
	var amount := 19 * 60 - run.game_minute_of_day()
	if amount < 0: amount += 24 * 60
	return _check(bool(run.advance_game_clock_minutes(amount).get("ok", false)), "normal19:00 clock setup")

func _finalize_loaded_room(run: RunState, library: ContentLibrary) -> bool:
	var result := run.scenario_finalize_installed_environment(library, run.current_environment.get("scenario_layout_context", {}).duplicate(true))
	return _check(bool(result.get("ok", false)) and bool(run.publish_room_presentation().get("ok", false)), "normal loaded-room finalization")

func _state(run: RunState) -> Dictionary: return run.current_environment.get("scenario_sequence_state", {})
func _funds(run: RunState) -> Dictionary: return {"cash": run.bankroll, "chips": run.grand_casino_chips}
func _protected(run: RunState) -> Dictionary: return {"funds": _funds(run), "rng": run.rng_state, "clock": run.game_clock_minutes, "inventory": run.inventory.duplicate(true), "debt": run.debt.duplicate(true)}
func _queued_arrivals(run: RunState) -> Array: return _state(run).get("fact_queue", []).filter(func(value): return str(value.get("fact_type", "")) == "travel_arrived").duplicate(true)
func _arrival_receipts(run: RunState) -> Array: return _state(run).get("fact_receipt_records", []).filter(func(value): return str(value.get("envelope", {}).get("fact_type", "")) == "travel_arrived").duplicate(true)
func _pressure_branch(run: RunState) -> bool:
	for value in _state(run).get("branch_resolution_records", []):
		if str(value.get("branch_id", "")).ends_with("_pressure"): return true
	return false
func _journal(run: RunState) -> Dictionary:
	var result: Dictionary = {}
	for field in ["scenario_id", "phase_id", "status", "resolved_outcomes", "command_receipts", "command_receipt_records", "branch_resolution_records", "fact_queue", "fact_receipt_records"]: result[field] = _state(run).get(field)
	return JSON.parse_string(JSON.stringify(result))
func _different_paths(before: Variant, after: Variant, path: String = "") -> Array:
	var diffs: Array = []
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var keys: Array = before.keys()
		for key in after:
			if not keys.has(key): keys.append(key)
		keys.sort()
		for key in keys:
			var child := path + "." + str(key)
			if not before.has(key) or not after.has(key):
				diffs.append({"path": child, "before_present": before.has(key), "after_present": after.has(key), "before_type": typeof(before.get(key)), "after_type": typeof(after.get(key))})
			else: diffs.append_array(_different_paths(before[key], after[key], child))
			if diffs.size() >= 60: break
	elif typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		if before.size() != after.size(): diffs.append({"path": path + ".size", "before": before.size(), "after": after.size()})
		for index in range(mini(before.size(), after.size())):
			diffs.append_array(_different_paths(before[index], after[index], "%s[%d]" % [path, index]))
			if diffs.size() >= 60: break
	elif before != after or typeof(before) != typeof(after):
		diffs.append({"path": path, "before": before, "after": after, "before_type": typeof(before), "after_type": typeof(after)})
	return diffs.slice(0, 60)
func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok
func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "test_sha256": FileAccess.get_sha256("res://scripts/tests/wedding_arrival_order_check.gd")}, "  "))
			file.close()
	print("WEDDING_ARRIVAL_ORDER checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
