extends SceneTree
const Host:=preload("res://scripts/ui/foundation_main.gd")
var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_AUTHORED_TALK_BUNDLE")
	if not _check(not bundle.is_empty(),"unchanged copied Mina fixture required"):
		_finish();return
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy private profile companion")
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run(),"official Continue actual unresolved Mina offer"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	var event_id:="blackjack_counter_probe"
	var before:={"cash":run.bankroll,"chips":run.grand_casino_chips,"heat":run.suspicion_level(),"rng":run.rng_state}
	var ignores_before:=_generic_ignore_count(run)
	_check(not run.pending_talk_event(event_id).is_empty(),"actual authored pending offer retained")
	app._refresh_talk_dock()
	_check(str(app.talk_dock.entry.get("event_id"))==event_id,"actual Mina owns visible response surface")
	_check(app._is_authored_talk_choice(event_id,"ignore"),"authored Let it pass is not a generated abandonment")
	app._on_talk_dock_choice_requested(event_id,"ignore")
	for frame in range(8):await process_frame
	_check(run.pending_talk_event(event_id).is_empty(),"normal authored response releases pending offer")
	var after_heat:=run.suspicion_level()
	_check(after_heat<=before.heat and _generic_ignore_count(run)==ignores_before,"authored No effect adds no generic five Heat or abandonment receipt")
	var authored_receipt:Dictionary={}
	for row in run.story_log:
		if str(row.get("type"))=="event" and str(row.get("event_id"))==event_id:authored_receipt=row
	_check(not authored_receipt.is_empty() and int(authored_receipt.get("suspicion_delta",-1))==0,"authored outcome explicitly records zero Heat; ordinary action cooling remains intact")
	_check(run.bankroll==before.cash and run.grand_casino_chips==before.chips and run.rng_state==before.rng,"No effect preserves balances and RNG")
	var after:=run.to_save_snapshot()
	app._on_talk_dock_choice_requested(event_id,"ignore")
	_check(run.to_save_snapshot()==after,"stale authored response cannot resolve twice")
	_check(app.return_to_main_menu(),"normal Main Menu after authored dismissal")
	await process_frame
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue authored dismissal")
	run=app.run_state
	_check(run.pending_talk_event(event_id).is_empty() and run.suspicion_level()==after_heat,"Continue retains dismissal without penalty replay")
	_check(run.bankroll==before.cash and run.grand_casino_chips==before.chips and run.rng_state==before.rng,"Continue preserves balances/RNG")
	facts=before.duplicate(true)
	facts["heat_after"]=after_heat
	facts["scope"]="Actual unchanged Mina checkpoint; authored Let it pass via normal Dock callback. Header Close and unanswered timeout are separate policies."
	_check(app.return_to_main_menu(),"normal final Main Menu cleanup")
	run=null;await process_frame
	app.queue_free()
	for frame in range(3):await process_frame
	_finish()

func _generic_ignore_count(run:RunState)->int:
	var count:=0
	for row in run.story_log:
		if str(row.get("type"))=="talk_ignored":count+=1
	return count

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("AUTHORED_TALK_IGNORE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
