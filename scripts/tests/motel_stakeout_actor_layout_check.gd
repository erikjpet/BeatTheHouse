extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const Store := preload("res://scripts/core/developer_placement_store.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const WARNED := "scenario::motel_stakeout_aftermath_actor_occupant_warned"
const SOUTH := "scenario::motel_stakeout_south_observer"
const BOARD := Rect2(0,0,900,430)
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH","BTH_TARGET_OUTPUT",Store.USER_PATH_ENV,"BTH_MOTEL_BASELINE_PLACEMENT"]:
		private_ready = private_ready and not OS.get_environment(key).is_empty()
	if not check(private_ready,"private persistence and placement roots required"):
		_finish()
		return
	Store.reload()
	_check_exact_data_scope()
	_synthetic_binding_and_labels()
	if not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty(): await _captured_restore()
	_finish()

func _check_exact_data_scope() -> void:
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_MOTEL_BASELINE_PLACEMENT")))
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Store.PROJECT_PATH))
	var original_positions: Dictionary = before.rooms.motel.scenario_layouts.motel_stakeout.slot_positions
	check(original_positions["scenario.local_standing_person_1"] == [854.0,340.0] and original_positions["scenario.local_standing_person_2"] == [51.0,421.0],"baseline is exact reproduced project override")
	original_positions["scenario.local_standing_person_1"] = [276.0,414.0]
	original_positions["scenario.local_standing_person_2"] = [700.0,414.0]
	check(before == after,"only the two authorized coordinates change; all other values/keysets preserved")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Store.SCENARIO_LAYOUTS_PATH))
	var layout: Dictionary = {}
	for row in catalog.layouts:
		if str(row.get("layout_id","")) == "motel::motel_stakeout": layout = row
	for slot in layout.get("scenario_slots",[]):
		if str(slot.get("id","")) in ["scenario.local_standing_person_1","scenario.local_standing_person_2"]:
			check(after.rooms.motel.scenario_layouts.motel_stakeout.slot_positions[slot.id] == slot.pos,"candidate reuses existing catalog position "+str(slot.id))
	check(Store.user_slot_overrides(_environment()).is_empty(),"diagnostic has no user authoring override")

func _environment() -> Dictionary:
	return {"id":"motel_vis020","archetype_id":"motel","scenario_id":"motel_stakeout","scenario_state":{"id":"motel_stakeout"}}

func _synthetic_binding_and_labels() -> void:
	var environment := _environment()
	var before := environment.duplicate(true)
	var surface := Placement.surface_map(environment)
	var validation := Binder.validate_slot_map(surface)
	check(bool(validation.get("ok",false)),"effective Motel slot map remains valid: "+JSON.stringify(validation.get("errors",[])))
	var labels := ["North observer","Warned Occupant","Tired Lookout"]
	var ids := ["motel_stakeout_north_observer","motel_stakeout_aftermath_actor_occupant_warned","motel_stakeout_aftermath_actor_observer_waitout_failed"]
	for index in range(ids.size()):
		var identity := "scenario::"+str(ids[index])
		var actor := {"owner_namespace":"scenario","stable_object_id":ids[index],"label":labels[index],"zone_id":"left","behavior":"idle"}
		var south := {"owner_namespace":"scenario","stable_object_id":"motel_stakeout_south_observer","label":"South observer","zone_id":"right","anchor_id":"package_b_motel_top_left","behavior":"watch"}
		var bound := Binder.bind_scenario_visuals(environment,[{"identity":identity,"semantic":actor,"actor":true,"placement_class":"standing_person"},{"identity":SOUTH,"semantic":south,"actor":true,"placement_class":"standing_person"}])
		if not check(bool(bound.get("ok",false)),"exact actor binding succeeds: "+JSON.stringify(bound.get("errors",[]))): continue
		var bindings: Dictionary = bound.get("slot_bindings",{})
		check(str(bindings[identity].slot_id) == "scenario.local_standing_person_1" and str(bindings[SOUTH].slot_id) == "scenario.local_standing_person_2","alternatives retain exact distinct local slots")
		var left_rect := _array_rect(bindings[identity].slot.hit_rect)
		var right_rect := _array_rect(bindings[SOUTH].slot.hit_rect)
		check(left_rect.get_center().x < 450 and right_rect.get_center().x > 450,"left/right semantic sides match actual placement")
		check(BOARD.encloses(left_rect) and BOARD.encloses(right_rect),"static actor footprints stay inside board")
		var canvas := Canvas.new()
		canvas.size = Vector2(900,430)
		root.add_child(canvas)
		canvas.set_process(false)
		canvas.uses_foundation_snapshot = true
		canvas.foundation_snapshot = environment.duplicate(true)
		var records := [_record(identity,str(labels[index]),left_rect,str(bindings[identity].slot_id)),_record(SOUTH,"South observer",right_rect,str(bindings[SOUTH].slot_id))]
		var leave := _slot(surface,"exit.door_curtain")
		var leave_record := _record("travel:leave","Leave",_array_rect(leave.get("hit_rect",[])),"exit.door_curtain")
		leave_record["object_type"] = "travel"
		leave_record["visual_type"] = "travel"
		leave_record["slot_family"] = "exit"
		records.append(leave_record)
		canvas.foundation_scene_objects = canvas.call("_objects_from_interactable_records",records)
		canvas.call("_rebuild_scene_object_cache")
		_check_canvas_geometry(canvas,identity,"synthetic_"+str(index))
		canvas.free()
	check(environment == before,"binding/geometry projections preserve fixture state")

func _record(identity: String, label: String, rect: Rect2, slot_id: String) -> Dictionary:
	return {"object_id":identity,"object_type":"scenario_actor","visual_type":"character","label":label,"normalized_rect":{"x":rect.position.x/900,"y":rect.position.y/430,"w":rect.size.x/900,"h":rect.size.y/430},"fixed_slot_geometry":true,"scenario_layout_resolved":true,"slot_id":slot_id,"slot_family":"scenario","placement_class":"standing_person","interactive":true,"visible":true}

func _slot(surface: Dictionary, id: String) -> Dictionary:
	for value in Placement.all_slots(surface):
		if str(value.get("id","")) == id: return value
	return {}

func _captured_restore() -> void:
	if not _install_bundle(): return
	var reference: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(reference is RunState,"official SaveService loads original diagnostic copy"): return
	var expected := _protected(reference)
	facts["original_protected"] = expected.duplicate(true)
	root.size = Vector2i(1280,720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if not check(app.load_foundation_run(),"normal host Continue accepts original K copy"):
		app.queue_free()
		await process_frame
		return
	for frame in range(3): await process_frame
	app.set_process(false)
	check(_equal(_protected(app.run_state),expected),"normal Continue preserves exact accounting/history/receipts/RNG")
	check(app.run_state.bankroll == 6 and app.run_state.suspicion_level() == 0,"original warned state keeps cash6/Heat0")
	_check_canvas_geometry(app.environment_canvas,WARNED,"captured_continue")
	_classify_remaining_observers(app.environment_canvas)
	_check_canvas_geometry(app.environment_canvas,WARNED,"captured_settled")
	app.environment_canvas.small_screen_mode = true
	app.environment_canvas.call("_rebuild_scene_object_cache")
	_check_canvas_geometry(app.environment_canvas,WARNED,"captured_small_screen")
	app.environment_canvas.small_screen_mode = false
	app.environment_canvas.call("_rebuild_scene_object_cache")
	check(_equal(_protected(app.run_state),expected),"geometry/transit sampling cannot settle or reroll")
	app.save_service.wait_for_async_save()
	var save_error: Error = app.save_service.save_run(app.run_state,"vis020_after_geometry")
	check(save_error == OK,"normal official save accepts corrected layout")
	var restored: Variant = SaveService.new().load_run("vis020_after_geometry") if save_error == OK else null
	check(restored is RunState,"fresh SaveService restores corrected layout")
	if restored is RunState: check(_equal(_protected(restored),expected),"fresh-service restore preserves exact protected state")
	facts["after_protected"] = _protected(app.run_state)
	facts["current_authority"] = app.run_state.current_environment.get("scenario_layout_authority",{}).get(WARNED,{})
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame

func _check_canvas_geometry(canvas: PixelSceneCanvas, actor_id: String, tag: String) -> void:
	var layout: Dictionary = canvas.current_view_snapshot().get("object_layout",{})
	var actor := _layout_object(layout,actor_id)
	var leave := _layout_object(layout,"travel:leave")
	if not check(not actor.is_empty() and not leave.is_empty(),tag+" actor and Leave render once"): return
	var actor_rect := _rect(actor.get("rect",{}))
	var label_rect := _rect(actor.get("label_rect",{}))
	var leave_label := _rect(leave.get("label_rect",{}))
	check(actor_rect.get_center().x < 450,tag+" warned/left actor is in left corridor")
	check(BOARD.encloses(actor_rect) and label_rect.has_area() and BOARD.encloses(label_rect),tag+" actor and label stay inside room bounds")
	check(not label_rect.intersects(leave_label),tag+" actor label avoids Leave label")
	var occurrences := 0
	for value in layout.get("objects",[]):
		if str(value.get("id","")) == actor_id: occurrences += 1
	check(occurrences == 1,tag+" actor has no duplicate display identity")
	check(_rect(leave.get("interaction_rect",{})).has_area(),tag+" ordinary Leave retains hit target")
	facts[tag] = {"actor":actor,"leave":leave,"label_stats":layout.get("label_layout",{}),"small_screen":canvas.small_screen_mode}

func _classify_remaining_observers(canvas: PixelSceneCanvas) -> void:
	var observers: Array = []
	for value in canvas.call("_active_scene_objects"):
		var id := str(value.get("id",""))
		if id.ends_with("motel_stakeout_south_observer") or id.ends_with("motel_stakeout_north_observer"):
			observers.append({"id":id,"transit_active":value.get("person_transit_active",false),"transit_kind":value.get("person_transit_kind",""),"route":value.get("actor_route_stage",{})})
	facts["remaining_observers_before"] = observers
	if observers.is_empty(): return
	for observer in observers: check(bool(observer.transit_active) and str(observer.transit_kind) == "departure","removed observer is a departure transient")
	# Advance only the existing canvas presentation clock, never the run clock.
	# This identifies the8second transit boundary without consuming real game turns.
	canvas.actor_route_time += Canvas.PERSON_TRANSIT_MAX_DURATION_SEC + 1.0
	canvas.call("_advance_person_transits")
	var remaining: Array = []
	for value in canvas.call("_active_scene_objects"):
		var id := str(value.get("id",""))
		if id.ends_with("motel_stakeout_south_observer") or id.ends_with("motel_stakeout_north_observer"): remaining.append(id)
	check(remaining.is_empty(),"departed observers disappear after existing presentation deadline")
	facts["remaining_observers_after_test_clock"] = remaining

func _layout_object(layout: Dictionary, id: String) -> Dictionary:
	for value in layout.get("objects",[]):
		if str(value.get("id","")) == id: return value
	return {}

func _protected(run: RunState) -> Dictionary:
	var snapshot := run.to_save_snapshot()
	var result: Dictionary = {}
	for key in ["bankroll","grand_casino_chips","rng_seed","rng_state","game_clock_minutes","inventory","story_log","suspicion","event_cadence","crew_state","run_spending_score","narrative_flags","active_delivery_run","drunk_level","alcoholic_level","pending_drunk_absorption","run_status","run_failure_reason"]:
		if snapshot.has(key): result[key] = snapshot[key]
	var environment := run.current_environment
	for key in ["turns","resolved_event_ids","event_ids","game_ids","item_offers","scenario_state","scenario_phase_index","scenario_phase_action_counter"]:
		if environment.has(key): result["environment/"+key] = environment[key]
	var sequence: Dictionary = environment.get("scenario_sequence_state",{}).duplicate(true)
	sequence.erase("semantic_state")
	result["sequence_receipts_and_progress"] = sequence
	return result

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK,"install private unchanged "+name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user_dir.path_join(".crew_host_authority_v1")) == OK,"install unchanged host key"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["",".bak"]:
			var original := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original,OS.get_environment(pair[1])+suffix) == OK,"install unchanged companion"): return false
	return true

func _array_rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3])) if value.size() >= 4 else Rect2()

func _rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.get("x",0)),float(value.get("y",0)),float(value.get("w",0)),float(value.get("h",0)))

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key],right[key]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Synthetic exact-slot binding/canvas geometry plus optional actual untouched K13/K14 official host Continue and fresh SaveService restore. No OS pointer/browser or separate-process cold UI claim. Only existing presentation clock advanced if removed observers need transient classification; no game clock/RNG/action edits."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("MOTEL_STAKEOUT_LAYOUT checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
