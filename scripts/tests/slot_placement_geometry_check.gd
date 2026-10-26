extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Store := preload("res://scripts/core/developer_placement_store.gd")
const BOARD := Vector2(900,430)
const REGULAR_MODEL := Vector2(116,88)
const REGULAR_FRAME := Vector2(83.52,80.96)
var checks := 0
var failures: Array[String]=[]
var samples: Array=[]

func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/slot_placement_geometry_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var private_path := temp_root.path_join("user-%d-%d.json" % [OS.get_process_id(),int(Time.get_unix_time_from_system()*1000000)])
	_check(not FileAccess.file_exists(private_path),"Fresh private placement fixture required")
	if FileAccess.file_exists(private_path):quit(64);return
	OS.set_environment(Store.USER_PATH_ENV,private_path)
	Store.reload()
	var canvas := Canvas.new();canvas.size=BOARD;root.add_child(canvas)
	await process_frame
	for spec in [["bar","fixed.random_game_1"],["gas_station_casino","fixed.random_game_1"],["grand_casino","fixed.game_machine_1"]]:
		var environment := {"id":spec[0],"archetype_id":spec[0]}
		for scale in [1.0,0.5,1.5]:
			var saved := Store.save_slot_scale(environment,spec[1],scale)
			_check(bool(saved.get("ok",false)),"Private scale persists for %s" % spec[0])
			var surface := Placement.surface_map(environment)
			var slot: Dictionary={}
			for value in surface.get("fixed_slots",[]):
				if str(value.get("id",""))==spec[1]:slot=value;break
			_check(not slot.is_empty(),"Authored game slot exists in %s" % spec[0])
			if slot.is_empty():continue
			var a: Array=slot.hit_rect
			var rect := Rect2(a[0],a[1],a[2],a[3])
			for format in [["classic_3_reel",3,1],["line_5x3",5,3],["video_feature",5,3],["video_feature",6,5],["",3,1]]:
				var record := {"object_id":"game:slot","source_id":"slot","object_type":"game","visual_type":"game","label":"Slot","slot_id":spec[1],"slot_family":"fixed","fixed_slot_geometry":true,"interactive":true,"enabled":true,"placement_class":slot.footprint_class,"normalized_rect":{"x":rect.position.x/BOARD.x,"y":rect.position.y/BOARD.y,"w":rect.size.x/BOARD.x,"h":rect.size.y/BOARD.y},"visual_state":{"machine_family":"pinball","machine_format":format[0],"reel_count":format[1],"row_count":format[2]}}
				canvas.render_environment_snapshot({"id":spec[0],"archetype_id":spec[0],"interactable_objects":[record]})
				canvas.set_developer_slot_placement_mode(true)
				canvas.developer_slot_selected_id=spec[1]
				var live_slot: Dictionary=canvas._developer_slot(spec[1])
				var object: Dictionary=canvas._scene_object("game:slot")
				var model: Rect2=canvas._natural_model_rect_for_object(object)
				var frame: Rect2=canvas._slot_cabinet_frame_rect(model)
				var editor: Rect2=canvas._developer_slot_visual_rect(live_slot)
				var label := "%s %s %sx%s %s%%" % [spec[0],format[0],format[1],format[2],int(scale*100)]
				_check(model.size.is_equal_approx(REGULAR_MODEL*scale),label+" uses literal common regular model scale")
				_check(frame.size.is_equal_approx(REGULAR_FRAME*scale),label+" has the same physical cabinet baseline")
				_check(editor.is_equal_approx(frame),label+" movable bounds match the drawn cabinet frame")
				var drawn: Dictionary=canvas._slot_prop_static_layer(model,object,Color.WHITE)
				_check((drawn.body as Rect2).size.is_equal_approx(REGULAR_FRAME*Vector2(0.84,0.73)*scale),label+" preserves common visible housing dimensions")
				_check((drawn.topper as Rect2).size.is_equal_approx(REGULAR_FRAME*Vector2(0.92,0.15)*scale),label+" preserves common visible topper dimensions")
				for zoom in [1.0,1.6]:
					canvas.camera_zoom=zoom;canvas.target_camera_zoom=zoom
					canvas.camera_offset=canvas._camera_offset_for_focus(frame.get_center()/BOARD,zoom)
					canvas.target_camera_offset=canvas.camera_offset
					_check(canvas._board_rect_to_local_rect(editor).is_equal_approx(canvas._board_rect_to_local_rect(frame)),label+" zoom%s preserves matching screen bounds" % zoom)
					var edge := canvas._board_to_local_position(frame.position+Vector2(2,2))
					_check(canvas._developer_slot_id_at_local_position(edge)==spec[1],label+" zoom%s selects the visible cabinet edge" % zoom)
					_check(canvas._natural_model_rect_for_object(object).is_equal_approx(model),label+" zoom%s does not change physical size" % zoom)
				_check(canvas._interaction_rect_for_object(object).has_point(frame.get_center()),label+" ordinary interaction stays aligned")
				samples.append({"environment":spec[0],"format":format[0],"reels":format[1],"rows":format[2],"scale":scale,"model_size":[model.size.x,model.size.y],"frame_size":[frame.size.x,frame.size.y],"editor_size":[editor.size.x,editor.size.y]})
	_check_drag_resize_reopen(canvas)
	canvas.free()
	OS.set_environment(Store.USER_PATH_ENV,"");Store.reload()
	print("SLOT_PLACEMENT_GEOMETRY "+JSON.stringify({"fidelity":"Native real canvas adjustment-mode geometry with isolated placement store and authored slots; synthetic cabinets, not Web pixels","checks":checks,"failure_count":failures.size(),"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _check_drag_resize_reopen(canvas: Control) -> void:
	canvas.developer_placement_lock_requested.connect(_persist_position)
	canvas.developer_slot_scale_requested.connect(_persist_scale)
	canvas.set_developer_slot_edit_shared_in_scenario(true)
	var slot_id := "fixed.game_machine_1"
	var slot: Dictionary=canvas._developer_slot(slot_id)
	var original: Rect2=canvas._developer_slot_rect(slot)
	var before: Rect2=canvas._developer_slot_visual_rect(slot)
	canvas._begin_developer_slot_placement_drag(canvas._board_to_local_position(before.position+Vector2(3,3)))
	_check(canvas.developer_slot_dragging,"Drag begins at the visible cabinet edge outside the compact anchor")
	var delta := Vector2(16,8)
	canvas._update_developer_slot_placement_preview(original.position+delta)
	var pending: Rect2=canvas._developer_slot_visual_rect(slot,canvas.developer_slot_pending_rect)
	var model: Rect2=canvas._natural_model_rect_for_object(canvas._scene_object("game:slot"))
	_check(pending.is_equal_approx(Rect2(before.position+delta,before.size)),"Drag translates the cabinet frame without resizing it")
	_check(pending.is_equal_approx(canvas._slot_cabinet_frame_rect(model)),"Draw and selection stay aligned during the drag")
	_check(canvas.developer_slot_valid,"Focused authored cabinet move has a valid release")
	var wanted_position: Vector2=canvas.developer_slot_pending_position
	canvas._finish_developer_slot_placement_edit()
	slot=canvas._developer_slot(slot_id)
	_check(canvas._developer_slot_position(slot).is_equal_approx(wanted_position),"Release persists exactly the requested authored anchor")
	_check(canvas._developer_slot_visual_rect(slot).is_equal_approx(pending),"Locked cabinet remains aligned after local refresh")
	canvas.developer_slot_scale_increase_button.pressed.emit()
	_check(is_equal_approx(canvas._developer_slot_object_scale(canvas._developer_slot(slot_id)),1.6),"Supported plus control persists one scale step")
	canvas.developer_slot_scale_reset_button.pressed.emit()
	_check(is_equal_approx(canvas._developer_slot_object_scale(canvas._developer_slot(slot_id)),1.0),"Supported percentage control restores the common 100 percent baseline")
	canvas.developer_slot_scale_decrease_button.pressed.emit()
	_check(is_equal_approx(canvas._developer_slot_object_scale(canvas._developer_slot(slot_id)),0.9),"Supported minus control persists one scale step")
	var saved_frame: Rect2=canvas._developer_slot_visual_rect(canvas._developer_slot(slot_id))
	_check(saved_frame.size.is_equal_approx(REGULAR_FRAME*0.9),"Resized cabinet bounds use the literal percentage")
	Store.reload()
	var environment := {"id":"grand_casino","archetype_id":"grand_casino"}
	var reopened_slot: Dictionary={}
	for value in Placement.surface_map(environment).fixed_slots:
		if str(value.get("id",""))==slot_id:reopened_slot=value;break
	var a: Array=reopened_slot.hit_rect
	var snapshot: Dictionary=canvas.foundation_snapshot.duplicate(true)
	(snapshot.interactable_objects[0] as Dictionary).normalized_rect={"x":a[0]/BOARD.x,"y":a[1]/BOARD.y,"w":a[2]/BOARD.x,"h":a[3]/BOARD.y}
	var reopened := Canvas.new();reopened.size=BOARD;root.add_child(reopened)
	reopened.render_environment_snapshot(snapshot)
	reopened.set_developer_slot_placement_mode(true)
	reopened.developer_slot_selected_id=slot_id
	var reopened_frame: Rect2=reopened._developer_slot_visual_rect(reopened._developer_slot(slot_id))
	_check(reopened_frame.is_equal_approx(saved_frame),"Fresh placement store and canvas preserve position, scale and frame on reopen")
	reopened.set_developer_slot_placement_mode(false)
	var activated: Array[String]=[]
	reopened.object_activated.connect(func(id: String):activated.append(id))
	reopened._activate_object_at_local_position(reopened._board_to_local_position(reopened_frame.get_center()))
	_check(activated==["game:slot"],"Fresh ordinary click after reopen reaches the moved cabinet exactly once")
	reopened.free()

func _persist_position(request: Dictionary) -> void:
	request._placement_lock_handled=true
	request._placement_lock_persisted=bool(Store.save_position(request.environment,"slot_positions",request.slot_id,request.position).get("ok",false))
	_check(request._placement_lock_persisted,"Drag release writes only the isolated user placement store")

func _persist_scale(request: Dictionary) -> void:
	request._slot_scale_handled=true
	request._slot_scale_persisted=bool(Store.save_slot_scale(request.environment,request.slot_id,request.scale).get("ok",false))
	_check(request._slot_scale_persisted,"Scale control writes only the isolated user placement store")

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
