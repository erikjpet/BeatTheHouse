extends SceneTree

# Synthetic connected Crew preview/neutral Close, plus official SaveService
# warm -> fresh-process cold in the SAME private root. Warm previews only;
# cold also confirms one synthetic loan. No genuine R02 input or key transfer.
const Probe := preload("res://scripts/tests/grand_explicit_qa/grand_explicit_host_probe.gd")
const Dock := preload("res://scripts/ui/talk_dock.gd")
const LENDER := "the_crew"
const EVENT := "lender_conversation:borrow:the_crew"
const SLOT := "synthetic_crew_lender_reopen"
const EXPECTED := "user://synthetic_lender_reopen_public_expectation.json"

var app: Probe
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"confirmed_synthetic_accept_inputs": 0, "paid_inputs": 0, "profile_import_or_explicit_test_key_access": false}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("BTH_LENDER_REOPEN_MODE")
	var private_root := OS.get_environment("BTH_LENDER_REOPEN_PRIVATE_ROOT").replace("\\", "/").to_lower().trim_suffix("/")
	if not _check(mode in ["warm", "cold", "cold_diagnostic"] and private_root.contains("/native-private-lender-retalk-") and ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().begins_with(private_root + "/"), "explicit synthetic mode and resident private root required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured or browser profile input"):
		_finish(); return
	var source_root := ProjectSettings.globalize_path("res://").replace("\\", "/").to_lower().trim_suffix("/")
	if not _check(source_root == OS.get_environment("BTH_LENDER_REOPEN_SOURCE_ROOT").replace("\\", "/").to_lower().trim_suffix("/") and source_root.ends_with("/source-crew-lender-retalk-439"), "exact isolated candidate source required"):
		_finish(); return
	root.size = Vector2i(1280, 720)
	app = Probe.new()
	app.autosave_slot_id = SLOT
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	if not _check(app._ensure_run_ui_built(), "real run UI constructed"):
		await _cleanup(); _finish(); return
	app._ensure_full_content_library_loaded()
	if not _check(app.library != null and app.library.validation_errors.is_empty(), "actual content library loaded"):
		await _cleanup(); _finish(); return
	if mode == "warm":
		if not await _prepare_room():
			await _cleanup(); _finish(); return
		await _warm()
	else:
		await _cold()
	facts["mode"] = mode
	facts["save_request_spies"] = {"direct": app.qa_save_requests, "queued": app.qa_save_queue_requests}
	await _cleanup()
	_finish()

func _prepare_room() -> bool:
	var run := RunState.new()
	run.start_new("SYNTHETIC-LENDER-REOPEN-43971", {"id": "synthetic_lender_reopen", "tutorial": false})
	run.bankroll = 100
	var archetype: Dictionary = app.library.environment_archetype("back_alley")
	if not _check(not archetype.is_empty(), "authored Back Alley exists"):
		return false
	var rng := run.create_rng()
	var generated := EnvironmentInstance.from_archetype(archetype, 0, rng, app.library, run.challenge_config)
	run.save_rng(rng)
	run.set_environment(generated.to_dict())
	# Normal Continue initializes this venue-local zero; establish it before Save.
	run._store_current_local_suspicion()
	run._refresh_economy(true)
	var membership: Dictionary = run.prepare_current_environment_object_membership_for_publication()
	if not _check(bool(membership.get("ok", false)), "normal authoritative membership preparation admitted"):
		return false
	app.run_state = run
	app.meta_session_active = false
	app.current_game = null
	app._reset_game_surface_runtime_state()
	app._set_current_screen(app.SCREEN_ENVIRONMENT)
	app._configure_coach_for_run()
	app._refresh_runtime_environment_views()
	app._refresh_run_action_service()
	app._refresh()
	await _frames(5)
	return _check(bool(run.validate_room_action_authority().get("ok", false)) and not app._interactable_object("lender:" + LENDER).is_empty(), "strict room authority and actual Crew lender object exist")

func _warm() -> void:
	if not await _open_use(): return
	if not await _close(): return
	var run: RunState = app.run_state
	var before: Array = _typed(_public_guard(run))
	var journal: Array = _typed(run.narrative_flags.get("neutral_dialogue_dismissals", {}))
	_check(run.bankroll == 100 and run.suspicion_level() == 0 and run.crew_delivery_obligation_count() == 0, "preview and neutral Close grant no cash or obligations")
	_check(run.neutral_talk_dismissed_at_current_boundary(EVENT), "neutral Close records automatic suppression at this boundary")
	_check(not app._start_lender_conversation(LENDER, "borrow") and run.pending_talk_event(EVENT).is_empty(), "default automatic lender retry stays suppressed")
	_check(_typed(_public_guard(run)) == before, "automatic rejection preserves measured causal state")
	if not await _open_use(): return
	_check(_typed(run.narrative_flags.get("neutral_dialogue_dismissals", {})) == journal, "explicit retry preserves the dismissal journal")
	_check(_typed(_public_guard(run)) == before, "deliberate retry preserves cash/debt/inventory/obligations/history/clock/RNG")
	var queued := run.pending_talk_event_count()
	_check(app._start_lender_conversation(LENDER, "borrow") and run.pending_talk_event_count() == queued, "already-open preview does not duplicate the queue")
	_check(not run.enqueue_triggered_event(EVENT, "lender", {"source": "event_object"}, {"presentation": "talk"}), "manual marker does not bypass duplicate protection")
	if not await _close(): return
	_check(_typed(_public_guard(run)) == before, "second neutral Close has no transaction effect")
	_check(not app._start_lender_conversation(LENDER, "borrow"), "automatic preview still cannot loop after the second Close")
	var service := SaveService.new()
	if not _check(service.save_run(run, SLOT) == OK, "official synchronous SaveService saves this synthetic closed preview"):
		return
	var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
	if not _check(file != null, "public synthetic expectation file created"):
		return
	file.store_string(JSON.stringify({"public_guard": _typed(_public_guard(run)), "journal": _typed(JSON.parse_string(JSON.stringify(run.narrative_flags.get("neutral_dialogue_dismissals", {}))))}))
	file.close()
	_core_guard_controls()
	facts["journal_cold_reference"] = "Exact JSON wire types for this dismissal journal only; live journal and all other public guards remain type/bit exact."
	facts["warm_Save"] = "Official SaveService in its original resident-key root; not a browser Save claim."

func _cold() -> void:
	if not _check(FileAccess.file_exists(EXPECTED), "warm expectation exists in same root, not imported"):
		return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	if not _check(typeof(expected) == TYPE_DICTIONARY and app.load_foundation_run(), "fresh process uses ordinary Continue of the warm synthetic slot"):
		return
	await _frames(5)
	var run: RunState = app.run_state
	_check(bool(run.validate_room_action_authority().get("ok", false)), "restored room retains strict action authority")
	_check(run.pending_talk_event(EVENT).is_empty() and run.neutral_talk_dismissed_at_current_boundary(EVENT), "cold Continue preserves neutral dismissal, no unsolicited preview")
	facts["cold_public_differences"] = _diffs(expected.get("public_guard", []), _typed(_public_guard(run)))
	facts["cold_journal_differences"] = _diffs(expected.get("journal", []), _typed(run.narrative_flags.get("neutral_dialogue_dismissals", {})))
	_check(_typed(_public_guard(run)) == expected.get("public_guard", []), "cold preserves selected public financial/history/clock/RNG fields exactly")
	_check(_typed(run.narrative_flags.get("neutral_dialogue_dismissals", {})) == expected.get("journal", []), "cold retains exact journal fields/values and normal JSON numeric types")
	if OS.get_environment("BTH_LENDER_REOPEN_MODE") == "cold_diagnostic" or not failures.is_empty(): return
	_check(not app._start_lender_conversation(LENDER, "borrow"), "restored automatic/default request remains suppressed")
	var before: Array = _typed(_public_guard(run))
	if not await _open_use(): return
	_check(_typed(_public_guard(run)) == before, "actual cold connected Use does not accept, charge or grant anything")
	if not await _close(): return
	_check(_typed(_public_guard(run)) == before, "cold neutral Close preserves measured state")
	if not await _open_use(): return
	if not await _accept_once(): return
	facts["cold_scope"] = "Synthetic own-root fresh-process Continue and connected controls; no genuine R02 acceptance or full-world raw-equality claim."

func _accept_once() -> bool:
	var run: RunState = app.run_state
	if not _check(run.bankroll == 100 and run.crew_delivery_obligation_count() == 0, "synthetic fixture remains unaccepted before its one confirmation"):
		return false
	var before: Array = _typed(_public_guard(run))
	var accept := _accept_button()
	if not _check(accept != null and not accept.disabled and accept.is_visible_in_tree(), "visible synthetic Accept can be armed"):
		return false
	accept.pressed.emit()
	await _frames(3)
	_check(app.talk_dock.armed_choice_id == "accept" and _typed(_public_guard(run)) == before, "arming confirmation has no financial/history/RNG effect")
	var confirm := _accept_button()
	if not _check(confirm != null and confirm.text.begins_with("Confirm:") and not confirm.disabled, "actual TalkDock confirmation is required"):
		return false
	facts["confirmed_synthetic_accept_inputs"] = 1
	confirm.pressed.emit()
	await _frames(8)
	if not _check(run.bankroll == 170 and run.crew_delivery_obligation_count() == 2 and run.pending_talk_event(EVENT).is_empty(), "one confirmed synthetic Crew loan grants70 and two duties once"):
		return false
	var settled: Array = _typed(_public_guard(run))
	app._on_talk_dock_choice_requested(EVENT, "accept")
	await _frames(3)
	_check(_typed(_public_guard(run)) == settled, "stale accepted-choice callback cannot replay grant/duties/history/RNG")
	var service := SaveService.new()
	if not _check(service.save_run(run, SLOT + "_accepted") == OK, "official SaveService persists synthetic accepted settlement"):
		return false
	var restored: Variant = SaveService.new().load_run(SLOT + "_accepted")
	if not _check(restored is RunState, "fresh service restores accepted settlement without a second input"):
		return false
	_check(restored.bankroll == 170 and restored.crew_delivery_obligation_count() == 2 and _typed(_public_guard(restored)) == settled, "accepted settlement restores once with measured state unchanged")
	facts["synthetic_settlement"] = {"cash": run.bankroll, "duties": run.crew_delivery_obligation_count(), "stale_callback_inputs": 1, "same_process_fresh_service_restore": true}
	return true

func _accept_button() -> Button:
	var buttons: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("event_id", "")) == EVENT and str(button.get_meta("choice_id", "")) == "accept")
	return buttons[0] as Button if buttons.size() == 1 else null

func _open_use() -> bool:
	if not _check(app.select_lender_hook(LENDER), "actual Crew object selection succeeds"):
		return false
	var card := VBoxContainer.new()
	root.add_child(card)
	app._add_context_lender_actions(card, LENDER)
	var buttons: Array = card.find_children("*", "Button", true, false).filter(func(button): return str(button.text).begins_with("Use "))
	if not _check(buttons.size() == 1 and not buttons[0].disabled, "one enabled connected Use control is rendered"):
		card.queue_free(); return false
	buttons[0].pressed.emit()
	await _frames(4)
	card.queue_free()
	var entry: Dictionary = app.run_state.pending_talk_event(EVENT)
	if not _check(not entry.is_empty() and app.talk_dock.conversation_active and app.talk_dock.is_visible_in_tree(), "deliberate connected Use opens a visible lender conversation"):
		return false
	var context: Dictionary = entry.get("context", {})
	_check(str(entry.get("source", "")) == "lender" and str(context.get("source", "")) == "event_object", "semantic lender source and explicit input marker coexist")
	_check(str(context.get("lender_id", "")) == LENDER and str(context.get("lender_mode", "")) == "borrow" and str(context.get("source_object_id", "")) == "lender:" + LENDER, "offer mode and original object identity preserved")
	var accept: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("event_id", "")) == EVENT and str(button.get_meta("choice_id", "")) == "accept")
	return _check(accept.size() == 1 and not accept[0].disabled and accept[0].is_visible_in_tree(), "actual Accept Offer control is available; preview helper does not press it")

func _close() -> bool:
	var button: Button = app.talk_dock.collapse_button
	if not _check(button != null and button.text == "Close" and not button.disabled and button.is_visible_in_tree(), "one enabled actual header neutral Close exists"):
		return false
	button.pressed.emit()
	await _frames(4)
	return _check(app.run_state.pending_talk_event(EVENT).is_empty() and not app.talk_dock.conversation_active, "neutral Close retires this preview without an outcome")


func _core_guard_controls() -> void:
	var full := RunState.new()
	full.start_new("SYNTHETIC-LENDER-CAPACITY", {})
	for index in range(RunState.MAX_PENDING_TRIGGERED_EVENTS):
		_check(full.enqueue_triggered_event("capacity_fixture_%d" % index, "synthetic", {}, {"presentation": "modal"}), "synthetic capacity slot admitted")
	_check(not full.enqueue_triggered_event(EVENT, "lender", {"source": "event_object"}, {"presentation": "talk"}), "manual intent does not bypass queue capacity")
	var terminal := RunState.new()
	terminal.start_new("SYNTHETIC-LENDER-TERMINAL", {})
	terminal.run_status = RunState.RUN_STATUS_ENDED
	_check(terminal.is_terminal() and not terminal.enqueue_triggered_event(EVENT, "lender", {"source": "event_object"}, {"presentation": "talk"}), "manual intent does not bypass terminal talk rejection")

func _public_guard(run: RunState) -> Dictionary:
	var raw := run.to_dict()
	var result: Dictionary = {}
	for key in ["rng_seed", "rng_state", "bankroll", "grand_casino_chips", "grand_casino_atm_debt", "inventory", "portable_ticket_piles", "active_item_id", "debt", "suspicion", "drunk_level", "pending_drunk_absorption", "event_cadence", "story_flags", "story_log", "story_log_archive_count", "story_money_archive", "heat_history", "act", "act_index", "game_clock_minutes", "run_status", "run_failure_reason", "run_spending_score", "active_delivery_run"]:
		if not raw.has(key): _check(false, "required authoritative observable missing: " + str(key))
		result[key] = raw.get(key)
	result["environment_id"] = str(run.current_environment.get("id", ""))
	result["game_states"] = run.current_environment.get("game_states", {}).duplicate(true)
	result["delivery_obligation_count"] = run.crew_delivery_obligation_count()
	return result

func _typed(value: Variant) -> Array:
	match typeof(value):
		TYPE_NIL: return ["nil"]
		TYPE_BOOL: return ["bool", "true" if value else "false"]
		TYPE_INT: return ["int", str(value)]
		TYPE_FLOAT:
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, float(value))
			return ["float64", bytes.hex_encode()]
		TYPE_STRING: return ["string", str(value)]
		TYPE_STRING_NAME: return ["string_name", str(value)]
		TYPE_ARRAY:
			var items: Array = []
			for child in value: items.append(_typed(child))
			return ["array", items]
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var items: Array = []
			for key in keys: items.append([_typed(key), _typed(value[key])])
			return ["dictionary", items]
	_check(false, "unsupported non-JSON observable type: " + str(typeof(value)))
	return ["unsupported", str(typeof(value))]

func _diffs(expected: Variant, actual: Variant, path: String = "root") -> Array:
	var differences: Array = []
	if typeof(expected) == TYPE_ARRAY and typeof(actual) == TYPE_ARRAY:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(mini(expected.size(), actual.size())):
			differences.append_array(_diffs(expected[index], actual[index], path + "/" + str(index)))
	elif typeof(expected) != typeof(actual) or expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _cleanup() -> void:
	if app != null:
		if app.save_service != null: app.save_service.wait_for_async_save()
		app.queue_free()
		await _frames(3)

func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: failures.append(message)
	return condition

func _finish() -> void:
	print("CREW_LENDER_MANUAL_REOPEN_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "connected_callback_only": true, "physical_pointer_or_Web_qualified": false}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
