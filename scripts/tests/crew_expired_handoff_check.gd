extends SceneTree

# Synthetic timing fixture: the authored Crew event, real generated town,
# appointment schedule, travel install, sequence commands and SaveService remain
# production APIs. Only the offer's target selector is pinned to the Jazz Club.
# HandoffHost observes the real UI dispatch without rendering a window; this is
# neither a captured-player reproduction nor a visual browser playtest.
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Schedule := preload("res://scripts/core/crew_delivery_schedule.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const SequenceSchema := preload("res://scripts/core/scenario_sequence_schema.gd")
const DeliveryModel := preload("res://scripts/core/delivery_run_model.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const LAYOUT := {"viewport_size": {"x": 1280, "y": 720}}
const LEGACY_SLOT := "crew_expired_handoff_legacy_capture"
var library: ContentLibrary
var action_only_visual_ids: Dictionary = {}
var failures: Array = []
var checks := 0

class JazzDeliveryRun:
	extends RunState
	func delivery_crew_offer(definition_id: String, offered_clock: int = -1) -> Dictionary:
		var result := super.delivery_crew_offer(definition_id, offered_clock)
		if definition_id != "crew_favor_delivery" or not bool(result.get("ok", false)):
			return result
		var spec: Dictionary = result.get("spec", {}).duplicate(true)
		spec["targets"] = [{"node_id": "jazz_club", "label": "Jazz Club"}]
		var clock := game_clock_minutes if offered_clock < 0 else mini(offered_clock, game_clock_minutes)
		var windows := Schedule.windows_for(self, spec["targets"], clock)
		if windows.is_empty(): return {"ok": false, "message": "Jazz fixture has no appointment."}
		spec["consumer_payload"] = {"meeting_windows": windows}
		spec["deadline_game_clock_minutes"] = int(windows.back().get("closes", 0))
		spec["deadline_minutes"] = int(spec["deadline_game_clock_minutes"]) - game_clock_minutes
		return {"ok": true, "spec": spec, "message": Schedule.timing_text(spec, true)}

class HandoffHost:
	extends "res://scripts/ui/foundation_main.gd"
	var fixture_records: Array = []
	var refresh_count := 0
	var saved_count := 0
	var last_message := ""
	func _interactable_object_view_list() -> Array: return fixture_records.duplicate(true)
	func _refresh() -> void: refresh_count += 1
	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		saved_count += 1
		return true
	func _show_message(text: String) -> void: last_message = text
	func clear_interaction_focus(_animate_camera_return: bool = false, _refresh_presentation: bool = true) -> void:
		selected_object_id = ""
		focus_target_id = ""
		hover_target_id = ""

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("CHECK FAILED: ", message)

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("crew_expired_handoff_check requires an isolated BTH_DISTRIBUTION_DATA_ROOT")
		quit(64)
		return
	library = ContentLibrary.new()
	library.load(false)
	var layout_root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/scenario_slot_layouts.json"))
	for layout_value in layout_root.get("layouts", []):
		var layout: Dictionary = layout_value
		action_only_visual_ids["%s::%s" % [str(layout.get("map_id", "")), str(layout.get("scenario_id", ""))]] = layout.get("audit", {}).get("action_only_ids", [])
	var selected := OS.get_environment("BTH_CREW_HANDOFF_CASE")
	match selected:
		"before": _check_success()
		"opens": _check_success(true)
		"exact", "capture": _check_unmounted_expiry(0, selected == "capture")
		"after": _check_unmounted_expiry(1)
		"mounted": await _check_mounted_expiry()
		"legacy": _check_legacy_continue()
		"guards": _check_pending_checkpoint_guard()
		_:
			_check_unmounted_expiry(0)
			_check_unmounted_expiry(1)
			_check_success(true)
			_check_success()
			_check_pending_checkpoint_guard()
			await _check_mounted_expiry()
	print("CREW_EXPIRED_HANDOFF checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var run := JazzDeliveryRun.new()
	run.start_new("WORLD-SEQUENCE-PROOF-SCHEDULE")
	var generator := RunGenerator.new(library)
	Fidelity.generate_and_finalize(generator, run, failures, "expired handoff initial")
	Fidelity.travel_and_finalize(generator, run, "bar", true, library, failures, "expired handoff offer room")
	# As in crew_delivery_obligations_check: authored room with explicit synthetic
	# resident/obligation inputs, reconciled before the normal triggered event.
	run.current_environment["crew_presence"] = [{"member_id": "crew_rook"}]
	run.narrative_flags["crew_delivery_obligations"] = 2
	run.crew_add_trust("crew_rook", 50, "fixture")
	run.reconcile_current_environment_object_manifest(true)
	run.narrative_flags["crew_package_offer_rng_state"] = 48
	_check(run.enqueue_triggered_event("crew_favor_delivery", "game_action", {}, {"presentation": "talk"}), "Crew request did not enqueue")
	var module := EventModule.new()
	module.setup(library.event("crew_favor_delivery"), library)
	module.choice_views(run, run.current_environment)
	var accepted := module.resolve(run, run.current_environment, "run_package")
	run.complete_talk_event_resolution("crew_favor_delivery")
	var token := str(accepted.get("world_sequence_owner_token", ""))
	var targets: Array = run.delivery_snapshot().get("targets", [])
	_check(bool(accepted.get("ok", false)) and run.delivery_has_active_run() and not token.is_empty(), "Authored Crew package was not accepted: %s" % JSON.stringify(accepted))
	_check(targets.size() == 1 and str(targets[0].get("node_id", "")) == "jazz_club", "Synthetic quote did not produce Jazz Club target")
	if not bool(accepted.get("ok", false)) or token.is_empty() or targets.is_empty(): return {}
	var window := Schedule.window_for(run.active_delivery_run, "jazz_club")
	_check(not window.is_empty() and int(window.get("closes", 0)) > run.game_clock_minutes, "Jazz appointment did not retain its authored time window")
	return {"run": run, "token": token, "window": window}

func _finalize_room(run: RunState) -> Dictionary:
	var expected_scenario := _scenario_visual_ids(run)
	var result: Dictionary
	if SequenceSchema.is_sequence(run.scenario_sequence_definition()):
		result = run.scenario_finalize_installed_environment(library, LAYOUT)
	else:
		result = run.world_sequence_finalize_base_semantics([], library, LAYOUT)
	if bool(result.get("ok", false)):
		_check_scenario_visuals(run, expected_scenario, "room finalization")
	return result

func _scenario_visual_ids(run: RunState) -> Array:
	if not run.scenario_sequence_present(): return []
	# The raw engine projection deliberately bypasses RunState's readiness guard:
	# an accidentally invalidated derived publication must not hide what the
	# authenticated authored sequence still owns. Use a detached environment so
	# this evidence read cannot repair or suppress the live room.
	var raw: Dictionary = ScenarioEngineScript.sequence_projection(run.current_environment.duplicate(true), run.scenario_sequence_definition())
	_check(not raw.is_empty(), "Active scenario lost its raw engine projection")
	var semantic: Dictionary = raw.get("semantic_state", {})
	var action_hosts: Dictionary = Placement.surface_map(run.current_environment).get("scenario_instance_action_host_ids", {})
	var action_only: Array = action_only_visual_ids.get("%s::%s" % [str(run.current_environment.get("archetype_id", "")), str(run.scenario_sequence_definition().get("id", ""))], [])
	var ids: Array = []
	for family_name in ["scene_objects", "actors"]:
		var family: Dictionary = semantic.get(family_name, {})
		for identity in family:
			var object_data: Dictionary = family[identity]
			# Authored tasks attached to another prop are interaction-only. Their
			# real host (for example the recording desk) owns the rendered visual.
			if action_only.has(str(identity).trim_prefix("scenario::")) or action_hosts.has(str(identity)) or bool(object_data.get("action_only", false)) or str(object_data.get("presentation_mode", "")) == "action_only": continue
			if bool(object_data.get("present", true)) and str(object_data.get("owner_namespace", "")) != "base":
				if not ids.has(str(identity)): ids.append(str(identity))
	ids.sort()
	return ids

func _renderer_visual_ids(run: RunState) -> Array:
	var renderer: Dictionary = run.current_environment.get("scenario_render_snapshot", {})
	var ids: Array = []
	for object_value in renderer.get("visual_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY: continue
		var identity := str(object_value.get("semantic_identity", object_value.get("scenario_layout_authority_identity", "")))
		if not identity.is_empty() and not ids.has(identity): ids.append(identity)
	ids.sort()
	return ids

func _check_scenario_visuals(run: RunState, expected: Array, context: String) -> void:
	var actual := _renderer_visual_ids(run)
	for identity in expected:
		_check(actual.has(identity), "%s lost authored scenario visual %s" % [context, identity])
	print("CREW_HANDOFF_SCENARIO_VISUALS ", JSON.stringify({"context": context, "scenario_present": run.scenario_sequence_present(), "expected": expected, "rendered": actual}))

func _check_scenario_empty_flush(run: RunState, context: String) -> void:
	if not run.scenario_sequence_present():
		print("CREW_HANDOFF_SCENARIO_FLUSH inactive: ", context)
		return
	var expected := _scenario_visual_ids(run)
	_check_scenario_visuals(run, expected, context + " before flush")
	var accounting := _settlement(run)
	# A missed package can legitimately queue a heat fact. Process that ordinary
	# boundary once, then prove a repeated empty flush preserves the resulting
	# authored objects and rendered publication rather than blanking the room.
	var flushed := run.scenario_flush_facts()
	_check(bool(flushed.get("ok", false)), "%s ordinary scenario fact flush failed: %s" % [context, JSON.stringify(flushed.get("errors", []))])
	var after_facts := _scenario_visual_ids(run)
	_check_scenario_visuals(run, after_facts, context + " after ordinary flush")
	var rendered := _renderer_visual_ids(run)
	var repeated := run.scenario_flush_facts()
	_check(bool(repeated.get("ok", false)), "%s repeated scenario fact flush failed" % context)
	_check(_scenario_visual_ids(run) == after_facts and _renderer_visual_ids(run) == rendered, "%s empty scenario fact flush changed authored/rendered object identities" % context)
	_check(_settlement(run) == accounting, "%s scenario fact flush changed delivery accounting" % context)

func _arrive(run: RunState) -> void:
	# Foundation validates the route/hours and advances its clock before this
	# prevalidated atomic destination install. Delivery arrival follows the install.
	var travel := RunGenerator.new(library).travel_environment_result(run, "jazz_club", true)
	_check(bool(travel.get("ok", false)) and run.current_world_node_id() == "jazz_club", "Jazz travel install failed: %s" % JSON.stringify(travel.get("errors", [])))
	var arrival := run.delivery_resolve_travel_arrival({}, {})
	_check(arrival.is_empty() or bool(arrival.get("ok", false)), "Delivery arrival failed: %s" % JSON.stringify(arrival))
	var finalized := _finalize_room(run)
	_check(bool(finalized.get("ok", false)), "Jazz semantic finalization failed: %s" % JSON.stringify(finalized.get("errors", [])))

func _handoff_record(run: RunState, token: String) -> Dictionary:
	var semantic: Dictionary = run.world_sequence_composed_projection().get("semantic_state", {})
	var interactions: Dictionary = semantic.get("interactions", {})
	var interaction: Dictionary = interactions.get("crew::package_handoff", {})
	var actions: Array = interaction.get("available_actions", [])
	if actions.is_empty(): return {}
	return {"object_id": "crew::package_handoff", "owner_namespace": "crew", "stable_object_id": "package_handoff", "world_sequence_owner_token": token, "scenario_sequence_actions": actions.duplicate(true), "interactive": bool(interaction.get("enabled", true)), "enabled": bool(interaction.get("enabled", true))}

func _settlement(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "heat": run.suspicion_level(), "rng": run.rng_state, "crew_jobs": run.crew_jobs.duplicate(true), "owed": run.crew_delivery_obligation_count(), "trust": run.crew_trust("crew_rook"), "reputation": run.crew_reputation(), "delivery": run.active_delivery_run.duplicate(true), "inventory": run.inventory.duplicate(true), "missed": _missed_count(run)}

func _missed_count(run: RunState) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("type", "")) == "delivery_missed_window": count += 1
	return count

func _no_handoff(run: RunState, token: String, context: String) -> void:
	var registration: Dictionary = run.world_sequence_registrations.get(token, {})
	var record := _handoff_record(run, token)
	print("CREW_HANDOFF_PROJECTION ", JSON.stringify({"context": context, "status": run.active_delivery_run.get("status"), "world_applied": run.active_delivery_run.get("world_applied"), "checkpoint": not DeliveryModel.closed_checkpoint(run.active_delivery_run).is_empty(), "lifecycle": registration.get("lifecycle"), "raw_handoff": record, "missed": _missed_count(run)}))
	_check(run.delivery_arrival_interaction().is_empty() and record.is_empty(), "%s retained an actionable raw Crew Handoff after expiry" % context)
	_check(str(registration.get("lifecycle", "")) == "cleaned", "%s retained expired delivery registration" % context)
	_check(run.world_sequence_pending_outcomes(token).is_empty(), "%s invented an unpaid outcome transaction" % context)
	var manifest: Dictionary = run.current_environment.get("object_manifest", {})
	var renderer: Dictionary = run.current_environment.get("scenario_render_snapshot", {})
	var authority: Dictionary = run.current_environment.get("scenario_layout_authority", {})
	_check(not _contains_handoff(manifest.get("rows", [])), "%s retained Handoff in object manifest" % context)
	_check(not _contains_handoff(renderer.get("visual_objects", [])), "%s retained Handoff in renderer snapshot" % context)
	_check(not authority.has("crew::package_handoff") and not _contains_handoff(authority.values()), "%s retained Handoff layout authority" % context)
	_check(not bool(run.current_environment.get("scenario_restore_pending_trusted_rebuild", false)), "%s left trusted scenario rebuild pending" % context)
	if SequenceSchema.is_sequence(run.scenario_sequence_definition()):
		_check(run._scenario_semantic_ready(), "%s lost trusted scenario semantic readiness" % context)
		_check_scenario_visuals(run, _scenario_visual_ids(run), context)
	_check(bool(run.validate_room_action_authority().get("ok", false)), "%s lost room action authority" % context)
	if OS.get_environment("BTH_CREW_HANDOFF_HOST_CATALOG") == "1": _check_host_catalog(run, context)

func _contains_handoff(records: Array) -> bool:
	for value in records:
		if typeof(value) != TYPE_DICTIONARY: continue
		for field in ["object_id", "presentation_object_id", "semantic_identity", "identity", "scenario_layout_authority_identity"]:
			if str(value.get(field, "")) in ["crew::package_handoff", "scenario:crew:package_handoff"]: return true
		if str(value.get("owner_namespace", "")) == "crew" and str(value.get("stable_object_id", "")) == "package_handoff": return true
	return false

func _check_host_catalog(run: RunState, context: String) -> void:
	# Optional normal Main catalog projection, with real lazily loaded UI helper
	# scripts and no native window. This examines the committed publication after
	# cleanup instead of treating an empty raw sequence projection as sufficient.
	var host := Main.new()
	host.run_state = run
	host.library = library
	host.current_screen = Main.SCREEN_ENVIRONMENT
	host.run_action_service = RunActionService.new()
	host.run_action_service.setup(library, run)
	var scripts_ready: bool = host._ensure_run_ui_stage_scripts(0) and host._ensure_run_ui_stage_scripts(10)
	_check(scripts_ready, "%s could not load normal host catalog helpers" % context)
	if scripts_ready:
		var catalog: Array = host.EnvironmentInteractionControllerScript.prepare_room_catalog_at_boundary(host)
		host.set("_room_catalog_publication", catalog)
		var objects: Array = host._interactable_object_view_list()
		_check(not objects.is_empty(), "%s normal host catalog was empty" % context)
		_check(not _contains_handoff(objects), "%s normal host catalog retained actionable Handoff" % context)
		print("CREW_HANDOFF_HOST_CATALOG context=", context, " objects=", objects.size())
	host.free()

func _assert_missed(run: RunState, before: Dictionary, context: String) -> void:
	_check(not run.delivery_has_active_run() and str(run.active_delivery_run.get("resolution", {}).get("reason", "")) == "deadline" and bool(run.active_delivery_run.get("world_applied", false)), "%s did not commit missed delivery" % context)
	_check(run.bankroll == int(before.cash) and run.crew_delivery_obligation_count() == int(before.owed), "%s paid or satisfied an obligation for a miss" % context)
	_check(run.crew_trust("crew_rook") == int(before.trust) - 5 and run.crew_reputation() == int(before.reputation) - 5, "%s changed shipped missed-job trust/reputation penalty" % context)
	_check(_missed_count(run) == int(before.missed) + 1 and not run.inventory.has("crew_package"), "%s missed receipt/cargo removal was not exactly once" % context)
	_check(int(run.narrative_flags.get("crew_package_next_offer_clock", 0)) == run.game_clock_minutes + 360, "%s changed six-hour miss cooldown" % context)

func _restore(run: RunState, slot: String) -> RunState:
	var save := SaveService.new()
	_check(save.save_run(run, slot) == OK, "Save failed: %s" % slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	_check(loaded is RunState, "Cold Continue failed: %s" % slot)
	if not loaded is RunState: return run
	_check(bool(_finalize_room(loaded).get("ok", false)), "Cold Continue finalization failed: %s" % slot)
	return loaded

func _check_unmounted_expiry(offset: int, capture: bool = false) -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var run: RunState = fixture.run
	var token := str(fixture.token)
	var before := _settlement(run)
	var closes := int(fixture.window.get("closes", 0))
	var result := run.advance_game_clock_minutes(closes + offset - run.game_clock_minutes)
	_check(bool(result.get("ok", false)) and bool(result.get("delivery_resolved", false)), "Travel clock at closing %+d did not expire delivery: %s" % [offset, JSON.stringify(result)])
	_assert_missed(run, before, "unmounted closing %+d" % offset)
	_arrive(run)
	if capture:
		_check(SaveService.new().save_run(run, LEGACY_SLOT) == OK, "Historical stale handoff Save failed")
		print("CREW_HANDOFF_LEGACY_CAPTURE slot=", LEGACY_SLOT)
	_no_handoff(run, token, "Jazz arrival closing %+d" % offset)
	_check_scenario_empty_flush(run, "Jazz arrival closing %+d" % offset)
	var settled := _settlement(run)
	_check(bool(_finalize_room(run).get("ok", false)), "Expired room refresh failed")
	_no_handoff(run, token, "Jazz repeated refresh")
	_check(_settlement(run) == settled, "Room refresh changed a settled missed delivery")
	var restored := _restore(run, "crew_expired_handoff_arrival_%d" % offset)
	_no_handoff(restored, token, "Jazz cold Continue")
	_check(_settlement(restored) == settled, "Save/cold Continue changed missed-delivery accounting")

func _check_success(at_open: bool = false) -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var run: RunState = fixture.run
	var token := str(fixture.token)
	_arrive(run)
	var closes := int(fixture.window.get("closes", 0))
	var target_minute := int(fixture.window.get("opens", 0)) if at_open else closes - 1
	var context := "exact opening" if at_open else "last legal minute"
	_check(bool(run.advance_game_clock_minutes(target_minute - run.game_clock_minutes).get("ok", false)), "Clock could not reach %s handoff" % context)
	var record := _handoff_record(run, token)
	_check(not record.is_empty() and bool(run.delivery_arrival_interaction().get("available", false)), "%s lost its legitimate handoff" % context)
	if record.is_empty(): return
	var host := HandoffHost.new()
	host.run_state = run
	host.library = library
	host.fixture_records = [record]
	var before := _settlement(run)
	var accepted := host._complete_delivery_handoff("jazz_club")
	_check(accepted and not run.delivery_has_active_run(), "%s UI handoff failed: %s" % [context, host.last_message])
	_check(run.bankroll == int(before.cash) + 22 and run.suspicion_level() == int(before.heat) + 4 and run.rng_state == before.rng, "Legitimate handoff changed payout/heat/RNG")
	_check(run.crew_delivery_obligation_count() == int(before.owed) - 1 and run.crew_trust("crew_rook") == mini(100, int(before.trust) + 5) and run.crew_reputation() == mini(100, int(before.reputation) + 25), "Legitimate handoff changed obligation/trust/reputation rewards")
	_check(host.saved_count == 1 and host.refresh_count == 1 and run.world_sequence_pending_outcomes(token).is_empty(), "UI handoff did not finish its save/refresh/cleanup boundary")
	var settled := _settlement(run)
	host.free()
	var restored := _restore(run, "crew_expired_handoff_success_open" if at_open else "crew_expired_handoff_success")
	_check(_settlement(restored) == settled, "Completed handoff Save/Continue repaid or changed settlement")
	_check(bool(restored.world_sequence_resume_delivery_checkpoint().get("ok", false)) and _settlement(restored) == settled, "Completed handoff checkpoint recovery changed accounting")

func _check_mounted_expiry() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var run: RunState = fixture.run
	var token := str(fixture.token)
	_arrive(run)
	var closes := int(fixture.window.get("closes", 0))
	_check(bool(run.advance_game_clock_minutes(closes - 1 - run.game_clock_minutes).get("ok", false)), "Mounted fixture could not reach closing-1")
	var record := _handoff_record(run, token)
	_check(not record.is_empty(), "Mounted fixture lacks original cached UI action")
	var before := _settlement(run)
	var expired := run.advance_game_clock_minutes(1)
	_check(bool(expired.get("ok", false)) and bool(expired.get("delivery_resolved", false)), "Mounted clock did not expire at exact closing")
	_assert_missed(run, before, "mounted exact closing")
	# The normal clock host calls _refresh after the committed resolution. Its
	# room finalization must complete before judging the player-visible catalog;
	# the minimal HandoffHost below deliberately suppresses rendering/refresh.
	_check(bool(_finalize_room(run).get("ok", false)), "Mounted expiry host-refresh room finalization failed")
	_no_handoff(run, token, "mounted exact closing after host-refresh finalization")
	_check_scenario_empty_flush(run, "mounted exact closing after host-refresh finalization")
	var host := HandoffHost.new()
	host.run_state = run
	host.library = library
	host.fixture_records = [record]
	var settled := var_to_bytes(run.to_dict())
	var started := Time.get_ticks_usec()
	var stale := false
	if not record.is_empty():
		stale = host._activate_world_sequence_action(token, record, record.scenario_sequence_actions[0])
	var elapsed := Time.get_ticks_usec() - started
	_check(not stale and var_to_bytes(run.to_dict()) == settled, "Cached UI Handoff mutated expired state")
	_check(host.saved_count == 0 and host._event_response_transaction.is_empty() and host._rourke_resolution.is_empty() and not host.travel_transition_active, "Cached stale Handoff retained UI transaction/input ownership")
	await process_frame
	await process_frame
	_check(var_to_bytes(run.to_dict()) == settled, "Frames after stale Handoff changed expired state")
	print("CREW_HANDOFF_STALE_UI elapsed_usec=", elapsed, " refreshes=", host.refresh_count, " message=", host.last_message)
	host.free()
	var accounting := _settlement(run)
	var restored := _restore(run, "crew_expired_handoff_mounted")
	_no_handoff(restored, token, "mounted expiry cold Continue")
	_check(_settlement(restored) == accounting, "Mounted expiry Save/Continue repeated penalty")

func _check_legacy_continue() -> void:
	# Run `capture` on the unfixed source first, using this same disposable data
	# root. The slot is an authentic old runtime Save, never a forged checkpoint.
	var loaded: Variant = SaveService.new().load_run(LEGACY_SLOT)
	_check(loaded is RunState, "Historical stale-slot capture missing; run BTH_CREW_HANDOFF_CASE=capture on baseline")
	if not loaded is RunState: return
	var run: RunState = loaded
	var token := ""
	for value in run.world_sequence_registrations.keys():
		var registration: Dictionary = run.world_sequence_registrations[value]
		if str(registration.get("node_id", "")) == "jazz_club" and str(registration.get("public_instance_token", "")) == str(run.active_delivery_run.get("job_id", "")):
			token = str(value)
	_check(not token.is_empty(), "Historical stale slot lost its exact delivery owner")
	var before := _settlement(run)
	_check(bool(_finalize_room(run).get("ok", false)), "Historical stale Continue could not finalize Jazz Club")
	_no_handoff(run, token, "historical stale Save Continue")
	_check(_settlement(run) == before, "Historical stale presentation recovery changed already-applied accounting")
	var restored := _restore(run, "crew_expired_handoff_legacy_recovered")
	_no_handoff(restored, token, "recovered historical cold Continue")
	_check(_settlement(restored) == before, "Recovered historical cold Continue repeated settlement")

func _check_pending_checkpoint_guard() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var run: RunState = fixture.run
	var token := str(fixture.token)
	_arrive(run)
	_check(bool(run.advance_game_clock_minutes(int(fixture.window.get("opens", 0)) - run.game_clock_minutes).get("ok", false)), "Guard fixture could not reach appointment opening")
	var record := _handoff_record(run, token)
	_check(not record.is_empty(), "Guard fixture lacks a sealed handoff action")
	if record.is_empty(): return
	var action: Dictionary = record.scenario_sequence_actions[0]
	var options: Dictionary = {"owner_namespace": "crew", "stable_object_id": "package_handoff", "host_interaction_availability": {"crew::package_handoff": true}}
	for field in ["action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]: options[field] = str(action.get(field, ""))
	var command := run.world_sequence_command(FunctionOptions.world_sequence_command(token, "make_handoff", "expired-handoff:pending-guard", options))
	_check(bool(command.get("ok", false)), "Guard fixture sealed handoff command failed")
	var committed := run.world_sequence_commit_delivery_outcome(token, "jazz_club")
	var pending: Array = run.world_sequence_pending_outcomes(token)
	_check(bool(committed.get("ok", false)) and not DeliveryModel.closed_checkpoint(run.active_delivery_run).is_empty() and pending.size() == 1, "Guard fixture did not create a genuine closed checkpoint and pending outcome")
	if pending.size() != 1: return
	# Explicit hostile synthetic clone: delete only the authentic checkpoint.
	# The original production-generated owner receipt remains available below.
	var hostile := RunState.new()
	hostile.from_dict(run.to_dict())
	hostile.active_delivery_run.erase("closed_checkpoint")
	var pending_before := var_to_bytes(hostile.world_sequence_pending_outcomes(token))
	var accounting := _settlement(hostile)
	var lifecycle := str(hostile.world_sequence_registrations.get(token, {}).get("lifecycle", ""))
	var cleanup := hostile._cleanup_resolved_delivery_presentations()
	_check(bool(cleanup.get("ok", false)) and lifecycle != "cleaned" and str(hostile.world_sequence_registrations.get(token, {}).get("lifecycle", "")) == lifecycle and var_to_bytes(hostile.world_sequence_pending_outcomes(token)) == pending_before, "Cleanup retired or changed an unfinished pending checkpoint transaction")
	var rejected := hostile._apply_delivery_resolution()
	_check(not bool(rejected.get("ok", false)) and JSON.stringify(rejected.get("errors", [])).contains("missing its closed checkpoint"), "Missing checkpoint was not rejected at the mounted delivery authority boundary")
	_check(_settlement(hostile) == accounting and var_to_bytes(hostile.world_sequence_pending_outcomes(token)) == pending_before, "Missing-checkpoint rejection replayed cash/trust/jobs/inventory/RNG or lost its receipt")
	var authentic_accounting := _settlement(run)
	var consumed := run.world_sequence_consume_delivery_outcome(token, str(pending[0].get("receipt_id", "")), "jazz_club")
	_check(bool(consumed.get("ok", false)) and run.world_sequence_pending_outcomes(token).is_empty() and _settlement(run) == authentic_accounting, "Authentic checkpoint did not finish once without repeating settlement")
	var settled := var_to_bytes(run.to_dict())
	var resumed := run.world_sequence_resume_delivery_checkpoint()
	_check(bool(resumed.get("ok", false)) and bool(resumed.get("inactive", false)) and var_to_bytes(run.to_dict()) == settled, "Completed authentic checkpoint replay changed settled state")
	print("CREW_HANDOFF_CHECKPOINT_GUARD pending_preserved=true hostile_rejected=true authentic_consumed=true")
