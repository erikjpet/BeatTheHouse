extends SceneTree
const Host:=preload("res://scripts/ui/foundation_main.gd")
var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_SCRATCH017_BUNDLE")
	if not _check(not bundle.is_empty(),"unchanged I58 companion bundle required"):
		_finish();return
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy unchanged private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy existing private profile companion")
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run(),"official host Continue captured paid tray"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	var before:=run.to_save_snapshot()
	var player:=run.portable_ticket_state("scratch_tickets",run.current_environment)
	var ids:=_ids(player)
	_check(run.bankroll==0 and run.run_status=="active","zero-cash Continue remains active")
	_check(player.get("tray_stack",[]).size()==2 and ids.size()==2,"both actual paid ticket identities remain in tray")
	_check(app.enter_game("scratch_tickets"),"normal host opens Scratch cabinet at zero cash")
	var runtime:Dictionary=app.current_game.environment_runtime_state(run,run.current_environment)
	_check(bool(runtime.get("bankroll_zero_failure_deferred",false)) and int(runtime.get("unresolved_ticket_count"))==2,"live cabinet agrees with restored pending state")
	var command:Dictionary=app.current_game.surface_action_command("scratch_collect_tray",0,false,{},run,run.current_environment)
	_check(bool(command.get("environment_changed",false)),"normal surface command collects already-paid tray")
	player=run.portable_ticket_state("scratch_tickets",run.current_environment)
	_check(_ids(player)==ids and not player.get("active_ticket",{}).is_empty() and player.get("pending_queue",[]).size()==1,"same paid tickets become active plus queue")
	var after:=run.to_save_snapshot()
	for key in ["bankroll","grand_casino_chips","debt","story_log","rng_state","run_spending_score"]:
		_check(before.get(key)==after.get(key),"collection preserves "+key+" without purchase or payout replay")
	app.save_foundation_run()
	_check(app.return_to_main_menu(),"normal Main Menu after collection")
	await process_frame
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue after tray collection")
	run=app.run_state
	_check(run.run_status=="active" and run.bankroll==0 and _ids(run.portable_ticket_state("scratch_tickets",run.current_environment))==ids,"cold Continue preserves zero cash and both unresolved ticket identities")
	_check(run.rng_state==before.get("rng_state"),"Save/cold Continue cannot redraw ticket outcome")
	facts={"cash":run.bankroll,"status":run.run_status,"unresolved_count":ids.size(),"actual_paid_identities_preserved":true,"fidelity":"Official unchanged I58 copy, normal host Continue/cabinet entry/Save/fresh Continue, existing surface collection command; no new purchase, reveal, refund or original mutation."}
	_check(app.return_to_main_menu(),"normal final Main Menu releases restored cabinet ownership")
	run=null
	await process_frame
	app.queue_free()
	for frame in range(3):await process_frame
	_finish()

func _ids(player:Dictionary)->Array:
	var result:=[]
	var active:Dictionary=player.get("active_ticket",{})
	if not active.is_empty():result.append(str(active.get("id")))
	for key in ["tray_stack","pending_queue","winner_pile"]:
		for ticket in player.get(key,[]):result.append(str(ticket.get("id")))
	result.sort();return result

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("SCRATCH_CAPTURED_ZERO_CASH checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
