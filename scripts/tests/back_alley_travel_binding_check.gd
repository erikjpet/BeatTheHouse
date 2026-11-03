extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

# Actual captured-save regression. The caller supplies an immutable captured
# bundle; the inherited installer copies it into a disposable native-private
# root. No clock, route, scenario, delivery, or economy fixture is substituted.
# This exercises normal Continue -> Map -> Back Alley -> Confirm exactly once.
class BoundaryObserver extends RunGenerator:
	var rejected_install: Dictionary = {}
	var install_attempts := 0
	func _init(content: ContentLibrary) -> void:
		super(content)
	func _install_environment_with_rollback(run: RunState, environment: Dictionary, rollback: Dictionary, restore_on_failure: bool = true) -> Dictionary:
		install_attempts += 1
		var result := super._install_environment_with_rollback(run, environment, rollback, restore_on_failure)
		if not bool(result.get("ok", false)):
			# Normal host travel owns rollback. This bounded public-only summary is
			# sampled after production finalization and before that outer rollback.
			rejected_install = {
				"errors": result.get("errors", []).duplicate(true),
				"generated": binding_summary(environment),
				"installed": binding_summary(run.current_environment),
			}
		return result
	static func binding_summary(environment: Dictionary) -> Dictionary:
		var object_id := "event:recruitment_mags"
		var row: Dictionary = {}
		for value in environment.get("object_manifest", {}).get("rows", []):
			if str(value.get("presentation_object_id", value.get("object_id", ""))) == object_id:
				for field in ["object_id", "instance_object_id", "presentation_object_id", "source_kind", "slot_family", "family", "owner_namespace"]:
					if value.has(field): row[field] = value.get(field)
		var base: Dictionary = environment.get("layout", {}).get("slot_bindings", {})
		var scenario: Dictionary = environment.get("scenario_layout_authority", {})
		var visuals: Array = []
		for value in environment.get("scenario_render_snapshot", {}).get("visual_objects", []):
			if str(value.get("object_id", "")) == object_id:
				visuals.append({"object_id": object_id, "slot_id": value.get("slot_id", ""), "slot_family": value.get("slot_family", ""), "owner_namespace": value.get("owner_namespace", "")})
		return {
			"archetype_id": environment.get("archetype_id", ""),
			"scenario_id": environment.get("scenario_id", ""),
			"mags_manifest": row,
			"mags_base_binding": base.get(object_id, {}).duplicate(true),
			"mags_scenario_binding": scenario.get(object_id, scenario.get(str(row.get("instance_object_id", "")), {})).duplicate(true),
			"mags_visuals": visuals,
		}


func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "disposable private root required"):
		_finish(); return
	if not _check(ProjectSettings.globalize_path("user://").contains("native-private-"), "resolved user storage is disposable and private"):
		_finish(); return
	if OS.get_environment("BTH_ALLEY_BINDING_COLD") == "1":
		await _cold_continue()
		return
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not _check(not bundle.is_empty(), "explicit actual captured bundle required"):
		_finish(); return
	_install(bundle)
	if not failures.is_empty(): _finish(); return
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official captured save and authority companions load"):
		_finish(); return
	var initial_protected := _protected(baseline)
	var initial_delivery := _delivery_history(baseline)
	facts = {"fidelity": "actual captured R03 bundle; normal native host Continue and one map confirmation", "initial": _public_run_facts(baseline), "confirmations": 0}
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal host Continue loads captured run"):
		await _close(app); _finish(); return
	var run: RunState = app.run_state
	_check(_protected(run) == initial_protected, "Continue preserves captured protected gameplay exactly")
	_check_delivery_equivalence(run, initial_delivery, "Continue preserves missed delivery and outstanding duties", "initial_continue_delivery")
	if not _check(str(run.current_environment.get("archetype_id", "")) == "motel", "captured source is Motel"):
		await _close(app); _finish(); return
	_check(not run.delivery_has_active_run(), "captured missed delivery remains inactive")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "source has strict room authority")
	var forced_suppression := OS.get_environment("BTH_ALLEY_FORCE_SUPPRESSION") == "1"
	if forced_suppression:
		# Synthetic sibling of the actual captured save: exercise the normal
		# suppression entry point, without manufacturing an install rejection.
		var destination: Dictionary = run._seeded_scenario_definition_for_node_readonly("back_alley")
		var scenario_id := str(destination.get("id", ""))
		if not _check(not scenario_id.is_empty(), "synthetic suppressed sibling resolves actual destination scenario"):
			await _close(app); _finish(); return
		var suppression_before := _protected(run)
		var suppression_clock := run.game_clock_minutes
		if not _check(app._suppress_failed_standard_scenario({"target_id": "back_alley", "scenario_id": scenario_id}, "back_alley"), "normal host suppression accepts exact captured destination scenario"):
			await _close(app); _finish(); return
		var suppression_after := _protected(run)
		var suppression_diff := _different_paths(suppression_before, suppression_after)
		facts["suppression_protected"] = {
			"diff": suppression_diff,
			"raw_fingerprints": {"before": Runtime.content_fingerprint(suppression_before), "after": Runtime.content_fingerprint(suppression_after)},
			"persistent_fingerprints": {"before": _persistent_fingerprint(suppression_before), "after": _persistent_fingerprint(suppression_after)},
			"comparison_contract": "Synthetic forced suppression preserves every public Crew field and the full logical private payload hash; normal Save/Continue still authenticates its challenge-bound capsule.",
		}
		_check(suppression_diff.is_empty() and _persistent_fingerprint(suppression_before) == _persistent_fingerprint(suppression_after) and run.game_clock_minutes == suppression_clock, "synthetic overlay suppression preserves all public Crew fields private payload and protected gameplay values and clock")
		facts["fidelity"] = "synthetic suppressed-overlay sibling of actual captured R03 save; normal host suppression and one map confirmation"
		facts["forced_suppression"] = {"target_id": "back_alley", "scenario_id": scenario_id}
	var observer := BoundaryObserver.new(app.library)
	app.generator = observer
	observer.set_world_environment_timing_enabled(true)
	if not _check(app.open_world_map(), "normal World Map opens"):
		await _close(app); _finish(); return
	if not _check(app.select_world_map_node("back_alley"), "normal Back Alley map selection"):
		await _close(app); _finish(); return
	var quote: Dictionary = app._travel_choice("back_alley").duplicate(true)
	facts["quote"] = _public_quote(quote)
	if not _check(bool(quote.get("enabled", false)), "actual quoted Back Alley route is enabled"):
		await _close(app); _finish(); return
	var source_protected := _protected(run)
	var source_clock := run.game_clock_minutes
	var source_cash := run.bankroll
	var story_size := run.story_log.size()
	observer.rejected_install = {}
	observer.install_attempts = 0
	facts["confirmations"] = 1
	var result: Dictionary = app.confirm_world_map_travel()
	facts["travel"] = {"ok": bool(result.get("ok", false)), "errors": result.get("errors", []).duplicate(true)}
	facts["first_generator_install_attempts"] = observer.install_attempts
	facts["generator_failure"] = observer.environment_install_failure_snapshot()
	if not bool(result.get("ok", false)):
		facts["rejected_install"] = observer.rejected_install.duplicate(true)
		_check(_protected(app.run_state) == source_protected and app.run_state.game_clock_minutes == source_clock, "rejected normal trip rolls back protected state and clock")
		_check_delivery_equivalence(app.run_state, initial_delivery, "rejected trip never replays missed delivery", "rejected_delivery")
		_check(false, "normal captured Motel to Back Alley trip succeeds")
		facts["final"] = _public_run_facts(app.run_state)
		await _close(app); _finish(); return
	_check(true, "normal captured Motel to Back Alley trip succeeds")
	_check(observer.rejected_install.is_empty() and observer.install_attempts == 1 and app.generator == observer, "first intended install succeeds without automatic suppression retry")
	run = app.run_state
	_check(run.current_world_node_id() == "back_alley" and str(run.current_environment.get("archetype_id", "")) == "back_alley", "confirmed trip arrives in actual Back Alley")
	_check(run.game_clock_minutes - source_clock == int(quote.get("travel_minutes", 0)), "quoted travel clock commits once")
	var travel_rows: Array = []
	var risk_rows: Array = []
	for value in run.story_log.slice(story_size):
		if str(value.get("type", "")) == "travel" and str(value.get("id", "")) == "back_alley": travel_rows.append(value)
		if str(value.get("type", "")) == "travel_risk_event" and str(value.get("route_id", "")) == "back_alley": risk_rows.append(value)
	_check(travel_rows.size() == 1, "one accepted travel receipt")
	if not travel_rows.is_empty():
		var receipt: Dictionary = travel_rows[0]
		var risk: Dictionary = receipt.get("route_risk", {})
		var risk_delta := int(risk.get("bankroll_delta", 0)) if bool(risk.get("triggered", false)) else 0
		_check(int(receipt.get("route_cost", -1)) == int(quote.get("cost", 0)), "accepted fare equals visible departure quote")
		_check(run.bankroll == source_cash - int(quote.get("cost", 0)) + risk_delta, "cash changes by quoted fare and one actual risk only")
		_check(risk_rows.size() == (1 if bool(risk.get("triggered", false)) else 0), "risk receipt occurs once if triggered")
		facts["settlement"] = {"fare": receipt.get("route_cost", 0), "cash_delta": run.bankroll - source_cash, "risk": risk.duplicate(true), "travel_receipts": travel_rows.size(), "risk_receipts": risk_rows.size()}
	_check_delivery_equivalence(run, initial_delivery, "arrival never replays missed delivery payout or clears outstanding duties", "arrival_delivery")
	_check(not run.delivery_has_active_run(), "arrival never revives missed package")
	_assert_live_controls(app, "arrival")
	facts["arrival_binding"] = BoundaryObserver.binding_summary(run.current_environment)
	var arrival_protected := _protected(run)
	var arrival_clock := run.game_clock_minutes
	for repeat in range(2): app._prepare_room_presentation_at_boundary()
	_check(_protected(run) == arrival_protected and run.game_clock_minutes == arrival_clock, "repeated room publication preserves economy RNG clock and journals")
	if OS.get_environment("BTH_ALLEY_TAMPER") == "1": _check_actual_arrival_tamper(run, app.library)
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Main Menu after explicit Save")
	await process_frame
	app.save_service = SaveService.new()
	if _check(app.load_foundation_run(), "fresh SaveService normal Continue restores arrival"):
		run = app.run_state
		facts["continue_protected_diff"] = _different_paths(arrival_protected, _protected(run))
		facts["continue_protected_diff_paths"] = facts["continue_protected_diff"].map(func(value): return value.get("path", ""))
		facts["continue_protected_different_keys"] = _different_keys(arrival_protected, _protected(run))
		facts["continue_protected_fingerprints"] = {"before": Runtime.content_fingerprint(arrival_protected), "after": Runtime.content_fingerprint(_protected(run))}
		facts["continue_protected_persistent_fingerprints"] = {"before": _persistent_fingerprint(arrival_protected), "after": _persistent_fingerprint(_protected(run))}
		facts["continue_clock"] = {"before": arrival_clock, "after": run.game_clock_minutes}
		_check(run.current_world_node_id() == "back_alley", "Save Continue retains actual destination")
		_check(_persistent_fingerprint(_protected(run)) == _persistent_fingerprint(arrival_protected) and facts["continue_protected_diff"].is_empty() and run.game_clock_minutes == arrival_clock, "Save Continue preserves every protected value exactly in saved JSON representation including fare risk RNG clock and receipts")
		_check_delivery_equivalence(run, initial_delivery, "Save Continue preserves original missed delivery without rewards", "save_continue_delivery")
		_assert_live_controls(app, "Save Continue")
	facts["final"] = _public_run_facts(app.run_state)
	facts["cold_expected"] = _cold_expectation(app.run_state)
	await _close(app)
	_finish()


func _check_actual_arrival_tamper(run: RunState, library: ContentLibrary) -> void:
	# Explicitly synthetic adversarial siblings of the accepted actual arrival.
	# No forged envelope enters the live host, a save slot, or the captured bundle.
	var live_protected := Runtime.content_fingerprint(_protected(run))
	var live_clock := run.game_clock_minutes
	var results: Array = []
	for kind in ["frozen_target", "digest_reference"]:
		var probe := RunState.new()
		probe.from_dict(run.to_dict())
		probe.current_environment = run.current_environment.duplicate(true)
		probe.restore_scenario_definition_cache(run.scenario_definition_cache_snapshot())
		var before := Runtime.content_fingerprint(_protected(probe))
		var before_clock := probe.game_clock_minutes
		var state: Dictionary = probe.current_environment.get("scenario_sequence_state", {}).duplicate(true)
		var semantic: Dictionary = state.get("semantic_state", {}).duplicate(true)
		if not _check(not semantic.is_empty(), "synthetic %s probe starts from actual primary scenario authority" % kind):
			continue
		if kind == "frozen_target":
			var event_id := "recruitment_knuckles"
			var events: Array = probe.current_environment.get("event_ids", []).duplicate(true)
			if not _check(not library.event(event_id).is_empty() and not events.has(event_id), "synthetic target probe uses a real unsealed catalog event"):
				continue
			events.append(event_id)
			probe.current_environment["event_ids"] = events
			var targets: Dictionary = semantic.get("target_inventory", {}).duplicate(true)
			var scene_objects: Array = targets.get("scene_objects", []).duplicate(true)
			scene_objects.append("event::event:%s" % event_id)
			targets["scene_objects"] = scene_objects
			semantic["target_inventory"] = targets
			# The real save omits this derived body. Keep the original version/digest
			# reference while attacking the frozen target list used for reconstruction.
			probe.current_environment.erase("scenario_semantic_inventory")
		else:
			var forged_digest := "0".repeat(64)
			probe.current_environment["scenario_semantic_digest"] = forged_digest
			semantic["inventory_digest"] = forged_digest
		state["semantic_state"] = semantic
		probe.current_environment["scenario_sequence_state"] = state
		var rejected := probe.scenario_finalize_installed_environment(library)
		_check(not bool(rejected.get("ok", false)), "synthetic %s tamper fails strict finalization" % kind)
		_check(Runtime.content_fingerprint(_protected(probe)) == before and probe.game_clock_minutes == before_clock, "synthetic %s rejection preserves all protected cash RNG clock duties and missed history" % kind)
		results.append({"kind": kind, "ok": bool(rejected.get("ok", false)), "errors": rejected.get("errors", []).duplicate(true), "public_after": _public_run_facts(probe)})
	_check(Runtime.content_fingerprint(_protected(run)) == live_protected and run.game_clock_minutes == live_clock, "all synthetic tamper probes leave actual host run unchanged")
	facts["synthetic_tamper"] = results


func _cold_continue() -> void:
	# Independent process, same disposable storage. Never install the original
	# Motel capture or issue another trip in this acceptance mode.
	var expected_path := OS.get_environment("BTH_ALLEY_EXPECTED_RESULT")
	if not _check(not expected_path.is_empty() and FileAccess.file_exists(expected_path), "warm public receipt supplied for independent cold acceptance"):
		_finish(); return
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not _check(typeof(receipt) == TYPE_DICTIONARY, "warm receipt is valid JSON"):
		_finish(); return
	var expected: Dictionary = receipt.get("facts", {}).get("cold_expected", {})
	if not _check(not expected.is_empty() and receipt.get("failures", []).is_empty(), "warm accepted trip produced expected public facts and protected digests"):
		_finish(); return
	facts = {"fidelity": "independent-process cold Continue of the actual captured run after accepted travel", "confirmations": 0}
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "independent-process normal cold Continue"):
		await _close(app); _finish(); return
	var run: RunState = app.run_state
	_check(run.current_world_node_id() == "back_alley", "cold Continue restores actual Back Alley")
	var actual := _cold_expectation(run)
	facts["cold_expectation_diff"] = _different_paths(expected, actual)
	facts["cold_expectation_fingerprints"] = {"expected": Runtime.content_fingerprint(expected), "actual": Runtime.content_fingerprint(actual)}
	facts["cold_expectation_persistent_fingerprints"] = {"expected": _persistent_fingerprint(expected), "actual": _persistent_fingerprint(actual)}
	_check(_persistent_fingerprint(actual) == _persistent_fingerprint(expected) and facts["cold_expectation_diff"].is_empty(), "cold Continue preserves every public and protected value exactly in saved JSON representation including cash Heat clock RNG duties and missed history")
	_check(not run.delivery_has_active_run(), "cold Continue never revives missed package")
	_assert_live_controls(app, "independent cold Continue")
	facts["final"] = _public_run_facts(run)
	facts["cold_expected"] = _cold_expectation(run)
	await _close(app)
	_finish()


func _cold_expectation(run: RunState) -> Dictionary:
	return {"public": _public_run_facts(run), "protected_digest": _persistent_fingerprint(_protected(run)), "delivery_history_digest": _persistent_fingerprint(_delivery_history(run))}


func _persistent_fingerprint(value: Variant) -> String:
	# Persistence expectations compare the actual JSON save representation.
	# Godot restores JSON numbers as floats; preserve every value while avoiding
	# runtime-only int/float type tags in the typed command/receipt fingerprint.
	return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _assert_live_controls(app: Host, label: String) -> void:
	_check(bool(app.run_state.validate_room_action_authority().get("ok", false)), "%s strict room action authority" % label)
	var controls: Array = app._interactable_object_view_list()
	_check(not controls.is_empty() and not _has_room_unavailable(app), "%s actual room controls are usable" % label)
	var mags: Array = controls.filter(func(value): return str(value.get("object_id", "")) == "event:recruitment_mags")
	_check(mags.size() == 1, "%s has one actual Mags control" % label)


func _delivery_history(run: RunState) -> Dictionary:
	var values := {"active_delivery_run": run.active_delivery_run.duplicate(true), "duties": run.crew_delivery_obligation_count(), "crew_state": _comparison_crew_state(run, run.to_dict().get("crew_state", {}))}
	var flags: Dictionary = {}
	for key in run.narrative_flags:
		if str(key).begins_with("crew_delivery_") or str(key).begins_with("profile_delivery_") or key in ["crew_marker_clear", "crew_favor_pending", "crew_package_next_offer_clock"]:
			flags[key] = run.narrative_flags.get(key)
	values["flags"] = flags.duplicate(true)
	var delivery_rows: Array = []
	for value in run.story_log:
		if str(value.get("type", "")).begins_with("delivery_"): delivery_rows.append(value.duplicate(true))
	values["delivery_story"] = delivery_rows
	return values


func _protected(run: RunState) -> Dictionary:
	var result := super._protected(run)
	if OS.get_environment("BTH_ALLEY_FORCE_SUPPRESSION") == "1":
		result["crew_state"] = _comparison_crew_state(run, result.get("crew_state", {}))
	return result


func _comparison_crew_state(run: RunState, serialized: Dictionary) -> Dictionary:
	var result := serialized.duplicate(true)
	if OS.get_environment("BTH_ALLEY_FORCE_SUPPRESSION") != "1":
		return result
	# Synthetic suppression deliberately changes challenge_config, to which the
	# encrypted Crew capsule is bound. Compare all of its logical private inputs
	# instead, retaining every public Crew field. Receipts contain only this hash.
	# Official Save/Continue continues to authenticate the actual opaque capsule.
	result["z"] = _persistent_fingerprint({
		"authority_id": run._crew_private_authority_id,
		"grievances": run.crew_grievance_ledger.duplicate(true),
		"sequence": run.crew_grievance_sequence,
		"heist": run.crew_heist_state.duplicate(true),
	})
	return result


func _check_delivery_equivalence(run: RunState, expected: Dictionary, label: String, diagnostic_key: String) -> void:
	var actual := _delivery_history(run)
	var diff := _different_paths(expected, actual)
	facts[diagnostic_key] = {
		"diff": diff,
		"raw_fingerprints": {"before": Runtime.content_fingerprint(expected), "after": Runtime.content_fingerprint(actual)},
		"persistent_fingerprints": {"before": _persistent_fingerprint(expected), "after": _persistent_fingerprint(actual)},
	}
	_check(diff.is_empty() and _persistent_fingerprint(expected) == _persistent_fingerprint(actual), label)


func _public_run_facts(run: RunState) -> Dictionary:
	return {"archetype_id": run.current_environment.get("archetype_id", ""), "scenario_id": run.current_environment.get("scenario_id", ""), "clock": run.game_clock_minutes, "cash": run.bankroll, "Heat": run.suspicion_level(), "delivery_active": run.delivery_has_active_run(), "duties": run.crew_delivery_obligation_count()}


func _public_quote(quote: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in ["id", "label", "enabled", "disabled_reason", "cost", "travel_minutes", "risk", "risk_text", "risk_event", "suspicion_delta", "travel_method", "force_walk_fallback"]:
		if quote.has(field): result[field] = quote.get(field)
	return result.duplicate(true)


func _close(app: Host) -> void:
	app.queue_free()
	await process_frame


func _finish() -> void:
	var hashes: Dictionary = {}
	for name in ["scripts/core/run_generator.gd", "scripts/core/run_state.gd", "scripts/core/environment_object_manifest.gd", "scripts/core/environment_slot_binder.gd", "scripts/core/room_presentation_publication.gd", "scripts/ui/foundation_main.gd", "scripts/tests/back_alley_travel_binding_check.gd"]:
		hashes[name] = FileAccess.get_sha256("res://" + name)
	facts["source_sha256"] = hashes
	var receipt := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt, "  ")); file.close()
	print("BACK_ALLEY_CAPTURED ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
