extends SceneTree

const SequenceCatalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceSchema := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistry := preload("res://scripts/core/scenario_operation_registry.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SemanticInventory := preload("res://scripts/core/environment_semantic_inventory.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"
const EXPECTED_IDS := [
	"back_alley_cruiser_parked", "back_alley_fence_night", "back_alley_nothing_moving", "back_alley_street_craps",
	"corner_store_aftermath", "corner_store_dead_shift", "corner_store_delivery_day", "corner_store_inventory_night", "corner_store_lotto_fever",
	"pawn_shop_estate_lot_day", "pawn_shop_sals_mood", "pawn_shop_serial_check_day",
]
var _library: Variant = null
var _composition_cache: Dictionary = {}
var _active_host: Dictionary = {}

func _init() -> void:
	var failures: Array = []
	_library = ContentLibraryScript.new()
	_library.load(false)
	var catalog := SequenceCatalog.load_catalog()
	if not bool(catalog.get("ok", false)): failures.append_array(catalog.get("failures", []))
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(parsed_value) != TYPE_DICTIONARY:
		_finish(["Package A file is not a JSON dictionary."])
		return
	var entries := _array((parsed_value as Dictionary).get("scenarios", []))
	var actual_ids: Array = []
	var signatures: Dictionary = {}
	var normalized_signatures: Dictionary = {}
	for entry_value in entries:
		var entry := _dict(entry_value)
		var scenario_id := str(entry.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var definition := _definition(entry)
		var definition_errors: Array = []
		if scenario_id != "corner_store_delivery_day":
			_active_host = _production_host(definition, failures)
			definition_errors = SequenceSchema.validate_definition(definition, OperationRegistry, _dict(_active_host.get("target_inventory", {})))
			for error_value in definition_errors: failures.append("%s: %s" % [scenario_id,error_value])
		var signature := str(_dict(definition.get("sequence", {})).get("sequence_signature", ""))
		if signatures.has(signature): failures.append("%s duplicates exact signature with %s." % [scenario_id, signatures[signature]])
		signatures[signature] = scenario_id
		var normalized := JSON.stringify(SequenceSchema.normalized_signature(definition))
		if normalized_signatures.has(normalized): failures.append("%s duplicates normalized signature with %s." % [scenario_id, normalized_signatures[normalized]])
		normalized_signatures[normalized] = scenario_id
		if scenario_id == "corner_store_delivery_day":
			_check_reference_runtime(definition, failures)
		elif definition_errors.is_empty() and not _active_host.is_empty():
			_check_executable_routes(definition, entry, failures)
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package A inventory mismatch: %s" % JSON.stringify(actual_ids))
	_finish(failures)

func _check_reference_runtime(definition: Dictionary, failures: Array) -> void:
	var sequence := _dict(definition.get("sequence", {}))
	if _array(_dict(sequence.get("phase_graph", {})).get("phases", [])).size() < 5 or _dict(sequence.get("aftermath", {})).size() != 4: failures.append("Delivery Day accepted executable reference graph changed inside Package A.")

func _check_executable_routes(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var verbs := _objective_commands(definition)
	var authoring := _dict(entry.get("authoring", {}))
	var player_verbs := _array(authoring.get("player_verbs", []))
	if verbs.size() != 2 or player_verbs.size() < 5:
		failures.append("%s lacks its exact executable command inventory." % sid)
		return
	var success := _initial(definition, "%s_success" % sid)
	if str(success.get("status", "")) != "active":
		failures.append("%s runtime initialization failed: %s" % [sid, JSON.stringify(success.get("errors", []))])
		return
	for index in range(verbs.size()):
		if not _round_trip(success, definition): failures.append("%s success pre-command save/load drifted at %d." % [sid,index])
		var applied := _apply(success, definition, str(verbs[index]), "%s:success:%d" % [sid,index])
		if not bool(applied.get("ok", false)):
			failures.append("%s success command %s failed: %s" % [sid,verbs[index],JSON.stringify(applied.get("errors", []))])
			return
		success = _dict(applied.get("state", {}))
		if not _round_trip(success, definition): failures.append("%s success post-command save/load drifted at %d." % [sid,index])
	if str(success.get("status", "")) != "aftermath" or not _array(success.get("resolved_outcomes", [])).has("success"): failures.append("%s success route did not reach success aftermath." % sid)
	_check_command_terminal(definition, str(player_verbs[2]), "failure", true, failures)
	_check_command_terminal(definition, "ignore_sequence", "ignored", false, failures)
	_check_command_terminal(definition, "refuse_sequence", "refused", false, failures)
	_check_interruption(definition, "arrival", failures)
	_check_interruption(definition, "work", failures)
	_check_public_fact(definition, entry, failures)
	_check_reentry_expiry(definition, failures)
	_check_hostile_privacy_and_presentation(definition, entry, failures)

func _check_command_terminal(definition: Dictionary, command_id: String, outcome: String, after_begin: bool, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var state := _initial(definition, "%s_%s" % [sid,outcome])
	if after_begin:
		var begun := _apply(state, definition, str(_objective_commands(definition)[0]), "%s:%s:begin" % [sid,outcome])
		state = _dict(begun.get("state", {}))
	if not _round_trip(state, definition): failures.append("%s %s pre-branch save/load drifted." % [sid,outcome])
	var result := _apply(state, definition, command_id, "%s:%s" % [sid,outcome])
	var terminal := _dict(result.get("state", {}))
	if not bool(result.get("ok", false)) or str(terminal.get("status", "")) != "aftermath" or not _array(terminal.get("resolved_outcomes", [])).has(outcome): failures.append("%s %s route failed: %s" % [sid,outcome,JSON.stringify(result.get("errors", []))])
	if not _round_trip(terminal, definition): failures.append("%s %s post-branch save/load drifted." % [sid,outcome])

func _check_interruption(definition: Dictionary, phase_id: String, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var state := _initial(definition, "%s_interrupt_%s" % [sid,phase_id])
	if phase_id == "work": state = _dict(_apply(state, definition, str(_objective_commands(definition)[0]), "%s:interrupt:begin" % sid).get("state", {}))
	if not _round_trip(state, definition): failures.append("%s interruption at %s pre-branch save/load drifted." % [sid,phase_id])
	var fact := Runtime.fact("travel_departed", "travel", "package_a_runtime_node", "%s:%s:depart" % [sid,phase_id], 1, 1, {"source_id":sid,"target_id":"world_map","travel_kind":"ordinary"})
	var enqueued := Runtime.enqueue_fact(state, definition, fact)
	var flushed := Runtime.flush_facts(_dict(enqueued.get("state", {})), definition, 1)
	var interrupted := _dict(flushed.get("state", {}))
	if not bool(enqueued.get("ok", false)) or not bool(flushed.get("ok", false)) or str(interrupted.get("status", "")) != "aftermath" or not _array(interrupted.get("resolved_outcomes", [])).has("interrupted"): failures.append("%s interruption at %s failed." % [sid,phase_id])
	if not _round_trip(interrupted, definition): failures.append("%s interruption at %s post-branch save/load drifted." % [sid,phase_id])

func _check_public_fact(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var evidence := _dict(_dict(entry.get("authoring", {})).get("seed_evidence", {}))
	var fact_type := str(evidence.get("public_fact_type", ""))
	var producer := str(evidence.get("public_fact_producer", ""))
	var predicate_value: Variant = JSON.parse_string(str(evidence.get("public_payload_predicate", "{}")))
	var payload := _valid_payload(fact_type)
	payload.merge(_dict(predicate_value), true)
	var state := _initial(definition, "%s_public" % sid)
	if not _round_trip(state, definition): failures.append("%s public fact pre-branch save/load drifted." % sid)
	var fact_id := "%s:public:1" % sid
	var fact := Runtime.fact(fact_type, producer, "package_a_runtime_node", fact_id, 1, 1, payload)
	var enqueued := Runtime.enqueue_fact(state, definition, fact)
	var duplicate_queued := Runtime.enqueue_fact(_dict(enqueued.get("state", {})), definition, fact)
	var flushed := Runtime.flush_facts(_dict(duplicate_queued.get("state", {})), definition, 1)
	var public_state := _dict(flushed.get("state", {}))
	if not bool(enqueued.get("ok", false)) or not bool(duplicate_queued.get("duplicate", false)) or not bool(flushed.get("ok", false)) or _array(public_state.get("fact_receipts", [])).count(fact_id) != 1 or str(public_state.get("status", "")) != "aftermath" or not _array(public_state.get("resolved_outcomes", [])).has("public"): failures.append("%s public fact did not route exactly once to material play: enqueue=%s duplicate_queue=%s flush=%s receipts=%s status=%s outcomes=%s errors=%s" % [sid,enqueued.get("ok",false),duplicate_queued.get("duplicate",false),flushed.get("ok",false),JSON.stringify(public_state.get("fact_receipts",[])),public_state.get("status",""),JSON.stringify(public_state.get("resolved_outcomes",[])),JSON.stringify(flushed.get("errors",[]))])
	var projected_field := str(evidence.get("public_projected_field", ""))
	var selector := str(evidence.get("public_projected_payload_key", ""))
	var projected: Variant = _dict(public_state.get("local_state", {})).get(projected_field)
	if projected != payload.get(selector): failures.append("%s public fact projection did not expose %s exactly." % [sid,projected_field])
	if not _round_trip(public_state, definition): failures.append("%s public fact post-branch save/load drifted." % sid)
	var conflict := fact.duplicate(true)
	conflict["payload"] = payload.duplicate(true)
	conflict.payload[selector] = _conflicting_value(payload.get(selector))
	var queued_state := _dict(enqueued.get("state", {}))
	var before := JSON.stringify(queued_state)
	var rejected := Runtime.enqueue_fact(queued_state, definition, conflict)
	if bool(rejected.get("ok", false)) or JSON.stringify(_dict(rejected.get("state", {}))) != before: failures.append("%s public fact receipt conflict was not atomically rejected." % sid)
	if sid == "back_alley_street_craps" and (float(projected) <= 0.0 or _array(JSON.parse_string(str(evidence.get("accepted_public_facts", "[]")))).size() < 8): failures.append("Street Craps did not prove accepted public vocabulary and positive exactly-once stake recovery.")

func _check_reentry_expiry(definition: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var partial := _dict(_apply(_initial(definition, "%s_partial" % sid), definition, str(_objective_commands(definition)[0]), "%s:partial" % sid).get("state", {}))
	var partial_reentry := Runtime.apply_reentry(JSON.parse_string(JSON.stringify(partial)), definition, "%s_partial_visit" % sid, _host_semantics())
	if not bool(partial_reentry.get("ok", false)) or str(_dict(partial_reentry.get("state", {})).get("phase_id", "")) != "work": failures.append("%s partial reentry did not resume work." % sid)
	var terminal := _dict(_apply(partial, definition, str(_objective_commands(definition)[1]), "%s:terminal" % sid).get("state", {}))
	var terminal_reentry := Runtime.apply_reentry(terminal, definition, "%s_terminal_visit" % sid, _host_semantics())
	if not bool(terminal_reentry.get("ok", false)) or str(_dict(terminal_reentry.get("state", {})).get("status", "")) != "aftermath": failures.append("%s terminal reentry lost aftermath." % sid)
	var expiry := Runtime.apply_expiry(_initial(definition, "%s_expiry" % sid), definition, "night_end", 1)
	var expired := _dict(expiry.get("state", {}))
	var expired_reentry := Runtime.apply_reentry(expired, definition, "%s_expired_visit" % sid, _host_semantics())
	if not bool(expiry.get("ok", false)) or not bool(expiry.get("expired", false)) or str(expired.get("status", "")) != "aftermath" or not bool(expired_reentry.get("ok", false)): failures.append("%s expiry/cleanup/reentry failed." % sid)

func _check_hostile_privacy_and_presentation(definition: Dictionary, entry: Dictionary, failures: Array) -> void:
	var sid := str(definition.get("id", ""))
	var state := _initial(definition, "%s_hostile" % sid)
	var valid := _command(state, definition, str(_objective_commands(definition)[0]), "%s:receipt" % sid)
	var accepted := Runtime.apply_command(state, definition, valid)
	var accepted_state := _dict(accepted.get("state", {}))
	var replay := Runtime.apply_command(accepted_state, definition, valid)
	var conflict := valid.duplicate(true)
	conflict["command_id"] = "ignore_sequence"
	var before := JSON.stringify(accepted_state)
	var rejected := Runtime.apply_command(accepted_state, definition, conflict)
	if not bool(accepted.get("ok", false)) or not bool(replay.get("replayed", false)) or bool(rejected.get("ok", false)) or JSON.stringify(_dict(rejected.get("state", {}))) != before: failures.append("%s command replay/conflict authority failed." % sid)
	var hostile := valid.duplicate(true)
	hostile["expected_phase"] = "wrong_phase"
	var hostile_result := Runtime.apply_command(state, definition, hostile)
	if bool(hostile_result.get("ok", false)) or JSON.stringify(_dict(hostile_result.get("state", {}))) != JSON.stringify(state): failures.append("%s hostile command partially committed." % sid)
	var projection := Runtime.public_projection(state, definition)
	for forbidden in ["command_fingerprints","fact_fingerprints","seed_token","command_results","cleanup_fingerprints"]:
		if projection.has(forbidden): failures.append("%s leaked hidden %s." % [sid,forbidden])
	if JSON.stringify(projection) != JSON.stringify(Runtime.public_projection(JSON.parse_string(JSON.stringify(state)), definition)): failures.append("%s deterministic platform projection parity drifted." % sid)
	var interactions := _dict(_dict(projection.get("semantic_state", {})).get("interactions", {}))
	if interactions.size() < 2: failures.append("%s lacks independent task and safe-exit presentation targets." % sid)
	for interaction_value in interactions.values():
		var interaction := _dict(interaction_value)
		var hit := _dict(interaction.get("hit_bounds", {}))
		if int(hit.get("w",0)) < 44 or int(hit.get("h",0)) < 44 or str(interaction.get("label","")).is_empty() or str(interaction.get("prompt","")).is_empty() or str(interaction.get("non_color_state","")).is_empty(): failures.append("%s target failed accessibility/hit/obstruction proof." % sid)
	var captures := _array(_dict(entry.get("authoring", {})).get("capture_ids", []))
	for suffix in ["arrival","work","success","failure","ignored","refused","interrupted","partial_revisit","terminal_revisit","reduced_motion","small_screen","hit_overlay","obstruction"]:
		if not captures.has("%s_%s" % [sid,suffix]): failures.append("%s lacks package-scoped %s presentation evidence." % [sid,suffix])
	var normal := Runtime.drain_transitions(state, definition, false)
	var reduced := Runtime.drain_transitions(state, definition, true)
	if not bool(normal.get("ok", false)) or not bool(reduced.get("ok", false)) or _array(normal.get("transitions", [])).size() != _array(reduced.get("transitions", [])).size(): failures.append("%s reduced-motion parity failed." % sid)

func _initial(definition: Dictionary, seed: String) -> Dictionary:
	return Runtime.initial_state(definition, "package_a_runtime_node", seed, _host_semantics())

func _apply(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	return Runtime.apply_command(state, definition, _command(state, definition, command_id, receipt_id))

func _command(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var sid := str(definition.get("id", ""))
	var phase_id := str(state.get("phase_id", ""))
	var object_id := str(_objective_commands(definition)[0])
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id: object_id = str(interaction.get("stable_object_id", object_id))
	var descriptor := Runtime._command_descriptor(state, definition, "scenario", object_id, command_id)
	return Runtime.command(command_id, "package_a_runtime_node", phase_id, receipt_id, {}, "scenario", object_id, str(descriptor.get("action_origin_owner_namespace","scenario")), str(descriptor.get("action_origin_stable_object_id",object_id)), str(descriptor.get("action_origin_receipt_key","")), str(descriptor.get("action_origin_boundary_id","")), str(descriptor.get("action_origin_fingerprint","")))

func _objective_commands(definition: Dictionary) -> Array:
	var result: Array = []
	for objective_value in _array(_dict(definition.get("sequence", {})).get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			if str(_dict(step_value).get("kind", "")) == "command": result.append(str(_dict(step_value).get("command_id", "")))
	return result

func _round_trip(state: Dictionary, definition: Dictionary) -> bool:
	var restored := Runtime.normalize_state(JSON.parse_string(JSON.stringify(state)), definition, _host_semantics())
	return str(restored.get("phase_id","")) == str(state.get("phase_id","")) and str(restored.get("status","")) == str(state.get("status","")) and _array(restored.get("command_receipts",[])) == _array(state.get("command_receipts",[])) and _array(restored.get("fact_receipts",[])) == _array(state.get("fact_receipts",[])) and _array(_dict(restored.get("semantic_state",{})).get("operation_receipts",[])) == _array(_dict(state.get("semantic_state",{})).get("operation_receipts",[]))

func _definition(entry: Dictionary) -> Dictionary:
	var sid := str(entry.get("scenario_id", ""))
	return {"id":sid,"archetype_id":_archetype(sid),"sequence":_dict(entry.get("sequence", {})),"sequence_package_id":"env06_7_shops_streets","sequence_handler_pack":"corner_store_delivery","sequence_renderer_id":"corner_store_delivery","sequence_authoring":_dict(entry.get("authoring", {}))}

func _valid_payload(fact_type: String) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id":"craps","action_id":"street_craps_disperse","won":false,"ended":true,"bankroll_delta":25,"chips_delta":0,"applied_heat_delta":0}
		"service_result": return {"kind":"scenario_service","service_id":"service","ok":true,"action_id":"resolved"}
		"sweep_changed": return {"action_index":3,"node_id":"back_alley","segment_index":1,"active":true}
		"heat_changed": return {"previous":10,"current":20,"applied_delta":10,"source":"corner_store_surveillance"}
		"town_transition": return {"action_index":3,"weather":"rain","day_type":"weekday","happening_ids":[]}
	return {}

func _conflicting_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL: return not bool(value)
		TYPE_INT, TYPE_FLOAT: return value + 1
		TYPE_STRING: return "%s_conflict" % value
	return "conflict"

func _host_semantics() -> Dictionary:
	return _active_host.duplicate(true)


func _production_host(definition: Dictionary, failures: Array) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var archetype_id := str(definition.get("archetype_id", ""))
	var archetype: Dictionary = _library.environment_archetype(archetype_id)
	if archetype.is_empty():
		failures.append("%s production ContentLibrary lacks archetype %s." % [scenario_id, archetype_id])
		return {}
	var composition_key := "%s::%s" % [archetype_id, scenario_id]
	var composition: Dictionary = _composition_cache.get(composition_key, {})
	if composition.is_empty():
		var production_scenario := definition
		for candidate_value in _array(_library.environment_scenarios.get(archetype_id, [])):
			var candidate := _dict(candidate_value)
			if str(candidate.get("id", "")) == scenario_id:
				production_scenario = candidate.duplicate(true)
				production_scenario["sequence"] = _dict(definition.get("sequence", {})).duplicate(true)
				for key in ["sequence_package_id", "sequence_handler_pack", "sequence_renderer_id", "sequence_authoring"]:
					if definition.has(key): production_scenario[key] = definition.get(key)
				break
		var rng: Variant = RngStreamScript.new()
		rng.configure(abs(archetype_id.hash()) + 1)
		var environment: Variant = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, _library, {}, production_scenario)
		var environment_data: Dictionary = environment.call("to_dict")
		var sealed: Dictionary = SemanticInventory.for_instance(environment_data, _library, [], [])
		var inventory_errors: Array = SemanticInventory.validate_instance_binding(sealed, environment_data)
		var exact: Dictionary = SemanticInventory.exact_collections(sealed)
		if not inventory_errors.is_empty() or exact.is_empty():
			failures.append("%s production environment composition did not seal: %s" % [scenario_id, JSON.stringify(inventory_errors)])
			return {}
		composition = {
			"exact": exact,
			"event_choices": SemanticInventory.event_choice_index(_array(environment_data.get("event_ids", [])), _library),
			"schema_version": int(sealed.get("schema_version", 0)),
			"digest": str(sealed.get("digest", "")),
			"environment_id": str(environment_data.get("id", "")),
		}
		_composition_cache[composition_key] = composition
	var exact: Dictionary = composition.get("exact", {})
	var declared := _dict(_dict(definition.get("sequence", {})).get("declared_targets", {}))
	var bounded: Dictionary = {}
	for collection in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		bounded[collection] = []
		for identity_value in _array(declared.get(collection, [])):
			var identity := str(identity_value)
			if not _array(exact.get(collection, [])).has(identity):
				failures.append("%s declared %s is absent from production-composed %s." % [scenario_id, identity, archetype_id])
			else:
				bounded[collection].append(identity)
	bounded["event_choices"] = _dict(composition.get("event_choices", {}))
	return {
		"target_inventory": bounded,
		"inventory_schema_version": int(composition.get("schema_version", 0)),
		"inventory_digest": str(composition.get("digest", "")),
		"production_inventory_digest": str(composition.get("digest", "")),
		"environment_id": str(composition.get("environment_id", "")),
		"inventory_errors": [],
		"base_interactions": [],
		"event_choices": _dict(composition.get("event_choices", {})),
	}

func _archetype(scenario_id: String) -> String:
	if scenario_id.begins_with("corner_store_"): return "corner_store"
	if scenario_id.begins_with("back_alley_"): return "back_alley"
	return "pawn_shop"

func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("ENV06_7_PACKAGE_A_EXECUTABLE PASS ids=12 routes=66 public_facts=11")
		quit(0)
	else:
		for failure in failures: printerr("ENV06_7_PACKAGE_A_FAIL %s" % failure)
		quit(1)

func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []

func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
