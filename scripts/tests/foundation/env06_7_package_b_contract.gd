extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"
const EXPECTED_IDS := [
	"motel_conventioneers", "motel_stakeout", "motel_weekly_rates", "motel_wedding_overflow",
	"gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift",
	"gas_station_road_crew_payday", "gas_station_storm_shelter",
	"beach_bonfire_night", "beach_storm_coming", "beach_festival_weekend",
]
const COMMON_ZONES := [
	"base::zone:background", "base::zone:center", "base::zone:exit_lane", "base::zone:foreground",
	"base::zone:left", "base::zone:right", "base::zone:service_lane",
]


func _init() -> void:
	var failures: Array = []
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
		var definition := {"id": scenario_id, "sequence": row.get("sequence", {})}
		definitions.append(definition)
		target_inventories[scenario_id] = _target_inventory()
		var errors := Schema.validate_definition(definition, Registry, _target_inventory())
		for error_value in errors: failures.append("%s: %s" % [scenario_id, str(error_value)])
		_check_physical_sequence(scenario_id, row, failures)
		if errors.is_empty(): _check_runtime_trace(scenario_id, definition, failures)
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


func _check_runtime_trace(scenario_id: String, definition: Dictionary, failures: Array) -> void:
	var host := {
		"target_inventory": _target_inventory(),
		"inventory_schema_version": 1,
		"inventory_digest": str((definition.get("sequence", {}) as Dictionary).get("sequence_signature", "")),
		"inventory_errors": [], "base_interactions": [], "event_choices": {},
	}
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
		var command := _runtime_command(branch_state, definition, command_id, "%s:terminal:%d" % [scenario_id, terminal_index])
		var applied := Runtime.apply_command(branch_state, definition, command, {"available_funds": 0})
		if not bool(applied.get("ok", false)) or str((applied.get("state", {}) as Dictionary).get("status", "")) != Runtime.STATUS_AFTERMATH:
			failures.append("%s terminal command %s failed: %s" % [scenario_id, command_id, JSON.stringify(applied.get("errors", []))])
			continue
		var final_state: Dictionary = applied.get("state", {})
		var replay := Runtime.apply_command(final_state, definition, command, {"available_funds": 0})
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(final_state):
			failures.append("%s terminal receipt %s did not replay exactly once." % [scenario_id, command_id])
		var conflict := command.duplicate(true)
		conflict["command_id"] = "%s_conflict" % command_id
		if bool(Runtime.apply_command(final_state, definition, conflict, {"available_funds": 0}).get("ok", true)):
			failures.append("%s accepted conflicting reuse of terminal receipt %s." % [scenario_id, command_id])
	var interrupt_branch := (terminal_phase.get("branches", []) as Array)[4] as Dictionary
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


func _target_inventory() -> Dictionary:
	return {"scene_objects": [], "interactions": [], "actors": [], "services": [], "games": [], "routes": [], "anchors": [], "zones": COMMON_ZONES.duplicate(), "event_choices": {}}


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
