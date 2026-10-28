extends SceneTree

const Host:=preload("res://scripts/ui/foundation_main.gd")
const Controller:=preload("res://scripts/ui/environment_interaction_controller.gd")
class Observer extends Host:
	var publication_stages:Array=[]
	func _prepare_room_presentation_at_boundary()->void:
		var before:=_stage()
		super._prepare_room_presentation_at_boundary()
		if publication_stages.size()<20:publication_stages.append({"before":before,"after":_stage()})
	func _stage()->Dictionary:
		if run_state==null:return {"run":false,"screen":current_screen}
		var publication:=run_state.room_presentation_snapshot()
		var finalized:Dictionary=publication.get("finalized",{})
		var projection_errors:Array=[]
		if not bool(finalized.get("inactive",true)):
			projection_errors=Controller.project_finalized_sequence_interaction_result(finalized.get("records",[]),finalized).get("errors",[])
		var room_count:=0
		var rejection:=""
		for row in room_catalog_snapshot():
			if str(row.get("presentation_mode","room"))=="room" and not bool(row.get("room_geometry_rejected",false)):room_count+=1
			elif rejection.is_empty():rejection=str(row.get("room_geometry_rejection_reason",""))
		return {"run_id":run_state.get_instance_id(),"screen":current_screen,"ready":run_state.current_environment.get("scenario_semantic_ready"),"pending":run_state.current_environment.get("scenario_restore_pending_trusted_rebuild"),"controls":room_catalog_snapshot().size(),"room_controls":room_count,"projection_errors":projection_errors,"rejection":rejection,"message":message_label.text if message_label!=null else ""}
var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_RESOLVED_ROOM_BUNDLE")
	var mode:=OS.get_environment("BTH_RESOLVED_ROOM_CASE")
	if not _check(not bundle.is_empty(),"private unchanged fixture bundle required"):
		_finish();return
	_install(bundle)
	root.size=Vector2i(1280,720)
	var app:=Observer.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run(),"official Continue copied player checkpoint"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	var event_id:="late_shift_discount" if mode=="haggle" else "recruitment_switch"
	var before:=_controls(app)
	var original_cash:=run.bankroll
	var original_rng:=run.rng_state
	_check(before.size()>0,"captured room starts with physical controls")
	if mode=="haggle":
		var result:Dictionary=app.resolve_event_choice(event_id,"haggle")
		_check(bool(result.get("ok",false)),"normal inspector Haggle resolves once on exact captured Store")
		_check(run.bankroll==original_cash+5,"Haggle grants existing five dollars exactly once")
	else:
		_check(app._start_person_event_conversation(event_id),"normal actor Talk opens captured event")
		var result:Dictionary=app.resolve_event_choice(event_id,"work_with_switch")
		_check(bool(result.get("ok",false)),"normal Take the route resolves once")
		_check(run.bankroll==original_cash and run.crew_trust("crew_switch")==30,"one recruitment with no cash replay")
	_check(run.current_environment.get("resolved_event_ids",[]).has(event_id),"consumed event journal retained")
	var after:=_controls(app)
	_check(after.size()>0,"resolved event does not reject every room control")
	var retained:=0
	for object_id in before:
		if object_id=="event:"+event_id:continue
		if after.has(object_id):
			retained+=1
			_check(after[object_id]==before[object_id],"retained spatial identity unchanged: "+object_id)
	_check(retained>0,"unrelated controls remain physically available")
	_check(not after.has("event:"+event_id),"consumed ordinary event is hidden after validation")
	var publication:=run.room_presentation_snapshot()
	var finalized:Dictionary=publication.get("finalized",{})
	if not bool(finalized.get("inactive",true)):
		var sealed:Array=finalized.get("records",[])
		var projected:=Controller.project_finalized_sequence_interaction_result(sealed,finalized)
		_check(bool(projected.get("ok",false)),"complete immutable baseline still passes strict sealed projection")
		var removed:=Controller._without_resolved_event_presence(sealed,run.current_environment.get("resolved_event_ids",[]))
		var incomplete:=Controller.project_finalized_sequence_interaction_result(removed,finalized)
		_check(not bool(incomplete.get("ok",true)),"old pre-validation removal is still rejected; validator has not been weakened")
		facts["old_order_errors"]=incomplete.get("errors",[])
		var tampered:=finalized.duplicate(true)
		tampered["layout_authority_digest"]="0".repeat(64)
		_check(not bool(Controller.project_finalized_sequence_interaction_result(sealed,tampered).get("ok",true)),"changed layout digest remains rejected")
	else:
		facts["sealed_projection"]="inactive; adjacent ordinary-room control"
	for frame in range(4):await process_frame
	_check(_controls(app)==after,"no-input frames retain the same room controls")
	app.save_foundation_run()
	_check(app.return_to_main_menu(),"normal Main Menu releases prior UI ownership")
	await process_frame
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue consumed event")
	run=app.run_state
	facts["continued_state"]={"message":app.message_label.text,"ready":run.current_environment.get("scenario_semantic_ready"),"pending":run.current_environment.get("scenario_restore_pending_trusted_rebuild"),"proof_errors":run.validate_room_action_authority().get("errors",[]),"resolved":run.current_environment.get("resolved_event_ids",[]),"save_status":app.save_status_message}
	_check(run.current_environment.get("resolved_event_ids",[]).has(event_id) and not _controls(app).is_empty(),"cold Continue retains resolution and visible controls")
	facts["surviving_controls_after_action"]=after
	facts["surviving_controls_after_continue"]=_controls(app)
	_check(_same_control_footprints(_controls(app),after),"same-host Continue retains exact control identities and subpixel-equivalent footprints")
	_check(run.bankroll==original_cash+(5 if mode=="haggle" else 0),"cold Continue cannot grant reward again")
	_check(run.rng_state==original_rng,"event removal and cold Continue do not redraw run RNG")
	var cold_publication:=run.room_presentation_snapshot()
	var cold_finalized:Dictionary=cold_publication.get("finalized",{})
	if not bool(cold_finalized.get("inactive",true)):
		var cold_records:Array=cold_finalized.get("records",[])
		_check(bool(Controller.project_finalized_sequence_interaction_result(cold_records,cold_finalized).get("ok",false)),"restored baseline and live authority are correlated")
		var unrelated_removed:=cold_records.duplicate(true)
		if not unrelated_removed.is_empty():unrelated_removed.remove_at(0)
		_check(not bool(Controller.project_finalized_sequence_interaction_result(unrelated_removed,cold_finalized).get("ok",true)),"restored unrelated missing sealed record remains rejected")
	facts.merge({"case":mode,"cash":run.bankroll,"controls_before":before.size(),"controls_after":after.size(),"cold_controls":_controls(app).size(),"fidelity":"Normal host callbacks on an unchanged private historical QA fixture; clock frozen. Not the current user's live run."})
	facts["publication_stages"]=app.publication_stages
	app.queue_free();await process_frame
	_finish()

func _controls(app:Node)->Dictionary:
	var result:Dictionary={}
	for row in app.room_catalog_snapshot():
		if str(row.get("presentation_mode","room"))=="room" and not bool(row.get("room_geometry_rejected",false)):
			result[str(row.get("object_id"))]=row.get("normalized_rect",{}).duplicate(true)
	return result

func _same_control_footprints(first:Dictionary,second:Dictionary)->bool:
	if first.size()!=second.size():return false
	for object_id in first:
		if not second.has(object_id):return false
		for field in ["x","y","w","h"]:
			# Vector2 uses float32; save/restore can differ by a few millionths
			# of a pixel. Keep identity exact and geometry within 0.001 pixels.
			if absf(float(first[object_id].get(field,0))-float(second[object_id].get(field,0)))>0.000001:return false
	return true

func _install(bundle:String)->void:
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy private authority companion")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy existing private profile companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("RESOLVED_EVENT_ROOM checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
