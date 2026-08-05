extends SceneTree

# SRP-09 release gate: one uninterrupted accelerated three-hour run with a
# persistent twelve-cabinet Grand Casino room. Unlike the general soak, this
# fixture never rotates to a fresh run to hide retained storage growth.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballFeature := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const REPORT_PATH := "user://slot_runtime_storage_soak_report.json"
const SAVE_SLOT := "slot_runtime_storage_soak"
const SIM_MINUTES := 180
const SAMPLE_INTERVAL_MINUTES := 10
const ACTIONS_PER_SAMPLE := 28
const CABINET_COUNT := 12
const MAX_SAVE_BYTES := 150000
const MAX_MEMORY_GROWTH_BYTES := 32 * 1024 * 1024
const MAX_OBJECT_GROWTH := 96
const MAX_NODE_GROWTH := 12

var app: Control
var failures: Array = []
var samples: Array = []
var travel_count := 0
var revisit_count := 0
var save_load_count := 0
var action_count := 0
var visited_nodes: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(3)
	app.call("start_foundation_run", "SLOT-RUNTIME-STORAGE-SAME-RUN")
	await _settle(3)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 10000000
	_install_persistent_slot_room(run_state)
	await _sample(0)
	var sample_count := int(ceil(float(SIM_MINUTES) / float(SAMPLE_INTERVAL_MINUTES)))
	for sample_index in range(1, sample_count + 1):
		for _action_index in range(ACTIONS_PER_SAMPLE):
			await _drive_action()
		await _sample(sample_index)
	_assert_contract()
	var report := {
		"tool": "slot_runtime_storage_soak",
		"passed": failures.is_empty(),
		"failures": failures,
		"sim_minutes": SIM_MINUTES,
		"same_run_seed": "SLOT-RUNTIME-STORAGE-SAME-RUN",
		"actions": action_count,
		"travels": travel_count,
		"revisits": revisit_count,
		"save_loads": save_load_count,
		"samples": samples,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report, "\t"))
	var save_service: SaveService = app.get("save_service")
	if save_service != null:
		save_service.clear_run(SAVE_SLOT)
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _install_persistent_slot_room(run_state: RunState) -> void:
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	var room := {
		"id": "grand_casino_slot_soak_main",
		"archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"display_name": "Grand Casino Slot Soak",
		"kind": "casino",
		"tier": 3,
		"turns": 0,
		"game_ids": ["slot"],
		"event_ids": [], "resolved_event_ids": [], "item_offers": [],
		"service_ids": [], "lender_hooks": [], "travel_hooks": [], "next_archetypes": [],
		"object_fixtures": [],
		"layout": {"game_fixture_counts": {"slot": CABINET_COUNT}},
		"game_states": {},
	}
	room["layout"] = EnvironmentInstance.ensure_generated_layout(room)
	room["game_states"] = slot_game.generate_environment_fixture_states(
		run_state, room, run_state.create_rng("slot_runtime_storage_soak_room"), CABINET_COUNT
	)
	# Keep one genuinely active feature through repeated saves, and retain a
	# separately settled replay in another cabinet.
	var pinball_feature := PinballFeature.new()
	var active_machine: Dictionary = SlotState.peek_machine(room, "slot:12")
	var active: Dictionary = pinball_feature.open(active_machine, "video_feature", 10, run_state.create_rng("slot_runtime_storage_soak_active"), {"cap": 300, "ball_budget": 3})
	active_machine["active_bonus"] = active
	SlotState.write_runtime_machine(room, "slot:12", active_machine)
	var settled_machine: Dictionary = SlotState.peek_machine(room, "slot:11")
	var replay: Dictionary = pinball_feature.open(settled_machine, "lane_multiball", 10, run_state.create_rng("slot_runtime_storage_soak_settled"), {"cap": 180, "ball_budget": 2})
	replay["active"] = false
	replay["complete"] = true
	settled_machine["active_bonus"] = {"active": false, "complete": true}
	settled_machine["last_bonus_replay"] = replay
	settled_machine["last_bonus_complete"] = true
	SlotState.write_runtime_machine(room, "slot:11", settled_machine)
	run_state.store_grand_casino_room_environment(room)
	app.call("_invalidate_environment_runtime_schedule", room)


func _drive_action() -> void:
	action_count += 1
	var run_state: RunState = app.get("run_state")
	if run_state == null or run_state.seed_text != "SLOT-RUNTIME-STORAGE-SAME-RUN":
		failures.append("Same-run soak lost or replaced its authoritative run.")
		return
	var room := run_state.grand_casino_room_environment(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var cabinet_index := posmod(action_count, CABINET_COUNT - 2)
	var state_key := "slot" if cabinet_index == 0 else "slot:%d" % (cabinet_index + 1)
	var machine: Dictionary = SlotState.peek_machine(room, state_key)
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = 1
	SlotState.write_runtime_machine(room, state_key, machine)
	run_state.store_grand_casino_room_environment(room)
	app.call("_invalidate_environment_runtime_schedule", room)
	app.call("_advance_environment_game_runtime")
	if action_count % 23 == 0:
		app.call("save_foundation_run")
		app.call("load_foundation_run")
		save_load_count += 1
		await _settle(3)
	if action_count % ACTIONS_PER_SAMPLE == 0:
		await _travel_or_revisit()
	await process_frame


func _travel_or_revisit() -> void:
	var run_state: RunState = app.get("run_state")
	var before := run_state.current_world_node_id()
	visited_nodes[before] = true
	if not bool(app.call("open_world_map")):
		return
	await _settle(1)
	var snapshot: Dictionary = app.call("current_screen_snapshot")
	var map: Dictionary = snapshot.get("world_map", {})
	var enabled: Array = map.get("travel_enabled_node_ids", [])
	var target := ""
	for candidate_value in enabled:
		var candidate := str(candidate_value)
		if candidate != before and (target.is_empty() or visited_nodes.has(candidate)):
			target = candidate
			if visited_nodes.has(candidate):
				break
	if target.is_empty() or not bool(app.call("select_world_map_node", target)):
		app.call("close_world_map")
		return
	app.call("confirm_world_map_travel")
	await _settle(5)
	var after_run: RunState = app.get("run_state")
	var after := after_run.current_world_node_id()
	if after != before:
		travel_count += 1
		if visited_nodes.has(after):
			revisit_count += 1
		visited_nodes[after] = true
	app.call("back_to_environment")


func _sample(sample_index: int) -> void:
	await _settle(2)
	var run_state: RunState = app.get("run_state")
	var room := run_state.grand_casino_room_environment(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var game_states: Dictionary = room.get("game_states", {})
	var cabinet_count := 0
	var active_feature_count := 0
	var settled_replay_count := 0
	for key_value in game_states.keys():
		if str(key_value) == "slot" or str(key_value).begins_with("slot:"):
			cabinet_count += 1
			var machine: Dictionary = game_states.get(key_value, {})
			if SlotState.active_bonus_incomplete(machine):
				active_feature_count += 1
			if not (machine.get("last_bonus_replay", {}) as Dictionary).is_empty():
				settled_replay_count += 1
	var save_service: SaveService = app.get("save_service")
	var save_bytes := JSON.stringify(save_service.call("_save_payload", run_state, SAVE_SLOT)).length()
	var sample := {
		"sample_index": sample_index,
		"sim_minute": sample_index * SAMPLE_INTERVAL_MINUTES,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"v2_save_bytes": save_bytes,
		"story_entries": run_state.story_log.size(),
		"story_archive_count": run_state.story_log_archive_count,
		"cabinet_count": cabinet_count,
		"active_feature_count": active_feature_count,
		"settled_replay_count": settled_replay_count,
		"pinball_cache_size": PinballFeature.runtime_session_cache_size(),
	}
	samples.append(sample)
	print("SLOT_STORAGE_SOAK_SAMPLE minute=%d cabinets=%d save=%d memory=%d objects=%d nodes=%d active=%d settled=%d" % [
		int(sample["sim_minute"]), cabinet_count, save_bytes, int(sample["memory_static_bytes"]),
		int(sample["object_count"]), int(sample["node_count"]), active_feature_count, settled_replay_count,
	])


func _assert_contract() -> void:
	if samples.is_empty():
		failures.append("Same-run soak produced no samples.")
		return
	var baseline: Dictionary = samples[mini(3, samples.size() - 1)]
	var tail: Dictionary = samples.back()
	for sample_value in samples:
		var sample: Dictionary = sample_value
		if int(sample.get("cabinet_count", 0)) != CABINET_COUNT:
			failures.append("Persistent cabinet count changed at minute %d." % int(sample.get("sim_minute", 0)))
		if int(sample.get("v2_save_bytes", MAX_SAVE_BYTES + 1)) > MAX_SAVE_BYTES:
			failures.append("Same-run v2 save exceeded 150 KB at minute %d." % int(sample.get("sim_minute", 0)))
		if int(sample.get("orphan_node_count", 1)) != 0:
			failures.append("Same-run soak retained orphan nodes at minute %d." % int(sample.get("sim_minute", 0)))
	if int(tail.get("memory_static_bytes", 0)) - int(baseline.get("memory_static_bytes", 0)) > MAX_MEMORY_GROWTH_BYTES:
		failures.append("Same-run post-warmup memory growth exceeded 32 MB.")
	if int(tail.get("object_count", 0)) - int(baseline.get("object_count", 0)) > MAX_OBJECT_GROWTH:
		failures.append("Same-run post-warmup object growth exceeded 96.")
	if int(tail.get("node_count", 0)) - int(baseline.get("node_count", 0)) > MAX_NODE_GROWTH:
		failures.append("Same-run post-warmup node growth exceeded 12.")
	if int(tail.get("active_feature_count", 0)) < 1 or int(tail.get("settled_replay_count", 0)) < 1:
		failures.append("Same-run soak did not retain both active and settled bonus state.")
	if travel_count < 2 or revisit_count < 1:
		failures.append("Same-run soak did not exercise travel and revisits.")
	if save_load_count < 2:
		failures.append("Same-run soak did not exercise repeated save/load cycles.")


func _settle(frames: int) -> void:
	for _index in range(maxi(0, frames)):
		await process_frame
