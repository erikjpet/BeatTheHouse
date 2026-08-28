extends SceneTree

const PACKAGE_PATH := "res://data/games/rituals/craps06_3_sequences.json"
const MODULE_PATH := "res://scripts/games/craps.gd"
const CrapsGameScript := preload("res://scripts/games/craps.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	var package := _load_json(PACKAGE_PATH)
	_check_package(package)
	_check_module(FileAccess.get_file_as_string(MODULE_PATH))
	_check_executable_sequences(package)
	_check_legal_boundary_and_restore_clock()
	if failures.is_empty():
		print("CRAPS06_3_DEPTH_CONTRACT PASS profiles=5 contract=game_ritual/1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1 or typeof((parsed as Array)[0]) != TYPE_DICTIONARY:
		failures.append("Ritual package is not a one-record JSON data array.")
		return {}
	return (parsed as Array)[0] as Dictionary


func _check_package(package: Dictionary) -> void:
	if str(package.get("contract", "")) != "game_ritual/1":
		failures.append("Ritual package does not consume frozen game_ritual/1.")
	if str(package.get("contract_head", "")) != "a2760d816c781e711ff0923c296f97b786662453":
		failures.append("Ritual package is not pinned to the owner-frozen contract head.")
	var profiles: Array = package.get("profiles", []) if typeof(package.get("profiles", [])) == TYPE_ARRAY else []
	var expected := ["craps.ordinary_casino", "craps.hot_high_stakes", "craps.security_audit", "craps.ordinary_street", "craps.interrupted_street"]
	var seen: Array[String] = []
	for value in profiles:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var profile := value as Dictionary
		seen.append(str(profile.get("id", "")))
		for key in ["initial_phase", "phases", "required_actions", "actors", "objects", "material_operations", "required_facts"]:
			if not profile.has(key) or (typeof(profile.get(key)) == TYPE_ARRAY and (profile.get(key) as Array).is_empty()):
				failures.append("%s lacks %s." % [str(profile.get("id", "profile")), key])
		if not (profile.get("phases", []) as Array).has(str(profile.get("initial_phase", ""))):
			failures.append("%s initial phase is unreachable." % str(profile.get("id", "profile")))
	if seen != expected:
		failures.append("Required five-profile order/identity changed: %s" % JSON.stringify(seen))
	var persistence: Dictionary = package.get("persistence", {}) if typeof(package.get("persistence", {})) == TYPE_DICTIONARY else {}
	for class_id in ["authoritative", "derived", "transient", "one_shot"]:
		if not persistence.has(class_id):
			failures.append("Persistence class %s is absent." % class_id)
	if not bool((package.get("rejection_policy", {}) as Dictionary).get("side_effect_free", false)):
		failures.append("Rejections are not declared side-effect-free.")


func _check_module(source: String) -> void:
	var required_tokens := [
		"craps_remove", "craps_undo", "craps_repeat", "craps_rebet",
		"craps_throw_origin", "THROW_MIN_DISTANCE", "THROW_MAX_DISTANCE",
		"available_funds", "at_risk_working_stake", "last_returned_stake", "last_payout",
		"street_warning", "street_lookout_warning", "\"dispersal\"",
		"content_fingerprint", "receipt_key", "ritual_sequence",
	]
	for token in required_tokens:
		if source.find(token) < 0:
			failures.append("Craps implementation lacks required seam: %s" % token)
	if source.find("Time.get_ticks_msec") >= 0:
		failures.append("Craps authoritative module reads wall-clock ticks.")


func _check_executable_sequences(package: Dictionary) -> void:
	for value in package.get("profiles", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = value
		var phases: Array = profile.get("phases", [])
		var sequence: Array = profile.get("sequence", [])
		if sequence.is_empty():
			failures.append("%s has no executable sequence." % str(profile.get("id", "profile")))
			continue
		var current := str(profile.get("initial_phase", ""))
		for step_value in sequence:
			if typeof(step_value) != TYPE_DICTIONARY:
				failures.append("%s has a non-record sequence step." % str(profile.get("id", "profile")))
				continue
			var step: Dictionary = step_value
			if str(step.get("from", "")) != current:
				failures.append("%s sequence expected %s but authored %s." % [str(profile.get("id", "profile")), current, str(step.get("from", ""))])
			var action := str(step.get("action", ""))
			if not (profile.get("required_actions", []) as Array).has(action):
				failures.append("%s sequence uses undeclared action %s." % [str(profile.get("id", "profile")), action])
			current = str(step.get("to", ""))
			if not phases.has(current):
				failures.append("%s sequence reached undeclared phase %s." % [str(profile.get("id", "profile")), current])


func _check_legal_boundary_and_restore_clock() -> void:
	var game = CrapsGameScript.new()
	var games_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	for definition_value in games_value if typeof(games_value) == TYPE_ARRAY else []:
		if typeof(definition_value) == TYPE_DICTIONARY and str((definition_value as Dictionary).get("id", "")) == "craps":
			game.setup(definition_value as Dictionary)
			break
	if game.get_id() != "craps":
		failures.append("Executable proof could not load the shipped craps definition.")
		return
	var run_state = RunStateScript.new()
	run_state.start_new("CRAPS06-3-EXECUTABLE")
	run_state.bankroll = 100000
	run_state.grand_casino_chips = 10000
	run_state.simulation_msec = 26000
	var environment := {
		"id": "craps06_3_executable",
		"archetype_id": "grand_casino",
		"kind": "boss",
		"game_ids": ["craps"],
		"depth": 6,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 1000},
		"security_profile": {"strictness": "high"},
	}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("craps06_3_table"))
	environment["game_states"] = {game.get_id(): table}
	run_state.current_environment = environment
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	var pass_index := -1
	for index in range((surface.get("bet_targets", []) as Array).size()):
		var target: Dictionary = (surface.get("bet_targets", []) as Array)[index]
		if str(target.get("id", "")) == "pass_line":
			pass_index = index
			break
	var bet_command: Dictionary = game.surface_action_command("craps_bet", pass_index, false, {"selected_chip": 5}, run_state, environment)
	var bet_ui: Dictionary = bet_command.get("ui_state", {})
	var roll_command: Dictionary = game.surface_action_command("craps_roll", 0, false, bet_ui, run_state, environment)
	if not bool(roll_command.get("resolve", false)) or str(roll_command.get("action_id", "")) != "roll_craps":
		failures.append("Normal legal craps_roll no longer resolves through roll_craps.")
	table["last_roll"] = {
		"dice": [3, 4], "total": 7, "animation_id": "craps06_3:restore",
		"resolved_at_msec": run_state.simulation_time_msec(),
		"throw_trajectory": game._throw_trajectory(Vector2(40, -160)),
	}
	environment["game_states"] = {game.get_id(): table}
	run_state.current_environment = environment
	var active_ui := {"surface_time_msec": run_state.simulation_time_msec() + 100, "surface_presentation_time_msec": run_state.simulation_time_msec() + 5000}
	var restored = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var active: Dictionary = game.surface_state(restored, restored.current_environment, active_ui)
	if str(active.get("phase", "")) != "rolling" or str(active.get("ritual_phase", "")) != "bounce_read":
		failures.append("Saved roll did not restore legacy rolling plus ritual bounce/read phases.")
	var hostile: Dictionary = game.surface_action_command("craps_roll", 0, false, bet_ui.merged(active_ui, true), run_state, environment)
	if bool(hostile.get("resolve", false)) or bool(hostile.get("direct_resolve", false)):
		failures.append("Hostile double-roll input resolved during the saved animation.")
	var duration := int(game._config().get("roll_animation_duration_msec", 0))
	active_ui["surface_time_msec"] = run_state.simulation_time_msec() + duration
	var expired: Dictionary = game.surface_state(run_state, environment, active_ui)
	if str(expired.get("phase", "")) != "betting" or str(expired.get("ritual_phase", "")) != "betting":
		failures.append("Craps presentation did not settle back to betting at the finite boundary.")
	var trajectory: Dictionary = table.get("last_roll", {}).get("throw_trajectory", {})
	if (trajectory.get("contacts", []) as Array) != ["far_wall", "die_pair"] or (trajectory.get("die_a", []) as Array).size() < 5 or (trajectory.get("die_b", []) as Array).size() < 5:
		failures.append("Saved throw trajectory lacks wall/contact/bounce/separation/rest evidence.")
	for seed_index in range(10):
		var vector := Vector2(seed_index * 11 - 45, -120 - seed_index * 7)
		if JSON.stringify(game._throw_trajectory(vector)) != JSON.stringify(game._throw_trajectory(vector)):
			failures.append("Throw presentation is not deterministic for profile %d." % seed_index)
	var pointer_ui: Dictionary = game.surface_pointer_command("craps_throw", 0, "begin", Vector2(420, 240), bet_ui, run_state, environment).get("ui_state", {})
	pointer_ui = game.surface_pointer_command("craps_throw", 0, "move", Vector2(445, 180), pointer_ui, run_state, environment).get("ui_state", {})
	var pointer_end: Dictionary = game.surface_pointer_command("craps_throw", 0, "end", Vector2(465, 120), pointer_ui, run_state, environment)
	if not bool(pointer_end.get("direct_resolve", false)) or str(pointer_end.get("action_id", "")) != str(roll_command.get("action_id", "")) or int(pointer_end.get("set_stake", -1)) != int(roll_command.get("set_stake", -2)):
		failures.append("Pointer throw and keyboard/controller auto-throw do not share one authoritative boundary.")
	var energy_materializations: Array[String] = []
	for energy in [0, 50, 80]:
		var tier_table := table.duplicate(true)
		tier_table["table_energy"] = energy
		energy_materializations.append(JSON.stringify({"actors": game._ritual_actors(tier_table, false), "objects": game._ritual_scene_objects(tier_table, false, "betting")}))
	if energy_materializations[0] == energy_materializations[1] or energy_materializations[1] == energy_materializations[2] or energy_materializations[0] == energy_materializations[2]:
		failures.append("Every Craps energy tier must materially change actors or scene objects.")
