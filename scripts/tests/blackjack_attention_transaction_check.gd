extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private test root"): _finish(); return
	_install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size = Vector2i(1280,720)
	var app := Host.new(); app.continuous_environment_clock_enabled=false; app.script_prewarm_stopping=true; root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "genuine paid40 official Continue"): app.queue_free(); _finish(); return
	if not _check(app.enter_game("blackjack"), "normal paid table entry"): app.queue_free(); _finish(); return
	for frame in range(3): await process_frame
	var run: RunState=app.run_state
	var prior:=run.to_save_snapshot()
	var command: Dictionary=app._sealed_action_host_surface_intent("blackjack_distraction",1,false,100000)
	_check(bool(command.get("handled",false)) and not command.has("_sealed_action_host_delivery"), "attention opens without financial delivery")
	_check(not command.get("surface_state_patch",{}).is_empty(), "attention carries incremental presentation")
	var session: Dictionary=run.current_environment.game_states.blackjack[Authority.LEDGER_KEY].session
	var expected: Dictionary=app.current_game.surface_state(run,run.current_environment,session)
	_check(command.surface_state_patch.get("dealer_focus_runtime")==expected.get("dealer_focus_runtime"), "incremental attention equals complete surface runtime")
	_check(int(session.dealer_lookaway_started_msec)==100000, "input clock is preserved exactly")
	var distraction: Dictionary=run.current_environment.game_states.blackjack.distractions[1]
	_check(int(session.dealer_lookaway_duration_msec)==int(distraction.duration_msec), "ordinary window unchanged")
	_check(run.bankroll==78 and run.grand_casino_chips==10 and run.rng_state==prior.rng_state, "attention does not wager or draw RNG")
	_check(run.inventory==prior.inventory and run.story_log==prior.story_log and run.narrative_flags==prior.narrative_flags, "attention does not alter items/history/profile")
	_check(bool(run.validate_room_action_authority().get("ok",false)), "attention retains strict room proof")
	var normal:=run.detached_host_action_candidate("blackjack")
	var owned:=run.detached_host_action_candidate("blackjack")
	var source:=run.to_save_snapshot()
	var t:=Time.get_ticks_usec();var regular:Dictionary=normal.advance_environment_turns(1,true);var normal_usec:=Time.get_ticks_usec()-t
	t=Time.get_ticks_usec();var coalesced:Dictionary=owned.advance_environment_turns_with_external_rollback(1,true);var owned_usec:=Time.get_ticks_usec()-t
	_check(bool(regular.get("ok",false)) and bool(coalesced.get("ok",false)), "both complete environment turns accepted")
	var differences:=_different_paths(normal.to_save_snapshot(),owned.to_save_snapshot())
	facts={"turn_differences":differences,"normal_turn_usec":normal_usec,"owned_turn_usec":owned_usec}
	_check(differences.is_empty(), "coalesced turn equals original full transaction in every saved field")
	_check(bool(owned.validate_room_action_authority().get("ok",false)), "coalesced final proof strictly valid")
	_check(run.to_save_snapshot()==source, "speculative turns never mutate original graph")
	for stage in ["preflight","environment","encounter_and_rooms","fact_flush","legacy_expiry"]:
		var rejected:=run.detached_host_action_candidate("blackjack")
		rejected._turn_transaction_test_failure_stage=stage
		var outcome:=rejected.advance_environment_turns_with_external_rollback(1)
		_check(not bool(outcome.get("ok",true)), "owned transaction still rejects at "+stage)
		_check(run.to_save_snapshot()==source, "rejection preserves live state at "+stage)
	var tampered:=run.detached_host_action_candidate("blackjack")
	tampered.current_environment.layout.slot_binding_digest="0".repeat(64)
	_check(not bool(tampered.validate_room_action_authority().get("ok",true)), "tampered binding never acquires a reusable proof")
	var delivery:Dictionary=app._sealed_action_host_prepare_delivery("peek_hole_card",40)
	_check(bool(delivery.get("ok",false)), "valid pending delivery fixture issued by normal authority")
	var unchanged:=run.to_save_snapshot()
	var blocked:Dictionary=app._sealed_action_host._sealed_action_host_in_place_session_intent("blackjack_distraction",1,false,100100)
	_check(bool(blocked.get("_sealed_action_host_requires_transaction",false)), "pending delivery falls back to the existing recovery transaction")
	_check(run.to_save_snapshot()==unchanged, "rejected attention cannot clear a paid delivery")
	app.save_service.wait_for_async_save();app.queue_free();await process_frame;_finish()
