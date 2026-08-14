extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const DEFAULT_SEED := "WAVE-B-COMPOSITION-08"
const DEFAULT_REPORT_PATH := "res://.tmp/wave_b_composition_probe/report.json"
const RUMOR_VENUE_ID := "corner_store"
const RUMOR_TARGET_ID := "bar"
const PUNCHLINE_ID := "small_underground_casino"
const TRAVELER_ID := "dave_bus_regular"

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
	var selected := _select_production_run(library)
	var run_state: RunState = selected.get("run_state")
	var generator: RunGenerator = selected.get("generator")
	seed_text = str(selected.get("seed", seed_text))
	if run_state == null or generator == null:
		_require(false, "The requested production seed did not spawn Police Sweep with a live traveler itinerary.")
		_finish({"selected_seed": seed_text})
		return

	# Visit a real scenario-backed venue. The selector must persist the canonical
	# scenario chosen when the node is generated.
	generator.next_environment(run_state, RUMOR_VENUE_ID, true)
	var source_scenario := run_state.scenario_for_node(RUMOR_VENUE_ID)
	_require(run_state.current_world_node_id() == RUMOR_VENUE_ID, "Production travel did not enter the rumor venue.")
	_require(not source_scenario.is_empty(), "The visited rumor venue did not retain its selected scenario.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(source_scenario.get("id", "")), "The visited rumor venue applied a different scenario than Town State selected.")

	# Ask Town State for a rendered rumor backed by its live registry, then hear it
	# through RunState so the world map receives the distinct heard tier.
	var scenario_rumor: Dictionary = {}
	for rumor_value in run_state.rumors_for_venue(RUMOR_VENUE_ID, "street", 64):
		if typeof(rumor_value) != TYPE_DICTIONARY:
			continue
		var rumor: Dictionary = rumor_value
		if str(rumor.get("class", "")) == "scenario" and str(rumor.get("target_node_id", "")) == RUMOR_TARGET_ID:
			scenario_rumor = rumor
			break
	_require(not scenario_rumor.is_empty(), "The production rumor registry did not render the target scenario rumor at the source venue.")
	_require(not scenario_rumor.is_empty() and run_state.town_state.rumor_trace_is_live(scenario_rumor), "The rendered scenario rumor was not backed by live Town State truth.")
	var heard := run_state.hear_rumor(str(scenario_rumor.get("id", "")))
	var heard_node := WorldMapScript.node_metadata_by_id(run_state.world_map, RUMOR_TARGET_ID)
	var route := library.route(RUMOR_TARGET_ID)
	var heard_preview := run_state.travel_route_preview(route, library.environment_archetype(RUMOR_TARGET_ID), {}, false)
	_require(str(heard.get("fact_id", "")) == str(scenario_rumor.get("fact_id", "")), "RunState did not hear the exact truth-sourced rumor offered at the venue.")
	_require(not _dict(heard_node.get("heard", {})).is_empty() and not bool(heard_node.get("scouted", false)), "Hearing the rumor did not upgrade the other map node to heard-only state.")
	_require(str(heard_preview.get("level", "")) == "heard" and _dict(heard_preview.get("heard_rumor", {})).get("fact_id", "") == heard.get("fact_id", ""), "The target route preview did not consume the heard-tier rumor payload.")
	_require(not heard_preview.has("game_ids") and not heard_preview.has("service_ids"), "The heard-tier route preview leaked full scouting fields.")

	# Advance the production town clock exactly to Dave's next itinerary boundary.
	var traveler_before := run_state.traveler_state(TRAVELER_ID)
	var traveler_before_node := str(traveler_before.get("node_id", ""))
	var traveler_depart_action := int(traveler_before.get("depart_action", 0))
	_require(not traveler_before.is_empty(), "The production traveler itinerary had no active Dave segment.")
	run_state.advance_environment_turns(maxi(1, traveler_depart_action - int(run_state.town_state.action_index)))
	var traveler_after := run_state.traveler_state(TRAVELER_ID)
	_require(not traveler_after.is_empty() and str(traveler_after.get("node_id", "")) != traveler_before_node, "The traveler itinerary did not advance at its production action boundary.")

	# Bring the same run to a live Police Sweep segment, then cross one movement
	# boundary and verify the node it left exposes the authored swept window.
	var sweep_track := run_state.town_state.police_sweep.snapshot()
	var sweep_before := run_state.town_state.sweep_internal_status()
	var sweep_start_action := int(sweep_track.get("start_action", 0))
	if int(run_state.town_state.action_index) < sweep_start_action:
		run_state.advance_environment_turns(sweep_start_action - int(run_state.town_state.action_index))
	sweep_before = run_state.town_state.sweep_internal_status()
	var swept_node_id := str(sweep_before.get("current_node_id", ""))
	var sweep_segment_before := int(sweep_before.get("segment_index", -1))
	var sweep_move_action := int(sweep_before.get("next_move_action", 0))
	_require(bool(sweep_before.get("active", false)) and not swept_node_id.is_empty(), "Police Sweep did not become active on its production track.")
	run_state.advance_environment_turns(maxi(1, sweep_move_action - int(run_state.town_state.action_index)))
	var sweep_after := run_state.town_state.sweep_internal_status()
	var swept_window := run_state.swept_window(swept_node_id)
	_require(int(sweep_after.get("segment_index", -1)) > sweep_segment_before, "Police Sweep did not advance to its next production track segment.")
	_require(bool(swept_window.get("cheat_window_open", false)) and int(swept_window.get("remaining_actions", 0)) > 0, "The departed Sweep node did not expose its authored swept window.")

	# Enter the rumored node after hearing it. Its generated scenario identity must
	# be the exact truth named by the rumor, proving scenario selection composes
	# across multiple visited nodes in this run.
	generator.next_environment(run_state, RUMOR_TARGET_ID, true)
	var target_scenario := run_state.scenario_for_node(RUMOR_TARGET_ID)
	_require(run_state.current_world_node_id() == RUMOR_TARGET_ID, "Production travel did not enter the heard scenario node.")
	_require(str(target_scenario.get("id", "")) == str(heard.get("source_id", "")), "The entered node did not consume the exact scenario named by its truth-sourced rumor.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(target_scenario.get("id", "")), "The heard node's selected scenario was not applied to its generated environment.")
	_require(str(source_scenario.get("id", "")) != "" and str(target_scenario.get("id", "")) != "", "Scenario selection did not coexist across both visited nodes.")

	# Finally visit The Punchline through the same generator. The shipped Side Door
	# event discovers L2 from L1, and the production layer transition enters it.
	generator.next_environment(run_state, PUNCHLINE_ID, true)
	var punchline_scenario := run_state.scenario_for_node(PUNCHLINE_ID)
	_require(str(run_state.current_environment.get("current_layer_id", "")) == "club", "The Punchline did not begin on its public L1 club layer.")
	_require(not punchline_scenario.is_empty() and str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "The Punchline lost its Tier-2 scenario while entering L1.")
	var side_door: EventModule = EventModuleScript.new()
	side_door.setup(library.event("side_door"), library)
	var discovery_result := side_door.resolve(run_state, run_state.current_environment, "punchline_password")
	_require(bool(discovery_result.get("ok", false)) and bool(_dict(run_state.current_environment.get("layer_discovery", {})).get("casino", false)), "The shipped L1 Side Door choice did not discover Punchline L2.")
	var layer_result := generator.enter_environment_layer(run_state, "casino", false)
	_require(bool(layer_result.get("ok", false)) and str(run_state.current_environment.get("current_layer_id", "")) == "casino", "The production layer transition did not enter discovered Punchline L2.")
	_require(str(run_state.current_environment.get("scenario_id", "")) == str(punchline_scenario.get("id", "")), "Punchline L2 entry lost the selected Tier-2 scenario.")

	_finish({
		"selected_seed": seed_text,
		"scenarios": {
			RUMOR_VENUE_ID: str(source_scenario.get("id", "")),
			RUMOR_TARGET_ID: str(target_scenario.get("id", "")),
			PUNCHLINE_ID: str(punchline_scenario.get("id", "")),
		},
		"rumor": {
			"fact_id": str(heard.get("fact_id", "")),
			"source_venue": RUMOR_VENUE_ID,
			"target_node": RUMOR_TARGET_ID,
			"preview_level": str(heard_preview.get("level", "")),
		},
		"traveler": {
			"character_id": TRAVELER_ID,
			"before_node": traveler_before_node,
			"after_node": str(traveler_after.get("node_id", "")),
		},
		"police_sweep": {
			"departed_node": swept_node_id,
			"segment_before": sweep_segment_before,
			"segment_after": int(sweep_after.get("segment_index", -1)),
			"window_remaining_actions": int(swept_window.get("remaining_actions", 0)),
		},
		"punchline": {
			"l1": "club",
			"l2": str(run_state.current_environment.get("current_layer_id", "")),
			"discovery_method": "punchline_password",
		},
	})


func _select_production_run(library: ContentLibrary) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var sweep := run_state.town_state.police_sweep.snapshot()
	var traveler := run_state.traveler_state(TRAVELER_ID)
	if _array(sweep.get("segments", [])).is_empty() or traveler.is_empty():
		return {}
	if int(traveler.get("depart_action", 0)) >= int(sweep.get("end_action", 0)) - 1:
		return {}
	return {"seed": seed_text, "run_state": run_state, "generator": generator}


func _finish(details: Dictionary) -> void:
	var report := {
		"tool": "wave_b_composition_probe",
		"passed": failures.is_empty(),
		"details": details,
		"failures": failures.duplicate(),
	}
	_write_report(report)
	print("WAVE_B_COMPOSITION %s seed=%s traveler=%s sweep=%s punchline=%s report=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		str(details.get("selected_seed", seed_text)),
		JSON.stringify(details.get("traveler", {})),
		JSON.stringify(details.get("police_sweep", {})),
		JSON.stringify(details.get("punchline", {})),
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


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


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
		failures.append("Could not write composition report: %s." % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
