extends SceneTree
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not _install(): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not check(app.load_foundation_run(), "official Continue copied actual pre-GoPlay checkpoint"):
		app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	check(run.bankroll == 109 and run.grand_casino_chips == 24 and run.game_clock_minutes == 3771, "faithful actual pre-dismissal wallet/clock")
	app._refresh_talk_dock()
	check(str(app.talk_dock.entry.get("event_id", "")) == "heist_live_table", "actual live table owns TalkDock")
	var option: Dictionary = app._eligible_event_option("heist_live_table")
	var leave: Dictionary = app._event_choice(option, "leave")
	check(bool(leave.get("enabled", true)) and bool(leave.get("dismissal", false)) and str(leave.get("label", "")) == "Go play one blackjack hand", "authoritative current hand step provides explicit enabled dismissal")
	var substantive: Dictionary = app._event_choice(option, "inspect")
	check(not substantive.is_empty() and not bool(substantive.get("dismissal", false)), "ordinary Read Session response retains ordinary resolution policy")
	var before := _proof(run)
	app._on_talk_dock_choice_requested("heist_live_table", "leave")
	for frame in range(3): await process_frame
	check(run.pending_talk_event("heist_live_table").is_empty(), "normal authored dismissal releases pending dialogue ownership")
	check(_equal(_proof(run), before), "GoPlay costs no cash/chips/Heat/reputation/duties/action/time/RNG or heist state")
	var closed := run.to_save_snapshot()
	app._on_talk_dock_choice_requested("heist_live_table", "leave")
	check(run.to_save_snapshot() == closed, "stale repeated dismissal cannot resolve or consume a turn")
	app.save_service.wait_for_async_save()
	check(app.save_service.save_run(run, "foundation_ui_autosave") == OK, "official Save durably records neutral close")
	check(app.return_to_main_menu(), "ordinary Main Menu boundary after close")
	app.save_service = SaveService.new()
	check(app.load_foundation_run(), "fresh service Continue restores actual unchanged heist")
	run = app.run_state
	check(_equal(_proof(run), before), "Continue retains zero-cost dismissal and exact heist budget")
	check(run.pending_talk_event("heist_live_table").is_empty(), "dismissed prompt does not instantly reappear on Continue")
	check(app._start_person_event_conversation("heist_live_table"), "deliberate later Talk remains available")
	check(str(app.talk_dock.entry.get("event_id", "")) == "heist_live_table", "deliberate Talk can reacquire response surface")
	app._on_talk_dock_choice_requested("heist_live_table", "leave")
	check(_equal(_proof(run), before) and run.pending_talk_event("heist_live_table").is_empty(), "second deliberate neutral close remains effect-free")
	facts = {"before": before, "after": _proof(run), "leave": leave, "fidelity": "Unchanged actual pre-GoPlay Save, real Host Continue and normal TalkDock callback; no wager, hand, ending or reward replay. Fresh-service Continue is native, not Web fresh-process evidence."}
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()

func _proof(run: RunState) -> Dictionary:
	var snapshot := run.to_save_snapshot()
	var result := {}
	for key in ["bankroll", "grand_casino_chips", "suspicion", "rng_state", "game_clock_minutes", "simulation_msec", "run_status", "story_log", "story_log_archive_count", "story_money_archive", "world_sequence_registrations", "active_delivery_run", "debt", "inventory", "run_spending_score", "crew_state"]:
		result[key] = snapshot.get(key)
	var flags := run.narrative_flags.duplicate(true)
	flags.erase("neutral_dialogue_dismissals")
	result["narrative_flags"] = flags
	return result

func _install() -> bool:
	var bundle := OS.get_environment("BTH_COUNT_DISMISSAL_BUNDLE")
	if not check(not bundle.is_empty() and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit private fixture and persistence required"): return false
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install unchanged private save companion"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "install copied authority"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)) and not check(DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix) == OK, "install private companion"): return false
	return true

func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]: return a == b
	if typeof(a) != typeof(b): return false
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _equal(a[i], b[i]): return false
		return true
	return a == b

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "\t"))
	print("COUNT_AUTHORED_DISMISSAL checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
