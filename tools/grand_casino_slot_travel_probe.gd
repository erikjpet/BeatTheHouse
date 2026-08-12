extends SceneTree

# Regression gate for the Grand Casino's three main-floor cabinets. Autoplay
# continues only from the Cage and High Limit Room, and pauses everywhere else.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const SAVE_SLOT := "grand_casino_slot_travel_probe"
const KEYS := ["slot", "slot:2", "slot:3"]
const CAGE_ROUNDS := 6
const HIGH_LIMIT_ROUNDS := 4
const PAUSE_FRAMES := 45
const MAX_ROUND_FRAMES := 240

var app: Control
var room: Dictionary
var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await process_frame
	await process_frame
	_install_scenario()

	var production_count := _production_fixture_count()
	if production_count != KEYS.size():
		failures.append("Grand Casino production layout has %d slot machines; expected %d." % [production_count, KEYS.size()])
	var identities := _identity_report()
	if int(identities.get("count", 0)) != KEYS.size() or int(identities.get("unique_count", 0)) != KEYS.size():
		failures.append("The three main-floor slot machines do not have three unique identities.")

	var external_pause := await _assert_paused("apartment")
	var cage_active := await _run_active_rounds(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, CAGE_ROUNDS)
	var back_room_pause := await _assert_paused(RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID)
	var high_limit_active := await _run_active_rounds(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, HIGH_LIMIT_ROUNDS)
	var external_pause_after := await _assert_paused("corner_store")
	var persistence := _persistence_report()

	var expected_total := CAGE_ROUNDS + HIGH_LIMIT_ROUNDS
	for key_value in KEYS:
		var key := str(key_value)
		if int(_spin_counts().get(key, -1)) != expected_total:
			failures.append("%s did not retain its independent %d-spin total." % [key, expected_total])
		if bool(persistence.get("loadable", false)) and int((persistence.get("spin_counts", {}) as Dictionary).get(key, -1)) != expected_total:
			failures.append("%s lost its spin total across save/load." % key)
	if not bool(persistence.get("loadable", false)):
		failures.append("The stored three-machine state was not loadable after the travel test.")

	var report := {
		"tool": "grand_casino_slot_travel_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"production_fixture_count": production_count,
		"identities": identities,
		"external_pause": external_pause,
		"cage_active": cage_active,
		"back_room_pause": back_room_pause,
		"high_limit_active": high_limit_active,
		"external_pause_after": external_pause_after,
		"final_spin_counts": _spin_counts(),
		"persistence": persistence,
	}
	print(JSON.stringify(report, "\t"))
	var save_service: SaveService = app.get("save_service")
	if save_service != null and save_service.async_save_in_flight():
		save_service.wait_for_async_save()
	quit(0 if failures.is_empty() else 1)


func _install_scenario() -> void:
	app.call("start_foundation_run", "GRAND-CASINO-THREE-SLOT-TRAVEL")
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 100000000
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	room = {
		"id": "grand_casino_three_slot_travel_probe",
		"archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"display_name": "Grand Casino",
		"kind": "casino", "tier": 3, "turns": 0,
		"game_ids": ["slot"], "event_ids": [], "resolved_event_ids": [],
		"item_offers": [], "service_ids": [], "lender_hooks": [],
		"travel_hooks": [], "next_archetypes": [], "object_fixtures": [],
		"layout": {"game_fixture_counts": {"slot": KEYS.size()}}, "game_states": {},
	}
	room["layout"] = EnvironmentInstance.ensure_generated_layout(room)
	room["game_states"] = slot_game.generate_environment_fixture_states(
		run_state, room, run_state.create_rng("grand_casino_three_slot_states"), KEYS.size()
	)
	run_state.store_grand_casino_room_environment(room)
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_invalidate_environment_runtime_schedule", room)


func _production_fixture_count() -> int:
	var library: ContentLibrary = app.get("library")
	var archetype: Dictionary = library.environment_archetype("grand_casino")
	var layout_value: Variant = archetype.get("layout", {})
	var layout: Dictionary = layout_value as Dictionary if typeof(layout_value) == TYPE_DICTIONARY else {}
	var counts_value: Variant = layout.get("game_fixture_counts", {})
	var counts: Dictionary = counts_value as Dictionary if typeof(counts_value) == TYPE_DICTIONARY else {}
	return int(counts.get("slot", 0))


func _set_foreground_archetype(archetype_id: String) -> void:
	var run_state: RunState = app.get("run_state")
	run_state.current_environment["archetype_id"] = archetype_id
	run_state.current_environment["game_ids"] = []
	run_state.current_environment["game_states"] = {}
	app.set("stored_grand_casino_runtime_last_msec", -100000)
	app.call("_invalidate_environment_runtime_schedule", run_state.current_environment)


func _assert_paused(archetype_id: String) -> Dictionary:
	_set_foreground_archetype(archetype_id)
	var before := _spin_counts()
	_set_all_due()
	app.call("_invalidate_environment_runtime_schedule", room)
	for _index in range(PAUSE_FRAMES):
		await process_frame
	var after := _spin_counts()
	var paused := before == after
	if not paused:
		failures.append("Main-floor autoplay advanced while the player was in %s." % archetype_id)
	return {"archetype_id": archetype_id, "paused": paused, "before": before, "after": after}


func _run_active_rounds(archetype_id: String, rounds: int) -> Dictionary:
	_set_foreground_archetype(archetype_id)
	var before := _spin_counts()
	var frame_samples: Array[float] = []
	var completed := 0
	for _round_index in range(rounds):
		var target := _spin_counts()
		for key_value in KEYS:
			var key := str(key_value)
			target[key] = int(target.get(key, 0)) + 1
		_set_all_due()
		app.call("_invalidate_environment_runtime_schedule", room)
		var previous_usec := Time.get_ticks_usec()
		for _frame_index in range(MAX_ROUND_FRAMES):
			await process_frame
			var now_usec := Time.get_ticks_usec()
			frame_samples.append(float(now_usec - previous_usec))
			previous_usec = now_usec
			if _counts_reached(target):
				completed += 1
				break
		if completed <= _round_index:
			break
	var after := _spin_counts()
	if completed != rounds:
		failures.append("Only %d of %d three-machine autoplay rounds completed in %s." % [completed, rounds, archetype_id])
	frame_samples.sort()
	var frame_p95_ms := _percentile(frame_samples, 0.95) / 1000.0
	return {
		"archetype_id": archetype_id,
		"completed_rounds": completed,
		"before": before,
		"after": after,
		"frame_p95_ms": frame_p95_ms,
		"frame_max_ms": (frame_samples.back() if not frame_samples.is_empty() else 0.0) / 1000.0,
	}


func _set_all_due() -> void:
	for key_value in KEYS:
		var key := str(key_value)
		var machine := SlotState.peek_machine(room, key).duplicate(true)
		machine["slot_autoplay_active"] = true
		machine["slot_autoplay_next_msec"] = 1
		machine["active_bonus"] = {"active": false, "complete": true}
		machine.erase("slot_pending_feature_alert")
		SlotState.write_runtime_machine(room, key, machine)


func _spin_counts() -> Dictionary:
	var result: Dictionary = {}
	for key_value in KEYS:
		var key := str(key_value)
		result[key] = int(SlotState.peek_machine(room, key).get("spin_count", 0))
	return result


func _counts_reached(targets: Dictionary) -> bool:
	var counts := _spin_counts()
	for key_value in KEYS:
		var key := str(key_value)
		if int(counts.get(key, 0)) < int(targets.get(key, 0)):
			return false
	return true


func _identity_report() -> Dictionary:
	var values: Array = []
	var seen: Dictionary = {}
	for key_value in KEYS:
		var machine := SlotState.peek_machine(room, str(key_value))
		var identity := "%s:%s" % [str(machine.get("type_id", "")), str(machine.get("format_id", ""))]
		values.append(identity)
		seen[identity] = true
	return {"count": values.size(), "unique_count": seen.size(), "values": values}


func _persistence_report() -> Dictionary:
	var save_service: SaveService = app.get("save_service")
	if save_service.async_save_in_flight():
		save_service.wait_for_async_save()
	var error := save_service.save_run(app.get("run_state") as RunState, SAVE_SLOT)
	var loaded_value: Variant = save_service.load_run(SAVE_SLOT) if error == OK else null
	if not (loaded_value is RunState):
		return {"error": error, "loadable": false, "spin_counts": {}}
	var loaded := loaded_value as RunState
	var loaded_room := loaded.grand_casino_room_environment(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var counts: Dictionary = {}
	for key_value in KEYS:
		var key := str(key_value)
		counts[key] = int(SlotState.peek_machine(loaded_room, key).get("spin_count", -1))
	return {"error": error, "loadable": true, "spin_counts": counts}


func _percentile(sorted_values: Array[float], ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(int(ceil(float(sorted_values.size()) * ratio)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]
