extends SceneTree

const SequenceCatalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceSchema := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistry := preload("res://scripts/core/scenario_operation_registry.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"
const EXPECTED_IDS := [
	"back_alley_cruiser_parked", "back_alley_fence_night", "back_alley_nothing_moving", "back_alley_street_craps",
	"corner_store_aftermath", "corner_store_dead_shift", "corner_store_delivery_day", "corner_store_inventory_night", "corner_store_lotto_fever",
	"pawn_shop_estate_lot_day", "pawn_shop_sals_mood", "pawn_shop_serial_check_day",
]

func _init() -> void:
	var failures: Array = []
	var catalog := SequenceCatalog.load_catalog()
	if not bool(catalog.get("ok", false)): failures.append_array(catalog.get("failures", []))
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(parsed_value) != TYPE_DICTIONARY:
		failures.append("Package A file is not a JSON dictionary.")
		_finish(failures)
		return
	var entries: Array = (parsed_value as Dictionary).get("scenarios", [])
	var actual_ids: Array = []
	var signatures: Dictionary = {}
	var normalized_signatures: Dictionary = {}
	for entry_value in entries:
		var entry := entry_value as Dictionary
		var scenario_id := str(entry.get("scenario_id", ""))
		actual_ids.append(scenario_id)
		var sequence := entry.get("sequence", {}) as Dictionary
		var definition := {"id":scenario_id,"archetype_id":_archetype(scenario_id),"sequence":sequence}
		if scenario_id != "corner_store_delivery_day":
			for error_value in SequenceSchema.validate_definition(definition, OperationRegistry, {}): failures.append("%s: %s" % [scenario_id,error_value])
		var phases: Array = (sequence.get("phase_graph", {}) as Dictionary).get("phases", [])
		if phases.size() < 3: failures.append("%s lacks arrival/work/aftermath phases." % scenario_id)
		var aftermath: Dictionary = sequence.get("aftermath", {})
		if aftermath.size() < 3: failures.append("%s lacks three material terminal aftermaths." % scenario_id)
		var semantic_ids: Dictionary = {}
		var command_ids: Dictionary = {}
		for phase_value in phases:
			var phase := phase_value as Dictionary
			for family in ["scene_ops","actor_ops"]:
				for operation_value in phase.get(family, []):
					var operation := operation_value as Dictionary
					semantic_ids["%s::%s" % [family,operation.get("stable_object_id","")]] = true
			for branch_value in phase.get("branches", []):
				var condition: Dictionary = (branch_value as Dictionary).get("condition", {})
				if str(condition.get("type","")) == "command": command_ids[str(condition.get("command_id",""))] = true
		if semantic_ids.size() < 2: failures.append("%s changes fewer than two semantic objects/actors." % scenario_id)
		if command_ids.size() < 2: failures.append("%s exposes fewer than two command boundaries." % scenario_id)
		var authored_signature := str(sequence.get("sequence_signature",""))
		if signatures.has(authored_signature): failures.append("%s duplicates exact sequence signature with %s." % [scenario_id,signatures[authored_signature]])
		signatures[authored_signature] = scenario_id
		var normalized := JSON.stringify(SequenceSchema.normalized_signature(definition))
		if normalized_signatures.has(normalized): failures.append("%s duplicates normalized mechanic signature with %s." % [scenario_id,normalized_signatures[normalized]])
		normalized_signatures[normalized] = scenario_id
	actual_ids.sort()
	var expected := EXPECTED_IDS.duplicate()
	expected.sort()
	if actual_ids != expected: failures.append("Package A inventory mismatch: %s" % JSON.stringify(actual_ids))
	_finish(failures)

func _archetype(scenario_id: String) -> String:
	if scenario_id.begins_with("corner_store_"): return "corner_store"
	if scenario_id.begins_with("back_alley_"): return "back_alley"
	return "pawn_shop"

func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("ENV06_7_PACKAGE_A_CHECK PASS ids=12 exact_signatures=12 normalized_signatures=12")
		quit(0)
	else:
		for failure in failures: push_error(str(failure))
		quit(1)
