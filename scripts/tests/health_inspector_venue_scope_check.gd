extends SceneTree
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _run() -> void:
	var run := RunState.new()
	run.start_new("INSPECTOR-SCOPE")
	run.current_environment = {"id":"bar_original","archetype_id":"bar"}
	run.narrative_flags.health_inspector_closing_actions = 1
	run.log_story({"type":"event","event_id":"health_inspector","choice_id":"finish_one","environment_id":"bar_original"})
	_check(run.narrative_flags.health_inspector_origin_environment_id == "bar_original", "accepted receipt binds original venue")
	_check(run.reconcile_health_inspector_venue_scope(), "last action remains available in its original venue")
	var before := run.to_save_snapshot()
	var restored := RunState.new(); restored.from_dict(before)
	_check(restored.reconcile_health_inspector_venue_scope() and int(restored.narrative_flags.health_inspector_closing_actions) == 1, "same-venue Continue preserves allowance")
	restored.current_environment = {"id":"bar_inner","archetype_id":"bar","layer_states":{"outer":{"id":"bar_original"}}}
	_check(restored.reconcile_health_inspector_venue_scope(), "internal layer family preserves venue allowance")
	restored.current_environment = {"id":"bar_different","archetype_id":"bar"}
	_check(not restored.reconcile_health_inspector_venue_scope() and int(restored.narrative_flags.health_inspector_closing_actions) == 0, "another Bar is not the inspected venue")
	restored.from_dict(before)
	_check(restored.reconcile_health_inspector_venue_scope(), "failed-travel snapshot restores original pending allowance")
	run.narrative_flags.erase("health_inspector_origin_environment_id")
	_check(run.reconcile_health_inspector_venue_scope(), "legacy accepted history identifies same venue")
	run.current_environment = {"id":"jazz_other","archetype_id":"jazz_club"}
	_check(not run.reconcile_health_inspector_venue_scope() and int(run.narrative_flags.health_inspector_closing_actions) == 0, "known legacy departure retires allowance")
	run.narrative_flags.erase("health_inspector_origin_environment_id")
	run.narrative_flags.health_inspector_closing_actions = 1
	run.story_log.clear()
	_check(not run.reconcile_health_inspector_venue_scope() and int(run.narrative_flags.health_inspector_closing_actions) == 1, "unknown trimmed legacy history is preserved dormant rather than bound to a foreign room")
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not bundle.is_empty(): await _captured(bundle)
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "))
	print("INSPECTOR_VENUE checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _captured(bundle: String) -> void:
	var private_root := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	if not _check(private_root.is_absolute_path(), "private persistence root required"): return
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK, "copy protected-save companion privately")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1")) == OK, "copy private authority")
	root.size = Vector2i(1280,720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if _check(app.load_foundation_run(), "official Continue unchanged J31"):
		var run: RunState = app.run_state
		_check(run.bankroll == 65 and str(run.current_environment.get("id")) == "jazz_club_005", "actual captured arrival identity and funds preserved")
		_check(int(run.narrative_flags.health_inspector_closing_actions) == 0 and str(run.narrative_flags.health_inspector_origin_environment_id) == "bar_004", "legacy accepted origin retires foreign closure")
		var count := run.story_log_entry_count()
		var tips := 0
		for row in run.story_log:
			if str(row.get("type")) == "jazz_tip_jar": tips += 1
		_check(app.select_service_hook("jazz_band_tip_jar"), "select actual available Tip Jar")
		await create_timer(0.25).timeout
		_check(app.confirm_selected_service_hook(), "normal Use callback accepts one tip")
		for frame in range(6): await process_frame
		_check(run.bankroll == 59 and str(run.current_environment.get("id")) == "jazz_club_005", "one six-dollar tip leaves player at Jazz")
		var added_travel := 0
		var after_tips := 0
		for index in range(run.story_log.size()):
			var row: Dictionary = run.story_log[index]
			if str(row.get("type")) == "jazz_tip_jar": after_tips += 1
			if run.story_log_archive_count + index >= count and str(row.get("type")) == "travel": added_travel += 1
		_check(after_tips == tips + 1 and added_travel == 0, "one tip receipt and no forced trip")
		var rng := run.rng_state
		facts = {"cash":run.bankroll,"room":run.current_environment.get("id"),"rng":rng,"tip_receipts_added":after_tips-tips,"forced_trips_added":added_travel}
		_check(app.return_to_main_menu(), "normal Save and Main Menu")
		await process_frame; app.save_service = SaveService.new()
		_check(app.load_foundation_run(), "fresh-service Continue post-tip")
		run = app.run_state
		_check(run.bankroll == 59 and run.rng_state == rng and str(run.current_environment.get("id")) == "jazz_club_005", "Continue retains exact tip outcome without forced travel or replay")
		_check(app.return_to_main_menu(), "normal final cleanup")
	app.queue_free()
	for frame in range(3): await process_frame
