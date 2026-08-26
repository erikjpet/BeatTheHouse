extends SceneTree

const CoinPusherGame := preload("res://scripts/games/coin_pusher.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")

const RESULT_MARKER := "COIN_PUSHER_V3_SMOKE_RESULT="
const MACHINES := ["quarter_falls", "jackpot_ridge", "vault_drop"]
const OPENING_BODY_COUNT := 40
const REPLAY_TICKS := 720


func _initialize() -> void:
	var report := _run_smoke()
	print(RESULT_MARKER + JSON.stringify(report))
	print("NATIVE_COIN_PUSHER_SMOKE %s (production input-trace parity; backend=%s)" % ["PASS" if bool(report.get("ok", false)) else "FAIL", str(report.get("solver_backend", ""))])
	for failure_value in report.get("failures", []):
		push_error(str(failure_value))
	quit(0 if bool(report.get("ok", false)) else 1)


static func _run_smoke() -> Dictionary:
	var failures: Array[String] = []
	var library = ContentLibraryScript.new()
	library.load(false)
	var game = CoinPusherGame.new()
	game.setup(library.game("coin_pusher"), library)
	var machine_reports: Array = []
	for machine_id in MACHINES:
		var definition: Dictionary = game.call("_machine_definition", machine_id)
		if definition.is_empty():
			failures.append("Missing production definition for %s." % machine_id)
			continue
		machine_reports.append(_run_machine(machine_id, definition, failures))
	var total_peg_hits := 0
	var total_peg_misses := 0
	for machine_report_value in machine_reports:
		var machine_report: Dictionary = machine_report_value
		total_peg_hits += int(machine_report.get("peg_hit_body_count", 0))
		total_peg_misses += int(machine_report.get("peg_miss_body_count", 0))
	if total_peg_hits < 1 or total_peg_misses < 1:
		failures.append("Production traces must jointly prove real inserted-body peg hit and miss paths (hit=%d miss=%d)." % [total_peg_hits, total_peg_misses])
	var native_available := Solver.native_backend_available_for_test()
	var backend := Solver.last_step_backend_for_test()
	if OS.get_name() == "Windows" and (not native_available or backend != "native_v3"):
		failures.append("Windows parity evidence must execute the native_v3 backend (available=%s backend=%s)." % [native_available, backend])
	if OS.has_feature("web") and backend != "gdscript_v3":
		failures.append("Web parity evidence must execute the gdscript_v3 reference backend (backend=%s)." % backend)
	var parity_machines: Array = []
	for machine_report_value in machine_reports:
		parity_machines.append(_parity_record(machine_report_value as Dictionary))
	var payload := {"schema": "coin_pusher_v3_production_input_parity_payload_v3", "machines": parity_machines}
	return {
		"ok": failures.is_empty(),
		"schema": "coin_pusher_v3_export_parity_smoke",
		"version": 3,
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"distribution_feature": OS.has_feature("distribution_build"),
		"solver_backend": backend,
		"native_backend_available": native_available,
		"host_bookkeeping_event_kinds": ["insert"],
		"inserted_id_derivation": "canonical initial next_body_id plus accepted_inserts delta",
		"machines": machine_reports,
		"parity_machines": parity_machines,
		"parity_payload_sha256": _canonical_json(payload).sha256_text(),
		"failure_count": failures.size(),
		"failures": failures,
	}


static func _run_machine(machine_id: String, definition: Dictionary, failures: Array[String]) -> Dictionary:
	var opening_seed := "PUSHER-V3-PARITY:%s:OPENING" % machine_id
	var replay_seed := "PUSHER-V3-PARITY:%s:REPLAY" % machine_id
	var snapshot := Solver.create_machine(_rng(opening_seed), definition, OPENING_BODY_COUNT)
	var initial_digest := Solver.canonical_digest(snapshot)
	var initial_json := _canonical_json(initial_digest)
	var trace := _trace(machine_id, int(snapshot.get("tick", 0)))
	var trace_json := _canonical_json(trace)
	if trace.is_empty():
		failures.append("%s parity trace is empty." % machine_id)
	var first := Solver.replay_input_trace(snapshot, _rng(replay_seed), trace, REPLAY_TICKS)
	var second := Solver.replay_input_trace(snapshot, _rng(replay_seed), trace, REPLAY_TICKS)
	var final_digest := Solver.canonical_digest(first)
	var repeat_digest := Solver.canonical_digest(second)
	var final_json := _canonical_json(final_digest)
	var repeat_json := _canonical_json(repeat_digest)
	var all_events: Array = first.get("last_events", []) if typeof(first.get("last_events", [])) == TYPE_ARRAY else []
	var events := _physics_events(all_events)
	var tray: Array = first.get("tray_ledger", []) if typeof(first.get("tray_ledger", [])) == TYPE_ARRAY else []
	var gutter: Array = first.get("gutter_ledger", []) if typeof(first.get("gutter_ledger", [])) == TYPE_ARRAY else []
	var peg_body_ids: Array = []
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == "peg_impact":
			var body_id := str((event_value as Dictionary).get("body_id", ""))
			if not peg_body_ids.has(body_id):
				peg_body_ids.append(body_id)
	var inserted_ids := _inserted_body_ids(initial_digest, final_digest)
	var peg_hit_count := 0
	var peg_miss_count := 0
	for body_id in inserted_ids:
		if peg_body_ids.has(body_id):
			peg_hit_count += 1
		else:
			peg_miss_count += 1
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var apparatus_type := str(apparatus.get("type", ""))
	var trace_kinds: Array = []
	for input_value in trace:
		trace_kinds.append(str((input_value as Dictionary).get("kind", "")))
	if apparatus_type == "rail_slot" and not trace_kinds.has("carriage"):
		failures.append("%s did not exercise its rail carriage control." % machine_id)
	if apparatus_type == "hole_set" and not trace_kinds.has("hole"):
		failures.append("%s did not exercise its authored hole selector." % machine_id)
	for required_kind in ["drop", "skill_stop", "nudge"]:
		if not trace_kinds.has(required_kind):
			failures.append("%s parity trace omitted %s." % [machine_id, required_kind])
	# Dense Plinko boards may legitimately route every short smoke-trace drop
	# through a peg. Require real contact and complete inserted-body accounting;
	# the exhaustive traversal matrix separately measures rare miss frequency.
	var entry_coverage_ok := peg_hit_count >= 1 and peg_hit_count + peg_miss_count == inserted_ids.size()
	if inserted_ids.size() < 2 or not entry_coverage_ok:
		failures.append("%s did not prove its authored inserted-body entry coverage (inserted=%s hit=%d miss=%d)." % [machine_id, JSON.stringify(inserted_ids), peg_hit_count, peg_miss_count])
	if machine_id == "jackpot_ridge" and (not trace_kinds.has("motor_rate") or int(final_digest.get("motor_run_rate_fp", 0)) != Solver.FP * 2 or int(final_digest.get("motor_target_rate_fp", 0)) != Solver.FP * 2):
		failures.append("Jackpot Ridge parity trace did not preserve its authored rate=2 run behavior.")
	if initial_json == final_json:
		failures.append("%s trace produced no canonical state change." % machine_id)
	if final_json != repeat_json:
		failures.append("%s was not bit-identical across same-process repeated replays." % machine_id)
	if _canonical_json(Solver.canonical_digest(snapshot)) != initial_json:
		failures.append("%s replay mutated its fresh source state." % machine_id)
	return {
		"machine_id": machine_id,
		"apparatus_type": apparatus_type,
		"definition_sha256": _canonical_json(definition).sha256_text(),
		"trace_sha256": trace_json.sha256_text(),
		"rng_opening_sha256": opening_seed.sha256_text(),
		"rng_replay_sha256": replay_seed.sha256_text(),
		"trace": trace,
		"trace_input_count": trace.size(),
		"replay_ticks": REPLAY_TICKS,
		"initial_canonical_state": initial_digest,
		"initial_canonical_sha256": initial_json.sha256_text(),
		"final_canonical_state": final_digest,
		"final_canonical_sha256": final_json.sha256_text(),
		"repeat_canonical_sha256": repeat_json.sha256_text(),
		"same_process_repeat_exact": final_json == repeat_json,
		"physics_events_sha256": _canonical_json(events).sha256_text(),
		"physics_event_count": events.size(),
		"physics_event_log": events,
		"raw_event_kind_counts": _event_kind_counts(all_events),
		"tray_digest_sha256": _canonical_json(tray).sha256_text(),
		"tray_count": tray.size(),
		"gutter_digest_sha256": _canonical_json(gutter).sha256_text(),
		"gutter_count": gutter.size(),
		"inserted_body_ids": inserted_ids,
		"peg_hit_body_ids": peg_body_ids,
		"peg_hit_body_count": peg_hit_count,
		"peg_miss_body_count": peg_miss_count,
		"accepted_inserts": int(final_digest.get("accepted_inserts", 0)),
		"refused_inserts": int(final_digest.get("refused_inserts", 0)),
	}


static func _trace(machine_id: String, start_tick: int) -> Array:
	if machine_id == "jackpot_ridge":
		return [
			{"tick": start_tick + 2, "kind": "hole", "index": 0},
			{"tick": start_tick + 5, "kind": "drop", "x": 25000, "density": 1},
			{"tick": start_tick + 90, "kind": "hole", "index": 1},
			{"tick": start_tick + 95, "kind": "drop", "x": 50000, "density": 1},
			{"tick": start_tick + 140, "kind": "hole", "index": 2},
			{"tick": start_tick + 145, "kind": "drop", "x": 75000, "density": 1},
			{"tick": start_tick + 180, "kind": "motor_rate", "rate_fp": Solver.FP * 2},
			{"tick": start_tick + 230, "kind": "skill_stop", "engaged": true},
			{"tick": start_tick + 270, "kind": "skill_stop", "engaged": false, "resume_rate_fp": Solver.FP * 2},
			{"tick": start_tick + 330, "kind": "nudge", "x": -700, "y": -900},
			{"tick": start_tick + 719, "kind": "drop", "x": 75000, "density": 1},
		]
	var rail_min := 8000 if machine_id == "quarter_falls" else 10000
	var hit_x := 30000 if machine_id == "quarter_falls" else 22000
	return [
		{"tick": start_tick + 2, "kind": "carriage", "x": hit_x},
		{"tick": start_tick + 5, "kind": "drop", "x": hit_x, "density": 1},
		{"tick": start_tick + 100, "kind": "carriage", "x": rail_min},
		{"tick": start_tick + 105, "kind": "drop", "x": rail_min, "density": 1},
		{"tick": start_tick + 210, "kind": "skill_stop", "engaged": true},
		{"tick": start_tick + 250, "kind": "skill_stop", "engaged": false},
		{"tick": start_tick + 320, "kind": "nudge", "x": 700, "y": -900},
	]


static func _physics_events(all_events: Array) -> Array:
	var result: Array = []
	for event_value in all_events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) != "insert":
			result.append((event_value as Dictionary).duplicate(true))
	return result


static func _event_kind_counts(events: Array) -> Dictionary:
	var counts := {}
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var kind := str((event_value as Dictionary).get("kind", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


static func _inserted_body_ids(initial_digest: Dictionary, final_digest: Dictionary) -> Array:
	var result: Array = []
	var first_id := int(initial_digest.get("next_body_id", 1))
	var accepted := int(final_digest.get("accepted_inserts", 0)) - int(initial_digest.get("accepted_inserts", 0))
	for serial in range(first_id, first_id + maxi(0, accepted)):
		result.append("body_%05d" % serial)
	return result


static func _parity_record(report: Dictionary) -> Dictionary:
	var keys := [
		"machine_id", "apparatus_type", "definition_sha256", "trace_sha256",
		"rng_opening_sha256", "rng_replay_sha256", "trace_input_count", "replay_ticks",
		"initial_canonical_sha256", "final_canonical_sha256", "repeat_canonical_sha256",
		"same_process_repeat_exact", "physics_events_sha256", "physics_event_count",
		"tray_digest_sha256", "tray_count", "gutter_digest_sha256", "gutter_count",
		"inserted_body_ids", "peg_hit_body_ids", "peg_hit_body_count", "peg_miss_body_count",
		"accepted_inserts", "refused_inserts",
	]
	var result := {}
	for key in keys:
		result[key] = report.get(key)
	return result


static func _canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


static func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash(seed))
	return rng


static func _stable_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value
