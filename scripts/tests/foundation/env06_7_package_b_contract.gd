extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"
const EXPECTED_IDS := [
	"motel_conventioneers", "motel_stakeout", "motel_weekly_rates", "motel_wedding_overflow",
	"gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift",
	"gas_station_road_crew_payday", "gas_station_storm_shelter",
	"beach_bonfire_night", "beach_storm_coming", "beach_festival_weekend",
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
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			failures.append("Scenario row is not an object.")
			continue
		var row := row_value as Dictionary
		var scenario_id := str(row.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var definition := {"id": scenario_id, "sequence": row.get("sequence", {})}
		definitions.append(definition)
		var errors := Schema.validate_definition(definition, Registry, {})
		for error_value in errors: failures.append("%s: %s" % [scenario_id, str(error_value)])
		_check_physical_sequence(scenario_id, row, failures)
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package B ids differ from the fixed 12-id inventory.")
	var uniqueness := Schema.catalog_uniqueness_report(definitions, EXPECTED_IDS.size(), Registry)
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


func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("ENV06_7_PACKAGE_B_CONTRACT_OK ids=12")
		quit(0)
		return
	for failure_value in failures: printerr("ENV06_7_PACKAGE_B_CONTRACT_FAIL: %s" % str(failure_value))
	quit(1)
