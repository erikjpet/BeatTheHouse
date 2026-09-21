extends SceneTree

# Wave-B audit for the real tier-1 scenario selector and generated overlays.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const EXPECTED := {
	"corner_store": ["corner_store_delivery_day", "corner_store_lotto_fever", "corner_store_aftermath", "corner_store_dead_shift"],
	"back_alley": ["back_alley_street_craps", "back_alley_cruiser_parked", "back_alley_fence_night"],
	"motel": ["motel_conventioneers", "motel_stakeout", "motel_weekly_rates"],
	"bar": ["bar_wake", "bar_fight_night", "bar_payday_rush", "bar_lock_in"],
	"gas_station_casino": ["gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift"],
}

var output_path := "res://.tmp/tier1_scenario_audit.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append(str(error_value))
	var reached: Dictionary = {}
	var selections: Array = []
	for seed_index in range(20):
		var seed_text := "TIER1-REACH-%02d" % seed_index
		var run_state := RunStateScript.new()
		run_state.start_new(seed_text)
		var generator := RunGeneratorScript.new(library)
		for archetype_id_value in EXPECTED.keys():
			var archetype_id := str(archetype_id_value)
			var selected: Dictionary = generator.call("_select_scenario", run_state, archetype_id, run_state.create_rng("tier1_reach:%s" % archetype_id))
			var scenario_id := str(selected.get("id", ""))
			if not scenario_id.is_empty():
				reached[scenario_id] = int(reached.get(scenario_id, 0)) + 1
			var tags := _string_array(selected.get("town_weight_tags", []))
			selections.append({
				"seed": seed_text,
				"archetype_id": archetype_id,
				"scenario_id": scenario_id,
				"town_weight_tags": tags,
				"town_multiplier": run_state.scenario_weight_multiplier(archetype_id, scenario_id, tags),
			})
	var expected_ids: Array = []
	for ids_value in EXPECTED.values():
		expected_ids.append_array(ids_value as Array)
	for scenario_id_value in expected_ids:
		if not reached.has(str(scenario_id_value)):
			failures.append("20-seed selector sweep starved %s." % str(scenario_id_value))
	var smoke: Array = []
	for archetype_id_value in EXPECTED.keys():
		var archetype_id := str(archetype_id_value)
		var scenario_ids: Array = EXPECTED.get(archetype_id, [])
		for smoke_index in range(mini(2, scenario_ids.size())):
			var scenario_id := str(scenario_ids[smoke_index])
			var smoke_run := RunStateScript.new()
			smoke_run.start_new("TIER1-SMOKE-%s" % scenario_id)
			var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype(archetype_id), 1, smoke_run.create_rng("smoke"), library, {}, library.scenario(scenario_id)).to_dict()
			smoke.append({
				"archetype_id": archetype_id,
				"scenario_id": scenario_id,
				"stake_floor": int(_dict(environment.get("economic_profile", {})).get("stake_floor", 0)),
				"stake_ceiling": int(_dict(environment.get("economic_profile", {})).get("stake_ceiling", 0)),
				"event_ids": _string_array(environment.get("event_ids", [])),
				"presentation": _dict(environment.get("scenario_presentation", {})),
				"music_profile": _dict(environment.get("music_profile", {})),
				"security_profile": _dict(environment.get("security_profile", {})),
				"hook_flags": _dict(environment.get("scenario_hook_flags", {})),
			})
	var fight_run := RunStateScript.new()
	fight_run.start_new("TIER1-FIGHT-SAVE")
	var fight_environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("bar"), 1, fight_run.create_rng("fight"), library, {}, library.scenario("bar_fight_night")).to_dict()
	fight_environment["world_node_id"] = "bar"
	fight_run.set_environment(fight_environment)
	fight_run.advance_environment_turns(4)
	var fight_restored := RunStateScript.new()
	fight_restored.from_dict(fight_run.to_dict())
	var fight_mid_bout_ok := int(fight_restored.current_environment.get("scenario_phase_index", -1)) == 1 and int(fight_restored.current_environment.get("scenario_phase_action_counter", -1)) == 1
	if not fight_mid_bout_ok:
		failures.append("Fight Night did not restore mid-bout at phase 1 counter 1.")
	fight_restored.advance_environment_turns(3)
	var fight_aftermath_ok := int(fight_restored.current_environment.get("scenario_phase_index", -1)) == 2
	if not fight_aftermath_ok:
		failures.append("Fight Night did not reach aftermath after restore.")
	var tutorial_config := library.challenge_config_for("tutorial_first_card", "TIER1-TUTORIAL-AUDIT")
	var tutorial_run := RunStateScript.new()
	tutorial_run.start_new("TIER1-TUTORIAL-AUDIT", tutorial_config)
	var tutorial_generator := RunGeneratorScript.new(library)
	tutorial_generator.next_environment(tutorial_run)
	tutorial_generator.next_environment(tutorial_run, "corner_store", true)
	var tutorial_scenario := tutorial_run.scenario_for_node("corner_store")
	var tutorial_ok := str(tutorial_scenario.get("id", "")) == "corner_store_delivery_day" and _dict(tutorial_run.current_environment.get("scenario_exclusive_opportunity", {})).is_empty() and _dict(tutorial_run.current_environment.get("scenario_hook_flags", {})).is_empty()
	if not tutorial_ok:
		failures.append("Tutorial did not store the neutral Delivery Day identity without gameplay mutations.")
	var report := {
		"passed": failures.is_empty(),
		"expected_count": expected_ids.size(),
		"reached_count": reached.size(),
		"reach_counts": reached,
		"selections": selections,
		"two_per_archetype_smoke": smoke,
		"fight_night": {"mid_bout_save_load": fight_mid_bout_ok, "aftermath_after_restore": fight_aftermath_ok},
		"tutorial_neutral_pin": {"passed": tutorial_ok, "scenario_id": str(tutorial_scenario.get("id", ""))},
		"failures": failures,
	}
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write tier-1 scenario audit: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TIER1_SCENARIO_AUDIT %s reached=%d/%d smoke=%d report=%s" % ["PASS" if failures.is_empty() else "FAIL", reached.size(), expected_ids.size(), smoke.size(), output_path])
	for failure_value in failures:
		push_error(str(failure_value))
	quit(0 if failures.is_empty() else 1)


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result
