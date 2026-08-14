extends RefCounted

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const BASELINE_PATH := "res://scripts/tests/fixtures/punchline_l2_pre_rework_baseline.json"
const PUNCHLINE_ID := "small_underground_casino"
const CANONICAL_FIELDS := [
	"visual_context", "objective_hint", "layout", "security_profile", "music_profile",
	"economic_profile", "game_pool", "game_count", "item_pool", "item_count",
	"event_pool", "event_scopes", "event_count", "service_pool", "lender_hooks",
	"lender_count", "suspicion_cues", "travel_hooks", "local_narrative_flags", "moods",
]


static func check(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype(PUNCHLINE_ID)
	var layers := _dict(archetype.get("layers", {}))
	if str(archetype.get("display_name", "")) != "The Punchline" or str(archetype.get("default_layer_id", "")) != "club" or layers.size() != 3:
		failures.append("Punchline archetype did not expose one node with club/casino/back_room layers.")
		return
	_check_public_identity(library, archetype, failures)
	_check_l2_baseline(layers, failures)
	_check_generation_and_tutorial(library, archetype, failures)
	_check_discovery_and_save(library, archetype, failures)
	_check_back_room_access(library, archetype, failures)
	_check_legacy_migration(library, archetype, failures)
	_check_shortcut_edge(library, failures)
	_check_scenario_layer_scope(failures)


static func _check_public_identity(library: ContentLibrary, archetype: Dictionary, failures: Array) -> void:
	var route := library.route(PUNCHLINE_ID)
	var public_copy := " ".join([
		str(archetype.get("display_name", "")),
		str(archetype.get("kind", "")),
		str(_dict(archetype.get("visual_context", {})).get("description", "")),
		str(archetype.get("objective_hint", "")),
		str(route.get("label", "")),
		str(route.get("description", "")),
		str(_dict(route.get("decision", {})).get("offer", "")),
		str(_dict(library.route("gas_station_casino").get("decision", {})).get("tradeoff", "")),
	]).to_lower()
	if not public_copy.contains("comedy") or public_copy.contains("casino") or public_copy.contains("underground") or public_copy.contains("basement"):
		failures.append("Punchline public map/preview identity leaked the hidden casino or omitted the comedy-club cover.")
	if not _array(archetype.get("game_pool", [])).is_empty() or _array(archetype.get("service_pool", [])) != ["punchline_two_drink_minimum"]:
		failures.append("Punchline club did not retain its lean no-games/two-drink public layer.")
	var service := library.service("punchline_two_drink_minimum")
	if service.is_empty() or str(service.get("category", "")) != "alcohol":
		failures.append("Punchline two-drink-minimum service was not registered through the drink-service contract.")


static func _check_l2_baseline(layers: Dictionary, failures: Array) -> void:
	var baseline := _load_dictionary(BASELINE_PATH)
	var expected := _dict(baseline.get("canonical_fields", {}))
	var casino := _dict(layers.get("casino", {}))
	for field_name in CANONICAL_FIELDS:
		if not _json_equal(casino.get(field_name), expected.get(field_name)):
			failures.append("Punchline L2 changed pre-rework canonical field %s (baseline %s)." % [field_name, str(baseline.get("baseline_sha256", "missing"))])
	if _array(casino.get("game_pool", [])) != ["slot", "blackjack", "video_poker"] or int(_dict(casino.get("economic_profile", {})).get("stake_floor", -1)) != 10:
		failures.append("Punchline L2 gameplay pool/stakes no longer match the shipped underground venue.")


static func _check_generation_and_tutorial(library: ContentLibrary, archetype: Dictionary, failures: Array) -> void:
	var normal_run := RunStateScript.new()
	normal_run.start_new("PUNCHLINE-NORMAL")
	var normal := EnvironmentInstanceScript.from_archetype(archetype, 2, normal_run.create_rng("punchline"), library).to_dict()
	if str(normal.get("current_layer_id", "")) != "club" or not _array(normal.get("game_ids", [])).is_empty() or not bool(_dict(normal.get("layer_discovery", {})).get("club", false)) or bool(_dict(normal.get("layer_discovery", {})).get("casino", true)):
		failures.append("Ordinary Punchline generation did not begin in the public undiscovered club layer.")
	if _array(normal.get("layer_ambient_lines", [])).size() < 4 or str(normal.get("layer_ambient_line", "")).is_empty():
		failures.append("Punchline club did not generate its deterministic rotating stage bit.")
	var object_rects := _dict(_dict(normal.get("layout", {})).get("object_rects", {}))
	if not object_rects.has("environment_layer:ambient") or not object_rects.has("environment_layer:casino"):
		failures.append("Punchline layer fixtures were not assigned stable transition-time layout surfaces.")
	normal_run.set_environment(normal)
	var ambient_before := str(normal_run.current_environment.get("layer_ambient_line", ""))
	normal_run.advance_environment_turns(1)
	if str(normal_run.current_environment.get("layer_ambient_line", "")) != ambient_before:
		failures.append("Punchline ambient stage bit rotated before its action boundary.")
	normal_run.advance_environment_turns(1)
	if str(normal_run.current_environment.get("layer_ambient_line", "")) == ambient_before:
		failures.append("Punchline ambient stage bit did not rotate on its authored action boundary.")
	var history_before := normal_run.environment_history.size()
	var bankroll_before := normal_run.bankroll
	var clock_before := normal_run.game_clock_minutes
	normal_run.discover_environment_layer("casino", "fixture")
	if not bool(RunGeneratorScript.new(library).enter_environment_layer(normal_run, "casino", true).get("ok", false)) or normal_run.environment_history.size() != history_before or normal_run.bankroll != bankroll_before or normal_run.game_clock_minutes != clock_before:
		failures.append("Punchline interior navigation behaved like world travel or charged the run.")
	var tutorial_config := library.challenge_config_for("tutorial_first_card", "IGNORED")
	var tutorial_run := RunStateScript.new()
	tutorial_run.start_new("PUNCHLINE-TUTORIAL", tutorial_config)
	var tutorial := EnvironmentInstanceScript.from_archetype(archetype, 2, tutorial_run.create_rng("punchline"), library, tutorial_config).to_dict()
	if str(tutorial.get("current_layer_id", "")) != "casino" or _array(tutorial.get("game_ids", [])) != ["blackjack"] or _array(tutorial.get("event_ids", [])) != ["tutorial_grand_casino_invitation"]:
		failures.append("Tutorial compatibility override did not enter Punchline L2 with the shipped blackjack/invitation flow.")
	if int(_dict(tutorial.get("economic_profile", {})).get("stake_floor", -1)) != 10 or int(_dict(tutorial.get("economic_profile", {})).get("game_stake_floor_overrides", {}).get("blackjack", -1)) != 5:
		failures.append("Tutorial Punchline L2 lost the pre-rework underground stake contract.")


static func _check_discovery_and_save(library: ContentLibrary, archetype: Dictionary, failures: Array) -> void:
	var event_module := EventModuleScript.new()
	event_module.setup(library.event("side_door"), library)
	for choice_id in ["punchline_password", "punchline_regular_nod"]:
		var run_state := RunStateScript.new()
		run_state.start_new("PUNCHLINE-DISCOVERY-%s" % choice_id)
		run_state.set_environment(EnvironmentInstanceScript.from_archetype(archetype, 2, run_state.create_rng("punchline"), library).to_dict())
		var club_choices := _choice_ids(event_module.choices(run_state, run_state.current_environment))
		if not club_choices.has("punchline_password") or not club_choices.has("punchline_regular_nod") or club_choices.has("cheap_route") or club_choices.has("dark_route"):
			failures.append("Punchline club did not offer two canonical discovery paths while hiding legacy route choices.")
			return
		var result := event_module.resolve(run_state, run_state.current_environment, choice_id)
		if not bool(result.get("ok", false)) or not bool(_dict(run_state.current_environment.get("layer_discovery", {})).get("casino", false)):
			failures.append("Punchline discovery choice %s did not persist the L2 seam." % choice_id)
			continue
		var discovery_log_count := _story_type_count(run_state.story_log, "environment_layer_discovered")
		var generator := RunGeneratorScript.new(library)
		var entered := generator.enter_environment_layer(run_state, "casino", false)
		if not bool(entered.get("ok", false)) or str(run_state.current_environment.get("current_layer_id", "")) != "casino":
			failures.append("Punchline discovery choice %s did not open L2." % choice_id)
			continue
		var casino_choices := _choice_ids(event_module.choices(run_state, run_state.current_environment))
		if not casino_choices.has("cheap_route") or not casino_choices.has("dark_route") or casino_choices.has("punchline_password"):
			failures.append("Legacy side-door route choices did not survive outside Punchline L1.")
		var restored := RunStateScript.new()
		restored.from_dict(run_state.to_dict())
		if str(restored.current_environment.get("current_layer_id", "")) != "casino" or not bool(_dict(restored.current_environment.get("layer_discovery", {})).get("casino", false)):
			failures.append("Punchline save/load did not restore the active L2 and discovery state.")
		var stored_games := _dict(restored.current_environment.get("game_states", {}))
		stored_games["layer_fixture"] = {"choice_id": choice_id}
		restored.current_environment["game_states"] = stored_games
		if not bool(generator.enter_environment_layer(restored, "club", false).get("ok", false)) or not bool(generator.enter_environment_layer(restored, "casino", false).get("ok", false)):
			failures.append("Discovered Punchline L2 did not become one-click re-entry.")
		elif str(_dict(_dict(restored.current_environment.get("game_states", {})).get("layer_fixture", {})).get("choice_id", "")) != choice_id:
			failures.append("Punchline layer re-entry regenerated and lost persisted game state.")
		restored.discover_environment_layer("casino", "repeat")
		if _story_type_count(restored.story_log, "environment_layer_discovered") != discovery_log_count:
			failures.append("Punchline re-entry repeated discovery presentation/logging.")


static func _check_back_room_access(library: ContentLibrary, archetype: Dictionary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("PUNCHLINE-L3")
	var casino := EnvironmentInstanceScript.from_archetype_layer(archetype, "casino", 2, run_state.create_rng("casino"), library).to_dict()
	casino["layer_discovery"] = {"club": true, "casino": true, "back_room": false}
	run_state.set_environment(casino)
	var denied := run_state.environment_layer_access_status("back_room")
	if bool(denied.get("available", false)) or not str(denied.get("reason", "")).to_lower().contains("rook"):
		failures.append("Punchline L3 did not deny a stranger politely through the Crew gate.")
	run_state.crew_add_trust("crew_rook", 10000, "punchline_test")
	if not bool(run_state.environment_layer_access_status("back_room").get("available", false)):
		failures.append("Punchline L3 did not open at made Crew standing.")
	var generator := RunGeneratorScript.new(library)
	if not bool(generator.enter_environment_layer(run_state, "back_room", false).get("ok", false)) or not _array(run_state.current_environment.get("game_ids", [])).is_empty() or not str(run_state.current_environment.get("layer_ambient_line", "")).contains("Rook"):
		failures.append("Punchline L3 did not enter as the minimal Rook shell.")
	var escort_run := RunStateScript.new()
	escort_run.start_new("PUNCHLINE-L3-ESCORT")
	escort_run.set_environment(casino)
	escort_run.story_flags["rook_escort_punchline_back_room"] = true
	if not bool(escort_run.environment_layer_access_status("back_room").get("available", false)):
		failures.append("Punchline L3 did not open from the authored Rook escort flag.")


static func _check_legacy_migration(library: ContentLibrary, archetype: Dictionary, failures: Array) -> void:
	var source_run := RunStateScript.new()
	source_run.start_new("PUNCHLINE-LEGACY")
	var legacy := EnvironmentInstanceScript.from_archetype_layer(archetype, "casino", 2, source_run.create_rng("casino"), library).to_dict()
	for key in ["environment_layer_schema_version", "current_layer_id", "default_layer_id", "layer_ids", "layer_display_name", "layer_transitions", "layer_discovery", "layer_states", "layer_ambient_lines", "layer_ambient_label", "layer_ambient_prop", "layer_ambient_rotate_actions", "layer_ambient_index", "layer_ambient_line"]:
		legacy.erase(key)
	legacy["display_name"] = "Pink Room Underground Casino"
	source_run.current_environment = legacy
	var restored := RunStateScript.new()
	restored.from_dict(source_run.to_dict())
	if int(restored.current_environment.get("environment_layer_schema_version", 0)) != 1 or str(restored.current_environment.get("current_layer_id", "")) != "casino" or str(restored.current_environment.get("display_name", "")) != "The Punchline" or not bool(_dict(restored.current_environment.get("layer_discovery", {})).get("casino", false)):
		failures.append("Pre-0.6 underground save did not migrate into discovered Punchline L2.")
	var snapshot_run := RunStateScript.new()
	snapshot_run.start_new("PUNCHLINE-LEGACY-SNAPSHOT")
	snapshot_run.world_map = WorldMapScript.new(library).build(snapshot_run, snapshot_run.create_rng("world"))
	snapshot_run.world_map = WorldMapScript.store_environment(snapshot_run.world_map, PUNCHLINE_ID, legacy)
	snapshot_run.current_environment = {}
	var snapshot_restored := RunStateScript.new()
	snapshot_restored.from_dict(snapshot_run.to_dict())
	var migrated_snapshot: Dictionary = WorldMapScript.new(library).preview_for_target(snapshot_restored.world_map, PUNCHLINE_ID)
	if int(migrated_snapshot.get("environment_layer_schema_version", 0)) != 1 or str(migrated_snapshot.get("current_layer_id", "")) != "casino" or not bool(_dict(migrated_snapshot.get("layer_discovery", {})).get("casino", false)):
		failures.append("Pre-0.6 underground world-map snapshot did not migrate eagerly into discovered Punchline L2.")


static func _check_shortcut_edge(library: ContentLibrary, failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("PUNCHLINE-WORLD-EDGE")
	var world_map := WorldMapScript.new(library).build(run_state, run_state.create_rng("world"))
	if WorldMapScript.edge_between(world_map, PUNCHLINE_ID, "grand_casino").is_empty():
		failures.append("World graph lost the guaranteed Punchline-to-Grand-Casino shortcut edge.")
		return
	world_map = WorldMapScript.enter_node(world_map, "grand_casino", {})
	world_map = WorldMapScript.enter_node(world_map, PUNCHLINE_ID, {})
	var route := WorldMapScript.new(library).route_for_target(world_map, PUNCHLINE_ID, "grand_casino")
	if route.is_empty() or _array(route.get("world_path", [])) != [PUNCHLINE_ID, "grand_casino"]:
		failures.append("Guaranteed Punchline-to-Grand-Casino shortcut edge was present but not traversable.")


static func _check_scenario_layer_scope(failures: Array) -> void:
	var state := ScenarioEngineScript.initial_state({
		"id": "punchline_layer_fixture",
		"archetype_id": PUNCHLINE_ID,
		"layer_id": "casino",
		"display_name": "Layer Fixture",
		"weight": 1,
		"mutations": {"presentation": {"signage_line": "PRIVATE"}},
	})
	if str(state.get("layer_id", "")) != "casino" or str(ScenarioEngineScript.public_snapshot(state).get("layer_id", "")) != "casino":
		failures.append("Scenario engine did not preserve its optional environment layer scope.")
	var club := ScenarioEngineScript.apply_to_archetype({"current_layer_id": "club"}, state)
	ScenarioEngineScript.attach_to_environment(club, state)
	if _dict(club.get("scenario_presentation", {})).has("signage_line"):
		failures.append("Casino-scoped scenario mutations leaked into Punchline L1.")
	var casino := ScenarioEngineScript.apply_to_archetype({"current_layer_id": "casino"}, state)
	ScenarioEngineScript.attach_to_environment(casino, state)
	if str(_dict(casino.get("scenario_presentation", {})).get("signage_line", "")) != "PRIVATE":
		failures.append("Casino-scoped scenario mutation did not attach to Punchline L2.")


static func _load_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _json_equal(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


static func _choice_ids(choices: Array) -> Array:
	var result: Array = []
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY:
			result.append(str((choice_value as Dictionary).get("id", "")))
	return result


static func _story_type_count(story_log: Array, type_id: String) -> int:
	var result := 0
	for entry_value in story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == type_id:
			result += 1
	return result
