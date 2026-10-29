extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Publication := preload("res://scripts/core/room_presentation_publication.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SCALPER := "dialogue:scratch_ticket_scalper"
var checks := 0
var facts := {}
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var cold := OS.get_environment("BTH_ROOM028_STAGE") == "cold"
	for key in ["BTH_CAPTURED_FIXTURE","BTH_TARGET_OUTPUT","BTH_DISTRIBUTION_DATA_ROOT","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH"]:
		if not check(OS.get_environment(key).is_absolute_path(),"private absolute path required "+key): _finish(); return
	if not cold and not _install(OS.get_environment("BTH_CAPTURED_FIXTURE")): _finish(); return
	var slot_id := "room028_roundtrip" if cold else "foundation_ui_autosave"
	var reference: Variant = SaveService.new().load_run(slot_id)
	if not check(reference is RunState,"official unchanged copied save/roundtrip loads"): _finish(); return
	var expected := _protected(reference)
	root.size = Vector2i(1280,720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = slot_id
	if not check(app.load_foundation_run(),"normal host Continue accepts exact campaign"):
		app.queue_free(); await process_frame; _finish(); return
	for frame in range(3): await process_frame
	facts["initial_protected_difference_paths"] = _difference_paths(expected,_protected(app.run_state))
	check(_equal(_protected(app.run_state),expected),"Continue preserves complete protected finances/paid machines/history/clock/RNG")
	_check_room(app,"initial")
	_check_guards(app)
	if OS.get_environment("BTH_ROOM028_ACTIVATE") == "1":
		check(app.run_state.inventory.has("lucky_reel_grease"),"actual before fixture carries Grease")
		check(app.enter_game("slot"),"normal Slot entry requires no wager")
		for frame in range(3): await process_frame
		check(app.use_active_item_slot(),"normal Header Use opens item review")
		check(app.pending_active_item_id == "lucky_reel_grease","review owns exact Grease confirmation")
		app.confirm_pending_active_item_use()
		for frame in range(3): await process_frame
		check(not app.run_state.inventory.has("lucky_reel_grease"),"one confirmed use consumes one bottle")
		check(_charges(app.run_state) == 10,"one accepted use arms exactly ten spins")
		var accepted: Dictionary = app.run_state.to_save_snapshot().duplicate(true)
		app.confirm_pending_active_item_use()
		check(app.run_state.to_save_snapshot() == accepted,"stale repeated confirmation cannot regrant charges")
		app.back_to_environment()
		for frame in range(3): await process_frame
		check(app.current_game == null,"normal Back returns to room without a Spin")
		_check_room(app,"after_activation")
		expected = _protected(app.run_state)
	app.open_run_menu()
	for frame in range(2): await process_frame
	var before: Dictionary = app.run_state.to_save_snapshot().duplicate(true)
	app._prepare_room_presentation_at_boundary()
	check(app.run_state.to_save_snapshot() == before,"repeat causal preparation preserves full paused state")
	var catalog := Controller.prepare_room_catalog_at_boundary(app)
	check(app.run_state.to_save_snapshot() == before,"detached catalog composition cannot mutate or reroll")
	check(catalog.size() >= 17,"combined sealed/live catalog survives")
	app.save_service.wait_for_async_save()
	check(app.save_service.save_run(app.run_state,"room028_roundtrip") == OK,"official private Save succeeds")
	var fresh: Variant = SaveService.new().load_run("room028_roundtrip")
	if fresh is RunState: facts["fresh_protected_difference_paths"] = _difference_paths(expected,_protected(fresh))
	check(fresh is RunState and _equal(_protected(fresh),expected),"fresh service preserves accepted item and paid authority")
	app.autosave_slot_id = "room028_roundtrip"
	check(app.load_foundation_run(),"same-host Continue accepts private saved result")
	app.open_run_menu()
	for frame in range(3): await process_frame
	facts["saved_protected_difference_paths"] = _difference_paths(expected,_protected(app.run_state))
	check(_equal(_protected(app.run_state),expected),"repeated Continue never replays item use or changes protected campaign")
	_check_room(app,"saved_continue")
	facts["protected"] = {"cash":app.run_state.bankroll,"heat":app.run_state.suspicion_level(),"charges":_charges(app.run_state),"spin_count":app.run_state.current_environment.get("game_states",{}).get("slot",{}).get("spin_count",0),"sha256":Runtime.canonical_fingerprint(expected)}
	facts["cold_process"] = cold
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()

func _check_room(app: Variant, tag: String) -> void:
	check(bool(Publication.validate(app.run_state.current_environment).get("ok",false)),tag+" strict publication validates")
	check(not app._room_recovery_active_for_current_room(),tag+" no Room unavailable recovery")
	var catalog: Array = app.room_catalog_snapshot()
	var ids := {}
	var slots := {}
	for record in catalog:
		var identity := str(record.get("object_id",""))
		ids[identity] = record
		var slot := str(record.get("slot_id",""))
		if str(record.get("presentation_mode","room")) != "room" or not bool(record.get("visible",true)) or slot.is_empty(): continue
		check(not slots.has(slot),tag+" unique physical slot "+slot)
		slots[slot] = identity
	for id in ["game:slot","game:pull_tabs","game:scratch_tickets","character:nell","travel:leave"]:
		check(ids.has(id),tag+" room object retained "+id)
		if ids.has(id): check(bool(ids[id].get("interactive",false)) and bool(ids[id].get("enabled",true)),tag+" action usable "+id)
	var present := bool(app.run_state.current_environment.get("game_states",{}).get("scratch_tickets",{}).get("scalper_present",false))
	check(ids.has(SCALPER) == present,tag+" displayed actor matches committed machine presence")
	if present:
		check(not str(ids[SCALPER].get("slot_id","")).is_empty(),tag+" arrival owns authored slot")
		var count := 0
		for row in app.run_state.current_environment.get("object_manifest",{}).get("rows",[]):
			if str(row.get("presentation_object_id","")) == SCALPER: count += 1
		check(count == 1,tag+" arrival has one committed physical row")
	check(app.environment_canvas.foundation_scene_objects.size() >= 17,tag+" actual Canvas retains controls")
	facts[tag] = {"catalog_count":catalog.size(),"canvas_count":app.environment_canvas.foundation_scene_objects.size(),"scalper":present,"slots":slots}

func _check_guards(app: Variant) -> void:
	var game: GameModule = app._game_module_for_id("scratch_tickets")
	var before: Dictionary = app.run_state.to_save_snapshot().duplicate(true)
	check(not bool(game.prepare_environment_presentation_boundary(app.run_state,app.run_state.current_environment.duplicate(true)).get("ok",true)),"detached environment cannot claim live owner boundary")
	check(app.run_state.to_save_snapshot() == before,"rejected owner changes nothing")
	var layout: Dictionary = app.run_state.current_environment.get("layout",{}).duplicate(true)
	app.run_state.current_environment["layout"]["slot_binding_digest"] = "tampered"
	var rejected: Dictionary = app.run_state.to_save_snapshot().duplicate(true)
	check(not bool(game.prepare_environment_presentation_boundary(app.run_state,app.run_state.current_environment).get("ok",true)),"tampered physical authority remains rejected")
	check(app.run_state.to_save_snapshot() == rejected,"rejected authority is never re-signed by presence preparation")
	app.run_state.current_environment["layout"] = layout
	var finalized: Dictionary = app.run_state.room_presentation_snapshot().get("finalized",{})
	var incomplete: Array = finalized.get("records",[]).duplicate(true)
	if not incomplete.is_empty(): incomplete.pop_back()
	check(not bool(Controller.project_finalized_sequence_interaction_result(incomplete,finalized).get("ok",true)),"strict sealed coverage rejection remains")
	check(app.run_state.to_save_snapshot() == before,"guard checks restore exact accepted state")

func _protected(run: RunState) -> Dictionary:
	var result := {}
	var snapshot := run.to_save_snapshot()
	for key in ["bankroll","grand_casino_chips","inventory","active_item_id","story_log","debt","rng_seed","rng_state","game_clock_minutes","simulation_msec","numbers_state","crew_state","narrative_flags","story_flags","active_delivery_run","portable_ticket_piles","run_spending_score","run_status"]:
		if snapshot.has(key): result[key] = snapshot[key]
	for id in run.current_environment.get("game_states",{}):
		if id != "scratch_tickets": result["paid_machine/"+str(id)] = run.current_environment.game_states[id]
	var machine: Dictionary = run.current_environment.get("game_states",{}).get("scratch_tickets",{})
	# Generated/compact machines omit empty paid piles; normalization materializes
	# those same empty values. Compare their contents, including every nonempty
	# ticket field, without mistaking absent-empty shape for a new paid asset.
	result["scratch_paid/active_ticket"] = machine.get("active_ticket",{})
	for key in ["tray_stack","pending_queue","winner_pile"]: result["scratch_paid/"+key] = machine.get(key,[])
	for key in ["history","purchase_count","redemption_count","ticket_sequence","pending_payout","coin_in","coin_out"]:
		if machine.has(key): result["scratch_paid/"+key] = machine[key]
	var sequence: Dictionary = run.current_environment.get("scenario_sequence_state",{}).duplicate(true)
	# Trusted journal replay intentionally suppresses already-consumed one-shot
	# presentation transitions/stages. All causal, outcome and expiry records stay.
	for key in ["semantic_state","transition_delivery_receipts","active_stages"]: sequence.erase(key)
	result["scenario_causal_and_outcome_journal"] = sequence
	return result.duplicate(true)

func _charges(run: RunState) -> int:
	return int(run.current_environment.get("game_states",{}).get("slot",{}).get("slot_item_state",{}).get("lucky_reel_grease_spins",0))

func _install(bundle: String) -> bool:
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK,"install unchanged copied save"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1")) == OK,"install unchanged authority companion"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var source := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(source) and not check(DirAccess.copy_absolute(source,OS.get_environment(pair[1])+suffix) == OK,"install unchanged companion"): return false
	return true

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key],right[key]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _difference_paths(left: Variant, right: Variant, path: String = "") -> Array:
	if _equal(left,right): return []
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		var keys: Array = left.keys()
		for key in right:
			if not keys.has(key): keys.append(key)
		var paths := []
		for key in keys:
			if not left.has(key) or not right.has(key): paths.append(path+"/"+str(key))
			else: paths.append_array(_difference_paths(left[key],right[key],path+"/"+str(key)))
		return paths
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY and left.size() == right.size():
		var paths := []
		for index in range(left.size()): paths.append_array(_difference_paths(left[index],right[index],path+"/"+str(index)))
		return paths
	return [path]

func _finish() -> void:
	var file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"fidelity":"Actual copied pre/post item state with native host Continue, optional one normal confirmation, Canvas, repeat/guard checks and official Save/fresh-service. No Spin, OS pointer or original mutation."},"\t"))
	print("ROOM028_RESTORE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
