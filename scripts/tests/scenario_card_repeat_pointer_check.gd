extends SceneTree
const Canvas=preload("res://scripts/ui/pixel_scene_canvas.gd")
class RebuiltCard extends Canvas:
	var commands: Array[String]=[]
	var next_command="Brace Exit"
	func _activate_selected_info_action_at_local_position(_position: Vector2) -> bool:
		commands.append(next_command)
		next_command="Refuse the task"
		return true
class RoomFocus extends Canvas:
	var activated: Array[String]=[]
	func _activate_object_at_local_position(_position: Vector2, intended_object_id: String = "") -> void:
		activated.append(intended_object_id)
var failures: Array[String]=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for touch in [false,true]:
		var canvas=RebuiltCard.new();root.add_child(canvas);canvas.selected_object_id="door"
		for repeated in [false,true]:
			var event: InputEvent
			if touch:
				var e=InputEventScreenTouch.new();e.index=0;e.position=Vector2(210,210);e.pressed=true;e.double_tap=repeated;event=e
			else:
				var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=Vector2(60,60);e.pressed=true;e.double_click=repeated;event=e
			canvas._gui_input(event)
			if not repeated:await process_frame
		check(canvas.commands==["Brace Exit"],"second press activated rebuilt card (touch=%s): %s" % [touch,canvas.commands])
		var fresh: InputEvent
		if touch:
			var e=InputEventScreenTouch.new();e.index=0;e.position=Vector2(210,210);e.pressed=true;fresh=e
		else:
			var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=Vector2(60,60);e.pressed=true;fresh=e
		canvas._gui_input(fresh)
		check(canvas.commands==["Brace Exit","Refuse the task"],"fresh deliberate press was blocked (touch=%s)" % touch)
		canvas.queue_free();await process_frame
	var room=RoomFocus.new();root.add_child(room)
	room._begin_room_pointer_focus_gesture("mouse",false,Vector2.ZERO)
	room.selected_object_id="original";room._remember_room_pointer_focus("mouse")
	check(room._begin_room_pointer_focus_gesture("mouse",true,Vector2.ONE) and room.activated==["original"],"room double-click lost its original object")
	room._begin_room_pointer_focus_gesture("mouse",false,Vector2.ZERO)
	room.selected_object_id="old_room";room._remember_room_pointer_focus("mouse")
	room.interaction_context_generation+=1
	check(room._begin_room_pointer_focus_gesture("mouse",true,Vector2.ONE) and room.activated==["original"],"double-click crossed room transition")
	room._begin_room_pointer_focus_gesture("mouse",false,Vector2.ZERO)
	room.selected_object_id="fresh";room._remember_room_pointer_focus("mouse")
	check(room._begin_room_pointer_focus_gesture("mouse",true,Vector2.ONE) and room.activated==["original","fresh"],"fresh room gesture was blocked")
	room.queue_free();await process_frame
	print("SCENARIO_CARD_REPEAT_POINTER checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
