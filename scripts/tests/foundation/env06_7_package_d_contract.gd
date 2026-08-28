extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_underground_lounge.json"
const EXPECTED_IDS := [
	"punchline_open_mic_night", "punchline_headliner_night",
	"punchline_bringer_show", "punchline_high_stakes_night",
	"punchline_greased_week", "punchline_debt_court",
	"punchline_new_muscle", "punchline_raid_jitters",
	"kitty_cat_lounge_amateur_night", "kitty_cat_lounge_buyout",
	"kitty_cat_lounge_slow_night", "kitty_cat_lounge_bachelorette_storm",
]


func _initialize() -> void:
	var failures: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish(["Package D is not a JSON dictionary."])
		return
	var package := parsed as Dictionary
	if int(package.get("schema_version", 0)) != 1 or str(package.get("package_id", "")) != "env06_7_punchline_clubs": failures.append("Package D identity/version changed.")
	if str(package.get("handler_pack", "")) != "punchline_clubs" or str(package.get("renderer_id", "")) != "punchline_clubs": failures.append("Package D extension identity changed.")
	var actual_ids: Array = []
	var signatures: Dictionary = {}
	var definitions: Array = []
	for entry_value in _array(package.get("scenarios", [])):
		var entry := _dict(entry_value)
		var scenario_id := str(entry.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var archetype_id := "kitty_cat_lounge" if scenario_id.begins_with("kitty_cat_lounge_") else "small_underground_casino"
		var definition := {"id":scenario_id,"archetype_id":archetype_id,"sequence":_dict(entry.get("sequence", {})),"sequence_package_id":"env06_7_punchline_clubs","sequence_handler_pack":"punchline_clubs","sequence_renderer_id":"punchline_clubs","sequence_authoring":_dict(entry.get("authoring", {}))}
		definitions.append(definition)
		var errors := Schema.validate_definition(definition, null, _dict(_host_semantics().get("target_inventory", {})))
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
		_check_runtime_replay(definition, entry, failures)
		_check_identity_branch_matrix(definition, entry, failures)
		_check_lifecycle_matrix(definition, entry, failures)
		_check_ingress_and_observer_contract(definition, entry, failures)
		_check_package_presentation_contract(definition, entry, failures)
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package D exact 12-id inventory changed.")
	var report := Schema.catalog_uniqueness_report(definitions, EXPECTED_IDS.size())
	var equal_pairs := _array(report.get("pairs", [])).filter(func(pair): return bool(_dict(pair).get("equal_normalized_hash", false)))
	if not equal_pairs.is_empty(): failures.append("Package D contains equivalent normalized sequences.")
	_finish(failures)


func _check_runtime_replay(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var node_id := "package_d_runtime_node"
	var host_semantics := _host_semantics()
	var state := Runtime.initial_state(definition, node_id, "%s_runtime_seed" % scenario_id, host_semantics)
	if str(state.get("status", "")) != "active":
		failures.append("%s runtime did not enter active arrival: %s" % [scenario_id, JSON.stringify(state.get("errors", []))])
		return
	var arrival_semantics := _dict(state.get("semantic_state", {}))
	if _dict(arrival_semantics.get("scene_objects", {})).size() < 3 or _dict(arrival_semantics.get("actors", {})).size() < 2:
		failures.append("%s arrival did not materialize its physical object/actor tableau." % scenario_id)
	var verbs := _success_verbs(definition)
	for index in range(verbs.size()):
		var command_id := str(verbs[index])
		var target_id := "%s_task_%d" % [scenario_id, index]
		var command_value := _runtime_command(state, definition, command_id, node_id, "%s:runtime:%d" % [scenario_id, index], target_id)
		var applied := Runtime.apply_command(state, definition, command_value)
		if not bool(applied.get("ok", false)):
			failures.append("%s runtime rejected physical verb %s: %s" % [scenario_id, command_id, JSON.stringify(applied.get("errors", []))])
			return
		state = _dict(applied.get("state", {}))
		var saved := JSON.stringify(state)
		var normalized := Runtime.normalize_state(JSON.parse_string(saved), definition, host_semantics)
		if str(normalized.get("phase_id", "")) != str(state.get("phase_id", "")) or str(normalized.get("status", "")) != str(state.get("status", "")) or _array(normalized.get("command_receipts", [])) != _array(state.get("command_receipts", [])) or _array(_dict(normalized.get("semantic_state", {})).get("operation_receipts", [])) != _array(_dict(state.get("semantic_state", {})).get("operation_receipts", [])):
			failures.append("%s runtime save normalization changed phase/receipt authority after %s." % [scenario_id, command_id])
			return
		var replay := Runtime.apply_command(state, definition, command_value)
		var replay_state := _dict(replay.get("state", {}))
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or str(replay_state.get("phase_id", "")) != str(state.get("phase_id", "")) or _array(replay_state.get("command_receipts", [])) != _array(state.get("command_receipts", [])) or _array(_dict(replay_state.get("semantic_state", {})).get("operation_receipts", [])) != _array(_dict(state.get("semantic_state", {})).get("operation_receipts", [])):
			failures.append("%s command receipt %s was not an exact state-idempotent replay." % [scenario_id, command_id])
			return
	if str(state.get("status", "")) != "aftermath" or _array(state.get("resolved_outcomes", [])).is_empty():
		failures.append("%s physical success trace did not reach authored aftermath." % scenario_id)
	var operation_receipts := _array(_dict(state.get("semantic_state", {})).get("operation_receipts", []))
	if operation_receipts.size() < verbs.size() + 5:
		failures.append("%s runtime did not retain exact operation receipts across its trace." % scenario_id)
	var refused := Runtime.initial_state(definition, node_id, "%s_refuse_seed" % scenario_id, host_semantics)
	var refuse_id := "refuse_%s" % scenario_id
	var refuse_command := _runtime_command(refused, definition, refuse_id, node_id, "%s:refuse" % scenario_id, "%s_safe_exit" % scenario_id)
	var refused_result := Runtime.apply_command(refused, definition, refuse_command)
	if not bool(refused_result.get("ok", false)) or str(_dict(refused_result.get("state", {})).get("status", "")) != "aftermath":
		failures.append("%s refusal path did not remain a clean terminal exit: %s" % [scenario_id, JSON.stringify(refused_result.get("errors", []))])


func _check_identity_branch_matrix(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var decision := _dict(_dict(entry.get("authoring", {})).get("identity_decision", {}))
	var decision_phase := str(decision.get("phase_id", ""))
	var options := _array(decision.get("options", []))
	if decision_phase.is_empty() or options.size() != 3:
		failures.append("%s lacks its exact three-way identity decision contract." % scenario_id)
		return
	for option_index in range(options.size()):
		var option := _array(options[option_index])
		var state := _state_at_phase(definition, decision_phase, "%s_identity_%d" % [scenario_id, option_index], failures)
		if state.is_empty(): return
		var command_id := str(option[0])
		var target := str(option[1])
		var result := _apply_named_command(state, definition, command_id, "%s:identity:%d" % [scenario_id, option_index])
		var next := _dict(result.get("state", {}))
		if not bool(result.get("ok", false)) or (target.begins_with("terminal_") and str(next.get("status", "")) != "aftermath") or (not target.begins_with("terminal_") and str(next.get("phase_id", "")) != target):
			failures.append("%s identity decision %s did not execute its authored target %s: %s" % [scenario_id, command_id, target, JSON.stringify(result.get("errors", []))])


func _check_lifecycle_matrix(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var phases := ["arrival"]
	for index in range(_success_verbs(definition).size() - 1): phases.append("work_%d" % (index + 1))
	for phase_id in phases:
		for branch_kind in ["failure", "refused", "interrupted"]:
			var state := _state_at_phase(definition, phase_id, "%s_%s_%s" % [scenario_id, phase_id, branch_kind], failures)
			if state.is_empty(): return
			var result: Dictionary
			if branch_kind == "interrupted":
				result = _apply_fact_branch(state, definition, "travel_departed", {"source_id":scenario_id,"target_id":"world_map","travel_kind":"ordinary"}, "%s:%s:interrupt" % [scenario_id, phase_id])
			else:
				result = _apply_named_command(state, definition, ("fail_" if branch_kind == "failure" else "refuse_") + scenario_id, "%s:%s:%s" % [scenario_id, phase_id, branch_kind])
			if not bool(result.get("ok", false)) or str(_dict(result.get("state", {})).get("status", "")) != "aftermath":
				failures.append("%s %s branch at %s did not reach aftermath atomically: %s" % [scenario_id, branch_kind, phase_id, JSON.stringify(result.get("errors", []))])
	var partial := _state_at_phase(definition, "work_1", "%s_partial_reentry" % scenario_id, failures)
	var partial_saved := Runtime.normalize_state(JSON.parse_string(JSON.stringify(partial)), definition, _host_semantics())
	var partial_reentry := Runtime.apply_reentry(partial_saved, definition, "%s_partial_visit" % scenario_id, _host_semantics())
	if not bool(partial_reentry.get("ok", false)) or str(_dict(partial_reentry.get("state", {})).get("phase_id", "")) != "work_1": failures.append("%s partial save/reentry did not resume exact phase." % scenario_id)
	var terminal := _apply_named_command(Runtime.initial_state(definition, "package_d_runtime_node", "%s_terminal" % scenario_id, _host_semantics()), definition, "fail_%s" % scenario_id, "%s:terminal" % scenario_id)
	var terminal_reentry := Runtime.apply_reentry(_dict(terminal.get("state", {})), definition, "%s_terminal_visit" % scenario_id, _host_semantics())
	if not bool(terminal_reentry.get("ok", false)) or str(_dict(terminal_reentry.get("state", {})).get("status", "")) != "aftermath": failures.append("%s terminal reentry did not preserve aftermath." % scenario_id)
	var expiry_state := Runtime.initial_state(definition, "package_d_runtime_node", "%s_expiry" % scenario_id, _host_semantics())
	var expired := Runtime.apply_expiry(expiry_state, definition, "night_end", 1)
	var expired_state := _dict(expired.get("state", {}))
	var expired_reentry := Runtime.apply_reentry(expired_state, definition, "%s_expired_visit" % scenario_id, _host_semantics())
	if not bool(expired.get("ok", false)) or not bool(expired.get("expired", false)) or not _semantic_collections_empty(expired_state) or not bool(expired_reentry.get("ok", false)) or str(_dict(expired_reentry.get("state", {})).get("status", "")) != "cleaned": failures.append("%s expiry/cleanup/reentry contract failed." % scenario_id)


func _check_ingress_and_observer_contract(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var state := Runtime.initial_state(definition, "package_d_runtime_node", "%s_ingress" % scenario_id, _host_semantics())
	var valid := _runtime_command(state, definition, str(_success_verbs(definition)[0]), "package_d_runtime_node", "%s:receipt" % scenario_id, "%s_task_0" % scenario_id)
	var accepted := Runtime.apply_command(state, definition, valid)
	if not bool(accepted.get("ok", false)):
		failures.append("%s could not establish receipt mismatch fixture." % scenario_id)
		return
	var accepted_state := _dict(accepted.get("state", {}))
	var accepted_snapshot := JSON.stringify(accepted_state)
	var mismatch := valid.duplicate(true)
	mismatch["idempotency_key"] = "%s:receipt" % scenario_id
	mismatch["command_id"] = "fail_%s" % scenario_id
	var rejected := Runtime.apply_command(accepted_state, definition, mismatch)
	if bool(rejected.get("ok", false)) or JSON.stringify(_dict(rejected.get("state", {}))) != accepted_snapshot: failures.append("%s receipt mismatch was not rejected without mutation." % scenario_id)
	var malformed := valid.duplicate(true)
	malformed["action_origin_fingerprint"] = "0".repeat(64)
	var malformed_result := Runtime.apply_command(state, definition, malformed)
	if bool(malformed_result.get("ok", false)) or JSON.stringify(_dict(malformed_result.get("state", {}))) != JSON.stringify(state): failures.append("%s malformed operation injection partially committed." % scenario_id)
	var projection := Runtime.public_projection(state, definition)
	for forbidden in ["command_fingerprints", "fact_fingerprints", "seed_token", "cleanup_fingerprints", "command_results"]:
		if projection.has(forbidden): failures.append("%s public observer leaked hidden %s." % [scenario_id, forbidden])
	var native_projection := JSON.stringify(projection)
	var web_projection := JSON.stringify(Runtime.public_projection(JSON.parse_string(JSON.stringify(state)), definition))
	if native_projection != web_projection: failures.append("%s native/Web serialized public parity drifted." % scenario_id)


func _check_package_presentation_contract(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var state := Runtime.initial_state(definition, "package_d_runtime_node", "%s_present" % scenario_id, _host_semantics())
	var semantic := _dict(state.get("semantic_state", {}))
	var interactions := _dict(semantic.get("interactions", {}))
	if interactions.size() < 2: failures.append("%s presentation lacks task plus safe-exit targets." % scenario_id)
	var rect_keys: Dictionary = {}
	for interaction_value in interactions.values():
		var interaction := _dict(interaction_value)
		var hit := _dict(interaction.get("hit_bounds", {}))
		if int(hit.get("w", 0)) < 44 or int(hit.get("h", 0)) < 44 or str(interaction.get("label", "")).is_empty() or str(interaction.get("prompt", "")).is_empty() or str(interaction.get("non_color_state", "")).is_empty(): failures.append("%s presentation target failed label/prompt/non-color/44px accessibility." % scenario_id)
		rect_keys["%s:%s" % [hit.get("w", 0), hit.get("h", 0)]] = true
	var captures := _array(_dict(entry.get("authoring", {})).get("capture_ids", []))
	for suffix in ["arrival","partial","success","failure","refused","interrupted","reduced_motion","small_screen","hit_overlay","obstruction"]:
		if not captures.has("%s_%s" % [scenario_id, suffix]): failures.append("%s lacks package-scoped %s evidence binding." % [scenario_id, suffix])
	var normal := Runtime.drain_transitions(state, definition, false)
	var reduced := Runtime.drain_transitions(state, definition, true)
	if not bool(normal.get("ok", false)) or not bool(reduced.get("ok", false)) or _array(normal.get("transitions", [])).size() != _array(reduced.get("transitions", [])).size(): failures.append("%s reduced-motion presentation parity failed." % scenario_id)


func _runtime_command(state: Dictionary, definition: Dictionary, command_id: String, node_id: String, receipt_id: String, stable_object_id: String) -> Dictionary:
	var descriptor := Runtime._command_descriptor(state, definition, "scenario", stable_object_id, command_id)
	return Runtime.command(command_id, node_id, str(state.get("phase_id", "")), receipt_id, {}, "scenario", stable_object_id, str(descriptor.get("action_origin_owner_namespace", "scenario")), str(descriptor.get("action_origin_stable_object_id", stable_object_id)), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))


func _success_verbs(definition: Dictionary) -> Array:
	var result: Array = []
	for objective_value in _array(_dict(definition.get("sequence", {})).get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			result.append(str(_dict(step_value).get("command_id", "")))
	return result


func _state_at_phase(definition: Dictionary, target_phase: String, seed: String, failures: Array) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var state := Runtime.initial_state(definition, "package_d_runtime_node", seed, _host_semantics())
	var verbs := _success_verbs(definition)
	var guard := 0
	while str(state.get("phase_id", "")) != target_phase and str(state.get("status", "")) == "active" and guard < verbs.size():
		var phase_id := str(state.get("phase_id", ""))
		var index := 0 if phase_id == "arrival" else int(phase_id.trim_prefix("work_"))
		var result := _apply_named_command(state, definition, str(verbs[index]), "%s:advance:%d" % [seed, guard])
		if not bool(result.get("ok", false)):
			failures.append("%s could not prepare phase %s: %s" % [scenario_id, target_phase, JSON.stringify(result.get("errors", []))])
			return {}
		state = _dict(result.get("state", {}))
		guard += 1
	if str(state.get("phase_id", "")) != target_phase:
		failures.append("%s did not reach prepared phase %s." % [scenario_id, target_phase])
		return {}
	return state


func _apply_named_command(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var phase_id := str(state.get("phase_id", ""))
	var index := 0 if phase_id == "arrival" else int(phase_id.trim_prefix("work_"))
	var stable_object_id := "%s_safe_exit" % scenario_id if command_id.begins_with("refuse_") and phase_id == "arrival" else "%s_task_%d" % [scenario_id, index]
	return Runtime.apply_command(state, definition, _runtime_command(state, definition, command_id, "package_d_runtime_node", receipt_id, stable_object_id))


func _apply_fact_branch(state: Dictionary, definition: Dictionary, fact_type: String, payload: Dictionary, fact_id: String) -> Dictionary:
	var producer := "travel" if fact_type.begins_with("travel_") else "scenario"
	var fact := Runtime.fact(fact_type, producer, "package_d_runtime_node", fact_id, 1, 1, payload)
	var enqueued := Runtime.enqueue_fact(state, definition, fact)
	if not bool(enqueued.get("ok", false)): return enqueued
	return Runtime.flush_facts(_dict(enqueued.get("state", {})), definition, 1)


func _semantic_collections_empty(state: Dictionary) -> bool:
	var semantic := _dict(state.get("semantic_state", {}))
	for key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors"]:
		if not _dict(semantic.get(key, {})).is_empty(): return false
	return true


func _host_semantics() -> Dictionary:
	var zones := ["base::zone:left", "base::zone:center", "base::zone:right", "base::zone:background", "base::zone:exit_lane", "base::zone:service_lane"]
	for index in range(6): zones.append("base::zone:work_%d" % index)
	return {"target_inventory":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":zones,"event_choices":{}},"inventory_schema_version":1,"inventory_digest":"package_d_fixture_inventory","inventory_errors":[],"base_interactions":[],"event_choices":{}}


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
		print("ENV06_7_PACKAGE_D_CONTRACT_OK scenarios=12 signatures=12")
		quit(0)
	else:
		for failure in failures: printerr("ENV06_7_PACKAGE_D_CONTRACT_FAIL %s" % failure)
		quit(1)


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
