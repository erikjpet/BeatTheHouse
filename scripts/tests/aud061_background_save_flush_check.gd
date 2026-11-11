extends SceneTree
const MainScene := preload("res://scenes/main.tscn")
class BlockedGame extends GameModule:
	func foundation_save_ready(_run_state:RunState,_environment:Dictionary)->bool:return false
class CountingSave extends SaveService:
	var writes:=0
	func save_run(state:RunState,slot:String="autosave")->Error:
		writes+=1
		return super.save_run(state,slot)

var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
var app
var service:CountingSave
func _init()->void:call_deferred("_run")
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _baseline(slot:String)->void:
	app.current_game=null
	app._event_response_transaction={}
	app._rourke_resolution={}
	app.dev_game_test_mode=false
	app.meta_session_active=false
	app.run_state.narrative_flags.erase("_meta_home_session")
	app.room_publication_checked_generation=app.room_publication_generation
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.autosave_slot_id=slot
	app.run_state.narrative_flags["audit_lifecycle_marker"]="baseline"
	_check(app._autosave_foundation_run("Baseline.",true),"Baseline generation "+slot)
func _queue(marker:String)->void:
	app.run_state.narrative_flags["audit_lifecycle_marker"]=marker
	_check(app._autosave_foundation_run("Queued."),"Queued real autosave "+marker)
	_check(app.pending_autosave,"Pending generation "+marker)
func _marker(slot:String)->String:
	var loaded:RunState=service.load_run(slot)
	return str(loaded.narrative_flags.get("audit_lifecycle_marker","")) if loaded!=null else "missing"
func _run()->void:
	app=MainScene.instantiate()
	root.add_child(app)
	await process_frame
	_check(app.start_foundation_run("AUD061-08-LIFECYCLE",{},true),"Ordinary production host run starts")
	service=CountingSave.new()
	app.save_service=service
	var notifications=[Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED]
	for notification in notifications:
		var slot:="lifecycle_%d"%int(notification)
		_baseline(slot)
		_queue(slot)
		var frame:=Engine.get_process_frames()
		var started_usec:=Time.get_ticks_usec()
		app._notification(int(notification))
		var elapsed_ms:=float(Time.get_ticks_usec()-started_usec)/1000.0
		_check(Engine.get_process_frames()==frame,"Notification does not advance a frame "+slot)
		var marker:=_marker(slot)
		_check(marker==slot,"Queued generation durable synchronously "+slot)
		_check(not app.pending_autosave,"Pending state clears "+slot)
		observations.append({"case":slot,"marker":marker,"frame_unchanged":Engine.get_process_frames()==frame,"flush_elapsed_ms":elapsed_ms})
	# Real owned native worker, then a newer coalesced generation.
	_baseline("lifecycle_worker")
	_check(service.begin_save_run(app.run_state,app.autosave_slot_id)==OK,"Actual background worker starts")
	app.pending_autosave=false
	app.run_state.narrative_flags["audit_lifecycle_marker"]="newer_than_worker"
	var frame:=Engine.get_process_frames()
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not service.async_save_in_flight(),"Focus boundary drains the actual worker")
	_check(_marker(app.autosave_slot_id)=="newer_than_worker","Current generation replaces older in-flight generation")
	_check(Engine.get_process_frames()==frame,"Worker flush completes without frames")
	# Exercise the actual four Web phases natively, without a source/OS override.
	_baseline("lifecycle_web_phases")
	var path:=service.run_save_path(app.autosave_slot_id)
	_check(service._begin_web_save(app.run_state.to_save_snapshot_for_encoding(),app.autosave_slot_id,path,"")==OK,"Actual phased save starts")
	app.pending_autosave=false
	app.run_state.narrative_flags["audit_lifecycle_marker"]="newer_than_phases"
	frame=Engine.get_process_frames()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(not service.async_save_in_flight(),"Pause drains actual finite Web job")
	_check(_marker(app.autosave_slot_id)=="newer_than_phases","Current generation follows drained phases")
	_check(Engine.get_process_frames()==frame,"Phased flush completes without frames")
	for guard in ["live_game","room_publication","practice","meta","event_transaction","rourke_transaction"]:
		var slot:String="lifecycle_guard_"+str(guard)
		_baseline(slot)
		_queue(guard)
		var prior:=FileAccess.get_file_as_bytes(service.run_save_path(slot))
		if guard=="live_game":app.current_game=BlockedGame.new()
		elif guard=="room_publication":app.room_publication_generation=app.room_publication_checked_generation+1
		elif guard=="practice":app.dev_game_test_mode=true
		elif guard=="event_transaction":app._event_response_transaction={"qa_pending":true}
		elif guard=="rourke_transaction":app._rourke_resolution={"qa_pending":true}
		else:
			app.meta_session_active=true
			app.run_state.narrative_flags["_meta_home_session"]=true
		var writes:=service.writes
		app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(service.writes==writes,"Existing guard refuses lifecycle write "+guard)
		_check(FileAccess.get_file_as_bytes(service.run_save_path(slot))==prior,"Existing generation preserved "+guard)
		_check(app.pending_autosave,"Refused lifecycle generation remains pending "+guard)
	# Actual private filesystem failure, then a later boundary retries held state.
	_baseline("lifecycle_storage_failure")
	_queue("retry_after_storage_failure")
	path=ProjectSettings.globalize_path(service.run_save_path(app.autosave_slot_id)+".tmp")
	var own_root:=OS.get_environment("BTH_QA_RUN_DIR").replace("\\","/").trim_suffix("/")+"/"
	var admitted:=not OS.get_environment("BTH_QA_RUN_DIR").is_empty() and path.replace("\\","/").to_lower().begins_with(own_root.to_lower()) and not path.to_lower().begins_with("c:")
	_check(admitted,"Physical fault inside admitted non-C run")
	if admitted:
		_check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path),"Owned fault path initially absent")
		_check(DirAccess.make_dir_recursive_absolute(path)==OK,"Actual temporary-write path blocked")
		app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(app.pending_autosave and app.autosave_warning_active,"Failed lifecycle save retains pending warning")
		_check(DirAccess.remove_absolute(path)==OK,"Only owned empty fault removed")
		app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(_marker(app.autosave_slot_id)=="retry_after_storage_failure","Later boundary persists held state after physical failure")
		_check(not app.pending_autosave and not app.autosave_warning_active,"Successful retry clears pending warning")
	_baseline("lifecycle_no_pending")
	var writes:=service.writes
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(service.writes==writes,"No pending or in-flight work means no redundant write")
	observations.append({"case":"scopes","native_worker":"actual","web_phases":"actual SaveService phases invoked natively; exported callback delivery is separate Web evidence","guards":"actual publication/practice/meta; explicit rejecting GameModule readiness boundary"})
	app.queue_free()
	await process_frame
	await process_frame
	print("AUD061_08_LIFECYCLE "+JSON.stringify({"checks":checks,"failures":failures,"observations":observations}))
	quit(0 if failures.is_empty() else 1)
