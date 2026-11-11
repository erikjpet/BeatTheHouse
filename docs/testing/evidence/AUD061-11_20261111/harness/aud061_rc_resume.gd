extends SceneTree
const Main := preload("res://scripts/ui/foundation_main.gd")
const Crew := preload("res://scripts/core/crew_recruitment_model.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const CABINET_GAMES := ["scratch_tickets","pull_tabs","slot","video_poker"]
const IDS := ["scratch_tickets","pull_tabs","slot","bar_dice","blackjack","baccarat","craps","roulette","crew_draw_poker","video_poker","coin_pusher"]
var checks := 0
var failures: Array[String] = []
var rows: Array = []
func _init(): call_deferred("_run")
func _check(ok: bool, text: String):
	checks += 1
	if not ok: failures.append(text)
	return ok
func _frames(n: int):
	for i in range(n): await process_frame
func _account(run) -> Dictionary:
	if run == null: return {"missing_run":true}
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state,"inventory":run.inventory.duplicate(true)}
func _run():
	Engine.max_fps=60
	var cold := OS.get_cmdline_user_args().has("--cold")
	var path := OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("resume11-expectations.bin")
	var expected: Dictionary = {}
	if cold:
		if not FileAccess.file_exists(path):
			print("AUD061_RC_RESUME11 producer expectation missing; cold not run")
			quit(2)
			return
		expected=bytes_to_var(FileAccess.get_file_as_bytes(path))
	for id in IDS:
		var app = Main.new()
		app.autosave_slot_id = "aud061_rc_" + id
		root.add_child(app)
		await _frames(8)
		app._settle_script_prewarm_before_runtime()
		app._ensure_full_content_library_loaded()
		if cold:
			if not expected.has(id):
				_check(false,id+" warm fixture unavailable; cold not attempted")
				app.queue_free()
				await _frames(4)
				continue
			var loaded: bool = app.load_foundation_run()
			_check(loaded,id+" separate-process public Continue")
			if loaded:
				_check(_account(app.run_state)==expected[id].account,id+" cold wallet/RNG/inventory")
				_check(app.run_state.current_environment.get("game_states",{})==expected[id].states,id+" cold owned game state")
				_check(app.enter_game(id),id+" real host reentry")
				await _frames(3)
				rows.append({"game":id,"cold":true,"account":_account(app.run_state),"surface_phase":str(app.game_surface_canvas.state.get("phase",app.game_surface_canvas.state.get("ritual_phase",""))),"canvas_bound":app.game_surface_canvas.surface_game_module==app.current_game})
		else:
			var start: Dictionary = _start_case(app,id)
			_check(bool(start.get("ok",false)),id+" supported fresh Practice fixture")
			if bool(start.get("ok",false)):
				await _frames(3)
				_check(app.save_service.save_run(app.run_state,app.autosave_slot_id)==OK,id+" current-build fixture bootstrap through SaveService")
				var entered: bool = app.load_foundation_run() and app.enter_game(id)
				_check(entered,id+" public Continue leaves Practice before play")
				if not entered or app.run_state==null:
					rows.append({"game":id,"entry_failed":true,"message":app.save_status_message})
					app.queue_free()
					await _frames(4)
					continue
				await _frames(4)
				var opening := _account(app.run_state)
				var actions: Array = []
				match id:
					"scratch_tickets": actions=["scratch_buy"]
					"pull_tabs": actions=["pull_tab_buy"]
					"slot": actions=["slot_spin"]
					"bar_dice": actions=["bar_dice_roll","bar_dice_ack_cover"]
					"blackjack": actions=["blackjack_deal"]
					"baccarat": actions=["baccarat_chip","baccarat_bet","baccarat_deal"]
					"craps": actions=["craps_chip","craps_bet","craps_roll"]
					"roulette": actions=["roulette_bet","roulette_spin","roulette_spin"]
					"crew_draw_poker": actions=["poker_deal"]
					"video_poker": actions=["video_poker_deal","video_poker_deal"]
					"coin_pusher": actions=["coin_pusher_drop"]
				for action in actions:
					app._on_game_surface_action(action,3 if action=="baccarat_chip" else (1 if action=="craps_chip" else 0))
					await create_timer(0.3).timeout
					await _frames(3)
				if app.run_state==null or app.current_game==null:
					_check(false,id+" host lost active run during post-entry/action frames")
					rows.append({"game":id,"active_run_lost":true,"message":app.save_status_message,"result":app.last_game_result.get("message","")})
					app.queue_free()
					await _frames(4)
					continue
				var played := _account(app.run_state)
				var result: Dictionary = app.last_game_result.duplicate(true)
				var waits := 0
				while not app.current_game.foundation_save_ready(app.run_state,app.run_state.current_environment) and waits<600:
					await _frames(1)
					waits+=1
				played=_account(app.run_state)
				app.save_foundation_run()
				await _frames(3)
				var saved = app.save_service.load_run(app.autosave_slot_id)
				_check(saved!=null,id+" public Save leaves a loadable current slot")
				if saved!=null:
					_check(_account(saved)==played,id+" public Save captures post-action account")
					var state: Dictionary = saved.current_environment.get("game_states",{}).duplicate(true)
					_check(not state.is_empty(),id+" owns nonempty saved game state")
					expected[id]={"account":_account(saved),"states":state}
					rows.append({"game":id,"cold":false,"actions":actions,"opening":opening,"played":played,"saved":_account(saved),"result_ok":result.get("ok",null),"result_message":result.get("message",""),"save_message":app.save_status_message,"phase":str(app.game_surface_canvas.state.get("phase",app.game_surface_canvas.state.get("ritual_phase",""))),"state_keys":state.keys()})
		app.queue_free()
		await _frames(4)
		if not cold and expected.has(id):
			var final_saved = SaveService.new().load_run("aud061_rc_"+id)
			_check(final_saved!=null,id+" post-exit final slot readable")
			if final_saved!=null:
				rows[-1]["post_exit_account"]=_account(final_saved)
				rows[-1]["post_exit_state_changed"]=expected[id].states!=final_saved.current_environment.get("game_states",{})
				expected[id]={"account":_account(final_saved),"states":final_saved.current_environment.get("game_states",{}).duplicate(true)}
	if not cold:
		var f := FileAccess.open(path,FileAccess.WRITE)
		f.store_buffer(var_to_bytes(expected))
		f.close()
	print("AUD061_RC_RESUME11 "+JSON.stringify({"checks":checks,"failures":failures,"cold":cold,"rows":rows,"scope":"Fresh current-build Practice bootstrap followed by real Continue and host surface callbacks; public Save, separate-process Continue; not ordinary-pointer Web or all pending/settlement boundaries."}))
	quit(0 if failures.is_empty() else 1)

func _start_case(app, game_id: String) -> Dictionary:
	if not CABINET_GAMES.has(game_id):
		return app.start_game_test_session(game_id)
	# Cabinet runtime objects require a complete generated room, including its
	# persisted slot bindings. The game-only practice room is intentionally not a
	# campaign fixture. Select supported game content groups before generation,
	# then use the genuine generator and normal Save/Continue/entry boundaries.
	var groups: Array = app.library.default_content_group_ids()
	for definition in app.library.games:
		if str(definition.get("id", "")) == game_id: continue
		for group in definition.get("content_groups", []): groups.erase(group)
	var candidate: RunState
	for index in range(6):
		var seed := "CREW-CABINET-CAMPAIGN-%s-%d" % [game_id, index]
		var run := RunState.new()
		run.start_new(seed, RunState.custom_challenge("crew_cabinet_return", seed, {"content_groups": groups, "home_archetype_id": "gas_station_casino"}))
		run.bankroll = 1000
		run.narrative_flags["crew_delivery_obligations"] = 2
		for member_id in Crew.MEMBER_IDS: run.crew_add_trust(str(member_id), 50, "synthetic-campaign-fixture")
		# Select a Crew-present seeded fixture before any room is generated. No
		# failed room or authenticated input is edited to manufacture eligibility.
		if not Crew.presence_for_environment(run, {"kind": "casino", "archetype_id": "gas_station_casino", "world_node_id": "gas_station_casino"}).is_empty():
			candidate = run
			break
	if candidate == null: return {"ok": false, "errors": ["No Crew-present initial seed in the bounded fixture selection."]}
	var generator := RunGenerator.new(app.library)
	var fixture_errors: Array = []
	var generated := Fidelity.generate_and_finalize(generator, candidate, fixture_errors, "Crew cabinet return " + game_id, "gas_station_casino", true)
	if not bool(generated.get("ok", false)) or not fixture_errors.is_empty(): return {"ok": false, "errors": fixture_errors}
	if not _check(candidate.current_environment.get("game_ids", []).has(game_id), game_id + " production-generated Gas Casino includes the selected game"): return {"ok": false, "errors": ["Selected cabinet was not generated."]}
	var manifest_errors := EnvironmentInstance.object_manifest_errors(candidate.current_environment)
	var authority := Binder.validate_base_layout_authority(candidate.current_environment)
	if not _check(manifest_errors.is_empty() and bool(authority.get("ok", false)), game_id + " incoming generated cabinet room has valid manifest and persisted slot authority"):
		return {"ok": false, "errors": manifest_errors + authority.get("errors", [])}
	if app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	if app.save_service.save_run(candidate, app.autosave_slot_id) != OK: return {"ok": false, "errors": ["Could not save the fresh generated cabinet fixture."]}
	if not app.load_foundation_run(): return {"ok": false, "errors": ["Normal Continue rejected generated cabinet fixture."]}
	if not app.enter_game(game_id): return {"ok": false, "errors": ["Normal entry rejected generated cabinet."]}
	return {"ok": true, "fixture": "generated_gas_casino_campaign"}

