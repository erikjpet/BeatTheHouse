extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")

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
		var errors := Schema.validate_definition(definition)
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
