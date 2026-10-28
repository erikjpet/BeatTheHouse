extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Drops := preload("res://scripts/core/collection_drop_service.gd")

class FailMeta extends MetaCollectionService:
	var fail_next := false
	func save() -> Error:
		if fail_next:
			fail_next = false
			DurableStoreScript.set_debug_force_write_failure(true)
			var error := super.save()
			DurableStoreScript.reset_debug_faults()
			return error
		return super.save()

class FailSave extends SaveService:
	var fail_next := false
	func save_run(run: RunState, slot_id: String = "autosave") -> Error:
		if fail_next:
			fail_next = false
			DurableStoreScript.set_debug_force_rename_failure(true)
			var error := super.save_run(run, slot_id)
			DurableStoreScript.reset_debug_faults()
			return error
		return super.save_run(run, slot_id)

var checks := 0
var failures: Array[String] = []
var facts := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var bundle := OS.get_environment("BTH_BAG_CLAIM_BUNDLE")
	var mode := OS.get_environment("BTH_BAG_CLAIM_CASE")
	if not _check(not bundle.is_empty(), "private captured bundle supplied"): return _finish()
	_install(bundle)
	var original_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_META_COLLECTION_PATH")))
	root.size = Vector2i(1280,720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	_check(app.load_foundation_run(), "normal host Continue loads genuine terminal save")
	var run: RunState = app.run_state
	var signature := _signature(run)
	var markers := run.pending_bag_markers()
	var receipt := str(run.narrative_flags.get(Drops.SAL_STOCK_RECEIPT_FLAG,""))
	_check(run.bankroll == 209 and run.grand_casino_chips == 0 and run.run_status == RunState.RUN_STATUS_ENDED, "actual terminal balances/status preserved")
	_check(receipt == "sal-run:3:RUN-20261027-711800-003", "existing unique run identity retained")
	if mode == "legacy":
		_check(markers.is_empty() and bool(run.narrative_flags.get(Drops.FLUSHED_FLAG,false)), "load alone recovers selected claim")
		_check(_ids(app.meta_collection_service.unopened_bags()) == [4,7,9], "legacy Bag9 recognized without allocation/deletion")
		_check(app.meta_collection_service.snapshot().next_instance_id == 10, "legacy next instance remains10")
		_check(app.meta_collection_service.terminal_bag_claim(receipt).instance_id == 9, "legacy grant receives durable per-run receipt")
	else:
		_check(markers.size() == 3 and app._terminal_reward_selection_pending(), "unclaimed three alternatives stay pending")
		_check(app.run_report_screen.home_button.disabled and app.run_report_screen.bag_claim_button.visible, "actual report locks navigation before claim")
		var marker_id := str(markers[0].marker_id)
		if mode == "faults":
			var meta := FailMeta.new();meta.load();meta.fail_next = true
			app.meta_collection_service = meta
			var before := meta.snapshot()
			app.claim_victory_collection_bag(marker_id)
			_check(meta.snapshot() == before, "failed meta write rolls back allocation and receipt staging")
			_check(run.pending_bag_markers() == markers and app._terminal_reward_selection_pending(), "failed meta save leaves claim and navigation pending")
			var save := FailSave.new();save.fail_next = true;app.save_service = save
			app.claim_victory_collection_bag(marker_id)
			_check(_ids(meta.unopened_bags()) == [4,7,9] and meta.terminal_bag_claim(receipt).instance_id == 9, "meta succeeds before injected run-save failure")
			_check(run.pending_bag_markers() == markers and not bool(run.narrative_flags.get(Drops.FLUSHED_FLAG,false)), "run-save failure restores pending flags")
			_check(app.run_report_screen.home_button.disabled, "run-save failure does not unlock report")
			# Retry a different stale alternative: the already durable selection wins.
			app.claim_victory_collection_bag(str(markers[1].marker_id))
		else:
			app.run_report_screen.bag_claim_button.pressed.emit()
		_check(bool(run.narrative_flags.get(Drops.FLUSHED_FLAG,false)) and run.pending_bag_markers().is_empty(), "claim clears pending and records selected/flushed")
		_check(_ids(app.meta_collection_service.unopened_bags()) == [4,7,9], "one bag added, old bags unchanged")
		_check(app.meta_collection_service.snapshot().next_instance_id == 10, "one ID allocated")
		var selected := str(run.narrative_flags.get(Drops.SELECTED_FLAG,""))
		_check(selected == marker_id, "first durable selection wins over stale alternate")
		var before := app.meta_collection_service.snapshot()
		app.claim_victory_collection_bag(marker_id)
		app.claim_victory_collection_bag(str(markers[2].marker_id))
		_check(app.meta_collection_service.snapshot() == before, "same/different repeated callbacks cannot regrant or consume IDs/RNG")
	_check(not app._terminal_reward_selection_pending() and not app.run_report_screen.home_button.disabled and not app.run_report_screen.new_run_button.disabled, "durable claim unlocks real Home/New Run controls")
	_check(_signature(run) == signature, "claim/recovery leaves cash/debt/score/ending/history/cards/run RNG unchanged")
	var meta_before: Dictionary = app.meta_collection_service.snapshot()
	var before_file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT").get_base_dir().path_join("meta-before-cold.json"),FileAccess.WRITE)
	before_file.store_string(JSON.stringify(meta_before));before_file.close()
	app.meta_collection_service = MetaCollectionService.new();app.meta_collection_service.load()
	app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "fresh SaveService/meta cold Continue succeeds")
	_check(bool(app.run_state.narrative_flags.get(Drops.FLUSHED_FLAG,false)) and app.run_state.pending_bag_markers().is_empty(), "claimed state was actually saved before leaving report")
	var meta_after: Dictionary = app.meta_collection_service.snapshot()
	var after_file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT").get_base_dir().path_join("meta-after-cold.json"),FileAccess.WRITE)
	after_file.store_string(JSON.stringify(meta_after));after_file.close()
	_check(JSON.parse_string(JSON.stringify(meta_after)) == JSON.parse_string(JSON.stringify(meta_before)), "cold Continue causes no second grant or meta RNG change (serialized numeric semantics)")
	_check(_signature(app.run_state) == signature, "cold Continue preserves authoritative terminal state")
	_check(_same_json(app.meta_collection_service.owned_instances(),original_meta.get("owned_instances",[])), "all exact original Card/item instances unchanged")
	var bags: Array = app.meta_collection_service.unopened_bags()
	_check(_same_json(bags.slice(0,2),original_meta.get("unopened_bags",[]).slice(0,2)), "old Bag4/Bag7 metadata unchanged")
	if mode == "legacy":
		_check(_same_json(bags[2],original_meta.get("unopened_bags",[])[2]), "entire legacy Bag9 metadata and rolled tier unchanged")
		_negative_contract_checks(app.meta_collection_service.terminal_bag_claim(receipt))
	if mode == "fresh":
		var opened: Dictionary = app.meta_collection_service.open_bag(9)
		_check(bool(opened.get("ok",false)) and app.meta_collection_service.save() == OK, "separate diagnostic opens already claimed bag normally")
		var after_open: Dictionary = app.meta_collection_service.snapshot()
		_copy_run(bundle)
		app.save_service = SaveService.new()
		_check(app.load_foundation_run(), "simulated interrupted/backup run acknowledgement recovers after bag opening")
		_check(app.meta_collection_service.snapshot() == after_open and app.run_state.pending_bag_markers().is_empty(), "per-run receipt survives bag opening, no regrant or reroll")
		# Explicitly synthetic distinct-run/same-seed unit boundary, not a played run.
		var second := RunState.new()
		second.from_dict(app.run_state.to_save_snapshot())
		second.narrative_flags[ Drops.SAL_STOCK_RECEIPT_FLAG ] = "sal-run:4:RUN-20261027-711800-003"
		second.narrative_flags.erase(Drops.FLUSHED_FLAG)
		for value in markers: second.add_pending_bag_marker(value)
		var result: Dictionary = app.collection_drop_service.flush_selected_pending_bag(second,app.meta_collection_service,str(markers[0].marker_id))
		_check(bool(result.get("ok",false)) and bool(result.get("resolved",false)), "different run receipt with identical marker gets its own earned choice")
		_check(app.meta_collection_service.terminal_bag_claim(receipt).instance_id == 9 and app.meta_collection_service.terminal_bag_claim(str(second.narrative_flags[Drops.SAL_STOCK_RECEIPT_FLAG])).instance_id != 9, "per-run receipts distinguish identical seeds and survive normalization")
		_check(_signature(app.run_state) == signature, "synthetic service boundary never changes actual terminal campaign")
	facts = {"case":mode,"cash":app.run_state.bankroll,"run_rng":str(app.run_state.rng_state),"home_enabled":not app.run_report_screen.home_button.disabled,"claim_receipt_bag9":app.meta_collection_service.terminal_bag_claim(receipt).get("instance_id"),"fidelity":"Official unchanged copied save/authority, host Continue and claim/render controls; injected failures and same-seed unit variation explicitly diagnostic. No QA originals changed."}
	app.queue_free();await process_frame
	_finish()

func _signature(run:RunState)->Dictionary:
	var s := run.to_save_snapshot()
	s.erase("pending_bags")
	var flags:Dictionary = s.get("narrative_flags",{})
	for key in [Drops.FLUSHED_FLAG,Drops.SELECTED_FLAG,Drops.GRANTS_FLAG]: flags.erase(key)
	return s

func _same_json(a:Variant,b:Variant)->bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _negative_contract_checks(marker:Dictionary)->void:
	# Explicit synthetic unit inputs; no captured campaign is changed or saved.
	var meta := MetaCollectionService.new()
	var before := meta.snapshot()
	_check(not bool(meta.commit_terminal_bag_claim("",marker).get("ok",false)), "missing unique run receipt cannot grant")
	_check(not bool(meta.commit_terminal_bag_claim("diagnostic-run",{}).get("ok",false)), "malformed marker cannot grant")
	_check(meta.snapshot() == before, "rejected identity/marker leaves meta state unchanged")
	meta.grant_bag(int(marker.bagdef_id),str(marker.rng_seed),marker)
	before = meta.snapshot()
	_check(not bool(meta.legacy_terminal_bag_claim("diagnostic-run",[marker]).get("ok",false)), "unproved single legacy match is not silently adopted")
	_check(meta.snapshot() == before, "ambiguous legacy lookup is read-only")
	meta.grant_bag(int(marker.bagdef_id),str(marker.rng_seed),marker)
	before = meta.snapshot()
	_check(not bool(meta.legacy_terminal_bag_claim("diagnostic-run",[marker]).get("ok",false)), "multiple legacy matches cannot choose or grant another reward")
	_check(meta.snapshot() == before, "multiple-match rejection allocates nothing")

func _ids(entries:Array)->Array:
	var result:=[]
	for entry in entries: result.append(int(entry.get("instance_id",0)))
	return result

func _copy_run(bundle:String)->void:
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"install private actual save companion")

func _install(bundle:String)->void:
	_copy_run(bundle)
	var user := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(user)
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"install unchanged private authority")
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			_check(DirAccess.copy_absolute(bundle.path_join(pair[0]+suffix),OS.get_environment(pair[1])+suffix)==OK,"install private profile companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok: failures.append(message)
	return ok

func _finish()->void:
	var file:=FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("TERMINAL_BAG_CLAIM checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
