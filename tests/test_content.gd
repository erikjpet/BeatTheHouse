extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var count := _check_directory("res://data", failures)
	var library := ContentLibrary.new()
	library.load()
	for failure in library.validation_errors:
		failures.append(str(failure))
	_check_crew_escort(library, failures)
	_check_shelter_signage(library, failures)
	_check_reward_packs_stay_out_of_ordinary_shops(library, failures)
	if count == 0 or library.games.is_empty() or not library.validation_complete:
		failures.append("The authored data catalog did not load.")
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_directory(path: String, failures: Array[String]) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("Cannot read " + path)
		return 0
	var count := 0
	for child in dir.get_directories():
		count += _check_directory(path.path_join(child), failures)
	for filename in dir.get_files():
		var file := path.path_join(filename)
		if filename.get_extension() == "json":
			count += 1
			var source := FileAccess.open(file, FileAccess.READ)
			if source == null:
				failures.append("Cannot open " + file)
				continue
			var parser := JSON.new()
			if parser.parse(source.get_as_text()) != OK:
				failures.append("%s:%d: %s" % [file, parser.get_error_line(), parser.get_error_message()])
		elif filename.get_extension() in ["tres", "tscn"]:
			count += 1
			if ResourceLoader.load(file) == null:
				failures.append("Cannot load " + file)
	return count


func _check_crew_escort(library: ContentLibrary, failures: Array[String]) -> void:
	var run := RunState.new()
	run.start_new("CORE-ROOK-ESCORT")
	var archetype := library.environment_archetype("small_underground_casino")
	var casino := EnvironmentInstance.from_archetype_layer(archetype, "casino", 2, run.create_rng("casino"), library)
	run.set_environment(casino.to_dict())
	run.discover_environment_layer("back_room", "remembered")
	var generator := RunGenerator.new(library)
	if bool(generator.enter_environment_layer(run, "back_room", false).get("ok", false)):
		failures.append("Remembering the Crew door granted access without a credential.")
		return

	# Rook's explicit invitation is an independent credential for this door.
	run.story_flags["rook_escort_punchline_back_room"] = true
	var restored := RunState.new()
	restored.from_dict(run.to_dict())
	var entered := generator.enter_environment_layer(restored, "back_room", false)
	if not bool(entered.get("ok", false)) or str(entered.get("access_method", "")) != "rook_escort":
		failures.append("The Crew door rejected a saved Rook escort: %s" % str(entered))
		return
	if restored.crew_reputation() != run.crew_reputation() \
			or bool(restored.crew_standing().get("heist_eligibility", {}).get("the_count", false)):
		failures.append("Entering with an escort granted rank or Count eligibility.")


func _check_shelter_signage(library: ContentLibrary, failures: Array[String]) -> void:
	var shelter_data := library.scenario("gas_station_storm_shelter")
	var mutations: Dictionary = shelter_data.get("mutations", {})
	var environment := {
		"scenario_presentation": mutations.get("presentation", {}),
		"scenario_sequence_state": {"status": "active"},
	}
	if not ScenarioEngine.active_presentation(environment).has("signage_line"):
		failures.append("An active shelter lost its scenario sign.")
	environment["scenario_sequence_state"] = {"status": "cleaned"}
	if ScenarioEngine.active_presentation(environment).has("signage_line"):
		failures.append("An expired shelter still advertised its active situation.")


func _check_reward_packs_stay_out_of_ordinary_shops(library: ContentLibrary, failures: Array[String]) -> void:
	var stock := library.shop_item_pool_for_challenge([])
	if stock.is_empty():
		failures.append("Reward-only items left ordinary shops with no stock.")
	for group_id in ["scenario_souvenirs", "crew_gear"]:
		var pack := library.content_group(group_id)
		for item_id in pack.get("item_ids", []):
			if not library.item_enabled_for_challenge(str(item_id)) or stock.has(item_id):
				failures.append("Reward-only item %s is disabled or offered in ordinary shops." % str(item_id))
