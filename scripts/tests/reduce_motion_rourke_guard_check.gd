extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")
const Ritual := preload("res://scripts/core/game_ritual_runtime.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class ClockHost extends Main:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int: return test_msec

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT","BTH_CAPTURED_FIXTURE","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH","BTH_TARGET_OUTPUT"]:
		private_ready = private_ready and not OS.get_environment(key).is_empty()
	if not check(private_ready,"private captured fixture roots required") or not _install_bundle():
		_finish()
		return
	var mode := OS.get_environment("BTH_REDUCE_MOTION_CASE")
	var reduced := mode.ends_with("_on")
	facts["case"] = mode
	root.size = Vector2i(1280,720)
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if not check(app.load_foundation_run(),"normal Continue loads unchanged pre-hand copy"):
		app.queue_free()
		_finish()
		return
	for frame in range(3): await process_frame
	app.set_process(false)
	if app.current_game == null: check(app.enter_game("blackjack"),"ordinary Rourke table entry")
	app.game_surface_canvas.set_process(false)
	# Native startup frames legitimately tick the ordinary canvas before this
	# controlled-clock fixture takes ownership. Anchor from that observed value.
	app.test_msec = app.game_surface_canvas.surface_simulation_time_msec()
	check(app.current_game != null and app.current_game.get_id() == "blackjack","captured Rourke game is active")
	check(app.user_settings.reduce_motion == reduced and app.game_surface_canvas.reduce_motion == reduced,"copied persisted Reduce Motion setting is used")
	check(not app._simulation_progression_paused(),"captured pre-hand state has no blocking pause")
	var before := _state(app)
	facts["before"] = before
	check(before.hands == 0 and before.calls.size() == 0 and before.player_stack == 66 and before.rourke_stack == 125,"official pre-hand fixture is unplayed66/125")
	facts["initial_clocks"] = _clocks(app)
	_tick(app,10000)
	facts["idle_clocks"] = _clocks(app)
	check(app._current_game_surface_input_time_msec() == app.test_msec,"after10s idle visible input time equals automation time")
	check(app.game_surface_canvas.surface_presentation_time_msec() == int(facts.initial_clocks.presentation) + (0 if reduced else 10000),"idle presentation stays reduced or advances normally")
	check(_equal(_state(app),before),"idle clock advancement does not alter cards/RNG/duel/wallet")
	app._on_game_surface_action("blackjack_deal",0)
	app.game_surface_canvas.set_process(false)
	var session := _session(app)
	var started := int(session.get("deal_started_msec",0))
	var duration := int(app.current_game._deal_animation_duration_msec(session.get("deal_animation_events",[])))
	facts["deal"] = {"clocks":_clocks(app),"started":started,"duration":duration,"timing_enforced":session.get("presentation_timing_enforced")}
	check(started == app.test_msec,"sealed Deal rebases presentation against current input time")
	check(duration == 1600,"authored four-card1600ms guard is unchanged")
	check(bool(session.get("presentation_timing_enforced",false)),"existing timing authority remains enabled")
	_tick(app,632)
	facts["call_window"] = {"clocks":_clocks(app),"auto_due":app.current_game._blackjack_host_needs_auto_tick(app.test_msec,app.run_state,app.run_state.current_environment)}
	check(not bool(facts.call_window.auto_due),"new Deal cannot auto-settle before the632ms call")
	if mode.begins_with("uncalled"):
		_tick(app,967)
		check(not app.current_game._blackjack_host_needs_auto_tick(app.test_msec,app.run_state,app.run_state.current_environment),"guard still blocks natural settlement at1599ms")
		_tick(app,2)
		check(app.current_game._blackjack_host_needs_auto_tick(app.test_msec,app.run_state,app.run_state.current_environment),"uncalled natural becomes due after original1600ms guard")
		app._advance_game_surface_automation()
		var settled := _state(app)
		check(settled.hands == 1 and settled.calls.size() == 0 and settled.player_stack == 46 and settled.rourke_stack == 145,"actual uncalled natural transfers20 once; no forever-active hand")
		app._advance_game_surface_automation()
		check(_equal(_state(app),settled),"same-boundary repeated automation does not settle twice")
	else:
		var swap_index := -1
		var callouts: Array = app.game_surface_canvas.state.get("boss_callouts",[])
		for index in range(callouts.size()):
			if str(callouts[index].get("label","")).to_lower().contains("swap"): swap_index = index
		check(swap_index >= 0,"observed public Call Swap option is available")
		if swap_index >= 0: app._on_game_surface_action("blackjack_boss_callout",swap_index)
		var called := _state(app)
		facts["after_call"] = called
		check(called.hands == 0 and called.calls.size() == 1 and called.player_stack == 84 and called.rourke_stack == 107,"normal Call Swap at632ms transfers18 once and leaves live H1")
		check(called.calls.size() == 1 and bool(called.calls[0].get("correct",false)) and int(called.calls[0].get("stack_swing",0)) == 18,"existing correct-call receipt preserved")
		check(called.cash == before.cash and called.chips == before.chips,"call does not charge the external wallet")
		# Standard native Settings controls, with the original pause owner intact.
		app.open_run_menu()
		app.run_menu_settings_button.pressed.emit()
		app._sync_simulation_pause_owners()
		check(app.settings_overlay.visible and app._run_menu_is_visible(),"Settings opens through the real paused Run Menu route")
		var paused_input: int = app.game_surface_canvas.surface_simulation_time_msec()
		app.game_surface_canvas._process(2.0)
		check(app.game_surface_canvas.surface_simulation_time_msec() == paused_input,"Settings pause freezes live input clock")
		app.settings_menu.reduce_motion.button_pressed = not reduced
		app.settings_menu.apply_button.pressed.emit()
		app.close_settings_menu()
		app.close_run_menu()
		app._sync_simulation_pause_owners()
		check(app.user_settings.reduce_motion != reduced,"normal Settings Apply changes only the motion preference")
		check(_equal(_state(app),called),"live setting transition does not redeal/charge/rewind/RNG-roll")
		check(app.save_service.save_run(app.run_state,app.autosave_slot_id) == OK,"live accepted call saves via official SaveService")
		app.save_service = SaveService.new()
		check(app.load_foundation_run(),"fresh SaveService normal Continue restores live accepted call")
		check(_equal(_state(app),called),"restored cards/RNG/edge/call/duel identities survive without replay")
	facts["after"] = _state(app)
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()

func _tick(app: ClockHost, milliseconds: int) -> void:
	app.test_msec += milliseconds
	app.game_surface_canvas.set_process(false)
	app.game_surface_canvas._process(float(milliseconds)/1000.0)

func _clocks(app: ClockHost) -> Dictionary:
	return {"automation":app.test_msec,"input":app._current_game_surface_input_time_msec(),"simulation":app.game_surface_canvas.surface_simulation_time_msec(),"presentation":app.game_surface_canvas.surface_presentation_time_msec()}

func _session(app: ClockHost) -> Dictionary:
	if app.current_game == null: return {}
	var table: Dictionary = app.current_game._peek_table_state(app.run_state.current_environment)
	return table.get(Blackjack.BLACKJACK_HOST_LEDGER_KEY,{}).get("session",{}).duplicate(true)

func _state(app: ClockHost) -> Dictionary:
	var run := app.run_state
	var duel := run.grand_casino_duel_status()
	var session := _session(app)
	var calls: Array = run.story_log.filter(func(row: Dictionary) -> bool: return str(row.get("type","")) == "grand_casino_duel_callout")
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state,"inventory":run.inventory.duplicate(true),"status":run.run_status,"hands":duel.get("hands",[]).size(),"player_stack":int(duel.get("player_stack",0)),"rourke_stack":int(duel.get("rourke_stack",0)),"calls":calls.duplicate(true),"live_cards_hash":Ritual.canonical_fingerprint({"hands":session.get("hands",[]),"dealer_cards":session.get("dealer_cards",[]),"original_dealer_cards":session.get("boss_original_dealer_cards",[])})}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK,"install unchanged private save"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user_dir.path_join(".crew_host_authority_v1")) == OK,"install unchanged private authority"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["",".bak"]:
			var path := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(path) and not check(DirAccess.copy_absolute(path,OS.get_environment(pair[1])+suffix) == OK,"install unchanged private companion"): return false
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

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Original r352/k004 pre-hand bytes and companion settings through host Continue. Native public surface/Settings callbacks with an explicitly controlled host automation clock and real canvas delta ticks; actual authority/game rules/RNG unchanged. Same-engine fresh SaveService restore, not trusted pointer/Web/cold-process timing coverage. No settled QA hand replay."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("REDUCE_MOTION_ROURKE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
