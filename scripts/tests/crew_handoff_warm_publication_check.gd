extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const HandoffPublication := preload("res://scripts/core/room_presentation_publication.gd")
const HANDOFF_ID := "crew::package_handoff"

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-handoff-warm001-"), "isolated handoff regression root required"): _finish(); return
	var mode := OS.get_environment("BTH_HANDOFF_WARM001_MODE")
	if mode != "cold": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official copied-state load"): _finish(); return
	var baseline_protected := _protected(baseline)
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app); app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "ordinary Host Continue"): app.queue_free(); _finish(); return
	for frame in range(4): await process_frame
	var run: RunState = app.run_state
	facts = {"mode": mode, "fidelity": "Genuine private copies; one normal deferred Machine Jam Wait callback only in warm case. No handoff, trip, paid game, clock/funds/outcome injection or historical settlement replay.", "before": _handoff_snapshot(app)}
	_check(_different_paths(baseline_protected, _protected(run)).is_empty(), "Continue preserves protected gameplay")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "strict initial room authority")
	var owners := _owner_fingerprints(run)
	if mode == "settled":
		_check(run.bankroll == 93 and run.crew_reputation() == 53 and run.suspicion_level() == 9, "protected settled93cash53Crew9Heat")
		_check(run.crew_delivery_obligation_count() == 1 and not run.inventory.has("crew_package"), "settled one duty and no package preserved")
		_check(str(run.active_delivery_run.get("status", "")) == "resolved", "settled job never revived")
		_assert_handoff(app, false, "cleaned owner stays absent")
	else:
		_assert_handoff(app, true, "initial eligible contact")
		_check(run.crew_delivery_obligation_count() == 2 and run.inventory.has("crew_package"), "two duties and carried package retained")
		_check(str(run.active_delivery_run.get("status", "")) == "active" and int(run.active_delivery_run.get("deadline_game_clock_minutes", 0)) == 4470, "same active deadline4470")
		if mode == "warm":
			_check(run.bankroll == 74 and run._crew_action_index() == 8, "genuine pre-Wait74cash/action8")
			var games: Dictionary = run.current_environment.get("game_states", {}).duplicate(true)
			var rng_before := run.rng_state
			_check(app._activate_event_response_action("event_response:machine_jam:wait"), "normal deferred Wait callback accepted once")
			for frame in range(24):
				await process_frame
				if app._event_response_transaction.is_empty() and not app.event_choice_resolution_pending: break
			_check(app._event_response_transaction.is_empty() and not app.event_choice_resolution_pending, "deferred response completes through normal frames")
			# Read immediately, before a new preparation/restore can hide a lost row.
			facts["immediate_after_Wait"] = _handoff_snapshot(app)
			_assert_handoff(app, true, "warm event publication retains contact")
			_check(run.bankroll == 71 and run._crew_action_index() == 9, "Wait charges3 once and advances one action")
			_check(run.crew_reputation() == 32 and run.suspicion_level() == 5 and run.crew_delivery_obligation_count() == 2, "existing Heat/Crew/duty semantics unchanged")
			_check(run.rng_state == rng_before and _different_paths(games, run.current_environment.get("game_states", {})).is_empty(), "no paid machine or root RNG mutation")
			_check(_wait_count(run) == 1 and run.inventory.has("crew_package") and str(run.active_delivery_run.get("status", "")) == "active", "one event receipt, no package settlement")
			_check(_owner_fingerprints(run) == owners, "world owner state unchanged by generic response")
			var accepted := _protected(run)
			var stale_confirmation := app.confirm_selected_event_choice()
			_check(not bool(stale_confirmation.get("ok", true)), "resolved choice cannot be confirmed twice")
			_check(_different_paths(accepted, _protected(run)).is_empty(), "stale Wait cannot charge/reward/advance again")
		elif mode == "after":
			_check(run.bankroll == 71 and _wait_count(run) == 1, "legacy missing-row save restores without replaying Wait")
		var stable := _protected(run)
		for repeat in range(2):
			var flushed := run.scenario_flush_facts()
			_check(bool(flushed.get("ok", false)), "ordinary repeated fact boundary accepted")
			_assert_handoff(app, true, "fact boundary retains composed contact")
		_check(_different_paths(stable, _protected(run)).is_empty() and _owner_fingerprints(run) == owners, "repeated composition changes no gameplay/owner state")
	var tampered := run.current_environment.duplicate(true)
	tampered["scenario_layout_authority_digest"] = "synthetic-invalid-proof"
	_check(not bool(HandoffPublication.validate(tampered).get("ok", true)), "strict renderer authority tamper remains rejected")
	if mode == "cold":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_HANDOFF_WARM001_EXPECTED")))
		_check(_different_paths(expected.get("facts", {}).get("protected_after", {}), _protected(run)).is_empty(), "independent-process protected state preserved")
		_check(_different_paths(expected.get("facts", {}).get("owner_states_after", {}), _owner_states(run)).is_empty(), "independent-process owner state preserved")
	else:
		app.save_foundation_run(); app.save_service.wait_for_async_save()
		var restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
		_check(restored != null and _different_paths(_protected(run), _protected(restored)).is_empty(), "normal Save/fresh service preserves accepted state")
		facts["owner_restore_fingerprint_pair"] = {"live": _owner_fingerprints(run), "restored": _owner_fingerprints(restored)}
		facts["owner_restore_semantic_diff"] = _different_paths(_owner_states(run), _owner_states(restored))
		_check(facts.owner_restore_semantic_diff.is_empty(), "Save preserves owner ledger without reward replay")
	facts["protected_after"] = _protected(run)
	facts["owner_fingerprints_after"] = _owner_fingerprints(run)
	facts["owner_states_after"] = _owner_states(run)
	facts["after"] = _handoff_snapshot(app)
	app.queue_free(); await process_frame; _finish()

func _assert_handoff(app: Host, present: bool, label: String) -> void:
	var view := _handoff_snapshot(app)
	var expected := 1 if present else 0
	_check(int(view.manifest) == expected and int(view.visuals) == expected and int(view.authority) == expected, label + " exact sealed physical membership")
	_check(int(view.catalog) == expected and int(view.canvas) == expected, label + " actual catalog/Canvas presence")
	if present: _check(int(view.enabled_handoff_actions) > 0, label + " enabled owner-scoped handoff")
	_check(bool(app.run_state.validate_room_action_authority().get("ok", false)), label + " strict publication valid")

func _handoff_snapshot(app: Host) -> Dictionary:
	var run: RunState = app.run_state; var env: Dictionary = run.current_environment
	var catalog := app._interactable_object_view_list()
	var actions := 0
	for value in catalog:
		if str(value.get("object_id", "")) == HANDOFF_ID and bool(value.get("enabled", false)):
			actions += value.get("scenario_sequence_actions", []).size()
	return {"cash": run.bankroll, "Heat": run.suspicion_level(), "Crew": run.crew_reputation(), "clock": run.game_clock_minutes, "action": run._crew_action_index(), "duties": run.crew_delivery_obligation_count(), "manifest": _count_id(env.get("object_manifest", {}).get("rows", [])), "visuals": _count_id(env.get("scenario_render_snapshot", {}).get("visual_objects", [])), "authority": 1 if env.get("scenario_layout_authority", {}).has(HANDOFF_ID) else 0, "catalog": _count_id(catalog), "canvas": _count_id(app.environment_canvas.foundation_scene_objects), "enabled_handoff_actions": actions}

func _count_id(rows: Array) -> int:
	var count := 0
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("object_id", row.get("id", ""))) == HANDOFF_ID: count += 1
	return count

func _owner_states(run: RunState) -> Dictionary:
	# Compare the complete production persistence envelope, not optional empty
	# in-memory defaults that durable_container deliberately omits from saves.
	return WorldAdapter.durable_container(run.current_environment.get("world_sequence_instances", {}))

func _owner_fingerprints(run: RunState) -> Dictionary:
	var result: Dictionary = {}
	for token in run.current_environment.get("world_sequence_instances", {}):
		var entry: Dictionary = run.current_environment.world_sequence_instances[token]
		result[str(token)] = {"lifecycle": entry.get("lifecycle"), "state": Runtime.content_fingerprint(entry.get("state", {}))}
	return result

func _wait_count(run: RunState) -> int:
	var count := 0
	for row in run.story_log:
		if str(row.get("event_id", "")) == "machine_jam" and str(row.get("choice_id", "")) == "wait": count += 1
	return count
