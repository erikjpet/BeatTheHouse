extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const DEFAULT_SEED := "WAVE-A-COEXISTENCE"
const DEFAULT_REPORT_PATH := "res://.tmp/wave_a_coexistence_probe/report.json"
const SCENARIO_NODE_ID := "bar"
const CREW_LENDER_NODE_ID := "corner_store"
const CREW_LENDER_ID := "the_crew"
const CREW_MARKER_MEMBER_ID := "crew_rook"

var seed_text := DEFAULT_SEED
var report_path := DEFAULT_REPORT_PATH
var failures: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_text = argument.trim_prefix("--seed=").strip_edges()
		elif argument.begins_with("--out="):
			report_path = _normalized_report_path(argument.trim_prefix("--out=").strip_edges())
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	_require(not library.environment_archetype(SCENARIO_NODE_ID).is_empty(), "Missing shipped scenario archetype: %s." % SCENARIO_NODE_ID)
	_require(not library.scenarios_for_archetype(SCENARIO_NODE_ID).is_empty(), "Missing shipped scenario pool: %s." % SCENARIO_NODE_ID)
	_require(not library.environment_archetype(CREW_LENDER_NODE_ID).is_empty(), "Missing shipped Crew lender environment: %s." % CREW_LENDER_NODE_ID)
	var crew_lender := library.lender(CREW_LENDER_ID)
	_require(not crew_lender.is_empty(), "Missing shipped Crew lender definition: %s." % CREW_LENDER_ID)
	_require(str(crew_lender.get("lender_type", "")) == "favor_crew", "The shipped Crew lender no longer uses the favor_crew path.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var start_environment: EnvironmentInstance = generator.next_environment(run_state)
	_require(not start_environment.to_dict().is_empty(), "The run did not generate its starting environment.")
	_require(run_state.scenario_for_node(SCENARIO_NODE_ID).is_empty(), "The scenario target was already generated before its first visit.")

	generator.next_environment(run_state, SCENARIO_NODE_ID, true)
	var selected_scenario := run_state.scenario_for_node(SCENARIO_NODE_ID)
	var selected_scenario_id := str(selected_scenario.get("id", ""))
	_require(run_state.current_world_node_id() == SCENARIO_NODE_ID, "First-visit travel did not enter %s." % SCENARIO_NODE_ID)
	_require(not selected_scenario_id.is_empty(), "First-visit generation did not select a scenario for %s." % SCENARIO_NODE_ID)
	_require(str(run_state.current_environment.get("scenario_id", "")) == selected_scenario_id, "The selected scenario was not applied to the generated environment.")
	_require(run_state.recent_scenario_ids(SCENARIO_NODE_ID).has(selected_scenario_id), "First-visit selection did not update scenario repeat protection.")

	var town_before := run_state.town_snapshot()
	var town_public_before := run_state.town_public_snapshot()
	var environment_turns_before := int(run_state.current_environment.get("turns", 0))
	run_state.advance_environment_turns(1)
	var town_after := run_state.town_snapshot()
	var town_public_after := run_state.town_public_snapshot()
	_require(int(town_after.get("action_index", -1)) == int(town_before.get("action_index", -1)) + 1, "Town State did not advance exactly once at the action boundary.")
	_require(int(run_state.current_environment.get("turns", -1)) == environment_turns_before + 1, "The environment action boundary did not advance its turn alongside Town State.")
	_require(_schedule_identity(town_after) == _schedule_identity(town_before), "Town State regenerated its seeded schedule while advancing an action.")

	generator.next_environment(run_state, CREW_LENDER_NODE_ID, true)
	_require(run_state.current_world_node_id() == CREW_LENDER_NODE_ID, "Travel did not enter the shipped Crew lender environment.")
	_require(_string_array(run_state.current_environment.get("lender_hooks", [])).has(CREW_LENDER_ID), "The generated Crew lender environment does not expose the shipped Crew hook.")
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	var lender_option := resolver.hook_option("lender", CREW_LENDER_ID)
	_require(bool(lender_option.get("mutation_supported", false)), "The shipped Crew lender hook is not mutation-supported.")
	_require(bool(lender_option.get("enabled", false)), "The shipped Crew lender hook was unavailable: %s" % str(lender_option.get("disabled_reason", "unknown")))
	var trust_before := run_state.crew_trust(CREW_MARKER_MEMBER_ID)
	var bankroll_before := run_state.bankroll
	var crew_result := resolver.use_hook("lender", CREW_LENDER_ID)
	var trust_after := run_state.crew_trust(CREW_MARKER_MEMBER_ID)
	var marker_threshold := CrewStateModelScript.rank_threshold("marker")
	_require(bool(crew_result.get("ok", false)), "The shipped Crew lender hook failed: %s" % str(crew_result.get("message", "unknown")))
	_require(trust_before < marker_threshold, "The probe did not begin below Marker trust.")
	_require(trust_after == marker_threshold, "The shipped Crew lender hook did not write exact Marker trust for Rook.")
	_require(run_state.crew_rank(CREW_MARKER_MEMBER_ID) == "marker", "Rook was not at Marker rank after the shipped Crew lender hook.")
	_require(run_state.bankroll == bankroll_before + int(crew_lender.get("debt_profile", {}).get("loan_amount", 0)), "The Crew lender result did not preserve its shipped bankroll transfer.")
	var crew_debt := _debt_for_lender(run_state.debt, CREW_LENDER_ID)
	_require(not crew_debt.is_empty(), "The shipped Crew lender hook did not open its favor marker.")
	_require(str(crew_debt.get("debt_kind", "")) == "favor", "The shipped Crew lender hook did not retain favor-denominated debt.")

	var authoritative_scenario := run_state.scenario_for_node(SCENARIO_NODE_ID)
	var authoritative_town := run_state.town_snapshot()
	var authoritative_trust := run_state.crew_trust_by_member.duplicate(true)
	var authoritative_debt := run_state.debt.duplicate(true)
	var saved := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved)
	var restored_scenario := restored.scenario_for_node(SCENARIO_NODE_ID)
	var restored_town := restored.town_snapshot()
	var restored_debt := _debt_for_lender(restored.debt, CREW_LENDER_ID)
	_require(_json_equal(restored_scenario, authoritative_scenario), "Save/load changed the selected scenario state.")
	_require(_json_equal(restored_town, authoritative_town), "Save/load changed Town State.")
	_require(_json_equal(restored.crew_trust_by_member, authoritative_trust), "Save/load changed Crew trust.")
	_require(_json_equal(restored.debt, authoritative_debt), "Save/load changed the Crew lender debt ledger.")
	_require(restored.crew_rank(CREW_MARKER_MEMBER_ID) == "marker" and not restored_debt.is_empty(), "Save/load lost the shipped Crew lender Marker interaction.")
	_require(restored.current_world_node_id() == CREW_LENDER_NODE_ID, "Save/load changed the current world node.")

	var report := {
		"tool": "wave_a_coexistence_probe",
		"seed": seed_text,
		"passed": failures.is_empty(),
		"scenario": {
			"node_id": SCENARIO_NODE_ID,
			"scenario_id": selected_scenario_id,
			"phase_index": int(authoritative_scenario.get("phase_index", -1)),
		},
		"town": {
			"action_index_before": int(town_before.get("action_index", -1)),
			"action_index_after_boundary": int(town_after.get("action_index", -1)),
			"action_index_after_crew_hook": int(authoritative_town.get("action_index", -1)),
			"weather_before": str(town_public_before.get("weather", "")),
			"weather_after_boundary": str(town_public_after.get("weather", "")),
		},
		"crew": {
			"lender_id": CREW_LENDER_ID,
			"member_id": CREW_MARKER_MEMBER_ID,
			"trust_before": trust_before,
			"trust_after": trust_after,
			"rank_after": run_state.crew_rank(CREW_MARKER_MEMBER_ID),
			"debt_id": str(crew_debt.get("id", "")),
		},
		"save_load": {
			"scenario_equal": _json_equal(restored_scenario, authoritative_scenario),
			"town_equal": _json_equal(restored_town, authoritative_town),
			"crew_trust_equal": _json_equal(restored.crew_trust_by_member, authoritative_trust),
			"crew_debt_equal": _json_equal(restored.debt, authoritative_debt),
		},
		"failures": failures.duplicate(),
	}
	_write_report(report)
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("WAVE_A_COEXISTENCE %s seed=%s scenario=%s@%s town=%d>%d>%d crew=%s:%d>%d/%s save_load=%s report=%s" % [
		status,
		seed_text,
		selected_scenario_id,
		SCENARIO_NODE_ID,
		int(town_before.get("action_index", -1)),
		int(town_after.get("action_index", -1)),
		int(authoritative_town.get("action_index", -1)),
		CREW_MARKER_MEMBER_ID,
		trust_before,
		trust_after,
		run_state.crew_rank(CREW_MARKER_MEMBER_ID),
		"ok" if bool(report.get("save_load", {}).get("scenario_equal", false)) and bool(report.get("save_load", {}).get("town_equal", false)) and bool(report.get("save_load", {}).get("crew_trust_equal", false)) and bool(report.get("save_load", {}).get("crew_debt_equal", false)) else "failed",
		report_path,
	])
	if failures.is_empty():
		quit(0)
		return
	for failure_value in failures:
		push_error(str(failure_value))
	quit(1)


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _debt_for_lender(entries: Array, lender_id: String) -> Dictionary:
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("lender_id", "")) == lender_id:
			return (entry_value as Dictionary).duplicate(true)
	return {}


func _schedule_identity(snapshot: Dictionary) -> String:
	return JSON.stringify({
		"schema_version": snapshot.get("schema_version", 0),
		"seed_value": snapshot.get("seed_value", 0),
		"turn_horizon": snapshot.get("turn_horizon", 0),
		"weather_schedule": snapshot.get("weather_schedule", []),
		"calendar_cycle": snapshot.get("calendar_cycle", []),
		"calendar_offset_actions": snapshot.get("calendar_offset_actions", 0),
		"happenings": snapshot.get("happenings", []),
	})


func _json_equal(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value as Array:
			result.append(str(entry_value))
	return result


func _normalized_report_path(value: String) -> String:
	if value.is_empty():
		return DEFAULT_REPORT_PATH
	if value.to_lower().ends_with(".json"):
		return value
	return "%s/report.json" % value.trim_suffix("/")


func _write_report(report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write coexistence report: %s." % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
