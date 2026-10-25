extends SceneTree
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _person(id: String, slot_id: String, contact: bool = false) -> Dictionary:
	var surface := Placement.surface_map({"archetype_id":"pawn_shop"})
	var slot := {}
	for value in surface.get("event_slots",[]):
		if str(value.get("id",""))==slot_id: slot=value
	var binding := {"slot":slot,"slot_id":slot_id,"placement_class":"standing_person","slot_family":"event","presentation_mode":"room"}
	var rect := Binder.normalized_rect(Binder.rect_from_binding(binding))
	return {"object_id":id,"object_type":"character","visual_type":"character","label":"Waiting contact" if contact else "Ambient person","visible":true,"interactive":true,"enabled":true,"delivery_contact":contact,"placement_class":"standing_person","slot_id":slot_id,"slot_family":"event","presentation_mode":"room","fixed_slot_geometry":true,"normalized_rect":rect,"small_screen_rect":rect.duplicate(true)}
func _room(records: Array) -> Dictionary:
	return {"id":"delivery_contact_arrival_fixture","archetype_id":"pawn_shop","world_node_id":"pawn_shop","environment_visit_id":"same_visit","interactable_objects":records,"reduce_motion":false}
func _object(canvas, id: String) -> Dictionary:
	for value in canvas.foundation_scene_objects:
		if str(value.get("id",""))==id: return value
	return {}
func _run() -> void:
	# Synthetic renderer records use real authored Pawn slots. No game clock,
	# delivery authority, money, RNG or player save is changed by this check.
	var canvas = Canvas.new()
	canvas.render_environment_snapshot(_room([]))
	var contact := _person("crew::package_handoff","event.standing_person_4",true)
	var ambient := _person("ambient:visitor","event.standing_person_2")
	var changed := _room([contact,ambient]); var before := JSON.stringify(changed)
	canvas.render_environment_snapshot(changed)
	var waiting := _object(canvas,"crew::package_handoff")
	_check(bool(waiting.get("delivery_contact",false)),"Contact flag was lost between the host record and canvas")
	_check(not bool(waiting.get("person_transit_active",false)),"Waiting delivery contact started a noninteractive walk-in")
	_check(bool(waiting.get("interactive",false)),"Waiting contact lost its host-provided interaction")
	_check((canvas._interaction_rect_for_object(waiting) as Rect2).has_area(),"Waiting contact has no usable target")
	_check(bool(_object(canvas,"ambient:visitor").get("person_transit_active",false)),"Ordinary ambient arrival stopped animating")
	_check(canvas.person_transit_ids.size()==1,"Waiting contact consumed ambient arrival capacity")
	_check(JSON.stringify(changed)==before,"Renderer mutated the authoritative input record")
	canvas.render_environment_snapshot(changed)
	_check(not canvas.person_transit_ids.has("crew::package_handoff"),"Refresh restarted the waiting contact's arrival")
	canvas.actor_route_time=20.0;canvas._advance_person_transits()
	_check(bool(_object(canvas,"ambient:visitor").get("interactive",false)),"Ambient arrival did not settle normally")
	canvas.render_environment_snapshot(_room([contact]))
	_check(str(_object(canvas,"ambient:visitor").get("person_transit_kind",""))=="departure","Ambient departure stopped animating")
	var promoted = Canvas.new(); promoted.render_environment_snapshot(_room([]))
	var person := _person("existing:recipient","event.standing_person_4")
	promoted.render_environment_snapshot(_room([person]))
	_check(bool(_object(promoted,"existing:recipient").get("person_transit_active",false)),"Promotion fixture did not first arrive normally")
	person["delivery_contact"]=true;promoted.render_environment_snapshot(_room([person]))
	_check(not promoted.person_transit_ids.has("existing:recipient") and bool(_object(promoted,"existing:recipient").get("interactive",false)),"A newly designated recipient retained its previous arrival lock")
	var unavailable = Canvas.new();unavailable.render_environment_snapshot(_room([]))
	var closed := contact.duplicate(true);closed["interactive"]=false;closed["enabled"]=false
	unavailable.render_environment_snapshot(_room([closed]))
	_check(not bool(_object(unavailable,"crew::package_handoff").get("interactive",true)),"Presentation enabled an unavailable host action")
	canvas.free();promoted.free();unavailable.free()
	if failures.is_empty(): print("DELIVERY_CONTACT_ARRIVAL PASS checks=",checks);quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
