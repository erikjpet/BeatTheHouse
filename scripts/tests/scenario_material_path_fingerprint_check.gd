extends SceneTree

# Actual canonical-class regression; run this identical script on each source version.
const CanonicalSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const CanonicalRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const CanonicalCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const REPORT_ENV := "BTH_TARGET_OUTPUT"

var checks: Array = []
var failures: Array[String] = []
var authored_records: Array = []
var fixture_records: Array = []
var helper_records: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(not _same_variant([1], [1.0]), "comparison preserves scalar Variant types")
	_check(not _same_variant({"a": 1, "b": 2}, {"b": 2, "a": 1}), "comparison preserves dictionary insertion order")
	_check(_raw_digest([1]) != _raw_digest([1.0]), "Variant-byte digests preserve scalar Variant types beyond JSON")
	_check(_raw_digest({"a": 1, "b": 2}) != _raw_digest({"b": 2, "a": 1}), "Variant-byte digests preserve dictionary insertion order beyond JSON")
	var rows := _source_rows()
	_check(rows.size() == 55, "all55 original-order source scenarios are present")
	var seen: Dictionary = {}
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var scenario_id := str(row.get("id", ""))
		_check(not scenario_id.is_empty() and not seen.has(scenario_id), "source ID is nonempty and unique: " + scenario_id)
		seen[scenario_id] = true
		var definition := CanonicalCatalogScript.legacy_definition(scenario_id)
		_check(str(definition.get("id", "")) == scenario_id and typeof(definition.get("sequence")) == TYPE_DICTIONARY, "canonical authored definition is available: " + scenario_id)
		var source_before := definition.duplicate(true)
		var validation := _validate(definition, {}, false, "authored:" + scenario_id)
		var material := _material(_dict(definition.get("sequence", {})), {}, "authored:" + scenario_id)
		_check(_contains_text(validation["errors"], "no independent target catalog proof"), "authored definition retains actual unbound authority rejection: " + scenario_id)
		_check(_same_variant(definition, source_before), "shared authored definition remains unchanged: " + scenario_id)
		authored_records.append({"index": index, "id": scenario_id, "definition": definition, "definition_variant_sha256": _raw_digest(definition), "validation": validation, "material": material})
	_check(authored_records.size() == 55 and seen.size() == 55, "all55 complete validation and direct-helper records finished")

	# Exact existing maintained definition/inventory; no target grants to any of55.
	var definition: Dictionary = SequenceContractScript._runtime_definition()
	var inventory: Dictionary = SequenceContractScript._fixture_target_inventory(definition)
	var definition_before := definition.duplicate(true)
	var inventory_before := inventory.duplicate(true)
	var validation := _validate(definition, inventory, true, "maintained_runtime_fixture")
	var material := _material(_dict(definition.get("sequence", {})), inventory, "maintained_runtime_fixture")
	_check(validation["errors"].is_empty(), "unchanged maintained runtime fixture validates with its exact maintained inventory")
	_check(_same_variant(definition, definition_before) and _same_variant(inventory, inventory_before), "unchanged maintained fixture and inventory remain intact")
	fixture_records.append({"label": "unchanged_maintained_runtime_fixture", "definition": definition, "target_inventory": inventory, "definition_variant_sha256": _raw_digest(definition), "inventory_variant_sha256": _raw_digest(inventory), "validation": validation, "material": material})

	# The following case builders and independent oracles are verbatim frozen R2.
	for case_value: Variant in _helper_cases():
		var case: Dictionary = case_value
		var label := str(case["label"])
		var result := _material(case["authored"], {}, "synthetic_helper_only:" + label)
		_check_helper_expectations(case, result["value"], result["errors"])
		helper_records.append({"label": label, "scope": "diagnostic helper-only; no whole-definition signature or authority claim", "authored": case["authored"], "target_inventory": {}, "expectation": case["expectation"], "authored_variant_sha256": _raw_digest(case["authored"]), "material": result})
	_check(helper_records.size() == 13, "all13 frozen independent helper cases completed")
	_run_fingerprint_budget_probe()
	_finish()


func _source_rows() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CanonicalCatalogScript.LEGACY_CATALOG_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "legacy catalog source root is a Dictionary")
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var rows: Array = []
	for pool: Variant in (parsed as Dictionary).values():
		if typeof(pool) != TYPE_ARRAY:
			continue
		for value: Variant in pool:
			if typeof(value) == TYPE_DICTIONARY:
				rows.append(value)
	return rows


func _validate(definition: Dictionary, inventory: Dictionary, explicit_inventory: bool, label: String) -> Dictionary:
	var owned_definition := definition.duplicate(true)
	var owned_inventory := inventory.duplicate(true)
	var definition_before := owned_definition.duplicate(true)
	var inventory_before := owned_inventory.duplicate(true)
	var memo_before: Dictionary = CanonicalSchemaScript._successful_validation_memo_stats_for_tests()
	var errors: Array = []
	if explicit_inventory:
		errors = CanonicalSchemaScript.validate_definition(owned_definition, CanonicalRegistryScript, owned_inventory)
	else:
		# Exactly two arguments preserve the callee's canonical empty default.
		errors = CanonicalSchemaScript.validate_definition(owned_definition, CanonicalRegistryScript)
	var memo_after: Dictionary = CanonicalSchemaScript._successful_validation_memo_stats_for_tests()
	var unchanged := _same_variant(owned_definition, definition_before) and _same_variant(owned_inventory, inventory_before)
	_check(unchanged, "whole validation preserves complete typed input and inventory: " + label)
	var delta := _memo_delta(memo_before, memo_after)
	if not explicit_inventory:
		_check(_same_variant(delta, {"entries": 0, "order_entries": 0, "hits": 0, "full_runs": 1, "evictions": 0}), "unbound failure performs one full run without success-cache admission: " + label)
	return {"inventory_argument": "explicit unchanged maintained inventory" if explicit_inventory else "omitted; canonical empty Dictionary default", "errors": errors.duplicate(true), "errors_variant_sha256": _raw_digest(errors), "input_unchanged": unchanged, "definition_before_variant_sha256": _raw_digest(definition_before), "definition_after_variant_sha256": _raw_digest(owned_definition), "inventory_before_variant_sha256": _raw_digest(inventory_before), "inventory_after_variant_sha256": _raw_digest(owned_inventory), "memo_before": memo_before, "memo_after": memo_after, "memo_delta": delta}


func _material(authored: Dictionary, inventory: Dictionary, label: String) -> Dictionary:
	var owned_authored := authored.duplicate(true)
	var owned_inventory := inventory.duplicate(true)
	var authored_before := owned_authored.duplicate(true)
	var inventory_before := owned_inventory.duplicate(true)
	var prefix: Array = ["catalog015 existing error sentinel", {"typed": [1, 1.0, false, "1"], "ordered": {"z": 0, "a": 1}}]
	var errors := prefix.duplicate(true)
	var memo_before: Dictionary = CanonicalSchemaScript._successful_validation_memo_stats_for_tests()
	var value: Dictionary = CanonicalSchemaScript._material_target_paths_by_outcome(owned_authored, owned_inventory, errors)
	var memo_after: Dictionary = CanonicalSchemaScript._successful_validation_memo_stats_for_tests()
	var unchanged := _same_variant(owned_authored, authored_before) and _same_variant(owned_inventory, inventory_before)
	var prefix_preserved := errors.size() >= prefix.size() and _same_variant(errors.slice(0, prefix.size()), prefix)
	_check(unchanged, "direct material helper preserves complete typed authored/inventory input: " + label)
	_check(prefix_preserved, "direct material helper preserves supplied ordered error prefix: " + label)
	_check(_same_variant(memo_before, memo_after), "direct material helper leaves existing validation memo counters unchanged: " + label)
	return {"value": value.duplicate(true), "value_variant_sha256": _raw_digest(value), "errors": errors.duplicate(true), "errors_variant_sha256": _raw_digest(errors), "error_prefix": prefix, "error_prefix_variant_sha256": _raw_digest(prefix), "input_unchanged": unchanged, "error_prefix_preserved": prefix_preserved, "authored_before_variant_sha256": _raw_digest(authored_before), "authored_after_variant_sha256": _raw_digest(owned_authored), "inventory_before_variant_sha256": _raw_digest(inventory_before), "inventory_after_variant_sha256": _raw_digest(owned_inventory), "memo_before": memo_before, "memo_after": memo_after}


func _helper_cases() -> Array:
	var cases: Array = []
	cases.append(_case("duplicate_same_outcome", _authored("start", [_phase("start", [{"outcome": "done"}, {"outcome": "done"}])]), {"outcome_counts": {"done": 1}, "added_errors": 0}))
	cases.append(_case("same_fingerprint_different_outcomes", _authored("start", [_phase("start", [{"outcome": "done"}, {"outcome": "other"}, {"outcome": "done"}])]), {"outcome_counts": {"done": 1, "other": 1}, "added_errors": 0}))
	cases.append(_case("distinct_targets_same_outcome", _fork_authored(_spawn("left", {"probe": "left"}), _spawn("right", {"probe": "right"}), false), {"outcome_counts": {"done": 2}, "target_keys": [["scenario::left"], ["scenario::right"]], "added_errors": 2}))
	cases.append(_case("reconverged_equal_paths", _fork_authored({}, {}, true), {"outcome_counts": {"done": 1}, "added_errors": 0}))
	cases.append(_case("reconverged_distinct_paths", _fork_authored(_spawn("left", {"probe": "left"}), _spawn("right", {"probe": "right"}), true), {"outcome_counts": {"done": 2}, "target_keys": [["scenario::left"], ["scenario::right"]], "added_errors": 2}))
	cases.append(_case("dictionary_insertion_order_deduplicates", _fork_authored(_spawn("shared", {"z": 9, "a": 1}), _spawn("shared", {"a": 1, "z": 9}), false), {"outcome_counts": {"done": 1}, "target_keys": [["scenario::shared"]], "added_errors": 1}))
	cases.append(_case("array_order_remains_material", _fork_authored(_spawn("shared", {"probe": [1, 2]}), _spawn("shared", {"probe": [2, 1]}), false), {"outcome_counts": {"done": 2}, "target_keys": [["scenario::shared"], ["scenario::shared"]], "added_errors": 2}))
	var converged := _fork_authored(_spawn("left", {"probe": "left"}), _spawn("right", {"probe": "right"}), false)
	converged["cleanup"]["operations"] = [
		{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_left", "owner_namespace": "scenario", "stable_object_id": "left"},
		{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_right", "owner_namespace": "scenario", "stable_object_id": "right"},
	]
	cases.append(_case("distinct_before_cleanup_equal_after_cleanup_keep_both", converged, {"outcome_counts": {"done": 2}, "target_keys": [[], []], "added_errors": 0}))
	cases.append(_case("phase_cycle", _authored("start", [_phase("start", [{"next_phase": "start"}])]), {"outcome_counts": {}, "added_errors": 1, "error_contains": "material path repeats phase start"}))
	var phases: Array = []
	for index in range(10):
		var branches: Array = [{"outcome": "done"}] if index == 9 else [{"next_phase": "p%d" % (index + 1)}, {"next_phase": "p%d" % (index + 1)}]
		phases.append(_phase("p%d" % index, branches))
	cases.append(_case("explicit_512_path_limit", _authored("p0", phases), {"outcome_counts": {"done": 1}, "added_errors": 1, "error_contains": "exceeds the explicit 512-path limit"}))
	cases.append(_case("malformed_graph_container", {"phase_graph": "not a Dictionary", "cleanup": [1, false]}, {"outcome_counts": {}, "added_errors": 0}))
	cases.append(_case("malformed_phase_and_branch_rows", _authored("start", [null, 7, false, {"id": "start", "scene_ops": "not an Array", "branches": [null, 3, {"next_phase": "missing"}]}]), {"outcome_counts": {}, "added_errors": 0}))
	cases.append(_case("helper_string_id_coercion", _authored("7", [{"id": 7, "branches": [{"outcome": 12}, {"outcome": 12}]}]), {"outcome_counts": {"12": 1}, "added_errors": 0}))
	return cases


func _run_fingerprint_budget_probe() -> void:
	# One bounded invalid definition, not an authority grant or accepted content.
	# FIFO terminal order is small A, large B, then identical small A again.
	var repeated_text := "\n".repeat(512)
	var groups: Array = []
	for group_index in range(24):
		var group: Dictionary = {}
		for field_index in range(64):
			group["field_%02d" % field_index] = repeated_text
		groups.append(group)
	var authored := _authored("start", [
		_phase("start", [{"next_phase": "small"}, {"next_phase": "big"}, {"next_phase": "again"}]),
		_phase("small", [{"outcome": "done"}], _spawn("shared", {"probe": "small"})),
		_phase("big", [{"outcome": "done"}], _spawn("shared", {"bulk": groups})),
		_phase("again", [{"outcome": "done"}], _spawn("shared", {"probe": "small"})),
	])
	authored["schema_version"] = 2
	var label := "fingerprint_budget_disable_then_repeat"
	var shape_errors: Array = []
	CanonicalSchemaScript._validate_shape_bounds(label, authored, shape_errors)
	_check(shape_errors.is_empty(), "budget probe passes unchanged generic shape bounds")
	var leak := "sequence terminal path for outcome done leaks temporary scene_objects target scenario::shared after cleanup."
	var validation := _validate({"id": "fingerprint_budget_probe", "sequence": authored}, {}, false, label)
	_check(not validation["errors"].is_empty(), "bounded diagnostic definition remains rejected by whole validation")
	_check(_contains_text(validation["errors"], leak), "bounded invalid definition reaches material cleanup after generic shape preflight")
	var expectation := {"outcome_counts": {"done": 2}, "target_keys": [["scenario::shared"], ["scenario::shared"]], "added_errors": 2}
	var case := _case(label, authored, expectation)
	var result := _material(authored, {}, "synthetic_helper_only:" + label)
	_check_helper_expectations(case, result["value"], result["errors"])
	_check(_same_variant(_array(result["errors"]).slice(2), [leak, leak]), "budget probe preserves exact ordered cleanup leak errors")
	var paths := _array(_dict(result["value"]).get("done", []))
	var charges: Array = []
	for path_value: Variant in paths:
		# Literal contract values also parse on the pre-budget canonical baseline.
		charges.append(JSON.stringify(CanonicalSchemaScript._canonical_variant(path_value)).length() * 4 + 128)
	_check(charges.size() == 2 and int(charges[0]) <= 4 * 1024 * 1024 and int(charges[1]) > 4 * 1024 * 1024, "actual canonical small/large fingerprint charges straddle the 4MiB budget")
	var first := _dict(_dict(_dict(paths[0]).get("scene_objects", {})).get("scenario::shared", {})) if paths.size() >= 1 else {}
	var second := _dict(_dict(_dict(paths[1]).get("scene_objects", {})).get("scenario::shared", {})) if paths.size() >= 2 else {}
	_check(first.get("probe") == "small" and _array(second.get("bulk", [])).size() == 24, "budget probe keeps first A then B and suppresses repeated A after fallback")
	helper_records.append({"label": label, "scope": "bounded invalid helper-only diagnostic; whole validation rejection and shape preflight recorded; no authority grant", "authored": authored, "target_inventory": {}, "expectation": expectation, "authored_variant_sha256": _raw_digest(authored), "material": result, "shape_errors": shape_errors, "whole_validation": validation, "fingerprint_charges": charges, "charge_contract": "4*canonical_JSON_String.length()+128 per retained outcome entry; 4MiB per invocation; not a process RSS claim"})
	_check(helper_records.size() == 14, "all13 frozen cases plus the additive budget fallback probe completed")


func _case(label: String, authored: Dictionary, expectation: Dictionary) -> Dictionary:
	return {"label": label, "authored": authored, "expectation": expectation}


func _authored(initial_phase: String, phases: Array) -> Dictionary:
	return {"phase_graph": {"initial_phase": initial_phase, "phases": phases}, "cleanup": {"operations": []}}


func _phase(id: String, branches: Array, operation: Dictionary = {}) -> Dictionary:
	return {"id": id, "scene_ops": [] if operation.is_empty() else [operation], "branches": branches}


func _spawn(id: String, payload: Dictionary) -> Dictionary:
	return {"op": "spawn", "receipt_id": "spawn_" + id, "owner_namespace": "scenario", "stable_object_id": id, "object": payload}


func _fork_authored(left_operation: Dictionary, right_operation: Dictionary, reconverge: bool) -> Dictionary:
	var branch: Dictionary = {"next_phase": "merge"} if reconverge else {"outcome": "done"}
	var phases: Array = [
		_phase("start", [{"next_phase": "left"}, {"next_phase": "right"}]),
		_phase("left", [branch.duplicate(true)], left_operation),
		_phase("right", [branch.duplicate(true)], right_operation),
	]
	if reconverge:
		phases.append(_phase("merge", [{"outcome": "done"}]))
	return _authored("start", phases)


func _check_helper_expectations(case: Dictionary, value: Dictionary, errors: Array) -> void:
	var label := str(case["label"])
	var expected: Dictionary = case["expectation"]
	var counts: Dictionary = {}
	for outcome: Variant in value.keys():
		counts[outcome] = _array(value[outcome]).size()
	_check(_same_variant(counts, expected["outcome_counts"]), "independent expected outcome/path counts: " + label)
	_check(errors.size() - 2 == int(expected["added_errors"]), "independent expected appended error count: " + label)
	if expected.has("error_contains"):
		_check(_contains_text(errors.slice(2), str(expected["error_contains"])), "independent expected error cause: " + label)
	if expected.has("target_keys"):
		var keys: Array = []
		for path_value: Variant in _array(value.get("done", [])):
			keys.append(_dict(_dict(path_value).get("scene_objects", {})).keys())
		_check(_same_variant(keys, expected["target_keys"]), "independent expected retained material identities/order: " + label)


func _memo_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for key: String in ["entries", "order_entries", "hits", "full_runs", "evictions"]:
		delta[key] = int(after.get(key, 0)) - int(before.get(key, 0))
	return delta


func _same_variant(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_DICTIONARY:
		var a: Dictionary = left
		var b: Dictionary = right
		if a.size() != b.size() or not _same_variant(a.keys(), b.keys()):
			return false
		for key: Variant in a.keys():
			if not b.has(key) or not _same_variant(a[key], b[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY:
		var a: Array = left
		var b: Array = right
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not _same_variant(a[index], b[index]):
				return false
		return true
	return left == right


func _contains_text(values: Array, wanted: String) -> bool:
	for value: Variant in values:
		if str(value).contains(wanted):
			return true
	return false


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures.append(label)


func _raw_digest(value: Variant) -> String:
	var context := HashingContext.new()
	var started := context.start(HashingContext.HASH_SHA256)
	if started != OK:
		_check(false, "Variant-byte SHA256 initialization succeeds")
		return ""
	var updated := context.update(var_to_bytes(value))
	if updated != OK:
		_check(false, "Variant-byte SHA256 update succeeds")
		return ""
	return context.finish().hex_encode()


func _finish() -> void:
	var report_path := OS.get_environment(REPORT_ENV)
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()):
		var argument := str(arguments[index])
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif argument == "--report":
			if index + 1 < arguments.size():
				report_path = str(arguments[index + 1])
			else:
				failures.append("--report requires a fresh output path")
	var file: FileAccess = null
	if report_path.is_empty():
		failures.append("A fresh --report path or BTH_TARGET_OUTPUT is required")
	elif FileAccess.file_exists(report_path):
		failures.append("Preserve existing report; select a fresh report path")
	else:
		file = FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			failures.append("Could not open fresh report path")
	var comparable := {"schema": "bth_scenario_material_path_fingerprint_comparable_v1", "scenario_count": authored_records.size(), "authored_records": authored_records, "fixture_records": fixture_records, "helper_case_count": helper_records.size(), "helper_records": helper_records}
	var comparable_digest := _raw_digest(comparable)
	var report := {"schema": "bth_scenario_material_path_fingerprint_check_v1", "status": "PASS" if failures.is_empty() else "FAIL", "check_count": checks.size(), "failure_count": failures.size(), "failures": failures, "checks": checks, "comparable": comparable, "comparable_variant_sha256": comparable_digest, "digest_encoding": "SHA256 of var_to_bytes(value), preserving Variant scalar types and Dictionary insertion order; independently asserted before traversal", "scope": "Actual canonical Schema only. Run the identical test on baseline and candidate and compare the complete comparable object and Variant-byte digests externally. All55 authored scenarios retain unchanged default empty inventory. The separately labelled maintained fixture uses its unchanged existing inventory; synthetic helper cases grant no target authority and make no whole-definition signature claim. No whole-suite, RNG-state parity, lifecycle or speedup acceptance claim.", "rng_scope": "This script calls no RNG API and does not measure or claim RNG-state parity.", "memo_policy": "No clear, prewarm, reset or added cross-call cache. Complete actual validation memo counters are recorded; the unchanged bound fixture may legitimately enter the existing positive memo.", "limits": "External root-owned supervision only; no budget assertion, job launch, deletion or source mutation."}
	if file != null:
		var serialized := JSON.stringify(report, "\t")
		file.store_string(serialized)
		file.flush()
		var write_error := file.get_error()
		file.close()
		if write_error != OK or FileAccess.get_file_as_string(report_path) != serialized:
			failures.append("Fresh report failed exact byte-equivalent text readback")
			report["status"] = "FAIL"
			report["failure_count"] = failures.size()
	print("SCENARIO_MATERIAL_PATH_FINGERPRINT_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
