extends SceneTree
class DrawSpy:
	extends "res://scripts/ui/pixel_scene_canvas.gd"
	var roster_draws := 0
	var procedural_draws := 0
	func _scale_canvas() -> void: pass
	func _draw_object_shadow(_rect: Rect2, _active: bool, _kind: String) -> void: pass
	func _draw_character_actor(_rect: Rect2, _object: Dictionary) -> void: roster_draws += 1
	func _draw_scenario_actor(_rect: Rect2, _object: Dictionary, _active: bool) -> void: procedural_draws += 1

var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	# Exercise real host-record -> canvas projection -> painter dispatch, replacing
	# only the final drawing calls with spies. This is not visual Web evidence.
	var canvas := DrawSpy.new()
	var source := {"object_id":"crew::package_handoff","object_type":"character","visual_type":"character","label":"The Shop Contact","delivery_contact":true,"interactive":true,"enabled":true,"placement_class":"standing_person","slot_id":"event.standing_person_4","slot_family":"event","fixed_slot_geometry":true,"manifest_physical":true,"manifest_render_key":"rowdy_regular","normalized_rect":{"x":0.711111,"y":0.772093,"w":0.071111,"h":0.190698}}
	var original := JSON.stringify(source)
	var projected: Dictionary = canvas._objects_from_interactable_records([source])[0]
	canvas._draw_scene_object_body(projected)
	_check(canvas.procedural_draws==1 and canvas.roster_draws==0,"Contact without a roster portrait had no person painter")
	_check(JSON.stringify(source)==original,"Drawing changed the authoritative record")
	canvas.roster_draws=0;canvas.procedural_draws=0
	projected["character_actor"]={"members":[{"character_id":"existing_recipient"}]}
	canvas._draw_scene_object_body(projected)
	_check(canvas.roster_draws==1 and canvas.procedural_draws==0,"Existing contact portrait was replaced")
	canvas.roster_draws=0;canvas.procedural_draws=0
	projected["character_actor"]={};projected["delivery_contact"]=false
	canvas._draw_scene_object_body(projected)
	_check(canvas.roster_draws==1 and canvas.procedural_draws==0,"Fallback changed unrelated character dispatch")
	canvas.roster_draws=0;canvas.procedural_draws=0
	projected["delivery_contact"]=true;projected["disabled"]=true
	canvas._draw_scene_object_body(projected)
	_check(canvas.procedural_draws==1,"Unavailable waiting recipient lost its visible person")
	_check(bool(projected.get("disabled",false)),"Drawing enabled an unavailable recipient")
	canvas.free()
	if failures.is_empty(): print("DELIVERY_CONTACT_RENDER PASS checks=",checks);quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
