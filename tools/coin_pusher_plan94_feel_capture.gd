extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Renderer := preload("res://scripts/games/coin_pusher/coin_pusher_renderer.gd")
const LiveSession := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")

const CAPTURE_SIZE := Vector2i(1280, 720)
const VARIATIONS := ["quarter_falls", "jackpot_ridge", "vault_drop"]
const REQUIRED_SCENES := ["played_in_opening", "upper_row_join", "delivery_descent", "ratchet_three_cycles", "stack_nestle_topple", "skill_stop_bank_release", "rapid_drop_pile", "tray_growth_collect", "gutter_visible_fall"]

var app: Control
var canvas: Control
var game: GameModule
var library: ContentLibrary
var active_run_state: RunState
var active_environment: Dictionary = {}
var active_machine: Dictionary = {}
var production_clock_msec := 0
var out_dir := "res://.tmp/coin_pusher_plan94_feel"
var machine_records: Array = []
var failed := false
var minimum_viewport_verified := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	root.size = CAPTURE_SIZE
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_plan94_feel_%d" % Time.get_ticks_usec())
	root.add_child(app)
	await _frames(4)
	var visible_size := root.get_visible_rect().size
	minimum_viewport_verified = visible_size.x >= CAPTURE_SIZE.x and visible_size.y >= CAPTURE_SIZE.y
	if not minimum_viewport_verified:
		_fail("Plan 9.4 capture viewport is below 1280x720: %s." % str(visible_size))
	app.call("start_game_test_session", "coin_pusher")
	await _frames(8)
	game = app.get("current_game") as GameModule
	library = app.get("library") as ContentLibrary
	canvas = app.get("game_surface_canvas") as Control
	if game == null or canvas == null or library == null:
		_fail("Production Coin Pusher surface did not open.")
		_finish()
		return
	app.set_process(false)
	for variation_id in VARIATIONS:
		await _capture_machine(variation_id)
	_write_manifest()
	_finish()


func _capture_machine(variation_id: String) -> void:
	if not _enter_production_variation(variation_id):
		_fail("Production environment entry failed for %s." % variation_id)
		return
	var definition: Dictionary = game.call("_machine_definition", variation_id)
	if definition.is_empty():
		_fail("Missing production definition for %s." % variation_id)
		return
	var scenes: Array = []
	scenes.append(await _capture_played_in_opening(variation_id, definition))
	scenes.append(await _capture_upper_row(variation_id, definition))
	scenes.append(await _capture_delivery(variation_id, definition))
	scenes.append(await _capture_ratchet(variation_id, definition))
	scenes.append(await _capture_nestle_topple(variation_id, definition))
	scenes.append(await _capture_skill_stop(variation_id, definition))
	scenes.append(await _capture_rapid_drop_pile(variation_id, definition))
	scenes.append(await _capture_tray(variation_id, definition))
	scenes.append(await _capture_gutter_fall(variation_id, definition))
	var context := _machine_context(variation_id, definition)
	var complete := scenes.size() == REQUIRED_SCENES.size()
	for scene in scenes:
		complete = complete and bool((scene as Dictionary).get("passed", false))
	machine_records.append({"variation_id": variation_id, "context": context, "scenes": scenes, "passed": complete})
	if not complete:
		_fail("%s did not produce every plan 9.4 feel scene." % variation_id)


func _capture_played_in_opening(variation_id: String, definition: Dictionary) -> Dictionary:
	var state: Dictionary = (active_machine.get("simulation", {}) as Dictionary).duplicate(true)
	var initial := _record(state)
	var opening_count := (state.get("bodies", []) as Array).size()
	var initial_upper := _elevated_coin_count(state, definition)
	var passive_tray := (state.get("tray_ledger", []) as Array).size()
	var per_play: Array = []
	var total_collected := 0
	for play_index in range(5):
		Solver.add_coin(state, _rng("plan94:%s:opening-drop:%d" % [variation_id, play_index]), _policy_x(definition, play_index), 1, {"opening_capture": true})
		Solver.step_ticks(state, {"motor_enabled": true}, 360)
		var collected := Solver.collect_tray(state)
		var count := int(collected.get("count", 0))
		per_play.append(count)
		total_collected += count
	var final_record := _record(state)
	var final_upper := _elevated_coin_count(state, definition)
	var file := "%s_played_in_opening.png" % variation_id
	var reduced_file := "%s_played_in_opening_reduced.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, final_record], false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, [initial, final_record], true)
	var passed: bool = opening_count >= 148 and opening_count <= 165 and passive_tray == 0 and int(per_play.max()) <= 6 and total_collected <= 10 and initial_upper >= 12 and final_upper >= 6 and saved and reduced_saved
	return {"id": "played_in_opening", "passed": passed, "files": [file, reduced_file], "opening_body_count": opening_count, "passive_tray_count": passive_tray, "first_five_payout_counts": per_play, "first_five_total": total_collected, "initial_elevated_coins": initial_upper, "final_elevated_coins": final_upper}


func _elevated_coin_count(state: Dictionary, definition: Dictionary) -> int:
	var geometry: Dictionary = definition.get("geometry", {}) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}
	var face := int(state.get("face_y", geometry.get("face_extended_y", 43000)))
	var count := 0
	for body_value in state.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		if str(body.get("kind", "")) != "coin":
			continue
		var surface_z := int(geometry.get("platform_top_z", 3600)) if int(body.get("y", 0)) >= face else int(geometry.get("deck_z", 0))
		if int(body.get("z", 0)) >= surface_z + int(body.get("height", 950)) - 100:
			count += 1
	return count


func _capture_upper_row(variation_id: String, definition: Dictionary) -> Dictionary:
	var period := maxi(1, int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
	var opening_snapshot := _production_opening_snapshot()
	LiveSession.advance(active_machine, production_clock_msec)
	var production_entry_machine := active_machine.duplicate(true)
	var state := _restore_production_entry(production_entry_machine)
	if state.is_empty() or opening_snapshot.is_empty():
		return {"id": "upper_row_join", "passed": false, "files": [], "reason": "production_opening_restore_failed"}
	var before_views := Solver.body_views(state)
	var before_record := _record(state)
	var branch_session_identity := _upper_row_session_identity()
	var idle_before := _upper_row_control_digest(state)
	var bankroll_before_idle := active_run_state.bankroll
	var story_before_idle := active_run_state.story_log_entry_count()
	var idle_events: Array = []
	var idle_exact_ticks := true
	for _tick in range(period):
		var idle_step := _advance_production_exact_tick()
		idle_exact_ticks = idle_exact_ticks and bool(idle_step.get("exact_one_tick", false))
		idle_events.append_array(idle_step.get("events", []))
	var idle_after := _upper_row_control_digest(state)
	var idle_record := _record(state)
	var idle_unchanged := idle_before == idle_after \
		and idle_events.is_empty() \
		and int(state.get("motor_rate_fp", -1)) == 0 \
		and active_run_state.bankroll == bankroll_before_idle \
		and active_run_state.story_log_entry_count() == story_before_idle
	var idle_file := "%s_upper_row_idle_control.png" % variation_id
	var idle_saved := await _save_record_strip(idle_file, variation_id, definition, [before_record, idle_record], false)

	state = _restore_production_entry(production_entry_machine)
	if state.is_empty():
		return {"id": "upper_row_join", "passed": false, "files": [idle_file], "reason": "production_drop_restore_failed", "idle_control_passed": idle_unchanged and idle_exact_ticks and idle_saved}
	var restored_views := Solver.body_views(state)
	var restored_session_identity := _upper_row_session_identity()
	var baseline_reproduced := restored_views == before_views \
		and restored_session_identity == branch_session_identity \
		and _sha256(_production_opening_snapshot()) == _sha256(opening_snapshot)
	var control_trace := _run_upper_row_control_trace(variation_id, state)
	var preexisting_ids := _body_id_set(Solver.body_views(state))
	var stimulus_before := _record(state)
	var queue_before := (active_machine.get("drop_queue", []) as Array).size()
	var accepted_before := int(state.get("accepted_inserts", 0))
	var bankroll_before_drop := active_run_state.bankroll
	var story_before_drop := active_run_state.story_log_entry_count()
	var drop_command := game.surface_action_command("coin_pusher_drop", 0, false, {}, active_run_state, active_environment)
	var paid_drop_cost := int(drop_command.get("set_stake", 0))
	var drop_result := game.resolve_with_context(str(drop_command.get("action_id", "")), paid_drop_cost, active_run_state, active_environment, _rng("plan94:%s:upper:paid" % variation_id), {})
	GameModule.apply_result(active_run_state, drop_result)
	# Variation features synchronize before enqueue. Read the next solver ID only
	# after the production resolve so the tracked ID is the committed quarter.
	var body_id := "body_%05d" % int(state.get("next_body_id", 1))
	var selected_nozzle_id := str(active_machine.get("selected_nozzle_id", ""))
	var queue_after := (active_machine.get("drop_queue", []) as Array).size()
	var drop_committed := bool(drop_command.get("handled", false)) \
		and bool(drop_command.get("direct_resolve", false)) \
		and paid_drop_cost > 0 \
		and active_run_state.bankroll == bankroll_before_drop - paid_drop_cost \
		and active_run_state.story_log_entry_count() == story_before_drop + 1 \
		and queue_after == queue_before + 1 \
		and bool(active_machine.get("motor_started", false))
	var first_support_event := {}
	var landing_tick := -1
	var landing_record := {}
	var landing_neighbor_views: Array = []
	var landing_neighbor_diagnostics: Array = []
	var landing_phase_fp := -1
	var landing_phase_tick := -1
	var landing_face_y := -1
	var landing_cycle_serial := -1
	var terminal_before_support := false
	var emitted := false
	var exact_live_ticks := true
	var pre_landing_events: Array = []
	for _tick in range(1200):
		var result := _advance_production_exact_tick()
		exact_live_ticks = exact_live_ticks and bool(result.get("exact_one_tick", false))
		emitted = emitted or not _body(state, body_id).is_empty()
		for event_value in result.get("events", []):
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if str(event.get("body_id", "")) == body_id:
				pre_landing_events.append(event.duplicate(true))
				if str(event.get("kind", "")) in ["tray", "gutter", "plinko_cup"] and first_support_event.is_empty():
					terminal_before_support = true
			if str(event.get("body_id", "")) == body_id and bool(event.get("first_support", false)):
				first_support_event = event.duplicate(true)
				landing_tick = int(state.get("tick", -1))
				landing_phase_fp = int(state.get("phase_fp", -1))
				landing_phase_tick = landing_phase_fp / Solver.FP
				landing_face_y = int(state.get("face_y", -1))
				landing_cycle_serial = int(state.get("stroke_cycle_serial", -1))
				landing_record = _record(state, [], result.get("events", []))
				landing_neighbor_views = _upper_row_local_neighbors(Solver.body_views(state), body_id, preexisting_ids)
				landing_neighbor_diagnostics = _upper_row_neighbor_diagnostics(Solver.body_views(state), body_id, preexisting_ids)
		if not first_support_event.is_empty() or terminal_before_support:
			break
	var landing_y := _body_y_for_ids(Solver.body_views(state), _body_ids(landing_neighbor_views))
	var post_landing_events: Array = []
	var release_control := {"required": bool(state.get("skill_stop_engaged", false)), "handled": true}
	if not first_support_event.is_empty():
		if bool(state.get("skill_stop_engaged", false)):
			var release_command := game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, active_run_state, active_environment)
			release_control = {
				"required": true,
				"handled": bool(release_command.get("handled", false)),
				"released": not bool(state.get("skill_stop_engaged", true)),
			}
		for _tick in range(period * 4):
			var result := _advance_production_exact_tick()
			exact_live_ticks = exact_live_ticks and bool(result.get("exact_one_tick", false))
			post_landing_events.append_array(result.get("events", []))
			if int(state.get("stroke_cycle_serial", -1)) > landing_cycle_serial \
					and int(state.get("phase_fp", -2)) / Solver.FP == landing_phase_tick \
					and int(state.get("face_y", -2)) == landing_face_y:
				break
	var final_views := Solver.body_views(state)
	var final_phase_fp := int(state.get("phase_fp", -2))
	var final_phase_tick := final_phase_fp / Solver.FP
	var final_face_y := int(state.get("face_y", -2))
	# The production motor ramps through fractional fixed-point rates after the
	# skill stop. Solver geometry is evaluated at whole phase ticks, so match the
	# exact authored phase tick, face position, and a later cycle rather than an
	# unreachable pre-ramp fractional remainder.
	var phase_matched := landing_phase_tick >= 0 and final_phase_tick == landing_phase_tick \
		and final_face_y == landing_face_y \
		and int(state.get("stroke_cycle_serial", -1)) > landing_cycle_serial
	var final_y := _body_y_for_ids(final_views, _body_ids(landing_neighbor_views))
	var advanced_ids: Array = []
	var neighbor_forward_deltas := {}
	var deposit_ids := {}
	for event_value in post_landing_events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == "platform_deposit":
			deposit_ids[str((event_value as Dictionary).get("body_id", ""))] = true
	for neighbor_id in landing_y:
		var id := str(neighbor_id)
		var delta := int(landing_y[id]) - int(final_y.get(id, landing_y[id]))
		neighbor_forward_deltas[id] = delta
		if delta > 100 or deposit_ids.has(id):
			advanced_ids.append(id)
	var final_tracked := _body_from_views(final_views, body_id)
	var event_support_root := str(first_support_event.get("support_root", ""))
	var landing_tracked := _body_from_views((landing_record.get("current_views", []) as Array) if not landing_record.is_empty() else [], body_id)
	var independent_support_root := str(landing_tracked.get("support_root", ""))
	var joined_platform_row := not terminal_before_support \
		and str(first_support_event.get("kind", "")) == "impact" \
		and bool(first_support_event.get("first_support", false)) \
		and event_support_root == "platform" \
		and independent_support_root == "platform" \
		and not landing_neighbor_views.is_empty()
	var join_file := "%s_upper_row_join.png" % variation_id
	var join_saved := false
	if not landing_record.is_empty():
		join_saved = await _save_record_strip(join_file, variation_id, definition, [stimulus_before, landing_record, _record(state)], false)
	var passed := idle_unchanged and idle_exact_ticks and idle_saved \
		and baseline_reproduced and bool(control_trace.get("passed", false)) and drop_committed and emitted \
		and int(state.get("accepted_inserts", 0)) == accepted_before + 1 \
		and exact_live_ticks and joined_platform_row and phase_matched and bool(release_control.get("handled", false)) and bool(release_control.get("released", true)) \
		and not advanced_ids.is_empty() \
		and not final_tracked.is_empty() and str(final_tracked.get("support_root", "")) == "platform" \
		and join_saved
	return {
		"id": "upper_row_join",
		"passed": passed,
		"files": [join_file, idle_file],
		"opening_snapshot_sha256": _sha256(opening_snapshot),
		"opening_body_count": before_views.size(),
		"stroke_period_ticks": period,
		"idle_control_passed": idle_unchanged and idle_exact_ticks and idle_saved,
		"idle_control": {"start": idle_before, "end": idle_after, "events": idle_events, "exact_ticks": idle_exact_ticks, "file_saved": idle_saved},
		"baseline_reproduced": baseline_reproduced,
		"baseline_session_identity": branch_session_identity,
		"restored_session_identity": restored_session_identity,
		"fixed_control_trace": control_trace,
		"selected_nozzle_id": selected_nozzle_id,
		"paid_drop_cost": paid_drop_cost,
		"drop_committed": drop_committed,
		"queue_before": queue_before,
		"queue_after": queue_after,
		"tracked_body_id": body_id,
		"drop_emitted": emitted,
		"landing_tick": landing_tick,
		"landing_phase_fp": landing_phase_fp,
		"landing_phase_tick": landing_phase_tick,
		"landing_face_y": landing_face_y,
		"landing_cycle_serial": landing_cycle_serial,
		"final_phase_fp": final_phase_fp,
		"final_phase_tick": final_phase_tick,
		"final_face_y": final_face_y,
		"phase_matched": phase_matched,
		"release_control": release_control,
		"terminal_before_support": terminal_before_support,
		"tracked_pre_landing_events": pre_landing_events,
		"first_support_event": first_support_event,
		"event_support_root": event_support_root,
		"independent_support_root": independent_support_root,
		"qualified_neighbor_views": landing_neighbor_views,
		"nearest_preexisting_platform_coins": landing_neighbor_diagnostics,
		"neighbor_y_at_first_support": landing_y,
		"neighbor_y_after_phase_matched_cycle": final_y,
		"neighbor_forward_deltas": neighbor_forward_deltas,
		"advanced_local_neighbor_ids": advanced_ids,
		"post_landing_events": post_landing_events,
		"tracked_final_body": final_tracked,
		"exact_live_ticks": exact_live_ticks,
		"production_input_trace_count": ((active_machine.get("live_session", {}) as Dictionary).get("input_trace", []) as Array).size(),
		"production_liveness_ticks": int((active_machine.get("live_session", {}) as Dictionary).get("liveness_ticks", 0)),
		"join_file_saved": join_saved,
	}


func _run_upper_row_control_trace(variation_id: String, state: Dictionary) -> Dictionary:
	const PRIMING_DROP_COUNT := 1
	var control := {"actions": [], "handled": true, "selected_nozzle_id": str(active_machine.get("selected_nozzle_id", ""))}
	if variation_id == "jackpot_ridge":
		var command := game.surface_action_command("coin_pusher_hole_2", 0, false, {}, active_run_state, active_environment)
		control = {
			"actions": ["coin_pusher_hole_2"],
			"handled": bool(command.get("handled", false)),
			"environment_changed": bool(command.get("environment_changed", false)),
			"selected_nozzle_id": str(active_machine.get("selected_nozzle_id", "")),
		}
	elif variation_id == "quarter_falls":
		var commands: Array = []
		for _step in range(2):
			commands.append(game.surface_action_command("coin_pusher_carriage_right", 0, false, {}, active_run_state, active_environment))
		control = {
			"actions": ["coin_pusher_carriage_right", "coin_pusher_carriage_right"],
			"handled": commands.all(func(value: Variant) -> bool: return typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("handled", false))),
			"carriage_x": int(state.get("carriage_x", -1)),
			"selected_nozzle_id": str(active_machine.get("selected_nozzle_id", "")),
		}
	else:
		control["carriage_x"] = int(state.get("carriage_x", -1))
		control["reason"] = "unchanged_production_entry_rail"
	var control_passed := bool(control.get("handled", false)) \
		and ((variation_id == "jackpot_ridge" and str(control.get("selected_nozzle_id", "")) == "ridge_right") \
			or (variation_id != "jackpot_ridge" and not str(control.get("selected_nozzle_id", "")).is_empty()))
	var priming_records: Array = []
	var trace_passed := control_passed
	for prime_index in range(PRIMING_DROP_COUNT):
		var queue_before := (active_machine.get("drop_queue", []) as Array).size()
		var bankroll_before := active_run_state.bankroll
		var story_before := active_run_state.story_log_entry_count()
		var command := game.surface_action_command("coin_pusher_drop", 0, false, {}, active_run_state, active_environment)
		var cost := int(command.get("set_stake", 0))
		var result := game.resolve_with_context(str(command.get("action_id", "")), cost, active_run_state, active_environment, _rng("plan94:%s:upper:prime:%d" % [variation_id, prime_index]), {})
		GameModule.apply_result(active_run_state, result)
		var body_id := "body_%05d" % int(state.get("next_body_id", 1))
		var committed := bool(command.get("handled", false)) \
			and bool(command.get("direct_resolve", false)) \
			and cost > 0 \
			and queue_before == 0 \
			and (active_machine.get("drop_queue", []) as Array).size() == 1 \
			and active_run_state.bankroll == bankroll_before - cost \
			and active_run_state.story_log_entry_count() == story_before + 1
		var emitted := false
		var exact_ticks := true
		var first_support := {}
		var terminal_before_support := false
		for _tick in range(1200):
			var step := _advance_production_exact_tick()
			exact_ticks = exact_ticks and bool(step.get("exact_one_tick", false))
			emitted = emitted or not _body(state, body_id).is_empty()
			for event_value in step.get("events", []):
				if typeof(event_value) != TYPE_DICTIONARY or str((event_value as Dictionary).get("body_id", "")) != body_id:
					continue
				var event: Dictionary = event_value
				if str(event.get("kind", "")) in ["tray", "gutter", "plinko_cup"] and first_support.is_empty():
					terminal_before_support = true
				if bool(event.get("first_support", false)):
					first_support = event.duplicate(true)
			if not first_support.is_empty() or terminal_before_support:
				break
		var platform_rooted := not terminal_before_support \
			and str(first_support.get("support_root", "")) == "platform" \
			and str(_body_from_views(Solver.body_views(state), body_id).get("support_root", "")) == "platform"
		trace_passed = trace_passed and committed and emitted and exact_ticks and platform_rooted
		priming_records.append({
			"ordinal": prime_index + 1,
			"body_id": body_id,
			"committed": committed,
			"emitted": emitted,
			"exact_live_ticks": exact_ticks,
			"terminal_before_support": terminal_before_support,
			"first_support_event": first_support,
			"platform_rooted_view": str(_body_from_views(Solver.body_views(state), body_id).get("support_root", "")) == "platform",
		})
	var geometry: Dictionary = (state.get("machine_definition", {}) as Dictionary).get("geometry", {}) if typeof((state.get("machine_definition", {}) as Dictionary).get("geometry", {})) == TYPE_DICTIONARY else {}
	var rear_target_y := int(geometry.get("face_retracted_y", 61000)) - 250
	var alignment_ticks := 0
	while int(state.get("face_y", 0)) < rear_target_y and alignment_ticks < 1200:
		var alignment_step := _advance_production_exact_tick()
		trace_passed = trace_passed and bool(alignment_step.get("exact_one_tick", false))
		alignment_ticks += 1
	var stop_command := game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, active_run_state, active_environment)
	var stop_ticks := 0
	while int(state.get("motor_rate_fp", 0)) > 0 and stop_ticks < 120:
		var stop_step := _advance_production_exact_tick()
		trace_passed = trace_passed and bool(stop_step.get("exact_one_tick", false))
		stop_ticks += 1
	var aligned_stop := bool(stop_command.get("handled", false)) \
		and bool(state.get("skill_stop_engaged", false)) \
		and int(state.get("motor_rate_fp", -1)) == 0 \
		and int(state.get("face_y", 0)) >= rear_target_y
	trace_passed = trace_passed and aligned_stop
	return {
		"schema": "coin_pusher_upper_row_fixed_trace_v1",
		"trace_id": "production_entry_fixed_nozzle_rear_row_skill_stop_then_tracked_drop",
		"seed_search_count": 0,
		"control_search_count": 0,
		"control": control,
		"priming_drop_count": PRIMING_DROP_COUNT,
		"priming_drops": priming_records,
		"rear_alignment": {
			"target_face_y": rear_target_y,
			"alignment_ticks": alignment_ticks,
			"stop_ticks": stop_ticks,
			"stop_handled": bool(stop_command.get("handled", false)),
			"skill_stop_engaged": bool(state.get("skill_stop_engaged", false)),
			"motor_rate_fp": int(state.get("motor_rate_fp", -1)),
			"face_y": int(state.get("face_y", -1)),
			"passed": aligned_stop,
		},
		"passed": trace_passed,
	}


func _capture_delivery(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:delivery" % variation_id, definition, 0)
	var previous := Solver.body_views(state)
	var drop := Solver.add_coin(state, _rng("plan94:%s:delivery:drop" % variation_id), _delivery_contact_x(definition), 1)
	var body_id := str(drop.get("id", ""))
	var records: Array = [_record(state, previous, [])]
	var stage_names: Array = ["release"]
	var peg_events: Array = []
	var landing_event := {}
	var contact_z := 0
	var post_pending := false
	var mid_fall_captured := false
	for _tick in range(5000):
		previous = Solver.body_views(state)
		var result := Solver.step_ticks(state, {"motor_enabled": true}, 1)
		var events: Array = result.get("events", [])
		var first_contact_this_tick := false
		for event_value in events:
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if str(event.get("body_id", "")) != body_id:
				continue
			if str(event.get("kind", "")) == "peg_impact":
				peg_events.append(event.duplicate(true))
				if peg_events.size() == 1:
					first_contact_this_tick = true
					records.append(_record(state, previous, events))
					stage_names.append("peg_contact")
					contact_z = int(_body(state, body_id).get("z", 0))
					post_pending = true
			if str(event.get("kind", "")) == "impact" and str(event.get("support", "")) in ["platform", "body"]:
				landing_event = event.duplicate(true)
				records.append(_record(state, previous, events))
		if not peg_events.is_empty() and post_pending and not first_contact_this_tick and landing_event.is_empty():
			records.append(_record(state, previous, events))
			stage_names.append("post_bounce")
			post_pending = false
		elif not peg_events.is_empty() and not mid_fall_captured and landing_event.is_empty():
			var tracked := _body(state, body_id)
			if str(tracked.get("rest_state", "")) == "falling" and int(tracked.get("z", contact_z)) < contact_z - 1000:
				records.append(_record(state, previous, events))
				stage_names.append("mid_fall")
				mid_fall_captured = true
		if not landing_event.is_empty():
			break
	var normal_file := "%s_delivery_full_descent.png" % variation_id
	var reduced_file := "%s_delivery_full_descent_reduced.png" % variation_id
	var normal_saved := await _save_record_strip(normal_file, variation_id, definition, records, false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, records, true)
	if not landing_event.is_empty() and stage_names.size() < records.size():
		stage_names.append("landing")
	var passed := bool(drop.get("accepted", false)) and not peg_events.is_empty() and not landing_event.is_empty() and stage_names == ["release", "peg_contact", "post_bounce", "mid_fall", "landing"] and records.size() == 5 and normal_saved and reduced_saved
	var stages: Array = []
	for stage_index in range(mini(stage_names.size(), records.size())):
		stages.append({"stage": stage_names[stage_index], "tick": int((records[stage_index] as Dictionary).get("tick", -1)), "body": _body_from_views((records[stage_index] as Dictionary).get("current_views", []), body_id), "events": (records[stage_index] as Dictionary).get("events", [])})
	return {"id": "delivery_descent", "passed": passed, "files": [normal_file, reduced_file], "tracked_body_id": body_id, "stages": stages, "peg_events": peg_events, "landing_event": landing_event, "real_solver_records": records.size()}


func _capture_ratchet(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:ratchet" % variation_id, definition, 0)
	_hold_phase(state, definition, 0)
	var geometry: Dictionary = definition.get("geometry", {})
	var top_z := int(geometry.get("platform_top_z", 3600))
	var tracked_front: Array = []
	for row in range(3):
		for column in range(10):
			var body := Solver.add_coin(state, _rng("plan94:%s:ratchet:%d:%d" % [variation_id, row, column]), 7000 + column * 9400, 1)
			_configure_body(body, 7000 + column * 9400 + (350 if row % 2 else 0), 58700 - row * 8200, top_z, "platform", true)
			if row == 2:
				tracked_front.append(str(body.get("id", "")))
	var bankroll_before_drop := active_run_state.bankroll
	var drop_command := game.surface_action_command("coin_pusher_drop", 0, false, {}, active_run_state, active_environment)
	var paid_drop_cost := int(drop_command.get("set_stake", 0))
	var drop_result := game.resolve_with_context(str(drop_command.get("action_id", "")), paid_drop_cost, active_run_state, active_environment, _rng("plan94:%s:ratchet:paid" % variation_id), {})
	GameModule.apply_result(active_run_state, drop_result)
	# Production synchronizes physical riders/pucks/fragments immediately before
	# queuing the paid drop. Capture the next solver ID after that synchronization
	# so the proof follows the quarter, never a newly injected feature body.
	var paid_body_id := "body_%05d" % int(state.get("next_body_id", 1))
	var paid_drop_charged := bool(drop_command.get("handled", false)) and bool(drop_command.get("direct_resolve", false)) and paid_drop_cost > 0 and active_run_state.bankroll == bankroll_before_drop - paid_drop_cost
	var initial := _record(state)
	var deposits: Array = []
	var cycle_events: Array = []
	var mid_record := {}
	var period := maxi(1, int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
	var paid_landed_on_platform := false
	var paid_drop_seen := false
	var paid_events: Array = []
	for _tick in range(period * 3):
		var previous := Solver.body_views(state)
		var result := _advance_production_tick()
		paid_drop_seen = paid_drop_seen or not _body(state, paid_body_id).is_empty()
		for event_value in result.get("events", []):
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if str(event.get("body_id", "")) == paid_body_id:
				paid_events.append(event.duplicate(true))
			if str(event.get("kind", "")) == "stroke_cycle":
				cycle_events.append(event.duplicate(true))
			if str(event.get("body_id", "")) == paid_body_id and str(event.get("kind", "")) == "impact" and str(event.get("support_root", event.get("support", ""))) in ["platform", "body"]:
				paid_landed_on_platform = true
			if str(event.get("kind", "")) == "platform_deposit" and tracked_front.has(str(event.get("body_id", ""))):
				deposits.append(event.duplicate(true))
				if mid_record.is_empty():
					mid_record = _record(state, previous, result.get("events", []))
	var final_record := _record(state)
	if mid_record.is_empty():
		mid_record = final_record
	var file := "%s_ratchet_three_cycles.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, mid_record, final_record], false)
	var passed := paid_drop_charged and paid_drop_seen and paid_landed_on_platform and cycle_events.size() >= 3 and not deposits.is_empty() and saved
	return {"id": "ratchet_three_cycles", "passed": passed, "files": [file], "cycles": cycle_events, "paid_body_id": paid_body_id, "paid_drop_cost": paid_drop_cost, "paid_drop_charged": paid_drop_charged, "paid_drop_seen_in_live_solver": paid_drop_seen, "paid_landed_on_platform": paid_landed_on_platform, "paid_events": paid_events, "paid_final_body": _body(state, paid_body_id).duplicate(true), "tracked_front_body_ids": tracked_front, "tracked_deposit_body_id": str((deposits[0] as Dictionary).get("body_id", "")) if not deposits.is_empty() else "", "platform_deposit_events": deposits, "initial_tick": int(initial["tick"]), "final_tick": int(final_record["tick"])}


func _capture_nestle_topple(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:nestle" % variation_id, definition, 0)
	var height := int((definition.get("coins", {}) as Dictionary).get("height", 950))
	var a := Solver.add_coin(state, _rng("plan94:%s:nestle:a" % variation_id), 47650, 1)
	var b := Solver.add_coin(state, _rng("plan94:%s:nestle:b" % variation_id), 52350, 1)
	var support := Solver.add_coin(state, _rng("plan94:%s:nestle:support" % variation_id), 45000, 1)
	var top := Solver.add_coin(state, _rng("plan94:%s:nestle:top" % variation_id), 49500, 1)
	_configure_body(a, 47650, 18000, 0, "deck", true)
	_configure_body(b, 52350, 18000, 0, "deck", true)
	_configure_body(support, 45000, 18000, height, "body", true)
	_configure_body(top, 49500, 18000, height * 2, "body", false)
	top["rest_state"] = "resting"
	top["vx"] = 4200
	var body_id := str(top.get("id", ""))
	var initial := _record(state)
	var motion_record := {}
	var event_record := {}
	var motion_events: Array = []
	for _tick in range(180):
		var previous := Solver.body_views(state)
		var result := Solver.step_ticks(state, {"motor_enabled": false}, 1)
		var tracked := _body(state, body_id)
		if motion_record.is_empty() and (int(tracked.get("vx", 0)) != 0 or int(tracked.get("vz", 0)) != 0):
			motion_record = _record(state, previous, result.get("events", []))
		for event_value in result.get("events", []):
			if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("body_id", "")) == body_id:
				motion_events.append((event_value as Dictionary).duplicate(true))
				if event_record.is_empty():
					event_record = _record(state, previous, result.get("events", []))
	var settled := _body(state, body_id)
	var final_record := _record(state)
	if motion_record.is_empty(): motion_record = initial
	if event_record.is_empty(): event_record = final_record
	var file := "%s_stack_nestle_topple.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, motion_record, event_record, final_record], false)
	var nestled := str(settled.get("support_kind", "")) == "body" and int(settled.get("z", -1)) == height and int(settled.get("x", 0)) > 48000 and int(settled.get("x", 0)) < 52000
	var passed := nestled and not motion_events.is_empty() and saved
	return {"id": "stack_nestle_topple", "passed": passed, "files": [file], "tracked_body_id": body_id, "initial": _body_from_views(initial["current_views"], body_id), "motion": _body_from_views(motion_record["current_views"], body_id), "intermediate_events": motion_events, "final": settled.duplicate(true), "toppled_from_stack_and_nestled": nestled}


func _capture_skill_stop(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:skill" % variation_id, definition, 72)
	Solver.set_skill_stop(state, true)
	Solver.step_ticks(state, {"motor_enabled": true}, 24)
	var banked_ids: Array = []
	for index in range(5):
		var body := Solver.add_coin(state, _rng("plan94:%s:skill:%d" % [variation_id, index]), 47000 + index * 1200, 1)
		banked_ids.append(str(body.get("id", "")))
	Solver.step_ticks(state, {"motor_enabled": true}, 140)
	var held := _record(state)
	var held_y := _body_y_for_ids(held["current_views"], banked_ids)
	var motor_stopped := int(state.get("motor_rate_fp", -1)) == 0
	Solver.set_skill_stop(state, false)
	var min_y := held_y.duplicate(true)
	var release_events: Array = []
	for _tick in range(720):
		var result := Solver.step_ticks(state, {"motor_enabled": true}, 1)
		release_events.append_array(result.get("events", []))
		var positions := _body_y_for_ids(Solver.body_views(state), banked_ids)
		for body_id in banked_ids:
			if positions.has(body_id):
				min_y[body_id] = mini(int(min_y.get(body_id, positions[body_id])), int(positions[body_id]))
	var displacement := 0
	var advanced := 0
	for body_id in banked_ids:
		if held_y.has(body_id) and min_y.has(body_id):
			var delta := maxi(0, int(held_y[body_id]) - int(min_y[body_id]))
			displacement += delta
			advanced += 1 if delta > 100 else 0
	var released := _record(state)
	var normal_file := "%s_skill_stop_bank_release.png" % variation_id
	var reduced_file := "%s_skill_stop_bank_release_reduced.png" % variation_id
	var normal_saved := await _save_record_strip(normal_file, variation_id, definition, [held, released], false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, [held, released], true)
	var passed := banked_ids.size() == 5 and motor_stopped and advanced >= 3 and displacement > 5000 and normal_saved and reduced_saved
	return {"id": "skill_stop_bank_release", "passed": passed, "files": [normal_file, reduced_file], "banked_body_ids": banked_ids, "held_tick": int(held["tick"]), "released_tick": int(released["tick"]), "motor_stopped": motor_stopped, "advanced_body_count": advanced, "total_forward_displacement": displacement, "terminal_events": _terminal_events(release_events)}


func _capture_tray(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:tray" % variation_id, definition, 0)
	var geometry: Dictionary = definition.get("geometry", {})
	var lip := int(geometry.get("tray_lip_y", 4000))
	var ids: Array = []
	var terminal_events: Array = []
	for index in range(12):
		var body := Solver.add_coin(state, _rng("plan94:%s:tray:%d" % [variation_id, index]), 21000 + index % 6 * 11000, 1)
		_configure_body(body, 21000 + index % 6 * 11000, lip - 800 - index / 6 * 300, 0, "deck", true)
		ids.append(str(body.get("id", "")))
	var result := Solver.step_ticks(state, {"motor_enabled": false}, 1)
	terminal_events.append_array(_terminal_events(result.get("events", [])))
	var departure := _record(state, [], result.get("events", []))
	var mid_fall := {}
	for _tick in range(60):
		var previous := Solver.body_views(state)
		result = Solver.step_ticks(state, {"motor_enabled": false}, 1)
		terminal_events.append_array(_terminal_events(result.get("events", [])))
		if mid_fall.is_empty():
			for body_value in state.get("bodies", []):
				if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("exit_state", "")) == "tray_fall" and int((body_value as Dictionary).get("z", 0)) < -1000:
					mid_fall = _record(state, previous, result.get("events", []))
					break
		if (state.get("tray_ledger", []) as Array).size() == ids.size():
			break
	if mid_fall.is_empty():
		mid_fall = departure
	var grown := _record(state)
	var tray_count := (state.get("tray_ledger", []) as Array).size()
	var tray_value := _ledger_value(state.get("tray_ledger", []))
	var bankroll_before_collect := active_run_state.bankroll
	var collected := game.surface_action_command("coin_pusher_collect", 0, false, {}, active_run_state, active_environment)
	var empty := _record(state)
	var file := "%s_tray_visible_fall_growth_collect.png" % variation_id
	var reduced_file := "%s_tray_visible_fall_growth_collect_reduced.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [departure, mid_fall, grown, empty], false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, [departure, mid_fall, grown, empty], true)
	var bankroll_transfer := active_run_state.bankroll - bankroll_before_collect
	var passed := tray_count == 12 and _event_count(terminal_events, "tray_fall_start") == 12 and _event_count(terminal_events, "tray") == 12 and int(mid_fall.get("tick", 0)) > int(departure.get("tick", 0)) and int(grown.get("tick", 0)) > int(mid_fall.get("tick", 0)) and bool(collected.get("handled", false)) and bankroll_transfer == tray_value and (state.get("tray_ledger", []) as Array).is_empty() and saved and reduced_saved
	return {"id": "tray_growth_collect", "passed": passed, "files": [file, reduced_file], "body_ids": ids, "terminal_events": terminal_events, "departure_tick": int(departure["tick"]), "mid_fall_tick": int(mid_fall["tick"]), "grown_tick": int(grown["tick"]), "tray_count_before_collect": tray_count, "tray_value_before_collect": tray_value, "bankroll_before_collect": bankroll_before_collect, "bankroll_after_collect": active_run_state.bankroll, "bankroll_transfer": bankroll_transfer, "collect_result": collected, "tray_count_after_collect": 0}


func _capture_gutter_fall(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:gutter" % variation_id, definition, 0)
	var geometry: Dictionary = definition.get("geometry", {})
	var lip := int(geometry.get("tray_lip_y", 4000))
	var gutter := int(geometry.get("gutter_x", 3000))
	var body := Solver.add_coin(state, _rng("plan94:%s:gutter:body" % variation_id), gutter / 2, 1)
	_configure_body(body, gutter / 2, lip - 800, 0, "deck", true)
	var body_id := str(body.get("id", ""))
	var all_events: Array = []
	var result := Solver.step_ticks(state, {"motor_enabled": false}, 1)
	all_events.append_array(_terminal_events(result.get("events", [])))
	var departure := _record(state, [], result.get("events", []))
	var mid_fall := {}
	for _tick in range(60):
		var previous := Solver.body_views(state)
		result = Solver.step_ticks(state, {"motor_enabled": false}, 1)
		all_events.append_array(_terminal_events(result.get("events", [])))
		var tracked := _body(state, body_id)
		if mid_fall.is_empty() and not tracked.is_empty() and str(tracked.get("exit_state", "")) == "gutter_fall" and int(tracked.get("z", 0)) < -1000:
			mid_fall = _record(state, previous, result.get("events", []))
		if tracked.is_empty():
			break
	if mid_fall.is_empty():
		mid_fall = departure
	var landed := _record(state)
	var file := "%s_gutter_visible_fall.png" % variation_id
	var reduced_file := "%s_gutter_visible_fall_reduced.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [departure, mid_fall, landed], false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, [departure, mid_fall, landed], true)
	var passed := _event_count(all_events, "gutter_fall_start") == 1 and _event_count(all_events, "gutter") == 1 and (state.get("gutter_ledger", []) as Array).size() == 1 and int(mid_fall.get("tick", 0)) > int(departure.get("tick", 0)) and int(landed.get("tick", 0)) > int(mid_fall.get("tick", 0)) and saved and reduced_saved
	return {"id": "gutter_visible_fall", "passed": passed, "files": [file, reduced_file], "body_id": body_id, "events": all_events, "departure_tick": int(departure["tick"]), "mid_fall_tick": int(mid_fall["tick"]), "landed_tick": int(landed["tick"])}


func _capture_rapid_drop_pile(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := _production_state("plan94:%s:rapid-pile" % variation_id, definition, 0)
	var pile_definition: Dictionary = state.get("machine_definition", {})
	var pile_apparatus: Dictionary = pile_definition.get("apparatus", {}) if typeof(pile_definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	# Isolate the pile response from delivery-board deflection. The production
	# renderer and cabinet stay intact while every rapid drop shares one clear
	# vertical path, so the final irregularity is landing/contact behavior.
	pile_apparatus["pegs"] = []
	pile_definition["apparatus"] = pile_apparatus
	_hold_phase(state, definition, 120)
	var release_x := _policy_x(definition, 0)
	var ids: Array = []
	var initial := {}
	var landing_events: Array = []
	for index in range(8):
		var body := Solver.add_coin(state, _rng("plan94:%s:rapid-pile:%d" % [variation_id, index]), release_x, 1)
		ids.append(str(body.get("id", "")))
		if initial.is_empty():
			initial = _record(state)
		var step := Solver.step_ticks(state, {"motor_enabled": false}, 2)
		landing_events.append_array(step.get("events", []))
	for _tick in range(240):
		var step := Solver.step_ticks(state, {"motor_enabled": false}, 1)
		landing_events.append_array(step.get("events", []))
	var final_record := _record(state)
	var landed_positions := {}
	var carried_stack_count := 0
	for body_id in ids:
		var landed_body := _body(state, str(body_id))
		if landed_body.is_empty():
			continue
		landed_positions["%d:%d" % [int(landed_body.get("x", 0)) / 100, int(landed_body.get("y", 0)) / 100]] = true
		if str(landed_body.get("support_kind", "")) == "body" and bool(landed_body.get("carried_sleep", false)):
			carried_stack_count += 1
	var scatter_directions := {}
	for event_value in landing_events:
		if typeof(event_value) != TYPE_DICTIONARY or str((event_value as Dictionary).get("kind", "")) != "impact":
			continue
		var event: Dictionary = event_value
		if not ids.has(str(event.get("body_id", ""))):
			continue
		scatter_directions["%d:%d" % [int(event.get("landing_scatter_x", 0)), int(event.get("landing_scatter_y", 0))]] = true
	var file := "%s_rapid_drop_irregular_pile.png" % variation_id
	var reduced_file := "%s_rapid_drop_irregular_pile_reduced.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, final_record], false)
	var reduced_saved := await _save_record_strip(reduced_file, variation_id, definition, [initial, final_record], true)
	var passed := landed_positions.size() >= 3 and scatter_directions.size() >= 3 and saved and reduced_saved
	return {"id": "rapid_drop_pile", "passed": passed, "files": [file, reduced_file], "body_ids": ids, "distinct_landing_cells": landed_positions.size(), "scatter_direction_count": scatter_directions.size(), "platform_rooted_body_support_count": carried_stack_count, "initial_tick": int(initial.get("tick", -1)), "final_tick": int(final_record.get("tick", -1))}


func _save_pair(variation_id: String, scene_id: String, definition: Dictionary, first: Dictionary, second: Dictionary, reduced: bool) -> Dictionary:
	var file := "%s_%s.png" % [variation_id, scene_id]
	return {"files": [file], "saved": await _save_record_strip(file, variation_id, definition, [first, second], reduced)}


func _save_record_strip(file_name: String, variation_id: String, definition: Dictionary, records: Array, reduced_motion: bool) -> bool:
	if records.is_empty():
		return false
	var images: Array[Image] = []
	for record_value in records:
		images.append(await _render_record(variation_id, definition, record_value, reduced_motion))
	var strip := Image.create(CAPTURE_SIZE.x * images.size(), CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	for index in range(images.size()):
		if images[index].is_empty():
			return false
		strip.blit_rect(images[index], Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(index * CAPTURE_SIZE.x, 0))
	var output_path := ProjectSettings.globalize_path("%s/%s" % [out_dir, file_name])
	return strip.save_png(output_path) == OK


func _render_record(variation_id: String, definition: Dictionary, record: Dictionary, reduced_motion: bool) -> Image:
	var production_patch: Dictionary = record.get("production_surface_state", {}) if typeof(record.get("production_surface_state", {})) == TYPE_DICTIONARY else {}
	if production_patch.is_empty():
		_fail("%s %s record bypassed the production surface projection." % [variation_id, str(record.get("tick", -1))])
		return Image.new()
	production_patch = production_patch.duplicate(true)
	production_patch["coin_pusher_interpolation_alpha"] = 1.0 if reduced_motion else 0.5
	production_patch["reduce_motion"] = reduced_motion
	canvas.call("apply_surface_state_patch", production_patch)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		return Image.new()
	var result := image.duplicate()
	if result.get_size() != CAPTURE_SIZE:
		result.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return result


func _record(state: Dictionary, previous_views: Array = [], events: Array = []) -> Dictionary:
	var current := Solver.body_views(state)
	var previous := current.duplicate(true) if previous_views.is_empty() else previous_views.duplicate(true)
	var saved_previous: Variant = (active_machine.get("live_session", {}) as Dictionary).get("presentation_previous_bodies", [])
	var saved_current: Variant = (active_machine.get("live_session", {}) as Dictionary).get("presentation_current_bodies", [])
	(active_machine.get("live_session", {}) as Dictionary)["presentation_previous_bodies"] = previous
	(active_machine.get("live_session", {}) as Dictionary)["presentation_current_bodies"] = current
	var production_surface := game.surface_state(active_run_state, active_environment, {})
	(active_machine.get("live_session", {}) as Dictionary)["presentation_previous_bodies"] = saved_previous
	(active_machine.get("live_session", {}) as Dictionary)["presentation_current_bodies"] = saved_current
	return {"tick": int(state.get("tick", 0)), "state": state.duplicate(true), "previous_views": previous, "current_views": current, "events": events.duplicate(true), "production_surface_state": production_surface}


func _record_from_views(state: Dictionary, views: Array) -> Dictionary:
	return _record(state, views, [])


func _enter_production_variation(variation_id: String) -> bool:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		return false
	game = module_script.new()
	game.setup(definition, library)
	active_run_state = app.get("run_state") as RunState
	if active_run_state == null:
		return false
	active_environment = {
		"id": "plan94_%s" % variation_id,
		"world_node_id": "plan94_%s" % variation_id,
		"name": "%s Plan 9.4" % variation_id.replace("_", " ").capitalize(),
		"game_ids": ["coin_pusher"],
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": variation_id}},
		"game_states": {},
	}
	var generated: Dictionary = game.generate_environment_state(active_run_state, active_environment, _rng("plan94:%s:production-entry" % variation_id))
	active_environment["game_states"] = {"coin_pusher": generated}
	game.enter(active_run_state, active_environment)
	var live_map: Dictionary = game.get("_live_machines")
	active_machine = live_map.values()[0] if not live_map.is_empty() else {}
	production_clock_msec = 0
	return not active_machine.is_empty() and str(active_machine.get("variation_id", "")) == variation_id


func _production_opening_snapshot() -> Dictionary:
	var game_states: Dictionary = active_environment.get("game_states", {}) if typeof(active_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var durable: Dictionary = game_states.get("coin_pusher", {}) if typeof(game_states.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	var snapshot: Dictionary = durable.get("settled_state", {}) if typeof(durable.get("settled_state", {})) == TYPE_DICTIONARY else {}
	return snapshot.duplicate(true)


func _restore_production_entry(production_entry_machine: Dictionary) -> Dictionary:
	if production_entry_machine.is_empty() \
		or typeof(production_entry_machine.get("simulation", {})) != TYPE_DICTIONARY \
		or typeof(production_entry_machine.get("live_session", {})) != TYPE_DICTIONARY:
		return {}
	# Preserve the dictionary already installed in the production module's live
	# map and replay the exact production entry RNG/session byte-for-byte.
	active_machine.clear()
	active_machine.merge(production_entry_machine.duplicate(true), true)
	production_clock_msec = 0
	return active_machine.get("simulation", {}) if typeof(active_machine.get("simulation", {})) == TYPE_DICTIONARY else {}


func _advance_production_exact_tick() -> Dictionary:
	var session: Dictionary = active_machine.get("live_session", {}) if typeof(active_machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var accumulator_units := int(session.get("accumulator_units", 0))
	var units_needed := maxi(1, 1000 - accumulator_units)
	var elapsed_msec := maxi(1, ceili(float(units_needed) / float(LiveSession.FIXED_HZ)))
	production_clock_msec += elapsed_msec
	var advanced := LiveSession.advance(active_machine, production_clock_msec)
	game.call("_consume_live_physics_events", active_run_state, active_machine, advanced.get("events", []))
	advanced["exact_one_tick"] = int(advanced.get("ticks", 0)) == 1
	return advanced


func _upper_row_control_digest(state: Dictionary) -> Dictionary:
	return {
		"body_views_sha256": _sha256(Solver.body_views(state)),
		"tray_sha256": _sha256(state.get("tray_ledger", [])),
		"gutter_sha256": _sha256(state.get("gutter_ledger", [])),
		"variation_state_sha256": _sha256(active_machine.get("variation_state", {})),
		"target_state_sha256": _sha256(state.get("target_last_capture", {})),
		"phase_fp": int(state.get("phase_fp", -1)),
		"face_y": int(state.get("face_y", -1)),
		"previous_face_y": int(state.get("previous_face_y", -1)),
		"stroke_cycle_serial": int(state.get("stroke_cycle_serial", -1)),
		"motor_started": bool(active_machine.get("motor_started", false)),
		"motor_rate_fp": int(state.get("motor_rate_fp", -1)),
		"accepted_inserts": int(state.get("accepted_inserts", 0)),
		"collected_count": int(state.get("collected_count", 0)),
		"collected_value": int(state.get("collected_value", 0)),
	}


func _upper_row_session_identity() -> Dictionary:
	var session: Dictionary = active_machine.get("live_session", {}) if typeof(active_machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	return {
		"start_snapshot_sha256": _sha256(session.get("start_snapshot", {})),
		"rng_sha256": _sha256(session.get("rng", {})),
		"input_trace_sha256": _sha256(session.get("input_trace", [])),
		"input_cursor": int(session.get("input_cursor", -1)),
		"accumulator_units": int(session.get("accumulator_units", -1)),
		"last_clock_msec": int(session.get("last_clock_msec", -1)),
	}


func _body_id_set(views: Array) -> Dictionary:
	var result := {}
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY:
			result[str((body_value as Dictionary).get("id", ""))] = true
	return result


func _body_ids(views: Array) -> Array:
	var result: Array = []
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY:
			result.append(str((body_value as Dictionary).get("id", "")))
	return result


func _upper_row_local_neighbors(views: Array, tracked_body_id: String, opening_ids: Dictionary) -> Array:
	var tracked := _body_from_views(views, tracked_body_id)
	if tracked.is_empty():
		return []
	var support_ids := {}
	for support_id in tracked.get("support_ids", []):
		support_ids[str(support_id)] = true
	var result: Array = []
	for body_value in views:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var body_id := str(body.get("id", ""))
		if body_id == tracked_body_id or support_ids.has(body_id) or not opening_ids.has(body_id) \
				or str(body.get("kind", "")) != "coin" \
				or str(body.get("support_root", "")) != "platform":
			continue
		var dx := int(body.get("x", 0)) - int(tracked.get("x", 0))
		var dy := int(body.get("y", 0)) - int(tracked.get("y", 0))
		var contact_distance := int(body.get("radius", 2350)) + int(tracked.get("radius", 2350)) + 120
		# A body directly underneath the drop proves support, not "beside the row."
		# Require a neighboring coin on the same local tier; modest z tolerance
		# allows an irregular physical bed without admitting a full stacked layer.
		var tier_tolerance := maxi(100, int(mini(int(body.get("height", 950)), int(tracked.get("height", 950))) / 2))
		var same_upper_tier := absi(int(body.get("z", 0)) - int(tracked.get("z", 0))) <= tier_tolerance
		if same_upper_tier and dx * dx + dy * dy <= contact_distance * contact_distance:
			result.append(body.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return result


func _upper_row_neighbor_diagnostics(views: Array, tracked_body_id: String, opening_ids: Dictionary) -> Array:
	var tracked := _body_from_views(views, tracked_body_id)
	if tracked.is_empty():
		return []
	var support_ids := {}
	for support_id in tracked.get("support_ids", []):
		support_ids[str(support_id)] = true
	var result: Array = []
	for body_value in views:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var body_id := str(body.get("id", ""))
		if body_id == tracked_body_id or support_ids.has(body_id) or not opening_ids.has(body_id) \
				or str(body.get("kind", "")) != "coin" \
				or str(body.get("support_root", "")) != "platform":
			continue
		var dx := int(body.get("x", 0)) - int(tracked.get("x", 0))
		var dy := int(body.get("y", 0)) - int(tracked.get("y", 0))
		var dz := int(body.get("z", 0)) - int(tracked.get("z", 0))
		result.append({
			"id": body_id,
			"dx": dx,
			"dy": dy,
			"dz": dz,
			"distance_squared": dx * dx + dy * dy,
			"radius_sum": int(body.get("radius", 2350)) + int(tracked.get("radius", 2350)),
			"height_min": mini(int(body.get("height", 950)), int(tracked.get("height", 950))),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("distance_squared", 0)) < int(b.get("distance_squared", 0)))
	if result.size() > 12:
		result.resize(12)
	return result


func _production_state(seed: String, definition: Dictionary, opening_bodies: int) -> Dictionary:
	var state := Solver.create_machine(_rng(seed), definition, opening_bodies)
	active_machine["simulation"] = state
	active_machine.erase("live_session")
	LiveSession.begin(active_machine, definition, seed.hash() & 0x7fffffff)
	production_clock_msec = 0
	LiveSession.advance(active_machine, production_clock_msec)
	return state


func _advance_production_tick() -> Dictionary:
	production_clock_msec += 17
	var advanced := LiveSession.advance(active_machine, production_clock_msec)
	game.call("_consume_live_physics_events", active_run_state, active_machine, advanced.get("events", []))
	return advanced


func _machine_context(variation_id: String, definition: Dictionary) -> Dictionary:
	var renderer = Renderer.new()
	var signature := renderer.render_signature({"coin_pusher_variation_id": variation_id, "coin_pusher_geometry": definition.get("geometry", {}), "coin_pusher_apparatus": definition.get("apparatus", {}), "coin_pusher_cabinet": definition.get("cabinet", {}), "coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 950)), "coin_pusher_coin_radius": int((definition.get("coins", {}) as Dictionary).get("radius", 2350)), "coin_pusher_bodies": []})
	return {"machine_id": str(definition.get("machine_id", variation_id)), "apparatus_type": str((definition.get("apparatus", {}) as Dictionary).get("type", "")), "cabinet_identity": str(signature.get("identity", "")), "cabinet_marquee": str(signature.get("marquee", "")), "sub_game_feature_kind": str((definition.get("sub_game", {}) as Dictionary).get("feature_kind", "none")), "geometry_sha256": _sha256({"geometry": definition.get("geometry", {}), "stroke": definition.get("stroke", {}), "apparatus": definition.get("apparatus", {})})}


func _policy_x(definition: Dictionary, index: int) -> int:
	var apparatus: Dictionary = definition.get("apparatus", {})
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	if not holes.is_empty():
		return int(holes[index % holes.size()])
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	return int(rail.get("x_min", 8000)) + (int(rail.get("x_max", 92000)) - int(rail.get("x_min", 8000))) * (index + 1) / 3


func _delivery_contact_x(definition: Dictionary) -> int:
	var apparatus: Dictionary = definition.get("apparatus", {})
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	if not holes.is_empty():
		return int(holes[holes.size() / 2])
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	var best_x := (rail_min + rail_max) / 2
	var best_distance := 1 << 30
	for peg_value in apparatus.get("pegs", []):
		if typeof(peg_value) != TYPE_DICTIONARY:
			continue
		var peg_x := int((peg_value as Dictionary).get("x", best_x))
		if peg_x < rail_min or peg_x > rail_max:
			continue
		var distance := absi(peg_x - (rail_min + rail_max) / 2)
		if distance < best_distance:
			best_distance = distance
			best_x = peg_x
	return best_x


func _hold_phase(state: Dictionary, definition: Dictionary, phase: int) -> void:
	state["phase_fp"] = phase * Solver.FP
	state["face_y"] = Solver.face_y_for_phase(definition, phase)
	state["previous_face_y"] = int(state["face_y"])


func _configure_body(body: Dictionary, x: int, y: int, z: int, support: String, sleeping: bool) -> void:
	body.merge({"x": x, "y": y, "z": z, "vx": 0, "vy": 0, "vz": 0, "support_kind": support, "rest_state": "resting" if sleeping else "falling", "sleeping": sleeping, "sleep_ticks": 8 if sleeping else 0, "carried_sleep": support == "platform"}, true)


func _body(state: Dictionary, body_id: String) -> Dictionary:
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
			return body_value
	return {}


func _body_from_views(views: Array, body_id: String) -> Dictionary:
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
			return (body_value as Dictionary).duplicate(true)
	return {}


func _body_y_map(views: Array) -> Dictionary:
	var result := {}
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY:
			result[str((body_value as Dictionary).get("id", ""))] = int((body_value as Dictionary).get("y", 0))
	return result


func _body_y_for_ids(views: Array, ids: Array) -> Dictionary:
	var wanted := {}
	for body_id in ids:
		wanted[str(body_id)] = true
	var result := {}
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY and wanted.has(str((body_value as Dictionary).get("id", ""))):
			result[str((body_value as Dictionary).get("id", ""))] = int((body_value as Dictionary).get("y", 0))
	return result


func _terminal_events(events: Array) -> Array:
	return events.filter(func(event): return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) in ["tray_fall_start", "gutter_fall_start", "tray", "gutter", "platform_deposit"])


func _event_count(events: Array, kind: String) -> int:
	var count := 0
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _ledger_value(ledger: Array) -> int:
	var total := 0
	for entry_value in ledger:
		if typeof(entry_value) == TYPE_DICTIONARY:
			total += maxi(0, int((entry_value as Dictionary).get("value", 0)))
	return total


func _sha256(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value, "", true).to_utf8_buffer())
	return context.finish().hex_encode()


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng


func _write_manifest() -> void:
	var passed := not failed and minimum_viewport_verified and machine_records.size() == VARIATIONS.size()
	for machine_record in machine_records:
		passed = passed and bool((machine_record as Dictionary).get("passed", false))
	var manifest := {"schema": "coin_pusher_v3_plan_9_4_feel_capture_v2", "production_surface": true, "production_environment_entry": true, "production_surface_projection": true, "upper_row_evidence": "production_entry_idle_control_local_neighbors_phase_matched_cycle", "minimum_viewport": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y, "verified": minimum_viewport_verified}, "required_machines": VARIATIONS, "required_scenes_per_machine": REQUIRED_SCENES, "machine_count": machine_records.size(), "passed": passed, "machines": machine_records}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		_fail("Could not write plan 9.4 manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish() -> void:
	print("COIN_PUSHER_PLAN94_FEEL_%s machines=%d out=%s" % ["FAIL" if failed else "PASS", machine_records.size(), ProjectSettings.globalize_path(out_dir)])
	quit(1 if failed else 0)
