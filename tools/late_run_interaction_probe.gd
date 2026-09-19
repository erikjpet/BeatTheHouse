extends SceneTree

# Read-only acceptance probe for the largest persisted run fixture. It catches
# regressions where routine UI refreshes or route scouting scale with historical
# receipts, visited room payloads, or the complete map.

const MainScene := preload("res://scenes/main.tscn")
const EnvironmentInteractionViewModel := preload("res://scripts/ui/environment_interaction_view_model.gd")
const FIXTURE_SLOT := "pathological_continue_save_probe_copy"
const MAX_WARM_FULL_REFRESH_AVG_MS := 100.0
const MAX_SELECTED_SCOUT_PREVIEW_AVG_MS := 40.0


func _init() -> void:
	call_deferred("_run")


func _average_ms(callable: Callable, iterations: int) -> float:
	var started := Time.get_ticks_usec()
	for _index in range(iterations):
		callable.call()
	return (float(Time.get_ticks_usec() - started) / 1000.0) / float(maxi(1, iterations))


func _stage_ms(callable: Callable, iterations: int = 4) -> float:
	return _average_ms(callable, iterations)


func _refresh_stage_timings(host) -> Dictionary:
	# Profile the stable read/presentation stages independently after the complete
	# warm refresh. This keeps production refreshes free of diagnostic branches
	# while making late-run regressions attributable instead of reporting one sum.
	var environment_snapshot: Dictionary = host._environment_view_snapshot()
	var recent_result: Dictionary = host._recent_result_snapshot()
	var archetype: Dictionary = host._current_environment_archetype()
	var snapshot_options := {
		"recent_result": recent_result,
		"drunk_effect_mode": host._drunk_effect_mode(),
		"reduce_motion": host._reduce_motion_enabled(),
		"high_contrast": host._high_contrast_enabled(),
		"accessibility": host.current_accessibility_snapshot(),
		"travel_choices": host._travel_choice_view_list(),
		"selected_travel_target_id": host.selected_travel_target_id,
		"selected_travel_label": host.selected_travel_label,
		"venue_open_status": host._environment_open_status(archetype),
		"venue_open_status_text": "",
		"world_map_overlay_visible": false,
		"world_map": {},
		"event_options": host._eligible_event_option_view_list(),
		"item_offers": host._item_offer_view_list(),
		"inventory_items": host._inventory_item_view_list(),
		"shopkeeper_available": host._shopkeeper_available(),
		"service_options": host._service_hook_view_list(),
		"lender_options": host._lender_hook_view_list(),
		"interactable_objects": host._interactable_object_view_list(),
		"outcome_object_id": host._outcome_object_id(recent_result),
		"outcome_message": host._outcome_message(recent_result),
	}
	var timings := {
		"resume_world_outcomes": _stage_ms(func(): host._resume_pending_world_sequence_outcomes()),
		"terminal_state": _stage_ms(func(): host._evaluate_run_terminal_state()),
		"scenario_transitions": _stage_ms(func(): host._consume_scenario_transitions()),
		"environment_screen": _stage_ms(func(): host._render_environment_screen()),
		"world_header": _stage_ms(func(): host._refresh_world_header()),
		"hud_model": _stage_ms(func(): host._run_status_hud_model()),
		"focus_layout": _stage_ms(func(): host._apply_focus_layout()),
		"result_feedback": _stage_ms(func(): host._refresh_environment_result_feedback()),
		"run_report": _stage_ms(func(): host._render_run_report()),
		"result_panel": _stage_ms(func(): host._render_result_panel()),
		"foundation_snapshots": _stage_ms(func(): host._render_foundation_snapshots()),
		"environment_snapshot_model": _stage_ms(func(): host._environment_view_snapshot()),
		"environment_snapshot_projection": _stage_ms(func(): EnvironmentInteractionViewModel.environment_snapshot(host.run_state, snapshot_options)),
		"environment_snapshot_signature": _stage_ms(func(): host._environment_snapshot_signature()),
		"recent_result": _stage_ms(func(): host._recent_result_snapshot()),
		"travel_choices": _stage_ms(func(): host._travel_choice_view_list()),
		"event_options": _stage_ms(func(): host._eligible_event_option_view_list()),
		"item_offers": _stage_ms(func(): host._item_offer_view_list()),
		"inventory_items": _stage_ms(func(): host._inventory_item_view_list()),
		"service_options": _stage_ms(func(): host._service_hook_view_list()),
		"lender_options": _stage_ms(func(): host._lender_hook_view_list()),
		"interactable_objects": _stage_ms(func(): host._interactable_object_view_list()),
		"talk_dock": _stage_ms(func(): host._refresh_talk_dock()),
		"world_map": _stage_ms(func(): host._refresh_world_map_overlay()),
		"music": _stage_ms(func(): host._update_procedural_music()),
		"coach": _stage_ms(func(): host._refresh_coach_at_boundary()),
	}
	if host.environment_canvas != null:
		timings["environment_canvas_apply"] = _stage_ms(func(): host.environment_canvas.render_owned_environment_snapshot(environment_snapshot))
	if host.run_action_service != null:
		var selected_item_id: String = host.run_action_service.selected_active_item_id()
		for item_value in host.run_state.inventory:
			var item_id: String = str(item_value.get("id", "")) if typeof(item_value) == TYPE_DICTIONARY else str(item_value)
			if not item_id.is_empty():
				timings["inventory_detail:%s" % item_id] = _stage_ms(func(): host.run_action_service.inventory_item_detail(item_id, selected_item_id))
	return timings


func _run() -> void:
	var failures: Array = []
	var host = MainScene.instantiate()
	# Configure the fixture before _ready so this probe never observes or writes
	# the player's Continue slot. Practice mode disables every autosave mutation.
	host.autosave_slot_id = FIXTURE_SLOT
	host.dev_game_test_mode = true
	root.add_child(host)
	await process_frame
	host.load_foundation_run()
	host.pending_autosave = false
	if host.run_state == null:
		failures.append("Pathological late-run fixture could not be loaded.")
	else:
		host._refresh()
		var warm_refresh_avg_ms := _average_ms(func(): host._refresh(), 8)
		var refresh_stage_timings := _refresh_stage_timings(host)
		var target_ids: Array = host._travel_target_ids()
		var selected_scout_avg_ms := 0.0
		var selected_scout_cold_ms := 0.0
		var selected_scout_warm_avg_ms := 0.0
		var preview_environment_timing: Dictionary = {}
		if not target_ids.is_empty():
			host.selected_travel_target_id = str(target_ids[0])
			host._invalidate_travel_view_cache()
			host.generator.set_world_environment_timing_enabled(true)
			var scout_started := Time.get_ticks_usec()
			host._travel_choice_view_list()
			selected_scout_cold_ms = float(Time.get_ticks_usec() - scout_started) / 1000.0
			preview_environment_timing = host.generator.preview_environment_timing_snapshot()
			selected_scout_warm_avg_ms = _average_ms(func(): host._travel_choice_view_list(), 3)
			selected_scout_avg_ms = (selected_scout_cold_ms + selected_scout_warm_avg_ms * 3.0) / 4.0
		if warm_refresh_avg_ms > MAX_WARM_FULL_REFRESH_AVG_MS:
			failures.append("Warm late-run refresh averaged %.1f ms (limit %.1f ms)." % [warm_refresh_avg_ms, MAX_WARM_FULL_REFRESH_AVG_MS])
		if selected_scout_avg_ms > MAX_SELECTED_SCOUT_PREVIEW_AVG_MS:
			failures.append("Selected late-run scout preview averaged %.1f ms (limit %.1f ms)." % [selected_scout_avg_ms, MAX_SELECTED_SCOUT_PREVIEW_AVG_MS])
		print("LATE_RUN_INTERACTION_PROBE refresh_avg_ms=%.3f selected_scout_avg_ms=%.3f selected_scout_cold_ms=%.3f selected_scout_warm_avg_ms=%.3f save_chars=%d story=%d heat=%d failures=%d" % [
			warm_refresh_avg_ms,
			selected_scout_avg_ms,
			selected_scout_cold_ms,
			selected_scout_warm_avg_ms,
			JSON.stringify(host.run_state.to_save_snapshot()).length(),
			host.run_state.story_log.size(),
			host.run_state.heat_history.size(),
			failures.size(),
		])
		print("LATE_RUN_INTERACTION_DETAIL target_count=%d preview_environment_timing=%s" % [target_ids.size(), JSON.stringify(preview_environment_timing)])
		print("LATE_RUN_REFRESH_STAGE_DETAIL timings_ms=%s" % JSON.stringify(refresh_stage_timings))
	host.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(str(failure))
	quit(1 if not failures.is_empty() else 0)
