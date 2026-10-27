extends SceneTree
const Controller=preload("res://scripts/ui/environment_interaction_controller.gd")
const Model=preload("res://scripts/ui/scenario_semantic_view_model.gd")
const Canvas=preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _initialize() -> void:
	var brace={"id":"brace_exit","label":"Brace Exit","enabled":true,"attached_owner_namespace":"scenario","attached_stable_object_id":"task_0","action_origin_receipt_key":"receipt","action_origin_boundary_id":"arrival","action_origin_fingerprint":"proof"}
	var interaction={"owner_namespace":"scenario","stable_object_id":"door","enabled":true,"available_actions":[{"id":"refuse","label":"Refuse"},brace,{"id":"fail","label":"Let the fight spread"}]}
	var authority={"presentation_object_id":"scenario::door"}
	var before=interaction.duplicate(true)
	var record=Controller._merge_projected_interaction({},interaction,authority,"",7)
	check(record.inline_actions.size()==3,"physical multi-action record collapsed to first action")
	var canvas=Canvas.new();canvas.selected_object_id=record.object_id
	var choices=canvas._selected_info_inline_actions({"id":record.object_id,"inline_actions":record.inline_actions})
	check(choices.map(func(a):return a.label)==["Refuse","Brace Exit","Let the fight spread"],"mouse card choices: %s (selected %s / host %s)" % [JSON.stringify(choices),canvas.selected_object_id,record.object_id])
	var token=str(record.inline_actions[1].emit_object_id)
	var descriptor=Model.action_descriptor_for_token([record],token)
	check(descriptor.get("sequence_action",{})==brace,"mouse token lost exact sequence action/proof")
	check(descriptor.get("sequence_record",{}).get("object_id")==record.object_id,"mouse token changed physical host")
	check(record.inline_actions[1].scenario_stable_object_id=="task_0","attached task origin was replaced by door host")
	check(Model.action_descriptor_for_token([record],token+"forged").is_empty(),"unknown token accepted")
	var next=Controller._merge_projected_interaction({},interaction,authority,"",8)
	check(Model.action_descriptor_for_token([next],token).is_empty(),"previous-boundary token remained live")
	var disabled=interaction.duplicate(true);disabled.available_actions[1].enabled=false
	var disabled_record=Controller._merge_projected_interaction({},disabled,authority,"",7)
	check(Model.action_descriptor_for_token([disabled_record],token).is_empty(),"disabled action accepted")
	var hidden=interaction.duplicate(true);hidden.available_actions[1].hidden=true
	var hidden_record=Controller._merge_projected_interaction({},hidden,authority,"",7)
	check(hidden_record.inline_actions.size()==2,"hidden action became a visible mouse choice")
	check(Model.action_descriptor_for_token([hidden_record],token).is_empty(),"hidden action got a live token")
	var single=interaction.duplicate(true);single.available_actions=[brace]
	check(Controller._merge_projected_interaction({},single,authority,"",7).get("inline_actions",[]).is_empty(),"single-action fallback changed")
	var world=interaction.duplicate(true);world.world_sequence_owner_token="crew_world"
	check(Controller._merge_projected_interaction({},world,authority,"",7).get("inline_actions",[]).is_empty(),"world dispatch changed")
	check(interaction==before,"projection modified authored action input")
	canvas.free()
	print("SCENARIO_MULTI_ACTION_MOUSE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
