extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Proof := preload("res://scripts/core/room_presentation_publication.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var bundle := OS.get_environment("BTH_HEIST_REVERSE_BUNDLE")
	if not _check(not bundle.is_empty(),"unchanged copied Casino rejection checkpoint required"):
		_finish();return
	_install(bundle)
	root.size=Vector2i(1280,720)
	var app:=Host.new()
	app.continuous_environment_clock_enabled=false
	app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(),"official Continue captured Casino save"):
		app.queue_free();await process_frame;_finish();return
	var run:RunState=app.run_state
	_check(run.bankroll==109 and run.crew_reputation()==97 and str(run.current_environment.get("current_layer_id"))=="casino","captured Casino109/Crew97 retained")
	var before:=_accounting(run)
	var corrupt:=RunState.new()
	corrupt.from_dict(run.to_save_snapshot())
	corrupt.current_environment["layout"]["slot_binding_digest"]="invalid-diagnostic-binding"
	var corrupt_before:=corrupt.to_save_snapshot()
	_check(not bool(app.generator._prepare_layer_crew_membership(corrupt).get("ok",true)),"strict invalid incoming binding still rejected")
	_check(corrupt.to_save_snapshot()==corrupt_before,"invalid binding is not healed")
	_check(app.focus_interactable_object("environment_layer:club"),"normal visible Club focus")
	var entered:=app.activate_interactable_object("environment_layer:club")
	_check(entered and str(run.current_environment.get("current_layer_id"))=="club","normal reverse entry commits Club")
	if entered:
		_check(bool(Proof.validate(run.current_environment).get("ok",false)),"reverse Club strict presentation proof accepted")
		var bindings:Dictionary=run.current_environment.get("layout",{}).get("slot_bindings",{})
		var cass:Dictionary=bindings.get("event:chain06_cass_first_contact",{})
		_check(not cass.is_empty(),"newly eligible Cass has a compatible authored binding")
		_check(str(cass.get("slot_id","")).begins_with("event.standing_person"),"Cass uses standing-person slot rather than floor fixture")
		_check(_accounting(run)==before,"reverse entry preserves funds/items/debt/RNG/Crew obligations")
		_check(_controls(app)>0,"reverse Club publishes physical controls")
		var saved_rng:=run.rng_state
		app.save_foundation_run()
		_check(app.return_to_main_menu(),"normal Main Menu releases prior layer ownership")
		await process_frame
		app.save_service=SaveService.new()
		_check(app.load_foundation_run(),"fresh SaveService Continue reverse entry")
		run=app.run_state
		_check(str(run.current_environment.get("current_layer_id"))=="club" and run.rng_state==saved_rng,"cold Continue retains Club without entry replay")
		_check(bool(Proof.validate(run.current_environment).get("ok",false)) and _controls(app)>0,"cold Club proof and controls remain valid")
		await create_timer(0.25).timeout
		_check(app.focus_interactable_object("environment_layer:casino") and app.activate_interactable_object("environment_layer:casino"),"forward Casino route still works")
		facts["forward_feedback"]=str(app._environment_result_feedback_view().get("message",""))
		_check(bool(Proof.validate(run.current_environment).get("ok",false)),"forward Casino proof retained")
		await create_timer(0.25).timeout
		_check(app.focus_interactable_object("environment_layer:back_room") and app.activate_interactable_object("environment_layer:back_room"),"qualified Back Room remains accessible")
		facts["back_room_feedback"]=str(app._environment_result_feedback_view().get("message",""))
		_check(bool(Proof.validate(run.current_environment).get("ok",false)),"Back Room proof retained")
		_check(_accounting(run)==before,"round trip preserves money/RNG/obligations and item identity")
		facts.merge({"layer":run.current_environment.get("current_layer_id"),"cash":run.bankroll,"Crew":run.crew_reputation(),"cass_binding":cass,"normal_host_entry_and_cold":true,"count_started":false})
	_check(app.return_to_main_menu(),"normal final Main Menu saves and releases layer/UI ownership")
	run=null
	corrupt=null
	await process_frame
	app.queue_free()
	for frame in range(3):await process_frame
	_finish()

func _accounting(run:RunState)->Dictionary:
	var snapshot:=run.to_save_snapshot()
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"debt":snapshot.get("debt"),"rng":run.rng_state,"inventory":run.inventory.duplicate(true),"Crew":run.crew_reputation(),"duties":run.crew_delivery_obligation_count(),"trust":snapshot.get("crew_state",{}).get("trust",{})}

func _controls(app:Node)->int:
	var count:=0
	for row in app.room_catalog_snapshot():
		if str(row.get("presentation_mode","room"))=="room" and not bool(row.get("room_geometry_rejected",false)):count+=1
	return count

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
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"copy existing profile companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "))
		file.close()
	print("HEIST_REVERSE_LAYER checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
