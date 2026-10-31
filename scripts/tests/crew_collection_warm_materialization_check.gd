extends "res://scripts/tests/crew_handoff_warm_publication_check.gd"

const COLLECTION_JOB := "knuckles_friendly_collection:0004"
const SECOND_ASK := "event:crew_collection_press"

class RejectedPublicationRun extends RunState:
	var rejected_publications := 0
	func prepare_current_environment_object_membership_for_publication() -> Dictionary:
		rejected_publications += 1
		return {"ok": false, "errors": ["synthetic collection publication rejection"]}

# Captured accepted job -> one pickup, one quoted trip, one normal handoff.
# Stop before either collection choice: the existing settled receipt is never
# replayed. Other modes only Continue their own disposable captured/save copy.
func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-collection-warm001-"), "isolated collection data root required"): _finish(); return
	var mode := OS.get_environment("BTH_COLLECTION_WARM001_MODE")
	if not _check(mode in ["warm", "cold", "recovered", "settled"], "explicit collection regression mode required"): _finish(); return
	if mode != "cold": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official copied-state load"): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal host Continue"): app.queue_free(); _finish(); return
	for frame in range(3): await process_frame
	var run: RunState = app.run_state
	facts = {"mode": mode, "fidelity": "Captured copies through normal host APIs. Warm does one pickup/trip/handoff and never selects friendly/press. Cold/recovered/settled load only; no completed settlement replay.", "before": _collection_view(app)}
	_check(_different_paths(_protected(baseline), _protected(run)).is_empty(), "Continue preserves protected state")
	if mode == "warm":
		_check(run.bankroll == 55 and run.current_world_node_id() == "small_underground_casino" and run._crew_action_index() == 42, "genuine accepted55cash/action42 checkpoint")
		_check(_job(run).get("status", "") == "active" and not bool(_job(run).get("payload", {}).get("press_choice_pending", false)), "same accepted collection awaiting pickup")
		if failures.is_empty():
			_check(app._activate_delivery_physical_action("pickup"), "one normal pickup callback")
			var quote := app._travel_choice("kitty_cat_lounge")
			_check(bool(quote.get("enabled", false)) and int(quote.get("cost", -1)) == 14 and int(quote.get("travel_minutes", -1)) == 30, "original ordinary Lounge14/30 quote")
			facts["quote"] = {"cost": quote.get("cost"), "minutes": quote.get("travel_minutes")}
			if failures.is_empty():
				_check(app.open_world_map() and app.select_world_map_node("kitty_cat_lounge"), "normal map route selection")
				var trip := app.confirm_world_map_travel()
				_check(bool(trip.get("ok", false)), "one ordinary Lounge trip")
				for frame in range(3): await process_frame
				_check(run.bankroll == 41 and run.current_world_node_id() == "kitty_cat_lounge", "fare charged once at genuine destination")
				_check(not run.current_environment.get("layout", {}).get("object_placement_hints", {}).has(SECOND_ASK), "Second Ask not materialized before handoff")
				var invariant := _handoff_invariants(run)
				var owners := _owner_states(run)
				var scenario: Dictionary = run.current_environment.get("scenario_sequence_state", {}).duplicate(true)
				var prior_room_ids := _unrelated_room_ids(run.current_environment)
				if failures.is_empty():
					var wrong_target_before := _protected(run)
					_check(not bool(run.delivery_complete_handoff("synthetic-not-current-room").get("ok", true)), "omitted-library API still rejects wrong target without action")
					_check(_different_paths(wrong_target_before, _protected(run)).is_empty(), "wrong-target optional-argument control preserves state")
					# Detached synthetic failure seam, never the live/captured branch:
					# force the existing publication rejection after the metadata refresh.
					var rejected_run := RejectedPublicationRun.new()
					rejected_run.from_dict(run.to_dict())
					var rejection_before := rejected_run.to_dict()
					var rejection_calls_before := rejected_run.rejected_publications
					var rejected := rejected_run.delivery_complete_handoff("kitty_cat_lounge", app.library)
					_check(rejected_run.rejected_publications > rejection_calls_before and not bool(rejected.get("ok", true)) and rejected.get("errors", []).has("synthetic collection publication rejection"), "strict membership failure reaches original rejection branch")
					_check(_different_paths(rejection_before, rejected_run.to_dict()).is_empty(), "publication failure rolls back complete detached run and room aliases")
					facts["synthetic_rollback_control"] = {"rejections_before": rejection_calls_before, "rejections_after": rejected_run.rejected_publications, "errors": rejected.get("errors", []), "ok": rejected.get("ok"), "no_live_branch_action": true}
					_check(app._complete_delivery_handoff("kitty_cat_lounge"), "one normal Hand Over The Package callback")
					# Inspect immediately; do not add another preparation/Continue that
					# could conceal the original missing-hint publication failure.
					facts["immediate_after_handoff"] = _collection_view(app)
					_assert_second_ask(app, true, "warm handoff")
					var after_room_ids := _unrelated_room_ids(run.current_environment)
					facts["prior_unrelated_room_ids"] = prior_room_ids
					facts["after_unrelated_room_ids"] = after_room_ids
					for object_id in prior_room_ids: _check(after_room_ids.has(object_id), "handoff retains prior physical room record " + str(object_id))
					_check(_handoff_invariants(run) == invariant, "handoff changes no funds/clock/action/finance/paid game/root RNG/trust")
					_check(_owner_states(run) == owners and run.current_environment.get("scenario_sequence_state", {}) == scenario, "existing scenario and mounted owner state unchanged")
					_check(str(run.active_delivery_run.get("status", "")) == "resolved" and bool(run.active_delivery_run.get("world_applied", false)), "delivery resolution committed once")
					_check(_job(run).get("status", "") == "active" and bool(_job(run).get("payload", {}).get("press_choice_pending", false)), "job awaits final choice without payout")
					var stable := _protected(run)
					_check(not app._complete_delivery_handoff("kitty_cat_lounge"), "stale handoff callback rejected")
					_check(_different_paths(stable, _protected(run)).is_empty(), "stale callback cannot repeat consequences")
					for repeat in range(2): app._prepare_room_presentation_at_boundary()
					_assert_second_ask(app, true, "repeated read/presentation boundary")
					_check(_different_paths(stable, _protected(run)).is_empty(), "repeated presentation changes no gameplay")
	elif mode == "settled":
		_check(run.bankroll == 60 and _job(run).get("status", "") == "resolved" and _job(run).get("outcome", "") == "success", "genuine settled60cash job stays resolved")
		_assert_second_ask(app, false, "settled Continue")
		_check(_different_paths(_protected(baseline), _protected(run)).is_empty(), "settled receipt is not replayed on Continue")
	else:
		_check(run.bankroll == 41 and _job(run).get("status", "") == "active" and bool(_job(run).get("payload", {}).get("press_choice_pending", false)), "pending41cash state remains unpaid")
		_assert_second_ask(app, true, "cold/recovered Continue")
		if mode == "cold":
			var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_COLLECTION_WARM001_EXPECTED")))
			_check(_different_paths(expected.get("facts", {}).get("protected_after", {}), _protected(run)).is_empty(), "independent process preserves exact pending state")
	var tampered := run.current_environment.duplicate(true)
	tampered["scenario_layout_authority_digest"] = "synthetic-invalid-proof"
	_check(not bool(HandoffPublication.validate(tampered).get("ok", true)), "strict renderer authority tamper remains rejected")
	if mode != "settled" and failures.is_empty():
		var before_inspection := _protected(run)
		_check(app._activate_event_object("crew_collection_press"), "ordinary Second Ask opening callback")
		for frame in range(3): await process_frame
		var popup := app.current_event_choice_popup_snapshot()
		facts["choice_inspection"] = {"visible": popup.get("visible", false), "event_id": popup.get("event_id", ""), "choice_ids": popup.get("choice_ids", [])}
		_check(bool(popup.get("visible", false)) and str(popup.get("event_id", "")) == "crew_collection_press", "normal collection choice surface opens")
		for choice_id in ["friendly", "press"]:
			var enabled_buttons := 0
			for button in app.event_choice_popup_choices_list.find_children("*", "Button", true, false):
				if button is Button and str(button.get_meta("choice_id", "")) == choice_id and button.is_visible_in_tree() and not button.disabled: enabled_buttons += 1
			_check(enabled_buttons == 1, "one enabled normal choice control " + choice_id)
		app._dismiss_interactable_event_popup()
		_check(_different_paths(before_inspection, _protected(run)).is_empty(), "inspection and neutral close do not resolve/pay/advance")
	if mode != "cold":
		app.save_foundation_run()
		app.save_service.wait_for_async_save()
		var restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
		_check(restored != null and _different_paths(_protected(run), _protected(restored)).is_empty(), "normal Save/fresh service preserves state without settlement")
	facts["protected_after"] = _protected(run)
	facts["after"] = _collection_view(app)
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _job(run: RunState) -> Dictionary:
	return run.crew_jobs.get(COLLECTION_JOB, {}).duplicate(true)


func _protected(run: RunState) -> Dictionary:
	var result := super._protected(run)
	# Add collection-specific clock/receipt boundaries to the inherited paid
	# asset/finance/history coverage; do not relax any inherited comparisons.
	var saved := run.to_dict()
	for key in ["game_clock_minutes", "story_money_archive", "story_log_archive_count"]: result[key] = saved.get(key)
	result["crew_action_index"] = run._crew_action_index()
	return result


func _handoff_invariants(run: RunState) -> Dictionary:
	var protected := _protected(run)
	var result := {"clock": run.game_clock_minutes, "action": run._crew_action_index(), "Crew": run.crew_reputation(), "Knuckles": run.crew_trust("crew_knuckles"), "duties": run.crew_delivery_obligation_count()}
	for key in ["bankroll", "grand_casino_chips", "debt", "grand_casino_atm_debt", "suspicion", "rng_seed", "rng_state", "run_spending_score", "run_status", "game_states", "scratch_paid"]:
		result[key] = protected.get(key)
	return result


func _collection_count(rows: Array) -> int:
	var count := 0
	for row in rows:
		if str(row.get("object_id", row.get("id", ""))) == SECOND_ASK: count += 1
	return count


func _unrelated_room_ids(environment: Dictionary) -> Array:
	var result: Array = []
	for row in environment.get("object_manifest", {}).get("rows", []):
		if not bool(row.get("active", true)) or not bool(row.get("physical", true)): continue
		var object_id := str(row.get("presentation_object_id", row.get("object_id", row.get("id", ""))))
		if object_id.is_empty() or object_id == SECOND_ASK or object_id == HANDOFF_ID or object_id.begins_with("delivery:"): continue
		result.append(object_id)
	result.sort()
	return result


func _collection_view(app: Host) -> Dictionary:
	var env := app.run_state.current_environment
	var catalog := app._interactable_object_view_list()
	var unavailable := catalog.any(func(row): return str(row.get("object_id", "")) == "room:unavailable")
	return {"cash": app.run_state.bankroll, "clock": app.run_state.game_clock_minutes, "manifest": _collection_count(env.get("object_manifest", {}).get("rows", [])), "hint": env.get("layout", {}).get("object_placement_hints", {}).get(SECOND_ASK, {}), "binding": env.get("layout", {}).get("slot_bindings", {}).get(SECOND_ASK, {}), "catalog": _collection_count(catalog), "canvas": _collection_count(app.environment_canvas.foundation_scene_objects), "unavailable": unavailable, "job": _job(app.run_state)}


func _assert_second_ask(app: Host, present: bool, label: String) -> void:
	var view := _collection_view(app)
	var expected := 1 if present else 0
	_check(int(view.manifest) == expected and int(view.catalog) == expected and int(view.canvas) == expected, label + " exact physical/catalog/Canvas presence")
	_check(not bool(view.unavailable) and bool(app.run_state.validate_room_action_authority().get("ok", false)), label + " strict usable room")
	if present:
		_check(str(view.hint.get("asset_path", "")) == str(app.library.event("crew_collection_press").get("asset_path", "missing")) and not view.binding.is_empty(), label + " authored art hint and sealed binding")
		var ids: Array = app._interactable_object_view_list().map(func(row): return str(row.get("object_id", "")))
		for id in ["game:bar_dice", "game:roulette", "game:slot", "service:kitty_champagne", "travel:leave"]:
			_check(ids.has(id), label + " retains normal room attachment " + id)


func _finish() -> void:
	facts["test_sha256"] = FileAccess.get_sha256("res://scripts/tests/crew_collection_warm_materialization_check.gd")
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
	print("CREW_COLLECTION_WARM001 checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
