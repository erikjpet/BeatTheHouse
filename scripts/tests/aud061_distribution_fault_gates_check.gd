extends SceneTree
const Store := preload("res://scripts/core/durable_store.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Paths := preload("res://scripts/core/persistence_paths.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
func _init() -> void:call_deferred("_run")
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _run()->void:
	var prior:=OS.get_environment(Paths.DISTRIBUTION_FEATURE_ENV)
	for distribution in [false,true]:
		OS.set_environment(Paths.DISTRIBUTION_FEATURE_ENV,"1" if distribution else "0")
		_check(Paths.distribution_build()==distribution,"Actual distribution predicate "+str(distribution))
		for fault in ["write","rename",Store.TRANSITION_STAGE_BACKUP,Store.TRANSITION_ROTATE_PRIMARY,Store.TRANSITION_INSTALL_PRIMARY,Store.TRANSITION_VALIDATE_PRIMARY]:
			Store.reset_debug_faults()
			var path: String="user://aud061_16/%s/%s.json" % [str(distribution),fault]
			_check(bool(Store.write_json(path,{"generation":1}).ok),"Initial primary "+fault)
			_check(bool(Store.write_json(path,{"generation":2}).ok),"Initial backup "+fault)
			if fault=="write":Store.set_debug_force_write_failure(true)
			elif fault=="rename":Store.set_debug_force_rename_failure(true)
			else:Store.set_debug_fail_transition(fault)
			var result:=Store.write_json(path,{"generation":3})
			Store.reset_debug_faults()
			var saved:=Store.read_json(path)
			_check(bool(result.ok)==distribution,"Fault effect "+fault+" distribution="+str(distribution))
			_check(int(saved.data.generation)==(3 if distribution else 2),"Actual retained/installed generation "+fault+" distribution="+str(distribution))
			observations.append({"distribution":distribution,"fault":fault,"ok":result.ok,"error_code":result.get("error_code"),"saved_generation":saved.data.generation})
		var payload:Dictionary={"text":"sample".repeat(100),"count":2}
		Codec.debug_storage_byte_limit_override=8
		var limited:=Codec.pack_for_storage(payload)
		Codec.debug_storage_byte_limit_override=0
		_check(bool(limited.ok)==distribution,"Storage limit override distribution="+str(distribution))
		Codec.debug_force_compression_failure=true
		var compressed:=Codec.pack_for_storage(payload)
		Codec.debug_force_compression_failure=false
		_check(bool(compressed.ok)==distribution,"Compression failure override distribution="+str(distribution))
		observations.append({"distribution":distribution,"codec_limit_ok":limited.ok,"codec_compression_ok":compressed.ok})
		var app:=Main.new()
		var script_path:="res://scripts/ui/player_text.gd"
		app.run_ui_script_prewarm_requests[script_path]=true
		app.script_prewarm_force_start_error_for_test=true
		app._start_next_script_prewarm_worker()
		var threaded:bool=app.script_prewarm_thread!=null
		_check(threaded==distribution,"Forced start error distribution="+str(distribution))
		app._join_active_script_prewarm_worker()
		_check(app.script_prewarm_thread==null and app.run_ui_script_prewarm_requests.is_empty(),"Worker/fallback fully drained")
		observations.append({"distribution":distribution,"prewarm_thread_started":threaded})
		app.free()
	OS.set_environment(Paths.DISTRIBUTION_FEATURE_ENV,prior)
	print("AUD061_16_FAULT_GATES "+JSON.stringify({"checks":checks,"failures":failures,"observations":observations}))
	quit(0 if failures.is_empty() else 1)
