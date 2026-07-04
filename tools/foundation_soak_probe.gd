extends SceneTree

# Long-session stability probe for the 0.3.1 hardening board.
# It accelerates three simulated hours of play and asserts post-warmup memory,
# object, node, serialized RunState, and pinball session-cache growth stays bounded.

const MainScene := preload("res://scenes/main.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const REPORT_PATH := "user://foundation_soak_probe_report.json"
const DEFAULT_SEED_PREFIX := "FOUNDATION-SOAK"
const DEFAULT_SIM_MINUTES := 180
const DEFAULT_ACTIONS_PER_SAMPLE := 28
const SAMPLE_INTERVAL_MINUTES := 10
const WARMUP_SAMPLE_COUNT := 3
const SAVE_LOAD_ACTION_INTERVAL := 23
const RUN_ROTATION_ACTION_INTERVAL := 160
const SLOT_AUTOPLAY_ACTION_INTERVAL := 97
const SLOT_AUTOPLAY_FRAMES := 150
const PINBALL_CACHE_STRESS_SESSIONS := 40
const SOAK_SAVE_SLOT := "foundation_soak_probe"

const MAX_SERIALIZED_RUN_STATE_BYTES := 1500000
const MAX_POST_WARMUP_MEMORY_GROWTH_BYTES := 16 * 1024 * 1024
const MAX_POST_WARMUP_MEMORY_SLOPE_BYTES_PER_SAMPLE := 1024 * 1024
const MAX_POST_WARMUP_OBJECT_GROWTH := 512
const MAX_POST_WARMUP_OBJECT_SLOPE_PER_SAMPLE := 24.0
const MAX_POST_WARMUP_NODE_GROWTH := 16
const MAX_POST_WARMUP_NODE_SLOPE_PER_SAMPLE := 2.0
const MAX_POST_WARMUP_ORPHAN_NODE_COUNT := 0

var app: Control
var failures: Array = []
var warnings: Array = []
var samples: Array = []
var coverage: Dictionary = {}
var run_index := 0
var action_counter := 0
var seed_prefix := DEFAULT_SEED_PREFIX
var sim_minutes := DEFAULT_SIM_MINUTES
var actions_per_sample := DEFAULT_ACTIONS_PER_SAMPLE


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed_prefix = OS.get_environment("BTH_SOAK_SEED_PREFIX")
	if seed_prefix.strip_edges().is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	sim_minutes = _configured_int("BTH_SOAK_MINUTES", DEFAULT_SIM_MINUTES)
	actions_per_sample = _configured_int("BTH_SOAK_ACTIONS_PER_SAMPLE", DEFAULT_ACTIONS_PER_SAMPLE)
	PinballFeatureScript.clear_runtime_session_cache()
	coverage = {
		"runs_started": 0,
		"save_loads": 0,
		"world_travels": 0,
		"revisits": 0,
		"game_actions": 0,
		"slot_autoplay_blocks": 0,
		"pinball_cache_stress_blocks": 0,
		"event_actions": 0,
		"item_actions": 0,
		"service_actions": 0,
		"lender_actions": 0,
	}
	await _open_fresh_app()
	await _start_next_run()
	await _sample(0)
	var sample_count := maxi(1, int(ceil(float(sim_minutes) / float(SAMPLE_INTERVAL_MINUTES))))
	for sample_index in range(1, sample_count + 1):
		for _action_index in range(actions_per_sample):
			await _drive_action()
		await _sample(sample_index)
	_assert_coverage()
	_assert_growth()
	_write_report()
	_print_summary()
	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return
	quit(0)


func _open_fresh_app() -> void:
	app = MainScene.instantiate() as Control
	if app == null:
		failures.append("Could not instantiate main scene.")
		return
	get_root().add_child(app)
	await _settle(3)
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		failures.append("Main scene did not initialize the foundation runtime.")
	app.set("autosave_slot_id", SOAK_SAVE_SLOT)


func _start_next_run() -> void:
	run_index += 1
	var seed := "%s-%03d" % [seed_prefix, run_index]
	var challenge: Dictionary = RunStateScript.custom_challenge("soak", seed, {
		"starting_bankroll": 5000,
		"hidden_seed": true,
	})
	app.set("autosave_slot_id", SOAK_SAVE_SLOT)
	app.call("start_foundation_run", seed, challenge)
	coverage["runs_started"] = int(coverage.get("runs_started", 0)) + 1
	await _settle(4)


func _drive_action() -> void:
	if app == null:
		return
	action_counter += 1
	await _resolve_blocking_popup()
	if _run_is_terminal():
		await _start_next_run()
		return
	if action_counter % RUN_ROTATION_ACTION_INTERVAL == 0:
		await _start_next_run()
		return
	if action_counter % SAVE_LOAD_ACTION_INTERVAL == 0:
		app.call("save_foundation_run")
		await _settle(2)
		app.call("load_foundation_run")
		coverage["save_loads"] = int(coverage.get("save_loads", 0)) + 1
		await _settle(3)
		return
	if action_counter % SLOT_AUTOPLAY_ACTION_INTERVAL == 0:
		await _exercise_slot_autoplay_block()
		return
	if action_counter % 5 == 0:
		var did_travel: bool = await _try_world_map_travel()
		if did_travel:
			return
	if action_counter % 7 == 0:
		var did_object: bool = await _try_interactable_object(["lender", "service", "event", "item", "game_hook"])
		if did_object:
			return
	var did_game: bool = await _try_play_environment_game()
	if did_game:
		return
	var fallback_travel: bool = await _try_world_map_travel()
	if fallback_travel:
		return
	await _try_interactable_object(["event", "lender", "service", "item", "game_hook"])


func _try_world_map_travel() -> bool:
	if _run_is_terminal():
		return false
	var before_state: Dictionary = app.call("serialized_run_state")
	var before_node := _current_world_node_id(before_state)
	if not bool(app.call("open_world_map")):
		return false
	await _settle(2)
	var screen: Dictionary = app.call("current_screen_snapshot")
	var map_snapshot: Dictionary = _dict(screen.get("world_map", {}))
	var target_id := _preferred_world_target(map_snapshot, before_node)
	if target_id.is_empty():
		target_id = _preferred_travel_choice_id()
	if target_id.is_empty():
		app.call("close_world_map")
		await _settle(1)
		return false
	if not bool(app.call("select_world_map_node", target_id)):
		app.call("close_world_map")
		await _settle(1)
		return false
	app.call("confirm_world_map_travel")
	await _settle(6)
	await _resolve_blocking_popup()
	var after_state: Dictionary = app.call("serialized_run_state")
	var after_node := _current_world_node_id(after_state)
	if after_node == before_node and target_id != before_node:
		warnings.append("World-map travel target %s did not change node from %s." % [target_id, before_node])
		return false
	coverage["world_travels"] = int(coverage.get("world_travels", 0)) + 1
	if _world_node_was_visited(map_snapshot, target_id):
		coverage["revisits"] = int(coverage.get("revisits", 0)) + 1
	app.call("back_to_environment")
	await _settle(2)
	return true


func _preferred_world_target(map_snapshot: Dictionary, current_node_id: String) -> String:
	var enabled_ids := _string_array(map_snapshot.get("travel_enabled_node_ids", []))
	if enabled_ids.is_empty():
		return ""
	var nodes := _array(map_snapshot.get("nodes", []))
	if action_counter % 2 == 0:
		for node_value in nodes:
			var node := _dict(node_value)
			var node_id := str(node.get("id", ""))
			if node_id == current_node_id or not enabled_ids.has(node_id):
				continue
			if str(node.get("state", "")) == "visited" or bool(node.get("visited", false)):
				return node_id
	for target_id in enabled_ids:
		if str(target_id) != current_node_id:
			return str(target_id)
	return ""


func _world_node_was_visited(map_snapshot: Dictionary, target_id: String) -> bool:
	for node_value in _array(map_snapshot.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("id", "")) != target_id:
			continue
		return str(node.get("state", "")) == "visited" or bool(node.get("visited", false))
	return false


func _preferred_travel_choice_id() -> String:
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	for choice_value in _array(environment_snapshot.get("travel_choices", [])):
		var choice := _dict(choice_value)
		if bool(choice.get("enabled", true)):
			return str(choice.get("id", ""))
	return ""


func _try_interactable_object(preferred_types: Array) -> bool:
	if _run_is_terminal():
		return false
	var spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects := _array(spatial.get("objects", []))
	for preferred_type_value in preferred_types:
		var preferred_type := str(preferred_type_value)
		for object_value in objects:
			var object_data := _dict(object_value)
			if str(object_data.get("object_type", "")) != preferred_type:
				continue
			if not bool(object_data.get("enabled", true)):
				continue
			var object_id := str(object_data.get("object_id", ""))
			if object_id.is_empty():
				continue
			var activated := bool(app.call("activate_interactable_object", object_id))
			await _settle(3)
			await _resolve_blocking_popup()
			if activated:
				_increment_object_coverage(preferred_type)
				app.call("back_to_environment")
				await _settle(2)
				return true
	return false


func _try_play_environment_game() -> bool:
	if _run_is_terminal():
		return false
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var game_ids := _string_array(environment_snapshot.get("game_ids", []))
	if game_ids.is_empty():
		return false
	var game_id := _preferred_game_id(game_ids)
	if game_id.is_empty():
		return false
	app.call("enter_game", game_id)
	await _settle(3)
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if not bool(game_snapshot.get("has_valid_stake", false)):
		app.call("back_to_environment")
		await _settle(1)
		return false
	var stake_min := maxi(1, int(game_snapshot.get("stake_min", 1)))
	var stake_max := maxi(stake_min, int(game_snapshot.get("stake_max", stake_min)))
	app.call("set_selected_stake", clampi(10, stake_min, stake_max))
	var action := _preferred_game_action(game_id, _array(game_snapshot.get("legal_actions", [])))
	if action.is_empty():
		app.call("back_to_environment")
		await _settle(1)
		return false
	app.call("select_game_action", str(action.get("id", "")), "legal")
	app.call("resolve_selected_game_action")
	await _settle(5)
	await _resolve_blocking_popup()
	coverage["game_actions"] = int(coverage.get("game_actions", 0)) + 1
	coverage["game:%s" % game_id] = int(coverage.get("game:%s" % game_id, 0)) + 1
	app.call("back_to_environment")
	await _settle(2)
	return true


func _preferred_game_id(game_ids: Array) -> String:
	if game_ids.has("slot"):
		return "slot"
	var index := posmod(action_counter, game_ids.size())
	return str(game_ids[index])


func _preferred_game_action(game_id: String, actions: Array) -> Dictionary:
	var preferred_ids := {
		"slot": "spin",
		"pull_tabs": "buy_tab",
		"bar_dice": "roll",
		"blackjack": "play_basic",
		"baccarat": "deal_baccarat",
		"roulette": "spin_roulette",
		"video_poker": "draw",
	}
	var preferred_id := str(preferred_ids.get(game_id, ""))
	for action_value in actions:
		var action := _dict(action_value)
		if str(action.get("id", "")) == preferred_id:
			return action
	for action_value in actions:
		var action := _dict(action_value)
		if not str(action.get("id", "")).is_empty():
			return action
	return {}


func _exercise_slot_autoplay_block() -> void:
	app.call("start_game_test_session", "slot")
	await _settle(5)
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null:
		failures.append("Soak probe could not find game_surface_canvas for slot autoplay.")
	else:
		canvas.emit_signal("surface_action", "slot_auto_toggle", 0, false)
		coverage["slot_autoplay_blocks"] = int(coverage.get("slot_autoplay_blocks", 0)) + 1
		for frame_index in range(SLOT_AUTOPLAY_FRAMES):
			await process_frame
			if frame_index % 30 == 0:
				await _resolve_blocking_popup()
	_stress_pinball_session_cache()
	app.call("return_to_main_menu")
	await _settle(4)
	await _start_next_run()


func _stress_pinball_session_cache() -> void:
	var rng := RngStream.new()
	rng.configure(910000 + action_counter, 910000 + action_counter)
	var feature := PinballFeatureScript.new()
	for session_index in range(PINBALL_CACHE_STRESS_SESSIONS):
		var mode := _pinball_mode_for_index(session_index)
		var machine := {
			"format_id": _pinball_format_for_mode(mode),
			"type_id": "pinball",
			"bet_ladder": {"selected_id": "bet_10"},
		}
		var active: Dictionary = feature.open(machine, mode, 10, rng, {"cap": 180, "ball_budget": 3})
		machine["active_bonus"] = active
	coverage["pinball_cache_stress_blocks"] = int(coverage.get("pinball_cache_stress_blocks", 0)) + 1


func _pinball_mode_for_index(index: int) -> String:
	match index % 3:
		1:
			return "lane_multiball"
		2:
			return "video_feature"
		_:
			return "em_bumper_drop"


func _pinball_format_for_mode(mode: String) -> String:
	match mode:
		"lane_multiball":
			return "line_5x3"
		"video_feature":
			return "video_feature"
		_:
			return "classic_3_reel"


func _resolve_blocking_popup() -> bool:
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot") if app != null else {}
	if not bool(popup.get("visible", false)):
		return false
	var popup_type := str(popup.get("popup_type", ""))
	if popup_type == "active_item_confirmation":
		app.call("cancel_pending_active_item_use")
		await _settle(2)
		return true
	if popup_type == "wager_confirmation":
		app.call("cancel_pending_wager_confirmation")
		await _settle(2)
		return true
	var event_id := str(popup.get("event_id", ""))
	var choices := _array(popup.get("choices", []))
	for choice_value in choices:
		var choice := _dict(choice_value)
		if bool(choice.get("dismissal", false)):
			continue
		var choice_id := str(choice.get("id", ""))
		if not event_id.is_empty() and not choice_id.is_empty():
			app.call("resolve_event_choice", event_id, choice_id)
			coverage["event_actions"] = int(coverage.get("event_actions", 0)) + 1
			await _settle(3)
			return true
	if not choices.is_empty() and not event_id.is_empty():
		var fallback_choice := _dict(choices[0])
		var fallback_id := str(fallback_choice.get("id", ""))
		if not fallback_id.is_empty():
			app.call("resolve_event_choice", event_id, fallback_id)
			await _settle(3)
			return true
	app.call("_hide_event_choice_popup")
	await _settle(1)
	return true


func _sample(sample_index: int) -> void:
	await _settle(2)
	var state: Dictionary = app.call("serialized_run_state") if app != null else {}
	var serialized_text := JSON.stringify(state)
	var sample := {
		"sample_index": sample_index,
		"sim_minute": sample_index * SAMPLE_INTERVAL_MINUTES,
		"action_count": action_counter,
		"run_index": run_index,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"scene_tree_node_count": _scene_tree_node_count(),
		"serialized_run_state_bytes": serialized_text.length(),
		"environment_history_length": _array_size(state.get("environment_history", [])),
		"environment_history_archive_count": int(state.get("environment_history_archive_count", 0)),
		"environment_travel_count": int(state.get("environment_history_archive_count", 0)) + _array_size(state.get("environment_history", [])),
		"story_log_length": _array_size(state.get("story_log", [])),
		"story_log_archive_count": int(state.get("story_log_archive_count", 0)),
		"story_log_entry_count": int(state.get("story_log_archive_count", 0)) + _array_size(state.get("story_log", [])),
		"world_map_visited_path_length": _world_map_visited_path_length(state),
		"pinball_session_cache_size": PinballFeatureScript.runtime_session_cache_size(),
	}
	samples.append(sample)
	print("SOAK_SAMPLE index=%d sim_minute=%d memory=%d objects=%d nodes=%d orphans=%d serialized=%d env_history=%d/%d story=%d/%d pinball_cache=%d" % [
		sample_index,
		int(sample.get("sim_minute", 0)),
		int(sample.get("memory_static_bytes", 0)),
		int(sample.get("object_count", 0)),
		int(sample.get("node_count", 0)),
		int(sample.get("orphan_node_count", 0)),
		int(sample.get("serialized_run_state_bytes", 0)),
		int(sample.get("environment_history_length", 0)),
		int(sample.get("environment_travel_count", 0)),
		int(sample.get("story_log_length", 0)),
		int(sample.get("story_log_entry_count", 0)),
		int(sample.get("pinball_session_cache_size", 0)),
	])


func _assert_coverage() -> void:
	for key in ["runs_started", "save_loads", "world_travels", "game_actions", "slot_autoplay_blocks", "pinball_cache_stress_blocks"]:
		if int(coverage.get(key, 0)) <= 0:
			failures.append("Soak probe did not exercise required path: %s." % key)
	if int(coverage.get("runs_started", 0)) < 3:
		failures.append("Soak probe expected at least 3 back-to-back runs, got %d." % int(coverage.get("runs_started", 0)))
	if int(coverage.get("event_actions", 0)) + int(coverage.get("lender_actions", 0)) + int(coverage.get("service_actions", 0)) <= 0:
		failures.append("Soak probe did not exercise any event/lender/service lifecycle path.")


func _assert_growth() -> void:
	if samples.size() <= WARMUP_SAMPLE_COUNT:
		failures.append("Soak probe did not collect enough samples for post-warmup growth checks.")
		return
	_assert_metric_growth("memory_static_bytes", MAX_POST_WARMUP_MEMORY_GROWTH_BYTES, MAX_POST_WARMUP_MEMORY_SLOPE_BYTES_PER_SAMPLE)
	_assert_metric_growth("object_count", MAX_POST_WARMUP_OBJECT_GROWTH, MAX_POST_WARMUP_OBJECT_SLOPE_PER_SAMPLE)
	_assert_metric_growth("node_count", MAX_POST_WARMUP_NODE_GROWTH, MAX_POST_WARMUP_NODE_SLOPE_PER_SAMPLE)
	for sample_value in samples:
		var sample := _dict(sample_value)
		if int(sample.get("serialized_run_state_bytes", 0)) > MAX_SERIALIZED_RUN_STATE_BYTES:
			failures.append("Serialized RunState size %d exceeded cap %d at sample %d." % [
				int(sample.get("serialized_run_state_bytes", 0)),
				MAX_SERIALIZED_RUN_STATE_BYTES,
				int(sample.get("sample_index", 0)),
			])
		if int(sample.get("environment_history_length", 0)) > RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES:
			failures.append("Environment history length exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("story_log_length", 0)) > RunStateScript.MAX_STORY_LOG_ENTRIES:
			failures.append("Story log length exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("pinball_session_cache_size", 0)) > PinballFeatureScript.MAX_RUNTIME_SESSIONS:
			failures.append("Pinball runtime session cache exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("orphan_node_count", 0)) > MAX_POST_WARMUP_ORPHAN_NODE_COUNT:
			failures.append("Orphan node count %d exceeded cap at sample %d." % [
				int(sample.get("orphan_node_count", 0)),
				int(sample.get("sample_index", 0)),
			])


func _assert_metric_growth(metric_key: String, max_growth: float, max_slope: float) -> void:
	var warmup_sample := _dict(samples[WARMUP_SAMPLE_COUNT])
	var warmup_value := float(warmup_sample.get(metric_key, 0.0))
	var max_value := warmup_value
	for index in range(WARMUP_SAMPLE_COUNT, samples.size()):
		var sample := _dict(samples[index])
		max_value = maxf(max_value, float(sample.get(metric_key, 0.0)))
	var growth := max_value - warmup_value
	var slope := _linear_slope(metric_key, WARMUP_SAMPLE_COUNT)
	if growth > max_growth:
		failures.append("%s post-warmup growth %.3f exceeded %.3f." % [metric_key, growth, max_growth])
	if slope > max_slope:
		failures.append("%s post-warmup slope %.3f/sample exceeded %.3f/sample." % [metric_key, slope, max_slope])


func _linear_slope(metric_key: String, start_index: int) -> float:
	var count := samples.size() - start_index
	if count <= 1:
		return 0.0
	var sum_x := 0.0
	var sum_y := 0.0
	var sum_xy := 0.0
	var sum_x2 := 0.0
	for index in range(start_index, samples.size()):
		var x := float(index - start_index)
		var y := float(_dict(samples[index]).get(metric_key, 0.0))
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	var denominator := float(count) * sum_x2 - sum_x * sum_x
	if is_zero_approx(denominator):
		return 0.0
	return maxf(0.0, (float(count) * sum_xy - sum_x * sum_y) / denominator)


func _print_summary() -> void:
	var final_sample := _dict(samples[samples.size() - 1]) if not samples.is_empty() else {}
	var warmup_sample := _dict(samples[WARMUP_SAMPLE_COUNT]) if samples.size() > WARMUP_SAMPLE_COUNT else final_sample
	print("FOUNDATION_SOAK_OVERALL status=%s samples=%d sim_minutes=%d actions=%d memory_growth=%d object_growth=%d node_growth=%d serialized_max=%d coverage=%s report=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		samples.size(),
		sim_minutes,
		action_counter,
		int(final_sample.get("memory_static_bytes", 0)) - int(warmup_sample.get("memory_static_bytes", 0)),
		int(final_sample.get("object_count", 0)) - int(warmup_sample.get("object_count", 0)),
		int(final_sample.get("node_count", 0)) - int(warmup_sample.get("node_count", 0)),
		_max_sample_int("serialized_run_state_bytes"),
		JSON.stringify(coverage),
		REPORT_PATH,
	])


func _write_report() -> void:
	var report := {
		"passed": failures.is_empty(),
		"failures": failures.duplicate(),
		"warnings": warnings.duplicate(),
		"coverage": coverage.duplicate(true),
		"config": {
			"sim_minutes": sim_minutes,
			"sample_interval_minutes": SAMPLE_INTERVAL_MINUTES,
			"actions_per_sample": actions_per_sample,
			"warmup_sample_count": WARMUP_SAMPLE_COUNT,
			"serialized_run_state_cap_bytes": MAX_SERIALIZED_RUN_STATE_BYTES,
			"environment_history_cap": RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES,
			"story_log_cap": RunStateScript.MAX_STORY_LOG_ENTRIES,
			"pinball_session_cache_cap": PinballFeatureScript.MAX_RUNTIME_SESSIONS,
			"memory_growth_cap_bytes": MAX_POST_WARMUP_MEMORY_GROWTH_BYTES,
			"memory_slope_cap_bytes_per_sample": MAX_POST_WARMUP_MEMORY_SLOPE_BYTES_PER_SAMPLE,
			"object_growth_cap": MAX_POST_WARMUP_OBJECT_GROWTH,
			"node_growth_cap": MAX_POST_WARMUP_NODE_GROWTH,
		},
		"samples": samples.duplicate(true),
		"post_warmup_slopes": {
			"memory_static_bytes": _linear_slope("memory_static_bytes", WARMUP_SAMPLE_COUNT),
			"object_count": _linear_slope("object_count", WARMUP_SAMPLE_COUNT),
			"node_count": _linear_slope("node_count", WARMUP_SAMPLE_COUNT),
		},
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write soak report to %s." % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _run_is_terminal() -> bool:
	var state: Dictionary = app.call("serialized_run_state") if app != null else {}
	var status := str(state.get("run_status", ""))
	return status == "failed" or status == "ended"


func _current_world_node_id(state: Dictionary) -> String:
	var world_map := _dict(state.get("world_map", {}))
	return str(world_map.get("current_node_id", ""))


func _world_map_visited_path_length(state: Dictionary) -> int:
	var world_map := _dict(state.get("world_map", {}))
	return _array_size(world_map.get("visited_path", []))


func _scene_tree_node_count() -> int:
	return _count_nodes(get_root())


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total


func _increment_object_coverage(object_type: String) -> void:
	match object_type:
		"event":
			coverage["event_actions"] = int(coverage.get("event_actions", 0)) + 1
		"item":
			coverage["item_actions"] = int(coverage.get("item_actions", 0)) + 1
		"service":
			coverage["service_actions"] = int(coverage.get("service_actions", 0)) + 1
		"lender":
			coverage["lender_actions"] = int(coverage.get("lender_actions", 0)) + 1
		_:
			coverage["object:%s" % object_type] = int(coverage.get("object:%s" % object_type, 0)) + 1


func _max_sample_int(metric_key: String) -> int:
	var result := 0
	for sample_value in samples:
		result = maxi(result, int(_dict(sample_value).get(metric_key, 0)))
	return result


func _configured_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return maxi(1, int(raw))


func _settle(frames: int) -> void:
	for _index in range(maxi(0, frames)):
		await process_frame


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in (value as Array):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
