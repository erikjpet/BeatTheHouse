extends SceneTree

const WorldSequencePackageCatalogScript := preload("res://scripts/core/world_sequence_package_catalog.gd")
const ItemEffectScript := preload("res://scripts/core/item_effect.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentHoursScript := preload("res://scripts/core/environment_hours.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_package_results()
	_check_item_modifier_conflicts()
	_check_clock_boundary()
	_check_route_affordability()
	if failures.is_empty():
		print("HEALTH06_1_CORRECTNESS PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_package_results() -> void:
	_expect(not WorldSequencePackageCatalogScript.entry("world06_1_crew_favor_delivery").is_empty(), "CH-07: valid allowlisted package no longer loads.")
	var oversized: Array = []
	for index in range(WorldSequencePackageCatalogScript.MAX_PACKAGES_PER_FILE + 1):
		oversized.append({"package_id": "fixture_%d" % index, "definitions": [{}]})
	var oversized_result := WorldSequencePackageCatalogScript._entry_result_from_payload(oversized, "fixture_0")
	_expect(str(oversized_result.get("error_code", "")) == "package_file_too_large", "CH-07: explicit package-file bound was not enforced.")
	var corrupt_shape := WorldSequencePackageCatalogScript._entry_result_from_payload({"package_id": "fixture"}, "fixture")
	_expect(str(corrupt_shape.get("error_code", "")) == "package_file_invalid", "CH-07: corrupt package shape was not reported distinctly.")
	var unknown := WorldSequencePackageCatalogScript.entry_result("not_allowlisted")
	_expect(str(unknown.get("error_code", "")) == "unknown_package_id", "CH-07: unknown package id was not reported distinctly.")


func _check_item_modifier_conflicts() -> void:
	var item := ItemEffectScript.new()
	item.setup({
		"id": "health_conflict",
		"class": "fixture",
		"domain": "games",
		"effect": {
			"win_chance": {"bad": true},
			"legal_win_chance": 2,
			"families": {"slot": {"win_chance": 3}},
		},
	})
	var modifiers := item.modifiers_for({"domain": "games", "game_family": "slot", "action_kind": "legal"})
	_expect(modifiers.get("win_chance") == 5, "CH-08: guarded runtime merge did not deliberately replace then accumulate a conflicting modifier.")
	var library := ContentLibraryScript.new()
	library.items = [{
		"id": "health_conflict",
		"content_groups": ["health"],
		"effect": {"win_chance": {"bad": true}, "legal_win_chance": 2},
	}]
	library.content_groups = [{"id": "health"}]
	library.validation_errors = []
	library._validate_item_definitions()
	_expect(_contains_text(library.validation_errors, "modifier type conflict"), "CH-08: ContentLibrary accepted conflicting item modifier types.")


func _check_clock_boundary() -> void:
	var status := EnvironmentHoursScript.status_at({"open_hours": {"open_minute": 570, "close_minute": 1050}}, 500)
	_expect(str(status.get("opens_at", "")) == "9:30 AM", "CH-09: environment hours still drops authored minutes.")


func _check_route_affordability() -> void:
	_expect(RunTerminalEvaluatorScript._route_is_affordable(10, 0), "CH-10: a free route is not affordable with a positive bankroll.")
	_expect(RunTerminalEvaluatorScript._route_is_affordable(10, 9), "CH-10: a route leaving positive bankroll is not affordable.")
	_expect(not RunTerminalEvaluatorScript._route_is_affordable(10, 10), "CH-10: a route consuming the final bankroll unit is affordable.")


func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
