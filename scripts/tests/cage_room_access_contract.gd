extends SceneTree

# Synthetic seeded player state; all doors, publication, Save and Continue use
# production APIs. The player's original run/browser is never read.
const MainScene := preload("res://scenes/main.tscn")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const REQUIRED := ["casino_fixture:cage_counter", "casino_fixture:cage_atm", "staff:grand_casino_linda", "event:recruitment_bishop", "travel:grand_casino"]
var failures: Array[String] = []
var app: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", ProjectSettings.globalize_path("user://cage_room_access_contract"))
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for frame in range(3): await process_frame
	var cold := OS.get_cmdline_user_args().has("--cold")
	if cold:
		_check(bool(app.call("load_foundation_run")), "Cold Continue failed.")
		for frame in range(4): await process_frame
		_assert_cage("cold Continue")
		var run: RunState = app.get("run_state")
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://cage_access_expected.json"))
		_check(run.bankroll == int(expected.cash) and run.grand_casino_chips == int(expected.chips), "Continue changed cash/chips.")
		_check(str(run.rng_state) == str(expected.rng) and run.game_clock_minutes == int(expected.clock), "Continue changed RNG/clock.")
		_check(run.current_environment.get("cage_gift_shop_state", {}) == expected.stock, "Continue rerolled gift stock.")
		_check(run.crew_trust_by_member.get("crew_rook", 0) == 10, "Continue lost Crew progression.")
		_check(_travel("grand_casino"), "Cold Continue could not exit to Main Floor.")
	else:
		app.call("start_foundation_run", "CAGE-ACCESS-REPRO")
		var run: RunState = app.get("run_state")
		run.crew_trust_by_member["crew_rook"] = 10
		var generator: RunGenerator = app.get("generator")
		var arrival := generator.travel_environment_result(run, "grand_casino", true)
		_check(bool(arrival.get("ok", false)), "Synthetic Main Floor preparation failed.")
		app.call("_set_current_screen", "ENVIRONMENT")
		app.call("_refresh_run_action_service")
		app.call("_refresh")
		_check(_travel("grand_casino_cage"), "Offered Cage entrance failed.")
		for frame in range(4): await process_frame
		_assert_cage("first arrival")
		var original_stock: Dictionary = run.current_environment.get("cage_gift_shop_state", {}).duplicate(true)
		_check(_travel("grand_casino"), "Cage Main Floor exit failed.")
		# Existing card/cash/showdown requirements remain authoritative.
		var original_cash := run.bankroll
		run.bankroll = 0
		_check(not bool(run.grand_casino_room_access_status("grand_casino_high_limit").get("available", true)), "High-Limit lost its cash/card requirement.")
		_check(not bool(run.grand_casino_room_access_status("grand_casino_back_room").get("available", true)), "Back Room lost its Rourke requirement.")
		run.bankroll = original_cash
		run.narrative_flags["grand_casino_high_limit_access"] = true
		run.narrative_flags["grand_casino_high_limit_access_method"] = "card"
		_check(_travel("grand_casino_high_limit"), "Card-eligible High-Limit entrance failed.")
		_check(_travel("grand_casino_cage"), "High-Limit Cage entrance failed.")
		_assert_cage("High-Limit arrival")
		_check(run.current_environment.get("cage_gift_shop_state", {}) == original_stock, "Reentry rerolled gift stock.")
		_check(_travel("grand_casino"), "Second Cage exit failed.")
		var cage := run.grand_casino_room_environment("grand_casino_cage")
		var wrong_room := cage.duplicate(true)
		wrong_room["archetype_id"] = "grand_casino_high_limit"
		run.grand_casino_room_states["grand_casino_cage"] = wrong_room
		var before := [run.bankroll, run.game_clock_minutes, run.rng_state, run.current_environment.get("id")]
		var mismatch := generator.enter_grand_casino_room_result(run, "grand_casino_cage")
		_check(not bool(mismatch.get("ok", true)), "Cached cross-room identity was accepted.")
		_check(before == [run.bankroll, run.game_clock_minutes, run.rng_state, run.current_environment.get("id")], "Rejected room identity changed cash/clock/RNG/source.")
		_check(run.grand_casino_room_states.get("grand_casino_cage", {}).get("archetype_id") == "grand_casino_high_limit", "Rejected room cache was overwritten.")
		var stale_doors := cage.duplicate(true)
		stale_doors.local_narrative_flags["casino_room_targets"] = []
		run.grand_casino_room_states["grand_casino_cage"] = stale_doors
		_check(not bool(generator.enter_grand_casino_room_result(run, "grand_casino_cage").get("ok", true)), "Inconsistent saved Cage exit definition was accepted.")
		# Pre-world-node saves normalized their subroom node to its own archetype.
		# Accept that unambiguous legacy identity, then restore the shared node.
		cage["world_node_id"] = "grand_casino_cage"
		run.grand_casino_room_states["grand_casino_cage"] = cage
		_check(not bool(generator.enter_grand_casino_room_result(run, "cage").get("ok", true)), "Unknown room identifier was accepted.")
		_check(_travel("grand_casino_cage"), "Cage reentry after rejected cache failed.")
		_check(run.current_environment.get("world_node_id") == "grand_casino", "Legacy Cage identity did not regain the shared world node.")
		_assert_cage("before Save")
		var damaged := run.current_environment.duplicate(true)
		damaged.layout["slot_binding_digest"] = "0".repeat(64)
		_check(not bool(Controller._object_manifest_join_proof(damaged).get("ok", true)), "Damaged binding authority was accepted.")
		var expected := {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state), "clock": run.game_clock_minutes, "stock": run.current_environment.get("cage_gift_shop_state", {}).duplicate(true)}
		var file := FileAccess.open("user://cage_access_expected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(expected)); file.close()
		_check(bool(app.call("_autosave_foundation_run", "Saved run.", true)), "Normal Save failed.")
	var save_service: SaveService = app.get("save_service")
	if save_service.async_save_in_flight(): save_service.wait_for_async_save()
	app.queue_free()
	for frame in range(3): await process_frame
	if failures.is_empty():
		print("CAGE_ROOM_ACCESS_CONTRACT PASS mode=%s" % ("cold" if cold else "entry_exit_access_save"))
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _travel(target: String) -> bool:
	return bool(app.call("select_travel_option", target)) and bool(app.call("confirm_selected_travel", true))

func _assert_cage(label: String) -> void:
	var run: RunState = app.get("run_state")
	_check(run != null and run.current_environment.get("archetype_id") == "grand_casino_cage", "%s did not install the Cage." % label)
	if run == null: return
	_check(bool(Controller._object_manifest_join_proof(run.current_environment).get("ok", false)), "%s failed strict room authority." % label)
	var ids: Array = []
	for record in app.call("room_catalog_snapshot"):
		if record.get("presentation_mode", "") == "room": ids.append(record.get("object_id", ""))
	for identity in REQUIRED:
		_check(ids.has(identity), "%s lost room object %s." % [label, identity])
	var stock: Array = run.current_environment.get("cage_gift_shop_state", {}).get("stock", [])
	_check(stock.size() in [3, 4], "%s has no real Cage gifts." % label)
	_check(not bool(app.call("_room_recovery_active_for_current_room")), "%s triggered room recovery." % label)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
