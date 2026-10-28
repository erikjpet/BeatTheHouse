extends SceneTree

const Terminal := preload("res://scripts/core/run_terminal_evaluator.gd")
const Rules := preload("res://scripts/games/craps/craps_rules.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class HotRun extends RunState:
	func suspicion_level() -> int: return 100

func _initialize() -> void: call_deferred("_run")

func _fixture(game_id: String = "craps", chips: int = 156, archetype: String = RunState.GRAND_CASINO_ARCHETYPE_ID) -> RunState:
	var run := RunState.new()
	run.start_new("GRAND-LIQUIDITY-BOUNDARY")
	run.current_environment = {"id":archetype,"archetype_id":archetype,"game_ids":[game_id],"economic_profile":{"stake_floor":10,"stake_ceiling":100},"game_states":{}}
	run.bankroll = 0
	run.grand_casino_chips = chips
	return run

func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH","BTH_TARGET_OUTPUT"]:
		private_ready = private_ready and not OS.get_environment(key).is_empty()
	if not check(private_ready,"private diagnostic persistence roots are required"):
		_finish()
		return
	var library := ContentLibrary.new()
	library.load(false)
	for game_id in ["blackjack","baccarat","roulette","craps","video_poker","pull_tabs","bar_dice"]:
		var run := _fixture(game_id)
		var before := run.to_save_snapshot()
		for terminal_only in [false,true]:
			var result := Terminal.evaluate_terminal(run,library) if terminal_only else Terminal.evaluate(run,library)
			check(not bool(result.failed), "%s chip-funded run survives evaluator mode%s" % [game_id,terminal_only])
			check(bool(result.wager_available), "%s existing chips fund valid wager in mode%s" % [game_id,terminal_only])
		check(run.bankroll == 0 and run.grand_casino_chips == 156 and run.rng_state == before.rng_state, "%s evaluation preserves cash/chips/RNG" % game_id)
		run.grand_casino_chips = 5
		check(not Terminal._has_valid_wager(run,library), "%s below-floor chips cannot invent an affordable wager" % game_id)
		run.grand_casino_chips = 10
		check(Terminal._has_valid_wager(run,library), "%s exact existing floor remains affordable" % game_id)
	var outside := _fixture("craps",156,"bar")
	check(Terminal.evaluate_terminal(outside,library).reason == RunState.FAILURE_BANKROLL_ZERO, "chips outside Grand do not become cash")
	var cash := _fixture("craps",0,"bar")
	cash.bankroll = 20
	check(not bool(Terminal.evaluate_terminal(cash,library).failed), "positive cash behavior retained")
	var broke := _fixture("craps",0)
	check(Terminal.evaluate_terminal_and_apply(broke,library).reason == RunState.FAILURE_BANKROLL_ZERO and broke.is_terminal(), "genuine empty bankroll still fails")
	var stopped := broke.to_save_snapshot()
	Terminal.evaluate_terminal_and_apply(broke,library)
	check(broke.to_save_snapshot() == stopped, "repeat failure does not settle or log again")
	var working := _fixture("craps",0)
	working.current_environment.game_states["craps"] = {"point":4,"working_bets":{"pass_line":5}}
	check(bool(Terminal.evaluate_terminal(working,library).bankroll_zero_deferred), "paid working Craps remains deferred")
	var lost := Rules.settle_roll(working.current_environment.game_states.craps,{}, {"dice":[3,4],"total":7},{})
	check(int(lost.bankroll_delta) == 0 and not working.has_working_craps_wagers(), "synthetic genuine last-line loss clears stakes")
	check(Terminal.evaluate_terminal_and_apply(working,library).reason == RunState.FAILURE_BANKROLL_ZERO, "fully settled genuine loss still fails")
	var paid_drop := _fixture("coin_pusher",0,"corner_store")
	paid_drop.current_environment.game_states["coin_pusher"] = {"schema":"coin_pusher_discrete_pile","paid_drop_pending":true,"total_cost":1,"tray_value":0}
	check(bool(Terminal.evaluate_terminal(paid_drop,library).bankroll_zero_deferred), "existing paid Coin Pusher deferral remains active")
	paid_drop.current_environment.game_states.coin_pusher["paid_drop_pending"] = false
	check(Terminal.evaluate_terminal(paid_drop,library).reason == RunState.FAILURE_BANKROLL_ZERO, "resolved empty Coin Pusher receipt no longer defers")
	var hot := HotRun.new()
	hot.current_environment = {"id":"bar","archetype_id":"bar"}
	hot.bankroll = 20
	check(Terminal.evaluate_terminal(hot,library).reason == RunState.FAILURE_POLICE_CAPTURE, "Heat precedence retained")
	hot.current_environment.local_narrative_flags = {"environment_test_session":true}
	hot.bankroll = 0
	check(not bool(Terminal.evaluate_terminal(hot,library).terminal), "practice protection retains precedence")
	var original_failed := _fixture()
	original_failed.run_status = RunState.RUN_STATUS_FAILED
	original_failed.run_failure_reason = RunState.FAILURE_BANKROLL_ZERO
	check(Terminal.evaluate_terminal(original_failed,library).reason == RunState.FAILURE_BANKROLL_ZERO, "historical failed chip balance is not revived")
	if not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty():
		await _captured_host()
	_finish()

func _captured_host() -> void:
	if not _install_bundle(): return
	root.size = Vector2i(1280,720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if not check(app.load_foundation_run(), "normal Continue loads unchanged captured copy"):
		app.queue_free()
		return
	for frame in range(3): await process_frame
	app.set_process(false)
	facts["before"] = _state(app.run_state)
	if app.run_state.is_terminal():
		var saved := app.run_state.to_save_snapshot()
		check(app.run_state.bankroll == 0 and app.run_state.grand_casino_chips == 156, "original historical failed fixture remains funded but terminal")
		Terminal.evaluate_terminal_and_apply(app.run_state,app.library)
		check(app.run_state.to_save_snapshot() == saved, "original failed fixture remains unchanged; no historical compensation")
	else:
		check(app.run_state.bankroll == 0 and app.run_state.grand_casino_chips == 0 and app.run_state.has_working_craps_wagers(), "captured z011 paid-zero-funds state remains active")
		check(app.enter_game("craps"), "normal table reentry accepts paid line")
		for frame in range(3): await process_frame
		app._on_game_surface_action("craps_throw",0)
		facts["result"] = app.last_game_result.duplicate(true)
		check(bool(app.last_game_result.get("ok",false)) and int(app.last_game_result.get("craps_total_wager",-1)) == 0, "normal THROW accepts zero new stake")
		check(app.run_state.bankroll == 0 and app.run_state.grand_casino_chips == 156 and not app.run_state.has_working_craps_wagers(), "captured natural win settles exactly156 chips once")
		check(not app.run_state.is_terminal(), "host evaluator preserves corrected chip-funded run")
		var settled := _state(app.run_state)
		facts["settled"] = settled.duplicate(true)
		app._on_game_surface_action("craps_throw",0)
		check(_state(app.run_state) == settled, "stale repeated THROW while roll locked does not pay or roll again")
		app.save_service.wait_for_async_save()
		check(app.save_service.save_run(app.run_state,app.autosave_slot_id) == OK, "settled active state saves")
		app.save_service = SaveService.new()
		check(app.load_foundation_run(), "fresh SaveService normal Continue restores settled win")
		var restored := _state(app.run_state)
		facts["restore_difference_keys"] = settled.keys().filter(func(key: Variant) -> bool: return not _equal(settled[key],restored.get(key)))
		facts["restore_numeric_type_differences"] = _numeric_type_differences(settled,restored)
		check(_equal(restored,settled) and not app.run_state.is_terminal(), "restore keeps exact funds/RNG/stakes and active status without replay")
	facts["after"] = _state(app.run_state)
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame

func _state(run: RunState) -> Dictionary:
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state,"status":run.run_status,"reason":run.run_failure_reason,"clock":run.game_clock_minutes,"craps":run.current_environment.get("game_states",{}).get("craps",{}).duplicate(true),"story":run.story_log.duplicate(true),"inventory":run.inventory.duplicate(true),"score":run.run_spending_score}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK, "install private unchanged " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user_dir.path_join(".crew_host_authority_v1")) == OK,"install private unchanged authority"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["",".bak"]:
			var original := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original,OS.get_environment(pair[1])+suffix) == OK,"install unchanged companion"): return false
	return true

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

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

func _numeric_type_differences(left: Variant, right: Variant, path: String = "state") -> Array:
	var differences: Array = []
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:
		if typeof(left) != typeof(right): differences.append({"path":path,"before_type":type_string(typeof(left)),"restored_type":type_string(typeof(right)),"equal_value":left == right})
	elif typeof(left) == typeof(right) and typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if (typeof(left) == TYPE_DICTIONARY and right.has(key)) or (typeof(left) == TYPE_ARRAY and key < right.size()):
				differences.append_array(_numeric_type_differences(left[key],right[key],path+"/"+str(key)))
	return differences

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Synthetic evaluator matrix plus optional official copied z011/z016 host Continue and native surface callback. Fresh SaveService restore in the same engine; no OS pointer/Web/cold-process claim. No RNG/outcome override."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("GRAND_CHIP_LIQUIDITY checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
