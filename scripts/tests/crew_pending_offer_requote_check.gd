extends SceneTree

const Host:=preload("res://scripts/ui/foundation_main.gd")
var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_CREW_DIAG_BUNDLE")
	if not _check(not bundle.is_empty(),"unchanged private Riverboat and Beach bundles required"):
		_finish();return
	_install(bundle.path_join("riverboat"))
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run(),"official Continue captured pending Riverboat request"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	_check(run.game_clock_minutes==4246 and run.bankroll==95 and run.crew_delivery_obligation_count()==2,"captured clock4246/cash95/duties2")
	var module:EventModule=app._crew_delivery_event_module(app.library.event("crew_favor_delivery"))
	var pending_template:=run.pending_talk_event("crew_favor_delivery").duplicate(true)
	# The old UI quote cache is not serialized. Reconstruct it explicitly from
	# the observed initial request clock; all durable state remains the copy.
	module._crew_offer_clock=4042
	app._refresh_talk_dock()
	app.talk_dock.armed_choice_id="run_package"
	var before:=var_to_bytes(run.to_save_snapshot())
	var result:Dictionary=app.resolve_event_choice("crew_favor_delivery","run_package")
	_check(not bool(result.get("ok",true)) and bool(result.get("crew_offer_requote",false)),"expired absolute quote rejects with refresh marker")
	_check(var_to_bytes(run.to_save_snapshot())==before,"rejected quote changes no durable state, RNG, cooldown, money or duties")
	var feedback:=str(app._environment_result_feedback_view().get("message",""))
	_check(feedback.contains("window has passed") and feedback.contains("confirm again"),"visible Result retains expiry and reconfirmation instruction")
	_check(not run.pending_talk_event("crew_favor_delivery").is_empty(),"same pending request retained")
	_check(app.talk_dock.armed_choice_id.is_empty(),"changed quote clears the previous armed confirmation")
	var fresh:EventModule=app._crew_delivery_event_module(app.library.event("crew_favor_delivery"))
	var choices:=fresh.choice_views(run,run.current_environment)
	var offer_clock:=-1
	for row in choices:
		if str(row.get("id"))=="run_package":offer_clock=int(row.get("crew_offer_clock",-1))
	_check(offer_clock==run.game_clock_minutes,"new quote is based on current clock")
	_check(bool(run.delivery_crew_offer("crew_favor_delivery",offer_clock).get("ok",false)),"fresh displayed route is still valid")
	var accepted:Dictionary=app.resolve_event_choice("crew_favor_delivery","run_package")
	_check(bool(accepted.get("ok",false)),"deliberate fresh confirmation accepts one route")
	_check(app.immediate_environment_acknowledgement.is_empty(),"accepted refreshed offer clears old rejection acknowledgement")
	var accepted_view:Dictionary=app._environment_result_feedback_view()
	_check(bool(accepted_view.get("result",{}).get("delivery_started",false)) and not str(accepted_view.get("message","")).contains("window has passed"),"Result shows accepted delivery rather than expired quote")
	_check(run.delivery_has_active_run() and run.inventory.size()==1,"one active delivery and one package")
	_check(run.bankroll==95 and run.crew_delivery_obligation_count()==2,"acceptance grants no cash or obligation completion")
	var accepted_before:=var_to_bytes(run.to_save_snapshot())
	var repeated:Dictionary=app.resolve_event_choice("crew_favor_delivery","run_package")
	_check(not bool(repeated.get("ok",true)),"stale second acceptance rejected while active")
	_check(var_to_bytes(run.to_save_snapshot())==accepted_before,"repeat acceptance cannot duplicate package or mutate RNG")
	app.save_foundation_run()
	_check(app.return_to_main_menu(),"normal Main Menu after accepted route")
	await process_frame
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue accepted route")
	run=app.run_state
	_check(run.delivery_has_active_run() and run.inventory.size()==1 and run.bankroll==95 and run.crew_delivery_obligation_count()==2,"cold Continue retains exactly one unpaid active route")
	facts["riverboat"]={"visible_expiry":feedback,"fresh_offer_clock":offer_clock,"active_after_cold":run.delivery_has_active_run(),"package_count":run.inventory.size(),"cash":run.bankroll,"duties":run.crew_delivery_obligation_count()}
	var content:ContentLibrary=app.library
	_check(app.return_to_main_menu(),"normal final Main Menu releases active delivery presentation")
	run=null
	await process_frame
	app.queue_free()
	for frame in range(3):await process_frame
	_install(bundle.path_join("beach"))
	var beach:RunState=SaveService.new().load_run("foundation_ui_autosave")
	_check(beach!=null and beach.crew_delivery_request_context_valid(),"captured Beach has actual Lucky and owed duties")
	if beach!=null:
		# Restore only the queued request that the old consumer retired. This is
		# an explicit synthetic eligibility variation, not a new hourly RNG roll.
		pending_template["environment_id"]=str(beach.current_environment.get("id",""))
		pending_template["context"]={}
		beach.pending_triggered_events.append(pending_template)
		_check(beach.triggered_event_pending("crew_favor_delivery"),"synthetic pending request on diagnostic Beach copy; no producer/RNG call")
		var beach_module:=EventModule.new();beach_module.setup(content.event("crew_favor_delivery"),content)
		var beach_before:=var_to_bytes(beach.to_save_snapshot())
		_check(not beach_module._environment_allows_room_actor(beach.current_environment),"generic recovery actor policy remains restrictive")
		_check(beach_module.can_trigger(beach,beach.current_environment),"valid Crew request survives generic Beach actor policy")
		_check(not beach_module.choice_views(beach,beach.current_environment).is_empty(),"Crew response choices remain available")
		_check(var_to_bytes(beach.to_save_snapshot())==beach_before,"Beach projection consumes no extra roll or state")
		var absent:=beach.current_environment.duplicate(true)
		absent.event_ids=[];absent.resolved_event_ids=[];absent.lender_hooks=[]
		_check(not beach.crew_delivery_request_context_valid(absent),"absent Crew still fails authoritative presence")
		facts["beach"]={"valid_request":true,"generic_room_actor_allowed":false,"fidelity":"Captured after-state plus explicitly synthetic pending queue; no future hourly attempt or protected state replay."}
	_finish()

func _install(bundle:String)->void:
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy existing profile companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("CREW_PENDING_REQUOTE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
