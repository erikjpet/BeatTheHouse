extends SceneTree
const Host := preload("res://scripts/ui/foundation_main.gd")
const Scratch := preload("res://scripts/games/scratch_tickets.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _run() -> void:
	var bundle := OS.get_environment("BTH_SCRATCH026_BUNDLE")
	if not _check(not bundle.is_empty() and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "private captured-save bundle and persistence required"):
		_finish(); return
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy private profile companion")
	root.size=Vector2i(1280,720)
	var app:=Host.new(); app.continuous_environment_clock_enabled=false; app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3): await process_frame
	if _check(app.load_foundation_run(),"official unchanged unfiled winner + queued ticket Continue"):
		var run: RunState = app.run_state
		var player := run.portable_ticket_state("scratch_tickets",run.current_environment)
		var ids := _ids(player)
		var purchases := _purchases(run)
		_check(purchases==3,"captured campaign has exactly three accepted purchases")
		_check(run.bankroll==0 and run.run_status=="active" and ids.size()==2,"two paid identities remain active at zero cash")
		_check(app.enter_game("scratch_tickets"),"normal Scratch cabinet entry")
		await create_timer(0.3).timeout
		app._on_game_surface_action(Scratch.FILE_TICKET_ACTION,0,false)
		await create_timer(0.8).timeout
		for frame in range(8): await process_frame
		_check(app._event_choice_popup_is_visible() and app.pending_event_choice_popup_event_id=="machine_jam","one normal File triggers actual Machine Jam")
		var result: Dictionary=app.resolve_event_choice("machine_jam","wait")
		_check(bool(result.get("ok",false)),"normal Wait response accepted once")
		await create_timer(1.0).timeout
		for frame in range(8): await process_frame
		player=run.portable_ticket_state("scratch_tickets",run.current_environment)
		_check(run.run_status=="active" and run.bankroll==0,"Wait cannot bankrupt paid-ticket owner")
		_check(_ids(player)==ids and not player.get("active_ticket",{}).is_empty() and player.get("winner_pile",[]).size()==1,"same next active ticket and filed winner retained")
		_check(int(player.winner_pile[0].get("payout",0))==10,"actual ten-dollar winner remains collectible")
		_check(_purchases(run)==purchases,"no purchase replay")
		_check(not bool(app._evaluate_run_terminal_state(true).get("failed",false)),"host terminal evaluator agrees with shared paid-asset predicate")
		var rng := run.rng_state
		var history := run.story_log.duplicate(true)
		facts={"cash":run.bankroll,"rng":rng,"ticket_ids":ids,"payout":10,"wait_ok":result.get("ok"),"status":run.run_status}
		_check(app.return_to_main_menu(),"normal Save/Main Menu with unresolved assets")
		await process_frame; app.save_service=SaveService.new()
		_check(app.load_foundation_run(),"fresh-service Continue retains Wait outcome")
		run=app.run_state; player=run.portable_ticket_state("scratch_tickets",run.current_environment)
		_check(run.run_status=="active" and run.bankroll==0 and run.rng_state==rng and _ids(player)==ids,"Continue preserves same assets/funds/RNG")
		if run.story_log!=history:
			var differences: Array=[]
			for index in range(maxi(history.size(),run.story_log.size())):
				if index>=history.size() or index>=run.story_log.size() or history[index]!=run.story_log[index]:
					differences.append({"index":index,"before":history[index] if index<history.size() else null,"after":run.story_log[index] if index<run.story_log.size() else null})
			facts["history_differences"]=differences
		_check(_same_json(run.story_log,history),"Continue does not replay File, Wait, purchase or payout")
		_check(app.use_game_environment_hook("scratch_tickets",Scratch.REDEEM_HOOK_ID,Scratch.REDEEM_ACTION_ID),"normal existing clerk redemption accepts stored winner")
		_check(run.bankroll==10 and run.portable_ticket_state("scratch_tickets",run.current_environment).get("winner_pile",[]).is_empty(),"exact ten-dollar redemption once")
		var paid_rng:=run.rng_state
		await create_timer(0.25).timeout
		app.use_game_environment_hook("scratch_tickets",Scratch.REDEEM_HOOK_ID,Scratch.REDEEM_ACTION_ID)
		_check(run.bankroll==10 and run.rng_state==paid_rng,"repeated redemption grants no extra money or RNG")
		_check(app.return_to_main_menu(),"normal final cleanup")
	app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _ids(player: Dictionary) -> Array:
	var result: Array=[]
	var active: Dictionary=player.get("active_ticket",{})
	if not active.is_empty(): result.append(str(active.id))
	for field in ["tray_stack","pending_queue","winner_pile"]:
		for ticket in player.get(field,[]): result.append(str(ticket.id))
	result.sort(); return result

func _purchases(run: RunState) -> int:
	var count:=0
	for row in run.story_log:
		if str(row.get("type"))=="game_action" and str(row.get("game_id"))=="scratch_tickets" and str(row.get("action_id"))==Scratch.BUY_ACTION: count+=1
	return count

func _same_json(left: Variant, right: Variant) -> bool:
	# JSON transports the new pending-payout and cooldown counters as floats.
	# Accept only mathematically exact integral type changes, never rounding.
	if typeof(left)==TYPE_INT and typeof(right)==TYPE_FLOAT:
		return is_finite(right) and right==floor(right) and int(right)==left
	if typeof(right)==TYPE_INT and typeof(left)==TYPE_FLOAT:
		return is_finite(left) and left==floor(left) and int(left)==right
	if typeof(left)!=typeof(right): return false
	if typeof(left)==TYPE_DICTIONARY:
		if left.size()!=right.size(): return false
		for key in left:
			if not right.has(key) or not _same_json(left[key],right[key]): return false
		return true
	if typeof(left)==TYPE_ARRAY:
		if left.size()!=right.size(): return false
		for index in range(left.size()):
			if not _same_json(left[index],right[index]): return false
		return true
	return left==right

func _finish() -> void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "))
	print("SCRATCH_EVENT_BOUNDARY checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
