extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

# Diagnostic wrappers delegate unchanged work. The real Foundation script stays
# canonical so its normal in-place/rollback policy is not changed by a subclass.
const SealedHost := preload("res://scripts/ui/sealed_action_host.gd")
class TimedRun extends RunState:
	var turn_samples: Array = []
	var phase_time := 0
	func _advance_environment_turns_candidate(amount: int) -> Dictionary:
		phase_time = Time.get_ticks_usec()
		return super(amount)
	func _environment_turn_test_failure(stage: String) -> Dictionary:
		var now := Time.get_ticks_usec()
		turn_samples.append({"phase":stage, "usec":now-phase_time})
		phase_time = now
		return super(stage)


	func publish_room_presentation() -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super()
		turn_samples.append({"subphase":"publish_room_presentation", "usec":Time.get_ticks_usec()-t}); return r

	func reconcile_current_environment_object_manifest(refresh: bool = false) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(refresh)
		turn_samples.append({"subphase":"reconcile_current_environment_object_manifest", "usec":Time.get_ticks_usec()-t}); return r
	func scenario_flush_facts(boundary: int = -1) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(boundary)
		turn_samples.append({"subphase":"scenario_flush_facts", "usec":Time.get_ticks_usec()-t}); return r
	func _publish_scenario_membership_candidate(candidate: Dictionary, result: Dictionary, label: String) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(candidate, result, label)
		turn_samples.append({"subphase":"_publish_scenario_membership_candidate", "usec":Time.get_ticks_usec()-t}); return r

class TimedAuthorityHost extends SealedHost:
	var samples: Array = []
	func _init(foundation: Object) -> void: super(foundation)
	func _sealed_action_host_transaction_candidate(action_id: String = "") -> RunState:
		var t := Time.get_ticks_usec(); var r := super(action_id)
		samples.append({"stage": "transaction_candidate", "usec": Time.get_ticks_usec()-t}); return r
	func _sealed_action_host_detached() -> RunState:
		var t := Time.get_ticks_usec(); var r := super()
		samples.append({"stage": "detached_run", "usec": Time.get_ticks_usec()-t})
		if OS.get_environment("BTH_PROFILE_TURN") == "1" and r != null:
			var measured := TimedRun.new()
			measured._apply_environment_turn_snapshot(r._environment_turn_publish_snapshot(), false)
			return measured
		return r
	func _sealed_action_host_ledger(candidate: RunState, create: bool = true, reconcile_checkpoint: bool = true) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(candidate, create, reconcile_checkpoint)
		samples.append({"stage": "ledger", "usec": Time.get_ticks_usec()-t}); return r
	func _sealed_action_host_trusted_context(candidate: RunState, stake: int, action_id: String = "") -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(candidate, stake, action_id)
		samples.append({"stage": "trusted_context", "usec": Time.get_ticks_usec()-t}); return r
	func _sealed_action_host_publish(candidate: RunState, action_id: String = "") -> bool:
		var t := Time.get_ticks_usec(); var r := super(candidate, action_id)
		samples.append({"stage": "publish", "usec": Time.get_ticks_usec()-t}); return r
	func _sealed_action_host_surface_intent_impl(action: String, index: int, confirm_requested: bool = false, surface_time_msec: int = -1) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(action, index, confirm_requested, surface_time_msec)
		samples.append({"stage": "whole_surface_intent", "usec": Time.get_ticks_usec()-t})
		if OS.get_environment("BTH_PROFILE_MAIN") == "1" and str(r.get("action_id", "")) == "peek_hole_card":
			r["ui_state"] = r.get("ui_state", {}).duplicate(false)
			r.ui_state["coin_pusher_debug_profile_stages"] = true
		return r
	func _sealed_action_host_prepare_resolution_context(action: String, stake: int, delivery_claim: Dictionary = {}, prepared_claim: Dictionary = {}) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(action, stake, delivery_claim, prepared_claim)
		samples.append({"stage": "prepare_resolution_context", "usec": Time.get_ticks_usec()-t}); return r
	func _sealed_action_host_commit_resolution(context: Dictionary, proposal: Dictionary) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(context, proposal)
		samples.append({"stage": "commit_resolution", "usec": Time.get_ticks_usec()-t})
		if context.get("candidate") is TimedRun:
			samples.append({"stage":"turn_phases", "samples":context.candidate.turn_samples})
		return r

	func _sealed_action_host_resolve_intent(action: String, stake: int, delivery_claim: Dictionary = {}, prepared_claim: Dictionary = {}) -> Dictionary:
		var t := Time.get_ticks_usec(); var r := super(action, stake, delivery_claim, prepared_claim)
		samples.append({"stage": "whole_resolve_intent", "usec": Time.get_ticks_usec()-t}); return r

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private diagnostic root required"): _finish(); return
	_install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size = Vector2i(1280,720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true; root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "genuine paid-unpeeked Continue"): app.queue_free(); _finish(); return
	_check(app.run_state.bankroll==78 and app.run_state.grand_casino_chips==10, "paid40 already debited, no new wager")
	if not _check(app.enter_game("blackjack"), "ordinary entry reuses original paid hand"): app.queue_free(); _finish(); return
	for frame in range(3): await process_frame
	var table: Dictionary = app.run_state.current_environment.game_states.blackjack
	var ledger: Dictionary = table.get("_blackjack_action_authority", {})
	_check(not bool(ledger.get("session", {}).get("dealer_hole_visible", false)) and not bool(ledger.get("session", {}).get("cheats_used", {}).get("peek_hole_card", false)), "genuine unfinished unpeeked hand")
	var before: Dictionary = _protected(app.run_state)
	var timed := TimedAuthorityHost.new(app)
	app._sealed_action_host = timed
	facts = {"mode": OS.get_environment("BTH_STUTTER_STAGE"), "test_sha256": FileAccess.get_sha256("res://scripts/tests/blackjack_lookaway_stage_probe.gd"), "actions": []}
	for action in ["blackjack_distraction", "blackjack_peek"]:
		timed.samples.clear()
		var started := Time.get_ticks_usec()
		app._on_game_surface_action(action, 1 if action == "blackjack_distraction" else 0, action == "blackjack_peek")
		var elapsed := Time.get_ticks_usec()-started
		facts.actions.append({"action": action, "host_callback_usec": elapsed, "sealed_stages": timed.samples.duplicate(true)})
		if action == "blackjack_distraction":
			_check(app.run_state.bankroll==78 and app.run_state.grand_casino_chips==10 and app.run_state.rng_state==before.rng_state, "LookAway changes no money/root RNG")
			await create_timer(0.25).timeout
		else:
			for frame in range(8): await process_frame
	_check(app.run_state.bankroll==78 and app.run_state.grand_casino_chips in [0,10], "one Peek adds no wager; caught penalty may confiscate the existing10")
	var peek_count := 0
	for row in app.run_state.story_log:
		if str(row.get("action_id", "")) == "peek_hole_card": peek_count += 1
	_check(peek_count == 1, "diagnostic actually committed one Peek rather than only selecting it")
	facts["peek_count"] = peek_count
	facts["main_stage_timings_usec"] = app.last_game_result.get("coin_pusher_debug_host_timing_usec", {})
	facts["cash"] = app.run_state.bankroll; facts["chips"] = app.run_state.grand_casino_chips
	facts["state_key"] = app.current_game_state_key
	facts["root_rng_after"] = str(app.run_state.rng_state)
	app.save_service.wait_for_async_save(); app.queue_free(); await process_frame; _finish()
