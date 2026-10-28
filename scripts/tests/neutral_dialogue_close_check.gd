extends SceneTree

const Host:=preload("res://scripts/ui/foundation_main.gd")
const Codec:=preload("res://scripts/core/run_save_codec.gd")
class CountAvailable extends RunState:
	func active_player_count_status()->Dictionary:
		return {"active":true,"reason":"Synthetic eligible-count view only"}

var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var bundle:=OS.get_environment("BTH_NEUTRAL_DIALOGUE_BUNDLE")
	if not _check(not bundle.is_empty(),"unchanged captured disabled-Cass bundle required"):
		_finish();return
	_install(bundle)
	var synthetic:=RunState.new();synthetic.start_new("NEUTRAL-DIALOGUE-CLOSE")
	synthetic.current_environment={"id":"neutral_dialogue_fixture","archetype_id":"bar"}
	var before:=_gameplay(synthetic)
	_check(synthetic.enqueue_triggered_event("locked_fixture","automatic",{}, {"presentation":"talk"}),"synthetic all-disabled conversation queued")
	_check(synthetic.dismiss_talk_event_without_effect("locked_fixture"),"neutral close removes pending ownership")
	_check(_gameplay(synthetic)==before,"neutral close consumes no money/Heat/rep/time/action/RNG/flags/rewards")
	_check(not synthetic.dismiss_talk_event_without_effect("locked_fixture"),"repeated close is a no-op")
	_check(not synthetic.enqueue_triggered_event("locked_fixture","automatic",{}, {"presentation":"talk"}),"same automatic prompt cannot instantly reopen")
	_check(synthetic.enqueue_triggered_event("different_fixture","automatic",{}, {"presentation":"talk"}),"different eligible conversation can use the slot")
	var restored:=RunState.new()
	var encoded:=Codec.encode(synthetic.to_save_snapshot())
	restored.from_dict(Codec.decode(JSON.parse_string(JSON.stringify(encoded))))
	_check(not restored.enqueue_triggered_event("locked_fixture","automatic",{}, {"presentation":"talk"}),"neutral dismissal survives JSON restore")
	_check(restored.enqueue_triggered_event("locked_fixture","event_object",{}, {"presentation":"talk"}),"later deliberate conversation remains possible")
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run(),"official Continue actual disabled-Cass Gas save"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	var event_id:="chain06_cass_first_contact"
	_check(not bool(run.active_player_count_status().get("active",false)),"actual Gas has no active count")
	app._refresh_talk_dock()
	var keep:Dictionary={};var share:Dictionary={}
	for choice in app.talk_dock.option.get("choices",[]):
		if str(choice.get("id"))=="keep_counting":keep=choice
		elif str(choice.get("id"))=="share_the_read":share=choice
	_check(bool(keep.get("enabled",false)) and not bool(share.get("enabled",true)),"Cass Keep counting enabled while substantive answer stays count-gated")
	_check(app.talk_dock.collapse_button.text=="Close" and not app.talk_dock.collapse_button.disabled,"Close replaces Hide and remains enabled")
	var actual_before:=_gameplay(run)
	app._on_talk_dock_choice_requested(event_id,"keep_counting")
	_check(run.pending_talk_event(event_id).is_empty(),"normal Keep counting callback releases Cass slot")
	_check(_gameplay(run)==actual_before,"actual neutral dismissal changes no gameplay state or authored Cass flags")
	app._on_talk_dock_choice_requested(event_id,"share_the_read")
	app._on_talk_dock_choice_requested(event_id,"keep_counting")
	_check(_gameplay(run)==actual_before,"stale response and repeated close cannot resolve or reward after dismissal")
	_check(app._start_person_event_conversation(event_id),"deliberate later Cass Talk still opens")
	_check(not bool(run.story_flags.get("chain06_cass_first_contact",false)),"dismissal did not consume Cass's future first contact")
	var eligible:=CountAvailable.new();eligible.from_dict(run.to_save_snapshot())
	var module:=EventModule.new();module.setup(app.library.event(event_id),app.library)
	var eligible_share:=false
	for choice in module.choice_views(eligible,eligible.current_environment):
		if str(choice.get("id"))=="share_the_read":eligible_share=bool(choice.get("enabled",false))
	_check(eligible_share,"explicit synthetic active-count view preserves substantive answer eligibility")
	await process_frame
	app.talk_dock._request_neutral_close()
	_check(run.pending_talk_event(event_id).is_empty(),"actual Close header releases current conversation")
	_check(_gameplay(run)==actual_before,"Close header remains effect-free")
	_check(app.start_dialogue("chatty_clerk",{"source":"neutral_close_focused_test"}),"next catalog dialogue can open after Cass")
	_check(str(app.talk_dock.entry.get("dialogue_id"))=="chatty_clerk","next conversation owns the visible dock")
	await process_frame
	app.talk_dock._request_neutral_close()
	_check(run.pending_talk_event("dialogue:chatty_clerk").is_empty(),"generic dialogue Close also releases its slot")
	_check(_gameplay(run)==actual_before,"generic Close preserves gameplay values")
	app.save_foundation_run()
	_check(app.return_to_main_menu(),"normal Main Menu preserves neutral dismissals")
	await process_frame
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue after neutral closes")
	run=app.run_state
	_check(_gameplay(run)==actual_before,"Continue preserves finances/jobs/RNG/flags and clocks without replay")
	_check(run.pending_talk_event(event_id).is_empty(),"Cass is not reopened by Continue refresh")
	_check(app.start_dialogue("chatty_clerk",{"source":"event_object"}),"deliberate next conversation still opens after Continue")
	await process_frame
	app.talk_dock._request_neutral_close()
	_check(_gameplay(run)==actual_before,"repeated generic Close after Continue remains effect-free")
	facts={"cash":run.bankroll,"heat":run.suspicion_level(),"count_answer_remains_gated":true,"Cass_first_contact_consumed":bool(run.story_flags.get("chain06_cass_first_contact",false)),"synthetic_eligible_count_view_only":true,"actual_callbacks":"Keep counting and Close header on a copied Gas save; no original actions, departure or penalty compensation."}
	app.queue_free();await process_frame
	_finish()

func _gameplay(run:RunState)->Dictionary:
	var s:=run.to_save_snapshot()
	var result:Dictionary={}
	for key in ["bankroll","grand_casino_chips","debt","inventory","rng_state","game_clock_minutes","run_spending_score","story_flags","story_log","crew_state"]:result[key]=s.get(key)
	result["action_index"]=int(run.event_cadence.get("action_index",0))
	result["heat"]=run.suspicion_level()
	result["Crew"]=run.crew_reputation()
	result["duties"]=run.crew_delivery_obligation_count()
	return result

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
	print("NEUTRAL_DIALOGUE_CLOSE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
