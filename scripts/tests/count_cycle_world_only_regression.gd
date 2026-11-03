extends SceneTree

# Synthetic, key-local diagnosis of the Grand 03:45 -> 04:00 publication boundary.
# No campaign, fixture import, wager, or Save is involved.
const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SLOT := "count_cycle_base_room_060"
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
	var pinned_scenario := OS.get_environment("BTH_COUNT_PIN_SCENARIO")
	if not pinned_scenario.is_empty():
		var modifiers: Dictionary = run.challenge_config.get("modifiers", {}).duplicate(true)
		var pins: Dictionary = modifiers.get("scenario_pins", {}).duplicate(true)
		pins["grand_casino"] = pinned_scenario
		modifiers["scenario_pins"] = pins
		run.challenge_config["modifiers"] = modifiers
	# At Day 5 03:45 the 24h Grand venue is in its authored scenario gap.
	# The genuine cold save has this exact old cycle stamp, no scenario/seal,
	# and a late Crew-owned Live Table with a valid live rectangle.
	run.game_clock_minutes = 4 * 1440 + 225
	var errors: Array = []
	var arrival := Fidelity.generate_and_finalize(app.generator, run, errors, "synthetic Grand room", "grand_casino", true)
	var facts := {"arrival_ok": arrival.get("ok", false), "generation_errors": errors}
	_check(bool(arrival.get("ok", false)) and errors.is_empty(), "authored Grand room arrives with valid authority")
	if errors.is_empty():
		app.run_state = run
		# The normal travel commit has already moved the map cursor to the room.
		# Fidelity's direct generator seam leaves it at the tutorial start node.
		run.world_map["current_node_id"] = str(run.current_environment.get("world_node_id", "grand_casino"))
		facts["first_arrival"] = _facts(run, app)
		var overnight := run.advance_game_clock_minutes(0)
		facts["overnight_clock"] = overnight
		_check(str(run.current_environment.get("scenario_id", "")).is_empty() \
			and not run.current_environment.has("scenario_semantic_digest"), "03:45 base room has no scenario seal")
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
		facts["registration_count"] = run.world_sequence_registrations.size()
		facts["world_preparation"] = run.world_sequence_prepare_semantic_finalization()
		var semantic_inputs := preload("res://scripts/core/environment_base_semantic_records.gd").authoritative_interactable_records(run.current_environment, app.library)
		facts["table_base_records"] = (semantic_inputs.get("records", []) as Array).filter(func(record): return JSON.stringify(record).contains("heist_live_table"))
		facts["table_runtime_entries"] = (run.current_environment.get("runtime_object_manifest_entries", []) as Array).filter(func(row): return str(row.get("object_id", "")) == "event:heist_live_table")
		facts["table_archetype"] = run.current_environment.get("archetype_id", "")
		var raw_records: Array = semantic_inputs.get("records", [])
		var filtered_records: Array = run._world_only_without_crew_live_table_base_record(raw_records)
		facts["table_filter_count"] = filtered_records.size()
		_check(raw_records.size() == filtered_records.size() + 1 and not JSON.stringify(filtered_records).contains("heist_live_table"), "only the Crew-owned Live Table leaves the base interaction inventory")
		var original_environment: Dictionary = run.current_environment
		var unowned_environment: Dictionary = original_environment.duplicate(true)
		for row in unowned_environment.get("runtime_object_manifest_entries", []):
			if str(row.get("object_id", "")) == "event:heist_live_table": row["runtime_owner"] = "untrusted_owner"
		run.current_environment = unowned_environment
		_check(run._world_only_without_crew_live_table_base_record(raw_records) == raw_records, "untrusted Live Table owner cannot omit a base interaction")
		run.current_environment = original_environment
		var wrong_record := {"object_id": "event:heist_live_table", "source_id": "heist_live_table", "object_type": "event", "manifest_family": "fixed", "slot_family": "scenario"}
		_check(run._world_only_without_crew_live_table_base_record([wrong_record]) == [wrong_record], "non-Crew Live Table record cannot be silently omitted")
		_check(bool(facts.world_preparation.get("active", false)), "Count registration activates world-only sealing in the current room")
		facts["world_only_finalize"] = run.scenario_finalize_installed_environment(app.library)
		_check(bool(facts.world_only_finalize.get("ok", false)), "Crew-owned Live Table does not enter immutable world-only base semantics")
		app._prepare_room_presentation_at_boundary()
		facts["before"] = _facts(run, app)
		var live_layout: Dictionary = (run.current_environment.get("layout", {}) as Dictionary).get("object_rects", {}).duplicate(true)
		_check(live_layout.has("event:heist_live_table") \
			and not run.current_environment.has("scenario_sequence_base_layout_object_rects"), "late Count table has live geometry but no scenario baseline")
		# The previous regression saved only after a successful cycle refresh.
		# Probe the actual incident's older-cycle room through official Save/load
		# before its first 04:00 refresh, without touching the original profile.
		var pre_cycle_save: Error = app.save_service.save_run(run, "count_pre_cycle_cold_probe")
		_check(pre_cycle_save == OK, "synthetic pre-cycle Count Save succeeds")
		if pre_cycle_save == OK:
			var cold_source: RunState = SaveService.new().load_run("count_pre_cycle_cold_probe")
			_check(cold_source != null, "fresh service restores pre-cycle Count room")
			if cold_source != null:
				var cold_before := _protected(cold_source)
				var cold_clock := cold_source.advance_game_clock_minutes(15)
				var cold_refresh: Dictionary = app.generator.refresh_current_venue_scenario_cycle(cold_source)
				facts["cold_first_refresh"] = {"clock":cold_clock,"refresh":cold_refresh,
					"pre":cold_before,"post":_facts(cold_source, app)}
				_check(bool(cold_refresh.get("ok", false)), "pre-cycle cold Count room refreshes without rejected Live Table")
				if bool(cold_refresh.get("ok", false)):
					app.run_state = cold_source
					app._prepare_room_presentation_at_boundary()
					_check(_enabled_blackjack(app) and not app._room_publication_save_blocked(), "cold-first Count room publishes Blackjack and Save")
				app.run_state = run
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
	var room: Dictionary = run.current_environment
	var rects: Dictionary = (room.get("layout", {}) as Dictionary).get("object_rects", {})
	var owners: Array = room.get("runtime_object_manifest_entries", [])
	var table_owners := 0
	for owner_value in owners:
		if typeof(owner_value) == TYPE_DICTIONARY and str((owner_value as Dictionary).get("runtime_owner", "")) == "crew_heist_live_table": table_owners += 1
	var enabled := 0
	for view in views:
		if bool(view.get("enabled", false)) and not bool(view.get("room_geometry_rejected", false)): enabled += 1
	return {"clock": run.game_clock_minutes, "scenario": run.current_environment.get("scenario_id", ""),
		"layer": room.get("current_layer_id", ""), "scenario_state_id": (room.get("scenario_state", {}) as Dictionary).get("id", ""),
		"world_instance_count": (room.get("world_sequence_instances", {}) as Dictionary).size(),
		"baseline_rects_present": room.has("scenario_sequence_base_layout_object_rects"),
		"live_table_rect": rects.has("event:heist_live_table"), "baseline_table_rect": (room.get("scenario_sequence_base_layout_object_rects", {}) as Dictionary).has("event:heist_live_table"), "table_owner_count": table_owners,
		"cycle": run.current_environment.get("environment_situation_cycle_id", ""),
		"game_ids": run.current_environment.get("game_ids", []),
		"manifest_errors": EnvironmentInstance.object_manifest_errors(run.current_environment),
		"authority_ok": run.validate_room_action_authority().get("ok", false), "enabled": enabled,
		"publication_failed": app._scenario_cycle_publication_failed}
