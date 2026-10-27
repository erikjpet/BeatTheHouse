extends SceneTree

# Synthetic private profile, exercised through the real Run Setup and Home map
# controls. No personal profile, bag opening, reward grant or player action replay.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Meta := preload("res://scripts/core/meta_collection_service.gd")

var failures: Array[String] = []
var checks := 0
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty() or OS.get_environment("BTH_META_COLLECTION_PATH").is_empty():
		push_error("Quick Start check requires fresh private distribution/profile roots")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var service := _profile_fixture()
	var owned_before := _ownership(service)
	var expected := service.normal_run_start_modifiers()
	_check(expected.get("meta_collection_carried_instance_ids", []) == [11, 12], "fixture packs the exact card and gear instances")
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.size = Vector2(1280, 720)
	for _frame in range(3):
		await process_frame
	app._ensure_full_content_library_loaded()
	app.meta_collection_service = service
	app.profile_inventory.tutorial_completed = true
	app.user_settings.coach_tips_enabled = false
	app.selected_challenge_id = ""
	app.selected_home_type_id = RunState.HOME_SELECTION_RANDOM
	app.selected_content_group_ids = app.library.default_content_group_ids()
	app.open_run_configuration()
	app.seed_input.text = "EQUIPPED-CARRY-REFERENCE"
	_check(app.run_config_start_button != null and not app.run_config_start_button.disabled, "normal Run Setup start control is enabled")
	app.run_config_start_button.pressed.emit()
	for _frame in range(3):
		await process_frame
	_check(app.run_state != null and not app.run_state.is_tutorial_run(), "Run Setup starts a normal run")
	if app.run_state == null:
		app.queue_free()
		_finish()
		return
	_check_run(app.run_state, expected, "Run Setup")
	var reference := _projection(app.run_state, expected)
	facts["run_setup"] = reference
	_check(_equal(_ownership(service), owned_before), "Run Setup leaves profile ownership/floats/gold unchanged")
	# Use the same Home -> Map -> Start Run -> Travel button callbacks as players.
	# Emitting the actual enabled button signal is native UI routing coverage,
	# not an OS pointer or deployed Web play claim.
	app.open_meta_home()
	for _frame in range(2):
		await process_frame
	_check(app._is_meta_session(), "Home opens as a meta session")
	_check(app.open_world_map(), "Home map opens")
	_check(app.select_world_map_node("start_run"), "Home map offers Start Run")
	for _frame in range(2):
		await process_frame
	_check(app.world_map_confirm_button != null and not app.world_map_confirm_button.disabled, "Home Quick Start confirmation control is enabled")
	app.world_map_confirm_button.pressed.emit()
	for _frame in range(3):
		await process_frame
	_check(app.run_state != null and not app._is_meta_session(), "Home Quick Start starts a normal run")
	_check_run(app.run_state, expected, "Home Quick Start")
	var quick := _projection(app.run_state, expected)
	facts["home_quick_start"] = quick
	_check(_equal(quick, reference), "Home Quick Start and Run Setup have identical bag/card/modifiers/effects")
	_check(_equal(_ownership(service), owned_before), "Quick Start neither grants nor removes profile possessions")
	var inventory_before: Array = app.run_state.inventory.duplicate(true)
	app._apply_meta_collection_loadout_to_run()
	app._apply_meta_collection_loadout_to_run()
	_check(_equal(app.run_state.inventory, inventory_before), "repeated existing loadout application does not duplicate inventory")
	_check(app.start_meta_quick_run(), "a second Quick Start succeeds")
	_check_run(app.run_state, expected, "Repeated Quick Start")
	_check(_equal(_projection(app.run_state, expected), reference), "a second run still carries each equipped instance once")
	_check(_equal(_ownership(service), owned_before), "repeated Quick Start preserves stored and carried profile instances")
	app.save_service.wait_for_async_save()
	_check(app.save_service.save_run(app.run_state, "quick_start_carry") == OK, "Quick Start run saves through SaveService")
	var restored: Variant = SaveService.new().load_run("quick_start_carry")
	_check(restored != null, "Quick Start run cold loads through SaveService")
	if restored != null:
		facts["cold_continue"] = _projection(restored, expected)
		_check_run(restored, expected, "Cold Continue")
		_check(_equal(_projection(restored, expected), reference), "cold load preserves exact card floats, bag identity and modifiers")
	var profile_cold := Meta.new()
	profile_cold.load()
	_check(_equal(_ownership(profile_cold), owned_before), "cold profile load preserves equipped and stored instances")
	# Tutorial is the material adjacent launch boundary: its explicit isolated
	# start must continue to exclude the real equipped loadout.
	_check(app.start_tutorial_run(), "tutorial entry remains available")
	_check(app.run_state.is_tutorial_run() and not app.run_state.meta_collection_enabled_for_run(), "tutorial remains isolated from equipped meta modifiers")
	_check(_meta_items(app.run_state).is_empty(), "tutorial does not acquire the profile card or gear")
	_check(_equal(_ownership(service), owned_before), "tutorial entry does not spend the profile loadout")
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _profile_fixture() -> MetaCollectionService:
	var service := Meta.new()
	var data := service.snapshot()
	data["housing_tier"] = Meta.HOUSING_MOTEL_ROOM
	data["meta_home"] = {"housing_tier": Meta.HOUSING_MOTEL_ROOM, "current_location": "home"}
	data["gold_balance"] = 25
	data["owned_containers"] = [{"item_id": "bag", "instance_id": 7, "capacity": 3}]
	data["owned_instances"] = [
		{"instance_id": 11, "itemdef_id": 9500, "potency": 1.0, "condition": 0.08, "resonance": 1.0, "usage": 1.0, "source": "grand_casino_players_card", "source_id": "high_roller_cashout", "instance_data": {"tier_reached": "gold", "seed": "CARRY-CARD"}},
		{"instance_id": 12, "itemdef_id": 1000, "potency": 0.8, "condition": 0.9, "resonance": 0.7, "usage": 0.96, "source": "run_victory", "source_id": "player_run", "source_rng_seed": "CARRY-GEAR"},
		{"instance_id": 13, "itemdef_id": 1001, "potency": 0.7, "condition": 0.8, "resonance": 0.6, "usage": 0.92, "source": "run_victory", "source_id": "player_run", "source_rng_seed": "STORED-GEAR"},
	]
	data["loadout"] = [11, 12]
	data["next_instance_id"] = 14
	var file := FileAccess.open(Meta.store_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	service.load()
	return service


func _ownership(service: MetaCollectionService) -> Dictionary:
	var data := service.snapshot()
	var result := {}
	for key in ["owned_instances", "owned_containers", "loadout", "unopened_bags", "gold_balance", "next_instance_id"]:
		result[key] = data.get(key)
	return result


func _check_run(run: RunState, expected: Dictionary, label: String) -> void:
	var modifiers := run.challenge_modifiers()
	for key in expected:
		_check(_equal(modifiers.get(key), expected[key]), "%s preserves %s" % [label, key])
	_check(_equal(_meta_items(run), expected.get("meta_collection_loadout", [])), label + " carries exact card/gear records once and excludes stored gear")
	_check(str(run.current_environment.get("archetype_id", "")) == Meta.HOUSING_MOTEL_ROOM, label + " starts at the equipped home")
	var containers := run.current_home_containers()
	_check(containers.size() == 1 and int(containers[0].get("meta_container_instance_id", -1)) == 7 and containers[0].get("items", []).size() == 2, label + " preserves bag7 with two packed items")


func _meta_items(run: RunState) -> Array:
	var result := []
	for item in run.inventory:
		if typeof(item) == TYPE_DICTIONARY and item.has("meta_collection"):
			result.append(item)
	return result


func _projection(run: RunState, expected: Dictionary) -> Dictionary:
	var modifiers := {}
	for key in expected:
		modifiers[key] = run.challenge_modifiers().get(key)
	var effects := {}
	for item in expected.get("meta_collection_loadout", []):
		for key in item.get("effect", {}):
			if typeof(item.effect[key]) in [TYPE_INT, TYPE_FLOAT]:
				effects[key] = run.item_effect_total(key)
	return {"modifiers": modifiers, "meta_items": _meta_items(run), "containers": run.current_home_containers(), "effect_totals": effects}


func _equal(left: Variant, right: Variant) -> bool:
	# JSON persistence may represent integer-valued numbers as floats. Compare
	# their exact numeric value while retaining every field, array and float.
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return left == right
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _equal(left[index], right[index]):
				return false
		return true
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]):
				return false
		return true
	return left == right


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Synthetic isolated profile; real Run Setup and Home map confirmation Button signals, actual run generation, repeated start, SaveService cold load and tutorial isolation. No deployed Web or OS pointer claim."}
	var file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("QUICK_START_EQUIPPED_LOADOUT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
