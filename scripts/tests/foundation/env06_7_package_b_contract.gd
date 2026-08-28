extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SemanticInventory := preload("res://scripts/core/environment_semantic_inventory.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"
const EXPECTED_IDS := [
	"motel_conventioneers", "motel_stakeout", "motel_weekly_rates", "motel_wedding_overflow",
	"gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift",
	"gas_station_road_crew_payday", "gas_station_storm_shelter",
	"beach_bonfire_night", "beach_storm_coming", "beach_festival_weekend",
]
var _library: Variant = null
var _composition_cache: Dictionary = {}


func _init() -> void:
	var failures: Array = []
	_library = ContentLibraryScript.new()
	_library.load(false)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish(["Package B JSON did not parse as an object."])
		return
	var package := parsed as Dictionary
	if str(package.get("package_id", "")) != "env06_7_roadside_shelter": failures.append("Package id changed.")
	if str(package.get("handler_pack", "")) != "roadside_shelter" or str(package.get("renderer_id", "")) != "roadside_shelter": failures.append("Package extensions changed.")
	var rows: Array = package.get("scenarios", [])
	var actual_ids: Array = []
	var definitions: Array = []
	var target_inventories: Dictionary = {}
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			failures.append("Scenario row is not an object.")
			continue
		var row := row_value as Dictionary
		var scenario_id := str(row.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var definition := {"id": scenario_id, "archetype_id": _archetype_id(scenario_id), "sequence": row.get("sequence", {})}
		definitions.append(definition)
		var host := _production_host(definition, failures)
		var target_inventory: Dictionary = host.get("target_inventory", {})
		target_inventories[scenario_id] = target_inventory
		var errors := Schema.validate_definition(definition, Registry, target_inventory)
		for error_value in errors: failures.append("%s: %s" % [scenario_id, str(error_value)])
		_check_physical_sequence(scenario_id, row, failures)
		if errors.is_empty(): _check_runtime_trace(scenario_id, definition, host, failures)
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package B ids differ from the fixed 12-id inventory.")
	var uniqueness := Schema.catalog_uniqueness_report(definitions, EXPECTED_IDS.size(), Registry, {}, target_inventories)
	for failure_value in uniqueness.get("failures", []): failures.append("uniqueness: %s" % str(failure_value))
	_finish(failures)


func _check_physical_sequence(scenario_id: String, row: Dictionary, failures: Array) -> void:
	var sequence: Dictionary = row.get("sequence", {})
	var phases: Array = (sequence.get("phase_graph", {}) as Dictionary).get("phases", [])
	if phases.size() < 4: failures.append("%s has fewer than arrival, two physical beats, and decision." % scenario_id)
	var changed_objects: Dictionary = {}
	var command_boundaries: Dictionary = {}
	var safe_exit := false
	for phase_value in phases:
		var phase := phase_value as Dictionary
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in phase.get(family, []):
				var operation := operation_value as Dictionary
				changed_objects["%s::%s" % [family, str(operation.get("stable_object_id", ""))]] = true
		for operation_value in phase.get("interaction_ops", []):
			var operation := operation_value as Dictionary
			var interaction: Dictionary = operation.get("interaction", {})
			if bool(interaction.get("safe_exit", false)): safe_exit = true
		for branch_value in phase.get("branches", []):
			var condition: Dictionary = (branch_value as Dictionary).get("condition", {})
			if str(condition.get("type", "")) == "command": command_boundaries[str(condition.get("command_id", ""))] = true
	if changed_objects.size() < 4: failures.append("%s changes fewer than four physical object/actor identities." % scenario_id)
	if command_boundaries.size() < 4: failures.append("%s exposes fewer than four distinct command boundaries." % scenario_id)
	if not safe_exit: failures.append("%s does not preserve a semantic safe exit." % scenario_id)
	var aftermath: Dictionary = sequence.get("aftermath", {})
	if aftermath.size() != 5: failures.append("%s does not implement its five success/failure/refuse/interruption aftermaths." % scenario_id)
	var authoring: Dictionary = row.get("authoring", {})
	if (authoring.get("capture_ids", []) as Array).size() < phases.size() + aftermath.size() + 5: failures.append("%s capture matrix is incomplete." % scenario_id)
	if (authoring.get("world_connections", []) as Array).size() < 3: failures.append("%s lacks a material world-system connection record." % scenario_id)


func _check_runtime_trace(scenario_id: String, definition: Dictionary, host: Dictionary, failures: Array) -> void:
	var state := Runtime.initial_state(definition, "%s_node" % scenario_id, "%s_trace" % scenario_id, host)
	if str(state.get("status", "")) != Runtime.STATUS_ACTIVE:
		failures.append("%s did not initialize an active runtime trace: %s" % [scenario_id, JSON.stringify(state.get("errors", []))])
		return
	var command_serial := 0
	while str(state.get("phase_id", "")) != "decision" and command_serial < 12:
		var phase := Schema.phase(definition, str(state.get("phase_id", "")))
		var branches: Array = phase.get("branches", [])
		if branches.is_empty():
			failures.append("%s runtime trace reached a phase without branches." % scenario_id)
			return
		var condition: Dictionary = (branches[0] as Dictionary).get("condition", {})
		var command_id := str(condition.get("command_id", ""))
		var command := _runtime_command(state, definition, command_id, "%s:trace:%d" % [scenario_id, command_serial])
		var applied := Runtime.apply_command(state, definition, command, {"available_funds": 0})
		if not bool(applied.get("ok", false)):
			failures.append("%s runtime command %s failed: %s" % [scenario_id, command_id, JSON.stringify(applied.get("errors", []))])
			return
		state = applied.get("state", {})
		if JSON.stringify(Runtime.normalize_state(state, definition)) != JSON.stringify(state):
			failures.append("%s save normalization changed phase %s." % [scenario_id, str(state.get("phase_id", ""))])
			return
		command_serial += 1
	if str(state.get("phase_id", "")) != "decision":
		failures.append("%s runtime trace did not reach the decision phase." % scenario_id)
		return
	var terminal_phase := Schema.phase(definition, "decision")
	for terminal_index in range(4):
		var branch := (terminal_phase.get("branches", []) as Array)[terminal_index] as Dictionary
		var command_id := str((branch.get("condition", {}) as Dictionary).get("command_id", ""))
		var branch_state := state.duplicate(true)
		if not _round_trip(branch_state, definition, host): failures.append("%s terminal branch %s changed before save/load." % [scenario_id, command_id])
		var command := _runtime_command(branch_state, definition, command_id, "%s:terminal:%d" % [scenario_id, terminal_index])
		var applied := Runtime.apply_command(branch_state, definition, command, {"available_funds": 0})
		if not bool(applied.get("ok", false)) or str((applied.get("state", {}) as Dictionary).get("status", "")) != Runtime.STATUS_AFTERMATH:
			failures.append("%s terminal command %s failed: %s" % [scenario_id, command_id, JSON.stringify(applied.get("errors", []))])
			continue
		var final_state: Dictionary = applied.get("state", {})
		if not _round_trip(final_state, definition, host): failures.append("%s terminal branch %s changed after save/load." % [scenario_id, command_id])
		var replay := Runtime.apply_command(final_state, definition, command, {"available_funds": 0})
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(final_state):
			failures.append("%s terminal receipt %s did not replay exactly once." % [scenario_id, command_id])
		var conflict := command.duplicate(true)
		conflict["command_id"] = "%s_conflict" % command_id
		if bool(Runtime.apply_command(final_state, definition, conflict, {"available_funds": 0}).get("ok", true)):
			failures.append("%s accepted conflicting reuse of terminal receipt %s." % [scenario_id, command_id])
	var interrupt_branch := (terminal_phase.get("branches", []) as Array)[4] as Dictionary
	if not _round_trip(state, definition, host): failures.append("%s interruption branch changed before save/load." % scenario_id)
	var fact_type := str((interrupt_branch.get("condition", {}) as Dictionary).get("fact_type", ""))
	var fact_boundary := int(state.get("boundary_serial", 0)) + 1
	var fact := Runtime.fact(fact_type, _fact_producer(fact_type), str(state.get("node_id", "")), "%s_interrupt_fact" % scenario_id, 1, fact_boundary, _fact_payload(fact_type, state))
	var queued := Runtime.enqueue_fact(state, definition, fact)
	if not bool(queued.get("ok", false)):
		failures.append("%s interruption fact %s did not enqueue: %s" % [scenario_id, fact_type, JSON.stringify(queued.get("errors", []))])
		return
	var duplicate := Runtime.enqueue_fact(queued.get("state", {}), definition, fact)
	if not bool(duplicate.get("ok", false)) or not bool(duplicate.get("duplicate", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(queued.get("state", {})):
		failures.append("%s interruption fact did not deduplicate before its safe boundary." % scenario_id)
	var conflicting_fact := fact.duplicate(true)
	conflicting_fact["producer_serial"] = 2
	if bool(Runtime.enqueue_fact(queued.get("state", {}), definition, conflicting_fact).get("ok", true)):
		failures.append("%s accepted conflicting reuse of its interruption fact id." % scenario_id)
	var flushed := Runtime.flush_facts(queued.get("state", {}), definition, fact_boundary)
	if fact_type == "world_boundary" and bool(flushed.get("ok", false)) and str((flushed.get("state", {}) as Dictionary).get("status", "")) == Runtime.STATUS_ACTIVE:
		var second_boundary := fact_boundary + 1
		var second_fact := Runtime.fact(fact_type, "scenario", str(state.get("node_id", "")), "%s_interrupt_fact_after_grace" % scenario_id, 2, second_boundary, _fact_payload(fact_type, state))
		var second_queued := Runtime.enqueue_fact(flushed.get("state", {}), definition, second_fact)
		flushed = Runtime.flush_facts(second_queued.get("state", {}), definition, second_boundary) if bool(second_queued.get("ok", false)) else second_queued
	if not bool(flushed.get("ok", false)) or str((flushed.get("state", {}) as Dictionary).get("status", "")) != Runtime.STATUS_AFTERMATH:
		failures.append("%s interruption fact %s did not resolve its physical aftermath: %s" % [scenario_id, fact_type, JSON.stringify(flushed.get("errors", []))])
	elif not _round_trip(flushed.get("state", {}), definition, host):
		failures.append("%s interruption branch changed after save/load." % scenario_id)
	_check_lifecycle_rollback_observers(scenario_id, definition, host, state, failures)


func _check_lifecycle_rollback_observers(scenario_id: String, definition: Dictionary, host: Dictionary, decision_state: Dictionary, failures: Array) -> void:
	var initial := Runtime.initial_state(definition, "%s_lifecycle_node" % scenario_id, "%s_lifecycle_seed" % scenario_id, host)
	if str(initial.get("status", "")) != Runtime.STATUS_ACTIVE: return
	var initial_phase := Schema.phase(definition, str(initial.get("phase_id", "")))
	var first_branch: Dictionary = (initial_phase.get("branches", []) as Array)[0]
	var first_command_id := str((first_branch.get("condition", {}) as Dictionary).get("command_id", ""))
	var partial_result := Runtime.apply_command(initial, definition, _runtime_command(initial, definition, first_command_id, "%s:partial" % scenario_id), {"available_funds": 0})
	var partial: Dictionary = partial_result.get("state", {})
	var partial_reentry := Runtime.apply_reentry(partial, definition, "%s_partial_visit" % scenario_id, host)
	if not bool(partial_result.get("ok", false)) or not bool(partial_reentry.get("ok", false)) or str((partial_reentry.get("state", {}) as Dictionary).get("status", "")) != Runtime.STATUS_ACTIVE:
		failures.append("%s partial reentry failed." % scenario_id)
	elif not _round_trip(partial_reentry.get("state", {}), definition, host): failures.append("%s partial reentry save/load drifted." % scenario_id)
	var terminal_phase := Schema.phase(definition, "decision")
	var terminal_branch: Dictionary = (terminal_phase.get("branches", []) as Array)[0]
	var terminal_command_id := str((terminal_branch.get("condition", {}) as Dictionary).get("command_id", ""))
	var terminal_result := Runtime.apply_command(decision_state, definition, _runtime_command(decision_state, definition, terminal_command_id, "%s:terminal_reentry" % scenario_id), {"available_funds": 0})
	var terminal: Dictionary = terminal_result.get("state", {})
	var terminal_reentry := Runtime.apply_reentry(terminal, definition, "%s_terminal_visit" % scenario_id, host)
	if not bool(terminal_result.get("ok", false)) or not bool(terminal_reentry.get("ok", false)) or str((terminal_reentry.get("state", {}) as Dictionary).get("status", "")) != Runtime.STATUS_AFTERMATH:
		failures.append("%s terminal reentry failed." % scenario_id)
	elif not _round_trip(terminal_reentry.get("state", {}), definition, host): failures.append("%s terminal reentry save/load drifted." % scenario_id)
	var expiry: Dictionary = (definition.get("sequence", {}) as Dictionary).get("expiry", {})
	var expiry_state := initial
	var expiry_result: Dictionary = {}
	for serial in range(1, maxi(1, int(expiry.get("after", 1))) + 1):
		expiry_result = Runtime.apply_expiry(expiry_state, definition, str(expiry.get("boundary", "")), serial)
		if not bool(expiry_result.get("ok", false)): break
		expiry_state = expiry_result.get("state", {})
	if not bool(expiry_result.get("ok", false)) or not bool(expiry_result.get("expired", false)):
		failures.append("%s expiry policy did not execute." % scenario_id)
	else:
		var expired_reentry := Runtime.apply_reentry(expiry_state, definition, "%s_expired_visit" % scenario_id, host)
		if not bool(expired_reentry.get("ok", false)) or not _round_trip(expired_reentry.get("state", {}), definition, host): failures.append("%s expiry cleanup/reentry save-load failed." % scenario_id)
		var tampered_cleanup := definition.duplicate(true)
		var cleanup_ops: Array = (((tampered_cleanup.get("sequence", {}) as Dictionary).get("cleanup", {}) as Dictionary).get("operations", []) as Array)
		if not cleanup_ops.is_empty():
			(cleanup_ops[0] as Dictionary)["receipt_id"] = "%s_forged_cleanup" % scenario_id
			var before_cleanup := JSON.stringify(expiry_state)
			var cleanup_injection := Runtime._apply_cleanup(expiry_state, tampered_cleanup, "forged")
			if bool(cleanup_injection.get("ok", false)) or JSON.stringify(cleanup_injection.get("state", {})) != before_cleanup: failures.append("%s cleanup/finalization injection did not roll back exactly." % scenario_id)
	var hostile_command := _runtime_command(initial, definition, first_command_id, "%s:hostile_operation" % scenario_id)
	hostile_command["expected_phase"] = "forged_phase"
	var before_initial := JSON.stringify(initial)
	var hostile_result := Runtime.apply_command(initial, definition, hostile_command, {"available_funds": 0})
	if bool(hostile_result.get("ok", false)) or JSON.stringify(hostile_result.get("state", {})) != before_initial: failures.append("%s operation injection did not roll back exactly." % scenario_id)
	var fact_type := str((((terminal_phase.get("branches", []) as Array)[4] as Dictionary).get("condition", {}) as Dictionary).get("fact_type", ""))
	var producer := _fact_producer(fact_type)
	var wrong_producer := "game" if producer != "game" else "scenario"
	var hostile_fact := Runtime.fact(fact_type, wrong_producer, str(initial.get("node_id", "")), "%s:hostile_fact" % scenario_id, 1, 1, _fact_payload(fact_type, initial))
	var hostile_fact_result := Runtime.enqueue_fact(initial, definition, hostile_fact)
	if bool(hostile_fact_result.get("ok", false)) or JSON.stringify(hostile_fact_result.get("state", {})) != before_initial: failures.append("%s fact injection did not roll back exactly." % scenario_id)
	var projection := Runtime.public_projection(initial, definition)
	for forbidden in ["seed_token", "command_fingerprints", "fact_fingerprints", "command_results", "cleanup_fingerprints"]:
		if projection.has(forbidden): failures.append("%s public observer leaked %s." % [scenario_id, forbidden])
	var hidden_a := initial.duplicate(true)
	var hidden_b := initial.duplicate(true)
	hidden_a["seed_token"] = "hidden_a"
	hidden_b["seed_token"] = "hidden_b"
	hidden_a["command_fingerprints"] = {"private": "a"}
	hidden_b["command_fingerprints"] = {"private": "b"}
	if Runtime.content_fingerprint(Runtime.public_projection(hidden_a, definition)) != Runtime.content_fingerprint(Runtime.public_projection(hidden_b, definition)): failures.append("%s paired hidden-state observers diverged." % scenario_id)
	var native_round_trip: Variant = JSON.parse_string(JSON.stringify(projection))
	if Runtime.content_fingerprint(projection) != Runtime.content_fingerprint(native_round_trip): failures.append("%s native/Web canonical projection parity drifted." % scenario_id)
	var normal := Runtime.drain_transitions(initial, definition, false)
	var reduced := Runtime.drain_transitions(initial, definition, true)
	if not bool(normal.get("ok", false)) or not bool(reduced.get("ok", false)) or (normal.get("transitions", []) as Array).size() != (reduced.get("transitions", []) as Array).size(): failures.append("%s transition liveness/reduced-motion parity failed." % scenario_id)
	var counters: Dictionary = (partial.get("performance_counters", {}) as Dictionary)
	if int(counters.get("commands_applied", 0)) < 1 or int(counters.get("transitions_prepared", 0)) < 1: failures.append("%s runtime liveness counters did not advance." % scenario_id)


func _round_trip(state_value: Variant, definition: Dictionary, host: Dictionary) -> bool:
	if typeof(state_value) != TYPE_DICTIONARY: return false
	var state := state_value as Dictionary
	var restored := Runtime.normalize_state(JSON.parse_string(JSON.stringify(state)), definition, host)
	return Runtime.content_fingerprint(restored) == Runtime.content_fingerprint(state) and Runtime.content_fingerprint(Runtime.public_projection(restored, definition)) == Runtime.content_fingerprint(Runtime.public_projection(state, definition))


func _runtime_command(state: Dictionary, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var origin := _find_action_origin(state, command_id)
	var descriptor := Runtime._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), command_id, {})
	return Runtime.command(
		command_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), receipt_id, {},
		str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")),
		str(descriptor.get("action_origin_owner_namespace", "")),
		str(descriptor.get("action_origin_stable_object_id", "")),
		str(descriptor.get("action_origin_receipt_key", "")),
		str(descriptor.get("action_origin_boundary_id", "")),
		str(descriptor.get("action_origin_fingerprint", "")),
	)


func _find_action_origin(state: Dictionary, command_id: String) -> Dictionary:
	var interactions: Dictionary = (state.get("semantic_state", {}) as Dictionary).get("interactions", {})
	for interaction_value in interactions.values():
		var interaction := interaction_value as Dictionary
		if not bool(interaction.get("enabled", false)): continue
		for action_value in interaction.get("available_actions", []):
			if str((action_value as Dictionary).get("id", "")) == command_id:
				return {"owner_namespace": str(interaction.get("owner_namespace", "")), "stable_object_id": str(interaction.get("stable_object_id", ""))}
	return {}


func _archetype_id(scenario_id: String) -> String:
	if scenario_id.begins_with("motel_"): return "motel"
	if scenario_id.begins_with("gas_station_"): return "gas_station_casino"
	if scenario_id.begins_with("beach_"): return "beach"
	return ""


func _production_host(definition: Dictionary, failures: Array) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var archetype_id := str(definition.get("archetype_id", ""))
	var archetype: Dictionary = _library.environment_archetype(archetype_id)
	if archetype.is_empty():
		failures.append("%s production ContentLibrary lacks archetype %s." % [scenario_id, archetype_id])
		return {}
	var composition: Dictionary = _composition_cache.get(archetype_id, {})
	if composition.is_empty():
		var rng: Variant = RngStreamScript.new()
		rng.configure(abs(archetype_id.hash()) + 1)
		var environment_class: Variant = EnvironmentInstanceScript
		var environment: Variant = environment_class.from_archetype(archetype, 1, rng, _library, {}, definition)
		var environment_data: Dictionary = environment.call("to_dict")
		var sealed: Dictionary = SemanticInventory.for_instance(environment_data, _library, [], [])
		var inventory_errors: Array = SemanticInventory.validate_instance_binding(sealed, environment_data)
		var exact: Dictionary = SemanticInventory.exact_collections(sealed)
		if not inventory_errors.is_empty() or exact.is_empty():
			failures.append("%s production environment composition did not seal: %s" % [scenario_id, JSON.stringify(inventory_errors)])
			return {}
		composition = {"exact": exact, "schema_version": int(sealed.get("schema_version", 0)), "digest": str(sealed.get("digest", "")), "environment_id": str(environment_data.get("id", ""))}
		_composition_cache[archetype_id] = composition
	var exact: Dictionary = composition.get("exact", {})
	var declared: Dictionary = (definition.get("sequence", {}) as Dictionary).get("declared_targets", {})
	var bounded: Dictionary = {}
	for collection in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		bounded[collection] = []
		for identity_value in declared.get(collection, []):
			var identity := str(identity_value)
			if not (exact.get(collection, []) as Array).has(identity):
				failures.append("%s declared %s is absent from production-composed %s." % [scenario_id, identity, archetype_id])
			else:
				bounded[collection].append(identity)
	bounded["event_choices"] = exact.get("event_choices", {})
	return {"target_inventory": bounded, "inventory_schema_version": int(composition.get("schema_version", 0)), "inventory_digest": str(composition.get("digest", "")), "production_inventory_digest": str(composition.get("digest", "")), "environment_id": str(composition.get("environment_id", "")), "inventory_errors": [], "base_interactions": [], "event_choices": exact.get("event_choices", {})}


func _fact_producer(fact_type: String) -> String:
	if fact_type.begins_with("travel_"): return "travel"
	if fact_type == "game_result": return "game"
	if fact_type == "service_result": return "service"
	if fact_type == "sweep_changed": return "sweep"
	if fact_type == "town_transition": return "town"
	return "scenario"


func _fact_payload(fact_type: String, state: Dictionary) -> Dictionary:
	match fact_type:
		"travel_departed", "travel_arrived": return {"source_id": "package_b_source", "target_id": "package_b_target", "travel_kind": "road"}
		"game_result": return {"game_id": "package_b_game", "action_id": "settled"}
		"service_result": return {"kind": "rest", "service_id": "package_b_service"}
		"sweep_changed": return {"action_index": 1, "node_id": str(state.get("node_id", "")), "segment_index": 1, "active": true}
		"town_transition": return {"action_index": 1, "weather": "storm", "day_type": "night", "happening_ids": ["package_b_weather"]}
		"world_boundary": return {"amount": 1, "action_index": 1}
	return {}


func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("ENV06_7_PACKAGE_B_CONTRACT_OK ids=12")
		quit(0)
		return
	for failure_value in failures: printerr("ENV06_7_PACKAGE_B_CONTRACT_FAIL: %s" % str(failure_value))
	quit(1)
