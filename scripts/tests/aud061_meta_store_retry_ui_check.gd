extends SceneTree
const MainScene := preload("res://scenes/main.tscn")
const Meta := preload("res://scripts/core/meta_collection_service.gd")

class FaultMeta extends Meta:
	var calls:=0
	func save()->Error:
		calls+=1
		return super.save()

var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}
func _init()->void:call_deferred("_run")
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _frames(n:int)->void:
	for i in range(n):await process_frame
func _run()->void:
	Engine.max_fps=60
	root.size=Vector2i(1280,720)
	var app=MainScene.instantiate()
	root.add_child(app)
	await _frames(8)
	app._settle_script_prewarm_before_runtime()
	var service:=FaultMeta.new()
	service.add_gold(10000)
	service.gold_delta_applied.connect(app._on_meta_gold_delta_applied)
	app.meta_collection_service=service
	app.open_meta_home()
	await _frames(8)
	_check(app.meta_session_active,"Actual Meta Home is active")
	var quote:=service.next_housing_upgrade()
	var gold_before:=int(service.snapshot().get("gold_balance",0))
	var expected_gold:=gold_before-int(quote.get("price",0))
	var primary:=service.store_path()
	var temp:=ProjectSettings.globalize_path(primary+".tmp")
	var own_root:=OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/").trim_suffix("/") + "/"
	var admitted:=not own_root.is_empty() and temp.replace("\\", "/").to_lower().begins_with(own_root.to_lower()) and not temp.to_lower().begins_with("c:")
	_check(admitted,"Physical fault stays inside admitted private non-C run")
	if not admitted:
		app.queue_free()
		await _frames(4)
		print("AUD061_14_PATH_GATE_REJECTED")
		quit(1)
		return
	var had_primary:=FileAccess.file_exists(primary)
	var prior_bytes:=FileAccess.get_file_as_bytes(primary) if had_primary else PackedByteArray()
	_check(not DirAccess.dir_exists_absolute(temp) and not FileAccess.file_exists(temp),"Temporary fault path starts absent")
	_check(DirAccess.make_dir_recursive_absolute(temp)==OK,"Owned temporary-path directory creates an actual filesystem write failure")
	app.buy_meta_home_upgrade()
	await _frames(3)
	_check(service.housing_tier()==str(quote.get("tier","")) and int(service.snapshot().get("gold_balance",0))==expected_gold,"Paid upgrade remains in real service memory")
	_check(FileAccess.get_file_as_bytes(primary)==prior_bytes if had_primary else not FileAccess.file_exists(primary),"Failed write preserves prior durable generation")
	_check(app._meta_store_save_pending() and app._meta_store_retry_scheduled,"Failed save has a real scheduled retry")
	var popup:Label=app.event_choice_popup_summary_label
	_check(popup.is_visible_in_tree() and popup.text.contains(app.STORE_SAVE_PENDING_MESSAGE),"Actual visible purchase popup shows unsaved status")
	facts["purchase_warning"]=popup.text
	app._hide_event_choice_popup()
	app.open_meta_container()
	await _frames(4)
	var summary:Label=app.meta_item_interaction_screen._summary_label
	_check(summary.is_visible_in_tree() and summary.text.contains(app.STORE_SAVE_PENDING_MESSAGE),"Actual visible collection header shows pending status")
	facts["collection_warning"]=summary.text
	var selected:String=app.meta_item_interaction_screen.selected_key()
	_check(DirAccess.remove_absolute(temp)==OK,"Only the owned empty temporary-path fault is removed")
	var before_retry_calls:=service.calls
	await create_timer(3.6).timeout
	await _frames(3)
	_check(service.calls>before_retry_calls,"Real timer invokes a retry without another action")
	_check(not app._meta_store_save_pending(),"Actual scheduled retry clears pending state")
	_check(not summary.text.contains(app.STORE_SAVE_PENDING_MESSAGE),"Visible collection header clears recovered status")
	_check(app.meta_item_interaction_screen.selected_key()==selected,"Retry preserves current collection selection")
	var fresh:=Meta.new()
	fresh.load()
	var loaded:=fresh.snapshot()
	_check(str(loaded.get("housing_tier",""))==str(quote.get("tier","")),"Fresh service loads upgraded home from actual disk")
	_check(int(loaded.get("gold_balance",-1))==expected_gold,"Fresh service loads exact paid balance with no second charge")
	facts["recovered_summary"]=summary.text
	facts["gold_before"]=gold_before
	facts["upgrade_price"]=int(quote.get("price",0))
	facts["gold_saved"]=loaded.get("gold_balance")
	facts["save_calls"]=service.calls
	_check(not app._meta_store_retry_scheduled,"Retry chain stops after successful persistence")
	print("AUD061_14_META_RETRY_UI "+JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"scope":"Actual production Main, Meta Home, popup and collection header, real timer and final DurableStore disk write/load. Synthetic QA gold supplied through actual add_gold; actual filesystem directory fault blocks the temporary write and is removed before retry. Save override only counts calls and always delegates to production save. No processing/rendering disabled."}))
	app.queue_free()
	await _frames(4)
	quit(0 if failures.is_empty() else 1)
