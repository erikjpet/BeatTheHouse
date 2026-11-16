extends "res://scripts/tests/foundation/world_sequence_delivery_proof_contract.gd"

# Synthetic publication contract only: a shipped public world-sequence is
# registered/mounted in a generated room. Ordinary Main Save/Continue must retain
# that same sealed owner actor/actions. --cleanup-contract also settles one fresh
# synthetic handoff and probes detached failure recovery; no campaign is loaded.
const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SLOT := "CREW-HANDOFF-CONTINUE-SYNTHETIC"
var checks := 0
var failures: Array = []
var facts: Dictionary = {}
var cleanup_contract := false
var primary_contract := false

class RejectCleanupPublication extends RunStateScript:
	var reject_cleanup_publication := false
	func _resolve_world_sequence_composed_layout(records: Array, context: Dictionary, primary: Variant = null) -> Dictionary:
		if reject_cleanup_publication: return {"ok": false, "errors": ["Synthetic cleanup publication failure."]}
		return super._resolve_world_sequence_composed_layout(records, context, primary)


func _initialize() -> void:
	cleanup_contract = OS.get_cmdline_user_args().has("--cleanup-contract")
	primary_contract = OS.get_cmdline_user_args().has("--primary-contract")
	call_deferred("_run_continue_fixture")
func _expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); print("CHECK FAILED: ", label)
	return ok
func _frames(count: int) -> void:
	for i in range(count): await process_frame
func _protected(run: RunState) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"cash": run.bankroll, "heat": run.suspicion_level(), "clock": run.game_clock_minutes, "rng": str(run.rng_state), "debt": run.debt.duplicate(true), "inventory": run.inventory.duplicate(true), "duties": run.crew_delivery_obligation_count(), "jobs": run.crew_jobs.duplicate(true), "delivery": run.delivery_snapshot(), "registrations": run.world_sequence_registrations.duplicate(true), "owners": CrewWorldSequenceAdapterScript.durable_container(run.current_environment.get("world_sequence_instances", {}))}))
func _changed_paths(before, after, path: String = "") -> Array:
	if before is Dictionary and after is Dictionary:
		var paths: Array = []; var keys: Array = before.keys()
		for key in after.keys():
			if not keys.has(key): keys.append(key)
		keys.sort()
		for key in keys:
			if not before.has(key) or not after.has(key): paths.append(path + "/" + str(key))
			else: paths.append_array(_changed_paths(before[key], after[key], path + "/" + str(key)))
		return paths
	return [] if before == after else [path]
func _view(app) -> Dictionary:
	var run: RunState = app.run_state
	var contacts: Array = []
	for object in app.current_spatial_interaction_snapshot().get("objects", []):
		if str(object.get("object_id", "")) == "crew::package_handoff" or bool(object.get("delivery_contact", false)): contacts.append(object)
	return {"node": run.current_world_node_id(), "scenario": str(run.current_environment.get("scenario_id", "")), "primary_present": run.scenario_sequence_present(), "ready": run.current_environment.get("scenario_semantic_ready"), "pending": run.current_environment.get("scenario_restore_pending_trusted_rebuild"), "definition_cache_tokens": run.get("_world_sequence_definition_cache").keys(), "owner": run.world_sequence_mounted_owner_for_channel("delivery_handoff", "back_alley"), "contacts": contacts, "room_authority": run.validate_room_action_authority()}
func _assert_contact(view: Dictionary, token: String, stage: String) -> void:
	_expect(view.get("owner", "") == token, stage + ": same mounted owner")
	_expect(view.get("room_authority", {}).get("ok", false), stage + ": strict room authority")
	var contacts: Array = view.get("contacts", [])
	if not _expect(contacts.size() == 1, stage + ": exactly one published handoff contact"): return
	var contact: Dictionary = contacts[0]
	_expect(contact.get("object_id", "") == "crew::package_handoff" and contact.get("delivery_contact", false), stage + ": exact enriched handoff identity")
	_expect(contact.get("visible", false) and contact.get("interactive", false) and contact.get("enabled", false), stage + ": visible enabled interactive contact")
	_expect(contact.get("world_sequence_owner_token", "") == token, stage + ": contact keeps exact owner")
	var actions: Array = contact.get("scenario_sequence_actions", [])
	_expect(actions.size() == 1 and actions[0].get("id", "") == "make_handoff" and actions[0].get("world_sequence_owner_token", "") == token, stage + ": actual owner handoff action retained")
func _run_continue_fixture() -> void:
	if not _expect(not OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty(), "isolated synthetic storage required"): return _finish_fixture()
	var library := ContentLibraryScript.new(); library.load(false)
	var excludes: Array = []
	if not primary_contract:
		for definition in library.scenarios_for_archetype("back_alley"): excludes.append(str(definition.get("id", "")))
	var run := RunStateScript.new()
	run.start_new("HANDOFF-CONTINUE-WORLD-ONLY", RunStateScript.custom_challenge("handoff_continue_contract", "HANDOFF-CONTINUE-WORLD-ONLY", {"scenario_excludes": {"back_alley": excludes}}))
	var generator := RunGeneratorScript.new(library)
	Fidelity.generate_and_finalize(generator, run, failures, "synthetic initial room")
	Fidelity.travel_and_finalize(generator, run, "bar", true, library, failures, "synthetic package origin")
	if not _expect(failures.is_empty(), "generated room has production arrival/seal"): return _finish_fixture()
	var spec := {"run_id": "crew_favor_delivery", "job_id": "synthetic_continue_0001", "cargo_id": "crew_package", "cargo_label": "Synthetic package", "targets": [{"node_id": "back_alley", "label": "Back Alley"}], "deadline_actions": 180}
	if cleanup_contract:
		# Explicit detached fixture setup; no original campaign is loaded. The
		# package's consequences come from the shipped ordinary event response.
		run.narrative_flags["crew_delivery_obligations"] = 2
		run.narrative_flags["crew_delivery_rules_version"] = 1
		for choice in library.event("crew_favor_delivery").get("payload", {}).get("choices", []):
			if str(choice.get("id", "")) == "run_package":
				spec["consumer_payload"] = run._delivery_event_consumer_payload({"success": choice.get("consequences", {}), "failure": choice.get("streets_failure", {})})
		facts.authored_consumer = spec.get("consumer_payload", {})
	var begun := run.delivery_begin_package(spec)
	if not _expect(begun.get("ok", false), "production delivery model starts synthetic carried route"): facts.delivery_begin = begun; return _finish_fixture()
	_pickup_delivery(run, "continue_contract")
	var packages: Array = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	var entry: Dictionary = packages[0].get("definitions", [])[0]
	var registered: Dictionary = run._world_sequence_register_trusted_entry(entry, "synthetic_continue_0001", "back_alley")
	if not _expect(registered.get("ok", false), "synthetic public owner registers without a campaign action"): return _finish_fixture()
	var token := str(registered.get("owner_token", ""))
	Fidelity.travel_and_finalize(generator, run, "back_alley", true, library, failures, "synthetic world-only destination")
	var arrival := run.delivery_resolve_travel_arrival({}, {})
	if not _expect(failures.is_empty() and arrival.get("ok", false), "production delivery arrival reaches real world-only target"): facts.arrival = arrival; return _finish_fixture()
	var finalized := run.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
	if not _expect(finalized.get("ok", false), "synthetic public owner mounts through ordinary room finalization"): facts.finalization = finalized; return _finish_fixture()
	if cleanup_contract:
		var window := CrewDeliveryScheduleScript.window_for(run.active_delivery_run, "back_alley")
		var wait_minutes := maxi(0, int(window.get("opens", run.game_clock_minutes)) - run.game_clock_minutes)
		_expect(run.advance_game_clock_minutes(wait_minutes).get("ok", false), "synthetic clock API reaches the authored appointment before Save")
		_expect(run.delivery_arrival_interaction().get("available", false), "synthetic saved handoff starts inside its real appointment")
	_expect(run.scenario_sequence_present() == primary_contract and run.delivery_has_active_run(), "fixture has requested primary context and live matching delivery")
	facts.fixture = {"target": "back_alley", "primary_present": run.scenario_sequence_present(), "scenario": run.current_environment.get("scenario_id", ""), "owner": token, "ready": run.current_environment.get("scenario_semantic_ready"), "pending": run.current_environment.get("scenario_restore_pending_trusted_rebuild")}
	var protected := _protected(run)
	root.size = Vector2i(1280, 720)
	var app = MainScene.instantiate(); app.autosave_slot_id = SLOT
	root.add_child(app); await _frames(8)
	_expect(app.save_service.save_run(run, SLOT) == OK, "normal SaveService writes only synthetic slot")
	_expect(app.save_service.wait_for_async_save() == OK, "synthetic save finishes")
	if not _expect(app.load_foundation_run(), "ordinary Main Continue loads synthetic saved state"):
		app.queue_free(); await _frames(2); return _finish_fixture()
	# Read first: projection/token getters must not warm a cache before this.
	facts.after_continue = _view(app)
	_assert_contact(facts.after_continue, token, "first Continue publication")
	facts.continue_protected_differences = _changed_paths(protected, _protected(app.run_state))
	_expect(_protected(app.run_state) == protected, "Continue preserves accounting RNG clock job delivery and owner journal")
	if facts.after_continue.get("contacts", []).is_empty():
		var compiled: Array = app.EnvironmentInteractionControllerScript.compile_room_catalog_at_boundary(app)
		facts.compiler_diagnostics = []
		for record in compiled:
			var reason := str(record.get("room_geometry_rejection_reason", ""))
			if not reason.is_empty(): facts.compiler_diagnostics.append({"object_id": record.get("object_id"), "reason": reason})
	app._refresh(); facts.after_refresh = _view(app)
	_assert_contact(facts.after_refresh, token, "repeated ordinary refresh")
	_expect(_protected(app.run_state) == protected, "refresh neither settles nor mutates protected state")
	var saved_generation_before := int(app.autosave_completed_generation)
	app.save_foundation_run()
	facts.explicit_save = {"completed_before": saved_generation_before, "completed_after": app.autosave_completed_generation, "dirty_generation": app.autosave_dirty_generation, "status": app.save_status_message}
	_expect(int(app.autosave_completed_generation) > saved_generation_before and app.save_status_message == "Saved run.", "explicit Main Save commits a new completed generation")
	_expect(app.save_service.wait_for_async_save() == OK, "normal Main Save finishes same synthetic slot")
	_expect(app.load_foundation_run(), "second ordinary Continue creates a cold RunState from same synthetic slot")
	facts.after_second_continue = _view(app)
	_assert_contact(facts.after_second_continue, token, "Save and second cold RunState publication")
	_expect(_protected(app.run_state) == protected, "second Save/Continue preserves accounting RNG clock job delivery and owner journal")
	_negative_restore_guards(app.run_state, library, token)
	if cleanup_contract and failures.is_empty(): await _exercise_cleanup(app, library, token)
	app.queue_free(); await _frames(2)
	_finish_fixture()
func _cleanup_view(app, token: String) -> Dictionary:
	var run: RunState = app.run_state
	var registration: Dictionary = run.world_sequence_registrations.get(token, {})
	var entry: Dictionary = run.current_environment.get("world_sequence_instances", {}).get(token, {})
	var state: Dictionary = entry.get("state", {})
	var objects: Array = app.current_spatial_interaction_snapshot().get("objects", [])
	var handoffs: Array = []; var leaves: Array = []
	for object in objects:
		if str(object.get("object_id", "")) == "crew::package_handoff" or bool(object.get("delivery_contact", false)): handoffs.append(object)
		if str(object.get("object_id", "")) == "travel:leave" and object.get("enabled", false) and object.get("visible", false) and object.get("interactive", false): leaves.append(object)
	return {"run_status": run.run_status, "terminal": run.is_terminal(), "screen": app.current_screen, "primary_present": run.scenario_sequence_present(), "scenario": run.current_environment.get("scenario_id", ""), "cash": run.bankroll, "heat": run.suspicion_level(), "duties": run.crew_delivery_obligation_count(), "rng": str(run.rng_state), "delivery": run.delivery_snapshot(), "authority": run.validate_room_action_authority(), "object_count": objects.size(), "handoffs": handoffs, "enabled_leave_count": leaves.size(), "pending_rebuild": run.current_environment.get("scenario_restore_pending_trusted_rebuild"), "registration_lifecycle": registration.get("lifecycle"), "instance_lifecycle": entry.get("lifecycle"), "pending_outcome_count": registration.get("pending_outcomes", []).size(), "outcome_keys": entry.get("outcome_receipts", {}).keys(), "ack_keys": entry.get("outcome_acknowledgements", {}).keys(), "command_receipts": state.get("command_receipts", []).duplicate()}
func _assert_cleanup_view(view: Dictionary, app, stage: String) -> void:
	_expect(not view.get("terminal", true) and view.get("run_status", "") == RunState.RUN_STATUS_ACTIVE, stage + ": ordinary handoff does not end run")
	_expect(view.get("screen") == app.SCREEN_ENVIRONMENT, stage + ": ordinary room remains displayed")
	_expect(view.get("primary_present", false) == primary_contract and view.get("scenario", "") == facts.fixture.get("scenario", ""), stage + ": authored primary context retained")
	_expect(view.get("authority", {}).get("ok", false), stage + ": strict active room authority retained")
	_expect(int(view.get("object_count", 0)) > 0 and int(view.get("enabled_leave_count", 0)) == 1, stage + ": ordinary visible room and enabled Leave remain")
	_expect(view.get("handoffs", []).is_empty(), stage + ": completed contact is absent")
	_expect(view.get("registration_lifecycle", "") == "cleaned" and view.get("instance_lifecycle", "") == "cleaned", stage + ": owner remains cleaned")
	_expect(view.get("outcome_keys", []).size() == 1 and view.get("ack_keys", []) == view.get("outcome_keys", []) and int(view.get("pending_outcome_count", -1)) == 0, stage + ": one receipt acknowledged with no pending outcome")
func _exercise_cleanup(app, library: ContentLibrary, token: String) -> void:
	var before := _protected(app.run_state)
	var pre_handoff: Dictionary = app.run_state.to_dict()
	var primary_before: Dictionary = app.run_state.current_environment.get("scenario_sequence_state", {}).duplicate(true)
	var candidates: Array = []
	for object in app.current_spatial_interaction_snapshot().get("objects", []):
		if object.get("object_id", "") == "crew::package_handoff" and object.get("delivery_contact", false) and object.get("visible", false) and object.get("interactive", false) and object.get("enabled", false) and object.get("world_sequence_owner_token", "") == token: candidates.append(object)
	if not _expect(candidates.size() == 1, "one exact displayed handoff is available after cold restore"): return
	facts.cleanup_before = {"state": before, "view": _cleanup_view(app, token)}
	_test_cleanup_boundary_failures(pre_handoff, library, token, candidates[0])
	var activated: bool = app.focus_interactable_object("crew::package_handoff") and app.activate_interactable_object("crew::package_handoff")
	_expect(activated, "one normal displayed handoff activation returns success")
	facts.handoff_activation_count = 1
	await _frames(8)
	var view := _cleanup_view(app, token); facts.cleanup_after = view
	_assert_cleanup_view(view, app, "after one displayed handoff")
	_expect(app.run_state.current_environment.get("scenario_sequence_state", {}) == primary_before, "handoff cleanup preserves primary sequence state")
	var authored: Dictionary = facts.authored_consumer.get("success", {})
	_expect(int(view.cash) == int(before.cash) + int(authored.get("cash", 0)) and int(view.heat) == int(before.get("heat", 0)) + int(authored.get("heat", 0)), "handoff applies shipped consumer cash and heat exactly once")
	_expect(int(view.duties) == int(before.duties) - 1 and str(view.rng) == str(before.rng), "handoff clears one duty without root RNG change")
	_expect(view.delivery.get("status", "") == "resolved" and view.delivery.get("resolution", {}).get("outcome", "") == "success" and view.delivery.get("resolution", {}).get("reason", "") == "delivered", "handoff resolves one successful delivered package")
	if not view.get("authority", {}).get("ok", false): facts.cleanup_save_skipped = "Room authority failed; no explicit Save or replay attempted"; return
	var settled := _protected(app.run_state)
	app._refresh(); app._refresh()
	_expect(_protected(app.run_state) == settled, "repeated refresh preserves settled accounting and causal owner journal")
	var generation_before := int(app.autosave_completed_generation)
	app.save_foundation_run()
	_expect(int(app.autosave_completed_generation) > generation_before and app.save_status_message == "Saved run.", "settled explicit Main Save commits a new generation")
	_expect(app.save_service.wait_for_async_save() == OK and app.load_foundation_run(), "ordinary Continue reloads settled same synthetic slot")
	facts.cleanup_after_continue = _cleanup_view(app, token)
	_assert_cleanup_view(facts.cleanup_after_continue, app, "settled Save/Continue")
	_expect(app.run_state.current_environment.get("scenario_sequence_state", {}) == primary_before, "settled Continue preserves primary sequence state")
	_expect(_protected(app.run_state) == settled, "settled Continue replays no money duty or outcome receipt")
	_negative_cleanup_owner_guards(app.run_state, token)
func _economy(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "heat": run.suspicion_level(), "duties": run.crew_delivery_obligation_count(), "rng": str(run.rng_state), "delivery": run.delivery_snapshot()}
func _test_cleanup_boundary_failures(saved: Dictionary, library: ContentLibrary, token: String, displayed: Dictionary) -> void:
	# Detached synthetic models only. No Main/profile is replaced or copied.
	for mutation in ["manifest", "slot"]:
		var hostile := RunStateScript.new(); hostile.from_dict(saved)
		_expect(hostile.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}}).get("ok", false), mutation + ": cleanup tamper fixture hydrates valid source")
		if mutation == "manifest": hostile.current_environment["object_manifest_digest"] = "f".repeat(64)
		else:
			var bindings: Dictionary = hostile.current_environment.get("layout", {}).get("slot_bindings", {})
			var keys := bindings.keys(); keys.sort()
			if not _expect(not keys.is_empty(), "cleanup tamper has physical slot binding"): continue
			bindings[keys[0]]["slot_id"] = "fixed.nonexistent_synthetic_slot"
		var environment_before := JSON.stringify(hostile.current_environment)
		var protected_before := _protected(hostile)
		var rejected := hostile.world_sequence_sync_owner(token, false, "owner_ended")
		_expect(not rejected.get("ok", false), mutation + ": cleanup authenticates incoming full seal before owner retirement")
		_expect(JSON.stringify(hostile.current_environment) == environment_before and _protected(hostile) == protected_before, mutation + ": rejected cleanup changes neither presentation nor accounting/journals")
	var detached := RejectCleanupPublication.new(); detached.from_dict(saved)
	_expect(detached.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}}).get("ok", false), "publication-failure fixture hydrates valid source")
	var actions: Array = displayed.get("scenario_sequence_actions", [])
	if not _expect(actions.size() == 1, "failure injection uses exact displayed action origin"): return
	var action: Dictionary = actions[0]
	var command := detached.world_sequence_command(FunctionOptions.world_sequence_command(token, "make_handoff", "synthetic:cleanup_publication_failure", {
		"payload": {}, "owner_namespace": "crew", "stable_object_id": "package_handoff", "host_interaction_availability": {"crew::package_handoff": true},
		"action_origin_owner_namespace": action.get("action_origin_owner_namespace", ""), "action_origin_stable_object_id": action.get("action_origin_stable_object_id", ""),
		"action_origin_receipt_key": action.get("action_origin_receipt_key", ""), "action_origin_boundary_id": action.get("action_origin_boundary_id", ""), "action_origin_fingerprint": action.get("action_origin_fingerprint", "")
	}))
	_expect(command.get("ok", false), "detached failure case issues one authenticated handoff command")
	var committed := detached.world_sequence_commit_delivery_outcome(token, "back_alley")
	if not _expect(committed.get("ok", false), "detached failure case commits one settlement checkpoint"): return
	var pending: Array = detached.world_sequence_pending_outcomes(token)
	if not _expect(pending.size() == 1, "detached failure case has one outcome receipt"): return
	var receipt_id := str(pending[0].get("receipt_id", ""))
	var settled := _economy(detached)
	detached.reject_cleanup_publication = true
	var rejected := detached.world_sequence_consume_delivery_outcome(token, receipt_id, "back_alley")
	_expect(not rejected.get("ok", false) and rejected.get("errors", []).has("Synthetic cleanup publication failure."), "composition failure is reported rather than publishing partial room")
	var entry: Dictionary = detached.current_environment.get("world_sequence_instances", {}).get(token, {})
	var registration: Dictionary = detached.world_sequence_registrations.get(token, {})
	_expect(_economy(detached) == settled, "publication rollback retains committed payment duty and delivery checkpoint")
	_expect(entry.get("lifecycle", "") == "cleanup_pending" and registration.get("lifecycle", "") == "cleanup_pending", "publication rollback retains acknowledged cleanup-pending presentation")
	_expect(entry.get("outcome_acknowledgements", {}).has(receipt_id) and registration.get("pending_outcomes", []).size() == 1 and entry.get("state", {}).get("command_receipts", []).size() == 1, "rollback retains acknowledgment and one command plus durable cleanup work")
	detached.reject_cleanup_publication = false
	var resumed := detached.world_sequence_consume_delivery_outcome(token, receipt_id, "back_alley")
	_expect(resumed.get("ok", false) and detached.validate_room_action_authority().get("ok", false), "cleanup-only retry produces strict room authority")
	_expect(_economy(detached) == settled, "cleanup-only retry reissues no settlement")
	entry = detached.current_environment.get("world_sequence_instances", {}).get(token, {})
	_expect(entry.get("lifecycle", "") == "cleaned" and entry.get("outcome_acknowledgements", {}).has(receipt_id) and entry.get("state", {}).get("command_receipts", []).size() == 1, "retry cleans same acknowledged receipt with one original command")
	var finished := _protected(detached)
	_expect(detached.world_sequence_sync_owner(token, false).get("replayed", false) and _protected(detached) == finished, "completed cleanup replay is an accounting and journal no-op")
	facts.cleanup_failure_injection = {"initial_failure": rejected, "retry": resumed, "economy_unchanged": _economy(detached) == settled, "commands": entry.get("state", {}).get("command_receipts", []).size(), "acknowledged": entry.get("outcome_acknowledgements", {}).has(receipt_id)}
func _negative_cleanup_owner_guards(source_run: RunState, token: String) -> void:
	var saved := source_run.to_dict()
	var original := _protected(source_run)
	for mutation in ["missing_entry", "other_node"]:
		var detached := RunStateScript.new(); detached.from_dict(saved)
		if mutation == "missing_entry": detached.current_environment["world_sequence_instances"].erase(token)
		else: detached.world_sequence_registrations[token]["node_id"] = "bar"
		var before := _protected(detached)
		_expect(not detached.world_sequence_prepare_semantic_finalization().get("active", false), mutation + ": cleaned history cannot authorize unrelated rebuild")
		_expect(_protected(detached) == before, mutation + ": rejected cleanup owner creates no consequence or journal change")
	_expect(_protected(source_run) == original, "cleanup negative copies leave settled source untouched")
func _negative_restore_guards(source_run: RunState, library: ContentLibrary, token: String) -> void:
	# Hostile inputs affect detached synthetic copies only. The unchanged trusted
	# finalizer must reject them before hydration, publication or any consequence.
	var saved := source_run.to_dict()
	var protected_source := _protected(source_run)
	for mutation in ["manifest", "slot"]:
		var hostile := RunStateScript.new(); hostile.from_dict(saved)
		if mutation == "manifest": hostile.current_environment["object_manifest_digest"] = "f".repeat(64)
		else:
			var layout: Dictionary = hostile.current_environment.get("layout", {}).duplicate(true)
			var bindings: Dictionary = layout.get("slot_bindings", {}).duplicate(true)
			var keys := bindings.keys(); keys.sort()
			if not _expect(not keys.is_empty(), "slot tamper fixture has existing sealed bindings"): continue
			var binding: Dictionary = bindings[keys[0]].duplicate(true)
			binding["slot_id"] = "fixed.nonexistent_synthetic_slot"; bindings[keys[0]] = binding
			layout["slot_bindings"] = bindings; hostile.current_environment["layout"] = layout
		var before := JSON.stringify(hostile.current_environment)
		var protected_before := _protected(hostile)
		var result := hostile.scenario_finalize_installed_environment(library, {"viewport_size": {"x": 1280, "y": 720}})
		_expect(not result.get("ok", false), mutation + ": trusted finalizer rejects hostile saved authority")
		_expect(JSON.stringify(hostile.current_environment) == before and _protected(hostile) == protected_before, mutation + ": rejection leaves source bytes and accounting/owner journals unchanged")
		_expect(hostile.get("_world_sequence_definition_cache").is_empty(), mutation + ": rejected authority never hydrates the owner")
	var wrong_node := RunStateScript.new(); wrong_node.from_dict(saved)
	var registration: Dictionary = wrong_node.world_sequence_registrations[token].duplicate(true)
	registration["node_id"] = "bar"; wrong_node.world_sequence_registrations[token] = registration
	var wrong_before := _protected(wrong_node)
	_expect(wrong_node.delivery_world_sequence_owner_for_presentation("back_alley").is_empty(), "foreign-node registration cannot qualify exact delivery rebuild")
	_expect(_protected(wrong_node) == wrong_before, "foreign-node rejection does not mutate model state")
	var invalid_saved := saved.duplicate(true)
	var invalid_registration: Dictionary = invalid_saved["world_sequence_registrations"][token]
	invalid_registration["definition"]["id"] = "invalid_synthetic_definition"
	var invalid := RunStateScript.new(); invalid.from_dict(invalid_saved)
	_expect(not invalid.world_sequence_registrations.has(token), "mismatched owner definition/fingerprint is rejected during normal restore")
	_expect(invalid.delivery_world_sequence_owner_for_presentation("back_alley").is_empty(), "rejected definition cannot authorize a delivery rebuild")
	_expect(_protected(source_run) == protected_source, "negative cases leave the valid source fixture unchanged")
func _finish_fixture() -> void:
	var fidelity := "Synthetic custom challenge excludes primary Back Alley scenarios; production package begin/arrival, shipped public owner mount/seal, ordinary Main Save/Continue. No player campaign/profile, private authority, handoff/reward/outcome command."
	if cleanup_contract: fidelity = "Detached synthetic package with explicit duties and shipped event consumer payload; production clock reaches appointment before Save; one normal displayed Main handoff after cold restore, then cleanup/Save/Continue. Detached failure injection uses a separate synthetic model and cleanup-only retry. No original player campaign/profile, CJ2 access, copied save, custody reset or reward replay."
	var result := {"checks": checks, "failures": failures, "facts": facts, "fidelity": fidelity, "primary_context": primary_contract}
	var tokens := OS.get_cmdline_user_args()
	var index := tokens.find("--evidence-output")
	if index >= 0 and index + 1 < tokens.size():
		var file := FileAccess.open(tokens[index + 1], FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ") + "\n"); file.close()
	print("CREW_HANDOFF_CONTINUE_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
