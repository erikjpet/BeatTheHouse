extends SceneTree

# Synthetic native host probe: real dealt cards, duel settlement, and the UI's
# event-enqueue boundary. Times exclude rendering and browser persistence.
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Duel := preload("res://scripts/core/grand_casino_duel_model.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")


func _init() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_BUILD") != "1" or OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("Duel probe requires an explicitly isolated distribution data root.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var run := RunStateScript.new()
	run.start_new("CREW-DUEL-TIMING")
	run.narrative_flags["grand_casino_showdown_active"] = true
	run.narrative_flags["grand_casino_showdown_step"] = "duel"
	run.narrative_flags["crew_favor_pending"] = true
	var terms: Dictionary = library.event("the_house_calls").get("payload", {}).get("duel_terms", {}).duplicate(true)
	terms["starting_stacks"] = {"player": 1000, "rourke": 1000}
	terms["rules"]["hand_limit"] = 12
	run.narrative_flags["grand_casino_duel_terms"] = terms
	run.narrative_flags["grand_casino_duel_state"] = Duel.initialize(terms, run.create_rng("duel_probe"))
	var definition := library.game("blackjack")
	var game: GameModule = load(str(definition.get("module_path", ""))).new()
	game.setup(definition, library)
	run.current_environment = {"id": "duel_probe", "archetype_id": "grand_casino_back_room", "world_node_id": "grand_casino", "kind": "boss", "tier": 3, "turns": 2, "local_narrative_flags": {"blackjack_boss_variant": "rourke_duel"}, "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "game_states": {}}
	run.current_environment["game_states"] = {"blackjack": game.generate_environment_state(run, run.current_environment, run.create_rng("probe_table"))}
	var app := Main.new()
	root.add_child(app)
	app.set_process(false)
	app.continuous_environment_clock_enabled = false
	app.call("_ensure_run_ui_built")
	app.library = library
	app.run_state = run
	app.current_screen = app.SCREEN_ENVIRONMENT
	var samples: Array = []
	var offers := 0
	var displayed_calls := 0
	var failures: Array = []
	if app.talk_dock == null: failures.append("TalkDock construction unavailable")
	for hand in range(6):
		var deal := game.surface_action_command("blackjack_deal", 0, false, {"surface_time_msec": (hand + 1) * 10000}, run, run.current_environment)
		var started := Time.get_ticks_usec()
		var result: Dictionary = game.call("_resolve_rourke_duel_hand", "play_basic", run, run.current_environment, deal.get("ui_state", {}))
		var settled := Time.get_ticks_usec()
		if not bool(result.get("ok", false)): failures.append("hand %d did not settle" % hand)
		app.last_game_result = result
		# Give the normal random candidate a certain roll in this diagnostic only;
		# eligibility and cadence remain the shipped boundaries in both builds.
		var forced: Dictionary = library.event("crew_favor_delivery")
		forced["trigger"]["chance_percent"] = 100
		for entry in library.action_trigger_event_candidates_readonly():
			if str(entry.get("id", "")) == "crew_favor_delivery": entry["trigger"]["chance_percent"] = 100
		var context := {"trigger": "action", "type": "action", "source": "game_action", "turns": int(run.current_environment.get("turns", 2))}
		app.call("_enqueue_triggered_events_for_context", "game_action", context, run.current_environment)
		var queued := Time.get_ticks_usec()
		var presenting := Time.get_ticks_usec()
		app.call("_refresh_talk_dock")
		var presentation_usec := Time.get_ticks_usec() - presenting
		if app.talk_dock != null and app.talk_dock.visible: displayed_calls += 1
		var projected_usec := 0
		if run.triggered_event_pending("crew_favor_delivery"):
			offers += 1
			var module := EventModule.new()
			module.setup(library.event("crew_favor_delivery"), library)
			var projecting := Time.get_ticks_usec()
			module.choice_views(run, run.current_environment)
			projected_usec = Time.get_ticks_usec() - projecting
			run.complete_talk_event_resolution("crew_favor_delivery")
		samples.append({"hand": hand + 1, "settlement_usec": settled - started, "enqueue_usec": queued - settled, "talk_dock_build_usec": presentation_usec, "offer_projection_usec": projected_usec})
		run.advance_environment_turns(1)
	if run.has_method("crew_package_solicitation_available") and (offers != 0 or displayed_calls != 0): failures.append("Crew call interrupted the duel")
	print("CREW_DUEL_TIMING " + JSON.stringify({"fidelity": "synthetic native settlement, UI enqueue and actual TalkDock construction; headless, excludes browser rendering/persistence", "samples": samples, "package_calls": offers, "displayed_calls": displayed_calls, "failures": failures}))
	app.free()
	quit(0 if failures.is_empty() else 1)
