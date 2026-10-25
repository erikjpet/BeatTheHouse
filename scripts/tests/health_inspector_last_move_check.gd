extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _inspector_fixture(app) -> bool:
	# Generated production room/routes with a synthetic queued inspector. Actual
	# player-save and visible Web reproductions are separate release evidence.
	if not app.start_foundation_run("RUN-20261025-440400-001", {}, false):
		return false
	for choice in app._travel_choice_view_list():
		if str(choice.get("id", "")) == "bar" and bool(choice.get("enabled", false)):
			if not bool(app._travel_to("bar", "Roadside Bar", choice, true).get("ok", false)):
				return false
			break
	if app.run_state.current_world_node_id() != "bar": return false
	app.run_state.current_environment["turns"] = 1
	var context: Dictionary = app._event_action_trigger_context("event")
	context["environment_snapshot"] = app.run_state.current_environment.duplicate(true)
	if not app.run_state.enqueue_triggered_event("health_inspector", "event", context): return false
	var entry: Dictionary = app.run_state.begin_triggered_event_resolution(app.run_state.next_pending_triggered_event())
	return app._show_triggered_event_popup(entry)

func _run() -> void:
	var app = MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for _i in range(3): await process_frame
	app.set_process(false)
	_check(_inspector_fixture(app), "Could not establish generated Bar inspector fixture.")
	if failures.is_empty():
		var cash: int = app.run_state.bankroll
		var rng: int = app.run_state.rng_state
		var event_rng := JSON.stringify(app.run_state.event_cadence.get("rng_state", 0))
		var result: Dictionary = app.resolve_event_choice("health_inspector", "finish_one")
		_check(bool(result.get("ok", false)), "One last move was rejected.")
		_check(app.run_state.current_world_node_id() == "bar", "The inspector response spent its own last move.")
		_check(app.run_state.bankroll == cash and app.run_state.rng_state == rng, "Arming the allowance charged travel or consumed gameplay RNG.")
		_check(int(app.run_state.narrative_flags.get("health_inspector_closing_actions", 0)) == 1, "One last move was not left armed.")
		_check(not bool(app.run_state.narrative_flags.get("health_inspector_forced_travel", false)), "Forced travel was published before the next action.")
		_check(app.run_state.active_triggered_event.is_empty(), "Resolved inspector still owns the modal.")
		_check(JSON.stringify(app.run_state.event_cadence.get("rng_state", 0)) == event_rng, "Resolving the inspector rerolled event cadence.")
		# Existing armed saves and every ordinary action caller use the default
		# boundary: exactly one subsequent action consumes the persisted allowance.
		_check(bool(app._apply_post_action_environment_interrupt("game_action")), "The next ordinary action did not force departure.")
		_check(app.run_state.current_world_node_id() != "bar" and bool(app.run_state.narrative_flags.get("health_inspector_forced_travel", false)), "Armed default boundary did not complete real travel.")
		_check(int(app.run_state.narrative_flags.get("health_inspector_closing_actions", -1)) == 0, "Forced departure did not consume exactly one allowance.")
		var settled_cash: int = app.run_state.bankroll
		var settled_rng: int = app.run_state.rng_state
		_check(settled_cash == cash + int(app.last_hook_result.get("bankroll_delta", 0)), "Forced travel did not apply its complete travel receipt exactly once.")
		_check(not bool(app._apply_forced_environment_travel("game_action").get("applied", true)), "Consumed allowance forced a second trip.")
		_check(app.run_state.bankroll == settled_cash and app.run_state.rng_state == settled_rng, "Repeated boundary charged or rerolled after settlement.")
	_check(_inspector_fixture(app), "Could not establish bribe fixture.")
	if app._event_choice_popup_is_visible():
		var cash: int = app.run_state.bankroll
		var rng: int = app.run_state.rng_state
		var rejected: Dictionary = app.resolve_event_choice("health_inspector", "missing_choice")
		_check(not bool(rejected.get("ok", false)), "Invalid inspector response was accepted.")
		_check(app.run_state.bankroll == cash and app.run_state.rng_state == rng and int(app.run_state.narrative_flags.get("health_inspector_closing_actions", 0)) == 0, "Rejected response changed money, RNG or allowance.")
		var bribe: Dictionary = app.resolve_event_choice("health_inspector", "slip_twenty")
		_check(bool(bribe.get("ok", false)) and app.run_state.bankroll == cash - 20, "Bribe did not charge its authored $20 exactly once.")
		_check(app.run_state.current_world_node_id() == "bar" and int(app.run_state.narrative_flags.get("health_inspector_closing_actions", 0)) == 0, "Bribe unexpectedly armed or applied forced travel.")
		_check(app.run_state.rng_state == rng, "Bribe changed gameplay RNG.")
	if app.save_service != null and app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	for failure in failures: push_error(failure)
	print("Health Inspector last-move checks: ", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
