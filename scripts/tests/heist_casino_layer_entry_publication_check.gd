extends SceneTree

const Host:=preload("res://scripts/ui/foundation_main.gd")
const RoomProof:=preload("res://scripts/core/room_presentation_publication.gd")

class RejectEntry extends RunGenerator:
	func _init(content:ContentLibrary)->void:super(content)
	func enter_environment_layer(_run:RunState,_target:String,_advance:bool=true)->Dictionary:
		return {"ok":false,"message":"Diagnostic rejected entry: authority retained."}

class RejectExit extends RunGenerator:
	func _init(content:ContentLibrary)->void:super(content)
	func _crew_room_exit_errors(environment:Dictionary)->Array:
		if str(environment.get("current_layer_id"))=="back_room":return ["Diagnostic unavailable safe exit."]
		return super._crew_room_exit_errors(environment)

var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_HEIST_ROOM002_BUNDLE")
	var mode:=OS.get_environment("BTH_HEIST_ROOM002_CASE")
	if not _check(not bundle.is_empty(),"private unchanged checkpoint25 bundle required"):return _finish()
	_install(bundle)
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	_check(app.load_foundation_run(),"normal host Continue genuine checkpoint25")
	var run:RunState=app.run_state
	_check(run.bankroll==109 and run.suspicion_level()==7 and run.crew_reputation()==97,"actual109/Heat7/Crew97 preserved")
	_check(int(run.narrative_flags.get("crew_delivery_obligations",-1))==0 and bool(run.narrative_flags.get("crew_heist_count_audit_roster_read",false)),"duties0 and learned Audit retained")
	_check(str(run.current_environment.get("current_layer_id"))=="club","captured source club retained")
	var immutable:=_preserved(run)
	var original_casino:Dictionary=run.current_environment.get("layer_states",{}).get("casino",{}).duplicate(true)
	var rejection_facts:Dictionary={}
	if mode=="reject":
		# Explicit detached corruption test. No captured original or host run edits.
		var detached:=RunState.new();detached.from_dict(run.to_save_snapshot())
		detached.current_environment["object_manifest"]["source_digest"]="diagnostic-stale-source"
		var bad_before:=detached.to_save_snapshot()
		var rejected:Dictionary=app.generator._prepare_layer_crew_membership(detached)
		_check(not bool(rejected.get("ok",true)),"stale incoming source rejected before derived Crew mutation")
		_check(detached.to_save_snapshot()==bad_before,"rejected baseline is not healed or mutated")
		app.generator=RejectEntry.new(app.library)
		var before:=_transaction_state(run)
		_check(not _enter(app,"casino"),"explicit injected rejection returnsfalse")
		_check(_transaction_state(run)==before,"rejected entry leaves cash/time/RNG/history/prerequisites unchanged")
		var visible:Dictionary=app._environment_result_feedback_view()
		_check(str(visible.get("message"))=="Diagnostic rejected entry: authority retained.","actual visible Result shows rejection instead of old trip")
		rejection_facts={"incoming_errors":rejected.get("errors",[]),"visible_rejection":visible.get("message"),"state_unchanged":true}
		app.generator=RunGenerator.new(app.library)
	var entered:=_enter(app,"casino")
	_check(entered,"normal canvas casino entry succeeds")
	if not entered:
		facts={"case":mode,"entry_error":app.message_label.text,"visible":app._environment_result_feedback_view().get("message")}
		app.queue_free();await process_frame;return _finish()
	_check(str(run.current_environment.get("current_layer_id"))=="casino","transaction commits casino layer")
	_check(_preserved(run)==immutable,"entry changes no cash/chips/debt/items/trust/duties/Audit/story completion flags")
	_check(bool(RoomProof.validate(run.current_environment).get("ok",false)),"independent full casino room authority validates")
	_check(_room_count(app)>0,"casino publishes visible physical controls")
	_check(str(app._environment_result_feedback_view().get("message"))!="Diagnostic rejected entry: authority retained.","successful retry does not retain a rejected-entry Result")
	var old_rects:Dictionary=original_casino.get("layout",{}).get("object_rects",{})
	var new_rects:Dictionary=run.current_environment.get("layout",{}).get("object_rects",{})
	for key in old_rects:
		if new_rects.has(key):_check(old_rects[key]==new_rects[key],"existing target authored rectangle retained: "+str(key))
	var committed_rng:=run.rng_state
	app.save_foundation_run();app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue casino")
	run=app.run_state
	_check(str(run.current_environment.get("current_layer_id"))=="casino" and run.rng_state==committed_rng,"cold Continue retains committed layer/RNG without entry replay")
	_check(_preserved(run)==immutable and bool(RoomProof.validate(run.current_environment).get("ok",false)),"cold casino retains progress and complete authority")
	if mode=="reject":
		app.generator=RejectExit.new(app.library)
		var before:=_transaction_state(run)
		_check(not _enter(app,"back_room"),"unsafe-exit rejection rolls back private entry")
		_check(_transaction_state(run)==before and str(run.current_environment.get("current_layer_id"))=="casino","unsafe-exit rollback preserves accepted state in casino")
		_check(str(app._environment_result_feedback_view().get("message")).contains("safe exit"),"unsafe-exit rejection is visible")
		app.generator=RunGenerator.new(app.library)
	_check(bool(run.environment_layer_access_status("back_room").get("available",false)),"existing Crew97 satisfies unchanged private-room gate")
	var back_entered:=_enter(app,"back_room")
	_check(back_entered,"normal Back Room entry succeeds")
	if back_entered:
		_check(str(run.current_environment.get("current_layer_id"))=="back_room" and bool(RoomProof.validate(run.current_environment).get("ok",false)),"Back Room publishes full valid authority")
		var planning:=_planning_records(app)
		_check(not planning.is_empty(),"Planning Table visible without locking Count")
		_check(_preserved(run)==immutable,"Back Room preserves completed run prerequisites and accounting")
		var back_rng:=run.rng_state
		app.save_foundation_run();app.save_service=SaveService.new()
		_check(app.load_foundation_run(),"fresh Continue private room")
		run=app.run_state
		_check(str(run.current_environment.get("current_layer_id"))=="back_room" and run.rng_state==back_rng and not _planning_records(app).is_empty(),"cold private room retains Planning Table and no duplicate transition")
		_check(_preserved(run)==immutable,"cold private room preserves cash/trust/flags")
		facts={"case":mode,"cash":run.bankroll,"heat":run.suspicion_level(),"Crew":run.crew_reputation(),"layer":run.current_environment.get("current_layer_id"),"planning":_planning_records(app),"rejection":rejection_facts,"count_locked":false,"fidelity":"Official copied checkpoint25, normal host focus/canvas entry/Save/freshContinue. Rejection mode explicitly injects generator errors and a detached corrupt baseline; no originals or protected campaign changed."}
	app.queue_free();await process_frame
	_finish()

func _enter(app:Node,target:String)->bool:
	if not app.focus_interactable_object("environment_layer:"+target):return false
	return app.activate_interactable_object("environment_layer:"+target)

func _room_count(app:Node)->int:
	var count:=0
	for row in app.room_catalog_snapshot():
		if str(row.get("presentation_mode","room"))=="room" and not bool(row.get("room_geometry_rejected",false)):count+=1
	return count

func _planning_records(app:Node)->Array:
	var result:=[]
	for row in app.room_catalog_snapshot():
		if str(row.get("label","")).to_lower().contains("planning") and str(row.get("presentation_mode","room"))=="room":
			result.append({"id":row.get("object_id"),"label":row.get("label"),"enabled":row.get("enabled")})
	return result

func _preserved(run:RunState)->Dictionary:
	var source:=run.to_save_snapshot()
	var flags:Dictionary={}
	for key in run.narrative_flags:
		if str(key).contains("headliner") or str(key).contains("audit") or str(key).contains("invitation") or str(key)=="crew_delivery_obligations":flags[key]=run.narrative_flags[key]
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"debt":source.get("debt"),"inventory":run.inventory.duplicate(true),"trust":source.get("crew_state",{}).get("trust",{}),"Crew":run.crew_reputation(),"flags":flags,"story_flags":run.story_flags.duplicate(true)}

func _transaction_state(run:RunState)->Dictionary:
	var source:=run.to_save_snapshot()
	var result:=_preserved(run)
	for key in ["rng_state","game_clock_minutes","story_log","narrative_flags","crew_state"]:result[key]=source.get(key)
	result["layer"]=run.current_environment.get("current_layer_id")
	return result

func _install(bundle:String)->void:
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy actual private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy unchanged private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy existing private profile companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var file:=FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("HEIST_ROOM002_CHECK checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
