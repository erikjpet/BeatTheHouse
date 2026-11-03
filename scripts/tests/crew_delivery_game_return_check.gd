extends SceneTree

# Synthetic campaign fixtures around the real game launcher, Crew event queue,
# TalkDock confirmation callback, event resolver and Save/Continue APIs. This is
# native host coverage, not a captured player save or visual Web playtest.
const Main := preload("res://scripts/ui/foundation_main.gd")
const World := preload("res://scripts/core/world_map.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Crew := preload("res://scripts/core/crew_recruitment_model.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const CABINET_GAMES := ["scratch_tickets", "pull_tabs", "slot", "video_poker"]

class CrewHost extends Main:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int: return test_msec
	func _current_game_surface_input_time_msec() -> int: return test_msec
	func _game_test_archetype() -> Dictionary:
		for value in library.environment_archetypes:
			if str(value.get("id", "")) == "bar": return value.duplicate(true)
		return {}
	func _game_test_environment(game_id: String, game: GameModule) -> Dictionary:
		var environment := super._game_test_environment(game_id, game)
		environment["world_node_id"] = "bar"
		environment["crew_presence"] = [{"member_id": "crew_rook"}]
		return environment
	func _prepare_game_test_prerequisites(game_id: String, environment: Dictionary) -> void:
		super._prepare_game_test_prerequisites(game_id, environment)
		run_state.world_map = World.new(library).build(run_state, run_state.create_rng("crew-return-fixture-map"))
		run_state.world_map = World.enter_node(run_state.world_map, "bar", {})
		run_state.narrative_flags["crew_delivery_obligations"] = 2
		run_state.crew_add_trust("crew_rook", 50, "synthetic-return-fixture")
	func _game_test_bankroll() -> int: return 1000
	func _game_test_seed(game_id: String) -> String: return "CREW-NATIVE-RETURN-" + game_id

var checks := 0
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL ", message)
	return ok

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_BUILD") == "1" and not OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty(), "explicit isolated distribution storage required"):
		_finish()
		return
	var app := CrewHost.new()
	app.continuous_environment_clock_enabled = false
	print("CREW_RETURN_PROGRESS startup")
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	print("CREW_RETURN_PROGRESS full_content_begin")
	app._ensure_full_content_library_loaded()
	print("CREW_RETURN_PROGRESS full_content_end games=", app.library.games.size())
	_check(app.library.games.size() == 11, "full production game catalog contains all eleven games")
	print("CREW_RETURN_PROGRESS run_ui_begin")
	if not _check(app._ensure_run_ui_built(), "production run UI builds before native cases"):
		app.queue_free()
		await process_frame
		_finish()
		return
	print("CREW_RETURN_PROGRESS run_ui_end")
	var wanted := OS.get_environment("BTH_CREW_RETURN_GAMES").split(",", false)
	for value in app.library.games:
		var game_id := str(value.get("id", ""))
		if not wanted.is_empty() and not wanted.has(game_id): continue
		for choice_id in ["run_package", "refuse"]:
			await _case(app, game_id, choice_id)
		if OS.get_environment("BTH_CREW_RETURN_PAID") == "1" and game_id in ["roulette", "coin_pusher", "blackjack"]:
			await _case(app, game_id, "run_package", true)
	_check(not rows.is_empty(), "at least one requested native game case completed")
	app.queue_free()
	await process_frame
	_finish()

func _case(app: CrewHost, game_id: String, choice_id: String, paid: bool = false) -> void:
	var label := game_id + ":" + choice_id + (":paid" if paid else ":unpaid")
	print("CREW_RETURN_PROGRESS entry_begin ", label)
	var start := _start_case(app, game_id)
	print("CREW_RETURN_PROGRESS entry_end ", label, " ok=", start.get("ok", false))
	if not _check(bool(start.get("ok", false)), label + " normal host game entry: " + str(start.get("errors", []))): return
	for _frame in range(2): await process_frame
	var run := app.run_state
	var game := app.current_game
	var state_key := app.current_game_state_key
	var environment_id := str(run.current_environment.get("id", ""))
	_check(app.current_screen == app.SCREEN_GAME and app.game_surface_canvas.surface_game_module == game, label + " initial native canvas is bound")
	if paid:
		print("CREW_RETURN_PROGRESS paid_action_begin ", label)
		var opening_cash := run.bankroll
		match game_id:
			"blackjack": app._on_game_surface_action("blackjack_deal", 0)
			"coin_pusher": app._on_game_surface_action("coin_pusher_drop", 0)
			"roulette":
				var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
				var red := -1
				for index in range(targets.size()):
					if str(targets[index].get("label", "")).to_upper() == "RED": red = index
				_check(red >= 0, label + " full Roulette exposes RED wager")
				app._on_game_surface_action("roulette_bet", maxi(0, red))
				app._on_game_surface_action("roulette_spin", 0)
				app._on_game_surface_action("roulette_spin", 0)
		for _frame in range(12): await process_frame
		_check(bool(app.last_game_result.get("ok", false)), label + " normal paid action succeeds")
		var committed_wager := int(app.last_game_result.get("roulette_total_wager", 0)) if game_id == "roulette" else int(app.last_game_result.get("blackjack_wager_debited", 0)) if game_id == "blackjack" else opening_cash - run.bankroll
		_check(committed_wager > 0, label + " action has a real committed payment")
		print("CREW_RETURN_PROGRESS paid_action_end ", label, " wager=", committed_wager)
	_check(run.crew_package_solicitation_available(), label + " Crew request has physical presence and an obligation")
	# A known successful hourly attempt controls only solicitation, not game RNG.
	run.narrative_flags["crew_package_offer_rng_state"] = 48
	_check(run.enqueue_triggered_event("crew_favor_delivery", "game_action", {"source": "game_action", "game_id": game_id}, {"presentation": "talk"}), label + " actual Crew event enqueue")
	app._refresh_talk_dock()
	print("CREW_RETURN_PROGRESS offer_presented ", label)
	for _frame in range(2): await process_frame
	_check(str(app.talk_dock.entry.get("event_id", "")) == "crew_favor_delivery", label + " TalkDock presents Crew offer")
	_check(not app.talk_dock._choice_by_id(choice_id).is_empty(), label + " real response exists")
	var before_cash := run.bankroll
	var before_chips := run.grand_casino_chips
	var before_rng := run.rng_state
	var before_states := var_to_bytes(run.current_environment.get("game_states", {}))
	var choice_before: Dictionary = app.talk_dock._choice_by_id(choice_id)
	print("CREW_RETURN_PROGRESS choice_begin ", label)
	app.talk_dock._on_choice_pressed(choice_id)
	# These are separate player presses. Allow the first press's normal layout
	# work to settle before the confirmation press reaches the entry-frame guard.
	await process_frame
	await process_frame
	var confirm_guard: bool = app.talk_dock._entry_open_input_guard_active()
	var armed_before_confirm: String = app.talk_dock.armed_choice_id
	app.talk_dock._on_choice_pressed(choice_id)
	for _frame in range(4): await process_frame
	var result: Dictionary = app.last_hook_result
	var response_screen := app.current_screen
	var response_native_bound: bool = app.game_surface_canvas.surface_game_module == game
	print("CREW_RETURN_PROGRESS choice_end ", label, " ok=", result.get("ok", false), " screen=", response_screen, " native=", response_native_bound)
	if not bool(result.get("ok", false)):
		print("CREW_RETURN_RESPONSE_DIAGNOSTIC ", JSON.stringify({"case": label, "choice_before": choice_before, "armed_before_confirm": armed_before_confirm, "confirm_entry_guard": confirm_guard, "message": app.message_label.text, "overlay": app.current_overlay_state_snapshot(), "coach": app.current_coach_snapshot(), "talk_after": app.talk_dock.current_snapshot(), "hook_result": result}))
	_check(bool(result.get("ok", false)), label + " confirmed native TalkDock response resolves: " + str(result.get("errors", [])))
	_check(app.current_game == game and app.current_game_state_key == state_key, label + " same game and fixture remain active")
	_check(app.current_screen == app.SCREEN_GAME, label + " response returns to GAME")
	_check(app.game_surface_canvas.visible and app.game_surface_canvas.surface_game_module == game, label + " visible canvas retains its native game module")
	_check(str(app.game_surface_canvas.state.get("game_id", "")) == game_id, label + " native snapshot remains the active game")
	_check(str(run.current_environment.get("id", "")) == environment_id, label + " response stays in origin room")
	_check(run.bankroll == before_cash and run.grand_casino_chips == before_chips and run.rng_state == before_rng, label + " response grants no advance reward or game RNG draw")
	_check(var_to_bytes(run.current_environment.get("game_states", {})) == before_states, label + " response preserves existing table states")
	_check(run.delivery_has_active_run() == (choice_id == "run_package"), label + " real package admission matches choice")
	_check(run.crew_delivery_obligation_count() == 2, label + " response does not fulfill a delivery")
	if choice_id == "run_package":
		_check(str(run.delivery_snapshot().get("physical", {}).get("cargo_state", "")) == "carried" and run.inventory.count("crew_package") == 1, label + " existing Crew favor transfers exactly one carried package")
		if game_id in ["roulette", "coin_pusher", "blackjack"]:
			print("CREW_RETURN_PROGRESS save_continue_begin ", label)
			var delivery := run.active_delivery_run.duplicate(true)
			_check(app.save_service.save_run(run, app.autosave_slot_id) == OK, label + " Save persists accepted package and game")
			_check(app.load_foundation_run(), label + " normal Continue succeeds")
			_check(app.run_state.active_delivery_run == delivery, label + " Continue preserves exact accepted delivery")
			_check(app.run_state.bankroll == before_cash and app.run_state.grand_casino_chips == before_chips and app.run_state.rng_state == before_rng, label + " Continue preserves account and RNG")
			_check(app.enter_game(game_id), label + " normal game reentry after Continue")
			_check(app.current_screen == app.SCREEN_GAME and app.game_surface_canvas.surface_game_module == app.current_game, label + " Continue reentry binds full native game")
			print("CREW_RETURN_PROGRESS save_continue_end ", label)
	rows.append({"game": game_id, "choice": choice_id, "paid": paid, "result_ok": result.get("ok", false), "response_screen": response_screen, "response_native_bound": response_native_bound, "final_screen": app.current_screen, "state_key": state_key})

func _start_case(app: CrewHost, game_id: String) -> Dictionary:
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

func _finish() -> void:
	var report := {"fidelity": "Synthetic seeded fixtures: complete production-generated Gas Casino campaign rooms for cabinet games, practice games with generated map for table/physical games; explicit Crew eligibility precedes generation. Real native game entry, TalkDock confirmation callback and event resolution; selected real Save/Continue. Optional paid cases use actual Deal, RED bet/Spin and Coin Drop through the native host. No player/browser profile capture, physical pointer injection or deployed Web gameplay.", "checks": checks, "failures": failures, "cases": rows}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("CREW_DELIVERY_GAME_RETURN ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
