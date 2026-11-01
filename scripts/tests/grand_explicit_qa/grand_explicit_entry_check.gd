extends SceneTree

# Derived connected-control regression; original failing e53 tests are retained.
# Never imports a captured profile or reads/copies/hashes an authority key.
const Probe := preload("res://scripts/tests/grand_explicit_qa/grand_explicit_host_probe.gd")
const Dock := preload("res://scripts/ui/talk_dock.gd")
const Resolver := preload("res://scripts/core/collection_item_resolver.gd")
const Meta := preload("res://scripts/core/meta_collection_service.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const SOURCE_COMMIT := "e53eb65725fb387ed0b97761e23ea6bb77e47713"
const COMPARISON_TREE := "661c272eb8a658cf429564addd6b4aec85b41966"
const CAGE := "dialogue:linda_cage_services"
const COUNTER := "casino_fixture:cage_counter"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"phase": "setup", "classification": "UNEXECUTED", "transaction_inputs": 0, "card_award_inputs": 0}
var app
var cards: Array = []

func _init() -> void:
	call_deferred("_run")

func _case_id() -> String:
	return "invalid"

func _run() -> void:
	if not _private_scope():
		_finish()
		return
	root.size = Vector2i(1280, 720)
	app = Probe.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	if not _check(app._ensure_run_ui_built(), "real run UI constructed"):
		await _cleanup(); _finish(); return
	app._ensure_full_content_library_loaded()
	if not _check(app.library != null and app.library.is_fully_loaded() and app.library.validation_errors.is_empty(), "real full library loaded"):
		await _cleanup(); _finish(); return
	if app.meta_collection_service == null:
		app._initialize_meta_collection()
	if not _check(app.profile_inventory != null and app.meta_collection_service != null, "fresh private profile/collection services exist"):
		await _cleanup(); _finish(); return
	if not _check(_players_card_count() == 0, "fresh fixture has no Players Card allocation"):
		await _cleanup(); _finish(); return
	var prepared := false
	if _case_id() in ["sal_talk", "sal_resume"]:
		prepared = await _prepare_sal(_case_id() == "sal_resume")
	else:
		prepared = await _prepare_bronze()
	if not prepared:
		facts["classification"] = "SETUP_ADMISSION_FAILED"
		await _cleanup(); _finish(); return
	await _frames(4)
	if not _check(_players_card_count() == 0 and app.run_state.run_status == RunState.RUN_STATUS_ACTIVE, "setup has no card allocation or terminal outcome"):
		await _cleanup(); _finish(); return
	facts["phase"] = "measured_connected_controls"
	facts["classification"] = "MEASUREMENT_STARTED"
	if _case_id() == "bronze_resume":
		await _bronze_measurement()
	elif _case_id() == "counter_manual":
		await _counter_measurement()
	else:
		await _sal_measurement()
	facts["save_spies"] = {"direct": app.qa_save_requests, "queued": app.qa_save_queue_requests}
	facts["meta_players_card_instances_after"] = _players_card_count()
	if failures.is_empty(): facts["classification"] = "PASS_SYNTHETIC_CONNECTED_CONTROL"
	await _cleanup()
	_finish()

func _private_scope() -> bool:
	var private_root := OS.get_environment("BTH_GRAND_EXPLICIT_PRIVATE_ROOT").replace("\\", "/").to_lower().trim_suffix("/")
	var source_root := ProjectSettings.globalize_path("res://").replace("\\", "/").to_lower().trim_suffix("/")
	var expected_source := OS.get_environment("BTH_GRAND_EXPLICIT_SOURCE_ROOT").replace("\\", "/").to_lower().trim_suffix("/")
	if not _check(OS.get_environment("BTH_GRAND_EXPLICIT_SCOPE") == "entry_native_v1" and _case_id() == OS.get_environment("BTH_GRAND_EXPLICIT_CASE") and _case_id() in ["sal_talk", "sal_resume", "bronze_resume", "counter_manual"], "explicit synthetic case/scope required"):
		return false
	if not _check(not private_root.is_empty() and private_root.contains("/native-private-") and source_root == expected_source and source_root.ends_with("/source-explicit-dialogue-intent-661c"), "matching isolated source and private roots"):
		return false
	for env_name in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "TEMP", "TMP", "BTH_SAVE_DIR", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path := OS.get_environment(env_name).replace("\\", "/").to_lower().trim_suffix("/")
		if not _check(path == private_root or path.begins_with(private_root + "/"), "private environment root: " + env_name): return false
	if not _check(ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().begins_with(private_root + "/"), "engine user root is private"):
		return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured or browser profile input")

func _prepare_sal(pending: bool) -> bool:
	var entered: Dictionary = app._enter_meta_location(app._meta_pawn_location_id())
	if not _check(bool(entered.get("ok", false)) and app._is_meta_session(), "real pawn meta location entered"):
		return false
	await _frames(4)
	if not _check(app.meta_collection_service.pending_starter_buyback().is_empty(), "new private collection starts without pending offer"):
		return false
	if pending:
		var resolver := Resolver.new()
		var instance: Dictionary = app.meta_collection_service.grant_instance(resolver.roll_instance(1000, "SYNTHETIC-NATIVE-SAL-ENTRY"))
		if not _check(int(instance.get("itemdef_id", -1)) == 1000, "synthetic setup item is ordinary collection1000, not Players Card"):
			return false
		var quote: Dictionary = app.meta_collection_service.ordinary_collection_price_breakdown(instance, Meta.LISTING_MODE_STARTER_BUYBACK)
		if not _check(bool(quote.get("ok", false)), "real buyback quote supports synthetic pending fixture"):
			return false
		var store: Dictionary = app.meta_collection_service.snapshot()
		var resale: Dictionary = JsonCoerceScript._copy_dict(store.get("sal_resale", {}))
		var slots: Array = JsonCoerceScript._copy_array(resale.get("slots", []))
		if not _check(not slots.is_empty(), "real default Sal shelf exists"):
			return false
		var empty_slot: Dictionary = JsonCoerceScript._copy_dict(slots[0])
		empty_slot["occupied"] = false
		empty_slot["item"] = {}
		slots[0] = empty_slot
		resale["slots"] = slots
		resale["starter_tutorial_resolved"] = false
		resale["pending_starter_buyback"] = {
			"instance_id": int(instance.get("instance_id", 0)), "item": instance.duplicate(true),
			"original_slot_index": 0, "pawn_quote": int(quote.get("pawn_quote", 0)),
			"offer_price": int(quote.get("final_price", 0)), "rare_channel": "potency",
			"rare_value": float(instance.get("potency", 0.0)), "resolved": false,
			"provenance": {"source": "synthetic_native_entry_fixture"},
		}
		app.meta_collection_service._store["sal_resale"] = resale
		app.meta_session_controller.invalidate_cache()
		var published: Dictionary = app._apply_meta_environment(app._meta_pawn_location_id())
		if not _check(bool(published.get("ok", false)), "pending synthetic fixture republishes real pawn view"):
			return false
		facts["fixture_setup"] = "One ordinary synthetic item grant and pending metadata before baseline; no purchase/buyback/card award. Acquisition not qualified."
	else:
		facts["fixture_setup"] = "Fresh empty private collection; no grants or purchase."
	app.run_state._refresh_economy(true)
	app._refresh()
	await _frames(4)
	return _check((not app.meta_collection_service.pending_starter_buyback().is_empty()) == pending, "pending-offer fixture matches selected case")

func _prepare_bronze() -> bool:
	var run := RunState.new()
	run.start_new("SYNTHETIC-NATIVE-BRONZE-ENTRY", {"id": "synthetic_bronze_resume", "tutorial": true})
	run.bankroll = 71
	run.grand_casino_chips = 25
	var archetype: Dictionary = app.library.environment_archetype(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	var fixture_rng := run.create_rng()
	var generated := EnvironmentInstance.from_archetype(archetype, 0, fixture_rng, app.library, run.challenge_config)
	run.save_rng(fixture_rng)
	run.set_environment(generated.to_dict())
	for key in ["grand_casino_players_card_tier", "grand_casino_players_card_highest_tier", "grand_casino_players_card_awarded_tier"]:
		run.narrative_flags[key] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	run.narrative_flags["grand_casino_players_card_bronze_benefits_granted"] = true
	run.narrative_flags["grand_casino_comp_drink_tokens"] = 1
	var completed: Dictionary = {}
	for value in app.library.tutorial_lessons:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("scope", "")) == "tutorial_run": completed[str(value.get("id", ""))] = true
	run.narrative_flags["tutorial_lessons_completed"] = completed
	run._refresh_economy(true)
	var membership: Dictionary = run.prepare_current_environment_object_membership_for_publication()
	if not _check(bool(membership.get("ok", false)), "synthetic Cage membership admitted"):
		return false
	app.run_state = run
	app.meta_session_active = false
	app.current_game = null
	app._reset_game_surface_runtime_state()
	app._set_current_screen(app.SCREEN_ENVIRONMENT)
	app._configure_coach_for_run()
	app._refresh_runtime_environment_views()
	await _frames(5)
	facts["fixture_setup"] = "Synthetic tutorial/Bronze/curriculum metadata only; no tier-grant, Players Card allocation or finale method. Real guards retained."
	return _check(run.is_tutorial_run() and str(run.demo_objective_status().get("players_card_tier", "")) == "bronze" and not bool(run.narrative_flags.get("demo_victory", false)), "real tutorial/Bronze/no-victory prerequisite")

func _sal_measurement() -> void:
	var id := "dialogue:sal_starter_offer" if _case_id() == "sal_resume" else "dialogue:sal_shop_talk"
	var dialogue := "sal_starter_offer" if _case_id() == "sal_resume" else "sal_shop_talk"
	var before := _protected([id])
	if not (await _context_press("meta_sal:talk", "Talk")): return
	await _frames(5)
	if not _check(not app.run_state.pending_talk_event(id).is_empty(), "first connected Talk opens authored dialogue"):
		facts["classification"] = "INITIAL_ENTRY_ADMISSION_FAILED"; return
	if not _guard_equal(before, [id], "first entry has zero measured effects"): return
	if not (await _close(id)): return
	if not _guard_equal(before, [id], "neutral Close has zero measured effects"): return
	var journal: Dictionary = app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	var automatic: bool = app._resume_sal_starter_offer() if _case_id() == "sal_resume" else app.start_dialogue(dialogue)
	if not _check(not automatic and app.run_state.pending_talk_event(id).is_empty(), "actually invoked automatic/default guard stays suppressed"):
		facts["classification"] = "AUTOMATIC_GUARD_FAILED"; return
	if not _guard_equal(before, [id], "automatic suppression preserves measured state"): return
	var queue_before_reopen: int = app.run_state.pending_talk_event_count()
	if not (await _context_press("meta_sal:talk", "Talk")): return
	await _frames(5)
	var opened: bool = not app.run_state.pending_talk_event(id).is_empty()
	facts["explicit_reopened"] = opened
	facts["neutral_journal_retained"] = app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}) == journal
	_check(opened, "deliberate connected Talk reopens at same boundary")
	_check(bool(facts["neutral_journal_retained"]), "explicit request retains automatic suppression journal")
	if not _guard_equal(before, [id], "retry has zero measured effects"): return
	if not opened:
		facts["classification"] = "CONNECTED_MANUAL_REOPEN_REJECTED_REQUIRES_REVIEW"; return
	facts["queue_source"] = str(app.run_state.pending_talk_event(id).get("source", ""))
	_check(facts["queue_source"] == "event_object" and str(app.run_state.pending_talk_event(id).get("context", {}).get("source_object_id", "")) == "meta_sal:talk", "manual queue intent retains original Sal object")
	_check(app.run_state.pending_talk_event_count() == queue_before_reopen + 1, "manual Sal retry queues exactly one dialogue")
	await _close(id)
	_guard_equal(before, [id], "final Close has zero measured effects")

func _bronze_measurement() -> void:
	var id := "dialogue:tutorial_linda_bronze_finish"
	var before := _protected([id, CAGE])
	if not (await _collect_preview()):
		facts["classification"] = "COLLECT_UI_ADMISSION_FAILED"; return
	if not _check(not app.run_state.pending_talk_event(id).is_empty(), "actual Collect opens separate Bronze handoff"):
		facts["classification"] = "INITIAL_HANDOFF_ADMISSION_FAILED"; return
	if not _guard_equal(before, [id, CAGE], "Collect preview has no award or measured effects"): return
	if not (await _close(id)): return
	if not _guard_equal(before, [id, CAGE], "Bronze neutral Close has no award or effects"): return
	var journal: Dictionary = app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	var automatic: bool = app.start_dialogue("tutorial_linda_bronze_finish", {"source": "tutorial_bronze_review", "source_object_id": COUNTER})
	if not _check(not automatic and app.run_state.pending_talk_event(id).is_empty(), "dispatch-only automatic handoff guard remains suppressed"):
		facts["classification"] = "AUTOMATIC_GUARD_FAILED"; return
	var resumed_automatically: bool = app._resume_tutorial_linda_bronze_finish()
	if not _check(not resumed_automatically and app.run_state.pending_talk_event(id).is_empty(), "shared Bronze resume default remains automatic and suppressed"):
		facts["classification"] = "AUTOMATIC_HELPER_GUARD_FAILED"; return
	if not _guard_equal(before, [id, CAGE], "automatic Bronze helper has no award or effects"): return
	if not (await _collect_preview()):
		facts["classification"] = "COLLECT_RETRY_UI_ADMISSION_FAILED"; return
	var opened: bool = not app.run_state.pending_talk_event(id).is_empty()
	facts["explicit_reopened"] = opened
	_check(opened, "deliberate connected Collect reopens handoff at same boundary")
	_check(app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}) == journal, "Bronze retry retains suppression journal")
	if not _guard_equal(before, [id, CAGE], "Bronze retry grants no card/finale/other effect"): return
	if not opened:
		facts["classification"] = "CONNECTED_COLLECT_REOPEN_REJECTED_REQUIRES_REVIEW"; return
	_check(str(app.run_state.pending_talk_event(id).get("source", "")) == "event_object" and str(app.run_state.pending_talk_event(id).get("context", {}).get("source_object_id", "")) == COUNTER, "manual Collect intent retains Counter identity")
	await _close(id)
	_guard_equal(before, [id, CAGE], "final Bronze Close remains effect-free")

func _collect_preview() -> bool:
	if not (await _context_press(COUNTER, "Inspect")): return false
	await _frames(4)
	if not _check(not app.run_state.pending_talk_event(CAGE).is_empty(), "real Counter services open"):
		return false
	if str(app.run_state.pending_talk_event(CAGE).get("current_node", "")) != "card":
		if not (await _choice_press(CAGE, "open_card")): return false
	return await _choice_press(CAGE, "cage_finish_tutorial_card")

func _context_press(object_id: String, label: String) -> bool:
	var record: Dictionary = app._interactable_object(object_id)
	if not _check(not record.is_empty() and bool(record.get("enabled", true)), "real published enabled object " + object_id): return false
	var card := VBoxContainer.new()
	root.add_child(card); cards.append(card)
	app._add_context_object_actions(card, record)
	await _frames(3)
	var buttons: Array = card.get_children().filter(func(node): return node is Button and node.text == label)
	if not _check(buttons.size() == 1 and not buttons[0].disabled and buttons[0].is_visible_in_tree(), "one enabled connected context control " + label): return false
	buttons[0].pressed.emit()
	await _frames(4)
	return true

func _choice_press(event_id: String, choice_id: String) -> bool:
	# Only free menu navigation and Collect preview are permitted by this harness.
	if not _check(choice_id in ["open_card", "cage_finish_tutorial_card"], "choice is in zero-award allowlist"): return false
	await _frames(3)
	var buttons: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("event_id", "")) == event_id and str(button.get_meta("choice_id", "")) == choice_id)
	if not _check(buttons.size() == 1 and not buttons[0].disabled and buttons[0].is_visible_in_tree(), "actual enabled free choice " + choice_id): return false
	buttons[0].pressed.emit()
	await _frames(5)
	return true

func _close(event_id: String) -> bool:
	await _frames(3)
	if not _check(str(app.talk_dock.entry.get("event_id", "")) == event_id, "Close owns the intended dialogue"): return false
	var button: Button = app.talk_dock.collapse_button
	if not _check(button != null and not button.disabled and button.is_visible_in_tree(), "actual neutral Close is available"): return false
	button.pressed.emit()
	await _frames(4)
	return _check(app.run_state.pending_talk_event(event_id).is_empty() and app.run_state.neutral_talk_dismissed_at_current_boundary(event_id), "neutral Close records actual same-boundary dismissal")

func _protected(ids: Array) -> Dictionary:
	var run: Dictionary = app.run_state.to_dict().duplicate(true)
	var pending: Array = run.get("pending_triggered_events", [])
	run["pending_triggered_events"] = pending.filter(func(row): return str(row.get("event_id", "")) not in ids)
	var active: Dictionary = run.get("active_triggered_event", {})
	if str(active.get("event_id", "")) in ids: run["active_triggered_event"] = {}
	for key in ["surface_clock_checkpoint_msec", "music_tempo_state"]: run.erase(key)
	var flags: Dictionary = run.get("narrative_flags", {})
	var journal: Dictionary = flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	for id in ids: journal.erase(id)
	if journal.is_empty(): flags.erase("neutral_dialogue_dismissals")
	else: flags["neutral_dialogue_dismissals"] = journal
	return {"run": run, "collection": app.meta_collection_service.snapshot(), "profile": app.profile_inventory.to_dict()}

func _guard_equal(before: Dictionary, ids: Array, label: String) -> bool:
	var after := _protected(ids)
	var same := before == after
	if not same:
		facts["unexpected_changed_paths"] = _changed_paths(before, after)
		facts["classification"] = "UNEXPECTED_DELTA_REQUIRES_DIAGNOSIS"
	return _check(same and _players_card_count() == 0, label)

func _players_card_count() -> int:
	if app == null or app.meta_collection_service == null: return 0
	var count := 0
	for value in app.meta_collection_service.snapshot().get("owned_instances", []):
		if typeof(value) == TYPE_DICTIONARY and int(value.get("itemdef_id", -1)) == 9500: count += 1
	return count

func _changed_paths(left: Variant, right: Variant, prefix: String = "$") -> Array:
	var paths: Array = []
	if left == right: return paths
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		for key in left:
			if not right.has(key): paths.append(prefix + "." + str(key) + " <removed>")
			else: paths.append_array(_changed_paths(left[key], right[key], prefix + "." + str(key)))
		for key in right:
			if not left.has(key): paths.append(prefix + "." + str(key) + " <added>")
	elif typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY and left.size() == right.size():
		for index in left.size(): paths.append_array(_changed_paths(left[index], right[index], prefix + "[" + str(index) + "]"))
	else:
		paths.append(prefix)
	return paths.slice(0, 40)

func _frames(count: int) -> void:
	for frame in count: await process_frame

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _cleanup() -> void:
	for card in cards:
		if is_instance_valid(card): card.queue_free()
	if is_instance_valid(app): app.queue_free()
	await _frames(3)

func _finish() -> void:
	print(JSON.stringify({"suite": "grand_explicit_entry_native", "case": _case_id(), "checks": checks, "failures": failures, "facts": facts,
		"source_base_commit": SOURCE_COMMIT, "base_tree": COMPARISON_TREE, "tested_tree": OS.get_environment("BTH_EXPLICIT_PATCH_TREE"),
		"fidelity": "SYNTHETIC_CONNECTED_NATIVE_CONTROLS_ONLY; no browser/physical input, acquisition, actual card award or storage durability"}))
	quit(0 if failures.is_empty() else 1)

func _counter_measurement() -> void:
	var id := CAGE
	var before := _protected([id])
	if not (await _context_press(COUNTER, "Inspect")): return
	if not _check(not app.run_state.pending_talk_event(id).is_empty(), "actual Counter Inspect opens services"): return
	if not _guard_equal(before, [id], "Counter Inspect has no service or award effect"): return
	if not (await _close(id)): return
	var journal: Dictionary = app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	var automatic: bool = app.start_dialogue("linda_cage_services", {"source": "casino_cage_counter", "source_object_id": COUNTER})
	_check(not automatic and app.run_state.pending_talk_event(id).is_empty(), "default Counter request stays suppressed after Close")
	if not _guard_equal(before, [id], "automatic Counter suppression preserves all protected state"): return
	var queued_before: int = app.run_state.pending_talk_event_count()
	if not (await _context_press(COUNTER, "Inspect")): return
	var entry: Dictionary = app.run_state.pending_talk_event(id)
	_check(not entry.is_empty() and str(entry.get("source", "")) == "event_object", "actual Counter Inspect reopens with manual intent")
	_check(app.run_state.pending_talk_event_count() == queued_before + 1, "Counter retry queues exactly one conversation")
	_check(app.run_state.narrative_flags.get("neutral_dialogue_dismissals", {}) == journal, "Counter retry retains automatic suppression journal")
	if not _guard_equal(before, [id], "Counter reopen has no accounting/RNG/card effect"): return
	if not (await _close(id)): return
	_guard_equal(before, [id], "final Counter Close remains effect-free")
