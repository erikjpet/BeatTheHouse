class_name PerfTelemetryOverlay
extends Control

# Debug-only runtime telemetry for low-end/web baselines. The node is never
# created unless an explicit command-line flag or web query parameter enables it.

const SlotStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const PerformanceFixtureSetupScript := preload("res://scripts/ui/performance_fixture_setup.gd")
const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const CoinPusherLiveSessionScript := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")

const REQUIRED_GAME_IDS := [
	"pull_tabs",
	"scratch_tickets",
	"slot",
	"bar_dice",
	"blackjack",
	"baccarat",
	"roulette",
	"craps",
	"crew_draw_poker",
	"video_poker",
]
const ACTIVE_ACTIONS := {
	"pull_tabs": "buy_tab",
	"scratch_tickets": "buy_scratch_ticket",
	"slot": "spin",
	"bar_dice": "roll",
	"blackjack": "play_basic",
	"baccarat": "deal_baccarat",
	"roulette": "spin_roulette",
	"craps": "roll_craps",
	"crew_draw_poker": "deal",
	"video_poker": "draw",
}
const ACTIVE_STAKES := {
	"pull_tabs": 1,
	"scratch_tickets": 2,
	"slot": 10,
	"bar_dice": 10,
	"blackjack": 10,
	"baccarat": 20,
	"roulette": 10,
	"craps": 10,
	"crew_draw_poker": 5,
	"video_poker": 5,
}
const PERF06_IDLE_PHASES := {
	"pull_tabs": "idle",
	"scratch_tickets": "idle",
	"slot": "idle",
	"bar_dice": "idle",
	"blackjack": "betting_idle",
	"baccarat": "betting_idle",
	"roulette": "betting_idle",
	"craps": "idle",
	"crew_draw_poker": "actor_idle",
	"video_poker": "idle",
}
const PERF06_ACTIVE_PHASES := {
	"pull_tabs": "purchase_active",
	"scratch_tickets": "purchase",
	"slot": "spin",
	"bar_dice": "wager_roll",
	"blackjack": "deal_action",
	"baccarat": "deal_reveal",
	"roulette": "spin",
	"craps": "throw",
	"crew_draw_poker": "deal_action",
	"video_poker": "wager_draw_hold",
}
const DEFAULT_SAMPLE_STRIDE_FRAMES := 30
const DEFAULT_SCENARIO_FRAMES := 180
const DEFAULT_ACTIVE_FRAMES := 240
const DEFAULT_MEMORY_SECONDS := 600
const OVERLAY_REFRESH_STRIDE_FRAMES := 15
const WEB_HEAP_SAMPLE_STRIDE_FRAMES := 60
const REPORT_PREFIX := "BTH_PERF_REPORT "
const READY_PREFIX := "BTH_PERF_READY "
const COIN_PUSHER_FIXTURE_SEED := "practice:coin_pusher_full_cap"
const COIN_PUSHER_SHIPPED_BODY_COUNT := 160
const COIN_PUSHER_SOLVER_STRESS_BODY_COUNT := 300
const COIN_PUSHER_SOLVER_SAMPLE_COUNT := 60
const COIN_PUSHER_SOLVER_TICK_P95_BUDGET_MS := 12.0
const COIN_PUSHER_IDLE_SAMPLE_FRAMES := 120
const COIN_PUSHER_ACTION_SAMPLE_FRAMES := 60
const IDLE_LIVENESS_MINIMUM_INTERVALS := 2
const IDLE_LIVENESS_WAIT_GRACE_MSEC := 5000
const ACTIVE_PHASE_MINIMUM_FRAMES := 12
const ACTIVE_PHASE_MINIMUM_MSEC := 500
const ACTIVE_PHASE_CHANNELS := {
	"baccarat": "baccarat_deal",
	"roulette": "roulette_spin",
}
const PERF06_TIMELINE_GAMES := ["baccarat", "roulette", "craps"]
const ALLOCATION_COPY_SOURCE_IDS := [
	"foundation_snapshot",
	"environment_runtime",
	"surface_automation",
	"surface_realtime",
	"layout",
	"autosave_flush",
	"coin_pusher_native_step",
	"producer_fixture",
]
const PERF06_SYSTEM_ALLOCATION_ROOTS := {
	"meta_home": ["environment_runtime", "layout", "foundation_snapshot"],
	"room_environment": ["environment_runtime", "layout", "foundation_snapshot"],
	"dynamic_scenario": ["environment_runtime", "layout", "foundation_snapshot"],
	"crew": ["environment_runtime", "surface_realtime", "foundation_snapshot"],
	"world": ["environment_runtime", "layout", "foundation_snapshot"],
	"talk_dialogue": ["surface_realtime", "layout", "foundation_snapshot"],
	"run_report": ["layout", "foundation_snapshot"],
	"inventory_service": ["surface_realtime", "layout", "foundation_snapshot"],
	"audio": ["environment_runtime", "foundation_snapshot"],
	"save_restore": ["autosave_flush", "foundation_snapshot"],
	"maximal_composition": ALLOCATION_COPY_SOURCE_IDS,
	"run_trajectory": ALLOCATION_COPY_SOURCE_IDS,
}
# CPU-throttled shipped Web frames can leave a substantial live-session
# accumulator for the production chunked-exit path to drain. This bound affects
# setup synchronization only; locked measurement windows remain unchanged.
const COIN_PUSHER_EXIT_WAIT_FRAMES := 600

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
var current_start_liveness: Dictionary = {}
var frame_ms_samples: Array = []
var process_ms_samples: Array = []
var physics_ms_samples: Array = []
var draw_call_samples: Array = []
var render_object_samples: Array = []
var primitive_samples: Array = []
var memory_samples: Array = []
var memory_delta_samples: Array = []
var memory_positive_delta_samples: Array = []
var memory_negative_delta_samples: Array = []
var object_count_samples: Array = []
var object_count_delta_samples: Array = []
var object_count_positive_delta_samples: Array = []
var object_count_negative_delta_samples: Array = []
var node_count_samples: Array = []
var node_count_delta_samples: Array = []
var orphan_node_count_samples: Array = []
var monitor_sample_count := 0
var last_sample_memory_bytes := 0
var last_sample_object_count := 0
var last_sample_node_count := 0
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
var foundation_snapshot_usec_samples: Array = []
var foundation_environment_runtime_usec_samples: Array = []
var foundation_autosave_usec_samples: Array = []
var foundation_layout_usec_samples: Array = []
var foundation_coin_pusher_native_step_usec_samples: Array = []
var foundation_surface_automation_usec_samples: Array = []
var foundation_surface_realtime_usec_samples: Array = []
var foundation_surface_realtime_ui_usec_samples: Array = []
var foundation_surface_realtime_module_usec_samples: Array = []
var foundation_surface_realtime_augment_usec_samples: Array = []
var foundation_snapshot_last_usec := 0
var foundation_environment_runtime_last_usec := 0
var foundation_autosave_last_usec := 0
var foundation_layout_last_usec := 0
var foundation_coin_pusher_native_step_last_usec := 0
var foundation_surface_automation_last_usec := 0
var foundation_surface_realtime_last_usec := 0
var foundation_surface_realtime_ui_last_usec := 0
var foundation_surface_realtime_module_last_usec := 0
var foundation_surface_realtime_augment_last_usec := 0
var explicit_allocation_counts := PackedInt64Array()
var explicit_shallow_copy_counts := PackedInt64Array()
var explicit_deep_copy_counts := PackedInt64Array()
var explicit_allocation_copy_bytes := PackedInt64Array()
var explicit_allocation_audited_sources := PackedByteArray()


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
		"web_thread_feature": OS.has_feature("threads"),
	})
	if plan_id == "l02":
		call_deferred("_run_l02_plan")
	elif plan_id == "secure_entropy":
		call_deferred("_run_secure_entropy_plan")
	elif plan_id == "corner_store":
		call_deferred("_run_corner_store_plan")
	elif plan_id == "lb3":
		call_deferred("_run_lb3_plan")
	elif plan_id == "la1":
		call_deferred("_run_la1_plan")
	elif plan_id == "la5":
		call_deferred("_run_la5_plan")
	elif plan_id == "la6":
		call_deferred("_run_la6_plan")
	elif plan_id == "grand_casino":
		call_deferred("_run_grand_casino_plan")
	elif plan_id == "coin_pusher":
		call_deferred("_run_coin_pusher_plan")


func configure_for_probe(owner: FoundationMain, overlay_visible: bool) -> void:
	app = owner
	runtime_options = {}
	telemetry_enabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 4096
	created_msec = Time.get_ticks_msec()
	show_overlay = overlay_visible
	visible = overlay_visible
	if show_overlay:
		_build_overlay()
	_begin_scenario("overlay_cost_probe", {"surface": "environment", "mode": "idle"})


func travel_stage_timing_enabled(target_id: String) -> bool:
	return target_id == "corner_store" and plan_id in ["l02", "corner_store"]


func begin_foundation_frame() -> void:
	foundation_snapshot_last_usec = 0
	foundation_environment_runtime_last_usec = 0
	foundation_autosave_last_usec = 0
	foundation_layout_last_usec = 0
	foundation_coin_pusher_native_step_last_usec = 0
	foundation_surface_automation_last_usec = 0
	foundation_surface_realtime_last_usec = 0
	foundation_surface_realtime_ui_last_usec = 0
	foundation_surface_realtime_module_last_usec = 0
	foundation_surface_realtime_augment_last_usec = 0


func record_foundation_subsystem_usec(subsystem: String, elapsed_usec: int) -> void:
	var value := maxi(0, elapsed_usec)
	var allocation_source := "foundation_snapshot" if subsystem == "snapshot_builds" else subsystem
	match subsystem:
		"snapshot_builds":
			foundation_snapshot_last_usec += value
		"environment_runtime":
			foundation_environment_runtime_last_usec += value
		"autosave_flush":
			foundation_autosave_last_usec += value
		"layout":
			foundation_layout_last_usec += value
		"coin_pusher_native_step":
			foundation_coin_pusher_native_step_last_usec += value
		"surface_automation":
			foundation_surface_automation_last_usec += value
		"surface_realtime":
			foundation_surface_realtime_last_usec += value
		"surface_realtime_ui":
			foundation_surface_realtime_ui_last_usec += value
		"surface_realtime_module":
			foundation_surface_realtime_module_last_usec += value
		"surface_realtime_augment":
			foundation_surface_realtime_augment_last_usec += value
	if allocation_source in ALLOCATION_COPY_SOURCE_IDS:
		mark_allocation_root_audited(allocation_source)


# Opt-in probes call this only when the telemetry overlay exists. Normal play
# never constructs this node, so explicit allocation/copy accounting has zero
# default-game frame cost. `source` must name the instrumented operation rather
# than inferring language allocations from memory deltas.
func record_allocation_copy(kind: String, source: String, count: int = 1, bytes: int = 0) -> void:
	var normalized_kind := kind.strip_edges().to_lower()
	if normalized_kind not in ["allocation", "shallow_copy", "deep_copy"]:
		return
	var source_index := ALLOCATION_COPY_SOURCE_IDS.find(source.strip_edges())
	if source_index < 0 or count <= 0 or bytes < 0:
		return
	explicit_allocation_audited_sources[source_index] = 1
	if normalized_kind == "allocation":
		explicit_allocation_counts[source_index] += count
	elif normalized_kind == "shallow_copy":
		explicit_shallow_copy_counts[source_index] += count
	else:
		explicit_deep_copy_counts[source_index] += count
	explicit_allocation_copy_bytes[source_index] += bytes


func mark_allocation_root_audited(source: String) -> void:
	var source_index := ALLOCATION_COPY_SOURCE_IDS.find(source.strip_edges())
	if source_index >= 0:
		explicit_allocation_audited_sources[source_index] = 1


func _process(delta: float) -> void:
	if not telemetry_enabled:
		return
	var started_usec := Time.get_ticks_usec()
	frame_index += 1
	var frame_ms := maxf(0.0, delta * 1000.0)
	if scenario_active:
		frame_ms_samples.append(frame_ms)
		foundation_snapshot_usec_samples.append(foundation_snapshot_last_usec)
		foundation_environment_runtime_usec_samples.append(foundation_environment_runtime_last_usec)
		foundation_autosave_usec_samples.append(foundation_autosave_last_usec)
		foundation_layout_usec_samples.append(foundation_layout_last_usec)
		foundation_coin_pusher_native_step_usec_samples.append(foundation_coin_pusher_native_step_last_usec)
		foundation_surface_automation_usec_samples.append(foundation_surface_automation_last_usec)
		foundation_surface_realtime_usec_samples.append(foundation_surface_realtime_last_usec)
		foundation_surface_realtime_ui_usec_samples.append(foundation_surface_realtime_ui_last_usec)
		foundation_surface_realtime_module_usec_samples.append(foundation_surface_realtime_module_last_usec)
		foundation_surface_realtime_augment_usec_samples.append(foundation_surface_realtime_augment_last_usec)
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
		"boot_timeline": _boot_timeline_snapshot(),
		"scenario_count": scenario_records.size(),
		"scenarios": scenario_records,
		"events": telemetry_events,
		"telemetry_overhead": _overhead_stats(),
		"build_identity": {
			"source_commit": str(runtime_options.get("bth_perf_source_commit", "")),
			"export_sha256": str(runtime_options.get("bth_perf_export_sha256", "")),
		},
		"evidence_profile": str(runtime_options.get("bth_perf_evidence_profile", OS.get_environment("BTH_PERF_EVIDENCE_PROFILE"))),
	}
	_write_report_file(report)
	_emit_console(REPORT_PREFIX, report)
	return report


# The Web runtime can close before its final console message crosses the
# browser/probe boundary. Keep the tree alive for two frames so a successful
# auto-quit run cannot be misreported as a timeout.
func _quit_after_report_flush() -> void:
	if not auto_quit:
		return
	if OS.has_feature("web"):
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()


func mark_event(event_id: String, data: Dictionary = {}) -> void:
	telemetry_events.append({
		"id": event_id,
		"msec": Time.get_ticks_msec(),
		"scenario": current_scenario,
		"data": data.duplicate(false),
	})


func _run_l02_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	await _measure_meta_home()
	await _measure_corner_store()
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		await _measure_game(game_id)
	await _measure_slot_autoplay()
	await _measure_pinball_feature()
	await _measure_world_map()
	await _measure_scripted_memory()
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _measure_meta_home() -> void:
	var opened_started_usec := Time.get_ticks_usec()
	_begin_system_phase("meta_home_open", "meta_home", "open", "transition")
	app.call("open_meta_home")
	var open_snapshot: Dictionary = app.call("current_screen_snapshot")
	var open_environment: Dictionary = app.call("current_environment_view_snapshot")
	_complete_system_evidence(
		bool(open_snapshot.get("has_run", false)) and str(open_snapshot.get("screen", "")) == "ENVIRONMENT",
		{"screen": str(open_snapshot.get("screen", "")), "environment_id": str(open_environment.get("id", ""))}
	)
	mark_event("meta_home_open", {
		"duration_ms": _duration_ms_since(opened_started_usec),
		"environment_id": str(open_environment.get("id", "")),
	})
	await _finish_system_phase(mini(scenario_frames, 90))
	await _measure_system_state(
		"meta_home_animated_idle", "meta_home", "animated_idle",
		bool(open_snapshot.get("has_run", false)) and str(open_snapshot.get("screen", "")) == "ENVIRONMENT",
		{"environment_id": str(open_environment.get("id", ""))}, scenario_frames, "animated_idle"
	)
	_begin_system_phase("meta_home_close", "meta_home", "close", "transition")
	app.call("return_to_main_menu")
	var close_snapshot: Dictionary = app.call("current_screen_snapshot")
	_complete_system_evidence(
		str(close_snapshot.get("screen", "")) == "START" and not bool(close_snapshot.get("has_run", true)),
		{"screen": str(close_snapshot.get("screen", "")), "has_run": bool(close_snapshot.get("has_run", true))}
	)
	await _finish_system_phase(mini(scenario_frames, 90))


func _run_secure_entropy_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	mark_event("secure_entropy_contract", _secure_entropy_contract())
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _secure_entropy_contract() -> Dictionary:
	var requested_sizes := [16, 32, CrewTurnModelScript.PRIVATE_SAVE_PLAIN_BYTES]
	var exact_lengths := true
	var nonrepeating := true
	var crypto := Crypto.new()
	for byte_count_value in requested_sizes:
		var byte_count := int(byte_count_value)
		var first := crypto.generate_random_bytes(byte_count)
		var second := crypto.generate_random_bytes(byte_count)
		exact_lengths = exact_lengths and first.size() == byte_count and second.size() == byte_count
		nonrepeating = nonrepeating and first != second
	var authority_id := CrewTurnModelScript.new_authority_id()
	var binding := CrewTurnModelScript.private_save_binding(authority_id, "WEB-ENTROPY-CONTRACT", {"surface": "exported_web"})
	var private_state := {
		"v": CrewTurnModelScript.STATE_VERSION,
		"m": "crew_switch",
		"w": [CrewTurnModelScript.SIGNAL_PATTERN],
		"e": [CrewTurnModelScript.SIGNAL_PATTERN],
		"h": false,
		"c": false,
		"f": 1,
		"t": [{"b": 9, "q": 2}],
	}
	var payload := {"x": private_state, "g": [[2, 0, 8, 4, "6730303031", "666978747572655f6a6f62"]], "q": 1}
	var normalized := CrewTurnModelScript.normalize_private_payload(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS)
	var first_encoded := CrewTurnModelScript.pack_private_save(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	var second_encoded := CrewTurnModelScript.pack_private_save(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	var first_capsule := Marshalls.base64_to_raw(first_encoded)
	var second_capsule := Marshalls.base64_to_raw(second_encoded)
	var restored := CrewTurnModelScript.unpack_private_save(first_encoded, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	var tamper_rejected := false
	if first_capsule.size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES:
		var tampered := first_capsule.duplicate()
		tampered[tampered.size() - 1] = int(tampered[tampered.size() - 1]) ^ 1
		tamper_rejected = CrewTurnModelScript.unpack_private_save(Marshalls.raw_to_base64(tampered), CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding).is_empty()
	var plain_payload := CrewTurnModelScript.canonical_json(normalized).to_utf8_buffer()
	var fixed_width := first_capsule.size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES and second_capsule.size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES
	var distinct_capsules := fixed_width and first_capsule.slice(0, 16) != second_capsule.slice(0, 16) and first_capsule != second_capsule
	var round_trip := not normalized.is_empty() and CrewTurnModelScript.canonical_json(restored) == CrewTurnModelScript.canonical_json(normalized)
	var privacy_preserved := fixed_width and not _packed_contains(first_capsule, plain_payload) and not _packed_contains(second_capsule, plain_payload)
	var passed := exact_lengths and nonrepeating and CrewTurnModelScript.valid_authority_id(authority_id) \
		and fixed_width and distinct_capsules and round_trip and tamper_rejected and privacy_preserved
	return {
		"passed": passed,
		"entropy_provider": "godot_crypto_mbedtls",
		"requested_sizes": requested_sizes,
		"exact_lengths": exact_lengths,
		"nonrepeating": nonrepeating,
		"authority_id_valid": CrewTurnModelScript.valid_authority_id(authority_id),
		"capsule_bytes": first_capsule.size(),
		"fixed_width": fixed_width,
		"distinct_capsules": distinct_capsules,
		"aes_round_trip": round_trip,
		"hmac_tamper_rejected": tamper_rejected,
		"privacy_preserved": privacy_preserved,
	}


func _packed_contains(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty() or needle.size() > haystack.size():
		return false
	for start in range(haystack.size() - needle.size() + 1):
		var matches := true
		for offset in range(needle.size()):
			if haystack[start + offset] != needle[offset]:
				matches = false
				break
		if matches:
			return true
	return false


func _run_corner_store_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("corner_store_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	await _measure_corner_store()
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _run_grand_casino_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("grand_casino_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	app.start_foundation_run("WEB-GRAND-CASINO-LATE")
	await _wait_frames(8)
	var run_state: RunState = app.get("run_state") as RunState
	var generator: RunGenerator = app.get("generator") as RunGenerator
	if run_state == null or generator == null:
		mark_event("grand_casino_missing_runtime")
		dump_report()
		await _quit_after_report_flush()
		return
	run_state.bankroll = maxi(run_state.bankroll, 5000)
	run_state.narrative_flags["grand_casino_invite"] = true
	var grand_installed := _install_generated_grand_casino_fixture(run_state)
	mark_event("grand_casino_fixture_install", grand_installed)
	run_state.add_suspicion("web_grand_casino_late_probe", 85, "behavior")
	run_state.narrative_flags["grand_casino_high_limit_access"] = true
	run_state.narrative_flags["grand_casino_high_limit_access_method"] = "performance_probe"
	app.call("_refresh")
	_begin_scenario("grand_casino_late_settle", {"surface": "grand_casino", "mode": "late_run_entry"})
	await _wait_frames(maxi(scenario_frames, 360))
	_end_scenario()
	await _measure_grand_casino_system_matrix(run_state, generator)
	_begin_scenario("grand_casino_room_churn", {"surface": "grand_casino", "mode": "repeated_room_transitions"})
	var room_sequence := [
		RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID,
		RunState.GRAND_CASINO_ARCHETYPE_ID,
		RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID,
		RunState.GRAND_CASINO_ARCHETYPE_ID,
	]
	for cycle in range(2):
		for room_id_value in room_sequence:
			var room_id := str(room_id_value)
			if not generator.enter_grand_casino_room(run_state, room_id):
				mark_event("grand_casino_room_transition_failed", {"cycle": cycle, "room_id": room_id})
				continue
			app.call("_update_procedural_music")
			app.call("_refresh")
			await _wait_frames(90)
	_end_scenario()
	await _measure_scenario("grand_casino_late_idle", {"surface": "grand_casino", "mode": "late_run_idle"}, scenario_frames)
	mark_event("grand_casino_late_debug", app.call("debug_soak_snapshot"))
	mark_event("grand_casino_web_audio_bridge_stats", WebAudioBridgeScript.debug_stats())
	l02_driver_complete = true
	dump_report()
	_publish_grand_casino_browser_summary()
	await _quit_after_report_flush()


func _publish_grand_casino_browser_summary() -> void:
	if not OS.has_feature("web"):
		return
	var summary := {
		"scenarios": scenario_records,
		"events": telemetry_events,
		"telemetry_overhead": _overhead_stats(),
	}
	var title := "BTH_GC_REPORT " + JSON.stringify(summary)
	JavaScriptBridge.eval("document.title = %s;" % JSON.stringify(title), true)


func _install_generated_grand_casino_fixture(run_state: RunState) -> Dictionary:
	var library: ContentLibrary = app.get("library") as ContentLibrary
	var generator: RunGenerator = app.get("generator") as RunGenerator
	if library == null or generator == null:
		return {"ok": false, "reason": "missing_generation_runtime"}
	var archetype := library.environment_archetype(RunState.GRAND_CASINO_ARCHETYPE_ID)
	if archetype.is_empty():
		return {"ok": false, "reason": "missing_archetype"}
	var rng := run_state.create_rng("perf06_grand_casino_environment")
	var scenario_value: Variant = generator.call("_select_scenario", run_state, RunState.GRAND_CASINO_ARCHETYPE_ID, rng)
	var candidates: Array = []
	if typeof(scenario_value) == TYPE_DICTIONARY and not (scenario_value as Dictionary).is_empty():
		candidates.append((scenario_value as Dictionary).duplicate(true))
	var pool_value: Variant = library.call("_scenarios_for_archetype_readonly", RunState.GRAND_CASINO_ARCHETYPE_ID)
	if typeof(pool_value) == TYPE_ARRAY:
		for candidate_value in pool_value as Array:
			if typeof(candidate_value) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = candidate_value
			var candidate_id := str(candidate.get("id", ""))
			if candidate_id.is_empty():
				continue
			var already_present := false
			for existing_value in candidates:
				already_present = already_present or str((existing_value as Dictionary).get("id", "")) == candidate_id
			if not already_present:
				candidates.append(candidate.duplicate(true))
	var installed: Dictionary = {"ok": false, "errors": ["No Grand Casino scenario candidate installed."]}
	var installed_scenario: Dictionary = {}
	var attempts: Array = []
	for candidate_value in candidates:
		var scenario: Dictionary = candidate_value
		var scenario_id := str(scenario.get("id", ""))
		var candidate_rng := rng.fork("scenario_fixture:%s" % scenario_id)
		run_state.seed_scenario_for_node(RunState.GRAND_CASINO_ARCHETYPE_ID, scenario)
		var generated := EnvironmentInstance.from_archetype(archetype, 1, candidate_rng, library, run_state.challenge_config, scenario)
		var environment := generated.to_dict()
		environment["world_node_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
		run_state.apply_town_generation_modifiers(environment, candidate_rng)
		var generated_states: Variant = generator.call("_generated_game_states", run_state, environment, candidate_rng)
		if typeof(generated_states) == TYPE_DICTIONARY:
			environment["game_states"] = generated_states
		environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
		var rollback_value: Variant = generator.call("_travel_rollback_snapshot", run_state)
		var rollback: Dictionary = rollback_value if typeof(rollback_value) == TYPE_DICTIONARY else {}
		var installed_value: Variant = generator.call("_install_environment_with_rollback", run_state, environment, rollback)
		installed = installed_value if typeof(installed_value) == TYPE_DICTIONARY else {}
		attempts.append({"scenario_id": scenario_id, "ok": bool(installed.get("ok", false)), "errors": installed.get("errors", [])})
		if bool(installed.get("ok", false)):
			installed_scenario = scenario
			break
	# Keep the rest of the system matrix runnable while an authored scenario is
	# fail-closed by its own layout contract. The dynamic rows remain red and carry
	# every rejected scenario attempt; no fallback is allowed to counterfeit them.
	if not bool(installed.get("ok", false)):
		var fallback_rng := rng.fork("scenario_fixture:plain_grand_casino")
		var fallback := EnvironmentInstance.from_archetype(archetype, 1, fallback_rng, library, run_state.challenge_config)
		var fallback_environment := fallback.to_dict()
		fallback_environment["world_node_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
		fallback_environment["layout"] = EnvironmentInstance.ensure_generated_layout(fallback_environment)
		var fallback_rollback_value: Variant = generator.call("_travel_rollback_snapshot", run_state)
		var fallback_rollback: Dictionary = fallback_rollback_value if typeof(fallback_rollback_value) == TYPE_DICTIONARY else {}
		var fallback_install_value: Variant = generator.call("_install_environment_with_rollback", run_state, fallback_environment, fallback_rollback)
		installed = fallback_install_value if typeof(fallback_install_value) == TYPE_DICTIONARY else {}
	run_state.save_rng(rng)
	app.call("_refresh")
	return {
		"ok": bool(installed.get("ok", false)) and str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID,
		"installed": installed,
		"environment_id": str(run_state.current_environment.get("archetype_id", "")),
		"scenario_id": str(run_state.current_environment.get("scenario_id", "")),
		"selected_scenario_id": str(installed_scenario.get("id", "")),
		"attempts": attempts,
	}


func _measure_grand_casino_system_matrix(run_state: RunState, generator: RunGenerator) -> void:
	var phase_frames := mini(scenario_frames, 90)
	var environment := run_state.current_environment
	var environment_id := str(environment.get("archetype_id", ""))
	var scenario_id := str(environment.get("scenario_id", ""))
	var semantic_ready := bool(environment.get("scenario_semantic_ready", false))
	var render_snapshot: Dictionary = environment.get("scenario_render_snapshot", {}) if typeof(environment.get("scenario_render_snapshot", {})) == TYPE_DICTIONARY else {}
	var projection: Dictionary = run_state.scenario_sequence_projection()
	var base_actors: Array = environment.get("scenario_base_actors", []) if typeof(environment.get("scenario_base_actors", [])) == TYPE_ARRAY else []
	var crew_standing := run_state.crew_standing()
	await _measure_system_state("maximal_composition_entry", "maximal_composition", "entry", environment_id == RunState.GRAND_CASINO_ARCHETYPE_ID, {"environment_id": environment_id, "scenario_id": scenario_id}, phase_frames, "transition")
	await _measure_system_state("maximal_composition_live", "maximal_composition", "live", semantic_ready and not render_snapshot.is_empty(), {"semantic_ready": semantic_ready, "render_snapshot_present": not render_snapshot.is_empty()}, phase_frames)
	await _measure_system_state("run_trajectory_maximal_late", "run_trajectory", "maximal_late", run_state.suspicion_level() >= 85 and environment_id == RunState.GRAND_CASINO_ARCHETYPE_ID, {"suspicion": run_state.suspicion_level(), "environment_id": environment_id}, phase_frames)
	await _measure_system_state("world_maximal_environment", "world", "maximal_environment", environment_id == RunState.GRAND_CASINO_ARCHETYPE_ID and not environment.is_empty(), {"environment_id": environment_id, "object_count": _environment_interactable_objects().size()}, phase_frames)
	await _measure_system_state("dynamic_scenario_fully_staged", "dynamic_scenario", "fully_staged", semantic_ready and not projection.is_empty() and not render_snapshot.is_empty(), {"scenario_id": scenario_id, "projection_phase": str(projection.get("phase_id", "")), "actor_count": base_actors.size()}, phase_frames)
	await _measure_system_state("crew_actor_idle", "crew", "actor_idle", not base_actors.is_empty(), {"scenario_id": scenario_id, "actor_count": base_actors.size()}, phase_frames, "idle")
	await _measure_system_state("crew_late_run", "crew", "late_run", typeof(crew_standing) == TYPE_DICTIONARY and run_state.suspicion_level() >= 85, {"standing_members": crew_standing.size(), "suspicion": run_state.suspicion_level()}, phase_frames)

	await _measure_dynamic_scenario_actions(run_state, phase_frames)
	await _measure_grand_casino_room_and_dialogue(run_state, generator, phase_frames)
	await _measure_inventory_phases(run_state, phase_frames)
	await _measure_audio_phases(run_state, generator, phase_frames)
	await _measure_grand_casino_game_background(run_state, generator, phase_frames)
	await _measure_save_terminal_restore_phases(run_state, phase_frames)


func _environment_interactable_objects() -> Array:
	if app == null:
		return []
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var objects_value: Variant = snapshot.get("interactable_objects", [])
	return objects_value if typeof(objects_value) == TYPE_ARRAY else []


func _first_interactable_object(types: Array = []) -> Dictionary:
	for object_value in _environment_interactable_objects():
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		var object_type := str(object_data.get("object_type", ""))
		if object_id.is_empty() or not bool(object_data.get("enabled", true)):
			continue
		if types.is_empty() or object_type in types:
			return object_data
	return {}


func _measure_dynamic_scenario_actions(run_state: RunState, phase_frames: int) -> void:
	var before_projection := run_state.scenario_sequence_projection()
	var scenario_object := _first_interactable_object(["scenario_sequence", "scenario"])
	var object_id := str(scenario_object.get("object_id", ""))
	_begin_system_phase("dynamic_scenario_beat_transition", "dynamic_scenario", "beat_transition", "transition")
	var accepted := not object_id.is_empty() and bool(app.call("activate_interactable_object", object_id))
	await _wait_frames(12)
	var after_projection := run_state.scenario_sequence_projection()
	_complete_system_evidence(accepted and JSON.stringify(before_projection) != JSON.stringify(after_projection), {
		"accepted": accepted,
		"object_id": object_id,
		"before_phase": str(before_projection.get("phase_id", "")),
		"after_phase": str(after_projection.get("phase_id", "")),
	})
	await _finish_system_phase(phase_frames)
	var action_count := 1 if accepted else 0
	for _step in range(15):
		var next_object := _first_interactable_object(["scenario_sequence", "scenario"])
		var next_id := str(next_object.get("object_id", ""))
		if next_id.is_empty():
			break
		if not bool(app.call("activate_interactable_object", next_id)):
			break
		action_count += 1
		await _wait_frames(12)
	var final_projection := run_state.scenario_sequence_projection()
	var remaining_action := _first_interactable_object(["scenario_sequence", "scenario"])
	await _measure_system_state("dynamic_scenario_terminal_cleanup", "dynamic_scenario", "terminal_cleanup", action_count > 0 and remaining_action.is_empty(), {
		"action_count": action_count,
		"remaining_action_id": str(remaining_action.get("object_id", "")),
		"final_phase": str(final_projection.get("phase_id", "")),
		"semantic_ready": bool(run_state.current_environment.get("scenario_semantic_ready", false)),
	}, phase_frames, "transition")


func _measure_grand_casino_room_and_dialogue(run_state: RunState, generator: RunGenerator, phase_frames: int) -> void:
	_begin_system_phase("world_revisit", "world", "revisit", "transition")
	var cage_entered := generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	app.call("_refresh")
	_complete_system_evidence(cage_entered and str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, {
		"accepted": cage_entered,
		"environment_id": str(run_state.current_environment.get("archetype_id", "")),
	})
	await _finish_system_phase(phase_frames)
	var cage_object := _first_interactable_object(["casino_fixture", "dialogue"])
	if cage_object.is_empty():
		for object_value in _environment_interactable_objects():
			if typeof(object_value) == TYPE_DICTIONARY and str((object_value as Dictionary).get("object_id", "")).contains("cage_counter"):
				cage_object = object_value as Dictionary
				break
	var cage_object_id := str(cage_object.get("object_id", ""))
	_begin_system_phase("room_environment_object_focus", "room_environment", "object_focus", "transition")
	var focused := not cage_object_id.is_empty() and bool(app.call("focus_interactable_object", cage_object_id))
	_complete_system_evidence(focused and str(app.get("selected_object_id")) == cage_object_id, {"accepted": focused, "object_id": cage_object_id, "selected_object_id": str(app.get("selected_object_id"))})
	await _finish_system_phase(phase_frames)
	_begin_system_phase("room_environment_interaction", "room_environment", "interaction", "transition")
	var activated := not cage_object_id.is_empty() and bool(app.call("activate_interactable_object", cage_object_id))
	await _wait_frames(8)
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	_complete_system_evidence(activated and bool(talk.get("visible", false)), {"accepted": activated, "object_id": cage_object_id, "talk_event_id": str(talk.get("event_id", ""))})
	await _finish_system_phase(phase_frames)
	await _measure_live_dialogue_states(talk, phase_frames)
	var event_id := str((app.call("current_talk_dock_snapshot") as Dictionary).get("event_id", ""))
	if not event_id.is_empty():
		app.call("_ignore_talk_event", event_id, "performance_probe_reset")
		await _wait_frames(8)
	_begin_system_phase("crew_dialogue_open", "crew", "dialogue_open", "transition")
	var reopened := bool(app.call("_start_linda_cage_services", {"object_id": cage_object_id}))
	await _wait_frames(8)
	var reopened_talk: Dictionary = app.call("current_talk_dock_snapshot")
	_complete_system_evidence(reopened and bool(reopened_talk.get("visible", false)), {"accepted": reopened, "event_id": str(reopened_talk.get("event_id", ""))})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("crew_full_sequence", "crew", "full_sequence", bool(reopened_talk.get("visible", false)) and int(reopened_talk.get("choice_count", 0)) > 0, {"event_id": str(reopened_talk.get("event_id", "")), "choice_count": int(reopened_talk.get("choice_count", 0))}, phase_frames)
	_begin_system_phase("crew_dialogue_close", "crew", "dialogue_close", "transition")
	event_id = str(reopened_talk.get("event_id", ""))
	var closed := not event_id.is_empty() and bool(app.call("_ignore_talk_event", event_id, "performance_probe_close"))
	await _wait_frames(8)
	var closed_talk: Dictionary = app.call("current_talk_dock_snapshot")
	_complete_system_evidence(closed and not bool(closed_talk.get("visible", false)), {"accepted": closed, "event_id": event_id, "visible_after": bool(closed_talk.get("visible", false))})
	await _finish_system_phase(phase_frames)


func _measure_live_dialogue_states(initial_talk: Dictionary, phase_frames: int) -> void:
	var visible := bool(initial_talk.get("visible", false))
	var evidence := {"event_id": str(initial_talk.get("event_id", "")), "choice_count": int(initial_talk.get("choice_count", 0))}
	await _measure_system_state("talk_dialogue_dock_active", "talk_dialogue", "dock_active", visible, evidence, phase_frames)
	await _measure_system_state("talk_dialogue_dialogue_active", "talk_dialogue", "dialogue_active", visible and not str(initial_talk.get("summary", "")).is_empty(), evidence, phase_frames)
	await _measure_system_state("crew_dialogue_active", "crew", "dialogue_active", visible, evidence, phase_frames)
	var choice_ids: Array = initial_talk.get("choice_ids", []) if typeof(initial_talk.get("choice_ids", [])) == TYPE_ARRAY else []
	var event_id := str(initial_talk.get("event_id", ""))
	var choice_id := str(choice_ids[0]) if not choice_ids.is_empty() else ""
	_begin_system_phase("talk_dialogue_choice_advance", "talk_dialogue", "choice_advance", "transition")
	if not event_id.is_empty() and not choice_id.is_empty():
		app.call("_on_talk_dock_choice_requested", event_id, choice_id)
	await _wait_frames(8)
	var advanced: Dictionary = app.call("current_talk_dock_snapshot")
	var progressed := not event_id.is_empty() and not choice_id.is_empty() and JSON.stringify(initial_talk) != JSON.stringify(advanced)
	_complete_system_evidence(progressed, {"event_id": event_id, "choice_id": choice_id, "visible_after": bool(advanced.get("visible", false)), "event_after": str(advanced.get("event_id", ""))})
	await _finish_system_phase(phase_frames)
	var close_event_id := str(advanced.get("event_id", ""))
	_begin_system_phase("talk_dialogue_close", "talk_dialogue", "close", "transition")
	var accepted := true
	if not close_event_id.is_empty():
		accepted = bool(app.call("_ignore_talk_event", close_event_id, "performance_probe_close"))
	await _wait_frames(8)
	var after_close: Dictionary = app.call("current_talk_dock_snapshot")
	_complete_system_evidence(accepted and not bool(after_close.get("visible", false)), {"accepted": accepted, "event_id": close_event_id, "visible_after": bool(after_close.get("visible", false))})
	await _finish_system_phase(phase_frames)


func _measure_inventory_phases(run_state: RunState, phase_frames: int) -> void:
	run_state.add_item("instant_coffee")
	_begin_system_phase("inventory_service_open", "inventory_service", "open", "transition")
	app.call("open_run_inventory")
	await _wait_frames(8)
	var opened: Dictionary = app.call("current_run_inventory_snapshot")
	_complete_system_evidence(bool(opened.get("visible", false)), {"visible": bool(opened.get("visible", false)), "item_count": (opened.get("items", []) as Array).size()})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("inventory_service_populated_active", "inventory_service", "populated_active", bool(opened.get("visible", false)) and (opened.get("items", []) as Array).size() > 0, {"item_count": (opened.get("items", []) as Array).size(), "fixture_item": "instant_coffee"}, phase_frames)
	_begin_system_phase("inventory_service_mutation", "inventory_service", "mutation", "transition")
	var had_item := run_state.inventory.has("instant_coffee")
	run_state.remove_item("instant_coffee")
	app.call("_refresh")
	await _wait_frames(8)
	var mutated: Dictionary = app.call("current_run_inventory_snapshot")
	var removed := had_item and not run_state.inventory.has("instant_coffee")
	_complete_system_evidence(removed, {"removed": removed, "item_count_after": (mutated.get("items", []) as Array).size()})
	await _finish_system_phase(phase_frames)
	run_state.add_item("instant_coffee")
	_begin_system_phase("inventory_service_close", "inventory_service", "close", "transition")
	app.call("close_run_inventory")
	await _wait_frames(8)
	var closed: Dictionary = app.call("current_run_inventory_snapshot")
	_complete_system_evidence(not bool(closed.get("visible", false)), {"visible_after": bool(closed.get("visible", false))})
	await _finish_system_phase(phase_frames)


func _measure_audio_phases(run_state: RunState, generator: RunGenerator, phase_frames: int) -> void:
	_begin_system_phase("audio_maximal_cues", "audio", "maximal_cues")
	app.call("_play_environment_audio_cue", "phone_call", -2.0, "crew_world", {"stable_object_id": "perf06_phone"})
	app.call("_play_environment_audio_cue", "heat_gain", -2.0, "crew_world", {"stable_object_id": "perf06_heat"})
	await _wait_frames(8)
	var audio_debug: Dictionary = app.call("debug_soak_snapshot")
	var sfx_debug: Dictionary = audio_debug.get("environment_sfx", {}) if typeof(audio_debug.get("environment_sfx", {})) == TYPE_DICTIONARY else {}
	_complete_system_evidence(not sfx_debug.is_empty(), {"requested_cues": ["phone_call", "heat_gain"], "sfx_debug_present": not sfx_debug.is_empty()})
	await _finish_system_phase(phase_frames)
	_begin_system_phase("audio_transition_cleanup", "audio", "transition_cleanup", "transition")
	var entered_main := generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID)
	app.call("_update_procedural_music")
	app.call("_refresh")
	await _wait_frames(8)
	_complete_system_evidence(entered_main and str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID, {"accepted": entered_main, "environment_id": str(run_state.current_environment.get("archetype_id", ""))})
	await _finish_system_phase(phase_frames)


func _measure_grand_casino_game_background(run_state: RunState, generator: RunGenerator, phase_frames: int) -> void:
	if str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_ARCHETYPE_ID:
		generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID)
		app.call("_refresh")
	var game_ids: Array = run_state.current_environment.get("game_ids", []) if typeof(run_state.current_environment.get("game_ids", [])) == TYPE_ARRAY else []
	var game_id := str(game_ids[0]) if not game_ids.is_empty() else ""
	_begin_system_phase("maximal_composition_active_game_background", "maximal_composition", "active_game_background", "transition")
	var entered := not game_id.is_empty() and bool(app.call("enter_game", game_id))
	await _wait_frames(12)
	_complete_system_evidence(entered and app.get("current_game") != null and str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID, {"accepted": entered, "game_id": game_id, "environment_id": str(run_state.current_environment.get("archetype_id", ""))})
	await _finish_system_phase(phase_frames)
	_begin_system_phase("maximal_composition_exit", "maximal_composition", "exit", "transition")
	if entered:
		app.back_to_environment()
		await _wait_for_game_exit()
	await _wait_frames(8)
	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	_complete_system_evidence(str(screen_snapshot.get("screen", "")) == "ENVIRONMENT" and app.get("current_game") == null, {"screen": str(screen_snapshot.get("screen", "")), "game_id": game_id})
	await _finish_system_phase(phase_frames)


func _measure_save_terminal_restore_phases(run_state: RunState, phase_frames: int) -> void:
	var original_slot := str(app.get("autosave_slot_id"))
	var restore_slot := "perf06_grand_restore"
	var terminal_slot := "perf06_grand_terminal"
	app.set("autosave_slot_id", restore_slot)
	_begin_system_phase("save_restore_start_save", "save_restore", "start_save", "transition")
	var start_saved := bool(app.call("_autosave_foundation_run", "Performance start save.", true))
	_complete_system_evidence(start_saved, {"accepted": start_saved, "slot": restore_slot, "boundary": "start"})
	await _finish_system_phase(phase_frames)
	run_state.add_item("instant_coffee")
	_begin_system_phase("save_restore_mid_save", "save_restore", "mid_save", "transition")
	var mid_saved := bool(app.call("_autosave_foundation_run", "Performance mid save.", true))
	_complete_system_evidence(mid_saved, {"accepted": mid_saved, "slot": restore_slot, "boundary": "mid", "inventory_count": run_state.inventory.size()})
	await _finish_system_phase(phase_frames)
	_begin_system_phase("save_restore_maximal_save", "save_restore", "maximal_save", "transition")
	var maximal_saved := bool(app.call("_autosave_foundation_run", "Performance maximal save.", true))
	_complete_system_evidence(maximal_saved, {"accepted": maximal_saved, "slot": restore_slot, "environment_id": str(run_state.current_environment.get("archetype_id", "")), "suspicion": run_state.suspicion_level()})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("maximal_composition_save_restore_live", "maximal_composition", "save_restore_live", maximal_saved and not run_state.current_environment.is_empty(), {"slot": restore_slot, "environment_id": str(run_state.current_environment.get("archetype_id", ""))}, phase_frames)

	_begin_system_phase("run_report_terminal_transition", "run_report", "terminal_transition", "transition")
	run_state.fail_run("performance_probe", "Performance terminal fixture.")
	var terminal_result: Dictionary = app.call("_evaluate_run_terminal_state", true)
	app.call("_refresh")
	await _wait_frames(12)
	var report: Dictionary = app.call("current_run_report_snapshot")
	_complete_system_evidence(run_state.is_terminal() and not report.is_empty(), {"terminal": run_state.is_terminal(), "status": str(run_state.run_status), "report_present": not report.is_empty(), "evaluator": terminal_result})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("run_report_open", "run_report", "open", run_state.is_terminal() and not report.is_empty(), {"status": str(run_state.run_status), "report_keys": report.keys()}, phase_frames)
	var replay_before := float(report.get("replay_progress", 0.0))
	_begin_system_phase("run_report_replay", "run_report", "replay")
	await _wait_frames(maxi(phase_frames, 120))
	var replay_after_report: Dictionary = app.call("current_run_report_snapshot")
	var replay_after := float(replay_after_report.get("replay_progress", replay_before))
	_complete_system_evidence(not replay_after_report.is_empty() and replay_after >= replay_before, {"progress_before": replay_before, "progress_after": replay_after, "report_present": not replay_after_report.is_empty()})
	await _finish_system_phase(1)
	app.set("autosave_slot_id", terminal_slot)
	_begin_system_phase("save_restore_terminal_save", "save_restore", "terminal_save", "transition")
	var terminal_saved := bool(app.call("_autosave_foundation_run", "Performance terminal save.", true))
	_complete_system_evidence(terminal_saved and run_state.is_terminal(), {"accepted": terminal_saved, "slot": terminal_slot, "status": str(run_state.run_status)})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("maximal_composition_terminal_cleanup", "maximal_composition", "terminal_cleanup", run_state.is_terminal() and not (app.call("current_run_report_snapshot") as Dictionary).is_empty(), {"status": str(run_state.run_status)}, phase_frames, "transition")

	app.set("autosave_slot_id", restore_slot)
	_begin_system_phase("save_restore_restore_revisit", "save_restore", "restore_revisit", "transition")
	var restored := bool(app.call("_load_foundation_run_from_slot", false))
	await _wait_frames(12)
	var restored_run: RunState = app.get("run_state") as RunState
	var restore_ok := restored and restored_run != null and not restored_run.is_terminal() and str(restored_run.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID
	_complete_system_evidence(restore_ok, {"accepted": restored, "slot": restore_slot, "environment_id": str(restored_run.current_environment.get("archetype_id", "")) if restored_run != null else "", "terminal": restored_run.is_terminal() if restored_run != null else true})
	await _finish_system_phase(phase_frames)
	await _measure_system_state("run_trajectory_terminal_revisit", "run_trajectory", "terminal_revisit", restore_ok, {"restored_from_terminal": true, "slot": restore_slot}, phase_frames, "transition")
	app.set("autosave_slot_id", original_slot)


func _run_coin_pusher_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("coin_pusher_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	app.start_game_test_session("coin_pusher")
	await _wait_frames(4)
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	if run_state == null or game == null:
		mark_event("coin_pusher_fixture_failed", {"reason": "missing_runtime"})
		dump_report()
		await _quit_after_report_flush()
		return
	# start_game_test_session opens the ordinary 150-body practice machine. Exit
	# it through the production boundary first so that transient live state cannot
	# shadow the durable shipped-cap fixture installed below.
	app.back_to_environment()
	if not await _wait_for_coin_pusher_exit():
		mark_event("coin_pusher_fixture_failed", {"reason": "initial_exit_timeout"})
		dump_report()
		await _quit_after_report_flush()
		return
	if not _install_coin_pusher_fixture(run_state, game):
		mark_event("coin_pusher_fixture_failed")
		dump_report()
		await _quit_after_report_flush()
		return
	if not bool(app.call("enter_game", "coin_pusher")):
		mark_event("coin_pusher_enter_failed")
		dump_report()
		await _quit_after_report_flush()
		return
	await _wait_frames(4)
	_enable_coin_pusher_stage_diagnostic()
	var fixture := _coin_pusher_fixture_identity(run_state, game)
	mark_event("coin_pusher_fixture_identity", fixture)
	await _wait_frames(4)
	await _measure_coin_pusher_idle("coin_pusher_idle", false, fixture)
	await _measure_coin_pusher_goal_ritual(fixture)
	await _measure_coin_pusher_raw_solver(run_state, game)
	for action_value in [
		["coin_pusher_drop", "coin_pusher_active_drop"],
		["coin_pusher_carriage_left", "coin_pusher_active_carriage"],
		["coin_pusher_skill_stop", "coin_pusher_active_skill_stop"],
		["coin_pusher_skill_stop", "coin_pusher_active_skill_release"],
	]:
		await _measure_coin_pusher_action(str(action_value[0]), str(action_value[1]), fixture)
	# COLLECT receives a fresh authoritative fixture. Earlier action windows may
	# legitimately move or consume bodies, so seeding their derivative live state
	# cannot prove the binding shipped-origin conservation law.
	var collect_reinstall := await _reinstall_coin_pusher_fixture(run_state, game)
	if collect_reinstall.is_empty():
		mark_event("coin_pusher_collect_fixture_failed")
		dump_report()
		await _quit_after_report_flush()
		return
	var collect_fixture: Dictionary = collect_reinstall.get("fixture", {})
	mark_event("coin_pusher_collect_fixture_identity", collect_fixture)
	mark_event("coin_pusher_collect_fixture_observation", collect_reinstall.get("observation", {}))
	if not _seed_coin_pusher_collect_fixture(run_state, game):
		mark_event("coin_pusher_collect_seed_failed")
		dump_report()
		await _quit_after_report_flush()
		return
	await _measure_coin_pusher_action("coin_pusher_collect", "coin_pusher_active_collect", collect_fixture)
	# The active-action sequence is allowed to consume or move fixture bodies.
	# Reinstall and re-enter the identical durable 160-body fixture so reduced-
	# motion evidence cannot silently measure a depleted derivative state.
	var reduced_reinstall := await _reinstall_coin_pusher_fixture(run_state, game)
	if reduced_reinstall.is_empty():
		mark_event("coin_pusher_reduced_fixture_failed")
		dump_report()
		await _quit_after_report_flush()
		return
	var reduced_fixture: Dictionary = reduced_reinstall.get("fixture", {})
	mark_event("coin_pusher_reduced_fixture_identity", reduced_fixture)
	mark_event("coin_pusher_reduced_fixture_observation", reduced_reinstall.get("observation", {}))
	await _set_coin_pusher_reduce_motion(true)
	var reduced_sample_state := _coin_pusher_surface_state(_coin_pusher_canvas())
	mark_event("coin_pusher_reduced_sample_boundary", {
		"body_count": int(reduced_sample_state.get("coin_pusher_body_count", -1)),
		"tray_count": int(reduced_sample_state.get("coin_pusher_tray_count", -1)),
		"liveness_ticks": int(reduced_sample_state.get("coin_pusher_liveness_ticks", 0)),
		"conservation": _coin_pusher_conservation_snapshot(run_state, game),
	})
	await _measure_coin_pusher_idle("coin_pusher_reduced_motion", true, reduced_fixture)
	await _set_coin_pusher_reduce_motion(false)
	await _measure_coin_pusher_ceiling_refusal(run_state, game)
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _wait_for_coin_pusher_exit() -> bool:
	return await _wait_for_game_exit()


func _wait_for_game_exit() -> bool:
	for _frame_index in range(COIN_PUSHER_EXIT_WAIT_FRAMES):
		if not bool(app.get("game_exit_settle_active")):
			return true
		await get_tree().process_frame
	return false


func _reinstall_coin_pusher_fixture(run_state: RunState, game: GameModule) -> Dictionary:
	app.back_to_environment()
	if not await _wait_for_coin_pusher_exit():
		return {}
	if not _install_coin_pusher_fixture(run_state, game):
		return {}
	if not bool(app.call("enter_game", "coin_pusher")):
		return {}
	# Capture the reinstall identity at the synchronous entry boundary. The live
	# production solver remains authoritative immediately afterward, so keep a
	# separate observation proving that the following frames were not frozen.
	var canvas := _coin_pusher_canvas()
	var fixture := _coin_pusher_fixture_identity(run_state, game)
	var boundary_state := _coin_pusher_surface_state(canvas)
	await _wait_frames(4)
	_enable_coin_pusher_stage_diagnostic()
	var observed_state := _coin_pusher_surface_state(canvas)
	var conservation := _coin_pusher_conservation_snapshot(run_state, game)
	return {
		"fixture": fixture,
		"observation": {
			"boundary_body_count": int(boundary_state.get("coin_pusher_body_count", -1)),
			"boundary_tray_count": int(boundary_state.get("coin_pusher_tray_count", -1)),
			"observed_body_count": int(observed_state.get("coin_pusher_body_count", -1)),
			"observed_tray_count": int(observed_state.get("coin_pusher_tray_count", -1)),
			"liveness_before": int(boundary_state.get("coin_pusher_liveness_ticks", 0)),
			"liveness_after": int(observed_state.get("coin_pusher_liveness_ticks", 0)),
			"conservation": conservation,
		},
	}


func _enable_coin_pusher_stage_diagnostic() -> void:
	if not _option_bool(runtime_options, "bth_perf_coin_pusher_stage_diagnostic", false):
		return
	var ui_state_value: Variant = app.get("game_surface_ui_state")
	if typeof(ui_state_value) == TYPE_DICTIONARY:
		var ui_state: Dictionary = (ui_state_value as Dictionary).duplicate(true)
		ui_state["coin_pusher_debug_profile_stages"] = true
		app.set("game_surface_ui_state", ui_state)
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("apply_surface_state_patch"):
		canvas.call("apply_surface_state_patch", {"coin_pusher_perf_stage_capture": true})


func _coin_pusher_machine_definition(game: GameModule) -> Dictionary:
	var value: Variant = game.call("_machine_definition")
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


# This intentionally mirrors foundation_performance_probe's maintained native
# shipped-cap Quarter Falls fixture: same seed namespace, fork, production solver
# API, durable snapshot and real cabinet entry path.
func _install_coin_pusher_fixture(run_state: RunState, game: GameModule) -> bool:
	if not _install_coin_pusher_fixture_at_body_count(run_state, game, COIN_PUSHER_SHIPPED_BODY_COUNT):
		return false
	return int(game.call("_coin_cap")) == COIN_PUSHER_SHIPPED_BODY_COUNT


func _install_coin_pusher_fixture_at_body_count(run_state: RunState, game: GameModule, body_count: int) -> bool:
	var machine_definition := _coin_pusher_machine_definition(game)
	var fixture_rng := run_state.create_rng("performance_coin_pusher_full_cap").fork("bodies:%d" % body_count)
	var simulation := CoinPusherSolverScript.create_machine(fixture_rng, machine_definition, body_count)
	var machine := game.call("_ensure_machine_state", run_state, run_state.current_environment, true) as Dictionary
	machine["variation_id"] = "quarter_falls"
	machine["variation_state"] = {}
	machine["simulation"] = simulation
	machine["riders"] = []
	machine["locked_down"] = false
	machine["staff_watch_memory"] = false
	machine["alarm_tolerance_remaining"] = 100
	machine["tell_rung"] = 0
	game.call("_sync_physical_features", machine)
	machine["settled_state"] = CoinPusherLiveSessionScript.make_snapshot(simulation, machine)
	machine.erase("simulation")
	machine.erase("live_session")
	game.call("_write_machine_state", run_state.current_environment, machine)
	app.call("_refresh")
	return CoinPusherSolverScript.coin_count(simulation) == body_count \
		and int(machine_definition.get("ceiling", 0)) >= body_count \
		and int(simulation.get("fixed_hz", 0)) == CoinPusherSolverScript.FIXED_HZ


func _coin_pusher_fixture_identity(run_state: RunState, game: GameModule) -> Dictionary:
	var canvas := app.get("game_surface_canvas") as Control
	var state: Dictionary = canvas.call("realtime_surface_state") if canvas != null and canvas.has_method("realtime_surface_state") else {}
	var definition := _coin_pusher_machine_definition(game)
	return {
		"fixture_seed": COIN_PUSHER_FIXTURE_SEED,
		"rng_namespace": "performance_coin_pusher_full_cap",
		"rng_fork": "bodies:%d" % COIN_PUSHER_SHIPPED_BODY_COUNT,
		"fixture_api": "CoinPusherSolverScript.create_machine",
		"snapshot_api": "CoinPusherLiveSessionScript.make_snapshot",
		"variation_id": "quarter_falls",
		"cabinet_scope": "Quarter Falls shared V3 cabinet/render/live-session path",
		"body_count": int(state.get("coin_pusher_body_count", -1)),
		"shipped_body_cap": int(game.call("_coin_cap")),
		"machine_ceiling": int(definition.get("ceiling", 0)),
		"solver_fixed_hz": 60,
		"solver_backend": CoinPusherSolverScript.last_step_backend_for_test(),
		"platform": _platform_label(),
		"source_commit": str(runtime_options.get("bth_perf_source_commit", "")),
		"export_sha256": str(runtime_options.get("bth_perf_export_sha256", "")),
		"environment_id": str(run_state.current_environment.get("id", "")),
	}


func _coin_pusher_conservation_snapshot(run_state: RunState, game: GameModule) -> Dictionary:
	var machine := game.call("_ensure_live_machine", run_state, run_state.current_environment) as Dictionary
	var simulation_value: Variant = game.call("_simulation", machine)
	if typeof(simulation_value) != TYPE_DICTIONARY:
		return {}
	var simulation: Dictionary = simulation_value
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var invariants: Dictionary = simulation.get("last_invariants", {}) if typeof(simulation.get("last_invariants", {})) == TYPE_DICTIONARY else {}
	var active := int(invariants.get("active", -1)) if bool(session.get("native_body_state_dirty", false)) else ((simulation.get("bodies", []) as Array).size() if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else -1)
	var tray := (simulation.get("tray_ledger", []) as Array).size() if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else -1
	var gutter := (simulation.get("gutter_ledger", []) as Array).size() if typeof(simulation.get("gutter_ledger", [])) == TYPE_ARRAY else -1
	var collected := int(simulation.get("collected_count", -1))
	var cup_consumed := int(simulation.get("cup_consumed_count", -1))
	var origin := int(simulation.get("opening_body_count", -1)) \
		+ int(simulation.get("accepted_inserts", 0)) \
		+ int(simulation.get("external_origin_count", 0))
	var accounted := active + tray + gutter + collected + cup_consumed
	var solver_invariants_present := invariants.has("conservation_ok")
	return {
		"active": active,
		"tray": tray,
		"gutter": gutter,
		"collected": collected,
		"cup_consumed": cup_consumed,
		"origin": origin,
		"accounted": accounted,
		"conservation_ok": accounted == origin,
		"solver_invariants_present": solver_invariants_present,
		"solver_conservation_ok": bool(invariants.get("conservation_ok", false)),
	}


func _seed_coin_pusher_collect_fixture(run_state: RunState, game: GameModule) -> bool:
	# Once the cabinet is entered, the transient live machine is authoritative;
	# the durable row deliberately no longer carries a simulation dictionary.
	var machine := game.call("_ensure_live_machine", run_state, run_state.current_environment) as Dictionary
	CoinPusherLiveSessionScript.sync_native_body_state(machine)
	var simulation_value: Variant = game.call("_simulation", machine)
	if typeof(simulation_value) != TYPE_DICTIONARY:
		return false
	var simulation: Dictionary = simulation_value
	var bodies: Array = simulation.get("bodies", []) if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else []
	var tray: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	if bodies.is_empty() or not tray.is_empty():
		return false
	# Preserve the shipped-origin conservation law: move one deterministic fixture
	# coin into the tray instead of fabricating an extra outcome.
	var seeded_body: Dictionary = bodies.pop_back() as Dictionary
	tray.append({
		"body_id": str(seeded_body.get("id", "web_perf_collect_seed")),
		"kind": "coin",
		"value": 3,
		"item_id": "",
		"provenance": {},
	})
	simulation["bodies"] = bodies
	simulation["tray_ledger"] = tray
	# Refresh from that same live authority so the sampled before-state observes
	# the seeded tray rather than a stale durable projection.
	app.call("_refresh")
	mark_event("coin_pusher_collect_seed", {
		"body_id": str(seeded_body.get("id", "")),
		"origin_body_count": bodies.size() + tray.size(),
		"tray_count": tray.size(),
		"tray_value": 3,
		"active_body_count": bodies.size(),
		"conserved_body_count": bodies.size() + tray.size(),
	})
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	session["native_cache_reset"] = true
	session["native_body_state_dirty"] = false
	return bodies.size() == COIN_PUSHER_SHIPPED_BODY_COUNT - 1 and tray.size() == 1


func _coin_pusher_canvas() -> Control:
	return app.get("game_surface_canvas") as Control if app != null else null


func _coin_pusher_canvas_counters(canvas: Control) -> Dictionary:
	if canvas != null and canvas.has_method("performance_counters"):
		var counters := (canvas.call("performance_counters") as Dictionary).duplicate(true)
		var samples: Array = counters.get("draw_frame_usec_samples", []) if typeof(counters.get("draw_frame_usec_samples", [])) == TYPE_ARRAY else []
		counters["draw_sample_count"] = int(counters.get("draw_sample_count", samples.size()))
		return counters
	return {}


func _coin_pusher_surface_state(canvas: Control) -> Dictionary:
	if canvas != null and canvas.has_method("realtime_surface_state"):
		# Performance evidence only reads boundary scalars plus the existing action
		# binding dictionary. Deep-copying the shipped-cap presentation arrays here
		# made the observer allocate several complete machines inside an active
		# action window, then charged the resulting browser GC pauses to gameplay.
		# A shallow boundary copy keeps the scalar observations stable without
		# cloning presentation data that the report never consumes.
		return (canvas.call("realtime_surface_state") as Dictionary).duplicate(false)
	return {}


func _measure_coin_pusher_goal_ritual(fixture: Dictionary) -> void:
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before := _coin_pusher_surface_state(canvas)
	var goal_before: Dictionary = before.get("coin_pusher_goal", {}) if typeof(before.get("coin_pusher_goal", {})) == TYPE_DICTIONARY else {}
	_begin_scenario("coin_pusher_machine_goal_ritual", {
		"surface": "coin_pusher",
		"mode": "machine_goal",
		"perf06_surface_id": "coin_pusher",
		"perf06_phase_id": "ritual",
		"fixture": fixture.duplicate(true),
	})
	await _wait_frames(maxi(scenario_frames, 30))
	var after := _coin_pusher_surface_state(canvas)
	var goal_after: Dictionary = after.get("coin_pusher_goal", {}) if typeof(after.get("coin_pusher_goal", {})) == TYPE_DICTIONARY else {}
	var observed := not str(goal_after.get("id", "")).is_empty() \
		and not str(goal_after.get("title", "")).is_empty() \
		and not str(goal_after.get("instruction", "")).is_empty() \
		and int(goal_after.get("target", 0)) > 0 \
		and int(goal_after.get("bonus_tokens", 0)) > 0
	current_tags["phase_evidence"] = {
		"observed": observed,
		"goal_before": goal_before.duplicate(true),
		"goal_after": goal_after.duplicate(true),
	}
	current_tags["solver_backend"] = CoinPusherSolverScript.last_step_backend_for_test()
	_end_scenario()


func _measure_coin_pusher_raw_solver(run_state: RunState, game: GameModule) -> void:
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var opening_rng := run_state.create_rng("performance_coin_pusher_raw_solver").fork("opening")
	var machine_definition := _coin_pusher_machine_definition(game)
	var machine_ceiling := int(machine_definition.get("ceiling", 0))
	var state := CoinPusherSolverScript.create_machine(opening_rng, machine_definition, COIN_PUSHER_SOLVER_STRESS_BODY_COUNT)
	var initial_body_count := CoinPusherSolverScript.coin_count(state)
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	for body_index in range(mini(80, bodies.size())):
		var body: Dictionary = bodies[body_index]
		body["sleeping"] = false
		body["sleep_ticks"] = 0
		body["vx"] = opening_rng.randi_range(-1600, 1600)
		body["vy"] = opening_rng.randi_range(-1800, 900)
	_begin_scenario("coin_pusher_raw_solver_300", {
		"surface": "coin_pusher",
		"mode": "coin_pusher_solver_tick_300_body_stress",
		"perf06_surface_id": "coin_pusher",
		"perf06_phase_id": "raw_solver",
	})
	var samples: Array = []
	var fixed_tick_samples := 0
	var capped_samples := 0
	for _sample_index in range(COIN_PUSHER_SOLVER_SAMPLE_COUNT):
		var start_usec := Time.get_ticks_usec()
		var step := CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 1)
		samples.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)
		var metrics: Dictionary = step.get("metrics", {}) if typeof(step.get("metrics", {})) == TYPE_DICTIONARY else {}
		if int(metrics.get("fixed_ticks", 0)) == 1:
			fixed_tick_samples += 1
		if int(metrics.get("body_count", machine_ceiling + 1)) <= machine_ceiling:
			capped_samples += 1
		await get_tree().process_frame
	var stats := _float_stats(samples)
	var backend := CoinPusherSolverScript.last_step_backend_for_test()
	var observed := samples.size() == COIN_PUSHER_SOLVER_SAMPLE_COUNT \
		and fixed_tick_samples == samples.size() \
		and capped_samples == samples.size() \
		and backend == "native_v3" \
		and int(state.get("fixed_hz", 0)) == CoinPusherSolverScript.FIXED_HZ \
		and initial_body_count == COIN_PUSHER_SOLVER_STRESS_BODY_COUNT \
		and float(stats.get("p95", 0.0)) <= COIN_PUSHER_SOLVER_TICK_P95_BUDGET_MS
	current_tags["raw_solver_timing"] = stats
	current_tags["raw_solver_initial_body_count"] = initial_body_count
	current_tags["raw_solver_final_body_count"] = CoinPusherSolverScript.coin_count(state)
	current_tags["raw_solver_fixed_tick_samples"] = fixed_tick_samples
	current_tags["raw_solver_capped_samples"] = capped_samples
	current_tags["raw_solver_machine_ceiling"] = machine_ceiling
	current_tags["raw_solver_p95_budget_ms"] = COIN_PUSHER_SOLVER_TICK_P95_BUDGET_MS
	current_tags["solver_backend"] = backend
	current_tags["phase_evidence"] = {"observed": observed, "sample_count": samples.size(), "solver_backend": backend}
	_end_scenario()


func _measure_coin_pusher_ceiling_refusal(run_state: RunState, game: GameModule) -> void:
	app.back_to_environment()
	if not await _wait_for_coin_pusher_exit():
		mark_event("coin_pusher_ceiling_fixture_failed", {"reason": "exit_timeout"})
		return
	var ceiling := int(_coin_pusher_machine_definition(game).get("ceiling", 0))
	if ceiling <= 0 or not _install_coin_pusher_fixture_at_body_count(run_state, game, ceiling):
		mark_event("coin_pusher_ceiling_fixture_failed", {"reason": "fixture", "ceiling": ceiling})
		return
	if not bool(app.call("enter_game", "coin_pusher")):
		mark_event("coin_pusher_ceiling_fixture_failed", {"reason": "enter", "ceiling": ceiling})
		return
	await _wait_frames(4)
	_enable_coin_pusher_stage_diagnostic()
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before := _coin_pusher_surface_state(canvas)
	var bankroll_before := run_state.bankroll
	var turns_before := int(run_state.current_environment.get("turns", 0))
	var story_before := run_state.story_log_entry_count()
	var fallback_before := int(app.get("embedded_full_snapshot_fallback_count"))
	_begin_scenario("coin_pusher_authored_ceiling_refusal", {
		"surface": "coin_pusher",
		"mode": "authored_ceiling_refusal",
		"perf06_surface_id": "coin_pusher",
		"perf06_phase_id": "ceiling_refusal",
	})
	var handled := bool(app.call("_handle_module_surface_action", "coin_pusher_drop", 0, true))
	await _wait_frames(maxi(scenario_frames, 30))
	var after := _coin_pusher_surface_state(canvas)
	var result: Dictionary = app.get("last_game_result") if typeof(app.get("last_game_result")) == TYPE_DICTIONARY else {}
	var observed := handled \
		and int(before.get("coin_pusher_body_count", -1)) == ceiling \
		and int(after.get("coin_pusher_body_count", -2)) == ceiling \
		and int(after.get("coin_pusher_input_trace_count", -1)) == int(before.get("coin_pusher_input_trace_count", -2)) \
		and run_state.bankroll == bankroll_before \
		and int(run_state.current_environment.get("turns", 0)) == turns_before \
		and run_state.story_log_entry_count() == story_before \
		and int(app.get("embedded_full_snapshot_fallback_count")) == fallback_before \
		and _coin_pusher_free_controls_present(after)
	current_tags["phase_evidence"] = {
		"observed": observed,
		"handled": handled,
		"reason": str(result.get("reason", result.get("message", ""))),
		"ceiling": ceiling,
		"body_count_before": int(before.get("coin_pusher_body_count", -1)),
		"body_count_after": int(after.get("coin_pusher_body_count", -1)),
		"input_trace_before": int(before.get("coin_pusher_input_trace_count", -1)),
		"input_trace_after": int(after.get("coin_pusher_input_trace_count", -1)),
	}
	current_tags["solver_backend"] = CoinPusherSolverScript.last_step_backend_for_test()
	_end_scenario()


func _measure_coin_pusher_idle(name: String, reduced_motion: bool, fixture: Dictionary) -> void:
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before_state := _coin_pusher_surface_state(canvas)
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	var conservation_before := _coin_pusher_conservation_snapshot(run_state, game) if run_state != null and game != null else {}
	var before_counters := _coin_pusher_canvas_counters(canvas)
	_begin_scenario(name, {
		"surface": "coin_pusher",
		"mode": "reduced_motion" if reduced_motion else "settled_idle",
		"perf06_surface_id": "coin_pusher",
		"perf06_phase_id": "" if reduced_motion else "cap_idle",
		"fixture": fixture.duplicate(true),
	})
	await _wait_frames(maxi(scenario_frames, COIN_PUSHER_IDLE_SAMPLE_FRAMES))
	var after_state := _coin_pusher_surface_state(canvas)
	var conservation_after := _coin_pusher_conservation_snapshot(run_state, game) if run_state != null and game != null else {}
	var after_counters := _coin_pusher_canvas_counters(canvas)
	current_tags["canvas_before"] = before_counters
	current_tags["canvas_after"] = after_counters
	current_tags["redraw_delta"] = int(after_counters.get("surface_animation_redraw_count", 0)) - int(before_counters.get("surface_animation_redraw_count", 0))
	current_tags["solver_liveness_before"] = int(before_state.get("coin_pusher_liveness_ticks", 0))
	current_tags["solver_liveness_after"] = int(after_state.get("coin_pusher_liveness_ticks", 0))
	current_tags["solver_liveness_delta"] = int(after_state.get("coin_pusher_liveness_ticks", 0)) - int(before_state.get("coin_pusher_liveness_ticks", 0))
	current_tags["body_count_before"] = int(before_state.get("coin_pusher_body_count", -1))
	current_tags["body_count_after"] = int(after_state.get("coin_pusher_body_count", -1))
	current_tags["tray_count_before"] = int(before_state.get("coin_pusher_tray_count", -1))
	current_tags["tray_count_after"] = int(after_state.get("coin_pusher_tray_count", -1))
	current_tags["conservation_before"] = conservation_before
	current_tags["conservation_after"] = conservation_after
	current_tags["solver_backend"] = CoinPusherSolverScript.last_step_backend_for_test()
	_end_scenario()


func _measure_coin_pusher_action(surface_action: String, name: String, fixture: Dictionary) -> void:
	var canvas := _coin_pusher_canvas()
	if canvas != null and canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before_state := _coin_pusher_surface_state(canvas)
	var before_counters := _coin_pusher_canvas_counters(canvas)
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	var bankroll_before := run_state.bankroll if run_state != null else 0
	var turns_before := int(run_state.current_environment.get("turns", 0)) if run_state != null else 0
	var story_before := run_state.story_log_entry_count() if run_state != null else 0
	var fallback_before := int(app.get("embedded_full_snapshot_fallback_count"))
	_begin_scenario(name, {
		"surface": "coin_pusher",
		"mode": "active",
		"surface_action": surface_action,
		"perf06_surface_id": "coin_pusher",
		"perf06_phase_id": _coin_pusher_perf06_phase(name),
		"fixture": fixture.duplicate(true),
	})
	var call_start_usec := Time.get_ticks_usec()
	var handled := bool(app.call("_handle_module_surface_action", surface_action, 0, true))
	var resolve_call_ms := float(Time.get_ticks_usec() - call_start_usec) / 1000.0
	var accepted_result: Dictionary = app.get("last_game_result") if typeof(app.get("last_game_result")) == TYPE_DICTIONARY else {}
	var accepted_host_timing_variant: Variant = accepted_result.get("coin_pusher_debug_host_timing_usec", {})
	var host_timing: Dictionary = accepted_host_timing_variant if typeof(accepted_host_timing_variant) == TYPE_DICTIONARY else {}
	# Action acceptance and the maintained 60-frame physical observation are
	# distinct boundaries. Retain both so later legitimate exits cannot overwrite
	# proof of what the accepted action itself did.
	var accepted_state := _coin_pusher_surface_state(canvas)
	var accepted_conservation := _coin_pusher_conservation_snapshot(run_state, game) if run_state != null else {}
	await _wait_frames(maxi(active_frames, COIN_PUSHER_ACTION_SAMPLE_FRAMES))
	var after_state := _coin_pusher_surface_state(canvas)
	var after_conservation := _coin_pusher_conservation_snapshot(run_state, game) if run_state != null else {}
	var after_counters := _coin_pusher_canvas_counters(canvas)
	var result: Dictionary = app.get("last_game_result") if typeof(app.get("last_game_result")) == TYPE_DICTIONARY else {}
	var metrics: Dictionary = result.get("coin_pusher_solver_metrics", {}) if typeof(result.get("coin_pusher_solver_metrics", {})) == TYPE_DICTIONARY else {}
	current_tags["handled"] = handled
	current_tags["resolve_call_ms"] = resolve_call_ms
	if not host_timing.is_empty():
		current_tags["host_timing_usec"] = host_timing.duplicate(true)
	current_tags["canvas_before"] = before_counters
	current_tags["canvas_after"] = after_counters
	current_tags["redraw_delta"] = int(after_counters.get("surface_animation_redraw_count", 0)) - int(before_counters.get("surface_animation_redraw_count", 0))
	current_tags["input_trace_before"] = int(before_state.get("coin_pusher_input_trace_count", 0))
	current_tags["input_trace_after"] = int(after_state.get("coin_pusher_input_trace_count", 0))
	current_tags["solver_liveness_before"] = int(before_state.get("coin_pusher_liveness_ticks", 0))
	current_tags["solver_liveness_after"] = int(after_state.get("coin_pusher_liveness_ticks", 0))
	current_tags["body_count_before"] = int(before_state.get("coin_pusher_body_count", -1))
	current_tags["body_count_after"] = int(after_state.get("coin_pusher_body_count", -1))
	current_tags["carriage_x_before"] = int(before_state.get("coin_pusher_carriage_x", -1))
	current_tags["carriage_x_after"] = int(after_state.get("coin_pusher_carriage_x", -1))
	current_tags["selected_hole_before"] = int(before_state.get("coin_pusher_selected_hole", -1))
	current_tags["selected_hole_after"] = int(after_state.get("coin_pusher_selected_hole", -1))
	current_tags["skill_stop_before"] = bool(before_state.get("coin_pusher_skill_stop_engaged", false))
	current_tags["skill_stop_after"] = bool(after_state.get("coin_pusher_skill_stop_engaged", false))
	current_tags["tray_count_before"] = int(before_state.get("coin_pusher_tray_count", -1))
	current_tags["tray_count_after"] = int(after_state.get("coin_pusher_tray_count", -1))
	current_tags["tray_value_before"] = int(before_state.get("coin_pusher_tray_value", -1))
	current_tags["tray_value_after"] = int(after_state.get("coin_pusher_tray_value", -1))
	current_tags["body_count_at_accept"] = int(accepted_state.get("coin_pusher_body_count", -1))
	current_tags["tray_count_at_accept"] = int(accepted_state.get("coin_pusher_tray_count", -1))
	current_tags["tray_value_at_accept"] = int(accepted_state.get("coin_pusher_tray_value", -1))
	current_tags["conservation_at_accept"] = accepted_conservation
	current_tags["conservation_after"] = after_conservation
	current_tags["bankroll_before"] = bankroll_before
	current_tags["bankroll_after"] = run_state.bankroll if run_state != null else 0
	current_tags["environment_turns_before"] = turns_before
	current_tags["environment_turns_after"] = int(run_state.current_environment.get("turns", 0)) if run_state != null else 0
	current_tags["story_entries_before"] = story_before
	current_tags["story_entries_after"] = run_state.story_log_entry_count() if run_state != null else 0
	current_tags["host_full_snapshot_fallbacks"] = int(app.get("embedded_full_snapshot_fallback_count")) - fallback_before
	current_tags["full_snapshot_calls"] = int(after_counters.get("full_snapshot_calls", 0))
	current_tags["physical_motion_seen"] = int(after_state.get("coin_pusher_liveness_ticks", 0)) > int(before_state.get("coin_pusher_liveness_ticks", 0)) \
		or int(after_state.get("coin_pusher_phase_fp", 0)) != int(before_state.get("coin_pusher_phase_fp", 0)) \
		or int(metrics.get("awake_count", 0)) > 0 or int(metrics.get("collision_count", 0)) > 0
	current_tags["solver_backend"] = CoinPusherSolverScript.last_step_backend_for_test()
	current_tags["surface_ui_preserved"] = _coin_pusher_free_controls_present(after_state)
	current_tags["bankroll_delta"] = int(result.get("bankroll_delta", 0))
	current_tags["action_patch_present"] = typeof(result.get("surface_action_view_patch", {})) == TYPE_DICTIONARY and not (result.get("surface_action_view_patch", {}) as Dictionary).is_empty()
	_end_scenario()


func _coin_pusher_free_controls_present(surface_state: Dictionary) -> bool:
	var bindings: Dictionary = surface_state.get("surface_action_bindings", {}) if typeof(surface_state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	return bindings.has("coin_pusher_carriage_left") and bindings.has("coin_pusher_carriage_right") \
		and bindings.has("coin_pusher_skill_stop") and bindings.has("coin_pusher_collect")


func _set_coin_pusher_reduce_motion(enabled: bool) -> void:
	var settings: Variant = app.get("user_settings") if app != null else null
	if settings != null:
		settings.set("reduce_motion", enabled)
	app.call("_refresh")
	await _wait_frames(4)


func _measure_corner_store() -> void:
	var total_started_usec := Time.get_ticks_usec()
	var stage_started_usec := total_started_usec
	_begin_system_phase("run_trajectory_start", "run_trajectory", "start", "transition")
	app.start_foundation_run("WEB-CORNER-STORE")
	var start_snapshot: Dictionary = app.call("current_screen_snapshot")
	_complete_system_evidence(
		bool(start_snapshot.get("has_run", false)) and str(start_snapshot.get("screen", "")) == "ENVIRONMENT",
		{"seed": "WEB-CORNER-STORE", "screen": str(start_snapshot.get("screen", ""))}
	)
	var foundation_run_start_ms := _duration_ms_since(stage_started_usec)
	stage_started_usec = Time.get_ticks_usec()
	await _finish_system_phase(mini(scenario_frames, 90))
	await _measure_system_state(
		"run_trajectory_post_warmup", "run_trajectory", "post_warmup",
		bool(start_snapshot.get("has_run", false)), {"seed": "WEB-CORNER-STORE"}, mini(scenario_frames, 90), "idle"
	)
	var post_start_settle_ms := _duration_ms_since(stage_started_usec)
	var run_state: RunState = app.get("run_state") as RunState
	stage_started_usec = Time.get_ticks_usec()
	var choice: Dictionary = app.call("_travel_choice", "corner_store")
	if choice.is_empty() or not bool(choice.get("enabled", true)):
		choice = {
			"id": "corner_store",
			"label": "Corner Store",
			"enabled": true,
			"route": app.call("_world_route_for_target", "corner_store"),
		}
	var choice_build_ms := _duration_ms_since(stage_started_usec)
	var started_usec := Time.get_ticks_usec()
	_emit_console("BTH_CORNER_STORE_OPEN_START ", {
		"from": run_state.current_world_node_id() if run_state != null else "",
		"target": "corner_store",
	})
	_begin_system_phase("room_environment_transition", "room_environment", "transition", "transition")
	var travel_result: Variant = app.call("_travel_to", "corner_store", "Corner Store", choice)
	var travel_ok := typeof(travel_result) == TYPE_DICTIONARY and bool((travel_result as Dictionary).get("ok", false))
	_complete_system_evidence(travel_ok and str(run_state.current_environment.get("archetype_id", "")) == "corner_store", {
		"accepted": travel_ok,
		"target": "corner_store",
		"environment_id": str(run_state.current_environment.get("archetype_id", "")),
	})
	var duration_ms := _duration_ms_since(started_usec)
	_emit_console("BTH_CORNER_STORE_OPEN_DONE ", {
		"duration_ms": duration_ms,
		"environment_id": str(run_state.current_environment.get("archetype_id", "")) if run_state != null else "",
	})
	mark_event("corner_store_open", {"duration_ms": duration_ms})
	mark_event("corner_store_startup_timing", {
		"foundation_run_start_ms": foundation_run_start_ms,
		"post_start_settle_ms": post_start_settle_ms,
		"choice_build_ms": choice_build_ms,
		"travel_ms": duration_ms,
		"total_ms": _duration_ms_since(total_started_usec),
	})
	await _finish_system_phase(mini(scenario_frames, 90))
	await _measure_scenario("corner_store_idle", {"surface": "environment", "mode": "idle", "perf06_surface_id": "room_environment", "perf06_phase_id": "quiet_idle"}, scenario_frames)
	await _measure_system_state(
		"audio_quiet_idle", "audio", "quiet_idle", travel_ok,
		{"environment_id": str(run_state.current_environment.get("archetype_id", "")), "cue_request_count": 0},
		mini(scenario_frames, 90), "idle"
	)


func _run_lb3_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("lb3_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	mark_event("lb3_boot_snapshot", _boot_timeline_snapshot())
	var run_started_usec := Time.get_ticks_usec()
	app.start_foundation_run("LB3-FIRST-RUN")
	mark_event("lb3_first_run_start", {
		"duration_ms": _duration_ms_since(run_started_usec),
		"screen": str(app.get("current_screen")),
	})
	await _wait_frames(8)
	var first_surface_started_usec := Time.get_ticks_usec()
	app.enter_first_available_game()
	mark_event("lb3_first_surface_open", {
		"duration_ms": _duration_ms_since(first_surface_started_usec),
		"screen": str(app.get("current_screen")),
	})
	await _measure_scenario("lb3_first_surface_interactive", {"surface": "first_available", "mode": "first_open"}, mini(scenario_frames, 90))
	app.back_to_environment()
	await _wait_frames(8)
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		await _measure_lb3_game_open(game_id, true)
		await _measure_lb3_game_open(game_id, false)
	await _measure_lb3_save_stall()
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _measure_lb3_game_open(game_id: String, first_open: bool) -> void:
	var mode := "first_open" if first_open else "steady_open"
	var opened_started_usec := Time.get_ticks_usec()
	app.start_game_test_session(game_id)
	mark_event("lb3_game_%s" % mode, {
		"game_id": game_id,
		"duration_ms": _duration_ms_since(opened_started_usec),
		"screen": str(app.get("current_screen")),
	})
	await _measure_scenario("lb3_%s_%s" % [game_id, mode], {"surface": game_id, "mode": mode}, mini(scenario_frames, 90))
	app.back_to_environment()
	await _wait_frames(8)


func _measure_lb3_save_stall() -> void:
	app.start_foundation_run("LB3-SAVE-STALL")
	await _wait_frames(8)
	var refresh_started_usec := Time.get_ticks_usec()
	app.call("_refresh")
	mark_event("lb3_action_refresh", {
		"duration_ms": _duration_ms_since(refresh_started_usec),
	})
	_measure_lb3_refresh_phases("fresh")
	var autosave_started_usec := Time.get_ticks_usec()
	var autosave_accepted := bool(app.call("_autosave_foundation_run", "LB3 Autosave.", false))
	mark_event("lb3_autosave_request", {
		"duration_ms": _duration_ms_since(autosave_started_usec),
		"accepted": autosave_accepted,
		"pending": bool(app.get("pending_autosave")),
	})
	await _wait_frames(4)
	mark_event("lb3_autosave_after_flush", {
		"pending": bool(app.get("pending_autosave")),
	})
	var save_service: SaveService = app.get("save_service") as SaveService
	var run_state: RunState = app.get("run_state") as RunState
	if save_service == null or run_state == null:
		mark_event("lb3_save_unavailable")
		return
	var save_started_usec := Time.get_ticks_usec()
	var save_error := save_service.save_run(run_state, "lb3_direct_save_probe")
	mark_event("lb3_save_run_direct", {
		"duration_ms": _duration_ms_since(save_started_usec),
		"error": int(save_error),
	})
	_fill_lb3_late_run_save_fixture(run_state)
	var late_refresh_started_usec := Time.get_ticks_usec()
	app.call("_refresh")
	mark_event("lb3_late_run_action_refresh", {
		"duration_ms": _duration_ms_since(late_refresh_started_usec),
		"story_entries": run_state.story_log.size(),
		"environment_history_entries": run_state.environment_history.size(),
	})
	var late_request_started_usec := Time.get_ticks_usec()
	var late_request_accepted := bool(app.call("_autosave_foundation_run", "LB3 late-run autosave.", false))
	mark_event("lb3_late_run_autosave_request", {
		"duration_ms": _duration_ms_since(late_request_started_usec),
		"accepted": late_request_accepted,
		"pending": bool(app.get("pending_autosave")),
	})
	await _wait_frames(4)
	var late_save_started_usec := Time.get_ticks_usec()
	var late_save_error := save_service.save_run(run_state, "lb3_late_run_save_probe")
	mark_event("lb3_late_run_save_direct", {
		"duration_ms": _duration_ms_since(late_save_started_usec),
		"error": int(late_save_error),
		"story_entries": run_state.story_log.size(),
		"environment_history_entries": run_state.environment_history.size(),
	})


func _fill_lb3_late_run_save_fixture(run_state: RunState) -> void:
	for index in range(RunState.MAX_STORY_LOG_ENTRIES):
		run_state.log_story({
			"type": "game_result",
			"game_id": REQUIRED_GAME_IDS[index % REQUIRED_GAME_IDS.size()],
			"message": "Representative late-run action result with enough player-facing context to exercise persistence.",
			"bankroll_delta": (index % 17) - 8,
			"suspicion_delta": index % 4,
		})
	for index in range(RunState.MAX_ENVIRONMENT_HISTORY_ENTRIES):
		run_state.environment_history.append({
			"id": "late_run_stop_%d" % index,
			"archetype_id": "small_underground_casino",
			"world_node_id": "late_run_node_%d" % index,
			"display_name": "Late Run Stop %d" % index,
			"kind": "casino",
		})


func _measure_lb3_refresh_phases(mode: String) -> void:
	for method in [
		"_evaluate_run_terminal_state",
		"_run_status_hud_model",
		"_refresh_world_header",
		"_style_hud_for_recent_consequence",
		"_apply_hud_mode_visibility",
		"_refresh_active_item_slot",
		"_apply_focus_layout",
		"_refresh_environment_result_feedback",
		"_render_victory_summary",
		"_render_failure_summary",
		"_render_result_panel",
		"_render_foundation_snapshots",
		"_refresh_talk_dock",
		"_render_action_panel",
		"_refresh_world_map_overlay",
		"_update_procedural_music",
		"_refresh_run_menu",
	]:
		var started_usec := Time.get_ticks_usec()
		app.call(method)
		mark_event("lb3_refresh_phase", {
			"mode": mode,
			"method": method,
			"duration_ms": _duration_ms_since(started_usec),
		})


func _run_la1_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("la1_missing_app")
		dump_report()
		await _quit_after_report_flush()
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
	await _quit_after_report_flush()


func _run_la5_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("la5_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	app.start_foundation_run("LA5-DRUNK-ENV")
	await _wait_frames(20)
	_force_drunk_distortion_level(72)
	await _wait_frames(8)
	await _measure_scenario("la5_environment_drunk_distortion", {"surface": "environment", "mode": "drunk_distortion"}, scenario_frames)
	app.start_game_test_session("slot")
	await _wait_frames(12)
	_force_drunk_distortion_level(72)
	await _wait_frames(8)
	await _measure_scenario("la5_game_drunk_distortion", {"surface": "slot", "mode": "drunk_distortion"}, scenario_frames)
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _run_la6_plan() -> void:
	if l02_driver_started:
		return
	l02_driver_started = true
	await _wait_frames(8)
	_end_scenario()
	if app == null:
		mark_event("la6_missing_app")
		dump_report()
		await _quit_after_report_flush()
		return
	WebAudioBridgeScript.reset_debug_stats()
	app.start_foundation_run("LA6-WEB-AUDIO")
	await _wait_frames(20)
	var music_player: ProceduralMusicPlayer = app.get("procedural_music_player") as ProceduralMusicPlayer
	if music_player != null:
		music_player.web_audio_user_gesture()
		var run_state: RunState = app.get("run_state") as RunState
		if run_state != null:
			music_player.refresh_after_web_audio_unlock(run_state.current_environment, run_state.suspicion_level(), app.music_fx_state_snapshot())
	await _wait_frames(8)
	for index in range(24):
		var cue_id := "roulette_chip_place" if index % 3 == 0 else "blackjack_card" if index % 3 == 1 else "bonus_start_pinball"
		app.call("_play_environment_audio_cue", cue_id, -4.0)
		await _wait_frames(2)
	await _measure_scenario("la6_audio_unlocked_idle", {"surface": "environment", "mode": "audio"}, scenario_frames)
	mark_event("la6_web_audio_bridge_stats", WebAudioBridgeScript.debug_stats())
	l02_driver_complete = true
	dump_report()
	await _quit_after_report_flush()


func _force_drunk_distortion_level(level: int) -> void:
	if app == null:
		return
	var run_state: RunState = app.get("run_state") as RunState
	if run_state == null:
		return
	run_state.change_pending_drunk_absorption(-run_state.pending_drunk_absorption_amount())
	run_state.change_drunk(clampi(level, 0, RunState.ALCOHOL_MAX) - run_state.drunk_level)
	app.call("_refresh")


func _measure_game(game_id: String) -> void:
	if app == null:
		return
	if not await _wait_for_game_exit():
		mark_event("game_fixture_entry_failed", {"game_id": game_id, "reason": "prior_exit_timeout"})
		return
	var session_result := app.start_game_test_session(game_id)
	await _wait_frames(12)
	if not bool(session_result.get("ok", false)):
		mark_event("game_fixture_entry_failed", {"game_id": game_id, "errors": session_result.get("errors", [])})
		return
	if game_id == "crew_draw_poker" and not bool(PerformanceFixtureSetupScript.install_actor_present_crew_draw_poker(app).get("ok", false)):
		mark_event("crew_draw_poker_fixture_failed")
		return
	if game_id == "craps":
		var craps_run: RunState = app.get("run_state") as RunState
		if craps_run != null and craps_run.grand_casino_table_uses_chips("craps", craps_run.current_environment):
			# Retain cash so the host's normal zero-bankroll terminal guard does not
			# close the table while preparing this disposable active fixture.
			craps_run.buy_grand_casino_chips(mini(1000, maxi(100, int(craps_run.bankroll / 2))), craps_run.grand_casino_chip_exchange_rate())
			app.call("_refresh")
	var entered_game: GameModule = app.get("current_game") as GameModule
	if entered_game == null or entered_game.get_id() != game_id:
		mark_event("game_fixture_entry_failed", {"game_id": game_id, "reason": "current_game_mismatch", "actual_game_id": entered_game.get_id() if entered_game != null else ""})
		return
	await _measure_game_idle(game_id)
	_begin_scenario("%s_active" % game_id, {
		"surface": game_id,
		"mode": "active",
		"perf06_surface_id": game_id,
		"perf06_phase_id": str(PERF06_ACTIVE_PHASES.get(game_id, "active")),
	})
	current_tags["action_evidence"] = await _trigger_timed_surface_game_action(game_id) \
		if game_id in ["baccarat", "roulette"] else _trigger_active_game_action(game_id)
	if ACTIVE_PHASE_CHANNELS.has(game_id):
		current_tags["active_phase_evidence"] = await _measure_named_active_phase(
			str(ACTIVE_PHASE_CHANNELS.get(game_id, "")),
			active_frames
		)
	else:
		await _wait_frames(mini(active_frames, 30) if game_id in PERF06_TIMELINE_GAMES else active_frames)
	_end_scenario()
	await _measure_followup_game_phases(game_id)
	app.back_to_environment()
	if not await _wait_for_game_exit():
		mark_event("game_fixture_exit_failed", {"game_id": game_id, "reason": "exit_timeout"})
	await _wait_frames(2)


func _coin_pusher_perf06_phase(scenario_name: String) -> String:
	match scenario_name:
		"coin_pusher_active_drop":
			return "drop"
		"coin_pusher_active_carriage":
			return "carriage"
		"coin_pusher_active_skill_stop":
			return "skill_stop"
		"coin_pusher_active_skill_release":
			return "skill_release"
		"coin_pusher_active_collect":
			return "collect"
	return ""


func _measure_game_idle(game_id: String) -> void:
	_begin_scenario("%s_idle" % game_id, {
		"surface": game_id,
		"mode": "idle",
		"perf06_surface_id": game_id,
		"perf06_phase_id": str(PERF06_IDLE_PHASES.get(game_id, "idle")),
	})
	var start_game: Dictionary = current_start_liveness.get("game_surface", {}) if typeof(current_start_liveness.get("game_surface", {})) == TYPE_DICTIONARY else {}
	var declared_fps := maxf(0.0, float(start_game.get("surface_idle_animation_fps", 0.0)))
	var required_window_msec := ceili(float(IDLE_LIVENESS_MINIMUM_INTERVALS) * 1000.0 / declared_fps) if declared_fps > 0.0 else 0
	current_tags["idle_liveness_declared_fps"] = declared_fps
	current_tags["idle_liveness_required_intervals"] = IDLE_LIVENESS_MINIMUM_INTERVALS
	current_tags["idle_liveness_required_window_msec"] = required_window_msec
	await _wait_frames(scenario_frames)
	if required_window_msec > 0:
		var start_elapsed_msec := int(start_game.get("surface_animation_scheduler_elapsed_msec", 0))
		var deadline_msec := Time.get_ticks_msec() + required_window_msec + IDLE_LIVENESS_WAIT_GRACE_MSEC
		while Time.get_ticks_msec() < deadline_msec:
			var live := _game_surface_live_status()
			if int(live.get("surface_animation_scheduler_elapsed_msec", 0)) - start_elapsed_msec >= required_window_msec:
				break
			await get_tree().process_frame
	_end_scenario()


func _game_surface_live_status() -> Dictionary:
	if app == null:
		return {}
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.has_method("performance_live_status"):
		return {}
	return canvas.call("performance_live_status") as Dictionary


func _measure_named_active_phase(channel_id: String, frame_count: int) -> Dictionary:
	var canvas := app.get("game_surface_canvas") as Control if app != null else null
	# Headless/exported builds can advance much faster than an interactive frame.
	# Sample until both the frame and wall-clock residency gates are proven, while
	# retaining a finite bound when a production channel goes missing.
	var maximum_sample_frames := maxi(600, frame_count)
	var active_at_start := canvas != null and canvas.has_method("surface_animation_active") \
		and bool(canvas.call("surface_animation_active", channel_id))
	var active_frame_count := 0
	var sample_frames := 0
	var longest_consecutive_active_frames := 0
	var consecutive_active_frames := 0
	var active_elapsed_msec := 0.0
	var prior_usec := Time.get_ticks_usec()
	for _frame_index in range(maximum_sample_frames):
		await get_tree().process_frame
		sample_frames += 1
		var now_usec := Time.get_ticks_usec()
		var active := canvas != null and canvas.has_method("surface_animation_active") \
			and bool(canvas.call("surface_animation_active", channel_id))
		if active:
			active_frame_count += 1
			consecutive_active_frames += 1
			longest_consecutive_active_frames = maxi(longest_consecutive_active_frames, consecutive_active_frames)
			active_elapsed_msec += float(maxi(0, now_usec - prior_usec)) / 1000.0
		else:
			consecutive_active_frames = 0
		# Advance on both branches: retaining the old baseline while active would
		# triangularly overcount a sustained phase and qualify a short sample.
		prior_usec = now_usec
		if longest_consecutive_active_frames >= ACTIVE_PHASE_MINIMUM_FRAMES \
				and active_elapsed_msec >= float(ACTIVE_PHASE_MINIMUM_MSEC):
			break
	var active_at_end := canvas != null and canvas.has_method("surface_animation_active") \
		and bool(canvas.call("surface_animation_active", channel_id))
	return {
		"channel_id": channel_id,
		"active_at_start": active_at_start,
		"active_at_end": active_at_end,
		"sample_frames": sample_frames,
		"active_frame_count": active_frame_count,
		"longest_consecutive_active_frames": longest_consecutive_active_frames,
		"active_elapsed_msec": active_elapsed_msec,
		"minimum_active_frames": ACTIVE_PHASE_MINIMUM_FRAMES,
		"minimum_active_msec": ACTIVE_PHASE_MINIMUM_MSEC,
		"coverage_passed": active_at_start \
			and longest_consecutive_active_frames >= ACTIVE_PHASE_MINIMUM_FRAMES \
			and active_elapsed_msec >= float(ACTIVE_PHASE_MINIMUM_MSEC),
	}


func _measure_slot_autoplay() -> void:
	if app == null:
		return
	app.start_game_test_session("slot")
	await _wait_frames(12)
	_begin_scenario("slot_autoplay_active", {"surface": "slot", "mode": "autoplay", "perf06_surface_id": "slot", "perf06_phase_id": "autoplay"})
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
	_begin_scenario("pinball_feature_session", {"surface": "slot", "mode": "pinball_feature", "prepared": prepared, "perf06_surface_id": "slot", "perf06_phase_id": "bonus"})
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
	_begin_system_phase("world_map_open", "world", "travel_transition", "transition")
	var opened := bool(app.open_world_map())
	var opened_snapshot: Dictionary = app.call("current_screen_snapshot")
	_complete_system_evidence(opened and bool(opened_snapshot.get("world_map_overlay_visible", false)), {
		"accepted": opened,
		"world_map_visible": bool(opened_snapshot.get("world_map_overlay_visible", false)),
	})
	await _finish_system_phase(mini(scenario_frames, 90))
	await _measure_scenario("world_map_idle", {"surface": "world_map", "mode": "idle", "perf06_surface_id": "world", "perf06_phase_id": "map_idle"}, scenario_frames)
	app.close_world_map()
	await _wait_frames(8)


func _measure_scripted_memory() -> void:
	if app == null:
		return
	app.start_foundation_run("L02-MEMORY")
	await _wait_frames(20)
	_begin_scenario("scripted_play_memory_10m", {"surface": "full_run", "mode": "scripted_play", "target_seconds": memory_seconds, "perf06_surface_id": "run_trajectory", "perf06_phase_id": "mid_run"})
	var frame := 0
	var end_msec := Time.get_ticks_msec() + memory_seconds * 1000
	while Time.get_ticks_msec() < end_msec:
		if frame % 240 == 0:
			_scripted_memory_step(frame / 240)
		frame += 1
		await get_tree().process_frame
	_end_scenario()


func _begin_system_phase(name: String, surface_id: String, phase_id: String, mode: String = "active") -> void:
	_begin_scenario(name, {
		"surface": surface_id,
		"mode": mode,
		"perf06_surface_id": surface_id,
		"perf06_phase_id": phase_id,
		"phase_evidence": {"observed": false, "pending": true},
	})
	for root_value in PERF06_SYSTEM_ALLOCATION_ROOTS.get(surface_id, []):
		mark_allocation_root_audited(str(root_value))


func _complete_system_evidence(observed: bool, evidence: Dictionary = {}) -> void:
	var proof := evidence.duplicate(true)
	proof["observed"] = observed
	proof["pending"] = false
	current_tags["phase_evidence"] = proof


func _finish_system_phase(frames: int = 60) -> void:
	await _wait_frames(maxi(1, frames))
	_end_scenario()


func _measure_system_state(name: String, surface_id: String, phase_id: String, observed: bool, evidence: Dictionary = {}, frames: int = 60, mode: String = "active") -> void:
	_begin_system_phase(name, surface_id, phase_id, mode)
	_complete_system_evidence(observed, evidence)
	await _finish_system_phase(frames)


func _measure_scenario(name: String, tags: Dictionary, frames: int) -> void:
	_begin_scenario(name, tags)
	await _wait_frames(frames)
	_end_scenario()


func _begin_scenario(name: String, tags: Dictionary = {}) -> void:
	if scenario_active:
		_end_scenario()
	# Reset the production canvases before the start snapshot so draw cost and
	# liveness belong to this phase rather than an earlier fixture.
	var game_canvas := app.get("game_surface_canvas") as Control if app != null else null
	if game_canvas != null and game_canvas.has_method("reset_performance_counters"):
		game_canvas.call("reset_performance_counters")
	var environment_canvas := app.get("environment_canvas") as Control if app != null else null
	if environment_canvas != null and environment_canvas.has_method("reset_performance_counters"):
		environment_canvas.call("reset_performance_counters")
	current_scenario = name
	_emit_console("BTH_PERF_SCENARIO ", {"phase": "begin", "name": name, "ticks_msec": Time.get_ticks_msec()})
	current_tags = tags.duplicate(false)
	current_start_msec = Time.get_ticks_msec()
	current_start_memory_bytes = _current_memory_bytes()
	current_last_memory_bytes = current_start_memory_bytes
	current_start_liveness = _liveness_counter_snapshot()
	_reset_allocation_copy_counters()
	var canonical_surface_id := str(current_tags.get("perf06_surface_id", ""))
	for root_value in PERF06_SYSTEM_ALLOCATION_ROOTS.get(canonical_surface_id, []):
		mark_allocation_root_audited(str(root_value))
	frame_ms_samples = []
	process_ms_samples = []
	physics_ms_samples = []
	draw_call_samples = []
	render_object_samples = []
	primitive_samples = []
	memory_samples = []
	memory_delta_samples = []
	memory_positive_delta_samples = []
	memory_negative_delta_samples = []
	object_count_samples = []
	object_count_delta_samples = []
	object_count_positive_delta_samples = []
	object_count_negative_delta_samples = []
	node_count_samples = []
	node_count_delta_samples = []
	orphan_node_count_samples = []
	foundation_snapshot_usec_samples = []
	foundation_environment_runtime_usec_samples = []
	foundation_autosave_usec_samples = []
	foundation_layout_usec_samples = []
	foundation_coin_pusher_native_step_usec_samples = []
	foundation_surface_automation_usec_samples = []
	foundation_surface_realtime_usec_samples = []
	foundation_surface_realtime_ui_usec_samples = []
	foundation_surface_realtime_module_usec_samples = []
	foundation_surface_realtime_augment_usec_samples = []
	monitor_sample_count = 0
	last_sample_memory_bytes = current_start_memory_bytes
	last_sample_object_count = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	last_sample_node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	scenario_active = true
	_sample_monitors()


func _end_scenario() -> void:
	if not scenario_active:
		return
	_sample_monitors()
	var end_msec := Time.get_ticks_msec()
	var memory_stats := _int_stats(memory_samples)
	var end_liveness := _liveness_counter_snapshot()
	var frame_attribution_samples := {}
	if current_scenario.begins_with("coin_pusher_"):
		# Keep the per-frame rows for Coin Pusher closure captures. Aggregate p95
		# numbers identify a regression, but these aligned samples identify which
		# production subsystem occupied each slow browser frame.
		frame_attribution_samples = {
			"frame_ms": frame_ms_samples.duplicate(),
			"snapshot_builds_usec": foundation_snapshot_usec_samples.duplicate(),
			"environment_runtime_usec": foundation_environment_runtime_usec_samples.duplicate(),
			"coin_pusher_native_step_usec": foundation_coin_pusher_native_step_usec_samples.duplicate(),
			"surface_automation_usec": foundation_surface_automation_usec_samples.duplicate(),
			"surface_realtime_usec": foundation_surface_realtime_usec_samples.duplicate(),
			"surface_realtime_ui_usec": foundation_surface_realtime_ui_usec_samples.duplicate(),
			"surface_realtime_module_usec": foundation_surface_realtime_module_usec_samples.duplicate(),
			"surface_realtime_augment_usec": foundation_surface_realtime_augment_usec_samples.duplicate(),
		}
	var record := {
		"name": current_scenario,
		"tags": current_tags.duplicate(false),
		"start_msec": current_start_msec,
		"end_msec": end_msec,
		"duration_msec": maxi(0, end_msec - current_start_msec),
		"frame_time_ms": _float_stats(frame_ms_samples),
		"surface_draw_time_ms": _surface_draw_stats(end_liveness, frame_ms_samples),
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
		"foundation_process_attribution_usec": {
			"snapshot_builds": _int_stats(foundation_snapshot_usec_samples),
			"environment_runtime": _int_stats(foundation_environment_runtime_usec_samples),
			"autosave_flush": _int_stats(foundation_autosave_usec_samples),
			"layout": _int_stats(foundation_layout_usec_samples),
			"coin_pusher_native_step": _int_stats(foundation_coin_pusher_native_step_usec_samples),
			"surface_automation": _int_stats(foundation_surface_automation_usec_samples),
			"surface_realtime": _int_stats(foundation_surface_realtime_usec_samples),
			"surface_realtime_ui": _int_stats(foundation_surface_realtime_ui_usec_samples),
			"surface_realtime_module": _int_stats(foundation_surface_realtime_module_usec_samples),
			"surface_realtime_augment": _int_stats(foundation_surface_realtime_augment_usec_samples),
		},
		"frame_attribution_samples": frame_attribution_samples,
		"liveness_counters_start": current_start_liveness.duplicate(false),
		"liveness_counters": end_liveness,
		"liveness_counter_delta": _liveness_counter_delta(current_start_liveness, end_liveness),
		"allocation_proxy": {
			"sample_count": monitor_sample_count,
			"sample_stride_frames": sample_stride_frames,
			"static_memory_delta_bytes": _int_stats(memory_delta_samples),
			"static_memory_positive_delta_bytes": _int_stats(memory_positive_delta_samples),
			"static_memory_positive_delta_total": _sum_int(memory_positive_delta_samples),
			"static_memory_negative_delta_bytes": _int_stats(memory_negative_delta_samples),
			"static_memory_negative_delta_total": _sum_int(memory_negative_delta_samples),
			"object_count_delta": _int_stats(object_count_delta_samples),
			"object_count_positive_delta": _int_stats(object_count_positive_delta_samples),
			"object_count_positive_delta_total": _sum_int(object_count_positive_delta_samples),
			"object_count_negative_delta": _int_stats(object_count_negative_delta_samples),
			"object_count_negative_delta_total": _sum_int(object_count_negative_delta_samples),
			"node_count_delta": _int_stats(node_count_delta_samples),
		},
		"allocation_copy_counters": _allocation_copy_snapshot(),
	}
	scenario_records.append(record)
	_emit_console("BTH_PERF_SCENARIO ", {"phase": "end", "name": current_scenario, "ticks_msec": end_msec, "frame_count": frame_ms_samples.size()})
	scenario_active = false
	current_scenario = ""


func _surface_draw_stats(end_liveness: Dictionary, measured_frame_samples: Array) -> Dictionary:
	var game_status: Dictionary = end_liveness.get("game_surface", {}) if typeof(end_liveness.get("game_surface", {})) == TYPE_DICTIONARY else {}
	var sample_count := int(game_status.get("draw_sample_count", 0))
	if sample_count > 0:
		return {
			"count": sample_count,
			"avg_ms": float(game_status.get("draw_avg_ms", 0.0)),
			"p95_ms": float(game_status.get("draw_p95_ms", 0.0)),
			"max_ms": float(game_status.get("draw_max_ms", 0.0)),
			"source": "production_game_canvas",
		}
	# PixelSceneCanvas exposes a liveness count but does not publish a separate
	# CPU draw timer. The complete frame cost is a conservative upper bound for
	# environment/system draw cost and can never hide a draw regression.
	var frame_stats := _float_stats(measured_frame_samples)
	return {
		"count": int(frame_stats.get("count", 0)),
		"avg_ms": float(frame_stats.get("avg", 0.0)),
		"p95_ms": float(frame_stats.get("p95", 0.0)),
		"max_ms": float(frame_stats.get("max", 0.0)),
		"source": "complete_frame_upper_bound",
	}


func _allocation_copy_snapshot() -> Dictionary:
	var totals := {"allocations": 0, "shallow_copies": 0, "deep_copies": 0, "bytes": 0}
	var sources: Array = []
	var audited_call_roots: Array = []
	for source_index in range(ALLOCATION_COPY_SOURCE_IDS.size()):
		var row := {
			"source": str(ALLOCATION_COPY_SOURCE_IDS[source_index]),
			"audited": explicit_allocation_audited_sources[source_index] != 0,
			"allocations": int(explicit_allocation_counts[source_index]),
			"shallow_copies": int(explicit_shallow_copy_counts[source_index]),
			"deep_copies": int(explicit_deep_copy_counts[source_index]),
			"bytes": int(explicit_allocation_copy_bytes[source_index]),
		}
		totals["allocations"] = int(totals.get("allocations", 0)) + int(row.allocations)
		totals["shallow_copies"] = int(totals.get("shallow_copies", 0)) + int(row.shallow_copies)
		totals["deep_copies"] = int(totals.get("deep_copies", 0)) + int(row.deep_copies)
		totals["bytes"] = int(totals.get("bytes", 0)) + int(row.bytes)
		sources.append(row)
		if explicit_allocation_audited_sources[source_index] != 0:
			audited_call_roots.append(str(ALLOCATION_COPY_SOURCE_IDS[source_index]))
	totals["source"] = "explicit_instrumented_probe"
	totals["sources"] = sources
	totals["instrumented_source_count"] = ALLOCATION_COPY_SOURCE_IDS.size()
	totals["scope"] = "steady_state_frame"
	totals["evidence_kind"] = "explicit_counter"
	totals["audited_call_roots"] = audited_call_roots
	totals["coverage_complete"] = not audited_call_roots.is_empty()
	return totals


func _reset_allocation_copy_counters() -> void:
	var size := ALLOCATION_COPY_SOURCE_IDS.size()
	explicit_allocation_counts.resize(size)
	explicit_shallow_copy_counts.resize(size)
	explicit_deep_copy_counts.resize(size)
	explicit_allocation_copy_bytes.resize(size)
	explicit_allocation_audited_sources.resize(size)
	explicit_allocation_counts.fill(0)
	explicit_shallow_copy_counts.fill(0)
	explicit_deep_copy_counts.fill(0)
	explicit_allocation_copy_bytes.fill(0)
	explicit_allocation_audited_sources.fill(0)


func _sample_monitors() -> void:
	process_ms_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	physics_ms_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	draw_call_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	render_object_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	primitive_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var memory_bytes := _current_memory_bytes()
	current_last_memory_bytes = memory_bytes
	memory_samples.append(memory_bytes)
	var object_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if monitor_sample_count > 0:
		_record_signed_delta(memory_delta_samples, memory_positive_delta_samples, memory_negative_delta_samples, memory_bytes - last_sample_memory_bytes)
		_record_signed_delta(object_count_delta_samples, object_count_positive_delta_samples, object_count_negative_delta_samples, object_count - last_sample_object_count)
		node_count_delta_samples.append(node_count - last_sample_node_count)
	last_sample_memory_bytes = memory_bytes
	last_sample_object_count = object_count
	last_sample_node_count = node_count
	monitor_sample_count += 1
	object_count_samples.append(object_count)
	node_count_samples.append(node_count)
	orphan_node_count_samples.append(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))


func _trigger_active_game_action(game_id: String) -> Dictionary:
	if app == null:
		return {"accepted": false, "progressed": false, "reason": "missing_app"}
	var action_id := _preferred_action_id(game_id)
	if action_id.is_empty():
		mark_event("missing_action", {"game_id": game_id})
		return {"accepted": false, "progressed": false, "reason": "missing_action"}
	var run_state: RunState = app.get("run_state") as RunState
	var turns_before := int(run_state.current_environment.get("turns", 0)) if run_state != null else -1
	var story_before := run_state.story_log_entry_count() if run_state != null else -1
	var before := app.current_game_view_snapshot()
	var resolve_started_usec := Time.get_ticks_usec()
	app.select_game_action(action_id, "legal")
	app.set_selected_stake(_safe_stake(game_id))
	app.resolve_selected_game_action()
	var resolve_elapsed_usec := Time.get_ticks_usec() - resolve_started_usec
	var result: Dictionary = app.get("last_game_result") if typeof(app.get("last_game_result")) == TYPE_DICTIONARY else {}
	var after := app.current_game_view_snapshot()
	var turns_after := int(run_state.current_environment.get("turns", 0)) if run_state != null else -1
	var story_after := run_state.story_log_entry_count() if run_state != null else -1
	# Accepted alone is not progress: a host bug could acknowledge a no-op. Every
	# ordinary game action must advance a canonical turn or append its story fact.
	var progressed := bool(result.get("ok", false)) and (turns_after > turns_before or story_after > story_before)
	if game_id == "crew_draw_poker":
		progressed = bool(result.get("ok", false)) and str(after.get("phase", "idle")) != "idle" \
			and (int(after.get("hand_number", 0)) > int(before.get("hand_number", 0)) \
				or int(after.get("action_ordinal", 0)) > int(before.get("action_ordinal", 0))) \
			and (turns_after > turns_before or story_after > story_before)
	return {
		"game_id": game_id,
		"action_id": action_id,
		"accepted": bool(result.get("ok", false)),
		"progressed": progressed,
		"message": str(result.get("message", "")),
		"resolve_ms": float(maxi(0, resolve_elapsed_usec)) / 1000.0,
		"environment_turns_before": turns_before,
		"environment_turns_after": turns_after,
		"story_entries_before": story_before,
		"story_entries_after": story_after,
		"phase_before": str(before.get("phase", "")),
		"phase_after": str(after.get("phase", "")),
		"hand_number_before": int(before.get("hand_number", 0)),
		"hand_number_after": int(after.get("hand_number", 0)),
		"action_ordinal_before": int(before.get("action_ordinal", 0)),
		"action_ordinal_after": int(after.get("action_ordinal", 0)),
		"surface_before": _perf06_surface_evidence(before),
		"surface_after": _perf06_surface_evidence(after),
	}


func _trigger_timed_surface_game_action(game_id: String) -> Dictionary:
	if app == null:
		return {"accepted": false, "progressed": false, "reason": "missing_app"}
	var run_state: RunState = app.get("run_state") as RunState
	var turns_before := int(run_state.current_environment.get("turns", 0)) if run_state != null else -1
	var story_before := run_state.story_log_entry_count() if run_state != null else -1
	var before := app.current_game_view_snapshot()
	var action_id := ""
	if game_id == "baccarat":
		# The table minimum is $20; select that real chip before placing the wager.
		_emit_surface_action("baccarat_chip", 2, false)
		await _wait_frames(2)
		_emit_surface_action("baccarat_bet", 0, false)
		await _wait_frames(2)
		action_id = "baccarat_deal"
	elif game_id == "roulette":
		_emit_surface_action("roulette_bet", 0, false)
		await _wait_frames(2)
		action_id = "roulette_spin"
	else:
		return {"accepted": false, "progressed": false, "reason": "unsupported_surface_timeline", "game_id": game_id}
	var started_usec := Time.get_ticks_usec()
	_emit_surface_action(action_id, 0, true)
	await _wait_frames(2)
	var resolve_elapsed_usec := Time.get_ticks_usec() - started_usec
	var result: Dictionary = app.get("last_game_result") if typeof(app.get("last_game_result")) == TYPE_DICTIONARY else {}
	var after := app.current_game_view_snapshot()
	var turns_after := int(run_state.current_environment.get("turns", 0)) if run_state != null else -1
	var story_after := run_state.story_log_entry_count() if run_state != null else -1
	var accepted := bool(result.get("ok", false))
	return {
		"game_id": game_id,
		"action_id": action_id,
		"accepted": accepted,
		"progressed": accepted and (turns_after > turns_before or story_after > story_before),
		"message": str(result.get("message", "")),
		"resolve_ms": float(maxi(0, resolve_elapsed_usec)) / 1000.0,
		"environment_turns_before": turns_before,
		"environment_turns_after": turns_after,
		"story_entries_before": story_before,
		"story_entries_after": story_after,
		"surface_before": _perf06_surface_evidence(before),
		"surface_after": _perf06_surface_evidence(after),
	}


func _perf06_surface_evidence(snapshot: Dictionary) -> Dictionary:
	var evidence := {}
	for key_value in [
		"game_id", "phase", "ritual_phase", "counter_phase", "hand_number",
		"action_ordinal", "result_message", "showdown_active", "deal_staged",
		"payout_staged", "double_up_offered", "baccarat_squeeze_available",
		"rolled", "presentation_phase", "last_net", "win_meter",
		"bar_dice_ritual_phase", "ticket_complete", "pending_payout",
		"revealed_count", "reveal_progress", "session_settled", "pending_double_credits",
		"counting_enabled", "wheel_read_active", "roulette_motion_active",
	]:
		var key := str(key_value)
		if snapshot.has(key):
			evidence[key] = snapshot.get(key)
	var last_result: Variant = snapshot.get("last_result", {})
	evidence["last_result_present"] = typeof(last_result) == TYPE_DICTIONARY and not (last_result as Dictionary).is_empty()
	var ritual_projection: Variant = snapshot.get("ritual_projection", {})
	if typeof(ritual_projection) == TYPE_DICTIONARY:
		var projection: Dictionary = ritual_projection
		evidence["ritual_projection_present"] = not projection.is_empty()
		evidence["ritual_projection_phase"] = str(projection.get("phase_id", projection.get("phase", "")))
		evidence["ritual_acknowledgement_available"] = bool(projection.get("acknowledgement_available", false))
		evidence["ritual_energy_tier"] = str(projection.get("energy_tier", ""))
	else:
		evidence["ritual_projection_present"] = false
		evidence["ritual_projection_phase"] = ""
	var channels: Array = snapshot.get("surface_animation_channels", []) if typeof(snapshot.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	var active_channels: Array = []
	for channel_value in channels:
		if typeof(channel_value) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = channel_value
		if not str(channel.get("active_id", channel.get("id", ""))).is_empty():
			active_channels.append({
				"channel": str(channel.get("channel", channel.get("channel_id", ""))),
				"active_id": str(channel.get("active_id", channel.get("id", ""))),
			})
	evidence["active_animation_channels"] = active_channels
	for projection_key_value in ["bar_dice_ritual_projection", "counter_ritual"]:
		var projection_key := str(projection_key_value)
		var projection_value: Variant = snapshot.get(projection_key, {})
		if typeof(projection_value) == TYPE_DICTIONARY:
			var named_projection: Dictionary = projection_value
			evidence["%s_present" % projection_key] = not named_projection.is_empty()
			evidence["%s_phase" % projection_key] = str(named_projection.get("phase_id", named_projection.get("phase", "")))
	var ritual_actors: Array = snapshot.get("ritual_actors", []) if typeof(snapshot.get("ritual_actors", [])) == TYPE_ARRAY else []
	var ritual_objects: Array = snapshot.get("ritual_scene_objects", []) if typeof(snapshot.get("ritual_scene_objects", [])) == TYPE_ARRAY else []
	evidence["ritual_actor_count"] = ritual_actors.size()
	evidence["ritual_object_count"] = ritual_objects.size()
	return evidence


func _measure_followup_game_phases(game_id: String) -> void:
	match game_id:
		"pull_tabs":
			await _measure_observed_game_phase(game_id, "ritual", "pull_tabs_counter_ritual", 30)
			await _measure_pull_tab_redeem_phase()
		"scratch_tickets":
			_emit_surface_action("scratch_all", 0, false)
			await _wait_frames(2)
			await _measure_observed_game_phase(game_id, "scratch_reveal", "scratch_ticket_full_reveal", 30)
			_emit_surface_action("scratch_file_ticket", 0, false)
			await _wait_frames(2)
			await _measure_observed_game_phase(game_id, "payout", "scratch_ticket_outcome", 30)
			await _measure_observed_game_phase(game_id, "ritual", "scratch_ticket_counter_ritual", 30)
		"slot":
			await _measure_observed_game_phase(game_id, "ritual", "slot_machine_ritual", 30)
			if _install_slot_handpay_fixture():
				await _wait_frames(2)
				await _measure_observed_game_phase(game_id, "jackpot_attendant", "slot_jackpot_attendant", 30)
				_emit_surface_action("slot_handpay_acknowledge", 0, true)
				await _wait_frames(2)
		"bar_dice":
			await _measure_observed_game_phase(game_id, "resolve_payout", "bar_dice_resolve_payout", 30)
			await _measure_observed_game_phase(game_id, "ritual", "bar_dice_table_ritual", 30)
		"blackjack":
			await _measure_observed_game_phase(game_id, "resolve_payout", "blackjack_resolve_payout", 30)
			await _measure_observed_game_phase(game_id, "ritual", "blackjack_table_ritual", 30)
			_emit_surface_action("blackjack_count_toggle", 0, false)
			await _wait_frames(2)
			await _measure_observed_game_phase(game_id, "skill", "blackjack_counting_skill", 30)
		"baccarat":
			await _measure_observed_game_phase(game_id, "ritual", "baccarat_table_ritual", 30)
			if await _wait_for_game_phase(game_id, "skill", 900):
				await _measure_observed_game_phase(game_id, "skill", "baccarat_squeeze_skill", 30)
			if await _wait_for_game_phase(game_id, "resolve_payout", 900):
				await _measure_observed_game_phase(game_id, "resolve_payout", "baccarat_resolve_payout", 30)
		"roulette":
			await _measure_observed_game_phase(game_id, "ritual", "roulette_table_ritual", 30)
			if await _wait_for_game_phase(game_id, "post_spin", 1200):
				await _measure_observed_game_phase(game_id, "post_spin", "roulette_ball_settle", 30)
			if await _wait_for_game_phase(game_id, "resolve_payout", 600):
				await _measure_observed_game_phase(game_id, "resolve_payout", "roulette_resolve_payout", 30)
			await _wait_for_surface_flag_clear("roulette_motion_active", 900)
			_emit_surface_action("roulette_read_wheel", 0, false)
			await _wait_frames(2)
			await _measure_observed_game_phase(game_id, "skill", "roulette_wheel_read_skill", 30)
			_emit_surface_action("roulette_read_wheel", 0, false)
			await _wait_frames(2)
		"craps":
			await _measure_observed_game_phase(game_id, "bounce", "craps_bounce_read", 20)
			await _measure_observed_game_phase(game_id, "ritual", "craps_table_ritual", 20)
			if await _wait_for_game_phase(game_id, "settle", 180):
				await _measure_observed_game_phase(game_id, "settle", "craps_dealer_settlement", 20)
			if await _wait_for_game_phase(game_id, "resolve", 180):
				await _measure_observed_game_phase(game_id, "resolve", "craps_resolved_table", 30)
			await _measure_craps_offer_and_aim()
		"crew_draw_poker":
			await _measure_observed_game_phase(game_id, "ordered_hand", "crew_poker_ordered_hand", 30)
			await _measure_observed_game_phase(game_id, "ritual", "crew_poker_table_ritual", 30)
			await _measure_crew_poker_terminal()
		"video_poker":
			await _measure_observed_game_phase(game_id, "payout", "video_poker_payout", 30)
			await _measure_observed_game_phase(game_id, "ritual", "video_poker_machine_ritual", 30)
			if _install_video_poker_double_fixture():
				await _wait_frames(2)
				_emit_surface_action("video_poker_double", 0, false)
				await _wait_frames(2)
				await _measure_observed_game_phase(game_id, "double_up", "video_poker_double_up", 30)
				_emit_surface_action("video_poker_double_pick", 0, false)
				await _wait_frames(2)


func _measure_observed_game_phase(game_id: String, phase_id: String, scenario_name: String, frames: int) -> bool:
	var before := _current_game_phase_evidence()
	var observed := _game_phase_observed(game_id, phase_id, before)
	if not observed:
		mark_event("perf06_phase_not_observed", {"game_id": game_id, "phase_id": phase_id, "evidence": before})
		return false
	_begin_scenario(scenario_name, {
		"surface": game_id,
		"mode": phase_id,
		"perf06_surface_id": game_id,
		"perf06_phase_id": phase_id,
		"phase_evidence": {"observed": true, "before": before},
	})
	await _wait_frames(frames)
	var after := _current_game_phase_evidence()
	var phase_evidence: Dictionary = current_tags.get("phase_evidence", {})
	phase_evidence["after"] = after
	current_tags["phase_evidence"] = phase_evidence
	_end_scenario()
	return true


func _wait_for_game_phase(game_id: String, phase_id: String, max_frames: int) -> bool:
	for _frame_index in range(maxi(1, max_frames)):
		var evidence := _current_game_phase_evidence()
		if _game_phase_observed(game_id, phase_id, evidence):
			return true
		await get_tree().process_frame
	mark_event("perf06_phase_wait_timeout", {"game_id": game_id, "phase_id": phase_id, "max_frames": max_frames})
	return false


func _wait_for_surface_animation_inactive(channel_id: String, max_frames: int) -> bool:
	var canvas := app.get("game_surface_canvas") as Control if app != null else null
	if canvas == null or not canvas.has_method("surface_animation_active"):
		return false
	for _frame_index in range(max_frames):
		if not bool(canvas.call("surface_animation_active", channel_id)):
			return true
		await get_tree().process_frame
	mark_event("perf06_animation_wait_timeout", {"channel_id": channel_id, "max_frames": max_frames})
	return false


func _wait_for_surface_flag_clear(flag_id: String, max_frames: int) -> bool:
	for _frame_index in range(max_frames):
		var snapshot := _current_game_phase_snapshot()
		if not bool(snapshot.get(flag_id, false)):
			return true
		await get_tree().process_frame
	mark_event("perf06_surface_flag_wait_timeout", {"flag_id": flag_id, "max_frames": max_frames})
	return false


func _current_game_phase_snapshot() -> Dictionary:
	if app == null:
		return {}
	var game: GameModule = app.get("current_game") as GameModule
	var canvas := app.get("game_surface_canvas") as Control
	if game != null and canvas != null and canvas.has_method("realtime_surface_state"):
		var live_value: Variant = canvas.call("realtime_surface_state")
		if typeof(live_value) == TYPE_DICTIONARY:
			var live: Dictionary = live_value
			if str(live.get("game_id", "")) == game.get_id():
				return live
	return app.current_game_view_snapshot()


func _current_game_phase_evidence() -> Dictionary:
	var evidence := _perf06_surface_evidence(_current_game_phase_snapshot())
	var canvas := app.get("game_surface_canvas") as Control if app != null else null
	var animation_channels := {}
	if canvas != null and canvas.has_method("surface_animation_active") and canvas.has_method("surface_animation_progress"):
		for channel_value in ["blackjack_count_rhythm", "baccarat_deal", "baccarat_payout", "roulette_spin", "roulette_payout", "craps_roll"]:
			var channel := str(channel_value)
			animation_channels[channel] = {
				"active": bool(canvas.call("surface_animation_active", channel)),
				"progress": float(canvas.call("surface_animation_progress", channel)),
			}
	evidence["animation_channels"] = animation_channels
	return evidence


func _measure_pull_tab_redeem_phase() -> void:
	# The purchased tab first exists in the dispenser tray. Follow the ordinary
	# collect/reveal/file controls; never mutate the ticket outcome to manufacture
	# a winning row for this measurement.
	await _wait_for_animation_quiet(240)
	_emit_surface_action("pull_tab_collect_tray", 0, false)
	await _wait_frames(4)
	_emit_surface_action("pull_tab_auto_open", 0, false)
	for _reveal_index in range(1200):
		var evidence := _current_game_phase_evidence()
		if _game_phase_observed("pull_tabs", "payout_redeem", evidence):
			break
		await get_tree().process_frame
	var revealed := _current_game_phase_evidence()
	if not _game_phase_observed("pull_tabs", "payout_redeem", revealed):
		mark_event("perf06_phase_not_observed", {"game_id": "pull_tabs", "phase_id": "payout_redeem", "evidence": revealed})
		return
	await _measure_observed_game_phase("pull_tabs", "payout_redeem", "pull_tabs_payout_redeem", 30)


func _wait_for_animation_quiet(max_frames: int) -> bool:
	for _frame_index in range(maxi(1, max_frames)):
		var evidence := _current_game_phase_evidence()
		if (evidence.get("active_animation_channels", []) as Array).is_empty():
			return true
		await get_tree().process_frame
	return false


func _install_slot_handpay_fixture() -> bool:
	if app == null:
		return false
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	if run_state == null or game == null or game.get_id() != "slot":
		return false
	var environment := run_state.current_environment
	var machine := SlotStateScript.read_machine(environment, "slot")
	if machine.is_empty():
		return false
	# Install a presentation-only jackpot result around the machine's current
	# authoritative spin ordinal. The sealed acknowledgement still travels through
	# Foundation's normal action boundary and writes the only durable receipt.
	machine["spin_count"] = maxi(1, int(machine.get("spin_count", 0)))
	machine["last_outcome_id"] = "perf06_jackpot_attendant"
	machine["last_classification"] = "jackpot"
	machine["slot_celebration_tier"] = "jackpot"
	machine["slot_animation_id"] = ""
	machine["active_bonus"] = {}
	machine.erase("ritual_acknowledged_result_id")
	SlotStateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	app.call("_refresh")
	return true


func _install_video_poker_double_fixture() -> bool:
	if app == null:
		return false
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	if run_state == null or game == null or game.get_id() != "video_poker":
		return false
	var environment := run_state.current_environment
	var machine_value: Variant = game.call("_machine_state", run_state, environment)
	if typeof(machine_value) != TYPE_DICTIONARY:
		return false
	var machine: Dictionary = machine_value
	var last_result: Dictionary = machine.get("last_result", {}) if typeof(machine.get("last_result", {})) == TYPE_DICTIONARY else {}
	if last_result.is_empty():
		return false
	# Keep the already-rendered authoritative hand and expose the product's normal
	# double-up offer with a bounded diagnostic credit. The following pick still
	# resolves through the production action authority and RNG stream.
	last_result["double_credits"] = maxi(5, int(last_result.get("win_credits", 0)))
	last_result["win_credits"] = int(last_result["double_credits"])
	last_result["summary"] = "Performance fixture: settled hand offers Double Up."
	machine["last_result"] = last_result
	game.call("_update_environment_state", environment, machine)
	run_state.current_environment = environment
	app.call("_refresh")
	return true


func _measure_craps_offer_and_aim() -> void:
	# Rebet the completed round. A fresh pass-line wager can be illegal while a
	# point is established, which leaves the real throw interaction unavailable.
	_emit_surface_action("craps_rebet", 0, false)
	await _wait_frames(2)
	_emit_surface_pointer("craps_throw", 0, "begin", Vector2(426, 240))
	if await _wait_for_game_phase("craps", "offer", 30):
		await _measure_observed_game_phase("craps", "offer", "craps_dice_offer", 20)
	_emit_surface_pointer("craps_throw", 0, "move", Vector2(438, 190))
	if await _wait_for_game_phase("craps", "aim", 30):
		await _measure_observed_game_phase("craps", "aim", "craps_throw_aim", 20)
	_emit_surface_pointer("craps_throw", 0, "end", Vector2(446, 96))
	await _wait_frames(2)


func _measure_crew_poker_terminal() -> void:
	for _action_index in range(32):
		var evidence := _current_game_phase_evidence()
		if _game_phase_observed("crew_draw_poker", "terminal", evidence):
			break
		var action_evidence := _trigger_active_game_action("crew_draw_poker")
		if not bool(action_evidence.get("accepted", false)):
			mark_event("crew_poker_terminal_action_rejected", action_evidence)
			break
		await _wait_frames(2)
	await _measure_observed_game_phase("crew_draw_poker", "terminal", "crew_poker_terminal", 30)


func _game_phase_observed(game_id: String, phase_id: String, evidence: Dictionary) -> bool:
	var phase := str(evidence.get("phase", ""))
	var ritual_phase := str(evidence.get("ritual_phase", evidence.get("bar_dice_ritual_phase", "")))
	var result_visible := bool(evidence.get("last_result_present", false)) or not str(evidence.get("result_message", "")).is_empty()
	var animations: Dictionary = evidence.get("animation_channels", {}) if typeof(evidence.get("animation_channels", {})) == TYPE_DICTIONARY else {}
	if phase_id == "ritual":
		return bool(evidence.get("ritual_projection_present", false)) \
			or bool(evidence.get("bar_dice_ritual_projection_present", false)) \
			or bool(evidence.get("counter_ritual_present", false)) \
			or not ritual_phase.is_empty() \
			or int(evidence.get("ritual_actor_count", 0)) > 0 \
			or int(evidence.get("ritual_object_count", 0)) > 0
	match game_id:
		"pull_tabs":
			if phase_id != "payout_redeem":
				return false
			if str(evidence.get("result_message", "")).is_empty():
				return false
			return bool(evidence.get("counter_ritual_present", false))
		"scratch_tickets":
			if phase_id == "scratch_reveal":
				return str(evidence.get("counter_phase", "")) in ["play", "file"]
			if phase_id == "payout":
				return result_visible or str(evidence.get("counter_phase", "")) in ["result", "selection"]
		"bar_dice", "blackjack":
			if phase_id == "resolve_payout":
				return result_visible
			if game_id == "blackjack" and phase_id == "skill":
				var count_rhythm: Dictionary = animations.get("blackjack_count_rhythm", {}) if typeof(animations.get("blackjack_count_rhythm", {})) == TYPE_DICTIONARY else {}
				return bool(evidence.get("counting_enabled", false)) or bool(count_rhythm.get("active", false))
		"slot":
			return phase_id == "jackpot_attendant" \
				and str(evidence.get("ritual_projection_phase", "")) == "payout_or_handpay" \
				and bool(evidence.get("ritual_acknowledgement_available", false))
		"baccarat":
			var baccarat_deal: Dictionary = animations.get("baccarat_deal", {}) if typeof(animations.get("baccarat_deal", {})) == TYPE_DICTIONARY else {}
			var baccarat_payout: Dictionary = animations.get("baccarat_payout", {}) if typeof(animations.get("baccarat_payout", {})) == TYPE_DICTIONARY else {}
			if phase_id == "skill":
				var deal_progress := float(baccarat_deal.get("progress", 0.0))
				return ritual_phase == "squeeze_reveal" or (bool(baccarat_deal.get("active", false)) and deal_progress >= 0.43 and deal_progress < 0.58)
			if phase_id == "resolve_payout":
				return (ritual_phase == "settlement" or bool(baccarat_payout.get("active", false))) and result_visible
		"roulette":
			var roulette_spin: Dictionary = animations.get("roulette_spin", {}) if typeof(animations.get("roulette_spin", {})) == TYPE_DICTIONARY else {}
			var roulette_payout: Dictionary = animations.get("roulette_payout", {}) if typeof(animations.get("roulette_payout", {})) == TYPE_DICTIONARY else {}
			if phase_id == "post_spin":
				return ritual_phase == "ball_settle" or (bool(roulette_spin.get("active", false)) and float(roulette_spin.get("progress", 0.0)) >= 0.80)
			if phase_id == "resolve_payout":
				return (ritual_phase == "croupier_settlement" or bool(roulette_payout.get("active", false))) and result_visible
			if phase_id == "skill":
				return bool(evidence.get("wheel_read_active", false))
		"craps":
			var craps_roll: Dictionary = animations.get("craps_roll", {}) if typeof(animations.get("craps_roll", {})) == TYPE_DICTIONARY else {}
			if phase_id == "bounce":
				return ritual_phase == "bounce_read" or (bool(craps_roll.get("active", false)) and float(craps_roll.get("progress", 0.0)) < 0.55)
			if phase_id == "settle":
				return ritual_phase == "dealer_settlement" or (bool(craps_roll.get("active", false)) and float(craps_roll.get("progress", 0.0)) >= 0.55)
			if phase_id == "resolve":
				return not bool(craps_roll.get("active", false)) and result_visible
			if phase_id == "offer":
				return ritual_phase == "dice_offered"
			if phase_id == "aim":
				return ritual_phase == "aiming_throw"
		"crew_draw_poker":
			if phase_id == "ordered_hand":
				return phase in ["before", "draw", "after"]
			if phase_id == "terminal":
				return phase == "idle" and result_visible
		"video_poker":
			if phase_id == "payout":
				return phase in ["settled", "double_result"] and result_visible
			if phase_id == "double_up":
				return phase == "double_up" and int(evidence.get("pending_double_credits", 0)) > 0
	return false


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


func _safe_stake(game_id: String = "") -> int:
	var run_state: RunState = app.get("run_state") as RunState
	if run_state == null:
		return 1
	var environment: Dictionary = run_state.current_environment
	var economic_profile: Dictionary = environment.get("economic_profile", {})
	return maxi(int(ACTIVE_STAKES.get(game_id, 1)), int(economic_profile.get("stake_floor", 1)))


func _emit_surface_action(action_id: String, index: int, confirm: bool) -> void:
	if app == null:
		return
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null:
		mark_event("missing_surface_canvas", {"action_id": action_id})
		return
	canvas.emit_signal("surface_action", action_id, index, confirm)


func _emit_surface_pointer(action_id: String, index: int, phase: String, board_position: Vector2) -> void:
	if app == null:
		return
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null:
		mark_event("missing_surface_canvas", {"action_id": action_id, "phase": phase})
		return
	canvas.emit_signal("surface_pointer_action", action_id, index, phase, board_position)


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
	overlay_label.size = Vector2(560, 150)
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
	var liveness := _liveness_counter_snapshot()
	var game_live: Dictionary = liveness.get("game_surface", {})
	var environment_live: Dictionary = liveness.get("environment_scene", {})
	overlay_label.text = "BTH PERF %s\nframe %.2fms fps %.1f scenario %s\nmain usec snapshot %d env %d autosave %d layout %d\ncanvas draw %.3fms samples %d\nlive surface_animation_redraw_count %d scene_idle_animation_redraw_count %d\ntelemetry %.4fms avg" % [
		_platform_label(),
		frame_ms,
		float(fps),
		current_scenario,
		foundation_snapshot_last_usec,
		foundation_environment_runtime_last_usec,
		foundation_autosave_last_usec,
		foundation_layout_last_usec,
		float(game_live.get("draw_avg_ms", 0.0)),
		int(game_live.get("draw_sample_count", 0)),
		int(game_live.get("surface_animation_redraw_count", 0)),
		int(environment_live.get("scene_idle_animation_redraw_count", 0)),
		float(overhead.get("avg_ms", 0.0)),
	]


func overhead_snapshot() -> Dictionary:
	return _overhead_stats()


func foundation_attribution_snapshot() -> Dictionary:
	return {
		"snapshot_builds": _int_stats(foundation_snapshot_usec_samples),
		"environment_runtime": _int_stats(foundation_environment_runtime_usec_samples),
		"autosave_flush": _int_stats(foundation_autosave_usec_samples),
		"layout": _int_stats(foundation_layout_usec_samples),
		"coin_pusher_native_step": _int_stats(foundation_coin_pusher_native_step_usec_samples),
		"surface_automation": _int_stats(foundation_surface_automation_usec_samples),
		"surface_realtime": _int_stats(foundation_surface_realtime_usec_samples),
		"surface_realtime_ui": _int_stats(foundation_surface_realtime_ui_usec_samples),
		"surface_realtime_module": _int_stats(foundation_surface_realtime_module_usec_samples),
		"surface_realtime_augment": _int_stats(foundation_surface_realtime_augment_usec_samples),
	}


func _liveness_counter_snapshot() -> Dictionary:
	if app == null:
		return {"game_surface": {}, "environment_scene": {}}
	var game_status: Dictionary = {}
	var game_canvas := app.get("game_surface_canvas") as Control
	if game_canvas != null and game_canvas.has_method("performance_counters"):
		game_status = game_canvas.call("performance_counters")
		var draw_samples: Array = game_status.get("draw_frame_usec_samples", []) if typeof(game_status.get("draw_frame_usec_samples", [])) == TYPE_ARRAY else []
		game_status["draw_sample_count"] = int(game_status.get("draw_sample_count", draw_samples.size()))
	elif game_canvas != null and game_canvas.has_method("performance_live_status"):
		game_status = game_canvas.call("performance_live_status")
	var environment_status: Dictionary = {}
	var environment_canvas := app.get("environment_canvas") as Control
	if environment_canvas != null and environment_canvas.has_method("performance_live_status"):
		environment_status = environment_canvas.call("performance_live_status")
	return {
		"game_surface": game_status,
		"environment_scene": environment_status,
	}


func _liveness_counter_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var before_game := before.get("game_surface", {}) as Dictionary
	var after_game := after.get("game_surface", {}) as Dictionary
	var before_environment := before.get("environment_scene", {}) as Dictionary
	var after_environment := after.get("environment_scene", {}) as Dictionary
	return {
		"game_surface": {
			"surface_animation_redraw_count": int(after_game.get("surface_animation_redraw_count", 0)) - int(before_game.get("surface_animation_redraw_count", 0)),
			"surface_animation_scheduler_elapsed_msec": int(after_game.get("surface_animation_scheduler_elapsed_msec", 0)) - int(before_game.get("surface_animation_scheduler_elapsed_msec", 0)),
			"surface_idle_animation_fps": float(after_game.get("surface_idle_animation_fps", 0.0)),
			"draw_sample_count": int(after_game.get("draw_sample_count", 0)) - int(before_game.get("draw_sample_count", 0)),
		},
		"environment_scene": {
			"scene_idle_animation_redraw_count": int(after_environment.get("scene_idle_animation_redraw_count", 0)) - int(before_environment.get("scene_idle_animation_redraw_count", 0)),
		},
	}


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


func _sum_int(samples: Array) -> int:
	var total := 0
	for sample_value in samples:
		total += int(sample_value)
	return total


func _record_signed_delta(all_samples: Array, positive_samples: Array, negative_samples: Array, delta: int) -> void:
	all_samples.append(delta)
	if delta > 0:
		positive_samples.append(delta)
	elif delta < 0:
		negative_samples.append(abs(delta))


func _duration_ms_since(started_usec: int) -> float:
	return float(maxi(0, Time.get_ticks_usec() - started_usec)) / 1000.0


func _boot_timeline_snapshot() -> Dictionary:
	if app == null or not app.has_method("boot_telemetry_snapshot"):
		return {}
	return app.call("boot_telemetry_snapshot") as Dictionary


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
