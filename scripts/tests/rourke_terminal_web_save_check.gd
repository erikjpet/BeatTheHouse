extends SceneTree
const Main := preload("res://scripts/ui/foundation_main.gd")
const Store := preload("res://scripts/core/durable_store.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures: Array[String]=[]

class PhasedSave extends SaveService:
	var steps: Array=[]
	var fail_install:=false
	func begin_save_run(state: RunState, slot: String="autosave") -> Error:
		if async_save_in_flight():return ERR_BUSY
		steps.append({"phase":"encode","frame":Engine.get_process_frames()})
		var clean:=_slot_id(slot)
		var path:=run_save_path(clean)
		return _begin_web_save(state.to_save_snapshot_for_encoding(),clean,path,_trusted_primary_digest(clean,path))
	func _advance_web_save_step() -> void:
		var phase:=str(_web_save_job.get("phase",""))
		steps.append({"phase":phase,"frame":Engine.get_process_frames()})
		if phase=="install" and fail_install:Store.debug_force_write_failure=true
		super._advance_web_save_step()
		Store.debug_force_write_failure=false

class PhasedMain extends Main:
	func _terminal_checkpoint_uses_web_phases() -> bool:
		# Emulate only the production Web/nothreads platform predicate natively.
		return run_state!=null and str(run_state.current_environment.get("local_narrative_flags",{}).get("blackjack_boss_variant",""))=="rourke_duel"

func _initialize() -> void:call_deferred("_run")

func _open(case_id: String) -> PhasedMain:
	var app:=PhasedMain.new()
	root.add_child(app)
	app.continuous_environment_clock_enabled=false
	app.autosave_slot_id="rourke_web_"+case_id
	app.save_service=PhasedSave.new()
	var path: String=app.save_service.run_save_path(app.autosave_slot_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(FIXTURE));f.close()
	_check(app.load_foundation_run(),case_id+": fixture load")
	app.run_state.fail_run(RunState.FAILURE_CASINO_TAKEN_OUT_BACK,"Terminal checkpoint test")
	app.run_state.narrative_flags.erase(app.TERMINAL_RESUME_CHECKPOINT_FLAG)
	app.pending_autosave=false
	return app

func _wait_write(app: PhasedMain) -> void:
	for frame in range(20):
		await process_frame
		if app.autosave_completed_generation>=app.autosave_dirty_generation or app.autosave_retry_blocked:return

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():quit(2);return
	var app:=_open("complete")
	var service: PhasedSave=app.save_service
	var rng: int=app.run_state.rng_state
	_check(app._save_terminal_resume_checkpoint(),"terminal checkpoint accepted")
	_check(app.pending_autosave and service.steps.is_empty(),"input callback queues without encoding or installation")
	await _wait_write(app)
	_check(service.steps.size()==5,"encode, pack, bytes/hash, JSON and install execute once")
	if service.steps.size()==5:
		for index in range(1,service.steps.size()):
			_check(service.steps[index-1].frame<service.steps[index].frame,"each save phase runs on a distinct frame")
	var restored: RunState=service.load_run(app.autosave_slot_id)
	_check(restored!=null and restored.is_terminal() and restored.rng_state==rng,"completed phased checkpoint restores terminal state and RNG")
	app.free()
	app=_open("leave")
	service=app.save_service
	rng=app.run_state.rng_state
	_check(app._save_terminal_resume_checkpoint(),"pre-navigation checkpoint queued")
	_check(app.return_to_main_menu(),"immediate Main Menu waits for a synchronous durable checkpoint")
	restored=service.load_run(app.autosave_slot_id)
	_check(restored!=null and restored.is_terminal() and restored.rng_state==rng,"immediate navigation retains terminal Continue")
	app.free()
	app=_open("leave_inflight")
	service=app.save_service
	_check(app._save_terminal_resume_checkpoint(),"in-flight navigation checkpoint queued")
	await process_frame
	await process_frame
	_check(service.async_save_in_flight(),"navigation case reaches a partially written Web job")
	_check(app.return_to_main_menu(),"navigation drains the in-flight Web job before leaving")
	restored=service.load_run(app.autosave_slot_id)
	_check(restored!=null and restored.is_terminal(),"in-flight navigation retains terminal Continue")
	app.free()
	app=_open("failure")
	service=app.save_service
	service.fail_install=true
	_check(app._save_terminal_resume_checkpoint(),"failure case queued")
	await _wait_write(app)
	_check(not bool(app.run_state.narrative_flags.get(app.TERMINAL_RESUME_CHECKPOINT_FLAG,false)),"failed phase clears checkpoint acknowledgement for retry")
	var retained: RunState=app.run_state
	Store.debug_force_write_failure=true
	_check(not app.return_to_main_menu() and app.run_state==retained,"failed immediate navigation keeps the terminal run open")
	Store.debug_force_write_failure=false
	service.fail_install=false
	_check(app.return_to_main_menu(),"recovered synchronous save allows navigation")
	restored=service.load_run(app.autosave_slot_id)
	_check(restored!=null and restored.is_terminal(),"Continue retains the recovered ending")
	app.free()
	print("ROURKE_TERMINAL_WEB_SAVE ",JSON.stringify({"failures":failures,"cases":4,"platform":"native emulation of existing no-thread Web save phases"}))
	for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
