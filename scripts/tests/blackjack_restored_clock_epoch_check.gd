extends SceneTree

# Actual already-revealed paid hand; no Deal, Peek, Hit, Stand or settlement.
# Detached clock-origin controls are explicitly synthetic. Run the cold stage
# as another process on the same maintained private persistence root.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SLOT := "blackjack_clock_roundtrip"
const LEDGER := "_blackjack_action_authority"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cold := OS.get_environment("BTH_CLOCK_RESTORE_STAGE") == "cold"
	if not _private_roots() or not cold and not _install_bundle():
		_finish()
		return
	var reference: Variant = SaveService.new().load_run(SLOT if cold else "foundation_ui_autosave")
	if not check(reference is RunState, "official unchanged private paid-hand copy loads"):
		_finish()
		return
	var expected := _protected(reference)
	var original_session := _session(reference)
	check(bool(original_session.get("cheats_used", {}).get("peek_hole_card", false)) and bool(original_session.get("dealer_hole_visible", false)), "fixture is a genuine already-revealed unfinished hand")
	check(reference.bankroll == 71 and reference.grand_casino_chips == 230, "original paid balances remain71 cash230 chips")
	var started := int(original_session.get("dealer_lookaway_started_msec", 0))
	var duration := int(original_session.get("dealer_lookaway_duration_msec", 0))
	var deadline := started + duration
	check(started == 75701 and duration == 3400, "captured absolute start and3.4second duration retained")
	var initial_anchor: int = reference.restored_surface_clock_msec()
	if not cold:
		check(reference.surface_clock_checkpoint_msec == -1 and initial_anchor == 76234, "legacy fallback is validated last-action76234, not current process time")
		_synthetic_epoch_controls(reference, started, duration)
	else:
		check(reference.surface_clock_checkpoint_msec >= 76234, "new process reads the actual later saved frame checkpoint")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.user_settings.reduce_motion = OS.get_environment("BTH_CLOCK_REDUCE_MOTION") == "1"
	app.autosave_slot_id = SLOT if cold else "foundation_ui_autosave"
	if not check(app.load_foundation_run(), "ordinary Host Continue restores the paid hand"):
		app.queue_free(); await process_frame; _finish(); return
	var loaded_now: int = app._environment_simulation_time_msec()
	check(loaded_now >= initial_anchor and loaded_now < initial_anchor + 2000, "Continue clock begins in saved epoch, independent of startup duration")
	if not check(app.enter_game("blackjack"), "ordinary same-table entry succeeds without a paid input"):
		app.queue_free(); await process_frame; _finish(); return
	var canvas: Variant = app.game_surface_canvas
	var focus: Dictionary = app.current_game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state())
	var opened_now: int = canvas.surface_simulation_time_msec()
	check(opened_now >= initial_anchor and opened_now < initial_anchor + 2000, "first rendered clock shares the restored epoch")
	check(int(focus.get("lookaway_remaining_msec", 0)) <= maxi(0, deadline - initial_anchor), "entry never grants more than the known saved remaining duration")
	check(int(focus.get("lookaway_remaining_msec", 0)) <= duration, "actual rendered countdown cannot exceed original duration")
	check(_protected(app.run_state) == expected, "entry preserves full paid ledger, wallets, history, flags, debt and RNG")
	app.top_menu_button.pressed.emit()
	for frame in range(3): await process_frame
	check(app._run_menu_is_visible() and canvas.environment_activity_paused, "normal Menu owns the paused game clock")
	var paused: int = canvas.surface_simulation_time_msec()
	var paused_focus: Dictionary = app.current_game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state())
	await create_timer(0.15).timeout
	check(canvas.surface_simulation_time_msec() == paused, "menu wait leaves simulation time unchanged")
	check(app.current_game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state()) == paused_focus, "menu wait cannot consume or extend the window")
	for frame in range(16):
		if not app._room_publication_save_blocked(): break
		await process_frame
	check(not app._room_publication_save_blocked(), "ordinary restored-room publication completes before Save")
	app.save_foundation_run()
	app.save_service.wait_for_async_save()
	check(app.run_state.surface_clock_checkpoint_msec == maxi(paused, reference.surface_clock_checkpoint_msec), "normal Save captures the pause-safe visible input frame")
	var normal_saved: Variant = SaveService.new().load_run(app.autosave_slot_id)
	check(normal_saved is RunState and normal_saved.surface_clock_checkpoint_msec == app.run_state.surface_clock_checkpoint_msec, "normal Host Save actually installed that frame checkpoint")
	check(_protected(app.run_state) == expected, "clock checkpoint never rewrites paid authority or game outcome")
	# Retain that same normal Host snapshot under a dedicated diagnostic slot.
	check(app.save_service.save_run(app.run_state, SLOT) == OK, "official private roundtrip save succeeds")
	var saved: Variant = SaveService.new().load_run(SLOT)
	if check(saved is RunState, "fresh SaveService reads checkpoint with strict existing validators"):
		check(saved.surface_clock_checkpoint_msec == app.run_state.surface_clock_checkpoint_msec, "clock checkpoint persists as exact integer")
		check(_protected(saved) == expected, "fresh service preserves full protected authority and accounting")
		check(int(saved.to_action_snapshot_without_world().get("surface_clock_checkpoint_msec", -2)) == saved.surface_clock_checkpoint_msec, "action snapshot/rollback retains epoch checkpoint")
		check(int(saved.to_dict().get("surface_clock_checkpoint_msec", -2)) == saved.surface_clock_checkpoint_msec, "canonical schema retains epoch checkpoint")
	app.run_menu_resume_button.pressed.emit()
	for frame in range(3): await process_frame
	check(canvas.surface_simulation_time_msec() >= paused, "warm Resume advances from frozen clock without reset")
	app.top_menu_button.pressed.emit()
	for frame in range(2): await process_frame
	app.save_foundation_run()
	app.save_service.wait_for_async_save()
	check(app.run_state.surface_clock_checkpoint_msec >= paused, "second Save cannot rewind elapsed time")
	check(app.save_service.save_run(app.run_state, SLOT) == OK, "second exact snapshot saved for independent cold process")
	var checkpoint: int = app.run_state.surface_clock_checkpoint_msec
	app.autosave_slot_id = SLOT
	check(app.load_foundation_run(), "same-host Continue can reload the newer checkpoint")
	check(app._environment_simulation_time_msec() >= checkpoint and app._environment_simulation_time_msec() < checkpoint + 2000, "same-host Continue rebases once, not additively")
	check(app.enter_game("blackjack"), "same-host re-entry restores unchanged hand")
	var after_focus: Dictionary = app.current_game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state())
	check(int(after_focus.get("lookaway_remaining_msec", 0)) <= maxi(0, deadline - checkpoint), "repeated Continue never restarts or extends a consumed window")
	check(_protected(app.run_state) == expected, "repeated Continue and Resume preserve paid ledger and all accounting")
	facts = {"stage": "new_process_cold" if cold else "write", "reduce_motion": app.user_settings.reduce_motion, "legacy_or_saved_anchor": initial_anchor, "opened_clock": opened_now, "opened_remaining": focus.get("lookaway_remaining_msec", 0), "paused_clock": paused, "saved_checkpoint": checkpoint, "reloaded_remaining": after_focus.get("lookaway_remaining_msec", 0), "deadline": deadline, "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "authority_fingerprint": Runtime.canonical_fingerprint(_ledger(app.run_state)), "scope": "Normal Continue/table entry/Menu/Save/Resume, no paid action or hidden decision. Detached epoch/bounds controls are synthetic."}
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _synthetic_epoch_controls(run: RunState, started: int, duration: int) -> void:
	var original_checkpoint: int = run.surface_clock_checkpoint_msec
	var original_ledger := Runtime.canonical_fingerprint(_ledger(run))
	var game := Blackjack.new()
	var canvas := Canvas.new()
	var probe := Host.new()
	probe.run_state = run
	var session := _session(run)
	var base_time := int(session.get("surface_time_msec", 0))
	for reduce_motion in [false, true]:
		for origin in [1000, 200000]:
			for checkpoint in [-1, base_time + 1000, started + duration + 1]:
				run.surface_clock_checkpoint_msec = checkpoint
				# Freeze the existing pause-safe host clock at a synthetic process
				# origin; production clock formula itself is not overridden.
				probe.environment_pause_started_msec = Time.get_ticks_msec()
				probe.environment_paused_total_msec = probe.environment_pause_started_msec - origin
				probe._restore_loaded_surface_clock_epoch()
				var expected: int = maxi(base_time, checkpoint)
				check(probe._environment_simulation_time_msec() == expected, "synthetic before/after epoch resumes exact saved elapsed boundary")
				probe._restore_loaded_surface_clock_epoch()
				check(probe._environment_simulation_time_msec() == expected, "repeated epoch restore is idempotent")
				canvas.render_game_snapshot({"game_id": "blackjack", "surface_time_msec": expected, "reduce_motion": reduce_motion, "dealer_focus_runtime": {"dealer_lookaway_started_msec": started, "dealer_lookaway_duration_msec": duration}})
				var projected: Dictionary = game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state())
				check(int(projected.get("lookaway_remaining_msec", -1)) == maxi(0, started + duration - expected), "elapsed/expired rendered window survives both epoch directions and motion modes")
				check(bool(projected.get("lookaway_active", false)) == (expected <= started + duration), "known expired window stays expired")
	for now in [started - 1, started, started + duration, started + duration + 1]:
		var local_session := session.duplicate(true)
		local_session["surface_time_msec"] = now
		var active: bool = now >= started and now <= started + duration
		check(game._dealer_lookaway_active(local_session) == active, "logical lookaway rejects pre-start and expired timestamps")
		var focus: Dictionary = game._dealer_focus_state({}, local_session, null)
		check(bool(focus.get("lookaway_active", false)) == active and int(focus.get("lookaway_remaining_msec", 0)) <= duration, "logical focus shares bounded window semantics")
		canvas.render_game_snapshot({"game_id": "blackjack", "surface_time_msec": now, "dealer_focus_runtime": {"dealer_lookaway_started_msec": started, "dealer_lookaway_duration_msec": duration}})
		check(bool(game._dealer_focus_for_surface_state(canvas, canvas.realtime_surface_state()).get("lookaway_active", false)) == active, "renderer and logical boundary agree")
	run.surface_clock_checkpoint_msec = original_checkpoint
	check(Runtime.canonical_fingerprint(_ledger(run)) == original_ledger, "all synthetic clock controls leave sealed session byte-equivalent")
	var rejected := RunState.new()
	rejected.current_environment = run.current_environment.duplicate(true)
	var bad_ledger: Dictionary = rejected.current_environment["game_states"]["blackjack"][LEDGER]
	bad_ledger["table_binding"] = "untrusted-other-table"
	check(rejected.restored_surface_clock_msec() == -1, "invalid table-bound ledger cannot supply a legacy epoch")
	probe.free(); canvas.free()


func _ledger(run: RunState) -> Dictionary:
	return run.current_environment.get("game_states", {}).get("blackjack", {}).get(LEDGER, {})


func _session(run: RunState) -> Dictionary:
	return _ledger(run).get("session", {})


func _protected(run: RunState) -> Dictionary:
	return {"ledger": Runtime.canonical_fingerprint(_ledger(run)), "cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state), "story": Runtime.canonical_fingerprint(run.story_log), "flags": Runtime.canonical_fingerprint(run.narrative_flags), "debt": Runtime.canonical_fingerprint(run.debt), "score": run.run_spending_score, "action": run.numbers_state.action_index, "inventory": Runtime.canonical_fingerprint(run.inventory)}


func _private_roots() -> bool:
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path()
	if not check(distribution.is_absolute_path() and "native-private-" in distribution, "explicit maintained private native root required"): return false
	var prefix := distribution.get_base_dir().to_lower()
	for key in ["BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "APPDATA"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not check(path == prefix or path.begins_with(prefix + "/"), "private containment for " + key): return false
	return true


func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(bundle.is_absolute_path(), "explicit unchanged copied actual bundle required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves); DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "copy unchanged private " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "private original authority companion"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "copy private " + str(pair[0]) + suffix): return false
	return true


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "\t"))
	print("BLACKJACK_RESTORED_CLOCK checks=%d failures=%s" % [checks, str(failures)])
	quit(0 if failures.is_empty() else 1)
