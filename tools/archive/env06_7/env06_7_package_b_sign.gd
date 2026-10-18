extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"


func _init() -> void:
	var source := FileAccess.get_file_as_string(PACKAGE_PATH)
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("Package B signer could not parse the package.")
		quit(1)
		return
	var package := (parsed as Dictionary).duplicate(true)
	var scenarios: Array = package.get("scenarios", [])
	for index in range(scenarios.size()):
		var row := (scenarios[index] as Dictionary).duplicate(true)
		row = _repair_safe_exit_branches(row)
		row = _repair_route_required_behaviors(row)
		var definition := {"id": str(row.get("scenario_id", "")), "sequence": (row.get("sequence", {}) as Dictionary).duplicate(true)}
		definition["sequence"]["sequence_signature"] = ""
		definition["sequence"]["sequence_signature"] = Schema.calculated_signature_hash(definition)
		row["sequence"] = definition["sequence"]
		scenarios[index] = row
	package["scenarios"] = scenarios
	var file := FileAccess.open(PACKAGE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Package B signer could not open the package for writing.")
		quit(1)
		return
	file.store_string(JSON.stringify(package, "  ", false) + "\n")
	file.close()
	print("PACKAGE_B_SIGNED count=%d" % scenarios.size())
	quit(0)


func _repair_safe_exit_branches(row: Dictionary) -> Dictionary:
	var repaired := row.duplicate(true)
	var scenario_id := str(repaired.get("scenario_id", ""))
	var sequence := (repaired.get("sequence", {}) as Dictionary).duplicate(true)
	var graph := (sequence.get("phase_graph", {}) as Dictionary).duplicate(true)
	var phases := (graph.get("phases", []) as Array).duplicate(true)
	var refused_outcome := ""
	var refused_objectives: Dictionary = {}
	for phase_value in phases:
		var phase: Dictionary = phase_value
		for branch_value in phase.get("branches", []):
			var branch: Dictionary = branch_value
			if str((branch.get("condition", {}) as Dictionary).get("command_id", "")) == "%s_refuse" % scenario_id:
				refused_outcome = str(branch.get("outcome", ""))
				refused_objectives = (branch.get("objective_outcomes", {}) as Dictionary).duplicate(true)
	if refused_outcome.is_empty():
		return repaired
	for objective_id_value in refused_objectives.keys():
		refused_objectives[objective_id_value] = "ignore"
	var safe_command := "%s_leave_safe" % scenario_id
	for phase_index in range(phases.size()):
		var phase := (phases[phase_index] as Dictionary).duplicate(true)
		var command_branch_count := 0
		for branch_value in phase.get("branches", []):
			if str(((branch_value as Dictionary).get("condition", {}) as Dictionary).get("type", "")) == "command":
				command_branch_count += 1
		if command_branch_count == 0:
			continue
		var branches := (phase.get("branches", []) as Array).duplicate(true)
		var already_present := false
		for branch_value in branches:
			if str(((branch_value as Dictionary).get("condition", {}) as Dictionary).get("command_id", "")) == safe_command:
				already_present = true
				break
		if not already_present:
			var leave_branch := {
				"id": "%s_%s_leave_safe" % [scenario_id, str(phase.get("id", ""))],
				"condition": {"type":"command", "command_id":safe_command},
			}
			if str(phase.get("id", "")) == "decision":
				leave_branch["outcome"] = refused_outcome
				leave_branch["objective_outcomes"] = refused_objectives.duplicate(true)
			else:
				leave_branch["next_phase"] = "decision"
			branches.append(leave_branch)
		phase["branches"] = branches
		phases[phase_index] = phase
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	repaired["sequence"] = sequence
	return repaired


func _repair_route_required_behaviors(row: Dictionary) -> Dictionary:
	var repaired := row.duplicate(true)
	var sequence := (repaired.get("sequence", {}) as Dictionary).duplicate(true)
	var graph := (sequence.get("phase_graph", {}) as Dictionary).duplicate(true)
	var phases := (graph.get("phases", []) as Array).duplicate(true)
	var despawn_ids := {
		"motel_wedding_overflow_wedding_runner": true,
		"gas_station_trucker_convoy_lead_driver": true,
		"gas_station_road_crew_payday_machine_player": true,
		"beach_storm_coming_late_swimmer": true,
		"beach_festival_weekend_lost_child": true,
	}
	for phase_index in range(phases.size()):
		var phase := (phases[phase_index] as Dictionary).duplicate(true)
		var actor_ops := (phase.get("actor_ops", []) as Array).duplicate(true)
		for operation_index in range(actor_ops.size()):
			var operation := (actor_ops[operation_index] as Dictionary).duplicate(true)
			var stable_id := str(operation.get("stable_object_id", ""))
			if despawn_ids.has(stable_id) and str(operation.get("behavior", "")) == "depart":
				operation["op"] = "despawn"
				operation.erase("behavior")
				operation["receipt_id"] = str(operation.get("receipt_id", "")).replace("_depart", "_despawn")
			elif stable_id == "gas_station_graveyard_shift_night_clerk" and str(operation.get("behavior", "")) == "patrol":
				operation["behavior"] = "watch"
			actor_ops[operation_index] = operation
		phase["actor_ops"] = actor_ops
		phases[phase_index] = phase
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	repaired["sequence"] = sequence
	return repaired
