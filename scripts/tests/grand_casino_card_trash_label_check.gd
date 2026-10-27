extends SceneTree

# Private r265 custody is supplied out of tree. No disposition choice is accepted.
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var bundle := OS.get_environment("BTH_CARD_TRASH_BUNDLE")
	if not _check(not bundle.is_empty(), "private captured bundle required"): return _finish()
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"install private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"install private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0]+suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"install private profile companion")
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app)
	for frame in range(3):await process_frame
	_check(app.load_foundation_run(),"official host Continue loads genuine r265")
	var run:RunState=app.run_state
	_check(run.bankroll==77 and run.grand_casino_chips==13 and str(run.narrative_flags.get("grand_casino_showdown_step"))=="walk","captured walk and balances intact")
	var before:=JSON.stringify(run.to_save_snapshot())
	var module:=EventModule.new();module.setup(app.library.event(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID),app.library)
	var choices:=module.choices(run,run.current_environment)
	var cards:=[]
	for choice in choices:
		if str(choice.get("showdown_method"))!="trash":continue
		var payload:=str(choice.get("item_id",""))
		var entry:Variant=null
		for item in run.inventory:
			if str(item)==payload:entry=item;break
		_check(entry!=null,"existing serialized action payload still selects same inventory entry")
		_check(str(choice.id)=="trash_item__"+payload,"existing choice identity remains byte-equivalent")
		if typeof(entry)==TYPE_DICTIONARY:
			var instance_id:=int(entry.get("meta_collection",{}).get("instance_id",0))
			var expected:="Trash: Grand Casino Players Card #%d"%instance_id
			_check(str(choice.label)==expected,"Card%d Trash label is readable and instance-specific"%instance_id)
			_check(str(choice.text).contains("Grand Casino Players Card #%d"%instance_id) and not str(choice.text).contains("\"class\""),"Card description contains no dictionary dump")
			cards.append({"instance":instance_id,"label":choice.label,"payload_unchanged":payload==str(entry)})
		else:
			_check(str(choice.label)=="Trash: Marked Cards","ordinary string item label unchanged")
	_check(cards.size()==2,"both exact Card instances are presented separately")
	_check(app._show_interactable_event_popup(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID),"normal Review responses surface opens")
	var button_labels:=_buttons(app.event_choice_popup_choices_list)
	_check(button_labels.has("Trash: Grand Casino Players Card #3") and button_labels.has("Trash: Grand Casino Players Card #6"),"actual rendered buttons show both readable Card identities")
	_check(button_labels.has("Keep Everything") and button_labels.has("Trash: Marked Cards"),"ordinary and Keep controls remain present")
	_check(JSON.stringify(run.to_save_snapshot())==before,"view and popup rendering change no item, outcome, money, clock or RNG")
	app._show_interactable_event_popup(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)
	_check(_buttons(app.event_choice_popup_choices_list)==button_labels,"repeated Review responses preserves labels without duplicate buttons")
	_check(app.save_service.save_run(run,app.autosave_slot_id)==OK,"existing active walk saves without accepting a response")
	app.save_service=SaveService.new()
	_check(app.load_foundation_run(),"fresh SaveService Continue restores unresolved walk")
	_check(JSON.stringify(app.run_state.to_save_snapshot())==before,"saved unresolved state preserves exact cards, cash, clock and RNG")
	_check(app._show_interactable_event_popup(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID) and _buttons(app.event_choice_popup_choices_list)==button_labels,"cold rendered choices retain identity labels")
	facts={"cards":cards,"button_labels":button_labels,"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":str(run.rng_state),"trash_accepted":false}
	app.queue_free();await process_frame
	_finish()

func _buttons(control:Node)->Array:
	var result:=[]
	for child in control.get_children():
		if child is Button:result.append(child.text)
		result.append_array(_buttons(child))
	return result

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var file:=FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"fidelity":"Genuine copiedr265, native normal host Continue/Review popup/rendered controls and fresh SaveService restore. No Trash/Keep/Follow or deletion accepted; action payloads intentionally unchanged."},"  "));file.close()
	print("CARD_TRASH_LABEL checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
