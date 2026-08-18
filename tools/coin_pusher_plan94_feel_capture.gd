extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Renderer := preload("res://scripts/games/coin_pusher/coin_pusher_renderer.gd")

const CAPTURE_SIZE := Vector2i(1280, 720)
const VARIATIONS := ["quarter_falls", "jackpot_ridge", "vault_drop"]
const REQUIRED_SCENES := ["upper_row_join", "delivery_descent", "ratchet_three_cycles", "stack_nestle_topple", "skill_stop_bank_release", "tray_growth_collect"]

var app: Control
var canvas: Control
var game: GameModule
var out_dir := "res://.tmp/coin_pusher_plan94_feel"
var machine_records: Array = []
var failed := false


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
	app.call("start_game_test_session", "coin_pusher")
	await _frames(8)
	game = app.get("current_game") as GameModule
	canvas = app.get("game_surface_canvas") as Control
	if game == null or canvas == null:
		_fail("Production Coin Pusher surface did not open.")
		_finish()
		return
	app.set_process(false)
	for variation_id in VARIATIONS:
		await _capture_machine(variation_id)
	_write_manifest()
	_finish()


func _capture_machine(variation_id: String) -> void:
	var definition: Dictionary = game.call("_machine_definition", variation_id)
	if definition.is_empty():
		_fail("Missing production definition for %s." % variation_id)
		return
	var scenes: Array = []
	scenes.append(await _capture_upper_row(variation_id, definition))
	scenes.append(await _capture_delivery(variation_id, definition))
	scenes.append(await _capture_ratchet(variation_id, definition))
	scenes.append(await _capture_nestle_topple(variation_id, definition))
	scenes.append(await _capture_skill_stop(variation_id, definition))
	scenes.append(await _capture_tray(variation_id, definition))
	var context := _machine_context(variation_id, definition)
	var complete := scenes.size() == REQUIRED_SCENES.size()
	for scene in scenes:
		complete = complete and bool((scene as Dictionary).get("passed", false))
	machine_records.append({"variation_id": variation_id, "context": context, "scenes": scenes, "passed": complete})
	if not complete:
		_fail("%s did not produce every plan 9.4 feel scene." % variation_id)


func _capture_upper_row(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := Solver.create_machine(_rng("plan94:%s:upper" % variation_id), definition, 70)
	var before_views := Solver.body_views(state)
	var before_record := _record(state)
	var before_y := _body_y_map(before_views)
	var drop := Solver.add_coin(state, _rng("plan94:%s:upper:drop" % variation_id), _policy_x(definition, 0), 1)
	var body_id := str(drop.get("id", ""))
	var first_support_event := {}
	var landing_tick := -1
	for _tick in range(1200):
		var result := Solver.step_ticks(state, {"motor_enabled": true}, 1)
		for event_value in result.get("events", []):
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if str(event.get("body_id", "")) == body_id and bool(event.get("first_support", false)):
				first_support_event = event.duplicate(true)
				landing_tick = int(state.get("tick", -1))
		if not first_support_event.is_empty() and int(state.get("tick", 0)) >= landing_tick + 240:
			break
	var after_views := Solver.body_views(state)
	var advanced_ids: Array = []
	for body_value in after_views:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var id := str(body.get("id", ""))
		if before_y.has(id) and int(body.get("y", 0)) < int(before_y[id]) - 100:
			advanced_ids.append(id)
	var files := await _save_pair(variation_id, "upper_row_join", definition, before_record, _record(state), false)
	var support_root := str(first_support_event.get("support_root", first_support_event.get("support", "")))
	var passed := bool(drop.get("accepted", false)) and support_root in ["platform", "body"] and not advanced_ids.is_empty() and bool(files.get("saved", false))
	return {"id": "upper_row_join", "passed": passed, "files": files, "tracked_body_id": body_id, "landing_tick": landing_tick, "first_support_event": first_support_event, "advanced_existing_body_ids": advanced_ids}


func _capture_delivery(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := Solver.create_machine(_rng("plan94:%s:delivery" % variation_id), definition, 0)
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
	var state := Solver.create_machine(_rng("plan94:%s:ratchet" % variation_id), definition, 0)
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
	var initial := _record(state)
	var deposits: Array = []
	var cycle_events: Array = []
	var mid_record := {}
	var period := maxi(1, int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
	for _tick in range(period * 3):
		var previous := Solver.body_views(state)
		var result := Solver.step_ticks(state, {"motor_enabled": true}, 1)
		for event_value in result.get("events", []):
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if str(event.get("kind", "")) == "stroke_cycle":
				cycle_events.append(event.duplicate(true))
			if str(event.get("kind", "")) == "platform_deposit" and tracked_front.has(str(event.get("body_id", ""))):
				deposits.append(event.duplicate(true))
				if mid_record.is_empty():
					mid_record = _record(state, previous, result.get("events", []))
	var final_record := _record(state)
	if mid_record.is_empty():
		mid_record = final_record
	var file := "%s_ratchet_three_cycles.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, mid_record, final_record], false)
	var passed := cycle_events.size() >= 3 and not deposits.is_empty() and saved
	return {"id": "ratchet_three_cycles", "passed": passed, "files": [file], "cycles": cycle_events, "tracked_front_body_ids": tracked_front, "platform_deposit_events": deposits, "initial_tick": int(initial["tick"]), "final_tick": int(final_record["tick"])}


func _capture_nestle_topple(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := Solver.create_machine(_rng("plan94:%s:nestle" % variation_id), definition, 0)
	var height := int((definition.get("coins", {}) as Dictionary).get("height", 1700))
	var a := Solver.add_coin(state, _rng("plan94:%s:nestle:a" % variation_id), 45700, 1)
	var b := Solver.add_coin(state, _rng("plan94:%s:nestle:b" % variation_id), 54300, 1)
	var support := Solver.add_coin(state, _rng("plan94:%s:nestle:support" % variation_id), 42000, 1)
	var top := Solver.add_coin(state, _rng("plan94:%s:nestle:top" % variation_id), 49500, 1)
	_configure_body(a, 45700, 18000, 0, "deck", true)
	_configure_body(b, 54300, 18000, 0, "deck", true)
	_configure_body(support, 42000, 18000, height, "body", true)
	_configure_body(top, 49500, 18000, height * 2, "body", false)
	top["rest_state"] = "resting"
	top["vx"] = 8000
	var body_id := str(top.get("id", ""))
	var initial := _record(state)
	Solver.step_ticks(state, {"motor_enabled": false}, 180)
	var settled := _body(state, body_id)
	var final_record := _record(state)
	var file := "%s_stack_nestle_topple.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [initial, final_record], false)
	var nestled := str(settled.get("support_kind", "")) == "body" and int(settled.get("z", -1)) == height and int(settled.get("x", 0)) > 48000 and int(settled.get("x", 0)) < 52000
	var passed := nestled and saved
	return {"id": "stack_nestle_topple", "passed": passed, "files": [file], "tracked_body_id": body_id, "initial": _body_from_views(initial["current_views"], body_id), "final": settled.duplicate(true), "toppled_from_stack_and_nestled": nestled}


func _capture_skill_stop(variation_id: String, definition: Dictionary) -> Dictionary:
	var state := Solver.create_machine(_rng("plan94:%s:skill" % variation_id), definition, 72)
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
	var state := Solver.create_machine(_rng("plan94:%s:tray" % variation_id), definition, 0)
	var geometry: Dictionary = definition.get("geometry", {})
	var lip := int(geometry.get("tray_lip_y", 6000))
	var ids: Array = []
	var terminal_events: Array = []
	for index in range(12):
		var body := Solver.add_coin(state, _rng("plan94:%s:tray:%d" % [variation_id, index]), 21000 + index % 6 * 11000, 1)
		_configure_body(body, 21000 + index % 6 * 11000, lip - 800 - index / 6 * 300, 0, "deck", true)
		ids.append(str(body.get("id", "")))
	var result := Solver.step_ticks(state, {"motor_enabled": false}, 1)
	terminal_events = _terminal_events(result.get("events", []))
	var grown := _record(state)
	var tray_count := (state.get("tray_ledger", []) as Array).size()
	var collected := Solver.collect_tray(state)
	var empty := _record(state)
	var file := "%s_tray_growth_collect.png" % variation_id
	var saved := await _save_record_strip(file, variation_id, definition, [grown, empty], false)
	var passed := tray_count == 12 and int(collected.get("count", 0)) == 12 and (state.get("tray_ledger", []) as Array).is_empty() and saved
	return {"id": "tray_growth_collect", "passed": passed, "files": [file], "body_ids": ids, "terminal_events": terminal_events, "grown_tick": int(grown["tick"]), "tray_count_before_collect": tray_count, "collect_result": collected, "tray_count_after_collect": 0}


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
	var state: Dictionary = record.get("state", {})
	var tray: Array = state.get("tray_ledger", []) if typeof(state.get("tray_ledger", [])) == TYPE_ARRAY else []
	canvas.call("apply_surface_state_patch", {
		"coin_pusher_variation_id": variation_id,
		"coin_pusher_variation_name": variation_id.replace("_", " ").capitalize(),
		"coin_pusher_geometry": (definition.get("geometry", {}) as Dictionary).duplicate(true),
		"coin_pusher_apparatus": (definition.get("apparatus", {}) as Dictionary).duplicate(true),
		"coin_pusher_cabinet": (definition.get("cabinet", {}) as Dictionary).duplicate(true),
		"coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 1700)),
		"coin_pusher_bodies": record.get("current_views", []),
		"coin_pusher_previous_bodies": record.get("previous_views", record.get("current_views", [])),
		"coin_pusher_body_count": (record.get("current_views", []) as Array).size(),
		"coin_pusher_face_position_y": int(state.get("face_y", 28000)),
		"coin_pusher_previous_face_position_y": int(state.get("previous_face_y", state.get("face_y", 28000))),
		"coin_pusher_carriage_x": int(state.get("carriage_x", 50000)),
		"coin_pusher_selected_hole": int(state.get("selected_hole", 0)),
		"coin_pusher_phase_fp": int(state.get("phase_fp", 0)),
		"coin_pusher_motor_rate_fp": int(state.get("motor_rate_fp", 1000)),
		"coin_pusher_skill_stop_engaged": bool(state.get("skill_stop_engaged", false)),
		"coin_pusher_tray_count": tray.size(),
		"coin_pusher_tray_value": _ledger_value(tray),
		"coin_pusher_presentation_view_serial": int(record.get("tick", 0)),
		"coin_pusher_interpolation_alpha": 1.0 if reduced_motion else 0.5,
		"reduce_motion": reduced_motion,
	})
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
	return {"tick": int(state.get("tick", 0)), "state": state.duplicate(true), "previous_views": current.duplicate(true) if previous_views.is_empty() else previous_views.duplicate(true), "current_views": current, "events": events.duplicate(true)}


func _record_from_views(state: Dictionary, views: Array) -> Dictionary:
	return {"tick": int(state.get("tick", 0)), "state": state.duplicate(true), "previous_views": views.duplicate(true), "current_views": views.duplicate(true), "events": []}


func _machine_context(variation_id: String, definition: Dictionary) -> Dictionary:
	var renderer = Renderer.new()
	var signature := renderer.render_signature({"coin_pusher_variation_id": variation_id, "coin_pusher_geometry": definition.get("geometry", {}), "coin_pusher_apparatus": definition.get("apparatus", {}), "coin_pusher_cabinet": definition.get("cabinet", {}), "coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 1700)), "coin_pusher_bodies": []})
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
	return events.filter(func(event): return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) in ["tray", "gutter", "platform_deposit"])


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
	var passed := not failed and machine_records.size() == VARIATIONS.size()
	for machine_record in machine_records:
		passed = passed and bool((machine_record as Dictionary).get("passed", false))
	var manifest := {"schema": "coin_pusher_v3_plan_9_4_feel_capture_v1", "production_surface": true, "minimum_viewport": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y}, "required_machines": VARIATIONS, "required_scenes_per_machine": REQUIRED_SCENES, "machine_count": machine_records.size(), "passed": passed, "machines": machine_records}
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
