extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_bars_road.json"
const EXPECTED_IDS := [
	"bar_wake", "bar_fight_night", "bar_payday_rush", "bar_lock_in",
	"bar_darts_league_night", "bar_live_band", "bar_dead_tuesday",
	"jazz_club_guest_legend", "jazz_club_rent_party",
	"jazz_club_recording_night", "jazz_club_union_trouble",
]


func _initialize() -> void:
	var failures: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish(["Package C is not a JSON dictionary."])
		return
	var package := parsed as Dictionary
	if int(package.get("schema_version", 0)) != 1 or str(package.get("package_id", "")) != "env06_7_bars_road": failures.append("Package C identity/version changed.")
	if str(package.get("handler_pack", "")) != "bars_road" or str(package.get("renderer_id", "")) != "bars_road": failures.append("Package C extension identity changed.")
	var actual_ids: Array = []
	var signatures: Dictionary = {}
	var definitions: Array = []
	for entry_value in _array(package.get("scenarios", [])):
		var entry := _dict(entry_value)
		var scenario_id := str(entry.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var definition := {"id":scenario_id,"archetype_id":"jazz_club" if scenario_id.begins_with("jazz_club_") else "bar","sequence":_dict(entry.get("sequence", {})),"sequence_package_id":"env06_7_bars_road","sequence_handler_pack":"bars_road","sequence_renderer_id":"bars_road","sequence_authoring":_dict(entry.get("authoring", {}))}
		definitions.append(definition)
		var errors := Schema.validate_definition(definition, null, _target_inventory())
		if not errors.is_empty(): failures.append("%s schema errors: %s" % [scenario_id, JSON.stringify(errors)])
		var signature := str(definition.sequence.get("sequence_signature", ""))
		if signature.length() != 64 or signatures.has(signature): failures.append("%s lacks a unique calculated signature." % scenario_id)
		signatures[signature] = scenario_id
		var outcomes := Schema.reachable_outcome_ids(definition)
		if outcomes.size() != 4: failures.append("%s must expose success, failure, refuse, and interruption aftermaths." % scenario_id)
		var phases := _array(_dict(definition.sequence.get("phase_graph", {})).get("phases", []))
		if phases.size() < 6: failures.append("%s is not a multi-step physical sequence." % scenario_id)
		if _array(_dict(entry.get("authoring", {})).get("player_verbs", [])).size() < 4: failures.append("%s lacks scenario-specific verbs." % scenario_id)
		var receipts: Dictionary = {}
		_collect_receipts(definition.sequence, receipts, failures, scenario_id)
		_check_runtime_matrix(definition, entry, failures)
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package C exact 11-id inventory changed.")
	var catalog := Catalog.load_catalog()
	if not bool(catalog.get("ok", false)): failures.append("Catalog rejected Package C: %s" % JSON.stringify(catalog.get("failures", [])))
	for scenario_id in EXPECTED_IDS:
		var overlay := Catalog.overlay_for(scenario_id, catalog)
		if str(overlay.get("package_id", "")) != "env06_7_bars_road": failures.append("Catalog did not claim %s exactly once." % scenario_id)
	var report := Schema.catalog_uniqueness_report(definitions, EXPECTED_IDS.size())
	var equal_pairs := _array(report.get("pairs", [])).filter(func(pair): return bool(_dict(pair).get("equal_normalized_hash", false)))
	if not equal_pairs.is_empty(): failures.append("Package C contains equivalent normalized sequences.")
	_finish(failures)

func _check_runtime_matrix(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var verbs := _objective_commands(definition)
	var success := _initial(definition, "%s_success" % sid)
	if str(success.get("status", "")) != "active":
		failures.append("%s runtime initialization failed: %s" % [sid,JSON.stringify(success.get("errors",[]))])
		return
	for index in range(verbs.size()):
		if not _round_trip(success, definition): failures.append("%s success pre-save drifted at %d." % [sid,index])
		var result := _apply(success, definition, str(verbs[index]), "%s:success:%d" % [sid,index])
		if not bool(result.get("ok", false)):
			failures.append("%s success command %s failed: %s" % [sid,verbs[index],JSON.stringify(result.get("errors",[]))])
			return
		success = _dict(result.get("state", {}))
		if not _round_trip(success, definition): failures.append("%s success post-save drifted at %d." % [sid,index])
	if str(success.get("status", "")) != "aftermath": failures.append("%s success trace did not terminate." % sid)
	var phases := ["arrival"]
	for index in range(1, verbs.size()): phases.append("work_%d" % index)
	for phase_id in phases:
		for kind in ["failure","refused","interrupted"]:
			_check_terminal_route(definition, phase_id, kind, failures)
		if phase_id != "arrival": _check_pressure_route(definition, phase_id, failures)
	_check_identity_routes(definition, entry, failures)
	_check_reentry_expiry(definition, failures)
	_check_hostile_privacy_presentation(definition, entry, failures)

func _check_terminal_route(definition: Dictionary, phase_id: String, kind: String, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var state := _state_at_phase(definition, phase_id, "%s_%s_%s" % [sid,phase_id,kind], failures)
	if state.is_empty(): return
	if not _round_trip(state, definition): failures.append("%s %s %s pre-save drifted." % [sid,phase_id,kind])
	var result: Dictionary
	if kind == "interrupted": result = _fact_route(state, definition, "travel_departed", {"source_id":sid,"target_id":"world_map","travel_kind":"ordinary"}, "%s:%s:depart" % [sid,phase_id])
	else: result = _apply(state, definition, ("fail_" if kind == "failure" else "refuse_") + sid, "%s:%s:%s" % [sid,phase_id,kind])
	var terminal := _dict(result.get("state", {}))
	if not bool(result.get("ok", false)) or str(terminal.get("status", "")) != "aftermath": failures.append("%s %s at %s failed: %s" % [sid,kind,phase_id,JSON.stringify(result.get("errors",[]))])
	if not _round_trip(terminal, definition): failures.append("%s %s %s post-save drifted." % [sid,phase_id,kind])

func _check_pressure_route(definition: Dictionary, phase_id: String, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var fact_type := _scenario_fact_type(definition)
	var state := _state_at_phase(definition, phase_id, "%s_%s_pressure" % [sid,phase_id], failures)
	var result := _fact_route(state, definition, fact_type, _valid_payload(fact_type), "%s:%s:pressure" % [sid,phase_id])
	if not bool(result.get("ok", false)) or str(_dict(result.get("state", {})).get("status", "")) != "aftermath": failures.append("%s pressure fact %s at %s failed." % [sid,fact_type,phase_id])

func _check_identity_routes(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var evidence := _dict(_dict(entry.get("authoring", {})).get("seed_evidence", {}))
	var phase_id := str(evidence.get("identity_decision_phase", ""))
	var decision_verbs := _array(evidence.get("identity_decision_verbs", []))
	if phase_id.is_empty() or decision_verbs.size() != 3:
		failures.append("%s lacks its exact three-way identity decision evidence." % sid)
		return
	var terminal_count := 0
	for index in range(decision_verbs.size()):
		var state := _state_at_phase(definition, phase_id, "%s_identity_%d" % [sid,index], failures)
		var command_id := str(decision_verbs[index])
		var target := _branch_target(definition, phase_id, command_id)
		var result := _apply(state, definition, command_id, "%s:identity:%d" % [sid,index])
		var next := _dict(result.get("state", {}))
		if target.begins_with("terminal_"): terminal_count += 1
		if not bool(result.get("ok", false)) or (target.begins_with("terminal_") and str(next.get("status", "")) != "aftermath") or (not target.begins_with("terminal_") and str(next.get("phase_id", "")) != target): failures.append("%s identity command %s missed target %s." % [sid,command_id,target])
		if not _round_trip(next, definition): failures.append("%s identity command %s save/load drifted." % [sid,command_id])
	if terminal_count < 2: failures.append("%s identity graph lacks materially exclusive terminal choices." % sid)

func _check_reentry_expiry(definition: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var partial := _state_at_phase(definition, "work_1", "%s_partial" % sid, failures)
	var partial_reentry := Runtime.apply_reentry(partial, definition, "%s_partial_visit" % sid, _host_semantics())
	if not bool(partial_reentry.get("ok", false)) or str(_dict(partial_reentry.get("state", {})).get("phase_id", "")) != "work_1": failures.append("%s partial reentry failed." % sid)
	var terminal := _dict(_apply(_initial(definition, "%s_terminal" % sid), definition, "fail_%s" % sid, "%s:terminal" % sid).get("state", {}))
	var terminal_reentry := Runtime.apply_reentry(terminal, definition, "%s_terminal_visit" % sid, _host_semantics())
	if not bool(terminal_reentry.get("ok", false)) or str(_dict(terminal_reentry.get("state", {})).get("status", "")) != "aftermath": failures.append("%s terminal reentry failed." % sid)
	var expiry := Runtime.apply_expiry(_initial(definition, "%s_expiry" % sid), definition, "night_end", 1)
	var expired := _dict(expiry.get("state", {}))
	var expired_reentry := Runtime.apply_reentry(expired, definition, "%s_expired_visit" % sid, _host_semantics())
	if not bool(expiry.get("ok", false)) or not bool(expiry.get("expired", false)) or str(expired.get("status", "")) != "cleaned" or not bool(expired_reentry.get("ok", false)): failures.append("%s expiry/cleanup/reentry failed." % sid)

func _check_hostile_privacy_presentation(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var state := _initial(definition, "%s_hostile" % sid)
	var command := _command(state, definition, str(_objective_commands(definition)[0]), "%s:receipt" % sid)
	var accepted := Runtime.apply_command(state, definition, command)
	var accepted_state := _dict(accepted.get("state", {}))
	var replay := Runtime.apply_command(accepted_state, definition, command)
	var conflict := command.duplicate(true)
	conflict["command_id"] = "fail_%s" % sid
	var accepted_snapshot := JSON.stringify(accepted_state)
	var rejected := Runtime.apply_command(accepted_state, definition, conflict)
	if not bool(accepted.get("ok", false)) or not bool(replay.get("replayed", false)) or bool(rejected.get("ok", false)) or JSON.stringify(_dict(rejected.get("state", {}))) != accepted_snapshot: failures.append("%s receipt replay/conflict failed." % sid)
	var hostile := command.duplicate(true)
	hostile["expected_phase"] = "wrong_phase"
	var hostile_result := Runtime.apply_command(state, definition, hostile)
	if bool(hostile_result.get("ok", false)) or JSON.stringify(_dict(hostile_result.get("state", {}))) != JSON.stringify(state): failures.append("%s hostile rollback injection partially committed." % sid)
	var projection := Runtime.public_projection(state, definition)
	for forbidden in ["seed_token","command_fingerprints","fact_fingerprints","command_results","cleanup_fingerprints"]:
		if projection.has(forbidden): failures.append("%s leaked private %s." % [sid,forbidden])
	var canonical := JSON.stringify(projection)
	if canonical != JSON.stringify(Runtime.public_projection(JSON.parse_string(JSON.stringify(state)), definition)): failures.append("%s native/Web deterministic platform parity drifted." % sid)
	var interactions := _dict(_dict(projection.get("semantic_state", {})).get("interactions", {}))
	if interactions.size() < 2: failures.append("%s production layout lacks independent task/safe-exit targets." % sid)
	for interaction_value in interactions.values():
		var interaction := _dict(interaction_value)
		var hit := _dict(interaction.get("hit_bounds", {}))
		if int(hit.get("w",0)) < 44 or int(hit.get("h",0)) < 44 or str(interaction.get("label","")).is_empty() or str(interaction.get("prompt","")).is_empty() or str(interaction.get("non_color_state","")).is_empty(): failures.append("%s presentation accessibility/hit/obstruction contract failed." % sid)
	var captures := _array(_dict(entry.get("authoring", {})).get("capture_ids", []))
	for suffix in ["arrival","partial","success","failure","refused","interrupted","reduced_motion","small_screen","hit_overlay","obstruction"]:
		if not captures.has("%s_%s" % [sid,suffix]): failures.append("%s lacks %s presentation binding." % [sid,suffix])
	var normal := Runtime.drain_transitions(state, definition, false)
	var reduced := Runtime.drain_transitions(state, definition, true)
	if not bool(normal.get("ok", false)) or not bool(reduced.get("ok", false)) or _array(normal.get("transitions", [])).size() != _array(reduced.get("transitions", [])).size(): failures.append("%s reduced-motion/liveness parity failed." % sid)

func _state_at_phase(definition: Dictionary, target_phase: String, seed: String, failures: Array) -> Dictionary:
	var sid := str(definition.get("id", ""))
	var state := _initial(definition, seed)
	var verbs := _objective_commands(definition)
	var guard := 0
	while str(state.get("phase_id", "")) != target_phase and str(state.get("status", "")) == "active" and guard < verbs.size():
		var current := str(state.get("phase_id", ""))
		var index := 0 if current == "arrival" else int(current.trim_prefix("work_"))
		var result := _apply(state, definition, str(verbs[index]), "%s:advance:%d" % [seed,guard])
		if not bool(result.get("ok", false)):
			failures.append("%s could not prepare %s." % [sid,target_phase])
			return {}
		state = _dict(result.get("state", {}))
		guard += 1
	return state if str(state.get("phase_id", "")) == target_phase else {}

func _initial(definition: Dictionary, seed: String) -> Dictionary:
	return Runtime.initial_state(definition, "package_c_runtime_node", seed, _host_semantics())

func _apply(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	return Runtime.apply_command(state, definition, _command(state, definition, command_id, receipt_id))

func _command(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var object_id := ""
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id: object_id = str(interaction.get("stable_object_id", ""))
	var descriptor := Runtime._command_descriptor(state, definition, "scenario", object_id, command_id)
	return Runtime.command(command_id,"package_c_runtime_node",str(state.get("phase_id","")),receipt_id,{},"scenario",object_id,str(descriptor.get("action_origin_owner_namespace","scenario")),str(descriptor.get("action_origin_stable_object_id",object_id)),str(descriptor.get("action_origin_receipt_key","")),str(descriptor.get("action_origin_boundary_id","")),str(descriptor.get("action_origin_fingerprint","")))

func _fact_route(state: Dictionary, definition: Dictionary, fact_type: String, payload: Dictionary, fact_id: String) -> Dictionary:
	var fact := Runtime.fact(fact_type,_producer(fact_type),"package_c_runtime_node",fact_id,1,1,payload)
	var enqueued := Runtime.enqueue_fact(state, definition, fact)
	if not bool(enqueued.get("ok", false)): return enqueued
	var flushed := Runtime.flush_facts(_dict(enqueued.get("state", {})), definition, 1)
	if fact_type == "world_boundary" and str(_dict(flushed.get("state", {})).get("status", "")) == "active":
		var second := Runtime.fact(fact_type,_producer(fact_type),"package_c_runtime_node","%s_next" % fact_id,2,2,payload)
		var second_enqueue := Runtime.enqueue_fact(_dict(flushed.get("state", {})), definition, second)
		return Runtime.flush_facts(_dict(second_enqueue.get("state", {})), definition, 2)
	return flushed

func _objective_commands(definition: Dictionary) -> Array:
	var result: Array = []
	for objective_value in _array(_dict(definition.get("sequence", {})).get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])): result.append(str(_dict(step_value).get("command_id", "")))
	return result

func _scenario_fact_type(definition: Dictionary) -> String:
	for value in _array(_dict(definition.get("sequence", {})).get("fact_subscriptions", [])):
		var fact_type := str(value) if typeof(value) == TYPE_STRING else str(_dict(value).get("fact_type", ""))
		if fact_type != "travel_departed": return fact_type
	return ""

func _branch_target(definition: Dictionary, phase_id: String, command_id: String) -> String:
	for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		if str(phase.get("id", "")) != phase_id: continue
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			if str(condition.get("command_id", "")) == command_id: return str(branch.get("next_phase", ""))
	return ""

func _round_trip(state: Dictionary, definition: Dictionary) -> bool:
	if state.is_empty(): return false
	var restored := Runtime.normalize_state(JSON.parse_string(JSON.stringify(state)), definition, _host_semantics())
	return str(restored.get("phase_id","")) == str(state.get("phase_id","")) and str(restored.get("status","")) == str(state.get("status","")) and _array(restored.get("command_receipts",[])) == _array(state.get("command_receipts",[])) and _array(restored.get("fact_receipts",[])) == _array(state.get("fact_receipts",[])) and _array(_dict(restored.get("semantic_state",{})).get("operation_receipts",[])) == _array(_dict(state.get("semantic_state",{})).get("operation_receipts",[]))

func _producer(fact_type: String) -> String:
	for producer_value in Runtime.FACT_TYPES_BY_PRODUCER.keys():
		if _array(Runtime.FACT_TYPES_BY_PRODUCER.get(producer_value, [])).has(fact_type): return str(producer_value)
	return "scenario"

func _valid_payload(fact_type: String) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id":"darts","action_id":"match_resolved","won":false,"ended":true,"bankroll_delta":0,"chips_delta":0,"applied_heat_delta":0}
		"service_result": return {"kind":"bar_service","service_id":"bar_service","ok":false,"action_id":"resolved"}
		"crew_changed": return {"member_id":"wake_member","change":"memory","value":"changed"}
		"crew_job_changed": return {"job_id":"rent_party","status":"resolved","definition_id":"rent_party","member_id":"rent_host","outcome":"complete"}
		"heat_changed": return {"previous":10,"current":20,"applied_delta":10,"source":"bar_fight"}
		"heat_band_changed": return {"previous_band":"quiet","current_band":"caution","current":20,"source":"union_trouble"}
		"town_transition": return {"action_index":2,"weather":"clear","day_type":"weekday","happening_ids":[]}
		"sweep_changed": return {"action_index":2,"node_id":"bar","segment_index":1,"active":true}
		"travel_arrived": return {"source_id":"world_map","target_id":"jazz_club","travel_kind":"ordinary"}
		"scenario_command": return {"command_id":"save_recording_take","receipt_id":"recording_public_receipt"}
		"world_boundary": return {"amount":1,"action_index":2}
	return {}

func _target_inventory() -> Dictionary:
	var zones := ["base::zone:left","base::zone:right","base::zone:center","base::zone:background","base::zone:service_lane","base::zone:foreground","base::zone:exit_lane"]
	for index in range(6): zones.append("base::zone:work_%d" % index)
	return {"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":zones,"event_choices":{}}

func _host_semantics() -> Dictionary:
	return {"target_inventory":_target_inventory(),"inventory_schema_version":1,"inventory_digest":"package_c_production_inventory","inventory_errors":[],"base_interactions":[],"event_choices":{}}


func _collect_receipts(value: Variant, receipts: Dictionary, failures: Array, scenario_id: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var row := value as Dictionary
		if row.has("receipt_id"):
			var receipt := str(row.get("receipt_id", ""))
			if receipt.is_empty() or receipts.has(receipt): failures.append("%s has missing/duplicate exact receipt %s." % [scenario_id, receipt])
			receipts[receipt] = true
		for nested in row.values(): _collect_receipts(nested, receipts, failures, scenario_id)
	elif typeof(value) == TYPE_ARRAY:
		for nested in value as Array: _collect_receipts(nested, receipts, failures, scenario_id)


func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("ENV06_7_PACKAGE_C_CONTRACT_OK scenarios=11 signatures=11")
		quit(0)
	else:
		for failure in failures: printerr("ENV06_7_PACKAGE_C_CONTRACT_FAIL %s" % failure)
		quit(1)


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
