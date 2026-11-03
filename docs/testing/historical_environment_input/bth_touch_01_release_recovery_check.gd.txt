extends SceneTree
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []
var baseline := false
func _init() -> void: call_deferred("_run")
func _frames(n: int = 2) -> void:
	for i in range(n): await process_frame
func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new();e.index=index;e.position=point;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func _snapshot(id: String) -> Dictionary:
	return {"id":id,"archetype_id":"back_alley","environment_visit_id":id,"reduce_motion":true,"interactable_objects":[{"object_id":"event:target","object_type":"event","visual_type":"event","source_id":"target","label":"Target","interactive":true,"enabled":true,"normalized_rect":{"x":0.25,"y":0.34,"w":0.18,"h":0.22}}]}
func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _run() -> void:
	baseline=OS.get_environment("BTH_TOUCH01_EXPECT_BASELINE")=="1"
	root.size=Vector2i(1280,720)
	for reused in [false,true]:
		var canvas := Canvas.new();root.add_child(canvas);canvas.size=Vector2(1080,580);canvas.position=Vector2(80,100)
		canvas.render_environment_snapshot(_snapshot("old_room"));canvas.reduce_motion=true
		await _frames()
		var counts := {"focus":0,"activate":0}
		canvas.object_focused.connect(func(_id):counts.focus+=1)
		canvas.object_activated.connect(func(_id):counts.activate+=1)
		var target: Dictionary=canvas._scene_object("event:target")
		var local: Vector2=canvas._board_to_local_position(canvas._interaction_rect_for_object(target).get_center())
		var point: Vector2=canvas.get_global_transform_with_canvas()*local
		_touch(0,point,true);await _frames()
		_check(canvas.selected_object_id=="event:target","real initial ScreenTouch reaches offset canvas")
		canvas.render_environment_snapshot(_snapshot("new_room"));await _frames()
		_check(canvas.arrival_touch_releases_pending.has(0) and canvas.selected_object_id.is_empty(),"transition quarantines original held finger")
		var drag := InputEventScreenDrag.new();drag.index=0;drag.position=point;drag.relative=Vector2(1,0);Input.parse_input_event(drag);Input.flush_buffered_events();await _frames()
		_check(canvas.selected_object_id.is_empty() and counts.activate==0,"held old-finger drag cannot select or activate incoming room")
		var next_index := 0 if reused else 1
		var before: int=counts.focus
		# Browser/OS lost the old release. This physical pressed event is a new gesture.
		_touch(next_index,point,true);await _frames()
		facts.append({"reused_index":reused,"selected":canvas.selected_object_id,"pending":canvas.arrival_touch_releases_pending.duplicate(),"focus_delta":counts.focus-before,"activation_count":counts.activate})
		if baseline:
			_check(canvas.selected_object_id.is_empty(),"shipped source reproduces permanent room-focus block after missing release")
		else:
			_check(canvas.selected_object_id=="event:target" and counts.focus==before+1,"fresh physical touch focuses incoming room exactly once despite missing old release")
		_check(counts.activate==0,"selection never commits an object action")
		_touch(next_index,point,false);_touch(0,point,false);await _frames()
		canvas.queue_free();await _frames()
	print("BTH_TOUCH_01_RECOVERY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"baseline_reproduction":baseline,"facts":facts,"input":"Input.parse_input_event actual ScreenTouch and generated emulated mouse; no direct _gui_input calls","campaign_state":"none"}))
	quit(0 if failures.is_empty() else 1)
