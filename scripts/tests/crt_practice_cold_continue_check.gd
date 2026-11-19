extends SceneTree

# Two separate engine processes, one fresh guarded QA layout. The producer uses
# ordinary run generation, normal TV dispatch and paid Scratch Buy; the cold
# phase invokes the title Continue button. No profile/save copying or migration.
const MainScene := preload("res://scenes/main.tscn")
const SLOT := "crt_practice_engine_cold"
const SEED := "CRT-ENGINE-COLD-ORDINARY-061"
var app: Control
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var mode := ""
var expected_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or str(args[0]) not in ["--producer", "--cold"]:
		push_error("Use exactly one of --producer or --cold after Godot's -- separator.")
		quit(2)
		return
	mode = str(args[0]).trim_prefix("--")
	for key in ["BTH_QA_EVIDENCE_DIR", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").to_lower()
		if not _check(path.begins_with("e:/codexqa/bth/") and not path.contains("/../"), key + " is explicitly isolated on E:"):
			_finish()
			return
	expected_path = OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("crt-cold-expected.json")
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	await _frames(4)
	if mode == "producer":
		await _producer()
	else:
		await _cold()
	app.queue_free()
	await process_frame
	_finish()


func _producer() -> void:
	if not _check(not FileAccess.file_exists(expected_path) and not app.call("_has_foundation_save"), "producer starts with a fresh disposable Continue slot"):
		return
	# This is the normal complete world/run generator, with only its supported
	# home selector fixed so the source room is reproducible.
	if not _check(bool(app.call("start_foundation_run", SEED, {"modifiers": {"home_archetype_id": "apartment"}}, false)), "ordinary Apartment run starts through the production host"):
		return
	await _frames(4)
	var ordinary: RunState = app.get("run_state")
	_check(ordinary != null and str(ordinary.current_environment.get("archetype_id", "")) == "apartment" and not bool(app.get("dev_game_test_mode")), "producer owns an ordinary active Apartment run")
	if ordinary == null:
		return
	# Seed nonempty state only in this fresh guarded profile. Warm and cold
	# checks must retain actual profile items and collection currency, not merely
	# two empty defaults that could hide a reset.
	var profile: ProfileInventory = app.get("profile_inventory")
	var collection: MetaCollectionService = app.get("meta_collection_service")
	if not _check(profile != null and collection != null, "producer has the real profile and meta collection services"):
		return
	profile.add_reference_chip(2)
	collection.add_gold(137)
	if not _check(profile.save() == OK and collection.save() == OK, "nonempty disposable profile and collection baselines are durable"):
		return
	ordinary._store_current_local_suspicion()
	app.call("save_foundation_run")
	await _drain_save()
	var before := _identity(ordinary)
	var profile_meta_before := _profile_meta_state()
	var saved_path: String = app.get("save_service").run_save_path(SLOT)
	_check(FileAccess.file_exists(saved_path), "ordinary pre-practice Save is durable")
	_check(bool(app.call("activate_interactable_object", "home_console:tv")), "ordinary television opens CRT through room dispatch")
	var launch: Dictionary = app.call("start_game_test_session", "scratch_tickets")
	if not _check(bool(launch.get("ok", false)), "normal Scratch Tickets practice launches"):
		return
	var practice: RunState = app.get("run_state")
	var machine: Dictionary = practice.current_environment.get("game_states", {}).get("scratch_tickets", {})
	var stock: Array = machine.get("stock", [])
	if not _check(not stock.is_empty(), "practice machine has the canonical stocked ticket rows"):
		return
	var cash_before := practice.bankroll
	var price := int((stock[0] as Dictionary).get("price", 1))
	app.call("_on_game_surface_action", "scratch_buy", 0)
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if str(popup.get("popup_type", "")) == "wager_confirmation" and bool(popup.get("visible", false)):
		app.call("confirm_pending_wager_action")
	await _frames(2)
	var bought: Dictionary = practice.current_environment.get("game_states", {}).get("scratch_tickets", {})
	_check(practice != ordinary and practice.bankroll == cash_before - price and not (bought.get("tray_stack", []) as Array).is_empty(), "real practice Buy spends only practice money and dispenses a ticket")
	app.call("back_to_environment")
	await _selector()
	app.call("close_game_test_menu")
	_check(app.get("run_state") == ordinary and not bool(app.call("_crt_practice_active")), "Exit CRT restores the exact ordinary run reference")
	_check(_numeric_equal(_identity(ordinary), before), "practice wager/Leave/Exit preserves ordinary room, cash, Heat, clock, inventory, home and RNG")
	_check(_numeric_equal(_profile_meta_state(), profile_meta_before), "warm practice wager/Leave/Exit retains profile inventory and meta collection")
	app.call("save_foundation_run")
	await _drain_save()
	_check(_numeric_equal(_identity(ordinary), before), "ordinary post-practice Save preserves protected identity")
	_check(_numeric_equal(_profile_meta_state(), profile_meta_before), "ordinary post-practice Save retains profile inventory and meta collection")
	facts = {"schema": "bth.crt_engine_cold/v1", "identity": _identity(ordinary), "profile_meta": _profile_meta_state(), "source": "ordinary production start_foundation_run with supported apartment selector; fresh profile reference chips and collection gold", "producer_pid": OS.get_process_id(), "primary_sha256": FileAccess.get_sha256(saved_path), "practice_purchase_price": price}
	if failures.is_empty():
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		if _check(file != null, "producer writes its guarded expected-identity receipt"):
			file.store_string(JSON.stringify(facts))
			file.close()


func _cold() -> void:
	if not _check(FileAccess.file_exists(expected_path), "cold process finds producer expected-identity receipt"):
		return
	var expected_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not _check(typeof(expected_value) == TYPE_DICTIONARY, "producer receipt parses"):
		return
	var expected: Dictionary = expected_value
	_check(int(expected.get("producer_pid", -1)) != OS.get_process_id(), "Continue runs in a different engine process")
	_check(_numeric_equal(_profile_meta_state(), expected.get("profile_meta", {})), "fresh process loads the producer's nonempty profile inventory and meta collection")
	var button: Button = app.get("continue_button")
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled and button.text == "CONTINUE", "fresh title offers the actual enabled Continue button"):
		return
	button.pressed.emit()
	await _frames(4)
	var state: RunState = app.get("run_state")
	if not _check(state != null, "actual Continue button loads the stored ordinary run"):
		facts["last_load_outcome"] = app.get("save_service").last_load_outcome
		return
	_check(not bool(app.get("dev_game_test_mode")) and not bool(app.get("dev_environment_test_mode")) and not bool(app.call("_crt_practice_active")) and not bool(app.call("_is_meta_session")), "cold Continue is an ordinary run without retained practice/meta ownership")
	var loaded := _identity(state)
	_check(_numeric_equal(loaded, expected.get("identity", {})), "engine-cold Continue retains the complete producer protected identity")
	_check(_numeric_equal(_profile_meta_state(), expected.get("profile_meta", {})), "engine-cold Continue retains the producer's profile inventory and meta collection")
	_check(bool(app.call("activate_interactable_object", "home_console:tv")), "cold resumed ordinary room retains its television control")
	app.call("close_game_test_menu")
	_check(app.get("run_state") == state and _numeric_equal(_identity(state), loaded), "cold resumed CRT cancel loop retains the loaded ordinary state")
	_check(_numeric_equal(_profile_meta_state(), expected.get("profile_meta", {})), "cold resumed CRT cancel retains the producer's profile inventory and meta collection")
	facts = {"schema": "bth.crt_engine_cold/v1", "producer_pid": expected.get("producer_pid"), "cold_pid": OS.get_process_id(), "expected": expected.get("identity", {}), "actual": _identity(state), "expected_profile_meta": expected.get("profile_meta", {}), "actual_profile_meta": _profile_meta_state(), "last_load_outcome": app.get("save_service").last_load_outcome, "continue_entry": "actual title continue_button.pressed"}


func _identity(state: RunState) -> Dictionary:
	# Preserve all 64 RNG bits in the inter-process JSON receipt; JSON numeric
	# decoding uses floating point and cannot represent every 64-bit integer.
	return {"seed": state.seed_text, "room_id": str(state.current_environment.get("id", "")), "archetype": str(state.current_environment.get("archetype_id", "")), "cash": state.bankroll, "chips": state.grand_casino_chips, "heat": state.suspicion.duplicate(true), "clock": state.game_clock_minutes, "inventory": state.inventory.duplicate(true), "home": state.home_state.duplicate(true), "rng_seed": str(state.rng_seed), "rng_state": str(state.rng_state)}


func _profile_meta_state() -> Dictionary:
	var profile: ProfileInventory = app.get("profile_inventory")
	var collection: MetaCollectionService = app.get("meta_collection_service")
	return {
		"profile": profile.to_dict().duplicate(true) if profile != null else {},
		"meta": collection.snapshot().duplicate(true) if collection != null else {},
	}


func _numeric_equal(actual: Variant, expected: Variant) -> bool:
	# JSON converts integer tokens to floating point. Only that type distinction
	# is normalized; dictionary membership, array order and all values stay exact.
	if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		return actual == expected
	if typeof(actual) != typeof(expected):
		return false
	if typeof(actual) == TYPE_DICTIONARY:
		if actual.size() != expected.size():
			return false
		for key in actual:
			if not expected.has(key) or not _numeric_equal(actual[key], expected[key]):
				return false
		return true
	if typeof(actual) == TYPE_ARRAY:
		if actual.size() != expected.size():
			return false
		for index in range(actual.size()):
			if not _numeric_equal(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _drain_save() -> void:
	for _frame in range(600):
		if not bool(app.get("pending_autosave")) and not app.get("save_service").async_save_in_flight():
			_check(bool(app.get("save_service").last_save_outcome.get("ok", false)), "ordinary Save completes successfully")
			return
		await process_frame
	_check(false, "ordinary Save completes within bounded frames")


func _selector() -> void:
	for _frame in range(600):
		var menu: Control = app.get("game_test_menu")
		if menu != null and menu.is_visible_in_tree() and app.get("current_game") == null:
			_check(true, "normal Leave returns to the CRT selector")
			return
		await process_frame
	_check(false, "normal Leave reaches CRT within bounded frames")


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok


func _finish() -> void:
	print("CRT_PRACTICE_COLD_CONTINUE " + JSON.stringify({"mode": mode, "checks": checks, "failures": failures, "facts": facts, "scope": "Two separate fresh QA engine processes; ordinary host Save, paid practice Buy/Leave/Exit, actual cold title Continue. No rendered native/Web or physical pointer claim."}))
	quit(0 if failures.is_empty() else 1)
