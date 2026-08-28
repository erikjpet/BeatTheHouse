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
	var verbs := _array(_dict(entry.get("authoring", {})).get("player_verbs", []))
	verbs = verbs.slice(0, verbs.size() - 2)
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


func _runtime_command(state: Dictionary, definition: Dictionary, command_id: String, node_id: String, receipt_id: String, stable_object_id: String) -> Dictionary:
	var descriptor := Runtime._command_descriptor(state, definition, "scenario", stable_object_id, command_id)
	return Runtime.command(command_id, node_id, str(state.get("phase_id", "")), receipt_id, {}, "scenario", stable_object_id, str(descriptor.get("action_origin_owner_namespace", "scenario")), str(descriptor.get("action_origin_stable_object_id", stable_object_id)), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))


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
