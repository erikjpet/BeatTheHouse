extends SceneTree
const Main := preload("res://scripts/ui/foundation_main.gd")

class FaultProfile extends ProfileInventory:
	var save_error:Error=ERR_FILE_CANT_WRITE
	var calls:=0
	var durable:Dictionary={}
	func save()->Error:
		calls+=1
		if save_error==OK:durable=to_dict()
		return save_error

class FaultSettings extends UserSettings:
	var save_error:Error=ERR_FILE_CANT_WRITE
	var calls:=0
	var durable:Dictionary={}
	func save()->Error:
		calls+=1
		if save_error==OK:durable=to_dict()
		return save_error

class FaultMeta extends MetaCollectionService:
	var save_error:Error=ERR_FILE_CANT_WRITE
	var calls:=0
	var durable:Dictionary={}
	var packed:=false
	func save()->Error:
		calls+=1
		if save_error==OK:
			durable=snapshot()
			durable["test_packed"]=packed
		return save_error
	func pack_instance(_id:int)->Dictionary:
		packed=true
		return {"ok":true,"message":"Item packed."}
	func unpack_instance(_id:int)->Dictionary:
		packed=false
		return {"ok":true,"message":"Item unpacked."}

class Host extends Main:
	var notices:Array[String]=[]
	var popups:Array[String]=[]
	var logged:Array[String]=[]
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
	func _show_message(text:String)->void:notices.append(text)
	func _show_meta_popup(_title:String,summary:String,_type:String)->void:popups.append(summary)
	func _add_meta_close_card()->void:pass
	func _refresh()->void:pass
	func _refresh_meta_item_interaction()->void:pass
	func _refresh_home_type_controls()->void:pass
	func _apply_meta_environment(_id:String)->Dictionary:return {"ok":true}
	func _log_store_save_failure(context:String,error:Error)->void:logged.append(context+":"+str(error))

var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
func _init()->void:call_deferred("_run")
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _pending(app:Host,store:Object)->bool:
	for p in app.get_property_list():
		if p.name=="_pending_store_saves":
			var pending:Dictionary=app.get("_pending_store_saves")
			return pending.has(store.get_instance_id())
	return false
func _warned(app:Host)->bool:
	return (" ".join(app.notices)+" "+" ".join(app.popups)+" "+app.meta_last_panel_message).to_lower().contains("not saved")

func _run()->void:
	for kind in ["scratch","home_setting","reset_coach","seen_coach","purchase","pack","unpack"]:
		var app:=Host.new()
		var profile:=FaultProfile.new()
		var settings:=FaultSettings.new()
		var meta:=FaultMeta.new()
		app.profile_inventory=profile
		app.user_settings=settings
		app.meta_collection_service=meta
		var store:Object=profile
		if kind=="scratch":
			app._record_scratch_ticket_discovery("two_fer")
			_check(profile.scratch_ticket_types_discovered.has("two_fer"),"Scratch mutation retained")
		elif kind=="home_setting":
			store=settings
			app.home_type_option=OptionButton.new()
			app.add_child(app.home_type_option)
			app.home_type_option.add_item("Home")
			app.home_type_option.set_item_metadata(0,"test_home")
			app._on_home_type_selected(0)
			_check(settings.selected_home_type_id=="test_home","Home selection retained")
		elif kind=="reset_coach":
			profile.tips_seen={"audit":true}
			app._on_reset_coach_tips_requested()
			_check(profile.tips_seen.is_empty(),"Coach reset retained")
		elif kind=="seen_coach":
			app._on_coach_lesson_seen("audit_seen")
			_check(profile.tips_seen.has("audit_seen"),"Coach seen flag retained")
		elif kind=="purchase":
			store=meta
			meta.add_gold(10000)
			var quote:=meta.next_housing_upgrade()
			var expected_gold:int=int(meta.snapshot().get("gold_balance",0))-int(quote.get("price",0))
			app.buy_meta_home_upgrade()
			_check(meta.housing_tier()==str(quote.get("tier","")) and int(meta.snapshot().get("gold_balance",0))==expected_gold,"Actual housing purchase and exact cost retained")
		elif kind=="pack":
			store=meta
			app._toggle_meta_item_pack(101,true)
			_check(meta.packed,"Packing mutation retained")
		else:
			store=meta
			meta.packed=true
			app._toggle_meta_item_pack(101,false)
			_check(not meta.packed,"Unpacking mutation retained")
		_check(int(store.get("calls"))==1,kind+" attempted one actual caller save")
		_check(_pending(app,store),kind+" failed store remains pending")
		if kind in ["purchase","pack","unpack"]:_check(_warned(app),kind+" visibly says not saved")
		else:_check(app.popups.is_empty() and app.notices.is_empty(),kind+" has no modal/player interruption")
		observations.append({"case":kind,"pending":_pending(app,store),"warning":_warned(app),"save_calls":store.get("calls")})
		app.free()
	# Repeated failures log once, later real changes retry the same held state.
	var app:=Host.new()
	var profile:=FaultProfile.new()
	app.profile_inventory=profile
	app._on_coach_lesson_seen("first")
	app._on_reset_coach_tips_requested()
	_check(profile.calls==2 and app.logged.size()==1,"Repeated profile failures log once")
	profile.save_error=OK
	app._on_coach_lesson_seen("later")
	_check(profile.calls==3 and profile.durable.tips_seen.has("later"),"Next profile change saves held state")
	_check(not _pending(app,profile),"Profile success clears pending")
	_check(app.popups.is_empty() and app.notices.is_empty(),"Profile retry has no modal")
	var settings:=FaultSettings.new()
	app.user_settings=settings
	app.home_type_option=OptionButton.new()
	app.add_child(app.home_type_option)
	for id in ["first_home","later_home"]:
		app.home_type_option.add_item(id)
		app.home_type_option.set_item_metadata(app.home_type_option.item_count-1,id)
	app._on_home_type_selected(0)
	app._on_home_type_selected(0)
	_check(settings.calls==2 and app.logged.size()==2,"Repeated settings failures log once")
	settings.save_error=OK
	app._on_home_type_selected(1)
	_check(settings.calls==3 and settings.durable.selected_home_type_id=="later_home","Next setting change retries")
	_check(not _pending(app,settings),"Settings success clears pending")
	app.free()
	# A retry saves the existing paid state; it never invokes purchase again.
	app=Host.new()
	var meta:=FaultMeta.new()
	app.meta_collection_service=meta
	meta.add_gold(10000)
	app.buy_meta_home_upgrade()
	var gold:=int(meta.snapshot().get("gold_balance",0))
	var tier:=meta.housing_tier()
	if app.has_method("_retry_pending_meta_store"):
		app._retry_pending_meta_store()
		_check(meta.calls==2 and app.logged.size()==1 and _pending(app,meta),"Failed automatic retry remains pending without another log")
		meta.save_error=OK
		app._retry_pending_meta_store()
		_check(meta.calls==3 and not _pending(app,meta),"Successful meta retry clears pending")
		_check(int(meta.durable.get("gold_balance",-1))==gold and str(meta.durable.get("housing_tier",""))==tier,"Retry persists exact paid state without a second charge")
		_check(not app.meta_last_panel_message.contains("Not saved yet"),"Recovered panel status clears warning")
		meta.save_error=ERR_FILE_CANT_WRITE
		app._toggle_meta_item_pack(101,true)
		meta.save_error=OK
		app._retry_pending_meta_store()
		_check(bool(meta.durable.get("test_packed",false)),"Retry persists current packing state")
	else:_check(false,"Meta retry entry point exists")
	app.free()
	var probe:=Main.new()
	_check(probe.has_method("_persist_or_warn"),"Shared error boundary exists")
	probe.free()
	print("AUD061_14_IGNORED_STORES "+JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"Actual six caller sites plus both pack directions. Real profile/settings mutations and real housing upgrade/price. Pack domain service stubbed; caller behavior is under test. Empty Host has no canvases; full production liveness is a separate check."}))
	quit(0 if failures.is_empty() else 1)
