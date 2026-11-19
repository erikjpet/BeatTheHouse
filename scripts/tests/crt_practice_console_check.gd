extends SceneTree

# Synthetic, disposable host regression. Room fixtures use the production room
# generator; every practice launch and Leave uses the production host/module.
# This is routing/state qualification, not rendered native or Web acceptance.

const Foundation := preload("res://scripts/ui/foundation_main.gd")
const ScratchTickets := preload("res://scripts/games/scratch_tickets.gd")
const Profile := preload("res://scripts/core/profile_inventory.gd")
const MetaCollection := preload("res://scripts/core/meta_collection_service.gd")
const Console := preload("res://scripts/core/home_practice_console.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")

class ProbeHost extends Foundation:
	var generated_practice: Dictionary = {}
	var reject_next_foundation_write := false
	var rejected_foundation_writes: Array[Dictionary] = []

	func _game_test_environment(game_id: String, game: GameModule) -> Dictionary:
		var environment := super._game_test_environment(game_id, game)
		# Capture before enter() adds live session/presentation timing. This keeps
		# repeatability assertions on the actual generated model, without deleting
		# selected fields or substituting a simulator.
		generated_practice = environment.duplicate(true)
		return environment

	func _write_foundation_run_save(status_text: String = "Autosaved.", synchronous: bool = false) -> bool:
		# Refuse one host-owned request before the real service is called. Every
		# successful case still uses the production writer and disposable slot.
		if reject_next_foundation_write:
			reject_next_foundation_write = false
			rejected_foundation_writes.append({"status_text": status_text, "synchronous": synchronous})
			return false
		return super._write_foundation_run_save(status_text, synchronous)

var app: ProbeHost
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []
var persistence_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _isolated_paths_present():
		_finish(2)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = ProbeHost.new()
	app.continuous_environment_clock_enabled = false
	app.autosave_slot_id = "crt_practice_console_check"
	root.add_child(app)
	await _settle(3)
	app._ensure_full_content_library_loaded()
	if not _check(app._ensure_run_ui_built(), "production run UI builds"):
		_finish(1)
		return
	_prepare_persistence_baseline()
	await _title_catalog_and_loops()
	await _generation_inputs()
	await _terminal_and_persistence_boundaries()
	for archetype_id in ["motel_room", "apartment", "house"]:
		await _room_origin_loop(archetype_id)
	for housing_tier in ["motel_room", "apartment", "house"]:
		await _meta_origin_loop(housing_tier)
	await _inflight_save_entry()
	_check_console_eligibility()
	app.queue_free()
	await process_frame
	_finish(0 if failures.is_empty() else 1)


func _isolated_paths_present() -> bool:
	var safe := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").to_lower()
		safe = _check(path.begins_with("e:/codexqa/bth/") and not path.contains("/../"), "%s uses explicit disposable E: QA storage" % key) and safe
	for key in ["BTH_CAPTURED_FIXTURE", "BTH_WEB_STORAGE_PROFILE"]:
		safe = _check(OS.get_environment(key).is_empty(), "%s is absent; no captured/player profile is opened" % key) and safe
	return safe


func _prepare_persistence_baseline() -> void:
	var continued := RunState.new()
	continued.start_new("CRT-CONTINUE-SENTINEL")
	continued.home_state = {"active": true, "lost": false, "home_archetype_id": "apartment", "home_node_id": "apartment", "tenure": {}}
	var baseline_generator := RunGenerator.new(app.library)
	var baseline_room := baseline_generator.environment_test_result(continued, {"archetype_id": "apartment", "scenario_id": "__none", "generation_key": "crt-continue-baseline", "depth": 0})
	_check(bool(baseline_room.get("ok", false)), "Continue sentinel uses a fully generated production apartment")
	continued._store_current_local_suspicion()
	continued.bankroll = 317
	continued.narrative_flags["crt_continue_sentinel"] = "preserve"
	_check(app.save_service.save_run(continued, app.autosave_slot_id) == OK, "disposable Continue primary is seeded")
	_check(app.save_service.save_run(continued, app.autosave_slot_id) == OK, "disposable Continue backup is seeded")
	_check(app.profile_inventory.save() == OK, "disposable profile baseline is durable")
	_check(app.meta_collection_service.save() == OK, "disposable meta baseline is durable")
	persistence_paths = [
		app.save_service.run_save_path(app.autosave_slot_id),
		app.save_service.backup_save_path(app.autosave_slot_id),
		Profile.store_path(), Profile.store_path() + ".bak",
		MetaCollection.store_path(), MetaCollection.store_path() + ".bak",
	]
	_check(app._has_foundation_save(), "existing Continue remains available before practice")
	_check_codec_identity(continued, "fresh codec Continue validates the generated ordinary baseline")
	app._refresh_start_screen()


func _title_catalog_and_loops() -> void:
	var persistent_before := _persistent_snapshot()
	app.open_game_test_menu()
	await _settle(2)
	var menu := app.game_test_menu
	_check(menu != null and menu.is_visible_in_tree() and app._crt_practice_active(), "title Games opens the CRT selector")
	if menu == null:
		return
	var ids: Array = app._implemented_game_ids()
	var buttons := _launch_buttons(menu)
	_check(ids.size() == 11 and buttons.size() == 11, "all eleven canonical playable games appear exactly once")
	_check(app.game_test_seed_input.text == "PRACTICE", "visible seed default is retained")
	_check(app._game_test_bankroll() == 100000 and app._game_test_stake_floor() == 1 and app._game_test_stake_ceiling() == 200, "practice bankroll and minimum/maximum defaults are retained")
	_check(app._game_test_security_strictness() == "boss" and app._game_test_generation_overrides().is_empty(), "security and generation override defaults are retained")
	app.game_test_seed_input.text = "CRT-REPEATABLE"
	for game_id_value in ids:
		var game_id := str(game_id_value)
		var definition: Dictionary = app.library.game(game_id)
		var button := buttons.get(game_id) as Button
		_check(button != null and button.text == str(definition.get("display_name", "")), "%s row uses its canonical name" % game_id)
		_check(button != null and button.icon != null, "%s row includes its existing game icon" % game_id)
		if button == null:
			continue
		var expected_icon: Texture2D = app._texture_for_image_asset_path(str(definition.get("asset_path", "")))
		_check(expected_icon != null and button.icon == expected_icon, "%s row uses its canonical asset, including intentional aliases" % game_id)
		button.grab_focus()
		button.pressed.emit()
		var game: GameModule = app.current_game
		var entered := game != null and game.get_id() == game_id and app.current_screen == "GAME"
		_check(entered, "%s row launches its normal gameplay module" % game_id)
		if not entered:
			continue
		_check(app.run_state != null and app.dev_game_test_mode and not app._is_meta_session(), "%s launch owns an isolated practice RunState" % game_id)
		_check(app.run_state.seed_text == "CRT-REPEATABLE-%s" % game_id.to_upper(), "%s keeps existing seed derivation" % game_id)
		_check(app.run_state.excludes_profile_stats(), "%s practice excludes persistent run stats" % game_id)
		var first_generation: Dictionary = app.generated_practice.get("game_states", {}).duplicate(true)
		if game_id == "scratch_tickets":
			_check_scratch_stock(app.run_state.current_environment)
		await _normal_leave(game_id)
		_check(app.game_test_menu == menu and menu.is_visible_in_tree(), "%s Leave returns to the same CRT selector" % game_id)
		_check(app.game_test_seed_input.text == "CRT-REPEATABLE", "%s Leave preserves the visible seed" % game_id)
		_check(str(menu.get("selected_game_id")) == game_id, "%s Leave preserves selector choice" % game_id)
		var repeated: Dictionary = app.start_game_test_session(game_id)
		_check(bool(repeated.get("ok", false)), "%s can launch repeatedly" % game_id)
		_check(first_generation == app.generated_practice.get("game_states", {}), "%s identical generation seed reproduces its complete generated state" % game_id)
		await _normal_leave(game_id)
		cases.append({"origin": "title", "game": game_id, "launches": 2, "leave_path": "back_to_environment"})
	_check(_persistent_snapshot() == persistent_before, "all game entry/Leave loops preserve Continue/profile/meta bytes and state")
	var selector_run := app.run_state
	var rejected: Dictionary = app.start_game_test_session("__no_such_crt_game")
	_check(not bool(rejected.get("ok", true)), "unknown game is rejected")
	_check(app.game_test_menu == menu and menu.is_visible_in_tree() and app.run_state == selector_run and app._crt_practice_active(), "rejected launch keeps the selector and parked origin")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	app._input(cancel)
	await _settle(2)
	_check(not app._crt_practice_active() and app.current_screen == "START" and app.run_state == null, "Cancel exits the title CRT to the title screen")
	_check(_persistent_snapshot() == persistent_before, "title Cancel preserves Continue/profile/meta")


func _terminal_and_persistence_boundaries() -> void:
	var persistent_before := _persistent_snapshot()
	app.open_game_test_menu()
	var started: Dictionary = app.start_game_test_session("scratch_tickets")
	if not _check(bool(started.get("ok", false)), "persistence-boundary practice starts"):
		app.close_game_test_menu()
		return
	var practice := app.run_state
	app.pending_autosave = true
	app.pending_autosave_after_frame = -1
	app._flush_pending_autosave_if_ready()
	_check(not app._write_foundation_run_save("CRT must never write", true), "direct synchronous save rejects practice")
	_check(not app._autosave_foundation_run("CRT must never autosave", true), "forced autosave rejects practice")
	app._queue_pending_autosave("CRT must never queue", 0)
	app._flush_pending_autosave_for_lifecycle()
	app._record_scratch_ticket_discovery("two_fer")
	app._on_coach_lesson_seen("crt_regression_unseen_tip")
	for lesson_value in app.library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY:
			app._on_coach_lesson_completed(str((lesson_value as Dictionary).get("id", "")))
			break
	app._complete_tutorial_profile()
	app._clear_tutorial_resume_slot()
	_check(_persistent_snapshot() == persistent_before, "save/discovery/coach/tutorial callbacks cannot write practice into persistent stores")
	practice.bankroll = 19
	practice.game_clock_minutes += 43
	practice.inventory.append({"id": "crt_only_item", "quantity": 1})
	practice.narrative_flags["crt_only_progress"] = true
	practice.rng_state = 12345
	practice.challenge_config["completion_flag"] = "crt_must_not_unlock"
	practice.run_status = RunState.RUN_STATUS_ENDED
	app._record_profile_run_result_once()
	app._record_challenge_completion_if_needed()
	app._settle_terminal_meta_outcome(practice)
	_check(_persistent_snapshot() == persistent_before, "terminal victory cannot stock Sal, grant rewards/stats/unlocks, or replace Continue")
	_check(app._crt_practice_active() and not app.crt_practice_origin.is_empty(), "terminal practice retains its parked origin")
	practice.run_status = RunState.RUN_STATUS_FAILED
	app._record_profile_run_result_once()
	app._settle_terminal_meta_outcome(practice)
	_check(_persistent_snapshot() == persistent_before, "terminal failure cannot record profile history or decay meta collection")
	app.return_to_main_menu()
	await _settle(2)
	_check(app._crt_practice_active() and app.game_test_menu.is_visible_in_tree(), "practice Main Menu returns to CRT without discarding its origin")
	app.close_game_test_menu()
	_check(not app._crt_practice_active() and app.current_screen == "START", "Exit CRT restores title after terminal practice")
	_check(_persistent_snapshot() == persistent_before, "terminal exit preserves persistent state")


func _generation_inputs() -> void:
	app.open_game_test_menu()
	app.game_test_seed_input.text = "CRT-CUSTOM-SEED"
	app.game_test_bankroll_input.value = 4321
	app.game_test_stake_floor_input.value = 7
	app.game_test_stake_ceiling_input.value = 91
	app.game_test_security_option.select(1)
	var overrides := {"environment": {"economic_profile": {"stake_floor": 8}}, "game_state": {"crt_generation_marker": "nested"}}
	var override_text := JSON.stringify(overrides)
	var expected_parsed: Dictionary = JSON.parse_string(override_text)
	app.game_test_generation_overrides_text.text = override_text
	var started: Dictionary = app.start_game_test_session("blackjack")
	if _check(bool(started.get("ok", false)), "custom generation controls launch Blackjack"):
		var environment := app.generated_practice
		_check(app.run_state.seed_text == "CRT-CUSTOM-SEED-BLACKJACK" and app.run_state.bankroll == 4321, "custom seed and bankroll reach the existing practice path")
		_check(int(environment.get("economic_profile", {}).get("stake_floor", 0)) == 8 and int(environment.get("economic_profile", {}).get("stake_ceiling", 0)) == 91, "generation environment override merges with existing min/max controls")
		_check(str(environment.get("security_profile", {}).get("strictness", "")) == "high", "security choice reaches generation")
		_check(str(environment.get("game_states", {}).get("blackjack", {}).get("crt_generation_marker", "")) == "nested", "nested game-state generation override is retained")
		await _normal_leave("blackjack")
		_check(app.game_test_seed_input.text == "CRT-CUSTOM-SEED" and app._game_test_bankroll() == 4321 and app._game_test_stake_floor() == 7 and app._game_test_stake_ceiling() == 91, "Leave retains custom generation controls")
		var retained_overrides: Dictionary = app._game_test_generation_overrides()
		var retained_security := app._game_test_security_strictness()
		var retains_inputs := app.game_test_generation_overrides_text.text == override_text and retained_overrides == expected_parsed and retained_security == "high"
		_check(retains_inputs, "Leave retains security and override JSON")
		if not retains_inputs:
			diagnostics.append({"case": "generation_inputs_after_leave", "expected_security": "high", "actual_security": retained_security, "expected_overrides": expected_parsed, "actual_overrides": retained_overrides, "expected_text": override_text, "actual_text": app.game_test_generation_overrides_text.text, "differences": _identity_differences(expected_parsed, retained_overrides)})
	app.game_test_seed_input.text = ""
	app.game_test_generation_overrides_text.text = '{"crt_generation_marker":"bare"}'
	var bare: Dictionary = app.start_game_test_session("blackjack")
	if _check(bool(bare.get("ok", false)), "legacy bare game-state override still launches"):
		_check(app.run_state.seed_text == "PRACTICE-BLACKJACK" and str(app.generated_practice.get("game_states", {}).get("blackjack", {}).get("crt_generation_marker", "")) == "bare", "blank seed fallback and bare override contract remain compatible")
		await _normal_leave("blackjack")
	var security_ids: Array = []
	for index in range(app.game_test_security_option.item_count):
		security_ids.append(app.game_test_security_option.get_item_metadata(index))
	_check(security_ids == ["low", "high", "boss"], "all existing security options remain available")
	app.game_test_seed_input.text = "PRACTICE"
	app.game_test_bankroll_input.value = 100000
	app.game_test_stake_floor_input.value = 1
	app.game_test_stake_ceiling_input.value = 200
	app.game_test_security_option.select(2)
	app.game_test_generation_overrides_text.text = "{}"
	app.close_game_test_menu()


func _room_origin_loop(archetype_id: String) -> void:
	var candidate := RunState.new()
	candidate.start_new("CRT-PARKED-%s" % archetype_id)
	candidate.home_state = {"active": true, "lost": false, "home_archetype_id": archetype_id, "home_node_id": archetype_id, "tenure": {}}
	var fixture_generator := RunGenerator.new(app.library)
	var generated := fixture_generator.environment_test_result(candidate, {"archetype_id": archetype_id, "scenario_id": "__none", "generation_key": "crt-origin", "depth": 0})
	if not _check(bool(generated.get("ok", false)), "%s synthetic production room generates" % archetype_id):
		cases.append({"origin": archetype_id, "generation_errors": generated.get("errors", [])})
		return
	candidate._store_current_local_suspicion()
	app.run_state = candidate
	app.generator = fixture_generator
	app.dev_game_test_mode = false
	app.dev_environment_test_mode = false
	app.meta_session_active = false
	app.meta_session_location_id = ""
	app.current_game = null
	app._set_current_screen("ENVIRONMENT")
	app._bind_run_state_presentation_signals()
	app._refresh_run_action_service()
	app._queue_room_publication_check()
	app._refresh()
	await _settle(2)
	var console_object: Dictionary = app._interactable_object(Console.OBJECT_ID)
	_check(not console_object.is_empty() and bool(console_object.get("enabled", false)), "%s publishes an enabled television/console" % archetype_id)
	if console_object.is_empty():
		return
	var coach_before_click: Dictionary = app._coach_lifecycle_snapshot()
	app.environment_clock_fractional_minutes = 0.375
	# Queue the real ordinary autosave immediately before selecting the console.
	# There is deliberately no yielded frame between this request and entry.
	app._queue_pending_autosave("CRT parked ordinary generation", 1)
	var ordinary_generation := app.autosave_dirty_generation
	var before := _origin_state(candidate)
	var stores_before_entry := _persistent_snapshot()
	if archetype_id == "apartment":
		# Simulate a refused ordinary write at the ownership boundary without
		# changing file permissions, storage paths or the production save service.
		var rejected_before := app.rejected_foundation_writes.size()
		app.reject_next_foundation_write = true
		app.open_game_test_menu()
		_check(app.rejected_foundation_writes.size() == rejected_before + 1 and not app.reject_next_foundation_write and bool(app.rejected_foundation_writes.back().get("synchronous", false)), "failed queued-save fixture refuses the synchronous entry write once")
		_check(not app._crt_practice_active() and app.current_screen == "ENVIRONMENT" and not app.game_test_menu.is_visible_in_tree(), "failed ordinary entry save leaves the CRT closed")
		_check(app.run_state == candidate and app.generator == fixture_generator and _origin_state(candidate) == before, "failed ordinary entry save retains the actual run, generator and room state")
		_check(app.pending_autosave and app.autosave_dirty_generation == ordinary_generation and app.autosave_completed_generation < ordinary_generation, "failed ordinary entry save retains its pending generation for a normal retry")
		_check(_persistent_snapshot() == stores_before_entry, "failed ordinary entry save preserves existing Continue bytes and profile/meta stores")
	_check(app.activate_interactable_object(Console.OBJECT_ID), "%s television activates through ordinary room dispatch" % archetype_id)
	# Entry may finish this legitimate ordinary save, before ownership switches
	# to practice. Capture the immutable practice baseline after that completion.
	var persistent_before := _persistent_snapshot()
	_check(app.autosave_completed_generation >= ordinary_generation and app.autosave_inflight_generation == 0 and not app.pending_autosave, "%s queued ordinary save completes before practice ownership" % archetype_id)
	_check(persistent_before.get("profile", {}) == stores_before_entry.get("profile", {}) and persistent_before.get("meta", {}) == stores_before_entry.get("meta", {}), "%s ordinary entry save leaves profile and meta state unchanged" % archetype_id)
	_check_codec_identity(candidate, "%s queued ordinary generation is durable before practice or backgrounding" % archetype_id)
	var parked_coach: Dictionary = app.crt_practice_origin.get("lifecycle", {}).get("coach", {})
	diagnostics.append({"case": "%s_tv_activation_coach_boundary" % archetype_id, "before_click_lesson": coach_before_click.get("active_lesson", {}), "parked_lesson": parked_coach.get("active_lesson", {}), "same_attention_tween": coach_before_click.get("attention", {}).get("tween") == parked_coach.get("attention", {}).get("tween")})
	await _settle(2)
	_check(app._crt_practice_active() and app.game_test_menu.is_visible_in_tree(), "%s enters CRT" % archetype_id)
	_check(not app.pending_autosave, "%s practice inherits no ordinary pending save" % archetype_id)
	_check(not app._flush_pending_autosave_for_lifecycle(), "%s background lifecycle flush cannot write selector state" % archetype_id)
	_check(_persistent_snapshot() == persistent_before, "%s selector backgrounding retains the durable ordinary save and profile/meta stores" % archetype_id)
	var start: Dictionary = app.start_game_test_session("scratch_tickets")
	_check(bool(start.get("ok", false)) and app.run_state != candidate, "%s practice has an independent RunState" % archetype_id)
	if bool(start.get("ok", false)):
		await _buy_practice_ticket(archetype_id)
		app.run_state.bankroll += 51
		app.run_state.game_clock_minutes += 71
		app.run_state.rng_state = 941
		app.run_state.inventory.append({"id": "crt_only_item", "quantity": 1})
		app.run_state.add_suspicion("crt_only_heat", 9)
		app.run_state.narrative_flags["crt_only_unlock"] = true
		_check(not app._flush_pending_autosave_for_lifecycle(), "%s background lifecycle flush cannot write an active practice wager" % archetype_id)
		_check(_persistent_snapshot() == persistent_before, "%s practice backgrounding preserves the completed ordinary save and profile/meta stores" % archetype_id)
		_check_codec_identity(candidate, "%s Continue remains the ordinary generation while a practice wager is active" % archetype_id)
		await _normal_leave("scratch_tickets")
		_check(_origin_state(candidate) == before, "%s parked cash/Heat/time/inventory/progression/RNG/room remains unchanged during practice" % archetype_id)
	app.close_game_test_menu()
	_check(app.run_state == candidate and app.generator == fixture_generator and app.current_screen == "ENVIRONMENT", "%s Exit restores the exact originating run/generator/room" % archetype_id)
	_check(_origin_state(candidate) == before, "%s Exit preserves complete serialized run and current room" % archetype_id)
	_check(is_equal_approx(app.environment_clock_fractional_minutes, 0.375), "%s fractional game clock is retained" % archetype_id)
	_check(not app.pending_autosave and app.autosave_completed_generation >= ordinary_generation and app.autosave_inflight_generation == 0, "%s Exit does not resurrect the completed ordinary save request" % archetype_id)
	_check(_persistent_snapshot() == persistent_before, "%s practice never overwrites existing Continue/profile/meta" % archetype_id)
	await _settle(2)
	_check(app.autosave_completed_generation >= ordinary_generation and not app.pending_autosave and not app.save_service.async_save_in_flight(), "%s completed ordinary generation remains settled after CRT Exit" % archetype_id)
	_check_codec_identity(candidate, "%s cold codec Continue retains ordinary room, money, clock, inventory and RNG" % archetype_id)
	_check(app.activate_interactable_object(Console.OBJECT_ID), "%s television supports a second entry" % archetype_id)
	app.close_game_test_menu()
	_check(app.run_state == candidate and _origin_state(candidate) == before, "%s selector-only cancel loop preserves origin" % archetype_id)
	if archetype_id == "motel_room":
		await _coach_origin_retention()
	cases.append({"origin": archetype_id, "fidelity": "synthetic production room", "loops": 2})
	# End only this synthetic fixture without invoking run persistence.
	app.run_state = null
	app.current_game = null
	app._set_current_screen("START")
	app._refresh()


func _coach_origin_retention() -> void:
	var coach: CoachOverlay = app.coach_overlay
	if not _check(coach != null, "Coach retention fixture owns the real Coach overlay"):
		return
	# Direct console entry isolates the lifecycle contract from the ordinary
	# TV-selection focus boundary, which can legitimately refresh Coach lessons.
	var lesson := {"id": "crt_origin_active_lesson", "scope": "normal_run", "copy": "Retain the originating Coach lesson."}
	coach.active_lesson = lesson.duplicate(true)
	coach.active_context = app._coach_context_snapshot()
	coach.presentation_suspended = false
	coach._render_active(true)
	var retained_tween: Tween = coach.attention_tween
	if retained_tween != null:
		retained_tween.set_speed_scale(0.01)
	_check(retained_tween != null and retained_tween.is_valid(), "origin Coach attention Tween is active before direct parking")
	var before := {"lesson": coach.active_lesson.duplicate(true), "copy": coach.copy_label.text, "alpha": coach.panel.modulate.a}
	app.open_game_test_menu()
	var parked: Dictionary = app.crt_practice_origin.get("lifecycle", {}).get("coach", {})
	var parked_exact: bool = parked.get("active_lesson", {}) == lesson and parked.get("attention", {}).get("tween") == retained_tween
	_check(parked_exact, "direct CRT entry parks the exact active Coach model and Tween")
	diagnostics.append({"case": "direct_coach_parked_boundary", "before": before, "parked_lesson": parked.get("active_lesson", {}), "same_attention_tween": parked.get("attention", {}).get("tween") == retained_tween, "retained_tween_valid": retained_tween != null and retained_tween.is_valid()})
	var started: Dictionary = app.start_game_test_session("blackjack")
	_check(bool(started.get("ok", false)), "Coach retention fixture launches normal practice")
	if bool(started.get("ok", false)):
		await _normal_leave("blackjack")
	app.close_game_test_menu()
	var restored := coach.active_lesson == lesson and coach.attention_tween == retained_tween and retained_tween != null and retained_tween.is_valid()
	_check(restored, "Exit restores the same active origin Coach lesson and attention Tween")
	if not restored:
		diagnostics.append({"case": "coach_origin_after_exit", "before": before, "after": {"lesson": coach.active_lesson.duplicate(true), "copy": coach.copy_label.text, "alpha": coach.panel.modulate.a, "same_tween": coach.attention_tween == retained_tween, "original_tween_valid": retained_tween != null and retained_tween.is_valid(), "original_tween_running": retained_tween != null and retained_tween.is_valid() and retained_tween.is_running(), "current_tween_valid": coach.attention_tween != null and coach.attention_tween.is_valid(), "protected_count": coach.lifecycle_protected_attention_tweens.size(), "checkpoint_count": coach.lifecycle_attention_checkpoints.size(), "visible": coach.visible, "panel_visible": coach.panel.visible}})
	_check(coach.lifecycle_attention_checkpoints.is_empty() and coach.lifecycle_protected_attention_tweens.is_empty(), "CRT releases only its Coach lifecycle protection checkpoint")
	var prior_alpha := coach.panel.modulate.a
	var advanced := retained_tween.custom_step(0.03) if retained_tween != null and retained_tween.is_valid() else false
	_check(advanced and coach.panel.modulate.a > prior_alpha, "restored origin Coach fade remains live after practice")
	if not advanced or coach.panel.modulate.a <= prior_alpha:
		diagnostics.append({"case": "coach_origin_fade_step", "advanced": advanced, "alpha_before_step": prior_alpha, "alpha_after_step": coach.panel.modulate.a, "original_tween_valid": retained_tween != null and retained_tween.is_valid(), "same_tween": coach.attention_tween == retained_tween})


func _buy_practice_ticket(origin: String) -> void:
	var state := app.run_state
	var machine: Dictionary = state.current_environment.get("game_states", {}).get("scratch_tickets", {})
	var stock: Array = machine.get("stock", [])
	if not _check(not stock.is_empty(), "%s practice has a funded ticket selection" % origin):
		return
	var selected: Dictionary = stock[0]
	var cash_before := state.bankroll
	var price := int(selected.get("price", 1))
	app._on_game_surface_action("scratch_buy", 0)
	var popup := app.current_event_choice_popup_snapshot()
	if str(popup.get("popup_type", "")) == "wager_confirmation" and bool(popup.get("visible", false)):
		app.confirm_pending_wager_action()
	await _settle(2)
	var purchased: Dictionary = state.current_environment.get("game_states", {}).get("scratch_tickets", {})
	var tray: Array = purchased.get("tray_stack", [])
	_check(state.bankroll == cash_before - price and not tray.is_empty(), "%s normal practice Buy charges once and produces a ticket" % origin)
	_check(int((purchased.get("stock", []) as Array)[0].get("remaining", -1)) == 99, "%s normal practice wager consumes one of 100 tickets" % origin)


func _inflight_save_entry() -> void:
	var candidate := RunState.new()
	candidate.start_new("CRT-INFLIGHT-ORDINARY")
	candidate.bankroll = 287
	var fixture_generator := RunGenerator.new(app.library)
	var generated := fixture_generator.environment_test_result(candidate, {"archetype_id": "apartment", "scenario_id": "__none", "generation_key": "crt-inflight", "depth": 0})
	if not _check(bool(generated.get("ok", false)), "in-flight ordinary apartment fixture generates"):
		return
	candidate._store_current_local_suspicion()
	app.run_state = candidate
	app.generator = fixture_generator
	app.current_game = null
	app.dev_game_test_mode = false
	app.dev_environment_test_mode = false
	app._set_current_screen("ENVIRONMENT")
	app._refresh_run_action_service()
	app._queue_room_publication_check()
	app._refresh()
	await _settle(2)
	app._queue_pending_autosave("CRT in-flight original generation", 0)
	var original_generation := app.autosave_dirty_generation
	_check(app._write_foundation_run_save("CRT in-flight original generation"), "ordinary save begins immediately before CRT entry")
	# Native workers may finish before this synchronous call; Web's phased path
	# remains in flight. Both must preserve the accepted ordinary generation.
	app.open_game_test_menu()
	_check(app._crt_practice_active() and not app.save_service.async_save_in_flight(), "CRT entry drains accepted save before parking original counters")
	_check(app.autosave_completed_generation >= original_generation, "accepted original save completion is accounted before practice")
	var persistent_before := _persistent_snapshot()
	var launched: Dictionary = app.start_game_test_session("pull_tabs")
	_check(bool(launched.get("ok", false)), "practice launches after in-flight save drain")
	if bool(launched.get("ok", false)):
		app.run_state.bankroll = 1
		await _normal_leave("pull_tabs")
	app.close_game_test_menu()
	_check(app.run_state == candidate and app.autosave_completed_generation >= original_generation and app.autosave_inflight_generation == 0, "Exit does not resurrect a completed in-flight save generation")
	_check(_persistent_snapshot() == persistent_before, "in-flight entry practice preserves completed original save bytes")
	_check_codec_identity(candidate, "fresh codec Continue loads accepted ordinary generation after in-flight entry")
	app.run_state = null
	app.current_game = null
	app.pending_autosave = false
	app._set_current_screen("START")
	app._refresh()


func _meta_origin_loop(housing_tier: String) -> void:
	# Fixture setup only: select each supported housing tier in the fresh test
	# collection before capturing the immutable before-image.
	app.meta_collection_service._store["housing_tier"] = housing_tier
	_check(app.meta_collection_service.save() == OK, "%s disposable meta housing fixture saves" % housing_tier)
	app.open_meta_home()
	await _settle(2)
	var original := app.run_state
	if not _check(original != null and app._is_meta_session(), "%s meta-home opens" % housing_tier):
		return
	var before := _origin_state(original)
	var persistent_before := _persistent_snapshot()
	_check(not app._interactable_object(Console.OBJECT_ID).is_empty(), "%s meta-home publishes television/console" % housing_tier)
	_check(app.activate_interactable_object(Console.OBJECT_ID), "%s meta-home console activates" % housing_tier)
	var start: Dictionary = app.start_game_test_session("scratch_tickets")
	_check(bool(start.get("ok", false)), "%s meta-home launches normal Scratch Tickets practice" % housing_tier)
	if bool(start.get("ok", false)):
		_check(not app._is_meta_session() and app.run_state != original, "%s practice clears meta context and keeps a separate run" % housing_tier)
		_check_scratch_stock(app.run_state.current_environment)
		await _normal_leave("scratch_tickets")
	app.close_game_test_menu()
	_check(app.run_state == original and app._is_meta_session() and app.meta_session_location_id == "home", "%s Exit restores exact meta-home context" % housing_tier)
	_check(_origin_state(original) == before, "%s meta-home state and RNG remain unchanged" % housing_tier)
	_check(_persistent_snapshot() == persistent_before, "%s meta-home practice preserves collection/profile/Continue bytes" % housing_tier)
	cases.append({"origin": "meta_" + housing_tier, "fidelity": "fresh disposable housing fixture", "game": "scratch_tickets"})
	app._exit_meta_session()
	await _settle(1)


func _check_scratch_stock(environment: Dictionary) -> void:
	var machine: Dictionary = environment.get("game_states", {}).get("scratch_tickets", {})
	var stock: Array = machine.get("stock", [])
	var seen: Array[String] = []
	for slot_value in stock:
		if typeof(slot_value) != TYPE_DICTIONARY:
			_check(false, "scratch stock row is a dictionary")
			continue
		var slot: Dictionary = slot_value
		seen.append(str(slot.get("type_id", "")))
		_check(int(slot.get("capacity", 0)) == 100 and int(slot.get("remaining", 0)) == 100, "%s scratch stock starts at 100/100" % str(slot.get("type_id", "")))
	_check(seen.size() == ScratchTickets.ACTIVE_TICKET_TYPE_IDS.size(), "scratch machine has exactly the active ticket roster")
	for type_id in ScratchTickets.ACTIVE_TICKET_TYPE_IDS:
		_check(seen.count(type_id) == 1, "scratch machine includes %s exactly once" % type_id)


func _check_console_eligibility() -> void:
	for archetype_id in ["motel_room", "apartment", "house"]:
		_check(Console.eligible({"archetype_id": archetype_id, "kind": "home"}), "%s admits a console" % archetype_id)
		_check(not Console.eligible({"archetype_id": archetype_id, "kind": "home", "home_lost": true}), "%s lost home cannot advertise a console" % archetype_id)
	_check(not Console.eligible({"archetype_id": "bar", "kind": "home"}) and not Console.eligible({"archetype_id": "house", "kind": "casino"}), "console eligibility rejects unrelated or forged room kinds")
	for archetype_id in ["motel_room", "apartment", "house"]:
		var environment := {"archetype_id": archetype_id, "kind": "home"}
		var before := Placement._shipping_surface_map(environment).duplicate(true)
		var after := Console.surface_map(environment, before).duplicate(true)
		for key in before:
			if typeof(before[key]) == TYPE_DICTIONARY:
				for inner_key in (before[key] as Dictionary):
					_check(after.get(key, {}).get(inner_key) == before[key][inner_key], "%s console preserves authored %s/%s" % [archetype_id, str(key), str(inner_key)])
			elif typeof(before[key]) == TYPE_ARRAY:
				for entry in before[key]:
					_check((after.get(key, []) as Array).has(entry), "%s console preserves an existing authored %s entry" % [archetype_id, str(key)])
			else:
				_check(after.get(key) == before[key], "%s console preserves authored %s" % [archetype_id, str(key)])


func _normal_leave(game_id: String) -> void:
	app.back_to_environment()
	# Quarter Falls retains its production chunked exit settle. Wait for the
	# bounded existing path rather than clearing the game or jumping to CRT.
	for _frame in range(600):
		if app.game_test_menu != null and app.game_test_menu.is_visible_in_tree() and app.current_game == null:
			return
		await process_frame
	_check(false, "%s normal Leave reaches CRT within 600 frames" % game_id)


func _persistent_snapshot() -> Dictionary:
	var files := {}
	for path in persistence_paths:
		files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return {"files": files, "profile": app.profile_inventory.to_dict().duplicate(true), "meta": app.meta_collection_service.snapshot().duplicate(true)}


func _origin_state(state: RunState) -> Dictionary:
	return {"run": state.to_dict().duplicate(true), "room": state.current_environment.duplicate(true), "home": state.home_state.duplicate(true), "rng_seed": state.rng_seed, "rng_state": state.rng_state}


func _continued_identity(state: RunState) -> Dictionary:
	return {"seed": state.seed_text, "room_id": str(state.current_environment.get("id", "")), "archetype": str(state.current_environment.get("archetype_id", "")), "cash": state.bankroll, "chips": state.grand_casino_chips, "heat": state.suspicion.duplicate(true), "clock": state.game_clock_minutes, "inventory": state.inventory.duplicate(true), "home": state.home_state.duplicate(true), "rng_seed": state.rng_seed, "rng_state": state.rng_state}


func _check_codec_identity(expected_state: RunState, label: String) -> void:
	var loader := SaveService.new()
	var continued: Variant = loader.load_run(app.autosave_slot_id)
	var expected := _continued_identity(expected_state)
	var actual := _continued_identity(continued) if continued is RunState else {"loaded_type": typeof(continued)}
	var identical := continued is RunState and actual == expected
	_check(identical, label)
	if not identical:
		diagnostics.append({"case": label, "expected": expected, "actual": actual, "differences": _identity_differences(expected, actual), "last_load_outcome": loader.last_load_outcome.duplicate(true)})


func _identity_differences(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var differences := {}
	for key in expected:
		if not actual.has(key) or expected[key] != actual[key]:
			differences[key] = {"expected": expected[key], "actual": actual.get(key), "expected_type": typeof(expected[key]), "actual_type": typeof(actual.get(key))}
	for key in actual:
		if not expected.has(key):
			differences[key] = {"expected": null, "actual": actual[key], "actual_type": typeof(actual[key])}
	return differences


func _launch_buttons(node: Node) -> Dictionary:
	var found := {}
	if node is Button and node.has_meta("game_test_id"):
		found[str(node.get_meta("game_test_id"))] = node
	for child in node.get_children():
		var child_buttons := _launch_buttons(child)
		for game_id in child_buttons:
			_check(not found.has(game_id), "game row %s is unique" % game_id)
			found[game_id] = child_buttons[game_id]
	return found


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok


func _finish(exit_code: int) -> void:
	print("CRT_PRACTICE_CONSOLE_CHECK " + JSON.stringify({"checks": checks, "cases": cases, "failures": failures, "diagnostics": diagnostics, "fidelity": "Synthetic disposable production-generator/host routing and persistence regression. No rendered native/Web or physical controller claim."}))
	quit(exit_code)
