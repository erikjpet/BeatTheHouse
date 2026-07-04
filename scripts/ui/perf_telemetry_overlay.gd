class_name PerfTelemetryOverlay
extends Control

# Debug-only runtime telemetry for low-end/web baselines. The node is never
# created unless an explicit command-line flag or web query parameter enables it.

const SlotStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")

const REQUIRED_GAME_IDS := [
	"pull_tabs",
	"slot",
	"bar_dice",
	"blackjack",
	"baccarat",
	"roulette",
	"video_poker",
]
const ACTIVE_ACTIONS := {
	"pull_tabs": "buy_tab",
	"slot": "spin",
	"bar_dice": "roll",
	"blackjack": "play_basic",
	"baccarat": "deal_baccarat",
	"roulette": "spin_roulette",
	"video_poker": "draw",
}
const DEFAULT_SAMPLE_STRIDE_FRAMES := 30
const DEFAULT_SCENARIO_FRAMES := 180
const DEFAULT_ACTIVE_FRAMES := 240
const DEFAULT_MEMORY_SECONDS := 600
const OVERLAY_REFRESH_STRIDE_FRAMES := 15
const WEB_HEAP_SAMPLE_STRIDE_FRAMES := 60
const REPORT_PREFIX := "BTH_PERF_REPORT "
const READY_PREFIX := "BTH_PERF_READY "

var app: FoundationMain
var runtime_options: Dictionary = {}
var telemetry_enabled := false
var show_overlay := false
var auto_quit := false
var plan_id := ""
var sample_stride_frames := DEFAULT_SAMPLE_STRIDE_FRAMES
var scenario_frames := DEFAULT_SCENARIO_FRAMES
var active_frames := DEFAULT_ACTIVE_FRAMES
var memory_seconds := DEFAULT_MEMORY_SECONDS
var report_path := "user://l02_perf_telemetry_report.json"
var created_msec := 0
var frame_index := 0
var overlay_label: Label
var scenario_active := false
var current_scenario := ""
var current_tags: Dictionary = {}
var current_start_msec := 0
var current_start_memory_bytes := 0
var current_last_memory_bytes := 0
var frame_ms_samples: Array = []
var process_ms_samples: Array = []
var physics_ms_samples: Array = []
var draw_call_samples: Array = []
var render_object_samples: Array = []
var primitive_samples: Array = []
var memory_samples: Array = []
var object_count_samples: Array = []
var node_count_samples: Array = []
var orphan_node_count_samples: Array = []
var scenario_records: Array = []
var telemetry_events: Array = []
var overhead_frame_count := 0
var overhead_total_usec := 0
var overhead_max_usec := 0
var overhead_samples_usec: Array = []
var l02_driver_started := false
var l02_driver_complete := false
var last_web_heap_sample_frame := -WEB_HEAP_SAMPLE_STRIDE_FRAMES
var last_web_heap_bytes := 0


static func runtime_enabled() -> bool:
	var options := _runtime_options()
	return _option_bool(options, "bth_perf", false) \
		or _option_bool(options, "bth_perf_telemetry", false) \
		or not str(options.get("bth_perf_plan", "")).strip_edges().is_empty()


func configure(owner: FoundationMain) -> void:
	app = owner
	runtime_options = _runtime_options()
	telemetry_enabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 4096
	created_msec = Time.get_ticks_msec()
	show_overlay = _option_bool(runtime_options, "bth_perf_overlay", false)
	auto_quit = _option_bool(runtime_options, "bth_perf_auto_quit", false)
	plan_id = str(runtime_options.get("bth_perf_plan", "")).strip_edges().to_lower()
	sample_stride_frames = maxi(1, _option_int(runtime_options, "bth_perf_stride", DEFAULT_SAMPLE_STRIDE_FRAMES))
	scenario_frames = maxi(30, _option_int(runtime_options, "bth_perf_frames", DEFAULT_SCENARIO_FRAMES))
	active_frames = maxi(30, _option_int(runtime_options, "bth_perf_active_frames", DEFAULT_ACTIVE_FRAMES))
	memory_seconds = maxi(10, _option_int(runtime_options, "bth_perf_memory_seconds", DEFAULT_MEMORY_SECONDS))
	report_path = str(runtime_options.get("bth_perf_report", report_path)).strip_edges()
	if report_path.is_empty():
		report_path = "user://l02_perf_telemetry_report.json"
	visible = show_overlay
	if show_overlay:
		_build_overlay()
	_begin_scenario("menu_idle", {"phase": "ready"})
	_emit_console(READY_PREFIX, {
		"ticks_msec": created_msec,
		"plan": plan_id,
		"sample_stride_frames": sample_stride_frames,
	})
	if plan_id == "l02":
		call_deferred("_run_l02_plan")
	elif plan_id == "la1":
		call_deferred("_run_la1_plan")


func _process(delta: float) -> void:
	if not telemetry_enabled:
		return
	var started_usec := Time.get_ticks_usec()
	frame_index += 1
	var frame_ms := maxf(0.0, delta * 1000.0)
	if scenario_active:
		frame_ms_samples.append(frame_ms)
		if frame_index % sample_stride_frames == 0:
			_sample_monitors()
	if show_overlay and frame_index % OVERLAY_REFRESH_STRIDE_FRAMES == 0:
		_refresh_overlay()
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	overhead_frame_count += 1
	overhead_total_usec += elapsed_usec
	overhead_max_usec = maxi(overhead_max_usec, elapsed_usec)
	overhead_samples_usec.append(elapsed_usec)


func dump_report() -> Dictionary:
	if scenario_active:
		_end_scenario()
	var report := {
		"tool": "l02_runtime_perf_telemetry",
		"schema_version": 1,
		"platform": _platform_label(),
		"plan": plan_id,
		"sample_stride_frames": sample_stride_frames,
		"scenario_frames": scenario_frames,
		"active_frames": active_frames,
		"memory_seconds": memory_seconds,
		"created_msec": created_msec,
		"dump_msec": Time.get_ticks_msec(),
		"scenario_count": scenario_records.size(),
		"scenarios": scenario_records,
		"events": telemetry_events,
		"telemetry_overhead": _overhead_stats(),
	}
	_write_report_file(report)
	_emit_console(REPORT_PREFIX, report)
	return report


func mark_event(event_id: String, data: Dictionary = {}) -> void:
	telemetry_events.append({
		"id": event_id,
		"msec": Time.get_ticks_msec(),
		"scenario": current_scenario,
		"data": data.duplicate(true),
	})


func _run_l02_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	await _measure_scenario("start_menu_idle", {"surface": "menu", "mode": "idle"}, scenario_frames)
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		await _measure_game(game_id)
	await _measure_slot_autoplay()
	await _measure_pinball_feature()
	await _measure_world_map()
	await _measure_scripted_memory()
	l02_driver_complete = true
	dump_report()
	if auto_quit:
		get_tree().quit()


func _run_la1_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("la1_missing_app")
		dump_report()
		if auto_quit:
			get_tree().quit()
		return
	app.start_foundation_run("LA1-WEB-CORE")
	await _wait_frames(20)
	var open_started_usec := Time.get_ticks_usec()
	var opened := app.open_world_map()
	var open_usec := maxi(0, Time.get_ticks_usec() - open_started_usec)
	mark_event("la1_world_map_open", {
		"opened": opened,
		"duration_ms": float(open_usec) / 1000.0,
	})
	await _wait_frames(8)
	await _measure_scenario("la1_world_map_idle", {"surface": "world_map", "mode": "idle"}, scenario_frames)
	app.close_world_map()
	await _wait_frames(8)
	var autosave_started_usec := Time.get_ticks_usec()
	var autosave_accepted := bool(app.call("_autosave_foundation_run", "LA1 Autosave.", false))
	var autosave_request_usec := maxi(0, Time.get_ticks_usec() - autosave_started_usec)
	mark_event("la1_app_autosave_request", {
		"duration_ms": float(autosave_request_usec) / 1000.0,
		"accepted": autosave_accepted,
		"pending": bool(app.get("pending_autosave")),
	})
	await _wait_frames(4)
	mark_event("la1_app_autosave_after_flush", {
		"pending": bool(app.get("pending_autosave")),
	})
	var save_service: SaveService = app.get("save_service") as SaveService
	var run_state: RunState = app.get("run_state") as RunState
	if save_service == null or run_state == null:
		mark_event("la1_save_unavailable")
	else:
		var save_started_usec := Time.get_ticks_usec()
		var save_error := save_service.save_run(run_state, "la1_web_probe")
		var save_usec := maxi(0, Time.get_ticks_usec() - save_started_usec)
		mark_event("la1_save_run", {
			"duration_ms": float(save_usec) / 1000.0,
			"error": int(save_error),
		})
	l02_driver_complete = true
	dump_report()
	if auto_quit:
		get_tree().quit()


func _measure_game(game_id: String) -> void:
	if app == null:
		return
	app.start_game_test_session(game_id)
	await _wait_frames(12)
	await _measure_scenario("%s_idle" % game_id, {"surface": game_id, "mode": "idle"}, scenario_frames)
	_begin_scenario("%s_active" % game_id, {"surface": game_id, "mode": "active"})
	_trigger_active_game_action(game_id)
	await _wait_frames(active_frames)
	_end_scenario()
	app.back_to_environment()
	await _wait_frames(8)


func _measure_slot_autoplay() -> void:
	if app == null:
		return
	app.start_game_test_session("slot")
	await _wait_frames(12)
	_begin_scenario("slot_autoplay_active", {"surface": "slot", "mode": "autoplay"})
	_emit_surface_action("slot_auto_toggle", 0, false)
	await _wait_frames(maxi(active_frames, scenario_frames))
	_end_scenario()
	app.back_to_environment()
	await _wait_frames(8)


func _measure_pinball_feature() -> void:
	if app == null:
		return
	app.start_game_test_session("slot")
	await _wait_frames(12)
	var prepared := _force_pinball_feature()
	_begin_scenario("pinball_feature_session", {"surface": "slot", "mode": "pinball_feature", "prepared": prepared})
	for frame in range(maxi(active_frames * 2, 480)):
		if frame % 45 == 0:
			_emit_surface_action("slot_bonus_launch", 0, false)
		elif frame % 45 == 12:
			_emit_surface_action("slot_bonus_left", 0, false)
		elif frame % 45 == 24:
			_emit_surface_action("slot_bonus_right", 0, false)
		elif frame % 45 == 36:
			_emit_surface_action("slot_bonus_power_up", 0, false)
		await get_tree().process_frame
	_end_scenario()
	app.back_to_environment()
	await _wait_frames(8)


func _measure_world_map() -> void:
	if app == null:
		return
	app.start_foundation_run("L02-WORLD-MAP")
	await _wait_frames(20)
	app.open_world_map()
	await _wait_frames(8)
	await _measure_scenario("world_map_idle", {"surface": "world_map", "mode": "idle"}, scenario_frames)
	app.close_world_map()
	await _wait_frames(8)


func _measure_scripted_memory() -> void:
	if app == null:
		return
	app.start_foundation_run("L02-MEMORY")
	await _wait_frames(20)
	_begin_scenario("scripted_play_memory_10m", {"surface": "full_run", "mode": "scripted_play", "target_seconds": memory_seconds})
	var frame := 0
	var end_msec := Time.get_ticks_msec() + memory_seconds * 1000
	while Time.get_ticks_msec() < end_msec:
		if frame % 240 == 0:
			_scripted_memory_step(frame / 240)
		frame += 1
		await get_tree().process_frame
	_end_scenario()


func _measure_scenario(name: String, tags: Dictionary, frames: int) -> void:
	_begin_scenario(name, tags)
	await _wait_frames(frames)
	_end_scenario()


func _begin_scenario(name: String, tags: Dictionary = {}) -> void:
	if scenario_active:
		_end_scenario()
	current_scenario = name
	current_tags = tags.duplicate(true)
	current_start_msec = Time.get_ticks_msec()
	current_start_memory_bytes = _current_memory_bytes()
	current_last_memory_bytes = current_start_memory_bytes
	frame_ms_samples = []
	process_ms_samples = []
	physics_ms_samples = []
	draw_call_samples = []
	render_object_samples = []
	primitive_samples = []
	memory_samples = []
	object_count_samples = []
	node_count_samples = []
	orphan_node_count_samples = []
	scenario_active = true
	_sample_monitors()


func _end_scenario() -> void:
	if not scenario_active:
		return
	_sample_monitors()
	var end_msec := Time.get_ticks_msec()
	var memory_stats := _int_stats(memory_samples)
	var record := {
		"name": current_scenario,
		"tags": current_tags.duplicate(true),
		"start_msec": current_start_msec,
		"end_msec": end_msec,
		"duration_msec": maxi(0, end_msec - current_start_msec),
		"frame_time_ms": _float_stats(frame_ms_samples),
		"process_time_ms": _float_stats(process_ms_samples),
		"physics_time_ms": _float_stats(physics_ms_samples),
		"draw_calls": _int_stats(draw_call_samples),
		"render_objects": _int_stats(render_object_samples),
		"render_primitives": _int_stats(primitive_samples),
		"static_memory_bytes": {
			"start": current_start_memory_bytes,
			"end": current_last_memory_bytes,
			"delta": current_last_memory_bytes - current_start_memory_bytes,
			"max": int(memory_stats.get("max", current_last_memory_bytes)),
		},
		"object_count": _int_stats(object_count_samples),
		"node_count": _int_stats(node_count_samples),
		"orphan_node_count": _int_stats(orphan_node_count_samples),
	}
	scenario_records.append(record)
	scenario_active = false
	current_scenario = ""


func _sample_monitors() -> void:
	process_ms_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	physics_ms_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	draw_call_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	render_object_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	primitive_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var memory_bytes := _current_memory_bytes()
	current_last_memory_bytes = memory_bytes
	memory_samples.append(memory_bytes)
	object_count_samples.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	node_count_samples.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	orphan_node_count_samples.append(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))


func _trigger_active_game_action(game_id: String) -> void:
	if app == null:
		return
	var action_id := _preferred_action_id(game_id)
	if action_id.is_empty():
		mark_event("missing_action", {"game_id": game_id})
		return
	app.select_game_action(action_id, "legal")
	app.set_selected_stake(_safe_stake())
	app.resolve_selected_game_action()


func _preferred_action_id(game_id: String) -> String:
	var preferred := str(ACTIVE_ACTIONS.get(game_id, ""))
	var game: GameModule = app.get("current_game") as GameModule
	var run_state: RunState = app.get("run_state") as RunState
	if game == null or run_state == null:
		return preferred
	var actions := game.legal_actions(run_state, run_state.current_environment)
	var fallback := ""
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", ""))
		if action_id.is_empty():
			continue
		if fallback.is_empty():
			fallback = action_id
		if action_id == preferred:
			return preferred
	return fallback


func _safe_stake() -> int:
	var run_state: RunState = app.get("run_state") as RunState
	if run_state == null:
		return 1
	var environment: Dictionary = run_state.current_environment
	var economic_profile: Dictionary = environment.get("economic_profile", {})
	return maxi(1, int(economic_profile.get("stake_floor", 1)))


func _emit_surface_action(action_id: String, index: int, confirm: bool) -> void:
	if app == null:
		return
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null:
		mark_event("missing_surface_canvas", {"action_id": action_id})
		return
	canvas.emit_signal("surface_action", action_id, index, confirm)


func _force_pinball_feature() -> bool:
	var run_state: RunState = app.get("run_state") as RunState
	var content_library: ContentLibrary = app.get("library") as ContentLibrary
	if run_state == null or content_library == null:
		return false
	var environment: Dictionary = run_state.current_environment
	var definition := content_library.game("slot")
	var machine: Dictionary = SlotStateScript.read_machine(environment, "slot")
	if machine.is_empty():
		return false
	machine = SlotStateScript.set_selected_bet(machine, "bet_10")
	var pinball := SlotPinballScript.new()
	var rng := run_state.create_rng("l02_pinball_feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	machine["slot_animation_id"] = "bonus:l02_pinball_feature"
	machine["slot_animation_duration_msec"] = 12000
	machine["slot_animation_started_msec"] = Time.get_ticks_msec()
	machine["slot_animation_plan"] = {
		"id": "bonus:l02_pinball_feature",
		"duration_msec": 12000,
		"feature_duration_msec": 12000,
	}
	SlotStateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	app.call("_refresh")
	return true


func _scripted_memory_step(step_index: int) -> void:
	if app == null or app.get("run_state") == null:
		return
	var current_game: GameModule = app.get("current_game") as GameModule
	if current_game != null:
		_trigger_active_game_action(current_game.get_id())
		if step_index % 2 == 0:
			app.back_to_environment()
		return
	if step_index % 5 == 0:
		if app.open_world_map():
			app.close_world_map()
		return
	app.enter_first_available_game()


func _wait_frames(frames: int) -> void:
	for _index in range(maxi(1, frames)):
		await get_tree().process_frame


func _build_overlay() -> void:
	overlay_label = Label.new()
	overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_label.position = Vector2(12, 12)
	overlay_label.size = Vector2(360, 94)
	overlay_label.add_theme_font_size_override("font_size", 12)
	overlay_label.add_theme_color_override("font_color", Color("#b8fff1"))
	add_child(overlay_label)
	_refresh_overlay()


func _refresh_overlay() -> void:
	if overlay_label == null:
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := 1000.0 / maxf(1.0, float(fps))
	var overhead := _overhead_stats()
	overlay_label.text = "BTH PERF %s\nframe %.2fms fps %.1f\nscenario %s\ntelemetry %.4fms avg" % [
		_platform_label(),
		frame_ms,
		float(fps),
		current_scenario,
		float(overhead.get("avg_ms", 0.0)),
	]


func _write_report_file(report: Dictionary) -> void:
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write perf telemetry report to %s." % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _emit_console(prefix: String, payload: Dictionary) -> void:
	var message := prefix + JSON.stringify(payload)
	print(message)
	if not OS.has_feature("web"):
		return
	var script := "console.log(%s);" % JSON.stringify(message)
	JavaScriptBridge.eval(script, true)


func _overhead_stats() -> Dictionary:
	var samples_ms: Array = []
	for sample_value in overhead_samples_usec:
		samples_ms.append(float(sample_value) / 1000.0)
	var stats := _float_stats(samples_ms)
	stats["frames"] = overhead_frame_count
	stats["avg_ms"] = (float(overhead_total_usec) / float(maxi(1, overhead_frame_count))) / 1000.0
	stats["max_ms"] = float(overhead_max_usec) / 1000.0
	stats["budget_ms"] = 0.1
	stats["under_budget"] = float(stats.get("avg_ms", 0.0)) <= 0.1
	return stats


func _float_stats(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"count": 0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample_value in sorted:
		total += float(sample_value)
	return {
		"count": sorted.size(),
		"avg": total / float(sorted.size()),
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"max": float(sorted[sorted.size() - 1]),
	}


func _int_stats(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"count": 0, "avg": 0.0, "p50": 0, "p95": 0, "max": 0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0
	for sample_value in sorted:
		total += int(sample_value)
	return {
		"count": sorted.size(),
		"avg": float(total) / float(sorted.size()),
		"p50": int(_percentile(sorted, 0.50)),
		"p95": int(_percentile(sorted, 0.95)),
		"max": int(sorted[sorted.size() - 1]),
	}


func _percentile(sorted_samples: Array, percentile: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var raw_index := int(ceil(float(sorted_samples.size()) * clampf(percentile, 0.0, 1.0))) - 1
	var index := clampi(raw_index, 0, sorted_samples.size() - 1)
	return float(sorted_samples[index])


func _platform_label() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("windows"):
		return "windows"
	return "desktop"


func _current_memory_bytes() -> int:
	var memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	if memory_bytes <= 0 and OS.has_feature("web"):
		return _web_heap_bytes()
	return memory_bytes


func _web_heap_bytes() -> int:
	if frame_index - last_web_heap_sample_frame < WEB_HEAP_SAMPLE_STRIDE_FRAMES:
		return last_web_heap_bytes
	last_web_heap_sample_frame = frame_index
	var heap_value: Variant = JavaScriptBridge.eval("performance && performance.memory ? performance.memory.usedJSHeapSize : 0", true)
	last_web_heap_bytes = maxi(0, int(heap_value))
	return last_web_heap_bytes


static func _runtime_options() -> Dictionary:
	var options: Dictionary = {}
	for arg_value in OS.get_cmdline_user_args():
		_apply_token_option(options, str(arg_value))
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		_apply_query_options(options, query)
	return options


static func _apply_token_option(options: Dictionary, token: String) -> void:
	var clean := token.strip_edges()
	if clean.begins_with("--"):
		clean = clean.substr(2)
	if clean.is_empty():
		return
	if clean.find("=") == -1:
		_set_option(options, clean, "1")
		return
	var parts := clean.split("=", true, 1)
	_set_option(options, str(parts[0]), str(parts[1]))


static func _apply_query_options(options: Dictionary, query: String) -> void:
	var clean := query.strip_edges()
	if clean.begins_with("?"):
		clean = clean.substr(1)
	if clean.is_empty():
		return
	for pair_value in clean.split("&"):
		var pair := str(pair_value)
		if pair.is_empty():
			continue
		if pair.find("=") == -1:
			_set_option(options, pair, "1")
		else:
			var parts := pair.split("=", true, 1)
			_set_option(options, str(parts[0]), str(parts[1]))


static func _set_option(options: Dictionary, key: String, value: String) -> void:
	var normalized := key.strip_edges().replace("-", "_")
	if normalized.is_empty():
		return
	options[normalized] = value.strip_edges()


static func _option_bool(options: Dictionary, key: String, fallback: bool) -> bool:
	if not options.has(key):
		return fallback
	var raw := str(options.get(key, "")).strip_edges().to_lower()
	return raw == "1" or raw == "true" or raw == "yes" or raw == "on"


static func _option_int(options: Dictionary, key: String, fallback: int) -> int:
	if not options.has(key):
		return fallback
	var raw := str(options.get(key, "")).strip_edges()
	if not raw.is_valid_int():
		return fallback
	return int(raw)
