extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	# Actual Bar anchors: the expanded six-reel/five-row cabinet's empty right
	# margin overlapped the visible rumor contact at board point (148,154).
	for spec in [["classic_3_reel",3,1],["line_5x3",5,3],["video_feature",5,3],["video_feature",6,5]]:
		var canvas := Canvas.new()
		canvas.size=Vector2(900,430)
		root.add_child(canvas)
		var staff := {"id":"event:town_rumor_staff","type":"event","label":"Word from Across Town","interactive":true,"scenario_layout_resolved":true,"placement_class":"behind_counter_person","position":Vector2(149.0/900.0,157.0/430.0),"size":Vector2(72,72)}
		var slot := {"id":"game:slot","type":"game","label":"Slot","interactive":true,"scenario_layout_resolved":true,"placement_class":"surface_item","position":Vector2(74.0/900.0,154.0/430.0),"size":Vector2(72,48),"visual_state":{"machine_format":spec[0],"reel_count":spec[1],"row_count":spec[2]}}
		canvas.scene_objects=[staff,slot]
		canvas.scene_object_cache_valid=false
		var original := var_to_str([staff,slot])
		var slot_anchor: Rect2=canvas._board_rect_for_object(slot)
		var model: Rect2=canvas._natural_model_rect_for_object(slot)
		var drawn: Dictionary=canvas._slot_prop_static_layer(model,slot,Color.WHITE)
		var hit: Rect2=canvas._interaction_rect_for_object(slot)
		var label := "%s %sx%s" % [spec[0],spec[1],spec[2]]
		for part in ["body","topper","deck","base"]:
			var visible_part: Rect2=drawn[part]
			_check(hit.has_point(visible_part.get_center()),"%s visible %s remains clickable." % [label,part])
		_check(canvas._interaction_rect_for_object(staff)==Rect2(113,121,72,72),"%s preserves the staff hit region." % label)
		var contact_point := canvas._board_to_local_position(Vector2(148,154))
		_check(canvas.object_id_at_local_position(contact_point)=="event:town_rumor_staff","%s empty cabinet margin must not steal the visible staff click." % label)
		var activated: Array[String]=[]
		canvas.object_activated.connect(func(id: String): activated.append(id))
		canvas._activate_object_at_local_position(contact_point)
		_check(activated==["event:town_rumor_staff"],"%s fresh contact activation reaches staff once." % label)
		var cabinet_point := canvas._board_to_local_position((drawn.body as Rect2).get_center())
		canvas._activate_object_at_local_position(cabinet_point)
		_check(activated==["event:town_rumor_staff","game:slot"],"%s deliberate cabinet activation stays usable." % label)
		_check(canvas._board_rect_for_object(slot)==slot_anchor and var_to_str([staff,slot])==original,"%s hit testing preserves authored anchors and visual state." % label)
		canvas.free()
	# Objects without a slot visual retain their existing full model hit region.
	var plain := Canvas.new()
	plain.size=Vector2(900,430);root.add_child(plain)
	var prop := {"id":"service:plain","interactive":true,"scenario_layout_resolved":true,"position":Vector2(0.5,0.5),"size":Vector2(72,48)}
	_check(plain._interaction_rect_for_object(prop)==plain._natural_model_rect_for_object(prop),"Non-slot model hit regions remain unchanged.")
	plain.free()
	print("SLOT_CABINET_POINTER_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
