extends Node

# Dedicated executable entry point. This scene is used directly for native
# capture/profiling and as the transient Web export main scene.

const MainScene := preload("res://scenes/main.tscn")
const ProbeSupport := preload("res://tools/scenario_sequence_probe_support.gd")

class EvidenceOverlay extends Control:
	var evidence_rects: Array = []
	var reserved_rect := Rect2()
	var label := ""

	func _draw() -> void:
		if reserved_rect.has_area():
			draw_rect(reserved_rect, Color(1.0, 0.20, 0.25, 0.18), true)
			draw_rect(reserved_rect, Color(1.0, 0.35, 0.35, 0.95), false, 3.0)
		for rect_value in evidence_rects:
			var rect: Rect2 = rect_value
			draw_rect(rect, Color(0.20, 1.0, 0.55, 0.12), true)
			draw_rect(rect, Color(0.20, 1.0, 0.65, 0.95), false, 2.0)
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(24.0, 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)


var app: Control
var failures: Array = []
var options: Dictionary = {}
var library: Variant = null
var run_state: Variant = null
var initial_run_snapshot: Dictionary = {}
var arrival_transition_run_snapshot: Dictionary = {}
var semantic_checkpoints: Array = []
var transition_samples_ms: Array = []
var prepared_frame_samples_ms: Array = []
var performance_rows: Dictionary = {}
var capture_records: Array = []
var capture_counts: Dictionary = {}
var active_overlay: EvidenceOverlay = null
var reduced_motion_feedback := ""
var failed_transition_count := 0


func _ready() -> void:
	options = _read_options()
	await _run()


func _run() -> void:
	var preparation_started := Time.get_ticks_usec()
	var contract := ProbeSupport.production_contract()
	_record_performance("package_contract_preflight", _elapsed_ms(preparation_started))
	for failure_value in _array(contract.get("failures", [])):
		_fail(str(failure_value))
	if not bool(contract.get("ok", false)):
		_finish({"schema": "env06_6_scenario_sequence_probe_v1"})
		return
	if str(options.get("mode", "probe")) == "visual" and OS.has_feature("web"):
		_fail("Visual capture must use the native windowed GL path.")
		_finish({"schema": "env06_6_scenario_sequence_capture_manifest_v1"})
		return
	await _start_production_app()
	if app == null or run_state == null or library == null:
		_finish({"schema": "env06_6_scenario_sequence_probe_v1"})
		return
	await _exercise_exact_sequence()
	var steady_frame := await _measure_steady_prepared_frames()
	if str(options.get("mode", "probe")) == "visual":
		await _finish_visual_manifest(steady_frame)
	else:
		_finish_probe_report(steady_frame)


func _start_production_app() -> void:
	var content_started := Time.get_ticks_usec()
	var detached_library := ContentLibrary.new()
	var detached_load: Dictionary = detached_library.load(true)
	var detached_timing := detached_library.load_timing_snapshot()
	_record_performance("content_schema_catalog_preparation", _elapsed_ms(content_started))
	var detached_catalog := _dict(detached_load.get("scenario_sequence_catalog", {}))
	var detached_errors := _array(detached_library.get("validation_errors"))
	if not bool(detached_catalog.get("ok", false)) \
		or detached_library.scenario(ProbeSupport.SCENARIO_ID).is_empty() \
		or not detached_errors.is_empty() \
		or float(detached_timing.get("total_ms", 0.0)) <= 0.0:
		_fail("Detached production ContentLibrary schema/catalog/index preparation failed.")
	app = MainScene.instantiate() as Control
	if app == null:
		_fail("Could not instantiate the production main scene.")
		return
	add_child(app)
	await _settle(4)
	app.call("start_foundation_run", ProbeSupport.PROOF_SEED, {}, false)
	await _settle(6)
	library = app.get("library")
	run_state = app.get("run_state")
	if library == null or run_state == null:
		_fail("Production FoundationMain did not expose ContentLibrary and RunState.")
		return
	var definition: Dictionary = library.call("scenario", ProbeSupport.SCENARIO_ID)
	var archetype: Dictionary = library.call("environment_archetype", ProbeSupport.ARCHETYPE_ID)
	if definition.is_empty() or archetype.is_empty():
		_fail("Production delivery-day definition or corner-store archetype is missing.")
		return
	var rng: RngStream = run_state.call("create_rng", "env06_6:executable-proof")
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, {}, definition)
	var data: Dictionary = environment.call("to_dict")
	data["world_node_id"] = ProbeSupport.NODE_ID
	var generator := RunGenerator.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.call("set_environment", data)
	arrival_transition_run_snapshot = _save_run_snapshot()
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(6)
	var projection := _projection()
	if str(projection.get("scenario_id", "")) != ProbeSupport.SCENARIO_ID or str(projection.get("phase_id", "")) != "arrival":
		_fail("Production main scene did not attach delivery day at arrival.")
		return
	initial_run_snapshot = _save_run_snapshot()
	await _measure_production_save_load()


func _exercise_exact_sequence() -> void:
	await _restore_run(initial_run_snapshot)
	await _evidence("arrival_delivery_blocked", "arrival")
	await _evidence("base_event_pre_request_gated", "arrival", "", "pre_request_gate")
	await _evidence("obstruction_overlay_zero_overlap", "arrival", "", "obstruction")
	await _evidence("hit_target_overlay_44_minimum", "arrival", "", "hit_targets")

	await _activate_command("inspect_manifest", "sorting")
	await _evidence("sorting_aisle_rerouted", "sorting")
	await _activate_command("shift_cartons", "verification")
	await _evidence("verification_station_ready", "verification")
	await _activate_command("request_stock_check", "awaiting_stock")
	await _evidence("awaiting_stock_choice", "awaiting_stock")
	await _evidence("base_event_request_delivered", "awaiting_stock", "", "request_delivered")
	var awaiting_run_snapshot := _save_run_snapshot()

	var reentry_start := Time.get_ticks_usec()
	var partial_reentry: Dictionary = run_state.call("scenario_reenter_current", "env06_6:partial:awaiting")
	var reentry_elapsed := _elapsed_ms(reentry_start)
	await _settle(2)
	transition_samples_ms.append(reentry_elapsed)
	_record_performance("reentry", reentry_elapsed)
	if not bool(partial_reentry.get("ok", false)):
		failed_transition_count += 1
		_fail("Production partial reentry failed.")
	app.call("_refresh")
	await _settle(2)
	await _evidence("partial_revisit_awaiting_stock", "awaiting_stock")

	await _restore_run(awaiting_run_snapshot)
	await _resolve_event_choice("clear_the_aisle", "repaired")
	await _evidence("resolution_repaired", "", "repaired")
	var repaired_run_snapshot := _save_run_snapshot()
	await _reenter_terminal(repaired_run_snapshot, "repaired", "terminal_revisit_repaired")

	await _restore_run(awaiting_run_snapshot)
	await _resolve_event_choice("take_the_deal", "broken")
	await _evidence("resolution_broken", "", "broken")
	var broken_run_snapshot := _save_run_snapshot()
	await _reenter_terminal(broken_run_snapshot, "broken", "terminal_revisit_broken")

	await _restore_run(initial_run_snapshot)
	await _activate_command("refuse_sort", "", "refused")
	await _evidence("resolution_refused", "", "refused")
	var refused_run_snapshot := _save_run_snapshot()
	await _reenter_terminal(refused_run_snapshot, "refused", "terminal_revisit_refused")
	await _evidence("base_event_terminal_gated", "", "refused", "terminal_gate")

	await _restore_run(initial_run_snapshot)
	await _activate_command("ignore_delivery", "", "interrupted")
	await _evidence("resolution_interrupted", "", "interrupted")
	var interrupted_run_snapshot := _save_run_snapshot()
	await _reenter_terminal(interrupted_run_snapshot, "interrupted", "terminal_revisit_interrupted")

	await _restore_run(initial_run_snapshot)
	var expiry_start := Time.get_ticks_usec()
	var expiry: Dictionary = run_state.call("scenario_apply_expiry", "night_end", 1)
	var expiry_elapsed := _elapsed_ms(expiry_start)
	await _settle(2)
	transition_samples_ms.append(expiry_elapsed)
	_record_performance("expiry", expiry_elapsed)
	if not bool(expiry.get("ok", false)):
		failed_transition_count += 1
		_fail("Production night-end expiry failed.")
	var expired_reentry: Dictionary = run_state.call("scenario_reenter_current", "env06_6:expired:night_end")
	if not bool(expired_reentry.get("ok", false)):
		_fail("Production expired-state reentry failed.")
	app.call("_refresh")
	await _settle(3)
	await _evidence("expired_revisit_night_end", "")

	await _restore_run_pre_consumption(arrival_transition_run_snapshot)
	var settings: Variant = app.get("user_settings")
	if settings == null:
		_fail("Production user settings are unavailable.")
	else:
		settings.set("reduce_motion", true)
		app.call("_apply_accessibility_settings")
		reduced_motion_feedback = str(app.call("_consume_scenario_transitions")).strip_edges()
		if not reduced_motion_feedback.is_empty():
			app.call("_show_message", reduced_motion_feedback)
		app.call("_refresh")
		await _settle(3)
		await _evidence("reduced_motion_arrival", "arrival", "", "reduced_motion")
		settings.set("reduce_motion", false)
		settings.set("play_on_small_screen", true)
		app.call("_apply_accessibility_settings")
		await _settle(3)
		await _evidence("small_screen_104x76", "arrival", "", "small_screen")
		settings.set("play_on_small_screen", false)
		app.call("_apply_accessibility_settings")
		await _settle(2)


func _reenter_terminal(snapshot: Dictionary, outcome: String, capture_id: String) -> void:
	await _restore_run(snapshot)
	var started := Time.get_ticks_usec()
	var result: Dictionary = run_state.call("scenario_reenter_current", "env06_6:terminal:%s" % outcome)
	var elapsed := _elapsed_ms(started)
	await _settle(2)
	transition_samples_ms.append(elapsed)
	_record_performance("reentry", elapsed)
	if not bool(result.get("ok", false)):
		failed_transition_count += 1
		_fail("Production %s terminal reentry failed." % outcome)
	app.call("_refresh")
	await _settle(2)
	await _evidence(capture_id, "", outcome)


func _restore_run(snapshot: Dictionary) -> void:
	var settings: Variant = app.get("user_settings")
	if settings != null:
		settings.set("reduce_motion", false)
		settings.set("play_on_small_screen", false)
		app.call("_apply_accessibility_settings")
	var started := Time.get_ticks_usec()
	run_state.call("from_dict", snapshot.duplicate(true))
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	_record_performance("load_rebuild", _elapsed_ms(started))


func _restore_run_pre_consumption(snapshot: Dictionary) -> void:
	var settings: Variant = app.get("user_settings")
	if settings != null:
		settings.set("reduce_motion", false)
		settings.set("play_on_small_screen", false)
	var started := Time.get_ticks_usec()
	run_state.call("from_dict", snapshot.duplicate(true))
	app.call("_clear_selected_game_action")
	_record_performance("load_rebuild", _elapsed_ms(started))


func _activate_command(command_id: String, expected_phase: String, expected_outcome: String = "") -> void:
	var token := _action_token(command_id)
	if token.is_empty():
		_fail("No enabled production UI token exists for scenario command %s." % command_id)
		return
	var started := Time.get_ticks_usec()
	var activated := bool(app.call("activate_interactable_object", token))
	var elapsed := _elapsed_ms(started)
	await _settle(3)
	transition_samples_ms.append(elapsed)
	_record_performance("command", elapsed)
	if command_id == "request_stock_check":
		_record_performance("command_request_drain_event_delivery", elapsed)
	if not expected_outcome.is_empty():
		_record_performance("terminal_cleanup", elapsed)
	if not activated:
		failed_transition_count += 1
		_fail("Production FoundationMain rejected scenario command %s." % command_id)
	_assert_projection(expected_phase, expected_outcome, "command %s" % command_id)


func _resolve_event_choice(choice_id: String, expected_outcome: String) -> void:
	var before_boundary := int(_scenario_state().get("boundary_serial", -1))
	var started := Time.get_ticks_usec()
	var activated := bool(app.call("activate_interactable_object", "event_response:%s:%s" % [ProbeSupport.EVENT_ID, choice_id]))
	var elapsed := _elapsed_ms(started)
	await _settle(4)
	transition_samples_ms.append(elapsed)
	_record_performance("fact_publish_flush_terminal_cleanup", elapsed)
	_record_performance("terminal_cleanup", elapsed)
	if not activated:
		failed_transition_count += 1
		_fail("Production FoundationMain rejected event choice %s." % choice_id)
	_assert_projection("", expected_outcome, "event choice %s" % choice_id)
	var state := _scenario_state()
	if int(state.get("boundary_serial", -1)) != before_boundary + 1:
		_fail("Event choice %s did not resolve at exactly one existing action boundary." % choice_id)
	if not _array(state.get("fact_queue", [])).is_empty() or not _array(state.get("event_request_queue", [])).is_empty():
		_fail("Event choice %s left a fact/request queued after the resolution boundary." % choice_id)


func _action_token(command_id: String) -> String:
	for record_value in _interactable_records():
		var record := _dict(record_value)
		for action_value in _array(record.get("inline_actions", [])):
			var action := _dict(action_value)
			if str(action.get("scenario_command_id", action.get("id", ""))) == command_id and bool(action.get("enabled", true)):
				return str(action.get("emit_object_id", ""))
	return ""


func _evidence(capture_id: String, expected_phase: String, expected_outcome: String = "", special: String = "") -> void:
	_assert_projection(expected_phase, expected_outcome, capture_id)
	if special == "obstruction":
		var focus_id := _first_scenario_object_id()
		if not focus_id.is_empty():
			app.call("focus_interactable_object", focus_id)
			app.call("_refresh")
			await _settle(3)
			var talk: Variant = app.get("talk_dock")
			if talk != null:
				talk.call("set_entry", {
					"event_id": "env06_6_obstruction_evidence",
					"speaker": {"speaking_character_name": "Room evidence"},
				}, {
					"summary": "The marked front-door lane and delivery controls remain clear beside this player-facing conversation.",
				}, 0)
				await _settle(3)
		_install_overlay("obstruction")
		await _settle(2)
	var projection_started := Time.get_ticks_usec()
	var projection_canvas: Variant = app.get("environment_canvas")
	if projection_canvas != null:
		projection_canvas.call("render_environment_snapshot", app.call("current_environment_view_snapshot"))
		projection_canvas.call("current_view_snapshot")
	_record_performance("projection_layout", _elapsed_ms(projection_started))
	var live_assertions := _live_assertions(special)
	for failure_value in _array(live_assertions.get("failures", [])):
		_fail("%s: %s" % [capture_id, str(failure_value)])
	_record_semantic_checkpoint(capture_id, live_assertions)
	if str(options.get("mode", "probe")) != "visual":
		_clear_evidence_overlay()
		return
	if capture_counts.has(capture_id):
		_fail("Capture id %s was requested more than once." % capture_id)
		return
	capture_counts[capture_id] = 1
	if (special == "obstruction" or special == "hit_targets") and active_overlay == null:
		_install_overlay(special)
	await _settle(2)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var absolute_dir := _absolute_output_dir()
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file_name := "%s.png" % capture_id
	var absolute_path := absolute_dir.path_join(file_name)
	var save_error := image.save_png(absolute_path)
	_clear_evidence_overlay()
	if save_error != OK:
		_fail("Capture %s could not save its PNG." % capture_id)
	var png_sha256 := FileAccess.get_sha256(absolute_path) if save_error == OK else ""
	if png_sha256.length() != 64:
		_fail("Capture %s did not produce a SHA-256-addressable PNG." % capture_id)
	capture_records.append({
		"capture_id": capture_id,
		"file": file_name,
		"png_sha256": png_sha256,
		"width": image.get_width(),
		"height": image.get_height(),
		"image_format": "png",
		"phase_id": str(_projection().get("phase_id", "")),
		"status": str(_projection().get("status", "")),
		"outcomes": _array(_projection().get("resolved_outcomes", [])).duplicate(),
		"visual_state_sha256": ProbeSupport.canonical_semantic_sha256({"semantic": {"projection": _projection(), "view": _environment_view()}}),
		"live_assertions_passed": _array(live_assertions.get("failures", [])).is_empty(),
		"assertions": _dict(live_assertions.get("assertions", {})),
	})


func _live_assertions(special: String) -> Dictionary:
	var assertion_failures: Array = []
	var view := _environment_view()
	var layout := _dict(view.get("object_layout", {}))
	if int(layout.get("overlap_count", -1)) != 0:
		assertion_failures.append("Live production layout contains object overlaps.")
	var hit_rects := _live_hit_rects()
	var scenario_hit_rects := _enabled_scenario_hit_rects()
	var minimum_hit := Vector2(INF, INF)
	for rect_value in hit_rects:
		var rect: Rect2 = rect_value
		minimum_hit.x = minf(minimum_hit.x, rect.size.x)
		minimum_hit.y = minf(minimum_hit.y, rect.size.y)
	if hit_rects.is_empty():
		assertion_failures.append("Live production view exposes no interactive hit rectangles.")
	elif minimum_hit.x < 44.0 or minimum_hit.y < 44.0:
		assertion_failures.append("A live production hit target is smaller than 44x44.")
	var event_record := _event_interactable_record()
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	var state := _scenario_state()
	var accessibility: Dictionary = app.call("current_accessibility_snapshot")
	var result_feedback: Dictionary = app.call("current_environment_result_feedback_snapshot")
	var reserved := _rect(view.get("reserved_overlay_global_rect", Rect2()))
	var obstruction_target_rects := _obstruction_target_rects()
	var obstruction_count := _reserved_overlap_count(reserved, obstruction_target_rects)
	var object_evidence := _live_object_evidence(reserved)
	assertion_failures.append_array(_array(object_evidence.get("failures", [])))
	match special:
		"pre_request_gate":
			if event_record.is_empty() or bool(event_record.get("enabled", true)):
				assertion_failures.append("Base event is not visibly gated before request authority.")
			if not _array(state.get("event_request_history", [])).is_empty():
				assertion_failures.append("Base-event pre-request evidence already contains delivered authority.")
		"request_delivered":
			if not bool(popup.get("visible", false)) or str(popup.get("event_id", "")) != ProbeSupport.EVENT_ID:
				assertion_failures.append("Delivered request did not visibly activate the production event modal.")
			if _array(state.get("event_request_history", [])).size() != 1 or not _array(state.get("event_request_queue", [])).is_empty():
				assertion_failures.append("Delivered event request history/queue is not exact.")
		"terminal_gate":
			if event_record.is_empty() or bool(event_record.get("enabled", true)):
				assertion_failures.append("Unresolved terminal outcome did not retain the base-event gate.")
		"reduced_motion":
			if not bool(view.get("reduce_motion", false)) or not bool(accessibility.get("reduce_motion", false)):
				assertion_failures.append("Reduced-motion capture is not using the production reduced-motion view.")
			var feedback_text := str(result_feedback.get("text", result_feedback.get("message", ""))).strip_edges()
			if reduced_motion_feedback.is_empty() \
				or not bool(result_feedback.get("visible", false)) \
				or feedback_text.find(reduced_motion_feedback) < 0 \
				or not _array(state.get("active_stages", [])).is_empty() \
				or not _array(_dict(state.get("semantic_state", {})).get("transition_queue", [])).is_empty():
				assertion_failures.append("Reduced-motion transition did not suppress timed stages while preserving readable feedback.")
		"small_screen":
			var small_accessibility := _dict(accessibility.get("small_screen", {}))
			if not bool(view.get("small_screen_mode", false)) or not bool(small_accessibility.get("enabled", false)):
				assertion_failures.append("Small-screen capture is not using production small-screen mode.")
			var policy_size: Variant = view.get("minimum_environment_hit_size", Vector2.ZERO)
			var policy_ok := typeof(policy_size) == TYPE_VECTOR2 and (policy_size as Vector2).is_equal_approx(Vector2(104.0, 76.0))
			var primary_target := _primary_enabled_scenario_target()
			var scenario_logical_size: Vector2 = primary_target.get("logical_size", Vector2.ZERO)
			if not policy_ok or str(primary_target.get("object_id", "")).is_empty() or str(primary_target.get("command_id", "")).is_empty() or scenario_logical_size.x < 104.0 or scenario_logical_size.y < 76.0:
				assertion_failures.append("Resolved production small-screen target geometry is below 104x76.")
		"obstruction":
			var talk: Variant = app.get("talk_dock")
			var talk_snapshot: Dictionary = talk.call("current_snapshot") if talk != null else {}
			var talk_reserved: Rect2 = talk.call("environment_reserved_global_rect") if talk != null else Rect2()
			if scenario_hit_rects.size() != 1 or obstruction_target_rects.size() < 2:
				assertion_failures.append("Obstruction evidence does not contain the exact enabled scenario target and an enabled safe exit.")
			if not reserved.has_area():
				assertion_failures.append("Production obstruction overlay has no reserved rectangle.")
			if not bool(talk_snapshot.get("visible", false)) or not talk_reserved.has_area() or not talk_reserved.is_equal_approx(reserved):
				assertion_failures.append("TalkDock did not publish the authoritative visible environment reservation.")
			if obstruction_count != 0:
				assertion_failures.append("Production obstruction overlay intersects a live target.")
			if not bool(object_evidence.get("selected_composition_unobstructed", false)):
				assertion_failures.append("Selected scenario composition intersects the TalkDock reservation.")
		"hit_targets":
			if hit_rects.is_empty() or minimum_hit.x < 44.0 or minimum_hit.y < 44.0:
				assertion_failures.append("Production target overlay cannot prove the 44 minimum.")
	return {
		"failures": assertion_failures,
		"assertions": {
			"phase_id": str(_projection().get("phase_id", "")),
			"outcomes": _array(_projection().get("resolved_outcomes", [])),
			"layout_overlap_count": int(layout.get("overlap_count", -1)),
			"live_hit_rect_count": hit_rects.size(),
			"minimum_live_hit_width": 0.0 if is_inf(minimum_hit.x) else minimum_hit.x,
			"minimum_live_hit_height": 0.0 if is_inf(minimum_hit.y) else minimum_hit.y,
			"enabled_scenario_target_count": scenario_hit_rects.size(),
			"primary_enabled_scenario_target": _primary_enabled_scenario_target(),
			"reserved_overlay_has_area": reserved.has_area(),
			"obstruction_target_count": obstruction_target_rects.size(),
			"reserved_overlay_overlap_count": obstruction_count,
			"small_screen_mode": bool(view.get("small_screen_mode", false)),
			"reduce_motion": bool(view.get("reduce_motion", false)),
			"event_enabled": bool(event_record.get("enabled", false)) if not event_record.is_empty() else false,
			"event_popup_visible": bool(popup.get("visible", false)),
			"reduced_motion_feedback": reduced_motion_feedback,
			"center_hit_correlation_count": int(object_evidence.get("center_hit_correlation_count", 0)),
			"interactive_object_count": int(object_evidence.get("interactive_object_count", 0)),
			"safe_exit_unobstructed": bool(object_evidence.get("safe_exit_unobstructed", false)),
			"scenario_non_color_text_complete": bool(object_evidence.get("scenario_non_color_text_complete", false)),
			"z_order_fingerprint": str(object_evidence.get("z_order_fingerprint", "")),
		},
	}


func _live_object_evidence(reserved: Rect2) -> Dictionary:
	var evidence_failures: Array = []
	var canvas: Control = app.get("environment_canvas") as Control
	if canvas == null:
		return {"failures": ["Production environment canvas is unavailable."]}
	var view: Dictionary = canvas.call("current_view_snapshot")
	var ordered_identity: Array = []
	var interactive_count := 0
	var center_hits := 0
	for object_value in _array(view.get("objects", [])):
		var object_data := _dict(object_value)
		var object_id := str(object_data.get("id", ""))
		ordered_identity.append({"id": object_id, "z_order": int(object_data.get("z_order", 0))})
		if not bool(object_data.get("interactive", true)) or bool(object_data.get("disabled", false)):
			continue
		var rect: Rect2 = canvas.call("global_rect_for_object", object_id)
		if not rect.has_area():
			continue
		interactive_count += 1
		var local_center := canvas.to_local(rect.get_center())
		if str(canvas.call("object_id_at_local_position", local_center)) == object_id:
			center_hits += 1
	if interactive_count == 0 or center_hits != interactive_count:
		evidence_failures.append("Live target centers do not correlate exactly with production hit testing.")
	var safe_exit_unobstructed := false
	for record_value in _interactable_records():
		var record := _dict(record_value)
		var enabled_inline := false
		for action_value in _array(record.get("inline_actions", [])):
			if bool(_dict(action_value).get("enabled", true)):
				enabled_inline = true
				break
		if not bool(record.get("safe_exit", false)) or not bool(record.get("enabled", true)) or not bool(record.get("interactive", true)) or not enabled_inline:
			continue
		var exit_rect: Rect2 = canvas.call("global_rect_for_object", str(record.get("object_id", "")))
		var exit_center := canvas.to_local(exit_rect.get_center()) if exit_rect.has_area() else Vector2.ZERO
		if exit_rect.has_area() \
			and str(canvas.call("object_id_at_local_position", exit_center)) == str(record.get("object_id", "")) \
			and (not reserved.has_area() or not exit_rect.intersects(reserved)):
			safe_exit_unobstructed = true
			break
	if not safe_exit_unobstructed:
		evidence_failures.append("No enabled safe-exit target is visibly unobstructed.")
	var selected_composition: Rect2 = canvas.call("global_rect_for_selected_composition")
	var selected_composition_unobstructed := selected_composition.has_area() and (not reserved.has_area() or not selected_composition.intersects(reserved))
	var scenario_non_color_text_complete := true
	var scenario_count := 0
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if str(record.get("object_type", "")) != "scenario":
			continue
		scenario_count += 1
		if str(record.get("label", "")).strip_edges().is_empty() \
			or str(record.get("non_color_state", record.get("state_badge", ""))).strip_edges().is_empty() \
			or str(record.get("action_summary", "")).strip_edges().is_empty():
			scenario_non_color_text_complete = false
	if scenario_count == 0 or not scenario_non_color_text_complete:
		evidence_failures.append("Scenario targets lack visible text/non-color state evidence.")
	return {
		"failures": evidence_failures,
		"interactive_object_count": interactive_count,
		"center_hit_correlation_count": center_hits,
		"safe_exit_unobstructed": safe_exit_unobstructed,
		"selected_composition_unobstructed": selected_composition_unobstructed,
		"scenario_non_color_text_complete": scenario_non_color_text_complete,
		"z_order_fingerprint": JSON.stringify(ordered_identity, "", true).sha256_text(),
	}


func _assert_projection(expected_phase: String, expected_outcome: String, label: String) -> void:
	var projection := _projection()
	if not expected_phase.is_empty() and str(projection.get("phase_id", "")) != expected_phase:
		_fail("%s expected phase %s but saw %s." % [label, expected_phase, str(projection.get("phase_id", ""))])
	if not expected_outcome.is_empty() and _array(projection.get("resolved_outcomes", [])) != [expected_outcome]:
		_fail("%s expected outcome %s." % [label, expected_outcome])


func _record_semantic_checkpoint(label: String, live_assertions: Dictionary) -> void:
	var projection := _projection()
	var state := _scenario_state()
	var event_record := _event_interactable_record()
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	semantic_checkpoints.append({
		"label": label,
		"projection": {
			"scenario_id": str(projection.get("scenario_id", "")),
			"node_id": str(projection.get("node_id", "")),
			"phase_id": str(projection.get("phase_id", "")),
			"status": str(projection.get("status", "")),
			"boundary_serial": int(projection.get("boundary_serial", 0)),
			"objectives": _array(projection.get("objectives", [])).duplicate(true),
			"local_state": _dict(projection.get("local_state", {})).duplicate(true),
			"resolved_outcomes": _array(projection.get("resolved_outcomes", [])).duplicate(),
		},
		"authority": {
			"fact_queue_count": _array(state.get("fact_queue", [])).size(),
			"fact_receipts": _array(state.get("fact_receipts", [])).duplicate(),
			"command_receipts": _array(state.get("command_receipts", [])).duplicate(),
			"event_choice_receipts": _array(state.get("event_choice_receipts", [])).duplicate(),
			"event_request_queue_count": _array(state.get("event_request_queue", [])).size(),
			"event_request_history": _array(state.get("event_request_history", [])).duplicate(true),
		},
		"event": {
			"present": not event_record.is_empty(),
			"enabled": bool(event_record.get("enabled", false)) if not event_record.is_empty() else false,
			"popup_visible": bool(popup.get("visible", false)),
			"popup_event_id": str(popup.get("event_id", "")),
			"popup_choice_ids": _array(popup.get("choice_ids", [])).duplicate(),
		},
		"live": _dict(live_assertions.get("assertions", {})).duplicate(true),
	})


func _measure_steady_prepared_frames() -> Dictionary:
	await _restore_run(initial_run_snapshot)
	await _settle(12)
	var before_state := _scenario_state()
	var before_render := _dict(_current_environment().get("scenario_render_snapshot", {}))
	var before_debug: Dictionary = app.call("debug_soak_snapshot")
	var before_fingerprint := ProbeSupport.canonical_semantic_sha256({"semantic": before_state})
	var before_render_fingerprint := ProbeSupport.canonical_semantic_sha256({"semantic": before_render})
	var before_counts := _steady_debug_counts(before_debug)
	for _index in range(60):
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		prepared_frame_samples_ms.append(_elapsed_ms(started))
		_record_performance("steady_prepared_frame", _elapsed_ms(started))
	var after_state := _scenario_state()
	var after_render := _dict(_current_environment().get("scenario_render_snapshot", {}))
	var after_debug: Dictionary = app.call("debug_soak_snapshot")
	var after_fingerprint := ProbeSupport.canonical_semantic_sha256({"semantic": after_state})
	var after_render_fingerprint := ProbeSupport.canonical_semantic_sha256({"semantic": after_render})
	var after_counts := _steady_debug_counts(after_debug)
	var unchanged := before_fingerprint == after_fingerprint \
		and before_render_fingerprint == after_render_fingerprint \
		and JSON.stringify(before_counts, "", true) == JSON.stringify(after_counts, "", true) \
		and _array(before_state.get("command_receipts", [])).size() == _array(after_state.get("command_receipts", [])).size() \
		and _array(before_state.get("fact_receipts", [])).size() == _array(after_state.get("fact_receipts", [])).size()
	if not unchanged:
		_fail("Steady prepared frames changed authoritative state, receipts, render snapshot, or reconstruction counts.")
	return {
		"unchanged": unchanged,
		"frame_count": prepared_frame_samples_ms.size(),
		"authoritative_fingerprint_before": before_fingerprint,
		"authoritative_fingerprint_after": after_fingerprint,
		"render_fingerprint_before": before_render_fingerprint,
		"render_fingerprint_after": after_render_fingerprint,
		"receipt_counts_before": {"commands": _array(before_state.get("command_receipts", [])).size(), "facts": _array(before_state.get("fact_receipts", [])).size()},
		"receipt_counts_after": {"commands": _array(after_state.get("command_receipts", [])).size(), "facts": _array(after_state.get("fact_receipts", [])).size()},
		"reconstruction_counts_before": before_counts,
		"reconstruction_counts_after": after_counts,
	}


func _steady_debug_counts(snapshot: Dictionary) -> Dictionary:
	var canvas := _dict(snapshot.get("environment_canvas", {}))
	return {
		"foundation_object_count": int(canvas.get("foundation_object_count", -1)),
		"scene_object_index_count": int(canvas.get("scene_object_index_count", -1)),
		"item_icon_texture_cache_size": int(canvas.get("item_icon_texture_cache_size", -1)),
		"icon_sprite_texture_cache_size": int(canvas.get("icon_sprite_texture_cache_size", -1)),
		"game_module_cache_size": int(snapshot.get("game_module_cache_size", -1)),
		"signal_connection_counts": _dict(snapshot.get("signal_connection_counts", {})).duplicate(true),
	}


func _finish_probe_report(steady_frame: Dictionary) -> void:
	var platform := "Web" if OS.has_feature("web") else "Windows"
	var named_rows := _performance_row_summaries()
	var missing_rows: Array = []
	for row_id in ProbeSupport.REQUIRED_PERFORMANCE_ROWS:
		if int(_dict(named_rows.get(row_id, {})).get("count", 0)) <= 0:
			missing_rows.append(row_id)
	var report := {
		"schema": "env06_6_scenario_sequence_probe_v1",
		"ok": failures.is_empty(),
		"platform": platform,
		"scenario_id": ProbeSupport.SCENARIO_ID,
		"seed": ProbeSupport.PROOF_SEED,
		"semantic": {"capture_ids": ProbeSupport.EXPECTED_CAPTURE_IDS, "outcomes": ProbeSupport.EXPECTED_OUTCOMES, "checkpoints": semantic_checkpoints},
		"performance": {
			"budgets": ProbeSupport.PERFORMANCE_BUDGETS,
			"named_rows": named_rows,
			"required_rows": ProbeSupport.REQUIRED_PERFORMANCE_ROWS,
			"missing_rows": missing_rows,
			"transition": ProbeSupport.timing_summary(transition_samples_ms),
			"prepared_frame": ProbeSupport.timing_summary(prepared_frame_samples_ms),
			"failed_transitions": failed_transition_count,
			"missing_transitions": missing_rows.size(),
			"steady_frame": steady_frame,
		},
		"host": {"display_server": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name()},
		"failures": failures.duplicate(),
	}
	report["semantic_sha256"] = ProbeSupport.canonical_semantic_sha256(report)
	for failure_value in ProbeSupport.validate_probe_report(report, platform):
		if not failures.has(str(failure_value)):
			_fail(str(failure_value))
	report["failures"] = failures.duplicate()
	report["ok"] = failures.is_empty()
	_write_report_if_native(report, "probe_report.json")
	_finish(report)


func _finish_visual_manifest(steady_frame: Dictionary) -> void:
	_clear_isolated_save_slot()
	var manifest := {
		"schema": "env06_6_scenario_sequence_capture_manifest_v1",
		"passed": failures.is_empty(),
		"scenario_id": ProbeSupport.SCENARIO_ID,
		"seed": ProbeSupport.PROOF_SEED,
		"production_scene": "res://scenes/main.tscn",
		"capture_ids": ProbeSupport.EXPECTED_CAPTURE_IDS,
		"captures": capture_records,
		"windowed": DisplayServer.get_name() != "headless",
		"renderer": RenderingServer.get_video_adapter_name(),
		"steady_frame": steady_frame,
		"failures": failures.duplicate(),
	}
	if DisplayServer.get_name() == "headless":
		_fail("Visual capture did not use an actual windowed display server.")
	for failure_value in ProbeSupport.validate_capture_manifest(manifest):
		if not failures.has(str(failure_value)):
			_fail(str(failure_value))
	manifest["failures"] = failures.duplicate()
	manifest["passed"] = failures.is_empty()
	_write_json(_absolute_output_dir().path_join("manifest.json"), manifest)
	print("ENV06_6_SEQUENCE_CAPTURE=%s" % JSON.stringify(manifest))
	get_tree().quit(0 if failures.is_empty() else 1)


func _read_options() -> Dictionary:
	var result := {"mode": "probe", "out": "res://.tmp/env06_6/scenario_sequence_probe"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			result["mode"] = argument.trim_prefix("--mode=").strip_edges()
		elif argument.begins_with("--out="):
			result["out"] = argument.trim_prefix("--out=").strip_edges()
	if OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("window.location.search", true)).trim_prefix("?")
		for pair in search.split("&", false):
			var separator := pair.find("=")
			if separator <= 0:
				continue
			var key := pair.substr(0, separator).uri_decode()
			var value := pair.substr(separator + 1).uri_decode()
			if key == "mode" or key == "out":
				result[key] = value
	return result


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish(report: Dictionary) -> void:
	_clear_isolated_save_slot()
	report["failures"] = failures.duplicate()
	report["ok"] = failures.is_empty()
	print("ENV06_6_SEQUENCE_PROBE=%s" % JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _projection() -> Dictionary:
	return run_state.call("scenario_sequence_projection") if run_state != null else {}


func _current_environment() -> Dictionary:
	return run_state.get("current_environment") if run_state != null else {}


func _scenario_state() -> Dictionary:
	return _dict(_current_environment().get("scenario_sequence_state", {})).duplicate(true)


func _environment_view() -> Dictionary:
	if app == null:
		return {}
	var canvas: Variant = app.get("environment_canvas")
	return canvas.call("current_view_snapshot") if canvas != null else {}


func _interactable_records() -> Array:
	if app == null:
		return []
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	return _array(snapshot.get("interactable_objects", []))


func _event_interactable_record() -> Dictionary:
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if str(record.get("object_type", "")) == "event" and str(record.get("source_id", "")) == ProbeSupport.EVENT_ID:
			return record
	return {}


func _first_scenario_object_id() -> String:
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if str(record.get("object_type", "")) == "scenario" and bool(record.get("enabled", true)):
			return str(record.get("object_id", ""))
	return ""


func _live_hit_rects() -> Array:
	var result: Array = []
	var canvas: Variant = app.get("environment_canvas") if app != null else null
	if canvas == null:
		return result
	var view: Dictionary = canvas.call("current_view_snapshot")
	for object_value in _array(view.get("objects", [])):
		var object_data := _dict(object_value)
		if not bool(object_data.get("interactive", true)) or bool(object_data.get("disabled", false)):
			continue
		var object_id := str(object_data.get("id", ""))
		var interaction_rect: Variant = canvas.call("global_rect_for_object", object_id)
		if typeof(interaction_rect) == TYPE_RECT2 and (interaction_rect as Rect2).has_area():
			result.append(interaction_rect)
	return result


func _enabled_scenario_hit_rects() -> Array:
	var result: Array = []
	var canvas: Variant = app.get("environment_canvas") if app != null else null
	if canvas == null:
		return result
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if str(record.get("object_type", "")) != "scenario" or not bool(record.get("enabled", true)) or not bool(record.get("interactive", true)):
			continue
		var rect: Variant = canvas.call("global_rect_for_object", str(record.get("object_id", "")))
		if typeof(rect) == TYPE_RECT2 and (rect as Rect2).has_area():
			result.append(rect)
	return result


func _obstruction_target_rects() -> Array:
	var result: Array = []
	var canvas: Variant = app.get("environment_canvas") if app != null else null
	if canvas == null:
		return result
	var scenario_added := false
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if not bool(record.get("enabled", true)) or not bool(record.get("interactive", true)):
			continue
		var is_scenario := str(record.get("object_type", "")) == "scenario"
		var is_safe_exit := bool(record.get("safe_exit", false)) and _has_enabled_inline_action(record)
		if (not is_scenario or scenario_added) and not is_safe_exit:
			continue
		var rect: Variant = canvas.call("global_rect_for_object", str(record.get("object_id", "")))
		if typeof(rect) != TYPE_RECT2 or not (rect as Rect2).has_area():
			continue
		result.append(rect)
		if is_scenario:
			scenario_added = true
	return result


func _has_enabled_inline_action(record: Dictionary) -> bool:
	for action_value in _array(record.get("inline_actions", [])):
		if bool(_dict(action_value).get("enabled", true)):
			return true
	return false


func _primary_enabled_scenario_target() -> Dictionary:
	var canvas: Variant = app.get("environment_canvas") if app != null else null
	if canvas == null:
		return {}
	var scale := maxf(0.001, float(_environment_view().get("board_scale", 1.0)))
	for record_value in _interactable_records():
		var record := _dict(record_value)
		if str(record.get("object_type", "")) != "scenario" or not bool(record.get("enabled", true)) or not bool(record.get("interactive", true)):
			continue
		var rect_value: Variant = canvas.call("global_rect_for_object", str(record.get("object_id", "")))
		if typeof(rect_value) == TYPE_RECT2 and (rect_value as Rect2).has_area():
			return {
				"object_id": str(record.get("object_id", "")),
				"command_id": str(record.get("scenario_command_id", record.get("confirm_action_id", ""))),
				"logical_size": (rect_value as Rect2).size / scale,
			}
	return {}


func _reserved_overlap_count(reserved: Rect2, hit_rects: Array) -> int:
	if not reserved.has_area():
		return 0
	var count := 0
	for global_rect_value in _global_hit_rects(hit_rects):
		var global_rect: Rect2 = global_rect_value
		if global_rect.intersects(reserved) and global_rect.intersection(reserved).get_area() > 0.5:
			count += 1
	return count


func _global_hit_rects(hit_rects: Array) -> Array:
	return hit_rects.duplicate()


func _install_overlay(kind: String) -> void:
	active_overlay = EvidenceOverlay.new()
	active_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_overlay.evidence_rects = _global_hit_rects(_obstruction_target_rects() if kind == "obstruction" else _live_hit_rects())
	active_overlay.reserved_rect = _rect(_environment_view().get("reserved_overlay_global_rect", Rect2())) if kind == "obstruction" else Rect2()
	active_overlay.label = "LIVE OBSTRUCTION / TARGET GEOMETRY" if kind == "obstruction" else "LIVE INTERACTION TARGETS (44 MINIMUM)"
	add_child(active_overlay)
	active_overlay.queue_redraw()


func _clear_evidence_overlay() -> void:
	var talk: Variant = app.get("talk_dock") if app != null else null
	if talk != null and str(_dict(talk.call("current_snapshot")).get("event_id", "")) == "env06_6_obstruction_evidence":
		talk.call("clear_entry")
	if active_overlay == null:
		return
	active_overlay.queue_free()
	active_overlay = null


func _absolute_output_dir() -> String:
	var requested := str(options.get("out", "res://.tmp/env06_6/scenario_sequence_probe"))
	return ProjectSettings.globalize_path(requested) if requested.begins_with("res://") or requested.begins_with("user://") else requested


func _write_report_if_native(report: Dictionary, file_name: String) -> void:
	if OS.has_feature("web"):
		return
	var absolute_dir := _absolute_output_dir()
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	_write_json(absolute_dir.path_join(file_name), report)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write evidence JSON: %s" % path)
		return
	file.store_string(JSON.stringify(value, "\t", true, true))
	file.close()


func _save_run_snapshot() -> Dictionary:
	var snapshot: Dictionary = run_state.call("to_dict")
	return snapshot


func _measure_production_save_load() -> void:
	var service: Variant = app.get("save_service")
	if service == null:
		_fail("Production SaveService is unavailable to the evidence probe.")
		return
	var slot_id := "autosave"
	var before := ProbeSupport.canonical_semantic_sha256({"semantic": _scenario_state()})
	var save_started := Time.get_ticks_usec()
	var save_error := int(service.call("save_run", run_state, slot_id))
	_record_performance("save", _elapsed_ms(save_started))
	if save_error != OK:
		_fail("Production SaveService could not write the isolated evidence slot.")
		return
	var raw_load: Variant = service.call("load_run", slot_id)
	if raw_load == null:
		_fail("Production SaveService could not load the isolated evidence slot.")
		return
	var load_started := Time.get_ticks_usec()
	app.call("load_foundation_run")
	var load_elapsed := _elapsed_ms(load_started)
	run_state = app.get("run_state")
	_record_performance("load_rebuild", load_elapsed)
	if run_state == null or ProbeSupport.canonical_semantic_sha256({"semantic": _scenario_state()}) != before:
		_fail("FoundationMain production load/rebuild changed delivery-day authority.")
	_clear_isolated_save_slot()


func _clear_isolated_save_slot() -> void:
	var service: Variant = app.get("save_service") if app != null else null
	if service == null:
		return
	var clear_error := int(service.call("clear_run", "autosave"))
	if clear_error != OK:
		_fail("Production SaveService could not clear the isolated evidence slot.")


func _record_performance(row_id: String, elapsed_ms: float) -> void:
	var rows := _array(performance_rows.get(row_id, []))
	rows.append(maxf(0.001, elapsed_ms))
	performance_rows[row_id] = rows


func _performance_row_summaries() -> Dictionary:
	var result: Dictionary = {}
	for row_id_value in performance_rows.keys():
		var row_id := str(row_id_value)
		result[row_id] = ProbeSupport.timing_summary(performance_rows.get(row_id, []))
	return result


func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await get_tree().process_frame


func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))), Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0))))


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
