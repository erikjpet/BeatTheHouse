class_name Fixsweep061Regressions
extends RefCounted


static func check_wave1(_library: ContentLibrary, failures: Array) -> void:
	_check_bth_039_oversized_save_is_atomic(failures)
	_check_bth_043_money_transactions_are_atomic(_library, failures)
	_check_bth_045_compact_failure_has_full_fallback(failures)


static func check_wave2(_library: ContentLibrary, failures: Array) -> void:
	_check_bth_021_developer_placement_audit_is_truthful(failures)
	_check_bth_wave2_all_archetype_interaction_authority(_library, failures)


static func _check_bth_021_developer_placement_audit_is_truthful(failures: Array) -> void:
	var authority := {
		"base::travel:leave": {
			"normalized_hit_rect": {"x": 0.80, "y": 0.20, "w": 0.12, "h": 0.18},
			"small_screen_rect": {"x": 720.0, "y": 80.0, "w": 108.0, "h": 78.0},
		},
		"scenario::safe_exit": {
			"normalized_hit_rect": {"x": 0.84, "y": 0.24, "w": 0.12, "h": 0.18},
			"small_screen_rect": {"x": 750.0, "y": 100.0, "w": 108.0, "h": 78.0},
		},
	}
	var developer_room := {"id": "bth021_bar", "archetype_id": "bar"}
	if not ScenarioLayoutResolver._developer_placement_room(developer_room):
		failures.append("BTH-021 fixture is not exercising a checked-in developer-placement room.")
		return
	if ScenarioLayoutResolver._overlap_count(authority, "normalized_hit_rect", developer_room) != 1 \
			or ScenarioLayoutResolver._overlap_count(authority, "small_screen_rect", developer_room) != 1:
		failures.append("BTH-021 checked-in developer placement suppressed normal or small-screen overlap audit truth.")


static func _check_bth_wave2_all_archetype_interaction_authority(library: ContentLibrary, failures: Array) -> void:
	var checked := 0
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		if archetype_id.is_empty():
			continue
		var run := RunState.new()
		run.start_new("FIXSWEEP-W2-%s" % archetype_id)
		var rng := run.create_rng("fixsweep_wave2_layout")
		var environment := EnvironmentInstance.from_archetype(archetype, 1, rng, library, run.challenge_config)
		var data := environment.to_dict()
		var generator := RunGenerator.new(library)
		data["game_states"] = generator._generated_game_states(run, data, rng)
		var layout := EnvironmentInstance.ensure_generated_layout(data, library)
		var errors: Array = layout.get("placement_errors", []) if typeof(layout.get("placement_errors", [])) == TYPE_ARRAY else []
		if not errors.is_empty():
			failures.append("BTH-001..020 placement authority reported errors for %s: %s" % [archetype_id, errors])
		var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
		var ids := object_rects.keys()
		ids.sort()
		for left_index in range(ids.size()):
			var left_id := str(ids[left_index])
			var left := _bth_wave2_rect(object_rects.get(left_id, {}))
			if left.size.x * 900.0 < 43.99 or left.size.y * 414.0 < 43.99:
				failures.append("BTH-001..020 placement authority produced a sub-44px target %s in %s." % [left_id, archetype_id])
			for right_index in range(left_index + 1, ids.size()):
				var right_id := str(ids[right_index])
				var right := _bth_wave2_rect(object_rects.get(right_id, {}))
				if left.intersects(right) and left.intersection(right).get_area() > 0.000001:
					failures.append("BTH-001..020 direct interaction overlap in %s: %s vs %s." % [archetype_id, left_id, right_id])
		checked += 1
	if checked != 18:
		failures.append("BTH-001..020 regression expected 18 archetypes, checked %d." % checked)


static func _bth_wave2_rect(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("w", 0.0)),
		float(data.get("h", 0.0))
	)


static func _check_bth_039_oversized_save_is_atomic(failures: Array) -> void:
	var slot_id := "fixsweep06_1_bth039"
	var empty_slot_id := "fixsweep06_1_bth039_empty"
	var service := SaveService.new()
	_cleanup_save_slot(service, slot_id)
	_cleanup_save_slot(service, empty_slot_id)
	var old_generation := RunState.new()
	old_generation.start_new("FIXSWEEP-BTH039-OLD")
	old_generation.bankroll = 700
	if service.save_run(old_generation, slot_id) != OK:
		failures.append("BTH-039 fixture could not write its old generation.")
	var baseline := RunState.new()
	baseline.start_new("FIXSWEEP-BTH039-BASELINE")
	baseline.bankroll = 811
	if service.save_run(baseline, slot_id) != OK:
		failures.append("BTH-039 fixture could not write its baseline generation.")
		_cleanup_save_slot(service, slot_id)
		return
	var primary_path := ProjectSettings.globalize_path(service.run_save_path(slot_id))
	var backup_path := ProjectSettings.globalize_path(service.backup_save_path(slot_id))
	var baseline_bytes := FileAccess.get_file_as_bytes(primary_path)
	var backup_bytes := FileAccess.get_file_as_bytes(backup_path)
	var oversized := RunState.new()
	oversized.start_new("FIXSWEEP-BTH039-OVERSIZED")
	oversized.bankroll = 911
	oversized.story_log.append({"type": "bth039", "message": "x".repeat(RunSaveCodec.MAX_STORAGE_BYTES + 1024)})
	var encoded_bytes := JSON.stringify(RunSaveCodec.encode(oversized.to_save_snapshot())).to_utf8_buffer().size()
	if encoded_bytes <= RunSaveCodec.MAX_STORAGE_BYTES:
		failures.append("BTH-039 fixture did not exceed the production storage limit (%d bytes)." % encoded_bytes)
	var save_error := service.save_run(oversized, slot_id)
	if save_error == OK:
		failures.append("BTH-039 oversized synchronous save reported success.")
	if FileAccess.get_file_as_bytes(primary_path) != baseline_bytes:
		failures.append("BTH-039 oversized synchronous save changed the valid primary generation.")
	if FileAccess.get_file_as_bytes(backup_path) != backup_bytes:
		failures.append("BTH-039 oversized synchronous save changed the valid backup generation.")
	var fresh := SaveService.new()
	var loaded: RunState = fresh.load_run(slot_id)
	if loaded == null or loaded.bankroll != 811:
		failures.append("BTH-039 oversized synchronous save did not preserve the loadable baseline generation.")
	var empty_service := SaveService.new()
	if empty_service.save_run(oversized, empty_slot_id) == OK:
		failures.append("BTH-039 oversized empty-slot save reported success.")
	if FileAccess.file_exists(ProjectSettings.globalize_path(empty_service.run_save_path(empty_slot_id))) \
			or FileAccess.file_exists(ProjectSettings.globalize_path(empty_service.backup_save_path(empty_slot_id))):
		failures.append("BTH-039 oversized empty-slot save created a generation.")
	if empty_service.trusted_primary_fingerprints.has(empty_slot_id):
		failures.append("BTH-039 failed empty-slot save added a trusted fingerprint.")
	if service.begin_save_run(oversized, slot_id) != OK or service.wait_for_async_save() == OK:
		failures.append("BTH-039 oversized asynchronous replacement did not fail at completion.")
	if FileAccess.get_file_as_bytes(primary_path) != baseline_bytes or FileAccess.get_file_as_bytes(backup_path) != backup_bytes:
		failures.append("BTH-039 oversized asynchronous replacement changed a valid generation.")
	RunSaveCodec.debug_force_compression_failure = true
	var compression_error := service.save_run(baseline, slot_id)
	RunSaveCodec.debug_force_compression_failure = false
	if compression_error == OK:
		failures.append("BTH-039 injected compression failure reported success.")
	if FileAccess.get_file_as_bytes(primary_path) != baseline_bytes or FileAccess.get_file_as_bytes(backup_path) != backup_bytes:
		failures.append("BTH-039 compression failure changed a valid generation.")
	var status := SaveService.new().slot_status(slot_id)
	if not bool(status.get("primary_loadable", false)):
		failures.append("BTH-039 a save reported OK but was not loadable through a fresh service.")
	_cleanup_save_slot(service, slot_id)
	_cleanup_save_slot(service, empty_slot_id)


static func _cleanup_save_slot(service: SaveService, slot_id: String) -> void:
	for path in [service.run_save_path(slot_id), service.backup_save_path(slot_id)]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


static func _check_bth_043_money_transactions_are_atomic(library: ContentLibrary, failures: Array) -> void:
	for clock in [0, 1, 2]:
		for bankroll in [17, 18, 19]:
			var run := _bth043_run("item", bankroll, clock)
			var before := JSON.stringify(run.to_save_snapshot())
			var service := RunActionService.new()
			service.setup(library, run)
			var response := service.buy_item_offer("ledger_pencil")
			_bth043_assert_atomic(response, run, before, "item clock=%d bankroll=%d" % [clock, bankroll], "ledger_pencil", "", failures)
	for clock in [0, 1, 2]:
		for bankroll in [20, 21, 22]:
			var run := _bth043_run("service", bankroll, clock)
			var before := JSON.stringify(run.to_save_snapshot())
			var service := RunActionService.new()
			service.setup(library, run)
			var response := service.use_hook("service", "punchline_cover_charge")
			_bth043_assert_atomic(response, run, before, "service clock=%d bankroll=%d" % [clock, bankroll], "", "punchline_headliner_cover_paid", failures)
	var jazz := _bth043_run("jazz", 50, 2)
	jazz.add_item("jazz_drummer_glasses")
	jazz.add_suspicion("bth043_jazz_heat", 12, "behavior", false, {"environment_id": str(jazz.current_environment.get("id", ""))})
	jazz._turn_transaction_test_failure_stage = "global_start"
	var jazz_before := JSON.stringify(jazz.to_save_snapshot())
	var jazz_service := RunActionService.new()
	jazz_service.setup(library, jazz)
	var jazz_response := jazz_service.use_hook("service", "show_drummer_glasses")
	if bool(jazz_response.get("ok", false)) or JSON.stringify(jazz.to_save_snapshot()) != jazz_before:
		failures.append("BTH-043 Jazz show_drummer_glasses no longer restores its complete state after a rejected boundary.")


static func _bth043_run(kind: String, bankroll: int, clock: int) -> RunState:
	var run := RunState.new()
	run.start_new("FIXSWEEP-BTH043-%s-%d-%d" % [kind, bankroll, clock])
	run.bankroll = bankroll
	var services: Array = ["show_drummer_glasses"] if kind == "jazz" else ["punchline_cover_charge"] if kind == "service" else []
	run.set_environment({
		"id": "bth043_%s_room" % kind,
		"world_node_id": "bth043_%s_node" % kind,
		"archetype_id": "jazz_club" if kind == "jazz" else "underground_casino" if kind == "service" else "corner_store",
		"kind": "shop",
		"item_offers": [{"id": "ledger_pencil", "display_name": "Ledger Pencil", "price": 12}] if kind == "item" else [],
		"service_ids": services,
		"lender_hooks": [],
		"game_ids": [],
		"event_ids": [],
		"next_archetypes": [],
		"travel_hooks": [],
		"layout": {},
	})
	run.add_debt({
		"id": "bth043_note", "lender_id": "street_lender", "balance": 30,
		"deadline_turns": clock, "turns_remaining": clock, "status": "active",
		"default_consequence": "forced_repayment",
	})
	return run


static func _bth043_assert_atomic(response: Dictionary, run: RunState, before: String, label: String, item_id: String, flag_id: String, failures: Array) -> void:
	if not bool(response.get("ok", false)):
		if JSON.stringify(run.to_save_snapshot()) != before:
			failures.append("BTH-043 rejected %s changed bankroll, debt, offers, rewards, Heat, or story." % label)
		return
	if run.run_status != RunState.RUN_STATUS_ACTIVE or run.bankroll < 0:
		failures.append("BTH-043 accepted %s left the run failed or underfunded." % label)
	if not item_id.is_empty() and (not run.inventory.has(item_id) or not run.current_environment.get("item_offers", []).is_empty()):
		failures.append("BTH-043 accepted %s did not commit its item and offer together." % label)
	if not flag_id.is_empty() and not bool(run.narrative_flags.get(flag_id, false)):
		failures.append("BTH-043 accepted %s did not commit its paid-service flag." % label)
	if run.story_log.is_empty():
		failures.append("BTH-043 accepted %s without one transaction story record." % label)


static func _check_bth_045_compact_failure_has_full_fallback(failures: Array) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var resolve_start := source.find("func _resolve_game_action(")
	var start := source.find("if uses_compact_action_rollback:", resolve_start)
	var finish := source.find("run_state.defer_next_bankroll_zero_failure", start)
	var failure_branch := source.substr(start, finish - start) if start >= 0 and finish > start else ""
	if not failure_branch.contains("restore_host_action_rollback") \
			or not failure_branch.contains("run_state.from_dict(boundary_rollback_run)") \
			or not failure_branch.contains("run_state.current_environment = boundary_rollback_environment") \
			or not failure_branch.contains("host_action_rollback_failure_payload"):
		failures.append("BTH-045 compact rollback rejection no longer applies the complete run/environment fallback with identity diagnostics.")
