extends SceneTree

# SYNTHETIC ENGINEERING FIXTURE ONLY. Never install a captured player save here.
# Reuses reviewed fixture003 without changing its setup/paid-action order.
# Candidate qualification is recorded by source hashes; BASE_SOURCE is provenance.
# The treatment sets historical job net to -100 before one real paid6 settlement.
# No cards, shoe, current outcome, authority receipt or actual Web state is forced.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const LOSS_OBJECT := "event:crew_stake_horse_loss"
const SLOT := "foundation_ui_autosave"
const STAKE := 6
const HISTORICAL_NET := -100
const BASE_SOURCE := "e53eb65725fb387ed0b97761e23ea6bb77e47713"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var job_id := ""


# Read-only diagnostics on copied projection inputs. No manifest regeneration,
# slot repair, proof rewriting, or validation result substitution is performed.
class PhysicalTrace:
	extends RefCounted

	static func room(value: Dictionary) -> Dictionary:
		var env := value.duplicate(true)
		var surface := EnvironmentPlacement.surface_map(env)
		var entries := EnvironmentInstance._physical_manifest_layout_entries(env, surface)
		var manifest: Dictionary = env.get("object_manifest", {})
		var inputs: Dictionary = {}
		for key in ["id", "archetype_id", "current_layer_id", "world_node_id", "game_ids", "event_ids", "resolved_event_ids", "service_ids", "lender_hooks", "object_fixtures", "travel_hooks", "next_archetypes", "layer_transitions", "home_lost"]:
			inputs[key] = env.get(key)
		var entry_inputs: Array = []
		for row in entries:
			if not str(row.get("runtime_owner", "")).is_empty() or str(row.get("spot_field", "")) == "runtime_object_manifest_entries": continue
			var selected: Dictionary = {}
			for key in ["object_id", "object_type", "index", "placement_class", "slot_family", "family", "render_key", "spot_field", "metadata", "active"]: selected[key] = row.get(key)
			entry_inputs.append(selected)
		inputs["physical_entries"] = entry_inputs
		return {"id": env.get("id", ""), "layer": env.get("current_layer_id", ""), "recorded_source_digest": manifest.get("source_digest", ""), "recomputed_source_digest": EnvironmentObjectManifest._source_digest(env, entries, surface), "manifest_errors": EnvironmentInstance.object_manifest_errors(env), "source_inputs": inputs}

	static func view(value: Dictionary) -> Dictionary:
		var result := room(value)
		var layers: Dictionary = {}
		for layer_id in value.get("layer_states", {}):
			var layer_value: Variant = value.get("layer_states", {}).get(layer_id)
			if layer_value is Dictionary: layers[str(layer_id)] = room(layer_value)
		result["layers"] = layers
		return result

class InstallTraceRun:
	extends RunState
	var install_trace: Array = []

	func set_environment(environment_data: Dictionary, debug_timing: Dictionary = {}) -> Dictionary:
		install_trace.append({"phase": "before_set_environment", "view": PhysicalTrace.view(environment_data)})
		var result := super.set_environment(environment_data, debug_timing)
		install_trace.append({"phase": "after_set_environment", "result": result.duplicate(true), "view": PhysicalTrace.view(current_environment)})
		return result

	func scenario_finalize_installed_environment(library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
		install_trace.append({"phase": "before_scenario_finalize", "view": PhysicalTrace.view(current_environment)})
		var result := super.scenario_finalize_installed_environment(library, layout_context)
		install_trace.append({"phase": "after_scenario_finalize", "result": result.duplicate(true), "view": PhysicalTrace.view(current_environment)})
		return result

class InstallTraceGenerator:
	extends RunGenerator
	var install_trace: Array = []

	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func _install_environment_with_rollback(run: RunState, environment_data: Dictionary, rollback: Dictionary, restore_on_failure: bool = true) -> Dictionary:
		install_trace.append({"phase": "generator_before_install", "view": PhysicalTrace.view(environment_data)})
		var result := super._install_environment_with_rollback(run, environment_data, rollback, restore_on_failure)
		install_trace.append({"phase": "generator_after_install", "result": result.duplicate(true), "view": PhysicalTrace.view(run.current_environment)})
		return result



func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var private_root := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	if not _check(private_root.contains("native-private-stake-loss-synthetic-"), "dedicated synthetic private root required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "captured/Web fixtures must not be supplied"):
		_finish(); return
	var mode := OS.get_environment("BTH_STAKE_LOSS_SYNTH_MODE")
	if not _check(mode in ["control", "warm", "cold"], "explicit synthetic mode required"):
		_finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	facts = {"source_base_commit": BASE_SOURCE, "mode": mode, "fidelity": "SYNTHETIC: fresh private run, generated Casino, synthetic Mags eligibility and historical job net. Exactly one production sealed paid6 play_basic; no card/result/receipt forcing and no genuine Web save input."}
	if mode == "cold":
		await _cold(app)
	else:
		await _paid_case(app, mode == "warm")
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _paid_case(app: Host, threshold_case: bool) -> void:
	if not _check(app._ensure_run_ui_built(), "normal host UI initialization"):
		return
	if app.library == null: app._initialize_foundation()
	app._ensure_full_content_library_loaded()
	if not _check(app.library != null, "loaded authoritative content library"):
		return
	var trace_run := InstallTraceRun.new()
	var run: RunState = trace_run
	# Match Foundation's and EnvironmentTestModeCheck's supported constructor.
	# This namespaced seed/context is synthetic setup, never a campaign reroll.
	var domain_seed := "ENVIRONMENT-PRACTICE-v1:SYNTHETIC-CREW-STAKE-PUBLICATION-001"
	run.start_new(domain_seed, RunState.custom_challenge("environment_practice", domain_seed, {"environment_practice": true}))
	facts["practice_context"] = {"domain_seed": domain_seed, "challenge_kind": "environment_practice", "modifier": true, "Crew_eligibility_order_unchanged_from_failed_control": false}
	# Synthetic setup, before the measured paid transaction. These are not earned
	# campaign actions and are never used as normal-player coverage.
	run.bankroll = 200
	var generator := InstallTraceGenerator.new(app.library)
	var generated := generator.environment_test_result(run, {
		"archetype_id": "small_underground_casino", "scenario_id": "__none",
		"layer_id": "casino", "generation_key": "synthetic-stake-loss-publication", "depth": 0,
	})
	facts["initial_generation_trace"] = {"generator": generator.install_trace.duplicate(true), "run": trace_run.install_trace.duplicate(true), "generated_result": {"ok": generated.get("ok", false), "errors": generated.get("errors", []), "warnings": generated.get("warnings", [])}}
	if not _check(bool(generated.get("ok", false)), "production generator installs synthetic Casino"):
		facts["generation_errors"] = generated.get("errors", []); return
	# Separate synthetic-fixture construction from practice entry of an already
	# Crew-started state. That real helper defect remains captured in controls001/002.
	# Admit the pristine room first; do not repair or reuse the rejected envelope.
	var pristine_errors := EnvironmentInstance.object_manifest_errors(run.current_environment)
	var pristine_authority := run.validate_room_action_authority()
	facts["pristine_generation"] = {"manifest_errors": pristine_errors.duplicate(), "authority": pristine_authority.duplicate(true), "environment_id": run.current_environment.get("id", ""), "world_node_id": run.current_environment.get("world_node_id", ""), "layer": run.current_environment.get("current_layer_id", ""), "seed_text": run.seed_text, "seed_value_opaque_digest": _digest(run.seed_value), "Crew_before_synthetic_setup": run.crew_reputation(), "Mags_before_synthetic_setup": run.crew_trust("crew_mags"), "game_state_opaque_digest": _digest(run.current_environment.get("game_states", {}))}
	if not _check(pristine_errors.is_empty() and bool(pristine_authority.get("ok", false)) and run.crew_reputation() == 0 and run.crew_trust("crew_mags") == 0, "pristine room strictly admitted before synthetic Crew setup"):
		return
	# Declared synthetic preconditions only. Existing library-aware baseline
	# generation and strict publication below still precede any measured paid call.
	run.crew_add_trust("crew_mags", 30, "synthetic_native_fixture")
	run.crew_change_reputation(100)
	run.current_environment["crew_presence"] = [{"member_id": "crew_mags", "rank": "associate"}]
	var accepted := run.crew_job_accept_definition("mags_low_roller_stake")
	job_id = str(accepted.get("job_id", ""))
	if not _check(bool(accepted.get("ok", false)) and not job_id.is_empty(), "synthetic eligible Mags job created through model admission"):
		facts["admission"] = accepted; return
	_check(run.bankroll == 220, "one authored20 funding credit on synthetic200 start")
	var job: Dictionary = run.crew_jobs.get(job_id, {}).duplicate(true)
	var payload: Dictionary = job.get("payload", {}).duplicate(true)
	# Deliberately artificial prior history: -100 is already below the loss
	# boundary. It is NOT a legitimately pending normal-player checkpoint and
	# does not claim the measured current hand lost. The control uses zero.
	payload["session_net"] = HISTORICAL_NET if threshold_case else 0
	job["payload"] = payload
	run.crew_jobs[job_id] = job
	# Only initial fixture preparation has a full library-aware layout build.
	# Never repair/rebuild hints manually after the measured loss insertion.
	run.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(run.current_environment, app.library)
	var prepared := run.prepare_current_environment_object_membership_for_publication()
	if not _check(bool(prepared.get("ok", false)), "initial synthetic room passes ordinary strict membership"):
		facts["initial_membership"] = prepared; return
	app.run_state = run
	app.generator = generator
	app._bind_run_state_presentation_signals()
	app._refresh_run_action_service()
	app._set_current_screen(app.SCREEN_ENVIRONMENT)
	app._refresh()
	for frame in range(3): await process_frame
	var base_controls := _ordinary_controls(app)
	var base_geometry := _control_geometry(app, base_controls)
	_check(not base_controls.is_empty(), "initial room has ordinary controls")
	_check(not run.current_environment.get("event_ids", []).has("crew_stake_horse_loss"), "Crew Money absent before paid result")
	_check(not run.current_environment.get("layout", {}).get("object_placement_hints", {}).has(LOSS_OBJECT), "new loss art not preallocated in fixture")
	if not failures.is_empty(): return
	if not _check(app.enter_game("blackjack"), "normal host enters generated Blackjack"):
		return
	var before_cash := run.bankroll
	var before_rows := _paid_rows(run)
	var result: Dictionary = app._sealed_action_host_resolve_intent("play_basic", STAKE)
	run = app.run_state # Observe the host-published owner, never a stale candidate.
	facts["paid_result"] = {
		"ok": result.get("ok", false), "error_code": result.get("error_code", ""),
		"action_id": result.get("action_id", ""), "stake": result.get("stake", -1),
		"currency_settlement": result.get("settlement", {}),
		"authority_receipt_digest": _digest(result.get(Authority.HOST_APPLY_RECEIPT_KEY, {})),
		"request_key": result.get(Authority.HOST_REQUEST_KEY, ""),
	}
	if not _check(bool(result.get("ok", false)), "production sealed paid settlement accepted"):
		facts["classification"] = "PAID_TRANSACTION_OR_FIXTURE_FAILURE; inspect before claiming geometry defect"
		return
	_check(int(result.get("stake", STAKE)) == STAKE, "paid stake remains exactly6")
	var witness: Dictionary = result.get("settlement", {})
	_check(not witness.is_empty() and not result.get(Authority.HOST_APPLY_RECEIPT_KEY, {}).is_empty(), "paid result has currency settlement and consumed host receipt")
	_check(str(witness.get("currency", "cash")) == "cash" and int(witness.get("delta", 0)) == run.bankroll - before_cash, "paid receipt agrees with measured cash change")
	_check(_paid_rows(run) == before_rows + 1, "current play_basic settlement story recorded once")
	var historical_net := HISTORICAL_NET if threshold_case else 0
	var observed_current_cash_net := run.bankroll - before_cash
	_check(int(_job(run).get("payload", {}).get("session_net", 0)) == historical_net + observed_current_cash_net, "synthetic history plus actual current net recorded exactly once")
	facts["accounting"] = {"synthetic_historical_net": historical_net, "current_wallet_before": before_cash, "current_wallet_after": run.bankroll, "actual_current_cash_net": observed_current_cash_net, "job_net_after": _job(run).get("payload", {}).get("session_net", 0), "not_an_earned_or_forced_current_loss": true}

	_check(bool(_job(run).get("payload", {}).get("loss_choice_pending", false)) == threshold_case, "only synthetic threshold case owns pending loss choice")
	_check(run.current_environment.get("event_ids", []).has("crew_stake_horse_loss") == threshold_case, "loss semantic event added only at threshold")
	var paid_boundary := _paid_snapshot(run)
	var full_before_stale := _digest(run.to_save_snapshot())
	var stale := GameModule.apply_result(run, result.duplicate(true))
	_check(not bool(stale.get("ok", true)) and str(stale.get("error_code", "")) == "authority_receipt_rejected", "actual accepted authority receipt cannot settle twice")
	_check(_digest(run.to_save_snapshot()) == full_before_stale, "stale duplicate leaves complete synthetic run unchanged")
	# This is the normal player return seam, not a reload or manual layout repair.
	app.back_to_environment()
	for frame in range(3): await process_frame
	_check(app.current_game == null and app.current_screen == app.SCREEN_ENVIRONMENT, "ordinary Back publishes room after settled hand")
	facts["immediate_warm_view"] = _view(app)
	_assert_event(app, threshold_case, "ordinary warm return")
	var before_repeat := _digest(run.to_save_snapshot())
	for repeat in range(2):
		var repeated := run.prepare_new_room_event_membership_for_publication(app.library)
		_check(bool(repeated.get("ok", false)) and not bool(repeated.get("changed", true)), "content publication repeats as an exact no-op")
	_check(_digest(run.to_save_snapshot()) == before_repeat, "repeated event preparation changes no owner/gameplay/persistence inputs")
	if threshold_case:
		# Synthetic negative input on a detached room; no live state, paid action,
		# resident authority key, or historical player fixture is changed.
		var rejected_run := RunState.new()
		rejected_run.current_environment = run.current_environment.duplicate(true)
		rejected_run.current_environment.layout.object_placement_hints.erase(LOSS_OBJECT)
		rejected_run.current_environment.layout.slot_binding_digest = "synthetic-invalid-proof"
		var rejected_before := var_to_bytes(rejected_run.current_environment)
		var rejected := rejected_run.prepare_new_room_event_membership_for_publication(app.library)
		_check(not bool(rejected.get("ok", true)) and var_to_bytes(rejected_run.current_environment) == rejected_before, "missing metadata cannot authorize repair of an edited slot envelope")
	var after_controls := _ordinary_controls(app)
	for object_id in base_controls:
		_check(after_controls.has(object_id), "warm room retains control " + str(object_id))
	_check(_equal(_control_geometry(app, base_controls), base_geometry), "warm event publication preserves ordinary control bindings and geometry")
	_check(_equal(_paid_snapshot(run), paid_boundary), "normal return/publication does not replay current paid settlement")
	if threshold_case and _count(app._interactable_object_view_list()) == 1:
		var before_inspection := _custody(run)
		_check(app._activate_event_object("crew_stake_horse_loss"), "actual published Crew Money opens through host callback")
		for frame in range(3): await process_frame
		var popup := app.current_event_choice_popup_snapshot()
		_check(bool(popup.get("visible", false)) and str(popup.get("event_id", "")) == "crew_stake_horse_loss", "Crew Money choice surface belongs to pending job")
		for choice_id in ["repay", "shrug"]:
			var enabled := 0
			for button in app.event_choice_popup_choices_list.find_children("*", "Button", true, false):
				if button is Button and str(button.get_meta("choice_id", "")) == choice_id and button.is_visible_in_tree() and not button.disabled: enabled += 1
			_check(enabled == 1, "one enabled ordinary choice " + choice_id)
		app._dismiss_interactable_event_popup()
		_check(_equal(_custody(run), before_inspection), "inspection/dismissal makes no loss repayment or extra wager")
	app.save_foundation_run()
	app.save_service.wait_for_async_save()
	var restored: RunState = SaveService.new().load_run(SLOT)
	_check(restored != null, "synthetic pending state saved through official service")
	if restored != null:
		_check(_equal(_custody(restored), _custody(run)), "fresh service preserves pending ownership and paid currency once")
	facts["job_id"] = job_id
	facts["historical_net_precondition"] = HISTORICAL_NET if threshold_case else 0
	facts["baseline_controls"] = base_controls
	facts["baseline_geometry"] = base_geometry
	facts["paid_boundary"] = paid_boundary
	facts["protected_after"] = _custody(run)
	facts["synthetic_Save_produced"] = restored != null
	facts["paid_result_not_forced"] = true


func _cold(app: Host) -> void:
	var expected_path := OS.get_environment("BTH_STAKE_LOSS_SYNTH_EXPECTED")
	if not _check(not expected_path.is_empty() and FileAccess.file_exists(expected_path), "warm expected receipt required"):
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	job_id = str(expected.get("facts", {}).get("job_id", ""))
	if not _check(not job_id.is_empty(), "warm receipt has synthetic pending job ID"):
		return
	if not _check(app.load_foundation_run(), "fresh native process normal Continue of private synthetic Save"):
		return
	for frame in range(3): await process_frame
	var run: RunState = app.run_state
	_check(_equal(_custody(run), expected.get("facts", {}).get("protected_after", {})), "cold preserves all selected paid/job/debt/RNG/history state")
	_assert_event(app, true, "fresh cold pending loss")
	for object_id in expected.get("facts", {}).get("baseline_controls", []):
		_check(_ordinary_controls(app).has(object_id), "cold retains ordinary control " + str(object_id))
	_check(_equal(_control_geometry(app, expected.get("facts", {}).get("baseline_controls", [])), expected.get("facts", {}).get("baseline_geometry", {})), "cold preserves ordinary control bindings and geometry")
	facts["job_id"] = job_id
	facts["protected_after"] = _custody(run)
	facts["cold_view"] = _view(app)
	facts["no_wager_result_or_choice_replayed"] = true


func _job(run: RunState) -> Dictionary:
	return run.crew_jobs.get(job_id, {}).duplicate(true)


func _paid_rows(run: RunState) -> int:
	var total := 0
	for row in run.story_log:
		if str(row.get("type", "")) == "game_action" and str(row.get("action_id", "")) == "play_basic": total += 1
	return total


func _paid_snapshot(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state),
		"paid_rows": _paid_rows(run), "spending": run.to_dict().get("run_spending_score"),
		"profile_lost": run.narrative_flags.get("profile_bankroll_lost", 0),
		"profile_won": run.narrative_flags.get("profile_bankroll_won", 0)}


func _custody(run: RunState) -> Dictionary:
	var saved := run.to_dict()
	var table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
	return {"paid": _paid_snapshot(run), "job": _job(run), "clock": run.game_clock_minutes,
		"action": run._crew_action_index(), "debt": saved.get("debt", []),
		"duties": run.crew_delivery_obligation_count(), "Crew": run.crew_reputation(),
		"Mags": run.crew_trust("crew_mags"), "rng_seed": str(run.rng_seed),
		"run_status": run.run_status, "heat": run.suspicion_level(),
		"story_money_digest": _digest(saved.get("story_money_archive", {})),
		"story_archive_count": saved.get("story_log_archive_count", 0),
		"paid_game_state_digest": _digest({"ledger": table.get(Authority.LEDGER_KEY, {}), "last_result": table.get("last_result", {})})}


func _ordinary_controls(app: Host) -> Array:
	var ids: Array = []
	for row in app._interactable_object_view_list():
		var object_id := str(row.get("object_id", ""))
		for prefix in ["game:", "service:", "lender:", "travel:", "environment_layer:"]:
			if object_id.begins_with(prefix) and not bool(row.get("room_geometry_rejected", false)):
				if not ids.has(object_id): ids.append(object_id)
	ids.sort()
	return ids


func _count(rows: Array) -> int:
	var total := 0
	for row in rows:
		if str(row.get("object_id", row.get("id", ""))) == LOSS_OBJECT: total += 1
	return total


func _control_geometry(app: Host, ids: Array) -> Dictionary:
	var layout: Dictionary = app.run_state.current_environment.get("layout", {})
	var result: Dictionary = {}
	for object_id in ids:
		result[object_id] = {"binding": layout.get("slot_bindings", {}).get(object_id, {}).duplicate(true), "rect": layout.get("object_rects", {}).get(object_id, {}).duplicate(true)}
	return result


func _view(app: Host) -> Dictionary:
	var env := app.run_state.current_environment
	var catalog := app._interactable_object_view_list()
	return {"manifest": _count(env.get("object_manifest", {}).get("rows", [])),
		"catalog": _count(catalog), "canvas": _count(app.environment_canvas.foundation_scene_objects),
		"hint": env.get("layout", {}).get("object_placement_hints", {}).get(LOSS_OBJECT, {}),
		"binding": env.get("layout", {}).get("slot_bindings", {}).get(LOSS_OBJECT, {}),
		"manifest_errors": EnvironmentInstance.object_manifest_errors(env),
		"strict_authority": app.run_state.validate_room_action_authority(),
		"base_slot_authority": EnvironmentSlotBinder.validate_base_layout_authority(env),
		"placement_errors": env.get("layout", {}).get("placement_errors", []).duplicate(true),
		"overflow_ids": env.get("layout", {}).get("slot_overflow_ids", []).duplicate(true),
		"unavailable": catalog.any(func(row): return str(row.get("object_id", "")) == "room:unavailable"),
		"job_id": job_id, "pending_loss": _job(app.run_state).get("payload", {}).get("loss_choice_pending", false)}


func _assert_event(app: Host, present: bool, label: String) -> void:
	var view := _view(app)
	var wanted := 1 if present else 0
	_check(int(view.manifest) == wanted and int(view.catalog) == wanted and int(view.canvas) == wanted, label + " exact physical/catalog/Canvas loss event count")
	_check(not bool(view.unavailable) and bool(view.strict_authority.get("ok", false)) and bool(view.base_slot_authority.get("ok", false)) and view.manifest_errors.is_empty() and view.placement_errors.is_empty(), label + " strict usable room authority")
	if present:
		_check(str(view.hint.get("asset_path", "")) == str(app.library.event("crew_stake_horse_loss").get("asset_path", "missing")) and not view.binding.is_empty(), label + " authored loss art and slot binding")
		_check(str(view.binding.get("slot_id", "")) == "event.surface_item_1" and str(view.binding.get("slot_family", "")) == "event" and str(view.binding.get("placement_class", "")) == "surface_item" and str(view.binding.get("presentation_mode", "")) == "room", label + " real authored paper slot instead of an overflow/fallback")
		_check(not app.run_state.current_environment.get("layout", {}).get("slot_overflow_ids", []).has(LOSS_OBJECT), label + " loss event is never manufactured as overflow")
		_check(str(_job(app.run_state).get("member_id", "")) == "crew_mags" and str(_job(app.run_state).get("status", "")) == "active" and bool(view.pending_loss), label + " pending event belongs to same active Mags job")


func _canonical(value: Variant) -> Variant:
	# Keep exact64-bit integers; never demote RNG/receipt numbers to binary64.
	if typeof(value) == TYPE_INT: return ["integer", str(value)]
	if typeof(value) == TYPE_FLOAT:
		if is_finite(value) and value == float(int(value)): return ["integer", str(int(value))]
		return ["float", str(value)]
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys: Array = value.keys(); keys.sort()
		for key in keys: result[str(key)] = _canonical(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value: result.append(_canonical(entry))
		return result
	return value


func _digest(value: Variant) -> String:
	return JSON.stringify(_canonical(value), "", true).sha256_text()


func _equal(a: Variant, b: Variant) -> bool:
	return _digest(a) == _digest(b)


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok


func _finish() -> void:
	facts["test_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	facts["candidate_source_sha256"] = {}
	for path in ["res://scripts/core/run_state.gd", "res://scripts/ui/foundation_main.gd", "res://data/environments/placement_surfaces.json"]:
		facts["candidate_source_sha256"][path] = FileAccess.get_sha256(path)
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
	print("CREW_STAKE_LOSS_SYNTHETIC checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
