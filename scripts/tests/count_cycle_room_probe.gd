extends SceneTree

# Synthetic, key-local diagnosis of the Grand 03:45 -> 04:00 publication boundary.
# No campaign, fixture import, wager, or Save is involved.
const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SLOT := "count_cycle_synthetic_057"
var checks := 0
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var private_root := OS.get_environment("BTH_COUNT_PRIVATE_ROOT").replace("\\", "/").trim_suffix("/")
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not private_root.is_absolute_path() or not private_root.contains("/native-private-count-cycle-") or not user_dir.begins_with(private_root + "/"):
		print("COUNT_CYCLE_PROBE ", JSON.stringify({"error": "private root containment"}))
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var app := MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for i in range(2): await process_frame
	app.set_process(false)
	app._ensure_run_ui_built()
	app._ensure_full_content_library_loaded()
	if OS.get_environment("BTH_COUNT_PROBE_COLD") == "1":
		app.autosave_slot_id = SLOT
		_check(app.load_foundation_run(), "fresh process loads synthetic saved Count room")
		for i in range(3): await process_frame
		var cold_facts := {"clock": app.run_state.game_clock_minutes if app.run_state != null else -1,
			"cash": app.run_state.bankroll if app.run_state != null else -1,
			"chips": app.run_state.grand_casino_chips if app.run_state != null else -1}
		if app.run_state != null:
			app._prepare_room_presentation_at_boundary()
			cold_facts["room"] = _facts(app.run_state, app)
			_check(app.run_state.game_clock_minutes == 6000 and bool(app.run_state.validate_room_action_authority().get("ok", false)), "cold Count cycle remains at Day 5 04:00 with strict authority")
			_check(_enabled_blackjack(app) and not app._room_publication_save_blocked(), "cold Count room retains playable Blackjack and Save")
			_check(str(app.run_state.crew_heist_snapshot().get("status", "")) == "play", "cold Count play remains pending")
		app.queue_free()
		await process_frame
		print("COUNT_CYCLE_PROBE ", JSON.stringify({"checks": checks, "failures": failures, "facts": cold_facts, "mode": "cold"}))
		quit(0 if failures.is_empty() else 1)
		return
	var run := RunState.new()
	run.start_new("COUNT-CYCLE-SYNTHETIC-057")
	run.game_clock_minutes = 3 * 1440 + 240
	var errors: Array = []
	var arrival := Fidelity.generate_and_finalize(app.generator, run, errors, "synthetic Grand room", "grand_casino", true)
	var facts := {"arrival_ok": arrival.get("ok", false), "generation_errors": errors}
	_check(bool(arrival.get("ok", false)) and errors.is_empty(), "authored Grand room arrives with valid authority")
	if errors.is_empty():
		app.run_state = run
		facts["first_arrival"] = _facts(run, app)
		var overnight := run.advance_game_clock_minutes(1425)
		facts["overnight_clock"] = overnight
		# The genuine pre-boundary screenshot does not expose saved retirement state.
		# Keep the old authored scenario mounted for this alternate delayed-cycle case.
		var count := CrewHeistModel.begin("the_count", 14)
		count["status"] = CrewHeistModel.STATUS_PLAY
		count["setup"] = {"identity": true, "schedule": true, "swap_cart": true}
		run.crew_heist_state = count
		run.narrative_flags["heist_live_table_active"] = true
		facts["heist_sync"] = run._crew_heist_boundary_sync()
		facts["heist_status"] = run.crew_heist_snapshot().get("status", "")
		facts["heist_event_before"] = run.current_environment.get("event_ids", []).has("heist_live_table")
		_check(bool(facts.heist_sync) and bool(facts.heist_event_before), "Count live table mounts through its owner")
		var live_table := EventModule.new()
		live_table.setup(app.library.event("heist_live_table"), app.library)
		facts["hold_result"] = live_table.resolve(run, run.current_environment, "go_hold")
		_check(bool(facts.hold_result.get("ok", false)), "Count Hold opening is accepted")
		facts["before"] = _facts(run, app)
		var protected_before := _protected(run)
		var clock := run.advance_game_clock_minutes(15)
		facts["clock"] = clock
		_check(bool(clock.get("ok", false)) and run.game_clock_minutes == 6000, "ordinary clock reaches Day 5 04:00")
		facts["pre_refresh"] = _facts(run, app)
		var refresh: Dictionary = app.generator.refresh_current_venue_scenario_cycle(run)
		facts["refresh"] = {"ok": refresh.get("ok", false), "changed": refresh.get("changed", false),
			"errors": refresh.get("errors", []), "scenario_id": refresh.get("scenario_id", "")}
		facts["post_refresh"] = _facts(run, app)
		_check(bool(refresh.get("ok", false)) and bool(refresh.get("changed", false)), "new scenario accepts unclaimed base controls")
		_check(_protected(run) == protected_before, "rollover preserves cash, chips, Heat, debt, RNG, and Count state")
		app._prepare_room_presentation_at_boundary()
		facts["post_publication"] = _facts(run, app)
		_check(bool(facts.post_publication.authority_ok) and facts.post_publication.manifest_errors.is_empty(), "strict room and manifest authority remain valid")
		_check(int(facts.post_publication.enabled) > 0 and _enabled_blackjack(app), "Blackjack and ordinary room controls publish")
		_check(run.current_environment.get("event_ids", []).has("heist_live_table"), "Crew live table remains mounted")
		var primary := run.scenario_sequence_projection()
		var combined := run.world_sequence_composed_projection()
		var primary_interactions: Dictionary = primary.get("semantic_state", {}).get("interactions", {})
		var combined_interactions: Dictionary = combined.get("semantic_state", {}).get("interactions", {})
		var ordinary_door := "base::travel:grand_casino_back_room"
		_check(bool(combined.get("ok", false)) and combined_interactions.get(ordinary_door, {}) == primary_interactions.get(ordinary_door, {}), "current scenario owns unclaimed ordinary door bytes")
		var owner_identity := "crew::heist_count_play"
		_check(combined_interactions.has(owner_identity), "Count-owned interaction remains present")
		if combined_interactions.has(owner_identity):
			var conflicting_primary := primary.duplicate(true)
			(conflicting_primary["semantic_state"]["interactions"] as Dictionary)[owner_identity] = {"owner_namespace": "crew", "stable_object_id": "heist_count_play", "forged": true}
			var conflict := CrewWorldSequenceAdapter.composed_projection(run.current_environment, run._world_sequence_definition_cache, conflicting_primary)
			_check(not bool(conflict.get("ok", true)) and JSON.stringify(conflict.get("errors", [])).contains(owner_identity), "genuine owner collision still fails closed")
		var repeat: Dictionary = app.generator.refresh_current_venue_scenario_cycle(run)
		_check(bool(repeat.get("ok", false)) and not bool(repeat.get("changed", true)), "repeat cycle check is idempotent")
		_check(_protected(run) == protected_before, "repeat check cannot replay financial or Count effects")
		var save_error: Error = app.save_service.save_run(run, SLOT)
		_check(save_error == OK, "synthetic official Save succeeds")
		if save_error == OK:
			var restored: RunState = SaveService.new().load_run(SLOT)
			if restored != null:
				var cold_protected := _protected(restored)
				var different_keys: Array = []
				for key in protected_before.keys():
					if protected_before[key] != cold_protected.get(key): different_keys.append(key)
				facts["cold_protected_differences"] = different_keys
				if different_keys.has("heist"):
					var heist_differences: Array = []
					for heist_key in (protected_before["heist"] as Dictionary).keys():
						if (protected_before["heist"] as Dictionary)[heist_key] != (cold_protected["heist"] as Dictionary).get(heist_key): heist_differences.append(heist_key)
					facts["cold_heist_difference_keys"] = heist_differences
			var cold_paid_exact := false
			var cold_count_pending := false
			if restored != null:
				var cold_fields := _protected(restored)
				cold_paid_exact = true
				for key in ["cash", "chips", "heat", "debt", "rng"]:
					if cold_fields[key] != protected_before[key]: cold_paid_exact = false
				cold_count_pending = str((cold_fields["heist"] as Dictionary).get("status", "")) == "play" \
					and (cold_fields["heist"] as Dictionary).get("play", {}).get("decisions", {}) == (protected_before["heist"] as Dictionary).get("play", {}).get("decisions", {})
			_check(cold_paid_exact and cold_count_pending, "fresh-service cold load retains exact finance/RNG and pending Count decision")
			if restored != null:
				app.run_state = restored
				app._prepare_room_presentation_at_boundary()
				_check(_enabled_blackjack(app) and bool(restored.validate_room_action_authority().get("ok", false)), "cold room has playable Blackjack under strict authority")
	app.queue_free()
	await process_frame
	print("COUNT_CYCLE_PROBE ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)

func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(),
		"debt": run.debt.duplicate(true), "rng": run.rng_state, "heist": run.crew_heist_snapshot()}

func _enabled_blackjack(app: Node) -> bool:
	for view in app._interactable_object_view_list():
		if str(view.get("object_id", "")) == "game:blackjack" and bool(view.get("enabled", false)) and not bool(view.get("room_geometry_rejected", false)):
			return true
	return false

func _facts(run: RunState, app: Node) -> Dictionary:
	var views: Array = app._interactable_object_view_list()
	var enabled := 0
	for view in views:
		if bool(view.get("enabled", false)) and not bool(view.get("room_geometry_rejected", false)): enabled += 1
	return {"clock": run.game_clock_minutes, "scenario": run.current_environment.get("scenario_id", ""),
		"cycle": run.current_environment.get("environment_situation_cycle_id", ""),
		"game_ids": run.current_environment.get("game_ids", []),
		"manifest_errors": EnvironmentInstance.object_manifest_errors(run.current_environment),
		"authority_ok": run.validate_room_action_authority().get("ok", false), "enabled": enabled,
		"publication_failed": app._scenario_cycle_publication_failed}
