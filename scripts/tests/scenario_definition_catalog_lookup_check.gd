extends SceneTree

# Focused actual-class resolver regression proposal. Run in its own owned child.
# Canonical Script receivers only; no anonymous baseline and no budget assertion.
# The default Catalog root is restored by exact reference before report/quit.
const ResolverScript := preload("res://scripts/core/scenario_engine.gd")
const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Manifest := preload("res://scripts/core/scenario_sequence_rollout_manifest.gd")
const Dispatch := preload("res://scripts/core/scenario_extension_dispatch.gd")
const SequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const OVERLAY_KEYS := ["sequence", "sequence_package_id", "sequence_handler_pack", "sequence_renderer_id", "sequence_authoring", "__scenario_sequence_runtime_validated", "__scenario_sequence_catalog_resolved"]

var checks: Array = []
var failures: Array[String] = []
var fixture_cases: Array = []
var authority_cases: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_usec := Time.get_ticks_usec()
	var original_cache: Dictionary = Catalog._default_catalog_cache
	var original_cache_payload := original_cache.duplicate(true)
	_check(not _same_variant({"nested": [1]}, {"nested": [1.0]}), "comparator preserves nested scalar types")
	_check(not _same_variant({}, {"missing": null}), "comparator preserves missing versus null")
	_check(not _same_variant({"a": 1, "b": 2}, {"b": 2, "a": 1}), "comparator preserves dictionary insertion order")
	var production := Catalog.default_catalog_snapshot()
	var production_before := production.duplicate(true)
	var ids: Array = Manifest.expected_ids()
	_check(ids.size() == 55, "current rollout manifest has55 scenario IDs")
	_check(bool(production.get("ok", false)), "production default catalog is accepted")
	var overlays_value: Variant = production.get("overlays", {})
	_check(typeof(overlays_value) == TYPE_DICTIONARY, "production overlays are a dictionary")
	var overlays: Dictionary = overlays_value if typeof(overlays_value) == TYPE_DICTIONARY else {}
	_check(overlays.size() == 55, "production catalog has55 selected overlays")
	Catalog._default_catalog_cache = production
	var raw_legacy := _raw_legacy_rows()
	var seen: Dictionary = {}
	for value: Variant in ids:
		var scenario_id := str(value)
		_check(not scenario_id.is_empty() and not seen.has(scenario_id), "manifest ID is nonempty/unique: " + scenario_id)
		seen[scenario_id] = true
		var selected := Catalog.overlay_for(scenario_id, production)
		_check(not selected.is_empty(), "selected overlay exists: " + scenario_id)
		var authored := Catalog.legacy_definition(scenario_id)
		_check(str(authored.get("id", "")) == scenario_id, "fresh source selects exact ID: " + scenario_id)
		_check(str(authored.get("sequence_package_id", "")) == str(selected.get("package_id", "")), "fresh source selects registered package: " + scenario_id)
		var authority_errors := Schema.validate_definition(authored, Registry)
		_check(_contains_text(authority_errors, "no independent target catalog proof"), "unbound authored definition requires independent target proof: " + scenario_id)
		authority_cases.append({"id": scenario_id, "errors": authority_errors.duplicate(true)})
		var expected: Dictionary = raw_legacy.get(scenario_id, {})
		var environment := {"scenario_state": {"id": scenario_id}, "scenario_id": scenario_id, "probe_input": {"nested": ["environment"]}}
		var before_environment := environment.duplicate(true)
		var preferred: Dictionary = {}
		var resolved := ResolverScript.sequence_definition_for_environment(environment, preferred)
		_check(_same_variant(resolved, expected), "full typed raw legacy fallback: " + scenario_id)
		_check(str(resolved.get("id", "")) == scenario_id and not resolved.has("sequence_package_id"), "fallback preserves ID without admitted package: " + scenario_id)
		_check(not resolved.has("sequence") and not resolved.has(ResolverScript.VALIDATED_SEQUENCE_MARKER), "unbound resolver fails closed without sequence/receipt: " + scenario_id)
		_check(_same_variant(environment, before_environment) and preferred.is_empty(), "resolver preserves environment/empty preferred: " + scenario_id)
		_check(is_same(Catalog._default_catalog_cache, production) and _same_variant(production, production_before), "resolver preserves catalog root/payload: " + scenario_id)
	# Malformed fixtures are fresh owned roots. Never mutate the saved original.
	if not ids.is_empty():
		var scenario_id := str(ids[0])
		var selected := Catalog.overlay_for(scenario_id, production)
		if not selected.is_empty():
			var preferred := Catalog.legacy_definition(scenario_id)
			preferred.erase(ResolverScript.VALIDATED_SEQUENCE_MARKER)
			preferred.erase(ResolverScript.RESOLVED_SEQUENCE_CATALOG_MARKER)
			_cache_fixtures(scenario_id, preferred, selected)
			_ownership_and_early_paths(scenario_id, preferred, selected)
			_snapshot_ownership(scenario_id, production)
	_check(_same_variant(production, production_before), "all focused fixtures preserve saved production snapshot")
	# One terminal path after cache mutation: restore exact saved root, not a clone.
	Catalog._default_catalog_cache = original_cache
	_check(is_same(Catalog._default_catalog_cache, original_cache), "original Catalog cache root restored by exact reference")
	_check(_same_variant(original_cache, original_cache_payload), "original Catalog cache payload unchanged")
	_finish(started_usec)

func _raw_legacy_rows() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Catalog.LEGACY_CATALOG_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "raw legacy source is a dictionary")
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	var rows: Dictionary = {}
	var duplicate_id := false
	for pool: Variant in (parsed as Dictionary).values():
		if typeof(pool) != TYPE_ARRAY: continue
		for value: Variant in pool:
			if typeof(value) != TYPE_DICTIONARY: continue
			var row: Dictionary = value
			var scenario_id := str(row.get("id", ""))
			if rows.has(scenario_id): duplicate_id = true
			rows[scenario_id] = row
	_check(not duplicate_id and not rows.has(""), "raw legacy IDs are nonempty and unique")
	_check(rows.size() == 55, "raw legacy source has55 definitions")
	return rows

func _cache_fixtures(scenario_id: String, preferred: Dictionary, selected: Dictionary) -> void:
	var healthy_rows: Dictionary = {}
	healthy_rows[scenario_id] = selected.duplicate(true)
	var healthy := {"ok": true, "overlays": healthy_rows}
	_case("valid selected overlay", scenario_id, preferred, healthy, true)
	_case("failed catalog with populated overlay", scenario_id, preferred, {"ok": false, "overlays": healthy_rows.duplicate(true)}, false)
	_case("missing acceptance flag with populated overlay", scenario_id, preferred, {"overlays": healthy_rows.duplicate(true)}, false)
	_case("malformed overlay map", scenario_id, preferred, {"ok": true, "overlays": []}, false)
	_case("missing selected overlay", scenario_id, preferred, {"ok": true, "overlays": {}}, false)
	var bad_rows: Dictionary = {}
	bad_rows[scenario_id] = ["not a dictionary"]
	_case("nondictionary selected overlay", scenario_id, preferred, {"ok": true, "overlays": bad_rows}, false)
	var empty_rows: Dictionary = {}
	empty_rows[scenario_id] = {}
	_case("empty selected overlay", scenario_id, preferred, {"ok": true, "overlays": empty_rows}, false)
	var wrong_package := selected.duplicate(true)
	wrong_package["package_id"] = "probe_unregistered_package"
	var wrong_package_rows: Dictionary = {}
	wrong_package_rows[scenario_id] = wrong_package
	_check(not Dispatch.validate_package_extensions(str(wrong_package["package_id"]), str(wrong_package.get("handler_pack", "")), str(wrong_package.get("renderer_id", ""))).is_empty(), "mismatched production package also has invalid extension registration")
	_case("package differs from production; extension also invalid (not isolated package-mismatch branch)", scenario_id, preferred, {"ok": true, "overlays": wrong_package_rows}, true)
	var bad_extension := selected.duplicate(true)
	bad_extension["handler_pack"] = "probe_unknown_handler"
	bad_extension["renderer_id"] = "probe_unknown_renderer"
	var bad_extension_rows: Dictionary = {}
	bad_extension_rows[scenario_id] = bad_extension
	_check(not Dispatch.validate_package_extensions(str(bad_extension.get("package_id", "")), str(bad_extension["handler_pack"]), str(bad_extension["renderer_id"])).is_empty(), "invalid selected extension is rejected by registry")
	_case("invalid selected extension", scenario_id, preferred, {"ok": true, "overlays": bad_extension_rows}, true)
	var deep := selected.duplicate(true)
	var nested: Dictionary = {"leaf": true}
	for _index in range(Schema.MAX_DATA_DEPTH + 2): nested = {"nested": nested}
	deep["sequence"]["owner_exceptions"] = [nested]
	var deep_rows: Dictionary = {}
	deep_rows[scenario_id] = deep
	var deep_catalog := {"ok": true, "overlays": deep_rows}
	var deep_candidate := Catalog.apply_overlay(preferred, deep_catalog)
	_check(_contains_text(Schema.validate_definition(deep_candidate, Registry), "nesting depth"), "selected deep-invalid fixture reaches schema depth rejection")
	_case("deep-invalid selected schema", scenario_id, preferred, deep_catalog, true)

func _case(label: String, scenario_id: String, preferred_source: Dictionary, cache_source: Dictionary, overlay_admitted: bool) -> void:
	var environment := {"scenario_state": {"id": scenario_id}, "probe_input": {"nested": ["environment"]}}
	var environment_before := environment.duplicate(true)
	var preferred := preferred_source.duplicate(true)
	var preferred_before := preferred.duplicate(true)
	var cache := cache_source.duplicate(true)
	var cache_before := cache.duplicate(true)
	Catalog._default_catalog_cache = cache
	var selected := Catalog.overlay_for(scenario_id)
	_check(not selected.is_empty() == overlay_admitted, "fixture selected-overlay admission: " + label)
	var unbound := Catalog.apply_overlay(preferred, cache)
	var schema_errors := Schema.validate_definition(unbound, Registry)
	_check(not schema_errors.is_empty(), "fixture unbound or invalid schema remains rejected: " + label)
	if label == "valid selected overlay":
		_check(_contains_text(schema_errors, "no independent target catalog proof"), "healthy selected catalog does not grant unbound target authority")
	var resolved := ResolverScript.sequence_definition_for_environment(environment, preferred)
	var expected := preferred_source.duplicate(true)
	for key: String in OVERLAY_KEYS: expected.erase(key)
	_check(_same_variant(resolved, expected), "fixture full typed legacy fallback: " + label)
	_check(not resolved.has("sequence") and not resolved.has(ResolverScript.VALIDATED_SEQUENCE_MARKER), "fixture inactive/failclosed result: " + label)
	_check(_same_variant(environment, environment_before), "fixture environment unchanged: " + label)
	_check(_same_variant(preferred, preferred_before), "fixture preferred unchanged: " + label)
	_check(is_same(Catalog._default_catalog_cache, cache) and _same_variant(cache, cache_before), "fixture catalog root/payload unchanged: " + label)
	fixture_cases.append({"label": label, "catalog_overlay_admitted": not selected.is_empty(), "engine_active_expected": false, "actual_has_sequence": resolved.has("sequence"), "schema_errors": schema_errors.duplicate(true)})

func _ownership_and_early_paths(scenario_id: String, source: Dictionary, selected: Dictionary) -> void:
	var rows: Dictionary = {}
	rows[scenario_id] = selected.duplicate(true)
	var cache := {"ok": true, "overlays": rows}
	var cache_before := cache.duplicate(true)
	Catalog._default_catalog_cache = cache
	var preferred := source.duplicate(true)
	preferred["probe_owned_nested"] = {"values": ["original"]}
	var preferred_before := preferred.duplicate(true)
	var environment := {"scenario_id": scenario_id}
	var resolved := ResolverScript.sequence_definition_for_environment(environment, preferred)
	var expected := preferred.duplicate(true)
	for key: String in OVERLAY_KEYS: expected.erase(key)
	_check(_same_variant(resolved, expected), "unmarked unbound definition returns exact legacy fallback")
	_check(not is_same(resolved, preferred), "unmarked fallback is independently owned")
	_check(not resolved.has("sequence"), "ownership fixture preserves unbound failclosed boundary")
	resolved["probe_owned_nested"]["values"].append("changed")
	_check(_same_variant(preferred, preferred_before), "mutating fallback preserves preferred nested data")
	_check(is_same(Catalog._default_catalog_cache, cache) and _same_variant(cache, cache_before), "mutating fallback preserves selected cached overlay")
	_check(_same_variant(ResolverScript.sequence_definition_for_environment(environment, preferred), expected), "repeated fallback resolution remains independently owned")
	_check(_same_variant(environment, {"scenario_id": scenario_id}), "ownership probes preserve environment")
	# Reuse the unchanged canonical receipt fixture and its independent inventory,
	# exactly as _check_definition_validation_receipt. Never stamp the authored55.
	var validated := SequenceContractScript._runtime_definition()
	var inventory := SequenceContractScript._fixture_target_inventory(validated)
	var fixture_before := validated.duplicate(true)
	var validation_errors := Schema.validate_definition(validated, Registry, inventory)
	_check(validation_errors.is_empty(), "canonical runtime fixture has its exact independent target proof")
	_check(_same_variant(validated, fixture_before), "canonical fixture validation preserves payload")
	var rejected_cache := {"ok": false, "overlays": {}}
	Catalog._default_catalog_cache = rejected_cache
	if validation_errors.is_empty():
		validated[ResolverScript.VALIDATED_SEQUENCE_MARKER] = true
		var validated_before := validated.duplicate(true)
		var validated_environment := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_state": {"id": str(validated.get("id", ""))}}
		var validated_environment_before := validated_environment.duplicate(true)
		var validated_result := ResolverScript.sequence_definition_for_environment(validated_environment, validated)
		_check(is_same(validated_result, validated), "independently validated preferred intentionally retains exact alias")
		_check(_same_variant(validated, validated_before), "validated preferred payload unchanged")
		_check(_same_variant(validated_environment, validated_environment_before), "validated preferred environment unchanged")
		var suppress_preferred := validated.duplicate(true)
		suppress_preferred[ResolverScript.SEQUENCE_SUPPRESSION_KEY] = true
		var suppress_before := suppress_preferred.duplicate(true)
		var suppressed_expected := validated.duplicate(true)
		for key: String in OVERLAY_KEYS: suppressed_expected.erase(key)
		suppressed_expected[ResolverScript.SEQUENCE_SUPPRESSION_KEY] = true
		var preferred_suppressed := ResolverScript.sequence_definition_for_environment(validated_environment, suppress_preferred)
		_check(_same_variant(preferred_suppressed, suppressed_expected), "preferred suppression wins over legitimately validated receipt")
		_check(_same_variant(suppress_preferred, suppress_before), "preferred suppression input unchanged")
	_check(is_same(Catalog._default_catalog_cache, rejected_cache) and _same_variant(rejected_cache, {"ok": false, "overlays": {}}), "validated and suppressed early paths preserve rejected catalog")
	var plain := {"id": scenario_id, "probe_owned_nested": {"values": ["plain"]}}
	plain[ResolverScript.RESOLVED_SEQUENCE_CATALOG_MARKER] = true
	var plain_before := plain.duplicate(true)
	var plain_result := ResolverScript.sequence_definition_for_environment(environment, plain)
	_check(is_same(plain_result, plain) and _same_variant(plain, plain_before), "resolved nonsequence intentionally retains exact alias/payload")
	_check(not plain_result.has("sequence"), "resolved nonsequence does not reacquire overlay")
	var suppressed_environment := {"scenario_state": {"id": scenario_id, "sequence_suppressed": true}}
	var suppressed_before := suppressed_environment.duplicate(true)
	var expected_suppressed := source.duplicate(true)
	for key: String in OVERLAY_KEYS: expected_suppressed.erase(key)
	expected_suppressed[ResolverScript.SEQUENCE_SUPPRESSION_KEY] = true
	var suppressed := ResolverScript.sequence_definition_for_environment(suppressed_environment, source)
	_check(_same_variant(suppressed, expected_suppressed), "environment suppression wins before overlay/registration")
	_check(_same_variant(suppressed_environment, suppressed_before), "suppression preserves environment")
	_check(is_same(Catalog._default_catalog_cache, rejected_cache) and _same_variant(rejected_cache, {"ok": false, "overlays": {}}), "all early paths preserve rejected catalog")
	_check(ResolverScript.sequence_definition_for_environment({}, {}).is_empty(), "blank scenario ID returns empty")
	_check(ResolverScript.sequence_definition_for_environment({"scenario_id": "probe_never_a_scenario"}, {}).is_empty(), "unknown scenario ID returns empty")

func _snapshot_ownership(scenario_id: String, production: Dictionary) -> void:
	Catalog._default_catalog_cache = production
	var before := production.duplicate(true)
	var snapshot := Catalog.default_catalog_snapshot()
	_check(not is_same(snapshot, production) and _same_variant(snapshot, production), "public catalog snapshot remains an owned complete copy")
	snapshot["overlays"][scenario_id]["sequence"]["probe_snapshot_mutation"] = ["changed"]
	(snapshot["packages"] as Array).append({"probe_snapshot_mutation": true})
	_check(is_same(Catalog._default_catalog_cache, production) and _same_variant(production, before), "mutating public snapshot preserves entire cached catalog")
	var selected := Catalog.overlay_for(scenario_id)
	selected["sequence"]["probe_selected_mutation"] = ["changed"]
	_check(_same_variant(production, before), "selected overlay remains deeply owned")

func _same_variant(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		var a: Dictionary = left
		var b: Dictionary = right
		if a.size() != b.size() or not _same_variant(a.keys(), b.keys()): return false
		for key: Variant in a.keys():
			if not b.has(key) or not _same_variant(a[key], b[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		var a: Array = left
		var b: Array = right
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same_variant(a[index], b[index]): return false
		return true
	return left == right

func _contains_text(values: Array, wanted: String) -> bool:
	for value: Variant in values:
		if str(value).contains(wanted): return true
	return false

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok: failures.append(label)

func _finish(started_usec: int) -> void:
	var report_path := OS.get_environment("BTH_TARGET_OUTPUT")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
	var file: FileAccess = null
	if not report_path.is_empty():
		if FileAccess.file_exists(report_path):
			failures.append("Preserve existing report; use a fresh --report path")
		else:
			file = FileAccess.open(report_path, FileAccess.WRITE)
			if file == null: failures.append("Could not open fresh report path")
	var report := {"schema": "bth_scenario_definition_catalog_lookup_v3", "task": "BTH061-AUDIT-LAYER-DEFINITION-013", "status": "PASS" if failures.is_empty() else "FAIL", "check_count": checks.size(), "failure_count": failures.size(), "failures": failures, "checks": checks, "fixture_cases": fixture_cases, "unbound_authority_cases": authority_cases, "elapsed_usec": Time.get_ticks_usec() - started_usec, "catalog_cache_restoration": "exact prior root reference and unchanged payload checked before reporting", "scope": "actual canonical Engine/Catalog unbound-authority failure boundary and existing independently proven receipt; no whole-suite/RNG/lifecycle claim", "schema_memo": "existing process-local validation memo may change; this child test does not claim to restore it", "historical_terminal": "unchanged source scope, not exercised here", "package_mismatch_limit": "selected package/extension/schema failures may overlap; no isolated registration-mismatch cause claim; healthy catalog admission never grants target authority"}
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("SCENARIO_DEFINITION_CATALOG_LOOKUP " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
